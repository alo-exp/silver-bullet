Let me also check for some cross-references and inconsistencies.
Now I have all 8 files plus the 3 prior reviews (R2, R3, R4). Let me write the critical review.

---

# Critical Self-Review: multi-ai-task Skill (Round 5)

**Review date:** 2026-06-27
**Reviewed version:** 2.1.0 (SKILL.md frontmatter)
**Reviewer:** Independent critical review (direct read + analysis)
**Prior reviews:** `self-review.md` (R2), `critical-review-r3.md` (R3), `critical-review-r4.md` (R4)

**Note on version:** The task description says "v2.0.0" but SKILL.md frontmatter (line 6) says `version: 2.1.0`. This is the same discrepancy flagged in R2 (line 18) and still unresolved. There is no changelog anywhere in the skill directory.

---

## §1. Critical Assessment

### 1. SKILL.md

**What works well:**
- The "When to use / When NOT to use" table (lines 35-49) remains the best decision matrix — concrete enough to act on. No issues.
- The `--schema` parameter section (lines 86-155) with column types, composite keys, and named conflict rules is genuinely implementable.

**What is missing or wrong:**

- **The "task-agnostic" claim is structurally false.** The skill's consolidation model (steps 3-6, lines 18-21) requires responses to be decomposable into "items" — a list-shaped output. `consolidation-rules.md:9-22` states explicitly: *"For the consolidation step to work, the model responses need to be decomposable into **items**."* Tasks producing prose (writing critique), code (refactoring), or structured documents (architecture proposals) are forced through a lossy H2-split heuristic (`methodology.md:83-98`) that treats `## Summary`, `## Analysis`, `## Conclusion` as three separate "items." The skill should say: "list-task-agnostic; experimental for non-list outputs." This was flagged in R4 (line 22) and remains unaddressed.

- **`--concurrency` appears in `argument-hint` (line 4) but is never defined.** The inputs table (lines 62-69) doesn't list it. The only parallel-vs-sequential discussion is in `dispatch-mechanics.md:104-111`, which describes it as a user choice, not a CLI flag. A caller parsing the argument-hint will expect a `--concurrency` flag that doesn't exist.

- **`--no-auto-inject` is listed under "What this skill does NOT do" (line 23-29) but IS something the skill does.** Line 23: "Auto-injects the schema into every dispatch prompt (by default ON; pass `--no-auto-inject` to opt out)." This is a positive capability, listed under a "does NOT do" heading. The double-negative framing (`--no-auto-inject` to disable a default-ON behavior) is confusing enough without also misplacing the feature. Flagged in R4 (line 32), unfixed.

**What is unclear or ambiguous:**

- **Line 74: "at least one reasoning-capable model if the task is research-like"** — how does the skill detect "research-like"? The entire point of being task-agnostic is that the skill doesn't know the task type. Is this a heuristic on the prompt text? A user flag? Left to the user's judgment? Not stated.

- **Line 28: "Retry failed dispatches (this is the calling agent's responsibility)"** — is listed under "does NOT do" without saying HOW. A one-sentence pattern (e.g., "wrap `wait` in a timeout loop and re-dispatch only models whose `.err` files indicate timeout") would turn a gap into guidance.

---

### 2. rules/methodology.md

**What works well:**
- The 4-fallback extraction path (lines 37-64) is concrete, implementable, and ordered with clear rationale at each step. No issues.
- The "Deterministic + LLM-assisted hybrid" principle (lines 156-161) makes the design trade-off explicit.

**What is missing or wrong:**

- **The `run-manifest.json` canonical schema claim is broken (4th consecutive review flagging).** methodology.md:145-147 says: *"The canonical schema lives in `rules/output-schema.md` § `run-manifest.json`. All other files reference it."* But output-schema.md:209-237 is missing `phases_completed`, `consolidation`, `schema_auto_injected`, and `aliases`. methodology.md itself defines these fields in prose (lines 15, 19, 147) but not in the JSON example. Two files both claim canonicity; neither has the complete set.

- **Line 173: "Idempotent re-runs" is the wrong term.** Idempotent means same input → same output. Each run gets different model responses (LLMs are non-deterministic). The correct term is "re-runnable" or "repeatable." Flagged in R3 and R4, unfixed.

- **Line 157: "Structured extraction (Mode A) is deterministic — pure parsing, no LLM in the loop" is false.** Mode A fallback path 3 (lines 52-58) dispatches an extractor LLM. The claim should be: "Structured extraction is deterministic when the model produces a compliant table; LLM-assisted fallbacks are used otherwise." Flagged in R3 and R4, unfixed.

- **The "Extractor model" concept is defined three times with slightly different wording:** methodology.md:52-54, methodology.md:104, and consolidation-rules.md doesn't define it but references it. The three definitions disagree on whether it's "the slowest/highest-capability model" or "a designated model." This should be defined once and referenced.

**What is unclear or ambiguous:**

- **Line 104: "Default: the slowest, highest-capability model from the original dispatch."** How is "highest-capability" determined? Context window? Parameter count? Provider tier? This has been flagged in R3 and R4. The skill needs a concrete heuristic (e.g., "the model with the largest context window; ties broken by dispatch order") or should say "left to the implementation."

- **Phase 2 extraction says "Split by H2 headings" (line 83) but doesn't handle non-item H2s.** If a model writes `## Summary`, `## Analysis`, `## Conclusion` — the parser treats "Summary," "Analysis," and "Conclusion" as three items. This is a known gap with no documented mitigation. Flagged in R4, unfixed.

---

### 3. rules/dispatch-mechanics.md

**What works well:**
- The 4-mechanism decision table (lines 178-188) maps constraints to mechanisms clearly. No issues.
- Real-world bug references (issue #18615, 6 issues for task tool model field) add credibility.

**What is missing or wrong:**

- **The default Mechanism 2 bash snippet (lines 36-61) defines `TIMEOUT=600` but never uses it in the `npx` command.** The `npx` command (lines 52-57) runs without any timeout wrapper. The prose on line 69 describes the fix (`timeout "$TIMEOUT" enforces per-model timeout`), but the snippet itself is broken. This is the DEFAULT mechanism — every reader copy-pasting it will hit the 2-min default bash timeout on long tasks. Flagged in R3 and R4, unfixed. This is the 3rd consecutive review.

- **The slug logic (`cut -d/ -f2`) doesn't handle multi-slash model IDs.** Line 51: `slug=$(echo "$model" | cut -d/ -f2)`. For `opencode-go/minimax-m3`, this extracts `minimax-m3`. But for `org/provider/model` (three slashes), it would extract `provider`, not `model`. The comment on line 64 says "critical" but doesn't address the multi-slash case.

- **Lines 119-124: "Always check the model's CWD for stray `*.md` files after a dispatch."** The calling agent has no programmatic access to the model's CWD. This is advice for a human user, not for an automated pipeline. It should be under a "Manual post-run steps" heading, not in the general dispatch section.

**What is unclear or ambiguous:**

- **Line 113: "configure MCPs that support multiplexing"** — no concrete MCP names, no config examples, no links. This is a concrete technical recommendation with zero concrete details. Flagged in R4, unfixed.

- **Lines 46-48: The `--dangerously-skip-permissions` flag is present unconditionally in the snippet.** The code-review example (`code-review.md:38`) correctly omits it, but the default snippet — which most people will copy — includes it. For write tasks, this is a security risk. The snippet should conditionally include it or have a prominent `# REMOVE FOR WRITE TASKS` comment.

---

### 4. rules/consolidation-rules.md

**What works well:**
- The named rule library (lines 163-221) remains the strongest part of the skill. Every rule has purpose, input spec, algorithm, and edge cases. No issues.
- The conflict documentation template (lines 227-234) uses real examples.

**What is missing or wrong:**

- **The `concatenate` vs `concatenate-all` naming inconsistency.** Line 307: *"Use `concatenate` for comments"* (writing critique row in custom strategies table). But the rule library (lines 199-203) defines the rule as `concatenate-all`. An implementor building the writing critique recipe will look up `concatenate` in the rule library and find nothing. Flagged in R4, unfixed.

- **The fuzzy match algorithm (line 131) offers "Levenshtein or token-overlap" without specifying which.** These produce different results: "AutoGen Framework" vs "Framework AutoGen" has Levenshtein distance ~14 (low similarity) but token-overlap of 100% (perfect match). The skill must pick one algorithm. Flagged in R4, unfixed.

- **The alias map is overloaded with skip semantics.** Line 115: *"Mark a row's primary key as `aliases[n] = null` to drop it from the registry."* This mixes two operations (alias resolution and skip filtering) in one data structure. A null entry in the alias map has no semantic meaning without reading the prose. The skip rules should be a separate data structure. Flagged in R4, unfixed.

- **`lowest-of-majors` returns `unverified` but the rule says "change the schema to match the rule" (line 185).** This inverts normal API design. If a user schema has `values: ["true", "false", "partially-true"]` and uses `majority-with-uncertain` for the verdict field, the rule silently returns `unverified` — a value the schema doesn't accept. Line 185 acknowledges this with `conflict_resolution.verdict_uncertain_value` but then contradicts itself: "Do NOT change the rule's return value to match the schema — change the schema to match the rule." This is backwards.

**What is unclear or ambiguous:**

- **Line 82: "supply an alias map at run time."** How? Is it a CLI flag? Part of `--schema`? A separate file? Embedded in `run-manifest.json`? The research example hardcodes it, but the core rules don't specify the interface. Flagged in R3 and R4, unfixed.

- **Line 129-132: "Match if normalized titles are ≥80% similar"** — the threshold is hardcoded. For short titles ("BMAD" vs "BMAD Method"), 80% token-overlap is trivial. For long titles ("Microsoft Agent Framework" vs "MAF"), 80% Levenshtein similarity is impossible. The threshold should be adaptive or the algorithm should be specified.

---

### 5. rules/output-schema.md

**What works well:**
- The markdown formatting rules (lines 258-269) are critical and well-specified — every rule was learned from real WYSIWYG failures. No issues.
- The two-mode output structure (schema vs free-form) is cleanly delineated.

**What is missing or wrong:**

- **`run-manifest.json` schema is stale (4th consecutive review).** This file (lines 209-237) is missing `phases_completed`, `consolidation`, `schema_auto_injected`, and `aliases`. The file explicitly says "This is the canonical schema" (line 209) but is out of date. This is the most-repeated finding across all four reviews.

- **§3 "Per-Item Details" (lines 100-115) leaks research-specific fields.** Line 109: `gaps_vs_reference = ... ; reference_gaps_vs_them = ...` — these are research-prior-art fields. A code-review user reading §3 would be confused. Replace with truly generic examples.

- **The Markdown formatting rules section (lines 258-269) has no section number.** It follows §8 but isn't numbered. Should be §9 for cross-reference consistency. Flagged in R3 and R4, unfixed.

- **`run-manifest.json` doesn't capture timing data.** The schema has `timestamp` (start time) but no `duration_ms`, no per-model timing, no consolidation wall-time. For a skill that lists "Latency of slowest model + consolidation is OK" as a decision criterion (SKILL.md:41), the manifest doesn't capture the data needed to evaluate that criterion.

- **The `conflicts.md` file and §4 of `consolidated.md` have identical content with no stated consumer.** Line 205: `conflicts.md` is "Same as §4 but as a standalone file (for tooling that consumes it)." What tooling? If there's no consumer, this is duplication.

**What is unclear or ambiguous:**

- **Lines 130-131: §5 (Aggregated Scores) and §8 (Synthesized Verdict) are "optional" but §6 (Negative Results) and §7 (Open Questions) are not marked optional.** Are they always produced? What if there are no negative results — is §6 omitted or produced empty? The optionality contract is inconsistent.

- **Line 70: "Conflict marker legend (place at top of section)"** — but §2A comes before §4. If conflict markers are in §2A's table, the reader hasn't seen the conflict resolution rules yet. Either move §4 before §2, or add a forward reference.

---

### 6. rules/examples/research-prior-art.md

**What works well:**
- The full prompt template (lines 37-68), schema (lines 72-99), scoring rubric (lines 104-118), and alias map (lines 125-141) together form a complete, copy-pasteable recipe. This is the only example that's been run end-to-end.

**What is missing or wrong:**

- **The schema uses `"primary_key": "name"` (line 75) — a field that doesn't exist in the schema spec.** SKILL.md:142 defines composite keys via `dedup_key: true` on individual columns. The code-review example (line 70) explicitly says: *"The string-form `primary_key` is not a recognized schema field."* Yet the only proven example uses exactly that pattern. This is a cross-file contradiction. Flagged in R4, unfixed.

- **The bash dispatch (lines 18-32) doesn't show `--schema` being passed.** Line 173 says "the prompt did NOT embed the schema; the skill auto-injected it because `--no-auto-inject` was not passed" — but where does the schema come from? The bash snippet doesn't show `--schema <file>`. This is a gap in the example's completeness.

- **The scoring rubric (lines 104-118) is research-specific, not generic.** The 8 dimensions (`catalog`, `dynamic`, `v_loop`, `enforce`, `parent_worker`, `evidence`, `se_devops`, `customization`) are Silver Bullet architecture dimensions. A code-review or fact-check user would have no use for these. Yet this is the only scoring example, implying it's the standard.

**What is unclear or ambiguous:**

- **Line 182: "diminishing returns past 6 (this is an empirical observation, not a measured curve)"** — honest but weakens the recommendation. Either cite the data or don't state a number.

---

### 7. rules/examples/code-review.md

**What works well:**
- The composite-key correction (lines 70-71) is pedagogically valuable — shows the wrong way and the right way.
- Custom strategies table (lines 93-100) maps each field to a named rule with rationale.

**What is missing or wrong:**

- **No worked example (line 111: "Not yet produced (deferred to v2.2.0)").** The "task-agnostic" claim rests on one proven example. This has been flagged in R2, R3, and R4.

- **Line 33: the dispatch uses only 2 models.** The `majority` conflict-resolution rule (used for `category`) needs ≥3 models to produce a majority. With 2 models and 2 different values, `majority` returns `null` (consolidation-rules.md:178). The example should either use ≥3 models or note that `majority` is degenerate with N=2.

- **Line 107: "Pre-commit hook ... NOT currently supported"** — this is a feature wishlist item in an "Example" file. It's not an example; it's a roadmap item.

**What is unclear or ambiguous:**

- **Line 45: "code review is a read-only task — the models just read and report"** — but if the model needs to READ the file via the `read` tool, it needs tool permissions. The `--dangerously-skip-permissions` flag is about tool permissions, not write permissions. The security note conflates "read-only task" with "no tool permissions needed."

---

### 8. rules/examples/fact-check.md

**What works well:**
- Consensus requirements (lines 103-109) with parameterized thresholds are well-specified.
- "Key customization for fact-check" (lines 73-77) explains WHY each rule choice matters.

**What is missing or wrong:**

- **No worked example (line 113: "deferred to v2.2.0").** Same gap as code-review. Flagged in R2, R3, R4.

- **Line 77: changelog entry embedded in example file.** "`sources: 'url_list'` is now formally defined in the schema spec (was a v2.1.0 gap)" — this is version history, not example documentation. Changelog info should be in a changelog, not scattered across example files.

- **The distinction between `partially-true` and `unverified` is never defined.** Both are valid verdict values in the schema (line 60). Line 76 says "`unverified` is a valid output" but doesn't explain when to use `partially-true` vs `unverified`. Is `partially-true` for "the claim is half-right" and `unverified` for "insufficient evidence"? The schema allows both; the prose doesn't distinguish them. Flagged in R4, unfixed.

- **Line 104: self-referential to a deleted draft.** "The '3+ models' rule in the original draft was a typo" — the reader can't see the original draft. Remove.

**What is unclear or ambiguous:**

- **Line 74: "require ≥ `max(2, ceil(N/2))` models to agree for a clean verdict (so for N=3 you need 2 votes, not 3)"** — the parenthetical "not 3" is confusing. `ceil(3/2) = 2`, so `max(2, 2) = 2`. The math is correct but the prose implies someone might think 3 is required. Just state the formula and give the example.

---

## §2. Score the Skill on the 8-Dimension Rubric

| Dimension | Score | Justification |
|-----------|-------|---------------|
| **Catalog of composable units** | **2** | Machine-readable catalog: 9 named conflict-resolution rules with algorithm specs, 8 column types with validation rules, 4 dispatch mechanisms with selection criteria. The schema JSON is the catalog format. This is genuinely strong. |
| **Dynamic composition** | **1** | Configuration drives behavior (`--mode`, `--schema`, `--models`), and `run-manifest.json` provides an audit trail. But no runtime replanning (mode cannot change mid-run based on partial results), no dynamic model substitution on failure, no adaptive extraction. |
| **V-loop depth** | **1** | `thorough` mode adds a verification loop (per-item source checking). But no per-step rollup (can't inspect intermediate extracts), no intent gate (no confirmation that consolidation matches user intent before final output), and no V-model traceability from output back through each phase. `phases_completed` is a list of integers, not a traceability matrix. |
| **Enforcement** | **0** | Honor system only. No IDE hooks, no CI integration, no delivery blockers. Nothing prevents misuse. The skill is a Markdown document — there is no executable enforcement layer. |
| **Parent/worker split** | **2** | Explicit orchestrator/worker with fail-soft design. The "extractor model" role is a designated fallback worker. The dispatch loop (`for model in ...; do ... & done; wait`) is a clear orchestrator pattern. |
| **Evidence model** | **2** | Tiered sufficiency with staleness: `source_refs`, `prefer-with-evidence-then-newer-then-strict`, `thorough` mode verification, `last_verified`. More sophisticated than many production systems. |
| **SE + DevOps unified** | **1** | Code-review example covers SE. But DevOps coverage is thin — no infrastructure review, config audit, or deployment verification example. "Covers both" is claimed but only SE is demonstrated. |
| **Team customization** | **1** | Schemas act as "process packs" but no overlay/extension mechanism. Can't extend a base schema with extra columns. No schema inheritance. No way to say "take the code-review schema and add a `security_impact` column." |
| **TOTAL** | **10/16** | Same as R3 and R4. The score has not changed across 3 reviews because the issues have not been fixed. |

---

## §3. Top 5 Improvements (ranked by impact × effort)

### 1. Fix the Mechanism 2 timeout bug (4th consecutive review)

- **Issue:** `dispatch-mechanics.md:52-57` defines `TIMEOUT=600` but never uses it in the `npx` command. The copy-pasteable default snippet silently fails on tasks longer than 2 minutes.
- **Why it matters:** This is the DEFAULT mechanism. Every user copy-pasting it will hit the 2-min bash timeout. This has been flagged in R2, R3, and R4.
- **Concrete change:** In `dispatch-mechanics.md:50-58`, replace the `for` loop body:
  ```bash
  for model in opencode-go/minimax-m3 opencode-go/qwen3.7-max opencode-go/glm-5.2; do
    slug=$(echo "$model" | cut -d/ -f2)
    CMD=("$TIMEOUT_CMD" "$TIMEOUT" npx -y opencode-ai run --model "$model" --title "multi-ai-task-${slug}-$(date +%s)" --dangerously-skip-permissions "$PROMPT")
    "${CMD[@]}" > "$OUT/${slug}.md" 2> "$OUT/${slug}.err" &
  done
  ```
- **Effort:** Low (edit 1 file, ~5 lines)
- **Impact:** High (prevents the most common silent failure mode)
- **Score:** High / Low = **High ROI**

### 2. Fix the `run-manifest.json` canonical schema (4th consecutive review)

- **Issue:** `output-schema.md:209` claims "This is the canonical schema" but is missing `phases_completed`, `consolidation`, `schema_auto_injected`, and `aliases`. `methodology.md:145-147` redirects to `output-schema.md`. Neither file has the complete set.
- **Why it matters:** Every implementer following `output-schema.md` will produce manifests missing 4 fields. This has been flagged in R2, R3, and R4.
- **Concrete change:** In `output-schema.md:207-237`, replace the JSON block with a reference to methodology.md and add the missing fields:
  ```markdown
  ### `run-manifest.json`

  **Canonical schema is defined in `rules/methodology.md` § Phase 4.**
  This file references it for output-structure purposes only.

  Required fields: `timestamp`, `task_prompt`, `task_prompt_hash`, `mode`,
  `schema_provided`, `schema_auto_injected`, `schema`, `models_dispatched`,
  `models_responded`, `models_failed`, `output_dir`, `aliases`, `totals`,
  `consolidation`, `phases_completed`.
  ```
  Then ensure methodology.md has the complete, authoritative schema with all fields in one JSON example.
- **Effort:** Low (edit 2 files, ~15 lines)
- **Impact:** High (data-integrity bug; every run affected)
- **Score:** High / Low = **High ROI**

### 3. Resolve the `primary_key` schema field contradiction

- **Issue:** `research-prior-art.md:75` uses `"primary_key": "name"` in the schema JSON. `code-review.md:70` explicitly says this is wrong: *"The string-form `primary_key` is not a recognized schema field."* `SKILL.md:96` shows `"primary_key": "item"` in an example. These three locations contradict each other.
- **Why it matters:** An implementor reading both examples will not know which schema syntax is correct. The only proven example uses a pattern the other example says is invalid.
- **Concrete change:** In `research-prior-art.md:72-99`, replace `"primary_key": "name"` with `"dedup_key": true` on the `name` column:
  ```json
  {"name": "name", "type": "string", "dedup_key": true},
  ```
  Then update `SKILL.md:96` to also use `dedup_key: true` instead of `"primary_key": "item"`. This aligns all examples with the spec at `SKILL.md:142`.
- **Effort:** Low (edit 2 files, ~3 lines)
- **Impact:** High (resolves cross-file contradiction in the schema spec)
- **Score:** High / Low = **High ROI**

### 4. Fix the `concatenate` vs `concatenate-all` naming inconsistency

- **Issue:** `consolidation-rules.md:307` says "Use `concatenate` for comments" (writing critique row), but the rule library (lines 199-203) defines the rule as `concatenate-all`.
- **Why it matters:** An implementor building the writing critique recipe will look up `concatenate` in the rule library and find nothing. They'll either implement a non-existent rule or give up.
- **Concrete change:** In `consolidation-rules.md:307`, change `concatenate` to `concatenate-all`:
  ```
  | **Writing critique** | Use `concatenate-all` for comments; present all model feedback in parallel sections |
  ```
- **Effort:** Low (edit 1 file, 1 word)
- **Impact:** Medium (prevents implementor confusion)
- **Score:** Medium / Low = **High ROI**

### 5. Correct the "idempotent" and "deterministic" claims

- **Issue:** `methodology.md:173` claims "Idempotent re-runs" (wrong — different model responses each time). `methodology.md:157` claims "Structured extraction (Mode A) is deterministic" (wrong — fallback path 3 uses an LLM).
- **Why it matters:** These are false claims about the skill's properties. An implementor relying on idempotency for caching or determinism for reproducibility will be surprised.
- **Concrete change:**
  - `methodology.md:173`: Change "Idempotent re-runs" to "Re-runnable" and update the prose: "The skill can be re-run with the same `task-prompt` to produce a new consolidated output. Each run is fresh — model responses are non-deterministic, so outputs will differ across runs."
  - `methodology.md:157`: Change "Structured extraction (Mode A) is deterministic — pure parsing, no LLM in the loop" to "Structured extraction (Mode A) is deterministic when the model produces a compliant table; LLM-assisted fallbacks are used otherwise."
- **Effort:** Low (edit 1 file, ~4 lines)
- **Impact:** Medium (corrects false claims about skill properties)
- **Score:** Medium / Low = **High ROI**

---

## §4. Open Questions

1. **Is the skill intended as a procedural document or a software artifact?** The entire skill is Markdown rules — no executable code, no reference implementation, no tests. Every agent must re-implement the dedup/conflict/extraction logic from prose. Is there a planned library, or is reimplementation-from-prose the intended design?

2. **What happens when ALL N models fail?** The skill says "fail-soft" and "excluded from consolidation." But if 0/N models respond, does the skill produce an empty `consolidated.md`? An error? A manifest with `models_failed: [all]`? This edge case isn't documented.

3. **How does the calling agent detect completion when using Mechanism 1 (task tool)?** The bash `&` + `wait` pattern works for Mechanism 2. But if the skill is invoked via `task` tool, how does the orchestrator know all sub-models are done? Is there a completion signal?

4. **What's the consolidation wall-time?** For 36 items × 6 models, how long do Phases 3-4 take? The skill says "latency of slowest model + consolidation" but gives no bounds for the consolidation part.

5. **Does `--no-auto-inject` do anything in free-form mode (no `--schema`)?** If no schema is passed, there's nothing to inject. Is the flag silently ignored? The spec doesn't say.

6. **What's the distinction between `partially-true` and `unverified` in fact-check?** Both are valid verdict values. The prose doesn't distinguish them. Is `partially-true` for "the claim is half-right" and `unverified` for "insufficient evidence"?

7. **How are model IDs with more than one slash handled?** The slug logic (`cut -d/ -f2`) assumes exactly one slash. `org/provider/model` would extract `provider`, not `model`.

8. **Why are code-review and fact-check proofs deferred to v2.2.0?** The generalization claim (task-agnostic) is undermined by having only one proven use case. What's the plan?

---

## §5. Confidence

- **Overall confidence:** High
- **What would change my assessment:**
  1. Resolution of the `primary_key` contradiction — if `primary_key` IS a valid schema field, the code-review example needs correction. If it's NOT, the research example's schema needs correction and the proven run's schema was invalid.
  2. A worked code-review or fact-check run would validate or invalidate the generalization claim.
  3. An executable reference implementation (even a 200-line Node script) would dramatically increase confidence that the algorithms are implementable from the prose.

---

**Meta-observation:** This is the 4th consecutive review. The top 3 issues (`run-manifest.json` stale schema, Mechanism 2 timeout bug, `primary_key` contradiction) have been flagged in R2, R3, and R4 without being fixed. The skill's quality is being held back not by design flaws but by unfixed bugs. The highest-ROI action is not another review — it's fixing the 5 items above.
