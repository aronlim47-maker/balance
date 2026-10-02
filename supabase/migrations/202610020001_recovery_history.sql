-- Keep historical recovery evidence in the same daily snapshot as scores.
-- No backfill: current recovery slots cannot prove what was protected in the past.
begin;
alter table public.world_status_snapshots add column had_protected_recovery boolean;

create function public.capture_snapshot_recovery() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  zone text;
  day_start timestamptz;
  day_end timestamptz;
begin
  select coalesce(time_zone, 'UTC') into zone
    from public.profiles where id = new.user_id;
  zone := coalesce(zone, 'UTC');
  if new.user_id = auth.uid() and new.local_date = (now() at time zone zone)::date then
    day_start := new.local_date::timestamp at time zone zone;
    day_end := (new.local_date + 1)::timestamp at time zone zone;
    new.had_protected_recovery := exists(
      select 1 from public.recovery_slots
      where user_id = new.user_id and is_protected
        and start_at < day_end and end_at > day_start);
  elsif tg_op = 'UPDATE' then
    new.had_protected_recovery := old.had_protected_recovery;
  else
    new.had_protected_recovery := null;
  end if;
  return new;
end;
$$;
create trigger snapshots_capture_recovery before insert or update
  on public.world_status_snapshots for each row
  execute function public.capture_snapshot_recovery();
revoke all on function public.capture_snapshot_recovery() from public, anon, authenticated;
commit;
