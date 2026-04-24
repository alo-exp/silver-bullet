---
id: gsd-progress
title: GSD — Progress Report
description: Show current phase status, remaining tasks, and next actions
trigger:
  - "progress"
  - "what's left"
  - "status"
  - "where are we"
  - "current state"
---

# GSD — Progress Report

## Steps

### Step 1: Read STATE.md
Parse `.planning/STATE.md` for:
- Current phase
- Completed phases
- Active plan status

### Step 2: Read ROADMAP.md
Identify remaining phases and their goals.

### Step 3: Check Current Plan
If PLAN.md exists for current phase:
- List remaining tasks
- Note any blockers

### Step 4: Generate Report
```
# Progress Report

## Current Phase
Phase <N>: <name>
Status: <in-progress | blocked | complete>

## Completed
- Phase 1: ✅
- Phase 2: ✅
- Phase 3: 🔄 (current)

## Remaining
- Phase 4: <goal>
- Phase 5: <goal>

## Current Tasks
- [ ] <task 1>
- [ ] <task 2>

## Next Action
<what to do next>
```

## Exit Condition
Progress report displayed. User knows what's done, what's left, and what to do next.
