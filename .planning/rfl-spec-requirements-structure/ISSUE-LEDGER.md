# ISSUE LEDGER — SPEC.md + REQUIREMENTS.md structure

Findings aggregated across rungs. Parent triages (wrong vs not wrong, not severity). ACCEPT fixes applied by launcher; REJECT reasons recorded.

## Rung 01 — GLM 5.2 High (Cursor) — CLEAN

| ID | Severity | Status | Summary |
|----|----------|--------|---------|
| R1-F01 | MED | APPLIED | Legacy lock algorithm (Wave 6 step 3) triggers on missing frontmatter alone; rollback mitigation requires both missing frontmatter AND missing `## User Stories`. Algorithm broader than its own rollback fix — contract hole. |
| R1-F02 | LOW | APPLIED | REQ-09 wave mapping lists 1,2,7 but compiler/clarify string asserts land in waves 3,4. Mapping understates coverage. |
| R1-F03 | LOW | APPLIED | AC-03 "or equivalent" If/Then is undefined; plan defers definition to RFL. Contract-soft; acceptable for a plan but should be pinned before Wave 2. |
| R1-F04 | NIT | APPLIED | Evidence table states SPEC.md.template = 1013 bytes; actual = 1017 bytes. |
| R1-F05 | NIT | APPLIED | AC-09 and NFR-03 both assert `test-spec-floor-check.sh` passes with only Overview+AC. Overlap, not contradiction. |

**Verdict:** CLEAN (no HIGH; 1 MED is a contract-tightening item, not a defect that blocks implementation). Recommendation: ACCEPT.

**Apply SHA-256:** `d281cb7ee6321201bdce5825dde26f48c082ab6c7e4ef7a59cfeff965dcd1feb`  
**Policy C:** [`rung-01-cursor-glm-5.2-high/POLICY-C.json`](rung-01-cursor-glm-5.2-high/POLICY-C.json) · [`POLICY-C.md`](rung-01-cursor-glm-5.2-high/POLICY-C.md)  
**Verify:** verify_1 PASS, verify_2 PASS (Grok 4.5 High native Cursor).

## Rung 02 — Kimi K3 High (Cursor) — CLEAN

| ID | Severity | Status | Summary |
|----|----------|--------|---------|
| R2-F01 | LOW | APPLIED | Wave 6 legacy-lock decision tree is non-total: `spec-version` present + no `## User Stories` + no `feature-slug` matches no branch (greenfield / augment×2 / lock). |
| R2-F02 | LOW | APPLIED | ISSUE-new / INFO-legacy severity split pinned for QC-9 only; QC-8 (SPEC-F70), QC-10 (SPEC-F72), and QC-6 `feature-slug` extension are silent, risking contradiction with the risk-table intent. |
| R2-F03 | LOW | APPLIED | Wave 2 comment offers `test-review-spec-qc-strings.sh` but the pinning paragraph and Wave 7 use `test-review-spec-req-xart-qc-strings.sh` — two names for one test file. |
| R2-F04 | NIT | APPLIED | Stray second H1 at line 38 (`# Do NOT execute freeze YAML…`) breaks single-H1 GFM structure; demote to blockquote admonition. |

**Verdict:** CLEAN (no HIGH/MED; 3 LOW + 1 NIT, all non-blocking mechanical plan edits). Rung-01 APPLY confirmed correctly applied (R1-F01–F05 present in freeze; not re-opened). Recommendation: ACCEPT.

**Apply SHA-256:** `2b2f7d7672534c8895ac821fe49d34b634833cc1eb16770d6f2f5d9d3f2d1ffe`  
**Policy C:** [`rung-02-cursor-kimi-k3-high/POLICY-C.json`](rung-02-cursor-kimi-k3-high/POLICY-C.json) · [`POLICY-C.md`](rung-02-cursor-kimi-k3-high/POLICY-C.md)  
**Verify:** verify_1 PASS, verify_2 PASS (Grok 4.5 High native Cursor).

## Rung 03 — Gemini 3.7 Flash High (Cursor) — CLEAN

| ID | Severity | Status | Summary |
|----|----------|--------|---------|
| — | — | none | Zero findings. HIGH / MED / LOW / NIT none. |

**Verdict:** CLEAN (no HIGH/MED/LOW/NIT). Prior rungs 01–02 APPLY confirmed still in freeze; none re-opened. Recommendation: ACCEPT (no-op APPLY).

**Apply SHA-256:** `2b2f7d7672534c8895ac821fe49d34b634833cc1eb16770d6f2f5d9d3f2d1ffe` (unchanged)  
**Policy C:** [`rung-03-cursor-gemini-3.7-flash-high/POLICY-C.json`](rung-03-cursor-gemini-3.7-flash-high/POLICY-C.json) · [`POLICY-C.md`](rung-03-cursor-gemini-3.7-flash-high/POLICY-C.md)  
**Verify:** verify_1 PASS, verify_2 PASS (Grok 4.5 High native Cursor).

## Rung 04 — Grok 4.6 High (Cursor) — NOT CLEAN

| ID | Severity | Status | Summary |
|----|----------|--------|---------|
| R4-F01 | MED | APPLIED | Wave 2 must retarget review-requirements QC-4 for Functional `AC` column = `AC-nn` IDs (not live “measurable Acceptance Criterion” cell / REQ-F30), so compiler Step 8a can get two clean passes. |
| R4-F02 | LOW | APPLIED | Wave 3 verify must also assert the dropped “Requirements” heading (not only “Users and goals”). |
| R4-F03 | NIT | APPLIED | Pin Invariants as `### Invariants` under Overview, not a second `##`. |

**Verdict:** NOT CLEAN (no HIGH; 1 MED Wave 2 contract hole + 1 LOW + 1 NIT). KEEP REJECT unchanged. Rungs 01–03 APPLY confirmed still in freeze; none re-opened. Recommendation: ACCEPT.

**Apply SHA-256:** `5d387487c1888fc260d50ffc57a4440459df9514fc0b9128c2c61e2ced0a61af`  
**Policy C:** [`rung-04-cursor-grok-4.6-high/POLICY-C.json`](rung-04-cursor-grok-4.6-high/POLICY-C.json) · [`POLICY-C.md`](rung-04-cursor-grok-4.6-high/POLICY-C.md)  
**Verify:** verify_1 PASS, verify_2 PASS (Grok 4.5 High native Cursor).
