# Consolidation Rules — multi-ai-task (task-agnostic)

The algorithms for the cross-model consolidation phases. Generic — works for any task type that produces a list of items.

---

## Phase mapping (methodology.md ↔ consolidation-rules.md)

`methodology.md` uses 4 high-level phases (1–4). `consolidation-rules.md` uses 4 detailed sub-phases (2–5) that fit inside methodology's phases 2–3. The mapping:

| methodology.md phase | consolidation-rules.md sub-phase(s) | What it does |
|---------------------|----------------------------------------|--------------|
| Phase 1 (Per-model execution) | — (dispatch happens before consolidation) | Same prompt sent to N models in parallel |
| Phase 2 (Output capture and extraction) | Phase 2 (ALIGN) | Per-model outputs are aligned into a uniform structure (`structured.jsonl`) |
| Phase 3 (Cross-model consolidation) | Phase 3 (DEDUP) + Phase 4 (Resolve + Aggregate) | Dedup by primary key → resolve conflicts → aggregate scores |
| Phase 4 (Final synthesis) | Phase 5 (SCORE + SYNTHESIZE) | Write `consolidated.md` + HTML preview + `conflicts.md` + `evidence-ledger.md` (thorough mode) |

This sub-phase numbering (2, 3, 4, 5) matches `methodology.md`'s 4-phase pipeline with an offset. Every consolidation sub-phase links back to the corresponding methodology phase.

---

## The minimal contract for consolidation

For the consolidation step to work, the model responses need to be decomposable into **items**. An item has:
- A unique identity (so dedup can work)
- Zero or more fields describing the item
- Optional source/evidence pointers

The skill doesn't care what an item IS — could be:
- A research candidate (LangGraph, BMAD, etc.)
- A code-review finding (file:line, severity, message)
- A fact-check claim (claim, verdict, source)
- An idea (title, description, feasibility)
- A bug report (title, repro, severity)
- A product feature (name, value, audience)

What matters is that the responses are list-shaped, and items within a response can be identified, compared, and merged.

---

## Phase 2 — Output capture and extraction (ALIGN)

Per `methodology.md:23`, Phase 2 is output capture and extraction. In the consolidation pipeline, this sub-phase is called "ALIGN" because its job is to align per-model outputs into a uniform structure.

For each model report, extract the per-item data into a normalized record:

```json
{
  "model": "<model-id>",
  "primary_key": "<unique identifier for this item>",
  "primary_key_raw": "<verbatim text from the model>",
  "fields": {
    "<field-name>": "<value>",
    ...
  },
  "source_refs": ["<url>", "<line-ref>"],
  "confidence_self": "high|medium|low"
}
```

**Table-extraction tips (when output is a markdown table):**
- The summary table is usually after a heading like `## Summary Table` or `## Top 5 Summary`
- Header row has 10-16 cells, with the first being `#` or `name`
- Skip separator rows (`|---|---|`)
- Stop at the first non-table line after the table
- Handle these header variants: `cat` / `category` / `classification` → `category`; `pw` / `p/w` / `parent_worker` → `parent_worker`; `enf` / `enforce` → `enforce`

**List-extraction tips (when output is a numbered or bulleted list):**
- Each numbered/bulleted item = one record
- The "head" of the item (number, name) is the primary key
- Body content is the "fields" blob

**Free-form extraction (when output is prose):**
- Split by H2 headings
- Each section = one item
- Item title = H2 text
- Item body = paragraph(s) under the H2

**Table parser pseudocode (Node):**

```js
function extractRows(content, model) {
  // 1. Find "## Summary Table" or similar heading
  // 2. Find next | line → that's the header
  // 3. Skip separator row (next line)
  // 4. For each subsequent | line, parse into cells
  // 5. Stop at first non-table line after the table
  // 6. Skip rows where the first cell is empty or pure digits (index column)
  // 7. Skip rows that are scoring-matrix headers (e.g., "Catalog of composable units")
}
```

---

## Phase 3 — Cross-model consolidation (DEDUP)

Per `methodology.md:108`, Phase 3 is cross-model consolidation. The DEDUP step within Phase 3 is where items with the same primary key are merged.

### Alias mapping

 Build an alias map for your task type. The default (no aliases) is `lowercase + strip-punctuation + collapse-whitespace + exact match`. For semantic dedup (e.g., `AutoGen` ↔ `AG2`), supply an alias map at run time. The alias map is **task-specific** — see `rules/examples/research-prior-art.md` for a 14-entry research alias map. A code-review or fact-check run would have a different alias map (or none).

Example skeleton (fill in for your task):

```js
const aliases = {
  // '<alias>': '<canonical>',
  // Add as you discover variants. Persist to run-manifest.json → aliases.
};
```

### Dedup algorithm

```js
const registry = {};  // canonical name -> {models: Set, entries: []}
for (const row of allRows) {
  const canonical = normalize(row.primary_key);  // apply aliases
  if (canonical === null) continue;  // explicit skip
  if (!registry[canonical]) {
    registry[canonical] = {
      entries: [],
      fields_per_model: {},  // {model: {field: value}}
      models: new Set(),
    };
  }
  registry[canonical].entries.push(row);
  registry[canonical].fields_per_model[row.model] = row.fields;
  registry[canonical].models.add(row.model);
}
```

### Skip rules

Mark a row's primary key as `aliases[n] = null` to drop it from the registry (don't count as an item). Generic skip rules for any task type:
- **Placeholder rows** (e.g., `Candidate`, `N/A`, `—`, `TBD`) — broken or empty model output
- **Header rows that were incorrectly parsed as data** (e.g., when a model emits column headers as a separate row)
- **The reference item itself** (if the task compares candidates against a reference; the reference is what the candidates are compared TO, not a candidate)
- **Scoring-matrix header rows** (for tasks that include a scoring matrix; the column-dimension names like "Catalog of composable units" might leak into the items table)

Task-type-specific skip entries belong in the alias map for that task's recipe, not in the core rules.

### Sort the registry

Sort by `entries.length` descending, then by canonical name. The "most-mentioned" items come first.

### Fuzzy match (when no schema)

If the model responses don't have a clear `primary_key` field, apply fuzzy matching on item titles:
- Normalize: lowercase, strip punctuation, collapse whitespace
- Match if normalized titles are ≥80% similar (Levenshtein or token-overlap)
- Tag fuzzy matches with `fuzzy_match: true` for human review

---

## Phase 4 — Conflict resolution and aggregation

In the consolidation pipeline, Phase 4 includes both the conflict-resolution step (formerly labeled "Phase 3.5" in the original numbering) and the score-aggregation step (formerly "Phase 3.6"). This phase takes the dedup'd registry from Phase 3 and produces the final consolidated record set.

For each canonical item, look at the per-field values across models. Apply the configured resolution rule per field.

### Default conflict resolution rules

These rules apply when the user doesn't pass a `--schema` with custom rules. The user can override per field in the schema.

| Field type | Default rule | Rationale |
|---|---|---|
| `string` (enumerated) | `prefer-with-evidence-then-newer-then-strict` | See below |
| `number` (score) | `median` | Robust to outliers |
| `boolean` | `majority` | Simple majority wins |
| `url` | `most-cited` (highest count) | URL with most citations is likely most authoritative |
| `date` | `newer` (max date) | Recency wins for maturity fields |
| `text` (long form) | `longest-with-quote` | Keep the most detailed version with primary quote support |
| `url_list` | `union-dedup` | Merge all URL lists; dedup by normalized form |
| `composite key` | `merge-exact` | See schema spec for composite key syntax |

### `prefer-with-evidence-then-newer-then-strict` (for enumerated strings like category)

In order:
1. **Quoted primary source wins.** If one model has a primary quote supporting value X, and the others don't, prefer the cited one.
2. **Newer `last_verified` wins.** Check the source date for the candidate's evidence. Recency > staleness.
3. **Single-model outlier rule.** If 1 of 6 models says `direct` and 5 say `adjacent`, treat the lone `direct` as an outlier (downgrade).
4. **Tie-break:** prefer the value with the strongest evidence quote, then prefer the most recent.

### Custom resolution rule library (the "named rules" the examples use)

The following rules are referenced in the example recipes (`rules/examples/`) and in custom `--schema` configurations. **All are implementable algorithms**, not aspirational labels.

#### `most-severe`
- **Purpose:** pick the most-severe value across models (default for code-review severity, security audit findings).
- **Input:** List of `(value, severity_order?)` per model. If `severity_order` is declared in the schema, use it. Otherwise default to: `["blocker", "major", "minor", "nit"]` (most-severe first).
- **Algorithm:** `min(values, key=severity_order.index)` — index 0 = most-severe (`blocker`), index N-1 = least-severe. So `min` returns the value with the smallest index, i.e., the most-severe. Ties broken by `majority` among the max-severity tier. If N=0, return `null` (or the schema default).
- **Edge case:** if 1/N reviewers says `blocker` and all others say `major` (or lower), and the lone `blocker` has no evidence quote, the schema may declare `"allow_downgrade": true` to downgrade the lone max to the next-severity tier. **Default: `allow_downgrade: false`** — the most-severe value wins even if only 1 reviewer reported it. This matches the code-review safety principle: "don't downgrade a blocker just because one reviewer missed it." Set `allow_downgrade: true` only when the task context requires conservative consensus (e.g., security audit with high false-positive risk).
- **Implementation note:** if the schema declares `severity_order`, the convention is **most-severe first** (index 0 is the most-severe value). This is the natural reading order ("blocker, major, minor, nit" reads from worst to best). If you reverse the convention, the algorithm needs `max` instead — but don't do that; the rule library assumes most-severe-first ordering everywhere.

#### `majority`
- **Purpose:** pick the most-frequent value.
- **Input:** List of values per model.
- **Algorithm:** `Counter(values).most_common(1)[0]`. Ties broken by schema-defined enumeration order (first listed wins). If all values are unique (no majority), return `null` and flag in `conflicts.md` as "no majority".
- **Edge case:** with 2 models and 2 different values, no majority — return `null`.

#### `majority-with-uncertain`
- **Purpose:** like `majority`, but require a *strict* majority threshold; if not met, return `unverified` (default for fact-check verdicts).
- **Input:** List of values per model.
- **Algorithm:** require `> max(2, ceil(N/2))` models to agree on a value (i.e., any dissent blocks consensus). For N=3, all 3 must agree; for N=5, at least 4 must agree; for N=7, at least 5 must agree. If met, return that value. If not, return `unverified`.
- **Edge case:** with N=1, single vote never reaches the threshold; return `unverified`. With N=2, two models must agree exactly (any dissent returns `unverified`).
- **Rationale for strict-majority:** this is the "high-stakes" rule — used for fact-check, security audit, regulatory review. Any dissent (even 1 of N) blocks consensus. If you want "any agreement is consensus", use `majority` instead.
- **Naming consistency:** the rule returns the value `unverified` (matching the schema's `values: ["true", "false", "partially-true", "unverified"]`). If a user schema uses a different name for the "unverified" verdict (e.g., `partially-true`), set `conflict_resolution.verdict_uncertain_value: "partially-true"` to remap. Do NOT change the rule's return value to match the schema — change the schema to match the rule.

#### `lowest-of-majors`
- **Purpose:** when combining verdict + confidence, use the majority verdict but the lowest confidence among the majority voters (default for fact-check).
- **Input:** List of `(value, confidence)` per model.
- **Algorithm:** first apply `majority` to get the majority value; then among the models voting for that value, return the lowest confidence (`high > medium > low`).
- **Edge case:** if only 1 model voted for the majority value, return its confidence unchanged.

#### `longest-with-quote`
- **Purpose:** keep the most detailed value (default for text fields).
- **Input:** List of values per model.
- **Algorithm:** prefer the value with the most words AND at least one inline quote (e.g., `"..."`). Tie-break by recency (model's `last_verified` if present, else the order in the input list).
- **Edge case:** if no value has an inline quote, fall back to longest by word count.

#### `concatenate-all`
- **Purpose:** preserve all models' values (default for evidence/quote collection in fact-check).
- **Input:** List of values per model.
- **Algorithm:** return all values joined by ` ; ` (or the schema's `separator` field if defined). Order: by model name (alphabetical) for determinism.
- **Edge case:** empty values are skipped (not included in the join).

#### `all-collected`
- **Purpose:** like `concatenate-all`, but tag each value with the model that produced it.
- **Input:** List of values per model.
- **Algorithm:** return a list of `{model, value}` objects. Preserves provenance for human review.
- **Edge case:** empty values are skipped.

#### `union-dedup`
- **Purpose:** merge all values into a single deduplicated set (default for `url_list`).
- **Input:** List of values per model.
- **Algorithm:** normalize each value (lowercase, trim, strip trailing slashes for URLs); dedup; return sorted set.
- **Edge case:** if all models produced empty lists, return empty.

#### `merge-exact`
- **Purpose:** combine per-field entries with identical primary keys (default for composite-key dedup).
- **Input:** List of `(primary_key, fields)` per model.
- **Algorithm:** group by primary key; for each group, union all fields; for fields that conflict across models, apply the schema's per-field resolution rule.
- **Edge case:** if the primary key is malformed (doesn't match the schema's composite pattern), log and skip the entry.

### How to document resolutions

For each conflict, write to `conflicts.md`:

```markdown
| Item | Field | Disagreement | Resolution rule | Final value | Confidence |
|------|-------|-------------|-----------------|-------------|------------|
| LangGraph | category | mimo=`direct`, 4 others=`adjacent`, qwen=`tangential` | outlier downgrade (1 of 6 says `direct` with no evidence quote) | `adjacent` | high |
| BMAD | maturity | deepseek=`negative-result`, 2 others=`adjacent` | majority (3/3 prefer `adjacent` after outlier downgrade) | `adjacent` | medium |
| security finding | severity | reviewer-A: blocker, B-D: major | most-severe | `blocker` | high |
| claim X | verdict | 2 say `true`, 1 says `false` | majority-with-uncertain (threshold not met) | `unverified` | high |
```

The user can override the default rules in the schema. For example:

```json
{
  "conflict_resolution": {
    "severity": "most-severe",
    "category": "majority",
    "verdict": "majority-with-uncertain"
  }
}
```

### Score conflict resolution

For each item × numeric dimension, compute:

- **median** of all numeric values across N models
- **range** (min, max) — the spread
- **N** — number of models that provided a value

If only 1 model scored an item, note it as `(1 model)` in the range column. If a dimension wasn't scored by any model, use `—`.

### Maturity / version conflict

For version-number disagreements, use the **newer** `last_verified` date. Confirm against the official release page.

For "beta" vs "production" disagreements, use the project's most recent release tag from the official source.

---

## Phase 5 — SCORE + SYNTHESIZE

### Aggregate scoring matrix

Build a single table:

| item | dim1 | dim2 | ... | TOTAL (median) | Range | N |
|------|------|------|-----|---------------|-------|---|
| reference | 2 | 2 | ... | **16** | (all) | N |
| top candidate | 2 | 1 | ... | **8** | 6-9 | 6 |
| ... | | | | | | |

**Top N by total** = "best matches to the user's reference."

### Final synthesis sections

The exact structure of `consolidated.md` depends on whether the user passed a schema. With a schema, follow the schema's natural output format. Without a schema, default to:

| Section | Content |
|---------|---------|
| Executive Summary (≤300 words) | cross-model consensus; closest matches; biggest gaps |
| Items Table (one row per distinct item) | 15-30 rows; canonical key; mentions; fields; source |
| Per-Item Details | expanded fields + evidence per item |
| Conflicts & Resolutions | per-field disagreements + resolution rules + final values |
| Aggregated Scores (if applicable) | median + range per item × dimension |
| Negative Results | items models searched for but found nothing |
| Open Questions | what remains unclear after the task |
| Appendix: Cross-AI Source Map | which model found which unique item |
| Appendix: Coverage Scoreboard | bucket → found / target / gap |

---

## Custom consolidation strategies

For specific task types, override the defaults:

| Task type | Custom strategy |
|-----------|-----------------|
| **Code review** | Use `most-severe` for `severity` field; dedup by `file:line` (not file alone) |
| **Fact-check** | Use `majority` for `verdict`; require ≥2 sources for `true` claims; `unverified` if no consensus |
| **Ideation** | No dedup (every idea is unique); rank by median `feasibility` × `impact` score |
| **Writing critique** | Use `concatenate-all` for comments; present all model feedback in parallel sections |
| **Translation verification** | Use `majority` for `accurate`; flag any disagreements for human review |

The user can specify these custom strategies in the `--schema` JSON, e.g.:

```json
{
  "type": "code-review",
  "dedup_key": "file:line",
  "conflict_resolution": {
    "severity": "most-severe",
    "category": "majority"
  }
}
```

---

## Aliases (canonical resolution table)

**The alias map is task-specific**, not part of this skill's core. For example, the prior-art research run has a 14-entry alias table (AutoGen ↔ AG2, MAF ↔ Microsoft Agent Framework, etc.) that lives in `rules/examples/research-prior-art.md` because it's research-only. A code-review or fact-check run would have a different alias map (or none).

**To use aliases in your run:**
1. Build the alias map for your task type (or start with no aliases and add as the models surface variants)
2. Apply the alias map in the `normalize()` step of the dedup algorithm (line 100-116)
3. Document the alias map in your run's `run-manifest.json → aliases` field so the consolidation is reproducible

**The default behavior** (no aliases) is: normalize = lowercase + strip-punctuation + collapse-whitespace, then exact match. This catches `AutoGen` vs `autogen` and `BMAD Method` vs `BMAD-Method`, but not `AutoGen` vs `AG2` (semantic equivalence). For semantic dedup, you need an alias map.
