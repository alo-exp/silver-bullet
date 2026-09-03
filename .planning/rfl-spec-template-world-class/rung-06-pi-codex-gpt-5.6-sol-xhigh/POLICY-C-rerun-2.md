# Policy C — Pi Codex GPT-5.6 Sol Extra High (re-run pass 2)

- **Rung identity:** Pi Codex GPT-5.6 Sol Extra High (re-run pass 2) (`gpt` / `xhigh`)
- **Verdict:** NOT CLEAN
- **Disposition:** ACCEPT-apply

## Blockers / Highs / Mediums

- **Blockers:** none
- **Highs:**
  - R6b-F01
- **Mediums:** none

## Reported issues (by severity)

### HIGH

| ID | Title |
|----|-------|
| R6b-F01 | Wave 3 Steps 7–8 / Wave 6 writing branches: cross-artifact failure can commit only the new SPEC |

### MED

| ID | Title |
|----|-------|
| — | **none** |

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
| R6b-F01 | HIGH | ACCEPT | Pair-wide no-partial-output on greenfield and augment 2/3/4b as well as 1b. Named mechanism: staged pair commit — Step 7 must not durable-commit SPEC until Step 8 succeeds; both files commit together; Step 8 FAIL leaves prior SPEC bytes unchanged (or both unwritten). Fixture: Step 8 FAIL after a would-be Step 7 SPEC bump. Do not weaken R5h/R5i, Wave 6 1b preserve-or-fail-closed, or R5k exclusive NFR Source vs dispositions. |

## Resolved (after launcher ACCEPT fixes)

| ID | Severity | Title | Decision | Resolved |
|----|----------|-------|----------|----------|
| R6b-F01 | HIGH | Wave 3 Steps 7–8 / Wave 6 writing branches: cross-artifact failure can commit only the new SPEC | ACCEPT | yes |
