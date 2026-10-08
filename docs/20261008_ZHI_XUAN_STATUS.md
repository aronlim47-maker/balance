# Chong Zhi Xuan — status at 8 October 2026

> Superseded for current status by [latest local verification](20261008_CHONG_LOCAL_VERIFICATION.md): e550f16, 213 tests. The baseline below is historical.

Baseline inspected: `717eeb3` (master, PR #10). The local data-foundation branch
has been fast-forwarded to this commit. PR #2 and PR #7 already integrated the
previous data foundation and history/lifecycle fixes. Being ahead of the old
remote feature branch does not mean these master commits are new personal work.

## Evidence and boundaries

- The 4 October entries in MVP1_ACCEPTANCE.md report deployed repair migrations
  and three successful SQL-role/claims rollback suites. This session reviewed
  those records; it did not rerun them or inspect the live database.
- Previous 151-test results apply to the 3 October revision, and the documented
  166-test result applies to 4 October. Neither proves this exact baseline.
- On 8 October, online dependency resolution did not complete and was stopped.
  Offline resolution failed because shared_preferences 2.5.6 is absent from the
  local cache. Current static analysis and full tests have NOT completed.
- User requested local checks only. No Supabase login, test records, migrations,
  credential changes, account creation or production writes were performed.

## Current contracts

See planning_adapter_compatibility.md for canonical database fields:
no_commitments, body, condition_text and source_key. The earlier draft names and
missing-file blocker in ZHI_XUAN_DATA_HANDOFF.md are historical.
Existing screen services use the atomic social RPC. The draft direct-insert
PlanningInputService social method must not replace that flow: it does not
atomically clear the weekly no-commitments response. acknowledgeOverload uses
server validation; legacy requestId/localDate arguments do not add deduplication.
Historical request-ID fallbacks are display identity, not retry evidence.

## Remaining acceptance

1. COMPLETE: locked dependencies, static analysis and 192 tests on the baseline.
2. Rehearse clean install and legacy upgrade on a disposable database; current
   production repair records do not establish these separate scenarios.
3. Use two genuinely signed-in test sessions for cross-owner read/write checks.
4. Exercise simultaneous requests and interrupted retries; verify Confirm/Undo,
   activity persistence and one award per user/key. Sequential SQL assertions
   are not evidence of actual network concurrency.
5. Verify time zones, Today/Profile score parity, Journey missing days, account
   switches and private-history navigation in the full application.
6. Record commit, migrations, environment, test result and evidence. Keep native
   email callback, notification delivery and release signing gates with the
   relevant owners; do not claim whole-MVP completion.

Items 2–5 remain pending and are not authorized for execution in the shared
Supabase project by this local-only session.

## Execution checklist for the next authorized acceptance session

No items below were executed in this local-only session. Use an approved test
project/accounts; confirm the target before any fixture creation. Never rerun
initial schema against the shared project. Do not put credentials in evidence.

| Case | Procedure | Pass condition | Status |
| --- | --- | --- | --- |
| Clean install / upgrade | Use a disposable empty database; separately upgrade legacy fixture rows through ordered migrations. | Both paths succeed; historical NULL/unknown values are preserved. | Pending |
| Two sessions | Sign A and B into separate browser profiles/devices; create clearly labelled own tasks/reflections. With authorized test tooling, attempt cross-owner reads and writes by known IDs. | Own records persist; cross-owner reads reveal nothing and writes have no effect. UI filtering alone is insufficient. | Pending |
| Social retry | Retry the identical request UUID/payload; repeat concurrently; then reuse the UUID with different content. | One matching event, atomic weekly-response update; changed payload rejected. | Pending |
| Council conflict | Two devices review the same task version; change the task on one and confirm the stale plan on the other. | Stale confirmation rejected; fresh confirmation and safe Undo remain consistent. | Pending |
| Achievement idempotency | Repeat an eligible verified action/evaluation from two sessions of the same test user. | Exactly one award per user/key, backed by trusted event evidence. | Pending |
| Date/history | Match profile and device time zones; compare Today/Profile after refresh and inspect a week containing uncaptured days. | Recorded scores agree; missing days stay unknown; no historical backfill. | Pending |
| Sign-out | Load private history, sign out during refresh, then sign in as the other user. | No old-account result is rendered or editable. | Pending |

For each case record: app commit, actual migration state, device/browser/OS,
account aliases A/B (no passwords/tokens), fixture IDs, steps, expected/actual
result, evidence reference and approved cleanup outcome. Do not delete genuine
team records. Coordinate cleanup of test awards/events with the project owner.
