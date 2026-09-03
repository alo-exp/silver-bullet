# `/silver:new-workflow` Meta Workflow — Plan

**Branch:** `feature/silver-agent-claude-skill`  
**Date:** 2026-07-05  
**Status:** implementation in progress

## Goal

Deliver `/silver:new-workflow` — a catalog-backed meta workflow that creates or promotes SB workflows/atomic flows from user intent, with safe target-repo selection, reuse analysis, plan RFL, implementation, validation, and local catalog registration.

## Modes

| Mode | Trigger | Outcome |
|------|---------|---------|
| **Create** | User describes a new workflow intent | New composer skill + catalog workflow + hooks/tests/docs |
| **Convert** | User supplies existing skill/workflow path | Gap review → compliant SB workflow/AF + catalog entries |

## Composition (catalog)

`WF-SILVER-NEW-WORKFLOW` (precomposed):

```
AF-CLARIFY → AF-ORIENT → AF-DECIDE → AF-PLAN → AF-REVIEW-TRIAGE → AF-EXECUTE → AF-VERIFY → AF-VALIDATE → AF-DOCUMENT
```

**Enforcement queue:** `silver-clarify`, `silver-scan`, `silver-research`, `silver-plan`, `silver-review-fix-ladder`, `silver-execute`, `silver-verify`, `silver-validate`, `silver-ensure-docs`

## Target repo safety

1. Ask which repo (default: current project root from `PWD` / workspace).
2. Record in `.planning/new-workflow-session.json`: `{ target_repo, mode, intent, created_at }`.
3. Writes outside `target_repo` and SB source catalog (`docs/apo-catalog.json`, `scripts/generate-apo-catalog.py`, `skills/`, `hooks/`) require explicit user confirmation.
4. Rollback: git stash/checkout in target repo; revert catalog edits via git.

## Reuse analysis (Step 2)

Before inventing AFs:

- `graphify query` for existing workflows, AFs, and similar skills
- Read `docs/apo-catalog.json` / `docs/composable-flows-contracts.md` composition matrix
- Prefer reusing `WF-POST-EXEC-GATES`, `WF-REVIEW-TRIAD`, existing AF prefixes

## Implementation checklist (per new workflow)

- [ ] `skills/silver-<slug>/SKILL.md` composer spec
- [ ] `scripts/generate-apo-catalog.py`: `SKILL_TO_FLOW`, `PRECOMPOSED`, `build_workflows()` entry
- [ ] `hooks/lib/orchestrator-state.sh`: composer + queue
- [ ] `hooks/workflow-chain-guard.sh`: pre-exec markers
- [ ] `skills/silver/SKILL.md`: router row
- [ ] `scripts/generate-plugin-commands.sh` if top route
- [ ] `templates/orchestrator-workers/<TEMPLATE>.md` if custom worker needed
- [ ] Focused test + `bash scripts/run-apo-authoring-compliance.sh`
- [ ] `python3 scripts/generate-apo-catalog.py` + `generate-apo-artifacts.py`
- [ ] `bash scripts/sync-codex-package.sh` + `sync-templates.sh`

## Artifacts

| Artifact | Path |
|----------|------|
| Skill | `skills/silver-new-workflow/SKILL.md` |
| Worker template | `templates/orchestrator-workers/NEW-WORKFLOW.md` |
| Validation helper | `scripts/validate-workflow-authoring.sh` |
| Runbook | `docs/NEW-WORKFLOW.md` |
| Test | `tests/scripts/test-silver-new-workflow.sh` |

## Review-fix ladder (plan phase)

**Scope:** `.planning/NEW-WORKFLOW-META-WORKFLOW-PLAN.md`, `skills/silver-new-workflow/SKILL.md` (draft)

**Charter goals:**
- Two modes (create vs convert) distinguished
- Target repo default + safety gates documented
- Catalog/hook/skill surfaces enumerated
- Reuse-before-invent policy explicit
- RFL on plan before code; post-ship RFL on delivered artifacts

**Charter non-goals:** Release/version bumps; modifying unrelated release worker state

### RFL rung outcomes

| Rung | Phase | Result |
|------|-------|--------|
| composer-2.5 / low | audit_fix | Added rollback section; clarified convert-mode gap review; fixed queue token list |
| composer-2.5 / low | verify_1 | Clean — charter signals present |
| composer-2.5 / low | verify_2 | Clean — no new issues |
| composer-2.5 / medium | audit_fix | Added `validate-workflow-authoring.sh` gate; documented sync script order |
| composer-2.5 / medium | verify_1 | Clean |
| composer-2.5 / medium | verify_2 | Clean — plan ready for implementation |

**Plan RFL status:** PASS (no open issues on final medium rung)

## Post-implementation RFL

Deferred until shipped artifacts exist; close-out tracked in `.planning/reviews/NEW-WORKFLOW-RFL-CLOSEOUT.md` after tests green.
