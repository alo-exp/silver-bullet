# Scope — Context Mode vs Lean Context (Ultradeep)

## Research question

For agentic coding and AI-assisted software engineering workflows, which context management solution is better: **Context Mode** or **Lean Context (LeanCTX)**, and under what conditions should Silver Bullet recommend one over the other?

## In scope

- Architecture, retrieval/indexing, token-savings models, agent UX, install/runtime complexity
- IDE/CLI integration for Cursor, Claude Code, Codex, and adjacent agents
- Privacy/security posture, local/offline behavior, licensing/pricing where published
- Fit with Silver Bullet recommended-tool policy (tier 1c token compression) and synergies with RTK, Graphify, agentmemory
- AF-DECIDE decision record with adoption conditions and residual risks

## Out of scope

- General-purpose vector databases or hosted RAG SaaS not positioned as agent context layers
- End-to-end benchmark reproduction (no controlled A/B token measurement in this run)
- LeanCTX Team/Enterprise commercial contract negotiation
- Context Mode Insight paid SaaS dashboard (explicitly out of SB scope per docs)

## Assumptions

1. Cursor + MCP + hooks is the reference SB host (see `asm_a1b2c3d4`).
2. Decision audience is SB maintainers choosing default recommended-tool guidance, not individual developers picking ad hoc utilities.
3. Public marketing claims (e.g., 60–90% token reduction) are recorded as vendor-stated unless independently measured.

## Success criteria

- Live-sourced evidence from leanctx.com and context-mode upstream docs
- Complete ultradeep artifact set with validation logs
- Actionable `decision-record.md` with winner, confidence, exceptions, and SB adoption path
