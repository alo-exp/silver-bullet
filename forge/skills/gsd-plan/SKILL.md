---
id: gsd-plan
title: GSD — Plan Phase
description: Create PLAN.md with task breakdown, requirements mapping, and verification steps
trigger:
  - "plan phase"
  - "create plan"
  - "write plan"
  - "planning"
---

# GSD — Plan Phase

## Prerequisites
- Phase goal is clear (from ROADMAP.md)
- If phase had gray areas: CONTEXT.md with locked decisions must exist

## Steps

### Step 1: Read Inputs
Read `.planning/ROADMAP.md` (phase goal), `.planning/REQUIREMENTS.md` (REQ-IDs), and `.planning/phases/<N>/CONTEXT.md` if it exists.

### Step 2: Write PLAN.md
Write `.planning/phases/<N>/PLAN.md` with these sections:
- **Goal** (one sentence)
- **Requirements covered** (list of REQ-IDs from REQUIREMENTS.md)
- **Task breakdown** (ordered list; each task atomic and independently verifiable)
- **Per-task**: file changed, description of change, how to verify it worked
- **Verification steps** (how to know the whole phase is done)
- **Threat model** (if phase touches auth, data persistence, or external services)
- **Rollback** (how to undo this phase if needed)

### Step 3: Run Pre-Plan Quality Gates
Run all 9 quality dimensions against the plan. Fix any ❌ findings before proceeding.

### Step 4: Present for Review
Show the completed PLAN.md and ask: "Does this plan look correct? Any changes before execution?"

## Exit Condition
PLAN.md exists, passes all 9 quality gate dimensions (no ❌), and has been reviewed.
