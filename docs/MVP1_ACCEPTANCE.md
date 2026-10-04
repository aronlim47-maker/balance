# MVP 1 acceptance and judge walkthrough

本文件记录第一版个人功能的验收入口。开发者和 AI 必须根据真实测试结果勾选，
不能用源码存在、模拟数据或本地单元测试代替 Supabase 和真机验收。

## Implemented personal scope

- [x] Account signup, sign in and sign out with safe English error messages.
- [x] Account help for password recovery and verification resend.
- [x] Recovery page guarded by Supabase's verified passwordRecovery event.
- [x] Quest create/edit, explicit category, search/filter/date range/sort.
- [x] Today availability, Daily Review, task detail and confirmed move visibility.
- [x] Five-dimension World Status with Unknown/Partial rather than invented data.
- [x] Council safe Confirm/Undo, protected commitments and private plan history.
- [x] Sanctuary recovery and recorded exercise/social inputs.
- [x] Journey personal achievements, captured weekly history and private reflections.
- [x] Team Coordination remains locked pending genuine V2 collaboration evidence.

These marks describe implementation, not final production sign-off. Native email
delivery and database behavior still require the tests below. Durable offline
sync, multi-task Council proposals and the fuller weekly visualization remain
separate backlog items; existing Council can propose a feasible single-task move
and otherwise explains why no feasible plan is available.

## Required remote and device evidence

- [ ] Apply only unapplied migrations in README order; rehearse clean install and upgrade.
- [ ] Verify create_social_event_once and active planning occupancy against real tables.
- [ ] Two Auth users cannot read or change each other's tasks, plans, reviews or awards.
- [ ] Duplicate/uncertain requests and concurrent Confirm/Undo keep consistent records.
- [x] Mobile redirect allowlist configured with the exact approved callback.
- [ ] Signup/resend/reset email flows verified on a real device.
- [ ] Recovery tested with app open/closed, expired links and wrong/new passwords.
- [ ] Profile time zone matches device; Today and Profile show matching recorded scores.
- [ ] Real device full journey passes; English labels, text size and keyboard are usable.
- [ ] Release signing and permanent application ID selected for final distribution.
- [ ] GitHub checks pass for the exact submitted commit.

## Judge walkthrough

1. Install the configured build and sign in to a prepared account. Profile must
   show the cloud account, not Preview user. Set the planning time zone.
2. Create or inspect tasks in Quests. Use category/search filters, open a task,
   and explain that protection prevents automatic rescheduling.
3. In Today, inspect available and planned time, task details and five dimensions.
   Add an optional Daily Review. Missing input remains Unknown; this is a planning
   estimate, not a medical assessment.
4. Use the README two-day overload fixture. Compare the Council suggestion, confirm,
   check the destination in Today, reopen Plan history, then undo. If current data
   makes a move unsafe, show the explanation and add realistic availability or seek
   an agreed task change instead of overriding protected commitments.
5. In Sanctuary, record protected recovery and exercise/social information.
   Refresh Journey and inspect awards supported by actual recorded actions.
6. Save a reflection and reopen it from View my reflections. Weekly history needs
   days actually captured when the app was used; do not invent missing past scores.
7. Sign out and verify private data is inaccessible. Repeat with the second account.

## Evidence log

4 October local verification: Flutter analysis passed and all 166 tests passed.
The configured Android test APK built successfully at
`build/app/outputs/flutter-apk/app-release.apk` (54.6 MB reported by Flutter).
This build still uses the existing debug signing configuration and is for internal
device testing. No iOS build or actual email delivery test was performed.

Dashboard verification on 4 October: the target project reported Healthy.
After Lim's approval, the agent added `com.balance.app://auth-callback/` to
Authentication Redirect URLs and verified the saved list displayed that exact
address with Total URLs 1. Site URL remains `http://localhost:3000`; mobile
requests explicitly supply the approved callback. Real email delivery and device
link tests remain pending. Dashboard health does not establish migration or RLS
test success.

Record the commit hash, migration list actually applied, device/OS, build command,
test date and result. Capture failure messages without passwords, tokens or keys.
Use `20261003_FIX_AND_DATABASE_HANDOFF.md` for the SQL and retry contracts. Final
MVP 1 completion requires closing the remote/device gates above.
