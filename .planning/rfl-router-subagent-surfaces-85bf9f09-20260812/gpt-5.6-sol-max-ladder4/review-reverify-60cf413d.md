# RFL Ladder 4 — GPT-5.6 Sol Max — RE-VERIFY on `60cf413d…` — PARENT ACCEPT

**Reviewer:** GPT-5.6 Sol Max (`sb-gpt-5-6-sol-max` / [`9886413d-5f6c-4b07-80fe-07337d0afd44`](9886413d-5f6c-4b07-80fe-07337d0afd44)). Review-only at review time. No nested Task. No Fast. No edits, commit, or checkout.
**Branch:** `main`
**Frozen SHA-256 at re-verify:** `60cf413ddac0cbcb80073e776dd0f6d9d56302002d3a2019a682fbb5060410de`
**Parent ACCEPT (round-28):** H-1 / H-2 / H-3 incorporated. Round-27 FAST/row-40 residue landed. Max **not** re-launched. No commit.

**Hash gate: PASS.** Both plan copies hashed to `60cf413ddac0cbcb80073e776dd0f6d9d56302002d3a2019a682fbb5060410de` at review time. Branch `main`, untouched during review.

**Round-27 landed check: PASS.** FAST AM skip / row 40 Advisor re-compose + composition-Val + plan-time Val re-bind + `definition_closure_hash` / `composition_generation` on replacement admission. KEEP REJECT honored (in-plan Executor mint; row 40 re-bind; `prompt_hash` inner-only; `worktree_cwd` / `remaining_depth` envelope metadata).

## Blockers

None.

## High (accepted)

### H-1 — `launch_intent` must carry closure identity

Authorizer-admitted `launch_intent` **requires** `definition_closure_hash` and `composition_generation` (same stamps row 40 recovery already names). Omit → not admitted (`blocked_launch_prompt_spec`, row 4). Surgical at ~L433, ~L592, and the admission envelope list.

### H-2 — Closure hash is recursive over nested WFs

`definition_closure_hash` covers the **root WF + every recursively referenced Workflow definition + their AFs**, not only root WF + AFs. Nested WF mint of a pre-existing catalog WF is already in the closure; Advisor re-compose that adds a WF **changes** the hash (row 40 path).

### H-3 — `context_refs` must be snapshotted or hashed

Mutable `context_refs` **content** cannot change under an unchanged work-spec / launch identity. Hash job-relevant K/L / work-spec-cited refs into sibling `context_refs_hash` on `launch_intent` (do **not** hash live agentmemory dumps) **and** snapshot at admit; consume / nested-Task compare. Stale/mutated ref content with the same identity → row 4.

## Mediums

None.

VERDICT: NOT CLEAN

Parent ACCEPT 2026-08-16 (round-28): H-1 / H-2 / H-3 incorporated. Mid-write SHA `5463fc192eed0cc601d1406536f628ad7e8f8c0b3e182f7a57c5d249b21c6e27` (GPT Highs only). Round-28 **final** SHA after Opus Extra High H-1/H-2/M-1: `aa3677a5531797f59465a1370b1909fb5c696a42067546b3b4f99f3ac4c5b30c`. Max not re-launched.
