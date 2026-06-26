# Methodology — multi-ai-task (task-agnostic)

The skill works for any task the user provides. The methodology below is generic — no assumptions about the task type.

---

## Phase 1 — Per-model execution

The same `task-prompt` is sent to each of N models in parallel. Each model:

- Receives the prompt as a user message
- Has its own tool/MCP context (e.g., `webfetch`, `ctx_fetch_and_index`, `gh`)
- Produces a response

**No domain-specific instructions are added by the skill.** The user is responsible for crafting the prompt to elicit the output they want (a table, code, prose, etc.). If the user passes a `--schema`, the prompt should include that schema as a constraint; the skill does NOT auto-append it.

**Output per model:** a single response (could be markdown, code, free-form text, or anything). The skill saves it to `<out-dir>/<model>.md` for capture.

If a model fails to produce a response (timeout, error, refusal), the failure is logged and the model is excluded from the consolidation. The skill does NOT retry, but the run-manifest.json records the failure.

---

## Phase 2 — Output capture and extraction

For each model's response, the skill extracts structured data into `<out-dir>/structured.jsonl`:

```json
{"model": "m1", "row_id": 1, "item": "LangGraph", "category": "adjacent", "score": 3, "evidence": "...", "url": "...", "raw_text_ref": "line 42-50"}
```

Extraction modes (chosen by whether `--schema` is passed):

### Mode A — Structured (schema provided)

- Parse the model's response looking for a markdown table with headers matching the schema
- Map columns by header name (case-insensitive, allow `cat` ↔ `category`, `pw` ↔ `parent_worker`, etc.)
- Skip rows that don't match the schema shape
- Each row becomes one JSONL line tagged with the model name

If the model returned a non-table response, the skill:
- Looks for explicit structured tags like `<structured>...</structured>`
- Asks the "extractor" model (default: same model) to reformat its answer into the schema
- Falls back to one-row-per-paragraph if all else fails

### Mode B — Free-form (no schema)

- Split the response by H2 headings (each section = one item)
- For each section, extract: title, body text, key claims, any embedded URLs
- Each section becomes one JSONL line with `item=title, body=text, claims=[...], urls=[...]`
- Fuzzy dedup applied at the title level (see consolidation-rules.md)

---

## Phase 3 — Cross-model consolidation

For each unique item (by `primary_key` from schema or by fuzzy title match in free-form mode):

1. **Aggregate**: collect all entries from all N models
2. **Dedup**: items with the same `primary_key` (or fuzzy-matched title) are merged
3. **Conflict resolution**: for each non-key field, apply the configured resolution rule
4. **Score aggregation**: if the schema has a numeric score field with `aggregate: "median"`, compute median + min/max across models
5. **Confidence**: number of models that found the item, plus per-field agreement

Output: a single canonical record per item, stored in `structured.jsonl` (append mode with `model: "_consolidated"`).

---

## Phase 4 — Final synthesis

The skill produces:

### `consolidated.md`

The primary deliverable. Structure depends on whether a schema was passed:

- **With schema**: renders the consolidated records in the schema's natural form (e.g., a markdown table matching the schema columns)
- **Without schema**: a section per unique item, with the merged body + per-model notes

### `consolidated.html`

Self-contained HTML render of `consolidated.md` (CSS embedded, no external resources). For users who need to share or view in a browser.

### `conflicts.md`

For every field where models disagreed, document:
- The disagreement (what each model said)
- The resolution rule applied
- The final value
- Confidence level

### `run-manifest.json`

```json
{
  "timestamp": "2026-06-27T07:30:00Z",
  "task_prompt": "...",
  "task_prompt_hash": "sha256:...",
  "mode": "standard",
  "schema_provided": true,
  "models_dispatched": ["opencode-go/minimax-m3", "opencode-go/qwen3.7-max", "..."],
  "models_responded": ["m1", "m2", "..."],
  "models_failed": [],
  "output_dir": "./multi-ai-out/2026-06-27-0730/",
  "totals": {
    "rows_per_model": {"m1": 25, "m2": 30, "m3": 18, "..."},
    "unique_items_consolidated": 36,
    "conflicts_resolved": 8
  },
  "consolidation": {
    "dedup_merges": 12,
    "score_aggregations": 25,
    "unresolved_conflicts": 0
  }
}
```

---

## Cross-cutting principles

### Generic by design
The skill makes ZERO assumptions about the task type. Whether the user is doing research, code review, fact-checking, ideation, or any other task, the same 4 phases apply.

### Deterministic + LLM-assisted hybrid
- Structured extraction (Mode A) is deterministic — pure parsing, no LLM in the loop
- Free-form extraction (Mode B) uses an LLM step to reformat — slower but more flexible
- Conflict resolution uses configured rules, not LLM judgment
- If a model fails, the skill still produces a partial consolidated output from the models that did respond

### Audit trail
Every step is recorded:
- The exact prompt sent
- Each model's raw response
- The structured extraction per model
- The conflict resolutions applied
- The final consolidated output

The user can always re-run with `--schema` to get structured output, or with `--mode quick` to skip consolidation and get raw per-model responses merged.

### Idempotent re-runs
The skill can be re-run with the same `task-prompt` and produce a new consolidated output. It does NOT cache across runs by default (each run is fresh), but the `run-manifest.json` from previous runs can be referenced for incremental consolidation (future enhancement).
