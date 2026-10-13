# Policy C — Pi Claude Opus 5 Extra High

- **Rung identity:** Pi Claude Opus 5 Extra High (`claude` / `xhigh`)
- **Verdict:** NOT CLEAN
- **Disposition:** ACCEPT-apply

## Blockers / Highs / Mediums

- **Blockers:** none
- **Highs:**
  - F-8-1
- **Mediums:**
  - F-8-2
  - F-8-3
  - F-8-4
  - F-8-5
  - F-8-6

## Reported issues (by severity)

### HIGH

| ID | Title |
|----|-------|
| F-8-1 | No severity→exit-code contract; only three special cases specify nonzero, and the one WARN that does contradicts the implied default |

### MED

| ID | Title |
|----|-------|
| F-8-2 | Graphify skew WARN is permanently true, has no --fix action, and no stated interaction with default tree is green |
| F-8-3 | required_when_enabled: false vs a hard D10 FAIL: doctor is stricter than the enforcement layer |
| F-8-4 | version_drift WARN vs --fix=packages pinned install: downgrade and post-apply idempotency contradict |
| F-8-5 | Two canonical evidence ids have no test-plan row, including the implementer-trap id |
| F-8-6 | Confirmation gate trigger is undefined: scope requested vs package mutation actually planned |

### LOW

| ID | Title |
|----|-------|
| F-8-7 | D13–D19 range includes a print-only check and a check that does not exist |
| F-8-8 | Stale five host CLIs residue contradicts current-host-only |
| F-8-9 | unsupported_package_manager skip has no defined DOCTOR_FIX_APPLIED / exit outcome |
| F-8-10 | Users table promises an Omni PASS N/A row that cannot exist when Phase 3 is deferred |

### NIT

| ID | Title |
|----|-------|
| F-8-11 | Dead bare-UUID links to the origin review (three occurrences) |
| F-8-12 | Status: draft after eight review rungs and a locked SHA |

## Triage (launcher, not rung model)

| ID | Severity | Decision | Reason |
|----|----------|----------|--------|
| F-8-1 | HIGH | ACCEPT | FAIL → nonzero; WARN → zero except unknown_key; PASS/PASS N/A → zero; global test rows for WARN-only vs FAIL trees |
| F-8-2 | MED | ACCEPT | Graphify skew WARN is expected non-blocking advisory; --fix none (operator graphify install); green means no FAIL |
| F-8-3 | MED | ACCEPT | required_when_enabled gates hook enforcement not audit honesty; D10 still FAILs opted-in missing CLI; deliberate divergence |
| F-8-4 | MED | ACCEPT | Older than pin → repair via pinned install; newer than pin → WARN only, no downgrade, WARN persists after apply |
| F-8-5 | MED | ACCEPT | Global test rows for duplicate_key FAIL and cross_tool no_five_tool_consent PASS |
| F-8-6 | MED | ACCEPT | Confirmation gate is plan-triggered: fires when the ordered pass would execute a confirm-class mutation |
| F-8-7 | LOW | ACCEPT | Use D13/D14/D16/D18/D19 enumeration; D15 print-only; no D17 |
| F-8-8 | LOW | ACCEPT | Session A Omni D10 is current doctor host CLI only; freeze five-CLI catalog is not a D10 requirement |
| F-8-9 | LOW | ACCEPT | Skip is WARN-class: DOCTOR_FIX_APPLIED=0, receipt not-applied, exit zero unless FAIL also exists |
| F-8-10 | LOW | ACCEPT | Omni PASS N/A only once Phase 3 lands; deferred Phase 3 has no Omni D10 row |
| F-8-11 | NIT | ACCEPT | Origin review 759a2827 as inline code, not a dead relative UUID link |
| F-8-12 | NIT | ACCEPT | Status promoted to ready for Session A implementation |

## Resolved (after launcher ACCEPT fixes)

| ID | Severity | Title | Decision | Resolved |
|----|----------|-------|----------|----------|
| F-8-1 | HIGH | severity→exit | ACCEPT | yes |
| F-8-2 | MED | Graphify skew advisory | ACCEPT | yes |
| F-8-3 | MED | hook vs audit flag | ACCEPT | yes |
| F-8-4 | MED | no downgrade | ACCEPT | yes |
| F-8-5 | MED | evidence test rows | ACCEPT | yes |
| F-8-6 | MED | plan-triggered confirm | ACCEPT | yes |
| F-8-7 | LOW | D13 enumeration | ACCEPT | yes |
| F-8-8 | LOW | current-host CLI | ACCEPT | yes |
| F-8-9 | LOW | skip DOCTOR_FIX_APPLIED | ACCEPT | yes |
| F-8-10 | LOW | Omni N/A after Phase 3 | ACCEPT | yes |
| F-8-11 | NIT | inline-code origin review | ACCEPT | yes |
| F-8-12 | NIT | status ready | ACCEPT | yes |

