---
name: review-plan
title: "Silver: Review Plan"
description: This skill should be used for PLAN.md artifact review -- validates SB phase plans for scope, dependencies, acceptance criteria, verification evidence, and execution readiness.
argument-hint: "<plan-path> [--source-inputs <context/spec/requirements paths>]"
user-invocable: false
version: 0.1.0
---

# review-plan

Read-only reviewer for SB phase plans. Implements the artifact-reviewer
framework interface and returns structured PASS/ISSUES_FOUND findings.

## Loading Rules

This reviewer MUST load:

- `@skills/artifact-reviewer/rules/reviewer-interface.md`
- `@skills/artifact-reviewer/rules/review-loop.md`

## Quality Criteria

Read the full plan and relevant source inputs before evaluating.

1. Scope is explicit: goal, non-goals, files/areas touched, and blast radius are
   stated.
2. Dependencies are explicit: prerequisite phases, external services, data,
   credentials, and migration order are named.
3. Work is sequenced: tasks are ordered into safe waves with clear handoff
   points.
4. Acceptance criteria are testable and trace to requirements, context, or user
   intent.
5. Verification plan is concrete: commands, manual checks, UI checks, or release
   gates are listed with expected evidence.
6. Risk handling is present: rollback, feature flags, data safety, security, or
   operational concerns are addressed when relevant.
7. The plan does not defer known blockers to a future unspecified phase.

## Output Contract

Return structured findings using `PLAN-F` IDs.

```text
status: "PASS" | "ISSUES_FOUND"
findings:
  - id: "PLAN-F01"
    severity: "ISSUE"
    description: "..."
    location: "..."
    suggestion: "..."
```

PASS requires zero ISSUE findings. INFO findings are allowed.

## Reviewer Prohibitions

- Do NOT modify the artifact.
- Do NOT accept placeholder tasks, placeholder criteria, or vague verification.
- Do NOT return prose instead of the structured output contract.
