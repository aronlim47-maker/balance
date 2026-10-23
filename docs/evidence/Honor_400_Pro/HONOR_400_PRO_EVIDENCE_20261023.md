# HONOR 400 Pro evidence — text size and keyboard (23 October 2026)

| Field | Value |
| --- | --- |
| Tester | Tan Yi Ming |
| Date | 23 October 2026 |
| Device | HONOR 400 Pro, MagicOS 10, Android 16 |
| App version | Balance v1.0.6 (commit hash: fill in from `git rev-parse --short HEAD`) |
| Mode | Supabase cloud account (test account; no email or password recorded) |
| Display settings | Text size **Huge** (maximum), Display size **Large** (maximum), text boldness Fine |
| Scope | Rev7 13.4 text scaling and keyboard check; MVP1 acceptance "text size and keyboard" |

The Samsung Galaxy A55 evidence (Matthew, v1.0.3, 13 Oct) is a separate run and is
recorded elsewhere. Results here apply to v1.0.6 on this device only.

## Result

**Pass, with one Minor cosmetic defect (D16).** Every screen below scrolls, is readable,
has no overlapping text, and the bottom navigation labels fit. With the keyboard open the
fields stay visible and **Create task** stays reachable above the keyboard.

## Screens checked

| Screen | What it shows | File |
| --- | --- | --- |
| Settings | Text size Huge | `A11Y_font_setting.jpg` |
| Settings | Display size Large | `A11Y_display_setting.jpg` |
| Today | Top of screen; "AVAILABIL-ITY" breaks mid-word (D16) | `A11Y_today.jpg` |
| Today | Scrolled; Availability and Planned tasks | `A11Y_today_scrolled.jpg` |
| Today (Sat 24 Oct) | 3h available, 5h planned, 2h over, Capacity gap card | `A11Y_today_overload.jpg` |
| Quests | Add task, search, filters, first quest | `A11Y_quests.jpg` |
| New task | Title field focused, keyboard open | `A11Y_keyboard_title.jpg` |
| New task | Estimated minutes, number keyboard open | `A11Y_keyboard_minutes.jpg` |
| New task | Create task visible above the keyboard | `A11Y_keyboard_create.jpg` |
| Edit task | Flexibility, Status, toggles, Planned start, Save changes | `A11Y_edit_form.jpg` |
| Council | Empty day ("No time added"); "WAR COUNCI-L" breaks mid-word (D16) | `A11Y_council.jpg` |
| Council | "No free time was found" message and Add free time button | `A11Y_council_nosafe.jpg` |
| Council | Plan card "Move 120 minutes to Sun 25 Oct" and Confirm selected plan | `A11Y_council_plan.jpg` |
| Plan confirmed | "Plan confirmed", what moved, change reference | `A11Y_council_confirmed.png` |
| Sanctuary | Empty state; Add recovery button partly behind nav while scrolling | `A11Y_sanctuary.jpg` |
| Sanctuary | Add recovery time button fully visible | `A11Y_sanctuary_button.jpg` |
| Journey | Achievements; "Coordinatio-n" breaks mid-word (D16) | `A11Y_journey.jpg` |
| Journey | Weekly pattern, "–" means no record | `A11Y_journey_week.jpg` |
| Profile | Time zone Asia/Kuala_Lumpur; email hidden with solid blocks | `A11Y_profile.jpg` |

## Paste into `docs/BUILDING_EVIDENCE_PACK.md`

Section G, Text scaling row:

```
Result: Pass (Minor cosmetic defect D16)
Note: Tan Yi Ming, 23 Oct 2026, Balance v1.0.6, HONOR 400 Pro, MagicOS 10, Android 16.
Text size Huge (maximum), Display size Large (maximum). Today, Quests, New task and
Edit task forms, Council (empty state, "no free time" message and a real plan card with
Confirm), Sanctuary, Journey and Profile all scroll, nothing is cut off or overlapping,
nav labels fit. Keyboard: Title and Estimated minutes visible with keyboard open; Create
task reachable above the keyboard. Minor: long words break mid-word (D16).
Files: docs/evidence/Honor_400_Pro/A11Y_*.
```

Section D, defect row:

```
| D16 | 23 Oct | HONOR 400 Pro (v1.0.6) | G Text scaling | At Huge text size, headings and labels break mid-word: "AVAILABIL-ITY" (Today), "WAR COUNCI-L" (Council), "JOURN-EY" (Journey header), "Coordinatio-n" (achievement card) | Words wrap whole or the layout shrinks the text | Minor | Ze Heng / TBD | | Open |
```

Section C, device matrix row:

```
| Physical phone 2: HONOR 400 Pro | 16 (MagicOS 10) | (fill in from About phone; do not paste IMEI or serial) | Text Huge / Display Large | Yes (v1.0.6) | (not run) | (not run) | D16 |
```

## Proposed wording for `docs/MVP1_ACCEPTANCE.md`

Agree with Lim first. The existing line also says "Real device full journey passes", and
the Galaxy A55 run had J5 Partial (D15), so it is split in two:

```
- [x] Text size and keyboard usable on a real device. 23 Oct, Tan Yi Ming, HONOR 400 Pro
  (MagicOS 10, Android 16), Balance v1.0.6, Text size Huge / Display size Large: all five
  tabs, forms, Profile and a Council plan card readable; keyboard does not hide Create task;
  minor mid-word wrapping (D16). See docs/BUILDING_EVIDENCE_PACK.md section G.
- [ ] Real device full journey passes. Matthew, Galaxy A55 (v1.0.3): J3, J4, J6, J7, J8 Pass,
  J5 Partial (D15, recovery time not reserved).
```

## Not done yet

- Undo after Confirm, and Plan history showing Undone, were not captured on this device.
- Email flows (#5) and GitHub Actions (#10) are separate evidence.
- This run does not cover TalkBack, contrast or touch-target checks from section G.
