# Policy C — Cursor GLM 5.2 High

- **Rung identity:** Cursor GLM 5.2 High (`glm` / `high`)
- **Verdict:** CLEAN
- **Disposition:** ACCEPT-apply

## Blockers / Highs / Mediums

- **Blockers:** none
- **Highs:** none
- **Mediums:**
  - R1-F01

## Reported issues (by severity)

### HIGH

| ID | Title |
|----|-------|
| — | **none** |

### MED

| ID | Title |
|----|-------|
| R1-F01 | Legacy lock algorithm is broader than its own rollback mitigation |

### LOW

| ID | Title |
|----|-------|
| R1-F02 | REQ-09 wave mapping understates coverage |
| R1-F03 | AC-03 If/Then equivalent is undefined (contract-soft) |

### NIT

| ID | Title |
|----|-------|
| R1-F04 | SPEC template byte count typo (1013 vs 1017) |
| R1-F05 | AC-09 / NFR-03 overlap on spec-floor test |

## Triage (launcher, not rung model)

| ID | Severity | Decision | Reason |
|----|----------|----------|--------|
| R1-F01 | MED | ACCEPT | Wave 6 lock must require missing spec-version and missing User Stories and missing feature-slug; stories-without-frontmatter is augment |
| R1-F02 | LOW | ACCEPT | AC-09 / REQ-09 mapping must include compiler/clarify string-assert waves 3 and 4 |
| R1-F03 | LOW | ACCEPT | Pin If/Then to non-interactive AC; interactive require GWT; ISSUE on new compiles, INFO on legacy pre-ID augment |
| R1-F04 | NIT | ACCEPT | Evidence/CONTEXT must cite SPEC template 52 lines / 1017 bytes, not 53 / 1013 |
| R1-F05 | NIT | ACCEPT | Spec-floor harness is NFR-03 only; AC-09 / REQ-09 own template/compiler/QC/ID-parse tests |

## Resolved (after launcher ACCEPT fixes)

| ID | Severity | Title | Decision | Resolved |
|----|----------|-------|----------|----------|
| R1-F01 | MED | Legacy lock algorithm is broader than its own rollback mitigation | ACCEPT | yes |
| R1-F02 | LOW | REQ-09 wave mapping understates coverage | ACCEPT | yes |
| R1-F03 | LOW | AC-03 If/Then equivalent is undefined (contract-soft) | ACCEPT | yes |
| R1-F04 | NIT | SPEC template byte count typo (1013 vs 1017) | ACCEPT | yes |
| R1-F05 | NIT | AC-09 / NFR-03 overlap on spec-floor test | ACCEPT | yes |

