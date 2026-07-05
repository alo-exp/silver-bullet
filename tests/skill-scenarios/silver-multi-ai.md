# Multi-AI Task Skill Scenario

## Skill: silver-multi-ai
## Catalog: FS-SILVER_MULTI_AI · AF-DECIDE · EV-FS-SILVER_MULTI_AI
## Context: Cross-model research consolidation within FLOW 4

### Scenario: Prior-art landscape with 3 models

**Trigger:** "Run multi-model prior-art research on agent orchestration tools — consolidate into one report."

**Workflow (AF-DECIDE flow step):**
1. Step 0 — resolve models via `scripts/multi-ai-task-models.py --json`
2. Parse task prompt and select models (default or `--models`)
3. Dispatch parallel per-model research with shared output schema
4. Deduplicate findings across model outputs
5. Resolve classification conflicts with documented tie-breaks
6. Aggregate scoring matrix (median + range per dimension)
7. Emit consolidated report at `--out` directory with `run-manifest.json`

**Pass criteria:** `consolidated.md` exists; `run-manifest.json` has `phases_completed`; per-model raw outputs referenced; conflicts documented in `conflicts.md` when applicable.

**Parent context:** When invoked from `silver:research`, only after user explicitly requests MultAI in the current task; hand off consolidated artifact to clarify apply pass.
