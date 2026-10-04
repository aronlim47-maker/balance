# MVP3: Lim's Council comparison integration

## Delivered scope

This increment integrates explanation and comparison around the existing
deterministic generator. It does not change Matthew's recommendation algorithm,
introduce forecasts, or claim that the whole MVP3 roadmap is complete.

The generator can supply up to three alternatives, each moving **one task**.
When more than one exists, Council exposes **Compare plans**. The comparison
sheet shows each move, affected dates, planned minutes before/after, available
minutes and capacity/deadline gaps before/after. Selecting an option only changes
the selection; it does not call a write API.

## Preview calculation contract

`previewTradeOff` is a pure explanation adapter for the current confirm RPC:

1. Locate exactly one original task and check that the proposed minute count is
   positive, within remaining work, matches destination duration and precedes
   the task deadline. Fixed, protected, inactive or mismatched tasks are rejected.
2. Simulate reduced remaining work at the original scheduled start. If no work
   remains, remove that original schedule in the simulation only.
3. Add one proposed reservation at the destination while retaining all existing
   reservations, availability, other tasks and recovery slots.
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
- Closing the sheet does nothing. Only **Confirm this move** invokes confirmation.
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

Local verification on 4 October 2026: Flutter analysis reported no issues and
all 185 tests passed. This does not prove the remote or device gates below.

- [ ] Real Supabase Confirm/Undo for each available alternative, including conflicts.
- [ ] Real-device small-screen, large-text and final-preview cancellation acceptance.
- [ ] Matthew's multi-task/more advanced recommendation contract and evaluation.
- [ ] Chong's consent, feedback/audit and retention interfaces where new personalized
  features require them; Tan's opt-in/reject/correct/disable experience.
- [ ] Approved cross-platform release acceptance.

No new migration is needed for this comparison adapter. Do not mark personalized
recommendations, workload forecasting or the full MVP3 release complete from this
increment's local tests.
