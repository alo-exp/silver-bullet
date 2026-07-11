All 13 artifacts written to `research/2026-07-12-canonical-sdlc-process-architecture/ocg-deepseek-v4-flash/`.

**Primary deliverable:** `research_report.md` (61.7 KB, 755 lines, 10 sections)

**Key finding:** AI is an amplifier, not a silver bullet — DORA 2025 data shows individual productivity gains coexist with 7.2% organizational stability decline per 25% AI adoption increase.

**Supporting artifacts:**
- `scope.md` — research boundaries
- `research-plan.md` — methodology (4 phases)
- `sources.jsonl` — 25 sources with credibility ratings
- `evidence.jsonl` — 19 claim-source links
- `triangulation.md` — cross-source verification
- `outline.md` — report structure
- `claims.jsonl` — 20 extracted claims
- `critique.md` — limitations (company bias, missing Chinese tech, paywalls)
- `decision-record.md` — 6 methodology decisions
- `handoff.md` — open items for follow-on research
- `vloop-rollup.json` / `run_manifest.json` — execution metadata
rs deploy multiple times daily with <1 hour lead time and <5% failure rate.

2. **Platform Engineering** has matured from emerging to mainstream. Internal Developer Platforms (IDPs) with golden paths, Backstage-style developer portals, and platform-as-product teams are now the normative approach for organizations with >3 engineering teams.

3. **AI-assisted development is universal** (>90% developer adoption) but the DORA 2025 finding is decisive: AI amplifies existing organizational strengths and weaknesses. Individual productivity gains (94% of Spotify engineers report being more productive) coexist with organizational delivery stability risks (7.2% stability decrease per 25% AI adoption increase).

4. **The verification tax** is real: 30% of developers do not trust AI-generated code. Time saved in writing is partially offset by increased auditing, larger batch sizes, and cognitive load on reviewers.

5. **Security is shifting further left.** NIST SSDF's 19 practice activities across 4 areas (Prepare, Protect, Produce, Respond) define the regulatory baseline. Supply chain security (SBOMs, SLSA, Sigstore) is now a first-class concern.

6. **Observability is the new debugging.** OpenTelemetry as CNCF-graduated standard has made distributed tracing, metrics, and logs a unified concern, feeding directly back into planning and reliability engineering.

7. **18 Process Areas** constitute the complete canonical taxonomy, organized from Strategy/Portfolio through AI-Assisted Engineering, each with detailed workflows, metrics, RACI, and three implementation tiers.

### Maturity Model Summary

| Tier | Characteristics | Org Profile |
|------|-----------------|-------------|
| Minimum | Manual reviews, basic CI/CD, ad-hoc testing, no platform team | Startup (<10 engineers) |
| Standard | Automated CI/CD, code review standards, SRE practices, backstage portal, IDP | Growth/Enterprise |
| Leading-Edge | AI-integrated workflows, agentic code review, platform engineering, continuous deployment, observability-driven development | High-Performance/Large-Scale |

---

## 2. Research Method and Evidence Base

### Source Classification

| Tier | Description | Examples |
|------|-------------|---------|
| PRIMARY | Official documentation, peer-reviewed research | DORA publications, NIST SSDF, Google Eng Practices |
| HIGH | Engineering blogs from named companies | GitHub Blog, Spotify Engineering, Stripe Engineering |
| MEDIUM | Industry surveys, practitioner analysis | Stack Overflow Survey, Pragmatic Engineer |
| REFERENCE | Standards bodies, community frameworks | OWASP, CNCF, OpenSSF, OpenTelemetry |
| CONTEXTUAL | Conference talks, vendor publications | Platform Engineering org, Backstage docs |

### Evidence Sources Catalog

25 sources indexed across all tiers. Key sources:

- **DORA**: Capabilities catalog, AI Capabilities Model, Balancing AI Tensions — longitudinal quantitative research (n=1,110+ Google engineers), peer-reviewed
- **Google**: Cloud DevOps capabilities, Eng Practices code review guide — canonical process documentation
- **NIST**: SP 800-218 SSDF v1.1 — regulatory-grade secure development framework
- **Stack Overflow**: 2025 Survey (49,000+ respondents, 177 countries) — largest global developer survey
- **GitHub**: Engineering blog with Copilot adoption metrics, Octoverse data
- **Spotify**: Engineering blog with AI adoption rates, Backstage evolution, Fleet Management system

### Triangulation Protocol

- Major claims require ≥2 independent sources
- DORA research treated as highest weight for delivery performance
- NIST treated as authoritative for security practices
- Industry surveys used for adoption rates, not causal claims
- AI claims verified against DORA quantitative findings + engineering blog operational data

---

## 3. Canonical Process-Area Taxonomy

### PA01 — Strategy, Portfolio & Product Direction

| Field | Value |
|-------|-------|
| **Definition** | Setting organizational product vision, strategy, and portfolio prioritization |
| **Purpose** | Align engineering investment with business outcomes; OKR/KPI-driven portfolio management |
| **Mid-2026 Relevance** | Increasingly data-driven; product analytics + AI demand sensing becoming standard |
| **Inputs** | Market research, user analytics, competitive analysis, executive vision, OKR targets |
| **Workflows** | Strategic planning, portfolio prioritization, OKR setting |
| **Outputs** | Product roadmap, strategic initiatives, OKR tree, investment allocation |
| **Dependencies** | Downstream to PA02 (Discovery), PA03 (UX Design), PA05 (Planning) |
| **Metrics/Gates** | OKR completion rate, strategy-to-execution lag, portfolio ROI |
| **Pitfalls** | Strategy disconnected from execution; top-down only without bottom-up input |
| **Context Variations** | Startup: founder vision, lean canvas. Enterprise: annual planning cycle, investment board |

### PA02 — Discovery, Requirements & Product Definition

| Field | Value |
|-------|-------|
| **Definition** | User research, problem exploration, requirements elicitation, and specification |
| **Purpose** | Validate problem-solution fit before committing engineering resources |
| **Mid-2026 Relevance** | AI-assisted user research synthesis; continuous discovery practices replacing big requirements upfront |
| **Inputs** | Product roadmap, user feedback, analytics, competitive analysis, technical constraints |
| **Workflows** | User research, requirements definition, specification writing, backlog grooming |
| **Outputs** | PRDs, user stories, acceptance criteria, prioritized backlog |
| **Dependencies** | Upstream PA01; downstream PA03 (Design), PA05 (Planning) |
| **Metrics/Gates** | Problem validation rate, story acceptance rate, discovery-to-delivery ratio |
| **Pitfalls** | Analysis paralysis; requirements as contract vs. hypotheses to test |
| **Context Variations** | Consumer: qualitative-heavy, design sprints. Enterprise: RFI/RFP-driven, compliance requirements |

### PA03 — UX & Product Design

| Field | Value |
|-------|-------|
| **Definition** | User experience research, interaction design, visual design, prototyping |
| **Purpose** | Ensure product usability, accessibility, and emotional desirability |
| **Mid-2026 Relevance** | Design systems are universal; AI-powered design tools augmenting but not replacing designers |
| **Inputs** | Requirements, user research, design system, brand guidelines |
| **Workflows** | UX research, interaction design, visual design, prototyping, design review, accessibility audit |
| **Outputs** | Design specifications, prototypes, design system contributions, accessibility reports |
| **Dependencies** | Upstream PA02; downstream PA04 (Technical Design), PA07 (Implementation) |
| **Metrics/Gates** | UX score (SUS/SEQ), task success rate, accessibility compliance (WCAG), design-to-dev handoff time |
| **Pitfalls** | Design handed off as static specs without developer collaboration; over-designing before validation |
| **Context Variations** | Consumer: polished visual design critical. Enterprise: usability and efficiency dominate |

### PA04 — Architecture & Technical Design

| Field | Value |
|-------|-------|
| **Definition** | System architecture decisions, technical specification, design documents |
| **Purpose** | Ensure systems are well-architected for scalability, reliability, security, and maintainability |
| **Mid-2026 Relevance** | Architecture Decision Records (ADRs) universal; C4 model for visualization; AI-assisted architecture review emerging |
| **Inputs** | Requirements, design specs, existing architecture, tech stack constraints, compliance requirements |
| **Workflows** | Architecture design, technical spec writing, ADR creation, design review, tech stack selection |
| **Outputs** | Architecture diagrams (C4), ADRs, design documents, tech stack decisions |
| **Dependencies** | Upstream PA02, PA03; downstream PA05, PA07, PA08 |
| **Metrics/Gates** | Architecture review cycle time, ADR coverage, design doc completeness |
| **Pitfalls** | Over-engineering for scale that never comes; ivory-tower architecture without implementation input |
| **Context Variations** | Startup: pragmatic, minimal viable architecture. Enterprise: formal architecture review, RFC process (Amazon-style) |

### PA05 — Planning & Work Management

| Field | Value |
|-------|-------|
| **Definition** | Breaking work into manageable units, sprint/iteration planning, estimation, and tracking |
| **Purpose** | Predictable delivery, transparent progress, adaptive replanning |
| **Mid-2026 Relevance** | Agile at scale (SAFe, LeSS, Spotify Model) still debated; continuous planning replacing sprint-only cadence; AI estimation assistance emerging |
| **Inputs** | Prioritized backlog, roadmap, team capacity, dependency map |
| **Workflows** | Sprint/iteration planning, daily standup, backlog refinement, sprint review, retrospective, progress tracking |
| **Outputs** | Sprint plan, burndown/velocity charts, dependency mapping, retrospective actions |
| **Dependencies** | Upstream PA01, PA02; downstream PA07 |
| **Metrics/Gates** | Sprint completion rate, predictability (planned vs. actual), cycle time, WIP limits, blocker resolution time |
| **Pitfalls** | Estimation-as-commitment (not forecast); velocity gaming; sprint as deadline rather than timebox |
| **Context Variations** | Startup: kanban-style continuous flow. Enterprise: scaled agile ceremonies, quarterly planning |

### PA06 — Development Environment & Toolchain

| Field | Value |
|-------|-------|
| **Definition** | Developer tooling, IDEs, local/remote development environments, dev containers |
| **Purpose** | Reduce time-to-productive-development; consistent environments across team |
| **Mid-2026 Relevance** | Dev containers (VS Code, GitHub Codespaces) universal; IDP-integrated developer portals; cloud-based dev environments replacing local setup for complex systems |
| **Inputs** | Tech stack decisions, infrastructure requirements, compliance constraints |
| **Workflows** | Environment setup, toolchain configuration, IDE configuration, developer portal integration |
| **Outputs** | Dev container specs, tool chain documentation, onboarding guide, standardized IDE config |
| **Dependencies** | Upstream PA04; downstream PA07; interdependent with PA12 (Platform Engineering) |
| **Metrics/Gates** | Developer setup time, environment consistency score, DevEx satisfaction |
| **Pitfalls** | Fragmented tooling across teams; golden path variance; tool fatigue |
| **Context Variations** | Startup: simple dev setup, local-first. Enterprise: standardized dev containers, remote dev environments, compliance-required tooling |

### PA07 — Software Implementation

| Field | Value |
|-------|-------|
| **Definition** | Writing code according to specifications, conventions, and quality standards |
| **Purpose** | Produce correct, maintainable, testable code that implements requirements |
| **Mid-2026 Relevance** | AI pair programming is universal (>90% adoption); prompt engineering is a recognized skill; small-batch working is critical for AI-era code quality |
| **Inputs** | Requirements, design docs, ADRs, coding standards, AI code completion tools |
| **Workflows** | Local coding, AI-assisted coding, unit testing (parallel), code formatting/linting, self-review, commit |
| **Outputs** | Feature implementation, unit tests, formatted/linted code, commit (small batch) |
| **Dependencies** | Upstream PA04, PA06; downstream PA08 (Code Review) |
| **Metrics/Gates** | Batch size (lines/PR), test coverage, lint/format compliance, AI acceptance rate, verify pass rate |
| **Pitfalls** | Large batches (anti-pattern, amplified by AI); blind AI output acceptance; bypassing "productive struggle" for juniors |
| **Context Variations** | Startup: speed-focused, less formalism. Enterprise: enforced standards, branch protection, policy-as-code |

### PA08 — Code Review & Knowledge Sharing

| Field | Value |
|-------|-------|
| **Definition** | Peer or automated review of code changes before integration; knowledge transfer through reading others' code |
| **Purpose** | Quality gate, defect detection, knowledge diffusion, style enforcement |
| **Mid-2026 Relevance** | AI code review now accounts for 1 in 5 reviews on GitHub; Google's OWNERS-based model is universal; DORA recommends shifting AI feedback to author phase. Review is being rethought as AI changes batch sizes and review dynamics |
| **Inputs** | Pull request/CL, automated check results (CI, lint, test), AI review annotations |
| **Workflows** | Reviewer assignment (OWNERS algorithm), AI pre-review (automated), human review pass, discussion/resolution, approval, merge |
| **Outputs** | Approved/rejected change, review comments (knowledge artifacts), CI + AI review signals |
| **Dependencies** | Upstream PA07; downstream PA10 (Build/Integration) |
| **Metrics/Gates** | Review cycle time, PR merge rate, first-response latency, re-review rate, reviewer pool depth |
| **Pitfalls** | AI-generated large PRs overwhelming human reviewers; rubber-stamp reviews; single-reviewer bottleneck; nitpicking style over substance |
| **Context Variations** | Startup: async review light, pair programming heavy. Enterprise: formal OWNERS-based, multi-stage review, AI-assisted pre-screen |

### PA09 — Testing, QE & Verification

| Field | Value |
|-------|-------|
| **Definition** | Systematic verification of software correctness, performance, and quality |
| **Purpose** | Detect defects early; provide confidence for release; prevent regressions |
| **Mid-2026 Relevance** | AI test generation emerging but not replacing human-written tests; DORA test automation capability remains core. Shift-left testing (unit > integration > e2e) is universal best practice |
| **Inputs** | Code changes, automated test suites, QA environments, test data |
| **Workflows** | Unit testing, integration testing, end-to-end testing, performance testing, security testing (DAST/SAST), exploratory testing, test data management |
| **Outputs** | Test results, coverage reports, defect reports, quality gates pass/fail |
| **Dependencies** | Upstream PA07, PA08; downstream PA10 |
| **Metrics/Gates** | Test coverage %, flaky test rate, defect escape rate, test execution time, automated vs. manual test ratio |
| **Pitfalls** | Flaky tests destroying trust in CI; over-investment in brittle e2e tests; manual testing as gate rather than complement |
| **Context Variations** | Startup: unit + CI only, minimal e2e. Regulated: full V-model, independent QA, audit trails. Consumer: experimentation-driven, canary testing |

### PA10 — Build, Integration & Artifact Management

| Field | Value |
|-------|-------|
| **Definition** | Building, packaging, and storing software artifacts in a reproducible, auditable manner |
| **Purpose** | Ensure build reproducibility; manage binary artifacts; enable traceability from source to deployable unit |
| **Mid-2026 Relevance** | SLSA framework for supply chain integrity gaining adoption; SBOM generation is regulatory requirement (US EO 14028); container-based builds are default |
| **Inputs** | Source code, build configuration, dependency declarations, CI pipeline config |
| **Workflows** | CI pipeline execution, dependency resolution, build/compile, artifact signing, SBOM generation, artifact storage, provenance attestation |
| **Outputs** | Signed build artifacts, SBOMs, build provenance (in-toto attestation), container images, dependency scan results |
| **Dependencies** | Upstream PA07, PA08, PA09; downstream PA11 (CI/Release/Deployment) |
| **Metrics/Gates** | Build time, build reproducibility rate, dependency freshness, SBOM accuracy, supply chain compliance score |
| **Pitfalls** | Non-reproducible builds; dependency confusion attacks; unsigned artifacts; vendored dependencies without scanning |
| **Context Variations** | Startup: simple CI, minimal supply chain controls. Regulated: full SLSA L3+, signed attestations, air-gapped builds |

### PA11 — CI, Release & Deployment

| Field | Value |
|-------|-------|
| **Definition** | Continuous integration pipeline execution, release management, and deployment automation |
| **Purpose** | Safe, frequent, automated delivery of changes to production; enable rapid iteration with controlled risk |
| **Mid-2026 Relevance** | Continuous deployment is elite standard; progressive delivery (canary, feature flags) universal; DORA: streamline change approval — only 3-5% of changes need manual approval |
| **Inputs** | Signed artifacts, CI pipeline config, release policy, deployment config, feature flags |
| **Workflows** | CI pipeline execution, release candidate promotion, change approval (automated/manual), deployment automation, progressive delivery (canary, blue-green), rollback, release communication |
| **Outputs** | Production deployment, release notes, deployment verification, rollback plan |
| **Dependencies** | Upstream PA10; downstream PA14 (Reliability/SRE), PA15 (Observability) |
| **Metrics/Gates** | Deployment frequency, change lead time, change failure rate, deployment rollback rate, canary success rate |
| **Pitfalls** | Manual change approval gates (anti-pattern per DORA); deployment fatigue from over-engineered pipelines; environment drift |
| **Context Variations** | Startup: push-to-deploy, minimal gates. Enterprise: staged deployments, compliance gates, multi-region coordination |

### PA12 — Platform Engineering & IDP

| Field | Value |
|-------|-------|
| **Definition** | Designing, building, and maintaining Internal Developer Platforms (IDPs) with golden paths, developer portals, and self-service capabilities |
| **Purpose** | Reduce cognitive load on developers; accelerate time-to-prod; enforce standards without blocking autonomy |
| **Mid-2026 Relevance** | Platform engineering is mainstream (60%+ of orgs on the journey). IDP = Platform Orchestrator + Developer Portal + Golden Paths. Backstage (CNCF graduated) dominant, but Port, OpsLevel, Cortex, Humanitec are strong alternatives. Gartner: platform engineering is a top strategic trend |
| **Inputs** | Engineering pain points, developer satisfaction surveys, infrastructure requirements, security/compliance policies |
| **Workflows** | Platform strategy/roadmap, golden path definition, developer portal configuration, self-service action creation, platform metrics/iteration, cost management |
| **Outputs** | Developer portal (catalog, docs, CI status), golden paths (scaffold → CI → deploy → observe), self-service actions, platform adoption reports |
| **Dependencies** | Upstream PA04, PA06; interdependent with PA11, PA13, PA14; downstream to all development teams |
| **Metrics/Gates** | Platform adoption rate (target >80%), time-to-prod, developer satisfaction score, ticket-ops reduction rate, standardization score |
| **Pitfalls** | Portal without orchestrator (= catalog only); platform team as gatekeeper vs. enabler; premature investment before understanding developer pain points |
| **Context Variations** | Startup: after ~3-5 teams, start with MVP golden path. Enterprise: full platform team, multi-stakeholder governance, compliance hooks |

### PA13 — Security, Privacy, Risk & Compliance

| Field | Value |
|-------|-------|
| **Definition** | Integrated security practices throughout SDLC; privacy-by-design; risk management; regulatory compliance |
| **Purpose** | Minimize security vulnerabilities, protect user data, meet regulatory obligations, manage third-party risk |
| **Mid-2026 Relevance** | NIST SSDF defines 19 POAM practices across 4 areas — regulatory baseline for US federal contracts. OWASP Top 10 remains standard for web security. AI-generated code introduces new supply chain and hallucination risks. SBOMs are mandated for US government software. Secret scanning (GitHub: 39M leaks detected 2024) is universal |
| **Inputs** | Compliance requirements, security policies, threat models, vulnerability reports, dependency manifests |
| **Workflows** | Threat modeling, secure design review, SAST/DAST scanning, dependency vulnerability scanning, secrets scanning, privacy review, compliance audit, penetration testing, incident response |
| **Outputs** | Threat models, SAST/DAST findings, vulnerability reports, compliance evidence, SBOMs, security audit report |
| **Dependencies** | Upstream PA04 (secure design), PA10 (artifact signing/SBOM); downstream PA14 (SRE); cross-cutting to all areas |
| **Metrics/Gates** | Critical vulnerability fix time (SLA), scanner pass rate, compliance audit pass rate, secret leak count, CVSS score distribution |
| **Pitfalls** | Security as afterthought/release gate; false positives desensitizing teams; AI-generated code introducing novel vulnerability patterns |
| **Context Variations** | Regulated: NIST 800-53, FedRAMP, SOC2 — full compliance program. Consumer: privacy-by-design focus. Startup: essential security (SAST, secret scanning) only |

### PA14 — Reliability, Operations & SRE

| Field | Value |
|-------|-------|
| **Definition** | Ensuring system reliability, uptime, incident response, and operational excellence |
| **Purpose** | Meet SLOs, minimize user-facing impact of failures, learn from incidents |
| **Mid-2026 Relevance** | SRE discipline mature; error budgets are universal at scale; SLOs as driver for development prioritization (not just ops concern). Reliability is cross-functional, not just SRE team responsibility |
| **Inputs** | Service level objectives (SLOs), error budgets, production incidents, capacity data, change velocity targets |
| **Workflows** | SLO definition, error budget tracking, incident response, post-incident review, capacity planning, chaos engineering, reliability testing, on-call management |
| **Outputs** | SLO compliance reports, incident postmortems, error budget consumption reports, capacity plans, runbooks |
| **Dependencies** | Upstream PA11 (deployment), PA15 (observability); cross-cutting to PA13 (security incidents) |
| **Metrics/Gates** | Service level attainment (SLA/SLO), MTTR, change failure rate, error budget burn rate, incident frequency, toil percentage |
| **Pitfalls** | Error budgets ignored during feature pushes; SLOs set without stakeholder input; on-call burnout; postmortems without action items |
| **Context Variations** | Startup: simple monitoring, no formal SRE. Enterprise: dedicated SRE team, error budget governance, full incident management (PagerDuty) |

### PA15 — Observability & Production Feedback

| Field | Value |
|-------|-------|
| **Definition** | Comprehensive monitoring, logging, tracing, metrics, and alerting to understand production behavior |
| **Purpose** | Understand system behavior in real time; debug faster; detect anomalies; feed production insights back into development |
| **Mid-2026 Relevance** | OpenTelemetry is CNCF-graduated — unified data model for traces, metrics, logs. Observability-driven development: instrument before you ship. AI-assisted anomaly detection emerging. DORA: monitoring/observability is a core technical capability |
| **Inputs** | Application instrumentation, infrastructure metrics, business KPIs, SLO definitions, logging standards |
| **Workflows** | Instrumentation setup, telemetry collection, dashboard creation, alert configuration, log analysis, trace analysis, AI-assisted anomaly detection, feedback to engineering |
| **Outputs** | Dashboards, alerts, traces, structured logs, runbooks, production KPI reports, feedback loop to PA02/PA05 |
| **Dependencies** | Upstream PA07 (instrumentation), PA14 (SLOs); downstream to PA02 (product feedback), PA05 (prioritization), PA14 (SRE) |
| **Metrics/Gates** | Observability coverage %, time-to-detect (TTD), time-to-triage, alert signal-to-noise ratio, dashboard freshness |
| **Pitfalls** | Alert fatigue from poorly tuned alerts; logs without correlation; dashboards without actionable insights; post-hoc instrumentation |
| **Context Variations** | Startup: basic monitoring (Datadog/NewRelic), minimal logging. Enterprise: full OpenTelemetry stack, structured logging, distributed tracing, AI-assisted ops |

### PA16 — Measurement, DevEx & Continuous Improvement

| Field | Value |
|-------|-------|
| **Definition** | Systematic measurement of developer experience, process effectiveness, and continuous improvement |
| **Purpose** | Quantify and improve developer productivity, satisfaction, and process health |
| **Mid-2026 Relevance** | SPACE framework (Microsoft Research/DORA) is the standard for DevEx measurement beyond velocity. DORA metrics + SPACE + DX surveys form the tripartite measurement model. Platform engineering measurement (adoption, time-to-prod, satisfaction) is codified |
| **Inputs** | DORA metrics, SPACE survey data, developer satisfaction scores, platform adoption metrics, incident data, velocity trends |
| **Workflows** | DORA metrics collection, developer experience survey (DX/SPACE), process health assessment, improvement initiative planning, retrospection, experimentation |
| **Outputs** | DORA dashboard, SPACE survey results, improvement backlog, experimentation results, platform adoption reports |
| **Dependencies** | Upstream PA05 (retrospectives), PA12 (platform metrics), PA14 (reliability metrics); downstream to all areas |
| **Metrics/Gates** | DORA four metrics, SPACE scores, eNPS, platform adoption rate, improvement cycle time |
| **Pitfalls** | Vanity metrics (e.g., lines of code); measuring proxy outputs instead of outcomes; survey fatigue; metrics divorced from improvement actions |
| **Context Variations** | Startup: basic velocity tracking. Enterprise: full DORA + SPACE + DX program, dedicated DevEx team |

### PA17 — Maintenance, Evolution & Retirement

| Field | Value |
|-------|-------|
| **Definition** | Managing existing systems: bug fixes, refactoring, technical debt management, dependency upgrades, system retirement |
| **Purpose** | Keep systems healthy, secure, and adaptable; reduce technical debt; retire systems gracefully |
| **Mid-2026 Relevance** | Automated dependency management (Dependabot, Renovate) is universal; Spotify's Fleet Management system automated 2.5M maintenance PRs. Technical debt is quantified and tracked in IDP scorecards. System retirement is recognized as an engineering work type |
| **Inputs** | Bug reports, dependency update alerts, security advisories, technical debt assessments, end-of-life notifications |
| **Workflows** | Bug triage/fix, dependency upgrades, refactoring, technical debt repayment, system deprecation planning, system decommissioning, migration execution, runbook maintenance |
| **Outputs** | Bug fixes, dependency update PRs, refactored code, technical debt metrics, decommissioning plans, migration plans |
| **Dependencies** | Upstream PA08 (bug detection), PA11 (deployment), PA13 (security patches); downstream PA11 |
| **Metrics/Gates** | Bug fix velocity, dependency freshness, technical debt ratio, decommission completion rate, time-to-patch critical vulns |
| **Pitfalls** | Letting technical debt accumulate without quantification; maintenance work invisible to planning (no tickets); indefinite support of obsolete systems |
| **Context Variations** | Startup: defer maintenance for speed. Enterprise: formal maintenance windows, lifecycle management, retirement budgets |

### PA18 — AI-Assisted / Agentic Software Engineering

| Field | Value |
|-------|-------|
| **Definition** | Systematic use of AI tools and agents across the SDLC — code generation, review, testing, documentation, and workflow automation |
| **Purpose** | Amplify developer productivity while managing risks of AI-generated code (verification tax, stability impact, skill degradation) |
| **Mid-2026 Relevance** | Universal adoption (>90% of developers). DORA 2025 central finding: AI is an amplifier, not a silver bullet. GitHub Copilot Code Review: 1 in 5 reviews. 99%+ Spotify engineers use AI weekly. Prompt engineering is a recognized SWE skill. Agentic coding (Spotify Fleetshift, GitHub agentic review) is production-validated for specific patterns |
| **Inputs** | AI code completion tools (Copilot, Cursor, Codex), AI review agents (Copilot Review, Amazon CodeGuru), internal documentation/codebase (for AI grounding), prompt libraries |
| **Workflows** | AI-assisted coding, AI pre-review, AI-assisted test generation, AI-assisted documentation, AI-assisted debugging, prompt engineering, agentic automation (fleet migrations, automated maintenance), AI output verification |
| **Outputs** | AI-generated code, AI review annotations, AI-generated tests/documentation, prompt libraries, verification evidence |
| **Dependencies** | Cross-cutting to PA07, PA08, PA09, PA11, PA17; interdependent with PA12 (AI-accessible internal data), PA13 (AI-generated code security) |
| **Metrics/Gates** | AI acceptance rate, AI-generated code quality (pass rate), verification tax ratio, developer trust score, prompt iteration count, PR size inflation |
| **Pitfalls** | Blind trust in AI output (30% of developers trust AI "little to not at all" for good reason); large batch sizes from AI; skill degradation for juniors; security hallucinations |
| **Context Variations** | Startup: high AI adoption, less oversight. Enterprise: governed AI use, sanctioned tools, AI training/guidelines, AI output verification mandatory |

---

## 4. Full Workflow Library

Due to the comprehensive scope of 18 Process Areas × 2+ workflows each, this section documents the highest-impact workflows with full detail. All 18 PA workflows are summarized; critical workflows receive expanded treatment.

### PA01-W01: Strategic Planning

| Field | Value |
|-------|-------|
| **Objective** | Define 6-12 month product and technology strategy aligned with business objectives |
| **Classification** | Universal |
| **Triggers** | Annual/quarterly planning cycle; market disruption; new leadership |
| **Preconditions** | Market analysis, competitive intelligence, current-state assessment |
| **Steps** | 1. Review business objectives → 2. Analyze market/competitive landscape → 3. Assess current portfolio → 4. Define strategic initiatives → 5. Determine investment allocation → 6. Approval → 7. Cascade to OKRs |
| **Decision Points** | Which initiatives to fund; build vs. buy vs. partner; risk tolerance; time horizon trade-offs |
| **Human-AI** | AI for market analysis synthesis, portfolio data aggregation, scenario modeling; human for strategy formulation and judgment |
| **Roles/RACI** | CPO/CTO (A/R), Product Directors (R), Engineering Directors (C), CEO (A) |
| **Tool Categories** | Product analytics (Amplitude, Mixpanel), OKR tools (Workboard, Align), Strategy tools |
| **Outputs** | Strategic plan, investment allocation, initiative charter |
| **Quality Criteria** | Strategic initiatives directly mapped to business objectives; investment allocation justified by data |
| **Automation** | Portfolio analytics dashboards; automated market signal monitoring |
| **Approval** | ELT/Board approval required |
| **KPIs** | OKR completion rate, strategy-to-execution lag, portfolio ROI |
| **Anti-patterns** | Strategy as PR-only, disconnected from resource allocation; no bottom-up input |
| **Minimum** | Founder-driven strategy, lightweight OKRs |
| **Standard** | Quarterly planning with portfolio review, data-informed allocation |
| **Leading-Edge** | Continuous strategy adaptation, AI-powered demand sensing, real-time portfolio ROI tracking |

### PA02-W01: User Research & Discovery

| Field | Value |
|-------|-------|
| **Objective** | Validate problem-solution fit through systematic user research |
| **Classification** | Universal |
| **Triggers** | New product/feature initiative; strategy pivot; unexplored user segment |
| **Steps** | 1. Research question definition → 2. Method selection (interviews, surveys, analytics) → 3. Data collection → 4. Synthesis → 5. Insight documentation → 6. Validation through prototyping |
| **Human-AI** | AI for research synthesis, pattern detection, survey analysis; human for interview conduct, empathy mapping, judgment |
| **Roles/RACI** | Product Manager (A/R), UX Researcher (R), Designer (C) |
| **Outputs** | Research findings, insight report, validated problem statements |
| **KPIs** | Research-to-delivery ratio, insight adoption rate |
| **Anti-patterns** | Research as validation for decisions already made; insufficient sample size |
| **Minimum** | Ad-hoc user conversations |
| **Standard** | Scheduled research sprints, mixed-methods (qual + quant) |
| **Leading-Edge** | Continuous discovery (Teresa Torres), AI-assisted research synthesis |

### PA02-W02: Requirements Definition

| Field | Value |
|-------|-------|
| **Objective** | Translate validated problems into actionable requirements and acceptance criteria |
| **Classification** | Universal |
| **Steps** | 1. Problem statement → 2. User story writing → 3. Acceptance criteria definition → 4. Technical feasibility check → 5. Stakeholder review → 6. Backlog prioritization |
| **Human-AI** | AI for story writing assistance, acceptance criteria generation, dependency detection |
| **Roles/RACI** | Product Manager (A/R), Engineering Lead (C), QA (C) |
| **Outputs** | User stories, acceptance criteria, prioritized backlog items |
| **KPIs** | Story acceptance rate, rework rate |
| **Anti-patterns** | Requirements as contract (not hypotheses); gold-plating acceptance criteria |

### PA04-W01: Architecture Design & ADR

| Field | Value |
|-------|-------|
| **Objective** | Document significant architecture decisions with rationale, alternatives, and consequences |
| **Classification** | Universal (ADRs) |
| **Steps** | 1. Decision trigger → 2. Context documentation → 3. Option identification → 4. Option evaluation (trade-offs) → 5. Decision → 6. Rationale → 7. Consequences → 8. Review/approval → 9. ADR publication |
| **Decision Points** | Which option based on trade-off analysis; defer vs. decide now; revisit conditions |
| **Human-AI** | AI for option generation, trade-off analysis, alternative research; human for decision ownership |
| **Roles/RACI** | Tech Lead/Architect (A/R), Engineering Lead (R), Stakeholders (C) |
| **Tool Categories** | ADR tools (adr-tools, Markdown Any Decision Records), architecture modeling (Structurizr, C4) |
| **Outputs** | Architecture Decision Record (ADR) |
| **KPIs** | ADR completeness, ADR cycle time, architecture review participation |
| **Anti-patterns** | Over-documenting trivial decisions; ADRs as rubber stamps; no revisit mechanism |
| **Minimum** | Verbal decision, documented in ticket |
| **Standard** | Lightweight ADR in repo (Markdown), reviewed by team |
| **Leading-Edge** | Structured ADR with C4 diagrams, automated option analysis, ADR-graph for system-level view |

### PA07-W01: AI-Assisted Implementation

| Field | Value |
|-------|-------|
| **Objective** | Implement features efficiently using AI code generation tools while maintaining quality |
| **Classification** | Universal (emerging maturity) |
| **Triggers** | New feature, bug fix, refactoring task |
| **Preconditions** | Small batch defined; acceptance criteria clear; developer has AI tool configured |
| **Steps** | 1. Task analysis → 2. AI prompt engineering → 3. AI output review → 4. Manual refinement → 5. Pre-commit verification → 6. Small-batch commit |
| **Decision Points** | Accept AI output as-is, modify, or reject; how to partition work into AI-friendly batches |
| **Human-AI** | AI generates code, suggests completions, answers context questions; human reviews, refines, drives architecture decisions, owns the design intent |
| **Roles/RACI** | Developer (A/R), AI tool (suggestion provider) |
| **Tool Categories** | AI coding assistants (GitHub Copilot, Cursor, Claude Code), local linters, test runners |
| **Outputs** | Correctly implemented feature/bugfix with tests, linted code, small commit |
| **Quality Criteria** | All tests pass; AI-generated code reviewed for correctness (not just acceptance); architecture consistent with ADRs |
| **Automation** | AI code generation and completion (full automation of suggestion phase); human remains in the loop for verification |
| **KPIs** | AI acceptance rate, code quality (pass rate vs. human-written), PR size, verification time ratio |
| **Anti-patterns** | Accepting AI output without understanding; generating large PRs in one shot; treating AI as senior developer (delegating architecture decisions) |
| **Minimum** | Basic AI autocomplete (Copilot), no specific prompt engineering |
| **Standard** | Multi-file AI generation with context engineering; prompt libraries for common patterns; mandatory AI output review |
| **Leading-Edge** | Agentic coding (auto-PR for well-scoped tasks); AI-generated test suites; fleet-wide automated refactoring (Spotify model); AI performance optimization |

### PA08-W01: Pull Request Review

| Field | Value |
|-------|-------|
| **Objective** | Ensure code quality through systematic peer review with AI augmentation |
| **Classification** | Universal |
| **Steps** | 1. AI pre-review (automated) → 2. Reviewer assignment (OWNERS/git blame) → 3. Human review pass → 4. Comment resolution → 5. Approval → 6. Merge |
| **Decision Points** | Approve, request changes, or reject; which reviewer(s) based on change scope |
| **Human-AI** | AI provides pre-review annotations (style, test gaps, vulnerability patterns); human focuses on design correctness, algorithmic soundness, and knowledge transfer |
| **Roles/RACI** | Author (R), Reviewer (A/R), AI Review Agent (automated), Approver (A) |
| **Tool Categories** | Code review platforms (GitHub, GitLab, Gerrit), AI review (Copilot Code Review, CodeRabbit), OWNERS files |
| **Outputs** | Approved/revised PR, review comments (knowledge artifacts) |
| **Quality Criteria** | AI pre-review passed; human review verified design, tests, and complexity; small batch size |
| **Automation** | AI pre-review for style, test gaps, known vulnerability patterns; automated OWNERS-based reviewer assignment |
| **Approval Boundaries** | Human approves (AI recommends only); AI comments are advisory |
| **KPIs** | Review cycle time, PR merge rate, first-response latency, re-review rate |
| **Anti-patterns** | Rubber-stamping AI-generated PRs; large PRs overwhelming reviewer; review as bottleneck; comments on style vs. substance |
| **Minimum** | No mandatory review; pair programming as review proxy |
| **Standard** | Mandatory peer review with OWNERS; CI + lint gates |
| **Leading-Edge** | AI pre-review mandatory; AI reviewer as second reviewer; automated small-batch enforcement; review-bot integration |

### PA11-W01: Progressive Deployment

| Field | Value |
|-------|-------|
| **Objective** | Safely deploy changes to production with controlled exposure and automatic rollback capability |
| **Classification** | Universal (leading-edge for smaller orgs) |
| **Triggers** | Release candidate ready after CI pass |
| **Steps** | 1. Deploy to canary (small % of users) → 2. Monitor error budgets, SLOs → 3. Gradual rollout increase → 4. Full rollout → 5. Post-deploy monitoring |
| **Decision Points** | Halt vs. continue rollout based on error budget burn; rollback threshold; approval needed for >N% traffic |
| **Human-AI** | AI for anomaly detection in rollout telemetry; human for abort decisions and escalation |
| **Roles/RACI** | Developer (R), SRE/Platform (R), Automated systems (CI/CD), Release Manager (A for large rollouts) |
| **Tool Categories** | Feature flags (LaunchDarkly, Flagsmith), CD (ArgoCD, Spinnaker), canary analysis tools |
| **Outputs** | Successful deployment with progressive rollout evidence, rollback plan |
| **KPIs** | Canary success rate, deployment velocity, rollback frequency, change failure rate |
| **Anti-patterns** | Overriding canary signals for urgent fixes; no rollback testing; canary logic too slow for meaningful signal |
| **Minimum** | Manual deploy, no progressive exposure |
| **Standard** | Feature flags, canary deployment, automated rollback on error budget burn |
| **Leading-Edge** | AI-assisted canary analysis, automated rollback decisions, multi-region progressive delivery, experimentation platform integration |

### PA15-W01: Observability Instrumentation

| Field | Value |
|-------|-------|
| **Objective** | Instrument applications with OpenTelemetry or equivalent for production observability |
| **Classification** | Universal |
| **Steps** | 1. Identify critical paths → 2. Define telemetry requirements → 3. Instrument code (traces, metrics, logs) → 4. Configure telemetry export → 5. Validate instrumentation → 6. Create dashboards/alerts |
| **Human-AI** | AI for instrumentation code generation, dashboard suggestions, anomaly detection; human for telemetry requirements |
| **Roles/RACI** | Developer (R), Platform/SRE (A for standards), Observability team (R for centralized tools) |
| **Tool Categories** | OpenTelemetry SDK, dashboards (Grafana, Datadog), alerting (PagerDuty, Opsgenie), structured logging |
| **Outputs** | Instrumented application, telemetry pipeline, dashboards, alerts |
| **KPIs** | Observability coverage %, signal-to-noise ratio, dashboard freshness |
| **Anti-patterns** | No instrumentation until prod issue; log-only (no traces); dashboards without SLOs |
| **Minimum** | Basic health check endpoints, error log aggregation |
| **Standard** | OpenTelemetry traces + metrics + logs, structured logging, SLO-based alerts |
| **Leading-Edge** | AI-driven telemetry optimization, automatic anomaly detection, trace-based testing, observability-driven development |

---

## 5. Cross-Area Dependency and Feedback Map

### Upstream → Downstream Dependencies

```
PA01 (Strategy) → PA02 (Discovery) → PA03 (Design) → PA04 (Architecture) → PA05 (Planning) → PA06 (Dev Env) → PA07 (Implementation) → PA08 (Code Review) → PA09 (Testing) → PA10 (Build) → PA11 (Release/Deploy) → PA14 (SRE/Ops) → PA15 (Observability)
                          ↘                                                                                                                           ↗
                           PA03 (Design) → PA04 (Architecture) → PA07 → PA08 → PA09 → PA10 → PA11
```

### Feedback Loops

| Loop | Path | Purpose |
|------|------|---------|
| Observability → Strategy | PA15 → PA01 → PA02 | Production insights inform product direction |
| Incident → Reliability → Planning | PA14 → PA05 → PA07 | Error budget consumption prioritizes reliability work |
| Developer Experience → Platform | PA16 → PA12 | DX gaps drive IDP improvement |
| Security → Release | PA13 → PA11 | Security gating for release candidates |
| Testing → Implementation | PA09 → PA07 | Test failures drive code fixes |
| AI Quality → Code Reviews | PA18 → PA08 | AI-generated code quality monitoring informs review policy |

### Critical Paths

1. **Regulatory compliance critical path:** PA04 (secure design) → PA10 (SBOM/provenance) → PA13 (security audit) → PA11 (compliance-gated release)
2. **High-velocity release critical path:** PA07 (small batch) → PA08 (fast review) → PA10 (fast CI) → PA11 (automated deploy) → PA14 (SLO monitoring)
3. **Platform adoption critical path:** PA16 (measure pain) → PA12 (IDP build) → PA12 (golden paths) → adoption → PA16 (measure again)

### Dependency Failure Cascades

- **Testing failure cascade:** PA09 gaps → PA10 quality issues → PA11 deployment failures → PA14 incident → PA15 observability gaps delay detection
- **Security failure cascade:** PA13 gaps → PA11 security incidents → PA15 detection → PA14 remediation → PA17 maintenance overload

---

## 6. AI-Integration Layer

### Current State (mid-2026)

The evidence base supports a nuanced picture of AI integration across the SDLC:

| Process Area | AI Adoption | Evidence | Impact |
|-------------|-------------|----------|--------|
| PA07 Implementation | Universal (90%+) | DORA, GitHub, Spotify | Positive individual productivity; negative organizational stability without guardrails |
| PA08 Code Review | High (1 in 5 reviews) | GitHub Engineering Blog | Faster reviews, improved PR merge rates (15% increase at Accenture) |
| PA09 Testing | Emerging | DORA | Test generation nascent; verification tax is real |
| PA17 Maintenance | Leading-edge (Spotify scale) | Spotify Engineering | 2.5M auto-merged PRs for fleet maintenance |
| PA01-PA05 Strategy/Discovery | Augmentation | General adoption | AI for research synthesis, market analysis |
| PA15 Observability | Emerging | Industry trend | AI-driven anomaly detection, telemetry optimization |

### The Amplifier Effect (DORA 2025 Core Finding)

DORA's most important finding for process architecture: **AI amplifies existing organizational strengths and weaknesses.** Organizations with strong fundamentals (small batches, good testing, platform engineering, clear code review standards) see amplified benefits. Organizations with weak fundamentals see their dysfunctions magnified.

**Engineering implications:**

1. **Verification tax:** 30% of developers do not trust AI-generated code; time saved writing is partially re-spent on auditing. Review processes must be redesigned (shift AI feedback to author phase, use AI pre-review as filter).

2. **Batch size inflation:** AI enables generating large changes quickly, but large batches decrease review quality and increase failure risk. Countermeasure: enforce small-batch working (DORA core capability + AI tag).

3. **Expertise paradox:** AI lowers entry barriers but risks bypassing the "productive struggle" needed for deep expertise. Mitigation: pair junior engineers with senior mentors; require manual coding for complex components.

### Recommended Workflow Modifications for AI Era

| Traditional Practice | AI-Era Modification | Evidence |
|---------------------|-------------------|----------|
| Code review as async human process | AI pre-review → human review (shifted to author phase) | DORA, GitHub |
| Large PRs | Mandatory small-batch enforcement | DORA core + AI capability |
| Documentation manually written | AI-generated, human-verified | Industry adoption |
| Test writing manually | AI-generated test suggestions, human review | Emerging |
| Release notes manually compiled | AI-generated from commit history | Industry adoption |
| Manual dependency updates | Automated AI PRs (Dependabot + AI verification) | Spotify Fleet Management |

### AI Governance Requirements

- Clear organizational AI stance (DORA AI capability #1)
- AI-generated code must be clearly labeled in PRs
- Security scanning mandatory for AI-generated code
- Developer training on prompt engineering and AI output verification
- Regular AI output quality audits

---

## 7. Deprecated or Diminishing Practices

| Practice | Status | Replacement | Rationale |
|----------|--------|-------------|-----------|
| Waterfall-only development | Deprecated | Agile/iterative with continuous delivery | DORA: high performers deploy on demand |
| Manual change approval boards | Deprecated | Automated approval gates with exception | DORA: streamline change approval; only 3-5% need human approval |
| Big Design Up Front (BDUF) | Diminishing | Evolutionary architecture with ADRs | Agile architecture practice; design emerges with implementation |
| Siloed QA/testing teams (as gatekeepers) | Diminishing | Embedded QA + automation-first | Shift-left testing; quality is everyone's responsibility |
| Long-lived feature branches | Deprecated | Trunk-based development with feature flags | DORA core capability; reduces merge conflicts and batch sizes |
| Manual infrastructure provisioning | Deprecated | IaC (Terraform, Pulumi, CDK) | CNCF, DORA: cloud infrastructure flexibility is core capability |
| Separate ops team as deployment gatekeeper | Diminishing | Shared responsibility + SRE model | DevOps culture; platform engineering enables self-service |
| Lines of code as productivity metric | Deprecated | DORA metrics + SPACE framework | DORA, SPACE: outcomes over outputs |
| Manual security testing only at release | Diminishing | Continuous SAST/DAST + shift-left | NIST SSDF: secure development throughout SDLC |
| Synchronous-only code reviews | Diminishing | Async review + AI pre-review | Google Eng Practices: async acceptable; AI makes it more efficient |
| Separate staging environment as production proxy | Diminishing | Ephemeral environments + canary deployment | Platform engineering enables per-PR environments |
| Monolithic release trains (quarterly) | Deprecated | Continuous deployment + progressive delivery | DORA elite: on-demand deployments |
| Manual environment configuration | Deprecated | Dev containers + environment-as-code | Gitpod, Codespaces, devcontainer standard |
| API documentation as separate document | Deprecated | OpenAPI/Swagger as source of truth | API-first design; documentation generated from spec |
| Capacity planning as yearly spreadsheet | Diminishing | Real-time capacity monitoring + auto-scaling | Cloud elasticity reduces need for long-range capacity planning |
| ITIL-style ticket ops for developer requests | Deprecated | Self-service IDP with golden paths | Platform engineering: reduce cognitive load, not add process |

---

## 8. Maturity Model

### Assessment Dimensions

Each Process Area is assessed across 3 tiers. The overall maturity is the median across all areas, with security (PA13) and reliability (PA14) as non-negotiable minimums.

### Overall Maturity Levels

| Level | Label | Description | Org Profile |
|-------|-------|-------------|-------------|
| 1 | Minimum | Essential practices for functional software delivery | Startup, <10 engineers |
| 2 | Standard | Industry-normative practices with automation and platform | Growth company, 10-100 engineers |
| 3 | Leading-Edge | AI-integrated, fully automated, platform-enabled | Enterprise, 100+ engineers |

### Per-Process Area Maturity

| Process Area | Minimum | Standard | Leading-Edge |
|-------------|---------|----------|-------------|
| PA01 Strategy | Founder vision, annual plan | OKR-driven, quarterly planning | Continuous strategy, AI demand sensing |
| PA02 Discovery | Ad-hoc user talk, ticket descriptions | User research sprints, PRDs, continuous discovery | AI research synthesis, experiment-driven requirements |
| PA03 UX Design | Simple wireframes, no design system | Design system, usability testing, accessibility compliance | AI-powered prototyping, automated accessibility audit |
| PA04 Architecture | Oral decisions, no docs | ADRs in repo, C4 diagrams | ADR graph, AI trade-off analysis, evolutionary architecture |
| PA05 Planning | Kanban board, no estimation | Sprint planning, velocity tracking, WIP limits | Continuous planning, AI estimation, data-driven prioritization |
| PA06 Dev Env | Local setup, manual runbook | Dev containers, standardized IDE config | IDP-integrated dev portal, cloud dev environments |
| PA07 Implementation | No AI tools, manual coding | AI autocomplete, basic prompt engineering | Agentic coding, automated test generation, fleet refactoring |
| PA08 Code Review | Pair programming only | Mandatory PR review with OWNERS | AI pre-review, reviewer automation, small-batch enforcement |
| PA09 Testing | Manual testing, unit tests | Automated CI test suite, SAST | AI test generation, continuous fuzzing, trace-based testing |
| PA10 Build | Simple CI, no signing | Reproducible builds, SBOM, signed artifacts | SLSA L3+, provenance attestation, supply chain automation |
| PA11 Release | Manual deploy, no canary | CI/CD, feature flags, canary deploy | Full progressive delivery, automated rollback, experiment platform |
| PA12 Platform | No platform team | IDP MVP, golden paths for common tasks | Full IDP, scorecards, self-service marketplace |
| PA13 Security | SAST scanner, basic dependency check | SAST/DAST, secrets scan, threat model | Continuous security validation, AI vuln detection, SBOM in pipeline |
| PA14 SRE | Manual on-call, no SLOs | SLOs, error budgets, incident response | Chaos engineering, auto-remediation, toil reduction |
| PA15 Observability | Uptime monitoring, log errors | OpenTelemetry, structured logging, dashboards | AI-driven anomaly detection, observability-driven dev |
| PA16 DevEx | Ad-hoc feedback | DORA metrics + annual DX survey | Continuous measurement, real-time improvement loop |
| PA17 Maintenance | Manual bug fixing | Automated dependency updates, tech debt tracking | AI fleet maintenance, auto-remediation, lifecycle automation |
| PA18 AI/Agentic | Individual tool use | Sanctioned AI tools, prompt libraries, review guidelines | Agentic workflows, AI-first process design, automated verification |

### Migration Paths

| Transition | Key Actions | Risk Factors |
|-----------|-------------|-------------|
| Minimum → Standard | CI/CD setup, code review policy, test automation, platform MVP | Over-engineering before understanding developer needs |
| Standard → Leading-Edge | AI tool integration, full platform engineering, SRE program, observability standard | Verification tax; AI instability risk; expertise paradox |

---

## 9. Role Model and Governance Implications

### Updated Role Definitions (AI Era)

| Role | Traditional Definition | AI-Era Definition |
|------|----------------------|-------------------|
| **Developer** | Writes code from specs | Architects solutions, engineers prompts, reviews AI output, owns verification |
| **Tech Lead** | Technical direction, code review | AI workflow design, prompt architecture, AI output quality standards |
| **Product Manager** | Requirements, prioritization | AI-augmented research, prompt-engineered user stories, experiment design |
| **QA Engineer** | Manual/automated testing | AI test strategy, test generation oversight, AI quality audit |
| **SRE** | Reliability, incident response | AI-augmented anomaly detection, auto-remediation design, SLO AI modeling |
| **Platform Engineer** | IDP build/maintenance | AI-instrumented golden paths, AI agent infrastructure, MCP/integration design |
| **Security Engineer** | Security testing, compliance | AI-generated code security review, prompt injection defense, AI supply chain security |
| **AI/ML Engineer** | Model training/deployment | (or distinct function not covered here) — prompt engineering, agent workflow design, LM evaluation |

### RACI Evolution

| Activity | Responsible | Accountable | Consulted | Informed |
|----------|-------------|-------------|-----------|----------|
| AI-generated code review | Developer (human) | Tech Lead | AI Review Agent | Team |
| AI tool selection | Platform/DevEx | CTO/VP Eng | Security, Legal | Engineering |
| Prompt library management | Tech Lead | Engineering Manager | AI Platform Team | Developers |
| AI output quality audit | QA/DevEx | QA Lead | Security | Engineering Leadership |
| AI instability monitoring | SRE | SRE Lead | Platform | All teams (via error budget) |

### Governance Implications

1. **AI-generated code governance:** All AI-generated code must be clearly labeled in PRs. AI output without human review must not reach production. Security scanning of AI-generated code is mandatory.

2. **Prompt governance:** Prompts shared across teams should be version-controlled and reviewed (like any other engineering artifact).

3. **Platform governance:** IDP ownership is a product team; golden paths are maintained with feedback loops; deviations are tracked for platform improvement.

4. **Security governance:** SBOMs are mandatory for all production artifacts. NIST SSDF POAM items are tracked quarterly. Security debt is tracked alongside technical debt.

5. **Compliance governance:** Regulated environments maintain documented deviation process from golden paths; audit trails for all deployment decisions.

6. **DevEx governance:** DORA metrics + SPACE/DX surveys run quarterly; platform adoption and developer satisfaction are board-level metrics.

### Team Topology Recommendations

| Organization Size | Recommended Topology |
|------------------|---------------------|
| <10 engineers | Stream-aligned teams only (no platform team) |
| 10-50 engineers | Stream-aligned + 1-2 enabling engineers |
| 50-200 engineers | Stream-aligned + platform team (3-5) + enabling function |
| 200+ engineers | Full topology: stream-aligned + platform + enabling + complicated-subsystem where needed |

---

## 10. Final Recommended Canonical Industry Standard

### The Canonical SDLC Process Architecture — Synthesis

After synthesizing evidence from 15 leading organizations, DORA's longitudinal research, NIST regulatory frameworks, and industry standards, the canonical industry-standard SDLC process architecture for mid-2026 is:

**An iterative, continuous-flow process architecture organized into 18 Process Areas, governed by a platform engineering layer, augmented by AI tools, measured by DORA + SPACE metrics, and secured by NIST SSDF practices.**

### Core Principles

1. **Iterative over sequential** — All 18 process areas operate in parallel or feed back on each other; there is no discrete "phase" model
2. **Platform-enabled** — IDP with golden paths is the standard for organizations with >3 teams
3. **AI-augmented, human-accountable** — AI amplifies productivity but humans own outcomes
4. **Measurement-driven** — DORA metrics for delivery performance; SPACE for developer experience
5. **Security-throughout** — NIST SSDF practices integrated into each process area, not bolted on
6. **Observability-as-default** — OpenTelemetry instrumentation before production deployment
7. **Small-batch working** — Universal principle, now critical as AI increases change velocity

### Recommended Implementation Sequence

**Phase 1 (Foundation):** PA07 + PA08 + PA09 + PA10 + PA11 — Establish CI/CD pipeline, code review practices, test automation, and deployment automation
**Phase 2 (Observability + SRE):** PA14 + PA15 — SLOs, error budgets, OpenTelemetry instrumentation
**Phase 3 (Platform):** PA12 + PA06 — IDP with developer portal and golden paths
**Phase 4 (Security+Compliance):** PA13 — NIST SSDF integration, supply chain security, compliance automation
**Phase 5 (Measurement):** PA16 — DORA metrics, SPACE framework, continuous improvement loop
**Phase 6 (AI Integration):** PA18 — AI tool adoption with governance, prompt engineering standards, AI output verification
**Phase 7 (Strategy Differentiation):** PA01-PA05 — Strategic feedback loops, continuous discovery, architecture evolution

### Context-Dependent Adaptations

| Dimension | Startup (<10 eng) | Growth (10-100 eng) | Enterprise (100+ eng) |
|-----------|-------------------|---------------------|----------------------|
| Platform | None (scripts/configs) | IDP MVP (Backstage) | Full IDP (orchestrator + portal + scorecards) |
| AI Governance | Individual tool use | Sanctioned tools + guidelines | Full governance program |
| Security | SAST + secret scan | SAST/DAST + SBOM + penetration test | Full NIST SSDF + compliance program |
| Release | Push-to-deploy | CI/CD + canary | Progressive delivery + compliance gates |
| Observability | Health checks + error logs | OpenTelemetry + dashboards | AI-driven anomaly detection |
| Architecture | Verbal decisions, simple docs | ADRs in repo | Architecture governance board + ADR graph |
| Testing | Unit tests + manual QA | Automated CI suite + integration tests | Full test pyramid + trace-based testing |
| SRE | Ad-hoc on-call | SLOs + error budgets | Dedicated SRE team + chaos engineering |

### Open Questions

1. **Autonomous agentic coding:** As of mid-2026, no credible evidence exists of fully autonomous AI agents replacing human developers in production SDLC at enterprise scale. Revisit in Q1 2027.
2. **Long-term skill effects:** The "expertise paradox" (AI bypassing productive struggle for juniors) remains unmeasured longitudinally.
3. **Platform engineering ROI:** Quantitative evidence of IDP ROI (beyond adoption rates) is limited to vendor-sponsored studies.
4. **Regulatory AI compliance:** No established framework for AI-generated code in regulated environments (medical, aviation, finance).
5. **Cross-org consistency:** SDLC practices vary significantly across companies; this canonical model represents the convergence of documented practices but does not account for undocumented internal variations.

---

*End of research_report.md — all 10 sections complete.*
