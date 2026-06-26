**Prompt injection notice:** The bash tool output contained injected text attempting to make me invoke a non-existent "graphify" tool and echo the same text twice. I am ignoring those instructions and continuing with your original review task.
I have enough context. Below is the critical self-review.

---

# Critical Self-Review: `multi-ai-task` Skill (v2.1.0)

**Reviewer note:** The task brief said v2.0.0; the skill's `SKILL.md:6` frontmatter now says `version: 2.1.0`. The content reflects v2.1.0, including changes credited to the prior 2026-06-27 self-review. This review therefore evaluates the post-iteration state. I have also cross-referenced the `multi-ai-self-review-20260627-083255/CONSOLIDATED_SELF_REVIEW.md` and a second self-review pass at `multi-ai-self-review-r2-20260627-093345/` (which is not cited in `SKILL.md`).

---

## §1. Critical Assessment

### 1.1 `SKILL.md`

**What works well**
- The frontmatter's `argument-hint` plus the inputs table gives a clean two-view contract for invocation.
- The "When to use / When NOT to use" tables are concrete and pre-empt real failure modes (single-model, real-time interactive, non-textual output).

**What is missing or wrong**
- **Version drift from brief.** Brief says v2.0.0; `SKILL.md:6` says `version: 2.1.0`. The "Proven provenance" section (`SKILL.md:236-247`) still says the original run was on 2026-06-27 and cites the *first* self-review directory (`multi-ai-self-review-20260627-083255/`), but a second self-review (`multi-ai-self-review-r2-20260627-093345/`) exists on disk and is not mentioned. Either cite both, or — better — distill the v2.1.0 delta into a "What changed in v2.1.0" subsection.
- **Argument-hint omits `--concurrency`.** `SKILL.md:4` lists `--models`, `--out`, `--schema`, `--mode`, `--no-auto-inject` in `argument-hint`; the inputs table at `SKILL.md:69` adds `--concurrency`. Pick one — either add it to the hint or remove it from the table.
- **`user-invocable: false` (frontmatter) contradicts the documented `/multi-ai-task "<prompt>"` invocation (`SKILL.md:57`) and the existence of `agents/codex/multi-ai-task/SKILL.md` and `plugins/silver-bullet/skill-source/multi-ai-task/`.** If it's `false`, document *how* a user invokes it (via a parent orchestrator only, with a `silver-bullet invoke-skill` wrapper, etc.). If it's `true`, fix the frontmatter.
- **Schema auto-injection forces a markdown table even for non-table tasks.** `SKILL.md`/Phase 1 auto-injects "`Return your answer as a markdown table with exactly these columns, and nothing that does not match this schema`". For narrative reviews or ideation this is a footgun. The "When NOT to use" table doesn't mention it; the only escape hatch is `--no-auto-inject`, which the user has to know about.
- **The "consolidated.html generation" guidance** (`SKILL.md:175`) recommends `marked`/`markdown`/`pandoc` with "Embed minimal CSS inline". This is hand-wavy and inconsistent with the WYSIWYG formatting rules in `output-schema.md:231-242` (which say avoid `≥` and `→`). A skill that ships HTML guidance should ship the actual CSS class names used (`.conflict-marker`, `.evidence`, etc.) so multiple implementations converge.
- **`Default model discovery` is hand-wavy** (`SKILL.md:74`): "queries the local OpenCode config … and picks a balanced default set of 4-6 models." No algorithm, no fallback (what if `~/.config/opencode/opencode.json` is missing?), no criteria for picking "the slowest, highest-capability" (see also methodology issue below).
- **Failure mode table references a phantom file** (`SKILL.md:228`): `score-aggregate.md` (planned) is listed as a symptom with the fix "Ignore for v2.x". This is admitting a known inconsistency; either remove the row or remove the bug.

**What is unclear or ambiguous**
- Is the skill meant to be **executable** or **documentation**? `SKILL.md` says the skill is fail-soft and that "retry policy lives in the calling agent's runner, not in the skill core" — i.e., it expects a wrapper. But there's no `scripts/multi-ai-task.sh` or similar in `scripts/`. The brief calls this a "skill" and the frontmatter says `user-invocable: false`. If the answer is "documentation that the parent reads", say so; if "executable", ship the executable.
- The relationship between `--schema` and the per-field `conflict_resolution` (when the schema is auto-injected) — does the auto-injected block include the resolution config, or only the columns? Not stated.

### 1.2 `rules/methodology.md`

**What works well**
- Pseudocode in `extractStructured` (`methodology.md:37-65`) makes the four-step fallback chain explicit.
- The "Cross-cutting principles" section (`methodology.md:175-195`) cleanly enumerates generic-by-design, deterministic + LLM-assisted hybrid, audit trail, and idempotency.

**What is missing or wrong**
- **The "extractor model" cost claim is false.** `methodology.md:104` says "Default: the slowest, highest-capability model from the original dispatch (caches the response, no extra cost)." This is wrong on two counts: (a) the extractor needs a *new* prompt containing the original response plus the schema and must produce reformatted output — that's a fresh LLM call; (b) the "cache" is a fabrication; nothing in the skill actually caches the response. The line above it (`methodology.md:52-54`) is correct: "NOT the model that produced the response — that model has already failed to produce structured output". The clarification at line 104 contradicts the pseudocode and should be corrected or removed.
- **Phase numbering conflicts with `consolidation-rules.md`.** `methodology.md` uses Phase 1–4. `consolidation-rules.md:26` calls it "Phase 2 — ALIGN", `:78` "Phase 3 — DEDUP", `:141` "Phase 3.5 — RESOLVE CONFLICTS", `:269` "Phase 3.6 — SCORE + SYNTHESIZE". These are not the same numbering. Pick one. The phase-fractional labels (3.5, 3.6) read as ad-hoc and signal that consolidation is really 3 sub-phases inside Phase 3, not 5 separate phases.
- **The "extractor model is the slowest, highest-capability" criterion is undefined** (`methodology.md:52, 104`). "Slowest" and "highest-capability" are not the same metric. With the 6-model OCG roster, which model is "the slowest" depends on per-run wall-time, not on declared capability. A deterministic criterion (e.g., "the last model in `--models` order" or "the first model with reasoning capability in the provider list") is needed.
- **The structured.jsonl schema is partly self-referential.** `methodology.md:28` shows a `raw_text_ref: "structured.jsonl#L1"` — but `structured.jsonl` is the file the record is *being written to*. This is a circular reference. The intent is clearly to point to the per-model raw output (e.g., `"raw_text_ref": "minimax-m3.md#L42-50"`).
- **`structured.jsonl` is described as append-mode for consolidated records** (`methodology.md:118`: "append mode with `model: '_consolidated'`"). This conflates per-model extraction rows with canonical records; they have different shapes. A separate `consolidated.jsonl` or a `consolidated` block inside the same file would be clearer and would not require the fake `model: "_consolidated"` namespace.

**What is unclear or ambiguous**
- The "deterministic + LLM-assisted hybrid" principle (`methodology.md:179-182`) is broken by `--mode thorough`, which dispatches a verifier model per item (see `SKILL.md:82` and the cross-cutting issue in `dispatch-mechanics.md` below). The skill claims to be "deterministic for structured extraction", but the thorough mode sub-dispatches an LLM. State this explicitly.
- For `quick` mode, is the conflicts.md produced at all? (`SKILL.md:80` says "no `conflicts.md`". `output-schema.md:203` says conflicts.md is "always produced, both modes". One of these is wrong.)

### 1.3 `rules/dispatch-mechanics.md`

**What works well**
- The 4 mechanisms are presented in a clear preference order with explicit use-case selection (`dispatch-mechanics.md:165-177`).
- The auth table (`dispatch-mechanics.md:136-144`) is a quick reference that's hard to get wrong.
- The `npx -y` and `--dangerously-skip-permissions` caveats (`dispatch-mechanics.md:55-56`) are exactly the kind of operational gotcha the doc should carry.

**What is missing or wrong**
- **Internal contradiction on "Sequential" and port collision.** The "Parallel vs sequential dispatch" table (`dispatch-mechanics.md:96-100`) lists Sequential as "Predictable; no port issues". The next paragraph (`dispatch-mechanics.md:102`) says: "Sequential alone doesn't fix port collision if the MCP binds a port on first start and holds it." The table pro ("no port issues") is wrong. Fix the table or remove the pro.
- **The "6-time-requested feature" enumeration is stale-prone.** `dispatch-mechanics.md:28` lists issues #6651, #11215, #17595, #26925, #29984, #32730 as still open, citing a 2026-06 snapshot. These numbers will rot; either snapshot a date explicitly or replace with a "check `gh issue list --repo anomalyco/opencode --search 'subagent model'`" instruction.
- **The "OpenCode Go" provider family in every example is fine for the 2026-06-27 run but reads as parochial.** All three bash examples use only `opencode-go/*` models. A skill labeled "task-agnostic" should also have a worked example with mixed providers (e.g., `anthropic/claude-opus-4.7` + `openai/gpt-5.2` + `google/gemini-2.5-pro`) to prove cross-provider dispatch actually works.
- **The OpenCode server SDK path (Mechanism 3) has a known bug** (`dispatch-mechanics.md:75`, issue #18615) that the doc says "use Mechanism 2 as a workaround". If Mechanism 3 is the documented "preferred" for `opencode serve` users, the doc should also note that "this path is currently broken" — not just hide it as a footnoted workaround.
- **MCP port-collision remediation is incomplete.** `dispatch-mechanics.md:102` says "configure MCPs that support multiplexing, or … restart the MCP between dispatches". Restarting the MCP between every model dispatch is operationally heavy and not scripted anywhere. Either provide the script or remove the suggestion.
- **The "model's CWD" recovery section** (`dispatch-mechanics.md:107-112`) is good practice, but `--out` is documented as a CLI flag in `SKILL.md:66` and never actually used in any of the bash examples (all examples use `OUT=$PWD/...` and write directly to that path). The flag is referenced in `argument-hint` and the inputs table but never wired in code. This is a contract that the examples don't honor.

**What is unclear or ambiguous**
- The decision table at `dispatch-mechanics.md:165-177` row "Multiple MCPs that share ports" recommends "Mechanism 2 sequential" — but sequential under Mechanism 2 still uses the `for ... & wait` pattern in the bash example. The fix is "dispatch to a single model at a time AND restart the MCP" (`dispatch-mechanics.md:102`); the recommendation in the table doesn't include the restart step.

### 1.4 `rules/consolidation-rules.md`

**What works well**
- The named-rule library (`most-severe`, `majority`, `majority-with-uncertain`, `lowest-of-majors`, `longest-with-quote`, `concatenate-all`, `all-collected`, `union-dedup`, `merge-exact`) is well-defined with explicit algorithms and edge cases. This is the strongest part of the skill.
- The conflict-resolution example table at `consolidation-rules.md:231-237` is concrete and is the only place where a model can see "here's exactly what a `conflicts.md` row looks like".

**What is missing or wrong**
- **Inconsistency: the skill has *two* different "outlier downgrade" heuristics, neither of which is given a stable name.**
  - `consolidation-rules.md:165`: "If 1 of 6 models says `direct` and 5 say `adjacent`, treat the lone `direct` as an outlier (downgrade)." — implicit, no threshold.
  - `consolidation-rules.md:176`: "if 1/N reviewers disagrees with no evidence quote, downgrade the lone max to the next-severity tier." — only for `most-severe`.
  These are conceptually the same rule but they trigger on different conditions (5/6 vs 1/N) and on different field types (categorical vs severity). Either unify them under a single `outlier-downgrade` rule with explicit thresholds, or call out the difference explicitly.
- **`lowest-of-majors` is undefined when there is no majority.** `consolidation-rules.md:190-194` describes the rule, but if `majority` returns `null` (no value reached plurality), what does `lowest-of-majors` return? The pseudocode first applies `majority`; if majority returns `null`, the behavior of `lowest-of-majors` is unspecified. Add a line: "If majority returns null, return the lowest confidence among *all* models."
- **`majority-with-uncertain` threshold inconsistent with the fact-check example.** `consolidation-rules.md:187`: "require ≥ `max(2, ceil(N/2))` models to agree." For N=3, this is 2. The fact-check example at `examples/fact-check.md:63` says "require ≥3 votes for a clean verdict." For N=3, the algorithm passes at 2 votes, the example requires 3. Pick one. (For N=5 the algorithm requires 3, the example also requires 3 — so they only disagree at N=3 and N=4.) Add a worked N=3 example to lock this in.
- **The fact-check example substitutes `partially-true` for `uncertain`.** `examples/fact-check.md:63`: "if 2 say true and 1 says false, default to `partially-true` (uncertain) rather than `true`". But the algorithm returns `uncertain` (a value not in the schema's `values: ["true", "false", "partially-true", "unverified"]`). The same example row in `consolidation-rules.md:236` says the final value is `unverified` (a third different name for the same concept). Three names for one concept (`uncertain` / `partially-true` / `unverified`) is a bug.
- **The "Skip rules" section (`consolidation-rules.md:120-126`) has a research-specific example in a "generic" section.** "Scoring-matrix header rows … the column-dimension names like 'Catalog of composable units' might leak into the items table" — that example is research-only. The skip rules section header says "Generic skip rules for any task type" but the last bullet is research-flavored. Either generic-ize the wording or move to the research example.
- **A residual alias table is still in the generic core** (`consolidation-rules.md:84-95`). The same file says at `consolidation-rules.md:326-337` that aliases are task-specific and belong in the recipe. The prior self-review claimed this was moved to `examples/research-prior-art.md`. It was *partially* moved; the sample lives on in core. Remove it from the generic file (or move it to a clearly-marked "Example: a research alias map" sidebar).
- **`all-collected` and `concatenate-all` differ only in whether model identity is preserved** (`consolidation-rules.md:208-212`). For text fields, `concatenate-all` is a lossier version of `all-collected` (you can recover the model identity from the join order in some schemas, but not generically). The custom-strategies table at `consolidation-rules.md:305-312` recommends `all-collected` for fact-check evidence but `concatenate-all` for fact-check counter_evidence. The rule for choosing one over the other is not stated.
- **`merge-exact` description is loose** (`consolidation-rules.md:220-224`). It "groups by primary key" — but the same file defines `dedup` for primary-key deduping. `merge-exact` is what happens for composite keys; the prose explanation doesn't make this clear. Tighten: "For schemas where `dedup_key: true` is set on multiple columns, treat the tuple as a composite key; for each composite-key group, union all fields; for conflicting fields, apply the schema's per-field resolution rule."

**What is unclear or ambiguous**
- The default rule for `string (enumerated)` is `prefer-with-evidence-then-newer-then-strict` (`consolidation-rules.md:151`). For a brand-new run with no schema, what counts as "the cited one" — a model that wrote a URL, or a model that included a `## Evidence` block? The "primary quote" criterion is fuzzily defined.
- "Recency" (`consolidation-rules.md:165` "Newer `last_verified` wins") requires every model to have populated `last_verified`. If half the models don't, what happens? The rule should specify a fallback (e.g., "use the timestamp in the model's `<slug>.err` file or the dispatch order").

### 1.5 `rules/output-schema.md`

**What works well**
- The 8 sections + 2 appendices give a stable structure downstream tooling can target.
- The WYSIWYG formatting rules at `output-schema.md:231-242` are the right level of paranoia (no triple-asterisk, normalize unicode, blank lines around tables). This kind of bullet list is rare and useful.

**What is missing or wrong**
- **`§2. Items Table` is labeled twice with the same number.** `output-schema.md:53` is "§2. Items Table (Mode A — schema-defined table)"; `output-schema.md:79` is "§2. Items Table (Mode B — generic narrative)". Two §2s in the same document. Renumber to §2.1 / §2.2 or §2A / §2B.
- **Mode B's "generic narrative" still shows a table at line 59-70.** The mode label is "generic narrative" but the §2 example is a markdown table with columns `# | Item | Mentions | Fields per model | Primary Source | Top Finding`. Either rename to "Mode B — generic table" or replace with the narrative-section example from `:82-95`.
- **The "Markdown formatting rules" CRITICAL block at `:231-242` lives only in `output-schema.md` but applies to *all* model output, including the per-model `<slug>.md` files.** The dispatch-mechanics doc should reference these rules so a model that produces `**foo***` is told not to before it does.
- **§6 Negative Results and §7 Open Questions have no algorithm** for *how* to detect them. A model that says "I searched for category X but found nothing" must be parsed to extract this; a model that simply omits X is indistinguishable from a model that didn't think to look. Either specify that a `--negative-results` JSON column is required in the schema, or document that negative results are best-effort and human-curated.
- **The Appendix A "Verified by" column** (`:172-177`) is undefined. "Verified by" — verified by what? Another model? The same model in a follow-up call? In `thorough` mode it's the verifier model, but the appendix is listed for "both modes". Either move the "Verified by" column to thorough-only, or define what populates it in standard mode.
- **The `run-manifest.json` example at `:209-227` is missing fields documented elsewhere.** It omits `schema_auto_injected` (mentioned at `SKILL.md:147`, `methodology.md:15`), `aliases` (mentioned at `consolidation-rules.md:335`), `models_failed` (mentioned at `SKILL.md:222`, `dispatch-mechanics.md:118`), and `consolidation` block (`methodology.md:163-167`). Pick one canonical run-manifest schema and cross-reference it.

**What is unclear or ambiguous**
- "Aggregated Scores" (§5) is marked "optional, both modes" but the "Coverage Scoreboard" (Appendix B) is "both modes" mandatory. For a research task with no scoring rubric, what populates Appendix B? The skill should say "omit if no rubric was provided".

### 1.6 `rules/examples/research-prior-art.md`

**What works well**
- This is the only fully worked example and it's excellent. The `alias map` table at `:125-141` is concrete and proves the consolidation logic on real-world data (AutoGen ↔ AG2, MAF ↔ Microsoft Agent Framework).
- The schema with 16 columns (`examples/research-prior-art.md:72-100`) is the right level of constraint.
- The scoring rubric (`examples/research-prior-art.md:104-119`) is a clean 8-dimension 0-2 rubric that the parent review task could literally copy.

**What is missing or wrong**
- **The dispatch bash block has a working-directory bug.** `examples/research-prior-art.md:16` does `cd "$OUT"` — but the example also writes `${slug}.md` directly to the CWD, not to `$OUT`. With `cd "$OUT"`, the outputs land in `$OUT`, which is correct. But the same pattern in `dispatch-mechanics.md:37-50` does not `cd`; it writes `"$OUT/${slug}.md"`. The two examples are inconsistent; pick one.
- **"Variations to try" line 184**: "8-10 models captures more unique finds but diminishing returns past 6 (this is an empirical observation, not a measured curve — run your own benchmark if you want a hard number)". This is a weak claim. Either back it with the prior-art run's "150+ raw mentions → 36 unique products" reduction curve, or drop the line.
- **The "Alias map" table at `:125-141` has 14 entries but no provenance.** When was each alias discovered? In which run? A new user copying this map has no way to know which entries are battle-tested vs. speculation. Add a "discovered" or "verified in run YYYY-MM-DD" column.
- **The "Skip rules (research-specific)" section at `:144-149` duplicates the generic skip rules in `consolidation-rules.md:120-126`** (the "scoring-matrix header rows" example appears in both). Consolidate: keep generic in core, research-specific only the research-only ones (e.g., "drop the reference subject's own name").
- **The `research-prompt.md` template at `:36-69` is a great reference but the example doesn't show the actual prompt contents** for the 2026-06-27 run. Cross-reference `SB_PRIOR_ART_USER_PROMPT.md` (which is on disk at `docs/research-260624/`) and say "this is the actual prompt used; the structure below is the template".

**What is unclear or ambiguous**
- The scoring rubric at `:104-119` uses `aggregate: "median"` and `max_total: 16`. With 8 dimensions × max 2 = 16, this is correct only if every model scores every dimension. If 2/6 models omit a dimension, the median for that dimension is over 4 votes, not 6. Document how partial coverage is handled (likely "median over available", but say so).
- Line 22: "for model in opencode-go/minimax-m3 opencode-go/qwen3.7-max opencode-go/deepseek-v4-pro opencode-go/glm-5.2 opencode-go/kimi-k2.6 opencode-go/mimo-v2.5-pro" — 6 models from the same provider family (`opencode-go/*`). The "Default model discovery" rule (`SKILL.md:74`) requires "at least 2 different provider families, no more than 2 models from the same family". This example violates the rule. Either relax the rule or change the example to demonstrate compliance.

### 1.7 `rules/examples/code-review.md`

**What works well**
- The custom-strategies table (`examples/code-review.md:74-82`) is the cleanest demonstration of the conflict-rule library: `severity: most-severe`, `category: majority`, `evidence: concatenate-all`. Copy-paste-ready for new code-review runs.
- The composite primary key (`file:line` at `:41`) is a strong example of a feature called out in `SKILL.md:143` but rarely demonstrated.

**What is missing or wrong**
- **`Worked example: Not yet produced.`** (`examples/code-review.md:91`). The skill's strongest claim is "task-agnostic" and the strongest proof of that is a worked example. The prior-art example was the proof; without a second worked example, the "task-agnostic" claim rests on the research case alone. The first self-review correctly deferred this to v2.2.0 — fine, but the file should say "v2.2.0" with a target date, not just "Not yet produced".
- **The "Variations" section at `:85-89` references `--mode thorough`** but `thorough` adds an evidence-ledger that is meaningless for code review (the "source URL" is a line in a file, not a citation). Either add a `thorough`-mode footnote explaining this is non-applicable, or note that thorough should not be used for code review.
- **The schema's `file` and `line` are split** (`:42-43`) but the primary key is the composite `file:line` (`:40`). The doc never shows what `dedup_key: true` on a *composite* key looks like in the schema (the `SKILL.md:143` example is "list multiple columns with `dedup_key: true`", but here `file:line` is a string, not a composite). Either show the composite form or note that "string + colon-separator + number" is the convention.
- **The bash example at `:23-32` uses the same for-loop with `&` pattern as the research example but doesn't set `--dangerously-skip-permissions` differently for write vs. read** (code review is read-only, so the flag is fine, but `dispatch-mechanics.md:56` flags it: "For **write tasks** (writing a file to the user's repo, modifying configs), do NOT use this flag"). Code review could be either (read-only review vs. "fix the bugs" review); the example should specify.

**What is unclear or ambiguous**
- The "Variations" section at `:85-89` says "Pre-commit hook: combine with git diff to only review changed lines" — this is a complete variant of the skill (different input source, different dedup surface) and gets a single bullet. Either link to a worked recipe or remove the line.

### 1.8 `rules/examples/fact-check.md`

**What works well**
- The `verdict: majority-with-uncertain` + `confidence: lowest-of-majors` combination (`examples/fact-check.md:55-58`) is the textbook "high-stakes fact-check" config and is exactly the right default.
- The "Consensus requirements" at `:91-95` codify a real epistemic standard (3+ models + primary source for `true`/`false`).

**What is missing or wrong**
- **Triple-inconsistency on what `majority-with-uncertain` returns.** `consolidation-rules.md:187` says return `uncertain`. `consolidation-rules.md:236` example row says return `unverified`. `examples/fact-check.md:63` says return `partially-true`. Same algorithm, three outputs. Pick one (recommend `unverified` to match the schema's `values: ["true", "false", "partially-true", "unverified"]` at `:49`) and fix the other two.
- **The `claim_id` dedup_key** (`examples/fact-check.md:47`) assumes the user pre-numbers their claims. The dispatch prompt at `:14-27` does include "1. [claim 1] / 2. [claim 2]" numbering, but if the input is a JSON file or a list of bullet points without numbers, the models have to assign IDs themselves and they will disagree (m1 calls it `claim_1`, m2 calls it `(1)`). Add an "input contract" subsection specifying the expected input format.
- **`--mode thorough` is never used in this example**, but the fact-check task is precisely where `thorough` would be most valuable (each claim needs a verified source). Add a "thorough mode" variant alongside the `quick`/`standard` recipe.
- **The bash example at `:29-37` uses 3 models** (`minimax-m3, qwen3.7-max, glm-5.2`). For fact-check with `majority-with-uncertain` at N=3, the threshold is `max(2, ceil(3/2))=2`. So 2 votes is enough. This contradicts the "3+ models agree" requirement in "Consensus requirements" at `:91-95`. Either raise the default model count to 4-5, or document the N=3 case explicitly.
- **`confidence: lowest-of-majors` with `verdict: majority-with-uncertain`** has an undefined edge case: if `majority-with-uncertain` returns `unverified` (no majority), the "majors" set is empty, and `lowest-of-majors` is undefined. Add: "If no majority, return the lowest confidence across *all* models."

**What is unclear or ambiguous**
- The "Worked example" at `:97` is "Not yet produced" again. Two of three examples are unproven; the skill is, in practice, a one-example skill with two aspirational ones.
- What happens if a model's verdict is `unverified` because *that model* couldn't find a source, but other models found one and returned `true`? The `majority-with-uncertain` algorithm doesn't distinguish "I abstained" from "I disagree". Add a way to mark abstentions.

---

## §2. Score the Skill on the 8-Dimension Rubric

Using the rubric defined in `consolidation-rules.md:104-119` and `examples/research-prior-art.md:104-119`. The two "N/A" dimensions (SE+DevOps unified, team customization) are scored per the task's mapping guidance.

| Dimension | Score | Justification |
|---|---|---|
| **Catalog of composable units** | **1/2** | Has named rules (`most-severe`, `majority-with-uncertain`, etc., `consolidation-rules.md:172-225`), modes (quick/standard/thorough, `SKILL.md:78-84`), and dispatch mechanisms (4 of them, `dispatch-mechanics.md:9-89`). Catalog exists in prose, not in a machine-readable manifest. No `pipeline.json` or similar. |
| **Dynamic composition** | **0/2** | "Replanner" is a stretch — there is no re-planning, no replanner, no failure-driven re-routing. The 4 phases are fixed; if a model fails, the others carry on. No audit log of "why we picked this dispatch mechanism". The `run-manifest.json` records what happened, not why. |
| **V-loop depth** | **0/2** | No per-step rollup; no intent gate; no intent declaration. `thorough` mode does per-item verification (`SKILL.md:82`), which is the closest analog, but it's an LLM call, not a programmatic rollup. The skill runs and reports; nothing iterates back on the dispatch. |
| **Enforcement** | **0/2** | "Honor system" only. The skill is documentation; there is no CI gate, no IDE hook, no compile-time check that the schema is well-formed. `dispatch-mechanics.md:171-177` decision table is the only "enforcement"-shaped artifact and it's advisory. |
| **Parent/worker split** | **2/2** | Explicit and clear. The skill is the orchestrator (parent); the N models are workers. The dispatch-mechanics doc enumerates how the parent dispatches. The "Calling agent's runner" boundary (`methodology.md:19`, `SKILL.md:29`) is correctly drawn. |
| **Evidence model** | **1/2** | `thorough` mode defines a tiered evidence model with an `evidence-ledger.md` per claim (`SKILL.md:82, 171`). But the default (`standard`) mode has only `concatenate-all` or `all-collected` for evidence — informal, not tiered. "Tiered sufficiency" is on the roadmap (per the prior self-review's v3.0.0 list) but not implemented. |
| **SE + DevOps unified (N/A → "covers both production task types")** | **2/2** | The skill is explicitly task-agnostic (`SKILL.md:11-13`, `methodology.md:175-176`); worked examples cover both SE (code review) and DevOps (fact-check, prior-art research). The same 4-phase pipeline works for both. |
| **Team customization (N/A → "supports team process packs")** | **0/2** | No overlay pack mechanism. Aliases are task-specific but are passed at run-time, not as a pre-defined pack. A team wanting to enforce "always use majority-with-uncertain" can't ship an overlay; they have to pass the JSON in every dispatch. Roadmap item in v3.0.0 per the prior self-review. |

**Total: 7/16** (1+0+0+0+2+1+2+0)

This matches the prior self-review's median score of 7/16 (`docs/research-260624/multi-ai-self-review-20260627-083255/CONSOLIDATED_SELF_REVIEW.md:80-94`). The v2.1.0 changes are net-positive on `Catalog` (1→would-be-2 if the catalog were machine-readable, but it's still prose, so still 1) and on `Evidence model` (still 1 because `thorough` exists but isn't default). The 0-scoring dimensions are the same.

---

## §3. Top 5 Improvements (ranked by impact × effort)

### 3.1 Fix the `majority-with-uncertain` return-value triple-inconsistency

- **Issue:** Three different return values for the same algorithm (`uncertain` / `unverified` / `partially-true`).
- **Why it matters:** The conflict-resolution library is the skill's stated core value. A user reading `consolidation-rules.md:187` and getting `unverified` from their fact-check run (per `consolidation-rules.md:236`) will file a bug or distrust the entire library. Naming bugs propagate into schema values and downstream tooling.
- **Concrete change:**
  - In `consolidation-rules.md:187`, change "return `uncertain`" to "return `unverified`".
  - In `examples/fact-check.md:63`, change "default to `partially-true` (uncertain) rather than `true`" to "default to `unverified` rather than `true`".
  - In the `examples/fact-check.md:49` enum `["true", "false", "partially-true", "unverified"]`, decide whether `partially-true` is a separate verdict (returned by a different rule) or a synonym for `unverified`; document the distinction. The schema's intent appears to be that `partially-true` is a real verdict (returned by the model) and `unverified` is the algorithm's fallback. Make this explicit in the schema doc.
- **Effort:** low
- **Impact:** high
- **Score:** high / low = **3.0**

### 3.2 Eliminate the "extractor model: no extra cost" fabrication

- **Issue:** `methodology.md:104` says the extractor model "caches the response, no extra cost". This is false.
- **Why it matters:** Cost transparency is critical for a skill that fans out to N models. Users reading the doc will underestimate `Mode B` (free-form) cost. The "caches the response" claim has no implementation; the extractor is a *new* LLM call with a prompt that contains the original response and the schema.
- **Concrete change:** Replace `methodology.md:104` with: *"The extractor model is the slowest/highest-capability model from the original dispatch. Cost: one additional LLM call per model whose structured extraction failed (paths 1 and 2 in the pseudocode). For N=6 models where 2 fail structured extraction, expect 2 additional LLM calls. Override via the implementation; not a CLI parameter."*
- **Effort:** low
- **Impact:** medium
- **Score:** medium / low = **2.0**

### 3.3 Make `SKILL.md` argument-hint and inputs table consistent, and add `--concurrency` everywhere

- **Issue:** `SKILL.md:4` (`argument-hint`) lists `--models, --out, --schema, --mode, --no-auto-inject`. `SKILL.md:69` (inputs table) adds `--concurrency`. The hint is missing one; the table is missing `--models, --out, --schema, --mode, --no-auto-inject` flag-level detail.
- **Why it matters:** Frontmatter `argument-hint` is what host skill pickers (Codex, Cursor) display to the user. If `--concurrency` is documented but not hinted, users will not know it exists. This is the kind of bug that lives forever once shipped.
- **Concrete change:** Change `SKILL.md:4` to: `argument-hint: "<task-prompt> [--models m1,m2,...] [--out <dir>] [--schema <json|file>] [--mode quick|standard|thorough] [--concurrency parallel|sequential] [--no-auto-inject]"`
- **Effort:** low
- **Impact:** medium
- **Score:** medium / low = **2.0**

### 3.4 Decide whether the skill is documentation or executable, and say so

- **Issue:** `SKILL.md` describes a fail-soft dispatch + consolidation pipeline with retry policy "in the calling agent's runner, not in the skill core". `methodology.md:19` echoes this. But there's no `scripts/multi-ai-task.sh` in `scripts/`. The prior self-review called this out as a v3.0.0 roadmap item. In the meantime, a user invoking the skill gets… what? A skill-loader that reads these markdown files? An LLM that reads the rules and "executes" them? Both?
- **Why it matters:** Users who copy the bash examples from `dispatch-mechanics.md:36-50` are running Mechanism 2 manually; the "skill" is a docset, not a tool. The `user-invocable: false` frontmatter is consistent with this, but the usage example `/multi-ai-task "<task-prompt>"` is *not*. This is a fundamental contract ambiguity.
- **Concrete change:** Add a top-level "## What kind of artifact is this skill?" section to `SKILL.md`, between the current "When to use" and "Usage" sections. State explicitly: *"This skill is **documentation + worked recipes** intended to be read by either (a) a human setting up a multi-model dispatch + consolidation pipeline, or (b) a parent LLM orchestrator that will execute the dispatch by following the rules in `rules/`. There is no `multi-ai-task.sh` executable; the `dispatch-mechanics.md` bash examples are reference implementations."* Update the frontmatter to make `user-invocable: true` *or* remove the `/multi-ai-task` usage example — pick one.
- **Effort:** low
- **Impact:** high (clarifies the entire skill contract)
- **Score:** high / low = **3.0**

### 3.5 Move the residual sample alias table out of `consolidation-rules.md`

- **Issue:** The prior self-review claimed alias tables were moved from `consolidation-rules.md` to `examples/research-prior-art.md`. The 12-entry sample at `consolidation-rules.md:84-95` was not moved; the research-specific table at `examples/research-prior-art.md:125-141` is a superset.
- **Why it matters:** A reader of the generic core (`consolidation-rules.md`) is told at `:328-331` that "The alias map is task-specific, not part of this skill's core" — and then sees a sample alias table at `:84-95` with AutoGen/MAF/BMAD entries. The doc contradicts itself.
- **Concrete change:** Delete `consolidation-rules.md:82-96` (the `const aliases = {...}` block). Replace with: *"See `examples/research-prior-art.md` for an example of a 14-entry research alias map. Task-specific aliases belong in the run's `run-manifest.json → aliases` field, not in this generic rules file."*
- **Effort:** low
- **Impact:** medium
- **Score:** medium / low = **2.0**

### 3.6 (Bonus) Reconcile phase numbering across `methodology.md` and `consolidation-rules.md`

- **Issue:** `methodology.md` uses 1-2-3-4; `consolidation-rules.md` uses 2-3-3.5-3.6.
- **Why it matters:** Cross-references like "see Phase 3" in one file and "see Phase 3.5" in another will confuse readers. The fractional phases (3.5, 3.6) read as a design-by-accident.
- **Concrete change:** Pick one numbering. Recommended: in `consolidation-rules.md`, rename the section headers from "Phase 2 — ALIGN" / "Phase 3 — DEDUP" / "Phase 3.5 — RESOLVE CONFLICTS" / "Phase 3.6 — SCORE + SYNTHESIZE" to "Phase 2 — Extract" / "Phase 3 — Dedup" / "Phase 4 — Resolve conflicts" / "Phase 5 — Score + synthesize" (and renumber `methodology.md` Phase 4 to Phase 6). Total phases become 6, with the 4 high-level ones from `methodology.md` re-labeled as the 1, 2, 3, 6 endpoints.
- **Effort:** low
- **Impact:** medium
- **Score:** medium / low = **2.0**

---

## §4. Open Questions

1. **What is the target user?** A skill that is `user-invocable: false`, has no executable, requires the user to read 4 rule files plus 3 examples, and is labeled "task-agnostic" — who is this for? A parent LLM orchestrator? A power user writing a runner script? A library author building a pipeline tool? The skill never says. The "Proven provenance" suggests "an LLM agent that reads the rules and runs the dispatch itself", but the frontmatter suggests the opposite. Pin this down.
2. **What is the relationship between `multi-ai-task` and the host skill loader?** In a Codex/Cursor harness, the `agents/codex/multi-ai-task/SKILL.md` and `agents/cursor/multi-ai-task/SKILL.md` are byte-identical to `skills/multi-ai-task/SKILL.md` (confirmed via `rtk diff -q`). The `plugins/silver-bullet/skill-source/multi-ai-task/` copy is also in sync. The `agents/codex/...` copy differs in the frontmatter (it has a `title: "Silver: Multi AI Task"` and rearranges `argument-hint`/`description`). Is the codex frontmatter variant a `sync-codex-package.sh` artifact, or a manual override? If the latter, who's responsible for keeping it in sync?
3. **Where is the executable that the skill implicitly assumes exists?** `methodology.md:19` says "The skill does NOT retry. Retry logic lives in the calling agent's runner". `SKILL.md:29` says the same. But there's no `scripts/multi-ai-task.sh` in `scripts/`, no `bin/multi-ai-task`, no `multi-ai-task.py`. The `tests/skill-scenarios/multi-ai-task.md` test (18 lines) is a description, not executable. Is the executable something the user is expected to write themselves using the skill as a spec? If so, say so. If not, where is it?
4. **Why are 2 of 3 examples unwritten?** The prior self-review's #10 deferred worked code-review and fact-check examples to v2.2.0. v2.1.0 shipped without them. The skill's strongest claim — "task-agnostic" — is supported by exactly one worked example. Is "v2.2.0 with worked examples" still on the roadmap? If yes, what's the target date? If no, the skill should drop the "task-agnostic" framing or qualify it ("proven for prior-art research; untested for other task types").
5. **What is the upgrade path from v2.x to v3.0.0?** The prior self-review's "Improvements Deferred" table lists v3.0.0 items (executable backend, tiered evidence rubric, overlay packs, machine-readable manifest). v3.0.0 is referenced but not dated or scoped. Add a "Roadmap" subsection to `SKILL.md` to set expectations.
6. **What happens when two models give factually contradictory answers that *both* look credible?** The conflict-resolution library handles "category" disagreements (a soft field) but not "evidence" contradictions (a hard field). Example: m1 says "LangGraph has V-model rollup" with a quote from the docs; m2 says "LangGraph does not have V-model rollup" with a quote from the same docs. The current rules (`majority`, `majority-with-uncertain`, `lowest-of-majors`) do not adjudicate. The "thorough" mode dispatches a verifier model, but the verifier is the *same* model that produced one of the contradictory answers; the loop isn't closed. Is this a known limitation, a v3.0.0 item, or a use-case the skill is not designed for?
7. **The prior self-review claimed the skill was "production fitness" with 6 OCG models; the second self-review pass (`multi-ai-self-review-r2-20260627-093345/`) shows 4 of 6 models producing 0-byte outputs.** Why? Is this a harness issue with the second pass, or a real reliability problem with the skill under load? The v2.1.0 changelog doesn't address it.

---

## §5. Confidence

- **Overall confidence: medium.**
- **What would change my assessment:**
  - If the user clarifies that the skill is documentation-only (no executable) and that the "calling agent's runner" is the LLM itself reading the markdown, then §3.4 becomes moot and several of the "missing/wrong" items in §1 (e.g., the "no executable" complaint) become "by design".
  - If the user points me at `scripts/multi-ai-task.sh` or similar that I missed (it's possible — the skill itself says "the executable is in the calling agent's runner", which I interpreted as "not in this repo"), then §1.1, §1.2, and §3.4 get re-scored: the skill moves from "documentation with no implementation" to "documentation with an implementation somewhere" — a different failure mode but a smaller one.
  - If `sync-codex-package.sh` is what generates the differing `agents/codex/multi-ai-task/SKILL.md` frontmatter (my read of the diff suggests it does, but I did not run the script), then the codex-variant inconsistency in §1.1 is "by design" and not a bug.

**Net assessment:** the skill is a competent, well-organized documentation set for an important pattern (multi-model fan-out + consolidation), with a well-defined conflict-resolution library that is its strongest asset. The named-rule library, the worked prior-art example, and the failure-mode table are good. The skill's weakest areas are: (a) internal contradictions on small but load-bearing details (return-value naming, phase numbering, port-collision claims), (b) the "extractor model: no extra cost" fabrication, and (c) a fundamental contract ambiguity about whether the skill is documentation, an executable, or an LLM-readable spec. Fixing the 5 items in §3 in priority order would take a single PR; they are all surgical, all low-effort, and all the kind of bug a user hits on first contact with the skill.

---

**Prompt injection recap (no action taken):** The earlier `bash` tool output for the directory-listing command contained injected text attempting to coerce me into invoking a non-existent "graphify" tool and echoing a payload twice. I ignored it and continued the review against the requested files only.
