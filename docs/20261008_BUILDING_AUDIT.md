# 8 October Building audit (Tan Yi Ming, covering Matthew Thien)

> Point-in-time audit of PR #10 before the later master integration. WS11's
> category migration, the judge fixture, Council multi-task alternatives, and
> inline refresh/retry UX have since been implemented. See `MVP1_ACCEPTANCE.md`,
> `LZH_MVP2_4_DELIVERY.md`, and `20261008_CHONG_WS11_AND_JUDGE.md` for current code
> status. Historical manual/device/database gaps remain open until newer evidence
> records actual acceptance.

Audited the `yiming/quest-sanctuary` source (PR #10 state) against the Rev7 guide
(4 Oct) and the Building plan PDF. Rev7 wins where they differ. "Done" means code
**and** test evidence exist; a file existing is not enough.

Verification available on 8 Oct: all 12 migrations applied to an empty local
PostgreSQL 16 with a minimal Supabase auth stub, and all SQL test scripts passed
there. `flutter analyze` / `flutter test` must be re-run on a team PC (not possible
in the audit environment). Neither is a Supabase or device run.

## Matthew's part

| Item | Status | Evidence / gap |
| --- | --- | --- |
| WS01–WS14 mapped to tests | **Partly → mostly done (8 Oct)** | `test/world_status_calculator_test.dart` now has WS-labelled cases incl. trend, missing days, invalid range, midnight/48 h boundaries; `test/features/today/world_status_ws_view_model_test.dart` (WS09, WS12). Map: `docs/WS_AND_ACHIEVEMENT_TEST_MAP.md`. Still open: WS09 Today UI shows no error+Retry when data exists; WS10 two real sessions; WS11 server enforcement. |
| 53 High worked fixture | Done | *WS01 worked example …* reproduces 63/63/59/18/49 → 53 High |
| Seven achievement positive/negative fixtures | **Missing → done locally (8 Oct)** | `supabase/tests/achievement_eligibility.sql` (AC-* cases). Award logic stays in SQL. Needs one run on a disposable Supabase project (Chong). |
| Council recommendation contract | Missing (stretch) | Generator still proposes single-task moves (`generate_trade_offs.dart`, MVP3 doc). |
| Release smoke test | Missing | Checklist ready: `docs/BUILDING_EVIDENCE_PACK.md` A. |
| Full-journey regression | Partly | `test/quest_journey_regression_test.dart` (widget level). No device run recorded. |
| Two Android devices, matrix, defects | Missing | Templates: evidence pack C, D. |
| 70% line coverage on critical code | Missing | No coverage command, report or CI step. Old 21.8% figure must not be reused. |
| README: architecture, test, build, demo account, judge guide | Partly | README has setup, Council fixture, verification, remote record. No architecture, demo account or judge section. |
| Execution evidence | Missing | Test log, device matrix, defect list, unedited recording: templates only. |
| Effectiveness evidence | Missing | Mapping template: evidence pack I. No user feedback yet. |
| MVP1_ACCEPTANCE unchecked items (Matthew/Tan) | Missing | "Profile time zone matches device; Today and Profile show matching scores" and "Real device full journey passes; English labels, text size and keyboard". The other 8 belong to Lim/Chong. |

## Tan's part

| Item | Status | Evidence / gap |
| --- | --- | --- |
| Quest Board, required category, Needs Review, search/filter | Done | `quest_board_test.dart`, `task_category_form_test.dart`, `task_card.dart` "Uncategorized · Needs Review" |
| Sanctuary | Done | `sanctuary_view_model_test.dart`, `sanctuary_screen.dart` |
| Exercise/social confirmation, linking, cancellation | Partly | Exercise prompt after completing an Exercise task (`quest_board_screen.dart` `_offerExerciseLog`) has **no test**; social linking tested (`social_conflicts_test.dart`, `social_card_test.dart`). |
| "No deadline" option | Missing — blocked | `tasks.due_at` is NOT NULL and `scheduled_end <= due_at`; Council RPCs and the calculator assume a deadline. Needs Chong's migration first. |
| Clear Sanctuary error ("Add availability on Today first") | Partly | Server raises `Recovery slot must fit inside available time`; app shows "Choose a time inside one of your available blocks." or the generic fallback. |
| Loading/empty/error/retry/offline on judged journey | Partly | Quest, Council, Profile, Sanctuary have Try again. **Today** swaps the whole page for a spinner on every refresh and hides a refresh error when data exists; **Journey** error has no Try again; Quest refresh error hidden when tasks exist. Network errors map to "Could not connect"; no offline banner. |
| Accessibility (labels, contrast, scaling, focus, targets) | Partly | Some `semanticsLabel`/`Semantics`; no guideline widget tests; no manual check recorded. |
| Practical names beside RPG names (14.13) | Partly | Council "Compare plans", Sanctuary "Recovery time", Journey "Weekly reflection" OK. Today lacks "Workload Overview" (Rev7 14.4.5 requires it); Quest Board lacks a practical "Tasks" name; bottom bar shows "Quests"/"Council" only. |
| English screenshots, unaided user test | Missing | Protocol and template: evidence pack F, H. |
| Pitch deck, timed script, backup video, judge guide | Missing | Rev7 13.2 also records none in the repo. |
| V2 shared-task UX / V3 opt-in UX (stretch) | Missing | No shared-task schema or recommendation feature to attach UX to. |

## Other findings

- Today shows a green **Fits** tag when no time has been added (0 min available) —
  misleading; should be neutral until availability exists.
- An overdue planned task (e.g. due 3 Oct) has no "Overdue" cue on its Quest card.
- No deterministic **judge account / sample day** (300 planned, 180 available) exists;
  `supabase/manual/20260927_sim_activity_seed.sql` is for Lim's account and does not
  create the overload day. Judge flow step 3 depends on it.
- WS11 server half: no migration rejects NULL `load_category` on new inserts.

## Plan 8–11 October (judge-critical first)

| When | Item | Owner | Blocks |
| --- | --- | --- | --- |
| 8 Oct | WS01–WS14 tests, achievement SQL fixtures, test map, evidence templates | Tan for Matthew | — |
| 8 Oct | Message Chong and Lim (see below) | Tan | judge seed, No deadline, release |
| 8 Oct | Sanctuary "Add availability on Today first" | Tan | S12 |
| 8–9 Oct | Judged-journey states: Today keeps data while refreshing, inline error + Try again; Journey Try again; Quest refresh error; neutral tag with no time | Tan (Today on Matthew's behalf) | WS09, S14 |
| 9 Oct | Practical names + accessibility fixes + guideline/text-scale widget tests | Tan | 14.13, a11y |
| 9 Oct | Coverage command, report script, CI step; tests for weakest critical files | Tan for Matthew | 70% gate |
| 9 Oct | README: architecture, testing, build, demo account, judge guide | Tan for Matthew | 13.3 |
| 9–10 Oct | Smoke test A + journey B on emulator + 2 phones; defects; fixes | Tan (+ any teammate with a phone) | Execution |
| 10 Oct | Unaided users (3–5), screenshots, unedited recording, accessibility manual | Tan | UI/UX, Execution |
| 10 Oct | Pitch deck, timed script, backup demo video, judge guide | Tan | Presentation |
| 11 Oct | Final `flutter analyze`/`flutter test`/coverage on the tagged commit; update MVP1_ACCEPTANCE with evidence; disclose limitations | Tan + Lim | Submission |
| Stretch | No deadline UI (only after Chong's migration is reviewed by 9 Oct night); Council multi-task contract; exercise-prompt widget test | Tan / Lim | — |
| Out of judged build | V2 shared tasks, V3 recommendations, V4 platform | — | Rev7 gate rule: failing gates stay out |

## Needs Chong (database)

1. Run `supabase/tests/achievement_eligibility.sql` on a disposable project with two new Auth users.
2. Judge account + deterministic sample day (300 planned / 180 available, two-day
   Council fixture) as a reviewed seed script, applied only to the judge account.
3. "No deadline": decide `due_at` nullable vs an explicit `has_deadline` flag, and the
   effect on `scheduled_end <= due_at`, `confirm_plan_change`, capacity and the
   48-hour rule. Reply by 9 Oct evening or we defer and disclose it.
4. WS11 enforcement migration: reject NULL `load_category` on new inserts, keep legacy rows.

## Needs Lim (master and release)

1. Review/merge PR #10, then the PR for this audit's test work.
2. Permanent application ID and private release signing before the judge APK.
3. Release-candidate tag on the submitted commit; confirm CI is green on that commit.
4. Two-account and two-device concurrency runs (MVP1_ACCEPTANCE) — Tan can help with a second phone.
