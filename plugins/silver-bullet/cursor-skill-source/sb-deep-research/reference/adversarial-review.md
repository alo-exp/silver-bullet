# Adversarial Review Protocol

Multi-angle critique for `DR-CRITIQUE`. Cycles scale by mode:

| Mode | Cycles | Agents |
|------|--------|--------|
| standard | 0 | — |
| deep | 2 | skeptic + reviewer |
| ultradeep | 3 | skeptic + reviewer + red-team |

## Angles (each cycle)

1. **Steelman** — strongest case against recommendation
2. **Contradiction hunt** — conflicting sources on core claims
3. **Missing stakeholder** — who is not represented
4. **Failure mode** — what breaks if recommendation is wrong

## Output: `critique.md`

Structured claim-level deltas:

```json
{
  "delta_type": "contradiction|missing_source_class|unsupported_inference|decision_risk",
  "claim_id": "C1",
  "description": "...",
  "severity": "high|medium|low",
  "loopback": true
}
```

## Stopping rules

- Stop when no `high` severity deltas remain OR max cycles reached
- `ultradeep` requires `critique.md` + loopback or documented blocker in `handoff.md`
- Do not loop indefinitely — record residual risk in `decision-record.md`
