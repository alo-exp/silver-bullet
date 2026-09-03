# Critical Self-Review: multi-ai-task Skill v2.1.0

---

## §1. Critical Assessment

### 1. `SKILL.md` (entry point)

**What works well:**
- Clear "when to use / when not to use" table with specific criteria (cost, latency, text-only).
- The `--schema` auto-injection mechanism is well-explained with an explicit opt-out flag.

**What is missing or wrong:**
- **Version drift:** The frontmatter says `version: 2.1.0` but the provenance section references "v2.0.0" behavior and the task prompt says "v2.0.0". Which is it? If this is 2.1.0, what changed from 2.0.0? There is no changelog.
- **`--concurrency` is documented in the inputs table but not in the mode semantics or methodology.** The methodology.md describes parallel vs sequential dispatch but never mentions the `--concurrency` flag. The mapping from CLI flag to behavior is undocumented — does `--concurrency sequential` change Phase 1 only, or all phases?
- **The "When NOT to use" row "Tool execution varies per model" is vague.** What does "consolidation assumes same prompt → comparable outputs" mean concretely? If one model uses `webfetch` and another doesn't, the outputs are still "comparable" — they're just different. This needs a sharper criterion.

**What is unclear or ambiguous:**
- **Who is the audience?** The skill is `user-invocable: false`, meaning only agents invoke it. But the usage section shows a `/multi-ai-task` slash command syntax. Is this for a human typing in a chat, or for an agent calling a tool? The `@file.md` inline syntax suggests human, but `user-invocable: false` says otherwise.
- **"Auto-discover" models:** The default model discovery says it "queries the local OpenCode config." Is this implemented, or aspirational? There's no pseudocode or algorithm for the discovery logic anywhere in the skill files.

---

### 2. `rules/methodology.md` (4-phase pipeline)

**What works well:**
- The 4 phases are clearly delineated with concrete pseudocode for extraction.
- The "fail-soft, no retry" design decision is well-justified (avoids infinite loops in shell wrappers).

**What is missing or wrong:**
- **Phase 2 extraction pseudocode references `dispatchExtractorModel()` but never defines it.** Line 58: `const extractorOutput = dispatchExtractorModel(response, schema);` — where does this function live? What model does it call? The text on line 104 says "the slowest, highest-capability model from the original dispatch" but this is never wired into the pseudocode. An implementor would have to guess.
- **"Idempotent re-runs" (line 194) is misleading.** The skill does NOT cache across runs — each run is fresh. That's the opposite of idempotent. If I run the same prompt twice, I get two different outputs (different timestamps, possibly different model responses). The word "idempotent" implies running it twice has the same effect as running it once. This is false.
- **No definition of what "extraction" actually produces in Mode B (free-form).** The pseudocode on line 79-99 shows `splitByH2` and `splitByParagraphs`, but the output format differs from Mode A's `structured.jsonl` record. Does free-form extraction also produce `structured.jsonl` entries? The schema of those entries is never defined for Mode B.

**What is unclear or ambiguous:**
- **Phase 3 says "apply the configured resolution rule" — but who configures it?** The user via `--schema`? The skill via defaults? The agent via some other mechanism? The chain of configuration precedence is never stated.

---

### 3. `rules/dispatch-mechanics.md` (4 dispatch mechanisms)

**What works well:**
- The 4 mechanisms are clearly ranked by preference with concrete decision criteria.
- The `--dangerously-skip-permissions` caveat for write tasks is an important security callout.

**What is missing or wrong:**
- **Mechanism 2 bash script has a bug.** Line 46: `" > "$OUT/${slug}.md" 2> "$OUT/${slug}.err" &` — the `PROMPT` variable is used unquoted on line 46 (`"$PROMPT"`), but it's set on line 20 as `PROMPT="$(cat /path/to/research-prompt.md)"`. If the prompt contains shell metacharacters (backticks, `$`, `!`), the subprocess will interpret them. The prompt should be passed via a file, not a shell variable. This is a real bug that would bite anyone with a prompt containing `$` or backticks.
- **Mechanism 3 references an OpenCode bug (#18615) but never says whether it's fixed.** "Known bug (2026-06)" — is this still open? Has it been resolved? The dated reference without a status makes this section fragile.
- **No guidance on what happens when mechanisms are mixed.** Can I use Mechanism 1 for 2 models and Mechanism 2 for 3 others in the same run? The skill implies "pick one mechanism" but never says this is required.

**What is unclear or ambiguous:**
- **"MCP port collision" is mentioned multiple times but never concretely defined.** Which MCPs bind ports? What port? How do you detect the collision? The skill says "configure MCPs that support multiplexing" — which MCPs support this?

---

### 4. `rules/consolidation-rules.md` (dedup, conflict resolution, scoring)

**What works well:**
- The named rule library (`most-severe`, `majority`, `majority-with-uncertain`, etc.) is the strongest part of the skill — concrete algorithms with edge cases defined.
- The alias map pattern with `null` skip rules is pragmatic.

**What is missing or wrong:**
- **The "prefer-with-evidence-then-newer-then-strict" rule (line 160-167) is under-specified.** Step 1: "If one model has a primary quote supporting value X" — what counts as a "primary quote"? Is it a `"`-delimited string in the response? A URL? A `source_refs` entry? The rule assumes extraction already tagged evidence, but the extraction phase doesn't define an "evidence" tag. This rule is aspirational, not algorithmic.
- **Fuzzy match threshold (line 137): "≥80% similar (Levenshtein or token-overlap)" — which one?** These are different algorithms with different behavior. `Levenshtein("BMAD Method", "BMAD-Method")` is high; `token-overlap("AutoGen", "AG2")` is zero. The choice matters and is left unspecified.
- **The `concatenate-all` rule (line 203) says "Order: by model name (alphabetical) for determinism" — but model names aren't in the `fields` object.** The consolidation pipeline receives `fields` per model but the model name is in the parent record. The rule assumes access to data it doesn't describe receiving.

**What is unclear or ambiguous:**
- **What happens when a schema declares `aggregate: "median"` but only 1 model provided a score?** Line 259 says "note it as `(1 model)`" — but is the single value the median? Is it reliable? No confidence qualifier is defined for N=1 aggregations.

---

### 5. `rules/output-schema.md` (output structure)

**What works well:**
- The WYSIWYG markdown formatting rules (line 231-242) are specific and actionable — this is the kind of concrete guidance that prevents rendering bugs.
- The conflict marker legend (`value*`) is a nice touch.

**What is missing or wrong:**
- **`structured.jsonl` schema differs between files.** In `methodology.md` line 28, the record has `raw_text_ref`. In `output-schema.md` line 200, it has `raw_text`. These are different fields. Which is canonical?
- **`conflicts.md` is described as "Same as §4 but as a standalone file" (line 205) — but §4 uses a markdown table format, while `conflicts.md` could be consumed by tooling.** Is the format identical (markdown table) or is there a JSON variant for programmatic consumption? This is never clarified.
- **No definition of what `consolidated.html` generation actually requires.** Line 175 says "convert `consolidated.md` to HTML using a markdown library (`marked` in Node, `markdown` in Python, `pandoc` for richer output)." But the skill is invoked by an agent — does the agent need to have `marked` installed? Is `pandoc` a dependency? The skill doesn't declare dependencies anywhere.

**What is unclear or ambiguous:**
- **The "Dispatch note" in the file header (line 34) is described but never populated in any example.** What does a real dispatch note look like? The examples don't show it.

---

### 6. `rules/examples/research-prior-art.md` (proven worked example)

**What works well:**
- This is the most credible part of the skill — a real run with real outputs, real models, and a real consolidated report.
- The alias map (14 entries) and skip rules are concrete and reproducible.

**What is missing or wrong:**
- **The dispatch script (line 13-33) uses `$PROMPT` as a shell variable, inheriting the injection bug from `dispatch-mechanics.md`.** If the research prompt contains `$` or backticks, the shell will interpret them.
- **"Variations to try" (line 180) says "8-10 models captures more unique finds but diminishing returns past 6" — then immediately admits "this is an empirical observation, not a measured curve."** This is a claim without evidence presented as guidance. Either measure it or don't state it as a recommendation.
- **No mention of how long the actual run took.** The dispatch mechanics say "~2-3 min/model" but the actual wall-clock time for the 6-model run is never stated. This is critical for users estimating cost/latency.

**What is unclear or ambiguous:**
- **The schema has `last_verified: "date"` but who sets this field?** The models? The consolidation? If the models don't include it, does the consolidation add it? This is never defined.

---

### 7. `rules/examples/code-review.md` (code-review recipe)

**What works well:**
- The schema is well-designed for code review: `file:line` as composite key, `most-severe` for severity, `majority` for category.
- The "Custom strategies" table is actionable.

**What is missing or wrong:**
- **"Not yet produced" (line 92).** This is a recipe with no worked example. The prior-art example has a real run; this one is theoretical. For a skill that claims "proven provenance," having untested recipes undermines credibility.
- **The dispatch script uses `code-review-${model}.md` as the output filename (line 30), but `${model}` contains a slash** (e.g., `opencode-go/minimax-m3`). This creates a subdirectory or fails. The prior-art example correctly uses `cut -d/ -f2` to sanitize, but this example doesn't. This is a copy-paste bug.
- **No `--schema` in the dispatch script.** The schema is defined separately but the dispatch command on line 25-31 doesn't pass `--schema`. How does the skill know to use it? Is it passed separately? This is ambiguous.

**What is unclear or ambiguous:**
- **§5 "Per-Reviewer Statistics" — how do you compute "false-positive rate if measurable"?** What's the denominator? Against what ground truth? This section is aspirational, not defined.

---

### 8. `rules/examples/fact-check.md` (fact-check recipe)

**What works well:**
- The schema is clean: `claim_id` as primary key, `majority-with-uncertain` for verdict, `lowest-of-majors` for confidence.
- The "Consensus requirements" section (line 89-95) defines concrete thresholds.

**What is missing or wrong:**
- **"Not yet produced" (line 98).** Same issue as code-review — an untested recipe.
- **The consensus requirements (line 92) say "3+ models agree on `true`" but the dispatch uses 3 models total.** With 3 models, "3+ agree" means unanimous agreement. The threshold is effectively "all models must agree," which is very strict. Is this intentional? If so, say so. If the intent is "majority of N," the threshold should be `ceil(N/2)+1`, not a hardcoded `3`.
- **The schema's `verdict` enum includes `partially-true` but the consensus requirements don't define when to use it.** If 2 models say `true` and 1 says `false`, the recipe says `majority-with-uncertain` returns `uncertain` — but `uncertain` is not in the enum. The enum has `unverified`, not `uncertain`. This is a terminology mismatch.

**What is unclear or ambiguous:**
- **`counter_evidence` is in the schema but the dispatch prompt (line 14-27) asks for it.** If a model doesn't provide counter-evidence for a `true` claim, is the field null or empty? The schema doesn't specify `required` for this field.

---

## §2. Score the Skill on the 8-Dimension Rubric

| Dimension | Score | Justification |
|---|---|---|
| **Catalog of composable units** | 1 | The named rule library (`most-severe`, `majority`, etc.) is a set of informal roles, not a machine-readable catalog. There's no JSON schema or type definition for the rules — they're described in prose with pseudocode fragments. |
| **Dynamic composition** | 1 | The skill has a replanner (mode selection: quick/standard/thorough, schema vs free-form), but there's no audit log of composition decisions. The `run-manifest.json` records what was chosen, not why. |
| **V-loop depth** | 0 | No verification loop exists. The skill dispatches, extracts, consolidates, and outputs — but never tests whether the consolidated output actually satisfies the schema or the user's intent. There's no "does the output make sense?" gate. |
| **Enforcement** | 0 | No CI integration, no IDE hooks, no delivery blockers. The skill is purely honor-system — an agent can invoke it, ignore the output, and nothing catches it. |
| **Parent/worker split** | 2 | Explicit orchestrator/worker split: the calling agent is the orchestrator, the N dispatched models are workers. The skill document clearly delineates responsibilities (skill does orchestration+consolidation, models do the work, calling agent handles retries). |
| **Evidence model** | 1 | Informal evidence handling. `source_refs` is defined in the record schema, `thorough` mode adds source verification, but there's no tiered sufficiency model. A claim with 1 URL and a claim with 5 URLs are treated identically unless the user builds custom logic. |
| **SE + DevOps unified** | 1 | Covers both research (SE-adjacent) and code review (SE) but doesn't cover DevOps tasks (infra review, IaC audit, deployment verification). The examples are research/code/fact-check — no DevOps recipe. |
| **Team customization** | 0 | No overlay pack mechanism. To customize for a team, you fork the skill or build a recipe from scratch. The alias map is per-run, not per-team. There's no `team-overlays/` directory or pack loading. |

**Total: 6/16**

---

## §3. Top 5 Improvements (ranked by impact × effort)

### 1. Shell injection bug in dispatch scripts

- **Issue:** `$PROMPT` used unquoted in shell `for` loops across all dispatch examples.
- **Why it matters:** Any prompt containing `$`, backticks, or `!` will be interpreted by the shell, corrupting the prompt or causing silent failures. This is a real bug that will bite users.
- **Concrete change:** In `rules/dispatch-mechanics.md:40-48` and all example dispatch scripts, replace the shell-variable approach with a heredoc or file-based approach:
  ```bash
  # Write prompt to a temp file, pass via --prompt-file or stdin
  echo "$PROMPT" > "$OUT/prompt.md"
  npx -y opencode-ai run --model "$model" --title "..." --dangerously-skip-permissions "$(cat "$OUT/prompt.md")"
  ```
  Or better: document that `opencode run` accepts `--prompt-file` if it does, or use `printf '%s' "$PROMPT"` with proper quoting.
- **Effort:** Low
- **Impact:** High (prevents real failures)
- **Score:** High/Low = **very high ROI**

### 2. Add a verification gate (V-loop)

- **Issue:** The skill has no V-loop — it never checks whether the consolidated output is valid.
- **Why it matters:** A consolidated table with missing required columns, malformed JSON in `structured.jsonl`, or a `conflicts.md` that references non-existent items would silently pass. The user gets a broken artifact with no indication.
- **Concrete change:** Add a Phase 4.5 to `rules/methodology.md`:
  ```markdown
  ## Phase 4.5 — Verification
  
  Before writing the final artifact:
  1. Validate `structured.jsonl` — each record must match the schema's column types
  2. Validate `consolidated.md` — table header count must match schema column count
  3. Validate `conflicts.md` — every referenced item must exist in the items table
  4. Validate `run-manifest.json` — `models_responded` count must equal the number of `.md` files in the output dir
  
  If any validation fails, write the error to `verification.md` and still produce the artifact (fail-soft), but flag it.
  ```
- **Effort:** Medium
- **Impact:** High (catches silent corruption)
- **Score:** High/Medium = **high ROI**

### 3. Unify `structured.jsonl` schema across files

- **Issue:** `methodology.md` defines the record with `raw_text_ref`; `output-schema.md` defines it with `raw_text`. These are different fields.
- **Why it matters:** An implementor reading both files gets contradictory guidance. Which field should the extraction produce?
- **Concrete change:** In `rules/methodology.md:28`, change `raw_text_ref` to `raw_text` (or vice versa — pick one). Add a canonical schema definition in one place (either `methodology.md` or `output-schema.md`) and reference it from the other.
- **Effort:** Low
- **Impact:** Medium (prevents implementation confusion)
- **Score:** Medium/Low = **high ROI**

### 4. Fix the code-review example's filename bug

- **Issue:** `rules/examples/code-review.md:30` uses `${model}` in the filename without sanitizing the slash.
- **Why it matters:** Anyone copying this example verbatim will get a broken dispatch (creates subdirectories or fails).
- **Concrete change:** In `rules/examples/code-review.md:30`, change:
  ```bash
  > "code-review-${model}.md" 2> "code-review-${model}.err" &
  ```
  to:
  ```bash
  slug=$(echo "$model" | cut -d/ -f2)
  > "code-review-${slug}.md" 2> "code-review-${slug}.err" &
  ```
  And add the `slug` variable definition before the loop.
- **Effort:** Low
- **Impact:** Medium (prevents copy-paste failures)
- **Score:** Medium/Low = **high ROI**

### 5. Define the "extractor model" dispatch mechanism

- **Issue:** `methodology.md:58` references `dispatchExtractorModel()` but never defines how it works. The text on line 104 says "the slowest, highest-capability model from the original dispatch" but this is never wired into the pseudocode or the dispatch mechanics.
- **Why it matters:** Mode B (free-form) extraction depends on this function. Without a definition, implementors have to invent it, and different implementations will behave differently.
- **Concrete change:** In `rules/methodology.md`, after line 104, add:
  ```markdown
  **Extractor model dispatch:** the extractor model is re-dispatched using the same mechanism as Phase 1 (Mechanism 2 by default). The prompt is:
  ```
  Reformat the following response into a JSON list matching this schema: <schema>
  
  Response:
  <model's raw response>
  ```
  Parse the extractor's JSON output. If parsing fails, fall back to Phase 2's paragraph split.
  ```
- **Effort:** Low
- **Impact:** Medium (makes Mode B implementable)
- **Score:** Medium/Low = **high ROI**

---

## §4. Open Questions

1. **Is the "auto-discover models" feature implemented or aspirational?** The SKILL.md describes it but no file contains the algorithm. If it's not implemented, the `--models` flag is effectively required, and the "default" column in the inputs table is misleading.

2. **What is the actual dependency set?** The skill references `marked`, `markdown`, `pandoc`, `npx`, `opencode-ai` — but never declares them as dependencies. Is `pandoc` optional? Is `marked` a Node dependency the agent must install? A `dependencies.md` or `package.json` equivalent is missing.

3. **How does the skill handle models that produce structured output (JSON) vs. markdown?** The extraction pseudocode assumes markdown tables. If a model returns JSON (because the prompt asked for it), does the skill parse JSON? The extraction logic doesn't cover this.

4. **What is the relationship between `--mode thorough` and the `deep-research` skill?** SKILL.md line 254 mentions "use Claude's `deep-research` skill if available" — but `thorough` mode already adds cross-source verification. Are these redundant? Complementary? The boundary is unclear.

5. **Who owns the `run-manifest.json` schema?** It's defined in two places (`methodology.md` and `output-schema.md`) with slightly different fields. Is there a canonical JSON Schema for it?

6. **The fact-check example's `verdict` enum includes `partially-true` but the `majority-with-uncertain` rule returns `uncertain`.** Are these the same value? If not, which one goes in the consolidated output?

7. **What happens when N=2 and models disagree on everything?** The `majority` rule returns `null` for 2-model ties. The `majority-with-uncertain` rule returns `uncertain`. But the consolidated output format doesn't have a defined representation for "all conflicts unresolved." Is there a special section? A flag?

---

## §5. Confidence

- **Overall confidence:** Medium-High

- **What would change my assessment:**
  - If the "auto-discover models" feature is actually implemented somewhere I didn't find (e.g., in a script or agent config), the skill is more complete than I rated it.
  - If there's a working code-review or fact-check run (not just the recipe), the "untested recipes" concern would be resolved.
  - If the shell injection bug has already been caught and fixed in a newer version, the top improvement drops off.
