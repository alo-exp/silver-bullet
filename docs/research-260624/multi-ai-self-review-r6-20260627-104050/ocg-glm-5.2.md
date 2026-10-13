I have read all 8 files. Let me verify a few cross-cutting issues before writingthe review.
I have enough context. Note: there are prior reviews (`critical-review-r3.md`, `critical-review-r4.md`) in the skill directory — this is round 5+. I verified the previously-flagged `run-manifest.json` schema issue has been fixed in the current `output-schema.md` (lines 217-235 now include `schema_auto_injected`, `aliases`, `consolidation`, `phases_completed`). I will not repeat fixed findings.

---

# Critical Self-Review of `multi-ai-task` Skill (Round 5)

**Reviewer note:** This is the **5th+ critical review** of this skill — `critical-review-r3.md` and `critical-review-r4.md` already exist in the skill directory, plus a "round-2 self-review (v2.1.0)" path is referenced in `SKILL.md:247`. I read all 8 files verbatim. Several findings from prior rounds have been fixed (notably the `run-manifest.json` canonical schema now includes `phases_completed`, `consolidation`, `schema_auto_injected`, and `aliases` — verifying `output-schema.md:235,224,218,230-234`). I will not re-flag any fixed issue; below are **new or persisting** findings only.

---

## §1. Critical Assessment — file by file

### 1. `SKILL.md` (entry point)

- **What works well:** The WHEN/USE-WHEN/usage-nexus tables are well-scoped; `argument-hint` accurately enumerates the 6 supported flags; the provenance section anchors the skill in real evidence rather than marketing.
- **Missing or wrong:**
  - **Version lies out of band, presumably hardcoded.** Line 6 declares `version: 2.1.0`; the user-facing prompt task description for THIS review says the skill is "at v2.0.0." Either the task prompt is stale or `silver-bullet` versioning is not flowing to invokers. This isn't a SKILL.md bug per se, but the frontmatter version should be the single source of truth the user can query — and there is no `CHANGELOG.md` in the skill to track what 2.0.0→2.1.0 changed.
  - **`score-aggregate.md` is acknowledged-but-orphaned.** Line 227 admits it's "not in the contract" yet kept as a guidance table entry. Either remove the row or write the section into `output-schema.md`. Leaving `score-aggregate.md` as a "known ghost" invites every future reviewer to re-flag it (I just did).
  - **"Task examples (NOT part of the skill — for reference only)"** (line 203). This is documentation sophistry — the `rules/examples/` directory ships with the skill, is referenced 3× from SKILL.md, and the recipes are how users actually invoke it. Either drop the disclaimer and own them as first-class skill content, or move them to `docs/`.
- **Unclear or ambiguous:**
  - Line 29: "Replace domain expertise (the models do the actual work; the skill just orchestrates and consolidates)." Is orchestrating/consolidating not domain expertise? This sentence reads like a half-apology; what is the actual boundary being asserted?
  - Line 247: the "round-2 self-review (v2.1.0)" path is referenced but not the r3/r4 reviews sitting in the same parent dir. Why expose r2 but not r3/r4? Either the provenance is incomplete or r3/r4 are not authoritative.

### 2. `rules/methodology.md` (4-phase pipeline)

- **What works well:** The "extractor model" clarification (line 104) preempts the "ask the failing model again" anti-pattern, which is a real-world mistake agents make. The deterministic-vs-LLM-assisted split is stated unambiguously.
- **Missing or wrong:**
  - **Phase numbering drift.** This file calls them "Phase 1/2/3/4" (lines 7/23/108/120). `consolidation-rules.md` invents "Phase 2 — ALIGN", "Phase 3.5 — RESOLVE CONFLICTS", "Phase 3.6 — SCORE + SYNTHESIZE" (consolidation-rules.md:26,136,266). `SKILL.md` line 77 calls them Phase 1/2/3/4. `output-schema.md:235` says `phases_completed: [1,2,3,4]`. **Three files use integers, one file uses fractional phases.** A `run-manifest.json` written per consolidation-rules.md would never match the integer enum.
  - **`--mode quick` Phase 3 contradiction.** `SKILL.md:79` says quick mode does "Dedup only, no conflict resolution". `output-schema.md:119` makes `§4. Conflicts & Resolutions` "(mandatory, both modes)". So quick mode produces a `consolidated.md` without §4 but `output-schema.md` calls §4 mandatory. Need an explicit override: "mandatory in `standard`/`thorough`; skipped in `quick`".
  - **Free-form fuzzy-match threshold is hardcoded at "≥80% similar"** (consolidation-rules.md:131, repeated as "first 5 words of each paragraph" in SKILL.md:154). For non-English or short-title tasks this is catastrophic. No schema field to override; no fallback to substring containment.
- **Unclear or ambiguous:**
  - Line 15-16: "the JSON schema verbatim, plus a one-line instruction". If the schema JSON is large (the prior-art example spec is ~1.5 KB), auto-injecting it into every prompt changes every model's effective context budget — but no note warns that auto-injection can push a small-context model over a context window. Is there a contraindication?

### 3. `rules/dispatch-mechanics.md` (4 dispatch mechanisms)

- **What works well:** The macOS `gtimeout`/`coreutils` branch is realistic and tested-flavored; the cross-link to issue numbers (#6651, #11215, etc.) shows real research, not speculation. The `permission.task` allow-list guidance (line 30) is genuinely useful.
- **Missing or wrong:**
  - **`--models` discovery is documented twice with different wording.** SKILL.md:73 says "queries the local OpenCode config (`~/.config/opencode/opencode.json` + `.jsonc`)". This file (line 12) says "If your harness supports custom subagent types" and shows the JSON shape. The two never reconcile: which file actually gets parsed, by what, when? There is no implementation pseudocode (in contrast to the extensive pseudocode in methodology.md for extraction).
  - **Mechanism 2 timeout guidance contradicts itself.** Line 40 says `TIMEOUT=600` inline ("10min for research, 5min for review"). Line 69 reiterates `600s = 10 min for research, 300s = 5 min for quick review`. But the prior-art run (`methodology.md` claim "2-3 min/model") used the default 600, meaning almost all dispatches were 2-3× under budget. There's no guidance on *right-sizing* the timeout — only the table of presets.
  - **MCP port-collision guidance is hand-wavy.** Line 113: "The proven fix is to either (a) configure MCPs that support multiplexing, or (b) dispatch to a single model at a time AND restart the MCP between dispatches." Option (b) restarts MCP between every dispatch — meaning N restarts. No code, no timing estimate, no MCP names that actually multiplex. The line is a TODO in prose.
  - **Auth table is OpenCode-centric.** Lines 148-156 list OpenCode-Go, Anthropic, OpenAI, Google, Ollama. Mechanism 4 (line 89+) is "Direct HTTP to provider API" — but the auth table doesn't mention providers like OpenRouter, Together AI, Mistral, Fireworks that Mechanism 4 users would hit. The table only addresses one of four mechanisms.
- **Unclear or ambiguous:**
  - Line 28: "Dynamic per-call model selection is a 6-time-requested feature ... not yet released." Against which OpenCode version/commit is this dated 2026-06? If the harness the user invokes from is a future build, this whole section may be wrong but no test/check is offered.

### 4. `rules/consolidation-rules.md` (dedup/conflict/scoring)

- **What works well:** The named rule library (`most-severe`, `majority-with-uncertain`, `lowest-of-majors`, `longest-with-quote`, `concatenate-all`, `all-collected`, `union-dedup`, `merge-exact`) is genuinely formalized — each has purpose/input/algorithm/edge-case. The `most-severe` `allow_downgrade` toggle (lines 171-172) is the kind of sharp edge other skills would have missed.
- **Missing or wrong:**
  - **`prefer-with-evidence-then-newer-then-strict` is missing from the named rule library despite being the default `string` rule (line 146).** It's described in prose (lines 155-164), but no `#### prefer-with-evidence-then-newer-then-strict` block exists in the library section. Every other rule has that block, so this one looks accidentally dropped — and SKILL.md:144 explicitly says it's one of the "named rules". This is the single biggest documentation inconsistency.
  - **`newer` and `most-cited` are referenced in the default table (lines 149-150) but absent from the library.** Naming convention: every default rule in the table at lines 144-153 should have a `####` block. `newer`, `most-cited` don't. Same gap for `prefer-with-evidence-then-newer-then-strict`.
  - **Phase 3.6 "TOTAL (median)"** (line 273) is computed but there's **no rule** for what to do when different models return different *numbers* of dimensions. If m1 scores 8/8 dimensions and m2 scores 4/8, is "TOTAL" the median of 8 cells (with 4 missing) or 4? Spec silent.
  - **`severity_order` convention is stated twice with contradicting terseness.** Line 169-172 says "most-severe first (index 0)". code-review.md:73 empirically confirms `["blocker","major","minor","nit"]`. fact-check.md reads differently. Fine — but the same invariant is now asserted in 3 places; if a 4th reader misses any one, the algorithm unrolls backwards (using `max`).
- **Unclear or ambiguous:**
  - Lines 280-281: Final synthesis "structure depends on whether the user passed a schema. With a schema, follow the schema's natural output format." What is the "natural output format" of a schema with `type: "table"` and 16 columns and 4 conflict rules? Is it always a single flat table? Grouped by category? This is the only vague sentence in an otherwise tight file.

### 5. `rules/output-schema.md` (output structure)

- **What works well:** Field semantics (lines 239-254) are now complete and match the `<out_dir>` tree (SKILL.md:162-172). The "Markdown formatting rules (CRITICAL for WYSIWYG viewer compatibility)" section (lines 258-269) is concrete and recognizes a real GFM-parser class of bug.
- **Missing or wrong:**
  - **`evidence-ledger.md` and `verification.md` have NO structural definition**, even though SKILL.md:170-171 emits them in `thorough` mode. This file claims to be the canonical output-structure document and is silent on two of its own outputs. Worst gap in the file.
  - **§4 example uses phantom rule numbers.** Lines 122-124:
    ```
    | LangGraph | category | ... | rule 4 (outlier downgrade) | `adjacent` | high |
    | BMAD | maturity | deepseek=`negative-result`, 2 others=`adjacent` | rule 3 (strict) | `adjacent` | medium |
    ```
    There is no "rule 4" or "rule 3" anywhere in the skill — the current library uses named rules (`most-severe`, `majority`, `prefer-with-evidence-then-newer-then-strict`). These are stale table rows from a pre-named-rule era. The same file at line 126 insists: "Always document the resolution rule used per row." — but its own example references rules that don't resolve.
  - **§6 "Negative Results (both modes)"** appears (lines 145-152) but the consolidated.md rendering rule for *negative results* that multiple models independently arrived at vs only one flagged is unspecified — are negative results deduped too? They should be (otherwise 6 models flagging "no BPMN catalog in subject" produces 6 identical negative rows).
  - **§2 Items Table mixing of modes inside one section.** The §2A title (line 53) says "Mode A — schema-defined table" but then immediately (line 57) says "When `--schema` is not provided, use the default items table:". So Mode-A's own subsection describes Mode B. The §2A/§2B boundary is broken.
- **Unclear or ambiguous:**
  - Line 130: `**§5. Aggregated Scores (optional, both modes)**`. "Optional" but §2 Items Table is mandatory. By what signal is §5 omitted? If no model emitted a score, presumably §5 is skipped — but the file never says so, just calls it "optional".

### 6. `rules/examples/research-prior-art.md` (the worked example)

- **What works well:** The 14-entry alias map (lines 127-140) is concrete and reusable; the worked-example linkage to `docs/research-260624/SB_PRIOR_ART_USER_PROMPT.md` (line 173) gives an actual reproducible anchor.
- **Missing or wrong:**
  - **`aggregate: "sum"` (line 116) but consolidation-rules.md:252 + methodology.md:115 say `aggregate: "median"`.** The scoring rubric here sums 8 dimensions of 0/1/2 to a 0-16 total. consolidation-rules.md says aggregation is "median + min/max across models" *per item × dimension*. These are two different aggregations: (a) within a model, sum 8 dims → that model's TOTAL; (b) across models, take median of the per-item TOTAL. The example conflates them by labeling `aggregate: "sum"` (which is per-model total-sum aggregation) and not declaring the cross-model aggregator explicitly. A reader implementing consolidation will get this wrong.
  - **`maturity` conflict_resolution = `"newer"`** (line 97) but the named rules library (consolidation-rules.md:144-153) defines `newer` as the default rule for `date` type, not the `string` type. `maturity` is typed `string` (line 88). Mismatched type×rule; the example is silently relying on string values that happen to be dates.
  - **Header column mismatch in the alias map.** Lines 125-126 declare `| Alias | Canonical |` but the column usage is inverted (rows like "AutoGen/AG2, AutoGen (maintenance) → **AutoGen**" list multiple aliases pointing to a single canonical — table semantics are aliases-in-cell-1, canonical-in-cell-2). The column header itself matches usage, OK — but the body commas ("AutoGen/AG2, AutoGen (maintenance)") make the cell ambiguous: is that ONE alias with two slash-suffixes or two aliases? Should be a bulleted sub-list per canonical for unambiguity.
- **Unclear or ambiguous:**
  - Line 173: "the prompt did NOT embed the schema; the skill auto-injected it because `--no-auto-inject` was not passed". This is asserted as the prior run's behavior — but SKILL.md:6 says v2.1.0 introduces auto-injection (per `schema_auto_injected` field). Was auto-injection added *after* the prior-art run? If yes, this sentence is anachronistic — the run couldn't have used a feature that didn't exist yet.

### 7. `rules/examples/code-review.md` (code-review recipe)

- **What works well:** The "Why the old `primary_key: file:line` is wrong" callout (lines 70-72) is rare and valuable — it actively deprecates an incorrect pattern a user might cargo-cult. The custom-strategies table (lines 94-100) enumerates each field with rationale.
- **Missing or wrong:**
  - **§5 Per-Reviewer Statistics (line 90)** is promised in output想象力 enumerated sections but `output-schema.md` enumerates §1–§8 and Appendix A/B; no §5 Per-Reviewer Statistics. **The list of schema sections across the two files diverges** — output-schema.md §5 is "Aggregated Scores (optional)"; this file's §5 is "Per-Reviewer Statistics". Either output-schema.md is task-generic-but-with-arbitrary-§5-name and code-review.md overrides, or these are now misaligned.
  - **`evidence: concatenate-all` (line 99)** per the strategies table, but the schema (line 59) declares `"evidence": {"type": "string", "max_words": 50}`. `concatenate-all` of N reviewers' 50-word quotes can easily produce 150-300 words — but `max_words: 50` enforces a truncate (consolidation-rules.md is silent on the order of conflict-resolution vs. max_words enforcement). Will the final `evidence` be 50 words truncated, or is `max_words` validated at row-extraction only (line 71-72 of methodology.md says "after extraction")? Spec is silent on whether aggregate-step output respects `max_words`.
  - **`category` conflict_resolution = `"majority"`** (line 64) — but per consolidation-rules.md:144 the default for `string (enumerated)` is `prefer-with-evidence-then-newer-then-strict`. The schema override is correct; the gap is that the schema uses a named rule (`prefer-...`) whose `####` definition is *missing* from consolidation-rules.md (see finding in file 4). So this example references the very same broken rule library entry.
- **Unclear or ambiguous:**
  - No "Worked example" produced (line 111: "deferred to v2.2.0"). research-prior-art.md has a worked example; this and fact-check do not. Either remove the section header or flag it explicitly as "stub".

### 8. `rules/examples/fact-check.md` (fact-check recipe)

- **What works well:** The "3+ models rule was a typo" correction (line 109) is unusual and laudable — explicit acknowledgement that an earlier spec was wrong, with the corrected parameterized formula. The threshold table (lines 104-108) is reproducible.
- **Missing or wrong:**
  - **`confidence: "lowest-of-majors"` (line 68)** but the named rule library (consolidation-rules.md:188-192) defines `lowest-of-majors` as operating on `(value, confidence)` tuples and returning the lowest confidence **among the majority voters**. The schema declares `confidence` as an enum `["high","medium","low"]` (line 61) with no linkage to `verdict`. So when models return `{verdict: true, confidence: high}` and `{verdict: false, confidence: low}`, `lowest-of-majors` uses `majority` to pick the verdict-as-majority (`unverified` for N=3 if 2-1 split), but then **cannot** compute "lowest confidence among the majority voters" if the majority collapsed to `unverified` (a verdict not in the original enum). Edge-case: spec-unspecified behavior.
  - **`evidence: "all-collected"`** in the strategies table (line 97), but the schema declares `evidence` as `{"type": "text", "max_words": 50}` (line 63). Same breed of bug as code-review: aggregate-step `concatenate-all` / `all-collected` will blow past `max_words: 50`. Two example recipes independently hit the same unstated rule.
  - **No "Worked example"** (line 113: "deferred to v2.2.0"). Same gap as code-review.md.
- **Unclear or ambiguous:**
  - Line 109: "The '3+ models' rule in the original draft was a typo". Which original draft? There is no version history cited. The reader can't audit the typo correction against anything.

---

## §2. Score the Skill on the 8-Dimension Rubric

Using the rubric defined in `consolidation-rules.md`/`research-prior-art.md` (where applicable; last two dimensions are skill-specific variants per the task instructions).

| Dimension | Score | Justification |
|---|---|---|
| **Catalog of composable units** | **1** | Informal "named rules" library (8 rules, single `.md`). Not machine-readable as a registry — there is no JSON/enum file the consolidation engine can load. Several named rules are prose-only (`prefer-with-evidence-then-newer-then-strict` lacks a `####` block). |
| **Dynamic composition** | **1** | Some replanner flavor via the extractor-model fallback (methodology.md:104); no audit-log result. Schema-driven dispatch is parsed at run time but no per-call agent selection. No recorded events saying "extractor invoked at step X for model Y." |
| **V-loop depth** | **1** | End-test present (consolidated.md + conflicts.md verification), `phases_completed` provides per-step rollup, but **no intent gate** — there is no checkpoint that the mid-run state still matches the user's original intent before producing the final artifact. No `verify` phase. |
| **Enforcement** | **0** | Honor system throughout. No IDE hook, no CI gate, no delivery blocker; even the run-manifest's `models_failed` is a passive log. Nothing in the skill coerces correct consolidation — bad outputs surface only as text-quality regressions. |
| **Parent/worker split** | **2** | Explicit: parent agent invokes skill (orchestrator) and dispatches N worker subprocesses via one of 4 mechanisms; the worker-per-model contract (`<slug>.md` + `structured.jsonl`) is explicit. Strongest dimension. |
| **Evidence model** | **1** | Tiered: per-model `source_refs`, `prefer-with-evidence-then-newer-then-strict` privileges quoted sources. `last_verified` field exists. But `thorough` mode verification spec is unimplemented (no evidence-ledger.md or verification.md structure defined). Gated to 2 only when thorough mode is real; right now it's aspirational. |
| **SE + DevOps unified** (covers both production task types) | **1** | Partial. Covers SE well (code-review recipe); DevOps mostly absent — no recipe for IaC drift detection, config-rotation review, CI failure triage, security-audit consolidation. Fact-check recipe is transversal but not DevOps-flavored. The "task-agnostic" framing is an excuse to not commit to either domain's hard problem. |
| **Team customization** (supports team process packs) | **0** | None. Aliases live in `run-manifest.json` per run; conflicts rules in `--schema` per run. No "team pack" notion, no overlay mechanism, no shared rule registry. Configuring rules for a team requires the user to copy/paste the JSON every run. |

**Total: 0+1+1+0+2+1+1+0 = 6/16.**

A score this low for the skill's own rubric is meaningful: the rubric is built for *production agent frameworks*, and `multi-ai-task` is a *task utility*. The skill is mis-applying an aspirational rubric to itself. This itself is a finding — see §3.

---

## §3. Top 5 Improvements (ranked by impact × effort)

### 1. End the phase-numbering Schizophrenia: zero out Phase 3.5/3.6 → 3a/3b OR align decimals across files

- **Issue:** consolidation-rules.md uses "Phase 3.5 — RESOLVE CONFLICTS" and "Phase 3.6 — SCORE + SYNTHESIZE"; methodology.md/SKILL.md/output-schema.md use "Phase 1/2/3/4"; `run-manifest.json → phases_completed: [1,2,3,4]`. The fractional phases can never be recorded.
- **Why it matters:** A manifest produced per consolidation-rules.md literally cannot populate `phases_completed` correctly; any consumer/tooling that relies on it is silently broken.
- **Concrete change:** In `consolidation-rules.md:26,136,266` rename `Phase 2 — ALIGN` → `Phase 2 — EXTRACT` (drop "ALIGN", it appears nowhere else), `Phase 3.5 — RESOLVE CONFLICTS` → `Phase 3 — RESOLVE CONFLICTS`, `Phase 3.6 — SCORE + SYNTHESIZE` → `Phase 4 — SCORE + SYNTHESIZE`. Then in `output-schema.md:235` set `"phases_completed": [1, 2, 3, 4]` and document that Phase 4 = score+synthesize + final §1-§8 writing. Update methodology.md:108/120 to match.
- **Effort:** low (renames across 3 files)
- **Impact:** high (manifest fidelity)
- **Score:** high/low = **highest ROI in this review**

### 2. Add the missing `#### prefer-with-evidence-then-newer-then-strict` rule block (and `newer`, `most-cited`) to the named rule library

- **Issue:** consolidation-rules.md default table (line 146) names `prefer-with-evidence-then-newer-then-strict`, `newer`, `most-cited` as default rules but only the prose `prefer-...` block exists (lines 155-164) — and `newer` + `most-cited` have no `####` block at all. SKILL.md:144 explicitly lists `prefer-with-evidence-then-newer-then-strict` as a "named rule"; it isn't, formally.
- **Why it matters:** Two example recipes (`code-review.md` and the prior-art recipe's `maturity: newer`) reference rules whose formal definition is missing; an implementer following only the `####` library would conclude these rules were invented by example authors and apply a wrong default.
- **Concrete change:** In `consolidation-rules.md` after line 222 (end of `merge-exact`) insert three blocks:
  ```
  #### `prefer-with-evidence-then-newer-then-strict`
  - **Purpose:** default for enumerated `string` fields where evidence + recency + consensus interact (also used for `category` in research).
  - **Input:** List of `(value, evidence_quote?, last_verified?)` per model.
  - **Algorithm:**
    1. If exactly one value has a primary-source quote, return it.
    2. Else prefer the value whose supporting source has the newest `last_verified`.
    3. Else, if one value is a single-model outlier (1 of N reports it, no evidence), downgrade the outlier to the majority value.
    4. Tie-break by strictness (more conservative enum value wins).
  - **Edge case:** if all values are equal, no conflict; return early.

  #### `newer`
  - **Purpose:** default for `date` fields; pick the maximum date.
  - **Input:** List of ISO-8601 date strings.
  - **Algorithm:** `max(values)` after parsing. Missing/invalid → ignored; if all values invalid return `null` and flag.
  - **Edge case:** string fields containing date-ish content should be typed `date`, not `string`; the rule trusts the schema.

  #### `most-cited`
  - **Purpose:** default for `url` fields; pick the URL with the highest cross-model citation count.
  - **Input:** List of `(url, citing_models)` per model.
  - **Algorithm:** count occurrences across models (URLs normalized: lowercase, strip trailing `/`); return highest-count URL; ties broken alphabetically.
  - **Edge case:** empty list → `null`.
  ```
- **Effort:** low (pure documentation)
- **Impact:** high (closes the gap between SKILL.md, the default table, and the examples)
- **Score:** **high ROI**

### 3. Define `evidence-ledger.md` and `verification.md` schemas (or remove the `thorough` mode promise)

- **Issue:** SKILL.md:170-171 emits two files only in `thorough` mode; `output-schema.md` (the canonical output-structure file) is silent on both. `thorough` mode is sold as "high-stakes: regulatory, due-diligence" but its evidence/verification outputs are undefined structures.
- **Why it matters:** A "thorough" run is the trust-foundation of the skill; undefined output structure means two implementers can produce incompatible evidence-ledgers, and consumers (e.g., a downstream regulatory report) cannot rely on the format.
- **Concrete change:** In `output-schema.md` after the `run-manifest.json` block (after line 254), add:
  ```
  ## `evidence-ledger.md` (thorough mode only)

  One row per (claim × source_url). Verifier model re-fetches source_url and judges claim-vs-source.

  | claim_id | source_url | verifier_model | verdict | quote | fetched_at | http_status |
  |----------|-----------|----------------|---------|-------|-------------|-------------|
  | c-12     | https://… | opencode-go/qwen3.7-max | supports | "..." | 2026-06-27T09:14Z | 200 |

  `verdict` ∈ {supports, partial, contradicts, unreachable, wrong-claim}. A 4xx/5xx → unreachable. A 200 with no match → wrong-claim.

  ## `verification.md` (thorough mode only)

  One row per consolidated item with source_verified rollup:

  | item | sources_checked | supports | partial | contradicts | unreachable | overall |
  |------|-----------------|----------|---------|-------------|-------------|---------|
  | LangGraph | 4 | 3 | 0 | 0 | 1 | verified |
  | BadClaim | 2 | 0 | 0 | 2 | 0 | contradicted |

  `overall` ∈ {verified, partial, contradicted, unreachable}. Drives per-item `source_verified: true|false|wrong` per SKILL.md:81.
  ```
  Also: add an enforcement note that thorough mode is no-op without these two writers.
- **Effort:** medium (two extra schemas + cross-references in SKILL.md, methodology.md explains where they are produced in Phase 4)
- **Impact:** high (turns the "high-stakes" mode from marketing to mechanism)
- **Score:** **high ROI**

### 4. Specify the interaction between `max_words` and aggregate-step rules (`concatenate-all`, `all-collected`)

- **Issue:** Two example recipes use `evidence: concatenate-all` (fact-check.md:97) / `evidence: concatenate-all` (code-review.md:99) while `evidence` is declared `"text"/"string"` with `max_words: 50`. Per methodology.md:71-72 `max_words` validated "after extraction". But the aggregate step *can exceed* 50 words, and no rule says whether to re-truncate, re-validate, or skip cap.
- **Why it matters:** A code review with 5 reviewers producing 50-word quotes concatenated = 250 words in a field contractually capped at 50. Silent truncation destroys evidence; no cap validation invites the very WYSIWYG-parser overflow the skill warns against in `output-schema.md:258-269`.
- **Concrete change:** Add a subsection in `consolidation-rules.md` after line 222 (named rule library end) titled `### Aggregate-rule output sizing`:
  ```
  Aggregate rules (`concatenate-all`, `all-collected`, `union-dedup`) MAY produce
  outputs larger than the per-field `max_words` cap. By default, `max_words` is
  re-validated at the aggregate step: values exceeding `max_words` are kept and
  flagged in `conflicts.md` with `truncated_no`. To re-truncate, set
  `"aggregate_truncate": true` in the column spec. To relax the cap entirely for
  aggregate output, declare `"max_words_aggregate": null` and document the
  rationale in the recipe.
  ```
  Update both example recipes with the proposed config (probably `aggregate_truncate: false, max_words_aggregate: null` for evidence to reflect current intent).
- **Effort:** low (1 new paragraph + 2 example edits)
- **Impact:** medium (one real correctness bug + one WYSIWYG-rendering bug)
- **Score:** medium ROI

### 5. Stop using the skill's 8-dimension framework rubric for itself — adopt a skill-specific one

- **Issue:** §2 above shows multi-ai-task scores 6/16 on its own rubric, mostly zeroes on dimensions that don't apply (Enforcement, Team customization, SE+DevOps unified). The rubric is designed for *production agent frameworks*. Using it on a single-purpose skill utility produces low signal.
- **Why it matters:** Future reviewers (me and otherwise) re-apply a rubric that mostly punishes the skill for being the wrong shape — wasting ink on dimensions that don't apply. The rubric itself becomes theater.
- **Concrete change:** In the SKILL.md "See also" section or a new `rules/review-rubric.md`, declare a 5-dimension skill-specific rubric appropriate to a task-utility skill:
  ```
  | Dimension | 0 | 1 | 2 |
  |---|---|---|---|
  | Schema completeness | No schema | JSON table only | JSON table + conflict rules + types + edge cases |
  | Dispatch robustness | Hardcoded 1 path | Multiple paths, no fallback table | All 4 mechanisms + failure-mode matrix + retry-vs-no-retry policy |
  | Consolidation determinism | LLM in the loop | Configurable rules | Named-rule library with edge cases |
  | Output artifact contract | Ad hoc | Markdown templates | JSON-structured files + WYSIWYG rules |
  | Reproducibility | None | Timestamp dirs | Run-manifest + content hashes + phase tracking |
  ```
  Self-score on the new rubric would land ~7/10 (vs 6/16 on the framework rubric) and the deltas would be actionable — the current rubric waters down to "the skill is not a framework" complaints.
- **Effort:** medium (1 new file + SKILL.md cross-ref + retire old rubric from examples)
- **Impact:** medium (only valuable because of the recurring self-review pattern visible in `critical-review-r{2,3,4}.md`)
- **Score:** medium ROI

---

## §4. Open Questions

1. **What is the implementation surface?** The skill reads as a hybrid — part executable (dispatch mechanics II-IV ship working bash), part spec (the consolidation rules describe algorithms in pseudocode, not a binary). If no engine implements the consolidation rules, then named-rule gaps (`prefer-...`) are non-fatal because every implementer has to code it themselves anyway. **Answering this changes §1-§3 entirely:** if the skill is purely spec, my improvements 1-2 are documentation-correctness only; if there's a reference implementation consuming these files, they're hard bugs.

2. **Cycle: this skill has been reviewed 4+ times (r1, r2, r3, r4 + this).** Are findings being fixed across rounds or are reviewers re-flagging? My read suggests the manifest-schema bug (fixed) and `score-aggregate.md` advisory (still present) are the two diagnostic outliers. Would a quick git-blame of `critical-review-r*.md` against the rules files tell us whether fixes are landing? I'd want that data before declaring which of my findings are new.

3. **Audience.** Is the skill invoked by another agent (per `user-invocable: false`, line 5) — i.e., does the human user ever read these files? If not, the SKILL.md prose quality is mostly for the LLM's consumption and many of my clarity findings (e.g., "natural output format" ambiguity) are lower-priority. If yes, the worked-example stubs (code-review/fact-check "deferred to v2.2.0") are real UX debt.

4. **The `user-invocable: false` + "you are a parent orchestrator using this skill RIGHT NOW" framing.** The skill is invoked by another agent — but the dispatch-mechanics.md describes the parent agent *as* the skill's executor (calling `npx opencode-ai run`, bash forking workers). When the skill says "the skill dispatches", is the executor the parent agent (in whose session the skill kit is loaded) or a separate process spawned by the parent? Conflating these two changes whether the dispatch mechanics file should be instructions-to-the-skill-vs-instructions-to-the-agent-who-calls-the-skill.

5. **Thorough-mode verification dispatch.** SKILL.md:81 says thorough mode dispatches "a verifier model to check the claimed source." Methodology.md doesn't have a Phase for it. Is it a Phase 3 pre-step or part of Phase 4? The phase-base would change `phases_completed` semantics.

---

## §5. Confidence

- **Overall confidence:** **medium**
- **What would change my assessment:** (a) Confirming whether there's a reference implementation consuming the named-rule library — if yes, my §3 improvements 1-3 are hard bugs, not docs; if no, they're docs. (b) A `git log` on the skill files to see whether prior reviewers' findings have been landing — currently I only know `score-aggregate.md` persisted while the manifest schema was fixed, leaving me unsure whether to weight "unfixed findings persist" or "findings get triaged" heavily.

---

**Final line:** This is the 5th+ round of self-review on this skill. The skill has improved each round (manifest schema now consistent across files), but it carries forward several self-inflicted inconsistencies that should have been caught *before* a "v2.1.0" tagging: phantom rule numbers in §4 examples, missing `####` blocks for default rules, undefined `thorough`-mode output schemas, and a rubric the skill scores 6/16 on by its own admission. The highest-ROI change is fixing the phase-numbering Schizophrenia (§3.1) and formalizing the three named rules currently only in prose/table-different (§3.2) — both are doc-only. The `thorough`-mode evidence-ledger definition (§3.3) is the next biggest lift: it converts the skill's "high-stakes" mode from a paragraph promise into an enforceable structure.
