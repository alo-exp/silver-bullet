# Process Area 18: AI-Assisted / Agentic Software Engineering

## Definition

AI-Assisted / Agentic Software Engineering encompasses the systematic integration of large language models (LLMs), AI coding assistants, and autonomous agents into every phase of the software development lifecycle. It covers both **human-in-the-loop** patterns (AI as copilot) and **human-on-the-loop** patterns (AI as autonomous agent with human oversight at the harness level).

## Purpose

To amplify engineering productivity, quality, and velocity by delegating appropriate cognitive and mechanical tasks to AI systems while maintaining human accountability for architectural decisions, security, and business outcomes.

## Mid-2026 Relevance

- **90% of technology professionals** now use AI at work; over 80% believe it has increased productivity (DORA 2025 State of AI-assisted Software Development).
- AI acts as an **amplifier**: it magnifies strengths of high-performing organizations and dysfunctions of struggling ones (DORA Balancing AI Tensions, March 2026).
- Higher AI adoption correlates with **both increased throughput and increased instability** — the central tension of AI-assisted delivery (DORA 2025).
- Spotify reports "coding is no longer the constraint" — the bottleneck has shifted to specification, review, and platform quality (Spotify, Code with Claude 2026).
- Thoughtworks identifies **harness engineering** — the practice of building and maintaining agent harnesses — as an emerging discipline (Fowler/Morris, March 2026).

## Inputs

| Input | Source |
|-------|--------|
| Feature requirements / user stories | Product management, Area 2 |
| Architecture decisions | Architecture governance, Area 3 |
| Codebase + conventions | Version control, Area 5 |
| Test suites + coverage data | Testing, Area 8 |
| Security policies | Security engineering, Area 10 |
| Platform abstractions | Platform engineering, Area 14 |
| Incident data / postmortems | Operations, Area 16 |

## Workflows

### WF-18.1: AI-Assisted Code Generation

- **Objective:** Accelerate implementation by generating code via LLM-powered assistants
- **Classification:** Universal (operational adoption across industry)
- **Triggers:** Developer begins implementation task; PR creation; feature branch work
- **Preconditions:** AI coding assistant configured; project conventions documented (CLAUDE.md / .cursorrules / copilot-instructions.md)
- **Inputs:** Natural language description, codebase context, test specifications
- **Steps:**
  1. Developer provides task description or lets agent interview them
  2. AI generates code using project context (conventions, patterns, dependencies)
  3. Developer reviews generated code against tests and standards
  4. Iterative refinement via conversation or direct editing
  5. Tests run; AI fixes failures in subsequent iterations
- **Decision points:** Accept/reject suggestion; escalate to human for architectural decisions
- **Human-AI collaboration:** Human-in-the-loop for routine tasks; human-on-the-loop for background agents
- **Roles/RACI:** Developer (R/A), AI agent (C), Tech lead (I for complex changes)
- **Tool categories:** IDE-integrated assistants (Copilot, Gemini Code Assist, Claude Code), background agents (Codex, Devin)
- **Outputs:** Source code, tests, documentation updates
- **Quality criteria:** All tests pass; no new security vulnerabilities; code review approved
- **Automation opportunities:** Background agents for migrations, boilerplate, test generation
- **Approval boundaries:** Human approval required for: architectural changes, security-sensitive code, public API changes
- **KPIs:** Task completion time, code acceptance rate, defect density per AI-generated LOC
- **Anti-patterns:** Blind acceptance of suggestions; using AI without understanding generated code; skipping tests for AI-generated code
- **Tiers:**
  - *Minimum:* IDE autocomplete (Copilot) with manual review
  - *Standard:* Agentic coding with test-first prompting, CLAUDE.md conventions
  - *Leading-edge:* Background agents for full feature implementation with automated review pipelines

### WF-18.2: AI-Powered Code Review

- **Objective:** Augment human code review with automated AI analysis for consistency, security, and quality
- **Classification:** Leading-edge (operational at Google, Meta, GitHub; not yet universal)
- **Triggers:** PR/MR opened; code change submitted
- **Preconditions:** AI review agent configured; organizational standards encoded
- **Inputs:** Code diff, project conventions, security policies, test results
- **Steps:**
  1. AI analyzes diff for style, security, performance, correctness
  2. Context-aware review agents enforce organizational standards before human review
  3. AI feedback delivered to author during writing phase (shift-left)
  4. Human reviewer focuses on design, architecture, business logic
  5. AI triages review comments and suggests fixes
- **Decision points:** AI-flagged issues → auto-fix vs. escalate to human; human overrides AI
- **Human-AI collaboration:** AI handles mechanical review; human handles judgment-based review
- **Roles/RACI:** AI agent (R for mechanical review), Human reviewer (A), Author (R for fixes)
- **Tool categories:** PR review bots (CodeRabbit, Copilot PR review, Google's AI review), custom review agents
- **Outputs:** Review comments, suggested fixes, approval/recommendation
- **Quality criteria:** No false-positive rate > threshold; all critical findings addressed
- **Automation opportunities:** Auto-approve PRs meeting all AI + test criteria (with human override)
- **Approval boundaries:** AI cannot approve security-sensitive or architecture-changing PRs
- **KPIs:** Review cycle time, AI false-positive rate, defect escape rate
- **Anti-patterns:** Over-reliance on AI review; rubber-stamping AI approvals; ignoring AI warnings
- **Tiers:**
  - *Minimum:* AI linting/style suggestions in PR comments
  - *Standard:* Context-aware AI review with organizational rules, human final approval
  - *Leading-edge:* AI-first review pipeline with human escalation paths, auto-merge for low-risk changes

### WF-18.3: AI-Assisted Testing

- **Objective:** Generate, augment, and maintain test suites using AI
- **Classification:** Universal for generation; leading-edge for autonomous test maintenance
- **Triggers:** New code written; test coverage below threshold; test failures
- **Preconditions:** Test framework configured; AI has access to codebase and test patterns
- **Inputs:** Source code, existing tests, coverage reports, specifications
- **Steps:**
  1. AI generates unit tests for new/changed code
  2. AI suggests integration test scenarios from specifications
  3. AI identifies edge cases from code analysis
  4. AI updates existing tests when interfaces change
  5. AI generates test data and fixtures
- **Decision points:** Accept/reject generated tests; prioritize coverage gaps
- **Human-AI collaboration:** AI generates; human validates test intent and coverage adequacy
- **Roles/RACI:** AI agent (R for generation), Developer (A), QA lead (C)
- **Tool categories:** Copilot test generation, Claude Code test workflows, CodiumAI, custom test agents
- **Outputs:** Test files, test data, coverage reports
- **Quality criteria:** Generated tests pass; meaningful assertions (not tautological); coverage improvement
- **Automation opportunities:** Auto-generate tests for all new code; auto-update tests on refactor
- **Approval boundaries:** Human validates test quality; AI-generated tests cannot self-approve
- **KPIs:** Test coverage delta, mutation score, AI-generated test defect detection rate
- **Anti-patterns:** Tautological tests (testing what the code does, not what it should do); 100% coverage targets without quality assessment
- **Tiers:**
  - *Minimum:* AI-assisted unit test generation with manual review
  - *Standard:* AI generates tests from specs + code; human validates; CI enforces
  - *Leading-edge:* Autonomous test maintenance, mutation testing validation, AI-driven test strategy

### WF-18.4: Context Engineering for Coding Agents

- **Objective:** Systematically manage the context provided to AI agents to maximize output quality
- **Classification:** Leading-edge (emerging discipline, documented by Thoughtworks and Spotify)
- **Triggers:** Agent performance degrades; new project setup; onboarding new team to AI tools
- **Preconditions:** Understanding of agent context mechanisms; project conventions documented
- **Inputs:** Project structure, coding standards, architectural decisions, dependency graph
- **Steps:**
  1. Define project-level context (CLAUDE.md, .cursorrules, copilot-instructions.md)
  2. Configure path-based rules (load guidance only when relevant files active)
  3. Set up memory/slots for persistent cross-session context
  4. Curate example code and patterns for agent reference
  5. Iterate: observe agent failures → improve context → validate
- **Decision points:** What context to include/exclude; when to clear vs. accumulate context
- **Human-AI collaboration:** Human engineers context; AI consumes and acts
- **Roles/RACI:** Platform/DevEx team (R), Tech leads (A), All developers (C)
- **Tool categories:** CLAUDE.md, Cursor rules, Copilot instructions, MCP servers, memory systems
- **Outputs:** Context configuration files, agent harness specifications
- **Quality criteria:** Agent produces correct output >80% of time on standard tasks; context size within token limits
- **Automation opportunities:** Auto-generate context from codebase analysis; auto-update on convention changes
- **KPIs:** Agent task success rate, context token efficiency, developer satisfaction with agent output
- **Anti-patterns:** Context bloat (too much irrelevant info); stale context; one-size-fits-all context
- **Tiers:**
  - *Minimum:* Single project-level instruction file
  - *Standard:* Modular rules with path-based loading, memory persistence
  - *Leading-edge:* Dynamic context assembly, automated context validation, per-task context profiles

### WF-18.5: Agentic Workflow Orchestration

- **Objective:** Deploy autonomous AI agents for multi-step development tasks with appropriate guardrails
- **Classification:** Leading-edge (operational at Spotify, GitHub, Anthropic customers)
- **Triggers:** Well-defined task suitable for autonomous execution (migrations, refactors, documentation)
- **Preconditions:** Agent harness configured; guardrails defined; human escalation path established
- **Inputs:** Task specification, codebase access, test suite, review pipeline
- **Steps:**
  1. Define task scope and acceptance criteria
  2. Configure agent with context, tools, and constraints
  3. Agent executes autonomously: plan → implement → test → iterate
  4. Automated quality gates (tests, linting, security scan)
  5. Human review of output; merge or reject
- **Decision points:** Agent self-assessment (continue vs. escalate); human gate at merge
- **Human-AI collaboration:** Human-on-the-loop — human defines harness and reviews output, not each step
- **Roles/RACI:** Agent (R), Developer (A for review), Platform team (R for harness), Tech lead (I)
- **Tool categories:** Claude Code (agentic mode), GitHub Copilot Coding Agent, Codex, Devin, custom agents
- **Outputs:** PRs, migration results, documentation updates
- **Quality criteria:** All automated gates pass; human review approval; no regression
- **Automation opportunities:** Background agents for large-scale migrations, dependency updates, documentation sync
- **Approval boundaries:** Human approval always required for merge; agent cannot bypass security gates
- **KPIs:** Agent task completion rate, PR acceptance rate, time-to-completion vs. human baseline
- **Anti-patterns:** Unsupervised agents without guardrails; agents modifying security-critical code without human review; runaway agent loops
- **Tiers:**
  - *Minimum:* Agent generates PR, human reviews every change
  - *Standard:* Agent with automated quality gates, human review at merge
  - *Leading-edge:* Multi-agent orchestration, automated review pipelines, agent-to-agent coordination

### WF-18.6: AI-Assisted Documentation

- **Objective:** Generate and maintain technical documentation using AI
- **Classification:** Universal (widely adopted for generation; emerging for autonomous maintenance)
- **Triggers:** Code merged; API changed; documentation gap identified
- **Preconditions:** Documentation standards defined; AI has access to codebase
- **Inputs:** Source code, API specs, existing docs, style guide
- **Steps:**
  1. AI generates doc updates from code changes
  2. AI cross-references related documentation
  3. SME reviews and approves
  4. AI publishes to documentation system
- **Decision points:** Auto-publish vs. SME review required
- **Human-AI collaboration:** AI generates; SME validates accuracy
- **Roles/RACI:** AI agent (R), Technical writer/SME (A), Developer (C)
- **Tool categories:** GitHub Agentic Workflows, custom doc agents, Copilot doc generation
- **Outputs:** Updated documentation, API references, changelogs
- **Quality criteria:** Accuracy verified by SME; no stale references; consistent style
- **KPIs:** Doc freshness (time since last code change), coverage, SME approval rate
- **Anti-patterns:** Publishing AI docs without SME review; generating docs that describe implementation rather than behavior
- **Tiers:**
  - *Minimum:* AI-assisted doc generation with manual review
  - *Standard:* Automated doc PRs on code merge, SME approval gate
  - *Leading-edge:* Autonomous cross-repo doc maintenance (GitHub Aspire pattern)

### WF-18.7: AI-Augmented Debugging and Incident Response

- **Objective:** Use AI to accelerate root cause analysis and incident resolution
- **Classification:** Emerging (promising results but limited systematic adoption evidence)
- **Triggers:** Build failure; test failure; production incident; error log anomaly
- **Preconditions:** AI has access to logs, traces, codebase, and incident history
- **Inputs:** Error logs, stack traces, metrics, recent changes, postmortem history
- **Steps:**
  1. AI correlates error with recent code changes
  2. AI suggests probable root causes from patterns
  3. AI proposes fix candidates with confidence scores
  4. Human validates diagnosis and applies fix
  5. AI generates postmortem draft
- **Decision points:** AI confidence threshold for fix suggestions; human always validates production fixes
- **Human-AI collaboration:** AI surfaces candidates; human diagnoses and decides
- **Roles/RACI:** AI agent (C), On-call engineer (R/A), Incident commander (A)
- **Tool categories:** AI debugging assistants, log analysis agents, incident response copilots
- **Outputs:** Root cause hypothesis, fix candidates, postmortem draft
- **Quality criteria:** Correct root cause identified; fix verified in staging; postmortem approved
- **KPIs:** Mean time to diagnosis (MTTD), mean time to resolution (MTTR), AI suggestion accuracy
- **Anti-patterns:** Blindly applying AI-suggested fixes in production; AI hallucinating root causes
- **Tiers:**
  - *Minimum:* AI-assisted log search and pattern matching
  - *Standard:* AI correlates changes with incidents, suggests fixes
  - *Leading-edge:* Autonomous incident triage, AI-driven runbooks, automated remediation with human approval

## Dependencies

| Dependency | Area | Nature |
|-----------|------|--------|
| Version control & branching | Area 5 | AI agents require structured repo access |
| CI/CD pipelines | Area 9 | Automated quality gates for agent output |
| Test automation | Area 8 | Tests as acceptance criteria for AI-generated code |
| Security scanning | Area 10 | Mandatory for all AI-generated output |
| Platform engineering | Area 14 | Agent harness infrastructure |
| Code review process | Area 7 | Human review of AI output |
| Documentation standards | Area 13 | Context for AI doc generation |

## Metrics / Gates / Exit Criteria

| Metric | Target | Gate |
|--------|--------|------|
| AI-generated code defect density | ≤ human baseline | CI quality gate |
| Agent task completion rate | ≥ 70% for well-scoped tasks | Sprint review |
| AI review false-positive rate | ≤ 20% | Review pipeline config |
| Context engineering effectiveness | ≥ 80% agent success on standard tasks | Monthly assessment |
| Human override rate | ≤ 30% for routine tasks | Weekly review |
| Security vulnerability introduction rate | 0 critical/high from AI-generated code | Security scan gate |

## Pitfalls and Mitigations

| Pitfall | Evidence | Mitigation |
|---------|----------|------------|
| **Throughput-instability tradeoff** | DORA 2025: higher AI adoption → more throughput AND more instability | Enforce small batches, robust test automation, mandatory review gates |
| **AI as amplifier of dysfunction** | DORA: AI magnifies dysfunctions of struggling orgs | Fix foundational practices first (testing, CI/CD, platform quality) before AI adoption |
| **Context bloat** | Thoughtworks: noisy context degrades agent output | Modular, path-based context loading; regular context pruning |
| **Verification tax** | DORA: time saved in creation re-allocated to auditing | Shift-left AI feedback to author phase; invest in automated verification |
| **Skill atrophy** | Emerging concern: developers losing ability to code without AI | Maintain manual coding practice; AI-free exercises; code review without AI assistance |
| **Security blind spots** | AI may introduce vulnerabilities from training data patterns | Mandatory security scanning of all AI-generated code; OWASP-aligned review |
| **License/IP contamination** | AI may reproduce licensed code from training data | IP scanning tools; configured code similarity detection; legal review policy |
| **Over-reliance on AI review** | Risk of rubber-stamping AI approvals | Human reviewer accountability; audit trail; periodic review quality checks |

## Context Variations

### Startup vs. Enterprise

| Dimension | Startup | Enterprise |
|-----------|---------|------------|
| Tool choice | Single AI assistant (Copilot/Claude Code) | Multi-tool strategy with governance |
| Context engineering | Informal, developer-managed | Platform-managed, standardized |
| Agent autonomy | Higher (smaller teams, faster iteration) | Lower (more gates, compliance requirements) |
| Review process | Lightweight, trust-based | Formal, audit-trailed |
| Risk tolerance | Higher (speed priority) | Lower (compliance priority) |

### Regulated vs. Consumer

| Dimension | Regulated (finance, health, gov) | Consumer |
|-----------|----------------------------------|----------|
| AI-generated code policy | Mandatory human review + audit trail | Risk-based review |
| Agent autonomy | Minimal; human-in-the-loop always | Human-on-the-loop for routine tasks |
| Data handling | On-prem/private LLM deployment required | Cloud API acceptable |
| Compliance | NIST AI RMF alignment; explainability required | Best-effort quality gates |
| Documentation | Full provenance chain for AI decisions | Standard documentation |

### Greenfield vs. Legacy

| Dimension | Greenfield | Legacy |
|-----------|-----------|--------|
| AI effectiveness | Higher (clean patterns, modern stack) | Lower (inconsistent patterns, old frameworks) |
| Context engineering | Built-in from start | Retrofit required; may need codebase cleanup first |
| Agent migration tasks | N/A | High value for modernization/refactoring |
| Testing baseline | AI can generate from scratch | AI must understand existing test patterns |

---

# AI Integration Matrix: Cross-Area AI Use Cases

| # | Process Area | AI/Agentic Use Cases | Evidence Level | Risk Tier |
|---|-------------|---------------------|---------------|-----------|
| 1 | **Product Discovery & Strategy** | AI-assisted market research synthesis; user feedback clustering; competitive analysis automation | Moderate (emerging) | Low |
| 2 | **Requirements Engineering** | AI-assisted user story generation; acceptance criteria expansion; requirements consistency checking; natural language ambiguity detection | Moderate (early adoption) | Medium |
| 3 | **Architecture & Design** | AI-assisted architecture decision records; pattern suggestion from requirements; trade-off analysis; diagram generation | Low-Moderate (experimental) | High |
| 4 | **Project Planning & Estimation** | AI-assisted story pointing; historical velocity analysis; risk identification; dependency mapping | Low (speculative) | Medium |
| 5 | **Version Control & Collaboration** | AI-generated commit messages; PR description generation; branch naming; merge conflict resolution suggestions | High (operational) | Low |
| 6 | **Build & Dependency Management** | AI-assisted dependency update analysis; build failure diagnosis; compatibility prediction | Moderate (early adoption) | Medium |
| 7 | **Code Review** | AI-powered review comments; style enforcement; security pattern detection; review triage | High (operational at Google, GitHub) | Medium |
| 8 | **Testing & Quality Assurance** | AI test generation; test maintenance; coverage gap analysis; flaky test detection; mutation testing | High (operational) | Medium |
| 9 | **CI/CD & Pipeline Engineering** | AI-assisted pipeline optimization; failure triage; deployment risk prediction; auto-remediation | Moderate (early adoption) | High |
| 10 | **Security Engineering** | AI vulnerability scanning; secure code suggestion; dependency audit; threat modeling assistance | Moderate (promising but requires validation) | Critical |
| 11 | **Database & Data Engineering** | AI-assisted schema design; query optimization; migration generation; data quality checks | Moderate (early adoption) | High |
| 12 | **API Design & Integration** | AI-assisted API spec generation; contract test generation; documentation; backward compatibility analysis | Moderate (early adoption) | Medium |
| 13 | **Documentation & Knowledge** | AI doc generation from code; cross-repo doc sync; API reference maintenance; changelog generation | High (operational at GitHub) | Low |
| 14 | **Platform Engineering & IaC** | AI-assisted IaC generation; platform configuration; drift detection; cost optimization | Moderate (early adoption) | High |
| 15 | **Release Management** | AI-assisted release notes; changelog generation; release risk assessment; rollback prediction | Moderate (early adoption) | Medium |
| 16 | **Operations & Incident Response** | AI log analysis; incident correlation; runbook execution; postmortem drafting | Moderate (early adoption) | High |
| 17 | **Metrics, Feedback & Continuous Improvement** | AI-assisted metric interpretation; anomaly detection; trend analysis; improvement recommendation | Moderate (early adoption) | Low |

### Evidence Level Key
- **High:** Multiple peer-reviewed studies or operational evidence from ≥3 major organizations
- **Moderate:** Operational evidence from 1-2 organizations or industry surveys
- **Low-Moderate:** Early experimental evidence or vendor claims with limited independent validation
- **Low:** Speculative or anecdotal; no systematic evidence

### Risk Tier Key
- **Critical:** AI errors could directly cause security vulnerabilities or data breaches
- **High:** AI errors could cause production outages or data loss
- **Medium:** AI errors could cause quality degradation or rework
- **Low:** AI errors are easily caught and have minimal impact

---

# Workflow Details: AI Integration Workflows in Other Process Areas

## WF-AI.1: AI-Assisted Requirements Analysis (Area 2)

- **Objective:** Use AI to improve requirements completeness and consistency
- **Classification:** Emerging
- **Triggers:** New feature request; epic creation; sprint planning
- **Inputs:** User stories, product backlog, domain knowledge base
- **Steps:**
  1. AI expands user story with edge cases and acceptance criteria
  2. AI checks for contradictions with existing requirements
  3. AI identifies ambiguous language and suggests clarification
  4. Product owner validates and refines
- **Human-AI collaboration:** AI suggests; PO decides
- **Quality criteria:** All acceptance criteria testable; no contradictions; PO sign-off
- **KPIs:** Requirements completeness score, ambiguity reduction, rework reduction
- **Anti-patterns:** Accepting AI-generated requirements without domain validation

## WF-AI.2: AI-Assisted Security Analysis (Area 10)

- **Objective:** Augment security review with AI-powered vulnerability detection
- **Classification:** Leading-edge
- **Triggers:** PR opened; dependency updated; security scan triggered
- **Inputs:** Code diff, dependency manifest, OWASP rules, CVE database
- **Steps:**
  1. AI scans code for security anti-patterns
  2. AI correlates with known vulnerability patterns
  3. AI suggests secure alternatives
  4. Security engineer validates findings
- **Human-AI collaboration:** AI detects; security engineer validates and prioritizes
- **Quality criteria:** Zero false negatives for critical vulnerabilities; acceptable false-positive rate
- **KPIs:** Vulnerability detection rate, false-positive rate, time-to-detection
- **Anti-patterns:** Treating AI security scan as sufficient; ignoring AI findings without investigation

## WF-AI.3: AI-Assisted Incident Response (Area 16)

- **Objective:** Accelerate incident diagnosis and resolution with AI
- **Classification:** Emerging
- **Triggers:** Production alert; error rate spike; user-reported issue
- **Inputs:** Monitoring data, logs, traces, recent deployments, postmortem history
- **Steps:**
  1. AI correlates alert with recent changes and known patterns
  2. AI suggests probable root causes ranked by confidence
  3. AI proposes remediation steps
  4. On-call engineer validates and executes
  5. AI drafts postmortem
- **Human-AI collaboration:** AI surfaces information; human diagnoses and acts
- **Quality criteria:** Correct root cause identified; fix verified; postmortem complete
- **KPIs:** MTTD, MTTR, AI suggestion accuracy
- **Anti-patterns:** Auto-applying AI fixes in production; AI hallucinating correlations

---

# Summary of Evidence Gaps

1. **Architecture & Design (Area 3):** Limited evidence of systematic AI adoption for architecture decisions. Most evidence is anecdotal.
2. **Project Planning & Estimation (Area 4):** AI-assisted estimation remains speculative; no robust studies on accuracy improvement.
3. **Database & Data Engineering (Area 11):** Early evidence for AI-assisted schema design and query optimization; needs more operational validation.
4. **Skill atrophy risk:** Emerging concern but no longitudinal studies yet.
5. **Multi-agent coordination:** Theoretical frameworks exist (Anthropic patterns) but operational evidence at scale is limited to a few organizations.
6. **Regulated industry adoption:** Most evidence comes from tech companies; regulated industry evidence is sparse.
7. **AI-assisted testing quality:** While generation is well-evidenced, the quality and maintainability of AI-generated tests lacks systematic study.
