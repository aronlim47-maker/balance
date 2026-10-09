# Chong: WS11 and judge fixture delivery — 8 October 2026

Base: e550f16, confirmed against GitHub before implementation.
Status: local implementation; not deployed, not committed/pushed.

## WS11 required category

New migration: `202610080001_require_task_category.sql`, after all earlier migrations.
The insert trigger rejects omitted/NULL categories for every database role. The
existing category CHECK still validates non-NULL values. No legacy values are
rewritten: old NULL rows remain editable and can acquire a real category. Once
classified, a task cannot be reset to NULL. No RLS/grants are broadened; the trigger
is security invoker with an empty search path. The app maps this one constraint
error to "Choose a task category before saving."

Deployment gate: all supported clients must send category on creation. An older
client that omits it will fail deliberately; coordinate rollout with Lim/Tan.
Do not edit old migrations or convert old NULL to Other. Deploy the additive file
only after disposable-database tests and client compatibility review.

`task_category_required.sql` covers omitted/explicit NULL rejection, all five
categories, legacy NULL editing, reclassification and clearing rejection. It
simulates a pre-migration row by temporarily disabling ONLY the new trigger in
one transaction on a disposable database; it re-enables it and rolls back all
changes. This is not authorization to disable triggers on the shared database.
The existing ownership test now creates classified fixtures; legacy testing lives
in the dedicated WS11 script.

## Judge sample day

`supabase/manual/20261008_judge_demo.sql` is a psql script, not a paste-ready SQL
Editor script. It requires an existing dedicated Auth account and its exact UUID
and email; it never creates accounts. Use a disposable project for rehearsal.
Set the profile time zone to match the intended demo device before running.

Example (connection string stays in the local environment, never in Git):

```powershell
psql "$env:TEST_DATABASE_URL" -v ON_ERROR_STOP=1 -v judge_user=UUID -v judge_email=EMAIL -v demo_date=YYYY-MM-DD -v persist=false -f supabase/manual/20261008_judge_demo.sql
```

The default is rollback. Only after preview, review and explicit target approval,
use `persist=true` for the designated judge account. Do not run it against an
ordinary team member account. It refuses accounts with existing business records,
locks the profile and user planning transaction, and rejects past dates.

Day 1: 09:00–12:00 availability (180 minutes), a scheduled 180-minute flexible
Study task plus an unscheduled 120-minute task due that day (300 planned).
Day 2: 09:00–11:00 availability; the flexible task deadline permits a two-hour move.
The server overload calculation must equal 120 or the transaction fails.
The script does not confirm a plan, unlock awards, write snapshots or invent past
history. The judge demonstrates Confirm/Undo through the app. Existing committed
fixtures are never deleted/overwritten; use a fresh approved account for a rerun.
Keep both sessions signed out during fixture creation; do not race normal app use.

## No deadline

Design proposal: see `NO_DEADLINE_DESIGN.md`. This is not shipped functionality
and not an approved release-scope change. Keep it deferred until Lim/Tan confirm
that every client/server path and the tests can be changed together.

## Validation limits

SQL/PLpgSQL syntax parsing passed for 13 migrations, 5 test scripts and the judge
script. Runtime PostgreSQL/Supabase execution remains pending; syntax parsing does
not validate table resolution, grants, trigger effects or the fixture assertion.
No local PostgreSQL/psql/Docker command was available for a runtime rehearsal.
No online database actions were performed. Real sessions/concurrency still pending.

Final local verification: Flutter analyze passed with no issues; all 214 Flutter
tests passed after adding the category-error regression. SQL syntax results cover
13 migrations, 5 rollback test scripts and the judge seed. These results apply to
the uncommitted working changes based on e550f16, not a new published commit.
Evidence files: chong-delivery-analyze.txt, chong-delivery-tests.txt,
chong-delivery-sql.txt in this task's local outputs directory.
