-- Requires 202610020002 request_id columns and unique owner/request indexes.
-- Preserve the original RPC for old clients. New clients use this explicit name.
begin;
create function public.create_social_event_once(
  p_start_at timestamptz,
  p_end_at timestamptz,
  p_pressure_level text,
  p_week_start date,
  p_request_id uuid,
  p_task_id uuid default null
) returns jsonb
language plpgsql security invoker set search_path = '' as $$
declare
  u uuid := auth.uid();
  saved public.social_events%rowtype;
  result jsonb;
  zone text;
  local_day date;
begin
  if u is null or p_request_id is null then
    raise exception 'Sign in and provide a request ID before saving.';
  end if;
  select time_zone into zone from public.profiles where id = u;
  local_day := (p_start_at at time zone coalesce(zone, 'UTC'))::date;
  if p_week_start is null or p_week_start is distinct from
      (local_day - (extract(isodow from local_day)::integer - 1)) then
    raise exception 'Social week does not match your profile time zone.';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(u::text || ':' || p_request_id::text, 0));
  select * into saved from public.social_events
    where user_id = u and request_id = p_request_id;
  if found then
    if saved.start_at is distinct from p_start_at or saved.end_at is distinct from p_end_at
       or saved.pressure_level is distinct from p_pressure_level
       or saved.task_id is distinct from p_task_id then
      raise exception 'Request ID already used with different input.';
    end if;
    return to_jsonb(saved);
  end if;
  -- Both the weekly response and request ID commit with the event, or roll back.
  result := public.create_social_event(p_start_at, p_end_at, p_pressure_level, p_week_start, p_task_id);
  update public.social_events set request_id = p_request_id
    where user_id = u and id = (result->>'id')::uuid returning * into saved;
  return to_jsonb(saved);
end;
$$;
revoke all on function public.create_social_event_once(timestamptz,timestamptz,text,date,uuid,uuid)
  from public, anon;
grant execute on function public.create_social_event_once(timestamptz,timestamptz,text,date,uuid,uuid)
  to authenticated;
notify pgrst, 'reload schema';
commit;
