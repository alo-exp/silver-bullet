# Subagent 2: Process Areas & Workflows

## Coverage
- PA-2: Discovery, Requirements & Product Definition
- PA-3: UX & Product Design
- PA-5: Planning & Work Management
- PA-16: Measurement, DevEx & Continuous Improvement

---

## PA-2: Discovery, Requirements & Product Definition

### Definition & Purpose
The process of identifying customer problems, validating market opportunities, and translating insights into actionable product requirements. Ensures teams build the *right thing* before investing in delivery.

### Mid-2026 Relevance
AI-assisted discovery (synthetic user interviews, automated competitive analysis, AI-generated prototypes) has compressed early-stage validation timelines. However, DORA's 2024 research warns that "AI significantly lowers the barrier to start, it does not inherently simplify the rigorous requirements of production-grade engineering" (src-dora-ai). Product discovery remains the primary risk-mitigation layer against building unwanted features.

### Inputs
- Market signals, customer feedback, support tickets, usage analytics
- Strategic objectives and OKRs
- Competitive intelligence
- Technical feasibility assessments

### Workflows
1. **Opportunity Assessment** (see WF-2.1)
2. **User Research & Problem Discovery** (see WF-2.2)
3. **Requirements Specification & Validation** (see WF-2.3)

### Outputs
- Validated opportunity assessments
- User stories / jobs-to-be-done with acceptance criteria
- Prioritized product backlog items
- Discovery artifacts (personas, journey maps, problem statements)

### Dependencies
- Upstream: Strategy & Portfolio Management (PA-1)
- Downstream: UX & Product Design (PA-3), Planning & Work Management (PA-5)

### Metrics / Gates / Exit Criteria
- **Gate:** Opportunity assessment approved by product leadership before entering design
- **Metrics:** Problem-solution fit score, customer interview completion rate, requirement stability index (change rate post-baseline)
- **Exit criteria:** Problem validated with ≥5 user interviews; solution hypothesis has measurable success criteria

### Pitfalls & Mitigations
| Pitfall | Mitigation |
|---------|-----------|
| Confirmation bias in interviews | Use structured interview protocols; separate interviewer from note-taker |
| Requirements churn after baseline | Freeze requirements per sprint/iteration; track change rate as metric |
| Over-reliance on stakeholder opinions vs user evidence | Require user evidence for every prioritized item (SVPG "evidence over opinion") |
| AI-generated requirements without validation | Treat AI output as hypotheses requiring human validation |

### Context Variations
- **Startup:** Lean discovery via rapid prototyping and customer development interviews; minimal documentation
- **Enterprise:** Formal requirements documents, traceability matrices, compliance-driven acceptance criteria
- **Regulated (healthcare/finance):** Requirements must include regulatory compliance mapping, audit trails
- **B2B vs B2C:** B2B requires deeper stakeholder mapping; B2C relies more on behavioral analytics at scale

---

### WF-2.1: Opportunity Assessment

| Attribute | Value |
|-----------|-------|
| **Objective** | Evaluate whether a product opportunity is worth pursuing before investing design/engineering resources |
| **Classification** | Universal |
| **Triggers** | New feature request, market signal, strategic initiative, customer escalation |
| **Preconditions** | Product strategy and target market defined |
| **Inputs** | Customer problem statement, market data, business objectives |

**Steps:**
1. Define the business problem and target user
2. Assess business value (revenue impact, strategic alignment, cost reduction)
3. Evaluate market size and competitive landscape
4. Identify key risks (value, usability, feasibility, business viability)
5. Define success metrics and measurement plan
6. Decision: Proceed / Pivot / Kill

**Decision Points:**
- Is the problem real and frequent enough? (value risk)
- Can users figure out how to use the solution? (usability risk)
- Can we build it? (feasibility risk)
- Does it work for our business model? (business viability risk)

**Human-AI Collaboration:**
- AI: Competitive analysis aggregation, market sizing estimates, draft opportunity assessment documents
- Human: Customer empathy, strategic judgment, go/no-go decisions

**RACI:**
- R: Product Manager
- A: VP Product / Product Leadership
- C: Engineering Lead, Design Lead, Business Stakeholders
- I: Delivery teams

**Tool Categories:** Product discovery tools (Jira Product Discovery, ProductBoard), analytics (Amplitude, Mixpanel), AI assistants for synthesis

**Outputs:** Completed opportunity assessment document with go/no-go recommendation

**Quality/Security/Completion Criteria:**
- All four risk dimensions assessed
- Success metrics defined with baseline and target
- At least one customer validation data point

**Automation Opportunities:** Auto-populate competitive landscape; AI-draft initial assessment from support ticket clusters

**Approval Boundaries:** Product Manager recommends; Product Leadership approves investment

**Escalation:** Strategic conflicts escalated to portfolio/leadership level

**KPIs:** Time-to-assessment, % of assessed opportunities that proceed to delivery, post-launch success metric achievement rate

**Anti-patterns:**
- "HiPPO" decisions (Highest Paid Person's Opinion) bypassing assessment
- Assessment as checkbox exercise without genuine validation
- Skipping feasibility check leading to undeliverable commitments

**Implementation Tiers:**
- **Minimum:** One-page opportunity canvas with problem, users, risks, success metrics
- **Standard:** Structured assessment with customer interviews, competitive analysis, feasibility spike
- **Leading-edge:** Continuous discovery with automated signal detection, AI-assisted risk scoring, weekly opportunity reviews

---

### WF-2.2: User Research & Problem Discovery

| Attribute | Value |
|-----------|-------|
| **Objective** | Develop deep understanding of user needs, behaviors, and pain points to inform product decisions |
| **Classification** | Universal |
| **Triggers** | New product initiative, declining metrics, user complaints, strategic pivot |
| **Preconditions** | Target user segment identified; research budget allocated |
| **Inputs** | User hypotheses, existing analytics, support data |

**Steps:**
1. Define research objectives and questions
2. Select appropriate methods (qualitative vs quantitative, attitudinal vs behavioral) per NN/g framework
3. Recruit participants matching target personas
4. Conduct research (interviews, observations, surveys, diary studies)
5. Synthesize findings into themes, personas, journey maps
6. Present insights and recommendations to product team

**Decision Points:**
- Qualitative vs quantitative: "Qualitative studies generate data about behaviors or attitudes based on observing or hearing them directly" while quantitative methods use instruments (src-nng-which-ux-methods)
- Generative (discover what's needed) vs evaluative (assess existing design)

**Human-AI Collaboration:**
- AI: Transcript analysis, theme extraction, survey generation, synthetic participant testing
- Human: Empathic observation, contextual interpretation, relationship building

**RACI:**
- R: UX Researcher
- A: Product Manager
- C: Design Lead, Engineering (for feasibility context)
- I: Broader product team

**Tool Categories:** Interview platforms (UserTesting, Lookback), survey tools (Typeform, Qualtrics), synthesis tools (Dovetail, Notion AI), analytics (FullStory, Hotjar)

**Outputs:** Research report, personas, journey maps, problem statements, insight repository

**Quality/Security/Completion Criteria:**
- Minimum 5 participants per segment for qualitative (saturation threshold)
- Research plan reviewed for bias
- Participant consent and data privacy compliance (GDPR, CCPA)

**Automation Opportunities:** AI-powered transcript summarization; automated survey analysis; pattern detection across research sessions

**Approval Boundaries:** Research plan approved by Product Manager; findings shared before design begins

**Escalation:** Conflicting findings escalated to product leadership with evidence

**KPIs:** Research velocity (studies per quarter), insight-to-action rate, % of product decisions backed by user evidence

**Anti-patterns:**
- Research theater (conducting research without intent to act on findings)
- Only interviewing power users; ignoring churned/non-users
- Over-indexing on what users say vs what they do

**Implementation Tiers:**
- **Minimum:** 5 user interviews per initiative; basic synthesis document
- **Standard:** Mixed-methods research program; personas and journey maps maintained; quarterly research cadence
- **Leading-edge:** Continuous research ops; AI-assisted synthesis; research repository with cross-study insights; participant panel

---

### WF-2.3: Requirements Specification & Validation

| Attribute | Value |
|-----------|-------|
| **Objective** | Translate validated problems and opportunities into clear, testable requirements for delivery teams |
| **Classification** | Universal |
| **Triggers** | Validated opportunity assessment; completed user research |
| **Preconditions** | Problem-solution fit established; key risks mitigated |
| **Inputs** | Discovery artifacts, user stories, technical constraints, compliance requirements |

**Steps:**
1. Decompose opportunity into user stories / jobs-to-be-done
2. Define acceptance criteria for each story (testable, specific)
3. Identify dependencies and technical constraints
4. Prioritize using value/effort matrix or WSJF
5. Validate requirements with stakeholders and engineering
6. Baseline requirements and establish change control

**Decision Points:**
- Level of specification detail (user story vs detailed spec) based on team maturity and risk
- Build vs buy vs partner for specific capabilities

**Human-AI Collaboration:**
- AI: Draft user stories from research transcripts, generate acceptance criteria suggestions, identify missing edge cases
- Human: Validate completeness, negotiate scope, ensure business context

**RACI:**
- R: Product Manager / Business Analyst
- A: Product Owner
- C: Engineering Lead, QA Lead, Security
- I: Delivery team

**Tool Categories:** Requirements management (Jira, Linear, Aha!), specification tools (Confluence, Notion), AI writing assistants

**Outputs:** Prioritized backlog with acceptance criteria, requirements traceability matrix (regulated contexts), definition of ready

**Quality/Security/Completion Criteria:**
- Every story has testable acceptance criteria
- Security and privacy requirements identified (NIST SSDF alignment for regulated contexts)
- Definition of Ready met before entering sprint

**Automation Opportunities:** AI-generated acceptance criteria from user stories; automated dependency detection; requirements consistency checking

**Approval Boundaries:** Product Owner approves backlog priority; Engineering approves feasibility estimates

**Escalation:** Scope conflicts escalated via product-engineering leadership alignment

**KPIs:** Requirement stability index, % stories meeting Definition of Ready, rework rate due to unclear requirements

**Anti-patterns:**
- 50-page PRDs that nobody reads
- Acceptance criteria that are untestable ("should be fast")
- Requirements written without engineering input

**Implementation Tiers:**
- **Minimum:** User stories with acceptance criteria in backlog tool
- **Standard:** Structured requirements with traceability, dependency mapping, Definition of Ready
- **Leading-edge:** Living requirements with automated consistency checks; AI-assisted gap detection; continuous refinement integrated with discovery

---

## PA-3: UX & Product Design

### Definition & Purpose
The discipline of designing product experiences that are usable, useful, and desirable. Translates validated requirements into interaction designs, visual systems, and prototypes ready for engineering.

### Mid-2026 Relevance
Design systems have matured as shared infrastructure. AI-powered design tools (generative UI, design-to-code) have accelerated production but raised questions about design quality and consistency. NN/g's design thinking framework remains the canonical process: "empathize, define, ideate, prototype, test, and implement" (src-nng-design-thinking).

### Inputs
- Validated requirements and user stories (from PA-2)
- User research findings, personas, journey maps
- Design system components and patterns
- Technical constraints and platform capabilities

### Workflows
1. **UX Research & Usability Evaluation** (see WF-3.1)
2. **Interaction & Visual Design** (see WF-3.2)
3. **Design System Governance** (see WF-3.3)

### Outputs
- Wireframes, mockups, interactive prototypes
- Design specifications and handoff documentation
- Updated design system components
- Usability test results and recommendations

### Dependencies
- Upstream: Discovery & Requirements (PA-2)
- Downstream: Implementation (PA-6), Planning (PA-5)
- Cross-cutting: Accessibility compliance, brand guidelines

### Metrics / Gates / Exit Criteria
- **Gate:** Design review approved before engineering implementation begins
- **Metrics:** Usability score (SUS/CSAT), design-to-development handoff completeness, design debt backlog size
- **Exit criteria:** Prototype validated with ≥3 users; design specs complete with responsive breakpoints

### Pitfalls & Mitigations
| Pitfall | Mitigation |
|---------|-----------|
| Designing without user validation | Mandate usability testing before handoff |
| Design system fragmentation | Governance process for component additions/changes |
| Pixel-perfect handoff expectations causing friction | Use design tokens and component-based handoff |
| AI-generated designs without accessibility review | Automated accessibility scanning + manual audit |

### Context Variations
- **Startup:** Rapid prototyping with lightweight tools; designer as generalist
- **Enterprise:** Design system with governance board; specialized roles (UX researcher, interaction designer, visual designer)
- **Regulated:** Accessibility compliance (WCAG 2.2 AA minimum); design documentation for audit
- **Mobile-first:** Platform-specific design patterns (HIG, Material Design); gesture-based interaction design

---

### WF-3.1: UX Research & Usability Evaluation

| Attribute | Value |
|-----------|-------|
| **Objective** | Evaluate design solutions against user needs through structured testing to identify usability issues before development |
| **Classification** | Universal |
| **Triggers** | Design prototype ready for testing; usability concerns raised; new feature design |
| **Preconditions** | Testable prototype or existing product available |
| **Inputs** | Design prototypes, user personas, task scenarios |

**Steps:**
1. Define test objectives and success criteria
2. Select method: usability testing, heuristic evaluation, A/B testing, or cognitive walkthrough
3. Recruit representative participants
4. Conduct test sessions (moderated or unmoderated)
5. Analyze findings; categorize by severity
6. Present recommendations with evidence clips/quotes

**Decision Points:**
- Moderated vs unmoderated testing (depth vs scale)
- Formative (during design) vs summative (after design) evaluation
- NN/g method selection: "the context of product use" and "phases of product development" guide method choice (src-nng-which-ux-methods)

**Human-AI Collaboration:**
- AI: Automated heuristic evaluation, eye-tracking prediction, accessibility scanning, test session transcription
- Human: Empathic observation, contextual interpretation, severity judgment

**RACI:**
- R: UX Researcher
- A: Design Lead
- C: Product Manager, Engineering (feasibility of fixes)
- I: Design team, Product team

**Tool Categories:** Usability testing (UserTesting, Maze, Lookback), heuristic evaluation tools, accessibility (axe, Lighthouse), analytics (FullStory, Hotjar)

**Outputs:** Usability test report with severity-rated findings, video clips, prioritized fix recommendations

**Quality/Security/Completion Criteria:**
- Nielsen's 10 usability heuristics evaluated (src-nng-articles)
- Minimum 5 participants for qualitative usability testing
- Critical/blocker issues identified and tracked to resolution

**Automation Opportunities:** AI-powered usability issue detection from screen recordings; automated accessibility compliance checking; synthetic user testing for initial heuristic pass

**Approval Boundaries:** Design Lead approves test plan; critical findings require Product Manager acknowledgment

**Escalation:** Unresolved critical usability issues block development start

**KPIs:** Usability issue detection rate pre-launch, SUS score, task completion rate, time-on-task improvement

**Anti-patterns:**
- Testing only with internal team members
- Testing after development is complete (too late to change)
- Ignoring "minor" usability issues that compound

**Implementation Tiers:**
- **Minimum:** 5-user moderated usability test on key flows before launch
- **Standard:** Regular testing cadence; mixed methods; heuristic evaluations; accessibility audits
- **Leading-edge:** Continuous unmoderated testing pipeline; AI-assisted issue detection; predictive usability modeling; research repository

---

### WF-3.2: Interaction & Visual Design

| Attribute | Value |
|-----------|-------|
| **Objective** | Create usable, accessible, and visually coherent interface designs that satisfy user needs and business goals |
| **Classification** | Universal |
| **Triggers** | Validated requirements; user research findings; design system updates needed |
| **Preconditions** | User research completed; requirements baselined |
| **Inputs** | User stories, research findings, brand guidelines, design system |

**Steps:**
1. Information architecture and content structure
2. Low-fidelity wireframes for key flows
3. Interaction design (navigation, states, transitions, error handling)
4. Visual design (typography, color, spacing, iconography)
5. Responsive/adaptive design for target platforms
6. Design specification and developer handoff
7. Design QA during implementation

**Decision Points:**
- Fidelity level based on risk and complexity
- Custom vs design-system component
- Platform-specific vs cross-platform patterns

**Human-AI Collaboration:**
- AI: Generate layout variations, design-to-code translation, accessibility contrast checking, asset generation
- Human: Creative direction, brand alignment, interaction nuance, emotional design

**RACI:**
- R: Product Designer / UI Designer
- A: Design Lead
- C: Product Manager, Frontend Engineering
- I: UX Researcher, Backend Engineering

**Tool Categories:** Design tools (Figma, Sketch), prototyping (Figma, ProtoPie), design tokens (Style Dictionary), handoff (Figma Dev Mode, Zeplin)

**Outputs:** Interactive prototypes, design specifications, component specifications, asset exports, design tokens

**Quality/Security/Completion Criteria:**
- WCAG 2.2 AA compliance verified
- All interaction states designed (default, hover, active, disabled, error, loading, empty)
- Responsive breakpoints defined
- Design review approved by Design Lead and Product Manager

**Automation Opportunities:** AI-generated design variations; automated design-to-code; design linting for consistency; automated accessibility checking

**Approval Boundaries:** Design Lead approves visual direction; Product Manager approves functional completeness

**Escalation:** Design-engineering feasibility conflicts escalated to Design Lead + Engineering Lead jointly

**KPIs:** Design-to-development handoff time, design QA defect rate, component reuse rate, accessibility compliance score

**Anti-patterns:**
- Designing in isolation without engineering feasibility input
- Ignoring edge cases (empty states, error states, long text)
- Over-customization bypassing design system

**Implementation Tiers:**
- **Minimum:** Wireframes + key screen mockups with basic handoff
- **Standard:** Interactive prototypes with all states; design system integration; design QA process
- **Leading-edge:** AI-assisted design generation; automated design-to-code pipeline; design token system; continuous design system evolution

---

### WF-3.3: Design System Governance

| Attribute | Value |
|-----------|-------|
| **Objective** | Maintain a consistent, scalable, and accessible component library that accelerates design and development |
| **Classification** | Context-dependent (scale-dependent) |
| **Triggers** | New component need; inconsistency detected; platform update; accessibility audit finding |
| **Preconditions** | Existing design system or decision to create one |
| **Inputs** | Component requests, usage analytics, accessibility audit results, platform updates |

**Steps:**
1. Submit component proposal with use cases and justification
2. Review against existing components (avoid duplication)
3. Design component with all states and variants
4. Implement component with accessibility and testing
5. Document usage guidelines and do/don't examples
6. Publish and communicate release
7. Monitor adoption and usage metrics

**Decision Points:**
- New component vs variant of existing
- Breaking change vs non-breaking
- Deprecation timeline for replaced components

**Human-AI Collaboration:**
- AI: Automated accessibility testing, component code generation from design, usage analytics, documentation drafting
- Human: Design decisions, governance reviews, breaking change management

**RACI:**
- R: Design System Team / Platform Designer
- A: Design System Lead
- C: Product Designers, Frontend Engineers, Accessibility Specialist
- I: All product teams

**Tool Categories:** Component libraries (Storybook, Figma libraries), documentation (Zeroheight, Storybook), testing (Chromatic, Percy), token management (Style Dictionary)

**Outputs:** Published components, release notes, updated documentation, migration guides for breaking changes

**Quality/Security/Completion Criteria:**
- Component passes accessibility audit (axe-core)
- Visual regression tests passing
- Documentation complete with usage examples
- Adopted by ≥2 consuming teams before declaring stable

**Automation Opportunities:** Automated visual regression testing; AI-generated component documentation; automated migration codemods for breaking changes

**Approval Boundaries:** Design System Lead approves component additions; breaking changes require consumer team sign-off

**Escalation:** Governance disputes escalated to Design Leadership + Engineering Leadership

**KPIs:** Component adoption rate, design consistency score, time-to-new-component, design debt reduction rate

**Anti-patterns:**
- Design system as ivory tower (imposed without consumer input)
- Too many similar components (lack of consolidation)
- No deprecation process (growing graveyard)

**Implementation Tiers:**
- **Minimum:** Shared Figma library + basic component documentation
- **Standard:** Versioned component library with Storybook; automated testing; governance process; adoption tracking
- **Leading-edge:** AI-assisted component generation; automated design-to-code sync; design token ecosystem; cross-platform design system with automated migration

---

## PA-5: Planning & Work Management

### Definition & Purpose
The process of organizing, prioritizing, and coordinating work across teams to deliver product value predictably. Bridges strategy and execution through iterative planning cycles.

### Mid-2026 Relevance
AI-assisted estimation and planning tools have emerged but human judgment remains critical for prioritization and dependency management. DORA research emphasizes that teams should "track metrics like cycle time, work in progress, defect escape rate, change failure rate, and mean time to recovery" to guide continuous improvement (src-atlassian-agile-handbook). Hybrid approaches combining Scrum structure with Kanban flow are increasingly common.

### Inputs
- Prioritized product backlog (from PA-2)
- Team capacity and velocity data
- Strategic roadmap and OKRs
- Dependency maps and risk registers

### Workflows
1. **Sprint/Iteration Planning** (see WF-5.1)
2. **Backlog Refinement & Prioritization** (see WF-5.2)
3. **Cross-Team Coordination & Dependency Management** (see WF-5.3)

### Outputs
- Sprint/iteration plans with committed goals
- Prioritized and refined backlog
- Dependency maps and risk mitigations
- Capacity plans and resource allocations

### Dependencies
- Upstream: Discovery & Requirements (PA-2), UX Design (PA-3)
- Downstream: Implementation (PA-6), CI/CD (PA-8)
- Cross-cutting: Architecture (PA-4), Security (PA-10)

### Metrics / Gates / Exit Criteria
- **Gate:** Sprint plan approved by team before execution begins
- **Metrics:** Sprint goal completion rate, cycle time, throughput, WIP limits adherence, planning accuracy (committed vs delivered)
- **Exit criteria:** Sprint goal defined; all stories meet Definition of Ready; capacity allocated

### Pitfalls & Mitigations
| Pitfall | Mitigation |
|---------|-----------|
| Overcommitting in sprint planning | Use historical velocity; leave 20% buffer for unplanned work |
| Backlog as dumping ground | Regular pruning; require opportunity assessment for new items |
| Ignoring technical debt | Allocate fixed % capacity (e.g., GitLab's 40% engineering time model) |
| Planning without dependency visibility | Maintain cross-team dependency board; flag blockers in planning |

### Context Variations
- **Startup:** Lightweight Kanban; minimal ceremony; founder-driven prioritization
- **Enterprise:** Scrum/SAFe with formal ceremonies; PI planning; portfolio-level dependency management
- **Regulated:** Planning must include compliance checkpoints and audit-ready documentation
- **Remote/distributed:** Asynchronous planning ceremonies; written decision records; timezone-aware scheduling

---

### WF-5.1: Sprint/Iteration Planning

| Attribute | Value |
|-----------|-------|
| **Objective** | Define a realistic, goal-oriented plan for the upcoming iteration that the team commits to delivering |
| **Classification** | Universal |
| **Triggers** | Start of new sprint/iteration; continuous planning trigger in Kanban |
| **Preconditions** | Backlog refined; previous sprint retrospective completed; team capacity known |
| **Inputs** | Prioritized backlog, team velocity/capacity, sprint goal candidates, dependency map |

**Steps:**
1. Review previous sprint outcomes and retrospective actions
2. Product Owner presents sprint goal and top-priority items
3. Team discusses, estimates, and commits to scope
4. Identify dependencies, risks, and mitigation plans
5. Define sprint goal (outcome-focused, not task-focused)
6. Confirm team capacity and adjust scope
7. Document sprint plan and communicate

**Decision Points:**
- Scope vs goal: If goal cannot be met with available capacity, negotiate scope reduction
- Carry-over: Unfinished work from previous sprint re-evaluated, not auto-carried

**Human-AI Collaboration:**
- AI: Velocity-based capacity prediction, automated estimation suggestions from historical data, risk flagging from dependency graphs
- Human: Goal negotiation, scope trade-offs, team commitment

**RACI:**
- R: Scrum Master / Team Lead (facilitation)
- A: Product Owner (scope), Team (commitment)
- C: Engineering Manager (capacity)
- I: Stakeholders, dependent teams

**Tool Categories:** Work management (Jira, Linear, Azure DevOps, Shortcut), estimation (Planning Poker, AI estimation), capacity planning

**Outputs:** Sprint backlog with committed stories, sprint goal, capacity allocation, risk register

**Quality/Security/Completion Criteria:**
- Sprint goal is measurable and outcome-focused
- All committed stories meet Definition of Ready
- Team consensus on commitment (no silent dissent)
- Security/compliance items included if applicable

**Automation Opportunities:** AI-powered estimation from historical data; automated capacity calculation from PTO/calendar; auto-generated sprint reports

**Approval Boundaries:** Product Owner approves scope; Team approves commitment; Scrum Master approves process adherence

**Escalation:** Unresolvable scope/capacity conflicts escalated to Product Manager + Engineering Manager

**KPIs:** Sprint goal completion rate, planning accuracy (committed vs delivered %), sprint carry-over rate, cycle time

**Anti-patterns:**
- Sprint planning as assignment (PO dictates, team accepts)
- Estimating in hours without calibration
- Ignoring WIP limits and context switching costs
- Planning ceremony without retrospective input

**Implementation Tiers:**
- **Minimum:** Backlog prioritization + team commitment to sprint goal
- **Standard:** Velocity-based planning; capacity-adjusted; retrospective-driven improvements; dependency tracking
- **Leading-edge:** AI-assisted estimation and risk prediction; probabilistic forecasting; continuous flow with WIP limits; automated replanning triggers

---

### WF-5.2: Backlog Refinement & Prioritization

| Attribute | Value |
|-----------|-------|
| **Objective** | Maintain a healthy, actionable, and prioritized backlog that enables effective sprint planning |
| **Classification** | Universal |
| **Triggers** | Recurring refinement cadence (weekly/bi-weekly); new items added; strategy changes |
| **Preconditions** | Product backlog exists; team has capacity for refinement |
| **Inputs** | New requirements, stakeholder requests, technical debt items, bugs, discovery outputs |

**Steps:**
1. Review new items against opportunity assessment criteria
2. Decompose large items (epics) into appropriately sized stories
3. Add acceptance criteria and definition of ready checks
4. Estimate effort (relative sizing or t-shirt sizing)
5. Re-prioritize based on value, urgency, dependencies, and risk
6. Remove stale items (older than 6 months without action)
7. Ensure top-of-backlog items are sprint-ready

**Decision Points:**
- Prioritize vs deprioritize vs delete
- Split vs keep as single story
- Technical debt vs feature work allocation

**Human-AI Collaboration:**
- AI: Automated story decomposition suggestions, duplicate detection, staleness flagging, estimation from similar past work
- Human: Value judgment, strategic alignment, stakeholder negotiation

**RACI:**
- R: Product Owner
- A: Product Manager
- C: Engineering Lead (estimation, feasibility), UX (design readiness)
- I: Development team

**Tool Categories:** Backlog management (Jira, Linear, GitHub Projects), prioritization frameworks (RICE, WSJF, ICE), AI refinement assistants

**Outputs:** Refined and prioritized backlog; sprint-ready items at top; pruned stale items

**Quality/Security/Completion Criteria:**
- Top 2 sprints worth of items are sprint-ready
- Every item has clear acceptance criteria
- Stale items regularly pruned
- Technical debt visibly tracked (not hidden)

**Automation Opportunities:** Auto-detect duplicate stories; AI-suggested story splits; automated staleness alerts; auto-estimation from historical patterns

**Approval Boundaries:** Product Owner owns priority; Engineering owns estimates; conflicts resolved collaboratively

**Escalation:** Priority disputes between stakeholders escalated to Product Leadership

**KPIs:** Backlog health score (ready items / total), refinement cycle time, % items meeting Definition of Ready, backlog age distribution

**Anti-patterns:**
- Backlog as infinite wish list without pruning
- Refinement only at planning time (too late)
- Engineering estimates treated as commitments
- Hidden technical debt (not in backlog)

**Implementation Tiers:**
- **Minimum:** Weekly refinement session; basic prioritization
- **Standard:** Continuous refinement; structured frameworks (RICE/WSJF); Definition of Ready enforced; regular pruning
- **Leading-edge:** AI-assisted refinement; automated backlog health monitoring; predictive prioritization based on value signals; continuous discovery feeding backlog

---

### WF-5.3: Cross-Team Coordination & Dependency Management

| Attribute | Value |
|-----------|-------|
| **Objective** | Identify, track, and resolve dependencies between teams to prevent blockers and enable predictable delivery |
| **Classification** | Context-dependent (scale-dependent) |
| **Triggers** | Multi-team initiative; dependency identified in planning; cross-team blocker |
| **Preconditions** | Multiple teams working on related initiatives |
| **Inputs** | Team sprint plans, dependency maps, architecture diagrams, roadmap |

**Steps:**
1. Map dependencies during planning (upstream, downstream, shared services)
2. Classify dependency type (blocking, informational, shared resource)
3. Negotiate timelines and commitments with dependent teams
4. Track dependencies in shared visibility tool
5. Monitor for slippage and proactively communicate
6. Resolve blockers through escalation or replanning
7. Review dependency patterns in retrospectives

**Decision Points:**
- Decouple vs coordinate: Can we architect away the dependency?
- Sequential vs parallel: Can teams work in parallel with interface contracts?

**Human-AI Collaboration:**
- AI: Automated dependency detection from code changes, impact analysis, risk scoring
- Human: Negotiation, prioritization trade-offs, relationship management

**RACI:**
- R: Scrum Master / Program Manager
- A: Engineering Manager / Director
- C: Team Leads, Architects
- I: All affected teams

**Tool Categories:** Dependency tracking (Jira Advanced Roadmaps, Aha!), architecture visualization, API contract management, communication (Slack, Teams)

**Outputs:** Dependency map, coordination agreements, blocker resolution plans, updated timelines

**Quality/Security/Completion Criteria:**
- All known dependencies mapped and tracked
- Blocking dependencies have committed delivery dates
- No unresolved blockers older than 1 sprint without escalation

**Automation Opportunities:** Automated dependency detection from git/code changes; CI pipeline dependency visualization; automated blocker alerts

**Approval Boundaries:** Team leads agree on coordination; Engineering Director resolves conflicts

**Escalation:** Unresolved cross-team blockers escalated to VP Engineering within 1 sprint

**KPIs:** Dependency-related delays, blocker resolution time, cross-team commitment adherence, coupling index

**Anti-patterns:**
- Discovering dependencies mid-sprint (should be in planning)
- Treating all dependencies as blocking (some are informational)
- No visibility tool — dependencies tracked in people's heads

**Implementation Tiers:**
- **Minimum:** Dependency identification in sprint planning; ad-hoc coordination
- **Standard:** Dependency board; regular sync meetings; committed delivery dates; architectural decoupling initiatives
- **Leading-edge:** Automated dependency detection; API contract-first development; platform golden paths reducing cross-team dependencies; dependency graph visualization

---

## PA-16: Measurement, DevEx & Continuous Improvement

### Definition & Purpose
The systematic practice of measuring software delivery performance, developer experience, and organizational effectiveness to drive evidence-based continuous improvement. Encompasses DORA metrics, SPACE/DevEx frameworks, and structured feedback loops.

### Mid-2026 Relevance
DORA's 2024 research has evolved from four keys to five metrics (adding "failed deployment recovery time" replacing MTTR). The AI era has introduced new measurement dimensions: "acceptance rates of AI suggestions, model quality, or trust" alongside traditional DevEx measures (src-dora-measurement-frameworks). JetBrains 2024 survey found "almost half of tech managers reported that their companies measure developer productivity, DevEx, or both" (src-jetbrains-devecosystem). Platform engineering has emerged as the organizational response to DevEx at scale (src-cncf-platforms).

### Inputs
- DORA metrics data (deployment frequency, lead time, change failure rate, failed deployment recovery time)
- Developer surveys and sentiment data
- Tool usage telemetry
- Retrospective outcomes and action items
- Industry benchmarks

### Workflows
1. **DORA Metrics Collection & Analysis** (see WF-16.1)
2. **Developer Experience Assessment & Improvement** (see WF-16.2)
3. **Retrospectives & Continuous Improvement Cycles** (see WF-16.3)

### Outputs
- Performance dashboards with trend analysis
- DevEx improvement initiatives with ROI tracking
- Retrospective action items with completion tracking
- Benchmarking reports against industry standards

### Dependencies
- Upstream: All SDLC process areas generate measurement data
- Downstream: Improvement initiatives feed back into all process areas
- Cross-cutting: Platform Engineering (provides measurement infrastructure)

### Metrics / Gates / Exit Criteria
- **Gate:** Quarterly business review includes DORA metrics and DevEx trends
- **Metrics:** DORA four/five keys, SPACE dimensions, DevEx satisfaction scores, improvement initiative completion rate
- **Exit criteria:** Metrics collected and trended; improvement actions identified and tracked; retrospective cadence maintained

### Pitfalls & Mitigations
| Pitfall | Mitigation |
|---------|-----------|
| Vanity metrics (lines of code, commit count) | Use DORA/SPACE frameworks; measure outcomes not activity |
| Measuring without acting | Every metric must have an owner and action threshold |
| Weaponizing metrics against individuals | Measure at team/system level; never individual performance |
| Survey fatigue | Limit surveys; supplement with passive telemetry |
| AI productivity claims without evidence | Use controlled experiments (GitHub's approach: perceived + observed speed) |

### Context Variations
- **Startup:** Lightweight DORA tracking; informal retrospectives; DevEx as "do developers enjoy working here?"
- **Enterprise:** Formal measurement program; dedicated DevEx/platform team; quarterly benchmarking; SPACE framework adoption
- **Regulated:** Compliance metrics alongside performance; audit-ready measurement documentation
- **AI-heavy workflows:** New metrics for AI suggestion acceptance rate, code review time with AI, trust in AI output

---

### WF-16.1: DORA Metrics Collection & Analysis

| Attribute | Value |
|-----------|-------|
| **Objective** | Collect, analyze, and act on software delivery performance metrics to drive continuous improvement |
| **Classification** | Universal (leading-practice) |
| **Triggers** | Ongoing (continuous collection); quarterly review cadence; performance concern |
| **Preconditions** | CI/CD pipeline instrumented; version control in use |
| **Inputs** | Pipeline telemetry, deployment logs, incident data, version control data |

**Steps:**
1. Instrument pipeline for automated metric collection
2. Collect five DORA metrics: deployment frequency, change lead time, change failure rate, failed deployment recovery time, and reliability
3. Calculate metric values and compare to DORA performance levels (elite/high/medium/low)
4. Identify trends and anomalies over time
5. Correlate with capability investments (from DORA capabilities model)
6. Present findings in team and leadership reviews
7. Identify improvement initiatives based on metric gaps

**Decision Points:**
- Which metric is the current constraint? (Theory of Constraints approach)
- Invest in throughput (lead time, deployment frequency) vs stability (change failure rate, recovery time)?

**Human-AI Collaboration:**
- AI: Automated metric collection and dashboarding, anomaly detection, trend prediction, correlation analysis
- Human: Interpretation, prioritization of improvement investments, organizational change decisions

**RACI:**
- R: DevOps/Platform Engineering team
- A: Engineering Director / VP Engineering
- C: Team Leads, Product Managers
- I: All engineering teams, executive leadership

**Tool Categories:** DORA dashboards (DORA Quick Check, LinearB, Sleuth, Jellyfish), CI/CD telemetry (GitHub Actions, GitLab CI, Jenkins), observability (Datadog, Grafana)

**Outputs:** DORA metrics dashboard, trend reports, improvement initiative proposals, quarterly benchmarking report

**Quality/Security/Completion Criteria:**
- All five metrics collected automatically (no manual reporting)
- Metrics reviewed at team level monthly and leadership level quarterly
- Improvement initiatives tracked with before/after measurements
- "These metrics function as leading indicators for organizational performance and employee well-being" (src-dora-metrics-four-keys)

**Automation Opportunities:** Fully automated collection from CI/CD pipeline; AI-powered anomaly detection; automated report generation; predictive modeling

**Approval Boundaries:** Engineering leadership approves improvement investment based on metric evidence

**Escalation:** Sustained metric degradation escalated to VP Engineering with improvement plan

**KPIs:** DORA metric levels (elite/high/medium/low), metric trend direction, improvement initiative ROI, time-to-detect metric regression

**Anti-patterns:**
- Measuring DORA metrics without acting on them
- Gaming metrics (deploying empty changes to inflate deployment frequency)
- Comparing teams against each other instead of against their own trends
- Ignoring the fifth metric (reliability) in favor of speed metrics only

**Implementation Tiers:**
- **Minimum:** Manual DORA metric tracking in spreadsheet; quarterly review
- **Standard:** Automated collection via CI/CD pipeline; dashboards; monthly team reviews; quarterly leadership reviews
- **Leading-edge:** Real-time dashboards; AI anomaly detection; capability-to-metric correlation; predictive modeling; DORA metrics integrated with business KPIs

---

### WF-16.2: Developer Experience Assessment & Improvement

| Attribute | Value |
|-----------|-------|
| **Objective** | Systematically assess and improve the developer experience to increase productivity, satisfaction, and retention |
| **Classification** | Leading-edge |
| **Triggers** | Quarterly DevEx survey; developer complaints; tool changes; AI adoption; retention concerns |
| **Preconditions** | Engineering organization of sufficient size (>20 engineers) to justify dedicated measurement |
| **Inputs** | Developer surveys, tool usage telemetry, DORA metrics, support ticket data, onboarding metrics |

**Steps:**
1. Select measurement framework (SPACE, DevEx, or hybrid) aligned with organizational goals
2. Design and deploy developer experience survey (satisfaction, productivity, flow state, tool satisfaction)
3. Collect passive telemetry (build times, environment setup time, context switching frequency)
4. Analyze results using framework dimensions (SPACE: Satisfaction, Performance, Activity, Communication, Efficiency)
5. Identify top pain points and improvement opportunities
6. Prioritize improvements using impact/effort matrix
7. Implement improvements and measure before/after
8. For AI tools: track "acceptance rates of AI suggestions, model quality, or trust" (src-dora-measurement-frameworks)

**Decision Points:**
- Framework selection: "Frameworks differ because they are intended to drive different outcomes" — choose based on organizational goals (src-dora-measurement-frameworks)
- Investment in tooling vs process vs culture improvements
- AI tool adoption: mandate vs opt-in based on evidence

**Human-AI Collaboration:**
- AI: Survey analysis, sentiment detection, telemetry pattern recognition, automated improvement suggestions
- Human: Developer empathy, cultural understanding, prioritization, change management

**RACI:**
- R: Platform Engineering / DevEx team
- A: VP Engineering / CTO
- C: Engineering Managers, Developer Representatives
- I: All engineering teams

**Tool Categories:** Survey tools (Culture Amp, Officevibe), telemetry (DX — getdx.com), IDP (Backstage, Port), AI coding tools (Copilot, Cursor), developer portals

**Outputs:** DevEx assessment report, improvement roadmap, tool evaluation recommendations, ROI analysis

**Quality/Security/Completion Criteria:**
- Survey response rate >60%
- Top 3 pain points have assigned owners and timelines
- Before/after measurements for implemented improvements
- GitHub Copilot research shows "90% of developers expressed feeling more fulfilled with their jobs" and "70% reported quite a bit less mental effort on repetitive tasks" (src-github-copilot-impact) — use as benchmark

**Automation Opportunities:** Automated survey deployment and analysis; passive telemetry collection; AI-powered pain point clustering; automated ROI calculation

**Approval Boundaries:** Platform Engineering proposes improvements; VP Engineering approves investment

**Escalation:** Persistent low DevEx scores escalated to CTO with improvement plan

**KPIs:** DevEx satisfaction score, developer NPS, time-to-first-commit (onboarding), flow state duration, tool satisfaction scores, AI tool adoption rate

**Anti-patterns:**
- Survey without action (survey fatigue)
- Measuring individual developer productivity (lines of code, commits)
- Ignoring qualitative feedback in favor of quantitative metrics only
- Treating DevEx as purely a tooling problem (culture and process matter equally)

**Implementation Tiers:**
- **Minimum:** Annual developer satisfaction survey; ad-hoc improvements
- **Standard:** Quarterly DevEx surveys; dedicated DevEx/platform team; structured improvement program; tool evaluation process
- **Leading-edge:** Continuous passive telemetry; SPACE/DevEx framework; AI tool effectiveness measurement; developer journey mapping; DevEx as product with user research

---

### WF-16.3: Retrospectives & Continuous Improvement Cycles

| Attribute | Value |
|-----------|-------|
| **Objective** | Create structured feedback loops that identify improvements and drive systematic organizational learning |
| **Classification** | Universal |
| **Triggers** | End of sprint/iteration; after incidents; after major releases; quarterly strategic retrospectives |
| **Preconditions** | Psychological safety within team; data from the period being reviewed |
| **Inputs** | Sprint/iteration data, incident reports, metric trends, team observations |

**Steps:**
1. Set the stage (establish safety, review previous actions)
2. Gather data (what happened — facts, metrics, timeline)
3. Generate insights (why it happened — patterns, root causes)
4. Decide what to do (select 1-3 actionable improvements)
5. Close the retrospective (appreciations, action item assignment)
6. Track action items to completion
7. Review previous action items at next retrospective

**Decision Points:**
- Format selection: Atlassian's 5-step format (set stage, gather data, generate insights, decide actions, close) is widely adopted (src-atlassian-retrospectives)
- Scope: Team-level vs cross-team vs organizational retrospective
- Action item count: 1-3 maximum to avoid overcommitment

**Human-AI Collaboration:**
- AI: Automated data gathering from tools, sentiment analysis of team communication, pattern detection across retrospectives, action item tracking
- Human: Facilitation, psychological safety creation, nuanced interpretation, commitment building

**RACI:**
- R: Scrum Master / Team Lead (facilitation)
- A: Team (collective ownership of improvements)
- C: Engineering Manager (for systemic issues requiring org-level action)
- I: Dependent teams (for cross-team findings)

**Tool Categories:** Retrospective tools (EasyRetro, Parabol, Miro), action tracking (Jira, Linear), sentiment analysis, communication platforms

**Outputs:** Retrospective notes, 1-3 action items with owners and deadlines, updated team working agreements

**Quality/Security/Completion Criteria:**
- Action items are specific, measurable, and assigned
- Previous action items reviewed for completion
- At least one improvement action per retrospective
- "Close the loop with data to plan, measure, and learn" (src-atlassian-agile-handbook)

**Automation Opportunities:** Auto-generated retrospective data packs (metrics, incidents, changes); AI-suggested improvement actions from historical patterns; automated action item tracking and reminders

**Approval Boundaries:** Team owns team-level actions; systemic issues escalated to Engineering Manager

**Escalation:** Recurring unresolved issues escalated to Engineering Leadership; cross-team issues to Program Management

**KPIs:** Action item completion rate, retrospective satisfaction score, improvement velocity (time from identification to implementation), recurring issue reduction

**Anti-patterns:**
- Retrospective as complaint session without action
- Same action items every sprint without progress
- Skipping retrospectives when "too busy"
- No follow-up on action items
- Manager-dominated retrospectives suppressing honest feedback

**Implementation Tiers:**
- **Minimum:** End-of-sprint retrospective with action items tracked
- **Standard:** Multiple retrospective formats; data-driven; action items tracked to completion; cross-team retrospectives for systemic issues
- **Leading-edge:** AI-assisted pattern detection across retrospectives; organizational learning repository; improvement experiments with A/B testing; continuous improvement integrated with DORA metrics

---

## Evidence Gaps

1. **SPACE framework detail:** The ACM Queue article (src-space-framework) returned minimal content; SPACE dimensions are referenced from DORA's measurement framework article instead.
2. **SVPG opportunity assessment template:** SVPG articles are paywalled/summary-only; specific template questions are referenced from the broader SVPG methodology but not directly quoted.
3. **AI-assisted planning tools:** Limited peer-reviewed evidence on AI estimation accuracy in production settings; most claims are vendor-reported.
4. **Design system governance at scale:** Limited published evidence beyond Spotify/Backstage and general design system guidance.
5. **DevEx measurement in regulated industries:** Evidence limited; most DevEx research focuses on tech companies.
