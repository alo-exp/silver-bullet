---
decision_class: locked-defaults
status: captured
created: 2026-08-29
topic: rfl-plan-review-prompt
clarify-path-rule: scripts/lib/planning-clarify-path.sh
---

# Clarify Brief — Standardized RFL plan-review prompt

## Problem statement

Review-fix-ladder (RFL) rungs that review **plan documents** receive inconsistent, ad-hoc briefs. The skill’s generic Template A (`rung_N_review`) does not encode plan-review criteria. Live freeze ladders (example: [`.planning/rfl-router-subagent-surfaces-85bf9f09-final-review-2/`](.planning/rfl-router-subagent-surfaces-85bf9f09-final-review-2/)) show 3–14 KB one-off `brief-review.md` files that mix freeze-hash ritual, KEEP REJECT catalogs, GFM locks, and product-specific charters. Rungs therefore review plans inconsistently: some miss contract-vs-implementation drift, GFM/slug defects, missing test citations, contradictions, or missing owners.

This is a **product** problem (operators and future RFL launchers need comparable plan reviews) and a **process** problem (the prompt is not a single owned artifact).

## Current context

- Canonical RFL skill: [`skills/silver-review-fix-ladder/SKILL.md`](skills/silver-review-fix-ladder/SKILL.md) — Template A is generic “audit scoped work”; Template B is verify (out of scope).
- Standalone plan reviewer: [`skills/review-plan/SKILL.md`](skills/review-plan/SKILL.md) — structured `PLAN-F` findings; **not** wired into RFL briefs today (graphify: no path from `review_fix_ladder_rung_prompt` to `review-plan`).
- Brief writers: no `scripts/` generator currently emits `brief-review.md` (inventory: only the RFL skill contains “Template A”). Live briefs are launcher-authored markdown in `.planning/rfl-*/rung-*/`.
- Root [`.planning/SPEC.md`](.planning/SPEC.md) is the v0.35.0 SB/GSD alignment spec — **must not be overwritten**.
- This pass authors planning docs only. **Do not** rewrite the live RFL prompt. **Do not** execute freeze YAML.

## PM framing

| | |
|---|---|
| **Who** | RFL launchers (parent orchestrators), plan-review rungs, operators reading `review.md` |
| **Job** | When the artifact under review is a plan, every rung should run the same checklist and return comparable findings |
| **Value** | Fewer missed contradictions, fewer KEEP REJECT reopenings, fewer GFM/slug false-fixes, cited tests, named owners |
| **Success** | One named prompt (`Template A-PLAN`) plus generators that emit it; `review-plan` QCs aligned; verify/code-review untouched |

## Options considered

1. **Simpler — extend `review-plan` only.** Teach humans to invoke `/review-plan` before RFL. Rejected: RFL rungs never load it; freeze evidence shows the gap is the **rung brief**, not the standalone skill.
2. **Ambitious — full RFL prompt rewrite for every artifact class** (plan, spec, code, freeze). Deferred: user asked to **standardize the plan-review prompt first**.
3. **Remove/simplify — stop ad-hoc freeze briefs; always paste Template A.** Rejected: freeze ladders need identity/hash/KEEP REJECT context; Template A alone is too thin.
4. **Recommended — Template A specialization (`A-PLAN`) that wraps review-plan QCs + plan-document checklist, emitted by skill + any brief generator; freeze-specific locks stay as a thin appendix.**

## Recommendation

Lock option 4. Own the prompt in `skills/silver-review-fix-ladder` as **Template A-PLAN**. Align `skills/review-plan` quality criteria so standalone and RFL reviews do not contradict. Any future script that writes `brief-review.md` must emit A-PLAN when the scoped artifact is a plan document. Freeze-specific identity (SHA copies, named KEEP REJECT list) is an **appendix**, not a fork of the prompt.

`decision_class: blocking` items below are locked with autonomous defaults so SPEC/PLAN can proceed without a user round-trip.

## Locked decisions (autonomous defaults)

| ID | Decision | Default (locked) | `decision_class` |
|----|----------|------------------|------------------|
| D1 | What counts as a **plan document** | See list in next section | locked |
| D2 | `review-plan` only vs RFL wrapper | **Both:** A-PLAN is the RFL review prompt; `review-plan` stays the standalone reviewer and is the QC source of truth for plan structure | locked |
| D3 | Policy C / D | **Unchanged.** Rungs remain review-only. Prompt must forbid triage, Policy C writes, APPLY. KEEP REJECT is a finding surface, not a Policy C mutation | locked |
| D4 | Verify rungs | **Out of scope.** Template B + Grok 4.5 High native Cursor Task unchanged | locked |
| D5 | Mixed plan+code ladders | If the charter is **plan review**, use A-PLAN. If the charter is execute/code review, this feature does not apply | locked |
| D6 | Implementation this pass | **Docs only.** No live prompt rewrite unless a later implementation phase | locked |
| D7 | Planning artifact location | Scoped dir [`.planning/rfl-plan-review-prompt/`](.planning/rfl-plan-review-prompt/) so root SPEC/REQUIREMENTS/CONTEXT are not clobbered | locked |
| D8 | Model policy (inherited) | Verify = Grok 4.5 High native Cursor; unspecified Grok default = 4.6 High not Extra High; Fast forbidden; Cursor-via-Pi forbidden until Omni tool-call translation is fixed | locked |

## Plan document definition (D1)

**In:**

- Cursor plans: `.cursor/plans/*.plan.md`
- Repo plans: `.planning/**/*.plan.md`, `.planning/phases/**/PLAN.md`, `.planning/**/PLAN.md`
- The RFL **scope target** when the ladder charter is “review this plan” (including freeze copies of a `.plan.md`)

**Out:**

- `SPEC.md`, `REQUIREMENTS.md`, `CONTEXT.md`, `DESIGN.md`, `UI-SPEC`
- `review.md`, `POLICY-C.*`, `APPLY.md`, `SKIPPED.md`, `BLOCKED.md`
- Code, tests, hooks, YAML freeze **execution**
- Verify-phase briefs (`brief-verify-*.md`)

## Assumptions

- [ASSUMPTION: Live freeze `brief-review.md` files are representative of current prompt quality problems and will not be executed in this work | Status: Accepted | Owner: planning]
- [ASSUMPTION: No `scripts/` writer currently generates `brief-review.md`; implementation may add one or teach the skill as the sole generator | Status: Accepted | Owner: implementation]
- [ASSUMPTION: Untrusted plan body must be delimited from system instructions (AI/LLM safety) | Status: Accepted | Owner: implementation]

## Unresolved questions (non-blocking)

- Whether a later phase adds a `scripts/review-fix-ladder.py` (or sibling) brief emitter vs skill-only paste. Default: skill is canonical; a script is optional if tests need a stable fixture. Owner: implementation. Status: Follow-up-required, not blocking SPEC.

## Next-step notes

1. `/silver:spec` → scoped SPEC + REQUIREMENTS (this session).
2. Skip ingest / DESIGN.md / UI-SPEC (no external design input; not UI).
3. `/silver:context` → scoped CONTEXT.md.
4. `/silver:quality-gates` design-time, then `/silver:plan`.
5. Implementation of A-PLAN is a **later** phase after these docs exist and (optionally) after user/plan review.

## Visual companion

Not offered. Topic is prompt/docs, not UI. `--text`.
