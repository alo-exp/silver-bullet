# Policy C — Pi Codex GPT-5.6 Sol Extra High (re-run pass 9)

- **Rung identity:** Pi Codex GPT-5.6 Sol Extra High (re-run pass 9) (`gpt` / `xhigh`)
- **Verdict:** NOT CLEAN
- **Disposition:** ACCEPT-apply

## Blockers / Highs / Mediums

- **Blockers:** none
- **Highs:** none
- **Mediums:**
  - R6i-F01
  - R6i-F02

## Reported issues (by severity)

### HIGH

| ID | Title |
|----|-------|
| — | **none** |

### MED

| ID | Title |
|----|-------|
| R6i-F01 | Functional AC-cell cardinality remains contradictory after R6h |
| R6i-F02 | NFR `Source` permits many-to-one but defines no cell-list grammar or behavioral parser fixture |

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
| R6i-F01 | MED | ACCEPT | Close the contradiction. R6h exact `AC-[0-9]{2}` cells wins: one Functional AC cell = exactly one `AC-nn`. Close the open “many-to-one via explicit AC column lists?” as no lists (`AC-01, AC-02` FAIL). Many-to-one REQ↔AC if needed is via multiple Functional rows, not a comma list in one cell. Fixture: `AC-01, AC-02` FAIL; `AC-01` PASS. |
| R6i-F02 | MED | ACCEPT | NFR `Source` many-to-one needs a named cell grammar and parser fixtures. Named `nfr-source-cell-list`: comma-separated source IDs with `, ` (comma + exactly one space), no other whitespace. Same parser for reverse-coverage / exclusivity / overlap FAIL. Template must not stay header-only empty. Fixture: two valid sources in one cell parse as two IDs; malformed list FAIL. Do not weaken R5k exclusive Source vs Dispositions. |

## Resolved (after launcher ACCEPT fixes)

| ID | Severity | Title | Decision | Resolved |
|----|----------|-------|----------|----------|
| R6i-F01 | MED | Functional AC-cell cardinality remains contradictory after R6h | ACCEPT | yes |
| R6i-F02 | MED | NFR `Source` permits many-to-one but defines no cell-list grammar or behavioral parser fixture | ACCEPT | yes |
