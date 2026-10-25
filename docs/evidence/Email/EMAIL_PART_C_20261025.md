# Email evidence, Part C: password reset and recovery (25 October 2026)

| Field | Value |
| --- | --- |
| Tester | Tan Yi Ming |
| Device | HONOR 400 Pro, MagicOS 10, Android 16 |
| App version | Balance v(fill in from pubspec.yaml), commit (fill in) |
| Account | The verified Part A test account (no email or password recorded) |
| Mail | Supabase Auth default template |

## Result

**Partly tested.** The reset email arrived and its link opened the "Choose a new password" screen.
Validation, the new password and the old password were checked. App-open (second run, to be confirmed) and expired-link
cases were not tested (see below), so acceptance line 39 stays unticked.

| Time | Step | Outcome | File |
| --- | --- | --- | --- |
| 20:15 | Account help, "Send password reset link" | Request made; email arrived in the same minute | `RESET_request_app.png`, `RESET_inbox.png` |
| 20:18 | Same as the current password | "Could not complete the account request (code: same_password). Please try again." | `RECOVERY_same_password_error.png` |
| 20:18 | A different new password | Password updated, app on Today | `RECOVERY_after_update_today.png` |
| 20:19 | Sign in with the old password | "The email or password is incorrect. Try again." | `RECOVERY_old_password_fails.png` |
| 20:19 | Sign in with the new password | Signed in, Today | `RECOVERY_new_password_works.png` |
| 20:19 | Opened the same reset email and tapped the link again | App opened on Today (still signed in); no new-password screen | `RECOVERY_used_link_email.png`, `RECOVERY_used_link_result.png` |

## Second run on the final build (25 October, 23:17-23:22)

Same account, after the reset screen gained show/hide eye buttons (PasswordField). The 20:15 table above was taken on the previous build; its three reset-screen shots were retaken here.

| Time | Step | Outcome | File |
| --- | --- | --- | --- |
| 23:17 | Account help, "Send password reset link" | Request made; email arrived in the same minute | `RESET2_request_app.png`, `RESET2_inbox.png` |
| 23:18 | Tapped "Reset password" in the email (app open in the background: Tan to confirm) | App opened on "Choose a new password", both fields have an eye button | `RECOVERY_choose_password.png` |
| 23:19 | Different confirmation (dummy text, shown with the eye) | "Passwords do not match." | `RECOVERY_mismatch.png` |
| 23:19 | `abc` in both fields | "Use at least 8 characters." | `RECOVERY_short.png` |
| 23:22 | Valid new password saved | App opened the Beginner guide, step 1 of 5 (signed in) | `RECOVERY2_success_beginner_guide.png` |
| 23:22 | Sign in with the old password | "The email or password is incorrect. Try again." | `RECOVERY2_old_password_fails.png` |
| 23:22 | Sign in with the new password | Signed in, Today | `RECOVERY2_new_password_works.png` |

## Observations

- The `same_password` case shows a raw error code. It is safe (no private detail) but not friendly. Candidate defect D20 (Minor, for Lim).
- The 20:15 build had no show/hide buttons on the reset screen (candidate D21). Fixed on the final build with the shared PasswordField (second run), pending Lim's agreement.
- D19 (Minor, open): the "If this email has an account, a reset link will arrive shortly..." notice from Account help is still shown on the "Choose a new password" screen.
- After the new password was saved, the app showed the Beginner guide again (step 1 of 5) instead of Today. Not yet judged; check with Lim whether this is by design.
- Used link: the app did not crash and did not show the new-password screen, but the session was already signed in, so this does not show how a used link behaves for a signed-out user.
- Default Supabase email template, no Balance branding.

## Not tested

- Expired link (needs a link older than its expiry).
- Used link while signed out.

## Acceptance

- Line 38 (signup, resend, reset flows on a real device): supported by Parts A, B and C.
- Line 39 (recovery with app open and closed, expired links, wrong and new passwords): wrong and new passwords shown; open/closed and expired not complete. Leave unticked until done or agreed with Lim.
