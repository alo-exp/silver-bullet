# Policy C — Pi Codex GPT-5.6 Sol High (re-run pass 2)

- **Rung identity:** Pi Codex GPT-5.6 Sol High (re-run pass 2) (`gpt` / `high`)
- **Verdict:** NOT CLEAN
- **Disposition:** ACCEPT-apply

## Blockers / Highs / Mediums

- **Blockers:** none
- **Highs:**
  - R5b-F01
- **Mediums:**
  - R5b-F02
  - R5b-F03

## Reported issues (by severity)

### HIGH

| ID | Title |
|----|-------|
| R5b-F01 | Kind-aware QC-1 checks required pack headings, but not required pack bodies or pack-local IDs |

### MED

| ID | Title |
|----|-------|
| R5b-F02 | software-kinds QC accepts lists that violate the catalog Two+ distinct atomic kinds contract |
| R5b-F03 | NFR Source join validates NFR→SPEC provenance but not SPEC→NFR reverse coverage |

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
| R5b-F01 | HIGH | ACCEPT | Kind-aware QC-1 must require pack bodies and pack-local IDs for required packs; _TBD — Clarify skipped illegally_ must not satisfy a required pack; required packs need EP-nn / CTRL-nn / SLO-nn as the catalog requires, not an empty stub |
| R5b-F02 | MED | ACCEPT | QC-6b software-kinds must be two+ distinct atomic catalog kinds, not [cli], not [multi, web-ui], not [cli, cli], not unknown members |
| R5b-F03 | MED | ACCEPT | Dropped QA-nn / SLO-nn / CTRL-nn in SPEC must be visible even if remaining NFR rows have valid Source; keep NFR Source and add reverse coverage |

## Resolved (after launcher ACCEPT fixes)

| ID | Severity | Title | Decision | Resolved |
|----|----------|-------|----------|----------|
| R5b-F01 | HIGH | Kind-aware QC-1 checks required pack headings, but not required pack bodies or pack-local IDs | ACCEPT | yes |
| R5b-F02 | MED | software-kinds QC accepts lists that violate the catalog Two+ distinct atomic kinds contract | ACCEPT | yes |
| R5b-F03 | MED | NFR Source join validates NFR→SPEC provenance but not SPEC→NFR reverse coverage | ACCEPT | yes |

