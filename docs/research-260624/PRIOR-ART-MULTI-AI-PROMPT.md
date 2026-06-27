# Prior-Art Discovery — Multi-AI Research

## Artifacts

Click any link to open in Cursor's built-in viewer.

### Prompts & index

| Artifact | Path |
|----------|------|
| **Index (this file)** | [PRIOR-ART-MULTI-AI-PROMPT.md](/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/PRIOR-ART-MULTI-AI-PROMPT.md) |
| **Master prompt** | [PRIOR-ART-MASTER-PROMPT.txt](/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/PRIOR-ART-MASTER-PROMPT.txt) |
| **Research prompt (full)** | [SB_PRIOR_ART_RESEARCH_PROMPT.md](/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/SB_PRIOR_ART_RESEARCH_PROMPT.md) |
| **User prompt (condensed)** | [SB_PRIOR_ART_USER_PROMPT.md](/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/SB_PRIOR_ART_USER_PROMPT.md) |

### Consolidated outputs

| Artifact | Path |
|----------|------|
| **Consolidated report (markdown)** | [SB_CONSOLIDATED_PRIOR_ART_REPORT.md](/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/SB_CONSOLIDATED_PRIOR_ART_REPORT.md) |
| **Consolidated report (HTML)** | [SB_CONSOLIDATED_PRIOR_ART_REPORT.html](/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/SB_CONSOLIDATED_PRIOR_ART_REPORT.html) |

### Per-model source reports

| Model | Report |
|-------|--------|
| deepseek-v4-pro | [prior-art-landscape-2026-06-27.md](/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/prior-art-landscape-2026-06-27.md) |
| minimax-m3 | [prior-art-landscape-minimax-m3.md](/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/prior-art-landscape-minimax-m3.md) |
| glm-5.2 | [prior-art-landscape-glm-5.2.md](/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/prior-art-landscape-glm-5.2.md) |
| kimi-k2.6 | [prior-art-landscape-report.md](/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/prior-art-landscape-report.md) |
| mimo-v2.5-pro | [prior-art-landscape-research.md](/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/prior-art-landscape-research.md) |
| qwen3.7-max | [prior-art-report.md](/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/prior-art-report.md) |

### Raw agent outputs

| Model | Output | Errors |
|-------|--------|--------|
| deepseek-v4-pro | [ocg-deepseek-v4-pro.md](/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/agent-output/ocg-deepseek-v4-pro.md) | [ocg-deepseek-v4-pro.err](/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/agent-output/ocg-deepseek-v4-pro.err) |
| glm-5.2 | [ocg-glm-5.2.md](/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/agent-output/ocg-glm-5.2.md) | [ocg-glm-5.2.err](/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/agent-output/ocg-glm-5.2.err) |
| kimi-k2.6 | [ocg-kimi-k2.6.md](/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/agent-output/ocg-kimi-k2.6.md) | [ocg-kimi-k2.6.err](/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/agent-output/ocg-kimi-k2.6.err) |
| mimo-v2.5-pro | [ocg-mimo-v2.5-pro.md](/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/agent-output/ocg-mimo-v2.5-pro.md) | [ocg-mimo-v2.5-pro.err](/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/agent-output/ocg-mimo-v2.5-pro.err) |
| minimax-m3 | [ocg-minimax-m3.md](/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/agent-output/ocg-minimax-m3.md) | [ocg-minimax-m3.err](/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/agent-output/ocg-minimax-m3.err) |
| qwen3.7-max | [ocg-qwen3-7-max.md](/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/agent-output/ocg-qwen3-7-max.md) | [ocg-qwen3-7-max.err](/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/agent-output/ocg-qwen3-7-max.err) |

### Dispatch & companion

| Artifact | Path |
|----------|------|
| **Dispatch script (parallel)** | [dispatch-research.sh](/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/dispatch-research.sh) |
| **Dispatch script (sequential)** | [dispatch-research-sequential.sh](/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/dispatch-research-sequential.sh) |
| **OCG subagent models note** | [OPENCODE_DYNAMIC_SUBAGENT_MODELS.md](/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/OPENCODE_DYNAMIC_SUBAGENT_MODELS.md) |
| **Atomic-flow redesign plan** | [atomic-flow-redesign.plan.md](/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/atomic-flow-redesign.plan.md) |

---

> **How to use:** Open [PRIOR-ART-MASTER-PROMPT.txt](/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/PRIOR-ART-MASTER-PROMPT.txt), select all, and paste the **same prompt** into every research-capable AI (Claude, GPT, Gemini, Perplexity, etc.). Run on **N ≥ 3** models, then **you** merge the N responses using **Section 8 (Cross-AI Dedup)** in the master prompt. Research and citation only — do not ask any AI to implement Silver Bullet.

**Why a plain `.txt` file?** Nested markdown code fences inside a fenced block break copy-paste in most editors and chat UIs. Plain text copies cleanly end-to-end.

**Reference (read if the model has web/repo access):**  
[atomic-flow-redesign.plan.md](https://github.com/alo-exp/silver-bullet/blob/ea08bf2a24a5e3c2bf0a953aa7b97f49af30fbc5/docs/research-260624/atomic-flow-redesign.plan.md)  
Companion artifacts: `docs/apo-catalog.json`, `docs/composable-flows-contracts.md`, `docs/ORCHESTRATOR.md`, `silver-bullet.md`

---

## Copy-paste source

**[PRIOR-ART-MASTER-PROMPT.txt](/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/PRIOR-ART-MASTER-PROMPT.txt)** — paste the entire file into each AI. No per-model variants.

### Steps

1. Open `PRIOR-ART-MASTER-PROMPT.txt` → **Select All** → paste into the AI.
2. Save each raw response to `docs/research-260624/prior-art-raw/<model>-<date>.md`.
3. Merge the N responses yourself via Section 8 → `docs/research-260624/PRIOR-ART-MERGED.md`.

---

## Checklist

- [ ] Run the **same master prompt** on ≥3 AIs
- [ ] Save each raw response to `docs/research-260624/prior-art-raw/<model>-<date>.md`
- [ ] Merge via Section 8 → `docs/research-260624/PRIOR-ART-MERGED.md`
- [ ] Score top matches; file gaps as backlog items if needed

---

*Authored for Silver Bullet APO / atomic-flow redesign research (2026-06). Do not execute research inside this file — prompt only.*
