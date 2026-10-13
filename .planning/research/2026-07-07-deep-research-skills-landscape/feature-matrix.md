# Feature Matrix — Deep Research Skills (July 2026)

Scoring: **0** absent · **1** minimal · **3** solid · **5** best-in-class.  
**Weighted score** = sum of 11 dimensions + 0.5×(validation + citation-evidence). Max ≈ 61.

| Rank | Skill | Phases/Modes | Citation/Evidence | Search Providers | Multilingual | Report Formats | Validation/Eval | Portability | Human-in-Loop | Composability | Source Catalogs | Adversarial | **Wt Score** |
|------|-------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| 1 | [Socialpranker/claude-deep-research](https://github.com/Socialpranker/claude-deep-research) | 5 | 5 | 5 | 3 | 5 | 5 | 3 | 3 | 4 | 5 | 5 | **58.5** |
| 2 | [silver-deep-research](https://github.com/alo-exp/silver-bullet/tree/main/skills/silver-deep-research) (SB) | 5 | 5 | 4 | 2 | 4 | 5 | 4 | 3 | 5 | 4 | 4 | **57.0** |
| 3 | [199-biotechnologies/claude-deep-research-skill](https://github.com/199-biotechnologies/claude-deep-research-skill) | 5 | 5 | 3 | 2 | 4 | 5 | 3 | 2 | 3 | 3 | 3 | **52.5** |
| 4 | [hoolulu/deep-research](https://github.com/hoolulu/deep-research) | 4 | 4 | 4 | 5 | 4 | 4 | 3 | 3 | 4 | 3 | 2 | **51.0** |
| 5 | [blessonism/openclaw-search-skills](https://github.com/blessonism/openclaw-search-skills) | 4 | 3 | 5 | 3 | 3 | 3 | 3 | 2 | 5 | 4 | 2 | **49.5** |
| 6 | [Weizhena/Deep-Research-skills](https://github.com/Weizhena/Deep-Research-skills) | 4 | 4 | 3 | 4 | 3 | 4 | 5 | 5 | 4 | 2 | 2 | **49.0** |
| 7 | [tonyazhuuki/deep-research-skill](https://github.com/tonyazhuuki/deep-research-skill) | 4 | 4 | 3 | 2 | 4 | 3 | 3 | 2 | 3 | 2 | 5 | **48.0** |
| 8 | [lingzhi227/agent-research-skills](https://github.com/lingzhi227/agent-research-skills) (deep-research) | 4 | 4 | 3 | 2 | 4 | 5 | 3 | 2 | 5 | 3 | 2 | **47.5** |
| 9 | [standardhuman/deep-research-skill](https://github.com/standardhuman/deep-research-skill) | 4 | 4 | 2 | 2 | 4 | 3 | 3 | 2 | 3 | 2 | 3 | **44.0** |
| 10 | [ramit-mitra/deep-research-skill](https://github.com/ramit-mitra/deep-research-skill) | 3 | 4 | 2 | 2 | 3 | 2 | 5 | 2 | 3 | 1 | 2 | **41.0** |

## Honorable mentions (did not make top 10)

| Skill | Why close | Gap vs #10 |
|-------|-----------|------------|
| [DishantPal/deep-research-skill](https://github.com/DishantPal/deep-research-skill) | Strong depth/quality philosophy (7–15× delivery) | Weaker formal validation & provider orchestration |
| [eliranwong/Claude_SearXNG_DeepResearch](https://github.com/eliranwong/Claude_SearXNG_DeepResearch) | Privacy-first SearXNG plugin | Narrower phase/mode spec |
| [czhiming-maker/pi-deep-research](https://github.com/czhiming-maker/pi-deep-research) | Clean reflect-iterate loop for pi | Host-limited; lighter evidence model |
| [parags/deep-research-pro](https://github.com/parags/deep-research-pro) | No API keys; OpenClaw metadata | Simpler pipeline than leaders |

## Dimension notes

- **Socialpranker** leads on catalogs (29 channels, 39 API families, 103 blocks) and adversarial + runtime verify [E001][E014].
- **SB silver-deep-research** leads on workflow composability (AF-DECIDE, V-loops, phases.yaml SSoT) [E013].
- **199bio** is the most mature **automated validation** fork widely copied by SB [E002].
- **hoolulu** leads **multilingual** production reporting (19 langs) [E003].
- **blessonism** is the strongest **retrieval substrate** for OpenClaw research stacks [E005].
- **Weizhena** leads **human-in-the-loop** and multi-host portability (Claude/Codex/OpenCode) [E004].
- **lingzhi** leads **academic phase gates** with file-based enforcement [E009].

## Stars vs features (illustrative)

| Repo | Stars | Feature rank |
|------|------:|:---:|
| Weizhena/Deep-Research-skills | 1543 | 6 |
| 199-biotechnologies | 819 | 3 |
| hoolulu/deep-research | 438 | 4 |
| blessonism/openclaw-search-skills | 437 | 5 |
| Socialpranker/claude-deep-research | 4 | **1** |

Popularity and capability diverge materially.
