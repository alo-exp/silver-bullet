# RFL Ladder 3 — Kimi K3 High — Architecture Review

**Reviewer:** Kimi K3 High (`sb-kimi-k3-high`; this rung model — no Grok substitute)
**Date:** 2026-08-16
**Branch:** `main` (no switch; no plan edits; no commit)
**Read order (full, in order):**
1. [SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md](../SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md)
2. [router_subagent_surfaces_85bf9f09.plan.md](../../router_subagent_surfaces_85bf9f09.plan.md) (657 lines, read in full in five chunks)
3. [router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md](../../router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md) (259 lines, read in full)

**Plan SHA-256 (frozen):** `5f8b3abd51f172adf226f7f422c9a8a7cd1eae56434bcb4435534a5d13bb7d9c` — verified `shasum -a 256` on **both** copies before review; re-verified identical after review (no drift, no edits).
**Mirror parity:** repo `.planning/` copy and `~/.cursor/plans/` copy carry the identical frozen SHA.
**Graphify:** `graphify query "router subagent surfaces Orchestrator Executor Advisor Verifier Validator"` (164-node scoped subgraph, orientation before any Read/Grep).
**Prior rungs consulted as falsifiable claims only:** Gemini 3.7 Flash High ladder-3 CLEAN (same frozen SHA); Composer 2.5 High/XHigh and GLM 5.2 High/XHigh ladder-3 CLEAN (earlier SHA `d4f1d2d3…`); Kimi K3 High ladder-2 (5 Mediums — all verified incorporated in the frozen bytes: rows 13/22 Advisor-classification fix, SessionStart-unproven honesty + Doctor bind-path reporting, `<<<SB_REMAINING_DEPTH>>>` envelope marker + record field, ESC-02 same-tuple Doctor reporting, unconditional live-E2E overlap-worktree construction).

## Independence statement

This pass re-derived every check from the frozen bytes rather than accepting prior CLEAN verdicts. Automated checks run locally against the frozen working copy:

- **Blocker enum:** 33 table rows (`| N | \`blocked_*\``), 33 unique `blocked_*` IDs in the document, `diff` of the two sets = **0 orphans either direction**. Rows 7 (`blocked_replan_budget`) and 14 (`blocked_advisor_state`) correctly historical/retired non-classifying; row 33 (`blocked_primary_checkout_unbound`) cleanly disjoint from row 4 by mutual exclusion clauses.
- **Structure:** exactly 10 frontmatter todos; 1 `#` title; 19 `##` headings = Overview + Table of contents + the 17 TOC entries, zero duplicates; 2 distinct mermaid blocks; no `## Pending user lock`; no standalone Addendum headings.
- **Term hygiene:** 0 `poa_draft`; 0 `verify_1`/`verify_2`; single `i_two_clean` mention is the explicit "Historical … is not a gate" negation; all 4 `Most Competent` mentions are negations; all 8 `silver:` mentions are historical/rename contexts (no active dual-prefix).
- **Locked items not reopened:** ESC-02 escalation I then V with **no A-loop** on steps 2–3 (3 consistent mentions); same `{ runtime, model, effort }` across Advisor/Executor allowed, row 14 retired (warn-only); Process-scope V terminal is `process_v_verified`, **not** `process_v_two_clean` (0 occurrences of the latter).
- **Delta vs committed HEAD** (`c2f7aa73…`): frozen bytes add `SB_REMAINING_DEPTH`/`remaining_depth` (0→8), row 33 (0→16), ESC-02 step-3 Doctor reporting (0→5), parent-proxy `requester_continuation_id` (0→10), `failed`→`resumed` (0→13), `plan_revision` binding (0→8), `sb:agent-wrap`/`AF-agent-delegate`/`nested_executor` (0→4 each) — i.e. the frozen SHA carries the full ladder-2 incorporation set; nothing reviewed here is stale.

## Lens summary

### Control plane
- Single-writer discipline holds: `hooks/lib/wbs-projector.sh` (WBS/packet/work-spec/plan artifacts, Orchestrator-session-only caller) and `hooks/lib/sb-spawn-proxy.sh` (jsonl + hash-bound staging payloads) are the only ledger writers; children submit role-signed receipts; helpers fail-closed unless write-root == `$SB_PRIMARY_CHECKOUT`. Parent-guard allowlist matches the three helper surfaces.
- Parent-proxy lifecycle is closed and crash-recoverable: `pending`→`prepared` (hash-bound payload staged, never hashes-only yield) → `consumed` (atomic with `launch_intent` + `launch_id`/`prompt_ref`/`work_spec_path` persist, or claimant-epoch lease with consumed-without-`launched` reconciliation) → `launched`→`completed` / `launched`→`failed` (distinct receipt kinds, no `completed(outcome=failed)` second protocol) → idempotent `completed`→`resumed` / `failed`→`resumed` put-if-absent on `requester_continuation_id`; CORR-17 covers all four crash windows; `blocked_callback_unresolved` fail-closed on Cursor rebind failure. No stranded-requester path found.
- Deadlock freedom: deny-all control-plane leaves (`advisor`, `verifier`, `validator`, `defect_escalation`, `knowledge_postwrite`) exempt from recursive I/A/V/Val; bootstrap admits first Orchestrator spawn (no Authorizer-spawns-Authorizer); `blocked_depth_unsupported` only when even parent-proxy is impossible; nested Task restricted to pre-written descendants.
- Quality order matches overview §5 and the clarify banner exactly: Advisor-first one-way handoff → I (no self-attest) → A two-clean → V (AF/Workflow stop; no `val_*` on ordinary SM) → code-only merge if extra tree → top Workflow join → 9a Process-synthesis packet-local I → 9b Process-scope A two-clean → 9c Process-scope V two-clean → Process-final Val → KLW-01 post-write leaf. Val-fail vs Process-scope-A/V-dirty 9a–9c re-run paths are correctly distinguished (both mint new `launch_id`; only Val-fail re-enters Process-final Val), with occurrence-ordinal advance closing the early-dedupe CAS collision.
- Admission CAS consistency re-verified: ledger keyed by `launch_id` (put-if-absent) with `(prompt_hash, work_spec_hash)` as the payload-identity pair within a launch; new-`launch_id` re-runs therefore cannot ack the prior Process-scope completion as duplicates — internally consistent with the "launch-payload CAS key remains `(prompt_hash, work_spec_hash)`" locked text (the pair is per-launch payload identity, not a global dedupe key; occurrence ordinal is callback/effect identity, not the admission key).

### Hosts / five-tool
- MVP = Cursor host adapter + `sb:agent-*` rename + bootstrap migrate (ILM-01) + live E2E; Codex/Claude/OpenCode parent-host adapters post-MVP — matches overview §2/§4.3 and clarify Q5 SUPERSEDED. `nested_executor` catalog class under `sb:agent-wrap`/`AF-agent-delegate` closes the second-router hole; WS1 validation accepts it as Process-owned.
- Cursor host realism is honest: no invented Task cwd/env API; SessionStart env-export explicitly flagged unproven with env → alias-not-extra-tree → `rt_git_main_worktree_root` precedence and Doctor bind-path reporting; TAT requires operator primary == git main-worktree on Cursor (else same-tree isolation); the ledger-omit-present/absent discriminator cleanly separates operator linked-worktree (row 33 fail-closed) from TAT extra-tree (fallback legal).
- Merge oracle mechanics are implementable as specified: pre-oracle product commit on the worktree branch; `blocked_corrupt_state` on tracked ledger-omit diffs (`merge-base..worktree-branch`) and/or filesystem presence; `git merge --no-ff --no-commit` + pre-merge primary working-tree snapshot restore (correct: `git merge` has no pathspec); clean-index requirement on every join including the first; `--no-ff` prevents silent fast-forward skipping `MERGE_HEAD`; post-merge `graphify update` at `$primary_checkout` before Process-final Val.
- Five-tool policy consistent across all restatements: opt-in → init probe before record → brownfield re-probe with warn+unselect (refuse only if all fail); unselect fail-closes five-tool gates only and keeps role keys; `optimize-five-tool-stack.sh` mandated when LeanCTX is opted in, with `optimize-rtk-context-mode.sh` qualified as RTK+CM-only sub-step at every co-located occurrence.

### Consistency
- Plan ↔ clarify banner parity: all superseded Qs (Q4 dual-prefix, Q5 hosts, Q7 RFL delete, Q9c trust path, Q11 packaging, Q12 I-two-clean, Q14/Q18/Q21/Q22 Val scope, note 15 path suffix) match plan body; clarify L65/L159 chains include Process-synthesis I + Process-scope A/V after the **top** Workflow join only.
- Traceability: "Preserve retained `VAL/TST-RFL-001..007, 101..118, 201..205, 301..306, 401..405, 501..506, 601..619, and 900`" — matrix contains CAT-A..G (7), CORR-01..18 (18), PREV-01..05 (5), FIX-01..06 (6), NEW-01..05 (5), CUR-01..06 (6), and all 19 of 601–619 (EFF/ADM/ING/MIG/ILP/PROD/TRUST/OFF/ITR/ILM/ESC-01/ALP/KLW/VLP/VALP/LPS/WBS/POA/ESC-02); meta `VAL/TST-RFL-900` + `BOOT-RFL-001` present; MVP vs post-MVP scoping consistent across Document control, §Testing, and WS7.

## Blockers

None.

## Highs

None.

## Mediums

Both are advisory one-line wording fixes; neither contradicts a locked decision, neither gates executability of the MVP slice. Same caliber as the ladder-2 Mediums that were incorporated.

### M1 (consistency) — Ratified ordinary V-loop intermediate state `v_two_clean` never named in the plan

Clarify Q13 is **ratified** (not superseded): "V-loop requires two consecutive clean; ordinary SM uses `v_running`/`v_two_clean`/`v_verified` (`v_verified` = two-clean terminal)". The frozen plan names the two-clean intermediate state for A (`a_running`/`a_two_clean`, line 192) and for Process-final Val (`val_running`/`val_two_clean`/`val_validated`, line 197), and for Process-scope A (`process_a_running`/`process_a_two_clean`) — but for the ordinary AF/Workflow V-loop it says only "Verifier V-loop until two-clean / `v_verified`" (line 193) and "AF-level `v_running` → `v_verified`" (line 202). `v_two_clean` has **0 occurrences** in the plan (and was absent at committed HEAD too, so this is a long-standing asymmetry, not a recent regression). An SM implementer cannot tell from the plan whether the first-clean-round is a named state or a counter inside `v_running`, while the ratified clarify names it. One-line fix: name the ordinary V SM states `v_running` / `v_two_clean` / `v_verified` in ordinary-delivery step 6 (mirrors the A-loop sentence). This does **not** touch the locked Process-scope terminal `process_v_verified`.

### M2 (control plane) — spawn-proxy record `remaining_depth` has no named write transaction

`remaining_depth` is defined as "the launched child's **post-launch** host-API remaining depth" (lines 6, 273) and is a required spawn-proxy record field (line 277: "Each record includes at least: … `remaining_depth` …"). But the two named write transactions don't cover it: the requester-written `pending`→`prepared` transaction cannot carry a correct value (the requester knows only its own envelope depth; the proxied child's post-launch depth depends on the *launching ancestor's* host depth, unknowable to the requester), and the enumerated consume/`launch_intent` MUST-persist list names only `launch_id`, `prompt_ref`, `work_spec_path`. The only consistent implementation is that the ancestor stamps `remaining_depth` during the consume/launch CAS-extension (it builds the child envelope there, which already requires the same value), but the text never says so — an implementer reading "each record includes … `remaining_depth`" beside the `prepared`-before-yield rule could conclude the requester must supply it at `prepared`, which is impossible to do correctly. One-line fix: add `remaining_depth` to the consume/launch MUST-persist list (or state explicitly that the ancestor CAS-extends the row with it at host launch).

## Deliberately not raised

- `stack-compression-coordinator.sh` not a column in the five-tool table (footnote + ERR-trap prose carry it; parent-rejected ladder-2 doc skim per Composer XHigh / GLM XHigh ladder-3).
- Admission CAS `(prompt_hash, work_spec_hash)` vs `launch_id`-keyed ledger interaction (locked; internally consistent under per-launch payload-identity reading, verified above).
- Extreme paragraph repetition of the primary-checkout / merge-oracle / parent-proxy invariants (intentional invariant reinforcement; same observation as five prior rungs).
- Clarify brief historical rows showing pre-`advisor_planning` chains (banner + plan supersede; brief hygiene only, not a plan defect).

## agentmemory

`user-agentmemory` MCP is not wired in this subagent session (tool catalog lookup for `agentmemory`/`memory_save` returned no server). Per the ladder-3 precedent (Composer XHigh, GLM XHigh), capture of this review outcome is deferred to the parent/orchestrator session where the MCP is available.

## Verdict

**CLEAN** — no Blockers, no Highs; two advisory Mediums (M1 `v_two_clean` state naming vs ratified Q13; M2 spawn-proxy `remaining_depth` write transaction), both one-line wording fixes recommended for the next plan-maintenance pass and neither gating the rung.

The plan at frozen SHA `5f8b3abd51f172adf226f7f422c9a8a7cd1eae56434bcb4435534a5d13bb7d9c` is internally consistent, deadlock-free, host-realistic for the Cursor MVP slice, and faithful to the clarify supersessions and locked decisions. Prior ladder-3 CLEAN verdicts were independently re-derived, not rubber-stamped; Gemini's same-SHA CLEAN was treated as a falsifiable claim and re-verified check-by-check.
