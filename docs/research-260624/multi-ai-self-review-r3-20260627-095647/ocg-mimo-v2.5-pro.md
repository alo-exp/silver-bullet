# Critical Self-Review: multi-ai-task Skill

---

## §1. Critical Assessment

### `SKILL.md`

**What works well:**
- The when-to-use / when-not-to-use table (lines 35-43) is genuinely useful — not just "use when you want better answers" but concrete decision criteria like "cost of N× compute is acceptable."
- The failure modes table (lines 218-228) is practical and specific, with real symptoms and fixes rather than generic error-handling advice.

**What is missing or wrong:**
- **Schema inconsistency across files.** `run-manifest.json` in SKILL.md (line 162-173) has a `consolidation` block (`dedup_merges`, `score_aggregations`, `unresolved_conflicts`). The same object in `methodology.md` (lines 149-174) has `schema_auto_injected` and `aliases` but NO `consolidation` block. The same object in `output-schema.md` (lines 210-226) has a `schema` field not present in either. Any tool consuming `run-manifest.json` will break depending on which file it read.
- **Double-negative in "What this skill does NOT do."** Line 28: "Inject the schema into the prompt unless `--no-auto-inject` is set (default ON)." The behavior is: schema IS auto-injected by default. The double-negative `NOT...unless...no-auto-inject...default ON` is genuinely confusing. Rewrite: "Auto-inject the schema into the dispatch prompt (enabled by default; disable with `--no-auto-inject`)."
- **Meta-commentary clutters the spec.** Lines 236-248 ("Proven provenance") and the folder-name note are documentation about a specific run, not part of the skill contract. They belong in a changelog or the example file, not the entry point. The self-review reference (line 248) is recursive noise.

**What is unclear:**
- "Auto-discover" (line 74): "queries the local OpenCode config and picks a balanced default set." What if there's no config? What if the config has only 1 model? What does "balanced" mean algorithmically — is it just "at least 2 provider families, max 2 per family" or is there weighting?
- Version: frontmatter says `2.1.0` but the task context says `v2.0.0`. Which is canonical? Is there a changelog?

---

### `rules/methodology.md`

**What works well:**
- The 4-phase structure is clean and the pseudocode for extraction (lines 37-64, 78-99) is specific enough to implement. The fallback chain (table → tags → extractor → paragraph split) is well-ordered.
- The fail-soft policy (line 19) is explicit: "The skill does NOT retry. Retry logic lives in the calling agent's runner." This prevents the #1 failure mode of orchestration skills (infinite retry loops).

**What is missing or wrong:**
- **Extractor model semantics are muddled.** Line 104: "caches the response, no extra cost." But it IS an LLM call — how is it cached? Is the extractor's output cached by prompt hash? Or does "no extra cost" mean "uses a model you already paid for"? The claim is unverifiable.
- **"Idempotent re-runs" (line 207) is misleading.** The skill can be *re-run*, but there's no actual idempotency guarantee (same inputs → same outputs). Line 208: "It does NOT cache across runs by default." So it's not idempotent — it's just re-runnable. The term "idempotent" has a specific meaning in distributed systems and this isn't it.
- **`run-manifest.json` schema doesn't match SKILL.md.** See above. This file has `schema_auto_injected` and `aliases` (lines 177-178) but no `consolidation` block. The field `phases_completed` (line 179) is here but not in SKILL.md's version.

**What is unclear:**
- Phase 2 extraction pseudocode handles tables and `<structured>` tags, but what about models that return mixed output (table + prose + code blocks)? Does the parser extract the first table and ignore the rest? Or all tables?
- "The slowest, highest-capability model from the original dispatch" as extractor — how is "slowest" determined? After the fact (it finished last)? By known latency profiles? By model size?

---

### `rules/dispatch-mechanics.md`

**What works well:**
- The 4-mechanism hierarchy (lines 9-89) is practical and well-ordered by preference. The shell code for Mechanism 2 (lines 36-51) is copy-pasteable and correct.
- The MCP port collision caveat (lines 102-103) is a real operational issue that most orchestration guides miss.

**What is missing or wrong:**
- **Stale issue reference.** Line 75: "Known bug (2026-06): Issue #18615." Is this fixed? The date is a month ago. Without a resolution status, this is potentially misleading.
- **Auth table is incomplete.** Lines 138-145 list 5 providers. Missing: Azure OpenAI, AWS Bedrock, Google Vertex, Together AI, Fireworks, Replicate, any local model server beyond Ollama. The skill claims to be task-agnostic but the auth guidance is OpenCode-centric.
- **Mechanism 4 is undercooked.** Line 77-89: "Skip the OpenCode layer entirely." But the consolidation logic (extracting structured data, dedup, conflict resolution) is specified as part of the skill — how does it run without the OpenCode layer? Is Mechanism 4 "just call the APIs and then manually consolidate"? If so, what value is the skill adding?

**What is unclear:**
- "Parallel vs sequential" recommendation (lines 93-103): the decision depends on "your latency budget" but no guidance on what a typical budget is. The example says "2-3 min/model" but doesn't say what total budget to assume.
- Lines 108-112: "Always check the model's CWD for stray `*.md` files after a dispatch." This is a manual step — who does it? The skill? The calling agent? The user? It's a gap in the automation.

---

### `rules/consolidation-rules.md`

**What works well:**
- The named rule library (lines 163-221) is the strongest part of the entire skill. Each rule has purpose, input, algorithm, and edge cases. The `most-severe`, `majority-with-uncertain`, and `lowest-of-majors` rules are genuinely useful and well-specified.
- The skip rules (lines 115-121) are practical: placeholder rows, header rows, reference items, scoring-matrix headers. These are real extraction failure modes.

**What is missing or wrong:**
- **Default rule table references a truncated rule name.** Line 146: `"prefer-with-evidence-then-newer-then-strict"` — this is the full name, but in the schema examples (SKILL.md line 109, research-prior-art.md line 95) it appears as the full name. However, the rule definition itself (lines 155-161) is only 4 lines of prose with no pseudocode, unlike every other named rule which has an explicit algorithm. The "prefer-with-evidence" step says "If one model has a primary quote supporting value X" — but how does the consolidation algorithm determine if a value has a "primary quote"? Is it checking for inline `"..."`? For a `source_refs` field? This is underspecified.
- **Score aggregation only supports `median`.** Line 251: "compute median + min/max across models." What about weighted median (by model confidence)? Mean? Custom aggregators? The schema supports `aggregate: "median"` but no other values are documented.
- **`concatenate` vs `concatenate-all` naming.** Line 307: "Use `concatenate` for comments" but the rule library defines `concatenate-all` (line 199). The custom strategies table uses a shortened name that doesn't match the rule library. Is `concatenate` an alias? A typo?

**What is unclear:**
- How does the alias map interact with fuzzy matching? If I have `aliases["AG2"] = "AutoGen"` and fuzzy matching is enabled (≥80% similarity), which takes precedence? Can fuzzy matching merge two items that the alias map kept separate?
- The dedup algorithm (lines 96-111) merges by primary key. But what if two genuinely different items share a primary key in different contexts? (E.g., "Python" as a language vs "Python" as a Monty Python reference.) The skill assumes primary keys are globally unique — is this always true?

---

### `rules/output-schema.md`

**What works well:**
- The markdown formatting rules (lines 231-242) are excellent — these are real WYSIWYG compatibility issues that most generators ignore. The `value*` conflict marker convention (line 73) is clever and unobtrusive.
- The two-mode structure (Mode A structured, Mode B generic) cleanly handles both schema and no-schema cases.

**What is missing or wrong:**
- **`run-manifest.json` schema differs from the other two files.** Line 217: includes `"schema": {...}` — the full schema object embedded. Neither SKILL.md nor methodology.md include this field. Three files, three different schemas for the same JSON file.
- **Appendix A vs §3 overlap.** Appendix A ("Cross-AI Source Map", lines 167-178) shows "which model found which item." §3 ("Per-Item Details", lines 100-116) also shows per-item information including sources. The duplication isn't clearly motivated — when would a consumer use one but not the other?
- **No schema validation.** The schema spec (SKILL.md lines 88-145) defines column types and fields but there's no validation step. What happens if a user passes `{"type": "banana"}`? Or `"min": "not-a-number"`? Fail-soft or fail-hard?

**What is unclear:**
- Lines 65-69: "Fields per model: short summary like `m1: {cat: direct, score: 3}`." Is this JSON? Human-readable text? A specific format? If the consolidated output is consumed by tooling (not just humans), the format needs to be specified.

---

### `rules/examples/research-prior-art.md`

**What works well:**
- The dispatch code (lines 13-33) is copy-pasteable and correct. The alias map (lines 125-141) is concrete with 14 real entries, showing what actual dedup looks like.
- The scoring rubric (lines 104-118) ties back to the 8-dimension rubric used in the skill's own review — good dogfooding.

**What is missing or wrong:**
- **"Variations to try" is speculative.** Line 182: "diminishing returns past 6 (this is an empirical observation, not a measured curve)." This weakens the example — if it's not measured, don't present it as guidance. Either measure it or remove the claim.
- **`last_verified` field is in the schema but not in the prompt.** The schema (line 92) declares `"last_verified": {"type": "date"}` but the dispatch prompt template (lines 37-68) never asks models to verify dates or provide a `last_verified` value. How does this field get populated? If it's always empty, it shouldn't be in the schema.
- **No guidance on adapting the prompt.** The prompt template (lines 37-68) is specific to "subject X" research but doesn't say how to parameterize it. Is the user supposed to copy-paste and find-replace? Or is there a template engine?

**What is unclear:**
- Is this example meant to be a recipe (copy and adapt) or documentation (read and understand)? The level of detail suggests recipe, but the "Variations to try" section suggests documentation. Pick one.

---

### `rules/examples/code-review.md`

**What works well:**
- The composite key example (line 68) clearly demonstrates `dedup_key: true` on multiple columns. The security note (lines 45-46) correctly distinguishes read-only review from write tasks.
- The conflict-resolution table (lines 94-100) with recommended rules per field is practical and directly usable.

**What is missing or wrong:**
- **No worked example.** Line 109: "Not yet produced (deferred to v2.2.0)." This is a significant gap — the prior-art example has actual output; code-review has only a recipe. Without a worked example, there's no proof the recipe produces good results.
- **`suggestion` field not in conflict resolution.** The schema (lines 57-58) includes `suggestion` but the conflict_resolution (lines 62-63) only covers `severity` and `category`. What if two reviewers disagree on the fix? Is `suggestion` just "last writer wins"?
- **Dispatch code omits `--dangerously-skip-permissions` but doesn't explain why in-context.** Line 38: the code doesn't pass the flag. Line 45: the security note explains why. But a reader copying the code might add the flag without reading the note. Add a comment in the code itself.

**What is unclear:**
- Line 106: "Pre-commit hook: combine with git diff to only review changed lines (NOT currently supported as a built-in dispatch; requires custom runner)." Is this a planned feature? A limitation to document? Or just a "wouldn't it be nice" comment?

---

### `rules/examples/fact-check.md`

**What works well:**
- The consensus requirements (lines 102-109) with parameterized thresholds (`max(2, ceil(N/2))`) are well-specified and correctly handle N=3, 5, 7.
- `unverified` as a valid output (line 76) is the right design choice for high-stakes fact-checking — forcing a true/false judgment when evidence is insufficient is worse than admitting uncertainty.

**What is missing or wrong:**
- **No worked example.** Line 111: "Not yet produced (deferred to v2.2.0)." Same gap as code-review. Two of three examples have no worked output.
- **Meta-commentary in the spec.** Line 109: "The '3+ models' rule in the original draft was a typo; the correct threshold is parameterized." This is changelog content, not example content. It tells the reader about a bug that was fixed — they don't care.
- **No `last_verified` in the schema.** For fact-checking, knowing WHEN a claim was verified is arguably more important than for research. The schema (lines 54-70) has `sources` and `evidence` but no temporal dimension. A claim verified in 2020 may be false in 2026.
- **Counter-evidence only for false/partially-true.** Line 29: "counter_evidence (if verdict is false or partially-true)." But a true claim can have important caveats or limitations. The field should be `evidence_and_caveats` or there should be a separate `caveats` field.

**What is unclear:**
- How does the skill handle claims that require access to paywalled or private sources? The dispatch assumes all models have equal access to information. If one model has web access and another doesn't, the fact-check is comparing apples to oranges.

---

## §2. Score the Skill on the 8-Dimension Rubric

| Dimension | Score | Justification |
|---|---|---|
| **Catalog of composable units** | 1 | Named rules (`most-severe`, `majority-with-uncertain`, etc.) are well-defined, but they're prose algorithms, not machine-readable. No formal registry, no import mechanism, no versioning. A consumer can't `require('consolidation-rules').most_severe` — they have to reimplement from the spec. |
| **Dynamic composition** | 1 | The 4-phase pipeline is fixed. The 4 dispatch mechanisms offer runtime selection, but the pipeline itself (dispatch → extract → consolidate → synthesize) is hardcoded. No replanner, no conditional branching, no "if this task type, use these rules." The user manually selects mode, schema, and rules — the skill doesn't compose dynamically. |
| **V-loop depth** | 0 | No verification loop at all. Phases run linearly. There's no "did the consolidation produce valid output?" check, no intent gate ("does the consolidated artifact actually answer the user's question?"), no rollback on bad consolidation. The skill assumes Phase 3 output is always usable. |
| **Enforcement** | 0 | Pure instruction — no hooks, no CI checks, no IDE integration, no delivery blockers. A user can ignore the schema spec, skip phases, or produce malformed output and the skill has no mechanism to detect or prevent it. |
| **Parent/worker split** | 2 | This is the skill's strongest dimension. The orchestrator (calling agent) dispatches to N worker models, consolidates their outputs, and produces a unified artifact. The split is explicit: workers produce raw output, orchestrator deduplicates and resolves conflicts. Fail-soft delegation is well-specified. |
| **Evidence model** | 2 | Tiered sufficiency is built in: `thorough` mode adds cross-source verification with `evidence-ledger.md`. Source staleness is tracked via `last_verified`. The `source_refs` field in structured.jsonl preserves provenance. The alias map documents how names were resolved. This is genuinely strong. |
| **SE + DevOps unified** | 1 | Code-review example covers SE. Fact-check and research cover neither SE nor DevOps specifically. There's no infrastructure review, no deployment audit, no IaC analysis example. The skill is "unified" only in the sense that it's generic — it doesn't have domain-specific guidance for either. |
| **Team customization** | 0 | No overlay mechanism. The schema is passed as a CLI argument — there's no team-level schema inheritance, no process pack system, no "load team defaults." A team that wants custom rules must either fork the skill or pass the full schema every time. |

**Total: 8/16**

---

## §3. Top 5 Improvements (ranked by impact × effort)

### 1. Consolidate `run-manifest.json` schema into one canonical definition

**Issue:** Three files (SKILL.md, methodology.md, output-schema.md) define three different schemas for `run-manifest.json`.

**Why it matters:** Any tool consuming `run-manifest.json` — for auditing, incremental consolidation, or reproducibility — will break depending on which file the implementer read. This is the single most likely source of implementation bugs.

**Concrete change:** Pick `output-schema.md` as canonical (it's the most complete). Delete the inline schemas from SKILL.md (lines 162-174) and methodology.md (lines 149-174). Replace with: "The canonical `run-manifest.json` schema is in `rules/output-schema.md` § Supporting files." Add a cross-reference.

**Effort:** Low (text edits, no logic changes)

**Impact:** High (prevents implementation divergence)

**Score:** High/Low = excellent ROI

---

### 2. Add a concrete implementation script (not just pseudocode)

**Issue:** The entire skill is pseudocode and bash recipes. There is no executable code. A user who wants to run multi-ai-task must reimplement the consolidation logic from scratch.

**Why it matters:** The skill's value is in the consolidation algorithms (dedup, conflict resolution, score aggregation). Without an implementation, every consumer reinvents the wheel and likely introduces bugs in the fuzzy matching, alias resolution, or conflict resolution logic.

**Concrete change:** Create `scripts/consolidate.js` (or `.ts`) that takes `structured.jsonl` + a schema JSON and produces `consolidated.md`, `conflicts.md`, and `run-manifest.json`. Start with the deterministic parts (dedup by primary key, median aggregation, conflict detection) and leave the LLM-assisted extraction as a callback hook. The dispatch script (Mechanism 2) is already bash — the missing piece is the consolidation.

**Effort:** High (real implementation)

**Impact:** High (transforms the skill from spec to tool)

**Score:** High/High = good ROI but significant investment

---

### 3. Specify the `prefer-with-evidence-then-newer-then-strict` rule as an algorithm, not prose

**Issue:** This rule (consolidation-rules.md lines 155-161) is the default for all enumerated string fields, but it's specified as 4 bullet points of prose, not as pseudocode like every other named rule. Step 1 says "If one model has a primary quote supporting value X" — how does the algorithm detect a "primary quote"?

**Why it matters:** This is the DEFAULT conflict-resolution rule for `category`, `verdict`, and other enum fields. If the algorithm is ambiguous, every consolidation run that uses the default will produce inconsistent results.

**Concrete change:** Replace lines 155-161 with pseudocode:

```
function resolve_prefer_with_evidence(values, field):
  // Step 1: values with a source_refs entry pointing to a primary source
  with_evidence = values.filter(v => v.source_refs.some(r => r.is_primary))
  if with_evidence.length === 1: return with_evidence[0]
  if with_evidence.length > 1: return prefer_newest(with_evidence)
  
  // Step 2: no evidence — use recency
  dated = values.filter(v => v.last_verified)
  if dated.length > 0: return max(dated, key=v => v.last_verified)
  
  // Step 3: no dates — outlier downgrade
  counts = Counter(values.map(v => v.value))
  majority_value = counts.most_common(1)[0]
  if counts[majority_value] >= ceil(N * 0.6): return majority_value
  
  // Step 4: true tie — return first by model name (deterministic)
  return sort(values, key=v => v.model)[0]
```

**Effort:** Low (specification fix)

**Impact:** High (makes the default rule implementable)

**Score:** High/Low = excellent ROI

---

### 4. Add team customization via overlay packs

**Issue:** The skill has no mechanism for team-level defaults. A team that wants custom schemas, conflict rules, or alias maps must pass them as CLI arguments every time or fork the skill.

**Why it matters:** In enterprise settings, teams have standard review rubrics, fact-check thresholds, and dedup aliases. Without overlay packs, every invocation requires passing a full schema JSON — error-prone and verbose.

**Concrete change:** Add a `--profile <name>` parameter that loads a JSON file from `~/.config/opencode/multi-ai-task/profiles/<name>.json`. The profile contains default schema, conflict rules, alias map, and mode. CLI arguments override profile defaults. Example profile:

```json
{
  "name": "code-review-strict",
  "default_mode": "standard",
  "default_schema": { ... },
  "default_aliases": { ... },
  "conflict_overrides": { "severity": "most-severe" }
}
```

Document in SKILL.md § Usage.

**Effort:** Medium (new parameter + file loading + merge logic)

**Impact:** Medium (enables enterprise adoption)

**Score:** Medium/Medium = decent ROI

---

### 5. Remove meta-commentary and provenance from SKILL.md

**Issue:** SKILL.md lines 236-248 contain provenance about specific runs, folder-name disclaimers, and self-review references. This is changelog content, not skill specification.

**Why it matters:** The entry point should be a clean contract. Meta-commentary about run dates, folder names, and self-reviews adds noise and makes the skill harder to understand for first-time readers.

**Concrete change:** Move lines 236-248 to a `CHANGELOG.md` or into the research-prior-art example file. Replace with a one-liner: "See `rules/examples/research-prior-art.md` for a proven end-to-end run."

**Effort:** Low (text move)

**Impact:** Low (readability improvement, no functional change)

**Score:** Low/Low = acceptable ROI

---

## §4. Open Questions

1. **Is this skill a specification or a tool?** Currently it's a spec — pseudocode and recipes. Is there a plan to ship an implementation? If not, who is expected to implement it — each consuming agent independently?

2. **What host harnesses does this target?** The dispatch mechanics are OpenCode-centric (Mechanism 2 uses `opencode run`). Does this skill work in Claude Code, Cursor, Codex, or other harnesses? Mechanism 4 (direct HTTP) is the only harness-agnostic path, but it's under-specified.

3. **How is the alias map maintained at runtime?** The research example has a 14-entry alias map that was built after the run. Is there a discovery mechanism (e.g., "if two items have ≥80% fuzzy match, flag as potential alias")? Or is it purely manual?

4. **What's the intended consumer of `consolidated.md`?** Is it a human reading a markdown file? A tool parsing structured output? An agent consuming it as context? The answer affects formatting decisions (e.g., the "Fields per model" format in §2).

5. **How does the skill handle models with different capabilities?** If one model has web access and another doesn't, or one has a 128K context window and another has 8K, the outputs are not comparable. Is this a known limitation or is there a mitigation?

6. **Is the 8-dimension rubric part of the skill or external?** The scoring rubric appears in the research example but not in the core skill files. Is it a general-purpose evaluation framework or research-specific?

7. **What's the upgrade path from v1.0.0 to v2.1.0?** The skill was "generalized from a research-focused v1.0.0." Are there breaking changes? Migration guidance?

---

## §5. Confidence

**Overall confidence:** Medium-high

The design is sound and well-documented. The named rule library is genuinely strong. The parent/worker split and evidence model are excellent. However, without an implementation, there's no way to verify the pseudocode actually works — the extraction fallback chain, fuzzy matching, and conflict resolution are complex enough that bugs are likely. The schema inconsistency across files is a concrete, verifiable problem. The two deferred worked examples (code-review, fact-check) mean 2/3 of the non-research examples are untested recipes.

**What would change my assessment:**
- An actual implementation that runs end-to-end and produces `consolidated.md` from `structured.jsonl` — this would move the score from 8 to 10-11.
- A single canonical `run-manifest.json` schema that all files reference — this is a quick fix that eliminates the most likely implementation bug.
- Worked examples for code-review and fact-check — these would prove the generic claim (the skill works for any task) rather than just asserting it.
