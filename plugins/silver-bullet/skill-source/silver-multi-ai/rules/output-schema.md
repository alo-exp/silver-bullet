# Output Schema — multi-ai-task consolidated report

The structure of `consolidated.md` and the supporting files. Generic — works for any task type.

---

## The two output modes

The skill produces one of two output structures based on whether `--schema` is passed:

### Mode A — Structured (schema provided)

When the user passes `--schema <json>`, the skill renders the consolidated output in the schema's natural form. For example, if the schema declares `type: "table"`, the output is a single markdown table matching the schema columns.

### Mode B — Generic (no schema)

When no schema is passed, the skill uses the default output structure documented below.

---

## File header (both modes)

```markdown
# <Task Title> — Cross-Model Consolidated Report

**Date:** YYYY-MM-DD
**Mode:** quick | standard | thorough
**Models:** N total
**Coverage:** M unique items / P raw mentions / Q aggregations
**Source reports:**
- `<model-slug>.md` — <model-id> (size in KB / line count)
- ...

**Dispatch note:** brief note on the dispatch mechanism used (CLI subprocess, task tool, SDK), and any quirks (e.g., harness rejected custom subagent types; fell back to `--model` flag).
```

---

## §1. Executive Summary (≤300 words, both modes)

Terse overview. Include:

- 1-2 sentence headline
- Cross-model consensus (or the lack thereof)
- Closest matches (if applicable)
- Biggest gaps or divergences
- The 3-5 most important findings

Do NOT repeat data here. Point at the table for evidence.

---

## §2A. Items Table (Mode A — schema-defined table)

When `--schema` is provided with `type: "table"`, render the consolidated items in a markdown table matching the schema's `columns` definition.

When `--schema` is not provided, use the default items table:

| # | Item | Mentions | Fields per model | Primary Source | Top Finding |
|---|------|---------:|------------------|----------------|-------------|
| 1 | <canonical-key> | N | m1: {...}, m2: {...} | <url> | <one-sentence summary> |
| 2 | ... | | | | |
| ... |

**Field rules:**
- `Mentions`: integer count of how many models mentioned this item
- `Fields per model`: short summary like `m1: {cat: direct, score: 3}; m2: {cat: adjacent, score: 5}` (truncate if verbose)
- `Primary Source`: the most-cited URL or reference
- `Top Finding`: one-sentence summary of the most-cited finding

**Conflict marker legend (place at top of section):**

> **Conflict marker:** `value*` = field conflict: at least one model disagreed. Resolution rules: see §4.

(Use a code-span like `` `direct*` `` if your viewer is WYSIWYG-strict; bare `*` otherwise.)

---

## §2B. Items Table (Mode B — generic narrative)

Without a schema, render items as sections:

```markdown
### 1. <Canonical Item Name>
- **Mentions:** 6/6 models
- **Top source:** https://...
- **Consensus description:** <the merged body, picking the most detailed version with primary quote support>
- **Per-model notes:**
  - m1: <one-line summary of m1's take>
  - m2: <one-line summary of m2's take>
  - m3: <one-line summary of m3's take>
- **Confidence:** high | medium | low

### 2. <Next Item>
...
```

---

## §3. Per-Item Details (compact, both modes)

For each item, include a compact bullet. The fields depend on the task type; below is a generic template:

```markdown
- **<Canonical>**: <task-specific per-item analysis fields>
```

Examples by task type:
- **Research / comparative:** `gaps_vs_reference = ... ; reference_gaps_vs_them = ...`
- **Code review:** `which reviewers flagged it = [model1, model3]; severity = <most-severe>; suggested_fix = ...`
- **Fact-check:** `verdict_per_model = {m1: true, m2: false, m3: true}; primary_source = <url>; confidence = <lowest-of-majors>`
- **Ideation:** `feasibility = <median>; impact = <median>; novelty_vs_other_ideas = ...`
- **Writing critique:** `comments = <concatenated-all>; consistency_notes = ...`

Be specific. Not "less mature" but "lacks V-model rollup; has BPMN catalog". Not "smaller community" but "1k stars vs ref's 0". The format is consistent; the content is task-specific.

---

## §4. Conflicts & Resolutions (mandatory, both modes)

| Item | Field | Disagreement | Resolution rule | Final value | Confidence |
|------|-------|-------------|-----------------|-------------|------------|
| LangGraph | category | m1=`direct`, 4 others=`adjacent`, qwen=`tangential` | rule 4 (outlier downgrade) | `adjacent` | high |
| BMAD | maturity | deepseek=`negative-result`, 2 others=`adjacent` | rule 3 (strict) | `adjacent` | medium |

Always document the resolution rule used per row.

---

## §5. Aggregated Scores (optional, both modes)

If the user provides a scoring rubric or the models self-score, build a single table:

| item | dim1 | dim2 | ... | TOTAL (median) | Range | N |
|------|------|------|-----|---------------|-------|---|
| reference | 2 | 2 | ... | **16** | (all) | N |
| top candidate | 2 | 1 | ... | **8** | 6-9 | 6 |
| ... | | | | | | |

**Top N by total** = "best matches."

---

## §6. Negative Results (both modes)

Categories searched with no credible finds. Negative results are valuable — document them.

```markdown
- **<Category>** — no item found with <required capability>
- **<Another category>** — <details>
```

---

## §7. Open Questions (both modes)

What remains unclear after the task. Carry-forward items.

---

## §8. Synthesized Verdict (optional, both modes)

If the user asked for a specific output (e.g., "rank these candidates", "find the bug", "decide between X and Y"), include the synthesized verdict here.

---

## Appendix A — Cross-AI Source Map (both modes)

For each unique item, which model(s) found it:

```markdown
| Finding | Discovered by | Verified by | Notes |
|---------|---------------|-------------|-------|
| <Unique Item 1> | **<model>** | — | unique find; needs deeper validation |
| <Unique Item 2> | <model1>, <model2> | <model3> | convergent find |
| ... |
```

---

## Appendix B — Coverage Scoreboard (both modes)

```markdown
| Bucket | Found | Models contributing | Gap |
|--------|-------|---------------------|-----|
| <Bucket 1> | N | all M | <gap description> |
| <Bucket 2> | ... | | |
| **Total unique items** | **M** | — | target ≥K: <MET/MISSED> |
```

---

## Supporting files (always produced, both modes)

### `structured.jsonl`

One JSON per line per (model, item) — the raw extraction before consolidation:

```json
{"model": "m1", "row_id": 1, "primary_key": "LangGraph", "primary_key_raw": "**LangGraph**", "fields": {"category": "adjacent", "score": 3, "url": "..."}, "source_refs": ["minimax-m3.md#L42-50"], "raw_text": "LangGraph is a framework for..."}
```

### `conflicts.md`

Same as §4 but as a standalone file (for tooling that consumes it).

### `run-manifest.json`

**This is the canonical schema.** All other files reference this definition. Required fields (cross-checked with `SKILL.md`, `methodology.md`, and the failure-modes table):

```json
{
  "timestamp": "2026-06-27T07:30:00Z",
  "task_prompt": "...",
  "task_prompt_hash": "sha256:...",
  "mode": "standard",
  "schema_provided": true,
  "schema_auto_injected": true,
  "schema": { "type": "table", "columns": [...] },
  "models_dispatched": ["opencode-go/minimax-m3", "opencode-go/qwen3.7-max", "..."],
  "models_responded": ["m1", "m2", "..."],
  "models_failed": [],
  "output_dir": "./multi-ai-out/2026-06-27-0730/",
  "aliases": {"AutoGen/AG2": "AutoGen"},
  "totals": {
    "rows_per_model": {"m1": 25, "m2": 30, "m3": 18, "..."},
    "unique_items_consolidated": 36,
    "conflicts_resolved": 8
  },
  "consolidation": {
    "dedup_merges": 12,
    "score_aggregations": 25,
    "unresolved_conflicts": 0
  },
  "phases_completed": [1, 2, 3, 4]
}
```

**Field semantics:**
- `timestamp` — ISO-8601 UTC of when the run started
- `task_prompt` — the verbatim prompt sent to models (or `"..."` for privacy)
- `task_prompt_hash` — `sha256:` of the prompt bytes; useful for cache lookup and reproducibility audit
- `mode` — `quick` | `standard` | `thorough`
- `schema_provided` — did the user pass `--schema`?
- `schema_auto_injected` — was the schema auto-injected into the dispatch prompt? (v2.1.0+)
- `schema` — the full schema object (if provided); omitted if `schema_provided: false`
- `models_dispatched` — full `provider/model` IDs of all dispatched models
- `models_responded` — bare slugs of models that returned a response
- `models_failed` — list of `{model, stderr_excerpt, exit_code}` per failure (empty list = all succeeded)
- `output_dir` — the output directory path
- `aliases` — task-specific alias map applied during dedup (v2.1.0+); empty `{}` if no aliases
- `totals` — high-level stats: per-model row counts, unique consolidated items, conflicts resolved
- `consolidation` — detailed stats: dedup merges, score aggregations, unresolved conflicts
- `phases_completed` — list of phase numbers that produced output (for partial-failure auditing)

---

## Markdown formatting rules (CRITICAL for WYSIWYG viewer compatibility)

The consolidated report must be WYSIWYG-safe. Apply these rules:

1. **Use code spans (backticks), not bold-italic, for inline markers.** `direct*` → `` `direct*` ``, not `**direct***`.
2. **Add blank line before AND after every table.** Most WYSIWYG viewers fail on `paragraph\n| table |` adjacency.
3. **Never use triple-asterisk `***`.** If you need bold+asterisk, use `**bold**` followed by `*literal*` with a space.
4. **Avoid unicode in cells when possible.** `—` → `--`, `→` → `->`, `≥` → `>=`. The middle dot `·` and section sign `§` are safe.
5. **All delimiter rows must start and end with `|`.** `|---|---|` is fine; `---|---|` is fragile.
6. **Header cells must equal body cell count** for every row.
7. **Wrap tables in clean code blocks** when rendering for the web; let the viewer's GFM parser handle the rest.

See the worked example at `docs/research-260624/SB_CONSOLIDATED_PRIOR_ART_REPORT.md` for a fully-compliant example.
