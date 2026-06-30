# Round N Outcomes — Enterprise E2E Matrix

Companion to [`ROUND-N-LEDGER.md`](ROUND-N-LEDGER.md). Score each criterion **pass / partial / fail / n/a** using [`OUTCOME-ASSESSMENT-RUBRIC.md`](OUTCOME-ASSESSMENT-RUBRIC.md).

Automated scoring (when artifacts exist):

```bash
source scripts/lib/enterprise-e2e-outcome-assessment.sh
enterprise_e2e_outcome_assess_round "$SB_ROOT/.planning/enterprise-e2e/ROUND-N-LEDGER.md"
```

---

## Round metadata

| Field | Value |
|-------|-------|
| Round | N |
| Ledger | `ROUND-N-LEDGER.md` |
| Assessor | |
| Assessment date | YYYY-MM-DD |
| Harness | `test-outcome-assessment.sh` @ SHA |

---

## Round-level criteria

| Criterion | Score | Notes | Evidence |
|-----------|-------|-------|----------|
| OUT-REVIEW-01 Review loop (8×2 verify) | | | ladder table |
| OUT-MEASURE-01 Ledger↔monitor integrity | | | reconcile status |
| OUT-KM-01 Knowledge management (round) | | | graphify update post-round |

**Round outcome score:** ___ / 3 round criteria pass

---

## Per-workflow checklist (22 rows)

Copy row block per workflow. Primary criteria from registry `workflow_row_map`.

### Row 1 — `silver-router`

| Criterion | Score | Notes |
|-----------|-------|-------|
| OUT-TAILOR-01 | | |
| OUT-ORCH-01 | | |
| OUT-SKILL-01 | | |
| OUT-HOOK-01 | | |
| OUT-CODEINT-01 | | |
| OUT-INTENT-01 | | |

### Row 2 — `silver-research`

| Criterion | Score | Notes |
|-----------|-------|-------|
| OUT-KM-01 | | |
| OUT-TRACE-01 | | |
| OUT-INTENT-01 | | |
| OUT-SKILL-01 | | |
| OUT-VLOOP-01 | | |

<!-- Repeat blocks for rows 3–22; or run: -->
<!-- enterprise_e2e_outcome_write_workflow_checklist <N> outcomes/row-N-outcomes.md -->

---

## Per-session checklist (live TUI / ladder)

| Session ID | Type | Date | Criteria assessed | Pass | Partial | Fail |
|------------|------|------|-------------------|------|---------|------|
| session-0 | bootstrap | | OUT-CODEINT-01, OUT-KM-01 | | | |
| row-1-attempt-1 | matrix TUI | | OUT-TAILOR-01, OUT-ORCH-01, … | | | |
| ladder-rung-1 | review-fix-ladder | | OUT-REVIEW-01 (partial) | | | |

**Session criteria (always):** OUT-SKILL-01, OUT-HOOK-01, OUT-ORCH-01, OUT-HANDOFF-01, OUT-CODEINT-01, OUT-KM-01, OUT-DECIDE-01, OUT-AUTO-01, OUT-NOOP-01, OUT-CLARIFY-01, OUT-HEAL-01, OUT-SUPER-01

**Blocking composite:** OUT-WORLD-01 — all applicable criteria must pass (partial = row fail).

---

## Summary

| Metric | Value |
|--------|-------|
| Workflow rows world-class (all primary criteria pass) | ___ / 22 |
| Sessions with zero fail on session criteria | ___ / ___ |
| Automated harness run | `bash tests/scripts/test-outcome-assessment.sh` |
| Registry version | `docs/testing/outcome-criteria-registry.json` v1 |

**Carryover:** Criteria scored partial/fail → link SB issue (`enterprise-test-app` label).
