# Critical Self-Review: `multi-ai-task` Skill

## §1. Critical Assessment

### SKILL.md

**What works well:**
- Frontmatter is complete and the `argument-hint` is genuinely useful for CLI discoverability.
- The "When to use / Don't use" table is crisp and decision-oriented — one of the best I've seen in a skill file.

**What is missing or wrong:**
- **Default model discovery is aspirational, not specified.** Line 72-73: *"the skill queries the local OpenCode config (`~/.config/opencode/opencode.json` + `.jsonc`) and picks a balanced default set of 4-6 models"* — there is no algorithm specified for how to parse the config, how to determine "provider families," or how to decide which models are "reasoning-capable." An implementer would have to guess.
- **`thorough` mode verifier model selection is undefined.** Line 81: *"dispatch a verifier model to check the claimed source"* — which model? The slowest? A different one from the original dispatch? The same one that made the claim? This is a cost-affecting decision left unspecified.
- **Known inconsistency left in the failure modes table.** Line 258: *"Output dir contains `score-aggregate.md` (planned) but not in the contract... Ignore for v2.x"* — this is a known bug documented as "ignore it." Either remove the planned file from the contract or fix the inconsistency.

**What is unclear or ambiguous:**
- **Mode B free-form fallback chain termination.** Lines 159-163 describe 3 fallback steps but never say what happens if all 3 fail. Does the skill produce an empty `structured.jsonl`? Does it error? Does it include the raw response as a single blob?
- **`@file.md` syntax for inlining prompts** (line 64) is mentioned but never defined. Is this a shell expansion? A skill-internal parser? A host feature?

---

### rules/methodology.md

**What works well:**
- The 4-phase structure is clean and the pseudocode for extraction (lines 38-64, 79-99) is genuinely implementable.
- The "Cross-cutting principles" section (lines 151-173) is a rare good practice — it states invariants that survive refactoring.

**What is missing or wrong:**
- **Contradiction in "Deterministic + LLM-assisted hybrid" claim.** Line 157: *"Structured extraction (Mode A) is deterministic — pure parsing, no LLM in the loop"* — but fallback path 3 (line 58) dispatches an extractor model, which IS an LLM in the loop. Mode A is deterministic only on the happy path.
- **Phase 3 consolidation output format is underspecified.** Line 118: *"stored in `structured.jsonl` (append mode with `model: "_consolidated"`)"* — appending consolidated records to the same JSONL as per-model extractions creates ambiguity. How does a consumer distinguish raw extractions from consolidated records? There's no `record_type` field.
- **"Future enhancement" in a methodology doc.** Line 173: *"the `run-manifest.json` from previous runs can be referenced for incremental consolidation (future enhancement)"* — scope-creep in a specification document. Move to a ROADMAP or remove.

**What is unclear or ambiguous:**
- **Extractor model cost is mentioned but not bounded.** Line 104: *"Cost: one additional LLM call per model whose structured extraction failed"* — what if all N models fail extraction? That's N additional LLM calls, potentially doubling the cost. No upper bound or circuit-breaker is specified.

---

### rules/dispatch-mechanics.md

**What works well:**
- The 4-mechanism ranking with explicit "when to use" table (lines 178-188) is practical and actionable.
- The `slug` sanitization note (line 64: *"the `cut -d/ -f2` pattern is critical"*) is the kind of hard-won operational detail that makes a skill trustworthy.

**What is missing or wrong:**
- **Typo in `npx` flag.** Line 65: *"`--y` in `npx -y opencode-ai run`"* — the flag is `-y` (single dash), not `--y`. This is a copy-paste error that could confuse implementers.
- **Time-sensitive references will rot.** Line 28: *"Dynamic per-call model selection is a 6-time-requested feature (issues #6651, #11215, #17595, #26925, #29984, #32730) with one open PR (#29447)"* — these issue numbers are frozen in time. When they're closed or the PR merges, this text becomes misleading. Same for line 86: *"Known bug (2026-06)"*.
- **MCP port collision mitigation is not actionable.** Line 113: *"configure MCPs that support multiplexing"* — which MCPs support multiplexing? How do you configure it? This is advice without a recipe.

**What is unclear or ambiguous:**
- **Mechanism 3 vs Mechanism 2 selection criteria.** The table at line 183 says use Mechanism 3 if you have "An OpenCode server running" — but Mechanism 2 also works with a server. When is the SDK strictly better than the CLI subprocess?

---

### rules/consolidation-rules.md

**What works well:**
- The named rule library (`most-severe`, `majority-with-uncertain`, `lowest-of-majors`, etc.) is genuinely well-specified — each rule has purpose, input, algorithm, edge cases, and rationale. This is the core value of the skill and it shows.
- The `most-severe` rule's `allow_downgrade` option (line 171) with its safety-conscious default (`false`) and explicit override rationale is excellent design.

**What is missing or wrong:**
- **`majority-with-uncertain` naming is misleading.** The rule requires `> max(2, ceil(N/2))` agreement. For N=3, this means all 3 must agree (unanimity). For N=5, at least 4. This is closer to "near-unanimity-or-unverified" than "majority-with-uncertain." The name suggests a loose majority, but the algorithm is strict. Line 185 calls it "high-stakes" but the name doesn't convey that.
- **Conflict resolution documentation example uses numbered rules that don't exist.** Line 231: *"rule 4 (outlier downgrade)"* and line 232: *"rule 3 (strict)"* — the named rules in this file don't have numbers. The example references a numbering scheme that isn't defined anywhere.
- **"Score conflict resolution" section is thin.** Lines 249-257: only 8 lines for score aggregation, compared to 100+ lines for string/enum resolution. Score aggregation (median, range, N) is specified but edge cases are missing: what if a model scores an item 0 and another scores it 16? What if only 1 of 6 models scores an item?

**What is unclear or ambiguous:**
- **`prefer-with-evidence-then-newer-then-strict` — what is "strict"?** The rule name includes "strict" but the description (lines 157-162) never defines what "strict" means. It's a 4-step cascade but the 4th step ("prefer the value with the strongest evidence quote") doesn't obviously relate to "strict."

---

### rules/output-schema.md

**What works well:**
- The `run-manifest.json` schema (lines 211-254) is comprehensive and well-cross-referenced. The field semantics section is genuinely useful.
- The markdown formatting rules (lines 258-269) are a rare and valuable addition — WYSIWYG compatibility is a real problem and the rules are specific and actionable.

**What is missing or wrong:**
- **`task_prompt_hash` computation is unspecified.** Line 215: `"task_prompt_hash": "sha256:..."` — what bytes are hashed? The prompt string as-is? UTF-8 encoded? With or without trailing newline? Before or after `@file.md` expansion? This matters for reproducibility.
- **`models_failed` object shape is not demonstrated.** Line 249 describes it as *"list of `{model, stderr_excerpt, exit_code}`"* but the example (line 222) shows an empty array `[]`. A non-empty example is needed to show the actual shape.
- **Markdown formatting rules contradict other files.** Line 265: *"Avoid unicode in cells when possible. `—` → `--`, `→` → `->`, `≥` → `>=`"* — but `consolidation-rules.md` line 231 uses `→` in a table cell, and `SKILL.md` uses `≥` throughout. The rule is not self-applied.

**What is unclear or ambiguous:**
- **§5 "Aggregated Scores" optionality.** Line 130: *"If the user provides a scoring rubric or the models self-score"* — what if the user doesn't provide a rubric but the models self-score anyway? Is the section included or omitted?

---

### rules/examples/research-prior-art.md

**What works well:**
- This is a genuine worked example with real file paths, real alias map, and real output references. The provenance is verifiable.
- The 14-entry alias map (lines 125-141) is a practical artifact that an implementer can directly reuse.

**What is missing or wrong:**
- **Dispatch script uses `cd "$OUT"` (line 16) which is fragile.** If the script is sourced or if subsequent commands depend on the original CWD, this breaks. The other examples (code-review, fact-check) correctly avoid `cd`.
- **Prompt template §8 "Cross-AI Dedup Instructions" conflates per-model and consolidation scope.** Line 63: *"normalize names, resolve conflicts, scoring rubric"* — dedup and conflict resolution are the skill's job (Phase 3), not the per-model prompt's job. Including this in the per-model prompt confuses the model about what it's responsible for.
- **Empirical claim without evidence.** Line 182: *"8-10 models captures more unique finds but diminishing returns past 6"* — this is stated as fact but no benchmark or data is cited. It's an anecdote from one run.

**What is unclear or ambiguous:**
- **Scoring rubric `max_total: 16` derivation.** Line 118: the rubric has 8 dimensions, each scored 0-2, so 8×2=16. But this is not stated — a reader has to count the dimensions and infer.

---

### rules/examples/code-review.md

**What works well:**
- The composite key explanation (lines 68-70) is clear and correct — the distinction between `primary_key: "file:line"` (wrong) and `dedup_key: true` on both columns (right) is well-explained.
- The security note (line 45) correctly distinguishes read-only from write tasks.

**What is missing or wrong:**
- **Dispatch script bug: passes file path instead of file contents.** Line 38: `"$OUT/prompt.md"` is passed as the prompt argument to `opencode run`. But `opencode run` expects a prompt string, not a file path. The research example (line 28) correctly uses `"$PROMPT"` where `PROMPT="$(cat /path/to/research-prompt.md)"`. This bug would cause the example to fail.
- **No worked example exists.** Line 111: *"Not yet produced (deferred to v2.2.0)"* — the code-review example is a recipe, not a proven example. This is a significant gap for a skill at v2.1.0.
- **Same-line-different-finding ambiguity.** The schema uses `file` + `line` as composite key, but two distinct findings can occur on the same line (e.g., a security issue and a style issue on line 42). The schema would merge them into one record, losing information.

**What is unclear or ambiguous:**
- **`--dangerously-skip-permissions` omission is noted but not explained for write variants.** Line 45 says "If you want a review-and-fix variant... pass the flag and accept the risk" — but doesn't specify what the fix dispatch would look like.

---

### rules/examples/fact-check.md

**What works well:**
- The consensus requirements section (lines 102-109) is a clear, actionable decision tree for high-stakes verification.
- The `lowest-of-majors` confidence rule application is well-motivated for fact-checking.

**What is missing or wrong:**
- **Same dispatch script bug as code-review.md.** Line 43: `"$OUT/prompt.md"` passed as prompt argument instead of file contents.
- **Redundant rule explanation.** Lines 74 and 109 both explain the `majority-with-uncertain` threshold formula. The duplication is near-verbatim and will drift out of sync.
- **No worked example exists.** Line 113: *"Not yet produced (deferred to v2.2.0)"* — same gap as code-review.

**What is unclear or ambiguous:**
- **`claim_id` preservation.** Line 22: *"claim_id (preserve the input ID)"* — but the prompt template uses numbered claims (`1. [claim 1]`). If the model renumbers or reorders, the `claim_id` won't match the input. No reconciliation strategy is specified.

---

## §2. Score on the 8-Dimension Rubric

| Dimension | Score | Justification |
|---|---|---|
| **Catalog of composable units** | 2 | The named rule library (`most-severe`, `majority`, `union-dedup`, etc.) and the schema column-type spec form a machine-readable catalog. The schema JSON is parseable and the rules have formal algorithms. |
| **Dynamic composition** | 1 | The `--mode quick\|standard\|thorough` changes pipeline depth, and `--schema` changes consolidation shape. But the 4 phases are fixed — there's no replanner that adapts the pipeline based on intermediate results. Mode is selected at invocation, not dynamically. |
| **V-loop depth** | 1 | `phases_completed` in `run-manifest.json` provides end-of-phase tracking, and `thorough` mode adds post-hoc verification. But there's no per-step rollup or intent gate — verification is a separate Phase, not embedded in each step. |
| **Enforcement** | 0 | The skill is entirely honor-system. No CI gate validates `run-manifest.json` against the schema. No IDE hook checks markdown formatting. No delivery blocker prevents publishing a non-compliant consolidated report. The rules are documentation, not enforcement. |
| **Parent/worker split** | 2 | Explicit orchestrator (the skill) dispatches N workers (models) via 4 documented mechanisms. The split is clear, the dispatch mechanics are ranked, and the fail-soft policy is defined. |
| **Evidence model** | 1 | `thorough` mode has an evidence ledger with per-claim source verification, and the schema supports `source_refs` and `confidence`. But there's no tiered sufficiency model or staleness check — evidence is tracked but not graded against a threshold. |
| **SE + DevOps unified** | 1 | Covers research (SE-adjacent) and code review (DevOps-adjacent) via separate example recipes. But they're not unified in one model — each requires a different schema and conflict rules. The skill is task-agnostic but doesn't provide a unified framework that spans both. |
| **Team customization** | 1 | `--schema` provides runtime customization for output shape and conflict rules. Example recipes provide task-type-specific defaults. But there's no overlay-pack mechanism — deep customization requires forking the skill or passing a full schema every run. |

**Total: 9/16**

---

## §3. Top 5 Improvements (ranked by impact × effort)

### 1. Fix dispatch script bug in code-review.md and fact-check.md

- **Issue:** Both examples pass `"$OUT/prompt.md"` (a file path) to `opencode run`, which expects a prompt string.
- **Why it matters:** The examples will fail when copy-pasted. This undermines trust in the skill's provenance.
- **Concrete change:** `rules/examples/code-review.md:33-43` and `rules/examples/fact-check.md:38-48` — replace `"$OUT/prompt.md"` with `"$(cat "$OUT/prompt.md")"` or use a heredoc-to-variable pattern matching the research example (`PROMPT="$(cat /path/to/research-prompt.md)"`).
- **Effort:** low
- **Impact:** high
- **Score:** high (high impact / low effort)

### 2. Add a validation script for `run-manifest.json` and output compliance

- **Issue:** The skill has zero enforcement (score 0 on the Enforcement dimension). All rules are honor-system.
- **Why it matters:** Without validation, a non-compliant `consolidated.md` or malformed `run-manifest.json` will go undetected. The skill's audit trail is only as good as the implementer's discipline.
- **Concrete change:** Create `scripts/validate-multi-ai-out.sh` that checks: (a) `run-manifest.json` has all required fields per `output-schema.md`, (b) `phases_completed` matches actual files present, (c) `consolidated.md` follows markdown formatting rules (no `***`, blank lines around tables, header/body cell count match), (d) `conflicts.md` exists if `consolidation.unresolved_conflicts > 0`. Add a reference in `SKILL.md` under "See also."
- **Effort:** medium
- **Impact:** high
- **Score:** high (high impact / medium effort)

### 3. Rename or clarify `majority-with-uncertain` and fix numbered-rule references

- **Issue:** The rule name suggests a loose majority but the algorithm is near-unanimity. Conflict resolution examples reference "rule 4" and "rule 3" which don't exist as numbered rules.
- **Why it matters:** Misleading naming causes incorrect rule selection. Phantom rule numbers cause confusion when readers can't find the referenced rule.
- **Concrete change:** (a) `rules/consolidation-rules.md:181` — rename to `strict-consensus-or-unverified` or add a subtitle: *"also known as near-unanimity rule; any dissent blocks consensus."* (b) `rules/consolidation-rules.md:231-234` — replace `"rule 4 (outlier downgrade)"` with `"prefer-with-evidence-then-newer-then-strict (outlier downgrade step)"` and `"rule 3 (strict)"` with `"majority"`.
- **Effort:** low
- **Impact:** medium
- **Score:** medium (medium impact / low effort)

### 4. Remove or quarantine time-sensitive references

- **Issue:** GitHub issue numbers (#6651, #11215, etc.), "Known bug (2026-06)", and version-specific workarounds will become stale and misleading.
- **Why it matters:** A reader in 2027 will see "Known bug (2026-06)" and not know if it's still relevant. Closed issues will make the text look outdated.
- **Concrete change:** (a) `rules/dispatch-mechanics.md:28` — replace the 6 issue numbers with *"Dynamic per-call model selection is a frequently-requested feature; check the OpenCode issue tracker for current status."* (b) `rules/dispatch-mechanics.md:86` — replace *"Known bug (2026-06)"* with *"Known limitation: the SDK may override model selection with the agent's fallback chain. Check current SDK documentation."* (c) Move all version-specific workarounds to a `KNOWN-ISSUES.md` file that can be updated independently.
- **Effort:** low
- **Impact:** medium
- **Score:** medium (medium impact / low effort)

### 5. Specify the default model discovery algorithm and verifier model selection

- **Issue:** "Default model discovery" (SKILL.md:72-73) and "verifier model" (SKILL.md:81) are described in prose but not algorithmically specified.
- **Why it matters:** An implementer cannot build the default discovery without guessing how to determine "provider families" or "reasoning-capable" models. The verifier model selection affects cost and is undefined.
- **Concrete change:** (a) `SKILL.md:72-73` — add a pseudocode block:
  ```
  function defaultModelSet(config):
    providers = config.agents.filter(a => a.mode == "subagent")
    families = groupBy(providers, p => p.provider.split("/")[0])
    selected = []
    for family in families (sorted by model count desc):
      selected += family.models.slice(0, 2)  // max 2 per family
      if selected.length >= 6: break
    if selected.length < 2: error("Need ≥2 models from different families")
    return selected
  ```
  (b) `SKILL.md:81` — add: *"The verifier model is the highest-capability model from the original dispatch that is NOT the model that made the claim. If only 1 model is available, skip verification for that claim."*
- **Effort:** medium
- **Impact:** medium
- **Score:** medium (medium impact / medium effort)

---

## §4. Open Questions

1. **What is the skill's runtime environment assumption?** The dispatch mechanics assume `npx`, `opencode-ai`, and various MCP servers are available. Is the skill intended to run only inside an OpenCode session, or can it be invoked from a CI pipeline, a cron job, or a different agent harness? The answer affects which dispatch mechanisms are viable defaults.

2. **What is the cost model?** The skill dispatches N models in parallel, potentially with extractor-model fallback (N additional calls), and `thorough` mode adds N_items × 1 verifier call. For a 6-model run with 36 items, this could be 6 + 6 + 36 = 48 LLM calls. Is there a cost budget or circuit-breaker? Should the skill warn the user before dispatching?

3. **What is the intended audience?** The skill documentation oscillates between "user invokes via `/multi-ai-task`" (suggesting end-user) and "implementer builds the 4-phase pipeline" (suggesting skill developer). Are these the same person? If the skill is invoked via the skill tool, who implements the pipeline — the host agent reading the skill, or a pre-built runner?

4. **What happens when the skill is invoked recursively?** The provenance section mentions a "self-review run" where the skill reviewed itself. But the skill assumes the orchestrator is a single agent dispatching to N workers. In a recursive invocation, the orchestrator IS a worker. Are there deadlock or infinite-recursion risks?

5. **What is the relationship between this skill and the `deep-research` skill?** The "See also" section (SKILL.md:286) mentions `deep-research` for "a deep 8-phase research methodology." Is `multi-ai-task` intended to replace `deep-research` for multi-model research, or complement it? The research example's prompt template (§8 "Cross-AI Dedup Instructions") suggests the per-model prompt should include dedup instructions — but that's the skill's job, not the model's.

---

## §5. Confidence

- **Overall confidence:** medium
- **What would change your assessment:** A worked code-review or fact-check example (currently deferred to v2.2.0) would validate that the schema, dispatch, and consolidation rules actually work end-to-end for non-research tasks. Without it, the skill's task-agnosticism claim is unverified — the only proven run is the research prior-art run, which may have shaped the rules to fit that specific task type. Additionally, clarity on whether the skill is a "read and implement" document for the host agent or a "invoke and forget" tool would change how I assess the enforcement gap (score 0) — if the host agent is expected to implement the pipeline, enforcement is the host's responsibility, not the skill's.
