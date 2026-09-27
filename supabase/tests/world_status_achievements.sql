-- Run with psql against a DISPOSABLE Supabase database after all migrations:
-- psql "$TEST_DATABASE_URL" -v ON_ERROR_STOP=1 -v user_a=UUID -v user_b=UUID -f this_file
-- Create the two test users through Supabase Auth first. All fixture writes roll back.
\set ON_ERROR_STOP on
begin;
select set_config('balance.test_user_a', :'user_a', true);
select set_config('balance.test_user_b', :'user_b', true);
do $$
begin
  if current_setting('balance.test_user_a') = current_setting('balance.test_user_b') then
    raise exception 'Use two different test users';
  end if;
  if (select count(*) from auth.users where id in (
    current_setting('balance.test_user_a')::uuid,
    current_setting('balance.test_user_b')::uuid)) <> 2 then
    raise exception 'Both test users must already exist';
  end if;
end $$;

create function pg_temp.assert_true(ok boolean, message text) returns void
language plpgsql as $$ begin
  if ok is distinct from true then raise exception 'FAIL: %', message; end if;
end $$;

do $$
declare t text;
begin
  foreach t in array array['world_status_settings','exercise_logs','social_events',
    'social_week_responses','reflections','overload_reviews','world_status_snapshots',
    'achievement_definitions','planning_events','user_achievements'] loop
    perform pg_temp.assert_true((select relrowsecurity from pg_class
      where oid = ('public.' || t)::regclass), t || ' RLS enabled');
    perform pg_temp.assert_true(not has_table_privilege('anon','public.'||t,'SELECT'), t || ' anon denied');
  end loop;
  foreach t in array array['world_status_snapshots','planning_events','user_achievements','achievement_definitions'] loop
    perform pg_temp.assert_true(not has_table_privilege('authenticated','public.'||t,'INSERT,UPDATE,DELETE'),t || ' client writes denied');
  end loop;
  perform pg_temp.assert_true((select count(*)=7 from public.achievement_definitions), 'seven definitions');
end $$;

insert into public.tasks(id,user_id,title,estimated_minutes,remaining_minutes,due_at)
values ('00000000-0000-4000-8000-0000000000a1',current_setting('balance.test_user_a')::uuid,'Legacy A',30,30,'2099-01-01T00:00:00Z'),
       ('00000000-0000-4000-8000-0000000000b1',current_setting('balance.test_user_b')::uuid,'Task B',30,30,'2099-01-01T00:00:00Z');
select pg_temp.assert_true((select load_category is null from public.tasks
  where id='00000000-0000-4000-8000-0000000000a1'), 'legacy category preserved');

insert into public.planning_events(id,user_id,event_key,event_type,occurred_at,evidence)
values ('00000000-0000-4000-8000-0000000000e1',current_setting('balance.test_user_a')::uuid,
  'sql-test:event-a','fixture',now(),'{}');
insert into public.user_achievements(user_id,achievement_key,rule_version,source_event_id,occurred_at)
values(current_setting('balance.test_user_a')::uuid,'reflection','achievements_v1',
  '00000000-0000-4000-8000-0000000000e1',now());
do $$ begin
  begin
    insert into public.user_achievements(user_id,achievement_key,rule_version,source_event_id,occurred_at)
    values(current_setting('balance.test_user_a')::uuid,'reflection','achievements_v1',
      '00000000-0000-4000-8000-0000000000e1',now());
    raise exception 'FAIL: duplicate award accepted';
  exception when unique_violation then null; end;
  begin
    insert into public.user_achievements(user_id,achievement_key,rule_version,source_event_id,occurred_at)
    values(current_setting('balance.test_user_b')::uuid,'reflection','achievements_v1',
      '00000000-0000-4000-8000-0000000000e1',now());
    raise exception 'FAIL: cross-user event link accepted';
  exception when foreign_key_violation then null; end;
end $$;

select set_config('request.jwt.claim.sub', current_setting('balance.test_user_a'), true);
set local role authenticated;
insert into public.exercise_logs(user_id,task_id,occurred_at,duration_minutes,request_id)
values(auth.uid(),'00000000-0000-4000-8000-0000000000a1',now(),30,'00000000-0000-4000-8000-0000000000d1');
do $$ begin
  begin
    insert into public.exercise_logs(user_id,task_id,occurred_at,duration_minutes,request_id)
    values(auth.uid(),'00000000-0000-4000-8000-0000000000b1',now(),30,gen_random_uuid());
    raise exception 'FAIL: cross-user task link accepted';
  exception when foreign_key_violation then null; end;
  begin
    insert into public.exercise_logs(user_id,occurred_at,duration_minutes,request_id)
    values(auth.uid(),now(),30,'00000000-0000-4000-8000-0000000000d1');
    raise exception 'FAIL: duplicate request accepted';
  exception when unique_violation then null; end;
  begin
    insert into public.planning_events(user_id,event_key,event_type,occurred_at,evidence)
    values(auth.uid(),'forged','fixture',now(),'{}');
    raise exception 'FAIL: forged event accepted';
  exception when insufficient_privilege then null; end;
end $$;
select pg_temp.assert_true((select count(*)=1 from public.user_achievements
  where source_event_id='00000000-0000-4000-8000-0000000000e1'), 'owner can read award');
reset role;
select set_config('request.jwt.claim.sub', current_setting('balance.test_user_b'), true);
set local role authenticated;
select pg_temp.assert_true((select count(*)=0 from public.user_achievements
  where source_event_id='00000000-0000-4000-8000-0000000000e1'), 'other user cannot read award');
select pg_temp.assert_true((select count(*)=0 from public.exercise_logs
  where request_id='00000000-0000-4000-8000-0000000000d1'), 'other user cannot read activity');
do $$ declare changed integer; begin
  update public.exercise_logs set duration_minutes=60
    where request_id='00000000-0000-4000-8000-0000000000d1';
  get diagnostics changed = row_count;
  perform pg_temp.assert_true(changed=0, 'other user cannot mutate activity');
end $$;
reset role;
rollback;
\echo 'Database contract assertions passed; all fixture writes rolled back.'
