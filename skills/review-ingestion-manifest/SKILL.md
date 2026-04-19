---
name: review-ingestion-manifest
description: "INGESTION_MANIFEST.md artifact reviewer — validates that all source artifacts are listed, statuses are accurate, failed artifacts have corresponding ARTIFACT MISSING blocks in the linked SPEC.md, and the manifest supports resumability"
argument-hint: "<manifest-path> [--source-inputs <spec-path>]"
user-invocable: false
version: 0.1.0
---

# review-ingestion-manifest

INGESTION_MANIFEST.md reviewer skill. Implements the artifact-reviewer framework interface to validate an INGESTION_MANIFEST.md file against SB ingestion quality criteria. Returns structured PASS/ISSUES_FOUND findings.

## Loading Rules

This reviewer MUST load the following before executing any review:

- `@skills/artifact-reviewer/rules/reviewer-interface.md` — interface contract (input/output shape, prohibitions)
- `@skills/artifact-reviewer/rules/review-loop.md` — 2-pass loop mechanism and audit trail format

## Usage

```
/artifact-reviewer <manifest-path> [--source-inputs <spec-path>]
```

Or invoke directly:
```
/review-ingestion-manifest <manifest-path> [--source-inputs <spec-path>]
```

## Input

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| artifact_path | string | YES | Path to INGESTION_MANIFEST.md file to review |
| source_inputs[0] | string | NO | Path to the linked SPEC.md for cross-reference validation |
| review_context | string | NO | Additional context string |

## Quality Criteria

Read the artifact at `artifact_path` completely before evaluating any criterion. Validate every criterion explicitly — do NOT skip sections.

### QC-1: All Source Artifacts Listed

The manifest MUST contain a row for every artifact referenced in the ingestion run. An ingestion run may reference artifacts via a run configuration, input list, or the associated SPEC.md (when `source_inputs` includes a spec-path). No artifact that was part of the ingestion run may be absent from the manifest.

**If any artifact is missing from the manifest:** Emit ISSUE finding `INGM-F01` with location = the ingestion run or spec section referencing the missing artifact, suggestion = "Add a manifest row for '[artifact identifier]' with the appropriate status (success/failed/skipped) and a reason if applicable."

### QC-2: Status Accuracy — No Blank Statuses

Every row in the manifest table MUST have a non-empty, valid status value. Valid statuses are: `success`, `failed`, `skipped`. A blank status, null, or unrecognized value fails this check.

**If any row has a blank or invalid status:** Emit ISSUE finding `INGM-F10` (increment suffix per row) with location = the manifest row, suggestion = "Set the status to one of: `success`, `failed`, or `skipped`. Use `skipped` when the source artifact was intentionally omitted or not applicable, `failed` when ingestion was attempted but errored."

### QC-3: Failed Artifacts Have Corresponding ARTIFACT MISSING Blocks (when spec-path provided)

**Only evaluate this criterion when `source_inputs` includes a spec-path.**

For every manifest row with status `failed` or `skipped`, there MUST be a corresponding `[ARTIFACT MISSING: reason]` block in the linked SPEC.md. The block must appear in the SPEC.md section that would have contained the artifact's ingested content.

**If a failed/missing artifact has no corresponding ARTIFACT MISSING block in the linked SPEC.md:** Emit ISSUE finding `INGM-F20` (increment suffix per missing block) with location = the manifest row AND the expected SPEC.md section, description = "Failed artifact '[artifact identifier]' has no corresponding `[ARTIFACT MISSING]` block in the linked SPEC.md", suggestion = "Add `[ARTIFACT MISSING: {reason from manifest}]` in the SPEC.md section where this artifact's content would have appeared."

### QC-4: No False Success — Succeeded Artifacts Have Non-Empty Content

**Only evaluate this criterion when `source_inputs` includes a spec-path.**

For every manifest row with status `success`, the ingested content in the linked SPEC.md MUST be non-empty and non-placeholder. Empty content means the section exists but contains only whitespace or template placeholder text (e.g., `[content here]`, `TODO`, `placeholder`, or the literal string "EMPTY").

**If a success artifact has empty or placeholder content in the SPEC.md:** Emit ISSUE finding `INGM-F30` with location = the manifest row AND the empty SPEC.md section, description = "Artifact marked 'success' but ingested content is empty or placeholder in SPEC.md", suggestion = "Correct the manifest status to `failed` or re-run ingestion for this artifact to populate real content."

### QC-5: Reason Field for Failed/Skipped Artifacts

Every manifest row with status `failed` or `skipped` MUST include a non-empty `reason` field (or equivalent column) explaining why the artifact failed or was skipped. A blank reason provides no actionable information.

**If any failed/skipped row has an empty reason:** Emit ISSUE finding `INGM-F40` with location = the manifest row, suggestion = "Add a non-empty reason explaining the failure, e.g., 'Confluence page not found at URL', 'API rate limit exceeded', 'JIRA ticket ID does not exist'."

### QC-6: Resumability — Sufficient State for Re-Run

The manifest MUST include enough state information for silver-ingest to resume from the last successful artifact. Required fields are:
- Artifact IDs or identifiers (unique per artifact, not just display names)
- Timestamps or run ID for the ingestion session

**If artifact IDs are missing:** Emit ISSUE finding `INGM-F50` with suggestion = "Add unique artifact IDs (e.g., JIRA ticket IDs, Confluence page IDs) to each manifest row to enable resumable ingestion."

**If run timestamp or session ID is missing:** Emit INFO finding `INGM-F51` with suggestion = "Add a run timestamp or session ID to the manifest header to identify when this ingestion run occurred and enable auditing."

## Output Contract

Return structured findings using the schema from `reviewer-interface.md`. Finding IDs MUST use the prefix `INGM-F`.

```
status: "PASS" | "ISSUES_FOUND"
findings:
  - id: "INGM-F01"       # unique within this review
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
