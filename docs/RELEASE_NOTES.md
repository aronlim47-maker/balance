# Balance release notes

## v1.0.0 — Building submission (October 2026)

Balance helps a student whose plan no longer fits the day: it shows the overload,
compares safe ways to fix it, changes nothing until the student confirms, and can undo
every confirmed change. Android 8.0 or later. Judges: start with the
[user guide](USER_GUIDE.md).

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

- First-run introduction (three pages), reopenable from Profile → How Balance works.
- Quest Board task details with an Edit action.
- Copy availability from the previous day, or repeat a day for the next six days.
- Per-dimension change since yesterday (▲/▼) on the workload bars.
- Free-time suggestions when protecting recovery time.
- Optional overload alerts the evening before an over-capacity day (off by default).
- RPG achievement wall with an unlock animation; optional original sound effects and
  relaxing background music (music off by default).
- Simpler pages: decision first on Today, one-line score explanations, compact trend,
  shorter Council, Journey and Sanctuary text, plain wording without technical terms.

### Fixes

- Turning on Track movement no longer fails with "You do not have access".
- The Android back gesture no longer closes the app from sign-up, account help or the
  main tabs; it returns to sign-in or Today.
- A confirmed plan can be undone after leaving the plan-updated screen (Plan history).
- Large text (200%) no longer overflows on the main pages; faint text meets WCAG AA.

### Quality and monitoring

- 377 automated tests; critical code 92.4% line coverage, enforced by CI on every push.
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
