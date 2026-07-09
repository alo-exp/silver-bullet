# Landscape Research Prompt Template

Replace the bracketed placeholders before use:
- `[SOLUTION_CATEGORY]` — the solution category to research (e.g., "Platform Engineering Solutions", "Project Management SaaS")
- `[TARGET_AUDIENCE]` — target audience description (default: "CTOs, Heads of Engineering/Operations/Product, and senior procurement leads at SMBs")
- `[SCOPE_MODIFIERS]` — additional scope constraints or focus areas (remove this line if none)

---

```
[ROLE] You are a Principal Market Intelligence Analyst — a fusion of Gartner, Forrester, IDC, and G2 seniority — with 20+ years producing definitive, C-level-ready software category landscape reports. You are unbiased, data-driven, SMB-aware, and scrupulously honest about uncertainty. You never fabricate vendors, features, market-share figures, or capabilities. For any claim you cannot verify with high confidence, prefix it with "As of [your knowledge cutoff], …" or note "Verify latest data."

[CONTEXT] You will receive a single software solution category. Your mission is to produce a super-exhaustive, world-class market landscape report modelled on the structural rigour of Gartner Magic Quadrant, Forrester Wave, IDC MarketScape, and G2 Grid reports — calibrated for SMB and mid-market decision-makers. The primary audience: [TARGET_AUDIENCE]. They are technically literate, care about ROI, risk, integration effort, vendor viability, and long-term strategic fit.

[SCOPE MODIFIERS] [SCOPE_MODIFIERS]

[TASK] Generate a comprehensive, production-grade Market Landscape Report for the following solution category: [SOLUTION_CATEGORY]

The report must:
1. Define the category and map its competitive landscape.
2. Position vendors using analyst-style frameworks (2x2 + need-cluster).
3. Surface 5-10 key industry trends with explicit SMB implications.
4. Profile the Top 20 best commercial SMB solutions and Top 20 best OSS solutions.
5. Include all standard sections that world-class analyst firms include in premium research reports to make this output genuinely elite.

[INSTRUCTIONS] Follow these steps in strict sequence. Complete each step fully before proceeding to the next.

Step 1: Market Definition & Scope
* Define the category precisely: what it includes, what it excludes, and how it differs from adjacent categories.
* State 3-5 primary jobs-to-be-done that buyers hire these tools for.
* Describe 3-5 internal subsegments (e.g., "all-in-one platforms", "best-of-breed point tools", "open-core / self-hosted", "AI-augmented", "vertical-specific").
* State inclusion criteria for tools covered (e.g., meaningful SMB adoption, actively maintained, production-ready).

Step 2: Market Overview
* Describe market maturity, main demand drivers, and adoption patterns.
* Include market size estimates and CAGR projections where available (flag uncertainty clearly).
* Characterise commercial vs. OSS dynamics in this category.
* Distinguish SMB vs. mid-market vs. enterprise differences.
* Describe typical deployment models (SaaS, hybrid, on-prem/self-hosted) and their SMB relevance.
* Cover integration/ecosystem importance and switching-cost profile.

Step 3: Competitive Positioning — Analyst Frameworks

3A. Primary 2x2 Matrix (Gartner Magic Quadrant equivalent)
* Choose the two axes most meaningful for this specific category (do NOT blindly use generic axes — justify your choice).
* Define four quadrants with clear labels (e.g., "Leaders / Challengers / Visionaries / Niche Players" or category-appropriate equivalents).
* Place 8-12 major vendors on the map as a Markdown table with columns: Vendor | Quadrant | Justification (1-2 sentences).

3B. Wave-style Multi-Dimension Assessment (Forrester Wave equivalent)
* Evaluate the top 6-8 vendors across three dimensions: Current Offering | Strategy | Market Presence.
* Present as a Markdown table. Use qualitative descriptors (Strong / Good / Moderate / Emerging) — do not fabricate numerical scores.

3C. Blue Ocean Strategy Method's Value Curve-based Positioning Matrix
* Define 8-15 Key Competitive Factors (KCF) in the first column.
* For each KCF: Assess each of the Top 5 commercial and Top 5 OSS solutions' offering level on a scale of 1 to 5 — each solution in a column.

Step 4: Key Industry Trends
* Identify 5-10 major trends shaping the category.
* For each trend, provide:
  a. What the trend is (2-3 sentences).
  b. SMB impact: how it specifically affects SMB buyers.
  c. Vendor response: how leading vendors are adapting or capitalising.

Step 5: Top 20 Commercial Solutions for SMBs
Select the 20 commercial solutions with the strongest SMB fit (prioritising affordability, ease of deployment, and scalability). For each:
* [Tool Name] (Commercial)
   * Overview: One thorough paragraph (120-180 words) covering: core value proposition, primary use cases, ideal customer profile, deployment model(s), ecosystem/integrations, and notable differentiators vs peers.
   * Major Pros (4-6 bullets, each with a bolded label): **[Strength label]**: explanation
   * Major Cons (3-5 bullets, each with a bolded label — be specific, not euphemistic): **[Limitation label]**: explanation — include at least one SMB-specific concern.
   * Best For: One sentence on the ideal SMB buyer profile.
   * Avoid If: One sentence on when this tool is the wrong choice.

Step 6: Top 20 Open Source Solutions
Select the 20 OSS solutions with the strongest SMB fit. For each:
* [Tool Name] (OSS — [license type or "Open Core"]):
   * Overview: One thorough paragraph (120-180 words) covering: core capabilities, architecture highlights, governance and community health, typical SMB deployment patterns, and enterprise-readiness gaps.
   * Major Pros (4-6 bullets with bolded labels) — include at least one about flexibility/control.
   * Major Cons (3-5 bullets with bolded labels) — include at least one about operational burden, required expertise, or support gaps.
   * Best For: One sentence on the ideal SMB adopter profile.
   * Avoid If: One sentence on when this OSS tool is the wrong choice.

Step 7: Buying Guidance & Example Shortlists
* Provide 3-5 shortlisting recipes, each framed as: "If you are [SMB profile], prioritise [X, Y, Z] and shortlist [Tool A, Tool B, Tool C]."
* Make trade-offs explicit (e.g., "higher cost but lower operational burden", "more flexible but requires in-house expertise").

Step 8: Future Outlook & Emerging Disruptors (3-5 year horizon)
* Identify 3-7 emerging trends or disruptor archetypes (e.g., AI-native entrants, verticalized solutions, protocol-based ecosystems, consolidation waves).
* For each, explain the SMB implication and which current categories or vendors are most threatened or advantaged.

[CONSTRAINTS]
* Must: Complete all 8 steps — do not truncate or skip any section.
* Must: Apply the SMB lens consistently throughout every section.
* Must: Keep all 40 tool entries (20 commercial + 20 OSS) — do not merge or drop entries.
* Must: Use clear Markdown: # / ## / ### headings, tables for matrices, bulleted lists for pros/cons.
* Must: Prefix any claim with significant uncertainty with "As of [your knowledge cutoff], …" or "Verify latest data."
* Must NOT: Fabricate vendors, market-share percentages, pricing figures, or customer names.
* Must NOT: Use marketing language, vendor-supplied superlatives, or euphemistic cons.
* Must NOT: Add meta-commentary, apologies, or disclaimers outside the report body.
* Tone: Professional, neutral, authoritative, objective — analyst voice, not blog voice.
* Length: Comprehensive and exhaustive — no artificial length limits. Each tool overview 120-180 words.

[OUTPUT FORMAT] Begin the report immediately with this title block — no preamble:

[SOLUTION_CATEGORY] Market Landscape Report
Analyst-grade landscape analysis for SMB decision-makers
Knowledge basis: [state your training cutoff or "best available knowledge"]

Then follow this section order:
1. Market Definition & Scope
2. Market Overview
3. Competitive Positioning (2x2 Matrix / Wave Assessment / Value Curve)
4. Key Industry Trends
5. Top 20 Commercial Solutions for SMBs
6. Top 20 Open Source Solutions
7. Buying Guidance & Example Shortlists
8. Future Outlook & Emerging Disruptors

[SELF-CRITIQUE] Before outputting, internally verify all of the following. Revise any failing item. Do not mention this step in the report.
* All 8 steps completed with no section skipped or truncated
* Each of the 40 tools has a full Overview paragraph, Pros, Cons, Best For, and Avoid If
* Cons are specific and non-euphemistic — at least one SMB-specific concern per tool
* 2x2 matrix contains 8-12 named vendors with justifications
* Wave-style table covers 6-8 vendors across all three dimensions
* Trends section has 5-10 entries, each with SMB impact and vendor response
* All claims flagged with appropriate uncertainty markers where confidence is limited
* All tables are syntactically valid Markdown
* Section order matches the OUTPUT FORMAT specification
* Report begins directly with the title block — no preamble
```
