---
name: "silver:multi-ai"
title: "Multi AI"
description: Use this skill to dispatch any task across multiple LLM models in parallel and consolidate their outputs into a single artifact. Handles cross-model deduplication, conflict resolution, and result aggregation. Use when (a) you want ≥2 independent answers to triangulate, (b) a task benefits from model diversity (research, code review, fact-checking, ideation, writing critique, etc.), or (c) you need one consolidated artifact merging N model outputs with conflict resolution.
argument-hint: "<task-prompt> [--models m1,m2,...] [--out <dir>] [--schema <json|file>] [--mode quick|standard|thorough] [--no-auto-inject] [--lite]"
user-invocable: false
version: 2.3.0
---

# /silver:multi-ai — Multi-Model Orchestration

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
8. **Auto-injects the schema into every dispatch prompt** (by default ON; pass `--no-auto-inject` to opt out — see "The `--schema` parameter" below)

**What this skill does NOT do:**
- Define the task content (user provides the prompt)
- Define the output schema (user can pass `--schema`; defaults to LLM-assisted extraction)
- Replace domain expertise (the models do the actual work; the skill just orchestrates and consolidates)
- Retry failed dispatches (this is the calling agent's responsibility; the skill is fail-soft)

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
/silver:multi-ai "<task-prompt>" [--models m1,m2,...] [--out <dir>] [--schema <json|file>] [--mode quick|standard|thorough] [--no-auto-inject] [--lite]
```

### Inputs

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `task-prompt` | YES | — | The task description sent to every model verbatim. Use `@file.md` to inline a multi-line prompt. |
| `--models` | NO | Auto-discover (see below) | Comma-separated list of `provider/model` IDs. Recommended: 4-6 models from at least 2 different provider families. |
| `--out` | NO | `./multi-ai-out/<timestamp>/` | Output directory |
| `--schema` | NO | LLM-assisted extraction | Optional structured output schema. Either a JSON object (inline) or a path to a `.json` file. Defines columns, types, dedup keys, conflict rules. |
| `--mode` | NO | `standard` | `quick` (merge raw, no dedup) / `standard` (dedup + conflict resolution) / `thorough` (standard + cross-source verification; see Mode semantics) |
| `--no-auto-inject` | NO | (schema is auto-injected) | If passed, the skill does NOT append the schema to the dispatch prompt. Use when your prompt already embeds the schema or you want to manage prompt construction yourself. |
| `--lite` | NO | (standard models) | If passed, or if the task-prompt contains the keyword "lite", use the OCG-Lite budget-friendly model set (see OCG-Lite below). Replaces high-cost models with cheaper alternatives; excludes some models entirely. |

### Default model discovery

**Step 0 — resolve models (medium reasoning only):**

```bash
python3 scripts/multi-ai-task-models.py --json
```

This uses the **same model inventory as `/silver:review-fix-ladder`** for the active host (from `SILVER_BULLET_RUNTIME`) but pins **reasoning effort to `medium` only**. Print `host`, `plan`, and the resolved model list before dispatching.

| Host | Source | Notes |
|------|--------|-------|
| **task host** | Fixed ladder set | Same models as review-fix-ladder; use task host Task slug when dispatching |
| **api host** | `models_cache.json` or fallback | Excludes `gpt-5.4-mini`; medium rung per model |
| **primary host** | Fallback chain | `primary-model`, `primary host-opus-4-7`, `primary host-opus-4-8` @ medium |

**OpenCode Go (OCG) plan:** when `~/.config/opencode/opencode.json(c)` defines `agent.*.model` entries under `opencode-go/*`, those models are preferred for parallel dispatch (Mechanism 1 / Mechanism 2). **Prerequisite:** each OCG model needs a pre-defined agent entry — the `task` tool does not accept per-call `model`. Example:

```jsonc
{
  "agent": {
    "ocg-minimax-m3": { "mode": "subagent", "model": "opencode-go/minimax-m3" }
  },
  "permission": { "task": { "ocg-*": "allow" } }
}
```

See `rules/dispatch-mechanics.md` for Mechanism 1–4 selection.

If `--models` is omitted after Step 0, use the resolver output. Override with `--models` to pin a specific set. When OCG is unavailable, pick 4–6 models across ≥2 provider families from the resolver list.

### OCG-Lite (budget-friendly variant)

Activate by passing `--lite` or by including the keyword "lite" in the task-prompt. The resolver replaces high-cost OCG models with cheaper alternatives:

```bash
python3 scripts/multi-ai-task-models.py --json --lite
```

| Standard OCG | OCG-Lite replacement | Notes |
|---|---|---|
| `opencode-go/minimax-m3` | `opencode-go/minimax-m3` | Kept unchanged (already budget-friendly) |
| `opencode-go/qwen3.7-max` | `opencode-go/qwen3.7-plus` | Mid-tier replacement |
| `opencode-go/deepseek-v4-pro` | `opencode-go/deepseek-v4-flash` | Flash-tier, lower cost |
| `opencode-go/glm-5.2` | **excluded** | Removed to reduce total model count |
| `opencode-go/kimi-k2.6` | `opencode-go/kimi-k2.7-code` | Code-specialised, cost-efficient |
| `opencode-go/mimo-v2.5-pro` | `opencode-go/mimo-v2.5` | Non-pro tier, lower cost |

Ladder fallback models (non-OCG) are kept as-is. The `plan` field in the payload is set to `"ocg-lite"` for audit trail.

**Use when:** budget is constrained, the task tolerates lower model capability (quick drafts, low-stakes ideation, cost-conscious triage), or you are testing the pipeline before a full run.

**Avoid when:** the task requires the highest quality per model output (deep research, critical code review, production decisions).

### Mode semantics

| Mode | Phase 1 (dispatch) | Phase 2 (extract) | Phase 3 (consolidate) | Phase 4 (synthesize) | Use when |
|------|--------------------|------------------|----------------------|----------------------|----------|
| `quick` | Full | Basic (table parse, no fuzzy match) | Dedup only, no conflict resolution | Merged raw output, no `conflicts.md` | Speed-critical, low-stakes |
| `standard` | Full | Full (fuzzy match, schema-driven) | Dedup + conflict resolution per schema/default rules | Full `consolidated.md` + `conflicts.md` | Default for most tasks |
| `thorough` | Full | Full + **cross-source verification**: for each canonical item, dispatch a verifier model to check the claimed source actually supports the claim | Dedup + conflict resolution + **evidence-ledger.md** (per-claim source URL + verdict) | Full + **evidence-ledger.md** + per-item `source_verified: true|false|wrong` flag | High-stakes (regulatory, due-diligence) |

`thorough` mode adds ~N_items × 1 verifier call. For 36 items × 1 verifier, expect ~3-5 min additional wall-time (sequential) or ~1 min (parallel). Do not use for routine ideation or code review.

### The `--schema` parameter

The skill needs to know how to structure the consolidation. Two modes:

**Mode A: structured schema (preferred for tables / lists)**

Pass a JSON object describing the expected per-row schema:

```json
{
  "type": "table",
  "primary_key": "item",
  "columns": [
    {"name": "item",    "type": "string",  "dedup_key": true,                "required": true},
    {"name": "category","type": "enum",    "values": ["direct","adjacent","tangential","negative-result"]},
    {"name": "score",   "type": "number",  "aggregate": "median",            "min": 0, "max": 16},
    {"name": "url",     "type": "url",     "dedup_key": "secondary"},
    {"name": "evidence","type": "string",  "max_words": 50},
    {"name": "sources", "type": "url_list"},
    {"name": "file",    "type": "string"},
    {"name": "line",    "type": "number"}
  ],
  "conflict_resolution": {
    "category": "prefer-with-evidence-then-newer-then-strict",
    "score": "median",
    "severity": "most-severe"
  }
}
```

**Supported column types:**

| `type` | Description |
|--------|-------------|
| `string` | Free-text string |
| `number` | Numeric (integer or float) |
| `boolean` | True/false |
| `enum` | One of the `values` list |
| `url` | A single URL string |
| `url_list` | Comma-separated URLs (normalized + deduped on dedup) |
| `date` | ISO-8601 date string |
| `text` | Long-form text (use `max_words` to constrain) |

**Supported top-level schema fields:**

| Field | Description |
|-------|-------------|
| `type` | Always `"table"` (the only currently supported shape) |
| `primary_key` | Name of the single column that is the dedup key. Convenience alias for putting `dedup_key: true` on one column. For composite keys, omit this and use `dedup_key: true` on multiple columns instead. |
| `columns` | List of column definitions (see below) |
| `conflict_resolution` | Map of `{field_name: rule_name}` to override defaults |

**Supported column fields:**

| Field | Description |
|-------|-------------|
| `name` | Column name (required) |
| `type` | Type (required; see above) |
| `dedup_key: true` | This column is part of the dedup primary key |
| `dedup_key: "secondary"` | Tiebreaker after primary key |
| `required: true` | Row is dropped with warning if this field is missing |
| `min` / `max` | For numeric: enforce range |
| `max_words` | For text: enforce word count cap |
| `values` | For enum: list of allowed values (most-severe first for `most-severe` rule) |
| `separator` | For url_list: separator (default `,`) |
| `severity_order` | Optional override for the `most-severe` rule: list of enum values in most-severe-first order. Defaults to `["blocker", "major", "minor", "nit"]` if omitted. |
| `allow_downgrade` | Boolean. When `true`, the `most-severe` rule downgrades a lone max-severity value (1 of N reviewers says `blocker` with no evidence quote) to the next tier. Default: `false` (most-severe value wins even if only 1 reviewer reported it). |

**Composite primary keys:** list multiple columns with `dedup_key: true`. Example: `file` + `line` for code review.

**Conflict-resolution values:** see the full rule library in `rules/consolidation-rules.md` (named rules: `most-severe`, `majority`, `majority-with-uncertain`, `lowest-of-majors`, `longest-with-quote`, `concatenate-all`, `all-collected`, `union-dedup`, `merge-exact`, `prefer-with-evidence-then-newer-then-strict`).

**Schema auto-injection (default ON):** by default, the skill appends a `## Required Output Schema` block to each dispatch prompt containing the schema verbatim, plus a one-line instruction. This ensures models know the column structure even if the user didn't embed it. To opt out (because your prompt already embeds the schema, or you want to manage prompt construction yourself), pass `--no-auto-inject`. The auto-inject state is recorded in `run-manifest.json → schema_auto_injected: true|false`.

**Mode B: free-form (no schema)**

If no schema is provided, the skill uses LLM-assisted extraction:
1. Ask each model to wrap its response in `<structured></structured>` tags containing a JSON list
2. If a model doesn't comply, fall back to asking a designated "extractor" model (default: the slowest, highest-capability model from the original dispatch) to read the response and pull out the structured data
3. Apply generic dedup (fuzzy match on first 5 words of each paragraph) and conflict resolution (longer answer wins; if multiple disagree, present all)

**Recommended:** always pass `--schema` for tasks that produce tables/lists; use free-form mode for narrative / creative tasks.

---

## Output structure

```
<out-dir>/
├── <model-slug>.md          # Raw output per model
├── <model-slug>.err         # stderr per model (if subprocess)
├── consolidated.md          # Merged artifact (per the schema or free-form)
├── consolidated.html         # Self-contained HTML preview (generated from consolidated.md)
├── structured.jsonl          # Per-row extracted data (one JSON per row per model)
├── conflicts.md              # Documented disagreements + resolutions
├── run-manifest.json          # Inputs, models, timing, mode, schema_auto_injected
├── evidence-ledger.md        # (thorough mode only) per-claim source URL + verification verdict
└── verification.md            # (thorough mode only) per-item source verification
```

### `thorough`-mode-only file schemas

`evidence-ledger.md` (one row per claim × source pair):

```markdown
| item | claim | source | verifier | verdict | confidence |
|------|-------|--------|----------|---------|------------|
| LangGraph | "Stateful DAG with checkpointers" | https://langchain-ai.github.io/langgraph/concepts/ | minimax-m3 | verified | high |
| LangGraph | "Per-step rollup + intent gate" | https://langchain-ai.github.io/langgraph/concepts/ | minimax-m3 | wrong | n/a |
```

`verification.md` (one row per canonical item, per-item rollup):

```markdown
| item | source_verified | verdicts_by_source | notes |
|------|------------------|---------------------|-------|
| LangGraph | partially-verified | 1 verified, 1 wrong | at least one source claim contradicted |
| BMAD | verified | 3 verified, 0 wrong | all sources support claims |
```

**Verdict values** for both files: `verified` (the source supports the claim), `wrong` (the source contradicts the claim), or `uncertain` (the verifier couldn't determine).

`consolidated.html` generation: convert `consolidated.md` to HTML using a markdown library (`marked` in Node, `markdown` in Python, `pandoc` for richer output). Embed minimal CSS inline (table styles, conflict-marker color, section anchors). Self-contained — no external resources.

---

## Methodology (the 4 phases)

The full pipeline is documented in `rules/methodology.md`. Quick summary:

1. **Per-model execution** — same prompt sent to all N models in parallel
2. **Output capture** — each response saved to `<slug>.md`; structured rows extracted to `structured.jsonl`
3. **Cross-model consolidation** — dedup by primary key, resolve conflicts by configured rule, aggregate scores by configured aggregator
4. **Final synthesis** — write `consolidated.md` (per the schema or free-form), render HTML preview, write `conflicts.md` documenting all resolutions

The 4 phases are also tracked in `run-manifest.json → phases_completed` (a top-level array, per the canonical schema in `rules/output-schema.md`) for audit purposes.

## Dispatch mechanics

The 4 dispatch mechanisms (in order of preference) and how to choose between them — see `rules/dispatch-mechanics.md`. **Default is Mechanism 2** (`opencode run --model <id>` subprocess per model; proven to work; subagent_types via the `task` tool may be restricted by some harnesses).

## Consolidation algorithms

The dedup, conflict-resolution, and aggregation algorithms — see `rules/consolidation-rules.md`. These are the core value of the skill; everything else is plumbing. The named rule library (`most-severe`, `majority-with-uncertain`, `lowest-of-majors`, `concatenate-all`, `union-dedup`, etc.) is now formally defined.

## Output schema

The structure of `consolidated.md` and the per-row schema rules — see `rules/output-schema.md`. When a `--schema` is provided, follow it; otherwise default to a generic "items + evidence + scores + per-row resolutions" structure.

---

## Task examples (NOT part of the skill — for reference only)

The skill is generic. To use it for a specific task type, the user supplies the prompt and (optionally) the schema. Worked examples in `rules/examples/`:

- `rules/examples/research-prior-art.md` — the proven 6-model prior-art run on 2026-06-27
- `rules/examples/code-review.md` — parallel code review recipe
- `rules/examples/fact-check.md` — parallel fact verification recipe

These are reference recipes. The skill itself works for any task.

---

## Failure modes

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `npx opencode-ai run` returns instantly with no output | Model unavailable, network error, or rate-limited | Check stderr; substitute or skip the model |
| Subprocess dies after 2 min with no report | Shell tool's 2-min default timeout | Set explicit `timeout` on bash tool, or run sequential |
| 5/N models return, others missing | One model in API outage | Substitute or skip; flag in `run-manifest.json → models_failed` |
| All N models return same content (no diversity) | Prompt too narrow, or models from same provider family | Broaden prompt; add adversarial framing; use diverse provider families |
| MCP rate-limit (9 calls/30s) blocks mid-task | Single-query loops in agent | Pass `queries: [array]` batched; instruct model to use `ctx_batch_execute` |
| Cross-model conflict can't be resolved automatically | Models give incomparable answers | Present all + document "no consensus" in `conflicts.md` |
| `task` tool returns "Unknown agent type: ocg-..." | Harness restricts `subagent_type` enum | Widen `permission.task` allow-list, or use Mechanism 2 |
| Model's CWD contains a stray `*.md` after dispatch | Model wrote to its own CWD instead of output dir | Copy the stray file to output dir; the report is still usable |
| Output dir contains `score-aggregate.md` (planned) but not in the contract | Old spec inconsistency | Ignore for v2.x; the section is in `consolidated.md` body as §5 Aggregated Scores |

**Retry policy:** the skill does **not** retry failed dispatches. If you need retries, wrap the dispatch in your own runner. This avoids infinite retry loops in shell wrappers with 2-min default timeouts.

---

## Proven provenance

The skill was first run end-to-end on 2026-06-27 for prior-art research. Inputs and outputs:

- **6 OCG models** dispatched in parallel via `opencode run --model`
- **Same prompt verbatim** to all 6
- **Results**: 150+ raw mentions → 36 unique products → 1 consolidated report at `docs/research-260624/SB_CONSOLIDATED_PRIOR_ART_REPORT.md`
- **All 4 scoring matrices** (from 4 of 6 agents) extracted and aggregated (median + range per dimension); the remaining 2 agents produced qualitative comparisons only (no scoring matrix). All category conflicts resolved and documented in §4 of the report.

**Folder-name note:** the run output lives at `docs/research-260624/` — the folder name encodes `2026-06-24` (a pre-existing convention from the docs directory), but the actual run was on **2026-06-27**. The folder name is the path; the run date is in the `timestamp` field of `run-manifest.json` and in the `Proven provenance` section above. Do not rename the folder — it's referenced by 30+ other paths.

See `rules/examples/research-prior-art.md` for how that run was structured. **That run is one example of many possible uses** — the skill is task-agnostic.

A self-review run (also on 2026-06-27) used the skill recursively to review itself. The consolidated review is at `docs/research-260624/multi-ai-self-review-20260627-083255/`. A round-2 self-review (v2.1.0) is at `docs/research-260624/multi-ai-self-review-r2-20260627-093345/`.

---

## See also

- `silver-bullet` — for managing the SDLC workflow that may consume `silver:multi-ai` outputs
- `find-skills` — to discover other SB skills
- For a deep 8-phase research methodology (when invoking a per-model prompt for research), use the host `deep-research` skill skill if available, or inline the methodology in the dispatch prompt
