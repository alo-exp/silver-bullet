Let me verify a few cross-references and check for inconsistencies before writing the review.
I have all 8 files plus cross-reference checks. Here is the critical self-review.

---

# Critical Self-Review of `multi-ai-task` v2.1.0

Meta-note: this very review was produced by being recursively invoked through this skill. Several defects flagged below (phase numbering, thorough-mode under-specification, structured.jsonl conflict) are *exactly the kind of cross-document inconsistency that consolidation should have caught*. Their survival through two prior self-review rounds (round-1 `20260627-083255`, round-2 r2 `20260627-093345`) is itself evidence the consolidation loop is not closing.

---

## §1. Critical Assessment (per file)

### 1. `SKILL.md`

**Works well**
- Clear when-to-use / when-NOT-to-use tables; durable failure-modes table with concrete fixes.
- `--no-auto-inject` opt-out + `run-manifest.json → schema_auto_injected` audit field is well-thought-out.

**Missing / wrong**
- **Phase-numbering contract is broken in this file's own summary.** Lines 211–218 say "4 phases": Phase 1 Per-model execution, Phase 2 Output capture, Phase 3 Cross-model consolidation, Phase 4 Final synthesis. But `consolidation-rules.md` uses **5 phases** with different names (ALIGN/DEDUP/RESOLVE/SCORE+SYNTHESIZE, numbered 2–5). The two documents are incompatible; an agent invoking the skill will land on one numbering and assume the other one is wrong. Confirmed via grep: `consolidation-rules.md` contains `## Phase 5` (1 match), but this file never mentions Phase 5.
- **Arithmetic bug in Proven provenance.** Lines 271–272: "**6 OCG models** dispatched... **All 4 scoring matrices** (from 4 of 6 agents)... 2 agents produced qualitative comparisons only; 1 produced only the rubric." 4 + 2 + 1 = 7, not 6. Either two groups overlap (the prose implies disjoint), or the run actually had 7 models, or a category is mis-counted. The fix is to either state the overlap ("of which 1 also produced only the rubric") or correct the numbers. As written, the headline provenance is self-contradicting.
- **`--mode thorough` adds a verifier-model sub-dispatch but no dispatch-mechanism guidance exists.** `dispatch-mechanics.md` has **zero** `thorough`/`verifier` mentions; `methodology.md` has **zero** as well (only this file does, 13×). The verifier call is therefore orphan spec.
- **`type` contract is contradicted elsewhere.** Line 132: `type` → *"Always 'table' (the only currently supported shape)"*. But `consolidation-rules.md:317` shows `"type": "code-review"` as a working example. Either the spec is wrong (other `type`s are allowed) or the consolidation example is wrong.

**Unclear**
- "**Recommended: 4-6 models from at least 2 different provider families**" appears at line 65, but the proven run used 6 models from ONE family (`opencode-go/*`). Is a one-family run still "proven" but off-spec, or is the recommendation soft?
- Auto-inject instruction string nonsensical when invoked recursively: it appends *"Return your answer as a markdown table with exactly these columns, and nothing that does not match this schema"* — for free-form, narrative, or list tasks this actively harms model output. Auto-inject is a single instruction string, parameterless per task shape.

---

### 2. `rules/methodology.md`

**Works well**
- Mode A extraction pseudocode ladder (table → `<structured>` tags → extractor model → paragraph split) is well-ordered with explicit failure rationale for fallback choices.
- The "extractor is NOT the producing model" clarification (line 104) prevents a real anti-pattern.

**Missing / wrong**
- **No thorough-mode phase.** This file declares "4 phases" and ends at Phase 4 Final synthesis. Thorough-mode cross-source verification (a verifier model per claim) is documented only in `SKILL.md`'s mode table. Methodologically, verification should be either Phase 3.5 or a Phase 5 here. Its absence means there's no algorithmic description of *how* the verifier is invoked (batched? sequential? which model? what prompt?). Confirmed: 0 `thorough`/`verifier` mentions in this file.
- **`structured.jsonl` semantic collision with `output-schema.md`.** Line 118 says consolidated canonical records are *"stored in `structured.jsonl` (append mode with `model: "_consolidated"`)"*. But `output-schema.md:197` says `structured.jsonl` is *"One JSON per line per (model, item) — the raw extraction BEFORE consolidation."* Either `structured.jsonl` mixes raw + consolidated rows (undocumented in the output-schema), or one of these two files is wrong. They cannot both be right.
- **Phase 3 description in this file lumps 3 consolidation-rules phases.** Cross-model consolidation here (#3) merges "aggregate, dedup, conflict resolution, score aggregation, confidence" — but `consolidation-rules.md` splits the same work into Phase 3 (DEDUP) + Phase 4 (RESOLVE) + Phase 5 (SCORE+SYNTHESIZE). Phase-3 entry description cannot tell you where scoring happens. Defect scope: any LLM trying to track per-phase audit fields gets lost.

**Unclear**
- "If a model fails... excluded from consolidation" — does the dissolution of N models change `majority`/`majority-with-uncertain` thresholds (they're N-dependent)? Line says "the run continues with the models that did respond", but the conflict rules hard-code N from `models_dispatched` or `models_responded`? Undocumented; matters because `majority-with-uncertain` returns `unverified` with strict-majority at high N, dropping a model from N=6→5 silently changes the threshold from 4 to 4 (same) but N=4→3 changes it from 3 to 3 — fine — but N=5→4 changes 4→3 — material.

---

### 3. `rules/dispatch-mechanics.md`

**Works well**
- Definitive, dated constraint at line 28: *"The `task` tool's `Parameters` schema does not include a `model` field... dynamic per-call model selection is a 6-time-requested feature... not yet released."* Cites issues. Good reversal-of-latest-trend evidence.
- Parallel-vs-sequential trade-off table with the non-obvious "MCP port collision caveat" (lines 113–114) is genuinely useful hard-won knowledge.

**Missing / wrong**
- **`copilot-subprocess-died-after-2-min` failure entry is duplicated nearly verbatim across files.** This file (line 134) and `SKILL.md` (line 252) and `methodology.md` (via references) all describe the same 2-min timeout. Three locations means three places to update when the host changes the default.
- **Thorough-mode verifier dispatch is completely undocumented here.** The verifier model needs to be dispatched somehow (`task`? `opencode run`?), with its own timeout, auth, and concurrency. Confirmed 0 `thorough`/`verifier` mentions. For a high-stakes mode that adds " зоны N_items × 1 verifier call," that's a real implementation gap.
- **`--dangerously-skip-permissions` for "write tasks" guidance is contradictory.** Line 66: *"--dangerously-skip-permissions is fine for read-only tasks... For write tasks, do NOT use this flag — let the agent prompt for permission."* But parallel background dispatch (`&` and `wait`) cannot prompt interactively — a backgrounded subprocess asking for permission will hang forever. So the recommended security posture (don't skip perms on write tasks) is incompatible with the recommended performance posture (parallel background dispatch). The skill is silent on this.

**Unclear**
- "Recommended default: choose parallel if `max(per_model_time) ≤ your latency budget`" — but the per-model wall-time is unknown until dispatch. How does the caller estimate it? The example uses `TIMEOUT=600` as an outer bound, but `max(per_model_time)` prediction is left to the caller with no heuristic given beyond "the proven 6-model run was 2-3 min/model."

---

### 4. `rules/consolidation-rules.md`

**Works well**
- The named-rule library (`most-severe`, `majority`, `majority-with-uncertain`, `lowest-of-majors`, `longest-with-quote`, `concatenate-all`, `all-collected`, `union-dedup`, `merge-exact`) is a genuinely useful catalog — each has input, algorithm, edge case.
- `prefer-with-evidence-then-newer-then-strict` rule's 4-step ordered tiebreak is precise enough to implement directly.

**Missing / wrong**
- **Phase numbering diverges from `methodology.md` and `SKILL.md`.** This file uses Phase 2 ALIGN / Phase 3 DEDUP / Phase 4 RESOLVE / Phase 5 SCORE+SYNTHESIZE. `methodology.md` uses Phase 1 / 2 / 3 / 4. There is no Phase 5 in the other files. An agent constructing the audit field `phases_completed: [1,2,3,4]` cannot tell whether to append 5 or whether 5 maps onto methodology Phase 4. Real defect.
- **Custom-strategies code block self-contradicts the schema spec.** Lines 313–322 show:
  ```json
  { "type": "code-review", "dedup_key": "file:line", ... }
  ```
  This violates BOTH constraints declared elsewhere: (a) `SKILL.md:132` says `type` is always `"table"`; (b) the code-review recipe (`code-review.md:70`) explicitly says `"primary_key": "file:line"` is **wrong for composite keys** and the correct form is `dedup_key: true` on multiple columns. So this file's own example is the bug it warns against two files later.
- **`majority-with-uncertain` threshold algorithm has an unhandled edge case.** Algorithm is `> max(2, ceil(N/2))`. For N=2: max(2,1)=2, need >2 → 3 votes from 2 models = impossible. So N=2 fact-checks are *always* `unverified`. The edge case in `consolidation-rules.md` line 184 covers N=2 with "two models must agree exactly (any dissent returns unverified)" — but the algorithm gives the same result. The fact-check recipe (`fact-check.md:38`) recommends N=3 models. The recipe advises "use 4-5 for fact-check" line 37 but the proven prior-art run used 6 models — no N=6 worked example for fact-checks.
- **`most-severe`'s tie-break ("majority among the max-severity tier") is undefined when the max-severity tier has only 1 voter.** The text assumes ties exist; when only 1 reviewer says `blocker` and 5 say `major`, the "tie-break by majority among the max tier" is a vacuous 1-of-1 majority that is trivially the lone blocker — but this is not stated. The `allow_downgrade` flag (line 171) is *optional*, so the spec lets a single lone reviewer block a finding as a blocker forever, with no rule tie-break actually being defined. This may be intended (safety principle) but the rule description gives the wrong impression of a defined tie-break.
- **`longest-with-quote` ties broken by `last_verified` — but `last_verified` is per-item, not per-model.** The same item has the same `last_verified` regardless of which model wrote it. So "tie-break by recency (model's last_verified)" can never break a tie between models on the same item. Either this should be "task's verification date" not "model's," or the tie-break is really "the first-encountered input order" — undocumented.
- **No alias-map transport.** "Document the alias map in `run-manifest.json → aliases` field" (line 333) — but the key format is `{"AutoGen/AG2": "AutoGen"}` (alias-string → canonical-string) per output-schema.md example, while the research example (research-prior-art.md:125–141) presents aliases as a markdown table where the column header is "Alias" listing comma-joined variants and "Canonical" is the canonical. There's no documented JSON encoding (one canonical holding multiple aliases vs the reverse). Render mismatch between prose example and machine field.

**Unclear**
- "Sort by `entries.length` descending, then by canonical name" — for code-review where `entries.length=2` (2 reviewers found same finding) on every row, the sort degenerates to alphabetical by file:line. Not wrong; just unhelpful sort for that case. The skill implies this sort works for every task.

---

### 5. `rules/output-schema.md`

**Works well**
- Single canonical home for `run-manifest.json` field semantics; explicit "field semantics" subsection; v2.1.0 changelog markers inline (line 245, 251).
- Markdown formatting rules for WYSIWYG viewer compatibility (lines 258–268) are concrete and skimmable.

**Missing / wrong**
- **`structured.jsonl` row format in this file does NOT match the methodology description.** This file (line 197) says it's "One JSON per line per (model, item) — the raw extraction BEFORE consolidation." `methodology.md:118` appends rows with `model: "_consolidated"` to the SAME file. This file defines neither the consolidated row format nor the marker `"_consolidated"` field value — so reading only this file, an implementer would not know consolidated rows exist there at all. Either the spec is incomplete or the methodology description is aspirational.
- **Schema `dimensions` / `levels` / `aggregate` / `max_total` (used in `research-prior-art.md:104-118`) are absent from "Supported top-level schema fields."** Lines 128–135 list only `type`, `primary_key`, `columns`, `conflict_resolution`. So the *proven worked example* uses an undocumented shape. The research example is itself spec-violating per this schema.
- **§2A "Items Table (Mode A — schema-defined table)" falls through to default when `--schema` not provided** — contradicted by line 53's header ("When `--schema` is provided... render the consolidated items in a markdown table"). Lines 55–63 ("When `--schema` is not provided, use the default items table") appear *inside* §2A which is headlined "Mode A — schema-defined table." The §2B section (`output-schema.md:79`) ALSO describes the no-schema case. The result: two different "no-schema" item-table formats live in §2A and §2B. Reader cannot tell which applies.
- **Conflict-marker legend (line 73)** says: *"Use a code-span like `` `direct*` `` if your viewer is WYSIWYG-strict; bare `*` otherwise."* Two formats for the same field; renderer-dependent. A downstream tool parsing `consolidated.md` cannot reliably detect conflicts — one channel has the marker inside backticks (parsed as plain string), the other as bare `*` (collapsed-as-emphasis). Format is conditioned on the renderer, not the consumer. Audit-tooling-hostile.

**Unclear**
- `models_responded` (line 248) — "bare slugs" (e.g., `"minimax-m3"`) — while `models_dispatched` (line 247) — "full provider/model IDs" (e.g., `"opencode-go/minimax-m3"`). Why two different identifier schemes for the same logical entity? A consumer must normalize both to join them.
- `models_failed` (line 249): list of `{model, stderr_excerpt, exit_code}` — but `models_dispatched` and `models_responded` use bare strings. Three different element schemas for the same shape (a model). Schema is not internally consistent.

---

### 6. `rules/examples/research-prior-art.md`

**Works well**
- 14-entry alias map (`AutoGen` ↔ `AG2`, `MAF` ↔ `Microsoft Agent Framework`, etc.) is real, dense, and exactly the right kind of task-specific tribal knowledge that belongs in an example file.
- Generic skip rules enumerated separately from research-specific skip rules.

**Missing / wrong**
- **Uses API shape that violates the schema spec (`SKILL.md` "Supported top-level schema fields").** The scoring rubric JSON (lines 105–118) uses top-level keys `dimensions`, `levels`, `aggregate`, `max_total` — *none* documented in the schema spec. The "proven provenance" example is therefore spec-illegal per the skill's own published schema contract.
- **Schema redundancy at lines 73–99.** `"primary_key": "name"` AND `{"name": "name", "type": "string", "dedup_key": true}` both declare `name` as dedup key. `SKILL.md:133` says `primary_key` is a "convenience alias for putting `dedup_key: true` on one column." So if both are set, the `primary_key` is harmless redundancy — but the docs never say that. Reader may worry about precedence / conflict.
- **"Variations to try" bullet misleads on cost.** Line 182 says "8-10 models captures more unique finds but diminishing returns past 6 (this is an empirical observation, not a measured curve — run your own benchmark if you want a hard number)." OK caveat, but the inline research doesn't actually measure recall @ N. The claim is unverified hand-wave dressed as evidence.

**Unclear**
- The example dispatch (lines 13–33) uses `cd "$OUT"` — but `dispatch-mechanics.md` example (lines 37–61) does NOT cd into `$OUT`; it writes relative paths. Why the inconsistency? Both are "proven"? Style divergence is undocumented.
- "Save it in your run's `run-manifest.json → aliases` field" (line 123) — but the alias map here is a markdown table. How does a markdown table become a JSON field? Encoding unspecified (matches the defect flagged in §1 consolidation-rules assessment).

---

### 7. `rules/examples/code-review.md`

**Works well**
- Anti-pattern call-out at line 70 (*"Why `primary_key: "file:line"` is wrong for composite keys"*) explicitly prevents a JSON beginner's misuse. Concrete and pedagogically right.
- Custom `severity_order` extension (lines 73–77) shows how to add a custom `critical` tier without breaking defaults.

**Missing / wrong**
- **Composite key when `line` is missing or wrong.** Schema marks `line` as `required: true`. But code-review models often return findings at file granularity (e.g., a "whole function is poorly factored" finding with no line). What happens? The spec (`methodology.md:69`) says "row dropped if missing required field." So holistic findings are silently dropped from the consolidated report. Not mentioned. For a *code review* recipe this is a real coverage gap.
- **"Pre-commit hook: NOT currently supported as a built-in dispatch"** (line 107) — but this skill lives inside the silver-bullet repo where hooks are a primary surface. Either state explicitly this is out of scope for v2.x, or note that it's deferred to v2.2/v3. As written, it's a one-line discouragement that minimizes a real gap.
- **"Worked example: Not yet produced (deferred to v2.2.0)"** (line 111). The SKILL.md headlines the prior-art example as the canonical *proven* run, but only ONE of three named recipes has a worked example. That asymmetry is itself a finding — code-review/fact-check examples are unproven.

**Unclear**
- `description: "longest-with-quote"` recommended (line 98) — code-review finding descriptions don't usually contain quoted evidence because reviewers *wrote* them (vs research items that quote a source). "Quote" here means a code quote of the offending line. The named rule doesn't disambiguate "code quote" vs "source quote" — semantics of the rule applied to code-review is unstated.

---

### 8. `rules/examples/fact-check.md`

**Works well**
- High-stakes consensus requirements (lines 102–109) are sensible and well-separated from the looser `majority` rule.
- Per-section output structure (§5 Source Quality, §6 Unverified, §7 False Claims) appropriately treats false claims and unverified claims as separate epistemic states.

**Missing / wrong**
- **Only N=3 hardcoded in the example** (line 38), explicitly: *"use 4-5 for fact-check; majority-with-uncertain needs N>=3."* But the strict-majority threshold is N-dependent and jumps from "all 3 must agree" (N=3) to "at least 4 of 5 agree" (N=5) — qualitatively different. The example dispatches only the cheapest case (N=3, all-must-agree). For high-stakes fact-check, N=3 means a single dissent cancels a claim — the practitioner has no worked example showing how a 4-of-5 result actually renders in `consolidated.md`.
- **`counter_evidence` uses `concatenate-all` (line 99)** — but the named rule `concatenate-all` joins by ` ; ` (per `consolidation-rules.md:203`). For multi-paragraph counter-evidence, ` ; ` is unreadable and the schema gives no alternative separator override (only `url_list` has a `separator` field per `SKILL.md` column field spec). Output will be ugly concatenations of dissenting reviewers.
- **`sources` (`url_list`) conflict_resolution is unset.** The schema at lines 56–70 sets `verdict`, `confidence` rules, but `sources` uses its default (`union-dedup` per `consolidation-rules.md:152`). That's fine — but the recommended-strategies table (line 98) explicitly recommends `union-dedup` for sources anyway. So the custom-strategies table restates the default. Redundant.
- **No worked example (line 113)** ("deferred to v2.2.0"). Two of three example recipes lack worked examples — the "proven provenance" claim in `SKILL.md` covers only research.

**Unclear**
- "All N models agree on `true` with high confidence + primary source → confirmed" (line 104) — "primary source" is undefined. The skill has no documents specifying primary vs secondary hierarchies. The extractor pulls URLs and the verifier in thorough mode checks if a source supports a claim, but no tiering formalism exists. A reader implementing this has to invent the tiering.

---

## §2. Score on the 8-Dimension Rubric

Using the rubric defined in `consolidation-rules.md` (named rules library) and the rubric in `research-prior-art.md`:

| # | Dimension | Score | Justification |
|---|---|---|---|
| 1 | Catalog of composable units | **1** | Named-rule library (`most-severe`, `majority-with-uncertain`, `lowest-of-majors`, `concatenate-all`, `union-dedup`, `merge-exact`, `longest-with-quote`, `prefer-with-evidence-then-newer-then-strict`, `majority`, `all-collected`) is *informal* — named strings referenced in JSON, no machine-readable registry with stable IDs/types/signatures. Phase catalog (4-or-5 numbering conflict) is itself broken. |
| 2 | Dynamic composition | **1** | Conflict rules are chosen per-field by schema (`conflict_resolution: {field: rule}`) — schema-driven selection, but it's *static* config, not a runtime replanner. There IS an audit log (`conflicts.md`, `run-manifest.json`), but no composition decisioning adapts at runtime. |
| 3 | V-loop depth | **1** | End-of-run tests only: `phases_completed` array in `run-manifest.json`, no per-step per-phase rollup. Thorough mode adds per-claim verification but is off by default and only sketched in `SKILL.md`. No intent gate. No mid-pipeline checkpoint that lets the user say "stop, repeat at higher N." |
| 4 | Enforcement | **0** | Pure honor system. The skill explicitly delegates retry to the calling agent (`methodology.md:19`, `dispatch-mechanics.md:129`). There's no IDE hook, no CI gate, no delivery blocker — and the silver-bullet CI parity/freshness tests enforce the REPO, not this skill's outputs. The skill itself defines ZERO verification of its own output. |
| 5 | Parent/worker split | **2** | Explicit: calling agent is the orchestrator; N dispatched models are the workers; consolidation happens in the orchestrator. The distinction is clear in `dispatch-mechanics.md` and the recipe dispatch scripts. |
| 6 | Evidence model | **1** | Informal. `structured.jsonl` records per-model evidence pointers (`source_refs`); `last_verified` is per-item; thorough mode's `evidence-ledger.md` is tiered-ish (verified/wrong/uncertain) but only thorough-mode-only and undocumented algorithmically (where is the verifier's prompt defined?). No staleness handling beyond the date the model cited; no sufficiency tiers. |
| 7 | SE + DevOps unified | **0** | Covers neither production task type as a first-class concept — by design (task-agnostic). The rubric originally scored research candidates for SE+DevOps coverage; here the skill itself models neither. Generic orchestration ≠ unified SE+DevOps modeling. |
| 8 | Team customization | **0** | No overlay or team-pack concept. Aliases are task-specific JSON blobs embedded in `run-manifest.json`; conflict rules are per-schema JSON. There is no packaging mechanism by which, e.g., a security team could publish its `--schema` + alias map for reuse without manual copy. Custom strategies (consolidation-rules.md:299-322) are prose recipes, not packs. |
| | **Total** | **6 / 16** | |

A score of 6/16 places this skill in the "informal but workable" band: solid parent/worker split and partial-evidence-model, but no enforcement, no production-task-type modeling, no team-pack mechanism, and an internally-broken phase catalog that prevents catalog-backed composition from becoming machine-readable.

---

## §3. Top 5 Improvements (ranked by impact × effort)

### 1. **Reconcile the 4-phase vs 5-phase numbering across `methodology.md`, `consolidation-rules.md`, `SKILL.md`**
- **Issue:** Three documents disagree on pipeline structure (`Phase 1-4` vs `Phase 2-5 ALIGN/DEDUP/RESOLVE/SCORE+SYNTHESIZE`).
- **Why it matters:** Any agent constructing `phases_completed` cannot produce a value that's consistent across all three places; consolidation audit integrity is compromised at the protocol level.
- **Concrete change:** In `consolidation-rules.md` rename `## Phase 2 — ALIGN` → `## Phase 2 — ALIGN (subsumes methodology Phase 2 extraction)`, `## Phase 3 — DEDUP`, `## Phase 4 — RESOLVE`, and **delete `## Phase 5`**; fold SCORE+SYNTHESIZE into Phase 4. In `methodology.md:105` add a sub-bullet: "*Phase 2 ALIGN detailed algorithm: see `consolidation-rules.md §Phase 2`; Phase 3 sub-decomposition: DEDUP/RESOLVE/SCORE in `consolidation-rules.md §Phase 3-4`.*
- **Effort:** low
- **Impact:** high
- **Score (impact/effort):** 3.0

### 2. **Define the *single* canonical schema for `structured.jsonl` and document the `_consolidated` row at `output-schema.md:197`**
- **Issue:** `structured.jsonl` is described inconsistently: raw-only rows here, raw + `_consolidated` appended rows in `methodology.md:118`.
- **Why it matters:** A consumer of `structured.jsonl` (audit tool, re-consolidator) cannot reliably parse it — the row shape changes mid-stream.
- **Concrete change:** At `output-schema.md:197` add: "*Two row kinds are interleaved: (a) per-model extractions, shape `{"model": "<slug>", "row_id": int, "primary_key": ..., "fields": ..., "source_refs": [...], "raw_text": ...}`; (b) consolidated canonical rows, shape `{"model": "_consolidated", "row_id": int, "primary_key": ..., "fields": ..., "models": [...], "conflicts": [...], "confidence": "high|medium|low"}`. Filter by `model === "_consolidated"` to read final output."* In `methodology.md:118` change "append mode with `model: "_consolidated"`" to reference this schema rather than redefining.
- **Effort:** low
- **Impact:** high
- **Score (impact/effort):** 3.0

### 3. **Fix `consolidation-rules.md` Custom-strategies code example to conform to spec (`type` field + composite keys)**
- **Issue:** Lines 313–322 show `"type": "code-review", "dedup_key": "file:line"` which violates `SKILL.md:132` (type always `"table"`) and `code-review.md:70` (`primary_key: "file:line"` is wrong).
- **Why it matters:** The skill's own example is the bug the skill itself warns against elsewhere; new practitioners will copy it.
- **Concrete change:** Replace with:
  ```json
  {
    "type": "table",
    "columns": [
      {"name": "file", "type": "string", "dedup_key": true, "required": true},
      {"name": "line", "type": "number", "dedup_key": true, "required": true},
      {"name": "severity", "type": "enum", "values": ["blocker","major","minor","nit"]}
    ],
    "conflict_resolution": {"severity": "most-severe", "category": "majority"}
  }
  ```
- **Effort:** low
- **Impact:** medium
- **Score (impact/effort):** 2.5

### 4. **Document the thorough-mode verifier dispatch in `dispatch-mechanics.md` (not just `SKILL.md`)**
- **Issue:** `dispatch-mechanics.md` has 0 `thorough`/`verifier` mentions yet thorough mode requires dispatching a verifier model per item.
- **Why it matters:** The cost claim in `SKILL.md:83` ("~3-5 min sequential / ~1 min parallel for 36 items × 1 verifier") is unverifiable without knowing whether verifier dispatch reuses Mechanism 2, what its timeout is, what prompt it gets, and what model is chosen.
- **Concrete change:** Add a `### Mechanism (thorough-mode verifier dispatch)` section in `dispatch-mechanics.md` between current Mechanism 4 and "Parallel vs sequential." Specify: (a) verifier is one model the user picks or the slowest from the dispatch set; (b) per-claim batched prompt with `ctx_batch_execute` style input (`{claim, claimed_source}` pairs); (c) per-claim timeout 60s if batched sequentially, 600s if batched; (d) it reuses `opencode run --model <verifier>` (Mechanism 2).
- **Effort:** medium
- **Impact:** high
- **Score (impact/effort):** 2.0

### 5. **Fix the arithmetic in `SKILL.md:270-272` Proven provenance (4 + 2 + 1 ≠ 6)**
- **Issue:** "6 OCG models... 4 produced scoring matrices... 2 produced qualitative comparisons only... 1 produced only the rubric" — sums to 7, but the sentence implies disjoint buckets summing to 6.
- **Why it matters:** The headline provenance is the skill's credibility anchor. Self-contradiction in the most-quoted paragraph undermines all other empirical claims (e.g., the 36-unique-products count).
- **Concrete change:** At `SKILL.md:271` change `"All 4 scoring matrices (from 4 of 6 agents) extracted and aggregated (median + range per dimension); 2 agents produced qualitative comparisons only; 1 produced only the rubric"` to either `"All 4 scoring matrices (from 4 of 6 agents) extracted and aggregated (median + range per dimension); 5 of 6 also produced qualitative comparisons (one of those produced only the rubric); 2 of the 6 produced no matrix at all"` or correct the actual numbers if the run had 7 models.
- **Effort:** low
- **Impact:** medium (trust, not correctness)
- **Score (impact/effort):** 2.0

---

## §4. Open Questions

1. **Which phase numbering is canonical for the audit field `phases_completed`?** If the answer is "1-4," then `consolidation-rules.md` should delete `Phase 5`. If "1-5," then `methodology.md` and `SKILL.md` should explicitly renumber. Knowing this changes the audit-log format and any tooling that consumes it.

2. **Is there an actual reference implementation of the skill, or is it pure prose + pseudocode?** The whole repo structure (hooks, scripts, JSON manifests) suggests silver-bullet is a runnable system; this skill is at the *documentation-tier* of that system. If the implementation is host-supplied (the calling agent reads the prose and executes it manually), then "consolidation correctness" is uncontrollable — no test suite asserts the named rules behave as described. If there is an implementation, the docs should link to it; if there isn't, the docs should state "this skill is a methodology, not an implementation."

3. **What's the intended audience?** A few signals conflict: (a) the prose assumes the reader is the *calling agent* (e.g., "Build the alias map for your task type (or start with no aliases...)" at `consolidation-rules.md:332-333`) — implying the agent is writing code to implement this; (b) the frontmatter `user-invocable: true` implies a human types `/multi-ai-task` and the harness runs it; (c) the dispatch examples are copy-pastable bash from a human shell. Three audiences; one doc. Which one is the contract for?

4. **What's the verifier-model cost contract in thorough mode?** "Adds ~N_items × 1 verifier call" is the only cost claim; for N_items = 100, that's 100 sequential LLM dispatches. Is there a batched variant, an early-exit (skip items with unanimous models), a model-tier reduction (use a cheap verifier for high-confidence items)? The skill is silent.

5. **Does thorough mode actually open URLs and check them, or does it dispatch a verifier that *claims* to have checked?** "Verifier model checks the claimed source actually supports the claim" (`SKILL.md:81`) — a model can hallucinate a verdict. The evidence ledger lists `verdict: verified|wrong|uncertain` but no guarantee the verifier actually fetched the URL. What's the integrity story?

6. **What is the relationship between this skill and the silver-bullet artifact-reviewer skills (`review-spec`, `review-roadmap`, etc.)?** Both implement "N-model review → consolidated output" patterns. Are they redundant, complementary, or do they cover orthogonal scopes (artifact-reviewers review artifacts, this reviews arbitrary prompts)?

---

## §5. Confidence

- **Overall confidence: medium-high.** The defects I flag are concrete (quote + file:line), reproducible from the files, and verifiable by grep. I am NOT high-confidence on two of my "arithmetic bug" claims in `consolidation-rules.md` (`most-severe` tie-break, `longest-with-quote` recency) — these might be intended behaviors that read ambiguously rather than real defects.
- **What would change my assessment:** (a) seeing the actual prior-art run output (e.g., `SB_CONSOLIDATED_PRIOR_ART_REPORT.md`) to verify the 36-item count and the 4-matrix/2-qualitative/1-rubric breakdown — if the report shows the buckets overlap as I suspect, defects #1 (phase numbering), #3 (custom-strategies example), and #4 (verifier dispatch) remain but the arithmetic fix #5 weakens; (b) reading an actual implementation file (if one exists) rather than docs-only — many "spec conflicts" would resolve if a source-file canonicalizes them; (c) confirming whether `consolidation-rules.md` `Phase 5` is intended to be retired (silently corrects several downstream findings).
