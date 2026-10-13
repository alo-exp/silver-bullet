# Landscape report context digest (for multi-AI critique)

run_id=run-57f38dfa25d83cc50d224e283d4692f3
Primary SPA: research/.../landscape-report.html (file://, ~589KB)
Markdown: landscape/landscape-report.md
Chart data: landscape/chart-data.json

## Markets
- Primary APO: Agentic Process Orchestrators
- Secondary: SDLC Plugins & Methodology Packs
- Tertiary: Agentic SDLC SaaS & Autonomous Delivery

## Membership (core)
```json
{
  "apo": {
    "display": "Agentic Process Orchestrators (APO)",
    "role": "primary",
    "core": [
      "agenthub",
      "agentsys",
      "ai-dlc",
      "ateam",
      "barkain-workflow-orchestrator",
      "cavekit-v31",
      "cc10x",
      "deepwork",
      "director",
      "metagpt",
      "silver-bullet",
      "turboshovel",
      "workflow-manager"
    ],
    "adjacent": [
      "axonflow",
      "cavekit-v4",
      "crewai",
      "langchain",
      "langgraph"
    ],
    "leaders": [
      "AgentHub",
      "AI-DLC",
      "Silver Bullet"
    ],
    "challengers": [],
    "mq_plotted": [
      "AgentHub",
      "AgentSys",
      "AI-DLC",
      "ATeam",
      "Barkain Workflow Orchestrator",
      "Cavekit v3.1",
      "cc10x",
      "Deepwork",
      "Director",
      "MetaGPT",
      "Silver Bullet",
      "Turboshovel",
      "Workflow Manager"
    ],
    "wave_count": 8,
    "unplotted": [
      "axonflow",
      "cavekit-v4",
      "crewai",
      "langchain",
      "langgraph"
    ]
  },
  "sdlc-plugins": {
    "display": "SDLC Plugins & Methodology Packs",
    "role": "secondary",
    "core": [
      "bmad",
      "claude-harness",
      "gsd",
      "oh-my-pi",
      "ruflo",
      "silver-bullet",
      "spec-kit",
      "superclaude",
      "superpowers",
      "zuvo"
    ],
    "adjacent": [
      "crewai",
      "langgraph"
    ],
    "leaders": [
      "BMAD-METHOD",
      "Claude Harness",
      "GSD (Get Shit Done)",
      "Oh My Pi (OMP)",
      "Ruflo / Claude Flow",
      "Silver Bullet",
      "GitHub Spec Kit",
      "SuperClaude",
      "Superpowers",
      "Zuvo"
    ],
    "challengers": [],
    "mq_plotted": [
      "BMAD-METHOD",
      "Claude Harness",
      "GSD (Get Shit Done)",
      "Oh My Pi (OMP)",
      "Ruflo / Claude Flow",
      "Silver Bullet",
      "GitHub Spec Kit",
      "SuperClaude",
      "Superpowers",
      "Zuvo"
    ],
    "wave_count": 8,
    "unplotted": [
      "crewai",
      "langgraph"
    ]
  },
  "agentic-sdlc-saas": {
    "display": "Agentic SDLC SaaS & Autonomous Delivery",
    "role": "tertiary",
    "core": [
      "augment-cosmos",
      "devin",
      "factory-ai",
      "magic-dev",
      "tembo"
    ],
    "adjacent": [
      "claude-code",
      "codex",
      "cognition-scout",
      "conductor",
      "cursor",
      "github-copilot",
      "replit-agent"
    ],
    "leaders": [
      "Augment Cosmos",
      "Devin",
      "Factory.ai",
      "Magic.dev",
      "Tembo"
    ],
    "challengers": [],
    "mq_plotted": [
      "Augment Cosmos",
      "Devin",
      "Factory.ai",
      "Magic.dev",
      "Tembo"
    ],
    "wave_count": 5,
    "unplotted": [
      "claude-code",
      "codex",
      "cognition-scout",
      "conductor",
      "cursor",
      "github-copilot",
      "replit-agent"
    ]
  }
}
```

## Scope excerpt

**Landscape scope**

Agentic SDLC orchestration solutions operating **one level above coding agents** — end-to-end, process-driven, workflow-based agentic layers for software engineering and DevOps (SecOps-adjacent). Excludes raw LLM APIs and single-shot copilots.

Research topic: `Agentic SDLC orchestration landscape multimarket final — APO primary, SDLC plugins secondary (BMAD GSD [Superpowers](https://github.com/obra/superpowers) Spec Kit Oh My [Zuvo](https://zuvo.dev/) OSS), agentic SDLC SaaS tertiary (Factory Devin Augment Cosmos)`

**Primary jobs-to-be-done**

1. Enforce a full SDLC or DevOps cycle so agents cannot skip planning, verification, review, or release steps
2. Compose specialist agents and external workflows (GSD, spec kits, review ladders) under one compliance layer
3. Persist process state, gates, and evidence across sessions and parallel workers
4. Provide procurement-ready comparison of process-orchestration depth vs host runtimes and frameworks

**Out of scope (excluded from core peer set)**

- Generic **coding agents** and IDE copilots (Cursor Background Agents, Cline, Aider, Continue, OpenHands, SWE-agent)
- **Host runtimes** that execute code without a process catalog (Devin, Copilot, [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) as hosts — listed under Adjacent only)
- **Single-step** tools (PR review bots, PM integrations such as Linear)
- **Generic agent frameworks** without SDLC process packaging (LangGraph, [CrewAI](https://github.com/crewAIInc/crewAI) as adjacent)
- **Sunset** products (GitHub Copilot Workspace, AutoGen, AgentGPT, Devika)

**Inclusion criteria**

A vendor belongs in the **core peer set** when it clearly demonstrates at least **3 of 7** capabilities below (not advisory-only claims):

- **Multi-phase lifecycle span** — Covers two or more of plan/spec, build, test, review, release, or DevOps operations as an integrated process — not a single-shot codegen or review-only tool.
- **Plugin / skill / hook packaging** — Ships as host-integrated packaging (Claude/[Codex](https://openai.com/codex/)/[Cursor](https://cursor.com/) plugin, skill bundle, hook layer, or equivalent) rather than a standalone IDE or raw API.
- **Deterministic quality gates** — Uses machine-checkable gates (hooks, audits, stop-checks, CI integration) that block progression when criteria fail.
- **Cross-session state** — Persists workflow state, memory, or runbooks across agent clears, sessions, or parallel workers.
- **Sp

## Adjacent

Products below are relevant context but **not** scored on the Magic Quadrant, Wave, or comparison matrix.

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

## Excluded

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

**Coverage gaps (must-research seeds missing from envelopes)**

- [Zuvo](https://zuvo.dev/) (`sdlc-plugin`)

## Buying guidance

- **Lean startup, process-first**: Prioritise workflow composition, atomic catalog, and hook gates — shortlist **[Silver Bullet](https://sb.alolabs.dev/)** and peers: [AgentHub](https://www.agenthub.ai/), [AgentSys](https://github.com/agent-sh/agentsys), [AI-DLC](https://github.com/awslabs/aidlc-workflows), [ATeam](https://www.a.team/), [Barkain Workflow Orchestrator](https://barkain.com/).
- **Open-source-first**: Prioritise [Silver Bullet](https://sb.alolabs.dev/) and OSS core orchestrators — budget for hook and catalog integration.
- **Host-runtime path**: Use SaaS-adjacent host runtimes ([Cursor](https://cursor.com/), [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview)) with a separate APO process layer — do not conflate with Factory/Devin SaaS cores or APO peers.

## Solutions catalog (34 entries)
- agenthub: AgentHub
- agentsys: AgentSys
- ai-dlc: AI-DLC
- ateam: ATeam
- augment-cosmos: Augment Cosmos
- barkain-workflow-orchestrator: Barkain Workflow Orchestrator
- bmad: BMAD-METHOD
- cavekit-v31: Cavekit v3.1
- cc10x: cc10x
- claude-code: Claude Code
- claude-code-expert: Claude Code Expert
- claude-harness: Claude Harness
- codex: Codex
- cognition-scout: Cognition Scout
- conductor: Conductor
- cursor: Cursor
- deepwork: Deepwork
- devin: Devin
- director: Director
- factory-ai: Factory.ai
- github-copilot: GitHub Copilot
- gsd: GSD (Get Shit Done)
- magic-dev: Magic.dev
- oh-my-pi: Oh My Pi (OMP)
- ruflo: Ruflo / Claude Flow
- sdlc-plugin: SDLC Plugin
- silver-bullet: Silver Bullet
- spec-kit: GitHub Spec Kit
- superclaude: SuperClaude
- superpowers: Superpowers
- tembo: Tembo
- turboshovel: Turboshovel
- workflow-manager: Workflow Manager
- zuvo: Zuvo

## Prior analyst-grade FINDINGS (excerpt)

# Analyst-grade review — multimarket landscape SPA

`run_id=run-57f38dfa25d83cc50d224e283d4692f3` (SCRs/waves reused; no new DR)

Report: [`landscape-report.html`](../landscape-report.html)

## file:// verify: **PASS**

- URL: `file:///Users/shafqat/.cursor/worktrees/repo/3ht3/research/2026-07-20-agentic-sdlc-orchestration-landscape-multimarket-final/landscape-report.html`
- Screenshots: ['AFTER-1280.png', 'AFTER-375.png', 'AFTER-dark-1280.png']
- Checks: `{"hasContent": true, "markedPinned": true, "noAgentsysAi": true, "hasAgentSysGithub": true, "noAwsAiDlc": true, "noDeepworkAi": true, "hasMetaGPT": true, "hasClaudeHarness": true, "noHarnessApoCandidate": true, "saasSectionMentionsFactory": true, "underlines": 0, "overflow375": 0, "noCursorInSaasMq": true, "metaGptInApoMq": true, "harnessInPluginsOss": true, "noClaudeCodeExpertInRankings": true, "pageErrors": 0}`

## Membership audit table (material solutions)

| Solution | Slug | Markets (correct) | License bucket | MQ? | Notes / action |
|---|---|---|---|---|---|
| AgentHub | `agenthub` | apo:core | commercial | yes | pack core_seed |
| AgentSys | `agentsys` | apo:core | oss | yes | pack core_seed |
| AI-DLC | `ai-dlc` | apo:core | oss | yes | pack core_seed |
| ATeam | `ateam` | apo:core | commercial | yes | pack core_seed |
| Barkain Workflow Orchestrator | `barkain-workflow-orchestrator` | apo:core | commercial | yes | pack core_seed |
| Cavekit v3.1 | `cavekit-v31` | apo:core | commercial | yes | pack core_seed |
| cc10x | `cc10x` | apo:core | commercial | yes | pack core_seed |
| Deepwork | `deepwork` | apo:core | commercial | yes | pack core_seed |
| Director | `director` | apo:core | oss | yes | pack core_seed |
| MetaGPT | `metagpt` | apo:core | oss | yes | pack core_seed |
| Silver Bullet | `silver-bullet` | apo:core | oss | yes | pack core_seed |
| Turboshovel | `turboshovel` | apo:core | commercial | yes | pack core_seed |
| Workflow Manager | `workflow-manager` | apo:core | commercial | yes | pack core_seed |
| BMAD-METHOD | `bmad` | sdlc-plugins:core | oss | yes | sdlc-plugins market_core (matrix) |
| Claude Harness | `claude-harness` | sdlc-plugins:core | oss | yes | sdlc-plugins market_core (matrix) |
| GSD (Get Shit Done) | `gsd` | sdlc-plugins:core | oss | yes | sdlc-plugins market_core (matrix) |
| Oh My Pi (OMP) | `oh-my-pi` | sdlc-plugins:core | oss | yes | sdlc-plugins market_core (matrix) |
| Ruflo / Claude Flow | `ruflo` | sdlc-plugins:core | oss | yes | sdlc-plugins market_core (matrix) |
| GitHub Spec Kit | `spec-kit` | sdlc-plugins:core | oss | yes | sdlc-plugins market_core (matrix) |
| SuperClaude | `superclaude` | sdlc-plugins:core | oss | yes | sdlc-plugins market_core (matrix) |
| Superpowers | `superpowers` | sdlc-plugins:core | oss | yes | sdlc-plugins market_core (matrix) |
| Zuvo | `zuvo` | sdlc-plugins:core | oss | yes | sdlc-plugins market_core (matrix) |
| Augment Cosmos | `augment-cosmos` | agentic-sdlc-saas:core | commercial | yes | agentic-sdlc-saas market_core (matrix) |
| Devin | `devin` | agentic-sdlc-saas:core | commercial | yes | agentic-sdlc-saas market_core (matrix) |
| Factory.ai | `factory-ai` | agentic-sdlc-saas:core | commercial | yes | agentic-sdlc-saas market_core (matrix) |
| Magic.dev | `magic-dev` | agentic-sdlc-saas:core | commercial | yes | agentic-sdlc-saas market_core (matrix) |
| Tembo | `tembo` | agentic-sdlc-saas:core | commercial | yes | agentic-sdlc-saas market_core (matrix) |
| Axonflow | `axonflow` | apo:adjacent | 

## Realistic charts / matrix memo (excerpt)

# Realistic charts + matrix pass

Date: 2026-07-21

## Engine policy

- `_CHART_FEAT_EQUIV = {}` (no Zero-infra → Managed hosting)
- `features.json` `supported: false` clears chart credit on regenerate
- Wave presence capped at 3 without Managed hosting
- Notable divergences: `select_notable_divergences()` subject+Jaccard dedupe

## Before → after placements (all plotted)

| Market | Vendor | Chart | Before | After | Verdict |
|---|---|---|---|---|---|
| agentic-sdlc-saas | `augment-cosmos` | MQ | (9.3, 8.6) Leaders | (9.5, 5.9) Leaders | ADJUST |
| agentic-sdlc-saas | `augment-cosmos` | GMQ | (7.9, 8.6) Leaders | (8.9, 5.4) Visionaries | ADJUST |
| agentic-sdlc-saas | `augment-cosmos` | WAVE | o=4.0 s=2.2 p=3 | o=3.5 s=2.2 p=3 | ADJUST |
| agentic-sdlc-saas | `devin` | MQ | (9.5, 8.5) Leaders | (9.5, 6.6) Leaders | ADJUST |
| agentic-sdlc-saas | `devin` | GMQ | (8.2, 8.5) Leaders | (8.4, 7.5) Leaders | ADJUST |
| agentic-sdlc-saas | `devin` | WAVE | o=4.0 s=2.2 p=3 | o=4.0 s=2.2 p=4 | ADJUST |
| agentic-sdlc-saas | `factory-ai` | MQ | (9.5, 8.7) Leaders | (9.5, 6.1) Leaders | ADJUST |
| agentic-sdlc-saas | `factory-ai` | GMQ | (8.2, 8.6) Leaders | (9.3, 6.9) Leaders | ADJUST |
| agentic-sdlc-saas | `factory-ai` | WAVE | o=4.0 s=2.2 p=3 | o=3.7 s=2.2 p=3 | ADJUST |
| agentic-sdlc-saas | `magic-dev` | MQ | (6.3, 5.3) Visionaries | (8.7, 5.6) Leaders | ADJUST |
| agentic-sdlc-saas | `magic-dev` | GMQ | (4.9, 4.6) Niche Players | (7.0, 5.0) Visionaries | ADJUST |
| agentic-sdlc-saas | `magic-dev` | WAVE | o=2.3 s=2.2 p=2 | o=2.8 s=2.2 p=2 | ADJUST |
| agentic-sdlc-saas | `tembo` | MQ | (6.5, 7.7) Leaders | (9.5, 5.7) Leaders | ADJUST |
| agentic-sdlc-saas | `tembo` | GMQ | (5.2, 6.2) Challengers | (8.8, 5.1) Visionaries | ADJUST |
| agentic-sdlc-saas | `tembo` | WAVE | o=2.8 s=2.2 p=2 | o=3.0 s=2.2 p=2 | ADJUST |
| apo | `agenthub` | MQ | (8.7, 6.2) Leaders | (5.9, 5.7) Leaders | ADJUST |
| apo | `agenthub` | GMQ | (7.3, 8.1) Leaders | (4.9, 6.1) Challengers | ADJUST |
| apo | `agenthub` | WAVE | o=3.4 s=2.2 p=3 | o=2.5 s=2.2 p=2 | ADJUST |
| apo | `agentsys` | MQ | (8.4, 5.6) Leaders | (5.8, 5.3) Visionaries | ADJUST |
| apo | `agentsys` | GMQ | (7.0, 7.5) Leaders | (4.9, 5.7) Challengers | ADJUST |
| apo | `agentsys` | WAVE | o=3.1 s=2.2 p=3 | o=2.5 s=2.2 p=2 | ADJUST |
| apo | `ai-dlc` | MQ | (9.0, 4.1) Visionaries | (6.6, 5.9) Leaders | ADJUST |
| apo | `ai-dlc` | GMQ | (6.1, 6.7) Leaders | (9.0, 3.7) Visionaries | ADJUST |
| apo | `ai-dlc` | WAVE | o=3.8

## SB chart placement (excerpt)

# Silver Bullet chart placement review (analyst-grade)

**Report:** [landscape-report.html](../landscape-report.html)  
**run_id:** `run-57f38dfa25d83cc50d224e283d4692f3` (artifacts reused; not re-derived)  
**Date:** 2026-07-21  
**Engine:** [`synthesize_landscape.py`](../../../../skills/silver-deep-research-multi-ai/scripts/synthesize_landscape.py)  
**Coords artifact:** [BEFORE-AFTER-COORDS.json](BEFORE-AFTER-COORDS.json)

---

## 1. Current placement table (AFTER adjustment)

| Market | Chart | SB (x, y) / Wave | Quadrant | Verdict |
|---|---|---|---|---|
| **APO** | MQ (Positioning) | (9.5, **8.8**) | Leaders | **ADJUST** (was 9.5, 9.5) |
| **APO** | GMQ (Vision × Execute) | (9.5, **9.0**) | Leaders | **ADJUST** (was 9.5, 9.5) |
| **APO** | Wave | offering 4.0 / strategy 3.2 / **presence 3** | — | **ADJUST** (presence was 4) |
| **sdlc-plugins** | MQ | (9.5, 9.3) | Leaders | **KEEP** |
| **sdlc-plugins** | GMQ | (9.5, 8.6) | Leaders | **KEEP** |
| **sdlc-plugins** | Wave | offering 4.0 / strategy 3.2 / **presence 3** | — | **ADJUST** (presence only) |
| **agentic-sdlc-saas** | MQ / GMQ / Wave | *not plotted* | — | **KEEP** (correctly absent) |

Axis convention (GMQ): **x = Completeness of Vision**, **y = Ability to Execute**.

---

## 2. Evidence **for** high placement

Sources: [solutions/silver-bullet/scr.md](../solutions/silver-bullet/scr.md), [solutions/silver-bullet/features.json](../solutions/silver-bullet/features.json), [comparison/comparison.json](../comparison/comparison.json).

| Capability | Evidence | Matrix / features |
|---|---|---|
| Workflow composition | SCR: 22 pre-composed workflows from 27 atomic flows | ✔ Critical |
| Atomic flow catalog | SCR: reusable atomic flows + evidence schemas | ✔ |
| Hook-enforced gates | SCR: 12 layers of SessionStart / PreToolUse / completion-audit / stop hooks | ✔ |
| Parent/child delegation | SCR: parent orchestrator + specialist workers | ✔ |
| IDE-native / multi-host | SCR: Cursor, Codex, Claude Code process

## Wave strategy spread PASS-FAIL (excerpt)

# PASS/FAIL — Wave Strategy spread fix

| Check | Result |
|-------|--------|
| Root cause identified (2-feature staircase collapse) | PASS |
| Strategy values differentiated per market (n≥2 vendors) | PASS |
| Silver Bullet remains high where justified | PASS (4.0 on process orchestrators + SDLC plugins) |
| No duplicate Wave (strategy, offering) pairs | PASS |
| Zero-infra ↛ Managed hosting equivalence preserved | PASS (unit tests) |
| Engine unit tests (`test_realistic_chart_scoring`) | PASS (6 tests) |
| landscape-report.html regenerated | PASS |
| file:// open | see FILE-RENDER.json |


Additional: HTML embed shows differentiated strategy numbers; macOS `open` exit 0. **file:// PASS**.


## Comparison matrix (excerpt)

# Comparison matrix (regenerated ticks)

Winner: **silver-bullet** | Runner-up: **gsd**

## Rankings

1. `silver-bullet` — 38
2. `gsd` — 34
3. `oh-my-pi` — 34
4. `bmad` — 32
5. `devin` — 32
6. `cc10x` — 27
7. `ruflo` — 24
8. `sdlc-plugin` — 24
9. `superpowers` — 24
10. `zuvo` — 24
11. `cursor` — 22
12. `factory-ai` — 22
13. `spec-kit` — 22
14. `superclaude` — 22
15. `augment-cosmos` — 20
16. `ai-dlc` — 19
17. `claude-code` — 17
18. `codex` — 17
19. `github-copilot` — 17
20. `conductor` — 16

## Managed hosting ticks

augment-cosmos, cognition-scout, conductor, cursor, devin, factory-ai, github-copilot, magic-dev, tembo


