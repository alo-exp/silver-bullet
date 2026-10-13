Let me start by fetching primary sources for the key candidates in parallel.
Now let me fetch more specific sources for the key candidates.
Now let me search for research papers and the BMAD Method specifically, plus get deeper content from the key candidates.
Now let me search for the specific content I need from the indexed sources to understand composition models, verification, and enforcement.
Now I have enough data to compile the comprehensive research report. Let me write it.
Research complete. Report written to:

**`docs/research-260624/prior-art-landscape-research.md`**

## Key Findings

**22 candidates evaluated** across 8 SB dimensions. Silver Bullet occupies a **distinct architectural niche** — no existing tool combines all 7 differentiators.

### Closest Direct Matches (by score)

| Rank | Candidate | Score | Why |
|------|-----------|-------|-----|
| 1 | **Camunda** | 7/16 | BPMN catalog + policy enforcement + parent/worker — but not agent-specific |
| 2 | **MetaGPT** | 4/16 | `Code = SOP(Team)` — closest SDLC-specific match, but no V-loops or hooks |
| 3 | **CrewAI** | 4/16 | Flows + Crews + task guardrails — but no catalog or hook enforcement |
| 4 | **Argo/Harness** | 4/16 | Strong DevOps pipeline — but no SDLC catalog or verification model |

### Biggest Gaps in the Market

1. **No tool combines machine-readable workflow catalog + per-step V-loop rollup + hook-enforced lifecycle chains** — this is SB's strongest differentiator
2. **No tool unifies SE + DevOps in one APO model** — existing tools are either SE-focused or DevOps-focused
3. **No tool has catalog-backed audited dynamic composition** — LangGraph has dynamic routing but no audit trail
4. **Evidence tiers with staleness rules** appear nowhere in the landscape

### Negative Results

- **BMAD Method** and **GSD**: Could not verify as existing open-source projects (GitHub search returned nothing, domains don't resolve)
- **No credible "agentic process orchestrator"** combining ≥3 SB differentiators found

### Top Adjacent Inspirations

1. **Temporal** — durable execution for crash recovery
2. **OPA** — policy-as-code for tool governance
3. **Claude Code** — mature hook system + sub-agents
4. **Anthropic patterns** — orchestrator-workers pattern
5. **Earthly Lunar** — natural language → deterministic enforcement
