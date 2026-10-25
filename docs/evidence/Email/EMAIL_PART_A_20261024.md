# Email evidence, Part A: signup verification (24–25 October 2026)

| Field | Value |
| --- | --- |
| Tester | Tan Yi Ming |
| Device | HONOR 400 Pro, MagicOS 10, Android 16 |
| App version | Balance v(fill in from pubspec.yaml), built locally from branch `honor-a11y-evidence` with the sign-up change (commit: fill in) |
| Mode | Supabase cloud, new test account (no email or password recorded) |
| Mail | Supabase Auth default template |

## Result

**Pass.** A new account was created at 23:59 and the app showed "Check your email to verify
your account. If you already have an account, sign in or use Account help." The verification
email arrived in about 20 seconds. Tapping "Confirm email address" on the same phone opened the
app through the `com.balance.app://auth-callback/` callback, signed the account in and showed
the Beginner guide at 00:06.

Observation: a new account starts on the `UTC` planning time zone (Profile, 00:06). Setting it
to `Asia/Kuala_Lumpur` in Profile worked and was saved (00:10). The judge guide should tell
users to set their time zone first.

Minor: the email is Supabase's default template ("powered by Supabase"), with no Balance branding.

## Files

| Step | What it shows | File |
| --- | --- | --- |
| Sign-up | New sign-up form (eye icons, Confirm password) and the verification notice; email address hidden | `EMAIL_signup_app.png` |
| Inbox | "Confirm your email address" from Supabase Auth; address and link not shown | `EMAIL_signup_inbox.png` |
| Link opened | Beginner guide step 1 of 5 after tapping the link | `EMAIL_signup_verified.png` |
| Profile (00:06) | Signed in, cloud account, time zone UTC; email hidden | `EMAIL_signup_profile.png` |
| Profile (00:10) | Same account with time zone set to Asia/Kuala_Lumpur | `PROFILE_timezone_set.png` |

## Not done yet

- Part B: resend verification.
- Part C: reset password and the recovery tests (app open and closed, used or expired link, wrong and new password).
- Acceptance lines 38 and 39 stay unticked until Parts B and C have evidence.
