I'll deliver the review below. All 8 files were read in full; specific line references cite the skill's own text.

---

# §1. Critical Assessment (per-file)

## 1. `SKILL.md`

**Works well**
- The "What this skill does NOT do" list (lines 24-29) is unusually honest — most skills skip negative scoping. The retry-policy non-decision is stated explicitly, which prevents mismatched user expectations.
- The supporting-files/architecture in the output structure block (lines 162-173) is concrete and usable.

**Missing / wrong**
- **Version drift.** Frontmatter declares `version: 2.1.0` (line 6), but the task framing and provenance prose repeatedly call this v2/v2.0.0 (e.g., "`score-aggregate.md` ... Ignore for v2.x" at line 228). The self-review is being asked against "v2.0.0" — there is no single source of truth for version.
- **Double-negative `--no-auto-inject` wording.** Line 28: *"Inject the schema into the prompt unless `--no-auto-inject` is set (default ON — see …)"*. "Default ON" here refers to auto-injection, not to the flag, but parsing it requires the reader to invert twice. This is a real usability hazard in a skill docs file.
- **`--concurrency` is in the inputs table (line 69) but missing from the usage line** (line 57) and missing from `argument-hint` (line 4). Three places where flag surface should agree; only one has it.
- **Failure-mode row drops the `-y` flag.** Line 220 says "`npx opencode-ai run` returns instantly with no output" but the dispatch recipes everywhere use `npx -y opencode-ai run`. The `-y` is load-bearing (`-y` skips npx install prompt; the docs themselves warn at `dispatch-mechanics.md:55` that without it subprocesses can hang). The failure-mode row silently misdescribes the command it purports to debug.
- **Known-bug admission in a shipped spec.** Line 228: *"Output dir contains `score-aggregate.md` (planned) but not in the contract | Old spec inconsistency | Ignore for v2.x"*. A skill should not ship a documented "ignore" contradiction — either remove the spec reference or remove the failure row. Carrying both is documentation rot.

**Unclear**
- Mechanism-preference contradiction: SKILL.md line 192 says *"Default is Mechanism 2"* while `dispatch-mechanics.md:7` lists the mechanisms *"in order of preference"* starting with Mechanism 1. Is the default "preferred" or "fallback"? The two files disagree on what "default" means.
- The auto-discovery default (line 74) says *"picks a balanced default set of 4-6 models across the available providers"*. What does the skill do if `opencode.json` advertises fewer than 2 provider families? Fail? Use 1? Pick "best effort"? The behavior is unspecified.

## 2. `rules/methodology.md`

**Works well**
- Phase 4 final-synthesis section (lines 122-145) gives a concrete `run-manifest.json` example with real fields.
- The "Deterministic + LLM-assisted hybrid" cross-cutting principle (lines 178-183) clearly states which steps are LLM-free vs LLM-involved.

**Missing / wrong**
- **"No extra cost" claim is false.** Line 104: *"the slowest, highest-capability model from the original dispatch (caches the response, no extra cost)"*. Invoking the extractor model with a *different prompt* (the reformat request, line 52-58) is a new completion — there is no API-level prompt-cache hit across prompts that differ by structure. This is a factual error that would mislead an implementer budgeting tokens.
- **Auto-inject instruction suppresses model judgment.** Line 15 instructs the model to *"Return your answer as a markdown table with exactly these columns, and nothing that does not match this schema."* For tasks where the schema is incomplete (e.g., research where models find unclassifiable adjacency), this silently drops findings outside the schema. The phrase "and nothing that does not match" is a quality killer and should be removed or softened.
- **Phase numbering diverges from the sibling file.** This file declares exactly 4 phases (lines 7-145). `consolidation-rules.md` uses `Phase 2 — ALIGN`, `Phase 3 — DEDUP`, `Phase 3.5 — RESOLVE CONFLICTS`, `Phase 3.6 — SCORE + SYNTHESIZE`. So `consolidation-rules.md`'s "Phase 3.5" and "Phase 3.6" map to which phase in methodology.md? They appear to live inside "Phase 4 — Final synthesis" — but methodology.md Phase 4 (lines 122-145) never mentions conflict resolution or aggregation algorithms at all. There's no internally consistent phase model.
- **Misleading header.** §"Idempotent re-runs" at line 195 then proceeds to say *"It does NOT cache across runs by default (each run is fresh)"*. That is the *opposite* of idempotent re-runs in the workflow sense; the header promises a property the skill explicitly disclaims. Rename to "Re-run semantics" or remove.

**Unclear**
- Line 19 *"The skill does NOT retry. Retry logic lives in the calling agent's runner…"*. But the calling agent is the one *invoking this skill*. So who is on the hook — the user, or the user's agent? The handoff boundary is unclear.

## 3. `rules/dispatch-mechanics.md`

**Works well**
- The "Choosing the right mechanism" routing table (lines 169-177) is a genuinely useful decision matrix.
- Concrete slug-sanitization note (line 54: *"`cut -d/ -f2` pattern is critical — without it, `out/$model.md` creates subdirectories or fails"*) is exactly the kind of operational detail skills usually omit.

**Missing / wrong**
- **Brittle reference to upstream issue numbers.** Lines 28 and 75 cite specific GitHub issue IDs (`#6651, #11215, #17595, #26925, #29984, #32730`, `#18615`). Skills outlive individual tracker issues; closed/renamed issues silently invalidate the doc. Either link only the PRs (`#29447`) or describe the constraint in prose.
- **Examples routinely violate the safety note.** Line 56: *"For write tasks (writing a file to the user's repo, modifying configs), do NOT use this flag."* Yet `code-review.md:28` and `fact-check.md:34` both pass `--dangerously-skip-permissions` unconditionally in the dispatch recipes. A code review may, by intent, *apply* fixes to the working tree — the recipe defaults to the unsafe flag.
- **No instruction for the actual MCP-restart workaround.** Line 102 admits *"Sequential alone doesn't fix port collision… restart the MCP between dispatches"* but provides no command. For a recipe-driven skill this is an operational hole — the reader is told a workaround exists and given no implementation.
- **Stale date in copyright.** Lines 28, 75 use *"as of 2026-06"* and *"Known bug (2026-06)"*. Both dates are today's month. Combined with hard-coded issue numbers and the multiple open-PR references, this reads as "snapshot of upstream state at write-time" — the most brittle kind of doc, because no refresh trigger exists.

**Unclear**
- The `task` tool constraint note (line 28) implies the OpenCode task tool's `Parameters` schema is `packages/opencode/src/tool/task.ts`. Is this the canonical path the skill promises to update if upstream restructures? If so, it should be marked "verify against current path before relying on this".

## 4. `rules/consolidation-rules.md`

**Works well**
- The named rule library (lines 168-224) is the skill's most defensible artifact: each rule has Purpose / Input / Algorithm / Edge case — that's real implementation spec, not hand-waving.
- Aliases table (lines 84-95) shows the canonicalization pattern explicitly and notes that new aliases are discovered iteratively.

**Missing / wrong**
- **`most-severe` algorithm inverted.** Line 175: *"`max(values, key=severity_order.index)`"*. With `severity_order = ["blocker", "major", "minor", "nit"]`, `index("blocker")=0` and `index("nit")=3`, so `max(... key=index)` picks **`nit`** — the *least* severe — exactly the opposite of the rule's purpose. This is a bug in pseudocode, not a stylistic complaint. For an artifact named the "core value of the skill" (per `SKILL.md:196`), an inverted algorithm is a ship-stopper.
- **`majority-with-uncertain` definition contradicts the fact-check recipe.** Line 187: *"require ≥ `max(2, ceil(N/2))` models to agree"*. For N=3, threshold = max(2,2) = 2, so 2-of-3 should pass. But `fact-check.md:63` says *"if 2 say true and 1 says false, default to `partially-true` (uncertain) rather than true; require ≥3 votes for a clean verdict"*. The recipe hardcodes "3" and overrides the parameterized rule. The two halves of the skill disagree on the algorithm they should be sharing.
- **`lowest-of-majors` edge case is unreachable.** Line 194: *"if only 1 model voted for the majority value, return its confidence unchanged"*. Majority-with-uncertain requires ≥ max(2, ceil(N/2)) voters to even reach a majority, so "only 1 model voted for the majority" can never occur. Either the rule definition has a hole (majority can be reached some other way not stated) or the edge case is dead code.
- **Rule 4 of `prefer-with-evidence-then-newer-then-strict` restates rules 1 and 2.** Line 166: *"Tie-break: prefer the value with the strongest evidence quote, then prefer the most recent."* Rules 1-2 (lines 163-164) are already "quoted primary source wins" and "newer last_verified wins". So the tie-break revisits the same ordering; readers cannot tell what rule 4 adds.
- **Fuzzy match threshold is unquantified.** Line 136: *"Match if normalized titles are ≥80% similar (Levenshtein or token-overlap)"*. "Levenshtein 80%" is not a standard measure; it could be `1 - dist/max_len`, or it could be token-set Jaccard. Different choices give different merge decisions — this is a consolidation-correctness ambiguity, not a docs nit.

**Unclear**
- Default conflict-resolution table (lines 149-158) gives per-type defaults, then `prefer-with-evidence-then-newer-then-strict` is listed at line 161 as the rule for *"enumerated strings like category"*. But the table at line 150 already lists `"string (enumerated)" → prefer-with-evidence-then-newer-then-strict`. Two places state the same default — is one of them the canonical spec, or do both need to stay in sync when one changes?

## 5. `rules/output-schema.md`

**Works well**
- Concrete WYSIWYG formatting rules (lines 232-242) — most skill docs hand-wave this; here it's enumerated. Practically useful.
- Appendix A "Cross-AI Source Map" (lines 167-177) is a genuinely good provenance design.

**Missing / wrong**
- **`run-manifest.json` example is incomplete relative to the spec.** Lines 209-227 omit `schema_auto_injected` — which `SKILL.md:147` and `methodology.md:15` both say MUST be recorded in `run-manifest.json → schema_auto_injected`. The example also omits the `aliases` field that `consolidation-rules.md:336` requires. Two contract fields silently dropped from the example.
- **Duplicate §2 numbering.** Line 53 `§2. Items Table (Mode A …)` and line 79 `§2. Items Table (Mode B — generic narrative)`. A consumer parsing sections by number cannot tell them apart; this should be §2/§3 or §2A/§2B.
- **§5 mandatory-or-optional status is inconsistent across files.** Line 130: *"§5. Aggregated Scores (optional, both modes)"*. But `research-prior-art.md:161` lists §5 as a regular section ("§5 Aggregated Scores (median + range across models)") — not marked optional. Is it part of the default contract or not?
- **Unicode rule violated in the same file.** Line 235: *"Avoid unicode in cells when possible. `—` → `--`"*. Yet the file's own tables use `—` (table rows at lines 124, 137, 156, 188 contain `—` / similar). The rule declares a style this file doesn't follow; downstream models will replicate whichever the skill itself does.

**Unclear**
- §7 (line 158) is one sentence: *"What remains unclear after the task. Carry-forward items."* No extraction rule, no source. Are open questions taken from each model's report verbatim, deduplicated, or synthesized? The skill is silent in its own output contract.

## 6. `rules/examples/research-prior-art.md`

**Works well**
- Alias map (lines 125-141) front-and-center with the explicit note that it's task-specific, not core. Correct factoring.
- Intellectual honesty on diminishing returns at line 182: *"this is an empirical observation, not a measured curve — run your own benchmark if you want a hard number"*. Rare in skill docs.

**Missing / wrong**
- **Dispatch example omits `--schema`.** Lines 14-32 dispatch with `$PROMPT` only — no `--schema` flag. But line 173 says *"Schema + scoring rubric: passed via `--schema` as a JSON file"*. The dispatch command is missing the very flag the worked example claims was used. Reproducibility is broken by example.
- **Date-folder mismatch.** Line 246 of SKILL.md references "`docs/research-260624/SB_CONSOLIDATED_PRIOR_ART_REPORT.md`"; this file at line 174 says inputs were at the same `docs/research-260624/` path. The run is dated *"on 2026-06-27"* (SKILL.md:240); the folder name encodes `260624` = 2026-06-24. Either the folder name is stale or the run date is misquoted — either way, the provenance Pointer does not match.
- **Scoring rubric lives in this example file**, but the rubric is also referenced as the *skill's own self-assessment rubric* (the rubric still appears in the self-review task prompt). If the rubric is "research-recipe-specific" it shouldn't be borrowed as a universal 8-dimension self-assessment; if it's meant to be reused, it should be promoted out of the example file. Current position is ambiguous.

**Unclear**
- Line 22: hardcoded model list. Is this list the *recommended default* for research or just *"the set used on 2026-06-27"*? The wording doesn't say.

## 7. `rules/examples/code-review.md`

**Works well**
- Per-field `Recommended rule | Rationale` table (lines 76-82) maps each column to a named algorithm — tight, actionable.

**Missing / wrong**
- **Dispatch loop uses unsanitized model name in filename.** Line 30: `> "code-review-${model}.md"`. Since `$model`=`opencode-go/minimax-m3`, this writes to `code-review-opencode-go/minimax-m3.md` — which creates a subdirectory (`opencode-go/`) or fails. The dispatch-mechanics.md slug pattern at line 44 (`slug=$(echo "$model" | cut -d/ -f2)`) was specifically called out as "critical" (line 54). This recipe silently fails the skill's own hygiene.
- **No `$OUT` directory, no `mkdir`.** Compared with `research-prior-art.md:14-15` (`OUT=./multi-ai-out/...` and `mkdir -p "$OUT"`), this recipe writes files to the CWD and deviates from the skill's own output-dir contract (`SKILL.md:66`).
- **`--dangerously-skip-permissions` used unconditionally for a write-capable task.** Line 28. Code review is exactly the case `dispatch-mechanics.md:56` warns against ("For write tasks … do NOT use this flag"). This example is a code-review recipe, not a pure read-only inspection (code-review models frequently attempt fixes); the example defaults to insecure.
- **`"primary_key": "file:line"` is the wrong schema syntax.** Line 40. SKILL.md:143 says composite primary keys are expressed by *listing multiple columns with `dedup_key: true`* — *"Example: `file` + `line` for code review."* The recipe's JSON instead writes the string `"file:line"` in `primary_key` and only sets `dedup_key` on no column. The column `"file"` and `"line"` (lines 42-43) are marked `required: true` but neither is `dedup_key: true`. So how does the skill actually dedupe? Per the skill's own spec, this schema does not declare a dedup key — there is no `dedup_key: true` column, and `primary_key: "file:line"` is not the documented format. The recipe is broken against the spec.
- **§5 in this recipe is "Per-Reviewer Statistics"** (line 70), but the canonical `output-schema.md` §5 is "Aggregated Scores" (line 130). Different contracts for the same skill.

**Unclear**
- Line 93: *"Not yet produced. The pattern is identical to the prior-art research example"* — but the prior-art example has 8 numbered output sections (limited to a research framing) and this recipe has 7 with a code-review framing. The claim "identical pattern" is unsupported.

## 8. `rules/examples/fact-check.md`

**Works well**
- The custom-strategies table (lines 81-87) clearly maps each field to a named rule from the library.
- Consensus-requirements block (lines 89-95) gives a stampable definition of "confirmed / debunked / uncertain".

**Missing / wrong**
- **Same dispatch bugs as code-review.md.** Lines 33-35: `"factcheck-${model}.md"` creates the subdirectory/breaks; no `$OUT`; `--dangerously-skip-permissions` defaulted.
- **Schema omits the resolution rules the prose recommends.** Line 55-59 `conflict_resolution` block declares only `verdict` and `confidence`. But the recipe's own "Custom strategies" table recommends `evidence: all-collected`, `sources: union-dedup`, `counter_evidence: concatenate-all`. Because the schema trumps prose (the schema is what's actually passed to `--schema`), the configured behavior will be the *defaults* (`evidence: longest-with-quote`, `sources: union-dedup` for `url_list`, `counter_evidence: longest-with-quote`), not what the prose prescribes. The example is internally inconsistent, and the prose walks the reader into believing they're getting `all-collected` when they're not.
- **Same `majority-with-uncertain` contradiction flagged earlier.** Line 63: *"if 2 say true and 1 says false, default to `partially-true` (uncertain) rather than true; require ≥3 votes for a clean verdict"*. The rule definition (`consolidation-rules.md:187`) gives threshold = `max(2, ceil(N/2))` = 2 for N=3, so 2 votes pass. The example overrides the rule. Either the rule definition is wrong (and should always require ≥3) or the example is wrong (and 2-of-3 should produce a verdict).
- **Hardcoded "3+ models" threshold doesn't scale.** Lines 91-93: *"3+ models agree on `true`…"*. With N=2, no claim can ever be confirmed; with N=10, "3" is a 30% supermajority — far too weak. The recipe assumes a fixed model count, which contradicts the claim that the skill scales N freely.

---

# §2. 8-Dimension Rubric Score

| Dimension | Score | Justification |
|---|---|---|
| Catalog of composable units | **1** | Named rules (`most-severe`, `union-dedup`, etc.) act as informal roles, but they are string IDs in markdown, not a machine-readable catalog with validation. |
| Dynamic composition | **0** | Phases are static (4 phases, hardcoded order). No replanner, no runtime selection of consolidation strategies based on response shape. |
| V-loop depth | **0** | No end tests defined for consolidated output correctness; `run-manifest.json → totals` is a counter, not a verification loop. The skill explicitly does not retry. |
| Enforcement | **0** | Pure honor system. None of the consolidation rules are enforced programmatically; a model that ignores `--schema` produces no error. |
| Parent/worker split | **2** | Explicit: parent orchestrator dispatches to N worker subagents (`opencode run --model`), each given the same prompt verbatim. Cleanly stated. |
| Evidence model | **1** | `thorough` mode has `evidence-ledger.md` + `source_verified` flag, but default mode has no tiered sufficiency; `last_verified` is a date, not a confidence tier. Staleness only meaningful in thorough mode. |
| SE + DevOps unified (N/A → covers both production task types) | **1** | Research (canonical) + code-review + fact-check covered; DevOps / IaC review notStub. Partial—one production surface (SE) addressed, the other (DevOps) absent. |
| Team customization (N/A → supports process packs) | **1** | `--schema` JSON is the only customization surface; no overlay/process-pack system. Customizing defaults requires a user to manually retype the schema, i.e. fork-the-defaults. |
| **Total** | **6 / 16** | Below the midpoint; the skill's strengths are concentrated in process clarity, weaker in enforcement and verification. |

---

# §3. Top 5 Improvements (ranked by impact × effort)

## 1. Fix the inverted `most-severe` algorithm
- **Issue:** `consolidation-rules.md:175` `max(values, key=severity_order.index)` selects the *least*-severe value, opposite of the rule's purpose.
- **Why it matters:** This rule is the default for code-review severity; an inverted implementation silently downgrades every blocker-find to nit in consolidation.
- **Concrete change:** `rules/consolidation-rules.md:175` — replace
  ```
  - **Algorithm:** `max(values, key=severity_order.index)`. Ties broken by `majority` among the max-severity tier. If N=0, return `null` (or the schema default).
  ```
  with
  ```
  - **Algorithm:** order severities so that the most severe has the *highest* sort key. With `severity_order = ["blocker","major","minor","nit"]`, use `max(values, key=lambda v: (len(severity_order) - severity_order.index(v)))`, or equivalently `min(values, key=lambda v: severity_order.index(v))`. Ties broken by `majority` among the min-index (max-severity) tier. If N=0, return `null`.
  ```
- **Effort:** low; **Impact:** high; **Score:** high (top priority bug).

## 2. Reconcile `majority-with-uncertain` definition with the fact-check example
- **Issue:** The rule definition (`consolidation-rules.md:187`) requires `≥ max(2, ceil(N/2))`, so 2-of-3 passes; the `fact-check.md:63` example says 2-of-3 should default to `uncertain` and require `≥3`.
- **Why it matters:** The two halves of the same skill give opposite verdicts for the same input. One of them is wrong.
- **Concrete change:** pick one and align both. If the fact-check recipe is the intended behavior (require strict majority), update `consolidation-rules.md:187` to
  ```
  - **Algorithm:** require `> N/2` (strict majority) models to agree on a value. If met, return that value. If not, return `uncertain`. For N≤2 the threshold is N (unanimous).
  ```
  and update `fact-check.md:63` to reference the rule (delete the hardcoded "≥3 votes" override, or replace with "≥ strict majority of N").
- **Effort:** low; **Impact:** high; **Score:** high.

## 3. Fix the code-review recipe's broken schema (`primary_key: "file:line"`)
- **Issue:** `code-review.md:40` writes `"primary_key": "file:line"` as a string, but `SKILL.md:143` defines composite primary keys by listing multiple columns with `dedup_key: true`. Neither `file` nor `line` columns have `dedup_key: true` (lines 42-43), so per the skill's own spec the schema declares no dedup key.
- **Why it matters:** The code-review recipe — one of three published worked examples — cannot dedup findings. Every reviewer's findings will appear as separate items in the consolidated table.
- **Concrete change:** `rules/examples/code-review.md:38-54` — change to
  ```json
  {
    "type": "table",
    "primary_key": ["file", "line"],
    "columns": [
      {"name": "file",   "type": "string", "dedup_key": true, "required": true},
      {"name": "line",   "type": "number", "dedup_key": true, "required": true},
      {"name": "severity", "type": "enum", "values": ["blocker","major","minor","nit"]},
      {"name": "category", "type": "enum", "values": ["bug","security","perf","style","design","test"]},
      {"name": "description", "type": "text", "max_words": 50},
      {"name": "suggestion",  "type": "text", "max_words": 30},
      {"name": "evidence",     "type": "string", "max_words": 50}
    ],
    "conflict_resolution": {
      "severity": "most-severe",
      "category": "majority",
      "description": "longest-with-quote",
      "evidence":   "concatenate-all"
    }
  }
  ```
- **Effort:** low; **Impact:** high; **Score:** high.

## 4. Sanitize filenames and add `$OUT` to all recipe dispatch loops
- **Issue:** `code-review.md:30` and `fact-check.md:35` write `> "code-review-${model}.md"` / `"factcheck-${model}.md"` — `${model}` is `opencode-go/foo`, the slash creates a subdirectory or fails. Same recipes have no `OUT=`/`mkdir`.
- **Why it matters:** Both recipes fail on the very first dispatch if any user copies them verbatim, contradicting `dispatch-mechanics.md:54`'s own warning.
- **Concrete change:** mirror the prior-art recipe. In both files (and in the `code-review.md:13-32` and `fact-check.md:13-37` blocks) insert
  ```bash
  OUT=./multi-ai-out/$(date +%Y%m%d-%H%M%S)
  mkdir -p "$OUT" && cd "$OUT"
  ```
  and change `> "${PREFIX}-${model}.md"` to
  ```bash
  slug=$(echo "$model" | cut -d/ -f2)
  > "${PREFIX}-${slug}.md" 2> "${PREFIX}-${slug}.err"
  ```
- **Effort:** low; **Impact:** medium-high; **Score:** high (small fix, unblocks example usage).

## 5. Complete `run-manifest.json` example and unify phase numbering
- **Issue (A):** `output-schema.md:209-227` and `methodology.md:147-169` show a `run-manifest.json` missing `schema_auto_injected` (mandated by `SKILL.md:147`/`methodology.md:15`) and `aliases` (mandated by `consolidation-rules.md:336`).
- **Issue (B):** Phase numbering drifts: `methodology.md` says 4 phases, `consolidation-rules.md` uses Phase 2/3/3.5/3.6. A reader mapping dotted phases to the "4-phase" pipeline can't.
- **Why it matters:** The skill advertises an audit trail; the contract example omits two fields the prose says are required. Phase drift means an implementer cannot reliably speak about phases with other implementers.
- **Concrete change:**
  - Add to both `run-manifest.json` examples:
    ```json
    "schema_auto_injected": true,
    "aliases": {"AG2": "AutoGen", "MAF": "Microsoft Agent Framework"}
    ```
  - Renumber `consolidation-rules.md` Phase 2/3/3.5/3.6 → Phase 2/3/4/4.5 *or* add a phase-map table in `methodology.md` showing ALIGN=Phase2, DEDUP=Phase3 step1, RESOLVE=Phase3 step2, etc.
- **Effort:** medium; **Impact:** medium; **Score:** medium.

---

# §4. Open Questions

1. **Is there actually a reference implementation?** Every algorithm in `consolidation-rules.md` is pseudocode. Has any of this been implemented and run end-to-end beyond the 2026-06-27 prior-art run, or is the "core value of the skill" (`SKILL.md:196`) still entirely aspirational? The skill's correctness claims rest on the answer.
2. **Who is the canonical user?** Is this skill invoked (a) by a human via `/multi-ai-task`, (b) by another skill via the `task` tool, or (c) by an outer orchestrator like `silver-bullet`? `user-invocable: false` (`SKILL.md:5`) rules out (a), but the failure-mode rows are written as if speaking to a human operator running shell loops. The intended agent boundary changes which operational gaps (e.g., MCP-restart instructions in `dispatch-mechanics.md:102`) are tolerable.
3. **Is `--concurrency` honored?** It appears in the inputs table (`SKILL.md:69`) and is described as `parallel|sequential`, but no dispatch recipe uses it. Does the skill read this flag and choose sequential vs parallel, or is the user expected to choose by *not* backgrounding the forking process? If the latter, the flag is documentation theater.
4. **What is the rubric's scope?** The 8-dimension scoring rubric defined inside `research-prior-art.md:104-118` is being reused as this skill's self-assessment rubric. Is the rubric "the skill's own scoring model" or "the scoring model used by one example task"? The answer changes whether the rubric belongs in the example file or in the skill core.
5. **Version contract:** Does `version: 2.1.0` in the frontmatter mean the spec includes the v2.x known-bug row (`SKILL.md:228`)? If the skill is currently in use for a recursive self-review while it carries a "Known: ignore for v2.x" inconsistency, what's the user's contract for trusting other parts of the spec?

---

# §5. Confidence

- **Overall confidence:** **medium**.
- **What would change my assessment:** If I could read the implementing code (a shell script or JS runner that actually parses tables, applies aliases, computes `most-severe`), I could determine whether the inverted `max(values, key=severity_order.index)` pseudocode is a doc-only bug or implemented-as-written — that swings Issue #1 from "documentation bug" to "ship-stopper." Similarly, if a single end-to-end run log exists showing `schema_auto_injected` and `aliases` actually written to `run-manifest.json`, Issue #5 collapses to a doc-fix; if the run logs lack those fields, Issue #5 widens to a contract-vs-implementation violation.
