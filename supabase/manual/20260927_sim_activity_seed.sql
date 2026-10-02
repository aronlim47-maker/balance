-- Optional demo data for Lim Ze Heng's test account only.
-- Run in Supabase SQL Editor after 202609270001_world_status_achievements.sql.
-- These rows simulate activity; they are NOT real confirmed exercise or events.
-- Re-running is safe because IDs are fixed and conflicts are skipped.

begin;

insert into public.tasks
  (id, user_id, title, estimated_minutes, remaining_minutes, due_at,
   flexibility, status, load_category)
values
  ('21111111-1111-4111-8111-111111111101',
   'fe48fe73-861f-4108-8a9f-1dd47858a10e',
   '[SIM] Evening walk', 30, 30, now() + interval '2 days',
   'flexible', 'planned', 'exercise'),
  ('21111111-1111-4111-8111-111111111102',
   'fe48fe73-861f-4108-8a9f-1dd47858a10e',
   '[SIM] Badminton session', 60, 60, now() + interval '4 days',
   'flexible', 'planned', 'exercise'),
  ('21111111-1111-4111-8111-111111111103',
   'fe48fe73-861f-4108-8a9f-1dd47858a10e',
   '[SIM] Dinner with friends', 90, 90, now() + interval '5 days',
   'fixed', 'planned', 'social'),
  ('21111111-1111-4111-8111-111111111104',
   'fe48fe73-861f-4108-8a9f-1dd47858a10e',
   '[SIM] Club meetup', 120, 120, now() + interval '6 days',
   'fixed', 'planned', 'social')
on conflict (id) do nothing;

insert into public.world_status_settings
  (user_id, movement_tracking_enabled, movement_target_days)
values
  ('fe48fe73-861f-4108-8a9f-1dd47858a10e', true, 3)
on conflict (user_id) do update
set movement_tracking_enabled = true,
    movement_target_days = 3;

insert into public.exercise_logs
  (id, user_id, task_id, occurred_at, duration_minutes, intensity, source)
values
  ('31111111-1111-4111-8111-111111111101',
   'fe48fe73-861f-4108-8a9f-1dd47858a10e',
   '21111111-1111-4111-8111-111111111101',
   now() - interval '1 day', 30, 'low', 'manual'),
  ('31111111-1111-4111-8111-111111111102',
   'fe48fe73-861f-4108-8a9f-1dd47858a10e',
   '21111111-1111-4111-8111-111111111102',
   now() - interval '3 days', 60, 'moderate', 'manual')
on conflict (id) do nothing;

-- Events are placed inside the current Malaysia-local Monday-Sunday week,
-- so the Today card can read them regardless of which day is selected.
insert into public.social_events
  (id, user_id, task_id, start_at, end_at, pressure_level)
values
  ('41111111-1111-4111-8111-111111111101',
   'fe48fe73-861f-4108-8a9f-1dd47858a10e',
   '21111111-1111-4111-8111-111111111103',
   (date_trunc('week', timezone('Asia/Kuala_Lumpur', now()))
     + interval '1 day 18 hours') at time zone 'Asia/Kuala_Lumpur',
   (date_trunc('week', timezone('Asia/Kuala_Lumpur', now()))
     + interval '1 day 19 hours 30 minutes') at time zone 'Asia/Kuala_Lumpur',
   'low'),
  ('41111111-1111-4111-8111-111111111102',
   'fe48fe73-861f-4108-8a9f-1dd47858a10e',
   '21111111-1111-4111-8111-111111111104',
   (date_trunc('week', timezone('Asia/Kuala_Lumpur', now()))
     + interval '5 days 14 hours') at time zone 'Asia/Kuala_Lumpur',
   (date_trunc('week', timezone('Asia/Kuala_Lumpur', now()))
     + interval '5 days 16 hours') at time zone 'Asia/Kuala_Lumpur',
   'moderate')
on conflict (id) do nothing;

commit;

select load_category, count(*)
from public.tasks
where user_id = 'fe48fe73-861f-4108-8a9f-1dd47858a10e'
  and id in (
    '21111111-1111-4111-8111-111111111101',
    '21111111-1111-4111-8111-111111111102',
    '21111111-1111-4111-8111-111111111103',
    '21111111-1111-4111-8111-111111111104'
  )
group by load_category;
