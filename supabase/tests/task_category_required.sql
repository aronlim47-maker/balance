-- DISPOSABLE DATABASE ONLY, after all migrations, as database owner via psql.
-- -v user_a=<existing Auth UUID>. All fixtures and trigger changes roll back.
\set ON_ERROR_STOP on
begin;
select set_config('balance.test_user_a', :'user_a', true);
do $$ begin
  if not exists(select 1 from auth.users where id=current_setting('balance.test_user_a')::uuid) then
    raise exception 'Create the test user through Auth first';
  end if;
end $$;
-- Reproduce an old row created before enforcement. Never do this in production.
alter table public.tasks disable trigger tasks_require_category;
insert into public.tasks(id,user_id,title,estimated_minutes,remaining_minutes,due_at)
values ('00000000-0000-4000-8000-00000000c001',current_setting('balance.test_user_a')::uuid,
  'WS11 legacy',30,30,'2099-01-01T12:00:00Z');
alter table public.tasks enable trigger tasks_require_category;
select set_config('request.jwt.claim.sub',current_setting('balance.test_user_a'),true);
set local role authenticated;
do $$
declare category text; created uuid;
begin
  -- Old NULL remains editable without manufacturing a category.
  update public.tasks set title='WS11 legacy edited',load_category=null
    where id='00000000-0000-4000-8000-00000000c001';
  if not exists(select 1 from public.tasks where id='00000000-0000-4000-8000-00000000c001'
      and load_category is null and title='WS11 legacy edited') then
    raise exception 'FAIL: legacy NULL row not preserved';
  end if;
  begin
    insert into public.tasks(user_id,title,estimated_minutes,remaining_minutes,due_at)
    values(auth.uid(),'WS11 missing category',30,30,'2099-01-01T12:00:00Z');
    raise exception 'FAIL: omitted category accepted';
  exception when check_violation then
    if sqlerrm <> 'Task category required' then raise; end if;
  end;
  begin
    insert into public.tasks(user_id,title,estimated_minutes,remaining_minutes,due_at,load_category)
    values(auth.uid(),'WS11 explicit NULL',30,30,'2099-01-01T12:00:00Z',null);
    raise exception 'FAIL: explicit NULL accepted';
  exception when check_violation then
    if sqlerrm <> 'Task category required' then raise; end if;
  end;
  foreach category in array array['study','errand','social','exercise','other'] loop
    insert into public.tasks(user_id,title,estimated_minutes,remaining_minutes,due_at,load_category)
    values(auth.uid(),'WS11 valid category',30,30,'2099-01-01T12:00:00Z',category)
    returning id into created;
    begin
      update public.tasks set load_category=null where id=created;
      raise exception 'FAIL: classified task cleared';
    exception when check_violation then
      if sqlerrm <> 'Task category required' then raise; end if;
    end;
  end loop;
  update public.tasks set load_category='study' where id='00000000-0000-4000-8000-00000000c001';
  begin
    update public.tasks set load_category=null where id='00000000-0000-4000-8000-00000000c001';
    raise exception 'FAIL: legacy task reverted after classification';
  exception when check_violation then
    if sqlerrm <> 'Task category required' then raise; end if;
  end;
end $$;
reset role;
rollback;
\echo 'WS11 category assertions passed; fixtures rolled back.'
