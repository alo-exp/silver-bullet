# Methodology — multi-ai-task

## Per-model pipeline (the 8-phase deep-research methodology, applied per model)

Each model receives the same prompt and runs the following 8 phases. The consolidation skill then aggregates across N models.

### Phase 1 — SCOPE
Confirm understanding of the task. Restate the question in your own words. Identify the in-scope vs out-of-scope items.

### Phase 2 — PLAN
List ~25-30 candidate items across all relevant categories. Identify primary sources to consult.

### Phase 3 — RETRIEVE
Run parallel fetches via:
- `webfetch` (single URL)
- `ctx_fetch_and_index` (batch URL with auto-indexing, prefer for ≥3 URLs)
- `gh search repos/issues/prs` (for GitHub discovery)
- arXiv abstract pages for papers
- Public JSON endpoints (Reddit, HN Algolia) for community sources

**Rate-limit rule (will BLOCK you if violated):**
- Never loop `ctx_search` with one query at a time. Pass an array of 5-8 queries per call.
- Never fire >9 `ctx_search` calls within 30 seconds.
- For multi-URL discovery, use `ctx_fetch_and_index(requests: [...], concurrency: 4-6)`, not sequential `webfetch` loops.

### Phase 4 — TRIANGULATE
Cross-check ≥2 independent sources per claim. Flag single-source as `confidence: low`.

### Phase 4.5 — OUTLINE REFINEMENT
Adapt the response outline as evidence emerges. Don't commit to a structure before retrieval.

### Phase 5 — SYNTHESIZE
Map each candidate to the output schema fields. Use disambiguation rules from the prompt.

### Phase 6 — CRITIQUE
Red-team: what's missing, what could be misclassified, what would an adversarial reviewer reject?

### Phase 7 — REFINE
Patch weak areas, resolve contradictions, add missing perspectives.

### Phase 8 — PACKAGE
Write the final structured output following the §4 schema (table + evidence blocks + narrative sections).

**FFS quality gate:** stop searching when you have ≥15 candidates with avg confidence ≥60/100 (quick), ≥15/70 (standard), ≥25/70 (deep), ≥30/75 (ultradeep).

---

## Cross-model consolidation pipeline (the 4 phases unique to multi-ai-task)

After all N per-model reports are written, run:

### Phase C1 — ALIGN
For each model report, extract the per-row structured data (name, category, score, evidence quote) into a normalized registry. Build an alias map for items the models named differently.

### Phase C2 — DEDUP
Merge rows that refer to the same real-world item. Build one canonical row per distinct item, preserving per-model fields:
- `category_per_model`: {model1: cat, model2: cat, ...}
- `score_per_model`: {model1: {...}, model2: {...}}
- `evidence_blocks`: [{model, quote, url, source_type, version_or_date}]

### Phase C3 — RESOLVE CONFLICTS
For each canonical row, apply the conflict resolution rules in the order defined in the main SKILL.md. Document the resolution per row in the `## 4. Unresolved Conflicts` section.

For each conflict:
1. Check if the model has a primary quote supporting its classification
2. Check the `last_verified` date — newer wins
3. Check if ≥3 SB-differentiator criteria are evidenced for `direct` (downgrade if not)
4. Check if the model is a known outlier (apply rule 5)

### Phase C4 — SCORE + SYNTHESIZE
1. Aggregate scoring matrices: for each candidate × dimension, compute median and range across N models.
2. Compute total score (sum of medians). Top 3 by total = "closest architectural matches".
3. Write the final consolidated report following the output schema (see `output-schema.md`):
   - Executive summary (cross-model consensus)
   - Dedup table (all canonical items)
   - Per-row gaps
   - Evidence blocks
   - Scoring matrix (median + range)
   - Top-N by ranking
   - Adjacent inspirations
   - Negative results
   - Open questions
   - 1-page positioning memo (deep/ultradeep only)
   - Cross-AI source map (which model found which unique item)
   - Coverage scoreboard

---

## Cardinality rules (how many models, how many candidates)

| Task complexity | Recommended N models | Target candidates | Target direct matches |
|-----------------|----------------------|--------------------|------------------------|
| Simple fact-check | 2-3 | 1-3 | n/a |
| Standard research | 4-6 | 15-30 | ≥3 strong-adjacent |
| Deep landscape scan | 6-10 | 30-100 | ≥5 direct or strong-adjacent |
| Multi-domain audit | 8-12 | 50-200 | full coverage with conflict surface |

**Rule of thumb:** N=4 is the minimum for meaningful cross-model dedup. N=6 captures most of the unique finds (diminishing returns past 6 for typical research).

---

## The "single model finds X" signal

When only one of N models surfaces a candidate, don't auto-dismiss. Instead:
- If the candidate has a primary quote and a verifiable URL → keep, mark `discovered_by: <model>`, `confidence: medium`
- If the candidate is mentioned without evidence → drop
- If 2+ models both find it but don't score it → consolidate as `adjacent`, note sparse coverage

This is how a 6-model run captured unique finds like `XFlow` (arXiv paper — only qwen found it) and `Antigravity Ultimate SDLC` (only glm found it).
