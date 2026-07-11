# Canonical SDLC Process Architecture — Multi-Agent Research Brief

**Research date:** 2026-07-12  
**Mode:** ultradeep (AF-DECIDE / FS-SILVER_DEEP_RESEARCH)  
**Agent output directory:** `research/2026-07-12-canonical-sdlc-process-architecture/<YOUR-AGENT-SLUG>/`

---

## Role

You are a Principal Software Engineering Process Architect and industry research analyst. Conduct rigorous deep-research to define a canonical industry-standard software development process based on best practices used by leading software organizations as of mid-2026.

## Objective

Evidence-based reference model organized into **Process Areas** and **Workflows** within each Process Area. Reflect what high-performing organizations actually practice at scale.

## Core requirements

- Cover practices from: Google, Microsoft, Amazon/AWS, Meta, Apple, Netflix, Spotify, Stripe, GitHub, Atlassian, Shopify, Cloudflare, LinkedIn, Uber, Airbnb, and comparable leaders.
- **Primary sources:** engineering blogs/handbooks, conference talks, DORA, NIST SSDF, OWASP, CNCF/OpenSSF/OpenTelemetry, industry surveys.
- Distinguish: universal / leading-edge / context-dependent / emerging practices.
- Security, reliability, quality, DevEx, platform engineering, governance, delivery performance are first-class.
- AI-assisted/agentic practices only with credible operational adoption evidence.
- True process architecture with nested workflows — **no invented areas without evidence**.

## Minimum Process Areas (all required)

1. Strategy Portfolio & Product Direction
2. Discovery Requirements & Product Definition
3. UX & Product Design
4. Architecture & Technical Design
5. Planning & Work Management
6. Development Environment & Toolchain
7. Software Implementation
8. Code Review & Knowledge Sharing
9. Testing QE & Verification
10. Build Integration & Artifact Management
11. CI Release & Deployment
12. Platform Engineering & IDP
13. Security Privacy Risk & Compliance
14. Reliability Operations & SRE
15. Observability & Production Feedback
16. Measurement DevEx & Continuous Improvement
17. Maintenance Evolution & Retirement
18. AI-Assisted / Agentic Software Engineering

## Per Process Area (required fields)

- definition, purpose, mid-2026 relevance
- inputs, workflows, outputs, dependencies
- metrics/gates/exit criteria
- pitfalls/mitigations
- context variations (startup vs enterprise, regulated vs consumer, etc.)

## Per Workflow (required fields)

- name, objective, classification (universal / leading-edge / context-dependent / emerging)
- triggers, preconditions, inputs
- steps, decision points
- human-AI collaboration patterns
- roles/RACI
- tool categories
- outputs
- quality/security/completion criteria
- automation opportunities
- approval boundaries, escalation paths
- KPIs
- anti-patterns
- minimum / standard / leading-edge implementation tiers

## Required output structure

Write `research_report.md` in your agent output directory with these sections:

1. Executive Summary
2. Research Method and Evidence Base
3. Canonical Process-Area Taxonomy
4. Full Workflow Library
5. Cross-Area Dependency and Feedback Map
6. AI-Integration Layer
7. Deprecated or Diminishing Practices
8. Maturity Model
9. Role Model and Governance Implications
10. Final Recommended Canonical Industry Standard

## Deep-research artifacts (also write to your agent directory)

```
scope.md
research-plan.md
sources.jsonl       # one JSON object per line: {id, url, title, type, date, credibility}
evidence.jsonl      # {id, source_id, span, claim}
triangulation.md
outline.md
claims.jsonl
critique.md
decision-record.md
handoff.md
vloop-rollup.json
run_manifest.json
```

## Research method (mandatory)

1. Use web search and fetch tools for **real** primary sources — do not hallucinate citations.
2. Triangulate claims across ≥2 independent sources for major assertions.
3. Tag each practice: universal | leading-edge | context-dependent | emerging.
4. Record source URLs in `sources.jsonl` with credibility notes.
5. If a process area lacks strong evidence, say so explicitly — do not invent.

## Quality bar

Enterprise handbook / SDLC reference model rigor. Suitable for CTO/VP Engineering adoption planning.
