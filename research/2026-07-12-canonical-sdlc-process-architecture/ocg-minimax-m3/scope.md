# Research Scope — Canonical SDLC Process Architecture

**Research ID:** DR-SDLC-CANON-2026-07-12
**Mode:** ultradeep (8+ phases, 20-45 min)
**Agent slug:** ocg-minimax-m3
**Started:** 2026-07-11T19:53:16Z
**Status:** scope-finalized

---

## 1. Question

What does a **canonical, evidence-based, industry-standard software development process** look like in mid-2026, organized into Process Areas and nested Workflows that reflect the actual practices of high-performing software organizations (Google, Microsoft, Amazon/AWS, Meta, Apple, Netflix, Spotify, Stripe, GitHub, Atlassian, Shopify, Cloudflare, LinkedIn, Uber, Airbnb, and comparable leaders)?

The deliverable is a reference model — not a methodology pitch — suitable for adoption planning by CTOs and VP Engineering at organizations ranging from startups to large regulated enterprises.

## 2. In Scope

- 18 mandatory Process Areas (PA-01 through PA-18, see brief).
- Nested workflows within each Process Area (universal / leading-edge / context-dependent / emerging).
- Inputs, outputs, metrics, gates, pitfalls, anti-patterns, context variations.
- Human-AI collaboration patterns, with AI claims required to be backed by credible operational adoption.
- Cross-area dependency / feedback relationships.
- Maturity model (minimum / standard / leading-edge tiers).
- Role model and governance implications.
- Deprecated or diminishing practices.
- Triangulation of claims across ≥2 independent primary sources.

## 3. Out of Scope

- **Methodology advocacy.** This is a reference model, not a methodology (SAFe, LeSS, Scrum@Scale) recommendation. Methodologies are cited as inputs to process design but the report is methodology-agnostic.
- **Tool vendor selection.** Categories are described, specific products are only mentioned as canonical examples of a category.
- **Cost / pricing analysis** of any commercial tool.
- **Pure academic software-engineering research** that has not crossed into operational adoption.
- **Speculative AI claims** without primary-source evidence. AI-Assisted/Agentic SDLC (PA-18) is included only where credible operational adoption is documented.
- **Outsourcing / offshoring governance** as a primary topic; mentioned only where it materially affects a process area.
- **Hardware / firmware / embedded** process nuances (covered only as context variations).
- **Non-engineering product functions** (sales, marketing, finance, legal) other than the handoffs they have with engineering.

## 4. Assumptions

1. **Audience is technical leadership** (CTO, VP Eng, directors, principal engineers) at organizations of 50–50,000 engineers.
2. **Mid-2026 reference point** means evidence up to and including the most recent 12 months is most relevant; older evidence is valid for stable universal practices.
3. **"Canonical" = convergent across ≥3 high-performing organizations**, not novel or vendor-driven.
4. **Triangulation rule:** every major assertion must be supported by ≥2 independent primary sources, or explicitly flagged as a single-source claim with a "single-source" note.
5. **AI claims must be operationally adopted**, not aspirational. Blog posts announcing AI capabilities without shipped integration do not qualify.
6. **Process Areas are not stages** in a waterfall; they are ongoing capabilities with feedback loops. The taxonomy is capability-based, not temporal.
7. **"Workflow" = a recurring unit of work** with triggers, decision points, and exit criteria, owned by an identified role.
8. **Regulated industries** (finance, healthcare, public sector) are treated as a first-class context variation, not a footnote.

## 5. Mode & Time Budget

- **Mode:** ultradeep (8 phases minimum).
- **Target artifact size:** 18 process areas × ~6 workflows average = ~110 workflow definitions + cross-area analysis.
- **Evidence budget:** 40–80 primary sources, ≥2 per major claim.
- **Hard time budget:** wall-clock time will be tracked in run_manifest.json. The report will be packaged as a complete deliverable even if iteration is limited.

## 6. Source Authority Hierarchy

| Tier | Source type | Treatment |
|------|-------------|-----------|
| 1 | Engineering blogs/handbooks from named leading orgs | Highest authority for "what they do" |
| 2 | Conference talks from named leading orgs (QCon, SREcon, KubeCon, Strange Loop, etc.) | Highest authority for emerging practices |
| 3 | Standards bodies (NIST SSDF, ISO/IEC, OWASP, CNCF, OpenSSF, OpenTelemetry) | Highest authority for security/compliance |
| 4 | Industry surveys (DORA, State of DevEx, Stack Overflow, JetBrains, GitHub Octoverse) | Highest authority for adoption baselines |
| 5 | Peer-reviewed academic with operational citation | Authoritative for foundational concepts |
| 6 | Vendor whitepapers / consultancy frameworks | Treated as input, not authority |
| 7 | Single-source claims | Flagged explicitly with credibility note |

## 7. Success Criteria

- All 18 Process Areas present with required fields.
- All 10 required report sections present.
- ≥40 primary sources in sources.jsonl.
- ≥2 independent sources for each major claim (PA-18 AI claims require Tier 1 or Tier 2 evidence of operational adoption).
- All files in the brief's artifact list present.
- Quality-gates pass: every claim has evidence, every evidence has a source, every source has a credibility note.

## 8. Risks

- **Hallucination risk:** high. Mitigated by evidence.jsonl requirement and triangulation.
- **Volume risk:** ultradeep scope × 18 process areas is large. Mitigated by phased evidence loops (retrieve → synthesize per area, not all-at-once).
- **AI-evidence risk:** PA-18 is genuinely new. Mitigated by strict Tier 1/2 evidence requirement and explicit "emerging" tagging.
- **Bias risk:** named-org list skews to US/Big-Tech. Mitigated by including European/Asian sources where relevant (Spotify, Shopify, Grab, Alibaba, ByteDance) and standards bodies.
