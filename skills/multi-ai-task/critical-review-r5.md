# Critical Self-Review: multi-ai-task v2.1.0

**Reviewer:** Parent orchestrator (meta-task — the skill is reviewing itself)
**Date:** 2026-06-27

---

## §1. Critical Assessment — Per File

### 1. SKILL.md (entry point)

**What works well:**
- The when-to-use / when-NOT-to-use tables (lines 35-50) are crisp and decision-oriented — rare for skill docs.
- The `--schema` parameter documentation (lines 85-165) is by far the strongest section: column types, supported fields, composite keys, conflict resolution, and auto-injection are all covered in one place.

**What is missing or wrong:**
- **The "task-agnostic" claim contradicts the consolidation model.** Lines 16-22 describe 7 steps, but steps 3-6 (extract structured items, dedup, resolve disagreements, aggregate scores) all assume the output is **list-shaped**. The skill's own `consolidation-rules.md:9-22` admits: "For the consolidation step to work, the model responses need to be decomposable into **items**." This is *list-task-agnostic*, not task-agnostic. Tasks producing prose (writing critique), code (refactoring plans), or structured documents (architecture proposals) are forced through a lossy H2-split heuristic (`methodology.md:83-98`) that treats section headings as items. The skill should state this constraint upfront rather than bury it in a sub-file.
- **No `--aliases` CLI flag.** The skill tells users to "build an alias map for your task type" (`consolidation-rules.md:82`) and "document the alias map in your run's `run-manifest.json → aliases`" but provides zero mechanism to pass an alias map at runtime. The `--schema` JSON has no `aliases` field. A user reading SKILL.md would never know aliases exist, let alone how to use them.
- **Provenance section is operational baggage.** Lines 263-275 spend 13 lines on a folder-naming dispute and a self-review meta-reference (line 278: "A self-review run (also on 2026-06-27) used the skill recursively to review itself"). This is navel-gazing. The skill doc doesn't need to reference its own review runs. Replace with a 2-line table of validated task types.
- **Default model discovery algorithm is unspecified.** Line 73: "queries the local OpenCode config… and picks a balanced default set of 4-6 models across the available providers." No pseudo-algorithm, no tie-breaking, no fallback for missing config. "Balanced" is defined in prose but not implementable from the description alone.

**What is unclear or ambiguous:**
- Lines 50 and 172 contradict each other? Line 50 says "You have ≤1 model available — no diversity to consolidate" as a Don't-Use. But `dispatch-mechanics.md:172` says "Below 2, the skill adds no value." Is the minimum 2 or 3? The methodology needs at least 2 for any dedup but at least 3 for `majority-with-uncertain` to be meaningful — this distinction is never explained in SKILL.md.
- The "Proven provenance" run used `--dangerously-skip-permissions` (per the example shell script). SKILL.md's description of what the skill does (line 16-22) never mentions this security posture or warns about it. Should every run use that flag?

---

### 2. rules/methodology.md (4-phase pipeline)

**What works well:**
- The phase decomposition (1-4) is clear and linear. Each phase has well-defined inputs and outputs.
- The pseudocode for structured extraction (lines 37-65) is concrete and implementable: 4 fallback paths with clear ordering.

**What is missing or wrong:**
- **"Slowest/highest-capability model" extractor selection is undefined.** Line 53: "the slowest/highest-capability model from the original dispatch (NOT the model that produced the response — that model has already failed to produce structured output, asking it again is unlikely to help)." Slowest ≠ highest-capability. These are different criteria and they can conflict — e.g., a small fast model might be better at reformatting JSON than a slow reasoning model. No algorithm is provided to resolve the tie or rank models. If all models finish simultaneously, "slowest" is undefined.
- **Free-form extraction is fragile and the design acknowledges it.** Line 97: the comment says `// First 5 words = primary_key (fragile; flag fuzzy_match:true)`. If a design document describes its own fragility in comments, that's a sign the design is insufficient. For prose-heavy outputs (writing critique, ideation), the "first 5 words" dedup key produces garbage — two paragraphs starting "The main issue with…" would be incorrectly merged.
- **"Idempotent re-runs" is a future enhancement, not a feature.** Line 173: "the `run-manifest.json` from previous runs can be referenced for incremental consolidation (future enhancement)." Either document it as a feature or remove it. A "future enhancement" in a shipped skill spec is a broken promise.
- **Schema auto-injection is described in 4 places.** It appears in SKILL.md:16, SKILL.md:155-157, methodology.md:15-16, and Phase 1 (methodology.md:9-15). Each restates the same content with slightly different wording. The DRY principle applies to skill docs too — define once, reference.

**What is unclear or ambiguous:**
- Phase 2 extraction (line 40) says "Match headers case-insensitively; allow synonyms (`cat` ↔ `category`)." What is the complete synonym map? The consolidation-rules.md:49 lists a few (`cat ↔ category`, `pw ↔ parent_worker`, `enf ↔ enforce`) but this is stated as a "tip" not a defined mapping. An implementer would not know all allowed synonyms.
- How does the phase numbering in methodology.md (1-4) relate to the "Phase 2 — ALIGN", "Phase 3 — DEDUP", "Phase 4 — RESOLVE CONFLICTS", "Phase 5 — SCORE + SYNTHESIZE" naming in consolidation-rules.md (lines 26, 78, 136, 267)? The two files use different numbering and different names for overlapping concepts. A reader switching between files would be confused.

---

### 3. rules/dispatch-mechanics.md (4 dispatch mechanisms)

**What works well:**
- The four mechanisms are well-described with concrete code examples. The parallel-vs-sequential decision table (lines 106-113) is practical and actionable.
- The failure handling table (lines 131-141) is comprehensive and links symptoms to causes to fixes — this is the best documentation pattern in the entire skill.

**What is missing or wrong:**
- **No MCP-awareness in dispatch.** Different models dispatched in parallel may have different tool/MCP availability. Mechanism 2 uses `--dangerously-skip-permissions` which may grant write/tool access that creates incomparable outputs — one model might `webfetch` a source while another can't, leading to false "disagreement" in consolidation. The skill's own "When NOT to use" says: "Tool execution varies per model — consolidation assumes same prompt → comparable outputs" (SKILL.md:48) but the skill does nothing to prevent this scenario. There's no mechanism to equalize tool access, no per-model capability manifest, and no warning when models have asymmetric tools.
- **The `TIMEOUT_CMD` logic is buggy on macOS.** Lines 44-48: if `gtimeout` is not installed (which requires Homebrew and `brew install coreutils`), `TIMEOUT_CMD="timeout"` — but macOS doesn't ship `timeout`. The script will error silently in background subprocesses with `timeout: command not found`. The script should either require `gtimeout` and fail fast, or use an alternative (e.g., `perl -e 'alarm shift; exec @ARGV' -- $TIMEOUT $CMD`).
- **Mechanism 3 references a known issue with a broken workaround.** Line 86: "Workaround: pass model on server side via config, or use Mechanism 2." If the workaround is "don't use this mechanism," then Mechanism 3 is not a real option — it should be flagged as "unreliable as of 2026-06" or demoted in the preference order.
- **No mention of `$PATH` for `npx`.** Mechanism 2's shell script assumes `npx` is in `$PATH`. On some Node installations (nvm, fnm, volta), `npx` isn't available in non-interactive shells. Background subprocesses (`&`) may inherit a different `$PATH` than the interactive session. Silent failures are the worst kind.
- **"Balanced" model selection is hand-wavy.** Line 174: "at least 2 different provider families, no more than 2 models from the same family, with at least one reasoning-capable model if the task is research-like" — how is "research-like" determined? By keyword matching on the prompt? This is an implementation detail masquerading as a specification.
- **Model selection strategy table (lines 166-170) contradicts default discovery.** The table says "≥1 reasoning-focused model… for research" but the default discovery says "at least one reasoning-capable model if the task is research-like." The default is weaker than the recommendation. Shouldn't the default match the recommendation?

**What is unclear or ambiguous:**
- Line 119: "Always check the model's CWD for stray *.md files after a dispatch." Is this a user instruction or a skill behavior? If the skill is supposed to handle this automatically, it's not documented as a phase. If it's manual, it's a fragile recovery step that violates the "automatic" promise.

---

### 4. rules/consolidation-rules.md (dedup, conflict resolution, scoring)

**What works well:**
- The named rule library (lines 165-222) is the strongest part of the entire skill. Eight rules, each with Purpose / Input / Algorithm / Edge case. Each rule is implementable from the description alone. This is what a specification should look like.
- The conflict resolution documentation template (lines 226-235) is clear with a worked example.

**What is missing or wrong:**
- **Alias map has no runtime injection mechanism.** Line 82: "supply an alias map at run time." The skill provides no `--aliases` CLI flag, no field in `--schema` JSON, and no environment variable. The only documentation of an alias map is in the research example (`research-prior-art.md:121-142`) as a markdown table — which is human-readable but not machine-ingestible. A user who builds an alias map has no way to feed it to the skill without modifying the consolidation code.
- **`prefer-with-evidence-then-newer-then-strict` is a prose description, not an algorithm.** Lines 155-161 describe a 4-step resolution rule, but unlike the 8 named rules below it, there's no Pseudocode, no Input definition, no Edge case section. It's the only resolution rule in the "default" table (line 146) that has no algorithmic definition. For the most important default rule (it governs `category` — the most-contentious field in the proven research run), this is a specification gap.
- **`aggregate: "sum"` is used in the research rubric but not defined in the schema or consolidation rules.** The research example's scoring rubric (`research-prior-art.md:116`) uses `"aggregate": "sum"`. The SKILL.md schema spec supports `aggregate: "median"` on numeric columns (line 100). The consolidation-rules score aggregation (lines 250-257) only describes median. `sum` is never defined as a supported aggregation anywhere in the core rules. This means the proven worked example uses a feature that doesn't exist in the spec.
- **"Outlier downgrade" is referenced but not named or defined.** The conflict resolution table (line 231-233) shows "outlier downgrade (1 of 6 says direct with no evidence quote)" as a resolution rule — but "outlier downgrade" is not in the named rule library. It's buried in step 3 of the `prefer-with-evidence-then-newer-then-strict` prose description (line 160). If it's a sub-rule of that composite, it should be named and algorithmically defined like the others.
- **Phase numbering is inconsistent.** This file uses "Phase 2 — ALIGN" (line 26), "Phase 3 — DEDUP" (line 78), "Phase 4 — RESOLVE CONFLICTS" (line 136), "Phase 5 — SCORE + SYNTHESIZE" (line 267). But methodology.md uses "Phase 1 — Per-model execution", "Phase 2 — Output capture and extraction", "Phase 3 — Cross-model consolidation", "Phase 4 — Final synthesis." The two numbering schemes don't align. Phase 2 in one file = Phase 2 in the other, but Phase 3 in methodology = Phases 3+4+5 in consolidation-rules. This is confusing.
- **The dedup algorithm assumes `primary_key` field exists.** The algorithm (lines 96-111) reads `row.primary_key`. In free-form mode, there is no `primary_key` per se — there's a fuzzy-matched title or an H2 heading. The algorithm doesn't show how free-form keys are plumbed into this path.

**What is unclear or ambiguous:**
- The "minimal contract for consolidation" (lines 8-21) says items can be "A code-review finding (file:line, severity, message)." This implies a specific field structure, but elsewhere the code-review schema uses composite keys (`file` + `line` both with `dedup_key: true`). The "minimal contract" says an item has "A unique identity" — but composite keys mean identity is a tuple, not a single value. The contract doesn't address this.
- `severity_order` is referenced (line 171) as "declared in the schema" but SKILL.md's schema field documentation doesn't include `severity_order` as a supported field. It appears only in the code-review example (`code-review.md:75`) inside `conflict_resolution`. It's not formally part of the schema spec.

---

### 5. rules/output-schema.md (output structure)

**What works well:**
- The two-mode output structure (Mode A structured, Mode B generic) is clearly documented with concrete section templates.
- The `run-manifest.json` field definitions (lines 239-254) are complete with field semantics — this is the canonical schema and it's well done.

**What is missing or wrong:**
- **Thorough-mode file schemas are implicit.** `evidence-ledger.md` (SKILL.md:187-192) and `verification.md` (SKILL.md:196-202) are shown as example rows but have no formal field definitions. No required/optional, no types, no validation rules. Compare with `run-manifest.json` which has 15+ fields each with semantic descriptions. If the skill produces these files, their schemas should be defined here alongside the others.
- **The `structured.jsonl` format differs between this file and methodology.md.** Output-schema.md:200 shows `source_refs: ["minimax-m3.md#L42-50"]` (a per-model reference). Methodology.md:28 shows `source_refs: ["minimax-m3.md#L42-50"]` plus `item` and `fields` with actual schema values. The output-schema version is simpler; the methodology version is more complete. Which is canonical?
- **No output schema for `consolidated.html`.** SKILL.md:205 says "convert `consolidated.md` to HTML using a markdown library" — but there's no specification of what the HTML should contain beyond "Embed minimal CSS inline (table styles, conflict-marker color, section anchors)." What CSS classes? What conflict-marker colors? What section anchor IDs? The HTML output is unspecified beyond a one-liner.
- **The file header template (lines 24-35) is underspecified.** "Dispatch note: brief note on the dispatch mechanism used" — "brief note" is not a specification. What fields? What format? Is it free-text or structured?
- **Header says "Models: N total" but doesn't distinguish dispatched vs responded.** If 6 models were dispatched and 2 failed, is N=6 or N=4? The consolidation tables below use "Mentions: N" meaning "how many models found this item" — but the header N is ambiguous.

**What is unclear or ambiguous:**
- Section numbering (lines 53-190). Mode A (§2A) and Mode B (§2B) suggest the output has two mutually exclusive tracks. But §3-§8 and Appendices A-B apply to "both modes." This is clear enough but the transition from the §2A/§2B fork to the §3 common path is implicit — a reader might not realize §3 is shared.
- Line 70-75: The conflict marker legend suggests `` `direct*` `` for WYSIWYG viewers. But the `*` suffix conflicts with the markdown emphasis syntax. If `*` is the conflict marker, a value like `major*` would render as italic `major` in some parsers. The suggestion to use backtick-wrapping everywhere is a reasonable workaround, but it adds visual noise.

---

### 6. rules/examples/research-prior-art.md (proven example)

**What works well:**
- Complete, end-to-end, with an actual run that produced real output. The alias map is concrete (14 entries). The scoring rubric is explicit. This is what all examples should look like.
- The prompt template (lines 37-68) shows what a well-structured research prompt contains — useful for users adapting to other research tasks.

**What is missing or wrong:**
- **Uses `aggregate: "sum"` which is not in the core spec.** Line 116: `"aggregate": "sum"` in the scoring rubric. As noted in §1.4, this feature is not defined in the SKILL.md schema spec or the consolidation-rules score aggregation. The example showcases a feature that doesn't formally exist.
- **Task-specific field names leak into the skill's language.** The schema (lines 72-99) has `gaps_vs_sb` and `sb_gaps_vs_them` — fields named after "Silver Bullet." The output-schema.md §3 uses `gaps_vs_reference` and `reference_gaps_vs_them` as a generic template. The example should use the generic names to reinforce that the skill is task-agnostic.
- **The scoring rubric (lines 102-119) is separate from the `--schema` JSON.** The rubric defines dimensions, levels, aggregate function, and max_total. But the `--schema` parameter only accepts the table schema (columns + conflict resolution). The scoring rubric is an ad-hoc second schema that has no formal integration point. How is it passed? Embedded in the prompt? As a second CLI flag? The example doesn't say.

**What is unclear or ambiguous:**
- Line 182: "diminishing returns past 6 (this is an empirical observation, not a measured curve — run your own benchmark if you want a hard number)." This is self-contradictory: "empirical observation" implies measurement, but "not a measured curve" denies measurement. Either say "our one run showed X" or don't claim an empirical basis.

---

### 7. rules/examples/code-review.md (code-review recipe)

**What works well:**
- The composite-key explanation (lines 68-70) and the severity_order override (lines 73-78) are clear.
- The security posture is explicit (line 45: does NOT pass `--dangerously-skip-permissions` for read-only review).

**What is missing or wrong:**
- **No worked example exists.** Line 111: "Not yet produced (deferred to v2.2.0)." This is the second-most-important task type for the skill (after research) and it has never been proven. The skill claims v2.1.0 generalized to "task-agnostic" but only has one validated task type.
- **No scaling guidance for `N reviewers × M files`.** If you dispatch 5 reviewers to review 50 files, you get 250 review reports. How does the composite-key dedup work across files? The dedup key is `(file, line)` — within a file this works, but if two reviewers flag different files, no dedup happens. That's correct behavior, but the example doesn't explain the boundary.
- **The composite-key defense is overly defensive.** Lines 70-71: "Why `"primary_key": "file:line"` is wrong for composite keys" — this spends 3 lines explaining why a wrong approach is wrong. A well-designed API doesn't need to document anti-patterns in its examples. If users keep making this mistake, fix the parser to accept `"primary_key": "file:line"` as a convenience shorthand. Otherwise, this reads as a design wart papered over with docs.
- **§6 "Coverage Gaps" in the output (line 90) is not in the output-schema.md template.** The canonical output structure in output-schema.md lists §1-§8 + Appendices A-B. "Coverage Gaps" is not one of them. The example invents a section that doesn't exist in the canonical schema.
- **§5 "Per-Reviewer Statistics" (line 89) is also not in the canonical schema.** Same problem — the example defines output sections that have no backing in the core spec.

**What is unclear or ambiguous:**
- The dispatch script (line 33) uses only 2 models (`minimax-m3` and `qwen3.7-max`). The model selection strategy table (`dispatch-mechanics.md:170`) says code-review should use "≥1 code-specialized model if available." The example uses generalist models. This mismatch between recommendation and example undermines the strategy table.

---

### 8. rules/examples/fact-check.md (fact-check recipe)

**What works well:**
- The consensus threshold table (lines 101-108) is clear and actionable. The 4-tier classification (confirmed, debunked, flagged, unverified) is well thought out.
- Custom strategies table (lines 93-99) correctly maps each field to the right resolution rule.

**What is missing or wrong:**
- **No worked example exists.** Line 113: "Not yet produced (deferred to v2.2.0)." Same credibility gap as code-review.
- **Duplicates `majority-with-uncertain` algorithm from consolidation-rules.md.** Lines 73-77 re-describe the algorithm: "For N=3, all 3 must agree; for N=5, at least 4 must agree; for N=7, at least 5 must agree." This is already in consolidation-rules.md:188-190 with the formal `> max(2, ceil(N/2))` definition. The example's prose restatement will drift from the canonical definition over time.
- **`verdict_per_model` field in output §3 is not in the schema.** Line 89 mentions `verdict_per_model = {m1: true, m2: false, m3: true}` as an output field. But the fact-check schema (lines 54-69) doesn't have a `verdict_per_model` column — it has a per-row `verdict` after consolidation. The per-model breakdown exists in `structured.jsonl` but is not in the consolidated output schema.
- **No handling of opinion-based claims.** The fact-check example assumes claims are verifiable against sources. What about claims like "X is the best framework for Y" — inherently subjective? The skill would produce `unverified` for all such claims, but the example doesn't warn about this boundary.

**What is unclear or ambiguous:**
- Line 77: "unverified is a valid output (don't force a true/false judgment when evidence is insufficient)" — this is good guidance but it's buried in a per-field note. It should be a top-level principle for the fact-check task type.

---

## §2. Score the Skill on the 8-Dimension Rubric

| Dimension | Score | Justification |
|---|---|---|
| **Catalog of composable units** | 1 | The named rule library (8 rules in consolidation-rules.md) is a machine-readable catalog of composable conflict-resolution algorithms. The schema type system (8 column types) is a typed catalog. However, these catalogs are embedded in prose, not in a parseable manifest. The alias maps, skip rules, and mode definitions are ad-hoc, not cataloged. The skill has the right pieces but no single machine-readable manifest that binds them. |
| **Dynamic composition** | 1 | The skill supports mode selection (`quick`/`standard`/`thorough`) and schema-driven composition (columns, conflict rules, dedup keys). However, composition is static at launch time — once a run starts, the mode and schema are fixed. There is no "replanner" that adapts mid-run (e.g., switching from standard to thorough if conflicts exceed a threshold). No audit log of composition decisions. |
| **V-loop depth** | 0 | The skill has no verification loop at any level. Phase 4 "Final synthesis" produces output, but there is no post-synthesis verification step, no intent gate (did the consolidated output actually answer the user's prompt?), and no iterative refinement. The skill is a single-shot pipeline. Even `thorough` mode's verifier model checks source claims but does not re-verify the consolidation itself. |
| **Enforcement** | 0 | Honor system only. There are no CI checks for skill correctness, no IDE hooks that validate schema compliance, no delivery blockers that prevent publishing a corrupted consolidation. The skill relies entirely on the calling agent to use it correctly. The output is human-readable markdown with no machine-verifiable assertions. |
| **Parent/worker split** | 2 | Explicit orchestrator/worker model. Phase 1 dispatches to N worker models. The parent (consolidation engine) processes their outputs in Phases 2-4. The `structured.jsonl` format tracks per-model provenance. The `run-manifest.json` records which models responded and which failed. This is a clean orchestrator/worker architecture, well-documented. |
| **Evidence model** | 2 | Tiered sufficiency: quick mode has no evidence requirement, standard mode requires per-field conflict documentation with resolution rules, thorough mode adds per-claim source verification with `evidence-ledger.md` and `verification.md`. Staleness: the schema supports `last_verified` date fields, and the `prefer-with-evidence-then-newer-then-strict` rule uses recency as a tiebreaker. The `most-severe` rule has `allow_downgrade` for evidence-based downgrading. This is a genuine tiered evidence model. |
| **SE + DevOps unified** | 2 | The skill covers both production task types. The research example evaluates tools across both SE dimensions (composition model, V-loop, enforcement) and DevOps dimensions (parent/worker split, evidence model). The code-review example covers SE directly. The skill is task-agnostic enough to handle infrastructure analysis, deployment review, and security audit. Both domains are covered in one model — the same schema system and consolidation rules apply to both. |
| **Team customization** | 1 | The `--schema` parameter allows per-task customization (columns, types, conflict rules, mode). The examples serve as "recipe packs" for common task types. However, there is no overlay/composition system for team process packs — two teams can't merge their customizations. To add a new task type, you fork the skill by writing a new example file. The skill recognizes the need (custom strategies table in consolidation-rules.md:303-309) but doesn't provide a mechanism for teams to compose and share customizations. |

**Total: 9/16**

---

## §3. Top 5 Improvements (ranked by impact × effort)

### 1. Add `--aliases` CLI flag and `aliases` field to `--schema` JSON

- **Issue:** The skill tells users to build alias maps but provides no mechanism to pass them at runtime.
- **Why it matters:** Without a way to inject aliases, every run requires the user to hardcode alias maps into the consolidation code — the skill is not actually usable for dedup-heavy tasks without code modification. This is the single biggest "the spec says you can but you actually can't" gap.
- **Concrete change:**
  - Add `--aliases <json|file>` to `SKILL.md:66` (inputs table) and the usage line (SKILL.md:57).
  - Add `"aliases": {"AutoGen/AG2": "AutoGen", ...}` as an accepted top-level field in the `--schema` JSON spec (SKILL.md:92-112, after `"conflict_resolution"`).
  - Document default behavior when `--aliases` is not provided: `normalize = lowercase + strip-punctuation + collapse-whitespace, exact match` (already defined in consolidation-rules.md:335 — just surface it in SKILL.md).
  - Update research-prior-art.md to show the alias map passed via `--aliases` instead of as a separate markdown table.
- **Effort:** Low (add one CLI flag, one schema field, update docs in 3 files)
- **Impact:** High (removes the biggest usability blocker in the skill)
- **Score:** High / Low = **Highest ROI**

### 2. Define `aggregate` as a first-class schema concept (add `sum`, `mean` to complement `median`)

- **Issue:** The research example uses `aggregate: "sum"` (research-prior-art.md:116) but the core schema (SKILL.md:100) only supports `aggregate: "median"` on numeric columns, and the consolidation-rules score aggregation (consolidation-rules.md:250-257) only describes median. `sum` and `mean` are undefined.
- **Why it matters:** The only proven example uses a feature that doesn't exist in the spec. This is a spec bug, not a missing feature — either the example is wrong or the spec is incomplete.
- **Concrete change:**
  - In SKILL.md, add an `aggregate` column field to the supported column fields table (after line 149):
    ```
    | `aggregate` | For numeric: aggregation method. `"median"` (default), `"mean"`, `"sum"`. Only meaningful in score-aggregation contexts (scoring matrices, not per-row fields). |
    ```
  - In consolidation-rules.md § "Score conflict resolution" (line 250-257): add `mean` and `sum` algorithms alongside `median`.
  - In research-prior-art.md, verify the scoring rubric's `aggregate: "sum"` is now backed by the spec.
- **Effort:** Low (add one column field, two algorithm descriptions)
- **Impact:** Medium (fixes a spec bug; the research example was the user's "hello world")
- **Score:** Medium / Low = **High ROI**

### 3. Fix free-form extraction fragility by adding a structured-fallback prompt

- **Issue:** Free-form mode (Mode B) splits by H2 headings and falls back to "first 5 words as primary key" (methodology.md:97). The code comment calls this "fragile" — and it is. For prose tasks like writing critique or ideation, this produces nonsensical dedup.
- **Why it matters:** Free-form mode is the fallback for all tasks without a schema. If it produces garbage, the skill is useless for any task that isn't table-shaped. The "task-agnostic" claim depends on this working.
- **Concrete change:**
  - In methodology.md, replace the paragraph-split fallback (lines 94-98) with: "If the response has no H2 structure, send the response to the extractor model with a structured prompt: 'Reformat this response into a JSON list. Each item should have a `title` (a short summary), `body` (the full text), and any URLs found.' Parse the extractor's JSON output."
  - This reuses the existing extractor-model infrastructure (path 3 in the pseudocode) instead of the lossy path 4.
  - Remove the "first 5 words" fallback entirely. Flag responses that can't be extracted at all as `{model, "extraction_failed": true}` in `structured.jsonl`.
- **Effort:** Medium (change one fallback path; test with prose-shaped model outputs)
- **Impact:** High (makes Mode B actually usable for non-research tasks)
- **Score:** High / Medium = **High ROI**

### 4. Produce worked examples for code-review and fact-check (prove the task-agnostic claim)

- **Issue:** Two of three example task types have "Not yet produced (deferred to v2.2.0)" — code-review.md:111 and fact-check.md:113. The skill claims v2.1.0 generalized to task-agnostic but has only one validated task type.
- **Why it matters:** A skill that claims to work for N task types but has only been proven on one is not a v2.1.0 skill — it's a v1.0.0 skill with v2.1.0 aspirations. The task-agnostic claim is not credible without evidence.
- **Concrete change:**
  - Run the code-review recipe against a real file (e.g., one of the skill's own source files — meta again, but at least it's a real run).
  - Run the fact-check recipe against 5-10 real claims with known ground truth.
  - Document the results in code-review.md and fact-check.md under a "Worked example" section (replace the "Not yet produced" line).
  - Update SKILL.md provenance to list validated task types: research (2026-06-27), code review (date), fact-check (date).
- **Effort:** High (requires actual multi-model runs, which cost compute time and API credits)
- **Impact:** High (validates the core claim of the skill; turns a spec into a proven tool)
- **Score:** High / High = **Medium ROI** (necessary work, but expensive)

### 5. Define the `prefer-with-evidence-then-newer-then-strict` rule algorithmically (same standard as the 8 named rules)

- **Issue:** The most important default conflict resolution rule (governs `category` for enumerated strings) is a 4-step prose description (consolidation-rules.md:155-161) with no Input, Algorithm, or Edge case sections — unlike the 8 named rules that follow it.
- **Why it matters:** The rule has 4 sub-steps including "outlier downgrade" (an unnamed, undefined sub-rule) and "tie-break." These are implementation details that need the same rigor as the rest of the rule library. If an implementer can't code this rule from the spec, the most-common conflict resolution path is broken.
- **Concrete change:**
  - In consolidation-rules.md, replace lines 155-161 with the same format as the 8 named rules:
    ```
    #### `prefer-with-evidence-then-newer-then-strict`
    - **Purpose:** Resolve enumerated string conflicts by preferring cited evidence, recency, then strict majority with outlier downgrade.
    - **Input:** List of `(value, evidence_quote?, last_verified?, model)` per model.
    - **Algorithm:**
      1. If exactly one model has `evidence_quote` (non-empty, primary source URL present), return that model's value.
      2. Else, compute newest `last_verified` date. If exactly one model has the newest date and it differs from others, return that model's value.
      3. Else, count values. If one value has ≥ `ceil(N/2)` occurrences, return that value. If the counts split such that the most-frequent value would be an outlier (1 of N), downgrade: return the next-most-frequent value instead.
      4. Else (tie), prefer the value with the strongest evidence quote (longest `evidence_quote` field), then prefer the most recent `last_verified`.
    - **Edge case:** N=0 → return `null`. N=2 with different values and no evidence → return `null`, flag as "no resolution."
    ```
- **Effort:** Low (restructure existing prose into algorithmic format; no new logic)
- **Impact:** Medium (improves spec quality; implementers already have the prose to work from)
- **Score:** Medium / Low = **High ROI**

---

## §4. Open Questions

1. **Who is the intended audience for this skill?** The skill reads like it targets both end users (the usage examples, the when-to-use tables) and skill authors (the detailed algorithm descriptions, the implementation pseudocode). These audiences have different needs. An end user doesn't need to read the Levenshtein distance threshold for fuzzy matching; an implementer doesn't need a when-to-use table. Is this skill designed primarily for agents to execute, or for humans to invoke? The documentation doesn't commit to one audience.

2. **Is there a reference implementation, or is this purely a specification?** The skill references a "proven provenance run" but the run was done manually via shell scripts, not via a skill engine. The pseudocode in methodology.md and consolidation-rules.md implies a reference implementation exists, but none is linked. Is the "skill" a specification for an implementation that doesn't exist yet?

3. **What is the exit criterion for the need of `--dangerously-skip-permissions`?** Mechanism 2 uses this flag for read-only tasks, but the flag itself is named to suggest it's dangerous. Is there a plan to add a `--read-only` mode to `opencode run` that would make this flag unnecessary? If so, document the transition plan. If not, the skill is permanently dependent on a flag that its own documentation warns about.

4. **Why are code-review and fact-check proofs deferred to v2.2.0 when the skill claims v2.1.0 has been generalized?** The version numbering implies the generalization is complete. If it's not, the version should be v2.0.0-alpha or the task-agnostic claim should be qualified: "proven for research; experimental for code-review, fact-check, ideation."

5. **How does the skill handle tasks where the "best" answer isn't dedup-able?** For creative tasks (ideation, writing critique), dedup is actively harmful — you want all ideas preserved, not merged. The custom strategies table (consolidation-rules.md:303-309) says ideation should use "No dedup (every idea is unique)" but the methodology always applies dedup (Phase 3). How does the skill know to skip dedup? Is there a `--no-dedup` flag, or does it detect the task type from the schema?

6. **What tool infrastructure is assumed?** The dispatch mechanisms assume various harnesses (OpenCode Go, OpenCode server, direct API). The extraction assumes `marked`/`pandoc` availability. The HTML generation assumes a Node or Python runtime. Is there a minimum environment spec? What happens if `pandoc` isn't installed?

7. **Does the skill itself have tests?** The repo AGENTS.md references `bash tests/run-all-tests.sh` but there's no indication that the multi-ai-task skill has tests. How is the skill validated beyond the one manual research run?

---

## §5. Confidence

- **Overall confidence: Medium**

The review is based on a thorough reading of all 8 files and cross-referencing of claims across them. The issues identified (schema gap for `aggregate: "sum"`, missing `--aliases` mechanism, untested examples, fragile free-form extraction) are supported by specific line citations. Confidence is medium, not high, because:

- **What would change the assessment:** Running the code-review and fact-check examples end-to-end would either confirm that the task-agnostic claim holds (raising confidence to high) or reveal consolidation failures that the current spec doesn't anticipate (requiring new rules, lowering confidence). The untested examples are the biggest unknown — the skill might work perfectly for those task types, or it might break on the first real run. Without evidence, the review can only assess the specification, not the implementation.

---

*End of review. No skill files were modified.*
