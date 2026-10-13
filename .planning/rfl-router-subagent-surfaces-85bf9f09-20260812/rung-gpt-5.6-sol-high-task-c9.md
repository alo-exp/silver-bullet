# RFL Rung 4 — GPT-5.6 Sol High — Cycle 9

Independent adversarial re-verification against repo-plan SHA-256 `c0a9a0990438425c65bf2bb12b8a409cfc62cf56f4510b7aa7b536eafd145a2e`.

## Baseline checks

- Read the product overview, review preamble, full plan, Cycle-8 report, and clarify brief in the required order.
- `cmp` returned exit 0 for the repo plan and `/Users/shafqat/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`; both copies have the SHA-256 above.
- Rechecked the locked P→I→A→V→Val ordering and control-plane exemptions, Authorizer launch admission, migration, Process-synthesis, callbacks, blocker preservation, LPS/WBS/POA traceability, ordinary-versus-Iterate discrimination, and product fit.

## Material findings

1. **The ordinary callback acknowledgment contract drops a fence that the generic channel contract requires.** Line 187 makes `callback fence` part of every authenticated producer/channel identity, before discriminating ordinary delivery from Iterate. Line 192 then places `callback fence` inside the fields bound **only** for `producer_kind=iterate_attempt`. That leaves an ordinary Advisor/Verifier/Validator/Process-synthesis callback commit receipt unable to prove which cancellation/acceptance fence it was accepted under, despite ordinary callbacks being subject to fencing. Make the callback fence generic in callback payload/commit/ack receipts for both producer kinds; keep only Iterate contract-binding/rung/`attempt_id` fields Iterate-only. Add an ordinary-delivery stale-callback-after-cancellation fixture to ING-01/PROD-01.

2. **The early-callback logical key aliases repeated same-kind callbacks from one child/run.** Line 195 keys an early callback by `(token, generation, epoch, callback kind, stable child/run identity)` and treats a later different hash as corruption. The key omits the occurrence identity required by lines 80 and 190 (`source_operation_id` with explicit occurrence ordinal) and also omits channel sequence. A single child that emits two legitimate same-kind callbacks before acknowledgment—such as repeated Advisor rounds—therefore collides and can produce `blocked_corrupt_state` instead of two ordered deliveries. Bind early dedupe to the stable source occurrence identity, or to a prospective channel plus sequence, and add multi-callback-before-ack replay/conflict fixtures to ADM-01/ING-01/PROD-01.

VERDICT: NEEDS_FIXES
