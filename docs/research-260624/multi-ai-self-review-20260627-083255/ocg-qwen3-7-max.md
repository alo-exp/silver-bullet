Now let me check for some cross-file patterns and inconsistencies.
Now I have a thorough understanding of all 8 files and cross-file patterns. Here is the review:

---

# Critical Self-Review: `multi-ai-task` Skill v2.0.0

## §1. Critical Assessment (per file)

### 1. `SKILL.md`

**What works well:**
- Clear "when to use / don't use" table with concrete decision criteria
- Failure modes table is practical and maps symptoms to fixes

**What is missing or wrong:**
- **`--mode thorough` is advertised but never defined.** Line 66: `"thorough" (adds cross-source verification)` — but no file in the skill describes what "cross-source verification" actually means mechanically. It's a phantom feature.
- **`@file.md` syntax is mentioned but never specified.** Line 62: `"Use @file.md to inline a multi-line prompt"` — how does this work? Is it a shell expansion? A skill-internal parser? The reader has no idea.
- **`--concurrency` flag is documented (line 67) but never wired into dispatch.** The dispatch examples in `dispatch-mechanics.md` show raw `for` loops with `&` and `wait` — there's no mechanism to limit concurrency. The flag is vaporware.

**What is unclear or ambiguous:**
- The "Default model discovery" section (line 69-71) says the skill "queries the local OpenCode config and picks a balanced default set of 4-6 models" — but provides no algorithm for what "balanced" means or how to pick.
- Line 136 says the default dispatch is `opencode run --model` but the dispatch-mechanics file lists it as "Mechanism 2" (not Mechanism 1). Minor inconsistency.

### 2. `rules/methodology.md`

**What works well:**
- The 4-phase pipeline is clearly structured and the phase boundaries are logical
- The Mode A / Mode B extraction split is well-motivated

**What is missing or wrong:**
- **Phase 2 Mode A table parsing is underspecified.** Lines 35-38 describe "parse the model's response looking for a markdown table" but the pseudocode in `consolidation-rules.md` (lines 64-73) is a comment-only skeleton with no actual implementation. An orchestrator following this skill would have to invent the parser from scratch.
- **No guidance on what happens when extraction fails entirely.** If a model returns pure prose and Mode A is active, the fallback chain (lines 40-43) says "ask the extractor model to reformat" but never specifies what happens if the reformat also fails.
- **`run-manifest.json` schema (lines 93-115) includes `task_prompt_hash` but never explains its purpose.** Is it for idempotency? For cache lookup? For audit?

**What is unclear or ambiguous:**
- Line 15: "the skill does NOT auto-append it" — what is "it"? The schema? The schema-as-constraint? This sentence is confusing.

### 3. `rules/dispatch-mechanics.md`

**What works well:**
- Honest about Mechanism 1 being "BEST, but rarely works" — practical realism
- The choosing-the-right-mechanism decision table (lines 132-139) is genuinely useful

**What is missing or wrong:**
- **All examples use `--dangerously-skip-permissions` with only a one-line caveat.** Line 48: "fine for non-destructive research tasks" — but the skill is task-agnostic. A code-review dispatch might need file read access; a fact-check might need web access. The security implications of `--dangerously-skip-permissions` for non-research tasks are unaddressed.
- **Mechanism 3 (HTTP SDK) references a known bug (line 66, "Issue #18615") but provides no link, no status, and no workaround beyond "use mechanism 2."** This is a dead reference.
- **No guidance on model selection strategy.** The file tells you HOW to dispatch but never helps you decide WHICH models to pick for a given task type. For a skill that claims "model diversity" as a core value, this is a significant gap.

**What is unclear or ambiguous:**
- Line 91: "parallel (with 10-min shell timeout) worked" — where is this timeout set? The bash tool's `timeout` parameter? The `--timeout` flag on `opencode run`? Unclear.

### 4. `rules/consolidation-rules.md`

**What works well:**
- The dedup algorithm pseudocode (lines 100-116) is concrete and implementable
- The `prefer-with-evidence-then-newer-then-strict` rule is well-specified with 5 ordered steps

**What is missing or wrong:**
- **7 custom conflict resolution rules are referenced in examples but NEVER defined here.** The examples use `most-severe`, `majority-with-uncertain`, `lowest-of-majors`, `concatenate-all`, `merge-exact`, `union-dedup`, and `all-collected` — none of these appear in the default rules table (lines 146-153) or anywhere else in this file. An orchestrator encountering these in a user's `--schema` would have to guess at their semantics.
- **The alias table (lines 254-274) is entirely research-specific.** Every alias (AutoGen, BMAD, Camunda, Conductor, etc.) is from the prior-art research example. For a "task-agnostic" skill, this is domain leakage. A code-review run would never use these aliases, and a fact-check run would be confused by them.
- **The skip rules (lines 118-123) are also research-specific.** `"Silver Bullet (ref)"` and `"Candidate"` as skip entries only make sense for the prior-art research task.
- **Fuzzy match threshold (line 133: "≥80% similar") is arbitrary and unvalidated.** No guidance on when to tighten or loosen it.

**What is unclear or ambiguous:**
- Line 160: "prefer `direct` only if ≥3 evidence criteria are met" — what are the "evidence criteria"? This is defined implicitly by the research context but never formally specified.

### 5. `rules/output-schema.md`

**What works well:**
- The WYSIWYG formatting rules (lines 224-235) are unusually practical — most skills ignore viewer compatibility
- The two-mode (structured vs generic) output split is clean

**What is missing or wrong:**
- **§3 (Per-Item Details, lines 100-108) is research-specific.** The template uses `gaps_vs_reference` and `reference_gaps_vs_them` — these are prior-art research concepts that make no sense for code review or fact-checking. This is a direct contradiction of the "task-agnostic" claim.
- **`consolidated.html` generation is promised but never specified.** Line 79-81 in methodology.md says "Self-contained HTML render" but no file provides: an HTML template, CSS styles, a conversion algorithm, or a tool recommendation. The orchestrator is expected to invent HTML generation from scratch.
- **§5 (Aggregated Scores) assumes a scoring rubric exists but the skill provides no mechanism for the user to pass one.** The `--schema` parameter supports column definitions and conflict rules, but not a scoring rubric with dimensions and levels. The research example (lines 99-113) shows a rubric JSON, but it's passed ad-hoc, not via any documented parameter.

**What is unclear or ambiguous:**
- §8 (Synthesized Verdict, line 154-156) says "if the user asked for a specific output" — how does the skill detect this? Is it a flag? Inferred from the prompt? This section is too vague to implement.

### 6. `rules/examples/research-prior-art.md`

**What works well:**
- This is the most complete and concrete file in the skill — it shows the actual dispatch command, the actual schema, and the actual output structure
- The "Variations to try" section (lines 143-148) is genuinely useful for iteration

**What is missing or wrong:**
- **The research prompt template (lines 32-63) is a skeleton, not a real prompt.** It says `[subject description, table of layers, differentiators, architecture]` — placeholders, not guidance on how to fill them.
- **The scoring rubric (lines 99-113) is presented as part of the example but is actually the ONLY place in the entire skill where a scoring rubric is defined.** If a user wants to use scoring for a non-research task, they have no template.
- **Line 145: "8-10 models captures more unique finds but diminishing returns past 6" — this is asserted without evidence.** The proven run used 6 models; there's no data to support the claim about 8-10.

**What is unclear or ambiguous:**
- No issues beyond the above.

### 7. `rules/examples/code-review.md`

**What works well:**
- The custom strategy table (lines 76-82) is clear and well-justified
- The schema example correctly demonstrates task-specific conflict resolution overrides

**What is missing or wrong:**
- **References 5 undefined conflict resolution rules** (`most-severe`, `concatenate-all`, `merge-exact`, `majority`, `longest-with-quote`) — only `majority` and `longest-with-quote` are defined in consolidation-rules.md. The others are used but never specified.
- **No worked example exists.** Line 93: "Not yet produced." For a skill at v2.0.0, having 2 of 3 examples be unproduced is a credibility gap.
- **The dispatch example (lines 14-32) doesn't show how the model accesses the code to review.** The prompt says "Review the file at /path/to/code.py" but `opencode run` with `--dangerously-skip-permissions` doesn't automatically give the model file access. The example is incomplete.

**What is unclear or ambiguous:**
- Line 70: "§5 Per-Reviewer Statistics" mentions "false-positive rate if measurable" — measurable how? Against what ground truth?

### 8. `rules/examples/fact-check.md`

**What works well:**
- The consensus requirements section (lines 89-95) is well-designed with clear thresholds
- The `majority-with-uncertain` rule is a genuinely novel and useful conflict resolution strategy

**What is missing or wrong:**
- **References 4 undefined conflict resolution rules** (`majority-with-uncertain`, `lowest-of-majors`, `all-collected`, `union-dedup`) — none are defined in consolidation-rules.md.
- **No worked example exists.** Line 99: "Not yet produced."
- **The dispatch example doesn't explain how models verify facts.** Models without web access can't verify claims against "official/primary" sources. The example assumes capabilities that depend on the dispatch mechanism but doesn't say so.

**What is unclear or ambiguous:**
- Line 63: "require ≥3 votes for a clean verdict" — what happens with 2 models? The example dispatches 3 models, so a 2-1 split is possible. Does it become `partially-true` or `unverified`?

---

## §2. Score the Skill on the 8-Dimension Rubric

| Dimension | Score | Justification |
|---|---|---|
| **Catalog of composable units** | 1 | The skill defines informal roles (dispatch, extraction, consolidation, synthesis) but they're not machine-readable or independently invocable. The 4 phases are described in prose, not as a composable catalog with inputs/outputs/contracts. |
| **Dynamic composition** | 0 | No replanner. The 4 phases always execute in fixed order. The `--mode` flag (quick/standard/thorough) selects a preset pipeline variant but doesn't dynamically compose steps based on intermediate results. |
| **V-loop depth** | 1 | The skill has a "conflicts can't be resolved → present all" exit gate (SKILL.md line 169), which is an end-test. But there's no per-step rollup, no intent gate checking whether the consolidation is "good enough," and no feedback loop from Phase 4 back to Phase 2. |
| **Enforcement** | 0 | Honor system entirely. No CI gates, no IDE hooks, no delivery blockers. The skill describes what to do but provides zero enforcement that it was done correctly. The `run-manifest.json` is an audit trail, not an enforcement mechanism. |
| **Parent/worker split** | 2 | Explicit orchestrator/worker design. The parent (skill invoker) handles dispatch, capture, and consolidation; each model is a stateless worker receiving the same prompt. The split is clearly documented. |
| **Evidence model** | 1 | Informal. The skill tracks `source_refs`, `confidence_self`, and per-model evidence quotes, but there's no tiered sufficiency model, no staleness detection, and no evidence completeness check. The `prefer-with-evidence-then-newer-then-strict` rule references evidence quality but doesn't define how to measure it. |
| **SE + DevOps unified** (covers both production task types) | 0 | The skill covers neither specifically. It's task-agnostic by design, which means it handles research well (proven) but has no domain-specific support for SE tasks (code review example is unproduced) or DevOps tasks (no example at all). |
| **Team customization** (supports team process packs) | 0 | No overlay mechanism. The `--schema` parameter allows per-run customization, but there's no concept of a "team process pack" or persistent configuration that a team could share. Every run requires the user to re-specify schema, conflict rules, and model selection. |

**Total: 5/16**

---

## §3. Top 5 Improvements (ranked by impact × effort)

### 1. Define all referenced conflict resolution rules

- **Issue:** 7 conflict resolution rules (`most-severe`, `majority-with-uncertain`, `lowest-of-majors`, `concatenate-all`, `merge-exact`, `union-dedup`, `all-collected`) are used in examples but never formally defined in `consolidation-rules.md`.
- **Why it matters:** An orchestrator following this skill cannot implement these rules — they're referenced by name but have no specification. This makes the examples unimplementable.
- **Concrete change:** `rules/consolidation-rules.md` after line 153 — add a new subsection:

```markdown
### Extended conflict resolution rules (for task-specific schemas)

| Rule | Applies to | Algorithm |
|------|-----------|-----------|
| `most-severe` | enum (ordered) | Pick the value with highest severity in the declared enum order (first = most severe) |
| `majority-with-uncertain` | enum | If majority exists AND ≥3 votes, use majority; else use designated "uncertain" value |
| `lowest-of-majors` | enum (confidence) | Among models holding the majority verdict, use the lowest confidence value |
| `concatenate-all` | text | Join all values with `\n---\n`; do not deduplicate |
| `merge-exact` | string (key) | Values must be identical; if not, flag as unresolvable conflict |
| `union-dedup` | url_list | Union of all URL lists; deduplicate by normalized URL |
| `all-collected` | text | Concatenate all values; deduplicate by source URL when available |
```

- **Effort:** Low
- **Impact:** High
- **Score:** High ROI

### 2. Define `thorough` and `quick` modes mechanically

- **Issue:** `--mode thorough` is advertised (SKILL.md:66) and referenced in examples but never defined. `--mode quick` gets one sentence (methodology.md:138).
- **Why it matters:** Users will pass `--mode thorough` expecting cross-source verification, and the orchestrator has no specification to implement. This is a phantom feature.
- **Concrete change:** `rules/methodology.md` after line 141 — add:

```markdown
## Mode variants

### `quick` mode
Skip Phase 3 entirely. Concatenate per-model outputs into `consolidated.md` with section headers per model. No dedup, no conflict resolution, no score aggregation. Useful for getting raw multi-model output fast.

### `standard` mode (default)
Full 4-phase pipeline as documented above.

### `thorough` mode
Adds a Phase 3.7 — Cross-Source Verification:
1. For each consolidated item, extract all cited source URLs
2. Re-fetch each URL (via `ctx_fetch_and_index`) and verify the cited claim appears in the source
3. Tag items as `verified` (claim found in source), `unverified` (source inaccessible or claim not found), or `contradicted` (source says opposite)
4. Add a `verification_status` column to the items table
5. Items with `contradicted` status are flagged in `conflicts.md` for human review

This mode adds significant latency (N items × M sources fetches) but provides evidence-grade output.
```

- **Effort:** Medium
- **Impact:** High
- **Score:** High ROI

### 3. Remove research-specific content from generic files

- **Issue:** The alias table (consolidation-rules.md:254-274), skip rules (lines 118-123), and output-schema §3 template (`gaps_vs_reference`, `reference_gaps_vs_them`) are all from the prior-art research example, leaking domain specifics into "task-agnostic" files.
- **Why it matters:** A code-review or fact-check orchestrator following these files will encounter irrelevant aliases and research-specific field names, causing confusion and potential mis-extraction.
- **Concrete change:**
  - `rules/consolidation-rules.md` lines 254-274: Move the alias table to `rules/examples/research-prior-art.md` and replace with:
    ```markdown
    ## Aliases (canonical resolution table)
    The alias map is task-specific. Populate it during your first run based on the domain.
    For research tasks, see `rules/examples/research-prior-art.md` for a pre-built alias table.
    ```
  - `rules/consolidation-rules.md` lines 118-123: Replace research-specific skip entries with generic guidance:
    ```markdown
    Mark a row's primary key as `aliases[n] = null` to drop it:
    - Placeholder rows (e.g., "Candidate", "N/A", "—")
    - Header rows that were incorrectly parsed as data
    - The reference item itself (if the task compares candidates against a reference)
    ```
  - `rules/output-schema.md` lines 100-108: Replace `gaps_vs_reference` / `reference_gaps_vs_them` with generic fields:
    ```markdown
    - **<Canonical>**: <task-specific per-item analysis fields>
    ```
- **Effort:** Low
- **Impact:** Medium
- **Score:** Medium-high ROI

### 4. Specify HTML generation or remove the promise

- **Issue:** `consolidated.html` is listed in the output structure (SKILL.md:116), described in methodology.md (lines 79-81), and referenced in the research example (line 131), but no file provides a template, CSS, or conversion logic.
- **Why it matters:** The orchestrator is expected to produce an HTML file but has zero guidance on how. This either results in no HTML output (broken contract) or ad-hoc HTML that varies per run.
- **Concrete change:** Either:
  - (A) Add a minimal HTML template to `rules/output-schema.md` after line 235:
    ```markdown
    ## HTML generation
    Convert `consolidated.md` to `consolidated.html` using a markdown-to-HTML library (e.g., `marked` in Node, `markdown` in Python). Embed the following CSS inline:
    [minimal CSS for tables, conflict markers, and section headers]
    ```
  - (B) Remove `consolidated.html` from the output structure and mark it as a future enhancement.
- **Effort:** Low (option B) / Medium (option A)
- **Impact:** Medium
- **Score:** Medium ROI

### 5. Add a model selection strategy section

- **Issue:** The skill tells you HOW to dispatch (4 mechanisms) but never helps you decide WHICH models to pick. For a skill whose core value proposition is "model diversity," there's no guidance on achieving it.
- **Why it matters:** A user dispatching 6 models from the same provider family (e.g., all OCG) gets less diversity than 4 models from 4 different families. The skill doesn't help the user make this tradeoff.
- **Concrete change:** `rules/dispatch-mechanics.md` after line 139 — add:

```markdown
## Model selection strategy

For maximum diversity, pick models from different provider families:
- **Reasoning-heavy tasks** (research, fact-check): include at least one reasoning-focused model (e.g., deepseek-v4-pro) and one generalist (e.g., qwen3.7-max)
- **Creative tasks** (ideation, writing critique): maximize provider diversity; same-family models produce similar creative output
- **Code tasks**: include at least one code-specialized model if available; code-review benefits from models trained on different code corpora

Avoid: dispatching >2 models from the same provider family (diminishing diversity returns).
Minimum viable: 2 models from different families. Below 2, the skill adds no value.
```

- **Effort:** Low
- **Impact:** Medium
- **Score:** Medium ROI

---

## §4. Open Questions

1. **Who is the orchestrator?** The skill describes what "the skill" does, but it's a markdown skill — it's instructions for an LLM agent. Is the agent expected to implement the 4-phase pipeline itself (writing parsers, running dedup, generating HTML)? Or is there a code implementation somewhere that the skill wraps? If the agent IS the implementation, the skill needs to be much more prescriptive about the mechanics.

2. **What harness versions does this target?** The dispatch mechanics reference specific bugs ("Issue #18615"), specific tool limitations ("task tool rejects custom types"), and specific CLI flags (`npx opencode-ai run`). These are point-in-time observations. Is the skill expected to be updated as harness capabilities change?

3. **Is the proven run reproducible?** The skill claims provenance from a 2026-06-27 run, but the actual prompt (`SB_PRIOR_ART_USER_PROMPT.md`), outputs, and conflicts are in `docs/research-260624/` — not in the skill directory. If those files are moved or deleted, the provenance claim becomes unverifiable.

4. **What is the cost model?** Dispatching 6 models in parallel costs 6× the single-model cost. The skill never discusses budget limits, cost estimation, or when the marginal value of an additional model justifies its cost.

5. **Is the skill meant to be invoked by humans or by other agents?** The `user-invocable: true` frontmatter suggests human invocation, but the meta-review context (an agent using this skill to review itself) suggests agent invocation. The skill doesn't distinguish between these audiences.

---

## §5. Confidence

- **Overall confidence:** **Medium**
- **What would change your assessment:** (1) If a code implementation of the consolidation pipeline exists (not just markdown instructions), several "undefined" issues become non-issues — I'd need to see it. (2) If the 2 unproduced examples (code-review, fact-check) have been run informally but just not documented, the credibility gap narrows significantly. (3) If the `thorough` and `quick` modes were intentionally left as "future enhancement" stubs rather than advertised features, the phantom-feature concern drops.
