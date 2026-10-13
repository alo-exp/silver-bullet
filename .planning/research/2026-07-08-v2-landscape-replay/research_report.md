# Deep Research Skills Landscape Report (v2 Replay)

## Executive Summary

This v2 replay ranks the top ten agent deep-research skills on GitHub and skills portals by **useful capabilities and features**, not popularity alone. Using the SB `search_orchestrator` with SB-owned `skill_portals.json`, twenty-three sources were collected across GitHub and skills.sh [1], [2]. [Socialpranker/claude-deep-research](https://github.com/Socialpranker/claude-deep-research) remains the feature leader [3]. Silver Bullet `silver-deep-research` v2 ranks second with improved search orchestration and eval harness [4], [5]. A key behavioral improvement: skills.sh semantic API returned eighty-eight results vs empty/HTML in the July baseline [2].

**Primary Recommendation:** Continue SB v2 engine development; adopt parallel-web install signal as discovery input but not capability proxy.

**Confidence Level:** High for documented features; Medium for output-quality comparisons.

---

## Introduction

### Research Question

Which ten deep-research skills deliver the strongest capability mix for rigorous, citation-backed agent research in July 2026?

### Scope & Methodology

Landscape survey via SB `search_orchestrator` (landscape mode), `gh search repos`, and skills.sh semantic API. Mode: **deep**. Twenty-three sources registered; feature scoring across eleven dimensions [5], [6].

### Key Assumptions

Feature claims are inferred from `SKILL.md` and `README.md` when live execution was not performed for every candidate.

---

## Main Analysis

### Finding 1: v2 portal discovery improves over July baseline

The SB `search_orchestrator` dispatched five portals from `skill_portals.json`. skills.sh semantic API succeeded with eighty-eight results in 683ms [2]. July baseline recorded skills.sh JSON API as empty/HTML [7]. GitHub code search portal failed (auth required) but `gh search repos` fallback collected thirty repos [1].

**Sources:** [1], [2], [7]

### Finding 2: Feature depth still diverges from GitHub stars

Socialpranker implements a nine-phase pipeline with one hundred three report blocks and twenty-nine search channels [3]. Despite low stars, it scores highest. Weizhena leads stars (1545) but ranks sixth on features [8], [9].

**Sources:** [3], [8], [9]

### Finding 3: SB silver-deep-research v2 leads workflow composability

v2 adds `search_orchestrator.py`, `capability_score.py`, `eval/validate_structure.py`, and SB-owned portal catalogs [4], [5]. It ranks second overall with improved search-provider and catalog scores vs July [6].

**Sources:** [4], [5], [6]

### Finding 4: parallel-web emerges from portal installs

skills.sh reports 11,200 installs for `parallel-deep-research` [2]. It enters the honorable-mention tier but lacks SB-level validation automation [10].

**Sources:** [2], [10]

---

## Synthesis & Insights

### Patterns Identified

Mature skills converge on phased pipelines, citation tracking, and optional adversarial critique. v2 SB engine adds structured portal dispatch and behavioral scoring without popularity signals.

### Novel Insights

Portal install counts (parallel-web) surface candidates invisible to GitHub star ranking alone [2], [10].

### Implications

SB should integrate skills.sh portal results into landscape mode while maintaining capability_score rubric that excludes install/star signals [5].

---

## Limitations & Caveats

### Known Gaps

- No live bake-off with identical research questions across top-five skills
- search-cli unavailable; web retrieval used gh + portal API fallbacks [1]
- GitHub code search portal requires auth token

### Assumptions

SKILL.md documentation reflects runtime behavior.

---

## Recommendations

### Immediate Actions

1. Commit v2 engine artifacts and benchmark replay delta [6]
2. Add GitHub portal auth token support for code search API

### Next Steps

Install search-cli for ultradeep runs; run live bake-off fixture across top five skills.

---

## Bibliography

[1] This research session. "gh-search-repos.json." SB DR v2 replay, 2026-07-08.
[2] skills.sh. "Semantic search API results." portal-skills_sh.json, 2026-07-08. https://skills.sh/api/search?q=deep+research+skill
[3] Socialpranker. "claude-deep-research." GitHub, 2026. https://github.com/Socialpranker/claude-deep-research
[4] Silver Bullet. "search_orchestrator.py and skill_portals.json." alo-exp/silver-bullet, 2026. https://github.com/alo-exp/silver-bullet/tree/main/skills/silver-deep-research
[5] Silver Bullet. "capability_score.py eval harness." alo-exp/silver-bullet, 2026. https://github.com/alo-exp/silver-bullet/tree/main/skills/silver-deep-research/scripts/capability_score.py
[6] This research session. "feature-matrix.md and vloop-rollup.json." SB DR v2 replay, 2026-07-08.
[7] July baseline. "run_manifest.json." 2026-07-07. https://github.com/alo-exp/silver-bullet/tree/main/.planning/research/2026-07-07-deep-research-skills-landscape
[8] Weizhena. "Deep-Research-skills." GitHub, 2026. https://github.com/Weizhena/Deep-Research-skills
[9] Weizhena. "Repository metadata." GitHub API, 2026-07-08.
[10] parallel-web. "parallel-agent-skills." GitHub, 2026. https://github.com/parallel-web/parallel-agent-skills

---

## Report Metadata

- **Mode:** deep
- **Sources:** 23
- **Evidence spans:** 10
- **Claims:** 5
- **Engine:** silver-deep-research v2
- **Replay of:** 2026-07-07-deep-research-skills-landscape
