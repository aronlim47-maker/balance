# 4 October audit fixes

- Reminder refresh reads tasks and the device zone before cancelling the existing
  schedule. A read failure retains reminders and exposes a safe English warning.
  Disabling reminders, denied permission and account changes still clear them.
- Committed task create/update/delete return without waiting for reminder I/O.
  Reminder work stays serialized and account-generation guarded in its controller.
- Council sends the reviewed task version. The new migration checks it while
  holding the task row lock, before any writes; missing/stale versions abort the
  transaction. Existing protection, capacity, ownership and undo rules remain.
- Social week boundaries use calendar dates, including DST and year transitions.

## Required database handoff

Apply `supabase/migrations/202610040001_plan_review_version.sql` only after all
earlier migrations. Do not rerun old migrations to upgrade an existing database.
The new client requires Council schema version 3 and disables confirmation on an
older backend. Old clients without a reviewed task version must refresh/update;
the database deliberately refuses their unversioned confirmations.

Remote verification: review a plan on device A, edit that task on device B, then
confirm on A. It must fail with a safe refresh message and create no plan change.
Refresh A and verify normal confirmation and undo still work. Also test two Auth
users and concurrent updates. Local syntax/unit checks do not prove these gates.

Production app ID/signing, device notification delivery, iOS and full MVP2–4
backlog remain separate release gates. This change does not deploy or push code.

## Remote acceptance follow-up

Lim approved the first three-script repair transaction. It succeeded and the
updated active-planning/retry script passed with final rollback. The security
script passed using two existing Auth identities as local database claims, not
actual browser login sessions. No fixture tasks remained after the first test.

World Status snapshot execution revealed a separate partially installed
verified-progress dependency graph. The additive `202610040002` repair restores
only missing original helpers, evaluator/acknowledgement RPCs and award triggers.
Existing definitions and snapshots are preserved. Helpers stay private; only
the two owner-bound public RPCs regain authenticated execution permission.
Lim approved this second repair with “solve it”. After Dashboard recovery,
a read-only catalog query confirmed the initial submission had not installed
the helpers. Resubmission succeeded: snapshot helper/evaluator present and
four award triggers installed. `verified_progress_runtime.sql` passed (daily
snapshot, trusted reflection evidence, repeat evaluation and private helper
permissions), with rollback. The planning/retry and cross-account security
scripts then passed again with the new triggers active and final rollback.
Actual authenticated browser/device flows remain separate acceptance gates;
database role/claims tests are not two live login sessions or concurrency tests.
