# 3 October integration fixes and Chong's database handoff

This file supersedes conflicting early-draft status in ZHI_XUAN_DATA_HANDOFF.md.
It is not evidence that new SQL has executed remotely or that V1–V4 are complete.

## 本轮交付说明

本次提交以当前 LZH 已合并的 master 为基础，交付客户端修复、个人历史入口、
数据库增量迁移、回归测试和持续检查配置。本文是本轮实现状态与数据库交接的
权威更新；既有设计指南的产品需求继续有效，不能把本次修复解释为所有版本已完成。

给后续开发者和 AI 的执行要求：先阅读本文的迁移依赖，再核对实际数据库已应用的
迁移记录。只执行未应用的迁移；不得重置数据、重复执行旧迁移、绕过 RLS 或将
service-role 密钥放入客户端。SQL 语法检查通过不代表数据库运行、安全隔离或并发
测试通过。先在临时项目演练，再更新目标数据库，最后分发新客户端。

用户可通过 Council 的历史入口查看已确认或撤销的计划，通过 Journey 查看自己的
反思记录。历史页面必须按登录用户读取数据；撤销必须继续经过服务器验证。
保存成功但刷新失败时，界面保留明确提示，不得假装已刷新，也不得诱导用户重复保存。

验收分为三层：本地分析与 152 项测试已通过；数据库运行和双账号隔离验证仍待完成；
APK 发布、GitHub 检查结果及真实设备端到端测试需另行记录。Git 提交和推送结果以
仓库记录为准，不属于上述测试证据。

## Implemented locally

- Fix the duplicated LifecycleNotifier merge declaration.
- Include confirmed moved-task reservations in Today's destination-day list;
  display Council times in task details. Completed/cancelled tasks remain hidden.
- Allow the date picker to open for overdue tasks.
- Keep existing rows visible when refresh fails, with a visible English error.
- Add Go to today and reset the selected date when Council returns to Today.
- Capture server-derived history after Daily Review and availability changes.
  A failed history refresh is a warning after a successful save, not save failure.
- Add Plan history to reopen confirmed/undone plans; the existing server checks
  remain the authority for Undo. No history deletion or forced undo is added.
- Add private reflection history in Journey.
- Paginate active task, availability, recovery, plan, exercise and social reads
  in deterministic order until an empty page. Short pages are not assumed final.
  Stop at 10,000 rows with an error rather than silently returning partial data.
- Add retry-safe exercise/reflection inserts and atomic social-event RPC.
  The same input retries with its retained request ID after an uncertain response.
  After confirmed success an intentional identical new record receives a new ID.
  This retention is IN MEMORY for the service/session, not durable offline sync;
  reopening the app cannot recover an unconfirmed request ID yet.
- Verify exercise/social deletion actually returned a deleted row.
- Add a GitHub check workflow pinned to local Flutter 3.47.2/Dart 3.13.2.
  It is prepared, not yet run on GitHub. It does not receive Supabase secrets.

## Migration dependencies — Chong

Apply only unapplied files, in filename order, after a disposable-project rehearsal.
Do not rerun historical migrations against an existing database.

1. Existing migrations through `202610020001_recovery_history.sql`.
2. `202610020002_planning_adapter_compatibility.sql`: nullable request IDs and
   owner/request uniqueness for raw exercise, social and reflection records.
3. NEW `202610030001_active_planning_occupancy.sql`: replace five functions,
   preserving their signatures, locks, security attributes, grants and safety
   rules. Only planned tasks contribute live moved-work conflicts. Historic
   plan/item rows remain available for audit. Editing a completed task back to
   planned still checks its own confirmed moved-work deadline against NEW data.
4. NEW `202610030002_retry_safe_social_event.sql`: new `create_social_event_once`
   RPC. It uses owner/request locking, returns a matching prior record on retry,
   rejects different payloads with the same ID, validates the week using profile
   time zone, and atomically saves the event, weekly response and request ID.
   The original RPC stays available to old clients. No unsafe client fallback.

Deploy these migrations BEFORE distributing this updated client. Until the new
social RPC exists, the app displays the database-upgrade error and does not save
via separate writes. `.env` and service-role credentials must not enter commits.

## Database tests — not executed remotely in this change

Use a DISPOSABLE database and fresh Auth-created users. The psql test scripts are
not directly pasteable into Dashboard SQL Editor: they have psql variable commands.
Use `ON_ERROR_STOP=1`. Both scripts wrap fixtures in a transaction and roll back.

- `supabase/tests/world_status_achievements.sql`: corrected source_key,
  achievement_v1, valid event type and required exercise source. Tests owner
  isolation, cross-owner linking, client-write denial and request uniqueness.
- `supabase/tests/active_planning_and_retry.sql`: active moved work blocks task
  and recovery collisions; completed AND cancelled work releases its time;
  historical moves no longer block availability deletion/replacement; new
  confirm/undo restores the baseline; social retries return one record and
  reject a reused ID with changed input.
- `tools/validate_sql.py` checks SQL, PL/pgSQL functions and DO bodies only.
  Syntax passing cannot prove runtime table resolution, RLS or concurrency.

Before sign-off, Chong must attach clean-install and legacy-upgrade results,
the two-account test output, and concurrent two-client retry/Confirm/Undo evidence.
Also test social writes with profiles.time_zone matching the device; arbitrary
device/profile timezone differences are not supported end-to-end yet.

## Local verification evidence

- `flutter analyze --no-pub`: No issues found.
- `flutter test --no-pub`: all 152 tests passed (142 before this repair batch).
- pglast 8.4 accepted all 10 migration files and both database test scripts,
  including SQL, PL/pgSQL function bodies and DO blocks.
- `git diff --check`: passed. Historical migration files were not edited.
- No remote database execution, live two-account RLS test, APK release build,
  GitHub workflow execution, commit or push is claimed by these results.

## Remaining implementation and release work

- Require category on new inserts only after agreeing legacy-client support.
- Durable cross-restart retry/outbox and concurrent pagination snapshot consistency.
- Multi-task Council proposals and recovery creation integrated into one plan UI.
- Password reset/resend and guarded mobile callbacks are implemented in the
  4 October update; redirect allowlist, email delivery and real-device link tests
  remain pending. See README and MVP1_ACCEPTANCE.md.
- Full Journey sleep/weekly planned-vs-available metrics and explainable patterns.
- Real-account/two-device E2E, fresh/upgrade APK tests, performance profiling.
- Permanent Android application ID and private release signing (owner decisions).
- V2 real collaboration, V3 evaluated opt-in recommendations, V4 organisation
  features: these are separate implementation gates, not fixed by this patch.

## Ownership

Lim integrates/reviews the client and Council history. Chong reviews the new SQL,
deploys only after rehearsal, and records security/runtime evidence. Matthew
verifies history/formula parity and Today behavior. Tan validates task forms,
activity flows and English small-screen UX. This help does not remove Chong's
database sign-off responsibility.
