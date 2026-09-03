# Triangulation Report: Canonical SDLC Process Architecture

## Method
Each major assertion in the research report was checked against ≥2 independent sources where possible. Sources were categorized as frameworks/standards, vendor/cloud guidance, company engineering handbooks/blogs, and open-source foundations. Claims were tagged:
- **Triangulated:** 3+ independent sources
- **Supported:** 2 independent sources
- **Single-source:** only 1 source available; treated as context-dependent or emerging
- **Inferred:** logically derived from multiple sources but not directly quoted

## Major Assertions and Source Independence

| # | Assertion | Sources | Status |
|---|-----------|---------|--------|
| 1 | Continuous integration/delivery improves delivery performance and stability. | DORA capabilities; Martin Fowler CI; continuousdelivery.com; GitLab DevOps | Triangulated |
| 2 | Code review is a universal quality and knowledge-sharing practice. | Google Engineering Practices; GitHub engineering; GitLab handbook; DORA | Triangulated |
| 3 | SRE practices (SLOs, error budgets, blameless postmortems) improve reliability. | Google SRE Book/Workbook; AWS Reliability Pillar; Google DevOps & SRE blog | Triangulated |
| 4 | Test automation aligned with the test pyramid is a leading quality practice. | Google Testing Blog (test sizes); Martin Fowler Test Pyramid; OWASP SAMM verification | Triangulated |
| 5 | Security must be integrated early (shift-left/DevSecOps). | NIST SSDF; OWASP SAMM; Microsoft SDL; OpenSSF Best Practices | Triangulated |
| 6 | Platform engineering / IDPs improve developer experience and reduce cognitive load. | CNCF Platforms White Paper; Spotify Backstage; internaldeveloperplatform.org; Humanitec | Triangulated |
| 7 | Observability (OpenTelemetry) enables production feedback and faster incident response. | OpenTelemetry docs; Google SRE; AWS Well-Architected; DORA | Triangulated |
| 8 | DORA metrics (deployment frequency, lead time, change-fail rate, MTTR) predict performance. | DORA research/guides; DORA capabilities; GitHub Octoverse | Triangulated |
| 9 | Trunk-based development with feature flags reduces integration risk. | DORA trunk-based development; Martin Fowler feature toggles; Google Engineering Practices | Triangulated |
| 10 | AI-assisted coding improves productivity but requires governance and quality controls. | GitHub Copilot impact study; DORA AI tensions; Anthropic effective agents; NIST AI RMF | Triangulated |
| 11 | Product discovery and user research reduce waste and align products to customer value. | SVPG Inspired; Nielsen Norman Group UX methods; Atlassian product management | Supported |
| 12 | Architecture decisions should be recorded (ADRs) and reviewed. | Google Engineering Practices; ThoughtWorks evolutionary architecture; AWS Well-Architected | Supported |
| 13 | Incident postmortems and learning cultures improve reliability. | Google SRE postmortem culture; AWS Reliability Pillar; Google SRE eliminating toil | Triangulated |
| 14 | Explicit technical-debt management and strangler-fig modernization reduce legacy risk. | Martin Fowler Strangler Fig; Spotify engineering; ThoughtWorks | Supported |
| 15 | Design systems improve UX consistency and development velocity. | Nielsen Norman Group; Atlassian design system guidance | Supported |
| 16 | Supply-chain security (SLSA, SBOM, signed artifacts) is becoming standard. | OpenSSF SLSA; OpenSSF Best Practices Badge; NIST SSDF | Triangulated |
| 17 | Regulated contexts require traceability, auditability, and control gates. | NIST SSDF; OWASP ASVS; Microsoft SDL | Triangulated |
| 18 | Retrospectives and continuous improvement cycles are universal agile practices. | Atlassian Team Playbook; DORA measurement frameworks; Spotify engineering | Triangulated |

## Single-Source or Limited-Evidence Areas
The following topics are reported but flagged as context-dependent or emerging due to limited independent evidence:
- **AI-assisted product discovery and requirements analysis:** primarily vendor case studies and early-adopter blogs.
- **AI-generated test quality and maintainability:** generation is well-evidenced; long-term quality is not.
- **Multi-agent coordination in production SDLC:** theoretical and early-adopter only (Spotify, Anthropic, GitHub agentic workflows).
- **SLSA Level 3+ artifact provenance in mass production:** strong specification, limited published production adoption data.
- **AI-assisted architecture decisions:** emerging; no systematic studies found.
- **Skill atrophy from AI assistance:** discussed in DORA AI tensions but longitudinal studies absent.

## Source Credibility Notes
- **High credibility (>80/100):** NIST, OWASP, DORA/Google Cloud, Google SRE books, major cloud Well-Architected frameworks, established company engineering handbooks.
- **Medium-high credibility (60-80):** CNCF whitepapers, foundation guidance (OpenSSF, OpenTelemetry), reputable company engineering blogs.
- **Medium credibility (40-60):** Vendor-specific case studies, community sites (platformengineering.org), subagent-inferred sources.
- **Low credibility (<40):** Not used for core claims.

## Contradictions and Debates
- **Agile scaling frameworks (SAFe vs. Spotify model):** Evidence favors autonomous, outcome-oriented team structures over heavy process frameworks, but SAFe remains prevalent in large enterprises. Classified as context-dependent.
- **Monolith vs. microservices:** ThoughtWorks and AWS guidance emphasize "start simple, evolve"; microservices are leading-edge/context-dependent, not universal.
- **AI code assistants:** Productivity gains are well-supported; impact on code quality, security, and skill development is debated and emerging.

## Confidence Summary
- Overall confidence in the 18-area taxonomy: **High**
- Confidence in universal workflow recommendations: **High**
- Confidence in leading-edge workflow recommendations: **Medium-High**
- Confidence in emerging AI/agentic workflow recommendations: **Medium** (rapidly evolving, limited longitudinal evidence)
