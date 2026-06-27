# Multi-AI Task Skill Scenario

## Skill: silver-multi-ai-task
## Context: Cross-model research consolidation

### Scenario: Prior-art landscape with 3 models

**Trigger:** "Run multi-model prior-art research on agent orchestration tools — consolidate into one report."

**Workflow:**
1. Parse task prompt and select models (default or `--models`)
2. Dispatch parallel per-model research with shared output schema
3. Deduplicate findings across model outputs
4. Resolve classification conflicts with documented tie-breaks
5. Aggregate scoring matrix (median + range per dimension)
6. Emit consolidated report at `--out` directory

**Pass criteria:** Consolidated artifact exists; per-model raw outputs referenced; conflicts documented.
