# Lim Ze Heng: MVP 2–4 delivery status

This is a delivery checklist, not a claim that versions 2–4 are complete.
Ownership follows the Rev6 design guide. Existing MVP1 functionality must remain
usable; later-version integrations must not bypass server authorization.

## Implemented in this increment

- [x] Wide-screen navigation rail for the five existing personal-workload pages.
- [x] Mobile bottom navigation retained below 840 logical pixels.
- [x] Wide content constrained to 1100 logical pixels for readable layouts.
- [x] Widget tests for desktop navigation and resizing back to mobile.

This is part of MVP4 responsive app preparation, **not** an organization dashboard.
Existing authentication and repository ownership rules are unchanged.

## MVP2: Lim-owned work still required

- [ ] Reminder settings, permission handling, scheduling, cancellation and quiet hours.
- [ ] Device notification verification, including denied permissions and changed tasks.
- [ ] Remote push delivery: select/configure a provider; coordinate owner-bound device
  token storage with Chong. No credentials or server endpoints are assumed to exist.
- [ ] Calendar client integration: agree provider and Chong's import/sync contract;
  handle source identifiers, time zones, duplicate imports and revoked permission.
- [ ] iOS validation on macOS, signing setup and a physical-device test.
- [ ] Collaboration release acceptance after the shared-task backend is available.

## MVP3: Lim-owned work still required

- [ ] Integrate Matthew's multi-alternative recommendation contract into Council.
- [ ] Verify every option displays moves, unchanged protected commitments, costs and
  resulting capacity before confirmation.
- [ ] Exercise confirmation and undo against the deployed backend; do not treat a
  recommendation preview as a saved change.
- [ ] Cross-platform release checks after recommendation/privacy acceptance.

## MVP4: Lim-owned work still required

- [ ] Web build and browser acceptance for the existing personal-workload flows.
- [ ] Authorized organization dashboard after Chong provides membership/role RLS.
- [ ] Approved education/project-management integration with revocation and audit.
- [ ] Durable owner-isolated offline synchronization with Chong's version/conflict
  contract. Never replay confirm/undo blindly or describe queued work as saved.
- [ ] Controlled API/webhook delivery with server-enforced scopes and rate limits.
- [ ] Operations, rollback and backup/recovery exercises with Matthew and Chong.

## Completion evidence

Check a box only after implementation and the relevant test evidence exist. Local
widget tests do not prove push delivery, calendar authorization, RLS, iOS support,
offline safety or production release readiness. Never include account secrets in
this file or in source control.
