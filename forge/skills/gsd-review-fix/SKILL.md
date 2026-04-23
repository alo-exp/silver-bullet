---
id: gsd-review-fix
title: GSD — Fix Code Review Findings
description: Address code review findings systematically with atomic commits
trigger:
  - "fix review findings"
  - "address review"
  - "fix code review"
---

# GSD — Fix Code Review Findings

## Prerequisites
REVIEW.md must exist with findings to address. If no findings: "No review findings to address."

## Steps

### Step 1: Read REVIEW.md
Identify all CRITICAL and MAJOR findings that need addressing.

### Step 2: Sort by Priority
Fix CRITICAL findings first, then MAJOR, then MINOR. Never defer CRITICAL findings.

### Step 3: Fix Each Finding
For each finding:
1. Understand the issue
2. Apply the fix
3. Run verification (tests, linter)
4. Commit with `fix(<scope>): <brief description>` + DCO sign-off

### Step 4: Re-run Review
After fixing, run 'code review' to verify all findings are resolved.

## Exit Condition
All CRITICAL and MAJOR findings resolved. New REVIEW.md shows only MINOR findings (if any).
