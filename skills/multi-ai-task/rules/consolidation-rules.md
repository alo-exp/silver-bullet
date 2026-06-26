# Consolidation Rules — multi-ai-task (task-agnostic)

The algorithms for the cross-model consolidation phases. Generic — works for any task type that produces a list of items.

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

## Phase 2 — ALIGN: extract per-model structured data

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

## Phase 3 — DEDUP: build the canonical registry

### Alias mapping

Build an alias map from known patterns. Add new aliases as you discover them:

```js
const aliases = {
  'AutoGen/AG2': 'AutoGen',
  'AutoGen (maintenance)': 'AutoGen',
  'Microsoft Agent Framework (MAF)': 'Microsoft Agent Framework',
  'MAF': 'Microsoft Agent Framework',
  'Camunda': 'Camunda 8',
  'Conductor OSS': 'Conductor',
  'GitHub Spec Kit': 'Spec Kit',
  'BMAD Method': 'BMAD',
  // ... add as discovered
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

Mark a row's primary key as `aliases[n] = null` to drop it from the registry (don't count as an item):
- `Silver Bullet (ref)` — the reference, not a candidate
- `Candidate` — placeholder / broken row from a model
- Pure scoring-matrix headers (e.g., `Catalog of composable units`)

### Sort the registry

Sort by `entries.length` descending, then by canonical name. The "most-mentioned" items come first.

### Fuzzy match (when no schema)

If the model responses don't have a clear `primary_key` field, apply fuzzy matching on item titles:
- Normalize: lowercase, strip punctuation, collapse whitespace
- Match if normalized titles are ≥80% similar (Levenshtein or token-overlap)
- Tag fuzzy matches with `fuzzy_match: true` for human review

---

## Phase 3.5 — RESOLVE CONFLICTS

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

### `prefer-with-evidence-then-newer-then-strict` (for enumerated strings like category)

In order:
1. **Quoted primary source wins.** If one model has a primary quote supporting value X, and the others don't, prefer the cited one.
2. **Newer `last_verified` wins.** Check the source date for the candidate's evidence. Recency > staleness.
3. **Strict rule for `direct`/`adjacent`/`tangential`:** prefer `direct` only if ≥3 evidence criteria are met. Otherwise downgrade to `adjacent` and document the reason.
4. **Single-model outlier rule.** If 1 of 6 models says `direct` and 5 say `adjacent`, treat the lone `direct` as an outlier (downgrade).
5. **Tie-break:** prefer the value with the strongest evidence quote, then prefer the most recent.

### How to document resolutions

For each conflict, write to `conflicts.md`:

```markdown
| Item | Field | Disagreement | Resolution rule | Final value | Confidence |
|------|-------|-------------|-----------------|-------------|------------|
| LangGraph | category | mimo=`direct`, 4 others=`adjacent`, qwen=`tangential` | rule 4 (outlier downgrade) | `adjacent` | high |
| BMAD | maturity | deepseek=`negative-result`, 2 others=`adjacent` | rule 3 (strict) | `adjacent` | medium |
```

The user can override the default rules in the schema. For example, for code review, the user might want to use `most-severe` for `severity` (always pick the highest severity across reviewers) rather than `majority`.

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

## Phase 3.6 — SCORE + SYNTHESIZE

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
| **Fact-check** | Use `majority` for `verdict`; require ≥2 sources for `true` claims; `uncertain` if no consensus |
| **Ideation** | No dedup (every idea is unique); rank by median `feasibility` × `impact` score |
| **Writing critique** | Use `concatenate` for comments; present all model feedback in parallel sections |
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

Always resolve these on dedup when you encounter them. Add to this table as new aliases surface in future runs.

| Alias | Canonical |
|-------|-----------|
| AutoGen/AG2, AutoGen (maintenance) | **AutoGen** |
| MAF, Microsoft Agent Framework (MAF) | **Microsoft Agent Framework** |
| Camunda, Camunda 8 | **Camunda 8** |
| Conductor OSS, Conductor-OSS, Conductor (Netflix) | **Conductor** |
| GitHub Spec Kit | **Spec Kit** |
| GSD (Get Shit Done) | **GSD** |
| BMAD Method | **BMAD** |
| gh-aw, GitHub Agentic Workflows (gh-aw) | **GitHub Agentic Workflows** |
| OPA, Open Policy Agent, OPM | **OPA** |
| Claude Code Skills, Claude Code Hooks | **Claude Code** |
| Lunar | **Earthly Lunar** |
| Qodo, PR-Agent, Qodo / PR-Agent | **Qodo/PR-Agent** |
| Windsurf, Devin Desktop | **Windsurf** |
| Devin (Cognition), Devin (closed) | **Devin** |

(Add task-type-specific aliases as you encounter them. The skill is task-agnostic but the alias map grows over time.)
