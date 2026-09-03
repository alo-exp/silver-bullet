# Score triage — 20260705T173019Z-AUTO-C02

**Verdict after triage:** harness/scorer **false negative** — genuine agent delivery succeeded.

## Symptoms (initial score)

| Outcome | Initial | Root cause |
|---------|---------|------------|
| OUT-AUTO-01 | partial | Babysitting FP on brief echo `without operator babysitting` (operator between without and babysit) |
| OUT-NOOP-01 | fail | Same babysitting FP |
| OUT-TAILOR-01 | n/a | Enterprise row 6 tailor scorer unconditionally returned n/a though AUTO-C02 blocks on OUT-TAILOR-01 |

`delegate_exit=0`, log ~170KB, commit `ed8c1d4` on `feature/agent-claude-auto-c02`, README marker present.

## Fixes applied

1. **Scorer** — extend E2E-097 negation to `without operator babysit` variants.
2. **Scorer** — row 6 tailor pass when fast-readme / composition / `/silver:fast` evidence present.

## Re-score

```bash
bash scripts/agent-claude-autonomous-test.sh score --run 20260705T173019Z-AUTO-C02
```

No re-delegation required.
