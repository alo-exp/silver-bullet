# Decision Record

## DR-001: Process Area Scope
- **Decision:** Include 18 process areas as specified — no additions, no removals
- **Rationale:** Requirements mandate these 18 areas; AI-Assisted/Agentic SWE included as its own area rather than cross-cutting concern to highlight emerging practices
- **Alternatives considered:** Cross-cutting AI integration into each area (rejected: reduces visibility of AI-specific maturity)
- **Date:** 2026-07-12

## DR-002: Source Credibility Framework
- **Decision:** Five-tier classification: PRIMARY / HIGH / MEDIUM / REFERENCE / CONTEXTUAL
- **Rationale:** Distinguishes peer-reviewed research (DORA, NIST) from engineering blogs (Google, GitHub) from surveys from reference standards
- **Date:** 2026-07-12

## DR-003: Practice Classification Tags
- **Decision:** Four categories: universal / leading-edge / context-dependent / emerging
- **Rationale:** Universal = practiced by >50% of high-performing orgs with >2 evidence sources; leading-edge = >2 sources but <50% adoption; context-dependent = varies by org type; emerging = <1 year evidence
- **Date:** 2026-07-12

## DR-004: Workflow Depth
- **Decision:** Per-workflow fields as specified (name, objective, classification, triggers, preconditions, inputs, steps, RACI, KPIs, anti-patterns, 3-tier implementation)
- **Rationale:** Maximum utility for CTO/VP adoption planning
- **Date:** 2026-07-12

## DR-005: AI Claims Evidence Standard
- **Decision:** Only include AI practices with ≥1 credible primary source showing operational adoption at scale (not vendor marketing or pure speculation)
- **Rationale:** Prevents hype contamination; many agentic AI claims lack production evidence
- **Date:** 2026-07-12

## DR-006: Company Coverage Selection
- **Decision:** Google, Microsoft, Amazon/AWS, Meta, Apple, Netflix, Spotify, Stripe, GitHub, Atlassian, Shopify, Cloudflare, LinkedIn, Uber, Airbnb
- **Rationale:** Required by spec; these 15 represent diverse SDLC challenges (consumer, enterprise, infrastructure, payments)
- **Date:** 2026-07-12
