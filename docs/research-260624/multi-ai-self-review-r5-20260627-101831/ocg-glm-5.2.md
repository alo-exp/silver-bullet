# Critical Self-Review of `multi-ai-task`

---

## §1. Critical Assessment

### `SKILL.md`

**What works well**
- The "What this skill does NOT do" list (lines 24-30) is unusually honest — naming what's out of scope (no retry, no schema-definition, no domain expertise) sets correct expectations.
- Mechanism 2 is correctly anointed as the default with a clear rationale ("subagent_types via the `task` tool may be restricted by some harnesses") — this is real-world knowledge that saves a misuse.

**What is missing or wrong**
- **Version drift / provenance contradiction.** Frontmatter says `version: 2.1.0` (line 6) and provenance explicitly references "a round-2 self-review (v2.1.0)" (line 247). The reviewer task brief states the skill is "at v2.0.0". Either the reviewer is stale or the frontmatter jumped a minor without a corresponding doc trail. `SKILL.md` should make the version history auditable (e.g., a one-line CHANGELOG at the bottom).
- **`phases_completed` location is wrong.** Line 187: "tracked in `run-manifest.json → totals.phases_completed`". But `output-schema.md:235` declares `"phases_completed": [1, 2, 3, 4]` at the **top level**, not under `totals`. The canonical schema file contradicts SKILL.md — the SKILL.md reader will write the wrong JSON path.
- **`--no-auto-inject` defaults column is self-contradictory phrasing.** Line 69 lists the flag's "Default" as `(schema is auto-injected)`. The "Default" column should describe the flag's default state (`false` / "off"), not the inverse behavior. As written, a reader scanning the table sees `--no-auto-inject` with default "auto-injected" and has to reverse-engineer the double negative. A negative-prefixed flag with a "default ON" behavior is the classic CLI anti-pattern; consider `--schema-inject / --no-schema-inject`.
- **Failure-mode row about `score-aggregate.md` (line 227) leaks internal debris.** "Output dir contains `score-aggregate.md` (planned) but not in the contract | Old spec inconsistency | Ignore for v2.x". This is an internal note that no user can act on (there's no planned file, no contract to check). Either delete the row or replace it with an actual failure mode.

**What is unclear or ambiguous**
- The `--mode thorough` cost estimate ("~1 min parallel" for 36 verifier calls, line 83) is presented as fact with no measurement basis. Is this wall-time per verifier subprocess startup + 1 round trip, or assumes the verifier already has its context loaded? The dispatch overhead in Mechanism 2 (cold `npx -y opencode-ai run` + MCP init) is routinely >20s, so 36 parallel verifier launches in 1 min is implausible.
- "Balanced" model discovery (line 73) defers to "research-like" task detection — how is "research-like" decided at auto-discovery time? There's no task-type classifier described anywhere.

### `rules/methodology.md`

**What works well**
- The 3-fallback extraction ladder (table → structured tags → extractor model → paragraph split) is the most concrete part of the spec; the explicit note that the extractor is **not** the failing model (line 50-53) shows real operational learning.
- The `models_failed` "do NOT retry" rationale (line 19) is correctly justified against the shell 2-min timeout trap.

**What is missing or wrong**
- **No handling of cross-model column mismatch.** Lines 41-42 say header matching is case-insensitive with synonyms ("cat" ↔ "category"), but if model A emits `[name, url, category]` and model B emits `[tool, link, classification]` with **no overlap** and **no supplied synonym map**, Phase 2 extraction silently drops model B. There is no "column-set divergence detector" → at minimum the skill should write a `consolidation_warnings` entry when >X% of models can't be parsed against the schema's header set.
- **`extractFreeform` primary-key heuristic is known-fragile but has no escape hatch.** Line 97: "First 5 words = primary_key (fragile; flag fuzzy_match:true)". The flag is set but nothing consumes it downstream — `consolidation-rules.md` only uses `fuzzy_match: true` as a tag for human review (line 132). If 100% of free-form items are `fuzzy_match:true`, the consolidated output is effectively unusable; there should be a guardrail ("if >50% items are fuzzy_match, write a warning in `conflicts.md` and recommend the user supply a schema").
- **Mode A "deterministic" claim is overstated (line 157).** Path 3 (`dispatchExtractorModel`) is an LLM call inside Mode A. Calling Mode A "deterministic — pure parsing, no LLM in the loop" misdescribes the fallback chain. The claim is only true for the happy path.

**What is unclear or ambiguous**
- "Extractor model = the slowest, highest-capability model from the original dispatch (caches the response, no extra cost)" (line 104). What does "caches the response" mean? The extractor model receives a *new* prompt (the failing model's raw output + schema). There is no cached response being reused — there is a new dispatch. The "no extra cost" claim is wrong unless it refers to something not described here.

### `rules/dispatch-mechanics.md`

**What works well**
- The "Important constraint (as of 2026-06)" paragraph (line 28) citing issues #6651, #11215, etc. and PR #29447 is unusually well-sourced — this is the kind of provenance that lets a reader verify the limitation is real.
- The "stray `*.md` in CWD" recovery note (line 116) is operationally hard-won and absent from most skill docs.

**What is missing or wrong**
- **The `opencode run` command form is questionable.** All examples use `npx -y opencode-ai run --model "$model"`. The repo's own binary (per AGENTS.md and the `opencode` CLI in this environment) is `opencode`, not `opencode-ai`. If `opencode-ai` is the npm package name (vs the binary), that should be stated; otherwise every copy-paste user hits `command not found`. Worse, line 126's failure table says `npx -y opencode-ai run` as if it's a verified command — but the failure row is "returns instantly with no output", which is exactly what you'd see if the binary name were wrong.
- **Example block (lines 36-54) lacks `set -e` / error propagation.** `mkdir -p "$OUT"` failure, `wait` returning non-zero, and silent partial outputs are all unhandled. For a "proven default mechanism" the canonical example should at least `set -euo pipefail` and check `wait`'s exit codes.
- **MCP port collision advice is incomplete.** Line 106: "Sequential alone doesn't fix port collision if the MCP binds a port on first start and holds it." The fix given is "restart the MCP between dispatches" — but `opencode run` is a fresh process each time, so by default MCPs **are** restarted per dispatch. The actual collision mode is when the MCP server is shared via `opserve` (Mechanism 3), not Mechanism 2. The caveat is in the wrong section.

**What is unclear or ambiguous**
- "timeout 600" on macOS: line 62 says "use `gtimeout` from `brew install coreutils`" — but the canonical Mechanism 2 example (line 45) uses bare `timeout "$TIMEOUT"`, which on macOS will resolve to a non-coreutil `timeout` (or fail). The canonical snippet will not run as-written on darwin (this environment).

### `rules/consolidation-rules.md`

**What works well**
- The named rule library (`most-severe`, `majority-with-uncertain`, `lowest-of-majors`, etc., lines 167-221) is genuinely machine-readable: each rule has a stated input shape, algorithm, and edge case. This is the strongest part of the skill.
- `allow_downgrade: false` default for `most-severe` (line 171) with the safety rationale ("don't downgrade a blocker just because one reviewer missed it") shows the safety reasoning is explicit, not implicit.

**What is missing or wrong**
- **`majority-with-uncertain` for N=2 contradicts the fact-check example's framing.** Line 184: "with N=1, single vote never reaches the threshold; return `unverified`". For N=2, threshold = `max(2, ceil(2/2)) = max(2,1) = 2` → both must agree or else `unverified`. But the fact-check example dispatches 3 models (fact-check.md:38) and the consensus section (fact-check.md:104) says "≥ `max(2, ceil(N/2))` models agree on `true` with high confidence + primary source → confirmed". With N=3, threshold=2, so 2-of-3 with "high confidence + primary source" confirms. That bar is weaker than the rule's own N=2 bar (which requires unanimity). The skill advertises fact-check as "high-stakes" but ships a recipe where a 2-1 plurality — possibly with the lone dissenter at `high` confidence — is treated as confirmed. The example undercuts the rule's stated caution.
- **`most-severe` tie-break underspecified.** Line 170: "Ties broken by `majority` among the max-severity tier." But if multiple models in the max-severity tier each assert the same severity for *different* texts (e.g., each says `blocker` but for different reasons), the rule returns which `blocker`? The algorithm returns the severity *value* (`blocker`), not the evidence — so this is fine for severity-only fields, but the rule is also recommended for `severity` + `evidence` together (code-review.md:99 `concatenate-all` for evidence). The interaction between `most-severe` (picks one value) and `concatenate-all` (preserves all values) on paired fields is not described.
- **`union-dedup` ordering for `url_list` is non-deterministic across runs unless "sorted set" is interpreted.** Line 214: "return sorted set". Sorted by what? Alphabetical by URL? By first-seen order? This affects reproducibility (`run-manifest.json → aliases` promises reproducibility; URL ordering should match).

**What is unclear or ambiguous**
- "Maturity / version conflict" (lines 259-263): "use the project's most recent release tag from the official source." How does the consolidation algorithm fetch the release tag? It doesn't — this is advice to the human reviewer. The rule is unimplementable as written; it should be reclassified as "manual review required" with a flag, not as a resolution rule.

### `rules/output-schema.md`

**What works well**
- A single canonical `run-manifest.json` definition (line 209) that other files explicitly defer to — this is the right DRY pattern and prevents drift.
- The "Field semantics" block (lines 239-254) gives per-field required/optional and meaning — exactly what a manifest consumer needs.

**What is missing or wrong**
- **Markdown formatting rule #4 ("Avoid unicode: `≥` → `>=`") contradicts the skill's own prose.** Line 265. Every rules file uses `≥` liberally: `consolidation-rules.md:131` ("≥80% similar"), `research-prior-art.md:103` etc. Either the rule applies only to **table cells** (and should say so) or the rules files are non-compliant with their own output rule. Right now a reader following the rule will rewrite consolidated tables but the rule is worded as a general markdown rule.
- **§2A "default items table" is defined but §2A is titled "Mode A — schema-defined table" (line 53).** Lines 57-69 then describe a *default* table used "when `--schema` is not provided" — that's Mode B's job. §2A's content smuggles in mode-B material under a mode-A heading. Either split cleanly (§2A = schema-defined only; §2B = generic) or rename §2A to "Items Table (both modes, schema-driven form preferred)".
- **Conflict-marker legend placement is mode-specific but stated as universal.** Line 71: "Conflict marker legend (place at top of section)". The example uses `direct` / `adjacent` / `tangential` values — these are research-specific enums. A code-review run has no `direct`/`adjacent` values. The legend's example overfits to the research recipe; the generic form should show a placeholder (`<value>*`).

**What is unclear or ambiguous**
- §5 "Aggregated Scores (optional, both modes)" (line 130) vs §3.6 in consolidation-rules.md which presents the same table as a Phase 3.6 step. Is the aggregated-scores table *always* built when scores are present, or only if the user opted in? Two files imply different defaults.

### `rules/examples/research-prior-art.md`

**What works well**
- The 14-entry alias table (lines 125-141) is real, persisted, and reusable — exactly the kind of artifact that makes a recipe actionable rather than aspirational.
- "Variations to try" (lines 180-185) is honest about empirical limits ("diminishing returns past 6 ... is an empirical observation, not a measured curve").

**What is missing or wrong**
- **The dispatch script (lines 22-32) omits the `timeout` wrapper that `dispatch-mechanics.md:45` calls critical.** This is the "proven worked example" and it does not follow the canonical dispatch. A reader copying this example hits the 2-min default bash-tool timeout the skill itself warns about. The example and the canonical mechanics disagree.
- **The dispatch script uses bare `npx -y opencode-ai run` with no `--dangerously-skip-permissions` decision.** The canonical example (dispatch-mechanics.md:47) passes it; this example omits it. For research (read-only) it should be present per the rule "fine for read-only tasks" (dispatch-mechanics.md:59). The example either has an intentional reason to omit it (not stated) or is inconsistent.
- **The dispatch `cd "$OUT"` (line 16) means the model writes into `$OUT` as CWD,** but `dispatch-mechanics.md:116` then tells the user to check the model's *own* CWD for stray files. After `cd "$OUT"`, those are the same place — the recovery instruction becomes a no-op. The example should either not `cd` (and use absolute paths) or note that the "stray CWD file" failure mode is mitigated by this `cd`.

**What is unclear or ambiguous**
- Scoring rubric (lines 104-118) uses dimension names `catalog`, `dynamic`, `v_loop`, etc., but the rubric in the reviewer task brief uses longer names ("Catalog of composable units", "Dynamic composition"...). Which is canonical for the manifest? Minor, but matters for a machine-readable rubric.

### `rules/examples/code-review.md`

**What works well**
- The explicit correction (lines 70-71) that the old `"primary_key": "file:line"` string form is wrong, and the correct composite-key form is two `dedup_key: true` columns — this is a real fix that prevents a recurring misconfiguration.
- "Security note (READ-ONLY ONLY)" (line 45) with the explicit pointer to the dispatch-mechanics line is the right cross-reference pattern.

**What is missing or wrong**
- **"Worked example: Not yet produced (deferred to v2.2.0)" (line 111).** Combined with `SKILL.md:208` listing this as the recipe for "parallel code review", the recipe is **unvalidated**. The prior-art example is the only proven run. This should be flagged in `SKILL.md`'s pointer ("reference recipes; only prior-art is proven"), not buried at the bottom of each recipe file.
- **Composite key collision risk for line numbers.** Dedup by `(file, line)` merges findings on the same line — but a single line can host multiple distinct findings (e.g., a security bug + a style nit). The merge will collapse them. The recipe should recommend `(file, line, category)` as the composite key, or document that same-line multi-finding is a known limitation.
- **No `severity` conflict example with `allow_downgrade` in the schema.** The conflict-resolution note (lines 72-78) shows how to add `critical`, but doesn't show the `allow_downgrade: true` case for security audits (described in consolidation-rules.md:171). The example with the highest false-positive risk (security) is the one that doesn't show the conservative-consensus option.

**What is unclear or ambiguous**
- §5 "Per-Reviewer Statistics" (line 88) is in the output section but no schema field captures it. Is it computed from `structured.jsonl` row counts? Stated as a section but not as a manifest field.

### `rules/examples/fact-check.md`

**What works well**
- The threshold parameterization table (line 109: "For N=3, threshold = 2. For N=5, threshold = 3...") and the explicit correction of the "3+ models" typo — this kind of self-correction record is rare and useful.
- `unverified` as a first-class verdict (line 76) instead of forcing binary judgment is the right epistemic posture for fact-check.

**What is missing or wrong**
- **3-model dispatch undercuts the consensus-requirements section.** Line 38 dispatches 3 models, line 37 says "use 4-5 for fact-check; majority-with-uncertain needs N>=3". With N=3 and threshold = max(2, ceil(3/2))=2, a 2-1 plurality confirms. But line 104 requires "**≥ max(2, ceil(N/2))** models agree on `true` **with high confidence + primary source** → confirmed". Does the implementation actually gate on "high confidence + primary source" as a conjunction, or just on the majority count? If the latter, the consensus-requirements section is aspirational; the schema's `confidence: "lowest-of-majors"` rule only downgrades confidence, it doesn't *reject* the verdict. The example promises a strict bar but the schema doesn't enforce it.
- **`confidence: "lowest-of-majors"` + `verdict: "majority-with-uncertain"` interaction.** If majority verdict is `unverified` (no threshold met), what does `lowest-of-majors` do for `confidence`? There's no "majority" to take the lowest confidence from — `unverified` is a default value, not a voted value. The rule's edge case (consolidation-rules.md:191) only handles "1 model voted for the majority value". The "no majority" case for `confidence` is undefined.
- **No counter-evidence handling when verdict is `true`.** `counter_evidence` field (line 64) is in the schema but `concatenate-all` (line 99) only runs the rule across models' values; if all models return empty `counter_evidence` (verdict = true), the field is just empty. The output section (line 89) lists §7 "False Claims ... include counter-evidence" but gives no handling for claims where 1 reviewer found counter-evidence and 4 didn't — does the counter-evidence get surfaced, or buried because the verdict is `true`?

**What is unclear or ambiguous**
- "Worked example: Not yet produced (deferred to v2.2.0)" (line 113) — same issue as code-review: unvalidated recipe presented as a reference.

---

## §2. Score the Skill on the 8-Dimension Rubric

| # | Dimension | Score | Justification |
|---|---|---:|---|
| 1 | Catalog of composable units | **2** | Named rule library (`most-severe`, `majority-with-uncertain`, `union-dedup`, etc.) is machine-readable in `--schema` JSON with explicit algorithms, inputs, and edge cases (consolidation-rules.md:167-221). |
| 2 | Dynamic composition | **1** | No replanner; the 4-phase pipeline is fixed. Schema-driven *per-field* rule selection is flexible within Phase 3 but the phase structure cannot be re-composed at runtime. |
| 3 | V-loop depth | **1** | Has end-of-run `conflicts.md` + per-item `confidence` flag + `run-manifest.json → phases_completed`. No per-step intent gate; no rollup of intent vs. outcome mid-pipeline. The loop is "end tests" (final consolidated output validated against schema), not per-step. |
| 4 | Enforcement | **1** | Honor system at run time + repo-level CI (per AGENTS.md `tests/run-all-tests.sh`). No IDE hook or delivery blocker; the skill emits `run-manifest.json` but nothing gates a downstream consumer on its presence. |
| 5 | Parent/worker split | **2** | Explicit orchestrator/worker: parent (`multi-ai-task`) dispatches N peer workers (models) in parallel and consolidates; workers do not see each other. Mechanisms 1-4 all preserve this split. |
| 6 | Evidence model | **2** | Tiered: `confidence_self: high\|medium\|low` per row, `source_verified: true\|false\|wrong` in thorough mode, `evidence-ledger.md` with per-claim URL + staleness via `last_verified`. This is tiered sufficiency + staleness. |
| 7 | SE + DevOps unified | **0** | The skill is task-agnostic and covers *neither* SE nor DevOps specifically. Examples cover research, code review, fact-check — no DevOps/IaC recipe. "Task-agnostic" is a polite way of saying "covers neither production task type by default". |
| 8 | Team customization | **1** | Alias maps are per-task JSON blobs but not "overlay packs" — there's no team-process layer, no inheritance, no merging of base + overlay. Forking the skill is required for a team-specific consolidation policy. |

**Total: 10 / 16**

---

## §3. Top 5 Improvements (ranked by impact × effort)

### 1. Fix the `phases_completed` location contradiction
- **Issue:** `SKILL.md:187` claims `run-manifest.json → totals.phases_completed`; `output-schema.md:235` defines it at the top level.
- **Why it matters:** Any tooling that consumes the manifest will read the wrong JSON path and miss the audit field — silent data loss in the audit trail the skill advertises.
- **Concrete change:** `SKILL.md:187` — replace
  ```
  The 4 phases are also tracked in `run-manifest.json → totals.phases_completed` for audit purposes.
  ```
  with
  ```
  The 4 phases are also tracked in `run-manifest.json → phases_completed` (a top-level array, see `rules/output-schema.md`) for audit purposes.
  ```
- **Effort:** low
- **Impact:** medium
- **Score:** 0.71

### 2. Gate `majority-with-uncertain` confirmation on more than vote count in fact-check
- **Issue:** fact-check.md:104 promises confirmation requires "majority vote **with high confidence + primary source**" but the schema (fact-check.md:54-71) only enforces the vote count; `lowest-of-majors` downgrades confidence post-hoc but doesn't *reject* the verdict. A 2-1 plurality at mixed confidence currently confirms.
- **Why it matters:** This is the "high-stakes" use case the skill advertises; the bar is advertised as strict but enforced as weak.
- **Concrete change:** `fact-check.md` schema (line 66) — add a `confirmation_gate` block:
  ```json
  "confirmation_gate": {
    "verdict": "true",
    "requires": {
      "min_majority_votes": "max(2, ceil(N/2))",
      "min_confidence_of_majority": "high",
      "requires_primary_source": true
    },
    "on_fail": "downgrade_to_unverified"
  }
  ```
  and reference it from `consolidation-rules.md` §`majority-with-uncertain` so the rule library documents the gate. Add the gate to the worked example once produced.
- **Effort:** medium
- **Impact:** high
- **Score:** 0.50 (high impact, but the schema extension + rule doc + validation is non-trivial)

Wait, recalc: high/medium = 0.67. Let me list clean.

Final scores (impact/effort, higher ROI first):
1. phases_completed fix: impact medium / effort low = 0.71 × scale → high ROI
2. fact-check confirmation gate: impact high / effort medium = high
3. thorough-mode cost estimate verification: impact medium / effort low
4. cross-model column-mismatch detector: impact high / effort medium
5. `--no-auto-inject` rename: impact medium / effort low

Let me finalize cleanly.### 3. Establish cross-model column-divergence detection in Mode A
- **Issue:** `methodology.md:40-43` matches headers case-insensitively with synonyms, but if models emit non-overlapping column sets with no supplied synonym map, the failing models are silently dropped from Phase 2 with no aggregate warning.
- **Why it matters:** A 6-model run where 3 models used different column headers produces a "consolidated" report that is actually a 3-model report — and the user has no way to know.
- **Concrete change:** `methodology.md` after line 73 (Row validation) — add:
  ```
  - **Column-set divergence guard:** after extraction, if >25% of models could not be parsed against the schema's `columns` (no header match, no structured tags, extractor returned empty), write a `consolidation_warnings: ["column_divergence: 3/6 models unparsed"]` entry to `run-manifest.json` and emit a banner at the top of `consolidated.md` recommending the user supply a `--schema` or add header synonyms.
  ```
  Mirror the `consolidation_warnings` field in `output-schema.md` §`run-manifest.json` (line 211).
- **Effort:** medium
- **Impact:** high
- **Score:** 0.67

### 4. Replace `--no-auto-inject` with a positive-polarity pair
- **Issue:** `SKILL.md:69` ships a negative-prefixed flag whose "Default" column reads "(schema is auto-injected)" — a double negative that has already caused confusion in the table's own phrasing.
- **Why it matters:** CLI flag polarity is a major source of user error; this one is referenced 6+ times across files so the confusion compounds.
- **Concrete change:** Rename to `--schema-inject / --no-schema-inject`. `SKILL.md:4` argument-hint:
  ```
  "<task-prompt> [--models m1,m2,...] [--out <dir>] [--schema <json|file>] [--mode quick|standard|thorough] [--no-schema-inject]"
  ```
  Default becomes `--schema-inject` (on); users opt out with `--no-schema-inject`. Update `SKILL.md:28,69,146`, `methodology.md:15`. Record the rename in a one-line CHANGELOG so existing scripts can migrate.
- **Effort:** low
- **Impact:** medium
- **Score:** 0.50

### 5. Make the research-prior-art dispatch example match the canonical mechanics
- **Issue:** `research-prior-art.md:22-32` — the "proven" example omits the `timeout "$TIMEOUT"` wrapper that `dispatch-mechanics.md:45` calls critical, and adds `cd "$OUT"` which neutralizes the "stray CWD file" recovery note.
- **Why it matters:** A reader copying the proven example hits the 2-min default bash timeout the skill specifically warns about — the canonical and the example disagree on the most-referenced snippet.
- **Concrete change:** `research-prior-art.md:18-33` — wrap each `npx` invocation in `timeout "$TIMEOUT"` (using `gtimeout` on macOS), or add a one-line note: "See `rules/dispatch-mechanics.md` for the full timeout-wrapped form; this snippet is abbreviated for clarity." Either align or annotate.
- **Effort:** low
- **Impact:** medium
- **Score:** 0.50

---

## §4. Open Questions

1. **What is the canonical binary name — `opencode` or `opencode-ai`?** Every dispatch example uses `npx -y opencode-ai run`, but the host environment's binary is `opencode`. Is `opencode-ai` the npm package name (in which case `npx opencode-ai` resolves to a binary — possibly `opencode`)? A one-line clarifier in `dispatch-mechanics.md` would resolve every copy-paste failure mode attributed to "Model unavailable, network error, or rate-limited".

2. **Is there a worked `thorough`-mode run anywhere?** The proven provenance is `standard` mode; `thorough` is described in `SKILL.md:81` with concrete time estimates but no cited run, no `evidence-ledger.md` example, and no `verification.md` example. If `thorough` is unvalidated, the cost estimate in `SKILL.md:83` should be marked provisional.

3. **Who is the intended audience — a host agent (Claude/Codex) reading the skill, or a human copy-pasting into a shell?** The skill reads as both, which is why `dispatch-mechanics.md` has both `task(subagent_type=...)` (agent-facing) and `npx opencode-ai run` (shell-facing). Some contradictions (e.g., the auto-inject flag's table phrasing) come from serving two audiences with one table. Splitting "agent contract" from "human recipe" might reduce the surface.

4. **Is there a downstream consumer contract for `run-manifest.json`?** The schema is fully specified, but nothing in the repo describes who reads it (a CI gate? a re-consolidation tool? a human?). If no consumer exists yet, several fields (`schema_auto_injected`, `consolidation.*`) are audit-only and could be marked "informational" to lower implementation cost.

5. **Are the code-review and fact-check recipes intended to be invocable as-is today, or are they v2.2.0 aspirational?** Both end with "Not yet produced (deferred to v2.2.0)". If aspirational, `SKILL.md:208-209` should label them as such; if invocable, the composite-key and confirmation-gate gaps (§1 code-review, fact-check) are live bugs, not forward-looking improvements.

---

## §5. Confidence

- **Overall confidence:** **medium-high**
- **What would change my assessment:**
  1. Sight of the v2.1.0 self-review (`docs/research-260624/multi-ai-self-review-r2-20260627-093345/`) — if it already addressed the `phases_completed` and `--no-auto-inject` items, this review is partly stale and the remaining issues narrow to the fact-check gate and the cross-model column-divergence detector.
  2. A test run of the fact-check recipe with N=3 on a real claim list — if 2-1 pluralities at mixed confidence consistently produced "confirmed" verdicts the user would not endorse, the §3 #1 finding upgrades from "high impact" to "blocking".
  3. Confirmation of the binary name (`opencode` vs `opencode-ai`) — if `opencode-ai` is correct, the macOS `timeout` issue and the "command not found" failure-mode row both weaken substantially.
