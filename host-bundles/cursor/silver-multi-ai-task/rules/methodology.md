# Methodology — multi-ai-task (task-agnostic)

The skill works for any task the user provides. The methodology below is generic — no assumptions about the task type.

---

## Phase 1 — Per-model execution

The same `task-prompt` is sent to each of N models in parallel. Each model:

- Receives the prompt as a user message
- Has its own tool/MCP context (e.g., `webfetch`, `ctx_fetch_and_index`, `gh`)
- Produces a response

**Schema auto-injection (default ON):** if the user passes `--schema` and does **not** also pass `--no-auto-inject`, the skill appends a `## Required Output Schema` block (the JSON schema verbatim, plus a one-line instruction: "Return your answer as a markdown table with exactly these columns, and nothing that does not match this schema") to every dispatch prompt. This guarantees the model sees the column structure even if the user forgot to embed it. If the user's prompt already embeds the schema, pass `--no-auto-inject` to avoid duplication. The auto-inject state is recorded in `run-manifest.json → schema_auto_injected: true|false`.

**Output per model:** a single response (could be markdown, code, free-form text, or anything). The skill saves it to `<out-dir>/<model>.md` for capture.

If a model fails to produce a response (timeout, error, refusal), the failure is logged and the model is excluded from the consolidation. **The skill does NOT retry.** Retry logic lives in the calling agent's runner, not in the skill core — this avoids infinite retry loops in shell wrappers with 2-min default timeouts. Failures are recorded in `run-manifest.json → models_failed` with the stderr reason.

---

## Phase 2 — Output capture and extraction

For each model's response, the skill extracts structured data into `<out-dir>/structured.jsonl`:

```json
{"model": "m1", "row_id": 1, "item": "LangGraph", "primary_key": "LangGraph", "primary_key_raw": "**LangGraph**", "fields": {"category": "adjacent", "score": 3, "url": "https://github.com/langchain-ai/langgraph"}, "source_refs": ["minimax-m3.md#L42-50"], "raw_text": "LangGraph is a framework for..."}
```

Extraction modes (chosen by whether `--schema` is passed):

### Mode A — Structured (schema provided)

Pseudocode:

```js
function extractStructured(response, schema) {
  // 1. Find a markdown table with headers matching schema.columns
  //    - Tables may be inside ``` fences; strip fences first
  //    - Headers may be `| name | cat | ... |` or `name|cat|...` (no fences)
  //    - Match headers case-insensitively; allow synonyms ("cat" ↔ "category")
  const tableMatch = findTable(response, schema);
  if (tableMatch) return parseTableRows(tableMatch, schema);

  // 2. Fallback: explicit structured tags
  //    - Model may wrap response in <structured>...</structured> if its system prompt asks
  const tagMatch = extractStructuredTags(response);
  if (tagMatch) return parseStructuredTags(tagMatch, schema);

  // 3. Fallback: ask the extractor model to reformat
  //    - "extractor model" = the slowest/highest-capability model from the dispatch
  //      (NOT the model that produced the response — that model has already failed
  //      to produce structured output, asking it again is unlikely to help)
  //    - Prompt: "Reformat this response into the following JSON schema: <schema>.
  //      Original response: <response>"
  //    - Parse the extractor's JSON output
  const extractorOutput = dispatchExtractorModel(response, schema);
  if (extractorOutput) return parseExtractorOutput(extractorOutput, schema);

  // 4. Final fallback: one-row-per-paragraph (very lossy)
  //    - Only use if all other paths fail AND the response is paragraph-shaped
  return fallbackParagraphSplit(response, schema);
}
```

If the model returned a non-table response, the skill tries paths 2, 3, 4 in order.

**Row validation:** after extraction, validate each row against the schema:
- `required: true` fields must be present (drop row if missing; log warning)
- `type` constraints (`number` in `min..max`, `enum` in `values`, etc.) — drop invalid rows
- `max_words` for text fields — truncate with `...` marker

### Mode B — Free-form (no schema)

Pseudocode:

```js
function extractFreeform(response) {
  // 1. Split by H2 headings (## ...)
  //    - Each H2 section = one item
  //    - H1 (#) is the document title, not an item
  //    - H3+ are sub-content of the nearest H2
  const sections = splitByH2(response);
  if (sections.length >= 2) {
    return sections.map(s => ({
      primary_key: s.heading,
      body: s.body,
      claims: extractFirstSentences(s.body),
      urls: extractUrls(s.body)
    }));
  }

  // 2. Fallback: paragraphs
  //    - If response is single-block or has no H2s, split by blank lines
  //    - Each paragraph = one item
  //    - First 5 words = primary_key (fragile; flag fuzzy_match:true)
  return splitByParagraphs(response);
}
```

Fuzzy dedup is applied at the title level (see `consolidation-rules.md`).

**Extractor model — clarification:** the "extractor" model is a single designated model used for fallback extraction when a model returns non-structured output. It's NOT the model that produced the response (that model already failed to produce structured output; asking it again is unlikely to help). The extractor is a *new* LLM call with a prompt containing the original response and the schema. Cost: one additional LLM call per model whose structured extraction failed (paths 1 and 2 in the pseudocode). Default: the slowest/highest-capability model from the original dispatch. Override via the implementation; not a CLI parameter.

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

**The canonical schema lives in `rules/output-schema.md` § `run-manifest.json`.** All other files reference it. The full required-field list (cross-checked with `SKILL.md`, `methodology.md`, `output-schema.md`, and the failure-modes table) is in that single location. The field semantics, required vs optional, and all defaults are defined there — do not duplicate.

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
