---
id: quality-gates
title: Quality Gates — All 9 Dimensions
description: Runs all 9 quality dimensions in sequence; design-time or pre-ship mode auto-detected
trigger:
  - "quality gates"
  - "all 9 dimensions"
  - "quality review"
  - "ilities"
  - "silver quality"
---

# Quality Gates — Consolidated Review

## Mode Detection
Check if `.planning/VERIFICATION.md` exists with `status: passed`:
- If YES → **Pre-ship mode** (adversarial audit — N/A requires strong evidence)
- If NO → **Design-time mode** (planning checklist — N/A acceptable for unimplemented items)

## Run All 9 Dimensions
For each dimension below, evaluate every checklist item and mark ✅/❌/⚠️N/A.

### 1. Modularity
Run the `modularity` skill checklist against current plan or implementation.

### 2. Reusability
Run the `reusability` skill checklist.

### 3. Scalability
Run the `scalability` skill checklist.

### 4. Security
Run the `security` skill checklist. Note: Security items are NON-N/A — any unimplemented security measure must be addressed.

### 5. Reliability
Run the `reliability` skill checklist.

### 6. Usability
Run the `usability` skill checklist.

### 7. Testability
Run the `testability` skill checklist.

### 8. Extensibility
Run the `extensibility` skill checklist.

### 9. AI/LLM Safety
Run the `ai-llm-safety` skill checklist.

## Consolidated Report
Write to `.planning/QUALITY-GATES.md`:
```
# Quality Gates Report

## Mode: [Design-Time | Pre-Ship]
## Date: <YYYY-MM-DD>

| Dimension | Result | Notes |
|-----------|--------|-------|
| Modularity | ✅/❌/⚠️ | |
| Reusability | ✅/❌/⚠️ | |
| Scalability | ✅/❌/⚠️ | |
| Security | ✅/❌/⚠️ | |
| Reliability | ✅/❌/⚠️ | |
| Usability | ✅/❌/⚠️ | |
| Testability | ✅/❌/⚠️ | |
| Extensibility | ✅/❌/⚠️ | |
| AI/LLM Safety | ✅/❌/⚠️ | |

## Gate Enforcement
Any ❌ = **hard stop**. List each failure with specific fix required.
```

## Gate Enforcement
Any ❌ = **hard stop**. Do not proceed until resolved and gates re-run.

## Backlog Capture
Any ⚠️N/A items with future applicability → write to `.planning/BACKLOG.md`.

## Exit Condition
All dimensions ✅ or ⚠️N/A. Output "Quality gates PASSED."
