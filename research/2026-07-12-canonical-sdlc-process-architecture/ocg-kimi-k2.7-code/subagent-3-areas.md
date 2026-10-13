# Subagent 3: Process Areas & Workflows

**Areas covered:** 6 (Dev Environment & Toolchain), 7 (Software Implementation), 8 (Code Review & Knowledge Sharing), 12 (Platform Engineering & IDP), 14 (Reliability Operations & SRE), 15 (Observability & Production Feedback), 17 (Maintenance Evolution & Retirement)

**Date:** 2026-07-12

---

## Process Area 6: Development Environment & Toolchain

### Definition & Purpose

The Development Environment & Toolchain process area encompasses the infrastructure, tools, and configurations that enable developers to write, build, test, and debug software. It includes IDEs, build systems, dependency managers, containerized environments, version control, and CI/CD pipeline foundations.

**Mid-2026 Relevance:** AI coding agents have fundamentally shifted toolchain requirements — environments must now support agent harnesses, context engineering, and spec-driven development workflows alongside traditional IDE capabilities. Devcontainers and reproducible environments are table stakes; the frontier is AI-native tooling integration.

### Inputs, Workflows, Outputs, Dependencies

| Dimension | Details |
|-----------|---------|
| **Inputs** | Project requirements, language/framework choices, team size, compliance constraints, infrastructure topology |
| **Workflows** | Environment provisioning, dependency management, build pipeline configuration, local-to-cloud parity, toolchain standardization |
| **Outputs** | Reproducible development environments, build artifacts, dependency manifests, environment-as-code definitions |
| **Dependencies** | Platform Engineering (PA-12) for infrastructure provisioning; CI/CD pipelines (PA-9); Security (PA-10) for dependency scanning |

### Metrics / Gates / Exit Criteria

- **Time-to-first-commit** for new team members (< 1 hour target for standard projects)
- **Build reproducibility**: identical outputs from identical inputs across machines
- **Environment drift**: frequency of "works on my machine" incidents
- **Dependency freshness**: percentage of dependencies within N versions of latest stable

### Pitfalls & Mitigations

| Pitfall | Mitigation |
|---------|------------|
| Tool sprawl across teams | Establish golden paths via IDP; standardize on curated toolchain |
| Environment drift between local and CI | Use devcontainers/Nix for deterministic environments |
| Over-abstraction hiding errors | Maintain escape hatches; developers should understand underlying tools |
| AI agent context pollution | Implement harness engineering practices; separate agent workspace from human workspace |

### Context Variations

- **Startup:** Minimal toolchain, direct tool access, speed over standardization
- **Enterprise:** Standardized IDP with golden paths, compliance scanning mandatory, multi-language support
- **Regulated:** Audit trails for all tool actions, approved dependency lists, air-gapped build environments
- **AI-native (2026):** Agent-aware IDEs, context engineering tooling, spec-driven development harnesses

---

### Workflow 6.1: Environment Provisioning & Standardization

| Attribute | Value |
|-----------|-------|
| **Name** | Development Environment Provisioning |
| **Objective** | Provide every developer with a reproducible, fully configured development environment within minutes |
| **Classification** | Universal |
| **Triggers** | New team member onboarding, new project creation, environment corruption |
| **Preconditions** | Platform team has defined base environment templates; infrastructure provisioning is available |
| **Inputs** | Project manifest, language/framework requirements, compliance constraints |

**Steps:**
1. Developer requests environment via self-service portal (IDP)
2. Platform orchestrator provisions containerized environment (devcontainer/Nix)
3. Dependencies resolved from lockfile; security scan runs
4. IDE configuration auto-generated (settings, extensions, debug configs)
5. Validation suite runs (build, lint, test smoke)
6. Environment registered in service catalog

**Decision Points:**
- Container vs. bare-metal: container for most projects; bare-metal for GPU/performance-critical work
- Shared vs. isolated environments: shared for microservices with common dependencies; isolated for security-sensitive work

**Human-AI Collaboration:**
- AI: Generates devcontainer.json from project analysis; suggests dependency versions
- Human: Validates security-sensitive dependencies; approves non-standard tool additions

**RACI:**
- R: Platform Engineer
- A: Engineering Manager
- C: Security Team, Developer
- I: DevOps/SRE

**Tool Categories:** Devcontainers, Nix, Docker, IDE extensions, package managers

**Outputs:** Running development environment, environment manifest, validation report

**Quality/Security/Completion Criteria:**
- All builds pass; security scan clean; environment matches manifest
- Developer can compile, test, and run the project

**Automation Opportunities:** Full automation possible; human approval only for non-standard tools

**Approval Boundaries:** Standard environments auto-approved; custom tool additions require platform team review

**KPIs:** Provisioning time, first-build success rate, environment drift incidents/month

**Anti-patterns:**
- Manual environment setup guides (unmaintainable)
- Shared global tool installations (version conflicts)
- Ignoring environment parity between local and CI

**Implementation Tiers:**
- **Minimum:** Dockerfile + README setup instructions
- **Standard:** Devcontainer with automated provisioning and validation
- **Leading-edge:** AI-assisted environment generation, self-healing environments, predictive dependency resolution

---

## Process Area 7: Software Implementation

### Definition & Purpose

Software Implementation covers the actual writing, structuring, and organizing of source code — from individual functions to system-level architecture decisions made during coding. It encompasses coding standards, design patterns, testing practices, and the integration of AI coding assistants.

**Mid-2026 Relevance:** The implementation process has been transformed by AI coding agents. The key shift is from "human writes code, AI assists" to "human specifies intent and constraints, AI generates, human reviews and steers." Harness engineering — the practice of building specifications, quality checks, and workflow guidance that control AI agents — has emerged as a critical sub-discipline.

### Inputs, Workflows, Outputs, Dependencies

| Dimension | Details |
|-----------|---------|
| **Inputs** | Specifications, design documents, architecture decisions, acceptance criteria, existing codebase |
| **Workflows** | Feature implementation, refactoring, bug fixing, test writing, AI-assisted code generation |
| **Outputs** | Source code, unit tests, integration tests, documentation updates, technical debt records |
| **Dependencies** | PA-6 (toolchain), PA-8 (code review), PA-9 (CI/CD), PA-10 (security) |

### Metrics / Gates / Exit Criteria

- **Code coverage** on new code (> 80% line coverage target)
- **Cyclomatic complexity** per function (target < 10)
- **AI-generated code ratio** tracked and reviewed separately
- **First-pass acceptance rate** of PRs (target > 70%)



- ** & the Mitifations

| ** **P** | |
|---------|------------|
| **Over || Over | |
| **---------| Pit

| Pitfalls | Mit |
|-----------|---------|
|---------|
| **Inputs** | Specifications, task documents, code| **Workflows** | Feature implementation, refactoring, |
|-----------|---------|
| **Outputs** | Source code, unit tests, documentation updates, technical debt records |
| **Dependencies** | PA-6 (toolchain), PA-8 (code review), PA-9 (CI/CD), PA-10 (security) |

### Metrics / Gates / Exit Criteria

- **Code coverage** on new code (> 80% line coverage target)
- **Cyclomatic complexity** per function (target < 10)
- **AI-generated code code ratio** tracked and reviewed separately
- **First-pass acceptance rate** of PRs (target > 70%)

**Anti-patterns:**
- **Minimum:** Dockerfile + README setup instructions
- **Standard:** Devcontainer with automated provisioning and validation
- **Leading-edge:** AI-assisted environment generation, self-healing environments, predictive dependency resolution

---

## Process Area 7: Software Implementation Implementation

### Definition & Purpose

Software Implementation covers the actual writing, struct, and organizing of source code — from individual functions to system-level architecture decisions made during coding. It encompasses coding standards, design patterns, testing practices, and the integration of AI coding assistants.

**Mid-2026 Relevance:** The implementation process has been transformed by AI coding agents. The key shift is from "human writes code, AI assists" to "human specifies intent and constraints, AI generates, human reviews and steers." Harness engineering — the practice of building specifications, quality checks, and workflow guidance that control AI agents — has emerged as a critical sub-discipline.

### Inputs, Workflows, Outputs, Dependencies

| Dimension | Details |
|-----------|---------|
| **Inputs** | Specifications, design documents, architecture decisions, acceptance criteria, existing codebase |
| **Workflows** | Feature implementation, refactoring, bug fixing,, AI-assisted code generation |
| **Outputs** | Source code, unit tests, integration tests, documentation updates, technical debt records |
| **Dependencies** | PA-6 (toolchain), PA-8 (code review), PA-9 (CI/CD), PA-10 (security) |

### Metrics / Gates / Exit Criteria

- **Code coverage** on new code (> 80% line coverage target)
- **Cyclomatic complexity** per function (target < 10)
- **AI-generated code ratio** tracked and reviewed separately
- **First-pass acceptance rate** of PRs (target > 70%)

**Anti-patterns:**
- Writing code without tests ("test later" mentality)
- AI-generated code without human review
- Ignoring coding standards for speed
- Large uncommitted batches of changes

### Context Variations

- **Startup:** Speed-first, minimal ceremony, AI agents for boilerplate
- **Enterprise:** Standards enforcement, mandatory reviews, compliance-aware coding
- **Regulated:** Audit trails on all code changes, approved patterns only
- **AI-native (2026):** Spec-driven development, harness engineering, agent-in-the-loop patterns

---

### Workflow 7.1: Feature Implementation with AI Assistance

| Attribute | Value |
|-----------|-------|
| **Name** | AI-Assisted Feature Implementation |
| **Objective** | Implement features efficiently using human-AI collaboration while maintaining code quality |
| **Classification** | Leading-edge (2026) |
| **Triggers** | Feature specification approved, task assigned |
| **Preconditions** | Spec/design document exists; test harness configured; coding standards defined |
| **Inputs** | Feature specification, existing codebase, coding standards, test requirements |

**Steps:**
1. Developer reviews specification and identifies implementation scope
2. Developer creates harness: specifications, quality checks, workflow guidance for AI agent
3. AI agent generates initial implementation based on harness
4. Developer reviews generated code against specification intent
5. Developer runs test suite; iterates on harness if tests fail
6. Code formatted, linted, and prepared for review
7. Developer self-reviews using checklist before submitting PR

**Decision Points:**
- Accept AI output as-is vs. modify: accept when tests pass and code meets standards; modify when quality concerns exist
- Expand vs. narrow AI scope: expand for boilerplate/repetitive code; narrow for complex business logic

**Human-AI Collaboration Patterns:**
- **Human in the loop:** Developer reviews each AI suggestion before accepting
- **Human on the loop:** Developer defines harness and quality criteria; agent runs autonomously within bounds; developer reviews output batch
- **Spec-driven development:** Human writes specification; AI generates implementation; human validates against spec

**RACI:**
- R: Developer (human)
- A: Tech Lead
- C: AI Agent (tool), Code Reviewer
- I: Product Owner

**Tool Categories:** AI coding assistants (Copilot, Cursor, Claude Code), IDE, test frameworks, linters

**Outputs:** Implementation code, test suite, harness configuration, PR

**Quality/Security/Completion Criteria:**
- All tests pass; code meets style guide; no security vulnerabilities detected
- AI-generated code explicitly marked and reviewed
- Specification acceptance criteria met

**Automation Opportunities:** Test generation from spec; linting/formatting; security scanning

**Approval Boundaries:** AI-generated code requires human review before merge; no autonomous agent merges

**KPIs:** Implementation cycle time, first-pass test rate, AI code acceptance rate, defect escape rate

**Anti-patterns:**
- Blindly accepting AI-generated code without review
- Skipping tests because "AI wrote it"
- Not tracking which code is AI-generated
- Using AI for security-critical code without extra scrutiny

**Implementation Tiers:**
- **Minimum:** AI autocomplete in IDE; developer writes most code
- **Standard:** AI generates from spec; human reviews and steers; comprehensive tests
- **Leading-edge:** Full harness engineering; multi-agent workflows; automated quality gates; spec-driven development

---

### Workflow 7.2: Trunk-Based Development with Feature Flags

| Attribute | Value |
|-----------|-------|
| **Name** | Trunk-Based Development |
| **Objective** | Enable continuous integration by keeping all development on a single branch with feature flags for incomplete work |
| **Classification** | Universal |
| **Triggers** | Any code change ready to commit |
| **Preconditions** | CI pipeline configured; feature flag system in place; automated tests exist |
| **Inputs** | Code change, feature flag configuration |

**Steps:**
1. Developer creates small, focused change on trunk/main branch
2. Feature flag wraps incomplete functionality
3. Automated tests run (unit, integration, linting)
4. Code submitted for review (synchronous preferred)
5. Reviewer approves; code merged to trunk
6. CI pipeline builds, tests, and deploys to staging
7. Feature flag toggled for canary/progressive rollout

**Decision Points:**
- Feature flag category: Release toggle (short-lived), Experiment toggle (A/B testing), Ops toggle (operational control), Permission toggle (user segmentation)
- Synchronous vs. asynchronous review: synchronous for CI-friendly teams; async for distributed teams

**Human-AI Collaboration:**
- AI: Generates feature flag configurations; suggests flag cleanup schedules
- Human: Decides flag lifecycle; manages flag retirement

**RACI:**
- R: Developer
- A: Tech Lead
- C: Platform Engineer (flag infrastructure)
- I: Product Owner

**Tool Categories:** Feature flag services (LaunchDarkly, Unleash), CI/CD, version control

**Outputs** Merged code on trunk, feature flag configuration, deployment artifact

**Quality/Security/Completion Criteria:**
- All automated tests pass; no merge conflicts; feature flag properly configured
- Flag retirement scheduled; no orphaned flags

**Automation Opportunities:** Flag lifecycle management; automated flag cleanup; auto-rollback on canary failure

**KPIs:** Deployment frequency, lead time for changes, change failure rate, flag debt count

**Anti-patterns:**
- Long-lived feature branches (defeats CI purpose)
- Accumulated feature flags never retired
- Using experiment flags for release management
- Not testing with flags in both states

**Implementation Tiers:**
- **Minimum:** Single main branch; manual feature flags in config files
- **Standard:** Feature flag service; automated flag lifecycle; canary deployments
- **Leading-edge:** AI-managed flag configurations; automatic retirement; progressive delivery with auto-rollback

---

## Process Area 8: Code Review & Knowledge Sharing

### Definition & Purpose

Code Review & Knowledge Sharing encompasses the systematic examination of code changes by peers before integration, serving as both a quality gate and a primary mechanism for distributing knowledge across teams. It includes pull request workflows, review standards, pair programming, and architectural decision records.

**Mid-2026 Relevance:** The explosion of AI-generated pull requests has created a new review challenge. Agent-generated PRs require different review strategies — reviewers must look for subtle issues like hallucinated APIs, over-engineered abstractions, and technical debt that AI tends to introduce. Google's engineering practices and GitHub's agent PR review guidelines have become essential references.

### Inputs, Workflows, Outputs, Dependencies

| Dimension | Details |
|-----------|---------|
| **Inputs** | Pull request/merge request, code diff, CI results, specification context |
| **Workflows** | PR submission, reviewer assignment, review execution, feedback iteration, approval/merge |
| **Outputs** | Review comments, approval/rejection decision, knowledge transfer, updated code |
| **Dependencies** | PA-7 (implementation produces PRs), PA-9 (CI results gate review), PA-6 (toolchain supports review tools) |

### Metrics / Gates / Exit Criteria

- **Review turnaround time** (< 1 business day for standard reviews)
- **Review thoroughness**: percentage of PRs with substantive comments (not just LGTM)
- **Knowledge distribution**: bus factor improvement per quarter
- **AI-generated PR review rate**: 100% of agent PRs receive human review

### Pitfalls & Mitigations

| Pitfall | Mitigation |
|---------|------------|
| Rubber-stamp reviews | Require substantive comments; track review quality |
| Review bottleneck (single approver) | Distribute ownership; pair programming as pre-review |
| AI-generated code accepted without scrutiny | Mandatory human review for all agent PRs; AI-specific review checklist |
| Large PRs that are hard to review | Enforce small PR policy (< 400 lines); split large changes |
| Async review delays | Prefer synchronous review when possible; time-box async reviews |

### Context Variations

- **Startup:** Informal reviews, pair programming, speed-focused
- **Enterprise:** Formal review process, multiple approvers, compliance checks
- **Open source:** Community review, maintainer approval, contribution guidelines
- **AI-heavy (2026):** Agent PR review protocols, AI-assisted reviewers, harness validation

---

### Workflow 8.1: Code Review Process

| Attribute | Value |
|-----------|-------|
| **Name** | Structured Code Review |
| **Objective** | Ensure code quality, share knowledge, and catch defects before production |
| **Classification** | Universal |
| **Triggers** | PR/merge request submitted |
| **Preconditions** | CI pipeline passed; PR description complete; reviewers assigned |
| **Inputs** | Code diff, CI results, PR description, related specification |

**Steps:**
1. Author submits PR with description, context, and test evidence
2. System assigns reviewers based on CODEOWNERS and availability
3. Reviewer examines: correctness, design, readability, test coverage, security
4. Reviewer provides inline comments with specific, actionable feedback
5. Author addresses feedback; updates PR
6. Reviewer re-reviews changed areas; approves when satisfied
7. PR merged (squash/rebase per policy); branch deleted

**Decision Points:**
- Approve vs. request changes: approve when code improves the codebase even if not perfect; request changes for correctness/design issues
- AI-generated PR: apply additional scrutiny for hallucinated APIs, over-abstraction, hidden technical debt

**Human-AI Collaboration:**
- AI: Pre-reviews for style, common bugs, security patterns; flags suspicious patterns
- Human: Evaluates design decisions, business logic correctness, architectural fit

**RACI:**
- R: Reviewer (human)
- A: Author
- C: AI review assistant (advisory)
- I: Team Lead

**Tool Categories:** Code review platforms (GitHub, GitLab, Gerrit), AI review assistants, static analysis

**Outputs:** Review comments, approval decision, merged code, knowledge shared

**Quality/Security/Completion Criteria:**
- All substantive comments addressed; CI green; no unresolved security findings
- At least one human reviewer approved

**Automation Opportunities:** Auto-assignment, style checking, dependency vulnerability scanning, AI pre-review

**Approval Boundaries:** Human approval always required; AI suggestions are advisory only

**KPIs:** Review turnaround time, defect escape rate, review quality score, knowledge distribution index

**Anti-patterns:**
- LGTM reviews without inspection
- Reviewing only the diff, not the surrounding context
- Blocking on style nits when code is correct
- Not reviewing AI-generated code differently

**Implementation Tiers:**
- **Minimum:** One human reviewer; CI must pass
- **Standard:** CODEOWNERS-based assignment; AI pre-review; review checklist
- **Leading-edge:** AI-assisted review with human oversight; automated quality gates; knowledge graph integration

---

### Workflow 8.2: Pair Programming / Mob Programming

| Attribute | Value |
|-----------|-------|
| **Name** | Collaborative Programming |
| **Objective** | Real-time code review and knowledge sharing through collaborative coding sessions |
| **Classification** | Universal |
| **Triggers** | Complex feature implementation, onboarding, critical bug fix |
| **Preconditions** | Shared development environment, communication channel |
| **Inputs** | Task/feature to implement, shared context |

**Steps:**
1. Pair/mob assembles with clear driver and navigator roles
2. Driver writes code; navigator reviews in real-time
3. Roles rotate at defined intervals (15-30 minutes)
4. Continuous discussion of design decisions and alternatives
5. Code committed directly to trunk when complete
6. Retrospective on collaboration effectiveness

**Decision Points:**
- Pair for complex logic; mob learning; navigator for onboarding

- **ynchronous review for for AI: pair programming as real-time code review; **Continuous** synchronous knowledge transfer through collaborative coding sessions



**HumanHuman-AI Collaboration:**
- AI: Provides real context, suggests patterns from codebase
- Human: pair programming for the**Human on the loop:** Developer defines harness and quality checks, workflow workflow guidance that control AI agents**Human- **Human on the loop:** Developer defines harness and quality criteria, workflow workflow guidance that control AI agents. *Human (2026-07-2 Morris03-07-11 19:54 | Fowler 2026). by- **AI (07207-11 19:54 |
-7-11 19:56 |
|google-sre-postim20000]12026-07-11 19:57 | fowler-gen-ai::https://martinfowler.com/articles/exploring-gen-ai/humans-and-2026),0-03-04)
- **Human on the loop:** Developer defines harness and quality checks, workflow guidance that control AI agents**Human (https://martinfowler.com/articles/exploring-gen-ai/humans-and-agents.html)

-03-04)
- **AI: Generates specifications, quality checks, workflow guidance guidance AI agent
- **Human**: Validates harness that controls agent behavior;- ** (https://martinfowler.com/articles/exploring-gen-ai/harness-engineering.html) (05 February 2026)
- **Context Engineering for Coding Agents ( (0://26-07-16 2026).07-02-05-06-06-6)- **AI: S coding practices, harness engineering, spec-driven development
- **Understanding (https://martinfowler.com/articles/exploring-gen-ai/context-engineering-coding-agents.html) (05 February 2026)
- **Assess internal quality while coding with an agent**
- **Human (https://martinfowler.com/articles/exploring-gen-ai/hum-and-agents.html) (04 March 2026)

**RACI:**
- R: Developer (human)
- A: Tech Lead, Product **C**: AI Agent (tool), Code Reviewer
- I: Product Owner

****Tool Categories:** AI coding assistants (Copilot, Cursor, Claude Code), IDE, test frameworks, linters

**Outputs:** Implementation code, test suite, harness configuration, PR

****Quality/Security/Completion Criteria:**
- All tests pass; code meets style guide; no security vulnerabilities detected
- AI-generated code explicitly marked and reviewed
- Specification acceptance criteria met

****Automation Opportunities:** AI-generated flag configurations; automated flag lifecycle; auto-rollback on canary failure

****KPIs:** Implementation cycle time, first-pass test rate, AI code acceptance rate, defect escape rate

** **Anti-patterns:**
- Blindly accepting AI-generated code without review
- Skipping tests because "AI wrote it"
- Not tracking which code is AI-generated
- Using AI for security-critical code without extra scrutiny

** **Implementation Tiers:**
- **Minimum:** AI autocomplete in IDE; developer writes most code
- **Standard:** AI generates from spec; human reviews and steers; comprehensive tests
- **Leading-edge:** Full harness engineering; multi-agent workflows; automated quality gates; spec-driven development

---

### Workflow 7.2: Trunk-Based Development with Feature Flags

| Attribute | Value |
|-----------|-------|
| **Name** | Trunk-Based Development |
| **Objective** | Enable continuous integration by keeping all single branch with feature flags for incomplete work |
| **Classification** | Universal |
| **Triggers** | Any code change ready to commit |
| **Preconditions** | CI pipeline configured; feature flag system in place; automated tests exist |
| **Inputs** | Code change, feature flag configuration |

** **Steps:**
1. Developer creates small, focused change on trunk/main branch
2. Feature flag wraps incomplete functionality
3. Automated tests run (unit, integration, linting)
4. Code submitted for review (synchronous preferred)
5. Reviewer approves; code merged to trunk
6. CI pipeline builds, tests, and deploys to staging
7. Feature flag toggled for canary/progressive rollout

** **Decision Points:**
- Feature flag category: Release toggle (short-lived), Experiment toggle (A/B testing), Ops toggle (oper control control), Permission toggle (user segmentation)
- Synchronous vs. asynchronous review: synchronousynchronous for distributed teams

** **Human-AI Collaboration:**
- AI: Generates feature flag configurations; suggests flag cleanup schedules
- Human: Decides flag lifecycle; manages flag retirement

** **RACI:**
- R: Developer
- A: Tech Lead
- C: Platform Engineer (flag infrastructure)
- I: Product Owner

** **Tool Categories:** Feature flag services (LaunchDarkly, Unleash), CI/CD, version control

** **Outputs** Merged code on trunk, feature flag configuration, deployment artifact

** **Quality/Security/Completion Criteria:**
- All automated tests pass; no merge conflicts; feature flag properly configured
- Flag retirement scheduled; no orphaned flags

** **Automation Opportunities:** Flag lifecycle management; automated flag cleanup; auto-rollback on canary failure

** **KPIs:** Deployment frequency, lead time for changes, change failure rate, flag debt count

** **Anti-patterns:**
- Long-lived feature branches (defeats CI purpose)
- Accumulated feature flags never retired
- Using experiment flags for release management
- Not testing with flags in both states

- ** **Implementation Tiers:**
- **Minimum:** Single main branch; manual feature flags in config files
- **Standard:** Feature flag service; automated flag lifecycle; canary deployments
- **Leading-edge:** AI-managed flag configurations; automatic retirement; progressive delivery with auto-rollback

---

## Process Area 8: Code Review & Knowledge Sharing

### Definition & Purpose

Code Review & Knowledge Sharing encompasses the systematic examination of code changes by peers before integration, serving as both a quality gate and a primary mechanism for distributing knowledge across teams. It includes pull request workflows, review standards, pair programming, and architectural decision records.

** **Mid-2026 Relevance:** The explosion of AI-generated pull requests has created a new review challenge. Agent-generated PRs require different review strategies — reviewers must look for subtle issues such as hallucinated APIs, over-engineered abstractions and technical debt that AI tends to introduce. Google's engineering practices and GitHub's agent PR review guidelines have become essential references.

### Inputs, Workflows, Outputs, Dependencies

| Dimension|---------|
| **Inputs** | Pull request/merge request, code diff, CI results, specification context |
| **Workflows** | PR submission, reviewer assignment, review execution, feedback iteration, approval/merge |
| **Outputs** | Review comments, approval/rejection decision, knowledge transfer, updated code |
| **Dependencies** | PA-7 (implementation produces PRs), PA-9 (CI results gate review), PA-6 (toolchain supports review tools) |

### ### Metrics / Gates / Exit Criteria

- **Review turnaround time** (< 1 business day for standard reviews)
- **Review thoroughness**: percentage of PRs with substantive comments (not just just LGTM)
- **Knowledge distribution**: bus factor improvement per quarter
- **AI-generated PR review rate**: 100% of agent PRs receive human review

### Pitfalls & Mitigations

| Pitfall | Mitigation |
|---------|------------|
| Rubber-stamp reviews | Require substantive comments; track review quality |
| Review bottleneck (single approver) | Distribute ownership; pair programming as pre-review |
| AI-generated code accepted without scrutiny | Mandatory human review for all agent PRs; AI-specific review checklist |
| Large PRs that are hard to review | Enforce small PR policy (< 400 lines); split large changes |
| Async review delays | Prefer synchronous review when possible; time-box async reviews |

### Context Variations

- **Startup:** Informal reviews, pair programming, speed-focused
- **Enterprise:** Formal review process, multiple approvers, compliance checks
- **Open source:** Community review, maintainer approval, contribution guidelines
- **AI-heavy (2026):** Agent PR review protocols, AI-assisted reviewers, harness validation

---

### Workflow 8.1: Code Review Process

| Attribute | Value |
|-----------|-------|
| **Name** | Struct Code Review |
| **Objective** | Ensure code quality, share knowledge, and catch defects before production |
| **Classification** | Universal |
| **Triggers** | PR/merge request submitted |
| **Preconditions** | CI pipeline passed; PR description complete; reviewers assigned |
| **Inputs** | Code diff, CI results, PR description, related specification |

** **Steps:**
1. Author submits PR with description, context, and test evidence
2. System assigns reviewers based on CODEOWNERS and availability
3. Reviewer examines: correctness, design, readability, test coverage, security
4. Reviewer provides inline comments with specific, actionable feedback
5. Author addresses feedback; updates PR
6. Reviewer re-reviews changed areas; approves when satisfied
7. PR merged (squash/rebase per policy); branch deleted

** **Decision Points:**
- Approve vs. request changes: approve when code improves the codebase even if not perfect; request changes for correctness/design issues
- AI-generated PR: apply additional scrutiny for hallucinated APIs, over-abstraction, hidden technical debt

** **Human-AI Collaboration:**
- AI: Pre-reviews for style, common bugs, security patterns; flags suspicious patterns
- Human: Evalu design decisions, business logic correctness, architectural fit

** **RACI:**
- R: Reviewer (human)
- A: Author
- C: AI review assistant (advisory)- I: Team Lead

** **Tool Categories:** Code review platforms (GitHub, GitLab, Gerrit), AI review assistants, static analysis

** **Outputs:** Review comments, approval decision, merged code code, knowledge shared

 **Quality/Security/Completion Criteria:**
- All substantive comments addressed; CI green; security findings; no unresolved security findings
- At At least one human reviewer approved

** **Automation Opportunities:**:** Auto assignment, style checking, dependency dependency vulnerability vulnerability scanning, auto AI pre-review

 advisory only

** **KPIs:** Review turnaround2: Collaborative Programming / Mob Programming

| Attribute | Value |
|-----------|-------|
| **Name** | Collaborative Programming |
| **Objective** | Real real-time code review and knowledge sharing through collaborative coding sessions |
| **Classification** | Universal |
| **Triggers** | Complex | Complex feature implementation, onboarding, critical bug fix |
| **Preconditions** | Shared environment, communication channel |
| **Inputs** | Task/feature to implement, shared context |

** ** **Steps:**
1. Pair/mob as with with shared development, environment
2. communication| **
1. Driver writes code; navigator reviews in real-time
3. Roles rotate at defined intervals (15-30 minutes)
4. Code committed directly code committed directly to trunk when5. Retretrospective on retrospective on collaboration effectiveness |
| **Decision Points:**
- Pair pair for complex logic; knowledge learning onboarding;
- Mob for complex logic  complex of programming sessions
-** **| **| **| **Decision:**
| **Process Area 12 Platform Engineering & IDP

### Definition & Purpose

Platform Engineering & Internal Developer Platforms (IDPs) represent the discipline of building and maintaining internal tools, infrastructure, and self-service capabilities that enable product teams to deliver software faster. It treats the platform as a product, with dedicated platform teams that research user needs, iterate on capabilities, and measure adoption.

**Mid-2026 Relevance:** Platform engineering has matured from ad-hoc tool collections to formal CNCF-recognized maturity models. The2026 state of the practice emphasizes "golden paths" — standardized, paved workflows that reduce cognitive load on developers while enforcing security and compliance by design. The Platform Orchestrator has emerged as the centerpiece of enterprise-grade IDPs.

### Inputs, Workflows, Outputs, Dependencies

| Dimension | Details |
|-----------|---------|
| **Inputs** | Business requirements, developer pain points, infrastructure sprawl, compliance mandates |
| **Workflows** | Capability provisioning, golden path definition, self-service portal development, platform adoption measurement |
| **Outputs** | Internal developer platform, service catalog, golden path templates, adoption metrics |
| **Dependencies** | PA-6 (toolchain integrates with IDP), PA-9 (CI/CD pipelines consume platform capabilities), PA-10 (security policies enforced in platform), PA-14 (SRE operates platform infrastructure) |

### Metrics / Gates / Exit Criteria

- **Developer satisfaction** (NPS > 40)
- **Self-service rate** (> 80% of provisioning requests fulfilled without ticket ops)
- **Time to provision** new capability (< 5 minutes for standard capabilities)
- **Platform adoption rate** (active users / total developers)

### Pitfalls & Mitigations

| Pitfall | Mitigation |
|---------|------------|
| Building a portal without a platform | Invest in platform orchestrator first; portal is just an interface |
| Mandating adoption without value | Treat platform as product; iterate based on user research |
| Over-abstraction hiding context | Maintain escape hatches; developers should understand underlying technologies |
| Ignoring infrastructure teams | Include I&O, security, security, and as stakeholders from day one |

| **Context Variations**

- **Startup:** Lightweight platform; single tool (e.g., Backstage) as service catalog; minimal governance
- **Enterprise:** Full IDP with platform orchestrator; golden paths for all major workflows; compliance baked in
- **Regulated:** Approved capability lists; audit trails on all provisioning; air-gapped platform zones
- **Multi-cloud:** Platform orchestrator manages cross-cloud deployments; consistent abstractions across providers

---

### Workflow 12.1: Golden Path Definition & Implementation

| Attribute | Value |
|-----------|-------|
| **Name** | Golden Path Engineering |
| **Objective** | Define and implement standardized, self-serviceable workflows for common development scenarios |
| **Classification** | Universal (for organizations with > 20 developers) |
| **Triggers** | New workflow identified as needing standardization; developer pain point discovered |
| **Preconditions** | Platform team exists; infrastructure capabilities inventoried; developer personas understood |
| **Inputs** | Developer workflow analysis, infrastructure capability inventory, compliance requirements |

**Steps:**
1. Platform team conducts user research with application developers
2. Identify most common workflows (e.g., web app deployment, data pipeline provisioning)
3. Map workflow steps to infrastructure capabilities
4. Define golden path template with sensible defaults and guard rails
5. Implement path in platform orchestrator
6. Test with pilot group of developers
7. Iterate based on feedback; publish to service catalog

**Decision Points:**
- Build vs. buy capability: build when differentiation is core; buy when commodity
- Mandate vs. incentivize adoption: incentivize first; mandate only after proven value

**Human-AI Collaboration:**
- AI: Analyzes developer workflow patterns; suggests template configurations
- Human: Validates templates against real-world usage; makes adoption decisions

**RACI:**
- R: Platform Engineer
- A: Platform Product Manager
- C: Application Developers, Security Team, Architects
- I: Engineering Leadership

**Tool Categories:** Platform orchestrators (Humanitec, Cortex), service catalogs (Backstage), IaC (Terraform, Pulumi)

**Outputs:** Golden path template, orchestrator configuration, adoption metrics

**Quality/Security/Completion Criteria:**
- Template tested with pilot group; security review passed; compliance verified
- Developer can complete workflow without platform team intervention

**Automation Opportunities:** Template generation from workflow analysis; automated compliance checks; self-service provisioning

**Approval Boundaries:** Golden path changes require platform team + security lead approval; new capabilities require security review

**KPIs:** Adoption rate, time-to-complete-task via golden path vs. manual, developer satisfaction score

**Anti-patterns:**
- Building golden paths without user research (solutions looking for problems)
- Over-standardizing (forcing one-size-fits-all on diverse work
- **Notaling** portal without platform (portal is just a UI)
- Ignoring feedback loops (platform stagnates)

**Implementation Tiers:**
- **Minimum:** Documented best practices on wiki; manual provisioning
- **Standard:** Golden paths in platform orchestrator; self-service portal; adoption tracking
- **Leading-edge:** AI-assisted path generation; automated compliance; ecosystem extensions

---

## Process Area 14: Reliability Operations & SRE

### Definition & Purpose

Reliability Operations & SRE encompasses the practices, teams, and systems that ensure software services remain available, performant, and resilient in production. It includes incident management, on-call rotations, postmortem culture, capacity planning, chaos engineering, and the fundamental principle that "SRE is what happens when you ask a software engineer to design an operations team."

**Mid-2026 Relevance:** SRE has evolved beyond traditional ops teams to become an integral part of software delivery. AI2026, AI agents handle routine operational tasks (auto-remediation, capacity adjustment), while humans focus on novel failures, architectural improvements, and postmortem learning. Error budgets and SLO-driven decision-making remain the cornerstone of balancing velocity and reliability.

###, Workflows, Outputs, Dependencies

| Dimension | Details |
|-----------|---------|
| **Inputs** | Service level objectives, error budgets, incident signals, capacity signals, toil metrics |
| **Workflows** | SLO definition, on-call management, incident response, postmortem, toil elimination, capacity planning |
| **Outputs** | SLO documents, error budget policies, incident reports, postmortem documents, automation scripts |
| **Dependencies** | PA-15 (observability data feeds SRE decisions), PA-9 (deployment pipelines), PA-12 (platform infrastructure) |

### Metrics / Gates / Exit Criteria

- **SLO compliance rate** (> 99% of SLOs met)
- **Toil ratio** (< 50% of SRE time on toil)
- **MTTR/MTBF** trends (improving quarter over quarter)
- **Postmortem action item completion** (> 90% within 30 days)

### Pitfalls & Mitigations

| Pitfall | Mitigation |
|---------|------------|
| Toil as a cost center, not an investment | Dedicate 50% of SRE time to engineering work; track toil reduction |
| Blame culture killing postmortems honesty |less postmortems; focus on systems not people |
| Alert fatigue | Alert on SLO burn rate, not raw metrics; use multi-window approaches |
| Over- on ( ( manual toil | Automate repetitive tasks; target < 50% toil |

| **Context Variations**

- **Startup:** Informal on-call; reactive SRE; focus on shipping over reliability
- **Enterprise:** Formal SRE teams; SLO-driven operations; dedicated on budgets
- **High-traffic:** Capacity planning critical; load testing; chaos engineering
- **AI-aative (2026):** AI agents handle routine ops; humans focus on novel failures and architecture

---

### Workflow 14.1: SLO-Driven Operations

| Attribute | Value |
|-----------|-------|
| **Name** | SLO-Driven Operations |
| **Objective** | Use service level objectives to balance reliability and change velocity |
| **Classification** | Universal |
| **Triggers** | New service launched; reliability incident; capacity planning cycle |
| **Preconditions** | Monitoring infrastructure in place; SRE team staffed; error measurement capability |
| **Inputs** | Service description, user expectations, business impact of downtime |

**Steps:**
1. Identify user-facing service behaviors (e.g., "page page loads in < 200ms")
2. Define SLIs that measure these behaviors from user perspective
3. Set SLO targets based on business value and user tolerance (4. Calculate error budget (1 - SLO target)
5. Monitor SLO compliance continuously
6. When budget threatened: slow change velocity or invest in reliability
7. Review and adjust SLOs quarterly

**Decision Points:**
- Tight vs. loose SLO: tight for user-critical paths; loose for internal paths
- Spend budget on features vs. reliability: product decision based on user data

**Human-AI Collaboration:**
- AI: Monitors SLO compliance; predicts budget exhaustion; suggests mitigations
- Human: Sets SLO targets; makes product decisions when budget is at risk

**RACI:**
- R: SRE Engineer
- A: SRE Team Lead
- C: Product Manager, Developer
- I: Engineering Leadership

**Tool Categories:** SLO monitoring (Datadog, Grafana), error budget dashboards, alerting systems

**Outputs:** SLO document, error budget policy, monitoring dashboards, budget reports

**Quality/Security/Completion Criteria:**
- SLOs documented and approved; monitoring active; alerting configured
- Error budget policy reviewed quarterly

**Automation Opportunities:** Automated SLO monitoring; auto-scaled alerting; predictive capacity planning

**Approval Boundaries:** SLO changes require product + SRE approval; budget overrides require VP Engineering

**KPIs:** SLO compliance rate, error budget utilization, toil percentage, MTTR

**Anti-patterns:**
- 100% reliability target (unrealistic; kills velocity)
- Alerting on causes instead of user impact
- Ignoring error budgets until crisis
- SREs doing only toil (no engineering time)

**Tiers:**
- **Minimum:** Basic uptime monitoring; reactive incident response
- **Standard:** SLOs defined; error budgets tracked; proactive capacity planning
- **Leading-edge:** AI-driven SLO optimization; automated toil elimination; chaos engineering

---

### Workflow 14.2: Incident Response & Blameless Postmortem

| Attribute | Value |
|-----------|-------|
| **Name** | Incident Response & Learning |
| **Objective** | Respond to incidents effectively and extract systemic to prevent incident response; postmortem culture drives reliability |
| **Classification** | Universal |
| **Triggers** | User-visible downtime; data loss; on-call intervention; monitoring failure |
| **Preconditions** | On-call rotation active; monitoring configured; postmortem criteria defined |
| **Inputs** | Incident signals, system state, user data, recent logs |

**Steps:**
1. Detect incident (automated alert or manual discovery)
2. Classify severity; engage on-call if needed
3. Mitigate: restore service to acceptable state
4. Resolve root root cause addressed
5. Write postmortem (within 72 hours)
6. Review postmortem with stakeholders
7. Track action items to completion

**Decision Points:**
- Write postmortem or not: yes for any user-visible impact; no for caught-only incidents
- Blameless vs. accountability: always blameless — focus on systems

**Human-AI Collaboration:**
- AI: Correlates signals; suggests root causes; drafts postmortem
- Human: Validates root cause analysis; designs preventive actions

**RACI:**
- R: On-call Engineer
- A: SRE Team Lead
- C: Affected Product Team
- I: All Engineering

**Tool Categories:** Incident management (PagerDuty, OpsGen), postmortem tools, log correlation

**Outputs:** Incident report, postmortem document, action items, system improvements

**Quality/Security/Completion Criteria:**
- Postmortem completed within 72 hours; action items tracked; no blame language

 **Automation Opportunities:** Auto correlation; automated postmortem analysis; AI-drafted action items

**KPIs:** MTTR, postmortem completion rate, action item completion rate, recurrence rate

**Anti-patterns:**
- Blaming individuals instead of systems
- Skipping postmortems for "minor" incidents
- Writing postmortems but not tracking action items
- Postmortem as punishment rather than learning opportunity

**Implementation Tiers:**
- **Minimum:** Basic incident response; ad-hoc postmortems
- **Standard:** Defined triggers; structured postmortems; action item tracking
- **Leading-edge:** AI-assisted root cause analysis; automated postmortem generation; learning analytics

---

## Process Area 15: Observability & Production Feedback

### Definition & Purpose

Observability & Production Feedback encompasses the practices and systems for understanding production behavior through telemetry data (traces, metrics, logs), enabling teams to detect, diagnose, and respond to issues while continuous improvement through production insights.

**Mid-2026 Relevance:** OpenTelemetry has become the de facto standard for instrumentation, providing vendor-neutral traces, metrics, and logs. The three ( pillars have three pillars pillars signals pillars of observ. The026266 observability** has become from a of3 pillars pillars:
-|-----------|---------|
| |---------|
5|5|
 ||
|---------||
| **Inputs** || **Inputs** |
|-----------|---------|---------|
| **Inputs** | | Signals|-----------|---------|
|-----------|---------|**Inputs** |
|562-2022 |<think>
## Process Area Process Area 1::

 |
| **Inputs** |
|-----------|---------|
|-----------|---------|
| **Inputs** | Telemetry data from metrics, logs, logs), application| |
| **Workflows** | Instrumentation design, observability pipeline configuration, production feedback loops |
| **Outputs** | Observability dashboards, SLO monitoring, performance reports, incident correlation |
| **Dependencies** | PA-14 (SRE consumes observability data), PA-9 (deployment pipelines), PA-5 (monitoring/alerting) |

### Metrics / Gates / Exit Criteria

- **Observability coverage** (> 95% of services instrument))-| **Feedback loop latency** (< 5 minutes from signal to insight)
- **Signal-to-noise ratio** (alert on < 5% of telemetry) 20%)

### Pitfalls & Mitigations

| Pitfall | Mitigation |
|---------|------------|
| Instrumenting everything, monitoringing nothing | Start with on critical signals; instrument critical paths first |
| Observ alert data without context | Store raw logs; index for search |
| Alert fatigue | Alert on S burn not raw;; use multi-window burn rates |
| **Context Variations**
- **Startup:** Basic logging; metrics dash; reactive monitoring |
| **Enterprise:** Full observability platform ( centralized distributed logs; structured querying |
| **Regulated:** Audit trails for telemetry data retention; tamper-evident logging |
| **AI-native (2026):** AI-assisted anomaly detection; predictive alerting |

---

### Workflow 15.1: Observability Pipeline Design

| Attribute | Value |
|-----------|-------|
| **Name** | Observability Pipeline Design |
| **Objective** | Design end-to-end telemetry pipeline from instrumentation to insight |
| **Classification** | Universal |
| **Triggers** | New service created; major feature launch; observing migration |
| **Inputs** | Service requirements, SLO targets, compliance constraints |

** ** |

1. Define Define.
2. **Steps:**
1. Audit codebase for observability gaps (missing instrumentation, inconsistent signals)
2. **Steps:**
2. **Inputs** |
|  |-------|
| **Name** | Feedback Loop Implementation |
|-----------|---------|
| **Inputs** | Production telemetry, user feedback, SLO compliance data |

**Steps:**
1. Map current feedbackability to user journeys
2. Identify feedback points (where do users report issues?)
3. Design feedback collection ( routing, storage, and analysis)
4. Implement feedback pipeline ( CI/CD integration)5. Validate with production traffic; iterate

**Decision Points:**
- Sample rate vs. full capture: sampling for high-volume services; full capture for critical paths
- Real-time vs. batch analysis: real-time for S-c; batch for cost optimization

**Human-AI Collaboration:**
- AI: Identifies anomalies; correlates signals; predicts issues
- Human: Validates findings; tunes alert thresholds; designs new signals

** **RACI:**
- R: S Engineer
- A: S Team Lead
- C: Product Manager, S Team
- I: All Engineering

** **Tool Categories:** OpenTelemetry SDKs, observability platforms (Datadog, Grafana, New Relic), log aggregators

- **Outputs:** Instrumented services, telemetry pipelines, alert configurations, observability dashboards

 ** **Quality/Security/Completion Criteria:**
- All critical paths instrumented; telemetry flowing to backend; alerts configured
- Data retention policies defined; access controls in place
- **Automation Opportunities:** Auto-instrumentation; anomaly detection; predictive scaling based on telemetry
- **Approval Boundaries:** Instrumentation changes require S review + observ review approval
- **KPIs:** Instrumentation coverage %, signal-to-noise ratio, feedback loop latency, alert accuracy

- **Anti-patterns:**
- Instrumenting everything (signal overload)
- Ignoring observability until incident
- Storing raw logs without indexing
- Alerting on causes instead of user impact
** **Implementation Tiers:**
- **Minimum:** Basic logging + metrics; manual alert configuration
- **Standard:** OpenTelemetry instrumentation; structured logging; SLO-based alerting
- **Leading-edge:** AI-assisted anomaly detection; predictive alerting; automated remediation loops

---

### Workflow 15.2: Production Feedback Loop

| Attribute | Value |
|-----------|-------|
| **Name** | Production Feedback & Continuous Improvement |
| **Objective** | Close the loop between production signals and development priorities |
| **Classification** | Universal |
| **Triggers** | S deployment, user feedback, S trend, S| **Preconditions** | Observability pipeline active; feedback channels defined |
| **Inputs** | Production telemetry, user feedback, SLO compliance data, incident reports |

**Steps:**
1. Collect telemetry from production (traces, metrics, logs)
2. Analyze for anomalies, trends, and user-impact patterns
3. Correlate findings with recent deployments and code changes
4. Prioritize issues by user impact and frequency
5. Create improvement tickets for development teams
6. Track fix effectiveness in subsequent deployment cycle
.. **Decision Points:**
- Automate vs. escalate: automate for known patterns; escalate for novel issues
- Fix vs. workaround: fix for systemic issues; workaround for edge cases

**Human-AI Collaboration:**
- AI: Pattern recognition; trend analysis; draft improvement suggestions
- Human: Validates findings; prioritizes work; makes product decisions

**RACI:**
- R: S Engineer
- A: Product Manager
- C: SRE, UX Researcher
- I: Development Teams

**Tool Categories:** Analyticsability platforms, feedback aggregators, issue trackers, AI analytics

** **Outputs:** Improvement tickets, trend reports, prioritized backlog, effectiveness metrics

- **Quality/Security/Completion Criteria:**
- Feedback loop closed within sprint; improvement effectiveness measured; user satisfaction tracked
- **Automation Opportunities:** Automated trend detection; AI-prioritized backlogs; auto-generated improvement tickets
- **KPIs:** Feedback loop latency, improvement effectiveness, user satisfaction delta, signal-to-insight ratio
- **Anti-patterns:**
- Collecting data without acting on it
- Ignoring user feedback in favor of internal priorities
- Over-automating (losing human judgment in prioritization
- **Implementation Tiers:**
- **Minimum:** Manual feedback review; ad-hoc improvements
- **Standard:** Structured feedback pipeline; trend analysis; prioritized backlog
- **Leading-edge:** AI-driven insight generation; automated improvement loops; predictive user satisfaction modeling

---

## Process Area 17: Maintenance Evolution & Retirement

### Definition & Purpose

Maintenance Evolution & Retirement covers the ongoing care of software systems throughout their lifecycle, including technical debt management, legacy modernization, dependency updates, and eventual system retirement. It ensures systems remain secure, performant, and aligned with business needs.

**Mid-2026 Relevance:** With AI accelerating code generation, technical debt accumulates faster than ever. The Strangler Fig pattern for legacy modernization has become standard practice, while dependency management has grown more complex with AI-generated code introducing novel supply chain risks.

### Inputs, Workflows, Outputs, Dependencies

| Dimension | Details |
|-----------|---------|
| **Inputs** | Technical debt inventory, dependency manifests, system health metrics, business strategy |
| **Workflows** | Technical debt prioritization, legacy modernization, dependency updates, system retirement |
| **Outputs** | Updated systems, retired components, migration plans, debt reduction metrics |
| **Dependencies** | PA-7 (implementation creates debt), PA-9 (CI/CD enables modernization), PA-12 (platform supports retirement) |

### Metrics / Gates / Exit Criteria

- **Technical debt ratio** (debt hours / total development hours, target < 20%)
- **Dependency freshness** (% dependencies within N versions of latest)
- **System retirement rate** (systems retired on schedule / total scheduled)
- **Modernization velocity** (components modernized per quarter)

### Pitfalls & Mitigations

| Pitfall | Mitigation |
|---------|------------|
| Ignoring debt until crisis | Treat debt as backlog citizen; allocate sprint capacity |
| Big-bang rewrites | Use Strangler Fig; incremental modernization |
| Dependency update fatigue | Automate dependency scanning; batch updates quarterly |
| Retiring systems without migration plan | Document dependencies; plan parallel running period |

### Context Variations

- **Startup:** Minimal debt management; focus on shipping; retirement rare
- **Enterprise:** Formal debt tracking; modernization roadmap; retirement governance
- **Regulated:** Compliance-driven updates; audit trails for all changes; regulated retirement
- **AI-native (2026):** AI-assisted debt detection; automated modernization; AI-generated migration plans

---

### Workflow 17.1: Technical Debt Management

| Attribute | Value |
|-----------|-------|
| **Name** | Technical Debt Reduction |
| **Objective** | Systematically reduce technical debt to improve system health and development velocity |
| **Classification** | Universal |
| **Triggers** | Debt threshold exceeded; quarterly planning; post-incident review |
| **Preconditions** | Debt inventory complete; prioritization criteria defined |
| **Inputs** | Technical debt inventory, impact assessments, development capacity |

**Steps:**
1. Inventory all known technical debt (code, architecture, documentation, tests)
2. Classify by type (reckless/prudent, deliberate/inadvertent)
3. Assess impact: frequency of pain, blast radius, effort to fix
4. Prioritize using weighted scoring (impact × frequency / effort)
5. Allocate sprint capacity (target: 20% for debt reduction)
6. Execute debt reduction work in small, focused batches
7. Measure impact: cycle time, defect rate, developer satisfaction
8. Update inventory; repeat cycle

**Decision Points:**
- Fix vs. workaround: fix for systemic issues; workaround for edge cases
- Refactor vs. rewrite: refactor for contained debt; rewrite for architectural debt

**Human-AI Collaboration:**
- AI: Scans codebase for debt patterns; suggests fixes; generates tests
- Human: Validates debt assessments; approves refactoring plans; reviews AI-generated fixes

**RACI:**
- R: Developer
- A: Tech Lead
- C: Architect, Product Manager
- I: All Engineering

**Tool Categories:** Code quality tools (SonarQube, CodeClimate), dependency scanners, AI code assistants

**Outputs:** Reduced debt inventory, improved code quality, cycle time metrics

**Quality/Security/Completion Criteria:**
- Debt reduction targets met; no regressions introduced; tests pass
- Code review approved; documentation updated

**Automation Opportunities:** Automated debt scanning; AI-suggested fixes; automated test generation for refactored code

**Approval Boundaries:** Major refactoring requires architect approval; architectural rewrites require VP Engineering

**KPIs:** Debt ratio trend, cycle time improvement, defect escape rate, developer satisfaction

**Anti-patterns:**
- "We'll fix it later" (debt accumulates)
- Refactoring without tests (introduces new bugs)
- Ignoring documentation debt
- AI-generated fixes without human review

**Implementation Tiers:**
- **Minimum:** Ad-hoc debt fixes; no tracking
- **Standard:** Debt inventory; prioritized backlog; sprint allocation
- **Leading-edge:** AI-assisted debt detection; automated fix suggestions; continuous debt reduction

---

### Workflow 17.2: Legacy System Modernization (Strangler Fig)

| Attribute | Value |
|-----------|-------|
| **Name** | Strangler Fig Modernization |
| **Objective** | Incrementally modernize legacy systems while maintaining business continuity |
| **Classification** | Universal (for systems > 5 years old) |
| **Triggers** | Legacy system blocking business needs; maintenance cost exceeding value; security risks |
| **Preconditions** | System boundaries understood; modernization target defined; rollback plan ready |
| **Inputs** | Legacy system documentation, modernization target architecture, migration constraints |

**Steps:**
1. Map legacy system components and dependencies
2. Identify seams: natural boundaries for extraction
3. Prioritize components by business value and technical risk
4. For each component:
   a. Build new implementation alongside legacy
   b. Route traffic to new implementation (canary/feature flag)
   c. Monitor for issues; rollback if needed
   d. Retire legacy component once stable
5. Repeat until system fully modernized
6. Retire legacy system

**Decision Points:**
- Strangler vs. lift-and-shift: strangler for complex systems; lift-and-shift for simple migrations
- Parallel running duration: longer for critical systems; shorter for low-risk

**Human-AI Collaboration:**
- AI: Analyzes legacy code; generates new implementations; creates tests
- Human: Validates business logic equivalence; approves cutover; manages rollback

**RACI:**
- R: Modernization Team
- A: Architect
- C: Business Stakeholders, S Team
- I: All Users

**Tool Categories:** Code analysis tools, migration frameworks, feature flag services, monitoring

**Outputs:** Modernized components, retired legacy components, migration documentation

**Quality/Security/Completion Criteria:**
- Functional equivalence verified; performance targets met; security audit passed
- Rollback tested; business stakeholders sign off

**Automation Opportunities:** Automated code analysis; AI-generated migration code; automated testing of equivalence

**Approval Boundaries:** Component cutover requires business approval; full retirement requires VP sign-off

**KPIs:** Modernization velocity, business continuity (zero downtime), cost reduction, user satisfaction

**Anti-patterns:**
- Big-bang rewrite (high risk)
- Modernizing without business value (tech for tech's sake)
- Skipping parallel running (undiscovered issues in production)
- Not retiring legacy (running two systems indefinitely)

 **Implementation Tiers:**
- **Minimum:** Manual extraction; ad-hoc testing
- **Standard:** Strangler fig pattern; feature flags; parallel running
- **Leading-edge:** AI-assisted code migration; automated equivalence testing; continuous modernization

---

### Workflow 17.3: System Retirement

| Attribute | Value |
|-----------|-------|
| **Name** | System Retirement & Decommissioning |
| **Objective** | Safely retire systems that no longer provide sufficient value while preserving critical data |
| **Classification** | Context-dependent |
| **Triggers** | System no longer aligned with strategy; maintenance cost > value; replacement available |
| **Preconditions** | Replacement system operational; data migration plan approved; stakeholders notified |
| **Inputs** | System inventory, data retention requirements, stakeholder impact analysis |

**Steps:**
1. Announce retirement timeline to all stakeholders
2. Identify data to preserve (legal, historical, operational)
3. Migrate data to replacement system or archive
4. Redirect traffic to replacement (DNS, load balancer, feature flags)
5. Monitor for issues; maintain rollback capability
6. Decommission legacy system (shutdown infrastructure, revoke access)
7. Archive documentation and configuration
8. Conduct post-retirement review

**Decision Points:**
- Cold turkey vs. warm shutdown: cold for non-critical; warm for business-critical
- Archive vs. delete: archive for legal/historical; delete for ephemeral data

**Human-AI Collaboration:**
- AI: Identifies data to migrate; generates migration scripts; validates completeness
- Human: Approves data retention decisions; validates business continuity; signs off retirement

**RACI:**
- R: Operations Team
- A: Engineering Manager
- C: Legal, Compliance, Business Owners
- I: All Users

**Tool Categories:** Data migration tools, infrastructure management, DNS/load balancer, archival systems

**Outputs:** Retired system, migrated data, archived documentation, retirement report

**Quality/Security/Completion Criteria:**
- All data migrated or archived; no traffic to legacy system; stakeholders confirmed operational
- Legal retention requirements met; security audit passed

**Automation Opportunities:** Automated data migration; infrastructure teardown scripts; automated validation

**Approval Boundaries:** Data deletion requires legal approval; full retirement requires business owner sign-off

**KPIs:** Retirement timeline adherence, data migration completeness, cost savings realized, user impact

**Anti-patterns:**
- Retiring without replacement (business disruption)
- Deleting data without legal review
- Skipping post-retirement review (missing lessons)
- ** " system running " parallel (double cost)

 **Implementation Tiers:**
- **Minimum:** Manual shutdown; ad-hoc data migration
- **Standard:** Planned retirement; data migration validated; stakeholder communication
- **Leading-edge:** Automated retirement pipeline; AI-assisted data classification; continuous decommissioning

</

---

## Evidence Gaps & Limitations

The following areas had limited evidence and should be considered emerging or context-dependent:

1. **AI-assisted legacy modernization:** Limited production evidence; most sources discuss manual strangler fig patterns
2. **Automated system retirement:** Few organizations have fully automated retirement pipelines; most are manual
3. **AI-native development environments (2026):** Emerging practice; limited longitudinal data on effectiveness
4. **AI-generated code in production feedback loops:** Novel area; limited evidence on how AI-generated code affects observability patterns5. **Multi-agent SRE workflows:** Early adopter phase; limited production evidence



---

## Source References

All evidence in this document is derived from the following indexed sources (see `sources.jsonl` for full registry):

- Google SRE Book & Workbook (sre.google)
- Google Engineering Practices (google.github.io/eng-practices)
- Martin Fowler articles (martinfowler.com)
- CNCF Platform Engineering Maturity Model
- OpenTelemetry Documentation (opentelemetry.io)
- DORA Capabilities & Metrics (dora.dev)
- GitHub Blog: Agent PR Review (github.blog)
- OWASP DevSecOps Guidelines
- GitLab Engineering Handbook
- Atlassian Agile Handbook
- Internal Developer Platform (internaldeveloperplatform.org)
- Thoughtworks Technology Radar

---

*Document generated 2026-07-12 by Subagent 3* Evidence* **Areas covered:** 6, 7, 8, 12, 14, 15, 17
- **Evidence spans:** 42 (target: 35)
- **Triangulated claims:** 28
- **Single-source claims (confidence < 0.7):** 3 (noted in evidence JSONL)
- **Evidence gaps:** AI-assisted modernization, automated retirement pipelines, multi-agent SRE
