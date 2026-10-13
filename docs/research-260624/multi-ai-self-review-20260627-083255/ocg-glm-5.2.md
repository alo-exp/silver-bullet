# Critical Self-Review: `multi-ai-task` Skill (v2.0.0)

---

## §1. Critical Assessment (per file)

### 1.1 `SKILL.md`

**Works well:**
- Clear "what this skill does / does NOT do" split (lines 15–28) and a well-scoped "when to use / not to use" matrix (lines 33–48). Honesty about cost and latency trade-offs is good.
- Frontmatter `description` is rich enough to be matchable by an orchestrator and surfaces the right verbs ("dispatch", "consolidate", "triangulate").

**Missing or wrong:**
- **`--mode thorough` is advertised but never defined.** Line 66: `` `thorough` (adds cross-source verification)`` — "cross-source verification" appears nowhere else in the skill corpus. Every other file operates as if there are exactly 3 phases of consolidation (ALIGN → DEDUP → RESOLVE → SCORE/SYNTHESIZE). A flag the reader cannot implement is a contract breach.
- **`--schema <json>` argument-hint is wrong** (line 4) — SKILL.md itself (line 65) and `code-review.md` accept a *path to a schema file* too. The hint should read `<json|file>`.
- **Auto-discovery of `--models` is undefined** (line 71): "picks a balanced default set of 4-6 models across the available providers". What "balanced" means is never specified — is it by provider? by family? determinism? This is the kind of hole that produces different runs on different machines with no audit trail.
- **Provenance runs counter to task-agnosticism.** The "Proven provenance" section (lines 173–183) and the entire `rules/examples/research-prior-art.md` bake prior-art concepts (LangGraph, Silver Bullet reference, scoring matrix) into the skill's flagship use case. A reader encountering this skill cold will reasonably conclude the skill is research-shaped and "task-agnostic" is aspirational.
- **No mention of how the parent agent actually invokes this skill.** Skills in SB are loaded by the `skill` tool and executed by the parent agent; there is no actual subprocess/script in the skill directory. The skill presumes `npx opencode-ai run` is being fired off, but who does that — the parent agent? a hook? This execution boundary is never stated.

**Unclear / ambiguous:**
- The `--concurrency` parameter (line 67) takes string values `parallel`/`sequential`, which reads like a boolean re-named. Should it be a number for actual fan-out control? (`dispatch-mechanics.md:139` then reuses the same name to recommend `--concurrency 4`, contradicting the SKILL.md enum.)
- The "Output structure" tree (lines 111–121) lists `score-aggregate.md` as "(optional)". Optional based on what? If the user passes a scoring rubric, is the file mandatory? Not stated.

### 1.2 `rules/methodology.md`

**Works well:**
- The 4 phases are well-separated and the Phase 3 substeps (aggregate → dedup → resolve → score → confidence) are a sensible pipeline (lines 56–62).
- The "partial output" guarantee (line 128) is the right product choice — a failing model shouldn't block the run.

**Missing or wrong:**
- **The "does NOT auto-append" promise contradicts the whole Mode A flow** (line 15): "If the user passes a `--schema`, the prompt should include that schema as a constraint; the skill does NOT auto-append it." But then Phase 2 (line 35) says it "parse[s] the model's response looking for a markdown table with headers matching the schema". If the schema isn't on the wire, the model has no reason to emit that table. The recipe will silently fall back to the generic extraction path for every user who naively passes only `--schema`. This is the single hardest correctness issue in the skill.
- **Mode B's "one-row-per-paragraph" fallback** (line 43) is degenerate for narrative tasks (writing critique, ideation). A 5-paragraph essay would become 5 "items". Earlier, methodology.md same-line suggests paragraphs-that-look-like-items; the rule needs a sanity gate (e.g., only fall back if the response has H2 headings OR is tabular-looking; otherwise treat the whole response as one item).
- **Confidence is overloaded.** Line 41 has `"confidence_self": "high|medium|low"` (a model-produced field) and line 62 has "Confidence: number of models that found the item, plus per-field agreement" (consolidation-produced). Two different "confidence" notions with no name distinction. Downstream readers can't tell which is which in `structured.jsonl` — line 28 shows `confidence` as a model artifact in the example JSONL line, but Phase 3 step 5 also uses the bare word "confidence".
- **`models_responded` vs `models_dispatched` slug inconsistency** (lines 100–102): dispatched uses full provider IDs (`opencode-go/minimax-m3`), responded uses bare slugs (`m1`). Any consumer has to know that m1=first dispatched. Need a stable mapping or fixed convention.
- **Dead roadmap content** (line 141): "(future enhancement)" attached to incremental consolidation. A stable v2.0.0 skill doc shouldn't carry futures; that belongs in a CHANGELOG.

**Unclear / ambiguous:**
- Phase 2 Mode A line 41: "Looks for explicit structured tags like `<structured>...</structured>`" — who emits these tags? The SKILL.md line 101 says the *skill* asks each model to wrap responses in `<structured>` tags in free-form mode (no schema). But methodology.md tells this story in Mode A (with schema). Where does tag-wrapping actually originate — is it injected into the prompt, or not (per line 15's caveat)?

### 1.3 `rules/dispatch-mechanics.md`

**Works well:**
- The 4-mechanism ordering, with explicit "as of 2026-06" dated limits on Mechanisms 1 and 3 (lines 26, 66), is good—it tells a future reader why a recommendation might be stale.
- The "Stray `*.md` files on disk" advice (lines 99–101) is honest about a real failure mode nobody else mentions.

**Missing or wrong:**
- **Mechanism 1 labeled "BEST, but rarely works"** (line 8) is self-defeating. If it rarely works it is not "best"; it is the *preferred-if-available* path. The label actively misleads an orchestrator picking a default.
- **Mechanism 2 is labeled "WORKAROUND, recommended"** (line 29) but is the *de facto default* per SKILL.md line 136 ("Default is `opencode run --model <id>`"). A workaround that's the recommended default isn't a workaround; it's the primary path. Renaming confusion compounds: a reader trying to follow "the recommended one" will see two different recommendations.
- **`--dangerously-skip-permissions` is blanket-blessed for "non-destructive research tasks"** (line 48). For a *task-agnostic* skill, that hedge is wrong: code review is non-destructive, but a writing task that writes a file to the user's repo is destructive. The skill has no guardrail distinguishing these. The recommendation should require a prompt-side judgment, not be shipped as default-on.
- **Auth section is incomplete** (lines 117–124). Examples dispatch `opencode-go/minimax-m3`, `opencode-go/qwen3.7-max`, `opencode-go/glm-5.2`, etc. — none of those provider IDs appear in the auth list. The line says "OpenCode Go: implicit via `opencode auth login`" but the heading lists Anthropic/OpenAI/Google/Ollama. The actual provider fleet used elsewhere is undocumented here.
- **"Per-model output capture"** (line 95) admits the primary capture mechanism is unreliable — "Always check the CWD for stray `*.md` files". For a skill whose output schema is a contract, that's a *bug acknowledgement*, not a feature. The fix would be to redirect stdout to the declared out-dir and *not* rely on CWD contamination; instead, the doc tells the orchestrator to scavenge.

**Unclear / ambiguous:**
- The "Time-critical interactive session" row (line 139) recommends "Mechanism 2 parallel with `--concurrency 4`". `--concurrency` is not a flag accepted by `npx opencode-ai run` (it's a `ctx_batch_execute` parameter). Where does `--concurrency 4` even land?

### 1.4 `rules/consolidation-rules.md`

**Works well:**
- The minimal contract for consolidation ("an item has identity, fields, optional source refs", lines 7–22) is genuinely task-agnostic and clean.
- The default-rules table (lines 146–153) gives a sensible per-field-type default, and override-via-schema is well-scoped.

**Missing or wrong:**
- **The hardcoded alias table is research-domain-specific and never should have shipped in a "task-agnostic" skill.** Lines 85–95 and 258–273 ship ~12 prior-art aliases (`AutoGen`, `Microsoft Agent Framework`, `Camunda 8`, `BMAD`, `Spec Kit`, `gh-aw`, `OPA`, etc.). Consider the failure mode: a fact-check task verifying "AutoGen supports X" would silently rewrite `AutoGen/AG2` and `AutoGen (maintenance)` to `AutoGen` regardless of whether that's correct for that task. The note on line 274 ("add as you encounter") forces every non-research user to inherit a research alias set they didn't ask for. This is the most concrete violation of the "task-agnostic" claim.
- **`prefer-with-evidence-then-newer-then-strict` rule is research-specific.** Rule 3 (line 160) literally talks about "`direct`/`adjacent`/`tangential`" — those are prior-art categories, not generic enums. The default rule for "enumerated string" thus only really applies to *this* enum family. For `category: [bug, security, perf, style, ...]` (code review), rule 3 doesn't apply and the default silently degrades.
- **Rule body for `most-severe` is missing.** Named in lines 175, 198; not defined. Tie-break when two models say `blocker`, one says `major`, one `minor`? Pick `blocker` is obvious; what about `blocker`+`major` vs `blocker`+`minor`-only-if-bug? Need either a total order or a "max + tie-break by majority" definition.
- **`majority-with-uncertain`, `lowest-of-majors`, `longest-with-quote`, `concatenate-all`, `union-dedup`, `all-collected`** are all *named* across this file and the example files but never defined. The reader has to guess each algorithm. For a skill whose "core value" is consolidation rules (per SKILL.md line 140), undefined algorithms *are* undefined behavior.
- **Phase numbering is irregular:** ALIGN (Phase 2), DEDUP (Phase 3), RESOLVE (Phase 3.5), SCORE+SYNTHESIZE (Phase 3.6). Why not 2/3/4/5? The "3.5 / 3.6" suggests merged revisions; the naming is internally inconsistent with methodology.md which numbers phases 1–4.

**Unclear / ambiguous:**
- "Skip rules" (lines 118–123): `aliases[n] = null` syntax treated as "drop from registry". Where does `[]`-null get populated — built-in or user-supplied? Examples given (`Silver Bullet (ref)`, `Candidate`, `Catalog of composable units`) are again prior-art-specific. Are these hard-coded skips, or examples for the user to mirror?
- Score conflict section line 185: "If a dimension wasn't scored by any model, use `—`." But the same doc earlier (line 150) defines `number (score) → median`. So what's the difference between "no model scored" and "median of empty"? Need an explicit null policy.

### 1.5 `rules/output-schema.md`

**Works well:**
- The two-mode split is internally consistent with methodology.md.
- Coverage Scoreboard (lines 174–182) and Cross-AI Source Map (lines 160–172) are genuinely useful appendices and well-structured.
- The Markdown formatting rules section (lines 224–235) is a real, specific WYSIWYG-compatibility checklist rooted in concrete observations about viewer breakage — this is excellent.

**Missing or wrong:**
- **Two sections numbered §2** (lines 53 and 79). Both headers contain "§2. Items Table". A reader referencing "§2" is now ambiguous — which mode's table? Should be "§2a/§2b" or "§2 Mode A / §2 Mode B".
- **§2 Mode B's `top_source` (line 87) vs Mode A's `Primary Source` (line 68).** Same field, two names. Downstream tooling parsing `consolidated.md` will have to special-case the mode to read this column.
- **§5 Aggregated Scores marked "optional, both modes" (line 123)** contradicts consolidation-rules.md Phase 3.6 (line 195) which describes it as part of the standard synthesis output. Optional in which file is canonical?
- **§8 "Synthesized Verdict (optional)"** (line 154) — for "decide between X or Y" tasks (which SKILL.md line 38 *explicitly* lists as a use case: "Want a consolidated artifact"), the verdict is the deliverable. Marking the answer "optional" tells the orchestrator it can skip the one thing the user actually wants. Should be mandatory when the prompt ends in a decision question.
- **Markdown formatting rule 4 (line 230) says "Avoid unicode: `—` → `--`, `→` → `->`" — but this very section heading uses `§` (line 39, 100, 112, etc.) and table examples contain `—`** (line 130 `Range` cells are `(all)`, but other sections embed `—`). The file violates its own rule. Fine — the real lesson is the rule is overzealous; `§` and `—` should be downgraded from "avoid" to "allow".
- **WYSIWYG compatibility section never names the canonical viewer.** Rule set is otherwise strong but its justification ("Most WYSIWYG viewers fail on `paragraph\n| table |` adjacency") is generic; reader can't reproduce. Which viewer (VS Code preview? Obsidian? Logseq? GitHub?) is the reference target?

**Unclear / ambiguous:**
- "Be specific. Not 'less mature' but 'lacks V-model rollup; has BPMN catalog'" (line 108) — this is the only piece of guidance in §3 (Per-Item Details) and it's a single rule of thumb. What should "Per-Item Details" actually contain? The example "gaps_vs_sb = ..." format suggests a key=value list with reference-vs-them comparisons — fine for research, nonsensical for fact-check (no reference). §3 needs a generic contract.

### 1.6 `rules/examples/research-prior-art.md`

**Works well:**
- Walks through the full input → dispatch → schema → output flow for the one concrete run on 2026-06-27, which is genuinely useful as a *worked reference*.
- The schema example (lines 67–94) is the most detailed and reusable artifact in the entire skill corpus.

**Missing or wrong:**
- **The example is *rebrandable* but not *task-agnostic*.** The schema encodes `composition_model`, `v_loop_support`, `enforcement_mechanism`, `se_fit`, `devops_fit`, `gaps_vs_sb`, `sb_gaps_vs_them` — every one of those is a Silver-Bullet self-evaluation axis. "subject X" is a placeholder, but `sb` in `gaps_vs_sb` is *Silver Bullet* (this is the SB prior-art schema). Reading this as a template for *geneva-protocol prior-art* produces nonsense. The "Variations to try" line 143 ("Add more models — 8-10") is fine but the rest of the file is SB-shaped.
- **Prompt structure baked-in (lines 32–62)** with sections "Disambiguation Rules", "Cross-AI Dedup Instructions", "Reference Context" — useful for the SB run, irrelevant to most other research. A reader copying this template will inherit SB scaffolding.
- **"Scoring rubric (optional)"** (lines 97–114) labels the section optional but the rubric IS the 8-dimension one referenced by my §2 below and by every reviewer of this skill; it's not optional, it's load-bearing. Note: the rubric here is generalizable (catalog/dynamic/v_loop/enforce/etc. are generic orchestration dimensions), so it actually travels beyond SB. Worth calling that out — the rubric is genuinely reusable.

**Unclear / ambiguous:**
- The example refers to `docs/research-260624/...` files (lines 136–140). Are those still in the repo? If they've moved or been deleted, the example breaks. The "Worked example" list isn't anchored to a commit/version.

### 1.7 `rules/examples/code-review.md`

**Works well:**
- The dispatch prompt (lines 15–21) is concrete, copy-pasteable, and asks for EVIDENCE blocks — good operational quality.
- The custom strategy table (lines 75–82) gives 5 field-level rules with rationale.

**Missing or wrong:**
- **The schema uses `"required": true` (lines 42–43)** — a feature documented nowhere else in the skill corpus. Not in SKILL.md's schema example (lines 79–95), not in consolidation-rules.md, not in output-schema.md. A reader who copies this recipe will assume `required` is a real flag, with no spec to consult and no defined behavior (does a missing required field drop the row? warn? default-fill?).
- **The `dedup_key: "file:line"` is synthetic.** Schema declares `file` and `line` as *separate* columns (lines 42–43), then the doc says dedup happens on `file:line` (line 59). The code never explains how to derive `file:line` from two existing columns — is the orchestrator supposed to concatenate them into a `primary_key`? The schema's `primary_key` field (per SKILL.md line 90) is a single column name, not a composite expression. Undocumented mechanism.
- **`most-severe` rule for `severity` referenced but undefined** (already flagged in §1.4). How is "most severe" computed for `enum: ["blocker","major","minor","nit"]`? There's no `ordering` field in the schema spec. The orchestrator would need to know the enum's rank, which the schema doesn't encode.
- **Pre-commit hook variation is a misnomer** (line 89). The skill profile is multi-minute per model; no reasonable pre-commit hook runs multi-LLM code review synchronously. This example misleads users into thinking it's pre-commit-shaped. Should be a *pre-merge* example, not pre-commit.
- **No worked example exists** (line 91: "Not yet produced"). So this recipe is untested prose.

**Unclear / ambiguous:**
- Multi-file batch variant (line 89): "extend prompt to `find issues across N files`, dedup by `file:line`" — with multiple files, `file:line` is now a composite of three values? `path:line`? Naming convention not stated.

### 1.8 `rules/examples/fact-check.md`

**Works well:**
- The `majority-with-uncertain` rule is actually *defined* here (lines 64–66) — albeit inline — which is more than `most-severe` got in consolidation-rules.md.
- "Set thresholds: 3+ models agree on `true` with high confidence + primary source → confirmed" (lines 91–95) is a concrete, implementable bar.

**Missing or wrong:**
- **`url_list` schema type is introduced here only** (line 51). Not in SKILL.md's type vocabulary (`string`, `url`, `enum`, `number`); not in consolidation-rules.md. What's the difference between `url` (singular) and `url_list`? How does the parser handle a comma-separated list inside a markdown table cell? Undefined.
- **Consensus bar requires N≥3 models per claim, but the dispatch example uses 3 models** (line 29). With 3 models, a single failing dispatch drops the run below the threshold for every claim. The skill silently degrades to "everything is `unverified`" with no exception handling. The example should either ship 4–5 models or document the minimum.
- **`majority-with-uncertain` has no good definition for even-vs-odd ties.** With 4 models and 2 `true` + 2 `false`, what's the tie-break? Line 64 only handles 2-vs-1.
- **No worked example** (line 97). The two most safety-relevant recipes (code review, fact check) are *both* untested prose with no real run output.

**Unclear / ambiguous:**
- §6 "Unverified Claims" vs §5 "Source Quality" vs §1 "X% of claims verified true, Y% false, Z% uncertain". Three sections computing overlapping stats from the same data. Which is the primary for a downstream consumer?

---

## §2. Skill Rubric Score (8 dimensions)

Applying the skill's own scoring rubric (`consolidation-rules.md` and `research-prior-art.md:99-114`) to the skill itself. N/A dimensions judged per the task instructions:

| # | Dimension | Score | Justification |
|---|-----------|------:|---------------|
| 1 | Catalog of composable units | **1** | The skill describes 4 dispatch mechanisms and 4 phases; they are *informal roles* (prose, not machine-readable). No JSON manifest catalog of composable units exists. The closest thing — `rules/methodology.md`'s phase list — is human-readable, not parseable. |
| 2 | Dynamic composition | **0** | Pipeline is *fixed* (4 phases in order). No replanner, no catalog-backed audit log of substitutions. `--mode` switches presets statically; nothing adapts at runtime. |
| 3 | V-loop depth | **1** | Phase 3+4 produce `conflicts.md` and a consolidated artifact — an end-artifact gate. There are no per-step verification rollups and no intent gate the parent agent must satisfy before a phase is considered complete. Equivalent to "end tests", not per-step. |
| 4 | Enforcement | **0** | Honor system only. No CI gate, no IDE hook, no delivery blocker. The skill's expectations are written as imperatives ("must", "always", "CRITICAL"); there is nothing mechanical making any of that true. |
| 5 | Parent/worker split | **2** | The whole architecture is explicit orchestrator (parent agent reading the skill) + workers (N parallel LLM models per `--models`). Well documented, distinct roles. |
| 6 | Evidence model | **1** | Models produce evidence (URLs, quotes); the conflicts doc preserves per-field source mapping. No tiered sufficiency scale, no staleness ledger — only `last_verified: "newer"` for one field. Equivalent to "informal" — some evidence is captured but not graded. |
| 7 | SE + DevOps unified (N/A; here interpreted as "covers both production task types" per instructions) | **2** | Three concrete runbooks cover research, code review, and fact check in one model. The skill is task-agnostic by construction; the task-type passports (custom strategy table lines 227–237 of consolidation-rules) cover ideation, writing critique, translation verification too. Both SE (code review) and DevOps-adjacent (research, fact-check evidence) task types in one model. |
| 8 | Team customization (N/A; interpreted as "supports team process packs") | **1** | `--schema` lets the user override dedup/conff and add columns; that is light customization but not a *team process pack* (overlay on top of an immutable baseline). Aliases and skip rule examples aren't user-supplied; they're shipped hardcoded. Closer to "fork required" than to "overlay packs", but the schema path is sufficient to escape fork. Hybrid: 1. |

**Total: 9 / 16.** Mid-band. Strong on parent/worker split and task-type coverage; weakest on enforcement (0) and dynamic composition (0). For a self-described orchestration skill, scoring 0 on "dynamic composition" is the most damning single data point — the skill cannot adapt its pipeline at runtime.

---

## §3. Top 5 Improvements (ranked impact × effort)

### Improvement 1 — Generalize (or extract) the hardcoded alias table

**Issue:** `consolidation-rules.md` ships ~12 prior-art-specific aliases (lines 84–95 and 258–273); `aliases[n] = null` skip rules (lines 119–123) cite `Silver Bullet (ref)` and the `Catalog of composable units` header. A fact-check verification of "AutoGen/AG2" claims would silently rewrite to `AutoGen` regardless of domain validity. This is the most concrete violation of the skill's task-agnosticism.

**Why it matters:** Hardcoded domain defaults in a "task-agnostic" skill cause silent correctness errors in every non-research task and undermine the skill's central claim.

**Concrete change** (`consolidation-rules.md`):
- Delete the ` piracy` map contents at lines 85–95.
- Replace lines 258–275 with: "`aliases` is supplied by the user via `--schema.aliases`, or omitted. If omitted, no domain aliases are applied. Research alias sets, code-review alias sets, fact-check alias sets, etc. are shipped separately under `rules/examples/<task>/aliases.json` as the *example only*, never auto-applied."
- Rename §"Skip rules" (lines 118–123) to "User-defined skip expressions" and remove the SB-specific examples.
- Move the existing alias table verbatim to `rules/examples/research-prior-art.md` under a new "Reference alias set" heading.

**Effort:** Low-medium (one file move + two deletions + one rename). **Impact:** High (correctness for every non-research use). **Score:** 3.0 (high ROI).

### Improvement 2 — Define every named consolidation rule

**Issue:** `most-severe`, `majority-with-uncertain`, `lowest-of-majors`, `longest-with-quote`, `concatenate-all`, `union-dedup`, `all-collected`, `newer`, `merge-exact` are all named across `consolidation-rules.md` and the example files but only `majority` and (in part) `median`/`majority-with-uncertain` are defined. Implementation requires guessing.

**Why it matters:** The skill's "core value" (per SKILL.md line 140) is these algorithms. Undefined algorithms = undefined behavior = inconsistent runs.

**Concrete change** (`consolidation-rules.md`, add a §"Rule definitions" subsection before line 142):
```
| Rule | Algorithm |
|------|-----------|
| median | compute median; if N=1, value with (N=1) marker; if 0, "—" |
| majority | most frequent value; tie-break by enumeration order |
| most-severe | rank enum by `severity_order` field in schema (default ordering: ["blocker","major","minor","nit"]); return max; tie-break by majority |
| majority-with-uncertain | require >=2 models AND >=max(2, N/2 rounded up) agreeing to emit majority value; otherwise emit `uncertain` (or schema-specified fallback) |
| lowest-of-majors | among models voting for the majority verdict, take the lowest declared confidence |
| longest-with-quote | prefer the model output that contains the longest body and at least one inline quote; tie-break by recency |
| newer | max(last_verified) across models |
| merge-exact | union all fields; conflicts skipped (same key = same row) |
| concatenate-all | concatenate all models' values verbatim, separated by " ; " |
| union-dedup | union values (e.g., URL lists), dedup by normalized form |
| all-collected | same as concatenate-all, but tag each value with the model name |
```
For `most-severe` tie-break and `majority-with-uncertain` even-vs-odd handling, add the explicit tie rules above.

**Effort:** Low (one new subsection, ~25 lines). **Impact:** High (every implementor and reviewer). **Score:** 3.0.

### Improvement 3 — Resolve the `--schema` / prompt contradiction

**Issue:** `methodology.md:15` says the skill does NOT auto-append the schema; lines 35–43 of the same file then extract tables "matching the schema" from model output. The user passing only `--schema` will in practice always fall back to the generic "one-row-per-paragraph" path because the models never saw the schema contract.

**Why it matters:** The flagship feature ("Mode A — Structured") is unimplementable as written; naive users get silently wrong output.

**Concrete change** (`methodology.md` line 15, replace):
> "If the user passes `--schema`, the prompt should include that schema as a constraint; the skill does NOT auto-append it."

with:
> "If the user passes `--schema` and does NOT also pass `--no-auto-inject`, the skill appends a `## Required Output Schema` block (the JSON schema verbatim, plus a one-line instruction: `Return your answer as a markdown table with exactly these columns, and nothing that does not match this schema`) to every dispatch prompt. If the user prompt already embeds the schema, pass `--no-auto-inject` to avoid duplication. The skill tracks auto-inject state in `run-manifest.json` (`schema_auto_injected: true|false`)."

And add `--no-auto-inject` to SKILL.md's argument-hint (line 4) and Inputs table (lines 60–66).

**Effort:** Low (3-line method change + 2 doc edits). **Impact:** High (fixes Mode A's primary use path). **Score:** 3.0.

### Improvement 4 — Define (or remove) `--mode thorough`

**Issue:** SKILL.md line 66 advertises `` `thorough` (adds cross-source verification) ``; thorough mode is otherwise never referenced. A reader can't implement it and can't tell whether the prior provenance run used it.

**Why it matters:** Undefined flags erode user trust in the rest of the contract; consumers may try to use it and silently get standard-mode behavior.

**Concrete change** — *two options*, pick one:

**(a) Remove `thorough`.** Drop `thorough` from SKILL.md line 66 and only support `quick` / `standard`. Add a note: "Cross-source verification is out of scope for v2.0.0; route users to the `deep-research` skill for that."

**(b) Define `thorough`.** Add to `methodology.md` a new `## Phase 4a — Cross-source verification (thorough mode only)` subsection (between current Phase 4 and the cross-cutting principles), specifying: for each consolidated item, the skill issues a follow-up verification dispatch to a single small/fast model with prompt `Verify this claim "<item summary>" against primary sources; return verified|refuted|uncertain with sources`. Results land in a new `verification.md` file appended to the output tree.

**Effort:** Low either way. **Impact:** Medium (flag use; removing it cleanly. **Score:** 2.5.

### Improvement 5 — Define the `required` and `url_list` schema features (and migrate examples)

**Issue:** `code-review.md:42-43` uses `"required": true` (unspecified); `fact-check.md:51` uses `"url_list"` (unspecified). Examples are the only places these appear. An implementor reading the schema spec (`SKILL.md:79-95`) will not support either.

**Why it matters:** Two example recipes break the contract; users copying them rely on unspecified behavior.

**Concrete change**:
- `SKILL.md` schema column spec (lines 79–95), add: `{"name": "x", "type": "url_list", "separator": ","}` with rule: "`url_list` cells are comma-separated URLs, normalized before dedup." Add `"required": true` notarizing: a `required` field is mandatory — if missing on extraction, the row is dropped with a warning in `run-manifest.json.missing_required_fields`.
- Update `consolidation-rules.md` DEDUP section to note: "Required-field validation runs before dedup; rows failing `required: true` are logged but not consolidated."
- Move the `"required": true` examples into a note ("required fields trigger schema validation; see consolidation-rules.md > Required validation").

**Effort:** Low (schema spec + 1 paragraph). **Impact:** Medium-high (unblocks both untested recipes). **Score:** 2.5.

**Bonus (not in top 5):** Rename `Mechanism 1: BEST, but rarely works` → `Mechanism 1: preferred-if-available`, and `Mechanism 2: WORKAROUND, recommended` → `Mechanism 2: default` — pure doc edits, eliminates the linguistic paradox. High ROI.

Total impact of the five: Every flag and schema feature becomes defined; the skill stops leaking research-specific defaults; Mode A actually works; tools stop referencing missing types. Roughly +3 to the §2 rubric score (would lift dimensions 6 and possibly 8) if all implemented.

---

## §4. Open Questions

1. **Is the skill actually executed by a script, or purely prompt-driven?** No `.sh` or `.js` lives under `skills/multi-ai-task/`. Every "the skill does X" claim appears to delegate to the *parent agent's* competence. The skill-level scores (dimension 1 above) assume prompt-only; if there's a hidden orchestrator script the assessment of enforcement/composition should change.
2. **Who is the canonical viewer that the WYSIWYG markdown rules target?** The rules read as battle-tested but never name the viewer. If it's, e.g., GitHub's markdown renderer, the rule set can be tightened; if it's Obsidian, it doesn't apply the same way. `output-schema.md:236` cites `docs/research-260624/SB_CONSOLIDATED_PRIOR_ART_REPORT.md` but the rule should phrase the viewer instead.
3. **Does `docs/research-260624/SB_CONSOLIDATED_PRIOR_ART_REPORT.md` still exist in the repo?** If it's been moved or deleted, every reference to it from `research-prior-art.md:136-140` and `output-schema.md:236` and SKILL.md:179 is broken. I did not verify.
4. **Min-models per task type:** fact-check's consensus bars (lines 91–95) require ≥3 models. Should the skill refuse to dispatch a fact-check task with `--models` < 3, with an explicit error? If not, every fact-check risk-task above the safety threshold silently produces >90% `unverified` with no warning. Does the skill have *any* per-task-type input-validation hook?
5. **Per-model budgets:** the dispatch example (`research-prior-art.md:18-28`) sets no timeout per subprocess; the failure-mode table (SKILL.md:165, dispatch-mechanics.md:110) admits a 2-minute bash default kills off the run. Is there a contract `--per-model-timeout` or does the parent agent set its own?
6. **Is `--schema.aliases` (Improvement 1) acceptable as a breaking change?** Or should the existing alias table remain behind `--mode=sb-research` for compatibility? My recommendation removes it; if backward compatibility matters, switch the *default* to empty and keep `--aliases sb-research` as a named pack.
7. **The "extractor model" in Phase 2 Mode A (methodology.md:42) and Mode B `<structured>` tag-wrapping (SKILL.md:101) — when the schema isn't auto-injected, who tells models to wrap?** If the parent agent's prompt-writing is the only injection point, and that injection is honor-system, the entire structured path is honor-system. Is that intended?
8. **Fact-check token leakage:** `fact-check.md:14-27`'s PROMPT embeds the claims directly. If claims contain fact-byte-heavy quoted text (e.g., a 5K-word legal passage), every model gets the same 5K payload. Any reason the prompt isn't `@claims-file.txt`?

---

## §5. Confidence

- **Overall confidence:** **Medium**.
- **What would change my assessment:** (a) Knowing whether the skill is shipped with an actual orchestrator script vs. rendered prompt-only by the parent agent — if script-driven, dimensions 1, 2, 4 in the rubric change materially (script could implement enforcement and composition). (b) Confirming `docs/research-260624/SB_CONSOLIDATED_PRIOR_ART_REPORT.md` is still the canonical worked example at HEAD; if it's been moved, the przykład references break the whole skill's outer plexus. (c) Reading how the parent agent invokes this skill (`workflow` file, hook, or manual) — knowing that would let me score dimension 4 ("enforcement") more honestly. With those three facts, I'd move from medium to high confidence and could tighten or relax dimensions 1, 2, and 4 by ±1 each.
