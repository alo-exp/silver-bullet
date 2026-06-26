# Consolidation Rules — multi-ai-task

The algorithms for the cross-model consolidation phases (C1-C4 in methodology.md).

---

## Phase C1: ALIGN — extract per-model structured data

For each model report, extract the summary table's rows into a normalized record:

```json
{
  "model": "opencode-go/minimax-m3",
  "name_raw": "**LangGraph**",
  "name_normalized": "LangGraph",
  "url": "https://github.com/langchain-ai/langgraph",
  "category_raw": "adjacent",
  "category": "adjacent",
  "v_loop": "end-only (interrupts)",
  "dynamic": "replanner",
  "parent_worker": "partial",
  "evidence_model": "informal",
  "maturity": "production (v1.2.6, Jun 2026)",
  "composition_model": "Stateful DAG; nodes/edges; subgraphs; Command routing",
  "enforce": "honor",
  "se_fit": "partial",
  "devops_fit": "none",
  "confidence": "high",
  "last_verified": "2026-06-27",
  "score_per_dim": {"cat": 0, "dyn": 1, "v": 1, "e": 0, "pw": 1, "ev": 0, "sd": 0, "cu": 0}
}
```

**Table-extraction tips:**
- The summary table is usually after a heading like `## Summary Table` or `## Top 5 Summary`
- Header row has 10-16 cells, with the first being `#` or `name`
- Skip separator rows (`|---|---|`)
- Stop at the first non-table line after the table
- Handle these header variants: `cat` / `category` / `classification` → `category`; `v_loop` / `v-loop` / `v` → `v_loop`; `p_w` / `p/w` / `pw` → `parent_worker`; `enforce` / `enf` / `e` → `enforce`

**Table parser pseudocode (Node):**

```js
function extractRows(content, model) {
  // 1. Find "## Summary Table" or similar heading
  // 2. Find next | line → that's the header
  // 3. Skip separator row (next line)
  // 4. For each subsequent | line, parse into cells
  // 5. Stop at first non-table line
  // 6. Skip rows where the first cell is empty or pure digits (index column)
}
```

---

## Phase C2: DEDUP — build the canonical registry

### Alias mapping

Build an alias map from known rebrandings/fork patterns. Add new aliases as you discover them:

```js
const aliases = {
  'AutoGen/AG2': 'AutoGen',
  'AutoGen (maintenance)': 'AutoGen',
  'Microsoft Agent Framework (MAF)': 'Microsoft Agent Framework',
  'MAF': 'Microsoft Agent Framework',
  'Camunda': 'Camunda 8',
  'Conductor OSS': 'Conductor',
  'Conductor-OSS': 'Conductor',
  'GitHub Spec Kit': 'Spec Kit',
  'GSD (Get Shit Done)': 'GSD',
  'BMAD Method': 'BMAD',
  // ... add as discovered
};
```

### Dedup algorithm

```js
const registry = {};  // canonical name -> {models: Set, entries: []}
for (const row of allRows) {
  const canonical = normalize(row.name);  // apply aliases
  if (canonical === null) continue;  // explicit skip
  if (!registry[canonical]) {
    registry[canonical] = { entries: [], categories: new Set(), models: new Set(), urls: new Set() };
  }
  registry[canonical].entries.push(row);
  registry[canonical].categories.add(row.category);
  registry[canonical].models.add(row.model);
  registry[canonical].urls.add(row.url);
}
```

### Skip rules

Mark a row as `aliases[n] = null` to drop it from the registry (don't count as a product):
- `Silver Bullet (ref)` — the reference, not a candidate
- `Candidate` — placeholder / broken row from a model
- Pure scoring-matrix headers (e.g., `Catalog of composable units`)

### Sort the registry

Sort by `entries.length` descending, then by canonical name. The "most-mentioned" items come first.

---

## Phase C3: RESOLVE CONFLICTS

### Category conflict resolution (priority order)

For each canonical row, look at `categories: {direct, adjacent, tangential, negative-result}`. Apply in order:

1. **Quoted primary source wins.** If one model has a primary quote supporting `direct`, and the others don't, prefer the quoted one.
2. **Newer `last_verified` wins.** Check the source date for the candidate's evidence. Recency > staleness.
3. **Permission rule: prefer `direct` only if ≥3 SB-differentiator-equivalent criteria are evidenced.** Otherwise downgrade to `adjacent` and document the reason.
4. **Single-model outlier rule.** If 1 of 6 models classifies as `direct` and 5 as `adjacent`, treat the lone `direct` as an outlier (downgrade). Same for `negative-result`.
5. **Tie-break:** prefer the classification with the strongest evidence quote, then prefer the most recent.

For each conflict resolution, document in the report's `## 4. Unresolved Conflicts` section:

| Candidate | Disagreement | Resolution per rule | Confidence |
|-----------|-------------|---------------------|------------|
| LangGraph | mimo=`direct`, 4 others=`adjacent`, qwen=`tangential` | downgrade to adjacent: mimo's `direct` not supported by primary quote (only graph primitives + interrupts + subgraphs, no SDLC catalog / V-loops / enforcement) | high |

### Score conflict resolution

For each candidate × dimension, compute:

- **median** of all numeric scores across N models
- **range** (min, max) — the spread
- **N** — number of models that provided a score

If only 1 model scored a candidate, note it as "(1 model)" in the range column. If a dimension wasn't scored by any model, use `—`.

### Maturity / version conflict

For version-number disagreements, use the **newer** `last_verified` date. Confirm against the official release page (e.g., GitHub releases tab).

For "beta" vs "production" disagreements, use the project's most recent release tag from the official source.

---

## Phase C4: SCORE + SYNTHESIZE

### Scoring matrix

Build a single table:

| candidate | cat | dyn | v | e | pw | ev | sd | cu | TOTAL (median) | Range |
|-----------|:---:|:---:|:-:|:-:|:--:|:--:|:--:|:--:|:--:|:--:|
| Silver Bullet (reference) | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | **16** | (all) |
| Camunda 8 | 2 | 1 | 1 | 1 | 1 | 1 | 0 | 1 | **7** | 4-8 |
| ... | | | | | | | | | | |

**Columns are the 8 SB-differentiator dimensions** (catalog of composable units, dynamic composition, V-loop depth, enforcement, parent/worker split, evidence model, SE+DevOps unified, team customization). Each scored 0-2.

**Top 3 by total** = "closest architectural matches to SB."

### Qualitative-only models

If 2+ models produced only qualitative comparisons (no numeric scores), include them in the qualitative "Top 3 by qualitative rubric" sub-list, separately from the numeric scoring. Document which models provided numeric vs qualitative.

### Final synthesis sections

| Section | Content |
|---------|---------|
| Executive Summary (≤300 words) | cross-model consensus; closest direct matches; biggest market gaps |
| Dedup Table (one row per distinct item) | 15-30 rows; canonical name; mentions; categories; URL; top finding |
| Per-Row Gaps | compact `gaps_vs_subject` and `subject_gaps_vs_them` bullets |
| Evidence Blocks | per-row quote + url + source_type + version |
| Scoring Matrix | median + range; total; top 3 |
| Top 5 Direct Competitors | ranked with rationale; documented evidence |
| Top 5 Adjacent Inspirations | what subject could borrow; ranked |
| Negative Results | categories searched with no credible finds |
| Open Questions | what remains unclear after the research |
| 1-Page Positioning Memo (deep/ultradeep) | where subject sits; concentric circles of competition; threats; opportunities |
| Appendix A — Cross-AI Source Map | which model found which unique item |
| Appendix B — Coverage Scoreboard | bucket → found / target / gap |

---

## Conflict-log format (for §4 of the report)

```markdown
## 4. Unresolved Conflicts

### 4.1 Category disagreements
| Candidate | Disagreement | Resolution per §8.2 |
|-----------|-------------|---------------------|
| **LangGraph** | mimo=`direct`, 4 others=`adjacent`, qwen=`tangential` | **downgrade to adjacent**: mimo's `direct` not supported by primary quote; only graph primitives + interrupts + subgraphs, no SDLC catalog / V-loops / enforcement. Confidence: high. |
| ... |

### 4.2 Maturity / version
- **AutoGen** — unanimous "maintenance mode"; superseded by MAF.
- ... |

### 4.3 Coverage gaps
- **deepseek**: BMAD/GSD/Superpowers private; Devin closed; ...
- ...
```

---

## Aliases (canonical resolution table)

Always resolve these on dedup:

| Alias | Canonical |
|-------|-----------|
| AutoGen/AG2, AutoGen (maintenance) | **AutoGen** |
| MAF, Microsoft Agent Framework (MAF) | **Microsoft Agent Framework** |
| Camunda, Camunda 8 | **Camunda 8** |
| Conductor OSS, Conductor-OSS, Conductor (Netflix) | **Conductor** |
| GitHub Spec Kit | **Spec Kit** |
| GSD (Get Shit Done) | **GSD** |
| BMAD Method | **BMAD** |
| Antigravity Ultimate SDLC Framework | **Antigravity Ultimate SDLC** |
| gh-aw, GitHub Agentic Workflows (gh-aw) | **GitHub Agentic Workflows** |
| OPA, Open Policy Agent, OPM | **OPA** |
| Claude Code Skills, Claude Code Hooks | **Claude Code** |
| DeerFlow (ByteDance) | **DeerFlow** |
| Anthropic "Building Effective Agents" | **Anthropic Building Effective Agents** |
| Lunar | **Earthly Lunar** |
| Qodo, PR-Agent, Qodo / PR-Agent | **Qodo/PR-Agent** |
| Windsurf, Devin Desktop | **Windsurf** |
| Devin (Cognition), Devin (closed) | **Devin** |

Add to this table as new aliases surface in future runs.
