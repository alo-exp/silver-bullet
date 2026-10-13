# RFL Ladder 2 — Kimi K3 High — Architecture Review

**Reviewer:** Kimi K3 High (this Task rung; replacement for stalled worker `7721c788`, which produced no artifact)
**Date:** 2026-08-15
**Branch:** `main` (no switch; no plan edits; no commit)
**Read order:** [SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md](../SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md) → [router_subagent_surfaces_85bf9f09.plan.md](../../router_subagent_surfaces_85bf9f09.plan.md) (652 lines, read in full) → [router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md](../../router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md) (read in full)
**Plan SHA-256:** `3712dc7731fdaa462ca0079a4c8a1fee53118d8b9c4cf94c478a60b0204a86ec` — matches the ledger value recorded at the Composer 2.5 Extra High rung (no plan drift since).
**Mirror parity:** `cmp` confirms `.planning/` and `~/.cursor/plans/` copies byte-identical (plan line 652 requirement holds).
**Graphify:** `graphify query "router subagent surfaces plan RFL ladder review escalation"` (orientation; 113-node subgraph, truncated to budget).
**Lenses:** control plane; hosts/five-tool; consistency.

## Independence statement

This pass re-read the mandatory overview, the full plan, and the clarify brief, then independently verified: (a) spawn/projector/spawn-proxy writer discipline and deadlock-freedom; (b) quality-loop order (Advisor-first one-way handoff, I no self-attest, A/V two-clean, AF/Workflow stop at V, Process-synthesis packet-local I, Process-scope 9a–9c, Process-final Val only); (c) MVP host scope (Cursor adapter + `sb:agent-*` rename; Codex/Claude/OpenCode post-MVP); (d) five-tool opt-in → init-probe → brownfield re-probe/warn-unselect policy and `$SB_PRIMARY_CHECKOUT` bind precedence; (e) blocker enum (32 rows) and first-match contract; (f) plan↔clarify supersession banner parity (L64/L158 chains include Process-synthesis I + Process-scope A/V); (g) structural integrity (exactly 10 todos; single `#` title; 19 `##` headings = Overview + Table of contents + 17 TOC entries; no duplicate `##` headings; two distinct mermaid blocks). Prior verdicts were treated as falsifiable claims, not premises. Locked items not reopened: ESC-02 (escalation I→V, no A on steps 2–3), retired row 14, DeepSeek M2 / Max H1 acceptances (bind precedence, Cursor extra-trees), Composer 2.5 XHigh ACCEPT (`optimize-five-tool-stack.sh` when LeanCTX opted in — verified present and consistently worded across all plan occurrences), and first-ladder Kimi ACCEPTs (top Workflow join, clarify L64/L158, Overview/WBS enumerations, LPS-01 `scope_bounds`, Verifier Process-scope V).

## VERDICT: CLEAN

No Blockers, no Highs. Five Mediums follow — all advisory hardening items; none contradicts a locked decision, none blocks executability of the MVP slice, and each is either already covered by a named workstream/todo or fixable with a one-line wording change. I recommend incorporation at the next plan-maintenance pass but do not gate the rung on them.

## Blockers

None.

## Highs

None.

## Mediums

### M1 (consistency) — Advisor-unavailable classification ambiguity between blocker rows 13 and 22

The failure-table contract (plan line 418) is: "Every failure classifies to exactly one canonical `blocked_*` by the first matching row of this ordered table." For an Advisor empty-replacement hard stop, three texts interact badly:

- Roles section (line 168): "the same hard stop for Advisor and Validator (`blocked_child_unavailable` / `blocked_validation_state` as the first matching row)".
- Row 13 (`blocked_validation_state`, line 434): trigger covers Val/Validator and adds "Advisor empty replacement after notify uses `blocked_child_unavailable` when rows 11–12 do not match" — a row whose trigger redirects to a *different* row's blocker ID.
- Row 22 (`blocked_child_unavailable`, line 443): "Residual required **non-role-specialized** child cannot be launched when rows 11–21 do not match."

The outcome ID (`blocked_child_unavailable`) is determinable, but the mechanics bend the first-match contract: if row 13 "matches" for Advisor, it yields a foreign blocker ID (row 13's own label is `blocked_validation_state`); if row 13 does not match, row 22's precondition "rows 11–21 do not match" is satisfied but its predicate excludes role-specialized children — and Advisor is a named preference-key role, i.e. role-specialized. Net: the Advisor case has a stated ID but no cleanly-matching row. One-line fix: drop "non-role-specialized" from row 22, or add an explicit Advisor clause to row 22 and delete the redirect clause from row 13.

### M2 (hosts/five-tool) — `SB_PRIMARY_CHECKOUT` SessionStart env-export is an unproven Cursor capability assumption

The plan repeatedly relies on: "Session-start on the Task-capable ancestor exports process env `SB_PRIMARY_CHECKOUT` for subsequent hooks in that ancestor session" (lines 48, 180, 283, 303, 322, 357–360, 372, 487, and WS3/WS6). Cursor hook processes are spawned per invocation; a SessionStart hook can only influence the environment of later, separately-spawned hook processes if the host persists hook-emitted env — the spec itself hedges elsewhere ("not a documented descendant Task env"; "do not invent a Cursor Task env API") but never establishes the *ancestor-session* env-persistence mechanism.

The design degrades safely: env unset → `rt_git_main_worktree_root` fallback, and TAT's `primary == git main-worktree` requirement makes fallback == primary whenever extra trees exist. Worst case is fail-closed (not mis-bind) for an operator whose primary is a non-main linked worktree — a configuration the plan explicitly supports for same-tree isolation ("if operator primary is a non-main linked worktree, TAT does not create extra trees — same-tree isolation only"). For that configuration with a non-functional env channel, helper write-root comparisons against env-or-fallback fail closed on every helper write. This is adjacent to but distinct from the locked DeepSeek M2 acceptance (which fixed bind *precedence*; this is about whether the env *channel exists* on the MVP host). Recommendation: the `capability-contract` todo / MVP live E2E should explicitly prove SessionStart→subsequent-hook env visibility on Cursor, and Doctor should report which bind path (env vs git-main fallback) resolved.

### M3 (control plane) — remaining-depth input not carried in envelope or spawn-proxy record field lists

Children decide nested-Task vs parent-proxy from "remaining depth" (lines 44, 273). Neither the launch-envelope marker list (`<<<SB_LAUNCH_PROMPT>>>` / `<<<SB_WORK_SPEC_JSON>>>` / `<<<SB_PRIMARY_CHECKOUT>>>` / `<<<SB_WORKTREE_CWD>>>` / `<<<SB_END>>>`, lines 285–295) nor the parent-proxy record fields (line 277: `request_id`, `requesting_child_launch_id`, `wbs_node_id`, `role`, `route`, hashes, `{runtime,model,effort}`, `primary_checkout`, `worktree_cwd`, `created_at`, `status`) carry current or remaining host-nesting depth. WBS ancestry is not a substitute: host-API depth is consumed by role-leaf launches (Advisor planning, consults, A-loop Mentors, Verifier V) that do not add WBS Workflow/AF levels, so WBS depth ≠ host depth in general. The record list says "at least" (room to add), and the `capability-contract` todo names depth as a thing to prove, so this is a completeness gap rather than a contradiction — but the envelope marker list is presented as exact. Recommendation: add a depth/remaining-depth field to the envelope and the spawn-proxy record, or state explicitly where the child reads it from.

### M4 (control plane) — escalation step-3 self-validation is spec'd but uninstrumented

On the finite four-step ladder, step 3 runs the Validator model as an Executor-shaped I then V, and "the same `{ runtime, model, effort }` as the step-3 implementer is allowed (Val is not an independent second Validator identity in MVP)" (line 227). This is an explicit, deliberate carve-out (role table line 145 mirrors it), so it is not a contradiction — but it means that on the most degraded delivery path, the *only* fit-for-purpose check (Process-final Val) may be self-graded by the same weights that produced the implementation. The product promise in the overview (§5: Validator is the independent final fitness gate) is weakest exactly where failure already occurred twice. Recommendation (non-gating): Doctor should report when Process-final Val identity equals a step-3 implementer identity, and post-MVP should prefer a distinct Validator identity on the escalation path. Flagging for visibility; the MVP trade-off itself is accepted as spec'd.

### M5 (consistency) — MVP live-E2E overlap-worktree requirement is conditional in §Testing, unconditional in acceptance

§Testing (line 487): the live E2E "MUST include one overlap-worktree scenario **when the heuristic fires**" (conditional). WS7 / MVP acceptance (line 559) and the `validation-tests` frontmatter todo require "live E2E **including** overlap-worktree scenario" (unconditional). On the MVP host all three heuristic inputs are operator-arrangeable (disjoint Advisor touch-sets, ≥2 Executors, primary == git main-worktree), so the scenario is always constructible; the conditional phrasing in §Testing lets an implementer claim "the heuristic didn't fire" and skip the mandated merge-oracle / snapshot-restore / `graphify update` evidence path. One-line fix: §Testing should say the E2E must be constructed so the heuristic fires.

## Lens summary

### Control plane

- Projector-only ledger (`hooks/lib/wbs-projector.sh`, sole Orchestrator-session caller, receipts-not-writes) and spawn-proxy helper (`hooks/lib/sb-spawn-proxy.sh`, exactly `$primary_checkout/.planning/sb-spawn-proxy.jsonl`, CAS `pending→consumed` atomic with `launch_intent` persist or claimant-epoch lease with consumed-without-`launched` reconciliation, line 279) — crash-safe; no raw Edit/Write path; hooks never invoke `Task`.
- No deadlock paths found: deny-all leaf roles exempt from recursive I/A/V/Val (line 204); bootstrap admits first Orchestrator-driven spawn (no Authorizer-spawns-Authorizer); consumed-without-launch is explicitly banned; `blocked_depth_unsupported` fires only when even parent-proxy is impossible.
- Quality-loop order matches overview §5 and the clarify banner exactly, including the 9a–9c invalidation + new `launch_id`/occurrence-ordinal re-run after Val-fail (lines 196, 235, 237) — duplicate-ack CAS hole is closed.
- Blocker table is 32 rows, ordered, with resume targets; rows 7 and 14 correctly historical/retired; `migration_not_activated` correctly non-`blocked_*`.

### Hosts / five-tool

- MVP = Cursor host adapter + `sb:agent-*` rename; Codex/Claude/OpenCode parent-host adapters post-MVP — matches overview §6 read-order and clarify Q5 SUPERSEDED. `sb:agent-*` cold-invoke Process-wrap then Executor-leaf semantics (line 359) close the second-router hole.
- Five-tool: opt-in → mandatory per selected runtime after init probe; brownfield re-probe with warn+unselect (not global refuse unless all fail); unselect fail-closes five-tool gates only; INDEX fallback preserved for K/L; unselect does not delete role keys; failing Pi probe does not block Cursor — internally consistent across lines 12, 188, 372, 429 (row 8), 553, and KLW-01.
- Composer-XHigh ACCEPT verified live: `optimize-five-tool-stack.sh` as the LeanCTX-opted-in orchestrator with `optimize-rtk-context-mode.sh` as RTK+CM-only sub-step is worded identically in every occurrence grepped.
- `$SB_PRIMARY_CHECKOUT` precedence (env → non-extra-tree alias → `rt_git_main_worktree_root` fallback; extra-tree cwd never wins; deny-not-skip when five-tool opted in) is consistent across todos, §WBS, row 8, WS3/WS6, and named red-test cases (1)–(5). Residual env-channel assumption flagged as M2.

### Consistency

- Plan ↔ clarify banner parity verified: L64 and L158 chains both include Process-synthesis I → Process-scope A/V after the **top** Workflow join only; Q12/Q14/Q18/Q21/Q22 supersessions match plan text; Q9c/note-15 trust path matches `~/.silver-bullet/authorizer-trust/<repo-id>/` with host-as-metadata.
- Traceability: "Preserve retained `VAL/TST-RFL-001..007, 101..118, 201..205, 301..306, 401..405, 501..506, 601..619, 900`" — every ID in that enumeration is present in the matrix; EFF/ADM/ING/MIG/ILP/PROD/TRUST/OFF/ITR/ILM/ESC/ALP/KLW/VLP/VALP/LPS/WBS/POA keys map to their stated validators/tests; MVP vs post-MVP scoping is consistent between Document control, §Testing, and WS7.
- Document integrity self-checks pass: exactly 10 todos; one `#` title; 19 `##` headings = Overview + Table of contents + the 17 TOC entries; no duplicate `##`; two distinct mermaid blocks; no standalone Addendum headings.
- Plan SHA-256 unchanged from the Composer rung ledger value; repo and Cursor-mirror copies byte-identical.
