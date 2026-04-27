---
name: gsd-secure
id: gsd-secure
title: GSD — Security Review
description: Security audit of changes; enforce defense in depth and OWASP best practices
trigger:
  - "security review"
  - "secure phase"
  - "security audit"
---

# GSD — Security Review

## When to Use
Mandatory step before shipping. Run the security quality dimension checklist against all changes.

## Steps

### Step 1: Identify Security-Touching Files
From REVIEW.md or git diff, list files that handle:
- Authentication/authorization
- Data persistence
- External API calls
- User input
- File operations
- Secrets management

### Step 2: Run Security Checklist
Check each security-touching file against the security quality dimension:
- Input validation on all boundaries
- Parameterized queries (no string concatenation)
- Proper output encoding
- Auth/authz checks on every endpoint
- No hardcoded secrets
- Secure defaults

### Step 3: Write SECURITY.md
```
# Security Review — Phase <N>

## Scope
<files reviewed>

## Findings

| ID | File | Issue | Severity | Status |
|----|------|-------|----------|--------|
| SEC-01 | | | | |

## Gate: PASS / FAIL
```

### Step 4: Fix Critical Findings
Any CRITICAL security issue must be fixed before proceeding. MAJOR/MINOR can be logged as technical debt.

## Exit Condition
SECURITY.md exists with Gate: PASS (or all CRITICAL findings fixed).
