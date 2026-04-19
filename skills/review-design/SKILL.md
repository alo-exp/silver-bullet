---
name: review-design
description: "DESIGN.md artifact reviewer — validates design quality against the SB design template: required sections, non-empty screen/component fields, behavior and state tables, and orphaned component detection against SPEC.md"
argument-hint: "<design-path> [--source-inputs <spec-path>]"
user-invocable: false
version: 0.1.0
---

# review-design

DESIGN.md reviewer skill. Implements the artifact-reviewer framework interface to validate a DESIGN.md file against the SB design quality criteria. Returns structured PASS/ISSUES_FOUND findings.

## Loading Rules

This reviewer MUST load the following before executing any review:

- `@skills/artifact-reviewer/rules/reviewer-interface.md` — interface contract (input/output shape, prohibitions)
- `@skills/artifact-reviewer/rules/review-loop.md` — 2-pass loop mechanism and audit trail format

## Usage

```
/artifact-reviewer <design-path> [--source-inputs <spec-path>]
```

Or invoke directly:
```
/review-design <design-path> [--source-inputs <spec-path>]
```

## Input

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| artifact_path | string | YES | Path to DESIGN.md file to review |
| source_inputs[0] | string | NO | Path to linked SPEC.md for cross-reference |
| review_context | string | NO | Additional context string |

## Quality Criteria

Read the artifact at `artifact_path` completely before evaluating any criterion. Validate every criterion explicitly — do NOT skip sections.

### QC-1: Required Sections Present

Check that all of the following section headings exist (case-insensitive `##` level):
- `## Screens`
- `## Components`
- `## Behavior Specifications`
- `## State Definitions`

**If any section is missing:** Emit ISSUE finding `DESIGN-F01` (increment suffix per missing section) with severity ISSUE, location = document structure, suggestion = "Add the missing section `## [Section Name]` following the DESIGN.md.template structure."

### QC-2: Every Screen Has Required Fields

For each screen defined under `## Screens` (each `### [Screen Name]` subsection), verify all three fields are present and non-empty:
- `**Purpose:**` — non-empty, not just `[what the user sees and does here]`
- `**Entry point:**` — non-empty, not just `[how user reaches this screen]`
- `**Exit points:**` — non-empty, not just `[navigation options from this screen]`

**If any screen is missing a field or has a placeholder value:** Emit ISSUE finding `DESIGN-F10` with location = the screen name and field, suggestion = "Fill in the `[field]` for screen `[Screen Name]` with real design content."

### QC-3: Every Component Has Required Fields

For each component defined under `## Components` (each `### [Component Name]` subsection), verify all three fields are present and non-empty:
- `**Type:**` — non-empty, not just `[button / modal / form / list / card / etc.]`
- `**State variants:**` — non-empty, not just `[default / loading / error / empty / success]`
- `**Behavior:**` — non-empty, not just `[what happens on interaction]`

**If any component is missing a field or has a placeholder value:** Emit ISSUE finding `DESIGN-F20` with location = the component name and field, suggestion = "Fill in the `[field]` for component `[Component Name]` with real design content."

### QC-4: Behavior Specifications Table Has At Least 1 Real Row

The `## Behavior Specifications` table MUST have at least 1 data row (not the header row, not the template placeholder row) with non-empty values in all three columns: Trigger, Condition, System Response.

**If the table is missing or has only the template placeholder:** Emit ISSUE finding `DESIGN-F30` with suggestion = "Add at least one real row to the Behavior Specifications table with a specific Trigger, Condition, and System Response."

### QC-5: State Definitions Table Has At Least 1 Real Row

The `## State Definitions` table MUST have at least 1 data row with non-empty values in all three columns: State, Description, Visual Indicator.

**If the table is missing or has only the template placeholder:** Emit ISSUE finding `DESIGN-F40` with suggestion = "Add at least one real row to the State Definitions table with a specific State, Description, and Visual Indicator."

### QC-6: No Orphaned Components (when source_inputs includes spec-path)

**Only evaluate this criterion when `source_inputs` contains a spec path.**

Every Component named in `## Components` and referenced in `## Behavior Specifications` or `## Screens` must correspond to at least one User Story in the linked SPEC.md.

Procedure:
1. Read the SPEC.md at `source_inputs[0]`
2. Extract all User Stories from `## User Stories`
3. For each Component in `## Components`, check if any User Story's action or outcome references the component's purpose or name
4. A component is "orphaned" if no User Story in SPEC.md plausibly covers its functionality

**If any orphaned component is found:** Emit ISSUE finding `DESIGN-F50` with location = the component name, suggestion = "Either add a User Story to SPEC.md covering `[Component Name]`, or remove the component if it is out of scope."

### QC-7: Frontmatter — linked-spec Field Present

The YAML frontmatter MUST contain a `linked-spec` field with a non-empty value (not `""` or absent).

**If missing or empty:** Emit ISSUE finding `DESIGN-F60` with suggestion = "Set `linked-spec` in the frontmatter to the path of the SPEC.md this design implements, e.g., `.planning/SPEC.md`."

## Output Contract

Return structured findings using the schema from `reviewer-interface.md`. Finding IDs MUST use the prefix `DESIGN-F`.

```
status: "PASS" | "ISSUES_FOUND"
findings:
  - id: "DESIGN-F01"      # unique within this review
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
