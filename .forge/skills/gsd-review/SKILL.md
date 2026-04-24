---
id: gsd-review
title: GSD — Code Review
description: Review changed files for bugs, security issues, and code quality; produce REVIEW.md
trigger:
  - "code review"
  - "review code"
  - "review this"
  - "review changes"
---

# GSD — Code Review

## Steps

### Step 1: Identify Changed Files
List all files changed since the branch diverged from main. Group by module/concern.

### Step 2: Review Each File
For each changed file, check:
- Bugs (logic errors, off-by-one, null pointer risks)
- Security issues (input validation, injection vectors, secrets in code)
- Code quality (single responsibility, naming clarity, unnecessary complexity)
- Test coverage (does every new function have a test?)

### Step 3: Classify Findings
- **CRITICAL**: Data loss, security breach, correctness failure — must fix before merge
- **MAJOR**: Code quality, missing tests, maintainability — should fix
- **MINOR**: Style, naming, nice-to-have — low priority

### Step 4: Write REVIEW.md
Write `.planning/REVIEW.md`:
```
# Code Review

| File | Finding | Severity | Recommendation |
|------|---------|----------|----------------|
...

## Gate: PASS / BLOCK
```
Gate is BLOCK if any CRITICAL findings. PASS if only MAJOR/MINOR.

## Exit Condition
REVIEW.md exists. If gate is BLOCK, exit with instruction to run 'fix review findings'.
