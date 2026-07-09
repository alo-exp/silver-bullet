# Consolidation Guide — Landscape Researcher

This guide defines the structure, synthesis rules, and quality criteria for producing a **Market Landscape Report** from raw multi-AI responses. The consolidator skill reads this guide and follows it as the sole structural authority.

---

## Input

- A raw AI responses archive (produced by the orchestrator skill) containing 3-7 AI platform analyses of a solution category
- Each response addresses market positioning, commercial and OSS solutions, trends, buying guidance, and future outlook
- An optional domain knowledge file (`domains/{domain}.md`) providing prior context on archetypes, terminology, and evaluation criteria

---

## Output

**Primary report:**
- **Filename:** `{Solution Category} - Market Landscape Report.md`
- **Location:** `reports/{task-name}/`

**Required side-car — `chart-data.json`:**
- **Filename:** `chart-data.json`
- **Location:** `reports/{task-name}/` (same directory as the Markdown report)

`preview.html` fetches this file at load time to populate all charts (MultAI upstream pattern).
**SB adaptation:** use inline JSON in `report.html` via `generate_report_spa.py` — no `launch_report.py` or HTTP server.

### `chart-data.json` schema

```json
{
  "anchors": {
    "mq":   ["3A", "<H3 keyword that identifies the 2×2 section>"],
    "wave": ["3B", "<H3 keyword that identifies the Wave section>"],
    "vc":   ["3C", "<H3 keyword that identifies the Value Curve section>"]
  },
  "titles": {
    "mq":   "3A-1 · <Domain> Positioning Matrix",
    "mq_x": "← Low <X concept>         High <X concept> →",
    "mq_y": "← Low <Y concept>         High <Y concept> →",
    "gmq":  "3A-2 · Magic Quadrant — <Domain>",
    "wave": "3B · Wave-Style Assessment — <Domain>",
    "vc":   "3C · Blue Ocean Value Curve — <Domain>"
  },
  "mq_data": [
    { "label": "VendorName", "x": 7.5, "y": 7.5, "q": "QuadrantName" }
  ],
  "mq_colors": {
    "QuadrantName1": "#4f46e5",
    "QuadrantName2": "#059669",
    "QuadrantName3": "#d97706",
    "QuadrantName4": "#94a3b8"
  },
  "gmq_data": [
    { "label": "VendorName", "x": 8.0, "y": 8.0, "q": "Leaders" }
  ],
  "gmq_colors": {
    "Leaders": "#4f46e5", "Challengers": "#7c3aed",
    "Visionaries": "#d97706", "Niche Players": "#94a3b8"
  },
  "wave_data": [
    { "label": "VendorName", "offering": 3.5, "strategy": 3.5, "presence": 3 }
  ],
  "vc_kcfs": ["KCF1", "KCF2"],
  "vc_commercial": [
    { "label": "VendorName", "data": [1,2,3,4,5], "color": "#4f46e5" }
  ],
  "vc_oss": [
    { "label": "VendorName", "data": [1,2,3,4,5], "color": "#22d3ee" }
  ],
  "link_pairs": [
    ["VendorName", "https://vendor.com"]
  ]
}
```

**Population rules:**
- `anchors`: Include a substring that matches the exact H3 heading used in the report for each chart section (e.g. `"Governance Matrix"` if the H3 reads `### Governance × Coordination Matrix`)
- `mq_data` / `gmq_data`: x/y scores on a 1–10 scale; `q` must match a key in the corresponding `_colors` map
- `wave_data`: `offering` / `strategy` on a 1–4 scale; `presence` is 1–4 (controls bubble size)
- `vc_kcfs`: list of Key Competitive Factors in table-stakes → differentiating order
- `vc_commercial` / `vc_oss`: `data` array length must equal `vc_kcfs` length; scores 1–5
- `link_pairs`: vendor names listed longest-first to prevent partial over-matching

The report must begin with this exact title block (no preamble):

```
{Solution Category} Market Landscape Report
Analyst-grade landscape analysis for SMB decision-makers
Knowledge basis: Synthesised from multiple AI platform responses ({platform list}) + [any web-grounded sources if present]
[Report date]
```

---

## Output Structure — 9 Sections

### Section 1: Market Definition & Scope
- **Category definition** — what the category includes, excludes, and how it differs from adjacent categories
- **Primary jobs-to-be-done** (3-5) — consensus-first; include any unique JTBD from a single strong source
- **Internal subsegments** (3-5) — e.g., all-in-one platforms, best-of-breed point tools, open-core/self-hosted, AI-augmented, vertical-specific
- **Inclusion criteria** — what qualified a tool for coverage in this report

### Section 2: Market Overview
- **Market maturity and demand drivers** — where the category sits on the hype/adoption curve, primary growth forces
- **Market size and growth** — include CAGR and absolute size estimates from any source; always prefix with confidence qualifier ("web-verified", "As of [cutoff]", or "Verify latest data")
- **Adoption statistics** — org adoption rates, team formation data, ROI/failure rates if available
- **Commercial vs. OSS dynamics** — open-core tension, build-vs-buy economics
- **SMB vs. mid-market vs. enterprise segmentation** — how needs and constraints differ
- **Deployment models and SMB relevance** — SaaS, hybrid, self-hosted; switching costs
- **Integration and ecosystem importance** — integration depth as an evaluation criterion

### Section 3: Competitive Positioning — Analyst Frameworks
- **3A. Primary 2×2 Matrix** — axes chosen for this specific category (not generic); 8-12 vendors; Markdown table: Vendor | Quadrant | Justification
- **3B. Wave-Style Multi-Dimension Assessment** — top 6-8 vendors; dimensions: Current Offering | Strategy | Market Presence; qualitative descriptors (Strong / Good / Moderate / Emerging)
- **3C. Value Curve Positioning Matrix** — 8-15 Key Competitive Factors; top 5 commercial + top 5 OSS; scale 1-5 per factor; rendered as Markdown table

### Section 4: Key Industry Trends
- 5-10 macro and micro trends
- For each trend: (a) what it is (2-3 sentences), (b) SMB impact, (c) vendor response
- Prioritise trends that appear in 3+ sources; note if a trend is from a single source

### Section 5: Top 20 Commercial Solutions for SMBs
For each solution (20 total):
- **Overview** — 120-180 word paragraph: core value prop, primary use cases, ideal customer profile, deployment models, ecosystem/integrations, key differentiators
- **Major Pros** (4-6 bullets with bolded labels) — specific, evidence-backed
- **Major Cons** (3-5 bullets with bolded labels) — specific, non-euphemistic; include at least one SMB-specific concern
- **Best For** — one sentence on ideal SMB buyer profile
- **Avoid If** — one sentence on when this tool is the wrong choice

Selection criteria: strongest SMB fit; prioritise affordability, ease of deployment, scalability; actively maintained; production-ready.

### Section 6: Top 20 OSS Solutions
For each solution (20 total), same format as Section 5 plus:
- License type in heading (e.g., "Apache 2.0", "Open Core", "BSL")
- Community health signals in Overview (GitHub stars, commit frequency, CNCF status if applicable)
- At least one Pro about flexibility/control
- At least one Con about operational burden, required expertise, or support gaps

### Section 7: Buying Guidance & Shortlist Profiles
- 3-5 shortlisting recipes: "If you are [SMB profile], prioritise [criteria] and shortlist [Tool A, Tool B, Tool C]"
- Make trade-offs explicit (cost vs. operational burden, flexibility vs. expertise required)
- Cover at least: (a) smallest/leanest team profile, (b) mid-size team with dedicated DevOps, (c) regulated/compliance-heavy SMB, (d) open-source-first team

### Section 8: Future Outlook & Emerging Disruptors
- 3-7 emerging trends or disruptor archetypes on a 3-5 year horizon
- For each: what it is, SMB implication, which current vendors are most threatened or advantaged
- Include AI-native entrants, consolidation waves, and protocol/standard shifts if present in sources

### Section 9: Source Reliability Assessment
Always the final section. Format as a Markdown table:

| Source | Response Size | Weight Applied | Assessment |
|--------|--------------|----------------|------------|
| [Platform] | [N chars] | **[Heavy—Primary / Good—Secondary / Moderate—Supplementary / EXCLUDED]** | [2-3 sentence assessment: depth, citation quality, unique contributions, any caveats] |

Include cross-source consensus patterns and notable divergences after the table.

---

## Synthesis Rules

1. **Consensus-first**: Lead each point with what multiple sources agree on. Flag single-source claims.
2. **Union, not intersection**: Include any vendor mentioned by 2+ sources, or by 1 highly reliable source with specific, detailed coverage. Do not restrict to only universally mentioned vendors.
3. **No fabrication**: Every vendor, statistic, and capability must trace to at least one source. If uncertain, flag it.
4. **Preserve specificity**: Keep vendor-specific technical detail — do not generalise away meaningful distinctions.
5. **Flag uncertainty**: Market size, CAGR, and adoption figures must carry confidence qualifiers. Web-verified data (e.g., from deep research sessions) should be noted as such.
6. **Cross-reference disagreements**: Where sources disagree on vendor positioning or market data, present both views and note the discrepancy.
7. **Source attribution**: Attribute notable or unique data points to their source in parentheses where it aids credibility.
8. **Tone**: Analyst voice throughout — authoritative, neutral, data-informed. No marketing language, superlatives, or euphemistic cons.

---

## Quality Checklist

Before saving the report, verify all of the following:

- [ ] All 9 sections present and complete
- [ ] Section order matches the specification above
- [ ] Report begins with the exact title block format
- [ ] At least 20 commercial solutions covered in Section 5
- [ ] At least 20 OSS solutions covered in Section 6
- [ ] Each solution entry has: Overview, Pros (4-6), Cons (3-5), Best For, Avoid If
- [ ] At least 5 industry trends in Section 4, each with SMB impact and vendor response
- [ ] 2×2 matrix contains 8-12 vendors with justifications
- [ ] Value Curve table covers ≥5 commercial + ≥5 OSS across ≥8 KCFs
- [ ] Source Reliability Assessment covers all platforms that responded
- [ ] No hallucinated vendors (every vendor traces to at least one source)
- [ ] All market size/CAGR figures have confidence qualifiers
- [ ] Cons are specific and non-euphemistic — no "may require configuration" type vagueness
- [ ] All Markdown tables are syntactically valid

---

## Domain Knowledge Integration

If `domains/{domain}.md` is provided:
- Use its **archetypes** to classify vendors in the 2×2 and Wave sections
- Use its **terminology** for consistent capability labelling
- Use its **evaluation criteria weights** to prioritise which factors matter most for this domain's buyers
- Use its **known vendor categories** to sanity-check that major known solutions are represented
- Do **not** fabricate domain data — use only what is in the file

---

## Handling Weak or Excluded Sources

- If a source responded with only prompt-echo, failed, or produced fewer than 1,000 chars of unique content: mark it **EXCLUDED** in the Source Reliability table and do not weight its content
- If a source produced partial content (e.g., only covered 3 of 8 sections): mark it **Partial** and weight proportionally
- Gemini Deep Research responses (when available) carry the highest citation quality — mark as **Heavy — Primary** and note the number of websites researched
