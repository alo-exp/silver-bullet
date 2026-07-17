# Clarify Brief — router_subagent_surfaces_85bf9f09

**UTC file stamp:** 2026-07-17T14:37:57Z (session local 2026-07-18)
**Clarify run:** 2026-07-17T14:37:57Z (interactive `/silver:clarify`, Grok 4.5 High)  
**Source plan:** `.planning/router_subagent_surfaces_85bf9f09.plan.md`  
**Cursor mirror:** `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` (byte-identical after incorporation)  
**Do not overwrite:** `.planning/CLARIFY.md` (multi-AI deep-research brief — unrelated)

---

## Problem Statement

Silver Bullet needs a Process-first `/silver` router architecture with Authorizer-fenced hierarchical execution, nested quality loops (I → A → V), Levels 0–3 defect recovery, optional Iterate Ladder, and universal migration — clarified interactively before implementation.

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

Canonical order: `pre-read Knowledge/Learnings → I-loop(s) → A-loop → (return to I if needed) → V-loop → post-verify Knowledge/Learnings write → return to parent`.

- Advisor is fundamental and universal (not Marketing-only).
- Enables lower-cost executors + higher-cost Advisors.
- Verifier = strict spec check (never fixes). Advisor = review **and Mentor**.
- Mentorship: project → `docs/knowledge/`; portable → `docs/learnings/`.
- Sidekick absorb: host-as-advisor/mentor + AGENTS mentoring semantics; leave out external-agent harness / DLGT / L3 take-over.
- Marketing specialty folded into universal A-loop for v1.

### Toolstack (five-tool routed)

| Step | Graphify | agentmemory | Context Mode | LeanCTX | RTK |
|------|----------|-------------|--------------|--------|-----|
| Pre-read | query (primary retrieve) | optional session recall | filter INDEX/month files | large-file read if needed | n/a |
| I / A / V | query before edits; update after code | save decisions/defects/receipts | analysis of diffs/tests | large-file read | shell compression when opted in |
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

Plan Locked decisions + body amended. Proceed to implementation when parent orchestrator queues workers. Skip `/silver:context` unless brownfield framing is needed.

---

## Artifacts

| Artifact | Path |
|----------|------|
| This brief | `.planning/router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md` |
| Repo plan | `.planning/router_subagent_surfaces_85bf9f09.plan.md` |
| Cursor mirror | `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` |

---

## Plan-locked appendix (Q12–Q20)

These deepen the plan Locked decisions without reopening Q1–Q11. Authoritative detail remains in `.planning/router_subagent_surfaces_85bf9f09.plan.md` (byte-identical with `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`).

| Q | Decision |
|---|----------|
| Q12 | I-loop requires two consecutive clean outcomes (same two-clean family as A-loop) |
| Q13 | V-loop requires two consecutive clean; ordinary SM uses `v_running`/`v_two_clean`/`v_verified` (`v_verified` = two-clean terminal) |
| Q14 | AF leaf Step runs A-loop two-clean once before AF V; that receipt satisfies the AF A-gate (no duplicate AF A) |
| Q15 | Nine `fitness_charter` fields + four canonical Iterate rung IDs as in plan Locked decisions |
| Q16 | `contracts/iterate-ladder-contract.lock.json` is binding/fence authority for Iterate |
| Q17 | Exact six migration ingress states: `freeze_new_source` → `project_pre_freeze_events` → `seal_drain_watermark` → `drain_old_epoch` → `producer_stopped` → `cutover` |
| Q18 | Ordinary delivery SM: `pre_read_pending` → `i_*` → `a_*` → `v_*` → `kl_post_write_pending` → `scope_complete` |
| Q19 | Iterate work states are orthogonal to `authority_status` |
| Q20 | `awaiting_revalidation` (in-rung) ≠ `awaiting_baseline_revalidation` (baseline-stale) |

