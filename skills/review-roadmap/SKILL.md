---
name: review-roadmap
description: "ROADMAP.md artifact reviewer — validates roadmap quality: required phase fields, 100% requirement coverage, no phantom requirements, no circular phase dependencies, success criteria derivation, and plans field completeness"
argument-hint: "<roadmap-path> [--source-inputs <requirements-path>]"
user-invocable: false
version: 0.1.0
---

# review-roadmap

ROADMAP.md reviewer skill. Implements the artifact-reviewer framework interface to validate a ROADMAP.md file against the SB roadmap quality criteria. Returns structured PASS/ISSUES_FOUND findings.

## Loading Rules

This reviewer MUST load the following before executing any review:

- `@skills/artifact-reviewer/rules/reviewer-interface.md` — interface contract (input/output shape, prohibitions)
- `@skills/artifact-reviewer/rules/review-loop.md` — 2-pass loop mechanism and audit trail format

## Usage

```
/artifact-reviewer <roadmap-path> [--source-inputs <requirements-path>]
```

Or invoke directly:
```
/review-roadmap <roadmap-path> [--source-inputs <requirements-path>]
```

## Input

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| artifact_path | string | YES | Path to ROADMAP.md file to review |
| source_inputs[0] | string | NO | Path to REQUIREMENTS.md for cross-reference |
| review_context | string | NO | Additional context string |

## Quality Criteria

Read the artifact at `artifact_path` completely before evaluating any criterion. Validate every criterion explicitly — do NOT skip sections.

### QC-1: Every Phase Has Required Fields

For each phase defined in the roadmap, verify all four fields are present and non-empty:
- **Goal** — non-empty, not a placeholder like `[goal text]` or `TBD`
- **Depends on** — present (may be `None` for the first phase, but field must exist)
- **Requirements** — present (may be `None` for infrastructure phases, but field must exist)
- **Success Criteria** — non-empty, not a placeholder

**If any phase is missing a required field or has a placeholder value:** Emit ISSUE finding `ROAD-F01` with location = the phase name and missing field, suggestion = "Fill in the `[field]` for Phase `[N]` with real content. 'Depends on: None' is valid for the first phase."

### QC-2: 100% Requirement Coverage (when source_inputs provided)

**Only evaluate this criterion when `source_inputs` contains a requirements path.**

Procedure:
1. Read the REQUIREMENTS.md at `source_inputs[0]`
2. Extract all requirement IDs (pattern `REQ-nn` and `NFR-nn`)
3. For each requirement ID, verify it appears in at least one phase's Requirements field in the roadmap
4. Any requirement ID not found in any phase's Requirements field is "orphaned"

**If any orphaned requirement exists:** Emit ISSUE finding `ROAD-F10` with location = the orphaned requirement ID, suggestion = "Add `[REQ-ID]` to the Requirements field of the phase where it will be implemented, or create a new phase if no existing phase covers it."

### QC-3: No Phantom Requirements

Every requirement ID referenced in any phase's Requirements field MUST exist in the linked Requirements file (when `source_inputs` provided), OR — if no requirements file is provided — must follow the `REQ-nn`/`NFR-nn` format.

**If any phase references a requirement ID that doesn't exist in the Requirements file:** Emit ISSUE finding `ROAD-F20` with location = the phase name and phantom ID, suggestion = "Either add `[REQ-ID]` to REQUIREMENTS.md with its full definition, or remove it from Phase `[N]`'s Requirements field."

### QC-4: Phase Dependency Correctness

Verify the phase dependency graph has no issues:
- No circular dependencies (Phase A depends on Phase B which depends on Phase A)
- No phase depends on a later-numbered phase (unless explicitly marked `INSERTED` in the phase name or description)

Procedure: build a dependency graph from all `Depends on:` fields, detect cycles and backward references.

**If circular dependency found:** Emit ISSUE finding `ROAD-F30` with location = the phases involved in the cycle, suggestion = "Break the dependency cycle between `[Phase A]` and `[Phase B]` by removing one dependency direction or reordering the phases."

**If backward reference found (not INSERTED):** Emit ISSUE finding `ROAD-F31` with location = the referencing phase, suggestion = "Phase `[N]` depends on Phase `[M]` which comes later. Either reorder the phases or mark Phase `[N]` as INSERTED if it was added out of sequence."

### QC-5: Success Criteria Derivation

For each phase, every Success Criterion in the Success Criteria field should trace to at least one requirement in that phase's Requirements field. A success criterion that references outcomes entirely unrelated to the listed requirements is a traceability gap.

This check applies best-effort alignment: look for semantic overlap between the success criterion language and the requirement descriptions. Do not fail on criteria for infrastructure phases with no requirements.

**If a Success Criterion has no traceable requirement in the phase:** Emit ISSUE finding `ROAD-F40` with location = the phase and criterion, suggestion = "Either add a requirement to Phase `[N]` that this success criterion traces to, or rewrite the criterion to reflect the phase's actual requirements."

### QC-6: Plans Field Completeness

For each phase in the roadmap:
- **Completed phases** (marked as done, shipped, or with a version number): MUST have a non-empty Plans field listing the plan files or plan names that implemented it
- **Upcoming phases** (not yet started): MUST have at least `TBD` in the Plans field

**If a completed phase has an empty Plans field:** Emit ISSUE finding `ROAD-F50` with location = the phase name, suggestion = "Add the list of plan files that implemented Phase `[N]` to the Plans field, e.g., `01-PLAN.md, 02-PLAN.md`."

**If an upcoming phase has no Plans field at all:** Emit ISSUE finding `ROAD-F51` with location = the phase name, suggestion = "Add `Plans: TBD` to Phase `[N]` as a placeholder until plans are drafted."

## Output Contract

Return structured findings using the schema from `reviewer-interface.md`. Finding IDs MUST use the prefix `ROAD-F`.

```
status: "PASS" | "ISSUES_FOUND"
findings:
  - id: "ROAD-F01"        # unique within this review
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
