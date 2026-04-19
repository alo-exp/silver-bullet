---
name: review-requirements
description: "REQUIREMENTS.md artifact reviewer — validates requirements quality: required sections, REQ-ID format and uniqueness, testable acceptance criteria, priority fields, traceability frontmatter, and SPEC.md criterion coverage"
argument-hint: "<requirements-path> [--source-inputs <spec-path>]"
user-invocable: false
version: 0.1.0
---

# review-requirements

REQUIREMENTS.md reviewer skill. Implements the artifact-reviewer framework interface to validate a REQUIREMENTS.md file against the SB requirements quality criteria. Returns structured PASS/ISSUES_FOUND findings.

## Loading Rules

This reviewer MUST load the following before executing any review:

- `@skills/artifact-reviewer/rules/reviewer-interface.md` — interface contract (input/output shape, prohibitions)
- `@skills/artifact-reviewer/rules/review-loop.md` — 2-pass loop mechanism and audit trail format

## Usage

```
/artifact-reviewer <requirements-path> [--source-inputs <spec-path>]
```

Or invoke directly:
```
/review-requirements <requirements-path> [--source-inputs <spec-path>]
```

## Input

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| artifact_path | string | YES | Path to REQUIREMENTS.md file to review |
| source_inputs[0] | string | NO | Path to linked SPEC.md for cross-reference |
| review_context | string | NO | Additional context string |

## Quality Criteria

Read the artifact at `artifact_path` completely before evaluating any criterion. Validate every criterion explicitly — do NOT skip sections.

### QC-1: Required Sections Present

Check that all of the following section headings exist (case-insensitive `##` level):
- `## Functional Requirements`
- `## Non-Functional Requirements`
- `## Out of Scope`
- `## Open Items`

**If any section is missing:** Emit ISSUE finding `REQ-F01` (increment suffix per missing section) with severity ISSUE, location = document structure, suggestion = "Add the missing section `## [Section Name]` following the REQUIREMENTS.md.template structure."

### QC-2: REQ-ID Format Correctness

Every requirement ID in the document MUST match one of these patterns:
- Functional: `REQ-nn` where `nn` is one or more digits (e.g., `REQ-01`, `REQ-12`)
- Non-functional: `NFR-nn` where `nn` is one or more digits (e.g., `NFR-01`, `NFR-03`)

**If any ID does not match:** Emit ISSUE finding `REQ-F10` with location = the offending row/ID, suggestion = "Rename the ID to follow the pattern `REQ-nn` (functional) or `NFR-nn` (non-functional) where nn is zero-padded digits."

### QC-3: REQ-ID Uniqueness

No two requirements in the entire document (across all sections) may share the same ID.

Procedure: collect all IDs in the document, check for duplicates. Each duplicate pair produces one finding.

**If any duplicate IDs exist:** Emit ISSUE finding `REQ-F20` with location = both offending rows, suggestion = "Rename one of the duplicate `[ID]` entries to a new unique ID, incrementing the number."

### QC-4: Testable Acceptance Criteria / Metrics

Every row in the `## Functional Requirements` table MUST have an Acceptance Criterion column value that is measurable. Every row in the `## Non-Functional Requirements` table MUST have a Metric column value that is measurable.

A value is NOT measurable if it uses only vague language such as: "should work well", "is fast", "is easy", "works correctly", "handles errors" without a specific threshold, state, or observable outcome.

Signs of testability: named error messages, specific counts, time thresholds, percentages, named UI states, boolean observable outcomes (e.g., "button appears", "form is disabled").

**If any row has a non-testable criterion or metric:** Emit ISSUE finding `REQ-F30` with location = the offending row ID, suggestion = "Rewrite the Acceptance Criterion/Metric for `[ID]` to include a measurable qualifier, e.g., a threshold, count, named state, or explicit pass/fail condition."

### QC-5: Priority Field Present and Valid

Every requirement row (in both `## Functional Requirements` and `## Non-Functional Requirements`) MUST have a Priority column value that is one of: `P1`, `P2`, or `P3`.

**If any row is missing Priority or has an invalid value:** Emit ISSUE finding `REQ-F40` with location = the offending row ID, suggestion = "Set the Priority field for `[ID]` to one of: P1, P2, or P3."

### QC-6: Traceability — Derived From Field

The document header or frontmatter MUST reference a valid SPEC.md path in a `**Derived from:**` or `derived-from:` field.

Check for: a line matching `**Derived from:**` or frontmatter `derived-from:` with a non-empty, non-placeholder value (not `""`, not `[spec path]`).

**If missing or empty:** Emit ISSUE finding `REQ-F50` with suggestion = "Add `**Derived from:** .planning/SPEC.md v{spec-version}` at the top of the document to establish traceability."

### QC-7: Source Consistency — SPEC Criterion Coverage (when source_inputs provided)

**Only evaluate this criterion when `source_inputs` contains a spec path.**

Procedure:
1. Read the SPEC.md at `source_inputs[0]`
2. Extract all Acceptance Criteria from `## Acceptance Criteria`
3. For each SPEC acceptance criterion, verify at least one REQ-ID in this REQUIREMENTS.md maps to it (by content alignment — the requirement's acceptance criterion column should capture the same observable outcome)
4. Flag any SPEC criterion that has no corresponding requirement as an orphaned criterion

**If any SPEC criterion has no corresponding requirement:** Emit ISSUE finding `REQ-F60` with location = the SPEC acceptance criterion text, suggestion = "Add a requirement row derived from SPEC acceptance criterion `[criterion text]` so every SPEC criterion has at least one requirement entry."

## Output Contract

Return structured findings using the schema from `reviewer-interface.md`. Finding IDs MUST use the prefix `REQ-F`.

```
status: "PASS" | "ISSUES_FOUND"
findings:
  - id: "REQ-F01"         # unique within this review
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
