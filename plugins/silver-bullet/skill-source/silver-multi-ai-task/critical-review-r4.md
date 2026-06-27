# Critical Self-Review: multi-ai-task Skill (Round 4)

**Review date:** 2026-06-27
**Reviewed version:** 2.1.0 (SKILL.md frontmatter)
**Reviewer:** Independent critical review (direct read + analysis)
**Prior reviews:** `self-review.md` (round 2), `critical-review-r3.md` (round 3)

This review focuses on **what prior reviews missed**: architectural contradictions, hidden assumptions, cross-file inconsistencies not yet flagged, and the fundamental tension between "task-agnostic" and "list-shaped consolidation."

---

## §1. Critical Assessment

### 1. SKILL.md

**What works well:**
- The "When to use / When NOT to use" table remains the best decision matrix in the SB skill ecosystem.
- The schema parameter section (lines 86-155) is genuinely implementable — column types, composite keys, conflict rule names, auto-injection. Someone could build a parser from this alone.

**What is missing or wrong:**

- **The "task-agnostic" claim is undermined by the consolidation model's hidden assumption.** Lines 16-22 describe 7 steps, but steps 3-6 (extract structured items, dedup, resolve disagreements, aggregate scores) all assume the output is **list-shaped**. The skill's own consolidation-rules.md:9-22 states: "For the consolidation step to work, the model responses need to be decomposable into **items**." This is not task-agnostic — it's list-task-agnostic. Tasks producing prose (writing critique), code (refactoring), or structured documents (architecture proposals) are forced through a lossy H2-split heuristic (methodology.md:83-98) that treats section headings as items. The skill should be honest: "task-agnostic for list-shaped outputs; experimental for non-list outputs."

- **`--concurrency` is declared in `argument-hint` (line 4) but never defined anywhere.** The inputs table (lines 62-69) doesn't list it. The only parallel-vs-sequential discussion is in `dispatch-mechanics.md:97-107`, which describes it as a user choice, not a CLI flag. A caller parsing the argument-hint will expect a `--concurrency` flag that doesn't exist. Either define it in the inputs table or remove it from the argument-hint.

- **The scoring rubric in the research example (research-prior-art.md:104-118) is research-specific, contradicting the "task-agnostic" framing.** The 8 dimensions (`catalog`, `dynamic`, `v_loop`, `enforce`, `parent_worker`, `evidence`, `se_devops`, `customization`) are Silver Bullet architecture dimensions, not generic scoring axes. A code-review user or fact-check user would have no use for these. Yet the rubric is presented in the only proven example, implying it's the standard. The skill needs a truly generic scoring example or should explicitly say "the rubric is task-specific — design your own."

**What is unclear or ambiguous:**

- **Line 152: "fuzzy match on first 5 words of each paragraph"** — this is the free-form fallback's primary_key heuristic. But "first 5 words" is undefined for multi-paragraph items. If a model writes a 3-paragraph item under one H2, does the parser take the first 5 words of the first paragraph? The heading? The skill doesn't say.

- **Line 28: the double negation issue (flagged by R3) is still present.** "Inject the schema into the prompt unless `--no-auto-inject` is set (default ON — see 'The `--schema` parameter' below)" under a "does NOT do" heading. This hasn't been fixed between reviews.

---

### 2. rules/methodology.md

**What works well:**
- The 4-fallback extraction path (lines 37-64) is concrete and implementable. Each fallback has a clear trigger condition.
- The "Deterministic + LLM-assisted hybrid" section (lines 156-161) makes the design trade-off explicit.

**What is missing or wrong:**

- **The `run-manifest.json` canonical schema claim is still broken (flagged by both prior reviews, unfixed).** methodology.md:145-147 says "The canonical schema lives in `rules/output-schema.md`." But output-schema.md:209-237 is missing `phases_completed`, `consolidation`, `schema_auto_injected`, and `aliases`. Both files claim canonicity; one is stale. This is the single most impactful data-integrity bug in the skill.

- **Line 173: "Idempotent re-runs" uses the term incorrectly (flagged by R3, unfixed).** Idempotent means same input → same output. Different model responses each time means different output. The correct term is "re-runnable" or "repeatable." The skill is NOT idempotent.

- **Line 157: "Structured extraction (Mode A) is deterministic — pure parsing, no LLM in the loop" is false (flagged by both prior reviews, unfixed).** Mode A fallback path 3 (lines 52-58) dispatches an extractor LLM. The claim should be: "Structured extraction is deterministic when the model produces a compliant table; LLM-assisted fallbacks are used otherwise."

- **The `last_verified` tie-break in `longest-with-quote` (consolidation-rules.md:196) references a field that may not exist.** The `longest-with-quote` rule says: "Tie-break by recency (model's `last_verified` if present, else the order in the input list)." But `last_verified` is an optional schema field — it's only in the research schema. For code-review or fact-check schemas that don't define `last_verified`, the tie-break silently falls back to input order. This is fine in practice but the rule should explicitly say "if the schema defines `last_verified`" rather than implying it's always available.

**What is unclear or ambiguous:**

- **Line 104: "Extractor model — Default: the slowest, highest-capability model from the original dispatch."** How is "highest-capability" determined? This has been flagged by both prior reviews and remains unanswered. Is there a model ranking? Is it by context window size? Parameter count? The skill needs a concrete heuristic or should say "left to the implementation."

- **Phase 2 extraction says "Split by H2 headings" (line 83) but doesn't handle non-item H2s.** If a model writes `## Summary`, `## Analysis`, `## Conclusion` — the parser treats "Summary," "Analysis," and "Conclusion" as items. This is a known gap in the free-form extraction path that has no mitigation documented.

---

### 3. rules/dispatch-mechanics.md

**What works well:**
- The 4-mechanism decision table (lines 172-181) maps constraints to mechanisms clearly.
- Real-world bug references (issue #18615, 6 issues for task tool model field) add credibility.

**What is missing or wrong:**

- **The default Mechanism 2 bash snippet (lines 36-53) still doesn't enforce the timeout it defines (flagged by both prior reviews, unfixed).** `TIMEOUT=600` is declared on line 41 but never used in the `npx` command (lines 44-50). The prose on line 62 describes the fix (`timeout $TIMEOUT npx ...`), but the snippet itself is broken. This is the DEFAULT mechanism — every reader copy-pasting it will hit the 2-min default timeout on long tasks.

- **Mechanism 2 snippet passes `--dangerously-skip-permissions` unconditionally (lines 48).** The snippet's comment says "for read-only tasks" but the flag is always present. For write tasks (the skill claims to be task-agnostic), this is a security risk. The snippet should either conditionally include the flag or have a prominent comment explaining when to remove it. The code-review example (code-review.md:38) correctly omits it, but the default snippet — which most people will copy — includes it.

- **Mechanism 4 code example (lines 85-93) is a skeleton, not a working example (flagged by R3, unfixed).** It references `ENDPOINTS`, `KEYS`, and `model.id`/`model.provider` without defining them. No error handling, no auth, no rate limits. This should either be a complete example or clearly labeled "pseudocode only."

- **Lines 107-112: "Always check the model's CWD for stray `*.md` files after a dispatch."** The calling agent has no access to the model's CWD. This is advice for a human user, not for an automated pipeline. It should be under a "Manual post-run steps" heading, not in the automated pipeline section.

**What is unclear or ambiguous:**

- **Line 106: "configure MCPs that support multiplexing"** — this has been flagged by both prior reviews. No concrete MCP names, no config examples, no links. This is a concrete technical recommendation with zero concrete details.

- **Line 57-58: "`$slug` sanitizes the model name so filenames don't contain slashes (the `cut -d/ -f2` pattern is critical — without it, `out/$model.md` creates subdirectories or fails)."** This is good debugging advice, but the comment says "cut -d/ -f2" while the code on line 44 uses exactly that pattern. The comment is redundant with the code. More importantly: what happens when the model ID has more than one slash (e.g., `org/provider/model`)? The `cut -d/ -f2` would extract `provider`, not `model`. The slug logic doesn't handle nested paths.

---

### 4. rules/consolidation-rules.md

**What works well:**
- The named rule library (lines 163-221) remains the strongest part of the skill. Every rule has purpose, input spec, algorithm, and edge cases.
- The conflict documentation template (lines 227-234) uses real examples.

**What is missing or wrong:**

- **The `concatenate` vs `concatenate-all` naming inconsistency.** consolidation-rules.md:307 says "Use `concatenate` for comments" (writing critique row in the custom strategies table), but the rule library (lines 199-203) defines the rule as `concatenate-all`. These are different names for what appears to be the same operation. Is `concatenate` a different rule from `concatenate-all`? If so, it's not defined. If it's a typo, it's in a table that implementors will copy.

- **The fuzzy match algorithm (line 131) offers "Levenshtein or token-overlap" without specifying which.** These produce different results for the same input. "AutoGen Framework" vs "Framework AutoGen" has Levenshtein distance ~14 (low similarity) but token-overlap of 100% (perfect match). An implementor who picks the wrong one will get different dedup results. The skill must pick one algorithm.

- **The `most-severe` rule's prose structure is confusing (flagged by R3, partially addressed in R3's suggested fix but not applied).** Lines 167-172 describe the `allow_downgrade` edge case before stating the default behavior. A skimming reader will think the default is to downgrade. The R3 review suggested rewriting to lead with the default — this hasn't been applied.

- **The alias map is overloaded with skip semantics (flagged by both prior reviews, unfixed).** Line 115: "Mark a row's primary key as `aliases[n] = null` to drop it from the registry." This mixes two operations (alias resolution and skip filtering) in one data structure. A reader scanning the alias map sees `{'AutoGen/AG2': 'AutoGen', 'SomePlaceholder': null}` — the null has no semantic meaning without reading the prose.

- **`lowest-of-majors` returns `unverified` but the rule says "change the schema to match the rule" (line 185).** This inverts normal API design. If a user schema has `values: ["true", "false", "partially-true"]` and uses `majority-with-uncertain` for the verdict field, the rule silently returns `unverified` — a value the schema doesn't accept. The rule should respect the schema's `conflict_resolution.verdict_uncertain_value` override, as line 185 itself suggests — but then contradicts by saying "Do NOT change the rule's return value."

**What is unclear or ambiguous:**

- **Line 82: "supply an alias map at run time."** How? This has been flagged by both prior reviews. Is it a CLI flag? Part of `--schema`? A separate file? Embedded in `run-manifest.json`? The research example hardcodes it, but the core rules don't specify the interface.

- **Line 129-132: "Match if normalized titles are ≥80% similar"** — the threshold is hardcoded. For short titles ("BMAD" vs "BMAD Method"), 80% token-overlap is easy to hit. For long titles ("Microsoft Agent Framework" vs "MAF"), 80% Levenshtein similarity is impossible. The threshold should be adaptive or the algorithm should be specified (see above).

---

### 5. rules/output-schema.md

**What works well:**
- The markdown formatting rules (lines 258-269) are critical and well-specified — every rule was learned from real WYSIWYG failures.
- The two-mode output structure (schema vs free-form) is cleanly delineated.

**What is missing or wrong:**

- **`run-manifest.json` schema is stale (flagged by both prior reviews, unfixed).** This file (lines 209-237) is missing `phases_completed`, `consolidation`, `schema_auto_injected`, and `aliases`. The file explicitly says "This is the canonical schema" (line 209) but is out of date. This is the most-repeated finding across all three reviews.

- **§3 "Per-Item Details" (lines 100-115) leaks research-specific fields.** Line 109: `gaps_vs_reference = ... ; reference_gaps_vs_them = ...` — these are research-prior-art fields. A code-review user reading §3 would be confused. Replace with truly generic examples.

- **The Markdown formatting rules section (lines 258-269) has no section number (flagged by R3, unfixed).** It follows §8 but isn't numbered. Should be §9 for cross-reference consistency.

- **`run-manifest.json` doesn't capture timing data.** The schema has `timestamp` (start time) but no `duration_ms`, no per-model timing, no consolidation wall-time. For a skill that lists "Latency of slowest model + consolidation is OK" as a decision criterion (SKILL.md:41), the manifest doesn't capture the data needed to evaluate that criterion. A user who wants to know "how long did consolidation take?" has no answer.

- **The `conflicts.md` file and §4 of `consolidated.md` are specified as separate outputs but with identical content.** output-schema.md:205 says `conflicts.md` is "Same as §4 but as a standalone file (for tooling that consumes it)." What tooling? If there's no consumer, this is duplication. If there is, name it.

**What is unclear or ambiguous:**

- **Lines 130-131: §5 (Aggregated Scores) and §8 (Synthesized Verdict) are "optional" but §6 (Negative Results) and §7 (Open Questions) are not marked optional.** Are they always produced? What if there are no negative results — is §6 omitted or produced empty? The optionality contract is inconsistent.

- **Line 70: "Conflict marker legend (place at top of section)"** — but §2A comes before §4. If conflict markers are in §2A's table, the reader hasn't seen the conflict resolution rules yet. Either move §4 before §2, or add a forward reference.

---

### 6. rules/examples/research-prior-art.md

**What works well:**
- The full prompt template (lines 37-68), schema (lines 72-99), scoring rubric (lines 104-118), and alias map (lines 125-141) together form a complete, copy-pasteable recipe. This is the only example that's been run end-to-end.

**What is missing or wrong:**

- **The schema uses `"primary_key": "name"` (line 75) — a field that doesn't exist in the schema spec.** SKILL.md:96 shows `"primary_key": "item"` in the schema example, but the actual schema spec defines composite keys via `dedup_key: true` on individual columns (SKILL.md:142). The code-review example (code-review.md:70) explicitly says: "Why the old `'primary_key': 'file:line'` is wrong: the skill spec says composite keys are expressed by listing multiple columns with `dedup_key: true` — not by concatenating strings. The string-form `primary_key` is not a recognized schema field." Yet the research example — the ONLY proven example — uses exactly that pattern. Either `primary_key` is a valid schema field (and the code-review example is wrong), or it's not (and the research example is wrong). This is a cross-file contradiction.

- **No consolidated output snippet (flagged by both prior reviews, unfixed).** Lines 154-167 list section headings but show no actual table rows, conflict resolution examples, or scoring matrix rows. The reader must find the consolidated report separately.

- **The bash dispatch (lines 18-32) doesn't show `--schema` being passed.** Line 173 says "the prompt did NOT embed the schema; the skill auto-injected it because `--no-auto-inject` was not passed" — but where does the schema come from? The bash snippet doesn't show `--schema <file>`. This is a gap in the example's completeness.

**What is unclear or ambiguous:**

- **Line 182: "diminishing returns past 6 (this is an empirical observation, not a measured curve)"** — honest but weakens the recommendation. Either cite the data or don't state a number.

---

### 7. rules/examples/code-review.md

**What works well:**
- The composite-key correction (lines 70-71) is pedagogically valuable — shows the wrong way and the right way.
- Custom strategies table (lines 93-100) maps each field to a named rule with rationale.

**What is missing or wrong:**

- **No worked example (line 111: "Not yet produced (deferred to v2.2.0)").** Same gap as prior reviews. The "task-agnostic" claim rests on one proven example.

- **Line 107: "Pre-commit hook ... NOT currently supported"** — this is a feature wishlist item in an "Example" file. It's not an example; it's a roadmap item.

- **The bash dispatch (lines 33-42) doesn't pass `--dangerously-skip-permissions` — but the prompt asks models to "Review the file at /path/to/code.py."** If the model needs to READ the file via the `read` tool, it needs tool permissions. The `--dangerously-skip-permissions` flag is about tool permissions, not write permissions. Line 45 says "code review is a read-only task — the models just read and report" — but "read-only" and "no tool permissions needed" are different things. The security note conflates them.

- **The schema at line 49-65 uses `dedup_key: true` on `file` and `line` — correct per the spec. But the research example (research-prior-art.md:75) uses `"primary_key": "name"` — which the code-review example (line 70) explicitly says is wrong.** These two examples contradict each other on schema syntax. An implementor reading both will be confused about which form is correct.

**What is unclear or ambiguous:**

- **Line 33: the dispatch uses only 2 models.** The `majority` conflict-resolution rule (used for `category`) needs ≥3 models to produce a majority. With 2 models and 2 different values, `majority` returns `null` (consolidation-rules.md:178). The example should either use ≥3 models or note that `majority` is degenerate with N=2.

---

### 8. rules/examples/fact-check.md

**What works well:**
- Consensus requirements (lines 103-109) with parameterized thresholds are well-specified.
- "Key customization for fact-check" (lines 73-77) explains WHY each rule choice matters.

**What is missing or wrong:**

- **No worked example (line 113: "deferred to v2.2.0").** Same gap.

- **Line 77: changelog entry embedded in example file.** "`sources: 'url_list'` is now formally defined in the schema spec (was a v2.1.0 gap)" — this is version history, not example documentation.

- **Line 109: self-referential to a deleted draft.** "The '3+ models' rule in the original draft was a typo" — the reader can't see the original draft. Remove.

- **The distinction between `partially-true` and `unverified` is never defined (flagged by R3, unfixed).** Both are valid verdict values in the schema (line 24). Line 76 says "`unverified` is a valid output" but doesn't explain when to use `partially-true` vs `unverified`. Is `partially-true` for "the claim is half-right" and `unverified` for "insufficient evidence"? The schema allows both; the prose doesn't distinguish them.

- **Line 104 introduces a `confirmed` status not in the schema.** "≥ `max(2, ceil(N/2))` models agree on `true` with high confidence + primary source → confirmed." But the schema's enum (line 60) is `["true", "false", "partially-true", "unverified"]` — `confirmed` is not a valid value. Is `confirmed` the same as `true`? If so, don't introduce a new term.

**What is unclear or ambiguous:**

- **Line 74: "require ≥ `max(2, ceil(N/2))` models to agree for a clean verdict (so for N=3 you need 2 votes, not 3)"** — the parenthetical says "not 3" but `ceil(3/2) = 2`, so `max(2, 2) = 2`. The math is correct but the parenthetical is confusing — "not 3" implies someone might think 3 is required. Just state the formula and give the example.

---

## §2. Score the Skill on the 8-Dimension Rubric

| Dimension | Score | Justification |
|-----------|-------|---------------|
| **Catalog of composable units** | **2** | Machine-readable catalog: 9 named conflict-resolution rules with algorithm specs, 8 column types with validation rules, 4 dispatch mechanisms with selection criteria, 3 consolidation modes. The schema JSON is the catalog format. This is genuinely strong. |
| **Dynamic composition** | **1** | Configuration drives behavior (`--mode`, `--schema`, `--models`), and `run-manifest.json` provides an audit trail. But no runtime replanning, no dynamic model substitution on failure, no adaptive extraction. |
| **V-loop depth** | **1** | `thorough` mode adds a verification loop. But no per-step rollup, no intent gate, no V-model traceability. `phases_completed` is a list of integers, not a traceability matrix. |
| **Enforcement** | **0** | Honor system only. No IDE hooks, no CI integration, no delivery blockers. Nothing prevents misuse. |
| **Parent/worker split** | **2** | Explicit orchestrator/worker with fail-soft design. The "extractor model" role is a designated fallback worker. |
| **Evidence model** | **2** | Tiered sufficiency with staleness: `source_refs`, `prefer-with-evidence-then-newer-then-strict`, `thorough` mode verification, `last_verified`. More sophisticated than many production systems. |
| **SE + DevOps unified** | **1** | Code-review example covers SE. But DevOps coverage is thin — no infrastructure review, config audit, or deployment verification example. "Covers both" is claimed but only SE is demonstrated. |
| **Team customization** | **1** | Schemas act as "process packs" but no overlay/extension mechanism. Can't extend a base schema with extra columns. No schema inheritance. |
| **TOTAL** | **10/16** | |

**Difference from R3 review (10/16):** Same score. R3 downgraded SE+DevOps from 2 to 1 (correct). All other dimensions hold.

**Difference from R2 review (11/16):** R2 scored SE+DevOps at 2 (incorrect — only SE demonstrated) and Enforcement at 0 (correct). Net: 10 vs 11.

---

## §3. Top 5 Improvements (ranked by impact × effort)

### 1. Resolve the `primary_key` schema field contradiction between research and code-review examples

- **Issue:** research-prior-art.md:75 uses `"primary_key": "name"` in the schema JSON. code-review.md:70 explicitly says this is wrong: "The string-form `primary_key` is not a recognized schema field." The only proven example uses a pattern the other example says is invalid.
- **Why it matters:** An implementor reading both examples will not know which schema syntax is correct. The research example is the only proven run — if its schema is wrong, the provenance is questionable.
- **Concrete change:** In `research-prior-art.md:72-99`, replace `"primary_key": "name"` with `"dedup_key": true` on the `name` column definition:
  ```json
  {"name": "name", "type": "string", "dedup_key": true},
  ```
  Then update the schema example in SKILL.md:94-113 to also use `dedup_key: true` instead of `"primary_key": "item"`. This aligns all examples with the spec at SKILL.md:142.
- **Effort:** Low (edit 2 files, ~5 lines)
- **Impact:** High (resolves cross-file contradiction in the schema spec)
- **Score:** High / Low = **High ROI**

### 2. Fix the stale `run-manifest.json` canonical schema (3rd consecutive review flagging this)

- **Issue:** `run-manifest.json` schema defined in two places with different fields. output-schema.md claims canonicity (line 209) but is missing 4 fields added in v2.1.0. methodology.md:145-147 redirects to output-schema.md. Neither file has the complete set.
- **Why it matters:** This has been flagged in 3 consecutive reviews (R2, R3, R4) and remains unfixed. Every implementer following output-schema.md will produce manifests missing `phases_completed`, `consolidation`, `schema_auto_injected`, and `aliases`.
- **Concrete change:** In `output-schema.md:207-237`, replace the JSON block and field semantics with:
  ```markdown
  ### `run-manifest.json`

  **Canonical schema is defined in `rules/methodology.md` § Phase 4.**
  This file references it for output-structure purposes only.

  Required fields: `timestamp`, `task_prompt`, `task_prompt_hash`, `mode`,
  `schema_provided`, `schema_auto_injected`, `schema`, `models_dispatched`,
  `models_responded`, `models_failed`, `output_dir`, `aliases`, `totals`,
  `consolidation`, `phases_completed`.
  ```
  Then ensure methodology.md has the complete, authoritative schema with all fields.
- **Effort:** Low (edit 2 files, ~15 lines)
- **Impact:** High (data-integrity bug; every run affected)
- **Score:** High / Low = **High ROI**

### 3. Add timeout enforcement to the default Mechanism 2 dispatch snippet (3rd consecutive review flagging this)

- **Issue:** The bash snippet in `dispatch-mechanics.md:36-53` defines `TIMEOUT=600` but never uses it in the `npx` command. The fix is described in prose (line 62) but not in the code.
- **Why it matters:** This has been flagged in 3 consecutive reviews. The DEFAULT mechanism's copy-pasteable snippet silently fails on tasks longer than 2 minutes.
- **Concrete change:** In `dispatch-mechanics.md:44-50`, wrap the `npx` command with timeout enforcement:
  ```bash
  # macOS: gtimeout from brew install coreutils; Linux: timeout is a coreutil
  if command -v gtimeout &>/dev/null; then
    gtimeout "$TIMEOUT" npx -y opencode-ai run \
      --model "$model" \
      --title "multi-ai-task-${slug}-$(date +%s)" \
      --dangerously-skip-permissions \
      "$PROMPT" \
      > "$OUT/${slug}.md" 2> "$OUT/${slug}.err" &
  else
    timeout "$TIMEOUT" npx -y opencode-ai run \
      --model "$model" \
      --title "multi-ai-task-${slug}-$(date +%s)" \
      --dangerously-skip-permissions \
      "$PROMPT" \
      > "$OUT/${slug}.md" 2> "$OUT/${slug}.err" &
  fi
  ```
- **Effort:** Low (edit 1 file, ~10 lines)
- **Impact:** High (prevents the most common silent failure mode)
- **Score:** High / Low = **High ROI**

### 4. Fix the `concatenate` vs `concatenate-all` naming inconsistency

- **Issue:** consolidation-rules.md:307 says "Use `concatenate` for comments" (writing critique row), but the rule library (lines 199-203) defines the rule as `concatenate-all`. These are different names.
- **Why it matters:** An implementor building the writing critique recipe will look up `concatenate` in the rule library and find nothing. They'll either implement a non-existent rule or give up.
- **Concrete change:** In `consolidation-rules.md:307`, change:
  ```
  | **Writing critique** | Use `concatenate` for comments; present all model feedback in parallel sections |
  ```
  To:
  ```
  | **Writing critique** | Use `concatenate-all` for comments; present all model feedback in parallel sections |
  ```
- **Effort:** Low (edit 1 file, 1 word)
- **Impact:** Medium (prevents implementor confusion on the writing critique recipe)
- **Score:** Medium / Low = **High ROI**

### 5. Add `duration_ms` and per-model timing to `run-manifest.json`

- **Issue:** The manifest captures `timestamp` (start time) but no duration, no per-model timing, no consolidation wall-time. For a skill that lists "Latency of slowest model + consolidation is OK" as a decision criterion (SKILL.md:41), the manifest doesn't capture the data needed to evaluate that criterion.
- **Why it matters:** Users can't answer "how long did this run take?" or "which model was slowest?" from the manifest. This data is needed for the "When NOT to use" latency evaluation and for optimizing future runs.
- **Concrete change:** In `methodology.md` (the canonical `run-manifest.json` schema), add to the `totals` object:
  ```json
  "totals": {
    "rows_per_model": {"m1": 25, "m2": 30},
    "unique_items_consolidated": 36,
    "conflicts_resolved": 8,
    "duration_ms": 180000,
    "per_model_duration_ms": {"m1": 120000, "m2": 95000, "m3": 180000},
    "consolidation_duration_ms": 5000
  }
  ```
- **Effort:** Low (edit 1 file, ~5 lines added to schema)
- **Impact:** Medium (enables latency evaluation and run optimization)
- **Score:** Medium / Low = **High ROI**

---

## §4. Open Questions

1. **Is `primary_key` a valid schema field or not?** The research example uses it; the code-review example says it's not a recognized field; SKILL.md:96 shows it in an example schema. This is a fundamental ambiguity in the spec. The answer determines whether the proven research run's schema was valid.

2. **Is the skill intended as a procedural document or a software artifact?** The entire skill is Markdown rules — no executable code, no reference implementation, no tests. Every agent must re-implement the dedup/conflict/extraction logic from prose. Is there a planned library, or is reimplementation-from-prose the intended design?

3. **What happens for non-list-shaped outputs?** The consolidation model assumes items are decomposable into a list. Writing critique (prose), refactoring suggestions (code), and architecture proposals (structured documents) don't naturally decompose. The free-form Mode B (H2-split) is a lossy heuristic. Is there a plan for non-list consolidation, or should the skill explicitly scope itself to list-shaped tasks?

4. **What's the distinction between `partially-true` and `unverified` in fact-check?** Both are valid verdict values. The prose doesn't distinguish them. Is `partially-true` for "the claim is half-right" and `unverified` for "insufficient evidence"? This needs a concrete decision rule.

5. **How does the calling agent detect completion when using Mechanism 1 (task tool)?** The bash `&` + `wait` pattern works for Mechanism 2. But if the skill is invoked via `task` tool, how does the orchestrator know all sub-models are done? Is there a completion signal?

6. **What's the consolidation wall-time?** For 36 items × 6 models, how long do Phases 3-4 take? The skill says "latency of slowest model + consolidation" but gives no bounds for the consolidation part.

7. **Why are code-review and fact-check proofs deferred to v2.2.0?** The generalization claim (task-agnostic) is undermined by having only one proven use case. What's the plan?

8. **Does `--no-auto-inject` do anything in free-form mode (no `--schema`)?** If no schema is passed, there's nothing to inject. Is the flag silently ignored? The spec doesn't say.

---

## §5. Confidence

- **Overall confidence:** High
- **What would change my assessment:**
  1. Resolution of the `primary_key` contradiction — if `primary_key` IS a valid schema field, the code-review example needs correction. If it's NOT, the research example's schema needs correction and the proven run's schema was invalid.
  2. A worked code-review or fact-check run would validate or invalidate the generalization claim.
  3. An executable reference implementation (even a 200-line Node script) would dramatically increase confidence that the algorithms are implementable from the prose.
