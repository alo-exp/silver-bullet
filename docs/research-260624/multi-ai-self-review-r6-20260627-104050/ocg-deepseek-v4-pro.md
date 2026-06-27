I'll start by reading all 8 files in parallel.
Now let me search for cross-cutting patterns to strengthen the review.
Let me check what prior reviews have already covered so I can find new issues.
Now let me verify which prior-review issues remain unfixed vs resolved, and find truly new gaps.
Now I have a clear picture. Let me check one more cross-cutting issue — the output format guidance to models.
I now have all the data needed for a thorough review. Here is the complete critical assessment.

---

# Critical Self-Review: multi-ai-task Skill (Round 5)

**Reviewed version:** 2.1.0 (SKILL.md frontmatter)
**Review date:** 2026-06-27

> **Note:** This is the 5th round of self-review. Prior reviews at `self-review.md`, `critical-review-r3.md`, and `critical-review-r4.md` flagged several issues. Where those issues remain unfixed, I note it explicitly. Where new issues have been introduced or prior reviews missed something, I call that out. The review is self-contained — no prior-review knowledge required.

---

## §1. Critical Assessment

### 1. SKILL.md

**What works well:**
- The when-to-use / when-not-to-use decision table (lines 35-50) is clear, actionable, and honest about tradeoffs.
- The mode semantics table (lines 77-81) compactly explains quick/standard/thorough phase differences.

**What is missing or wrong:**

1. **`user-invocable: false` contradicts the documented CLI usage.** Frontmatter line 5 says `user-invocable: false`, but line 57 shows `/multi-ai-task "<task-prompt>" [--models ...]` — a CLI invocation pattern. In Silver Bullet's skill model, `user-invocable: false` means the skill is callable only via the `skill` tool, not as a slash command. One of these is wrong. If the skill is `user-invocable: false`, the usage line should document tool invocation (e.g., `skill(name="multi-ai-task", ...)`), not a slash command.

2. **Failure modes table (lines 216-228) duplicates `dispatch-mechanics.md:131-140`** with slightly different entries. The "Report partial — only the planning phase" row exists only in dispatch-mechanics.md; the "Output dir contains `score-aggregate.md`" row exists only in SKILL.md. A reader of only SKILL.md has incomplete failure coverage. This is a maintenance hazard — edits to one table will not propagate.

3. **The task-agnostic claim is undermined by having exactly ONE proven task type.** Lines 236-244 describe the research prior-art run as "proven provenance." Lines 210-211 say "The skill itself works for any task." But the code-review and fact-check examples (lines 208-209) both say "Not yet produced (deferred to v2.2.0)" per `rules/examples/code-review.md:111` and `rules/examples/fact-check.md:113`. A skill that claims 5+ supported task types (research, code review, fact-check, ideation, writing critique, translation verification — per lines 13 and 301-308 of consolidation-rules.md) has only ONE end-to-end run.

4. **Version is undocumented.** Frontmatter says `version: 2.1.0` but there is no CHANGELOG.md anywhere in the skill directory. What changed between 2.0.0 and 2.1.0? The fields `--no-auto-inject`, `aliases`, `phases_completed`, `schema_auto_injected`, `consolidation` appear to be 2.1.0 additions but there's no changelog confirming this. The fact-check example at line 77 embeds a changelog fragment in an example file: "`sources: 'url_list'` is now formally defined in the schema spec (was a v2.1.0 gap)."

**What is unclear or ambiguous:**

1. **Default model discovery algorithm is a black box.** Line 73: "queries the local OpenCode config and picks a balanced default set of 4-6 models across the available providers." The selection algorithm is unspecified. If the user has 8 providers each with 3 models (24 total), what subset of 4-6 is chosen? The definition of "balanced" is given in prose but no selection algorithm. This makes runs non-reproducible when `--models` is omitted.

2. **`--mode thorough` cost is described in prose but not in the table.** Line 83 says "thorough mode adds ~N_items × 1 verifier call" but the mode semantics table at line 81 just says "Full + cross-source verification" with no cost column. A user scanning the table encounters a surprise billing at line 83.

---

### 2. rules/methodology.md

**What works well:**
- The 4-phase decomposition is clear and the pseudocode for Mode A/B extraction is concrete enough to implement.
- Fail-soft behavior (partial output from responding models) is well-documented.

**What is missing or wrong:**

1. **Phase 2 Mode A fallback path 2 is dead code with no system prompt configuration.** Line 47-48 says the model "may wrap response in `<structured>...</structured>` if its system prompt asks." But the skill never constructs a system prompt. The auto-injection feature (line 15) only appends a `## Required Output Schema` user-message block, not a system prompt. The `<structured>` tag extraction path is referenced at line 48 but never enabled — no code or instruction tells any model to use these tags.

2. **Extractor model dispatch is underspecified.** Phase 2 Mode A path 3 (lines 52-58) calls `dispatchExtractorModel(response, schema)` — a function with no implementation. What mechanism dispatches the extractor? Is it a subprocess like Mechanism 2? A tool call? Sequential or parallel? The "extractor model" designation says "Default: the slowest/highest-capability model from the original dispatch" (line 104), but "slowest" is unknowable at dispatch time and "highest-capability" is a heuristic with no algorithm. The extractor model is also a **single point of failure**: if it rate-limits or errors, ALL models that need re-extraction fail simultaneously.

3. **The "one-line instruction" for schema auto-injection says the right thing but is fragile.** Line 15: `"Return your answer as a markdown table with exactly these columns, and nothing that does not match this schema"` — this IS appended to the dispatch prompt. But it's a user-message suffix, not a system prompt. Some models may not honor a user-message formatting instruction as reliably as a system-message one. The entire structured extraction pipeline depends on this one line producing a parseable markdown table.

4. **Free-form mode (Mode B) has NO output format instruction at all.** When no `--schema` is passed, the skill does not append any formatting instruction to the dispatch prompt. The extraction code (lines 80-98) assumes H2 headings or paragraphs, but no model is ever asked to use these. A model responding in a code block, bullet list, or raw JSON would fail the H2-based extraction.

**What is unclear or ambiguous:**

1. **The "idempotent re-runs" note is a dangling future feature.** Line 172-173: "the `run-manifest.json` from previous runs can be referenced for incremental consolidation (future enhancement)." No ticket reference, no design sketch, no target version. This raises expectations without commitment and could confuse users who assume the feature exists.

---

### 3. rules/dispatch-mechanics.md

**What works well:**
- Practical, executable shell snippets with real caveats (macOS needs `gtimeout`, Issue #18615, MCP port collision).
- The 4-mechanism hierarchy covers all plausible harness scenarios.

**What is missing or wrong:**

1. **Mechanism 1 is listed as "preferred" but cannot do the skill's core function.** Lines 9-30 describe the `task` tool with pre-configured subagent types as "preferred-if-available." But line 28-30 explicitly states that the `task` tool's schema does not include a `model` field — per-call model selection is impossible. The skill's entire value proposition is dispatching the same prompt to N *different* models. Mechanism 1 requires the user to pre-define one `subagent_type` per model in `opencode.json` — which is strictly more work than Mechanism 2's zero-config approach and offers no additional benefit. Listing it as "preferred" misleads users into a dead-end setup.

2. **Mechanism 3 example is incomplete** (lines 72-87). The code calls `client.session.promptAsync()` and returns the session ID, but never shows how to poll for completion status or retrieve the model's text output. A user implementing Mechanism 3 would need to write the polling/retrieval logic themselves with no guidance.

3. **"Parallel risks MCP port collision" has no mitigation.** Line 68 warns about port collision but the skill provides no port-locking mechanism, no PID file, no detection code, and no `run-manifest.json` field to record a collision event. The user discovers the problem by observing missing output files.

4. **Sequential dispatch process is never shown.** Line 68 says "sequential is safer" but no sequential dispatch code example exists in the file. The only dispatch examples are parallel (`for...do...& done; wait`).

5. **Failure handling table (lines 131-140) partially duplicates SKILL.md:216-228.** The "Report partial — only the planning phase" row (line 135) exists only here. The "Output dir contains score-aggregate.md" row exists only in SKILL.md. See SKILL.md §1 item #2 for the maintenance hazard.

**What is unclear or ambiguous:**

1. **The MCP port collision fix is circular.** Line 113: "Sequential alone doesn't fix port collision if the MCP binds a port on first start and holds it." The fix is "restart the MCP between dispatches." But how does the skill know which MCPs are shared? How does it restart them? This advice is impossible for the skill to action autonomously.

---

### 4. rules/consolidation-rules.md

**What works well:**
- The named rule library (most-severe, majority-with-uncertain, lowest-of-majors, union-dedup, etc.) is the strongest artifact in the skill — each rule has purpose, input contract, algorithm, and edge cases.
- The dedup algorithm pseudocode (lines 97-111) is concrete and implementable.
- The alias map pattern is well-explained with a clear boundary (task-specific, not in core rules).

**What is missing or wrong:**

1. **The 8-dimension scoring rubric referenced by this self-review task is NOT in this file.** The task description for this review says: "Use the skill's own scoring rubric (defined in `consolidation-rules.md` and the prior-art research example)." The rubric lives only in `rules/examples/research-prior-art.md:102-119` under a JSON schema block labeled "optional." If this is the skill's canonical evaluation rubric, it should be in consolidation-rules.md, not buried in a research-specific example.

2. **Aggregation strategy is inconsistent between the rubric JSON and the consolidation rules.** The rubric JSON (research-prior-art.md:117) says `"aggregate": "sum"` with `"max_total": 16`. But consolidation-rules.md:252 says "median" is the default for numeric scores. The narrative in SKILL.md:240 says "median + range per dimension." These are three different aggregation strategies. `sum` of per-dimension scores gives a 0-16 total; `median` of per-dimension scores gives per-dimension medians but no total. Which is canonical?

3. **The `sum` aggregation with `max_total: 16` is mathematically broken when models skip dimensions.** The rubric has 8 dimensions each scoring 0-2. If a model skips a dimension (and the methodology says "If a dimension wasn't scored by any model, use `—`" at line 256), then the sum of scored dimensions is less than 16 but `max_total` remains 16. The total becomes uninterpretable — a score of 8/16 could mean "scored 1 on all 8 dimensions" or "scored 2 on 4 dimensions and skipped 4."

4. **The scoring-matrix header skip rule is heuristic-only.** Line 62-63 says "Skip rows that are scoring-matrix headers (e.g., 'Catalog of composable units')" but provides no algorithm for detecting scoring-matrix headers. The "e.g." leaves implementation to guesswork. A model that writes a research candidate literally named "Catalog of composable units" would be silently dropped.

5. **"Fuzzy match" threshold is ambiguously defined.** Line 131: "Match if normalized titles are ≥80% similar (Levenshtein or token-overlap)." These are different algorithms with different results: Levenshtein is character-based (e.g., "AutoGen" vs "AutoGenX" = ~87% similar by Levenshtein but 50% by token overlap), while token-overlap is word-based. The ambiguity makes dedup non-deterministic across implementations.

**What is unclear or ambiguous:**

1. **Skip rules are described conceptually but not connected to the code.** Line 98 says `if (canonical === null) continue;` but lines 116-121 describe skip rules (placeholders, headers, reference item) without showing how they map to `null`. Is the mapping via alias map (setting `aliases["Candidate"] = null`)? Not stated.

---

### 5. rules/output-schema.md

**What works well:**
- The `run-manifest.json` schema is now complete (confirmed: `schema_auto_injected`, `aliases`, `phases_completed`, and `consolidation` fields are present — fixed after prior reviews).
- The file-header template and section structure are well-defined.

**What is missing or wrong:**

1. **The "canonical schema" claim is misleading.** Line 209: "This is the canonical schema. All other files reference this definition." But `methodology.md:145-147` also says "The canonical schema lives in `rules/output-schema.md`" — which means two files are claiming the same thing, and each points at the other. The duplication creates ambiguity about which file to edit when the schema changes.

2. **Conflict markers are defined only for Mode A (structured table).** Lines 72-75 define a conflict marker legend (`value*` = conflict) only for the schema-defined Items Table (§2A). The Mode B (generic narrative) Items Table (§2B, lines 79-96) has no conflict markers. A user in free-form mode has no visual indication of which values are disputed.

3. **WYSIWYG rule #7 contradicts rule #2.** Rule #2 (line 262): "Add blank line before AND after every table." Rule #7 (line 269): "Wrap tables in clean code blocks when rendering for the web." Code blocks disable GFM table rendering — the table becomes monospaced text, not a rendered table. These rules are mutually exclusive for web viewers.

4. **The code-review output sections are incomplete.** The code-review example (lines 82-90) claims the output includes §5 "Per-Reviewer Statistics" and §6 "Coverage Gaps" — neither of which appears in output-schema.md's section listing (lines 39-168, which goes from §1 to Appendix B). The output schema document is not kept in sync with per-task-type additions.

**What is unclear or ambiguous:**

1. **The `aliases` field type in `run-manifest.json` is untyped.** Line 251: "task-specific alias map applied during dedup" — but the JSON example (line 224) shows `"aliases": {"AutoGen/AG2": "AutoGen"}` (an object). Is a flat `{}` valid? Can values be `null` (for skip rules)? The field semantics don't specify valid types or values.

---

### 6. rules/examples/research-prior-art.md

**What works well:**
- Complete end-to-end example: prompt, schema, dispatch script, alias map, skip rules, expected output.
- The alias map is annotated with commentary (why each alias exists), making it self-documenting.
- The only **proven** example in the skill — it has a real run to reference.

**What is missing or wrong:**

1. **Aggregation strategy in the scoring rubric JSON contradicts the methodology.** Line 117: `"aggregate": "sum"` with `"max_total": 16` says to sum dimension scores. But the narrative (SKILL.md:240) and consolidation-rules.md:252 both say median. See consolidation-rules.md §1 item #2 for full analysis.

2. **The dispatch script diverges from the canonical Mechanism 2.** The script at lines 14-33 is an older copy of dispatch-mechanics.md Mechanism 2 but:
   - It's missing the `TIMEOUT` enforcement (no `timeout`/`gtimeout` wrapping).
   - It doesn't reference or link to dispatch-mechanics.md.
   - If dispatch-mechanics.md is updated, this script silently drifts. The example should say "See `rules/dispatch-mechanics.md` Mechanism 2" instead of duplicating the code.

3. **Skip rules classified as "research-specific" but also listed as "generic."** Line 148: "Skip rules (research-specific)" includes "The reference subject's own name." But consolidation-rules.md:118 already lists "The reference item itself" as a generic skip rule. This rule appears in both "generic" and "research-specific" categories, creating ambiguity about where it should be defined.

4. **`"primary_key": "name"` at schema top-level contradicts the code-review example.** Line 75 uses `"primary_key": "name"` as a top-level schema field. But code-review.md:70 says "The string-form `primary_key` is not a recognized schema field." Both cannot be correct. The SKILL.md schema example (lines 96-97) also uses `"primary_key": "item"` — suggesting `primary_key` IS valid, and the code-review example's assertion is incorrect.

**What is unclear or ambiguous:**

1. **The "diminishing returns past 6" claim is explicitly non-evidence.** Line 182: "diminishing returns past 6 (this is an empirical observation, not a measured curve — run your own benchmark if you want a hard number)." This is advice presented as empirical but marked as unmeasured. Either remove the claim or run the benchmark. A self-disclaiming claim is not useful.

---

### 7. rules/examples/code-review.md

**What works well:**
- Clear composite-key example with `file`+`line` dedup — correctly uses `dedup_key: true` on both columns.
- Explicitly flags the old buggy syntax (`"primary_key": "file:line"`) and shows the correct alternative.
- The custom strategies table (lines 93-101) maps fields to rules with rationale.

**What is missing or wrong:**

1. **No worked example exists.** Line 111: "Not yet produced (deferred to v2.2.0)." This is the second-most-important task type for the skill (code review) and it has zero proven runs. The `--dangerously-skip-permissions` security note (lines 46-48) claims code review is read-only and safe without the flag, but this claim is untested.

2. **The `primary_key` assertion is wrong.** Line 70: "The string-form `primary_key` is not a recognized schema field." But SKILL.md lines 96-97 and research-prior-art.md line 75 both use `"primary_key": "name"` as a top-level schema field. SKILL.md:142-143 says "Composite primary keys: list multiple columns with `dedup_key: true`" — this means `primary_key` IS the single-column form and `dedup_key: true` on multiple columns IS the composite form. The code-review example's assertion contradicts the skill's own spec.

3. **Output sections claimed (lines 82-90) are not defined in output-schema.md.** §5 "Per-Reviewer Statistics" and §6 "Coverage Gaps" appear in the code-review example's output description but have no corresponding section template in output-schema.md. The output schema doc is incomplete for code-review use cases.

4. **Custom strategies table says `evidence: "concatenate-all"` but the schema doesn't declare it.** Line 99 says evidence should use `concatenate-all`, but the schema JSON (lines 50-65) has no `conflict_resolution` entry for `evidence`. The custom-strategies table prescribes behavior the schema doesn't enforce.

**What is unclear or ambiguous:**

1. **"Pre-commit hook" variation is documented as "NOT currently supported."** Line 106: "Pre-commit hook: combine with git diff to only review changed lines (NOT currently supported as a built-in dispatch; requires custom runner)." If it's not supported, why document it in the "variations" section? This is either a feature request or noise — neither belongs in a reference example.

---

### 8. rules/examples/fact-check.md

**What works well:**
- Good explanation of `majority-with-uncertain` rationale for high-stakes verification.
- Consensus thresholds (lines 102-109) are parameterized with clear N→threshold mapping.

**What is missing or wrong:**

1. **No worked example exists.** Line 113: "Not yet produced (deferred to v2.2.0)." Same gap as code-review — the fact-check use case is untested.

2. **Line 77 embeds a changelog entry in an example file:** "`sources: 'url_list'` is now formally defined in the schema spec (was a v2.1.0 gap)." This is changelog information embedded in an end-user example. If the schema spec was updated to include `url_list`, that belongs in a CHANGELOG.md. The example file should document usage, not version history.

3. **Line 109 documents a typo fix:** "The '3+ models' rule in the original draft was a typo; the correct threshold is parameterized." This is self-referential version archaeology. The current reader doesn't need to know about a typo in a prior draft — this is noise in a reference document.

4. **The `confidence: "lowest-of-majors"` rule has an implausible edge case not documented.** Line 188-191 says "if only 1 model voted for the majority value, return its confidence unchanged." But if 1 model voted and that was enough for majority (e.g., N=1 or all other models disagreed), the confidence of that single model may be artificially high ("high") while the consensus is actually weak. The rule should flag this as low-confidence when N_minority > 0.

**What is unclear or ambiguous:**

1. **Consensus thresholds (lines 103-108) reference "high confidence" but the schema doesn't define what constitutes "high."** The schema has `confidence: ["high", "medium", "low"]` but the threshold prose says "high confidence + primary source." Should the confidence aggregation consider whether the confidence is `high`? The `lowest-of-majors` rule handles confidence aggregation, but there's no connection between that rule and the "confirmed" / "debunked" thresholds.

---

## §2. Score the Skill on the 8-Dimension Rubric

**Scoring methodology:** Each dimension scored 0-2 against the rubric defined in `research-prior-art.md:102-119`. The rubric levels are: 0 = none/broken, 1 = partial/informal, 2 = complete/formal.

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | **Catalog of composable units** | **2** | The named rule library (most-severe, majority-with-uncertain, lowest-of-majors, longest-with-quote, concatenate-all, all-collected, union-dedup, merge-exact) and the column type system (string, number, boolean, enum, url, url_list, date, text) form a machine-readable catalog. Both are formally defined with algorithms and edge cases. |
| 2 | **Dynamic composition** | **2** | Models are composed dynamically at runtime (auto-discover from config, or explicit `--models` list). Consolidation rules are selected per-field via `--schema`. The `run-manifest.json` provides an audit log of the composition. The alias map enables runtime dedup customization. |
| 3 | **V-loop depth** | **1** | The 4-phase pipeline has `phases_completed` tracking and reports partial failures. The `thorough` mode adds cross-source verification with per-claim evidence-ledger. However, there is no per-item rollup gate — if 30/36 items are fine but 6 have unresolvable conflicts, the run completes with no quality gate blocking. You cannot roll up at the per-item level; consolidation succeeds or fails as a block. |
| 4 | **Enforcement** | **1** | The skill enforces schema constraints at extraction time (required fields, type ranges, enum values) — this is CI-level enforcement (parse-and-reject). But there are no IDE hooks, no pre-commit integration, no delivery blockers. The skill cannot prevent a bad `consolidated.md` from being published or acted upon. |
| 5 | **Parent/worker split** | **2** | Explicit orchestrator (the skill's 4-phase pipeline) / worker (N dispatched models) split. The parent handles extraction, consolidation, and synthesis; workers produce raw responses. Boundary is clear: models don't know about each other; the orchestrator manages all cross-model logic. |
| 6 | **Evidence model** | **2** | In thorough mode: `evidence-ledger.md` + per-item `source_verified: true|false|wrong` flags are tiered sufficiency. In standard mode: conflict resolution uses "primary source quote wins" and recency (`last_verified`) as evidence heuristics. Staleness is tracked via date comparison rules. |
| 7 | **SE + DevOps unified** | **2** | The skill handles software engineering (code review: file, line, severity, bug/security/perf/style/design/test categories) and DevOps-adjacent tasks (fact-check with source verification, evidence-ledger with URL citations). Both task types use the same consolidation model — same schema format, same named rules. |
| 8 | **Team customization** | **1** | The `--schema` parameter and custom conflict resolution rules allow per-run customization without forking the skill. Alias maps are task-specific and documented in `run-manifest.json`. However, there is no "overlay packs" concept — you cannot compose multiple customization profiles, cannot share schemas as reusable presets, and cannot apply a team's standard schema library across runs without copy-pasting the JSON each time. |

**Total: 13/16**

---

## §3. Top 5 Improvements (ranked by impact × effort)

### #1. Add output format instruction for free-form mode

- **Issue:** When no `--schema` is passed, models receive zero formatting guidance. The extraction code assumes H2 headings or paragraphs, but models are never asked to use these.
- **Why it matters:** Free-form mode is the default when the user doesn't pass `--schema`. Without a formatting instruction, extraction is unreliable and the fallback paths (extractor model re-parse, paragraph split) are costly and lossy for every model.
- **Concrete change:** In `rules/methodology.md` after line 15 (the auto-injection prose), add a parallel block:

```markdown
**Free-form formatting instruction (when no --schema):** the skill appends a
`## Output Format` block to every dispatch prompt: "Return your answer as 
markdown with one ## H2 heading per item. Each item section should contain the
item name, description, and any URLs or evidence. Use blank lines between
paragraphs."
```

- **Effort:** Low (add ~5 lines of documentation + ensure implementation appends the block)
- **Impact:** High (reduces extraction failures in free-form mode, the default path)
- **Score:** High/Low

### #2. Fix aggregation strategy inconsistency

- **Issue:** The research example's scoring rubric says `"aggregate": "sum"` but consolidation-rules.md says median is the default for numeric scores, and SKILL.md:240 says "median + range per dimension" was used.
- **Why it matters:** Two implementations following different docs will produce different total scores for the same input. The `sum` variant is also mathematically broken when models skip dimensions (total < max_total → uninterpretable).
- **Concrete change:** In `rules/examples/research-prior-art.md:117`, change:
  ```json
  "aggregate": "sum",
  "max_total": 16
  ```
  to:
  ```json
  "aggregate": "median",
  "max_total": 16
  ```
  and add a note at line 119:
  ```markdown
  **Aggregation note:** Per-dimension scores use median across models.
  The TOTAL column is the sum of per-dimension medians (max 16). If a
  dimension is unscored by all models, it contributes 0 to the total.
  ```
- **Effort:** Low (two line changes in one file)
- **Impact:** Medium (avoids incorrect scoring for research tasks)
- **Score:** Medium/Low

### #3. Fix Mechanism 1 ordering and labeling

- **Issue:** Mechanism 1 is listed as "preferred-if-available" but cannot do the skill's core function (dynamic per-call model selection). Users who follow the "preferred" path hit a dead end.
- **Why it matters:** The first dispatch mechanism a user reads should be the one that actually works without pre-configuration. Mechanism 2 is the proven, zero-config option. Mechanism 1 should be labeled as a config-heavy alternative, not "preferred."
- **Concrete change:** In `rules/dispatch-mechanics.md`:
  - Line 9: Change `### Mechanism 1: Native task tool with pre-configured subagent types (preferred-if-available)` to `### Mechanism 1: Native task tool with pre-configured subagent types (config-heavy; requires per-model agent definitions)`.
  - Swap Mechanism 1 and Mechanism 2 ordering (make Mechanism 2 the first listed).
  - Line 183: Update the "Choosing the right mechanism" table to reflect the re-ordering.
- **Effort:** Low (relabel + reorder, ~5 line changes)
- **Impact:** Medium (prevents user confusion at the entry point)
- **Score:** Medium/Low

### #4. Resolve `primary_key` schema field contradiction

- **Issue:** SKILL.md:96-97 and research-prior-art.md:75 use `"primary_key": "name"` as a top-level schema field. But code-review.md:70 says "The string-form `primary_key` is not a recognized schema field." One of these is wrong.
- **Why it matters:** An implementer reading the code-review example would avoid using `primary_key` (thinking it's invalid), then find it's used in both the research example and SKILL.md — causing confusion about which schema format is correct.
- **Concrete change:** In `rules/examples/code-review.md:70-71`, change:
  ```markdown
  **Why the old `"primary_key": "file:line"` is wrong:** the skill spec says 
  composite keys are expressed by listing multiple columns with 
  `dedup_key: true` — not by concatenating strings. The string-form 
  `primary_key` is not a recognized schema field.
  ```
  to:
  ```markdown
  **Why `"primary_key": "file:line"` is wrong for composite keys:** the top-level 
  `primary_key` field names a single column as the dedup key. For composite 
  keys (file + line together), list multiple columns with `dedup_key: true` 
  instead of concatenating column names with `:`. See SKILL.md:142-143.
  ```
- **Effort:** Low (~6 line change, clarification only)
- **Impact:** Medium (removes a direct contradiction between reference documents)
- **Score:** Medium/Low

### #5. Add circuit breaker for large-N consolidation

- **Issue:** The dedup algorithm (consolidation-rules.md:97-111) processes all rows in a single pass with registry lookups, but fuzzy matching (when no schema) is O(N²) per pairwise comparison. With 10 models each producing 80 items (800 rows), the fuzzy match could attempt ~320,000 pairwise comparisons.
- **Why it matters:** Without an upper bound, a large dispatch (N=10 models, verbose prompts) can cause minutes of CPU-bound work or even OOM. There is no batching strategy, no degradation mode, and no warning.
- **Concrete change:** In `rules/consolidation-rules.md`, after line 133 (the fuzzy match section), add:
  ```markdown
  **Circuit breaker:** If total items across all models exceeds 500, 
  fuzzy matching is disabled and exact-match-only dedup is used. 
  The run-manifest.json records `fuzzy_match_disabled: true` with the 
  reason. For large-N runs where fuzzy matching is required, increase 
  the threshold by setting `N_ITEMS_FUZZY_LIMIT` higher (trade CPU for accuracy).
  ```
- **Effort:** Medium (design + implementation of threshold + degradation path)
- **Impact:** Medium (prevents pathological performance but rare in practice)
- **Score:** Medium/Medium

---

## §4. Open Questions

1. **What is the skill's target audience?** The frontmatter says `user-invocable: false` (skill-tool-only), but the documentation is written for CLI users (`/multi-ai-task ...`). Is the skill designed for end-users running dispatches, or for agent orchestrators programmatically invoking it? The tone and content differ significantly between these audiences.

2. **What is the security classification model?** The dispatch notes say "for read-only tasks, use `--dangerously-skip-permissions`" and "for write tasks, do NOT." But the skill defines no taxonomy for classifying a task as read-only vs write. Research (web fetches, disk writes to output dir) is treated as read-only, but both involve resource access. Where is the line?

3. **What happens to the extractor model if it fails?** Phase 2 Mode A path 3 (`dispatchExtractorModel`) is a single point of failure. If the designated extractor model rate-limits or times out, all models whose responses need re-extraction fail simultaneously with no fallback.

4. **How does the default model discovery actually work?** The "balanced set of 4-6 models" selection algorithm is unspecified. Without knowing the algorithm, runs that omit `--models` are non-reproducible.

5. **What is the compatibility contract between skill versions?** v2.0.0 added `phases_completed`, v2.1.0 added `schema_auto_injected` and `aliases` to `run-manifest.json`. Can a v2.0.0 consolidation tool consume v2.1.0 output? Is `run-manifest.json` forward-compatible? Without a CHANGELOG or compatibility statement, consumers cannot safely upgrade.

6. **How are code-review §5 (Per-Reviewer Statistics) and §6 (Coverage Gaps) defined?** These sections are claimed in the output description but have no template in output-schema.md. Are they mandatory for code-review tasks? Optional? Schema-driven?

7. **Should the 8-dimension scoring rubric be part of the skill core?** The rubric currently lives in a research-specific example but is used for the skill's own self-review. If the rubric is canonical to the skill (for assessing any task's quality), it should live in consolidation-rules.md. If it's task-specific, the self-review task shouldn't claim it's "the skill's own scoring rubric."

---

## §5. Confidence

- **Overall confidence:** **Medium**

- **What would change your assessment:** A second worked example (code-review on a real file, or fact-check on real claims) would raise confidence to **high** by proving the skill generalizes beyond research. Conversely, discovering that the structured extraction table parser fails on real model output formats (which are often inconsistently formatted) would lower confidence to **low** — the entire skill rests on reliable extraction from markdown tables, and the current proof is based on one 6-model research run where all models produced compatible output. One bad table format from a model would cascade through the fallback pipeline and potentially produce garbage.
