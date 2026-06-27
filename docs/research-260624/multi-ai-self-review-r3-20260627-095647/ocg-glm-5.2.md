# Critical Self-Review of `multi-ai-task` (v2.1.0)

> Reading all 8 files of the skill and assessing it as a skeptical reviewer. Note: the task prompt claims the skill is at "v2.0.0", but `SKILL.md:6` actually declares `version: 2.1.0`. I'll treat v2.1.0 as canonical (the frontmatter is authoritative over the task description).

---

## §1. Critical Assessment (file-by-file)

### 1.1 `SKILL.md` — entry point, usage, when to use/not use, provenance

**What works well**
- Clean "When to use / When NOT to use" matrix (`SKILL.md:35-50`); from the perspective of someone sizing up the skill, it gives honest guidance on cost, latency, and diversification value.
- Modes `quick | standard | thorough` show mode-by-mode behaviour in one place (`SKILL.md:78-84`), including overdue cost advice ("thorough adds ~N_items × 1 verifier call").

**What is missing or wrong**
- **Mis-placed "does NOT do" bullet.** `SKILL.md:28` lists under "What this skill does NOT do": *"Inject the schema into the prompt unless `--no-auto-inject` is set (default ON — see …)"*. This sentence describes what the skill **does** do (inject is the default; only suppressed by the flag). It belongs in the "What this skill DOES do" list (lines 15-23), not under "does NOT do". As written, the bullet is a self-contradiction and confusing.
- **Self-version inconsistency.** Frontmatter is `version: 2.1.0` (line 6), but the prose at `methodology.md:178` says "(v2.1.0+)" of `schema_auto_injected` and `aliases`. Fine. The issue is the body never says "current version 2.1.0" — the user has to hunt the frontmatter. Also `SKILL.md:228` references "v2.x" generically. Consider pinning a current-version line + a changelog pointer.
- **Failed-dispatch retry is "the calling agent's responsibility" (`SKILL.md:29`, `:230`; `methodology.md:19`)**, yet `thorough` mode "dispatches a verifier model to check the claimed source" (`SKILL.md:82`) — i.e., the *skill* dispatches extra models. The retry-avoids-dispatch principle and the thorough-dispatches-verifiers principle are in tension; neither file reconciles the two.
- **Proven provenance is date-stamped to 2026-06-27** (`SKILL.md:236`, `:244-246`), tied to a folder name `docs/research-260624/`. The skill acknowledges the folder-name/run-date mismatch in `SKILL.md:244`. But by now the prior-art in that run is ~12 months stale and the "prior art example" is increasingly an archaeology artefact, not a recipe that reflects the current model landscape. The skill lists the OCG model IDs in `:239` (`minimax-m3`, etc.) which themselves may not exist a year later.
- **No "How is the skill implemented" section.** The skill repeatedly says "the skill does X" (e.g., line 19 "Extracts structured items from each response") but never states *where the implementation lives* — there's no `bin/`, `scripts/multi-ai-task.sh`, or npm package. The "skill" appears to be promissory — it's only Markdown specs, executed by the calling agent doing the steps by hand. There's no actual program. That's fine for a "prompt skill," but it should say so explicitly: "this skill is a procedure for the calling agent; the agent performs each phase as steps." Instead it reads as if there were an implementation backing it.

**What is unclear or ambiguous**
- "Default model discovery (`SKILL.md:74`)" — *who* queries `~/.config/opencode/opencode.json`? The calling agent? An embedded script? An implementation would do that; promissory prose does not.
- `SKILL.md:228` (the `score-aggregate.md` failure-modes row) is a vestige: it tells the user "ignore this v2.x inconsistency." Why is a known broken output path mentioned in the failure modes? If `score-aggregate.md` is dead, delete the row from the table.

### 1.2 `rules/methodology.md` — 4-phase pipeline

**What works well**
- Clean Phase 1–4 split; each phase has inputs, outputs, and a fail-soft caveat (`methodology.md:19`).
- Row validation rules are concrete: `required:true` drops rows, `min/max` enforced, `max_words` truncates with `...` marker (`methodology.md:69-72`).
- Example `structured.jsonl` row at `:28` is concrete and immediately parseable.

**What is missing or wrong**
- **Phase naming collision with `consolidation-rules.md`.** Here Phase 1–4 is the master pipeline. But `consolidation-rules.md` introduces **Phase 2 — ALIGN, Phase 3 — DEDUP, Phase 3.5 — RESOLVE CONFLICTS, Phase 3.6 — SCORE + SYNTHESIZE** (`consolidation-rules.md:26,78,136,266`). Consolidation-rules assigns "ALIGN" (extraction) to *its* Phase 2 (matches methodology's Phase 2 ✓), but then "DEDUP" to *its* Phase 3 — methodology's Phase 3 is called "Cross-model consolidation" which covers dedup AND conflict resolution AND scoring. The 3.5 and 3.6 sub-phases have no home in methodology.md. The two files use overlapping-but-not-identical phase numbers. Pick one as canonical, or rename consolidation-rules' sub-phases (e.g., "Phase 3a-d") to remove ambiguity.
- **`structured.jsonl` is overloaded.** `methodology.md:25` says Phase 2 writes per-(model,item) JSONL lines. `methodology.md:118` says Phase 3 *also* writes to `structured.jsonl` in append mode with `model: "_consolidated"`. So one file holds both raw per-model rows AND consolidated records, mixed. A consumer tool can't tell "is this the pre- or post-consolidation file?" without inspecting each row. Either: (a) split into `structured-raw.jsonl` + `structured-consolidated.jsonl`, or (b) add a `phase: 2 | 3` field to every row. Currently the only disambiguator is `model == "_consolidated"`, which is fragile — what if a real model happens to be named `_consolidated`?
- **`run-manifest.json` schema divergence.** `methodology.md:147-174` declares the *canonical* schema, which includes `task_prompt_hash`, `schema_auto_injected`, `aliases`, `phases_completed`, `consolidation` block, and `models_failed`. But `output-schema.md:209-227` — which methodology.md claims is canonical (`methodology.md:147`) — shows a leaner schema that omits `task_prompt_hash`, `schema_auto_injected`, `aliases`, `phases_completed`, and `consolidation`. So the "canonical" file disagrees with the file that declares it canonical. This is a real bug; consumers won't know which is correct.
- **Phase 2 Mode B "fragile" fallback never tested by the worked example.** The free-form extractor's paragraph-split fallback is tagged "fragile; flag `fuzzy_match:true`" (`methodology.md:99`). The prior-art worked example uses Mode A (table). Mode B's paragraph-split path is unexercised; no recipe demonstrates it; no test covers it.
- **`methodology.md:104` "Extractor model … not a CLI parameter."** Extractor model selection ("slowest, highest-capability") is an implementation choice the user can't override. If a user's strongest model is rate-limited, there's no way out except by hand-coding. At minimum, expose `--extractor-model` even if optional.

**What is unclear or ambiguous**
- Phase 1 prompt delivery: "each model has its own tool/MCP context" (`methodology.md:12`). But if models are dispatched via Mechanism 2 (`npx opencode-ai run`), they're a fresh CLI invocation — not the calling agent's MCP set. The diagram in the user's head breaks here: which MCPs do the spawned models have? Unaddressed.
- "Idempotent re-runs" (`methodology.md:207`) says each run is fresh, no caching — but `task_prompt_hash` exists "for cache lookup and reproducibility audit" (`methodology.md:182`). Which is it — cached or not? The hash implies a cache that the prose disclaims.

### 1.3 `rules/dispatch-mechanics.md` — 4 dispatch mechanisms

**What works well**
- Mechanism 1 vs Mechanism 2 distinction (and the note that `task` tool's `subagent_type` enum can be harness-restricted) is genuinely useful operational intel.
- Parallel-vs-sequential decision guidance at `:94-100` is concrete: "≤ latency budget → parallel; otherwise sequential."
- Model-selection strategy table at `:155-161` is short and accurate ("≥1 reasoning-focused model + ≥1 generalist" for research-heavy work).

**What is missing or wrong**
- **`--dangerously-skip-permissions` contradiction.** `dispatch-mechanics.md:56`: *"`--dangerously-skip-permissions` is fine for **read-only** tasks (research, code review, fact-check). For **write tasks** … do NOT use this flag."* But `code-review.md:45-46` says: *"code review is a read-only task — the models just read and report, they don't write. So the dispatch above does **NOT** pass `--dangerously-skip-permissions`."* Same in `fact-check.md:50`. Two opposite policies for the same task class. The examples hang or behave predictably in different ways depending on which rule the reader applied. This is the single most consequential inconsistency in the skill.
  - Resolution: `opencode run --model` is non-interactive; without `--dangerously-skip-permissions` it cannot get approval for `webfetch`/`read` tool calls, so the model effectively can't go fetch sources. The examples in `code-review.md` and `fact-check.md` that drop the flag are likely **broken in practice** — the models will produce degraded no-tool output. Either: (a) pass `--dangerously-skip-permissions` for all read-only tasks (matching dispatch-mechanics.md:56) and update the two examples, or (b) document the read-only permission profile explicitly (which tools are auto-allowed without the flag), assuming one exists. Right now the code-review/fact-check examples appear to assume an interactive permission loop, which `opencode run` doesn't provide.
- **Specific GitHub issue numbers without verification.** `dispatch-mechanics.md:28` cites issue numbers `#6651, #11215, #17595, #26925, #29984, #32730` and "one open PR (#29447)" for the missing `model` field on `task` tool. These are extremely specific references. If they're fabricated (common LLM failure mode), quoting them in the skill makes the skill's provenance claims look false. Even if real, they break on rename/repo move. Replace with prose: *"multiple open feature requests exist to allow dynamic per-call `model` selection on the `task` tool; not yet released as of 2026-06"* (drop the specific numbers), and link to a GitHub search instead.
- **Mechanism 3 "known bug" link (`dispatch-mechanics.md:75`)** likewise cites issue `#18615`. Same fragility. Either pin the date and remove the slug, or remove the bug entry (it may have been fixed).
- **`opencode run --title` flag (`dispatch-mechanics.md:44`, `:24-29`, code-review.md:36, fact-check.md:42)** — unverified that this flag exists on `opencode-ai run`. If the script is being run by humans, an unrecognised flag silently fails or errors. Either verify and link to docs, or drop it.

**What is unclear or ambiguous**
- Mechanism 1 says "pre-define one subagent_type per model". With 10 models, that's 10 stale config entries that must be hand-maintained as provider models change. Is there a generator? Not addressed.
- "Per-model output capture" (`dispatch-mechanics.md:106-112`) says "always check the model's CWD for stray `*.md` files after a dispatch." But Mechanism 2 spawns a *subprocess* with its own CWD — which CWD is the model's? The dispatcher's? `$OUT`? A temp scratch dir? How do you "always check"? The fix line `fix: copy the stray file to the output dir` is under-specified.

### 1.4 `rules/consolidation-rules.md` — dedup, conflict resolution, scoring aggregation

**What works well**
- The named-rule library (`most-severe`, `majority`, `majority-with-uncertain`, `lowest-of-majors`, `longest-with-quote`, `concatenate-all`, `all-collected`, `union-dedup`, `merge-exact`) is the genuine value-add: each has algorithm, input shape, edge case. `consolidation-rules.md:165-221`.
- The aliases section (`:325-333`) correctly defers to per-recipe alias maps and documents the default normalizer.

**What is missing or wrong**
- **`most-severe` index convention is explanation-heavy and brittle.** `consolidation-rules.md:170-172` spends two paragraphs explaining that "most-severe first" means `min()` on `severity_order.index`. The risk: any reversal silently breaks. Safer convention: `severity_rank = {blocker: 1, major: 2, minor: 3, nit: 4}` (higher = worse), pick `max(severity_rank.values_seen)`. The current "most-severe first, index 0, min()" inversion is the cause of the lengthy explanation; a normal-orientation rule would eliminate the explanation entirely and remove the trap.
- **`majority-with-uncertain` rule returns `unverified`** but `consolidation-rules.md:185` then says *"Do NOT change the rule's return value to match the schema — change the schema to match the rule."* That's a strong prescription, but it intersects badly with: fact-check examples use `verdict_uncertain_value` remap support that is *mentioned* in the same paragraph but never shown as a JSON schema field. Where does `verdict_uncertain_value` go in `conflict_resolution`? Undocumented field shape.
- **`all-collected`** (`consolidation-rules.md:205-209`) returns `List of {model, value}` objects, but `output-schema.md:53-63` renders consolidated rows as a markdown table. How does a `{model, value}` list get rendered into a single text cell? There's no rendering rule. Either JSON-stringify, or render as a sub-table, or per-model bullets — none specified.
- **`consolidation-rules.md:147`** ("Decoupling Phase 3.x labelling"). Already covered in §1.2.
- **Skip rules section (`:115-121`)** says "Task-type-specific skip entries belong in the alias map for that task's recipe, not in the core rules" — yet the prior-art recipe (`research-prior-art.md:144-148`) has its own "Skip rules" section that lists "the reference item itself (Silver Bullet)" but does not place that into the alias map. The recipe ignores the core-rules' instruction. Either update the instruction or update the recipe.
- **`consolidation-rules.md:130` fuzzy match threshold "≥80% similar (Levenshtein or token-overlap)"** — two very different algorithms. Token-overlap (Jaccard) and Levenshtein give different verdicts for the same two strings, especially for short titles. Specify which (and the tokenization).
- **Phase 3 line 116 (`fields_per_model`)** — used here but never referenced by `output-schema.md` or the per-row template. Dead artefact? Or implicitly the data feeding the per-model notes column?

**What is unclear or ambiguous**
- "In order: 1) Quoted primary source wins. 2) Newer `last_verified` wins…" (`consolidation-rules.md:157-161`) — these are *in order*, but in what sense — early-exit cascade, or each as a tie-break after the previous? Declare a cascade semantics, e.g., "Apply 1; if still tied, apply 2; etc."
- "Newer `last_verified`" (`:159`) — but `last_verified` is a per-row field which models may not produce uniformly. If 3 of 6 models omit `last_verified` for an item, the newer-wins step has no data. What's the fallback? Untreated.

### 1.5 `rules/output-schema.md`

**What works well**
- Plain §1-§8 + 2 Appendix structure for the default report. Sections are reusable across task types (`output-schema.md:39-189`).
- Markdown formatting rules at `:231-242` are concrete and WYSIWYG-safe (code spans not bold-italic; blank lines around tables; no triple-asterisk; ASCII substitutions). These rules genuinely improve render quality and they exist nowhere else in the repo.

**What is missing or wrong**
- **`run-manifest.json` schema here (`:209-227`) omits fields methodology.md requires** — see §1.2. The two schemas disagree on:
  - `task_prompt_hash` (present in methodology, absent in output-schema)
  - `schema_auto_injected` (present in methodology, absent in output-schema)
  - `aliases` (present in methodology, absent in output-schema)
  - `phases_completed` (present in methodology, absent in output-schema)
  - `consolidation` block (present in methodology, absent in output-schema)
  methodologies.md asserts this file is canonical (`methodology.md:147`). Which one wins? This is the most concrete bug in the skill.
- `output-schema.md:53-63` template shows "| # | Item | Mentions | Fields per model | Primary Source | Top Finding |" but doesn't show the conflict-marker legend inline. The legend is described at `:71-75` ("place at top of section") as an instruction to the writer — not enforced in the template. Recipes vary on whether they include it; the prior-art example doesn't show the marker legend in `research-prior-art.md:155-167`. Drift.
- `output-schema.md:130-141` §5 Aggregated Scores — the table format is identical to one in `:296-299` of consolidation-rules.md. Fine, but no cross-link.
- `output-schema.md:161-165` §8 Synthesized Verdict "optional" — but the prior-art recipe says §8 includes "where does SUBJECT sit in the landscape" (`research-prior-art.md:163`), implying it's always there for research. The "optional" qualifier squats awkwardly against recipe expectations. Either declare it always-present with task-typed content, or always-absent for tasks without a verdict ask.

**What is unclear or ambiguous**
- `thorough`-mode files `evidence-ledger.md` and `verification.md` are listed in `SKILL.md:171-172` as thorough-mode-only outputs — but `output-schema.md` has **no section** defining their structure. Where does their structure live? They're referenced 12 places and specified nowhere.
- "Conflict marker" at `:73` says `value*` = field conflict, then "use a code-span like `` `direct*` `` if your viewer is WYSIWYG-strict." So is the canonical marker `star-after-value` or code-span-with-star? Both cannot be canonical. Pick one.

### 1.6 `rules/examples/research-prior-art.md`

**What works well**
- Full worked dispatch script (`research-prior-art.md:13-33`) executable as-is (modulo the `--dangerously-skip-permissions` debate above).
- Schema JSON (`:72-100`) is concrete: every column typed, `,dedup_key` set, `conflict_resolution` populated. A user copy-pasting this will get a working run.
- Alias table (`:125-141`) is genuinely useful — 14 specific equivalences a real run discovered.

**What is missing or wrong**
- **No actual consolidated output reproduced or summarised** — the recipe says "see `docs/research-260624/SB_CONSOLIDATED_PRIOR_ART_REPORT.md`" (`:175`) and ends. A reader of the recipe shouldn't have to navigate elsewhere to see what a *good* consolidated output looks like. At minimum, paste a 5-row sample of the §2 Items Table here. Otherwise this recipe is "instructions to go elsewhere."
- **Skip-rules-vs-alias-map drift** (`:144-148`). The "Skip rules (research-specific)" section is parallel to the alias map, not inside it. This contradicts the core rule at `consolidation-rules.md:121` ("Task-type-specific skip entries belong in the alias map for that task's recipe"). Update the core rule, or move skip entries into the alias map as `aliases[n] = null` (which the dedup algorithm actually supports — `consolidation-rules.md:99`).
- **Folder-name date drift already noted** (`:171`). The recipe punts the run/folder date mismatch to `SKILL.md:244`. Two places to read about one fact.
- **Schema-no-auto-inject note** (`:173`): "the skill auto-injected it because `--no-auto-inject` was not passed." This is the only worked run of the skill — but the auto-injected schema *text* is never quoted. The user can't see what the model actually received. Use a code block at the end of this file showing: "the skill appended this exact block to every dispatch prompt" + the literal block.

**What is unclear or ambiguous**
- The recipe `code-review.md` and `fact-check.md` say "Not yet produced (deferred to v2.2.0)". So is this recipe the only worked example? If yes, the dossier of "examples" is really "1 example + 2 recipes." That's fine, but call it for what it is — otherwise users expect 3 worked examples.

### 1.7 `rules/examples/code-review.md`

**What works well**
- The schema JSON (`code-review.md:49-66`) demonstrates composite primary key correctly (`file` + `line` both `dedup_key: true`).
- The "Why the old `primary_key: 'file:line'` is wrong" note (`:70-72`) is genuinely educational.

**What is missing or wrong**
- **Same `--dangerously-skip-permissions` contradiction** documented in §1.3.
- **Schema missing `evidence` rule in `conflict_resolution`.** The Custom strategies table at `:97` says `evidence` should use `concatenate-all`. The schema's `conflict_resolution` block (`:61-65`) only declares `severity` and `category` — no `evidence` entry. The default for `text` (which `evidence` is — `type: text`) per `consolidation-rules.md:151` is `longest-with-quote`, not `concatenate-all`. So the recipe says one thing and the schema does another. Add `"evidence": "concatenate-all"` to the `conflict_resolution`.
- **Suggestion column has no rule either.** Same pattern — `text` default (`longest-with-quote`) is probably fine for `suggestion`? Or should it be `concatenate-all`? Undeclared.
- **No `description` rule.** Custom-strategies table at `:98` says use `longest-with-quote` — matches default, no schema entry needed, but it'd be clearer to declare it.
- **Schema example previews only 2 models dispatched** (`:33`) — yet `dispatch-mechanics.md:161` says "Minimum viable: 2 models from different families." Two-model code review produces dubious conflict resolution (majority can't work with 2 distinct values). Add a note that 3+ reviewers is recommended for `majority` rules.
- **No worked example** (`:111`). Documented at end as deferred.

**What is unclear or ambiguous**
- "Pre-commit hook (NOT currently supported as a built-in dispatch; requires custom runner)" (`:106`) — surfaces a use case and immediately says it doesn't work. Without a runner stub, this is aspirational noise.
- `§5 Per-Reviewer Statistics` and `§6 Coverage Gaps` (`:88-89`) are post-consolidation analyses that the skill core doesn't describe how to compute. Coverage Gaps especially would require knowing the code under review's full surface. Underspecified.

### 1.8 `rules/examples/fact-check.md`

**What works well**
- `verdict: "majority-with-uncertain"` + `confidence: "lowest-of-majors"` pairing is the right design for high-stakes verification (`fact-check.md:67-69`).
- Consensus requirements table at `:103-107` parameterizes the threshold as `max(2, ceil(N/2))`, which is the right derivation rule, and the worked examples (N=3→2, N=5→3, N=7→4) make it immediately usable.

**What is missing or wrong**
- **Same `--dangerously-skip-permissions` contradiction** (see §1.3).
- **3-model dispatch contradicts the "use 4-5" prose (`fact-check.md:37`).** The example dispatches only 3 models (`:38`), then a few lines later says "use 4-5 for fact-check; majority-with-uncertain needs N≥3." Three barely meets the floor; an example should reflect the recommended N. Pick 5.
- **`sources` field type `url_list` (`:62`)** — fine, but `fact-check.md:77` says *"sources: url_list is now formally defined in the schema spec (was a v2.1.0 gap)"* — this is **release-note leakage**, not documentation. Delete the parenthetical.
- **`fact-check.md:109`** *"'The "3+ models" rule in the original draft was a typo; the correct threshold is parameterized."* — also **release-note leakage**. A current reader doesn't know what "the original draft" refers to. Delete or migrate to a CHANGELOG.
- **`counter_evidence` field (`:64`) declared but no rule in `conflict_resolution`.** Default for `text` is `longest-with-quote`, but custom strategies table says `concatenate-all` (`:99`). Add the rule to the schema.
- **`evidence: "all-collected"` in custom strategies (`:98`)** — but `all-collected` returns `{model, value}` pairs (per `consolidation-rules.md:205-209`). A user reading the table will see this rule but the schema still uses default (not declared). Same drift as code-review.
- **No worked example** (`:113`).

**What is unclear or ambiguous**
- §5 "Source Quality" output (`:87`) — how is "primary vs secondary" classification decided? A model needs to declare it; no schema field captures it.
- §6 "Unverified Claims" (`:88`) — fine concept, but how do you separate "unverified" (verdict) from "needs human review" (action)? They're conflated in this section.

---

## §2. Score on the Skill's Own 8-Dimension Rubric

| Dimension | 0 | 1 | 2 | Score | Justification |
|---|---|---|---|---|---|
| Catalog of composable units | None | Informal roles | Machine-readable catalog | **1** | Named conflict-resolution rules (`most-severe`, `majority-with-uncertain`, …) form an Informal roles-style catalog; models and dispatch mechanisms are role-named, but nothing machine-readable (e.g., a declarable registry with field-consumer API). |
| Dynamic composition | None | Replanner | Catalog-backed + audit log | **0** | Pure static dispatch — fixed `--models` set, no replanner can insert/drop models mid-run, no plan revision. |
| V-loop depth | None | End tests | Per-step rollup + intent gate | **1** | `phases_completed` and `modes_with-verification` give end-tests; `thorough` mode's verifier dispatch is the closest the skill gets to an intent gate, but it's per-item post-hoc not per-step rollup. |
| Enforcement | Honor system | CI only | IDE hooks + delivery blockers | **0** | The skill is invoked by the parent agent; failures land in `run-manifest.json` but nothing downstream is blocked by the manifest. Pure honor system. |
| Parent/worker split | No | Partial | Explicit orchestrator/worker | **2** | The calling agent = parent orchestrator; spawned `npx opencode-ai run` processes = workers; role separation is explicit and the manifest tracks who is who (`models_dispatched`, `models_failed`). |
| Evidence model | None | Informal | Tiered sufficiency + staleness | **2** | `prefer-with-evidence-then-newer-then-strict` *is* a tiered sufficiency rule; `last_verified` is staleness; `confidence_self` per-row + `lowest-of-majors` aggregate make a three-tier model. |
| SE + DevOps unified (re-interpreted for this skill as "covers both production task types") | One domain | Partial | Both in one model | **1** | Code-review + fact-check + research + ideation are all represented; nothing covers IaC/infra/DevOps drift/policy-as-code. Sample-by-task-type table at `consolidation-rules.md:299-308` is one-sided toward SE-style work. |
| Team customization | None | Fork required | Overlay packs | **1** | Task-type recipes live in `rules/examples/*.md` and alias maps in recipes. Adding a new task type = fork the recipes folder and edit (`research-prior-art.md:121-142`). No overlay mechanism to layer without forking. |
| | | | **Total** | **8 / 16** | Medium strength: orchestrator/evidence pillars are real; dynamic composition and enforcement are non-existent. |

---

## §3. Top 5 Improvements (ranked by impact × effort)

### 3.1 Reconcile `run-manifest.json` schema divergence
- **Issue:** `methodology.md:147-174` and `output-schema.md:209-227` give two different `run-manifest.json` schemas, and methodology.md declares output-schema.md canonical.
- **Why it matters:** A consumer author verifying a run wouldn't know which fields to expect; downstream tooling reading `aliases`, `phases_completed`, or `schema_auto_injected` would silently drop them when the leaner (canonical-claimed) schema is implemented.
- **Concrete change:** In `output-schema.md`, replace lines 209-227 with the methodology.md block. Add a one-line pointer *"Canonical — referenced from `methodology.md:147`."* Or: in `methodology.md:147`, change the canonical to be `methodology.md` itself and have `output-schema.md` say *"see `methodology.md` for the schema."* Either way, only one copy exists.
- **Effort:** low
- **Impact:** high
- **Score:** high

### 3.2 Fix `--dangerously-skip-permissions` policy contradiction
- **Issue:** `dispatch-mechanics.md:56` says pass the flag for read-only tasks; `code-review.md:45` and `fact-check.md:50` say don't pass it for read-only tasks. Both are stated as firm rules.
- **Why it matters:** Security and operability — if the dispatcher follows the examples, models spawned by `npx opencode-ai run` (non-interactive) cannot approve tool calls; they either produce degraded no-network output or hang. If they follow dispatch-mechanics, models get blanket permission which has its own risks.
- **Concrete change:** Update `code-review.md:33-39` and `fact-check.md:38-46` to include `--dangerously-skip-permissions \\` on its own line, with a one-line note in both: *"read-only permission grant verified safe for research/review/fact-check; see `dispatch-mechanics.md:56`."* Or, replace the single-line rule at `dispatch-mechanics.md:56` with: *"For non-interactive `npx opencode-ai run` dispatches of read-only tasks, `--dangerously-skip-permissions` is required because there is no shell to answer permission prompts."*
- **Effort:** low
- **Impact:** high
- **Score:** high

### 3.3 Define `evidence-ledger.md` and `verification.md` structures
- **Issue:** `SKILL.md:171-172`, `:82` advertise per-claim source URL + verdict outputs in thorough mode; `output-schema.md` has no section defining them.
- **Why it matters:** `thorough` mode is the headline feature that justifies the v2.x bump ("high-stakes, regulatory, due-diligence"), but its output structure is undefined. Implementers will guess.
- **Concrete change:** Add `## §9. evidence-ledger.md` and `## §10. verification.md` to `output-schema.md` after line 227. Templates:
  ```markdown
  ## evidence-ledger.md (thorough mode only)

  | evidence_id | claim_id | source_url | seen_at | verdict | model |
  |---|---|---|---|---|---|
  | e1 | c1 | https://... | 2026-06-27T08:00Z | supports | minimax-m3 |

  ## verification.md (thorough mode only)

  | item | claim | verified_by | source_url | verdict | source_verified | notes |
  |---|---|---|---|---|---|---|
  | LangGraph | "has V-model rollup" | deepseek-v4-pro | https://github.com/langchain-ai/langgraph | true | true | inline source citation found |
  ```
- **Effort:** medium
- **Impact:** high
- **Score:** high

### 3.4 Reconcile thorough-mode verifier dispatch with "no retry" principle
- **Issue:** Skill core (`SKILL.md:29,230`; `methodology.md:19`; `dispatch-mechanics.md:118`) says "skills don't retry; that lives in the caller's runner." But `thorough` mode ("dispatches a verifier model to check", `SKILL.md:82`) implies the skill *does* dispatch additional models post-hoc.
- **Why it matters:** Either thorough mode is an exception to the no-retry rule (and should be declared as such) or the verifier is supposed to be invoked by the caller (and the SKILL.md description is misleading). A reader who implements the skill literally doesn't know where the verifier logic lives.
- **Concrete change:** In `SKILL.md:82`, change *"dispatch a verifier model to check the claimed source"* to *"the user/calling-agent dispatches one verifier model per canonical item — the skill documents this as the thorough-mode contract, not as a built-in skill operation; see `rules/methodology.md`"*. In `methodology.md:19`, add a paragraph after the no-retry statement: *"Exception: in `thorough` mode, verifier dispatches are part of the caller's runner; the skill provides the prompt and the source list to verify, but the actual `npx opencode-ai run --model <verifier> &` loop lives in the caller's shell wrapper, alongside retry logic."*
- **Effort:** low (mostly a clarification)
- **Impact:** medium-high
- **Score:** medium-high

### 3.5 Rename/split `structured.jsonl` to remove dual-role confusion
- **Issue:** `methodology.md:25` (Phase 2) writes per-(model,item) rows. `methodology.md:118` (Phase 3) appends consolidated records with `model: "_consolidated"` to the same file.
- **Why it matters:** A consumer tool sees a JSONL stream and can't deterministically classify rows without inspecting `model` on each row, and the sentinel `"_"` magic string is fragile (collisions with future model IDs unlikely but undocumented invariant).
- **Concrete change:** In `methodology.md` rename Phase 2 output to `structured-raw.jsonl` (line 25, 28) and Phase 3 output to `structured-consolidated.jsonl` (line 118). Update `SKILL.md:168` (file listing) and `output-schema.md:194-201` to match. Alternatively, add a `"phase": 2 | 3` to every row and keep the single file; either is fine but document which.
- **Effort:** low
- **Impact:** medium
- **Score:** medium-high

---

## §4. Open Questions

1. **Is there an actual implementation?** The skill is described as if a backing program carries out the 4 phases — `run-manifest.json` enums, conflict rules, evidence ledger — yet I don't see a `scripts/multi-ai-task.*` anywhere in the spec. Is the "skill" a procedure the calling agent is expected to *hand-execute* (read the rules, then perform each step in the conversation), or is there an implementation behind the frontmatter? This single question determines how seriously to take the "machine-readable catalog" claims.

2. **What's the actual permission profile of `opencode run --model`?** The `--dangerously-skip-permissions` flag is the make-or-break operational choice, and the skill declines to specify what `opencode run` auto-allows by default for read-only tasks (read tool? webfetch? ctx_fetch_and_index?). I'd want to know this before resolving the contradiction in §3.2.

3. **What is the intended surface for the implemented rule library?** The named rules (`most-severe`, `majority-with-uncertain`, etc.) are described *as algorithms in prose*, not in code. Are they supposed to be hand-applied by the consolidating agent, or implemented in a `lib/`? If hand-applied, the audit-semantics ("which rule applied" in `conflicts.md`) depend on the consolidating agent's literal reading of the rule; there's no guarantee of determinism. If implemented, where is the code?

4. **Audience.** Is this skill for a single orchestrator agent (the parent), for a team of interop-ing agents via agentmemory mesh sync, or for both? The `snippet` about `run-manifest.json → aliases` filed on disk implies one orchestrator; the section about `task` tool subagent types implies one with multiple pre-defined subagent configs. Multi-agent team usage is undiscussed. Knowing the audience would resolve some recipe choices (e.g., whether the thorough-mode verifier is a separate peer in a mesh or a fresh subprocess).

5. **Mode of provenance test.** The "round-2 self-review" run (`SKILL.md:248`) is referenced but its content/verdict is not summarised. What did round-2 find that round-1 didn't? Without a summary I can't tell if the skill has been seriously critiqued before, or if this is the first such pass and prior self-reviews were shallow.

6. **Cost-bounding policy.** Thorough mode is `~N_items × 1 verifier call` (`SKILL.md:84`). With 10K items, that's 10K dispatches. Is there a sampling strategy (verify the top-K most-cited items only)? None documented. Knowing the intended upper bound would shape the evidence-ledger schema (e.g., a `verifier_sampled` field).

---

## §5. Confidence

- **Overall confidence:** *medium-high*
- **What would change my assessment:** Verifying (a) whether `opencode run --model` actually supports `--title` and what the default permission profile is (would resolve §3.2 with certainty); (b) whether the GitHub issue/PoR numbers in `dispatch-mechanics.md:28,75` are real (would downgrade the dispatch mechanics' credibility if fabricated); (c) reading the prior round-2 self-review (`SKILL.md:248`) to see if any of these findings have been raised-and-rejected vs raised-and-deferred-vs novel. If the prior self-reviews already covered these and they were accepted as "by design," scoring would need re-baselining — but on the documents presented, they read as outright bugs.
