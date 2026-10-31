# WS01–WS14 and achievement test map

Owner: Matthew Thien (test lead). Prepared by Tan Yi Ming on 8 October 2026 while
covering Matthew's part. Source of truth: Rev7 guide 14.4.7 (WS cases), 14.4.8
(worked fixture) and 14.7.1 (achievements). A row is **Pass** only when the named
test ran and passed on the recorded date. "Manual" rows need a person and a device.

Run one case: `flutter test --plain-name WS05`. Run all calculator cases:
`flutter test test/world_status_calculator_test.dart`.

## Stress Meter cases

| ID | Case | Automated evidence | Remaining manual evidence |
| --- | --- | --- | --- |
| WS01 | All five known | `world_status_calculator_test.dart`: *WS01 worked example … 53 High*, *WS01 weights total 100% …*, *WS01 labels …*, *WS01 invalid ranges …*, *WS01 every dimension … 0-100* | Screenshot of Today with five bars |
| WS02 | Missing Daily Review | *WS02 missing energy is partial …*, *WS02 skipped energy is excluded …*, *WS02 Mental is Unknown …*; `daily_review_card_test.dart` (Skip writes nothing) | — |
| WS03 | Capacity overload | *WS03 planned 300 vs available 180 …*, *WS03 missing availability …*, *WS03 explicit zero availability …*; `today_view_model_test.dart` (300/180/120) | Judge sample day shows 300 / 180 |
| WS04 | Exercise gap | *WS04 exercise history and opt in …*, *WS04 gap counts local days …*; `movement_view_model_test.dart` | — |
| WS05 | Social pressure | *WS05 neutral event …*, *WS05 a High event and a sleep overlap …*; `social_conflicts_test.dart` | — |
| WS06 | Errands classification | *WS06 unclassified …*, *WS06 fully classified …*, *WS06 only the chosen category …* | — |
| WS07 | Recovery | *WS07 protecting recovery lowers …*, *WS07 marking a recovery activity done …*; `sanctuary_view_model_test.dart` (done only sets completedAt) | — |
| WS08 | Trend, boundaries, invalid input | *WS08 trend requires three …*, *WS08 missing days are not zeros …*, *WS08 the calculator reports the trend …*, *WS08 trend input must be exactly seven …*, *WS08 exercise gap uses calendar dates …*, *WS08 the 48-hour due window …*; `calendar_week_test.dart`, `world_history_service_test.dart` (year boundary) | Multi-day trend screenshot (needs 3+ captured days) |
| WS09 | Failure and retry | `world_status_ws_view_model_test.dart`; `today_view_model_test.dart`; `today_refresh_error_test.dart`; `quest_board_test.dart`; `journey_achievements_test.dart` | Airplane-mode test on device; widget tests verify stale data plus inline retry on Today, Quest Board and Journey |
| WS10 | RLS | `supabase/tests/world_status_achievements.sql`; `supabase/tests/achievement_eligibility.sql` (AC-ISO) | Two real signed-in accounts on two devices (Lim/Chong) |
| WS11 | Required category | `task_category_form_test.dart`; `supabase/tests/task_category_required.sql` covers omitted/NULL rejection, all categories and legacy rows | Migration `202610080001_require_task_category.sql` exists and SQL syntax passes. Runtime test on a disposable Supabase database and coordinated rollout to all supported clients remain pending. |
| WS12 | Exercise confirmation | *WS12 completing an Exercise task alone …*; `world_status_achievements.sql` (duplicate request rejected) | Device: complete an Exercise task, cancel the prompt, Physical unchanged |
| WS13 | Social linkage | *WS13 an unlinked Social task …*; `social_conflicts_test.dart` (*does not count an event against its own linked task*); `active_planning_and_retry.sql` (social retry) | — |
| WS14 | Reclassification / legacy | *WS14 changing Study to Errand …*, *WS14 coverage under 60% …*, *WS06 unclassified …* | Device: reclassify a task, refresh, snapshot changes |

## Achievement eligibility (server-side; no client award logic)

File: `supabase/tests/achievement_eligibility.sql`. It runs against a disposable
database with two fresh Auth users and rolls back every write. Case IDs:

| Key | Positive | Negative |
| --- | --- | --- |
| protected_rest | AC-PR+ protected recovery slot; protected sleep minimum | AC-PR- unprotected slot, chosen/completed activity, protected work shift alone |
| safe_trade_off | AC-ST+ confirmed feasible plan | AC-ST- stale/failed confirmation |
| deadline_safety | AC-DS+ persisted flexible move before deadline, evidence = plan id | AC-DS- failed confirmation; detecting overload only |
| early_review | AC-ER+ review on an earlier **local** date (00:30 tomorrow in Kuala Lumpur) | AC-ER- task due later the same local day; account with no overload |
| protected_limit | AC-PL+ protected work shift; sleep minimum | AC-PL- protected task with no commitment type; title "Work shift" only |
| reflection | AC-RF+ non-empty reflection | AC-RF- blank reflection rejected |
| team_coordination | (V2 only) | AC-TC- needs-agreement personal task; forged event; direct client award insert |

Anti-farming (AC-DUP): Undo keeps the award; a second confirmation, repeated
*Mark as reviewed*, a second reflection and two re-evaluations add nothing.
Isolation (AC-ISO): account B cannot read A's awards or events and gets no award
from A's actions.

How to run (Chong, disposable Supabase project only):

```powershell
psql "$env:TEST_DATABASE_URL" -v ON_ERROR_STOP=1 -v user_a=UUID_A -v user_b=UUID_B -f supabase/tests/achievement_eligibility.sql
```

Expected last line: `Achievement eligibility assertions passed; fixture writes rolled back.`
The user accounts must be new (the script refuses accounts that already hold awards).

## Recorded runs

| Date | Where | Result |
| --- | --- | --- |
| 8 Oct 2026 | Local PostgreSQL 16 with a minimal Supabase auth stub; all 12 migrations applied to an empty database | All 4 SQL scripts passed (`achievement_eligibility`, `active_planning_and_retry`, `verified_progress_runtime`, `world_status_achievements`). Two deliberately broken copies failed as expected. This is **not** a Supabase run and does not prove real Auth sessions. |
| 8 Oct 2026 | Merged `origin/master` `e89f55a`; local SQL parser | Syntax passed for all 13 migrations and 5 Supabase test scripts. Syntax is not runtime/database acceptance. |
| 8 Oct 2026 | Tan's Windows PC: `flutter analyze --no-pub` / `flutter test --no-pub` | Analysis clean; 225 tests passed after master merge. Later inline-retry changes have focused widget-test evidence; full-suite result is recorded in the current delivery note. |
| 10 Oct 2026 | Lim's Windows PC on `7fdca8c` (master after PR #22): `flutter analyze` / `flutter test --coverage` / `tools/check_coverage.py --min 70` | Analysis clean; 376 tests passed; critical code 92.4% (2360/2554 lines). GitHub CI passed the same checks plus web compilation and SQL syntax. |
| 10 Oct 2026 | Judge account on an Android 15 emulator set to Asia/Kuala_Lumpur (read-only check) | 1 Nov sample day: 300 planned / 180 available / 120 over; availability 9:00 AM – 12:00 PM; deadlines 5:00 PM. |
| 12 Oct 2026 | Lim's Windows PC on `LZH` after the Sanctuary rest camp (`2e2c734`): `flutter analyze` / `flutter test --coverage` / `tools/check_coverage.py --min 70` | Analysis clean; 422 tests passed; critical code 92.5% (2438/2635 lines). |
| 12 Oct 2026 | Judge account on the Android 15 emulator (read-only, run R1 in the evidence pack) | 1 Nov still shows 2H OVER and a FEASIBLE move to 2 Nov 9:00–11:00 AM; 0 of 7 achievements and 0 confirmed plans, so the account is untouched. |
| 13 Oct 2026 | Lim's Windows PC on `fa867de` (tag `v1.0.4`): `flutter analyze` / `flutter test --coverage` / `tools/check_coverage.py --min 70` | Analysis clean; 445 tests passed; critical code 93.1% (2586/2777 lines). |
| 13 Oct 2026 | v1.0.3 and v1.0.4 release APKs on the Android 15 emulator, test account (evidence pack R8, R9) | D01 D02 D04 D05 D07 D10 D12 D13 D14 retested: all pass. Council moved unscheduled work to an earlier day after the suggested free time was added; the server accepted the confirm and the undo. Test data removed afterwards. |
| 20 Oct 2026 | Matthew's PC: `flutter analyze` / `flutter test --coverage` / `python tools/check_coverage.py --min 70` | Analysis clean (no issues found); 450 tests passed; critical-code line coverage 93.4% (2607/2792 lines, required 70%); World Status calculator 99.6%, trend calculator 100%, achievement evaluator 100% |
| 28 Oct 2026 | Full-app test of the v1.0.8 build on the Android 15 emulator, test account | Free time on two days, unscheduled task due tomorrow, Council moved 60 min to today, confirm, both days checked, Sanctuary slot, undo from Plan history, slot removed, theme and music toggles, Profile, Reminders, beginner guide, Back navigation, offline refresh and Try again: all pass after fixing D21 and D22 (first recorded as D18/D19). Test data removed (task marked done). |
| 28 Oct 2026 | Lim's Windows PC on `LZH`: `flutter analyze` / `flutter test --coverage` / `tools/check_coverage.py --min 70` | Analysis clean; 467 tests passed (including 8 device sizes); critical code 93.4% (2617/2802 lines). |
| 29 Oct 2026 | Full-app test of the published v1.0.9 APK on the Android 15 emulator, test account | Free time added and copied to the next day, task form validation (category required), two 300 min tasks, Council no-plan explanation and free-time suggestion, suggestion button opens the right day, Council moved 300 min to 30 Oct after 2h was added, confirm, Sanctuary suggestion skips plan time (D21 retest pass), undo from Plan history, Profile, Back key, offline and reconnect, no errors in the log: all pass except D23 and D24 (fixed on `LZH`). |
| 29 Oct 2026 | Lim's Windows PC on `LZH`: `flutter analyze` / `flutter test --coverage` / `tools/check_coverage.py --min 70` | Analysis clean; 468 tests passed; critical code 93.4% (2623/2808 lines). |
| 30 Oct 2026 | Full-app test of the published v1.0.10 APK (SHA-256 matches R16) on the Android 15 emulator, test account | Available and Blocked time, Repeat for the next 6 days, fixed task with planned time, task form checks, Council with fixed work (What stays protected, free-time hint 3h 30m for a 199 min gap), Sanctuary slot with activity and Remove, reflection saved (achievement unlocked), light and dark theme, music, Profile, 1280×800 dp tablet with font scale 1.3: all pass except D25, D26, D27 (fixed on `LZH`). No errors in the log. The reflection stays (reflections cannot be deleted). |
| 30 Oct 2026 | Lim's Windows PC on `LZH`: `flutter analyze` / `flutter test --coverage` / `tools/check_coverage.py --min 70` | Analysis clean; 470 tests passed; critical code 93.5% (2633/2816 lines). |
| 31 Oct 2026 | Team changes from master (Today Rest time, per-account beginner guide) on the Android 15 emulator, test account, then the v1.0.12 release APK (R18) | Rest time on Today: empty state, Sanctuary button, a slot added in Sanctuary shown with its time and counted in Capacity, not shown on the next day, gone after removal; recovery time outside free time refused with *Go to Today*; beginner guide not shown again to an existing account. All passed; test data removed.
| 31 Oct 2026 | Lim's Windows PC on `LZH`: `flutter analyze` / `flutter test --coverage` / `tools/check_coverage.py --min 70` | Analysis clean; 476 tests passed; critical code 93.5% (2644/2828 lines).
| | Disposable Supabase (Chong) | _fill in_ |

## Domain contract and regression files (added 9 October)

| File | Purpose | Status                                                                     |
| --- | --- |----------------------------------------------------------------------------|
| `lib/domain/usecases/achievement_evaluator.dart` + `test/domain/achievement_evaluator_test.dart` | Dart reference for the seven eligibility rules (positive and negative cases, once-per-type, retries). Never grants awards; the SQL stays the source of truth. | **Pass** (`flutter test`, Matthew's PC, 9 Oct 2026)                        |
| `lib/domain/usecases/world_trend_calculator.dart`, `lib/domain/models/world_trend_models.dart` + `test/domain/world_trend_calculator_test.dart` | Rolling 7-day cumulative load, moving average and direction per dimension; Unknown days skipped and kept out of the denominator. | **Pass** (`flutter test`, Matthew's PC, 9 Oct 2026)                        |
| `test/domain/full_scenario_test.dart` | Domain-level full journey for the 300/180 scenario: overload, compare plans, Confirm arithmetic (150 work + 30 free), recovery, achievements, Undo. | **Pass** (`flutter test`, Matthew's PC, 9 Oct 2026)                        |
| `test/domain/validate_plan_test.dart` | The four plan statuses and their priority; overload formula. | **Pass** (`flutter test`, Matthew's PC, 9 Oct 2026)                        |
| `test/features/today/world_status_card_test.dart` (3 new cases) | No time added shows a neutral tag, never green Fits. | **Pass** (`flutter test`, Matthew's PC, 9 Oct 2026)                        |
| `tools/check_coverage.py` | Line coverage of critical code (`lib/domain` + `*_view_model.dart`). | **Pass**: 2087/2285 lines = 91.3% (required 70%), Matthew's PC, 9 Oct 2026 |

## Multi-day trend UI and formula sheet (added 9 October)

| File | Covers | Status                                              |
| --- | --- |-----------------------------------------------------|
| `docs/WORLD_STATUS_FORMULA_SHEET.md` | WL02 formula sheet for the five dimensions and the trend | Written; team confirmation pending                  |
| `lib/features/today/world_trend_panel.dart` | WL05 period, unit, cumulative load, data gaps on Today | **Pass** (`flutter test`, Matthew's PC, 9 Oct 2026) |
| `test/features/today/world_trend_panel_test.dart` | 8 widget tests: no data, gaps, recorded zero, singular wording, card wiring | **Pass** (`flutter test`, Matthew's PC, 9 Oct 2026) |

Still manual (not covered by the rows above): English mobile screenshots of Today
(five dimensions and the 7-day trend panel), two-device checks, and the disposable
Supabase run.
