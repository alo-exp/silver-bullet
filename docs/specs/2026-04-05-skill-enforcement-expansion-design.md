# Design Spec — Skill Enforcement Expansion

**Date:** 2026-04-05
**Status:** Approved (autonomous)
**Author:** Claude (autonomous session)

---

## Problem

Four skills from installed dependency plugins are used informally or not at all, creating enforcement gaps:

| Skill | Current state | Gap |
|-------|--------------|-----|
| `superpowers:test-driven-development` | "TDD principles apply" — prose only | No skill invocation, no hook enforcement |
| `engineering:tech-debt` | Inline manual step (format a table) | Skill exists but is never invoked |
| `design:accessibility-review` | Not present | UI work has no accessibility gate |
| `engineering:incident-response` | Not present | Incident fast path has no ICS structure |

---

## Approach (selected)

**Hard REQUIRED gates for TDD and tech-debt; conditional REQUIRED for accessibility-review and incident-response.**

- `test-driven-development`: REQUIRED in EXECUTE (both workflows) — invoked at the start of each execute phase to establish red-green-refactor discipline before any implementation code is written. Added to `required_deploy` so completion-audit blocks commits if skipped.
- `tech-debt`: REQUIRED in FINALIZATION (both workflows) — replaces the existing inline manual step. Added to `required_deploy`.
- `accessibility-review`: REQUIRED within the UI work conditional in DISCUSS (full-dev-cycle only) — fires whenever "UI work" is flagged. Conditional on UI work, so not in `required_deploy`.
- `incident-response`: REQUIRED as step 1 of the Incident Fast Path (devops-cycle only) — fires whenever the fast path is triggered. Conditional on incident, so not in `required_deploy`.

Rejected alternatives:
- Making all 4 globally required: `accessibility-review` and `incident-response` are path-specific; forcing them unconditionally would create false negatives and noise.
- Adding all 4 to `required_deploy` only (no workflow text): enforcement without instruction is invisible — the workflow docs are the source of truth that agents read.

---

## Architecture

### Enforcement layers

```
Workflow docs (instruction layer)     → agent reads and follows
.silver-bullet.json all_tracked       → record-skill.sh records invocations
.silver-bullet.json required_deploy   → completion-audit.sh blocks commits
```

No hook changes required. The existing `record-skill.sh` already strips namespace prefixes (`superpowers:test-driven-development` → `test-driven-development`), so the state file will correctly record all 4 new skills when invoked.

### Files changed

| File | Change |
|------|--------|
| `docs/workflows/full-dev-cycle.md` | TDD in EXECUTE, tech-debt in FINALIZATION, accessibility-review in DISCUSS UI conditional |
| `docs/workflows/devops-cycle.md` | TDD in EXECUTE, tech-debt in FINALIZATION, incident-response in INCIDENT FAST PATH |
| `templates/workflows/full-dev-cycle.md` | Mirror of docs/ changes |
| `templates/workflows/devops-cycle.md` | Mirror of docs/ changes |
| `.silver-bullet.json` | Add 4 skills to `all_tracked`; add TDD + tech-debt to `required_deploy` |

---

## Component Design

### full-dev-cycle.md — DISCUSS (step 3)

UI conditional block updated from:
```
- If this phase involves **UI work**: `/design-system` + `/ux-copy`
```
To:
```
- If this phase involves **UI work**: `/design-system` + `/ux-copy` + `/accessibility-review`
  (WCAG 2.1 AA audit against the phase's UI deliverables)   **REQUIRED when UI work** ← DO NOT SKIP
```

### full-dev-cycle.md — EXECUTE (step 6)

New sub-step added before wave dispatch:
```
   `/test-driven-development` — Before writing any implementation code: establish      **REQUIRED** ← DO NOT SKIP
   red-green-refactor discipline. Write the failing test first, make it pass,
   then refactor. TDD applies per task within each GSD wave.
```

### full-dev-cycle.md — FINALIZATION (step 14)

Inline manual step replaced by:
```
14. `/engineering:tech-debt` — Identify, categorize, and prioritize technical debt     **REQUIRED** ← DO NOT SKIP
    introduced or surfaced during this work. Append structured items to
    `docs/tech-debt.md`. Format: `| Item | Severity | Effort | Phase introduced |`.
    Create file if needed.
```

### devops-cycle.md — INCIDENT FAST PATH

New step 1 prepended; existing steps renumbered:
```
1. `/incident-response` — Invoke immediately. Establish severity classification,       **REQUIRED** ← DO NOT SKIP
   owner assignment, comms channel, and timeline tracking before any change is made.
2. Document the incident: what is broken, proposed change, expected outcome.
3–6. (existing steps, renumbered)
```

### devops-cycle.md — EXECUTE (step 7)

Same TDD sub-step as full-dev-cycle, with IaC context:
```
   `/test-driven-development` — Before writing IaC implementation: establish           **REQUIRED** ← DO NOT SKIP
   test-first discipline. For Terraform: Terratest / conftest / OPA.
   For Helm: helm test / BATS. TDD applies per task within each GSD wave.
```

### devops-cycle.md — FINALIZATION (step 17)

Same tech-debt replacement as full-dev-cycle.

### .silver-bullet.json

`all_tracked` additions: `"test-driven-development"`, `"tech-debt"`, `"accessibility-review"`, `"incident-response"`

`required_deploy` additions: `"test-driven-development"`, `"tech-debt"`

---

## Data Flow

```
Agent invokes /test-driven-development
  → record-skill.sh fires (PostToolUse: Skill)
  → strips prefix → records "test-driven-development" to state file
  → later: git commit → completion-audit.sh
  → reads state file → finds "test-driven-development" → ✅

Agent skips /test-driven-development and runs git commit
  → completion-audit.sh fires
  → "test-driven-development" NOT in state file
  → ❌ BLOCKED — lists missing skill
```

---

## Error Handling

- `accessibility-review` and `incident-response` are NOT in `required_deploy` → not enforced by completion-audit. Enforcement is instruction-only for conditional paths.
- If `engineering:tech-debt` is invoked as `tech-debt` (no prefix), record-skill.sh records it correctly (no stripping needed). If invoked as `engineering:tech-debt`, the `engineering:` prefix is stripped → recorded as `tech-debt`. Both work.

---

## Testing

Verify after implementation:
1. `cat ~/.claude/.silver-bullet/state` — confirm new skills appear when invoked
2. Attempt `git commit` without invoking TDD or tech-debt → completion-audit should block
3. Invoke `/test-driven-development` → commit → should pass
4. UI phase: confirm accessibility-review appears in DISCUSS conditional
5. DevOps incident fast path: confirm incident-response is step 1
