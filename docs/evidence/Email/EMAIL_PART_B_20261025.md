# Email evidence, Part B: resend verification (25 October 2026)

| Field | Value |
| --- | --- |
| Tester | Tan Yi Ming |
| Device | HONOR 400 Pro, MagicOS 10, Android 16 |
| App version | Balance v(fill in from pubspec.yaml), built locally from branch `honor-a11y-evidence` (commit: fill in) |
| Mode | Supabase cloud, new unverified test account (no email or password recorded) |

## Result

**Pass.** A new account was created at 00:19 and its first verification email was left unopened.
A resend attempt at 00:21 was paused by the Supabase email rate limit (2 emails per hour,
project-wide) and the app showed "Too many verification emails were sent recently, so new ones are
paused for up to an hour…". Later the same day, "Resend verification email" on Account help showed
"If verification is needed, a new link will arrive shortly. Check your inbox and spam folder.";
the new email from Supabase Auth arrived within a few seconds (stamped 17:31); tapping its link
opened the app and signed the account in (screenshots 17:32). Profile (17:37) shows the signed-in
cloud account with display name "Test" and the default UTC time zone.

## Files

| Step | What it shows | File |
| --- | --- | --- |
| Sign-up (00:19) | Sign-up form and verification notice; email hidden | `EMAIL_t3_signup_app.png` |
| First email (00:19) | First "Confirm your email address" email; address hidden | `EMAIL_t3_inbox_first.png` |
| Rate limit (00:21) | Resend paused: "Too many verification emails were sent recently…" | `EMAIL_resend_ratelimit.png` |
| Resend (17:32) | Account help message after "Resend verification email" | `EMAIL_resend_app.png` |
| Resent email (17:31) | New "Confirm your email address" email | `EMAIL_resend_inbox.png` |
| Link opened (17:32) | App signed in on Today after tapping the link | `EMAIL_resend_verified.png` |
| Profile (17:37) | Signed-in cloud account "Test" | `EMAIL_resend_profile.png` |

## Notes

- Built-in Supabase email allows 2 emails per hour for the whole project; sign-ups, resends and
  password resets share it. A burst of sign-ups would be paused. Judges and testers use prepared accounts.
- Stale notice (minor): on Account help, the sign-up line "Check your email to verify your account…"
  was still showing before any button was pressed.

## Not done yet

- Part C: reset password and the recovery tests (app open and closed, used or expired link, wrong and new password).
- Acceptance lines 38 and 39 stay unticked until Part C has evidence.
