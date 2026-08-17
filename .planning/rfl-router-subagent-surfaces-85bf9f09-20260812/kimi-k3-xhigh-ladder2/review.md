# RFL Ladder 2 — Kimi K3 Extra High / Max — Architecture Review

**Reviewer:** Kimi K3 Extra High / Max (this Task rung — `sb-kimi-k3-xhigh`; this family's Max rung)
**Date:** 2026-08-15
**Branch:** `main` (no switch; no plan edits; no commit)
**Read order:** [SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md](../SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md) (read in full) → [router_subagent_surfaces_85bf9f09.plan.md](../../router_subagent_surfaces_85bf9f09.plan.md) (652 lines, read in full) → [router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md](../../router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md) (read in full)
**Plan SHA-256:** `3712dc7731fdaa462ca0079a4c8a1fee53118d8b9c4cf94c478a60b0204a86ec` — unchanged from the locked post-Composer-XHigh-fix value; `sha256sum` on repo copy and `~/.cursor/plans/` mirror match, byte-identical.
**Graphify:** `graphify query "router subagent surfaces control plane hosts five-tool consistency"` (orientation; 121-node subgraph, truncated to budget).
**agentmemory:** MCP not wired in this session; usage recorded via REST `POST http://localhost:3111/agentmemory/smart-search` (status 200) per `docs/AGENTMEMORY.md` usage-recording path.
**Lenses:** control plane; hosts/five-tool; consistency.

## Independence statement

This Extra High / Max pass re-read the mandatory overview, the full plan, and the clarify brief, then independently re-verified the contract rather than adopting prior CLEAN verdicts. Direct checks performed:

- Plan integrity: SHA-256 `3712dc77…` on both copies; mirror byte-identical; 652 lines; exactly 10 frontmatter todos; single `#` title; 19 `##` headings = Overview + Table of contents + the 17 TOC entries, each TOC entry present exactly once; `### Document integrity` correctly an h3 under Traceability.
- Blocker enum: 32 ordered rows (`blocked_corrupt_state` … `blocked_user_escalation`); every `blocked_*` ID referenced anywhere in the plan body resolves to a table row (zero unresolved refs); row 7 `blocked_replan_budget`, row 14 `blocked_advisor_state`, row 15 `blocked_triage_unresolved` retained as historical/non-classifying exactly as locked.
- Quality-loop order: Advisor-first one-way handoff (`advisor_planning` → `plan_handed_off`); I has no self-attested two-clean; A/V two-clean; AF/Workflow stop at V (no `val_*` on the ordinary SM); after the **top** Workflow join, Process-synthesis packet-local I → Process-scope A two-clean → Process-scope V two-clean → Process-final Val; inner nested Workflow joins stop at V. Zero `poa_draft` / `poa_advisor_review` / `poa_satisfied` residue in the plan.
- Naming-hole fix (Composer 2.5 XHigh ACCEPT condition): `scripts/optimize-five-tool-stack.sh` is named as the LeanCTX-opted-in five-tool orchestrator (17 occurrences) with `scripts/optimize-rtk-context-mode.sh` as the RTK+CM-only sub-step (33 occurrences, all in the sub-step/RTK+CM-only framing); both scripts exist in-repo. No residual "RTK+CM script alone for LeanCTX stacks" wording.
- Primary-checkout / worktree contract: `$SB_PRIMARY_CHECKOUT` (env; alias `SILVER_BULLET_PROJECT_ROOT` treated as unset when it points at a heuristic extra tree) → `rt_git_main_worktree_root` fallback only when env unset; extra-tree cwd never wins; fail-closed deny (not skip) when five-tool is opted in; ledger-omit dirs (`.planning/`, `graphify-out/`, `.agentmemory/`, project `.silver-bullet/`) sparse-checkout-omitted; merge oracle on `merge-base..worktree-branch` plus filesystem-presence check, `git merge --no-commit` → restore ledger-omit paths from the pre-merge primary working-tree snapshot → code-only `git commit` or `git merge --abort`; clean-index requirement for repeated joins; post-merge `graphify update` at `$primary_checkout` before Process-final Val.
- Plan↔clarify parity: clarify L64 and L158 canonical chains both include Process-synthesis I → Process-scope A/V after the **top** Workflow join only; banner supersessions (Q4 dual-prefix, Q5 day-1 multi-host, Q7 RFL delete, Q9c/note-15 trust path, Q11 packaging, Q12 I-loop two-clean, Q14/Q18/Q21/Q22 Val scope) all match the plan body.

Locked items were not reopened: ESC-02 (escalation steps 2–3 are Executor-shaped I then V, no A), retired row 14, first-ladder Kimi ACCEPTs, DeepSeek bind-failure / extra-tree acceptances, and the Composer XHigh optimizer-naming ACCEPT. The five Kimi-High advisory mediums (M1 rows 13/22 Advisor-unavailable first-match mechanics; M2 SessionStart env-export unproven; M3 remaining-depth not in envelope/spawn-proxy field lists; M4 step-3 Val self-grade uninstrumented; M5 live-E2E overlap conditional phrasing vs L559) were re-examined against the current plan and the parent's REJECT rationale; none is a real obligation mismatch — M1's outcome ID is determinable and row mechanics are classifying-table style, M2 degrades fail-closed and is assigned to the capability-contract/live-E2E proof surface, M3's record list is explicitly non-exhaustive ("at least") with depth proof owned by the capability-contract todo, M4 is an explicit accepted MVP carve-out, and M5's heuristic inputs are operator-arrangeable on the MVP host with acceptance text mandating the scenario. They remain non-gating and are not re-raised as findings.

## Lens summary

### Control plane

- **Projector-only ledger:** `hooks/lib/wbs-projector.sh` is the sole writer of WBS/packet/work-spec/plan-artifact files; only the Task-capable Orchestrator session invokes it; role-signed receipts are inputs, not state writes (no Executor/Advisor stamping of `v_verified` / `val_validated`). `hooks/lib/sb-spawn-proxy.sh` is a third allowlisted helper for exactly `$primary_checkout/.planning/sb-spawn-proxy.jsonl`; no raw Edit/Write path exists for ledger or jsonl.
- **Spawn physics:** hooks/scripts never invoke `Task`; nested Task allowed while remaining depth > 0; parent-proxy mandatory at depth 0 with put-if-absent `request_id`, atomic `pending→consumed` + `launch_intent` persist (or claimant-epoch lease with consumed-without-`launched` reconciliation back to `pending`/`failed` — never permanently consumed-without-launch). Bootstrap admits the first Orchestrator-driven spawn; no Authorizer-spawns-Authorizer cycle.
- **Deadlock freedom:** deny-all leaf roles (advisor / verifier / validator / defect_escalation and admitted Mentors/Validators) are exempt from Advisor-plan recursion and recursive I/A/V/Val — they execute role work, return a signed receipt, terminate. `blocked_depth_unsupported` fires only when even parent-proxy spawn is impossible.
- **Repair / re-run integrity:** Val-fail invalidates `process_synth_*` / `process_a_*` / `process_v_*`; 9a–9c re-run after the repair chain re-joins the top Workflow with a fresh `launch_id` and advanced occurrence ordinal, so admission CAS cannot duplicate-ack prior Process-scope completions. Repair Executors and Process-final Validator run at `$primary_checkout`; no un-merge.

### Hosts / five-tool

- **MVP scope:** Cursor host adapter + `sb:agent-*` rename (including OpenCode) + bootstrap migrate (ILM-01) + live E2E; Codex/Claude/OpenCode Orchestrator-as-parent host adapters are post-MVP — matches overview §2/§4.3 and clarify Q5 SUPERSEDED. Cold `/sb:agent-*` mints a Process wrap then runs as an Executor-shaped leaf (Advisor-first handoff included), closing the second-router hole.
- **Five-tool:** opt-in → mandatory on every **selected** runtime after init probe; brownfield re-probe all recorded runtimes; per-runtime warn+unselect on probe failure (five-tool gates fail closed for that runtime; Knowledge INDEX fallback preserved; role preference keys retained); refuse opt-in only when every recorded runtime fails; failing Pi probe does not block Cursor; runtime-changing replacements probe first or do not switch. Optimizer naming-hole fix verified as above.
- **Primary-root bind:** consistent across frontmatter todos, §Overview, §Task/work-spec, §Dispatch/parent-proxy, §WBS/shared-state, §Hosts/five-tool, §Failure modes row 8, WS3/WS6, and named red-test cases (1)–(5) — env → non-extra-tree alias → git-main fallback; PWD config walk never wins; `stack-compression-coordinator.sh` carries the same bind obligation as the six `sb-project-gate` PreToolUse entrypoints.

### Consistency

- **Supersession parity:** no dual `/silver` window; bootstrap `scripts/sb-migrate-from-silver.sh` plus plugin postinstall (not only `/sb:migrate`); no day-1 multi-host adapters; no AF/Workflow `val_*`; no I-loop self-attested two-clean; trust at `~/.silver-bullet/authorizer-trust/<repo-id>/` with host as metadata (the two remaining `remote_id_sha256` mentions are the historical digest-name note, not a path suffix); `producer_kind=ordinary_delivery` vs `iterate_attempt` discrimination intact.
- **Traceability:** `VAL/TST-RFL-601..619` plus CAT/CORR/PREV/FIX/NEW/CUR rows present; preserved-ID enumeration (001..007, 101..118, 201..205, 301..306, 401..405, 501..506, 601..619, 900) matches the matrix; MVP acceptance excludes ITR/OFF/PROD/ING-freeze-drain and TRUST rotation/revocation while naming the MVP slice IDs (LPS, WBS, POA incl. `step_yield`, ALP, VLP incl. Process-scope V, VALP, KLW, ADM-01, ILM-01, TRUST-01 identity-only, EFF-01 ordinary, ILP-01, ESC-02, live E2E incl. the overlap-worktree scenario).
- **Document integrity self-check:** the plan's own §Document integrity invariants hold (verified counts above); no standalone Addendum headings; two distinct mermaid blocks matching canonical-order prose; no duplicate `##` headings.

## Blockers

None.

## Highs

None.

## Mediums

None.

## Deliberately not re-raised (locked or parent-rejected)

- ESC-02 escalation steps 2–3 as Executor-shaped I then V without A — locked.
- Row 14 `blocked_advisor_state` retired/non-classifying; identical Advisor/Executor tuples warn-only — locked.
- DeepSeek M2 / Max H1 primary-checkout bind precedence and Cursor extra-tree gating — locked.
- Composer 2.5 Extra High optimizer naming hole — parent ACCEPT applied; fix verified present and uniformly worded; not re-raised.
- Kimi K3 High M1–M5 advisory mediums — parent REJECT confirmed as non-gating; re-examined at Extra High depth; no real obligation mismatch found (see Independence statement).
- Parent-rejected doc-only mediums (five-tool summary table row label `I / A / V / Val`; `stack-compression-coordinator.sh` absent from the five-column table) — normative prose carries both; not reopened.
- First-ladder Kimi ACCEPTs (top Workflow join wrap, clarify L64/L158 chains, Overview/WBS enumerations, LPS-01 `scope_bounds`, Verifier Process-scope V) — verified still satisfied.

## Non-material observations

- The plan's near-verbatim repetition of the primary-checkout / ledger-omit / merge-oracle invariants across ~15 locations is deliberate invariant reinforcement; no contradictions found among the restatements.
- Clarify brief retains historical round-2 rows (e.g. Q18) whose banner-level supersession is explicit; brief hygiene only, not a plan defect.

## VERDICT: CLEAN

Independent Kimi K3 Extra High / Max review finds the router-subagent-surfaces spec **CLEAN**: no control-plane deadlock or executability break, no host/five-tool obligation mismatch, and no consistency or traceability defect against the locked ladder-2 state. The plan is byte-identical to its Cursor mirror at SHA-256 `3712dc77…`; structural invariants (10 todos, 19 `##` headings, 32-row blocker enum with zero unresolved references) hold; the Composer-XHigh optimizer fix is correctly and uniformly applied; the parent-rejected Kimi-High mediums remain non-gating with no newly discovered obligation mismatch. Blockers, highs, and mediums are all empty. The Kimi K3 High CLEAN verdict was independently re-derived, not rubber-stamped.
