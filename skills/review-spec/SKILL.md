---
name: review-spec
description: "SPEC.md artifact reviewer — validates spec quality against the SB spec template: required sections, non-empty overview, user story format, testable acceptance criteria, assumption completeness, and frontmatter fields"
argument-hint: "<spec-path> [--source-inputs <jira-ticket> <figma-url>]"
user-invocable: false
version: 0.1.0
---

# review-spec

SPEC.md reviewer skill. Implements the artifact-reviewer framework interface to validate a SPEC.md file against the SB spec quality criteria. Returns structured PASS/ISSUES_FOUND findings.

## Loading Rules

This reviewer MUST load the following before executing any review:

- `@skills/artifact-reviewer/rules/reviewer-interface.md` — interface contract (input/output shape, prohibitions)
- `@skills/artifact-reviewer/rules/review-loop.md` — 2-pass loop mechanism and audit trail format

## Usage

```
/artifact-reviewer <spec-path> [--source-inputs <jira-ticket> <figma-url>]
```

Or invoke directly:
```
/review-spec <spec-path> [--source-inputs <jira-ticket> <figma-url>]
```

## Input

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| artifact_path | string | YES | Path to SPEC.md file to review |
| source_inputs[0] | string | NO | JIRA ticket URL or ID for cross-reference |
| source_inputs[1] | string | NO | Figma URL for UX Flows cross-reference |
| review_context | string | NO | Additional context string |

## Quality Criteria

Read the artifact at `artifact_path` completely before evaluating any criterion. Validate every criterion explicitly — do NOT skip sections.

### QC-1: Required Sections Present

Check that all of the following section headings exist (case-insensitive `##` level):
- `## Overview`
- `## User Stories`
- `## UX Flows`
- `## Acceptance Criteria`
- `## Assumptions`
- `## Open Questions`
- `## Out of Scope`
- `## Implementations`

**If any section is missing:** Emit ISSUE finding `SPEC-F01` (or increment suffix for each missing section) with severity ISSUE, location = document structure, suggestion = "Add the missing section `## [Section Name]` following the SPEC.md.template structure."

### QC-2: Non-Empty Overview with Problem Statement

The `## Overview` section MUST contain content that is:
- Non-empty (not blank, not just a comment)
- NOT a verbatim copy of the template placeholder: `[2-3 sentence problem statement. Who has the problem. What the problem is.]`
- Contains language describing who has the problem AND what the problem is (look for "user", "team", "developer", or a named persona alongside a described pain or goal)

**If violated:** Emit ISSUE finding `SPEC-F10` with suggestion = "Replace the placeholder with a real 2-3 sentence problem statement naming the affected user and describing the problem clearly."

### QC-3: At Least 1 User Story in Correct Format

The `## User Stories` section MUST contain at least one bullet that matches the pattern:
`As a [persona], I want to [action] so that [outcome].`

All three parts (As a / I want to / so that) must be present. Partial stories fail this check.

**If violated:** Emit ISSUE finding `SPEC-F20` with suggestion = "Add at least one user story in the format: `As a [persona], I want to [action] so that [outcome].`"

### QC-4: At Least 1 Testable Acceptance Criterion

The `## Acceptance Criteria` section MUST contain at least one criterion that is measurable or observable. A criterion is NOT testable if it uses only vague language like "works well", "is fast", "looks good", "is easy to use" without a measurable qualifier.

Signs of testability: specific counts, percentages, named states, error messages, explicit pass/fail conditions, timing thresholds, named user roles.

**If violated:** Emit ISSUE finding `SPEC-F30` with suggestion = "Rewrite acceptance criteria to include measurable/observable language, e.g., 'User can submit the form and receives a confirmation message within 2 seconds.'"

### QC-5: Assumption Status Fields Present

Every ASSUMPTION entry in `## Assumptions` MUST include a `Status:` field with a value of `Resolved`, `Accepted`, or `Follow-up-required`.

Pattern to check (each assumption line or block): `Status: Resolved` or `Status: Accepted` or `Status: Follow-up-required`

**If any assumption lacks a Status field or has an unrecognized value:** Emit ISSUE finding `SPEC-F40` with location = the offending assumption entry, suggestion = "Add `| Status: Resolved` (confirmed correct), `| Status: Accepted` (user acknowledged), or `| Status: Follow-up-required` (needs resolution) to each ASSUMPTION entry."

### QC-6: Frontmatter Completeness

The YAML frontmatter MUST contain all of these fields with non-empty values:
- `spec-version`
- `status`
- `created`
- `last-updated`

**If any field is missing or empty (value is `""`, `null`, `YYYY-MM-DD`, or absent):** Emit ISSUE finding `SPEC-F50` (one finding per missing field) with suggestion = "Set the `[field]` frontmatter field to a real value."

### QC-7: Source Input Consistency (when source_inputs provided)

**Only evaluate this criterion when `source_inputs` is non-empty.**

- **If JIRA ticket provided:** Verify that the User Stories in `## User Stories` align with the acceptance criteria described in the JIRA ticket. If the JIRA ticket defines acceptance criteria that have no corresponding user story in the SPEC, emit ISSUE finding `SPEC-F60`.
- **If Figma URL provided:** Verify that `## UX Flows` references the design (screen names, flow descriptions should correspond to Figma frames or pages described in the URL). If there is no reference to the Figma design in UX Flows, emit ISSUE finding `SPEC-F61`.

**Suggestion for SPEC-F60:** "Add User Stories derived from JIRA acceptance criteria that are not yet represented in this SPEC."
**Suggestion for SPEC-F61:** "Reference the Figma design in UX Flows, e.g., 'See [Figma Frame Name] in [figma-url]' or describe flows corresponding to Figma screens."

## Output Contract

Return structured findings using the schema from `reviewer-interface.md`. Finding IDs MUST use the prefix `SPEC-F`.

```
status: "PASS" | "ISSUES_FOUND"
findings:
  - id: "SPEC-F01"        # unique within this review
    severity: "ISSUE"     # or "INFO"
    description: "..."    # what is wrong
    location: "..."       # section header or line reference
    suggestion: "..."     # specific, actionable fix
```

**Status rules:**
- `PASS` — zero ISSUE-severity findings; INFO findings allowed
- `ISSUES_FOUND` — one or more ISSUE-severity findings

## Reviewer Prohibitions

- Do NOT modify the artifact — this reviewer is strictly read-only
- Do NOT skip sections because they look complete — validate every QC criterion explicitly
- Do NOT return PASS when any required section is missing or empty
- Do NOT conflate INFO and ISSUE — only ISSUE findings block progression
- Do NOT return unstructured prose as the primary output
