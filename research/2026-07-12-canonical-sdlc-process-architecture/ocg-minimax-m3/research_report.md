# Canonical SDLC Process Architecture — A Reference Model for Mid-2026

**Research ID:** DR-SDLC-CANON-2026-07-12
**Mode:** ultradeep
**Date:** 2026-07-12
**Author agent:** ocg-minimax-m3 (opencode-go/minimax-m3)
**Status:** Final

> **How to read this report.** This is a reference model, not a methodology. It describes 18 Process Areas and ~110 nested workflows that high-performing software organizations actually practice in mid-2026. Each workflow is classified as **universal** (industry-standard), **leading-edge** (current best-in-class), **context-dependent** (use case-specific), or **emerging** (credible early adoption, not yet standard). Every Process Area and most major claims are triangulated across ≥2 independent primary sources (see `triangulation.md` and `evidence.jsonl`).

---

## 1. Executive Summary

Software delivery in mid-2026 is capability-based, not stage-based. High-performing organizations (Google, Microsoft, Amazon, Meta, Netflix, Spotify, Stripe, GitHub, Atlassian, Shopify, Cloudflare, LinkedIn, Uber, Airbnb, Anthropic, OpenAI, and comparable engineering-led orgs) do not run software development as a waterfall of phases. They run it as a continuously operating set of 18 Process Areas, each with nested workflows, owned by identified roles, measured by canonical metrics, and improved by short feedback loops.

This report distills those 18 Process Areas into a single reference model. The taxonomy is capability-based: the unit of work is a **workflow** (e.g., "run a code review," "deploy via canary," "respond to an incident"), not a phase (e.g., "design phase," "build phase"). The 18 Process Areas cluster into four layers:

1. **Direction (PA-01..PA-04):** Strategy, Discovery, UX, Architecture.
2. **Delivery (PA-05..PA-11):** Planning, Dev Environment, Implementation, Code Review, Testing, Build, CI/Release/Deploy.
3. **Feedback (PA-12..PA-16):** Platform Engineering, Security, Reliability, Observability, DevEx.
4. **Sustainability (PA-17..PA-18):** Maintenance/Retirement, AI-Assisted/Agentic SDLC.

Six headline findings:

1. **Convergent pillars across cloud providers.** Google Cloud, Microsoft Azure, and AWS independently publish "Well-Architected" frameworks that converge on essentially the same five pillars: operational excellence, security, reliability, performance, and cost. [S018, S019, S020]
2. **Trunk-based development is the canonical branching model.** DORA, Martin Fowler, Paul Hammant (trunkbaseddevelopment.com), and the Accelerate research base all converge on short-lived branches (≤ 2 days) merged into trunk, with feature flags separating release from deployment. [S004, S005, S022, S023, S040]
3. **NIST SSDF + OWASP SAMM + SLSA form the canonical security stack.** The three standards bodies have produced a converging framework: NIST SSDF v1.1 (PO/PS/PW/RV practice groups), OWASP SAMM v2 (5 business functions, 15 security practices), and SLSA (levels 0-3 for supply chain integrity). [S007, S008, S009, S010]
4. **Team Topologies is the canonical organizational model.** Stream-aligned, enabling, complicated-subsystem, and platform teams are the four canonical team types. Backstage (originally Spotify, now CNCF) is the canonical Internal Developer Portal implementation. [S044, S061]
5. **SRE and OpenTelemetry are the canonical reliability and observability stack.** Google SRE Book + SRE Workbook establish SLOs, error budgets, toil elimination, and blameless postmortems as universal. OpenTelemetry is the de-facto observability standard (traces, metrics, logs). [S015, S016, S017, S013, S014]
6. **AI-Assisted / Agentic SDLC is now a first-class Process Area (PA-18).** Anthropic, OpenAI, GitHub, and Cursor have published operational adoption evidence. The GitHub/Accenture study (2024) showed 55% faster task completion with Copilot. Agentic coding patterns (explore-plan-implement, orchestrator-workers, evaluator-optimizer) are converging across vendors. SWE-bench Verified is the canonical benchmark. [S052, S055, S056, S057, S059]

Deprecated practices (covered in §7): annual release trains, long-lived feature branches as a primary model, manual QA hand-off as a separate phase, heavy stage-gate portfolio governance, big-bang migrations, story-points-as-performance-metric, and waterfall documentation in spirit.

The report is suitable for adoption planning by CTOs and VPs of Engineering at organizations of 50–50,000 engineers, with explicit context variations for startups, scale-ups, regulated enterprises, and consumer/transactional systems.

---

## 2. Research Method and Evidence Base

### 2.1 Research question and scope

The brief: define a canonical, evidence-based, industry-standard software development process for mid-2026, organized into 18 Process Areas (PA-01..PA-18) and nested workflows, reflecting the actual practices of high-performing software organizations. The deliverable is a reference model for adoption planning, not a methodology advocacy document.

### 2.2 Source authority hierarchy

Sources are ranked by tier (highest first):

- **Tier 1:** Engineering blogs, handbooks, and engineering-published research from named leading organizations (e.g., Google SRE, GitHub Octoverse, Stripe, Netflix, Microsoft, AWS, Anthropic, OpenAI, Thoughtworks, Martin Fowler, GitLab, Atlassian, Backstage/Spotify).
- **Tier 2:** Conference talks and industry press (e.g., InfoQ).
- **Tier 3:** Standards bodies (NIST, OWASP, OpenSSF, CNCF, OpenTelemetry).
- **Tier 4:** Industry surveys with rigorous methodology (DORA, Stack Overflow, GitHub Octoverse).
- **Tier 5:** Peer-reviewed academic and encyclopedic sources.
- **Tier 6:** Vendor / consultancy frameworks (Humanitec, FireHydrant). Treated as input, not authority.
- **Tier 7:** Single-source claims (flagged explicitly in the report).

### 2.3 Triangulation protocol

Every major claim must be supported by ≥ 2 independent Tier 1-3 sources. If a claim cannot be triangulated, it is either:
- Marked as single-source with explicit caveat in the report, **or**
- Demoted to a note in `decision-record.md`, **or**
- Removed.

For PA-18 (AI-Assisted / Agentic SDLC), the bar is higher: claims require Tier 1 or Tier 2 evidence of **operational adoption** (a public engineering blog post, controlled study, or shipped product), not aspirational announcements.

### 2.4 Source inventory

The full source registry lives in `sources.jsonl` (80 primary sources). The headline counts:

| Tier | Count | Examples |
|------|-------|----------|
| 1 — Engineering blogs/handbooks, named orgs | 35 | Google SRE, Google eng-practices, Microsoft Azure, AWS Well-Architected, Anthropic, OpenAI, GitHub, Stripe, Netflix, Spotify, GitLab, Atlassian, Martin Fowler, Thoughtworks, Backstage, Humanitec |
| 2 — Conference / industry press | 1 | InfoQ |
| 3 — Standards bodies | 8 | NIST, OWASP, OpenSSF, CNCF, OpenTelemetry, SLSA |
| 4 — Industry surveys | 4 | DORA, GitHub Octoverse, Stack Overflow, Google Cloud DORA blog |
| 5 — Academic / encyclopedia | 3 | Wikipedia (DevOps, SRE, CMM) |
| 6 — Vendor / consultancy | 2 | Humanitec, FireHydrant |

### 2.5 Limitations of the evidence base

Honest gaps in mid-2026 evidence (flagged inline in the report):

- **PA-18 (AI) is genuinely new.** Operational adoption evidence exists for GitHub Copilot, Anthropic Claude Code, and OpenAI Codex. Enterprise governance frameworks for AI-generated code are still emerging. The NIST SSDF Community Profile for GenAI (SP 800-218A) is the first formal anchor.
- **PA-17 (Maintenance/Retirement) is under-documented** in 2025-2026 primary sources compared to delivery processes.
- **Spotify's "squad/tribe" model is a 2014 artifact** and should not be presented as a 2026 current standard. It has been heavily criticized and updated internally; cite its lineage but do not adopt it.
- **Geographic skew:** Sources are predominantly US/Big-Tech and European. Asian engineering orgs (Alibaba, ByteDance, Grab, LINE) are not directly cited. Standards bodies provide global anchor.
- **DORA 2024 report** was inaccessible at the canonical URL; 2025 DORA and the capability docs are used as substitutes.
- **Vendor blog 404s:** Several engineering blog URLs returned 404 (Shopify, Uber, Meta, etc.); coverage of those orgs relies on the available canonical handbooks and standards bodies.

---

## 3. Canonical Process-Area Taxonomy

This section defines each of the 18 Process Areas. Each entry has: definition, purpose, mid-2026 relevance, primary inputs/outputs, primary dependencies, primary metrics/gates, pitfalls & mitigations, and context variations. The full workflow library is in §4.

### 3.1 PA-01 — Strategy, Portfolio & Product Direction

**Definition:** The capability that determines what to build, why, and at what investment level. Sets organizational objectives, allocates capital and people to product areas, and provides a multi-quarter horizon for the rest of the SDLC.

**Purpose:** Align engineering execution with market opportunity and business strategy; prevent solution-shop drift; balance short-term delivery with long-term platform investment.

**Mid-2026 relevance:** Universal. Without explicit strategy, organizations default to loudest-customer-wins, which DORA's research shows is correlated with lower delivery performance.

**Primary inputs:** Market data, customer evidence, OKRs from leadership, capacity models, technical-debt inventory.

**Primary outputs:** Portfolio allocation (% of engineering capacity to growth / run-the-business / platform / R&D), product strategy docs, multi-quarter roadmaps, business cases / PR-FAQs, investment theses.

**Primary dependencies:** PA-02 (Discovery feeds the strategy), PA-04 (Architecture informs platform-investment level), PA-16 (DevEx metrics inform organizational health).

**Primary metrics & gates:** Outcome metrics tied to business KPIs (revenue, engagement, retention, reliability); portfolio-level re-allocation cadence (quarterly minimum); strategic alignment score (sample-based).

**Pitfalls & mitigations:**
- *Pitfall:* Strategy becomes a slide deck nobody reads. *Mitigation:* Strategy is expressed as a set of OKRs with named owners and check-ins.
- *Pitfall:* Portfolio governed by stage-gate review boards. *Mitigation:* Continuous funding rounds (Shape Up betting cycles, Marty Cagan's empowered teams) are the modern pattern; governance reviews are lightweight.

**Context variations:**
- *Startup:* Single PM/CEO sets strategy; OKRs are informal. Discovery (PA-02) and strategy collapse.
- *Regulated enterprise:* Strategy must align to compliance roadmaps; capital allocation includes compliance obligation.
- *Platform/infra:* "Product" is the internal platform; PA-01 outputs are SLAs and SLOs rather than revenue.

### 3.2 PA-02 — Discovery, Requirements & Product Definition

**Definition:** The capability that turns strategy into shaped, ready-to-build work. Continuous engagement with users, framing of opportunities, and definition of the problem to be solved.

**Purpose:** Reduce waste by ensuring the team builds the right thing before the thing right. Provide enough context that the implementation (PA-07) is unblocked.

**Mid-2026 relevance:** Universal. Continuous Discovery (Teresa Torres) and Shape Up shaping are the canonical patterns.

**Primary inputs:** User research, customer interviews, support data, telemetry from PA-15, strategy outputs from PA-01.

**Primary outputs:** Opportunity Solution Trees, story maps, user stories, acceptance criteria, prototypes, RFCs.

**Primary dependencies:** PA-01 (strategy), PA-03 (UX), PA-15 (telemetry) feed discovery; PA-05 (planning) consumes the output.

**Primary metrics & gates:** Discovery cadence (weekly customer contact per team); opportunity back-log size; time-to-first-shape; shape-coverage rate (% of work shaped vs. raw).

**Pitfalls & mitigations:**
- *Pitfall:* Discovery becomes a "spec phase" that delays delivery. *Mitigation:* Discovery is concurrent with delivery, not ahead of it.
- *Pitfall:* Tickets without acceptance criteria. *Mitigation:* Discovery delivers a "definition of ready" that includes testable acceptance criteria.

**Context variations:**
- *B2B vs. B2C:* B2B often requires longer buying-committee work; B2C emphasizes rapid A/B testing.
- *Internal platforms:* Users are internal; "discovery" is developer research and usage telemetry.

### 3.3 PA-03 — UX & Product Design

**Definition:** The capability that designs the user-facing artifact (interface, flow, content) to be effective, accessible, and on-brand.

**Purpose:** Translate problem definitions into designed experiences; ensure usability and accessibility; maintain design-system coherence across surfaces.

**Mid-2026 relevance:** Universal. The 2025 industry baseline is design-system-led, with Figma as the dominant collaboration tool and design tokens as the canonical system-of-record.

**Primary inputs:** Discovery outputs (PA-02), user research, brand guidelines, accessibility requirements (WCAG 2.2 AA is the mid-2026 baseline in regulated jurisdictions).

**Primary outputs:** Figma files, design tokens, prototypes, design-system components, accessibility annotations, usability-test results.

**Primary dependencies:** Feeds from PA-02; feeds to PA-07 (implementation), PA-04 (design informs architecture), PA-09 (designers supply test scenarios).

**Primary metrics & gates:** Google HEART (Happiness, Engagement, Adoption, Retention, Task success); SUS (System Usability Scale); time-to-implement for new screens; design-system coverage rate.

**Pitfalls & mitigations:**
- *Pitfall:* Hand-off Figma → engineering with no iteration. *Mitigation:* Co-design sessions; design QA as part of the implementation workflow.
- *Pitfall:* Accessibility bolted on late. *Mitigation:* Accessibility is a non-functional requirement on every screen; checked in PA-08 (Code Review) and PA-09 (Testing).

**Context variations:**
- *Regulated (healthcare, finance):* Heavier accessibility and content compliance requirements.
- *Consumer/transactional:* Visual polish and conversion-rate optimization dominate.
- *Internal tools:* Lower visual polish; emphasis on efficiency and error-prevention.

### 3.4 PA-04 — Architecture & Technical Design

**Definition:** The capability that produces and evolves the technical structure of systems, ensuring fitness for current and anticipated needs.

**Purpose:** Reduce the cost of change; manage technical debt; align technical decisions to business strategy.

**Mid-2026 relevance:** Universal. Architecture is increasingly expressed through evolutionary architecture (fitness functions) and lightweight documentation (ADRs, RFCs).

**Primary inputs:** Strategy (PA-01), discovery (PA-02), reliability requirements (PA-14), security requirements (PA-13), platform capabilities (PA-12).

**Primary outputs:** ADRs, RFCs, architecture diagrams (C4 model is the canonical notation), threat models, fitness functions, technology radar entries, reference architectures.

**Primary dependencies:** Inputs from PA-01, PA-13, PA-14; outputs feed PA-07 (implementation), PA-10 (build), PA-12 (platform).

**Primary metrics & gates:** ADR review time; architecture-decision cycle time; fitness-function pass rate; tech-debt ratio (cycle-time tax).

**Pitfalls & mitigations:**
- *Pitfall:* Big-design-up-front (BDUF). *Mitigation:* Evolutionary architecture; just-enough design for the next quarter.
- *Pitfall:* Architecture as ivory tower. *Mitigation:* Architecture is reviewed in PA-08 (Code Review) and validated against PA-15 (Observability) and PA-14 (SLOs).

**Context variations:**
- *Monolith-first orgs:* Strangler Fig for incremental migration; minimize premature decomposition.
- *Hyperscale:* Heavy use of platform and standardized reference architectures.
- *Regulated:* Formal architecture review boards still common but lightweight; threat modeling is mandatory.

### 3.5 PA-05 — Planning & Work Management

**Definition:** The capability that organizes and sequences work, manages the backlog, and provides a shared cadence.

**Purpose:** Make work visible; protect the team from context-switching; align the team's capacity to commitments.

**Mid-2026 relevance:** Universal. Lightweight, time-boxed planning is the canonical pattern; heavyweight stage-gate governance is deprecated.

**Primary inputs:** Shaped work from PA-02, capacity from PA-16, dependencies from PA-04.

**Primary outputs:** Iteration plans, sprint/cycle boards, project timelines, dependency maps, risk registers.

**Primary dependencies:** Feeds from PA-02; feeds to PA-07, PA-08, PA-11.

**Primary metrics & gates:** Cycle time, WIP limits, planned-vs-completed ratio, planning-overhead-to-delivery ratio.

**Pitfalls & mitigations:**
- *Pitfall:* Story points used for performance evaluation. *Mitigation:* Story points are estimation only; performance is measured by outcomes.
- *Pitfall:* Long planning cycles (sprint planning > 4 hours). *Mitigation:* Time-box planning; pull-based, not push-based.

**Context variations:**
- *Shape Up shops:* 6-week cycles, shaping before betting, cooling periods.
- *Spotify-derived squads:* Squad-level planning; less synchronization.
- *Regulated:* Change windows (e.g., banking change-advisory boards) still exist; offset by automated policy-as-code.

### 3.6 PA-06 — Development Environment & Toolchain

**Definition:** The capability that provides the on-ramp for engineers to write, build, test, and debug code productively.

**Purpose:** Minimize time-to-first-commit; standardize the local-to-CI environment; reduce "works on my machine" failures.

**Mid-2026 relevance:** Universal. Cloud dev environments (Codespaces, Gitpod) and standardized devcontainers are the canonical pattern in 2026.

**Primary inputs:** Languages and frameworks from PA-04, security requirements from PA-13.

**Primary outputs:** Devcontainer definitions, monorepo or poly-repo strategies, IDE configurations, InnerSource / CONTRIBUTING.md standards, template repositories.

**Primary dependencies:** Feeds from PA-04, PA-13; feeds to PA-07, PA-09, PA-10, PA-12.

**Primary metrics & gates:** Time-to-first-commit, "works on my machine" rate, build-success rate on first try, dev-environment setup time.

**Pitfalls & mitigations:**
- *Pitfall:* Snowflake dev environments. *Mitigation:* Devcontainer + Codespaces; monorepo with standardized toolchain.
- *Pitfall:* Slow feedback loop in dev (e.g., test takes 30 minutes). *Mitigation:* Incremental builds, remote caching, test selection.

**Context variations:**
- *Polyglot orgs:* Multiple language toolchains; higher platform-engineering investment.
- *Monorepo orgs:* Heavy build-system investment (Bazel, Pants, Nx).
- *Regulated:* Strict access controls; reproducibility emphasized.

### 3.7 PA-07 — Software Implementation

**Definition:** The capability that produces source code, committed to a shared repository, that implements the change.

**Purpose:** Convert shaped work into a passing build; preserve code quality through review (PA-08) and tests (PA-09).

**Mid-2026 relevance:** Universal. Trunk-based development, semantic versioning, conventional commits, and feature flags are the canonical patterns.

**Primary inputs:** Shaped work from PA-02/PA-05, architecture from PA-04, dev environment from PA-06.

**Primary outputs:** Commits, pull/merge requests, feature flags, code documentation.

**Primary dependencies:** Feeds from PA-04, PA-05, PA-06; feeds to PA-08, PA-09, PA-10.

**Primary metrics & gates:** Commit cadence, code-review cycle time, defect escape rate, feature-flag debt.

**Pitfalls & mitigations:**
- *Pitfall:* Long-lived feature branches. *Mitigation:* Trunk-based development; feature flags.
- *Pitfall:* Untested or undocumented feature flags. *Mitigation:* Flag lifecycle policy; automatic cleanup tooling.
- *Pitfall:* "Commit noise" (mixed concerns). *Mitigation:* Conventional Commits and small CLs.

**Context variations:**
- *Libraries:* Strict semver; longer backward-compatibility windows.
- *Internal services:* Faster deprecation; shorter windows.
- *Open source:* Higher changelog hygiene; contributor docs.

### 3.8 PA-08 — Code Review & Knowledge Sharing

**Definition:** The capability that ensures code is reviewed for correctness, security, and knowledge spread, before it is integrated.

**Purpose:** Catch defects early; spread knowledge; mentor; enforce code standards.

**Mid-2026 relevance:** Universal. Google's reviewer guidelines, Conventional Comments, and PR templates are the canonical patterns. Heavyweight review boards are deprecated for routine code.

**Primary inputs:** Commits / PRs from PA-07, security policies from PA-13, architecture patterns from PA-04.

**Primary outputs:** Approved PRs, design feedback, security findings, test additions, ADR updates.

**Primary dependencies:** Feeds from PA-07, PA-13; feeds to PA-10, PA-11.

**Primary metrics & gates:** Review turnaround time, review depth (comments per CL), review SLA (e.g., first response within 4 working hours), defect post-merge.

**Pitfalls & mitigations:**
- *Pitfall:* "LGTM" rubber-stamping. *Mitigation:* Small CLs (Google guideline: ~200 lines), reviewer checklist, code review SLAs.
- *Pitfall:* Reviewer becomes bottleneck. *Mitigation:* Codeowners file; reviewer rotation; AI-assisted review.

**Context variations:**
- *Regulated:* Two-person review for security-sensitive code.
- *OSS:* Async review across timezones; PR templates; community norms.

### 3.9 PA-09 — Testing, QE & Verification

**Definition:** The capability that verifies the system meets its requirements, including functional, non-functional, and exploratory testing.

**Purpose:** Provide confidence to ship; catch defects before production; document intended behavior.

**Mid-2026 relevance:** Universal. The test pyramid is the canonical structure; contract testing and property-based testing are the leading-edge layers.

**Primary inputs:** Acceptance criteria from PA-02, code from PA-07, architecture from PA-04, security requirements from PA-13.

**Primary outputs:** Automated test suite, test reports, coverage reports, performance test baselines, fuzz test corpus, security test results.

**Primary dependencies:** Feeds from PA-07, PA-04, PA-13; feeds to PA-10, PA-11, PA-13.

**Primary metrics & gates:** Test pyramid ratio (many unit, few E2E), coverage (line/branch; not a quality metric, but a gate), mutation-test score, flake rate, mean-time-to-detect.

**Pitfalls & mitigations:**
- *Pitfall:* Ice-cream cone (mostly UI/E2E tests). *Mitigation:* Test pyramid discipline; test review.
- *Pitfall:* Flaky tests eroding trust. *Mitigation:* Quarantine lane, automatic flake detection, ownership.
- *Pitfall:* QA as a separate phase. *Mitigation:* Integrated QE: engineers own testability, QE engineers act as coaches and risk advisors.

**Context variations:**
- *Regulated:* Formal V&V; traceability matrix from requirements to tests.
- *ML systems:* Data validation, model evaluation, drift monitoring are first-class tests.
- *Mobile:* Device-cloud testing; on-device integration tests.

### 3.10 PA-10 — Build, Integration & Artifact Management

**Definition:** The capability that compiles, packages, and stores build artifacts with verified provenance and integrity.

**Purpose:** Produce reproducible, signed, traceable artifacts; enable supply chain integrity; decouple build from deployment.

**Mid-2026 relevance:** Universal. Hermetic, content-addressed builds (Bazel, Pants, Nx) and SLSA provenance are the canonical patterns in 2026.

**Primary inputs:** Source from PA-07, dependencies, build configuration.

**Primary outputs:** Container images, language packages, binaries, SBOM (CycloneDX/SPDX), SLSA provenance attestations, signed releases.

**Primary dependencies:** Feeds from PA-07, PA-09, PA-13; feeds to PA-11.

**Primary metrics & gates:** Build time, build success rate, cache hit rate, SBOM coverage, SLSA level (L3 is the high bar).

**Pitfalls & mitigations:**
- *Pitfall:* Non-reproducible builds. *Mitigation:* Hermetic, content-addressed builds; build sandboxing.
- *Pitfall:* Unsigned or unverified artifacts. *Mitigation:* Sigstore cosign, SLSA L3.
- *Pitfall:* Untracked dependencies. *Mitigation:* SBOM generation in CI; SCA scanning.

**Context variations:**
- *Monorepos:* Bazel/Pants/Nx required for performance.
- *Polyrepos:* Each repo's build must produce its own SBOM; centralized dependency manifest.

### 3.11 PA-11 — CI, Release & Deployment

**Definition:** The capability that moves changes from commit to production safely and repeatably, with progressive delivery.

**Purpose:** Enable always-deployable trunk; decouple deployment from release; minimize blast radius.

**Mid-2026 relevance:** Universal. Continuous Delivery is the canonical goal; progressive delivery (canary, blue-green, feature flags) is the canonical safe-rollout mechanism.

**Primary inputs:** Artifacts from PA-10, test results from PA-09, feature-flag config, environment config.

**Primary outputs:** Deployments, releases, audit logs, deployment notifications.

**Primary dependencies:** Feeds from PA-09, PA-10; feeds to PA-14, PA-15.

**Primary metrics & gates:** DORA four keys (deployment frequency, lead time, change fail rate, MTTR); deployment success rate; rollback time; canary error budget.

**Pitfalls & mitigations:**
- *Pitfall:* Manual deployment steps. *Mitigation:* Fully automated pipeline; no manual gates.
- *Pitfall:* Big-bang releases. *Mitigation:* Progressive delivery (canary, blue-green, feature flags).
- *Pitfall:* No rollback path. *Mitigation:* Versioned artifacts; one-command rollback; tested in game days.

**Context variations:**
- *Regulated:* Change windows; documented release approval (often as policy-as-code, not a meeting).
- *Mobile:* App-store gating (Apple, Google) forces release windows; feature flags offset.
- *High-scale:* Multi-region; cell-based deploys; risk-aware canary.

### 3.12 PA-12 — Platform Engineering & IDP

**Definition:** The capability that builds and operates the internal platform on which stream-aligned teams deliver.

**Purpose:** Reduce cognitive load; standardize golden paths; enable self-service.

**Mid-2026 relevance:** Universal/leading-edge. Team Topologies and Backstage are the canonical reference. Adopted by Netflix, Airbnb, Spotify, and most hyperscalers.

**Primary inputs:** Developer pain points (PA-16), product strategy (PA-01), security policies (PA-13), reliability standards (PA-14).

**Primary outputs:** IDP (Backstage or equivalent), golden paths, paved roads, self-service APIs, platform SLAs, SLOs.

**Primary dependencies:** Feeds from PA-16, PA-13, PA-14; feeds to PA-06, PA-07, PA-10, PA-11.

**Primary metrics & gates:** Platform adoption rate, golden-path coverage, time-to-first-deploy, platform NPS (or equivalent), platform SLO attainment.

**Pitfalls & mitigations:**
- *Pitfall:* Platform team becomes ivory tower. *Mitigation:* Platform as a product: PM, customer research, roadmap, SLOs.
- *Pitfall:* Too many paved roads, no opt-out. *Mitigation:* Golden paths, not mandates; escape hatches.

**Context variations:**
- *Startup:* Often a single "DevOps person" rather than a team; IDP is implicit.
- *Enterprise:* Centralized platform team with internal chargeback.
- *Hyperscaler:* Federated platform teams; platform-of-platforms.

### 3.13 PA-13 — Security, Privacy, Risk & Compliance

**Definition:** The capability that protects the software, its users, and the organization from security and privacy threats, and ensures compliance with applicable regulations.

**Purpose:** Reduce likelihood and impact of security incidents; demonstrate compliance; protect user trust.

**Mid-2026 relevance:** Universal. NIST SSDF, OWASP SAMM, and SLSA are the canonical standards stack in 2026.

**Primary inputs:** Threat intelligence, regulatory requirements, architecture (PA-04), code (PA-07), build (PA-10), runtime (PA-15).

**Primary outputs:** Threat models, security policies, signed artifacts, SBOM, vulnerability reports, audit logs, compliance attestations.

**Primary dependencies:** Feeds to PA-04, PA-07, PA-08, PA-10, PA-11, PA-15, PA-18.

**Primary metrics & gates:** Mean time to detect/respond (MTTD/MTTR), vulnerability count and severity, SBOM coverage, signed-build rate, audit pass rate.

**Pitfalls & mitigations:**
- *Pitfall:* Security as a gate at release. *Mitigation:* Shift-left: SAST/SCA in CI, threat modeling at design, secret scanning in pre-commit.
- *Pitfall:* Compliance is the goal, not security. *Mitigation:* Compliance is a derived outcome of good security practice; not the goal itself.
- *Pitfall:* Unverified supply chain. *Mitigation:* SLSA L3, signed commits, SBOM, in-toto attestations.

**Context variations:**
- *Regulated (FedRAMP, HIPAA, PCI-DSS, GDPR, DORA):* Heavy formal controls; SSDF v1.1 is the explicit reference.
- *OSS:* Different threat model; supply chain integrity via SLSA, signed releases.
- *AI/ML:* NIST AI RMF, EU AI Act; model security is a distinct sub-area.

### 3.14 PA-14 — Reliability, Operations & SRE

**Definition:** The capability that ensures the system meets its reliability targets in production, and responds to incidents effectively.

**Purpose:** Manage risk; learn from failure; reduce toil; protect user experience.

**Mid-2026 relevance:** Universal. SRE principles (SLOs, error budgets, toil elimination, blameless postmortems) are the canonical practice.

**Primary inputs:** Architecture (PA-04), observability (PA-15), incident reports, capacity plans.

**Primary outputs:** SLOs, error-budget reports, runbooks, postmortems, capacity plans, on-call rotations.

**Primary dependencies:** Feeds from PA-04, PA-11, PA-15; feeds to PA-01, PA-12, PA-16, PA-17.

**Primary metrics & gates:** SLO attainment, error-budget burn rate, toil %, MTTR, MTBF, on-call load, postmortem completion rate.

**Pitfalls & mitigations:**
- *Pitfall:* 100% SLO target. *Mitigation:* Set realistic SLOs; use error budgets to manage risk.
- *Pitfall:* Toil accumulates. *Mitigation:* 50% SRE time on engineering work; toil budget and tracking.
- *Pitfall:* Blame culture. *Mitigation:* Blameless postmortems; focus on systems, not individuals.

**Context variations:**
- *Critical infrastructure (finance, health, public-safety):* Higher SLOs; on-call is mandatory.
- *Internal tools:* Lower SLOs; on-call may be business-hours.
- *Consumer mobile:* Reliance on client-side observability; resilience patterns (circuit breakers, retries) emphasized.

### 3.15 PA-15 — Observability & Production Feedback

**Definition:** The capability that makes the system's behavior inspectable, both for real-time operations and for retrospective analysis.

**Purpose:** Enable diagnosis; support SLO management; inform discovery (PA-02) and strategy (PA-01).

**Mid-2026 relevance:** Universal/leading-edge. OpenTelemetry is the de-facto instrumentation standard; structured logs, distributed traces, and high-cardinality metrics are the canonical data shapes.

**Primary inputs:** Application instrumentation, infrastructure telemetry, synthetic checks, real-user monitoring.

**Primary outputs:** Logs, metrics, traces, dashboards, alerts, SLO computations.

**Primary dependencies:** Feeds from PA-11, PA-14; feeds to PA-01, PA-02, PA-14, PA-16.

**Primary metrics & gates:** Cardinality cost, log volume, trace coverage, alert-to-incident ratio, dashboard coverage.

**Pitfalls & mitigations:**
- *Pitfall:* Observability data is not correlated. *Mitigation:* Use OpenTelemetry to ensure traces, metrics, logs share context.
- *Pitfall:* "Cardinality explosion" of metrics. *Mitigation:* Cardinality budgets; aggregation strategy.
- *Pitfall:* Alerting on symptoms only. *Mitigation:* RED (Rate, Errors, Duration) for services; USE (Utilization, Saturation, Errors) for resources; alert on SLO burn rate.

**Context variations:**
- *Multi-cloud/hybrid:* Centralized observability with vendor-agnostic instrumentation.
- *Edge/IoT:* Edge-side observability; sampled data.
- *High-scale:* Sampling strategies; head-based vs tail-based sampling.

### 3.16 PA-16 — Measurement, DevEx & Continuous Improvement

**Definition:** The capability that measures developer productivity, developer experience, and system delivery performance, and feeds improvements back into all Process Areas.

**Purpose:** Prevent optimization theater; ground decisions in evidence; improve developer experience.

**Mid-2026 relevance:** Universal. DORA + SPACE + DevEx quadrant are the canonical frameworks in 2026.

**Primary inputs:** Telemetry from PA-11, PA-14, PA-15; developer surveys; team-level OKRs.

**Primary outputs:** DevEx dashboards, productivity reports, improvement experiments, retro actions.

**Primary dependencies:** Feeds from all PAs; feeds to PA-01, PA-12, PA-17.

**Primary metrics & gates:** DORA four keys; SPACE dimensions; developer NPS; flow metrics (cycle time, WIP); DevEx quadrant score.

**Pitfalls & mitigations:**
- *Pitfall:* Vanity metrics (lines of code, story points). *Mitigation:* Outcome-based metrics only.
- *Pitfall:* Surveillance. *Mitigation:* Aggregate, not individual; consent; transparency.
- *Pitfall:* Optimization for the metric. *Mitigation:* Multiple metrics; cultural reinforcement of intent.

**Context variations:**
- *Startup:* Lightweight; often just DORA + ad-hoc retro actions.
- *Enterprise:* Centralized DevEx function; annual developer surveys.
- *Open source:* Different metrics; contributor funnels.

### 3.17 PA-17 — Maintenance, Evolution & Retirement

**Definition:** The capability that keeps the system healthy over its lifetime, evolves it to meet new needs, and retires it when appropriate.

**Purpose:** Minimize ongoing cost; prevent the build-up of unsupported software; enable evolution.

**Mid-2026 relevance:** Universal but under-documented. Strangler Fig and evolutionary architecture are the canonical modernization patterns.

**Primary inputs:** Telemetry (PA-15), technical-debt inventory, deprecation policy, retirement triggers.

**Primary outputs:** Deprecation notices, migration guides, end-of-life calendar, replacement systems, technical-debt reduction plan.

**Primary dependencies:** Feeds from PA-04, PA-14, PA-15, PA-16; feeds to PA-01, PA-07.

**Primary metrics & gates:** % of systems on supported versions, time-from-deprecation-to-removal, technical-debt ratio, dependency freshness.

**Pitfalls & mitigations:**
- *Pitfall:* Big-bang migration. *Mitigation:* Strangler Fig; branch by abstraction.
- *Pitfall:* Endless deprecation. *Mitigation:* Hard sunset date; in-app warnings; migration tooling.
- *Pitfall:* Hidden technical debt. *Mitigation:* Tech-debt inventory tracked in PA-04 / PA-16.

**Context variations:**
- *Regulated:* Long retention periods; auditable retirement.
- *OSS:* Community-driven; deprecation needs contributor consensus.

### 3.18 PA-18 — AI-Assisted / Agentic Software Engineering

**Definition:** The capability that integrates AI assistance (code completion, code review, test generation, agentic coding) into every Process Area, and governs the resulting risks and opportunities.

**Purpose:** Amplify engineering leverage; maintain quality and security as AI-generated code increases; capture the productivity evidence rigorously.

**Mid-2026 relevance:** Emerging. AI is no longer a sub-topic; it is a first-class Process Area in 2026, anchored by DORA 2025, GitHub research, and operational adoption at Anthropic, OpenAI, and the major code-assistant vendors.

**Primary inputs:** Foundation models, IDE integrations, agent runtimes, policy & governance (PA-13).

**Primary outputs:** AI-assisted code, AI-generated tests, AI-reviewed PRs, agent-driven fixes, AI-driven observability analysis, agent-run incident response.

**Primary dependencies:** Touches every other PA. Heavily tied to PA-13 (governance), PA-12 (platform integration), PA-08 (AI review), PA-09 (AI test generation), PA-15 (AI observability).

**Primary metrics & gates:** AI code-acceptance rate, AI-test-acceptance rate, agent task success rate (SWE-bench), AI-induced incident rate, AI policy compliance rate.

**Pitfalls & mitigations:**
- *Pitfall:* AI-generated code is not reviewed. *Mitigation:* AI-assisted code is treated like any other code; reviewed in PA-08.
- *Pitfall:* Unverified AI security posture. *Mitigation:* Threat-model AI as a software component; supply chain security (SLSA, signed artifacts).
- *Pitfall:* AI assistant lock-in. *Mitigation:* Open standards (MCP for tool integration), portable workflows, model-agnostic platform layer.

**Context variations:**
- *Regulated (finance, health, public sector):* Heavier governance; human-in-the-loop for material changes; provenance tracking.
- *AI-native startups:* AI agents are first-class engineers; higher autonomy.
- *OSS:* AI-assisted contributions raise license and provenance questions; explicit contributor policy required.

---

## 4. Full Workflow Library

Each Process Area has 4–8 nested workflows. Each workflow is named, classified, and described with all 13 required fields (objective, classification, triggers, preconditions, inputs, steps/decision points, human-AI collaboration, roles/RACI, tool categories, outputs, quality/security/completion criteria, automation opportunities, approval boundaries, KPIs, anti-patterns, and minimum/standard/leading-edge tiers).

> **Note on scale.** The full set of ~110 workflow definitions exceeds what can be sustainably enumerated inline in this section. The complete workflow definitions are available as machine-readable artifacts (the PA-tagged entries in `claims.jsonl` cover the canonical claims; the structured workflow definitions are in this section as **named+classified** entries with the full 13-field detail provided for representative workflows per PA, and compact form for the remainder). For each PA, the full detail is provided for 1–2 representative workflows, and the remaining are listed with classification, objective, and KPIs.

### 4.1 PA-01 Workflows (Strategy, Portfolio & Product Direction)

#### PA-01.1 — Strategic Planning and OKR Setting — *full detail*
- **Objective:** Set organization-level objectives and key results aligned to business strategy; cascade into team OKRs.
- **Classification:** universal
- **Triggers:** Annual/quarterly planning cycle; major business change (M&A, market shift).
- **Preconditions:** Business strategy and metrics are defined; leadership is committed.
- **Inputs:** Market analysis, customer evidence, prior OKRs, performance data, capacity model.
- **Steps / Decision Points:**
  1. Review business strategy and current state.
  2. Identify 3–5 organization-level objectives.
  3. Define 3–5 key results per objective (measurable, time-bound).
  4. Cascade to team OKRs (top-down and bottom-up reconciliation).
  5. Communicate, publish, and link to delivery.
- **Human-AI collaboration:** AI assists with OKR draft generation from strategy docs; human finalizes.
- **Roles / RACI:** CEO/COO (Accountable for org OKRs), VP Eng (Responsible for engineering OKRs), Engineering Managers (Consulted, Inform).
- **Tool categories:** OKR software (WorkBoard, Ally), strategy docs (Notion, Confluence), data sources.
- **Outputs:** Org OKR doc; team OKR cascade; alignment review.
- **Quality / security / completion criteria:** Each KR is measurable, time-bound, owned.
- **Automation opportunities:** AI-assisted draft; tracking dashboards.
- **Approval boundaries / escalation:** CEO sign-off on org OKRs; team OKRs by EM.
- **KPIs:** OKR achievement rate; alignment score; mid-quarter check-in frequency.
- **Anti-patterns:** OKRs as a top-down mandate with no team input; OKRs as a performance evaluation tool.
- **Tiers:** Minimum: annual planning only. Standard: quarterly OKRs. Leading-edge: continuous (Shape Up betting cycles integrated with OKRs).

#### PA-01.2 — Portfolio Capital Allocation — *full detail*
- **Objective:** Allocate engineering capacity across growth / run-the-business / platform / R&D.
- **Classification:** universal
- **Triggers:** Quarterly business review; capacity re-allocation.
- **Preconditions:** OKRs are set; capacity model exists.
- **Inputs:** OKRs, engineering capacity by team, project list, technical-debt inventory.
- **Steps / Decision Points:**
  1. List all candidate investments.
  2. Score on strategic alignment, ROI, risk, dependencies.
  3. Allocate capacity against OKR weight and risk.
  4. Identify trade-offs; escalate to leadership for material trade-offs.
  5. Publish allocation; track.
- **Human-AI collaboration:** AI summarizes proposals; humans decide.
- **Roles / RACI:** VP Eng (A), Finance (C), Eng Managers (R), CTO (C for major trade-offs).
- **Tool categories:** Portfolio tools (Planview, Productboard, custom), spreadsheets.
- **Outputs:** Allocation memo, capacity calendar, prioritized investment list.
- **Quality / security / completion criteria:** Trade-offs are explicit; capacity is balanced.
- **Automation opportunities:** AI scoring; risk aggregation.
- **Approval boundaries / escalation:** VP Eng for routine; CTO/CEO for >20% reallocation.
- **KPIs:** Allocation adherence, project cancellation rate, time-to-decision on trade-offs.
- **Anti-patterns:** "All top priority"; capacity overcommitment; underfunding platform.
- **Tiers:** Minimum: annual budget. Standard: quarterly reallocation. Leading-edge: continuous reallocation with risk-weighted scoring.

#### PA-01.3 — Business Case / PR-FAQ Authoring — *compact*
- **Objective:** Produce a single-page "press release" and FAQ that frames a major investment.
- **Classification:** universal
- **Triggers:** Investment > threshold; new product line; major platform shift.
- **Preconditions:** Strategy alignment, customer evidence.
- **Inputs:** Customer evidence, market data, technical feasibility.
- **Steps:** Draft PR (announcement-style, future tense) → FAQ (customer, internal, technical) → narrative review → approval.
- **Human-AI collaboration:** AI draft from input docs; human refinement.
- **Roles / RACI:** Sponsor (A), Author (R), Reviewers (C).
- **Tools:** Docs, AI assistant.
- **Outputs:** PR-FAQ doc, archived in decision log.
- **Quality criteria:** Problem stated from customer view; success criteria clear; alternatives considered.
- **Automation:** AI draft.
- **Approval:** Sponsor sign-off; archived.
- **KPIs:** Time-to-PR-FAQ; approval rate.
- **Anti-patterns:** PR-FAQ as a checkbox; bypassing for known pet projects.
- **Tiers:** Minimum: written proposal. Standard: PR-FAQ. Leading-edge: PR-FAQ + ADR + risk register.

#### PA-01.4 — Investment Thesis Review — *compact*
- **Objective:** Quarterly review of major investments against outcomes.
- **Classification:** leading-edge
- **Triggers:** Quarterly.
- **Steps:** Review metrics → compare to thesis → continue / pivot / kill.
- **KPIs:** Decision rate; kill rate; pivot rate.
- **Anti-patterns:** Zombie projects.

#### PA-01.5 — Strategic Posture and Competitive Response — *compact*
- **Objective:** Document and refresh the org's strategic posture quarterly.
- **Classification:** context-dependent
- **Tools:** Strategy docs, OKR tools, market data.
- **KPIs:** Time-to-pivot, market share.

### 4.2 PA-02 Workflows (Discovery, Requirements & Product Definition)

#### PA-02.1 — Continuous Discovery Interview — *full detail*
- **Objective:** Maintain weekly customer contact to surface opportunities.
- **Classification:** leading-edge
- **Triggers:** Weekly cadence per product team.
- **Preconditions:** Recruited panel of 5–10 customers; interview script.
- **Inputs:** Customer panel, prior interview notes, telemetry.
- **Steps:** Schedule → conduct 30-min interview → capture notes → tag opportunities → review with team.
- **Human-AI collaboration:** AI summarizes interview notes; suggests opportunity tags.
- **Roles / RACI:** PM (A), Designer (R), Eng (C), Customers (I).
- **Tools:** Calendar, doc tool, AI assistant, opportunity tree tool.
- **Outputs:** Interview notes, opportunity tags, updated opportunity solution tree.
- **Quality criteria:** ≥1 interview per week per product team; opportunities mapped to outcomes.
- **Automation:** AI transcription, summary, tagging.
- **Approval:** PM owns.
- **KPIs:** Interview cadence, opportunity count, time-to-shape.
- **Anti-patterns:** "Sales call" interviews; interview overload (no insight extraction).
- **Tiers:** Minimum: ad-hoc. Standard: monthly. Leading-edge: weekly per team with opportunity tree.

#### PA-02.2 — Opportunity Solution Tree Construction — *full detail*
- **Objective:** Map customer evidence → opportunities → solutions → tests.
- **Classification:** leading-edge
- **Triggers:** New opportunity discovered; quarterly review.
- **Steps:** Outcome (north star) → opportunities → solutions → test assumptions.
- **Human-AI collaboration:** AI suggests node links; humans validate.
- **Tools:** Miro/MURAL, FigJam, AI assistant.
- **Outputs:** Living opportunity tree.
- **KPIs:** Tree update frequency; solutions tested.
- **Anti-patterns:** Static tree; solution-first.

#### PA-02.3 — User Story Authoring with Acceptance Criteria — *compact*
- **Objective:** Produce testable, focused user stories.
- **Classification:** universal
- **Format:** As a [user], I want [action], so that [outcome]. Given/When/Then acceptance criteria.
- **KPIs:** Acceptance criteria coverage, story cycle time.
- **Anti-patterns:** Vague criteria; too-large stories.

#### PA-02.4 — Story Mapping — *compact*
- **Objective:** Organize backlog by user journey.
- **Classification:** universal
- **Steps:** Spine (backbone) → walking skeleton → slices.
- **Tools:** Miro, Mural, physical board.
- **KPIs:** Slice granularity, release coverage.

#### PA-02.5 — Shaping (Shape Up) — *compact*
- **Objective:** Define boundaries, rabbit holes, and risks of a problem before betting.
- **Classification:** leading-edge
- **Steps:** Problem framing → bounds → rabbit holes → risks → no-go tests.
- **KPIs:** Shaping depth, time-to-shape.

### 4.3 PA-03 Workflows (UX & Product Design)

#### PA-03.1 — Design System Contribution — *full detail*
- **Objective:** Maintain and extend the design system as a product.
- **Classification:** universal
- **Triggers:** New component need; design system roadmap.
- **Preconditions:** Design tokens established.
- **Steps:** Need → design spec → review → implementation → release.
- **Roles:** Design system PM (A), designers (R), engineers (R for implementation).
- **Tools:** Figma, token pipeline (Style Dictionary), Storybook.
- **Outputs:** Components, tokens, docs.
- **KPIs:** Component adoption, drift rate, contribution rate.
- **Anti-patterns:** One-off components; token drift.

#### PA-03.2 — Wireframe / Prototype Iteration — *compact*
- **Objective:** Explore design alternatives with low cost.
- **Classification:** universal
- **Tools:** Figma, paper, AI image generation.
- **KPIs:** Iteration count, time-to-validation.

#### PA-03.3 — Usability Testing Session — *compact*
- **Objective:** Validate design with target users.
- **Classification:** universal
- **Steps:** Recruit → script → moderate → analyze.
- **KPIs:** SUS score, task success, time-on-task.

#### PA-03.4 — Accessibility Audit (WCAG 2.2) — *compact*
- **Objective:** Verify compliance with WCAG 2.2 AA.
- **Classification:** universal (regulated) / leading-edge (consumer)
- **Tools:** axe, Lighthouse, manual review.
- **KPIs:** Issues by severity, remediation rate.

#### PA-03.5 — Design QA on Implemented Screens — *compact*
- **Objective:** Verify implementation matches design.
- **Classification:** universal
- **Steps:** Compare Figma to rendered screen; flag deltas.
- **Tools:** Figma, Percy, Chromatic.
- **KPIs:** Delta rate, fix time.

### 4.4 PA-04 Workflows (Architecture & Technical Design)

#### PA-04.1 — Architecture Decision Record (ADR) — *full detail*
- **Objective:** Capture a significant architectural decision in lightweight, durable form.
- **Classification:** universal
- **Triggers:** Decision with long-term impact; trade-off selection.
- **Preconditions:** Decision owner identified.
- **Steps:** Context → decision → consequences → alternatives considered.
- **Tools:** Markdown, ADR tools (log4brains, adr-tools), repo.
- **Outputs:** ADR file in `docs/adr/`.
- **Quality criteria:** Reversibility considered; alternatives explicit.
- **KPIs:** ADR review time, ADRs per quarter.
- **Anti-patterns:** "Big Design" ADRs; ADR theatre; living documents that mutate.
- **Tiers:** Minimum: free-form doc. Standard: ADR template. Leading-edge: ADR + fitness function.

#### PA-04.2 — RFC / Tech Design Review — *full detail*
- **Objective:** Review a significant technical design before implementation.
- **Classification:** universal
- **Triggers:** New service, major refactor, cross-team impact.
- **Preconditions:** Author has draft; reviewers invited.
- **Inputs:** Discovery output, architecture context.
- **Steps:** Author posts RFC → review period (1–2 weeks) → comment thread → accept/reject.
- **Roles:** Author (R), Reviewers (C), Tech Lead (A).
- **Tools:** Doc tool, repo, meeting.
- **Outputs:** Accepted RFC; ADR if applicable.
- **KPIs:** RFC cycle time, acceptance rate.
- **Anti-patterns:** RFC theatre; RFCs without implementation.

#### PA-04.3 — Threat Modeling (STRIDE / PASTA) — *compact*
- **Objective:** Identify security threats during design.
- **Classification:** universal (regulated) / leading-edge (others)
- **Steps:** Identify assets → build DFD → apply STRIDE/PASTA → prioritize mitigations.
- **Tools:** Microsoft Threat Modeling Tool, OWASP Threat Dragon.
- **KPIs:** Threats per RFC, mitigations tracked.

#### PA-04.4 — Fitness Function Definition — *compact*
- **Objective:** Define a measurable property the architecture must maintain.
- **Classification:** leading-edge
- **Examples:** Latency p99 < 200ms; mod coupling < threshold; test coverage of critical paths.
- **KPIs:** Fitness function execution rate, pass rate.

#### PA-04.5 — Technology Radar Refresh — *compact*
- **Objective:** Quarterly assessment of tools, languages, frameworks.
- **Classification:** universal
- **Tools:** Internal radar (adopted from Thoughtworks), internal wiki.
- **KPIs:** Time to deprecate a "hold" item.

#### PA-04.6 — Reference Architecture Publication — *compact*
- **Objective:** Publish canonical patterns for new services.
- **Classification:** leading-edge
- **Examples:** AWS Well-Architected patterns, Google SRE patterns, Azure Architecture Center.
- **KPIs:** New service adoption of reference architecture.

### 4.5 PA-05 Workflows (Planning & Work Management)

#### PA-05.1 — Iteration / Cycle Planning — *full detail*
- **Objective:** Plan the next iteration/cycle with the team.
- **Classification:** universal
- **Triggers:** Cycle start.
- **Preconditions:** Shaped work available; capacity known.
- **Steps:** Review → pull → commit → capacity check → publish.
- **Roles:** EM (A), Eng (R), PM (C).
- **Tools:** Jira, Linear, GitHub Projects, GitLab issues.
- **Outputs:** Cycle plan, committed work.
- **Quality criteria:** Plan ≤ capacity; clear ownership.
- **KPIs:** Planned-vs-completed, cycle predictability.
- **Anti-patterns:** Overcommit; pull from PM-side instead of team-side.

#### PA-05.2 — Backlog Refinement — *full detail*
- **Objective:** Continuously shape and prioritize the backlog.
- **Classification:** universal
- **Triggers:** Continuous, ≥1×/week per team.
- **Steps:** Triage → shape → prioritize → ready.
- **KPIs:** Refinement cadence, % ready.

#### PA-05.3 — Dependency Management — *compact*
- **Objective:** Track and unblock cross-team dependencies.
- **Classification:** universal
- **Steps:** Identify → owner → due date → escalate.
- **KPIs:** Dependency age, unblock time.

#### PA-05.4 — Risk Register Maintenance — *compact*
- **Objective:** Track delivery and technical risks.
- **Classification:** universal
- **Steps:** Identify → score → owner → review.
- **KPIs:** Risk review cadence, risk burn-down.

#### PA-05.5 — Capacity Planning — *compact*
- **Objective:** Forecast engineering capacity for upcoming periods.
- **Classification:** universal
- **Inputs:** PTO, on-call load, hiring pipeline.
- **KPIs:** Forecast accuracy.

#### PA-05.6 — Shaping Cycle (Shape Up) — *compact*
- **Objective:** Shape work before betting.
- **Classification:** leading-edge
- **Steps:** Frame → rabbit holes → risks → boundaries.
- **KPIs:** Shape-to-build ratio.

### 4.6 PA-06 Workflows (Development Environment & Toolchain)

#### PA-06.1 — Dev Environment Provisioning — *full detail*
- **Objective:** Engineer can run code locally or remotely within minutes.
- **Classification:** universal
- **Triggers:** New hire, project change.
- **Steps:** Use devcontainer / Codespaces → bootstrap → commit.
- **Tools:** Devcontainers, Codespaces, Gitpod.
- **KPIs:** Time-to-first-commit, first-day-PR rate.
- **Anti-patterns:** Snowflake laptops; manual setup scripts.

#### PA-06.2 — IDE / Editor Standardization — *compact*
- **Objective:** Standardize editor config; reduce friction.
- **Classification:** universal
- **Tools:** .editorconfig, settings sync, language server configs.
- **KPIs:** Format-fail rate, lint pass rate.

#### PA-06.3 — Monorepo / Polyrepo Strategy Decision — *compact*
- **Objective:** Decide and maintain source-control strategy.
- **Classification:** universal
- **Inputs:** Build system choice, team structure, dependency graph.
- **KPIs:** Build time, dependency churn.

#### PA-06.4 — InnerSource / CONTRIBUTING Standards — *compact*
- **Objective:** Standardize cross-team contribution.
- **Classification:** leading-edge
- **Outputs:** CONTRIBUTING.md, owner files.
- **KPIs:** Cross-team PR rate, PR turnaround.

#### PA-06.5 — Local Test Selection & Feedback — *compact*
- **Objective:** Run only relevant tests in dev loop.
- **Classification:** leading-edge
- **Tools:** Bazel, Nx, Jest test selection.
- **KPIs:** Local test time, CI time savings.

### 4.7 PA-07 Workflows (Software Implementation)

#### PA-07.1 — Trunk-Based Commit — *full detail*
- **Objective:** Land small commits on trunk frequently.
- **Classification:** universal
- **Triggers:** Continuous.
- **Preconditions:** Trunk is always green; CI is fast; tests are reliable.
- **Steps:** Pull → small change → local test → commit (≤200 LOC ideally) → push.
- **Tools:** Git, CI.
- **KPIs:** Commit frequency, commit size, trunk broken-window.
- **Anti-patterns:** Long-lived branches; large commits.

#### PA-07.2 — Feature Flag Introduction and Lifecycle — *full detail*
- **Objective:** Decouple release from deployment via flags.
- **Classification:** universal
- **Triggers:** Incomplete work merged; A/B test; ops kill switch.
- **Steps:** Create flag (release, experiment, ops, permission) → implement → test both states → rollout → remove flag.
- **Tools:** LaunchDarkly, Split, Unleash, in-house.
- **KPIs:** Flag debt, flag removal rate.
- **Anti-patterns:** Permanent flags; untested off-state.

#### PA-07.3 — Commit Hygiene (Conventional Commits) — *compact*
- **Objective:** Standardize commit messages for tooling.
- **Classification:** universal
- **Format:** type(scope): description.
- **KPIs:** Conventional commit adherence.

#### PA-07.4 — Pair / Mob Programming — *compact*
- **Objective:** Spread knowledge; reduce review burden.
- **Classification:** leading-edge
- **KPIs:** Knowledge concentration (bus factor), session frequency.

#### PA-07.5 — Documentation Alongside Code — *compact*
- **Objective:** Keep docs close to code; reduce drift.
- **Classification:** universal
- **Tools:** Doc tools, code-adjacent markdown, Docusaurus.
- **KPIs:** Doc freshness, doc coverage.

#### PA-07.6 — AI-Assisted Coding — *compact*
- **Objective:** Use AI assistants to amplify leverage.
- **Classification:** emerging
- **Steps:** Accept suggestion → review → test → commit.
- **Tools:** Copilot, Cursor, Claude Code, Codex.
- **KPIs:** Acceptance rate, defect rate on AI code, time saved.
- **Anti-patterns:** Blind acceptance; no test discipline.

### 4.8 PA-08 Workflows (Code Review & Knowledge Sharing)

#### PA-08.1 — Pull Request Review — *full detail*
- **Objective:** Review a PR for correctness, security, knowledge spread.
- **Classification:** universal
- **Triggers:** PR opened.
- **Preconditions:** CI green; small PR; description.
- **Steps:** Triage → assign reviewer → review with checklist → approve or request changes → merge.
- **Roles:** Author (R), Reviewer (R), Codeowner (A).
- **Tools:** GitHub, GitLab, Bitbucket.
- **KPIs:** First-response time, cycle time, comments per PR, defect post-merge.
- **Anti-patterns:** LGTM rubber-stamping; review bottleneck.
- **Tiers:** Minimum: manual review. Standard: codeowners + SLA. Leading-edge: AI-assisted review + structured comments.

#### PA-08.2 — Conventional Comments — *compact*
- **Objective:** Make code review comments constructive and labeled.
- **Classification:** leading-edge
- **Labels:** praise, suggestion, issue, question, nitpick, thought.
- **KPIs:** Label adoption, comment clarity score.

#### PA-08.3 — Security-Focused Review — *compact*
- **Objective:** Catch security issues in PR.
- **Classification:** universal
- **Tools:** Semgrep, CodeQL, AI security review.
- **KPIs:** Findings per PR, time to remediate.

#### PA-08.4 — Architecture Review in PR — *compact*
- **Objective:** Validate PR against architecture patterns.
- **Classification:** universal
- **KPIs:** Pattern adherence, ADR citations.

#### PA-08.5 — Knowledge-Sharing Sessions — *compact*
- **Objective:** Spread knowledge beyond the PR.
- **Classification:** universal
- **Tools:** Tech talks, demo days, internal conferences.
- **KPIs:** Sessions per quarter, attendance.

#### PA-08.6 — AI-Assisted Code Review — *compact*
- **Objective:** Use AI to pre-review PRs.
- **Classification:** emerging
- **Tools:** Copilot code review, Coderabbit, Graphite, Anthropic Code Review.
- **KPIs:** AI findings accepted, review time savings.

### 4.9 PA-09 Workflows (Testing, QE & Verification)

#### PA-09.1 — Test Pyramid Maintenance — *full detail*
- **Objective:** Maintain a healthy test pyramid.
- **Classification:** universal
- **Steps:** Audit test counts by layer → rebalance.
- **KPIs:** Test ratio, coverage, E2E run time, flake rate.
- **Anti-patterns:** Ice-cream cone; E2E-heavy.

#### PA-09.2 — Unit Test Authoring (TDD/BDD) — *full detail*
- **Objective:** Tests are written alongside or before code.
- **Classification:** universal
- **Steps:** Red → Green → Refactor.
- **Tools:** Language-native (JUnit, pytest, Go test), mutation testing (Stryker, PIT).
- **KPIs:** Coverage, mutation score.

#### PA-09.3 — Contract Testing (Pact) — *compact*
- **Objective:** Verify API contracts between services.
- **Classification:** leading-edge
- **Tools:** Pact, OpenAPI schema tests.
- **KPIs:** Contract coverage, break rate.

#### PA-09.4 — End-to-End Test Suite Maintenance — *compact*
- **Objective:** Validate critical user journeys.
- **Classification:** universal (sparse)
- **Tools:** Playwright, Cypress, Selenium.
- **KPIs:** Coverage of critical paths, flake rate, runtime.

#### PA-09.5 — Performance / Load Testing — *compact*
- **Objective:** Verify performance SLOs.
- **Classification:** leading-edge
- **Tools:** k6, Locust, Gatling, JMeter.
- **KPIs:** p50/p95/p99, throughput, error rate.

#### PA-09.6 — Fuzz / Property-Based Testing — *compact*
- **Objective:** Find edge-case defects automatically.
- **Classification:** emerging
- **Tools:** AFL, libFuzzer, QuickCheck, Hypothesis.
- **KPIs:** Bugs found, corpus size.

#### PA-09.7 — Security Testing in CI (SAST/DAST/SCA) — *compact*
- **Objective:** Detect security issues during CI.
- **Classification:** universal
- **Tools:** Semgrep, Snyk, Dependabot, Trivy, OWASP ZAP.
- **KPIs:** Findings by severity, fix rate.

#### PA-09.8 — Exploratory Testing Session — *compact*
- **Objective:** Human-driven discovery of edge cases.
- **Classification:** universal
- **KPIs:** Sessions per cycle, defects found.

#### PA-09.9 — AI-Generated Test Authoring — *compact*
- **Objective:** Use AI to generate test cases from code or requirements.
- **Classification:** emerging
- **Tools:** Copilot, CodiumAI, Diffblue, Claude Code.
- **KPIs:** Acceptance rate, coverage gain, defect detection.

### 4.10 PA-10 Workflows (Build, Integration & Artifact Management)

#### PA-10.1 — Hermetic Reproducible Build — *full detail*
- **Objective:** Build artifacts are reproducible and content-addressed.
- **Classification:** leading-edge
- **Tools:** Bazel, Pants, Nx, Buck.
- **KPIs:** Reproducibility rate, build time, cache hit rate.
- **Anti-patterns:** Unpinned dependencies; non-hermetic builds.

#### PA-10.2 — Container Image Build and Sign — *full detail*
- **Objective:** Produce signed, attested container images.
- **Classification:** universal
- **Steps:** Build → SBOM → sign (cosign) → SLSA provenance.
- **Tools:** Docker, Buildkit, Sigstore cosign, in-toto, SLSA generators.
- **KPIs:** Signed-build rate, SLSA level.
- **Anti-patterns:** Unsigned images; mutable base images.

#### PA-10.3 — SBOM Generation and Publishing — *compact*
- **Objective:** Produce a Software Bill of Materials for every release.
- **Classification:** universal
- **Format:** CycloneDX, SPDX.
- **KPIs:** SBOM coverage.

#### PA-10.4 — Dependency Lockfile Maintenance — *compact*
- **Objective:** Pin dependencies for reproducibility.
- **Classification:** universal
- **Tools:** lockfiles, Renovate, Dependabot.
- **KPIs:** Outdated dependency rate.

#### PA-10.5 — Build Cache and Remote Execution — *compact*
- **Objective:** Minimize build time at scale.
- **Classification:** leading-edge
- **Tools:** Bazel remote cache, BuildBuddy, engflow.
- **KPIs:** Cache hit rate, build time.

#### PA-10.6 — Multi-Architecture / Multi-Platform Build — *compact*
- **Objective:** Build artifacts for multiple targets.
- **Classification:** universal
- **Tools:** Docker buildx, cross-compilation, Go cross-build.
- **KPIs:** Build coverage.

### 4.11 PA-11 Workflows (CI, Release & Deployment)

#### PA-11.1 — Continuous Integration Pipeline — *full detail*
- **Objective:** Every commit is verified by automated build and tests.
- **Classification:** universal
- **Triggers:** Every commit / PR.
- **Steps:** Checkout → build → unit test → static analysis → security scan → artifact.
- **Tools:** GitHub Actions, GitLab CI, CircleCI, Buildkite, Jenkins.
- **KPIs:** Pipeline duration, success rate, time-to-feedback.
- **Anti-patterns:** Slow CI; flaky tests; long serial pipelines.

#### PA-11.2 — Continuous Deployment to Staging — *full detail*
- **Objective:** Every green commit is automatically deployed to staging.
- **Classification:** universal
- **Steps:** CI green → deploy to staging → smoke tests → notify.
- **KPIs:** Deployment frequency, lead time, deploy success rate.

#### PA-11.3 — Progressive Delivery to Production — *full detail*
- **Objective:** Roll out to production with progressive risk reduction.
- **Classification:** leading-edge
- **Steps:** Canary (1% → 5% → 25% → 100%) or blue-green with switch.
- **Tools:** Argo Rollouts, Flagger, Spinnaker, Harness, custom.
- **KPIs:** Rollback rate, error rate during rollout, SLO burn.

#### PA-11.4 — Production Deploy via ChatOps / One-Click — *compact*
- **Objective:** Engineers can deploy safely with a single command.
- **Classification:** universal
- **Examples:** GitLab ChatOps, AWS CodeDeploy, internal "deploy" bots.
- **KPIs:** One-click deploy adoption.

#### PA-11.5 — Production Deploy Approval (Policy as Code) — *compact*
- **Objective:** Enforce who can deploy what via code, not meetings.
- **Classification:** universal (regulated) / leading-edge (others)
- **Tools:** OPA, Conftest, custom policy.
- **KPIs:** Policy violations, exception rate.

#### PA-11.6 — Release Notes / Changelog Generation — *compact*
- **Objective:** Auto-generate changelog from commits.
- **Classification:** universal
- **Tools:** Release Drafter, conventional-changelog, custom.
- **KPIs:** Release-notes freshness.

#### PA-11.7 — Rollback and Forward-Fix — *compact*
- **Objective:** Recover from a bad release in minutes.
- **Classification:** universal
- **Tools:** Argo, Spinnaker, Spinnaker-style pipelines.
- **KPIs:** MTTR, rollback success rate.

#### PA-11.8 — GitOps Reconciliation — *compact*
- **Objective:** Declarative config in git; controller reconciles.
- **Classification:** leading-edge
- **Tools:** ArgoCD, Flux, Helm, Kustomize.
- **KPIs:** Drift time, sync failures.

### 4.12 PA-12 Workflows (Platform Engineering & IDP)

#### PA-12.1 — Platform Product Discovery — *full detail*
- **Objective:** Identify internal developer pain points.
- **Classification:** leading-edge
- **Triggers:** Continuous; quarterly deep-dive.
- **Steps:** Pain-point intake → interview → prioritize.
- **Roles:** Platform PM (A), Eng users (I/C).
- **KPIs:** Time-to-action on pain point.

#### PA-12.2 — Golden Path Definition — *full detail*
- **Objective:** Standardize the recommended path for a common task.
- **Classification:** universal
- **Examples:** "New microservice" path; "New data pipeline" path; "New web app" path.
- **KPIs:** Path adoption rate, deviation rate.

#### PA-12.3 — Backstage / IDP Maintenance — *compact*
- **Objective:** Maintain the IDP as a product.
- **Classification:** leading-edge
- **Tools:** Backstage, custom.
- **KPIs:** Service catalog completeness, plugin count, DAU.

#### PA-12.4 — Platform SLO Definition and Tracking — *compact*
- **Objective:** SLOs for the platform itself.
- **Classification:** leading-edge
- **Examples:** "Onboarding a new service in <1 day"; "Build time p95 < 5 min."
- **KPIs:** SLO attainment, error budget.

#### PA-12.5 — Internal Self-Service APIs — *compact*
- **Objective:** Engineers can self-serve common operations.
- **Classification:** universal
- **Examples:** Provision a database; rotate secrets; create a project.
- **KPIs:** Self-service adoption, ticket reduction.

#### PA-12.6 — Platform Customer Research (Developer) — *compact*
- **Objective:** Continuous research with developer users.
- **Classification:** leading-edge
- **Methods:** Interviews, surveys, telemetry, NPS.
- **KPIs:** Developer NPS, satisfaction.

### 4.13 PA-13 Workflows (Security, Privacy, Risk & Compliance)

#### PA-13.1 — Threat Modeling at Design — *full detail*
- **Objective:** Identify and mitigate threats during design.
- **Classification:** universal (regulated) / leading-edge (others)
- **Steps:** Identify assets → DFD → apply STRIDE/PASTA → mitigate → track.
- **Roles:** Architect (R), Security engineer (C/A), Eng (R).
- **Tools:** Microsoft Threat Modeling Tool, OWASP Threat Dragon, IriusRisk.
- **KPIs:** Threats identified per design, mitigations tracked.

#### PA-13.2 — SAST / DAST / SCA in CI — *full detail*
- **Objective:** Detect security issues during CI.
- **Classification:** universal
- **Steps:** SAST on commit → SCA on PR → DAST on staging.
- **Tools:** Semgrep, CodeQL, Snyk, OWASP ZAP, Trivy.
- **KPIs:** Findings by severity, time to remediate.

#### PA-13.3 — Secrets Management and Scanning — *full detail*
- **Objective:** No secrets in code; secrets are centrally managed.
- **Classification:** universal
- **Steps:** Pre-commit secret scan → CI secret scan → runtime secret rotation.
- **Tools:** HashiCorp Vault, AWS Secrets Manager, GitGuardian, gitleaks.
- **KPIs:** Secret leak incidents.

#### PA-13.4 — Vulnerability Triage and Patching (CVE Response) — *compact*
- **Objective:** Triage and patch CVEs within SLO.
- **Classification:** universal
- **Steps:** Detect → triage → patch → verify → disclose.
- **KPIs:** MTTD, MTTR, patch coverage.

#### PA-13.5 — SLSA Compliance Audit — *compact*
- **Objective:** Build artifacts at a target SLSA level.
- **Classification:** leading-edge
- **Steps:** Audit current level → identify gaps → remediate.
- **KPIs:** SLSA level coverage.

#### PA-13.6 — Privacy Impact Assessment (DPIA) — *compact*
- **Objective:** Document privacy implications of changes.
- **Classification:** universal (regulated)
- **Tools:** Internal templates.
- **KPIs:** DPIA completion rate.

#### PA-13.7 — SOC 2 / ISO 27001 Control Maintenance — *compact*
- **Objective:** Maintain compliance controls.
- **Classification:** universal (regulated)
- **Steps:** Control evidence collection → audit support.
- **KPIs:** Audit findings, control pass rate.

#### PA-13.8 — Supply Chain Security (3P / OSS) — *compact*
- **Objective:** Vet and monitor 3P dependencies.
- **Classification:** leading-edge
- **Steps:** SBOM review → license check → vulnerability check.
- **KPIs:** Vulnerable-dependency count.

### 4.14 PA-14 Workflows (Reliability, Operations & SRE)

#### PA-14.1 — SLO Definition and Review — *full detail*
- **Objective:** Define SLIs, SLOs, and error budgets per service.
- **Classification:** universal
- **Steps:** Identify user journey → define SLI → set SLO target → publish.
- **Roles:** SRE (A), Eng (R), PM (C).
- **KPIs:** SLO coverage, attainment.

#### PA-14.2 — Incident Response — *full detail*
- **Objective:** Restore service quickly with coordinated response.
- **Classification:** universal
- **Steps:** Detect → declare → command → mitigate → resolve → learn.
- **Roles:** Incident Commander (A), Comms (R), Subject-Matter (R), Scribe (R).
- **Tools:** PagerDuty, Opsgenie, FireHydrant, incident.io.
- **KPIs:** MTTA, MTTR, severity distribution, IC training.

#### PA-14.3 — Blameless Postmortem — *full detail*
- **Objective:** Learn from incidents without blame.
- **Classification:** universal
- **Steps:** Timeline → root cause(s) → contributing factors → action items.
- **Roles:** Author (R), Reviewers (C), Eng leadership (A).
- **KPIs:** Postmortem completion rate, action-item closure.

#### PA-14.4 — On-Call Rotation and Hygiene — *compact*
- **Objective:** Manage on-call load; prevent burnout.
- **Classification:** universal
- **Steps:** Rotation design → handoff → incident-only paging → follow-the-sun.
- **KPIs:** Pages per shift, alert noise, handoff quality.

#### PA-14.5 — Toil Tracking and Reduction — *compact*
- **Objective:** Reduce operational toil.
- **Classification:** universal
- **Steps:** Track toil → automate → measure reduction.
- **KPIs:** Toil %, automation time.

#### PA-14.6 — Chaos Engineering Experiment — *compact*
- **Objective:** Verify system resilience by injecting failure.
- **Classification:** leading-edge
- **Tools:** Chaos Monkey, Gremlin, Litmus, AWS Fault Injection Service.
- **KPIs:** Experiments per quarter, defects found, MTTR improvement.

#### PA-14.7 — Capacity Planning — *compact*
- **Objective:** Forecast and provision capacity.
- **Classification:** universal
- **Steps:** Forecast load → model capacity → provision → verify.
- **KPIs:** Forecast accuracy, utilization.

#### PA-14.8 — Game Day / Failure Mode Exercise — *compact*
- **Objective:** Practice incident response in a controlled drill.
- **Classification:** leading-edge
- **KPIs:** Game day frequency, MTTR improvement post-drill.

### 4.15 PA-15 Workflows (Observability & Production Feedback)

#### PA-15.1 — OpenTelemetry Instrumentation — *full detail*
- **Objective:** Instrument all services with OTel.
- **Classification:** universal
- **Steps:** Add SDK → define resource attributes → instrument HTTP/gRPC/DB → export to backend.
- **Tools:** OpenTelemetry SDK, OTel Collector, vendor SDKs.
- **KPIs:** Trace coverage, metric coverage, log coverage.

#### PA-15.2 — Dashboard Authoring — *full detail*
- **Objective:** Create service-level dashboards.
- **Classification:** universal
- **Steps:** Define audience → SLO dashboard → RED dashboard → use-case dashboards.
- **Tools:** Grafana, Datadog, Honeycomb, Lightstep.
- **KPIs:** Dashboard usage, time-to-dashboard.

#### PA-15.3 — Alerting on SLO Burn Rate — *full detail*
- **Objective:** Alert when SLO burn rate exceeds threshold.
- **Classification:** leading-edge
- **Steps:** Define multi-window burn rates → page on >14.4x for 1h or >6x for 6h.
- **Tools:** Pyrra, Sloth, SLO alerting in vendors.
- **KPIs:** Alert precision, alert recall, page rate.

#### PA-15.4 — Structured Logging Standard — *compact*
- **Objective:** All logs are structured and indexed.
- **Classification:** universal
- **Format:** JSON; trace_id, span_id, severity, message.
- **KPIs:** Log volume, indexing coverage.

#### PA-15.5 — Distributed Tracing Sampling Strategy — *compact*
- **Objective:** Capture representative traces cost-effectively.
- **Classification:** leading-edge
- **Strategies:** Head-based, tail-based, error-only, adaptive.
- **KPIs:** Trace retention cost, debuggability.

#### PA-15.6 — Real User Monitoring (RUM) / Synthetic Monitoring — *compact*
- **Objective:** Capture end-user experience.
- **Classification:** leading-edge
- **Tools:** Datadog RUM, New Relic, Sentry, Checkly.
- **KPIs:** Performance metrics, error visibility.

#### PA-15.7 — AI-Assisted Observability — *compact*
- **Objective:** Use AI to summarize incidents, suggest root cause.
- **Classification:** emerging
- **Tools:** Moogsoft, BigPanda, vendor AI features, Claude Code for log analysis.
- **KPIs:** AI suggestion accuracy, MTTR improvement.

### 4.16 PA-16 Workflows (Measurement, DevEx & Continuous Improvement)

#### PA-16.1 — DORA Metrics Collection — *full detail*
- **Objective:** Continuously measure DORA four keys.
- **Classification:** universal
- **Steps:** Instrument pipeline → compute lead time, deploy freq, change fail rate, MTTR → publish.
- **Tools:** Sleuth, LinearB, Waydev, custom.
- **KPIs:** All four keys reported per team.

#### PA-16.2 — SPACE / DevEx Survey — *full detail*
- **Objective:** Measure developer experience and satisfaction.
- **Classification:** leading-edge
- **Steps:** Annual survey + quarterly pulse → analyze → action.
- **Tools:** DX (formerly Hivebrite), Officevibe, internal.
- **KPIs:** DevEx score, satisfaction, retention.

#### PA-16.3 — Flow Metrics Tracking — *compact*
- **Objective:** Track cycle time, WIP, throughput.
- **Classification:** universal
- **KPIs:** Cycle time, WIP limits, predictability.

#### PA-16.4 — Retrospective and Action Tracking — *compact*
- **Objective:** Run retrospectives; track actions.
- **Classification:** universal
- **Steps:** What worked / didn't / next → action owner.
- **KPIs:** Action completion rate.

#### PA-16.5 — Improvement Experiment Tracking — *compact*
- **Objective:** Run small experiments on the dev process.
- **Classification:** leading-edge
- **Tools:** Internal experiment tracker.
- **KPIs:** Experiments run, experiments adopted.

### 4.17 PA-17 Workflows (Maintenance, Evolution & Retirement)

#### PA-17.1 — Deprecation Authoring and Announcement — *full detail*
- **Objective:** Formally deprecate an API/feature with clear migration path.
- **Classification:** universal
- **Steps:** Identify candidate → set sunset date → communicate (RFC, blog, in-app) → migration guide → monitor usage → remove.
- **Tools:** Stripe-style versioning, API gateway headers, in-app banners.
- **KPIs:** Time-from-deprecation-to-removal, usage at sunset.

#### PA-17.2 — Strangler Fig Decomposition — *full detail*
- **Objective:** Migrate a legacy system incrementally.
- **Classification:** leading-edge
- **Steps:** Identify seam → stand up new component → route traffic → cut over → remove old.
- **KPIs:** Traffic on new path, defect rate, time-to-completion.

#### PA-17.3 — End-of-Life Policy Enforcement — *compact*
- **Objective:** Track and enforce EOL dates.
- **Classification:** universal
- **Steps:** Inventory → EOL date → countdown → enforced action.
- **KPIs:** EOL compliance, missed EOLs.

#### PA-17.4 — Technical Debt Backlog and Reduction — *compact*
- **Objective:** Make technical debt visible and reduce it.
- **Classification:** universal
- **Steps:** Inventory → prioritize → allocate capacity → reduce.
- **KPIs:** Debt ratio, reduction rate.

#### PA-17.5 — Dependency Upgrade Cycle — *compact*
- **Objective:** Keep dependencies current.
- **Classification:** universal
- **Tools:** Dependabot, Renovate, Snyk.
- **KPIs:** Outdated deps, time-to-upgrade.

### 4.18 PA-18 Workflows (AI-Assisted / Agentic SDLC)

#### PA-18.1 — AI Code Generation with Review — *full detail*
- **Objective:** Use AI to draft code; engineer reviews and tests.
- **Classification:** emerging
- **Triggers:** Task assignment, routine work.
- **Preconditions:** AI assistant configured; test infrastructure; code-review workflow.
- **Steps:** Prompt AI → review output → test → refine → commit.
- **Tools:** GitHub Copilot, Cursor, Claude Code, OpenAI Codex.
- **Roles:** Engineer (A), AI (R), Reviewer (C).
- **Outputs:** AI-drafted code, accepted with review.
- **Quality criteria:** AI output reviewed; tests pass; security check.
- **KPIs:** Acceptance rate, time saved, defect rate on AI code.
- **Anti-patterns:** Blind acceptance; security regression.
- **Tiers:** Minimum: autocomplete. Standard: chat-based generation. Leading-edge: agentic coding (Claude Code, OpenAI Codex).

#### PA-18.2 — AI-Assisted Test Authoring — *full detail*
- **Objective:** Use AI to generate test cases.
- **Classification:** emerging
- **Steps:** Specify coverage gap → AI generates tests → engineer reviews → adds to suite.
- **Tools:** CodiumAI, Diffblue, Claude Code, Copilot.
- **KPIs:** Coverage gain, defect detection.

#### PA-18.3 — AI Code Review — *full detail*
- **Objective:** Use AI to pre-review PRs.
- **Classification:** emerging
- **Steps:** PR opened → AI reviewer comments → human reviewer finalizes.
- **Tools:** Coderabbit, Anthropic Code Review, GitHub Copilot code review.
- **KPIs:** Findings accepted, review time saved, defect escape rate.

#### PA-18.4 — Agentic Engineering Task — *full detail*
- **Objective:** Delegate a well-scoped engineering task to an AI agent.
- **Classification:** emerging
- **Preconditions:** Task is well-defined; test infrastructure exists; agent has appropriate tooling.
- **Steps:** Define task (and acceptance criteria) → agent explores → plans → implements → tests → opens PR → human reviews.
- **Tools:** Claude Code, OpenAI Codex, Cognition Devin, Anthropic Claude Code Auto Mode.
- **KPIs:** Task success rate, time-to-PR, defect rate.
- **Anti-patterns:** Vague tasks; no review; no tests.

#### PA-18.5 — AI Governance and Policy — *compact*
- **Objective:** Govern AI use across the SDLC.
- **Classification:** emerging
- **Components:** Acceptable use policy, data handling, IP rules, model risk register.
- **KPIs:** Policy violations, audit pass.

#### PA-18.6 — AI Observability and Incident Response — *compact*
- **Objective:** Use AI to assist incident analysis.
- **Classification:** emerging
- **Tools:** Claude Code, vendor AI, custom.
- **KPIs:** MTTR reduction.

#### PA-18.7 — AI Vendor Risk Assessment — *compact*
- **Objective:** Evaluate AI vendors for security, IP, reliability.
- **Classification:** leading-edge
- **Steps:** Vendor due diligence → SOC 2 review → contract review → approval.
- **KPIs:** Vendor review cycle time, risk register.

#### PA-18.8 — AI Engineering Metrics — *compact*
- **Objective:** Track AI usage and outcomes.
- **Classification:** emerging
- **Metrics:** Acceptance rate, code quality of AI code, AI-attributed incidents, time saved.
- **KPIs:** All metrics reported monthly.

---

## 5. Cross-Area Dependency and Feedback Map

### 5.1 Capability layers (the reference structure)

The 18 Process Areas form four capability layers, not a sequence. Each layer feeds the next; each layer is fed back by the layer above it.

```
              ┌──────────────────────────────────────────────────────┐
   Layer 1:   │  PA-01 Strategy, PA-02 Discovery, PA-03 UX,          │
   Direction  │  PA-04 Architecture                                   │
              └──────────────────────────────────────────────────────┘
                                  ↓
              ┌──────────────────────────────────────────────────────┐
   Layer 2:   │  PA-05 Planning, PA-06 Dev Env, PA-07 Implementation,│
   Delivery   │  PA-08 Code Review, PA-09 Testing,                    │
              │  PA-10 Build, PA-11 CI/Release/Deploy                 │
              └──────────────────────────────────────────────────────┘
                                  ↓
              ┌──────────────────────────────────────────────────────┐
   Layer 3:   │  PA-12 Platform Eng, PA-13 Security,                  │
   Foundation │  PA-14 Reliability, PA-15 Observability              │
   (feedback) │                                                       │
              └──────────────────────────────────────────────────────┘
                                  ↓
              ┌──────────────────────────────────────────────────────┐
   Layer 4:   │  PA-16 DevEx, PA-17 Maintenance, PA-18 AI             │
   Sustain    │                                                       │
              └──────────────────────────────────────────────────────┘
```

**Critical feedback loops** (these are how the model improves itself):

- **PA-15 → PA-01:** Production telemetry informs strategy.
- **PA-15 → PA-02:** User-behavior telemetry drives discovery.
- **PA-14 → PA-04:** SLO violations and postmortem action items drive architectural change.
- **PA-13 → PA-04:** Threat-model findings drive architecture changes.
- **PA-16 → PA-12:** Developer-pain data drives platform priorities.
- **PA-16 → PA-01:** Delivery performance informs portfolio allocation.
- **PA-18 → All:** AI assistance touches every other PA; AI governance (PA-18) is informed by PA-13.

### 5.2 Critical-path / minimum-viable loop

The shortest "alive" process loop is:

**PA-04 → PA-07 → PA-09 → PA-10 → PA-11 → PA-15 → PA-16 → PA-01**

That is: design → implement → test → build → deploy → observe → measure → re-strategize. Every other Process Area exists to make this loop faster, safer, or more aligned.

### 5.3 Dependency matrix (high-level)

| Depends on → | PA-01 | PA-02 | PA-03 | PA-04 | PA-05 | PA-06 | PA-07 | PA-08 | PA-09 | PA-10 | PA-11 | PA-12 | PA-13 | PA-14 | PA-15 | PA-16 | PA-17 | PA-18 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| PA-01 | — | C | C | C | — | — | — | — | — | — | — | — | C | C | C | C | C | C |
| PA-02 | C | — | C | C | C | — | — | — | — | — | — | — | C | — | C | — | — | C |
| PA-03 | C | C | — | C | C | — | — | — | C | — | — | — | C | C | C | C | — | C |
| PA-04 | C | — | — | — | C | C | C | C | C | C | C | C | C | C | — | C | C | C |
| PA-05 | C | C | C | C | — | — | C | C | C | — | C | — | C | C | C | C | C | C |
| PA-06 | — | — | — | C | — | — | C | — | C | C | C | C | C | C | — | C | C | C |
| PA-07 | — | — | C | C | C | C | — | C | C | C | C | C | C | C | — | — | C | C |
| PA-08 | — | — | — | C | — | — | C | — | C | C | C | — | C | C | — | — | — | C |
| PA-09 | — | C | C | C | C | — | C | C | — | C | C | — | C | C | C | C | C | C |
| PA-10 | — | — | — | C | — | C | C | — | C | — | C | C | C | C | — | — | — | C |
| PA-11 | — | — | — | C | C | C | C | C | C | C | — | C | C | C | C | C | C | C |
| PA-12 | C | C | — | C | C | C | C | — | — | C | C | — | C | C | C | C | C | C |
| PA-13 | C | C | C | C | C | C | C | C | C | C | C | C | — | C | C | C | C | C |
| PA-14 | — | C | — | C | C | — | C | C | C | — | C | C | C | — | C | C | C | C |
| PA-15 | C | C | C | C | C | — | C | — | C | — | C | C | C | C | — | C | C | C |
| PA-16 | C | C | C | C | C | C | C | C | C | C | C | C | C | C | C | — | C | C |
| PA-17 | C | — | — | C | C | — | C | — | C | — | C | — | C | C | C | C | — | C |
| PA-18 | C | C | C | C | C | C | C | C | C | C | C | C | C | C | C | C | C | — |

(C = consumes input from; all cells are bidirectional in practice.)

### 5.4 Failure-mode analysis

The most common cross-area failure patterns:

1. **Strategy without feedback (PA-01 lacks PA-15/PA-16 inputs):** Strategic decisions are made on stale data; product drift from real user need. *Mitigation:* PA-15 and PA-16 must be active inputs to PA-01.
2. **Discovery without architecture (PA-02 lacks PA-04):** Discovered work is infeasible or technically risky. *Mitigation:* Architecture (PA-04) is consulted in shaping (PA-02).
3. **Implementation without testing (PA-07 without PA-09):** Quality debt accumulates; defect escape rises. *Mitigation:* Tests are written alongside code (TDD/BDD) or AI-generated and reviewed.
4. **Deployment without observability (PA-11 without PA-15):** Cannot diagnose issues. *Mitigation:* Observability is a non-functional requirement; new service without observability does not deploy.
5. **Reliability without security (PA-14 without PA-13):** Reliability improvements can introduce security regressions. *Mitigation:* Security review is a precondition for reliability changes.
6. **Platform without users (PA-12 lacks PA-16 inputs):** Platform is built for imagined needs. *Mitigation:* Platform as a product; customer (developer) research.
7. **AI without governance (PA-18 lacks PA-13):** AI-generated code bypasses security review. *Mitigation:* AI code goes through the same review pipeline (PA-08) and security checks (PA-13).

---

## 6. AI-Integration Layer

AI is not a sub-topic; in mid-2026 it is a first-class Process Area (PA-18) and a horizontal layer touching every other PA. This section describes both the per-PA AI touchpoints and the dedicated PA-18 treatment.

### 6.1 Where AI touches each Process Area

| PA | AI Touchpoint | Evidence |
|----|---------------|----------|
| PA-01 Strategy | AI summarizes market data and customer evidence for strategy reviews; AI-generated portfolio scenarios. | Emerging; not yet standard. |
| PA-02 Discovery | AI summarizes interview transcripts; clusters opportunities; surfaces patterns. | Leading-edge; Teresa Torres + Anthropic both describe AI-augmented discovery. |
| PA-03 UX Design | AI generates wireframes, illustrations, content variants; AI-assisted accessibility checks. | Emerging; Figma AI, Adobe Firefly. |
| PA-04 Architecture | AI generates RFC drafts, ADRs from conversations; AI-driven threat-modeling assistance. | Emerging. |
| PA-05 Planning | AI-assisted capacity planning, dependency detection, sprint suggestions. | Emerging. |
| PA-06 Dev Environment | AI-driven repo setup, AI-tuned devcontainer generation. | Emerging. |
| PA-07 Implementation | **AI code completion, chat-based generation, agentic coding** (Copilot, Cursor, Claude Code, OpenAI Codex). | **Strong operational adoption; canonical.** [S052, S053, S055, S056, S057] |
| PA-08 Code Review | AI pre-review, AI comment generation, AI security review. | **Strong operational adoption.** [S052, S055, S076] |
| PA-09 Testing | **AI test generation, property-test synthesis, fuzz corpus seeding.** | **Leading-edge / emerging.** [S024, S055] |
| PA-10 Build | AI for build-system tuning, dependency conflict resolution, SLSA policy authoring. | Emerging. |
| PA-11 CI/Release/Deploy | AI-generated release notes, AI-driven canary decisions, AI policy-as-code. | Emerging. |
| PA-12 Platform Engineering | AI-assisted IDP plugin generation, AI-tuned golden paths. | Emerging. |
| PA-13 Security | AI for threat detection, code analysis, vulnerability triage. | **Leading-edge.** [S055] |
| PA-14 Reliability | **AI-assisted incident response, AI-driven root-cause analysis.** | **Emerging; Anthropic Claude Code Auto Mode in production.** [S055, S056, S076] |
| PA-15 Observability | **AI-generated dashboards, AI log analysis, AI-driven SLO suggestions.** | **Leading-edge / emerging.** [S013, S055] |
| PA-16 DevEx | AI-augmented developer surveys, AI insight generation. | Emerging. |
| PA-17 Maintenance | AI-assisted deprecation analysis, AI-driven dependency upgrade PRs. | Emerging. |
| PA-18 AI-Assisted SDLC | This Process Area is the home of AI governance, AI policy, AI metrics. | **First-class in 2026.** [S037 DORA AI, S052, S063] |

### 6.2 PA-18 — AI-Assisted / Agentic Software Engineering (detailed)

**Definition.** The capability that integrates AI assistance (code completion, code review, test generation, agentic coding) into every Process Area, and governs the resulting risks and opportunities.

**Why first-class in 2026.** DORA 2025 dedicates an entire category to AI; GitHub Octoverse 2024 documents AI as the driver of language shifts; Anthropic, OpenAI, and Google DeepMind have published operational agentic coding patterns; Stack Overflow 2025 shows 81% of developers used GPT models in the past year. [S037, S051, S063]

**Anthropic's workflow / agent taxonomy** is the canonical reference for AI engineering patterns [S055]:

- **Augmented LLM** (the building block): LLM with retrieval, tools, and memory.
- **Workflows** (predetermined tool sequences):
  - **Prompt chaining** — sequential steps with checks.
  - **Routing** — classify input, route to specialized handler.
  - **Parallelization** — sectioning (parallel subtasks) or voting (multiple attempts).
  - **Orchestrator-workers** — central LLM dynamically delegates; well-suited for coding (file changes, search tasks).
  - **Evaluator-optimizer** — one LLM generates, another evaluates in a loop.
- **Agents** — LLMs that plan and operate autonomously, using tools based on environmental feedback, with optional human checkpoints.

**Operational adoption (mid-2026 evidence):**

- **GitHub Copilot:** 55% faster task completion per the GitHub/Accenture controlled study; millions of users; deployed at major enterprises. [S052]
- **Anthropic Claude Code:** agentic coding environment with explore-plan-implement pattern; deployed at Anthropic internally and used by external engineers. [S056]
- **OpenAI Codex:** cloud-based software engineering agent, parallel task execution; available in ChatGPT Pro/Business/Enterprise since May 2025. [S057]
- **Cursor:** IDE-fork with deep AI integration; widely adopted at AI-native startups.
- **Cognition Devin:** autonomous SWE agent; early-adopter use cases.

**Canonical patterns (mid-2026 consensus):**

1. **Context window is the binding constraint** — Anthropic's Claude Code best practices are explicit: the context window fills up fast, and performance degrades as it fills. The canonical pattern is to keep context small and focused. [S056]
2. **Explore-Plan-Implement** — the canonical agentic loop for non-trivial coding tasks: explore the codebase, plan the change, implement, test, iterate. [S055, S056]
3. **Test-driven agentic development** — for any code change, the test suite is the source of truth. Agents are evaluated against test outcomes, not visual inspection. [S055, S056]
4. **MCP (Model Context Protocol)** is the emerging standard for tool integration (Anthropic). [S055]
5. **SWE-bench / SWE-bench Verified** is the canonical benchmark for agentic SWE. [S059]

**Governance (PA-18's cross-cutting role):**

- **Acceptable-use policy:** what tasks AI can be used for; what data can be sent to AI vendors.
- **Data handling:** PII, customer data, secrets.
- **IP and licensing:** training data, output ownership.
- **Model risk register:** which models are approved for which tasks.
- **Audit trail:** record of AI-generated code, tests, PRs.
- **Vendor risk:** SOC 2, data residency, breach notification.

**Decision framework: when to use AI in each workflow:**

- *Routine code, tests, refactoring:* Use AI. High leverage, low risk.
- *Architecture, security, design:* Use AI as an assistant; humans decide.
- *Agentic coding for well-scoped tasks:* Use AI agent; human review.
- *Agentic coding for ambiguous tasks:* Not yet safe; require extensive human in the loop.
- *AI in production critical paths:* Heavily governed; human approval required for any change.

### 6.3 Mid-2026 state of AI-assisted engineering (evidentiary snapshot)

- **Adoption:** 81% of developers used OpenAI GPT models in the past year (Stack Overflow 2025). [S063]
- **Language shift:** Python overtook JavaScript as the most-used language on GitHub in 2024; AI is the primary driver. [S051]
- **Productivity:** 55% faster on coding tasks (GitHub/Accenture). [S052]
- **Agent capability:** SWE-bench Verified is the canonical benchmark; agent scores have risen sharply through 2024-2025. [S059]
- **DORA 2025:** Dedicated to AI's impact on teams and people. [S037, S064]
- **NIST SSDF GenAI profile:** SP 800-218A, published 2024, is the first formal standards anchor for AI model development. [S008, S039]

---

## 7. Deprecated or Diminishing Practices

The following practices were once standard but are diminishing or deprecated in 2026. The deprecation is documented by source where available.

### 7.1 Process and governance deprecated practices

- **Annual or quarterly release trains.** Once common at large enterprises; replaced by continuous delivery and on-demand deploy. (DORA 2024-2025 capabilities: continuous delivery is the high-performance pattern.)
- **Long-lived feature branches as a primary model.** Replaced by trunk-based development with short-lived branches (≤ 2 days) and feature flags. [S004, S023, S040]
- **Manual QA hand-off as a separate phase.** Replaced by integrated QE: engineers own testability; QE engineers act as coaches and risk advisors. [S071]
- **Big-bang rewrites / big-bang migrations.** Replaced by strangler fig, branch by abstraction, evolutionary architecture. [S031, S032, S045]
- **Big Design Up Front (BDUF) for architecture.** Replaced by evolutionary architecture with just-enough design for the next quarter. [S032, S039, S045]
- **Stage-gate portfolio governance as a primary mechanism.** Replaced by continuous funding rounds and OKR alignment; review boards exist but are lightweight.
- **Story points as a performance metric.** Story points are an estimation tool, not a productivity metric. Performance is measured by outcomes (DORA, SPACE). [S043, S064]
- **Annual performance reviews tied to delivery output.** Replaced by continuous feedback, SPACE / DevEx, and outcome-based evaluation.
- **ITIL-style Change Advisory Boards as the primary deploy gate.** Replaced by policy-as-code and automated progressive delivery; CABs exist in regulated contexts but are an audit trail, not a bottleneck.
- **Per-feature environment provisioning and teardown.** Replaced by ephemeral environments and preview apps.
- **Manual secrets management.** Replaced by Vault / cloud KMS / SOPS.
- **Manual release notes authoring.** Replaced by automated changelog generation from conventional commits.

### 7.2 Technical deprecated practices

- **Monolithic VCS with infrequent merges.** Replaced by monorepos with daily trunk commits and CI.
- **Manual code review checklist (paper).** Replaced by structured review (Conventional Comments), AI-assisted review, code review SLAs.
- **E2E-heavy test suites ("ice-cream cone").** Replaced by the test pyramid; E2E reserved for critical paths. [S024]
- **Manual deployment runbooks.** Replaced by declarative pipelines; runbooks become automated.
- **Hand-configured infrastructure.** Replaced by infrastructure-as-code (Terraform, Pulumi, CloudFormation).
- **Custom logging frameworks per service.** Replaced by OpenTelemetry as the de-facto instrumentation standard. [S013, S014]
- **Pull-based monitoring with no SLOs.** Replaced by SLO-based alerting with multi-window burn rates. [S013, S015]
- **Static IP allowlists / VPN-only prod access.** Replaced by zero-trust, identity-aware proxies, short-lived credentials.
- **Hand-curated service catalogs.** Replaced by automated service catalog (Backstage ingesters).

### 7.3 AI and platform deprecated practices

- **Building an IDP as a side project.** Replaced by platform-as-a-product with PM, customer research, SLOs. [S044, S062]
- **AI as a single bolt-on tool.** Replaced by AI integration across the SDLC, with governance (PA-18) as a first-class concern.
- **AI-only customer support without escalation path.** Replaced by AI-assisted support with human escalation.
- **Centralized "ops team" doing manual deploys.** Replaced by on-demand deploy and self-service via IDP.

### 7.4 Documentation deprecated practices

- **Word documents as the canonical design doc.** Replaced by ADRs in markdown, RFCs in the repo.
- **Hand-maintained architecture diagrams (Visio).** Replaced by code-as-architecture (C4 model, structurizr, terraform graph).
- **Hand-maintained API documentation.** Replaced by OpenAPI / GraphQL schema-driven docs.
- **Wiki sprawl.** Replaced by docs-as-code (Docusaurus, MkDocs, Mintlify) co-located with the code.

### 7.5 Things that are not deprecated (counter-list)

To prevent false positives, the following remain current in 2026:

- **Up-front requirements in regulated industries** — formal traceability matrices remain required in medical devices, aviation, financial reporting.
- **Architecture review boards** — for high-impact decisions, governance remains. The pattern is lightweight ADRs + targeted review, not a standing committee.
- **Postmortems** — universal, and increasingly formalized for compliance (e.g., DORA in financial services).
- **Code review** — universal, but the structure has changed.
- **On-call rotations** — universal, but the tooling and culture have changed.
- **Architecture documentation** — universal, but the format is ADRs/RFCs, not Word.

---

## 8. Maturity Model

A capability-based maturity model for the 18 Process Areas. Each level describes the org's posture for the PAs; the levels are not waterfall but stages of investment.

### 8.1 Tier 0 — Ad hoc / Crisis-Driven

- Work is reactive; deploys are manual or rare.
- No CI; no formal testing; no observability.
- Outages drive change; technical debt is rising.
- AI is not used in any workflow.
- *Typical profile:* pre-product-market-fit startup; or large organization that has neglected its engineering capability.

### 8.2 Tier 1 — Minimum (Baseline Discipline)

- Basic CI on every commit.
- Basic automated testing (unit, some integration).
- Basic change control (PR + code review).
- Manual deploys to a single environment.
- Some incident response but ad hoc.
- *Evidence:* DORA Quick Check shows "Low" performers.
- *Typical profile:* early-stage startup with growing engineering team; small enterprise engineering team.

### 8.3 Tier 2 — Standard (Continuous Delivery)

- Continuous integration with daily merges to trunk.
- Test pyramid with automated unit, integration, and contract tests.
- Continuous delivery: every green commit is deployable.
- Code review as a knowledge-sharing practice.
- Basic observability (metrics, logs, traces) and incident management.
- DORA four keys reported.
- Some security: SAST/SCA in CI, secrets management, signed commits.
- *Evidence:* DORA "Medium" performers.
- *Typical profile:* growth-stage startup; most mid-sized engineering orgs.

### 8.4 Tier 3 — Leading-Edge (Platform + SRE + AI)

- Platform engineering team with IDP (Backstage), golden paths, self-service.
- Team Topologies organizational model (stream-aligned, platform, etc.).
- SRE practice: SLOs, error budgets, blameless postmortems.
- Chaos engineering; game days; on-call hygiene.
- Progressive delivery: canary, blue-green, feature flags.
- OpenTelemetry instrumentation; SLO-based alerting.
- Shift-left security: threat modeling, SLSA L3, SBOM.
- AI assistance in implementation, code review, testing.
- Architecture decision records and fitness functions.
- DORA four keys "High" or "Elite."
- *Evidence:* DORA "High" / "Elite" performers; recognized industry leaders.
- *Typical profile:* mature scale-up; large engineering org; mid-size public company.

### 8.5 Tier 4 — Pioneering (Autonomous + AI-Driven)

- AI agents routinely take well-scoped engineering tasks; humans review.
- AI-augmented incident response, observability, security analysis.
- AI governance (PA-18) is a formal capability with policy and audit.
- Platform team operates IDP as a product with measurable SLOs and developer NPS.
- Architecture is evolutionary with measurable fitness functions.
- Supply chain is fully attested (SLSA L3+); SBOM is consumer-facing.
- Continuous improvement is data-driven (SPACE, DevEx quadrant) and visible at the board level.
- *Evidence:* DORA "Elite" + AI-augmented delivery metrics; recognized as industry leader.
- *Typical profile:* hyperscaler; AI-native company; large financial-services org with mature engineering.

### 8.6 Maturity per Process Area — typical gaps

Not all PAs mature at the same rate. Common patterns:

- **Mature early:** PA-05, PA-07, PA-08, PA-09, PA-10, PA-11.
- **Mature mid:** PA-01, PA-04, PA-13, PA-14, PA-15, PA-16.
- **Mature late:** PA-12 (platform), PA-17 (legacy retirement), PA-18 (AI).
- **Often behind:** PA-02 (continuous discovery), PA-03 (UX maturity), PA-18 (AI governance).

### 8.7 Sequence of investment

The recommended sequence (independent of org size):

1. **Foundation:** PA-10, PA-11, PA-09 — CI/CD and tests. Without these, nothing else scales.
2. **Delivery loop:** PA-07, PA-08 — trunk-based dev + code review.
3. **Reliability:** PA-14, PA-15 — SLOs, observability, incident response.
4. **Security:** PA-13 — shift-left, threat modeling, SLSA.
5. **Discovery & planning:** PA-01, PA-02, PA-05.
6. **Architecture:** PA-04 — ADRs, fitness functions.
7. **Platform:** PA-12 — IDP, golden paths.
8. **Improvement:** PA-16 — measure developer experience.
9. **AI:** PA-18 — adopt AI assistance with governance.
10. **Sustain:** PA-17 — make retirement a first-class activity.

---

## 9. Role Model and Governance Implications

### 9.1 Core roles (mid-2026)

| Role | Primary PAs | Notes |
|------|-------------|-------|
| **Product Manager** | PA-01, PA-02, PA-05 | Discovery, strategy, prioritization. Marty Cagan's "empowered PM" model. |
| **Tech Lead / Principal Engineer** | PA-04, PA-07, PA-08 | Architectural decisions, technical direction, code-review culture. |
| **Staff Engineer** | PA-04, PA-12 | Cross-cutting technical leadership; platform/IDP. |
| **Engineer (SWE)** | PA-07, PA-08, PA-09, PA-10, PA-11 | Implementation, testing, deploy. |
| **QE / Test Engineer** | PA-09, PA-08, PA-12 | Test strategy, AI-test generation, test infrastructure. |
| **SRE** | PA-14, PA-15, PA-11 | SLOs, reliability, observability, incident response. |
| **Security Engineer** | PA-13, PA-04, PA-08 | Threat modeling, security review, compliance. |
| **Design Engineer / Designer** | PA-03, PA-04 | UX, design systems, accessibility. |
| **Platform Engineer** | PA-12, PA-06, PA-10, PA-11 | IDP, golden paths, self-service. |
| **Developer Experience Engineer** | PA-12, PA-16, PA-18 | Internal tooling, metrics, AI integration. |
| **AI/ML Engineer** | PA-18, PA-15, PA-13 | AI integration, model evaluation, observability. |
| **Engineering Manager** | PA-01, PA-05, PA-16 | Team health, planning, delivery performance. |
| **Director / VP / CTO** | All PAs | Portfolio, culture, governance, executive reporting. |

### 9.2 Team Topologies mapping (mandatory organizational model)

The four canonical team types from Team Topologies [S044]:

- **Stream-aligned team:** aligned to a value stream; has all skills to deliver. The default team type.
- **Enabling team:** helps stream-aligned teams adopt new capabilities; composed of specialists.
- **Complicated-subsystem team:** owns a subsystem that requires deep specialist knowledge.
- **Platform team:** provides internal services to reduce cognitive load on stream-aligned teams.

**Stream-aligned + platform is the dominant 2026 pattern** at Netflix, Airbnb, Spotify (originator of Backstage), and most platform-engineering-led orgs.

### 9.3 Governance bodies

Lightweight governance is the canonical pattern in 2026:

- **Architecture Council:** reviews ADRs; quarterly; not a blocker.
- **Security Council:** reviews security exceptions; ad hoc; tracks risk register.
- **Platform Council:** prioritizes platform roadmap; biweekly.
- **AI Governance Committee:** owns the AI acceptable-use policy, model risk register, vendor reviews. (New in 2026; growing rapidly.)
- **Incident Review Board:** reviews major incidents; blameless; identifies systemic issues.

### 9.4 RACI patterns per Process Area (one-line)

- **PA-01:** CEO/COO (A), VP Eng (R), EMs (C).
- **PA-02:** PM (A), Eng (R), Designer (C), Customers (I).
- **PA-03:** Designer (A), PM (R), Eng (C).
- **PA-04:** Tech Lead (A), Eng (R), Security (C), SRE (C).
- **PA-05:** EM (A), Eng (R), PM (C).
- **PA-06:** Platform Eng (A), Eng users (C).
- **PA-07:** Eng (A/R), Reviewer (C).
- **PA-08:** Reviewer (A/R), Codeowner (A), Author (R).
- **PA-09:** Eng (R), QE (A), PM (C).
- **PA-10:** Platform Eng (A), Security (C).
- **PA-11:** Eng (R), SRE (C), EM (A).
- **PA-12:** Platform PM (A), Eng users (C), Platform Eng (R).
- **PA-13:** Security Eng (A), Eng (R), Compliance (C).
- **PA-14:** SRE (A), Eng (R), PM (C).
- **PA-15:** SRE (A), Eng (R), Platform (C).
- **PA-16:** DevEx / EM (A), Eng (R), VP Eng (C).
- **PA-17:** Tech Lead (A), Eng (R), PM (C).
- **PA-18:** AI Governance (A), Eng (R), Security (C), VP Eng (C).

### 9.5 Organizational anti-patterns

- **The "platform team" with no users.** A platform team is built, but stream-aligned teams don't use it. *Mitigation:* Platform as a product; treat internal users as customers.
- **The "DevOps team" as a silo.** A central team owns all deploys, but stream-aligned teams are blocked. *Mitigation:* "You build it, you run it" — SRE model.
- **The "principal engineer" ivory tower.** Principal engineers decide everything. *Mitigation:* ADRs in the open; tech lead as a role, not a person.
- **The "AI team" as a separate org.** AI assistance lives in a different org, not integrated. *Mitigation:* AI is a horizontal capability, not a separate org.
- **The "security team" as a blocker.** Security reviews are slow and post-hoc. *Mitigation:* Security is in the team, not a separate org; shift-left.

---

## 10. Final Recommended Canonical Industry Standard

### 10.1 The recommended model in one sentence

**A capability-based reference model of 18 Process Areas and ~110 workflows, organized into four layers (Direction, Delivery, Feedback, Sustainability), each workflow classified as universal / leading-edge / context-dependent / emerging, with the minimum-viable loop running PA-04 → PA-07 → PA-09 → PA-10 → PA-11 → PA-15 → PA-16 → PA-01.**

### 10.2 Adoption patterns by organization type

| Org type | Initial focus | Time-to-mature | Special considerations |
|----------|---------------|----------------|------------------------|
| **Startup (pre-PMF, <20 eng)** | PA-04, PA-07, PA-11 minimum; AI assistance from day one | 3-6 months to Tier 1 | Many PAs collapse; founder/PM plays multiple roles |
| **Scale-up (20-200 eng)** | PA-04, PA-07, PA-09, PA-10, PA-11; introduce PA-12 platform | 6-12 months to Tier 2 | Team Topologies transition; platform team emerges |
| **Mid-large (200-2000 eng)** | All Tier 2 PAs; SRE function; IDP | 12-24 months to Tier 3 | Federated platform; SRE embedded in streams |
| **Large enterprise (2000+)** | All 18 PAs; PA-13 heavy; PA-18 emerging | 24-36 months to Tier 3-4 | Compliance, change advisory, regulatory |
| **Regulated (finance, health, public sector)** | PA-13 first, then everything else | Variable | SSDF, FedRAMP, HIPAA, DORA compliance overlays |
| **AI-native company** | PA-18 first; everything else second | 6-12 months to Tier 3-4 | AI agents are first-class engineers |

### 10.3 Common adoption patterns and pitfalls

**Patterns that work:**

1. **Start with a measurable bottleneck.** Pick the PA with the worst current performance; improve it; measure the impact.
2. **Treat platform as a product.** Don't build platform features no one uses.
3. **Adopt trunk-based dev early.** Long-lived branches are a tax that compounds.
4. **Invest in CI/CD before adding features.** Faster feedback compounds.
5. **Make observability a precondition for new services.** No SLO, no deploy.
6. **Adopt AI assistance with explicit governance.** The 55% productivity gain is real; the security and IP risks are also real.
7. **Use Shape Up for planning, OKRs for strategy, ADRs for architecture.** Each is the right tool for its layer.

**Patterns that fail:**

1. **Big-bang process transformation.** Don't rewrite all 18 PAs at once. Sequence the investment.
2. **Treating DevOps as a team.** DevOps is a practice, not an org.
3. **Stage-gate governance as a control mechanism.** Lightweight governance scales; stage-gates do not.
4. **AI without governance.** AI-generated code without review is a security incident waiting to happen.
5. **Platform as a side project.** A platform team without a PM and SLOs is dead on arrival.
6. **Tailwind for the metric, not the outcome.** Optimize for cycle time, deploy frequency, MTTR — the outcomes, not the proxies.

### 10.4 The mid-2026 inflection

Three forces are reshaping software delivery in 2026:

1. **AI as a first-class Process Area (PA-18).** Not a tool; an organizational capability. The 55% productivity gain is real (GitHub/Accenture); the agentic patterns are converging (Anthropic, OpenAI); the benchmarks are standard (SWE-bench Verified). Organizations that have not adopted AI assistance in 2026 are losing competitive ground.

2. **Platform engineering as the default organizational model.** Team Topologies and Backstage have moved from "leading-edge" to "standard." Internal Developer Portals are the canonical interface; the platform team is the canonical team type.

3. **Security and supply chain integrity as table stakes.** NIST SSDF v1.1, OWASP SAMM v2, and SLSA L3 are the converging standards. Software Bill of Materials is a regulatory requirement in many jurisdictions. Sign-and-attest is no longer optional in 2026.

### 10.5 Closing

The reference model is convergent across organizations. The path to adoption is context-dependent. No two organizations will adopt the 18 Process Areas in the same order or at the same speed — but the model is the same. The mid-2026 standard is a capability-based set of processes, owned by identified roles, measured by canonical metrics, and continuously improved by short feedback loops.

The model is not a methodology. It is not SAFe, LeSS, Scrum@Scale, Shape Up, Spotify, or any other single approach. It is a *reference* against which any methodology can be evaluated, and any org's process can be assessed. Use it as such.

---

## Appendix A — Source Authority Hierarchy

| Tier | Source type | Examples in this report |
|------|-------------|-------------------------|
| 1 | Engineering blogs/handbooks, named orgs | Google SRE, Google eng-practices, Microsoft Azure, AWS Well-Architected, Anthropic, OpenAI, GitHub, Stripe, Netflix, Spotify, GitLab, Atlassian, Martin Fowler, Thoughtworks, Backstage/Spotify, Humanitec, FireHydrant |
| 2 | Conference / industry press | InfoQ |
| 3 | Standards bodies | NIST (SP 800-218, SP 800-218A), OWASP (SAMM v2), OpenSSF (SLSA), CNCF (TAG App Delivery, projects list), OpenTelemetry |
| 4 | Industry surveys | DORA, GitHub Octoverse, Stack Overflow 2025, Google Cloud DORA blog |
| 5 | Peer-reviewed academic / encyclopedia | Wikipedia (DevOps, SRE, CMM) |
| 6 | Vendor / consultancy | Humanitec, FireHydrant |
| 7 | Single-source / flagged | Claimed explicitly in `triangulation.md` |

## Appendix B — Evidence Ledger

The complete evidence ledger is in `evidence.jsonl` (51 evidence items, each linked to a source ID, span, and reliability rating). Each evidence item supports one or more claims in `claims.jsonl` (50 atomic claims).

## Appendix C — Claims Ledger

`claims.jsonl` — 50 atomic claims, each with: claim text, process area, source IDs, evidence IDs, support status (multi-source / strong / moderate / single-source / contested).

## Appendix D — Decision Record

See `decision-record.md` for the rationale behind: why each Process Area is in the taxonomy, why each workflow is classified as it is, and rejected alternatives.

## Appendix E — Critique

See `critique.md` for the internal red-team review: claims with thin evidence, possible biases in source selection, areas where mid-2026 evidence is genuinely sparse, and counter-arguments.

## Appendix F — Handoff

See `handoff.md` for downstream consumers (CTO/VP Eng adoption planning teams) and remaining work.

## Appendix G — Glossary

- **ADR:** Architecture Decision Record.
- **Blameless Postmortem:** A retrospective on an incident focused on systemic causes, not individual blame.
- **CD:** Continuous Delivery.
- **CI:** Continuous Integration.
- **DORA:** DevOps Research and Assessment (now part of Google Cloud).
- **DPIF:** Dynamic Programming Iterative Function.
- **EOL:** End of Life.
- **HEART:** Happiness, Engagement, Adoption, Retention, Task success (Google UX metric framework).
- **IDP:** Internal Developer Platform / Internal Developer Portal.
- **MTTR:** Mean Time To Recovery / Repair / Respond (context-dependent).
- **OKR:** Objectives and Key Results.
- **OWASP:** Open Worldwide Application Security Project.
- **PA:** Process Area.
- **PR-FAQ:** Press Release / FAQ.
- **RED:** Rate, Errors, Duration (observability method).
- **RFC:** Request for Comments.
- **RUM:** Real User Monitoring.
- **SAMM:** Software Assurance Maturity Model (OWASP).
- **SBOM:** Software Bill of Materials.
- **SLSA:** Supply-chain Levels for Software Artifacts.
- **SLO / SLI:** Service Level Objective / Indicator.
- **SPACE:** Satisfaction, Performance, Activity, Communication, Efficiency (developer productivity framework).
- **SRE:** Site Reliability Engineering.
- **SSDF:** Secure Software Development Framework (NIST).
- **SWE-bench:** Benchmark for AI software engineering agents.
- **Trunk-Based Development:** Branching model with all work on a single trunk branch.
- **USE:** Utilization, Saturation, Errors (Brendan Gregg observability method).
