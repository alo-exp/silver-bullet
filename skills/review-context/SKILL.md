---
name: review-context
description: "CONTEXT.md artifact reviewer — validates that all discussion points are resolved (locked decision or Claude's Discretion), decisions are specific (not vague), and no contradictions exist between decisions"
argument-hint: "<context-path>"
user-invocable: false
version: 0.1.0
---

# review-context

CONTEXT.md reviewer skill. Implements the artifact-reviewer framework interface to validate a CONTEXT.md file against SB context quality criteria. Returns structured PASS/ISSUES_FOUND findings.

## Loading Rules

This reviewer MUST load the following before executing any review:

- `@skills/artifact-reviewer/rules/reviewer-interface.md` — interface contract (input/output shape, prohibitions)
- `@skills/artifact-reviewer/rules/review-loop.md` — 2-pass loop mechanism and audit trail format

## Usage

```
/artifact-reviewer <context-path>
```

Or invoke directly:
```
/review-context <context-path>
```

## Input

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| artifact_path | string | YES | Path to CONTEXT.md file to review |
| source_inputs | string[] | NO | Optional additional context paths |
| review_context | string | NO | Additional context string |

## Quality Criteria

Read the artifact at `artifact_path` completely before evaluating any criterion. Validate every criterion explicitly — do NOT skip sections.

### QC-1: Decisions Section Exists and Is Non-Empty

The artifact MUST contain a `## Decisions` (or `# Decisions`) section with at least one decision entry. A section that exists but contains only whitespace or placeholder text fails this check.

**If missing or empty:** Emit ISSUE finding `CTX-F01` with suggestion = "Add a `## Decisions` section listing at least one resolved decision or marking items as Claude's Discretion."

### QC-2: Every Gray Area Has a Resolution

Every discussion point, open question, or gray area noted in the CONTEXT.md MUST have a resolution. A resolution is either:
- A **locked decision** — a specific concrete choice has been made and documented
- **Claude's Discretion** — explicitly marked as delegated to Claude

A gray area is unresolved if it is listed without any resolution or still phrased as a question with no answer below it.

**If any unresolved gray area found:** Emit ISSUE finding `CTX-F02` (increment suffix for each instance) with location = the unresolved item, suggestion = "Resolve this point — either record the concrete decision made or mark it as `Claude's Discretion: [context for Claude to decide]`."

### QC-3: Decision Specificity — No Vague Decisions

Each locked decision MUST contain a concrete, specific choice — not vague language. A decision is vague if:
- It defers without resolving: "we'll figure it out", "to be determined", "TBD", "decide later"
- It names a category but not a choice: "use a database" (which one?), "pick a library" (which one?)
- It has no actionable conclusion: "it depends", "either could work"

Specific decisions name the actual choice made: "use PostgreSQL", "implement as a REST API", "disable feature X in production".

**If any vague decision found:** Emit ISSUE finding `CTX-F10` (increment suffix for each vague decision) with location = the vague decision, description = "Vague decision — no concrete choice recorded", suggestion = "Replace vague language with the specific choice made, e.g., 'Use PostgreSQL 15' instead of 'use a database'."

### QC-4: No Contradictions Between Decisions

No two decisions in the same CONTEXT.md may contradict each other. A contradiction occurs when two decisions make mutually exclusive assertions about the same subject — e.g., "use REST API" and "use GraphQL" for the same endpoint, or "disable caching" and "enable Redis caching" for the same layer.

Scan all decisions pairwise for logical conflicts.

**If any contradiction found:** Emit ISSUE finding `CTX-F20` with location = both conflicting decisions, description = "Contradictory decisions — two decisions make mutually exclusive assertions", suggestion = "Remove or reconcile the conflicting decisions. Keep the one that reflects the actual final choice."

### QC-5: Deferred Ideas Clearly Separated from Active Decisions

If a `## Deferred Ideas` (or equivalent) section is present, no item from that section may also appear in `## Decisions` as an active decision. Deferred ideas are not decisions — they are explicitly parked for future consideration.

**If a deferred idea appears as an active decision:** Emit ISSUE finding `CTX-F30` with location = the duplicated item, suggestion = "Remove this item from `## Decisions` (it is already deferred) or move it out of Deferred Ideas and record the actual resolution."

### QC-6: Claude's Discretion Items Have Sufficient Context

Any item marked as "Claude's Discretion" MUST include enough context for Claude to make a reasonable, informed choice. A bare "Claude's Discretion" label without description or constraints fails this check.

**If any Claude's Discretion item lacks context:** Emit ISSUE finding `CTX-F40` with location = the item, suggestion = "Add context to guide Claude's choice, e.g., constraints, preferences, or the options being considered."

## Output Contract

Return structured findings using the schema from `reviewer-interface.md`. Finding IDs MUST use the prefix `CTX-F`.

```
status: "PASS" | "ISSUES_FOUND"
findings:
  - id: "CTX-F01"        # unique within this review
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
