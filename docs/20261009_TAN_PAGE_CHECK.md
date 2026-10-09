# Quests and Sanctuary sign-off (Tan Yi Ming, 9 October 2026)

Fill this in on the emulator or a phone after `flutter test` passes. Mark each row
Pass or Fail and add a short note. A Fail goes into the defect list in
`docs/BUILDING_EVIDENCE_PACK.md` (section D). Do not write passwords or emails here.

| Field | Value |
| --- | --- |
| Commit (`git rev-parse --short HEAD`) | |
| Device | Pixel 8 API 35 emulator / phone model |
| Run command | `flutter run --dart-define-from-file=.env` |
| Account alias | |
| Date / time | |

## 1. Quests (about 5 minutes)

| ID | Step | Expected | Result | Note |
| --- | --- | --- | --- | --- |
| Q1 | Open Quests | Title **TASKS**, small **QUEST BOARD** above it | | |
| Q2 | Look at a task whose due date has passed | **OVERDUE** tag, "Was due …", subtitle says "N overdue" | | |
| Q3 | ⋮ → **Mark as done** | "Marked as done." and the task moves to **FINISHED** | | |
| Q4 | ⋮ → **Mark as not done** | Task returns; OVERDUE comes back if still late | | |
| Q5 | Mark an **Exercise** task as done | "Record this exercise?" appears; **Skip** closes it and nothing is recorded | | |
| Q6 | Status chip → **Overdue** | Only overdue tasks; chip reads "Status: Overdue"; **Clear filters** resets | | |
| Q7 | Search "rev" | Only matching tasks shown | | |
| Q8 | + → try to save without a category | Save blocked with an English message | | |
| Q9 | + → create a task with a category | "Task created." and it appears in the list | | |
| Q10 | Airplane mode on → pull down to refresh | Tasks stay visible; "Could not connect …" with **Try again** | | |
| Q11 | Airplane mode off → **Try again** | Error disappears | | |

## 2. Sanctuary (about 5 minutes)

| ID | Step | Expected | Result | Note |
| --- | --- | --- | --- | --- |
| R1 | On **Today**, add availability for today (e.g. 8–10 PM) | Block appears on Today | | |
| R2 | Sanctuary → + → choose a time inside that block → save | Slot shows **TIME RESERVED** / protected | | |
| R3 | + → choose a time on a day with **no** availability → save | "Recovery time must be inside your available time. Add availability on Today first, then try again." plus **Go to Today** | | |
| R4 | Tap **Go to Today** | Today opens | | |
| R5 | + → overlap an existing slot | "This overlaps another recovery slot." | | |
| R6 | On a slot that has already started, tap **Activity done**, then **Undo activity done** | Both work; the page says marking done does not change workload scores | | |
| R7 | Remove a manual slot | Slot disappears | | |
| R8 | Airplane mode on → pull to refresh | Friendly error with Try again; no raw database text | | |

## 3. Accessibility (both pages, about 10 minutes)

Turn on TalkBack: Settings → Accessibility → TalkBack. Swipe right to move, double-tap
to press. Turn it off the same way when done.

| ID | Check | Quests | Sanctuary | Note |
| --- | --- | --- | --- | --- |
| A1 | Every button is read with a clear name (+ reads "Add task" / "Add recovery time", ⋮ reads "Task actions", Profile reads "Profile") | | | |
| A2 | Focus moves top to bottom in reading order; dialogs keep focus until closed | | | |
| A3 | OVERDUE / PROTECTED / Locked are read as words, not only shown as colour | | | |
| A4 | Settings → Display → Font size **largest** and Display size **largest**: nothing cut off or overlapping; page still scrolls | | | |
| A5 | Every tappable item is easy to hit with a fingertip (chips, ⋮, day arrows) | | | |
| A6 | Faint grey text (footer notes, "Was due") is readable | | | |

Anything that fails here: write the exact screen and element, then send it to Tan's
Claude session for a fix.

## 4. English screenshots (judge evidence)

Default font size, prepared account, no personal data visible. Emulator: the camera
icon in the side toolbar saves a PNG. Phone: Power + Volume down.

| File name | Screen |
| --- | --- |
| `q01_tasks_list.png` | Quests list with an OVERDUE task and the FINISHED group |
| `q02_task_menu.png` | ⋮ menu open showing Mark as done |
| `q03_task_form.png` | New task form with the category choices |
| `q04_filters.png` | Status filter menu showing Overdue |
| `s01_sanctuary.png` | Sanctuary with a protected slot |
| `s02_add_recovery.png` | Protect recovery time dialog |
| `s03_no_availability.png` | The "Add availability on Today first" message with Go to Today |
| `s04_empty.png` | Sanctuary empty state (fresh account) |

Save them in a shared team folder (not in Git) and note the folder link here:

Folder: ____________________

## Sign-off

| Page | All rows Pass? | Open defects | Signed (name, date) |
| --- | --- | --- | --- |
| Quests | | | |
| Sanctuary | | | |
