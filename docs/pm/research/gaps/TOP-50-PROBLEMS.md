# Top 50 Problems: AI Agents in Software Engineering & DevOps

**Research mode:** ultradeep  
**Date:** 2026-06-27  
**Output:** `docs/pm/research/gaps/`  
**Ranking weights:** severity 40% · frequency 35% · business impact 25%

---

## Executive Summary

Engineering teams in 2025–2026 adopted AI coding agents faster than they adopted governance for those agents. Survey data shows 55% of engineers now use agents regularly [S02], while security research documents a sustained wave of credential theft, prompt-injection RCE, and trust-boundary bypasses across every major CLI [S05][S06][S08]. Academic synthesis finds that agentic success correlates with **output verifiability** — test results, compiler feedback, operational metrics — not with model size alone [S03]. The dominant failure modes cluster into eight themes: process bypass, traceability drift, context degradation, knowledge blindness, quality theater, delivery risk, DevOps hazards, and cost/model risk.

Silver Bullet's honest positioning must acknowledge that workflow enforcement addresses process bypass and traceability drift strongly, code-intelligence tools (Graphify, agentmemory, RTK, Context Mode) address knowledge blindness and context degradation when opted in, but **outcome validation** (production observability, load testing, continuous security scanning) remains a documented gap [S10][S11].

Brooks's essential-complexity argument still applies: no single tool delivers order-of-magnitude gains without process discipline [S13]. The opportunity is orchestration — making cheaper models reliable through gates, retrieval, and compression — not raw model substitution.

---

## Introduction

### Scope

This report ranks the top 50 problems engineering teams face when using AI agents for software engineering and DevOps workflows. It excludes general enterprise chatbot use cases and focuses on agentic coding CLIs (Claude Code, Codex, Cursor), CI-integrated agents, and multi-step implementation workflows.

### Methodology

Ultradeep mode: multi-source retrieval (industry reports, 2026 security disclosures, arXiv systematic reviews, SB internal gap analysis), triangulation across ≥3 independent sources per top-10 claim, claim ledger in `claims.jsonl`, evidence store in `evidence.jsonl`. Problems ranked by composite score across severity, frequency in practitioner literature, and business impact (incident cost, rework, opportunity loss).

### Assumptions

- Primary audience: engineering leaders and IC developers at teams with weekly+ AI tool usage [S18].
- Time horizon: conditions observed 2025–H1 2026.
- SB mapping is descriptive, not marketing — gaps from `docs/internal/sdlc-gap-analysis.md` are included.

---

## Eight Homepage Clusters

| Cluster | Problems | Core symptom |
|---------|----------|--------------|
| **Process bypass** | #1, #19, #23, #33, #36, #43, #47, #50 | Agents skip planning, gates, and retros |
| **Traceability drift** | #5, #24–25, #29, #31, #40 | Spec ↔ PR ↔ UAT ↔ docs diverge |
| **Context degradation** | #4, #26, #49 | Long sessions and raw dumps rot context |
| **Knowledge blindness** | #8, #18, #32, #41, #46 | No graph, memory, or repo-aware retrieval |
| **Quality theater** | #3, #14–15, #17, #39 | Reviews and gates without outcome proof |
| **Delivery risk** | #6, #9, #12, #21, #30, #35, #44 | "Done" without fresh evidence |
| **DevOps hazards** | #2, #11–13, #20, #22, #28, #34–35, #38, #45, #48 | Credentials, injection, blast radius |
| **Cost & model risk** | #7, #10, #16, #27, #37, #42 | API limits, non-linear agent loops |

---

## Ranked Problem List

### Tier 1 — Critical (Ranks 1–10)

**#1 Process bypass — agents edit before planning** [C001][E016]  
Agents default to file edits when no mechanical admission gate exists. Severity: critical. Frequency: universal in unconstrained sessions.

**#2 Prompt injection and credential exfiltration in CI/CD** [C002][E005][E006]  
Untrusted PR/issue content combined with privileged agent tools has produced P1/CVSS-9.x disclosures across vendors. Business impact: repository takeover, secret leak.

**#3 Insecure AI-generated code at scale** [C003][E007]  
Studies report ~45% of AI code samples with OWASP-class issues; vibe-coded apps show thousands of vulns per scan cohort [E015].

**#4 Context rot in long sessions** [C004][E004]  
Output quality degrades silently as windows fill; natural-language history alone cannot sustain repo-scale loops [S04].

**#5 Traceability drift across artifacts** [C005][E010]  
Spec, requirements, plan, UAT, and PR narratives diverge without enforced links.

**#6 Premature "done" without verification** [C006][E003]  
Agents claim completion without fresh tests, CI green, or review evidence — verifiability is the adoption enabler [S03].

**#7 Top-tier model cost and usage limits** [C007][E012]  
Teams hit API ceilings mid-sprint; cost blocks scale more than capability [S02].

**#8 No durable cross-session memory** [C008][E004][E019]  
Decisions evaporate between sessions unless externalized (agentmemory is opt-in [S11]).

**#9 Benchmark–reality gap** [C009][E022]  
SWE-bench success does not predict success on ambiguous, multi-file production tasks [S14].

**#10 Non-linear multi-agent token burn** [C010][E013]  
Planner–executor–reviewer loops multiply cost without routing discipline [S03].

### Tier 2 — High (Ranks 11–25)

**#11 False confidence in approval prompts** [C011][E008] — symlink/RCE chains after user-approved copies.  
**#12 No post-ship observability loop** [C012][E010] — ship → nothing; SB gap.  
**#13 Hallucinated permissions/config** [C013][E009] — internal data exposure without attacker.  
**#14 Review theater** [C014] — loops without assessor triage.  
**#15 Vibe-coding vulnerability debt** [C015][E015].  
**#16 Rate-limit flow breaks** [C016][E012].  
**#17 Compliance without outcome validation** [C017][E011] — SB's stated remaining gap.  
**#18 Large-codebase navigation failure** [C018][E004] — flat grep/RAG insufficient.  
**#19 Compaction erases obligations** [C019] — needs hook re-injection.  
**#20 Episodic not continuous security** [C020][E025].  
**#21 Over-delegation incident risk** [C021][E024].  
**#22 Slopsquatting / invented packages** [C022][E007].  
**#23 Unverifiable discovery/requirements phases** [C023][E017].  
**#24 PR–spec disconnect** [C024].  
**#25 Stale UAT vs spec version** [C025].

### Tier 3 — Material (Ranks 26–40)

**#26 Raw tool output floods context** [C026].  
**#27 Small models fail without process compensation** [C027][E023].  
**#28 Agent IAM blind spots** [C028][E005].  
**#29 Roadmap drift** [C029].  
**#30 Stale test markers** [C030].  
**#31 Docs lag code** [C031].  
**#32 Wrong-stack pattern reuse** [C032].  
**#33 Silent plugin downgrade** [C033].  
**#34 Infra blast-radius underestimation** [C034].  
**#35 PR merge ≠ release readiness** [C035].  
**#36 Weak incident/retro governance** [C036].  
**#37 Non-determinism vs reproducibility** [C037].  
**#38 Shadow AI bypass** [C038].  
**#39 Stylistic findings block delivery** [C039].  
**#40 Cross-artifact inconsistency** [C040].

### Tier 4 — Structural (Ranks 41–50)

**#41 Memory not indexed without Graphify** [C041][E019].  
**#42 Context Mode ELv2 licensing friction** [C042][E020].  
**#43 Fast-path scope creep** [C043].  
**#44 Missing load/performance validation** [C044].  
**#45 Weak canary discipline** [C045].  
**#46 Essential complexity remains** [C046][E023].  
**#47 Junior teams highest risk** [C047][E002].  
**#48 MCP/tool sprawl attack surface** [C048][E008].  
**#49 RTK freshness gate friction** [C049].  
**#50 No enforcement in discovery/validation** [C050][E017].

---

## Synthesis & Insights

1. **Verifiability beats autonomy** — Industrial agent adoption concentrates where executable feedback exists (tests, deploy, ops) [S03].
2. **Security moved from model risk to IAM risk** — Attackers target agent credentials, not weights [S05].
3. **Process and retrieval are substitutes for model tier** — Cheaper models + gates + graph/memory can outperform expensive models + vibes [S10][S23].
4. **Governance lag is measurable** — 95% weekly AI usage [S18] vs. documented exploit cadence [S05] shows enforcement debt.

---

## Limitations & Caveats

- Rankings synthesize published research and surveys, not a proprietary panel study.
- Incident reports (Foresiet, Adversa) describe research/disclosure contexts; prevalence in private enterprises is under-reported.
- SB mechanism mapping reflects repo state 2026-06-27; opt-in tools are not universal in downstream installs.
- Customer outcome metrics are not claimed — SB is alpha OSS without published case studies.

---

## Recommendations

1. **Leaders:** Treat agent credentials as production IAM; mandate human-in-the-loop for irreversible actions [S01][S06].
2. **Teams:** Enforce spec→test→PR traceability before scaling agent hours [S10].
3. **SB adopters:** Opt into Graphify + agentmemory + Context Mode + RTK stack for knowledge/context clusters; accept documented observability gaps honestly.
4. **Security:** Continuous scanning, not one-time design gates [S10][S07].

---

## Bibliography

See `sources.jsonl` for canonical IDs S01–S18. Key references: Anthropic 2026 Agentic Coding Trends [S01]; Pragmatic Engineer AI Tooling 2026 [S02]; arXiv 2605.15245 [S03]; VentureBeat agent exploits [S05]; Microsoft CI/CD agent security [S06]; Cycode AI vulnerabilities 2026 [S07]; Adversa symlink RCE [S08]; SB sdlc-gap-analysis [S10]; Brooks 1986 [S13].

---

## Methodology Appendix

Phases executed: SCOPE → PLAN → RETRIEVE → TRIANGULATE → OUTLINE → SYNTHESIZE → CRITIQUE → REFINE → PACKAGE. Claim-support verification via `claims.jsonl` ↔ `evidence.jsonl` join. HTML export optional at `TOP-50-PROBLEMS.html`.
