# RFL Ladder 2 — GLM 5.2 Extra High / Max — Architecture Review

**Reviewer:** GLM 5.2 Extra High / Max (this Task rung — `sb-glm-5-2-xhigh`; this family's Max; no separate Medium slug; no distinct Extra High vs Max split)
**Date:** 2026-08-15
**Branch:** `main` (no switch)
**Read order:** [SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md](../SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md) → [router_subagent_surfaces_85bf9f09.plan.md](../../router_subagent_surfaces_85bf9f09.plan.md) (652 lines) → [router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md](../../router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md)
**Plan SHA-256:** `3712dc7731fdaa462ca0079a4c8a1fee53118d8b9c4cf94c478a60b0204a86ec`
**Mirror parity:** `cmp` exit 0 vs `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`; `shasum -a 256` matches on both copies (exit 0)
**Graphify:** `graphify query "router_subagent_surfaces plan: control plane roles, hosts, five-tool stack, Authorizer, Orchestrator, quality loops I A V Val, migration, work spec, WBS"` (orientation; 354-node subgraph, truncated to 43 nodes at ~2000-token budget)
**Prior ladder-2 (not rubber-stamped):** DeepSeek V4 Pro High M2 ACCEPT (bind-failure / `SB_PRIMARY_CHECKOUT`); Max H1 ACCEPT (Cursor extra-trees); MiniMax M3 High/Max CLEAN; Composer 2.5 High CLEAN — parent rejected two doc-only mediums (Val row label; stack-coordinator table omission); Composer 2.5 Extra High NOT CLEAN → parent ACCEPT applied (LeanCTX-opted-in five-tool uses `optimize-five-tool-stack.sh`; `optimize-rtk-context-mode.sh` is RTK+CM-only sub-step). Plan SHA-256 advanced to `3712dc77…`. GLM 5.2 High CLEAN (naming-hole fix verified present and consistent) — not rubber-stamped by this pass.

## Independence statement

This Extra High / Max pass re-read the mandatory overview, the full plan (652 lines, read in three chunks), and the clarify brief, then independently verified against the locked ladder-2 state and the refreshed product overview. Automated and manual checks performed:

- Plan SHA-256 = `3712dc7731fdaa462ca0079a4c8a1fee53118d8b9c4cf94c478a60b0204a86ec` (matches the post-Composer-XHigh-fix locked value); plan↔Cursor-mirror byte-identical (`cmp` exit 0; `shasum -a 256` identical on both copies).
- Blocker enum: 32 ordered table rows (rows 1–32 read directly at lines 420–453); every `blocked_*` ID referenced in the plan body resolves to a table row; historical `blocked_replan_budget` (row 7), `blocked_advisor_state` (row 14), and `blocked_triage_unresolved` (row 15) retained as non-classifying/historical — consistent with the finite 4-step ladder and retired Val-triage.
- Structural integrity: exactly 10 frontmatter todos (read at lines 4–34); single `#` title; single `## Overview` (line 42); single `## Table of contents` (line 52); 17 `##` headings listed in the TOC all appear exactly once in the body (19 `##` total = 17 TOC + Overview + Table of contents); `### Document integrity` is correctly an h3 under Traceability (line 648), not a stray `##`.
- Zero `poa_draft` / executor-draft P-loop residue (Advisor-first one-way planning throughout; `advisor_planning` / `plan_handed_off` are the canonical SM states).
- Both mermaid blocks (lines 109–128, 324–350) match the canonical-order prose (I → A → V at AF/Workflow; Process-synthesis I → Process-scope A/V → Process-final Val after the top Workflow join).
- Naming-hole fix (parent ACCEPT condition) wording consistent across all 15 occurrences of `optimize-five-tool-stack.sh` and 15 of `optimize-rtk-context-mode.sh`; no residual `optimize-rtk-context-mode.sh`-as-the-LeanCTX-entrypoint wording.

Prior CLEAN verdicts (MiniMax, Composer High, GLM High) and the parent-rejected doc-only mediums were treated as falsifiable claims, not premises. Locked items were not reopened: ESC-02 escalation I→V without A on steps 2–3 (lines 221–222), retired row 14, DeepSeek M2/Max bind-failure and extra-tree acceptances, the Composer-XHigh naming hole (parent ACCEPT applied), and the first-ladder ACCEPT/REJECT ledger rows.

## Naming-hole fix verification (parent ACCEPT condition, re-checked)

The brief required flagging if the new wording is still wrong. It is not. The mandated-optimizer contract is stated identically in 15 plan locations (frontmatter todos `nested-orchestration` and `validation-tests`; Overview; §WBS; §Shared-state layout; §Hook-visible primary root; §Hosts/five-tool; §Installer adapters; WS3; WS6; §Risks; §Risks five-tool; WBS-01 traceability row; KLW-01 traceability row; LPS-01 traceability row). The canonical parenthetical is:

> `scripts/optimize-five-tool-stack.sh` (LeanCTX opted-in five-tool orchestrator; it may invoke `scripts/optimize-rtk-context-mode.sh` as the RTK+CM sub-step), and `scripts/optimize-rtk-context-mode.sh` (RTK+CM-only)

The clearest normative statement is §Hosts/five-tool (line 372): *"When LeanCTX is in the opted-in stack, the mandated optimizer is `scripts/optimize-five-tool-stack.sh` (it may invoke `scripts/optimize-rtk-context-mode.sh` as the RTK+CM sub-step); `scripts/optimize-rtk-context-mode.sh` alone remains the RTK+CM-only path."* This is unambiguous, implementer-facing, and consistent with the in-repo `optimize-five-tool-stack.sh` mutual-exclusion rule (LeanCTX opted-in → five-tool orchestrator; RTK+CM-only → `optimize-rtk-context-mode.sh` alone). No residual mismatch. The fix is sound and uniformly applied.

## Lens summary

### Control plane

- **Projector-only ledger:** `hooks/lib/wbs-projector.sh` is the sole writer of WBS/packet/work-spec/plan-artifact files; only the Task-capable Orchestrator session may invoke it; role-signed receipts are inputs, not arbitrary state writes (an Executor/Advisor must not stamp `v_verified`/`val_validated) — matches overview §4.1 parent≠implementer and plan §Dispatch/§WBS/§Roles.
- **Spawn-proxy:** depth-0 parent-proxy via `hooks/lib/sb-spawn-proxy.sh` at exactly `$primary_checkout/.planning/sb-spawn-proxy.jsonl`; CAS consume with claimant-epoch lease reconciliation for consumed-without-`launched` (line 279) — crash-recovery-safe; hooks never invoke `Task`; nested Task allowed when remaining depth > 0; no Authorizer-spawns-Authorizer deadlock (bootstrap admits the first Orchestrator-driven spawn, line 271).
- **Quality-loop order:** Advisor-first one-way planning; I-clean judged by A-loop (Executor does not self-attest; I has no self-attested two-clean, line 200); AF/Workflow stop at V (no `val_*` on ordinary SM, line 193); after top Workflow join: Process-synthesis packet-local I → Process-scope A two-clean → Process-scope V two-clean → Process-final Val (lines 196–197, 202); inner nested Workflow joins stop at V and are not Process-scope — consistent with clarify Q18/Q21/Q22 SUPERSEDED and overview §5.
- **Leaf exemptions:** deny-all control-plane roles (advisor/verifier/validator/defect_escalation) exempt from Advisor-plan recursion and recursive I/A/V/Val (line 204) — no deadlock path identified.
- **Mandatory control-plane children** enumerated with "generated denies must never fence those edges out" (line 299) — sufficient for Orchestrator-mediated spawn; clarify note 13's Step→Advisor wording is Orchestrator-spawned, not a second Process router.
- **Process-synthesis** is packet-local composition/findings only (not product I of child work); re-runs of 9a–9c after Val-fail mint a new `launch_id` and occurrence ordinal so admission CAS cannot ack the prior Process-scope completion as a duplicate (lines 196, 235, 237) — duplicate-ack closed.

### Hosts / five-tool

- **MVP host adapter = Cursor**; Codex/Claude/OpenCode Orchestrator-as-parent adapters post-MVP; `sb:agent-*` rename in the MVP ship — consistent with overview §2/§4.3 and clarify Q5 SUPERSEDED.
- **Five-tool policy:** opt-in then mandatory on every **selected** runtime after init probe; brownfield re-probe all recorded runtimes; warn+unselect per failing runtime; refuse opt-in only if every runtime fails; unselect fail-closes five-tool gates only (INDEX fallback preserved for Knowledge pre-read); unselect does not delete role preference keys — matches clarify toolstack SUPERSEDED banner and plan §Hosts (line 372).
- **TAT / extra-tree:** `host_native` only; Cursor requires operator primary == git main-worktree else same-tree isolation; sparse-checkout ledger-omit dirs; merge oracle + pre-merge primary snapshot restore; `graphify update` at `$primary_checkout` before Process-final Val — consistent with locked extra-tree / primary-checkout decisions.
- **`SB_PRIMARY_CHECKOUT` bind precedence** (env → alias if not extra-tree → `rt_git_main_worktree_root` when unset; extra-tree cwd never wins; fail-closed deny not skip when five-tool opted in) is stated consistently across todos, §WBS, §Failure modes row 8, WS3/WS6, and named red-test cases (1)–(5).
- **Naming-hole fix** verified correct above (no residual mismatch); 15 consistent occurrences of each optimizer script.

### Consistency

- **No regressions** to superseded clarify positions: no dual `/silver` (lines 366, 481); no day-1 multi-host adapters; no AF/Workflow `val_*` SM (line 193); no I-loop self-attested two-clean (line 200); trust at `authorizer-trust/<repo-id>/` only with host as metadata, no `remote_id_sha256` path suffix (lines 398–402); `producer_kind=ordinary_delivery` vs `iterate_attempt` discrimination present (line 267).
- **Blocker enum:** 32 canonical `blocked_*` IDs in the ordered table (rows 1–32); every ID referenced elsewhere in the plan body resolves to a table row; `blocked_validation_state`, `blocked_callback_unresolved`, `blocked_verification_unavailable`, `blocked_child_unavailable`, `blocked_iterate_budget_exhausted`, `blocked_ladder_conflict`, `blocked_legacy_rfl_readmit`, and `blocked_user_escalation` all have row-level trigger predicates and resume targets. Historical `blocked_replan_budget` (row 7), `blocked_advisor_state` (row 14), and `blocked_triage_unresolved` (row 15) retained as non-classifying/historical.
- **Traceability:** `VAL/TST-RFL-601..619` + CAT-A..G / CORR / PREV / FIX / NEW / CUR matrix rows present; MVP acceptance slice explicitly excludes post-MVP ITR/OFF/PROD/ING freeze-drain IDs (lines 521, 559); ESC-02 traceability row (line 644) matches the escalation-ladder prose (lines 220–227) — locked I→V-without-A on steps 2–3 not reopened.
- **Structural integrity:** exactly 10 frontmatter todos; single `#` title; single `## Overview`; single `## Table of contents`; all 17 `##` headings in the TOC appear exactly once in the body; `### Document integrity` is correctly an h3 under Traceability (not a stray `##`); zero `poa_draft`/executor-draft P-loop residue; both mermaid blocks match the canonical-order prose.
- **Plan↔clarify supersession banner parity:** the clarify brief banner lists all superseded Qs (Q4, Q5, Q7, Q9c, Q11, Q12, Q14, Q18, Q21, Q22, note 15) and the plan body is consistent with the supersession (no dual `/silver`, no day-1 multi-host, no AF/Workflow `val_*`, no I-loop two-clean, trust at `authorizer-trust/<repo-id>/`).

## Blockers

None.

## Highs

None.

## Mediums

None.

## Deliberately not re-raised (parent-rejected or locked)

- Five-tool summary table row label `I / A / V / Val` (line 377) — parent-rejected doc-only medium; normative text restricts Val to Process-final; not reopened.
- `stack-compression-coordinator.sh` absent from the five-column tool table (line 374) — parent-rejected doc-only medium; WS3 + ERR-trap prose carry the obligation; not reopened.
- ESC-02 escalation I→V without A on steps 2–3 (lines 221–222) — locked ACCEPT; not reopened.
- DeepSeek M2 / Max H1 primary-checkout and extra-tree decisions — locked.
- Composer 2.5 Extra High `optimize-five-tool-stack.sh` naming hole — parent ACCEPT applied; fix verified correct above; not re-raised.
- Retired row 14 (`blocked_advisor_state`) — retained as historical/non-classifying; not reopened.

## Non-material observations

- Plan repetition of the primary-checkout / merge-oracle / ledger-omit paragraphs is extreme (~15 near-verbatim restatements) but is intentional invariant reinforcement (same observation as MiniMax Max, Composer rungs, and GLM High); not a defect.
- Clarify brief round-2 Q18 historical row (line 120 of the brief) still shows a pre-`advisor_planning` chain; the brief banner + plan supersede it — brief hygiene only, not a plan defect.
- Graphify orientation subgraph was truncated to 43 of 354 nodes at the ~2000-token budget; this was sufficient for orientation since the plan body was read in full directly. Not a defect.

## VERDICT: CLEAN

Independent GLM 5.2 Extra High / Max pass finds no control-plane deadlock, no host-realism break, no quality-loop contradiction, and no consistency defect against the refreshed overview and locked ladder-2 decisions. The Composer-2.5-Extra-High naming-hole fix is present and correctly worded in all 15 plan locations; `optimize-five-tool-stack.sh` is the LeanCTX-opted-in mandated optimizer and `optimize-rtk-context-mode.sh` is the RTK+CM-only sub-step. Plan SHA-256 matches the locked `3712dc77…`; plan↔Cursor-mirror byte-identical. Blocker enum (32 rows), structural integrity (10 todos, 19 `##` headings, single Overview/TOC), traceability matrix, and MVP/post-MVP slice boundaries are all consistent. Blockers, highs, and mediums are clear. Locked ladder-2 items (ESC-02, retired row 14, DeepSeek bind-failure/extra-tree, parent-rejected doc mediums, the naming hole) were not reopened. The GLM 5.2 High CLEAN verdict is consistent with this independent Extra High / Max pass; High was not rubber-stamped — the full plan was re-read and each lens was re-verified.
