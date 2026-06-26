---
name: multi-ai-task
description: Use this skill to dispatch a single research/analysis task across multiple LLM models in parallel and consolidate the results into a unified report. Handles cross-model deduplication, conflict resolution, scoring-matrix aggregation, and final synthesis. Use when (a) a question benefits from multi-model diversity (research, code review, fact-checking, ideation), (b) you need ≥2 independent answers to triangulate, or (c) you need a consolidated artifact aggregating findings from N models with conflict resolution and a final verdict.
argument-hint: "<task-prompt> [--models m1,m2,...] [--mode quick|standard|deep|ultradeep] [--out <dir>]"
user-invocable: true
version: 1.0.0
---

# multi-ai-task

Orchestrate a single research/analysis task across multiple LLM models in parallel, then consolidate the per-model outputs into one unified report with:

- **Cross-model deduplication** of distinct items (products, findings, candidates, etc.) via a canonical-name + aliases registry
- **Category / classification conflict resolution** with documented tie-break rules
- **Scoring-matrix aggregation** (median + range across models per dimension)
- **Final synthesis** (executive summary, top-N rankings, gap analysis, optional positioning memo)

Proven with 6-model prior-art research dispatches: handled 150+ raw mentions → 36 unique products → 0 direct competitors, with all category conflicts resolved and traceable.

---

## When to use

| Use this skill | Don't use this skill |
|---|---|
| Need ≥2 independent answers to triangulate | Single-model answer is sufficient |
| Outputs can be normalized into a table | Outputs are inherently narrative / no shared schema |
| You need a consolidated artifact, not just one answer | You want raw multi-model output, no consolidation |
| Disagreement across models is signal, not noise | You just need a fast single answer |
| You can write a structured output prompt | The task is open-ended "tell me what you think" |

## When NOT to use

- Cost is the primary constraint (multi-model = N× the API spend of a single model)
- Latency is critical (parallel dispatch takes the slowest model's time, plus consolidation overhead)
- The task requires tool execution that varies per model (consolidation assumes same prompt → same shape)
- You have ≤1 model available

---

## Usage

```
/multi-ai-task "<task-prompt>" [--models m1,m2,...] [--mode quick|standard|deep|ultradeep] [--out <dir>]
```

### Inputs

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `task-prompt` | YES | — | The prompt to send to every model. Use `@file.md` to inline a multi-line prompt. |
| `--models` | NO | Auto-discovered (see below) | Comma-separated list of `provider/model` IDs |
| `--mode` | NO | `standard` | One of `quick`, `standard`, `deep`, `ultradeep`. Controls consolidation depth and output verbosity |
| `--out` | NO | `./multi-ai-out/<timestamp>/` | Output directory for per-model reports + consolidated artifact |

### Mode semantics

| Mode | Per-model behavior | Consolidation behavior |
|------|--------------------|------------------------|
| `quick` | Single-shot prompt, ~2K output | Dedup + 1-page summary + ranking |
| `standard` | 8-phase deep-research pipeline, ~10K output each | Full dedup + scoring + conflict resolution + 1-page memo |
| `deep` | Same as standard but with cross-checking and source verification | Adds source verification, citation de-duplication, confidence calibration |
| `ultradeep` | Full methodology with paper-grade citation tracking | All of deep + academic-grade cross-source verification, formal evidence ledger |

The dispatch prompt is the same across modes; the difference is what the per-model prompt instructions ask the model to do.

### Default model discovery

If `--models` is omitted, the skill queries the local OpenCode config (`~/.config/opencode/opencode.json` and `.jsonc`) for available providers/models and picks a balanced default set of 4-6 models that span the available providers. Override with `--models` to pin a specific set.

**Important constraint (as of 2026-06):** OpenCode's `task` tool does NOT accept custom subagent types in some harness configurations. If your `task` tool rejects `subagent_type="my-agent"`, use the `opencode run --model <provider/model>` CLI dispatch pattern described in `rules/dispatch-mechanics.md`.

---

## Output structure

```
<out-dir>/
├── <model-slug>.md          # Raw output per model
├── <model-slug>.err         # stderr per model (if dispatched via subprocess)
├── consolidated.md          # Cross-model consolidated report (Section 4 schema)
├── consolidated.html         # Self-contained HTML version (rendered preview)
├── sources.jsonl             # Append-only source registry (deep/ultradeep only)
├── claims.jsonl              # Atomic claim ledger (deep/ultradeep only)
└── run-manifest.json          # Inputs, mode, models, timing
```

---

## Methodology (loaded on demand)

The full 8-phase + consolidation pipeline is documented in:

- `@skills/multi-ai-task/rules/methodology.md` — 8-phase per-model pipeline + 4-phase cross-model consolidation
- `@skills/multi-ai-task/rules/dispatch-mechanics.md` — how to actually launch N parallel LLM processes (task tool, opencode run, subprocess, SDK)
- `@skills/multi-ai-task/rules/consolidation-rules.md` — deduplication, conflict resolution, scoring aggregation
- `@skills/multi-ai-task/rules/output-schema.md` — the exact schema for the final consolidated report
- `@skills/multi-ai-task/rules/prompt-template.md` — the per-model prompt template (8-phase deep-research instructions)

**ALWAYS read `methodology.md` before invoking the skill on a non-trivial task.** This SKILL.md is the entry point and the schema reference; the rules/ subdir has the actual algorithms.

---

## Output schema (consolidated.md)

```markdown
# <Task Title> — Cross-Model Consolidated Report
**Date:** YYYY-MM-DD | **Models:** N | **Mode:** standard | **Coverage:** M unique items

## 1. Executive Summary (≤300 words)
<terse landscape overview, cross-model consensus, biggest gaps>

## 2. Dedup Table (one row per distinct item)
| # | Canonical | Mentions | Categories | Primary URL | Top Finding |
|---|-----------|---------:|------------|-------------|-------------|
| N | ... | N | adjacent, `direct*`, tangential | ... | ... |

*Use code spans (not bold-italic) for category conflict markers — they survive copy-paste into WYSIWYG viewers.*

## 3. Per-Row Gaps
- <canonical>: gaps_vs_subject = ... ; subject_gaps_vs_them = ...

## 4. Evidence Blocks
### EVIDENCE — <name>
- source_type, version_or_date, quote (≤50 words), url

## 5. Scoring Matrix (median across N models)
| candidate | dim1 | dim2 | ... | TOTAL (median) | Range |
|-----------|------|------|-----|---------------|-------|

## 6. Top N by ranking
## 7. Adjacent Inspirations
## 8. Negative Results
## 9. Open Questions
## 10. 1-Page Positioning Memo (deep/ultradeep only)
## Appendix A: Cross-AI Source Map
## Appendix B: Coverage Scoreboard
```

See `rules/output-schema.md` for the full template.

---

## Cross-model conflict resolution (canonical rules)

When 2+ models disagree on a categorical field (e.g., "is this a direct competitor or adjacent?"), apply these rules in order:

1. **Newer `last_verified` date wins** (re-classifying with a fresher source is more reliable).
2. **Quoted primary source wins** — if one model cites a verbatim quote and the other doesn't, prefer the cited one.
3. **Median of N scores** — for numeric fields, use the median across all N model scores.
4. **Prefer `direct` only if ≥3 SB-differentiator-equivalent criteria are evidenced** with a primary quote. Otherwise downgrade to `adjacent` and document the reason.
5. **Tie-break**: if a single model is an outlier on ≥2 fields, demote its classification to the next lower category and document.

Always document the resolution rule used per row in the `## 4. Unresolved Conflicts` section of the report.

---

## Dedup registry (canonical-name + aliases)

Each model may use a different name for the same item. Build a single canonical registry:

```json
{
  "canonical_name": {
    "aliases": ["alias1", "alias2", "model-a-name", "model-b-name"],
    "category_per_model": {"m1": "direct", "m2": "adjacent", "m3": "tangential"},
    "score_per_model": {"m1": {"dim1": 2, "dim2": 1}, "m2": {...}},
    "evidence_blocks": [{"model": "m1", "quote": "...", "url": "..."}],
    "urls": ["https://..."],
    "first_seen": "m1"
  }
}
```

Aliases are typically needed for: rebrandings (Claude Dev → Cline), forks (AutoGen → AG2), regional variants (Anthropic vs github.com/anthropics), and case-variants.

---

## Proven provenance

This skill was first run end-to-end on 2026-06-27 to consolidate the Silver Bullet (SB) Agentic Process Orchestrator prior-art research. Inputs and outputs:

- **6 OCG models** dispatched in parallel: `opencode-go/{minimax-m3, qwen3.7-max, deepseek-v4-pro, glm-5.2, kimi-k2.6, mimo-v2.5-pro}`
- **Same prompt verbatim** to all 6
- **Results**: 150+ raw mentions → 36 unique products → 1 consolidated report at `docs/research-260624/SB_CONSOLIDATED_PRIOR_ART_REPORT.md`
- **All 4 scoring matrices** extracted and aggregated (median + range per dimension)
- **All category conflicts** resolved and documented in §4 of the report

See that file for a complete worked example of every section in the output schema.

---

## Failure modes and known limitations

1. **Harness rejects custom subagent types.** The OpenCode harness's `task` tool may hardcode a small enum (`explore`, `general`). Workaround: dispatch each model via `opencode run --model <id>` in a subprocess; the ocg-* subagent names in `opencode.json` are unreachable from some harnesses.
2. **Per-model rate limiting.** `ctx_search` throttles at ~9 calls per 30 seconds per context. Workaround: pass `queries: [array]` (batch), use `ctx_batch_execute`, avoid single-query loops.
3. **MCP port collisions on parallel dispatch.** If multiple subprocesses try to start the same MCP (e.g., agentmemory on port 3111), only one wins. Workaround: dispatch sequentially, or disable MCPs in subprocesses.
4. **Some models are more permissive graders.** A single model classifying 4+ items as `direct` when 5 others say `adjacent` is a signal to investigate, not to accept. Apply rule 5 from the conflict-resolution section.
5. **Scoring matrix absence.** Some models produce qualitative comparisons instead of numeric scores. The scoring matrix section should note "models without numeric scores" rather than inventing numbers.
6. **Tool failure mid-dispatch.** If a subprocess is killed (e.g., by a shell timeout) but the model already wrote its report to disk via `write` tool, the report is still recoverable. Always check the CWD for stray `prior-art-*.md` / `report-*.md` files after a dispatch.

---

## See also

- `deep-research` skill (Claude/Codex) — the 8-phase pipeline per model. multi-ai-task uses this methodology per model, then adds the cross-model consolidation.
- `find-skills` — to discover related SB skills.
- `silver-bullet` — for managing the SDLC workflow that may consume multi-ai-task's outputs.
