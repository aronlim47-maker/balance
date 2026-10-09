create extension if not exists pgcrypto;
create extension if not exists btree_gist;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  time_zone text not null default 'UTC',
  created_at timestamptz not null default now()
);

create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (length(trim(title)) > 0),
  estimated_minutes integer not null check (estimated_minutes > 0),
  remaining_minutes integer not null check (
    remaining_minutes >= 0 and remaining_minutes <= estimated_minutes
  ),
  due_at timestamptz not null,
  scheduled_start timestamptz,
  scheduled_end timestamptz,
  flexibility text not null default 'flexible'
    check (flexibility in ('fixed', 'flexible', 'needs_agreement')),
  is_protected boolean not null default false,
  is_optional boolean not null default false,
  status text not null default 'planned'
    check (status in ('planned', 'completed', 'cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1 check (version > 0),
  check (
    (scheduled_start is null and scheduled_end is null)
    or (
      scheduled_start is not null
      and scheduled_end is not null
      and scheduled_end > scheduled_start
    )
  ),
  check (
    scheduled_start is null
    or extract(epoch from (scheduled_end - scheduled_start)) / 60 = remaining_minutes
  ),
  check (scheduled_end is null or scheduled_end <= due_at),
  exclude using gist (
    user_id with =,
    tstzrange(scheduled_start, scheduled_end, '[)') with &&
  ) where (status = 'planned' and scheduled_start is not null)
);

create table public.availability_blocks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  start_at timestamptz not null,
  end_at timestamptz not null,
  block_type text not null check (block_type in ('available', 'blocked')),
  label text,
  created_at timestamptz not null default now(),
  check (end_at > start_at),
  exclude using gist (
    user_id with =,
    tstzrange(start_at, end_at, '[)') with &&
  )
);

create table public.check_ins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  check_in_date date not null,
  sleep_hours numeric(4,1) check (sleep_hours between 0 and 24),
  mental smallint check (mental between 1 and 5),
  physical smallint check (physical between 1 and 5),
  social smallint check (social between 1 and 5),
  errands smallint check (errands between 1 and 5),
  created_at timestamptz not null default now(),
  unique (user_id, check_in_date)
);

create table public.plan_changes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'draft'
    check (status in ('draft', 'confirmed', 'undone')),
  before_overload_minutes integer not null default 0 check (before_overload_minutes >= 0),
  after_overload_minutes integer not null default 0 check (after_overload_minutes >= 0),
  validation_status text not null default 'needs_review'
    check (validation_status in ('feasible', 'needs_review', 'needs_agreement', 'no_feasible_plan')),
  consequences jsonb not null default '{}'::jsonb,
  failure_reason text,
  confirmed_at timestamptz,
  undone_at timestamptz,
  created_at timestamptz not null default now(),
  check (after_overload_minutes <= before_overload_minutes),
  check (
    (status = 'draft' and confirmed_at is null and undone_at is null)
    or (status = 'confirmed' and confirmed_at is not null and undone_at is null)
    or (status = 'undone' and confirmed_at is not null and undone_at is not null)
  ),
  check (status <> 'confirmed' or validation_status = 'feasible')
);

create table public.plan_change_items (
  id uuid primary key default gen_random_uuid(),
  plan_change_id uuid not null references public.plan_changes(id) on delete cascade,
  task_id uuid not null references public.tasks(id) on delete restrict,
  original_start timestamptz,
  original_end timestamptz,
  proposed_start timestamptz not null,
  proposed_end timestamptz not null,
  moved_minutes integer not null check (moved_minutes > 0),
  original_remaining_minutes integer not null check (original_remaining_minutes >= 0),
  proposed_remaining_minutes integer not null check (proposed_remaining_minutes >= 0),
  original_task_version integer not null check (original_task_version > 0),
  applied_task_version integer not null check (applied_task_version > original_task_version),
  created_at timestamptz not null default now(),
  check (
    (original_start is null and original_end is null)
    or (
      original_start is not null
      and original_end is not null
      and original_end > original_start
    )
  ),
  check (proposed_end > proposed_start),
  check (extract(epoch from (proposed_end - proposed_start)) / 60 = moved_minutes),
  check (original_remaining_minutes - moved_minutes = proposed_remaining_minutes),
  unique (plan_change_id, task_id)
);

create table public.recovery_slots (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  plan_change_id uuid references public.plan_changes(id) on delete set null,
  start_at timestamptz not null,
  end_at timestamptz not null,
  is_protected boolean not null default true,
  selected_activity text,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  check (end_at > start_at),
  exclude using gist (
    user_id with =,
    tstzrange(start_at, end_at, '[)') with &&
  )
);

create index tasks_user_due_idx on public.tasks(user_id, due_at);
create index tasks_user_schedule_idx on public.tasks(user_id, scheduled_start, scheduled_end);
create index availability_user_time_idx on public.availability_blocks(user_id, start_at, end_at);
create index plan_changes_user_created_idx on public.plan_changes(user_id, created_at desc);
create index recovery_slots_user_time_idx on public.recovery_slots(user_id, start_at, end_at);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger tasks_set_updated_at
before update on public.tasks
for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'display_name', ''));
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

create or replace function public.validate_profile_time_zone()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if not exists (
    select 1 from pg_catalog.pg_timezone_names
    where name = new.time_zone
  ) then
    raise exception 'Unknown time zone: %', new.time_zone;
  end if;
  return new;
end;
$$;

create trigger profiles_validate_time_zone
before insert or update of time_zone on public.profiles
for each row execute function public.validate_profile_time_zone();

alter table public.profiles enable row level security;
alter table public.tasks enable row level security;
alter table public.availability_blocks enable row level security;
alter table public.check_ins enable row level security;
alter table public.plan_changes enable row level security;
alter table public.plan_change_items enable row level security;
alter table public.recovery_slots enable row level security;

revoke all on table public.profiles from anon, authenticated;
revoke all on table public.tasks from anon, authenticated;
revoke all on table public.availability_blocks from anon, authenticated;
revoke all on table public.check_ins from anon, authenticated;
revoke all on table public.plan_changes from anon, authenticated;
revoke all on table public.plan_change_items from anon, authenticated;
revoke all on table public.recovery_slots from anon, authenticated;

grant select on public.profiles to authenticated;
grant update (display_name, time_zone) on public.profiles to authenticated;
grant select, delete on public.tasks to authenticated;
grant insert (
  user_id, title, estimated_minutes, remaining_minutes, due_at,
  flexibility, is_protected, is_optional, status
) on public.tasks to authenticated;
grant update (
  title, estimated_minutes, due_at, flexibility, is_protected, is_optional, status
) on public.tasks to authenticated;
grant select, insert, update, delete on public.availability_blocks to authenticated;
grant select, insert, update, delete on public.check_ins to authenticated;
grant select on public.plan_changes to authenticated;
grant select on public.plan_change_items to authenticated;
grant select, insert, update, delete on public.recovery_slots to authenticated;

create policy profiles_own_rows on public.profiles
for all to authenticated
using (id = auth.uid())
with check (id = auth.uid());

create policy tasks_own_rows on public.tasks
for all to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy availability_own_rows on public.availability_blocks
for all to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy check_ins_own_rows on public.check_ins
for all to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy plan_changes_own_rows on public.plan_changes
for all to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy plan_change_items_own_rows on public.plan_change_items
for all to authenticated
using (
  exists (
    select 1 from public.plan_changes
    where plan_changes.id = plan_change_items.plan_change_id
      and plan_changes.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.plan_changes
    where plan_changes.id = plan_change_items.plan_change_id
      and plan_changes.user_id = auth.uid()
  )
  and exists (
    select 1 from public.tasks
    where tasks.id = plan_change_items.task_id
      and tasks.user_id = auth.uid()
  )
);

create policy recovery_slots_select_own on public.recovery_slots
for select to authenticated
using (user_id = auth.uid());

create policy recovery_slots_insert_own on public.recovery_slots
for insert to authenticated
with check (user_id = auth.uid() and plan_change_id is null);

create policy recovery_slots_update_manual on public.recovery_slots
for update to authenticated
using (user_id = auth.uid() and plan_change_id is null)
with check (user_id = auth.uid() and plan_change_id is null);

create policy recovery_slots_delete_manual on public.recovery_slots
for delete to authenticated
using (user_id = auth.uid() and plan_change_id is null);

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
  v_available_minutes integer;
  v_planned_minutes integer;
begin
  if p_user_id <> auth.uid() then
    raise exception 'Cannot calculate another user''s capacity';
  end if;

  select time_zone into v_time_zone
  from public.profiles
  where id = p_user_id;

  v_day_start := p_day::timestamp at time zone coalesce(v_time_zone, 'UTC');
  v_day_end := (p_day + 1)::timestamp at time zone coalesce(v_time_zone, 'UTC');

  select coalesce(sum(
    extract(epoch from (
      least(end_at, v_day_end) - greatest(start_at, v_day_start)
    )) / 60
  ), 0)::integer
  into v_available_minutes
  from public.availability_blocks
  where user_id = p_user_id
    and block_type = 'available'
    and start_at < v_day_end
    and end_at > v_day_start;

  select (
    coalesce((
      select sum(extract(epoch from (
        least(t.scheduled_end, v_day_end) - greatest(t.scheduled_start, v_day_start)
      )) / 60)
      from public.tasks t
      where t.user_id = p_user_id
        and t.status = 'planned'
        and t.scheduled_start < v_day_end
        and t.scheduled_end > v_day_start
    ), 0)
    + coalesce((
      select sum(extract(epoch from (
        least(i.proposed_end, v_day_end) - greatest(i.proposed_start, v_day_start)
      )) / 60)
      from public.plan_change_items i
      join public.plan_changes c on c.id = i.plan_change_id
      where c.user_id = p_user_id
        and c.status = 'confirmed'
        and i.proposed_start < v_day_end
        and i.proposed_end > v_day_start
    ), 0)
    + coalesce((
      select sum(extract(epoch from (
        least(r.end_at, v_day_end) - greatest(r.start_at, v_day_start)
      )) / 60)
      from public.recovery_slots r
      where r.user_id = p_user_id
        and r.is_protected
        and r.start_at < v_day_end
        and r.end_at > v_day_start
    ), 0)
  )::integer
  into v_planned_minutes;

  return greatest(0, v_planned_minutes - v_available_minutes);
end;
$$;

create or replace function public.validate_recovery_slot()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.user_id <> auth.uid() then
    raise exception 'Recovery slot must belong to the authenticated user';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(new.user_id::text, 0));
  if not exists (
    select 1 from public.availability_blocks b
    where b.user_id = new.user_id
      and b.block_type = 'available'
      and b.start_at <= new.start_at
      and b.end_at >= new.end_at
  ) then
    raise exception 'Recovery slot must fit inside available time';
  end if;
  if exists (
    select 1 from public.tasks t
    where t.user_id = new.user_id
      and t.status = 'planned'
      and t.scheduled_start < new.end_at
      and t.scheduled_end > new.start_at
  ) then
    raise exception 'Recovery slot overlaps a scheduled task';
  end if;
  if exists (
    select 1 from public.plan_change_items i
    join public.plan_changes c on c.id = i.plan_change_id
    where c.user_id = new.user_id
      and c.status = 'confirmed'
      and i.proposed_start < new.end_at
      and i.proposed_end > new.start_at
  ) then
    raise exception 'Recovery slot overlaps a moved task';
  end if;
  return new;
end;
$$;

create trigger recovery_slots_validate
before insert or update on public.recovery_slots
for each row execute function public.validate_recovery_slot();

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
  v_proposed_start timestamptz;
  v_proposed_end timestamptz;
  v_moved_minutes integer;
  v_dates date[] := '{}'::date[];
  v_date date;
  v_before_overload integer := 0;
  v_after_overload integer := 0;
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

  for v_move in select value from jsonb_array_elements(p_moves)
  loop
    v_proposed_start := (v_move ->> 'proposed_start')::timestamptz;
    v_proposed_end := (v_move ->> 'proposed_end')::timestamptz;
    v_moved_minutes := (v_move ->> 'moved_minutes')::integer;

    select * into strict v_task
    from public.tasks
    where id = (v_move ->> 'task_id')::uuid and user_id = v_user_id
    for update;

    if v_moved_minutes <= 0 or v_moved_minutes > v_task.remaining_minutes then
      raise exception 'Moved minutes exceed the task''s remaining work';
    end if;
    if extract(epoch from (v_proposed_end - v_proposed_start)) / 60 <> v_moved_minutes then
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
    if not exists (
      select 1 from public.availability_blocks b
      where b.user_id = v_user_id
        and b.block_type = 'available'
        and b.start_at <= v_proposed_start
        and b.end_at >= v_proposed_end
    ) then
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

    if v_task.scheduled_start is not null then
      v_dates := array_append(
        v_dates,
        timezone(coalesce(v_time_zone, 'UTC'), v_task.scheduled_start)::date
      );
    end if;
    v_dates := array_append(
      v_dates,
      timezone(coalesce(v_time_zone, 'UTC'), v_proposed_start)::date
    );
  end loop;

  if p_recovery_start is not null then
    v_dates := array_append(
      v_dates,
      timezone(coalesce(v_time_zone, 'UTC'), p_recovery_start)::date
    );
  end if;

  for v_date in select distinct unnest(v_dates)
  loop
    v_before_overload := greatest(
      v_before_overload,
      public.calculate_day_overload(v_user_id, v_date)
    );
  end loop;

  insert into public.plan_changes (
    user_id, status, before_overload_minutes, after_overload_minutes,
    validation_status, consequences
  ) values (
    v_user_id, 'draft', v_before_overload, 0, 'feasible', coalesce(p_consequences, '{}'::jsonb)
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
          else scheduled_start + make_interval(mins => remaining_minutes - v_moved_minutes)
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
    raise exception 'Plan still exceeds available capacity by % minutes', v_after_overload;
  end if;

  update public.plan_changes
  set after_overload_minutes = v_after_overload
  where id = v_change_id;

  return v_change_id;
end;
$$;

create or replace function public.undo_plan_change(p_change_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_change public.plan_changes%rowtype;
  v_item public.plan_change_items%rowtype;
  v_task public.tasks%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text, 0));

  select * into strict v_change
  from public.plan_changes
  where id = p_change_id and user_id = auth.uid()
  for update;

  if v_change.status <> 'confirmed' then
    raise exception 'Only a confirmed plan can be undone';
  end if;

  for v_item in
    select * from public.plan_change_items where plan_change_id = p_change_id
  loop
    select * into strict v_task
    from public.tasks
    where id = v_item.task_id and user_id = auth.uid()
    for update;

    if v_task.version <> v_item.applied_task_version then
      raise exception 'Task changed after this plan; undo would overwrite newer work';
    end if;
  end loop;

  for v_item in
    select * from public.plan_change_items where plan_change_id = p_change_id
  loop
    update public.tasks
    set scheduled_start = v_item.original_start,
        scheduled_end = v_item.original_end,
        remaining_minutes = v_item.original_remaining_minutes,
        version = version + 1
    where id = v_item.task_id and user_id = auth.uid();
  end loop;

  delete from public.recovery_slots
  where plan_change_id = p_change_id and user_id = auth.uid();

  update public.plan_changes
  set status = 'undone', undone_at = now()
  where id = p_change_id;
end;
$$;

revoke all on function public.set_updated_at() from public;
revoke all on function public.handle_new_user() from public;
revoke all on function public.validate_profile_time_zone() from public;
revoke all on function public.validate_recovery_slot() from public;
revoke all on function public.calculate_day_overload(uuid, date) from public;
revoke all on function public.confirm_plan_change(jsonb, timestamptz, timestamptz, jsonb) from public;
revoke all on function public.undo_plan_change(uuid) from public;
grant execute on function public.calculate_day_overload(uuid, date) to authenticated;
grant execute on function public.confirm_plan_change(jsonb, timestamptz, timestamptz, jsonb) to authenticated;
grant execute on function public.undo_plan_change(uuid) to authenticated;
