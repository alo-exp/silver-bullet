# Policy C — Pi Codex GPT-5.6 Sol High (re-run pass 8)

- **Rung identity:** Pi Codex GPT-5.6 Sol High (re-run pass 8) (`gpt` / `high`)
- **Verdict:** NOT CLEAN
- **Disposition:** ACCEPT-apply

## Blockers / Highs / Mediums

- **Blockers:** none
- **Highs:** none
- **Mediums:**
  - R5h-F01

## Reported issues (by severity)

### HIGH

| ID | Title |
|----|-------|
| — | **none** |

### MED

| ID | Title |
|----|-------|
| R5h-F01 | Cross-version ID non-reuse is promised but has no persisted state or retirement contract |

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
| R5h-F01 | MED | ACCEPT | Named mechanism: tombstone list (id-tombstones). Persist retired IDs in SPEC YAML. QC-13/QC-12 fail reissue. Step 7 sequential next-free skips tombstones. Fixtures: retired AC-03 reissued; retired EX-nn reissued; preserve-still-present; mint after retire skips the hole. |

## Resolved (after launcher ACCEPT fixes)

| ID | Severity | Title | Decision | Resolved |
|----|----------|-------|----------|----------|
| R5h-F01 | MED | Cross-version ID non-reuse is promised but has no persisted state or retirement contract | ACCEPT | yes |
