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

**Pass, with one Minor cosmetic defect (D18).** Every screen below scrolls, is readable,
has no overlapping text, and the bottom navigation labels fit. With the keyboard open the
fields stay visible and **Create task** stays reachable above the keyboard.

## Screens checked

| Screen | What it shows | File |
| --- | --- | --- |
| Settings | Text size Huge | `A11Y_font_setting.jpg` |
| Settings | Display size Large | `A11Y_display_setting.jpg` |
| Today | Top of screen; "AVAILABIL-ITY" breaks mid-word (D18) | `A11Y_today.jpg` |
| Today | Scrolled; Availability and Planned tasks | `A11Y_today_scrolled.jpg` |
| Today (Sat 24 Oct) | 3h available, 5h planned, 2h over, Capacity gap card | `A11Y_today_overload.jpg` |
| Quests | Add task, search, filters, first quest | `A11Y_quests.jpg` |
| New task | Title field focused, keyboard open | `A11Y_keyboard_title.jpg` |
| New task | Estimated minutes, number keyboard open | `A11Y_keyboard_minutes.jpg` |
| New task | Create task visible above the keyboard | `A11Y_keyboard_create.jpg` |
| Edit task | Flexibility, Status, toggles, Planned start, Save changes | `A11Y_edit_form.jpg` |
| Council | Empty day ("No time added"); "WAR COUNCI-L" breaks mid-word (D18) | `A11Y_council.jpg` |
| Council | "No free time was found" message and Add free time button | `A11Y_council_nosafe.jpg` |
| Council | Plan card "Move 120 minutes to Sun 25 Oct" and Confirm selected plan | `A11Y_council_plan.jpg` |
| Plan confirmed | "Plan confirmed", what moved, change reference | `A11Y_council_confirmed.png` |
| Sanctuary | Empty state; Add recovery button partly behind nav while scrolling | `A11Y_sanctuary.jpg` |
| Sanctuary | Add recovery time button fully visible | `A11Y_sanctuary_button.jpg` |
| Journey | Achievements; "Coordinatio-n" breaks mid-word (D18) | `A11Y_journey.jpg` |
| Journey | Weekly pattern, "–" means no record | `A11Y_journey_week.jpg` |
| Profile | Time zone Asia/Kuala_Lumpur; email hidden with solid blocks | `A11Y_profile.jpg` |

## Where this is recorded

- `docs/BUILDING_EVIDENCE_PACK.md`, section G (Text scaling row), section D (D18) and the section J test log.
- `docs/MVP_ACCEPTANCE.md`: "Text size and keyboard usable on a real device" and the 23 October Evidence log paragraph.

## Related earlier evidence on this phone

TalkBack labels, focus order, touch targets, contrast and colour-alone checks were run on this
HONOR 400 Pro on 13 October 2026 (run R10, v1.0.2): see section G and
`docs/evidence/Accessibility/G01-G10`.

## Not done on v1.0.6

- Undo after Confirm and Plan history on this device.
- Email flows and GitHub Actions evidence are separate.
