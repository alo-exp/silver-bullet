---
name: review-uat
description: "UAT.md artifact reviewer — validates that every SPEC.md Acceptance Criterion has a UAT row, evidence is substantive (not 'looks good'), spec-version matches, and all results have pass/fail status with evidence"
argument-hint: "<uat-path> [--source-inputs <spec-path>]"
user-invocable: false
version: 0.1.0
---

# review-uat

UAT.md reviewer skill. Implements the artifact-reviewer framework interface to validate a UAT.md file against SB UAT quality criteria. Returns structured PASS/ISSUES_FOUND findings.

## Loading Rules

This reviewer MUST load the following before executing any review:

- `@skills/artifact-reviewer/rules/reviewer-interface.md` — interface contract (input/output shape, prohibitions)
- `@skills/artifact-reviewer/rules/review-loop.md` — 2-pass loop mechanism and audit trail format

## Usage

```
/artifact-reviewer <uat-path> [--source-inputs <spec-path>]
```

Or invoke directly:
```
/review-uat <uat-path> [--source-inputs <spec-path>]
```

## Input

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| artifact_path | string | YES | Path to UAT.md file to review |
| source_inputs[0] | string | NO | Path to the linked SPEC.md for acceptance criteria cross-reference |
| review_context | string | NO | Additional context string |

## Quality Criteria

Read the artifact at `artifact_path` completely before evaluating any criterion. Validate every criterion explicitly — do NOT skip sections.

### QC-1: Coverage — Every Acceptance Criterion Has a UAT Row (when spec-path provided)

**Only evaluate this criterion when `source_inputs` includes a spec-path.**

Every Acceptance Criterion listed in the `## Acceptance Criteria` section of the linked SPEC.md MUST have a corresponding row in the UAT.md. A UAT row "corresponds" to an AC if it references the AC by ID, text, or clear paraphrase. Missing ACs produce ISSUE findings.

**If any Acceptance Criterion has no corresponding UAT row:** Emit ISSUE finding `UAT-F01` (increment suffix per missing AC) with location = the missing AC in the SPEC.md, description = "Acceptance Criterion '[AC ID or text]' has no corresponding UAT row", suggestion = "Add a UAT row covering this acceptance criterion with a pass/fail result and substantive evidence of testing."

### QC-2: No Orphaned UAT Rows

Every UAT row MUST trace back to a Acceptance Criterion in the linked SPEC.md (when source_inputs provides a spec-path). A UAT row with no traceable AC is an orphan — it tests something not required.

**If any orphaned UAT row found (spec-path available):** Emit ISSUE finding `UAT-F10` with location = the orphaned row, suggestion = "Either remove this UAT row (if it tests something out of scope) or add the corresponding Acceptance Criterion to the SPEC.md."

### QC-3: Evidence Quality — No Non-Substantive Evidence

Every UAT row's evidence field MUST describe what was observed or measured. Non-substantive evidence produces ISSUE findings. A row's evidence is non-substantive if it contains ONLY one or more of these phrases without further detail:
- "looks good"
- "works"
- "tested"
- "OK"
- "passed"
- "verified"
- "done"

Substantive evidence describes observable outcomes: "Submitted the registration form with a duplicate email — received error message 'Email already in use' within 1 second", "Loaded dashboard with 10,000 records — page rendered in 2.1 seconds (< 3s threshold)."

**If any non-substantive evidence found:** Emit ISSUE finding `UAT-F20` (increment suffix per row) with location = the UAT row, description = "Non-substantive evidence — does not describe what was observed or measured", suggestion = "Replace the evidence with a description of what was observed: what action was taken, what the system returned, and whether it matched the expected outcome."

### QC-4: Spec-Version Match

The UAT.md MUST include a `spec-version` field (in frontmatter or a metadata section) that matches the `spec-version` field in the linked SPEC.md (when source_inputs provides a spec-path).

A mismatch means the UAT was written against a different version of the spec than the current one — any intervening spec changes may not be covered.

**If spec-version is missing from UAT.md:** Emit ISSUE finding `UAT-F30` with suggestion = "Add a `spec-version:` field to the UAT.md frontmatter or metadata section matching the SPEC.md spec-version value."

**If spec-version values do not match (spec-path available):** Emit ISSUE finding `UAT-F31` with location = the spec-version fields in both files, description = "UAT.md spec-version '[UAT version]' does not match SPEC.md spec-version '[SPEC version]' — UAT may be stale", suggestion = "Update the UAT.md to cover any Acceptance Criteria changes since spec-version '[SPEC version]', then update the spec-version field to match."

### QC-5: No Blank Results — Every Row Has Status and Evidence

Every UAT row MUST have:
1. A `result` field set to either `pass` or `fail` (not blank, not "TBD", not "pending")
2. A non-empty `evidence` field

A UAT with blank results is not a completed UAT — it is a template.

**If any row has a blank result or missing evidence:** Emit ISSUE finding `UAT-F40` (increment suffix per row) with location = the UAT row, suggestion = "Complete this UAT row: set result to `pass` or `fail` and add evidence describing what was observed when testing this criterion."

### QC-6: Fail Follow-Up — Failed Rows Have Linked Issues or Remediation Notes

Any UAT row marked `fail` MUST include either:
- A link to a tracked issue (e.g., GitHub issue URL, JIRA ticket ID), OR
- A remediation note describing the planned fix

A bare `fail` with no follow-up leaves the defect untracked.

**If any failed row has no linked issue or remediation note:** Emit ISSUE finding `UAT-F50` with location = the failing UAT row, suggestion = "Add a linked issue (e.g., GitHub issue URL or JIRA ticket ID) or a remediation note describing how this failure will be addressed."

## Output Contract

Return structured findings using the schema from `reviewer-interface.md`. Finding IDs MUST use the prefix `UAT-F`.

```
status: "PASS" | "ISSUES_FOUND"
findings:
  - id: "UAT-F01"        # unique within this review
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
