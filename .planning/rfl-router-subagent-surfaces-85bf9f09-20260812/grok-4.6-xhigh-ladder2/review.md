# RFL Ladder 2 — Grok 4.6 Extra High / Max — Architecture Review

**Reviewer:** Grok 4.6 Extra High / Max (this Task rung; `cursor-grok-4.6-xhigh`; not delegated; not High)
**Date:** 2026-08-15
**Branch:** `main` (no switch; no plan edits; no commit)
**Read order:** [SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md](../SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md) (read in full first) → [router_subagent_surfaces_85bf9f09.plan.md](../../router_subagent_surfaces_85bf9f09.plan.md) (653 lines, read in full) → [router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md](../../router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md) (read in full, including superseded addenda)
**Plan SHA-256:** `3712dc7731fdaa462ca0079a4c8a1fee53118d8b9c4cf94c478a60b0204a86ec` — matches the Composer 2.5 Extra High ACCEPT ledger value; `sha256` on repo copy and `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` match; `cmp` byte-identical.
**Graphify:** `graphify query "router subagent surfaces control plane five-tool hosts consistency RFL 85bf9f09"` (orientation; 149-node subgraph, truncated). Graphify MCP was down; CLI used.
**agentmemory:** MCP `memory_save` not wired in this session; REST `POST http://localhost:3111/agentmemory/remember` used (health 200).
**Lenses:** control plane; hosts/five-tool; consistency.

## Independence statement

This Extra High / Max pass re-read the mandatory overview, the full plan body, and the clarify brief, then independently re-derived the contract. Grok 4.6 High CLEAN was treated as a falsifiable claim, not a premise. Direct checks:

- Plan integrity: SHA-256 `3712dc77…` on both copies; mirror byte-identical; 653 lines; exactly 10 frontmatter todos (`capability-contract` … `docs-release`); single `#` title; 19 `##` headings = Overview + Table of contents + the 17 TOC entries, each present once; `### Document integrity` is an h3 under Traceability; two distinct mermaid blocks.
- Blocker enum: 32 ordered rows (`blocked_corrupt_state` … `blocked_user_escalation`); every `blocked_*` ID in the body resolves to a table row; row 14 `blocked_advisor_state` retained as never-matching historical classifier (not reopened); row 32 is ESC-02 step 4.
- Quality-loop order: Advisor-first one-way handoff; I has no self-attested two-clean (single `i_two_clean` is historical/non-gate); A/V two-clean; AF/Workflow stop at V (no `val_*` on the ordinary SM); after the **top** Workflow join, Process-synthesis packet-local I → Process-scope A two-clean → Process-scope V two-clean → Process-final Val; inner nested Workflow joins stop at V. Zero `poa_draft` residue. Deny-all leaves terminate after a signed receipt.
- Optimizer ACCEPT (locked): `scripts/optimize-five-tool-stack.sh` named 17 times as the LeanCTX-opted-in orchestrator (may invoke `optimize-rtk-context-mode.sh` as RTK+CM sub-step); both scripts exist in-repo. Not re-raised.
- Primary-checkout / extra-tree bind and Cursor TAT gating verified consistent across todos, Overview, Dispatch, WBS, Hosts, row 8, WS3/WS6, and named red-test cases (1)–(5). DeepSeek bind/extra-tree decisions not reopened.
- Plan↔clarify supersession banner parity (Q4/Q5/Q7/Q9c/Q11/Q12/Q14/Q18/Q21/Q22, note 15, toolstack, nested Task + parent-proxy) holds.

Locked items were not reopened: ESC-02 (I then V, no A on steps 2–3); retired row 14; DeepSeek bind/extra-trees; optimizer ACCEPT; parent REJECT of Kimi High advisory mediums.

## Lens summary

### Control plane

- **Projector-only ledger:** `hooks/lib/wbs-projector.sh` is the sole writer of WBS/packet/work-spec/plan artifacts; only the Task-capable Orchestrator session may invoke it; children submit role-signed receipts and must not stamp `v_verified` / `val_validated`. Matches overview §4.1.
- **Spawn split:** hooks/scripts never invoke `Task`; nested Task when remaining depth > 0 **after** the ancestor has written that child's work-spec/WBS; parent-proxy mandatory at remaining depth 0 via `hooks/lib/sb-spawn-proxy.sh` at exactly `$primary_checkout/.planning/sb-spawn-proxy.jsonl`; CAS consume with claimant-epoch lease for consumed-without-`launched`. Bootstrap admits the first Orchestrator-driven spawn (no Authorizer-spawns-Authorizer deadlock).
- **Quality-loop order and Process-scope 9a–9c:** consistent with overview §5 and clarify L64/L158. Val-fail invalidates `process_synth_*` / `process_a_*` / `process_v_*` and re-runs 9a–9c with a new `launch_id` and occurrence ordinal.
- **Hole (this rung):** the spawn split plus projector-only writes do **not** give an executable path for an in-flight Executor to obtain a **new** Authorizer-admitted control-plane child (on-demand Advisor consult during `i_running`) while remaining depth is still > 0. See Highs.

### Hosts / five-tool

- **MVP host adapter = Cursor**; Codex/Claude/OpenCode Orchestrator-as-parent adapters after MVP; `sb:agent-*` rename (including OpenCode) in the MVP ship. Cold `/sb:agent-*` mints a Process wrap then runs as an Executor-shaped leaf with Advisor-first handoff. Matches overview §2/§4.3 and clarify Q5 SUPERSEDED. Spec does not invent a Cursor Task cwd/env API.
- **Five-tool:** opt-in → mandatory on every **selected** runtime after init probe; brownfield re-probe; warn+unselect per failing runtime; refuse opt-in only if every recorded runtime fails; Cursor-only MVP does not require Pi five-tool unless Pi is selected.
- **Optimizer ACCEPT:** verified present and uniformly worded. Not re-raised.
- **`$SB_PRIMARY_CHECKOUT` bind:** env (even when not git main-worktree) → alias unless extra-tree → `rt_git_main_worktree_root` only when env/alias unset; extra-tree cwd never wins; deny-not-skip when five-tool opted in. ERR-trap list includes `stack-compression-coordinator.sh`; WS3 binds the coordinator even where the six-gate “share the same bind” list omits it (parent-rejected as doc skim; not re-raised).

### Consistency

- No leftover dual `/silver` window, executor-draft P-loop, or AF/Workflow `val_*` SM. Trust path is `~/.silver-bullet/authorizer-trust/<repo-id>/` (remaining `remote_id_sha256` mentions are the historical digest name, not a path suffix).
- MVP vs after-MVP split in Document control matches Testing/WS7 exclusion of OFF/ITR/PROD/ING freeze-drain from the MVP live E2E.
- Document integrity self-check holds (10 todos, 19 `##`, 32-row blocker table, two mermaid blocks). Plan copies left byte-identical.

## Blockers

None.

## Highs

1. **In-flight unplanned control-plane spawn vs projector-only (control plane).** POA-01 on-demand Advisor consult is executor-initiated during ordinary `i_running` (plan lines 208–210), Authorizer-admitted, and listed among mandatory control-plane children whose generated denies must never fence the edge out (line 299; clarify note 13: Orchestrator session spawns). Admission requires an on-disk work-spec persisted **only** by the Task-capable Orchestrator invoking `hooks/lib/wbs-projector.sh` (lines 48, 180–181, 273, 277). Nested Task children never invoke the projector (line 273). Dispatch spawn physics then split:
   - remaining depth > 0 → the **child** launches the grandchild with nested Task **after** the ancestor has already written that child's work-spec/WBS (line 273);
   - remaining depth = 0 → parent-proxy jsonl + **requester yield**, so the ancestor gets a turn, persists the work-spec on consume, and starts the child (lines 275–279).

   On Cursor, a Task-capable Orchestrator that started the Executor with nested Task is blocked until that Task returns. SessionStart/Stop that “does not invoke Task” does not give the ancestor a projector turn while it is waiting on the Executor Task. Therefore, at remaining depth > 0 during `i_running`:
   - the Executor cannot nested-Task the consult (no pre-written work-spec; child cannot write one);
   - the Executor cannot use parent-proxy as specified (that protocol is gated to remaining depth 0);
   - even if the Executor appended jsonl without yielding, the ancestor cannot consume or invoke the projector until the Executor Task ends.

   Result: the consult edge fail-closes (`blocked_launch_prompt_spec`) or deadlocks. Ordinary I→A→V without consult still works (Orchestrator sequences Mentor/Verifier after I-complete). This is not ESC-02, not row 14, and not the parent-rejected Kimi M3 “remaining-depth field list” nit — it is missing spawn physics for a named MVP obligation.

   **Suggestion:** in Dispatch / nested-orchestration, state that remaining-depth nested Task is only for descendants whose work-spec/WBS the ancestor already persisted **before this child's Task started**. Any in-flight request that needs a **new** projector write (on-demand consult; any other unplanned control-plane child) MUST use parent-proxy jsonl + requester yield **even when remaining depth > 0**, so the ancestor can persist the work-spec on consume and then start the child (nested Task if depth remains on the ancestor's turn, else ancestor Task). Do not allow an in-flight child to nested-Task a grandchild that still lacks an on-disk work-spec.

## Mediums

None that independently gate this rung. Residual classification wording (line 168 vs rows 13/22) and the five-tool table row label `I / A / V / Val` were previously raised and parent-rejected; not re-raised.

## Deliberately not re-raised (locked or parent-rejected)

- ESC-02 escalation I→V without A on steps 2–3.
- Retired row 14 `blocked_advisor_state`.
- DeepSeek M2 / Max H1 `$SB_PRIMARY_CHECKOUT` bind and Cursor extra-tree decisions.
- Composer 2.5 Extra High `optimize-five-tool-stack.sh` naming hole — parent ACCEPT applied; wording verified correct (17 hits; both scripts exist).
- Kimi K3 High five advisory mediums (parent REJECT), including remaining-depth not listed in envelope field lists (M3) — distinct from High 1 above.
- Five-tool summary table `I / A / V / Val` row label and `stack-compression-coordinator.sh` omission from the six-gate “share the same bind” list (normative ERR-trap + WS3 already bind the coordinator).

## Non-material observations

- Extreme paragraph repetition on primary-checkout / merge-oracle / Cursor Task env is intentional invariant reinforcement; restatements agree.
- Clarify round-2 historical Q18 row still shows a pre-`advisor_planning` chain; banner + plan supersede — brief hygiene only.
- Grok 4.6 High treated unplanned consult as “Orchestrator-spawned (line 299) … implementable without a second request bus.” Extra High does not inherit that: line 299 enumerates admitted children; it does not authorize nested Task without a pre-written spec, and it does not extend parent-proxy+yield to remaining depth > 0.

## VERDICT: NOT CLEAN

Independent Grok 4.6 Extra High / Max pass finds the hosts/five-tool and consistency lenses clean against the overview, locked decisions, and plan SHA-256 `3712dc77…`. Control plane has one **High**: in-flight on-demand Advisor consult at remaining depth > 0 has no executable spawn path under projector-only writes. Optimizer ACCEPT, ESC-02, retired row 14, and DeepSeek bind/extra-trees were not reopened. Plan copies left byte-identical.

1. In-flight unplanned control-plane spawn vs projector-only (on-demand consult at remaining depth > 0).
