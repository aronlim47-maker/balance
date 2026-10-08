# No deadline — proposed contract, pending team decision

Owner: Chong; coordinated changes needed from Tan (forms) and Lim (Council/app).
Status: proposal only. No due_at schema change is included in the WS11 delivery.

## Recommendation

Use nullable `due_at` as the single source of truth, rather than a sentinel future
date or a second has_deadline flag that can disagree with due_at. A scheduled
interval is not a deadline. Do not silently infer a due date from scheduled_end.
Recommend deferring from the current judged build unless the following complete
change can be reviewed and validated together. This is a recommendation, not a
recorded team approval.

## Required coordinated behavior

- Additive migration drops due_at NOT NULL. Retain scheduled interval consistency;
  deadline comparison is explicit: due_at IS NULL OR scheduled_end <= due_at.
- TaskItem.dueAt becomes nullable. Mapper handles JSON NULL. Updates must explicitly
  send due_at:null when the user clears a deadline, rather than omitting the key.
- Unscheduled, undated work is backlog, not silently assigned to today. Scheduled
  undated work still occupies its actual interval. Completion/cancellation still
  releases active occupancy.
- The 48-hour and overdue calculations exclude undated tasks. General unfinished
  task counts may include them under the approved formula; confirm with Matthew.
- Council can move scheduled undated work within availability and protection rules;
  cannot choose a source day for unscheduled backlog without explicit scheduling.
  Deadline Safety and Early Review require a real deadline and must not unlock for
  undated work. Version checks, locks, rollback and Undo rules remain mandatory.
- Update every server function reading due_at, including capture_world_status,
  calculate_day_overload, confirm_plan_change and achievement evaluation, together
  with Dart daily_capacity/generate_trade_offs/world_status_calculator.
- Tan adds a No deadline toggle and clear date rendering, search/sort/filter rules,
  notification cancellation on clearing a deadline and calendar-day handling.
- Old app versions cannot parse NULL due_at: rollout must prevent incompatible
  clients from reading new undated tasks before the client upgrade is available.

## Acceptance before deployment

Known/unknown deadlines × scheduled/unscheduled × planned/completed/cancelled;
clear and restore deadline; invalid schedule end; legacy row upgrade; mapper/UI
roundtrip; overdue/48-hour boundaries; capacity and formula parity; Council
Confirm/Undo with stale versions; no false Deadline Safety/Early Review awards;
reminders and time zones. Run both SQL and application tests on a disposable
project before any shared-project migration.

Until accepted, current required-deadline behavior is an explicit limitation in
the judge guide. Do not advertise No deadline or fabricate a distant deadline.
