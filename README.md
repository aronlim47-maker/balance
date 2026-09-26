# Balance

Balance is a Flutter workload-planning application. The current foundation includes navigation, shared UI, the War Council flow, Supabase authentication, and the initial database migration.

## Supabase setup

1. Create a Supabase project.
2. Open the Supabase SQL Editor and run the migrations in order: `supabase/migrations/202609240001_initial_schema.sql`, then `supabase/migrations/202609250001_war_council_integrity.sql`. If the first migration has already been applied, run only the second one.
3. Copy `.env.example` to `.env`.
4. Put the project URL and publishable key in `.env`. Never use the `service_role` key in the Flutter application.
5. Run the app with:

```powershell
flutter run --dart-define-from-file=.env
```

For an Android APK, build it with the same compile-time configuration:

```powershell
flutter build apk --release --dart-define-from-file=.env
```

This APK is currently for internal device testing only. The Android application ID is still `com.example.balance`, and the release build uses the debug signing key. Before distributing a final APK, choose the permanent application ID, configure a private release signing key, and verify a fresh install and upgrade on real devices. Keep the signing key and passwords out of Git.

Install that newly built APK on the device. An app started or built without the `--dart-define-from-file=.env` argument runs in local preview mode even when `.env` exists on the computer. The app now displays a persistent local-preview banner and the Profile page shows the connection mode. Tasks made in local preview are only in memory; they are not sent to Supabase and cannot be automatically recovered or synced after switching modes. Re-create those tasks after launching the configured build.

The first migration creates the seven MVP tables, automatically creates a profile after signup, and enables Row Level Security. The second migration adds the War Council validation and atomic confirm/undo checks. Until it is applied, the app shows an upgrade notice and disables plan confirmation.

Before testing day-by-day planning, open Profile and set the signed-in user's planning time zone to match the device (for example, `Asia/Kuala_Lumpur` in Malaysia). New profiles currently default to `UTC`; a mismatch can make the app and database assign work near midnight to different days. The Profile page saves this setting to `profiles.time_zone`.

War Council labels plans as Feasible, Needs Review, Needs Agreement or No Feasible Plan. It compares its capacity calculation with the database before enabling confirmation; a mismatch is shown as Needs Review. Fixed and protected tasks and protected recovery are listed separately. Agreement-dependent suggestions are visible but cannot be confirmed until the task is updated after agreement.

To test War Council after upgrading, add three hours of availability on one future day and two hours on the following day. Create one flexible, unprotected task scheduled for the full three hours on the first day, with a deadline after the second day. Create another unscheduled two-hour task due on the first day. War Council should propose moving two hours of the scheduled task to the second day. Confirm it, check both days in Today, then undo it on the plan-updated screen. The first day's original overload should return after undo. Avoid changing the tasks or availability between confirm and undo, because the undo safety check may correctly reject restoration if a new conflict was introduced.

Without Supabase values, the app stays in local development mode so UI work and widget tests can continue.

User-facing failures are translated into concise English guidance for common authentication, connectivity, scheduling, permission and database cases. Unknown technical errors are not displayed verbatim; the app asks the user to retry instead.

## Verification

```powershell
flutter analyze
flutter test
```
