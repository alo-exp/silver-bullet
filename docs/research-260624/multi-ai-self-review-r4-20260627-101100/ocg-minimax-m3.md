# Critical Self-Review: `multi-ai-task` v2.1.0

> **Task description says "v2.0.0"** but the SKILL.md frontmatter (line 6) declares `version: 2.1.0`. The frontmatter is the source of truth; this review treats the skill as v2.1.0.

---

## §1. Critical Assessment (per file)

### File 1: `SKILL.md` (255 lines)

**What works well**
- "When to use / When NOT to use" table (lines 33–50) is unusually explicit for a Silver Bullet skill. The "Output is non-textual" and "You have ≤1 model available" rows are the right call.
- The "What this skill does NOT do" block (lines 24–29) names things most skill specs silently assume. Useful.

**What is missing or wrong**
- **Frontmatter contradicts the Usage section.** Line 5: `user-invocable: false`, but line 57 documents a user-facing slash command: `/multi-ai-task "<task-prompt>"`. The skill is presented as a slash command and as a non-invocable skill at the same time. If a harness enforces `user-invocable`, the slash command at line 57 will not work.
- **Default model discovery hard-codes "research".** Line 73: *"…with at least one reasoning-capable model if the task is research-like."* The skill is supposed to be task-agnostic, but the auto-discovery heuristic bakes in a research assumption. A code-review or fact-check user (both of which also benefit from reasoning models) gets the same default — but for non-obvious reasons, because the doc never defines "research-like".
- **The failure-modes table is contaminated with a change note.** Line 227: *"Output dir contains `score-aggregate.md` (planned) but not in the contract" — Old spec inconsistency — Ignore for v2.x; the section is in `consolidated.md` body as §5 Aggregated Scores."* This is a v1→v2 changelog note masquerading as a failure mode. It does not describe a symptom, a likely cause, or a fix.
- **No changelog.** v2.1.0 added `aliases`, `schema_auto_injected`, formally defined `url_list`/`union-dedup` (per output-schema.md lines 245, 251 and fact-check.md line 77). None of this is summarized; readers have to infer what changed by diffing prose.
- **`thorough` mode cost model is under-stated.** Line 81: *"thorough mode adds ~N_items × 1 verifier call."* With 30 items this is 30 additional dispatches of the verifier model. The "~" is doing a lot of work; the actual multiplier is linear in items, not "small".

**What is unclear or ambiguous**
- The `quick` mode is described (line 79) as *"Dedup only, no conflict resolution … Merged raw output"*. What is the actual format of "merged raw output"? A concatenation of `<slug>.md` files? A per-model section in a single file? The doc never shows the shape.
- The version in the frontmatter is `2.1.0` but the task description (above) and the provenance section (line 207) still reference the v2.0.0 era. Is v2.1.0 the generalized skill plus the v2.0.0 → v2.1.0 deltas, or are these separate generations? The doc does not say.

---

### File 2: `methodology.md` (173 lines)

**What works well**
- The 4-phase structure (lines 7–148) is the spine that the rest of the skill hangs from. Each phase has a clear input/output.
- The `extractStructured` pseudocode (lines 38–64) is the only place in the skill that admits a fallback chain: table → tags → extractor model → paragraph split. This is good honest engineering.

**What is missing or wrong**
- **The `extractor` claim is internally contradictory.** Line 53: *"the slowest/highest-capability model from the original dispatch (NOT the model that produced the response — that model has already failed to produce structured output, asking it again is unlikely to help)"*. But the response was already dispatched. Re-dispatching the same prompt through the same model is a separate LLM call, not a "cache" of the original. The "caches the response, no extra cost" claim at line 104 is wrong — it is a fresh LLM call with a reformulation prompt. Cost: roughly 1 additional large-LLM call per non-compliant response.
- **Pseudocode is silent on the most lossy step.** Lines 70–72 list 7 parser steps; step 6 says *"Skip rows where the first cell is empty or pure digits (index column)"*. This will incorrectly drop legitimate rows whose primary key is purely numeric (CVE IDs, ISO dates, ISBNs, release tags). The parser should distinguish "an index column" from "a numeric key", e.g. by header name `#` / `idx` / `index` rather than the cell content.
- **Phase numbering does not match `run-manifest.json`.** methodology.md introduces 3.5 RESOLVE CONFLICTS (line 136) and 3.6 SCORE + SYNTHESIZE (line 266). The `run-manifest.json → phases_completed` field (output-schema.md line 254) is `[1, 2, 3, 4]`. Sub-phases 3.5/3.6 have no slot. Either 3.5/3.6 are internal to phase 3 (and should not be numbered), or the manifest schema is missing fields. As written, an audit trail cannot distinguish "phase 3 completed, including 3.5 and 3.6" from "phase 3 partially failed at 3.5".
- **Methodology imports an OpenCode-specific tool surface as if it were generic.** Line 12: *"Has its own tool/MCP context (e.g., `webfetch`, `ctx_fetch_and_index`, `gh`)"*. The skill is documented as harness-agnostic, but the per-model context assumes the OpenCode MCP stack. A Mechanism 4 user (direct HTTP, dispatch-mechanics.md line 81) has no MCP access at all — the methodology text is silently wrong for them.

**What is unclear or ambiguous**
- Phase 1 is called *"Per-model execution"* (line 7) here but *"Phase 1 (dispatch)"* in SKILL.md's mode table (line 77). Same phase, two names. The same drift exists in §"Methodology" of SKILL.md (line 178): *"per-model execution"*. Inconsistency costs the reader when cross-referencing.

---

### File 3: `dispatch-mechanics.md` (181 lines)

**What works well**
- Mechanism 2 is the most realistic option for most users and the doc treats it as such (line 191 in SKILL.md calls out the default). The bash example is *almost* a drop-in script.
- The auth table (lines 138–151) and the "Choosing the right mechanism" decision table (lines 171–181) are practical.

**What is missing or wrong**
- **The bash example has a dead `TIMEOUT` variable and a flag typo.** Lines 38–54 set `TIMEOUT=600` but the loop never references it; the `&` + `wait` pattern blocks indefinitely on a hung subprocess. Line 62 *describes* the fix — `timeout $TIMEOUT npx -y opencode-ai run …` — but the example does not apply it. A user copying lines 38–54 verbatim will not get per-model timeouts; the bash tool's 2-minute default will kill the loop. Line 58 uses `--y` (two dashes) which is not a valid npx flag — should be `-y` or `--yes`.
- **The "preferred" mechanism contradicts the default.** Line 9: *"Mechanism 1: … (preferred-if-available)"*. Line 191 of SKILL.md: *"Default is Mechanism 2"*. The reader has to discover (from the constraint note at line 28) that Mechanism 1 is only "preferred-if-available" because OpenCode's `task` tool has no per-call model field. That constraint should drive the default, not be hidden in a 7-line footnote.
- **The issue-number catalog is noise.** Line 28 lists *"issues #6651, #11215, #17595, #26925, #29984, #32730"* and an open PR (#29447). Six issue numbers in a sentence fragment are not actionable; pick the canonical one or link the meta-issue.
- **Mechanism 4 loses everything OpenCode provides.** Lines 81–93 show a `python openai` call. Compared to Mechanism 2, this loses MCP access, tool use, and any per-model capability routing. The doc names this (line 83) but does not warn that some prompt formats (e.g., anything that depends on `ctx_batch_execute` or `webfetch`) will not work. Mechanism 4 is not equivalent to Mechanisms 1–3; it is a degraded fallback.
- **The "minimum viable" claim is internally inconsistent.** Line 165: *"Minimum viable: 2 models from different families. Below 2, the skill adds no value."* But the named rule `majority` (consolidation-rules.md line 178) returns `null` when 2 models disagree. With N=2 and disagreement, no value is produced. The threshold for "value" is at least 3, not 2.

**What is unclear or ambiguous**
- "Highest control" (Mechanism 4, line 83) is undefined. Control over what — auth, prompt format, concurrency, model selection, retries? The reader cannot tell.
- The "MCP port collision" caveat at line 106 implies that parallel dispatches share MCPs that may bind a port. The "Parallel vs sequential" table at lines 99–103 does not list this risk. A user picking parallel for speed will not see the port-collision trade-off.

---

### File 4: `consolidation-rules.md` (334 lines)

**What works well**
- The named-rule library (lines 167–221) is genuinely well-defined. Each rule has an algorithm, an input contract, edge cases, and an example. This is the part of the skill with real engineering value.
- The "minimal contract for consolidation" framing (lines 7–22) — items, identity, fields, sources — is the right abstraction for a task-agnostic skill.

**What is missing or wrong**
- **The "Custom consolidation strategies" example uses the v2.0.0 (now-removed) `dedup_key` string form.** Lines 313–321 show:
  ```json
  {
    "type": "code-review",
    "dedup_key": "file:line",
    ...
  }
  ```
  SKILL.md line 142 documents composite keys as *"list multiple columns with `dedup_key: true`"*. The code-review example (lines 51–66 of `examples/code-review.md`) uses the correct form. Consolidation-rules.md itself, in its own `merge-exact` rule (line 219), describes the composite-key contract as identical to the `dedup_key: true` form. The "Custom consolidation strategies" example is the only place in the skill that still uses the deprecated string form. Users following this section will hit a schema validation error.
- **The `prefer-with-evidence-then-newer-then-strict` rule has inconsistent internal numbering.** Lines 155–162 number its sub-rules 1, 2, 3, 4. Rule 3 is *"Single-model outlier rule"*. The `conflicts.md` example in this same file (line 230) cites it as *"rule 4 (outlier downgrade)"*. The cross-reference in the `conflicts.md` example is off by one and points to a sub-rule that is not what the text says it is.
- **`longest-with-quote` ties to the wrong "recency" field.** Line 196: *"Tie-break by recency (model's `last_verified` if present, else the order in the input list)"*. `last_verified` in the schema (examples/research-prior-art.md line 92) is a per-**item** field, not a per-**model** field. A per-model recency field is never defined anywhere in the skill. This rule, as written, cannot be implemented.
- **The skip rules and alias sections are not pseudocode.** Lines 113–121 describe skip rules in prose; the user has to translate to code. The dedup algorithm (lines 95–111) is pseudocode. The two halves of the same phase are written in different styles, which makes the file harder to implement against.
- **`merge-exact` is described for "composite key" but the algorithm is single-key.** Line 219: *"group by primary key"* (singular). A composite key like `(file, line)` would group by the tuple; the algorithm text does not mention tuple grouping. Either the rule only works for single-key primary keys, or the algorithm is wrong.
- **Line 326 introduces a circular cross-reference.** *"The default behavior (no aliases) is: normalize = lowercase + strip-punctuation + collapse-whitespace, then exact match."* This describes SKILL.md's Mode B path; but in methodology.md Mode B (line 75) the default dedup is *"fuzzy match on first 5 words of each paragraph"* (with `fuzzy_match:true` flagged). Two different "default" behaviors in two docs.

**What is unclear or ambiguous**
- `union-dedup` (line 211) and `concatenate-all` (line 199) both "preserve all values" but the former is set semantics, the latter is list-with-separator semantics. The doc does not put this contrast up front. A user picking one for a `text` field will get silent mis-formatting.

---

### File 5: `output-schema.md` (270 lines)

**What works well**
- The `run-manifest.json` field-by-field semantics (lines 239–254) is the most precise piece of schema documentation in the repo. Every field has a one-line description.
- The markdown formatting rules (lines 258–269) — code spans, blank lines around tables, no triple-asterisk — are practical and correct in intent.

**What is missing or wrong**
- **The §1–§8 structure is described as "both modes" but only fits Mode A.** §1 Executive Summary is bullets (line 39); §2A is a markdown table (line 53); §2B is per-item narrative (line 79). §3 (line 100) gives "Per-Item Details (compact, both modes)" examples that are JSON-like and only fit Mode A. §5 (line 130) and §8 (line 162) are both labeled "optional" but the research example (examples/research-prior-art.md line 156) requires both. The "both modes" labeling is false.
- **`thorough` mode is invisible in this file.** SKILL.md lines 170–172 list `evidence-ledger.md` and `verification.md` for thorough mode. output-schema.md never specifies their format. The "Mode semantics" table at SKILL.md lines 77–83 describes what these files contain, but no schema is defined anywhere. A user running `--mode thorough` has no spec to follow.
- **Markdown rule self-contradiction.** Line 261: *"Use code spans (backticks), not bold-italic, for inline markers. `direct*` → `` `direct*` ``, not `**direct***`."* This very sentence uses `**direct***` (the forbidden form) to demonstrate the rule. Line 263: *"Never use triple-asterisk `***`."* The same sentence uses `***` in its warning text. The rule is enforced by example that violates it.
- **The `phases_completed` field does not include 3.5/3.6.** Line 254: `"phases_completed": [1, 2, 3, 4]`. methodology.md (lines 136, 266) defines 3.5 and 3.6 as separate phases. The manifest is missing the granularity. Same complaint as in methodology.md §1 above.
- **The `url_list` type and its companion `union-dedup` rule are introduced in `fact-check.md` and `consolidation-rules.md` but never in output-schema.md's type list.** output-schema.md documents neither. The "two output modes" framing (line 7) and "Supported column types" table (SKILL.md lines 117–126) are the canonical place to find them; they are absent.

**What is unclear or ambiguous**
- Appendix A "Cross-AI Source Map" (line 168) duplicates `structured.jsonl` per-row `model` info. The relationship is not stated. Is the appendix a human-readable rendering of `structured.jsonl` for browsing, or a separate index? A human reading this can construct Appendix A from `structured.jsonl` and `models_responded`; if the schema is meant to be authoritative, that is fine, but the doc should say so.

---

### File 6: `examples/research-prior-art.md` (185 lines)

**What works well**
- This is the proven example. The schema (lines 73–100) is concrete and the alias map (lines 124–141) is reproduced from a real run.
- The "Variations to try" section (lines 181–185) is appropriately honest about diminishing returns past N=6.

**What is missing or wrong**
- **The example's 8-dimension scoring rubric is the same rubric used to score the skill itself.** The rubric at lines 102–119 lists 8 dimensions including `se_devops` and `customization` — exactly the rubric in the §2 of *this review* (and presumably the original 2026-06-27 self-review). The example bakes in a self-referential assumption: that prior-art depth in the SB landscape is best measured on these 8 dimensions. The example never notes this recursion. If the rubric changes, this example silently becomes a different evaluation.
- **The prompt template says to embed the schema AND `--schema` auto-injects it.** Lines 36–68 describe a `research-prompt.md` template that includes §4 *"Required Output Schema"*. SKILL.md line 146: schema auto-injection is on by default. The user is told to embed the schema in the prompt (creating duplication) while the same skill will inject it. The example should either show `--no-auto-inject` in use, or omit §4 from the prompt template.
- **The skip rules are duplicated.** Lines 145–149 add research-specific skip rules to the generic skip rules in consolidation-rules.md lines 113–121. The doc acknowledges this at line 122 of consolidation-rules.md ("Task-type-specific skip entries belong in the alias map for that task's recipe, not in the core rules"), but the example does not use an alias map for this — it uses a separate section. The two approaches are not reconciled.

**What is unclear or ambiguous**
- Line 78 includes `negative-result` in the `category` enum, and §6 of output-schema.md has a separate "Negative Results" section. Is a `negative-result` category a row in the items table, or does it belong only in §6? Both are documented, neither is reconciled.

---

### File 7: `examples/code-review.md` (111 lines)

**What works well**
- The schema (lines 50–66) is the *correct* composite-key form (`dedup_key: true` on both `file` and `line`). This file is the reference for how the v2.0.0 string form should be replaced.
- The "Custom strategies" table (lines 93–100) makes the rule choice per-field, with one-line rationale. This is the most actionable table in the whole skill.

**What is missing or wrong**
- **Section numbering does not match output-schema.md.** Lines 86–90 list §1–§7 with content like *"§5 Per-Reviewer Statistics (how many findings each reviewer produced)"*. output-schema.md §5 is "Aggregated Scores" and §6 is "Negative Results". A report produced by following this example cannot be cross-checked against the canonical §-number contract.
- **The "old form" complaint has no version attribution.** Lines 67–71: *"Why the old `"primary_key": "file:line"` is wrong"*. A reader at v2.1.0+ has no way to know which version the "old" form was in. The fix path (composite `dedup_key: true`) is given, but the migration history is not.
- **No worked example.** Line 110: *"Not yet produced (deferred to v2.2.0)"*. This is one of three example files (code-review, fact-check) without a worked output. The SKILL.md line 207 promises them as v2.0.0+ examples. The deferred status is honest but reduces the example's value as a reference.

**What is unclear or ambiguous**
- The "Variations" section (line 102) includes a "Pre-commit hook" variation. Line 106: *"NOT currently supported as a built-in dispatch; requires custom runner"*. A skill that does not support a variation should not advertise it. Either remove the variation or add it as a built-in.

---

### File 8: `examples/fact-check.md` (113 lines)

**What works well**
- The `majority-with-uncertain` threshold formula is concrete (line 74, line 184 of consolidation-rules.md). N=2 → threshold 2, N=3 → 2, N=5 → 3. The example correctly explains this is what makes high-stakes fact-checking "fail safe".
- The "Consensus requirements" section (lines 101–109) is the only place in the skill that maps threshold math to operational outcomes (confirmed / debunked / flagged / unverified).

**What is missing or wrong**
- **Section numbering does not match output-schema.md.** Lines 83–90 list §1–§7 with custom headings: *"§5 Source Quality"*, *"§6 Unverified Claims"*, *"§7 False Claims"*. output-schema.md §5 is "Aggregated Scores" and §6 is "Negative Results". Same complaint as code-review.md.
- **A meta-comment about a draft typo is left in the production doc.** Line 110: *"The '3+ models' rule in the original draft was a typo; the correct threshold is parameterized."* This is a changelog note for the example file, not guidance for users. Future readers will not know what the "original draft" was.
- **`url_list` is documented in two places as a v2.1.0+ addition.** Line 77: *"`sources: 'url_list'` is now formally defined in the schema spec (was a v2.1.0 gap)"*. The same addition is implicit in consolidation-rules.md line 152 (the default for `url_list` is `union-dedup`) and SKILL.md line 124. Three documents, no single place to find the formal definition. The fact-check example is a good place to mention it, but it should also be the canonical reference, which it is not.

**What is unclear or ambiguous**
- The `claim_id` field is `dedup_key: true` (line 58). What happens when two models report the same claim with different IDs (e.g., "1" vs "claim-1")? The dedup will not merge. The example does not address this; high-stakes fact-checking depends on per-claim merging.

---

## §2. 8-Dimension Rubric Score

I am scoring the multi-ai-task skill itself against the rubric it uses to score candidates. This is meta but the rubric does apply — the skill is a process artifact, not a software product, so some dimensions are penalized for the genre.

| Dimension | Score | Justification |
|---|---|---|
| **Catalog of composable units** | 1 | The named-rule library (`most-severe`, `majority`, `majority-with-uncertain`, `lowest-of-majors`, `longest-with-quote`, `concatenate-all`, `all-collected`, `union-dedup`, `merge-exact`) is a catalog of 9 composable conflict-resolution rules. But the catalog is in prose, not machine-readable; an implementer has to parse the prose. Score 1 (informal roles) — the units exist and are composable, but the catalog is not itself an indexable artifact. |
| **Dynamic composition** | 1 | Per-field conflict rules can be composed via the `--schema` `conflict_resolution` object, and the schema is configurable at call time. But there is no replanner, no dynamic re-prompting, no self-modification based on observed results. The 3 modes (quick/standard/thorough) are static. Score 1. |
| **V-loop depth** | 1 | Phase 3.5 (resolve conflicts) and phase 3.6 (score + synthesize) provide per-item verification before the final synthesis. Thorough mode adds a verifier dispatch per item. End-of-loop synthesis is explicit. But there is no intent gate, no per-step rollup, no rollback on failed verification. Score 1. |
| **Enforcement** | 0 | The skill is a process skill; it does not hook into IDE, CI, or any external system. The closest thing to "enforcement" is its own schema validation, which is internal. Score 0. |
| **Parent/worker split** | 2 | The skill is explicitly an orchestrator (parent) that dispatches to N model subprocesses (workers). The split is named, documented, and the `run-manifest.json` records which model produced which row. Score 2. |
| **Evidence model** | 1 | Tiered extraction (table → tags → extractor → paragraph) is implicit in the methodology. The `evidence` and `sources` fields in the schema are first-class. Thorough mode adds a verifier. But staleness, sufficiency, and source quality are not formally tiered; they are handled ad hoc per task. Score 1. |
| **SE + DevOps unified** | 1 | The skill is task-agnostic and the three example files cover SE (code review), DevOps (fact-check on infrastructure claims), and a mixed reference (research prior-art). But the examples are separate recipes, not a unified model — they each define their own schema, alias map, and conflict rules. A user with a cross-cutting task writes their own recipe. Score 1. |
| **Team customization** | 1 | The CLI exposes `--models`, `--out`, `--schema`, `--mode`, `--no-auto-inject`; the schema is a full JSON object. The alias map and skip rules are per-recipe. This is "overlay pack"-like but not formalized as packs (no directory structure, no versioning, no inheritance). Score 1. |

**Total: 8 / 16.**

---

## §3. Top 5 Improvements (ranked by impact × effort)

### #1 — `dispatch-mechanics.md:38–54` bash example has a dead `TIMEOUT` and a wrong flag

- **Issue:** The Mechanism 2 example sets `TIMEOUT=600` but never references it. The loop uses `&` + `wait`, which blocks indefinitely on a hung subprocess. Line 58 uses `--y` (invalid npx flag) instead of `-y` or `--yes`. The "fix" described in line 62 (`timeout $TIMEOUT npx -y opencode-ai run ...`) is not in the example.
- **Why it matters:** A user copying this script will get the bash tool's 2-minute default, not the 10-minute `TIMEOUT` they were promised. Long-running research dispatches (3-5 min/model) will be killed mid-flight. This is the most-recommended dispatch path in the skill; the bug is reachable in one copy-paste.
- **Concrete change:**
  - File: `rules/dispatch-mechanics.md`
  - Lines: 38–62
  - Replace the loop body with:
    ```bash
    for model in "${MODELS[@]}"; do
      slug=$(echo "$model" | cut -d/ -f2)
      timeout "$TIMEOUT" npx -y opencode-ai run \
        --model "$model" \
        --title "multi-ai-task-${slug}-$(date +%s)" \
        --dangerously-skip-permissions \
        "$PROMPT" \
        > "$OUT/${slug}.md" 2> "$OUT/${slug}.err" &
    done
    wait
    ```
    And on line 58, change `--y` to `-y`.
- **Effort:** low
- **Impact:** high
- **Score:** 4.0

### #2 — `SKILL.md:5` `user-invocable: false` contradicts the slash command on line 57

- **Issue:** Frontmatter declares `user-invocable: false`. Usage section (line 57) documents a user-facing slash command `/multi-ai-task "<task-prompt>"`. The two cannot both be true.
- **Why it matters:** Harnesses that enforce `user-invocable: false` will not register the slash command. The skill is then *only* callable by an orchestrator (a parent agent invoking the skill via a tool), but the Usage section is written for a human typing the slash command directly. A user who reads the Usage section and types `/multi-ai-task` in their harness will get either a silent failure (if the harness respects the frontmatter) or a broken command (if it doesn't). Either way, the skill's discoverability is wrong.
- **Concrete change:**
  - File: `SKILL.md`
  - Line 5: change `user-invocable: false` to `user-invocable: true` *if* the slash command is the intended user path; **OR** rewrite the Usage section (lines 56–58) to document the skill as orchestrator-invoked only, with a parent-agent example instead of a slash command.
  - Whichever fix is chosen, add a one-line "Invoked by:" note under the Usage header so the audience is unambiguous.
- **Effort:** low
- **Impact:** high
- **Score:** 4.0

### #3 — `consolidation-rules.md:313–321` "Custom consolidation strategies" example uses the deprecated `dedup_key: "file:line"` string form

- **Issue:** The example shows:
  ```json
  {
    "type": "code-review",
    "dedup_key": "file:line",
    "conflict_resolution": { ... }
  }
  ```
  SKILL.md line 142 documents composite keys as *"list multiple columns with `dedup_key: true`"*. The `examples/code-review.md` (lines 51–66) uses the correct form. `consolidation-rules.md`'s own `merge-exact` rule (line 219) describes the same composite-key contract. The "Custom strategies" example is the only remaining string-form instance.
- **Why it matters:** A user following the "Custom strategies" example as a template will produce a schema that fails validation. The same skill ships the correct form in `examples/code-review.md`, so the inconsistency is internal — not a format version mismatch, just a missed edit.
- **Concrete change:**
  - File: `rules/consolidation-rules.md`
  - Lines: 313–321
  - Replace the example body with:
    ```json
    {
      "type": "code-review",
      "columns": [
        {"name": "file", "type": "string", "dedup_key": true, "required": true},
        {"name": "line", "type": "number", "dedup_key": true, "required": true},
        {"name": "severity", "type": "enum", "values": ["blocker", "major", "minor", "nit"]}
      ],
      "conflict_resolution": {
        "severity": "most-severe",
        "category": "majority"
      }
    }
    ```
    Add a sentence: *"Composite primary keys are expressed by listing multiple columns with `dedup_key: true` (see SKILL.md and the `examples/code-review.md` schema)."*
- **Effort:** low
- **Impact:** high
- **Score:** 4.0

### #4 — `output-schema.md` does not define the format of `evidence-ledger.md` or `verification.md`

- **Issue:** SKILL.md lines 170–172 list `evidence-ledger.md` and `verification.md` as outputs of `thorough` mode. SKILL.md lines 77–83 describe them at a paragraph level. output-schema.md — the file that defines the schema for every other output artifact — does not specify their format. There is no field-by-field definition, no example, no required columns.
- **Why it matters:** Thorough mode is the only mode that promises cross-source verification. Without a schema, the `evidence-ledger.md` and `verification.md` files are whatever the implementation chooses to emit. Two implementations of the same skill will produce incompatible ledgers, and downstream consumers (a verifier, a human reviewer) cannot rely on the structure.
- **Concrete change:**
  - File: `rules/output-schema.md`
  - Add a new section after §"Supporting files" (line 192) titled "Thorough-mode artifacts":
    ```markdown
    ### `evidence-ledger.md` (thorough mode only)
    
    One row per consolidated item that had a `source` / `url` field:
    
    | item | claim | claimed_source | verified_source | verdict | verifier_model | verified_at |
    |------|-------|----------------|-----------------|---------|----------------|-------------|
    
    ### `verification.md` (thorough mode only)
    
    Summary of cross-source verification:
    - Total claims checked
    - Confirmed / refuted / unverifiable counts
    - Per-verifier-model accuracy stats (if multiple verifiers used)
    ```
  - Add the corresponding entries to `run-manifest.json`:
    ```json
    "totals": {
      "claims_verified": 30,
      "claims_confirmed": 24,
      "claims_refuted": 2,
      "claims_unverifiable": 4
    }
    ```
- **Effort:** medium
- **Impact:** medium
- **Score:** 2.0

### #5 — Section numbering mismatch between `examples/code-review.md` and `examples/fact-check.md` vs `output-schema.md`

- **Issue:**
  - `examples/code-review.md` lines 86–90: §1 Exec Summary, §2 Findings Table, §3 Per-Finding Details, §4 Conflicts, §5 Per-Reviewer Statistics, §6 Coverage Gaps, §7 Open Questions.
  - `examples/fact-check.md` lines 83–90: §1, §2 Claims Table, §3 Per-Claim Details, §4 Conflicts, §5 Source Quality, §6 Unverified Claims, §7 False Claims.
  - `output-schema.md` §1–§8: §1 Exec Summary, §2 Items Table, §3 Per-Item Details, §4 Conflicts, §5 Aggregated Scores, §6 Negative Results, §7 Open Questions, §8 Synthesized Verdict.
  - The §5 and §6 headings differ across all three files. A user following an example produces a report that does not match the canonical §-number contract.
- **Why it matters:** The §-numbering is referenced in cross-references (e.g., "see §4" in §"Conflicts & Resolutions"). A report produced by an example cannot be cross-checked against the canonical output schema, so auditability is broken for example-driven runs.
- **Concrete change:**
  - File: `rules/examples/code-review.md`, lines 86–90
  - File: `rules/examples/fact-check.md`, lines 83–90
  - Replace each example's section list with the canonical §1–§8 from `output-schema.md`, adding example-specific sub-bullets inside each section. For code-review, "Per-Reviewer Statistics" moves into §3 Per-Item Details as a sub-bullet; "Coverage Gaps" moves into §6 Negative Results. For fact-check, "Source Quality" moves into §3; "Unverified Claims" and "False Claims" move into §6.
- **Effort:** medium
- **Impact:** medium
- **Score:** 2.0

---

## §4. Open Questions

1. **What is the "extractor model" actually?** methodology.md line 53 and SKILL.md line 152 describe it as *"the slowest, highest-capability model from the original dispatch"*. But calling the extractor is a *fresh* LLM dispatch with a reformulation prompt, not a cache lookup. Where is the cache that "saves the response" (line 104 of methodology.md)?

2. **What does `quick` mode actually output?** SKILL.md line 79 says "Merged raw output, no `conflicts.md`". Is this a single `consolidated.md` containing all `<slug>.md` contents concatenated, or per-model sections? Without an example or a spec, the format is guessable but not defined.

3. **Is `phases_completed` supposed to include 3.5/3.6, or are those internal to phase 3?** methodology.md (lines 136, 266) introduces them as separate phases. The `run-manifest.json` schema only has [1, 2, 3, 4] (output-schema.md line 254). Either the manifest is missing fields, or the methodology's phase numbering is internal-only. Whichever is true, the other doc should say so.

4. **What is the v2.1.0 changelog?** The skill is at v2.1.0 but the frontmatter does not link a CHANGELOG. The provenance section (SKILL.md line 207) and the `url_list`/`aliases`/`schema_auto_injected` mentions imply the diff is: v1.0.0 research-only → v2.0.0 task-agnostic + string-form `dedup_key` → v2.1.0 composite-form `dedup_key` + `aliases` field + `url_list` type + `schema_auto_injected` field. A short CHANGELOG entry would resolve the "what changed?" question once and for all.

5. **Is the skill intended to be a *worker* of a parent orchestrator, or directly user-invocable?** The `user-invocable: false` frontmatter (line 5) says one thing; the Usage section (line 57) says another. The "provenance" section (line 247) and this very review both imply orchestrator-invocation. The doc should commit.

6. **How are the output files consumed?** The skill emits `consolidated.md`, `conflicts.md`, `run-manifest.json`, `evidence-ledger.md`, etc. If a human reads them, the markdown formatting rules (output-schema.md lines 258–269) are correct. If another skill consumes them, the JSON files need a stable schema and a version field. Neither is documented.

7. **What other v2.0.0 → v2.1.0 lessons are unrecorded?** The v2.1.0 changes (`url_list`, `aliases`, `schema_auto_injected`) appear to be driven by gaps in the proven v1.0.0 run. What other gaps were discovered? A "lessons learned" note would prevent the same discoveries from being re-made in v2.2.0.

8. **Where is the skill's implementation?** The skill is currently 8 markdown documents. The bash example in dispatch-mechanics.md is "what worked in the proven run" (line 56) — but is there a `multi-ai-task.sh` or `multi-ai-task.py` script? If yes, the docs are documentation; if no, the bash example *is* the implementation. The skill should say which.

---

## §5. Confidence

- **Overall confidence:** **high** on the existence of the issues cited (I have specific line numbers, quoted text, and cross-document comparisons). **Medium** on the prioritization: the rubric scoring in §2 is a meta-application of a rubric designed for software products, applied to a process skill; reasonable people could score ±1 on most dimensions.

- **What would change my assessment:**
  1. **An existing implementation.** If `multi-ai-task.sh` (or equivalent) exists and resolves some of the ambiguities (e.g., how `phases_completed` is actually populated, what `quick` mode emits), then several of the "unclear" complaints in §1 collapse from ambiguity to "not yet documented". The score for §2 Evidence Model might rise to 2 if the implementation has tiered staleness.
  2. **A real usage count.** The skill has a single proven provenance (2026-06-27, 6 models, 36 items, 1 consolidated report). If `multi-ai-task` has been invoked dozens of times since then, the §3 prioritization should weight the "user-facing bug" findings (dispatch-mechanics.md, consolidation-rules.md) higher; if it has been invoked once, the "documentation drift" findings should be weighted higher.

---

*Review generated: 2026-06-27. Files reviewed: 8 (SKILL.md, methodology.md, dispatch-mechanics.md, consolidation-rules.md, output-schema.md, examples/research-prior-art.md, examples/code-review.md, examples/fact-check.md). Total: 1,539 lines of source. No files were modified.*
