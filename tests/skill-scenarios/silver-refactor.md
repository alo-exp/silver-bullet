# silver-refactor Scenario

## Purpose

Validate SB-owned behavior-preserving refactor workflow.

## Expected Behavior

- Writes `.planning/REFACTOR.md`.
- Establishes behavior contract and baseline tests before editing.
- Routes missing baseline coverage to `silver:test --mode write`.
- Applies code-health, structure-maintainability, test-health, and affected domain packs.
- Blocks unrelated churn and unverified behavior changes.
