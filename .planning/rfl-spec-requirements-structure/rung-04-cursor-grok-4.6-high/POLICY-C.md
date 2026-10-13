# Policy C — Cursor Grok 4.6 High

- **Rung identity:** Cursor Grok 4.6 High (`grok` / `high`)
- **Verdict:** NOT CLEAN
- **Disposition:** ACCEPT-apply

## Blockers / Highs / Mediums

- **Blockers:** none
- **Highs:** none
- **Mediums:**
  - R4-F01

## Reported issues (by severity)

### HIGH

| ID | Title |
|----|-------|
| — | **none** |

### MED

| ID | Title |
|----|-------|
| R4-F01 | Wave 2 does not retarget review-requirements QC-4 for the new Functional AC column |

### LOW

| ID | Title |
|----|-------|
| R4-F02 | Wave 3 verify omits the Requirements negative assert the work item itself requires |

### NIT

| ID | Title |
|----|-------|
| R4-F03 | ## Invariants is not a subsection of Overview |

## Triage (launcher, not rung model)

| ID | Severity | Decision | Reason |
|----|----------|----------|--------|
| R4-F01 | MED | ACCEPT | Wave 2 must retarget QC-4 so Functional AC column is AC-nn IDs; compiler Step 8a needs two clean review-requirements passes |
| R4-F02 | LOW | ACCEPT | Wave 3 verify must also assert the dropped Requirements heading, not only Users and goals |
| R4-F03 | NIT | ACCEPT | Pin Invariants as ### Invariants under Overview, not a second ## |

## Resolved (after launcher ACCEPT fixes)

| ID | Severity | Title | Decision | Resolved |
|----|----------|-------|----------|----------|
| R4-F01 | MED | Wave 2 does not retarget review-requirements QC-4 for the new Functional AC column | ACCEPT | yes |
| R4-F02 | LOW | Wave 3 verify omits the Requirements negative assert the work item itself requires | ACCEPT | yes |
| R4-F03 | NIT | ## Invariants is not a subsection of Overview | ACCEPT | yes |

