---
name: quality-gates
description: Apply all 9 Silver Bullet quality dimensions against the current design or plan. Use before /gsd:plan-phase in the dev cycle, or ad-hoc to audit any existing code or design.
---

> **Recommended model:** Sonnet (default) — quality gates are structured checklist evaluation, not open-ended reasoning. Sonnet handles all 9 dimensions accurately.

# /quality-gates — Consolidated Quality Review

Applies all 9 Silver Bullet quality dimensions in sequence. Every dimension must
pass before the current plan proceeds to `/gsd:plan-phase`. If any dimension fails,
the design must be corrected before continuing — do not defer.

**Plugin root**: Determine `PLUGIN_ROOT` from this file's path. This file lives at
`${PLUGIN_ROOT}/skills/quality-gates/SKILL.md`, so the plugin root is two directories up.

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

For each dimension, run its **Planning Checklist** against the current design or plan.
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

- If **all dimensions pass** → output "Quality gates passed. Proceed to `/gsd:plan-phase`."
- If **any dimension fails** → output "Quality gates FAILED. Redesign required before planning."
  List each failure with the specific rule and required corrective action.
  Do NOT proceed to `/gsd:plan-phase` until all failures are resolved and this skill is re-run.

**There are no exceptions.** A ❌ is a hard stop, not a warning.
