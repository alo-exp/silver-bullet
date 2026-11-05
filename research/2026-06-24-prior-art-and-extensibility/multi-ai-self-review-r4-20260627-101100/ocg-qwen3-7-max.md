I'll read all 8 files in parallel first.
# Critical Self-Review: multi-ai-task Skill (v2.1.0)

---

## §1. Critical Assessment

### File 1: `SKILL.md` (255 lines)

**What works well:**
- The "When to use / Don't use" table is crisp and decision-useful — users can self-select in 10 seconds.
- The `--schema` parameter section (lines 85–155) is the best-documented part of the skill: column types, fields, composite keys, and auto-injection are all concrete.

**What is missing or wrong:**
- **Contradiction: `user-invocable: false` (line 5) vs. `/multi-ai-task` usage syntax (line 57).** If the skill is not user-invocable, the `/multi-ai-task` command syntax is misleading. Either the frontmatter is wrong or the usage section is aspirational. A user reading line 57 will try `/multi-ai-task` and fail.
- **Retry policy is orphaned.** Line 29 says "Retry failed dispatches (this is the calling agent's responsibility; the skill is fail-soft)" and line 229 repeats "the skill does **not** retry failed dispatches." But the skill IS the calling agent in Mechanism 2 (the default). Who retries? The doc punts to a "runner" that doesn't exist in the skill.
- **Default model discovery is underspecified.** Line 73 says "queries the local OpenCode config (`~/.config/opencode/opencode.json` + `.jsonc`) and picks a balanced default set of 4-6 models" — but what if the config has 0 models? 1 model? 20 models? There's no fallback behavior documented.

**What is unclear or ambiguous:**
- **`--no-auto-inject` naming is inverted.** The default is auto-inject ON. The flag disables it. Users reading the flag name without the description will assume it enables injection. Consider `--manual-schema-inject` or `--schema-passthrough`.
- **Line 227 references `score-aggregate.md` as "planned" but "not in the contract."** This is a dangling future-feature reference that adds noise. Remove it or implement it.

---

### File 2: `rules/methodology.md` (173 lines)

**What works well:**
- The 4-phase structure is clean and the pseudocode for extraction (lines 38–64, 79–99) is implementable.
- The "Cross-cutting principles" section (lines 151–173) correctly identifies the deterministic-vs-LLM-hybrid split.

**What is missing or wrong:**
- **Extractor model failure is unhandled.** Line 53 says the extractor is "the slowest, highest-capability model from the dispatch" and explicitly says "NOT the model that produced the response." But what if the extractor model itself failed dispatch (is in `models_failed`)? The doc doesn't address this. If the extractor is unavailable, the fallback chain (step 4: paragraph split) is lossy and undocumented.
- **Phase 3 confidence is undefined.** Line 116: "Confidence: number of models that found the item, plus per-field agreement." This is not an algorithm — it's a vibe. How do you combine a count (integer) with agreement (ratio) into a single confidence value? The doc needs a formula or it should say "confidence is not computed in standard mode."
- **Free-form extraction's "first 5 words" primary key (line 97) is acknowledged as fragile but has no fallback.** The doc says "flag `fuzzy_match: true`" but doesn't say what happens when fuzzy match fails to find a match. Does the item become a singleton? Is it dropped?

**What is unclear or ambiguous:**
- **Phase numbering inconsistency.** The methodology calls them "Phase 1–4" but `consolidation-rules.md` uses "Phase 2 — ALIGN", "Phase 3 — DEDUP", "Phase 3.5 — RESOLVE CONFLICTS", "Phase 3.6 — SCORE + SYNTHESIZE". Are 3.5 and 3.6 sub-phases of Phase 3 or separate phases? The `run-manifest.json → phases_completed` field uses `[1, 2, 3, 4]` — so 3.5 and 3.6 must be sub-phases, but this is never stated.
- **"Idempotent re-runs" (line 172) says "each run is fresh" but then mentions "incremental consolidation (future enhancement)."** Is this supported or not? The parenthetical undermines the claim.

---

### File 3: `rules/dispatch-mechanics.md` (181 lines)

**What works well:**
- The 4-mechanism ranking with real-world provenance (Mechanism 2 worked on 2026-06-27) is honest and practical.
- The "Choosing the right mechanism" decision table (lines 173–181) is immediately actionable.

**What is missing or wrong:**
- **The parallel wall-time formula is mathematically wrong.** Line 104: "choose parallel if `N × per_model_time ≤ your latency budget`." For parallel dispatch, wall-time = `max(per_model_time)`, not `N × per_model_time`. The formula as written would steer users toward sequential when parallel would fit. The correct formula: "choose parallel if `max(per_model_time) ≤ your latency budget`."
- **The primary Mechanism 2 example (lines 37–53) uses bare `wait` with no timeout.** If any model hangs, the entire dispatch blocks indefinitely. The doc mentions `timeout`/`gtimeout` on line 62 but doesn't include it in the primary example. Users will copy-paste the example and get stuck.
- **Mechanism 3 documents a known bug (issue #18615, line 79) but still lists it as a viable mechanism.** It should be marked `[EXPERIMENTAL/BROKEN]` in the heading or removed from the "in order of preference" ranking.

**What is unclear or ambiguous:**
- **Mechanism 1 failure mode is undocumented.** Line 28 explains that the `task` tool resolves the model at config time, not call time. But what happens if a user passes `subagent_type="ocg-minimax-m3"` without pre-defining it? Does the tool error, silently fall back to the parent model, or hang? The doc says "Unknown agent type" is a possible error but doesn't say this is the ONLY failure mode.
- **MCP port collision (line 106) says "Sequential alone doesn't fix port collision if the MCP binds a port on first start and holds it."** But the fix ("restart the MCP between dispatches") is not automated and not part of any dispatch script. This is a known gap with no workaround in the skill.

---

### File 4: `rules/consolidation-rules.md` (334 lines)

**What works well:**
- The named-rule library (10 rules, lines 163–221) is the core value of the skill. Each rule has purpose, input, algorithm, and edge cases — this is genuinely implementable.
- The `most-severe` rule's `allow_downgrade` feature (line 171) is well-reasoned with a clear default and safety rationale.

**What is missing or wrong:**
- **`allow_downgrade` has no schema syntax.** Line 171 says "the schema may declare `allow_downgrade: true`" but never shows WHERE in the schema this goes. Is it `"conflict_resolution": {"severity": "most-severe", "allow_downgrade": true}`? Or `"severity": {"rule": "most-severe", "allow_downgrade": true}`? The schema format is undefined.
- **`prefer-with-evidence-then-newer-then-strict` assumes research-specific fields.** Step 2 (line 159) says "Check the source date for the candidate's evidence. Recency > staleness." But the generic schema has no `last_verified` field — that's research-specific (it appears in `research-prior-art.md` line 92). For a code-review or ideation task, this rule's step 2 is inapplicable. The rule should degrade gracefully when `last_verified` is absent.
- **`majority-with-uncertain` return value is rigid.** Line 185: "Do NOT change the rule's return value to match the schema — change the schema to match the rule." This is backwards from user expectations. Users define their schema's `values` array and expect the conflict rule to produce one of those values. Forcing users to include `unverified` in their enum (even when it doesn't match their domain vocabulary) is a usability gap.

**What is unclear or ambiguous:**
- **The dedup algorithm (lines 96–111) calls `normalize(row.primary_key)` but the normalize function is defined 230 lines later (lines 327–333).** The algorithm pseudocode should either inline the normalize logic or forward-reference it explicitly.
- **Phase 3.5 and 3.6 numbering.** These are clearly sub-phases of Phase 3, but the doc presents them as top-level headings alongside "Phase 2" and "Phase 3". The hierarchy is flat when it should be nested.

---

### File 5: `rules/output-schema.md` (270 lines)

**What works well:**
- The `run-manifest.json` schema (lines 209–254) is the most complete part of the skill — field semantics, required vs optional, and defaults are all defined.
- The WYSIWYG formatting rules (lines 258–269) are practical and born from real pain.

**What is missing or wrong:**
- **`models_failed` object shape is never shown.** Line 249 says it's a "list of `{model, stderr_excerpt, exit_code}` per failure" but the example (line 222) shows `"models_failed": []`. A concrete example with one failure object would prevent implementer guesswork.
- **`task_prompt_hash` encoding is unspecified.** Line 242 says "`sha256:` of the prompt bytes" but doesn't specify hex vs base64 encoding, or whether the hash includes a trailing newline. For reproducibility audit, this matters.
- **§2A and §2B are both titled "Items Table" but produce fundamentally different output.** The mode-selection logic is clear (schema → §2A, no schema → §2B) but the identical section titles make cross-referencing confusing. Rename to "§2A. Structured Items Table" and "§2B. Narrative Items."

**What is unclear or ambiguous:**
- **§8 "Synthesized Verdict" is marked optional but the criteria for inclusion are vague.** Line 162: "If the user asked for a specific output (e.g., 'rank these candidates', 'find the bug', 'decide between X and Y')." How does the orchestrator detect this from the prompt? Is it a keyword match? An LLM classification step? The doc doesn't say.
- **The `consolidated.html` generation (referenced in SKILL.md line 174) is not defined in output-schema.md.** The SKILL.md says "convert `consolidated.md` to HTML using a markdown library" but the output-schema — which should be the canonical output spec — doesn't mention HTML at all.

---

### File 6: `rules/examples/research-prior-art.md` (185 lines)

**What works well:**
- This is the only proven worked example (6 models, 2026-06-27, real file paths). It's the skill's strongest credibility anchor.
- The 14-entry alias map (lines 125–141) is concrete and reusable.

**What is missing or wrong:**
- **The dispatch script (line 16) uses `cd "$OUT"` which creates the "stray file" problem the skill warns about elsewhere.** The model's CWD becomes the output dir, so any file the model writes goes there — but `dispatch-mechanics.md` line 116 warns "Always check the model's CWD for stray `*.md` files." The example creates the exact problem the docs warn about.
- **The scoring rubric (lines 104–118) has an implicit scoring convention.** The `levels` array has 3 entries (indices 0, 1, 2) and the score is the index. So `levels[0]` = score 0, `levels[2]` = score 2. This is never stated explicitly. An implementer might assume `levels[0]` = score 1 (1-indexed) and get max_total = 24 instead of 16.
- **"Variations to try" (line 182) makes an empirical claim with no data:** "8-10 models captures more unique finds but diminishing returns past 6." This is anecdotal. Either cite the data or remove the claim.

**What is unclear or ambiguous:**
- **The alias map is presented as a living document ("Add new aliases to this map as they surface," line 142) but it lives in an example file.** If the example is a "reference recipe" (per SKILL.md line 211), it should be frozen at the proven run's state. Living aliases belong in a separate file or in the run's `run-manifest.json`.

---

### File 7: `rules/examples/code-review.md` (111 lines)

**What works well:**
- The composite primary key example (`file` + `line` both with `dedup_key: true`, line 53–54) is the clearest expression of this feature in the entire skill.
- The security note (line 45) correctly distinguishes read-only review from write-enabled fix-and-review.

**What is missing or wrong:**
- **No worked example.** Line 110: "Not yet produced (deferred to v2.2.0)." This is a recipe that has never been executed. Every schema, prompt, and conflict rule is speculative. The skill's provenance section (SKILL.md lines 233–247) only cites the research run.
- **Output sections §5–§7 (lines 88–90) are not defined in `output-schema.md`.** "Per-Reviewer Statistics," "Coverage Gaps," and "Open Questions" are code-review-specific sections that don't exist in the generic output schema. Either the generic schema needs extension points or the example needs to acknowledge these are ad-hoc additions.
- **The prompt template (line 21) uses a hardcoded path `/path/to/code.py` with no parameterization guidance.** How does the user substitute the actual file path? Shell variable? Template engine? The doc doesn't say.

**What is unclear or ambiguous:**
- **Line 70 argues against a "old" `primary_key: "file:line"` syntax that doesn't appear anywhere in the current skill.** The doc is refuting a ghost — possibly from v1.0.0 or a draft. Without context, this paragraph confuses more than it clarifies.

---

### File 8: `rules/examples/fact-check.md` (113 lines)

**What works well:**
- The consensus requirements section (lines 101–109) with parameterized thresholds (`max(2, ceil(N/2))`) is mathematically precise and well-explained.
- The `lowest-of-majors` confidence rule (line 75) — "when in doubt, downconfidence" — is a sound epistemic principle.

**What is missing or wrong:**
- **No worked example.** Line 112: "Not yet produced (deferred to v2.2.0)." Same issue as code-review — speculative recipe.
- **N=2 edge case is unhandled.** The threshold formula `max(2, ceil(N/2))` for N=2 gives `max(2, 1) = 2`, meaning BOTH models must agree. But the doc says "use 4-5 for fact-check" (line 37) and doesn't mention that N=2 requires unanimity. A user dispatching 2 models will get `unverified` for any disagreement, which may be surprising.
- **Line 77 contains a changelog note:** "`sources: url_list` is now formally defined in the schema spec (was a v2.1.0 gap)." This belongs in a CHANGELOG, not a recipe. It's noise for a first-time reader.

**What is unclear or ambiguous:**
- **The prompt template (lines 20–35) uses `[claim 1]`, `[claim 2]` as placeholders but doesn't explain how to populate them.** Is the user expected to hand-edit the prompt? Pipe from a CSV? The doc assumes manual editing but doesn't state it.

---

## §2. Score the Skill on the 8-Dimension Rubric

| Dimension | Score | Justification |
|---|---|---|
| **Catalog of composable units** | 1 | The 10 named conflict-resolution rules and 8 column types are documented in prose/pseudocode but there is no machine-readable registry (JSON schema, enum file). An implementer must read 334 lines of `consolidation-rules.md` to discover available rules. |
| **Dynamic composition** | 1 | `--mode` (quick/standard/thorough) and `--schema` allow per-run composition changes, but there is no replanner that adapts mid-run and no audit log of composition decisions beyond `run-manifest.json`. |
| **V-loop depth** | 1 | The 4-phase pipeline produces per-phase output files, but there is no per-step rollup, no intent gate, and no mid-pipeline verification. Once dispatched, the pipeline runs to completion or failure. `thorough` mode adds post-hoc verification but not in-loop. |
| **Enforcement** | 0 | The skill documents what should happen (fail-soft, conflict resolution, schema validation) but enforces nothing. There is no CI gate, no IDE hook, no delivery blocker. A model that ignores the schema produces output that the skill tries to parse but cannot reject. |
| **Parent/worker split** | 2 | Explicit orchestrator/worker separation is the skill's core design. The parent dispatches, captures, and consolidates; the N models are stateless workers. 4 dispatch mechanisms document the separation thoroughly. |
| **Evidence model** | 1 | `standard` mode has informal `source_refs` in `structured.jsonl`. `thorough` mode adds `evidence-ledger.md` with per-claim verification. But there is no tiered sufficiency model — evidence is either present or absent, not graded by tier. |
| **SE + DevOps unified** (adapted: covers multiple task types) | 2 | The skill is genuinely task-agnostic. Research, code review, fact-check, ideation, writing critique, and translation verification are all covered by the same 4-phase pipeline with different schemas and conflict rules. |
| **Team customization** (adapted: supports process packs) | 1 | Customization requires writing a `--schema` JSON file and an alias map per task type. There is no overlay, preset, or process-pack mechanism. Teams must fork or copy the example recipes. |

**Total: 9/16**

---

## §3. Top 5 Improvements (ranked by impact × effort)

### 1. Fix the parallel wall-time formula

- **Issue:** `dispatch-mechanics.md:104` says "choose parallel if `N × per_model_time ≤ your latency budget`" — this is wrong for parallel dispatch.
- **Why it matters:** Users will incorrectly choose sequential when parallel fits their budget, adding N× latency for no reason.
- **Concrete change:** `rules/dispatch-mechanics.md:104` — replace with: "choose parallel if `max(per_model_time) ≤ your latency budget AND you have no shared-MCP port conflicts`."
- **Effort:** low
- **Impact:** high
- **Score:** high ROI

### 2. Add timeout to the primary Mechanism 2 dispatch example

- **Issue:** `dispatch-mechanics.md:37-53` uses bare `wait` with no per-model timeout. A hung model blocks the entire dispatch indefinitely.
- **Why it matters:** Production reliability — the primary example is the one users copy-paste.
- **Concrete change:** `rules/dispatch-mechanics.md:43-51` — wrap each `npx` call with `timeout $TIMEOUT`:
  ```bash
  timeout $TIMEOUT npx -y opencode-ai run \
    --model "$model" \
    --title "multi-ai-task-${slug}-$(date +%s)" \
    --dangerously-skip-permissions \
    "$PROMPT" \
    > "$OUT/${slug}.md" 2> "$OUT/${slug}.err" &
  ```
- **Effort:** low
- **Impact:** high
- **Score:** high ROI

### 3. Fix the `user-invocable: false` contradiction

- **Issue:** `SKILL.md:5` says `user-invocable: false` but `SKILL.md:57` shows `/multi-ai-task` usage syntax.
- **Why it matters:** Users will try `/multi-ai-task` and fail, or not try it because the frontmatter says it's not invocable.
- **Concrete change:** Either (a) set `user-invocable: true` if the skill is meant to be invoked via `/multi-ai-task`, or (b) remove the `/multi-ai-task` usage syntax and replace with "This skill is invoked by the orchestrator agent, not directly by the user. The orchestrator reads this skill's rules and implements the dispatch."
- **Effort:** low
- **Impact:** medium
- **Score:** medium-high ROI

### 4. Create a machine-readable conflict-rule catalog

- **Issue:** The 10 named conflict-resolution rules are documented only in prose (`consolidation-rules.md:163-221`). There is no JSON registry, enum file, or schema-validation hook.
- **Why it matters:** Implementers must grep prose to discover rules. Schema validation cannot check if a user's `"conflict_resolution": {"severity": "most-severe"}` references a valid rule name. IDE autocomplete is impossible.
- **Concrete change:** Create `rules/conflict-rule-catalog.json`:
  ```json
  {
    "rules": [
      {"name": "most-severe", "input": "enum", "output": "enum", "default_for": ["severity"]},
      {"name": "majority", "input": "any", "output": "any", "default_for": ["category", "boolean"]},
      {"name": "majority-with-uncertain", "input": "enum", "output": "enum+unverified", "default_for": ["verdict"]},
      ...
    ]
  }
  ```
  Reference this catalog from `consolidation-rules.md` and `output-schema.md`.
- **Effort:** medium
- **Impact:** high
- **Score:** medium-high ROI

### 5. Define `models_failed` object shape with a concrete example

- **Issue:** `output-schema.md:249` says `models_failed` is a "list of `{model, stderr_excerpt, exit_code}`" but the example (line 222) shows only `"models_failed": []`.
- **Why it matters:** Implementers guess at field names, types, and whether `stderr_excerpt` is truncated.
- **Concrete change:** `rules/output-schema.md:222` — add a non-empty example:
  ```json
  "models_failed": [
    {
      "model": "opencode-go/kimi-k2.6",
      "stderr_excerpt": "Error: model rate-limited (429). Retry after 30s.",
      "exit_code": 1
    }
  ]
  ```
- **Effort:** low
- **Impact:** medium
- **Score:** medium ROI

---

## §4. Open Questions

1. **Who is the audience?** The skill oscillates between "the orchestrator agent reads this and implements the pipeline" (SKILL.md line 5: `user-invocable: false`) and "the user runs this bash script" (every example). Is the skill a set of instructions for an LLM orchestrator, or a CLI tool with bash scripts? If both, the boundary needs to be explicit.

2. **What is the version contract?** The frontmatter says v2.1.0 but the task description says v2.0.0. The code-review and fact-check examples reference "v2.2.0" for worked examples. Is the skill at a stable version, or is it in active development with forward-references to unreleased features?

3. **Is the skill meant to be implemented as code, or followed as prose?** The pseudocode in `methodology.md` and `consolidation-rules.md` is detailed enough to implement, but there is no actual implementation in the skill directory. Is the expectation that every orchestrator re-implements the pipeline from prose? If so, the pseudocode needs to be more rigorous (e.g., TypeScript types, not `// comment` pseudocode).

4. **What happens when consolidation fails?** The skill documents model-dispatch failures (fail-soft, skip the model) but not consolidation failures. What if the dedup algorithm produces 0 items? What if all items are singletons (no cross-model overlap)? What if the conflict resolver produces `null` for every field? The skill has no "consolidation failed, here's what to do" path.

5. **Is `thorough` mode actually implementable?** The doc says "for each canonical item, dispatch a verifier model to check the claimed source actually supports the claim" (SKILL.md line 81). This requires the verifier model to fetch the source URL, read the content, and judge whether it supports the claim. This is a non-trivial sub-task that the skill documents as a one-liner. Has `thorough` mode ever been run end-to-end?

---

## §5. Confidence

- **Overall confidence:** medium
- **What would change your assessment:** (1) A worked example for code-review or fact-check (currently both are "deferred to v2.2.0") would validate that the generic pipeline actually works beyond research. (2) Clarification on whether the skill is instructions-for-LLM or CLI-tool-with-scripts would resolve the audience ambiguity that pervades every file.
