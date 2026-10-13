# Policy C — Pi Codex GPT-5.6 Sol Extra High (re-run pass 10)

- **Rung identity:** Pi Codex GPT-5.6 Sol Extra High (re-run pass 10) (`gpt` / `xhigh`)
- **Verdict:** NOT CLEAN
- **Disposition:** ACCEPT-apply

## Blockers / Highs / Mediums

- **Blockers:** none
- **Highs:** none
- **Mediums:**
  - R6j-F01
  - R6j-F02

## Reported issues (by severity)

### HIGH

| ID | Title |
|----|-------|
| — | **none** |

### MED

| ID | Title |
|----|-------|
| R6j-F01 | Functional AC-cell cardinality is not carried into the compiler and cross-artifact consumer contract |
| R6j-F02 | `nfr-source-cell-list` is not bound to Step 8 or `review-cross-artifact` despite both performing reverse/exclusive coverage |

### LOW

| ID | Title |
|----|-------|
| — | **none** |

### NIT

| ID | Title |
|----|-------|
| — | **none** |

## Triage (launcher, not rung model)

| ID | Severity | Decision | Reason |
|----|----------|----------|--------|
| R6j-F01 | MED | ACCEPT | Bind R6i one-`AC-nn`-per-cell to Wave 3 Step 8, `review-cross-artifact`, and compiler/migration tests. `AC-01, AC-02` must FAIL at mint/serialize/XART, not only Wave 1 template tests. |
| R6j-F02 | MED | ACCEPT | Bind named `nfr-source-cell-list` (`, `) to Step 8 and `review-cross-artifact` reverse-coverage / exclusivity / overlap. `QA-01,SLO-01` (no space) must FAIL the same parser as Wave 1. Do not weaken R5k exclusivity. |

## Resolved (after launcher ACCEPT fixes)

| ID | Severity | Title | Decision | Resolved |
|----|----------|-------|----------|----------|
| R6j-F01 | MED | Functional AC-cell cardinality is not carried into the compiler and cross-artifact consumer contract | ACCEPT | yes |
| R6j-F02 | MED | `nfr-source-cell-list` is not bound to Step 8 or `review-cross-artifact` despite both performing reverse/exclusive coverage | ACCEPT | yes |
