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
