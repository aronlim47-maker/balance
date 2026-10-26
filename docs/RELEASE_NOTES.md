# Balance release notes

## v1.0.8 — 26 October 2026

Checked on phones and tablets of every size. Install it over any earlier version; your
sign-in and settings stay. Judges: the
[user guide](https://github.com/aronlim47-maker/balance/blob/master/docs/USER_GUIDE.md)
([PDF](https://github.com/aronlim47-maker/balance/blob/master/docs/Balance_User_Guide.pdf))
applies unchanged.

### Fixes

- On very small phones (320 dp wide) the task form's Flexibility list no longer runs off the
  right edge; long choices in every drop-down list now end with "…" instead.

### Quality

- New device test: every main page, the task form, Profile and the beginner guide lay out
  without overflow on a small phone (320×568), compact Android (360×640), Galaxy A55
  (384×832), large phone (430×932), phone landscape, an open foldable and a tablet in
  portrait (800×1280) and landscape (1280×800). Tablets and landscape screens get the side
  navigation rail.
- 466 automated tests; critical code 93.4% line coverage.

## v1.0.7 — 26 October 2026

Easier passwords on sign-up and reset. Install it over any earlier version; your sign-in and
settings stay. Judges: the
[user guide](https://github.com/aronlim47-maker/balance/blob/master/docs/USER_GUIDE.md)
([PDF](https://github.com/aronlim47-maker/balance/blob/master/docs/Balance_User_Guide.pdf))
applies unchanged; the judge account signs in exactly as before.

### New

- Sign-up asks for the password twice (**Confirm password**) and both fields have the eye
  button to show or hide what you typed.
- The **Choose a new password** screen (from a reset email) also has show/hide on both
  fields.

### Fixes

- Choosing your old password again when resetting it now says *Choose a password that is
  different from your old one* instead of an error code.
- Opening a reset link no longer shows the earlier "a reset link will arrive shortly"
  message on the Choose a new password screen.

### Quality

- 458 automated tests; critical code 93.4% line coverage.

## v1.0.6 — 16 October 2026

Clearer messages when sign-up or sign-in is temporarily limited. Install it over any earlier
version; your sign-in and settings stay. Judges: the
[user guide](https://github.com/aronlim47-maker/balance/blob/master/docs/USER_GUIDE.md)
([PDF](https://github.com/aronlim47-maker/balance/blob/master/docs/Balance_User_Guide.pdf))
applies unchanged.

### Fixes

- When the server asks you to wait (for example after tapping Sign up twice), Balance says
  how many seconds to wait, and the button counts down (*Try again in 42s*) and unlocks by
  itself. Before, it said only "Could not complete the account request".
- Too many verification emails: Balance explains that new emails are paused for up to an
  hour and that the first email may already be in the inbox or spam folder.
- Too many attempts from one device, or an email that could not be sent, each have their
  own message with how long to wait.
- Any other account error shows its error code, so the team can help.

### Quality

- 450 automated tests; critical code 93.4% line coverage.

## v1.0.5 — 13 October 2026

Consistency fixes from the second physical-phone retest (HONOR 400 Pro). Install it over any
earlier version; your sign-in and settings stay. Judges: the
[user guide](https://github.com/aronlim47-maker/balance/blob/master/docs/USER_GUIDE.md)
([PDF](https://github.com/aronlim47-maker/balance/blob/master/docs/Balance_User_Guide.pdf))
applies unchanged; the sample day works exactly as before.

### Fixes

- Today's Time capacity tag now shows the full capacity gap, the same number as Council and
  the Capacity gap card. Before, a day with work due before its free time could read
  *1H OVER* on Today and *2H OVER* on Council.
- Council on a day with no tasks and no free time says *Nothing planned yet* instead of the
  green *No changes needed. Your plan fits this day.*
- Sanctuary's folded *Next rest* line uses 12-hour time like the rest of the page.

### Quality

- 446 automated tests; critical code 93.1% line coverage.

## v1.0.4 — 13 October 2026

Two small wording fixes found while retesting v1.0.3. Install it over any earlier version;
your sign-in and settings stay. Judges: the
[user guide](https://github.com/aronlim47-maker/balance/blob/master/docs/USER_GUIDE.md)
([PDF](https://github.com/aronlim47-maker/balance/blob/master/docs/Balance_User_Guide.pdf))
applies unchanged.

### Fixes

- Deleting a task that was part of a confirmed plan (even one later undone) now explains
  why it cannot be deleted — plan history keeps it — and suggests **Mark as done**, which
  removes it from every day. Before, it said only "Could not delete this task. Please try
  again."
- Protect recovery time with no free time ahead now says "No free time in the 7 days from
  *(date)*" instead of "this week", which read as the calendar week.

### Quality

- 445 automated tests; critical code 93.1% line coverage.

## v1.0.3 — 13 October 2026

A smarter War Council for days with no safe move. Install it over any earlier version; your
sign-in and settings stay. Judges: the
[user guide](https://github.com/aronlim47-maker/balance/blob/master/docs/USER_GUIDE.md)
([PDF](https://github.com/aronlim47-maker/balance/blob/master/docs/Balance_User_Guide.pdf))
applies unchanged; the sample day works exactly as before.

### Council finds more safe moves

- Flexible work without a start time can now move, whole or in part, to free time on an
  earlier day before its deadline. Before, it was never moved.
- When no free window is long enough, a plan can move the largest part that fits and leave
  the rest in place.
- Fixed and protected work and protected rest still never move, and the server still checks
  every rule before saving.

### When there is still no safe move

- Council names the day and the extra free time that would unlock a plan, for example
  *Add 2h 30m of free time on Wed 14 Oct (for example 8:00–10:30 AM)*, and says when that day
  is already over capacity. Each suggestion is checked by re-running Council first.
- **Add free time on …** opens Today on that day.
- **Edit task** opens a blocking task (work due that day, or work waiting for agreement) so
  you can change its deadline or minutes; Council checks the day again after saving.
- Reasons no longer ask for a start time; they say when work is due that same day.

### Quality

- 443 automated tests; critical code 93.1% line coverage.

## v1.0.2 — 13 October 2026

Fixes from our physical-phone smoke test (Samsung Galaxy A55 5G). Install it over
v1.0.0 or v1.0.1; your sign-in and settings stay. Judges: the
[user guide](https://github.com/aronlim47-maker/balance/blob/master/docs/USER_GUIDE.md)
([PDF](https://github.com/aronlim47-maker/balance/blob/master/docs/Balance_User_Guide.pdf))
applies unchanged.

### Fixes

- When work is due before the day's free time starts, the Capacity gap card now explains
  why the gap is larger than planned minus available time.
- A day with nothing added says "Nothing planned yet" instead of a green "Plan is
  balanced".
- The ▲/▼ change arrows only compare with a previous day that has a recorded total,
  the same rule as the 7-day trend.
- Council shows each option's description in full, so the time range is never cut off.
- Sanctuary uses 12-hour times everywhere, and its error message no longer touches the
  buttons below it.
- Journey's weekly chart states its unit (workload score 0–100 per day).

### Quality

- 431 automated tests; critical code 92.6% line coverage.

## v1.0.1 — 13 October 2026

A small update to v1.0.0. Install it over v1.0.0; your sign-in and settings stay.
Judges: the [user guide](https://github.com/aronlim47-maker/balance/blob/master/docs/USER_GUIDE.md)
([PDF](https://github.com/aronlim47-maker/balance/blob/master/docs/Balance_User_Guide.pdf))
applies unchanged.

### New

- Deadline reminders can now use a custom lead time: besides 15 minutes, 30 minutes,
  1 hour and 1 day, choose **Custom minutes…** and enter 1 to 10080 minutes (up to
  7 days). Only whole numbers in that range are accepted.

### Quality

- 427 automated tests; critical code 92.5% line coverage.

## v1.0.0 — Building submission (October 2026)

Balance helps a student whose plan no longer fits the day: it shows the overload,
compares safe ways to fix it, changes nothing until the student confirms, and can undo
every confirmed change. Android 8.0 or later. Judges: start with the
[user guide](https://github.com/aronlim47-maker/balance/blob/master/docs/USER_GUIDE.md)
([PDF](https://github.com/aronlim47-maker/balance/blob/master/docs/Balance_User_Guide.pdf)).

### Install

1. Download `app-release.apk` from this release on an Android phone.
2. Open it and allow installing from this source if Android asks.
3. If an older Balance test build is installed, uninstall it first (the app ID is now
   `com.gateofsteiner.balance`).
4. Keep the phone on Malaysia time; times follow the phone's time zone.

### What Balance does

- **Detect (Today · World Status):** planned vs available time first, a clear verdict,
  the day's availability and tasks, then five workload dimensions (Mental, Time,
  Physical, Social, Errands) with their change since yesterday and a 7-day trend.
  Missing data is **Unknown**, never zero.
- **Decide (War Council):** safe moves that keep protected commitments (shifts, family,
  sleep) in place, with cost, room created and checks shown before you confirm. The
  server re-checks every rule on confirm; any plan can be undone from Plan history.
- **Recover (Sanctuary):** protect genuinely free time for rest, chosen from suggested
  free windows. Activities are optional and rest is never scored.
- **Reflect (Journey):** a private weekly summary, optional reflections and an RPG
  achievement wall of seven badges for safe planning, celebrated once when earned.
  No streaks, rankings or penalties.

### New in this build

- Beginner guide: five simple steps with short animations and "Show me" shortcuts to each
  page; shown on first run and reopenable from Profile → Beginner guide.
- Quest Board task details with an Edit action.
- Copy availability from the previous day, or repeat a day for the next six days.
- Per-dimension change since yesterday (▲/▼) on the workload bars.
- Free-time suggestions when protecting recovery time.
- Optional overload alerts the evening before an over-capacity day (off by default).
- RPG achievement wall with an unlock celebration (flash, gold sparks and a short
  vibration); original sound effects and relaxing background music, both on by default.
  A gold music button on every page turns the music off in one tap.
- Dark look by default, plus a warm parchment light look (sun/moon button).
- Sanctuary rest camp: a campfire scene whose sky follows the clock, a soft crackle while
  music is on, and an optional one-minute 'Breathe with the fire' exercise (never scored).
- Short one-shot animations on the core journey: the capacity bar fills and the verdict
  pops in, the five workload bars grow with counting scores, a confirmed plan draws a tick
  and slides the task to the day with room, and Undo slides it back. All of them show
  their finished frame when the phone asks for reduced motion.
- Gold guild-crest app icon (adaptive and Android 13 themed), a dark launch screen with
  the crest, the crest on the sign-in page and as the notification icon.
- Foldable page sections (main ones open, choice remembered on the phone) with a ? button
  that explains each page and section; full-width Add task and Add recovery time buttons.
- Profile: edit the display name and choose a profile photo (kept on the phone only).
- Simpler pages: decision first on Today, one-line score explanations, compact trend,
  shorter Council, Journey and Sanctuary text, plain wording without technical terms.

### Fixes

- Turning on Track movement no longer fails with "You do not have access".
- The Android back gesture no longer closes the app from sign-up, account help or the
  main tabs; it returns to sign-in or Today.
- A confirmed plan can be undone after leaving the plan-updated screen (Plan history).
- Large text (200%) no longer overflows on the main pages; faint text meets WCAG AA.
- Sign-in shows the Email field again (it had been replaced by a second password field).
- Closing the weekly reflection with Back no longer shows an error screen.
- Council names a blocking recovery slot in local time (it showed the UTC hour).
- Today's task cards show the minutes that count on that day, including plan-moved time.
- Sound effects no longer pause the background music.
- Council no longer flashes "Needs Review" while it loads; Edit name starts with the
  current name.

### Quality and monitoring

- 422 automated tests; critical code 92.5% line coverage, enforced by CI on every push.
- Accessibility tests on every main page: tap targets, labels, contrast, 200% text.
- Hourly health check of the backend and the APK download link; crash reporting with
  Sentry (errors only; no screenshots, IP address or user email).

### Known limitations

- Android only; iOS is not device-tested and the web build is not part of this release.
- Every task needs a deadline. Shared tasks and the Team Coordination badge are planned
  for a later version.
- English only; Bahasa Melayu and Chinese are planned.
- Scores describe recorded planning data. Balance is not a medical, diagnostic or
  mental-health tool.
