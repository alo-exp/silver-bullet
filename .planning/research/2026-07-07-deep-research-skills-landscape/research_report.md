# Deep Research Skills Landscape Report

## Executive Summary

This report ranks the top ten agent deep-research skills on GitHub and skills portals by **useful capabilities and features**, not popularity alone. After evaluating twenty-two candidates, [Socialpranker/claude-deep-research](https://github.com/Socialpranker/claude-deep-research) leads on phased depth, source catalogs, adversarial review, and runtime citation verification [1], [2]. Silver Bullet `silver-deep-research` ranks second for composable workflow integration with machine-readable phase gates and evidence ledgers [3]. The 199-biotechnologies fork remains the most influential validated open pipeline [4]. GitHub stars poorly predict feature leadership: Weizhena has the most stars but ranks sixth on capabilities [5], [6].

**Primary Recommendation:** Use Socialpranker and 199bio as external capability benchmarks; maintain SB's composability advantage while borrowing multilingual and search-orchestration patterns from hoolulu and blessonism.

**Confidence Level:** High for documented features; Medium for output-quality comparisons.

---

## Introduction

### Research Question

Which ten deep-research skills deliver the strongest capability mix for rigorous, citation-backed agent research in July 2026?

### Scope & Methodology

Landscape survey across GitHub (`gh search repos`, `gh api`), skills.sh portal, OpenClaw ecosystem, and SB native `silver-deep-research`. Mode: **deep** (nine nested DR phases). Twenty-eight sources registered; feature scoring across eleven dimensions with validation-weighted composite [3], [7].

### Key Assumptions

Feature claims are inferred from `SKILL.md` and `README.md` when live execution was not performed for every candidate.

---

## Main Analysis

### Finding 1: Feature depth diverges from GitHub stars

Socialpranker implements a nine-phase pipeline with one hundred three report blocks, twenty-nine search channels, and thirty-nine API source catalogs plus adversarial and runtime verification passes [1], [2]. Despite ~4 stars, it scores highest on the feature matrix. Weizhena leads stars (1543) but ranks sixth on features due to narrower validation and catalog breadth [5], [6].

**Sources:** [1], [2], [5], [6]

### Finding 2: SB silver-deep-research leads workflow composability

Silver Bullet's skill is the only evaluated skill wired to AF-DECIDE with `phases.yaml` single source of truth, V-loop gates, `sources.jsonl` / `evidence.jsonl` / `claims.jsonl` ledgers, and packaged validation scripts [3], [7]. It ranks second overall and first for composability and validation automation in SB-hosted workflows.

**Sources:** [3], [7]

### Finding 3: Domain-specific leaders fill complementary niches

hoolulu/deep-research leads multilingual production reporting (nineteen languages) with multi-agent chapter assembly and layered SearXNG retrieval [8]. blessonism/openclaw-search-skills provides the strongest OpenClaw retrieval substrate with intent-aware Brave+Exa+Tavily+Grok orchestration [9]. lingzhi227's `deep-research` sub-skill enforces the strictest academic phase-file gates [10]. tonyazhuuki implements the strongest explicit three-cycle adversarial ensemble [11].

**Sources:** [8], [9], [10], [11]

### Finding 4: Portal discovery remains incomplete

skills.sh lists deep-research skills but its JSON API was unavailable in this session, limiting install-based cross-checks [12]. GitHub search remained the primary discovery channel [7].

**Sources:** [7], [12]

---

## Synthesis & Insights

### Patterns Identified

Mature skills converge on phased pipelines (6–9 phases), citation tracking, and optional adversarial critique. Differentiation is in **automation** (validation scripts), **catalogs** (search channels/APIs), and **host integration** (SB AF-DECIDE, OpenClaw search-layer, Codex JSON validation).

### Novel Insights

Popularity metrics are misleading for procurement: a four-star repo can out-feature an eight-hundred-star fork if catalogs and verification are richer [1], [4], [6].

### Implications

SB should treat external skills as feature donors (catalogs, multilingual templates, intent routing) while preserving evidence-engine and composable-flow moat [3].

---

## Limitations & Caveats

### Known Gaps

- No live bake-off with identical research questions across top-five skills
- search-cli unavailable; web retrieval used gh + ctx_fetch fallbacks [7]
- skills.sh install rankings not extracted [12]

### Assumptions

SKILL.md documentation reflects runtime behavior; some repos may drift.

### Areas of Uncertainty

199bio marketing claims of outperforming closed DR products were not empirically tested [4].

---

## Recommendations

### Immediate Actions

1. Adopt feature-matrix top ten as SB benchmarking reference set [7]
2. Map Socialpranker catalogs into optional `silver-deep-research` deep-mode profiles [1]

### Next Steps

Install search-cli for future ultradeep runs; run live bake-off fixture across top five skills.

### Further Research

Cursor marketplace-specific DR catalog audit; empirical output comparison study.

---

## Bibliography

[1] Socialpranker. "claude-deep-research repository description." GitHub, 2026. https://github.com/Socialpranker/claude-deep-research
[2] Socialpranker. "deepdive SKILL.md — 9-phase workflow." GitHub raw, 2026. https://github.com/Socialpranker/claude-deep-research/blob/main/SKILL.md
[3] Silver Bullet. "silver-deep-research SKILL.md and phases.yaml." alo-exp/silver-bullet, 2026. https://github.com/alo-exp/silver-bullet/tree/main/skills/silver-deep-research
[4] 199-biotechnologies. "claude-deep-research-skill." GitHub, 2026. https://github.com/199-biotechnologies/claude-deep-research-skill
[5] Weizhena. "Deep-Research-skills README." GitHub, 2026. https://github.com/Weizhena/Deep-Research-skills
[6] Weizhena. "Deep-Research-skills repository metadata." GitHub API, 2026-07-07. https://github.com/Weizhena/Deep-Research-skills
[7] This research session. "run_manifest.json and research-plan.md." SB DR artifacts, 2026-07-07. https://github.com/alo-exp/silver-bullet/tree/main/.planning/research/2026-07-07-deep-research-skills-landscape
[8] hoolulu. "deep-research SKILL.md." GitHub, 2026. https://github.com/hoolulu/deep-research
[9] blessonism. "openclaw-search-skills search-layer SKILL.md." GitHub, 2026. https://github.com/blessonism/openclaw-search-skills
[10] lingzhi227. "agent-research-skills deep-research SKILL.md." GitHub, 2026. https://github.com/lingzhi227/agent-research-skills
[11] tonyazhuuki. "deep-research-skill research/SKILL.md." GitHub, 2026. https://github.com/tonyazhuuki/deep-research-skill
[12] skills.sh. "Agent Skills Directory search." https://skills.sh/search?q=deep+research

---

## Appendix: Methodology

### Research Process

FS-SILVER_DEEP_RESEARCH deep mode: scope → plan → retrieve → triangulate → outline → synthesize → critique → refine → package.

### Sources Consulted

Twenty-eight registered sources; fifteen evidence spans in `evidence.jsonl`.

### Verification Approach

Cross-triangulation of repo metadata vs SKILL.md content; claims ledger in `claims.jsonl`.

### Quality Control

Automated `validate_report.py`, `verify_citations.py`, `verify_claim_support.py` on final artifact.

---

## Top 10 Quick Reference

| # | Skill | Rationale |
|---|-------|-----------|
| 1 | Socialpranker/claude-deep-research | Deepest phased engine + catalogs + adversarial + runtime verify |
| 2 | silver-deep-research (SB) | AF-DECIDE composability + phases.yaml + V-loops |
| 3 | 199-biotechnologies/claude-deep-research-skill | Validated 4-mode 8-phase fork |
| 4 | hoolulu/deep-research | 19-language multi-agent reports |
| 5 | blessonism/openclaw-search-skills | Intent-aware 4-provider search layer |
| 6 | Weizhena/Deep-Research-skills | Human-in-the-loop multi-host control |
| 7 | tonyazhuuki/deep-research-skill | 3-cycle adversarial ensemble |
| 8 | lingzhi227/agent-research-skills | Academic 6-phase gated reviews |
| 9 | standardhuman/deep-research-skill | 7-phase GoT + domain overlays |
| 10 | ramit-mitra/deep-research-skill | Portable skills.sh wave-research loop |

Full matrix: [feature-matrix.md](./feature-matrix.md)
