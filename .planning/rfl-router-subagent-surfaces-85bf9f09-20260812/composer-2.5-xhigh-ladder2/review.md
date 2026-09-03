# RFL Ladder 2 — Composer 2.5 Extra High — Architecture Review

**Reviewer:** Composer 2.5 Extra High (this Task rung)  
**Date:** 2026-08-15  
**Branch:** `main` (no switch)  
**Read order:** [SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md](../SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md) → [router_subagent_surfaces_85bf9f09.plan.md](../../router_subagent_surfaces_85bf9f09.plan.md) (653 lines) → [router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md](../../router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md)  
**Plan SHA-256:** `adb4c6a1c318e62c384a712e6b1654e663ef6f70c3e64ce66345ab39ad8436d9`  
**Mirror parity:** `cmp` exit 0 vs `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`  
**Graphify:** `graphify query "router subagent surfaces control plane hosts five-tool stack coordinator"` (orientation; 259-node subgraph, truncated)  
**Prior ladder-2:** DeepSeek V4 Pro High M2 ACCEPT (`SB_PRIMARY_CHECKOUT` bind); Max H1 ACCEPT (Cursor extra-trees); MiniMax M3 High/Max CLEAN; Composer 2.5 High CLEAN — parent **rejected** two doc-only mediums (five-tool Val row label; stack-coordinator missing from summary table)

## Independence statement

Extra High pass re-read the mandatory overview, clarify brief, and plan body (frontmatter, control-plane spawn/projector/proxy, quality loops, hosts/five-tool, blocker enum, traceability matrix, WS1–WS7). Prior CLEAN claims and parent-rejected doc mediums were treated as falsifiable, not premises. Automated checks: 32/32 `blocked_*` IDs in body match the ordered table (no orphans); plan↔mirror byte-identical; zero `poa_draft` residue; ESC-02 locked as Executor-shaped I→V (not reopened); retired row 14 not reopened.

## Lens summary

### Control plane

- **Projector-only ledger:** `hooks/lib/wbs-projector.sh` is sole writer of WBS/packets/work-spec/plan artifacts; Task-capable Orchestrator session only; children submit receipts — aligned with overview §4.1 and plan §Dispatch / §WBS.
- **Spawn-proxy:** depth-0 parent-proxy via `hooks/lib/sb-spawn-proxy.sh` at exactly `$primary_checkout/.planning/sb-spawn-proxy.jsonl`; CAS consume + `launch_intent` atomicity specified; hooks never invoke `Task`.
- **Quality-loop order:** Advisor-first one-way planning; I-clean via A-loop (no Executor self-attest); AF/Workflow stop at V; mandatory Process-synthesis I → Process-scope A/V → Process-final Val after top Workflow join — consistent with clarify supersession banner and overview §5.
- **Leaf exemptions:** deny-all control-plane roles exempt from recursive I/A/V/Val — no deadlock path identified.
- **Mandatory control-plane children** enumerated with “generated denies must never fence those edges out.”

### Hosts / five-tool

- **MVP host adapter = Cursor**; Codex/Claude/OpenCode Orchestrator-as-parent adapters post-MVP; `sb:agent-*` rename in MVP ship — consistent with overview §2/§4.3 and clarify Q5 SUPERSEDED.
- **Five-tool policy:** opt-in then mandatory on every **selected** runtime after init probe; brownfield re-probe; warn+unselect per failing runtime; refuse opt-in only if every runtime fails; unselect fail-closes five-tool gates only (INDEX fallback preserved for Knowledge pre-read).
- **`$SB_PRIMARY_CHECKOUT` bind:** env → alias (extra-tree treated unset) → `rt_git_main_worktree_root` when unset; extra-tree cwd never wins; fail-closed deny (not skip) when five-tool opted in — consistent across todos, §WBS, row 8, WS3/WS6, and named red-test cases (1)–(5).
- **`stack-compression-coordinator.sh`:** normative prose and WS3 require same primary-checkout bind as the six `sb-project-gate` PreToolUse entrypoints (16 mentions in plan body). Obligation is present in implementation workstream text even where abbreviated traceability rows (KLW/WBS) list only the six gates.

### Consistency

- No regressions to superseded clarify positions (no dual `/silver`, no day-1 multi-host adapters, no AF/Workflow `val_*` SM, no I-loop self-attested two-clean, trust at `authorizer-trust/<repo-id>/` only).
- `producer_kind=ordinary_delivery` vs `iterate_attempt` discrimination present.
- Structural integrity: 10 frontmatter todos; single `## Overview`; TOC headings present; MVP slice explicitly excludes post-MVP ITR/OFF/PROD/ING matrix IDs.

## Blockers

None.

## Highs

None.

## Mediums

1. **Five-tool install orchestrator script name (hosts/five-tool obligation).** The plan mandates LeanCTX as a fifth five-tool column (§Hosts table; five-tool opt-in policy) and lists `scripts/install-leanctx-sb.sh` in WS3, but names **`scripts/optimize-rtk-context-mode.sh`** as the stack optimizer touchpoint **16 times** and never names **`scripts/optimize-five-tool-stack.sh`**. In-repo, `optimize-five-tool-stack.sh` explicitly states that when `leanctx.enabled_by_user` is true, callers **MUST** use it instead of `optimize-rtk-context-mode.sh` alone (conflict #9); it orchestrates LeanCTX + RTK + CM routing. An implementer following the plan literally could wire RTK+CM only and miss the routed five-tool profile LeanCTX requires. **Suggestion:** in WS3/WS6 and the repeated “Callers — every `RT_PROJECT_ROOT`…” paragraphs, name `optimize-five-tool-stack.sh` as the LeanCTX-opted-in entrypoint and retain `optimize-rtk-context-mode.sh` only as the sub-step it invokes (or document the mutual-exclusion rule explicitly).

## Deliberately not re-raised (parent-rejected or locked)

- Five-tool summary table row label `I / A / V / Val` (doc skim; normative text restricts Val to Process-final).
- `stack-compression-coordinator.sh` absent from the five-column tool table (doc skim; WS3 + ERR-trap prose carry the obligation).
- ESC-02 escalation I→V without A on steps 2–3 (locked ACCEPT).
- DeepSeek M2 / Max H1 primary-checkout and extra-tree decisions (locked).

## Non-material observations

- Extreme paragraph repetition on primary-checkout / merge-oracle is intentional invariant reinforcement (same as prior rungs).
- Clarify brief round-2 Q18 historical row still shows pre-`advisor_planning` chain; banner + plan supersede — brief hygiene only.

## VERDICT: NOT CLEAN

Independent Composer 2.5 Extra High pass finds no control-plane deadlock, host-realism break, or quality-loop contradiction. One **hosts/five-tool obligation mismatch** remains: the plan omits `optimize-five-tool-stack.sh` while mandating LeanCTX in the five-tool stack and repeatedly prescribing `optimize-rtk-context-mode.sh` alone. That is implementer-facing contract text, not a table-label nit. Blockers and highs are clear; locked ladder-2 items were not reopened.
