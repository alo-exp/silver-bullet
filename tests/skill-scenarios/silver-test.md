# silver-test Scenario

## Purpose

Validate SB-owned test engineering for test writing, E2E discovery, test repair, test audit, test performance, and mutation-style challenge work.

## Expected Behavior

- Selects the smallest testing mode set for the request.
- Writes `.planning/TEST-ENGINEERING.md` or the current phase testing section.
- Applies `testability`, `verify-tests`, and `silver:domain-audit --pack test-health`.
- Requires RED/GREEN evidence for behavior tests when TDD applies.
- Files deferred non-blocking gaps through `silver:add`.
