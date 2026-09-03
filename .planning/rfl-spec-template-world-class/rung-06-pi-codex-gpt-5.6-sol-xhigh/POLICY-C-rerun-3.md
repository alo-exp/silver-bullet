# Policy C — Pi Codex GPT-5.6 Sol Extra High (re-run pass 3)

- **Rung identity:** Pi Codex GPT-5.6 Sol Extra High (re-run pass 3) (`gpt` / `xhigh`)
- **Verdict:** NOT CLEAN
- **Disposition:** ACCEPT-apply

## Blockers / Highs / Mediums

- **Blockers:** none
- **Highs:**
  - R6c-F01
- **Mediums:** none

## Reported issues (by severity)

### HIGH

| ID | Title |
|----|-------|
| R6c-F01 | Wave 3 Steps 7a/8a and final pair installation: staged candidates are not carried through the review gates or committed with a recoverable two-file protocol |

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
| R6c-F01 | HIGH | ACCEPT | 7a/8a and review/QC gates between mint and install operate on staged SPEC/REQUIREMENTS candidates, not only on-disk canonical paths. Named recoverable pair-install (snapshot-restore): snapshot prior bytes of both before mutating either; if the second replace fails after the first, restore prior bytes of both. Fixtures: 7a/8a FAIL on staged candidate must not install; commit-boundary (second write fails after first) leaves both canonical files at prior bytes. Extends R6b; do not weaken R5h/R5i, Wave 6 1b, R5k exclusive NFR, or R6b staged-until-Step-8-succeeds. |

## Resolved (after launcher ACCEPT fixes)

| ID | Severity | Title | Decision | Resolved |
|----|----------|-------|----------|----------|
| R6c-F01 | HIGH | Wave 3 Steps 7a/8a and final pair installation: staged candidates are not carried through the review gates or committed with a recoverable two-file protocol | ACCEPT | yes |
