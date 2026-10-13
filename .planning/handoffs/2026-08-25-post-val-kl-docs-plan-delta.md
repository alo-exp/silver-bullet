# Plan delta — post-Val Executor K/L + key-doc hop (2026-08-25)

Plan-only. Both copies byte-identical.

| Copy | SHA-256 |
|---|---|
| `.planning/router_subagent_surfaces_85bf9f09.plan.md` | `6993d52039fe053a26aa8c000b879106d6eb91ee720348034d784534ecd16a22` |
| `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` | `6993d52039fe053a26aa8c000b879106d6eb91ee720348034d784534ecd16a22` |

Prior: `5c3c7c39…`. Bytes: 584593.

## MUST

Process-final Val vs user intent remains the Job’s last step against that intent. After it passes, **Executor** runs Job-scope K/L capture (existing KLW-01 helpers) and key-doc revision. **Advisor** reviews and **Verifier** verifies that hop. No second Process-final Val. Q-loop/thermos skip unless code was emitted. FAST keeps thin-capture only.

YAML `post-val-kl-docs` pending. KEEP REJECT not reopened.
