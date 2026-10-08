# MVP3: Lim's Council comparison integration

## Delivered scope

This increment integrates explanation and comparison around a deterministic
rules-based generator. It does not introduce forecasts or claim that the whole
MVP3 roadmap is complete.

The generator supplies up to three single-task alternatives when one move can
clear the selected day's overload. If no single-task move can do so, it tries one
bounded combined alternative moving up to three flexible tasks. The combined
planner currently requires each moved task to fit wholly within the source day;
it leaves cross-midnight work to the single-task planner. If it cannot place all
moves in available time before their deadlines while clearing every affected
day, it returns no plan. When more than one option exists, Council exposes
**Compare plans**. The comparison sheet lists each task move and shows affected
dates, planned minutes before/after, available minutes and capacity gaps.
Selecting an option only changes the selection; it does not call a write API.

## Preview calculation contract

`previewTradeOff` is a pure explanation adapter for the current confirm RPC:

1. Locate every original task exactly once and check that task IDs are unique;
   each move must be positive, within remaining work, match destination duration
   and precede that task's deadline. Fixed, protected, inactive or mismatched
   tasks are rejected.
2. Simulate reduced remaining work at each original scheduled start. If no work
   remains, remove that original schedule in the simulation only.
3. Add every proposed reservation while retaining all existing reservations,
   availability, other tasks and recovery slots. Reject overlapping proposed
   placements, occupied time, blocked time or time outside availability.
4. Use the existing DailyCapacity calculator on the selected source date and
   every date touched by the original and destination intervals. Do not assume
   moved minutes equal source-day relief for cross-midnight work.
5. Display the calculated before/after values. Reject unresolved affected-day
   overload and agreement-dependent work from final confirmation.

The adapter is not an independent complete schedule validator. It uses options
from the existing validated generator; the live RPC remains authoritative for
ownership, current data, collisions, deadlines, protection and transaction safety.
No predicted stress reduction or fabricated recovery benefit is displayed.

## User-controlled confirmation

- **Confirm selected plan** first opens a final, scrollable preview sheet.
- Closing the sheet does nothing. Only **Confirm this move(s)** invokes confirmation.
- Protected tasks/recovery and unchanged deadlines are explained explicitly.
- The destination receives work; total work is not reduced. No new recovery slot
  is created by this flow.
- Capture the option ID, review revision and selected source date before opening
  the sheet. Loading again, selecting a different option or changing date makes
  the captured review stale. A stale review must not write and instead asks the
  user to refresh and review again.
- The server capacity evidence is bound to the actual checked date, not merely
  a matching numerical overload. A changed date cannot reuse the old evidence.
- Confirmation and Undo continue using the existing real RPC/change ID and plan
  result/history screens. A preview is never described as a confirmed plan.
- Concurrent remote edits still require RPC validation; the local revision token
  is not a substitute for server authorization or conflict checking.

## Verification and remaining gates

Tests cover immutable before/after simulation, protection/agreement rejection,
invalid moves, destination overload, comparison selection, disabled unsafe final
confirmation, stale-review rejection and date-bound server evidence.

Current Matthew handoff: the World Status calculator and Unknown/Partial handling
are implemented in the domain layer. Council now has a deterministic multi-task
fallback, per-move capacity/occupancy preview, and submits all moves through the
existing atomic, version-checked RPC. Unit coverage includes a case where two
60-minute tasks must both move to clear a 120-minute overload, confirmation sends
both moves, protected work is not selected, and destination capacity is enforced.
This is a bounded heuristic—not a predictive/AI recommendation system. Its quality
evaluation across broader calendars and priorities remains open. The new database
achievement cases are syntax-checked but still need a rollback-only remote rerun.

8 October follow-up: the comparison now states a concise reason when an option is
feasible or cannot be confirmed, using the preview's capacity issue when present
and explicitly naming the agreement requirement when applicable. Local analysis
and focused comparison/Council tests pass. The broader quality-review checkbox
below remains open until realistic-calendar review is documented.

Local verification on 7 October 2026: Flutter analysis reported no issues; all
204 tests passed, including combined generation, per-move preview, collision
rejection and repository confirmation with two moves. The configured Android
release APK rebuilt successfully (56.2 MB; internal testing only because it uses
debug signing). SQL syntax checks pass, but the new combined Confirm/Undo and
achievement cases still need their rollback-only remote run. This does not prove
the remote or device gates below.

- [ ] Real Supabase Confirm/Undo for each available alternative, including conflicts.
- [ ] Real-device small-screen, large-text and final-preview cancellation acceptance.
- [ ] Evaluate recommendation quality across realistic multi-task calendars and
  confirm the user-facing reasons remain accurate on devices.
- [ ] Chong's consent, feedback/audit and retention interfaces where new personalized
  features require them; Tan's opt-in/reject/correct/disable experience.
- [ ] Approved cross-platform release acceptance.

No new migration is needed for this comparison adapter. Do not mark personalized
recommendations, workload forecasting or the full MVP3 release complete from this
increment's local tests.
