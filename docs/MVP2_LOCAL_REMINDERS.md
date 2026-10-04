# MVP2 local task reminders

## Scope and entry point

Open **Profile → Task reminders** after signing in on Android or iOS.
This is local notification scheduling, not remote push, calendar synchronization
or automatic rescheduling. No new Supabase migration is required.

## Rules implemented

- Reminders are off by default and preferences are stored per account on this
  device. Switching accounts does not inherit the previous account's preference.
- Enabling reminders explicitly requests notification permission. Startup and
  refresh never prompt. Denial displays a safe English message rather than an
  exception and does not persist a newly enabled preference.
- Choose 15 minutes, 30 minutes, 1 hour or 1 day before the task deadline.
- Only planned tasks with positive remaining work and a future reminder instant
  qualify. Completed/cancelled/deleted tasks do not qualify. Protection is not
  changed by reminders.
- Quiet hours default to 22:00–08:00 in the device's IANA time zone. A reminder
  whose scheduled instant falls inside the interval is skipped, not postponed.
  Start is inclusive and end exclusive. Equal start/end is rejected when enabled.
- UTC deadline minus lead duration is converted to the device time zone. This
  preserves the intended instant across daylight-saving changes.
- At most the nearest 50 eligible task deadlines are scheduled. No repeating
  catch-up notification or past-deadline notification is created.
- Notifications use generic wording, without task titles, email or account ID.
- Successful task writes reconcile reminders. Notification failure does not
  change the confirmed write result; a separate warning appears in reminder
  settings. Task writes that fail do not trigger reconciliation.
- Reconciliation clears old requests before scheduling the current authoritative
  task list. Serial execution and account-generation checks prevent an old
  asynchronous operation from installing another account's reminders.
- Sign-out/account change clears scheduled and displayed local notifications.
  App resume/manual refresh fetches task changes made elsewhere. While this app
  remains closed, remote edits cannot update its existing device reminders.
- Android uses inexact scheduling, without exact-alarm or Do Not Disturb override
  permissions. Battery restrictions can delay delivery, including beyond a quiet
  boundary. Quiet hours filter intended times; this is not an OS-level DND policy.
- Android reboot/update receivers and a retained monochrome notification icon are
  configured. iOS notification delegate setup is included but not device-tested.

## Automated verification

Eight new domain/controller tests cover default-off, expired/completed/cancelled
tasks, duplicate IDs, quiet boundaries, time zones/DST, nearest-50 limit, denied
permission, mutation reconciliation, failure isolation and account-switch races.
The full suite passed with 177 tests after fixing lazy preference initialization
so local preview does not require a native storage plugin during startup. This
includes a widget test opening Profile → Task reminders in local preview and
checking that unavailable notification controls stay disabled without crashing.
Final Flutter analysis reported no issues. Android notification-plugin integration
built successfully into an internal test APK; real notification delivery and iOS
acceptance remain pending.

## Native acceptance — do not mark complete from unit tests

- [ ] Install the latest configured APK and sign in; reminders initially off.
- [ ] Enable and deny permission; verify guidance and no scheduled notifications.
- [ ] Grant permission and create a task due at least 20 minutes from now; choose
  a 15-minute lead and ensure its reminder time is outside quiet hours.
- [ ] Background/close the app and verify the generic notification arrives.
- [ ] Edit the deadline; verify the old reminder is replaced rather than duplicated.
- [ ] Complete, cancel and delete test tasks; verify their reminders are removed.
- [ ] Disable reminders; verify all pending reminders are removed.
- [ ] Sign out and switch to a second account; verify no old reminders/preferences
  leak across accounts.
- [ ] Reboot Android and test delivery with normal and restricted battery settings.
- [ ] Change device time zone, resume and refresh; verify quiet-hour interpretation.
- [ ] Verify iOS permission, background delivery and account switching on macOS/iPhone.

Keep actual device, OS, test time and outcomes with release evidence. A successful
APK build is not evidence that a notification arrived.
