-- Read-only checks after applying 202609270002_verified_progress.sql.
-- Run in Supabase SQL Editor. These checks do not prove RLS isolation;
-- SQL Editor usually runs as a privileged role. Test RLS with two app users.
select
  to_regprocedure('public.capture_world_status()') is not null as snapshot_rpc_exists,
  to_regprocedure('public.evaluate_my_achievements()') is not null as award_rpc_exists,
  to_regprocedure('public.acknowledge_overload(uuid)') is not null as review_rpc_exists,
  has_function_privilege('authenticated','public.capture_world_status()','EXECUTE') as user_can_capture,
  not has_function_privilege('anon','public.capture_world_status()','EXECUTE') as anon_cannot_capture,
  not has_function_privilege('authenticated','public._award_verified(uuid,text,uuid,timestamptz)','EXECUTE') as user_cannot_forge_award;

select tablename, rowsecurity from pg_tables
where schemaname='public' and tablename in
  ('world_status_snapshots','planning_events','user_achievements','reflections','overload_reviews')
order by tablename;

select policyname, tablename, cmd from pg_policies
where schemaname='public' and tablename in
  ('world_status_snapshots','planning_events','user_achievements','reflections','overload_reviews')
order by tablename, policyname;
