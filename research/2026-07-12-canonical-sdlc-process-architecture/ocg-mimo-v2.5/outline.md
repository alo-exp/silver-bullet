# Outline — Canonical SDLC Process Architecture

## 1. Executive Summary
- Research scope and methodology
- Key findings: 18 process areas, evidence-based practices
- AI adoption: 90%+ professionals, amplification effect
- Maturity tiers: minimum / standard / leading-edge

## 2. Research Method and Evidence Base
- Sources: DORA, Google SRE, OWASP, NIST, OpenSSF, CNCF, 15+ company blogs
- Triangulation: >=2 sources for major claims
- Practice classification: universal / leading-edge / context-dependent / emerging

## 3. Canonical Process-Area Taxonomy
### PA1: Strategy, Portfolio & Product Direction
- Workflows: OKR setting, portfolio prioritization, roadmap planning
- Universal practices: product-led discovery, evidence-based prioritization

### PA2: Discovery, Requirements & Product Definition
- Workflows: User research, requirements gathering, acceptance criteria
- Universal practices: user story mapping, behavior-driven development

### PA3: UX & Product Design
- Workflows: Design thinking, prototyping, design systems
- Universal practices: design systems, accessibility-first design

### PA4: Architecture & Technical Design
- Workflows: ADRs, architecture reviews, API design
- Universal practices: loosely coupled architecture, API versioning

### PA5: Planning & Work Management
- Workflows: Sprint planning, capacity allocation, technical debt management
- Universal practices: agile/lean methodology, visible work in value stream

### PA6: Development Environment & Toolchain
- Workflows: IDE setup, local development, toolchain integration
- Universal practices: standardized toolchains, documentation as code

### PA7: Software Implementation
- Workflows: Coding, pair programming, trunk-based development
- Universal practices: small batch sizes, automated formatting/linting

### PA8: Code Review & Knowledge Sharing
- Workflows: Pull request review, design reviews, knowledge transfer
- Universal practices: peer review, CODEOWNERS, reviewer rotation

### PA9: Testing, QE & Verification
- Workflows: Unit testing, integration testing, E2E testing, exploratory testing
- Universal practices: test pyramid, developer-owned testing, shift-left testing

### PA10: Build, Integration & Artifact Management
- Workflows: Build automation, dependency management, artifact versioning
- Universal practices: reproducible builds, SBOM generation

### PA11: CI, Release & Deployment
- Workflows: CI pipeline, CD pipeline, release management, feature flags
- Universal practices: trunk-based development, progressive rollouts, rollback

### PA12: Platform Engineering & IDP
- Workflows: IDP development, golden paths, developer self-service
- Leading-edge: platform as product, developer portals (Backstage)

### PA13: Security, Privacy, Risk & Compliance
- Workflows: Threat modeling, security scanning, compliance checks
- Universal practices: shift-left security, SAST/SCA/DAST, SBOM

### PA14: Reliability, Operations & SRE
- Workflows: SLO/SLI management, error budgets, on-call, incident response
- Universal practices: blameless postmortems, error budgets

### PA15: Observability & Production Feedback
- Workflows: Monitoring, distributed tracing, alerting, log aggregation
- Universal practices: OpenTelemetry, structured logging, SLI-based alerting

### PA16: Measurement, DevEx & Continuous Improvement
- Workflows: DORA metrics tracking, developer surveys, retrospectives
- Universal practices: DORA metrics, continuous improvement culture

### PA17: Maintenance, Evolution & Retirement
- Workflows: Deprecation planning, migration, service retirement
- Universal practices: strangler fig pattern, versioned APIs

### PA18: AI-Assisted / Agentic Software Engineering
- Workflows: AI code generation, AI code review, AI testing, AI documentation
- Leading-edge: AI agents for coding, autonomous testing agents
- Emerging: AI-native development workflows

## 4. Full Workflow Library
- Detailed workflows for each process area
- Per-workflow: triggers, steps, decision points, RACI, tools, outputs

## 5. Cross-Area Dependency and Feedback Map
- Feedback loops between process areas
- Dependency graph: which PAs depend on which

## 6. AI-Integration Layer
- AI adoption statistics and maturity
- AI practices across the SDLC
- Risks and mitigation strategies

## 7. Deprecated or Diminishing Practices
- Manual QA gates
- heavyweight change approval
- Long-lived feature branches
- Documentation silos

## 8. Maturity Model
- Minimum tier: baseline practices
- Standard tier: industry-average practices
- Leading-edge tier: elite performer practices

## 9. Role Model and Governance Implications
- RACI across process areas
- Role definitions and responsibilities
- Governance structure recommendations

## 10. Final Recommended Canonical Industry Standard
- Synthesis of evidence-based practices
- Implementation roadmap
- Success criteria
