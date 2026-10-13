# Consolidated Report — Canonical SDLC Process Architecture (Mid-2026)

**Research date:** 2026-07-12  
**Method:** Parallel OpenCode deep-research (`/silver:agent-opencode` + `/silver:deep-research` ultradeep) across 5 OCG models  
**Consolidation:** Synthesis of 4 complete agent runs (see [agent-comparison.md](agent-comparison.md))

| Artifact | Path |
|----------|------|
| **This report** | [consolidated-report.md](consolidated-report.md) |
| **Agent comparison** | [agent-comparison.md](agent-comparison.md) |
| **HTML SPA** | [report.html](report.html) |
| **Source: minimax-m3** | [../ocg-minimax-m3/research_report.md](../ocg-minimax-m3/research_report.md) |
| **Source: kimi-k2.7-code** | [../ocg-kimi-k2.7-code/research_report.md](../ocg-kimi-k2.7-code/research_report.md) |
| **Source: deepseek-v4-flash** | [../ocg-deepseek-v4-flash/research_report.md](../ocg-deepseek-v4-flash/research_report.md) |
| **Source: mimo-v2.5** | [../ocg-mimo-v2.5/research_report.md](../ocg-mimo-v2.5/research_report.md) |
| **Partial: qwen3.7-plus** | [../ocg-qwen3.7-plus/](../ocg-qwen3.7-plus/) |

---

## 1. Executive Summary

High-performing software organizations in mid-2026 do not run software delivery as a linear waterfall. They operate **18 concurrent Process Areas** — each with nested, evidence-backed workflows — that span strategy through retirement, with platform engineering, security, reliability, and developer experience treated as first-class capabilities rather than afterthoughts.

Four complete parallel research runs (MiniMax M3, Kimi K2.7 Code, DeepSeek V4 Flash, MiMo V2.5) independently converged on this architecture. The consensus model has four layers:

1. **Direction (PA-01..PA-04):** Strategy & portfolio, discovery & requirements, UX & design, architecture & technical design.
2. **Delivery (PA-05..PA-11):** Planning, dev environment, implementation, code review, testing, build/integration, CI/release/deploy.
3. **Feedback (PA-12..PA-16):** Platform engineering, security/compliance, SRE, observability, DevEx measurement.
4. **Sustainability (PA-17..PA-18):** Maintenance/retirement, AI-assisted/agentic engineering.

**Universal pillars** (all four agents, multiple primary sources): trunk-based development with short-lived branches; continuous integration; test automation following the testing pyramid; mandatory code review; progressive delivery (canary/blue-green/feature flags); SLO-driven reliability with error budgets; OpenTelemetry-based observability; shift-left security aligned to NIST SSDF, OWASP SAMM, and SLSA supply-chain integrity.

**Leading-edge mainstream:** Internal Developer Platforms (IDP) with golden paths; Team Topologies (stream-aligned, platform, enabling, complicated-subsystem teams); Backstage-style developer portals; DevEx measurement programs; platform-as-product operating model.

**AI integration (emerging → leading-edge):** AI coding assistants show credible individual productivity gains (e.g., GitHub/Accenture Copilot studies), but DORA 2025 research emphasizes an **amplification effect** — AI magnifies existing organizational strengths and weaknesses. DeepSeek's run quantified a **7.2% delivery stability decrease per 25% AI adoption increase** when fundamentals (small batches, robust testing, review discipline) are weak. A **verification tax** (auditing AI-generated code, larger review batches) partially offsets writing-time savings.

**Deprecated:** annual release trains, long-lived feature branches as the default model, manual QA phase-gates, big-bang migrations, story-points-as-performance-metrics, siloed ops gatekeepers.

This consolidated report is suitable for CTO/VP Engineering adoption planning at organizations from 50 to 50,000 engineers, with explicit context variations for startups, scale-ups, regulated enterprises, and safety-critical systems.

---

## 2. Research Method and Evidence Base

### 2.1 Dispatch methodology

1. **Orient:** `graphify query` on silver-agent-opencode, silver-deep-research, opencode.jsonc.
2. **Config verification:** All 5 requested `ocg-*` agents confirmed in `~/.config/opencode/opencode.jsonc` with model pins.
3. **Parallel dispatch:** `opencode run --model opencode-go/<slug> --auto --dir <repo>` per agent (primary invocation pattern; ocg-* subagents are config-defined but invoked as primary build agents per established SB dispatch note).
4. **Brief:** Identical ultradeep research brief passed to each agent ([RESEARCH-BRIEF.md](../RESEARCH-BRIEF.md)).
5. **Wall-clock:** ~30 minutes for slowest agent (Kimi K2.7); ~7 minutes for fastest complete (DeepSeek V4 Flash).

### 2.2 Evidence tiers (consensus hierarchy)

| Tier | Description | Examples |
|------|-------------|----------|
| 1 | Engineering handbooks/blogs from named orgs | Google SRE, Google eng-practices, AWS Well-Architected, Microsoft SDL, Stripe/GitHub/Netflix engineering |
| 2 | Conference/industry research | DORA capabilities, Martin Fowler, Thoughtworks Radar |
| 3 | Standards bodies | NIST SSDF, OWASP SAMM/ASVS, OpenSSF, CNCF, OpenTelemetry, SLSA |
| 4 | Surveys | DORA State of DevOps, GitHub Octoverse, Stack Overflow Developer Survey |
| 5 | Academic | Peer-reviewed with operational citation |

### 2.3 Triangulation protocol

All four complete agents required ≥2 independent sources for major claims. Kimi indexed **121 sources** and **155 evidence spans**; MiniMax **80 sources** with explicit triangulation.md; MiMo **44 sources** with classification tags; DeepSeek **25 sources** with DORA-weighted quantitative framing.

### 2.4 Known limitations (flagged by agents)

- **Public-source bias:** Apple, parts of Amazon retail, internal Meta systems under-documented.
- **Geographic bias:** US/EU cloud-native SaaS overrepresented vs. embedded/mainframe/safety-critical.
- **Temporal risk:** PA-18 (AI/agentic) evolves faster than research cycle; quarterly review recommended.
- **PA-17 gap:** Maintenance/retirement less documented in 2025–2026 primary sources than delivery areas.
- **Partial agent:** ocg-qwen3.7-plus gathered 32 sources but did not complete synthesis.

---

## 3. Canonical Process-Area Taxonomy

The 18 Process Areas below represent **unanimous consensus** across all complete agent runs.

### Layer: Direction

| ID | Process Area | Definition (consensus) | Key outputs |
|----|--------------|------------------------|-------------|
| PA-01 | Strategy, Portfolio & Product Direction | Align engineering investment with business outcomes; govern product/platform portfolio | OKRs, roadmaps, investment allocation, architecture principles |
| PA-02 | Discovery, Requirements & Product Definition | Validate problems; define valuable/feasible/viable requirements | PRDs, user stories, acceptance criteria, prioritized backlog |
| PA-03 | UX & Product Design | Research, interaction/visual design, prototyping, accessibility | Design specs, prototypes, design system contributions, WCAG compliance |
| PA-04 | Architecture & Technical Design | System structure, ADRs, non-functional requirements, threat modeling input | ADRs, architecture diagrams, API contracts, NFR specifications |

### Layer: Delivery

| ID | Process Area | Definition (consensus) | Key outputs |
|----|--------------|------------------------|-------------|
| PA-05 | Planning & Work Management | Break work into deliverable units; manage flow and dependencies | Sprint/iteration plans, kanban boards, dependency maps |
| PA-06 | Development Environment & Toolchain | Reproducible dev environments, IDE/tool standards, local parity with CI | Dev containers, toolchain docs, onboarding runbooks |
| PA-07 | Software Implementation | Write/maintain production code per standards | Merged code, feature flags, implementation docs |
| PA-08 | Code Review & Knowledge Sharing | Peer review for quality, security, knowledge transfer | Approved PRs, review comments, pairing/mob records |
| PA-09 | Testing, QE & Verification | Automated and exploratory verification at unit/integration/e2e levels | Test suites, coverage reports, quality gates |
| PA-10 | Build, Integration & Artifact Management | Compile, package, sign, store immutable artifacts | Container images, signed binaries, SBOMs |
| PA-11 | CI, Release & Deployment | Pipeline automation, progressive delivery, rollback | Deployment records, release notes, rollback runbooks |

### Layer: Feedback

| ID | Process Area | Definition (consensus) | Key outputs |
|----|--------------|------------------------|-------------|
| PA-12 | Platform Engineering & IDP | Internal platforms, golden paths, self-service infrastructure | IDP portal, paved roads, platform SLOs |
| PA-13 | Security, Privacy, Risk & Compliance | SSDF practices, threat modeling, supply chain, privacy | Security reviews, SBOMs, compliance attestations |
| PA-14 | Reliability Operations & SRE | SLOs, error budgets, incident response, capacity planning | SLO dashboards, postmortems, runbooks |
| PA-15 | Observability & Production Feedback | Traces, metrics, logs, user analytics feeding back to product | Dashboards, alerts, customer feedback loops |
| PA-16 | Measurement, DevEx & Continuous Improvement | DORA metrics, developer surveys, improvement experiments | DORA dashboards, DevEx scores, experiment results |

### Layer: Sustainability

| ID | Process Area | Definition (consensus) | Key outputs |
|----|--------------|------------------------|-------------|
| PA-17 | Maintenance, Evolution & Retirement | Tech debt management, deprecation, end-of-life | Deprecation notices, migration guides, archival |
| PA-18 | AI-Assisted / Agentic Software Engineering | Governed use of AI for code, review, test, ops; human-in-the-loop boundaries | AI usage policies, prompt libraries, verification protocols |

---

## 4. Full Workflow Library (consolidated highlights)

MiniMax M3 produced the deepest workflow catalog (~110 workflows). Below are **representative consensus workflows** per area with classification.

### PA-11: CI, Release & Deployment (universal workflows)

| Workflow | Classification | Consensus steps | KPIs |
|----------|----------------|-----------------|------|
| Trunk-based integration | Universal | Short-lived branches (≤2 days); merge to main; feature flags decouple deploy from release | Integration frequency, merge conflict rate |
| Progressive delivery | Leading-edge → universal at scale | Canary → blue/green → full; automated rollback on SLO breach | Change failure rate, MTTR |
| Release automation | Universal | CI builds on every commit; artifact immutability; signed releases | Deployment frequency, lead time for changes |

### PA-08: Code Review (universal)

| Workflow | Classification | Consensus |
|----------|----------------|-----------|
| Mandatory peer review | Universal | Every change reviewed before merge; Google eng-practices: small CLs, owner approval |
| AI-assisted review | Emerging | Copilot/CodeRabbit-style pre-review; human remains approver |
| Knowledge sharing via review | Universal | Review comments as teaching moments; style guides enforced in CI |

### PA-14: SRE (universal at scale)

| Workflow | Classification | Consensus |
|----------|----------------|-----------|
| SLO definition | Universal | User-centric SLIs; error budgets cap release velocity |
| Incident response | Universal | On-call rotation; severity classification; blameless postmortems |
| Toil reduction | Leading-edge | Automate repetitive ops; cap toil at 50% (Google SRE guidance) |

### PA-18: AI-Assisted Engineering (emerging)

| Workflow | Classification | Consensus |
|----------|----------------|-----------|
| AI code completion | Leading-edge | IDE-integrated; policy on sensitive code paths |
| Agentic multi-step coding | Emerging | Orchestrator-worker patterns; requires sandbox + verification gates |
| AI output verification | Leading-edge | Mandatory human review; test coverage requirements for AI-generated code |

*Full per-workflow metadata (RACI, anti-patterns, three tiers) is in [ocg-minimax-m3/research_report.md §4](../ocg-minimax-m3/research_report.md) and [ocg-kimi-k2.7-code/research_report.md §4](../ocg-kimi-k2.7-code/research_report.md).*

---

## 5. Cross-Area Dependency and Feedback Map

```
PA-01 Strategy ──► PA-02 Discovery ──► PA-03 UX ──► PA-04 Architecture
       │                    │                │              │
       └────────────────────┴────────────────┴──────────────┼──► PA-05 Planning
                                                            │
PA-06 DevEnv ◄── PA-12 Platform ◄───────────────────────────┤
       │                                                    │
       ▼                                                    ▼
PA-07 Implementation ──► PA-08 Review ──► PA-09 Testing ──► PA-10 Build
       │                                                    │
       └──────────────────────► PA-11 CI/Release ◄─────────┘
                                        │
                    ┌───────────────────┼───────────────────┐
                    ▼                   ▼                   ▼
              PA-14 SRE          PA-15 Observability   PA-13 Security
                    │                   │                   │
                    └──────────► PA-16 Measurement ◄─────────┘
                                        │
                    ┌───────────────────┴───────────────────┐
                    ▼                                       ▼
              PA-17 Maintenance                        PA-18 AI (overlay)
```

**Critical feedback loops (unanimous):**

- **PA-15 → PA-02/PA-05:** Production telemetry and user analytics drive discovery and prioritization.
- **PA-14 → PA-11:** Error budget exhaustion throttles release velocity.
- **PA-16 → PA-01:** DORA/DevEx metrics inform portfolio and platform investment.
- **PA-18 → PA-08/PA-09:** AI-generated code increases review and test burden (verification tax).

---

## 6. AI-Integration Layer

### 6.1 Consensus findings

| Finding | Evidence | Classification |
|---------|----------|----------------|
| AI coding assistants widely adopted | GitHub Octoverse, Stack Overflow 2025, Spotify engineering (94% report productivity gains) | Leading-edge → universal |
| Individual productivity gains real | GitHub/Accenture Copilot study (~55% faster task completion) | Leading-edge |
| Organizational stability risk | DORA 2025: 7.2% stability decrease per 25% AI adoption increase | Universal caution |
| Verification tax | ~30% developers distrust AI code; review time increases | Leading-edge |
| Agentic multi-agent patterns | Anthropic, OpenAI, Cursor operational blogs; SWE-bench as benchmark | Emerging |

### 6.2 Recommended AI governance workflows

1. **Policy boundary:** Define allowed AI use per data classification (no secrets/PII in prompts).
2. **Human-in-the-loop:** AI proposes; human approves merges and production changes.
3. **Verification gate:** AI-generated code requires equal or greater test coverage than human code.
4. **Measurement:** Track AI-assisted vs. manual change failure rates separately.
5. **Quarterly review:** PA-18 practices evolve fastest; reassess policies each quarter.

---

## 7. Deprecated or Diminishing Practices

**Unanimous across all complete agents:**

| Practice | Status | Replacement |
|----------|--------|-------------|
| Annual/quarterly big-bang releases | Deprecated | Continuous delivery, feature flags |
| Long-lived feature branches (>2 days) | Deprecated | Trunk-based development |
| Manual QA hand-off phase | Deprecated | Shift-left automated testing + exploratory QA in-flow |
| Siloed ops as deployment gatekeepers | Diminishing | You-build-it-you-run-it / SRE partnership |
| Story points as performance metric | Deprecated | Outcome metrics (DORA, business KPIs) |
| Big design up front without iteration | Diminishing | Evolutionary architecture + ADRs |
| Waterfall documentation in spirit | Deprecated | Living docs, ADRs, runbooks in repo |
| Heavy stage-gate portfolio boards | Diminishing | Continuous funding (Shape Up, empowered teams) |
| Spotify squad model as 2026 default | **Historical only** | Team Topologies; squads cited as 2014 artifact |

---

## 8. Maturity Model

Consensus three-tier model:

| Tier | Profile | Characteristics |
|------|---------|-----------------|
| **Minimum** | Startup, <10 engineers | Basic CI, code review, trunk-based, manual deploy with checklist, ad-hoc security |
| **Standard** | Growth, 10–500 engineers | Full CI/CD, automated tests, SRE practices, IDP/Backstage, SSDF-aligned security, DORA measurement |
| **Leading-edge** | Elite/large scale | Continuous deployment, platform engineering, AI-governed workflows, observability-driven development, error-budget-gated releases |

**Migration path:** Implement universal workflows in PA-07..PA-11 first, then add PA-12 (platform), PA-13..PA-14 (security/reliability), then PA-16 (measurement), then PA-18 (AI governance).

---

## 9. Role Model and Governance Implications

### 9.1 Team Topologies (consensus org model)

| Team type | Responsibility |
|-----------|----------------|
| Stream-aligned | End-to-end feature delivery for a product stream |
| Platform | IDP, golden paths, self-service infra |
| Enabling | Coaching, security champions, temporary expertise injection |
| Complicated-subsystem | Deep specialist domains (ML, payments, compliance) |

### 9.2 RACI evolution for AI era

- **Product/Engineering:** Accountable for outcomes; Responsible for AI policy compliance.
- **Platform team:** Responsible for golden paths including AI tool integration.
- **Security:** Consulted on AI data boundaries; Informed on AI-assisted change metrics.
- **SRE:** Accountable for SLOs regardless of code authorship (human or AI).

### 9.3 Governance gates (consensus)

| Gate | Trigger | Approver |
|------|---------|----------|
| Architecture | New service / significant NFR change | Staff+ engineer / arch review |
| Security | Threat model for new surface; dependency with CVE | Security champion / AppSec |
| Production deploy | Error budget available; CI green | Automated + on-call |
| AI policy exception | AI use on restricted data path | Security + legal |

---

## 10. Final Recommended Canonical Industry Standard

### 10.1 The reference model

Adopt the **18 Process Area capability model** as a **reference architecture**, not a compliance checklist. Organizations should:

1. **Map current state** against the 18 areas; score each workflow at Minimum/Standard/Leading-edge.
2. **Prioritize universal workflows** in Delivery layer (PA-05..PA-11) before investing in leading-edge AI or platform expansion.
3. **Instrument with DORA metrics** (deployment frequency, lead time, change failure rate, MTTR) plus security (SSDF practices) and reliability (SLO attainment).
4. **Establish platform engineering** when ≥3 stream-aligned teams share infrastructure concerns.
5. **Govern AI** as PA-18 overlay with explicit verification gates — treat AI as amplifier, not substitute for engineering discipline.

### 10.2 Context-specific guidance

| Context | Emphasis |
|---------|----------|
| Startup | Collapse PA-01/PA-02; Minimum tier for PA-12; defer PA-18 formal governance until AI adoption is material |
| Scale-up | Standard tier for PA-11..PA-12; hire platform team; introduce SLOs |
| Regulated enterprise | PA-13 heavyweight; formal change advisory; audit trails; SSDF + SAMM assessments |
| Safety-critical | PA-09 formal verification; PA-04 architecture rigor; limited PA-18 autonomy |

### 10.3 Open questions for follow-on research

- Enterprise AI governance frameworks maturing (NIST SSDF GenAI profile, EU AI Act operationalization).
- PA-17 maintenance/retirement evidence base still thin.
- Non-US engineering org practices (Alibaba, ByteDance, Grab) underrepresented.
- Retry ocg-qwen3.7-plus for fifth-agent triangulation completeness.

---

*Consolidated by synthesis of parallel OCG deep-research runs. Primary workflow depth: [ocg-minimax-m3](../ocg-minimax-m3/research_report.md). Primary source breadth: [ocg-kimi-k2.7-code](../ocg-kimi-k2.7-code/research_report.md). Primary AI quantification: [ocg-deepseek-v4-flash](../ocg-deepseek-v4-flash/research_report.md).*
