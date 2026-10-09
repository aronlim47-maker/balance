# Matthew's part: what is done in code and what still needs a person (9 October 2026)

Code and documents below were written without a Flutter/Dart SDK, so **none of the new
tests have been run yet**. Run them first; fix anything that fails before ticking a box.

## Run first (5 minutes, team PC)

```powershell
flutter pub get
flutter analyze
flutter test --coverage
python tools/check_coverage.py --min 70
```

Record the commit hash, the number of tests passed and the coverage figure in
`docs/WS_AND_ACHIEVEMENT_TEST_MAP.md` (Recorded runs) and `docs/BUILDING_EVIDENCE_PACK.md`.
If coverage is below 70%, the script lists the weakest files first: add tests there.
Then delete `continue-on-error: true` from the coverage step in `.github/workflows/check.yml`.

## Done in code (needs the run above to count)

- Today capacity tag: "No time added" instead of a green "Fits" when no availability exists.
- `AchievementEvaluator`: Dart reference for the seven eligibility rules with positive and
  negative cases (`test/domain/achievement_evaluator_test.dart`).
- `WorldTrendCalculator`: rolling 7-day load, moving average and direction per dimension.
- `test/domain/full_scenario_test.dart`: domain full-journey regression (300/180).
- `test/domain/validate_plan_test.dart`: the four plan statuses.
- Coverage script, CI step, README architecture/testing/judge sections.

## Needs a person or a real environment (cannot be done from code)

| Item | Who | How |
| --- | --- | --- |
| Run `supabase/tests/achievement_eligibility.sql` and the other 4 scripts | Chong | Disposable Supabase project, two new Auth users; commands in the test map |
| Apply `202610080001_require_task_category.sql` after clients send a category | Chong + Lim | Only after the disposable-database run |
| Release smoke test S01-S16, journey J1-J8 | Anyone with a phone | `docs/BUILDING_EVIDENCE_PACK.md` A and B |
| Two Android devices, device matrix, defect list | Anyone with a phone | Evidence pack C and D |
| 3-5 unaided users, screenshots, unedited recording | Team | Evidence pack F and H |
| MVP1_ACCEPTANCE: time-zone/score match, real-device journey | Matthew/Tan | Tick only after doing it |
| Team Coordination on genuine shared tasks (V2) | Not built | No shared-task schema exists; stays Locked and out of the judged build |
| Calamity / recommendation rules (V3), institutional cases (V4) | Not built | Out of the judged build by the gate rule; disclose in the final report |
| Final sign-off of the test log and limitations | Matthew | After everything above |


## Added later
- `docs/WORLD_STATUS_FORMULA_SHEET.md` (WL02) — needs team confirmation.
- `WorldTrendPanel` on the Today card + `world_trend_panel_test.dart` — not yet run; run `flutter analyze` and `flutter test --coverage`.
