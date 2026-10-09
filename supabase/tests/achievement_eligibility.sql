-- Achievement eligibility fixtures: positive and negative cases for all seven
-- achievement_v1 rules (Rev7 14.7.1). Covers Matthew's handoff in
-- docs/ZHI_XUAN_DATA_HANDOFF.md. Award logic stays server-side; this script only
-- exercises the existing triggers and owner-bound RPCs.
--
-- DISPOSABLE database only, after every migration. Create both users through Auth.
-- psql "$TEST_DATABASE_URL" -v ON_ERROR_STOP=1 -v user_a=UUID -v user_b=UUID -f this_file
-- Everything below rolls back.
--
-- Case IDs (used in docs/WS_AND_ACHIEVEMENT_TEST_MAP.md):
--   AC-PR+ / AC-PR-   Protected Rest       AC-ST+ / AC-ST-   Safe Trade-off
--   AC-DS+ / AC-DS-   Deadline Safety      AC-ER+ / AC-ER-   Early Review
--   AC-PL+ / AC-PL-   Protected Limit      AC-RF+ / AC-RF-   Reflection
--   AC-TC-            Team Coordination (stays Locked in V1)
--   AC-DUP            Repeat/retry/undo never adds a second award
--   AC-ISO            Another account cannot read or receive these awards
\set ON_ERROR_STOP on
begin;
set local time zone 'UTC';
select set_config('balance.test_user_a', :'user_a', true);
select set_config('balance.test_user_b', :'user_b', true);
do $$ begin
  if current_setting('balance.test_user_a') = current_setting('balance.test_user_b') then
    raise exception 'Use two different test users';
  end if;
  if (select count(*) from auth.users where id in (
      current_setting('balance.test_user_a')::uuid,
      current_setting('balance.test_user_b')::uuid)) <> 2 then
    raise exception 'Create both disposable test users through Auth first';
  end if;
  if exists(select 1 from public.user_achievements where user_id in (
      current_setting('balance.test_user_a')::uuid,
      current_setting('balance.test_user_b')::uuid)) then
    raise exception 'Use fresh test users: these accounts already hold awards';
  end if;
end $$;
-- A non-UTC zone proves Early Review compares local calendar dates.
update public.profiles set time_zone='Asia/Kuala_Lumpur'
  where id=current_setting('balance.test_user_a')::uuid;
update public.profiles set time_zone='Asia/Kuala_Lumpur'
  where id=current_setting('balance.test_user_b')::uuid;

create function pg_temp.assert_true(ok boolean, message text) returns void
language plpgsql as $$ begin
  if ok is distinct from true then raise exception 'FAIL: %', message; end if;
end $$;

create function pg_temp.award_count(p_user uuid, p_key text) returns integer
language sql as $$
  select count(*)::integer from public.user_achievements
  where user_id=p_user and achievement_key=p_key
$$;

reset role;
select pg_temp.assert_true((select count(*)=7 from public.achievement_definitions
  where achievement_key in ('protected_rest','safe_trade_off','deadline_safety',
    'early_review','protected_limit','reflection','team_coordination')),
  'all seven achievement definitions exist');

select set_config('request.jwt.claim.sub', current_setting('balance.test_user_a'), true);
set local role authenticated;

-- ---------------------------------------------------------------------------
-- Negative cases first: awards are once per user and key, so each negative
-- must run before its positive.
-- ---------------------------------------------------------------------------
do $$
declare
  base timestamptz := '2099-03-01T00:00:00Z';
  slot uuid;
begin
  insert into public.availability_blocks(user_id,start_at,end_at,block_type)
    values(auth.uid(),base+interval '9 hours',base+interval '12 hours','available');

  -- AC-RF-: an empty reflection is rejected and earns nothing.
  begin
    insert into public.reflections(user_id,body) values(auth.uid(),'   ');
    raise exception 'FAIL: empty reflection accepted';
  exception when check_violation then null;
  end;
  perform pg_temp.assert_true(pg_temp.award_count(auth.uid(),'reflection')=0,
    'AC-RF-: empty reflection earns no award');

  -- AC-PR-: an unprotected slot, choosing an activity and marking it done do not qualify.
  insert into public.recovery_slots(user_id,start_at,end_at,is_protected,selected_activity)
    values(auth.uid(),base+interval '9 hours',base+interval '9 hours 30 minutes',false,'Short walk')
    returning id into slot;
  update public.recovery_slots set completed_at=base+interval '9 hours 30 minutes' where id=slot;
  perform pg_temp.assert_true(pg_temp.award_count(auth.uid(),'protected_rest')=0,
    'AC-PR-: unprotected/completed activity earns no Protected Rest');
  delete from public.recovery_slots where id=slot;

  -- AC-PL-: a protected task without a commitment type, or a title that merely
  -- says "work shift", is not Protected Limit evidence.
  insert into public.tasks(user_id,title,estimated_minutes,remaining_minutes,due_at,
    is_protected,load_category)
    values(auth.uid(),'Protected essay',60,60,base+interval '20 days',true,'study');
  insert into public.tasks(user_id,title,estimated_minutes,remaining_minutes,due_at,load_category)
    values(auth.uid(),'Work shift at cafe',60,60,base+interval '20 days','other');
  perform pg_temp.assert_true(pg_temp.award_count(auth.uid(),'protected_limit')=0,
    'AC-PL-: no commitment type means no Protected Limit');

  -- AC-PL+ and AC-PR- together: a protected work shift is Protected Limit,
  -- but it is not Protected Rest.
  insert into public.tasks(user_id,title,estimated_minutes,remaining_minutes,due_at,
    is_protected,protected_commitment_type,flexibility,load_category)
    values(auth.uid(),'Shift',240,240,base+interval '20 days',true,'work_shift','fixed','other');
  perform pg_temp.assert_true(pg_temp.award_count(auth.uid(),'protected_limit')=1,
    'AC-PL+: protected work shift earns Protected Limit');
  perform pg_temp.assert_true(pg_temp.award_count(auth.uid(),'protected_rest')=0,
    'AC-PR-: a work shift alone does not earn Protected Rest');
end $$;

-- AC-ST- / AC-DS-: a stale (failed) confirmation earns nothing.
do $$
declare
  base timestamptz := '2099-03-01T00:00:00Z';
  mover uuid;
  reviewed_version integer;
  same_day_task uuid;
  day_start timestamptz := ((now() at time zone 'Asia/Kuala_Lumpur')::date)::timestamp
    at time zone 'Asia/Kuala_Lumpur';
begin
  insert into public.availability_blocks(user_id,start_at,end_at,block_type)
    values(auth.uid(),base+interval '1 day 9 hours',base+interval '1 day 12 hours','available');
  insert into public.tasks(user_id,title,estimated_minutes,remaining_minutes,due_at,
    scheduled_start,scheduled_end,load_category)
    values(auth.uid(),'Fixture reading',180,180,base+interval '3 days',
      base+interval '9 hours',base+interval '12 hours','study') returning id into mover;
  insert into public.tasks(user_id,title,estimated_minutes,remaining_minutes,due_at,load_category)
    values(auth.uid(),'Fixture assignment',120,120,base+interval '12 hours','study');
  select version into reviewed_version from public.tasks where id=mover;
  update public.tasks set title='Fixture reading (edited after review)' where id=mover;
  begin
    perform public.confirm_plan_change(jsonb_build_array(jsonb_build_object(
      'task_id',mover,'proposed_start',base+interval '1 day 9 hours',
      'proposed_end',base+interval '1 day 11 hours','moved_minutes',120,
      'expected_task_version',reviewed_version)));
    raise exception 'FAIL: stale confirmation accepted';
  exception when serialization_failure then null;
  end;
  perform pg_temp.assert_true(pg_temp.award_count(auth.uid(),'safe_trade_off')=0,
    'AC-ST-: failed confirmation earns no Safe Trade-off');
  perform pg_temp.assert_true(pg_temp.award_count(auth.uid(),'deadline_safety')=0,
    'AC-DS-: failed confirmation earns no Deadline Safety');
  -- Merely measuring the overload is not a move.
  perform pg_temp.assert_true(public.calculate_day_overload(auth.uid(),base::date) > 0,
    'fixture source day is overloaded');
  perform pg_temp.assert_true(pg_temp.award_count(auth.uid(),'deadline_safety')=0,
    'AC-DS-: detecting a conflict earns no Deadline Safety');

  -- AC-ER-: today's local overload exists, but the reviewed task is due later
  -- the SAME local day, so it cannot be an early review.
  insert into public.tasks(user_id,title,estimated_minutes,remaining_minutes,due_at,load_category)
    values(auth.uid(),'Due tonight',60,60,day_start+interval '23 hours 30 minutes','study')
    returning id into same_day_task;
  perform pg_temp.assert_true(public.calculate_day_overload(auth.uid(),
    (now() at time zone 'Asia/Kuala_Lumpur')::date) > 0, 'fixture today is overloaded');
  begin
    perform public.acknowledge_overload(same_day_task);
    raise exception 'FAIL: same-day review accepted';
  exception when raise_exception then
    if sqlerrm <> 'No eligible early overload review' then raise; end if;
  end;
  perform pg_temp.assert_true(pg_temp.award_count(auth.uid(),'early_review')=0,
    'AC-ER-: same local day review earns no Early Review');

  -- AC-TC-: a needs-agreement personal task is not shared-task evidence.
  insert into public.tasks(user_id,title,estimated_minutes,remaining_minutes,due_at,
    flexibility,load_category)
    values(auth.uid(),'Group report (looks shared)',60,60,base+interval '20 days',
      'needs_agreement','study');
  perform public.evaluate_my_achievements();
  perform pg_temp.assert_true(pg_temp.award_count(auth.uid(),'team_coordination')=0,
    'AC-TC-: Team Coordination stays Locked without V2 evidence');

  -- Clients can never write an award or a planning event directly.
  begin
    insert into public.planning_events(user_id,source_key,event_type,occurred_at,evidence)
      values(auth.uid(),'forged-team','team_coordination',now(),'{}');
    raise exception 'FAIL: forged planning event accepted';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.user_achievements(user_id,achievement_key,rule_version,occurred_at)
      values(auth.uid(),'team_coordination','achievement_v1',now());
    raise exception 'FAIL: client award write accepted';
  exception when insufficient_privilege then null;
  end;
end $$;

-- ---------------------------------------------------------------------------
-- Positive cases and anti-farming.
-- ---------------------------------------------------------------------------
do $$
declare
  base timestamptz := '2099-03-01T00:00:00Z';
  mover uuid;
  change_id uuid;
  second_change uuid;
  tomorrow_task uuid;
  day_start timestamptz := ((now() at time zone 'Asia/Kuala_Lumpur')::date)::timestamp
    at time zone 'Asia/Kuala_Lumpur';
begin
  -- AC-PR+: a persisted protected recovery slot inside availability.
  insert into public.recovery_slots(user_id,start_at,end_at)
    values(auth.uid(),base+interval '1 day 11 hours 30 minutes',base+interval '1 day 12 hours');
  perform pg_temp.assert_true(pg_temp.award_count(auth.uid(),'protected_rest')=1,
    'AC-PR+: protected recovery slot earns Protected Rest');

  -- AC-ST+ / AC-DS+: a committed feasible move of a flexible task before its deadline.
  select id into mover from public.tasks
    where user_id=auth.uid() and title like 'Fixture reading%';
  change_id := public.confirm_plan_change(jsonb_build_array(jsonb_build_object(
    'task_id',mover,'proposed_start',base+interval '1 day 9 hours',
    'proposed_end',base+interval '1 day 11 hours','moved_minutes',120,
    'expected_task_version',(select version from public.tasks where id=mover))));
  perform pg_temp.assert_true(pg_temp.award_count(auth.uid(),'safe_trade_off')=1,
    'AC-ST+: confirmed feasible plan earns Safe Trade-off');
  perform pg_temp.assert_true(pg_temp.award_count(auth.uid(),'deadline_safety')=1,
    'AC-DS+: persisted flexible move before deadline earns Deadline Safety');
  perform pg_temp.assert_true((select count(*)=1 from public.planning_events
    where user_id=auth.uid() and event_type='deadline_safety' and source_record_id=change_id),
    'AC-DS+: award points at the confirmed plan as evidence');

  -- AC-DUP: Undo keeps the historical badge; a second plan cannot farm it.
  perform public.undo_plan_change(change_id);
  perform pg_temp.assert_true(pg_temp.award_count(auth.uid(),'safe_trade_off')=1,
    'AC-DUP: Undo keeps Safe Trade-off');
  second_change := public.confirm_plan_change(jsonb_build_array(jsonb_build_object(
    'task_id',mover,'proposed_start',base+interval '1 day 9 hours',
    'proposed_end',base+interval '1 day 11 hours','moved_minutes',120,
    'expected_task_version',(select version from public.tasks where id=mover))));
  perform pg_temp.assert_true(second_change is distinct from change_id, 'second plan is new');
  perform pg_temp.assert_true(pg_temp.award_count(auth.uid(),'safe_trade_off')=1
    and pg_temp.award_count(auth.uid(),'deadline_safety')=1,
    'AC-DUP: second confirmation adds no second award');

  -- AC-ER+: overloaded today and the task is due on a LATER local date.
  -- 00:30 tomorrow in Kuala Lumpur is still "today" in UTC: local dates decide.
  insert into public.tasks(user_id,title,estimated_minutes,remaining_minutes,due_at,load_category)
    values(auth.uid(),'Due after local midnight',60,60,
      day_start+interval '1 day 30 minutes','study') returning id into tomorrow_task;
  perform public.acknowledge_overload(tomorrow_task);
  perform pg_temp.assert_true(pg_temp.award_count(auth.uid(),'early_review')=1,
    'AC-ER+: review on an earlier local date earns Early Review');
  perform public.acknowledge_overload(tomorrow_task);
  perform pg_temp.assert_true(pg_temp.award_count(auth.uid(),'early_review')=1
    and (select count(*)=1 from public.overload_reviews where user_id=auth.uid()),
    'AC-DUP: repeated Mark as reviewed adds no second review or award');

  -- AC-RF+: a voluntary non-empty reflection.
  insert into public.reflections(user_id,body) values(auth.uid(),'Moving the reading helped.');
  insert into public.reflections(user_id,body) values(auth.uid(),'Second note.');
  perform pg_temp.assert_true(pg_temp.award_count(auth.uid(),'reflection')=1,
    'AC-RF+ / AC-DUP: reflection earns exactly one award');

  -- AC-DUP: re-evaluation (app restart / refresh) is stable.
  perform public.evaluate_my_achievements();
  perform public.evaluate_my_achievements();
  perform pg_temp.assert_true((select count(*)=6 from public.user_achievements
    where user_id=auth.uid()), 'six personal awards; Team Coordination still Locked');
  perform pg_temp.assert_true(pg_temp.award_count(auth.uid(),'team_coordination')=0,
    'AC-TC-: still Locked after re-evaluation');
end $$;

-- AC-PR+ (sleep): protecting a sleep minimum is both Protected Limit and Rest.
-- Checked on user B so the once-per-key rule does not hide the result.
reset role;
select set_config('request.jwt.claim.sub', current_setting('balance.test_user_b'), true);
set local role authenticated;
do $$ begin
  -- AC-ISO: B sees none of A's awards or evidence, and gets nothing from A's actions.
  perform pg_temp.assert_true((select count(*)=0 from public.user_achievements
    where user_id=current_setting('balance.test_user_a')::uuid), 'AC-ISO: B cannot read A awards');
  perform pg_temp.assert_true((select count(*)=0 from public.planning_events
    where user_id=current_setting('balance.test_user_a')::uuid), 'AC-ISO: B cannot read A events');
  perform public.evaluate_my_achievements();
  perform pg_temp.assert_true((select count(*)=0 from public.user_achievements),
    'AC-ISO: B has no awards without its own evidence');
  insert into public.tasks(user_id,title,estimated_minutes,remaining_minutes,due_at,
    is_protected,protected_commitment_type,flexibility,load_category)
    values(auth.uid(),'Sleep',480,480,'2099-04-01T00:00:00Z',true,'sleep_minimum','fixed','other');
  perform pg_temp.assert_true(pg_temp.award_count(auth.uid(),'protected_limit')=1
    and pg_temp.award_count(auth.uid(),'protected_rest')=1,
    'AC-PR+ / AC-PL+: protected sleep minimum earns both');
  -- B cannot acknowledge A's task.
  begin
    perform public.acknowledge_overload((select id from public.tasks
      where title='Sleep' and user_id=auth.uid()) );
    raise exception 'FAIL: B review without overload accepted';
  exception when raise_exception then
    if sqlerrm <> 'No eligible early overload review' then raise; end if;
  end;
end $$;
reset role;
rollback;
\echo 'Achievement eligibility assertions passed; fixture writes rolled back.'
