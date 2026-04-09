# Reviewer Interface Contract

Every SB artifact reviewer MUST implement this interface. Reviewers that deviate from this contract are non-conformant and will not integrate with the review loop.

---

## Input Contract

The orchestrator passes these inputs to each reviewer invocation:

```
artifact_path: string     — absolute or relative path to the artifact file (REQUIRED)
source_inputs: string[]   — optional paths to source artifacts (e.g., SPEC.md for DESIGN.md review)
review_context: string    — optional additional context (e.g., "Phase 16 spec creation")
```

---

## Output Contract

Reviewers MUST return structured findings — never free-form prose as the primary output.

```
status: "PASS" | "ISSUES_FOUND"
findings: Finding[]
```

### Finding Structure

```
Finding:
  id: string          — unique finding ID within this review (e.g., "SPEC-F01", "PLAN-F03")
  severity: "ISSUE" | "INFO"
  description: string — what is wrong or noteworthy
  location: string    — section header or line reference within the artifact
  suggestion: string  — specific, actionable fix
```

### Status Rules

- `PASS` — zero ISSUE-severity findings; INFO findings are allowed alongside PASS
- `ISSUES_FOUND` — one or more ISSUE-severity findings; INFO findings may also be present

---

## Reviewer Responsibilities

- Read the artifact at `artifact_path` completely before forming findings
- If `source_inputs` are provided, cross-reference them for consistency with the artifact
- Validate against the artifact type's quality criteria (each reviewer defines its own criteria)
- Return structured findings — the review loop depends on machine-readable output
- A "PASS" result asserts that the artifact meets all required quality criteria

---

## Reviewer Prohibitions

- Do NOT modify the artifact — reviewers are strictly read-only
- Do NOT skip sections because they "look fine" — validate every required section explicitly
- Do NOT return PASS when any required section is missing or empty
- Do NOT conflate INFO and ISSUE — only ISSUE findings block progression
- Do NOT return unstructured text as the primary output; wrap findings in the schema above
