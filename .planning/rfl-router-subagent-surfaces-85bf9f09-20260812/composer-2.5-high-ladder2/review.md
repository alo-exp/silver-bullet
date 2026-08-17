# RFL Ladder 2 — Composer 2.5 High — Architecture Review

**Reviewer:** Composer 2.5 High (this Task rung)  
**Date:** 2026-08-15  
**Branch:** `main` (no switch)  
**Read order:** [SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md](../SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md) → [router_subagent_surfaces_85bf9f09.plan.md](../../router_subagent_surfaces_85bf9f09.plan.md) (653 lines) → [router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md](../../router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md)  
**Plan SHA-256:** `adb4c6a1c318e62c384a712e6b1654e663ef6f70c3e64ce66345ab39ad8436d9`  
**Mirror parity:** `cmp` exit 0 vs `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`  
**Graphify:** `graphify query "router subagent surfaces control plane hosts five-tool routing"` (orientation)  
**Prior ladder-2 (not rubber-stamped):** DeepSeek V4 Pro High M2 ACCEPT (bind-failure / `SB_PRIMARY_CHECKOUT`); Max H1 ACCEPT (Cursor extra-trees); MiniMax M3 High CLEAN; MiniMax M3 Max CLEAN (~345s, [review.md](../../agent-opencode/rfl-minimax-m3-max-20260814/review.md))

## Independence statement

This pass re-read the mandatory overview, full plan, and clarify brief, then independently checked control-plane spawn/projector/proxy semantics, MVP host-adapter scope, five-tool + `$SB_PRIMARY_CHECKOUT` bind rules, quality-loop order (Advisor-first, Process-scope 9a–9c, Process-final Val only), blocker enum completeness, and plan↔clarify supersession banner parity. Prior CLEAN verdicts were treated as claims to falsify, not premises. Locked items were not reopened: ESC-02 (escalation I→V without A), retired row 14, DeepSeek M2 bind-failure acceptance, or first-ladder ACCEPT/REJECT ledger rows without new contradiction.

## Lens summary

### Control plane

- **Projector-only WBS/packets/work-spec/plan artifacts** via `hooks/lib/wbs-projector.sh`; Task-capable Orchestrator session is sole caller; children submit receipts only — matches overview §4.1 parent≠implementer and plan §Dispatch / §WBS.
- **Spawn-proxy** at exactly `$primary_checkout/.planning/sb-spawn-proxy.jsonl` through `hooks/lib/sb-spawn-proxy.sh` (append + CAS-consume); depth-0 parent-proxy mandatory — executable on Cursor MVP without hooks invoking `Task`.
- **Process-synthesis I** is packet-local composition/findings only (not product I of child work); mandatory 9a–9c after top Workflow join before Process-final Val — aligned with clarify Q18/Q21/Q22 SUPERSEDED and overview §5.
- **Deny-all leaf exemption** from Advisor-plan recursion and recursive I/A/V/Val — deadlock-free for advisor/verifier/validator/defect_escalation leaves.
- **Mandatory control-plane children** enumerated (Advisor planning, on-demand consult, A Mentors, V, Process-final Validator, Process-synthesis, Process-repair) with **“Generated denies must never fence those edges out”** — sufficient for Orchestrator-mediated spawn model (clarify note 13’s Step→Advisor wording is Orchestrator-spawned, not a second Process router).

### Hosts / five-tool

- **MVP = Cursor host adapter**; Codex/Claude/OpenCode Orchestrator-as-parent adapters **after MVP** — consistent with overview §2/§4.3 and clarify Q5 SUPERSEDED.
- **Five-tool:** opt-in then mandatory on every **selected** runtime after init probe; brownfield re-probes all recorded runtimes; warn+unselect per failing runtime; refuse opt-in only if every runtime fails; unselect fail-closes five-tool gates only (INDEX fallback remains for Knowledge pre-read) — matches clarify toolstack SUPERSEDED banner and plan §Hosts.
- **TAT / extra-tree:** `host_native` only; Cursor requires operator primary == git main-worktree else same-tree isolation; sparse-checkout ledger-omit dirs; merge oracle + pre-merge primary snapshot restore — consistent with locked extra-tree / primary-checkout decisions.
- **`SB_PRIMARY_CHECKOUT` bind precedence** (env → alias if not extra-tree → `rt_git_main_worktree_root` when unset; extra-tree cwd never wins; fail-closed deny not skip when five-tool opted in) is stated consistently across todos, §WBS, §Failure modes row 8, and named red-test cases (1)–(5).

### Consistency

- **No regressions** to superseded clarify positions: no dual `/silver`, no day-1 multi-host adapters, no AF/Workflow `val_*` SM, no I-loop self-attested two-clean, trust at `authorizer-trust/<repo-id>/` only, `producer_kind=ordinary_delivery` vs `iterate_attempt` discrimination present.
- **Blocker enum:** 32 canonical `blocked_*` IDs in the ordered table; every ID referenced elsewhere in the plan body; `blocked_validation_state`, `blocked_callback_unresolved`, `blocked_verification_unavailable`, `blocked_child_unavailable`, and `blocked_iterate_budget_exhausted` all have row-level trigger predicates (GLM High c1 enum gaps are closed in current bytes).
- **Traceability:** `VAL/TST-RFL-601..619` + matrix rows present; MVP acceptance slice explicitly excludes post-MVP ITR/OFF/PROD/ING freeze-drain IDs.
- **Structural integrity:** 10 frontmatter todos; single `## Overview`; TOC headings match body; no `poa_draft` / executor-draft P-loop residue.

## Blockers

None.

## Highs

None.

## Mediums

1. **Five-tool summary table row label (§Hosts, lines 374–378).** The usage row is labeled `I / A / V / Val` while the architecture (and clarify Q21/Q22 SUPERSEDED) restricts Validation-loop to **Process-final only**; AF/Workflow stop at V. The row describes tool usage during phases, not SM states, but the label can misread as mandatory per-scope Val tooling. **Suggestion:** rename to `I / A / V (AF/Workflow); Process-final Val` or add a footnote that Val column applies only at Process roll-up.

2. **`stack-compression-coordinator.sh` absent from the five-tool summary table.** Prose throughout WS3 / §Hosts / §Failure modes requires this hook to share the same `$SB_PRIMARY_CHECKOUT` bind as the six named PreToolUse gates, but the five-column tool table lists only Graphify/agentmemory/CM/LeanCTX/RTK. **Suggestion:** add a one-line note under the table that `hooks/stack-compression-coordinator.sh` is a stack-routing PreToolUse participant (not a sixth tool) and inherits the same primary-checkout bind — reduces implementer table-only skim risk.

## Non-material observations

- Plan repetition of primary-checkout / merge-oracle paragraphs is extreme but intentionally reinforces locked invariants and red-test oracle semantics (same observation as MiniMax Max Notes).
- Clarify brief round-2 Q18 historical row (line 120) still shows a pre-`advisor_planning` chain; banner + plan supersede — brief hygiene only, not a plan defect.

## VERDICT: CLEAN

Independent Composer 2.5 High pass finds no control-plane deadlock, host-realism break, or consistency contradiction against the refreshed overview and locked ladder-2 decisions. Two documentation-clarity mediums are recorded; neither reopens locked ESC-02, bind-failure, or retired-row-14 items, and neither blocks MVP executability given the surrounding normative prose and WS ownership splits.
