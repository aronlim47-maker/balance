-- Additive repair of a partially installed verified-progress dependency graph.
-- Apply after 202610040001. Existing definitions and historical scores remain.
-- Missing functions use the reviewed 202609270002 implementation, not new rules.
begin;
do $$
begin
  if to_regprocedure('public._ws_cap(numeric)') is null then
    execute $ddl$
create function public._ws_cap(v numeric) returns numeric
language sql immutable set search_path = '' as $fn$
  select case when v is null then null else least(100, greatest(0, v)) end;
$fn$;
    $ddl$;
  end if;
  if to_regprocedure('public._ws_components(numeric[],numeric[],numeric)') is null then
    execute $ddl$
create function public._ws_components(v numeric[], w numeric[], minimum numeric)
returns numeric language sql immutable set search_path = '' as $fn$
  select case when sum(w[i]) filter (where v[i] is not null) >= minimum
    then sum(v[i] * w[i]) / sum(w[i]) filter (where v[i] is not null) end
  from generate_subscripts(v, 1) i;
$fn$;
    $ddl$;
  end if;
  if to_regprocedure('public._award_verified(uuid,text,uuid,timestamptz)') is null then
    execute $ddl$
create function public._award_verified(p_user uuid,p_key text,p_source uuid,p_time timestamptz)
returns void language plpgsql security definer set search_path = '' as $fn$
declare event_id uuid;
begin
  insert into public.planning_events(user_id,event_type,source_key,source_record_id,occurred_at,evidence)
    values(p_user,p_key,p_source::text,p_source,p_time,jsonb_build_object('verified_by','database_v1'))
    on conflict(user_id,event_type,source_key) do nothing;
  select id into event_id from public.planning_events
    where user_id=p_user and event_type=p_key and source_key=p_source::text;
  insert into public.user_achievements(user_id,achievement_key,source_event_id,occurred_at)
    values(p_user,p_key,event_id,p_time) on conflict(user_id,achievement_key) do nothing;
end;
$fn$;
    $ddl$;
  end if;
  if to_regprocedure('public.evaluate_my_achievements()') is null then
    execute $ddl$
create function public.evaluate_my_achievements() returns void
language plpgsql security definer set search_path = '' as $fn$
declare u uuid:=auth.uid(); r record;
begin
  if u is null then raise exception 'Authentication required'; end if;
  perform pg_advisory_xact_lock(hashtextextended(u::text,0));
  for r in select id,created_at from public.recovery_slots where user_id=u and is_protected loop
    perform public._award_verified(u,'protected_rest',r.id,r.created_at);
  end loop;
  for r in select id,created_at,protected_commitment_type from public.tasks
    where user_id=u and is_protected and protected_commitment_type is not null loop
    perform public._award_verified(u,'protected_limit',r.id,now());
    if r.protected_commitment_type='sleep_minimum' then
      perform public._award_verified(u,'protected_rest',r.id,now());
    end if;
  end loop;
  for r in select id,confirmed_at from public.plan_changes
    where user_id=u and status='confirmed' and validation_status='feasible' loop
    perform public._award_verified(u,'safe_trade_off',r.id,r.confirmed_at);
    if exists(select 1 from public.plan_change_items i join public.tasks t on t.id=i.task_id
      where i.plan_change_id=r.id and t.user_id=u and t.flexibility='flexible'
        and i.proposed_end<=t.due_at) then
      perform public._award_verified(u,'deadline_safety',r.id,r.confirmed_at);
    end if;
  end loop;
  for r in select id,created_at from public.reflections where user_id=u and length(btrim(body))>0 loop
    perform public._award_verified(u,'reflection',r.id,r.created_at);
  end loop;
  -- Early Review is awarded by the verified acknowledgement RPC below.
  -- Team Coordination requires V2 shared-task evidence; never infer it from a personal task.
end;
$fn$;
    $ddl$;
  end if;
  if to_regprocedure('public.acknowledge_overload(uuid)') is null then
    execute $ddl$
create function public.acknowledge_overload(p_task uuid) returns void
language plpgsql security definer set search_path = '' as $fn$
declare u uuid:=auth.uid(); t public.tasks%rowtype; zone text; d date; review_id uuid;
begin
  if u is null then raise exception 'Authentication required'; end if;
  perform pg_advisory_xact_lock(hashtextextended(u::text,0));
  select * into t from public.tasks where id=p_task and user_id=u and status='planned';
  if not found then raise exception 'Task unavailable'; end if;
  select time_zone into zone from public.profiles where id=u;
  d:=(now() at time zone coalesce(zone,'UTC'))::date;
  if (t.due_at at time zone coalesce(zone,'UTC'))::date<=d
    or public.calculate_day_overload(u,d)<=0 then raise exception 'No eligible early overload review'; end if;
  if exists(select 1 from public.user_achievements
    where user_id=u and achievement_key='early_review') then return; end if;
  insert into public.overload_reviews(user_id,task_id,reviewed_at) values(u,p_task,now()) returning id into review_id;
  perform public._award_verified(u,'early_review',review_id,now());
end;
$fn$;
    $ddl$;
  end if;
  if to_regprocedure('public._award_from_recovery()') is null then
    execute $ddl$
create function public._award_from_recovery() returns trigger
language plpgsql security definer set search_path = '' as $fn$
begin
  if new.is_protected then
    perform public._award_verified(new.user_id,'protected_rest',new.id,new.created_at);
  end if;
  return new;
end;
$fn$;
    $ddl$;
  end if;
  if to_regprocedure('public._award_from_task()') is null then
    execute $ddl$
create function public._award_from_task() returns trigger
language plpgsql security definer set search_path = '' as $fn$
begin
  if new.is_protected and new.protected_commitment_type is not null then
    perform public._award_verified(new.user_id,'protected_limit',new.id,now());
    if new.protected_commitment_type='sleep_minimum' then
      perform public._award_verified(new.user_id,'protected_rest',new.id,now());
    end if;
  end if;
  return new;
end;
$fn$;
    $ddl$;
  end if;
  if to_regprocedure('public._award_from_plan()') is null then
    execute $ddl$
create function public._award_from_plan() returns trigger
language plpgsql security definer set search_path = '' as $fn$
begin
  if new.status='confirmed' and old.status<>'confirmed' and new.validation_status='feasible' then
    perform public._award_verified(new.user_id,'safe_trade_off',new.id,new.confirmed_at);
    if exists(select 1 from public.plan_change_items i join public.tasks t on t.id=i.task_id
      where i.plan_change_id=new.id and t.user_id=new.user_id and t.flexibility='flexible'
      and i.proposed_end<=t.due_at) then
      perform public._award_verified(new.user_id,'deadline_safety',new.id,new.confirmed_at);
    end if;
  end if;
  return new;
end;
$fn$;
    $ddl$;
  end if;
  if to_regprocedure('public._award_from_reflection()') is null then
    execute $ddl$
create function public._award_from_reflection() returns trigger
language plpgsql security definer set search_path = '' as $fn$
begin
  perform public._award_verified(new.user_id,'reflection',new.id,new.created_at);
  return new;
end;
$fn$;
    $ddl$;
  end if;
  if not exists (select 1 from pg_trigger where tgname='recovery_award'
      and tgrelid='public.recovery_slots'::regclass and not tgisinternal) then
    execute $ddl$create trigger recovery_award after insert or update of is_protected on public.recovery_slots
      for each row execute function public._award_from_recovery();$ddl$;
  end if;
  if not exists (select 1 from pg_trigger where tgname='task_protection_award'
      and tgrelid='public.tasks'::regclass and not tgisinternal) then
    execute $ddl$create trigger task_protection_award after insert or update of is_protected,protected_commitment_type on public.tasks
      for each row execute function public._award_from_task();$ddl$;
  end if;
  if not exists (select 1 from pg_trigger where tgname='plan_confirmation_award'
      and tgrelid='public.plan_changes'::regclass and not tgisinternal) then
    execute $ddl$create trigger plan_confirmation_award after update of status on public.plan_changes
      for each row execute function public._award_from_plan();$ddl$;
  end if;
  if not exists (select 1 from pg_trigger where tgname='reflection_award'
      and tgrelid='public.reflections'::regclass and not tgisinternal) then
    execute $ddl$create trigger reflection_award after insert on public.reflections
      for each row execute function public._award_from_reflection();$ddl$;
  end if;
end;
$$;
revoke all on function public._ws_cap(numeric) from public, anon, authenticated;
revoke all on function public._ws_components(numeric[],numeric[],numeric) from public, anon, authenticated;
revoke all on function public._award_verified(uuid,text,uuid,timestamptz) from public, anon, authenticated;
revoke all on function public.evaluate_my_achievements() from public, anon, authenticated;
revoke all on function public.acknowledge_overload(uuid) from public, anon, authenticated;
revoke all on function public._award_from_recovery() from public, anon, authenticated;
revoke all on function public._award_from_task() from public, anon, authenticated;
revoke all on function public._award_from_plan() from public, anon, authenticated;
revoke all on function public._award_from_reflection() from public, anon, authenticated;
grant execute on function public.evaluate_my_achievements() to authenticated;
grant execute on function public.acknowledge_overload(uuid) to authenticated;
notify pgrst, 'reload schema';
commit;
