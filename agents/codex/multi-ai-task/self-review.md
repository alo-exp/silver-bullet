# Critical Self-Review: multi-ai-task Skill

**Review date:** 2026-06-27
**Reviewed version:** 2.1.0 (frontmatter) / 2.0.0 (context description — discrepancy noted below)
**Reviewer:** Parent orchestrator, applying this skill recursively (meta-task)

---

## §1. Critical Assessment

### 1. SKILL.md

**What works well:**
- The "When to use / When NOT to use" table is genuinely useful — concrete enough to make a real decision
- The `--schema` parameter section documents both structured and free-form modes with sufficient detail for someone to choose between them

**What is missing or wrong:**
- **Version inconsistency:** Frontmatter `version: 2.1.0` but the task description context says "v2.0.0." Neither value is documented in a changelog or with a diff of what changed. If 2.1.0 added `--no-auto-inject`, `aliases`, and `phases_completed`, that's not stated anywhere.
- **`--concurrency` is declared but underspecified.** The argument-hint and inputs table mention `--concurrency parallel|sequential`, but SKILL.md never explains what it actually changes in the pipeline. The reader must go to dispatch-mechanics.md to learn that parallel dispatches risk MCP port collision.
- **Self-deprecating framing damages credibility.** Line 194: "These are the core value of the skill; everything else is plumbing." Dispatch failure handling, extraction fallbacks, HTML rendering, and the evidence model are NOT plumbing — they're part of the value proposition and have caused real failures in proven runs (see failure-modes table entries 2, 5, 7, 8).

**What is unclear or ambiguous:**
- Line 74: "at least one reasoning-capable model if the task is research-like" — how does the skill detect whether a task is "research-like"? The entire point of being task-agnostic is that the skill doesn't know the task type.
- Line 28: "Retry failed dispatches (this is the calling agent's responsibility)" — is listed under "What this skill does NOT do." But the phrase "the calling agent's responsibility" without saying HOW the calling agent should retry is a hand-wave. A one-sentence pattern (e.g., "The calling agent should wrap `wait` in a timeout loop and re-dispatch only failed models") would turn a gap into guidance.

### 2. rules/methodology.md

**What works well:**
- The extraction pseudocode (Phase 2, mode A) is concrete and implementable — paths are ordered with clear rationale at each step
- The `run-manifest.json` schema with field semantics is thorough
- "DetEMinistic + LLM-assisted hybrid" section makes the design intent clear

**What is missing or wrong:**
- **`run-manifest.json` schema diverges from `output-schema.md`.** methodology.md:172-174 includes `phases_completed` (list), `consolidation` (object), `schema_auto_injected`, and `aliases`. output-schema.md:209-227 defines a different subset without these fields. Two canonical-schema claims for the same file. This is a data-integrity bug — which one is authoritative?
- **Phase 3 "SCORE" claims overlap with Phase 3.6.** Phase 3, step 4 (line 115) says "Score aggregation: if the schema has a numeric score field with `aggregate: "median"`, compute median + min/max across models." Then Phase 3.6 (line 266-278) says "Aggregate scoring matrix" and "Build a single table." Is scoring done in Phase 3 or Phase 3.6? If both, the duplication is misleading.
- **"Deterministic extraction" claim is overstated.** Line 192: "Structured extraction (Mode A) is deterministic — pure parsing, no LLM in the loop." But Mode A fallback path 3 (line 52-58) dispatches an extractor LLM to reformat the response — that IS an LLM in the loop, and it's been used in real runs when models return prose instead of tables.

**What is unclear or ambiguous:**
- Phase 2 says "Split by H2 headings" for free-form extraction (line 83-84). But what happens when a model's output has H2s for sections that aren't items (e.g., a model writes "## Summary" then "## Analysis")? The parser would treat "Summary" and "Analysis" as items.
- Line 104: "Extractor model — clarification: the 'extractor' is a single designated model used for fallback extraction ... Default: the slowest, highest-capability model from the original dispatch." How is "highest-capability" determined? Is this hardcoded or depends on provider metadata?

### 3. rules/dispatch-mechanics.md

**What works well:**
- The 4-mechanism ordering with clear decision table at the bottom is well-structured
- Real-world constraints documented: OpenCode `task` tool limitation (line 28-29: 6 issues + 1 PR), mechanism 3 SDK bug (issue #18615), port collision caveat

**What is missing or wrong:**
- **Mechanism 2 (the default) has no explicit timeout guidance.** The failure-modes table mentions "Shell tool's 2-min default timeout" (SKILL.md:221, line 221) as a known cause of failures, but the dispatch bash snippet (lines 40-49) does NOT set `--timeout`. A reader copy-pasting the snippet will hit that exact failure mode.
- **Mechanism 4 code example (lines 82-89) is broken for real use.** It references `ENDPOINTS`, `KEYS`, and `model.id`/`model.provider` without defining them. No error handling, no rate-limit handling, no retry logic. If this is meant to be a reference, it should include at least ONE complete provider example.
- **"Per-model output capture" section (lines 107-112) tells the agent to check CWD for strays but doesn't say HOW.** The calling agent has no file access to the model's CWD — that's a separate directory from the output dir. In practice, you're telling the human user to dig through temp directories after a failed run.

**What is unclear or ambiguous:**
- Line 102: "The proven fix is to either (a) configure MCPs that support multiplexing, or (b) dispatch to a single model at a time AND restart the MCP between dispatches." Neither option has concrete instructions. How do you "configure MCPs that support multiplexing"? What command "restarts the MCP"?

### 4. rules/consolidation-rules.md

**What works well:**
- The named rule library is the strongest part of the skill — every rule has a purpose, algorithm, input spec, and edge case. This is genuinely implementable.
- The conflict documentation template (line 227-234) is concrete with real examples

**What is missing or wrong:**
- **`most-severe` edge case contradicts code-review example.** Line 171: "if 1/N reviewers disagrees with no evidence quote, downgrade the lone max to the next-severity tier." Code-review.md:96: "Safety: don't downgrade a blocker just because one reviewer missed it." These are directly contradictory. A code reviewer who finds a blocker is EXACTLY the case described — 1/N says `blocker`, others say `major`. The edge case says downgrade; the example says don't.
- **Phase 3.5 vs 3.6 numbering is confusing.** The heading structure uses "Phase 3.5 — RESOLVE CONFLICTS" (line 136) and "Phase 3.6 — SCORE + SYNTHESIZE" (line 266), but Phase 4 — SYNTHESIZE is in methodology.md. Is Phase 3.6 the same as Phase 4? If not, what's left for Phase 4 after scoring is done?
- **`lowest-of-majors` rule returns `unverified` but comments say "change the schema to match the rule."** Line 185: "Do NOT change the rule's return value to match the schema — change the schema to match the rule." This inverts normal API design — the configuration should drive the behavior, not the other way around. If a user schema uses `partially-true` instead of `unverified`, the rule silently returns `unverified` and the consolidation breaks.
- **Alias map and skip rules share the same data structure but are different operations.** Line 115: "Mark a row's primary key as `aliases[n] = null` to drop it from the registry." This overloads the alias map with skip semantics. A reader scanning the alias map sees `{'AutoGen/AG2': 'AutoGen', 'SomePlaceholder': null}` — the null has no semantic meaning without reading the prose.

**What is unclear or ambiguous:**
- Line 79-80: "For semantic dedup (e.g., `AutoGen` ↔ `AG2`), supply an alias map at run time." The paragraph says the default (no aliases) normalization is well-defined, but doesn't say HOW the alias map is supplied — is it a CLI flag, a separate config file, embedded in the schema JSON? The research example hardcodes it in the bash script, but that's example-specific.
- Line 119-120: "Skip rules" says "Header rows that were incorrectly parsed as data (e.g., when a model emits column headers as a separate row)" — but the parser should already be handling this in Phase 2. If Phase 2 parse correctly, Phase 3 should never see header rows. This skip rule implies Phase 2 is buggy.

### 5. rules/output-schema.md

**What works well:**
- The two-mode (schema vs free-form) output structure is clearly delineated
- Markdown formatting rules (lines 231-242) are CRITICAL and well-specified — every one of those rules was learned from WYSIWYG rendering failures

**What is missing or wrong:**
- **`run-manifest.json` schema is stale** (as noted above). This file omits `phases_completed`, `consolidation`, `schema_auto_injected`, and `aliases` — all added in v2.1.0. The file that claims to be the canonical schema is out of date.
- **§ Markdown formatting rules section has no section number.** It follows §8 but isn't numbered. This makes it impossible to reference ("in the Markdown formatting rules section" vs "in §9"). It's unclear whether this is part of the output schema specification or just implementation notes.
- **§3 "Per-Item Details" examples leak research-specific fields into generic documentation.** Line 109: `gaps_vs_reference = ... ; reference_gaps_vs_them = ...` — these are research-prior-art fields, not generic. A code-review user reading §3 would be confused.

**What is unclear or ambiguous:**
- Line 70: "Conflict marker legend (place at top of section)" — but §2A comes before §4 (Conflicts & Resolutions). If conflict markers are in §2A's table, the reader hasn't seen the conflict resolution rules yet. Either move §4 before §2, or add a forward reference to §4.
- Line 130-131: `§5. Aggregated Scores (optional, both modes)` and `§8. Synthesized Verdict (optional, both modes)` — other sections like §6 (Negative Results) and §7 (Open Questions) are not marked optional. Are they always produced? What if there are no negative results — is §6 omitted or produced empty?

### 6. rules/examples/research-prior-art.md

**What works well:**
- The full prompt template, schema, scoring rubric, and alias map provide a complete worked example — someone could literally substitute their subject and run
- The alias map with 14 well-documented entries is a strong reference

**What is missing or wrong:**
- **No consolidated output snippet.** The example says "After consolidation, `consolidated.md` contains..." and then lists section headings. There's no actual markdown table excerpt, no example of what a resolved conflict looks like, no scoring matrix row. The reader has to find `docs/research-260624/SB_CONSOLIDATED_PRIOR_ART_REPORT.md` separately.
- **Line 35-68 shows the prompt template but the bash dispatch (lines 18-32) uses `cat /path/to/research-prompt.md` — these don't connect.** The template is in the markdown example, but the dispatch reads from a file. A reader might think they're the same thing.
- **Line 173: "the prompt did NOT embed the schema; the skill auto-injected it because `--no-auto-inject` was not passed"** — but the bash dispatch snippet (lines 18-32) doesn't show the schema being passed. So where does auto-injection come from? The bash example doesn't use `--schema` at all.

**What is unclear or ambiguous:**
- Line 182-183: "diminishing returns past 6 (this is an empirical observation, not a measured curve)" — this is honest, but it weakens the recommendation. Either cite the 6-model run's marginal-uniqueness numbers or don't state a number at all.

### 7. rules/examples/code-review.md

**What works well:**
- The composite-key correction (lines 70-71) is pedagogically valuable — shows the wrong way and the right way
- Custom strategies table (lines 93-100) is concrete and useful

**What is missing or wrong:**
- **No worked example exists (line 111: "Not yet produced (deferred to v2.2.0)").** The same is true for fact-check. This means the skill has exactly ONE proven example (research). For a skill that claims "task-agnostic" and lists 5+ task types (code review, fact-check, ideation, writing critique, translation verification), having only one proven task type is a credibility gap.
- **Line 107: "Pre-commit hook ... NOT currently supported as a built-in dispatch; requires custom runner"** — this is an aspirational feature that doesn't exist, included in a file labeled "Example." It's not an example; it's a wishlist item.
- **`severity_order` declaration syntax is inconsistent with the schema spec.** Line 73-78 shows `conflict_resolution.severity_order` as a top-level conflict key, but the schema spec in SKILL.md:107-113 doesn't define this field. The `severity_order` is only documented in consolidation-rules.md:172, not in the schema type system.

**What is unclear or ambiguous:**
- Line 45: "The dispatch above does NOT pass `--dangerously-skip-permissions`" but the bash snippet (lines 33-42) DOES pass the original prompt and doesn't pass any flags to `npx opencode-ai run`. The security posture described doesn't match the bash code — the bash code passes no flags at all (no `--dangerously-skip-permissions` AND no `--model` after the prompt), so its behavior depends on defaults.

### 8. rules/examples/fact-check.md

**What works well:**
- Consensus requirements table (lines 103-109) is well-specified with parameterized thresholds
- "Key customization for fact-check" (lines 73-77) explains WHY each rule choice matters

**What is missing or wrong:**
- **Same deferred-to-v2.2.0 gap as code-review (line 113).** Only the research example is proven.
- **Line 77: "`sources: "url_list"` is now formally defined in the schema spec (was a v2.1.0 gap)"** — this is a v2.1.0 changelog entry embedded in an example file. Changelog information should be in a changelog, not scattered across example files.
- **Line 109: "The '3+ models' rule in the original draft was a typo; the correct threshold is parameterized."** This is self-referential to a draft the reader can't see. Remove the reference to a deleted draft.

**What is unclear or ambiguous:**
- Line 76: "`unverified` is a valid output (don't force a true/false judgment when evidence is insufficient)" — but the schema also has `partially-true` as a valid verdict value. When does a claim get `partially-true` vs `unverified`? The distinction is not made clear.

---

## §2. Score the Skill on the 8-Dimension Rubric

| Dimension | Score | Justification |
|-----------|-------|---------------|
| **Catalog of composable units** | **2** | The skill has a machine-readable catalog: 9 named conflict-resolution rules with algorithm specs, 8 column types with validation rules, 4 dispatch mechanisms with selection criteria, and 3 consolidation modes. The schema JSON itself is the catalog format. |
| **Dynamic composition** | **1** | Configuration drives behavior (`--mode`, `--schema`, `--models`), and `run-manifest.json` provides an audit trail of what was composed. But there is no runtime replanning (mode cannot change mid-run based on partial results), and no dynamic model substitution on failure. |
| **V-loop depth** | **1** | `thorough` mode adds a verification loop (per-item source checking), providing an "end-test" pass. But there is no per-step rollup (you can't inspect intermediate extracts and decide to re-dispatch), no intent gate (no confirmation that the consolidation matches the user's intent before final output), and no V-model traceability from output back through each phase. |
| **Enforcement** | **0** | Honor system only. The skill is a document — it has no IDE hooks, no CI integration, no delivery blockers. Nothing stops a user from reading the skill and then dispatching to a single model without consolidation. The skill's value depends entirely on the user's discipline. |
| **Parent/worker split** | **2** | Explicit orchestrator/worker architecture: the consolidation engine (Phase 3-4) is the orchestrator; each per-model dispatch (Phase 1) is a worker with defined output contract. Fail-soft design preserves partial results when workers fail. Extract phase has a designated "extractor model" role. |
| **Evidence model** | **2** | Tiered sufficiency with staleness: (1) per-item source URLs `source_refs` in structured extraction; (2) `prefer-with-evidence-then-newer-then-strict` rule treats evidence-backed claims as higher authority; (3) `thorough` mode adds per-source verification with `evidence-ledger.md` and `source_verified` flags; (4) `last_verified` date tracks staleness. This is more sophisticated than many production review systems. |
| **SE + DevOps unified** | **2** | Task-agnostic design covers both. The code-review example covers SE tasks (bug, security, perf, style, design, test categories). The skill's evidence model and verification loop covers DevOps audit/review tasks. The fact-check example serves both domains (SE config drift checks, DevOps compliance verification). |
| **Team customization** | **1** | Team-specific schemas and example recipes act as "process packs" but there is no overlay/extension mechanism. A team must fork the schema JSON or write a new one from scratch — the research schema can't be "extended with a few extra columns" while inheriting the base. No composition of schemas. |
| **TOTAL** | **11/16** | |

---

## §3. Top 5 Improvements (ranked by impact × effort)

### 1. Fix `run-manifest.json` duplication — make `methodology.md` canonical, delete stale copy in `output-schema.md`

- **Issue:** `run-manifest.json` schema defined in two places with different fields; `output-schema.md` version is stale (missing v2.1.0 fields)
- **Why it matters:** Implementers following `output-schema.md` will produce `run-manifest.json` files missing `schema_auto_injected`, `aliases`, `consolidation`, `phases_completed` — breaking audit reproducibility
- **Concrete change:** In `output-schema.md:207-227`, replace the JSON block with:
  ```
  See `rules/methodology.md` § Phase 4 — `run-manifest.json` for the canonical schema.
  Required fields: `timestamp`, `task_prompt`, `task_prompt_hash`, `mode`,
  `schema_provided`, `schema_auto_injected`, `models_dispatched`,
  `models_responded`, `models_failed`, `output_dir`, `aliases`,
  `totals`, `consolidation`, `phases_completed`.
  ```
- **Effort:** Low (10-line edit in 1 file)
- **Impact:** High (data-integrity bug fix, every run affected)
- **Score:** High ROI

### 2. Resolve `most-severe` contradiction between consolidation-rules and code-review example

- **Issue:** consolidation-rules.md:171 says "downgrade the lone max to the next-severity tier" but code-review.md:96 says "don't downgrade a blocker just because one reviewer missed it"
- **Why it matters:** Code review is the most concrete use case for `most-severe` — if the rule and the example disagree, implementors will pick wrong
- **Concrete change:** In `consolidation-rules.md:171`, change:
  ```
  Edge case: if 1/N reviewers disagrees with no evidence quote, downgrade the
  lone max to the next-severity tier (avoids model hallucination of "blocker"
  with no support).
  ```
  To:
  ```
  Edge case: if 1/N reviewers disagrees with no evidence quote, check if the
  schema declares `severity_edge_case: "keep" | "downgrade"` (default: "keep"
  for safety-critical tasks like code review, "downgrade" for comparative tasks
  like research). When "keep", retain the lone max; when "downgrade", drop to
  next-severity tier. Document the decision in conflicts.md.
  ```
- **Effort:** Medium (requires updating consolidation-rules, code-review example, and schema type system)
- **Impact:** High (core conflict-resolution algorithm is wrong for its primary use case)
- **Score:** High ROI

### 3. Add timeout guidance to Mechanism 2 dispatch snippet

- **Issue:** The default dispatch bash snippet in `dispatch-mechanics.md:40-49` lacks `--timeout`, but the failure-modes table identifies 2-min timeout as a known failure cause
- **Why it matters:** Every reader who copy-pastes the snippet will hit silent timeout failures on long-running models
- **Concrete change:** In `dispatch-mechanics.md:40-49`, change lines 42-47 to:
  ```bash
    # Set timeout to task estimate (default 10 min for research; 5 min for review)
    TIMEOUT=600000  # milliseconds
    npx -y opencode-ai run \
      --model "$model" \
      --title "multi-ai-task-${slug}-$(date +%s)" \
      --dangerously-skip-permissions \
      --timeout "$TIMEOUT" \
      "$PROMPT" \
      > "$OUT/${slug}.md" 2> "$OUT/${slug}.err" &
  ```
- **Effort:** Low (edit 1 file, 5 lines)
- **Impact:** High (prevents the most common silent failure mode)
- **Score:** High ROI

### 4. Simplify phase numbering to eliminate 3.5/3.6 confusion

- **Issue:** Methodology uses Phase 2, Phase 3, Phase 3.5, Phase 3.6, Phase 4 — no reader can tell whether Phase 3.6 is distinct from Phase 4
- **Why it matters:** Implementors reading consolidation-rules.md independently won't know that "Phase 3.6 — SCORE + SYNTHESIZE" overlaps with "Phase 4 — Final synthesis" in methodology.md
- **Concrete change:** Rename phases to sequential integers:
  - Phase 1: Dispatch (per-model execution) — unchanged
  - Phase 2: Extract (per-model structured data) — unchanged
  - Phase 3: Dedup (canonical registry) — formerly first half of Phase 3
  - Phase 4: Resolve (conflict resolution) — formerly Phase 3.5
  - Phase 5: Aggregate (scoring + synthesis) — formerly Phase 3.6
  - Phase 6: Produce (write consolidated.md, html, conflicts.md, manifest) — formerly Phase 4
  Updated in methodology.md:108, consolidation-rules.md:78,136,266, and methodology.md:122
- **Effort:** Medium (affects 3 files, 6 section headings, all cross-references, and `phases_completed` in run-manifest.json)
- **Impact:** Medium (clarity improvement, doesn't fix bugs)
- **Score:** Medium ROI

### 5. Separate aliases from skip rules into distinct data structures

- **Issue:** The alias map is overloaded to also serve as a skip list (`aliases[n] = null`), mixing two semantically different operations
- **Why it matters:** A reader scanning the alias map can't distinguish "X is the same as Y" from "X doesn't count" — both use the same map. This is fragile and confusing
- **Concrete change:** In `consolidation-rules.md:79-90` and `consolidation-rules.md:113-121`, refactor:
  ```js
  // NEW: separate structures
  const aliases = {
    'AutoGen/AG2': 'AutoGen',
    // ... semantic equivalents only
  };
  const skipKeys = new Set([
    'Candidate', 'N/A', '-', 'TBD', 'Catalog of composable units',
    // ... items to ignore only
  ]);
  // Then in normalize():
  function normalize(key) {
    key = key.toLowerCase().replace(/[^\w\s-]/g, '').trim();
    if (skipKeys.has(key)) return null;  // explicit skip
    return aliases[key] || key;           // alias or identity
  }
  ```
- **Effort:** Low (edit 1 file, ~20 lines changed)
- **Impact:** Medium (prevents alias-map confusion, easier to audit)
- **Score:** Medium ROI

---

## §4. Open Questions

1. **What is the actual version?** SKILL.md frontmatter says 2.1.0; the task description says v2.0.0; the research example references a v2.1.0 gap fix (line 77 of fact-check.md: "was a v2.1.0 gap"). Was 2.1.0 a release or is the frontmatter stale? Without a changelog, it's impossible to know which version a reader should expect.
2. **What does `--no-auto-inject` interact with when `--schema` is not provided?** The description says "if passed, the skill does NOT append the schema to the dispatch prompt," but in free-form mode (no `--schema`), there is no schema to inject. Does the flag still do something (e.g., skip the `<structured></structured>` instruction), or is it silently ignored?
3. **What is the concurrency implementation?** `--concurrency parallel|sequential` is declared in the CLI but no rule file explains how sequential mode actually dispatches. Does it wait for each model to finish (with what timeout?) before starting the next? Does it reuse the same shell session? The dispatch-mechanics.md mentions sequential mode but doesn't implement it in the bash snippet.
4. **How does model discovery work when `--models` is omitted?** SKILL.md:74-75 describes a "balanced default set of 4-6 models" but provides no algorithm. Is this implemented in a script? Does it parse `opencode.json`? What happens if the config contains 20 models — which ones are picked?
5. **Is the skill intended as a procedural document or a software artifact?** The entire skill is Markdown rules — there's no executable script. Implementation is left to "the calling agent." But many rules describe algorithms in enough detail that they should be a library. Is the intent that every agent re-implements the dedup/conflict/extraction logic from prose, or is there a planned reference implementation?
6. **Why are code-review and fact-check proofs deferred to v2.2.0 when the skill claims v2.1.0 has been generalized?** The generalization claim (task-agnostic) is undermined by having only one proven use case. What's the plan for proving the other task types?
7. **What's the expected latency for a typical 6-model standard-mode run?** The skill says "latency of slowest model + consolidation" but gives no bounds. The proven run took "~2-3 min/model" (dispatch-mechanics.md:101), but what's the consolidation wall-time? Without this, users can't evaluate the "When NOT to use" criterion "Latency is critical."
8. **How does the calling agent detect completion without polling?** The bash `&` + `wait` pattern works when the calling agent IS the shell, but if the skill is invoked from an OpenCode session via `task` tool, how does the orchestrator know all sub-models are done? Is there a completion signal?

---

## §5. Confidence

- **Overall confidence:** High
- **What would change my assessment:** A worked code-review or fact-check run would either validate or invalidate the generalization claim. If the same extraction/dedup algorithms work cleanly on a second task type, the skill's architecture is proven. If they don't, the task-agnostic claim is aspirational and the skill should be scoped down to research-only until the generalization is proven.
