# Balance Building sprint plan

Target: submit a stable source repository by **11 October 2026, Malaysia time**. The exact hour still needs confirmation. Versions 1–4 are a stretch target. Only a version that passes its gate may enter the judged build. This plan supersedes the earlier daily ownership table; completed Supabase/auth groundwork is not reassigned.

## Current ownership

| Owner | Main delivery | Required handoff |
| --- | --- | --- |
| Lim Ze Heng | Auth and app integration, War Council, Confirm/Undo UI, Journey achievement cards, confirmed-plan event handoff, Android release | Pass confirmed action IDs and outcomes to Chong; integrate Matthew's rule results and Tan's screens. |
| Tan Yi Ming | Quest Board, required task category, old-task Needs Review, Sanctuary, exercise/social confirmation screens, English UX and accessibility | Pass the exact form payloads to Chong and the category semantics to Matthew. |
| Chong Zhi Xuan | Additive SQL migration, RLS, repositories, World Status snapshots, weekly Journey queries, trusted event and achievement persistence | Verify a clean database, upgrade of existing records, owner isolation and retry deduplication; publish repository contracts. |
| Matthew Thien Yung En | Today Review, availability, five-dimension calculator/trend, seven achievement eligibility rules, test evidence | Give Chong deterministic eligibility rules and fixtures; lead WS01–WS14 and full-journey tests. |

## Daily handoffs

| Target date | Lim Ze Heng | Tan Yi Ming | Chong Zhi Xuan | Matthew Thien Yung En |
| --- | --- | --- | --- | --- |
| 27 Sep | Finish War Council integration audit; list event IDs available after Confirm/Undo. | Finalize category choices and old-task Needs Review UX. | Review new additive SQL against current migrations; identify data and RLS contracts. | Freeze World Status formula fixture and achievement eligibility cases. |
| 28 Sep | Integrate category model/navigation without disturbing Confirm/Undo. | Implement task category create/edit validation. | Test the additive migration on a fresh and existing database; create repository interfaces. | Implement five-dimension pure calculator and Unknown/Partial behavior. |
| 29 Sep | Build Journey achievement card shell and locked states. | Finish category UI and begin exercise/social confirmation forms. | Implement settings, exercise/social and snapshot repositories. | Implement trend, Today inputs and WS01–WS14 domain tests. |
| 30 Sep | Connect plan confirmation and recovery event handoff with stable IDs. | Finish exercise/social input, cancellation and linked-task UX. | Implement trusted snapshot writer and owner-isolated reads. | Verify Today/World Status English explanations on emulator. |
| 1 Oct | Integrate achievement cards with real read API; no optimistic Unlocked state. | Finish Sanctuary and reflection entry UX; test loading/error states. | Implement planning event and award storage with idempotent retries. | Implement seven eligibility predicates and positive/negative tests. |
| 2 Oct | Run end-to-end Confirm/Undo, snapshot and award flow; fix integration defects. | Test Quest/Sanctuary/activity entries on mobile and accessibility. | Finish weekly Journey query and cross-user RLS checks. | Run full scenario fixture and achievement evidence tests. |
| 3 Oct V1 gate | Produce installable Android candidate and merge only passing V1 features. | Capture English V1 screens and usability issues. | Verify migrations, RLS, trusted writes and old-row compatibility. | Lead V1 regression and record failed cases. |
| 4–5 Oct V2 | Integrate collaboration screens and real Needs Agreement event handoff. | Build shared-task invitation/agreement UX. | Add participant/invitation schema and least-privilege access. | Validate agreement rules and Team Coordination eligibility on genuine shared tasks. |
| 6 Oct V2 gate | Review V2 build and release evidence. | Test permissions, denial states and Journey UI. | Verify upgrade and sharing isolation; test award once only. | Lead V2 collaboration/security regression. |
| 7–8 Oct V3 | Integrate only explainable, reversible recommendation features. | Build opt-in/reject/correct/disable UX. | Add consent, retention and audit storage. | Define and evaluate Calamity/recommendation rules and limits. |
| 8 Oct V3 gate | Keep strongest stable release candidate. | Verify optional UX and user control. | Verify withdrawal and privacy behavior. | Test explanation, fairness, resilience and baseline comparison. |
| 9–10 Oct V4 | Integrate authorised web/platform work only when dependencies exist; prepare release. | Validate demand, privacy boundaries, responsive UX and accessibility. | Add approved organisation/role/aggregation storage and security checks. | Validate institutional cases, role separation and recovery tests. |
| 10 Oct freeze | Sign release build and record rollback notes. | Capture judge journey/screenshots. | Verify production migration, judge account and deterministic demo data. | Run final tests on two Android devices and close critical defects. |
| 11 Oct submission | Submit repository link before organiser cutoff; archive evidence. | Verify judge guide and English flow. | Recheck isolation and database restore notes. | Sign off test log and disclose remaining limitations. |

## Gates and constraints

- **3 Oct repair update:** The compile regression is fixed locally. Destination-day moved-task display, overdue task picker, refresh warnings, snapshot refresh, paginated reads, retry-safe input, plan history and reflection history are implemented. Chong must review/rehearse the two `20261003` migrations and run the corrected rollback-only security/occupancy scripts. These new migrations have not been executed remotely in this update. See `docs/20261003_FIX_AND_DATABASE_HANDOFF.md`; prior unchecked release/security gates remain unchecked.

- **V1:** Personal tasks, five-dimension World Status, safe planning, Sanctuary and private weekly Journey work with real data. All seven achievement cards and conditions are displayed. Six personal achievements can unlock when their evidence exists. Team Coordination stays Locked until V2 real shared-task evidence exists.
- **V2:** Shared tasks and Needs Agreement work with correct permissions. Team Coordination becomes unlockable only from a verified shared-task event. Repeated taps or two devices still produce one award.
- **V3:** Recommendations require opt-in, explanations, user control and a tested rules baseline. Predictive behavior is included only after evaluation.
- **V4:** Organisation, platform and external integration work requires real accounts, consent, security evidence and passing tests. No mocked external success is marked complete.
- **SQL staging:** `202609270001_world_status_achievements.sql` is additive. It does not calculate scores or grant awards by itself. `tasks.load_category` remains nullable so the current client and old rows keep working. Tan ships required category input, then Chong adds a separate enforcement migration for new inserts. Do not convert old NULL values to Other.
- **27 Sep integration update:** The local Flutter code now includes Sanctuary recovery slots, Profile/Today World Status parity, social conflict calculation, weekly Journey history, reflection entry and six personal achievement paths. `202609270002_verified_progress.sql` adds server-derived daily snapshots and trusted, idempotent personal awards. Its SQL grammar and function bodies were parsed locally. This is **not** a completed release gate: migration 002 still needs execution on the real project, a clean database rehearsal, two-account RLS tests and device end-to-end checks. Team Coordination remains a V2 task.
- **Review rule:** A checked box means implemented, reviewed and supported by test evidence. Each owner reports finished work, evidence, blocker and next action. Lim records merge decisions. Do not apply the new migration to production merely because it exists in the repository.
