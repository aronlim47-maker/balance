-- DISPOSABLE project only, after every migration. No production test users.
-- psql "$TEST_DATABASE_URL" -v ON_ERROR_STOP=1 -v user_a=UUID -f this_file
-- Create user_a through Auth first. Everything below rolls back.
\set ON_ERROR_STOP on
begin;
set local time zone 'UTC';
select set_config('balance.test_user_a', :'user_a', true);
do $$ begin
  if not exists(select 1 from auth.users where id=current_setting('balance.test_user_a')::uuid) then
    raise exception 'Create the disposable test user through Auth first';
  end if;
end $$;
update public.profiles set time_zone='UTC' where id=current_setting('balance.test_user_a')::uuid;
select set_config('request.jwt.claim.sub', current_setting('balance.test_user_a'), true);
set local role authenticated;

do $$
declare
  state text;
  base timestamptz := '2099-01-01T00:00:00Z';
  mover uuid;
  next_mover uuid;
  replacement uuid;
  change_id uuid;
  recovery uuid;
  target_block uuid;
  before_minutes integer;
begin
  foreach state in array array['completed','cancelled'] loop
    insert into public.availability_blocks(user_id,start_at,end_at,block_type)
      values(auth.uid(),base+interval '9 hours',base+interval '12 hours','available');
    insert into public.availability_blocks(user_id,start_at,end_at,block_type)
      values(auth.uid(),base+interval '1 day 9 hours',base+interval '1 day 12 hours','available')
      returning id into target_block;
    insert into public.tasks(user_id,title,estimated_minutes,remaining_minutes,due_at,
      scheduled_start,scheduled_end,load_category)
      values(auth.uid(),'SQL moving task',180,180,base+interval '3 days',
        base+interval '9 hours',base+interval '12 hours','study') returning id into mover;
    insert into public.tasks(user_id,title,estimated_minutes,remaining_minutes,due_at,load_category)
      values(auth.uid(),'SQL deadline work',120,120,base+interval '12 hours','study');
    change_id := public.confirm_plan_change(jsonb_build_array(jsonb_build_object(
      'task_id',mover,'proposed_start',base+interval '1 day 9 hours',
      'proposed_end',base+interval '1 day 11 hours','moved_minutes',120)));
    if public.calculate_day_overload(auth.uid(),base::date) <> 0 then
      raise exception 'FAIL: confirm did not clear source overload';
    end if;
    -- Active moved work must still block all conflicting writes.
    begin
      insert into public.tasks(user_id,title,estimated_minutes,remaining_minutes,due_at,
        scheduled_start,scheduled_end,load_category)
        values(auth.uid(),'SQL blocked replacement',120,120,base+interval '3 days',
          base+interval '1 day 9 hours',base+interval '1 day 11 hours','study');
      raise exception 'FAIL: active moved work accepted a conflicting schedule';
    exception when raise_exception then
      if sqlerrm <> 'Scheduled task overlaps confirmed moved work' then raise; end if;
    end;
    begin
      insert into public.recovery_slots(user_id,start_at,end_at)
        values(auth.uid(),base+interval '1 day 9 hours',base+interval '1 day 11 hours');
      raise exception 'FAIL: active moved work accepted conflicting recovery';
    exception when raise_exception then
      if sqlerrm <> 'Recovery slot overlaps a moved task' then raise; end if;
    end;
    update public.tasks set status=state where id=mover;
    -- The history remains confirmed, but the time can now be used again.
    insert into public.tasks(user_id,title,estimated_minutes,remaining_minutes,due_at,
      scheduled_start,scheduled_end,load_category)
      values(auth.uid(),'SQL replacement',120,120,base+interval '3 days',
        base+interval '1 day 9 hours',base+interval '1 day 11 hours','study') returning id into replacement;
    delete from public.tasks where id=replacement;
    insert into public.recovery_slots(user_id,start_at,end_at)
      values(auth.uid(),base+interval '1 day 9 hours',base+interval '1 day 11 hours') returning id into recovery;
    delete from public.recovery_slots where id=recovery;
    delete from public.availability_blocks where id=target_block;
    insert into public.availability_blocks(user_id,start_at,end_at,block_type)
      values(auth.uid(),base+interval '1 day 9 hours',base+interval '1 day 12 hours','available');
    insert into public.tasks(user_id,title,estimated_minutes,remaining_minutes,due_at,
      scheduled_start,scheduled_end,load_category)
      values(auth.uid(),'SQL new move',120,120,base+interval '3 days',
        base+interval '10 hours',base+interval '12 hours','study') returning id into next_mover;
    before_minutes := public.calculate_day_overload(auth.uid(),base::date);
    change_id := public.confirm_plan_change(jsonb_build_array(jsonb_build_object(
      'task_id',next_mover,'proposed_start',base+interval '1 day 9 hours',
      'proposed_end',base+interval '1 day 11 hours','moved_minutes',120)));
    perform public.undo_plan_change(change_id);
    if public.calculate_day_overload(auth.uid(),base::date) <> before_minutes then
      raise exception 'FAIL: undo did not restore the original overload';
    end if;
    base := base+interval '4 days';
  end loop;
end $$;

do $$
declare
  retry_request uuid := gen_random_uuid();
  first_row jsonb;
  retried jsonb;
begin
  first_row := public.create_social_event_once('2099-02-02T09:00:00Z','2099-02-02T10:00:00Z',
    'low','2099-02-02',retry_request,null);
  retried := public.create_social_event_once('2099-02-02T09:00:00Z','2099-02-02T10:00:00Z',
    'low','2099-02-02',retry_request,null);
  if first_row->>'id' is distinct from retried->>'id' or
      (select count(*) from public.social_events where user_id=auth.uid() and social_events.request_id=retry_request) <> 1 then
    raise exception 'FAIL: retry duplicated the social event';
  end if;
  begin
    perform public.create_social_event_once('2099-02-02T09:00:00Z','2099-02-02T11:00:00Z',
      'low','2099-02-02',retry_request,null);
    raise exception 'FAIL: changed payload accepted with reused request ID';
  exception when raise_exception then
    if sqlerrm <> 'Request ID already used with different input.' then raise; end if;
  end;
end $$;
reset role;
rollback;
\echo 'Active occupancy and retry assertions passed; fixture writes rolled back.'
