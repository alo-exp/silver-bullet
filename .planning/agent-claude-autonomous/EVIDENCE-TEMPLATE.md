# Agent-Claude Autonomous Run — Evidence Template

Copy to `runs/<run-id>/result.md` after delegation completes.

---

## Run metadata

| Field | Value |
|-------|-------|
| run_id | |
| row_id | AUTO-C01 / AUTO-C02 / AUTO-C03 |
| started_at | |
| completed_at | |
| install_fp | |
| sb_git_sha | |
| claude_work_dir | |
| delegate_exit | |
| verdict | PASS / FAIL / BLOCKED |

## Harness

| Artifact | Path |
|----------|------|
| brief | `runs/<run-id>/brief.md` |
| claude log | `runs/<run-id>/claude-run.log` |
| ledger stub | `runs/<run-id>/ledger.json` |
| monitor notes | (optional) |

## Product evidence

| Criterion | Evidence |
|-----------|----------|
| Commit SHA | |
| Branch | |
| Files touched | |
| Tests run | |

## Outcome scores (blocking)

| Outcome | Score | Notes |
|---------|-------|-------|
| OUT-AUTO-01 | pass/partial/fail | |
| OUT-NOOP-01 | pass/partial/fail | |
| OUT-CLARIFY-01 | pass/partial/fail/n/a | |
| OUT-ORCH-01 | pass/partial/fail/n/a | |
| OUT-WORLD-01 | pass/partial/fail/n/a | |

## Advisory

| Outcome | Score |
|---------|-------|
| OUT-KM-01 | |
| OUT-VLOOP-01 | |
| OUT-TRACE-01 | |

## failure_class (if FAIL)

## Operator interventions

List any non-blocking checkpoints or auth assists. **Assist-only = FAIL** for OUT-AUTO-01.

## Mentor note

What worked / what to change on next delegation wave.
