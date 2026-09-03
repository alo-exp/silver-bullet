# Score triage — 20260705T171753Z-AUTO-C01

**Verdict after triage:** harness/scorer **false negative** — genuine agent delivery succeeded.

## Symptoms

| Outcome | Initial | Root cause |
|---------|---------|------------|
| OUT-AUTO-01 | fail | `cmd_score` passed `row_num=1` → routing-row path; babysitting FP on brief text |
| OUT-NOOP-01 | fail | Same babysitting FP (`without babysitting` in acceptance criteria) |
| OUT-CLARIFY-01 | pass | `/silver:clarify` mentioned in brief (instruction echo) |

`delegate_exit=0`, log ~269KB, commit `0b69977` on `feature/agent-claude-auto-c01`, tests pass.

## Root causes (fixed)

1. **Harness** — `agent-claude-autonomous-test.sh score` hardcoded `enterprise_row_num=1`, treating AUTO-C01 as enterprise matrix routing row. Routing path fails immediately on any babysitting signal. Fixed: `MATRIX.json` `scorer.enterprise_row_num` (3 for C01, 6 for C02).
2. **Scorer** — `enterprise_e2e_outcome_log_has_babysitting` matched substring `babysit` inside normalized `withoutbabysitting` from brief acceptance line. Fixed: E2E-097 negation exclusion (mirrors E2E-096 operator-pause fix).

## Re-score

```bash
bash scripts/agent-claude-autonomous-test.sh score --run 20260705T171753Z-AUTO-C01
```

No re-delegation required.
