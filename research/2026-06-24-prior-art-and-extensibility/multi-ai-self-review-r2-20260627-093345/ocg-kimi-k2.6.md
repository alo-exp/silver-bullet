# Critical Self-Review: `multi-ai-task` Skill

---

## §1. Critical Assessment

### 1. `SKILL.md` (entry point)

**What works well**
- The task-agnostic framing is clean and the "when to use / not use" table (lines 33–42) is genuinely useful for triage.
- Version is pinned (`2.1.0`) and `user-invocable: false` correctly signals this is an agent-facing protocol.

**What is missing or wrong**
- **Conflicting auto-inject semantics in the "does NOT do" list.** Line 28 says: *"Inject the schema into the prompt unless `--no-auto-inject` is set (default ON)."* This is a double-negative inside a negated list. Parsing it: the skill says it "does NOT inject ... unless `--no-auto-inject` is set", which literally means it injects *only when* `--no-auto-inject` is passed. That contradicts the parenthetical "(default ON)". The intent is obvious to a human, but an agent parsing this literally will get it backwards.
- **`--concurrency` is omitted from the `argument-hint` frontmatter.** Line 4 lists `[--models] [--out] [--schema] [--mode] [--no-auto-inject]` but line 69 documents `--concurrency parallel|sequential`. A parameter documented in the body but missing from the hint string will be forgotten by callers.
- **Dead spec leakage.** Line 229 documents a symptom: *"Output dir contains `score-aggregate.md` (planned) but not in the contract"* with the fix *"Ignore for v2.x"*. If it's not in the contract and should be ignored, it should not be in the failure-modes table. It's noise.

**What is unclear or ambiguous**
- The "Mode semantics" table (lines 78–82) assigns **cross-source verification** to "Phase 2 (extract)" for `thorough` mode. But cross-source verification is a post-extraction, pre-synthesis activity (you verify sources *after* you have extracted claims). The phase assignment contradicts `methodology.md`, which never mentions verification in Phase 2.
- Line 173 says `consolidated.html` is generated with "minimal CSS inline", but no CSS template or generation command is provided anywhere in the skill. Is the agent expected to hand-write CSS?

---

### 2. `rules/methodology.md`

**What works well**
- The 4-phase breakdown is conceptually sound and the pseudocode for structured extraction (lines 36–64) gives implementers enough structure to start.
- Fail-soft policy is explicit and correct: *"The skill does NOT retry"* (line 19).

**What is missing or wrong**
- **Inconsistent phase numbering with `consolidation-rules.md`.** This file numbers phases 1–4. `consolidation-rules.md` uses Phase 2 (ALIGN), Phase 3 (DEDUP), Phase 3.5 (RESOLVE), Phase 3.6 (SCORE). There is no Phase 4 in the consolidation rules, and the sub-phases (3.5, 3.6) have no equivalent here. An audit trail that references "Phase 3.5" cannot be cross-walked to the 4-phase model.
- **`run-manifest.json` example (lines 147–168) is incomplete.** The text claims `totals.phases_completed` is tracked for audit (line 188), but the JSON example omits it. It also omits the `schema` field (present when `schema_provided: true`), the `aliases` field, and the `consolidation` object.
- **False claim about extractor model cost.** Line 104 says the extractor model *"caches the response, no extra cost"*. Dispatching a secondary model to reformat output consumes API tokens and wall time. "No extra cost" is incorrect.

**What is unclear or ambiguous**
- The "idempotent re-runs" section (line 194) says `run-manifest.json` *"can be referenced for incremental consolidation (future enhancement)"*. If the enhancement doesn't exist, the sentence is speculative and offers no actionable guidance.
- No guidance on how `consolidated.html` is actually generated from `consolidated.md` beyond "use a markdown library." What about the conflict-marker color CSS mentioned in line 175 of `SKILL.md`?

---

### 3. `rules/dispatch-mechanics.md`

**What works well**
- The 4-mechanism comparison is pragmatic and the "Choosing the right mechanism" table (lines 167–176) is decision-oriented.
- Auth-per-harness table (lines 137–143) is a nice operational detail that prevents debug loops.

**What is missing or wrong**
- **Task-agnostic skill making security assumptions about the task.** Line 56 says `--dangerously-skip-permissions` is *"fine for read-only tasks"* but warns *"For write tasks, do NOT use this flag."* The skill is task-agnostic; it cannot know whether the user's prompt is read-only or write. This creates a footgun where an agent following the skill's own example bash scripts may silently bypass permissions for a write task.
- **Bash example is missing timeout handling that the proven script uses.** The example (lines 40–50) has no timeout, yet the failure table (lines 121–129) lists "Subprocess dies after 2 min" as a primary failure mode. The proven `dispatch-research.sh` sets `AGENT_TIMEOUT=1500` and implements a wait loop. The skill's canonical example should include this, not rely on a separate file.
- **Latency budget formula is backwards.** Line 100 says: *"choose parallel if N × per_model_time ≤ your latency budget"*. Parallel wall time is approximately `max(per_model_time)`, not `N × per_model_time`. The condition should be `max(per_model_time) ≤ latency_budget`, or sequential should be chosen when `N × per_model_time` exceeds the budget.

**What is unclear or ambiguous**
- "MCP port collision" is mentioned repeatedly (lines 59, 97, 102) but no specific MCPs are named, nor is there a diagnostic for detecting collision. How does a caller know if their MCP is port-bound?
- Mechanism 3 has a documented bug with no workaround other than "use Mechanism 2." If Mechanism 3 is effectively non-functional, why list it as a preferred mechanism (line 62: "If you have an OpenCode server running, use the SDK")?

---

### 4. `rules/consolidation-rules.md`

**What works well**
- The named rule library (`most-severe`, `majority-with-uncertain`, `longest-with-quote`, etc.) is thorough and each rule includes an algorithm and edge case. This is the strongest part of the skill.
- The conflict documentation template (lines 230–237) is concrete and copy-pasteable.

**What is missing or wrong**
- **Broken phase numbering.** The file uses Phase 2 (ALIGN), Phase 3 (DEDUP), Phase 3.5 (RESOLVE), Phase 3.6 (SCORE). There is no Phase 4 (SYNTHESIZE) even though `methodology.md` defines one. The sub-decimal phases (3.5, 3.6) are non-standard and break any tooling that expects integer phase IDs.
- **Research-specific alias map polluting the core rules.** Lines 84–96 show a hardcoded JS alias object containing research-only entries (`AutoGen/AG2`, `BMAD Method`, `Camunda 8`). Lines 330–336 claim the alias map is task-specific and not part of the core. The contradiction will confuse implementers: should they hardcode research aliases or start empty?
- **Default conflict resolution for `string` is nonsensical for free-form strings.** Lines 150–151 map `string (enumerated)` to `prefer-with-evidence-then-newer-then-strict`. But the schema type system has no "enumerated string" distinct from `string`; it has `enum` for that. A free-form `string` field (e.g., `description`) cannot usefully be resolved by evidence-quote preference. The default should map `enum` → `prefer-with-evidence...` and `string` → `longest-with-quote`.

**What is unclear or ambiguous**
- The `most-severe` edge case (line 176) says to downgrade a lone max *"with no evidence quote"*. How is "no evidence quote" detected algorithmically? By grepping for `"..."`? By a separate evidence field? The rule is not implementable as written.
- Line 306 says *"Ideation: No dedup (every idea is unique)"*, but the dedup algorithm (lines 100–116) has no bypass switch. How is "no dedup" enforced—by setting all `dedup_key` to false, by a schema flag, or by skipping Phase 3 entirely?

---

### 5. `rules/output-schema.md`

**What works well**
- The WYSIWYG formatting rules (lines 232–242) are specific and actionable. Rule 2 (*"Add blank line before AND after every table"*) is a real parser fix.
- The file header template (lines 23–35) is complete and includes the useful "Dispatch note" field.

**What is missing or wrong**
- **Duplicate section headers.** Both Mode A and Mode B items tables are labeled `## §2. Items Table` (lines 53 and 79). A reader or parser cannot distinguish them without reading body text. They should be `§2a` and `§2b`, or `§2. Structured Table` / `§2. Narrative Items`.
- **Field naming inconsistency.** The `structured.jsonl` example in this file (line 200) uses `source_ref` (singular), but `methodology.md` line 28 and the extraction pseudocode use `source_refs` (plural). Implementers will produce incompatible JSON.
- **The default items table is unusably wide.** Line 61 shows a column `Fields per model` with content like `m1: {...}, m2: {...}`. In a markdown table with 4–6 models, this column will be hundreds of characters wide and break every renderer. There is no guidance on truncation or vertical stacking.

**What is unclear or ambiguous**
- Line 115 says *"Be specific. Not 'less mature' but 'lacks V-model rollup; has BPMN catalog'."* This is excellent advice, but it belongs in the task examples (research-prior-art, code-review), not in the generic output schema. A fact-check output doesn't have "maturity" fields.
- The `run-manifest.json` example (lines 209–226) is inconsistent with the one in `methodology.md` (missing `schema`, `consolidation`, `phases_completed`).

---

### 6. `rules/examples/research-prior-art.md`

**What works well**
- The provenance chain is excellent: it references exact files (`docs/research-260624/SB_CONSOLIDATED_PRIOR_ART_REPORT.md`), exact models, and exact counts (36 unique products, 153 mentions).
- The alias map (lines 125–141) is battle-tested and includes a maintenance note (*"audit for missed alias cases"*), which is a good operational habit.

**What is missing or wrong**
- **Schema/rubric mismatch.** The schema (lines 72–99) defines separate fields `se_fit` and `devops_fit`, but the scoring rubric (lines 104–118) collapses these into a single dimension `se_devops`. A model following the schema produces two independent scores; the rubric expects one. There is no documented mapping.
- **Prompt instructs models to do the skill's job.** The prompt structure (lines 37–68) includes `## 8. Cross-AI Dedup Instructions` and `## 8.3 Scoring Rubric`. The skill is supposed to handle dedup and scoring aggregation. By embedding these in the user prompt, the skill invites models to pre-normalize, which may mask real disagreements that the consolidation step should surface.
- **Unmeasured claim presented as guidance.** Line 182: *"8-10 models captures more unique finds but diminishing returns past 6 (this is an empirical observation, not a measured curve — run your own benchmark if you want a hard number)."* If it's not measured, it shouldn't be in the skill's canonical guidance. Remove or rephrase as a hypothesis.

**What is unclear or ambiguous**
- The schema includes a `composition_model` field (type `string`) that is never referenced in the rubric, the alias map, or the output sections. What is it for? Is it dead schema?

---

### 7. `rules/examples/code-review.md`

**What works well**
- Schema customization is precise: `file:line` composite key and `most-severe` for severity are the correct defaults for code review.
- The custom strategies table (lines 76–83) gives clear rationale per field.

**What is missing or wrong**
- **Filename collision bug.** Line 30 writes to `"code-review-${model}.md"`, where `$model` is the full `provider/model` string (e.g., `opencode-go/minimax-m3`). This creates a subdirectory `code-review-opencode-go/` and writes `minimax-m3.md` inside it, or fails depending on the shell. The prior-art example correctly uses `${slug}` (from `cut -d/ -f2`); this example omits that sanitization.
- **Composite key syntax contradiction.** The schema shows `"primary_key": "file:line"` at the root (line 40), but `consolidation-rules.md` line 143 says composite keys are defined by listing *"multiple columns with `dedup_key: true`"*. Which is canonical? The example doesn't use `dedup_key` on `file` or `line` at all.
- **No worked example.** The file admits this (line 91: *"Not yet produced. The pattern is identical to the prior-art research example"*). For a skill that claims provenance, every canonical example should have at least one proven run.

**What is unclear or ambiguous**
- The "Pre-commit hook" variation (line 88) suggests combining with git diff but provides zero implementation detail. Is this a hypothetical or a tested pattern?

---

### 8. `rules/examples/fact-check.md`

**What works well**
- The consensus requirements (lines 91–95) are appropriately conservative for high-stakes fact-checking: 3+ models with high confidence + primary source.
- `majority-with-uncertain` as the default verdict rule is the right choice for this domain.

**What is missing or wrong**
- **Same filename collision bug as code-review.** Line 35 writes to `"factcheck-${model}.md"` with unsanitized `$model`.
- **`counter_evidence` is in the schema but not in the prompt's table request.** The prompt (lines 14–27) asks models to return `claim_id`, `claim`, `verdict`, `confidence`, `sources`, `evidence`, and `counter_evidence`. But it frames the output as *"Return as a markdown table with these columns"* without specifying which columns. A model may omit `counter_evidence` from the table because it wasn't explicitly included in the list of columns. The schema then expects it, creating an extraction failure.
- **No worked example.** Same issue as code-review.

**What is unclear or ambiguous**
- The consensus threshold requires **3+ models agreeing**. If the user only dispatches 3 models, a single dissenter blocks consensus. The skill should note that fact-check mode realistically requires ≥4 models, or the threshold should scale with N. Currently it doesn't.

---

## §2. Score the Skill on the 8-Dimension Rubric

| Dimension | Score | Justification |
|---|---|---|
| **Catalog of composable units** | **1** | The named conflict-resolution rules (`most-severe`, `majority-with-uncertain`, etc.) act as informal composable units, but there is no machine-readable catalog (e.g., JSON schema for the rules themselves). Implementers must hardcode the 10 rule names from prose. |
| **Dynamic composition** | **1** | The skill has static modes (`quick`/`standard`/`thorough`) that toggle phases on/off, but there is no runtime replanning or conditional branching based on intermediate results. The pipeline is fixed once dispatched. |
| **V-loop depth** | **1** | End-test only: did the model produce output? Did extraction succeed? There is no per-step verification *within* a model's execution, and no rollback if consolidation detects systematic bias in a model's output. |
| **Enforcement** | **0** | Pure honor system. No CI gate, no IDE hook, no delivery blocker. The skill is documentation; compliance is voluntary. |
| **Parent/worker split** | **2** | Explicit and clean. The skill is the orchestrator (parent); the dispatched LLMs are workers. The manifest tracks which worker produced which item. |
| **Evidence model** | **2** | Strong. `prefer-with-evidence-then-newer-then-strict` explicitly tiers evidence (primary quote > recency > majority), and staleness is handled via `last_verified` / `newer` rules. |
| **SE + DevOps unified** | **1** | Partial. The skill covers code review (SE) and could cover infrastructure review (DevOps), but the examples skew toward research and code review. No explicit DevOps/IaC example is provided. |
| **Team customization** | **2** | `--schema` JSON acts as an overlay pack. Teams can define custom columns, conflict rules, and dedup keys without forking the skill. |

**Total: 10 / 16**

---

## §3. Top 5 Improvements (ranked by impact × effort)

### 1. Fix filename collision bug in code-review and fact-check examples
- **Issue:** Both examples write to `${model}.md` using the unsanitized `provider/model` string, creating subdirectories or failing.
- **Why it matters:** A user copy-pasting the example will have broken output capture on the first run. This is a provenance-destroying bug.
- **Concrete change:**  
  `rules/examples/code-review.md:30` — change `> "code-review-${model}.md"` to `slug=$(echo "$model" | cut -d/ -f2)` and `> "code-review-${slug}.md"`. Same for `rules/examples/fact-check.md:35`.
- **Effort:** low
- **Impact:** high
- **Score:** 6.0

### 2. Add `--concurrency` to argument-hint and fix auto-inject double-negative in SKILL.md
- **Issue:** `--concurrency` is documented but omitted from the frontmatter `argument-hint`, and the "does NOT do" list contains a parseable contradiction about auto-inject.
- **Why it matters:** Agents parsing the frontmatter will miss a documented parameter; agents parsing the negation literally will disable auto-inject when they mean to enable it.
- **Concrete change:**  
  `SKILL.md:4` — append `[--concurrency parallel|sequential]` to `argument-hint`.  
  `SKILL.md:28` — replace *"Inject the schema into the prompt unless `--no-auto-inject` is set (default ON)"* with *"Auto-injects the `--schema` into every dispatch prompt (disable with `--no-auto-inject`)"* and move it out of the "does NOT do" list.
- **Effort:** low
- **Impact:** medium
- **Score:** 3.0

### 3. Standardize `source_refs` vs `source_ref` across all files
- **Issue:** The field is plural in `methodology.md` and singular in `output-schema.md`. Implementations will produce incompatible JSON.
- **Why it matters:** A downstream tool consuming `structured.jsonl` will miss source references depending on which file the implementer read.
- **Concrete change:**  
  `rules/output-schema.md:200` — change `"source_ref"` to `"source_refs"`. Audit all 8 files for the same inconsistency.
- **Effort:** low
- **Impact:** medium
- **Score:** 3.0

### 4. Reconcile composite key syntax and document it unambiguously
- **Issue:** `consolidation-rules.md` says composite keys use multiple `dedup_key: true` columns, but `code-review.md` uses `"primary_key": "file:line"` at the schema root without `dedup_key` on either column.
- **Why it matters:** A user building a code-review schema cannot tell which syntax is valid. If they follow the example, dedup may silently fail.
- **Concrete change:**  
  `rules/examples/code-review.md:40-43` — add `"dedup_key": true` to `file` and `line` columns and remove the ambiguous `"primary_key": "file:line"` root property, **OR** document that `"primary_key": "<col>:<col>"` is shorthand for multiple `dedup_key: true`. Pick one; enforce it in the schema validation section of `SKILL.md`.
- **Effort:** medium
- **Impact:** high
- **Score:** 2.7

### 5. Fix broken phase numbering and add Phase 4 synthesis algorithm to consolidation-rules.md
- **Issue:** Phases are numbered 2, 3, 3.5, 3.6 in consolidation-rules.md, with no Phase 4. Phase 4 (synthesis) is mentioned in methodology.md but has no algorithm.
- **Why it matters:** The skill claims auditability (`run-manifest.json → phases_completed`), but the phase IDs are non-integer, inconsistent, and Phase 4 is undefined. An implementer cannot build the synthesis step from the current docs.
- **Concrete change:**  
  `rules/consolidation-rules.md` — renumber Phase 2→2, 3→3, 3.5→3.3, 3.6→3.4. Add new **Phase 4 — SYNTHESIZE** after line 298 with pseudocode for rendering `consolidated.md` (sort order, column width handling, Mode A vs Mode B branching) and `consolidated.html` (CSS embedding, table styling).
- **Effort:** medium
- **Impact:** medium
- **Score:** 2.0

---

## §4. Open Questions

1. **What is the executable surface?** The skill is entirely markdown documentation and bash snippets. Is the agent expected to implement the consolidation pseudocode from scratch on every invocation, or is there a hidden implementation (e.g., a Node script or Python module) elsewhere in the repo? If the latter, it should be referenced. If the former, the skill is a protocol spec, not a skill in the traditional "invoke and it runs" sense.

2. **How was the 2026-06-27 consolidated report actually produced?** The report shows sophisticated human-like judgment in conflict resolution (e.g., *"mimo's `direct` not supported by primary quote"*). Was this generated purely by following the skill's algorithms, or was it heavily post-edited by a human/agent? Knowing this would calibrate whether the skill's pseudocode is sufficient or aspirational.

3. **What changed between v2.0.0 and v2.1.0?** The task context says v2.0.0; the file says v2.1.0. No changelog is present. Without knowing the delta, I cannot assess whether issues I found are regressions or long-standing.

4. **Does the skill expect the user prompt to do dedup pre-normalization?** The research example includes `## 8. Cross-AI Dedup Instructions` in the user prompt, which trains models to pre-harmonize their outputs. This undermines the value of cross-model conflict detection. Is this intentional (to reduce noise) or accidental (leaking skill internals into the prompt)?

---

## §5. Confidence

- **Overall confidence:** **medium**
- **What would change your assessment:**  
  Reading the actual implementation code (if any) for extraction, dedup, and synthesis would immediately raise or lower the score—currently I'm judging a spec, not a tested system. Additionally, seeing the raw, unedited outputs from the 2026-06-27 provenance run (before any agent/human consolidation) would reveal whether the skill's pseudocode actually works on real model outputs or if the published report is a polished exception.
