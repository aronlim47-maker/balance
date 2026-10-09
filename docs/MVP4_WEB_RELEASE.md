# MVP4 Web preparation and release runbook — Lim Ze Heng

## What this increment actually delivers

- Configured Flutter Web release compilation for existing personal-workload flows.
- Existing responsive navigation: side rail at 840 logical pixels and above,
  bottom navigation on smaller screens. Content width is bounded at 1100 pixels.
- English web metadata, a loading notice and safe startup-failure wording.
- Browser email redirects return to the current HTTPS website/base path, not an
  assumed localhost Site URL. Route fragments and query tokens are excluded.
- Android/iOS retain `com.balance.app://auth-callback/`.
- Pull-request checks compile Web using clearly fake configuration. That output
  is not deployable and does not prove connectivity to Supabase.
- A manual GitHub workflow builds a configured candidate after analysis/tests and
  uploads it as a seven-day artifact; it does not host or deploy the application.

This is **not** an organization/team dashboard or complete MVP4 sign-off.
No offline write queue, external OAuth integration, public API or webhook is
implemented by this increment. Browser caching is not offline synchronization.

## Verified locally on 4 October 2026

- Flutter analysis: no issues.
- Full automated suite: 188 tests passed.
- Configured release Web build: succeeded at `build/web`.
- Browser: local site reached `/#/login` and displayed the English login controls.
- Account help navigation opened `/#/account-help` and returned to login.
- No account was signed into and no reset/verification email was sent by the agent.
- Authenticated browser writes, email callbacks and production hosting are not
  established by this smoke test. Responsive primary-navigation checks are widget
  tests, not an authenticated production browser acceptance result.

## 8 October recheck

- `flutter build web --release --dart-define-from-file=.env` completed successfully
  to `build/web` after the current integration.
- `flutter analyze --no-pub` reports no issues and `flutter test --no-pub` passes
  all 204 tests.
- Android debug APK also built and launched on the Android 15 emulator, but these
  checks do not replace Web browser acceptance.
- Browser smoke testing remains open: the workspace could not start a static local
  preview server and Chrome automation was unavailable in this session. No hosting,
  public domain, signed-in browser write or email callback was verified.

## Local browser test

From the project directory, build with:

```powershell
flutter build web --release --dart-define-from-file=.env
```

Serve **only** the generated `build/web` directory using a static HTTP server
bound to `127.0.0.1`; never serve the repository root or `.env`. The agent's local
test service uses `http://127.0.0.1:8765/`. This is not a publicly deployed app.

The local Supabase email callback allowlist must include that exact base URL if
you want to test email recovery there. PKCE links should be opened in the same
browser/site that requested them. Do not copy access tokens into screenshots,
reports or source control. A new origin/port has separate browser session storage.

## Production preparation — requires a selected host/domain

1. Choose the approved HTTPS host and exact base path, e.g. a root `/` or a
   subdirectory `/balance/`. The examples here are not configured project domains.
2. For subdirectory hosting, build with the corresponding trailing-slash base:
   `flutter build web --release --base-href /balance/ --dart-define-from-file=.env`.
   For root hosting, the default `/` is correct.
3. Deploy only `build/web`. Never publish `.env`, credentials, source maps, a
   service-role key or a Supabase secret key. A publishable key is expected to be
   visible in browser code; actual protection must be server-enforced RLS.
4. In Supabase Authentication URL Configuration, set the approved website's base
   as Site URL and add its exact HTTPS base URL to Redirect URLs. Retain the
   approved mobile callback. Do not add broad arbitrary-origin wildcards.
5. Review existing email templates: if customized, ensure they respect the
   requested redirect rather than hard-code an obsolete Site URL.
6. Use hash routing as currently configured. URLs such as `/#/quests` return the
   same index document; do not switch to path routing without rewrite rules and
   a corresponding callback-policy review.
7. Configure the host to serve HTML/bootstrap/main JS with revalidation so a new
   deployment does not leave users on stale application code. Test refresh after
   each release; do not claim automatic offline data safety from a web manifest.
8. Require HTTPS, correct JS/Wasm MIME types and needed Flutter renderer assets.
   Test actual network/firewall behavior. The stock build may fetch renderer/font
   assets externally; offline startup is not an acceptance claim here.
9. Complete the acceptance gates below before public/judge release.

## GitHub candidate workflow

After committing/pushing the reviewed changes:

1. Store `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` in the repository's Actions
   secrets. Use this project's HTTPS URL and an `sb_publishable_...` key only.
   Do not provide admin, service-role or `sb_secret_...` keys.
2. Open Actions → **Prepare Balance web candidate** → Run workflow and select
   the reviewed branch/commit. This is manual, not a deployment trigger.
3. Confirm all checks passed. Download `balance-web-<commit SHA>` and archive the
   SHA, test evidence, build time and host configuration with release notes.
4. Deploy to the chosen host only after authorization and security acceptance.

The new workflow has not been executed remotely in this increment. Missing
repository secrets should fail the build instead of producing a falsely configured
release. PR compilation uses fake values and must never be used as the release.

## Browser/production acceptance checklist

- [ ] Actual chosen HTTPS domain serves the exact reviewed commit.
- [ ] Desktop and mobile browser layouts navigate all five personal pages.
- [ ] Keyboard/tab navigation, text scaling, scrolling and form validation work.
- [ ] Sign in/out and page reload preserve/clear the correct session.
- [ ] Signup/verification/recovery emails return to the exact website; expired
  links cannot authorize password changes.
- [ ] Two-user isolation and logged-out access checked against real Supabase RLS.
- [ ] Task writes, Daily Review, recovery, achievements and Council Confirm/Undo
  work with real account data and safe errors.
- [ ] Failed network writes do not appear saved; changed remote plans fail safely.
- [ ] Desktop/browser reminder settings remain unavailable rather than claiming
  native mobile notifications are supported there.
- [ ] Hosting cache/update behavior verified; no obsolete service worker keeps an
  earlier client active after deployment.
- [ ] GitHub candidate workflow passes for the exact submitted commit.

## Rollback and database responsibilities

Keep an immutable copy of the previous accepted Web artifact. For a frontend
rollback, restore that artifact on the same host and verify account/callback/core
flows. Do not roll back database schemas destructively or restore production data
merely because the frontend failed. Chong owns compatible additive migration and
backup contracts; Matthew/Chong/Lim must rehearse restore and access checks in an
approved isolated environment before claiming recovery readiness.

## Remaining MVP4 dependencies

| Area | Dependency and acceptance boundary |
| --- | --- |
| Organization dashboard | Chong's membership/role schema and least-privilege RLS; Tan's approved views. Client-side role labels alone are not authorization. |
| External education/project integration | Approved provider, user consent/scopes, revocation and auditable backend contract. No provider is assumed. |
| Offline/cross-device sync | Chong's version/conflict/idempotency contract and durable owner-isolated client storage. Confirm/Undo must not replay blindly. |
| APIs/webhooks | Server-enforced identity, scopes, rate limits, replay defense and audit. A client screen cannot establish these controls. |
| Operations/recovery | Host/domain decision, real account testing, backup evidence and an authorized rollback/restore rehearsal. |

References: [Flutter Web release](https://docs.flutter.dev/deployment/web),
[Flutter Web initialization](https://docs.flutter.dev/platform-integration/web/initialization),
[Supabase redirect URLs](https://supabase.com/docs/guides/auth/redirect-urls).
