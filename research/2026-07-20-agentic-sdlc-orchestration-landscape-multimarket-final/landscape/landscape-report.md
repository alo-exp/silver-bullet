# Agentic SDLC Process Orchestrators Market Landscape Report

*Analyst-grade landscape analysis for SMB decision-makers*

Knowledge basis: Synthesised from multiple AI platform responses (claude-opus-4.8-medium, gemini-3.5-flash, gpt-5.6-luna-medium, ocg-deepseek-v4-flash, ocg-kimi-k2.7-code, ocg-mimo-v2.5, ocg-minimax-m3, ocg-qwen3.7-plus)
August 14, 2026

## Executive Summary

One-page briefing for SMB buyers. Charts and vendor cards follow; this page does not restate coordinate formulas.

### Market overview

Agentic SDLC orchestration sits **one level above coding agents**: process catalogs, gates, and specialist routing rather than raw codegen. Three markets are scored separately — **Agentic Process Orchestrators (APO)** (primary), **SDLC plugins & methodology packs** (secondary), and **agentic SDLC SaaS / autonomous delivery** (tertiary). The category is early mainstream: executor-first hosts are ahead of fail-closed process layers. OSS packs dominate experimentation; commercial SaaS leads managed execution.

### Key findings

- Buyers should shortlist **by market**, not from a single blended ranking.
- Hook-enforced gates plus durable cross-session state remain the scarce combination; most methodology packs are skippable prompt/persona layers.
- Thin-evidence APO commercials (Deepwork, Turboshovel, Workflow Manager) stay on the chart as cores but are not a procurement shortlist on ticks alone.
- Magic.dev is hard-excluded (coding-model lab). Conductor is an aggregator, not APO. This report does not call any vendor 'most complete'.
- [Zuvo](https://zuvo.dev/) is an sdlc-plugins **core** with public evidence (site → MIT GitHub). It is scored and placed with the other plugin cores; it is not a coverage gap.

### Leader shortlist (per market)

- **APO (primary):** [Silver Bullet](https://sb.alolabs.dev/)
- **SDLC plugins & methodology packs:** [Silver Bullet](https://sb.alolabs.dev/) — feature-gate (hooks **and** ledger cross-session), not a 'most complete product' claim
- **Agentic SDLC SaaS:** Devin, [Factory.ai](https://www.factory.ai/), Augment Cosmos

Leader plots are MQ top-right in this run. Plugin MQ Leaders = Silver Bullet only because only Silver Bullet passed hook-enforced gates AND inclusion-ledger cross-session in this run. That is not a mandate to buy one vendor across every profile.

### Buyer guidance

- **Spec-first / lean packs:** equal-standing OSS peers including [Zuvo](https://zuvo.dev/), [Barkain Workflow Orchestrator](https://github.com/barkain/claude-code-workflow-orchestration), [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD), [Cavekit v3.1](https://github.com/JuliusBrussee/cavekit), [cc10x](https://github.com/romiluz13/cc10x), Claude Harness — pick on spec vs persona vs swarm topology.
- **OSS APO cores:** equal-standing peers ([AgentSys](https://github.com/agent-sh/agentsys), [AI-DLC](https://github.com/awslabs/aidlc-workflows), Deepwork, Director, [MetaGPT](https://github.com/FoundationAgents/MetaGPT)); [AI-DLC](https://github.com/awslabs/aidlc-workflows) is AWS/awslabs methodology vocabulary without shipped hook gates (Visionaries, not Wave) — not IBM.
- **Managed autonomous delivery:** Augment Cosmos, Devin, [Factory.ai](https://www.factory.ai/) — this profile does not resolve to an OSS process pack. Magic.dev is not a SaaS-core substitute.
- **Host-runtime path:** [Cursor](https://cursor.com/) / [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) / [Codex](https://openai.com/codex/) **plus a pack**. The host is not the orchestrator.

## 1. Problem

Coding agents execute work; they do not by themselves **enforce** an SDLC. Buyers need a process layer so planning, verification, review, and release cannot be skipped when agents run in parallel or across sessions.

**Primary jobs-to-be-done**

1. Enforce a full SDLC or DevOps cycle so agents cannot skip planning, verification, review, or release steps
2. Compose specialist agents and external workflows (GSD, spec kits, review ladders) under one compliance layer
3. Persist process state, gates, and evidence across sessions and parallel workers
4. Provide procurement-ready comparison of process-orchestration depth vs host runtimes and frameworks

## 2. Market

### Market Definition & Scope

**Landscape scope**

Agentic SDLC orchestration solutions operating **one level above coding agents** — end-to-end, process-driven, workflow-based agentic layers for software engineering and DevOps (SecOps-adjacent). Excludes raw LLM APIs and single-shot copilots.

Research topic: `Agentic SDLC orchestration landscape multimarket final — APO primary, SDLC plugins secondary (BMAD GSD [Superpowers](https://github.com/obra/superpowers) Spec Kit Oh My [Zuvo](https://zuvo.dev/) OSS), agentic SDLC SaaS tertiary (Factory Devin Augment Cosmos)`

**Out of scope (excluded from core peer set)**

- Generic **coding agents** and IDE copilots (Cursor Background Agents, Cline, Aider, Continue, OpenHands, SWE-agent)
- **Host runtimes** that execute code without a process catalog ([Cursor](https://cursor.com/), Copilot, [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview), [Codex](https://openai.com/codex/) as hosts — listed under Adjacent). Devin is agentic-sdlc-saas core, not a host-runtime adjacent.
- **Single-step** tools (PR review bots, PM integrations such as Linear)
- **Generic agent frameworks** without SDLC process packaging (LangGraph, [CrewAI](https://github.com/crewAIInc/crewAI) as adjacent)
- **Sunset** products (GitHub Copilot Workspace, AutoGen, AgentGPT, Devika)

### Market Overview

As of July 2026, the category is **early mainstream**: buyers separate agent hosts from process layers, but few vendors combine machine-readable catalogs with hook-enforced gates.
Verify latest data — market size estimates for agentic SDLC orchestration are not web-verified in this synthesis; growth is driven by multi-agent adoption and verification-gate demand.

- **Maturity**: Early mainstream; executor-first agents are ahead of process catalogs.
- **Commercial vs OSS**: OSS frameworks dominate experimentation; commercial players lead managed execution.
- **SMB vs enterprise**: SMBs favour templates, predictable pricing, and managed hosting; enterprises prioritise audit, SSO, and residency.
- **Deployment**: SaaS agents, IDE plugins, and self-hosted OSS graphs coexist; switching costs rise with hook and catalog lock-in.

### Key Industry Trends

#### Process-first orchestration above coding agents
- **What**: Buyers increasingly separate the agent host (IDE, cloud sandbox) from the SDLC process layer that composes workflows, enforces gates, and records skills.
- **SMB impact**: SMBs without platform teams need opinionated process packs rather than bespoke agent graphs.
- **Vendor response**: [Silver Bullet](https://sb.alolabs.dev/), [Factory.ai](https://www.factory.ai/), and GitHub Copilot Workspace market explicit SDLC chains; [Cursor](https://cursor.com/) and Devin remain executor-first.

#### Hook-enforced lifecycle gates
- **What**: Host hooks that fail closed on skill recording, planning ownership, and delivery gates are emerging as trust rails for autonomous work.
- **SMB impact**: Reduces rework risk when junior teams delegate multi-step agent runs.
- **Vendor response**: [Silver Bullet](https://sb.alolabs.dev/) and [Cursor](https://cursor.com/) document hook layers; most git-native agents lack cross-host gate parity.

#### Machine-readable workflow catalogs
- **What**: Atomic flow catalogs (workflows, steps, V-loops) enable composition, audit, and CI freshness checks beyond ad-hoc prompts.
- **SMB impact**: Lets lean teams adopt SDLC patterns without writing orchestration code.
- **Vendor response**: [Silver Bullet](https://sb.alolabs.dev/) ships `apo-catalog.json`; spec-kit and GSD offer lighter-weight spec packs.

#### Git-native issue→PR agent loops
- **What**: Issue trackers and repos become control planes for multi-step agent work with human review on PRs.
- **SMB impact**: Fits teams already on GitHub; lowers integration tax versus custom runtimes.
- **Vendor response**: GitHub Copilot Workspace, Sweep, and [Tembo](https://tembo.io/) target this pattern.

#### Autonomous software engineers (plan→ship)
- **What**: Managed agents that plan, implement, test, and open PRs in customer repos are maturing for enterprise pilots.
- **SMB impact**: High capability but opaque process; pricing and governance remain enterprise-weighted.
- **Vendor response**: Devin and [Factory.ai](https://www.factory.ai/) Droids compete here; Magic.dev is a coding-model lab, not a scored SaaS-core peer.

#### BYO agent runtimes and graph orchestration
- **What**: Frameworks expose durable graphs, interrupts, and delegation primitives for custom orchestration.
- **SMB impact**: Maximum flexibility at the cost of in-house agent ops expertise.
- **Vendor response**: [LangGraph Platform](https://www.langchain.com/langgraph), [CrewAI](https://github.com/crewAIInc/crewAI), and AutoGen anchor this segment; [MetaGPT](https://github.com/FoundationAgents/MetaGPT) is scored as APO OSS core, not a generic framework adjacent.

#### Spec-driven and context-engineering workflows
- **What**: Lightweight methodology packs emphasize intent specs, critique loops, and context hygiene before code.
- **SMB impact**: Low-cost entry for teams not ready for full orchestration platforms.
- **Vendor response**: GitHub spec-kit, GSD, and [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD) are representative.

#### Multi-model pools and triangulated research
- **What**: This research pass triangulates multiple model families with explicit divergence tracking. That is a report method — not a product feature vendors were scored on.
- **SMB impact**: Use triangulation to interrogate marketing claims; do not treat it as a matrix tick.
- **Vendor response**: Not a scored MQ/Wave/matrix axis in this engine; see scoring methodology.

## 3. Framework

### Inclusion criteria

A vendor belongs in the **core peer set** when it clearly demonstrates at least **3 of 7** capabilities below (not advisory-only claims):

- **Multi-phase lifecycle span** — Covers two or more of plan/spec, build, test, review, release, or DevOps operations as an integrated process — not a single-shot codegen or review-only tool.
- **Plugin / skill / hook packaging** — Ships as host-integrated packaging (Claude/[Codex](https://openai.com/codex/)/[Cursor](https://cursor.com/) plugin, skill bundle, hook layer, or equivalent) rather than a standalone IDE or raw API.
- **Deterministic quality gates** — Uses machine-checkable gates (hooks, audits, stop-checks, CI integration) that block progression when criteria fail.
- **Cross-session state** — Persists workflow state, memory, or runbooks across agent clears, sessions, or parallel workers.
- **Specialist agent orchestration** — Routes work to named specialist agents, hats, or role-specific subagents — not a single monolithic agent.
- **Quality / release enforcement claim** — Publicly claims enforcement of quality, compliance, release, or governance — not advisory-only suggestions.
- **Process layer above host runtime** — Positions as a meta-orchestrator or compliance wrapper above [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview), [Codex](https://openai.com/codex/), [Cursor](https://cursor.com/), or similar — not as the host runtime itself.

### Scoring methodology

Charts answer **which evidenced capabilities a vendor has**, not a 100-point brand score and not a 'most complete product' ranking. Every plotted number is reproducible from the comparison matrix in this report ([comparison.json](../comparison/comparison.json)). `solutions/<slug>/features.json` is the machine copy of those same ticks — not a hidden feature set.

**1. Comparison-matrix ranking (buyer: weighted capability depth).** Each matrix row has a priority. A ✔ adds that row's points; an empty cell adds 0. This is the MultAI comparator, **not** a TopGun 55/20/15/10 blend:

- Critical = **5** · Very High = **4** · High = **3** · Medium = **2** · Low = **1**
- Ranking score = sum of (priority points × 1 if ticked). Stored as `comparison.rankings[].score`.

**2. Chart coordinates (buyer: process depth vs execute depth).** Each axis uses a short feature list (the buyer-priority capabilities for that market), not the full matrix. For each axis:

1. **Floor** — where a vendor with zero axis ticks still sits so they remain visible.
2. **Tick points** — each evidenced axis feature adds a fixed number of chart points (points-per-tick). That is the weight: how much one capability moves the plot.
3. **Ranking remainder** — `ranking_score ÷ spread`. Spread is **how many ranking points equal 1.0 chart unit**, so two vendors with the same axis ticks still separate slightly by overall matrix depth. Example: spread 15 means a 15-point ranking gap moves that axis by 1.0.
4. **Caps** — Leader eligibility and methodology-without-gates can lower an axis; they never invent ticks.
5. **Collision slotting** — if two vendors would share an X or a Y at one decimal place, a deterministic 0.1-step walk takes the nearest free slot inside the chart bounds. Rank order of the true scores is preserved. This is collision avoidance, **not a score and not random jitter**. The engine does not apply jitter amplitudes (±0.28 / ±0.34 / ±0.36 are gone).

Positioning Matrix (3A) X = process / offering depth; Y = execute / operations. Magic Quadrant (3B) X = Completeness of Vision; Y = Ability to Execute. Quadrants split at **5.5 / 5.5** (Leaders top-right).

**3. Wave (3C).** Current Offering = floor 1.5 + ranking_score/10, cap 4 (matrix depth as current product). Strength of Strategy starts at 1.0, adds the weighted feature ticks below, then small SCR-text bonuses (multi-host 0.10/0.25, OSS license 0.20, marketplace/ecosystem 0.15, roadmap 0.10, bonus cap +0.55), then cap 4 — **not** `1.2 + count(Workflow, Atomic)`. Market Presence = `int(1 + ranking_score/8)`, cap 4, then cap 3 without Managed hosting. Packs that fail Leader eligibility are capped to presence ≤ 2 / offering ≤ 2.4 / strategy ≤ 2.5. Methodology-without-gates seeds are **omitted from Wave**.

**Strategy feature weights (points added when the matrix ticks that feature):** Atomic flow catalog +0.55; Skill/plugin marketplace +0.40; Prebuilt SDLC templates +0.35; Free tier / OSS core +0.30; Hook-enforced gates +0.30; Automated review loops +0.30; Parent/child delegation +0.30; Managed hosting +0.25; Visual/E2E verification +0.25; IDE-native integration +0.20; Zero-infra bootstrap +0.20; CI integration +0.20; Predictable pricing +0.20; Per-seat transparency +0.15; Self-serve signup +0.15; Workflow composition +0.15; Quick onboarding +0.10.

**4. Blue Ocean (3D).** Leaders only. A factor is plotted only when at least one Leader has matrix evidence. True = 5, otherwise 1. Unmanaged OSS hosting is not plotted as a flat factor when no Leader has hosting. Zero-infra bootstrap is **not** treated as Managed hosting.

**Leader eligibility.** SDLC plugins need hook-enforced gates **and** inclusion-ledger cross-session pass. APO seeds without shipped hook gates cannot occupy Leaders. Plugin MQ Leaders = Silver Bullet only in this run is that feature-gate fact — not a 'most complete product' claim.

**Hard-exclusion membership.** A slug on the pack hard-exclusion list (Magic.dev as `coding_agent`; A.Team as professional services) has **one** membership — excluded. It is not a core, not an MQ/Wave point, and not a comparison-matrix column. Contributing-model seed lists that re-include it are envelope quotes / model error, not membership.

**Not scored.** Multi-model triangulation, brand reputation, and COI. Triangulation is a research method for this document; vendors were not graded on it. This report does not call any vendor 'most complete'.

Matrix rows in this run (the ranking uses these priorities; chart axes use the short feature lists in the rubric table, not every row as an axis tick):

- **Critical (5 pts per ✔)**: Workflow composition, Self-serve signup, Quick onboarding, Managed hosting, Prebuilt SDLC templates, Zero-infra bootstrap
- **Very High (4 pts per ✔)**: Predictable pricing, Free tier / OSS core, Per-seat transparency
- **High (3 pts per ✔)**: IDE-native integration, Skill/plugin marketplace
- **Medium (2 pts per ✔)**: Atomic flow catalog, Parent/child agent delegation, Hook-enforced gates, Automated review loops, CI integration, Visual/E2E verification, SSO, RBAC, Audit log

| Market | Chart | Axis | Buyer meaning | Axis features (1 tick each) | Floor | Points per tick | Ranking spread (pts → 1.0 chart) |
|---|---|---|---|---|---|---|---|
| Agentic Process Orchestrators (APO) | 3A Positioning | X | Process / offering depth | Workflow composition, Atomic flow catalog, Hook-enforced gates | 3.0 | 2.2 | 15.0 |
| Agentic Process Orchestrators (APO) | 3A Positioning | Y | Execute / operations depth | Parent/child delegation, Managed hosting, Prebuilt SDLC templates | 3.0 | 2.0 | 18.0 |
| Agentic Process Orchestrators (APO) | 3B Magic Quadrant | X | Completeness of Vision | Workflow composition, Atomic flow catalog, Prebuilt SDLC templates, Free tier / OSS core | 2.5 | 1.6 | 12.0 |
| Agentic Process Orchestrators (APO) | 3B Magic Quadrant | Y | Ability to Execute | Parent/child delegation, Managed hosting, CI integration, Hook-enforced gates, IDE-native integration | 2.5 | 1.35 | 14.0 |
| SDLC Plugins & Methodology Packs | 3A Positioning | X | Process / offering depth | Workflow composition, Prebuilt SDLC templates, Hook-enforced gates | 3.4 | 1.55 | 14.0 |
| SDLC Plugins & Methodology Packs | 3A Positioning | Y | Execute / operations depth | Atomic flow catalog, Parent/child delegation, Managed hosting | 2.4 | 1.9 | 12.0 |
| SDLC Plugins & Methodology Packs | 3B Magic Quadrant | X | Completeness of Vision | Prebuilt SDLC templates, Atomic flow catalog, Free tier / OSS core, Skill/plugin marketplace | 2.8 | 1.45 | 13.0 |
| SDLC Plugins & Methodology Packs | 3B Magic Quadrant | Y | Ability to Execute | Parent/child delegation, Atomic flow catalog, Managed hosting, Quick onboarding | 2.3 | 1.5 | 15.0 |
| Agentic SDLC SaaS & Autonomous Delivery | 3A Positioning | X | Process / offering depth | Workflow composition, Managed hosting, Parent/child delegation | 3.3 | 2.05 | 14.0 |
| Agentic SDLC SaaS & Autonomous Delivery | 3A Positioning | Y | Execute / operations depth | Hook-enforced gates, CI integration, IDE-native integration | 2.8 | 2.15 | 16.5 |
| Agentic SDLC SaaS & Autonomous Delivery | 3B Magic Quadrant | X | Completeness of Vision | Managed hosting, Workflow composition, Parent/child delegation, Prebuilt SDLC templates | 2.2 | 1.7 | 11.5 |
| Agentic SDLC SaaS & Autonomous Delivery | 3B Magic Quadrant | Y | Ability to Execute | CI integration, Hook-enforced gates, IDE-native integration, Automated review loops, Zero-infra bootstrap | 2.9 | 1.25 | 13.5 |

Worked identity: `axis = floor + (count of those axis ticks × points-per-tick) + (ranking_score ÷ spread)`, then clamp to [1.0, 9.5], then collision-slot unique X and unique Y at 0.1. No jitter term.

### Multi-market membership

A solution **may** compete in more than one market. That is not a contradiction.

- **[Silver Bullet](https://sb.alolabs.dev/)** is core in **APO ∩ sdlc-plugins**: APO because it ships a process catalog, hook-enforced gates, and cross-session state; sdlc-plugins because it is also host-plugin packaging. Plugin MQ Leaders = Silver Bullet only is the hooks+ledger feature-gate, not a completeness ranking.
- **Devin** is agentic-sdlc-saas **core**, not a host-runtime adjacent.
- **[AgentHub](https://www.agenthub.ai/)** is APO-adjacent CRM, not an APO Leader.
- **[Conductor](https://conductor.build/)** is a SaaS-adjacent aggregator, not APO. Claude Harness is an sdlc-plugins core (host plugins), not APO. There is no "Claude Code Expert" product in this peer set (hard-excluded sunset).
- **[Tembo](https://tembo.io/)** is SaaS-adjacent and unplotted.
- **[AI-DLC](https://github.com/awslabs/aidlc-workflows)** is AWS/awslabs (not IBM): methodology-without-gates, Visionaries on MQ, omitted from APO Wave.
- **[MetaGPT](https://github.com/FoundationAgents/MetaGPT)** is APO OSS core (not a generic-framework adjacent).

### Vendor inclusion ledger

3-of-7 inclusion rule applied **per market**. Cells: **P** pass / **F** fail / **U** unknown. Legend: C1 lifecycle · C2 plugin/hook packaging · C3 deterministic gates · C4 cross-session state · C5 specialist orchestration · C6 quality/release enforcement · C7 process layer above host. Full per-criterion notes: `landscape/inclusion-ledger.md`.

**Membership must match charts.** APO core (~8): AgentSys, AI-DLC, Deepwork, Director, MetaGPT, Silver Bullet, Turboshovel, Workflow Manager. sdlc-plugins core (~13): BMAD, GSD, Zuvo, Spec Kit, Superpowers, SuperClaude, Ruflo, Oh My Pi, Claude Harness, cc10x, Cavekit, Barkain, Silver Bullet. SaaS core: Factory.ai, Devin, Augment Cosmos. Multi-market is allowed (Silver Bullet = APO ∩ plugins).

| Vendor | Market | C1 Life | C2 Plug | C3 Gate | C4 State | C5 Spec | C6 Enf | C7 Proc | Evidence cite | Final decision |
|---|---|---|---|---|---|---|---|---|---|---|
| [Augment Code](https://www.augmentcode.com/) (Cosmos) | `agentic-sdlc-saas` | P | P | U | U | P | U | P | solutions/augment-cosmos/features.json:Workflow composition | included-core |
| Devin | `agentic-sdlc-saas` | P | P | U | U | F | P | P | solutions/devin/features.json:Workflow composition | included-core |
| [Factory.ai](https://www.factory.ai/) | `agentic-sdlc-saas` | P | P | U | U | P | P | P | solutions/factory-ai/features.json:Workflow composition | included-core |
| [AI-DLC](https://github.com/awslabs/aidlc-workflows) | `apo` | P | U | U | U | U | U | U | solutions/ai-dlc/features.json:Workflow composition,Prebuilt SDLC templates | included-core |
| [AgentSys](https://github.com/agent-sh/agentsys) | `apo` | P | P | F | U | P | U | P | solutions/agentsys/features.json:Workflow composition | included-core |
| Deepwork | `apo` | P | P | F | U | U | U | P | solutions/deepwork/features.json:Workflow composition | included-core |
| Director | `apo` | P | P | U | U | U | U | P | solutions/director/features.json:Workflow composition | included-core |
| [MetaGPT](https://github.com/FoundationAgents/MetaGPT) | `apo` | U | U | U | U | U | U | U | solutions/metagpt/features.json/scr.md (insufficient evidence) | included-core |
| [Silver Bullet](https://sb.alolabs.dev/) | `apo` | P | P | P | P | P | P | P | solutions/silver-bullet/features.json:Workflow composition,Prebuilt SDLC templates | included-core |
| Turboshovel | `apo` | P | P | F | U | U | U | P | solutions/turboshovel/features.json:Workflow composition | included-core |
| Workflow Manager | `apo` | P | P | U | U | F | U | P | solutions/workflow-manager/features.json:Workflow composition | included-core |
| [Barkain Workflow Orchestrator](https://github.com/barkain/claude-code-workflow-orchestration) | `sdlc-plugins` | P | P | U | U | U | U | P | solutions/barkain-workflow-orchestrator/features.json:Workflow composition | included-core |
| [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD) | `sdlc-plugins` | P | P | P | U | U | P | P | solutions/bmad/features.json:Workflow composition,Prebuilt SDLC templates | included-core |
| [Cavekit v3.1](https://github.com/JuliusBrussee/cavekit) | `sdlc-plugins` | P | P | F | U | F | U | P | solutions/cavekit-v31/features.json:Workflow composition | included-core |
| [cc10x](https://github.com/romiluz13/cc10x) | `sdlc-plugins` | P | P | P | U | U | P | P | solutions/cc10x/features.json:Workflow composition | included-core |
| Claude Harness | `sdlc-plugins` | P | P | P | U | F | P | P | solutions/claude-harness/features.json:Workflow composition | included-core |
| GSD (Get Shit Done) | `sdlc-plugins` | P | P | P | U | U | P | P | solutions/gsd/features.json:Workflow composition,Prebuilt SDLC templates | included-core |
| [GitHub Spec Kit](https://github.com/github/spec-kit) | `sdlc-plugins` | P | P | P | U | F | P | P | solutions/spec-kit/features.json:Workflow composition,Prebuilt SDLC templates | included-core |
| Oh My Pi (OMP) | `sdlc-plugins` | P | P | P | U | P | P | P | solutions/oh-my-pi/features.json:Workflow composition,Prebuilt SDLC templates | included-core |
| Ruflo (formerly Claude Flow) | `sdlc-plugins` | P | P | P | U | P | P | P | solutions/ruflo/features.json:Workflow composition,Prebuilt SDLC templates | included-core |
| [Silver Bullet](https://sb.alolabs.dev/) | `sdlc-plugins` | P | P | P | P | P | P | P | solutions/silver-bullet/features.json:Workflow composition,Prebuilt SDLC templates | included-core |
| [SuperClaude](https://github.com/SuperClaude-Org/SuperClaude_Framework) | `sdlc-plugins` | P | P | P | U | U | P | P | solutions/superclaude/features.json:Workflow composition,Prebuilt SDLC templates | included-core |
| [Superpowers](https://github.com/obra/superpowers) | `sdlc-plugins` | P | P | P | U | U | P | P | solutions/superpowers/features.json:Workflow composition,Prebuilt SDLC templates | included-core |
| [Zuvo](https://zuvo.dev/) | `sdlc-plugins` | P | P | P | U | P | U | P | solutions/zuvo/features.json:Workflow composition | included-core |

_Adjacent (not core in that market)_

| Vendor | Market | C1 Life | C2 Plug | C3 Gate | C4 State | C5 Spec | C6 Enf | C7 Proc | Evidence cite | Final decision |
|---|---|---|---|---|---|---|---|---|---|---|
| [AgentHub](https://www.agenthub.ai/) | `apo` | P | P | U | U | P | U | P | solutions/agenthub/features.json:Workflow composition | adjacent (APO CRM — not Leaders) |
| [Conductor](https://conductor.build/) | `agentic-sdlc-saas` | U | U | U | U | U | U | U | not in inclusion-ledger.json | adjacent-aggregator (not APO) |
| [Tembo](https://tembo.io/) | `agentic-sdlc-saas` | F | F | F | F | U | F | U | envelopes: Satisfies 2 of 7 inclusion criteria at most | adjacent (unplotted) |

_Hard-excluded — not membership. Envelope quotes that re-include these are model error, not seed lists._

| Vendor | Market | C1 Life | C2 Plug | C3 Gate | C4 State | C5 Spec | C6 Enf | C7 Proc | Evidence cite | Final decision |
|---|---|---|---|---|---|---|---|---|---|---|
| Magic.dev | `hard-excluded` | P | P | F | U | F | F | P | solutions/magic-dev/features.json:Workflow composition | hard-excluded (`coding_agent`) |
| ATeam | `hard-excluded` | P | P | F | U | P | U | P | solutions/ateam/features.json:Workflow composition | hard-excluded (FDE shop) |

### Coverage completeness matrix

Whether this run has **evidence files**, a **comparison-matrix score**, and a **market placement** — separate from 3-of-7 inclusion. Empty/U cells are honest unknowns; they are **not** proof of absence in the wild. A new DR is required to thicken Critical-row fill. This matrix does **not** claim completeness.

| Vendor | Evidence available | Scoring complete | Market placement | Gaps |
|--------|--------------------|------------------|------------------|------|
| Augment Cosmos | yes (features.json + scr.md) | yes | `agentic-sdlc-saas` / included-core | — |
| Devin | yes (features.json + scr.md) | yes | `agentic-sdlc-saas` / included-core | — |
| [Factory.ai](https://www.factory.ai/) | yes (features.json + scr.md) | yes | `agentic-sdlc-saas` / included-core | — |
| [Tembo](https://tembo.io/) | yes (features.json + scr.md) | no | `agentic-sdlc-saas` / adjacent (unplotted) | SaaS-adjacent / unplotted |
| [Conductor](https://conductor.build/) | yes (features.json + scr.md) | no | `agentic-sdlc-saas` / adjacent-aggregator (not APO) | SaaS-adjacent aggregator; not APO core |
| [Cursor](https://cursor.com/) | yes (features.json + scr.md) | no | `agentic-sdlc-saas` / adjacent | host runtime — SaaS-adjacent only |
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) | yes (features.json + scr.md) | no | `agentic-sdlc-saas` / adjacent | host runtime — SaaS-adjacent only |
| [Codex](https://openai.com/codex/) | yes (features.json + scr.md) | no | `agentic-sdlc-saas` / adjacent | host runtime — SaaS-adjacent only |
| GitHub Copilot | yes (features.json + scr.md) | no | `agentic-sdlc-saas` / adjacent | host runtime — SaaS-adjacent only |
| [AgentSys](https://github.com/agent-sh/agentsys) | yes (features.json + scr.md) | yes | `apo` / included-core | — |
| [AI-DLC](https://github.com/awslabs/aidlc-workflows) | yes (features.json + scr.md) | yes | `apo` / included-core | AWS/awslabs methodology-without-gates — Visionaries, omitted from APO Wave |
| Deepwork | yes (features.json + scr.md) | yes | `apo` / included-core | thin-evidence APO commercial — ticks are proxies, not a shortlist |
| Director | yes (features.json + scr.md) | yes | `apo` / included-core | — |
| [MetaGPT](https://github.com/FoundationAgents/MetaGPT) | missing | no | `apo` / included-core | APO OSS core without solution artifacts — U cells are honest unknowns; new DR needed |
| [Silver Bullet](https://sb.alolabs.dev/) | yes (features.json + scr.md) | yes | `apo` / included-core | multi-market: also sdlc-plugins core |
| Turboshovel | yes (features.json + scr.md) | yes | `apo` / included-core | thin-evidence APO commercial — ticks are proxies, not a shortlist |
| Workflow Manager | yes (features.json + scr.md) | yes | `apo` / included-core | thin-evidence APO commercial — ticks are proxies, not a shortlist |
| [AgentHub](https://www.agenthub.ai/) | yes (features.json + scr.md) | no | `apo` / adjacent (APO CRM — not Leaders) | APO-adjacent CRM — not Leaders |
| [Barkain Workflow Orchestrator](https://github.com/barkain/claude-code-workflow-orchestration) | yes (features.json + scr.md) | yes | `sdlc-plugins` / included-core | — |
| [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD) | yes (features.json + scr.md) | yes | `sdlc-plugins` / included-core | — |
| [Cavekit v3.1](https://github.com/JuliusBrussee/cavekit) | yes (features.json + scr.md) | yes | `sdlc-plugins` / included-core | — |
| [cc10x](https://github.com/romiluz13/cc10x) | yes (features.json + scr.md) | yes | `sdlc-plugins` / included-core | — |
| Claude Harness | yes (features.json + scr.md) | yes | `sdlc-plugins` / included-core | — |
| GSD (Get Shit Done) | yes (features.json + scr.md) | yes | `sdlc-plugins` / included-core | — |
| Oh My Pi (OMP) | yes (features.json + scr.md) | yes | `sdlc-plugins` / included-core | — |
| [Ruflo / Claude Flow](https://github.com/ruvnet/ruflo) | yes (features.json + scr.md) | yes | `sdlc-plugins` / included-core | — |
| [Silver Bullet](https://sb.alolabs.dev/) | yes (features.json + scr.md) | yes | `sdlc-plugins` / included-core | multi-market: also APO core; Plugin MQ Leader via hooks+ledger only |
| [GitHub Spec Kit](https://github.com/github/spec-kit) | yes (features.json + scr.md) | yes | `sdlc-plugins` / included-core | — |
| [SuperClaude](https://github.com/SuperClaude-Org/SuperClaude_Framework) | yes (features.json + scr.md) | yes | `sdlc-plugins` / included-core | — |
| [Superpowers](https://github.com/obra/superpowers) | yes (features.json + scr.md) | yes | `sdlc-plugins` / included-core | — |
| [Zuvo](https://zuvo.dev/) | yes (features.json + scr.md) | yes | `sdlc-plugins` / included-core | scored and placed as core plugins — not missing |
| Magic.dev | yes (features.json + scr.md) | no | `hard-excluded` | quoted model error / hard-excluded coding_agent — not SaaS core, not MQ/Wave, not a comparison-matrix column |
| ATeam | yes (features.json + scr.md) | no | `hard-excluded` | hard-excluded FDE shop / professional_services — not APO membership |

## 4. Findings

### Competitive positioning — analyst frameworks

### 4.1 Primary market: Agentic Process Orchestrators (APO)

- Methodology/framework seeds without shipped hook gates (for example [AI-DLC](https://github.com/awslabs/aidlc-workflows)) are omitted from Wave and are not peer-complete on MQ: Completeness of Vision is capped so they do not plot as shipped-orchestrator peers; Ability to Execute is capped below Leaders.
- Demoted from Leaders for missing gates and/or cross-session state: agentsys, ai-dlc, deepwork, director, metagpt, turboshovel, workflow-manager.

#### 4.1.1 Agentic Process Orchestrators (APO) — Positioning Matrix

#### 4.1.2 Magic Quadrant — Agentic Process Orchestrators (APO)

| Vendor | Quadrant | Justification |
|--------|----------|---------------|
| [Silver Bullet](https://sb.alolabs.dev/) | Leaders | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| [AI-DLC](https://github.com/awslabs/aidlc-workflows) | Visionaries | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| Director | Niche Players | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| [AgentSys](https://github.com/agent-sh/agentsys) | Niche Players | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| Deepwork | Niche Players | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| Turboshovel | Niche Players | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| Workflow Manager | Niche Players | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| [MetaGPT](https://github.com/FoundationAgents/MetaGPT) | Niche Players | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |

#### 4.1.3 Wave-Style Assessment — Agentic Process Orchestrators (APO)

| Vendor | Current Offering | Strategy | Market Presence |
|--------|------------------|----------|-----------------|
| [Silver Bullet](https://sb.alolabs.dev/) | Strong | Strong | Good |

#### 4.1.4 Blue Ocean Value Curve — Agentic Process Orchestrators (APO)

Radar of Key Competitive Factors for Magic Quadrant Leaders (top-right) only. Factors appear only when at least one Leader has matrix/features.json evidence.

| Key Competitive Factor | [Silver Bullet](https://sb.alolabs.dev/) |
|---|---|
| Workflow composition | 5 |
| Atomic flow catalog | 5 |
| Hook-enforced gates | 5 |
| Parent/child delegation | 5 |
| Prebuilt SDLC templates | 5 |
| IDE-native integration | 5 |
| Free tier / OSS core | 5 |

### 4.2 Secondary market: SDLC Plugins & Methodology Packs

- Leaders require hook-enforced gates plus inclusion-ledger cross-session pass. Methodology packs that fail those under-served criteria are Visionaries or lower even when workflow ticks are dense. Wave presence, offering, and strategy are capped for packs that fail Leader eligibility.
- Demoted from Leaders for missing gates and/or cross-session state: barkain-workflow-orchestrator, bmad, cavekit-v31, [cc10x](https://github.com/romiluz13/cc10x), claude-harness, gsd, oh-my-pi, ruflo, spec-kit, superclaude, superpowers, zuvo.

#### 4.2.1 SDLC Plugins & Methodology Packs — Positioning Matrix

#### 4.2.2 Magic Quadrant — SDLC Plugins & Methodology Packs

| Vendor | Quadrant | Justification |
|--------|----------|---------------|
| [Silver Bullet](https://sb.alolabs.dev/) | Leaders | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| GSD (Get Shit Done) | Visionaries | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| Oh My Pi (OMP) | Visionaries | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD) | Visionaries | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| [cc10x](https://github.com/romiluz13/cc10x) | Visionaries | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| [Ruflo / Claude Flow](https://github.com/ruvnet/ruflo) | Visionaries | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| [Superpowers](https://github.com/obra/superpowers) | Visionaries | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| [Zuvo](https://zuvo.dev/) | Visionaries | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| [GitHub Spec Kit](https://github.com/github/spec-kit) | Visionaries | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| [SuperClaude](https://github.com/SuperClaude-Org/SuperClaude_Framework) | Visionaries | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| Claude Harness | Niche Players | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| [Cavekit v3.1](https://github.com/JuliusBrussee/cavekit) | Niche Players | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| [Barkain Workflow Orchestrator](https://github.com/barkain/claude-code-workflow-orchestration) | Niche Players | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |

#### 4.2.3 Wave-Style Assessment — SDLC Plugins & Methodology Packs

| Vendor | Current Offering | Strategy | Market Presence |
|--------|------------------|----------|-----------------|
| [Silver Bullet](https://sb.alolabs.dev/) | Strong | Strong | Good |
| GSD (Get Shit Done) | Moderate | Good | Moderate |
| Oh My Pi (OMP) | Good | Moderate | Moderate |
| [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD) | Moderate | Good | Moderate |
| [cc10x](https://github.com/romiluz13/cc10x) | Good | Moderate | Moderate |
| [Ruflo / Claude Flow](https://github.com/ruvnet/ruflo) | Moderate | Good | Moderate |
| [Superpowers](https://github.com/obra/superpowers) | Good | Moderate | Moderate |
| [Zuvo](https://zuvo.dev/) | Moderate | Good | Moderate |

#### 4.2.4 Blue Ocean Value Curve — SDLC Plugins & Methodology Packs

Radar of Key Competitive Factors for Magic Quadrant Leaders (top-right) only. Factors appear only when at least one Leader has matrix/features.json evidence.

| Key Competitive Factor | [Silver Bullet](https://sb.alolabs.dev/) |
|---|---|
| Workflow composition | 5 |
| Atomic flow catalog | 5 |
| Hook-enforced gates | 5 |
| Parent/child delegation | 5 |
| Prebuilt SDLC templates | 5 |
| IDE-native integration | 5 |
| Free tier / OSS core | 5 |

### 4.3 Tertiary market: Agentic SDLC SaaS & Autonomous Delivery

- SaaS-core MQ/Wave plots shipped autonomous-delivery products with managed hosting. Coding-model labs without orchestration evidence are hard-excluded, not tertiary core.

#### 4.3.1 Agentic SDLC SaaS & Autonomous Delivery — Positioning Matrix

#### 4.3.2 Magic Quadrant — Agentic SDLC SaaS & Autonomous Delivery

| Vendor | Quadrant | Justification |
|--------|----------|---------------|
| Devin | Leaders | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| [Factory.ai](https://www.factory.ai/) | Leaders | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| Augment Cosmos | Leaders | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |

#### 4.3.3 Wave-Style Assessment — Agentic SDLC SaaS & Autonomous Delivery

| Vendor | Current Offering | Strategy | Market Presence |
|--------|------------------|----------|-----------------|
| Devin | Strong | Good | Strong |
| [Factory.ai](https://www.factory.ai/) | Strong | Moderate | Good |
| Augment Cosmos | Strong | Moderate | Good |

#### 4.3.4 Blue Ocean Value Curve — Agentic SDLC SaaS & Autonomous Delivery

Radar of Key Competitive Factors for Magic Quadrant Leaders (top-right) only. Factors appear only when at least one Leader has matrix/features.json evidence.

| Key Competitive Factor | Devin | [Factory.ai](https://www.factory.ai/) | Augment Cosmos |
|---|---|---|---|
| Workflow composition | 5 | 5 | 5 |
| Parent/child delegation | 1 | 5 | 5 |
| Managed hosting | 5 | 5 | 5 |
| IDE-native integration | 5 | 5 | 5 |
| Free tier / OSS core | 5 | 1 | 1 |
| Predictable pricing | 5 | 1 | 1 |


### Agentic Process Orchestrators (APO) — Top Commercial Solutions (3 core)

### Deepwork (Commercial)

* **Overview**: THIN EVIDENCE — Deepwork is a seed-level APO commercial candidate. Capabilities are **unknown** without primary product documentation in this pass.
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

* **Overview**: THIN EVIDENCE — Turboshovel is a seed-level APO commercial candidate. Product URL and capabilities are **unknown/unverified** here.
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

* **Overview**: THIN EVIDENCE — Workflow Manager is a seed-level APO commercial candidate. Distinct homepage and capabilities are **unknown** in this pass.
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

### Agentic Process Orchestrators (APO) — Top Open Source Solutions (5 core)

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

* **Overview**: Director is a primary-market APO candidate — agent orchestration, workflow composition, deterministic gates, and specialist agent routing. Canonical product URL was not independently verified in this pass (prior candidate repo returned 404); treat identity as seed-level until a primary source is confirmed.
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

### SDLC Plugins & Methodology Packs — Top Open Source Solutions (13 core)

### [Barkain Workflow Orchestrator](https://github.com/barkain/claude-code-workflow-orchestration) (OSS — OSS)

* **Overview**: THIN EVIDENCE — [Barkain Workflow Orchestrator](https://github.com/barkain/claude-code-workflow-orchestration) is seed-listed. Persistence/gate claims are **unknown** without independent corroboration.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Control & flexibility**: OSS/core deployable on your infrastructure.
  * **Ecosystem momentum**: Active presence in the agentic SDLC orchestration category.
* **Major Cons**:
  * **Weak hook gates**: Lacks explicit fail-closed lifecycle hooks versus process-first peers.
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [Barkain Workflow Orchestrator](https://github.com/barkain/claude-code-workflow-orchestration).
* **Avoid If**: You need capabilities [Barkain Workflow Orchestrator](https://github.com/barkain/claude-code-workflow-orchestration) lacks in the matrix (Atomic flow catalog, Hook-enforced gates).

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

### [Cavekit v3.1](https://github.com/JuliusBrussee/cavekit) (OSS — OSS)

* **Overview**: THIN EVIDENCE — [Cavekit v3.1](https://github.com/JuliusBrussee/cavekit) seed listing. Feature depth **unknown** beyond seed metadata; v4 remains adjacent until process-layer evidence clears.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Skill/plugin marketplace**: Supported in startup-weighted comparison matrix.
  * **Control & flexibility**: OSS/core deployable on your infrastructure.
* **Major Cons**:
  * **Weak hook gates**: Lacks explicit fail-closed lifecycle hooks versus process-first peers.
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [Cavekit v3.1](https://github.com/JuliusBrussee/cavekit).
* **Avoid If**: You need capabilities [Cavekit v3.1](https://github.com/JuliusBrussee/cavekit) lacks in the matrix (Atomic flow catalog, Hook-enforced gates).

### [cc10x](https://github.com/romiluz13/cc10x) (OSS — OSS)

* **Overview**: [cc10x](https://github.com/romiluz13/cc10x) is not an APO peer — a [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview)–oriented enhancement pack for multi-agent coordination, process enforcement, and host-integrated packaging. Public footprint is thinner than [Silver Bullet](https://sb.alolabs.dev/) or [AI-DLC](https://github.com/awslabs/aidlc-workflows); treat adoption claims as unverified without primary metrics.
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
* **Best For**: SMB teams prioritising workflow composition with [cc10x](https://github.com/romiluz13/cc10x).
* **Avoid If**: You need capabilities [cc10x](https://github.com/romiluz13/cc10x) lacks in the matrix (Atomic flow catalog, Predictable pricing).

### Claude Harness (OSS — OSS)

* **Overview**: UNVERIFIED IDENTITY: Claude Harness is listed as a methodology/process pack candidate, but no distinct canonical repository or homepage was verified in this pass. Do **not** treat `anthropics/claude-code` (the host runtime) as the Harness product source. Capabilities below are seed-asserted only until a primary source is confirmed.
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

### [Ruflo / Claude Flow](https://github.com/ruvnet/ruflo) (OSS — OSS)

* **Overview**: Naming: **Ruflo** is the current project name; **Claude Flow** is the former name (same ruvnet line). SPARC methodology pack over [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) — not two unrelated products.
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
* **Best For**: SMB teams prioritising workflow composition with [Ruflo / Claude Flow](https://github.com/ruvnet/ruflo).
* **Avoid If**: You need capabilities [Ruflo / Claude Flow](https://github.com/ruvnet/ruflo) lacks in the matrix (Atomic flow catalog, Predictable pricing).

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

### [GitHub Spec Kit](https://github.com/github/spec-kit) (OSS — OSS)

* **Overview**: GitHub spec-kit makes specifications executable via constitution.md principles and spec-driven development workflows.
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
* **Best For**: SMB teams prioritising workflow composition with [GitHub Spec Kit](https://github.com/github/spec-kit).
* **Avoid If**: You need capabilities [GitHub Spec Kit](https://github.com/github/spec-kit) lacks in the matrix (Atomic flow catalog, Predictable pricing).

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

### [Zuvo](https://zuvo.dev/) (OSS — OSS)

* **Overview**: Identity verified 2026-08-13 from the product site: homepage [`https://zuvo.dev/`](https://zuvo.dev/) → GitHub [`https://github.com/greglas75/zuvo`](https://github.com/greglas75/zuvo). Do not use `github.com/zuvo-ai/zuvo`, `github.com/zuvo-labs/zuvo`, `github.com/zuvo`, `anthropics/claude-code`, or `claude.com/plugins`.
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
* **Best For**: SMB teams prioritising workflow composition with [Zuvo](https://zuvo.dev/).
* **Avoid If**: You need capabilities [Zuvo](https://zuvo.dev/) lacks in the matrix (Atomic flow catalog, Predictable pricing).

### Agentic SDLC SaaS & Autonomous Delivery — Top Commercial Solutions (3 core)

### Augment Cosmos (Commercial)

* **Overview**: Naming: public brand is **[Augment Code](https://www.augmentcode.com/)**; Cosmos is an Augment agentic SDLC capability/surface, not a separate standalone vendor. Agents may run in customer env or Augment cloud.
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
* **Best For**: SMB teams prioritising workflow composition with Augment Cosmos.
* **Avoid If**: You need capabilities Augment Cosmos lacks in the matrix (Atomic flow catalog, Hook-enforced gates).

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

### Adjacent Markets (not core peers)

Products below are relevant context but **not** scored as core peers on the market where they are adjacent. A vendor may be **core in one market and adjacent in another** (multi-market is allowed). Silver Bullet is core in APO ∩ sdlc-plugins — not listed here. Devin is agentic-sdlc-saas core, not a host-runtime adjacent.

- **[AgentHub](https://www.agenthub.ai/)** (`agenthub`) — APO-adjacent CRM, not Leaders
- **[AxonFlow](https://www.axonflow.ai/)** (`axonflow`) — pack adjacent_seed (generic orchestration)
- **Cavekit v4** (`cavekit-v4`) — pack adjacent_seed (Cavekit v3.1 is the sdlc-plugins core)
- **[Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview)** (`claude-code`) — host runtime, SaaS-adjacent only
- **[Codex](https://openai.com/codex/)** (`codex`) — host runtime, SaaS-adjacent only
- **[Cognition Scout](https://cognition.ai/)** (`cognition-scout`) — SaaS-adjacent
- **[Conductor](https://conductor.build/)** (`conductor`) — SaaS-adjacent aggregator, **not APO**
- **[CrewAI](https://github.com/crewAIInc/crewAI)** (`crewai`) — generic agent framework adjacent
- **[Cursor](https://cursor.com/)** (`cursor`) — host runtime, SaaS-adjacent only
- **GitHub Copilot** (`github-copilot`) — host runtime, SaaS-adjacent only
- **[LangChain](https://github.com/langchain-ai/langchain)** (`langchain`) — generic framework adjacent
- **LangGraph** (`langgraph`) — generic framework adjacent
- **[Replit Agent](https://replit.com/)** (`replit-agent`) — SaaS-adjacent
- **[Tembo](https://tembo.io/)** (`tembo`) — SaaS-adjacent / unplotted

### Explicitly Excluded

- **Aider** — pack hard_exclusion (coding_agent)
- **Amazon Q Developer** — hard_veto from need_profile
- **ATeam** — pack hard_exclusion (professional_services)
- **Claude Code Expert** — pack hard_exclusion (sunset)
- **Cline** — pack hard_exclusion (coding_agent)
- **CodeRabbit** — hard_veto from need_profile
- **Continue** — pack hard_exclusion (coding_agent)
- **Cursor Background Agents** — hard_veto from need_profile
- **GitHub Copilot Enterprise** — pack hard_exclusion (coding_agent)
- **JetBrains AI Assistant** — hard_veto from need_profile
- **Linear** — pack hard_exclusion (project_management)
- **Magic.dev** — pack hard_exclusion (coding_agent)
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

Honest remaining evidence gaps (not missing cores): MetaGPT has no solution artifacts in this run (U cells); Deepwork / Turboshovel / Workflow Manager are thin-evidence APO commercials; many C4 cross-session cells are U. A new DR is required to thicken Critical-row fill. **Zuvo is not a coverage gap.**

### Consensus Patterns

What contributing models **agreed on** across retrieve / triangulate / critique envelopes (at least three model families). This is not a dump of industry trends and not a buying recommendation.

#### Process layer above host runtimes
- **Agreement** (7 families: claude, deepseek, gemini, kimi, mimo, minimax, qwen): Contributing models treat Agentic Process Orchestrators as a process or enforcement layer above a host coding-agent runtime, not as a synonym for autonomous code generation.

#### Hook-enforced and deterministic gates
- **Agreement** (7 families: claude, deepseek, gemini, kimi, mimo, minimax, qwen): Models agree that machine-checkable gates (host hooks, blocking quality rails) are the main differentiator versus prompt- or persona-level methodology packs, which an agent can skip.

#### SDLC plugin / methodology packs as substitutes
- **Agreement** (7 families: claude, deepseek, gemini, kimi, mimo, minimax, qwen): Models agree the secondary market (BMAD, GSD, [Superpowers](https://github.com/obra/superpowers), Spec Kit, Ruflo, Oh My Pi, and peers) covers plan-to-ship workflows as host plugins. That is a substitute class, not automatic Leader standing on the primary APO chart.

#### Cross-session state is under-served
- **Agreement** (7 families: claude, deepseek, gemini, kimi, mimo, minimax, qwen): Models agree durable cross-session state is the weakest inclusion criterion for most methodology packs; markdown re-read per session is not an enforced state machine.

#### Tertiary SaaS as buying substitutes
- **Agreement** (7 families: claude, deepseek, gemini, kimi, mimo, minimax, qwen): Models agree [Factory.ai](https://www.factory.ai/), Devin, and Augment Cosmos are analyst-grade substitutes for process-orchestration buying even when they do not self-label as APO. They are scored in the SaaS market, not as APO peers.

Catalogs and git-native issue-to-PR loops appear in this report's trend list; they did **not** reach cross-family agreement in contributing-model claims, so they are not listed as consensus.
### Consensus Resolution Table

Notable divergences are **inter-model disagreements**. This table is the **analyst call** this report follows. Envelope quotes of model disagreement belong here only — they are not seed lists, comparison columns, or Top Commercial membership.

| Claim | Supporting models | Contradicting models | Final analyst decision | Evidence |
|-------|-------------------|----------------------|------------------------|----------|
| Magic.dev membership (SaaS core vs hard-excluded) | `gemini-3.5-flash` listed it as a tertiary SaaS peer in triangulation envelopes | `ocg-qwen3.7-plus` + category-pack `hard_exclusions` (`coding_agent`) | **FINAL:** one membership — hard-excluded as `coding_agent`. Not a SaaS core, not a comparison-matrix column, not an MQ/Wave point, not a Top Commercial card. Contributing-model seed lists that re-include it are envelope quotes / model error, not report membership. | Category-pack `hard_exclusions`; `solutions/magic-dev/scr.md` (coding-model lab, not Factory/Devin-class delivery); SaaS cores remain [Factory.ai](https://www.factory.ai/), Devin, Augment Cosmos. Magic.dev is absent from comparison-matrix columns. |
| [Conductor](https://conductor.build/) as APO peer vs aggregator | Some triangulation envelopes framed [Conductor](https://conductor.build/) as a mid-tier APO / process orchestrator | Category-pack adjacent class + `features.json` (no shipped hook gates or specialist orchestration) | **FINAL:** aggregator (SaaS-adjacent coding-agent aggregator), not an Agentic Process Orchestrator. Not plotted on the APO chart and not a comparison column. Claude Harness is an sdlc-plugins core (host plugins), not APO. There is no "Claude Code Expert" product in this peer set (hard-excluded sunset). | Category-pack adjacent class; `solutions/conductor/features.json` has no shipped hook gates or specialist orchestration; APO cores are process layers above a host runtime, not multi-agent aggregators. |
| [Silver Bullet](https://sb.alolabs.dev/) is 'most complete' | Some retrieve/triangulate envelopes used a completeness superlative for [Silver Bullet](https://sb.alolabs.dev/) | Critique envelopes dispute any single OSS APO as 'most complete' | **FINAL:** this report does not call any vendor 'most complete'. Silver Bullet's plugin MQ Leader plot is a feature-gate outcome (hook-enforced gates AND inclusion-ledger cross-session pass). That is not a completeness ranking. Buying profiles keep equal-standing peers. | Leader eligibility (`_CROSS_SESSION_PASS_SLUGS` = silver-bullet; plugins need gates + ledger C4). Ranking scores are Critical=5…Low=1 tick totals. COI is ignored as a reason to demote Silver Bullet; superlatives are still removed. |
| Secondary packs 'lack gates/state' therefore are empty or not worth buying | Some critique envelopes used overbroad negatives about methodology packs | Matrix ticks show dense workflow/template coverage on BMAD, GSD, Spec Kit, Zuvo, and peers | **FINAL:** secondary packs are host-plugin substitutes for plan-to-ship workflows, not automatic APO Leaders. Leader demotion is specifically missing hook gates and/or cross-session state — not a blanket claim that the pack is empty. Zuvo is an sdlc-plugins CORE with public evidence, not a missing vendor. | sdlc-plugins core (13) in catalog_audit / chart-data; comparison matrix includes zuvo; MQ plots Zuvo as Visionaries. |
| AI-DLC is IBM enterprise APO vs AWS methodology without gates | Some envelopes framed AI-DLC as enterprise-grade APO with lifecycle orchestration | Public repo is awslabs/aidlc-workflows; features.json has no shipped hook gates | **FINAL:** AI-DLC is AWS/awslabs, not IBM. It is an APO core methodology-without-gates seed: Visionaries on MQ, omitted from APO Wave, not a peer-complete execute Leader. | https://github.com/awslabs/aidlc-workflows; catalog_audit apo.core includes ai-dlc; Wave omits methodology-without-gates. |

## 5. Buying Guidance & Shortlist Profiles

- **Lean startup / spec-first packs**: Shortlist OSS methodology packs on equal standing — [Zuvo](https://zuvo.dev/), [Barkain Workflow Orchestrator](https://github.com/barkain/claude-code-workflow-orchestration), [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD), [Cavekit v3.1](https://github.com/JuliusBrussee/cavekit), [cc10x](https://github.com/romiluz13/cc10x), Claude Harness, GSD (Get Shit Done), [GitHub Spec Kit](https://github.com/github/spec-kit), [Superpowers](https://github.com/obra/superpowers). Zuvo is an sdlc-plugins **core** (https://zuvo.dev/ → MIT GitHub), not missing. Pick on spec-driven vs persona vs swarm topology. Do not treat a single orchestrator as the default.
- **Process-first / fail-closed delivery**: Plugin MQ Leaders = [Silver Bullet](https://sb.alolabs.dev/) **only** in this run because only that slug passed **both** hook-enforced gates and inclusion-ledger cross-session. That is a **feature-gate fact**, not a claim that the product is 'most complete'. This report does not call any vendor 'most complete'. Other APO cores remain peers below.
- **Open-source APO cores**: [AgentSys](https://github.com/agent-sh/agentsys), [AI-DLC](https://github.com/awslabs/aidlc-workflows), Deepwork, Director, [MetaGPT](https://github.com/FoundationAgents/MetaGPT), Turboshovel, Workflow Manager stand as peers. [AI-DLC](https://github.com/awslabs/aidlc-workflows) is AWS/awslabs methodology vocabulary without shipped hook gates — Visionaries on MQ, omitted from APO Wave; not IBM. Director is an APO seed with unverified identity and no shipped hook gates — not a plugin and not an aggregator.
- **Host-runtime path**: Use [Cursor](https://cursor.com/), [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview), or [Codex](https://openai.com/codex/) with a separate pack (including [Zuvo](https://zuvo.dev/), [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD), GSD). The host is not the orchestrator; Factory/Devin are SaaS cores, not host-runtime add-ons.
- **Managed autonomous delivery**: Shortlist Augment Cosmos, Devin, [Factory.ai](https://www.factory.ai/). This profile does not resolve to an OSS process pack. Magic.dev is hard-excluded (coding-model lab), not a SaaS-core substitute.
- **Triangulation**: Use contributing-model consensus and the Consensus Resolution Table as a **reading aid**. Notable divergences are inter-model disagreements; the resolution table is the analyst call. Triangulation is not a scored axis.

## 6. Future Outlook & Emerging Disruptors

### Router-first catalogs and hook gates
- Process routers with nested verify loops remain a differentiator for teams that need fail-closed delivery, not just prompt packs. **SMB implication**: Threatens executor-only agents.

### Multi-model triangulation as a research method
- This report triangulates contributing models. Vendors were **not** scored on multi-model pools — triangulation is not a matrix row or MQ/Wave axis. **SMB implication**: Use it to read claims; do not treat it as a product feature tick.

### Consolidation of git-native agents
- Issue-to-PR agents may merge with SDLC orchestration platforms. **SMB implication**: Threatens point tools without ecosystem depth.

### Completeness claims are closed for this report
- The analyst decision is that this report does not call any vendor 'most complete'. Ranking scores are feature-tick totals. Plugin MQ Leaders = Silver Bullet only is a hooks + cross-session feature-gate, not a completeness ranking. **SMB implication**: Treat Leader plots as feature-gate outcomes; keep equal-standing shortlists by buying profile.

## 7. Source Reliability Assessment

### Model response weights

| Source | Response Size | Weight Applied | Assessment |
|--------|--------------|----------------|------------|
| claude-opus-4.8-medium | 41185 chars | **Good—Secondary** | Contributed DR phases with structured payloads; depth varies by phase. |
| gemini-3.5-flash | 30675 chars | **Heavy—Primary** | Contributed DR phases with structured payloads; depth varies by phase. |
| gpt-5.6-luna-medium | 24921 chars | **Good—Secondary** | Contributed DR phases with structured payloads; depth varies by phase. |
| ocg-deepseek-v4-flash | 26293 chars | **Good—Secondary** | Contributed DR phases with structured payloads; depth varies by phase. |
| ocg-kimi-k2.7-code | 21845 chars | **Good—Secondary** | Contributed DR phases with structured payloads; depth varies by phase. |
| ocg-mimo-v2.5 | 25627 chars | **Good—Secondary** | Contributed DR phases with structured payloads; depth varies by phase. |
| ocg-minimax-m3 | 32805 chars | **Good—Secondary** | Contributed DR phases with structured payloads; depth varies by phase. |
| ocg-qwen3.7-plus | 28791 chars | **Good—Secondary** | Contributed DR phases with structured payloads; depth varies by phase. |