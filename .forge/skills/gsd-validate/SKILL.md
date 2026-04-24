---
id: gsd-validate
title: GSD — Validation Phase
description: Validate that implementation matches spec and requirements
trigger:
  - "validate phase"
  - "validate implementation"
  - "spec validation"
---

# GSD — Validation Phase

## When to Use
After implementation but before shipping. Confirms the work matches the spec and all requirements are covered.

## Steps

### Step 1: Read SPEC.md
Read `.planning/SPEC.md` to understand the specification requirements.

### Step 2: Cross-Check Implementation
For each requirement in SPEC.md:
1. Identify the files that implement it
2. Verify the implementation matches the spec
3. Note any gaps or deviations

### Step 3: Check REQUIREMENTS.md Coverage
Read `.planning/REQUIREMENTS.md`. For each REQ-ID:
- Verify the requirement is implemented
- Verify it passes its acceptance criteria
- Note any unimplemented or partially implemented requirements

### Step 4: Write VALIDATION.md
```
# Validation Report — Phase <N>

## Requirements Coverage

| REQ-ID | Requirement | Implementation | Status |
|--------|-------------|----------------|--------|
| REQ-01 | | | COVERED / PARTIAL / MISSING |

## Gaps Found

<list of any gaps or deviations>

## Gate: PASS / FAIL
```

## Exit Condition
VALIDATION.md exists with Gate: PASS (all REQ-IDs covered).
