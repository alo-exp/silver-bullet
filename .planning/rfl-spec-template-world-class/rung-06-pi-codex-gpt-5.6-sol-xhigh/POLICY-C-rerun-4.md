# Policy C — Pi Codex GPT-5.6 Sol Extra High (re-run pass 4)

- **Rung identity:** Pi Codex GPT-5.6 Sol Extra High (re-run pass 4) (`gpt` / `xhigh`)
- **Verdict:** NOT CLEAN
- **Disposition:** ACCEPT-apply

## Blockers / Highs / Mediums

- **Blockers:** none
- **Highs:**
  - R6d-F01
- **Mediums:** none

## Reported issues (by severity)

### HIGH

| ID | Title |
|----|-------|
| R6d-F01 | Wave 3 Step 8a/final install gate: fixes can mutate the staged pair after its cross-artifact validation without a mandatory final fixed-point revalidation |

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
| R6d-F01 | HIGH | ACCEPT | After any successful 8a (or 7a) mutation of staged bytes, re-run Step 8 / 7a/8a / review-cross-artifact (as applicable) on the exact staged pair that will be installed (named fixed-point). Install allowed only when the last review/QC PASS was on those bytes with no further mutation. If 8a mutates after a PASS, prior PASS is stale; fail-before-install until revalidated. Fixture: 8a mutates REQUIREMENTS after a pair PASS → install FAIL unless a subsequent full PASS on the new bytes. Extends R6b/R6c; do not weaken tombstones, Wave 6 1b, R5k exclusive NFR, R6b staged pair, or R6c snapshot-restore. Distinct from R6c snapshot-restore. |

## Resolved (after launcher ACCEPT fixes)

| ID | Severity | Title | Decision | Resolved |
|----|----------|-------|----------|----------|
| R6d-F01 | HIGH | Wave 3 Step 8a/final install gate: fixes can mutate the staged pair after its cross-artifact validation without a mandatory final fixed-point revalidation | ACCEPT | yes |
