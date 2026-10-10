# Balance — workload planning for overloaded students

**Team Gate of Steiner:** Lim Ze Heng, Tan Yi Ming, Chong Zhi Xuan, Matthew Thien Yung En
**Problem statement:** Stress & Workload Manager

| | |
| --- | --- |
| 📱 **Download (Android APK)** | [Latest release](https://github.com/aronlim47-maker/balance/releases/latest) |
| 📖 **User guide for judges** | [docs/USER_GUIDE.md](docs/USER_GUIDE.md) |
| 🎬 Preliminary pitch video | [YouTube](https://www.youtube.com/watch?v=DV6PFbYdbk8) |
| 🖼️ Preliminary slides | [Google Slides](https://docs.google.com/presentation/d/1_ctq2F96NrVD1dD9PSV1PLKwfyI83E4G-brSaejZjLE/edit?usp=sharing) |

## What Balance does

University students juggle assignments, exams, part-time shifts, family duties and
group work in the same few hours. When the plan no longer fits, they need to know
three things: **what must stay protected, what can move, and what each change will
cost.** Balance answers those questions in one flow:

**Detect → Decide → Recover → Reflect**

| Practical feature | RPG label | What it does |
| --- | --- | --- |
| Workload Overview | World Status | Planned vs available minutes, five load dimensions (Mental, Time, Physical, Social, Errands) and a 7-day trend. Missing data shows **Unknown**, never zero. |
| Tasks and Protected Commitments | Quest Board | Tasks with category, duration, deadline, flexibility and protection. Protected work is never moved to make a plan look feasible. |
| Plan Comparison | War Council | Compares safe moves and shows what changes, what stays protected and the cost on other days. Nothing changes until you **Confirm**; every confirmed plan can be **Undone**. |
| Recovery Time | Sanctuary | Protects genuinely freed time for optional rest. Skipping has no penalty. |
| Weekly Reflection | Journey | Private weekly summary, optional reflection and seven sustainable-planning achievements. No streaks, rankings or rewards for overwork. |

Balance is a planning aid. Its scores describe recorded planning data; they are not a
medical, diagnostic or mental-health assessment.

## Try it in five minutes

1. Install the APK from the [latest release](https://github.com/aronlim47-maker/balance/releases/latest)
   on an Android phone (allow installing from this source when asked).
2. Sign in with the judge account supplied in our submission form. Credentials are
   never stored in this repository.
3. **Today:** the sample evening has 300 planned minutes but only 180 available — a
   120-minute overload — and five World Status bars.
4. **Council:** compare the options, **Confirm** one, check Today, then **Undo** it.
5. **Sanctuary:** see the protected recovery slot. **Journey:** see the weekly summary and
   the seven achievement cards.

Step-by-step instructions with screenshots are in the [user guide](docs/USER_GUIDE.md).

## Scope and known limitations

- Android is the supported platform. A web build compiles but has not passed browser
  acceptance; iOS has not been tested on a device.
- **Team Coordination** stays Locked: shared tasks with real agreement workflows are a
  future version.
- Every task needs a deadline; a "No deadline" option is a design proposal only.
- The app is currently English-only. Bahasa Melayu and Chinese, selectable in Profile,
  are planned.
- Email verification and password-reset links must be opened on the same phone that
  requested them.

## Built with

Flutter and Dart (Android first) · Supabase Auth, PostgreSQL, Row Level Security and
transactional RPCs · Provider + go_router. The [Architecture](#architecture) and
[Testing and coverage](#testing-and-coverage) sections below give details: 341
automated tests pass and critical code has 91.7% line coverage, enforced by CI.

---

# Developer documentation

## Latest Council upgrade (4 October)

After every earlier migration, apply
`supabase/migrations/202610040001_plan_review_version.sql` once. Council now
requires schema version 3: confirmation carries the reviewed task version and
the server rejects missing/stale versions before writing. Existing databases
must apply only unapplied migrations, not rerun the initial schema. See
`docs/20261004_AUDIT_FIXES.md` for the two-device acceptance test and release gates.

For a partially installed verified-progress backend, apply the next additive
repair `202610040002_restore_progress_helpers.sql`. It installs missing original
dependencies without replacing existing definitions or reconstructing historical
scores. Validate with `supabase/tests/verified_progress_runtime.sql` on a disposable
database; it uses an existing Auth test user and rolls back its fixture writes.

Balance is a Flutter workload-planning application with personal tasks, five-dimension World Status, Supabase authentication, safe Council Confirm/Undo, Sanctuary, private Journey and plan/reflection history. This is an implemented V1 foundation, not a claim that release and live security gates have passed.

## Supabase setup

1. Create a Supabase project.
2. Open the Supabase SQL Editor and run each unapplied migration once, in filename order: `202609240001_initial_schema.sql`, `202609250001_war_council_integrity.sql`, `202609270001_world_status_achievements.sql`, `202609270002_verified_progress.sql`, `202610010001_planning_consistency.sql`, `202610010002_atomic_social_event.sql`, `202610020001_recovery_history.sql`, `202610020002_planning_adapter_compatibility.sql`, `202610030001_active_planning_occupancy.sql`, `202610030002_retry_safe_social_event.sql`, `202610040001_plan_review_version.sql`, `202610040002_restore_progress_helpers.sql`, then `202610080001_require_task_category.sql` **only after confirming every supported app client submits a category for new tasks and validating the migration against a disposable database**. The latest migration intentionally rejects new tasks with an omitted/NULL category but preserves legacy NULL rows; an older client will fail to save new tasks after it is deployed. For an existing database, apply only migrations not already run. Each migration depends on those before it. Social-event creation requires the atomic-social-event migration; do not fall back to separate writes. Recovery history requires `202610020001_recovery_history.sql` and is recorded only when today's World Status is captured; past days are not backfilled.
3. Copy `.env.example` to `.env`.
4. Put the project URL and publishable key in `.env`. Never use the `service_role` key in the Flutter application.
5. Run the app with:

```powershell
flutter run --dart-define-from-file=.env
```

In Android Studio, the local `main.dart` Flutter run configuration includes `--dart-define-from-file=.env` in **Additional run args**. Select that configuration and the Android emulator, stop any old local-preview instance, then press Run again. If Android Studio recreates the configuration, add the same argument under **Run > Edit Configurations > Flutter > Additional run args**. A hot reload cannot change compile-time Dart defines; start a new run.

For an Android APK, build it with the same compile-time configuration:

```powershell
flutter build apk --release --dart-define-from-file=.env
```

The permanent Android application ID is `com.gateofsteiner.balance`. Release signing reads `android/key.properties` (copy `android/key.properties.example`); the file and the `.jks` keystore are git-ignored and must stay out of Git. Without `key.properties` the release build falls back to the debug key and prints a warning: such an APK is for internal testing only and must not be distributed. Because the ID changed from `com.example.balance`, uninstall any earlier test build before installing; verify a fresh install on a real device before publishing.

Install that newly built APK on the device. A debug app started without the `--dart-define-from-file=.env` argument runs in local preview mode even when `.env` exists on the computer. A release app without these values stops with a configuration notice instead of silently entering preview. The app now displays a persistent local-preview banner and the Profile page shows the connection mode. Tasks made in local preview are only in memory; they are not sent to Supabase and cannot be automatically recovered or synced after switching modes. Re-create those tasks after launching the configured build.

The first migration creates the seven MVP tables, automatically creates a profile after signup, and enables Row Level Security. The second migration adds the War Council validation and atomic confirm/undo checks. Until it is applied, the app shows an upgrade notice and disables plan confirmation.

Before testing day-by-day planning, open Profile and set the signed-in user's planning time zone to match the device (for example, `Asia/Kuala_Lumpur` in Malaysia). New profiles currently default to `UTC`; a mismatch can make the app and database assign work near midnight to different days. The Profile page saves this setting to `profiles.time_zone`.

War Council labels plans as Feasible, Needs Review, Needs Agreement or No Feasible Plan. It compares its capacity calculation with the database before enabling confirmation; a mismatch is shown as Needs Review. Fixed and protected tasks and protected recovery are listed separately. Agreement-dependent suggestions are visible but cannot be confirmed until the task is updated after agreement.

To test War Council after upgrading, add three hours of availability on one future day and two hours on the following day. Create one flexible, unprotected task scheduled for the full three hours on the first day, with a deadline after the second day. Create another unscheduled two-hour task due on the first day. War Council should propose moving two hours of the scheduled task to the second day. Confirm it, check both days in Today, then undo it on the plan-updated screen. The first day's original overload should return after undo. Avoid changing the tasks or availability between confirm and undo, because the undo safety check may correctly reject restoration if a new conflict was introduced.

Without Supabase values, debug builds stay in local development mode so UI work and widget tests can continue; release builds stop at the setup notice.

User-facing failures are translated into concise English guidance for common authentication, connectivity, scheduling, permission and database cases. Unknown technical errors are not displayed verbatim; the app asks the user to retry instead.

## Verification

### Account recovery on mobile

In Supabase Authentication URL Configuration, add exactly
`com.balance.app://auth-callback/` to Redirect URLs. Keep the standard confirmation
and recovery email templates pointing to Supabase's generated confirmation link.
The Android/iOS handlers pass the callback to Supabase for verification; a route
name alone cannot authorize a password update. Install a freshly rebuilt app after
changing native link configuration; hot reload cannot add an Android intent filter.

From Sign in, choose **Forgot password or need verification?**. Enter the account
email, then choose a reset link or resend verification. Open the new email link on
the same device and installation that requested it (PKCE verification uses local
state). A verified recovery link opens Choose a new password. Set matching
passwords with at least 8 characters, or Cancel and sign out. Invalid/expired
links show safe guidance; request a fresh link. Rate limits and email delivery
remain governed by the project's Auth configuration. Messages intentionally do
not confirm whether an email belongs to an account.

Acceptance on a real device: test signup verification, verification resend,
password recovery with the app open and closed, expired/used links, cancellation,
then sign out and confirm the old password fails and the new password works.
These email delivery/native-link cases are not proven by widget tests. iOS link
configuration is prepared but requires verification on macOS and an iPhone.

After migration 002, run `supabase/manual/20260927_verified_progress_checks.sql` in the SQL Editor. Its read-only checks verify function availability, grants and RLS configuration. Then sign in through the app with two distinct accounts and confirm each account sees only its own tasks, recovery slots, snapshots and awards. The SQL Editor's privileged role cannot prove user isolation.

With one account, record a protected recovery slot in Sanctuary; check its achievement in Journey. Create a protected work shift task; check Protected Limit. Confirm a feasible Council plan and undo it; Safe Trade-off must stay unlocked. Save a Journey reflection; Reflection should unlock. Early Review requires an overloaded current day and a task whose local deadline is on a later day. Team Coordination remains locked until the V2 shared-task workflow supplies real evidence. Retry the same actions or use a second device: `user_achievements` must keep one award per key. Today and Profile must show the same five-dimension score after refresh. Journey shows only actually captured days; missing history says “No record”.

`capture_world_status` records today's server-derived snapshot when Today loads.
It does not backfill historic days. Open the app on multiple days to accumulate
a real trend. The configured profile time zone should match the device for day
boundaries. For the verified remote deployment state, see the 4 October record below.

```powershell
flutter analyze
flutter test
```

## 3 October fixes and database handoff

See [3 October handoff](docs/20261003_FIX_AND_DATABASE_HANDOFF.md) for migration
dependencies and retry limitations. Its deployment statements are historical;
the 4 October record below supersedes them. Flutter tests alone do not prove RLS
or remote function behavior.

## 4 October remote repair and acceptance

Project `zuilqjrwpyilsbaitmwo`: migrations `202610030001`, `202610030002`,
`202610040001` and additive repair `202610040002` were applied with Lim's approval.
The repair restores missing snapshot helpers, owner-bound achievement/review RPCs
and four award triggers without replacing existing snapshot formulas or guessing
historical scores. Private helpers remain unavailable to client roles.

Three transaction/rollback scripts passed against this project:

- `supabase/tests/verified_progress_runtime.sql`: today's snapshot, verified
  reflection evidence, repeat evaluation without duplicate awards, private helpers.
- `supabase/tests/active_planning_and_retry.sql`: stale/missing versions,
  Confirm/Undo, active occupancy and retry-safe social saves.
- `supabase/tests/world_status_achievements.sql`: its RLS, grants, trusted-write
  and cross-owner assertions using existing Auth identities as database claims.

Test fixture writes were rolled back. These tests do not prove two live app
sessions, simultaneous requests, mobile email callbacks or notification delivery.
See [acceptance checklist](docs/MVP1_ACCEPTANCE.md) and
[repair evidence](docs/20261004_AUDIT_FIXES.md). No whole-MVP completion is implied.

## Pending Chong database delivery (8 October)

See [WS11 and judge fixture handoff](docs/20261008_CHONG_WS11_AND_JUDGE.md).
Migration 202610080001 requires supported-client category rollout and disposable
database verification before deployment. The judge fixture defaults to rollback.
No deadline remains a design proposal, not a shipped feature.

## Architecture

Balance is one Flutter/Dart codebase (Android first) with Supabase for sign-in and storage.
Dependencies point one way:

```text
Flutter screens (lib/features/*)  ->  view-models (ChangeNotifier + Provider)
        ->  domain rules (lib/domain: models, enums, usecases; no Flutter, no I/O)
        ->  repository interfaces (lib/data/repositories)  ->  services/mappers  ->  Supabase
```

- `lib/domain/usecases` holds the pure rules: `DailyCapacity`, `generateTradeOffs`,
  `validatePlan`, the five-dimension `WorldStatusCalculator` (formula `world_status_v1`),
  `WorldTrendCalculator` (rolling 7-day load and moving average, Unknown ignored) and
  `AchievementEvaluator` (reference eligibility rules for the seven achievements).
- Unknown is never zero: missing data is `null` / `DataStatus.unknown`; only a recorded zero is `0`.
- Awards and World Status snapshots are written only by trusted database functions
  (`supabase/migrations`). `AchievementEvaluator` documents and tests the same rules in Dart
  but never grants anything; the client cannot send an "isEligible" flag.

## Testing and coverage

```powershell
flutter analyze
flutter test                                  # all Dart tests
flutter test test/domain                      # pure domain rules only
flutter test --plain-name WS05                # one acceptance case
flutter test --coverage                       # writes coverage/lcov.info
python tools/check_coverage.py --min 70       # critical code: lib/domain + *_view_model.dart
```

`tools/check_coverage.py` prints per-file line coverage for the critical code and exits 1 when
the combined figure is below `--min`. CI enforces the 70% minimum; the 9 October 2026 local
run measured 91.7% (2210/2410 lines) with 341 tests passing.
The WS01-WS14 and achievement test map is `docs/WS_AND_ACHIEVEMENT_TEST_MAP.md`.
`test/domain/full_scenario_test.dart` is the domain-level full-journey regression
(300 minutes proposed for a 180-minute evening). SQL scripts in `supabase/tests` need a
disposable Supabase database and are not run by `flutter test`.

## Judge guide

1. Install the APK built with `flutter build apk --release --dart-define-from-file=.env`.
2. Sign in with the dedicated judge account (alias only in Git; credentials are shared
   out of band, never committed). Seed its sample day with
   `supabase/manual/20261008_judge_demo.sql` after the rehearsal described in
   `docs/20261008_CHONG_WS11_AND_JUDGE.md`.
3. Today: 300 planned vs 180 available, a 120-minute overload, five World Status bars
   (missing data says Unknown).
4. Council: compare plans, Confirm a valid plan, then Undo.
5. Sanctuary: a protected recovery slot. Journey: weekly summary and seven achievements
   (Team Coordination stays Locked until verified shared tasks exist).

Demo account: none is created by the repository. Create a fresh account, then run the seed.
