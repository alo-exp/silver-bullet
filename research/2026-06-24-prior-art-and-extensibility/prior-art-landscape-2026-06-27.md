# Deep Research: Silver Bullet Prior-Art Landscape
**Model:** opencode-go/deepseek-v4-pro | **Date:** 2026-06-27
**Coverage:** 23 candidates, 0 direct, 16 adjacent, 3 negative-result
**Gaps:** BMAD/GSD/Superpowers private; Devin closed-source; Cursor docs JS-rendered; arXiv zero papers on V-model+LLM-agent intersection.

## Executive Summary

No existing tool combines SB's five architectural differentiators: machine-readable workflow catalog, per-unit V-model verification rollups, hook-enforced lifecycle chains, explicit parent/worker split, and unified SE+DevOps coverage. Each differentiator exists separately — LangGraph (stateful DAG + checkpoints), CrewAI (Flows+Crews), Spec Kit (spec-driven phases), Aider (architect/editor split), Argo/Temporal (hardened DAG with retry) — but none stitches them into a composable, auditable, enforceable APO.

The biggest market gap is enforcement: no agent framework ships IDE-level hooks that block commits/PRs/deploys unless lifecycle skills complete with audit evidence. CI/CD tools enforce policies on infrastructure, not agent behavior. Enterprise orchestrators have mature DAGs but no LLM-native atomic flows, evidence tiers, or dynamic catalog composition. SB's `apo-catalog.json` as single-source-of-truth has no equivalent.

## Summary Table

| name | url | cat | composition | v_loop | enforce | SE | DevOps | p_w | evidence | dynamic | maturity |
|------|-----|-----|-------------|--------|---------|-----|--------|-----|----------|---------|----------|
| LangGraph | gh.com/langchain-ai/langgraph | adj | Stateful DAG; Command routing; checkpoints | end-only | honor | partial | - | partial | informal | replanner | prod v0.4 |
| CrewAI | gh.com/crewAIInc/crewAI | adj | Flows+Crews; seq/hier/cond | end-only | honor | partial | - | partial | informal | replanner | prod v0.108 |
| AutoGen/AG2 | gh.com/microsoft/autogen | adj | AgentChat teams; handoffs | none | honor | - | - | - | informal | - | prod v0.7 |
| OpenHands | gh.com/All-Hands-AI/OpenHands | adj | CodeAct sandbox loop; ACP | end-only | honor | partial | - | - | informal | - | beta rc11 |
| Spec Kit | gh.com/github/spec-kit | adj | constitution→implement phases | end-only | honor | strong | - | - | informal | - | alpha v0.0.22 |
| Aider | gh.com/Aider-AI/aider | adj | Architect→Editor dual-model | end-only | honor | strong | - | yes | informal | - | prod v0.82 |
| Claude Code | gh.com/anthropics/claude-code | tang | Single-agent tool use | end-only | honor | strong | - | - | informal | - | prod v2.0 |
| Cursor | cursor.com/docs | adj | Agent+rules+skills+MCP IDE | end-only | ide-hook | strong | - | - | informal | - | prod 2025 |
| Cline | gh.com/cline/cline | tang | Agent SDK+IDE+CLI | end-only | honor | strong | - | - | informal | - | beta v3.12 |
| Temporal | gh.com/temporalio/temporal | adj | DAG; retry; saga; replay | per-phase | ci-gate | - | strong | partial | informal | - | prod v1.27 |
| Camunda | gh.com/camunda/camunda | adj | BPMN; Zeebe; DMN | per-phase | policy | - | partial | partial | informal | - | prod v8.6 |
| Argo Workflows | gh.com/argoproj/argo-workflows | adj | K8s DAG+steps; retry | per-phase | ci-gate | - | strong | partial | artifact | - | prod v3.6 |
| Backstage | gh.com/backstage/backstage | adj | Catalog+templates; plugins | none | ci-gate | partial | partial | - | informal | - | prod v1.35 |
| Dagger | gh.com/dagger/dagger | tang | Pipeline-as-code; containers | end-only | ci-gate | - | strong | - | artifact | - | beta v0.18 |
| OPA | gh.com/open-policy-agent/opa | tang | Rego policy; decision logs | none | policy | - | partial | - | artifact | - | prod v1.2 |
| Harness | gh.com/harness/harness | adj | CI/CD+policy+flags+STO/SCA | per-phase | policy | - | strong | partial | artifact | - | prod 2025 |
| CodeRabbit | docs.coderabbit.ai | adj | AI PR review; rules; auto-fix | end-only | ci-gate | partial | - | - | informal | - | prod 2025 |
| Qodo/PR-Agent | qodo.ai | adj | AI review+quality governance | end-only | ci-gate | partial | - | - | tiered | - | prod 2025 |
| MetaGPT | arxiv.org/abs/2308.00352 | research | SOP roles; structured outputs | none | honor | partial | - | partial | artifact | - | research 2024 |
| BMAD Method | private | neg | Methodology phases/roles | none | honor | partial | - | - | informal | - | private 2024 |
| GSD | private | neg | PM/Architect/Engineer roles | none | honor | partial | - | - | informal | - | private 2024 |
| Semantic Kernel | gh.com/microsoft/semantic-kernel | tang | AI SDK; plugins; process exp. | none | honor | - | - | - | informal | - | prod v1.30 |
| Superpowers | private | neg | Coding workflow; no public footprint | none | honor | partial | - | - | informal | - | private 2024 |

## Key Gaps vs SB

- **LangGraph** (-catalog -vloop_rollup -hooks -evidence -devops) | +checkpoint_persistence
- **CrewAI** (-catalog -vloop_rollup -hooks -evidence -devops) | +event_triggers
- **AutoGen** (-catalog -vloop -hooks -se -devops) | +actor_distributed
- **Spec Kit** (-dynamic -vloop_rollup -hooks -p_worker -devops) | +constitution_gates
- **Aider** (-catalog -dynamic -vloop_rollup -hooks -devops -evidence) | +architect_editor_split
- **Temporal** (-agent_flows -se_catalog -ide_hooks -llm_evidence) | +replay +hardening
- **Argo** (-agent_flows -se_lifecycle -ide_hooks) | +artifact_passing +scaling
- **Harness** (-agent_catalog -vloops -p_worker) | +ci_cd_platform
- **Qodo** (-se_lifecycle -dynamic) | +soc2_evidence +governance
- **MetaGPT** (-vloop -hooks -dynamic) | +sop_roles +structured_outputs

## Evidence Quotes

- **LangGraph**: "Interrupts pause graph execution at specific points and wait for external input... LangGraph saves graph state using its persistence layer." — docs, Jun 2026
- **CrewAI**: "Crews: Teams of AI agents with true autonomy... Flows: Production-ready, event-driven workflows with precise control." — README, v0.108
- **Spec Kit**: "Spec-Driven Development flips the script. Specifications become executable, directly generating working implementations." — README, v0.0.22
- **Aider**: "Architect mode sends requests to two models: main model proposes solution, editor model turns proposal into specific file editing instructions." — docs, v0.82
- **Argo**: "Define a workflow as a directed-acyclic graph by specifying dependencies of each task. DAGs allow for maximum parallelism." — docs, v3.6
- **MetaGPT**: "Takes one-line requirement as input, outputs user stories/competitive analysis/requirements/data structures/APIs/documents." — arXiv 2308.00352

## Top 5 Closest (none qualify "direct" — need ≥3 of 6 diff.)

1. **Aider** (4/16) — only tool with explicit parent/worker split (architect→editor).
2. **Temporal** (5/16) — hardened DAG+retry+gates but no agent-native flows or SE catalog.
3. **Argo Workflows** (5/16) — K8s-native DAG+artifact passing+retry but no agent or SE model.
4. **Harness** (5/16) — CI/CD+policy platform but no agent workflow catalog or V-loops.
5. **LangGraph** (3/16) — best stateful DAG composition among agent frameworks.

## Top 5 Inspirations

1. **LangGraph checkpoints** — persistent snapshots for cross-session workflow resumption
2. **CrewAI event triggers** — event-driven flow triggering (on PR→start review)
3. **Spec Kit constitution.md** — project-level principles gating compliance
4. **Qodo SOC2 evidence** — tiered-sufficiency with compliance-vertical polish
5. **Temporal deterministic replay** — audit workflows via identical-input replay

## Negative Results

- **BMAD, GSD, Superpowers**: private methodologies, no public repos/docs. Referenced in SB docs historically, unverifiable.
- **arXiv "V-model + LLM agents"**: zero results. Academic community has not published on this intersection.
- **arXiv "verification loops + multi-agent"**: 4 false positives, no relevant papers.
- **arXiv "agentic process orchestrator"**: zero results. Term not established in literature.

## Open Questions

1. Devin/Cognition internals — closed-source; surface suggests closer match but unverifiable.
2. Cursor hook depth — JS-rendered docs hide possible enforcement infrastructure.
3. Microsoft AutoGen+Semantic Kernel convergence — could unify into Azure-native APO.
4. Temporal/Camunda adding LLM-native agent flows — credible enterprise APO threat within 12-18 months.
5. Spec Kit roadmap — deeper workflow composition and gates likely coming from GitHub.

## Aliases

AutoGen=AG2(v0.4+); Qodo=PR-Agent/CodiumAI; Windsurf=Devin Desktop/Codeium

## Scoring Matrix (0–2, max 16)

| candidate | cat | dyn | v_loop | enf | p_w | evid | se_dev | cust | **TOTAL** |
|-----------|:---:|:---:|:------:|:---:|:---:|:----:|:------:|:----:|:---------:|
| **SB (ref)** | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | **16** |
| Temporal | 0 | 1 | 1 | 1 | 1 | 0 | 1 | 0 | 5 |
| Argo | 0 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 5 |
| Harness | 0 | 0 | 1 | 1 | 1 | 1 | 1 | 0 | 5 |
| Aider | 0 | 0 | 1 | 0 | 2 | 0 | 1 | 0 | 4 |
| Camunda | 0 | 1 | 1 | 1 | 1 | 0 | 0 | 0 | 4 |
| Backstage | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 1 | 4 |
| LangGraph | 0 | 1 | 1 | 0 | 1 | 0 | 0 | 0 | 3 |
| CrewAI | 0 | 1 | 1 | 0 | 1 | 0 | 0 | 0 | 3 |
| Spec Kit | 1 | 0 | 1 | 0 | 0 | 0 | 1 | 0 | 3 |
| MetaGPT | 0 | 0 | 0 | 0 | 1 | 1 | 1 | 0 | 3 |
| Qodo | 0 | 0 | 1 | 1 | 0 | 1 | 0 | 0 | 3 |
| Cursor | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 0 | 3 |
| AutoGen | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 1 |
| OpenHands | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 1 |

*dims: cat=machine-readable; dyn=catalog-backed+audited; v_loop=per-step+intent; enf=ide-hooks+blockers; p_w=explicit split; evid=tiered-sufficiency; se_dev=both unified; cust=overlay packs*

## SB Positioning

SB is the only open-source APO combining a machine-readable workflow catalog with per-unit V-model verification, hook-enforced lifecycle chains, and unified SE+DevOps coverage. No competitor has all four.

**Moat**: `apo-catalog.json` as single-source-of-truth — atomic flows, workflows, V-loops, evidence records, tool policies, and dynamic composition rules with stable IDs and auditable composition logs. Competitors define workflows in code, BPMN, YAML, or prose — never as a structured catalog.

**Threats**: (1) Temporal/Camunda adding LLM-native agent flows with production hardening. (2) Spec Kit evolving to composable catalog with CI gates and GitHub distribution. (3) Microsoft converging AutoGen+Semantic Kernel into Azure-native APO.

**Defense**: Make `apo-catalog.json` consumable by external tools so SB is the canonical definition layer even when execution runs elsewhere.
