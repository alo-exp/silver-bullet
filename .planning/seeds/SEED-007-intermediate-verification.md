---
seed_id: SEED-007
title: Enforce verification-before-completion at intermediate task boundaries
github_issue: 72
priority: medium
planted_during: v0.30.0 Open-Issue Sweep
planted_at: 2026-04-28
trigger_when:
  - A real failure mode is observed: a multi-task autonomous run where intermediate bugs compounded and the end-of-phase verification missed them
  - SB adds a per-task hook (e.g. for completion-tracking) — good time to bundle this in
  - User-feedback signal that "things passed end-verification but were broken inside"
---

# SEED-007: Verification at intermediate task boundaries

## Idea

Today, `verification-before-completion` is enforced once at the final delivery gate. Multi-task autonomous runs can complete several tasks without any verification pass between them; intermediate bugs may compound until the final gate, where the failure mode is harder to attribute.

Two design options from the original issue body:

- **Option A (hook):** PostToolUse/Skill hook injects a reminder to invoke `verification-before-completion` after each `gsd-execute-phase` / `gsd-complete-phase` invocation.
- **Option B (skill step):** Add `verification-before-completion` as an explicit step inside `silver-feature` / `silver-bugfix` / `silver-devops` after each execution phase, not just at the ship gate.

Option B is lower risk and more auditable. Option A is more automatic but harder to test.

## Why This Matters

Catches intermediate compounding bugs before they reach the final gate. Cheap to add (one extra step in the flow skills); modest risk of fatigue/noise if applied too often.

## When to Surface

- A real failure mode is observed (intermediate compounding bug not caught until final verify).
- The flow skills are restructured for any other reason — easier to land alongside.
- User feedback signals that the end-verify gate is too coarse-grained.

## Implementation Sketch (Option B, when triggered)

1. After each `gsd-execute-phase` step in `silver-feature` / `silver-bugfix` / `silver-devops`, insert an explicit `silver:verify` (which wraps `superpowers:verification-before-completion`) step.
2. Make it conditional: only run if state shows ≥1 code-mutating skill since the last verification.
3. Add a hook (`hooks/boundary-verify-check.sh`, PostToolUse/Bash on `git push`) that emits an INFORMATIONAL warning (not a block) when a push occurs and verification hasn't run since the last code-mutating skill.

## Why Deferred

This is a design choice (A vs B) that benefits from a real failure-mode signal to inform the right tradeoff. Picking the wrong option creates either noise (Option A over-fires) or auditability gaps (Option B if applied inconsistently). Wait for evidence before committing.

## References

- GitHub issue: https://github.com/alo-exp/silver-bullet/issues/72
