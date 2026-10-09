# World Status formula sheet — `world_status_v1` (WL02)

Owner: Matthew Thien Yung En. Status: **drafted from `lib/domain/usecases/world_status_calculator.dart`; the team still has to confirm it** (WL02: "The team confirms the formula sheet").
It is a planning indicator, not a health or stress assessment. Every score is 0–100 where **higher = more planning pressure**.

Stable keys: `mental`, `time`, `physical`, `social`, `errands`. Weights in the total: Mental .25, Time .30, Physical .15, Social .15, Errands .15.

Rules shared by all dimensions
- Unknown is not zero. A component without data is skipped and its weight is removed from the denominator; if too little weight is known the whole dimension is Unknown (shown as "No data", never 0).
- A dimension built from only some of its components is marked Partial.
- A recorded zero (for example 0 Errand minutes with every task categorised) is a real 0.
- Scores are capped to 0–100. Unit: points (not minutes, not percent of health).
- Time window: "now" = `windowStart`; "due soon" = due within 48 hours of it; Physical uses local calendar days; Social uses the current week.

| Key | English name | Plain meaning | Measured / self-reported | Missing-value rule |
|---|---|---|---|---|
| mental | Mental | How mentally loaded the plan is | Mixed: energy rating is self-reported; tasks, minutes and recovery are measured from app data | Needs ≥ 50% of component weight known, otherwise Unknown |
| time | Time | Whether planned work fits the time available | Measured (planned and available minutes, deadlines) | Unknown when availability is missing; needs ≥ 50% known weight |
| physical | Physical | How long since recorded movement, plus reported physical energy | Mixed: confirmed exercise date is recorded; physical energy is self-reported | Unknown unless movement tracking is on and an exercise date exists; needs ≥ 70% known weight (the days-since component alone, 70%, is enough) |
| social | Social | Pressure from social events this week and their clashes with other commitments | Self-reported (event pressure) + measured (overlap minutes) | Unknown until an event is added or "no social commitments" is confirmed |
| errands | Errands | Remaining Errand-category work relative to time available | Measured from task categories and minutes | Unknown if tasks are not loaded or any unfinished task has no category; needs ≥ 60% known weight |

## Components (weights are relative; unknown ones are dropped and the rest are re-normalised)

**Mental** = .30 Daily Review energy · .25 Tasks and deadlines · .25 Capacity pressure · .20 Protected recovery
**Time** = .50 Capacity gap · .25 Deadlines within 48 h · .10 Unfinished task count · .15 Protected recovery
**Physical** = .70 Days since recorded exercise · .30 Daily Review physical energy
**Social** = .70 event pressure · .30 schedule conflicts
**Errands** = .60 Remaining Errand minutes · .25 Errands due within 48 h · .15 Unfinished Errand count

Component formulas (all capped to 0–100)
- Energy pressure: Low energy = 80, Moderate = 50, High = 20; no rating = unknown.
- Task count pressure = unfinished tasks / 8 × 100 (8-task reference scale).
- Deadline pressure = minutes due within 48 h / max(planned minutes, 1) × 100.
- Tasks and deadlines (Mental) = average of count pressure and deadline pressure.
- Capacity pressure = max(0, planned − available) / max(available, 1) × 100; available 0 with planned > 0 = 100.
- Recovery deficit = (target − protected recovery minutes) / target × 100; target 0 = 0. Default target 30 min (0–240).
- Days since exercise = max(0, days since last confirmed exercise − target interval) / 4 × 100. Default interval 3 days (1–14).
- Social load = Σ(minutes × pressure value) / (weekly target minutes × 80) × 100, default target 300 min/week; conflict = overlapping minutes / total event minutes × 100.
- Errand minutes = Errand minutes / max(available, 1) × 100; Errands due soon = due-soon Errand minutes / Errand minutes × 100; Errand count = Errand tasks / 8 × 100.

## Total, label, trend
- Total = Σ(dimension × weight) / Σ(weight of known dimensions), rounded. **Needs known weight ≥ 60%, otherwise no total** (shown as No data). Partial when any dimension is missing or partial.
- Labels: Low < 25, Building < 50, High < 75, Over capacity ≥ 75.
- Fixed example: 63 / 63 / 59 / 18 / 49 → total 53 "High" (test WS in `world_status_calculator_test.dart`).

### Cumulative trend (WL05)
- What accumulates: the daily total score (0–100 points).
- Window: 7 local calendar days ending on the selected day, inclusive. Dates are local dates, no time-zone shifting.
- Aggregation: **cumulative load** = sum of known daily totals in the window; **average** = that sum / number of days with a known total. Days without a total are excluded from both and are reported as "N days have no data and are left out of the average" — they are never counted as 0 and never read as improving.
- Direction: today's total vs the mean of the previous 7 known totals; > +5 Rising, < −5 Easing, otherwise Stable; fewer than 3 known earlier totals = "Not enough history".
- Reset: none; it is a rolling window. The window moves with the selected day.
- Code: `WorldTrendCalculator` (`lib/domain/usecases/world_trend_calculator.dart`), shown by `WorldTrendPanel` on the Today screen.

## Mapping of existing fields (candidates only — not renamed, not yet approved as sources)
`mental`, `physical`, `social`, `errands` and `sleepHours` columns from the old schema are **not** read by `world_status_v1`; it computes from tasks, availability, recovery slots, confirmed exercise and social events. Their semantics have not been checked, so they stay unmapped until the team decides.
