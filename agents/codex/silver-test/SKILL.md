---
name: "silver:test"
title: "Test"
description: >
  This skill should be used for SB-owned test engineering: test writing,
  E2E route discovery, test repair, test audit, test performance, and
  mutation-style challenge workflows.
argument-hint: "<scope> [--mode write|e2e|repair|audit|performance|mutation]"
version: 0.1.0
---

# /silver:test - Test Engineering Workflow

SB-owned test engineering for creating, repairing, auditing, and proving tests.
It complements `tdd`, `testability`, `verify-tests`, and `silver:verify`; it
does not replace the final verification gate.

Use this skill when the user asks to add tests, generate browser tests, repair
broken tests, audit test quality, speed up a test suite, or challenge a suite
with mutation-style cases.

## Output

Write or update `.planning/TEST-ENGINEERING.md` or the current phase testing
section.

The report must include:

- scope and selected mode;
- discovered production targets and risk ranking;
- test strategy and generated/changed test files;
- quality findings using `test-health` evidence schema;
- commands run and timing where relevant;
- unresolved gaps filed through `silver:add`.

## Modes

| Mode | Purpose | Required evidence |
|---|---|---|
| `write` | Add unit/integration tests for existing code | target classification, missing behavior list, RED/GREEN evidence, meaningful assertions |
| `e2e` | Discover user flows and create browser tests | route/flow inventory, criticality score, Playwright/browser evidence when runnable |
| `repair` | Fix failing or weak tests by anti-pattern family | triage report, selected pattern, production-context check, verification command |
| `audit` | Audit tests against SB test-health gates | file/line evidence, critical gaps, flake/mock/oracle review |
| `performance` | Baseline or improve test runtime | timing baseline, slowest tests, runner/config findings, verify comparison |
| `mutation` | Challenge test effectiveness with meaningful changes | mutation plan, expected kill condition, result, surviving-mutant follow-up |

## Process

1. Display `SILVER BULLET > TEST`.
2. Select the smallest mode set that covers the request. If the request is
   broad, start with `audit` before editing tests.
3. Read production code, existing tests, configured runners, and relevant
   PLAN/SPEC artifacts.
4. Invoke or apply `testability` before designing new tests.
5. Invoke or apply `silver:domain-audit --pack test-health` and include
   `api-contract`, `data-contract`, `ui-system`, or `performance-resource`
   where the tests exercise those surfaces.
6. For `write` and `repair`, require failing-test-first evidence unless the
   work is pure harness/config cleanup; record the exception.
7. For `e2e`, discover routes and user flows from source, routing config, docs,
   and rendered app behavior when available. Score flows by user/business risk.
8. For `performance`, save a baseline before optimization and compare after.
9. For `mutation`, choose behavior-relevant challenges: boundaries, permission
   checks, null/error paths, async ordering, security bypasses, and state
   transitions.
10. Run `verify-tests` or the targeted runner after changes.
11. File deferred non-blocking gaps through `silver:add`.

## Exit Gate

The test workflow passes only when:

- selected modes have direct evidence;
- changed tests fail for the intended reason before passing when TDD applies;
- assertions prove behavior rather than implementation details;
- no unresolved `BLOCK` test-health finding remains;
- final verification commands are fresh and recorded.
