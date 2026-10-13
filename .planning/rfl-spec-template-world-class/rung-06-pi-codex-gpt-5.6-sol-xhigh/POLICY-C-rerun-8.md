# Policy C — Pi Codex GPT-5.6 Sol Extra High (re-run pass 8)

- **Rung identity:** Pi Codex GPT-5.6 Sol Extra High (re-run pass 8) (`gpt` / `xhigh`)
- **Verdict:** NOT CLEAN
- **Disposition:** ACCEPT-apply

## Blockers / Highs / Mediums

- **Blockers:** none
- **Highs:** none
- **Mediums:**
  - R6h-F01

## Reported issues (by severity)

### HIGH

| ID | Title |
|----|-------|
| — | **none** |

### MED

| ID | Title |
|----|-------|
| R6h-F01 | Wave 1 REQUIREMENTS template and Wave 2 `review-requirements` QC-4 |

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
| R6h-F01 | MED | ACCEPT | Wave 1: Functional REQUIREMENTS table must have an `AC` column whose cells are exact `AC-nn` (e.g. `AC-01`), not only the header string `AC`. Wave 1: forbid a live `Acceptance Criterion` column (or equivalent old heading) on Functional rows. Wave 2 QC-4: fixture/assertion that `REQ-F30` does not fire on a valid `AC-nn` join key; a valid `AC-01` cell must pass that check. Do not weaken R5h/R5i tombstones, Wave 6 1b, R5k exclusive NFR, R6b/R6c/R6d pair-install/fixed-point, R6f exhaustion FAIL closed. |

## Resolved (after launcher ACCEPT fixes)

| ID | Severity | Title | Decision | Resolved |
|----|----------|-------|----------|----------|
| R6h-F01 | MED | Wave 1 REQUIREMENTS template and Wave 2 `review-requirements` QC-4 | ACCEPT | yes |
