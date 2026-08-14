# Clarify Brief — router_subagent_surfaces_85bf9f09

> **The architecture spec supersedes contradicting clarify Qs.** Canonical text: [`.planning/router_subagent_surfaces_85bf9f09.plan.md`](.planning/router_subagent_surfaces_85bf9f09.plan.md) (byte-identical with [`~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`](/Users/shafqat/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md)). History below is retained and marked superseded. Round-10 fix 2026-08-14.
>
> **Superseded (do not implement these answers):**
> - **Q4** dual-prefix during migrate — no public dual `/silver` window; bootstrap is `bash scripts/sb-migrate-from-silver.sh` plus plugin postinstall, not only `/sb:migrate`.
> - **Q5** day-1 Cursor+Codex+Claude hosts — MVP is Cursor host adapter; Codex/Claude/OpenCode host adapters after MVP.
> - **Q7** hard-cut delete public RFL — keep `sb:review-fix-ladder` until Iterate exists (Verifier+Process-final-Val path or thin alias).
> - **Q9c** trust path `host/org/repo` as CAS — Authorizer trust is `~/.silver-bullet/authorizer-trust/<repo-id>/`; host is metadata, not a second CAS.
> - **Q11** ship-everything / pending lock — MVP slice as named in the spec.
> - **Q12** I-loop two consecutive clean — spec-wins: I has no self-attested two-clean; two-clean applies to A (including Process-scope A), V (including Process-scope V), and Process-final Val (when Val runs).
> - **Q14** AF Val after merge — AF does V, not Val; Val is Process-final only.
> - **Q18** `val_*` on ordinary AF/Workflow SM — canonical order I→A→V at AF/Workflow; after the top Workflow join: Process-synthesis I → Process-scope A/V (mandatory) → Process-final Val.
> - **Q21** “Val always after V” at AF (answer B) — Process-final Val only; AF/Workflow run V.
> - **Q22** AF + Workflow + Process all mandatory Val — only Process runs Val.
> - **Note 15** path-as-CAS / `remote_id_sha256` suffix — trust path remains `~/.silver-bullet/authorizer-trust/<repo-id>/`.
> - Universal Advisor “Validation-loop mandatory at AF, Workflow, and Process”.
> - Toolstack “Five-tool is Cursor opt-in” / Graphify miss not blocked on other hosts — opt-in then mandatory on every selected runtime after init probe.
> - Round-5 “Orchestrator session is the only Task/Agent syscall” — nested Task is allowed; parent-proxy at remaining depth 0.
> - Round-5 “merge then AF Val” — do not un-merge; repair is Executor I+V; Val again only at Process-final; Orchestrator+Advisor map the fail receipt (Validator does not walk WBS).
> - Round-4 / note 19 `blocked_replan_budget` as job bound — replaced by the finite 4-step ladder.
> - RFL note 10 leaf Step then AF Val.
> - RFL note 12 Process-synthesis owns Process I of child work — packet-local composition/findings only.
> - Next-step “pending user lock” / plan `## Pending user lock`.

**UTC file stamp:** 2026-07-17T14:37:57Z (session local 2026-07-18)
**Clarify run:** 2026-07-17T14:37:57Z (interactive `/silver:clarify`, Grok 4.5 High)  
**Round-5 alignment:** 2026-08-14 — historical. **Round-1 fix 2026-08-14:** architecture spec supersedes the contradicting Qs listed in the banner (round-4 executor-draft P-loop remains superseded; Q4 public IDs remain `sb:<route>`). **Round-2 fix 2026-08-14:** Q18 `val_*` on ordinary AF/Workflow SM superseded; note 15 `remote_id_sha256` path suffix superseded. **Round-10 fix 2026-08-14:** Q12 I-loop two consecutive clean superseded — I has no self-attested two-clean. **Composer-Medium RFL fix 2026-08-14:** Process-scope A/V and Process-synthesis I are mandatory after the top Workflow join before Process-final Val (ordinary-delivery steps 9a–9c); VLP-01/ILP-01/ESC-02/`step_yield`/overlap live E2E aligned. **Kimi-K3-High parent-side fix 2026-08-14:** live canonical-order chains (this banner, Universal Advisor L64, Validation-loop Order) include Process-synthesis I and Process-scope A/V after the **top** Workflow join only.  
**Source plan:** `.planning/router_subagent_surfaces_85bf9f09.plan.md`  
**Cursor mirror:** `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` (byte-identical after incorporation)  
**Do not overwrite:** `.planning/CLARIFY.md` (multi-AI deep-research brief — unrelated)

---

## Problem Statement

Silver Bullet needs a Process-first `/sb` router architecture with Authorizer-admitted / Orchestrator-spawned hierarchical execution, nested quality loops (**I → A → V** at AF and Workflow; after the **top** Workflow join: Process-synthesis I → Process-scope A/V → **Process-final Val**), Levels 0–3 defect recovery (post-MVP with Iterate), optional Iterate Ladder (post-MVP), and universal migration — clarified interactively before implementation. Public routes are `sb:<route>`. Product name `silver-bullet.md` / `~/.silver-bullet/` may remain.

---

## Recorded Q&A

| Q | Decision |
|---|----------|
| Q1 | Plan-scoped clarify brief + Decision Addendum in plan; do **not** overwrite multi-AI `.planning/CLARIFY.md` |
| Q2 | Diff-merge repo vs Cursor first (richer Cursor base + clarify wins); then keep both byte-identical |
| Q3 | GLM 5.2 is **not** barred; allow in Planning/Validation defaults; remove blanket bar |
| Q4 | **All AFs and all Workflows** are `sb:<route>` (amend “exactly 18”); ordered membership from full APO catalog. Public cutover is `/sb` only. **SUPERSEDED (dual-prefix):** no public dual `/silver` window; bootstrap is `bash scripts/sb-migrate-from-silver.sh` plus plugin postinstall, not only `/sb:migrate`. |
| Q5 | **SUPERSEDED (day-1 Codex+Claude).** Architecture: MVP = Cursor host adapter; Codex/Claude/OpenCode host adapters after MVP; `sb:agent-*` rename in the MVP ship. Historical: Day-1 hosts intent Cursor + Codex + Claude Code; OpenCode deferred. |
| Q6 | `critical_policy` only from in-repo reviewed hash-bound SB policies |
| Q7 | **SUPERSEDED (hard-cut delete public RFL).** Architecture: keep public `sb:review-fix-ladder` until Iterate exists (Verifier+Process-final-Val path or thin alias). Historical: hard cut RFL retirement. |
| Q8 | **Unlimited** Process-authorized Workflow nesting |
| Q9a | Rename **Broker → Authorizer** |
| Q9b | Runtime-home key storage |
| Q9c | **SUPERSEDED (path-as-CAS).** Architecture: Authorizer trust is `~/.silver-bullet/authorizer-trust/<repo-id>/`; host is metadata, not a second CAS. Historical: filesystem-safe `host/org/repo` from git remote. |
| Q10 | **Superseded** by universal Advisor A-loop |
| Q10′ | A-loop **two consecutive clean**; findings → I → re-A before V; V never starts with open Advisor findings |
| Q11 | **SUPERSEDED (ship-everything / pending lock).** Architecture MVP = Cursor host + six-role control plane + `/sb` + Task/work-spec + WBS projector + overlap worktrees + Advisor-first + process-final Val + existing `sb:agent-*` rename + bootstrap migrate (ILM-01) + live E2E. |

---

## Universal Advisor / A-loop

Canonical order: `pre-read Knowledge/Learnings → Advisor planning (Advisor produces plan of action) → one-way plan handoff to Executor → I-loop(s) → A-loop → (return to I if needed) → V-loop → (merge code if extra host_native worktree) → top Workflow join → Process-synthesis I → Process-scope A two-clean → Process-scope V two-clean → Process-final Validation-loop → post-verify Knowledge/Learnings write → return to parent`. AF and Workflow stop at V. Inner nested Workflow joins are not Process-scope. Ordinary AF/Workflow SM has no `val_*` states.

Round-4 executor-draft **P-loop** (`poa_draft` / executor drafts then Advisor reviews) is **superseded**. Executor never plans.

- Advisor is fundamental and universal (not Marketing-only).
- Enables lower-cost executors + higher-cost Advisors.
- Verifier = strict spec check (never fixes). Advisor = review **and Mentor**. Authorizer = hook/admission TCB (not bound to Verifier LLM; not a preference key).
- **Validation-loop** = Validator-role fit-for-purpose judgment (≠ Verification, ≠ Advisor). **SUPERSEDED:** not mandatory at AF/Workflow; Process-final Val only; AF/Workflow run V; Validator returns a fail receipt and does not walk WBS; Orchestrator+Advisor map the receipt. Historical: always after V including after empty V-attest; mandatory at AF, Workflow, and Process; two-clean.
- Mentorship: project → `docs/knowledge/`; portable → `docs/learnings/`.
- **Sidekick:** absorb host-as-advisor/mentor + AGENTS mentoring semantics; ignore / out of MVP: external-agent harness / DLGT / L3 take-over.
- Marketing specialty folded into universal A-loop for v1.

### Toolstack (five-tool routed)

| Step | Graphify | agentmemory | Context Mode | LeanCTX | RTK |
|------|----------|-------------|--------------|--------|-----|
| Pre-read | query (primary retrieve) | optional session recall | filter INDEX/month files | large-file read if needed | n/a |
| I / A / V / Val | query before edits; update after code | save decisions/defects/receipts | analysis of diffs/tests | large-file read | shell compression when opted in |
| Post-verify K/L write | update after doc edits | save write refs | draft assist | not for durable write | n/a |

Synergy: save via agentmemory, retrieve via Graphify. Do not use `lctx_remember` or `lctx_graph` for code.
Alumnium is out of scope for this architecture ship (UI/browser evidence remains a separate opted-in surface).
**SUPERSEDED (Cursor-only five-tool).** Architecture: five-tool is opt-in, then mandatory on every **selected** runtime after an init probe passes (do not record a runtime if Graphify/etc. cannot run there yet; porting is in-scope for that selection). Historical: Cursor opt-in only; Codex/Claude INDEX/fallback; Graphify failure on those hosts not `blocked_knowledge_preread`.

---

## Recommended defaults (logged, not re-litigated)

- A-loop orthogonal to Levels 0–3.
- Advisor strictly stronger than that scope’s executor.
- Sidekick L3 host take-over out of scope.

---

## Next step

Round-2 Q12–Q22 remain historical except where the architecture banner supersedes them (Q12 I-loop two-clean; Q14/Q18/Q21/Q22 Val scope; Q11 packaging; note 15 trust path). Plan + Cursor mirror must stay byte-identical. **Do not implement product code from superseded Qs.** Skip `/sb:context` unless brownfield framing is needed.

---

## Artifacts

| Artifact | Path |
|----------|------|
| This brief | `.planning/router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md` |
| Repo plan | `.planning/router_subagent_surfaces_85bf9f09.plan.md` |
| Cursor mirror | `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` |

---

## Plan appendix (Q12–Q22)

These deepen the plan. Q1–Q3 and Q6 / Q8–Q10′ / Q13 / Q15–Q17 / Q19–Q20 remain as noted; **Q4 dual-prefix, Q5 hosts, Q7 RFL delete, Q9c trust path, Q11 packaging, Q12 I-loop two-clean, Q14/Q18/Q21/Q22 Val scope, note 15 path suffix** are **SUPERSEDED** by the architecture spec (banner). Authoritative detail remains in `.planning/router_subagent_surfaces_85bf9f09.plan.md` (byte-identical with `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`).

| Q | Decision | Status |
|---|----------|--------|
| Q12 | I-loop requires two consecutive clean outcomes (same two-clean family as A-loop) | **SUPERSEDED** — spec-wins: I has no self-attested two-clean; two-clean applies to A, V, and Process-final Val (when Val runs). Historical: I-loop two consecutive clean. |
| Q13 | V-loop requires two consecutive clean; ordinary SM uses `v_running`/`v_two_clean`/`v_verified` (`v_verified` = two-clean terminal) | **Ratified** (round-2) |
| Q14 | AF leaf Step runs A-loop two-clean once before AF V; that receipt satisfies the AF A-gate (no duplicate AF A); **no Step-level V**; work stays in worktree until AF V; then merge if overlap. **SUPERSEDED (AF Val mandatory):** AF does V not Val; Val is Process-final only. | **SUPERSEDED in part** (AF Val) |
| Q15 | Nine `fitness_charter` fields + four canonical Iterate rung IDs as in plan Locked decisions | **Ratified** (round-2) |
| Q16 | `contracts/iterate-ladder-contract.lock.json` is binding/fence authority for Iterate | **Ratified** (round-2) |
| Q17 | Exact six migration ingress states: `freeze_new_source` → `project_pre_freeze_events` → `seal_drain_watermark` → `drain_old_epoch` → `producer_stopped` → `cutover` | **Ratified** (round-2, answer **A**) |
| Q18 | **SUPERSEDED (`val_*` on ordinary AF/Workflow SM).** Canonical order is I → A → V at AF and Workflow; Val is Process-final only (separate last step after Workflow join). Ordinary AF/Workflow SM: `pre_read_pending` → `advisor_planning`/`plan_handed_off` → `i_*` → `a_*` → `v_*` → (merge if extra host_native worktree) → join. Process-final: `val_*` → `kl_post_write_pending` → `scope_complete`. Historical: `val_*` on the ordinary AF/Workflow machine. Historical `p_*`/`poa_*` names retired with executor-draft P-loop. | **SUPERSEDED in part** (`val_*` on AF/Workflow) |
| Q19 | Iterate work states are orthogonal to `authority_status` | **Ratified** (round-2) |
| Q20 | `awaiting_revalidation` (in-rung) ≠ `awaiting_baseline_revalidation` (baseline-stale) | **Ratified** (round-2) |
| Q21 | AF Validation-loop (≠ V, ≠ A); **"Val always after V"** → **B**: `I → A → V → (merge if overlap) → Val`; Validator-role owner; two-clean; Val still required after empty V-attest | **SUPERSEDED** — Process-final Val only; AF/Workflow run V |
| Q22 | AF **and** Workflow **and** Process all **must** run Validation-loop, always after V | **SUPERSEDED** — only Process runs Val |

---

## Clarify Decision Addendum (round-2 — 2026-07-20) — COMPLETE

Interactive `/silver:clarify` round-2 (Grok 4.5 High). All blockers answered; incorporated into plan + mirror.

### Ratified

- **Q12** — **SUPERSEDED (I-loop two consecutive clean).** Spec-wins: I has no self-attested two-clean. Historical: I-loop two consecutive clean (same two-clean family as A-loop)
- **Q13** — V-loop two consecutive clean; SM `v_running` / `v_two_clean` / `v_verified`
- **Q14** — AF leaf Step A-loop two-clean once before AF V; receipt satisfies AF A-gate (no duplicate AF A); then AF V. **SUPERSEDED:** then AF Val mandatory
- **Q15** — Nine `fitness_charter` fields + four canonical Iterate rung IDs
- **Q16** — `contracts/iterate-ladder-contract.lock.json` is Iterate binding/fence authority
- **Q17** — Answer **A**: exact six ordered migration ingress states
- **Q18** — **SUPERSEDED (`val_*` on ordinary AF/Workflow SM).** Canonical I → A → V at AF/Workflow; Process-final Val after Workflow join. Historical round-2 text put `val_*` on the ordinary machine; P-loop `p_*`/`poa_*` inserted by round-4 then superseded by Advisor-first `advisor_planning`/`plan_handed_off`
- **Q19** — Iterate work states orthogonal to `authority_status`
- **Q20** — `awaiting_revalidation` (in-rung) ≠ `awaiting_baseline_revalidation` (baseline-stale)
- **Q21** — Answer **B** / **"Val always after V"**: **SUPERSEDED** by Process-final Val only (historical: order `I → A → V → Val` at AF; Validator-role owner; two-clean; Val still required after empty V-attest)
- **Q22** — Answer **B**: **SUPERSEDED** (historical: AF + Workflow + Process all mandatory Validation-loop)

### Validation-loop

| Axis | Spec |
|------|------|
| Distinction | Validation ≠ Verification (V-loop) ≠ Advisor (A-loop) |
| Meaning | Fit-for-purpose / right-thing judgment (Planning/Validation tier) |
| Order | **I → A → V** at AF and Workflow. After the **top** Workflow join: Process-synthesis I → Process-scope A/V (mandatory) → **Process-final Val**. Chain: `I → A → V → (merge code if extra host_native worktree) → top Workflow join → Process-synthesis I → Process-scope A two-clean → Process-scope V two-clean → Process-final Val`. Inner nested Workflow joins stop at V. **SUPERSEDED:** always after V at every scope; `val_*` on ordinary AF/Workflow SM |
| Scopes | **SUPERSEDED:** Process only. Historical: AF, Workflow, and Process — all mandatory |
| Owner | Validator role (not Verifier; not Advisor) |
| Two-clean | Yes for A, V, and Process-final Val (when Val runs). I has no self-attested two-clean |
| Dirty | Return to I; re-satisfy A if needed; re-V if contract affected; Val again only at Process-final; KL post-write only after Process-final Val two-clean |

### Still open

None for round-2.

**Do not** overwrite multi-AI `.planning/CLARIFY.md`. Repo plan and Cursor mirror must remain **byte-identical**.

---

## Clarify Decision Addendum (round-3 — 2026-07-20) — COMPLETE

Interactive requirements lock (Grok 4.5 High). Incorporated into plan + mirror.

### Ratified

- **Launch prompt + work spec (mandatory admission gate)** — Every host subagent launch must include a prompt-engineered launch prompt **and** a well-specified work spec with clear **output** and **outcome** requirements. Fail-closed without them: blocker `blocked_launch_prompt_spec` (no spawn / no lease/capability/channel).
- **Work-spec exactly these fields** — `goal_outcome`, `required_outputs`, `acceptance_criteria`, `scope_bounds`, `context_refs` (Knowledge/Learnings/pre-read + packet/ancestry refs). Unknown properties fail closed (`additionalProperties: false`). Prompt binds work-spec hash, WBS path, role, denies, callback/return contract.
- **ASCII WBS progress visualization (mandatory UX)** — On every governing-scope step transition and every user-facing status: path `Process > Workflow > AF > Step` (optional ` > Skill`), markers `[x]` complete / `[>]` current / `[ ]` pending / `[!]` blocked. Missing viz → `blocked_progress_viz`.
- Traceability: **LPS-01** (`VAL/TST-RFL-616`), **WBS-01** (`VAL/TST-RFL-617`).

### Still open

None for round-3.

**Do not** overwrite multi-AI `.planning/CLARIFY.md`. Repo plan and Cursor mirror must remain **byte-identical**.

---

## Clarify Decision Addendum (round-4 — 2026-08-12) — SUPERSEDED

**Naming:** the pre-implementation plan-of-action Advisor gate is **Advisor-first one-way planning** (not an executor-draft P-loop). Round-4 text below is historical and **must not** be treated as current spec.

Interactive requirements lock. Incorporated into plan + Cursor mirror, then **superseded 2026-08-14**.

### Historical (do not implement)

1. ~~P-loop / Planning Loop: every worker/executor drafts a durable plan of action, submits it to a stronger-tier Advisor~~ → **replaced:** Advisor owns planning; Executor never drafts; one-way handoff; `advisor_planning` / `plan_handed_off`.
2. On-demand Advisor consult during `i_running` remains (advice only). Material plan change = **Advisor receipt**, not Executor self-assessment; **SUPERSEDED:** `blocked_replan_budget` as job bound — replaced by the finite 4-step ladder.
3. ~~Ordinary SM: `poa_draft`/`poa_advisor_review`/`poa_satisfied`~~ → **replaced:** `advisor_planning`/`plan_handed_off`.
4. Traceability **POA-01** / `VAL/TST-RFL-618` **retained** with renamed semantics.

**Do not** overwrite multi-AI `.planning/CLARIFY.md`. Repo plan and Cursor mirror must remain **byte-identical**.

## Clarify Decision Addendum (round-5 — 2026-08-14) — SUPERSEDED IN PART (architecture spec wins)

Aligns this brief with an earlier plan draft. **SUPERSEDED** where it contradicts the architecture spec banner (including Q18 `val_*` on ordinary AF/Workflow SM).

- Spawn: **SUPERSEDED** “Orchestrator session is the only Task/Agent syscall”. Architecture: hooks never invoke Task; nested Task is allowed; root Orchestrator is always Task-capable; parent-proxy at remaining depth 0.
- Effort: `low|medium|high|xhigh`; Executor = highest available on host; do not collapse xhigh; Max is not a Cursor Task effort.
- Merge: after AF V two-clean, before **Process-final** Val (code-only). **SUPERSEDED:** AF Val. Val-fail: do not un-merge; Validator fail receipt; Orchestrator+Advisor map to WBS; Executor I+V; Val again only at Process-final.
- MVP slice supersedes Q11 “ship everything together”.
- `{ runtime, model, effort }`; Authorizer not a preference key; in-repo slug catalog; **SUPERSEDED:** five-tool Cursor-opt-in — opt-in then mandatory on every selected runtime after init probe.
- `silver`→`sb` is in the architecture ship; Q4 = `sb:<route>`; **SUPERSEDED:** dual-prefix migrate window; bootstrap is `scripts/sb-migrate-from-silver.sh`.
- Full one-line checklist: architecture spec Document control (no `## Pending user lock`).

## RFL incorporate notes (2026-08-12)

Clarifying elaborations recorded into the plan during adversarial RFL (do not reopen these Qs), **as amended by the 2026-08-14 draft** (Advisor-first; no executor-draft P-loop):

1. **Advisor-plan scope:** Applies to **ordinary-delivery** implementation workers/executors only (Workflow/AF/Step/Process-synthesis). Deny-all leaf control-plane roles (`advisor`, `verifier`, `validator`, `defect_escalation`) are exempt from plan-of-action handoff. **Iterate rung implementers** use charter + baseline admission (not ordinary `advisor_planning`). Historical “P-loop” language is retired.
2. **Migration Val receipts:** Legacy RFL maps into I/A/V/**Validation-loop** records; missing Val history uses migration-only `val_loop_not_applicable` (never satisfies live Val gates).
3. **Levels 0–3 repair return:** Successful repair → original owner **I → A → V** (re-A before V), not V-only. Ordinary repair never enters Iterate `awaiting_baseline_revalidation`; Iterate repair does.
4. **Authorizer path fallback:** **SUPERSEDED (path-as-CAS).** Architecture: `~/.silver-bullet/authorizer-trust/<repo-id>/` with host as metadata. Historical injective `host/org/repo/<remote_id_sha256>` (full 64-hex digest; no truncated prefix) from canonical remote bytes; `local/default/<repo_dir_sha256>` when git remote absent/unparseable; trust lookup verifies stored canonical identity.
5. **KLW post-write:** Insight write **or** durable `kl_post_write_no_insights` satisfies KLW-01.
6. **LPS schema artifact:** `contracts/work-spec.schema.json` is a Row-1 reviewed source; explicit `VAL/TST-RFL-612`–`618` obligation paragraphs required.

7. **Work-spec immutability:** Task five-field hash immutable per `launch_id`; Advisor plan artifact may be replaced under the same `launch_id` with an Advisor receipt. New `launch_id` only if the Task itself (goal/scope/acceptance) changes.
8. **Control-plane quality-loop exemption:** deny-all leaf roles exempt from Advisor-plan **and** recursive I/A/V/Val; role receipt then terminate.
9. **LPS host delimitation:** Cursor single-string `Task.prompt` uses `<<<SB_LAUNCH_PROMPT>>>` / `<<<SB_WORK_SPEC_JSON>>>` / `<<<SB_END>>>` envelope.
10. **Leaf Step handoff:** leaf Step terminates quality loops at `a_two_clean`; parent AF owns V → (merge if overlap). **SUPERSEDED:** AF Val → K/L post-write. No Step-level V. Val is Process-final only.

11. **Discriminated callbacks (Sol High):** ordinary producers bind `launch_id + scope_execution_id + execution_attempt_id` (`producer_kind=ordinary_delivery`); only `producer_kind=iterate_attempt` binds Iterate contract-binding/rung/`attempt_id`. **Callback fence is generic** for both kinds. Early-callback dedupe CAS key is immutable `(project_id, source_operation_id)` only — token/generation/epoch/channel/seq are validated values/indexes, not key components (Sol XHigh c1).
12. **Process-synthesis executor:** **SUPERSEDED (owns I of child work).** Architecture: Process-synthesis I is packet-local composition/findings only; product implementation is Workflow/AF Executors. Historical: Authorizer-admitted Process-scope synthesis/executor owns Process Advisor-plan→I→A→V→Val after top Workflow returns; parent orchestrator never implements (Orchestrator session does spawn).
13. **Step→Advisor request edges:** implementation Step/executor (or AF on behalf of Step) may request Advisor planning and in-I consult; Authorizer-only admission; Orchestrator session spawns; §6 deny-generation must allow these edges.
14. **Active ordinary RFL migration:** non-Iterate re-admit path with `blocked_legacy_rfl_readmit`; never uses Iterate baseline states; Iterate authority only via fresh post-migration activation.
15. **Injective Authorizer trust identity:** **SUPERSEDED (path-as-CAS / `remote_id_sha256` suffix).** Trust path remains `~/.silver-bullet/authorizer-trust/<repo-id>/`. Historical: canonical remote bytes + **full** `remote_id_sha256` path suffix (no truncated prefix); trust lookup verifies stored canonical identity before key use (Sol XHigh c1).
16. **Discriminated Levels 0–3 repair (Sol High c3):** ordinary repair re-enters ordinary SM (never `awaiting_baseline_revalidation`); Iterate repair uses baseline-revalidation path. Level-1 is a separate repair leaf, not the V-loop Verifier.
17. **Active RFL → live pre-read/Advisor-plan:** post-migration prospective ordinary I edits require fresh `pre_read_pending → advisor_planning`; historical mapped evidence never satisfies live gates.
18. **Iterate Advisor-plan exemption:** rung planning gate is charter + baseline admission/revalidation — not ordinary `advisor_planning`.
19. **Plan freshness:** material plan-of-action change = Advisor receipt that ordered steps changed; plan artifact may be replaced under the same `launch_id`. **SUPERSEDED:** `blocked_replan_budget` as job-stop — finite 4-step ladder. New `launch_id` only if the Task five-field hash changes.
20. **Process-repair delegation (Sol XHigh c2/c3):** ancestry-preserving Authorizer-admitted path `process_repair_pending` → `process_repair_delegated` → reopen deepest leaf through declared owner chain only; invalidate ancestor A/V/KL evidence; keep already-merged sibling AFs; bottom-up joins + I+V (A judges I-clean) before Process-final Val; forbid direct nested-AF/Workflow→Process callback; Process-synthesis never mutates AF/Work-Skill artifacts. **SUPERSEDED:** re-run Val at every repair hop.
21. **Blocker total precedence:** complete ordered mutually exclusive table over canonical `blocked_*` IDs (now including `blocked_replan_budget` and `blocked_executor_unavailable`; `blocked_triage_unresolved` retired as Val-triage) with disjoint predicates and explicit resume targets.

22. **Non-material RFL polish (Opus High/XHigh + earlier-rung nits, 2026-08-12):** occurrence-ordinal cross-refs use § anchors (not brittle line numbers); `drain_only` named in ingress substate whitelist; `launch_intent` enumerates Authorizer-minted `scope_execution_id`/`execution_attempt_id`; dependency-matrix rows 2–4 name WBS/LPS/POA acceptance; ESC-01 repair-rejoin ordinal fixture; uniform `revalidation_cycle_id` `trigger_kind` 3-tuple; TRUST-01 local-fallback realpath/symlink fixture + migrate re-bind; LPS envelope escaping + RFC 8785 JCS hash equality; labelled leaf-Step `a_two_clean → step_yield` terminal; ordinary budget/oscillation note (no Iterate-style ladder-conflict counterpart); Process-synthesis Workhorse tier; A-loop Mentor continuity + knowledge-candidate buffering; rows 6↔12 phase labels + overlap fixture; callback gap-vs-unresolved tiebreaker; I-loop dirty-round disposition mapping; `final-validation` = `val_validated` synonym; mandatory A/Val "floor" wording.










