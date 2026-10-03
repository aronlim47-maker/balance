# PR #2 / Version 1.4 compatibility

Apply `supabase/migrations/202610020002_planning_adapter_compatibility.sql`
after all earlier migrations, using the Supabase SQL Editor. This is additive:
it does not delete data, disable RLS, or grant clients achievement-write access.

Canonical database names remain `no_commitments`, `body`, `condition_text`,
and `source_key`. New adapters now use those names rather than draft aliases.
Exercise, social and reflection inserts gain nullable UUID `request_id` with
owner-scoped uniqueness. Reuse the same UUID and unchanged payload on retry.
Historical rows have no request UUID; mapper fallback to row ID is display
identity only, not proof that the original request was deduplicated.

Reflections gain optional `local_date`. Undated legacy rows stay unknown and
do not appear in explicit local-date range queries. Do not fabricate dates.
Social `has_conflict` is optional self-report, not a verified scheduling result.
Neutral is a valid social pressure value, not a Daily Review energy value.

Overload acknowledgement calls the existing verified server RPC. Its legacy
requestId/localDate arguments do not provide request deduplication or override
the server date. Awards remain server-verified and uniquely constrained.

These PR #2 adapters are not wired to the current screens. Keep the existing
atomic `create_social_event` UI flow. Do not wire the draft direct-insert social
adapter without also making the weekly-response update atomic.

Verification: local mocked tests do not prove deployed schema or RLS. After
applying SQL, validate authenticated writes and same-request retries, and use
two accounts to verify isolation. Anonymous permission-denied responses are
expected and must not be treated as evidence that owner access works.
