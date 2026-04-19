---
name: artifact-review-assessor
description: "Triages artifact reviewer findings into MUST-FIX / NICE-TO-HAVE / DISMISS based on artifact contract -- prevents over-zealous reviews"
argument-hint: "<review-findings> <artifact-path> [--contract-source <path>]"
user-invocable: false
version: 0.1.0
---

# artifact-review-assessor

Reality-check artifact reviewer findings before fixing. Prevents over-zealous reviews from causing unnecessary work.

The assessor triages each reviewer finding against the artifact's contract — only MUST-FIX items block the 2-pass gate. NICE-TO-HAVE items are logged but do not block. DISMISS items are discarded with a reason.

## Usage

Invoke after `artifact-reviewer` produces findings. Fix only MUST-FIX items, then re-invoke the reviewer.

```
artifact-reviewer <artifact-path>
  -> artifact-review-assessor <review-findings> <artifact-path>
  -> fix MUST-FIX items only
  -> artifact-reviewer <artifact-path>        (NOT assessor again)
  -> repeat until 2 consecutive clean passes
```

## No Self-Review Rule

No review loop on the assessor itself. Assessor triages ONCE per reviewer invocation. The cycle is: Reviewer -> Assessor -> fix MUST-FIX -> Reviewer again (NOT Assessor again).

The assessor is not an artifact — it produces a classified list, not a document that requires its own review round.

## Input / Output

**Input:**
- Reviewer findings (markdown — the output of an artifact-reviewer invocation)
- Artifact being reviewed (path)
- Artifact contract source (path or inline — see Contract Sources table below)

**Output:**
- Classified findings list with 3 categories: MUST-FIX, NICE-TO-HAVE, DISMISS
- NICE-TO-HAVE items appended to WORKFLOW.md "Deferred Improvements" section (if WORKFLOW.md exists)

## Classification Criteria

| Classification | Criterion |
|---|---|
| MUST-FIX | Contract violation: required section missing, factual inconsistency, untraceable criterion, security/correctness issue |
| NICE-TO-HAVE | Genuine improvement: clarity, detail, structure -- logged in WORKFLOW.md "Deferred Improvements" but does not block 2-pass gate |
| DISMISS | Extraneous: stylistic preference, "could be more detailed" without specific gap, contradicts locked CONTEXT.md decision, duplicate |

## Contract Sources

| Artifact | Contract defined by |
|---|---|
| SPEC.md | silver-spec SKILL.md step 7 template |
| REQUIREMENTS.md | REQ-XX format rules in silver-spec SKILL.md step 8 |
| CONTEXT.md | Locked decisions format in gsd-discuss-phase workflow |
| PLAN.md | Wave structure + task format in gsd-plan-phase workflow |
| RESEARCH.md | Evidence + confidence format in gsd-phase-researcher agent |
| DESIGN.md | SB design template in silver-spec SKILL.md step 9 |
| UI-SPEC.md | Design contract format in gsd-ui-phase workflow |
| REVIEW.md | Code quality finding format in gsd-code-reviewer agent |
| UAT.md | Criterion + Result + Evidence format in gsd-verify-work workflow |
| INGESTION_MANIFEST.md | Source artifact listing in silver-ingest SKILL.md step 7 |
| SECURITY.md | Threat model format in gsd-secure-phase workflow |

## Triage Steps

1. Load the artifact contract from the Contract Sources table above
2. For each reviewer finding, compare against the contract
3. Classify:
   - Does it violate a contract requirement? → MUST-FIX
   - Is it a genuine improvement not in contract? → NICE-TO-HAVE
   - Is it stylistic, subjective, or duplicate? → DISMISS
4. Output classified list (see Output Format below)
5. NICE-TO-HAVE items get logged to WORKFLOW.md "Deferred Improvements" section (if WORKFLOW.md exists)

## Output Format

```markdown
## Assessor Triage — <artifact-path>

### MUST-FIX (N)

- [ ] **Finding:** <reviewer finding text>
      **Contract:** <specific contract rule violated>
      **Source:** <contract source skill/workflow>

### NICE-TO-HAVE (N)

- **Finding:** <reviewer finding text>
  **Improvement:** <what it would improve>
  **Deferred-to:** WORKFLOW.md "Deferred Improvements"

### DISMISS (N)

- **Finding:** <reviewer finding text>
  **Reason:** <why dismissed — stylistic / contradicts locked decision / duplicate / no specific gap>
```
