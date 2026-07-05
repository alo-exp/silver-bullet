# Decision Record (ART-DECIDE)

**Workflow:** WF-SILVER-DEEP-RESEARCH · **Atomic flow:** AF-DECIDE · **Mode:** ultradeep  
**Date:** 2026-07-05

## Chosen recommendation

**Silver Bullet should keep Context Mode as the default recommended context-management tool (tier 1c)** for opted-in users, and **recommend Lean Context (LeanCTX) only under explicit exception conditions** listed below—not as a wholesale replacement.

## Alternatives considered

| Alternative | Verdict |
|-------------|---------|
| Replace Context Mode with LeanCTX as sole SB recommended tool | **Rejected** — high integration cost, overlaps RTK+CM stack, no SB hook catalog today |
| Recommend both equally without routing guidance | **Rejected** — creates hook/stack ambiguity |
| Status quo (Context Mode only, ignore LeanCTX) | **Rejected** — leaves Apache-2.0 and governance use cases unaddressed |
| Conditional dual guidance (chosen) | **Accepted** |

## Evidence summary

LeanCTX offers broader context engineering (read AST modes, wire proxy, PathJail, signed savings ledger, Apache-2.0) [1][2][5][12]. Context Mode offers mature MCP sandboxing, FTS5 session memory, PreCompact recovery, and **existing SB install/enforcement** [6][8][10]. SB tier 1c already pairs Context Mode with RTK [9][10]. Live retrieval confirmed both are local-first [1][6].

## Tradeoffs and risks

| Factor | Context Mode (default) | Lean Context (exceptions) |
|--------|------------------------|---------------------------|
| SB wiring | Implemented hooks, docs, consent | Not in catalog |
| License | ELv2 — bundling constraint [8] | Apache-2.0 [5] |
| Compression | MCP / analysis path [6] | Read + wire + shell native [1][2] |
| Governance | Instruction + sandbox [6] | PathJail, ledger, enterprise plane [2][3] |
| Risk | ELv2 for commercial SB derivatives | Untested co-install with RTK+CM |

## Conditions — recommend Lean Context over Context Mode when

1. **License:** Apache-2.0 is required and ELv2 is unacceptable for redistribution or bundling.
2. **Read-path pain dominates:** primary waste is full-file Read/Grep of large codebases, not MCP tool floods.
3. **Wire compression:** team needs prompt-cache-preserving request proxy across providers [2].
4. **Governance/compliance:** Ed25519 savings ledger, evidence bundles, or fleet policy packs are mandatory [12][3].
5. **Security posture:** PathJail workspace confinement and deny-by-default shell allowlists are required beyond MCP sandbox rules [2].

## Conditions — recommend Context Mode (SB default) when

1. User is on SB recommended-tools path with RTK + Graphify + agentmemory synergy [9][10].
2. Primary failure mode is MCP/fetch/large-analysis output entering context [6][10].
3. Cursor/Claude/Codex hook integration with existing SB scripts is preferred [8].
4. ELv2 is acceptable for personal/internal use with disclosed consent [8].

## Confidence and remaining gaps

**Confidence:** medium-high (0.72) for SB policy routing; medium (0.55) for absolute "better product" in all environments.

**Remaining gaps:** no co-install benchmark; vendor savings percentages unverified; search-cli absent for broader triangulation.

## Downstream handoff route

- **Docs:** `/silver:ensure-docs` — optional adjacent-tools note linking this decision record (no catalog change in this run).
- **Future spike:** `/silver:feature` or manual integration branch to prototype `recommended_tools.lean_context` evaluation.
- **Artifacts:** [research_report.md](research_report.md), [handoff.md](handoff.md), [vloop-rollup.json](vloop-rollup.json)
