# Research Scope: Canonical SDLC Process Architecture

## Research Question
What is the canonical, evidence-based software development lifecycle (SDLC) process architecture used by leading software organizations as of mid-2026, expressed as a taxonomy of Process Areas and nested Workflows?

## Mode
Ultradeep (AF-DECIDE / FS-SILVER_DEEP_RESEARCH). Target: enterprise handbook / SDLC reference-model rigor suitable for CTO/VP Engineering adoption planning.

## In Scope
- All 18 mandated Process Areas:
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
- Per-area definition, inputs/workflows/outputs, metrics/gates, pitfalls/mitigations, context variations.
- Per-workflow name, objective, classification (universal / leading-edge / context-dependent / emerging), triggers, preconditions, inputs, steps, decision points, human-AI collaboration patterns, roles/RACI, tool categories, outputs, quality/security/completion criteria, automation opportunities, approval boundaries, escalation paths, KPIs, anti-patterns, minimum/standard/leading-edge tiers.
- Primary sources from Google, Microsoft, Amazon/AWS, Meta, Apple, Netflix, Spotify, Stripe, GitHub, Atlassian, Shopify, Cloudflare, LinkedIn, Uber, Airbnb, DORA, NIST SSDF, OWASP, CNCF/OpenSSF/OpenTelemetry, and industry surveys.
- Cross-area dependency map, AI-integration layer, deprecated/diminishing practices, maturity model, role/governance implications.

## Out of Scope
- Vendor product comparisons or procurement recommendations.
- Detailed financial analysis or market sizing.
- Organization-specific change-management playbooks (the output is a reference model, not an implementation plan for a specific firm).
- Source code or tool configuration artifacts.

## Assumptions to Validate
1. The 18 Process Areas represent a near-complete, mutually intelligible taxonomy (may need to note overlaps).
2. Practices can be meaningfully classified as universal, leading-edge, context-dependent, or emerging.
3. Sufficient public primary-source material exists for each area to avoid invention.
4. AI-assisted/agentic practices have reached credible operational adoption in at least some leading organizations.

## Success Criteria
- `research_report.md` contains all 10 required sections and covers all 18 Process Areas.
- `sources.jsonl` contains ≥40 credible sources with URLs, dates, and credibility notes.
- `evidence.jsonl` contains ≥120 claim-level spans tied to source IDs.
- Each major claim is triangulated across ≥2 independent sources where possible; single-source claims are flagged.
- All required deep-research artifacts are present and coherent.
