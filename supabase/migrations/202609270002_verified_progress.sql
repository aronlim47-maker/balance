-- Apply after 202609270001. No client-supplied scores or eligibility flags.
-- Past dates are NOT reconstructed from today's mutable task list.
begin;

create function public._ws_cap(v numeric) returns numeric
language sql immutable set search_path = '' as $$
  select case when v is null then null else least(100, greatest(0, v)) end;
$$;
create function public._ws_components(v numeric[], w numeric[], minimum numeric)
returns numeric language sql immutable set search_path = '' as $$
  select case when sum(w[i]) filter (where v[i] is not null) >= minimum
    then sum(v[i] * w[i]) / sum(w[i]) filter (where v[i] is not null) end
  from generate_subscripts(v, 1) i;
$$;

create function public.capture_world_status() returns void
language plpgsql security definer set search_path = '' as $$
declare
  u uuid := auth.uid(); zone text; d date; a timestamptz; b timestamptz;
  ws timestamptz; we timestamptz; week_day date;
  settings public.world_status_settings%rowtype;
  review public.check_ins%rowtype;
  available numeric; work numeric; recovery numeric;
  counts numeric; due numeric; deadline numeric; capacity numeric; deficit numeric;
  mental numeric; time_score numeric; physical numeric; social numeric; errands numeric;
  energy numeric; last_day date; n integer; minutes numeric; soon numeric;
  social_load numeric := 0; social_minutes numeric := 0; conflicts numeric := 0;
  e record; overlap_minutes numeric; scores numeric[]; weights numeric[] := array[.25,.30,.15,.15,.15];
  names text[] := array['mental','time','physical','social','errands']; known text[] := '{}';
  coverage numeric := 0; total numeric := 0; score integer; i integer; mean_score numeric;
  trend_name text := 'not_enough_history';
begin
  if u is null then raise exception 'Authentication required'; end if;
  perform pg_advisory_xact_lock(hashtextextended(u::text, 0));
  select time_zone into zone from public.profiles where id = u;
  zone := coalesce(zone, 'UTC');
  d := (now() at time zone zone)::date;
  a := d::timestamp at time zone zone; b := (d + 1)::timestamp at time zone zone;
  week_day := d - (extract(isodow from d)::integer - 1);
  ws := week_day::timestamp at time zone zone; we := (week_day + 7)::timestamp at time zone zone;
  select * into settings from public.world_status_settings where user_id = u;
  select * into review from public.check_ins where user_id = u and check_in_date = d;
  select sum(floor(extract(epoch from (least(end_at,b)-greatest(start_at,a)))/60))
    into available from public.availability_blocks
    where user_id=u and block_type='available' and start_at<b and end_at>a;
  select coalesce(sum(case when scheduled_start is null then remaining_minutes
    else floor(extract(epoch from (least(scheduled_end,b)-greatest(scheduled_start,a)))/60) end),0)
    into work from public.tasks where user_id=u and status='planned' and
    ((scheduled_start is null and due_at>=a and due_at<b) or (scheduled_start<b and scheduled_end>a));
  select work + coalesce(sum(floor(extract(epoch from
    (least(i.proposed_end,b)-greatest(i.proposed_start,a)))/60)),0) into work
    from public.plan_change_items i join public.plan_changes c on c.id=i.plan_change_id
    where c.user_id=u and c.status='confirmed' and i.proposed_start<b and i.proposed_end>a;
  select coalesce(sum(floor(extract(epoch from (least(end_at,b)-greatest(start_at,a)))/60)),0)
    into recovery from public.recovery_slots
    where user_id=u and is_protected and start_at<b and end_at>a;
  select public._ws_cap(count(*)::numeric/8*100),
    coalesce(sum(remaining_minutes) filter (where due_at>=a and due_at<=a+interval '48 hours'),0)
    into counts,due from public.tasks where user_id=u and status='planned';
  deadline := public._ws_cap(due/greatest(work,1)*100);
  capacity := case when available is null then null
    when available=0 and work>0 then 100
    else public._ws_cap(greatest(0,work-available)/greatest(available,1)*100) end;
  deficit := case when coalesce(settings.target_recovery_minutes,30)=0 then 0
    else public._ws_cap((coalesce(settings.target_recovery_minutes,30)-recovery)
      /coalesce(settings.target_recovery_minutes,30)*100) end;
  energy := case review.mental_energy_level when 'low' then 80 when 'moderate' then 50 when 'high' then 20 end;
  mental := public._ws_components(array[energy,(counts+deadline)/2,capacity,deficit],array[.30,.25,.25,.20],.5);
  time_score := case when available is null then null else
    public._ws_components(array[capacity,deadline,counts,deficit],array[.50,.25,.10,.15],.5) end;
  select (max(occurred_at) at time zone zone)::date into last_day
    from public.exercise_logs where user_id=u and occurred_at<b;
  if coalesce(settings.movement_tracking_enabled,false) and last_day is not null then
    energy := case review.physical_energy_level when 'low' then 80 when 'moderate' then 50 when 'high' then 20 end;
    physical := public._ws_components(array[
      public._ws_cap(greatest(0,d-last_day-coalesce(settings.movement_target_days,3))::numeric/4*100),energy],array[.70,.30],.7);
  end if;
  for e in select *, greatest(start_at,ws) clipped_start, least(end_at,we) clipped_end
    from public.social_events where user_id=u and start_at<we and end_at>ws
  loop
    minutes := floor(extract(epoch from(e.clipped_end-e.clipped_start))/60);
    if minutes<=0 then continue; end if;
    social_minutes := social_minutes+minutes;
    social_load := social_load+minutes*(case e.pressure_level when 'high' then 80 when 'moderate' then 50 when 'low' then 20 else 0 end);
    -- range_agg merges overlaps, preventing double/triple counting.
    with busy as (
      select start_at s,end_at t from public.social_events where user_id=u and id<>e.id
      union all select scheduled_start,scheduled_end from public.tasks
        where user_id=u and status='planned' and id is distinct from e.task_id and scheduled_start is not null
      union all select i.proposed_start,i.proposed_end from public.plan_change_items i
        join public.plan_changes c on c.id=i.plan_change_id
        where c.user_id=u and c.status='confirmed' and i.task_id is distinct from e.task_id
      union all select start_at,end_at from public.recovery_slots where user_id=u and is_protected
    ), merged as (
      select range_agg(tstzrange(greatest(s,e.clipped_start),least(t,e.clipped_end),'[)')) r
      from busy where s<e.clipped_end and t>e.clipped_start
    ) select coalesce(floor(sum(extract(epoch from(upper(segment)-lower(segment))))/60),0)
      into overlap_minutes from merged, lateral unnest(r) as segments(segment);
    conflicts := conflicts+overlap_minutes;
  end loop;
  if social_minutes>0 or exists(select 1 from public.social_week_responses
    where user_id=u and week_start=week_day and no_commitments) then
    social := .7*public._ws_cap(social_load/greatest(coalesce(settings.target_social_minutes_week,300)*80,1)*100)
      +.3*public._ws_cap(conflicts/greatest(social_minutes,1)*100);
  end if;
  if not exists(select 1 from public.tasks where user_id=u and status='planned' and load_category is null) then
    select count(*),coalesce(sum(remaining_minutes),0),coalesce(sum(remaining_minutes)
      filter(where due_at>=a and due_at<=a+interval '48 hours'),0) into n,minutes,soon
      from public.tasks where user_id=u and status='planned' and load_category='errand';
    errands := case when minutes=0 then 0 else public._ws_components(array[
      case when available is null then null else public._ws_cap(minutes/greatest(available,1)*100) end,
      public._ws_cap(soon/minutes*100), public._ws_cap(n::numeric/8*100)],array[.60,.25,.15],.6) end;
  end if;
  scores := array[mental,time_score,physical,social,errands];
  for i in 1..5 loop
    if scores[i] is not null then
      coverage:=coverage+weights[i]; total:=total+scores[i]*weights[i]; known:=array_append(known,names[i]);
    end if;
  end loop;
  if coverage>=.6 then score:=round(total/coverage); end if;
  select count(*),avg(total_score) into n,mean_score from public.world_status_snapshots
    where user_id=u and local_date>=d-7 and local_date<d and formula_version='world_status_v1' and total_score is not null;
  if n>=3 and score is not null then
    trend_name:=case when score-mean_score>5 then 'rising' when score-mean_score < -5 then 'easing' else 'stable' end;
  end if;
  insert into public.world_status_snapshots(user_id,local_date,mental_score,time_score,physical_score,
    social_score,errands_score,total_score,known_dimensions,coverage,trend)
    values(u,d,mental,time_score,physical,social,errands,score,known,coverage,trend_name)
    on conflict(user_id,local_date,formula_version) do update set
      mental_score=excluded.mental_score,time_score=excluded.time_score,physical_score=excluded.physical_score,
      social_score=excluded.social_score,errands_score=excluded.errands_score,total_score=excluded.total_score,
      known_dimensions=excluded.known_dimensions,coverage=excluded.coverage,trend=excluded.trend,computed_at=now();
end;
$$;

create function public._award_verified(p_user uuid,p_key text,p_source uuid,p_time timestamptz)
returns void language plpgsql security definer set search_path = '' as $$
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
$$;

create function public.evaluate_my_achievements() returns void
language plpgsql security definer set search_path = '' as $$
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
$$;

create function public.acknowledge_overload(p_task uuid) returns void
language plpgsql security definer set search_path = '' as $$
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
$$;

create function public._award_from_recovery() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.is_protected then
    perform public._award_verified(new.user_id,'protected_rest',new.id,new.created_at);
  end if;
  return new;
end;
$$;
create trigger recovery_award after insert or update of is_protected on public.recovery_slots
for each row execute function public._award_from_recovery();

create function public._award_from_task() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.is_protected and new.protected_commitment_type is not null then
    perform public._award_verified(new.user_id,'protected_limit',new.id,now());
    if new.protected_commitment_type='sleep_minimum' then
      perform public._award_verified(new.user_id,'protected_rest',new.id,now());
    end if;
  end if;
  return new;
end;
$$;
create trigger task_protection_award after insert or update of is_protected,protected_commitment_type
on public.tasks for each row execute function public._award_from_task();

create function public._award_from_plan() returns trigger
language plpgsql security definer set search_path = '' as $$
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
$$;
create trigger plan_confirmation_award after update of status on public.plan_changes
for each row execute function public._award_from_plan();

create function public._award_from_reflection() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform public._award_verified(new.user_id,'reflection',new.id,new.created_at);
  return new;
end;
$$;
create trigger reflection_award after insert on public.reflections
for each row execute function public._award_from_reflection();

revoke all on function public._ws_cap(numeric) from public,anon,authenticated;
revoke all on function public._ws_components(numeric[],numeric[],numeric) from public,anon,authenticated;
revoke all on function public._award_verified(uuid,text,uuid,timestamptz) from public,anon,authenticated;
revoke all on function public._award_from_recovery() from public,anon,authenticated;
revoke all on function public._award_from_task() from public,anon,authenticated;
revoke all on function public._award_from_plan() from public,anon,authenticated;
revoke all on function public._award_from_reflection() from public,anon,authenticated;
revoke all on function public.capture_world_status() from public,anon,authenticated;
revoke all on function public.evaluate_my_achievements() from public,anon,authenticated;
revoke all on function public.acknowledge_overload(uuid) from public,anon,authenticated;
grant execute on function public.capture_world_status() to authenticated;
grant execute on function public.evaluate_my_achievements() to authenticated;
grant execute on function public.acknowledge_overload(uuid) to authenticated;
commit;
