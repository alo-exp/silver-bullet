# Phase 2 Context — Skill Enforcement Expansion

**Phase:** 2 — Skill Enforcement Expansion
**Date:** 2026-04-05
**Mode:** autonomous (all gray areas auto-selected, recommended options applied)

---

## Canonical refs

- `docs/workflows/full-dev-cycle.md` — primary workflow doc (full dev cycle)
- `docs/workflows/devops-cycle.md` — primary workflow doc (devops cycle)
- `templates/workflows/full-dev-cycle.md` — template mirror (must stay in sync)
- `templates/workflows/devops-cycle.md` — template mirror (must stay in sync)
- `.silver-bullet.json` — enforcement config (all_tracked, required_deploy)
- `hooks/record-skill.sh` — records Skill tool invocations to state file
- `hooks/completion-audit.sh` — blocks commits/push/deploy if required skills missing
- `docs/specs/2026-04-05-skill-enforcement-expansion-design.md` — approved design spec

---

## Decisions

### 1. test-driven-development

- **Placement:** Sub-step within EXECUTE (step 6 in full-dev-cycle, step 7 in devops-cycle)
- **Position:** Before wave dispatch; invoked once per execution phase to establish TDD discipline
- **Enforcement:** REQUIRED, marked `← DO NOT SKIP`
- **Rationale:** "TDD principles apply" is currently prose-only — no skill invocation, no hook enforcement. Making it a REQUIRED sub-step closes the enforcement gap.
- **`required_deploy`:** YES — `test-driven-development` added to `required_deploy` in `.silver-bullet.json`
- **Devops-cycle note:** IaC context — reference Terratest / conftest / OPA / BATS as test tooling
- **Invocation text:** `/test-driven-development` (short-form, no namespace prefix)

### 2. tech-debt

- **Placement:** Replaces existing inline manual step in FINALIZATION (step 14 in full-dev-cycle, step 17 in devops-cycle)
- **Enforcement:** REQUIRED, marked `← DO NOT SKIP`
- **Rationale:** Inline manual step exists today but no skill is invoked. Replacing with a skill call makes the step auditable by `record-skill.sh`.
- **`required_deploy`:** YES — `tech-debt` added to `required_deploy`
- **Format note:** Retain the table format guidance (`| Item | Severity | Effort | Phase introduced |`) and "Create file if needed" instruction inside the step description
- **Invocation text:** `/tech-debt` (short-form, not `/engineering:tech-debt`)

### 3. accessibility-review

- **Placement:** Added to the UI work conditional block in DISCUSS (step 3, full-dev-cycle only)
- **Current UI conditional:** `/design-system` + `/ux-copy`
- **New UI conditional:** `/design-system` + `/ux-copy` + `/accessibility-review`
- **Enforcement:** REQUIRED when UI work is present (conditional gate, not unconditional)
- **Note:** Add `(WCAG 2.1 AA)` parenthetical to clarify scope
- **`required_deploy`:** NO — conditional on UI work; would cause false failures on non-UI phases
- **devops-cycle:** Not added (no UI work in DevOps workflow)
- **Invocation text:** `/accessibility-review`

### 4. incident-response

- **Placement:** New step 1 of Incident Fast Path in devops-cycle; existing steps renumbered (1→2, 2→3, 3→4, 4→5, 5→6)
- **Enforcement:** REQUIRED when fast path is triggered, marked `← DO NOT SKIP`
- **Rationale:** Incident fast path currently has no ICS structure step. `/incident-response` establishes severity, owner, comms channel, and timeline before any change is made.
- **`required_deploy`:** NO — conditional on incident; would cause false failures on planned work
- **full-dev-cycle:** Not added (no incident fast path)
- **Invocation text:** `/incident-response`

---

## .silver-bullet.json changes

### all_tracked additions
```json
"test-driven-development", "tech-debt", "accessibility-review", "incident-response"
```

### required_deploy additions
```json
"test-driven-development", "tech-debt"
```

---

## Style constraints

- All skill references in workflow docs use **short-form** (no namespace prefix) — consistent with existing `/quality-gates`, `/code-review`, `/blast-radius` etc.
- REQUIRED marker format: `**REQUIRED** ← DO NOT SKIP` (existing convention)
- Alignment: right-align the REQUIRED marker to column ~80 using spaces, consistent with existing steps
- Conditional enforcement note: `**REQUIRED when UI work** ← DO NOT SKIP` for accessibility-review

---

## Out of scope

- Hook changes (record-skill.sh and completion-audit.sh already handle new skills correctly)
- Adding `dispatching-parallel-agents` skill (deferred — lower priority, noted in gap analysis)
- Adding `episodic-memory:search-conversations` as a required step (deferred)

---

## Deferred ideas

- `dispatching-parallel-agents`: Could be required before each Agent Team dispatch. Low urgency — agent dispatch already works. Defer to Phase 3.
- `episodic-memory:search-conversations`: Could be required at session start. Defer.
