# Policy C — Pi Codex GPT-5.6 Sol High (re-run pass 1)

- **Rung identity:** Pi Codex GPT-5.6 Sol High (re-run pass 1) (`gpt` / `high`)
- **Verdict:** NOT CLEAN
- **Disposition:** ACCEPT-apply

## Blockers / Highs / Mediums

- **Blockers:** none
- **Highs:**
  - R5-F01
- **Mediums:**
  - R5-F02
  - R5-F03

## Reported issues (by severity)

### HIGH

| ID | Title |
|----|-------|
| R5-F01 | Augment preservation can keep forbidden pack headings so compiler emits SPEC that must fail SPEC-F08 |

### MED

| ID | Title |
|----|-------|
| R5-F02 | Frontmatter lists more required keys than QC-6 / compiler Step 7 / Wave 1 tests enforce |
| R5-F03 | REQUIREMENTS NFR rows have no source-ID join to pack-local QA-nn / SLO-nn / CTRL-nn |

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
| R5-F01 | HIGH | ACCEPT | Wave 3 Step 7 and Wave 6 augment preserve-body can keep forbidden pack headings after minting software-kind (e.g. ## UX Flows after cli); compiler must not emit a SPEC that must fail SPEC-F08 |
| R5-F02 | MED | ACCEPT | Align frontmatter QC-required set with QC-6 / Step 7 / Wave 1: only feature-slug + software-kind (plus software-kinds iff multi); do not QC-6-require clarify-brief or derived-requirements |
| R5-F03 | MED | ACCEPT | REQUIREMENTS NFR rows need a Source column joining QA-nn / SLO-nn / CTRL-nn (or SCAN:); Functional AC join stays as already scoped |

## Resolved (after launcher ACCEPT fixes)

| ID | Severity | Title | Decision | Resolved |
|----|----------|-------|----------|----------|
| R5-F01 | HIGH | Augment preservation can keep forbidden pack headings so compiler emits SPEC that must fail SPEC-F08 | ACCEPT | yes |
| R5-F02 | MED | Frontmatter lists more required keys than QC-6 / compiler Step 7 / Wave 1 tests enforce | ACCEPT | yes |
| R5-F03 | MED | REQUIREMENTS NFR rows have no source-ID join to pack-local QA-nn / SLO-nn / CTRL-nn | ACCEPT | yes |

