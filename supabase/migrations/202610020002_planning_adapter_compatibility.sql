-- Additive compatibility for PR #2 adapters against the Version 1.4 schema.
-- Run after 202610020001_recovery_history.sql. No historical values are guessed.
begin;

alter table public.exercise_logs add column if not exists request_id uuid;
alter table public.social_events add column if not exists request_id uuid;
alter table public.social_events add column if not exists has_conflict boolean;
alter table public.reflections add column if not exists request_id uuid;
alter table public.reflections add column if not exists local_date date;

-- NULL remains valid for legacy records and existing UI writers.
-- Retrying the same owner/request pair cannot create another row.
create unique index if not exists exercise_logs_owner_request_uidx
  on public.exercise_logs (user_id, request_id);
create unique index if not exists social_events_owner_request_uidx
  on public.social_events (user_id, request_id);
create unique index if not exists reflections_owner_request_uidx
  on public.reflections (user_id, request_id);

comment on column public.social_events.has_conflict is
  'Optional user-reported conflict; NULL means unknown. Not a server-verified scheduling result.';
comment on column public.reflections.local_date is
  'User-selected reflection date. Legacy NULL is unknown; achievement evidence still uses trusted server timestamps.';

-- Keep existing RLS, grants, body/no_commitments/condition_text/source_key
-- and server-verified achievement RPCs unchanged.
notify pgrst, 'reload schema';
commit;
