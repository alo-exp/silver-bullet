---
name: "silver:verify"
title: "Verify"
description: This skill verifies completed SB work against plan, spec, tests, UAT criteria, and artifact requirements.
argument-hint: "<phase or completion claim>"
version: 0.1.0
---

# /silver:verify - Work Verification

SB-owned verification checks actual artifacts, acceptance criteria, tests, and
evidence rather than agent confidence.

## Output

Write or update `.planning/phases/<phase>/VERIFICATION.md` or
`.planning/VERIFICATION.md` for project-level work.

## Process

1. Display `SILVER BULLET > VERIFY`.
2. Read SPEC, PLAN, SUMMARY, REVIEW, VALIDATION, and relevant docs.
3. Check each acceptance criterion and plan task against actual files.
4. Run fresh tests or invoke `verify-tests` when the verification requires a
   broader test gate.
5. For behavior-changing, release, API, data, performance, runtime, or
   benchmark-sensitive work, invoke or apply `silver:domain-audit` with
   `test-health` plus the affected domain packs. Verification may reuse an
   existing fresh DOMAIN-AUDIT.md only when it covers the current diff and
   command evidence.
6. If coverage gaps are found, add or request missing tests before passing the
   gate.
7. Record UAT evidence, commands run, results, unverified claims, and residual
   risks.
8. File deferred non-blocking gaps through `silver:add`.

## Exit Gate

Verification passes only when:

- must-have behavior is evidenced;
- tests are fresh enough for the change;
- missing evidence is classified as BLOCK/WARN/INFO;
- BLOCK findings are resolved before ship.
