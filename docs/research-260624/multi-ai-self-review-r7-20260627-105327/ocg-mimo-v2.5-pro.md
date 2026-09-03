I'll read all 8 skill files in parallel to begin the review.
Now let me check for cross-file inconsistencies more precisely.
Now I have all the data. Here is the critical review.

---

# Critical Self-Review: multi-ai-task Skill (v2.1.0)

---

## §1. Critical Assessment

### SKILL.md

**What works well:**
- The when-to-use / when-not-to-use table (lines 35-42) is concise and actionable.
- The failure modes table (lines 248-258) is practical — each row has symptom/cause/fix.

**What is missing or wrong:**
1. **Phase numbering mismatch with the mode table.** Line 77 labels columns `Phase 1 (dispatch) | Phase 2 (extract) | Phase 3 (consolidate) | Phase 4 (synthesize)`. But `consolidation-rules.md` uses Phase 2/3/4/5 for the same work. A reader cross-referencing the files gets conflicting phase numbers for the same step.
2. **`--mode quick` semantics are contradictory.** Line 79 says quick mode does "Basic (table parse, no fuzzy match)" for Phase 2 and "Dedup only, no conflict resolution" for Phase 3. But the "What this skill does" list (line 20) says the skill "Resolves disagreements across models (with documented tie-break rules)" — no qualifier for mode. The skill's value proposition is overstated for quick mode.
3. **No CHANGELOG.** The frontmatter says `version: 2.1.0` but nowhere in the skill is there a changelog documenting what changed from 2.0.0 to 2.1.0. The `--no-auto-inject` flag, `aliases` field, and `phases_completed` field are all marked as "v2.1.0+" in scattered locations but never collected.

### rules/methodology.md

**What works well:**
- The extraction pseudocode (lines 37-64) is concrete and implementable — 4 fallback paths with clear ordering.
- The "Deterministic + LLM-assisted hybrid" principle (lines 156-161) is honest about where LLMs are in the loop.

**What is missing or wrong:**
1. **Phase numbering diverges from consolidation-rules.md.** This file uses Phase 1/2/3/4 (lines 7, 23, 108, 122). `consolidation-rules.md` uses Phase 2/3/4/5 (lines 26, 78, 136, 267). The boundaries don't align: Phase 3 here ("Cross-model consolidation") encompasses both dedup AND conflict resolution, which are Phases 3 and 4 in consolidation-rules.md. Phase 4 here ("Final synthesis") is Phase 5 there. A reader can't tell which numbering is canonical.
2. **The "Idempotent re-runs" claim (line 172) is misleading.** It says "the skill can be re-run with the same task-prompt and produce a new consolidated output" — but also says "It does NOT cache across runs." That's not idempotency; that's just re-running. True idempotency would produce *identical* output for identical input, which is impossible with LLMs.
3. **The extractor model logic is underspecified.** Line 104 says the extractor is "the slowest/highest-capability model from the original dispatch." How is "slowest" determined? By prior benchmark? By model family heuristic? This needs a concrete selection algorithm.

### rules/dispatch-mechanics.md

**What works well:**
- The 4 mechanisms ranked by preference with real issue references (line 28: issues #6651, #11215, etc.) add credibility.
- The MCP port collision caveat (lines 113-114) is a real operational concern, well-documented.

**What is missing or wrong:**
1. **Mechanism 2's `$PROMPT` variable is undefined in the example.** Line 56 uses `"$PROMPT"` but the script never assigns it. The comment says "Substitute the path to the user's research prompt file" but the code doesn't show the substitution. A copy-paste user gets an empty prompt.
2. **The auth table (lines 148-155) is misleading for OpenRouter-hosted models.** The table lists `opencode-go/*` as using `opencode auth login`, but the models in the examples (minimax-m3, qwen3.7-max, etc.) are hosted on OpenRouter, not directly on OpenCode. The auth path is `opencode auth login` → OpenRouter token, not a direct provider key. This distinction matters when debugging auth failures.
3. **No guidance on detecting MCP port collisions.** Line 113 says "Sequential alone doesn't fix port collision if the MCP binds a port on first start and holds it" but provides no diagnostic command (e.g., `lsof -i :3111`) or symptom to detect the collision.

### rules/consolidation-rules.md

**What works well:**
- The named rule library (lines 167-222) is the skill's strongest asset. Each rule has purpose, input, algorithm, and edge cases — implementable as-is.
- The `most-severe` rule's `allow_downgrade` design (line 171) with the "don't downgrade a blocker" safety principle is well-reasoned.

**What is missing or wrong:**
1. **Phase numbering is chaotic and conflicts with methodology.md.** This file labels phases as 2/3/4/5 (ALIGN, DEDUP, RESOLVE, SCORE). `methodology.md` labels them as 1/2/3/4. `SKILL.md`'s mode table uses 1/2/3/4 with different boundaries. Three files, three incompatible numbering schemes for the same pipeline.
2. **The `prefer-with-evidence-then-newer-then-strict` rule assumes `last_verified` exists.** Line 159 says "Check the source date for the candidate's evidence." But the schema may not have a `last_verified` field (the code-review schema doesn't). What happens when the field is absent? The rule's behavior is undefined.
3. **Fuzzy match threshold (80%, line 132) is arbitrary.** No guidance on tuning it. For task types with short item names (e.g., "BMAD" vs "BMAD Method"), 80% token-overlap may be too high; for long names, it may be too low.

### rules/output-schema.md

**What works well:**
- The `run-manifest.json` schema (lines 211-236) is concrete with field semantics documented.
- The markdown formatting rules (lines 258-268) are practical for WYSIWYG compatibility.

**What is missing or wrong:**
1. **Claims to be "the canonical schema" but is missing 4 v2.1.0 fields.** Line 209 says "This is the canonical schema." But `phases_completed` (line 235) is present, while `schema_auto_injected` (mentioned at SKILL.md:155 and methodology.md:15) and `aliases` (mentioned at consolidation-rules.md:333) are documented only as "v2.1.0+" notes, not as required fields in the schema block. The "canonical" claim is false — the schema is incomplete.
2. **Section numbering in consolidated.md is confusing.** §2A and §2B (lines 53-96) are mutually exclusive based on mode, but they're presented as separate sections. A reader seeing "§2A" in the schema and "§2" in an actual output won't know if §2B was omitted or if the numbering collapsed.
3. **`consolidated.html` generation is underspecified.** Line 205 says "convert consolidated.md to HTML using a markdown library (marked in Node, markdown in Python, pandoc for richer output)." This assumes the implementing agent has access to these libraries. No fallback if none are available.

### rules/examples/research-prior-art.md

**What works well:**
- The complete dispatch script (lines 13-33) is copy-pasteable with real model IDs.
- The 14-entry alias map (lines 127-141) is concrete and reusable.

**What is missing or wrong:**
1. **The prompt template (lines 37-68) is full of placeholders.** `[subject description, table of layers, differentiators, architecture]`, `[2A direct prior art, 2B adjacent categories, ...]` — these are section descriptions, not fillable templates. A user can't construct a prompt from this without significant interpretation.
2. **No output snippet.** The "Worked example" section (lines 169-178) points to file paths but shows zero actual output. For a "proven" example, the absence of even a 5-row table excerpt is a missed opportunity for calibration.
3. **The scoring rubric (lines 104-118) has no mapping algorithm.** It defines 8 dimensions with 3 levels each (0/1/2) but doesn't explain how to map a model's qualitative text response to a numeric 0-2 score. Is it the consolidator's judgment? An LLM call? Deterministic keyword matching?

### rules/examples/code-review.md

**What works well:**
- The composite key schema (lines 49-65) with `file` + `line` as dual `dedup_key: true` is a clear, correct example.
- The security note about `--dangerously-skip-permissions` (line 45) is appropriately cautious.

**What is missing or wrong:**
1. **The dispatch example uses only 2 models (line 33).** With 2 models, `majority` conflict resolution produces ties (2 different values → no majority). The skill recommends 4-6 models. The example contradicts the guidance.
2. **No worked example.** Line 111: "Not yet produced (deferred to v2.2.0)." The second-most-concrete use case has no proven run. The "task-agnostic" claim rests on one example.
3. **Line-number instability is unaddressed.** Code review findings reference `line` numbers, but if the code changes between dispatch and consolidation (e.g., a file is edited mid-run), the composite key `(file, line)` becomes unreliable. No mitigation is documented.

### rules/examples/fact-check.md

**What works well:**
- The `majority-with-uncertain` rule explanation (lines 73-74) with the `> max(2, ceil(N/2))` formula is precise.
- The consensus requirements section (lines 102-108) is practical for high-stakes use.

**What is missing or wrong:**
1. **No worked example.** Line 113: "Not yet produced (deferred to v2.2.0)." Same gap as code-review.
2. **Changelog entry embedded in example file.** Line 77: "`sources: 'url_list'` is now formally defined in the schema spec (was a v2.1.0 gap)." Version history belongs in a changelog, not scattered across example files.
3. **No guidance on claim volume.** The prompt template (lines 20-35) shows 3 placeholder claims but doesn't discuss scaling. How does consolidation change with 5 claims vs 50? Does the verifier in `thorough` mode scale linearly?

---

## §2. Score the Skill on the 8-Dimension Rubric

| Dimension | Score | Justification |
|---|---|---|
| **Catalog of composable units** | **1** | The named rule library (10 rules) and 4 dispatch mechanisms exist, but they're prose algorithms, not a machine-readable catalog you can query or compose programmatically. No registry, no API surface. |
| **Dynamic composition** | **1** | Model auto-discovery (SKILL.md:72-73) and mode-based pipeline selection exist, but there's no audit log of composition decisions and no catalog-backed selection. The "balanced default set" algorithm is described in prose, not code. |
| **V-loop depth** | **1** | The 4-phase pipeline exists, but there's no per-step verification or intent gate. Row validation (methodology.md:70-72) drops invalid rows, but there's no "does this extraction look right?" checkpoint before consolidation. The pipeline is linear, not a V-model. |
| **Enforcement** | **1** | Schema validation enforces column types and required fields. But there's no CI integration, no IDE hooks, no delivery blockers. Enforcement is runtime-only (drop invalid rows with a warning). |
| **Parent/worker split** | **2** | Explicit: the orchestrator (skill core) dispatches, extracts, consolidates, synthesizes. Workers (N models) have defined output contracts (structured.jsonl schema). Fail-soft design preserves partial results. The "extractor model" is a designated fallback worker. |
| **Evidence model** | **1** | `source_refs` tracks per-row provenance. `thorough` mode adds `evidence-ledger.md` with per-claim source verification. But there's no staleness detection (a 2-year-old source is treated the same as today's), and evidence sufficiency is informal (no minimum-source threshold in the core rules). |
| **SE + DevOps unified** | **1** | The skill handles code review (SE) and fact-check (DevOps-adjacent) with different schemas, but they're separate examples with no shared model. The core pipeline is task-agnostic, but the "unified" claim means the same pipeline handles both — which it does, trivially, by being generic. That's not unification; it's indifference. |
| **Team customization** | **1** | Custom `--schema` and `conflict_resolution` overrides exist. But there's no "overlay pack" mechanism — a team must pass the full schema every time. No named presets, no team-level defaults, no inheritance. |

**Total: 9/16**

---

## §3. Top 5 Improvements (ranked by impact × effort)

### 1. Fix phase numbering across all files

- **Issue:** Three files use incompatible phase numbers for the same pipeline steps.
- **Why it matters:** Implementors reading files independently can't tell which phase is which. This is the #1 source of confusion in the skill's own prior self-reviews (flagged in both self-review.md and critical-review-r3.md, still unfixed).
- **Concrete change:** Standardize on a single numbering in all 5 rule files. Proposed canonical mapping:

  | Current (methodology.md) | Current (consolidation-rules.md) | Proposed |
  |---|---|---|
  | Phase 1 | — | Phase 1: Dispatch |
  | Phase 2 | Phase 2 | Phase 2: Extract |
  | Phase 3 | Phase 3 + Phase 4 | Phase 3: Dedup, Phase 4: Resolve |
  | Phase 4 | Phase 5 | Phase 5: Synthesize |

  Update `SKILL.md:77` mode table, `methodology.md` headings, `consolidation-rules.md` headings, and `output-schema.md` references.
- **Effort:** Low (file edits only, no logic changes)
- **Impact:** Medium (removes a persistent confusion)
- **Score:** medium/low = high ROI

### 2. Add worked examples for code-review and fact-check

- **Issue:** Both non-research examples are stubs ("Not yet produced (deferred to v2.2.0)").
- **Why it matters:** The "task-agnostic" claim is the skill's core value proposition. It rests on one proven example (research). Two of three example types are unverified. Users evaluating the skill for code-review or fact-check have no output to calibrate against.
- **Concrete change:** Run the skill with the code-review schema on a real file (e.g., one of the skill's own files) and the fact-check schema on 3-5 real claims. Capture the output in `docs/` and update `code-review.md:109-111` and `fact-check.md:111-113` with links and 10-row excerpts.
- **Effort:** Medium (requires 2 actual skill runs + output capture)
- **Impact:** High (validates the core claim)
- **Score:** high/medium = high ROI

### 3. Fix the `$PROMPT` variable in dispatch-mechanics.md Mechanism 2

- **Issue:** The bash example (line 56) uses `"$PROMPT"` but never assigns it.
- **Why it matters:** This is the default dispatch mechanism. A copy-paste user gets an empty prompt sent to all models, producing garbage output. The research example (research-prior-art.md:20) shows the correct pattern (`PROMPT="$(cat /path/to/file)"`) but the canonical Mechanism 2 documentation doesn't.
- **Concrete change:** In `dispatch-mechanics.md`, add before line 50:
  ```bash
  # Load the prompt from a file (avoid shell metacharacter issues)
  PROMPT="$(cat /path/to/your-prompt.md)"
  ```
  And update the comment at line 56 to reference this.
- **Effort:** Low (2-line edit)
- **Impact:** Medium (prevents a copy-paste failure)
- **Score:** medium/low = high ROI

### 4. Define the `run-manifest.json` schema in exactly one place

- **Issue:** The schema is defined in `output-schema.md:211-236` (claimed canonical) but also referenced in `methodology.md:145-147` (which redirects to output-schema.md) and `SKILL.md:218` (which defines `phases_completed`). The output-schema.md version is missing `schema_auto_injected` and `aliases` as required fields despite them being marked "v2.1.0+" elsewhere.
- **Why it matters:** Implementors don't know which file to trust. The "canonical" file is incomplete.
- **Concrete change:** In `output-schema.md`, add `schema_auto_injected` and `aliases` to the JSON schema block (lines 211-236) as required fields. In `methodology.md:145-147`, delete the cross-reference and replace with: "The `run-manifest.json` schema is defined in `rules/output-schema.md`. Do not duplicate." In `SKILL.md:218`, remove the inline field definition and add a pointer to output-schema.md.
- **Effort:** Low (edits to 3 files, no logic changes)
- **Impact:** Medium (eliminates conflicting definitions)
- **Score:** medium/low = high ROI

### 5. Define the free-form extraction fallback more precisely

- **Issue:** The "first 5 words of paragraph" primary key (methodology.md:97) is acknowledged as fragile. The 80% fuzzy match threshold (consolidation-rules.md:132) is arbitrary. The H2-heading split (methodology.md:83-84) doesn't handle non-item H2s like "Summary" or "Conclusion."
- **Why it matters:** Free-form mode is the default when no `--schema` is passed. The extraction quality determines consolidation quality. If the primary key is wrong, dedup fails silently (items that should merge don't, or items that shouldn't merge do).
- **Concrete change:** Add to `methodology.md` after line 99:
  ```
  **Free-form extraction caveats:**
  - H2 headings like "Summary", "Conclusion", "Appendix" are NOT items — skip them.
    Only H2s that introduce a distinct entity/topic are items.
  - The "first 5 words" primary key is a last resort. Prefer H2 headings > numbered list
    items > paragraph first-sentence. Tag any "first 5 words" key with `fuzzy_match: true`.
  - The 80% fuzzy threshold is a starting point. For task types with short item names
    (e.g., "BMAD" = 4 chars), lower to 60%. For long names, 80% is fine.
  ```
- **Effort:** Low (documentation addition)
- **Impact:** Medium (reduces silent dedup failures)
- **Score:** medium/low = high ROI

---

## §4. Open Questions

1. **What is the actual version?** SKILL.md frontmatter says 2.1.0. The task context says v2.0.0. fact-check.md:77 references a "v2.1.0 gap" fix. Is there a changelog? What changed between versions?

2. **Has the skill been run beyond the one proven research example?** The code-review and fact-check examples are stubs. Has anyone actually dispatched a code-review task and consolidated the output? If so, where are the results?

3. **How does the extractor model selection work in practice?** "The slowest/highest-capability model from the original dispatch" — is this determined by model family heuristics (e.g., "deepseek-v4-pro is slow"), by prior timing data, or by configuration?

4. **What happens when consolidation itself fails?** The skill documents model failures (fail-soft), but what if the consolidation step itself errors — e.g., the dedup algorithm hits an unexpected data shape, or the conflict resolution rule returns `null` for all fields? Is there a fallback to raw output?

5. **How does the skill handle models that return structured data in incompatible formats?** If one model returns a markdown table and another returns a JSON blob inside `<structured>` tags and a third returns prose — the extraction pseudocode handles each path, but the cross-model merge assumes normalized `structured.jsonl` records. Is there validation that the extracted records are actually comparable before consolidation?

6. **What is the consolidation wall-time budget?** The skill says "latency of slowest model + consolidation" but gives no bounds. For 36 items × 6 models, how long does Phase 3-5 take? Without this, users can't evaluate the "When NOT to use" latency criterion.

7. **The `consolidated.html` generation references `marked` (Node) and `markdown` (Python).** Which runtime does the skill expect? If the implementing agent is a bash script with no Node/Python available, does HTML generation fail silently?

---

## §5. Confidence

- **Overall confidence:** Medium-high

- **What would change my assessment:**
  - If someone showed me a working code-review or fact-check run with real output, I'd upgrade the "task-agnostic" claim from "plausible but unproven" to "validated." This would raise the SE+DevOps score from 1 to 2 and the total from 9 to 10.
  - If the phase numbering were fixed and a changelog existed, I'd have higher confidence that the skill is maintained vs. incrementally patched. The existence of 3 prior self-review files (self-review.md, critical-review-r3.md, critical-review-r4.md) in the directory — all flagging the same phase numbering issue — suggests the reviews are produced but the fixes aren't applied.
