-- Disposable database by default. Uses existing Auth user_a; all writes roll back.
-- psql "$TEST_DATABASE_URL" -v ON_ERROR_STOP=1 -v user_a=UUID -f this_file
\set ON_ERROR_STOP on
begin;
select set_config('balance.test_user_a', :'user_a', true);
update public.profiles set time_zone='UTC'
  where id=current_setting('balance.test_user_a')::uuid;
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
  protected_recovery_id uuid;
  protected_task_id uuid;
  ordinary_protected_task_id uuid;
  overload_task_id uuid;
  available_start timestamptz;
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

  -- A genuinely protected recovery slot grants Protected Rest.
  insert into public.recovery_slots(user_id,start_at,end_at,is_protected)
    values(auth.uid(),now()+interval '2 days',now()+interval '2 days 30 minutes',true)
    returning id into protected_recovery_id;
  if not exists(select 1 from public.user_achievements where user_id=auth.uid()
      and achievement_key='protected_rest') then
    raise exception 'FAIL: protected recovery did not grant Protected Rest';
  end if;

  -- A typed protected commitment grants Protected Limit. Generic protected
  -- work without a commitment type must not grant that achievement.
  insert into public.tasks(user_id,title,estimated_minutes,remaining_minutes,due_at,
      is_protected,protected_commitment_type,load_category)
    values(auth.uid(),'SQL temporary protected shift',60,60,now()+interval '4 days',
      true,'work_shift','other') returning id into protected_task_id;
  if not exists(select 1 from public.user_achievements where user_id=auth.uid()
      and achievement_key='protected_limit') then
    raise exception 'FAIL: typed protected commitment did not grant Protected Limit';
  end if;
  insert into public.tasks(user_id,title,estimated_minutes,remaining_minutes,due_at,
      is_protected,load_category)
    values(auth.uid(),'SQL temporary protected ordinary task',60,60,now()+interval '4 days',
      true,'study') returning id into ordinary_protected_task_id;
  if exists(select 1 from public.planning_events where user_id=auth.uid()
      and event_type='protected_limit' and source_record_id=ordinary_protected_task_id) then
    raise exception 'FAIL: ordinary protected work incorrectly granted Protected Limit';
  end if;

  -- An invalid commitment label on an unprotected task is rejected by schema.
  begin
    insert into public.tasks(user_id,title,estimated_minutes,remaining_minutes,due_at,
        is_protected,protected_commitment_type,load_category)
      values(auth.uid(),'SQL invalid unprotected commitment',30,30,now()+interval '4 days',
        false,'family_duty','other');
    raise exception 'FAIL: unprotected commitment type was accepted';
  exception when check_violation then null;
  end;

  -- Early Review requires an actual current-day capacity gap and a task whose
  -- deadline is after today. It cannot be earned for a balanced day.
  local_day := (now() at time zone 'UTC')::date;
  available_start := date_trunc('day',now() at time zone 'UTC') at time zone 'UTC';
  insert into public.availability_blocks(user_id,start_at,end_at,block_type,label)
    values(auth.uid(),available_start,available_start+interval '30 minutes','available',
      'SQL temporary early-review capacity');
  insert into public.tasks(user_id,title,estimated_minutes,remaining_minutes,due_at,
      scheduled_start,scheduled_end,load_category)
    values(auth.uid(),'SQL temporary overload review',90,90,
      (local_day+2)::timestamp at time zone 'UTC',
      greatest(now()+interval '5 minutes',available_start+interval '1 hour'),
      greatest(now()+interval '5 minutes',available_start+interval '1 hour')+interval '90 minutes',
      'study') returning id into overload_task_id;
  if public.calculate_day_overload(auth.uid(),local_day)<=0 then
    raise exception 'FAIL: early-review fixture did not create overload';
  end if;
  perform public.acknowledge_overload(overload_task_id);
  if not exists(select 1 from public.overload_reviews where user_id=auth.uid()
      and task_id=overload_task_id)
     or not exists(select 1 from public.user_achievements where user_id=auth.uid()
      and achievement_key='early_review') then
    raise exception 'FAIL: eligible overload review did not grant Early Review';
  end if;

  perform public.evaluate_my_achievements();
  select count(*) into awards from public.user_achievements where user_id=auth.uid();
  perform public.evaluate_my_achievements();
  if (select count(*) from public.user_achievements where user_id=auth.uid()) <> awards then
    raise exception 'FAIL: repeated evaluation duplicated awards';
  end if;
  if exists(select 1 from public.user_achievements where user_id=auth.uid()
      and achievement_key='team_coordination') then
    raise exception 'FAIL: personal-only evidence incorrectly granted Team Coordination';
  end if;
end;
$$;
reset role;
rollback;
\echo 'Verified-progress runtime assertions passed; fixture writes rolled back.'
