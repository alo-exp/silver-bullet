# Policy C — Cursor GLM 5.2 High

- **Rung identity:** Cursor GLM 5.2 High (`glm` / `high`)
- **Verdict:** NOT CLEAN
- **Disposition:** ACCEPT-apply

## Blockers / Highs / Mediums

- **Blockers:** none
- **Highs:**
  - R1-F01
  - R1-F02
  - R1-F03
- **Mediums:**
  - R1-F04
  - R1-F05
  - R1-F06
  - R1-F07

## Reported issues (by severity)

### HIGH

| ID | Title |
|----|-------|
| R1-F01 | QC-1 heading count vs QC-10 Change History (7 vs 8) is ambiguous |
| R1-F02 | Wave 3 must update silver-spec Step 3 kind-blind heading list (incl. UX Flows) |
| R1-F03 | Clarify skip-turn map names Security/Telemetry/API/CLI/Mobile/Pipeline turns that do not exist |

### MED

| ID | Title |
|----|-------|
| R1-F04 | multi union vs forbid conflict is unresolved |
| R1-F05 | Decision-log trigger has no capture-schema decisions field |
| R1-F06 | security optional for headless-service / data-ml / library-sdk is contradictory |
| R1-F07 | No behavioral multi / kind-multi fixture |

### LOW

| ID | Title |
|----|-------|
| R1-F08 | ### Invariants is core-required but no QC enforces presence |
| R1-F09 | Pack-local ID scheme is inconsistent across packs |

### NIT

| ID | Title |
|----|-------|
| R1-F10 | software-kinds presence-iff-multi is not a stated QC |

## Triage (launcher, not rung model)

| ID | Severity | Decision | Reason |
|----|----------|----------|--------|
| R1-F01 | HIGH | ACCEPT | Pin QC-1 = 7 headings; Change History is 8th core-required heading enforced only by QC-10 |
| R1-F02 | HIGH | ACCEPT | Wave 3 must recompute silver-spec Step 3 required-sections from catalog; UX Flows not universal |
| R1-F03 | HIGH | ACCEPT | Option A: add kind-gated domain turns so all 13 packs are sourced; skip map names only existing turns |
| R1-F04 | MED | ACCEPT | multi tie-break: required-wins over forbidden + INFO unusual combination |
| R1-F05 | MED | ACCEPT | Wave 4 capture schema gains a decisions field; compiler counts that field |
| R1-F06 | MED | ACCEPT | security is required for headless-service, data-ml, and library-sdk |
| R1-F07 | MED | ACCEPT | Add kind-multi behavioral fixture and required-wins test case |
| R1-F08 | LOW | ACCEPT | QC-11 requires ### Invariants under Overview with >=1 MUST/MUST NOT |
| R1-F09 | LOW | ACCEPT | Mint DATA-nn SIG-nn SLO-nn CTRL-nn QA-nn so structured packs are ID-addressable |
| R1-F10 | NIT | ACCEPT | QC-6b: software-kinds present and non-empty iff software-kind is multi |

## Resolved (after launcher ACCEPT fixes)

| ID | Severity | Title | Decision | Resolved |
|----|----------|-------|----------|----------|
| R1-F01 | HIGH | QC-1 heading count vs QC-10 Change History (7 vs 8) is ambiguous | ACCEPT | yes |
| R1-F02 | HIGH | Wave 3 must update silver-spec Step 3 kind-blind heading list (incl. UX Flows) | ACCEPT | yes |
| R1-F03 | HIGH | Clarify skip-turn map names Security/Telemetry/API/CLI/Mobile/Pipeline turns that do not exist | ACCEPT | yes |
| R1-F04 | MED | multi union vs forbid conflict is unresolved | ACCEPT | yes |
| R1-F05 | MED | Decision-log trigger has no capture-schema decisions field | ACCEPT | yes |
| R1-F06 | MED | security optional for headless-service / data-ml / library-sdk is contradictory | ACCEPT | yes |
| R1-F07 | MED | No behavioral multi / kind-multi fixture | ACCEPT | yes |
| R1-F08 | LOW | ### Invariants is core-required but no QC enforces presence | ACCEPT | yes |
| R1-F09 | LOW | Pack-local ID scheme is inconsistent across packs | ACCEPT | yes |
| R1-F10 | NIT | software-kinds presence-iff-multi is not a stated QC | ACCEPT | yes |

