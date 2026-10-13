# Policy C — Cursor GLM 5.2 High (re-run pass 1)

- **Rung identity:** Cursor GLM 5.2 High (re-run pass 1) (`glm` / `high`)
- **Verdict:** NOT CLEAN
- **Disposition:** ACCEPT-apply

## Blockers / Highs / Mediums

- **Blockers:** none
- **Highs:** none
- **Mediums:**
  - R1b-F01
  - R1b-F02

## Reported issues (by severity)

### HIGH

| ID | Title |
|----|-------|
| — | **none** |

### MED

| ID | Title |
|----|-------|
| R1b-F01 | QC-7 SPEC-F61 exemption is a six-kind enum; multi with ux forbidden still deadlocks vs catalog QC-1 / figma-url |
| R1b-F02 | Wave 4 capture schema does not name brief fields for kind-gated packs the compiler concatenates from non-empty brief fields |

### LOW

| ID | Title |
|----|-------|
| R1b-F03 | Blast radius still lists Clarify optional quality prompt after R2-F01 made nfr a real turn |

### NIT

| ID | Title |
|----|-------|
| — | **none** |

## Triage (launcher, not rung model)

| ID | Severity | Decision | Reason |
|----|----------|----------|--------|
| R1b-F01 | MED | ACCEPT | QC-7 SPEC-F61 exemption must tie to catalog ux-forbidden (including software-kind multi), not a closed list of six atomic kinds; figma-url must not deadlock vs kind-aware QC-1 |
| R1b-F02 | MED | ACCEPT | Wave 4 capture schema must name brief fields for kind-pack turns (ux, errors, data, nfr, security, telemetry, api, cli, mobile, pipeline, ops, examples) plus decisions so concat can see non-empty fields |
| R1b-F03 | LOW | ACCEPT | Blast-radius Clarify row must call nfr a real/mandatory turn per R2-F01, not an optional quality prompt |

## Resolved (after launcher ACCEPT fixes)

| ID | Severity | Title | Decision | Resolved |
|----|----------|-------|----------|----------|
| R1b-F01 | MED | QC-7 SPEC-F61 exemption is a six-kind enum; multi with ux forbidden still deadlocks vs catalog QC-1 / figma-url | ACCEPT | yes |
| R1b-F02 | MED | Wave 4 capture schema does not name brief fields for kind-gated packs the compiler concatenates from non-empty brief fields | ACCEPT | yes |
| R1b-F03 | LOW | Blast radius still lists Clarify optional quality prompt after R2-F01 made nfr a real turn | ACCEPT | yes |

