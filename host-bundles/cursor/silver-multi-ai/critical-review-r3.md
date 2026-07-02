# Critical Self-Review: multi-ai-task Skill (Round 3)

**Review date:** 2026-06-27
**Reviewed version:** 2.1.0 (SKILL.md frontmatter)
**Reviewer:** Independent critical review (not a re-run of the skill; direct read + analysis)
**Prior review:** `self-review.md` (round 2) — this review overlaps on some points but adds new findings and goes deeper on implementation gaps.

---

## §1. Critical Assessment

### 1. SKILL.md

**What works well:**
- The "When to use / When NOT to use" table is one of the best decision matrices in the SB skill ecosystem — concrete enough to actually prevent misuse.
- The schema parameter section (lines 86-155) is the most detailed part of the skill: column types, composite keys, conflict-resolution rule names, auto-injection behavior. Someone could implement a schema parser from this alone.

**What is missing or wrong:**
- **`--concurrency` is declared in `argument-hint` (line 4) but never defined.** The inputs table (lines 62-69) does not list it. The only mention of parallel vs sequential behavior is in `dispatch-mechanics.md:97-107`, which describes it as a user choice, not a CLI flag. A caller parsing the argument-hint will expect a `--concurrency` flag that doesn't exist in the spec.
- **The "What this skill does NOT do" list (lines 24-29) contains a self-contradiction.** Line 28: "Inject the schema into the prompt unless `--no-auto-inject` is set (default ON)." The parenthetical says the default is to inject. But the clause says "does NOT do" — inject. The sentence reads: "This skill does NOT inject the schema ... unless you opt out of NOT injecting." Double negation. Should be: "Inject the schema into the prompt (default ON; pass `--no-auto-inject` to disable)."
- **Line 194: "These are the core value of the skill; everything else is plumbing."** This is wrong and self-defeating. The dispatch mechanisms, extraction fallbacks, failure handling, HTML rendering, and the evidence model are all part of the value. Calling them "plumbing" tells the reader to skip those sections. The sentence should be deleted.

**What is unclear or ambiguous:**
- **Line 73-75: "at least one reasoning-capable model if the task is research-like."** The skill claims to be task-agnostic, so how does it detect "research-like"? Is this a heuristic on the prompt text? A user flag? Left to the user's judgment? If the latter, say so explicitly: "If your task involves finding and comparing external sources, include a reasoning-focused model."
- **Line 152-153: "Free-form mode uses 'one-row-per-paragraph (very lossy)'" with "fuzzy match on first 5 words."** The first-5-words heuristic is acknowledged as fragile but no alternative is offered. What happens when a model writes multi-paragraph items? The skill silently produces garbage. This needs a confidence flag or a "low-confidence" warning in the output.

---

### 2. rules/methodology.md

**What works well:**
- The extraction pseudocode (Phase 2, Mode A, lines 37-64) is concrete, ordered, and implementable — the 4 fallback paths are clearly sequenced with rationale.
- The "Deterministic + LLM-assisted hybrid" principle (lines 156-161) makes the design trade-off explicit.

**What is missing or wrong:**
- **`run-manifest.json` schema is duplicated and stale.** methodology.md:145-147 says "The canonical schema lives in `rules/output-schema.md`." But output-schema.md:209-237 defines the schema WITHOUT `phases_completed`, `consolidation`, `schema_auto_injected`, and `aliases` — all present in methodology.md's prose. Two files both claim canonicity; one is wrong. This is a data-integrity bug.
- **Phase 3, step 4 (line 115-116) says "Score aggregation: compute median + min/max." Phase 3.6 (consolidation-rules.md:266) says "Aggregate scoring matrix: Build a single table."** These overlap. Is scoring done in Phase 3 or Phase 3.6? If Phase 3 does per-item aggregation and 3.6 does the matrix, that's fine — but it's not stated.
- **Line 157: "Structured extraction (Mode A) is deterministic — pure parsing, no LLM in the loop."** This is false. Mode A fallback path 3 (line 52-58) dispatches an extractor LLM. The claim should be: "Structured extraction is deterministic when the model produces a compliant table; LLM-assisted fallbacks are used otherwise."

**What is unclear or ambiguous:**
- **Line 104: "Extractor model — Default: the slowest, highest-capability model from the original dispatch."** How is "highest-capability" determined? Is there a model capability ranking? Is it the model with the largest context window? The most parameters? This needs a concrete heuristic (e.g., "prefer models in order: reasoning-focused > generalist > code-specialized").
- **Line 173: "Idempotent re-runs — the skill can be re-run with the same task-prompt and produce a new consolidated output."** This isn't idempotent — it's just re-runnable. Idempotent means same input → same output. Different model responses each time means different output. The term is misused.

---

### 3. rules/dispatch-mechanics.md

**What works well:**
- The 4-mechanism decision table at the bottom (lines 172-181) is genuinely useful — maps constraints to mechanisms.
- Real-world bug references (issue #18615, 6 issues for task tool model field) add credibility.

**What is missing or wrong:**
- **The default Mechanism 2 bash snippet (lines 36-53) doesn't set a timeout.** The `TIMEOUT=600` variable is defined (line 41) but never used in the `npx` command (lines 44-50). The variable exists; the enforcement doesn't. A reader copy-pasting this will hit the 2-min default timeout on long tasks. The fix: add `timeout $TIMEOUT` before `npx` (Linux) or `gtimeout $TIMEOUT` (macOS), as described in line 62 — but the description is prose, not in the code.
- **Line 62: "use `timeout $TIMEOUT npx -y opencode-ai run ...` on Linux or `gtimeout $TIMEOUT npx ...` on macOS"** — this is the fix, buried in a paragraph after the broken snippet. The snippet itself should be fixed, not the paragraph after it.
- **Mechanism 4 code example (lines 85-93) is a skeleton, not a working example.** It references `ENDPOINTS`, `KEYS`, and `model.id`/`model.provider` without defining them. No error handling, no auth, no rate limits. If this is meant to be "for reference only," label it as such. Currently it looks like it should work.
- **Lines 107-112: "Always check the model's CWD for stray `*.md` files after a dispatch."** The calling agent has no access to the model's CWD. This is advice for a human user, not for an automated skill. It should be under a "Manual post-run steps" heading, not mixed with automated pipeline guidance.

**What is unclear or ambiguous:**
- **Line 106: "configure MCPs that support multiplexing"** — how? What MCPs support this? Is there a config flag? This is a concrete technical recommendation with zero concrete details.

---

### 4. rules/consolidation-rules.md

**What works well:**
- The named rule library (lines 163-221) is the strongest part of the entire skill. Every rule has: purpose, input spec, algorithm pseudocode, edge cases. This is genuinely implementable from the prose alone.
- The conflict documentation template (lines 227-234) uses real examples, not placeholders.

**What is missing or wrong:**
- **`most-severe` edge case directly contradicts the code-review example.** consolidation-rules.md:171 says: "if 1/N reviewers says `blocker` and all others say `major` (or lower), and the lone `blocker` has no evidence quote, the schema may declare `allow_downgrade: true` to downgrade." Default is `allow_downgrade: false`. But code-review.md:96 says: "Safety: don't downgrade a blocker just because one reviewer missed it." These agree on the default (don't downgrade). HOWEVER, consolidation-rules.md:171 also says "This matches the code-review safety principle" — but the preceding text says the DEFAULT is `allow_downgrade: false`, which means the lone blocker WINS. The prose is internally confusing: it describes the downgrade option first, then says the default is to NOT downgrade. A reader skimming will miss the default. Rewrite to lead with the default.
- **Phase numbering is chaotic.** This file uses "Phase 2", "Phase 3", "Phase 3.5", "Phase 3.6" — but methodology.md uses "Phase 1-4" with different boundaries. Phase 3.5 here (conflict resolution) is part of Phase 3 in methodology.md. Phase 3.6 here (score + synthesize) is Phase 4 in methodology.md. The numbering doesn't match across files.
- **Line 185: "Do NOT change the rule's return value to match the schema — change the schema to match the rule."** This inverts normal API design. Configuration should drive behavior, not the other way around. If a user's schema has `values: ["true", "false", "partially-true"]` and they want `unverified` to mean `partially-true`, the rule should respect the schema's `conflict_resolution` config, not silently return a value the schema doesn't accept.
- **Line 115: "Mark a row's primary key as `aliases[n] = null` to drop it from the registry."** This overloads the alias map with skip semantics. The alias map should map aliases → canonical names. Using `null` as a sentinel for "skip" is a code smell — a separate `skip_keys` set would be clearer.

**What is unclear or ambiguous:**
- **Line 82: "supply an alias map at run time."** How? Is it a CLI flag? Part of `--schema`? A separate file? The research example hardcodes it, but the core rules don't specify the interface.
- **Line 131: "Match if normalized titles are >=80% similar (Levenshtein or token-overlap)."** Which one? Levenshtein and token-overlap produce different results for the same input. This needs to be one algorithm, not an either/or.

---

### 5. rules/output-schema.md

**What works well:**
- The markdown formatting rules (lines 258-269) are critical and well-specified — every rule was clearly learned from real WYSIWYG rendering failures.
- The two-mode (schema vs free-form) output structure is cleanly delineated.

**What is missing or wrong:**
- **`run-manifest.json` schema is stale.** This file (lines 209-237) is missing `phases_completed`, `consolidation`, `schema_auto_injected`, and `aliases` — all defined in methodology.md. The file that explicitly says "This is the canonical schema" (line 209) is out of date. This is the single most impactful bug in the skill.
- **§3 "Per-Item Details" (lines 100-115) leaks research-specific fields into generic documentation.** Line 109: `gaps_vs_reference = ... ; reference_gaps_vs_them = ...` — these are research-prior-art fields, not generic. A code-review user reading §3 would be confused. Replace with truly generic examples.
- **The Markdown formatting rules section (lines 258-269) has no section number.** It follows §8 but isn't numbered. This makes it impossible to reference in cross-file documentation. Should be §9.
- **Line 70: "Conflict marker legend (place at top of section)"** — but §2A comes before §4 (Conflicts & Resolutions). If conflict markers are in §2A's table, the reader hasn't seen the conflict resolution rules yet. Either move §4 before §2, or add a forward reference.

**What is unclear or ambiguous:**
- **Lines 130-131: §5 (Aggregated Scores) and §8 (Synthesized Verdict) are marked "optional."** But §6 (Negative Results) and §7 (Open Questions) are not marked optional. Are they always produced? What if there are no negative results — is §6 omitted or produced empty? The optionality contract is inconsistent.

---

### 6. rules/examples/research-prior-art.md

**What works well:**
- The full prompt template (lines 37-68), schema (lines 72-99), scoring rubric (lines 104-118), and alias map (lines 125-141) together form a complete, copy-pasteable recipe. This is the only example that's actually been run end-to-end.
- The alias map with 14 entries is a strong reference for research dedup.

**What is missing or wrong:**
- **No consolidated output snippet.** Lines 154-167 list section headings but show no actual table rows, no conflict resolution example, no scoring matrix. The reader must find `docs/research-260624/SB_CONSOLIDATED_PRIOR_ART_REPORT.md` separately. A 5-row excerpt would make this example self-contained.
- **The bash dispatch (lines 18-32) and the prompt template (lines 37-68) are disconnected.** The dispatch uses `cat /path/to/research-prompt.md` (line 20) but the template is inline. A reader might not realize they need to save the template to a file first.
- **Line 173: "the prompt did NOT embed the schema; the skill auto-injected it because `--no-auto-inject` was not passed"** — but the bash dispatch (lines 18-32) doesn't show `--schema` being passed either. Where does the schema come from? The example implies the schema is passed separately, but the bash snippet doesn't show it.

**What is unclear or ambiguous:**
- **Line 182: "diminishing returns past 6 (this is an empirical observation, not a measured curve)"** — honest but weakens the recommendation. Either cite the marginal-uniqueness data from the 6-model run or don't state a number.

---

### 7. rules/examples/code-review.md

**What works well:**
- The composite-key correction (lines 70-71) is pedagogically valuable — shows the wrong way and the right way.
- Custom strategies table (lines 93-100) maps each field to a named rule with rationale.

**What is missing or wrong:**
- **No worked example (line 111: "Not yet produced (deferred to v2.2.0)").** This is the second-most-concrete use case for the skill and it has no proven run. The "task-agnostic" claim rests on one proven example (research).
- **Line 107: "Pre-commit hook ... NOT currently supported as a built-in dispatch; requires custom runner"** — this is a feature wishlist item in an "Example" file. It's not an example; it's a roadmap item.
- **The bash dispatch (lines 33-42) doesn't pass `--dangerously-skip-permissions`.** Line 45 says "the dispatch above does NOT pass `--dangerously-skip-permissions`" — correct, but the code-review prompt asks models to "review the file at /path/to/code.py." If the model needs to READ the file, it needs file-system access. Does `opencode run` grant that by default? The example doesn't address this.

**What is unclear or ambiguous:**
- **Line 45: "code review is a read-only task — the models just read and report, they don't write."** But the prompt says "Review the file at /path/to/code.py." If the model uses `read` tool to access the file, it needs tool permissions. The `--dangerously-skip-permissions` flag is about tool permissions, not write permissions. The security note conflates "read-only task" with "no tool permissions needed."

---

### 8. rules/examples/fact-check.md

**What works well:**
- Consensus requirements (lines 103-109) with parameterized thresholds (`max(2, ceil(N/2))`) are well-specified.
- "Key customization for fact-check" (lines 73-77) explains WHY each rule choice matters.

**What is missing or wrong:**
- **No worked example (line 113: "deferred to v2.2.0").** Same gap as code-review.
- **Line 77: "`sources: 'url_list'` is now formally defined in the schema spec (was a v2.1.0 gap)"** — changelog information embedded in an example file. Should be in a changelog.
- **Line 109: "The '3+ models' rule in the original draft was a typo"** — self-referential to a deleted draft. Remove.
- **The distinction between `partially-true` and `unverified` is never defined.** Line 24 lists both as valid verdict values, and line 76 says "`unverified` is a valid output" but doesn't explain when to use `partially-true` vs `unverified`. Is `partially-true` for "the claim is half-right" and `unverified` for "we couldn't find enough evidence"? The schema allows both; the prose doesn't distinguish them.

**What is unclear or ambiguous:**
- **Line 104: "≥ `max(2, ceil(N/2))` models agree on `true` with high confidence + primary source → confirmed."** But the schema's conflict resolution is `majority-with-uncertain`, which returns `unverified` if the threshold isn't met. It doesn't return `confirmed` — it returns `true`. The prose introduces a `confirmed` status that's not in the schema's enum. Is `confirmed` the same as `true`? If so, don't introduce a new term.

---

## §2. Score the Skill on the 8-Dimension Rubric

| Dimension | Score | Justification |
|-----------|-------|---------------|
| **Catalog of composable units** | **2** | Machine-readable catalog: 9 named conflict-resolution rules with algorithm specs, 8 column types with validation rules, 4 dispatch mechanisms with selection criteria, 3 consolidation modes. The schema JSON is the catalog format. This is genuinely strong. |
| **Dynamic composition** | **1** | Configuration drives behavior (`--mode`, `--schema`, `--models`), and `run-manifest.json` provides an audit trail. But no runtime replanning (mode can't change mid-run), no dynamic model substitution on failure (the skill is fail-soft but doesn't re-dispatch), and no adaptive extraction (can't switch from table parse to LLM extraction mid-pipeline based on partial results). |
| **V-loop depth** | **1** | `thorough` mode adds a verification loop (per-item source checking). But no per-step rollup (can't inspect intermediate extracts), no intent gate (no confirmation that consolidation matches user intent before final output), and no V-model traceability from output back through each phase. The `phases_completed` field in run-manifest is a list of integers, not a traceability matrix. |
| **Enforcement** | **0** | Honor system only. The skill is a Markdown document — no IDE hooks, no CI integration, no delivery blockers, no pre-commit checks. Nothing prevents a user from reading the skill and dispatching to a single model without consolidation. The skill's value depends entirely on the user's discipline to follow it. |
| **Parent/worker split** | **2** | Explicit orchestrator/worker: consolidation engine (Phase 3-4) is the orchestrator; per-model dispatches (Phase 1) are workers with defined output contracts. Fail-soft preserves partial results. The "extractor model" role is a designated worker for fallback extraction. |
| **Evidence model** | **2** | Tiered sufficiency with staleness: (1) `source_refs` in structured extraction; (2) `prefer-with-evidence-then-newer-then-strict` treats evidence-backed claims as higher authority; (3) `thorough` mode adds per-source verification with `evidence-ledger.md`; (4) `last_verified` tracks staleness. More sophisticated than many production systems. |
| **SE + DevOps unified** | **1** | The code-review example covers SE tasks. But the DevOps coverage is thin — the fact-check example is domain-agnostic, not DevOps-specific. There's no example for infrastructure review, config audit, or deployment verification. "Covers both" is claimed but only SE is demonstrated. Score 1 (partial). |
| **Team customization** | **1** | Schemas and recipes act as "process packs" but no overlay/extension mechanism. A team must write a new schema from scratch — can't extend a base schema with extra columns. No schema inheritance, no merge strategy for team-specific rules. |
| **TOTAL** | **10/16** | |

**Difference from prior review (11/16):** I score SE+DevOps at 1 (not 2) because only SE is demonstrated. I score Enforcement at 0 (same). I score V-loop at 1 (same). Net: 10 vs 11.

---

## §3. Top 5 Improvements (ranked by impact × effort)

### 1. Fix `run-manifest.json` duplication — make one file canonical

- **Issue:** `run-manifest.json` schema defined in two places with different fields; `output-schema.md` version is stale (missing v2.1.0 fields)
- **Why it matters:** Every implementer will pick one file to follow. If they pick `output-schema.md` (which explicitly says "This is the canonical schema"), they'll produce manifests missing `phases_completed`, `consolidation`, `schema_auto_injected`, and `aliases` — breaking audit reproducibility.
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
  Then ensure `methodology.md:145-147` is the single source of truth with all fields.
- **Effort:** Low (edit 2 files, ~15 lines)
- **Impact:** High (data-integrity bug; every run affected)
- **Score:** High / Low = **High ROI**

### 2. Add timeout enforcement to the default Mechanism 2 dispatch snippet

- **Issue:** The bash snippet in `dispatch-mechanics.md:36-53` defines `TIMEOUT=600` but never uses it in the `npx` command. The fix is described in prose (line 62) but not in the code.
- **Why it matters:** This is the DEFAULT mechanism. Every reader copy-pasting the snippet will hit silent timeout failures on tasks longer than 2 minutes.
- **Concrete change:** In `dispatch-mechanics.md:44-50`, replace:
  ```bash
  npx -y opencode-ai run \
    --model "$model" \
    --title "multi-ai-task-${slug}-$(date +%s)" \
    --dangerously-skip-permissions \
    "$PROMPT" \
    > "$OUT/${slug}.md" 2> "$OUT/${slug}.err" &
  ```
  With:
  ```bash
  # macOS: use gtimeout if available, else run without per-model timeout
  if command -v gtimeout &>/dev/null; then
    gtimeout "$TIMEOUT" npx -y opencode-ai run \
      --model "$model" \
      --title "multi-ai-task-${slug}-$(date +%s)" \
      --dangerously-skip-permissions \
      "$PROMPT" \
      > "$OUT/${slug}.md" 2> "$OUT/${slug}.err" &
  else
    npx -y opencode-ai run \
      --model "$model" \
      --title "multi-ai-task-${slug}-$(date +%s)" \
      --dangerously-skip-permissions \
      "$PROMPT" \
      > "$OUT/${slug}.md" 2> "$OUT/${slug}.err" &
  fi
  ```
  And add a comment: `# TIMEOUT is in seconds; set based on task complexity (300 for review, 600 for research)`
- **Effort:** Low (edit 1 file, ~10 lines)
- **Impact:** High (prevents the most common silent failure mode)
- **Score:** High / Low = **High ROI**

### 3. Resolve `most-severe` prose confusion (not a contradiction, but misleading)

- **Issue:** `consolidation-rules.md:167-172` describes the `allow_downgrade` edge case before stating the default. A skimming reader will think the default is to downgrade.
- **Why it matters:** `most-severe` is the default rule for code-review severity — the most common non-research use case. Misleading prose → wrong implementation.
- **Concrete change:** In `consolidation-rules.md:167-172`, rewrite to:
  ```markdown
  #### `most-severe`
  - **Purpose:** pick the most-severe value across models (default for code-review severity, security audit findings).
  - **Input:** List of `(value, severity_order?)` per model. If `severity_order` is declared in the schema, use it. Otherwise default to: `["blocker", "major", "minor", "nit"]` (most-severe first).
  - **Algorithm:** `min(values, key=severity_order.index)` — index 0 = most-severe. Ties broken by `majority` among the max-severity tier. If N=0, return `null`.
  - **Default behavior:** the most-severe value wins even if only 1 reviewer reported it. This matches the code-review safety principle: "don't downgrade a blocker just because one reviewer missed it."
  - **Optional override:** set `"allow_downgrade": true` in the schema's `conflict_resolution` to downgrade a lone max-severity value (1 of N with no evidence quote) to the next tier. Use only when the task context requires conservative consensus (e.g., security audit with high false-positive risk). Default: `false`.
  ```
- **Effort:** Low (edit 1 file, ~8 lines reordered)
- **Impact:** High (core algorithm's documentation is misleading)
- **Score:** High / Low = **High ROI**

### 4. Fix the double negation in "What this skill does NOT do"

- **Issue:** SKILL.md:28 reads: "Inject the schema into the prompt unless `--no-auto-inject` is set (default ON)" under a "does NOT do" heading. Double negation.
- **Why it matters:** This is the entry point file. A confused reader here won't read the rest.
- **Concrete change:** In SKILL.md:28, replace:
  ```
  - Inject the schema into the prompt unless `--no-auto-inject` is set (default ON — see "The `--schema` parameter" below)
  ```
  With:
  ```
  - Inject the schema into the prompt by default (pass `--no-auto-inject` to disable; see "The `--schema` parameter" below)
  ```
  And move it from the "does NOT do" list to the "does" list (line 15-22), since by default it DOES inject.
- **Effort:** Low (edit 1 file, 2 lines)
- **Impact:** Medium (entry-point clarity)
- **Score:** Medium / Low = **High ROI**

### 5. Add a worked output snippet to the research example

- **Issue:** `research-prior-art.md:154-167` lists section headings but shows no actual output. The only proven example doesn't show what the output looks like.
- **Why it matters:** A reader evaluating the skill needs to see the output format to decide if it's useful. Listing headings is not enough.
- **Concrete change:** In `research-prior-art.md`, after line 167, add:
  ```markdown
  ### Output excerpt (from the 2026-06-27 run)

  **§2 Items Table (first 3 rows):**

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
  (Use real data from the 2026-06-27 run's consolidated report.)
- **Effort:** Low (edit 1 file, ~15 lines)
- **Impact:** Medium (makes the example self-contained)
- **Score:** Medium / Low = **High ROI**

---

## §4. Open Questions

1. **What is the actual version?** SKILL.md frontmatter says 2.1.0. The task description for this review says v2.0.0. fact-check.md:77 references a "v2.1.0 gap" fix. Was 2.1.0 a release? Is there a changelog? Without one, it's impossible to know what changed between versions.

2. **Is the skill a procedural document or a software artifact?** The entire skill is Markdown rules — no executable code, no reference implementation, no tests. The algorithms are described in enough detail to implement, but every agent must re-implement them from prose. Is there a planned library? Or is the intent that each agent rewrites dedup/conflict/extraction from scratch?

3. **How does the calling agent detect completion?** The bash `&` + `wait` pattern works when the calling agent IS the shell. But if the skill is invoked via `task` tool, how does the orchestrator know all sub-models are done? Is there a completion signal, or does it poll?

4. **What's the consolidation wall-time?** The skill says "latency of slowest model + consolidation" but gives no bounds for consolidation. For 36 items × 6 models, how long does Phase 3-4 take? Without this, users can't evaluate the "When NOT to use" latency criterion.

5. **How does model discovery work when `--models` is omitted?** SKILL.md:73-75 describes "balanced default set of 4-6 models" but no algorithm is specified. What if the config has 20 models? Which 4-6 are picked? Is there a heuristic, or is this left to the implementation?

6. **What's the distinction between `partially-true` and `unverified` in fact-check?** Both are valid verdict values in the schema. The prose doesn't distinguish them. Is `partially-true` for "the claim is half-right" and `unverified` for "insufficient evidence"? This needs a concrete decision rule.

7. **Why does `--no-auto-inject` exist when `--schema` is optional?** If no schema is passed, there's nothing to inject. If a schema is passed, injection is the default. The flag only matters when the user passes `--schema` AND doesn't want injection. Is this a real use case, or is the flag over-engineered?

8. **Does the skill work for non-list-shaped outputs?** The consolidation assumes items are decomposable into a list. What about tasks that produce prose (writing critique), code (refactoring suggestions), or structured documents (architecture proposals)? The "free-form" mode (Mode B) handles this by splitting on H2 headings, but that's a lossy heuristic, not a real solution.

---

## §5. Confidence

- **Overall confidence:** High
- **What would change my assessment:** A worked code-review or fact-check run would validate or invalidate the generalization claim. If the same extraction/dedup algorithms work cleanly on a second task type, the task-agnostic architecture is proven. If they require significant per-task customization, the skill should be scoped to "research + code-review" (the two most-specified use cases) until others are proven. Additionally, an executable reference implementation (even a 200-line Node script) would dramatically increase confidence that the algorithms are implementable from the prose.
