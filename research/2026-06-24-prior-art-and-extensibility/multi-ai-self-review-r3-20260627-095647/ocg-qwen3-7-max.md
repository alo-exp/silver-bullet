Let me check for some cross-file consistency issues and specific patterns.
Now let me check one more cross-reference issue:
---

# Critical Self-Review: `multi-ai-task` Skill

## §1. Critical Assessment

### File 1: `SKILL.md`

**What works well:**
- The "When to use / Don't use" table (lines 36-42) is genuinely useful decision-support — concise and covers the main tradeoffs.
- The `--schema` parameter section (lines 86-156) is the most complete and well-structured part of the entire skill, with supported types, fields, and examples all in one place.

**What is missing or wrong:**
- **`primary_key` as a top-level schema field is used here** (line 97: `"primary_key": "item"`) but the code-review example (`code-review.md:70`) explicitly calls this pattern *wrong*: "The string-form `primary_key` is not a recognized schema field." This is a direct contradiction between the SKILL.md and one of its own examples.
- **`--concurrency` is a phantom parameter.** Declared at line 4 and line 69 as a CLI argument, but no dispatch script in `dispatch-mechanics.md` or `methodology.md` ever reads or respects it. The dispatch scripts all use shell `&` for parallel. There is no mechanism by which the skill honors `--concurrency sequential` — it's a dead flag.
- **`evidence-ledger.md` vs `verification.md`** (lines 171-172): both listed as thorough-mode outputs with near-identical descriptions ("per-claim source URL + verification verdict" vs "per-item source verification"). Neither `methodology.md` nor `output-schema.md` defines the content of `verification.md` or how it differs from `evidence-ledger.md`. One of these files is likely redundant.

**What is unclear or ambiguous:**
- **`consolidated.html` generation** (line 175): lists three different libraries across two languages (`marked`, `markdown`, `pandoc`) with no recommendation. Who generates this — the orchestrating agent or each dispatched model? When in the pipeline?
- **Cost estimation**: line 40 says "Cost of N× compute is acceptable" as a use criterion, but provides no mechanism or formula for estimating that cost before dispatch.

---

### File 2: `rules/methodology.md`

**What works well:**
- The 4-fallback extraction chain (Mode A, lines 38-64) is well-designed: table parse → structured tags → extractor model → paragraph split. Clear degradation path.
- The `run-manifest.json` schema (lines 149-174) is the most complete version across all files.

**What is missing or wrong:**
- **`run-manifest.json` schema contradicts `output-schema.md`.** The methodology version (lines 149-174) includes `schema_auto_injected`, `aliases`, `consolidation`, and `phases_completed`. The output-schema.md version (lines 209-227) includes `schema` (the actual schema object) but **omits** `schema_auto_injected`, `aliases`, `consolidation`, and `phases_completed`. These are two different schemas for the same file, and neither references the other as canonical.
- **Mode B `<structured>` tags are undefined.** Line 152 says "Ask each model to wrap its response in `<structured></structured>` tags containing a JSON list" — but the internal JSON format is never specified. What schema does the JSON list follow? The extraction pseudocode for Mode B (lines 79-99) doesn't include a `<structured>` tag parsing path at all.
- **`task_prompt_hash`** (line 182): described as "useful for cache lookup" but the skill explicitly states "It does NOT cache across runs by default" (line 208). The hash serves no functional purpose in the current design.

**What is unclear or ambiguous:**
- **Extractor model selection** (line 104): "the slowest, highest-capability model from the original dispatch" — how is "slowest" determined at runtime? Wall-clock time from Phase 1? Config-declared model tier? This is not implementable as written.

---

### File 3: `rules/dispatch-mechanics.md`

**What works well:**
- The 4-mechanism hierarchy with clear preference ordering and "when to use" table (lines 167-177) is practical and well-organized.
- Honest documentation of known bugs and limitations (issue #18615, `task` tool restrictions, MCP port collision).

**What is missing or wrong:**
- **Mechanism 2 is the "default" but doesn't integrate with the skill's own parameters.** The dispatch scripts are raw bash loops — they don't read `--mode`, `--schema`, `--concurrency`, or `--no-auto-inject`. The skill documents these parameters but provides no runner script that wires them together. The gap between "the skill accepts `--schema`" and "here's how to pass it through `opencode run`" is entirely unbridged.
- **`--dangerously-skip-permissions` guidance is confused.** Line 56 says it's "fine for read-only tasks" but the code-review example (`code-review.md:45`) says the dispatch does NOT pass this flag for read-only code review. The fact-check example (`fact-check.md:50`) also omits it. So when IS it appropriate? The research example (`research-prior-art.md:27`) uses it for research, which is also read-only.
- **No dispatch script template exists.** Every example rewrites the bash loop from scratch with slight variations. There should be a canonical dispatch template that examples customize.

**What is unclear or ambiguous:**
- **Mechanism 3 (HTTP SDK)** references `client.session.promptAsync()` with no import path, no SDK version, and links to a known bug that makes it non-functional. This mechanism is aspirational, not usable.

---

### File 4: `rules/consolidation-rules.md`

**What works well:**
- The named rule library (lines 163-221) is the strongest part of the entire skill. Each rule has purpose, input, algorithm, and edge cases. This is genuinely implementable pseudocode.
- The alias/skip-rule separation (generic vs task-specific) is a clean architectural decision.

**What is missing or wrong:**
- **`most-severe` downgrade edge case is underspecified.** Line 171: "if 1/N reviewers disagrees with no evidence quote, downgrade the lone max to the next-severity tier." What if the severity is already at the lowest tier (`nit`)? What if N=2 and they disagree? The rule only handles the 1-of-N case, not 2-of-N or N/2-of-N.
- **`majority-with-uncertain` return value confusion.** Line 185 has a long parenthetical about renaming the return value to match the schema (`unverified` vs `partially-true`), ending with "Do NOT change the rule's return value to match the schema — change the schema to match the rule." This is backwards — the schema is the user's contract, and the rule should adapt. The advice to change the schema to match an internal implementation detail is wrong.
- **`prefer-with-evidence-then-newer-then-strict`** (lines 155-161): step 3 says "If 1 of 6 models says `direct` and 5 say `adjacent`, treat the lone `direct` as an outlier." But this is just `majority` with extra steps. The rule name implies evidence-weighted resolution, but step 3 degrades to simple majority. The "evidence" part (step 1) only fires if there's a primary quote — which models often don't provide.

**What is unclear or ambiguous:**
- **Fuzzy match threshold** (line 131): "≥80% similar (Levenshtein or token-overlap)" — these two metrics produce very different results. "LangGraph" vs "Langchain" is ~70% Levenshtein but 50% token-overlap. Which one to use changes the dedup behavior significantly.

---

### File 5: `rules/output-schema.md`

**What works well:**
- The WYSIWYG compatibility rules (lines 231-242) are unusually practical — they address real rendering issues that most specs ignore.
- The two-mode output structure (Mode A schema-driven, Mode B generic) is clean.

**What is missing or wrong:**
- **`run-manifest.json` schema is incomplete and contradicts `methodology.md`.** Lines 209-227 omit `schema_auto_injected`, `aliases`, `consolidation`, and `phases_completed` — all of which are documented as required in `methodology.md:149-174`. The methodology even says "The canonical schema lives in `rules/output-schema.md`" (line 147, emphasis mine) — but the version here is the less complete one.
- **§2A and §2B are confusingly named.** §2A is "Mode A — schema-defined table" and §2B is "Mode B — generic narrative." But §2A (line 57) also includes a default table for when no schema is provided: "When `--schema` is not provided, use the default items table." This means §2A covers both schema-provided AND no-schema cases, making §2B redundant or mis-scoped.
- **§3 Per-Item Details** (lines 100-116): provides "examples by task type" but these are just bullet-point sketches, not a schema. A code-review run and a research run would produce wildly different §3 sections with no structural contract.

**What is unclear or ambiguous:**
- **§8 Synthesized Verdict** (lines 162-164): "If the user asked for a specific output" — but the skill has no mechanism for the user to declare what output they want. This section is produced based on the orchestrator's judgment, not a schema field.

---

### File 6: `rules/examples/research-prior-art.md`

**What works well:**
- This is the only file backed by an actual run (2026-06-27, 6 models, 36 items). The provenance gives it credibility the other examples lack.
- The 14-entry alias map (lines 125-141) is concrete and reusable.

**What is missing or wrong:**
- **Schema uses `"primary_key": "name"`** (line 75) which the code-review example calls "not a recognized schema field." Either the research example is wrong, or the code-review example's claim is wrong. Both can't be right.
- **Scoring rubric dimensions** (lines 106-118) are specific to the Silver Bullet prior-art research task (catalog, dynamic, v_loop, enforce, etc.) — not generic. Presenting them in a "task-agnostic" skill's example without clearly labeling them as task-specific is misleading. A user copying this template would inherit SB-specific dimensions.
- **No consolidation timing data.** The example says "6 models dispatched in parallel" but doesn't report actual wall-clock time, per-model time, or token usage — data that would help users calibrate expectations.

**What is unclear or ambiguous:**
- **"Folder-name note"** (referenced from SKILL.md:244): the output folder is `docs/research-260624/` but the run was on 2026-06-27. This is documented but confusing — the example doesn't explain the convention inline.

---

### File 7: `rules/examples/code-review.md`

**What works well:**
- The composite key explanation (lines 68-70) is the clearest treatment of this topic across all files.
- The security note (line 45) correctly distinguishes read-only from write tasks.

**What is missing or wrong:**
- **Line 87 formatting error**: the line reads `- §4 Conflicts & Resolutions...` instead of `87: - §4...` — a numbering break in the file. Minor but indicates the file wasn't proofread.
- **Contradicts SKILL.md on `primary_key`.** Line 70: "The string-form `primary_key` is not a recognized schema field." But SKILL.md:97 uses exactly this pattern. The code-review example is correcting the SKILL.md, which means the SKILL.md is wrong.
- **No worked example.** Line 111: "Not yet produced (deferred to v2.2.0)." An example without an example is just a recipe nobody has cooked.
- **`--dangerously-skip-permissions` omission** (line 45): says the dispatch "does NOT pass" this flag, contradicting the research example which does pass it for an equally read-only task.

**What is unclear or ambiguous:**
- **Schema lacks `primary_key` field** but the research example and SKILL.md both use it. A user following the code-review example would produce a schema that doesn't match the other examples.

---

### File 8: `rules/examples/fact-check.md`

**What works well:**
- The `majority-with-uncertain` threshold parameterization (line 109: "For N=3, threshold = 2. For N=5, threshold = 3") is the clearest explanation of this rule anywhere in the skill.
- The consensus requirements section (lines 101-108) is concrete and actionable.

**What is missing or wrong:**
- **No worked example.** Line 113: "Not yet produced (deferred to v2.2.0)." Same issue as code-review.
- **`sources: "url_list"` note** (line 77): "is now formally defined in the schema spec (was a v2.1.0 gap)" — but the schema spec (`SKILL.md:125`) defines `url_list` without any version history. This note references a fix that isn't documented in the spec itself.
- **Only 3 models dispatched** (line 38) but `majority-with-uncertain` requires `max(2, ceil(N/2))` = 2 for N=3. This is the bare minimum — one model failure drops to N=2, where the threshold is still 2, meaning both remaining models must agree. This fragility isn't discussed.

**What is unclear or ambiguous:**
- **`counter_evidence` field** in the schema (line 64) has no conflict resolution rule specified. The custom strategies table (line 99) says `concatenate-all`, but the schema's `conflict_resolution` block (lines 66-69) doesn't include it — meaning the default rule (`longest-with-quote` for `text` type) would apply instead.

---

## §2. Score the Skill on the 8-Dimension Rubric

| Dimension | Score | Justification |
|---|---|---|
| **Catalog of composable units** | **1** | The named conflict-resolution rules (`most-severe`, `majority-with-uncertain`, `lowest-of-majors`, etc.) are well-defined composable units with algorithms and edge cases. But they exist only as prose in `consolidation-rules.md` — there is no machine-readable catalog (JSON registry, enum, or config) that a runner could enumerate. |
| **Dynamic composition** | **0** | The 4-phase pipeline is fixed. There is no replanner, no catalog-backed composition, and no audit log of composition decisions. The mode selection (`quick`/`standard`/`thorough`) changes phase *depth* but not phase *composition*. |
| **V-loop depth** | **0** | No verification loop exists within the skill. `thorough` mode adds a single-pass verifier call, not an iterative V-loop with rollback. There is no per-step rollup and no intent gate. The skill runs forward-only. |
| **Enforcement** | **0** | Entirely honor system. No CI gate validates that `consolidated.md` matches the schema. No IDE hook checks that `run-manifest.json` was produced. No delivery blocker prevents the orchestrator from skipping Phase 3. The skill documents what *should* happen but enforces nothing. |
| **Parent/worker split** | **1** | The orchestrator (parent agent) vs dispatched model (worker) distinction exists conceptually and is discussed throughout. But there is no formal contract — no defined interface for what the parent must provide or what the worker must return beyond the schema. The parent/worker boundary is implicit. |
| **Evidence model** | **1** | `source_refs`, `confidence_self`, and thorough-mode `evidence-ledger.md` provide informal evidence tracking. But there is no tiered sufficiency model (how much evidence is enough?), no staleness check (are sources still valid?), and no evidence-quality scoring. |
| **SE + DevOps unified** | **1** | The skill is task-agnostic and covers both SE-type tasks (code review) and research/analysis tasks. The examples demonstrate both. But the coverage is shallow — code review and fact-check examples have no worked runs, and the skill provides no task-type-specific defaults beyond what the user configures. |
| **Team customization** | **1** | The `--schema` and alias-map mechanisms allow per-run customization without forking the skill. But there is no "overlay pack" system — each run requires manual schema construction, alias map building, and conflict-rule selection. A team process pack (pre-built schema + aliases + rules for "code review" or "research") would be a significant improvement. |

**Total: 5 / 16**

---

## §3. Top 5 Improvements (ranked by impact × effort)

### 1. Fix the `primary_key` schema field contradiction

- **Issue:** SKILL.md:97 and research-prior-art.md:75 use `"primary_key": "name"` as a top-level schema field, but code-review.md:70 explicitly calls this "not a recognized schema field."
- **Why it matters:** A user following the code-review example will produce a schema incompatible with the research example and the SKILL.md's own example. This is the most confusing inconsistency in the skill.
- **Concrete change:** Either (a) add `primary_key` to the "Supported column fields" table in SKILL.md:129-141 and remove the "wrong" claim from code-review.md:70, or (b) remove `"primary_key"` from SKILL.md:97 and research-prior-art.md:75 and express all primary keys via `dedup_key: true` on columns. Option (a) is simpler — `primary_key` as a convenience alias for "the column with `dedup_key: true`."
- **Effort:** low
- **Impact:** high
- **Score:** high/low = **high ROI**

### 2. Unify the `run-manifest.json` schema across files

- **Issue:** methodology.md:149-174 and output-schema.md:209-227 define different schemas for the same file. methodology.md includes `schema_auto_injected`, `aliases`, `consolidation`, `phases_completed`; output-schema.md includes `schema` but omits the others.
- **Why it matters:** Implementers will produce inconsistent manifests depending on which file they read. The methodology.md even says "The canonical schema lives in `rules/output-schema.md`" — but the version there is less complete.
- **Concrete change:** Merge both versions into output-schema.md (add the missing fields from methodology.md), and have methodology.md:147 reference output-schema.md without reproducing the schema. Delete the duplicate JSON block from methodology.md.
- **Effort:** low
- **Impact:** high
- **Score:** high/low = **high ROI**

### 3. Remove or implement `--concurrency`

- **Issue:** `--concurrency` is declared as a CLI parameter (SKILL.md:4,69) but no dispatch script or methodology pseudocode reads or respects it. It's a dead flag.
- **Why it matters:** Users will pass `--concurrency sequential` expecting sequential dispatch and get parallel dispatch anyway (because the bash loop uses `&`). This is a correctness bug.
- **Concrete change:** Either (a) remove `--concurrency` from the argument-hint and inputs table, documenting parallel/sequential as a dispatch-mechanics choice (not a skill parameter), or (b) create a canonical dispatch template script that reads `--concurrency` and conditionally uses `&` or sequential `for` loop. Option (a) is faster.
- **Effort:** low
- **Impact:** medium
- **Score:** medium/low = **medium-high ROI**

### 4. Create a canonical dispatch template script

- **Issue:** Every example (research, code-review, fact-check) rewrites the bash dispatch loop from scratch with slight variations. There is no canonical template.
- **Why it matters:** The gap between "the skill accepts `--schema`" and "here's how to pass it through `opencode run`" is entirely unbridged. Users must manually wire schema injection, output capture, and failure handling.
- **Concrete change:** Create `rules/dispatch-template.sh` — a parameterized bash script that accepts `--models`, `--schema`, `--mode`, `--out`, and `--concurrency`, and generates the dispatch loop. Examples would then reference this template instead of inlining the loop.
- **Effort:** medium
- **Impact:** high
- **Score:** high/medium = **medium-high ROI**

### 5. Produce at least one more worked example

- **Issue:** Code-review and fact-check examples are recipes with no executed runs. Only the research example has proven provenance.
- **Why it matters:** Without worked examples, the code-review and fact-check schemas, conflict rules, and output structures are untested. The `most-severe` rule, composite keys, and `majority-with-uncertain` threshold have never been exercised end-to-end.
- **Concrete change:** Run the code-review example against a real PR (even a small one) with 3+ models, produce the consolidated output, and document any gaps or issues discovered. Update the example with the actual run data.
- **Effort:** high
- **Impact:** high
- **Score:** high/high = **medium ROI** (but high absolute value)

---

## §4. Open Questions

1. **Who is the audience?** The skill oscillates between "instructions for an orchestrating LLM agent" and "documentation for a human user configuring a multi-model run." The `--schema` parameter is clearly human-facing, but the methodology pseudocode is agent-facing. These audiences have very different needs.

2. **Is this skill a specification or a guide?** There is zero executable code. The pseudocode in methodology.md and consolidation-rules.md is detailed enough to implement from, but no implementation exists. Is the skill meant to BE the implementation (read by the agent at invocation time and followed as instructions), or is it meant to document a separate implementation that doesn't exist yet?

3. **What is the versioning strategy?** SKILL.md declares v2.1.0, the task prompt says v2.0.0, and examples reference "v2.2.0" for deferred work. Is there a changelog? What triggers a version bump?

4. **How does `thorough` mode select the verifier model?** SKILL.md:82 says "dispatch a verifier model" but doesn't specify which model, whether it's from the original dispatch set, or how to configure it.

5. **What happens when the schema and the model output are fundamentally incompatible?** The extraction fallback chain (table → tags → extractor → paragraphs) handles formatting differences, but what if a model returns 5 items and the schema expects 20? Or returns items that don't match any schema column? The "drop row" behavior is documented but the user experience of a 50% drop rate isn't addressed.

---

## §5. Confidence

- **Overall confidence:** **medium**
- **What would change your assessment:** Running the skill end-to-end on a non-research task (code review or fact-check) would likely surface implementation gaps that documentation review alone cannot find. The review above identifies structural and consistency issues; functional correctness of the consolidation algorithms is untested. Additionally, clarity on whether this skill is a specification-for-future-implementation or instructions-for-agent-execution would change how severely to judge the missing enforcement and dynamic composition dimensions.
