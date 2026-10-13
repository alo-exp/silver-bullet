# RFL Ladder 4 — GPT-5.6 Sol Max — RE-VERIFY on `c1868fa3…`

**Reviewer:** GPT-5.6 Sol Max (`sb-gpt-5-6-sol-max`)  
**Branch:** `main`  
**Mode:** review only; no checkout, plan edit, commit, nested Task, or Fast

## Hash gate

**Start: PASS.**

- Repo copy: `c1868fa31a9e424997ae9994376bac5d27e3f6886f74509c4f2717b21f36a93e`
- Cursor copy: `c1868fa31a9e424997ae9994376bac5d27e3f6886f74509c4f2717b21f36a93e`

**End: PASS.**

- Repo copy: `c1868fa31a9e424997ae9994376bac5d27e3f6886f74509c4f2717b21f36a93e`
- Cursor copy: `c1868fa31a9e424997ae9994376bac5d27e3f6886f74509c4f2717b21f36a93e`

## Round-30 landing checks

1. **PASS — Admission requests the projector; admission does not write packet paths.** The operative architecture makes `hooks/lib/wbs-projector.sh` the only WBS/packet writer and says `orchestrator-admission.sh` requests it, with the same ownership in WS3 and the parent-guard acceptance text ([plan L457](../../router_subagent_surfaces_85bf9f09.plan.md#L457), [L592](../../router_subagent_surfaces_85bf9f09.plan.md#L592), [L705](../../router_subagent_surfaces_85bf9f09.plan.md#L705), [L738](../../router_subagent_surfaces_85bf9f09.plan.md#L738), [L762-L764](../../router_subagent_surfaces_85bf9f09.plan.md#L762-L764)).
2. **PASS — DFS tri-color / recursion-stack cycle detection.** The closure definition requires WHITE/GRAY/BLACK semantics, rejects GRAY back-edges, and pins self-cycle FAIL, mutual-cycle FAIL, shared-DAG PASS to `VAL/TST-RFL-615`; the canonical blocker row also names tri-color and shared-DAG acceptance ([plan L263](../../router_subagent_surfaces_85bf9f09.plan.md#L263), [L630](../../router_subagent_surfaces_85bf9f09.plan.md#L630), [L727](../../router_subagent_surfaces_85bf9f09.plan.md#L727)).
3. **FAIL — Remint revocation lands, but the canonical row-1 classifier weakens the still-running-old-Executor clause.** Revocation-before-admit and the unconditional stale-Executor outcome are repeated in the role gate, row 40, WFM-01, and its test family ([plan L251-L253](../../router_subagent_surfaces_85bf9f09.plan.md#L251-L253), [L669](../../router_subagent_surfaces_85bf9f09.plan.md#L669), [L737](../../router_subagent_surfaces_85bf9f09.plan.md#L737), [L859](../../router_subagent_surfaces_85bf9f09.plan.md#L859)); however, the ordered canonical blocker table only matches a still-running old Executor **whose authority was not revoked before replacement admission** ([plan L626-L630](../../router_subagent_surfaces_85bf9f09.plan.md#L626-L630)). This leaves the compliant-revocation-but-process-still-running case without the promised row-1 classification.
4. **PASS — `VAL/TST-RFL-626` negative fixture.** The plan requires the child prompt/receipt to bind snapshot paths and not live `context_refs`, explicitly treating this as cooperative rather than a Read jail ([plan L633](../../router_subagent_surfaces_85bf9f09.plan.md#L633), [L738](../../router_subagent_surfaces_85bf9f09.plan.md#L738), [L855](../../router_subagent_surfaces_85bf9f09.plan.md#L855)).
5. **PASS — `context_refs_hash` stamp/compare lifecycle.** Launcher omission is allowed; admit copies and stamps; pre-admit drift refreshes; post-stamp consumption compares against recomputed durable snapshot bytes ([plan L263](../../router_subagent_surfaces_85bf9f09.plan.md#L263), [L592](../../router_subagent_surfaces_85bf9f09.plan.md#L592), [L633](../../router_subagent_surfaces_85bf9f09.plan.md#L633), [L738](../../router_subagent_surfaces_85bf9f09.plan.md#L738), [L855](../../router_subagent_surfaces_85bf9f09.plan.md#L855)).
6. **PASS — Named lock emitter.** `scripts/generate-router-contract-locks.py` is the lock emitter, appears in the named regeneration command and WS1 sources, and preserves the hand-authored `nested_executor` input table ([plan L175](../../router_subagent_surfaces_85bf9f09.plan.md#L175), [L746](../../router_subagent_surfaces_85bf9f09.plan.md#L746), [L750](../../router_subagent_surfaces_85bf9f09.plan.md#L750)).
7. **PASS — Snapshot stores regular files only.** Symlinks are followed to bytes and not preserved; non-regular, dangling, or looping entries fail closed ([plan L263](../../router_subagent_surfaces_85bf9f09.plan.md#L263), [L592](../../router_subagent_surfaces_85bf9f09.plan.md#L592), [L738](../../router_subagent_surfaces_85bf9f09.plan.md#L738)).
8. **PASS — Snapshot GC follows `launch_id` resumability.** Snapshots survive resumability and GC requires both fence release and child terminality; a missing resumable snapshot fails closed ([plan L263](../../router_subagent_surfaces_85bf9f09.plan.md#L263), [L592](../../router_subagent_surfaces_85bf9f09.plan.md#L592), [L728](../../router_subagent_surfaces_85bf9f09.plan.md#L728), [L738](../../router_subagent_surfaces_85bf9f09.plan.md#L738)).

## KEEP REJECT

**PASS — intact.** The current plan retains:

- `nested_executor` as lock-only with unchanged `additionalProperties: false` catalog schema ([plan L118](../../router_subagent_surfaces_85bf9f09.plan.md#L118), [L541](../../router_subagent_surfaces_85bf9f09.plan.md#L541), [L750-L752](../../router_subagent_surfaces_85bf9f09.plan.md#L750-L752));
- public `sb` / `sb:` / `/sb` only and generated catalog/locks ([plan L175](../../router_subagent_surfaces_85bf9f09.plan.md#L175), [L568](../../router_subagent_surfaces_85bf9f09.plan.md#L568), [L746-L750](../../router_subagent_surfaces_85bf9f09.plan.md#L746-L750));
- unlimited NW **tree** nesting with cycles fail-closed, in-plan Executor mint, and row-40 remint with a new `launch_id` ([plan L122](../../router_subagent_surfaces_85bf9f09.plan.md#L122), [L251-L253](../../router_subagent_surfaces_85bf9f09.plan.md#L251-L253), [L630](../../router_subagent_surfaces_85bf9f09.plan.md#L630), [L669](../../router_subagent_surfaces_85bf9f09.plan.md#L669));
- `wbs-projector.sh` exclusive packet ownership ([plan L457](../../router_subagent_surfaces_85bf9f09.plan.md#L457));
- FAST as classify-and-catalog-dispatch of `AF-FAST-PATH`, not a Job or GST record ([plan L116](../../router_subagent_surfaces_85bf9f09.plan.md#L116), [L259](../../router_subagent_surfaces_85bf9f09.plan.md#L259), [L548](../../router_subagent_surfaces_85bf9f09.plan.md#L548), [L665-L668](../../router_subagent_surfaces_85bf9f09.plan.md#L665-L668));
- Advisor-composed wrapping, Authorizer not Approver, ESC-02 without A, and inner-prompt-only `prompt_hash` ([plan L110-L114](../../router_subagent_surfaces_85bf9f09.plan.md#L110-L114), [L261](../../router_subagent_surfaces_85bf9f09.plan.md#L261), [L592](../../router_subagent_surfaces_85bf9f09.plan.md#L592), [L731](../../router_subagent_surfaces_85bf9f09.plan.md#L731)).

The round-30 clarify addendum states the same lock set without conflict ([clarify L1082-L1126](../../router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md#L1082-L1126)).

## Findings

### High — Canonical row 1 does not classify a still-running old Executor after successful revocation

The plan declares the blocker table ordered and canonical ([plan L626](../../router_subagent_surfaces_85bf9f09.plan.md#L626)). The landing requires two independent protections: revoke all old authority before admitting the replacement, and classify any old Executor that remains running after remint as `blocked_corrupt_state` ([plan L251](../../router_subagent_surfaces_85bf9f09.plan.md#L251), [L669](../../router_subagent_surfaces_85bf9f09.plan.md#L669)). But row 1 combines them into one conditional: it only matches a still-running old Executor **whose authority was not revoked before** replacement admission ([plan L630](../../router_subagent_surfaces_85bf9f09.plan.md#L630)). Under the required successful-revocation path, evidence that the old Executor remains alive no longer matches row 1, contradicting the landing and leaving the stale process without a canonical outcome.

Required correction: make row 1 independently match (a) failure to complete revocation before replacement admission and (b) any evidence that the old Executor remains running after remint, regardless of whether revocation succeeded. Pin both cases in `VAL/TST-RFL-625` / WFM-01.

## Tool note

Graphify orientation completed first. The configured MCP catalog exposed no `agentmemory` server or `memory_save` tool, so a session-note save could not be performed.

VERDICT: NOT CLEAN
