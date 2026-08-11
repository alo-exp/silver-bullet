# Clarify Brief — router_subagent_surfaces_85bf9f09

**UTC file stamp:** 2026-07-17T14:37:57Z (session local 2026-07-18)
**Clarify run:** 2026-07-17T14:37:57Z (interactive `/silver:clarify`, Grok 4.5 High)  
**Round-2 incorporation:** 2026-07-20 (Grok 4.5 High) — Q12–Q22 locked; plan + mirror rewritten byte-identical  
**Source plan:** `.planning/router_subagent_surfaces_85bf9f09.plan.md`  
**Cursor mirror:** `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` (byte-identical after incorporation)  
**Do not overwrite:** `.planning/CLARIFY.md` (multi-AI deep-research brief — unrelated)

---

## Problem Statement

Silver Bullet needs a Process-first `/silver` router architecture with Authorizer-fenced hierarchical execution, nested quality loops (**I → A → V → Val**), Levels 0–3 defect recovery, optional Iterate Ladder, and universal migration — clarified interactively before implementation.

---

## Locked Q&A

| Q | Decision |
|---|----------|
| Q1 | Plan-scoped clarify brief + Decision Addendum in plan; do **not** overwrite multi-AI `.planning/CLARIFY.md` |
| Q2 | Diff-merge repo vs Cursor first (richer Cursor base + clarify wins); then keep both byte-identical |
| Q3 | GLM 5.2 is **not** barred; allow in Planning/Validation defaults; remove blanket bar |
| Q4 | **All AFs and all Workflows** are `silver:<route>` (amend “exactly 18”); ordered membership from full APO catalog |
| Q5 | Day-1 hosts: **Cursor + Codex + Claude Code**; OpenCode deferred |
| Q6 | `critical_policy` only from in-repo reviewed hash-bound SB policies |
| Q7 | **Hard cut** RFL retirement (no dual public RFL) |
| Q8 | **Unlimited** Process-authorized Workflow nesting |
| Q9a | Rename **Broker → Authorizer** |
| Q9b | Runtime-home key storage |
| Q9c | Project ID = filesystem-safe `host/org/repo` from git remote |
| Q10 | **Superseded** by universal Advisor A-loop |
| Q10′ | A-loop **two consecutive clean**; findings → I → re-A before V; V never starts with open Advisor findings |
| Q11 | **Single coordinated release** |

---

## Universal Advisor / A-loop (locked intent)

Canonical order: `pre-read Knowledge/Learnings → P-loop (plan-of-action draft → Advisor review until satisfied) → I-loop(s) → A-loop → (return to I if needed) → V-loop → Validation-loop → post-verify Knowledge/Learnings write → return to parent`.

- Advisor is fundamental and universal (not Marketing-only).
- Enables lower-cost executors + higher-cost Advisors.
- Verifier = strict spec check (never fixes). Advisor = review **and Mentor**.
- **Validation-loop** = Planning/Validation-tier fit-for-purpose judgment (≠ Verification, ≠ Advisor); **always after V**; mandatory at AF, Workflow, and Process; two-clean.
- Mentorship: project → `docs/knowledge/`; portable → `docs/learnings/`.
- Sidekick absorb: host-as-advisor/mentor + AGENTS mentoring semantics; leave out external-agent harness / DLGT / L3 take-over.
- Marketing specialty folded into universal A-loop for v1.

### Toolstack (five-tool routed)

| Step | Graphify | agentmemory | Context Mode | LeanCTX | RTK |
|------|----------|-------------|--------------|--------|-----|
| Pre-read | query (primary retrieve) | optional session recall | filter INDEX/month files | large-file read if needed | n/a |
| I / A / V / Val | query before edits; update after code | save decisions/defects/receipts | analysis of diffs/tests | large-file read | shell compression when opted in |
| Post-verify K/L write | update after doc edits | save write refs | draft assist | not for durable write | n/a |

Synergy: save via agentmemory, retrieve via Graphify. Do not use `lctx_remember` or `lctx_graph` for code.
Alumnium is out of scope for this architecture ship (UI/browser evidence remains a separate opted-in surface).

---

## Recommended defaults (logged, not re-litigated)

- A-loop orthogonal to Levels 0–3.
- Advisor strictly stronger than that scope’s executor.
- Sidekick L3 host take-over out of scope.

---

## Next step

Round-2 clarify **complete** (Q12–Q22 locked). Plan + Cursor mirror incorporated byte-identical. Proceed to implementation when parent orchestrator queues workers. Skip `/silver:context` unless brownfield framing is needed.

---

## Artifacts

| Artifact | Path |
|----------|------|
| This brief | `.planning/router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md` |
| Repo plan | `.planning/router_subagent_surfaces_85bf9f09.plan.md` |
| Cursor mirror | `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` |

---

## Plan-locked appendix (Q12–Q22)

These deepen the plan Locked decisions without reopening Q1–Q11. Authoritative detail remains in `.planning/router_subagent_surfaces_85bf9f09.plan.md` (byte-identical with `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`).

| Q | Decision | Status |
|---|----------|--------|
| Q12 | I-loop requires two consecutive clean outcomes (same two-clean family as A-loop) | **Ratified** (round-2) |
| Q13 | V-loop requires two consecutive clean; ordinary SM uses `v_running`/`v_two_clean`/`v_verified` (`v_verified` = two-clean terminal) | **Ratified** (round-2) |
| Q14 | AF leaf Step runs A-loop two-clean once before AF V; that receipt satisfies the AF A-gate (no duplicate AF A); then AF V; then AF Val (mandatory) | **Ratified** (round-2; Val interaction amended) |
| Q15 | Nine `fitness_charter` fields + four canonical Iterate rung IDs as in plan Locked decisions | **Ratified** (round-2) |
| Q16 | `contracts/iterate-ladder-contract.lock.json` is binding/fence authority for Iterate | **Ratified** (round-2) |
| Q17 | Exact six migration ingress states: `freeze_new_source` → `project_pre_freeze_events` → `seal_drain_watermark` → `drain_old_epoch` → `producer_stopped` → `cutover` | **Ratified** (round-2, answer **A**) |
| Q18 | Ordinary delivery SM: `pre_read_pending` → `p_*` (`poa_draft`/`poa_advisor_review`/`poa_satisfied`) → `i_*` → `a_*` → `v_*` → `val_*` → `kl_post_write_pending` → `scope_complete` | **Ratified** (round-2; amended for Val; P-loop phases aligned round-4) |
| Q19 | Iterate work states are orthogonal to `authority_status` | **Ratified** (round-2) |
| Q20 | `awaiting_revalidation` (in-rung) ≠ `awaiting_baseline_revalidation` (baseline-stale) | **Ratified** (round-2) |
| Q21 | AF Validation-loop (≠ V, ≠ A); **"Val always after V"** → **B**: `I → A → V → Val`; Planning/Validation-tier owner; two-clean | **Ratified** (round-2, answer **B**) |
| Q22 | AF **and** Workflow **and** Process all **must** run Validation-loop, always after V | **Ratified** (round-2, answer **B**) |

---

## Clarify Decision Addendum (round-2 — 2026-07-20) — COMPLETE

Interactive `/silver:clarify` round-2 (Grok 4.5 High). All blockers answered; incorporated into plan + mirror.

### Ratified

- **Q12** — I-loop two consecutive clean (same two-clean family as A-loop)
- **Q13** — V-loop two consecutive clean; SM `v_running` / `v_two_clean` / `v_verified`
- **Q14** — AF leaf Step A-loop two-clean once before AF V; receipt satisfies AF A-gate (no duplicate AF A); then AF V; then AF Val mandatory
- **Q15** — Nine `fitness_charter` fields + four canonical Iterate rung IDs
- **Q16** — `contracts/iterate-ladder-contract.lock.json` is Iterate binding/fence authority
- **Q17** — Answer **A**: exact six ordered migration ingress states
- **Q18** — Ordinary delivery SM includes Val: `pre_read_pending` → `i_*` → `a_*` → `v_*` → `val_*` → `kl_post_write_pending` → `scope_complete`
- **Q19** — Iterate work states orthogonal to `authority_status`
- **Q20** — `awaiting_revalidation` (in-rung) ≠ `awaiting_baseline_revalidation` (baseline-stale)
- **Q21** — Answer **B** / **"Val always after V"**: order `I → A → V → Val`; Planning/Validation-tier owner; two-clean; distinct from A-loop and V-loop
- **Q22** — Answer **B**: AF + Workflow + Process all **mandatory** Validation-loop, always after V at that scope

### Validation-loop (architecture lock)

| Axis | Lock |
|------|------|
| Distinction | Validation ≠ Verification (V-loop) ≠ Advisor (A-loop) |
| Meaning | Fit-for-purpose / right-thing judgment (Planning/Validation tier) |
| Order | Always after V: `I → A → V → Val` then KL post-write |
| Scopes | AF, Workflow, and Process — all mandatory |
| Owner | Planning/Validation-tier validator |
| Two-clean | Yes (same family as I/A/V) |
| Dirty | Return to I; re-satisfy A if needed; re-V if contract affected; re-Val; KL post-write only after Val two-clean |

### Still open

None for round-2.

**Do not** overwrite multi-AI `.planning/CLARIFY.md`. Repo plan and Cursor mirror must remain **byte-identical**.

---

## Clarify Decision Addendum (round-3 — 2026-07-20) — COMPLETE

Interactive requirements lock (Grok 4.5 High). Incorporated into plan + mirror.

### Ratified

- **Launch prompt + work spec (mandatory admission gate)** — Every host subagent launch must include a prompt-engineered launch prompt **and** a well-specified work spec with clear **output** and **outcome** requirements. Fail-closed without them: blocker `blocked_launch_prompt_spec` (no spawn / no lease/capability/channel).
- **Work-spec minimum fields** — `goal_outcome`, `required_outputs`, `acceptance_criteria`, `scope_bounds`, `context_refs` (Knowledge/Learnings/pre-read + packet/ancestry refs). Prompt binds work-spec hash, WBS path, role, denies, callback/return contract.
- **ASCII WBS progress visualization (mandatory UX)** — On every governing-scope step transition and every user-facing status: path `Process > Workflow > AF > Step` (optional ` > Skill`), markers `[x]` complete / `[>]` current / `[ ]` pending / `[!]` blocked. Missing viz → `blocked_progress_viz`.
- Traceability: **LPS-01** (`VAL/TST-RFL-616`), **WBS-01** (`VAL/TST-RFL-617`).

### Still open

None for round-3.

**Do not** overwrite multi-AI `.planning/CLARIFY.md`. Repo plan and Cursor mirror must remain **byte-identical**.

---

## Clarify Decision Addendum (round-4 — 2026-08-12) — COMPLETE

**Naming:** the pre-implementation plan-of-action Advisor gate is called **P-loop (Planning Loop)**.

Interactive requirements lock. Incorporated into plan + Cursor mirror.

### Locked

1. **P-loop / Planning Loop (mandatory, pre-implementation):** After work-spec admission and Knowledge/Learnings pre-read, every worker/executor drafts a durable plan of action, submits it to a stronger-tier Advisor, incorporates feedback until a durable **satisfaction receipt** (plan hash + work-spec hash + launch_id), then may start implementation I-loop. Fail-closed: `blocked_plan_of_action_review`. Distinct from post-I A-loop.
2. **On-demand Advisor consult:** During `i_running`, executor may freely consult Advisor when self-assessed capability is insufficient. Authorizer-fenced; does not auto-mutate work-spec; does not replace plan-of-action satisfaction.
3. **Ordinary SM:** `pre_read_pending` → `poa_draft`/`poa_advisor_review`/`poa_satisfied` → `i_*` → `a_*` → `v_*` → `val_*` → `kl_post_write_pending` → `scope_complete`
4. Traceability **POA-01** / `VAL/TST-RFL-618`

**Do not** overwrite multi-AI `.planning/CLARIFY.md`. Repo plan and Cursor mirror must remain **byte-identical**.

## RFL incorporate notes (2026-08-12)

Clarifying elaborations locked into the plan during adversarial RFL (do not reopen Q-locks):

1. **P-loop scope:** Applies to **ordinary-delivery** implementation workers/executors only (Workflow/AF/Step/Process-synthesis). Deny-all leaf control-plane roles (`advisor`, `verifier`, `validator`, `defect_escalation`) are exempt from plan-of-action drafting/review. **Iterate rung implementers** use charter + baseline admission (not ordinary `poa_*`).
2. **Migration Val receipts:** Legacy RFL maps into I/A/V/**Validation-loop** records; missing Val history uses migration-only `val_loop_not_applicable` (never satisfies live Val gates).
3. **Levels 0–3 repair return:** Successful repair → original owner **I → A → V** (re-A before V), not V-only. Ordinary repair never enters Iterate `awaiting_baseline_revalidation`; Iterate repair does.
4. **Authorizer path fallback:** injective `host/org/repo/<remote_id_sha256>` (full 64-hex digest; no truncated prefix) from canonical remote bytes; `local/default/<repo_dir_sha256>` when git remote absent/unparseable; trust lookup verifies stored canonical identity.
5. **KLW post-write:** Insight write **or** durable `kl_post_write_no_insights` satisfies KLW-01.
6. **LPS schema artifact:** `contracts/work-spec.schema.json` is a Row-1 reviewed source; explicit `VAL/TST-RFL-612`–`618` obligation paragraphs required.

7. **Work-spec immutability:** work-spec hash immutable per `launch_id`; scope change requires Authorizer re-launch (fresh launch_id + P-loop), never in-place mutation.
8. **Control-plane quality-loop exemption:** deny-all leaf roles exempt from P-loop **and** recursive I/A/V/Val; role receipt then terminate.
9. **LPS host delimitation:** Cursor single-string `Task.prompt` uses `<<<SB_LAUNCH_PROMPT>>>` / `<<<SB_WORK_SPEC_JSON>>>` / `<<<SB_END>>>` envelope.
10. **Leaf Step handoff:** leaf Step terminates quality loops at `a_two_clean`; parent AF owns V → Val → K/L post-write.

11. **Discriminated callbacks (Sol High):** ordinary producers bind `launch_id + scope_execution_id + execution_attempt_id` (`producer_kind=ordinary_delivery`); only `producer_kind=iterate_attempt` binds Iterate contract-binding/rung/`attempt_id`. **Callback fence is generic** for both kinds. Early-callback dedupe CAS key is immutable `(project_id, source_operation_id)` only — token/generation/epoch/channel/seq are validated values/indexes, not key components (Sol XHigh c1).
12. **Process-synthesis executor:** Authorizer-launched Process-scope synthesis/executor owns Process P→I→A→V→Val after top Workflow returns; parent orchestrator never implements.
13. **Step→Advisor request edges:** implementation Step/executor (or AF on behalf of Step) may request P-loop Advisor and in-I consult; Authorizer-only spawn; §6 deny-generation must allow these edges.
14. **Active ordinary RFL migration:** non-Iterate re-admit path with `blocked_legacy_rfl_readmit`; never uses Iterate baseline states; Iterate authority only via fresh post-migration activation.
15. **Injective Authorizer trust identity:** canonical remote bytes + **full** `remote_id_sha256` path suffix (no truncated prefix); trust lookup verifies stored canonical identity before key use (Sol XHigh c1).
16. **Discriminated Levels 0–3 repair (Sol High c3):** ordinary repair re-enters ordinary SM (never `awaiting_baseline_revalidation`); Iterate repair uses baseline-revalidation path.
17. **Active RFL → live pre-read/P-loop:** post-migration prospective ordinary I edits require fresh `pre_read_pending → poa_*`; historical mapped evidence never satisfies live gates.
18. **Iterate P-loop exemption:** rung planning gate is charter + baseline admission/revalidation — not ordinary `poa_*`.
19. **P-loop plan freshness (Sol XHigh c1):** material plan-of-action change under same work-spec requires `i_running → poa_*` re-P (new satisfaction receipt) before re-entering `i_running`; work-spec scope change still requires re-launch.
20. **Process-repair delegation (Sol XHigh c2):** Process V/Val findings against child deliverables use Authorizer-owned `process_repair_pending` → `process_repair_delegated` → Workflow/AF relaunch + join; Process-synthesis never mutates AF/Work-Skill artifacts directly; re-entry through Process A→V→Val.
21. **Blocker precedence table (Sol XHigh c2):** mutually exclusive ordered classification — corrupt_state > callback_gap > callback_unresolved > verification_unavailable > validation_state > advisor_state > escalation_unavailable > child_unavailable (role-specific wins over generic); one canonical blocker + resume target per failure.








