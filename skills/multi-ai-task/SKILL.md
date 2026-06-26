---
name: multi-ai-task
description: Use this skill to dispatch any task across multiple LLM models in parallel and consolidate their outputs into a single artifact. Handles cross-model deduplication, conflict resolution, and result aggregation. Use when (a) you want ≥2 independent answers to triangulate, (b) a task benefits from model diversity (research, code review, fact-checking, ideation, writing critique, etc.), or (c) you need one consolidated artifact merging N model outputs with conflict resolution.
argument-hint: "<task-prompt> [--models m1,m2,...] [--out <dir>] [--schema <json>]"
user-invocable: true
version: 2.0.0
---

# multi-ai-task

Generic multi-model orchestration + consolidation. Dispatch the same task to N LLM models in parallel, capture each response, then merge into a single artifact.

**Task-agnostic.** Works for any task the user wants done — research, code review, fact-checking, ideation, translation verification, writing critique, decision support, etc. The task content is whatever the user provides as the prompt.

**What this skill does:**
1. Dispatches the user's prompt to N LLM models in parallel
2. Captures each model's full response
3. Extracts structured items from each response (rows, claims, candidates, etc.)
4. Deduplicates items that multiple models flagged
5. Resolves disagreements across models (with documented tie-break rules)
6. Aggregates scores / votes / ratings when applicable
7. Produces a consolidated artifact + an HTML preview

**What this skill does NOT do:**
- Define the task content (user provides the prompt)
- Define the output schema (user can pass `--schema`; defaults to LLM-assisted extraction)
- Replace domain expertise (the models do the actual work; the skill just orchestrates and consolidates)

---

## When to use

| Use this skill | Don't use this skill |
|---|---|
| Need ≥2 independent answers to triangulate | Single-model answer is sufficient |
| Cross-model disagreement is signal, not noise | You just want a fast single answer |
| Want a consolidated artifact, not raw N outputs | You want raw multi-model output, no merging |
| Cost of N× compute is acceptable | Cost is the primary constraint |
| Latency of slowest model + consolidation is OK | Latency is critical (single turn) |
| Task is well-defined and reproducible | Task is highly experimental / one-shot |

## When NOT to use

- **Single model suffices** — adds cost + consolidation time for no benefit
- **Real-time interactive** — multi-model dispatch adds seconds-to-minutes latency
- **Tool execution varies per model** — consolidation assumes same prompt → comparable outputs
- **Output is non-textual** (image generation, audio) — current consolidation is text-based
- **You have ≤1 model available** — no diversity to consolidate

---

## Usage

```
/multi-ai-task "<task-prompt>" [--models m1,m2,...] [--out <dir>] [--schema <json>]
```

### Inputs

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `task-prompt` | YES | — | The task description sent to every model verbatim. Use `@file.md` to inline a multi-line prompt. |
| `--models` | NO | Auto-discover (see below) | Comma-separated list of `provider/model` IDs |
| `--out` | NO | `./multi-ai-out/<timestamp>/` | Output directory |
| `--schema` | NO | Inferred from prompt (or LLM-assisted extraction) | Optional structured output schema. Either a JSON object describing the expected table/rows, OR a path to a schema file |
| `--mode` | NO | `standard` | `quick` (no dedup, just merge) / `standard` (dedup + conflict resolution) / `thorough` (adds cross-source verification) |
| `--concurrency` | NO | `parallel` | `parallel` (faster) or `sequential` (safer, no MCP port collision) |

### Default model discovery

If `--models` is omitted, the skill queries the local OpenCode config (`~/.config/opencode/opencode.json` + `.jsonc`) and picks a balanced default set of 4-6 models across the available providers. Override with `--models` to pin a specific set.

### The `--schema` parameter

The skill needs to know how to structure the consolidation. Two modes:

**Mode A: structured schema (preferred for tables / lists)**

Pass a JSON object describing the expected per-row schema:
```json
{
  "type": "table",
  "columns": [
    {"name": "item",    "type": "string",  "dedup_key": true},
    {"name": "category","type": "enum",    "values": ["direct","adjacent","tangential","negative-result"]},
    {"name": "score",   "type": "number",  "aggregate": "median"},
    {"name": "url",     "type": "url",     "dedup_key": "secondary"},
    {"name": "evidence","type": "string",  "max_words": 50}
  ],
  "primary_key": "item",
  "conflict_resolution": {
    "category": "prefer-with-evidence-then-newer-then-strict",
    "score": "median"
  }
}
```

**Mode B: free-form (no schema)**

If no schema is provided, the skill uses LLM-assisted extraction:
1. Ask each model to wrap its response in `<structured></structured>` tags containing a JSON list
2. If a model doesn't comply, fall back to asking a designated "extractor" model to read the response and pull out the structured data
3. Apply generic dedup (fuzzy match on first 5 words of each paragraph) and conflict resolution (longer answer wins; if multiple disagree, present all)

**Recommended:** always pass `--schema` for tasks that produce tables/lists; use free-form mode for narrative / creative tasks.

---

## Output structure

```
<out-dir>/
├── <model-slug>.md          # Raw output per model
├── <model-slug>.err         # stderr per model (if subprocess)
├── consolidated.md          # Merged artifact (per the schema or free-form)
├── consolidated.html         # Self-contained HTML preview
├── structured.jsonl          # Per-row extracted data (one JSON per row per model)
├── conflicts.md              # Documented disagreements + resolutions
├── run-manifest.json          # Inputs, models, timing, mode
└── (optional) score-aggregate.md  # If scoring rubric was provided
```

---

## Methodology (the 4 phases)

The full pipeline is documented in `rules/methodology.md`. Quick summary:

1. **Per-model execution** — same prompt sent to all N models in parallel
2. **Output capture** — each response saved to `<model>.md`; structured rows extracted to `structured.jsonl`
3. **Cross-model consolidation** — dedup by primary key, resolve conflicts by configured rule, aggregate scores by configured aggregator
4. **Final synthesis** — write `consolidated.md` (per the schema or free-form), render HTML preview, write `conflicts.md` documenting all resolutions

## Dispatch mechanics

The 4 dispatch mechanisms (in order of preference) and how to choose between them — see `rules/dispatch-mechanics.md`. Default is **`opencode run --model <id>`** subprocess per model (proven to work; subagent_types via the `task` tool may be restricted by some harnesses).

## Consolidation algorithms

The dedup, conflict-resolution, and aggregation algorithms — see `rules/consolidation-rules.md`. These are the core value of the skill; everything else is plumbing.

## Output schema

The structure of `consolidated.md` and the per-row schema rules — see `rules/output-schema.md`. When a `--schema` is provided, follow it; otherwise default to a generic "items + evidence + scores + per-row resolutions" structure.

---

## Task examples (NOT part of the skill — for reference only)

The skill is generic. To use it for a specific task type, the user supplies the prompt and (optionally) the schema. A few worked examples are in `rules/examples/`:

- `rules/examples/research-prior-art.md` — using multi-ai-task for prior-art research
- `rules/examples/code-review.md` — using multi-ai-task for parallel code review
- `rules/examples/fact-check.md` — using multi-ai-task for fact verification

These are reference recipes. The skill itself works for any task.

---

## Failure modes

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `npx opencode-ai run` returns instantly with no output | Model unavailable, network error, or rate-limited | Check stderr, retry, or substitute model |
| Subprocess dies after 2 min with no report | Shell tool's 2-min default timeout | Set explicit `timeout` on bash tool, or run sequential |
| 5/N models return, others missing | One model in API outage | Substitute or skip; flag in run-manifest |
| All N models return same content (no diversity) | Prompt too narrow, or models too similar | Broaden prompt; add adversarial framing; use diverse provider families |
| MCP rate-limit (9 calls/30s) blocks research mid-task | Single-query loops in agent | Use `queries: [array]` batched, `ctx_batch_execute` |
| Cross-model conflict can't be resolved automatically | Models give incomparable answers | Present all + document "no consensus" |

---

## Proven provenance

The skill was first run end-to-end on 2026-06-27 for prior-art research. Inputs and outputs:

- **6 OCG models** dispatched in parallel via `opencode run --model`
- **Same prompt verbatim** to all 6
- **Results**: 150+ raw mentions → 36 unique products → 1 consolidated report at `docs/research-260624/SB_CONSOLIDATED_PRIOR_ART_REPORT.md`
- **All 4 scoring matrices** extracted and aggregated (median + range per dimension)
- **All category conflicts** resolved and documented in `conflicts.md`

See `rules/examples/research-prior-art.md` for how that run was structured. **That run is one example of many possible uses** — the skill is task-agnostic.

---

## See also

- `deep-research` skill (Claude/Codex) — 8-phase research methodology that can be invoked as the per-model prompt
- `silver-bullet` — for managing the SDLC workflow that may consume multi-ai-task's outputs
- `find-skills` — to discover related SB skills
