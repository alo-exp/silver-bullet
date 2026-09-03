# Research Plan: Canonical SDLC Process Architecture

## Phase 1: SCOPE — Done
Scope documented in `scope.md`. Boundaries, assumptions, and success criteria established.

## Phase 2: PLAN — This Document

### Source Categories
1. **Frameworks & Standards** (high credibility): DORA State of DevOps Reports, NIST SSDF, OWASP SAMM, ISO/IEC 27034, ISO/IEC 25010, ITIL 4, COBIT.
2. **Cloud/Platform Vendor Guidance**: AWS Well-Architected Framework, Azure Well-Architected Framework, Google Cloud Architecture Framework, AWS Builders' Library, Azure DevOps documentation.
3. **Company Engineering Blogs & Handbooks**: Google Engineering Practices, Google SRE books, Microsoft Engineering, Netflix Tech Blog, Spotify Engineering, GitHub Engineering, Atlassian Team Playbook, Shopify Engineering, Cloudflare Blog, LinkedIn Engineering, Uber Engineering, Airbnb Engineering, Stripe Engineering, Meta Engineering.
4. **Open Source / Foundation Guidance**: CNCF TAGs, OpenSSF, OpenTelemetry, Cilium, Backstage, Chromium, Kubernetes community.
5. **Research & Surveys**: DORA (Google Cloud), Stack Overflow Developer Survey, JetBrains State of Developer Ecosystem, McKinsey/Forrester/Gartner (used sparingly, gated for paywalls).

### Query Angles (one fetch batch per angle)
- Angle A: Foundational SDLC / DevOps / DORA / SRE frameworks
- Angle B: Product management, discovery, UX/design at scale
- Angle C: Architecture, platform engineering, IDP, developer experience
- Angle D: Security, privacy, risk, compliance (SSDF, OWASP, DevSecOps)
- Angle E: AI-assisted / agentic software engineering practices and governance
- Angle F: Cross-area measurement, continuous improvement, maintenance/retirement

### Triangulation Strategy
- Core framework claims (e.g., "CI/CD improves deployment frequency"): DORA + vendor docs + company blog.
- Company-specific practices (e.g., "Google uses Blaze for builds"): company source + independent analysis.
- Emerging practices (e.g., agentic coding): vendor research + early-adopter engineering blogs + conference talks.
- Security claims: NIST/OWASP + vendor guidance + incident analyses.

### Subagent Deployment Plan
- Subagent 1 (Frameworks & Foundations): Gather evidence for Process Areas 1, 4, 9, 10, 11, 13.
- Subagent 2 (Product & Design): Gather evidence for Process Areas 2, 3, 5, 16.
- Subagent 3 (Platform & Operations): Gather evidence for Process Areas 6, 7, 8, 12, 14, 15, 17.
- Subagent 4 (AI & Emerging): Gather evidence for Process Area 18 and AI integration across all areas.
Each subagent returns a JSONL evidence file and a brief synthesis.

### Quality Gates
- Minimum 40 sources with average credibility >70/100.
- Each Process Area supported by ≥2 sources.
- Each major claim triangulated where possible.
- Gaps explicitly documented, not invented.

### Risk Mitigation
- **Paywalls**: Prefer publicly available engineering blogs and open frameworks; note when sources are gated.
- **Recency**: Prioritize 2022–2026 sources; foundational frameworks (e.g., SRE books, Well-Architected) may be older but are still authoritative.
- **Bias**: Include critic/alternative perspectives (e.g., critiques of SAFe, platform-engineering anti-patterns).
- **Scope creep**: Stick to reference-model description; avoid implementation tooling detail beyond tool categories.

## Phase 3: RETRIEVE
Launch parallel web fetches for primary sources; index into context-mode knowledge base.

## Phase 4: TRIANGULATE
Cross-reference claims, flag single-source information, assess credibility, document consensus and debate.

## Phase 4.5: OUTLINE REFINEMENT
Adapt report outline based on evidence strength; demote under-supported areas.

## Phase 5: SYNTHESIZE
Build process-area taxonomy, workflow library, dependency map, AI layer, maturity model.

## Phase 6: CRITIQUE
Red-team for unsupported claims, logical gaps, bias, and implementability.

## Phase 7: REFINE
Fill identified gaps with targeted delta-searches.

## Phase 8: PACKAGE
Progressively generate `research_report.md` and all required artifacts.
