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
| WS09 | Failure and retry | `world_status_ws_view_model_test.dart`: *WS09 a failed refresh …*; `today_view_model_test.dart` (capture failure is not save failure); `journey_achievements_test.dart` (failed refresh keeps awards) | Airplane-mode test on device; Today must show an error **with Retry** while keeping data (UI gap, see audit) |
| WS10 | RLS | `supabase/tests/world_status_achievements.sql`; `supabase/tests/achievement_eligibility.sql` (AC-ISO) | Two real signed-in accounts on two devices (Lim/Chong) |
| WS11 | Required category | `task_category_form_test.dart` (*new task requires an explicit category*) | **Server half missing**: no migration rejects NULL category on new inserts (Chong) |
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
| 8 Oct 2026 | Local PostgreSQL 16 with a minimal Supabase auth stub; all 12 migrations applied to an empty database | All 4 SQL scripts passed (`achievement_eligibility`, `active_planning_and_retry`, `verified_progress_runtime`, `world_status_achievements`). Two deliberately broken copies (wrong expected count; server early-review rule changed to allow same-day) both failed as expected. This is **not** a Supabase run and does not prove real Auth sessions. |
| | Tan's Windows PC: `flutter test` | _fill in: total passed / failed_ |
| | Disposable Supabase (Chong) | _fill in_ |
