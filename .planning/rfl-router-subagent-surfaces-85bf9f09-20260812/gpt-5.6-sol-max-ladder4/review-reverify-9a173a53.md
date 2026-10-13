# RFL Ladder 4 — GPT-5.6 Sol Max — RE-VERIFY on `9a173a53…` — PARENT ACCEPT

**Reviewer:** GPT-5.6 Sol Max (`sb-gpt-5-6-sol-max` / [`74906da9-cc19-403d-b036-a6eae3e725de`](74906da9-cc19-403d-b036-a6eae3e725de)). Review-only at review time. No nested Task. No Fast. No edits, commit, or checkout.
**Branch:** `main`
**Frozen SHA-256 at re-verify:** `9a173a53f04eec56bc139d1e1ae67f7cdc3c0530a9860f71e6253a67e346e7be`
**Parent ACCEPT (round-30):** H-1 / H-2 / H-3 / M-1 incorporated together with Opus Extra High B-1 / H-1 / H-2 / H-3 / M-1 / M-2. Round-29 landings present. Max **not** re-launched. Extra High **not** re-launched. No commit.

**Hash gate: PASS.** Both plan copies hashed to `9a173a53f04eec56bc139d1e1ae67f7cdc3c0530a9860f71e6253a67e346e7be` at review time. Branch `main`, untouched during review.

**Round-29 landed check: PASS.** Cycle fail-closed (visited-set → row 1); hash recompute/compare; immutable `context_refs` snapshot as child read source; SHA ledger; Opus remint-new-`launch_id`; lock emitter + hand-authored `nested_executor` table; WS3 snapshot + `VAL/TST-RFL-626`. KEEP REJECT honored (`wbs-projector.sh` exclusive packet writer; unlimited **tree** nesting; cycles fail-closed; in-plan Executor mint; row 40 remint new `launch_id`; public `/sb`).

## Blockers

None.

## High (accepted)

### H-1 — Projector writes the snapshot

`orchestrator-admission.sh` must **not** write packet files itself. It **requests** `hooks/lib/wbs-projector.sh` (sole allowlisted packet writer) to persist `$primary_checkout/.planning/packets/<launch_id>/context-refs-snapshot/`. WS3: admission helper + projector; no second writer. Fix ~L48/L457/L738/L762/L764 contradictions.

### H-2 — Tri-color / active-stack cycle detection

A visited-set **terminates** but cannot tell a **back-edge cycle** from **legal shared-node DAG reuse** (diamond). Require DFS **recursion-stack / tri-color**. Fixtures: self-cycle FAIL, mutual-cycle FAIL, shared-DAG (two parents one child WF) PASS. `blocked_corrupt_state` on cycles. Pin VAL/TST.

### H-3 — Remint revokes old Executor authority

New `launch_id` is not enough. **Before** admitting the replacement: revoke the old `launch_id`’s Authorizer-bound lease, capabilities, callbacks, and expected writes/effects (same bind-at-launch model). Conflicting reuse of the old id stays blocked (CORR-17). A still-running old Executor after remint is `blocked_corrupt_state` (row 1).

## Mediums (accepted)

### M-1 — TST-RFL-626 negative fixture

`VAL/TST-RFL-626` must also prove a child **cannot** consume mutable live `context_refs` after admission (only the snapshot). Hash/existence alone is insufficient.

VERDICT: NOT CLEAN

Parent ACCEPT 2026-08-16 (round-30): H-1 / H-2 / H-3 / M-1 incorporated with Opus Extra High B-1 / H-1 / H-2 / H-3 / M-1 / M-2. Round-30 SHA: `c1868fa31a9e424997ae9994376bac5d27e3f6886f74509c4f2717b21f36a93e`. Max not re-launched. Extra High not re-launched.
