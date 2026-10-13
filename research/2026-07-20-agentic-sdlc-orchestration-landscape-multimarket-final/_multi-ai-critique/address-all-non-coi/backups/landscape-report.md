# Agentic SDLC Process Orchestrators Market Landscape Report

*Analyst-grade landscape analysis for SMB decision-makers*

Knowledge basis: Synthesised from multiple AI platform responses (claude-opus-4.8-medium, gemini-3.5-flash, gpt-5.6-luna-medium, ocg-deepseek-v4-flash, ocg-kimi-k2.7-code, ocg-mimo-v2.5, ocg-minimax-m3, ocg-qwen3.7-plus)
July 22, 2026

## 1. Market Definition & Scope

**Landscape scope**

Agentic SDLC orchestration solutions operating **one level above coding agents** — end-to-end, process-driven, workflow-based agentic layers for software engineering and DevOps (SecOps-adjacent). Excludes raw LLM APIs and single-shot copilots.

Research topic: `Agentic SDLC orchestration landscape multimarket final — APO primary, SDLC plugins secondary (BMAD GSD [Superpowers](https://github.com/obra/superpowers) Spec Kit Oh My [Zuvo](https://zuvo.dev/) OSS), agentic SDLC SaaS tertiary (Factory Devin Augment Code (Cosmos))`

**Primary jobs-to-be-done**

1. Enforce a full SDLC or DevOps cycle so agents cannot skip planning, verification, review, or release steps
2. Compose specialist agents and external workflows (GSD, spec kits, review ladders) under one compliance layer
3. Persist process state, gates, and evidence across sessions and parallel workers
4. Provide procurement-ready comparison of process-orchestration depth vs host runtimes and frameworks

**Out of scope (excluded from core peer set)**

- Generic **coding agents** and IDE copilots (Cursor Background Agents, Cline, Aider, Continue, OpenHands, SWE-agent)
- **Host runtimes** that execute code without a process catalog (Devin, Copilot, [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) as hosts — listed under Adjacent only)

  - **Market-layer note (P0 consistency):** Devin is **adjacent** for the primary APO market (host runtime, not a process layer above a host). Devin **is** a **core Leader** in the tertiary **Agentic SDLC SaaS** market — those are different membership contracts, not a single “adjacent-only everywhere” rule.
- **Single-step** tools (PR review bots, PM integrations such as Linear)
- **Generic agent frameworks** without SDLC process packaging (LangGraph, [CrewAI](https://github.com/crewAIInc/crewAI) as adjacent)
- **Excluded / non-core** products (GitHub Copilot Workspace — discontinued; **AutoGen / AG2** — active multi-agent *framework* (not a sunset product; out of scope as programmable framework, not SDLC process pack); AgentGPT; Devika)

**Inclusion criteria**

**Cavekit versioning policy:** Cavekit v3.1 remains the APO-listed seed from the inclusion ledger for this run; Cavekit v4 stays adjacent until a verified envelope shows process-layer (not framework-only) evidence that clears 3-of-7. This is an evidence gate — not a claim that v3.1 is “newer/better.”


A vendor belongs in the **core peer set** when it clearly demonstrates at least **3 of 7** capabilities below (not advisory-only claims):

- **Multi-phase lifecycle span** — Covers two or more of plan/spec, build, test, review, release, or DevOps operations as an integrated process — not a single-shot codegen or review-only tool.
- **Plugin / skill / hook packaging** — Ships as host-integrated packaging (Claude/[Codex](https://openai.com/codex/)/[Cursor](https://cursor.com/) plugin, skill bundle, hook layer, or equivalent) rather than a standalone IDE or raw API.
- **Deterministic quality gates** — Uses machine-checkable gates (hooks, audits, stop-checks, CI integration) that block progression when criteria fail.
- **Cross-session state** — Persists workflow state, memory, or runbooks across agent clears, sessions, or parallel workers.
- **Specialist agent orchestration** — Routes work to named specialist agents, hats, or role-specific subagents — not a single monolithic agent.
- **Quality / release enforcement claim** — Publicly claims enforcement of quality, compliance, release, or governance — not advisory-only suggestions.
- **Process layer above host runtime** — Positions as a meta-orchestrator or compliance wrapper above [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview), [Codex](https://openai.com/codex/), [Cursor](https://cursor.com/), or similar — not as the host runtime itself.


### Conflict of interest / authorship disclosure

This landscape was produced **inside the Silver Bullet repository** by Silver Bullet’s own `silver-deep-research-multi-ai` research engine. Silver Bullet appears as a plotted vendor (APO + SDLC plugins). Treat SB placements, matrix scores, and buying-guidance mentions as **author-interested** unless independently verified. This pass discloses that bias explicitly; it does **not** claim third-party analyst neutrality.

### Scoring & chart methodology (reader contract)

1. **Magic Quadrant (MQ)** — market-specific X/Y axes (see each §3.x title). Quadrant mid = 5.5. Canonical **MQ Leaders** = `chart-data.json` → `markets.<id>.mq_data` where `q === "Leaders"`.
2. **Gartner-style MQ (GMQ)** — separate Completeness of Vision × Ability to Execute axes. **GMQ Leaders ≠ MQ Leaders**; do not union them.
3. **Wave** — Offering / Strategy / Presence. Wave rosters are **top-N** by offering×strategy among MQ-plotted cores (APO N=8, plugins N=7, SaaS N=all plotted). Vendors MQ-plotted but omitted from Wave are listed in per-market `methodology.wave_omitted` in chart-data — not silently dropped.
4. **Blue Ocean / Value Curve** — KCF radar for a **contrast shortlist**, not a Leader definition.
5. **Unknowns** — thin-evidence or unverified claims are labeled **unknown** / Niche / watchlist. Do not read templated pros as proven capability.
6. **Product shapes** — host runtime, autonomous SaaS, method/plugin pack, and programmable framework are different purchase objects (see §11).


## 2. Market Overview

As of July 2026, the category is **early mainstream**: buyers separate agent hosts from process layers, but few vendors combine machine-readable catalogs with hook-enforced gates.
Verify latest data — market size estimates for agentic SDLC orchestration are not web-verified in this synthesis; growth is driven by multi-agent adoption and verification-gate demand.

- **Maturity**: Early mainstream; executor-first agents are ahead of process catalogs.
- **Commercial vs OSS**: OSS frameworks dominate experimentation; commercial players lead managed execution.
- **SMB vs enterprise**: SMBs favour templates, predictable pricing, and managed hosting; enterprises prioritise audit, SSO, and residency.
- **Deployment**: SaaS agents, IDE plugins, and self-hosted OSS graphs coexist; switching costs rise with hook and catalog lock-in.

## 3. Competitive Positioning — Analyst Frameworks

### 3.1 Primary market: Agentic Process Orchestrators (APO)

#### 3.1.1 Agentic Process Orchestrators (APO) — Positioning Matrix

#### 3.1.2 Magic Quadrant — Agentic Process Orchestrators (APO)

| Vendor | Quadrant | Justification |
|--------|----------|---------------|
| [AgentHub](https://www.agenthub.ai/) | Leaders | Positioned from mq_data; SPA chart authoritative. |
| [AgentSys](https://github.com/agent-sh/agentsys) | Challengers | Positioned from mq_data; SPA chart authoritative. |
| [AI-DLC](https://github.com/awslabs/aidlc-workflows) | Leaders | Positioned from mq_data; SPA chart authoritative. |
| [ATeam](https://www.a.team/) | Challengers | Positioned from mq_data; SPA chart authoritative. |
| [Barkain Workflow Orchestrator](https://barkain.com/) | Niche Players | thin evidence → treat capabilities as unknown |
| [Cavekit v3.1](https://cavekit.ai/) | Niche Players | thin evidence → treat capabilities as unknown |
| [cc10x](https://cc10x.dev/) | Visionaries | thin evidence → treat capabilities as unknown |
| Deepwork | Niche Players | thin evidence → treat capabilities as unknown |
| Director | Niche Players | thin evidence → treat capabilities as unknown |
| [MetaGPT](https://github.com/FoundationAgents/MetaGPT) | Niche Players | Positioned from mq_data; SPA chart authoritative. |
| [Silver Bullet](https://sb.alolabs.dev/) | Leaders | Positioned from mq_data; SPA chart authoritative. |
| Turboshovel | Niche Players | thin evidence → treat capabilities as unknown |
| Workflow Manager | Niche Players | thin evidence → treat capabilities as unknown |

> **Challengers (mq_data):** AgentSys, ATeam.

> **Leader definition (canonical):** MQ Leaders above = `markets.apo.mq_data` with `q=Leaders`. GMQ / Blue Ocean / buying prose must not invent a competing Leader set.


#### 3.1.3 Wave-Style Assessment — Agentic Process Orchestrators (APO)

| Vendor | Current Offering | Strategy | Market Presence |
|--------|------------------|----------|-----------------|
| [Silver Bullet](https://sb.alolabs.dev/) | Strong (4) | Strong (4) | Competitive (3) |
| [cc10x](https://cc10x.dev/) | Strong (4) | Competitive (3.1) | Competitive (3) |
| [AI-DLC](https://github.com/awslabs/aidlc-workflows) | Competitive (3.4) | Limited (2.2) | Competitive (3) |
| [Cavekit v3.1](https://cavekit.ai/) | Competitive (2.6) | Limited (1.7) | Limited (2) |
| Director | Competitive (2.6) | Limited (2) | Limited (2) |
| [AgentHub](https://www.agenthub.ai/) | Competitive (2.5) | Limited (1.9) | Limited (2) |
| [AgentSys](https://github.com/agent-sh/agentsys) | Competitive (2.5) | Limited (2) | Limited (2) |
| [ATeam](https://www.a.team/) | Limited (2.4) | Limited (2) | Limited (2) |

> **MQ-plotted, not Wave-scored:** barkain-workflow-orchestrator, deepwork, metagpt, turboshovel, workflow-manager. Rule: Wave plots top-N by offering×strategy composite among MQ-plotted cores (N=8 for APO). Non-Wave MQ vendors remain MQ-plotted but are not Wave-scored.


#### 3.1.4 Blue Ocean Value Curve — Agentic Process Orchestrators (APO)

KCF radar for contrast among a shortlisted peer set. **Not a Leader definition.** Canonical MQ Leaders: AgentHub, AI-DLC, Silver Bullet.

| Key Competitive Factor | [cc10x](https://cc10x.dev/) | [AgentHub](https://www.agenthub.ai/) | [Silver Bullet](https://sb.alolabs.dev/) | [AI-DLC](https://github.com/awslabs/aidlc-workflows) |
|---|---|---|---|---|
| Workflow composition | 5 | 5 | 5 | 5 |
| Atomic flow catalog | 3 | 3 | 5 | 3 |
| Hook-enforced gates | 5 | 3 | 5 | 3 |
| Parent/child delegation | 3 | 5 | 5 | 3 |
| Managed hosting | 3 | 3 | 3 | 3 |
| Prebuilt SDLC templates | 3 | 3 | 5 | 5 |
| CI integration | 3 | 3 | 3 | 3 |
| IDE-native integration | 5 | 5 | 5 | 3 |
| Free tier / OSS core | 5 | 3 | 5 | 5 |
| Predictable pricing | 3 | 3 | 3 | 3 |

### 3.2 Secondary market: SDLC Plugins & Methodology Packs

#### 3.2.1 SDLC Plugins & Methodology Packs — Positioning Matrix

#### 3.2.2 Magic Quadrant — SDLC Plugins & Methodology Packs

| Vendor | Quadrant | Justification |
|--------|----------|---------------|
| [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD) | Leaders | Positioned from mq_data; SPA chart authoritative. |
| [Claude Harness](https://github.com/anthropics/claude-code) | Niche Players | identity unverified |
| [GitHub Spec Kit](https://github.com/github/spec-kit) | Challengers | Positioned from mq_data; SPA chart authoritative. |
| [GSD (Get Shit Done)](https://github.com/gsd-build/get-shit-done) | Leaders | Positioned from mq_data; SPA chart authoritative. |
| Oh My Pi (OMP) | Leaders | Positioned from mq_data; SPA chart authoritative. |
| Ruflo (formerly Claude Flow) | Challengers | Positioned from mq_data; SPA chart authoritative. |
| [Silver Bullet](https://sb.alolabs.dev/) | Leaders | Positioned from mq_data; SPA chart authoritative. |
| [SuperClaude](https://github.com/SuperClaude-Org/SuperClaude_Framework) | Challengers | Positioned from mq_data; SPA chart authoritative. |
| [Superpowers](https://github.com/obra/superpowers) | Visionaries | Positioned from mq_data; SPA chart authoritative. |

> **Challengers (mq_data):** GitHub Spec Kit, Ruflo (formerly Claude Flow), SuperClaude.

> **Leader definition (canonical):** MQ Leaders above = `markets.sdlc-plugins.mq_data` with `q=Leaders`. GMQ / Blue Ocean / buying prose must not invent a competing Leader set.


#### 3.2.3 Wave-Style Assessment — SDLC Plugins & Methodology Packs

| Vendor | Current Offering | Strategy | Market Presence |
|--------|------------------|----------|-----------------|
| [Silver Bullet](https://sb.alolabs.dev/) | Strong (4) | Strong (4) | Competitive (3) |
| [GSD (Get Shit Done)](https://github.com/gsd-build/get-shit-done) | Strong (4) | Competitive (3.4) | Competitive (3) |
| Oh My Pi (OMP) | Strong (4) | Strong (3.6) | Competitive (3) |
| [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD) | Strong (4) | Strong (3.5) | Competitive (3) |
| Ruflo (formerly Claude Flow) | Strong (3.9) | Competitive (3.2) | Competitive (3) |
| [Superpowers](https://github.com/obra/superpowers) | Strong (3.9) | Competitive (3.1) | Competitive (3) |
| [GitHub Spec Kit](https://github.com/github/spec-kit) | Strong (3.7) | Competitive (3.2) | Competitive (3) |

> **MQ-plotted, not Wave-scored:** superclaude, claude-harness. Rule: Wave plots top-N by offering×strategy (N=7 for plugins). Claude Harness (unverified) excluded from Wave.


#### 3.2.4 Blue Ocean Value Curve — SDLC Plugins & Methodology Packs

KCF radar for method-pack contrast — **not** an alternate Leaders list. Canonical MQ Leaders from mq_data only.

| Key Competitive Factor | [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD) | GSD (Get Shit Done) | Oh My Pi (OMP) | [Ruflo (formerly Claude Flow)](https://github.com/ruvnet/ruflo) | [Silver Bullet](https://sb.alolabs.dev/) |
|---|---|---|---|---|---|
| Workflow composition | 5 | 5 | 5 | 5 | 5 |
| Atomic flow catalog | 3 | 3 | 3 | 3 | 5 |
| Hook-enforced gates | 5 | 5 | 5 | 5 | 5 |
| Parent/child delegation | 3 | 3 | 5 | 5 | 5 |
| Managed hosting | 3 | 3 | 3 | 3 | 3 |
| Prebuilt SDLC templates | 5 | 5 | 5 | 5 | 5 |
| CI integration | 3 | 3 | 3 | 3 | 3 |
| IDE-native integration | 5 | 5 | 5 | 5 | 5 |
| Free tier / OSS core | 5 | 5 | 5 | 5 | 5 |
| Predictable pricing | 3 | 3 | 3 | 3 | 3 |

### 3.3 Tertiary market: Agentic SDLC SaaS & Autonomous Delivery

#### 3.3.1 Agentic SDLC SaaS & Autonomous Delivery — Positioning Matrix

#### 3.3.2 Magic Quadrant — Agentic SDLC SaaS & Autonomous Delivery

| Vendor | Quadrant | Justification |
|--------|----------|---------------|
| [Augment Code (Cosmos)](https://www.augmentcode.com/) | Visionaries | Public brand is Augment Code; Cosmos is an Augment agentic SDLC capability/surface — not a separate standalone vendor. |
| [Devin](https://devin.ai/) | Leaders | Positioned from mq_data; SPA chart authoritative. |
| [Factory.ai](https://www.factory.ai/) | Leaders | Positioned from mq_data; SPA chart authoritative. |
| [Magic.dev](https://magic.dev/) | Visionaries | Positioned from mq_data; SPA chart authoritative. |
| [Tembo](https://tembo.io/) | Visionaries | identity risk — verify product surface; IDENTITY RISK: tembo.io is widely known as a Postgres platform. Agentic-SDLC-SaaS placement depends on a distinct agent  |

> **Challengers:** none in this market’s mq_data. With only five verified SaaS cores and two clear Leaders (Devin, Factory.ai), remaining peers are Visionaries by axis placement. No honest Challenger (high execution / lower vision) exists in the verified set without inventing vendors — Challengers remain empty by evidence, not by all-Leaders collapse.

> **Leader definition (canonical):** MQ Leaders above = `markets.agentic-sdlc-saas.mq_data` with `q=Leaders`. GMQ / Blue Ocean / buying prose must not invent a competing Leader set.


#### 3.3.3 Wave-Style Assessment — Agentic SDLC SaaS & Autonomous Delivery

| Vendor | Current Offering | Strategy | Market Presence |
|--------|------------------|----------|-----------------|
| [Devin](https://devin.ai/) | Strong (4) | Competitive (2.7) | Strong (4) |
| [Factory.ai](https://www.factory.ai/) | Strong (3.7) | Limited (2.3) | Competitive (3) |
| [Augment Code (Cosmos)](https://www.augmentcode.com/) | Strong (3.5) | Limited (2) | Competitive (3) |
| [Tembo](https://tembo.io/) | Competitive (3) | Limited (2.1) | Limited (2) |
| [Magic.dev](https://magic.dev/) | Competitive (2.8) | Limited (1.6) | Limited (2) |

> Wave includes all MQ-plotted cores for this market.


#### 3.3.4 Blue Ocean Value Curve — Agentic SDLC SaaS & Autonomous Delivery

KCF radar for SaaS contrast — **not** an alternate Leaders list. Visionaries may appear for axis contrast.

| Key Competitive Factor | Devin | [Factory.ai](https://www.factory.ai/) | Augment Code (Cosmos) | [Magic.dev](https://magic.dev/) | [Tembo](https://tembo.io/) |
|---|---|---|---|---|---|
| Workflow composition | 5 | 5 | 5 | 5 | 5 |
| Atomic flow catalog | 3 | 3 | 3 | 3 | 3 |
| Hook-enforced gates | 3 | 3 | 3 | 3 | 3 |
| Parent/child delegation | 3 | 5 | 5 | 3 | 5 |
| Managed hosting | 5 | 5 | 5 | 5 | 5 |
| Prebuilt SDLC templates | 3 | 3 | 3 | 3 | 3 |
| CI integration | 3 | 3 | 3 | 3 | 3 |
| IDE-native integration | 5 | 5 | 5 | 5 | 5 |
| Free tier / OSS core | 5 | 3 | 3 | 3 | 3 |
| Predictable pricing | 5 | 3 | 3 | 3 | 3 |


## 4. Key Industry Trends

### Process-first orchestration above coding agents
- **What**: Buyers increasingly separate the agent host (IDE, cloud sandbox) from the SDLC process layer that composes workflows, enforces gates, and records skills.
- **SMB impact**: SMBs without platform teams need opinionated process packs rather than bespoke agent graphs.
- **Vendor response**: [Silver Bullet](https://sb.alolabs.dev/), [Factory.ai](https://www.factory.ai/), and GitHub Copilot Workspace market explicit SDLC chains; [Cursor](https://cursor.com/) and Devin remain executor-first.

### Hook-enforced lifecycle gates
- **What**: Host hooks that fail closed on skill recording, planning ownership, and delivery gates are emerging as trust rails for autonomous work.
- **SMB impact**: Reduces rework risk when junior teams delegate multi-step agent runs.
- **Vendor response**: [Silver Bullet](https://sb.alolabs.dev/) and [Cursor](https://cursor.com/) document hook layers; most git-native agents lack cross-host gate parity.

### Machine-readable workflow catalogs
- **What**: Atomic flow catalogs (workflows, steps, V-loops) enable composition, audit, and CI freshness checks beyond ad-hoc prompts.
- **SMB impact**: Lets lean teams adopt SDLC patterns without writing orchestration code.
- **Vendor response**: [Silver Bullet](https://sb.alolabs.dev/) ships `apo-catalog.json`; spec-kit and GSD offer lighter-weight spec packs.

### Git-native issue→PR agent loops
- **What**: Issue trackers and repos become control planes for multi-step agent work with human review on PRs.
- **SMB impact**: Fits teams already on GitHub; lowers integration tax versus custom runtimes.
- **Vendor response**: GitHub Copilot Workspace, Sweep, and [Tembo](https://tembo.io/) target this pattern.

### Autonomous software engineers (plan→ship)
- **What**: Managed agents that plan, implement, test, and open PRs in customer repos are maturing for enterprise pilots.
- **SMB impact**: High capability but opaque process; pricing and governance remain enterprise-weighted.
- **Vendor response**: Devin, [Factory.ai](https://www.factory.ai/) Droids, and [Magic.dev](https://magic.dev/) compete here.

### BYO agent runtimes and graph orchestration
- **What**: Frameworks expose durable graphs, interrupts, and delegation primitives for custom orchestration.
- **SMB impact**: Maximum flexibility at the cost of in-house agent ops expertise.
- **Vendor response**: [LangGraph Platform](https://www.langchain.com/langgraph), [CrewAI](https://github.com/crewAIInc/crewAI), and AutoGen anchor this segment; [MetaGPT](https://github.com/FoundationAgents/MetaGPT) is scored as APO OSS core, not a generic framework adjacent.

### Spec-driven and context-engineering workflows
- **What**: Lightweight methodology packs emphasize intent specs, critique loops, and context hygiene before code.
- **SMB impact**: Low-cost entry for teams not ready for full orchestration platforms.
- **Vendor response**: [GitHub spec-kit](https://github.com/github/spec-kit), GSD, and [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD) are representative.

### Multi-model pools and triangulated research
- **What**: Landscape and buying decisions increasingly synthesise multiple model families with explicit divergence tracking.
- **SMB impact**: Improves confidence on niche categories where single-vendor marketing dominates.
- **Vendor response**: Emerging in research tooling (MultAI pattern); not yet productised by incumbents.

## 5. Agentic Process Orchestrators (APO) — Top Commercial Solutions (8 core)

### [AgentHub](https://www.agenthub.ai/) (Commercial)

* **Overview**: [AgentHub](https://www.agenthub.ai/) is a primary-market APO candidate — multi-agent coordination, workflow persistence, specialist routing, cross-session state.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Parent/child agent delegation**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Parent/child delegation**: Supported in startup-weighted comparison matrix.
  * **Managed path**: Commercial offering with vendor-operated components.
* **Major Cons**:
  * **Hosting burden**: May require self-managed integration for some deployment paths.
  * **Weak hook gates**: Lacks explicit fail-closed lifecycle hooks versus process-first peers.
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [AgentHub](https://www.agenthub.ai/).
* **Avoid If**: You need capabilities [AgentHub](https://www.agenthub.ai/) lacks in the matrix (Atomic flow catalog, Hook-enforced gates).

### [ATeam](https://www.a.team/) (Commercial)

* **Overview**: [ATeam](https://www.a.team/) is a primary-market APO candidate — team-of-agents orchestration, role-based specialist routing, process enforcement, multi-phase lifecycle coverage.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Parent/child agent delegation**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Parent/child delegation**: Supported in startup-weighted comparison matrix.
  * **Managed path**: Commercial offering with vendor-operated components.
* **Major Cons**:
  * **Hosting burden**: May require self-managed integration for some deployment paths.
  * **Weak hook gates**: Lacks explicit fail-closed lifecycle hooks versus process-first peers.
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [ATeam](https://www.a.team/).
* **Avoid If**: You need capabilities [ATeam](https://www.a.team/) lacks in the matrix (Atomic flow catalog, Hook-enforced gates).

### [Barkain Workflow Orchestrator](https://barkain.com/) (Commercial)

* **Overview**: THIN EVIDENCE — Barkain is a seed-level commercial orchestrator listing. Cross-session persistence and gate claims are **unknown** without independent corroboration; MQ demoted to Niche Players.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Managed path**: Commercial offering with vendor-operated components.
  * **Ecosystem momentum**: Active presence in the agentic SDLC orchestration category.
* **Major Cons**:
  * **Hosting burden**: May require self-managed integration for some deployment paths.
  * **Weak hook gates**: Lacks explicit fail-closed lifecycle hooks versus process-first peers.
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [Barkain Workflow Orchestrator](https://barkain.com/).
* **Avoid If**: You need capabilities [Barkain Workflow Orchestrator](https://barkain.com/) lacks in the matrix (Atomic flow catalog, Hook-enforced gates).

### [Cavekit v3.1](https://cavekit.ai/) (Commercial)

* **Overview**: THIN EVIDENCE — Cavekit v3.1 is listed from the inclusion seed set. Treat feature depth as **unknown** beyond seed metadata; see Cavekit versioning policy (v4 remains adjacent until process-layer evidence clears).
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Skill/plugin marketplace**: Supported in startup-weighted comparison matrix.
  * **Managed path**: Commercial offering with vendor-operated components.
* **Major Cons**:
  * **Hosting burden**: May require self-managed integration for some deployment paths.
  * **Weak hook gates**: Lacks explicit fail-closed lifecycle hooks versus process-first peers.
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [Cavekit v3.1](https://cavekit.ai/).
* **Avoid If**: You need capabilities [Cavekit v3.1](https://cavekit.ai/) lacks in the matrix (Atomic flow catalog, Hook-enforced gates).

### [cc10x](https://cc10x.dev/) (Commercial)

* **Overview**: cc10x is a primary-market APO candidate — a Claude Code–oriented enhancement pack for multi-agent coordination, process enforcement, and host-integrated packaging. Public footprint is thinner than Silver Bullet or AI-DLC; treat adoption claims as unverified without primary metrics.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **Quick onboarding**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Skill/plugin marketplace**: Supported in startup-weighted comparison matrix.
  * **Managed path**: Commercial offering with vendor-operated components.
* **Major Cons**:
  * **Hosting burden**: May require self-managed integration for some deployment paths.
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [cc10x](https://cc10x.dev/).
* **Avoid If**: You need capabilities [cc10x](https://cc10x.dev/) lacks in the matrix (Atomic flow catalog, Predictable pricing).

### Deepwork (Commercial)

* **Overview**: THIN EVIDENCE — Deepwork is a seed-level APO commercial candidate. Specific capabilities below are **unknown** without primary product documentation; prior templated “supported in matrix” bullets are not proof of shipped features.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Managed path**: Commercial offering with vendor-operated components.
  * **Ecosystem momentum**: Active presence in the agentic SDLC orchestration category.
* **Major Cons**:
  * **Hosting burden**: May require self-managed integration for some deployment paths.
  * **Weak hook gates**: Lacks explicit fail-closed lifecycle hooks versus process-first peers.
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with Deepwork.
* **Avoid If**: You need capabilities Deepwork lacks in the matrix (Atomic flow catalog, Hook-enforced gates).

### Turboshovel (Commercial)

* **Overview**: THIN EVIDENCE — Turboshovel is a seed-level APO commercial candidate. Product URL and capability claims are **unknown/unverified** in this pass; do not treat matrix ticks as observed product behavior.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Managed path**: Commercial offering with vendor-operated components.
  * **Ecosystem momentum**: Active presence in the agentic SDLC orchestration category.
* **Major Cons**:
  * **Hosting burden**: May require self-managed integration for some deployment paths.
  * **Weak hook gates**: Lacks explicit fail-closed lifecycle hooks versus process-first peers.
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with Turboshovel.
* **Avoid If**: You need capabilities Turboshovel lacks in the matrix (Atomic flow catalog, Hook-enforced gates).

### Workflow Manager (Commercial)

* **Overview**: THIN EVIDENCE — Workflow Manager is a seed-level APO commercial candidate. Distinct vendor homepage and capability evidence are **unknown** here; demoted on MQ to Niche Players.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Managed path**: Commercial offering with vendor-operated components.
  * **Ecosystem momentum**: Active presence in the agentic SDLC orchestration category.
* **Major Cons**:
  * **Hosting burden**: May require self-managed integration for some deployment paths.
  * **Weak hook gates**: Lacks explicit fail-closed lifecycle hooks versus process-first peers.
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with Workflow Manager.
* **Avoid If**: You need capabilities Workflow Manager lacks in the matrix (Atomic flow catalog, Hook-enforced gates).

## 6. Agentic Process Orchestrators (APO) — Top Open Source Solutions (5 core)

### [AgentSys](https://github.com/agent-sh/agentsys) (OSS — OSS)

* **Overview**: [AgentSys](https://github.com/agent-sh/agentsys) is a primary-market APO candidate — multi-agent orchestration, process enforcement, specialist routing, multi-phase lifecycle coverage across plan/build/test/review.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Parent/child agent delegation**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Parent/child delegation**: Supported in startup-weighted comparison matrix.
  * **Control & flexibility**: OSS/core deployable on your infrastructure.
* **Major Cons**:
  * **Weak hook gates**: Lacks explicit fail-closed lifecycle hooks versus process-first peers.
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [AgentSys](https://github.com/agent-sh/agentsys).
* **Avoid If**: You need capabilities [AgentSys](https://github.com/agent-sh/agentsys) lacks in the matrix (Atomic flow catalog, Hook-enforced gates).

### [AI-DLC](https://github.com/awslabs/aidlc-workflows) (OSS — OSS)

* **Overview**: AWS [AI-DLC](https://github.com/awslabs/aidlc-workflows) is an open-source methodology (published July 2025; awslabs/aidlc-workflows open-sourced November 2025) structured as Inception → Construction → Operations 'bolts' with mandatory human validation at each step.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Free tier / OSS core**: Supported in startup-weighted comparison matrix.
  * **Prebuilt SDLC templates**: Supported in startup-weighted comparison matrix.
  * **Zero-infra bootstrap**: Supported in startup-weighted comparison matrix.
  * **Control & flexibility**: OSS/core deployable on your infrastructure.
* **Major Cons**:
  * **Weak hook gates**: Lacks explicit fail-closed lifecycle hooks versus process-first peers.
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [AI-DLC](https://github.com/awslabs/aidlc-workflows).
* **Avoid If**: You need capabilities [AI-DLC](https://github.com/awslabs/aidlc-workflows) lacks in the matrix (Atomic flow catalog, Hook-enforced gates).

### Director (OSS — OSS)

* **Overview**: THIN EVIDENCE — Director is a seed-level APO OSS candidate. Canonical product URL was not verified (prior candidate repo 404). Capabilities are **unknown** until a primary source is confirmed; MQ Niche Players.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Skill/plugin marketplace**: Supported in startup-weighted comparison matrix.
  * **Control & flexibility**: OSS/core deployable on your infrastructure.
* **Major Cons**:
  * **Weak hook gates**: Lacks explicit fail-closed lifecycle hooks versus process-first peers.
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with Director.
* **Avoid If**: You need capabilities Director lacks in the matrix (Atomic flow catalog, Hook-enforced gates).

### [MetaGPT](https://github.com/FoundationAgents/MetaGPT) (OSS — OSS)

* **Overview**: [MetaGPT](https://github.com/FoundationAgents/MetaGPT) maps a software-company SOP into role agents (PM/architect/engineer) that produce structured SDLC artifacts from a one-line brief.
* **Major Pros**:
  * **Control & flexibility**: OSS/core deployable on your infrastructure.
  * **Ecosystem momentum**: Active presence in the agentic SDLC orchestration category.
  * **Ecosystem momentum**: Active presence in the agentic SDLC orchestration category.
  * **Ecosystem momentum**: Active presence in the agentic SDLC orchestration category.
* **Major Cons**:
  * **Weak hook gates**: Lacks explicit fail-closed lifecycle hooks versus process-first peers.
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Limited composition**: Workflow composition not credited in comparison matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising agentic SDLC automation with [MetaGPT](https://github.com/FoundationAgents/MetaGPT).
* **Avoid If**: You need capabilities [MetaGPT](https://github.com/FoundationAgents/MetaGPT) lacks in the matrix (unverified gaps).

### [Silver Bullet](https://sb.alolabs.dev/) (OSS — OSS)

* **Overview**: [Silver Bullet](https://sb.alolabs.dev/) is an open-source Agentic Process Orchestrator — a process layer inside [Cursor](https://cursor.com/), [Codex](https://openai.com/codex/), and [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) that composes workflows, enforces hook gates, and records skills.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Atomic flow catalog**: Supported in startup-weighted comparison matrix.
  * **Parent/child agent delegation**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **Quick onboarding**: Supported in startup-weighted comparison matrix.
  * **Control & flexibility**: OSS/core deployable on your infrastructure.
* **Major Cons**:
  * **Operational depth**: Requires agent-ops maturity to realise full value.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [Silver Bullet](https://sb.alolabs.dev/).
* **Avoid If**: You need capabilities [Silver Bullet](https://sb.alolabs.dev/) lacks in the matrix (Predictable pricing, Managed hosting).

## 7. SDLC Plugins & Methodology Packs — Top Open Source Solutions (9 core + 1 quarantined)

### [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD) (OSS — OSS)

* **Overview**: [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD) is MIT-licensed, bring-your-own-model, and had approached ~49k GitHub stars — the highest-distribution OSS substitute in the secondary market.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **Quick onboarding**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Skill/plugin marketplace**: Supported in startup-weighted comparison matrix.
  * **Control & flexibility**: OSS/core deployable on your infrastructure.
* **Major Cons**:
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD).
* **Avoid If**: You need capabilities [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD) lacks in the matrix (Atomic flow catalog, Predictable pricing).

### Claude Harness (UNVERIFIED — not anthropics/claude-code)

* **Overview**: UNVERIFIED IDENTITY — Claude Harness is an SDLC-plugins methodology pack (not an APO peer) — [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) wrapper, process enforcement, compliance layer above host, deterministic gates. Distinct Harness homepage/repo was not verified; do not use anthropics/claude-code as this product’s canonical URL.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Free tier / OSS core**: Supported in startup-weighted comparison matrix.
  * **Control & flexibility**: OSS/core deployable on your infrastructure.
* **Major Cons**:
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with Claude Harness.
* **Avoid If**: You need capabilities Claude Harness lacks in the matrix (Atomic flow catalog, Predictable pricing).

### GSD (Get Shit Done) (OSS — OSS)

* **Overview**: GSD (Get Shit Done) is a [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) meta-prompting / spec-driven system for structured agent delivery loops.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **Quick onboarding**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Skill/plugin marketplace**: Supported in startup-weighted comparison matrix.
  * **Control & flexibility**: OSS/core deployable on your infrastructure.
* **Major Cons**:
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with GSD (Get Shit Done).
* **Avoid If**: You need capabilities GSD (Get Shit Done) lacks in the matrix (Atomic flow catalog, Predictable pricing).

### Oh My Pi (OMP) (OSS — OSS)

* **Overview**: Oh My Pi (OMP) is a host-integrated plugin pack; satisfies plugin/skill/hook packaging + process layer above host runtime. Lifecycle coverage narrower than BMAD/[Superpowers](https://github.com/obra/superpowers).
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Parent/child agent delegation**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **Quick onboarding**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Control & flexibility**: OSS/core deployable on your infrastructure.
* **Major Cons**:
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with Oh My Pi (OMP).
* **Avoid If**: You need capabilities Oh My Pi (OMP) lacks in the matrix (Atomic flow catalog, Predictable pricing).

### [Ruflo (formerly Claude Flow)](https://github.com/ruvnet/ruflo) (OSS — OSS)

* **Overview**: **Naming:** Ruflo is the current project name; Claude Flow is the prior name (same ruvnet line — not two unrelated products). Ruflo packages the SPARC methodology — Specification, Pseudocode, Architecture, Refinement, Completion — as a test-driven process layer over [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview).
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Parent/child agent delegation**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Skill/plugin marketplace**: Supported in startup-weighted comparison matrix.
  * **Control & flexibility**: OSS/core deployable on your infrastructure.
* **Major Cons**:
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [Ruflo (formerly Claude Flow)](https://github.com/ruvnet/ruflo).
* **Avoid If**: You need capabilities [Ruflo (formerly Claude Flow)](https://github.com/ruvnet/ruflo) lacks in the matrix (Atomic flow catalog, Predictable pricing).

### [Silver Bullet](https://sb.alolabs.dev/) (OSS — OSS)

* **Overview**: [Silver Bullet](https://sb.alolabs.dev/) is an open-source Agentic Process Orchestrator — a process layer inside [Cursor](https://cursor.com/), [Codex](https://openai.com/codex/), and [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) that composes workflows, enforces hook gates, and records skills.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Atomic flow catalog**: Supported in startup-weighted comparison matrix.
  * **Parent/child agent delegation**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **Quick onboarding**: Supported in startup-weighted comparison matrix.
  * **Control & flexibility**: OSS/core deployable on your infrastructure.
* **Major Cons**:
  * **Operational depth**: Requires agent-ops maturity to realise full value.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [Silver Bullet](https://sb.alolabs.dev/).
* **Avoid If**: You need capabilities [Silver Bullet](https://sb.alolabs.dev/) lacks in the matrix (Predictable pricing, Managed hosting).

### GitHub Spec Kit (OSS — OSS)

* **Overview**: [GitHub spec-kit](https://github.com/github/spec-kit) makes specifications executable via constitution.md principles and spec-driven development workflows.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Skill/plugin marketplace**: Supported in startup-weighted comparison matrix.
  * **Free tier / OSS core**: Supported in startup-weighted comparison matrix.
  * **Control & flexibility**: OSS/core deployable on your infrastructure.
* **Major Cons**:
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with GitHub Spec Kit.
* **Avoid If**: You need capabilities GitHub Spec Kit lacks in the matrix (Atomic flow catalog, Predictable pricing).

### [SuperClaude](https://github.com/SuperClaude-Org/SuperClaude_Framework) (OSS — OSS)

* **Overview**: [SuperClaude](https://github.com/SuperClaude-Org/SuperClaude_Framework) provides config + skill layers (flags, modes, agent personas) for [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview); satisfies plugin/skill/hook packaging + process layer above host runtime. Mostly configuration rather than enforced gates — partial on deterministic quality gates.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Skill/plugin marketplace**: Supported in startup-weighted comparison matrix.
  * **Free tier / OSS core**: Supported in startup-weighted comparison matrix.
  * **Control & flexibility**: OSS/core deployable on your infrastructure.
* **Major Cons**:
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [SuperClaude](https://github.com/SuperClaude-Org/SuperClaude_Framework).
* **Avoid If**: You need capabilities [SuperClaude](https://github.com/SuperClaude-Org/SuperClaude_Framework) lacks in the matrix (Atomic flow catalog, Predictable pricing).

### [Superpowers](https://github.com/obra/superpowers) (OSS — OSS)

* **Overview**: [Superpowers](https://github.com/obra/superpowers) (Jesse Vincent / obra) installs a composable skills framework into [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) covering brainstorming, design, plan-writing, TDD, systematic debugging, subagent-driven development with built-in code review, and skill authoring — multi-phase multi-phase lifecycle coverage in plugin packaging.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Skill/plugin marketplace**: Supported in startup-weighted comparison matrix.
  * **Free tier / OSS core**: Supported in startup-weighted comparison matrix.
  * **Control & flexibility**: OSS/core deployable on your infrastructure.
* **Major Cons**:
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [Superpowers](https://github.com/obra/superpowers).
* **Avoid If**: You need capabilities [Superpowers](https://github.com/obra/superpowers) lacks in the matrix (Atomic flow catalog, Predictable pricing).

### Zuvo (QUARANTINED / WATCHLIST — identity unverified)

* **Overview**: QUARANTINED: Zuvo could not be corroborated by open web search in this retrieval pass. Removed from sdlc-plugins MQ/Wave/Leader plots until a primary repo/license file is verified. Pack URL https://zuvo.dev/ remains unverified.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Parent/child agent delegation**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Skill/plugin marketplace**: Supported in startup-weighted comparison matrix.
  * **Control & flexibility**: OSS/core deployable on your infrastructure.
* **Major Cons**:
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: Not recommended for shortlists until identity and license are verified.
* **Avoid If**: Any procurement use-case — treat as watchlist only.

## 8. Agentic SDLC SaaS & Autonomous Delivery — Top Commercial Solutions (5 core)

### Augment Code (Cosmos) (Commercial)

* **Overview**: **Naming:** public brand is **Augment Code**; Cosmos is an Augment agentic SDLC surface (not a separate standalone vendor). Self-describes as an operating system for agentic software development with agents in customer env or Augment cloud.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Parent/child agent delegation**: Supported in startup-weighted comparison matrix.
  * **Quick onboarding**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Managed hosting**: Supported in startup-weighted comparison matrix.
  * **Managed path**: Commercial offering with vendor-operated components.
* **Major Cons**:
  * **Weak hook gates**: Lacks explicit fail-closed lifecycle hooks versus process-first peers.
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with Augment Code (Cosmos).
* **Avoid If**: You need capabilities Augment Code (Cosmos) lacks in the matrix (Atomic flow catalog, Hook-enforced gates).

### Devin (Commercial)

* **Overview**: Devin is Cognition's autonomous software engineer that plans, implements, tests, and ships code via pull requests in customer repositories.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Quick onboarding**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Predictable pricing**: Supported in startup-weighted comparison matrix.
  * **Free tier / OSS core**: Supported in startup-weighted comparison matrix.
  * **Managed path**: Commercial offering with vendor-operated components.
* **Major Cons**:
  * **Weak hook gates**: Lacks explicit fail-closed lifecycle hooks versus process-first peers.
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with Devin.
* **Avoid If**: You need capabilities Devin lacks in the matrix (Atomic flow catalog, Hook-enforced gates).

### [Factory.ai](https://www.factory.ai/) (Commercial)

* **Overview**: [Factory.ai](https://www.factory.ai/) provides managed Droids with workflow composition, parent/child delegation, review loops, and cloud hosting for agentic software delivery.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Parent/child agent delegation**: Supported in startup-weighted comparison matrix.
  * **Quick onboarding**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Managed hosting**: Supported in startup-weighted comparison matrix.
  * **Managed path**: Commercial offering with vendor-operated components.
* **Major Cons**:
  * **Weak hook gates**: Lacks explicit fail-closed lifecycle hooks versus process-first peers.
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [Factory.ai](https://www.factory.ai/).
* **Avoid If**: You need capabilities [Factory.ai](https://www.factory.ai/) lacks in the matrix (Atomic flow catalog, Hook-enforced gates).

### [Magic.dev](https://magic.dev/) (Commercial)

* **Overview**: [Magic.dev](https://magic.dev/) builds long-context coding models and agents aimed at large-repo autonomous engineering tasks.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Managed hosting**: Supported in startup-weighted comparison matrix.
  * **Managed path**: Commercial offering with vendor-operated components.
* **Major Cons**:
  * **Weak hook gates**: Lacks explicit fail-closed lifecycle hooks versus process-first peers.
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [Magic.dev](https://magic.dev/).
* **Avoid If**: You need capabilities [Magic.dev](https://magic.dev/) lacks in the matrix (Atomic flow catalog, Hook-enforced gates).

### [Tembo](https://tembo.io/) (Commercial)

* **Overview**: **IDENTITY RISK:** [tembo.io](https://tembo.io/) is widely known as a **Postgres platform**. This report’s agentic-SDLC-SaaS placement is provisional — confirm a distinct agent/SDLC product surface before procurement use. Prior “cloud agents across repos” copy is **unverified** for the Postgres brand collision.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Parent/child agent delegation**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Managed hosting**: Supported in startup-weighted comparison matrix.
  * **Parent/child delegation**: Supported in startup-weighted comparison matrix.
  * **Managed path**: Commercial offering with vendor-operated components.
* **Major Cons**:
  * **Weak hook gates**: Lacks explicit fail-closed lifecycle hooks versus process-first peers.
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [Tembo](https://tembo.io/).
* **Avoid If**: You need capabilities [Tembo](https://tembo.io/) lacks in the matrix (Atomic flow catalog, Hook-enforced gates).

## 9. Adjacent Markets (not core peers)

Products below are relevant context for the **primary APO** lens and are **not** plotted on the primary-market MQ/Wave. Host runtimes that are **core in the tertiary SaaS market** (e.g. Devin) remain scored there; do not read this adjacent list as a global unscored ban.

- **[AxonFlow](https://www.axonflow.ai/)** (`axonflow`) — pack adjacent_seed
- **Cavekit v4** (`cavekit-v4`) — pack adjacent_seed
- **[Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview)** (`claude-code`) — pack adjacent_seed
- **[Codex](https://openai.com/codex/)** (`codex`) — pack adjacent_seed
- **[Cognition Scout](https://cognition.ai/)** (`cognition-scout`) — pack adjacent_seed
- **[Conductor](https://conductor.build/)** (`conductor`) — pack adjacent_seed
- **[CrewAI](https://github.com/crewAIInc/crewAI)** (`crewai`) — pack adjacent_seed
- **[Cursor](https://cursor.com/)** (`cursor`) — pack adjacent_seed
- **GitHub Copilot** (`github-copilot`) — pack adjacent_seed
- **[LangChain](https://github.com/langchain-ai/langchain)** (`langchain`) — pack adjacent_seed
- **LangGraph** (`langgraph`) — pack adjacent_seed
- **[Replit Agent](https://replit.com/)** (`replit-agent`) — pack adjacent_seed

## 10. Explicitly Excluded

- **Aider** — pack hard_exclusion (coding_agent)
- **Amazon Q Developer** — hard_veto from need_profile
- **Claude Code Expert** — pack hard_exclusion (sunset)
- **Cline** — pack hard_exclusion (coding_agent)
- **CodeRabbit** — hard_veto from need_profile
- **Continue** — pack hard_exclusion (coding_agent)
- **Cursor Background Agents** — hard_veto from need_profile
- **GitHub Copilot Enterprise** — pack hard_exclusion (coding_agent)
- **JetBrains AI Assistant** — hard_veto from need_profile
- **Linear** — pack hard_exclusion (project_management)
- **Open Interpreter** — pack hard_exclusion (coding_agent)
- **OpenHands** — pack hard_exclusion (coding_agent)
- **Poolside** — hard_veto from need_profile
- **Sourcegraph Cody** — hard_veto from need_profile
- **SWE-agent** — pack hard_exclusion (coding_agent)
- **Sweep** — hard_veto from need_profile
- **Windsurf** — hard_veto from need_profile
- **AgentGPT** — Abandoned / non-production
- **AutoGen** — Microsoft shifted to Agent Framework; legacy status
- **GitHub Copilot Workspace** — Discontinued by GitHub
- **Devika** — Project discontinued

**Coverage gaps / quarantine**

- **Zuvo** — quarantined from sdlc-plugins core MQ/Wave/Leader plots (identity/OSS unverified). Listed as watchlist only; not a “missing envelope” while still scored as Leader.

## 11. Buying Guidance & Shortlist Profiles

**How to use this section:** pick a **product shape** first, then score against criteria. Silver Bullet appears in APO/plugin charts and is authored here — apply the COI disclosure; do not treat SB as the default winner without your own evaluation.

### Product shapes (separate purchase objects)

| Shape | What you buy | Examples in this report | Do not confuse with |
|-------|--------------|-------------------------|---------------------|
| **Host runtime / IDE agent** | Execution environment | Cursor, Claude Code, Copilot (adjacent) | Process orchestration packs |
| **Autonomous SDLC SaaS** | Hosted plan→ship agents | Devin, Factory.ai, Augment Code (Cosmos) | Method packs you install on a host |
| **Method / plugin pack** | Skills, SPARC/BMAD/GSD workflows on a host | BMAD, GSD, Ruflo, Spec Kit, Superpowers | Full APO compliance layers |
| **Programmable framework** | Libraries to build agents | LangGraph, CrewAI, AutoGen/AG2 (adjacent/excluded) | Turnkey SDLC process products |
| **APO process layer** | Catalog + gates above hosts | Silver Bullet, AI-DLC, AgentHub (varying evidence) | Bare host copilots |

### Criteria-first shortlists (illustrative — not ranked winners)

- **Process-first startup (APO shape):** require workflow composition + atomic catalog + hook/gate evidence. Evaluate OSS and commercial APO cores against the matrix; **exclude thin-evidence Niche seeds** (Deepwork, Turboshovel, Workflow Manager, Director, Barkain, Cavekit) from shortlists until primary docs exist.
- **Open-source method pack on an existing host:** BMAD, GSD, Spec Kit, Ruflo, Superpowers — score install path, maintenance, and gate depth; Claude Harness is **unverified**.
- **Autonomous SaaS delivery:** Devin and Factory.ai are the clearer Leaders in this pass’s SaaS MQ; Augment Code (Cosmos), Magic.dev, and Tembo are Visionaries / provisional — verify Tembo identity before RFP.
- **Host-runtime path:** buy a host (Cursor / Claude Code / Copilot) **plus** a separate APO or method pack — do not expect the host alone to satisfy process orchestration.

### Procurement evidence gaps (explicit)

This landscape does **not** yet include verified pricing, adoption metrics, SSO/SCIM, residency, BYOK, VPC, SLA, or portability evidence sufficient for security procurement. Treat § comparison ticks as feature-envelope research, not a compliance attestation.


## 12. Future Outlook & Emerging Disruptors

### [Silver Bullet](https://sb.alolabs.dev/) (OSS — Open Source)

* **Overview**: [Silver Bullet](https://sb.alolabs.dev/) is an open-source Agentic Process Orchestrator — a process layer inside [Cursor](https://cursor.com/), [Codex](https://openai.com/codex/), and [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) that composes workflows, enforces hook gates, and records skills.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Atomic flow catalog**: Supported in startup-weighted comparison matrix.
  * **Parent/child agent delegation**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **Quick onboarding**: Supported in startup-weighted comparison matrix.
  * **Control & flexibility**: OSS/core deployable on your infrastructure.
* **Major Cons**:
  * **Operational depth**: Requires agent-ops maturity to realise full value.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [Silver Bullet](https://sb.alolabs.dev/).
* **Avoid If**: You need capabilities [Silver Bullet](https://sb.alolabs.dev/) lacks in the matrix (Predictable pricing, Managed hosting).

### Router-first APO catalogs
- Process routers with Authorizer trust and nested V-loops may become default SB-style differentiators. **SMB implication**: Threatens executor-only agents.

### Multi-model triangulation as a buying step
- Consensus/divergence synthesis becomes part of procurement for niche categories. **SMB implication**: Advantages transparency-first vendors.

### Consolidation of git-native agents
- Issue→PR agents may merge with SDLC orchestration platforms. **SMB implication**: Threatens point tools without ecosystem depth.

## 13. Source Reliability Assessment

### Model response weights

| Source | Response Size | Weight Applied | Assessment |
|--------|--------------|----------------|------------|
| claude-opus-4.8-medium | 40906 chars | **Heavy—Primary** | Highest-effort frontier critique/research lane; preferred over flash tiers for synthesis judgment. |
| gpt-5.6-luna-medium | 24786 chars | **Good—Secondary** | Structured DR phases; used for triangulation, not sole authority. |
| ocg-minimax-m3 | 32584 chars | **Good—Secondary** | Strong OCG structured critique yield. |
| ocg-qwen3.7-plus | 28591 chars | **Good—Secondary** | Structured OCG findings. |
| ocg-kimi-k2.7-code | 21675 chars | **Good—Secondary** | Structured OCG findings. |
| ocg-mimo-v2.5 | 25338 chars | **Supporting** | Partial/truncated parse in critique pass — do not overweight. |
| ocg-deepseek-v4-flash | 26086 chars | **Supporting** | Flash-tier — useful for coverage, not primary reliability. |
| gemini-3.5-flash | 30489 chars | **Supporting** | Flash-tier; **character count is not a reliability method** — previously overweight; demoted. |

**Weighting rule (this revision):** model tier / structured-critique usefulness first; response length is informational only. Flash models are Supporting, not Primary.

**Security / procurement evidence:** contributors did not supply SSO/SCIM, residency, BYOK, VPC, SLA, or pricing packs. Absence is an **evidence gap**, not a claim that vendors lack those controls.


**Consensus patterns**: No cross-family consensus claims in triangulation — see divergence.

**Notable divergences**:
- Generic agent frameworks (LangGraph, [CrewAI](https://github.com/crewAIInc/crewAI), [LangChain](https://github.com/langchain-ai/langchain), [AxonFlow](https://www.axonflow.ai/), Cavekit v4) are designated as adjacent-only and must be excluded from primary APO comparison matrices. **MetaGPT remains APO OSS core** (Niche Players in MQ) per membership — do not also label it adjacent-only.
- [AI-DLC](https://github.com/awslabs/aidlc-workflows) (AWS / awslabs) is the weakest APO core seed by enforcement depth: it defines a conceptual lifecycle for methodology guidance without shipping deterministic gates, cross-session state, or host-integrated plugin packaging. It belongs in the APO market per inclusion criteria §Multi-phase lifecycle span alone but ranks below all shipped products.
- [Factory.ai](https://www.factory.ai/), Devin, Augment Code (Cosmos), [Tembo](https://tembo.io/), [Magic.dev](https://magic.dev/), and [Cognition Scout](https://cognition.ai/) represent the tertiary market (agentic SDLC SaaS and autonomous delivery) peers. Devin implements an autonomous plan-verify-ship loop, [Factory.ai](https://www.factory.ai/) uses specialized Droids for lifecycle phases, and Augment Code (Cosmos) leverages a dedicated context engine, matching the behavioral criteria of process orchestrators even without using the APO label.
- SDLC plugin secondary market (BMAD, GSD, [Superpowers](https://github.com/obra/superpowers), GitHub Spec Kit, Oh My plugins, Zuvo (quarantined/unverified), [SuperClaude](https://github.com/SuperClaude-Org/SuperClaude_Framework), Ruflo) represents the most credible APO substitution threat: each enforces a partial lifecycle span with methodology-specific gates, but none provides cross-session persistent state, deterministic hook enforcement, or specialist agent orchestration within a single package.
- The primary APO market is structurally immature: most named seeds (Turboshovel, [Cavekit v3.1](https://cavekit.ai/), [Barkain Workflow Orchestrator](https://barkain.com/), [cc10x](https://cc10x.dev/), Director, [AgentHub](https://www.agenthub.ai/), [ATeam](https://www.a.team/), Claude Harness) are single-maintainer OSS packs without pricing, SLAs, or enterprise governance, meaning competition is on process depth and host-compatibility rather than commercial moat.
- No APO product except [Silver Bullet](https://sb.alolabs.dev/) provides verifiable cross-session memory persistence (agentmemory, FTS5 knowledge base, observation audit trail) as a process-orchestration primitive. [Cavekit v3.1](https://cavekit.ai/) claim workflow state only; Factory and Devin retain session context within a single cloud workspace but do not surface it as a reusable gate-check artifact.
- Cross-session state persistence is the most under-served inclusion criterion across the secondary market: most methodology packs rely on markdown artifacts re-read per session rather than an enforced state machine keyed to branch or worktree identity.
- [Cursor](https://cursor.com/), [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview), [Codex](https://openai.com/codex/), and GitHub Copilot are classified strictly as host runtimes under the exclusion contract and must be mapped as adjacent peers rather than primary process orchestrators. Additionally, point solutions like Sweep, Windsurf, Amazon Q, Sourcegraph Cody, CodeRabbit, OpenHands, Cline, Continue, Aider, and SWE-agent are hard-excluded as single-SDLC-step tools or coding agents.