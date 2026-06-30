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
5. For behavior-changing, release, API, data, performance, runtime, content,
   benchmark, refactor, deployment, canary, incident, or test-engineering work,
   invoke or apply `silver:domain-audit` with `test-health` plus the affected
   domain packs. Verification may reuse an existing fresh DOMAIN-AUDIT.md only
   when it covers the current diff and command evidence.
6. When verification discovers missing tests, route to `silver:test` instead of
   accepting coverage as a vague follow-up. Use the relevant mode:
   `write`, `e2e`, `repair`, `audit`, `performance`, or `mutation`.
7. If coverage gaps are found, add or request missing tests before passing the
   gate.
8. Record UAT evidence, commands run, results, unverified claims, and residual
   risks. When UAT requires browser interaction, follow `silver-bullet.md §8.1`
   fallback hierarchy:
   - **Alumnium (preferred):** when configured, use `do` / `check` / `get` for
     acceptance-criteria evidence; attach results to VERIFICATION.md.
   - **Host browser MCP:** when Alumnium is absent, navigate to the app, walk
     UAT steps with `browser_click` / `browser_type` / `browser_scroll`,
     verify state via `browser_snapshot`, and capture `browser_take_screenshot`
     per criterion. task host: `host browser MCP` tools. Attach evidence to
     VERIFICATION.md.
   - **Text-only:** document unverified browser-dependent criteria as WARN when
     neither path is available.
9. File deferred non-blocking gaps through `silver:add`.

## Exit Gate

Verification passes only when:

- must-have behavior is evidenced;
- tests are fresh enough for the change;
- missing evidence is classified as BLOCK/WARN/INFO;
- BLOCK findings are resolved before ship.
