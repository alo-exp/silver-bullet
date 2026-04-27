---
name: gsd-execute
id: gsd-execute
title: GSD — Execute Phase
description: Execute PLAN.md with atomic commits, deviation handling, and TDD discipline
trigger:
  - "execute phase"
  - "implement"
  - "execute plan"
  - "build it"
---

# GSD — Execute Phase

## Hard Prerequisites
PLAN.md must exist. If it doesn't, say: "No PLAN.md found. Run 'plan phase <N>' first." Do not proceed without it.

## Steps

### Step 1: Read PLAN.md
Read the full plan. Note the task order and dependencies.

### Step 2: TDD Setup
For any task that creates new functions or modules: write the failing test FIRST. Commit the failing test stub before writing implementation. See the `tdd` skill.

### Step 3: Execute Tasks in Order
For each task in PLAN.md:
1. Implement the task
2. Run its verification step
3. If it passes: commit with `feat(<phase>): <task description>` + DCO sign-off
4. If it fails: fix it before moving to the next task
5. Mark ✅ in session log

### Step 4: Deviation Handling
If execution deviates from PLAN.md: document the deviation, explain why, and confirm before proceeding with the alternative approach. Never silently ignore plan deviations.

## Exit Condition
All tasks in PLAN.md marked ✅, all local tests pass, all commits have DCO sign-off.
