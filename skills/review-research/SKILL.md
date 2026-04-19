---
name: review-research
description: "RESEARCH.md artifact reviewer — validates that all findings cite evidence, confidence levels are justified, pitfalls are actionable, and recommendations are concrete and implementable"
argument-hint: "<research-path>"
user-invocable: false
version: 0.1.0
---

# review-research

RESEARCH.md reviewer skill. Implements the artifact-reviewer framework interface to validate a RESEARCH.md file against SB research quality criteria. Returns structured PASS/ISSUES_FOUND findings.

## Loading Rules

This reviewer MUST load the following before executing any review:

- `@skills/artifact-reviewer/rules/reviewer-interface.md` — interface contract (input/output shape, prohibitions)
- `@skills/artifact-reviewer/rules/review-loop.md` — 2-pass loop mechanism and audit trail format

## Usage

```
/artifact-reviewer <research-path>
```

Or invoke directly:
```
/review-research <research-path>
```

## Input

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| artifact_path | string | YES | Path to RESEARCH.md file to review |
| source_inputs | string[] | NO | Optional paths (e.g., phase CONTEXT.md for key questions) |
| review_context | string | NO | Additional context string (e.g., phase name for key question matching) |

## Quality Criteria

Read the artifact at `artifact_path` completely before evaluating any criterion. Validate every criterion explicitly — do NOT skip sections.

### QC-1: Key Questions Are Addressed (when review_context available)

If `review_context` or `source_inputs` includes a phase CONTEXT.md with a list of key research questions, every listed key question MUST have a corresponding finding or section in the RESEARCH.md that addresses it.

**If any key question is unanswered:** Emit ISSUE finding `RES-F01` (increment suffix per missing question) with location = the unanswered question from CONTEXT.md, suggestion = "Add a finding or section addressing this key question: '[question text]'."

### QC-2: Findings Are Evidence-Based — No Speculative Findings

Every finding stated in the RESEARCH.md MUST cite at least one piece of evidence. Acceptable evidence includes:
- A documentation URL (e.g., `https://docs.example.com/...`)
- A library version number with a source reference (e.g., "v4.2.1, see npm registry")
- Benchmark data with a named test or source
- A named RFC, standard, or specification

A finding is speculative if it makes a factual claim without citing any source. Phrases like "I believe", "it seems", "generally", "typically" without evidence are speculative.

**If any speculative finding found:** Emit ISSUE finding `RES-F10` (increment suffix per speculative finding) with severity ISSUE, location = the finding, description = "Speculative finding — no evidence cited", suggestion = "Add a citation: documentation URL, library version with source, benchmark data, or named standard that supports this claim."

### QC-3: Confidence Levels Are Justified

If the RESEARCH.md uses confidence levels (high/medium/low, or percentage estimates), each confidence assertion MUST include reasoning explaining WHY that confidence level was assigned — not just the label.

Unjustified confidence examples (fail): "Confidence: High", "Confidence: Medium — this is uncertain."
Justified confidence examples (pass): "Confidence: High — official documentation explicitly states X, tested against v4.1.2", "Confidence: Low — only one source found, dated 2021, may be outdated."

**If any unjustified confidence level found:** Emit ISSUE finding `RES-F20` with location = the confidence assertion, suggestion = "Add reasoning explaining the confidence level: what evidence supports it and what gaps or risks reduce it."

### QC-4: Pitfalls and Warnings Are Actionable

If the RESEARCH.md contains pitfalls, "don't hand-roll" warnings, or anti-patterns, each MUST:
1. Name the specific risk (what goes wrong and why)
2. Name the alternative or mitigation (what to do instead)

A pitfall that only says "avoid X" without explaining the risk or naming an alternative is not actionable.

**If any non-actionable pitfall found:** Emit ISSUE finding `RES-F30` with location = the pitfall entry, suggestion = "Expand this pitfall to name the specific failure mode and the recommended alternative, e.g., 'Do not hand-roll JWT validation — use [library name] because [specific risk]'."

### QC-5: Recommendations Section Exists with Concrete Choices

The RESEARCH.md MUST contain a `## Recommendations` (or equivalent concluding section) with at least one recommendation. Each recommendation MUST be:
- **Concrete**: names a specific library, approach, version, or pattern — not a category
- **Implementable**: actionable enough that an engineer can act on it without further research

**If Recommendations section is missing or empty:** Emit ISSUE finding `RES-F40` with suggestion = "Add a `## Recommendations` section with at least one concrete, implementable recommendation derived from the research findings."

**If any recommendation is too vague:** Emit ISSUE finding `RES-F41` with location = the vague recommendation, suggestion = "Make this recommendation concrete: name the specific library, version, or approach to use."

### QC-6: No Stale References (INFO-level)

If the RESEARCH.md references version numbers, these SHOULD be current (within a reasonable timeframe). Version numbers that appear to be more than 2 major versions behind the current ecosystem norm, or that reference deprecated packages, are flagged at INFO level.

**If potentially outdated version found:** Emit INFO finding `RES-F50` with location = the version reference, description = "Potentially outdated version reference — verify this is still current", suggestion = "Check whether [library/tool] has released a newer stable version since this research was written and update if necessary."

## Output Contract

Return structured findings using the schema from `reviewer-interface.md`. Finding IDs MUST use the prefix `RES-F`.

```
status: "PASS" | "ISSUES_FOUND"
findings:
  - id: "RES-F10"        # unique within this review
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
