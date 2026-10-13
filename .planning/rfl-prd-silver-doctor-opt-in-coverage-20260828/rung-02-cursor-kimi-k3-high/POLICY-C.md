# Policy C — Cursor Kimi K3 High

- **Rung identity:** Cursor Kimi K3 High (`kimi` / `high`)
- **Verdict:** NOT CLEAN
- **Disposition:** ACCEPT-apply

## Blockers / Highs / Mediums

- **Blockers:** none
- **Highs:** none
- **Mediums:** none

## Reported issues (by severity)

### HIGH

| ID | Title |
|----|-------|
| — | **none** |

### MED

| ID | Title |
|----|-------|
| — | **none** |

### LOW

| ID | Title |
|----|-------|
| F-2-1 | D10-routes no-consent case is PASS not WARN |
| F-2-2 | OQ4 vendor-doctor hermetic path is a mandate with no owner |
| F-2-3 | Unknown-id test row omitted PASS N/A unsupported emission |
| F-2-4 | cross_tool coverage row vs recommended_tools keys only |
| F-2-5 | AC 9 canary vs fail phrasing reads contradictory |
| F-2-6 | docs_pin backfill unphased |

### NIT

| ID | Title |
|----|-------|
| F-2-7 | Duplicate vendor-doctor skip test rows |
| F-2-8 | Open-question numbering interleaved |
| F-2-9 | Implementer prompt omitted SB_DOCTOR_ASSUME_YES |

## Triage (launcher, not rung model)

| ID | Severity | Decision | Reason |
|----|----------|----------|--------|
| F-2-1 | LOW | ACCEPT | Describe no_five_tool_consent as PASS N/A; WARN only unsupported-host |
| F-2-2 | LOW | ACCEPT | Lock OQ4 as Session A default 4; Phase 2 + AC 11 own hermetic vendor-doctor path |
| F-2-3 | LOW | ACCEPT | Test row asserts PASS N/A reason unsupported; no installer; no --fix |
| F-2-4 | LOW | ACCEPT | Require derived cross_tool / D10-routes coverage row in Goal 2, F4, AC 1 |
| F-2-5 | LOW | ACCEPT | AC 9: tests fail if stale loop used; canary only stale loop could green stays non-green |
| F-2-6 | LOW | ACCEPT | Phase 2 docs_pin backfill for existing D10 rows |
| F-2-7 | NIT | ACCEPT | Merge duplicate vendor-doctor skip rows |
| F-2-8 | NIT | ACCEPT | Locked 1-5 sequential; still-open 6-7 |
| F-2-9 | NIT | ACCEPT | Name SB_DOCTOR_ASSUME_YES=1 in implementer prompt |

## Resolved (after launcher ACCEPT fixes)

| ID | Severity | Title | Decision | Resolved |
|----|----------|-------|----------|----------|
| F-2-1 | LOW | D10-routes no-consent PASS | ACCEPT | yes |
| F-2-2 | LOW | OQ4 mandate owner | ACCEPT | yes |
| F-2-3 | LOW | Unknown-id test emission | ACCEPT | yes |
| F-2-4 | LOW | cross_tool coverage row | ACCEPT | yes |
| F-2-5 | LOW | AC 9 canary phrasing | ACCEPT | yes |
| F-2-6 | LOW | docs_pin backfill phase | ACCEPT | yes |
| F-2-7 | NIT | Duplicate vendor-doctor rows | ACCEPT | yes |
| F-2-8 | NIT | OQ numbering | ACCEPT | yes |
| F-2-9 | NIT | Prompt ASSUME_YES | ACCEPT | yes |

