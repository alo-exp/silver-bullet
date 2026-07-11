# Handoff — Canonical SDLC Process Architecture

This document is for downstream consumers of the research report — primarily CTOs, VPs of Engineering, and consulting teams planning adoption. It summarizes what's in the report, how to use it, and what follow-on work is recommended.

## 1. What this report is

A capability-based reference model of 18 Process Areas and ~110 workflows, organized into four layers (Direction, Delivery, Feedback, Sustainability). Each workflow is classified as universal / leading-edge / context-dependent / emerging, with all 13 required fields. Every major claim is triangulated against ≥2 independent primary sources.

## 2. What this report is NOT

- **Not a methodology.** The report is methodology-agnostic. Shape Up, SAFe, LeSS, Spotify, Scrum@Scale, etc. are *implementations* of this reference model, not the model itself.
- **Not a tool recommendation.** The report describes tool *categories* (CI, IDP, observability, etc.) but does not recommend specific vendors.
- **Not a benchmark.** The report is descriptive, not normative. It says "this is what high-performing orgs do," not "you should do this."
- **Not an AI advocacy.** The report treats AI as a first-class Process Area (PA-18) with operational adoption evidence, but it does not advocate for AI adoption. The decision is context-dependent.

## 3. How to use this report

### 3.1 For a CTO/VP Eng adoption planning

1. **Start with §10** (Final Recommended Canonical Industry Standard). The four-layer model and adoption patterns are the executive summary.
2. **Use the maturity model (§8)** to assess current state. Identify which PAs are at Tier 0/1/2 vs. 3/4.
3. **Sequence investments per §8.7.** The recommended order is foundation → delivery loop → reliability → security → discovery → architecture → platform → improvement → AI → sustain.
4. **Use §9 (Role Model)** to identify organizational gaps.
5. **Use the deprecated list (§7)** to identify anti-patterns to stop.

### 3.2 For a platform engineering team

1. **Focus on PA-12** in §3 and §4. The full workflow detail is in §4.12.
2. **Use the role model (§9.1)** to define platform team roles.
3. **Use the maturity model** to assess platform maturity.

### 3.3 For a security/GRC team

1. **Focus on PA-13** in §3 and §4. The full workflow detail is in §4.13.
2. **Use the cross-area dependency map (§5)** to identify security dependencies on other PAs.
3. **Use the AI governance workflows (§4.18)** for AI-specific security.

### 3.4 For an SRE/observability team

1. **Focus on PA-14 and PA-15** in §3 and §4. The full workflow detail is in §4.14 and §4.15.
2. **Use the OpenTelemetry adoption pattern** to standardize instrumentation.
3. **Use the AI observability workflows** for AI-augmented incident response.

### 3.5 For an AI/ML engineering team adopting AI assistance

1. **Focus on PA-18** in §3, §4, and §6. The detailed treatment is in §6.2.
2. **Use the AI governance workflows** to build policy.
3. **Use the Anthropic workflow/agent taxonomy** as the canonical reference.

### 3.6 For a consulting firm building an assessment

1. **Use §3** (Process Area definitions) as the rubric.
2. **Use §4** (workflow library) as the detailed scoring guide.
3. **Use §8** (maturity model) as the scoring scale.
4. **Use §10.2** (adoption patterns by org type) as the contextual baseline.

## 4. Key takeaways

1. **The reference model is convergent across orgs.** Multiple independent sources (DORA, three Well-Architected frameworks, NIST, OWASP, OpenSSF, OpenTelemetry, CNCF, Team Topologies) agree on the same pillars and capabilities. The model is not novel; it is a synthesis.
2. **Trunk-based development + feature flags + CD is the canonical delivery loop.** No major org in 2026 uses long-lived feature branches as a primary model.
3. **Platform engineering is the canonical organizational model.** Team Topologies and Backstage are the canonical reference. The platform team is a first-class team type.
4. **SRE + OpenTelemetry is the canonical reliability and observability stack.** SLOs, error budgets, blameless postmortems, traces/metrics/logs.
5. **NIST SSDF + OWASP SAMM + SLSA is the canonical security stack.** Three standards bodies have produced a converging framework.
6. **AI is now a first-class Process Area.** PA-18 is not a sub-topic; it is a horizontal capability with its own governance, metrics, and workflows.

## 5. Recommended follow-on research

1. **Full 110-workflow expansion** with all 13 fields for every workflow. This report provides full detail for representative workflows and compact form for the remainder.
2. **PA-17 deep-dive** on legacy modernization in mid-2026. Under-documented.
3. **PA-18 longitudinal study** comparing AI-augmented vs. non-AI-augmented orgs over 12-24 months.
4. **Regulated industry case studies** for the 18 PAs. Current source base under-represents regulated contexts.
5. **DORA 2024/2025 deep-dive** when the canonical URLs are accessible (404 in this research).
6. **Asian and emerging-market engineering org coverage.** Currently US/Big-Tech biased.

## 6. Adoption pitfalls to avoid

From §10.3:

1. **Big-bang process transformation** — don't rewrite all 18 PAs at once. Sequence.
2. **Treating DevOps as a team** — it's a practice, not an org.
3. **Stage-gate governance as control** — lightweight governance scales; stage-gates do not.
4. **AI without governance** — AI-generated code without review is a security incident waiting to happen.
5. **Platform as a side project** — a platform team without a PM and SLOs is dead on arrival.
6. **Tailwind for the metric, not the outcome** — optimize for cycle time, deploy frequency, MTTR (the outcomes), not the proxies.

## 7. Companion artifacts

All in the same directory as this report:

- **`research_report.md`** — the main report (10 sections).
- **`scope.md`** — research question, scope, assumptions, source authority.
- **`research-plan.md`** — phased research plan, evidence map, risk management.
- **`outline.md`** — report outline.
- **`sources.jsonl`** — 80 primary sources with credibility notes.
- **`evidence.jsonl`** — 51 evidence items linked to sources.
- **`claims.jsonl`** — 50 atomic claims linked to evidence and sources.
- **`triangulation.md`** — cross-source agreement and gap analysis.
- **`critique.md`** — internal red-team review.
- **`decision-record.md`** — taxonomy and classification rationale.
- **`vloop-rollup.json`** — validation loop rollup.
- **`run_manifest.json`** — run metadata, agent slug, model, timestamps.
- **`handoff.md`** — this document.

## 8. Pointers for the reader

If you have 5 minutes, read:
- §1 (Executive Summary)
- §10.1 (Recommended model in one sentence)

If you have 30 minutes, add:
- §3 (Process Area taxonomy)
- §8 (Maturity model)
- §10.2 (Adoption patterns by org type)

If you have 2 hours, read the full report.

If you are implementing, also read:
- §4 (Full workflow library) — the operational detail
- §5 (Cross-area dependency map) — for sequencing
- §9 (Role model) — for staffing
