# Capability-Only Feature Matrix — Deep Research Skills

**Generated:** 2026-07-07T16:16:25.875Z
**Candidates:** 67 (union SB landscape + TopGun, deduped)
**Scoring rubric:** 11 capability dimensions, 0–5 each. **Excluded:** stars, installs, recency, security, external_quality_signal.

## Scoring Rubric

| Scale | Meaning |
|---|---|
| 0 | Absent |
| 1 | Minimal / prompt-only |
| 3 | Solid production feature |
| 5 | Best-in-class |

**Weighted capability score** = Σ(11 dimensions) + 0.5×(validation + citation). Max ≈ **61.0**.

### Dimensions

| # | Dimension | What it measures |
|---|-----------|------------------|
| 1 | Phases/Modes | Named pipeline depth, mode tiers, explicit gates |
| 2 | Citation/Evidence | Claim ledgers, evidence.jsonl, source registries |
| 3 | Search Providers | Multi-provider orchestration, intent routing |
| 4 | Multilingual | Production multi-language report support |
| 5 | Report Formats | Block templates, structured artifact types |
| 6 | Validation/Eval | Automated verify scripts, quality gates |
| 7 | Portability | Multi-host (Claude/Codex/Cursor/OpenClaw) |
| 8 | Human-in-Loop | Checkpoints, interviews, gated progression |
| 9 | Composability | AF-DECIDE, phases.yaml, V-loops, subagent wiring |
| 10 | Source Catalogs | Channel/API/source-matrix breadth |
| 11 | Adversarial Review | Red-team, contradiction-seeking, critics |

### Scoring sources

- **sb_expert** — Hand-scored in SB landscape feature-matrix (SKILL.md triangulation)
- **tg_expert** — Extended hand-scoring for TG-only leaders (description + breakdown)
- **inferred** — Description-pattern inference for long tail

## Full Matrix (ranked)

| Rank | Skill | Ph | Cit | Srch | ML | Rpt | Val | Port | Hum | Comp | Cat | Adv | **Score** |
|------|-------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| 1 | Socialpranker/claude-deep-research | 5 | 5 | 5 | 3 | 5 | 5 | 3 | 3 | 4 | 5 | 5 | **53** |
| 2 | alo-exp/silver-bullet/silver-deep-res… | 5 | 5 | 4 | 2 | 4 | 5 | 4 | 3 | 5 | 4 | 4 | **50** |
| 3 | hashbulla/deep-research | 5 | 5 | 4 | 2 | 4 | 5 | 3 | 4 | 3 | 3 | 4 | **47** |
| 4 | hoolulu/deep-research | 4 | 4 | 4 | 5 | 4 | 4 | 3 | 3 | 4 | 3 | 2 | **44** |
| 5 | Weizhena/Deep-Research-skills | 4 | 4 | 3 | 4 | 3 | 4 | 5 | 5 | 4 | 2 | 2 | **44** |
| 6 | 199-biotechnologies/claude-deep-resea… | 5 | 5 | 3 | 2 | 4 | 5 | 3 | 2 | 3 | 3 | 3 | **43** |
| 7 | lingzhi227/agent-research-skills | 4 | 4 | 3 | 2 | 4 | 5 | 3 | 2 | 5 | 3 | 2 | **41.5** |
| 8 | daizedong/market-intel | 3 | 4 | 4 | 2 | 3 | 4 | 3 | 2 | 4 | 4 | 4 | **41** |
| 9 | blessonism/openclaw-search-skills | 4 | 3 | 5 | 3 | 3 | 3 | 3 | 2 | 5 | 4 | 2 | **40** |
| 10 | Jay-0807/firefly-deep-research-skill | 4 | 4 | 3 | 4 | 4 | 4 | 3 | 2 | 3 | 2 | 3 | **40** |
| 11 | kaynquang/multi-agent-research | 4 | 4 | 3 | 2 | 4 | 3 | 3 | 3 | 4 | 2 | 4 | **39.5** |
| 12 | daymade/claude-code-skills/deep-research | 4 | 4 | 3 | 2 | 5 | 4 | 3 | 2 | 3 | 2 | 3 | **39** |
| 13 | tonyazhuuki/deep-research-skill | 4 | 4 | 3 | 2 | 4 | 3 | 3 | 2 | 3 | 2 | 5 | **38.5** |
| 14 | standardhuman/deep-research-skill | 4 | 4 | 2 | 2 | 4 | 3 | 3 | 2 | 3 | 2 | 3 | **35.5** |
| 15 | jasonm4130/claude-skills | 4 | 4 | 2 | 2 | 3 | 4 | 3 | 2 | 3 | 1 | 3 | **35** |
| 16 | papabeans-library-deep-research | 4 | 4 | 2 | 2 | 3 | 4 | 3 | 2 | 2 | 1 | 4 | **35** |
| 17 | toustifer/omni-scope | 3 | 3 | 4 | 2 | 3 | 3 | 3 | 2 | 4 | 2 | 3 | **35** |
| 18 | rsiran/deep-research | 3 | 4 | 2 | 2 | 3 | 3 | 3 | 2 | 4 | 1 | 4 | **34.5** |
| 19 | 24601/agent-deep-research | 3 | 3 | 4 | 2 | 3 | 3 | 4 | 2 | 3 | 2 | 2 | **34** |
| 20 | rohunvora/x-research-skill | 3 | 3 | 3 | 2 | 3 | 2 | 4 | 2 | 4 | 2 | 2 | **32.5** |
| 21 | affaan-m/deep-research | 3 | 4 | 4 | 2 | 3 | 2 | 3 | 2 | 2 | 2 | 2 | **32** |
| 22 | ramit-mitra/deep-research-skill | 3 | 4 | 2 | 2 | 3 | 2 | 5 | 2 | 3 | 1 | 2 | **32** |
| 23 | vincent-wen789/notebooklm-research | 3 | 3 | 2 | 2 | 3 | 3 | 5 | 2 | 2 | 1 | 3 | **32** |
| 24 | hec-ovi/research-skill | 3 | 3 | 2 | 2 | 3 | 2 | 4 | 3 | 3 | 1 | 3 | **31.5** |
| 25 | pancat009/auto-deep-research-skill | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 2 | 2 | 1 | 2 | **31** |
| 26 | DishantPal/deep-research-skill | 4 | 3 | 2 | 2 | 4 | 2 | 3 | 3 | 2 | 1 | 2 | **30.5** |
| 27 | jhonhander/academic-agent-toolkit | 3 | 3 | 3 | 2 | 3 | 2 | 3 | 2 | 3 | 2 | 2 | **30.5** |
| 28 | eliranwong/Claude_SearXNG_DeepResearch | 3 | 3 | 4 | 2 | 3 | 2 | 3 | 2 | 2 | 2 | 1 | **29.5** |
| 29 | anthony-maio/pieces-agent-skills | 3 | 3 | 2 | 2 | 3 | 2 | 3 | 2 | 3 | 1 | 2 | **28.5** |
| 30 | niraven/pokee-deep-research-skill | 3 | 3 | 3 | 2 | 3 | 2 | 3 | 2 | 2 | 1 | 2 | **28.5** |
| 31 | tamnd/skills | 3 | 3 | 2 | 2 | 2 | 2 | 4 | 2 | 3 | 1 | 2 | **28.5** |
| 32 | ngvoicu/specmint-core | 3 | 2 | 3 | 2 | 2 | 2 | 4 | 3 | 3 | 1 | 1 | **28** |
| 33 | parags/deep-research-pro | 3 | 2 | 3 | 2 | 3 | 1 | 4 | 2 | 3 | 2 | 1 | **27.5** |
| 34 | tessellated-statisticalcommission243/… | 3 | 3 | 2 | 2 | 3 | 2 | 3 | 2 | 2 | 1 | 2 | **27.5** |
| 35 | czhiming-maker/pi-deep-research | 3 | 3 | 2 | 2 | 3 | 2 | 2 | 2 | 2 | 1 | 1 | **25.5** |
| 36 | havingautism/qurio | 3 | 2 | 3 | 2 | 2 | 1 | 3 | 2 | 3 | 2 | 1 | **25.5** |
| 37 | npm/verified-deep-research | 2 | 3 | 2 | 2 | 3 | 2 | 3 | 2 | 2 | 1 | 1 | **25.5** |
| 38 | pouyasharp/econometrics-deep-research | 3 | 3 | 1 | 2 | 4 | 2 | 2 | 2 | 2 | 1 | 1 | **25.5** |
| 39 | cam10001110101/ollama-deep-researcher | 2 | 2 | 4 | 2 | 2 | 2 | 2 | 2 | 3 | 1 | 1 | **25** |
| 40 | felores/perplexity-sonar-mcp | 2 | 2 | 4 | 2 | 2 | 2 | 2 | 2 | 3 | 1 | 1 | **25** |
| 41 | glama/deep-research-mcp | 2 | 2 | 4 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **25** |
| 42 | konbakuyomu/smart-search | 2 | 2 | 4 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **25** |
| 43 | mcp-so/deep-research-mcp-server | 2 | 2 | 4 | 2 | 2 | 2 | 2 | 2 | 3 | 1 | 1 | **25** |
| 44 | theishangoswami/web-search-exa | 2 | 2 | 4 | 2 | 2 | 2 | 2 | 2 | 3 | 1 | 1 | **25** |
| 45 | u14app/deep-research-mcp | 2 | 2 | 4 | 2 | 2 | 2 | 2 | 2 | 3 | 1 | 1 | **25** |
| 46 | arun-8687/gemini-deep-research | 2 | 2 | 3 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **24** |
| 47 | exa/exa-mcp | 2 | 2 | 4 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | 1 | **24** |
| 48 | fbettag/openai-deep-research-mcp | 2 | 2 | 4 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | 1 | **24** |
| 49 | firstpick/pi-skill-research-orchestra… | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 4 | 1 | 1 | **24** |
| 50 | jameskanyiri/langgraph_deep_agents | 3 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 3 | 1 | 1 | **24** |
| 51 | orchestra-research/ai-research-skills | 2 | 2 | 3 | 2 | 2 | 2 | 3 | 2 | 2 | 1 | 1 | **24** |
| 52 | kesslerio/academic-deep-research | 2 | 3 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | 1 | **23.5** |
| 53 | baranwang/mcp-deep-research | 2 | 2 | 3 | 2 | 2 | 2 | 3 | 1 | 2 | 1 | 1 | **23** |
| 54 | hirokidaichi/deepre | 2 | 2 | 2 | 2 | 3 | 2 | 2 | 2 | 2 | 1 | 1 | **23** |
| 55 | deep-research-orchestrator | 3 | 2 | 2 | 2 | 2 | 1 | 2 | 2 | 3 | 1 | 1 | **22.5** |
| 56 | deep-research-skill | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | 1 | **22** |
| 57 | monarch-initiative/deep-research-client | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | 1 | **22** |
| 58 | seyhunak/deep-research | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | 1 | **22** |
| 59 | zaycv/deepresearch | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | 1 | **22** |
| 60 | deep-research-writer | 2 | 2 | 2 | 2 | 3 | 1 | 2 | 2 | 2 | 1 | 1 | **21.5** |
| 61 | liangdabiao/claude-code-deep-research… | 3 | 2 | 2 | 2 | 2 | 1 | 2 | 2 | 2 | 1 | 1 | **21.5** |
| 62 | manfromtunis/melek-skills | 2 | 2 | 2 | 2 | 2 | 1 | 3 | 2 | 2 | 1 | 1 | **21.5** |
| 63 | mayrsascha/deep-research-skill | 2 | 2 | 2 | 2 | 2 | 1 | 4 | 2 | 1 | 1 | 1 | **21.5** |
| 64 | mayurrathi/awesome-agent-skills | 2 | 2 | 2 | 2 | 2 | 1 | 3 | 2 | 2 | 1 | 1 | **21.5** |
| 65 | rekko-ai/rekko-skill | 2 | 2 | 2 | 2 | 2 | 1 | 3 | 2 | 2 | 1 | 1 | **21.5** |
| 66 | rgvai/deep-research-agent | 2 | 2 | 2 | 2 | 2 | 1 | 3 | 2 | 2 | 1 | 1 | **21.5** |
| 67 | kirkidoo/shopsync | 2 | 2 | 2 | 2 | 2 | 1 | 2 | 2 | 1 | 1 | 1 | **19.5** |
