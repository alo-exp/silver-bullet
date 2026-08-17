# RFL Ladder 2 — Gemini 3.7 Flash High — Architecture Review

**Reviewer:** Gemini 3.7 Flash High (this Task rung)  
**Date:** 2026-08-15  
**Branch:** `main` (no switch)  
**Read order:** [SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md](../SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md) → [router_subagent_surfaces_85bf9f09.plan.md](../../router_subagent_surfaces_85bf9f09.plan.md) (652 lines) → [router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md](../../router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md)  
**Plan SHA-256:** `3712dc7731fdaa462ca0079a4c8a1fee53118d8b9c4cf94c478a60b0204a86ec`  
**Mirror parity:** `cmp` exit 0 vs `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`; `shasum -a 256` matches on both copies (exit 0)  
**Graphify:** `graphify query "router subagent surfaces"` (orientation; 40 nodes traversed)  
**Prior ladder-2 (not rubber-stamped):** DeepSeek V4 Pro High M2 ACCEPT (bind-failure / `SB_PRIMARY_CHECKOUT`); Max H1 ACCEPT (Cursor extra-trees); MiniMax M3 High/Max CLEAN; Composer 2.5 High CLEAN (parent rejected two doc mediums: Val row label, stack-coordinator table omission); Composer 2.5 Extra High NOT CLEAN → parent ACCEPT applied (LeanCTX-opted-in five-tool uses `optimize-five-tool-stack.sh`; `optimize-rtk-context-mode.sh` is RTK+CM-only sub-step; plan SHA-256 advanced to `3712dc77…`); GLM 5.2 High + Extra High/Max CLEAN; Qwen 3.8 High + Max CLEAN.

---

## Independence Statement

This review independently re-read the mandatory overview, the full architecture plan (`router_subagent_surfaces_85bf9f09.plan.md`, 652 lines), and the clarify brief. All claims, structural invariants, and state machines were verified directly against the plan text, rather than relying on prior CLEAN verdicts.

Key verification areas performed:
1. **Naming-hole fix verification (parent ACCEPT condition):** Verified that `scripts/optimize-five-tool-stack.sh` is consistently named as the mandated optimizer for LeanCTX-opted-in five-tool stacks across all occurrences, while `scripts/optimize-rtk-context-mode.sh` remains the RTK+CM-only sub-step.
2. **Control-plane executability and deadlock-freedom:** Checked parent-only orchestration, projector-only write authority (`hooks/lib/wbs-projector.sh`), depth-0 spawn proxying (`hooks/lib/sb-spawn-proxy.sh` at `$primary_checkout/.planning/sb-spawn-proxy.jsonl`), Authorizer-fenced launches, and leaf exemptions.
3. **Quality-loop canonical order:** Verified Advisor-first one-way planning (`advisor_planning` → `plan_handed_off`), Executor I-loop with no self-attestation, Advisor A-loop Mentorship (I-clean judged by two A-clean rounds), Verifier V-loop two-clean (`v_verified`), AF and Workflow termination at V (no `val_*` states on ordinary SM), code-only overlap merge, top Workflow join, Process-synthesis packet-local I, Process-scope A two-clean, Process-scope V two-clean, and Process-final Validation-loop once at roll-up.
4. **Hosts and five-tool stack:** Verified Cursor MVP host adapter vs post-MVP Codex/Claude/OpenCode parent-host adapters, `sb:agent-*` CLI/TUI rename, model preferences (`{ runtime, model, effort }`), unavailable model handling, five-tool init probe, brownfield opt-in re-probe and unselect semantics, and `$SB_PRIMARY_CHECKOUT` bind precedence.
5. **Structural and catalog integrity:** Verified 10 frontmatter todos, TOC-to-body heading parity (17 `##` sections in TOC matching 17 in body, plus Overview and TOC), 32 canonical blocker rows (`blocked_corrupt_state` through `blocked_user_escalation`), and byte-identical plan mirror parity.

Locked items were not reopened: ESC-02 (I then V, no A on escalation steps 2–3), retired row 14 (`blocked_advisor_state`), DeepSeek M2/Max primary checkout / extra-tree bindings, parent-rejected doc mediums, and first-ladder ACCEPT/REJECT ledger rows.

---

## Lens Summary

### 1. Control Plane

- **Parent Non-Implementation & Projector-Only Authority:** The Orchestrator parent never implements product source. `hooks/lib/wbs-projector.sh` is the sole writer of WBS, packet, work-spec, and plan-artifact files under `$primary_checkout/.planning/`. Only the Task-capable Orchestrator session invokes this helper; children and leaf roles (Advisor, Executor, Verifier, Validator) submit role-signed receipts and must not invoke the projector or edit these files directly.
- **Spawn-Proxy Protocol (Depth 0):** When remaining depth is 0, children append spawn requests via `hooks/lib/sb-spawn-proxy.sh` to `$primary_checkout/.planning/sb-spawn-proxy.jsonl`. The nearest Task-capable ancestor CAS-consumes pending rows on its next turn/SessionStart, leases claimant epochs, mints `launch_intent`, and launches the child. No background daemon is required, and crash recovery is guaranteed through epoch-leased CAS.
- **Admission & Fencing:** Authorizer hooks commit signed `launch_intent` and outboxes before host spawn. Work-spec RFC 8785 JCS hash and prompt NFC hash are verified fail-closed (`blocked_launch_prompt_spec`).
- **Deadlock Freedom:** Leaf control-plane roles (`advisor`, `verifier`, `validator`, `defect_escalation`) are explicitly exempt from Advisor-plan handoff and recursive I/A/V/Val loops; they return signed receipts and terminate. Bootstrap admits the first Orchestrator-driven spawn to eliminate Authorizer-spawns-Authorizer bootstrap deadlocks.
- **Process-Synthesis & Re-Runs:** Process-synthesis I is packet-local composition and findings only. Val-fail repair re-runs of Process-scope steps 9a–9c and Process-final Val re-entry mint a new `launch_id` and advance the occurrence ordinal, ensuring admission CAS does not duplicate-ack prior completions.

### 2. Hosts and Five-Tool Stack

- **MVP Scope:** MVP delivers the Cursor host adapter, six-role control plane, `/sb` router, Task/work-spec admission, WBS projector, overlap worktrees for `host_native`, Advisor-first planning, Process-final Val, `sb:agent-*` skill renames, bootstrap migration (`scripts/sb-migrate-from-silver.sh`), and live E2E testing. Parent-host adapters for Codex, Claude Code, and OpenCode sequence post-MVP.
- **Mandated Optimizer Contract:** All 15 occurrences of the five-tool optimizer in the plan correctly specify `scripts/optimize-five-tool-stack.sh` as the LeanCTX-opted-in orchestrator (which may invoke `scripts/optimize-rtk-context-mode.sh` as the RTK+CM sub-step) and `scripts/optimize-rtk-context-mode.sh` as the RTK+CM-only path.
- **Five-Tool Opt-In & Probe:** Opt-in enforces mandatory compliance on every selected runtime. `/sb:init` probes runtimes before recording; brownfield opt-in re-probes all recorded runtimes. Failing runtimes are unselected with a warning, failing-closed five-tool gates for that runtime while preserving INDEX fallback for Knowledge pre-reads and role preference keys. Opt-in is refused (`blocked_knowledge_preread`) only if every recorded runtime fails.
- **Primary Checkout Binding & TAT Isolation:** Extra worktrees are created only for `host_native` when Advisor touch-sets are disjoint, ≥2 Executors run, and on Cursor operator primary equals git main-worktree (`rt_git_main_worktree_root`). Extra trees omit ledger directories (`.planning/`, `graphify-out/`, `.agentmemory/`, `.silver-bullet/`) via sparse-checkout. PreToolUse gates resolve `$primary_checkout` via process env `SB_PRIMARY_CHECKOUT` → alias `SILVER_BULLET_PROJECT_ROOT` (unset if pointing to extra tree) → `rt_git_main_worktree_root` fallback. Extra-tree cwd never binds as primary, and missing resolution when five-tool is opted in results in fail-closed deny JSON.

### 3. Consistency and Integrity

- **Superseded Clarify Parity:** All items listed in the clarify brief banner (no dual `/silver`, no day-1 multi-host adapters, no AF/Workflow `val_*` states, no I-loop two-clean self-attest, Authorizer trust at `~/.silver-bullet/authorizer-trust/<repo-id>/` without `remote_id_sha256` path suffix) are strictly adhered to in the plan body.
- **Blocker Table Completeness:** The failure modes table lists exactly 32 canonical `blocked_*` rows with mutually disjoint triggers and explicit resume actions. Historical IDs (row 7 `blocked_replan_budget`, row 14 `blocked_advisor_state`, row 15 `blocked_triage_unresolved`) are correctly classified as non-classifying/historical.
- **Document Structure:** Frontmatter contains exactly 10 todos. All 17 `##` headings in the Table of Contents match the body sections 1:1. Both Mermaid diagrams accurately mirror the canonical execution flow. Plan SHA-256 matches the locked `3712dc77…` hash and maintains byte-identical parity with the Cursor mirror copy.

---

## Findings

### Blockers
None.

### Highs
None.

### Mediums
None.

---

## Deliberately Not Re-Raised (Locked or Parent-Rejected)

1. **ESC-02 Escalation I→V Without A on Steps 2–3:** Locked decision; Advisor / Validator-model implementations on escalation follow Executor-shaped I then Verifier V before Process-final Val.
2. **Retired Row 14 (`blocked_advisor_state`):** Retained as a non-classifying historical ID; Init/Doctor warn on identical Advisor/Executor model tuples rather than hard-stopping.
3. **DeepSeek M2 / Max H1 Extra-Tree & Primary Bindings:** Locked decisions; primary checkout resolution order and Cursor main-worktree TAT requirement are fully incorporated.
4. **Parent-Rejected Doc Mediums:** Five-tool summary table row label `I / A / V / Val` and omission of `stack-compression-coordinator.sh` from the five-column summary table remain rejected as non-normative/doc-only.
5. **Composer 2.5 Extra High Naming-Hole Fix:** Verified present, consistent, and correctly phrased across all 15 locations.

---

## Non-Material Observations

1. **Repetition of Primary-Checkout / Merge-Oracle / Ledger-Omit Invariants:** The plan repeats the primary-checkout binding rules, sparse-checkout ledger-omit directories, and merge-oracle procedures across multiple sections. This deliberate repetition serves as invariant reinforcement across workstream boundaries and causes no contradictions.
2. **Clarify Brief Historical Row Q18:** Line 120 of the clarify brief retains historical round-2 text, but the top-of-file banner explicitly supersedes it and directs the reader to the canonical architecture spec.

---

## VERDICT: CLEAN

The **Gemini 3.7 Flash High** review finds plan `router_subagent_surfaces_85bf9f09.plan.md` **CLEAN**. 

The specification presents a sound, executable, and internally consistent Process-first architecture with clear role boundaries, deadlock-free quality loops, robust primary-checkout binding, and unambiguous MVP vs post-MVP sequencing. No blockers, highs, or mediums were identified.
