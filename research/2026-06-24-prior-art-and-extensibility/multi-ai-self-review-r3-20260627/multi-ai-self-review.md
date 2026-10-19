# Critical Self-Review: multi-ai-task Skill v2.1.0

**Reviewed:** 2026-06-27 (Round 3 — final)
**Reviewer:** The parent orchestrator, recursively
**Files reviewed:** 8 (SKILL.md + 5 rules + 3 examples)

---

## §1. Critical Assessment

### 1. SKILL.md

**What works well:**
- The when-to-use / when-not-to-use table (§When to use, §When NOT to use) is concrete and decision-oriented — not generic advice. Lines 35-50 are genuinely useful for triage.
- Proven provenance (§233-247) is honest about what was tested, what the folder-name quirk is, and what remains speculative. That level of candor is rare in skill docs.

**What is missing or wrong:**
- **Schema double-injection has no guard.** SKILL.md:146 says "by default, the skill appends a `## Required Output Schema` block to each dispatch prompt." If the user's prompt *already* embeds the schema (the research example prompt has `## 4. Required Output Schema` right in it) AND the user passes `--schema` separately AND does not pass `--no-auto-inject`, the schema is injected *twice*. The skill does not detect the schema already being present in the prompt. No `schema_already_in_prompt` check exists.
- **"Minimum viable: 2 models" contradicts the when-not-to-use rule.** dispatch-mechanics.md:164 says "Minimum viable: 2 models from different families. Below 2, the skill adds no value." But SKILL.md:50 says "You have ≤1 model available — no diversity to consolidate." The boundary case of exactly 1 model is *implicitly* a don't-use, but the math of what happens with 2 models and `majority-with-uncertain` (which always returns `unverified` with N=2, see consolidation-rules.md analysis below) means 2 models is also borderline useless for consensus tasks. The minimum should be `max(2, task-dependent)`.
- **Latency claims are unquantified.** The `thorough` mode notes "~3-5 min additional wall-time" (SKILL.md:83) but `standard` mode has no timing estimate anywhere. The when-not-to-use says "Latency is critical (single turn)" but doesn't define what latency to expect. A user reading this has no way to estimate cost.

**What is unclear or ambiguous:**
- **Default model discovery is underspecified.** SKILL.md:73: "queries the local OpenCode config (`~/.config/opencode/opencode.json` + `.jsonc`) and picks a balanced default set." There is no algorithm for "balanced" beyond the prose description. Does it prefer reasoning models? How does it resolve `.json` vs `.jsonc` priority? What if neither exists? This leaves the calling agent guessing.
- **The version tag is confusing.** The frontmatter says `version: 2.1.0` (line 6) but the provenance section (line 247) references "A round-2 self-review (v2.1.0)." This implies v2.1.0 pre-existed the round-2 review, which is chronologically impossible unless the round-2 review produced v2.1.0. The version lineage is unclear.

### 2. rules/methodology.md

**What works well:**
- The extraction pseudocode (Mode A, lines 37-64) is explicit fallback-by-fallback — extractors can implement it directly. The extractor-model selection note (line 53-54) correctly avoids the trap of asking a failed model to re-extract.
- Audit trail principle (lines 162-168) is clean: every step recorded, re-runnable.

**What is missing or wrong:**
- **Extractor model has an infinite regression when all models fail.** methodology.md:52-54 says the extractor is "the slowest/highest-capability model from the original dispatch" and at line 53-54: "NOT the model that produced the response — that model has already failed to produce structured output, asking it again is unlikely to help." But if *every* model (including the designated extractor) produced non-structured output, the extractor is asked to extract *its own* response — violating the "NOT the model that produced the response" rule. There is no termination condition for when the extractor also fails.
- **Mode B is fragile for non-space-separated languages.** methodology.md:98: "First 5 words = primary_key (fragile; flag fuzzy_match:true)." For Chinese, Japanese, Korean — languages without space tokenization — "first 5 words" is undefined. The skill claims to be task-agnostic and shouldn't silently break on CJK input.
- **Row validation is silent.** methodology.md:69-72 validates rows and says "drop row if missing" / "drop invalid rows" but doesn't say whether this is logged to `structured.jsonl`, `conflicts.md`, or only reported in `run-manifest.json → totals`. Row drops are lossy and must be auditable.

**What is unclear or ambiguous:**
- **"Extractor model" is not a selectable parameter.** methodology.md:104 says the extractor is "Default: the slowest, highest-capability model from the original dispatch (caches the response, no extra cost). Override via the implementation; not a CLI parameter." This means different implementations may pick different extractors, making consolidation non-reproducible across harnesses. There's no "extractor" field in `run-manifest.json` to record which model was used.
- **Phase numbering is inconsistent.** The file ends with "Idempotent re-runs" (line 173) but never mentions Phase 3.5 or 3.6 — those appear only in consolidation-rules.md. A reader of methodology.md alone thinks the pipeline has 4 clean phases; the sub-phases in consolidation-rules.md are invisible.

### 3. rules/dispatch-mechanics.md

**What works well:**
- The parallel vs sequential decision table (lines 99-106) is pragmatic and covers the MCP port collision issue explicitly — rare for dispatch docs.
- Known bugs documented inline (Issue #18615 at line 79, the `task` tool limitation at lines 28-30) — preventing users from debugging the same issues repeatedly.
- Failure-handling table (lines 124-133) is concrete and covers the most common failure modes observed in the proven run.

**What is missing or wrong:**
- **Mechanism 4 loses tool access without warning.** dispatch-mechanics.md:81-93 describes "Direct HTTP to provider API" as "Highest control" but doesn't mention that models dispatched this way have *zero MCP/tool access* — no `webfetch`, no `gh`, no `ctx_fetch_and_index`. This fundamentally changes the models' capabilities vs Mechanism 1-3. A user switching from Mechanism 2 to Mechanism 4 gets silently degraded output.
- **Mechanism 1 is mostly aspirational.** dispatch-mechanics.md:9-30 describes the `task` tool approach but then immediately undercuts it: "Dynamic per-call model selection is a 6-time-requested feature... with one open PR (#29447); not yet released." (line 28). And "Some OpenCode harnesses restrict the `task` tool's `subagent_type` enum" (line 30). The preferred mechanism doesn't work for most users.
- **The `npx -y opencode-ai run` package is an unverified assumption.** dispatch-mechanics.md:45 uses `npx -y opencode-ai run`. The actual bin name for the OpenCode CLI is `opencode`, not `opencode-ai`. If `opencode-ai` is not an npm package name, this entire mechanism fails silently with `npx` downloading a wrong/different package.

**What is unclear or ambiguous:**
- **"$PROMPT" vs file-path arguments.** In the research example, `"$PROMPT"` is a string variable. In the code-review example (code-review.md:39), `"$OUT/prompt.md"` is a file path. Which does `opencode run` accept? If it accepts both, the behavior difference (string vs file read) changes how the prompt reaches the model. Not documented.
- **`--dangerously-skip-permissions` naming.** The flag name is alarming and the doc says "do NOT use this flag for write tasks" (dispatch-mechanics.md:59). But there's no *safe* equivalent for read-only tasks — users who want a non-interactive read-only dispatch are forced to use a flag named "dangerously." This is a UX (not skill) issue, but it affects skill adoption.

### 4. rules/consolidation-rules.md

**What works well:**
- Named rule library (lines 165-221) is genuinely good: each rule has algorithm pseudocode, edge cases, and a concrete example. `most-severe` with `allow_downgrade` and `severity_order` is thoroughly specified.
- The minimal contract for consolidation (lines 7-23) correctly separates the generic mechanism from the task-specific item semantics.
- Score aggregation (lines 249-256) is clean: median, range, N. No over-engineering.

**What is missing or wrong:**
- **Composite key handling is absent from the dedup algorithm.** consolidation-rules.md:94-111 shows the canonical dedup algorithm using `row.primary_key`. But the schema spec says composite keys are expressed as multiple `dedup_key: true` columns (SKILL.md:143). The algorithm never shows how to hash a `(file, line)` tuple into a single canonical key. The code-review example (code-review.md:68) explicitly says composite keys are the correct form, but the algorithm can't process them.
- **`majority-with-uncertain` silently fails for N=2.** consolidation-rules.md:180-185: threshold = `max(2, ceil(N/2))`. For N=2: ceil(2/2)=1, max(2,1)=2. To reach the threshold of 2, *both* models must agree. If models disagree (which is why you're running multi-model), the threshold is never met and `unverified` is always returned. For N=2, `majority-with-uncertain` is mathematically equivalent to "require unanimity." This should be explicitly documented so users don't dispatch 2 models for fact-check and get 100% `unverified`.
- **Phase numbering is broken.** The file has Phase 2 (line 26), Phase 3 (line 78), Phase 3.5 (line 136), Phase 3.6 (line 266). Phase 1 and Phase 4 are in methodology.md. Phase 3.1-3.4 don't exist. This numbering implies a taxonomy that was never filled in.
- **No within-model dedup.** The dedup algorithm (lines 96-111) only deduplicates *across* models. If a single model lists the same item twice (e.g., once in a "top picks" section and once in a "full list" section), those duplicate rows both enter the registry. No check for `same model + same primary_key`.

**What is unclear or ambiguous:**
- **`lowest-of-majors` confidence ordering.** consolidation-rules.md:190: "return the lowest confidence (`high > medium > low`)." The notation `high > medium > low` means `high` is ranked *above* `medium` above `low`. "Lowest confidence" would be `low` (least confident). But the text says "lowest confidence among the majority voters" — if three voters say `true` with confidences `high, medium, high`, the result is `medium`. That's correct. The ambiguity is that the arrow notation `>` was used for *preference ranking* not *confidence value*, which is the inverse. Clarify: "`high` is most confident, `low` is least confident."
- **Alias map format is ambiguous in the example.** consolidation-rules.md:333 says "Document the alias map in your run's `run-manifest.json → aliases`" but the example at output-schema.md:225 shows `"aliases": {"AutoGen/AG2": "AutoGen"}` — is the key `"AutoGen/AG2"` a slash-delimited list of aliases, or is it literally the string `"AutoGen/AG2"`? The research example (research-prior-art.md:125-140) uses a table with pipe-separated aliases. The JSON format and table format are inconsistent.

### 5. rules/output-schema.md

**What works well:**
- Two output modes clearly separated (Mode A = schema-driven table, Mode B = generic narrative). Lines 7-17 resolve the "what format will I get?" question.
- Markdown formatting rules for WYSIWYG viewers (lines 258-269) are specific and testable — not hand-waving.
- `run-manifest.json` has a complete field-semantics table (lines 239-254) — one canonical location, no duplication.

**What is missing or wrong:**
- **§2A and §2B are presented as both present, not alternatives.** output-schema.md:53-97 — the section numbering implies the report contains *both* §2A and §2B, but they're mutually exclusive based on whether a schema was passed. An implementer reading sequentially would include both. The file header (lines 23-35) correctly distinguishes mode A vs B; the section numbering should follow suit.
- **`evidence-ledger.md` and `verification.md` are in the SKILL.md output tree but never specified.** SKILL.md:170-171 lists these files as thorough-mode outputs. output-schema.md mentions them nowhere — not their format, schema, or relationship to `consolidated.md` §4. An implementer of `thorough` mode has no specification to work from.
- **`consolidated.html` specification is missing.** SKILL.md:174 says it's generated "using a markdown library... Embed minimal CSS inline." But output-schema.md has no CSS specification, no HTML structure, no conflict-marker rendering rules. The HTML output is undefined.
- **`run-manifest.json` alias field format is inconsistent.** output-schema.md:225 shows `"aliases": {"AutoGen/AG2": "AutoGen"}` as a single key-value pair. But consolidation-rules.md and the research example show multi-entry alias tables. The single-entry example is misleading — the field should be an object with multiple string→string mappings, not a string→string with a slash in the key.

**What is unclear or ambiguous:**
- **Version-tagging in `run-manifest.json`.** output-schema.md:245 tags `schema_auto_injected` with `(v2.1.0+)`. But if the report itself embeds a `skill_version` field, this per-field version tagging is unnecessary. Currently, `run-manifest.json` has no `skill_version` field. A consumer of `run-manifest.json` has no way to know which schema version produced it.
- **"Exact template" vs "example" blur.** The items table format (§2A, lines 59-63) shows a 6-column table with `# | Item | Mentions | Fields per model | Primary Source | Top Finding`. But the research example (research-prior-art.md:154-165) lists §2 as "Items Table (15-30 rows, one per distinct tool/framework/paper)" — different columns entirely. Which columns are mandatory and which are task-specific? The output-schema is supposed to be the canonical source but the examples override it.

### 6. rules/examples/research-prior-art.md

**What works well:**
- The alias map (lines 125-140) is concrete, complete, and demonstrates exactly what "semantic dedup" means — far better than the abstract description in consolidation-rules.md.
- The scoring rubric JSON (lines 104-119) maps 1:1 to the 8-dimension rubric used in the self-review, proving the schema format is composable.

**What is missing or wrong:**
- **The 9-section prompt template (lines 37-68) is presented as a single code block but contains both template *structure* and user-specific *content*.** Lines 42-67 mix `[subject description, table of layers...]` placeholders with instructional sections like "## 3. Disambiguation Rules." A user cannot copy-paste this template; they must mentally separate template from content. This is a document for reading, not for use.
- **"The schema (passed as --schema)" section shows the schema but does not show the `--no-auto-inject` flag.** The research example prompt already contains `## 4. Required Output Schema` (line 52). If the user passes this same JSON as `--schema` AND does not pass `--no-auto-inject`, the schema is injected twice. The example should demonstrate the correct flag usage.
- **Skip rules duplicate consolidation-rules.md.** research-prior-art.md:144-148 lists "also drop: The reference subject's own name" and "Pure scoring-matrix header rows." These are the same skip rules defined in consolidation-rules.md:116-119. Duplication risks divergence.

**What is unclear or ambiguous:**
- **"Diminishing returns past 6" claim is unsubstantiated.** research-prior-art.md:182: "8-10 models captures more unique finds but diminishing returns past 6 (this is an empirical observation, not a measured curve — run your own benchmark if you want a hard number)." If the observation is empirical, where is the data? If there's no data, remove the claim. The parenthetical disclaimer "not a measured curve" makes the statement non-falsifiable — it's either a finding or it's not.

### 7. rules/examples/code-review.md

**What works well:**
- Composite key example (lines 68-70) explicitly calls out and corrects a common mistake: using `"primary_key": "file:line"` (string form) vs multiple `dedup_key: true` columns. This prevents a whole class of implementation errors.
- Custom severity ordering (lines 72-78) shows how to extend `most-severe` with a custom severity like `critical` — practical, not theoretical.

**What is missing or wrong:**
- **"Worked example: Not yet produced (deferred to v2.2.0)"** (line 111). An example recipe that hasn't been executed isn't an example — it's a design document. This should not be in `rules/examples/` until proven. At minimum, the deferred status should be called out in the filename or a frontmatter field.
- **Security note is incomplete.** code-review.md:46 says "code review is a read-only task — the models just read and report, they don't write." But models dispatched with `opencode run` have the `write` tool available by default. Nothing in the prompt or the schema prevents a model from writing a findings report to the user's working directory. The example dispatch doesn't pass `--dangerously-skip-permissions`, which means the model *will* prompt for write permission — but if the user is running unattended, this could hang. Either the prompt should explicitly forbid writes, or the dispatch should note that `--dangerously-skip-permissions` is needed for unattended read-only runs (contradicting the general advice at dispatch-mechanics.md:59).

**What is unclear or ambiguous:**
- **Does `opencode run` accept a file path or prompt text?** code-review.md:39 passes `"$OUT/prompt.md"` as the prompt argument. research-prior-art.md:29 passes `"$PROMPT"` as a string variable. These are different argument types. If `opencode run` treats a file-path argument differently (reads the file vs treats it as literal text), the examples are inconsistent. If it treats them the same (both as prompt text), the code-review example sends the literal string `./multi-ai-out/2026.../prompt.md` as the prompt, which is wrong.

### 8. rules/examples/fact-check.md

**What works well:**
- The consensus threshold is parameterized correctly (lines 103-109): `≥ max(2, ceil(N/2))` and the per-N examples (N=3→2, N=5→3, N=7→4) make it concrete.
- `majority-with-uncertain` behavior is correctly explained for the fact-check use case — this is the canonical example of *when* to use that rule.

**What is missing or wrong:**
- **"Worked example: Not yet produced (deferred to v2.2.0)"** (line 113) — same gap as code-review. Both non-research examples are unimplemented. This means the skill's claim of "task-agnostic" is supported by exactly *one* task type (research) with actual execution evidence.
- **"The '3+ models' rule in the original draft was a typo"** (line 109) — this version-history note belongs in a changelog or commit message, not in the current example. A reader encountering the skill for the first time should not see internal draft corrections.
- **"sources: url_list is now formally defined in the schema spec (was a v2.1.0 gap)"** (line 77) — same issue. If v2.1.0 fixed this gap, the example is v2.1.0, so the gap note is stale. If the example was written before the fix and not updated, it's wrong.

**What is unclear or ambiguous:**
- **`counter_evidence` field has no conflict resolution strategy.** fact-check.md:67 uses `conflict_resolution: { verdict: "majority-with-uncertain", confidence: "lowest-of-majors" }` but doesn't specify a resolution for `counter_evidence`. The consolidation-rules.md default for text fields is `longest-with-quote` (line 150), but that's a bad fit for counter-evidence — multiple reviewers might find *different* counter-evidence, and you want all of it. The custom strategies table (lines 93-99) says `counter_evidence: "concatenate-all"` but this isn't in the schema JSON. A user copying the schema JSON gets the wrong default.

---

## §2. Score the Skill on the 8-Dimension Rubric

| Dimension | Score | Justification |
|-----------|-------|---------------|
| **Catalog of composable units** | **1** | Named rules (`most-severe`, `majority-with-uncertain`, etc.) exist as prose algorithms in `consolidation-rules.md:165-221` — they are catalog-like and composable. But they are not machine-readable (no JSON schema for the rule library; no way for a program to discover available rules without parsing markdown). Score 1 ("informal roles"), not 2 ("machine-readable catalog"). |
| **Dynamic composition** | **1** | Users can pass `--schema` to define columns, dedup keys, and conflict rules — a form of replanning. But there is no catalog-backed lookup ("I want a code-review schema" → picks appropriate columns and rules automatically) and no audit log of composition decisions. Score 1 ("replanner"). |
| **V-loop depth** | **1** | Phase 4 produces the output artifact, which functions as an end test (did consolidation succeed?). But there is no per-step rollup (Phase 2 extraction results are not verified before Phase 3 consolidation) and no intent gate (no check that `consolidated.md` actually answers the user's prompt). Thorough mode adds cross-source verification but only for source claims, not for intent alignment. Score 1 ("end tests"). |
| **Enforcement** | **0** | Entirely honor system. The skill is a markdown document agents read and follow voluntarily. No CI tests enforce correct extraction, no IDE hooks validate schema correctness, no delivery blockers prevent publishing a malformed `consolidated.md`. The consolidation rules exist only as prose; there's no automated validator. Score 0 ("honor system"). |
| **Parent/worker split** | **2** | Explicitly designed: the calling agent (parent) dispatches N worker models, captures their output, runs consolidation, and produces the merged artifact. The contracts are clear: workers receive a prompt + optional schema injection, return a response; parent handles extraction, dedup, conflict resolution, synthesis. `run-manifest.json` tracks exactly which models were workers and what they produced. Score 2 ("explicit orchestrator/worker"). |
| **Evidence model** | **2** | Three-tiered: (1) per-model source refs (`source_refs` in structured.jsonl), (2) per-item per-field model attribution in conflicts.md, (3) thorough mode adds `evidence-ledger.md` with per-claim source URL + verification verdict + `source_verified: true|false|wrong` flag. Staleness is tracked via `last_verified` date field in the schema. Score 2 ("tiered sufficiency + staleness"). |
| **SE + DevOps unified** | **1** | By design, the skill is task-agnostic and covers both software engineering tasks (code review, bug finding) and infrastructure-adjacent tasks (research, fact-check, decision support). However, the *model* treats them identically — there's no domain adaptation layer. A code-review consolidation and a fact-check consolidation use the same pipeline with different schemas, but the schema format is the same for both. Not a truly unified model, just a single model that happens to span both domains. Score 1 ("both are accommodated but not unified"). |
| **Team customization** | **1** | Teams can customize via `--schema` JSON (defining their own columns, conflict rules, dedup keys) and via task-type recipes (`rules/examples/`). But there are no "overlay packs" — no way to distribute a team's preferred schemas, alias maps, and conflict rules as a reusable package. Each team must fork the examples or write their own schemas from scratch. Score 1 ("fork required"). |

**Total: 9/16**

(Note: the prior self-review scored 7/16. The delta to 9/16 reflects the v2.1.0 formalization of the named rule library, the evidence-ledger for thorough mode, and clearer parent/worker split documentation — but enforcement remains 0 and dynamic composition remains at replanner-level.)

---

## §3. Top 5 Improvements (ranked by impact × effort)

### #1. Composite key handling is missing from the dedup algorithm

- **Issue:** The canonical dedup algorithm at `consolidation-rules.md:94-111` uses `row.primary_key` but the schema spec defines composite keys as multiple `dedup_key: true` columns, not a single primary_key field.
- **Why it matters:** The code-review use case (the most likely non-research use) requires `(file, line)` composite dedup — and the algorithm in the spec can't express it. Every implementer will have to invent their own key-serialization.
- **Concrete change:** Replace `consolidation-rules.md:97-98` with hash-based composite key construction.

Current (lines 96-98):
```js
for (const row of allRows) {
  const canonical = normalize(row.primary_key);  // apply aliases
```

Proposed replacement:
```js
for (const row of allRows) {
  // Composite key: if schema has multiple dedup_key columns, hash them.
  // Single key: use the lone dedup_key column directly.
  const rawKey = schema.dedupColumns.length === 1
    ? row.fields[schema.dedupColumns[0]]
    : schema.dedupColumns.map(c => `${c}=${row.fields[c]}`).join('||');
  const canonical = normalize(rawKey);  // apply aliases
```

- **Effort:** Low (clarify pseudocode; no new algorithm).
- **Impact:** High (fixes core algorithm for the code-review and fact-check use cases).
- **Score:** High

### #2. No verification that the consolidated output matches user intent (V-loop gap)

- **Issue:** Phase 4 produces `consolidated.md` but there's no step to check whether the output actually answers the user's original `task-prompt`. If all models misunderstood the task or converged on a wrong answer, the consolidation faithfully preserves the error.
- **Why it matters:** The skill's primary value is cross-model triangulation, but triangulation amplifies consensus errors as smoothly as it resolves disagreements. Without an intent gate, the user could receive a high-confidence consolidated output that is confidently wrong.
- **Concrete change:** Add Phase 5 to `methodology.md` (after line 148, before "Cross-cutting principles"):

```markdown
## Phase 5 — Intent verification (standard + thorough modes only)

After Phase 4 produces `consolidated.md`, a single verification check:

1. Extract the user's key question(s) from `task-prompt`
2. Ask the designated extractor model: "Does `consolidated.md` answer the following questions? Return YES/NO per question with a one-line justification."
3. If any question returns NO, append a `## Intent Gap Warning` section to `consolidated.md` listing which questions were not answered.
4. Record the verification result in `run-manifest.json → intent_verified: true|false`.

Skip in `quick` mode (user accepts the risk).
```

- **Effort:** Medium (adds 1 lightweight LLM call after consolidation; requires extracting questions from the prompt — but the extractor model already exists).
- **Impact:** High (prevents the worst failure mode: confident consolidated output that misses the point).
- **Score:** High

### #3. Schema double-injection with no guard

- **Issue:** SKILL.md says the schema is auto-injected into each dispatch prompt. If the user's prompt already contains a `## Required Output Schema` or equivalent block AND the user passes `--schema` AND does not pass `--no-auto-inject`, the schema is injected twice. The skill does not detect this.
- **Why it matters:** Double injection bloats the prompt, potentially pushing the schema past context-window limits (the research example schema alone is ~1.5 KB; doubled it's 3 KB). It also confuses models — "which schema is authoritative?"
- **Concrete change:** Add a pre-dispatch check to `methodology.md` Phase 1 (insert after line 15):

```markdown
**Schema duplication guard:** before auto-injecting, the skill checks the `task-prompt`
for an existing schema block (detects `## Required Output Schema`, `## Output Schema`,
`"type": "table"`, or `<structured>` tags within the prompt text). If found, auto-injection
is skipped and `run-manifest.json → schema_auto_injected` is set to `false` with
`"reason": "schema_already_in_prompt"`. The `--no-auto-inject` flag is still honored
as an explicit override (forces skip regardless of detection).
```

- **Effort:** Low (adds a string search in the prompt before dispatch; no new infrastructure).
- **Impact:** Medium (prevents a common configuration error; affects anyone who follows the research example template).
- **Score:** Medium

### #4. Extractor model infinite regression with no termination condition

- **Issue:** methodology.md:52-64 defines a 4-path fallback for structured extraction. Path 3 calls the "extractor model" (defined as one of the dispatch models). Path 4 is a lossy paragraph-split. If the extractor model itself produced non-structured output AND all other models also failed, the algorithm asks the extractor to extract *its own response* from path 3 — then falls through to path 4 for the extractor's output. But there's no check for whether the extractor is being asked to extract itself, and no cap on recursion if path 3 fails.
- **Why it matters:** In the worst case (all models produce prose-only, no structure), the extraction loop wastes time asking models to re-format their own prose and falls through to a lossy paragraph-split anyway. The outcome is the same, but the wall time is longer and the `run-manifest.json` shows path-3-tried-and-failed when it should just use path 4 directly.
- **Concrete change:** Amend `methodology.md:51-60` (the extractor paragraph):

```markdown
   // 3. Fallback: ask the extractor model to reformat.
   //    The extractor model = the slowest/highest-capability model from the dispatch
   //    that DID produce a response (even if unstructured). Skip this path if:
   //    - Only 1 model responded (it IS the extractor — no separate reformatter available)
   //    - All models failed (no extractor candidate)
   //    In those cases, proceed directly to path 4 (paragraph fallback).
   if (availableModels.length >= 2) {
     const extractor = pickExtractor(availableModels);
     const extractorOutput = dispatchExtractorModel(extractor, response, schema);
     if (extractorOutput) return parseExtractorOutput(extractorOutput, schema);
   }
```

- **Effort:** Low (adds 2 guard conditions to existing pseudocode).
- **Impact:** Medium (prevents wasted calls in edge cases; clarifies the algorithm).
- **Score:** Medium

### #5. Worked examples for non-research tasks are unimplemented

- **Issue:** Both `code-review.md:111` and `fact-check.md:113` state "Worked example: Not yet produced (deferred to v2.2.0)." The skill claims task-agnosticism but has execution evidence for exactly one task type (research).
- **Why it matters:** The code-review and fact-check recipes are the primary "different task type" validation. Without executed examples, the claim that the skill is task-agnostic is supported by design speculation, not evidence. The recipes may work in theory but fail in practice (e.g., if code-review models produce findings in prose paragraphs that the table parser can't extract).
- **Concrete change:** Either (a) execute at least one code-review run and one fact-check run and link the outputs, or (b) add a frontmatter field `verification: unverified` and a note at the top of each example:

```markdown
---
verification: unverified
note: "This recipe has not been executed end-to-end. Treat as design guidance, not proven practice."
---
```

If choosing (a), update the "Worked example" sections with paths to actual output. If choosing (b), be honest about the gap so users don't assume these are proven.

- **Effort:** High for (a) — requires executing multi-model runs. Low for (b) — adds frontmatter and a warning.
- **Impact:** Medium (for option b — honesty prevents false confidence; for option a — high, because it validates the claim).
- **Score:** Medium (for option b) / Medium-Low (for option a, given high effort)

---

## §4. Open Questions

1. **What is the intended audience?** The skill references OpenCode-specific mechanisms (Mechanism 1-3, `opencode run`, `task` tool) heavily, but Mechanism 4 says "A different harness entirely" is supported. Is this skill meant for OpenCode users only, or is the OpenCode-agnostic claim aspirational? The answer determines whether Mechanism 4 needs a full write-up (with tool-access parity) or can remain a stub.

2. **What is the release cadence and versioning strategy?** The frontmatter says `version: 2.1.0`. The code-review and fact-check examples say "deferred to v2.2.0." What goes into v2.2.0 vs v2.1.x? If v2.2.0 is the next feature release, when? The provenance section references "round-2 self-review (v2.1.0)" — was v2.1.0 the output of that review, or the input? Having a `CHANGELOG.md` or `VERSIONING.md` would resolve this.

3. **Should `mode: thorough` be a separate skill or a mode?** Thorough mode adds cross-source verification — a fundamentally different operation (sending a verifier model to check each claim against its source). This is closer to "fact-check augmentation" than "deeper consolidation." Does it belong in the core skill, or should it be a separate `verify-claims` skill that consumes `multi-ai-task` output?

4. **How should the skill handle streaming vs batch output?** The methodology assumes models produce a single complete response. But some models stream output, and `opencode run` may produce partial output if the shell timeout fires. What's the contract for partial output? The failure-handling table says "Copy the stray file to output dir" but doesn't say how to detect partial vs complete.

5. **What is the maximum schema size that can be auto-injected?** The research example schema is ~1.5 KB (16 columns). If a user defines a 50-column schema, auto-injection adds ~5 KB to each dispatch prompt. At what point does schema injection overflow model context windows? Should there be a `max_schema_bytes` guard?

6. **Is the skill intended to be invoked by agents or by end-users?** The `user-invocable: false` frontmatter field says no, but the CLI usage example (`/multi-ai-task`) looks like a user-facing command. If it's agent-only, the CLI syntax section is misleading. If it's user-facing, `user-invocable: false` is wrong.

---

## §5. Confidence

- **Overall confidence:** **Medium**

- **What would change my assessment:** Executing the skill on the two non-research task types (code review and fact-check) and comparing the outputs against the recipes' expectations. If the extraction pipeline works on code-review findings (which are more likely to be prose paragraphs than tables) and fact-check claims (which have per-field resolution requirements that differ from research), the "task-agnostic" claim holds. If extraction fails or conflict resolution produces wrong results for those task types, the skill is effectively single-task (research) with a thin generalization layer.
