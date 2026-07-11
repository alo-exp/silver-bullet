# Research Plan — Canonical SDLC Process Architecture

**Research ID:** DR-SDLC-CANON-2026-07-12
**Mode:** ultradeep
**Plan version:** 1.0

---

## Phase 1 — SCOPE  (DONE)

Artifact: `scope.md` — finalized with question, in/out of scope, assumptions, source authority hierarchy, success criteria, risks.

## Phase 2 — PLAN (current)

Artifact: `research-plan.md` (this file) and `outline.md` (skeleton report outline).

### Deliverables inventory

| File | Phase | Status |
|------|-------|--------|
| scope.md | 1 | DONE |
| research-plan.md | 2 | IN PROGRESS |
| outline.md | 2 | IN PROGRESS |
| sources.jsonl | 3 | PENDING |
| evidence.jsonl | 3-4 | PENDING |
| claims.jsonl | 4-7 | PENDING |
| triangulation.md | 4 | PENDING |
| research_report.md | 5-7 | PENDING |
| critique.md | 6 | PENDING |
| decision-record.md | 6-7 | PENDING |
| handoff.md | 8 | PENDING |
| vloop-rollup.json | 8 | PENDING |
| run_manifest.json | 8 | DONE (initial) |

## Phase 3 — RETRIEVE (evidence loop per Process Area)

Strategy: for each Process Area, execute a **retrieve → index → write evidence → refine outline → draft** loop. Process Areas are not equally evidence-rich, so loops are sized accordingly.

### Process Area evidence map (initial planning — will be revised during retrieval)

| PA | Title | Expected primary sources (initial hypothesis) | Difficulty |
|----|-------|-----------------------------------------------|-----------|
| PA-01 | Strategy & Portfolio | Amazon PR/FAQ, Spotify model, AWS Working Backwards, Shape Up, Marty Cagan, John Cutler | Medium — well-documented |
| PA-02 | Discovery & Requirements | Marty Cagan, Continuous Discovery (Teresa Torres), Shape Up, User Story Mapping (Patton) | Medium — well-documented |
| PA-03 | UX & Product Design | Google HEART, NN/g, Airbnb Design, Figma, IDEO, d.school | High — broad discipline |
| PA-04 | Architecture & Technical Design | AWS Well-Architected, Microsoft Azure Architecture Framework, Google SRE Book, RFC culture (Google/Meta/Stripe) | Medium — well-documented |
| PA-05 | Planning & Work Management | Shape Up, Shape Up variants (Linear, GitHub Projects), Spotify model, SAFe (critique), Spotless/Shape Up hybrid, OKR | Medium — well-documented |
| PA-06 | Dev Environment & Toolchain | GitHub Codespaces, Gitpod, Google monorepo, InnerSource, devcontainers | High — varies by stack |
| PA-07 | Software Implementation | Trunk-based dev, semantic versioning, conventional commits, feature flags (LaunchDarkly, Split) | Medium — well-documented |
| PA-08 | Code Review & Knowledge Sharing | Google's Code Review guidelines, Phabricator, Critique (Stripe), Microsoft Research, Conventional Comments | Medium — well-documented |
| PA-09 | Testing & QE | Google Testing Blog, Microsoft Test Framework, Spotify Model, Mocks Aren't Stubs (Fowler), Test Pyramid (Cohn), Property-based testing, Contract testing (Pact) | Medium — well-documented |
| PA-10 | Build & Artifact Mgmt | Bazel, Pants, Buck, Nx, Artifactory, OCI artifacts, SLSA | Medium — well-documented |
| PA-11 | CI / Release / Deployment | Continuous Delivery (Humble/Farley), DORA metrics, GitHub Actions, GitLab CI, ArgoCD, Flagger, Progressive Delivery, Spinnaker | High — diverse |
| PA-12 | Platform Engineering / IDP | Team Topologies, Backstage (Spotify), Humanitec, Internal Developer Portals (Spotify/Netflix/LinkedIn case studies), CNCF Platforms TAG | High — emerging |
| PA-13 | Security, Privacy, Risk, Compliance | NIST SSDF (SP 800-218), OWASP SAMM/ASVS, SLSA, SOC 2, ISO 27001, FedRAMP, supply chain, Sigstore/Cosign, SBOM/CycloneDX, DevSecOps | High — critical, well-documented |
| PA-14 | Reliability & SRE | Google SRE Book, SRE Workbook, Microsoft SRE, Netflix Chaos Engineering, AWS Well-Architected Reliability pillar, error budgets | High — well-documented |
| PA-15 | Observability | OpenTelemetry, Google SRE Ch 6, Honeycomb, Datadog, USE method (Brendan Gregg), RED method (Tom Wilkie), eBPF | High — emerging |
| PA-16 | Measurement, DevEx, Continuous Improvement | DORA, SPACE, DevEx quadrant (Forrester/GitHub), DX (DX/Forrester), Developer Productivity (McKinsey) | High — emerging |
| PA-17 | Maintenance, Evolution, Retirement | EOL policies, deprecation frameworks, Microsoft Modern Lifecycle, semantic versioning deprecation, sunset headers | Medium — under-documented |
| PA-18 | AI-Assisted / Agentic SDLC | GitHub Copilot metrics, Cursor, Devin (Cognition), Claude Code, OpenAI Codex, agent benchmarks (SWE-bench, aider), Anthropic/Meta/Google agent papers, internal adoption reports | Very high — emerging, claim-risky |

### Retrieval batches (parallel-safe, I/O bound)

Round 1 (foundation — standards & surveys):
- DORA State of DevOps report 2024 & 2025
- NIST SSDF SP 800-218
- OWASP SAMM v2
- CNCF Platforms TAG landscape
- OpenSSF SLSA specification
- OpenTelemetry documentation

Round 2 (engineering handbooks):
- Google Engineering Practices (code review)
- Google SRE Book / Workbook
- Microsoft Engineering Playbook / DevOps journey
- AWS Well-Architected Framework
- AWS Builder's Library
- Atlassian engineering handbook / postmortem culture

Round 3 (named-org specific):
- Spotify engineering blog (Backstage, R&D model)
- Stripe engineering blog (sessions, design docs, code review)
- GitHub engineering blog (Codespaces, Copilot adoption)
- Netflix Tech Blog (chaos engineering, observability)
- Cloudflare engineering blog
- LinkedIn Engineering
- Uber Engineering
- Airbnb Engineering
- Shopify engineering (monorepo, deployment)

Round 4 (PA-18 evidence — AI-Assisted):
- GitHub Copilot enterprise metrics
- Anthropic / OpenAI / Google DeepMind agent papers with operational results
- SWE-bench / SWE-bench Verified benchmarks
- Public engineering blog posts on Copilot/Cursor/Claude Code adoption at scale
- McKinsey State of AI reports
- Stack Overflow Developer Survey (AI section)

Round 5 (cross-area integration):
- Team Topologies book + blog
- Accelerate book (Forsgren, Humble, Kim)
- DORA / SPACE / DevEx research papers
- Continuous Delivery (Humble/Farley)
- Shape Up (Basecamp)
- Project to Product (Skurla)

## Phase 4 — TRIANGULATE

For every major claim, identify ≥2 independent sources. If a claim cannot be triangulated, it is either:
- (a) Marked as single-source with explicit caveat, or
- (b) Demoted to a note in decision-record.md, or
- (c) Removed.

## Phase 4.5 — OUTLINE REFINEMENT

After retrieval, refine outline.md to reflect evidence density per section. Sections with thin evidence get reduced; sections with rich evidence can be expanded.

## Phase 5-7 — SYNTHESIZE / CRITIQUE / REFINE

Draft research_report.md in passes:
- Pass 1: Process Area definitions, inputs/outputs, workflows (per PA).
- Pass 2: Cross-area dependency map, AI-Integration Layer, Deprecated Practices.
- Pass 3: Maturity model, role model, recommended canonical standard.
- Pass 4: Critique (internal red-team) and refine.

critique.md will document:
- Claims with thin evidence.
- Possible biases in source selection.
- Areas where mid-2026 evidence is genuinely sparse.
- Counter-arguments and steelman positions.

decision-record.md will document:
- Why each Process Area is in the taxonomy.
- Why each workflow is universal/leading-edge/context-dependent/emerging.
- Rejected alternatives and why.

## Phase 8 — PACKAGE

Final delivery: research_report.md, all 13 artifacts, run_manifest.json with timestamps and evidence counts.

---

## Risk management

| Risk | Mitigation |
|------|-----------|
| Retrieval cost (web fetch) | Batch 5-8 URLs in parallel; cache results in knowledge base; rely on indexed content for follow-up queries. |
| Hallucination | Strict evidence.jsonl discipline; no claim without source; no source without credibility note. |
| AI-evidence weak | PA-18 limited to claims with public operational evidence; explicit "emerging" tag; honest gaps. |
| Time overrun | Quality bar > completeness; if a section is thin, mark it thin rather than padding. |
| Bias | Include European/Asian sources; standards bodies; include both Big Tech and smaller engineering orgs. |
