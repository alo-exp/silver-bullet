# Critical Self-Review: `multi-ai-task` skill

**Skill:** `/Users/shafqat/projects/silver-bullet/repo/skills/multi-ai-task/`
**Version reviewed:** 2.1.0 (frontmatter at `SKILL.md:6`)
**Files reviewed:** 8 (SKILL.md + 4 rules + 3 examples)
**Review date:** 2026-06-27

---

## §1. Critical Assessment

### 1.1 `SKILL.md` (256 lines)

**What works well:**
- The "When to use / When NOT to use" matrix at `SKILL.md:35-50` is concrete and uses the right criterion (model diversity as signal vs noise).
- The failure-mode table at `SKILL.md:218-229` is honest about real failure modes (`npx opencode-ai run` returning instantly, 2-min shell timeout, CWD strays).

**What is missing or wrong:**
- **`argument-hint` and `Usage` line are out of sync.** Line 4 (`argument-hint`) lists `--concurrency`; line 57 (`Usage`) does not. The Inputs table (line 69) documents `--concurrency` but the Usage line that a human would copy-paste omits it. This is a small thing but a real defect in the contract.
- **No example of `--schema <file>` syntax.** `SKILL.md:67` says "Either a JSON object (inline) or a path to a `.json` file" but the schema example at line 95-114 is only inline. The file form (especially how it interacts with shell quoting and the auto-inject toggle) is not shown anywhere in the 8 files.
- **`See also` line 256 references `deep-research` with the qualifier "if available, or inline the methodology in the dispatch prompt."** This contradicts the file's own "task-agnostic" claim (line 11) — the skill is leaning on a host-specific helper. Either the dependency should be in the contract or the line should be cut.
- **The "Proven provenance" section at lines 236-248 is honest about a folder-name oddity** ("the folder name encodes 2026-06-24 ... but the actual run was on 2026-06-27 ... Do not rename the folder — it's referenced by 30+ other paths"). This is a good maintenance note but it also betrays that the run directory has 30+ references that nobody wants to update. That is process debt.
- **`SKILL.md:248` mentions a "round-2 self-review (v2.1.0) is at `docs/research-260624/multi-ai-self-review-r2-20260627-093345/`" but the disk also has `multi-ai-self-review-r3-20260627-095647/`.** The r3 run is not referenced. The r3 model output files are all 0 bytes (only `.err` files exist, with the same prompt the user is asking me now) — so the r3 run is effectively broken and unacknowledged. **The skill is being used RIGHT NOW (this prompt is the r3 prompt) and the previous r3 attempt did not produce output.** This is the most important fact in the review: the meta-task has been tried before and the model didn't complete the work.

**What is unclear or ambiguous:**
- `SKILL.md:5` declares `user-invocable: false` but the Usage line at `SKILL.md:57` shows `/multi-ai-task "<task-prompt>"` syntax. If the user can't invoke it, why is there a `/` command? The relationship between "agent invokes skill" and "user types slash command" is left implicit.
- The "task-agnostic" claim at `SKILL.md:11` is reinforced at lines 13, 24-29, 156, 189-191, 212 — but `SKILL.md:255` recommends "for the per-model prompt for research, use Claude's `deep-research` skill if available." That recommendation is task-specific (research) and host-specific (Claude). The "task-agnostic" framing leaks.

---

### 1.2 `rules/methodology.md` (208 lines)

**What works well:**
- The 4-phase pipeline (lines 7-7, 23, 108, 122) is a clean decomposition with crisp per-phase inputs/outputs.
- The schema auto-injection paragraph at `methodology.md:15` is a strong design choice — it documents the failure mode (model doesn't see the schema) and the fix (auto-append a `## Required Output Schema` block), plus the opt-out flag.
- The pseudocode in `methodology.md:38-65` is concrete enough to implement, with four explicit fallback paths.

**What is missing or wrong:**
- **`run-manifest.json` schema contradiction with `output-schema.md`.** `methodology.md:147` claims: "**The canonical schema lives in `rules/output-schema.md` § `run-manifest.json`.** All other files reference it." But the schema at `methodology.md:149-174` contains three fields that the `output-schema.md:209-227` schema does not: `aliases`, `consolidation`, and `phases_completed`. If `output-schema.md` is canonical, the methodology schema is wrong. If the methodology schema is right, the "canonical" claim is wrong. **This is a real spec bug** — any tool that reads `run-manifest.json` and trusts `output-schema.md` will silently drop the alias map, the consolidation stats, and the phases-completed audit trail.
- **Three different pseudocodes for "extract structured rows" across the skill:**
  - `methodology.md:38-65` — `extractStructured()` with 4 fallback paths
  - `consolidation-rules.md:64-74` — `extractRows()` with 1 path (table only)
  - `SKILL.md:151-154` — prose, no pseudocode, but a different fallback chain ("ask a designated 'extractor' model" is mentioned in `SKILL.md:153` and `methodology.md:51-58` but NOT in `consolidation-rules.md`).
  These should be one canonical algorithm.
- **"Extractor model" is underspecified.** `methodology.md:104` says: "Default: the slowest, highest-capability model from the original dispatch (caches the response, no extra cost)." But:
  - What if the "slowest" model is the one that failed (no response to extract from)?
  - What if the slowest model returns a refusal or empty response?
  - "Caches the response" — what cache? The output dir? The model's session?
  - "(no extra cost)" — the model has to be re-invoked as an extractor; that's a fresh API call. Where does "no extra cost" come from?

**What is unclear or ambiguous:**
- `methodology.md:207-208` says the skill "does NOT cache across runs by default" and "the `run-manifest.json` from previous runs can be referenced for incremental consolidation (future enhancement)." But `methodology.md:182` says `task_prompt_hash` is "useful for cache lookup and reproducibility audit." Two contradictory purposes for the hash: cache lookup (which doesn't exist) and audit (which it does). Pick one.
- "Idempotent re-runs" at line 207 — the skill is NOT idempotent by the standard definition; re-running produces a new run dir at a new timestamp. The "idempotent" label is a stretch.

---

### 1.3 `rules/dispatch-mechanics.md` (177 lines)

**What works well:**
- The 4-mechanism table (lines 7-89) is well-structured with concrete code, not just descriptions.
- The auth/credentials table (lines 134-145) is concrete and useful — many skill specs leave this out.
- Mechanism 1's "important constraint" (lines 28-30) is a real, useful warning about a harness limitation (the `task` tool's `Parameters` schema not including `model`).

**What is missing or wrong:**
- **`--concurrency` flag is not implemented in any example.** `SKILL.md:69` declares the flag, but `dispatch-mechanics.md` only shows parallel dispatch (the `for ... & wait` pattern at line 40-49). **There is no working `sequential` example anywhere in the 8 files.** A user following the docs cannot construct a sequential dispatch from the documented patterns alone.
- **Mechanism 3 (HTTP SDK) is admitted to be broken.** `dispatch-mechanics.md:75` cites known bug #18615 and recommends "use Mechanism 2." The "Choosing the right mechanism" table (line 167-177) still includes Mechanism 3 as an option for "OpenCode server running (`opencode serve`)." A reader following the table would pick Mechanism 3 and hit the bug.
- **Per-model output capture (lines 106-112)** says: "Always check the model's CWD for stray `*.md` files after a dispatch. If the shell wrapper was killed but the model already wrote its report, the report is still on disk." This is a rescue heuristic, not a contract. The output dir is "expected" and the CWD is "fallback" — but the skill never documents which CWD or how to reconcile. If the user runs 6 models in parallel, all 6 share one CWD; how do you tell whose stray `*.md` is whose?
- **Mechanism 4 (direct HTTP)** has no failure-mode table of its own. The auth table at lines 134-145 covers Mechanisms 1-3 (via `npx opencode-ai run`) but Mechanism 4 calls provider APIs directly. The example at line 81-89 uses `openai.AsyncOpenAI` but doesn't show how to dispatch to Anthropic, Google, or local Ollama in the same loop.

**What is unclear or ambiguous:**
- `dispatch-mechanics.md:175` recommends "Mechanism 4 for cross-provider coverage" in the "Choosing the right mechanism" table. But Mechanism 4 explicitly "lose[s] MCP access" (line 79). For a research task that uses `ctx_batch_execute` and `webfetch`, Mechanism 4 is not equivalent to Mechanism 2. The table treats them as substitutable.
- The MCP port-collision caveat (lines 102-103) says: "The proven fix is to either (a) configure MCPs that support multiplexing, or (b) dispatch to a single model at a time AND restart the MCP between dispatches." Option (b) is the sequential case; (a) requires MCP reconfiguration. Neither is "pass `--concurrency sequential`" — the flag in `SKILL.md:69` is too coarse to actually solve this.

---

### 1.4 `rules/consolidation-rules.md` (334 lines)

**What works well:**
- The named-rule library at lines 167-221 is the most concrete and useful section. Each rule has a Purpose, Input, Algorithm, Edge case, and Implementation note. These are implementable algorithms, not aspirational labels.
- The default rule-per-type table (lines 144-153) is a good mapping from schema type → behavior.
- "How to document resolutions" (lines 223-234) shows a concrete conflict-table example with realistic entries.

**What is missing or wrong:**
- **The "Maturity / version conflict" section at lines 258-262** references `last_verified` as a per-row field. But `last_verified` only appears in the research-prior-art schema (`research-prior-art.md:92`). It's not a field in `structured.jsonl` (line 195-201 of output-schema.md), not a top-level row field. The rule is task-specific but lives in the generic rules file. **Move it to `examples/research-prior-art.md` as a custom strategy.**
- **`lowest-of-majors` is underspecified for the multi-confidence case.** Lines 188-190: "first apply `majority` to get the majority value; then among the models voting for that value, return the lowest confidence (`high > medium > low`)." If the majority has 4 voters with confidence levels `[high, high, medium, low]`, the algorithm returns `low`. That's the "lowest of the majority." But the rule name says "lowest-of-majors" (plural), implying it could be a different ordering. The rule doesn't say whether "high > medium > low" means "high is better" (so lowest = most-cautious) or "high is index 0" (so `min` of index = `low` because it's last). This is a 1-line ambiguity but it matters for trust.
- **`prefer-with-evidence-then-newer-then-strict` rule (lines 155-161) is 4 steps, not 3.** The rule name says three things: "evidence / newer / strict." Step 1 is "quoted primary source wins." Step 2 is "newer `last_verified` wins." Step 3 is "single-model outlier rule." Step 4 is "tie-break: prefer the value with the strongest evidence quote, then prefer the most recent." The name is missing step 1 (it's an evidence rule) and step 3 (it's an outlier rule). The name is the contract; the body is more. **Rename the rule or split it.**
- **`score-aggregate.md` is acknowledged as a leftover.** This is in `SKILL.md:228` failure-modes table, not in this file, but the file references it indirectly via the score conflict resolution at lines 250-256 and "Aggregated Scores" in output-schema.md:130-140. The fragment is a real consistency problem — the user could believe a `score-aggregate.md` is promised.

**What is unclear or ambiguous:**
- The "Aliases" section at lines 325-334 duplicates content from the "Alias mapping" section at lines 80-91. The two sections describe the same concept from different angles. **Pick one and delete the other.** The "default behavior" at line 334 is repeated almost verbatim at line 82.
- The "Dedup algorithm" pseudocode at line 95-111 uses `if (canonical === null) continue;` (line 99) — but the alias map at line 87-91 has only `'<alias>': '<canonical>'` entries. The `aliases[n] = null` form (line 115) requires a map where the value is optional/null, not a string-to-string map. The data structure is inconsistent.

---

### 1.5 `rules/output-schema.md` (243 lines)

**What works well:**
- The "Markdown formatting rules" (lines 231-242) are concrete and address real WYSIWYG-rendering failure modes (bare `*` next to bold, missing blank lines around tables, header/body cell mismatch). This is the kind of detail most skill specs omit.
- The §2A / §2B split (schema vs no-schema item rendering) is a clean way to express the two output modes.

**What is missing or wrong:**
- **`run-manifest.json` schema is incomplete relative to `methodology.md`.** Lines 209-227 show: `timestamp`, `task_prompt`, `task_prompt_hash`, `mode`, `schema_provided`, `schema`, `models_dispatched`, `models_responded`, `models_failed`, `output_dir`, `totals`. Missing: `aliases` (v2.1.0+ per `methodology.md:178`), `consolidation` subsection (dedup_merges, score_aggregations, unresolved_conflicts per `methodology.md:167-171`), `phases_completed` (per `methodology.md:172`), `schema_auto_injected` (v2.1.0+ per `methodology.md:177`). **Four fields missing from the "canonical" file that the other file treats as required.**
- **No validator or linter is referenced.** The markdown formatting rules are CRITICAL ("CRITICAL for WYSIWYG viewer compatibility" line 231) but the skill doesn't ship a `lint-output.sh` or `validate-markdown.py`. A model that produces `**direct***` won't be caught. The rules are advisory only.
- **The conflict-marker legend (line 72-73) is inconsistent with the conflict table (line 121-124).** Line 73 says "`value*` = field conflict" (asterisk). Line 122-123 uses "rule 4 (outlier downgrade)" and "rule 3 (strict)" — rule numbers, not rule names. The conflict-marking scheme in the table body is "field conflict" (asterisk), but the resolution column is "rule N (description)" — and the rule library uses names (`most-severe`, `majority-with-uncertain`, etc.), not numbers. **Three different reference schemes for the same thing.**
- **`§8 Synthesized Verdict` is marked "(optional, both modes)"** (line 161). Who decides when it's rendered? The user prompt may or may not have asked for one. The "Skip if no synthesis possible" rule is implicit.

**What is unclear or ambiguous:**
- §2A says "render the consolidated items in a markdown table matching the schema's columns" (line 55). For a `text` column with `max_words: 50`, that's 50 words crammed into a table cell — hostile to rendering. §3 "Per-Item Details" (line 100) is the right home for long text. But the schema doesn't say "render text columns in §3, not §2A." The skill has the data model but not the rendering rule.
- The "Dispatch note" line 34 in the file header is supposed to capture harness quirks. But it's a free-text field in a markdown file — it doesn't machine-parse. The manifest would be a better home.

---

### 1.6 `rules/examples/research-prior-art.md` (185 lines)

**What works well:**
- The 14-entry alias map (lines 125-140) is the only concrete, in-skill example of a real alias set. The pairs (`AutoGen/AG2`, `MAF/Microsoft Agent Framework`, etc.) are non-trivial and surface real ambiguity in the model outputs.
- The scoring rubric (lines 102-119) is a complete 8-dimension research evaluation framework that is the foundation of the worked example's "closest match" section.
- "Variations to try" (line 180-185) is honest about the unknowns: "diminishing returns past 6 (this is an empirical observation, not a measured curve)."

**What is missing or wrong:**
- **Schema/scoring-rubric enums are inconsistent.** The schema at line 87 has `parent_worker_split: ["yes", "partial", "no"]`. The scoring rubric at line 111 has `parent_worker: ["no", "partial", "explicit orchestrator/worker"]`. The two are describing the same dimension with different value sets: a model scoring by the rubric would output `no/partial/explicit orchestrator/worker`; the schema's `parent_worker_split` field would reject `explicit orchestrator/worker` as not in `values`. **The rubric and the schema don't reconcile.**
- **"Reference subject" skip rule is not robust.** Line 147: "The reference subject's own name (e.g., 'Silver Bullet') if the task compares candidates against it — it's the comparison anchor, not a candidate." But the skill has no way to know the reference subject from the prompt. A user invoking `/multi-ai-task "find alternatives to X"` would need to also pass `--skip-reference X` or similar. The skip is undocumented in the contract.
- **The bash dispatch (line 22) hardcodes 6 model IDs.** A user wanting to vary the model set has to edit the loop. No comment says "substitute your own 4-6 models" — and the example uses 6 specific OCG models that may not be the user's available set.
- **Line 184 recommends running in `thorough` mode** but `SKILL.md:84` says "Do not use [thorough] for routine ideation or code review." The research example recommends it, the SKILL.md discourages it for "routine" tasks. The boundary is unclear.

**What is unclear or ambiguous:**
- The scoring rubric at lines 102-119 has `max_total: 16`. The example aggregation in the research example might not have hit 16 because not all 8 dimensions were scored by all 6 models. The reconciliation between the schema's per-row scoring and the rubric's total is not documented.
- Line 174-177 points to the actual run output files (`prior-art-landscape-*.md`), but the disk also has `prior-art-report.md`, `prior-art-landscape-report.md`, and `prior-art-landscape-research.md` — which one is the "real" consolidated output? The example says `SB_CONSOLIDATED_PRIOR_ART_REPORT.md` is canonical but the disk has multiple candidates.

---

### 1.7 `rules/examples/code-review.md` (111 lines)

**What works well:**
- The security note at line 45 ("READ-ONLY ONLY") is correctly aligned with `dispatch-mechanics.md:56` (`--dangerously-skip-permissions` is fine for read-only).
- The custom-strategies table (lines 93-101) is concrete: `severity: most-severe`, `category: majority`, `description: longest-with-quote`, `evidence: concatenate-all`, with a rationale per row.
- Composite primary key example (lines 53-55 + 70) is the right way to express file:line dedup; the deprecation note at line 70 ("the old `'primary_key': 'file:line'` is wrong") is good self-correction.

**What is missing or wrong:**
- **No worked example.** Line 110: "Not yet produced (deferred to v2.2.0)." The skill is marketed in `SKILL.md:3` as a code-review tool, but the only worked example in 8 files is the research one. A user picking code-review as their first use case has to extrapolate from research, which is a non-trivial mapping.
- **The "Pre-commit hook" variation at line 106** explicitly says: "(NOT currently supported as a built-in dispatch; requires custom runner)." This is a gap the example acknowledges and doesn't address.
- **The output structure (lines 82-90) has 7 sections** but `output-schema.md` has 8 sections (§1-§8) plus Appendices. The example is silent on §8 ("Synthesized Verdict") and the Appendices (A, B) — should code review produce these?

**What is unclear or ambiguous:**
- The `severity_order` customization (line 74-78) says: "If a reviewer adds a custom severity (e.g., `critical`), declare it in the schema." But the schema's `severity: "most-severe"` rule (line 62) doesn't reference `severity_order`. Where does `severity_order` go in the schema? The schema syntax at `SKILL.md:108-112` only shows `conflict_resolution` as a top-level field — no `severity_order` is shown. **Is `severity_order` a sibling of `conflict_resolution`, or a key inside it?**
- The output structure line 88 says "§5 Per-Reviewer Statistics" — but the schema has no `model_id` or `reviewer` field. The data has to come from the `model` field in `structured.jsonl`, but that's not obvious from the schema.

---

### 1.8 `rules/examples/fact-check.md` (113 lines)

**What works well:**
- The `majority-with-uncertain` customization (line 67 + 75) is the right rule for high-stakes fact-checking; "do not guess" is a real safety property.
- The parameterized consensus thresholds (lines 103-109) are honest about the math: `max(2, ceil(N/2))` for N=3 is 2, for N=5 is 3.
- `unverified` is correctly treated as a first-class verdict (line 76), not a failure.

**What is missing or wrong:**
- **"N>=3" claim is wrong.** Line 37: "Dispatch to N models (use 4-5 for fact-check; majority-with-uncertain needs N>=3)." For N=3, the threshold is `max(2, ceil(3/2)) = 2`, so 2 of 3 models agreeing is sufficient. The skill works fine with N=3. The "N>=3" line is misleading.
- **No worked example.** Line 112: "Not yet produced (deferred to v2.2.0)." Same gap as code-review.
- **The `confidence: "lowest-of-majors"` rule description is ambiguous.** Line 75: "When in doubt, downconfidence (use the lowest confidence among the majority verdict)." But "the majority verdict" is singular — and `lowest-of-majors` operates on a list of confidence levels among the voters. If 4 of 6 say `true` with `[high, high, medium, low]`, the rule returns `low`. If 2 of 6 say `true` with `[high, high]`, the rule returns `high`. The rule's "lowest" depends on how many voters are in the majority; the description doesn't make this explicit.
- **`sources: "url_list"` is described at line 78 as "now formally defined in the schema spec (was a v2.1.0 gap)."** But `url_list` is listed in the `SKILL.md:125` table as a supported type, and the conflict rule `union-dedup` (consolidation-rules.md:211) is the default for `url_list`. Where was the v2.1.0 "gap" exactly? The change-history isn't documented.

**What is unclear or ambiguous:**
- The "Consensus requirements" (lines 101-109) defines three outcomes: `confirmed`, `debunked`, `unverified`. The schema enum at line 61 is `["true", "false", "partially-true", "unverified"]`. **Are `confirmed` and `true` the same? Are `debunked` and `false` the same? What about `partially-true`?** The consensus rules don't reference the schema's enum.
- The dispatch (line 38) hardcodes 3 models but the recommendation (line 37) says "4-5." Why the discrepancy? The example doesn't work as written if you follow the recommendation.

---

## §2. 8-Dimension Rubric Score

The skill defines its own scoring rubric (`research-prior-art.md:102-119` and `consolidation-rules.md`). I score it on that rubric.

| Dimension | Score | Justification |
|---|---|---|
| **Catalog of composable units** | 1 | The skill has a named-rule library (8 conflict-resolution rules at `consolidation-rules.md:167-221`) and an example set, but no machine-readable catalog of "what workflows the skill can compose." A user has to read the prose to know that code-review, fact-check, and research are the supported patterns. There's no `CATALOG.md` or machine-readable list. |
| **Dynamic composition** | 0 | The skill is a single-shot dispatch — no replanner, no audit log of past runs that the skill reads to inform the next composition. `methodology.md:208` explicitly says "incremental consolidation" is a "future enhancement." A user who runs the skill twice doesn't get smarter the second time. |
| **V-loop depth** | 1 | The skill produces a single consolidated artifact per run, which is end-tested (it can be re-run). But there's no per-step rollup (each of the 4 phases is not individually validated before the next runs) and no intent gate. The verifier pass in `thorough` mode (`SKILL.md:82`) is a partial V-loop, but it only runs after the whole pipeline; it's not a per-step rollup. |
| **Enforcement** | 0 | The markdown formatting rules at `output-schema.md:231-242` are CRITICAL but are not enforced. There's no linter, no validator, no CI hook. The skill is "honor system" for output correctness and "honor system + shell exit code" for failure detection. The schema validation in `methodology.md:69-72` is a paragraph, not an implementation. |
| **Parent/worker split** | 2 | The 4-phase pipeline (methodology.md) is an explicit orchestrator/worker split. Phase 1 dispatches workers (parallel model calls). Phase 2-4 orchestrate. The run-manifest's `phases_completed` array (methodology.md:172) tracks the orchestrator's progress. This is a clean, explicit, well-named split. |
| **Evidence model** | 1 | Per-row `source_refs` (`consolidation-rules.md:39`) and the `evidence` field in the schema are informal evidence. The `thorough` mode adds a verifier call per claim (SKILL.md:82) and produces `evidence-ledger.md` — this is tiered sufficiency. But the default mode is informal; only `thorough` gets you tiered. Score 1 (informal in default, tiered in thorough). |
| **SE + DevOps unified** | 1 | The skill covers "code review" (`examples/code-review.md`) and "research" (which can be DevOps-adjacent via IaC, deployment, etc.). But there's no DevOps-specific example (e.g., IaC review, deployment plan review, blast-radius review). The skill covers one domain well (research/code/decision support) and partially the other (no DevOps recipe). |
| **Team customization** | 0 | Alias maps are task-specific and the user must build them per run (`consolidation-rules.md:80-91`). The `--schema` is user-supplied JSON, not a packaged "overlay pack." The skill has no "process pack" or "overlay" concept. A team that wants to standardize fact-checking across the org would have to fork the skill to add a default fact-check schema. |

**Total: 6 / 16**

---

## §3. Top 5 Improvements (ranked by impact × effort)

### Improvement 1: Reconcile the two `run-manifest.json` schemas

- **Issue:** `output-schema.md:209-227` and `methodology.md:149-174` define different `run-manifest.json` schemas. `output-schema.md` is declared canonical at `methodology.md:147` but is missing 4 fields the methodology version requires (`aliases`, `consolidation`, `phases_completed`, `schema_auto_injected`).
- **Why it matters:** Any tool that consumes `run-manifest.json` based on the "canonical" schema will silently drop the alias map and the per-phase audit trail. The skill's reproducibility story (re-runnable, auditable) depends on this file.
- **Concrete change:**
  - In `output-schema.md:209-227`, add the missing fields:
    ```json
    "schema_auto_injected": true,
    "aliases": {"AutoGen/AG2": "AutoGen"},
    "consolidation": {
      "dedup_merges": 12,
      "score_aggregations": 25,
      "unresolved_conflicts": 0
    },
    "totals": {
      "phases_completed": [1, 2, 3, 4],
      "rows_per_model": {"m1": 25},
      "unique_items_consolidated": 36,
      "conflicts_resolved": 8
    }
    ```
  - Update `methodology.md:147` if the canonical location moves; or keep `output-schema.md` as canonical and bring its schema to parity with `methodology.md`.
- **Effort:** low
- **Impact:** high
- **Score:** 3.0 (high / low)

### Improvement 2: Produce worked examples for code-review and fact-check

- **Issue:** Both `code-review.md:110` and `fact-check.md:112` say "Not yet produced (deferred to v2.2.0)." The skill markets 3 use cases (research, code-review, fact-check) in `SKILL.md:3` but only has 1 worked example. A user picking code-review or fact-check has to extrapolate from research.
- **Why it matters:** Worked examples are the difference between a "skill I can use" and a "skill I have to study." The research example proves the pattern works for research; the other two are recipes without proof.
- **Concrete change:**
  - Add a `code-review-worked.md` and `fact-check-worked.md` under `rules/examples/` (or `rules/examples/worked/`). Each should:
    - Reference actual output files (the failed r3 self-review shows the file structure).
    - Show a real per-model `structured.jsonl` excerpt.
    - Show a real `consolidated.md` excerpt (not just the section headers).
    - Document a real `conflicts.md` entry.
  - Alternatively, add a "v2.2.0 milestone" entry in the SKILL.md to make the gap visible in the version changelog, not buried in two example files.
- **Effort:** medium (requires running the skill end-to-end twice)
- **Impact:** high
- **Score:** 2.0 (high / medium)

### Improvement 3: Add a working `--concurrency sequential` example

- **Issue:** `SKILL.md:69` declares `--concurrency` as a parameter, but `dispatch-mechanics.md` shows only parallel dispatch. The MCP port-collision caveat at `dispatch-mechanics.md:102-103` is real but undocumented in the SKILL.md. Users who hit port collision have no example to copy.
- **Why it matters:** The flag is in the contract. The implementation pattern is missing. A user following the docs cannot implement sequential dispatch.
- **Concrete change:**
  - Add a sequential bash example to `dispatch-mechanics.md` (right after line 49, before the parallel/sequential table at line 95):
    ```bash
    OUT=./out/$(date +%Y%m%d-%H%M%S)
    mkdir -p "$OUT"
    for model in opencode-go/minimax-m3 opencode-go/qwen3.7-max; do
      slug=$(echo "$model" | cut -d/ -f2)
      npx -y opencode-ai run \
        --model "$model" \
        --title "multi-ai-task-${slug}-$(date +%s)" \
        --dangerously-skip-permissions \
        "$PROMPT" \
        > "$OUT/${slug}.md" 2> "$OUT/${slug}.err"
    done
    echo "Outputs in $OUT/"
    ```
  - Note explicitly that sequential eliminates MCP port collision risk (mostly).
- **Effort:** low
- **Impact:** medium
- **Score:** 2.0 (medium / low)

### Improvement 4: Add a markdown-output validator script

- **Issue:** `output-schema.md:231-242` lists 7 "CRITICAL" markdown formatting rules (no bare `*`, blank line around tables, etc.) but the skill has no validator. The rules are advisory; a model that produces `**direct***` won't be caught.
- **Why it matters:** The formatting rules are the difference between a report that renders in a WYSIWYG viewer and one that's a wall of text. Without a validator, the contract is "the skill tries to follow these rules" — not "the skill enforces these rules."
- **Concrete change:**
  - Add a `scripts/validate-output.sh` (or `tests/scripts/check-consolidated-markdown.sh` to fit the repo's test layout) that:
    - Checks every table for `|---|` separator and matching header/cell count.
    - Checks no `***` triple-asterisk in any cell.
    - Checks blank line before/after every table.
    - Returns non-zero on first violation.
  - Wire it into the failure-modes table at `SKILL.md:218-229` and `dispatch-mechanics.md:120-130` as a "model produced malformed markdown" symptom with a fix to run `validate-output.sh`.
- **Effort:** medium
- **Impact:** medium
- **Score:** 1.0 (medium / medium)

### Improvement 5: Fix the `lowest-of-majors` ambiguity and split the "evidence-then-newer-then-strict" rule

- **Issue:** Two rule-definition issues:
  - `consolidation-rules.md:188-190` — `lowest-of-majors` doesn't say whether the confidence order is `high > medium > low` (high is "best" so lowest is "most-cautious") or `low < medium < high` (low is "index 0" so `min` returns low). The rule is a 1-line ambiguity.
  - `consolidation-rules.md:155-161` — `prefer-with-evidence-then-newer-then-strict` has 4 steps but the name has 3. The "outlier rule" (step 3) is silently inside a 3-name rule.
- **Why it matters:** These are the named rules that go into user schemas. A user passing `"severity": "most-severe"` trusts that the algorithm is unambiguous. If `lowest-of-majors` is ambiguous, a user schema that depends on it for `confidence` may get different results in different implementations.
- **Concrete change:**
  - In `consolidation-rules.md:188-190`, change to:
    ```
    **Algorithm:** first apply `majority` to get the majority value; then among the models
    voting for that value, return the confidence with the highest "caution" (i.e., the
    lowest confidence on a `high > medium > low` ordering; `low` is most-cautious).
    ```
  - In `consolidation-rules.md:155-161`, rename the rule or split it:
    - Option A: `evidence-then-newer-then-outlier-then-tiebreak` (4 names; matches 4 steps)
    - Option B: Split into two rules: `with-evidence` (steps 1-2) and `outlier-downgrade` (step 3) and `tiebreak` (step 4). Then the schema can compose them.
- **Effort:** low
- **Impact:** medium
- **Score:** 2.0 (medium / low)

---

## §4. Open Questions

These are the questions I would need answered to make a more confident review.

1. **Is the r3 self-review (the one I'm running now) a known failure mode?** `docs/research-260624/multi-ai-self-review-r3-20260627-095647/` has 0-byte model output files. The previous r3 attempt (same prompt) didn't complete. **Is the skill's recursive use case (skill reviews itself) actually working, or is it aspirational?** If r3 doesn't produce output, the SKILL.md "Proven provenance" section (`SKILL.md:236-248`) is a lie about the meta-task.

2. **What is the intended runtime?** The skill is `user-invocable: false` (`SKILL.md:5`) but the Usage line (`SKILL.md:57`) shows `/multi-ai-task` slash-command syntax. Is this a slash command the user types? An agent-internal tool? Both? The 4 dispatch mechanisms (`dispatch-mechanics.md`) are bash-fork (`opencode run`), agent-task (`task` tool), HTTP SDK, and direct HTTP. **Is the skill run by a user, by an agent, or by another skill?** The answer changes which dispatch mechanism is "the default."

3. **Is the "task-agnostic" claim real or aspirational?** The skill has 1 worked example (research) and 2 "deferred" examples (code-review, fact-check). The output-schema has task-specific fields baked into the example (`gaps_vs_sb`, `sb_gaps_vs_them` at `research-prior-art.md:89-90`). **Is the skill actually task-agnostic, or is it "research with code-review and fact-check as aspirational adjacent uses"?**

4. **What is the consumer of `run-manifest.json`?** The schema is duplicated and inconsistent. But who reads it? If no tool reads it, the inconsistency doesn't matter and the field set is over-specified. If a tool reads it, the inconsistency is a real bug. **What tooling depends on the manifest?**

5. **Is the v2.1.0 changelog documented anywhere?** `SKILL.md:6` says `version: 2.1.0` but I see no changelog. `methodology.md:177-178` mentions "v2.1.0+" for `schema_auto_injected` and `aliases`, but the provenance section at `SKILL.md:236-248` doesn't say what changed. **What is the diff from 2.0.0 to 2.1.0?**

6. **Why is `output-schema.md` declared canonical at `methodology.md:147` if it's the file that's wrong?** This looks like an authoring mistake — `output-schema.md` may have been written first and `methodology.md` later, with the canonical declaration copied without verifying parity. Or vice versa. **Which file was written last?**

7. **The `aliases` field semantics: are they applied as `aliases[alias] = canonical` (string-to-string) or `aliases[primary_key] = null` (string-to-null) for skip?** Both forms appear in `consolidation-rules.md` (lines 87-91 and 115). **What is the actual data structure?**

8. **The r3 run produced empty `.md` files but populated `.err` files showing the model was reading the skill files.** Was the model timed out? Did the model decide not to respond? Did the dispatch fail silently? **The 0-byte output is a data point about skill failure modes that the failure-modes table doesn't cover.**

---

## §5. Confidence

**Overall confidence: medium**

I read all 8 files, cross-referenced them, verified the run output on disk, and read the consolidated report. I found real issues (run-manifest schema drift, missing worked examples, undefined extractor model) and concrete improvements. But:

- I did not run the skill end-to-end myself. I cannot verify that the bash examples in `dispatch-mechanics.md` and the examples work as written.
- I cannot verify the v2.1.0 changelog because there is no changelog.
- The "extractor model" is defined in pseudocode and prose but the actual implementation may behave differently than the spec.

**What would change my assessment:**

- If a real `run-manifest.json` from the prior-art run exists on disk and matches the `output-schema.md` schema (not the `methodology.md` schema), then the "output-schema.md is canonical" claim is correct and `methodology.md` is the file with the bug. My review would still flag the duplication but the severity would drop.
- If a tested `scripts/validate-output.sh` exists somewhere I didn't find, the "no validator" finding in Improvement 4 is wrong and Impact drops to low.
- If the r3 self-review folder is a known abandoned run (i.e., a deliberate test of failure handling), then the "Proven provenance" section's omission of r3 is intentional and the missing example is a deliberate gap, not an oversight.
