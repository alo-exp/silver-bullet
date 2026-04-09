# Reviewer Interface Contract

Every SB artifact reviewer MUST implement this interface. Reviewers that deviate from this contract are non-conformant and will not integrate with the review loop.

---

## Input Contract

The orchestrator passes these inputs to each reviewer invocation:

```
artifact_path: string     — absolute or relative path to the artifact file (REQUIRED)
source_inputs: string[]   — optional paths to source artifacts (e.g., SPEC.md for DESIGN.md review)
review_context: string    — optional additional context (e.g., "Phase 16 spec creation")
check_mode: "full" | "structural"  — review depth mode (REQUIRED, defaults to "full" if not provided)
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

## Check Mode Behavior

The `check_mode` parameter controls which quality criteria a reviewer evaluates.

### full (default)

Run ALL quality criteria defined by the reviewer. This is the standard behavior — every QC check fires.

### structural

Run ONLY structural quality criteria. Structural checks validate:
- Required sections exist (correct headings present)
- Document format is valid (frontmatter parseable, markdown well-formed)
- Required fields are non-empty (not blank placeholders)

Structural checks do NOT validate:
- Content quality (e.g., "overview contains a real problem statement" — QC-2 in review-spec)
- Cross-reference consistency (e.g., "AC IDs match spec" — unless it is a format check)
- Semantic correctness (e.g., "user stories have all three parts")
- Depth of coverage (e.g., "at least N items present")

### Reviewer Implementation Rule

Each reviewer skill MUST tag its QC checks as either `structural` or `content`:
- `structural`: Section presence, format validity, non-empty required fields
- `content`: Quality, consistency, semantics, coverage depth

When `check_mode == "structural"`, the reviewer MUST skip all `content`-tagged QC checks and only evaluate `structural`-tagged checks. A PASS in structural mode means "the artifact has correct structure" — it does NOT assert content quality.

---

## Reviewer Responsibilities

- Read the artifact at `artifact_path` completely before forming findings
- If `source_inputs` are provided, cross-reference them for consistency with the artifact
- Validate against the artifact type's quality criteria (each reviewer defines its own criteria)
- Return structured findings — the review loop depends on machine-readable output
- A "PASS" result asserts that the artifact meets all required quality criteria
- Respect the `check_mode` parameter — when `structural`, skip content quality checks and only validate structure and format

---

## Reviewer Prohibitions

- Do NOT modify the artifact — reviewers are strictly read-only
- Do NOT skip sections because they "look fine" — validate every required section explicitly
- Do NOT return PASS when any required section is missing or empty
- Do NOT conflate INFO and ISSUE — only ISSUE findings block progression
- Do NOT return unstructured text as the primary output; wrap findings in the schema above

---

## Fix Application Contract

Reviewers are **read-only** — they produce findings but NEVER apply fixes. Fix application is the responsibility of the **orchestrator** (the workflow step that invoked the review loop).

### `orchestrator_apply_fix(artifact_path, finding)`

The orchestrator applies fixes using this contract:

1. Read `finding.suggestion` — the reviewer's specific, actionable fix recommendation
2. If `finding.suggestion` is non-empty: apply the suggested change to `artifact_path` using Edit/Write tools, then commit atomically
3. If `finding.suggestion` is empty or unclear: surface the finding to the user for manual resolution — do NOT guess
4. After ALL findings in a round are fixed, the review loop re-invokes the reviewer for the next round

### `commit_review_trail(artifact_path)`

After the review loop achieves 2 consecutive clean passes:

1. Commit `REVIEW-ROUNDS.md` alongside the reviewed artifact
2. The commit message follows: `docs: review rounds complete for {artifact_filename}`

**Why the orchestrator owns fixes:** The producing step (silver-spec, gsd-planner, etc.) has the domain context to apply changes correctly. The reviewer only has validation context. Separating read (reviewer) from write (orchestrator) prevents reviewers from making changes they cannot validate.
