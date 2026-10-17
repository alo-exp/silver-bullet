# Critical Self-Review: `multi-ai-task` Skill

**Review date:** 2026-06-27  
**Reviewed version:** SKILL.md frontmatter claims `2.1.0`; task context says `v2.0.0` (discrepancy noted below).  
**Scope:** Read-only review of 8 files under `skills/multi-ai-task/`.

---

## §1. Critical Assessment

### 1. `SKILL.md` (entry point)

**What works well**
- The "When to use / When NOT to use" tables (lines 33-51) are genuinely useful guardrails. They prevent misuse for real-time or single-model tasks.
- The failure-modes table (lines 217-228) is specific and actionable—rare for a skill doc.

**What is missing or wrong**
- **Line 28-29: Self-contradiction under "What this skill does NOT do."** The bullet reads:  
  > "Inject the schema into the prompt unless `--no-auto-inject` is set (default ON — see 'The `--schema` parameter' below)"  
  The parenthetical says the default is ON (it DOES inject). But the heading is "does NOT do." A user scanning the negative list will incorrectly believe schema injection is disabled by default. This is a double-negative bug that undermines the primary UX flow.
- **Version inconsistency:** Frontmatter says `version: 2.1.0` (line 6), but the task description says the skill is at `v2.0.0`. There is no changelog or migration note anywhere in the tree explaining what changed between versions. The only "changelog" clues are scattered asides like fact-check.md line 77 ("was a v2.1.0 gap").
- **No guidance on safe inline `--schema` usage.** The argument hint (line 4) advertises `[--schema <json|file>]`, implying inline JSON is supported. In a shell context, passing a raw JSON object with quotes and brackets is a metacharacter trap. Every example in the repo uses a file path or heredoc. The skill should either drop `<json>` from the hint or provide a quoted-string escape example.

**What is unclear or ambiguous**
- **What happens when a model partially complies with the schema?** For example, a model returns a table with all required columns plus two extra columns. Is the row dropped, truncated, or accepted with unknown fields ignored? The doc doesn't say.
- **What is the maximum safe `N`?** The research example uses 6, code review uses 2, fact-check suggests 3-5. The doc never gives a rule of thumb for choosing N beyond "cost is acceptable."

---

### 2. `rules/methodology.md` (4-phase pipeline)

**What works well**
- Phase 2 pseudocode (lines 38-64) makes the extraction fallback chain explicit. Four fallbacks is the right level of paranoia for LLM output parsing.
- The cross-cutting "Audit trail" principle (lines 162-168) is strong and well-scoped.

**What is missing or wrong**
- **Line 104: Factually false claim about cost.**  
  > "Default: the slowest, highest-capability model from the original dispatch (caches the response, no extra cost)."  
  There is no caching mechanism described anywhere in the skill. Dispatching an extractor model consumes additional tokens and API calls. Stating "no extra cost" is either a lie or a reference to an unimplemented feature. This destroys user trust the first time they see an unexpected bill.
- **Line 170-173: "Idempotent re-runs" is the wrong word.**  
  > "The skill can be re-run with the same `task-prompt` and produce a new consolidated output."  
  LLM outputs are non-deterministic. Re-running with the same prompt produces *different* outputs, not the same output. "Reproducible" would also be wrong without temperature=0 and fixed seeds. The section should be retitled "Re-runnable" and explicitly note that outputs will vary.
- **Missing: prompt length / context window budgeting.** If the user passes a 10k-token prompt plus a large schema, some models in the default set may truncate or fail. There is no guidance on splitting prompts or choosing models by context window.

**What is unclear or ambiguous**
- **How is the "extractor model" selected if the dispatch set has identical capability ratings?** The doc says "slowest, highest-capability model"—what if two models tie? Arbitrary? Deterministic by name sort?
- **Line 81-84: Free-form extraction splits by H2 only.** Many models use H1 (`#`) for main sections. The skill silently treats H1 as the document title. This will miss structured output from models that prefer H1 sectioning.

---

### 3. `rules/dispatch-mechanics.md` (4 dispatch mechanisms)

**What works well**
- The security note on `--dangerously-skip-permissions` (line 56-59) is precise: correct for read-only, wrong for write tasks. This shows real operational awareness.
- The "Parallel vs sequential" tradeoff table (lines 99-103) includes the MCP port collision caveat, which is a genuinely subtle production issue.

**What is missing or wrong**
- **Line 44-45, 62: `timeout` command fails on stock macOS.** The default mechanism uses `timeout "$TIMEOUT" npx ...`. On macOS, `timeout` is not installed by default; users must `brew install coreutils` and use `gtimeout`. The doc mentions this in a footnote (line 62) but the actual script does not handle the fallback. A copy-paste user on macOS will get `command not found` and the per-model timeout protection disappears. This is a portability bug in the *default* mechanism.
- **Line 58: `npx -y` install risk in background processes.**  
  > "`--y` in `npx -y opencode-ai run` skips the install prompt; without it, background subprocesses may hang."  
  The opposite risk is unmentioned: if `opencode-ai` is not pre-installed, `npx -y` will attempt a background install, which can race, hang, or fail silently when run under `&` in a shell loop. The doc should advise pre-installing (`npm install -g opencode-ai`) before dispatch.
- **Missing: Rate-limit handling.** Firing 6 models in parallel via `npx opencode-ai run` can trigger provider rate limits. There is no backoff, jitter, or retry logic—only "check stderr" in the failure table.

**What is unclear or ambiguous**
- **Line 44: `slug` collision risk.** `slug=$(echo "$model" | cut -d/ -f2)` strips the provider. If a user dispatches both `openai/gpt-4` and `anthropic/gpt-4` (hypothetical or future naming collision), both write to `gpt-4.md`, clobbering each other. The doc should recommend `tr '/' '-'` or warn that slugs must be unique.
- **Line 107: MCP restart advice without implementation.** The doc says the proven fix for port collision is to "restart the MCP between dispatches," but provides no mechanism, script, or hook to do so. This is advice without tools.

---

### 4. `rules/consolidation-rules.md` (dedup, conflict resolution, scoring aggregation)

**What works well**
- The named rule library (lines 167-221) is the strongest part of the skill. Each rule has a stated purpose, algorithm, and edge case. `most-severe`'s `allow_downgrade` flag (lines 171-172) shows real-world code-review safety thinking.
- Alias map as a task-specific runtime construct (lines 81-91) is the right abstraction.

**What is missing or wrong**
- **`prefer-with-evidence-then-newer-then-strict` references a task-specific field as a default.** Lines 156-162 describe the default rule for enumerated strings. Step 2 says: "Newer `last_verified` wins." But `last_verified` is a column defined in the *research* schema example, not a generic field. In code-review or fact-check runs, this field does not exist. The rule pretends to be generic but embeds a research-specific assumption. The fallback when `last_verified` is absent is not specified.
- **`majority-with-uncertain` threshold is weak for even N.** Line 183: "require ≥ `max(2, ceil(N/2))` models to agree." For N=4, threshold = 2 (50%). For N=6, threshold = 3 (50%). The fact-check example (line 102-108) calls this "high-stakes," but a 50% threshold for even N is a bare plurality, not a confident consensus. The doc should recommend odd N for high-stakes tasks or raise the threshold for even N.
- **Missing ordinal-to-numeric mapping for scoring rubrics.** Lines 250-256 describe aggregating numeric scores, and the research example (lines 105-118) defines a rubric with textual levels (e.g., "none", "informal roles", "machine-readable catalog"). Nowhere does the skill specify how "machine-readable catalog" is converted to `2` before taking the median, or how the median `1.5` is mapped back to a label. This gap makes the scoring rubric in the research example unimplementable as written.

**What is unclear or ambiguous**
- **Line 185: Authoritarian naming policy for `majority-with-uncertain`.**  
  > "Do NOT change the rule's return value to match the schema — change the schema to match the rule."  
  Why? If a team uses `partially-true` instead of `unverified`, forcing them to rename their schema to accommodate the skill's internal constant is user-hostile. The rule should accept a configurable `uncertain_value` parameter.
- **How are missing values handled in score aggregation?** If 4 of 6 models score an item and 2 omit the dimension, is the median computed over 4 values? The doc notes the N=1 case (line 256) but not the general partial-coverage case.

---

### 5. `rules/output-schema.md` (output structure)

**What works well**
- The WYSIWYG formatting rules (lines 258-269) are surprisingly detailed and correct. Most docs ignore viewer compatibility; this doesn't.
- The `run-manifest.json` example (lines 211-236) is comprehensive and includes v2.1.0 fields like `schema_auto_injected`, `aliases`, and `phases_completed`.

**What is missing or wrong**
- **`models_failed` type ambiguity between files.** `SKILL.md` line 221 uses arrow notation: `run-manifest.json → models_failed`, implying a simple field name. `output-schema.md` line 249 defines it as a list of objects: `[{model, stderr_excerpt, exit_code}]`. The arrow notation in SKILL.md is sloppy and could mislead implementers into using a string list instead of an object list.
- **Missing `version` field in `run-manifest.json`.** There is no field indicating which version of the skill produced the manifest. When v2.2.0 adds new fields, old manifests will be indistinguishable from new ones. Add `"skill_version": "2.1.0"`.
- **No formal schema for `structured.jsonl`.** An example line is given (line 200), but there is no JSON Schema, TypeScript interface, or even a required-field list. Consumers cannot validate extraction output.

**What is unclear or ambiguous**
- **Line 251: Alias map JSON format is undefined.** The example shows `"aliases": {"AutoGen/AG2": "AutoGen"}`. Is the key a regex? A comma-separated list? The research example alias table shows `AutoGen/AG2, AutoGen (maintenance) | AutoGen` (pipe table), but the JSON serialization of multi-alias-per-canonical is never specified. Can I use `"AutoGen|AG2": "AutoGen"`? `"aliases": ["AutoGen", "AG2"]`? Unknown.
- **Line 174: HTML generation is hand-waved.** "Convert `consolidated.md` to HTML using a markdown library (`marked` in Node, `markdown` in Python, `pandoc` for richer output)." What if none are installed? Is HTML generation optional or mandatory? No error handling spec.

---

### 6. `rules/examples/research-prior-art.md` (proven worked example)

**What works well**
- This is the only *proven* example in the repo. It includes actual paths, a real alias map (14 entries), and a worked schema. It earns its credibility.
- The alias map admission (line 123) that semantic dedup requires curation is honest.

**What is missing or wrong**
- **Scoring rubric lacks ordinal-to-numeric mapping spec.** Lines 105-118 declare levels as strings (e.g., `"none"`, `"informal roles"`, `"machine-readable catalog"`) and set `"aggregate": "sum"`. But the consolidation rules expect numeric values. The implicit mapping (array index) is never stated. A model or implementer has no authoritative source for whether `"informal roles"` = `1` or `2`.
- **Line 183: Anecdotal guidance presented as fact.**  
  > "8-10 models captures more unique finds but diminishing returns past 6 (this is an empirical observation, not a measured curve — run your own benchmark if you want a hard number)"  
  Honest, but also an admission that the skill provides no data-driven sizing guidance. For a v2.1.0 skill, there should be at least a rough model-count vs. unique-find curve from the proven run.
- **Alias map is a markdown table, not machine-readable JSON.** To use it in `run-manifest.json → aliases`, a user must manually convert the pipe table to JSON. No script or utility is provided.

**What is unclear or ambiguous**
- **How was the research prompt constructed?** The doc says "substitute the path to the user's research prompt file" but gives no guidance on what makes a prompt successful for multi-model dispatch. Should it explicitly ask for a table? Should it forbid narrative? The proven run's prompt is referenced but not excerpted.

---

### 7. `rules/examples/code-review.md` (recipe for code-review use)

**What works well**
- The composite key explanation (lines 68-70) is clear and correct. Calling out the old `"primary_key": "file:line"` string form as wrong prevents a common schema mistake.
- The custom strategies table (lines 94-100) gives actionable per-field rules.

**What is missing or wrong**
- **Line 111: No worked example.**  
  > "Not yet produced (deferred to v2.2.0)."  
  For a skill claiming to be "task-agnostic" and listing code review as a primary use case, the absence of a proven run is a credibility gap. Two-thirds of the examples are stubs.
- **Exact line matching is brittle.** The composite key `(file, line)` uses exact integers. In practice, two reviewers may flag the same issue at lines 42 and 43 due to prompt drift, header offset, or model tokenization differences. The skill provides no `line_tolerance` or fuzzy matching for numeric keys, so the same finding will appear as two rows.
- **Missing: large-file handling.** If the target file is 10,000 lines, models may truncate or miss findings. No guidance on chunking or file-size limits.

**What is unclear or ambiguous**
- **Line 70 references an "old spec" without locating it.** If `"primary_key": "file:line"` is wrong, has it been purged from all other files and templates? A user encountering it in an old gist or blog post won't know it's deprecated. The doc should say "this was never valid in v2.x; if you see it, reject it."

---

### 8. `rules/examples/fact-check.md` (recipe for fact-check use)

**What works well**
- The consensus requirements (lines 102-108) are precise and correctly parameterized. The threshold math is explicit.
- Using `lowest-of-majors` for confidence is the right safety choice for high-stakes verification.

**What is missing or wrong**
- **Line 113: No worked example (same deferral as code-review).**  
  > "Not yet produced (deferred to v2.2.0)."  
  Only 1 of 3 examples is proven. The "task-agnostic" generalization is under-substantiated.
- **No handling of source reliability or knowledge cutoff drift.** Models may cite Wikipedia (low reliability) or official docs (high reliability). The skill treats all URLs equally in `union-dedup`. A claim might be `true` for one model (knowledge cutoff 2024) and `false` for another (cutoff 2023) due to temporal drift, not factual disagreement. The skill has no mechanism to weight sources or flag temporal conflicts.
- **Line 109: Self-admitted typo in a prior version.**  
  > "The '3+ models' rule in the original draft was a typo; the correct threshold is parameterized."  
  This suggests a documentation error escaped into a published version. It raises confidence in the current fix, but also flags that the skill's review process allowed a basic arithmetic error through.

**What is unclear or ambiguous**
- **What is the verifier model's prompt in `thorough` mode?** The doc mentions `thorough` mode adds cross-source verification, but the fact-check example doesn't show what prompt is sent to the verifier, how paywalled sources are handled, or what happens when the verifier itself hallucinates a verification result.

---

## §2. Score the Skill on the 8-Dimension Rubric

| Dimension | Score | Justification |
|---|---|---|
| **1. Catalog of composable units** | **1** | The named rule library (`most-severe`, `majority-with-uncertain`, etc.) is well-documented but lives in markdown prose. There is no machine-readable registry (JSON/YAML catalog) of rules, schema templates, or task-type packs that a harness could discover programmatically. |
| **2. Dynamic composition** | **0** | The skill offers three static modes (`quick`, `standard`, `thorough`) selected at invocation time. There is no replanning mid-run, no catalog-backed pipeline builder, and no audit-log-driven composition. Once the mode is chosen, the pipeline is fixed. |
| **3. V-loop depth** | **1** | `thorough` mode implements per-item cross-source verification (a per-step rollup), but it is optional. The default `standard` mode is end-test only: dispatch → extract → consolidate → synthesize. No intent gate or checkpoint blocks a bad intermediate result from propagating. |
| **4. Enforcement** | **0** | The skill is invoked entirely on the honor system of the calling agent. There are no CI gates, IDE hooks, or delivery blockers that require multi-model consolidation before a commit, merge, or deploy. |
| **5. Parent/worker split** | **2** | The skill is explicitly an orchestrator. The parent (calling agent / CLI wrapper) dispatches to N worker models, captures outputs, and consolidates. The dispatch-mechanics.md file makes this boundary explicit and provides 4 mechanisms for crossing it. |
| **6. Evidence model** | **2** | Tiered evidence is present: `source_refs` per extraction row, `evidence-ledger.md` in `thorough` mode, per-field confidence levels, and per-item `source_verified` flags. Staleness is partially addressed via `last_verified` (though that field is task-specific). |
| **7. SE + DevOps unified** | **2** | The skill is task-agnostic by design. While the provided examples lean toward SE (code review) and research, nothing in the architecture prevents DevOps tasks (e.g., IaC plan review, deployment verification). It covers both production task types in a single model. |
| **8. Team customization** | **1** | Teams can pass custom `--schema` JSON and alias maps without forking the skill core, but there is no "overlay pack" mechanism—no directory of drop-in team presets, no schema package manager, and no shared registry of team-specific rules. Each team reinvents the JSON from scratch. |

**Total: 9 / 16**

---

## §3. Top 5 Improvements (Ranked by Impact × Effort)

### 1. Fix the self-contradictory schema auto-injection bullet in `SKILL.md`
- **Issue:** Line 28-29 places an affirmative default behavior ("schema IS auto-injected") under a "What this skill does NOT do" heading, creating a double-negative that misleads users.
- **Why it matters:** A user scanning the negative list will omit `--schema` because they believe injection is off by default, producing unstructured model outputs and breaking consolidation.
- **Concrete change:** `SKILL.md:28-29`  
  Replace:  
  `"- Inject the schema into the prompt unless \`--no-auto-inject\` is set (default ON — see \"The \`--schema\` parameter\" below)"`  
  With:  
  `"- Inject the schema into the prompt (default ON; pass \`--no-auto-inject\` to disable)"`  
  And move it from the "does NOT do" list to the "does" list (lines 15-22).
- **Effort:** low | **Impact:** high | **Score:** 4.0

### 2. Correct the false "no extra cost" claim for the extractor model in `methodology.md`
- **Issue:** Line 104 claims the extractor model "caches the response, no extra cost." There is no caching mechanism described anywhere; calling the extractor costs tokens and API calls.
- **Why it matters:** Users budgeting API spend will be surprised by extra charges. A skill that lies about cost undermines trust in every other claim.
- **Concrete change:** `methodology.md:104`  
  Replace:  
  `"(caches the response, no extra cost)"`  
  With:  
  `"(incurs additional token cost; the extractor is a full second dispatch)"`
- **Effort:** low | **Impact:** high | **Score:** 4.0

### 3. Fix macOS portability of the default dispatch script in `dispatch-mechanics.md`
- **Issue:** Lines 44-45 use `timeout`, which does not exist on stock macOS. The footnote (line 62) mentions `gtimeout` but the script itself doesn't handle the fallback, so the default mechanism breaks on a major developer platform.
- **Why it matters:** A copy-paste user on macOS loses per-model timeout protection and will hit the 2-minute shell-tool timeout silently.
- **Concrete change:** `dispatch-mechanics.md:44`  
  Add above the loop:  
  ```bash
  TIMEOUT_CMD=$(command -v gtimeout || command -v timeout)
  if [ -z "$TIMEOUT_CMD" ]; then echo "Install coreutils (macOS) or util-linux (Linux)" >&2; exit 1; fi
  ```  
  And change line 45 to: `"$TIMEOUT_CMD" "$TIMEOUT" npx -y opencode-ai run ...`
- **Effort:** low | **Impact:** high | **Score:** 4.0

### 4. Provide machine-readable schema templates for common task types
- **Issue:** Every user must hand-author JSON schema from scratch. The examples embed schemas in markdown, but there are no downloadable `.json` files. This is the single biggest barrier to adoption.
- **Why it matters:** Writing a correct schema is error-prone (witness the old `"primary_key": "file:line"` mistake). Providing validated templates would reduce first-run failure by half.
- **Concrete change:** Create `skills/multi-ai-task/templates/schemas/` with:  
  - `code-review.schema.json` (composite key `file`+`line`, `most-severe` for severity)  
  - `fact-check.schema.json` (`claim_id` primary key, `majority-with-uncertain` for verdict)  
  - `research.schema.json` (the proven prior-art schema)  
  Update `SKILL.md:91` to reference them: "Download a template from `templates/schemas/<task>.schema.json`."
- **Effort:** medium | **Impact:** high | **Score:** 2.7

### 5. Define explicit ordinal-to-numeric mapping for scoring rubrics in `consolidation-rules.md`
- **Issue:** The research example defines rubric dimensions with textual levels (e.g., "none", "informal roles", "machine-readable catalog") and sets `"aggregate": "sum"`, but the consolidation algorithms expect numeric values. The mapping is implicit (array index) but never specified, making the rubric unimplementable.
- **Why it matters:** Any team attempting to replicate the research example will fail to aggregate scores correctly or will invent inconsistent mappings.
- **Concrete change:** `consolidation-rules.md:250-256`  
  Add a new subsection:  
  ```markdown
  ### Ordinal field aggregation
  For `enum` columns used as scoring dimensions, map each value to its zero-based index in the `values` array before numeric aggregation. After aggregation, map the numeric result back to the nearest valid enum value (round to integer). Example: `["none", "informal roles", "machine-readable catalog"]` → `[0, 1, 2]`; median `1.5` rounds to `1` → `"informal roles"`.
  ```  
  Update `research-prior-art.md:105-118` to note that `values` array order determines numeric weight.
- **Effort:** low | **Impact:** medium | **Score:** 2.0

---

## §4. Open Questions

1. **What is the canonical version?** SKILL.md says `2.1.0`, the task context says `v2.0.0`, and fact-check.md references a "v2.1.0 gap" fix. Was 2.1.0 released? Is there a changelog? Without one, reviewers cannot tell which issues were fixed vs. inherited.

2. **How is the HTML preview actually generated?** The skill promises `consolidated.html` but provides no script, no CSS spec, and no dependency manifest (`package.json` for `marked`, etc.). Is this implemented or aspirational?

3. **What is the intended audience for `thorough` mode?** It adds ~N_items verifier calls. For a 36-item research run, that's 36 extra API calls. At $0.01–$0.10 per call, that's $0.36–$3.60 extra—acceptable for due diligence, but who decides? The skill says "high-stakes (regulatory, due-diligence)" but doesn't define who authorizes the cost increase.

4. **Why are 2 of 3 examples unproven stubs deferred to v2.2.0?** The skill claims generalization from v1.0.0 to v2.x, yet only the research example has a proven run. What blocked code-review and fact-check proofs? Is it lack of test harness, lack of target code/claims, or known bugs in those paths?

5. **How should teams share custom schemas and alias maps?** The skill supports customization via `--schema` and `aliases`, but there is no packaging format, no versioning for schema files, and no discovery mechanism. Is this intentionally minimal, or is a schema registry planned?

---

## §5. Confidence

- **Overall confidence:** **medium**
- **What would change my assessment:**
  - Access to the actual implementation (not just the skill docs) would raise confidence in whether the pseudocode matches real behavior—especially for the extractor model fallback and the HTML renderer.
  - A changelog or git history of the skill files would clarify whether v2.1.0 is real and whether the issues flagged here are known regressions or long-standing gaps. Without that, some of my severity estimates are speculative.

---
The critical self-review is complete and returned above. Key findings:

- **SKILL.md** contains a logical contradiction: schema auto-injection is listed under "What this skill does NOT do" despite being ON by default.
- **methodology.md** falsely claims the extractor model incurs "no extra cost" — there is no caching mechanism described anywhere.
- **dispatch-mechanics.md**'s default script uses `timeout`, which fails on stock macOS.
- **consolidation-rules.md** embeds a research-specific field (`last_verified`) into a supposedly generic default conflict-resolution rule.
- **2 of 3 examples** (code-review, fact-check) are unproven stubs deferred to v2.2.0, undermining the "task-agnostic" claim.

**Rubric total: 9 / 16.** The skill scores well on parent/worker split and evidence model, but fails on enforcement, dynamic composition, and machine-readable catalog.

**Top ROI fixes:** correct the schema-injection contradiction, fix the extractor cost claim, and patch macOS portability — all low-effort, high-impact.
