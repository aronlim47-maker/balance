-- Additive schema for World Status and the seven Journey achievements.
-- Apply after 202609250001_war_council_integrity.sql.
-- This migration does not rewrite applied migrations or backfill unknown facts.
-- The current Flutter client does not yet send load_category. Keep legacy and
-- transitional task rows nullable; enforce required category in a later
-- migration after every supported client sends it.

alter table public.tasks
  add column load_category text
    check (load_category in ('study', 'errand', 'social', 'exercise', 'other')),
  add column protected_commitment_type text
    check (protected_commitment_type in
      ('work_shift', 'family_duty', 'sleep_minimum')),
  add constraint tasks_commitment_requires_protection
    check (protected_commitment_type is null or is_protected);

create index tasks_user_category_due_idx
  on public.tasks (user_id, load_category, due_at);

-- Composite foreign keys prevent an owned activity from linking to a task
-- belonging to another account. The primary key alone is insufficient for it.
alter table public.tasks
  add constraint tasks_user_id_id_unique unique (user_id, id);

grant insert (load_category, protected_commitment_type)
  on public.tasks to authenticated;
grant update (load_category, protected_commitment_type)
  on public.tasks to authenticated;

alter table public.check_ins
  add column mental_energy_level text
    check (mental_energy_level in ('low', 'moderate', 'high')),
  add column physical_energy_level text
    check (physical_energy_level in ('low', 'moderate', 'high'));

-- The older numeric mental/physical/social/errands fields remain untouched.
-- They need a semantic audit before any formula uses them.

create table public.world_status_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  movement_tracking_enabled boolean not null default false,
  movement_target_days smallint not null default 3
    check (movement_target_days between 1 and 14),
  target_recovery_minutes smallint not null default 30
    check (target_recovery_minutes between 0 and 240),
  target_social_minutes_week smallint not null default 300
    check (target_social_minutes_week between 0 and 2000),
  formula_version text not null default 'world_status_v1'
    check (formula_version = 'world_status_v1'),
  updated_at timestamptz not null default now()
);

create trigger world_status_settings_set_updated_at
before update on public.world_status_settings
for each row execute function public.set_updated_at();

create table public.exercise_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  task_id uuid,
  occurred_at timestamptz not null,
  duration_minutes integer not null check (duration_minutes between 1 and 1440),
  intensity text check (intensity in ('low', 'moderate', 'high')),
  source text not null check (source in ('manual', 'task_confirmation')),
  created_at timestamptz not null default now(),
  foreign key (user_id, task_id)
    references public.tasks(user_id, id) on delete set null (task_id),
  unique (user_id, task_id)
);

create index exercise_logs_user_occurred_idx
  on public.exercise_logs (user_id, occurred_at desc);

create table public.social_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  task_id uuid,
  start_at timestamptz not null,
  end_at timestamptz not null,
  pressure_level text not null
    check (pressure_level in ('neutral', 'low', 'moderate', 'high')),
  created_at timestamptz not null default now(),
  check (end_at > start_at),
  foreign key (user_id, task_id)
    references public.tasks(user_id, id) on delete set null (task_id),
  unique (user_id, task_id)
);

create index social_events_user_start_idx
  on public.social_events (user_id, start_at);

-- An empty social-events result is Unknown. A known zero requires this
-- explicit response for the corresponding local week.
create table public.social_week_responses (
  user_id uuid not null references auth.users(id) on delete cascade,
  week_start date not null,
  no_commitments boolean not null,
  recorded_at timestamptz not null default now(),
  primary key (user_id, week_start)
);

create table public.world_status_snapshots (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  local_date date not null,
  mental_score numeric(5,2) check (mental_score between 0 and 100),
  time_score numeric(5,2) check (time_score between 0 and 100),
  physical_score numeric(5,2) check (physical_score between 0 and 100),
  social_score numeric(5,2) check (social_score between 0 and 100),
  errands_score numeric(5,2) check (errands_score between 0 and 100),
  total_score smallint check (total_score between 0 and 100),
  known_dimensions text[] not null default '{}'::text[],
  coverage numeric(4,3) not null check (coverage between 0 and 1),
  trend text not null default 'not_enough_history'
    check (trend in ('rising', 'stable', 'easing', 'not_enough_history')),
  formula_version text not null default 'world_status_v1'
    check (formula_version = 'world_status_v1'),
  computed_at timestamptz not null default now(),
  unique (user_id, local_date, formula_version),
  check (cardinality(known_dimensions) <= 5),
  check (known_dimensions <@ array[
    'mental', 'time', 'physical', 'social', 'errands'
  ]::text[]),
  check ((coverage < 0.6 and total_score is null)
    or coverage >= 0.6)
);

create index world_status_snapshots_user_date_idx
  on public.world_status_snapshots (user_id, local_date desc);

-- Versioned catalogue is read only to the mobile app. The practical name
-- appears first; the RPG name is optional decoration.
create table public.achievement_definitions (
  achievement_key text not null,
  rule_version text not null default 'achievement_v1',
  practical_name text not null,
  rpg_name text not null,
  condition_text text not null,
  display_order smallint not null unique,
  primary key (achievement_key, rule_version),
  check (achievement_key in (
    'protected_rest', 'safe_trade_off', 'deadline_safety',
    'early_review', 'protected_limit', 'reflection',
    'team_coordination'
  )),
  check (rule_version = 'achievement_v1')
);

insert into public.achievement_definitions
  (achievement_key, rule_version, practical_name, rpg_name,
   condition_text, display_order)
values
  ('protected_rest', 'achievement_v1', 'Protected Rest',
   'Sanctuary Keeper', 'Protect a sleep or recovery slot.', 1),
  ('safe_trade_off', 'achievement_v1', 'Safe Trade-off',
   'Wise Strategist',
   'Confirm a plan without breaking protected commitments.', 2),
  ('deadline_safety', 'achievement_v1', 'Deadline Safety',
   'Deadline Guardian',
   'Move a flexible task while keeping its deadline safe.', 3),
  ('early_review', 'achievement_v1', 'Early Review',
   'Early Scout', 'Review an overload before the deadline day.', 4),
  ('protected_limit', 'achievement_v1', 'Protected Limit',
   'Contract Keeper',
   'Protect a work shift, family duty or sleep minimum.', 5),
  ('reflection', 'achievement_v1', 'Reflection',
   'Camp Journal Entry', 'Save a completed optional reflection.', 6),
  ('team_coordination', 'achievement_v1', 'Team Coordination',
   'Team Navigator',
   'Mark a shared task as Needs Agreement without moving it.', 7);

create table public.reflections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (length(btrim(body)) > 0),
  created_at timestamptz not null default now()
);

create index reflections_user_created_idx
  on public.reflections (user_id, created_at desc);

-- Explicit acknowledgement for Early Review. The trusted award evaluator
-- must still verify actual overload and the task's local deadline date.
create table public.overload_reviews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  task_id uuid not null,
  reviewed_at timestamptz not null default now(),
  foreign key (user_id, task_id)
    references public.tasks(user_id, id) on delete cascade
);

create index overload_reviews_user_date_idx
  on public.overload_reviews (user_id, reviewed_at desc);

-- These two tables are written only by trusted evidence evaluation. The
-- client can read its own history but cannot submit isEligible or awards.
create table public.planning_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  event_type text not null check (event_type in (
    'protected_rest', 'safe_trade_off', 'deadline_safety',
    'early_review', 'protected_limit', 'reflection',
    'team_coordination'
  )),
  source_key text not null check (length(btrim(source_key)) > 0),
  source_record_id uuid,
  occurred_at timestamptz not null,
  evidence jsonb not null default '{}'::jsonb
    check (jsonb_typeof(evidence) = 'object'),
  created_at timestamptz not null default now(),
  unique (user_id, event_type, source_key),
  unique (user_id, id)
);

create index planning_events_user_occurred_idx
  on public.planning_events (user_id, occurred_at desc);

create table public.user_achievements (
  user_id uuid not null references auth.users(id) on delete cascade,
  achievement_key text not null,
  rule_version text not null default 'achievement_v1',
  source_event_id uuid not null,
  occurred_at timestamptz not null,
  awarded_at timestamptz not null default now(),
  primary key (user_id, achievement_key),
  foreign key (achievement_key, rule_version)
    references public.achievement_definitions(achievement_key, rule_version),
  foreign key (user_id, source_event_id)
    references public.planning_events(user_id, id) on delete restrict
);

create index user_achievements_user_awarded_idx
  on public.user_achievements (user_id, awarded_at desc);

alter table public.world_status_settings enable row level security;
alter table public.exercise_logs enable row level security;
alter table public.social_events enable row level security;
alter table public.social_week_responses enable row level security;
alter table public.world_status_snapshots enable row level security;
alter table public.achievement_definitions enable row level security;
alter table public.reflections enable row level security;
alter table public.overload_reviews enable row level security;
alter table public.planning_events enable row level security;
alter table public.user_achievements enable row level security;

revoke all on table public.world_status_settings from anon, authenticated;
revoke all on table public.exercise_logs from anon, authenticated;
revoke all on table public.social_events from anon, authenticated;
revoke all on table public.social_week_responses from anon, authenticated;
revoke all on table public.world_status_snapshots from anon, authenticated;
revoke all on table public.achievement_definitions from anon, authenticated;
revoke all on table public.reflections from anon, authenticated;
revoke all on table public.overload_reviews from anon, authenticated;
revoke all on table public.planning_events from anon, authenticated;
revoke all on table public.user_achievements from anon, authenticated;

grant select on public.world_status_settings to authenticated;
grant insert (user_id, movement_tracking_enabled, movement_target_days,
  target_recovery_minutes, target_social_minutes_week)
  on public.world_status_settings to authenticated;
grant update (movement_tracking_enabled, movement_target_days,
  target_recovery_minutes, target_social_minutes_week)
  on public.world_status_settings to authenticated;
grant select, insert, update, delete on public.exercise_logs to authenticated;
grant select, insert, update, delete on public.social_events to authenticated;
grant select, insert, update, delete
  on public.social_week_responses to authenticated;
grant select on public.world_status_snapshots to authenticated;
grant select on public.achievement_definitions to authenticated;
grant select, insert, update, delete on public.reflections to authenticated;
grant select, insert, delete on public.overload_reviews to authenticated;
grant select on public.planning_events to authenticated;
grant select on public.user_achievements to authenticated;

create policy world_status_settings_own on public.world_status_settings
for all to authenticated
using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy exercise_logs_own on public.exercise_logs
for all to authenticated
using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy social_events_own on public.social_events
for all to authenticated
using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy social_week_responses_own on public.social_week_responses
for all to authenticated
using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy world_status_snapshots_own_read
on public.world_status_snapshots for select to authenticated
using (user_id = auth.uid());

create policy achievement_definitions_read
on public.achievement_definitions for select to authenticated
using (true);

create policy reflections_own on public.reflections
for all to authenticated
using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy overload_reviews_own on public.overload_reviews
for all to authenticated
using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy planning_events_own_read
on public.planning_events for select to authenticated
using (user_id = auth.uid());

create policy user_achievements_own_read
on public.user_achievements for select to authenticated
using (user_id = auth.uid());

-- Follow-up work before calling these features complete:
-- 1. Implement the trusted World Status calculator and snapshot writer.
-- 2. Implement verified, idempotent event and achievement evaluation.
-- 3. Add a later enforcement migration for required new-task category after
--    the Flutter form and every supported client submit load_category.
-- 4. Do not award Team Coordination until real shared-task evidence exists.
