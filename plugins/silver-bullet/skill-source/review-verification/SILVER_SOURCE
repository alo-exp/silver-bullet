---
name: review-verification
title: "Silver: Review Verification"
description: This skill should be used for VERIFICATION.md artifact review -- validates that verification evidence is fresh, substantive, traceable, and sufficient for SB completion claims.
argument-hint: "<verification-path> [--source-inputs <plan/spec/requirements paths>]"
user-invocable: false
version: 0.1.0
---

# review-verification

Read-only reviewer for SB verification artifacts. Implements the
artifact-reviewer framework interface and returns structured
PASS/ISSUES_FOUND findings.

## Loading Rules

This reviewer MUST load the following before executing any review:

- `@skills/artifact-reviewer/rules/reviewer-interface.md` — interface contract (input/output shape, prohibitions)
- `@skills/artifact-reviewer/rules/review-loop.md` — depth-aware review loop mechanism and audit trail format

## Quality Criteria

Read the full verification artifact and relevant source inputs before
evaluating.

1. Every acceptance criterion or plan check has verification evidence or an
   explicit documented exception.
2. Evidence is fresh for the current session or release gate; stale historical
   output is labelled as background, not proof.
3. Command output includes command names, pass/fail status, and meaningful
   excerpts or artifact paths.
4. Manual/UI checks describe observed behavior, input data, viewport/device when
   relevant, and expected-vs-actual outcome.
5. Failures are tracked with remediation notes or linked issues.
6. The conclusion matches the evidence; no PASS claim is allowed while blocking
   checks remain unresolved.

## Output Contract

Return structured findings using `VER-F` IDs.

```text
status: "PASS" | "ISSUES_FOUND"
findings:
  - id: "VER-F01"
    severity: "ISSUE"
    description: "..."
    location: "..."
    suggestion: "..."
```

PASS requires zero ISSUE findings. INFO findings are allowed.

## Reviewer Prohibitions

- Do NOT modify the artifact.
- Do NOT treat "tested", "looks good", or "verified" as substantive evidence.
- Do NOT return prose instead of the structured output contract.
