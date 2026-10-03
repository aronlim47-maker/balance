-- Apply after 202609270002_verified_progress.sql.
-- Preserve previously applied migrations; only capture today's live state.
begin;
alter table public.world_status_snapshots add column is_partial boolean;

create function public.adjust_task_duration() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.estimated_minutes is distinct from old.estimated_minutes then
    new.remaining_minutes := old.remaining_minutes + new.estimated_minutes - old.estimated_minutes;
    if new.remaining_minutes < 0 then
      raise exception 'Duration cannot be less than already allocated work';
    end if;
    if new.scheduled_start is not null then
      if new.remaining_minutes = 0 then
        new.scheduled_start := null;
        new.scheduled_end := null;
      else
        new.scheduled_end := new.scheduled_start + make_interval(mins => new.remaining_minutes);
      end if;
    end if;
  end if;
  return new;
end;
$$;
-- Runs before the existing schedule validation triggers.
create trigger a_tasks_adjust_duration before update on public.tasks
for each row execute function public.adjust_task_duration();
revoke all on function public.adjust_task_duration() from public, anon, authenticated;
drop trigger tasks_validate_schedule on public.tasks;
create trigger tasks_validate_schedule
before insert or update of scheduled_start, scheduled_end, status, remaining_minutes, due_at, estimated_minutes
on public.tasks for each row execute function public.validate_task_schedule();

create or replace function public.capture_world_status() returns void
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
    join public.tasks t on t.id=i.task_id
    where t.status='planned' and c.user_id=u and c.status='confirmed' and i.proposed_start<b and i.proposed_end>a;
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
          and exists(select 1 from public.tasks t where t.id=i.task_id and t.status='planned')
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
    social_score,errands_score,total_score,known_dimensions,coverage,trend,is_partial)
    values(u,d,mental,time_score,physical,social,errands,score,known,coverage,trend_name,
      coverage<1 or (mental is not null and (review.mental_energy_level is null or available is null))
      or (physical is not null and review.physical_energy_level is null))
    on conflict(user_id,local_date,formula_version) do update set
      mental_score=excluded.mental_score,time_score=excluded.time_score,physical_score=excluded.physical_score,
      social_score=excluded.social_score,errands_score=excluded.errands_score,total_score=excluded.total_score,
      known_dimensions=excluded.known_dimensions,coverage=excluded.coverage,trend=excluded.trend,
      is_partial=excluded.is_partial,computed_at=now();
end;
$$;

commit;

