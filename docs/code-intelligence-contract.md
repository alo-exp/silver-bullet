# SB Code Intelligence Contract

Silver Bullet code intelligence is layered. No single engine is required for
core lifecycle enforcement. Every workflow that uses code intelligence records
which tier supplied the evidence.

## Capability Tiers

| Tier | Name | Operations | When used |
|------|------|------------|-----------|
| 0 | Shell discovery | `rg`, `grep`, `find`, `git log`, file reads, test output | Always available; default fallback |
| 1 | Graphify retrieval | semantic search, related-file retrieval, session graph queries | When user opted in (`recommended_tools.graphify.enabled_by_user: true`) and Graphify is installed/indexed; **stack optimization pass** (`sb-optimize-stack.sh`) required when opted in |
| 1b | agentmemory capture | session memory, proactive injection, `.agentmemory/` export | When user opted in (`recommended_tools.agentmemory.enabled_by_user: true`) and server/MCP are wired; pairs with tier 1 for save/retrieve synergy; **synergy_max optimization** applies launchd, bridge, `.env` |
| 1c | Token compression (opt-in) | RTK shell wiring; Context Mode MCP/fragment | RTK: install+wiring gates; fresh CLI usage before commits when installed. Context Mode: install+wiring gates — usage via `silver-bullet.md` §2g-ii |
| 1d | Browser/visual testing (opt-in) | Alumnium MCP wiring | Alumnium: MCP present when opted in; skill routing per §8.1 |
| 2 | Structural graph | call chains, dependency edges, module boundaries, duplicate hotspots | When graph queries return structural evidence |
| 3 | Live runtime | browser traces, HTTP probes, Playwright, deploy smoke | When a runnable app or environment exists |

Record the highest tier used in the artifact footer or findings table:

```markdown
Code intelligence tier: 1 (Graphify retrieval) with tier-0 shell fallback for file paths
```

## Entry Routes

| User intent | SB route | Typical tiers |
|-------------|----------|---------------|
| Deferred work / session recovery scan | `silver:scan` | 0, optional 1 |
| Phase or release context | `silver:context`, `silver:handoff` | 0–1 |
| Domain or code health audit | `silver:domain-audit`, `silver:review` | 0–2 |
| UI / E2E verification | `silver:test --mode e2e`, `silver:ui-review` | 0, 3 |
| Post-deploy confidence | `silver:canary`, `silver:deploy` | 0, 3 |

## Degradation Rules

1. Start at tier 0 when graph or live tooling is absent.
2. Do not block ship solely because tier 1+ is unavailable if tier 0 evidence
   is sufficient for the finding — **unless** the user opted into Graphify enforcement.
3. Do not claim call-chain or semantic coverage without naming the tier and
   command/query that produced it.
4. Prefer direct shell and test evidence for release blockers; use graph
   enrichment for breadth, not as a substitute for runnable verification.

## Related Docs

- `docs/evidence-schema.md` — normalized finding shape
- `docs/GRAPHIFY.md` — Graphify setup and retrieval patterns
- `docs/AGENTMEMORY.md` — agentmemory setup, MCP wiring, Graphify synergy
- `docs/STACK-OPTIMIZATION.md` — synergy_max profile, apply/verify automation
- `docs/RTK.md` — RTK install, wrong-binary guard, host hook wiring
- `docs/CONTEXT-MODE.md` — Context Mode install, ELv2 license, instruction fragment
- `skills/silver-scan/SKILL.md` — session and backlog discovery
