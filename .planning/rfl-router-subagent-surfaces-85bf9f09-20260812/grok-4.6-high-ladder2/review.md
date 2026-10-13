# RFL Ladder 2 — Grok 4.6 High — Architecture Review

**Reviewer:** Grok 4.6 High (this Task rung; `cursor-grok-4.6-high`; not delegated)
**Date:** 2026-08-15
**Branch:** `main` (no switch; no plan edits; no commit)
**Read order:** [SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md](../SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md) (read in full first) → [router_subagent_surfaces_85bf9f09.plan.md](../../router_subagent_surfaces_85bf9f09.plan.md) (653 lines) → [router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md](../../router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md) (read in full)
**Plan SHA-256:** `3712dc7731fdaa462ca0079a4c8a1fee53118d8b9c4cf94c478a60b0204a86ec` — matches the Composer 2.5 Extra High ACCEPT ledger value.
**Mirror parity:** `cmp` exit 0 vs [`~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`](/Users/shafqat/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md). Clarify brief has no Cursor-mirror twin (`cmp` exit 2); plan line 652 only requires the plan copies.
**Graphify:** `graphify query "router subagent surfaces control plane hosts five-tool Task delegation"` (orientation; 158-node subgraph, truncated). Graphify MCP was down; CLI used.
**Lenses:** control plane; hosts/five-tool; consistency.

## Independence statement

This pass re-read the mandatory overview, the plan body (frontmatter todos, control-plane spawn/projector/proxy, quality loops, hosts/five-tool, blocker enum, workstreams, document integrity), and the clarify brief, then independently verified: (a) spawn/projector/spawn-proxy writer discipline and deadlock-freedom; (b) quality-loop order (Advisor-first one-way handoff, I no self-attest, A/V two-clean, AF/Workflow stop at V, Process-synthesis packet-local I, Process-scope 9a–9c, Process-final Val only); (c) MVP host scope (Cursor adapter + `sb:agent-*` rename; Codex/Claude/OpenCode host adapters after MVP); (d) five-tool opt-in → init-probe → brownfield re-probe/warn-unselect and `$SB_PRIMARY_CHECKOUT` bind precedence; (e) Composer-XHigh ACCEPT wording for `optimize-five-tool-stack.sh`; (f) blocker enum (32 rows) and first-match contract; (g) plan↔clarify supersession banner parity; (h) structural integrity (exactly 10 todos; single `#` title; 19 `##` headings; two mermaid blocks). Prior CLEAN verdicts were treated as falsifiable claims, not premises. Locked items not reopened: ESC-02 (escalation I→V, no A on steps 2–3), retired row 14, DeepSeek bind/extra-trees, optimizer ACCEPT, and parent REJECT of Kimi High advisory mediums.

## Lens summary

### Control plane

- **Projector-only ledger:** `hooks/lib/wbs-projector.sh` is the sole writer of WBS/packet/work-spec/plan artifacts; only the Task-capable Orchestrator session may invoke it; children submit role-signed receipts and must not stamp `v_verified` / `val_validated` (line 48). Matches overview §4.1 parent ≠ implementer.
- **Hooks never invoke Task:** Authorizer admits; a Task-capable session starts the child; nested Task is allowed when remaining depth > 0 after the ancestor has written that child's work-spec/WBS; MVP does not launch a nested Orchestrator (lines 44, 271, 273). Parent-proxy at remaining depth 0 via `hooks/lib/sb-spawn-proxy.sh` at exactly `$primary_checkout/.planning/sb-spawn-proxy.jsonl`; CAS consume with claimant-epoch lease for consumed-without-`launched` (lines 277–279). No Authorizer-spawns-Authorizer deadlock (bootstrap admits the first Orchestrator-driven spawn).
- **Mandatory control-plane children** (Advisor planning, on-demand consult, A-loop Mentors, Verifier, Process-final Validator, Process-synthesis, Process-repair) are enumerated; generated denies must never fence those edges out (line 299). Unplanned Step→Advisor consults are Orchestrator-spawned (clarify note 13), not a second Process router.
- **Quality-loop order:** Advisor-first one-way planning; I-clean judged by A-loop (Executor does not self-attest; historical `i_two_clean` is not a gate, line 192); AF/Workflow stop at V with no `val_*` on the ordinary SM (line 193); after the **top** Workflow join: Process-synthesis packet-local I → Process-scope A two-clean → Process-scope V two-clean → Process-final Val (lines 196–197, 202). Inner nested Workflow joins stop at V. Deny-all leaves (`advisor`, `verifier`, `validator`, `defect_escalation`) execute role work, return a signed receipt, and terminate (line 204) — no recursive I/A/V/Val deadlock.
- **Process-synthesis** is packet-local composition/findings only; product I stays with Workflow/AF Executors; Val-fail re-runs 9a–9c with a new `launch_id` and occurrence ordinal so admission CAS cannot ack the prior Process-scope completion (lines 196, 233, 235).
- **Escalation (ESC-02, locked):** steps 2–3 are Executor-shaped I then Verifier V; Process-final Val still runs when implementation occurred; happy-path Validator still does not implement (lines 220–227). Not reopened.

### Hosts / five-tool

- **MVP host adapter = Cursor**; Codex/Claude/OpenCode Orchestrator-as-parent adapters sequence after MVP; existing `sb:agent-*` (including OpenCode agent skill) rename in the MVP ship (lines 50, 80–81, 368). Matches overview §2/§4.3 and clarify Q5 SUPERSEDED. Agent-* skills are not those host adapters.
- **Five-tool policy:** opt-in, then mandatory on every **selected** runtime after init probe; brownfield re-probe; warn+unselect per failing runtime; refuse opt-in only if every recorded runtime fails; Cursor-only MVP does not require Pi five-tool unless Pi is selected (line 372). Matches clarify toolstack SUPERSEDED.
- **Optimizer ACCEPT (locked):** when LeanCTX is in the opted-in stack, the mandated optimizer is `scripts/optimize-five-tool-stack.sh` (may invoke `optimize-rtk-context-mode.sh` as the RTK+CM sub-step); `optimize-rtk-context-mode.sh` alone remains the RTK+CM-only path. Phrase is consistent across 17 `optimize-five-tool-stack.sh` hits (15 with the LeanCTX-orchestrator parenthetical). In-repo script exists. Not re-raised.
- **`$SB_PRIMARY_CHECKOUT` bind:** process env (even when not git main-worktree) → alias unless it points at an extra-tree → `rt_git_main_worktree_root` only when env/alias unset; extra-tree cwd never wins; deny-not-skip when five-tool is opted in. Cursor extra-tree isolation requires operator primary == git main-worktree (else same-tree only). Named red-test cases (1)–(5) present. DeepSeek bind/extra-tree decisions not reopened.
- **Host realism:** spec does not invent a Cursor Task cwd/env API; LPS envelope carries `primary_checkout` / `worktree_cwd`; hooks must not parse the envelope.

### Consistency

- Plan ↔ clarify banner parity: Q4 no dual `/silver`; Q5 Cursor-adapter MVP; Q7 keep public `sb:review-fix-ladder` until Iterate; Q9c/note-15 trust path `~/.silver-bullet/authorizer-trust/<repo-id>/`; Q12 I has no self-attested two-clean; Q14/Q18/Q21/Q22 Val is Process-final only; L64/L158 chains include Process-synthesis I → Process-scope A/V after the **top** Workflow join only.
- No leftover `poa_draft` / executor-draft P-loop / `Pending user lock`. The single `i_two_clean` occurrence is explicitly historical/non-gate. The single `dual /silver` occurrence is the prohibition.
- Blocker table: 32 ordered rows; row 14 `blocked_advisor_state` is a never-matching historical classifier (locked retired); row 32 is ESC-02 step 4 `blocked_user_escalation`. First-match contract stated at line 418.
- Traceability / MVP vs after-MVP split in Document control matches Testing/WS7 exclusion of OFF/ITR/PROD/ING matrix IDs from the MVP live E2E.
- Document integrity self-check holds: exactly 10 frontmatter todos (`capability-contract` … `docs-release`); one `#` title; 19 `##` headings = Overview + Table of contents + 17 TOC entries; two distinct mermaid blocks; no standalone Addendum headings.
- Plan SHA-256 unchanged from the optimizer-ACCEPT ledger; `.planning/` and Cursor-mirror plan copies byte-identical.

## Blockers

None.

## Highs

None.

## Mediums

None that gate this rung. Residual classification wording (line 168 vs rows 13/22 Advisor empty-replacement) and five-tool table row label `I / A / V / Val` were previously raised and parent-rejected as advisory/doc-skim; not re-raised.

## Deliberately not re-raised (locked or parent-rejected)

- ESC-02 escalation I→V without A on steps 2–3.
- Retired row 14 `blocked_advisor_state`.
- DeepSeek M2 / Max H1 `$SB_PRIMARY_CHECKOUT` bind and Cursor extra-tree decisions.
- Composer 2.5 Extra High `optimize-five-tool-stack.sh` naming hole — parent ACCEPT applied; wording verified correct above.
- Kimi K3 High five advisory mediums (parent REJECT).
- Five-tool summary table `I / A / V / Val` row label and `stack-compression-coordinator.sh` omission from the six-gate “share the same bind” list (normative ERR-trap + WS3 already bind the coordinator).

## Non-material observations

- Extreme paragraph repetition on primary-checkout / merge-oracle / Cursor Task env is intentional invariant reinforcement.
- Clarify round-2 historical Q18 row still shows a pre-`advisor_planning` chain; banner + plan supersede — brief hygiene only.
- Nested Task at remaining depth > 0 is sequenced “after the ancestor has written work-spec/WBS”; unplanned consult/repair edges are Orchestrator-spawned (line 299). Implementable without a second request bus; not a control-plane hole.

## VERDICT: CLEAN

Independent Grok 4.6 High pass finds no control-plane deadlock, no host-realism break, no quality-loop contradiction, and no consistency defect against the overview, locked decisions, or plan SHA-256 `3712dc77…`. Optimizer ACCEPT is present and consistently worded. Plan copies left byte-identical.
