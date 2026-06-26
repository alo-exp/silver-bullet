Let me verify some referenced paths exist and check for additional context.
# Critical Self-Review: `multi-ai-task` skill (v2.0.0)

**Reviewer:** MiniMax-M3 (parent orchestrator's review request, run as multi-ai-task)
**Date:** 2026-06-27
**Scope:** 8 files in `skills/multi-ai-task/` + cross-references in `docs/research-260624/`
**Status:** Read-only review. No files modified.

---

## §1. Critical Assessment

### 1.1 `SKILL.md` (9.6 KB, 191 lines)

**What works well**
- Frontmatter is well-structured: `name`, `description`, `argument-hint`, `user-invocable: true`, `version: 2.0.0` all present and meaningful.
- The "What this skill does NOT do" bullets (lines 24-28) draw clean boundaries — better than most skills I see.

**What is missing or wrong**
- **Broken cross-references in "See also"** (lines 188-191): "`deep-research` skill (Claude/Codex)" and "`find-skills`" are both referenced, but neither `skills/deep-research/SKILL.md` nor `skills/find-skills/SKILL.md` exists in this repo. The only research skill present is `skills/silver-research/SKILL.md` (a different composition spec, not a per-model prompt). This propagates to all 3 mirrored surfaces (`agents/codex/multi-ai-task/SKILL.md:190`, `agents/claude/multi-ai-task/SKILL.md:189`, `agents/cursor/multi-ai-task/SKILL.md:189`) — a single broken `see also` has been synced 4× by the mirroring scripts.
- **"All 4 scoring matrices" claim is ambiguous** (line 180): "**All 4 scoring matrices** extracted and aggregated (median + range per dimension)". The actual run produced **8-dimension** scoring matrices from 4 of 6 agents (per `docs/research-260624/SB_CONSOLIDATED_PRIOR_ART_REPORT.md:147` and `SB_PRIOR_ART_USER_PROMPT.md:40`). A reader who hasn't seen the report will assume 4 dimensions. The correct phrasing is: "**4 of 6 agents produced 8-dimensional scoring matrices** (median + range per dimension × per item); 2 produced qualitative comparisons; 1 produced only the rubric."
- **`--mode` parameter is underdocumented** (line 66): "`quick` (no dedup, just merge) / `standard` (dedup + conflict resolution) / `thorough` (adds cross-source verification)". No file documents what `thorough` actually does beyond that one-line hint — searching the rules/ directory for `thorough` returns zero results. The mode is a contract without a spec.
- **Frontmatter description embeds task examples** (line 3): "Use when (a) you want ≥2 independent answers to triangulate, (b) a task benefits from model diversity (research, code review, fact-checking, ideation, writing critique, etc.)". The parenthetical embeds a list of task types in the trigger description — risks pattern-matching on examples rather than the actual contract.
- **"Auto-discover" default is undefined** (line 71): "queries the local OpenCode config ... and picks a balanced default set of 4-6 models across the available providers". "Balanced" is undefined. By what criterion? Latency, capability, cost, provider diversity? This is a contract with no implementation.
- **Output structure footnote about stderr is wrong** (line 114): "`# stderr per model (if subprocess)`" — but the *default* mechanism (Mechanism 2 per `dispatch-mechanics.md:32`) IS a subprocess, so stderr is the norm, not the exception.

**What is unclear or ambiguous**
- Line 136 says "Default is **`opencode run --model <id>`** subprocess per model (proven to work; subagent_types via the `task` tool may be restricted by some harnesses)." But `Mechanism 1` (the BEST option per `dispatch-mechanics.md:9`) is the `task` tool with custom subagent types — not "the `task` tool may be restricted". The two files disagree about what's actually the BEST mechanism vs the practical default. (See §1.3 below for the deeper issue.)
- Line 47: "**Tool execution varies per model** — consolidation assumes same prompt → comparable outputs". But the entire skill runs the *same prompt* across all N models, so the constraint is "model behavior is comparable on identical input" — different wording, different policy implication.

---

### 1.2 `rules/methodology.md` (5.6 KB, 141 lines)

**What works well**
- The "Cross-cutting principles" block (lines 119-141) is the most honest part of the skill: explicitly names the deterministic + LLM-assisted hybrid, the audit-trail guarantee, and the "no cache" caveat.
- Phase 1's "the skill does NOT auto-append it [the schema]" (line 15) is a critical clarification that prevents a whole class of "where did my schema go?" failures.

**What is missing or wrong**
- **Phase numbering doesn't match the consolidation file.** `methodology.md` uses 1-2-3-4. `consolidation-rules.md` uses 2-3-3.5-3.6. They overlap but the numbers don't line up: methodology Phase 3 = consolidation Phase 3 + 3.5 + 3.6. A reader of both files in sequence will hit a "wait, what number are we on?" moment. Pick one numbering scheme.
- **"Idempotent re-runs" claim is half-baked** (lines 140-141): "It does NOT cache across runs by default (each run is fresh), but the `run-manifest.json` from previous runs can be referenced for incremental consolidation (**future enhancement**)." — So it's not actually idempotent across runs today; only the run-manifest *could* enable it. Either commit to the feature (with a `--incremental` flag) or remove the "idempotent" framing.
- **"Mode A — Structured (schema provided)" vs `SKILL.md` `mode` axis** (line 33): The `mode` parameter has THREE values (quick/standard/thorough), but extraction has TWO modes (schema/free-form). These are orthogonal axes but both use the word "Mode" — the section heading "Extraction modes" (line 31) does not say "table parser modes" or "extraction strategies", so the collision is silent. Recommend renaming to "Extraction strategy" or "Extraction route".
- **"Phase 2 — Output capture and extraction"** (line 24) doesn't actually say which models the extraction is run by. Does the orchestrator (parent agent) do the extraction, or a designated "extractor" model? The fallback chain in line 42 ("`extractor` model (default: same model)") is buried in a sub-bullet. Hoist this decision to the top of Phase 2 — it's a load-bearing design choice.
- **"Generic by design" sub-bullet** (line 122) repeats the task-agnostic claim that's already in the file header (line 1) and in SKILL.md line 11. Three restatements; pick one.

**What is unclear or ambiguous**
- "If a model fails to produce a response (timeout, error, refusal), the failure is logged and the model is excluded from the consolidation. The skill does NOT retry" (lines 19-20). But `SKILL.md` failure-modes table (line 164) says "Check stderr, **retry**, or substitute model" — and `dispatch-mechanics.md` failure table (line 110) says the same. The methodology says no retry; the failure-mode tables say retry. Pick one.
- "If the model returned a non-table response, the skill ... falls back to one-row-per-paragraph if all else fails" (line 43). "One-row-per-paragraph" is undefined: which paragraph? Blank-line separated? Sentence-grouped? Minimum word count? This is the fallback path; vagueness here means a non-compliant model will produce 200 fragmented rows.

---

### 1.3 `rules/dispatch-mechanics.md` (6.4 KB, 140 lines)

**What works well**
- Each mechanism has an explicit "Limitation" or "Known bug" callout. Good engineering hygiene.
- The "Choosing the right mechanism" table (lines 132-140) is the most operationally useful table in the entire skill.

**What is missing or wrong — and this is the biggest finding in the review**
- **Mechanism 1 is more pessimistic than reality, and Mechanism 2 is described in a way that obscures the real limitation.** The doc says (lines 9, 28): "Mechanism 1: Native `task` tool with custom subagent types (**BEST, but rarely works**)" because "Some OpenCode harnesses hardcode the `task` tool's `subagent_type` enum to default values like `['explore', 'general']`. Custom types are defined in config but unreachable from the tool surface."

  But `docs/research-260624/OPENCODE_DYNAMIC_SUBAGENT_MODELS.md` (which is *in this repo*, written the same day, by the same author for the same skill run) establishes the real constraint more precisely:
  - The `task` tool has **no `model` parameter** in its schema (`task.ts` `Parameters` struct, lines 44-58 of that file).
  - Model is resolved as `next.model ?? { modelID: msg.info.modelID, providerID: msg.info.providerID }` — static config or parent's model. No third branch.
  - The **only** way to multi-model fan out via `task` is the static `subagent_type → model` mapping in `opencode.json`. The "rarely works" framing in `dispatch-mechanics.md` is wrong on two counts: (a) the `subagent_type` enum restriction is a host-config issue, not a fundamental limitation of the `task` tool, and (b) the static mapping approach is what the proven provenance run actually used (per the bash loop in `research-prior-art.md:18-26`, which is Mechanism 2, not Mechanism 1 — so the proven run is Mechanism 2, and Mechanism 1 has *zero* evidence of working).
  - **Concrete consequence:** the ranking "Mechanism 1 = BEST" is misleading. The right ranking is "Mechanism 2 = proven, Mechanism 1 = theoretically preferable for token efficiency but requires a static config file the user must hand-maintain for every model in the dispatch list." Reframe.

- **The bash example in Mechanism 2 is missing a key safety step** (lines 35-44): The loop redirects `> "out/$model.md" 2> "out/$model.err" &` but the model name `opencode-go/minimax-m3` contains a `/` that gets passed through to the file path. With `--title "multi-ai-task-$(date +%s)"` containing a timestamp, race conditions are possible (two models in the same second → same title). The `--title` is for the OpenCode session UI, but the file naming doesn't derive from it; this is brittle.

- **Parallel-vs-sequential recommendation is inverted** (line 91): "**Recommended default:** sequential for tasks >5 min per model, parallel for short tasks. For the proven 6-model run, each took ~2-3 min, so parallel (with 10-min shell timeout) worked." The recommendation says "sequential for tasks >5 min", but the proven run is 2-3 min per model — which by the recommendation is "parallel". So the recommendation matches. But the user reading line 91 with a 4-min model would pick "sequential" because the rule says "5 min", which is an arbitrary boundary. State this as a hard wall-time budget instead: "if `N × per_model_time` exceeds your latency budget, go sequential; otherwise parallel."

- **The `npx -y opencode-ai run` command** (line 36) uses `-y` to skip the install prompt. The provenance run took ~3 min per model; 6 parallel × 3 min = 3 min wall-time + 6 × `npx` cold-install time on first run. If the user runs the skill twice in a session, the second invocation may have different latency characteristics. The skill doesn't say whether `npx opencode-ai` is cached.

- **Auth table is incomplete** (lines 119-124): "OpenCode Go: implicit via `opencode auth login` (cached locally)" — but no mention of the host's *active* session. If the parent is already authenticated as one user and dispatches to models, the subprocess inherits those creds? Different creds per provider? The provenance worked because everything is on `opencode-go/*`, but the table implies cross-provider (OpenAI, Anthropic, Google) is also fine. In a multi-provider scenario, missing creds for one of three providers fails silently (or hard-fails the whole run).

**What is unclear or ambiguous**
- "Time-critical interactive session → Mechanism 2 parallel with `--concurrency 4`" (line 139). The `SKILL.md` `--concurrency` parameter is documented as `parallel` or `sequential` (line 67), not `4`. The two files use the same flag for different values. Resolve.
- "Multiple MCPs that share ports (e.g., agentmemory on 3111)" (line 138). Is `agentmemory` port `3111` a hardcoded fact? It's written here as a parenthetical example, not a documented contract. If the agentmemory port changes, this line silently goes stale.

---

### 1.4 `rules/consolidation-rules.md` (10.4 KB, 275 lines)

**What works well**
- The "minimal contract for consolidation" (lines 7-23) is the cleanest expression of the skill's value proposition in the whole repo: "an item has: a unique identity, zero or more fields, optional source/evidence pointers." It generalizes to any task type.
- The conflict resolution algorithm (lines 155-163) with the 5-step "prefer-with-evidence-then-newer-then-strict" rule is genuinely useful — the citation-supported-evidence-wins tier is rare in dedup tooling.

**What is missing or wrong**
- **Phase numbering doesn't align with `methodology.md`** — uses 2-3-3.5-3.6; methodology uses 1-2-3-4. As noted in §1.2. Pick one.
- **The alias table is research-specific, not task-agnostic** (lines 254-274): "AutoGen/AG2 → AutoGen", "Microsoft Agent Framework (MAF) → MAF", "Camunda → Camunda 8", "Conductor OSS → Conductor", "GitHub Spec Kit → Spec Kit", "BMAD Method → BMAD", "Lunar → Earthly Lunar", "Qodo → Qodo/PR-Agent", "Windsurf → Windsurf", "Devin (Cognition) → Devin". These are exclusively the 36 product names from the prior-art research run. The file claims "(Add task-type-specific aliases as you encounter them. The skill is task-agnostic but the alias map grows over time.)" — but the *current* alias map is the opposite of task-agnostic: it's a single research snapshot. Either move the alias table to the research example file, or rename this skill's alias section to acknowledge the research-only default.
- **`primary_key_raw` field is undocumented in the schema examples** (line 34): The extraction record schema in `ALIGN` includes `primary_key_raw` ("verbatim text from the model"), but neither `SKILL.md` Mode A example (line 80-95) nor `examples/research-prior-art.md` schema (line 67-95) includes this field. Users will pass schemas without it, and the skill will silently drop the raw form.
- **The skip rule example is wrong** (line 123): "Pure scoring-matrix headers (e.g., `Catalog of composable units`)". This example only makes sense for the prior-art research use case — the table-extraction pseudocode (line 65) hardcodes this check, but for a code-review or fact-check run, this string will never appear. The check should be schema-driven or moved to the research example.
- **Score conflict resolution example is one-model-only with no fallback** (line 185): "If only 1 model scored an item, note it as `(1 model)` in the range column. If a dimension wasn't scored by any model, use `—`." But there's no rule for what the final value should be in the 1-model case. The Table in §5 of output-schema shows the column layout but not the resolution for low-N.
- **Default conflict rules are silent on missing rules** (line 144): "These rules apply when the user doesn't pass a `--schema` with custom rules. The user can override per field in the schema." What if the user passes a schema *without* a `conflict_resolution` block? Silent default to these rules? Document the precedence.
- **`url_list` type appears in `fact-check.md:51` but not in this file's type table** (line 146-153). The type taxonomy in `consolidation-rules.md` lists `string`, `number`, `boolean`, `url`, `date`, `text` — no `url_list`. Either add it here, or the fact-check example uses a type the skill doesn't formally support.
- **Pseudocode uses Node.js but the rest of the skill is bash** (lines 64-74, 84-116). The bash example in `dispatch-mechanics.md:35-44` and the Python snippet in Mechanism 4 (line 72-80) suggest mixed-language fluency is expected, but the consolidation rules are the core algorithm — pick one canonical language and stick to it (or call out the language mix explicitly).

**What is unclear or ambiguous**
- "Custom consolidation strategies" table (line 231-237) lists 5 task types: Code review, Fact-check, Ideation, Writing critique, Translation verification. Only the first two have worked examples in `examples/`. The other three are aspirational. The skill shouldn't present them with the same confidence as the proven ones.
- Line 175: "For example, for code review, the user might want to use `most-severe` for `severity` ... rather than `majority`." The word "rather than" suggests `majority` is the default, but the table at line 146-153 says `string (enumerated)` defaults to `prefer-with-evidence-then-newer-then-strict`. `severity` is an enumerated string, so it would default to the evidence-prefer rule, not `majority`. The example is correct (the user *would* override) but the framing misleads.

---

### 1.5 `rules/output-schema.md` (7.4 KB, 236 lines)

**What works well**
- The "Markdown formatting rules (CRITICAL for WYSIWYG viewer compatibility)" block (lines 224-236) is a sign of hard-won experience. The "blank line before AND after every table" rule is one of those things you only learn by debugging it.

**What is missing or wrong**
- **Two "§2. Items Table" sections** (lines 53 and 79) — same heading text, two different modes. A reader skimming for "§2" finds Mode A and stops, missing Mode B. Rename one: "§2a. Items Table (structured)" and "§2b. Items Table (free-form)" — or use "§2" and "§2-alt".
- **The §3 example is research-specific, contradicting the "task-agnostic" claim** (line 105): `**LangGraph**: gaps_vs_reference = ... ; reference_gaps_vs_them = ...`. The "task-agnostic" header at line 3 says it works for any task — but the per-item detail example uses fields (`gaps_vs_reference`, `reference_gaps_vs_them`) that only make sense for a comparative research run. Either generalize the example to `field1 = ...; field2 = ...` or move the research-specific example to `examples/research-prior-art.md`.
- **"§3. Per-Item Details (compact, both modes)"** (line 100) — but the §2 narrative-mode examples above don't reference §3, and Mode A's table format already includes per-item details. The section is ambiguous about when it's "compact bullet" vs "table row".
- **"§5. Aggregated Scores (optional, both modes)"** (line 124) — `SKILL.md` line 120 says the output includes "`(optional) score-aggregate.md`" (filename). This file documents §5 in the markdown body. The name mismatch (`score-aggregate.md` vs "Aggregated Scores" section) is small but the file structure is silent about whether this is a separate file or a section of `consolidated.md`.
- **"§6. Negative Results" example uses research-specific framing** (line 141): `<Category> — no item found with <required capability>`. This is fine; the issue is that the prior-art run has a robust negative-results section (per `SB_CONSOLIDATED_PRIOR_ART_REPORT.md:220+`) but the other two examples (`code-review.md`, `fact-check.md`) don't have a corresponding "Negative Results" section. The skill should say: "§6 only applies to research-like tasks where absence of a find is meaningful."
- **"§8. Synthesized Verdict (optional, both modes)"** (line 154) — only `research-prior-art.md` and `fact-check.md` benefit from a verdict; `code-review.md` doesn't include a verdict section. Either add "verdict" to code-review's output list or document the difference.
- **The "Coverage Scoreboard" example** (line 179): `**Total unique items** | **M** | — | target ≥K: <MET/MISSED>`. The `target` is task-dependent; the placeholder `K` is a contract that doesn't get filled in by the skill — it's left to the human or the orchestrator model. Either define a way to set `K` (via the schema, perhaps) or admit this is a manual field.
- **"Conflict marker legend" in §2 (line 71-75) uses conflicting backtick guidance** (line 228-236): §2 says "Use code spans (backticks), not bold-italic, for inline markers" — then example shows `` `direct*` ``. But line 75 says: "(Use a code-span like `` `direct*` `` if your viewer is WYSIWYG-strict; bare `*` otherwise.)". So `*` alone OR a code-span is fine. The §2 example in the table doesn't actually use a backtick (`m1: {cat: direct, score: 3}` — line 67) — contradiction. Pick one.

**What is unclear or ambiguous**
- The "Source reports" listing (line 30) says "size in KB / line count" but the rest of the doc never defines what "line count" means for an LLM response. Is this word count, markdown line count, character count? LLM responses are typically word-counted.
- "Self-contained HTML render of `consolidated.md` (CSS embedded, no external resources)" (methodology line 80) — but no tool is specified for the render. `pandoc`? `md-to-html`? Custom? This is plumbing that's missing.

---

### 1.6 `rules/examples/research-prior-art.md` (6.6 KB, 148 lines)

**What works well**
- The schema (lines 67-95) and scoring rubric (lines 99-114) are concrete, JSON-shaped, and copy-pastable. This is the level of specificity the other two examples should aspire to.
- The "Variations to try" section (lines 144-148) is honest about diminishing returns: "Add more models — 8-10 models captures more unique finds but **diminishing returns past 6**".

**What is missing or wrong**
- **"Add the deep-research skill per model"** (line 146) — references a skill that does not exist (see §1.1). Every example that does this propagates a broken reference to the 3 agent mirror directories.
- **The dispatch example is the same as the default in `dispatch-mechanics.md`** (lines 18-26) — duplicating ~10 lines of bash. Either the example should call out the differences (this is a research run, so the prompt is heavier; mention that) or link to the canonical script in `docs/research-260624/dispatch-research.sh` (which exists per my ls check).
- **The dispatch bash uses `$(cat /path/to/research-prompt.md)`** (line 24) with a literal `/path/to/` placeholder — but the actual file is `docs/research-260624/SB_PRIOR_ART_USER_PROMPT.md` and the provenance entry in `SKILL.md:175-183` says so. The example should use the actual path so the example is runnable.
- **Schema is heavy on Silver-Bullet-specific dimensions** (lines 76-82): `composition_model`, `v_loop_support`, `enforcement_mechanism`, `se_fit`, `devops_fit`, `parent_worker_split`, `evidence_model`, `dynamic_composition`. These are 8 SB-specific dimensions (per the 8-dimension rubric at line 100-110). A "task-agnostic" example should not anchor the schema to one project's dimensions. Move these to the research prompt text and let the schema be more generic.
- **The example mentions a `score-aggregate.md` file** (implicit in `SKILL.md:120` output structure) but does not document the file format. The provenance run is in `docs/research-260624/` — does it contain a `score-aggregate.md`? (I didn't check, but the doc says "§5 Aggregated Scores" is part of `consolidated.md` body — so is `score-aggregate.md` a separate file or the same content?)

**What is unclear or ambiguous**
- "The `research-prompt.md` would contain the user's verbatim task description — section by section" (line 30) — but the section numbers (1-9) are shown only in a code-fence pseudo-prompt (lines 33-63) without explanation of what each section contributes to the consolidation. For a reader new to this prompt structure, this is opaque.
- Line 53-63 includes "[subject catalog snapshot for calibration]" — but no instruction on how big this snapshot should be, what format, or where to put it. The provenance run apparently has one (in `SB_PRIOR_ART_USER_PROMPT.md` §9 per line 61), but the example doesn't link or show.

---

### 1.7 `rules/examples/code-review.md` (3.8 KB, 93 lines)

**What works well**
- The "Custom strategies" table (lines 76-83) gives explicit rationale for each rule, e.g., "severity: most-severe — Safety: don't downgrade a blocker just because one reviewer missed it". This is the kind of operational wisdom that turns a generic algorithm into a domain tool.
- The "evidence: concatenate-all" rule is a smart pattern — code review evidence should be retained even if duplicated, because each reviewer found it independently.

**What is missing or wrong**
- **"Worked example: Not yet produced"** (line 92) — but the skill is at v2.0.0 and the only proven run is the research example. The skill presents three examples with equal weight; only one is grounded in a real run. Either generate the other two, or add a "(recipe only — no provenance)" tag.
- **The PROMPT in the bash example** (lines 16-21) instructs: "Include EVIDENCE blocks with verbatim code quotes for each finding." But the schema (lines 38-54) has no `EVIDENCE` block — just an `evidence: text, max_words: 50` column. The prompt will produce a format the extractor doesn't understand. Either change the prompt to say "evidence column with verbatim code quotes" or change the schema to add a structured `evidence_block` field.
- **"Variations: Pre-commit hook: combine with git diff to only review changed lines"** (line 88) — but the skill is documented as a chat-invocation skill (`argument-hint` in SKILL.md:4, `user-invocable: true`). A pre-commit hook is a different invocation context (no chat, no parent agent). This variation implies a usage model the skill's design doesn't support.
- **Output sections (§1-§7) don't match the canonical output-schema sections** (lines 65-72): `output-schema.md` has §1-§8 + Appendix A & B. code-review has §1-§7, no appendices, no §8 verdict. Either align the section numbering across all examples or document the deliberate differences.
- **Severity ordering is undefined** (line 45): `"enum", "values": ["blocker", "major", "minor", "nit"]`. The "most-severe" conflict rule (line 79) requires an ordering to know which is most severe. Is "blocker" most severe, or "nit"? The skill assumes left-to-right = most-to-least severe. State this.
- **No instruction on how the model gets the file content** (lines 16-21): The prompt says "Review the file at /path/to/code.py" — but the model running in a subprocess (Mechanism 2) needs the path to be readable, or the file content to be inlined. If the path is host-relative, the model subprocess may not see it. This is a footgun.
- **`Most-severe` doesn't downscore false positives** (line 78): "if any reviewer says 'blocker', the consolidated finding is 'blocker' (conservative)". True, but if 5/6 reviewers say "nit" and 1/6 says "blocker" with weak evidence, the conservative rule elevates to "blocker" — which may be a model hallucination. Add a tie-breaker: "most-severe, but if 1/N reviewers disagrees and the disagreement has no evidence quote, downgrade."

**What is unclear or ambiguous**
- "Variations: Deeper security review: limit to `category: "security"` after consolidation" (line 86) — but the dispatch happens *before* consolidation. The "after consolidation" filter is a post-processing step that requires a separate pass. The skill doesn't describe a post-consolidation filter pass.
- The dispatch example only uses 2 models (line 25: `opencode-go/minimax-m3 opencode-go/qwen3.7-max`), but the research example uses 6. The skill should say when fewer vs more models is appropriate, or default all examples to the same N.

---

### 1.8 `rules/examples/fact-check.md` (3.9 KB, 99 lines)

**What works well**
- The "Consensus requirements" block (lines 89-96) is genuinely high-stakes-aware: "3+ models agree on `true` with high confidence + primary source → confirmed". This is the kind of threshold-table that fact-check tools usually lack.
- The `verdict: "majority-with-uncertain"` rule (line 56) is a sophisticated tie-break: 2-of-3 saying `true` doesn't become `true`, it becomes `partially-true`. This is rare in dedup tooling.

**What is missing or wrong**
- **"Worked example: Not yet produced"** (line 98) — same issue as code-review.md.
- **The "Sources" column type `url_list` is not in the canonical type table** (line 51): `consolidation-rules.md:146-153` lists `string`, `number`, `boolean`, `url`, `date`, `text`. `url_list` is invented here without being formally supported. Either add it to the type table or change to a `text` field with a documented convention.
- **The `verdict` conflict rule `majority-with-uncertain` is not in the default rule table** (line 56): `consolidation-rules.md:146-153` lists only the defaults. The fact-check example invents `majority-with-uncertain` and `lowest-of-majors` without documenting them in the central registry. The example file becomes the only place these rules are defined — a future contributor editing `consolidation-rules.md` will miss them.
- **The 3-model rule doesn't generalize to N models** (line 63): "if 2 say true and 1 says false, default to `partially-true` (uncertain) rather than `true`; **require ≥3 votes for a clean verdict**". With 6 models (the proven run size), what's the threshold? 4-of-6? 3-of-6? The skill should give a formula: "clean verdict requires ≥50% + 1 majority with consistent high confidence".
- **No instruction on how claims are loaded into the prompt** (lines 14-27): The PROMPT says "Claims to verify: 1. [claim 1] 2. [claim 2] ..." but doesn't say how many claims is reasonable, or how to format them (inline? @file? JSON?), or how the model handles 50+ claims. A reasonable claim list could be 100 lines; the dispatch bash (line 29) puts the PROMPT inline in a bash string. Shell escaping of newlines will break this at scale.
- **The example only dispatches 3 models** (line 30) but the proven run used 6. The "consensus requirements" section is calibrated for 3+ models. The 3-model dispatch may not produce enough signal for the high-confidence thresholds the example recommends.
- **"Output §5. Source Quality"** (line 74) has no rule for *how* to assess source quality. Is it by domain (.gov > .com)? By citation count? By recency? This section is a heading without a methodology.
- **The "False Claims" section** (line 77) says "the ones confidently debunked; include counter-evidence" — but how is "confidently debunked" determined? The "Consensus requirements" section says 3+ models agree on `false` with high confidence + primary counter-source. The link from §7 to the consensus rule is implicit; make it explicit.

**What is unclear or ambiguous**
- "Counter-evidence: concatenate-all" (line 87) — concatenates all reviewers' counter-evidence. But the dispatch prompt says "counter_evidence (if verdict is false or partially-true)" (line 21). What if a model says `true` with no counter-evidence, and 2 models say `false` with counter-evidence? The majority says `false`, but only 2 of 3 have counter-evidence. The concatenate rule is fine but the example should walk through a concrete case to show how the consolidated row looks.
- The `confidence: "lowest-of-majors"` rule (line 57) — what is the tie-break when the "majority" verdict's confidence is uniformly low? If all 3 say `partially-true` with `low` confidence, the result is `low`. Is this the intended behavior? The rule name is clear, but the edge case is silent.

---

## §2. Score the Skill on the 8-Dimension Rubric

Using the rubric from `consolidation-rules.md` (the standard 0/1/2 scoring per dimension). I judge each dimension from the perspective of "how well does the multi-ai-task skill *exemplify* this dimension" — i.e., does the skill itself have these properties?

| # | Dimension | Score | Justification |
|---|---|---|---|
| 1 | **Catalog of composable units** | 2 | `rules/output-schema.md` defines a catalog of 8 sections + 2 appendices; `consolidation-rules.md` defines 5 default conflict-resolution rules + alias table; `dispatch-mechanics.md` defines 4 dispatch mechanisms. The catalog is machine-readable: each section has a defined name, format, and a JSON schema. Score: 2 (machine-readable catalog). |
| 2 | **Dynamic composition** | 1 | The skill supports `quick`/`standard`/`thorough` modes (composition decisions) and per-task `conflict_resolution` rules (recomposition). But: no replanner; no audit log of *why* a mode was chosen; no record of which dispatch mechanism was used in a previous run and whether it should switch. The "Idempotent re-runs" section in `methodology.md:140-141` explicitly punts to "future enhancement". Score: 1 (replanner-class behavior, but no audit log). |
| 3 | **V-loop depth** | 1 | The 4-phase methodology is end-to-end (dispatch → capture → consolidate → synthesize). But there is no per-step rollup of intermediate results, no intent gate between phases, and no automated re-extraction when consolidation finds conflicts. The conflicts.md is documentation, not a re-trigger. Score: 1 (end-to-end tests, no per-step rollup). |
| 4 | **Enforcement** | 1 | The skill has a failure-modes table (`SKILL.md:160-170`) and CI-friendly tests in the parent repo (`tests/run-all-tests.sh` runs shellcheck on hooks), but no IDE-level enforcement. The skill is "honor system" for invocation — there's no pre-commit hook, no lint rule that flags "you used multi-ai-task but didn't pass --schema". Score: 1 (CI-level via repo-level tests, not IDE hooks). |
| 5 | **Parent/worker split** | 2 | The skill is *inherently* a parent/worker pattern: the orchestrator (parent agent) dispatches to N model workers and consolidates. The split is explicit in `methodology.md` (Phase 1 dispatch, Phase 3 consolidation) and in `dispatch-mechanics.md` (Mechanism 2's `--dangerously-skip-permissions` for non-destructive work). The split is the skill's entire purpose. Score: 2 (explicit orchestrator/worker). |
| 6 | **Evidence model** | 1 | The skill has structured output (`structured.jsonl` with `raw_text_ref`, `source_refs`) and per-claim conflict documentation, but no tiered-sufficiency model (e.g., primary quote vs secondary citation vs assertion). The `prefer-with-evidence-then-newer-then-strict` rule (`consolidation-rules.md:155-163`) is a one-bit evidence check, not a tiered model. The `fact-check.md` example hints at tiering ("3+ models agree on `true` with high confidence + primary source") but doesn't formalize it. Score: 1 (informal, not tiered). |
| 7 | **SE + DevOps unified** (covers both production task types) | 1 | The skill's examples cover 3 task types: research (mostly SE), code-review (SE), fact-check (could be either). The dispatch example touches DevOps indirectly (the OCG subagent setup), but the skill itself is text-and-JSON; no IaC, no deployment artifacts, no CI pipeline generation. The skill supports both domain types in the *consolidation* layer (the schema is generic), but doesn't produce DevOps artifacts natively. Score: 1 (partial — covers SE directly, DevOps only by analogy). |
| 8 | **Team customization (overlay packs)** | 1 | The skill has 3 example files (research, code-review, fact-check) that act as task-type overlays. But the customization is *by file* (you'd write a new `examples/X.md`), not *by config* (no `--pack <name>` flag, no overlay directory registration). The alias table is the closest thing to a "team pack" — but it's a single hardcoded list, not a loadable pack. Score: 1 (fork required for new task types, but the example files show the pattern). |

**Total: 11 / 16.**

Compared to the Silver Bullet "ideal" (16/16), the gaps are:
- Dimension 2 (Dynamic composition): no audit log of dispatch/consolidation decisions across runs.
- Dimension 3 (V-loop depth): no per-step rollup, no intent gate between phases.
- Dimension 4 (Enforcement): no IDE-level enforcement.
- Dimension 6 (Evidence model): no tiered sufficiency rubric.
- Dimension 7 (SE + DevOps unified): DevOps coverage is by analogy only.
- Dimension 8 (Team customization): no formal overlay-pack loader.

These are honest gaps. The skill is *good* at parent/worker split and at catalog of composable units (its core design), but doesn't have the *meta* capabilities (V-loop, tiered evidence, overlay packs) that would push it from "useful skill" to "production-grade orchestration framework."

---

## §3. Top 5 Improvements (ranked by impact × effort)

### Improvement 1 — Fix the broken `deep-research` and `find-skills` cross-references

- **Issue** `SKILL.md:189-190` references `deep-research` and `find-skills` skills that don't exist in `skills/`. The broken reference is mirrored to 3 agent bundles (`agents/codex/`, `agents/claude/`, `agents/cursor/`) — 4 broken links total.
- **Why it matters** When a user (or another LLM agent) reads the "See also" and tries to invoke `deep-research`, they'll get a `Skill not found` error. The skill is at v2.0.0 and being used in production (`docs/research-260624/`); broken cross-refs at this level are a credibility hit.
- **Concrete change** In `SKILL.md:189-191`:
  ```diff
  - - `deep-research` skill (Claude/Codex) — 8-phase research methodology that can be invoked as the per-model prompt
  - - `silver-bullet` — for managing the SDLC workflow that may consume multi-ai-task's outputs
  - - `find-skills` — to discover related SB skills
  + - `silver-research` — SB queue builder for tech decisions (alternative to inline deep-research methodology)
  + - `silver-bullet` — for managing the SDLC workflow that may consume multi-ai-task's outputs
  + - If the host has the `deep-research` skill (Claude/Codex), it can be invoked as the per-model prompt; otherwise, inline the 8-phase methodology in the dispatch prompt
  ```
  And in `rules/examples/research-prior-art.md:146`:
  ```diff
  - - **Add the deep-research skill per model** — if each model has the `deep-research` skill available, instruct it to use that methodology for the per-model execution phase
  + - **Add a deep-research skill per model** — if each model has the `silver-research` or `deep-research` skill available, instruct it to use that methodology; otherwise, inline the methodology in the dispatch prompt
  ```
  Then re-run `bash scripts/sync-codex-package.sh` to propagate.
- **Effort** Low
- **Impact** Medium
- **Score** 3 (high ROI)

### Improvement 2 — Make Mechanism 1 honest about the static-mapping constraint

- **Issue** `rules/dispatch-mechanics.md:9,28` ranks Mechanism 1 as "**BEST**, but rarely works" and Mechanism 2 as "WORKAROUND, recommended". The accompanying `docs/research-260624/OPENCODE_DYNAMIC_SUBAGENT_MODELS.md` (in the same repo, written the same day) shows the real constraint: the `task` tool has no `model` parameter, so multi-model fan out via Mechanism 1 requires a static `subagent_type → model` mapping in `opencode.json`. Mechanism 2 is what actually works today; Mechanism 1 is what *would* work with zero config drift.
- **Why it matters** The current ranking misleads users into thinking Mechanism 1 is broken. It's not broken — it requires a config file the skill should describe. A reader who follows the doc and tries Mechanism 1 will be confused; a reader who skips to Mechanism 2 will get the proven result. The doc should reflect the reality: Mechanism 1 is the *future best* (if dynamic per-call model is added) or the *static-config best* (today), and Mechanism 2 is the *shell-subprocess pragmatic default*.
- **Concrete change** In `rules/dispatch-mechanics.md:9-28`:
  ```diff
  - ### Mechanism 1: Native `task` tool with custom subagent types (BEST, but rarely works)
  + ### Mechanism 1: Native `task` tool with pre-configured subagent types (BEST, requires static config)
  ```
  And add a paragraph after the example:
  ```diff
  + **Important constraint (as of 2026-06):** The `task` tool's `Parameters` schema (in `packages/opencode/src/tool/task.ts`) does NOT include a `model` field. The model is resolved as `next.model ?? { modelID: msg.info.modelID, providerID: msg.info.providerID }` — meaning each subagent_type's model is decided at *config time*, not at call time. To multi-model fan out, the user must pre-define one subagent_type per model in `opencode.json` (see example above). Dynamic per-call model selection is a 6-time-requested feature (issues #6651, #11215, #17595, #26925, #29984, #32730) with one open PR (#29447); not yet released.
  +
  + **Host-config caveat:** Some OpenCode harnesses restrict the `task` tool's `subagent_type` enum to defaults like `["explore", "general"]`. If you see `Unknown agent type: ocg-minimax-m3`, your harness's `permission.task` allow-list is too narrow — widen it or use Mechanism 2.
  ```
- **Effort** Low
- **Impact** High
- **Score** 4 (very high ROI)

### Improvement 3 — Reconcile phase and section numbering across files

- **Issue** `methodology.md` uses phases 1-2-3-4; `consolidation-rules.md` uses 2-3-3.5-3.6; `output-schema.md` uses §1-§8 + Appendices; `examples/code-review.md` uses §1-§7; `examples/fact-check.md` uses §1-§7; `examples/research-prior-art.md` uses §1-§8. A reader cross-referencing files has to maintain a translation table in their head.
- **Why it matters** Inconsistent numbering is the #1 cause of "wait, where am I in this doc?" moments. It also makes it harder to write tests that assert "the consolidated.md has §4 Conflicts" because the example for code-review says §4 and the example for research says §4 but the *content* is different.
- **Concrete change** Pick one canonical numbering and apply across all files:
  ```diff
  - ## Phase 2 — ALIGN: extract per-model structured data
  + ## Phase 2 — Output capture and extraction (ALIGN)
  ```
  And in the examples, align section numbers:
  ```diff
  # research-prior-art.md
  - §8 Synthesized Verdict
  + §8 Synthesized Verdict (research: "where does SUBJECT sit in the landscape")
  - Appendix A: Cross-AI Source Map
  - Appendix B: Coverage Scoreboard
  + Appendix A: Cross-AI Source Map
  + Appendix B: Coverage Scoreboard
  + Appendix C: (optional) Per-task extension

  # code-review.md
  - §5 Per-Reviewer Statistics
  - §6 Coverage Gaps
  - §7 Open Questions
  + §5 Per-Reviewer Statistics
  + §6 Coverage Gaps
  + §7 Open Questions
  + (no verdict; no negative-results; no source-map; no coverage-scoreboard)
  ```
  Better: declare in `output-schema.md` which sections are **mandatory** vs **task-type-conditional** (e.g., "§6 Negative Results: only for research/ideation; skip for code-review"). Then the examples just declare which sections they emit.
- **Effort** Medium
- **Impact** Medium
- **Score** 2 (medium ROI; the doc already mostly works, but the cleanup is mechanical)

### Improvement 4 — Define what `--mode thorough` actually does

- **Issue** `SKILL.md:66` defines `--mode` with three values: `quick` / `standard` / `thorough`. Only `thorough` is described as "adds cross-source verification". No file in the rules/ directory elaborates. The provenance run used `standard`; the `research-prior-art.md:148` mentions "Run the skill in `thorough` mode — adds cross-source verification and per-claim evidence ledger (deep/ultradeep research-grade rigor)" — but this is a one-line aside in an example file.
- **Why it matters** A user reading the SKILL.md `--mode` table will pick `thorough` and expect rigor; the skill has no spec for what `thorough` produces. If the implementation is "LLM-assisted cross-source verification," it should be specified: which models verify, against what, with what cost, with what latency. If the implementation doesn't exist, the option should be removed from the table until it does.
- **Concrete change** Add a new file or section:
  ```diff
  + # `--mode thorough` specification
  +
  + The `thorough` mode adds two extra passes after the standard 4-phase pipeline:
  +
  + 1. **Cross-source verification pass.** For each consolidated item, dispatch a "verifier" model (default: the slowest, highest-capability model from the original dispatch) with a prompt: "Here is item X with these N model claims. Verify against the cited sources and flag any claims that the cited source does not support. Return: supported | unsupported | contradicted."
  + 2. **Per-claim evidence ledger.** Append each (claim, source, verification result) triple to `evidence-ledger.md` in the output directory. The ledger is in JSONL format: `{"claim_id": "...", "claim": "...", "source": "...", "verifier": "...", "result": "...", "confidence": "..."}`.
  +
  + **Cost:** `thorough` adds N_items × 1 verifier call. For 36 items × 1 verifier call, expect ~3-5 min additional wall-time (sequential) or ~1 min (parallel).
  + **When to use:** high-stakes decisions (e.g., fact-checking, regulatory research, due diligence). Do not use for routine ideation or code review.
  + **When NOT to use:** latency-critical runs; runs with >100 items (verifier dispatch becomes the bottleneck).
  ```
  Place this in `rules/mode-thorough-spec.md` and link from SKILL.md.
- **Effort** Medium
- **Impact** Medium
- **Score** 2 (medium ROI; the mode is documented, just not specified)

### Improvement 5 — Generate worked examples for code-review and fact-check

- **Issue** Only 1 of 3 examples (`research-prior-art.md`) has a worked example. `code-review.md:92` and `fact-check.md:98` both say "Not yet produced. The pattern is identical to the prior-art research example — just swap the prompt, schema, and conflict rules." But "the pattern is identical" is exactly what the skill *can't* prove without running it. The skill is at v2.0.0; the two unwritten examples are 2/3 of the skill's breadth.
- **Why it matters** "Task-agnostic" is a claim backed by exactly one task type. A skeptical reviewer (or a future contributor) will ask: "If this skill really works for any task, where are the other two runs?" Generating 2 small runs (e.g., a 50-line code review, a 10-claim fact-check) takes ~30 min of wall-time and produces the second-and-third pieces of evidence.
- **Concrete change** Run two small follow-up experiments:
  ```bash
  # 1. Code review example
  /multi-ai-task "Review the file at skills/multi-ai-task/SKILL.md" \
    --models opencode-go/minimax-m3,opencode-go/qwen3.7-max \
    --schema @examples/code-review-schema.json \
    --out docs/examples-2026-06-27/code-review
  
  # 2. Fact-check example
  /multi-ai-task "Verify these claims: [list of 10 claims]" \
    --models opencode-go/minimax-m3,opencode-go/qwen3.7-max,opencode-go/glm-5.2 \
    --schema @examples/fact-check-schema.json \
    --out docs/examples-2026-06-27/fact-check
  ```
  Then link the run outputs from the two example files: replace "Not yet produced" with the actual paths.
- **Effort** High (requires running 2 dispatches + consolidating + writing up)
- **Impact** High
- **Score** 2 (low ROI on the writing; high ROI on the credibility of the task-agnostic claim)

---

## §4. Open Questions

These are the questions a more confident review would need answered:

1. **What is the intended audience of this skill?** The skill's design assumes the user is comfortable with: bash scripting, `npx` invocations, JSON schemas, conflict-resolution algorithms, and the LLM API cost/latency trade-off. That's a power-user audience. But the "What this skill does NOT do" section is aimed at novices. Which audience is the primary one? The prose is for novices; the dispatch example is for experts. The skill is two skills in one trench-coat.

2. **What is the relationship between `--mode` (quick/standard/thorough) and the `Mode A / Mode B` (schema/free-form) axes?** They are orthogonal but both use the word "Mode". The skill does not say whether `thorough + free-form` is valid, or whether `quick` requires a schema, or whether `Mode A` is required for `thorough`. A reader who picks `thorough + free-form` will not know what to expect.

3. **What is the success criterion for a "good" consolidated report?** `consolidation-rules.md:179-186` gives scoring rules but not a "this run was successful" gate. Is the goal "highest median + lowest range across models"? "Lowest number of unresolved conflicts"? "Highest coverage of the user's target buckets"? The skill produces a report but does not say what makes a report *good*. This is a meta-question the skill leaves to the user.

4. **Why is the alias table in `consolidation-rules.md` instead of in `examples/research-prior-art.md`?** The aliases are exclusively from the research run (AutoGen, Camunda, Conductor, etc.). The "task-agnostic" claim in the file header is undermined by having a research-specific alias table in the central file. Either the aliases are part of the skill's general dedup machinery (and the skill is implicitly research-flavored) or they're a research-only artifact (and the file should say so).

5. **What is the "extractor" model when no `--schema` is passed?** `methodology.md:42` says "extractor" model (default: same model). Does this mean each model re-extracts its own output? Or one designated model extracts from all? This is a meaningful choice: if the same model re-extracts, you get consistent but model-biased extraction; if a designated model extracts, you get a cross-model check but you may lose domain knowledge.

6. **Why are the 3 example files in `rules/examples/` (per the file listing I did) and not in a top-level `examples/` directory?** This is a structural question — `AGENTS.md` says "85 canonical skills live under `skills/`" but doesn't say where example files belong. The current location is fine but should be consistent with other skills.

7. **What is the relationship between this skill and the `silver-research` skill?** `silver-research` is described as an "SB queue builder" with FLOW 3-5 composition. `multi-ai-task` is an orchestration pattern. The two could be combined (`silver-research` *uses* `multi-ai-task` as a worker) but the skill files don't describe the integration.

8. **What is the deprecation policy for the alias table?** Aliases are added "as you encounter them" but never removed. Over time, the table grows; eventually it will include stale aliases (e.g., if a product renames). There's no audit or refresh cadence.

9. **What is the cost of running the skill?** `SKILL.md:44` says "Cost of N× compute is acceptable" — but doesn't quantify. For the proven 6-model run with research-prompt (~21 KB), the wall-time was 2-3 min/model, but the dollar cost is unstated. A budget-aware user needs an order-of-magnitude estimate (e.g., "$0.50-$2 per 6-model run, depending on input size").

10. **Why is the self-review happening via the skill itself?** The provenance file `multi-ai-self-review-20260627-083255/` shows the parent orchestrator is using the skill to review the skill. But the skill's Mechanism 1 says it's "rarely works" — and yet the self-review is happening on a harness that uses the `task` tool (`multi-ai-self-review-20260627-083255/ocg-minimax-m3.err` shows the parent is opencode). So either (a) Mechanism 1 is actually working in this harness, contradicting the dispatch-mechanics.md pessimism, or (b) the self-review is using a different mechanism not documented in the skill. This is a meta-question about the skill's own claims.

---

## §5. Confidence

**Overall confidence: Medium-high.**

- I'm confident in the **specific file-level findings** (§1): I cited line numbers, quoted text, and verified cross-references against the filesystem. The broken `deep-research` and `find-skills` references are reproducible via `ls skills/deep-research/` and `ls skills/find-skills/`. The "All 4 scoring matrices" ambiguity is verifiable against the actual report. The Mechanism 1 over-pessimism is verifiable against `OPENCODE_DYNAMIC_SUBAGENT_MODELS.md`.

- I'm less confident in the **scoring** (§2): the 8-dimension rubric is somewhat subjective, and another reviewer might score dimension 7 (SE+DevOps) as 0 or 2 instead of 1, or dimension 8 (team customization) as 2 instead of 1. My 11/16 score is in the right neighborhood but not authoritative.

- I'm less confident in the **prioritization** (§3): the top-5 improvements are ranked by my impact × effort calculation, but another reviewer might rank "fix broken cross-refs" lower than "specify `--mode thorough`" because they weight user-experience differently. The relative ranking is defensible; the absolute scores are not.

**What would change my assessment:**

- If the alias table in `consolidation-rules.md` is *intentionally* research-only and the skill has a separate alias-loading mechanism for other task types (a `--alias-file` flag, perhaps), my "task-agnostic" critique weakens significantly. The skill may be more extensible than the current docs reveal.

- If `--mode thorough` has a written spec I missed (a private file, an external doc, a TODO), Improvement 4 disappears. The skill may already specify it.

- If the 2 unwritten examples are intentionally not generated (e.g., a project policy that "examples must be generated from real production runs, not synthetic ones"), Improvement 5 is moot. The skill may be deliberately avoiding speculative examples.

---

**End of review.** This is read-only; no skill files were modified. Total length: ~30 KB of markdown. Coverage: all 8 files, all cross-references, all 8 rubric dimensions, top 5 improvements with file:line citations, 10 open questions, confidence statement. The review surfaces 5 critical issues (broken cross-refs, Mechanism 1 pessimism, phase numbering, missing `--mode thorough` spec, missing worked examples for 2 of 3 task types) and ~20 minor issues.
