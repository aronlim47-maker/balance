-- War Council integrity upgrade. Apply after 202609240001_initial_schema.sql.
-- Per-day baselines let undo restore the original overload without accepting
-- a new overload caused by later changes to other work or availability.
alter table public.plan_changes
  add column if not exists before_overload_by_day jsonb not null default '{}'::jsonb;

-- Ordinary task edits must invalidate the version captured by a confirmed plan.
-- The original RPCs already increment version explicitly, so preserve that step.
create or replace function public.bump_task_version()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.version = old.version then
    new.version := old.version + 1;
  elsif new.version <> old.version + 1 then
    raise exception 'Task version must advance by exactly one';
  end if;
  return new;
end;
$$;

create or replace function public.confirm_plan_change(
  p_moves jsonb,
  p_recovery_start timestamptz default null,
  p_recovery_end timestamptz default null,
  p_consequences jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_time_zone text;
  v_change_id uuid;
  v_move jsonb;
  v_task public.tasks%rowtype;
  v_task_id uuid;
  v_proposed_start timestamptz;
  v_proposed_end timestamptz;
  v_moved_minutes integer;
  v_move_range tstzrange;
  v_seen_task_ids uuid[] := '{}'::uuid[];
  v_seen_ranges tstzrange[] := '{}'::tstzrange[];
  v_dates date[] := '{}'::date[];
  v_date date;
  v_day_before integer;
  v_before_overload integer := 0;
  v_after_overload integer := 0;
  v_before_by_day jsonb := '{}'::jsonb;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text, 0));

  if p_moves is null or jsonb_typeof(p_moves) is distinct from 'array' then
    raise exception 'Moves must be a JSON array';
  end if;
  if jsonb_array_length(p_moves) = 0 then
    raise exception 'At least one task move is required';
  end if;
  if (p_recovery_start is null) <> (p_recovery_end is null) then
    raise exception 'Recovery start and end must be supplied together';
  end if;
  if p_recovery_start is not null and p_recovery_end <= p_recovery_start then
    raise exception 'Recovery end must be after its start';
  end if;

  select time_zone into v_time_zone
  from public.profiles
  where id = v_user_id;
  v_time_zone := coalesce(v_time_zone, 'UTC');

  -- Validate the complete proposal before writing any plan rows. The task
  -- version and selected availability rows remain locked until commit.
  for v_move in select value from jsonb_array_elements(p_moves)
  loop
    v_task_id := (v_move ->> 'task_id')::uuid;
    v_proposed_start := (v_move ->> 'proposed_start')::timestamptz;
    v_proposed_end := (v_move ->> 'proposed_end')::timestamptz;
    v_moved_minutes := (v_move ->> 'moved_minutes')::integer;

    if v_task_id is null or v_proposed_start is null
       or v_proposed_end is null or v_moved_minutes is null then
      raise exception 'Every move requires a task, interval, and moved minutes';
    end if;
    if v_proposed_end <= v_proposed_start then
      raise exception 'Proposed end must be after its start';
    end if;
    if v_task_id = any(v_seen_task_ids) then
      raise exception 'A task can appear only once in a plan';
    end if;

    v_move_range := pg_catalog.tstzrange(
      v_proposed_start, v_proposed_end, '[)'
    );
    if exists (
      select 1 from pg_catalog.unnest(v_seen_ranges) as seen(slot)
      where seen.slot && v_move_range
    ) then
      raise exception 'Proposed task intervals overlap each other';
    end if;
    v_seen_task_ids := array_append(v_seen_task_ids, v_task_id);
    v_seen_ranges := array_append(v_seen_ranges, v_move_range);

    select * into strict v_task
    from public.tasks
    where id = v_task_id and user_id = v_user_id
    for update;

    if v_task.status <> 'planned' then
      raise exception 'Only planned tasks can be moved';
    end if;
    if v_moved_minutes <= 0 or v_moved_minutes > v_task.remaining_minutes then
      raise exception 'Moved minutes exceed the task''s remaining work';
    end if;
    if extract(epoch from (v_proposed_end - v_proposed_start)) / 60
       <> v_moved_minutes then
      raise exception 'Proposed interval must equal moved minutes';
    end if;
    if v_task.is_protected or v_task.flexibility = 'fixed' then
      raise exception 'Protected or fixed tasks cannot be moved';
    end if;
    if v_task.flexibility = 'needs_agreement' then
      raise exception 'This task still needs agreement';
    end if;
    if v_proposed_end > v_task.due_at then
      raise exception 'Proposed placement exceeds the task deadline';
    end if;
    if v_task.scheduled_start is not null
       and v_moved_minutes < v_task.remaining_minutes
       and pg_catalog.tstzrange(
         v_task.scheduled_start,
         v_task.scheduled_start
           + make_interval(mins => v_task.remaining_minutes - v_moved_minutes),
         '[)'
       ) && v_move_range then
      raise exception 'Proposed placement overlaps the task''s retained schedule';
    end if;

    perform 1
    from public.availability_blocks b
    where b.user_id = v_user_id
      and b.block_type = 'available'
      and b.start_at <= v_proposed_start
      and b.end_at >= v_proposed_end
    for share;
    if not found then
      raise exception 'Proposed placement must fit inside available time';
    end if;
    if exists (
      select 1 from public.tasks t
      where t.user_id = v_user_id
        and t.id <> v_task.id
        and t.status = 'planned'
        and t.scheduled_start < v_proposed_end
        and t.scheduled_end > v_proposed_start
    ) then
      raise exception 'Proposed placement overlaps another task';
    end if;
    if exists (
      select 1 from public.plan_change_items i
      join public.plan_changes c on c.id = i.plan_change_id
      where c.user_id = v_user_id
        and c.status = 'confirmed'
        and i.proposed_start < v_proposed_end
        and i.proposed_end > v_proposed_start
    ) then
      raise exception 'Proposed placement overlaps an earlier moved task';
    end if;
    if exists (
      select 1 from public.recovery_slots r
      where r.user_id = v_user_id
        and r.is_protected
        and r.start_at < v_proposed_end
        and r.end_at > v_proposed_start
    ) then
      raise exception 'Proposed placement overlaps protected recovery time';
    end if;

    if v_task.scheduled_start is null then
      -- Moving unscheduled work changes the backlog on its local due day.
      v_dates := array_append(
        v_dates, timezone(v_time_zone, v_task.due_at)::date
      );
    else
      for v_date in
        select public._local_days_for_interval(
          v_task.scheduled_start, v_task.scheduled_end, v_time_zone
        )
      loop
        v_dates := array_append(v_dates, v_date);
      end loop;
    end if;
    for v_date in
      select public._local_days_for_interval(
        v_proposed_start, v_proposed_end, v_time_zone
      )
    loop
      v_dates := array_append(v_dates, v_date);
    end loop;
  end loop;

  if p_recovery_start is not null then
    for v_date in
      select public._local_days_for_interval(
        p_recovery_start, p_recovery_end, v_time_zone
      )
    loop
      v_dates := array_append(v_dates, v_date);
    end loop;
  end if;

  for v_date in select distinct unnest(v_dates)
  loop
    v_day_before := public.calculate_day_overload(v_user_id, v_date);
    v_before_overload := greatest(v_before_overload, v_day_before);
    v_before_by_day := pg_catalog.jsonb_set(
      v_before_by_day, array[v_date::text], to_jsonb(v_day_before), true
    );
  end loop;

  insert into public.plan_changes (
    user_id, status, before_overload_minutes, before_overload_by_day,
    after_overload_minutes, validation_status, consequences
  ) values (
    v_user_id, 'draft', v_before_overload, v_before_by_day,
    0, 'feasible', coalesce(p_consequences, '{}'::jsonb)
  ) returning id into v_change_id;

  for v_move in select value from jsonb_array_elements(p_moves)
  loop
    v_proposed_start := (v_move ->> 'proposed_start')::timestamptz;
    v_proposed_end := (v_move ->> 'proposed_end')::timestamptz;
    v_moved_minutes := (v_move ->> 'moved_minutes')::integer;

    select * into strict v_task
    from public.tasks
    where id = (v_move ->> 'task_id')::uuid and user_id = v_user_id
    for update;

    insert into public.plan_change_items (
      plan_change_id, task_id, original_start, original_end,
      proposed_start, proposed_end, moved_minutes,
      original_remaining_minutes, proposed_remaining_minutes,
      original_task_version, applied_task_version
    ) values (
      v_change_id, v_task.id, v_task.scheduled_start, v_task.scheduled_end,
      v_proposed_start, v_proposed_end, v_moved_minutes,
      v_task.remaining_minutes, v_task.remaining_minutes - v_moved_minutes,
      v_task.version, v_task.version + 1
    );

    update public.tasks
    set remaining_minutes = remaining_minutes - v_moved_minutes,
        scheduled_end = case
          when remaining_minutes - v_moved_minutes = 0 then null
          else scheduled_start
            + make_interval(mins => remaining_minutes - v_moved_minutes)
        end,
        scheduled_start = case
          when remaining_minutes - v_moved_minutes = 0 then null
          else scheduled_start
        end,
        version = version + 1
    where id = v_task.id;
  end loop;

  update public.plan_changes
  set status = 'confirmed', confirmed_at = now()
  where id = v_change_id;

  if p_recovery_start is not null then
    insert into public.recovery_slots (
      user_id, plan_change_id, start_at, end_at, is_protected
    ) values (
      v_user_id, v_change_id, p_recovery_start, p_recovery_end, true
    );
  end if;

  for v_date in select distinct unnest(v_dates)
  loop
    v_after_overload := greatest(
      v_after_overload,
      public.calculate_day_overload(v_user_id, v_date)
    );
  end loop;
  if v_after_overload > 0 then
    raise exception 'Plan still exceeds available capacity by % minutes',
      v_after_overload;
  end if;

  update public.plan_changes
  set after_overload_minutes = v_after_overload
  where id = v_change_id;

  return v_change_id;
end;
$$;

create trigger tasks_bump_version
before update on public.tasks
for each row execute function public.bump_task_version();

-- Half-open intervals include the start day and exclude a day that starts
-- exactly at the end. This also handles local midnight and daylight changes.
create or replace function public._local_days_for_interval(
  p_start timestamptz,
  p_end timestamptz,
  p_time_zone text
)
returns setof date
language sql
stable
set search_path = ''
as $$
  select (p_start at time zone p_time_zone)::date + offsets.day_offset
  from pg_catalog.generate_series(
    0,
    ((p_end - interval '1 microsecond') at time zone p_time_zone)::date
      - (p_start at time zone p_time_zone)::date
  ) as offsets(day_offset)
  where p_start is not null
    and p_end is not null
    and p_end > p_start;
$$;

create or replace function public.calculate_day_overload(
  p_user_id uuid,
  p_day date
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_time_zone text;
  v_day_start timestamptz;
  v_day_end timestamptz;
  v_cutoff timestamptz;
  v_available_minutes integer;
  v_planned_minutes integer;
  v_overload integer := 0;
begin
  if auth.uid() is null or p_user_id is distinct from auth.uid() then
    raise exception 'Cannot calculate another user''s capacity';
  end if;
  if p_day is null then
    raise exception 'Capacity date is required';
  end if;

  select time_zone into v_time_zone
  from public.profiles
  where id = p_user_id;

  v_day_start := p_day::timestamp at time zone coalesce(v_time_zone, 'UTC');
  v_day_end := (p_day + 1)::timestamp at time zone coalesce(v_time_zone, 'UTC');

  -- Checking only the day total would let evening availability falsely cover
  -- a task due at noon. Evaluate every unscheduled deadline as a prefix of
  -- the local day, then evaluate the whole day for later booked work.
  for v_cutoff in
    select due_at
    from public.tasks
    where user_id = p_user_id
      and status = 'planned'
      and scheduled_start is null
      and remaining_minutes > 0
      and due_at >= v_day_start
      and due_at < v_day_end
    union
    select v_day_end
  loop
    select coalesce(sum(
      extract(epoch from (
        least(end_at, v_cutoff) - greatest(start_at, v_day_start)
      )) / 60
    ), 0)::integer
    into v_available_minutes
    from public.availability_blocks
    where user_id = p_user_id
      and block_type = 'available'
      and start_at < v_cutoff
      and end_at > v_day_start;

    select (
      coalesce((
        select sum(extract(epoch from (
          least(t.scheduled_end, v_cutoff)
            - greatest(t.scheduled_start, v_day_start)
        )) / 60)
        from public.tasks t
        where t.user_id = p_user_id
          and t.status = 'planned'
          and t.scheduled_start < v_cutoff
          and t.scheduled_end > v_day_start
      ), 0)
      + coalesce((
        select sum(t.remaining_minutes)
        from public.tasks t
        where t.user_id = p_user_id
          and t.status = 'planned'
          and t.scheduled_start is null
          and t.remaining_minutes > 0
          and t.due_at >= v_day_start
          and t.due_at < v_day_end
          and t.due_at <= v_cutoff
      ), 0)
      + coalesce((
        select sum(extract(epoch from (
          least(i.proposed_end, v_cutoff)
            - greatest(i.proposed_start, v_day_start)
        )) / 60)
        from public.plan_change_items i
        join public.plan_changes c on c.id = i.plan_change_id
        join public.tasks t on t.id = i.task_id
        where c.user_id = p_user_id
          and c.status = 'confirmed'
          and t.status = 'planned'
          and i.proposed_start < v_cutoff
          and i.proposed_end > v_day_start
      ), 0)
      + coalesce((
        select sum(extract(epoch from (
          least(r.end_at, v_cutoff) - greatest(r.start_at, v_day_start)
        )) / 60)
        from public.recovery_slots r
        where r.user_id = p_user_id
          and r.is_protected
          and r.start_at < v_cutoff
          and r.end_at > v_day_start
      ), 0)
    )::integer
    into v_planned_minutes;

    v_overload := greatest(
      v_overload, v_planned_minutes - v_available_minutes
    );
  end loop;

  return v_overload;
end;
$$;

-- Take the user-level planning lock before row locks to serialize direct edits
-- with confirm/undo without reversing their lock order.
create or replace function public.lock_user_planning_state()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if auth.uid() is not null then
    perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text, 0));
  end if;
  return null;
end;
$$;

create trigger tasks_lock_planning_state
before insert or update or delete on public.tasks
for each statement execute function public.lock_user_planning_state();

create trigger availability_lock_planning_state
before insert or update or delete on public.availability_blocks
for each statement execute function public.lock_user_planning_state();

-- Authenticated users may now create and edit their own task schedules.
-- Guard those schedules against already confirmed work and recovery time.
create or replace function public.validate_task_schedule()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_restoring_original boolean := false;
begin
  if new.status <> 'planned' then
    return new;
  end if;

  if exists (
    select 1 from public.plan_change_items i
    join public.plan_changes c on c.id = i.plan_change_id
    where c.user_id = new.user_id
      and c.status = 'confirmed'
      and i.task_id = new.id
      and i.proposed_end > new.due_at
  ) then
    raise exception 'Task deadline cannot precede confirmed moved work';
  end if;
  if new.scheduled_start is null then
    return new;
  end if;

  -- Undo may restore the exact prior schedule even when that historical
  -- schedule exceeded today's availability. Only the undo RPC can mark its
  -- plan undone in this transaction; all conflict checks below still run.
  if tg_op = 'UPDATE' then
    select exists (
      select 1
      from public.plan_change_items i
      join public.plan_changes c on c.id = i.plan_change_id
      where i.task_id = new.id
        and c.user_id = new.user_id
        and c.status = 'undone'
        and c.undone_at = now()
        and old.version = i.applied_task_version
        and new.version = i.applied_task_version + 1
        and new.scheduled_start is not distinct from i.original_start
        and new.scheduled_end is not distinct from i.original_end
        and new.remaining_minutes = i.original_remaining_minutes
    ) into v_restoring_original;
  end if;

  if not v_restoring_original and not exists (
    select 1 from public.availability_blocks b
    where b.user_id = new.user_id
      and b.block_type = 'available'
      and b.start_at <= new.scheduled_start
      and b.end_at >= new.scheduled_end
  ) then
    raise exception 'A scheduled task must fit inside available time';
  end if;
  if exists (
    select 1 from public.plan_change_items i
    join public.plan_changes c on c.id = i.plan_change_id
    where c.user_id = new.user_id
      and c.status = 'confirmed'
      and i.proposed_start < new.scheduled_end
      and i.proposed_end > new.scheduled_start
  ) then
    raise exception 'Scheduled task overlaps confirmed moved work';
  end if;
  if exists (
    select 1 from public.recovery_slots r
    where r.user_id = new.user_id
      and r.is_protected
      and r.start_at < new.scheduled_end
      and r.end_at > new.scheduled_start
  ) then
    raise exception 'Scheduled task overlaps protected recovery time';
  end if;
  return new;
end;
$$;

create trigger tasks_validate_schedule
before insert or update of scheduled_start, scheduled_end, status, remaining_minutes, due_at
on public.tasks
for each row execute function public.validate_task_schedule();

-- An availability edit must not strand work already placed inside that block.
-- The statement-level planning lock serializes this check with confirm/undo.
create or replace function public.protect_committed_availability()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_start timestamptz;
  v_end timestamptz;
begin
  if old.block_type <> 'available' then
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;

  for v_start, v_end in
    select t.scheduled_start, t.scheduled_end
    from public.tasks t
    where t.user_id = old.user_id
      and t.status = 'planned'
      and t.scheduled_start >= old.start_at
      and t.scheduled_end <= old.end_at
    union all
    select i.proposed_start, i.proposed_end
    from public.plan_change_items i
    join public.plan_changes c on c.id = i.plan_change_id
    where c.user_id = old.user_id
      and c.status = 'confirmed'
      and i.proposed_start >= old.start_at
      and i.proposed_end <= old.end_at
    union all
    select r.start_at, r.end_at
    from public.recovery_slots r
    where r.user_id = old.user_id
      and r.is_protected
      and r.start_at >= old.start_at
      and r.end_at <= old.end_at
  loop
    if tg_op = 'DELETE' then
      raise exception 'Availability contains committed work or recovery';
    end if;
    if new.block_type <> 'available'
       or new.start_at > v_start or new.end_at < v_end then
      raise exception 'Availability change would strand committed work or recovery';
    end if;
  end loop;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create trigger availability_protect_committed
before update or delete on public.availability_blocks
for each row execute function public.protect_committed_availability();

create or replace function public.undo_plan_change(p_change_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_time_zone text;
  v_change public.plan_changes%rowtype;
  v_item public.plan_change_items%rowtype;
  v_task public.tasks%rowtype;
  v_slot public.recovery_slots%rowtype;
  v_dates date[] := '{}'::date[];
  v_date date;
  v_current_by_day jsonb := '{}'::jsonb;
  v_allowed_overload integer;
  v_after_overload integer;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text, 0));

  select * into strict v_change
  from public.plan_changes
  where id = p_change_id and user_id = v_user_id
  for update;
  if v_change.status <> 'confirmed' then
    raise exception 'Only a confirmed plan can be undone';
  end if;

  select time_zone into v_time_zone
  from public.profiles
  where id = v_user_id;
  v_time_zone := coalesce(v_time_zone, 'UTC');

  for v_item in
    select * from public.plan_change_items
    where plan_change_id = p_change_id
    order by task_id
  loop
    select * into strict v_task
    from public.tasks
    where id = v_item.task_id and user_id = v_user_id
    for update;
    if v_task.version <> v_item.applied_task_version then
      raise exception 'Task changed after this plan; undo would overwrite newer work';
    end if;

    if v_item.original_start is not null then
      if exists (
        select 1 from public.tasks t
        where t.user_id = v_user_id
          and t.id <> v_item.task_id
          and t.status = 'planned'
          and t.scheduled_start < v_item.original_end
          and t.scheduled_end > v_item.original_start
      ) then
        raise exception 'Original task time is occupied by another task';
      end if;
      if exists (
        select 1 from public.plan_change_items i
        join public.plan_changes c on c.id = i.plan_change_id
        where c.user_id = v_user_id
          and c.status = 'confirmed'
          and c.id <> p_change_id
          and i.proposed_start < v_item.original_end
          and i.proposed_end > v_item.original_start
      ) then
        raise exception 'Original task time is occupied by another plan';
      end if;
      if exists (
        select 1 from public.recovery_slots r
        where r.user_id = v_user_id
          and r.is_protected
          and r.plan_change_id is distinct from p_change_id
          and r.start_at < v_item.original_end
          and r.end_at > v_item.original_start
      ) then
        raise exception 'Original task time is protected recovery time';
      end if;

      for v_date in
        select public._local_days_for_interval(
          v_item.original_start, v_item.original_end, v_time_zone
        )
      loop
        v_dates := array_append(v_dates, v_date);
      end loop;
    else
      v_dates := array_append(
        v_dates, timezone(v_time_zone, v_task.due_at)::date
      );
    end if;
    for v_date in
      select public._local_days_for_interval(
        v_item.proposed_start, v_item.proposed_end, v_time_zone
      )
    loop
      v_dates := array_append(v_dates, v_date);
    end loop;
  end loop;

  for v_slot in
    select * from public.recovery_slots
    where plan_change_id = p_change_id and user_id = v_user_id
  loop
    for v_date in
      select public._local_days_for_interval(
        v_slot.start_at, v_slot.end_at, v_time_zone
      )
    loop
      v_dates := array_append(v_dates, v_date);
    end loop;
  end loop;

  for v_date in select distinct unnest(v_dates)
  loop
    v_current_by_day := pg_catalog.jsonb_set(
      v_current_by_day, array[v_date::text],
      to_jsonb(public.calculate_day_overload(v_user_id, v_date)), true
    );
  end loop;

  -- Stop counting this plan and remove its recovery slot before restoring
  -- original task schedules. Any later error rolls the whole RPC back.
  update public.plan_changes
  set status = 'undone', undone_at = now()
  where id = p_change_id;

  delete from public.recovery_slots
  where plan_change_id = p_change_id and user_id = v_user_id;

  for v_item in
    select * from public.plan_change_items
    where plan_change_id = p_change_id
    order by task_id
  loop
    update public.tasks
    set scheduled_start = v_item.original_start,
        scheduled_end = v_item.original_end,
        remaining_minutes = v_item.original_remaining_minutes,
        version = version + 1
    where id = v_item.task_id and user_id = v_user_id;
  end loop;

  for v_date in select distinct unnest(v_dates)
  loop
    -- Legacy plans have no per-day baseline. Their global maximum cannot be
    -- safely assigned to each affected day, so allow no new per-day overload.
    v_allowed_overload := (v_current_by_day ->> v_date::text)::integer;
    if v_change.before_overload_by_day ? v_date::text then
      v_allowed_overload := greatest(
        v_allowed_overload,
        (v_change.before_overload_by_day ->> v_date::text)::integer
      );
    end if;
    v_after_overload := public.calculate_day_overload(v_user_id, v_date);
    if v_after_overload > v_allowed_overload then
      raise exception 'Undo would increase overload on % to % minutes',
        v_date, v_after_overload;
    end if;
  end loop;
end;
$$;

create or replace function public.war_council_schema_version()
returns integer
language sql
stable
security invoker
set search_path = ''
as $$
  select 2::integer;
$$;

grant insert (scheduled_start, scheduled_end) on public.tasks to authenticated;
grant update (scheduled_start, scheduled_end) on public.tasks to authenticated;

revoke all on function public.bump_task_version() from public;
revoke all on function public._local_days_for_interval(timestamptz, timestamptz, text) from public;
revoke all on function public.lock_user_planning_state() from public;
revoke all on function public.validate_task_schedule() from public;
revoke all on function public.protect_committed_availability() from public;
revoke all on function public.calculate_day_overload(uuid, date) from public;
revoke all on function public.confirm_plan_change(jsonb, timestamptz, timestamptz, jsonb) from public;
revoke all on function public.undo_plan_change(uuid) from public;
revoke all on function public.war_council_schema_version() from public;
grant execute on function public.calculate_day_overload(uuid, date) to authenticated;
grant execute on function public.confirm_plan_change(jsonb, timestamptz, timestamptz, jsonb) to authenticated;
grant execute on function public.undo_plan_change(uuid) to authenticated;
grant execute on function public.war_council_schema_version() to authenticated;
