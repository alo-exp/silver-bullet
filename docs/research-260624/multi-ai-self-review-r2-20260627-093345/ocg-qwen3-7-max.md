# Critical Self-Review: multi-ai-task Skill

## §1. Critical Assessment

### SKILL.md

**What works well:**
- Clear "When to use / Don't use" table (lines 35-42) — actionable decision criteria.
- The `--schema` parameter section (lines 86-156) is thorough with two modes, column types, and conflict-resolution references.

**What is missing or wrong:**
- **Version mismatch:** frontmatter says `version: 2.1.0` (line 6) but the task description says "v2.0.0". One of these is wrong.
- **`--concurrency` parameter undocumented in usage line:** listed in the inputs table (line 69) but absent from the usage syntax (line 57). Users won't discover it.
- **Contradictory placement of auto-inject in "What this skill does NOT do":** line 28 says "Inject the schema into the prompt unless `--no-auto-inject` is set (default ON" — but this section is titled "What this skill does NOT do". The skill DOES inject by default; this belongs in "What this skill does".

**What is unclear or ambiguous:**
- The failure modes table (lines 218-228) duplicates `dispatch-mechanics.md` lines 120-129 nearly verbatim. Which is authoritative?
- "score-aggregate.md (planned) but not in the contract" (line 228) — documenting a known inconsistency as "ignore for v2.x" is technical debt, not a fix.

---

### methodology.md

**What works well:**
- Phase 2 pseudocode (lines 38-64) gives a clear 4-step fallback chain for structured extraction.
- The "Cross-cutting principles" section (lines 173-195) articulates the hybrid deterministic+LLM design well.

**What is missing or wrong:**
- **`run-manifest.json` example missing `schema_auto_injected` field:** lines 147-169 show the manifest schema but omit the field documented at lines 15 and SKILL.md:147. Inconsistency.
- **Phase 3 is thin:** lines 108-118 give 5 bullet points for the core consolidation step but don't reference `consolidation-rules.md` explicitly. A reader hitting Phase 3 cold won't know the algorithms are elsewhere.
- **"Idempotent re-runs" is misleading:** line 194 claims idempotency but "does NOT cache across runs by default" — true idempotency requires same input → same output, which isn't guaranteed if models are non-deterministic.

**What is unclear or ambiguous:**
- The "extractor model" is defined 3 times (methodology.md:52-58, methodology.md:104, SKILL.md:153) with slightly different wording. Which is canonical?
- "one-row-per-paragraph (very lossy)" (line 63) — no guidance on when this is acceptable vs when to abort and flag failure.

---

### dispatch-mechanics.md

**What works well:**
- The 4-mechanism hierarchy (lines 9-89) is well-ordered with clear "use when" criteria.
- The "Choosing the right mechanism" decision table (lines 169-177) is immediately actionable.

**What is missing or wrong:**
- **Stale bug reference:** line 75 cites "Known bug (2026-06): Issue #18615" — if fixed, this is misleading; if open, it should say "still open as of [date]".
- **Mechanism 3 has no setup guidance:** references `client.session.promptAsync()` (line 65) but doesn't explain how to start the OpenCode server or what version is needed.
- **Language inconsistency:** Mechanism 4 shows Python (lines 81-88) but the rest of the skill uses bash/JS.

**What is unclear or ambiguous:**
- "MCP port collision caveat" (line 102) says "restart the MCP between dispatches" — operationally complex, not automated, and no script example.
- The auth table (lines 137-143) doesn't explain what happens if auth expires mid-run (e.g., OAuth token refresh).

---

### consolidation-rules.md

**What works well:**
- The named rule library (lines 168-224) is formally defined with purpose, input, algorithm, and edge cases for each rule.
- The conflict documentation format (lines 228-237) is clear and reproducible.

**What is missing or wrong:**
- **Alias map example is research-specific but lives in the "generic" rules file:** lines 85-95 show `AutoGen/AG2`, `MAF`, etc. — but line 330 says "The alias map is task-specific, not part of this skill's core." Contradiction: the example in the core file is research-only.
- **`most-severe` edge case incomplete:** line 176 says "if 1/N reviewers disagrees with no evidence quote, downgrade the lone max" — but what if N=2 and both say different severities? The rule doesn't cover the 2-model tie case.
- **`majority` tie-break assumes schema enumeration order:** line 181 says "Ties broken by schema-defined enumeration order (first listed wins)" — but what if the field isn't an `enum` type? No fallback.

**What is unclear or ambiguous:**
- Fuzzy match threshold "≥80% similar" (line 136) — no justification for 80% vs 75% or 85%. Is this empirical or arbitrary?
- `majority-with-uncertain` threshold `max(2, ceil(N/2))` (line 187): with N=2, threshold=2 (unanimity required). This is a design choice but not explained — users might expect "majority" to mean >50%.

---

### output-schema.md

**What works well:**
- The two-mode structure (Mode A structured, Mode B generic) is clearly separated.
- The "Markdown formatting rules" (lines 231-242) are specific and actionable (e.g., "All delimiter rows must start and end with `|`").

**What is missing or wrong:**
- **§2 defined twice:** "§2. Items Table (Mode A)" (line 53) and "§2. Items Table (Mode B)" (line 79). Should be §2A/§2B or merged into one section with subsections.
- **`run-manifest.json` schema incomplete:** lines 209-227 omit `schema_auto_injected`, `aliases`, and `phases_completed` fields documented in methodology.md and SKILL.md.
- **"Markdown formatting rules" labeled "CRITICAL" but buried at end:** lines 231-242 should be near the top of the file, not after all the section definitions.

**What is unclear or ambiguous:**
- §5 "Aggregated Scores" marked "optional" (line 130) but the research example treats it as mandatory. Which is it?
- "Fields per model" column (line 67) says "truncate if verbose" — no guidance on truncation length or format.

---

### research-prior-art.md

**What works well:**
- The worked example is concrete with actual file paths (`docs/research-260624/SB_CONSOLIDATED_PRIOR_ART_REPORT.md`) and a real 6-model dispatch.
- The alias map (lines 125-141) is comprehensive with 14 entries.

**What is missing or wrong:**
- **Dispatch script uses `cd "$OUT"` (line 16):** changes working directory for the entire shell session — fragile if the script is sourced or if subsequent commands assume the original CWD.
- **Scoring rubric dimension naming inconsistency:** line 111 uses `parent_worker` but consolidation-rules.md and output-schema.md use `parent_worker_split`. Which is canonical?
- **"Variations to try" makes unverified claims:** line 182 says "8-10 models captures more unique finds but diminishing returns past 6" — labeled "empirical observation, not a measured curve" but presented as guidance anyway.

**What is unclear or ambiguous:**
- "Add new aliases to this map as they surface" (line 142) — but the alias map is in the example file, not a mutable config. How does the user actually persist aliases across runs?

---

### code-review.md

**What works well:**
- The schema (lines 37-55) is well-tailored with `file:line` composite key and `most-severe` for severity.
- The "Custom strategies" table (lines 76-83) is concise and justified.

**What is missing or wrong:**
- **Composite key syntax unclear:** line 40 says `primary_key: "file:line"` but columns define `file` and `line` separately (lines 42-43). Is the composite key a string concatenation, or should both columns be marked `dedup_key: true`? The schema doesn't show either column with `dedup_key: true`.
- **"Worked example: Not yet produced" (line 92):** the skill claims proven provenance but only has one worked example (research). Code-review and fact-check are untested recipes.
- **"false-positive rate if measurable" (line 70):** how do you measure false positives without ground truth? This is aspirational, not implementable.

**What is unclear or ambiguous:**
- The dispatch prompt (line 15) says "Review the file at /path/to/code.py" — no error handling if the file doesn't exist or the model can't access it.

---

### fact-check.md

**What works well:**
- The `majority-with-uncertain` + `lowest-of-majors` combination (lines 56-58) is well-chosen for high-stakes verification.
- The "Consensus requirements" section (lines 89-95) is explicit about thresholds.

**What is missing or wrong:**
- **`majority-with-uncertain` return value inconsistency:** line 63 says "if 2 say true and 1 says false, default to `partially-true`" — but consolidation-rules.md line 187 says the rule returns `uncertain`, not `partially-true`. Which is it?
- **Consensus threshold unreachable with 2 models:** line 92 says "3+ models agree on `true`" — but the dispatch example uses only 3 models (line 29). If one fails, the threshold is unreachable. No fallback documented.
- **"Worked example: Not yet produced" (line 98):** same gap as code-review.

**What is unclear or ambiguous:**
- The dispatch prompt (lines 14-27) includes claims inline — for a large claim list (50+), this will exceed per-model token limits. No guidance on chunking or batching.

---

## §2. Score the Skill on the 8-Dimension Rubric

| Dimension | Score | Justification |
|---|---|---|
| **Catalog of composable units** | 1 | The skill defines informal roles (dispatch, extract, consolidate, synthesize) but has no machine-readable catalog of task types or consolidation strategies. The named rule library is documented in prose, not a queryable manifest. |
| **Dynamic composition** | 1 | The `--mode` parameter (quick/standard/thorough) is a static replanner — it selects a pre-defined pipeline variant. There's no catalog-backed composition or audit log of why a particular consolidation strategy was chosen. |
| **V-loop depth** | 1 | The skill has per-phase structure (4 phases) but no per-step rollup or intent gate. `thorough` mode adds a verification step, but it's a flat N×1 verifier call, not a V-model rollup with intent checking. |
| **Enforcement** | 0 | The skill is entirely honor-system. There are no CI gates, IDE hooks, or delivery blockers. The "CRITICAL" markdown formatting rules (output-schema.md:231) are advisory, not enforced. |
| **Parent/worker split** | 2 | Explicit orchestrator (the skill) dispatches to N worker models. The parent/worker boundary is clear: the skill orchestrates, the models execute. The dispatch-mechanics.md documents 4 mechanisms for this split. |
| **Evidence model** | 1 | `thorough` mode adds an evidence ledger (per-claim source URL + verdict), but it's optional and informal. There's no tiered sufficiency model or staleness detection. The `confidence_self` field (consolidation-rules.md:41) is self-reported by the model, not verified. |
| **SE + DevOps unified** | 0 | The skill covers neither SE nor DevOps production task types. It's task-agnostic by design, which means it doesn't unify any domain — it's a meta-orchestrator. N/A scored as 0 per the rubric instruction. |
| **Team customization** | 0 | No overlay packs, no process templates, no team-specific configuration. The skill is fork-required if a team wants to customize the consolidation pipeline. The example recipes are the closest thing to "packs" but they're not composable. |

**Total: 6/16**

---

## §3. Top 5 Improvements (ranked by impact × effort)

### 1. Fix the `majority-with-uncertain` return value inconsistency

- **Issue:** fact-check.md says the rule returns `partially-true`; consolidation-rules.md says it returns `uncertain`.
- **Why it matters:** Implementers will produce conflicting outputs depending on which file they read. This is a correctness bug in the spec.
- **Concrete change:** `rules/examples/fact-check.md:63` — change "default to `partially-true` (uncertain)" to "default to `uncertain` (which the user may map to `partially-true` in post-processing if desired)". Alternatively, add a `uncertain_value: "partially-true"` field to the schema's conflict_resolution block.
- **Effort:** low
- **Impact:** high
- **Score:** high/low = high ROI

### 2. Unify the `run-manifest.json` schema across all files

- **Issue:** The manifest is defined 3 times (methodology.md:147-169, output-schema.md:209-227, SKILL.md:170) with different fields. `schema_auto_injected`, `aliases`, and `phases_completed` are missing from some definitions.
- **Why it matters:** Implementers will produce incomplete manifests, breaking reproducibility.
- **Concrete change:** Define the manifest schema once in `rules/output-schema.md` (the canonical location), and have methodology.md and SKILL.md reference it. Add the missing fields:
  ```json
  "schema_auto_injected": true,
  "aliases": {"AutoGen/AG2": "AutoGen"},
  "phases_completed": [1, 2, 3, 4]
  ```
- **Effort:** low
- **Impact:** high
- **Score:** high/low = high ROI

### 3. Clarify composite primary key syntax in the schema

- **Issue:** code-review.md uses `primary_key: "file:line"` (line 40) but doesn't mark either column with `dedup_key: true`. SKILL.md:143 says "list multiple columns with `dedup_key: true`" for composite keys. The example contradicts the spec.
- **Why it matters:** Implementers won't know whether to use a string concatenation or multi-column dedup. Dedup will fail or produce wrong results.
- **Concrete change:** `rules/examples/code-review.md:42-43` — add `dedup_key: true` to both `file` and `line` columns:
  ```json
  {"name": "file", "type": "string", "dedup_key": true, "required": true},
  {"name": "line", "type": "number", "dedup_key": true, "required": true}
  ```
  And remove or clarify `primary_key: "file:line"` on line 40 (it's redundant if both columns are marked).
- **Effort:** low
- **Impact:** medium
- **Score:** medium/low = high ROI

### 4. Add worked examples for code-review and fact-check

- **Issue:** Both files say "Worked example: Not yet produced" (code-review.md:92, fact-check.md:98). The skill claims "proven provenance" but only has one proven run (research).
- **Why it matters:** Users will distrust untested recipes. The skill's credibility rests on the research example; extending to new task types requires proof.
- **Concrete change:** Run the skill end-to-end for a code-review task (e.g., review a known-buggy file) and a fact-check task (e.g., verify 10 claims from a public article). Save outputs to `docs/examples/` and update the "Worked example" sections with file paths.
- **Effort:** medium (requires running the skill, not just editing docs)
- **Impact:** high
- **Score:** high/medium = medium ROI

### 5. Move "Markdown formatting rules" to the top of output-schema.md

- **Issue:** The "CRITICAL" formatting rules (output-schema.md:231-242) are buried at the end of a 243-line file. Implementers who stop reading before the appendix will produce WYSIWYG-incompatible output.
- **Why it matters:** Broken tables in WYSIWYG viewers (Notion, Confluence, GitHub) make the consolidated report unreadable. This is a delivery blocker.
- **Concrete change:** Move lines 231-242 to immediately after the "File header" section (after line 35), and rename to "§0. Markdown Formatting Rules (CRITICAL — read before generating output)".
- **Effort:** low
- **Impact:** medium
- **Score:** medium/low = high ROI

---

## §4. Open Questions

1. **What is the actual version?** SKILL.md frontmatter says `2.1.0`; the task description says `v2.0.0`. Which is correct, and what changed between them?

2. **Who is the intended implementer?** The skill is written as if the orchestrator is an LLM agent (reading the skill and executing it). But the dispatch scripts are bash, the pseudocode is JS, and Mechanism 4 is Python. Is the skill for human engineers, LLM agents, or both? The audience affects how much prose vs code is appropriate.

3. **What happens when `thorough` mode verification fails?** If the verifier model says a source URL doesn't support the claim (`source_verified: false`), does the item get downgraded, removed, or flagged? The output-schema.md mentions the flag but doesn't define the downstream behavior.

4. **Is the skill actually task-agnostic, or is it research-biased?** The consolidation rules, alias examples, skip rules, and the only worked example are all research-specific. A code-review or ideation task has fundamentally different dedup semantics (same line = same finding vs same name = same product). Does the generic framework actually work for non-list tasks (e.g., narrative synthesis, decision support)?

5. **What is the cost model?** The skill dispatches N models × 1 prompt, plus `thorough` mode adds N_items × 1 verifier call. For 6 models × 36 items, that's 6 + 36 = 42 API calls. What's the expected cost in tokens/dollars? Users need this to decide if the skill is worth invoking.

6. **How does the skill handle model refusal?** If a model refuses the prompt (e.g., "I can't help with that"), is it logged as a failure or excluded silently? The failure modes table doesn't cover refusal.

---

## §5. Confidence

- **Overall confidence:** medium
- **What would change your assessment:** Running the skill end-to-end on a non-research task (code-review or fact-check) would reveal whether the "task-agnostic" claim holds or whether the consolidation rules are research-biased. Additionally, seeing the actual consolidated output from the proven run (`docs/research-260624/SB_CONSOLIDATED_PRIOR_ART_REPORT.md`) would let me verify whether the output-schema.md spec matches reality.
