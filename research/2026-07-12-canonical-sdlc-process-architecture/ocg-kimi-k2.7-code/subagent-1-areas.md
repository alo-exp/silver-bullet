# SDLC Process Architecture: 6 Process Areas

**Subagent 1 Deliverable** | Generated 2026-07-12
**Areas covered:** Strategy Portfolio & Product Direction, Architecture & Technical Design, Testing QE & Verification, Build Integration & Artifact Management, CI Release & Deployment, Security Privacy Risk & Compliance

---

## Process Area 1: Strategy, Portfolio & Product Direction

### Definition & Purpose

Strategy, Portfolio & Product Direction encompasses the activities that align software investment with business objectives. It covers product vision definition, portfolio prioritization, roadmap planning, stakeholder alignment, and value-stream management. This area answers: *what should we build, why, and in what order?*

**Mid-2026 relevance:** AI-assisted product discovery, data-driven prioritization frameworks, and outcome-based roadmapping have become mainstream. Organizations increasingly use AI to analyze user feedback at scale, predict market trends, and optimize portfolio allocation. The shift from output-based (features shipped) to outcome-based (value delivered) planning is now dominant in mature organizations.

### Inputs, Workflows, Outputs, Dependencies

**Inputs:**
- Business strategy and corporate objectives
- Market research and competitive analysis
- Customer feedback, user research, usage analytics
- Technical debt assessments and architecture constraints
- Regulatory and compliance requirements
- Financial constraints and resource availability

**Core workflows:**
1. Product Vision & Strategy Definition
2. Portfolio Prioritization & Investment Allocation
3. Roadmap Planning & Stakeholder Alignment
4. Discovery & Validation Cycles
5. Value Stream Measurement & Feedback

**Outputs:**
- Product vision statement and strategic themes
- Prioritized portfolio backlog with investment allocation
- Product roadmaps (outcome-based, time-horizon layered)
- Validated user stories and acceptance criteria
- OKRs / KPIs linked to business outcomes

**Dependencies:**
- Architecture & Technical Design (feasibility constraints)
- Security & Compliance (regulatory boundaries)
- Finance (budget allocation)
- Engineering capacity planning

### Metrics, Gates, Exit Criteria

| Metric | Target | Gate |
|--------|--------|------|
| Strategic alignment score | ≥90% of roadmap items trace to OKRs | Quarterly review |
| Discovery validation rate | ≥70% of hypotheses validated before build | Pre-commit gate |
| Time-to-decision | ≤2 weeks for prioritization decisions | Escalation trigger |
| Stakeholder satisfaction | ≥4/5 in quarterly surveys | Annual review |
| Portfolio value realization | ≥80% of planned outcomes achieved | Post-release review |

### Pitfalls & Mitigations

| Pitfall | Mitigation |
|---------|------------|
| HiPPO-driven prioritization | Use evidence-based frameworks (RICE, WSJF) with transparent scoring |
| Roadmap-as-commitment anti-pattern | Communicate roadmaps as directional, not contractual; use confidence bands |
| Disconnect between strategy and execution | Implement quarterly strategy-to-backlog alignment ceremonies |
| Over-indexing on short-term metrics | Balance leading indicators (engagement) with lagging (revenue, retention) |
| AI hallucination in discovery | Human-in-the-loop validation for all AI-generated insights |

### Context Variations

| Context | Variation |
|---------|-----------|
| Startup | Lean Canvas + rapid hypothesis testing; minimal formal portfolio; founder-driven vision |
| Enterprise | Formal portfolio governance; multi-year strategic themes; stage-gate investment |
| Regulated | Compliance-driven prioritization; audit trail for decisions; risk-adjusted roadmaps |
| Consumer | Data-driven experimentation; A/B testing at scale; rapid iteration cycles |
| B2B/Platform | Customer advisory boards; API-first roadmaps; ecosystem strategy |

---

## Process Area 4: Architecture & Technical Design

### Definition & Purpose

Architecture & Technical Design covers the structural decisions, design principles, and technical governance that shape how systems are built, evolve, and interoperate. It encompasses system decomposition, technology selection, interface contracts, non-functional requirements (NFRs), and architectural fitness functions.

**Mid-2026 relevance:** Evolutionary architecture, AI-assisted design review, platform engineering maturity, and cloud-native patterns dominate. Organizations balance microservice granularity with operational complexity. Architecture Decision Records (ADRs) and fitness functions have become standard practice. AI tools assist in design pattern recognition, dependency analysis, and technical debt quantification.

### Inputs, Workflows, Outputs, Dependencies

**Inputs:**
- Product requirements and NFRs (scalability, reliability, security, performance)
- Business constraints (budget, timeline, compliance)
- Existing system landscape and integration points
- Technology radar and organizational capabilities
- Threat models and security requirements

**Core workflows:**
1. Architectural Vision & Principles Definition
2. System Decomposition & Service Boundary Design
3. Technology Selection & Fitness Function Definition
4. Design Review & ADR Governance
5. Technical Debt Management & Evolution

**Outputs:**
- Architecture Decision Records (ADRs)
- System context diagrams, container diagrams, component diagrams
- API contracts and interface specifications
- Non-functional requirement specifications and SLAs
- Fitness functions and architectural governance rules
- Technical debt register with remediation roadmap

**Dependencies:**
- Strategy & Product Direction (requirements, constraints)
- Security & Compliance (threat models, compliance requirements)
- Build & CI/CD (deployment topology, infrastructure-as-code)
- Testing & QE (testability requirements)

### Metrics, Gates, Exit Criteria

| Metric | Target | Gate |
|--------|--------|------|
| ADR coverage | ≥90% of significant decisions documented | Design review gate |
| Fitness function pass rate | 100% on critical NFRs | Pre-deployment gate |
| Technical debt ratio | ≤15% of sprint capacity allocated to debt | Quarterly review |
| Architecture review cycle time | ≤5 business days for standard reviews | Escalation trigger |
| Dependency freshness | ≤30 days for critical dependency updates | Automated alert |

### Pitfalls & Mitigations

| Pitfall | Mitigation |
|---------|------------|
| Ivory tower architecture | Embed architects in delivery teams; use collaborative design sessions |
| Premature optimization | Apply YAGNI; defer decisions to last responsible moment |
| Over-engineering for scale | Use fitness functions to right-size; start simple, evolve |
| Technology hype adoption | Technology radar with trial/assess/adopt/hold lifecycle |
| Documentation rot | Living documentation; ADRs in version control; automated compliance checks |

### Context Variations

| Context | Variation |
|---------|-----------|
| Startup | Minimal upfront design; evolve-as-you-go; pragmatic tech choices |
| Enterprise | Formal architecture review boards; enterprise architecture frameworks; multi-year roadmaps |
| Regulated | Compliance-driven design; audit trail for all decisions; formal threat modeling |
| Cloud-native | Serverless-first; event-driven; immutable infrastructure; GitOps |
| Legacy modernization | Strangler fig pattern; incremental migration; parallel run strategies |

---

## Process Area 9: Testing, QE & Verification

### Definition & Purpose

Testing, Quality Engineering & Verification encompasses all activities that provide confidence that software meets its requirements, behaves correctly, and satisfies quality attributes. This includes test strategy, test automation, exploratory testing, performance testing, security testing, and verification of non-functional requirements.

**Mid-2026 relevance:** AI-assisted test generation, intelligent test selection, and shift-left testing are mainstream. The test pyramid remains foundational but has evolved with AI-generated unit tests, contract testing for microservices, and observability-driven testing. Quality engineering has shifted from a phase to a continuous capability embedded throughout the SDLC.

### Inputs, Workflows, Outputs, Dependencies

**Inputs:**
- Requirements (functional and non-functional)
- Architecture and design specifications
- Code changes and pull requests
- Production telemetry and incident data
- Risk assessments and compliance requirements

**Core workflows:**
1. Test Strategy & Planning
2. Test Design & Automation Development
3. Test Execution & Analysis
4. Quality Metrics & Reporting
5. Continuous Quality Improvement

**Outputs:**
- Test strategy documents and test plans
- Automated test suites (unit, integration, e2e, performance, security)
- Test execution reports and quality dashboards
- Defect reports and root cause analysis
- Quality metrics (coverage, defect density, escape rate)

**Dependencies:**
- Architecture & Design (testability, test environments)
- Build & CI/CD (test execution infrastructure)
- Security & Compliance (security testing requirements)
- Product Direction (acceptance criteria)

### Metrics, Gates, Exit Criteria

| Metric | Target | Gate |
|--------|--------|------|
| Automated test coverage | ≥80% for critical paths | Pre-merge gate |
| Test execution time | ≤10 minutes for CI suite | Pipeline gate |
| Defect escape rate | ≤5% to production | Release gate |
| Flaky test rate | ≤2% of automated tests | Weekly review |
| Mean time to detect (MTTD) | ≤15 minutes for critical defects | Monitoring alert |

### Pitfalls & Mitigations

| Pitfall | Mitigation |
|---------|------------|
| Ice cream cone anti-pattern (too many e2e tests) | Enforce test pyramid; invest in unit and integration tests |
| Flaky tests eroding trust | Quarantine flaky tests; fix or delete within 48 hours |
| Testing as a phase | Shift-left; embed QE in delivery teams; continuous testing |
| Over-reliance on coverage metrics | Focus on risk-based testing; measure defect detection effectiveness |
| AI-generated tests without review | Human review of AI-generated test logic; validate test intent |

### Context Variations

| Context | Variation |
|---------|-----------|
| Startup | Minimal test automation; focus on critical paths; manual exploratory testing |
| Enterprise | Comprehensive test automation; dedicated QE teams; formal quality gates |
| Regulated | Validation protocols; audit trail for all tests; independent verification |
| High-velocity | AI-assisted test generation; intelligent test selection; canary releases |
| Safety-critical | Formal verification; model-based testing; independent safety assessment |

---

## Process Area 10: Build, Integration & Artifact Management

### Definition & Purpose

Build, Integration & Artifact Management covers the processes that transform source code into deployable artifacts, manage dependencies, ensure build reproducibility, and maintain artifact integrity throughout the software supply chain. This includes compilation, packaging, dependency management, artifact storage, and supply chain security.

**Mid-2026 relevance:** Software supply chain security (SLSA, SBOMs), reproducible builds, and hermetic build environments are now baseline expectations. AI-assisted dependency analysis, automated vulnerability scanning, and provenance tracking have become standard. The shift from "build once, deploy many" to "build securely, verify continuously" reflects heightened supply chain threat awareness.

### Inputs, Workflows, Outputs, Dependencies

**Inputs:**
- Source code and configuration
- Dependency manifests (package.json, requirements.txt, etc.)
- Build configuration (Dockerfiles, build scripts)
- Security policies and compliance requirements
- Infrastructure specifications

**Core workflows:**
1. Build Environment Setup & Maintenance
2. Compilation, Packaging & Artifact Creation
3. Dependency Management & Vulnerability Scanning
4. Artifact Storage, Versioning & Distribution
5. Supply Chain Security & Provenance Tracking

**Outputs:**
- Deployable artifacts (containers, packages, binaries)
- Software Bill of Materials (SBOMs)
- Build provenance and attestation
- Dependency vulnerability reports
- Artifact metadata and version information

**Dependencies:**
- Source control (code and configuration)
- CI/CD (build execution and orchestration)
- Security & Compliance (vulnerability scanning, signing)
- Architecture (build tooling, containerization strategy)

### Metrics, Gates, Exit Criteria

| Metric | Target | Gate |
|--------|--------|------|
| Build success rate | ≥95% on mainline | Pipeline gate |
| Build reproducibility | 100% deterministic builds | Audit requirement |
| Dependency freshness | ≤7 days for critical vulnerabilities | Automated alert |
| SBOM generation | 100% of production artifacts | Release gate |
| SLSA level | ≥Level 2 for production artifacts | Compliance gate |

### Pitfalls & Mitigations

| Pitfall | Mitigation |
|---------|------------|
| Non-reproducible builds | Hermetic build environments; pinned dependencies; build caching |
| Dependency sprawl | Automated dependency updates; regular audits; minimal dependency policy |
| Artifact bloat | Multi-stage builds; layer caching; artifact size monitoring |
| Supply chain attacks | SBOMs; signature verification; SLSA compliance; provenance tracking |
| Build environment drift | Infrastructure-as-code for build environments; immutable build agents |

### Context Variations

| Context | Variation |
|---------|-----------|
| Startup | Simple CI/CD; container-based builds; minimal formal artifact management |
| Enterprise | Formal artifact repositories; multi-environment promotion; compliance scanning |
| Regulated | Signed artifacts; full provenance chain; independent verification |
| Open source | Public SBOMs; community vulnerability disclosure; reproducible builds |
| Embedded/IoT | Cross-compilation; hardware-in-the-loop testing; firmware signing |

---

## Process Area 11: CI, Release & Deployment

### Definition & Purpose

CI, Release & Deployment encompasses the practices and infrastructure that enable frequent, reliable, and safe delivery of software changes from development to production. This includes continuous integration, continuous delivery, deployment strategies, release management, and rollback capabilities.

**Mid-2026 relevance:** Trunk-based development, continuous deployment, and GitOps are mainstream for high-performing teams. AI-assisted code review, automated canary analysis, and progressive delivery strategies (feature flags, canary releases, blue-green deployments) have become standard. The distinction between continuous delivery (releasable) and continuous deployment (released) remains critical for business-controlled release decisions.

### Inputs, Workflows, Outputs, Dependencies

**Inputs:**
- Code changes and pull requests
- Automated test results
- Build artifacts
- Deployment configuration and infrastructure definitions
- Release approval workflows (when applicable)

**Core workflows:**
1. Continuous Integration (merge, build, test)
2. Continuous Delivery (package, stage, verify)
3. Release Planning & Approval
4. Deployment Execution & Progressive Rollout
5. Post-Deployment Verification & Rollback

**Outputs:**
- Integrated, tested code on mainline
- Deployment-ready artifacts in target environments
- Deployment logs and audit trail
- Release notes and changelog
- Post-deployment verification reports

**Dependencies:**
- Build & Artifact Management (deployable artifacts)
- Testing & QE (test execution and quality gates)
- Architecture (deployment topology, infrastructure)
- Security & Compliance (security gates, approval workflows)
- Operations (monitoring, incident response)

### Metrics, Gates, Exit Criteria

| Metric | Target | Gate |
|--------|--------|------|
| Deployment frequency | ≥Daily for high performers | Capability metric |
| Lead time for changes | ≤1 day (commit to production) | DORA metric |
| Change failure rate | ≤5% | DORA metric |
| Mean time to recover (MTTR) | ≤1 hour | Incident response SLA |
| Pipeline success rate | ≥90% end-to-end | Pipeline health metric |

### Pitfalls & Mitigations

| Pitfall | Mitigation |
|---------|------------|
| Long-lived feature branches | Trunk-based development; feature flags; short-lived branches (<1 day) |
| Manual deployment steps | Full automation; infrastructure-as-code; GitOps |
| Big bang releases | Progressive delivery; canary releases; feature flags |
| Insufficient rollback capability | Automated rollback triggers; blue-green deployments; database migrations |
| Environment drift | Infrastructure-as-code; ephemeral environments; environment parity |

### Context Variations

| Context | Variation |
|---------|-----------|
| Startup | Simple CI/CD; manual production deployments; feature flags for rollout |
| Enterprise | Formal release management; approval workflows; multi-environment promotion |
| Regulated | Change advisory boards; audit trail; segregated duties; rollback verification |
| High-velocity | Continuous deployment; automated canary analysis; self-service deployments |
| Mobile | App store release cycles; staged rollouts; A/B testing integration |

---

## Process Area 13: Security, Privacy, Risk & Compliance

### Definition & Purpose

Security, Privacy, Risk & Compliance encompasses all activities that ensure software is developed, deployed, and operated in a manner that protects against threats, respects user privacy, manages organizational risk, and meets regulatory requirements. This includes threat modeling, secure coding practices, security testing, privacy impact assessments, compliance verification, and incident response.

**Mid-2026 relevance:** DevSecOps, shift-left security, and AI-assisted threat detection are now baseline expectations. Zero-trust architecture, supply chain security (SLSA, SBOMs), and privacy-by-design have moved from leading-edge to standard practice. Regulatory pressure (AI Act, GDPR enforcement, sector-specific regulations) has elevated compliance from an afterthought to a first-class concern.

### Inputs, Workflows, Outputs, Dependencies

**Inputs:**
- Threat intelligence and vulnerability disclosures
- Regulatory requirements and compliance frameworks
- Architecture and design specifications
- Code changes and dependency updates
- Incident reports and security telemetry

**Core workflows:**
1. Threat Modeling & Risk Assessment
2. Secure Development Practices & Training
3. Security Testing & Verification
4. Compliance Verification & Audit
5. Incident Response & Continuous Improvement

**Outputs:**
- Threat models and risk registers
- Security requirements and secure coding guidelines
- Security test results and vulnerability reports
- Compliance attestations and audit reports
- Incident response plans and post-incident reviews

**Dependencies:**
- Architecture & Design (security architecture, threat models)
- Build & CI/CD (security gates, automated scanning)
- Testing & QE (security testing integration)
- Product Direction (privacy requirements, risk appetite)
- Operations (security monitoring, incident response)

### Metrics, Gates, Exit Criteria

| Metric | Target | Gate |
|--------|--------|------|
| Critical vulnerability remediation | ≤7 days | Security gate |
| Security test coverage | ≥90% of OWASP Top 10 | Release gate |
| Compliance audit findings | 0 critical findings | Audit gate |
| Security training completion | 100% of developers | Annual requirement |
| Mean time to remediate (MTTR) | ≤30 days for high-severity | SLA metric |

### Pitfalls & Mitigations

| Pitfall | Mitigation |
|---------|------------|
| Security as a gate | Shift-left; embed security in delivery teams; continuous security |
| Checkbox compliance | Risk-based approach; focus on outcomes, not artifacts |
| Alert fatigue | Prioritize vulnerabilities by exploitability and impact; automate triage |
| Security debt | Track security debt explicitly; allocate remediation capacity |
| AI-generated code vulnerabilities | Mandatory security review for AI-generated code; automated scanning |

### Context Variations

| Context | Variation |
|---------|-----------|
| Startup | Minimal formal security; focus on critical vulnerabilities; cloud provider security |
| Enterprise | Dedicated security teams; formal SDL; compliance programs; security champions |
| Regulated | Independent security assessment; audit trail; regulatory reporting; data protection officer |
| High-velocity | Automated security gates; security-as-code; continuous compliance |
| Open source | Community security review; coordinated vulnerability disclosure; security advisories |

---

# Workflow Specifications

## Workflow 1.1: Product Vision & Strategy Definition

**Objective:** Establish a clear, outcome-oriented product vision and strategic direction that aligns software investment with business objectives.

**Classification:** Universal

**Triggers:**
- New product or major initiative kickoff
- Annual/quarterly strategic planning cycle
- Significant market shift or competitive threat

**Preconditions:**
- Business strategy and corporate objectives defined
- Market research and competitive analysis available
- Stakeholder identification complete

**Inputs:**
- Business strategy documents
- Market research reports
- Customer insights and feedback
- Financial projections and constraints

**Steps:**
1. Synthesize business objectives into product vision statement
2. Identify strategic themes and investment horizons
3. Define success metrics (OKRs, KPIs)
4. Validate vision with key stakeholders
5. Communicate vision across organization

**Decision Points:**
- Vision alignment with business strategy (go/no-go)
- Investment horizon allocation (short/medium/long-term)
- Stakeholder consensus (escalation if misalignment)

**Human-AI Collaboration:**
- AI: Market trend analysis, competitive intelligence synthesis, sentiment analysis
- Human: Strategic judgment, stakeholder negotiation, vision articulation

**Roles/RACI:**
- Product Leader (Accountable)
- Executive Sponsor (Responsible)
- Engineering Leadership (Consulted)
- Marketing/Sales (Consulted)

**Tool Categories:**
- Strategic planning tools (Miro, Mural)
- Market intelligence platforms (CB Insights, Gartner)
- OKR management (Workboard, Lattice)

**Outputs:**
- Product vision statement
- Strategic themes document
- OKR framework with success metrics

**Quality/Security/Completion Criteria:**
- Vision statement validated by executive sponsor
- OKRs traceable to business objectives
- Stakeholder sign-off documented

**Automation Opportunities:**
- Automated market trend monitoring
- AI-assisted competitive intelligence gathering
- Automated OKR progress tracking

**Approval Boundaries:**
- Executive approval required for vision changes
- Product leader can adjust tactical priorities

**Escalation Paths:**
- Misalignment → Executive steering committee
- Resource constraints → Portfolio review board

**KPIs:**
- Strategic alignment score (≥90%)
- Stakeholder satisfaction (≥4/5)
- Vision communication reach (100% of relevant teams)

**Anti-patterns:**
- Vision without execution strategy
- Annual planning without quarterly adaptation
- Vision created in isolation from engineering

**Implementation Tiers:**
- **Minimum:** Vision statement + annual OKRs
- **Standard:** Vision + strategic themes + quarterly OKR reviews
- **Leading-edge:** AI-assisted market intelligence + dynamic OKR adjustment + continuous strategy validation

---

## Workflow 1.2: Portfolio Prioritization & Investment Allocation

**Objective:** Allocate resources across product initiatives to maximize value delivery while managing risk and technical debt.

**Classification:** Universal

**Triggers:**
- Quarterly planning cycle
- New initiative proposal
- Significant change in capacity or market conditions

**Preconditions:**
- Product vision and strategic themes defined
- Backlog of initiatives with estimated value and effort
- Capacity and resource constraints understood

**Inputs:**
- Initiative proposals with business cases
- Capacity forecasts
- Technical debt assessments
- Risk assessments

**Steps:**
1. Score initiatives using prioritization framework (RICE, WSJF)
2. Map initiatives to strategic themes
3. Allocate capacity across horizons (70/20/10 or similar)
4. Balance portfolio for risk and dependencies
5. Communicate allocation decisions and rationale

**Decision Points:**
- Initiative funding (approve/defer/reject)
- Capacity allocation across horizons
- Risk tolerance and trade-offs

**Human-AI Collaboration:**
- AI: Predictive value modeling, dependency analysis, capacity forecasting
- Human: Strategic judgment, stakeholder negotiation, risk appetite

**Roles/RACI:**
- Portfolio Manager (Accountable)
- Product Leaders (Responsible)
- Engineering Leadership (Consulted)
- Finance (Informed)

**Tool Categories:**
- Portfolio management (Aha!, Productboard)
- Prioritization frameworks (built-in or custom)
- Capacity planning tools

**Outputs:**
- Prioritized portfolio backlog
- Investment allocation by horizon
- Dependency map and risk register

**Quality/Security/Completion Criteria:**
- All initiatives scored and ranked
- Allocation aligns with strategic themes
- Stakeholder alignment documented

**Automation Opportunities:**
- Automated initiative scoring
- AI-assisted dependency detection
- Automated capacity forecasting

**Approval Boundaries:**
- Portfolio manager can approve within budget
- Executive approval for budget increases or strategic shifts

**Escalation Paths:**
- Resource conflicts → Portfolio review board
- Strategic misalignment → Executive steering committee

**KPIs:**
- Portfolio value realization (≥80%)
- Initiative cycle time
- Strategic theme coverage (≥90%)

**Anti-patterns:**
- Prioritization by loudest voice
- Over-commitment without capacity reality
- Ignoring technical debt in prioritization

**Implementation Tiers:**
- **Minimum:** Simple scoring + quarterly review
- **Standard:** Formal framework + capacity allocation + dependency tracking
- **Leading-edge:** AI-assisted value prediction + dynamic reallocation + continuous portfolio optimization

---

## Workflow 4.1: Architectural Vision & Principles Definition

**Objective:** Establish architectural principles and a technical vision that guides system design and evolution.

**Classification:** Universal

**Triggers:**
- New system or major system evolution
- Technology strategy refresh
- Significant architectural debt or misalignment

**Preconditions:**
- Business strategy and product vision understood
- Current system landscape documented
- Key stakeholders identified

**Inputs:**
- Business strategy and product vision
- Current architecture documentation
- Technology radar and trends
- Non-functional requirements

**Steps:**
1. Identify architectural drivers (business, technical, regulatory)
2. Define architectural principles (e.g., API-first, cloud-native, event-driven)
3. Establish fitness functions for key quality attributes
4. Document architectural vision and constraints
5. Socialize and gain alignment across teams

**Decision Points:**
- Principle adoption (consensus or escalation)
- Fitness function thresholds
- Technology adoption (trial/assess/adopt/hold)

**Human-AI Collaboration:**
- AI: Technology trend analysis, pattern recognition, dependency impact analysis
- Human: Strategic judgment, trade-off decisions, stakeholder alignment

**Roles/RACI:**
- Chief Architect / Architecture Lead (Accountable)
- Engineering Leadership (Responsible)
- Product Leadership (Consulted)
- Security (Consulted)

**Tool Categories:**
- Architecture modeling (C4, ArchiMate)
- Technology radar (ThoughtWorks-style)
- ADR management (ADR tools, GitHub)

**Outputs:**
- Architectural principles document
- Fitness function definitions
- Technology radar
- Architectural vision statement

**Quality/Security/Completion Criteria:**
- Principles traceable to business drivers
- Fitness functions measurable and automated
- Stakeholder alignment documented

**Automation Opportunities:**
- Automated fitness function execution
- Technology radar auto-updates
- ADR compliance checking

**Approval Boundaries:**
- Architecture lead can approve within principles
- Architecture review board for principle changes

**Escalation Paths:**
- Principle conflicts → Architecture review board
- Technology adoption disputes → CTO / VP Engineering

**KPIs:**
- Principle adoption rate (≥80%)
- Fitness function pass rate (100% critical)
- ADR coverage (≥90% significant decisions)

**Anti-patterns:**
- Principles without enforcement
- Ivory tower architecture disconnected from delivery
- Technology choices without fitness functions

**Implementation Tiers:**
- **Minimum:** Principles document + informal review
- **Standard:** Fitness functions + ADR process + technology radar
- **Leading-edge:** Automated fitness functions + AI-assisted design review + continuous architecture validation

---

## Workflow 4.2: Design Review & ADR Governance

**Objective:** Ensure architectural decisions are documented, reviewed, and aligned with principles and fitness functions.

**Classification:** Universal

**Triggers:**
- New feature or system requiring architectural decision
- Significant design change or technology adoption
- Fitness function failure or technical debt escalation

**Preconditions:**
- Architectural principles and fitness functions defined
- ADR template and process established
- Review participants identified

**Inputs:**
- Design proposals and alternatives
- Fitness function results
- Technical debt assessments
- Stakeholder requirements

**Steps:**
1. Submit design proposal with ADR draft
2. Review against principles and fitness functions
3. Evaluate alternatives and trade-offs
4. Document decision and rationale in ADR
5. Publish ADR and update architectural documentation

**Decision Points:**
- Design approval (approve/request changes/reject)
- Fitness function exception (grant/deny with conditions)
- ADR status (proposed/accepted/deprecated)

**Human-AI Collaboration:**
- AI: Automated fitness function checking, dependency impact analysis, pattern detection
- Human: Trade-off evaluation, risk assessment, stakeholder negotiation

**Roles/RACI:**
- Architecture Review Board (Accountable)
- Design Author (Responsible)
- Security (Consulted)
- Operations (Consulted)

**Tool Categories:**
- ADR management (adr-tools, Log4brains)
- Architecture modeling tools
- Automated compliance checking

**Outputs:**
- Approved ADR with decision and rationale
- Updated architectural documentation
- Fitness function compliance report

**Quality/Security/Completion Criteria:**
- ADR follows template and includes alternatives
- Decision traceable to principles and fitness functions
- Review participants sign-off documented

**Automation Opportunities:**
- Automated fitness function validation
- ADR template enforcement
- Automated dependency impact analysis

**Approval Boundaries:**
- Standard decisions: architecture lead approval
- Significant decisions: architecture review board
- Exceptions: CTO / VP Engineering

**Escalation Paths:**
- Review deadlock → Architecture review board chair
- Principle conflicts → Chief Architect

**KPIs:**
- ADR cycle time (≤5 business days)
- ADR coverage (≥90% significant decisions)
- Fitness function exception rate (≤10%)

**Anti-patterns:**
- ADRs as afterthought (post-decision documentation)
- Review without decision (analysis paralysis)
- Exceptions without sunset clauses

**Implementation Tiers:**
- **Minimum:** ADR template + informal review
- **Standard:** Formal review process + automated fitness functions + ADR lifecycle management
- **Leading-edge:** AI-assisted design review + automated compliance + continuous architecture validation

---

## Workflow 9.1: Test Strategy & Planning

**Objective:** Define a risk-based test strategy that balances coverage, speed, and confidence across the test pyramid.

**Classification:** Universal

**Triggers:**
- New project or major feature
- Test strategy refresh (quarterly/annually)
- Significant quality incident or escape

**Preconditions:**
- Requirements and acceptance criteria defined
- Architecture and design understood
- Risk assessment completed

**Inputs:**
- Requirements and acceptance criteria
- Architecture and design documents
- Risk assessments
- Historical defect data
- Compliance requirements

**Steps:**
1. Identify quality risks and test objectives
2. Define test pyramid allocation (unit/integration/e2e/manual)
3. Select test types and techniques for each level
4. Define test environments and data requirements
5. Establish quality gates and exit criteria

**Decision Points:**
- Test pyramid allocation (risk-based)
- Automation scope (what to automate vs. manual)
- Quality gate thresholds

**Human-AI Collaboration:**
- AI: Risk-based test selection, historical defect pattern analysis, test coverage optimization
- Human: Risk judgment, test strategy design, stakeholder alignment

**Roles/RACI:**
- QE Lead / Test Architect (Accountable)
- Development Team (Responsible)
- Product Owner (Consulted)
- Security (Consulted for security testing)

**Tool Categories:**
- Test management (TestRail, Zephyr)
- Risk assessment tools
- Coverage analysis tools

**Outputs:**
- Test strategy document
- Test plan with pyramid allocation
- Quality gate definitions
- Test environment and data requirements

**Quality/Security/Completion Criteria:**
- Strategy covers all quality risks
- Test pyramid aligned with risk profile
- Quality gates measurable and automated

**Automation Opportunities:**
- AI-assisted test strategy generation
- Automated risk-based test selection
- Automated coverage gap analysis

**Approval Boundaries:**
- QE lead can approve within strategy
- Architecture review for significant strategy changes

**Escalation Paths:**
- Risk disagreements → Product + Engineering leadership
- Resource constraints → Portfolio review

**KPIs:**
- Risk coverage (≥90% of identified risks)
- Test pyramid adherence (±10% of target allocation)
- Strategy review cycle time (≤1 week)

**Anti-patterns:**
- One-size-fits-all test strategy
- Strategy without risk analysis
- Ignoring non-functional testing

**Implementation Tiers:**
- **Minimum:** Basic test plan + manual test pyramid
- **Standard:** Risk-based strategy + automated pyramid + quality gates
- **Leading-edge:** AI-assisted strategy + dynamic test selection + continuous strategy optimization

---

## Workflow 9.2: Test Automation Development & Maintenance

**Objective:** Build and maintain a reliable, fast, and comprehensive automated test suite aligned with the test pyramid.

**Classification:** Universal

**Triggers:**
- New feature or code change
- Test strategy update
- Flaky test or automation debt identified

**Preconditions:**
- Test strategy and pyramid allocation defined
- Test infrastructure and environments available
- Coding standards and patterns established

**Inputs:**
- Test strategy and test plan
- Code changes and features under test
- Test data requirements
- Infrastructure and environment specifications

**Steps:**
1. Design test cases aligned with pyramid levels
2. Implement automated tests (unit, integration, e2e)
3. Set up test data and environment provisioning
4. Integrate tests into CI/CD pipeline
5. Monitor test health and maintain test suite

**Decision Points:**
- Test level assignment (unit vs. integration vs. e2e)
- Test data strategy (synthetic vs. production-like)
- Flaky test handling (quarantine/fix/delete)

**Human-AI Collaboration:**
- AI: AI-assisted test generation, test code review, flaky test detection
- Human: Test design, test intent validation, test maintenance

**Roles/RACI:**
- Development Team (Responsible)
- QE Lead (Accountable)
- DevOps / Platform (Consulted for infrastructure)

**Tool Categories:**
- Test frameworks (Jest, Pytest, Cypress, Playwright)
- Test data management
- CI/CD integration

**Outputs:**
- Automated test suites
- Test execution reports
- Test health dashboards
- Flaky test reports

**Quality/Security/Completion Criteria:**
- Tests aligned with pyramid allocation
- Test execution time within SLA (≤10 min CI suite)
- Flaky test rate ≤2%

**Automation Opportunities:**
- AI-assisted test generation
- Automated test maintenance
- Intelligent test selection

**Approval Boundaries:**
- Developers can add tests within guidelines
- QE lead approval for test strategy deviations

**Escalation Paths:**
- Infrastructure issues → Platform team
- Test debt → Engineering leadership

**KPIs:**
- Automated test coverage (≥80% critical paths)
- Test execution time (≤10 min CI suite)
- Flaky test rate (≤2%)
- Test maintenance effort (≤10% of test development)

**Anti-patterns:**
- Ice cream cone (too many e2e tests)
- Fragile tests tightly coupled to implementation
- Ignoring test maintenance

**Implementation Tiers:**
- **Minimum:** Unit tests for critical paths + basic CI integration
- **Standard:** Full pyramid + test health monitoring + flaky test management
- **Leading-edge:** AI-assisted generation + intelligent test selection + self-healing tests

---

## Workflow 10.1: Build Environment Setup & Maintenance

**Objective:** Provide reliable, reproducible, and secure build environments that support consistent artifact creation.

**Classification:** Universal

**Triggers:**
- New project or technology adoption
- Build environment drift or failure
- Security or compliance requirement change

**Preconditions:**
- Build requirements defined
- Infrastructure and tooling selected
- Security policies understood

**Inputs:**
- Build requirements and specifications
- Infrastructure and tooling selections
- Security and compliance policies
- Dependency manifests

**Steps:**
1. Define build environment specifications
2. Provision build infrastructure (immutable, containerized)
3. Configure build tools and dependencies
4. Validate build reproducibility
5. Monitor and maintain build environments

**Decision Points:**
- Build infrastructure model (cloud vs. on-prem, managed vs. self-hosted)
- Build isolation strategy (containers, VMs, hermetic)
- Dependency caching strategy

**Human-AI Collaboration:**
- AI: Build optimization recommendations, dependency conflict detection
- Human: Infrastructure decisions, security policy enforcement

**Roles/RACI:**
- DevOps / Platform Team (Accountable)
- Development Team (Responsible)
- Security (Consulted)

**Tool Categories:**
- Container orchestration (Docker, Podman)
- Build tools (Bazel, Gradle, Make)
- Infrastructure-as-code (Terraform, Pulumi)

**Outputs:**
- Build environment specifications
- Provisioned build infrastructure
- Build tool configurations
- Reproducibility validation reports

**Quality/Security/Completion Criteria:**
- Build reproducibility validated (100% deterministic)
- Security policies enforced in build environment
- Build environment documented and versioned

**Automation Opportunities:**
- Infrastructure-as-code for build environments
- Automated build environment validation
- Automated dependency caching

**Approval Boundaries:**
- Platform team can approve standard environments
- Security approval for custom environments

**Escalation Paths:**
- Infrastructure constraints → Platform leadership
- Security exceptions → Security leadership

**KPIs:**
- Build environment uptime (≥99.5%)
- Build reproducibility (100%)
- Environment provisioning time (≤30 minutes)

**Anti-patterns:**
- Snowflake build environments
- Manual environment setup
- Ignoring build environment security

**Implementation Tiers:**
- **Minimum:** Containerized builds + basic caching
- **Standard:** Immutable build agents + infrastructure-as-code + reproducibility validation
- **Leading-edge:** Hermetic builds + AI-assisted optimization + automated environment healing

---

## Workflow 10.2: Dependency Management & Vulnerability Scanning

**Objective:** Maintain secure, up-to-date, and traceable dependencies across all software artifacts.

**Classification:** Universal

**Triggers:**
- New dependency addition
- Vulnerability disclosure
- Regular dependency refresh cycle

**Preconditions:**
- Dependency manifests in version control
- Vulnerability scanning tools integrated
- Update policies defined

**Inputs:**
- Dependency manifests (package.json, requirements.txt, etc.)
- Vulnerability advisories (CVE databases, vendor alerts)
- Security policies and SLAs
- Build and test infrastructure

**Steps:**
1. Scan dependencies for known vulnerabilities
2. Prioritize vulnerabilities by severity and exploitability
3. Update or patch vulnerable dependencies
4. Validate updates with automated tests
5. Monitor for new vulnerabilities continuously

**Decision Points:**
- Vulnerability remediation priority (critical/high/medium/low)
- Update strategy (immediate patch vs. scheduled update)
- Exception handling (risk acceptance with mitigation)

**Human-AI Collaboration:**
- AI: Vulnerability impact analysis, automated patch suggestions, dependency conflict detection
- Human: Risk assessment, exception approval, strategic dependency decisions

**Roles/RACI:**
- Development Team (Responsible)
- Security Team (Accountable for policy)
- DevOps (Consulted for automation)

**Tool Categories:**
- Dependency scanning (Snyk, Dependabot, Trivy)
- SBOM generation (Syft, CycloneDX)
- Automated update tools (Renovate, Dependabot)

**Outputs:**
- Vulnerability scan reports
- Updated dependency manifests
- SBOMs for all artifacts
- Exception documentation (if applicable)

**Quality/Security/Completion Criteria:**
- Critical vulnerabilities remediated within SLA (≤7 days)
- SBOMs generated for all production artifacts
- Dependency freshness within policy (≤30 days)

**Automation Opportunities:**
- Automated vulnerability scanning in CI
- Automated dependency update PRs
- Automated SBOM generation

**Approval Boundaries:**
- Developers can approve standard updates
- Security approval for exceptions
- Architecture approval for major dependency changes

**Escalation Paths:**
- Remediation blockers → Security + Engineering leadership
- Supply chain incidents → Incident response team

**KPIs:**
- Critical vulnerability remediation time (≤7 days)
- Dependency freshness (≤30 days)
- SBOM coverage (100% production artifacts)

**Anti-patterns:**
- Ignoring low-severity vulnerabilities until they become critical
- Manual dependency updates without automation
- No SBOM or provenance tracking

**Implementation Tiers:**
- **Minimum:** Basic vulnerability scanning + manual updates
- **Standard:** Automated scanning + automated update PRs + SBOMs
- **Leading-edge:** AI-assisted impact analysis + automated remediation + continuous supply chain monitoring

---

## Workflow 11.1: Continuous Integration

**Objective:** Integrate code changes frequently, verify with automated builds and tests, and detect integration errors early.

**Classification:** Universal

**Triggers:**
- Code commit or pull request
- Scheduled build (nightly, weekly)
- Dependency or configuration change

**Preconditions:**
- Source code in version control
- Automated build and test infrastructure
- Test suite available (unit, integration)

**Inputs:**
- Code changes and pull requests
- Build configuration
- Test suites
- Dependency manifests

**Steps:**
1. Trigger build on code change
2. Compile and build artifacts
3. Run automated tests (unit, integration)
4. Run static analysis and security scans
5. Report results and gate merge

**Decision Points:**
- Build success/failure (gate merge)
- Test pass/fail (gate merge)
- Quality gate thresholds (coverage, security)

**Human-AI Collaboration:**
- AI: AI-assisted code review, automated test generation, build optimization
- Human: Code review, test design, build infrastructure maintenance

**Roles/RACI:**
- Development Team (Responsible)
- DevOps / Platform (Accountable for infrastructure)
- QE (Consulted for test strategy)

**Tool Categories:**
- CI platforms (GitHub Actions, GitLab CI, Jenkins)
- Build tools (language-specific)
- Test frameworks

**Outputs:**
- Build artifacts
- Test execution reports
- Static analysis reports
- Merge/PR status

**Quality/Security/Completion Criteria:**
- Build success rate ≥95%
- Test pass rate 100% (for merge)
- Static analysis within thresholds

**Automation Opportunities:**
- Fully automated build and test
- AI-assisted code review
- Automated build optimization

**Approval Boundaries:**
- Automated gates for standard merges
- Manual approval for exceptions or overrides

**Escalation Paths:**
- Broken mainline → Immediate fix or revert
- Infrastructure failures → Platform team

**KPIs:**
- Build success rate (≥95%)
- CI cycle time (≤10 minutes)
- Merge frequency (≥daily per developer)

**Anti-patterns:**
- Long-running CI (>30 minutes)
- Ignoring flaky tests
- Manual build steps

**Implementation Tiers:**
- **Minimum:** Automated build + unit tests on PR
- **Standard:** Full test pyramid + static analysis + security scans
- **Leading-edge:** AI-assisted review + intelligent test selection + predictive build optimization

---

## Workflow 11.2: Deployment Execution & Progressive Rollout

**Objective:** Deploy software changes safely and reliably using progressive delivery strategies.

**Classification:** Universal

**Triggers:**
- Successful CI pipeline completion
- Scheduled release window
- Emergency hotfix

**Preconditions:**
- CI pipeline passed all gates
- Deployment artifacts available
- Target environments provisioned
- Rollback plan defined

**Inputs:**
- Deployment artifacts and configuration
- Deployment strategy (canary, blue-green, rolling)
- Monitoring and alerting configuration
- Rollback procedures

**Steps:**
1. Validate deployment artifacts and configuration
2. Execute deployment using progressive strategy
3. Monitor deployment health and key metrics
4. Validate with automated and manual checks
5. Complete rollout or trigger rollback

**Decision Points:**
- Deployment strategy selection (risk-based)
- Rollout progression (automated vs. manual gates)
- Rollback trigger (automated thresholds or manual)

**Human-AI Collaboration:**
- AI: Automated canary analysis, anomaly detection, rollback recommendations
- Human: Deployment approval (when required), rollback decisions, incident response

**Roles/RACI:**
- DevOps / Platform (Accountable)
- Development Team (Responsible)
- Operations (Consulted)
- Product Owner (Informed for release decisions)

**Tool Categories:**
- Deployment tools (ArgoCD, Flux, Spinnaker)
- Feature flag platforms (LaunchDarkly, Unleash)
- Monitoring and observability (Prometheus, Grafana, Datadog)

**Outputs:**
- Deployed software in target environment
- Deployment logs and audit trail
- Health check results
- Rollback documentation (if applicable)

**Quality/Security/Completion Criteria:**
- Deployment success rate ≥95%
- Health checks passing
- Key metrics within thresholds
- Rollback tested and validated

**Automation Opportunities:**
- Automated deployment execution
- Automated canary analysis
- Automated rollback triggers

**Approval Boundaries:**
- Automated for standard deployments
- Manual approval for production (when required)
- Emergency deployments: expedited approval

**Escalation Paths:**
- Deployment failures → Incident response
- Rollback failures → Engineering leadership

**KPIs:**
- Deployment frequency (≥daily for high performers)
- Deployment success rate (≥95%)
- Mean time to deploy (≤1 hour)
- Rollback time (≤15 minutes)

**Anti-patterns:**
- Big bang deployments
- Manual deployment steps
- Insufficient monitoring post-deployment
- Untested rollback procedures

**Implementation Tiers:**
- **Minimum:** Automated deployment + basic health checks
- **Standard:** Progressive delivery + automated canary analysis + feature flags
- **Leading-edge:** AI-assisted deployment analysis + self-healing deployments + continuous verification

---

## Workflow 13.1: Threat Modeling & Risk Assessment

**Objective:** Identify, assess, and mitigate security threats early in the development lifecycle.

**Classification:** Universal (for any system handling sensitive data or operating in regulated environments)

**Triggers:**
- New system or major feature design
- Significant architecture change
- New threat intelligence or vulnerability disclosure
- Regulatory requirement change

**Preconditions:**
- System architecture and design understood
- Data flows and trust boundaries identified
- Threat modeling methodology selected

**Inputs:**
- System architecture and design documents
- Data flow diagrams
- Threat intelligence feeds
- Regulatory requirements
- Historical incident data

**Steps:**
1. Decompose system into components and data flows
2. Identify threats using structured methodology (STRIDE, PASTA)
3. Assess threat likelihood and impact
4. Define mitigations and security requirements
5. Document threat model and track mitigation progress

**Decision Points:**
- Threat model scope (system-wide vs. component)
- Risk acceptance (mitigate/accept/transfer/avoid)
- Mitigation priority (risk-based)

**Human-AI Collaboration:**
- AI: Automated threat identification, pattern recognition, mitigation suggestions
- Human: Risk judgment, mitigation design, threat model validation

**Roles/RACI:**
- Security Team (Accountable)
- Architecture / Design Team (Responsible)
- Development Team (Consulted)
- Product Owner (Informed)

**Tool Categories:**
- Threat modeling tools (Threat Dragon, IriusRisk)
- Risk assessment frameworks
- Security requirements management

**Outputs:**
- Threat model document
- Risk register with mitigations
- Security requirements and acceptance criteria
- Mitigation tracking

**Quality/Security/Completion Criteria:**
- All critical threats identified and assessed
- Mitigations defined for high-risk threats
- Threat model reviewed and approved

**Automation Opportunities:**
- AI-assisted threat identification
- Automated threat model generation from architecture
- Automated mitigation tracking

**Approval Boundaries:**
- Security team approves threat models
- Risk acceptance requires security + product leadership

**Escalation Paths:**
- Unmitigated critical risks → CISO / Security leadership
- Resource constraints → Portfolio review

**KPIs:**
- Threat model coverage (≥90% of critical systems)
- Mitigation implementation rate (≥80% of high-risk threats)
- Threat model review cycle time (≤1 week)

**Anti-patterns:**
- Threat modeling as a one-time activity
- Threat models disconnected from development
- Ignoring low-likelihood, high-impact threats

**Implementation Tiers:**
- **Minimum:** Basic threat model for critical systems
- **Standard:** Structured methodology + mitigation tracking + regular reviews
- **Leading-edge:** AI-assisted threat modeling + continuous threat model updates + automated mitigation validation

---

## Workflow 13.2: Security Testing & Verification

**Objective:** Validate that security controls are effective and that the system is resilient to attacks.

**Classification:** Universal (for any system handling sensitive data or operating in regulated environments)

**Triggers:**
- Code changes affecting security controls
- Pre-release security validation
- Regulatory or compliance requirement
- Security incident or vulnerability disclosure

**Preconditions:**
- Security requirements defined
- Test environments available
- Security testing tools integrated

**Inputs:**
- Security requirements and threat model
- Code changes and architecture
- Test environments and data
- Security testing tools and frameworks

**Steps:**
1. Define security test scope and objectives
2. Execute automated security tests (SAST, DAST, SCA)
3. Perform manual security testing (penetration testing, code review)
4. Analyze findings and prioritize remediation
5. Validate fixes and update security posture

**Decision Points:**
- Test scope (automated vs. manual, internal vs. external)
- Finding severity (critical/high/medium/low)
- Remediation priority and timeline

**Human-AI Collaboration:**
- AI: Automated vulnerability detection, false positive filtering, remediation suggestions
- Human: Manual penetration testing, risk assessment, remediation design

**Roles/RACI:**
- Security Team (Accountable)
- Development Team (Responsible for remediation)
- QE Team (Consulted for integration)

**Tool Categories:**
- SAST tools (SonarQube, Semgrep, CodeQL)
- DAST tools (OWASP ZAP, Burp Suite)
- SCA tools (Snyk, Dependabot)
- Penetration testing frameworks

**Outputs:**
- Security test reports
- Vulnerability findings with severity
- Remediation plans and tracking
- Security posture assessment

**Quality/Security/Completion Criteria:**
- All critical and high vulnerabilities remediated
- Security tests integrated into CI/CD
- Penetration testing completed (annually or per release)

**Automation Opportunities:**
- Automated SAST/DAST/SCA in CI
- Automated vulnerability triage
- Automated remediation validation

**Approval Boundaries:**
- Security team approves security test results
- Risk acceptance for unresolved findings requires security leadership

**Escalation Paths:**
- Critical vulnerabilities → Immediate remediation or release block
- Resource constraints → Security + Engineering leadership

**KPIs:**
- Security test coverage (≥90% of OWASP Top 10)
- Critical vulnerability remediation time (≤7 days)
- False positive rate (≤20%)

**Anti-patterns:**
- Security testing only at release
- Ignoring low-severity findings until they accumulate
- Manual-only security testing

**Implementation Tiers:**
- **Minimum:** Basic SAST + annual penetration test
- **Standard:** Automated SAST/DAST/SCA in CI + regular penetration testing
- **Leading-edge:** Continuous security testing + AI-assisted triage + bug bounty program

---

# Evidence Gaps & Limitations

## Evidence Gaps Encountered

1. **AI-assisted product discovery:** Limited peer-reviewed evidence on effectiveness; mostly vendor case studies.
2. **AI-generated test quality:** Emerging area; limited longitudinal studies on test effectiveness and maintenance burden.
3. **Fitness function automation:** Strong conceptual evidence (ThoughtWorks, evolutionary architecture); limited large-scale adoption data.
4. **SLSA Level 3+ adoption:** Early adopter stage; limited production evidence beyond major tech companies.
5. **AI-assisted threat modeling:** Emerging capability; limited independent validation.

## Confidence Notes

- Claims triangulated across ≥2 sources (DORA, Martin Fowler, OWASP, NIST, AWS, CNCF) are marked with confidence ≥0.85.
- Single-source claims (e.g., specific vendor case studies) are marked with confidence <0.7 and flagged as "Evidence limited."
- Emerging practices (AI-assisted design, AI-generated tests) are classified as "emerging" with appropriate confidence levels.

---

**End of Subagent 1 Deliverable**
