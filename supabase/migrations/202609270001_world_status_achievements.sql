-- DRAFT: storage contract only. Validate on a disposable Supabase database.
-- Apply after 202609250001. No score calculation or achievement writer is installed.
begin;
alter table public.tasks add column load_category text
  check (load_category in ('study','errand','social','exercise','other'));
-- Preserve historical NULL; do not enforce new-client requirements yet.
create index tasks_user_category_due_idx on public.tasks(user_id, load_category, due_at);
alter table public.tasks add constraint tasks_id_user_unique unique(id, user_id);
alter table public.check_ins
  add column mental_energy_level text check (mental_energy_level in ('low','moderate','high')),
  add column physical_energy_level text check (physical_energy_level in ('low','moderate','high'));
-- Existing mental/physical/social/errands (1..5) retain their original meaning.

create table public.world_status_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  movement_tracking_enabled boolean not null default false,
  movement_target_days smallint not null default 3 check (movement_target_days between 1 and 14),
  target_recovery_minutes smallint not null default 30 check (target_recovery_minutes between 0 and 240),
  target_social_minutes_week smallint not null default 300 check (target_social_minutes_week between 0 and 2000),
  formula_version text not null default 'world_status_v1' check (formula_version = 'world_status_v1'),
  updated_at timestamptz not null default now()
);
create trigger world_status_settings_updated before update on public.world_status_settings
for each row execute function public.set_updated_at();

create table public.exercise_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  task_id uuid unique,
  occurred_at timestamptz not null,
  duration_minutes integer not null check (duration_minutes > 0),
  intensity text,
  source text not null default 'manual' check (source in ('manual','consented_import')),
  request_id uuid not null,
  created_at timestamptz not null default now(),
  unique(user_id, request_id),
  foreign key(task_id,user_id) references public.tasks(id,user_id) on delete restrict
);
create index exercise_logs_user_time_idx on public.exercise_logs(user_id,occurred_at desc);
create table public.social_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  task_id uuid unique,
  start_at timestamptz not null,
  end_at timestamptz not null check (end_at > start_at),
  pressure_level text not null check (pressure_level in ('low','moderate','high')),
  has_conflict boolean,
  request_id uuid not null,
  created_at timestamptz not null default now(),
  unique(user_id, request_id),
  foreign key(task_id,user_id) references public.tasks(id,user_id) on delete restrict
);
create index social_events_user_time_idx on public.social_events(user_id,start_at);
create table public.social_week_responses (
  user_id uuid not null references auth.users(id) on delete cascade,
  week_start date not null check (extract(isodow from week_start)=1),
  no_social_commitments boolean not null,
  updated_at timestamptz not null default now(),
  primary key(user_id,week_start)
);
create trigger social_week_responses_updated before update on public.social_week_responses
for each row execute function public.set_updated_at();
create table public.reflections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  local_date date not null,
  content text not null check (length(btrim(content)) > 0),
  request_id uuid not null,
  created_at timestamptz not null default now(),
  unique(user_id,request_id)
);
create index reflections_user_date_idx on public.reflections(user_id,local_date);
-- Acknowledgement is input evidence, never proof of eligibility by itself.
create table public.overload_reviews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  task_id uuid not null,
  local_date date not null,
  reviewed_at timestamptz not null default now(),
  request_id uuid not null,
  unique(user_id,request_id),
  foreign key(task_id,user_id) references public.tasks(id,user_id) on delete restrict
);
create index overload_reviews_user_date_idx on public.overload_reviews(user_id,local_date);

create table public.world_status_snapshots (
  user_id uuid not null references auth.users(id) on delete cascade,
  local_date date not null,
  mental_score numeric check (mental_score between 0 and 100),
  time_score numeric check (time_score between 0 and 100),
  physical_score numeric check (physical_score between 0 and 100),
  social_score numeric check (social_score between 0 and 100),
  errands_score numeric check (errands_score between 0 and 100),
  total_score smallint check (total_score between 0 and 100),
  known_dimensions text[] not null,
  coverage numeric not null check (coverage between 0 and 1),
  trend text not null check (trend in ('rising','stable','easing','not_enough_history')),
  formula_version text not null check (length(btrim(formula_version)) > 0),
  computed_at timestamptz not null default now(),
  primary key(user_id,local_date,formula_version),
  check (known_dimensions = array_remove(array[
    case when mental_score is not null then 'mental' end,
    case when time_score is not null then 'time' end,
    case when physical_score is not null then 'physical' end,
    case when social_score is not null then 'social' end,
    case when errands_score is not null then 'errands' end
  ], null)),
  check (coverage >= 0.6 or total_score is null)
);
create index world_status_snapshots_user_date_idx on public.world_status_snapshots(user_id,local_date desc);
create table public.achievement_definitions (
  achievement_key text not null,
  practical_name text not null,
  rpg_name text not null,
  unlock_condition text not null,
  rule_version text not null default 'achievements_v1',
  primary key(achievement_key,rule_version)
);
insert into public.achievement_definitions (achievement_key,practical_name,rpg_name,unlock_condition) values
('protected_rest','Protected Rest','Sanctuary Keeper','Persist protection for an actual sleep or recovery slot.'),
('safe_trade_off','Safe Trade-off','Wise Strategist','Commit a plan without breaking protected commitments.'),
('deadline_safety','Deadline Safety','Deadline Guardian','Persist a flexible task move that preserves its deadline.'),
('early_review','Early Review','Early Scout','Explicitly review an overload before the related local deadline day.'),
('protected_limit','Protected Limit','Contract Keeper','Persist protection for a work shift, family duty or sleep minimum.'),
('reflection','Reflection','Camp Journal Entry','Voluntarily save a non-empty reflection.'),
('team_coordination','Team Coordination','Team Navigator','Mark a genuinely shared task Needs Agreement without automatically moving it (V2).');
create table public.planning_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  event_key text not null check (length(btrim(event_key)) > 0),
  event_type text not null check (length(btrim(event_type)) > 0),
  occurred_at timestamptz not null,
  evidence jsonb not null check (jsonb_typeof(evidence)='object'),
  created_at timestamptz not null default now(),
  unique(user_id,event_key),
  unique(id,user_id)
);
create index planning_events_user_time_idx on public.planning_events(user_id,occurred_at);
create table public.user_achievements (
  user_id uuid not null references auth.users(id) on delete cascade,
  achievement_key text not null,
  rule_version text not null,
  source_event_id uuid not null,
  occurred_at timestamptz not null,
  awarded_at timestamptz not null default now(),
  primary key(user_id,achievement_key),
  foreign key(achievement_key,rule_version) references public.achievement_definitions(achievement_key,rule_version),
  foreign key(source_event_id,user_id) references public.planning_events(id,user_id) on delete restrict
);

alter table public.world_status_settings enable row level security;
revoke all on public.world_status_settings from public, anon, authenticated;
grant select on public.world_status_settings to authenticated;
grant all on public.world_status_settings to service_role;
create policy owner_read on public.world_status_settings for select to authenticated using (user_id = (select auth.uid()));
grant insert on public.world_status_settings to authenticated;
create policy owner_insert on public.world_status_settings for insert to authenticated with check (user_id = (select auth.uid()));
grant update, delete on public.world_status_settings to authenticated;
create policy owner_update on public.world_status_settings for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy owner_delete on public.world_status_settings for delete to authenticated using (user_id = (select auth.uid()));

alter table public.exercise_logs enable row level security;
revoke all on public.exercise_logs from public, anon, authenticated;
grant select on public.exercise_logs to authenticated;
grant all on public.exercise_logs to service_role;
create policy owner_read on public.exercise_logs for select to authenticated using (user_id = (select auth.uid()));
grant insert on public.exercise_logs to authenticated;
create policy owner_insert on public.exercise_logs for insert to authenticated with check (user_id = (select auth.uid()));
grant update, delete on public.exercise_logs to authenticated;
create policy owner_update on public.exercise_logs for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy owner_delete on public.exercise_logs for delete to authenticated using (user_id = (select auth.uid()));

alter table public.social_events enable row level security;
revoke all on public.social_events from public, anon, authenticated;
grant select on public.social_events to authenticated;
grant all on public.social_events to service_role;
create policy owner_read on public.social_events for select to authenticated using (user_id = (select auth.uid()));
grant insert on public.social_events to authenticated;
create policy owner_insert on public.social_events for insert to authenticated with check (user_id = (select auth.uid()));
grant update, delete on public.social_events to authenticated;
create policy owner_update on public.social_events for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy owner_delete on public.social_events for delete to authenticated using (user_id = (select auth.uid()));

alter table public.social_week_responses enable row level security;
revoke all on public.social_week_responses from public, anon, authenticated;
grant select on public.social_week_responses to authenticated;
grant all on public.social_week_responses to service_role;
create policy owner_read on public.social_week_responses for select to authenticated using (user_id = (select auth.uid()));
grant insert on public.social_week_responses to authenticated;
create policy owner_insert on public.social_week_responses for insert to authenticated with check (user_id = (select auth.uid()));
grant update, delete on public.social_week_responses to authenticated;
create policy owner_update on public.social_week_responses for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy owner_delete on public.social_week_responses for delete to authenticated using (user_id = (select auth.uid()));

alter table public.reflections enable row level security;
revoke all on public.reflections from public, anon, authenticated;
grant select on public.reflections to authenticated;
grant all on public.reflections to service_role;
create policy owner_read on public.reflections for select to authenticated using (user_id = (select auth.uid()));
grant insert on public.reflections to authenticated;
create policy owner_insert on public.reflections for insert to authenticated with check (user_id = (select auth.uid()));
grant update, delete on public.reflections to authenticated;
create policy owner_update on public.reflections for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy owner_delete on public.reflections for delete to authenticated using (user_id = (select auth.uid()));

alter table public.overload_reviews enable row level security;
revoke all on public.overload_reviews from public, anon, authenticated;
grant select on public.overload_reviews to authenticated;
grant all on public.overload_reviews to service_role;
create policy owner_read on public.overload_reviews for select to authenticated using (user_id = (select auth.uid()));
grant insert on public.overload_reviews to authenticated;
create policy owner_insert on public.overload_reviews for insert to authenticated with check (user_id = (select auth.uid()));

alter table public.world_status_snapshots enable row level security;
revoke all on public.world_status_snapshots from public, anon, authenticated;
grant select on public.world_status_snapshots to authenticated;
grant all on public.world_status_snapshots to service_role;
create policy owner_read on public.world_status_snapshots for select to authenticated using (user_id = (select auth.uid()));

alter table public.planning_events enable row level security;
revoke all on public.planning_events from public, anon, authenticated;
grant select on public.planning_events to authenticated;
grant all on public.planning_events to service_role;
create policy owner_read on public.planning_events for select to authenticated using (user_id = (select auth.uid()));

alter table public.user_achievements enable row level security;
revoke all on public.user_achievements from public, anon, authenticated;
grant select on public.user_achievements to authenticated;
grant all on public.user_achievements to service_role;
create policy owner_read on public.user_achievements for select to authenticated using (user_id = (select auth.uid()));

alter table public.achievement_definitions enable row level security;
revoke all on public.achievement_definitions from public, anon, authenticated;
grant select on public.achievement_definitions to authenticated;
grant all on public.achievement_definitions to service_role;
create policy catalogue_read on public.achievement_definitions for select to authenticated using (true);

revoke insert on public.overload_reviews from authenticated;
grant insert(user_id,task_id,local_date,request_id) on public.overload_reviews to authenticated;
commit;
