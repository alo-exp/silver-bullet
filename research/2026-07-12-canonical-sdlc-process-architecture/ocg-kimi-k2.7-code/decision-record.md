# Decision Record: Canonical SDLC Process Architecture Research

## DR-001: Scope Boundary — 18 Mandated Process Areas
**Decision:** Adopt the 18 Process Areas specified in the research brief as the canonical taxonomy.  
**Rationale:** The brief mandates these areas; they cover the full software-delivery lifecycle and align with major frameworks (DORA, ITIL, NIST SSDF, SRE).  
**Trade-off:** Some areas overlap (e.g., Platform Engineering with Development Environment; Observability with SRE). We document overlaps explicitly rather than merge.

## DR-002: Classification Schema
**Decision:** Tag every workflow as one of: universal, leading-edge, context-dependent, or emerging.  
**Rationale:** Required by brief; helps readers distinguish baseline practice from advanced or unproven practice.  
**Definitions:**
- **Universal:** Practiced by a majority of high-performing organizations; strong multi-source evidence.
- **Leading-edge:** Practiced by top-quartile organizations; evidence from DORA elite performers or advanced practitioners.
- **Context-dependent:** Valuable only in specific contexts (regulated, large-scale, distributed teams, etc.).
- **Emerging:** Early adoption; limited operational evidence; high uncertainty.

## DR-003: Evidence Threshold
**Decision:** Major claims require ≥2 independent sources; single-source claims are flagged and downgraded in confidence.  
**Rationale:** Prevents invention and satisfies quality bar.  
**Exception:** Company-specific operational details (e.g., "Google uses Blaze") may be single-source if the company itself publishes them.

## DR-004: AI-Assisted Practices Inclusion Policy
**Decision:** Include AI/agentic practices only where there is credible operational adoption evidence (DORA research, GitHub Copilot studies, published engineering case studies).  
**Rationale:** Prevents hype-driven invention.  
**Trade-off:** Some exciting AI capabilities are excluded or marked emerging due to insufficient evidence.

## DR-005: Source ID Normalization
**Decision:** Merge subagent evidence source IDs into a single sources.jsonl; add missing IDs inferred from evidence URLs.  
**Rationale:** Subagents used inconsistent prefixes; consistency is required for citation verification.  
**Trade-off:** Some automatically inferred source titles are generic; credibility notes default to "Medium" for subagent-added sources.

## DR-006: Report Generation Strategy
**Decision:** Synthesize subagent outputs into a single coherent research_report.md rather than concatenate.  
**Rationale:** Ensures consistent voice, cross-area dependency mapping, and elimination of contradictions.  
**Trade-off:** Some granular subagent detail is summarized rather than reproduced verbatim.

## DR-007: Deprecated Practices Identification
**Decision:** List deprecated/diminishing practices based on consensus in DORA, SRE, DevOps, and agile literature, not just single critic sources.  
**Rationale:** Avoids declaring practices dead based on fashion.

## DR-008: Maturity Model Granularity
**Decision:** Use a 5-level maturity scale with per-area descriptors and map to minimum/standard/leading-edge tiers.  
**Rationale:** Aligns with CMMI, OWASP SAMM, and DORA capability models; useful for adoption planning.
