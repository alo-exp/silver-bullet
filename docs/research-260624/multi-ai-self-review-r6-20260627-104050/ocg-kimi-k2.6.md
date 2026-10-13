# Critical Self-Review: `multi-ai-task` Skill

## §1. Critical Assessment

### 1. `SKILL.md`

**What works well**
- The "When to use / When NOT to use" table (`SKILL.md:35-42`) is precise and genuinely prevents misuse. The negations are strong ("adds cost + consolidation time for no benefit").
- The failure-modes table (`SKILL.md:217-228`) is excellent operational telemetry — it maps symptoms to fixes with concrete flags like `--dangerously-skip-permissions`.

**What is missing or wrong**
- **Version inconsistency:** The user prompt says the skill is at v2.0.0, but the frontmatter says `version: 2.1.0` (`SKILL.md:6`). If this is a v2.1.0 file, the provenance section should reflect that the v2.0.0 → v2.1.0 delta was schema auto-injection + `run-manifest.json` alias fields; instead it narrates as if v2.0.0 is current.
- **Ambiguous `--schema` parsing:** The docs say `--schema` accepts "a JSON object (inline) or a path to a `.json` file" (`SKILL.md:67`). There is no disambiguation rule for how the skill tells an inline JSON string (`{"type":"table"}`) from a filename that happens to start with `{`. A simple heuristic (starts with `{` or `[` = inline) should be documented.
- **`--no-auto-inject` vs. `--schema` interaction gap:** If `--schema` is omitted, auto-injection has nothing to inject, yet the flag description (`SKILL.md:69`) implies it's relevant only when `--schema` is passed. The docs should state explicitly: "If no `--schema` is provided, `--no-auto-inject` is a no-op."

**What is unclear or ambiguous**
- **HTML renderer selection:** The skill says `consolidated.html` is generated using "a markdown library (`marked` in Node, `markdown` in Python, `pandoc` for richer output)" (`SKILL.md:174`). It is unclear whether the skill auto-detects the environment, requires the user to install one, or fails silently if none are present.
- **`user-invocable: false` vs. CLI syntax:** The frontmatter declares `user-invocable: false` (`SKILL.md:5`), yet the usage block presents a CLI-like invocation (`/multi-ai-task "<task-prompt>" ...`). If this is a system-only skill, the CLI syntax is misleading; if it can be invoked by users, the frontmatter is wrong.

---

### 2. `rules/methodology.md`

**What works well**
- The extraction pseudocode for Mode A (`methodology.md:38-64`) is explicit about the fallback chain (table → tags → extractor model → paragraph split), which makes the extraction surface area testable.
- The clarification that the extractor model is *not* the failing model (`methodology.md:104`) prevents a common anti-pattern.

**What is missing or wrong**
- **No handling of truncated model responses:** If a model hits a token limit mid-table, the markdown table will be malformed. The skill should document how it detects and handles truncation (e.g., missing closing `|` or `</structured>` tag). Currently: no mention.
- **Missing output-dir collision guidance:** The "Idempotent re-runs" section (`methodology.md:172-173`) says runs are fresh, but if the user passes `--out ./foo` twice, the second run will overwrite the first. The skill should warn that `--out` must be unique or auto-append a timestamp when omitted.

**What is unclear or ambiguous**
- **Phase numbering drift:** `methodology.md` defines 4 phases (1-4), but `consolidation-rules.md` introduces Phase 3.5 and 3.6. It is unclear whether `phases_completed` in `run-manifest.json` should record `[1,2,3,3.5,3.6,4]` or just `[1,2,3,4]`. The canonical schema in `output-schema.md` only shows integers (`output-schema.md:235`).
- **"LLM-assisted extraction" is not actually LLM-assisted in Mode A:** The text says "Structured extraction (Mode A) is deterministic — pure parsing, no LLM in the loop" (`methodology.md:157`), but then the fallback path 3 dispatches an extractor model. The statement is technically true for the happy path but misleading without the qualifier.

---

### 3. `rules/dispatch-mechanics.md`

**What works well**
- The per-model output capture advice (`dispatch-mechanics.md:119-124`) — "Always check the model's CWD for stray `*.md` files" — is a hard-won operational tip that will save users from data loss.
- The model selection strategy table (`dispatch-mechanics.md:164-171`) gives concrete, actionable guidance (e.g., "≥1 reasoning-focused model + ≥1 generalist").

**What is missing or wrong**
- **`slug` sanitization is fragile:** The pattern `cut -d/ -f2` (`dispatch-mechanics.md:51`) breaks for any provider with a nested path (e.g., `azure/openai/gpt-4` → slug becomes `openai`). A robust replacement like `tr '/' '-'` should be documented.
- **No concrete sequential dispatch example:** The "Parallel vs sequential" section (`dispatch-mechanics.md:104-114`) discusses tradeoffs but never shows how to run sequential. Users must infer to remove `&` and `wait`. A one-line note ("Remove `&` from the loop body and add `wait` after each iteration") would suffice but is absent.
- **Mechanism 2 shell snippet has an implicit `cd` hazard:** The research example (`research-prior-art.md:16`) does `cd "$OUT"` before the loop, but the generic Mechanism 2 snippet (`dispatch-mechanics.md:37-60`) does not. If a user copies the generic snippet after `cd "$OUT"`, the `"$OUT/${slug}.md"` path becomes `$OUT/$OUT/${slug}.md`. The snippets are inconsistent.

**What is unclear or ambiguous**
- **MCP port collision "fix" is underspecified:** The text says "configure MCPs that support multiplexing, or ... restart the MCP between dispatches" (`dispatch-mechanics.md:113`). It does not say *how* to restart an MCP or which MCPs support multiplexing, making this advice non-actionable.
- **Mechanism 3 "Known bug" reference:** The link to Issue #18615 (`dispatch-mechanics.md:86`) is an internal OpenCode tracker reference. External users (or non-OpenCode harnesses) cannot look this up. A one-sentence summary of the bug should be inlined.

---

### 4. `rules/consolidation-rules.md`

**What works well**
- The named rule library (`most-severe`, `majority-with-uncertain`, `lowest-of-majors`, etc.) is formally defined with algorithms, inputs, and edge cases. This is the strongest part of the skill.
- The alias map guidance (`consolidation-rules.md:82-92`) correctly keeps aliases task-specific and documents them in `run-manifest.json`.

**What is missing or wrong**
- **`majority` tie-break is undefined when schema lacks enumeration order:** The rule says "Ties broken by schema-defined enumeration order (first listed wins)" (`consolidation-rules.md:177`). If the schema uses `type: "string"` without a `values` list, there is no enumeration order. The fallback behavior is not specified.
- **Full-disagreement fallback is missing for non-`majority` rules:** `majority` returns `null` and flags "no majority" (`consolidation-rules.md:178`), but `most-severe`, `prefer-with-evidence-then-newer-then-strict`, and `longest-with-quote` do not specify what happens when every model produces a different value. For example, if 6 models assign 6 different severity levels and `allow_downgrade: false`, what is the result? Undefined.
- **`prefer-with-evidence` assumes a `last_verified` field that may not exist:** Step 2 of the rule says "Newer `last_verified` wins" (`consolidation-rules.md:159`). This field is research-specific. If a code-review schema uses `category` with this rule, the tie-break silently skips to step 3 because no model has `last_verified`. The rule should document what happens when the evidence field is absent.

**What is unclear or ambiguous**
- **Phase numbering:** As noted above, this file uses Phase 3, 3.5, and 3.6 while `methodology.md` uses Phase 3 and 4. It is unclear if `phases_completed` should track sub-phases.
- **`concatenate-all` separator collision:** The rule joins values with ` ; ` (`consolidation-rules.md:202`). If a model's evidence text legitimately contains ` ; `, the joined output is ambiguous. A configurable delimiter or JSON array output would be safer.

---

### 5. `rules/output-schema.md`

**What works well**
- The WYSIWYG formatting rules (`output-schema.md:258-269`) are concrete and actionable (e.g., "Add blank line before AND after every table").
- The `run-manifest.json` schema is comprehensive and centralized (`output-schema.md:207-254`), with clear field semantics.

**What is missing or wrong**
- **`verification.md` is completely undocumented:** The file is listed in the output directory tree (`output-schema.md:171`) but nowhere else in the file. There is no schema, example, or description of what it contains. For a "thorough mode only" artifact, this is a major specification gap.
- **Contradictory WYSIWYG advice:** The rules say "Avoid unicode in cells when possible" (`output-schema.md:264`) but immediately exempt `·` and `§`. Then rule 7 says "Wrap tables in clean code blocks when rendering for the web" — which would prevent the table from rendering as a table at all in most markdown parsers. This is incorrect advice.
- **§3 "Per-Item Details" overlaps with §2B:** In Mode B (no schema), §2B already renders "Per-model notes" and "Consensus description" per item. §3 then asks for "compact bullet" per item with task-specific fields. The distinction is unclear; users will duplicate content or omit one section inconsistently.

**What is unclear or ambiguous**
- **`conflicts.md` standalone schema:** The file says `conflicts.md` is "Same as §4 but as a standalone file" (`output-schema.md:205`). It does not specify whether §4's header (`## §4. Conflicts & Resolutions`) is repeated, whether the table is the only content, or if frontmatter is added. Tooling that consumes `conflicts.md` needs a stable schema.
- **"`...` for privacy" in `task_prompt`:** The `run-manifest.json` docs say `task_prompt` can be `"..."` for privacy (`output-schema.md:241`). It is unclear what triggers this redaction (a flag? automatic PII detection?) or whether the hash is still computed on the full prompt.

---

### 6. `rules/examples/research-prior-art.md`

**What works well**
- The alias map (`research-prior-art.md:125-140`) is a real, battle-tested artifact with 14 entries. Including it as a worked example makes the abstraction concrete.
- The prompt structure (`research-prior-art.md:37-68`) is a good template that users can adapt.

**What is missing or wrong**
- **Alias key format may not match normalization:** The alias map uses keys like `AutoGen/AG2` (`research-prior-art.md:127`). The default normalization is "lowercase + strip-punctuation + collapse-whitespace" (`consolidation-rules.md:82`). A slash `/` may or may not be stripped as punctuation; the behavior is undefined. If the normalized form of `AutoGen/AG2` becomes `autogenag2`, the alias will never match.
- **"Diminishing returns past 6" is unmeasured:** The text admits "this is an empirical observation, not a measured curve" (`research-prior-art.md:182`). For a skill that asks users to spend N× API cost, this should either be backed by data or removed.

**What is unclear or ambiguous**
- **Scoring rubric `max_total` mismatch with levels:** The rubric lists 3 levels per dimension (`none`, `informal roles`, `machine-readable catalog`) which maps to scores 0, 1, 2. `max_total: 16` is correct (8 dims × 2). However, the prompt's 8-dimension rubric table uses the same labels but doesn't explicitly map them to 0/1/2. A model could misinterpret `informal roles` as 1 or as a string label, producing non-numeric output that breaks aggregation.

---

### 7. `rules/examples/code-review.md`

**What works well**
- The composite key explanation (`code-review.md:68-70`) is a clear correction of an earlier design mistake (`"primary_key": "file:line"`). This shows honest evolution.
- The security note about `--dangerously-skip-permissions` (`code-review.md:45`) is appropriately cautious.

**What is missing or wrong**
- **No worked example:** "Not yet produced (deferred to v2.2.0)" (`code-review.md:109-110`). For a skill that claims code review as a primary use case, the absence of any proven run is a credibility gap. The prior-art example proves the pipeline works for research; code review has no such proof.
- **No guidance on multi-line code snippets in table cells:** Code review findings often contain multi-line code blocks. The schema uses `type: "text"` with `max_words`, but markdown tables cannot contain line breaks in cells without breaking the table. The skill should document how to handle this (e.g., escape newlines, use `<br>`, or move snippets to §3).

**What is unclear or ambiguous**
- **Pre-commit hook variation is non-actionable:** The variation says "Pre-commit hook: combine with git diff to only review changed lines (NOT currently supported as a built-in dispatch; requires custom runner)" (`code-review.md:106`). It is unclear whether this is a roadmap item or just an idea; the parenthetical reads as a disclaimer rather than guidance.

---

### 8. `rules/examples/fact-check.md`

**What works well**
- The consensus requirements (`fact-check.md:103-108`) are parameterized correctly (`max(2, ceil(N/2))`), and the text explicitly corrects an earlier "3+ models" typo. This is rigorous.
- The `lowest-of-majors` confidence rule (`fact-check.md:75`) is well-suited to high-stakes fact-checking.

**What is missing or wrong**
- **No worked example:** Same as code-review — "Not yet produced (deferred to v2.2.0)" (`fact-check.md:111-112`). Two of the three canonical examples lack provenance.
- **`majority-with-uncertain` tie at threshold is undefined:** For N=4, threshold = 2. If two models say `true` and two say `false`, both values meet the threshold. The algorithm does not specify whether this returns `unverified` or the first value. This is a real edge case for even-numbered model counts.

**What is unclear or ambiguous**
- **Interaction with `thorough` mode is unexplored:** Fact-checking seems like the ideal use case for `thorough` mode's cross-source verification, yet the example never mentions it. Users will not know whether to add `--mode thorough` or whether the standard schema already covers verification via `sources` and `evidence`.

---

## §2. Score the Skill on the 8-Dimension Rubric

| Dimension | Score | Justification |
|---|---|---|
| **Catalog of composable units** | **2** | The `--schema` JSON is a machine-readable catalog of columns, types, dedup keys, and conflict rules. It is formally defined and consumed by the consolidation engine. |
| **Dynamic composition** | **1** | The skill has three fixed modes (`quick`/`standard`/`thorough`) that act like a coarse replanner, but there is no runtime catalog of task types or automatic rule selection based on prompt content. |
| **V-loop depth** | **1** | `thorough` mode adds end-to-end cross-source verification, but there is no per-step rollup or intent gate within the 4-phase pipeline itself. Phase boundaries are run-once. |
| **Enforcement** | **0** | Pure honor system. No CI gates, IDE hooks, or delivery blockers. As a skill (not infrastructure), this is expected, but the rubric scores infrastructure integration. |
| **Parent/worker split** | **2** | Explicit and clean: the skill is the orchestrator (parent), the N models are workers. Dispatch mechanics, failure isolation, and result aggregation are all architected around this split. |
| **Evidence model** | **1** | Sources and evidence quotes are collected, but there is no built-in tiered sufficiency model or staleness tracking. The `last_verified` field is research-specific schema sugar, not a core evidence framework. |
| **SE + DevOps unified** | **2** | The skill is task-agnostic and the examples explicitly cover both software engineering (code review) and general production tasks (research, fact-check). It "covers both production task types" in one model. |
| **Team customization** | **1** | Teams can pass custom schemas and alias maps, but there is no formal "overlay pack" system. Teams must write raw JSON and manage their own alias maps; no team-level defaults or inherited configurations. |

**Total: 10 / 16**

---

## §3. Top 5 Improvements (ranked by impact × effort)

### 1. Add proven worked examples for code-review and fact-check
- **Issue:** Both example files state "Not yet produced (deferred to v2.2.0)."
- **Why it matters:** Two of the three canonical use cases lack provenance. Users cannot trust that the schema and conflict rules actually work for these tasks without a real run.
- **Concrete change:** `rules/examples/code-review.md:109` and `rules/examples/fact-check.md:111` — replace the deferral notice with a link to an actual run output (e.g., `docs/research-260624/`-style path) or, if none exists, run the skill on a real PR / real claims and check in the outputs.
- **Effort:** medium
- **Impact:** high
- **Score:** 2.0

### 2. Document `verification.md` and `evidence-ledger.md` schemas
- **Issue:** `output-schema.md` lists these files in the directory tree (`output-schema.md:170-171`) but provides zero specification for their content, structure, or schema.
- **Why it matters:** `thorough` mode is advertised for "high-stakes (regulatory, due-diligence)" use, yet its unique artifacts are unspecified. This makes the mode unusable for teams that need validated, machine-readable output.
- **Concrete change:** Add a new section to `output-schema.md` after "Supporting files" titled `### evidence-ledger.md` and `### verification.md`, each with a JSON schema example and field semantics analogous to `run-manifest.json`.
- **Effort:** low
- **Impact:** high
- **Score:** 3.0

### 3. Unify phase numbering across all files
- **Issue:** `methodology.md` uses Phases 1-4; `consolidation-rules.md` invents 3.5, 3.6; `output-schema.md` shows `phases_completed: [1, 2, 3, 4]`. This makes partial-failure auditing ambiguous.
- **Why it matters:** A run that fails during conflict resolution could legitimately claim Phase 3 is complete while 3.5 is not, but the manifest schema only accepts integers.
- **Concrete change:** `consolidation-rules.md:136` — rename "Phase 3.5" to "Phase 3, Step B: Resolve Conflicts" and "Phase 3.6" to "Phase 3, Step C: Score + Synthesize". Update `output-schema.md:235` example to `phases_completed: [1, 2, 3, 4]` with a note that Phase 3 sub-steps are implied by `consolidation.conflicts_resolved > 0`.
- **Effort:** low
- **Impact:** medium
- **Score:** 2.0

### 4. Add explicit full-disagreement fallback to all conflict rules
- **Issue:** `most-severe`, `prefer-with-evidence`, `longest-with-quote`, and `union-dedup` do not specify behavior when every model provides a different value. Only `majority` returns `null`.
- **Why it matters:** With 4-6 diverse models, full disagreement is common on subjective fields (e.g., `category` in research). Undefined behavior will produce silent `null`s or implementation-dependent output.
- **Concrete change:** `rules/consolidation-rules.md:140-221` — append to each rule definition: "If no winner can be determined (e.g., all values are unique and no tie-break applies), return `null` and flag the item in `conflicts.md` with `resolution: none (full disagreement)`." For `most-severe`, also clarify that `allow_downgrade: true` can be used to break the tie.
- **Effort:** low
- **Impact:** high
- **Score:** 3.0

### 5. Provide a concrete sequential dispatch snippet
- **Issue:** `dispatch-mechanics.md` only shows parallel dispatch with `&`. The parallel-vs-sequential table mentions sequential but never shows how.
- **Why it matters:** MCP port collision and long-running tasks (10+ min) are real failure modes. Users need a copy-pasteable sequential pattern, not an abstract recommendation.
- **Concrete change:** `rules/dispatch-mechanics.md:104-114` — add a code block after the parallel example:
  ```bash
  # Sequential variant — remove & and wait per iteration
  for model in ...; do
    slug=$(echo "$model" | tr '/' '-')
    timeout 600 npx -y opencode-ai run --model "$model" ... > "$OUT/${slug}.md" 2> "$OUT/${slug}.err"
    # Optional: restart MCP here if port collision persists
  done
  ```
- **Effort:** low
- **Impact:** medium
- **Score:** 2.0

---

## §4. Open Questions

1. **What is the intended runtime environment?** The skill references `npx opencode-ai run`, `opencode.json`, and `task` tool subagent types, suggesting it is tightly coupled to the OpenCode ecosystem. Yet it also presents Mechanism 4 (direct HTTP to provider API) as a fallback for "a different harness entirely (Claude, Codex, Cursor with no OpenCode)." Is the skill meant to be portable, or is OpenCode the only supported first-class harness? This changes how harshly we should judge Mechanism 1's static-config limitation.

2. **Who maintains the alias maps?** The research alias map has 14 entries and is task-specific. If a team runs this skill weekly on different research topics, do they maintain a growing global alias map, or start fresh each time? The skill says "Add new aliases ... and update the map" (`research-prior-art.md:142`), but there is no guidance on persistence, versioning, or sharing across team members.

3. **How is the scoring rubric actually enforced?** The research example includes an 8-dimension rubric with `levels` arrays, but the schema spec does not define a `levels` field for column types. Is the rubric passed as a separate JSON file, embedded in the prompt, or ignored by the consolidation engine? The relationship between the rubric and the schema is opaque.

4. **What is the governance model for `consolidated.html` generation?** The skill mentions `marked`, `markdown`, and `pandoc` but does not specify which is required, how it is invoked, or what happens if none are installed. Is HTML generation a soft dependency (skip if missing) or a hard failure?

5. **Is there a plan for v2.2.0, and what is in scope?** Two worked examples are deferred to v2.2.0. Is this a real milestone with an owner, or an indefinite placeholder? Knowing the roadmap would change whether "defer to v2.2.0" is acceptable or a red flag.

---

## §5. Confidence

- **Overall confidence:** **medium**

- **What would change my assessment:**
  - **High confidence** if I could inspect an actual `run-manifest.json` and `verification.md` from a `thorough` mode run (to validate that the undocumented artifacts have stable schemas) and see a code-review or fact-check run with real model outputs (to confirm the schemas and conflict rules behave as specified).
  - **Low confidence** if a `thorough` mode run reveals that `verification.md` is just free-form prose with no structure, or if a code-review run shows that the `file:line` composite key fails on real model outputs (e.g., models emit ranges like `42-50` instead of single lines, breaking dedup).
