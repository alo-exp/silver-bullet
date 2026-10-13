---
name: silver-clarify
mode: non-autonomous
target: .planning/router_subagent_surfaces_85bf9f09.plan.md
date: 2026-08-25
---

# Clarify brief — Router Subagent Surfaces freeze plan

Non-autonomous `/silver:clarify` (`--all`). No defaults applied. KEEP REJECT not reopened. YAML todos not marked completed. The user has **not** answered.

## Problem statement

The freeze plan is headed PRD / Analysis / Architecture / Design. Independent review repaired KR heading/body misalignment, public-surface leaks (`sb:agent-wrap`, `/sb:multi-ai-task` as if shipping), docs-layer confusion (WS0b vs post-Val K/L vs docs-release), and duplicate coverage maps. Three **true** product/policy forks remain. Ship cannot start WS1 until the user picks.

## Current context

- Plan copies: `.planning/router_subagent_surfaces_85bf9f09.plan.md` and `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`.
- Phase 1 SHA: `31406f106e131c39cb86fa788819353671a31b5b69966d08cae87038c3d995e1` (580674 bytes). Phase 2 expands §6 only.
- KEEP REJECT catalog: [§3.3](router_subagent_surfaces_85bf9f09.plan.md). Closed.
- Evidence: [`.planning/handoffs/2026-08-25-plan-independent-review-delta.md`](handoffs/2026-08-25-plan-independent-review-delta.md).

## PM framing

- **Who:** Silver Bullet operators and every SB instance on a repo.
- **Problem:** Three implementer forks would produce different catalogs, tests, and GST behavior.
- **Why now:** Freeze is otherwise closed; WS0→WS0b→WS1 cannot encode both sides.
- **Success:** One letter per question, recorded in the plan, KEEP REJECT still closed.

Visual companion was not offered: this is a process/architecture freeze, not a UI/mockup topic (`--text`).

## Options considered

See numbered questions below (A/B/C). Internally diverged: simpler (always-Job / split WS owners / retarget WF), more ambitious (keep a private AF), remove/simplify (empty-tag no-op).

## Clarify questions (ask the user)

KEEP REJECT already forbids: dual `/silver`; FAST as a Job; `sb:agent-wrap`; per-user custom evolution; auto-PR; JSON-edit generated catalog; exclusive-projector reopen; row 40 ≠ 37; remint without new `launch_id`.

### Q1. `/sb:improve` vs classified-trivial

**Why it matters:** Live-spec says Job / not FAST **and** “quality order applies unless classified-trivial.”

- **A.** Always a Job (never classified-trivial; GST + quality order).
- **B.** May be classified-trivial (skip six-role quality order and GST) but still not `sb:fast`.
- **C.** Always a Job except empty-tag no-op (user-visible fail-closed; not FAST).

**Recommendation (not a decision):** A.

### Q2. Improve/contribute workstream owner

**Why it matters:** YAML map says WS4 / WS7; WS1 already emits the public routes.

- **A.** WS1 emit only; WS4 Job runtime; WS7 docs/Doctor/site.
- **B.** WS4 owns emit + Job; WS1 does not touch these routes; WS7 docs only.
- **C.** WS7 owns contribute Job + docs; WS4 owns improve Job; WS1 emits both.

**Recommendation (not a decision):** A.

### Q3. `WF-SILVER-DEEP-RESEARCH-MULTI-AI` after retiring `AF-MULTI-AI-TASK`

**Why it matters:** Generator `usage_review` ties that WF to `AF-MULTI-AI-TASK`. LS-retire leaves deep-research unless it is the same **public route**.

- **A.** Keep the WF; retarget to `/sb:ladder` / `/sb:parallel` primitives; delete public multi-ai-task route; no `MULTI-AI-TASK.md` public worker.
- **B.** Keep `AF-MULTI-AI-TASK` as a **non-public** AF used only by deep-research (no public route).
- **C.** New AFs for deep-research; retire `AF-MULTI-AI-TASK` entirely.

**Recommendation (not a decision):** A.

## Assumptions (must be validated later)

- Goose/Hermes public leaves wait until those skills exist (body already says this; not asked).
- `sb:review-fix-ladder` is absorbed into `/sb:ladder` (LS-ladder-parallel; not asked).
- Q-loop docs exemption vs WS0b analysis/design is already specified in the glossary (not asked).

## Unresolved questions

The three questions above. No other locked-decision gaps were opened. Do not wait here for answers this session does not have.

## Next SB lifecycle step

After the user answers Q1–Q3: record letters in the plan §6, then `silver:plan` is already satisfied — implementation remains **not** this session. Next product work is WS0 (hygiene) only after answers land. Do **not** chain `--chain` into context/plan in this non-autonomous run.
