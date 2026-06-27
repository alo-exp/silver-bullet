# multi-ai-task v2.1.0 — Critical Self-Review (Round 3)

**Reviewer orchestration:** meta-task — the skill reviewed itself via its own dispatch mechanics.
**Date:** 2026-06-27
**Confidence:** high (based on full file read + cross-reference analysis + algorithm walkthrough)

---

## §1. Critical Assessment

### 1. SKILL.md

**What works well:**
- The when-to-use / when-not-to-use decision table (lines 35-50) is concrete and honest — "Cost of N× compute is acceptable", "You have ≤1 model available" are real tradeoffs, not marketing.
- The mode semantics table (lines 77-81) clearly defines what each mode skips/adds — quick/skip-conflict, standard/dedup+conflict, thorough/cross-source-verification.

**What is missing or wrong:**
- **No executable code, not even a reference implementation.** The skill is 255 lines of prose + pseudocode. An agent consuming this skill must re-implement all 4 phases from scratch every time. Given that consolidation rules are described as "the core value of the skill" (line 195: `"These are the core value of the skill; everything else is plumbing"`), they deserve an implementation, not just pseudocode. The `consolidation-rules.md` pseudocode (lines 96-111) isn't runnable — it references `normalize()`, `canonical`, and `fields_per_model` without defining them.
- **`score-aggregate.md` noted as "planned but not in the contract"** in the failure modes table (line 227: `"Output dir contains score-aggregate.md (planned) but not in the contract"`). This is not a *failure mode* — it's a spec inconsistency documented in the wrong place. It should be a roadmap item or removed.
- **Version inconsistency:** SKILL.md frontmatter declares `version: 2.1.0` (line 6) but the task framing around this review says v2.0.0. If the intent is 2.1.0, the tag should be consistent across all references. The self-review round-2 output (line 247) claims v2.1.0; if that self-review produced changes, they should be reflected in the version number — but the version was already 2.1.0 *before* round 2, suggesting the round-2 review didn't change anything or the version was pre-bumped incorrectly.

**What is unclear or ambiguous:**
- **Who is the intended audience?** The SKILL.md reads as a human reference document (argument tables, CLI syntax, "Usage" section) but the pseudocode and dispatch mechanics read as LLM-agent instructions. If this is for both, the dual nature should be explicit. If for agents only, the human-oriented sections (like the mode semantics table) are verbose padding.
- **HTML generation is underspecified.** Lines 174-175 say `"convert consolidated.md to HTML using a markdown library (marked in Node, markdown in Python, pandoc for richer output)"`. Three different tools, no priority, no CSS specification, no implementation. Which tool does the orchestrator actually use? If Node exists, use `marked`; if Python, use `markdown`; if neither, what's the fallback?

---

### 2. methodology.md

**What works well:**
- The 4-phase pipeline is well-structured and the phase boundaries are clear.
- The extraction pseudocode (lines 37-65) is the most concrete algorithm in the entire skill — it covers 4 fallback paths with relative priority.

**What is missing or wrong:**
- **"Extractor model" selection is undefined.** Lines 52-53: `"extractor model" = the slowest/highest-capability model from the dispatch"`. There is no metric for "highest capability" — is it reasoning score? Parameter count? Benchmarks? The orchestrating agent has no way to compute this. The SKILL.md (line 152) repeats the same phrase without adding specificity. This is a critical dependency — if extraction fails and the extractor model is chosen wrong, the entire pipeline produces garbage.
- **Fallback path 4 ("one-row-per-paragraph") is "very lossy"** but there's no quality gate — no threshold for when to reject the output entirely vs. produce a degraded result. Line 62: `"Only use if all other paths fail AND the response is paragraph-shaped."` The orchestrator must decide "is this good enough to include?" with zero guidance.
- **Row validation drops rows silently.** Lines 70-72: `required: true` fields missing → drop row; `type` constraints violated → drop row; `max_words` exceeded → truncate. But these losses are not summarized anywhere in `run-manifest.json` or `consolidated.md`. The user never learns how many rows were dropped or why.
- **Phase 3 writes `structured.jsonl` in "append mode"** (line 118: `"append mode with model: _consolidated"`). If the orchestrator crashes mid-write, the file is in a corrupt state (half-written JSON line). No atomic write strategy or recovery mechanism.
- **Disclaimer says "Generic by design. The skill makes ZERO assumptions about the task type"** (line 154). But Phase 2's table-extraction tips (consolidation-rules.md lines 44-49) assume a 10-16 cell summary table starting with `#` or `name`. That's a strong research-task assumption that fails for code-review (file:line composite key) and fact-check (claim_id as primary key).

**What is unclear or ambiguous:**
- **Phase 1 says models "have their own tool/MCP context"** (line 12: `"Has its own tool/MCP context (e.g., webfetch, ctx_fetch_and_index, gh)"`). Does this mean the orchestrator is responsible for ensuring each model has access to the right tools? Or does the dispatch mechanism handle this automatically? This is implementation-specific and not addressed.
- **"Caches the response, no extra cost"** for the extractor model (line 104). Caches *where*? The orchestrating agent's session? A file on disk? This is another "trust me" detail that every implementer must figure out independently.

---

### 3. dispatch-mechanics.md

**What works well:**
- 4 concrete dispatch mechanisms with clear tradeoffs and a recommended default (Mechanism 2). The "Choosing the right mechanism" decision table (lines 173-181) is the best decision-support artifact in the entire skill.
- The Proven Provenance section references a real run that worked, building credibility.

**What is missing or wrong:**
- **Mechanism 2 bash script is unsafe for general prompts.** Lines 43-53 pass `"$PROMPT"` directly to `npx` without escaping. If the prompt contains `$`, backticks, `"`, `\`, or newlines, the shell will interpret them before `npx` sees them. The heredoc approach shown in code-review.md (lines 20-30: `cat > "$OUT/prompt.md" <<'PROMPT'`) is the correct pattern, but it's not used in the main dispatch section. This is a well-known shell injection hazard and will surface the first time a user includes a code example in their prompt.
- **`cut -d/ -f2` slug extraction is format-dependent.** Line 44: `slug=$(echo "$model" | cut -d/ -f2)` assumes exactly 2 `/`-separated segments (`provider/model`). For 3-segment IDs like `opencode/go/minimax-m3` or `anthropic/claude-sonnet-4-20250514` (which has hyphens but still 2 segments), this silently truncates or misidentifies. The skill should either document the exact format constraint or use a more robust extraction (e.g., `echo "$model" | sed 's|.*/||'`).
- **Mechanism 1 references specific source files and issue numbers** from the OpenCode project. Line 28: `"packages/opencode/src/tool/task.ts"` and 6 issue numbers (#6651, #11215, #17595, #26925, #29984, #32730). These are implementation details of one specific harness and will rot within months. If the skill is harness-agnostic, these references don't belong here. If it's OpenCode-specific, the frontmatter should say so.
- **"Missing credential handling" contradicts the fail-soft principle.** Lines 151-152: `"The skill does NOT automatically skip to a fallback model — the user must explicitly omit the model from --models if they want to skip it."` But the failure handling section (lines 122-123) says `"The skill is fail-soft: a model failure is logged, the model is excluded from the consolidation."` A missing credential IS a model failure. Why treat it differently? This creates an unnecessary manual step.
- **"MCP port collision caveat" prescribes restarting MCPs** (line 106: `"restart the MCP between dispatches"`) but offers zero code or guidance on how. The orchestrating agent doesn't know which MCPs are running, which hold ports, or how to restart them.
- **Mechanism 3 "Known bug"** references issue #18615 on the OpenCode repository. Same harness-dependency problem as Mechanism 1.

**What is unclear or ambiguous:**
- **"OpenCode server"** (line 66: `"If you have an OpenCode server running"`) — what is this? Is it `opencode serve`? A hosted service? The term is used without definition, and it's different from the "OpenCode harness" used in Mechanism 1.
- **Latency budget undefined.** Line 104: `"choose parallel if N × per_model_time ≤ your latency budget"`. The skill never defines a latency budget heuristic. Is it 5 minutes? 30 minutes? The user provides `--mode` but not a `--timeout` flag for the total run — that's an implementation detail the orchestrator must guess.

---

### 4. consolidation-rules.md

**What works well:**
- The named rule library (lines 167-221) is the strongest part of the entire skill. Each rule has a purpose, algorithm, and edge-case handling. This is genuinely implementable.
- The conflict resolution table format (lines 227-234) is concrete and copyable.
- Alias mapping is properly scoped as task-specific (lines 325-334: `"The alias map is task-specific, not part of this skill's core"`).

**What is missing or wrong:**
- **CRITICAL BUG: `majority-with-uncertain` algorithm contradicts its documentation example.** The algorithm (line 183): `"require ≥ max(2, ceil(N/2)) models to agree"`. For N=3: `max(2, ceil(3/2)) = max(2, 2) = 2`. So 2 votes of `true` with 1 vote `false` → threshold met → returns `true`. But the documented example (line 233) says:
  ```
  | claim X | verdict | 2 say true, 1 says false | majority-with-uncertain (threshold not met) | unverified | high |
  ```
  "(threshold not met)" is wrong for N=3. The fact-check example (line 74) also says: `"if 2 say true and 1 says false, default to unverified rather than true"` — which also contradicts the algorithm. Either the algorithm should use `ceil(N/2) + 1` as the threshold, or the documentation examples need fixing. The algorithm IS the spec; the examples are wrong.
- **Confirmation bias: `majority-with-uncertain` with N=1 always returns `unverified`** (line 184: `"with N=1, single vote never reaches the threshold"`). The threshold `max(2, ceil(1/2)) = max(2, 1) = 2 > 1`, so yes, always `unverified`. This means the skill silently fails for single-model fact-check without warning the user. The fact-check example recommends N≥3 (line 37) but doesn't explain *why* beyond "majority-with-uncertain needs N>=3" — it should explicitly warn that N=1 is useless and N=2 is barely viable.
- **`merge-exact` rule is redundant with `dedup_key: true`.** Lines 217-221 define `merge-exact` for "composite-key dedup" but `dedup_key: true` on multiple columns already handles composite keys at the registry level (the dedup algorithm groups by canonical primary key). The `merge-exact` rule describes the same thing twice. It's listed as a conflict-resolution rule, but it's really a dedup mechanism, not a conflict resolver.
- **Score aggregation never warns about low-N statistics.** Lines 250-256 compute `median` and `range` but with N=2, median = average (not robust to outliers). With N=3 (fact-check example), median is the middle value which IS robust, but the range is useless (just the two extremes). With N=4, median = average of middle two. The skill should either require N≥5 for meaningful score aggregation or warn that low-N medians are unreliable.
- **Phase numbering is confusing.** "Phase 3.5" and "Phase 3.6" are sub-phases of Phase 3, but the main phases are numbered 1-4. This non-standard notation (decimal sub-phases) is harder to search and reference than "Phase 3a" or "Phase 3: Resolve" and "Phase 3: Score".

**What is unclear or ambiguous:**
- **Relationship between the 8-dimension scoring rubric (research-prior-art.md line 106-118) and the skill's own evaluation rubric (§2 of this review).** The skill defines a scoring rubric in the research example, but the rubric is *about* evaluating tools. Then this review uses it to evaluate the skill itself. Is this rubric part of the skill, or part of the example? The consolidation-rules.md doesn't define a scoring rubric — only the research example does.
- **"Cross-AI Dedup Instructions"** are mentioned in the research prompt template (research-prior-art.md line 63) but never defined. The prompt says `"normalize names, resolve conflicts, scoring rubric"` as a prose instruction to models, not an algorithm the orchestrator runs. This conflates model instructions with orchestrator logic.

---

### 5. output-schema.md

**What works well:**
- `run-manifest.json` schema (lines 212-236) is fully specified with field semantics and is cross-referenced from multiple files. This is the "single source of truth" pattern done right.
- WYSIWYG formatting rules (lines 259-269) are practical and specific — they address real rendering issues.
- Conflict marker convention (line 73-75: `"value* = field conflict"`) is simple and actionable.

**What is missing or wrong:**
- **`consolidated.html` generation has zero specification.** The SKILL.md mentions it (line 174-175) and the methodology says "self-contained HTML render" (line 135), but output-schema.md — the file that defines output structure — never specifies HTML generation. No CSS rules, no template, no rendering pipeline. The field that documents "Supporting files" (lines 193-254) lists `conflicts.md`, `structured.jsonl`, and `run-manifest.json` but not `consolidated.html`. The HTML deliverable is effectively undefined.
- **§2A "Fields per model" column is unreadable at scale.** Line 67: `"m1: {cat: direct, score: 3}; m2: {cat: adjacent, score: 5}"`. With 6 models and 10 fields each, this column would be 200+ characters per cell — completely unreadable in a markdown table. No truncation, no tooltip, no "see per-item details" reference.
- **`task_prompt_hash` encoding is unspecified.** Line 242: `"sha256: of the prompt bytes"`. SHA-256 produces a 256-bit hash. Common representations are hex (64 chars) or base64 (44 chars). The `sha256:` prefix is documented but the encoding isn't. Different agents will produce different hashes for the same prompt.
- **"Composite primary keys" concept (SKILL.md:143) is absent from output-schema.md.** The SKILL.md describes `"list multiple columns with dedup_key: true"` and code-review.md says `"Composite primary key: file AND line both have dedup_key: true"` but output-schema.md, the file that defines the schema, never mentions composite keys. This is a cross-reference gap.
- **"Coverage Scoreboard" bucketing is undefined.** Lines 181-189 define the scoreboard format with "Bucket" as a column, but "bucket" is never defined anywhere in the skill. The research example implies per-category buckets, code-review implies per-file buckets, fact-check implies per-verdict buckets. Without a bucketing definition, every run produces incomparable scoreboards.
- **`mode: "thorough"` output files are listed but not designed.** Lines 170-171: `"evidence-ledger.md (thorough mode only)"` and `"verification.md (thorough mode only)"` are listed in the output structure but never specified anywhere in output-schema.md. The thorough mode section mentions them (SKILL.md:81) but their format, columns, and relationship to each other are undocumented.

**What is unclear or ambiguous:**
- **"WYSIWYG viewer"** (line 260: `"The consolidated report must be WYSIWYG-safe"`). Which WYSIWYG viewer? GitHub? Obsidian? Typora? VS Code preview? Each has different rendering quirks. The rules describe general GFM, but the term "WYSIWYG viewer" is ambiguous enough that the precautions may not apply to the actual viewer the user has.
- **§2A vs §2B** — have the same section number (§2) with an A/B suffix. This makes cross-referencing fragile. If you cite "§2 Items Table", the reader has to guess which variant.

---

### 6. rules/examples/research-prior-art.md

**What works well:**
- Complete end-to-end worked example with actual provenance — the run on 2026-06-27 produced real output. This is the only example with evidence of execution.
- Alias map with 14 entries (lines 125-140) is practical and shows real-world dedup patterns.
- Skip rules (lines 145-148) are task-specific and well-scoped.

**What is missing or wrong:**
- **The research prompt template (lines 37-68) claims to be generic but is Silver Bullet-specific.** Line 41: "What SUBJECT Built" uses a placeholder, but the "2C dimension-specific probes" and "subject catalog snapshot for calibration" sections are SB-specific architecture questions. A user adapting this for a different subject would find the template confusing — the skeleton doesn't match the actual content from the proven run.
- **Alias map format is inconsistent.** Some entries are simple (line 127: `"Camunda, Camunda 8 | Camunda 8"`), others are compound (line 126: `"MAF, Microsoft Agent Framework (MAF) | Microsoft Agent Framework"`), and one is slash-separated (line 125: `"AutoGen/AG2, AutoGen (maintenance) | AutoGen"`). The format isn't standardized — the pipe delimiter separates alias list from canonical, but some entries have commas and slashes within the alias list. This makes parsing the alias map programmatically unreliable.
- **"Variations to try" claims diminishing returns past 6 models without evidence** (line 182: `"diminishing returns past 6 (this is an empirical observation, not a measured curve — run your own benchmark if you want a hard number)"`). If it's an empirical observation, it should cite data. If it's speculative, it should be removed. The parenthetical disclaimer undermines the claim while keeping it — this is simultaneously an assertion and a retraction.
- **Scoring rubric `max_total: 16`** (line 117) assumes all 8 dimensions are scored at level 2. But the rubric explicitly marks two dimensions as N/A for skills (SE+DevOps unified, Team customization). The research run scored only applicable dimensions, so `max_total` is misleading — it should be per-task variable.

**What is unclear or ambiguous:**
- **The "Reference Context" section** (line 69: `"subject catalog snapshot for calibration"`). What format is this? A JSON file? A markdown table? The template doesn't say, and the proven run output doesn't clarify.
- **The relationship between the "Research Questions" (line 45) and "Required Output Schema" (line 52).** The prompt says to answer research questions, but the schema defines a comparison table. How do free-text research questions map to table columns? The example says "the schema auto-injected this" but doesn't show how.

---

### 7. rules/examples/code-review.md

**What works well:**
- **Strong correction of bad pattern.** Lines 70-71 explicitly document why `primary_key: "file:line"` (a concatenated string) is wrong versus `dedup_key: true` on two columns. This is exactly the kind of concrete guidance that makes the skill usable.
- Security note (lines 45-46) correctly distinguishes read-only review from write tasks and maps to the appropriate flag.

**What is missing or wrong:**
- **"Worked example: Not yet produced (deferred to v2.2.0)"** (line 111). The example is advertised as a worked example but is entirely hypothetical. The skill is at v2.1.0 and the most important non-research use cases (code review, fact-check) have no proven runs. This makes the "task-agnostic" claim unvalidated.
- **Coverage gaps output is aspirational, not implementable.** Line 89: `"§6 Coverage Gaps (lines/areas no reviewer mentioned)"`. The skill has no mechanism for determining what *wasn't* found — it only consolidates what *was* found. Computing "lines no reviewer mentioned" requires either a full diff of the codebase (which the skill doesn't take as input) or a coverage metric that the skill doesn't define.
- **N=2 models breaks `majority` for category.** The code-review dispatch example (line 33) uses 2 models. With 2 models and different `category` values, `majority` returns `null` (per consolidation-rules.md line 178: `"with 2 models and 2 different values, no majority — return null"`). The example doesn't warn about this, and the word "N models" in the prompt reads as ≥2 without caveat.
- **`--dangerously-skip-permissions` discussion is duplicated across files.** dispatch-mechanics.md line 59 and code-review.md lines 45-46 both discuss the flag with slightly different wording. If one is updated, the other will drift.

**What is unclear or ambiguous:**
- **"Per-Reviewer Statistics"** (line 88: `"§5 Per-Reviewer Statistics (how many findings each reviewer produced)"`) — counts of raw findings or deduped findings? If reviewer A returned 5 findings and reviewer B returned 3, but 2 overlap, does the statistic say 5 and 3, or does dedup change the counts?
- **Template says "Review the file at /path/to/code.py"** (line 21). For multi-file PRs, does the orchestrator need to concatenate files, or dispatch one model per file? The variation (line 107: `"extend prompt to find issues across N files"`) delegates this to the prompt, but the consolidation would then dedup across files with different (file, line) tuples — which means no dedup. This is a design gap, not a limitation.

---

### 8. rules/examples/fact-check.md

**What works well:**
- Consensus requirements (lines 103-108) are parameterized and honest about thresholds.
- Explicit handling of `unverified` as a valid verdict (line 76: `"unverified is a valid output (don't force a true/false judgment when evidence is insufficient)"`).
- Per-field strategy table (lines 93-99) maps custom rules to rationales clearly.

**What is missing or wrong:**
- **"Worked example: Not yet produced (deferred to v2.2.0)"** (line 113). Same vaporware problem as code-review.md. Zero proven fact-check runs.
- **`claim` field has `type: "text"` but no `max_words`** (line 59). Unbounded text type with no constraint could produce a massive output. The schema column definition table in SKILL.md (lines 117-126) shows `text` as "Long-form text (use max_words to constrain)" — this field explicitly ignores that guidance.
- **`lowest-of-majors` rule only works when `majority` succeeds.** Lines 187-191 define `lowest-of-majors` as: "first apply majority to get the majority value; then among the models voting for that value, return the lowest confidence." But if `majority` returns `null` (no majority), `lowest-of-majors` has no input. The edge case where no majority exists is undocumented. Since `majority-with-uncertain` is the verdict rule and would return `unverified`, `lowest-of-majors` would have zero voters to sample from.
- **`counter_evidence` inclusion constraint is prose-only.** Line 28: `"(if verdict is false or partially-true)"` is a human instruction to the model, not a schema constraint. The model may ignore it and include `counter_evidence` for `true` claims. The schema has no `condition` field on columns.
- **Source quality analysis is underspecified.** Lines 87: `"§5 Source Quality (which sources were cited most often; which were primary vs secondary)"`. URL normalization (handling `https://example.com` vs `https://example.com/` vs `http://example.com`) is not specified, so URL dedup will miss near-identical URLs. The `union-dedup` rule (consolidation-rules.md line 214: `"normalize each value (lowercase, trim, strip trailing slashes for URLs)"`) catches trailing slashes but not protocol differences.

**What is unclear or ambiguous:**
- **How does the orchestrator determine "primary source" vs "secondary source"?** Line 105: `"with high confidence + primary source"` is mentioned as a consensus requirement, but the schema has no `source_type` field. The expectation is that models will self-identify primary sources, but different models will have different definitions.
- **N=3 with 2 true and 1 false → `unverified` if `majority-with-uncertain` threshold is met.** As documented in §1 item 4, this is the contradictory case. Fixing this requires deciding: should 2/3 be enough for `true`, or should the bar be 3/3?

---

## §2. Score the Skill on the 8-Dimension Rubric

| Dimension | Score | Justification |
|---|---|---|
| Catalog of composable units | **1** | Named rules (most-severe, majority, etc.) form a library but are prose-defined, not machine-readable. The `--schema` JSON is user-provided, not a built-in catalog. No JSON enum of available rules or modes. |
| Dynamic composition | **1** | `--mode quick\|standard\|thorough` reconfigures the 4-phase pipeline; `--schema` dynamically shapes output. But there's no audit log of composition choices (run-manifest.json tracks what was used, not why, and doesn't record the full composition decision graph). Not catalog-backed+audited. |
| V-loop depth | **1** | `thorough` mode adds end-of-pipeline per-claim verification (cross-source check). Standard mode resolves conflicts at end. But no recursive V-loop (verify → fix → re-verify). No intent gate that blocks synthesis if verification fails. |
| Enforcement | **0** | Entirely honor system. Nothing enforces that the orchestrator follows the 4-phase pipeline, uses the correct conflict rules, or validates output. An agent could read SKILL.md and produce a malformed consolidated report with zero enforcement. |
| Parent/worker split | **1** | Conceptual split is clear (orchestrator dispatches N workers, consolidates). But the implementation is entirely prose — every orchestrator re-implements from pseudocode. No runtime boundary or enforced interface. |
| Evidence model | **2** | `structured.jsonl` captures per-model, per-row evidence with `source_refs`. `run-manifest.json` tracks full dispatch provenance. `conflicts.md` documents resolution decisions. `thorough` mode adds `evidence-ledger.md` with per-claim `source_verified: true\|false\|wrong` flag and `last_verified` date — this IS tiered sufficiency + staleness. |
| SE + DevOps unified | **1** | The skill covers code review (SE), deployment verification (DevOps — if configured), and fact-check (operations). It supports both domains as task types, but doesn't unify them in one model — each requires a different schema and conflict rules. |
| Team customization | **0** | No process packs, no overlay mechanism, no way to persist team defaults. Every run requires full CLI args. The `--schema` parameter supports customization per run but doesn't persist. No sharing mechanism. |

**Total: 7 / 16**

A score of 7 reflects a skill that has strong conceptual design (evidence model, parent/worker split) and a well-designed named rule library, but is held back by zero enforcement, no machine-readable catalog, no team customization, and the lack of executable implementation.

---

## §3. Top 5 Improvements (ranked by impact × effort)

### 1. Fix the `majority-with-uncertain` algorithm/documentation contradiction

- **Issue:** Algorithm says ≥ max(2, ceil(N/2)) = 2 for N=3 → 2 votes meets threshold. Documentation says "(threshold not met)" for exactly that case.
- **Why it matters:** This is the most-used conflict rule for high-stakes fact-check tasks. Every user of fact-check mode will get wrong results or be confused by conflicting documentation.
- **Concrete change:** In `consolidation-rules.md:183`, change the algorithm to:
  ```
  require > max(2, ceil(N/2)) models to agree on a value. For N=3, this means ≥3 votes needed — single dissent blocks consensus.
  ```
  AND fix `consolidation-rules.md:233` to remove "(threshold not met)" from the example row (since with the WRONG threshold it should say "met", and with the FIXED threshold the example row should show a different vote count):
  ```
  | claim X | verdict | 3 say true, 1 says false | majority-with-uncertain (threshold met) | true | high |
  ```
  AND fix `fact-check.md:74` to match:
  ```
  - `verdict: "majority-with-uncertain"` — if 2 say true and 1 says false, 1 dissent blocks consensus; return `unverified`. Require > max(2, ceil(N/2)) models to agree for a clean verdict (so for N=3 you need all 3 votes, N=5 you need >3 = 4 votes).
  ```
- **Effort:** low (documentation fix, ~4 lines changed)
- **Impact:** high (correctness of the most common conflict rule)
- **Score:** high ROI

### 2. Add a reference implementation for the Phase 2-3 pipeline

- **Issue:** The skill is 100% prose. Every orchestrating agent must re-implement table extraction, dedup, conflict resolution, and score aggregation from pseudocode. There's no library, no script, no importable module.
- **Why it matters:** The consolidation algorithms are described as "the core value of the skill" (SKILL.md:195). Without a reference implementation, every run is a fresh implementation that may differ subtly from the spec. This is the main barrier to adoption and the primary source of divergence between agents.
- **Concrete change:** Create `skills/multi-ai-task/lib/consolidate.js` (or `.py`) that implements:
  - `extractRows(markdown, schema)` — implement the 4-fallback path from methodology.md:37-65
  - `buildRegistry(rows)` — implement the dedup algorithm from consolidation-rules.md:96-111
  - `resolveConflicts(registry, schema)` — implement all named rules from consolidation-rules.md:167-221
  - `renderConsolidated(registry, schema, mode)` — render consolidated.md from the registry
  
  The orchestrating agent then runs: `node skills/multi-ai-task/lib/consolidate.js --schema schema.json --out-dir out/ --mode standard`
  instead of reading 334 lines of pseudocode and implementing it in-session.
- **Effort:** high (new file, ~300-500 lines of code + tests)
- **Impact:** high (reduces agent errors, ensures consistency, makes the skill actually usable)
- **Score:** high ROI

### 3. Fix the unsafe `"$PROMPT"` shell injection vector in Mechanism 2

- **Issue:** `dispatch-mechanics.md:49` passes the prompt via `"$PROMPT"` on the command line. Shell metacharacters in the prompt (`$`, `` ` ``, `"`, `\`) will be interpreted before `npx` receives them.
- **Why it matters:** Every user who includes a code example (containing `$variable` or backticks) or template syntax in their prompt will experience a silent prompt corruption or command injection. This will be the first bug reported once the skill has users.
- **Concrete change:** In `dispatch-mechanics.md`, replace lines 43-53 with the heredoc-safe version already demonstrated in code-review.md:
  ```bash
  # Write prompt to a temp file to avoid shell injection
  PROMPT_FILE="$OUT/prompt.md"
  cat > "$PROMPT_FILE" <<'PROMPT_EOF'
  $PROMPT_CONTENT
  PROMPT_EOF
  
  for model in ...; do
    slug=$(echo "$model" | cut -d/ -f2)
    npx -y opencode-ai run \
      --model "$model" \
      --title "multi-ai-task-${slug}-$(date +%s)" \
      --dangerously-skip-permissions \
      @"$PROMPT_FILE" \
      > "$OUT/${slug}.md" 2> "$OUT/${slug}.err" &
  done
  ```
  Also fix `research-prior-art.md:28` which has the same issue.
- **Effort:** low (documentation fix, ~5 lines changed in two files)
- **Impact:** high (prevents a class of bugs that would make the skill unreliable for code-related tasks)
- **Score:** high ROI

### 4. Add input validation for `--schema` JSON

- **Issue:** The skill accepts a JSON schema from the user but performs zero validation. A user can pass `"conflict_resolution": {"category": "non-existent-rule"}` and the orchestrator will silently fail or produce garbage. Named rule references, column type validity, and `dedup_key` consistency are unchecked.
- **Why it matters:** Schema-driven consolidation is the primary value path (structured mode). Schema errors produce output that looks right but is wrong — the worst kind of bug. Validation would catch them at config time.
- **Concrete change:** Add a validation section to `output-schema.md` or create `rules/schema-validation.md` with:
  - Allowed `type` values: `["string", "number", "boolean", "enum", "url", "url_list", "date", "text"]`
  - Allowed `conflict_resolution` values: all named rules in consolidation-rules.md
  - Validation: if `dedup_key: true` on multiple columns, check that at least one column exists
  - Validation: if `type: "enum"`, `values` must be present and non-empty
  - Validation: if `type: "number"` with `min`/`max`, `min ≤ max`
  - Validation: `aggregate` values: `["median", "mean", "sum", "min", "max", "first", "last"]`
  - The orchestrator should validate the schema in Phase 0 (before any dispatch) and reject with specific error messages if invalid.
- **Effort:** medium (~50 lines of validation logic + ~100 lines of doc)
- **Impact:** high (prevents silent misconfiguration, the most expensive kind of bug)
- **Score:** medium-high ROI

### 5. Produce worked examples for code-review and fact-check (or remove the "Worked example" label)

- **Issue:** Both code-review.md:111 and fact-check.md:113 say `"Not yet produced (deferred to v2.2.0)"`. These files are labeled as worked examples in SKILL.md:203-210 but are entirely hypothetical. They're vaporware.
- **Why it matters:** The skill claims to be task-agnostic, but the only proven use case is research. Without at least one more proven task type, the "task-agnostic" claim is unvalidated. Removing the label is a 1-line fix; producing the example validates the design for a second task domain.
- **Concrete change:** Option A (fast): Change the "Worked example" sections to "Planned example (v2.2.0)" and add a warning at the top of each file: `"⚠ This example has NOT been validated in a live run."`
  Option B (better): Run the skill with 3-4 models on a real PR or fact-check claim set, document the output, and replace the deferred notes with the actual run results. For code review: pick a small public PR or a single file with known issues. For fact-check: pick 5-10 non-controversial factual claims with known answers.
  Option C (if no resources): Remove the deferred notes and just say "This recipe follows the same pattern as the prior-art research example. Adapt the prompt and schema."
- **Effort:** low (Option A or C) / medium (Option B — requires an actual run)
- **Impact:** medium (validates the "task-agnostic" claim; reduces user skepticism)
- **Score:** medium ROI

---

## §4. Open Questions

1. **What is the intended delivery format?** Is this skill a document to be read by LLMs (who implement it in-session), a human reference manual, or should it ship with executable code (`lib/consolidate.js`)? The current design is ambiguous, and the answer determines every implementation decision.

2. **What harness should the reference implementation target?** The dispatch mechanics are OpenCode-centric (Mechanism 1 references `opencode.json`, Mechanism 2 uses `npx opencode-ai run`). If a reference implementation is built, should it assume OpenCode, or be harness-agnostic? The skill says it's task-agnostic (SKILL.md:13) but the dispatch is harness-specific. This tension needs resolution.

3. **Should `thorough` mode be a separate skill?** `thorough` mode adds per-claim cross-source verification, an evidence ledger, and verifier model dispatch. This is a significant complexity increase (~50% more phases, new output files, sequential verifier calls). It might be cleaner as a separate `multi-ai-verify` skill that consumes `multi-ai-task` output.

4. **What's the actual cost/latency model?** The skill says "Cost of N× compute is acceptable" (SKILL.md:39) and "Latency of slowest model + consolidation is OK" (SKILL.md:41) but provides zero cost estimates. For a user deciding whether to use this skill, knowing that 6 models × 3 minutes = 18 minutes wall-time and ~$0.50-2.00 in API costs would be more useful than qualitative tradeoffs.

5. **Is `consolidated.html` worth the complexity?** The HTML deliverable is underspecified (no CSS, no rendering pipeline) and its value is unclear. If the user needs an HTML report, they can run `pandoc consolidated.md -o consolidated.html --standalone`. Adding this to the core pipeline adds complexity for marginal value. Should it be optional or removed?

6. **How does the skill handle incremental runs?** The methodology says re-runs are "fresh" (methodology.md:173: `"does NOT cache across runs by default"`) but also mentions that `"run-manifest.json from previous runs can be referenced for incremental consolidation (future enhancement)"`. What does incremental consolidation look like? If the user runs the skill, gets 4/6 model responses, and wants to add 2 more models without re-running the first 4, how does that work?

7. **Should the alias map have a standard file format?** The research example stores aliases as a markdown table (research-prior-art.md:125-140) and as a JSON object in run-manifest.json. The JSON format is `{"AutoGen/AG2": "AutoGen"}` but the table format is `Alias | Canonical`. These two representations could diverge. Should there be a standard `aliases.json` or `aliases.toml` format?

---

## §5. Confidence

- **Overall confidence:** high

The skill's design is thoroughly documented, the algorithms are specified concretely (especially the named rule library), and the critical bug found (majority-with-uncertain threshold) is a documentation contradiction, not a design flaw. The scores (7/16) accurately reflect a skill with strong conceptual foundations but zero executable implementation.

**What would change your assessment:** A reference implementation that validates the algorithms against real multi-model output would surface latent edge cases (e.g., how `lowest-of-majors` behaves when majority returns `null`, how the table parser handles models that emit non-standard markdown tables). Until a reference implementation exists and has been run against diverse model outputs, my assessment assumes the prose algorithms are correct — but the gap between pseudocode and working code is where most bugs live.
