# Instruction-Following Audits

Adversarial audits of Cursor session instruction-following quality.

| Date | Session | Failure rate | Report |
|------|---------|-------------:|--------|
| 2026-06-28 | `e12690dc-fb94-4616-b1c4-d9341a80e789` | **76.2%** (80/105) | [SESSION-AUDIT-2026-06-28.md](./SESSION-AUDIT-2026-06-28.md) · [META-AUDIT-2026-06-28.md](./META-AUDIT-2026-06-28.md) |

## Scoring methodology (canonical)

1. Parse full parent transcript; exclude meta subagent handoff prompts.
2. Count **actionable** user instructions (site changes, publish, audits, explicit asks).
3. **Full** = no re-ask; **Partial** = incomplete or regressed; **Failed** = not done or blocked.
4. **Failure rate** = (Partial + Failed) / actionable × 100.
5. Score adversarially: user re-ask or complaint → Partial minimum.
