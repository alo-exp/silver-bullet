I'll read all 8 files in parallel to beginthe review.
# Critical Self-Review of `multi-ai-task` v2.1.0

---

## §1. Critical Assessment

### 1. `SKILL.md`

**What works well:**
- The `argument-hint` and `user-invocable: false` frontmatter plus the failure-modes table make the skill's invocation contract explicit.
- The "What this skill does NOT do" list (lines 24-29) sets clear bounds — important for a generalized skill.

**What is missing or wrong:**
- **Version inconsistency between frontmatter and prose.** Frontmatter (line 6) says `version: 2.1.0`; the task prompt and provenance section (lines 235, 247) describe v2.0.0 generalization plus a "v2.1.0" round-2 self-review. But the body presents the auto-inject feature as the v2.1.0 addition while line 146 says "Schema auto-injection (default ON)" without ever stating this is new since 2.1.0. A reader meeting the file cold cannot reconstruct the v2.1.0 changelog from anywhere in-repo — there is no `CHANGELOG.md`.
- **Failure-modes table duplicates `dispatch-mechanics.md` lines 124-133 almost verbatim.** SKILL.md:217-227 and dispatch-mechanics.md:124-133 are nearly row-identical. Two sources of truth will drift; the provenance run already produced at least one drift symptom ("score-aggregate.md" inconsistency row in SKILL.md:227).
- **The "Evidence-ledger" claim (line 81) is unreachable.** Thorough mode produces `evidence-ledger.md`, but `output-schema.md` does not document that file at all. The output structure block (SKILL.md:162-172) lists it, the mode table mentions it, but no schema, no row shape, no verification-verdict field semantics are specified in `output-schema.md`. `thorough` mode is documented as a real feature with no contract.
- **The `--schema` "Mode A preferred" guidance contradicts the provenance note.** Line 155 says "always pass `--schema` for tasks that produce tables/lists"; the provenance run (research-prior-art.md:173) explicitly states the prompt did NOT embed the schema and the skill auto-injected it — i.e., schema was passed as a flag, not embedded. The wording conflates "pass `--schema`" with "embed schema in the prompt," which is exactly the confusion `--no-auto-inject` is meant to resolve.

**What is unclear or ambiguous:**
- **"Auto-discover a balanced default set of 4-6 models" (line 73) — how?** It says the skill "queries the local OpenCode config." But this skill has no runtime code (it is a Markdown skill). Who performs the discovery — the calling agent? In what language? `dispatch-mechanics.md` never implements this discovery. It is a non-actionable claim.
- **"`--dangerously-skip-permissions` is fine for read-only tasks" (line 59 of dispatch-mechanics, referenced from SKILL.md:29)** — but the skill also claims (SKILL.md:28) it does not inject schema "unless `--no-auto-inject` is set." For a skill that does nothing but emit prompts, what determines the security posture beyond a copy-paste snippet? This is agent-judgment territory masquerading as a skill rule.

---

### 2. `rules/methodology.md`

**What works well:**
- Phase 2 extraction pseudocode (lines 38-64) is concrete and ordered, giving an implementer a real algorithm.
- The "Idempotent re-runs" section (line 170) is honest about non-caching.

**What is missing or wrong:**
- **Phase 3.5 / Phase 3.6 phase numbering is off-by-one.** `consolidation-rules.md` introduces "Phase 3.5 — RESOLVE CONFLICTS" (line 136) and "Phase 3.6 — SCORE + SYNTHESIZE" (line 266), but `methodology.md` Phase 3 (lines 108-119) covers *aggregation, dedup, conflict resolution, score aggregation, confidence* in one phase, with no mention of 3.5/3.6. The two files disagree on the phase count (4 in methodology, implicitly 6 in consolidation-rules). `run-manifest.json → phases_completed: [1, 2, 3, 4]` (output-schema.md:235) cannot record 3.5/3.6.
- **"Free-form extraction (Mode B) uses an LLM step to reformat" (methodology.md:159) contradicts methodology.md:78-99**, where the free-form pseudocode is purely deterministic (`splitByH2`, `splitByParagraphs`) with no LLM call. The "Deterministic + LLM-assisted hybrid" section (lines 156-161) misdescribes its own pseudocode.
- **The "extractor model" is defined twice and inconsistently.** methodology.md:53 says "the slowest/highest-capability model from the dispatch — NOT the model that produced the response." methodology.md:104 says "the slowest, highest-capability model from the original dispatch (caches the response, no extra cost)." These agree on identity but the parenthetical "(caches the response, no extra cost)" is false — dispatching a *new* prompt to a model to reformat another model's text is an extra inference call. There is no caching mechanism described.
- **`structured.jsonl` append convention is ambiguous.** Line 118: "stored in `structured.jsonl` (append mode with `model: "_consolidated"`)." But `output-schema.md:197` documents structured.jsonl as the *per (model, item)* raw extraction (pre-consolidation), and never mentions a `_consolidated` sentinel model. The two files describe the same file with different contents. A consumer parsing structured.jsonl cannot tell which rows are raw vs consolidated.

**What is unclear or ambiguous:**
- **"Final fallback: one-row-per-paragraph (very lossy)" (methodology.md:62)** — when triggered, the row's `primary_key` is what? The pseudocode returns `fallbackParagraphSplit(response, schema)` with no return shape. A consumer consolidating paragraphs has no key to dedup against other models.
- **Phase 4 conflicts.md spec lives in three places** (methodology.md:139-143, output-schema.md §4, consolidation-rules.md:225-234). Which is authoritative? The methodology section says "for every field where models disagreed"; output-schema says it duplicates §4 "for tooling that consumes it." Three specs for one file is drift waiting to happen.

---

### 3. `rules/dispatch-mechanics.md`

**What works well:**
- Mechanism 2 bash sketch is genuinely runnable and was proven (lines 32-54).
- The `task(subagent_type)` model-resolution constraint (lines 28) is documented with issue numbers — concrete and verifiable.

**What is missing or wrong:**
- **Mechanism 3 has a known-broken primary path** (line 79: "OpenCode may override them with the agent's built-in fallback chain") and yet is listed ahead of Mechanism 4. Either remove it or move it below 4, which works. The ordering claims to be "in order of preference" but 3 is proven-broken.
- **Timeout handling in the bash sketch is unspecified.** Lines 41-52 set `TIMEOUT=600` but never apply it. The accompanying note (line 62: "use `timeout $TIMEOUT npx ...`") is not reflected in the example loop, which uses bare `npx -y opencode-ai run` and `&` + `wait` with no timeout. The failure-modes table (line 128) confirms 2-min default shell timeouts kill subprocesses — the example reproduces that exact bug. A user copying this sketch will hit the documented failure.
- **`--y` is described but not in the snippet** (line 58 says `--y` in `npx -y`; the snippet uses `npx -y` correctly, but line 58's text refers to it as `--y` which is not the flag — it's `-y`). Minor but it's a wrong character in a "proven" command note.
- **`--dangerously-skip-permissions` is described as "fine for read-only tasks" (line 59)** without any definition of how the skill knows a task is read-only. The skill itself says it is task-agnostic (SKILL.md:13). A task-agnostic skill cannot make read-only assertions; moving the security responsibility to the user is fine, but the dispatch file shouldn't take a position. This is the same contradiction that recurs SKILL.md → code-review.md.
- **The "Known bug (2026-06)" reference to issue #18615 (line 79)** is dated and effectively unverifiable from the skill — it will rot fast. There is no mechanism to re-verify open issues cited in skill files.

**What is unclear or ambiguous:**
- **"MCP port collision if multiple share a port" (line 101)** — which MCPs share which ports? No port list, no workaround link. The provenance run silently hit this and the skill does not say which MCP was the culprit or how it was fixed.
- **The model-selection strategy table (line 159)** lists "code-specialized" as a category of model without naming any. Generic advice with zero concrete examples for "code-heavy" tasks is the weakest part of the file.

---

### 4. `rules/consolidation-rules.md`

**What works well:**
- The named rule library (lines 163-221) is carefully specified with inputs, algorithms, edge cases, and the `severity_order` direction convention lines 171-172). This is the strongest part of the skill.
- The "Naming consistency" note for `majority-with-uncertain` (line 185) explicitly forbids adjusting rule output to match schema — good guardrail.

**What is missing or wrong:**
- **`prefer-with-evidence-then-newer-then-strict` (lines 155-162) is presented but not in the named-rule library section** (lines 163-221). It's the default for enumerated strings (line 146) and appears in the schema example (SKILL.md:108), but the library section that catalogs rules never restates it formally. A reader scanning the rule library misses the default conflict rule.
- **`most-severe` algorithm is mathematically off-by-one for the lone-flag case.** Line 171 says default `allow_downgrade: false` means "the most-severe value wins even if only 1 reviewer reported it." But the algorithm at line 170 says "Ties broken by `majority` among the max-severity tier." If 1 of 6 reviewers says `blocker` and 5 say `major`, there is no tie in the `blocker` tier (1 vs 0), so `blocker` wins under the algorithm as written — consistent. But the edge-case paragraph then says "allow_downgrade: true to downgrade the lone max to the next-severity tier" — which silently contradicts the earlier "Ties broken by majority among the max-severity tier." If the lone `blocker` is in its own tier, there is no tie to break. The two passages describe different algorithms. Either downgrade-without-majority (edge case) or majority-among-tier (algorithm); pick one.
- **`majority-with-uncertain` threshold formula.** Line 184: `require ≥ max(2, ceil(N/2))` — but fact-check.md:74 says "for N=3 you need 2 votes, not 3" and examples/fact-check.md:109 says "3+ models" was a typo and the correct threshold is parameterized. The consolidation rule's formula gives N=3 → max(2, 2) = 2 ✓. For N=5 → max(2, 3) = 3 ✓. For N=7 → max(2, 4) = 4 ✓. The formula is consistent; the example's hand-calcs are right; consolidation-rules never shows the worked examples. The doc never warns the reader that for N=2 the threshold is max(2,1)=2 (both models must agree) — which makes `majority-with-uncertain` degenerate to "unanimous" for N=2. Worth stating.
- **`merge-exact` (line 217) has no published composite-key syntax.** Lines 217-221 say "if the primary key is malformed (doesn't match the schema's composite pattern)" — but the composite pattern itself is defined in SKILL.md:142 only as "list multiple columns with `dedup_key: true`," which is per-column, not per-composite-pattern. There is no string pattern for `merge-exact` to match. The "malformed" check is undefined.
- **The aggregate scoring matrix (lines 269-278) does not define the `TOTAL` formula precisely.** "TOTAL (median)" is shown in the header but the algorithm is not stated — is it median of dimension scores (each already an aggregated median)? Median-of-medians is mathematically odd for a "total." If dimensions are 0/1/2 (from the rubric in research-prior-art.md:104-118), the meaningful total is a *sum*, not a median — yet the rubric declares `"max_total": 16` (8 dims × 2 max). A "max total = 16" with median aggregation across 8 dims cannot reach 16 (median of 8 binary 0/2 values caps at 2, not 16). The aggregation declared in the rubric (`"aggregate": "median"`) is incompatible with `max_total: 16` (which implies sum). This is a real semantic bug in the skill's own worked example.

**What is unclear or ambiguous:**
- **`unverified` vs `partially-true` (line 185)** — the schema allows `partially-true` as a verdict value, but `majority-with-uncertain` always emits `unverified`. The two terms have distinct meanings in fact-checking; the rule conflates "insufficient consensus" (unverified) with "mixed true/false evidence" (partially-true). A model that produces `partially-true` verdicts can never reach majority if the rule only treats `unverified` as the uncertain output.
- **`newer` `last_verified` rule (line 159)** — "newer `last_verified` wins" is the tie-breaking default, but `last_verified` is a column in the schema (research-prior-art.md:92). What if no model emitted `last_verified`? The rule's behavior when the field is absent is not specified.

---

### 5. `rules/output-schema.md`

**What works well:**
- The `run-manifest.json` definition (lines 208-254) is treated as canonical and references back to other files — a deliberate single-source-of-truth.
- The WYSIWYG formatting rules (lines 258-269) are concrete and operational.

**What is missing or wrong:**
- **`evidence-ledger.md` and `verification.md` are entirely undocumented here** despite SKILL.md:170-171 listing them as thorough-mode outputs. The supporting-files section (lines 193-254) only specifies `structured.jsonl`, `conflicts.md`, and `run-manifest.json`. A thorough-mode consumer has no schema contract for two of its three thorough-only artifacts. This is the largest single gap in the spec.
- **The `structured.jsonl` row (line 199-201) shape does not include `model: "_consolidated"`** — methodology.md:118 contradicts this by saying consolidated records are *appended* to structured.jsonl with that sentinel. The file documented here is "raw extraction before consolidation"; the file described in methodology is "raw + consolidated." The output-schema spec is the most-referenced one, so silent contradiction is a real bug.
- **`§2A Items Table` default columns (line 59) include `Fields per model` formatted as `m1: {cat: direct, score: 3}; m2: {cat: adjacent, score: 5}`** — but `output-schema.md` line 267 forbids unicode; using braces and semicolons inside a markdown table cell is fragile across renderers. No example renders this convention anywhere in-repo.
- **`§2A Conflict marker legend (lines 71-75)** allows *either* bare `*` *or* `` `value*` `` depending on viewer quirks. A skill that aims for WYSIWYG safety should pick one, not offer a two-pronged rule. The text "(Use a code-span like `` `direct*` `` if your viewer is WYSIWYG-strict; bare `*` otherwise)" places the choice on the implementer — but the skill is supposed to remove that ambiguity, not delegate it back.

**What is unclear or ambiguous:**
- **`task_prompt` may be `"..."` for privacy (line 242).** Does the `task_prompt_hash` still hash the literal `"..."`? If so the hash is meaningless for privacy-redacted runs. The contract doesn't say.
- **The `schema` field is shown inline (line 219: `"schema": { "type": "table", "columns": [...] }`)** but SKILL.md:67 says schema can be a `.json` file path. When the value is a path, should it be stored as the file path string or the parsed object? Not stated.

---

### 6. `rules/examples/research-prior-art.md`

**What works well:**
- The alias map (lines 125-140) is concrete and battle-derived — 14 real entries.
- The 9-section prompt skeleton (lines 37-68) is a useful template structure.

**What is missing or wrong:**
- **The example's score-aggregation convention contradicts the schema it ships.** The scoring rubric (lines 104-118) declares `"aggregate": "median"` and `"max_total": 16` for 8 dimensions each 0/1/2. Median of 8 values cannot equal 16; only a *sum* yields max 16. This is the consolidation bug flagged above; the worked example encodes it.
- **The alias map (line 137) maps `MAF` → `Microsoft Agent Framework` but the canonical form (research-prior-art.md:127) lists `MAF` separately from `Microsoft Agent Framework (MAF)` as if both rows point to the same canonical. Line 128 lists `MAF, Microsoft Agent Framework (MAF)` → `Microsoft Agent Framework` (good). Line 137 lists `OPA, Open Policy Agent, OPM` → `OPA` (the alias points to its own short form). The two-row canonicalization style is inconsistent (full form vs short form) and the skill doesn't say which convention is preferred. Aliases are case-by-case in practice but the doc doesn't acknowledge that.
- **"Add more models — 8-10 models captures more unique finds but diminishing returns past 6 (this is an empirical observation, not a measured curve)."** The empirical observation is one data point (the 6-model run). Citing "empirical" without the curve or sample size is rhetorical cover. Either run the benchmark or remove the "empirical" framing.
- **The dispatch snippet (lines 13-32) uses `--dangerously-skip-permissions`** without echoing the SKILL.md / dispatch-mechanics caveat that this is for read-only only. Research-prior-art *is* read-only, but a naive copy-paster applying this snippet to a write-task inherits the unflagged security hole.

**What is unclear or ambiguous:**
- **The prompt template uses placeholder subject "subject X" (line 9)** while the alias map is full of concrete names (Silver Bullet, BMAD, AutoGen). The example oscillates between abstract and concrete fragments without an integrating worked example — the "Worked example" section just links to `docs/research-260624/...` paths, not the actual data. A reader cannot learn the recipe end-to-end from this file alone.

---

### 7. `rules/examples/code-review.md`

**What works well:**
- The composite-key explanation (lines 68-70) actively deprecates the old `"primary_key": "file:line"` string form — useful corrective.
- The "Security note" (line 45) correctly *omits* `--dangerously-skip-permissions` for code review and cites dispatch-mechanics.

**What is missing or wrong:**
- **The schema (lines 49-66) uses `category` field but the custom-strategies table at line 98 lists `evidence` with rule `concatenate-all` while the schema's `evidence` is `type: string, max_words: 50`.** `concatenate-all` will blow past `max_words: 50` nearly always (3-5 reviewers × 50 words each = 150-250 words). The conflict-resolution rule and the type constraint are mutually inconsistent. Either remove the `concatenate-all` rule for `evidence` or drop the `max_words: 50` constraint. The skill validates against both and they collide.
- **`§5 Per-Reviewer Statistics` (line 90) is not present in `output-schema.md`.** output-schema.md's §5 is "Aggregated Scores (optional, both modes)" — there is no per-reviewer section in the canonical schema. The example invents a section the core schema doesn't authorize. This is drift: examples should not define new schema sections.
- **`§6 Coverage Gaps` (line 89) is also not in `output-schema.md`.** Output-schema §6 is "Negative Results." Same drift.
- **No worked example (line 109-111: "deferred to v2.2.0").** For a skill whose only *proven* use is research, the code-review and fact-check recipes are aspirational recipes with no validation. The skill's generalization claim ("task-agnostic") is supported by one proof point out of three documented use cases.

**What is unclear or ambiguous:**
- **`description: "longest-with-quote"` (line 98)** — but the schema declares `description` as `type: "text", max_words: 50`. `longest-with-quote` picks the longest value; if multiple reviewers each provide ≤50 words, the result is still ≤50. But what if one reviewer's description exceeds 50 and is truncated by Row Validation (methodology.md:73)? Does the truncation happen before or after `longest-with-quote` resolves the conflict? Order is unspecified.

---

### 8. `rules/examples/fact-check.md`

**What works well:**
- The threshold math (line 109: "3+ models rule was a typo") is correctly derived for the consolidation rule's formula.
- `unverified` is explicitly called out as a valid output (line 76) — important for the high-stakes use case.

**What is missing or wrong:**
- **`evidence: "all-collected"` (line 97)** — but the schema declares `evidence` as `type: "text", "max_words": 50`. `all-collected` returns all reviewers' quotes concatenated. Same conflict as code-review.md above (multiple-reviewer concatenation vs single-field cap). This is the same bug recurring in two of three example files.
- **No worked example (line 113).** Same as code-review — recipe only.
- **The dispatch uses only 3 models (line 38)** but the schema's `majority-with-uncertain` threshold for N=3 is 2, which means a 2-1 split on a `true` verdict yields "true" — exactly the high-stakes misjudgment the rule was designed to prevent. For N=3 fact-check with majority-with-uncertain, a 2-of-3 verdict is *reachable* under the rule, contradicting the "flag for human review" intent. The example should either use ≥5 models or strengthen the threshold to `ceil(2N/3)`.
- **`counter_evidence: "concatenate-all"` (line 99)** with `max_words: 50` (schema line 64) — same collision.

**What is unclear or ambiguous:**
- **"Primary source" (line 96) is recommended for fact-check but the skill has no notion of source tier.** `prefer-with-evidence-then-newer-then-strict` references "primary quote" (consolidation-rules.md:158) — but no schema field marks a source as primary vs secondary. The advice "prefer official/primary" (line 27 of the prompt) is in the dispatch prompt only; the consolidation step has no primary-source marker.
- **`N>=3` recommendation (line 37)** vs `N>=5` implicit in the prose (line 109 mentions N=5 and N=7). Which floor does the skill recommend? The example uses N=3, the consensus requirements (lines 102-107) discuss arbitrary N without recommending.

---

## §2. Skill Score on the 8-Dimension Rubric

Using the rubric as defined in `consolidation-rules.md` scoring matrix (and research-prior-art.md rubric):

| # | Dimension | Score | Justification |
|---|---|---|---|
| 1 | Catalog of composable units | **1** | "Informal roles" only: Phase 1/2/3/4, "extractor model," parent/worker. No machine-readable catalog anywhere; the "named rules library" is closest but lives in prose markdown, not a schema the orchestrator can resolve against. |
| 2 | Dynamic composition | **0** | No replanner. The 4-phase pipeline is fixed, present in `methodology.md` as a single unchangeable flow. `phases_completed` in `run-manifest.json` is recording, not replanning. `--mode quick/standard/thorough` is mode selection, not dynamic recomposition. |
| 3 | V-loop depth | **1** | "End tests" equivalent: phase completion recorded, conflicts.md documents resolutions. No per-step rollup with intent gate; there is no intent assertion that the consolidation must satisfy before being marked complete. |
| 4 | Enforcement | **0** | Pure honor system. The skill has no IDE hooks, no CI gate, no delivery blockers. `run-manifest.json → phases_completed` is data, not enforcement. The skill explicitly does not retry failures and declines to validate dispatch success. |
| 5 | Parent/worker split | **2** | Explicit orchestrator/worker: SKILL.md:15-22 enumerates parent responsibilities (dispatch, capture, consolidate, synthesize) vs worker models (receive prompt, produce response). Mechanism 1 (`task` tool) and Mechanism 2 (`opencode run --model` subprocess) both formalize the split. |
| 6 | Evidence model | **2** | Tiered sufficiency + staleness: `evidence` field type, `source_refs` in structured.jsonl, `last_verified` date field, `prefer-with-evidence-then-newer-then-strict` rule, `thorough` mode with evidence-ledger (granting the spec gap is real, the *intent* is tiered). The verifier model checks each claim against its source. Matches "tiered sufficiency + staleness" even if the spec contract for the ledger is missing. |
| 7 | SE + DevOps unified | **1** | Partial as interpreted for a skill ("covers both production task types" or "covers neither"). The skill is task-agnostic and so covers neither SE nor DevOps specifically. Examples touch research, code review, fact-check — none is "DevOps." Partial credit because the code-review recipe could in principle review IaC; the skill itself doesn't know. |
| 8 | Team customization | **0** | No overlay packs. Aliases are task-specific (per consolidation-rules.md:326) and the only mechanism for team-specific override. There is no "team process pack" concept; customization requires editing the skill files or forking recipes. |

**Total: 6 / 16.**

The skill's own orchestration rubric scores it as partial — strong on parent/worker and evidence, weak on dynamic composition, enforcement, and team customization. For an orchestration *skill* in 2026, the missing dynamic-composition is the biggest gap: every `(task_type, schema, conflict_rules)` triple is hand-assembled by the user rather than composed from the rule library catalog.

---

## §3. Top 5 Improvements (ranked by impact × effort)

### #1 — Define the missing `evidence-ledger.md` / `verification.md` schema contracts

- **Issue:** `thorough` mode is documented in SKILL.md as a shipped feature but neither artifact is specified in `output-schema.md`.
- **Why it matters:** `thorough` is the *only* mode that delivers cross-source verification; without a schema it can neither be implemented nor consumed by downstream tooling. `silver-bullet` workflows referencing thorough output have no contract.
- **Concrete change (output-schema.md, after line 205):**

  ```markdown
  ### `evidence-ledger.md` (thorough mode only)

  Per-claim source verification ledger. One row per (canonical item, source claim).

  | item | source_url | source_date | capture_excerpt (max_words=50) | verifier_model | verdict | verdict_reason |
  |------|-----------|-------------|--------------------------------|----------------|---------|-----------------|
  | LangGraph | https://github.com/.../langgraph | 2026-05-12 | "agent framework for...stateful multi-actor" | opencode-go/deepseek-v4-pro | true | quote supports the "direct" classification |
  | ... |

  ### `verification.md` (thorough mode only)

  Per-item summary rollup of `evidence-ledger.md`:
  ```json
  {"item": "LangGraph", "sources_checked": 3, "verified": 2, "wrong": 0, "source_verified": "true"}
  ```
  `source_verified` ∈ `true | false | wrong | partial`.
  ```
- **Effort:** Low (addendum to one file, ~30 lines).
- **Impact:** High (closes the largest spec gap; unblocks thorough-mode consumers).
- **Score:** 5 / 1 = **5.0**

### #2 — Fix the median-vs-sum scoring bug in the worked example and rubric aggregation

- **Issue:** `research-prior-art.md` declares `"aggregate": "median"` and `"max_total": 16` for an 8-dimension × 0/1/2 rubric. Median of 8 binary values cannot reach 16.
- **Why it matters:** The only *proven* run uses this rubric; the math is invalid; the consolidated report's `§5 Aggregated Scores` is computed against an incoherent scoring definition. Any reader following the example inherits the bug.
- **Concrete change (research-prior-art.md:115-117):**

  ```json
  "aggregate": "sum",
  "max_total": 16
  ```
  And in `consolidation-rules.md:269-278`, change the `TOTAL (median)` column header to `TOTAL (sum)` and add a sentence: *"TOTAL = sum of dimension scores. Each dimension score is itself an aggregate (per the dimension's `aggregate` field, default `median` across models)."*
- **Effort:** Low (3 string edits).
- **Impact:** High (correctness of the headline example; affects every reader's mental model).
- **Score:** 5 / 1 = **5.0**

### #3 — Reconcile `majority-with-uncertain`'s edge-case algorithm

- **Issue:** `consolidation-rules.md:170` says `most-severe` ties break by "majority among the max-severity tier" while `:171` simultaneously allows lone-flag downgrades via `allow_downgrade: true`. These describe different algorithms under the same rule.
- **Why it matters:** A code-review reviewer's lone `blocker` could either always win (`allow_downgrade: false` per algorithm) or be demoted (`allow_downgrade: true` per edge-case paragraph). The skill's documented safety guarantee ("don't downgrade a blocker") is ambiguous against its own algorithm description.
- **Concrete change (consolidation-rules.md:170-172):**

  Replace the algorithm line with: *"Algorithm: if `allow_downgrade: false`, return the value with the smallest `severity_order.index` (most-severe wins regardless of count). If `allow_downgrade: true`, require ≥ `max(2, ceil(N/2))` models to concur at the max severity; if threshold unmet, demote the max-severity value to the next tier and re-evaluate."*
- **Effort:** Low.
- **Impact:** Medium (closed ambiguity on a safety-sensitive rule).
- **Score:** 4 / 1 = **4.0**

### #4 — Fix the `evidence`/`max_words` vs `concatenate-all` collision in two example recipes

- **Issue:** Both `code-review.md:99` and `fact-check.md:97` recommend `concatenate-all` for `evidence` while the schemas declare `evidence: "text", "max_words": 50`. Concatenating 3-5 reviewers violates the cap.
- **Why it matters:** Two of three documented use cases contain a self-contradictory schema+rule pair. An implementer following either recipe produces invalid output (rows dropped by Row Validation, methodology.md:73).
- **Concrete change:** In `code-review.md` lines 57 and 99, and `fact-check.md` lines 64 and 97, drop the `max_words: 50` constraint on `evidence`, *or* swap the rule from `concatenate-all` to `longest-with-quote`. Recommended: drop the cap and add a note.

  ```json
  {"name": "evidence", "type": "text"}
  ```
  And remove the `concatenate-all` row in code-review.md:99 / fact-check.md:97, replacing with `longest-with-quote` *or* dropping both the constraint and keeping the rule.
- **Effort:** Low (4 line edits across 2 files, plus table updates).
- **Impact:** Medium (closes an obvious bug in the published recipes; prevents silent row-drops).
- **Score:** 4 / 1 = **4.0**

### #5 — Define the structured.jsonl consolidated-row contract

- **Issue:** `methodology.md:118` says consolidated records are appended to `structured.jsonl` with `model: "_consolidated"`. `output-schema.md:199` documents that file as per (model, item) raw extraction with no mention of the sentinel. Contradiction.
- **Why it matters:** Any tooling consuming `structured.jsonl` cannot distinguish raw from consolidated rows reliably. The skill advertises auditability (methodology.md:163-169) but the audit-trail contract has an unrecorded sentinel.
- **Concrete change (output-schema.md:197-200):**

  ```markdown
  ### `structured.jsonl`

  The raw per (model, item) extraction, plus (in `standard`/`thorough` mode) one final
  appended consolidated record per item. Two distinguishable row shapes:

  Raw row:
  ```json
  {"phase": "raw", "model": "m1", "row_id": 1, ...}
  ```
  Consolidated row (appended after all raw rows):
  ```json
  {"phase": "consolidated", "model": "_consolidated", "primary_key": "...", "fields": {...}, "models_in_agreement": ["m1","m3"], ...}
  ```
  Consumers MUST filter on `phase` to avoid double-counting. The `model: "_consolidated"`
  sentinel documented in methodology.md is preserved for backward compatibility.
  ```
- **Effort:** Low.
- **Impact:** Medium (prevents silent double-count in `structured.jsonl` consumers; clears methodology/output-schema contradiction).
- **Score:** 4 / 1 = **4.0**

---

## §4. Open Questions

To make this review more confident, I would need:

1. **Is there any actual runtime implementation of this skill?** The skill is shipped as Markdown "instructions"; the calling agent must execute Phase 1-4 by interpreting the prose. There is no `hooks/multi-ai-task.sh`, no JS in `scripts/`, no `plugins/silver-bullet/commands/multi-ai-task.md` stub that I located. Is the user/agent expected to *manually* run the bash loop in dispatch-mechanics.md and *manually* assemble `consolidated.md`? If so, the "field validation drops invalid rows" guarantee (methodology.md:71-73) has no executor — every column-rule is unenforced. This is the single most important clarifying question.

2. **What is the v2.0.0 → v2.1.0 changelog and where was it published?** The self-review run referenced in SKILL.md:247 is described as v2.1.0, but the only version field is in frontmatter. There is no CHANGELOG. Reviewing v2.1.0 without knowing what *changed* from v2.0.0 means I may be flagging intentional decisions the prior review made and the team already adjudicated. A diff would let me focus on regressions vs persistent issues.

3. **How is `structured.jsonl` actually consumed?** Is there tooling that parses the `model: "_consolidated"` sentinel, or is the sentinel aspirational? Answering this determines whether improvement #5 is spec-drift (low impact if no consumer exists) or a real correctness bug (high impact if tooling reads both rows).

4. **Is `thorough` mode implemented or aspirational?** I see the spec but no run-artifact path in `Proven provenance`. If thorough has never run, improvement #1 is closing a known-aspirational gap, not fixing a silent bug — different severity.

5. **Are the alias maps (research 14-entry) the only per-task customization permitted, or is there an overlay concept?** The skill scores 0 on team customization; if overlay packs are *intentionally* out of scope, the score is correct-and-acceptable. If the team expects packs, the score reflects a real gap.

6. **Across the 85 canonical skills catalog (per AGENTS.md), is `multi-ai-task` the only skill with machine-readable rule library prose?** If yes, the "Catalog of composable units" score of 1 is consistent with peer skills and not a special concern for this one. If peers have catalogs, this skill should too.

---

## §5. Confidence

- **Overall confidence:** **medium**.
- **What would change my assessment:** Confirming whether `multi-ai-task` has any runtime executor (a hook, a script, an agent-side task runner) or whether the calling agent manually interprets the prose. If there is no executor, several "spec" issues become moot (nothing enforces field caps, nothing appends the `_consolidated` sentinel — they are *descriptive* of how the report SHOULD look, not prescriptive of behavior). Confirming the presence of a CHANGELOG and the implementation status of `thorough` mode would also sharpen §3 ranking: if thorough has run successfully, the missing ledger spec is a high-severity silent bug; if thorough is aspirational, it's closing a known TODO.
