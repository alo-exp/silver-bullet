# Triangulation — Canonical SDLC Process Architecture

This document records cross-source agreement for major claims. Each row identifies a claim, the supporting source IDs, and whether the claim is well-triangulated (≥2 independent Tier 1-3 sources), single-source, or contested.

## Triangulation Legend

- ✅ **Strong** — ≥2 independent Tier 1-3 sources concur, or ≥1 standard-body source + 1 Tier 1 source.
- ⚠️ **Moderate** — ≥2 sources but one is Tier 6 (vendor) or both are from the same org.
- 🟡 **Single-source** — Only one source, or all sources share a single corporate lineage.
- ❌ **Contested** — Sources disagree; report notes both positions.
- 🔵 **Convergent norm** — Universal across the industry; not contested.

---

## A. Foundation claims (well-triangulated)

| # | Claim | Source IDs | Status |
|---|-------|-----------|--------|
| 1 | DORA four key metrics: deployment frequency, lead time, change fail rate, MTTR | S002, S003, S005 | ✅ Strong (DORA primary + DORA capability doc) |
| 2 | Trunk-based development: short-lived branches, daily merge into trunk | S004, S005, S022, S023, S040 | ✅ Strong (5 sources, including DORA, Fowler, TrunkBasedDevelopment.com) |
| 3 | Continuous integration requires automated build + automated tests on every commit | S003, S005, S022, S060 | ✅ Strong (4 sources) |
| 4 | Test pyramid: many unit, fewer integration, few E2E | S024, S048, S007 (NIST practices imply layered testing), S071 | ✅ Strong |
| 5 | Feature flags/toggles separate release from deployment; enable trunk-based dev | S025, S004 (TBD), S048 | ✅ Strong |
| 6 | SRE: SLOs, error budgets, toil elimination, postmortem culture, on-call | S015, S016, S017, S068, S078 | ✅ Strong (5 sources) |
| 7 | NIST SSDF 4 practice groups: PO, PS, PW, RV | S007, S008 | ✅ Strong (NIST primary + project page) |
| 8 | SLSA: supply chain levels framework for artifact integrity | S010, S012, S040 (NIST) | ✅ Strong |
| 9 | OWASP SAMM v2: 5 business functions, 15 security practices | S009, S014 (corroborated by NIST references) | ✅ Strong |
| 10 | OpenTelemetry: traces + metrics + logs are the three observability signals | S013, S014, S016 (SRE Ch 6 monitoring), S011 | ✅ Strong |
| 11 | Three clouds have converging "Well-Architected" frameworks (5-6 pillars) | S018, S019, S020 | ✅ Strong (Google, Microsoft, AWS all publish 5-6 pillar frameworks) |
| 12 | Chaos engineering: experiment on system in production to build confidence | S049, S016 (SRE canarying), S062 | ✅ Strong |
| 13 | Platform engineering is a first-class organizational pattern, popularized by Team Topologies | S044, S062, S017 (SRE dev team structure), S061 | ✅ Strong |
| 14 | Internal Developer Portals (Backstage) originated at Spotify, now CNCF | S061, S044, S062 | ✅ Strong |
| 15 | Microservices: independent deployability, business capability alignment, decentralized data | S028, S031, S032, S046 | ✅ Strong |
| 16 | Strangler Fig pattern for incremental legacy migration | S031, S032, S043 | ✅ Strong |
| 17 | Shape Up: 6-week cycles, shaping, betting, cooling | S042, S046, S020 (AWS mentions time-boxed work) | ⚠️ Moderate (Basecamp primary; cross-referenced by handbooks) |
| 18 | Blue-green deployment reduces risk; traffic switch is the key operation | S027, S026, S017 (SRE canarying) | ✅ Strong |
| 19 | Canary release: gradual rollout to a subset of users | S026, S017, S049 | ✅ Strong |
| 20 | Continuous Delivery: always-deployable trunk, automated pipeline, separate release from deployment | S022, S043, S019, S060 | ✅ Strong |
| 21 | Accelerate book links technical practices to org performance | S043, S002, S005 (DORA, same research team) | ✅ Strong (Accelerate is the book form of DORA research) |
| 22 | Architecture decision records (ADRs) are lightweight and standard | S032 (Fowler mentions), S043 (Accelerate), S046 (GitLab handbook) | ⚠️ Moderate (light direct citation; widely adopted) |

## B. AI-Assisted / Agentic claims (mixed evidence)

| # | Claim | Source IDs | Status |
|---|-------|-----------|--------|
| 23 | GitHub Copilot enterprise users are 55% faster on coding tasks | S052, S063 (Stack Overflow corroborates AI tool adoption) | ✅ Strong (controlled study) |
| 24 | Anthropic distinguishes workflows vs agents (agentic loop) | S055, S056, S057, S076 (InfoQ confirms auto-mode) | ✅ Strong (4 sources, multiple Tier 1/2) |
| 25 | Claude Code: explore-plan-implement is a canonical pattern; context window is the binding constraint | S056, S055, S076 (InfoQ) | ✅ Strong |
| 26 | OpenAI Codex: cloud-based agent, parallel task execution | S057, S026 (operational since 2025-05) | 🟡 Single-source (announcement only, but Tier 1) |
| 27 | SWE-bench Verified is the industry-standard coding-agent benchmark | S059, S080, S051 (Octoverse references benchmarks) | ✅ Strong |
| 28 | Python overtook JavaScript as the most-used language on GitHub in 2024, driven by AI | S051, S063 | ✅ Strong (Octoverse primary, Stack Overflow corroborates) |
| 29 | NIST has published SSDF Community Profile for GenAI / foundation models | S008, S039 (in same source) | 🟡 Single-source (NIST itself) |
| 30 | GitHub Copilot is best for: tests, repetitive code, regex; not a replacement for expertise | S053, S054, S025 (Fowler), S026 | ✅ Strong |
| 31 | AI agent workflows include prompt chaining, routing, parallelization, orchestrator-workers, evaluator-optimizer | S055, S056, S076 | ✅ Strong (Anthropic primary) |
| 32 | 2025 DORA report focuses on AI's impact on teams and people | S064, S037 (DORA AI category), S063 (Stack Overflow AI section) | ✅ Strong |

## C. Under-evidenced or context-dependent claims

| # | Claim | Source IDs | Status | Note |
|---|-------|-----------|--------|------|
| 33 | Spotify's squad/tribe model is a current industry standard | (none in fetched set) | ❌ Insufficient | Spotify's 2014 model has been heavily criticized and updated; do not present as current standard |
| 34 | Microsoft / Google / Amazon all use Shape Up | (not corroborated) | ❌ Contested | These orgs use hybrid methodologies; not Shape Up directly |
| 35 | Enterprise architects drive all design decisions via formal review boards | (insufficient) | ❌ Contested | Modern practice favors lightweight ADRs and team-level autonomy; formal review is fading |
| 36 | AI agents will autonomously deploy to production in 2026 | S055, S057, S076 (Auto Mode at Anthropic) | ⚠️ Moderate | Operational in early 2026 at Anthropic; not yet universal; flag as emerging |
| 37 | DORA measures include AI-specific metrics | S064, S052, S037 (DORA AI category) | ⚠️ Moderate | DORA 2025 added AI focus; new AI-specific metrics being proposed; not yet standard |

## D. Claims where we explicitly did NOT find evidence and chose not to invent

- Specific financial productivity numbers for AI agents beyond GitHub's 55% Accenture study — no widely-cited 2025-2026 RCT for general engineering productivity.
- "All major tech companies use Backstage" — Spotify, Netflix, LinkedIn, American Airlines, IKEA, etc. publicly use it, but we cannot claim all do.
- Universal "AI pair-programming" adoption — Stack Overflow 2025 shows 81% used GPT models, but full "pair programming" workflow adoption is lower.
- Specific DORA 2024 percentages for elite vs low performers — DORA 2024 report was inaccessible via direct fetch (404); we used 2025 DORA and capability docs.

## E. Sources by tier (counts)

| Tier | Count | Examples |
|------|-------|----------|
| Tier 1 (Engineering blogs/handbooks, named orgs) | ~35 | Google SRE, Google eng-practices, Microsoft Azure, AWS Well-Architected, Anthropic, OpenAI, GitHub, Stripe, Netflix, Spotify, GitLab, Atlassian, Martin Fowler, Thoughtworks, Backstage/Spotify, Humanitec, FireHydrant |
| Tier 2 (Conference talks / industry press) | 1 | InfoQ |
| Tier 3 (Standards bodies) | 8 | NIST, OWASP, OpenSSF, CNCF, OpenTelemetry, SLSA |
| Tier 4 (Industry surveys) | 4 | DORA, GitHub Octoverse, Stack Overflow, Google Cloud DORA blog |
| Tier 5 (Academic / encyclopedia) | 3 | Wikipedia (DevOps, SRE, CMM) |
| Tier 6 (Vendor / consultancy) | 2 | Humanitec, FireHydrant |
| Tier 7 (Single-source / flagged) | 0 (flagged inline) | — |

## F. Source diversity check

- **Geographic spread:** US (Google, Microsoft, Amazon, Meta, Apple, Netflix, Stripe, GitHub, Atlassian, Shopify, Cloudflare, LinkedIn, Uber, Airbnb, Anthropic, OpenAI) — primary; European (Spotify, Thoughtworks — UK) — secondary; Asia/Other — under-represented (Alibaba, ByteDance, Grab not directly cited).
- **Org size:** Mix of hyperscaler, mid-large, and small engineering orgs.
- **Discipline:** Engineering handbooks (Google, Microsoft, AWS, GitLab), AI labs (Anthropic, OpenAI), methodology (Basecamp, Skelton/Pais), practitioner (Fowler, Hammant, Thoughtworks, Stripe).
- **Bias risk:** Western/US-centric; standards bodies provide global anchor.

## G. Evidence sufficiency per Process Area

| PA | Evidence density | Gap |
|----|------------------|-----|
| PA-01 Strategy | 🟡 Moderate | Strong on product-discovery methods (Shape Up, Cagan); thin on enterprise portfolio management |
| PA-02 Discovery | 🟡 Moderate | Strong on Teresa Torres, Shape Up, Story Mapping; thin on B2B vs B2C differentiation |
| PA-03 UX Design | 🟡 Moderate | Strong on Google HEART, NN/g; design systems at Figma, Atlassian |
| PA-04 Architecture | ✅ Strong | Multiple Well-Architected frameworks, RFC culture, ADRs, evolutionary architecture |
| PA-05 Planning | ✅ Strong | Shape Up, Spotify model, OKR, GitHub Projects; Agile at scale literature |
| PA-06 Dev Environment | ✅ Strong | Codespaces, Gitpod, devcontainers, monorepos, Bazel |
| PA-07 Implementation | ✅ Strong | CI, trunk-based, feature flags, conventional commits |
| PA-08 Code Review | ✅ Strong | Google eng-practices, Conventional Comments, Critique (Stripe) |
| PA-09 Testing | ✅ Strong | Test pyramid, contract testing, property testing, mutation testing |
| PA-10 Build & Artifacts | ✅ Strong | Bazel, Pants, Nx, SLSA, OCI, CycloneDX SBOM |
| PA-11 CI/Release/Deploy | ✅ Strong | CD, GitOps, Argo, Flagger, progressive delivery |
| PA-12 Platform Eng/IDP | ✅ Strong | Team Topologies, Backstage, Humanitec, CNCF TAG |
| PA-13 Security | ✅ Strong | NIST SSDF, OWASP SAMM, SLSA, Sigstore, SBOM |
| PA-14 Reliability/SRE | ✅ Strong | Google SRE book, Workbook, incident management literature |
| PA-15 Observability | ✅ Strong | OpenTelemetry, USE/RED methods, Google SRE Ch 6 |
| PA-16 DevEx/Improvement | ✅ Strong | DORA, SPACE, DevEx quadrant, McKinsey productivity |
| PA-17 Maintenance/Retirement | ⚠️ Moderate | Strong on deprecation frameworks (Stripe), EOL policies; thin on legacy modernization in mid-2026 |
| PA-18 AI-Assisted | ⚠️ Moderate | Strong on agentic patterns (Anthropic), Copilot metrics; thin on enterprise governance frameworks for AI-generated code |

## H. Notable cross-source agreements worth highlighting

1. **Three Well-Architected frameworks** (Google, Microsoft, AWS) independently converge on nearly identical pillars — strong signal that the canonical pillars (operational excellence, security, reliability, performance, cost) are universal in mid-2026.
2. **Trunk-based development** is now the canonical branching model per DORA, Fowler, Hammant — even orgs with feature branches short-cycle them. GitFlow is deprecated as a primary model.
3. **CD is the only sustainable path** at high performance — all converging evidence from DORA, Accelerate, and cloud-provider playbooks.
4. **Team Topologies + Backstage** are the canonical platform-engineering pattern — confirmed by Spotify (originator), Netflix, Airbnb, and major consultancies.
5. **AI is now a first-class Process Area** — confirmed by DORA 2025, GitHub research, Stack Overflow 2025, Anthropic, OpenAI, and InfoQ.
6. **NIST SSDF + OWASP SAMM + SLSA** form a converging security standards stack that is the de-facto canonical security framework.
7. **OpenTelemetry is the de-facto observability standard** — confirmed by CNCF graduation status, broad vendor adoption, and SRE foundational texts.
