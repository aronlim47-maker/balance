-- Event creation and the associated weekly response are one transaction.
-- SECURITY INVOKER preserves the existing grants and ownership RLS policies.
begin;

create or replace function public.create_social_event(
  p_start_at timestamptz,
  p_end_at timestamptz,
  p_pressure_level text,
  p_week_start date,
  p_task_id uuid default null
) returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  u uuid := auth.uid();
  saved public.social_events%rowtype;
begin
  if u is null then
    raise exception 'Sign in before adding a social event.';
  end if;
  if p_week_start is null or extract(isodow from p_week_start) <> 1 then
    raise exception 'Choose a valid week for the social event.';
  end if;

  -- Existing CHECK and composite foreign-key constraints validate duration,
  -- pressure, and ownership of any linked task. A failure rolls back both writes.
  insert into public.social_events(user_id, start_at, end_at, pressure_level, task_id)
  values(u, p_start_at, p_end_at, p_pressure_level, p_task_id)
  returning * into saved;

  insert into public.social_week_responses(user_id, week_start, no_commitments)
  values(u, p_week_start, false)
  on conflict(user_id, week_start) do update
    set no_commitments = false, recorded_at = now();

  return to_jsonb(saved);
end;
$$;

revoke all on function public.create_social_event(timestamptz,timestamptz,text,date,uuid)
  from public, anon;
grant execute on function public.create_social_event(timestamptz,timestamptz,text,date,uuid)
  to authenticated;

commit;
