-- Disposable database by default. Uses existing Auth user_a; all writes roll back.
-- psql "$TEST_DATABASE_URL" -v ON_ERROR_STOP=1 -v user_a=UUID -f this_file
\set ON_ERROR_STOP on
begin;
select set_config('balance.test_user_a', :'user_a', true);
do $$
begin
  if not exists(select 1 from auth.users where id=current_setting('balance.test_user_a')::uuid) then
    raise exception 'Create the test user through Auth first';
  end if;
  if public._ws_cap(-5) <> 0 or public._ws_cap(120) <> 100
     or public._ws_cap(null) is not null
     or public._ws_components(array[20::numeric,null],array[.7::numeric,.3],.7) <> 20
     or public._ws_components(array[20::numeric,null],array[.4::numeric,.6],.7) is not null then
    raise exception 'FAIL: helper bounds or missing-input rules';
  end if;
  if has_function_privilege('authenticated','public._award_verified(uuid,text,uuid,timestamptz)','EXECUTE')
     or has_function_privilege('anon','public._award_verified(uuid,text,uuid,timestamptz)','EXECUTE')
     or has_function_privilege('authenticated','public._ws_cap(numeric)','EXECUTE') then
    raise exception 'FAIL: private helper exposed to clients';
  end if;
  if (select count(*) from pg_trigger where not tgisinternal
      and tgname in ('recovery_award','task_protection_award','plan_confirmation_award','reflection_award')) <> 4 then
    raise exception 'FAIL: incomplete achievement triggers';
  end if;
end;
$$;
select set_config('request.jwt.claim.sub',current_setting('balance.test_user_a'),true);
set local role authenticated;
do $$
declare
  reference_id uuid;
  local_day date;
  awards integer;
begin
  perform public.capture_world_status();
  select (now() at time zone coalesce(time_zone,'UTC'))::date into local_day
    from public.profiles where id=auth.uid();
  if (select count(*) from public.world_status_snapshots where user_id=auth.uid()
      and local_date=local_day and formula_version='world_status_v1') <> 1 then
    raise exception 'FAIL: missing daily snapshot';
  end if;
  insert into public.reflections(user_id,body)
    values(auth.uid(),'SQL temporary verified-progress acceptance') returning id into reference_id;
  if not exists(select 1 from public.planning_events where user_id=auth.uid()
      and event_type='reflection' and source_key=reference_id::text)
     or not exists(select 1 from public.user_achievements where user_id=auth.uid()
      and achievement_key='reflection') then
    raise exception 'FAIL: reflection did not produce trusted achievement evidence';
  end if;
  perform public.evaluate_my_achievements();
  select count(*) into awards from public.user_achievements where user_id=auth.uid();
  perform public.evaluate_my_achievements();
  if (select count(*) from public.user_achievements where user_id=auth.uid()) <> awards then
    raise exception 'FAIL: repeated evaluation duplicated awards';
  end if;
end;
$$;
reset role;
rollback;
\echo 'Verified-progress runtime assertions passed; fixture writes rolled back.'
