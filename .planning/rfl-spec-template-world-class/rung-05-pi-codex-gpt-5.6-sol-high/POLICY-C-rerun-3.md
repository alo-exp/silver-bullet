# Policy C — Pi Codex GPT-5.6 Sol High (re-run pass 3)

- **Rung identity:** Pi Codex GPT-5.6 Sol High (re-run pass 3) (`gpt` / `high`)
- **Verdict:** NOT CLEAN
- **Disposition:** ACCEPT-apply

## Blockers / Highs / Mediums

- **Blockers:** none
- **Highs:**
  - R5c-F01
- **Mediums:**
  - R5c-F02
  - R5c-F03

## Reported issues (by severity)

### HIGH

| ID | Title |
|----|-------|
| R5c-F01 | The stable-ID contract has no global uniqueness/shape check, allowing duplicate AC IDs to collapse traceability |

### MED

| ID | Title |
|----|-------|
| R5c-F02 | QC-10 enforces only the Change History heading, not the required table or current-version row |
| R5c-F03 | Reverse NFR coverage can be bypassed through an undefined non-requirement disposition |

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
| R5c-F01 | HIGH | ACCEPT | Named ID-integrity QC (file-unique + shape) for US-nn / AC-nn / pack-local IDs; duplicate AC-01 must FAIL Coverage Matrix / AC→REQ. Fixtures: dup AC-01, malformed IDs, unlabeled US/OQ/OOS |
| R5c-F02 | MED | ACCEPT | QC-10 / SPEC-F72 must require Change History table, current spec-version row, and non-placeholder summary — not heading-only |
| R5c-F03 | MED | ACCEPT | Define reverse-NFR recorded non-requirement disposition as a concrete table/field/enum/parser rule so dropped QA-nn / SLO-nn / CTRL-nn cannot slip FAIL |

## Resolved (after launcher ACCEPT fixes)

| ID | Severity | Title | Decision | Resolved |
|----|----------|-------|----------|----------|
| R5c-F01 | HIGH | The stable-ID contract has no global uniqueness/shape check, allowing duplicate AC IDs to collapse traceability | ACCEPT | yes |
| R5c-F02 | MED | QC-10 enforces only the Change History heading, not the required table or current-version row | ACCEPT | yes |
| R5c-F03 | MED | Reverse NFR coverage can be bypassed through an undefined non-requirement disposition | ACCEPT | yes |

