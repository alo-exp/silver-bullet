# Critical Self-Review: multi-ai-task Skill (v2.x)

**Reviewed by:** Self (meta-task using the skill's own methodology)
**Date:** 2026-06-27

---

## §1. Critical Assessment

### 1. SKILL.md

**What works:**
- The "What this skill does / does NOT do" tables (lines 15-29) are crisp and set correct expectations.
- The failure modes table (lines 218-228) is practical and battle-tested — specific symptoms mapped to actionable fixes.

**What is missing or wrong:**
- **Version inconsistency.** Frontmatter `version: 2.1.0` (line 6) but the review task prompt says "v2.0.0". No `CHANGELOG.md` or version history exists anywhere in the skill directory to resolve which is authoritative. `grep 'v\d+\.\d+\.\d+'` returns zero matches outside the frontmatter — there is no other version reference in the skill.
- **`argument-hint` format mismatch.** Line 4 says `--models m1,m2,...` (comma-separated inline) but every dispatch example across all files uses shell `for` loops with individual model names per iteration. No code path is documented for parsing the comma-separated argument. The default model discovery text (line 74) describes auto-selection but provides no pseudocode — it's hand-waving.
- **Repeated `--no-auto-inject` noise.** This flag is explained 4 times (lines 7, 28, 58, 70 in SKILL.md alone; also in methodology.md line 15). The repetition dilutes the document without adding clarity. A single reference in the inputs table with a pointer to methodology.md would suffice.

**What is unclear or ambiguous:**
- Line 153: "the slowest, highest-capability model from the original dispatch" — what metric determines "highest-capability"? Context window size? Benchmark score? Provider tier? This is a heuristic with no definition.
- Line 228: `score-aggregate.md` is listed as a failure-mode symptom for an "old spec inconsistency" but also says "Ignore for v2.x." If it's a v1 artifact that's been removed, why is it in the v2.x failure modes table at all? This table should only document active failure modes.

---

### 2. rules/methodology.md

**What works:**
- The 4-phase pipeline is well-scoped and the phase boundaries are cleanly defined.
- The pseudocode for extraction (lines 37-99) covers realistic fallback paths.

**What is missing or wrong:**
- **"Deterministic" claim is false.** Line 178: "Structured extraction (Mode A) is deterministic — pure parsing, no LLM in the loop." But Mode A's fallback path 3 (lines 55-59) explicitly calls `dispatchExtractorModel(response, schema)` — an LLM call. The extraction pipeline is *hybrid*, not deterministic. This mischaracterization could lead users to assume deterministic reproducibility.
- **`confidence_self` is orphaned.** The per-model extraction record (line 40 of consolidation-rules.md) includes `"confidence_self": "high|medium|low"` but this field appears nowhere else — not in the structured record in methodology.md (line 28, which omits it), not in the output schema, not in any consolidation step. It's declared in one file, used in zero.
- **No rule for how sections are ordered in free-form mode.** Line 133 says "a section per unique item" but the sort order is undefined. Are items sorted by mention count? Alphabetically? By model agreement? This matters for reproducibility.
- **`primary_key_raw` is extracted but never consumed.** The field appears in the extraction record (line 28: `"primary_key_raw": "**LangGraph**"`) but there's no downstream code that reads it — the dedup algorithm operates on `primary_key` (normalized). This is dead weight in the wire format.

**What is unclear or ambiguous:**
- Line 82: "H1 (#) is the document title, not an item" — this assumes a specific Markdown document structure. What happens if a model's output has no H1? Multiple H1s? An H1 that is semantically an item?
- Line 195: "future enhancement" for incremental consolidation — is this on a roadmap? No version, no issue tracker reference, no priority.

---

### 3. rules/dispatch-mechanics.md

**What works:**
- Excellent practical detail on all 4 mechanisms, including platform-specific gotchas (MCP port collision, `task` tool schema limitations, the `cut -d/ -f2` slug trick).
- The updated auth table (lines 137-146) is comprehensive.

**What is missing or wrong:**
- **No dependency validation.** Mechanism 2 (the default) requires `npx`, `opencode-ai` package, and Node.js. A user on a minimal Docker image or a Python-only machine gets an opaque error. The skill never validates these dependencies. There should be a pre-flight check or at minimum a documented dependency list.
- **Mechanism 3 bug is documented but not actionable.** Lines 75-76: "Known bug (2026-06): Issue #18615... model override" — the text says "Workaround: pass model on the server side via config" but doesn't show the workaround configuration. If a user hits this, they have to read the GitHub issue to find the fix.
- **Model selection strategy is unactionable.** Lines 155-161 say pick "≥1 reasoning-focused model" and "≥1 code-specialized model" but there is no taxonomy mapping the skill's default model pool to these categories. Which of `minimax-m3`, `qwen3.7-max`, `deepseek-v4-pro`, `glm-5.2`, `kimi-k2.6`, `mimo-v2.5-pro` is "reasoning-focused"? The user can't apply the advice.

**What is unclear or ambiguous:**
- Line 74 (SKILL.md): "queries the local OpenCode config" — how? What parsing logic? What happens if `opencode.json` doesn't exist, or `opencode.jsonc` has a syntax error? This is the default behavior path and it's entirely unspecified.
- Line 102: MCP port collision — is this a common failure or a rare edge case? The fix ("restart MCP between dispatches") is manual. Is there a way to detect collision and auto-fallback? If the skill knows about this failure mode, it should either auto-handle it or document it as a known limitation with a severity rating.

---

### 4. rules/consolidation-rules.md

**What works:**
- The named rule library (lines 170-224) is the file's crown jewel. Each rule has purpose, input spec, algorithm, and edge cases. This is implementable documentation.
- The conflict resolution documentation format (lines 228-237) is clear and example-driven.

**What is missing or wrong:**
- **Hardcoded alias map in core rules (lines 85-96) contradicts the task-specific guidance.** Lines 330-337 correctly state "The alias map is task-specific, not part of this skill's core" — but lines 84-96 show a hardcoded 5-entry alias map as example pseudocode. A casual reader will see this and assume the skill ships with these aliases. The example should be in the research example file, not the core rules.
- **Custom strategies table has broken rule references.** Line 310: `Use concatenate for comments` — should be `concatenate-all`. Line 311: `rank by median feasibility × impact score` — this is a computation (`median × median`? `Σ median`? `product per model then median`?) not defined anywhere in the rule library. It's not a named rule.
- **Floating maturity rules (lines 262-265) have no integration.** "For version-number disagreements, use the newer last_verified date" and "For 'beta' vs 'production' disagreements, use the project's most recent release tag" — these are conflict-resolution rules that exist outside the named rule library. They aren't referenced by any schema field and have no `conflict_resolution` config key. Either integrate them as named rules or remove them.
- **"Top N" is underspecified.** Line 282: "Top N by total = best matches" — what is N? Default 5? 10? Configurable? Is N the number of items or a count threshold? This matters for output determinism.

**What is unclear or ambiguous:**
- Line 136: "≥80% similar (Levenshtein or token-overlap)" — which one? These two algorithms produce different results. A string can be 80% similar by token overlap but 40% by Levenshtein. Pick one or specify the tie-break.
- Lines 116-125 skip rules: "The reference item itself" — how does the skill know which item is "the reference"? This is task-type knowledge that doesn't belong in a generic rule unless the schema declares a `reference_item` field, which it doesn't.

---

### 5. rules/output-schema.md

**What works:**
- The WYSIWYG markdown formatting rules (lines 233-241) are specific, enforceable, and vital for HTML render quality.
- The file header template (lines 23-35) captures machine-parseable metadata.

**What is missing or wrong:**
- **§2 is overloaded.** There are two independent §2 sections: "Items Table (Mode A — schema-defined table)" and "Items Table (Mode B — generic narrative)." Both are numbered §2. Any cross-reference saying "see §2" is ambiguous — the reader doesn't know which mode applies.
- **No version field.** Unlike SKILL.md (which has frontmatter `version: 2.1.0`), the output schema has no version identifier. If the schema evolves, there's no way to validate that a `consolidated.md` conforms to the schema version it was produced under.
- **Conflict marker rule is conditional with no condition.** Line 72 instructs `Use a code-span... if your viewer is WYSIWYG-strict; bare * otherwise` — but the skill is generating output, not displaying it. Which path should the implementation follow? This is a rendering concern leaking into the schema specification.
- **Rule 3 ("Never use triple-asterisk") contradicts Rule 1 ("Use code spans, not bold-italic").** Rules 1 and 3 describe overlapping behavior but disagree on what the safe alternative is. Rule 1 says code spans; Rule 3 says bold-then-asterisk with a space. Both can't be the canonical guidance.

**What is unclear or ambiguous:**
- Lines 184-189: "Bucket" in the Coverage Scoreboard is undefined. Are buckets derived from `category` enum values? From schema columns? From manual specification? A table with `Bucket 1`, `Bucket 2` as placeholders tells the user nothing.

---

### 6. rules/examples/research-prior-art.md

**What works:**
- Complete end-to-end blueprint: dispatch script, prompt template, schema, scoring rubric, alias map, output sections, and a pointer to the actual proven run. This is the gold-standard example.
- The alias map update instructions (line 142) are actionable.

**What is missing or wrong:**
- **Same-provider-family contradiction.** The dispatch script (lines 22-28) uses 6 models, all `opencode-go/*` — same provider family. SKILL.md line 162 explicitly warns "Avoid: dispatching >2 models from the same provider family" and SKILL.md says default selection requires "at least 2 different provider families." The proven run violates the skill's own guidance. Either the guidance is wrong (all-opencode-go is fine) or the proven run is suboptimal (and should be referenced with a caveat).
- **Alias map edit instructions are dangerous.** Line 142: "Add new aliases to this map as they surface in your runs" tells the user to edit the skill file. This file lives under `skills/multi-ai-task/rules/examples/` — it would be overwritten on any skill update. The correct instruction is "add aliases to your run's `run-manifest.json → aliases` field" as stated in consolidation-rules.md line 335.
- **Prompt template (lines 37-68) has no guidance on what's required vs task-type-specific.** A user copying this for a code-review task might include §7 "Constraints" (which is research-specific framing) and get confused when models produce research-oriented output.

**What is unclear or ambiguous:**
- Line 55: "prefer quotes" — what constitutes a "quote" for the `prefer-with-evidence-then-newer-then-strict` rule? Text wrapped in `"..."`, a `<blockquote>` element, indented text, or something else? The detection algorithm isn't specified anywhere.
- The scoring rubric (lines 105-118) has 8 dimensions clearly designed for evaluating multi-agent tools (catalog, dynamic, v_loop, enforce, parent_worker, evidence, se_devops, customization). Its presence in the research example suggests it's research-specific, but the task description uses it as a skill-evaluation rubric. Is this rubric generic or domain-specific?

---

### 7. rules/examples/code-review.md

**What works:**
- The custom strategies table (lines 76-83) provides clear per-field rule selection with rationale.
- The variations section (lines 84-89) gives practical extensions.

**What is missing or wrong:**
- **Worked example is absent.** Line 93: "Not yet produced. The pattern is identical to the prior-art research example." This is an unverified claim. Code-review items have different shape (file:line, severity, evidence quotes embedded in code blocks) than research items (name, url, category, scores). The claim that "the pattern is identical" ignores that the extraction pipeline needs to handle code blocks, inline code, and file paths — none of which the research example tests.
- **Schema doesn't declare the dedup key on columns.** The schema declares `"primary_key": "file:line"` at the schema level (line 40), but the individual column definitions (lines 42-48) don't include `"dedup_key": true` on either `file` or `line`. SKILL.md line 143 says "list multiple columns with `dedup_key: true`" — but the code-review example doesn't follow this pattern. The dedup key is declared at the schema root while the column-level mechanism is the documented approach. Which one is the actual implementation path?
- **2-model dispatch breaks majority rules.** Line 24 dispatches only 2 models. With 2 models and the `majority` rule for `category`, a 1-1 split produces NULL (no majority, per the algorithm at consolidation-rules.md line 182). The example doesn't address this. It should either dispatch ≥3 models or use a rule like `most-severe` (which has defined single-model behavior) for all fields.
- **"False-positive rate" (line 70) is aspirational.** Computing a false-positive rate requires ground truth (known bugs), which isn't available in a code review. Documenting this as an output section without a computation method is misleading.

**What is unclear or ambiguous:**
- Line 68: "how strongly" — this is not a field in the schema. Is it derived from severity? From reviewer count? From evidence presence? Undefined.
- Line 71: "Coverage Gaps" — what is a "gap"? Lines with 0 reviewer mentions? Lines not in the diff? Functions not analyzed? Computing coverage requires knowing the total surface area, which the skill doesn't model.

---

### 8. rules/examples/fact-check.md

**What works:**
- The consensus requirements (lines 90-96) define concrete vote thresholds, which is exactly what a fact-check user needs.
- The `unverified` enum value and the reluctance to force judgment is a good design choice for this use case.

**What is missing or wrong:**
- **Worked example is absent.** Line 99: same unverified claim as code-review.
- **Consensus threshold contradicts the algorithm.** Lines 92-93 say "3+ models agree on `true`" and "3+ models agree on `false`" but the dispatch uses only 3 models (line 29), and the `majority-with-uncertain` algorithm requires `≥ max(2, ceil(N/2))` votes, which for N=3 is `≥ 2`. The example's documented thresholds (≥3) are stronger than the algorithm it references (≥2). With 3 models dispatched, a "confirmed" verdict requires unanimity — not documented.
- **`counter_evidence` has no conflict resolution rule.** The field is in the schema (line 53) but not in the `conflict_resolution` config (lines 55-58). If model A provides counter-evidence and model B doesn't, what happens? The custom strategies table (lines 81-87) maps it to `concatenate-all` but the schema doesn't declare this.
- **Schema uses 3 models but "Proven provenance" expects 6.** The dispatch (line 29) uses 3 models while the proven research run used 6. The skill's guidance says 4-6. This example doesn't demonstrate the skill at its recommended scale.

**What is unclear or ambiguous:**
- "Partially-true" vs. "unverified" — the schema includes both as `verdict` enum values (line 49), but no rule distinguishes when to output one vs. the other. Is `partially-true` for mixed evidence from the same model, and `unverified` for no evidence? Or are they the same thing with different labels?
- Line 75: "Source Quality" as an output section — how is quality determined? Domain authority? Citation count? Manual review? This section is aspirational.

---

## §2. Score the Skill on the 8-Dimension Rubric

| Dimension | Score | Justification |
|-----------|-------|---------------|
| Catalog of composable units | **1** | The schema defines columns and types — an informal catalog. But there is no machine-readable catalog of extraction strategies, rule implementations, or conflict-resolution configurations. The named rule library is prose, not a registry. A JSON schema for rules would earn 2. |
| Dynamic composition | **2** | The `--schema` parameter enables dynamic composition — the pipeline adapts to any task by configuring columns, dedup keys, and conflict rules at call time. The `run-manifest.json` records the composition for audit. Catalog-backed + audit log. |
| V-loop depth | **1** | Phase 3 validates rows against schema constraints (required fields, type ranges, max words). Phase 4 produces `conflicts.md` documenting all resolutions. But there is no per-step rollup — the pipeline is linear, not a V. No phase has a gate that says "Phase N output must pass check X before Phase N+1 begins." End-tests only. |
| Enforcement | **0** | There is no enforcement mechanism. The skill is advisory — it documents rules but doesn't block delivery if consolidation fails, doesn't halt on schema violations (drops rows with warnings), and has no CI integration. Entirely honor-system. |
| Parent/worker split | **2** | Explicit orchestrator/worker model: the parent agent dispatches to N worker models, extracts and consolidates their output. The 4-phase methodology, dispatch mechanics, and consolidation rules all separate the orchestrator's concerns from the workers'. The `run-manifest.json` tracks which models were workers. |
| Evidence model | **1** | The `thorough` mode adds cross-source verification with an evidence ledger, but in `standard` mode (the default), evidence is informal — source refs are captured but not verified. The `prefer-with-evidence-then-newer-then-strict` rule uses evidence quotes but doesn't define evidence sufficiency tiers. Tiered in thorough mode only. |
| Covers both production task types (SE + DevOps) | **2** | The task-agnostic design covers research, code review, fact-check, ideation, writing critique, translation verification, and decision support. Code-review maps to SE; infrastructure validation could map to DevOps. Both domains are supported through the same pipeline with different schemas. |
| Supports team process packs | **0** | No team customization mechanism. The schema is per-run, not per-team. There's no overlay pack system, no shared configuration registry, no team profile that pre-defines model sets or conflict rules. Each user configures from scratch. Fork required to create team conventions. |

**Total: 9 / 16**

---

## §3. Top 5 Improvements (ranked by impact × effort)

### 1. Version + CHANGELOG consistency

- **Issue:** SKILL.md frontmatter says v2.1.0, task description says v2.0.0. No changelog, no version file, no migration notes for v1→v2.
- **Why it matters:** Users and downstream tools can't determine what version of the skill they're using, what changed, or whether their existing schemas are compatible.
- **Concrete change:**
  - **File:** `SKILL.md:6` — Resolve the version to a single authoritative value (e.g., `2.1.0`).
  - **New file:** `skills/multi-ai-task/CHANGELOG.md` — Add a changelog covering v1.0.0 (research-only) → v2.0.0 (task-agnostic) → v2.1.0 (current). Document breaking changes (schema format evolution, named rule library, `--no-auto-inject` default change if any).
  - **File:** `rules/output-schema.md:5` — Add `**Schema version:** 2.1.0` to the file header section so generated output declares which schema version it conforms to.
- **Effort:** Low
- **Impact:** Medium
- **Score:** High ROI

---

### 2. Fix code-review + fact-check schemas to work with their example dispatches

- **Issue:** The code-review example dispatches only 2 models, but `majority` rule breaks on ties. The fact-check example dispatches 3 models but the documented consensus thresholds require 3+ votes (unanimous). Neither has a proven run. Neither declares `dedup_key: true` at the column level as the skill's own docs require.
- **Why it matters:** Users copy-paste examples. A broken example teaches broken usage. The "pattern is identical" claim is an untested assertion.
- **Concrete change:**
  - **File:** `rules/examples/code-review.md:24` — Change dispatch loop to 4 models (e.g., add `opencode-go/glm-5.2`, `opencode-go/deepseek-v4-pro`).
  - **File:** `rules/examples/code-review.md:42-43` — Add `"dedup_key": true` to both `file` and `line` column definitions: `{"name": "file", "type": "string", "required": true, "dedup_key": true}` and `{"name": "line", "type": "number", "required": true, "dedup_key": true}`.
  - **File:** `rules/examples/fact-check.md:29` — Change dispatch to 4 models.
  - **File:** `rules/examples/fact-check.md:92-93` — Adjust thresholds from "3+" to "≥ ceil(N/2)+1" or explicitly note that with N=4, 3 models = confirmed, 2 = uncertain.
  - **File:** `rules/examples/fact-check.md:55-58` — Add `"counter_evidence": "concatenate-all"` to the `conflict_resolution` config.
  - **File:** `rules/examples/code-review.md:70` — Remove or re-label "false-positive rate" to "per-reviewer finding count" since false-positive rate is not computable without ground truth.
- **Effort:** Medium
- **Impact:** High
- **Score:** High ROI

---

### 3. Add `aggregate` field type to named rule library

- **Issue:** `"aggregate": "median"` is referenced in SKILL.md (line 101), methodology.md (line 115), and research-prior-art.md (line 116), but the only named aggregator is `median`. No `mean`, `mode`, `sum`, `min`, or `max` aggregators are defined. The research example's scoring rubric (line 116-117) defines `"aggregate": "median"` and `"max_total": 16` — but `max_total` isn't described anywhere in the schema column fields.
- **Why it matters:** Score aggregation is core to the skill's value for any comparative task. Without a defined set of aggregators, users writing scoring schemas don't know what values `aggregate` accepts. More critically, `max_total` appears in the research example but has no definition — is it a per-column max or a computed sum-of-columns cap?
- **Concrete change:**
  - **File:** `rules/consolidation-rules.md:250` (after "Score conflict resolution") — Add an "Aggregation functions" subsection defining: `median`, `mean` (arithmetic mean), `mode` (most frequent), `sum`, `min`, `max`, `range` (min–max span). For each, specify behavior on missing values (skip vs. zero vs. error) and N=1 edge case.
  - **File:** `SKILL.md:101` — Document `aggregate` as a column field in the "Supported column fields" table. Currently only `aggregate` appears in the example JSON but has no row in the field reference table.
  - **File:** `rules/examples/research-prior-art.md:117` — Either document `"max_total"` in the schema field reference or remove it as a scoring-rubric-only concept and rename to `"total_max"` for clarity.
- **Effort:** Low
- **Impact:** High
- **Score:** High ROI

---

### 4. Resolve the dedup_key / primary_key dual declaration confusion

- **Issue:** Schemas declare `"primary_key"` at the root (e.g., `"primary_key": "file:line"`) AND via `"dedup_key": true` on individual columns. But SKILL.md line 143 says "list multiple columns with `dedup_key: true`" while the code-review example uses only the root-level `primary_key`. These are two different declaration paths with no spec declaring which takes precedence or whether both must match.
- **Why it matters:** An implementer reading the skill must know how to parse the dedup key from the schema. If the root-level string and column-level booleans can disagree, what happens? This is the core identity mechanism for every item.
- **Concrete change:**
  - **File:** `SKILL.md:143` — Replace with: "**Composite primary keys:** When multiple columns form the identity, set `dedup_key: true` on each. The consolidated primary key is the concatenation (with `:` separator) of all columns where `dedup_key: true`. The root-level `primary_key` field in the schema is a human-readable hint only — the authoritative key derives from column-level `dedup_key` flags."
  - **File:** `rules/consolidation-rules.md:36-38` — Adjust the pseudocode's `normalize()` to use column-level `dedup_key` flags, not root-level `primary_key`. Show the composite key construction logic.
  - **File:** `rules/examples/code-review.md:40` — Keep `"primary_key": "file:line"` as a hint but add `"dedup_key": true` to the `file` and `line` column definitions as the authoritative declaration.
- **Effort:** Medium
- **Impact:** High
- **Score:** High ROI

---

### 5. Add deterministic route for extraction (or rename the claim)

- **Issue:** methodology.md line 178 claims extraction is "deterministic" but fallback path 3 (line 55) dispatches an LLM. The claim is false and misleading for users who expect bit-identical re-runs.
- **Why it matters:** Reproducibility claims affect trust. If a user re-runs with the same models and gets different extractions because the extractor LLM is non-deterministic, they will blame the skill.
- **Concrete change:**
  - **File:** `rules/methodology.md:178` — Rewrite: "Structured extraction (Mode A) is primarily rule-based (deterministic table parsing and row validation). When rule-based extraction fails (model returned non-table output), a designated extractor LLM reformats the response — this fallback is non-deterministic. Free-form extraction (Mode B) uses LLM-assisted extraction and is non-deterministic by design." Add `extraction_method: "deterministic" | "llm-fallback" | "llm"` to `run-manifest.json` so re-runs can compare extraction paths.
  - **File:** `rules/methodology.md:165-168` — Add `extraction_method` field to the `run-manifest.json` totals block.
- **Effort:** Low
- **Impact:** Medium
- **Score:** Medium-High ROI

---

## §4. Open Questions

1. **What is the skill's target runtime?** The dispatch mechanics reference `opencode run --model`, which requires an OpenCode Go installation. But the skill also claims to work via Mechanism 4 (direct HTTP) on any harness. Is the skill primarily an OpenCode-native skill, or is it intended to be harness-agnostic? The SKILL.md description says "works for any task" but the dispatch layer is 70% OpenCode-specific.

2. **What is the skill's relationship to the `deep-research` skill?** SKILL.md line 253 references Claude's `deep-research` skill as a per-model methodology. Is this an integration point (the skill knows to invoke deep-research per model) or just advisory text? If it's advisory, it should be moved to the research example.

3. **Is the scoring rubric (8 dimensions: catalog, dynamic, v_loop, enforce, etc.) part of the skill or part of the research example?** It appears only in `research-prior-art.md` but the task description uses it to evaluate the skill. If it's a general-purpose evaluation framework, it should be in the core rules. If it's research-specific, using it for skill evaluation is scope-creep.

4. **What is the API stability contract?** The schema format (`columns`, `conflict_resolution`, `primary_key`) has no versioning within the JSON. If the skill's schema format changes in v3.0, how does a user know their v2.x schema is incompatible? There's no `$schema` URI or version field in the schema JSON.

5. **Where is the implementation?** The skill is ~1,200 lines of specification spread across 8 files, but there is no executable code. Is this a spec-only skill (the calling agent must implement the pipeline by reading the spec), or is there an implementation file elsewhere? Without an implementation, every calling agent reimplements the extraction, dedup, and conflict-resolution algorithms from prose — leading to behavioral drift.

6. **What is the expected scope of the extraction pipeline?** The pseudocode handles markdown tables, `<structured>` tags, and H2-split prose. But what about JSON responses? CSV? YAML? Code blocks with formatted output? The skill is "task-agnostic" but the extraction pipeline only handles 3 output formats.

---

## §5. Confidence

- **Overall confidence:** Medium

- **What would change your assessment:** (a) An actual implementation file with the extraction/dedup/conflict-resolution algorithms — the prose pseudocode is plausible but untested for any task type other than research. (b) Proven runs for code-review and fact-check (not just the single research run) — the claim that "the pattern is identical" needs evidence. (c) A versioning policy document that defines what constitutes a breaking change to the schema format or rules — without this, users can't plan for upgrades.
