# Policy C — Cursor Gemini 3.7 Flash High

- **Rung identity:** Cursor Gemini 3.7 Flash High (`gemini` / `high`)
- **Verdict:** NOT CLEAN
- **Disposition:** ACCEPT-apply

## Blockers / Highs / Mediums

- **Blockers:** none
- **Highs:**
  - R3-F01
- **Mediums:**
  - R3-F02
  - R3-F03

## Reported issues (by severity)

### HIGH

| ID | Title |
|----|-------|
| R3-F01 | review-spec QC-7 is kind-blind and fails UX-forbidden kinds when figma-url is present |

### MED

| ID | Title |
|----|-------|
| R3-F02 | review-cross-artifact QC-1 Step 4 orphans all NFR-nn (XART-F02) |
| R3-F03 | silver-spec Step 1 domain mapping is kind-blind; Wave 3 omits Step 1 |

### LOW

| ID | Title |
|----|-------|
| R3-F04 | Wave 2 verify rg omits QC-9 / QC-10 / SPEC-F71 / SPEC-F72 / REQ-F70 |
| R3-F05 | kind-aware QC-1 present forbidden heading has no explicit SPEC-F* code |

### NIT

| ID | Title |
|----|-------|
| — | **none** |

## Triage (launcher, not rung model)

| ID | Severity | Decision | Reason |
|----|----------|----------|--------|
| R3-F01 | HIGH | ACCEPT | Wave 2 QC-7 must be kind-aware: do not require UX Flows / SPEC-F61 when ux is forbidden, even if figma-url is present; figma-url stays core |
| R3-F02 | MED | ACCEPT | XART-F02 Step 4 scopes to Functional REQ-nn lacking AC join; NFR-nn are exempt because NFR has no AC column and Coverage Matrix is AC↔REQ |
| R3-F03 | MED | ACCEPT | Wave 3 must name silver-spec Step 1 and map brief domains to kind pack headings, not blindly to UX Flows / AC / OQ |
| R3-F04 | LOW | ACCEPT | Wave 2 rg snippet must include QC-9, QC-10, SPEC-F71, SPEC-F72, REQ-F70 to match assert prose |
| R3-F05 | LOW | ACCEPT | Present forbidden heading emits SPEC-F08, not a bare ISSUE |

## Resolved (after launcher ACCEPT fixes)

| ID | Severity | Title | Decision | Resolved |
|----|----------|-------|----------|----------|
| R3-F01 | HIGH | review-spec QC-7 is kind-blind and fails UX-forbidden kinds when figma-url is present | ACCEPT | yes |
| R3-F02 | MED | review-cross-artifact QC-1 Step 4 orphans all NFR-nn (XART-F02) | ACCEPT | yes |
| R3-F03 | MED | silver-spec Step 1 domain mapping is kind-blind; Wave 3 omits Step 1 | ACCEPT | yes |
| R3-F04 | LOW | Wave 2 verify rg omits QC-9 / QC-10 / SPEC-F71 / SPEC-F72 / REQ-F70 | ACCEPT | yes |
| R3-F05 | LOW | kind-aware QC-1 present forbidden heading has no explicit SPEC-F* code | ACCEPT | yes |

