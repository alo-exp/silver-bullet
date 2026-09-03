# Outline — Canonical SDLC Process Architecture (mid-2026)

This is the working outline. Sections will be expanded/refined based on retrieval evidence.

---

# 1. Executive Summary (200-400 words)

- The case for capability-based (not stage-based) SDLC architecture.
- 18 Process Areas, ~110 workflows.
- Universal core + leading-edge accelerators + emerging AI layer.
- Source base: 40-80 primary sources, ≥2 per major claim.
- Maturity tiers: minimum / standard / leading-edge.
- Mid-2026 inflection: AI-Assisted/Agentic layer is now a first-class Process Area (PA-18), not a sub-topic.
- Adoption is bifurcating: enterprises formalize governance; product engineering orgs push agentic autonomy.
- Read this report as: a reference model, not a methodology.

# 2. Research Method and Evidence Base

- 2.1 Research question, scope, mode
- 2.2 Source authority hierarchy
- 2.3 Triangulation protocol
- 2.4 Source inventory (high-level: count by tier, by year, by org)
- 2.5 Limitations of the evidence base (gaps, biases)

# 3. Canonical Process-Area Taxonomy

18 Process Areas, each with: definition, purpose, mid-2026 relevance, primary inputs/outputs, primary dependencies, primary metrics/gates, pitfalls & mitigations, context variations.

- 3.1 PA-01 — Strategy, Portfolio & Product Direction
- 3.2 PA-02 — Discovery, Requirements & Product Definition
- 3.3 PA-03 — UX & Product Design
- 3.4 PA-04 — Architecture & Technical Design
- 3.5 PA-05 — Planning & Work Management
- 3.6 PA-06 — Development Environment & Toolchain
- 3.7 PA-07 — Software Implementation
- 3.8 PA-08 — Code Review & Knowledge Sharing
- 3.9 PA-09 — Testing, QE & Verification
- 3.10 PA-10 — Build, Integration & Artifact Management
- 3.11 PA-11 — CI, Release & Deployment
- 3.12 PA-12 — Platform Engineering & IDP
- 3.13 PA-13 — Security, Privacy, Risk & Compliance
- 3.14 PA-14 — Reliability, Operations & SRE
- 3.15 PA-15 — Observability & Production Feedback
- 3.16 PA-16 — Measurement, DevEx & Continuous Improvement
- 3.17 PA-17 — Maintenance, Evolution & Retirement
- 3.18 PA-18 — AI-Assisted / Agentic Software Engineering

# 4. Full Workflow Library

For each Process Area, list nested workflows. Each workflow has all 13 required fields.

(Template:)

## PA-XX.YY — Workflow Name

- **Objective:** ...
- **Classification:** universal | leading-edge | context-dependent | emerging
- **Triggers:** ...
- **Preconditions:** ...
- **Inputs:** ...
- **Steps / Decision points:** ...
- **Human-AI collaboration:** ...
- **Roles / RACI:** ...
- **Tool categories:** ...
- **Outputs:** ...
- **Quality / security / completion criteria:** ...
- **Automation opportunities:** ...
- **Approval boundaries / escalation:** ...
- **KPIs:** ...
- **Anti-patterns:** ...
- **Tiers:** minimum / standard / leading-edge

(110+ workflow stubs total, organized under their parent PA.)

# 5. Cross-Area Dependency and Feedback Map

- 5.1 Forward dependencies (e.g., PA-04 depends on PA-13 inputs; PA-11 consumes PA-10 outputs).
- 5.2 Feedback loops (e.g., PA-15 incidents feed PA-16 metrics; PA-16 metrics feed PA-01 strategy).
- 5.3 Critical path / minimum viable loop: PA-04 → PA-07 → PA-09 → PA-10 → PA-11 → PA-15 → PA-16 → PA-01.
- 5.4 Capability layers: foundation (PA-06, PA-10, PA-13) → delivery loop (PA-05, PA-07, PA-08, PA-09, PA-11) → feedback & improvement (PA-14, PA-15, PA-16) → direction (PA-01, PA-02, PA-03, PA-04) → sustainability (PA-12, PA-17, PA-18).

# 6. AI-Integration Layer

- 6.1 Where AI touches each Process Area (one-line per PA, citation-backed).
- 6.2 PA-18 detailed treatment: AI code generation, AI test generation, AI code review, AI incident response, AI observability, agentic workflows, agent governance.
- 6.3 Adoption evidence at mid-2026: GitHub Copilot enterprise metrics, Cursor, Devin, Claude Code, Codex.
- 6.4 Governance and risk: model risk, IP, data privacy, security of model supply chain.
- 6.5 Decision framework: when to adopt AI in each workflow.

# 7. Deprecated or Diminishing Practices

- Annual / quarterly release trains (vs continuous delivery).
- Long-lived feature branches (vs trunk-based development).
- QA hand-off as a separate phase (vs integrated QE).
- Manual test case authoring (vs model-based + AI-generated).
- ITIL change advisory boards as primary gate (vs progressive delivery + automated policy).
- Heavyweight stage-gate governance (vs Shape Up / continuous discovery).
- Annual performance reviews tied to delivery (vs SPACE / DORA continuous metrics).
- Waterfall documentation in spirit (vs lightweight RFCs / ADRs).
- Big-bang migrations (vs strangler-fig / evolutionary architecture).

# 8. Maturity Model

- 8.1 Tier 0 — Ad hoc / crisis-driven
- 8.2 Tier 1 — Minimum (basic CI, basic testing, basic change control)
- 8.3 Tier 2 — Standard (continuous delivery, automated tests, code review, incident management)
- 8.4 Tier 3 — Leading-edge (platform engineering, IDP, AIOps, agentic SDLC)
- 8.5 Tier 4 — Pioneering (autonomous operations, AI-driven engineering, full feedback loops)
- 8.6 Tier-progression: typical gaps by PA, common blockers, sequence of investments.

# 9. Role Model and Governance Implications

- 9.1 Roles: product manager, tech lead/principal engineer, staff engineer, platform engineer, SRE, security engineer, design engineer, AI/ML engineer, developer experience engineer, QE engineer, engineering manager, director/VP/CTO.
- 9.2 Team Topologies mapping: stream-aligned, enabling, complicated-subsystem, platform.
- 9.3 Governance: lightweight review boards, RFC culture, ADRs, security council, platform council, AI ethics committee.
- 9.4 RACI: standard RACI for each Process Area (one-line).

# 10. Final Recommended Canonical Industry Standard

- 10.1 The recommended canonical model: 18 Process Areas, ~110 workflows.
- 10.2 How to adopt: assessment, sequencing, quick wins, common pitfalls.
- 10.3 Adoption patterns by org type: startup, scale-up, enterprise, regulated.
- 10.4 The mid-2026 inflection: AI as a first-class PA.
- 10.5 Closing: the reference model is convergent across orgs, but the path is context-dependent.

---

# Appendix A — Sources (linked from sources.jsonl)

# Appendix B — Evidence Ledger (linked from evidence.jsonl)

# Appendix C — Claims Ledger (linked from claims.jsonl)

# Appendix D — Decision Record (linked from decision-record.md)

# Appendix E — Critique (linked from critique.md)

# Appendix F — Glossary
