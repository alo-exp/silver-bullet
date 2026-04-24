---
id: writing-plans
title: Writing Implementation Plans
description: Convert approved spec and design into structured implementation plans
trigger:
  - "writing plans"
  - "implementation plan"
  - "write plan"
  - "spec to plan"
---

# Writing Implementation Plans

## Purpose
Transform an approved spec/design into a concrete, actionable implementation plan with tasks, dependencies, and verification steps.

## Prerequisites
- SPEC.md or design document exists
- Brainstorming done (if needed)
- Requirements clearly defined

## Steps

### Step 1: Read the Spec
Read the SPEC.md or design document. Extract:
- Core functionality
- Acceptance criteria
- Non-functional requirements
- Edge cases to handle

### Step 2: Identify Tasks
Break the implementation into atomic tasks. Each task should:
- Be completable in isolation
- Have a clear deliverable
- Be verifiable
- Take 30min to 4 hours

### Step 3: Order Tasks
Arrange tasks in dependency order:
- Foundation tasks first (data models, interfaces)
- Core functionality next
- Integration last
- Testing throughout

### Step 4: Write PLAN.md
```
# Implementation Plan: <Feature>

## Overview
<one paragraph summary>

## Requirements
- REQ-01: <requirement>
- REQ-02: <requirement>

## Task Breakdown

### Task 1: <Name>
- **Files**: <files to create/modify>
- **Description**: <what to do>
- **Verification**: <how to verify>
- **Dependencies**: <task numbers or N/A>

### Task 2: <Name>
...

## Verification
<how to verify the entire feature works>

## Risks & Mitigations
| Risk | Impact | Mitigation |
|------|--------|------------|

## Timeline Estimate
<rough estimate>
```

### Step 5: Review with Quality Gates
Run pre-plan quality gates (trigger: "quality gates") before finalizing.

## Exit Condition
PLAN.md exists with ordered tasks, verification steps, and quality gate sign-off.
