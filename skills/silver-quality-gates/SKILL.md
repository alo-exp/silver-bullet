---
name: silver-quality-gates
description: "Dual-mode: design-time checklist (pre-plan) or adversarial audit (pre-ship). Mode auto-detected from artifact state."
version: 0.1.0
---

> **Recommended model:** Sonnet (default) — quality gates are structured checklist evaluation, not open-ended reasoning. Sonnet handles all 9 dimensions accurately.

# /silver-quality-gates — Consolidated Quality Review

Applies all 9 Silver Bullet quality dimensions in sequence. Operates in **dual-mode**: design-time checklist when run pre-plan, or adversarial audit when run pre-ship. Mode is auto-detected from artifact state — no manual configuration required.

**Plugin root**: Determine `PLUGIN_ROOT` from this file's path. This file lives at
`${PLUGIN_ROOT}/skills/silver-quality-gates/SKILL.md`, so the plugin root is two directories up.

---

## Step 0: Mode Detection

Detect operating mode from artifact state before loading dimension skills.

Run these detection commands:

```bash
PLAN_EXISTS=$(ls .planning/phases/*/**-PLAN.md 2>/dev/null | head -1)
VERIFY_PASSED=$(grep -l "status: passed" .planning/VERIFICATION.md 2>/dev/null)
```

Use the disambiguation table to determine mode:

| PLAN.md exists? | VERIFICATION.md with `status: passed`? | Mode |
|-----------------|----------------------------------------|------|
| No | No | **design-time** (pre-plan quality gate) |
| No | Yes | **Invalid state** — STOP with error: "VERIFICATION.md shows passed but no PLAN.md found. Cannot determine quality gate context." |
| Yes | No | **design-time** (mid-execution, treat as pre-plan) |
| Yes | Yes | **adversarial** (pre-ship quality gate) |

**Record the detected mode.** It controls Step 2 behavior for all 9 dimensions.

---

## Step 1: Load all quality dimension skills

Use the Read tool to read each of the following files:

1. `${PLUGIN_ROOT}/skills/modularity/SKILL.md`
2. `${PLUGIN_ROOT}/skills/reusability/SKILL.md`
3. `${PLUGIN_ROOT}/skills/scalability/SKILL.md`
4. `${PLUGIN_ROOT}/skills/security/SKILL.md`
5. `${PLUGIN_ROOT}/skills/reliability/SKILL.md`
6. `${PLUGIN_ROOT}/skills/usability/SKILL.md`
7. `${PLUGIN_ROOT}/skills/testability/SKILL.md`
8. `${PLUGIN_ROOT}/skills/extensibility/SKILL.md`
9. `${PLUGIN_ROOT}/skills/ai-llm-safety/SKILL.md`

---

## Step 2: Apply each dimension

For each dimension, run its **Planning Checklist (design-time mode) or Full Audit (adversarial mode) as determined in Step 0** against the current design or plan.

- **design-time mode:** Run the **Planning Checklist** for each dimension. Focus on design decisions, architectural alignment, and upfront risk identification. N/A is acceptable for implementation-specific items that cannot yet be evaluated.
- **adversarial mode:** Run the **Full Audit** for each dimension. Focus on implementation quality, edge cases, security gaps, and production readiness. N/A requires strong justification — assume the worst case unless evidence proves otherwise.

Work through all items. For each checklist item mark it:

- ✅ Pass — requirement is satisfied
- ❌ Fail — requirement is violated; note the specific gap
- ⚠️ N/A — dimension does not apply to this phase (provide one-sentence justification)

---

## Step 3: Produce consolidated report

Output a report in this format:

```
## Quality Gates Report

| Dimension     | Result | Notes |
|---------------|--------|-------|
| Modularity    | ✅/❌  | ...   |
| Reusability   | ✅/❌  | ...   |
| Scalability   | ✅/❌  | ...   |
| Security      | ✅/❌  | ...   |
| Reliability   | ✅/❌  | ...   |
| Usability     | ✅/❌  | ...   |
| Testability   | ✅/❌  | ...   |
| Extensibility | ✅/❌  | ...   |
| AI/LLM Safety | ✅/❌  | ...   |

### Failures requiring redesign
[List each ❌ item with the specific rule violated and required fix]

### Overall: PASS / FAIL
```

---

## Step 4: Gate enforcement

- If **all dimensions pass:**
  - design-time mode → output "Quality gates passed (design-time). Proceed to planning."
  - adversarial mode → output "Quality gates passed (pre-ship). Proceed to shipping."
- If **any dimension fails** → output "Quality gates FAILED. Redesign required before proceeding."
  List each failure with the specific rule and required corrective action.
  Do NOT proceed until all failures are resolved and this skill is re-run.

**There are no exceptions.** A ❌ is a hard stop, not a warning.

---

## Step 5: Backlog capture (mandatory)

After gate enforcement, scan the report for any items that:
- Were marked ⚠️ N/A but may apply in a future phase
- Were advisory suggestions noted during evaluation (not hard failures)
- Were deferred "nice-to-have" improvements

For each such item, **immediately add it to the GSD backlog** using `/gsd-add-backlog`. Do NOT silently drop suggested items — they must either be implemented now or captured in the backlog.

```
Skill(skill="gsd-add-backlog", args="{item description}")
```

If no items were deferred or suggested, output: "No backlog items to capture from this quality review."
