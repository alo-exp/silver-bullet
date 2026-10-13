# Policy C — Pi Codex GPT-5.6 Sol High (re-run pass 9)

- **Rung identity:** Pi Codex GPT-5.6 Sol High (re-run pass 9) (`gpt` / `high`)
- **Verdict:** NOT CLEAN
- **Disposition:** ACCEPT-apply

## Blockers / Highs / Mediums

- **Blockers:** none
- **Highs:** none
- **Mediums:**
  - R5i-F01

## Reported issues (by severity)

### HIGH

| ID | Title |
|----|-------|
| — | **none** |

### MED

| ID | Title |
|----|-------|
| R5i-F01 | REQ/NFR IDs remain reusable across augment versions despite the canonical tombstone mechanism |

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
| R5i-F01 | MED | ACCEPT | Named mechanism: tombstone list (id-tombstones) on REQUIREMENTS YAML for REQ-nn/NFR-nn. Persist retired IDs across augment. QC-2/QC-3 fail reissue. Step 8 sequential next-free skips tombstones. Fixtures: retired REQ-03 reissued; retired NFR-nn reissued; preserve-still-present; mint after retire skips the hole. SPEC id-tombstones/QC-12/QC-13/Step 7 unchanged. |

## Resolved (after launcher ACCEPT fixes)

| ID | Severity | Title | Decision | Resolved |
|----|----------|-------|----------|----------|
| R5i-F01 | MED | REQ/NFR IDs remain reusable across augment versions despite the canonical tombstone mechanism | ACCEPT | yes |
