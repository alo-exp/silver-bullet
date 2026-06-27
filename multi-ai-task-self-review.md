# Critical Self-Review: multi-ai-task Skill

## §1. Critical Assessment

### 1. SKILL.md (Entry Point)

**What works well**
- The "When to use / When NOT to use" table (lines 35-42) is clear, honest, and avoids scope creep. The latency and cost trade-offs are upfront.
- The `--no-auto-inject` flag and schema auto-injection logic (lines 23-24, 70, 155-156) is a genuinely useful UX improvement over v1.0.0. It removes a common failure mode (models ignoring the schema).

**What is missing or wrong**
- **Version drift:** The frontmatter says `version: 2.1.0` (line 6) but the task description says the skill is at v2.0.0. If this is intentional (v2.1.0 already shipped), the provenance section (line 266) only references v2.1.0 runs in one place and leaves it ambiguous whether the 2026-06-27 proven run was v2.0.0 or v2.1.0.
- **No execution contract:** The skill describes *what* happens but never says *how* an agent actually invokes it. There is no script, no binary, no shell command beyond hand-rolled `for` loops. The "Usage" block (lines 56-58) shows `/multi-ai-task "..."` but this is pseudo-syntax — no such CLI exists in the repo. The skill is a specification, not a runnable tool. An agent reading this has to build the orchestration from scratch every time.
- **Failure-mode table contradicts dispatch-mechanics:** Line 248 says "`npx opencode-ai run` returns instantly with no output" but the failure-mode table in `dispatch-mechanics.md` (lines 131-140) already covers this. The duplication is out of sync: `SKILL.md` omits the `gtimeout` vs `timeout` nuance that `dispatch-mechanics.md` includes.

**What is unclear or ambiguous**
- **What does "auto-discover" mean in practice?** Line 65-66 says `--models` defaults to "Auto-discover (see below)" but the "Default model discovery" section (lines 71-74) just says "queries the local OpenCode config... and picks a balanced default set." There is no algorithm, no pseudocode, no fallback if the config file doesn't exist. An agent cannot implement this without guessing.
- **No guidance on prompt size limits:** The skill says "same prompt verbatim to all N models" (line 269) but never mentions token/context-window limits. If the user passes a 200 KB prompt, some models will truncate. Should the skill split the prompt? Warn? Skip small-context models?

---

### 2. rules/methodology.md (4-Phase Pipeline)

**What works well**
- The Phase 2 extraction pseudocode (lines 37-65) is concrete and covers four fallback paths. The explicit comment "asking it again is unlikely to help" (line 53-54) is a nice touch that prevents a common anti-pattern.
- The cross-cutting principles (lines 151-173) — generic by design, deterministic + LLM-assisted hybrid, audit trail, idempotent re-runs — are well-stated and genuinely guide behavior.

**What is missing or wrong**
- **Phase 1 lacks dispatch detail:** Phase 1 (lines 7-20) says "same task-prompt is sent to each of N models in parallel" but provides no mechanism. The actual dispatch logic lives in `dispatch-mechanics.md`, which is fine, but Phase 1 should at least reference it explicitly (e.g., "See `rules/dispatch-mechanics.md` for the 4 mechanisms"). As written, a reader of just `methodology.md` has no idea how to actually launch the models.
- **Row validation is underspecified:** Lines 69-73 say "drop invalid rows" and "truncate with `...` marker" but never define what happens to dropped rows. Are they logged? Counted in `run-manifest.json → totals`? The manifest schema has `rows_per_model` but no `rows_dropped` field, so data loss is invisible.
- **Extractor model selection is circular:** Lines 52-53 say the extractor is "the slowest/highest-capability model from the original dispatch." But if the "slowest" model is the one that timed out (a common failure mode), the skill has no fallback extractor. The circular dependency is unacknowledged.

**What is unclear or ambiguous**
- **What is a "phase"?** The document numbers phases 1, 2, 3, 4 but `consolidation-rules.md` introduces "Phase 5 — SCORE + SYNTHESIZE" (line 267). Is Phase 5 part of Phase 4 (synthesis) or a separate phase? The manifest tracks `phases_completed: [1,2,3,4]` — so Phase 5 is invisible to the audit trail.
- **"Idempotent re-runs" is aspirational:** Line 172 says "It does NOT cache across runs by default" but then says "`run-manifest.json` from previous runs can be referenced for incremental consolidation (future enhancement)." So re-runs are not actually idempotent in the sense that they produce the same output given the same input — they're just "can be re-run." The word is misused.

---

### 3. rules/dispatch-mechanics.md (4 Dispatch Mechanisms)

**What works well**
- The "Choosing the right mechanism" table (lines 180-188) is practical and maps real constraints to real mechanisms. The MCP port collision caveat (lines 113-114) is a genuine operational insight.
- The `$slug` sanitization note (lines 64-65) and the `--y` flag note (line 65) are hard-won lessons from the proven run. They prevent real bugs.

**What is missing or wrong**
- **Mechanism 1 is largely fiction:** The "preferred-if-available" mechanism (lines 9-31) requires a `task` tool feature that doesn't exist in current OpenCode ("Dynamic per-call model selection is a 6-time-requested feature... not yet released"). Calling it "preferred" is misleading — for 99% of users, it is unavailable. It should be labeled "future / requires unreleased feature" and Mechanism 2 should be promoted to "preferred."
- **Mechanism 2 has a dangerous default:** Lines 55-56 say `--dangerously-skip-permissions` is "fine for read-only tasks" but the code example (lines 50-58) includes it unconditionally in the research example. The security note is buried in prose, not in the code comment. A user copy-pasting the script will skip permissions for write tasks without noticing.
- **No timeout for the `wait` command:** The parallel dispatch example (lines 50-58) uses `wait` but never `wait -n` or a global timeout. If one model hangs forever, the entire `wait` blocks indefinitely. The per-model `timeout` helps, but `wait` itself needs a ceiling.

**What is unclear or ambiguous**
- **"Parallel vs sequential" table oversimplifies:** The table (lines 106-110) says parallel risks "MCP port collision" but sequential "doesn't fix port collision if the MCP binds a port on first start and holds it." This is contradictory — the table implies sequential fixes the problem, but the caveat says it doesn't. The recommendation should be: "Use sequential + MCP restart between dispatches" for port-heavy tasks.
- **Mechanism 3 bug status is unclear:** Line 86 references Issue #18615 but doesn't say if it's fixed, open, or closed. The workaround is vague ("pass model on the server side via config"). If this mechanism is broken, it should be marked "not recommended until fixed."

---

### 4. rules/consolidation-rules.md (Dedup, Conflict Resolution, Scoring)

**What works well**
- The named rule library (lines 163-223) is the strongest part of the skill. Each rule has: purpose, input, algorithm, edge cases, and implementation notes. `most-severe` (lines 167-173) and `majority-with-uncertain` (lines 180-186) are particularly well-specified.
- The alias map guidance (lines 326-335) correctly makes aliases task-specific and persistent in the manifest.

**What is missing or wrong**
- **Missing rule: `prefer-with-evidence-then-newer-then-strict` is not fully defined:** The rule is referenced in the schema examples (e.g., `research-prior-art.md` line 95) and listed as a named rule in `SKILL.md` (line 153), but its full algorithm is only sketched in lines 155-162. It lacks: (a) a formal definition of "quoted primary source" (what counts as a quote? blockquote? inline `"..."`? citation URL?), (b) how `last_verified` is extracted from model output (is it a schema field? parsed from prose?), and (c) what "strict" means in step 3 ("treat the lone direct as an outlier" — by what threshold? 1 of 6? 1 of 3?). The rule is the most complex one and the least formalized.
- **Score aggregation lacks statistical rigor:** Lines 251-258 say "median + range" but never mention interquartile range, standard deviation, or outlier detection. For 6 models, one outlier can skew the median by 1 point, which is significant on a 0-2 scale. The skill should flag when the range exceeds a threshold (e.g., `range > 1` on a 0-2 scale = "significant disagreement").
- **Phase 5 is a section title without a Phase 4:** The document jumps from "Phase 3 — DEDUP" (line 78) to "Phase 4 — RESOLVE CONFLICTS" (line 136) to "Phase 5 — SCORE + SYNTHESIZE" (line 267). Where is Phase 4 in the methodology? In `methodology.md`, Phase 4 is "Final synthesis." Here, Phase 4 is "RESOLVE CONFLICTS" and Phase 5 is "SCORE + SYNTHESIZE." The numbering is inconsistent across files.

**What is unclear or ambiguous**
- **"Task-type-specific skip entries belong in the alias map" (line 121):** This conflates two concepts. Skip rules (drop "N/A" rows) and alias maps (merge "AutoGen" and "AG2") are different. The document mixes them in the same `aliases` object (`aliases[n] = null` to skip). This is clever but undocumented — a reader won't understand why `null` values are allowed in an alias map unless they read the pseudocode carefully.
- **How does `newer` work for dates?** Line 150 says default for `date` is `newer` (max date), and line 261 says "use the newer `last_verified` date." But what if models return dates in different formats? ISO-8601 is specified in `SKILL.md` (line 125) but models often output "June 2024" or "v2.1.0 (2024-03-15)." The parser is unspecified.

---

### 5. rules/output-schema.md (Output Structure)

**What works well**
- The `run-manifest.json` canonical schema (lines 207-255) is comprehensive and cross-referenced. Every field has semantics, and the document explicitly says "do not duplicate" (line 148 in methodology, line 209 here).
- The WYSIWYG formatting rules (lines 258-270) are specific and actionable. Rule 4 ("Avoid unicode in cells when possible") with the safe list (`·`, `§`) is a nice touch.

**What is missing or wrong**
- **`verification.md` schema is defined in SKILL.md but not here:** `SKILL.md` lines 194-201 define `verification.md` (per-item rollup), but `output-schema.md` only mentions `evidence-ledger.md` in passing and doesn't include the `verification.md` schema. If this file is the "canonical schema" for all outputs, it should include both.
- **Missing file: `score-aggregate.md` is mentioned as "planned" in SKILL.md (line 258) but never defined.** The skill says "ignore for v2.x" but this creates a dangling reference. It should be removed or explicitly deprecated.
- **`consolidated.html` generation is hand-waved:** Line 205 says "convert `consolidated.md` to HTML using a markdown library" but doesn't specify which library, which CSS framework, or how the HTML is self-contained. The research example references `SB_CONSOLIDATED_PRIOR_ART_REPORT.html` but there's no build script or template for it. An agent cannot reproduce this.

**What is unclear or ambiguous**
- **"Fields per model" column (line 61):** The default items table includes `m1: {...}, m2: {...}` as a column. This is unreadable for N=6 with more than 2-3 fields. The note says "truncate if verbose" but doesn't define the truncation rule. Is it character count? Word count? Field count?
- **Appendix B "Coverage Scoreboard" (lines 181-189):** What is a "bucket"? The example is empty (`<Bucket 1>`). For research, buckets might be categories; for code review, they might be files or severity levels. The skill needs to define how buckets are derived (schema field? auto-discovered from items?).

---

### 6. rules/examples/research-prior-art.md (Proven Worked Example)

**What works well**
- The alias map (lines 125-141) is specific, research-tested, and directly usable. It demonstrates the value of task-specific aliases.
- The scoring rubric (lines 104-119) is concrete and maps to the 8 dimensions used in this review. It shows the skill's intended power.

**What is missing or wrong**
- **The schema omits `conflict_resolution` for most fields:** The research schema (lines 72-99) only defines conflict resolution for `category`, `maturity`, and `confidence`. What about `composition_model`, `v_loop_support`, `enforcement_mechanism`, etc.? If models disagree on `v_loop_support`, the default rules apply — but the defaults are not always appropriate for enum fields. The example should show a complete `conflict_resolution` block.
- **"Diminishing returns past 6" is anecdotal:** Line 182 says "8-10 models captures more unique finds but diminishing returns past 6 (this is an empirical observation, not a measured curve)." This is honest but unhelpful. The skill should either (a) not make the claim, or (b) provide a methodology for measuring it (e.g., "run with 4, 6, 8 models and compare unique item counts").
- **The dispatch script is missing `--dangerously-skip-permissions`:** The research example (lines 13-33) uses `--dangerously-skip-permissions` but the code-review and fact-check examples explicitly do NOT. This inconsistency is confusing. Research is read-only, so skipping permissions is correct, but the example should justify it with a security note like the other examples do.

**What is unclear or ambiguous**
- **What is the "subject"?** The example refers to "subject X" (line 9) and "SUBJECT" (lines 157, 163) but never names it. I infer it's Silver Bullet itself, but the example should be explicit: "In this example, SUBJECT = Silver Bullet." This would make the gap analysis (`gaps_vs_sb`, `sb_gaps_vs_them`) comprehensible.
- **How was the scoring rubric used?** Lines 104-119 define the rubric, but the output section (lines 154-167) doesn't mention where the scores appear. Are they in `consolidated.md` §5? In a separate file? The proven run says "All 4 scoring matrices... extracted and aggregated" but the example doesn't show how the user passed the rubric to the skill.

---

### 7. rules/examples/code-review.md (Recipe)

**What works well**
- The composite key explanation (lines 68-70) is excellent. It explicitly corrects a common mistake (`"primary_key": "file:line"` is wrong) and shows the right way (`dedup_key: true` on both columns).
- The custom strategies table (lines 94-100) is task-specific and directly actionable.

**What is missing or wrong**
- **"Not yet produced (deferred to v2.2.0)" (line 111):** The example has no worked output. For a skill that claims provenance, the code-review recipe is unproven. This undermines confidence in the generic task-agnostic claim — the only proven example is research.
- **The schema has no `primary_key` field:** Lines 49-66 define columns but omit the top-level `primary_key` field. The document says "Composite primary key: `file` AND `line` both have `dedup_key: true`" but the schema JSON doesn't include `"primary_key": null` or any indication that composite keys are intentional. An agent parsing the schema might assume `primary_key` is missing and default to the first column.
- **Missing `severity_order` in the schema:** Lines 72-78 show how to add a custom `severity_order` but the base schema (lines 49-66) doesn't declare the default order. If a model returns `critical` and the schema doesn't list it, the `most-severe` rule falls back to `["blocker", "major", "minor", "nit"]` and `critical` would be treated as an unknown value (algorithm undefined).

**What is unclear or ambiguous**
- **"Pre-commit hook" variation (line 106):** The document says "NOT currently supported as a built-in dispatch; requires custom runner." This is a feature request disguised as a variation. It should either be removed or moved to a "Future ideas" section so users don't expect it to work.

---

### 8. rules/examples/fact-check.md (Recipe)

**What works well**
- The consensus requirements (lines 103-108) are clear and conservative. The strict thresholds (all N agree for `true`, etc.) are appropriate for high-stakes fact-checking.
- The `majority-with-uncertain` explanation (lines 74-76, 109) is repeated for emphasis, which is good because this rule is counter-intuitive (any dissent blocks consensus).

**What is missing or wrong**
- **"Not yet produced (deferred to v2.2.0)" (line 113):** Same issue as code-review — no proven output. Two of three examples are unproven.
- **The schema omits `conflict_resolution` for `evidence` and `counter_evidence`:** Lines 66-69 only define rules for `verdict` and `confidence`. But the "Custom strategies" table (lines 93-99) recommends `all-collected` for `evidence` and `concatenate-all` for `counter_evidence`. These rules are not in the schema JSON — they would default to `longest-with-quote` (for `text` fields), which is wrong for fact-check.
- **Duplicate `sources` type definition:** Line 77 says "`sources: "url_list"` is now formally defined in the schema spec (was a v2.1.0 gap)" but `SKILL.md` already defines `url_list` in the supported types table (line 124). This reads like a changelog note that leaked into the example. It should be removed.

**What is unclear or ambiguous**
- **What is the verifier model in `thorough` mode?** The fact-check example doesn't mention `thorough` mode at all, even though fact-checking is the most obvious use case for cross-source verification. The research example (line 185) mentions it, but the fact-check recipe should explicitly recommend `thorough` and explain the cost/latency trade-off.
- **How are claims numbered?** The prompt example (lines 20-35) shows `1. [claim 1]`, `2. [claim 2]` but the schema uses `claim_id` as a string. If the model outputs `claim_id: "1"` and another outputs `claim_id: "Claim 1"`, dedup will fail. The example should instruct the user to use stable IDs (e.g., `FC-001`) rather than ordinal numbers.

---

## §2. Score the Skill on the 8-Dimension Rubric

| Dimension | Score | Justification |
|---|---|---|
| **Catalog of composable units** | **1** | The skill defines a machine-readable schema format (`--schema` JSON) with typed columns, dedup keys, and conflict rules. However, there is no centralized catalog of reusable schemas or rule packs — each run invents its own. The examples are reference recipes, not importable modules. |
| **Dynamic composition** | **1** | The skill supports a `mode` parameter (`quick` | `standard` | `thorough`) that changes pipeline depth, but this is a static switch, not a replanner. There is no runtime adaptation based on intermediate results (e.g., "if conflict rate > 30%, escalate to thorough"). The provenance note about "incremental consolidation (future enhancement)" confirms this gap. |
| **V-loop depth** | **1** | The `thorough` mode adds a per-item verifier call, which is a per-step rollup. However, there is no intent gate — the skill does not check whether the user's original intent is still satisfied before emitting the final artifact. The `standard` mode has end-only validation (conflict resolution). The `quick` mode skips even that. |
| **Enforcement** | **0** | The skill is entirely honor-system. There are no CI gates, IDE hooks, or delivery blockers. The `run-manifest.json` is an audit trail, not an enforcement mechanism. The skill cannot reject a downstream artifact based on consolidation quality. |
| **Parent/worker split** | **2** | The skill has an explicit orchestrator (the agent running the skill) and explicit workers (the N models dispatched). The split is clean: the orchestrator handles dedup, conflict resolution, and synthesis; workers are stateless and independent. The `task` tool and `opencode run` mechanisms both respect this split. |
| **Evidence model** | **1** | The `thorough` mode has a tiered sufficiency model (`evidence-ledger.md` with `verified` / `wrong` / `uncertain` verdicts) and `source_verified` flags. However, staleness is only mentioned in passing (`last_verified` date) with no automatic staleness threshold or warning. The `standard` and `quick` modes lack any evidence model beyond per-model citations. |
| **SE + DevOps unified** | **1** | The skill "covers both production task types" in the sense that the examples span research (SE) and code review (DevOps-y). However, the skill does not unify them — there is no schema or workflow that connects a research finding to a code-review finding. The task-type-specific custom strategies (lines 303-309 in `consolidation-rules.md`) are siloed. |
| **Team customization** | **0** | The skill does not support team process packs. There is no mechanism for a team to publish a shared alias map, a custom conflict-resolution rule, or a reusable schema template. Every team member must copy-paste from the examples. The only "customization" is forking the schema JSON per run. |

**Total: 7 / 16**

---

## §3. Top 5 Improvements (ranked by impact × effort)

### 1. Make `prefer-with-evidence-then-newer-then-strict` a fully formalized algorithm
- **Issue:** The most-used conflict resolution rule is the least formally defined.
- **Why it matters:** Without a precise definition, different agents implementing this skill will produce different consolidation results for the same inputs, destroying reproducibility.
- **Concrete change:** `rules/consolidation-rules.md`, lines 155-162. Replace the prose sketch with pseudocode:
  ```
  function preferWithEvidenceThenNewerThenStrict(values, evidenceQuotes, lastVerifiedDates):
    // Step 1: Quoted primary source
    quoted = values.filter(v => evidenceQuotes[v] contains inline quote matching /".+"/)
    if quoted.length == 1: return quoted[0]
    if quoted.length > 1: goto Step 2 with quoted subset
    // Step 2: Newer last_verified
    newest = values with max(lastVerifiedDates)
    if newest.length == 1: return newest[0]
    // Step 3: Outlier downgrade (threshold: 1 of N where N >= 4)
    if values.length >= 4 and frequency(minorityValue) == 1:
       return majorityValue
    // Step 4: Tie-break
    return value with longest evidence quote, then max(lastVerifiedDate)
  ```
- **Effort:** Medium
- **Impact:** High
- **Score:** 2.0

### 2. Add a runnable entry point (shell script or CLI wrapper)
- **Issue:** The skill is a spec, not a tool. Every user must hand-roll the `for` loop.
- **Why it matters:** The barrier to adoption is enormous. A user reading `/multi-ai-task "..."` in `SKILL.md` will search for a binary that doesn't exist.
- **Concrete change:** Create `skills/multi-ai-task/run.sh` (or a Node script) that implements Mechanism 2 with argument parsing:
  ```bash
  #!/usr/bin/env bash
  # run.sh --models m1,m2 --schema schema.json --mode standard --out ./out "prompt"
  ```
  Update `SKILL.md` line 56-58 to reference `./run.sh` instead of pseudo-CLI syntax.
- **Effort:** Medium
- **Impact:** High
- **Score:** 2.0

### 3. Unify phase numbering across all files
- **Issue:** `methodology.md` has Phases 1-4; `consolidation-rules.md` has Phases 2-5 with different meanings. The manifest tracks `phases_completed: [1,2,3,4]` so Phase 5 is invisible.
- **Why it matters:** Inconsistent terminology makes debugging and audit-trail interpretation unreliable. An agent reading `phases_completed: [1,2,3,4]` cannot tell if Phase 4 is "synthesis" or "conflict resolution."
- **Concrete change:** 
  - `rules/methodology.md`: Rename Phase 4 to "Phase 4 — Synthesis (conflict resolution + scoring + final output)"
  - `rules/consolidation-rules.md`: Rename "Phase 4 — RESOLVE CONFLICTS" to "Sub-phase 4a" and "Phase 5 — SCORE + SYNTHESIZE" to "Sub-phase 4b." 
  - `rules/output-schema.md`: Update `phases_completed` description to "list of phase numbers 1-4" and add `subphases_completed: ["4a", "4b"]` for granularity.
- **Effort:** Low
- **Impact:** Medium
- **Score:** 3.0

### 4. Add `rows_dropped` and `extraction_failures` to `run-manifest.json`
- **Issue:** Data loss during extraction (invalid rows, parse failures) is invisible. The manifest only counts successes.
- **Why it matters:** If a model returns 30 rows and 15 are dropped due to validation errors, the user sees `rows_per_model: {"m1": 15}` with no indication that half the data was lost. This undermines trust.
- **Concrete change:** `rules/output-schema.md`, lines 225-229. Add:
  ```json
  "extraction": {
    "rows_per_model": {"m1": 25, "m2": 30},
    "rows_dropped": {"m1": 5, "m2": 0},
    "drop_reasons": {"m1": [{"row_id": 3, "reason": "missing required field 'url'"}]},
    "extraction_failures": [{"model": "m3", "reason": "no table found", "fallback_used": "paragraph_split"}]
  }
  ```
- **Effort:** Low
- **Impact:** Medium
- **Score:** 3.0

### 5. Deprecate or remove unproven example placeholders
- **Issue:** Two of three examples (code-review, fact-check) say "Not yet produced (deferred to v2.2.0)." This undermines the skill's credibility.
- **Why it matters:** A user evaluating this skill sees that only research is proven and may conclude the "task-agnostic" claim is marketing, not engineering.
- **Concrete change:** 
  - `rules/examples/code-review.md`: Remove line 111 ("Not yet produced...") and replace with a synthetic worked example (even a 3-model, 5-finding mock run is better than "deferred"). 
  - `rules/examples/fact-check.md`: Same for line 113.
  - Alternatively, label them `[DRAFT — v2.2.0]` in the title and move them to a `drafts/` subdirectory so the main examples directory only contains proven recipes.
- **Effort:** Low
- **Impact:** Medium
- **Score:** 3.0

---

## §4. Open Questions

1. **What is the intended runtime environment?** The skill references `opencode-ai run`, `task` tool, and direct HTTP APIs, but never says "this skill is designed for OpenCode agents" or "this skill works in any LLM harness." If it's OpenCode-only, the Mechanism 4 (direct HTTP) is unnecessary bloat. If it's harness-agnostic, Mechanism 1 is OpenCode-specific bloat. Clarifying the target runtime would simplify the dispatch section significantly.

2. **How large can N realistically be?** The skill says "4-6 models" is recommended and mentions 8-10 as a variation, but the consolidation algorithm is O(N × items) with no parallelism. At N=20, the conflict resolution step could be a bottleneck. Is there a hard limit? Should the skill shard the consolidation?

3. **What is the governance model for schema/rule evolution?** If a team invents a new conflict-resolution rule (e.g., `weighted-majority` based on model confidence scores), how do they contribute it back? The skill has no extension mechanism — the rule library is closed. Is this intentional (stable core) or an oversight?

4. **How does the skill handle model API cost?** The skill mentions "cost of N× compute is acceptable" as a when-to-use criterion, but there is no cost tracking in `run-manifest.json`. For a run with 6 models × $0.05/request, the total is trivial; for 6 models × 10K tokens × $0.03/1K, it's $1.80. At scale (100 runs/month), this matters. Should the manifest include estimated cost per model?

5. **What is the relationship to the `deep-research` skill?** `SKILL.md` line 284 says "For a deep 8-phase research methodology... use Claude's `deep-research` skill if available." Does `multi-ai-task` replace `deep-research`, complement it, or subsume it? If a user has both, which should they use for research? The answer seems to be "use `deep-research` for the per-model prompt, `multi-ai-task` for the orchestration" — but this is never stated explicitly.

---

## §5. Confidence

- **Overall confidence:** **medium**
- **What would change my assessment:**
  - **High confidence:** If I could see the actual implementation (the `run.sh` or equivalent) and run it against a test prompt to verify that the 4-phase pipeline produces the claimed outputs (`consolidated.md`, `conflicts.md`, `run-manifest.json`) with the correct schema injection, dedup, and conflict resolution. Right now, the skill is a well-written spec with no executable artifact.
  - **Low confidence:** If I discovered that the proven run (2026-06-27) was manually orchestrated and the "consolidation" was actually a human-authored merge. The provenance section is detailed but provides no machine-readable trace (e.g., a `run-manifest.json` from that run) to verify automation.

The skill is a **strong specification with weak provenance**. The research example is proven; the generic task-agnostic claim is not. The consolidation rules are the deepest and most valuable part of the skill, but they are undermined by informal definitions (e.g., `prefer-with-evidence-then-newer-then-strict`) and inconsistent phase numbering. With a runnable entry point, formalized algorithms, and at least one proven non-research example, this would be an excellent skill. As it stands, it is a **promising v2.1.0 spec that needs v2.2.0 hardening.**
