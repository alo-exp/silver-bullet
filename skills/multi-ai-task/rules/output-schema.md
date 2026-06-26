# Output Schema — multi-ai-task consolidated report

The exact structure and required fields for the consolidated.md file. Every section is mandatory unless marked optional.

---

## File header

```markdown
# <Task Title> — Cross-Model Consolidated Report

**Date:** YYYY-MM-DD
**Mode:** quick | standard | deep | ultradeep
**Models:** N total
**Coverage:** M unique items / P raw mentions / Q scoring matrices available
**Source reports:**
- `<model-slug>.md` — <model-id> (size in KB / line count)
- ...

**Dispatch note:** brief note on the dispatch mechanism used (CLI subprocess, task tool, SDK), and any quirks (e.g., harness rejected custom subagent types; fall back to `--model` flag).
```

---

## §1. Executive Summary (≤300 words)

Terse landscape overview. Include:

- 1-2 sentence headline (e.g., "No existing tool combines X")
- Cross-model consensus
- Closest direct matches (if any)
- Biggest market gaps
- The 3-5 most important findings to take away

**Do NOT** repeat data here. Point at the table for evidence.

---

## §2. Dedup Table (mandatory, one row per distinct item)

```markdown
| # | Canonical | Mentions | Cats across agents | Primary URL | Top Finding |
|---|-----------|---------:|--------------------|-------------|-------------|
| 1 | **LangGraph** | 6 | adjacent, `direct*`, tangential | langchain-ai/langgraph | Most-discussed; mimo classifies as `direct` (outlier) |
| 2 | **CrewAI** | 6 | adjacent, `direct*`, tangential | crewAIInc/crewAI | mimo only `direct` agent |
| ... |
```

**Field rules:**
- `Mentions`: integer count of how many models mentioned this item
- `Cats across agents`: comma-separated distinct category values across models, with conflict markers as code spans: `` `direct*` `` means at least one model disagreed
- `Primary URL`: the most-cited URL (typically the official repo/docs)
- `Top Finding`: one-sentence summary of the most-cited finding; note outliers in parens

**Conflict marker legend (place at top of section):**

> **Conflict marker:** `` `direct*` `` / `` `negative-result*` `` = category conflict: at least one agent disagreed on the classification. Resolution rules: `direct` only if ≥3 subject-differentiators are evidenced with primary quote; tie-break: source with primary quote wins.

**Use code spans, not bold+asterisk, for the conflict marker.** `**direct***` is fragile markdown that breaks in WYSIWYG viewers; `` `direct*` `` is robust.

---

## §3. Per-Row Gaps (compact)

For each item in the dedup table, include a compact bullet:

```markdown
- **<Canonical>**: gaps_vs_subject = ... ; subject_gaps_vs_them = ...
```

Be specific. Not "less mature" but "lacks V-model rollup; has BPMN catalog". Not "smaller community" but "1k stars vs SB's 0".

---

## §4. Evidence Blocks (mandatory per row)

```markdown
### EVIDENCE — <name>
- source_type: repo | docs | paper | release-notes | issue | demo
- version_or_date: <tag, commit date, or paper year>
- quote: "<verbatim ≤50 words from primary source proving the classification claim>"
- url: <canonical URL or specific deep link>
```

If no qualifying quote can be found, set `confidence: low` and explain what was inferred.

**For consolidated evidence across multiple models**, you may include multiple evidence blocks under the same canonical name — one per model that contributed a distinct quote:

```markdown
### EVIDENCE — BMAD (deepseek)
- source_type: repo, version_or_date: v6, 2025
- quote: "BMad Method (BMM) ... 34+ workflows ... Specialized Agents — 12+ domain experts (PM, Architect, Developer, UX)"
- url: https://github.com/bmad-code-org/BMAD-METHOD

### EVIDENCE — BMAD (minimax)
- source_type: docs, version_or_date: 2026
- quote: "BMAD's TEA module provides risk-based test scoring with per-step validation gates"
- url: https://docs.bmad-method.org/tea
```

---

## §5. Scoring Matrix (mandatory, deep/ultradeep only)

8 dimensions × N candidates. Each cell = median across models. Last column = range.

```markdown
| candidate | cat | dyn | v | e | pw | ev | sd | cu | TOTAL (median) | Range |
|-----------|:---:|:---:|:-:|:-:|:--:|:--:|:--:|:--:|:--:|:--:|
| **Silver Bullet (reference)** | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | **16** | (all) |
| **Camunda 8** | 2 | 1 | 1 | 1 | 1 | 1 | 0 | 1 | **7** | 4–8 |
| **Temporal** | 0 | 0 | 1 | 1 | 2 | 1 | 0 | 0 | **5** | 3–5 |
| ... | | | | | | | | | | | |

**Column semantics:**
- `cat` = catalog of composable units (0=none, 1=informal roles, 2=machine-readable catalog)
- `dyn` = dynamic composition (0=none, 1=replanner, 2=catalog-backed + audit log)
- `v` = V-loop depth (0=none, 1=end tests, 2=per-step rollup + intent gate)
- `e` = enforcement (0=honor system, 1=CI only, 2=IDE hooks + delivery blockers)
- `pw` = parent/worker split (0=no, 1=partial, 2=explicit orchestrator/worker)
- `ev` = evidence model (0=none, 1=informal, 2=tiered sufficiency + staleness)
- `sd` = SE+DevOps unified (0=one domain, 1=partial, 2=both in one model)
- `cu` = team customization (0=none, 1=fork required, 2=overlay packs)
```

**Top 3 by total** = "closest architectural matches to subject."

---

## §6. Top 5 Direct Competitors (ranked, with rationale)

For each:

```markdown
| Rank | Candidate | Rationale |
|------|-----------|-----------|
| **1** | **<Name>** | <one-sentence rationale: what's the closest match, what's missing vs subject> |
| ... |
```

If no direct competitors exist (downgraded to adjacent), document that explicitly with rationale: "Across all N models, zero products earned `direct` under the conflict-resolution rules."

---

## §7. Top 5 Adjacent Inspirations (what subject could borrow)

```markdown
| # | Source | What to borrow |
|---|--------|----------------|
| **1** | **<Name>** | <one specific pattern: durable execution, hook system, policy DSL, scaffolder model> |
| ... |
```

---

## §8. Negative Results (categories with no credible finds)

```markdown
- **<Category name>** — no product found with <required capability>
- **<Another category>** — <details>
```

Negative results are valuable. Document them.

---

## §9. Open Research Questions (carry-forward)

```markdown
1. <question 1 — what remains unclear, what follow-up needed>
2. <question 2>
...
```

---

## §10. 1-Page Positioning Memo (deep/ultradeep only, ≤400 words)

Required structure:

1. **Where subject sits** (1 paragraph): the unique slot subject occupies vs the landscape
2. **Three concentric circles of competition** (1 paragraph each):
   - Inner ring: execution substrates
   - Middle ring: agentic SDLC methodologies
   - Outer ring: enforcement / IDE hosts
3. **Three things only subject has** (1 paragraph): the consensus-different differentiators
4. **Three things subject lacks** (1 paragraph): honest gaps
5. **Top 5 threats** (ranked by probability × impact)
6. **Top 4 opportunities** (ranked by moat strength)
7. **Strategic posture** (1 paragraph): what to compete on, what to partner with, what to absorb

---

## Appendix A — Cross-AI Source Map

For each unique item, which model(s) found it:

```markdown
| Finding | Discovered by | Verified by | Notes |
|---------|---------------|-------------|-------|
| Antigravity Ultimate SDLC | **glm-5.2** | — | unique find; needs deeper validation |
| XFlow (arXiv) | **qwen3.7-max** | — | unique find; arXiv ID format suggests 2026-06 |
| ... |
```

---

## Appendix B — Coverage Scoreboard

```markdown
| Bucket | Found | Models contributing | Gap |
|--------|-------|---------------------|-----|
| Agentic SDLC frameworks | 7 (BMAD, GSD, ...) | all 6 | Loki Mode low-coverage |
| Multi-agent orchestration | 7 | all 6 | none |
| ... |
| **Total unique products** | **36** | — | target ≥15: MET (2.4×) |
| **Direct or strong-adjacent** | **0 direct, 6 strong-adjacent** | all 6 | target ≥5: MET (adjacent count) |
```

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

See the proven provenance file `docs/research-260624/SB_CONSOLIDATED_PRIOR_ART_REPORT.md` for a fully-compliant example.
