# Building evidence pack (8–11 October 2026)

Owner of this file: Tan Yi Ming, covering Matthew Thien's test-lead part while he is
unavailable. It holds the step-by-step checklists and fill-in templates for every
manual item in Rev7 13.3–13.5. Tick a box only after the step really ran. Never
write passwords, tokens, keys or a tester's personal details in this file.

Before any device run, write down:

| Field | Value |
| --- | --- |
| Commit hash (`git rev-parse --short HEAD`) | |
| Build command | `flutter build apk --release --dart-define-from-file=.env` |
| APK size | |
| Supabase project | (project name only, never the key) |
| Test account alias | e.g. `judge-1`, `tester-2` (not the email) |
| Date and tester | |

---

## A. Release smoke test (Rev7 13.4) — about 15 minutes per device

Use a fresh install. Record Pass/Fail and a short note. Any Fail goes into the
defect list (section D) with the same step ID.

| ID | Step | Expected result | Result | Note |
| --- | --- | --- | --- | --- |
| S01 | Install the APK; open the app | Sign-in screen in English; no "Local preview" banner | | |
| S01b | Sign in the first time | Three-page introduction; **Skip** and **Get started** both close it; it does not return | | |
| S02 | Register a new account | Clear English message; verification email arrives (if enabled) | | |
| S03 | Sign in; open Profile | Shows the cloud account and time zone `Asia/Kuala_Lumpur` (set it if not) | | |
| S04 | Quests → + → create a task with a category | Task appears; category chip shown | | |
| S05 | Try to save a task without a category | Save blocked with an English message | | |
| S06 | Today → add availability 180 min; tasks total 300 min | Time Capacity shows planned 300 / available 180, gap 120 | | |
| S07 | Today → five bars | Mental, Time, Physical, Social, Errands in that order; missing ones say Unknown | | |
| S08 | Council → compare options | Each option shows what moves, what stays protected, and the cost | | |
| S09 | Confirm a plan | Plan updated screen; Today shows the moved task on its new day | | |
| S10 | Undo the plan | Original overload returns; plan history shows Undone | | |
| S11 | Sanctuary → add recovery time | Free-time suggestions shown and one pre-selected; **Save** works first time; slot shown as protected | | |
| S12 | Sanctuary → pick a time on a day with no availability | English guidance with **Go to Today** and **Choose another time** | | |
| S13 | Journey → weekly summary and achievements | Wall of seven badges; earned ones gold with date; Team Coordination Locked; tapping a badge shows how to unlock it | | |
| S13b | Earn a new achievement (e.g. confirm a plan), then open Journey | "Achievement unlocked" animation and chime once; not shown again on the next visit | | |
| S14 | Turn on airplane mode → pull to refresh on Today | Friendly "Could not connect" message and Try again; old data stays | | |
| S15 | Airplane mode off → Try again | Data reloads | | |
| S16 | Sign out → sign in with a second account | No data from the first account is visible | | |
| S17 | Today → empty day after a day with time → **Copy from …** | The previous day's blocks appear with the same times | | |
| S18 | Today → **Repeat for the next 6 days** → Repeat | Copies to days without time; days that already have time are unchanged | | |
| S19 | Quests → tap a task | Details sheet with **Edit task** | | |
| S20 | Profile → Reminders and alerts → Overload alerts on (allow permission) | "N overload alerts scheduled" when a coming day is over capacity | | |
| S21 | Profile → Sound effects on, background music on, then off | Chime on confirm and unlock; calm loop plays and stops; music pauses when the app is backgrounded | | |
| S22 | Next day after S06: Today → five bars | ▲/▼ change since yesterday next to bars with a score on both days | | |

## B. Full-journey regression (judge self-service flow, Rev7 13.6)

Run once per device on the prepared judge account. Time each step.

| Step | Action | Expected | Time (mm:ss) | Pass/Fail |
| --- | --- | --- | --- | --- |
| J1 | Open app / install APK | Sign-in in English | | |
| J2 | Sign in with judge account | Today opens | | |
| J3 | Review the sample day (300 planned, 180 available) | Overload of 120 minutes is visible and explained | | |
| J4 | Open Council and compare options | At least one feasible option, or a clear No Feasible Plan reason | | |
| J5 | Confirm a valid plan | Task placement and recovery time change together | | |
| J6 | Undo | Both changes restored | | |
| J7 | Open Sanctuary | Protected recovery slot shown | | |
| J8 | Open Journey | Weekly summary shown; no invented past scores | | |

## C. Device matrix (need at least two Android devices)

| Device | Android version | Screen size / density | Font size setting | Install OK | Smoke A | Journey B | Defects |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Emulator Pixel 8 API 35 (`-gpu swiftshader_indirect`) | 15 | 1080×2400 | Default | | | | |
| Physical phone 1: | | | | | | | |
| Physical phone 2: | | | | | | | |

How to install the APK on a phone from Windows PowerShell:

```powershell
flutter build apk --release --dart-define-from-file=.env
adb devices
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

If `adb devices` shows nothing: enable Developer options → USB debugging on the phone,
plug in the cable and accept the prompt on the phone.

## D. Defect list

Severity: **Critical** = judge journey cannot finish or data is wrong/lost;
**Major** = a step works only with a workaround; **Minor** = cosmetic or copy.
Critical and Major must be fixed or disclosed before 11 October.

| ID | Date | Device | Step (A/B ID) | What happened | Expected | Severity | Owner | Fix commit | Retest result |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| D01 | | | | | | | | | |

## E. Unedited core-flow recording

1. Sign in on the judge account before you start recording (so no password is filmed).
2. Start recording, either:
   - on the phone: swipe down twice → **Screen record** → no audio; or
   - from the PC: `adb shell screenrecord /sdcard/balance_core.mp4` (stops after 3 minutes;
     press Ctrl+C to stop), then `adb pull /sdcard/balance_core.mp4`.
3. Do J3 → J8 in one take. Do not cut, speed up or edit the file.
4. Save as `balance_core_flow_YYYYMMDD_<device>.mp4` and record the commit hash next to it.
5. The **backup demo video** for the presentation is a separate, edited file.

## F. Unaided user test (Rev7 13.4: "without help")

Aim for 3–5 students who have not seen the app. Use a prepared tester account, not
their own data. Read only this script aloud, then stay silent:

> "This app helps you plan a busy day. Please do these tasks. Think aloud if you like.
> I can't help you during the test. You can stop at any time."

Tasks to hand them on paper:

1. Find out how many minutes you are over today.
2. Ask the app for a plan that fits, and accept one.
3. Change your mind and undo it.
4. Protect 30 minutes of rest.
5. Find this week's summary.

Record per tester (use an alias such as T1, no names):

| Tester | Task | Completed without help? (Y/N) | Time (mm:ss) | Where they hesitated or failed | Quote (optional) |
| --- | --- | --- | --- | --- | --- |
| T1 | 1 | | | | |
| T1 | 2 | | | | |

After the test ask two questions and write the answers:

- "What was most confusing?"
- "Would this help you during exam weeks? Why?"

Summary line for the judges: *N of M testers completed the journey unaided; median
time mm:ss; top 3 problems and what we changed.*

## G. Accessibility checklist (Rev7 13.4)

Do this on one physical phone. Note the screen and the exact element for each Fail.

| Check | How | Screens | Result |
| --- | --- | --- | --- |
| Labels | Turn on TalkBack (Settings → Accessibility). Swipe through every control. Every button reads a meaningful English name (no "button" alone, no icon names). | Today, Quests, Council, Sanctuary, Journey, task form | |
| Focus order | With TalkBack, swipe right through each screen. Order follows the visual top-to-bottom order; dialogs trap focus until closed. | All | |
| Text scaling | Settings → Display → Font size largest, Display size largest. Nothing is cut off; no text overlaps; every screen still scrolls. | All | |
| Contrast | Muted text and chips are readable in daylight; check the faint footer text on Sanctuary. | All | |
| Touch targets | Every tappable item is at least about 48×48 dp (a fingertip). Check chips, the ⋮ menu, day arrows. | All | |
| Colour alone | Status (Fits/Over, Locked/Unlocked) is also written as text, not colour only. | Today, Journey | |

The automated part (`meetsGuideline` widget tests) is added separately; this manual
check is still required.

## H. English screenshots for the judges

Capture on a phone at default font size and **Malaysia time**, using the test account
with the same sample data (keep the judge account untouched): introduction, Today (top
and five bars), Quest Board with filters, task details, task form, Council comparison,
Plan updated, Sanctuary with free-time suggestions, Journey summary, achievement wall,
an error state with Try again, Profile with sound and alerts. Name files
`00_intro.png`, `01_today.png`, `02_today_bars.png`, …

## I. Problem-statement mapping (Effectiveness)

Paste the organiser's exact Lifestyle Track problem statement at the top, then map
each part to a feature and its proof.

| Problem statement part | Balance feature | Proof (test ID, screenshot, user quote) |
| --- | --- | --- |
| (paste) | Overload detection on Today (300 vs 180) | WS03, J3, screenshot 01 |
| (paste) | Council trade-offs with protected commitments | S08–S10, `war_council_view_model_test.dart` |
| (paste) | Recovery that is protected, optional and not scored | WS07, S11, A09 |
| (paste) | Private weekly patterns, no ranking or streaks | J8, `journey_achievements_test.dart`, AC-DUP |
| (paste) | Not a medical tool; Unknown instead of guessing | WS02, WS04, Sanctuary footer |

## J. Test log (one line per run)

| Date | Commit | Command / activity | Result | Notes |
| --- | --- | --- | --- | --- |
| | | `flutter analyze` | | |
| | | `flutter test` | | |
| | | `flutter test --coverage` + report | | |
| | | Smoke test A on device 1 | | |
| | | Smoke test A on device 2 | | |
