# Research Report Outline: Canonical SDLC Process Architecture

## 1. Executive Summary
- Purpose of the reference model
- Key findings in 3-4 bullets
- Maturity snapshot: universal vs. leading-edge vs. emerging
- Recommendation for CTO/VP Engineering adoption

## 2. Research Method and Evidence Base
- Ultradeep multi-agent research methodology
- Source categories and credibility framework
- Triangulation rules and gap-handling policy
- Limitations of public-source research

## 3. Canonical Process-Area Taxonomy
- Introduction to the 18 Process Areas
- Lifecycle grouping (strategy → discovery → design → architecture → planning → implementation → verification → release → operations → improvement → retirement → AI enablement)
- For each Process Area (1-18):
  - Definition and purpose
  - Mid-2026 relevance
  - Inputs, outputs, dependencies
  - Metrics/gates/exit criteria
  - Pitfalls and mitigations
  - Context variations (startup/enterprise, regulated/consumer, greenfield/legacy)

## 4. Full Workflow Library
- Workflow metadata standard (name, objective, classification, triggers, steps, RACI, tools, criteria, KPIs, anti-patterns, tiers)
- Workflows grouped by Process Area
- Universal workflows (e.g., CI, code review, incident response, test automation)
- Leading-edge workflows (e.g., SRE error budgets, IDP golden paths, chaos engineering)
- Context-dependent workflows (e.g., formal change advisory boards, heavy design-system governance)
- Emerging workflows (e.g., agentic code review, AI-assisted threat modeling)

## 5. Cross-Area Dependency and Feedback Map
- Upstream/downstream matrix
- Feedback loops: production observability → requirements, incidents → architecture, metrics → improvement
- Critical integration points (DevSecOps, FinOps, AIOps, DevEx)
- Anti-patterns of siloed areas

## 6. AI-Integration Layer
- AI use cases mapped to each Process Area
- Human-AI collaboration patterns (copilot, agent, autonomous, human-in-the-loop)
- Evidence for operational adoption
- Risk tiers and governance boundaries
- AI-specific anti-patterns (skill atrophy, hallucination in requirements, over-reliance)

## 7. Deprecated or Diminishing Practices
- Waterfall-stage gates without iteration
- Manual-only release processes
- Security as final gate
- Hero culture / on-call without SLOs
- Big-bang rewrites
- Heavy specification documents without validation

## 8. Maturity Model
- 5-level maturity scale (Initial, Managed, Defined, Quantitatively Managed, Optimizing)
- Per-area maturity descriptors
- Minimum / standard / leading-edge implementation tiers
- Evidence-based benchmarks (DORA, OWASP SAMM, NIST SSDF)

## 9. Role Model and Governance Implications
- RACI across process areas
- Key roles: CTO, VP Engineering, Product, Design, Architect, SRE, Security, Platform, QE, Engineering Manager, IC
- Governance boards and councils
- Policy-as-code, guardrails, and approval boundaries
- Compliance integration (regulated contexts)

## 10. Final Recommended Canonical Industry Standard
- The 18-area model as reference architecture
- Adoption roadmap: crawl/walk/run
- Prioritization guidance by organization context
- Call for continuous update as practices evolve

## Appendices (in deep-research artifacts, not main report)
- sources.jsonl
- evidence.jsonl
- claims.jsonl
- triangulation.md
- critique.md
- decision-record.md
- handoff.md
- vloop-rollup.json
