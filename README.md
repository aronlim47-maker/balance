# Balance

Balance is a Flutter workload-planning application. The current foundation includes navigation, shared UI, the War Council flow, Supabase authentication, and the initial database migration.

## Supabase setup

1. Create a Supabase project.
2. Open the Supabase SQL Editor and run `supabase/migrations/202609240001_initial_schema.sql`.
3. Copy `.env.example` to `.env`.
4. Put the project URL and publishable key in `.env`. Never use the `service_role` key in the Flutter application.
5. Run the app with:

```powershell
flutter run --dart-define-from-file=.env
```

The migration creates the seven MVP tables, automatically creates a profile after signup, enables Row Level Security on every application table, and adds atomic confirm/undo RPC functions.

Without Supabase values, the app stays in local development mode so UI work and widget tests can continue.

## Verification

```powershell
flutter analyze
flutter test
```
