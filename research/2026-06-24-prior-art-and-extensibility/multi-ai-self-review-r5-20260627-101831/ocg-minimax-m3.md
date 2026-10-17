I've read all 8 files plus the two prior reviews (`self-review.md` round 2, `critical-review-r3.md`) that already live inside the skill directory. Below is my fresh review. Where r2/r3 issues are still present in the current files, I call that out explicitly; where the current state has changed or the r3 review was wrong, I note that too. I've also surfaced several issues the prior rounds missed.

---

# §1. Critical Assessment

## 1. `SKILL.md`

**What works well**
- The "When to use / When NOT to use" table (lines 35-50) is concrete enough to actually prevent misuse — "Single model suffices" / "Real-time interactive" / "Output is non-textual" are real disqualifiers, not platitudes.
- The schema section (lines 86-155) is the most implementation-ready part of the skill. Column types, composite keys, named rule library, and auto-inject behavior are all specified with enough detail to build a parser from prose.

**What is missing or wrong**
- **Line 5: `user-invocable: false`** plus the "Usage" heading at line 54 (with CLI-style invocation in lines 57-58) is contradictory. `user-invocable: false` means the skill is invoked by an agent, not a human; the CLI form is therefore an *agent-facing* interface, not a user-facing one. The Usage section never says this — it just writes a CLI as if a human will run it. Make the audience explicit: "Invocation form (for the calling agent): ..." or move the bash to `dispatch-mechanics.md` and leave SKILL.md as a behavioral spec.
- **Line 28 contains a self-contradicting double negation under a "does NOT do" heading:**
  > `- Inject the schema into the prompt unless `--no-auto-inject` is set (default ON — see "The `--schema` parameter" below)`
  
  The list is "What this skill does NOT do." The bullet says the skill DOES inject by default, with an opt-out. This is a triple-stacked negative: "does NOT do X unless not-X" = "does X." Either move this bullet to the "What this skill does" list (lines 15-22) or rewrite as "Skip schema auto-injection if `--no-auto-inject` is set (off by default)."

  The r3 review flagged this and it is **still present in the current file**.
- **Line 187: "The 4 phases are also tracked in `run-manifest.json → totals.phases_completed`"** is wrong. `phases_completed` is at the top level of `run-manifest.json`, not nested under `totals`. The canonical schema in `output-schema.md:235` shows `"phases_completed": [1, 2, 3, 4]` as a top-level field. This is an internal SKILL/methodology inconsistency. The r3 review's central claim (that `output-schema.md` was missing v2.1.0 fields) appears to be stale — those fields are now present. But this path bug at line 187 is a real, current error.
- **Line 194: "These are the core value of the skill; everything else is plumbing."** Self-deprecating. Dispatch mechanics, extraction fallbacks, HTML rendering, and the evidence model have caused real failures in the proven run (failure modes 2, 5, 7, 8 in lines 217-227). Calling them "plumbing" tells the reader to skip them. The r3 review flagged this; **still present**.
- **Line 227 — the failure-modes table contains a "planned file" entry** that is unlike any other entry in the table:
  > `| Output dir contains `score-aggregate.md` (planned) but not in the contract | Old spec inconsistency | Ignore for v2.x; the section is in `consolidated.md` body as §5 Aggregated Scores |`
  
  Every other entry documents a real failure mode. This one documents a planning artifact that was never built. It belongs in a changelog or roadmap, not in the failure-modes table. Drop it.

**What is unclear or ambiguous**
- **Line 191**: "**Default is Mechanism 2** (`opencode run --model <id>` subprocess per model; proven to work; subagent_types via the `task` tool may be restricted by some harnesses)." But `dispatch-mechanics.md:9-30` says Mechanism 1 is "preferred-if-available." So which is it — "preferred" or "default"? The answer (Mechanism 1 is preferred when the host allows custom subagent types; otherwise Mechanism 2) is implicit but not stated. Make it explicit: "Default when Mechanism 1 is unavailable: Mechanism 2."
- **Line 73-75 — "Default model discovery"**: "queries the local OpenCode config... and picks a balanced default set of 4-6 models." No algorithm is specified. What if the config has 20 models? Which 4-6 are picked? This is a behavioral contract with no spec.
- **Line 81 — `thorough` mode description** describes `evidence-ledger.md` and `source_verified: true|false|wrong` flags, but `methodology.md` Phase 4 (lines 122-148) never describes producing these files. The user-facing table promises an output that the methodology doesn't define.

---

## 2. `rules/methodology.md`

**What works well**
- The Phase 2 Mode A extraction pseudocode (lines 37-65) is concrete, ordered, and implementable — 4 fallback paths with clear rationale at each step (table → structured tags → extractor LLM → paragraph split).
- The "Deterministic + LLM-assisted hybrid" principle (lines 156-161) makes the design trade-off explicit.

**What is missing or wrong**
- **Phase 4 (lines 122-148) is missing the `thorough`-mode outputs.** The methodology's Phase 4 only lists `consolidated.md`, `consolidated.html`, `conflicts.md`, `run-manifest.json`. The skill promises `evidence-ledger.md` and `verification.md` in `thorough` mode (`SKILL.md:81`, `SKILL.md:170-171`) but `methodology.md` never says how or when those files are produced. A reader following methodology.md will not produce thorough-mode evidence files.
- **Line 187: `totals.phases_completed` is wrong.** The canonical schema (`output-schema.md:235`) has `phases_completed` at the top level. This contradicts itself between this file and the file it cites as canonical.
- **Line 158: "Structured extraction (Mode A) is deterministic — pure parsing, no LLM in the loop."** False. Mode A fallback path 3 (lines 52-58) dispatches an extractor LLM. The r3 review flagged this; **still present**. The claim should be: "Mode A is deterministic *when the model produces a compliant table*; the LLM extractor is the fallback for non-compliant responses."
- **Line 115-116 (Phase 3, step 4 — "Score aggregation") and Phase 3.6 in `consolidation-rules.md:266-278` ("Aggregate scoring matrix") overlap.** Is scoring done in Phase 3 (per-item) or Phase 3.6 (matrix)? Both. But this is not stated; a reader sees two scoring steps and assumes one is wrong.
- **Line 173: "Idempotent re-runs"** is misused. Idempotent means same input → same output. With non-deterministic LLM responses, the skill is *re-runnable* but not *idempotent*. Two runs with the same prompt will produce different outputs.

**What is unclear or ambiguous**
- **Line 104: "Extractor model — Default: the slowest, highest-capability model from the original dispatch."** How is "highest-capability" determined? Largest context window? Most parameters? Provider metadata? Reasoning-focused? This needs a concrete heuristic. The r3 review flagged this; **still present**.
- **Line 97: "First 5 words = primary_key (fragile; flag fuzzy_match:true)."** The skill admits this heuristic is fragile. What does the consolidation do when a model writes multi-paragraph items? The skill silently produces garbage. There is no "low-confidence" warning surfaced to the user.
- **Line 187 says "totals.phases_completed" but `output-schema.md:235` says `phases_completed` (top-level).** Which is canonical? Methodology.md claims output-schema.md is canonical (line 147) — so methodology.md is wrong. But methodology.md is the older file; the path string in line 187 was probably never updated.

---

## 3. `rules/dispatch-mechanics.md`

**What works well**
- The 4-mechanism decision table at the bottom (lines 172-181) maps real constraints (custom subagent types, OpenCode server, port collision) to mechanisms. This is genuinely useful.
- Real-world bug references add credibility: issue #18615 (Mechanism 3), 6 issues + 1 PR for the `task` tool's missing `model` field (Mechanism 1). Concrete, not hand-wavy.

**What is missing or wrong**
- **Lines 36-53: The bash snippet defines `TIMEOUT=600` (line 41) but never uses it in the `npx` command (lines 45-50).** The fix is described in prose on line 62 (`timeout $TIMEOUT` on Linux, `gtimeout` on macOS), but the snippet itself is broken. A reader copy-pasting the snippet will hit the 2-min default timeout on long tasks. The r3 review flagged this; **still present**. The snippet should be self-contained.
- **Line 50 redirects to `> "$OUT/${slug}.md"` and `2> "$OUT/${slug}.err"`** but does not explain how to recover partial output when the 2-min default kills the subprocess. There is no `timeout` guard, no `set -o pipefail`, no truncation warning.
- **Lines 85-93 — Mechanism 4 Python example is a non-working skeleton.** It references `ENDPOINTS`, `KEYS`, `model.id`, and `model.provider` without defining any of them. No error handling, no rate limit, no retry, no auth. If this is meant as a reference, label it as such. Currently it looks like it should work but won't.
- **Lines 107-112: "Always check the model's CWD for stray `*.md` files after a dispatch."** This is advice for a human user, not for an automated skill. The calling agent has no access to the model's CWD — that's a separate directory. Either: (a) document this as a manual post-run step, (b) have the dispatch command set the model's CWD to the output dir (via `cd "$OUT"` before `npx`), or (c) drop the advice. The current placement is misleading.
- **Line 106: "configure MCPs that support multiplexing"** — what MCPs? What config flag? This is a concrete recommendation with zero concrete details. r3 flagged this; **still present**.

**What is unclear or ambiguous**
- **Line 104: "The proven 6-model run took ~2-3 min/model."** This is for the research prior-art task. For other task types (code review, fact-check) the per-model time will differ. The "2-3 min" figure is task-specific but presented as a general benchmark.
- **Line 28 — "Dynamic per-call model selection is a 6-time-requested feature (issues #6651, #11215, #17595, #26925, #29984, #32730) with one open PR (#29447); not yet released."** These are real issue numbers, but no reader can verify them without the GitHub repo. The note should either link to the repo's issue list or be removed.

---

## 4. `rules/consolidation-rules.md`

**What works well**
- The named rule library (lines 163-221) is the strongest part of the entire skill. Every rule has purpose, input spec, algorithm pseudocode, and edge cases. `most-severe`, `majority`, `majority-with-uncertain`, `lowest-of-majors`, `longest-with-quote`, `concatenate-all`, `all-collected`, `union-dedup`, `merge-exact` — nine rules, all genuinely implementable.
- The conflict documentation template (lines 227-234) uses real example values, not placeholders.

**What is missing or wrong**
- **`most-severe` edge case (lines 167-172) is internally confusing.** The prose describes the `allow_downgrade: true` option before stating the default:
  > "if 1/N reviewers says `blocker` and all others say `major` (or lower), and the lone `blocker` has no evidence quote, the schema may declare `"allow_downgrade": true` to downgrade the lone max to the next-severity tier. **Default: `allow_downgrade: false`** — the most-severe value wins even if only 1 reviewer reported it."
  
  A skimming reader sees "may declare allow_downgrade to downgrade" and assumes that's the default behavior. The default is the opposite. Restructure to lead with the default and treat `allow_downgrade` as a rare override. r3 flagged this; **still present**.
- **Phase numbering is chaotic across files.** `methodology.md` uses Phase 1-4. `consolidation-rules.md` uses Phase 2 (line 26), Phase 3 (line 78), **Phase 3.5** (line 136), **Phase 3.6** (line 266). Phase 3.5 here is part of Phase 3 in methodology.md. Phase 3.6 here overlaps with Phase 4 in methodology.md. Two readers will count the phases differently. r3 flagged this; **still present**.
- **Line 185 — `majority-with-uncertain` naming rule is backwards.** The doc says:
  > "Do NOT change the rule's return value to match the schema — change the schema to match the rule."
  
  This inverts normal API design. Configuration should drive behavior, not the other way around. If a user's schema has `values: ["true", "false", "partially-true"]` (no `unverified`), the rule silently returns `unverified` and the consolidation breaks. Either the rule should accept a configurable return value, or the schema's enum should be validated against the rule at parse time.
- **Line 115 — Alias map and skip rules share the same data structure with overloaded semantics.** "Mark a row's primary key as `aliases[n] = null` to drop it from the registry." A reader scanning the alias map sees `{'AutoGen/AG2': 'AutoGen', 'SomePlaceholder': null}` and has no way to know that `null` means "skip" without reading the prose. Use a separate `skip_keys: Set` or `exclusions: []` field. r3 flagged this; **still present**.
- **Line 33 — The JSON record example uses `primary_key` as a column name, but the schema spec** (e.g., the `code-review.md` example) lists columns like `file`, `line`, `severity` — none of which is named `primary_key`. The `primary_key` here is the meta-field *identifying* which column is the key, not a column name itself. The terminology is muddled. The `code-review.md` "composite key correction" (line 70-71) says `primary_key: "file:line"` is wrong because "composite keys are expressed by listing multiple columns with `dedup_key: true`." But the `primary_key` field appears in the JSON record example at line 33, in the structured extraction example at `methodology.md:28`, and in the run-manifest schema description. Three different uses of the same name.
- **Line 73: Table parser pseudocode says "Header row has 10-16 cells, with the first being `#` or `name`".** This is research-specific (the research schema has 16 columns). The rule is in the *generic* rules file. A code-review schema has 7 columns; a fact-check schema has 7. The 10-16 cell guidance is wrong for those.
- **Line 82: "For semantic dedup (e.g., `AutoGen` ↔ `AG2`), supply an alias map at run time."** But the interface for supplying the alias map is **undefined**. There is no `--aliases` CLI flag in `SKILL.md`. The research example (line 123) hardcodes the alias map in the bash script and says "Save it in your run's `run-manifest.json → aliases` field" — but `run-manifest.json` is the *output*, not the input. A user reading the core rules cannot figure out how to pass the alias map.

**What is unclear or ambiguous**
- **Line 131: "Match if normalized titles are >=80% similar (Levenshtein or token-overlap)."** Which one? Levenshtein and token-overlap give different results for the same input. Pick one. `BMAD-Method` vs `Method-BMAD` has Levenshtein 4, token-overlap 100%. The skill says either works; the user picks the wrong one and gets different dedup results.
- **Line 100 — "Sort by `entries.length` descending, then by canonical name."** This is the *dedup* phase. But `methodology.md:124` says "sort by `entries.length` descending, then by canonical name" too. Why sort? The order affects how `consolidated.md` is rendered. The sort criterion is not stated to be configurable, but task-type-specific ordering might be desirable (e.g., code review: sort by severity not by mention count).
- **Lines 258-262 — "Maturity / version conflict"** describes resolution for version-number disagreements but doesn't say *how* to determine which version is "newer" (compare release tags? compare `last_verified` date? both?). The example uses GitHub-style tag comparison but doesn't generalize.

---

## 5. `rules/output-schema.md`

**What works well**
- The markdown formatting rules (lines 258-269) are CRITICAL and well-specified. Every one of those rules was clearly learned from real WYSIWYG rendering failures (`**direct***` → `` `direct*` ``, blank lines around tables, no triple-asterisk). These rules are non-obvious and the section is the most useful "tribal knowledge" in the skill.
- The two-mode output structure (schema vs free-form) is cleanly delineated.

**What is missing or wrong**
- **Line 209: "This is the canonical schema"** but the same schema is described in `methodology.md:145-147` ("The canonical schema lives in `rules/output-schema.md` § `run-manifest.json`."), which references this file. That's consistent — output-schema.md is canonical. **However**, `methodology.md:187` contradicts both by referencing `totals.phases_completed`, which doesn't exist in the canonical schema (it's at the top level). Two files, one canonical claim, one bug. r3 flagged this and the methodology.md side of the bug is **still present**.
- **Line 70: "Conflict marker legend (place at top of section)"** — but the legend refers to "Resolution rules: see §4" while §2A (Items Table) is positioned *before* §4. A reader sees a conflict marker in the items table, looks at the legend, is told to read §4, but §4 hasn't been introduced yet. Either renumber so §4 (Conflicts & Resolutions) comes before §2 (Items Table), or replace the forward reference with a self-contained legend.
- **Lines 100-115 — §3 "Per-Item Details" leaks research-specific fields into the generic spec:**
  > "Research / comparative: `gaps_vs_reference = ... ; reference_gaps_vs_them = ...`"
  
  These are research-prior-art fields, not generic. A code-review user reading §3 will be confused. Replace with truly task-agnostic examples, or split the section into "generic template" + "task-type examples" in `rules/examples/`.
- **Line 257-269: The markdown formatting rules section has no section number.** It follows §8 but isn't numbered. This makes it impossible to cross-reference ("see §9" is meaningless). The r3 review flagged this; **still present**. Make it §9.
- **Lines 130-131: §5 (Aggregated Scores) and §8 (Synthesized Verdict) are marked "optional" but §6 (Negative Results) and §7 (Open Questions) are not marked optional.** Is §6 always produced, even when there are no negative results? What if §6 is empty — is it omitted or produced as an empty heading? The optionality contract is inconsistent.
- **Line 219 — schema example has `"schema": { "type": "table", "columns": [...] }` but does not enumerate the supported `type` values.** Only `table` is documented. If a user passes `type: "tree"` or `type: "graph"`, what happens? The skill spec should list supported types or define behavior for unsupported ones.

**What is unclear or ambiguous**
- **Line 224 — `"aliases": {"AutoGen/AG2": "AutoGen"}`**. This example uses `AutoGen/AG2` as a key — but the alias map in `rules/examples/research-prior-art.md:127` has separate keys: `AutoGen/AG2` and `AutoGen (maintenance)`. The example in `output-schema.md` is oversimplified compared to the actual schema example. Which is the right form?
- **Line 252 — `totals.conflicts_resolved` vs `consolidation.unresolved_conflicts`** — two fields tracking overlapping concepts. `totals.conflicts_resolved` counts the number of resolutions; `consolidation.unresolved_conflicts` counts conflicts that couldn't be resolved. The relationship between them is implicit. Are unresolved conflicts subtracted from resolved? A reader parsing the manifest should not have to guess.

---

## 6. `rules/examples/research-prior-art.md`

**What works well**
- The full prompt template (lines 37-68), schema (lines 72-99), scoring rubric (lines 104-118), and alias map (lines 125-141) together form a complete, copy-pasteable recipe. This is the only example that's actually been run end-to-end, and the recipe is the most concrete artifact in the skill.
- The 14-entry alias map (lines 127-141) is a strong reference for research dedup.

**What is missing or wrong**
- **No consolidated output snippet.** Lines 154-167 list the section headings of `consolidated.md` but show no actual table rows, no conflict resolution example, no scoring matrix. A reader has to find `docs/research-260624/SB_CONSOLIDATED_PRIOR_ART_REPORT.md` separately. A 5-row excerpt would make this example self-contained. r3 flagged this; **still present**.
- **The bash dispatch (lines 18-32) and the prompt template (lines 37-68) are disconnected.** The dispatch uses `cat /path/to/research-prompt.md` (line 20) but the prompt template is inline. A reader may not realize they need to save the template to a file first. Either inline the prompt in the bash heredoc, or add a "save the above template to `research-prompt.md` first" instruction between the bash block and the template.
- **Line 173: "the prompt did NOT embed the schema; the skill auto-injected it because `--no-auto-inject` was not passed."** But the bash dispatch (lines 18-32) doesn't show `--schema` being passed either. Where does the schema come from? The example implies the schema is passed separately (as a JSON file?), but the bash snippet doesn't show it. The reader has to infer that `--schema /path/to/schema.json` should be added. Show it.
- **Line 182: "diminishing returns past 6 (this is an empirical observation, not a measured curve)"** — honest but weakens the recommendation. Either cite the marginal-uniqueness data from the 6-model run (e.g., "Models 1-3 contributed 30 unique items, 4-6 contributed 12 — the marginal value of model 5+ is roughly 1-2 unique items per model") or don't state a number. "Diminishing returns past 6" is a guess.

**What is unclear or ambiguous**
- **Line 142: "Add new aliases to this map as they surface in your runs."** But the alias map is in the example file. Should each run copy the map into its own bash script? Embed it in `--schema`? Save to a separate file passed via some (undefined) CLI flag? The interface is unclear.
- **The "Variations to try" section (lines 181-185) mixes concrete variations (add more models) with aspirational features (use research methodology per model, use `thorough` mode).** "Use a research methodology per model" is an option to invoke another skill (`deep-research`); that's a cross-skill dependency the reader should know about. "Use `thorough` mode" is well-documented. Mixing these in a flat list makes them look equivalent.

---

## 7. `rules/examples/code-review.md`

**What works well**
- The composite-key correction (lines 70-71) is pedagogically valuable: shows the wrong way (`"primary_key": "file:line"`) and the right way (two columns with `dedup_key: true`). The wrong way is explicitly marked as not a recognized schema field. This is a good piece of error-correction documentation.
- The "Custom strategies for code review" table (lines 93-100) maps each field to a named rule with rationale. This is the kind of table that makes the skill actually usable for code review.

**What is missing or wrong**
- **Line 111: "Not yet produced (deferred to v2.2.0)."** No worked example. The skill has exactly one proven example (research). For a skill that claims to be "task-agnostic" and lists 5+ task types, having only one proven task type is a credibility gap. Same gap in `fact-check.md:113`. The task-agnostic claim rests on a single case study.
- **Line 45 — Security note conflates "read-only task" with "no tool permissions needed":**
  > "code review is a read-only task — the models just read and report, they don't write. So the dispatch above does NOT pass `--dangerously-skip-permissions`."
  
  But the prompt (line 21) tells the model to "Review the file at /path/to/code.py." If the model uses the `read` tool to access the file, it needs file-system permissions. `--dangerously-skip-permissions` is about *all* tool permissions (including read), not just write permissions. The example's reasoning is wrong: code review may need read access, so the flag should be set if the harness requires it. The current dispatch may fail with permission errors when the model tries to read the file.
- **Line 107: "Pre-commit hook: combine with git diff to only review changed lines (NOT currently supported as a built-in dispatch; requires custom runner)"** — this is a feature wishlist item in an "Example" file. It is not an example; it is a roadmap item. Either move it to a `ROADMAP.md` in the skill directory, or remove it.
- **The bash dispatch (lines 33-42) shows only 2 models.** The "When to use" table in `SKILL.md` recommends "4-6 models from at least 2 different provider families." 2 models barely meets the minimum-viable threshold. The example would be more credible with 4 models.

**What is unclear or ambiguous**
- **Line 45 vs `dispatch-mechanics.md:56-59`** — `dispatch-mechanics.md` says: "For **write tasks** (writing a file to the user's repo, modifying configs), do NOT use this flag — let the agent prompt for permission. The skill is task-agnostic, so the user is responsible for choosing the right security posture." This is the opposite of the code-review example's reasoning, which says "read-only task → don't use the flag." The two sources disagree on the same flag.

---

## 8. `rules/examples/fact-check.md`

**What works well**
- The consensus requirements (lines 102-109) with parameterized thresholds (`max(2, ceil(N/2))`) are well-specified. The same rule applies across N=3, N=5, N=7 without rewriting the algorithm.
- The "Key customization for fact-check" (lines 73-77) explains *why* each rule choice matters — `majority-with-uncertain` is preferred because high-stakes claims should default to `unverified` rather than mis-judge.

**What is missing or wrong**
- **Line 113: "Not yet produced (deferred to v2.2.0)."** No worked example. Same gap as `code-review.md`. r3 flagged this; **still present**.
- **Line 77: "`sources: 'url_list'` is now formally defined in the schema spec (was a v2.1.0 gap)"** — this is a changelog entry embedded in an example file. Changelog information should be in `CHANGELOG.md` (which doesn't exist) or `run-manifest.json` versioning, not scattered across example files. r3 flagged this; **still present**.
- **Line 109: "The '3+ models' rule in the original draft was a typo; the correct threshold is parameterized."** Self-referential to a deleted draft. A reader who wasn't there for the original draft has no context. Remove or move to a comment in the source repository.
- **The distinction between `partially-true` and `unverified` is undefined.** Both are valid verdict values in the schema (line 60), but the prose (line 76) only says "`unverified` is a valid output." When does a model return `partially-true` vs `unverified`? Is `partially-true` for "the claim is half-right" and `unverified` for "insufficient evidence"? The schema allows both; the prose doesn't say which to use when.
- **Line 104 says "≥ `max(2, ceil(N/2))` models agree on `true` with high confidence + primary source → confirmed."** But the schema's conflict resolution is `majority-with-uncertain` (line 67), which returns `unverified` if the threshold isn't met. It doesn't return `confirmed` — it returns `true`. The prose introduces a `confirmed` status that's not in the schema's enum. Is `confirmed` the same as `true`? If so, don't introduce a new term. If not, define it.

**What is unclear or ambiguous**
- **The "Custom strategies for fact-check" table (lines 92-99) recommends `evidence: "all-collected"` and `counter_evidence: "concatenate-all"`.** These two rules are similar but different. `all-collected` returns `[{model, value}]` (preserves provenance); `concatenate-all` returns a string (loses per-model attribution). Why one for evidence and the other for counter-evidence? The rationale column is empty. Without rationale, the choice looks arbitrary.

---

# §2. Score the Skill on the 8-Dimension Rubric

| Dimension | Score | Justification |
|---|---|---|
| **Catalog of composable units** | 2 | Machine-readable catalog: 9 named conflict-resolution rules with algorithm + edge cases (`consolidation-rules.md:163-221`), 8 column types with validation rules (`SKILL.md:115-141`), 4 dispatch mechanisms with selection criteria (`dispatch-mechanics.md:172-181`), 3 modes with per-phase semantics (`SKILL.md:77-83`). The schema JSON is the catalog format. Genuinely strong — implementable from prose. |
| **Dynamic composition** | 1 | Configuration drives behavior (`--mode`, `--schema`, `--models`, `--no-auto-inject`). `run-manifest.json` is an audit trail. But no runtime replanning (mode can't change mid-run), no dynamic model substitution on failure (fail-soft but doesn't re-dispatch), no adaptive extraction (can't switch from table parse to LLM extraction based on partial results). The skill is a *pipeline*, not an *adaptive system*. |
| **V-loop depth** | 1 | `thorough` mode adds a verification loop (per-item source checking via a verifier model). `phases_completed` in `run-manifest.json` is a per-phase audit trail. But no per-step rollup (can't inspect intermediate extracts and re-dispatch), no intent gate (no confirmation that consolidation matches user intent before final output), no V-model traceability from output back through each phase. The `thorough` mode is one extra loop; not a V-model. |
| **Enforcement** | 0 | Honor system only. The skill is a set of Markdown files. No IDE hooks, no CI integration, no delivery blockers, no pre-commit checks, no test harness. Nothing prevents a user from invoking the skill with 1 model and skipping consolidation. The skill's value depends entirely on the calling agent's discipline to follow the rules. (Note: `output-schema.md` has markdown formatting rules for *rendering*, not *enforcing* the skill's own behavior.) |
| **Parent/worker split** | 2 | Explicit orchestrator/worker: the consolidation engine (Phase 3-4) is the orchestrator; per-model dispatches (Phase 1) are workers with defined output contracts (`structured.jsonl`). Fail-soft preserves partial results. The "extractor model" role is a designated worker for fallback extraction. The `--models` and `--mode` parameters let the user tune the worker pool. |
| **Evidence model** | 2 | Tiered sufficiency with staleness: (1) `source_refs` in structured extraction (`methodology.md:28`); (2) `prefer-with-evidence-then-newer-then-strict` rule treats evidence-backed claims as higher authority (`consolidation-rules.md:155-162`); (3) `thorough` mode adds per-source verification with `evidence-ledger.md` and `source_verified` flags (`SKILL.md:81`); (4) `last_verified` date tracks staleness. More sophisticated than many production review systems. |
| **SE + DevOps unified** | 1 | The code-review example covers SE tasks (bug, security, perf, style, design, test categories). The fact-check example is domain-agnostic but not DevOps-specific — there's no example for infrastructure review, config audit, deployment verification, or IaC change review. The "covers both" claim is supported by SE only. DevOps coverage is implied, not demonstrated. |
| **Team customization** | 1 | Schemas and recipes act as "process packs." But no overlay/extension mechanism. A team must write a new schema from scratch — can't extend a base schema with extra columns. No schema inheritance, no merge strategy for team-specific rules. The 14-entry alias map in the research example (lines 125-141) is hardcoded, not extensible. |
| **TOTAL** | **10/16** | |

Same as r3 (10/16). The r3 review's central claim — that `output-schema.md` was missing v2.1.0 fields — is now stale (those fields are present in the current file). But `methodology.md:187` still references `totals.phases_completed` incorrectly, and several other r3 issues remain unfixed. So the score is stable, but the *reasons* for the score are different.

---

# §3. Top 5 Improvements (ranked by impact × effort)

### 1. Fix the `phases_completed` path inconsistency and add Phase 4 thorough-mode output spec

- **Issue:** `methodology.md:187` says `run-manifest.json → totals.phases_completed`, but the canonical schema (`output-schema.md:235`) has `phases_completed` at the top level. This is a real bug that contradicts the file that methodology.md itself designates as canonical. Additionally, `methodology.md` Phase 4 never describes producing `evidence-ledger.md` and `verification.md` in `thorough` mode, even though `SKILL.md:81,170-171` promises them.
- **Why it matters:** Every implementer building the methodology will produce a manifest that doesn't match the schema. Every `thorough` mode run will silently fail to produce the evidence files the user was promised.
- **Concrete change:**
  - In `methodology.md:187`, change `run-manifest.json → totals.phases_completed` to `run-manifest.json → phases_completed`.
  - In `methodology.md` Phase 4 (after line 148), add a subsection:
    ```markdown
    ### Thorough-mode outputs (only when `mode: "thorough"`)
    
    - `evidence-ledger.md` — for each canonical item, one row per source URL with
      the verifier model's verdict (`true | false | wrong`).
    - `verification.md` — per-item rollup: `source_verified: true|false|wrong`,
      with the per-source verdicts collapsed into one.
    
    These are produced by dispatching a verifier model (default: the slowest
    / highest-capability model from the original dispatch) once per item × source
    URL pair. Adds ~`N_items × 1 verifier call` wall-time.
    ```
- **Effort:** Low (edit 2 sections in 1 file, ~15 lines)
- **Impact:** High (data-integrity bug + missing thorough-mode spec)
- **Score:** **High ROI**

### 2. Make Mechanism 2's bash snippet self-contained (timeout in the code, not in the prose)

- **Issue:** `dispatch-mechanics.md:36-53` defines `TIMEOUT=600` on line 41 but never uses it in the `npx` command on lines 45-50. The fix is buried in prose on line 62. A reader copy-pasting the snippet will hit the 2-min default timeout on long tasks — the very failure mode the failure-modes table warns about.
- **Why it matters:** This is the **default** mechanism. Every copy-pasted invocation will be broken until the reader finds the fix in prose.
- **Concrete change:** In `dispatch-mechanics.md:36-53`, replace the bash block with:
  ```bash
  OUT=./out/$(date +%Y%m%d-%H%M%S)
  mkdir -p "$OUT"
  
  # Per-model timeout in seconds. 300 for code review, 600 for research.
  # Use gtimeout (brew install coreutils) on macOS, timeout on Linux.
  TIMEOUT=600
  TIMEOUT_CMD="timeout"
  if [[ "$(uname)" == "Darwin" ]] && command -v gtimeout &>/dev/null; then
    TIMEOUT_CMD="gtimeout"
  fi
  
  for model in opencode-go/minimax-m3 opencode-go/qwen3.7-max opencode-go/glm-5.2; do
    slug=$(echo "$model" | cut -d/ -f2)
    $TIMEOUT_CMD "$TIMEOUT" npx -y opencode-ai run \
      --model "$model" \
      --title "multi-ai-task-${slug}-$(date +%s)" \
      --dangerously-skip-permissions \
      "$PROMPT" \
      > "$OUT/${slug}.md" 2> "$OUT/${slug}.err" &
  done
  wait
  echo "Outputs in $OUT/"
  ```
  And remove the prose paragraph on line 62.
- **Effort:** Low (edit 1 file, ~10 lines)
- **Impact:** High (prevents the most common silent failure mode in the default mechanism)
- **Score:** **High ROI**

### 3. Lead with the default in the `most-severe` rule documentation

- **Issue:** `consolidation-rules.md:167-172` describes the `allow_downgrade: true` option before stating the default. A skimming reader sees "may declare allow_downgrade to downgrade" and assumes that's the default behavior. The default is the opposite. `most-severe` is the default rule for code-review severity — the most common non-research use case — so this misleads the reader most likely to actually use it.
- **Why it matters:** Misleading prose on a core algorithm → wrong implementation in user code.
- **Concrete change:** In `consolidation-rules.md:167-172`, restructure to:
  ```markdown
  #### `most-severe`
  
  - **Purpose:** pick the most-severe value across models (default for code-review
    severity, security audit findings).
  - **Input:** List of `(value, severity_order?)` per model. If `severity_order` is
    declared in the schema, use it. Otherwise default to:
    `["blocker", "major", "minor", "nit"]` (most-severe first).
  - **Algorithm:** `min(values, key=severity_order.index)` — index 0 = most-severe.
    Ties broken by `majority` among the max-severity tier. If N=0, return `null`.
  - **Default behavior:** the most-severe value wins even if only 1 reviewer reported
    it. This matches the code-review safety principle: "don't downgrade a blocker
    just because one reviewer missed it."
  - **Optional override:** set `"allow_downgrade": true` in the schema's
    `conflict_resolution` to downgrade a lone max-severity value (1 of N with no
    evidence quote) to the next tier. Use only when the task context requires
    conservative consensus (e.g., security audit with high false-positive risk).
    Default: `false`.
  - **Edge case (default behavior):** if 1 of N reviewers says `blocker` and the
    rest say `major` (or lower), and the lone `blocker` has no evidence quote, the
    `blocker` WINS. The schema's `allow_downgrade: true` is the only way to change
    this.
  ```
- **Effort:** Low (reorder existing prose)
- **Impact:** High (core algorithm documentation, used in the most common non-research use case)
- **Score:** **High ROI**

### 4. Add a worked output excerpt to the research-prior-art example

- **Issue:** `research-prior-art.md:154-167` lists the section headings of `consolidated.md` but shows no actual table rows, conflict resolution example, or scoring matrix. The only proven example in the entire skill doesn't show what the output looks like.
- **Why it matters:** A reader evaluating the skill needs to see the output format to decide if it's useful. The research run produced 36 unique items, 8 conflict resolutions, and a 5-dimension scoring matrix — all of which would be a 30-line excerpt. Without it, the reader has to navigate to `docs/research-260624/` separately.
- **Concrete change:** In `research-prior-art.md`, after line 167, add:
  ```markdown
  ### Output excerpt (from the 2026-06-27 run)
  
  **§2 Items Table (first 3 rows, abbreviated):**
  
  | # | Item | Mentions | Category | Score (median) | Range | Primary Source |
  |---|------|---------:|----------|---------------:|-------|----------------|
  | 1 | LangGraph | 6/6 | adjacent | 3 | 2-5 | https://github.com/langchain-ai/langgraph |
  | 2 | BMAD | 5/6 | adjacent | 4 | 3-6 | https://github.com/bmad-sim/BMAD-METHOD |
  | 3 | Camunda 8 | 4/6 | direct | 5 | 4-7 | https://camunda.com/platform/ |
  
  **§4 Conflict example:**
  
  | Item | Field | Disagreement | Resolution | Final | Confidence |
  |------|-------|-------------|------------|-------|------------|
  | LangGraph | category | mimo=`direct`, 4=`adjacent`, qwen=`tangential` | outlier downgrade (1/6 `direct`, no evidence) | `adjacent` | high |
  ```
  (Use real values from `docs/research-260624/SB_CONSOLIDATED_PRIOR_ART_REPORT.md` §2 and §4.)
- **Effort:** Low (edit 1 file, ~15 lines)
- **Impact:** Medium (makes the example self-contained; readers can evaluate without leaving the file)
- **Score:** **High ROI**

### 5. Move self-review artifacts out of the skill directory

- **Issue:** `self-review.md` (25.9K) and `critical-review-r3.md` (28.8K) are sitting in `skills/multi-ai-task/`. `SKILL.md:247` says self-reviews belong in `docs/research-260624/multi-ai-self-review-*/`. The review files in the skill directory are either stale (moved here temporarily and never moved back) or orphaned (intended for a different location and forgotten). Either way, they pollute the skill with 54K of meta-content that wasn't part of v2.0 or v2.1.
- **Why it matters:** A reader cloning the skill gets review artifacts they didn't ask for. A future implementer will assume these files are part of the skill (they're in the skill directory, after all) and may try to use them. Also: r3's findings remain in those files, but it's unclear if they were actioned — there's no CHANGELOG.md to check.
- **Concrete change:** Move `skills/multi-ai-task/self-review.md` and `skills/multi-ai-task/critical-review-r3.md` to `docs/research-260624/multi-ai-self-review-r2-20260627-093345/critical-review.md` (or to `docs/research-260624/multi-ai-self-review-r3-20260627-XXXXXX/`). Create `skills/multi-ai-task/CHANGELOG.md` summarizing what was addressed in v2.1 and what remains. Update `SKILL.md:247` to reference the canonical review paths.
- **Effort:** Low (move 2 files, write 1 new file, update 1 reference)
- **Impact:** Medium (removes skill directory pollution; provides a place for the v2.0 → v2.1 changelog that the skill currently lacks)
- **Score:** **High ROI**

---

# §4. Open Questions

1. **What is the actual version, and what changed in v2.1.0?** `SKILL.md` frontmatter says 2.1.0. `fact-check.md:77` references a v2.1.0 gap fix. The r3 review was on v2.1.0 and found 10/16 issues. There is no `CHANGELOG.md`. If 2.1.0 added `--no-auto-inject`, `aliases`, `phases_completed`, `schema_auto_injected`, and `consolidation`, that should be documented. If those features were already in 2.0.0, the frontmatter is wrong.

2. **Where is the reference implementation?** The skill is a set of Markdown rules. The algorithms are described in enough detail to implement (the named rule library is genuinely implementable), but every calling agent must re-implement them from prose. Is there a planned library? A test suite? A reference harness? If not, how do you know the prose is actually implementable? Has anyone implemented it?

3. **How does model selection actually work when `--models` is omitted?** `SKILL.md:73-75` says "queries the local OpenCode config... and picks a balanced default set of 4-6 models." No algorithm. No heuristic. No example. For a 20-model config, which 4-6 are picked? This is a behavioral contract with no spec.

4. **Is the skill a procedural document, a library, or a runtime?** `user-invocable: false` says it's not directly user-invoked. The bash snippets say the calling agent forks sub-shells. The "task-agnostic" claim says it works for any task. But each task type seems to require the calling agent to write a different bash invocation. Is the skill the rules, the bash template, or both? A clearer contract would help.

5. **What happens to the `score-aggregate.md` planning artifact?** `SKILL.md:227` documents `score-aggregate.md` as "(planned) but not in the contract." Was this deferred, abandoned, or rolled into §5 Aggregated Scores? The failure-modes table entry is the only mention. Add a note to the eventual `CHANGELOG.md` to either commit to it or drop it.

6. **Why does the research example's bash dispatch (lines 18-32) not pass `--schema`?** The example says the schema is passed separately (line 173: "the skill auto-injected it because `--no-auto-inject` was not passed") but the bash snippet doesn't show it. Is the schema passed as a file (`--schema /path/to/schema.json`)? An inline JSON string? The reader has to guess.

7. **What is the relationship between `totals.conflicts_resolved` and `consolidation.unresolved_conflicts`?** Both track conflict-related counts. `output-schema.md:228` defines `totals.conflicts_resolved` (an integer). `output-schema.md:233` defines `consolidation.unresolved_conflicts` (an integer). Are unresolved conflicts a subset of resolved ones? A separate set? The relationship is implicit.

8. **Why are code-review and fact-check worked examples deferred to v2.2.0 when v2.1.0 is "task-agnostic"?** The task-agnostic claim rests on one proven example. If v2.2.0 is needed to prove the other task types work, the v2.1.0 "task-agnostic" claim is unproven. Either downgrade the claim to "task-agnostic architecture, currently proven for research" or move the worked examples into v2.1.0.

9. **What does "Default is Mechanism 2" mean when Mechanism 1 is "preferred-if-available"?** `SKILL.md:191` and `dispatch-mechanics.md:9-30` together suggest "use Mechanism 1 if your harness allows; otherwise Mechanism 2." But the language is "Default is Mechanism 2" (SKILL.md) vs "preferred-if-available" (dispatch-mechanics). A single sentence stating the precedence explicitly would resolve this.

10. **What's the consolidation wall-time?** `SKILL.md:41` lists "Latency of slowest model + consolidation" as a constraint. For 36 items × 6 models, how long does Phase 3-4 take? The skill says nothing. Users can't evaluate the "When NOT to use" latency criterion without a bound.

---

# §5. Confidence

- **Overall confidence:** **High.**
- **What would change my assessment:** A reference implementation (a single executable script that produces a `consolidated.md` from 3-5 model outputs) would either validate the algorithms are implementable from prose alone, or reveal that the algorithms have hidden ambiguities the prose hides. Second, a worked code-review and fact-check run would validate or invalidate the "task-agnostic" claim — if the same extraction/dedup algorithms work cleanly on a second task type without per-task customization, the architecture is proven. Third, a `CHANGELOG.md` would clarify what v2.1.0 actually changed and whether the r3 findings were actioned.

**One important note:** This is the third round of self-review on the same file (round 2: `self-review.md`, round 3: `critical-review-r3.md`, this round 4). The r3 issues I confirmed as "still present" have been unaddressed across two review cycles. That suggests either (a) the skill maintainer is satisfied with 10/16, (b) the reviews are advisory and never actioned, or (c) the frontmatter `version: 2.1.0` was bumped without the corresponding code/doc changes. The presence of two review files *inside the skill directory* (rather than in `docs/research-260624/`) hints at option (b) — the reviews are write-once, never integrated. If the next iteration is to be useful, it should include a `CHANGELOG.md` and an action tracker (or a `KNOWN-ISSUES.md`) that explicitly says which r2/r3 findings are accepted, deferred, or dismissed.
