# Prompt Template — multi-ai-task

The exact prompt structure sent to every model. The user provides the task-specific content; this template handles the methodology, output schema, and citation rules.

---

## How to use

1. Take the user's task description
2. Wrap it in the sections below:
   - §1 Executive Framing — set the subject matter
   - §2 Research Questions — what to answer
   - §3 Disambiguation Rules — what to exclude
   - §4 Required Output Schema — what the model returns
   - §5 Citation Requirements — how to cite
   - §6 Search Strategy Hints — how to search
   - §7 Constraints on Response — what NOT to do
   - §8 Cross-AI Dedup Instructions — context for downstream merging
   - §9 Reference Context — any task-specific calibration data
3. Send the wrapped prompt to every model verbatim
4. Models return their own report following §4 schema
5. The consolidation skill merges N reports into one

---

## Template (copy-paste this and fill in the bracketed sections)

```markdown
You are conducting **<prior-art | landscape | comparative-analysis | fact-check | ideation> research** — not building anything. Your job is to find existing tools, frameworks, methodologies, papers, and products that overlap with or inform the architectural approach described below. Be skeptical, cite primary sources, and distinguish marketing from inspectable mechanisms.

---

## 1. Executive Framing — What <SUBJECT> Built

**<SUBJECT>** is <one-paragraph description of the system/framework/concept being researched>. Its product model is a <declarative catalog / framework / methodology> that defines:

| Level | Description | Example |
|-------|-------------|---------|
| **<Level 1>** | <desc> | <example> |
| **<Level 2>** | <desc> | <example> |
| **<Level 3>** | <desc> | <example> |
| **<Level 4>** | <desc> | <example> |

### Core differentiators (search for equivalents)

1. **<Differentiator 1>** — <one-sentence description of what makes subject unique>
2. **<Differentiator 2>** — <...>
3. **<Differentiator 3>** — <...>
4. **<Differentiator 4>** — <...>
5. **<Differentiator 5>** — <...>
6. **<Differentiator 6>** — <...>
7. **<Differentiator 7>** — <...>
8. **<Differentiator 8>** — <...>

### Execution architecture

- **<Component 1>**: <desc>
- **<Component 2>**: <desc>

### What <SUBJECT> explicitly is NOT looking to duplicate

- <exclusion 1>
- <exclusion 2>
- <exclusion 3>
- <exclusion 4>

---

## 2. Research Questions

Answer all of the following. If no match exists, say so explicitly — negative results are valuable.

### 2A. Direct prior art (highest priority)

Find systems that combine **≥3** of:
- <criterion 1>
- <criterion 2>
- <criterion 3>
- <criterion 4>
- <criterion 5>
- <criterion 6>
- <criterion 7>

### 2B. Adjacent categories (map each find to the closest bucket)

| Category | Examples to investigate (non-exhaustive) |
|----------|----------------------------------------|
| **<Bucket 1>** | <example A>, <example B>, <example C> |
| **<Bucket 2>** | ... |
| **<Bucket 3>** | ... |
| **<Bucket 4>** | ... |
| **<Bucket 5>** | ... |
| **<Bucket 6>** | ... |
| **<Bucket 7>** | ... |
| **<Bucket 8>** | ... |

### 2C. Dimension-specific probes

For each candidate, determine:

1. **Composition model** — Static graph? Dynamic replanning? Catalog of reusable units?
2. **Verification model** — End-of-pipeline test only? Per-step gates? V-model?
3. **Enforcement mechanism** — Honor system? CI? IDE hooks? Policy engine?
4. **Parallelism model** — Single agent? Fan-out workers? DAG scheduler?
5. **Evidence** — What counts as proof? Tool outputs? Artifact schemas?
6. **<Domain> fit** — <What's the relevant domain coverage>
7. **Customization** — Team overlays without forking?
8. **Maturity** — Production adoption, version, last release?

### 2D. Gap analysis vs <SUBJECT>

For each **direct** match, identify what <SUBJECT> appears to have that they lack, and what they have that <SUBJECT> lacks. Be specific.

---

## 3. Disambiguation Rules — EXCLUDE Unless Criteria Met

**Exclude** or downgrade to "tangential" unless the candidate has **<composable workflow catalog + verification loops>**:

| Pattern | Exclude unless… |
|---------|------------------|
| <pattern 1> | <criterion> |
| <pattern 2> | <criterion> |
| <pattern 3> | <criterion> |
| <pattern 4> | <criterion> |
| <pattern 5> | <criterion> |
| Academic papers | Include only if they describe **implementable** orchestration + verification — not pure methodology |

When uncertain, include with category `adjacent` and explain the gap.

---

## 4. Required Output Schema

Return results as a **markdown table** plus optional detail sections. **One row per distinct tool/framework/product/paper.**

### 4.1 Summary table (mandatory)

| Field | Required content |
|-------|------------------|
| **name** | Tool, framework, product, or paper title |
| **url** | Primary source (repo, docs, paper PDF, product page) |
| **category** | `direct` \| `adjacent` \| `tangential` \| `negative-result` |
| **composition_model** | How workflows are defined and composed (1–2 sentences) |
| **v_loop_support** | `none` \| `end-only` \| `per-phase` \| `per-step+rollup` \| `v-model-explicit` — cite mechanism |
| **enforcement_mechanism** | `honor-system` \| `prompt-only` \| `ci-gate` \| `ide-hook` \| `policy-engine` \| `mixed` |
| **se_fit** | `none` \| `partial` \| `strong` |
| **devops_fit** | `none` \| `partial` \| `strong` |
| **parent_worker_split** | `yes` \| `partial` \| `no` |
| **evidence_model** | `none` \| `informal` \| `artifact-based` \| `tiered-sufficiency` |
| **dynamic_composition** | `no` \| `replanner-only` \| `catalog-backed-audited` |
| **maturity** | `research` \| `alpha` \| `beta` \| `production` — with date/version |
| **gaps_vs_sb** | Bullet list: what they lack |
| **sb_gaps_vs_them** | Bullet list: what subject may lack |
| **confidence** | `high` \| `medium` \| `low` |
| **last_verified** | ISO date |

### 4.2 Evidence block (mandatory per row)

```
EVIDENCE — <name>
    source_type: repo | docs | paper | release-notes | issue | demo
    version_or_date: <tag, commit date, or paper year>
    quote: "<verbatim ≤50 words from primary source proving composition/gate claim>"
    url: <canonical URL or more specific deep link>
```

### 4.3 Narrative sections (mandatory)

1. **Executive summary** (≤300 words)
2. **Top 5 direct competitors** — ranked with rationale
3. **Top 5 adjacent inspirations** — what subject could borrow
4. **Negative results** — categories searched where nothing credible was found
5. **Open research questions** — what remains unclear

---

## 5. Citation Requirements

- **Primary sources only**: official repos, docs, papers, release notes, RFCs
- **No** unsourced assertions — if a blog is the only source, label `confidence: low`
- Include **version or date** for every cited artifact
- Prefer **quotes** over paraphrase for composition and enforcement claims
- For GitHub repos: cite **default branch README or docs/** path

---

## 6. Search Strategy Hints

Use these query families:
- <query family 1>
- <query family 2>
- <query family 3>
- <query family 4>
- <query family 5>
- <query family 6>
- <query family 7>
- <query family 8>
- <query family 9>
- <query family 10>

Also search: Hacker News, GitHub trending, arXiv (cs.SE, cs.AI), official docs for <relevant platforms>, and comparison posts (treat as secondary).

**Minimum coverage target:** ≥15 distinct candidates with ≥5 classified `direct` or strong `adjacent`, unless you document exhaustive negative search.

---

## 7. Constraints on Your Response

- Do **not** propose implementing <SUBJECT>.
- Do **not** conflate "has agents" with "has <subject's core differentiators>".
- Flag **likely duplicate entries** — pick canonical name, cross-ref aliases.
- Flag **deprecated/abandoned** projects with last-commit date.
- Separate **open-source** vs **commercial** vs **research prototype**.
- If you lack web access, state limitations and reason from training data with explicit `confidence: low` and `last_verified: training-cutoff`.

---

## 8. Cross-AI Dedup Instructions (for the human merging N responses)

After running this prompt on multiple AIs, merge as follows:

### 8.1 Canonical registry
1. Create a master file with columns from §4.1
2. **Normalize names:** one row per product (merge aliases in an `aliases` column)
3. **URL dedup:** same repo/domain → single row; keep the richest evidence block

### 8.2 Conflict resolution
| Conflict | Resolution rule |
|----------|-----------------|
| Different `category` | Prefer `direct` only if **≥3 subject-differentiators** are evidenced; else downgrade to `adjacent`. Tie-break: source with primary quote wins. |
| Different `maturity` | Use **newer** `last_verified` date; confirm against official release page. |
| Different `v_loop_support` | Require quote proving per-step or per-phase gates; without quote → `end-only` or `none`. |
| One AI found it, others didn't | Keep if primary source verified; mark `discovered_by: <model>`. |

### 8.3 Scoring for "closest match to <SUBJECT>"

Score each candidate 0–2 on each dimension (max 16):

| Dimension | 0 | 1 | 2 |
|-----------|---|---|---|
| Catalog of composable units | None | Informal roles | Machine-readable catalog |
| Dynamic composition | None | Replanner | Catalog-backed + audit log |
| V-loop depth | None | End tests | Per-step rollup + intent gate |
| Enforcement | Honor system | CI only | IDE hooks + delivery blockers |
| Parent/worker split | No | Partial | Explicit orchestrator/worker |
| Evidence model | None | Informal | Tiered sufficiency + staleness |
| <Domain A> + <Domain B> unified | One domain | Partial | Both in one model |
| Team customization | None | Fork required | Overlay packs |

**Sum scores** — top 3 by total = "closest architectural matches."

---

## 9. Reference Context (<SUBJECT> catalog snapshot)

Use this to calibrate search — these are **targets to find analogs for**, not items to research themselves:

**Sample <level-3> items (<CODE>-*):** <list>
**Sample <level-2> items:** <list>
**Catalog entities beyond items:** <list>
**Enforcement touchpoints:** <list>
```

---

## Proven provenance

This template was first used end-to-end on 2026-06-27 to research prior art for the Silver Bullet (SB) Agentic Process Orchestrator. The filled-in template is at:

`docs/research-260624/SB_PRIOR_ART_USER_PROMPT.md`

That file is the canonical worked example. To create a new multi-ai-task dispatch for a different subject, copy that file and modify:
- The header "RESEARCH PROMPT FOR THE AGENTS"
- The subject in §1 ("What SUBJECT Built")
- The 8 differentiators in §1
- The exclusion list in §1 ("What SUBJECT explicitly is NOT looking to duplicate")
- The 7 criteria in §2A
- The buckets and examples in §2B
- The disambiguation rules in §3
- The field list in §4.1 (if your schema differs)
- The search query families in §6
- The 8-dimension rubric in §8.3

Keep the §4 output schema, §5 citation rules, §7 constraints, and §8 cross-AI dedup instructions as-is — they generalize.
