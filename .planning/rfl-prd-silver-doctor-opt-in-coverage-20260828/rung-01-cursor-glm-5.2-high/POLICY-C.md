# Policy C — Cursor GLM 5.2 High

- **Rung identity:** Cursor GLM 5.2 High (`glm` / `high`)
- **Verdict:** NOT CLEAN
- **Disposition:** ACCEPT-apply

## Blockers / Highs / Mediums

- **Blockers:** none
- **Highs:**
  - F-1
  - F-2
- **Mediums:**
  - F-3
  - F-4
  - F-5
  - F-6

## Reported issues (by severity)

### HIGH

| ID | Title |
|----|-------|
| F-1 | OQ3 SB_DOCTOR_ASSUME_YES TBD but F5 confirmation + test plan need non-interactive --fix |
| F-2 | OQ1/OQ2/OQ5 are phase prerequisites; no AC requires resolving OQs |

### MED

| ID | Title |
|----|-------|
| F-3 | Unknown tool: FAIL vs PASS N/A ambiguous |
| F-4 | Test plan under-covers false-green catalog + missing min_version row |
| F-5 | AC 8 omits test-router-doctor-report.sh required by Phase 3 |
| F-6 | AC 9 is a non-regression, not a positive done signal |

### LOW

| ID | Title |
|----|-------|
| F-7 | Phase 1 step 6 hedges --fix swallow vs L32 asserts it |
| F-8 | LeanCTX duplicate keys D10 FAIL vs D22 WARN wording |
| F-9 | OAuth one click vs manual |
| F-10 | Coverage table uses omniroute while OQ1 deferred the key |
| F-11 | OQ2 still open while Phase 1 already recommends PATH + version |

### NIT

| ID | Title |
|----|-------|
| F-12 | MUST NOT 3ht3 worktree is session-specific |
| F-13 | HNEST-01/HINST-01 undefined |
| F-14 | Freeze line citations unverifiable under charter |

## Triage (launcher, not rung model)

| ID | Severity | Decision | Reason |
|----|----------|----------|--------|
| F-1 | HIGH | ACCEPT | Lock SB_DOCTOR_ASSUME_YES=1 for tests; TTY still confirms packages/network/daemon restart |
| F-2 | HIGH | ACCEPT | Lock Session A defaults for OQ1/OQ2/OQ5 and add AC 11 requiring those defaults |
| F-3 | MED | ACCEPT | Unknown component id emits PASS N/A unsupported; no installer and no --fix |
| F-4 | MED | ACCEPT | Add false-green and min_version rows plus SB_DOCTOR_ASSUME_YES test row |
| F-5 | MED | ACCEPT | AC 8 requires test-router-doctor-report.sh when phase 3 is included |
| F-6 | MED | ACCEPT | Reframe AC 9 as a positive fixture that fails if consent-only loop is rewired |
| F-7 | LOW | ACCEPT | Remove hedge; Phase 1 is not done while swallow remains |
| F-8 | LOW | ACCEPT | D10 FAIL is Session A contract; D22 WARN is catalog label only |
| F-9 | LOW | ACCEPT | OAuth stays fully manual; --fix is install/restart only |
| F-10 | LOW | ACCEPT | Lock recommended_tools.omniroute / D10-omniroute |
| F-11 | LOW | ACCEPT | Lock search_cli Health as PATH + version; provider-missing WARN |
| F-12 | NIT | ACCEPT | Remove session-specific 3ht3 MUST NOT from the PRD |
| F-13 | NIT | ACCEPT | Gloss HNEST-01 / HINST-01 as nested-host and host-install Doctor writes |
| F-14 | NIT | ACCEPT | Cite freeze headings, not line numbers |

## Resolved (after launcher ACCEPT fixes)

| ID | Severity | Title | Decision | Resolved |
|----|----------|-------|----------|----------|
| F-1 | HIGH | OQ3 SB_DOCTOR_ASSUME_YES TBD | ACCEPT | yes |
| F-2 | HIGH | OQ1/OQ2/OQ5 prerequisites without AC | ACCEPT | yes |
| F-3 | MED | Unknown tool result state | ACCEPT | yes |
| F-4 | MED | Test plan under-coverage | ACCEPT | yes |
| F-5 | MED | AC 8 omits router doctor report test | ACCEPT | yes |
| F-6 | MED | AC 9 non-regression phrasing | ACCEPT | yes |
| F-7 | LOW | --fix swallow hedge | ACCEPT | yes |
| F-8 | LOW | D10 FAIL vs D22 WARN | ACCEPT | yes |
| F-9 | LOW | OAuth one click vs manual | ACCEPT | yes |
| F-10 | LOW | omniroute key pre-commit | ACCEPT | yes |
| F-11 | LOW | OQ2 still open | ACCEPT | yes |
| F-12 | NIT | 3ht3 MUST NOT | ACCEPT | yes |
| F-13 | NIT | HNEST-01/HINST-01 undefined | ACCEPT | yes |
| F-14 | NIT | Freeze line citations | ACCEPT | yes |

