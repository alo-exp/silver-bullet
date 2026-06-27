## §1. Critical Assessment

### File 1: `SKILL.md`

**What works well:**
- Clear "When to use / Don't use" table with concrete decision criteria
- The `--schema` parameter documentation is thorough with two modes (A/B) and supported column types/fields tables

**What is missing or wrong:**
- **Version mismatch:** frontmatter says `version: 2.1.0` (line 6) but the prose says "at v2.0.0" nowhere — the task prompt says v2.0.0, the file says 2.1.0. Which is it?
- **`--mode thorough` cost estimate is unsubstantiated:** "~3-5 min additional wall-time (sequential) or ~1 min (parallel)" for 36 items × 1 verifier (line 83) — no citation, no measurement methodology, just a guess
- **`user-invocable: false`** (line 5) contradicts the entire usage section which shows `/multi-ai-task` as a user-facing command. If it's not user-invocable, why document the CLI syntax?

**What is unclear or ambiguous:**
- **"Default model discovery"** (line 72-73): "queries the local OpenCode config" — no algorithm is specified for how to pick 4-6 models from the config. What if only 2 models are configured? What if all are from one family?
- **`@file.md` syntax** (line 64): "Use `@file.md` to inline a multi-line prompt" — this is mentioned once and never defined. Is this a shell feature? An opencode feature? Does it actually work?

---

### File 2: `rules/methodology.md`

**What works well:**
- The 4-phase pipeline is clearly delineated with pseudocode for extraction
- The extractor-model clarification (line 104) correctly distinguishes "the model that produced the response" from "the extractor model"

**What is missing or wrong:**
- **Phase 2 pseudocode is aspirational, not implementable:** `findTable(response, schema)` (line 43) — no algorithm for matching headers "case-insensitively; allow synonyms" is specified. How does `"cat" ↔ "category"` get discovered? Is there a synonym registry?
- **Free-form extraction "first 5 words" is fragile and acknowledged as such** (line 97: "fragile; flag fuzzy_match:true") — but no alternative is offered and no guidance on when this is acceptable vs. when to abort
- **No mention of token/cost budgeting:** Phase 1 dispatches N models, Phase 2 may dispatch an extractor model (additional LLM calls), Phase 3 thorough mode dispatches verifier models. Total cost could be 2-3× the naive N×estimate. This is never surfaced.

**What is unclear or ambiguous:**
- **"Idempotent re-runs"** (line 172): "It does NOT cache across runs by default" — but `task_prompt_hash` exists in `run-manifest.json`. Is caching planned? Is the hash used for anything today?

---

### File 3: `rules/dispatch-mechanics.md`

**What works well:**
- The 4 mechanisms are ranked by preference with concrete code examples for each
- The macOS `gtimeout` vs Linux `timeout` distinction (lines 44-48) is a real gotcha correctly documented

**What is missing or wrong:**
- **Mechanism 1 config example is wrong for the actual harness:** The example shows `"agent": { "ocg-minimax-m3": { "mode": "subagent", ... } }` (line 17) but the actual opencode config uses `"agents"` (plural) not `"agent"`. This will silently fail.
- **Mechanism 3 code is pseudocode dressed as real code:** `client.session.promptAsync()` (line 78) — no import, no SDK version, no indication of whether this API actually exists. The "Known bug" caveat (line 86) undermines the entire section.
- **`--dangerously-skip-permissions` guidance is contradictory:** Line 56 says "fine for read-only tasks" but the skill is "task-agnostic" — how does the skill know if the task is read-only? It doesn't. The user must decide, but the guidance assumes the skill can tell.

**What is unclear or ambiguous:**
- **"MCP port collision"** (line 113): mentioned as a risk but no concrete example of which MCPs collide, what port, or how to detect it

---

### File 4: `rules/consolidation-rules.md`

**What works well:**
- The named rule library (`most-severe`, `majority-with-uncertain`, `lowest-of-majors`, etc.) is formally defined with algorithms, edge cases, and implementation notes — this is the strongest part of the skill
- The `allow_downgrade` flag for `most-severe` (line 171) is a well-thought-out safety valve

**What is missing or wrong:**
- **`prefer-with-evidence-then-newer-then-strict` is underspecified:** Step 2 says "Check the source date for the candidate's evidence" (line 159) — but the schema doesn't require a `last_verified` field, and free-form mode has no date field at all. How does this step work when the date is absent?
- **Fuzzy match threshold "≥80% similar" is arbitrary** (line 131): no justification for 80% vs 70% or 90%. No guidance on what similarity metric (Levenshtein on characters? tokens? Jaccard?) — "Levenshtein or token-overlap" is two different algorithms with different results.
- **`concatenate-all` separator is ` ; `** (line 202) — this is a weird choice. Standard separators are `, ` or `\n`. The semicolon-space is ambiguous with prose that contains semicolons.

**What is unclear or ambiguous:**
- **`merge-exact` for composite keys** (line 218-221): "for fields that conflict across models, apply the schema's per-field resolution rule" — but what if the schema doesn't define a rule for that field? Does it fall back to the default rules table, or does it error?

---

### File 5: `rules/output-schema.md`

**What works well:**
- The `run-manifest.json` schema is the single canonical definition with clear field semantics
- WYSIWYG-safe markdown formatting rules (lines 258-269) are practical and specific

**What is missing or wrong:**
- **`task_prompt_hash` is defined but never used:** "useful for cache lookup and reproducibility audit" (line 242) — but no cache lookup is implemented anywhere. This is dead schema.
- **`models_failed` field type is inconsistent:** line 249 says `list of {model, stderr_excerpt, exit_code}` but the example JSON (line 222) shows `"models_failed": []` (empty array). The object shape is never shown in an example.
- **`phases_completed` is a list of integers** (line 235) — but phases are 1-4. What does `[1, 2, 4]` mean? Phase 3 failed but 4 ran? That's a partial-failure state that's never documented.

**What is unclear or ambiguous:**
- **§2A vs §2B naming:** "Mode A — schema-defined table" vs "Mode B — generic narrative" — but the file header says "both modes" for §1, §3-§8. The mode split only applies to §2. This is confusing — a reader might think the entire output structure changes.

---

### File 6: `rules/examples/research-prior-art.md`

**What works well:**
- The alias map (14 entries, lines 125-141) is concrete and immediately reusable
- The dispatch bash script is copy-pasteable and matches the proven run

**What is missing or wrong:**
- **The schema example has no `primary_key` field in the columns** — wait, it does: `"primary_key": "name"` at line 75. But `SKILL.md:142` says composite keys use `dedup_key: true` on multiple columns, and the research schema uses `"primary_key": "name"` as a top-level field. These are two different ways to express the same thing, and they're inconsistent.
- **"8-10 models captures more unique finds but diminishing returns past 6"** (line 182) — this is presented as empirical but the disclaimer says "this is an empirical observation, not a measured curve." It's an anecdote, not data.
- **The research prompt template (lines 37-68) is a skeleton with placeholders** like `[subject description]` — not a real prompt. A reader can't actually run this without significant additional work.

**What is unclear or ambiguous:**
- **"Schema + scoring rubric: passed via `--schema` as a JSON file"** (line 173) — but the scoring rubric is a separate JSON object from the schema. How are both passed? Two `--schema` flags? A combined file? This is not specified.

---

### File 7: `rules/examples/code-review.md`

**What works well:**
- The composite key correction (lines 68-70) explicitly calls out the wrong pattern (`"primary_key": "file:line"`) and shows the right one
- Security note about `--dangerously-skip-permissions` for read-only vs write tasks is well-placed

**What is missing or wrong:**
- **No worked example exists:** "Not yet produced (deferred to v2.2.0)" (line 110) — this is a recipe with no test. The entire code-review flow is unverified.
- **The prompt template hardcodes `/path/to/code.py`** (line 21) — not a real path. A reader must substitute, but there's no guidance on how to reference a file in the prompt (inline? `@file`? absolute path?).
- **Only 2 models in the dispatch example** (line 33) — the skill says "minimum viable: 2 models from different families" but both `minimax-m3` and `qwen3.7-max` are from the same OCG family. This violates the skill's own diversity guidance.

**What is unclear or ambiguous:**
- **"Per-Reviewer Statistics" (§5 in output, line 88)** — not defined in the output-schema.md. Is this a code-review-specific section? Where does it go in the §-numbering?

---

### File 8: `rules/examples/fact-check.md`

**What works well:**
- The consensus requirements table (lines 103-108) with parameterized thresholds is mathematically precise
- The `majority-with-uncertain` + `lowest-of-majors` pairing is well-justified for high-stakes verification

**What is missing or wrong:**
- **No worked example exists:** "Not yet produced (deferred to v2.2.0)" (line 112) — same problem as code-review. Unverified recipe.
- **The prompt template uses `[claim 1]`, `[claim 2]` placeholders** (lines 31-34) — not real claims. Can't be run as-is.
- **`sources: "url_list"` is noted as "now formally defined"** (line 77) — but the `url_list` type definition in `SKILL.md:124` just says "Comma-separated URLs (normalized + deduped on dedup)". What does "normalized" mean? Trailing slash? Protocol? Case?

**What is unclear or ambiguous:**
- **"Use 4-5 for fact-check"** (line 37) but the dispatch example only uses 3 models (line 38). Which is it?

---

## §2. Score the Skill on the 8-Dimension Rubric

| Dimension | Score | Justification |
|---|---|---|
| Catalog of composable units | **1** | The named rule library (`most-severe`, `majority`, etc.) is an informal catalog — rules are defined with algorithms but not machine-discoverable (no JSON schema for the rule registry itself). |
| Dynamic composition | **0** | No replanner, no catalog-backed composition. The 4 phases are fixed. The `--mode` flag selects a preset, not a dynamic plan. |
| V-loop depth | **1** | `thorough` mode adds per-item verification (a form of per-step rollup), but there's no intent gate — verification always runs if `thorough` is selected. No feedback loop from Phase 3 back to Phase 1. |
| Enforcement | **1** | The skill documents rules and expects the calling agent to follow them. No CI gate, no IDE hook, no delivery blocker. The `run-manifest.json` is an audit trail but nothing checks it. |
| Parent/worker split | **2** | Explicit orchestrator (the skill) dispatches to N worker models. The parent/worker boundary is clear: the skill owns consolidation, workers own execution. |
| Evidence model | **1** | `thorough` mode has `evidence-ledger.md` with per-claim source verification, but it's opt-in and the evidence tiers are informal (`high|medium|low` self-reported by models, not independently scored). |
| SE + DevOps unified | **1** | Covers research, code-review, and fact-check (3 task types) with recipes, but the recipes are untested (2 of 3 have no worked example). The skill is task-agnostic in theory but research-biased in practice. |
| Team customization | **0** | No overlay packs, no process-pack mechanism. Customization requires forking the schema or writing a new recipe file. |

**Total: 7/16**

---

## §3. Top 5 Improvements (ranked by impact × effort)

### 1. Fix the `user-invocable: false` contradiction

- **Issue:** Frontmatter says `user-invocable: false` but the entire skill is documented as a user-facing `/multi-ai-task` command.
- **Why it matters:** If a host reads `user-invocable: false` and hides the skill from the picker, users can't invoke it. If it's meant to be agent-invoked only, the CLI syntax documentation is misleading.
- **Concrete change:** `SKILL.md:5` — change to `user-invocable: true` if it's user-facing, OR remove the `/multi-ai-task` CLI syntax section and document it as an agent-internal protocol.
- **Effort:** low
- **Impact:** high
- **Score:** high

### 2. Produce a worked code-review example

- **Issue:** `rules/examples/code-review.md:110` says "Not yet produced (deferred to v2.2.0)." The code-review recipe is untested.
- **Why it matters:** 2 of 3 example recipes have never been run. The skill claims task-agnosticism but has only validated one task type (research). Untested recipes may have schema bugs, wrong conflict rules, or broken dispatch scripts.
- **Concrete change:** Run the code-review recipe end-to-end on a real PR, save outputs to `docs/`, and update `code-review.md` with the actual results. Same for fact-check.
- **Effort:** medium
- **Impact:** high
- **Score:** high

### 3. Specify the fuzzy-match algorithm concretely

- **Issue:** `consolidation-rules.md:131` says "≥80% similar (Levenshtein or token-overlap)" — two different algorithms, arbitrary threshold.
- **Why it matters:** Different algorithms produce different dedup results. A run using Levenshtein may merge items that token-overlap wouldn't, making results non-reproducible across implementations.
- **Concrete change:** `consolidation-rules.md:131` — pick one algorithm (recommend token-overlap/Jaccard for item titles, since titles are short and token-level overlap is more intuitive than character-edit distance). Specify: `Jaccard similarity on lowercased token sets, threshold 0.75. Tag all fuzzy merges with \`fuzzy_match: true\` and the similarity score.`
- **Effort:** low
- **Impact:** medium
- **Score:** medium

### 4. Add a cost/token budget estimate to the dispatch

- **Issue:** Nowhere in the skill is the total cost of a run estimated. N models × prompt tokens + N × response tokens + extractor calls + verifier calls (thorough) = potentially 3-4× the naive cost.
- **Why it matters:** Users dispatching 6 models for a research task may burn $5-15 without knowing. The skill should surface expected cost before dispatch.
- **Concrete change:** Add a `## Cost estimate` section to `SKILL.md` after "Mode semantics" with a formula: `Total ≈ N × (prompt_tokens + avg_response_tokens) × price_per_token + (extractor_calls + verifier_calls) × price`. Include a table of typical costs per mode.
- **Effort:** low
- **Impact:** medium
- **Score:** medium

### 5. Resolve the `primary_key` schema inconsistency

- **Issue:** `SKILL.md:96` shows `"primary_key": "item"` as a top-level schema field. `code-review.md:70` says "The string-form `primary_key` is not a recognized schema field." These contradict each other.
- **Why it matters:** Users will be confused about whether to use `"primary_key": "name"` (top-level) or `dedup_key: true` (per-column). The research example uses the top-level form; the code-review example says it's wrong.
- **Concrete change:** Decide: either (a) `"primary_key"` is a shorthand for single-column dedup and `dedup_key: true` is for composite keys (document both), or (b) remove `"primary_key"` from the schema spec and require `dedup_key: true` everywhere. Update `SKILL.md:96` and `research-prior-art.md:75` to match.
- **Effort:** low
- **Impact:** medium
- **Score:** medium

---

## §4. Open Questions

1. **Who is the audience?** The skill reads like it's written for an AI agent (the orchestrator), but the CLI syntax and `--schema` parameter suggest a human user. Is this a skill the agent loads and follows, or a CLI tool a human runs? Both? The `user-invocable: false` vs CLI docs contradiction reflects this unresolved question.

2. **What harness is this tested on?** The dispatch mechanics section documents 4 mechanisms but only Mechanism 2 has a proven run. Is Mechanism 1 (task tool with subagent types) actually tested, or is it aspirational? The "Known bug" caveat on Mechanism 3 suggests it's not.

3. **What happens when consolidation produces wrong results?** There's no human-in-the-loop checkpoint, no review gate, no way to flag "this consolidation looks wrong, re-run with different rules." The skill is fully automated with no feedback mechanism.

4. **Is the scoring rubric (8 dimensions, 0-2 each) part of this skill or the research task?** The rubric appears in `research-prior-art.md` as a research-specific scoring matrix, but the task prompt asks me to apply it to the skill itself. Is the rubric a built-in feature of the skill, or just one example of a user-provided schema?

5. **What's the upgrade path from v2.0 to v2.1?** The version in the frontmatter is 2.1.0 but the task says 2.0.0. What changed? Is there a changelog? The `schema_auto_injected` field is marked "v2.1.0+" — were there breaking changes?

---

## §5. Confidence

- **Overall confidence:** medium
- **What would change your assessment:** Running the code-review and fact-check recipes end-to-end would reveal whether the schemas, conflict rules, and dispatch scripts actually work as documented. If they do, the skill is stronger than this review suggests; if they don't, the gaps are worse than flagged.
