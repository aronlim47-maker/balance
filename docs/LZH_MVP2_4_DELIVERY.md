# Lim Ze Heng: MVP 2–4 delivery status

This is a delivery checklist, not a claim that versions 2–4 are complete.
Ownership follows the Rev6 design guide. Existing MVP1 functionality must remain
usable; later-version integrations must not bypass server authorization.

## Implemented in this increment

- [x] Wide-screen navigation rail for the five existing personal-workload pages.
- [x] Mobile bottom navigation retained below 840 logical pixels.
- [x] Wide content constrained to 1100 logical pixels for readable layouts.
- [x] Widget tests for desktop navigation and resizing back to mobile.
- [x] 8 October regression fix: World Status title/load summary adapt to narrow
  widths; full local Flutter suite passes 204 tests and static analysis is clean.

This is part of MVP4 responsive app preparation, **not** an organization dashboard.
Existing authentication and repository ownership rules are unchanged.

## MVP2: Lim-owned work still required

- [x] Local deadline reminder settings, explicit permission request, scheduling,
  cancellation and quiet hours implemented; domain/controller tests pass.
  Native permission and delivery acceptance remains unchecked below.
- [ ] Device notification verification, including denied permissions and changed tasks.
- [ ] Remote push delivery: select/configure a provider; coordinate owner-bound device
  token storage with Chong. No credentials or server endpoints are assumed to exist.
- [ ] Calendar client integration: agree provider and Chong's import/sync contract;
  handle source identifiers, time zones, duplicate imports and revoked permission.
- [ ] iOS validation on macOS, signing setup and a physical-device test.
- [ ] Collaboration release acceptance after the shared-task backend is available.

## MVP3: Lim-owned work still required

- [x] Compare existing single-task alternatives with calculated affected-day
  capacity, explicit trade-offs and a final confirmation preview. Stale-review
  and date-bound server-capacity guards implemented. See MVP3_COUNCIL_COMPARISON.md.
- [x] Integrate Matthew's deterministic multi-task alternatives into Council;
  candidate cards and final comparison show every move, affected-day capacity,
  unchanged protected items, costs, and why a preview is or is not confirmable.
- [ ] Broader quality review across realistic calendars; this is bounded rules-based
  planning, not personalized or predictive recommendations.
- [ ] Verify every option displays moves, unchanged protected commitments, costs and
  resulting capacity before confirmation.
- [ ] Exercise confirmation and undo against the deployed backend; do not treat a
  recommendation preview as a saved change.
- [ ] Cross-platform release checks after recommendation/privacy acceptance.

## MVP4: Lim-owned work still required

- [x] Configured Web compilation, English startup, same-site email callback policy,
  local login/account-help smoke test and candidate-build workflow prepared.
  Flutter analysis passed; the suite now passes all 204 tests. See MVP4_WEB_RELEASE.md.
- [x] 8 October local configured Web release build succeeded at `build/web` with
  `.env`; this is a build artifact only, not browser/live-auth/hosting acceptance.
- [ ] Browser acceptance for the existing personal-workload flows. The current
  workspace could not start a local static preview server or attach Chrome automation.
- [ ] Authorized organization dashboard after Chong provides membership/role RLS.
- [ ] Approved education/project-management integration with revocation and audit.
- [ ] Durable owner-isolated offline synchronization with Chong's version/conflict
  contract. Never replay confirm/undo blindly or describe queued work as saved.
- [ ] Controlled API/webhook delivery with server-enforced scopes and rate limits.
- [ ] Operations, rollback and backup/recovery exercises with Matthew and Chong.

## Completion evidence

### 8 October recheck

- [x] `flutter analyze --no-pub`: no issues.
- [x] `flutter test --no-pub`: all 204 tests pass, including the added explanation
  assertion for a feasible Council comparison option.
- [x] `flutter build web --release --dart-define-from-file=.env`: completed to
  `build/web`; no deploy or authenticated browser test was performed.
- [x] Android debug APK built, installed on Android 15 emulator and launched;
  process remained alive and the inspected log window contained no fatal exception.
- [ ] SQL parser validation could not run: Python is unavailable as an executable
  in this workspace. The database tests and live Supabase behaviors were not rerun.
- [ ] iOS compile/device check unavailable on this Windows host; Android licenses
  also show as not accepted in `flutter doctor`.

### 4 October database acceptance update

- [x] Remote Confirm/Undo, stale-version rejection, occupancy and social retry
  assertions passed with rollback after restoring the missing progress helpers.
- [x] Snapshot capture, trusted achievement evidence and duplicate prevention
  passed; the scoped cross-owner database security script also passed.
- [ ] Verify Today history and Journey achievements through the actual app.
- [ ] Verify two actual signed-in app accounts and concurrent-device behavior.

The deployed backend exercise in MVP3 has database-level evidence now, but its
broader checkbox remains open until app-flow acceptance. This update does not
complete notifications, integrations, organization access, offline sync or release.
Details: `MVP1_ACCEPTANCE.md` and `20261004_AUDIT_FIXES.md`.

Check a box only after implementation and the relevant test evidence exist. Local
widget tests do not prove push delivery, calendar authorization, RLS, iOS support,
offline safety or production release readiness. Never include account secrets in
this file or in source control.
