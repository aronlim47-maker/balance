# MVP 1 acceptance and judge walkthrough

本文件记录第一版个人功能的验收入口。开发者和 AI 必须根据真实测试结果勾选，
不能用源码存在、模拟数据或本地单元测试代替 Supabase 和真机验收。

## Implemented personal scope

- [x] Account signup, sign in and sign out with safe English error messages.
- [x] Account help for password recovery and verification resend.
- [x] Recovery page guarded by Supabase's verified passwordRecovery event.
- [x] Quest create/edit, explicit category, search/filter/date range/sort.
- [x] Today availability, Daily Review, task detail and confirmed move visibility.
- [x] Five-dimension World Status with Unknown/Partial rather than invented data.
- [x] Council safe Confirm/Undo, protected commitments and private plan history.
- [x] Sanctuary recovery and recorded exercise/social inputs.
- [x] Journey personal achievements, captured weekly history and private reflections.
- [x] Team Coordination remains locked pending genuine V2 collaboration evidence.

These marks describe implementation, not final production sign-off. Native email
delivery and database behavior still require the tests below. Council now supports
bounded deterministic multi-task alternatives with an affected-day preview; it is
not personalized prediction. Durable offline sync and fuller release evidence remain
separate backlog items.

## Required remote and device evidence

- [ ] Apply only unapplied migrations in README order; rehearse clean install and upgrade.
- [ ] Rerun the expanded active-planning, retry, achievement and isolation behavior
  scripts on a disposable Supabase project with a test Auth account and confirm
  they roll back.
- [x] 4 Oct SQL-role/claims rollback test: stale/missing task versions rejected;
  Confirm/Undo, completed/cancelled occupancy release and social retry passed.
- [x] 4 Oct two-account SQL-role/claims test: activity/award isolation, linked-task
  ownership, duplicate requests/awards and forged event-write rejection passed.
- [ ] Two Auth users cannot read or change each other's tasks, plans, reviews or awards.
- [ ] Duplicate/uncertain requests and concurrent Confirm/Undo keep consistent records.
- [x] Mobile redirect allowlist configured with the exact approved callback.
- [ ] Signup/resend/reset email flows verified on a real device.
- [ ] Recovery tested with app open/closed, expired links and wrong/new passwords.
- [ ] Profile time zone matches device; Today and Profile show matching recorded scores.
- [ ] Real device full journey passes; English labels, text size and keyboard are usable.
- [ ] Release signing and permanent application ID selected for final distribution.
- [ ] GitHub checks pass for the exact submitted commit.

## Judge walkthrough

1. Install the configured build and sign in to a prepared account. Profile must
   show the cloud account, not Preview user. Set the planning time zone.
2. Create or inspect tasks in Quests. Use category/search filters, open a task,
   and explain that protection prevents automatic rescheduling.
3. In Today, inspect available and planned time, task details and five dimensions.
   Add an optional Daily Review. Missing input remains Unknown; this is a planning
   estimate, not a medical assessment.
4. Use the README two-day overload fixture. Compare the Council suggestion, confirm,
   check the destination in Today, reopen Plan history, then undo. If current data
   makes a move unsafe, show the explanation and add realistic availability or seek
   an agreed task change instead of overriding protected commitments.
5. In Sanctuary, record protected recovery and exercise/social information.
   Refresh Journey and inspect awards supported by actual recorded actions.
6. Save a reflection and reopen it from View my reflections. Weekly history needs
   days actually captured when the app was used; do not invent missing past scores.
7. Sign out and verify private data is inaccessible. Repeat with the second account.

## Evidence log

4 October remote repair and acceptance (after commit `9e0ef61`): with Lim's
approval, `202610030001`, `202610030002`, then `202610040001` were applied inside
one transaction. The database returned Council schema 3 and the retry-safe social
RPC existed. `active_planning_and_retry.sql` was updated for task-version consent
and executed with final rollback. A read-only check found zero leftover fixture
tasks. The existing World Status/achievement security script also passed with two
existing accounts, `SET LOCAL ROLE authenticated` and local JWT subject claims.
This tests database policy behavior, not two independently signed-in UI sessions
or simultaneous network requests. Do not mark those broader gates complete.

The exact app commit was rebuilt successfully: configured Android test APK
(56.2 MB) and configured Web release. The APK still uses debug signing. During
Web acceptance, the app displayed "History is unavailable"; a rollback RPC test
identified missing `_ws_cap`, `_ws_components` and verified-achievement engine
dependencies. Repair migration `202610040002_restore_progress_helpers.sql` and
runtime test `verified_progress_runtime.sql` are complete for this database gate.
Lim authorized the repair with “solve it”. After recovery, a catalog query proved
the initial submission had not installed the helpers. Resubmission succeeded
(helper/evaluator present, four triggers). Runtime snapshot/achievement checks
and both planning/retry and security regression scripts passed with rollback.
This does not complete actual browser/device or concurrent-session acceptance.

4 October local verification: Flutter analysis passed and all 166 tests passed.
The configured Android test APK built successfully at
`build/app/outputs/flutter-apk/app-release.apk` (54.6 MB reported by Flutter).
This build still uses the existing debug signing configuration and is for internal
device testing. No iOS build or actual email delivery test was performed.

7 October Matthew-ownership follow-up: expanded the rollback-only achievement
fixtures to check positive evidence for Protected Rest, Protected Limit, Early
Review, Reflection, Safe Trade-off and Deadline Safety; negative evidence checks
cover an ordinary protected task without a commitment type and personal evidence
not unlocking Team Coordination. Stale/rejected plan proposals must not create
achievement evidence. The edited SQL scripts pass local PostgreSQL syntax and
PL/pgSQL parsing. **The expanded database fixtures have not yet been rerun remotely**;
keep runtime acceptance unchecked until they pass in the disposable Supabase test
account and roll back cleanly. The test task should have no overlapping current-day
availability or tasks because the Early Review fixture uses today's actual date.

7 October build verification: Flutter analysis passed with no issues; all 204
Flutter tests passed; the configured Android release APK built successfully at
`build/app/outputs/flutter-apk/app-release.apk` (56.2 MB), including multi-task
Council suggestions. Gradle emitted an SDK XML version compatibility warning on
the earlier build but completed successfully. The APK uses the debug signing key
and is for internal testing only; select a permanent application ID and configure
release signing before distribution. The newly expanded remote database fixtures
still need a clean, disposable-account rollback run.

7 October emulator smoke test: `Medium_Phone` booted, the newly built APK installed
successfully, and `com.example.balance/.MainActivity` remained foreground with a
live process after launch; no Android fatal-exception/crash signature was found in
the checked log window. Profile showed “Supabase mode”, loaded 21 active and 3
completed tasks, and showed the same 58/100 Partial World Status as Today. This is
an authenticated read/session smoke test, not a write/Confirm/Undo acceptance.
Physical-device behavior remains unchecked. No `supabase`, `psql`, or test-database
connection configuration is installed in this workspace, so the SQL scripts have
not been executed remotely.

7 October Supabase dashboard read-only verification: the target project returned
Council schema version 3; the live catalog contains the current four-argument
`confirm_plan_change`, `undo_plan_change`, retry-safe `create_social_event_once`,
and `calculate_day_overload` functions. The live `confirm_plan_change` definition
contains reviewed-task-version and overlapping-move checks, and the social RPC
rejects a reused request ID with changed input. The five-dimension helper functions,
verified-achievement evaluator, overload acknowledgement RPC, and all four
achievement triggers are present. RLS is enabled on the ten inspected personal,
planning, and achievement tables; inspected policies scope authenticated access to
`auth.uid()` and keep planning events and awards read-only to the client. These are
catalog/configuration checks only, not proof that each RPC behavior passes its test.
The project does not expose `supabase_migrations.schema_migrations`, so the exact
historical migration list cannot be verified from the dashboard SQL editor. The
expanded transaction fixtures were deliberately not run against the live personal
project: `active_planning_and_retry.sql` is documented for a disposable project,
and `verified_progress_runtime.sql` uses today's overload state. Use a separate
disposable Supabase project and test Auth user before marking behavioral regression
acceptance complete.

Dashboard verification on 4 October: the target project reported Healthy.
After Lim's approval, the agent added `com.balance.app://auth-callback/` to
Authentication Redirect URLs and verified the saved list displayed that exact
address with Total URLs 1. Site URL remains `http://localhost:3000`; mobile
requests explicitly supply the approved callback. Real email delivery and device
link tests remain pending. Dashboard health does not establish migration or RLS
test success.

8 October Matthew World Status explainability work: the Today card now labels the
practical feature as **Workload Overview** and retains **World Status** as its RPG
name. Expanding “How is this calculated?” and a dimension now shows its component
scores, weighted contribution points, evidence summary and available source task,
recovery or social-event records. Unknown components remain explicitly unknown;
missing planned minutes are not described as zero. Past snapshots only store daily
dimension totals today, so they cannot reconstruct component-level explanations.
Focused regression assertions were added for weighted contributions, unknown values,
source labels and the Today explanation UI. These changes were verified on 8 October:
`flutter analyze --no-pub` reports no issues and the complete `flutter test --no-pub`
suite passes all 204 tests. The 390-pixel responsive-navigation regression also
passes after stacking the World Status title tag and load summary on narrow layouts.
This is local automated evidence only; it does not replace phone/emulator or live
Supabase acceptance.

Matthew MVP2/MVP3 boundary: the app keeps Needs Agreement work out of automatic
confirmation and requires real agreement evidence before moving another person's
commitment. The collaboration backend and genuine multi-user/device evidence are
not present, so that capability must remain unavailable rather than simulated.
MVP3 currently has bounded, explainable rules-based Council alternatives; this is
not personalized forecasting or health prediction. Evaluate recommendation quality
on realistic calendars and close real-device and remote Confirm/Undo acceptance
before marking those gates complete.

Record the commit hash, migration list actually applied, device/OS, build command,
test date and result. Capture failure messages without passwords, tokens or keys.
Use `20261003_FIX_AND_DATABASE_HANDOFF.md` for the SQL and retry contracts. Final
MVP 1 completion requires closing the remote/device gates above.
