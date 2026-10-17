# Critical Self-Review: `multi-ai-task` Skill (v2.1.0)

## §1. Critical Assessment

### 1. `SKILL.md` (entry point, 256 lines)

**What works well:**
- The **When to use / When NOT to use** table (lines 35–50) is genuinely useful and prevents misuse. The latency/cost trade-offs are honest.
- The **proven provenance** section (lines 236–248) anchors the skill in real data (6 models, 150+ mentions → 36 unique items, 2026-06-27 run).

**What is missing or wrong:**
- **`--concurrency` is in the argument hint but missing from the inputs table.** Line 4 lists `[--concurrency parallel|sequential]`, but the table at lines 62–70 omits it entirely. Users must grep the doc for the flag.
- **`user-invocable: false` contradicts the description.** Line 5 says users cannot invoke it, yet line 3 says "Use this skill to dispatch any task..." and the "Usage" block (line 56) shows a user-facing `/multi-ai-task` command. If this is parent-agent-only, the description should say so.
- **Double-negative confusion in "What this skill does NOT do".** Line 28: "- Inject the schema into the prompt unless `--no-auto-inject` is set (default ON)". This is a triple-negative ("does NOT... unless... no..."). It should read: "Auto-inject the schema into the prompt (default ON; use `--no-auto-inject` to disable)".

**What is unclear or ambiguous:**
- The version mismatch: frontmatter says `version: 2.1.0` (line 6), but the task brief says v2.0.0. Which is canonical?
- The default output dir is `./multi-ai-out/<timestamp>/` (line 66), but the proven run lives at `docs/research-260624/` (line 240). Is the default honored, or do users typically override it?

---

### 2. `rules/methodology.md` (4-phase pipeline, 208 lines)

**What works well:**
- Phase 2 extraction pseudocode (lines 38–64) is concrete and actionable. The 4 fallback paths (table → tags → extractor → paragraphs) are well-designed.
- The audit-trail principle (lines 197–203) and idempotency note (lines 207–208) are strong.

**What is missing or wrong:**
- **Extractor model "no extra cost" claim is false.** Line 104 says the extractor model "caches the response, no extra cost." But line 52 says the extractor is dispatched with a new prompt: *"Reformat this response into the following JSON schema..."*. That is an additional LLM call. The "no extra cost" claim should be removed or clarified as "no extra cost beyond one additional call."
- **`run-manifest.json` schema drifts from `output-schema.md`.** Lines 149–174 include `aliases`, `consolidation.dedup_merges`, `consolidation.score_aggregations`, and `consolidation.unresolved_conflicts`. The canonical schema in `output-schema.md` (lines 209–226) omits all of these. One file must be the single source of truth.

**What is unclear or ambiguous:**
- **Total failure mode is undocumented.** The skill says "If a model fails, the skill still produces a partial consolidated output from the models that did respond" (line 195), but it never says what happens if **zero** models respond. Empty `consolidated.md`? Error? Infinite wait?

---

### 3. `rules/dispatch-mechanics.md` (177 lines)

**What works well:**
- The parallel vs sequential comparison (lines 95–103) is pragmatic and includes the MCP port collision caveat.
- The auth table (lines 137–143) is a concise reference.

**What is missing or wrong:**
- **Fake issue references.** Lines 29 and 75 cite GitHub issues (#6651, #11215, #18615, #29447, etc.) as if they are real public issues. They are not resolvable URLs and appear to be fictional or internal placeholders. Citing unverifiable issue numbers undermines trust.
- **Inconsistent `--dangerously-skip-permissions` usage.** Mechanism 2's example (line 45) includes the flag, but `code-review.md` (line 45) and `fact-check.md` (line 50) explicitly omit it for read-only tasks. If the default mechanism includes it, the examples should either all include it (with a warning) or all omit it. The current state trains users to copy-paste an unsafe default.
- **"Default is Mechanism 2" vs "preferred-if-available".** `SKILL.md` line 193 says "Default is Mechanism 2", but Mechanism 1 is labeled "preferred-if-available" (line 9). If Mechanism 1 is preferred, why isn't it the default? The answer (harness restrictions) is buried in line 30; it should be in the Mechanism 1 header.

**What is unclear or ambiguous:**
- **"MCP port collision" is jargon without definition.** Lines 98, 102, and 124 mention MCP port collisions as a primary reason to choose sequential dispatch, but nowhere does the doc explain what an MCP is, why it binds a port, or how to detect a collision. Users who don't already know OpenCode's MCP architecture will be lost.

---

### 4. `rules/consolidation-rules.md` (334 lines)

**What works well:**
- The named rule library (lines 165–222) is the strongest part of the skill. Edge cases are explicitly handled (e.g., `most-severe` lone-reviewer downgrade, `longest-with-quote` no-quote fallback).
- The conflict documentation template (lines 227–234) is concrete and copy-pasteable.

**What is missing or wrong:**
- **`prefer-with-evidence-then-newer-then-strict` name contradicts its behavior.** Lines 156–162 describe a rule whose *fourth* step is "prefer the value with the strongest evidence quote, then prefer the most recent." The word "strict" in the name is never defined. Does "strict" mean the outlier downgrade (step 3)? If so, the name should be `prefer-evidence-then-recency-then-majority`.
- **`majority-with-uncertain` formula is broken for N<3.** Line 183: *"require ≥ max(2, ceil(N/2))"*. For N=1, this requires 2 models — impossible, so every single-model run returns `unverified`. For N=2, it requires 2 models (unanimity), which is stricter than `majority` but undocumented. The rule should state: *"For N≥3, require ≥ ceil(N/2); for N=2, require unanimity; for N=1, always return unverified."*
- **`merge-exact` is misplaced.** Line 217 lists `merge-exact` under "Conflict resolution rules," but its description (line 220) says *"group by primary key; for each group, union all fields"* — that is a **dedup** algorithm, not a field-level conflict resolver. It should live in Phase 3 DEDUP, not Phase 3.5 RESOLVE.

**What is unclear or ambiguous:**
- **Undefined behavior for unknown rule names.** If a user passes `"conflict_resolution": {"foo": "custom-rule"}` and that rule is not in the named library, does the skill fall back to a default, throw an error, or silently ignore it? The doc never says.

---

### 5. `rules/output-schema.md` (243 lines)

**What works well:**
- The WYSIWYG formatting rules (lines 231–242) are unusually thorough and reflect real pain with markdown renderers.
- The two-mode structure (Mode A structured / Mode B generic) is clearly delineated.

**What is missing or wrong:**
- **`run-manifest.json` is incomplete.** Lines 209–226 omit `aliases`, `consolidation` sub-objects, and `models_failed` structure that are present in `methodology.md`. This file claims to host the canonical schema but is missing fields.
- **§2A Items Table `Fields per model` column is impractical.** Line 61 shows `m1: {...}, m2: {...}` as cell content. In a real markdown table with 6 models and 5+ fields each, this cell would be 200+ characters wide and break every renderer. It should be a compact summary (e.g., `cat: adjacent, score: 3`) or moved to a detail section.
- **`conflicts.md` has no defined schema.** Line 205 says it is "Same as §4 but as a standalone file," but §4 (lines 121–126) is a markdown table with 6 columns. If a tool wants to parse `conflicts.md`, it needs a schema — especially since `conflict_resolution` values can be free-form strings.

**What is unclear or ambiguous:**
- **Mode A trigger is ambiguous.** Line 13 says Mode A triggers when `--schema` is passed with `type: "table"`. What if `--schema` is passed with `type: "list"` or another type? Does Mode A still apply? The doc only defines table and generic modes.

---

### 6. `rules/examples/research-prior-art.md` (185 lines)

**What works well:**
- The 14-entry alias map (lines 125–141) is genuinely useful and specific. It saves users from reinventing semantic dedup.
- The worked example references real files in the repo (lines 171–178), making it verifiable.

**What is missing or wrong:**
- **"Diminishing returns past 6" is unsupported.** Line 182: *"diminishing returns past 6 (this is an empirical observation, not a measured curve — run your own benchmark if you want a hard number)"*. This is a hedge that adds no value. Either cite data from the 6-model run or delete the claim.
- **Scoring rubric dimension names mismatch the schema field names.** The rubric uses `catalog`, `dynamic`, `v_loop`, `enforce`, `parent_worker`, `evidence`, `se_devops`, `customization` (lines 107–114), but the schema columns are `composition_model`, `v_loop_support`, `enforcement_mechanism`, `parent_worker_split`, `evidence_model`, `dynamic_composition`, `se_fit`, `devops_fit`, and `maturity` (lines 76–91). There is no mapping table. A user trying to connect rubric scores to schema rows will fail.

**What is unclear or ambiguous:**
- The `research-prompt.md` template is described in prose (lines 37–68) but not provided as a reusable file. Should users copy-paste from the example, or is there a `templates/research-prompt.md` somewhere? The doc doesn't say.

---

### 7. `rules/examples/code-review.md` (111 lines)

**What works well:**
- The composite key explanation (lines 68–71) is clear and corrects a common schema error (`"primary_key": "file:line"` vs dual `dedup_key: true`).
- The security note about `--dangerously-skip-permissions` (line 45) is well-placed.

**What is missing or wrong:**
- **"Worked example: Not yet produced (deferred to v2.2.0)"** (line 111). This is a skill at v2.1.0 with a major example missing. For a code-review recipe, users have nothing to validate their setup against.
- **The schema does not require `evidence`.** The prompt says *"include a verbatim code quote in the description or a separate 'evidence' field"* (lines 29–30), but the schema marks `evidence` as optional (no `required: true`). This means a model can return a finding with zero evidence and it will still be extracted and merged. For code review, un-evidenced findings should be dropped or flagged.
- **§5 "Per-Reviewer Statistics" is undefined.** Line 88 lists it as an output section, but there is no schema, table structure, or content definition for it anywhere in the skill.

**What is unclear or ambiguous:**
- The example dispatches to only **2 models** (line 33). `dispatch-mechanics.md` says the minimum viable is 2, but `majority` rules (used for `category`) require >N/2 agreement. With N=2, a 1-1 tie returns `null` per `consolidation-rules.md:178`. The example should use 3+ models to make the conflict-resolution rules meaningful.

---

### 8. `rules/examples/fact-check.md` (113 lines)

**What works well:**
- The consensus requirements (lines 103–106) are concrete and parameterized by N.
- The `lowest-of-majors` confidence rule (line 75) is the right default for high-stakes verification.

**What is missing or wrong:**
- **"Worked example: Not yet produced (deferred to v2.2.0)"** (line 113). Same gap as code-review. Two of three examples are placeholders.
- **Threshold note is self-contradictory.** Lines 103–106 define threshold as `max(2, ceil(N/2))`. Line 109 says *"The '3+ models' rule in the original draft was a typo; the correct threshold is parameterized."* But for N=3, `max(2, ceil(1.5)) = 2`, not 3. So the "original draft" wasn't a typo — it was a different (stricter) rule. The note should say the threshold was lowered from unanimous to majority, not that it was a typo.
- **3 models is too few for high-stakes fact-checking.** The example dispatches to 3 models (line 38) with threshold=2. Two models agreeing is a weak bar for "high-stakes" claims. The example should recommend 5+ models and note that 3 is a minimum, not a recommendation.

**What is unclear or ambiguous:**
- **`counter_evidence` semantics are undefined.** The schema includes `counter_evidence` (line 64), but the doc never says when to populate it (only when verdict is false? Also for partially-true? What if one model provides counter-evidence and another doesn't?). The `concatenate-all` rule will merge empty strings, which is fine, but the human reviewer needs guidance on interpretation.

---

## §2. Score the Skill on the 8-Dimension Rubric

| Dimension | Score | Justification |
|---|---|---|
| **Catalog of composable units** | **1** | The named rule library (`most-severe`, `majority-with-uncertain`, etc.) is an informal but well-documented catalog. It is not machine-readable (no JSON Schema for rules, no validation), but it is more than ad-hoc. |
| **Dynamic composition** | **1** | The skill has three modes (`quick`, `standard`, `thorough`) that act as a coarse replanner. There is no runtime replanning based on intermediate results (e.g., "models disagree → dispatch a tie-breaker"). |
| **V-loop depth** | **2** | Phase 2 has per-step extraction with 4 fallback tiers, validation, and truncation. `thorough` mode adds a per-item verifier loop. This is effectively "per-step rollup + intent gate." |
| **Enforcement** | **0** | No CI gate, no IDE hook, no delivery blocker. The skill is entirely honor-system. A user can ignore `consolidated.md` and act on a single model's raw output without friction. |
| **Parent/worker split** | **2** | Explicitly split: the skill is the orchestrator (parent), models are workers. The `run-manifest.json` tracks which worker produced which output. |
| **Evidence model** | **2** | Tiered sufficiency is built in: primary quotes win, `last_verified` dates matter, `thorough` mode adds source verification. Staleness is handled via recency tie-breaks. |
| **SE + DevOps unified** | **1** | Covers SE (code-review example) but has no DevOps example (infra review, deployment validation, security audit). The research example's `se_devops` dimension evaluates *other tools*, not the skill itself. |
| **Team customization** | **1** | Supports custom schemas and alias maps, but teams must fork the skill files to add them. There is no "overlay pack" mechanism (e.g., `--team-config my-team.json` that layers rules on top). |

**Total: 10 / 16**

---

## §3. Top 5 Improvements (ranked by impact × effort)

### 1. Fix the broken `majority-with-uncertain` threshold formula
- **Issue:** `max(2, ceil(N/2))` makes N=1 impossible and N=2 unanimous, neither of which is documented.
- **Why it matters:** Users dispatching 1–2 models for quick fact-checks will get `unverified` for every claim, making the skill useless at small N.
- **Concrete change:** `rules/consolidation-rules.md:183`
  ```markdown
  - **Algorithm:** require ≥ `max(2, ceil(N/2))` models to agree on a value.
  + **Algorithm:** require ≥ `ceil(N/2)` models to agree. For N=1, always return `unverified`.
  ```
  And `rules/examples/fact-check.md:103-109`: update the threshold table to match.
- **Effort:** low
- **Impact:** high
- **Score:** 3.0

### 2. Add real worked examples for code-review and fact-check
- **Issue:** Two of three examples are "Not yet produced (deferred to v2.2.0)".
- **Why it matters:** Users cannot validate their schema or compare their output against a known-good baseline. The skill's credibility rests on the single research example.
- **Concrete change:** Produce `docs/research-260624/SB_CONSOLIDATED_CODE_REVIEW.md` and `..._FACT_CHECK.md` by running the skill with the provided recipes on real inputs. Add the paths to `rules/examples/code-review.md:111` and `fact-check.md:113`.
- **Effort:** medium
- **Impact:** high
- **Score:** 2.0

### 3. Unify the `run-manifest.json` schema to a single source of truth
- **Issue:** `methodology.md` has `aliases`, `consolidation`, `phases_completed`; `output-schema.md` omits them.
- **Why it matters:** Tooling that parses `run-manifest.json` will break depending on which file the author used as reference. It also signals sloppiness in a skill that claims to produce audit-grade artifacts.
- **Concrete change:** Move the canonical schema to `rules/output-schema.md` (which already claims to host it). Expand it to include all fields from `methodology.md:149-174`. In `methodology.md`, replace the inline schema with a cross-reference: *"The canonical schema lives in `rules/output-schema.md`."*
- **Effort:** low
- **Impact:** medium
- **Score:** 2.0

### 4. Add `--concurrency` to the inputs table and clarify MCP port collision
- **Issue:** `--concurrency` is advertised in the CLI hint but absent from the inputs table. "MCP port collision" is unexplained jargon.
- **Why it matters:** Users won't discover the flag from the table, and they won't understand why parallel dispatch fails mysteriously.
- **Concrete change:** `SKILL.md:62-70` add row:
  ```markdown
  | `--concurrency` | NO | `parallel` | `parallel` (faster, risk of MCP port collision) or `sequential` (slower, safer). See `rules/dispatch-mechanics.md`. |
  ```
  And in `dispatch-mechanics.md:98`, add a one-sentence definition: *"MCP (Model Context Protocol) servers often bind to fixed local ports (e.g., 3111). Parallel processes may race to bind the same port, causing one or more to fail."*
- **Effort:** low
- **Impact:** medium
- **Score:** 2.0

### 5. Add a DevOps example (e.g., Terraform plan review or security audit)
- **Issue:** The skill claims to be task-agnostic but has zero DevOps examples. The 8-dimension rubric's "SE + DevOps unified" dimension is only half-covered.
- **Why it matters:** DevOps teams evaluating the skill will see code-review and research examples and conclude it's not for them. The `se_devops` dimension in the research rubric implies DevOps is in scope, but the skill doesn't demonstrate it.
- **Concrete change:** Create `rules/examples/devops-review.md` with a recipe for parallel review of a Terraform plan or Kubernetes manifest. Schema would include `resource`, `severity`, `compliance_rule`, `remediation`. Conflict rules: `most-severe` for severity, `union-dedup` for affected resources.
- **Effort:** medium
- **Impact:** medium
- **Score:** 1.0

---

## §4. Open Questions

1. **Who is the intended audience?** The `user-invocable: false` flag suggests this is parent-agent-only, but the `/multi-ai-task` usage syntax and task-agnostic framing suggest end-user invocation. Is this skill meant to be wrapped by another skill (e.g., `deep-research` calls `multi-ai-task` internally), or is it a top-level command?

2. **What is the actual implementation?** The skill reads like a specification for a CLI tool (`npx opencode-ai run --model ...`), but there is no source code, test suite, or `package.json` in `skills/multi-ai-task/`. Is this a meta-skill (documentation only, executed by the parent agent via bash), or is there a hidden implementation elsewhere?

3. **How are schema conflicts validated?** If a user passes `--schema` with a `type: "table"` but the model returns a bulleted list, the extraction falls back to tags, then extractor, then paragraphs. At what point does the skill give up and flag a schema mismatch in `run-manifest.json`? The doc says "log warning" but doesn't define the warning format.

4. **What is the relationship to `silver-bullet`?** `SKILL.md:254` says *"for managing the SDLC workflow that may consume multi-ai-task's outputs"*. Does `silver-bullet` invoke this skill automatically in any workflow step, or is it purely manual?

---

## §5. Confidence

- **Overall confidence:** **medium**
- **What would change my assessment:** 
  - Seeing the actual implementation (if any) would resolve whether the pseudocode and schemas are aspirational or enforced. If this is pure documentation, many of the schema-drift and formula issues are moot (the parent agent improvises). If there is code, the gaps are bugs.
  - A clarification on `user-invocable: false` would change how I judge the UX issues (e.g., missing `--concurrency` from the inputs table matters less if no human ever reads it).
