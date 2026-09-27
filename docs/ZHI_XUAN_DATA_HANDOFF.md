# Zhi Xuan: data foundation draft

Status: local implementation draft; not deployed to Supabase. Existing auth,
RPCs and screens are unchanged. Do not mark the sprint's database/security
checks complete until the SQL has run on a disposable Supabase database.

## Delivered boundaries

- Migration `202609270001_world_status_achievements.sql`, after the two existing migrations.
- Typed row models and strict date-only `LocalDate`.
- Read mappers, `WorldStatusRepository`, `JourneyRepository` and proposed
  `PlanningInputRepository` contracts. `PlanningReadService` implements the two
  read repositories; input writes remain an interface only. Services are not
  wired into Provider/screens until the migration is deployed and verified.
- Local mapper/date tests and a rollback-only SQL security test script.

## Migration behavior

Existing tasks retain NULL category. Existing check-in ratings retain their old
1–5 meaning; new low/moderate/high energy fields are independent. Existing
clients can continue inserting tasks without category. Tan must ship and verify
the new input UI before a separate migration enforces category on new inserts.
Do not rewrite either previously applied migration.

Owned raw input tables permit owner CRUD. Overload acknowledgements are
append-only for clients and use server reviewed_at. They are untrusted input:
a trusted evaluator must verify the actual overload, deadline, user time zone
and committed source before creating a planning event. A client local_date is
not proof that a review occurred before a deadline day.

Snapshots, planning events and awards permit owner SELECT only for authenticated
clients, including no UPDATE/DELETE grants. The catalogue is readable by signed-in
users. Trusted server code must validate sources; service_role must never enter
the Flutter app. This migration creates storage, NOT a trusted writer/calculator.

Composite foreign keys prevent linking a user's activity/review to another user's
task or linking an award to another user's event. Linked task deletion is restricted:
Tan must explicitly unlink/delete the activity first; review history requires a
retention decision. UUID request_id must remain stable across retries. Unique
constraints prevent duplicates but do not by themselves implement successful
retry responses: adapters must return the original matching record, and reject
a reused key with a different payload. Never use overwrite-on-conflict for awards.

Snapshot uniqueness is (user_id, local_date, formula_version). Known dimensions
are ordered mental/time/physical/social/errands and must exactly match non-null
scores. Coverage is weighted, not a dimension count. Unknown is NULL, never zero.
The trusted calculator owns formula consistency and source explanation.
Catalogue definitions are keyed by (achievement_key, rule_version); a new rule
version adds a definition rather than rewriting the version referenced by an old
award. Awards remain unique per user and achievement key across rule versions.

## Handoffs needed

| Owner | Confirm before implementation/deployment |
| --- | --- |
| Matthew | Approved formula coefficients and source mappings; missing-source explanations; seven eligibility predicates and positive/negative fixtures. |
| Tan | Input shape, activity intensity vocabulary, explicit cancellation/unlink behavior, Monday week boundary, category deployment readiness. |
| Lim | Stable confirmed-action event keys, event_type/payload schema, source references and transactional event emission; achievement read UI. |
| Chong | Test clean install and populated upgrade; ownership tests; trusted writer implementation and paginated repository adapters. |

Proposed details needing review: request_id UUIDs; Monday week_start; exercise
source manual/consented_import; free-text optional intensity; event evidence JSON
and event_type; overload review task link; task deletion restriction. These are
draft implementation choices, not additional PDF requirements.

LocalDate is a calendar date already derived in profiles.time_zone. DateTime
ranges must be explicit UTC instants computed from that zone, not device midnight.
Read ranges are inclusive start/exclusive end. Social reads include overlapping
events (start_at < until AND end_at > from). Exercise history may need dates before
the visible week. Snapshot reads filter formula version. Awards are lifetime,
not filtered to the selected week. Implement pagination rather than silently
accepting Supabase's row cap. Empty weekly evidence is not zero workload.

## Not implemented by this draft

No five-dimension calculator, achievement evaluator, automatic events, UI changes,
score/award write RPC or weekly derived summary. Journey interfaces expose source
evidence only; weekly metrics still need agreed definitions and aggregation.
No database deployment, live auth/RLS/RPC verification or Android build claim.
Team Coordination must remain locked until genuine V2 shared-task evidence exists.
Current required due_at/No deadline mismatch is outside this additive migration;
coordinate with Tan/Matthew before changing the existing task/RPC contract.

## Validation after access returns

1. Use a disposable Supabase project; apply all three migrations in order.
2. Also test upgrading a copy containing legacy NULL-category tasks/check-ins.
3. Create two disposable users through Supabase Auth; run the SQL test with their
   UUIDs. Do not create users by inserting directly into auth.users.
4. Re-run existing Confirm/Undo tests and confirm rollback and data persistence.
5. Review SQL grants, linked-record ownership, retry and concurrent duplicate cases.
6. Only after review, deliberately deploy and record results. Committing SQL is
   not proof that a remote database has migrated.

## Local verification (27 September 2026)

- Flutter analyze: no issues.
- Flutter test: 46 passed (39 existing + 7 new).
- PostgreSQL parser: migration and SQL test syntax accepted (pglast 8.4).
- Tests ran in an isolated source copy with locked dependencies because this
  session cannot create Windows plugin symlinks in the original project.
- SQL assertions have NOT executed: no PostgreSQL/Supabase test server is available.
- No Supabase data changed. No commit or push was made.

## Read adapter follow-up (28 September 2026)

`PlanningReadService(Supabase.instance.client)` implements both read repositories.
It binds user_id from the current session, rejects unauthenticated reads, and
discards results if the account changes during a request. It does not replace RLS.
Missing settings/week responses remain null; server/missing-table failures propagate
to view models rather than pretending an empty result is valid.

All multi-row reads page in batches of 100 with stable ordering. Short server pages
are followed until an empty page; over 10,000 rows fails explicitly instead of
returning partial history. Offset pagination is not a database snapshot: concurrent
edits may change a history listing; refresh after edits. Trusted calculations must
read transactionally on the server, not derive authoritative scores from this adapter.
No automatic retry or user-facing exception text is added here.

Social event reads include overlap with the requested UTC interval; snapshots and
reflections use half-open LocalDate ranges. Formula/catalogue versions are explicit.
Achievement reads are lifetime and never write awards. No write endpoint or online
database call was made by the tests.

Verification: static analysis clean; 55 tests passed (9 new mocked-HTTP adapter
tests). `http` 1.6.0 is now an explicit dev dependency; its locked version did not
change. Tests cover pagination, owner/date/version filters, crossing-midnight
events, missing migration errors, invalid ranges, absent data and logout races.
