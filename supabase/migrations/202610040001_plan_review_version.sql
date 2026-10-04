-- Apply after 202610030002_retry_safe_social_event.sql.
-- Preserve existing occupancy, ownership, locking and undo rules.
begin;

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

    -- Bind consent to the exact task revision reviewed by the client.
    if coalesce(v_move ->> 'expected_task_version', '') !~ '^[0-9]{1,10}$' then
      raise exception 'Task version required: refresh the plan before confirming'
        using errcode = '40001';
    end if;
    if (v_move ->> 'expected_task_version')::bigint <> v_task.version then
      raise exception 'Task edit conflict: refresh before confirming'
        using errcode = '40001';
    end if;

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
      and exists (select 1 from public.tasks occupied_task
        where occupied_task.id = i.task_id and occupied_task.user_id = c.user_id
          and occupied_task.status = 'planned')
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

create or replace function public.war_council_schema_version()
returns integer language sql stable security invoker
set search_path = ''
as $$ select 3; $$;
revoke all on function public.confirm_plan_change(jsonb,timestamptz,timestamptz,jsonb) from public, anon;
grant execute on function public.confirm_plan_change(jsonb,timestamptz,timestamptz,jsonb) to authenticated;
revoke all on function public.war_council_schema_version() from public, anon;
grant execute on function public.war_council_schema_version() to authenticated;
commit;
