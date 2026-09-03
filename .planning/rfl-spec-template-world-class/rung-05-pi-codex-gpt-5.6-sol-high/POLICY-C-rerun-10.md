# Policy C — Pi Codex GPT-5.6 Sol High (re-run pass 10)

- **Rung identity:** Pi Codex GPT-5.6 Sol High (re-run pass 10) (`gpt` / `high`)
- **Verdict:** NOT CLEAN
- **Disposition:** ACCEPT-apply

## Blockers / Highs / Mediums

- **Blockers:** none
- **Highs:** none
- **Mediums:**
  - R5j-F01

## Reported issues (by severity)

### HIGH

| ID | Title |
|----|-------|
| — | **none** |

### MED

| ID | Title |
|----|-------|
| R5j-F01 | SPEC-only greenfield detection can overwrite an existing REQUIREMENTS tombstone ledger |

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
| R5j-F01 | MED | ACCEPT | True greenfield = both SPEC.md and REQUIREMENTS.md absent. Named behavior preserve-or-fail-closed. Partial-pair (SPEC absent, REQUIREMENTS present) unions prior REQUIREMENTS id-tombstones or fails before write. Step 8 / Wave 6 union prior tombstones on every replace. Fixture: no SPEC + id-tombstones [REQ-03, NFR-02] must not become [] / must not later reissue REQ-03. R5h SPEC tombstones/QC-12/QC-13/Step 7 and R5i REQUIREMENTS tombstones/QC-2/QC-3 unchanged. |

## Resolved (after launcher ACCEPT fixes)

| ID | Severity | Title | Decision | Resolved |
|----|----------|-------|----------|----------|
| R5j-F01 | MED | SPEC-only greenfield detection can overwrite an existing REQUIREMENTS tombstone ledger | ACCEPT | yes |
