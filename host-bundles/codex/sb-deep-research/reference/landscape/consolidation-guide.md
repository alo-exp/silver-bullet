# Consolidation Guide — Landscape Researcher

This guide defines the structure, synthesis rules, and quality criteria for producing a **Market Landscape Report** from raw multi-AI responses. The consolidator skill reads this guide and follows it as the sole structural authority.

When a **category market contract** (`category_pack_id` in `need_profile.json`) is active, pack rules override generic "Top 20" counts and ban wrong-category padding.

---

## Input

- Raw AI responses archive (3–7 platform analyses)
- `need_profile.json` with `category_pack_id` (required for solution-landscape)
- Resolved category pack from `reference/landscape/category-packs/{id}.json`
- Optional domain knowledge file (`domains/{domain}.md`)

Inject the pack block into consolidator context via `category_pack.pack_prompt_block()`.

---

## Output

**Primary report:**
- **Filename:** `{Solution Category} - Market Landscape Report.md`
- **Location:** `reports/{task-name}/`

**Required side-car — `chart-data.json`:**
- **Location:** same directory as the Markdown report
- **SB adaptation:** inline JSON in `report.html` via `generate_report_spa.py`

### `chart-data.json` schema

```json
{
  "anchors": {
    "mq":   ["3A", "<H3 keyword>"],
    "wave": ["3B", "<H3 keyword>"],
    "vc":   ["3C", "<H3 keyword>"]
  },
  "titles": { "...": "..." },
  "mq_data": [{ "label": "VendorName", "x": 7.5, "y": 7.5, "q": "QuadrantName" }],
  "wave_data": [{ "label": "VendorName", "offering": 3.5, "strategy": 3.5, "presence": 3 }],
  "vc_kcfs": ["KCF1"],
  "vc_commercial": [{ "label": "VendorName", "data": [1,2,3,4,5], "color": "#4f46e5" }],
  "vc_oss": [{ "label": "VendorName", "data": [1,2,3,4,5], "color": "#22d3ee" }],
  "link_pairs": [["VendorName", "https://vendor.com"]]
}
```

**Chart population rules (pack-aware):**
- `mq_data`, `wave_data`, `vc_*`: **in-scope core only** — never coding agents, host runtimes, excluded, or sunset products
- Vendor count bounded by pack `min_core_count`–`max_core_count` (total core, not 20+20)
- `vc_kcfs`: prefer pack `feature_axes` labels
- `link_pairs`: longest names first

Title block (no preamble):

```
{Solution Category} Market Landscape Report
Analyst-grade landscape analysis for SMB decision-makers
Knowledge basis: Synthesised from multiple AI platform responses ({platform list})
[Report date]
```

---

## Output Structure — 11 Sections

### Section 1: Market Definition & Scope
- Pack-aligned category definition with explicit exclusions (coding agents, host runtimes, etc.)
- Primary jobs-to-be-done (from pack + consensus)
- Internal subsegments (3–5)
- Inclusion criteria (≥N of M scorecard) and exclusion classes

### Section 2: Market Overview
- Market maturity, demand drivers, size/CAGR (with confidence qualifiers)
- Commercial vs. OSS dynamics; SMB vs. enterprise segmentation
- Deployment models and integration importance

### Section 3: Competitive Positioning — Analyst Frameworks (**core only**)
- **3A.** 2×2 matrix — 8–12 **core** vendors
- **3B.** Wave assessment — 6–8 **core** vendors
- **3C.** Value curve — pack feature_axes; top 5 commercial + top 5 OSS **core**

### Section 4: Key Industry Trends
- 5–10 trends with SMB impact and vendor response

### Section 5: In-Scope Core Solutions — Commercial
For each **core** commercial solution (not adjacent, not excluded):
- **Fitness scorecard** — criterion id | pass/fail | evidence
- Overview (120–180 words), Pros (4–6), Cons (3–5), Best For, Avoid If

Count: share of pack `min_core_count`–`max_core_count` total with Section 6.

### Section 6: In-Scope Core Solutions — Open Source
Same as Section 5 plus license type and community health signals.

### Section 7: Adjacent Markets
- Only when `allow_adjacent_section` is true
- Pack `adjacent_seeds` + other adjacent-class products
- One paragraph + "why adjacent, not core" — **never** on charts or core lists

### Section 8: Explicitly Excluded
- Table: Product | Exclusion class | Rationale
- Hard exclusions, sunset registry, failed scorecard candidates
- Coverage gaps for must-research seeds not found in sources

### Section 9: Buying Guidance & Shortlist Profiles
- 3–5 recipes with explicit trade-offs

### Section 10: Future Outlook & Emerging Disruptors
- 3–7 disruptor archetypes; SMB implications

### Section 11: Source Reliability Assessment
Final section — platform weight table + consensus/divergence notes.

---

## Synthesis Rules

1. **Pack-first**: Classify every candidate core | adjacent | excluded | sunset before writing Sections 3–6.
2. **Consensus-first**: Lead with multi-source agreement; flag single-source claims.
3. **No padding**: Do not invent vendors or pad to 20 commercial + 20 OSS. Cover verified in-scope solutions only.
4. **No fabrication**: Every vendor traces to a source; uncertainty flagged.
5. **Fitness scorecard required**: Each core entry documents inclusion criterion pass/fail (feeds downstream classifier).
6. **Naming hygiene**: Product-level names; apply pack `product_aliases` and `parent_child_dedupe`.
7. **Chart/core alignment**: Sections 3, 5, 6, and `chart-data.json` must list the **same core set**.
8. **Tone**: Analyst voice — neutral, specific cons, no marketing superlatives.

---

## Quality Checklist

Before saving:

- [ ] Pack loaded; `category_pack_id` matches report category
- [ ] Sections 1–11 present in order
- [ ] Market definition explicitly excludes coding agents / host runtimes (when APO pack)
- [ ] Core count within pack `min_core_count`–`max_core_count` (commercial + OSS combined)
- [ ] No hard exclusion or sunset slug in Sections 3, 5, 6, or chart-data
- [ ] No parent+child dual-list (Cognition+Devin, LangChain+LangGraph)
- [ ] Every core entry has fitness scorecard
- [ ] Must-research seeds covered or listed as gaps in Section 8
- [ ] Adjacent section present when enabled; excluded section present when OOS names researched
- [ ] Chart vendor set ≡ core vendor set
- [ ] Source Reliability Assessment covers all platforms

---

## Domain Knowledge Integration

If `domains/{domain}.md` is provided:
- Use archetypes for 2×2 / Wave classification
- Use terminology for KCF labels (supplement pack `feature_axes`)
- Do not fabricate domain data

---

## Handling Weak or Excluded Sources

- Prompt-echo / failed / <1,000 chars unique → **EXCLUDED** in Source Reliability table
- Partial responses → **Partial** weight
- Web-grounded / deep-research sessions → note citation quality

---

## Pack injection at retrieve time

Multi-AI retrieve wrappers must substitute:
- `[CATEGORY_PACK]` → `pack_prompt_block(pack)`
- `[SOLUTION_CATEGORY]` → `pack.display_name`
- Remove any legacy "40 tool entries" instructions from phase prompts
