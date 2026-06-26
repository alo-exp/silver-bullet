Now let me gather additional context about the skill's integration and the prior-art run it references.
Now I have enough context. Let me check one final thing — whether the rules mentioned in examples are actually defined in the core rules.
Here is the critical self-review.

---

# Critical Self-Review: `multi-ai-task` v2.0.0

## §1. Critical Assessment

### SKILL.md

**What works well:**
- Clean when-to-use/when-not-to-use table with concrete criteria (cost, latency, diversity signal).
- The `--schema` parameter documentation with Mode A example is the most implementable section of the entire skill.

**What is missing or wrong:**
1. **The skill claims to be "task-agnostic" but the schema example is research-specific.** The Mode A schema example (`SKILL.md:80-95`) uses `category` with values `["direct","adjacent","tangential","negative-result"]` and `evidence` with `max_words: 50` — these are prior-art research concepts, not generic. A user trying to use this for code review or fact-checking sees a research schema and has to mentally abstract. The first example a user encounters should be generic or there should be a rotated example.

2. **"LLM-assisted extraction" (Mode B) is hand-waved.** `SKILL.md:100-103` says "Ask each model to wrap its response in `<structured></structured>` tags" — but this is a prompt instruction, not a mechanism. How does the skill enforce this? What if the model ignores the instruction? The fallback ("Ask a designated extractor model") adds another LLM call with undefined behavior. The final fallback ("fuzzy match on first 5 words of each paragraph") is extremely brittle — the first 5 words of a paragraph are rarely a stable identifier.

3. **No error handling for `--schema` validation.** If the user passes malformed JSON or a schema with unknown `type` values (e.g., `"type": "code-review"` which appears in `code-review.md:39` but is never defined), what happens? The skill spec doesn't say.

**What is unclear or ambiguous:**
- The `--mode` parameter (`quick` / `standard` / `thorough`) is listed in the inputs table but never defined anywhere in any file. What does `thorough` actually add? The SKILL.md says "adds cross-source verification" but that phrase has no definition.
- `--concurrency parallel` vs `sequential` — is this about MCP port collision, or about API rate limits, or both? The failure modes table mentions MCP port collision but the parameter description doesn't.

---

### rules/methodology.md

**What works well:**
- The 4-phase pipeline is clearly delineated and the right abstraction level.
- The audit trail principle ("Every step is recorded") is well-specified with concrete file outputs.

**What is missing or wrong:**
1. **Phase 2 extraction has no actual algorithm.** `methodology.md:33-51` describes Mode A ("Parse the model's response looking for a markdown table with headers matching the schema") and Mode B ("Split the response by H2 headings") but provides no pseudocode, no error handling, no edge cases. The consolidation-rules.md has a table parser pseudocode stub (`consolidation-rules.md:64-73`) but it's incomplete — it doesn't handle multi-line cells, code blocks in tables, or tables that span the full response. This is the core extraction step and it's underspecified.

2. **"If a model fails, the skill still produces a partial consolidated output" — but how is coverage communicated?** `methodology.md:19` says "the failure is logged and the model is excluded from consolidation" but doesn't say how the consolidated output signals that 2 of 6 models are missing. The `run-manifest.json` has `models_failed` but the consolidated.md has no coverage warning section.

3. **The "deterministic + LLM-assisted hybrid" claim is misleading.** `methodology.md:125-128` says "Conflict resolution uses configured rules, not LLM judgment" — but the `prefer-with-evidence-then-newer-then-strict` rule requires checking "primary quote support" and "source date" which are semantic judgments that an LLM has to make. The line between "configured rule" and "LLM judgment" is not clean.

**What is unclear or ambiguous:**
- Phase 3 says "For each unique item (by `primary_key` from schema or by fuzzy title match in free-form mode)" — but the fuzzy match algorithm is in consolidation-rules.md, not here. The cross-reference is implicit. If a developer implements from methodology.md alone, they'll miss the fuzzy match spec.

---

### rules/dispatch-mechanics.md

**What works well:**
- The 4 mechanisms are clearly ranked with a decision table.
- The known bugs (issue #18615) are documented with workarounds.

**What is missing or wrong:**
1. **Mechanism 1 is labeled "BEST" but "rarely works."** `dispatch-mechanics.md:9` says "BEST, but rarely works" — this is confusing. If it rarely works, it's not the best mechanism; it's the aspirational mechanism. The label should be "PREFERRED (if supported)" and the text should be clearer that Mechanism 2 is the actual default.

2. **No retry logic is specified.** `dispatch-mechanics.md:105-113` lists failure symptoms and fixes but the skill has no retry mechanism. If a model returns empty output, the skill logs it and moves on. This is acceptable but should be explicit: "The skill does NOT retry. If you need retries, wrap the dispatch in your own retry loop."

3. **The `--dangerously-skip-permissions` flag is recommended without security context.** `dispatch-mechanics.md:39` uses it in the example, and line 49 says "fine for non-destructive research tasks" — but the skill is task-agnostic and could be used for code modification tasks. This recommendation needs a security warning.

**What is unclear or ambiguous:**
- The auth section (`dispatch-mechanics.md:118-126`) lists providers and env vars but doesn't say what happens if a provider's auth is missing. Does the skill fail with a clear error, or does the subprocess hang?

---

### rules/consolidation-rules.md

**What works well:**
- The dedup algorithm pseudocode (`consolidation-rules.md:100-115`) is the most implementable piece of the skill. It's concrete enough to port to any language.
- The conflict documentation format (`consolidation-rules.md:166-173`) with the markdown table template is clear and actionable.

**What is missing or wrong:**
1. **The alias table is research-specific despite the skill claiming to be task-agnostic.** `consolidation-rules.md:254-274` has aliases for "AutoGen", "BMAD", "Conductor", "Claude Code", etc. — all prior-art research terms. The table header says "Add task-type-specific aliases as you encounter them" but the table itself IS task-specific. For a code-review use case, this entire table is irrelevant noise. The aliases should be in the example file, not in the core rules.

2. **Six conflict resolution rules from examples are never formally defined.** The examples use `majority-with-uncertain`, `lowest-of-majors`, `most-severe`, `concatenate-all`, `merge-exact`, `all-collected`, `union-dedup` — none of these appear in the core `consolidation-rules.md` defaults table (lines 142-153). The defaults table has `median`, `majority`, `most-cited`, `newer`, `longest-with-quote`, and `prefer-with-evidence-then-newer-then-strict`. The example-specific rules are described in prose in the example files but never formalized. An LLM implementing this skill from the rules alone would have to invent the algorithm for these rules.

3. **The `prefer-with-evidence-then-newer-then-strict` rule is underspecified.** `consolidation-rules.md:155-162` describes 5 sub-rules, but rule 1 ("If one model has a primary quote supporting value X") requires semantic understanding of what constitutes a "primary quote" — this is not machine-implementable without an LLM in the loop, contradicting the "deterministic" claim.

4. **The scoring algorithm is incomplete.** `consolidation-rules.md:197-206` shows the output format (median + range) but doesn't specify: what if different models use different scales? What if a model gives a non-numeric score? What if a model scores some dimensions but not others?

**What is unclear or ambiguous:**
- The fuzzy match threshold "≥80% similar (Levenshtein or token-overlap)" (`consolidation-rules.md:133`) — which one? Levenshtein and token-overlap can give very different scores. "Silver Bullet" vs "SilverBullet" is 95% on Levenshtein but 50% on token-overlap.

---

### rules/output-schema.md

**What works well:**
- The WYSIWYG formatting rules (`output-schema.md:224-235`) are concrete and machine-checkable.
- The conflict marker legend (`output-schema.md:71-75`) with `value*` convention is clever and useful.

**What is missing or wrong:**
1. **Mode B (no schema) defaults are research-specific.** `output-schema.md:100-108` shows `gaps_vs_reference` and `reference_gaps_vs_them` — these are prior-art research fields, not generic. A user doing fact-checking or ideation would not have a "reference" concept. This should either be generic or explicitly labeled as a research example.

2. **The `--mode thorough` is referenced but never defined.** `output-schema.md:27` mentions `quick | standard | thorough` in the file header template, but no file defines what `thorough` adds to the output. The research example says "adds cross-source verification and per-claim evidence ledger" (`research-prior-art.md:148`) but that's in an example, not the core spec.

3. **§3 "Per-Item Details" has a hardcoded research format.** `output-schema.md:104-108` shows `gaps_vs_reference = ... ; reference_gaps_vs_them = ...` — this is a gap-analysis template, not a generic per-item detail format. For code review, this would be "which reviewers flagged it and what they said"; for fact-check, this would be "verdict per model with evidence."

**What is unclear or ambiguous:**
- `structured.jsonl` format differs between methodology.md (line 28: `row_id`, `item`, `category`, `score`, `evidence`) and output-schema.md (line 193: `primary_key`, `fields`, `source_ref`, `raw_text`). Which is canonical?

---

### rules/examples/research-prior-art.md

**What works well:**
- The only example with a worked end-to-end run. The provenance section (`research-prior-art.md:133-141`) links to actual artifacts, making it verifiable.
- The schema and scoring rubric are concrete JSON objects that can be copy-pasted.

**What is missing or wrong:**
1. **The dispatch script has a bug.** `research-prior-art.md:20-26` uses `$(cat /path/to/research-prompt.md)` — but `/path/to/research-prompt.md` is a placeholder. The actual prompt path used in the provenance run was `docs/research-260624/SB_PRIOR_ART_USER_PROMPT.md`. The example should either use the real path or make the placeholder more obvious (e.g., `<YOUR_PROMPT_FILE>`).

2. **The "Variations to try" section is aspirational, not tested.** `research-prior-art.md:144-148` suggests "Add the deep-research skill per model" and "Run the skill in `thorough` mode" — but neither has been tested. The `thorough` mode isn't even defined in the core rules.

**What is unclear or ambiguous:**
- The schema has `"type": "table"` but the core output-schema.md describes Mode A as "structured (schema provided)" — is `"type": "table"` a required field? What other types are valid?

---

### rules/examples/code-review.md

**What works well:**
- The schema with `dedup_key: "file:line"` is the right granularity for code review findings.
- The `most-severe` conflict rule for severity is well-motivated ("don't downgrade a blocker").

**What is missing or wrong:**
1. **"Not yet produced" — the worked example doesn't exist.** `code-review.md:93` says "Not yet produced." This means the example is theoretical. The schema and conflict rules haven't been tested against actual multi-model code review output. For all we know, LLMs may not produce consistent `file:line` references, making the dedup key unreliable.

2. **The conflict rules used (`most-severe`, `concatenate-all`, `merge-exact`) are not defined in the core rules.** An LLM implementing this skill would read `consolidation-rules.md` and find only `majority`, `median`, `most-cited`, `newer`, `longest-with-quote`, and `prefer-with-evidence-then-newer-then-strict`. The code-review-specific rules appear only in this example file. They need to be either added to the core rules registry or explicitly documented as "user-defined custom rules."

3. **The `--schema` uses `"type": "code-review"` but this type is never defined.** The core output-schema.md defines Mode A (structured) and Mode B (generic). Is `"type": "code-review"` a recognized type that triggers special behavior, or is it just a label? If it's just a label, it should be documented as such.

**What is unclear or ambiguous:**
- `dedup_key: "file:line"` — what if two reviewers report the same finding at line 12 vs line 14? Is there a proximity-based dedup, or are these treated as separate findings?

---

### rules/examples/fact-check.md

**What works well:**
- The `majority-with-uncertain` rule for verdicts is well-motivated for high-stakes fact-checking.
- The consensus requirements section (`fact-check.md:89-95`) with explicit thresholds (3+ models agree, high confidence, primary source) is the most concrete decision rule in the skill.

**What is missing or wrong:**
1. **"Not yet produced" — the worked example doesn't exist.** `fact-check.md:99` says "Not yet produced." Same issue as code-review.

2. **The conflict rules (`majority-with-uncertain`, `lowest-of-majors`, `all-collected`, `union-dedup`) are not in the core rules.** Same issue as code-review. These are described in prose but never formalized as implementable algorithms.

3. **The consensus requirements section is outside the skill's scope.** `fact-check.md:89-95` defines thresholds like "3+ models agree on `true` with high confidence + primary source" — but the core consolidation-rules.md doesn't have a concept of "consensus thresholds." This is a policy decision that should be in the `--schema` or `--mode` parameter, not hard-coded in an example.

**What is unclear or ambiguous:**
- `"verdict": "majority-with-uncertain"` — if 3 models say `true`, 2 say `false`, and 1 says `unverified`, what's the result? The rule says "if 2 say true and 1 says false, default to `partially-true`" but doesn't specify behavior for other distributions.

---

## §2. Score the Skill on the 8-Dimension Rubric

Using the skill's own rubric from `consolidation-rules.md` and `research-prior-art.md:101-113`:

| Dimension | Score | Justification |
|---|---|---|
| **Catalog of composable units** | 0 | The skill has no catalog of composable units. It has 4 phases and 4 dispatch mechanisms, but these are not machine-readable units with stable IDs. There's no way to say "use Phase 2 extraction from this skill with Phase 3 consolidation from another." |
| **Dynamic composition** | 0 | No replanner, no catalog, no audit log. The skill follows a fixed 4-phase pipeline. The `--mode` parameter (quick/standard/thorough) is a static switch, not dynamic composition. |
| **V-loop depth** | 0 | No verification loops at any phase. The skill dispatches, captures, consolidates, and outputs — there's no "does the consolidated output meet the schema?" validation step, no retry on extraction failure, no intent gate. |
| **Enforcement** | 0 | No CI integration, no IDE hooks, no delivery blockers. The skill produces an artifact; what happens next is the user's problem. |
| **Parent/worker split** | 1 | Partial. The orchestrator (parent) dispatches to N models (workers) and consolidates. But the orchestrator is the LLM session itself, not a separate process. The skill doesn't have a persistent orchestrator that can be resumed or monitored. |
| **Evidence model** | 0 | No tiered sufficiency, no staleness tracking. The "confidence" field in the output is self-reported by models, not measured. The "last_verified" field appears in the research schema but isn't enforced (a model can leave it blank). |
| **SE + DevOps unified** | 0 | The skill covers neither domain. It's a generic dispatch+consolidation framework. The examples show research (neither SE nor DevOps), code review (SE), and fact-checking (neither). The skill doesn't have task-type-specific logic for SE or DevOps. |
| **Team customization** | 0 | No overlay packs, no process packs. The user can pass `--schema` to customize the output format, but that's per-invocation configuration, not a persistent team process model. Forking the skill is the only way to add team-specific behavior. |

**Total: 1 / 16**

The skill scores 1 point for having a partial parent/worker split (the orchestrator dispatches to workers), but even that is weak because the orchestrator is ephemeral (it's the current LLM session, not a persistent process).

---

## §3. Top 5 Improvements (ranked by impact × effort)

### 1. Formalize the conflict resolution rule registry

**Issue:** 7 conflict resolution rules from examples (`most-severe`, `concatenate-all`, `merge-exact`, `majority-with-uncertain`, `lowest-of-majors`, `all-collected`, `union-dedup`) are not defined in the core rules.

**Why it matters:** An LLM implementing this skill from `consolidation-rules.md` alone cannot implement the code-review or fact-check examples. The examples are unreachable without the LLM inventing the algorithm.

**Concrete change:** Add a "Conflict Resolution Rule Registry" section to `consolidation-rules.md` after line 175, defining each rule with pseudocode:

```markdown
### Rule registry (machine-readable)

| Rule name | Algorithm | Input | Output |
|-----------|-----------|-------|--------|
| `most-severe` | Pick the value with the highest severity rank | List of enum values | Single enum value |
| `majority` | Pick the value with the most votes | List of values | Single value |
| `majority-with-uncertain` | If ≥3 agree, pick that. If split, return `uncertain`. | List of verdicts | Single verdict |
| `lowest-of-majors` | Among the majority value, pick the lowest confidence | List of (value, confidence) | Single confidence |
| `concatenate-all` | Union of all values, preserving order | List of lists | Flattened list |
| `merge-exact` | Merge entries with identical key; keep all fields | List of (key, fields) | Merged list |
| `all-collected` | Same as concatenate-all, deduplicated by content | List of lists | Deduplicated list |
| `union-dedup` | Union of all URLs/references, unique only | List of URL lists | Deduplicated URL list |
```

**Effort:** Low (add ~30 lines of pseudocode)
**Impact:** High (makes the examples actually implementable)
**Score:** High / Low = **high ROI**

---

### 2. Move research-specific content out of core rules

**Issue:** The alias table (`consolidation-rules.md:254-274`) and the Mode B default output format (`output-schema.md:100-108`) are research-specific but live in the core rules.

**Why it matters:** A user doing code review or fact-checking encounters research-specific artifacts (AutoGen aliases, "gaps_vs_reference" fields) and has to mentally filter them. This contradicts the "task-agnostic" claim.

**Concrete change:**
- Move the alias table from `consolidation-rules.md:254-274` to `examples/research-prior-art.md` (or a new `examples/_aliases/` directory).
- In `consolidation-rules.md`, replace with a generic alias section: "Aliases are task-specific. Define them in your `--schema` or in a separate aliases file referenced by the schema."
- In `output-schema.md:100-108`, replace `gaps_vs_reference` / `reference_gaps_vs_them` with generic fields: "Per-item details should include: key findings, evidence, and per-model notes. The exact fields depend on the task type."

**Effort:** Low (move content, replace with generic)
**Impact:** High (makes the skill genuinely task-agnostic)
**Score:** High / Low = **high ROI**

---

### 3. Define `--mode thorough` and `--mode quick`

**Issue:** The `--mode` parameter is listed in the inputs table (`SKILL.md:66`) but never defined. `thorough` is mentioned in examples as "adds cross-source verification and per-claim evidence ledger" but has no spec.

**Why it matters:** Users can't make informed decisions about mode selection. The `thorough` mode sounds valuable but may not exist.

**Concrete change:** Add a section to `methodology.md` after Phase 4:

```markdown
## Mode variations

| Mode | Phase 2 | Phase 3 | Phase 4 |
|------|---------|---------|---------|
| `quick` | Basic extraction (no fuzzy match) | Dedup only, no conflict resolution | Merged raw output, no conflicts.md |
| `standard` | Full extraction with fuzzy match | Dedup + conflict resolution | Full consolidated output |
| `thorough` | Full extraction + cross-source verification | Dedup + conflict resolution + evidence ledger | Full output + evidence audit trail + per-claim source verification |
```

**Effort:** Low (add ~20 lines)
**Impact:** Medium (removes ambiguity, but `quick` and `standard` already work)
**Score:** Medium / Low = **medium ROI**

---

### 4. Add a worked code-review or fact-check example

**Issue:** Both `code-review.md` and `fact-check.md` say "Not yet produced." The only tested example is research-prior-art.

**Why it matters:** Without a worked example, we don't know if the skill actually works for non-research tasks. The schema and conflict rules may be broken in practice. The "task-agnostic" claim is untested.

**Concrete change:** Run the skill on a real code review (e.g., review a PR in this repo with 3 models) and document the results in `code-review.md`. Replace "Not yet produced" with actual output.

**Effort:** Medium (requires a real dispatch run + cleanup)
**Impact:** High (validates the task-agnostic claim)
**Score:** High / Medium = **medium-high ROI**

---

### 5. Specify the extraction algorithm for Phase 2

**Issue:** Phase 2 extraction (`methodology.md:33-51`) is described in prose with no pseudocode, no edge cases, no error handling.

**Why it matters:** This is the step that converts raw LLM output into structured JSONL. If this step fails or produces garbage, the entire consolidation is garbage. An LLM implementing this step has to invent the algorithm.

**Concrete change:** Add pseudocode to `methodology.md` for each extraction mode:

```markdown
### Mode A extraction pseudocode
function extractStructured(response, schema):
  1. Find markdown table with headers matching schema.columns
  2. For each row: map cells to schema columns by header name
  3. Skip rows that don't match schema shape (wrong column count, missing required fields)
  4. If no table found: look for <structured> tags
  5. If no structured tags: ask extractor model to reformat
  6. If extractor fails: return empty extraction with warning

### Mode B extraction pseudocode
function extractFreeform(response):
  1. Split by H2 headings (## ...)
  2. For each section: title = heading text, body = paragraphs under heading
  3. Extract: title, body, embedded URLs, key claims (first sentence of each paragraph)
  4. If no H2 headings: split by paragraphs, use first 5 words as title
```

**Effort:** Low (add ~30 lines of pseudocode)
**Impact:** High (makes extraction implementable)
**Score:** High / Low = **high ROI**

---

## §4. Open Questions

1. **Is this skill meant to be implemented by an LLM reading the rules, or by a human developer writing code?** The rules contain pseudocode (suggesting human implementation) but also "tips" and "suggestions" (suggesting LLM interpretation). If it's LLM-implemented, the rules need to be more prescriptive. If it's human-implemented, the rules need actual code, not pseudocode.

2. **What's the relationship between `--schema` and the output-schema.md defaults?** If a user passes `--schema`, does the skill ignore the §2-§8 section structure in output-schema.md? Or does it merge them? The spec says "follow the schema's natural form" but that's ambiguous.

3. **How does the skill handle models that produce wildly different output formats?** If one model returns a table, another returns prose, and a third returns a JSON blob — does the skill normalize them all? The extraction modes assume similar formats.

4. **What's the minimum number of models?** The "When NOT to use" section says "≤1 model" but doesn't specify if 2 models is enough for meaningful consolidation. With 2 models, conflict resolution is just "pick one" — there's no majority to consult.

5. **Is the skill's output consumed by other skills?** The SKILL.md "See also" mentions `deep-research` and `silver-bullet` but doesn't specify the integration contract. Can another skill programmatically consume `structured.jsonl` or `conflicts.md`?

6. **What happens when the same model is dispatched twice (by accident or for verification)?** The dedup algorithm deduplicates by item, not by model. If the same model appears twice, its entries are treated as separate models. This should be documented.

---

## §5. Confidence

**Overall confidence:** High

The review is based on reading all 8 files, cross-referencing conflict resolution rules between core rules and examples, checking the actual prior-art consolidated output, and verifying the test scenario. The issues are structural (missing rule definitions, research-specific content in generic rules, undefined parameters) not stylistic.

**What would change my assessment:**
- If the skill is intended to be a "prompt template" rather than a "specification" (i.e., the LLM is expected to improvise the details), then the missing algorithms are acceptable — but the skill should say so explicitly.
- If there's a companion implementation file (e.g., a Python/JS script that actually does the extraction and consolidation), the pseudocode gaps would matter less. But no such file exists in the skill directory.
