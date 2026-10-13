I'll read all 8 files in parallel and then provide the critical self-review.
I have enough context. Note: this is the 5th+ self-review cycle on this skill — `self-review.md`, `critical-review-r3.md`, `critical-review-r4.md`, and `critical-review-r5.md` already exist in the same directory. Several issues I'll flag were already raised in R3/R4/R5 and not fixed. I'll mark those so this review is layered on prior work, not redundant.

# Critical Self-Review: `multi-ai-task` v2.1.0

## §1. Critical Assessment

### 1. `SKILL.md` (286 lines)

**What works well**
- "When to use / When NOT to use" table (lines 34-49) is genuinely well-scoped — six pairs of use/not-use cases that match real decision points. No padding.
- "Mode semantics" table (lines 76-83) cleanly maps `quick`/`standard`/`thorough` to phase behavior. The wall-time estimate ("~3-5 min sequential or ~1 min parallel") is concrete and honest.
- Failure-modes table (lines 247-256) gives specific symptoms + causes + fixes, not generic advice.

**What is missing or wrong**
- **Schema-injection docs are scattered across 3 places.** Line 23 mentions `--no-auto-inject`; lines 67-69 mention it in the inputs table; lines 85-155 have a full "The `--schema` parameter" section. A reader can't find the auto-inject opt-out without scanning. Worse, the example schema at line 98-112 is defined inline in the `--schema` section but the auto-inject mechanics aren't shown there — the docs say "appends a `## Required Output Schema` block" but the example of that block is missing.
- **`dedup_key: "secondary"` is defined but unimplemented.** Line 144: `dedup_key: "secondary" | Tiebreaker after primary key`. The dedup algorithm in `consolidation-rules.md:95-110` has no concept of "secondary" — composite keys use multiple `dedup_key: true` columns, not a primary + secondary. A user who writes `"dedup_key": "secondary"` will get silently incorrect behavior.
- **`-y` / `--y` typo in dispatch-mechanics.md:65 is referenced by this file.** SKILL.md:65-69 references the dispatch script; the script has the typo. Confirmed below in §3.
- **The `type` column constraint contradicts the free-form mode.** Line 132: `"type" — Always "table" (the only currently supported shape)`. But Mode B (line 158) explicitly supports free-form (no schema). The constraint is only true for `--schema` mode, but the docs say "Always".
- **`task_prompt_hash` in run-manifest is described at output-schema.md:241 but the field has no implementation guidance.** What does the hash include? The prompt only, or the prompt + schema + flags? SHA-256 of UTF-8 bytes? Not specified.

**What is unclear or ambiguous**
- "**Auto-discover (see below)**" (line 65) — the "see below" is the "Default model discovery" section at line 71-73, which queries `~/.config/opencode/opencode.json` + `.jsonc`. But the skill claims harness-agnosticism (Mechanism 4 in dispatch-mechanics.md is for non-OpenCode). What happens if there's no OpenCode config? What if the user is on a different harness? This is open-coded to one vendor.
- The "Provenance" section (lines 264-279) describes the 2026-06-27 run but doesn't link to `run-manifest.json` for that run. A reader has to find it. The "Folder-name note" about `docs/research-260624/` (which encodes `2026-06-24` while the run was `2026-06-27`) is a documented "don't fix" anti-pattern — pragmatic, but it sets a precedent for tolerating date/path drift.
- The "self-review run" lineage at line 278 is recursive ("the skill used to review itself... A round-2 self-review... is at..."). This is the 5th+ iteration of self-review (see `self-review.md`, `critical-review-r3.md`, `critical-review-r4.md`, `critical-review-r5.md` in the same directory). The recursive references should probably be consolidated into one provenance note rather than chained.

### 2. `rules/methodology.md` (173 lines)

**What works well**
- The 4-phase pipeline is small enough to hold in head. The "Cross-cutting principles" section (lines 150-173) is honest about audit trail, hybrid LLM/deterministic, and idempotency.
- The `extractStructured` pseudocode (lines 36-65) handles 4 fallback paths (table parse, structured tags, extractor model, paragraph split). Better than most skill specs.

**What is missing or wrong**
- **Phase numbering is inconsistent with `consolidation-rules.md`.** methodology.md uses Phase 1-4 (dispatch / extract / consolidate / synthesize). consolidation-rules.md uses Phase 2-5 (Align / Dedup / Resolve / Score+Synthesize). Same content, different numbering. The `phases_completed` field in `run-manifest.json` (output-schema.md:235) is supposed to track these phases — but the manifest's example shows `[1, 2, 3, 4]` and the consolidation doc uses 2-5. A user cross-referencing the two files will be lost. **This was flagged in R3 review and not fixed.**
- **The "thorough mode" verifier is not in the methodology.** SKILL.md:81 describes thorough mode as "for each canonical item, dispatch a verifier model". output-schema.md:185-203 documents `evidence-ledger.md` and `verification.md`. But methodology.md has no Phase 5 (or extended Phase 4) for the verifier dispatch. The workflow to produce those files is missing from the methodology entirely.
- **The "extractor model" is documented but not parameterized.** Line 53-58: "extractor model" = "the slowest/highest-capability model from the dispatch". This is a heuristic that requires all dispatches to finish before it can be determined. There's no `--extractor-model` flag, no deterministic default. The user can't pin one.
- **"Idempotent re-runs" section (lines 169-170) is misleading.** The heading promises idempotency. The next sentence says "does NOT cache across runs by default". So the section describes non-idempotency. The heading should be "Non-idempotent by default; re-run produces a fresh run" or the text should be removed.
- **"Deterministic + LLM-assisted hybrid" (line 156) overstates determinism.** Mode B (free-form) and the extractor-model path are LLM-assisted. The hybrid is real, but the "deterministic" label suggests more stability than the system provides.

**What is unclear or ambiguous**
- "The exact prompt sent" is listed in the audit trail (line 165) but is only stored as `task_prompt` in `run-manifest.json`. The *exact* prompt that reached each model (with auto-injection applied) is not stored separately. If auto-injection was on, the audit trail conflates the user's prompt with the augmented one. **This is a real audit gap.**
- "**It does NOT cache across runs by default**" (line 170) — but the manifest's `task_prompt_hash` field (output-schema.md:241) is described as "useful for cache lookup". So a cache is anticipated, but not implemented. The relationship between "no cache" and "cache lookup via hash" is unexplained.

### 3. `rules/dispatch-mechanics.md` (188 lines)

**What works well**
- The 4 mechanisms in preference order (Mechanism 1 → 4) with explicit trade-offs. The "Parallel vs sequential" table (lines 105-111) is a real decision tool.
- The "Known bug" annotations (Mechanism 1: missing `model` field in `task` tool, Mechanism 3: Issue #18615) are honest about harness limitations.

**What is missing or wrong**
- **`-y` typo on line 65.** The text says: "**`--y`** in `npx -y opencode-ai run` skips the install prompt; without it, background subprocesses may hang." The `npx` flag is `-y` (one dash). The bolded version has two dashes. This will mislead any reader who copy-pastes the bold text. **Trivial to fix, real bug.**
- **Mechanism 1 is "preferred-if-available" but the constraint at line 28 is a blocker for 95% of users.** "the `task` tool's `Parameters` schema... does **not** include a `model` field... the user must pre-define one subagent_type per model in `opencode.json`". So Mechanism 1 requires N pre-configured agent types. The "preferred" label is misleading — Mechanism 2 (default) is the only practical option unless you've already done significant harness config.
- **The MCP port-collision workaround at line 113 is not really a fix.** "(b) dispatch to a single model at a time AND restart the MCP between dispatches" — who restarts MCPs between dispatches? The user? The skill? Not specified. This is a documented-but-impractical workaround.
- **Issue references are given as bare numbers without links.** Line 28: "issues #6651, #11215, #17595, #26925, #29984, #32730... one open PR (#29447)". Line 88: "[Issue #18615]". A reader has to manually construct GitHub URLs.
- **"Per-model output capture" section (lines 117-124) doesn't explain where the CWD is.** "Always check the model's CWD for stray `*.md` files" — but the model is invoked via `npx opencode-ai run` in a subprocess. Is CWD the shell's CWD? The `--title` working dir? The user's home? The `OUT` variable? Not specified.

**What is unclear or ambiguous**
- "MCP port collision" (line 113) is mentioned but never explained. Which MCPs? Is this OpenCode-specific? A general issue? A reader with no MCP experience gets no foothold.
- Failure-handling table (lines 131-140) is a near-duplicate of the one in SKILL.md:247-256. **Drift risk** — when one is updated, the other won't be.
- "Long-running tasks (10+ min each)" threshold (line 109) — where does 10 come from? Empirical? Arbitrary? The proven 6-model run took 2-3 min/model (line 111) — 10 is 3-5x that. The threshold feels invented.

### 4. `rules/consolidation-rules.md` (335 lines)

**What works well**
- The named rule library (`most-severe`, `majority`, `majority-with-uncertain`, `lowest-of-majors`, `longest-with-quote`, `concatenate-all`, `all-collected`, `union-dedup`, `merge-exact`, `prefer-with-evidence-then-newer-then-strict`) is the genuine value of this skill. Each rule has an algorithm, edge cases, and an example. This is implementable code, not aspiration.
- The `How to document resolutions` example (lines 226-235) gives a concrete `conflicts.md` row format.

**What is missing or wrong**
- **`allow_downgrade` is documented at line 170 but not in the schema spec.** Code-review.md:73-77 references `severity_order` in `conflict_resolution`. consolidation-rules.md:170 references `allow_downgrade` in the schema. Neither field is in the schema field table at SKILL.md:96-112. A user implementing the code-review recipe will write `"severity_order": [...]` and get a silent error or silent ignore. **Flagged in R3:70 and R5:81, not fixed.**
- **The `most-severe` rule's prose structure is confusing.** Line 171: "if 1/N reviewers says `blocker` and all others say `major`... and the lone `blocker` has no evidence quote, the schema may declare `allow_downgrade: true` to downgrade the lone max to the next-severity tier. **Default: `allow_downgrade: false`** — the most-severe value wins even if only 1 reviewer reported it." The edge case (downgrade option) is described *before* the default (no downgrade). A skimming reader will think the default is to downgrade. The next sentence tries to recover ("This matches the code-review safety principle..."). Rewrite to lead with the default. **Flagged in R3:227, not fixed.**
- **The `prefer-with-evidence-then-newer-then-strict` rule name contains "strict" but the steps don't define it.** Lines 156-162. Steps are: quoted source → newer last_verified → outlier downgrade → tie-break by evidence+recency. "Strict" appears nowhere. The name suggests a "strict mode" that isn't defined. Either rename to `prefer-with-evidence-then-newer-then-outlier` or document what "strict" means.
- **The "outlier rule" at line 160 is a magic number.** "If 1 of 6 models says `direct` and 5 say `adjacent`, treat the lone `direct` as an outlier (downgrade)." — but is 1-of-6 the threshold? 1-of-5? 1-of-3? 2-of-5? The rule doesn't define the threshold or its justification. A 2-of-6 situation is not addressed.
- **`merge-exact` references "composite pattern" (line 222) that isn't defined.** "if the primary key is malformed (doesn't match the schema's composite pattern), log and skip the entry." But the schema spec only says "list multiple columns with `dedup_key: true`" (SKILL.md:151). There's no pattern (regex? range? lookup table?) to match against. So "malformed" is undefined.
- **The `—` character in the score-conflict section (line 257) contradicts output-schema.md:265.** consolidation-rules.md says "use `—`" for missing scores. output-schema.md says "Avoid unicode in cells when possible. `—` → `--`". Internal contradiction.
- **`lowest-of-majors` edge case: what if there's no majority?** Lines 188-191. "first apply `majority` to get the majority value; then among the models voting for that value, return the lowest confidence." But `majority` returns `null` when no value wins (line 178). What does `lowest-of-majors` return when `majority` returns null? Not specified.
- **The `version` disagreement rule (line 261-263) is an LLM call, not a deterministic rule.** "For version-number disagreements, use the **newer** `last_verified` date. Confirm against the official release page." — "Confirm" requires an LLM (or web fetch). This contradicts the "Deterministic + LLM-assisted hybrid" claim in methodology.md:156.
- **The "extractor model" cost claim at methodology.md:104 says "one additional LLM call per model whose structured extraction failed" — but a single model with N failed extractions triggers N calls, not 1.** Re-reading: "Cost: one additional LLM call per model whose structured extraction failed (paths 1 and 2 in the pseudocode)." — actually the pseudocode has paths 1, 2, 3, 4. Path 3 is the extractor call. If path 1 fails, try path 2; if path 2 fails, try path 3 (one extractor call per model). So "one additional LLM call per model" is correct. OK.
- **The alias map is described as "task-specific, not part of this skill's core" (line 328) but the manifest has an `aliases` field (output-schema.md:251).** Where is the alias map loaded from at runtime? Is it in the schema? In a separate file? In a CLI flag? None of `--schema`, `--aliases`, or any other mechanism is described for the alias map. **Real gap.**

**What is unclear or ambiguous**
- The relationship between the alias map and skip rules is muddled. Line 116: "Mark a row's primary key as `aliases[n] = null` to drop it from the registry." But the research example's skip rules (research-prior-art.md:144-149) include rules like "drop the reference subject's own name" — those aren't in the alias map. Are task-specific skip rules in the alias map, or in a separate field? The docs say "Generic skip rules for any task type" (line 114) and "Task-type-specific skip entries belong in the alias map for that task's recipe, not in the core rules" (line 121). But the example skip rule for "scoring-matrix header rows" is in the alias map (research-prior-art.md:148). Contradiction.
- `lowest-of-majors` — what does "lowest confidence" mean for confidence expressed as a number? The rule example (line 190) treats it as ordinal ("`high > medium > low`"). But the fact-check schema (fact-check.md:62) declares `confidence: enum ["high", "medium", "low"]`. OK, ordinal. But what if a future schema uses numeric confidence? The rule's algorithm is silent on this.
- "longest-with-quote" (line 196-198) requires "at least one inline quote (e.g., `"..."`)". What counts as an inline quote? Single quotes? Curly quotes? Markdown blockquotes? Block code? The rule is informal.

### 5. `rules/output-schema.md` (270 lines)

**What works well**
- The 7 markdown formatting rules at the end (lines 258-269) are practical and address real WYSIWYG viewer bugs. The `—` → `--` and `→` → `->` substitutions are concrete.
- Mode A vs Mode B (lines 7-19) is a clean separation. The user can pick the schema-driven or free-form path without ambiguity.
- The "run-manifest.json" example (lines 211-237) has 15+ fields with semantic descriptions. This is the most formal schema spec in the skill.

**What is missing or wrong**
- **The "Source reports" line 32 has no schema.** "size in KB / line count" — is this a string like "12 KB / 150 lines" or a structured `{size_kb: 12, line_count: 150}`? The spec doesn't say.
- **The `Source reports` list is a header concern but the per-model raw files (`<model-slug>.md`) are listed in the same line as the model-slug-vs-model-id distinction.** Line 31: "`<model-slug>.md` — <model-id> (size in KB / line count)". The hyphen-and-space between slug and model-id suggests a single string, but it's two fields. Format is implicit.
- **Conflict marker is ambiguous.** Line 72: "**Conflict marker:** `value*` = field conflict: at least one model disagreed." But line 75 says: "(Use a code-span like `` `direct*` `` if your viewer is WYSIWYG-strict; bare `*` otherwise.)" — two recommendations. Then line 262 (the WYSIWYG rule): "**Use code spans (backticks), not bold-italic, for inline markers.**" So the recommendation is code-spans. The parenthetical at line 75 contradicts this. Pick one.
- **§3 "Per-Item Details" (lines 100-115) is a template, not a schema.** The examples are research-flavored (`gaps_vs_reference`, `reference_gaps_vs_them`). A code-review user has to invent their own format. The "Be specific. Not 'less mature' but 'lacks V-model rollup; has BPMN catalog'." is advice, not structure.
- **§5 "Aggregated Scores" is "optional" (line 130) but research-prior-art.md:159 lists it as part of the output.** "Optional" is not defined — does it mean "if applicable", "if requested", "if data exists"? All three.
- **The `evidence-ledger.md` and `verification.md` schemas (lines 183-203) are example rows, not formal field definitions.** No required/optional, no types, no validation rules. R5:92 noted this — not fixed.
- **"Coverage: M unique items / P raw mentions / Q aggregations" (line 29) — what is "Q aggregations"?** Not defined anywhere. The research example aggregates scores (line 159), but the manifest's `consolidation.score_aggregations` (line 232) is a count, not a list. The header is informal.
- **`task_prompt_hash` (line 241) — what is hashed?** The prompt bytes? The prompt + schema + flags + timestamp? The hash is a deterministic cache key, but the input is unspecified.
- **`phases_completed` (line 254) is underspecified.** "list of phase numbers that produced output (for partial-failure auditing)". But "produced output" is undefined. A phase that errored? A phase that returned empty? A phase that succeeded with 0 items? The audit story is vague.
- **`schema_provided` and `schema_auto_injected` fields (lines 244-245) are both "v2.1.0+" but only `schema_auto_injected` has the version annotation.** `schema_provided` has been around since v1 (probably). Why the asymmetric annotation? Sloppy.
- **`source_refs` example line format (`minimax-m3.md#L42-50`) is not defined.** The format is repeated across SKILL.md, methodology.md, output-schema.md. Is it `L<start>-<end>`? Can it be `L<line>` for single-line? Can it be `L<start>-<end>:H42` for a header at line 42? Unclear. No grammar is given.

**What is unclear or ambiguous**
- The "Source reports" list at line 31 — who generates it? Is the skill responsible for emitting this list in the header, or is it user-injected? Not specified.
- The "All delimiter rows must start and end with `|`" rule (line 266) is for safety, but the §4 example table at lines 121-125 uses `|---|` — fine. But the conflicts.md example at consolidation-rules.md:228-234 uses `|---|---|`. Both comply. OK.
- The "Header cells must equal body cell count" rule (line 267) is a constraint but the skill itself produces tables in 4+ places (consolidated.md, conflicts.md, evidence-ledger.md, verification.md). Is this a hard requirement? A warning? A test? The spec is silent.

### 6. `rules/examples/research-prior-art.md` (185 lines)

**What works well**
- Concrete example with real artifacts (paths to the 2026-06-27 run). 14-entry alias map that catches real research variants (AutoGen/AG2, MAF/Microsoft Agent Framework).
- The "Variations to try" section (lines 181-185) is honest: "Add more models" says "diminishing returns past 6 (this is an empirical observation, not a measured curve — run your own benchmark if you want a hard number)".

**What is missing or wrong**
- **The dispatch script uses 6 specific models with no fallback.** Lines 22-32. If the user has fewer than 6, they have to edit. If a model is unavailable at run time, the script doesn't substitute.
- **The schema has `se_fit` and `devops_fit` columns (lines 84-85) but the example is research, not DevOps.** The columns are research-task-specific, not task-agnostic. A code-review or fact-check user wouldn't want these columns. The example doesn't generalize.
- **The scoring rubric "aggregate": "sum" (line 117) doesn't match the per-dimension "median" aggregation in consolidation-rules.md:256.** The chain is "median per dimension, then sum of medians" — but the skill docs both. The chain is implicit.
- **"Scoring rubric" lines 107-118 is a research-specific 8-dimension rubric.** It's the rubric used to score research candidates, not a generic multi-ai-task rubric. The example conflates "the skill's task-agnostic framework" with "one specific research-task scoring framework". A user reading the example might think the 8-dimension rubric is part of the skill. It's not — it's a research-specific input.
- **The "Earthly Lunar" alias (line 137) is suspicious.** Should "Earthly" and "Earthly Lunar" be merged? The alias map only lists "Lunar → Earthly Lunar", not "Earthly → Earthly Lunar". A user who provides "Earthly" as a primary key won't get the same canonical name as "Lunar".
- **The "Coverage Scoreboard" line 188-189 is in output-schema.md as a generic section, but the example doesn't show what "bucket" means in the research context.** "Bucket" is research-specific (e.g., "research categories"). The example should show 2-3 rows of a real scoreboard.
- **Line 173 says "the prompt did NOT embed the schema" but lines 38-68 show a prompt structure that includes "## 4. Required Output Schema" as a section.** So the prompt *does* embed the schema (or at least a section heading for it). The "did not embed" claim is contradicted by the prompt structure shown 100 lines earlier. **Real contradiction.**

**What is unclear or ambiguous**
- The "Skip rules" at line 144-149: "drop the reference subject's own name (e.g., 'Silver Bullet')". But the alias map doesn't include "Silver Bullet" as a skip. How does the skill know to skip it? Hard-coded? A flag? The text is silent.
- The "Worked example" at lines 170-178 references the run but doesn't link to the `run-manifest.json` for that run. A reader has to navigate.

### 7. `rules/examples/code-review.md` (111 lines)

**What works well**
- Composite primary key (file + line) is correctly handled by `dedup_key: true` on both columns (line 68-70). The "Why `primary_key: 'file:line'` is wrong" callout (line 70) catches a real anti-pattern.
- The "Custom strategies" table (lines 93-100) is task-specific and justified (`most-severe` for safety, `majority` for category, `longest-with-quote` for description).

**What is missing or wrong**
- **No worked example.** Lines 109-111: "Not yet produced (deferred to v2.2.0). The pattern follows the prior-art research example — just swap the prompt, schema, and conflict rules." So the recipe is theoretical. A user has to trust that the prior-art example generalizes.
- **The dispatch script uses only 2 models (line 33).** Research uses 6. Why 2 for code review? No justification. The skill says 4-6 is the recommended default (SKILL.md:65). 2 is below minimum viable diversity (dispatch-mechanics.md:172: "Minimum viable: 2 models from different families").
- **The schema at lines 47-66 declares `severity_order` in `conflict_resolution` (line 75) but `severity_order` is not in SKILL.md's schema spec.** This is the same gap I flagged in §1 above. **Real reproducibility issue.**
- **Line 102-107 has a "Pre-commit hook" variation: "NOT currently supported as a built-in dispatch; requires custom runner".** The variation is documented as not supported. Either drop the variation or document the custom-runner pattern.
- **"For each finding, include a verbatim code quote" (line 29) is in the prompt but the schema declares both `description` and `evidence` as text fields.** Which is the quote? Is the quote mandatory in `description` or `evidence`? The schema doesn't enforce.
- **The "Output" section (lines 81-90) lists "§5 Per-Reviewer Statistics" and "§6 Coverage Gaps" which are not in output-schema.md.** Are these code-review-specific sections? The output-schema says §1-§8 + Appendix A-B. Code-review adds §5-§6. Where's the merge? Not documented.

**What is unclear or ambiguous**
- "Code review is a read-only task" (line 45) — but code review often produces "review and fix" outputs where the model applies edits. The recipe acknowledges this at line 105 but the security note is binary. The "review-and-fix" pattern needs its own recipe.
- A finding might span multiple lines (e.g., "lines 42-55"). The schema only has a single `line` field (number). The recipe doesn't address multi-line findings. Real limitation.
- The dispatch is "sequential" (the for loop) but the 2-model version is parallel (the `&`). Inconsistent with the dispatch-mechanics.md advice (line 105-111) that suggests sequential for shared-state tasks. Code review is read-only, so no shared state. Parallel is fine. But the recipe doesn't explain.

### 8. `rules/examples/fact-check.md` (113 lines)

**What works well**
- `majority-with-uncertain` is a high-stakes-aware rule (any dissent blocks consensus). The "Consensus requirements" section (lines 101-109) is appropriately strict.
- The schema at lines 53-71 has `counter_evidence` as a separate field, which is a real fact-check concept (the schema matches the task).

**What is missing or wrong**
- **The dispatch script uses 3 models (line 38) but the recommendation at line 37 is "4-5 for fact-check".** The example contradicts its own recommendation. For N=3, `majority-with-uncertain` requires all 3 to agree (consolidation-rules.md:183), so 1 dissent means `unverified`. With 3 models and tight consensus, most claims will be `unverified`. 4-5 is the practical floor.
- **The "Custom strategies" table at lines 91-99 lists `evidence: "all-collected"`, `sources: "union-dedup"`, `counter_evidence: "concatenate-all"` — but the schema at lines 53-71 only declares `verdict` and `confidence` in `conflict_resolution`.** The other three rules are aspirational. A user copying the schema won't get those rules applied.
- **The schema at line 60 declares `verdict: enum ["true", "false", "partially-true", "unverified"]` but the `majority-with-uncertain` rule only returns one of `true`/`false`/`unverified` (it never returns `partially-true`).** The schema is over-specified. Either remove `partially-true` or document when it's used.
- **The schema declares `sources: "url_list"` (line 64) — `url_list` was "formally defined in the schema spec (was a v2.1.0 gap)" per line 78.** But SKILL.md's column type list (line 124) only shows `url_list` as a type, not as a conflict-resolution type. So `url_list` as a column type is defined, but `union-dedup` (the corresponding resolution rule) being applied to a `url_list` field is not in the schema spec. The recipe assumes the mapping.
- **"Worked example — Not yet produced (deferred to v2.2.0)" (line 111-113).** Same gap as code-review. The recipe is theoretical.
- **The recipe is shorter (113 lines) than research (185 lines) and code-review (111 lines).** Research has an alias map; fact-check has none. Is "facts don't have aliases" correct? Or an oversight? The recipe doesn't justify.

**What is unclear or ambiguous**
- Line 24: `verdict: true | false | partially-true | unverified` — the prompt is unquoted. The schema is quoted. The pipeline expects JSON extraction, so quoted. The prompt is informal; a strict model would produce JSON, a lax model would produce prose. The skill's Mode A extraction (methodology.md:36-65) handles both. OK.
- "Unverified Claims" and "False Claims" sections at lines 88-89 are fact-check-specific output sections not in output-schema.md. Where do they fit in the §1-§8 structure?

---

## §2. Score the Skill on the 8-Dimension Rubric

| Dimension | Score | Justification |
|---|---|---|
| Catalog of composable units | **1** | The skill has a `rules/` directory (4 markdown files) and an `examples/` directory (3 files). The schema spec (`--schema` JSON) is machine-readable, but the named conflict-resolution rules (`most-severe`, `majority-with-uncertain`, etc.) are documented in prose at `consolidation-rules.md:163-222`, not as a typed catalog. The `rules/` directory is an informal role taxonomy, not a machine-readable catalog. |
| Dynamic composition | **1** | The 4-phase pipeline is static (no replanning). Consolidation is catalog-backed (schema drives it), and `run-manifest.json` is an audit log with `phases_completed`. But the audit log is distributed (manifest + structured.jsonl + conflicts.md) and the dispatch is not catalog-driven. Closer to "Replanner" than "Catalog-backed + audit log" because the catalog only drives consolidation, not the whole pipeline. |
| V-loop depth | **0** | (Matches R5 review scoring.) The skill is a single-shot pipeline. The default mode has no verification loop. `thorough` mode adds a verifier that checks *source claims* against URLs, but does not re-verify the consolidation itself. There is no intent gate ("did the output answer the user's prompt?") and no iterative refinement. |
| Enforcement | **0** | Honor system. No schema validation enforced. No CI integration. No IDE hooks. The user gets a report and is trusted to read it. The "thorough" mode is opt-in, not automatic. |
| Parent/worker split | **2** | Explicit orchestrator (parent agent invoking the skill) vs. workers (N models dispatched). The 4 dispatch mechanisms explicitly describe worker dispatch. Failure modes differentiate parent-side issues (timeout) from worker-side issues (model failure). |
| Evidence model | **2** | (Matches R3 and R5 scoring.) Tiered sufficiency: (1) `source_refs` per item; (2) `prefer-with-evidence-then-newer-then-strict` rule treats evidence-backed claims as higher authority; (3) `thorough` mode adds per-source verification with `evidence-ledger.md` and `verification.md`; (4) `last_verified` date tracks staleness; (5) `most-severe` has `allow_downgrade` for evidence-based downgrading. This is more sophisticated than most production review systems. |
| SE + DevOps unified | **0** | The 3 examples (research, code-review, fact-check) are SE-flavored. No DevOps example (deployment, infrastructure, monitoring, CI/CD pipelines, IaC). The skill is task-agnostic in claim but the examples don't represent both production task types. |
| Team customization | **0** | No overlay-pack concept. The alias map is task-specific, not team-specific. There's no customization layer; a team wanting to extend the skill would fork it. |

**Total: 6/16.**

This score is consistent with prior self-reviews: `self-review.md` (round 1) and `critical-review-r3.md` both score Evidence model at 2. `critical-review-r5.md:161` scores V-loop depth at 0. The low total is expected — the skill is a multi-model *dispatch* skill, not a V-model *workflow* skill. The 8-dimension rubric measures V-model maturity, which isn't the skill's claim. The skill scores where the rubric overlaps with multi-model dispatch (parent/worker = 2, evidence = 2) and scores low where it doesn't (enforcement, customization, DevOps coverage).

---

## §3. Top 5 Improvements (ranked by impact × effort)

### #1. `severity_order` and `allow_downgrade` are used in examples but not in the schema spec
- **Issue:** The schema field table in `SKILL.md:96-112` lists `conflict_resolution` as a map of `{field_name: rule_name}` but does not include the auxiliary fields that the rule library expects: `severity_order` (used in `code-review.md:75`), `allow_downgrade` (used in `consolidation-rules.md:170`), `separator` (used in `consolidation-rules.md:202`), and `verdict_uncertain_value` (used in `consolidation-rules.md:186`).
- **Why it matters:** A user implementing the code-review recipe will write a schema with `"severity_order": [...]` and either get a silent error (if the consumer validates strictly) or a silent ignore (if it doesn't). Same for `allow_downgrade`. **Flagged in R3:70 and R5:81, not fixed.**
- **Concrete change:** Expand `SKILL.md:107-112` to list the auxiliary fields. Sketch:
  ```json
  "conflict_resolution": {
    "category": "prefer-with-evidence-then-newer-then-strict",
    "score": "median",
    "severity": "most-severe",
    "severity_order": ["blocker", "major", "minor", "nit"],
    "allow_downgrade": false,
    "verdict_uncertain_value": "unverified",
    "separator": "; "
  }
  ```
  Document each field's semantics (most-severe-first ordering, default false, etc.) with cross-references to `consolidation-rules.md`.
- **Effort:** low
- **Impact:** high
- **Score: 3**

### #2. The "thorough mode" verifier dispatch is documented in 3 files but the workflow is missing from dispatch-mechanics.md and methodology.md
- **Issue:** `SKILL.md:81` describes thorough mode as "for each canonical item, dispatch a verifier model to check the claimed source actually supports the claim". `output-schema.md:183-203` documents `evidence-ledger.md` and `verification.md`. But `dispatch-mechanics.md` has no verifier dispatch (Mechanisms 1-4 are all for the initial fan-out), and `methodology.md:7-148` has 4 phases (1=dispatch, 2=extract, 3=consolidate, 4=synthesize) with no verifier phase. A user wanting to use thorough mode has no workflow to follow.
- **Why it matters:** A documented feature with no implementation path is a documentation bug. The user is told "thorough mode does X" but cannot find how X is done.
- **Concrete change:** Add a "Mechanism 5: Verifier dispatch (thorough mode only)" section to `dispatch-mechanics.md:104-115`. Sketch:
  > ### Mechanism 5: Per-item verifier dispatch (thorough mode)
  > After Phase 3 consolidation, for each canonical item with at least one `source_ref`, dispatch a verifier model per (item, source) pair:
  > ```bash
  > for item in "${items[@]}"; do
  >   for source in $(jq -r '.source_refs[]' "$OUT/${item}.json"); do
  >     # verifier prompt: "Does this source support this claim? Yes / No / Uncertain"
  >     npx -y opencode-ai run --model "$VERIFIER_MODEL" "$VERIFIER_PROMPT" > "$OUT/${item}-${source_hash}.verdict"
  >   done
  > done
  > ```
  > Default verifier model: the slowest/highest-capability model from the original dispatch (heuristic). Override via `--verifier-model <id>`.
  And add a Phase 5 to `methodology.md:7-148`: "**Phase 5 — Verification (thorough mode only)**" that references the dispatch mechanism.
- **Effort:** low
- **Impact:** high
- **Score: 3**

### #3. Phase numbering inconsistency between `methodology.md` and `consolidation-rules.md`
- **Issue:** `methodology.md` uses Phase 1-4 (dispatch / extract / consolidate / synthesize). `consolidation-rules.md` uses Phase 2-5 (Align / Dedup / Resolve / Score+Synthesize). Same content, different numbering. The `phases_completed` field in `run-manifest.json` (output-schema.md:235, 254) is supposed to track these phases but the manifest example shows `[1, 2, 3, 4]` and the consolidation doc uses 2-5.
- **Why it matters:** A reader cross-referencing the two files will be confused. The audit log's semantics are ambiguous because the phase numbers mean different things in different files. **Flagged in R3 review, not fixed.**
- **Concrete change:** Pick one numbering. Recommendation: re-number `consolidation-rules.md` to 1-4 (Align=1, Dedup=2, Resolve=3, Score+Synth=4) and add a "Phase 0: Dispatch" preamble. This matches `methodology.md:7-148`. Update the `phases_completed` example in `output-schema.md:235` to match. Update the cross-references in `methodology.md:147` ("**The canonical schema lives in `rules/output-schema.md` § `run-manifest.json`") to be phase-number-agnostic.
- **Effort:** low
- **Impact:** medium
- **Score: 3**

### #4. The "task-agnostic" claim is contradicted by the examples and defaults
- **Issue:** `SKILL.md:13` says "Task-agnostic. Works for any task the user wants done — research, code review, fact-checking, ideation, translation verification, writing critique, decision support, etc." But: (a) all 3 examples are information-extraction tasks (research, code-review, fact-check), none are generative or action tasks; (b) the scoring rubric in `research-prior-art.md:107-118` is research-domain-specific (catalog, dynamic_composition, v_loop, etc. — these measure V-model workflow maturity, not generic multi-model quality); (c) the named conflict-resolution rules are task-flavored (`most-severe` for code-review, `majority-with-uncertain` for fact-check) and the rule library has no general-purpose `default` or `narrative` rules; (d) the alias map is research-specific (AutoGen/AG2, MAF, etc.); (e) the consolidation-rules.md:285-296 "Final synthesis sections" list ("Executive Summary", "Items Table", "Per-Item Details", "Conflicts & Resolutions", "Aggregated Scores", "Negative Results") is research-flavored.
- **Why it matters:** A user wanting to use the skill for ideation, writing critique, or translation verification will find that the examples don't help, the named rules don't apply, and the output structure is wrong. The "task-agnostic" claim is aspirational, not current. **Real credibility gap.**
- **Concrete change:** Two options:
  - **Option A (low effort, lower value):** Update the description to be honest. Replace line 13 with: "**Multi-model dispatch + structured extraction + consolidation.** Defaults favor information-extraction tasks (research, code-review, fact-check). Other task types (generative, action, multi-turn) are not currently supported." This sets correct expectations.
  - **Option B (medium effort, higher value):** Add 1-2 more examples to demonstrate the task-agnostic claim. Candidates: `ideation.md` (no dedup, median feasibility × impact ranking), `writing-critique.md` (concatenate-all for comments, parallel sections per model), `translation-verification.md` (majority for accuracy, flag disagreements for human review). Each should be 80-120 lines, following the pattern of the existing examples.
- **Effort:** low (Option A) or medium (Option B)
- **Impact:** high
- **Score: 2-3 (Option A) or 2 (Option B)**

### #5. The `-y` typo, `dedup_key: "secondary"` undefined, and other small but real bugs
- **Issue:** Several small issues compound:
  - `dispatch-mechanics.md:65`: bolded text "`--y` in `npx -y opencode-ai run`" has the wrong flag (npx uses `-y`, one dash).
  - `SKILL.md:144` defines `dedup_key: "secondary"` as "Tiebreaker after primary key" but the dedup algorithm in `consolidation-rules.md:95-110` has no concept of "secondary" — composite keys use multiple `dedup_key: true` columns. A user writing `"dedup_key": "secondary"` will get silently incorrect behavior.
  - The "Source reports" line format in `output-schema.md:32` is ambiguous (string vs. structured).
  - The conflict-marker rule at `output-schema.md:75` contradicts the WYSIWYG rule at line 262.
  - The `—` vs `--` rule is contradicted between `consolidation-rules.md:257` and `output-schema.md:265`.
  - The "most-severe" rule's prose structure puts the edge case before the default (`consolidation-rules.md:170-172`), which a skimmer will read as the default. **Flagged in R3:227, not fixed.**
  - The `prefer-with-evidence-then-newer-then-strict` rule name contains "strict" but the algorithm doesn't define it.
  - The `phases_completed` field in `output-schema.md:254` has undefined "produced output" semantics.
- **Why it matters:** Each is small. In aggregate they're 8+ bugs or spec gaps that future users will hit. None is hard to fix.
- **Concrete change:**
  - `dispatch-mechanics.md:65`: change "`--y`" to "`-y`".
  - `SKILL.md:144`: remove the `dedup_key: "secondary"` row (or implement secondary-key support in `consolidation-rules.md:95-110`).
  - `output-schema.md:32`: clarify as a structured field `{path, model_id, size_kb, line_count}`.
  - `output-schema.md:75`: align with line 262 — always use code-spans for conflict markers.
  - `consolidation-rules.md:257` and `output-schema.md:265`: pick one (recommend `--`).
  - `consolidation-rules.md:170-172`: rewrite to lead with the default (`allow_downgrade: false`), then describe the edge case.
  - `consolidation-rules.md:156-162`: rename rule to `prefer-with-evidence-then-newer-then-outlier` (or document what "strict" means).
  - `output-schema.md:254`: define `phases_completed` semantics explicitly: "phase N is in `phases_completed` iff it produced its expected output file (even if empty); a phase that errored is not listed".
- **Effort:** low (per item, trivial; combined, low-medium)
- **Impact:** low-medium (per item, low; combined, medium)
- **Score: 2-3**

---

## §4. Open Questions

To make a more confident review, I'd need to know:

1. **Is the skill actually implemented anywhere?** All 8 files are markdown specs. There's no `scripts/`, `hooks/`, or `lib/` directory in `skills/multi-ai-task/`. The skill is a specification that downstream agents (parents) read and follow. The "parent orchestrator" referenced in the user's prompt is presumably an LLM agent reading this spec and manually doing the dispatch. If so, the spec is a prompt-template more than a skill. Is there a planned implementation? Or is the spec the implementation?

2. **What is the version-tracking story?** The frontmatter says `version: 2.1.0`. The "Provenance" section in `SKILL.md:264-279` describes v2.0.0 and v2.1.0. But there's no `CHANGELOG.md`, no release notes, no upgrade path from v2.0.0 → v2.1.0. The 5 prior self-reviews (`self-review.md`, `critical-review-r3.md`, `critical-review-r4.md`, `critical-review-r5.md`) are in the skill directory but aren't referenced from `SKILL.md`. Are they authoritative? A new user won't know they exist.

3. **The "task-agnostic" claim — is it a goal or a current state?** The v1 → v2 transition generalized from research-only to task-agnostic. But the v2 still has research-flavored defaults and examples. Is the intent to fully generalize (Option B in improvement #4)? Or is the intent to be honest that the skill is "research-first, generalizing over time" (Option A)?

4. **The 4 prior self-reviews flagged 10+ issues that weren't fixed.** R3:70 (`severity_order` not in schema spec), R3:227 (most-severe prose structure), R5:81 (same), R5:92 (evidence-ledger.md schema), R5:161 (V-loop = 0), R5:164 (Evidence = 2). Why are these not being fixed? Is the self-review process purely advisory? Is there a separate triage process?

5. **The "round-2 self-review" at `SKILL.md:278` references a specific path. Are the prior 5 self-reviews part of an ongoing self-improvement cycle? Or are they one-off exercises?** If ongoing, what's the trigger? A version bump? A schedule?

6. **The `evidence-ledger.md` and `verification.md` schemas (output-schema.md:183-203) are example rows, not formal field definitions.** R5:92 flagged this. Is the plan to formalize them? Or are they deliberately informal because thorough mode is rarely used?

7. **The "default model discovery" in `SKILL.md:71-73` is OpenCode-specific.** The skill claims harness-agnosticism via Mechanism 4 (direct HTTP). But the default model set is determined from `~/.config/opencode/opencode.json`. If a user is on Claude or Codex with no OpenCode config, what happens? Is "no config → use environment variables" an implicit fallback? Or is the skill OpenCode-only in practice?

8. **The `task_prompt_hash` field in `run-manifest.json` is described as "useful for cache lookup" (output-schema.md:241) but the skill "does NOT cache across runs by default" (methodology.md:170).** Is the cache lookup for future implementation? Or for user-level caching? The relationship is unclear.

9. **The "extractor model" default ("the slowest/highest-capability model from the dispatch") is a post-hoc heuristic.** methodology.md:53-58. Is there a plan to make it a deterministic default (e.g., `--extractor-model <id>`) or always the first model in `--models`?

10. **The "Default model discovery" of "4-6 models" is a recommendation, not a hard requirement.** What's the actual minimum for the skill to be useful? 2? 3? 4? The conflict-resolution rules give different answers (`majority-with-uncertain` requires N≥3; `most-severe` works with 1; `prefer-with-evidence` needs ≥2 for the outlier rule).

---

## §5. Confidence

- **Overall confidence: medium.** I've read all 8 files thoroughly and grepped for several specific patterns. Several issues (the `-y` typo, the `dedup_key: "secondary"` gap, the `severity_order` schema spec gap, the missing verifier workflow) are real bugs. Other issues (the "task-agnostic" claim, the phase numbering inconsistency) are matters of design intent. I've not run the skill myself, so I can't verify which issues are theoretical (spec gap with no downstream consumer) vs. which are practical (user hits error today).

- **What would change my assessment:**
  - **If I saw the run-manifest.json from a real run** (e.g., the 2026-06-27 prior-art run), I could verify whether `schema_auto_injected`, `phases_completed`, and the `aliases` field are actually populated as documented, or whether the manifest in practice diverges from the spec.
  - **If I saw the actual implementation** (a `scripts/` or `lib/` directory in the skill, or a downstream consumer that reads the spec and dispatches), I could verify which spec gaps are real (block the implementation) vs. aspirational (no one checks).
  - **If I saw the 4 prior self-reviews' full content** rather than just the directory listing, I could identify which issues are genuinely new vs. which are re-flags of known problems. I know at least 3 of my top 5 issues were flagged in R3 or R5 and not fixed — that affects my confidence in the "improvement" framing. If the team has already triaged these and decided not to fix them, my "improvement" recommendations are noise.
