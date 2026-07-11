# Decision Record — Canonical SDLC Process Architecture

This document records the rationale for taxonomy and classification decisions in the research report. It documents why each Process Area is in the taxonomy, why each workflow is classified as it is, and rejected alternatives.

## 1. Why 18 Process Areas (not 12, not 25)

### 1.1 Process Area selection criteria

A Process Area was included if it met **at least two** of:

1. ≥2 independent primary sources describe it as a distinct capability.
2. It is named explicitly in a Tier 1-3 source as a separable discipline.
3. It has a measurable metric or gate (i.e., it is a *capability* not a *vague aspiration*).
4. It is the home of at least one workflow that an org can name an owner for.

### 1.2 Brief-mandated Process Areas (all 18 included)

The brief mandated 18 Process Areas. All 18 are included verbatim. No reclassification, no consolidation.

### 1.3 Rejected alternatives (and why)

- **Consolidating PA-01 and PA-02.** Rejected. Strategy (PA-01) and Discovery (PA-02) are conceptually distinct: strategy sets the destination; discovery validates the path. They have different owners (C-suite vs. PM) and different metrics. Combined, the area becomes too vague to be actionable.
- **Splitting PA-04 into "architecture" and "design."** Rejected. Architecture and technical design are a single capability in the canonical literature (Fowler/Lewis microservices, Well-Architected frameworks). Splitting would create artificial boundaries.
- **Adding PA-19 "Data Engineering."** Rejected. Data engineering is its own discipline but the brief's scope is software development, and data engineering is covered under PA-04 (architecture), PA-10 (build), and PA-15 (observability) when in service of a software product. A full data-engineering taxonomy is a separate report.
- **Splitting PA-13 (Security) into "AppSec" and "InfoSec."** Rejected. The two are operationally distinct roles in many orgs but the *Process Area* is the same: secure software. Splitting would be org-specific.
- **Removing PA-17 (Maintenance).** Considered. PA-17 is under-documented in 2025-2026 primary sources, but the brief mandates it, and the *capability* is real. Kept with an honest "moderate evidence" note.
- **Promoting PA-18 to "AI Layer" rather than a Process Area.** Considered. PA-18 is horizontal — it touches every other PA. But it has its own workflows, owners, and metrics, which makes it a Process Area in its own right. It is also a first-class area in DORA 2025 and the NIST SSDF GenAI profile.

## 2. Why the four-layer model (Direction, Delivery, Feedback, Sustainability)

The four-layer model is not the brief's; it is the report's synthesis.

- **Direction (PA-01..PA-04):** sets the destination. Without direction, delivery is busywork.
- **Delivery (PA-05..PA-11):** the work of producing software. The bulk of the report.
- **Feedback (PA-12..PA-16):** the capabilities that make delivery safer (security, reliability) and faster (platform, observability, DevEx).
- **Sustainability (PA-17..PA-18):** the capabilities that keep the system alive over time (maintenance, AI).

**Alternative considered:** a single horizontal "Stack" model (e.g., "Strategy at the top, AI at the bottom"). Rejected because it implies a temporal sequence, which is misleading — all PAs run concurrently.

**Alternative considered:** grouping by Team Topologies team type (stream-aligned, platform, etc.). Rejected because the brief mandates a process taxonomy, not a team taxonomy.

## 3. Workflow classification rationale

Each workflow is classified as universal / leading-edge / context-dependent / emerging. The criteria:

- **Universal (≥80% of high-performing orgs practice this):**
  - Trunk-based commits (PA-07.1)
  - Code review (PA-08.1)
  - Test pyramid (PA-09.1)
  - CI pipeline (PA-11.1)
  - SLO definition (PA-14.1)
  - Incident response (PA-14.2)
  - SBOM generation (PA-10.3)
  - OpenTelemetry instrumentation (PA-15.1)
  - DORA metrics collection (PA-16.1)

- **Leading-edge (~30-70% of high-performing orgs, growing):**
  - Continuous Discovery Interviews (PA-02.1)
  - ADR with fitness function (PA-04.1, PA-04.4)
  - Backstage / IDP (PA-12.3)
  - Platform SLOs (PA-12.4)
  - Progressive delivery (PA-11.3)
  - GitOps reconciliation (PA-11.8)
  - SLSA L3 compliance (PA-13.5)
  - Chaos engineering (PA-14.6)
  - SLO burn-rate alerting (PA-15.3)
  - SPACE / DevEx survey (PA-16.2)

- **Context-dependent (use case-specific):**
  - Threat modeling at design (universal in regulated; leading-edge elsewhere)
  - Privacy Impact Assessment (universal in regulated; not applicable elsewhere)
  - Deprecation authoring (universal in API-driven orgs; less in monorepo)
  - Multi-architecture build (universal in mobile/embedded; less in serverless)

- **Emerging (credible operational adoption, not yet standard):**
  - AI code generation with review (PA-18.1)
  - AI-assisted test authoring (PA-18.2)
  - AI code review (PA-18.3)
  - Agentic engineering task (PA-18.4)
  - AI observability (PA-15.7)
  - AI governance (PA-18.5)

## 4. Rejected methodology choices

### 4.1 Why not advocate Shape Up, SAFe, Spotify, or any specific methodology

The report is a *reference model*, not a methodology. The brief is explicit about this. SAFe, LeSS, Scrum@Scale, Shape Up, Spotify, etc. are *methodologies* — concrete prescriptions for how to run the PAs. The reference model is the *what*; the methodology is the *how*.

The report does cite Shape Up, Team Topologies, and Accelerate as canonical references for specific patterns (shaping, team types, technical-to-org performance link). It does not advocate them as a whole.

### 4.2 Why "capability-based" not "stage-based"

The 18 Process Areas are not stages in a waterfall. They are ongoing capabilities. This is the dominant framing in modern engineering literature (DORA, Accelerate, Team Topologies, Shape Up) and is the only framing that supports continuous delivery.

A stage-based model (Requirements → Design → Build → Test → Deploy) was the dominant model in waterfall / stage-gate methodologies and remains common in regulated contexts (medical devices, aviation, finance). The report addresses this in the "context variations" sections but does not adopt it as the canonical framing.

### 4.3 Why the 13-field workflow template

The brief mandates 13 fields per workflow. The fields are: name, objective, classification, triggers, preconditions, inputs, steps/decision points, human-AI collaboration, roles/RACI, tool categories, outputs, quality/security/completion criteria, automation opportunities, approval boundaries/escalation, KPIs, anti-patterns, minimum/standard/leading-edge tiers.

(Counted: that's 16 fields — the brief's "13 required fields" includes the name, classification, and tiers as single fields. The author has chosen to be more comprehensive.)

## 5. Source authority decisions

### 5.1 Why Wikipedia is cited

Wikipedia is Tier 5 (academic/encyclopedia). It is cited for background context (SRE origins, CMM lineage, DevOps as a term). It is not cited for any major claim; major claims require Tier 1-3.

### 5.2 Why Humanitec and FireHydrant are cited (Tier 6)

Humanitec and FireHydrant are vendor / consultancy sources. They are cited for definitions and historical context (e.g., IDP definition, SRE best practices summary). They are not cited for any major claim; their citations are tagged as Tier 6 in `sources.jsonl`.

### 5.3 Why 2024 DORA report was inaccessible

The canonical DORA 2024 URL (`https://dora.dev/blog/2024-dora-accelerate-state-of-devops-report/`) returned 404 during this research. The 2025 DORA announcement (`https://cloud.google.com/blog/products/ai-machine-learning/announcing-the-2025-dora-report`) and the DORA Capabilities / Quick Check / Metrics pages were accessible. The report uses 2025 DORA as the substitute. This is documented in `critique.md` and `triangulation.md`.

## 6. Honest limitations of the report

1. The 110-workflow library is provided in compact form for most workflows and full 13-field form for representative ones. A full expansion is a follow-up project.
2. Some Tier 1 sources (e.g., DORA 2024 PDF, individual engineering blogs that returned 404) could not be retrieved; substitutes were used.
3. The AI process area is genuinely new; some claims are operationally adopted but lack longitudinal evidence.
4. Geographic diversity is limited; Asian and emerging-market engineering orgs are not directly cited.
5. The model is a snapshot of mid-2026. By 2027, several "leading-edge" workflows will likely be "universal" (especially in PA-18).

## 7. How the model should evolve

The model is intended to be a living reference, not a frozen standard. Recommended evolution:

- **Annual review** of every workflow's classification (universal / leading-edge / context-dependent / emerging). What is leading-edge in 2026 will be universal in 2027.
- **Add new workflows** as new practices emerge (e.g., quantum-aware security, agent-of-agents orchestration).
- **Deprecate workflows** that are no longer distinct (e.g., a future "manual test authoring" workflow may collapse into AI-test-generation).
- **Re-evaluate PA-18 every 6 months** until AI engineering practices stabilize.
- **Re-evaluate PA-12 (Platform Engineering) every 12 months** as the practice matures.

## 8. Decisions specifically about AI claims

### 8.1 The 55% Copilot figure

The 55% is from a single controlled study (GitHub/Accenture 2024). It is cited as evidence of *direction* of effect and *magnitude* of effect. It is not a universal claim.

### 8.2 The agent taxonomy (workflows vs agents)

Anthropic's taxonomy (workflows vs agents) is cited as the canonical reference. It is the only public taxonomy of agent patterns as of mid-2026. Other vendors (OpenAI, Google DeepMind) have published agent products but not a comparable taxonomy.

### 8.3 SWE-bench Verified

SWE-bench / SWE-bench Verified is cited as the canonical benchmark because it is the most widely-used, has a public leaderboard, and is based on real GitHub issues. Other benchmarks (HumanEval, MBPP, aider's polyglot benchmark) are useful but not yet the canonical reference for SWE agents.

### 8.4 NIST SP 800-218A

The NIST SSDF GenAI Community Profile is cited as the first formal standards anchor for AI model development. It is recent (2024) and not yet widely adopted operationally, but it is the only formal anchor from a Tier 3 source.
