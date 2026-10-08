-- REVIEWED TARGET REQUIRED. Run with psql as project owner after all migrations:
-- -v judge_user=UUID -v judge_email=EXACT_EMAIL -v demo_date=YYYY-MM-DD
-- -v persist=false (default) previews with ROLLBACK; persist=true commits fixtures.
-- New, dedicated empty account only. Does not create Auth users or award history.
\set ON_ERROR_STOP on
\if :{?persist}
\else
\set persist false
\endif
begin;
select set_config('balance.judge_user', :'judge_user', true);
select set_config('balance.judge_email', :'judge_email', true);
select set_config('balance.demo_date', :'demo_date', true);
do $$
declare u uuid := current_setting('balance.judge_user')::uuid;
  d date := current_setting('balance.demo_date')::date;
  zone text;
  a timestamptz;
  b timestamptz;
begin
  if not exists(select 1 from auth.users where id=u and email=current_setting('balance.judge_email')) then
    raise exception 'Judge UUID/email do not match an existing Auth account';
  end if;
  select time_zone into zone from public.profiles where id=u for update;
  if zone is null then raise exception 'Judge profile missing'; end if;
  perform pg_advisory_xact_lock(hashtextextended(u::text,0));
  if d < (now() at time zone zone)::date then raise exception 'Demo day must not be in the past'; end if;
  if exists(select 1 from public.tasks where user_id=u)
    or exists(select 1 from public.availability_blocks where user_id=u)
    or exists(select 1 from public.recovery_slots where user_id=u)
    or exists(select 1 from public.plan_changes where user_id=u)
    or exists(select 1 from public.user_achievements where user_id=u)
    or exists(select 1 from public.world_status_snapshots where user_id=u)
    or exists(select 1 from public.exercise_logs where user_id=u)
    or exists(select 1 from public.social_events where user_id=u)
    or exists(select 1 from public.reflections where user_id=u)
    or exists(select 1 from public.check_ins where user_id=u)
    or exists(select 1 from public.planning_events where user_id=u) then
    raise exception 'Use an empty dedicated judge account; existing data is never cleared or overwritten';
  end if;
  a := (d + time '09:00') at time zone zone;
  b := ((d+1) + time '09:00') at time zone zone;
  insert into public.availability_blocks(user_id,start_at,end_at,block_type,label) values
    (u,a,a+interval '3 hours','available','Judge demo: day 1'),
    (u,b,b+interval '2 hours','available','Judge demo: day 2');
  insert into public.tasks(user_id,title,estimated_minutes,remaining_minutes,due_at,
    scheduled_start,scheduled_end,load_category) values
    (u,'Judge demo: flexible report',180,180,b+interval '8 hours',a,a+interval '3 hours','study');
  insert into public.tasks(user_id,title,estimated_minutes,remaining_minutes,due_at,load_category)
    values(u,'Judge demo: deadline work',120,120,a+interval '8 hours','study');
  if public.calculate_day_overload(u,d) <> 120 then
    raise exception 'Fixture must produce 300 planned minus 180 available = 120 overload';
  end if;
end $$;
select current_setting('balance.judge_user') as judge_user,
  current_setting('balance.demo_date') as demo_date, 300 as planned_minutes,
  180 as available_minutes,120 as overload_minutes;
\if :persist
commit;
\echo 'Judge fixture committed to the explicitly selected account.'
\else
rollback;
\echo 'Preview passed; all fixture writes rolled back. No demo data persisted.'
\endif
