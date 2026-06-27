I've read all 8 files plus the 4 prior review iterations (self-review.md, critical-review-r3.md, critical-review-r4.md, and the consolidated R3 self-review at `multi-ai-self-review-r3-20260627-critical.md`). I also cross-checked the actual content of the files against claims made in prior reviews. The current review is the **5th round** of self-review and the first that arrives after 4 prior rounds — some of which have **stale or incorrect claims** that need to be addressed, not just added to.

---

# Critical Self-Review: multi-ai-task Skill (Round 5)

**Review date:** 2026-06-27
**Reviewed version:** 2.1.0 (SKILL.md frontmatter; prior reviews and the task brief disagree on whether this is v2.0.0 or v2.1.0 — see §1.1)
**Reviewer:** Independent critical review (direct read + cross-reference analysis + algorithm walkthrough)
**Prior reviews:** `self-review.md` (R1), implicit R2, `multi-ai-self-review-r3-20260627-critical.md` (R3 — the strongest prior review), `critical-review-r3.md` (R3 again, abbreviated), `critical-review-r4.md` (R4 — weakest, contains incorrect claims)
**This review's focus:** (a) **unfixed findings from R3 that R4 missed**; (b) **incorrect claims in R4 that are now propagating**; (c) new findings from a fresh pass on the current file contents; (d) cross-file contradictions in the current file set, not just in the prior reviews.

---

## §1. Critical Assessment

### 1.1 SKILL.md (255 lines)

**What works well:**

- The "When to use / When NOT to use" decision matrix (lines 35-50) is the most honest and concrete entry-point in the SB skill ecosystem. It states actual tradeoffs ("Cost of N× compute is acceptable", "Latency is critical") instead of marketing. This is the kind of guidance that prevents misuse.
- The mode semantics table (lines 77-81) cleanly maps `--mode` values to what each phase skips/adds. A reader can decide between `quick`/`standard`/`thorough` from the table alone.

**What is missing or wrong:**

- **The "What this skill does NOT do" list at lines 25-29 contradicts the auto-inject default.** Line 23 (in the "does" list) says: `Auto-injects the schema into every dispatch prompt (by default ON; pass --no-auto-inject to opt out — see "The --schema parameter" below)`. But the "does NOT" list (lines 25-29) says: `Define the output schema (user can pass --schema; defaults to LLM-assisted extraction)`. These two are saying opposite things about the same default. The "does NOT" entry implies that without a `--schema` the skill falls back to LLM-assisted extraction (which is correct), but the "does" entry says the schema is auto-injected by default — which implies a schema always exists. The contradiction only resolves if you read the longer "schema parameter" section (lines 86-156), which is not a robust contract. **Fix:** remove the contradictory entry from one of the two lists, or rephrase the "does NOT" entry to: `Force the user to pass --schema; the skill auto-injects the schema when one is provided and falls back to LLM-assisted extraction otherwise`.

- **Line 4 (`argument-hint`) lists 5 flags; the Inputs table at lines 62-69 lists 5 flags. The two agree, but `argument-hint` uses `[--out <dir>]` while the Inputs table calls it `--out` — and there's no human-readable description of what `<dir>` means in the hint.** A user invoking the skill from a host that surfaces `argument-hint` will see `[--schema <json|file>]` and not know whether `json` is a literal value or a placeholder. The Inputs table is clearer but lives below. **Fix:** remove the angle-bracket placeholders from `argument-hint` and just list the flags: `[--models ...] [--out ...] [--schema ...] [--mode ...] [--no-auto-inject]`. Or move the full Inputs table to the top of the file.

- **Line 96's schema example uses `"primary_key": "item"` as a top-level schema field, which the code-review example (rules/examples/code-review.md:70-71) explicitly says is wrong.** Quote from code-review.md:70: `"Why the old 'primary_key': 'file:line' is wrong: the skill spec says composite keys are expressed by listing multiple columns with dedup_key: true — not by concatenating strings. The string-form 'primary_key' is not a recognized schema field."` This is a direct cross-file contradiction. **Fix:** remove the `"primary_key"` line from the SKILL.md schema example (line 96), since the column definition immediately below (`{"name": "item", "type": "string", "dedup_key": true}`) already declares the dedup key correctly.

- **Line 152 (in the free-form fallback description) says: "fuzzy match on first 5 words of each paragraph".** This is the only place the free-form mode's primary-key heuristic is specified, and it's wrong. (a) "Paragraph" is undefined — is it a blank-line split, a fixed char count, or a heuristic? (b) "First 5 words" doesn't produce a stable key for headers longer than 5 words (`## A deep dive into Microsoft Agent Framework` would key on `A deep dive into Microsoft`, which is unlikely to fuzzy-match anything). (c) The "first 5 words of a paragraph" doesn't even apply to a heading, which has no paragraph. **Fix:** either specify a concrete algorithm (e.g., "If the response has H2 headings, key on the H2 text; otherwise, key on the first sentence's first noun phrase") or remove the heuristic and require a schema for free-form mode.

- **The "What does NOT" list (lines 25-29) omits "the skill does not retry" (which is mentioned at line 29 as bullet 4 — so it IS in the list) AND omits that the skill is `fail-soft`** (mentioned only in dispatch-mechanics.md:129 and methodology.md:19). The fail-soft behavior is a contract that callers depend on; it should appear in the SKILL.md main list too.

**What is unclear or ambiguous:**

- **Line 174-175: HTML generation says `convert consolidated.md to HTML using a markdown library (marked in Node, markdown in Python, pandoc for richer output).`** Three tools, no priority, no CSS spec, no fallback. If both Node and Python are available, which wins? What CSS classes does the HTML use? The methodology.md:135 says `Self-contained HTML render of consolidated.md (CSS embedded, no external resources)` — but no CSS is specified anywhere. This is not a failure mode, it's a non-spec. **Fix:** either commit to a single tool (recommend `marked` for Node or `pandoc` for richer output) and provide the CSS template, or remove the HTML deliverable and let the caller render it post-hoc.

- **Line 207: "6 OCG models" vs line 22: "for model in opencode-go/minimax-m3 opencode-go/qwen3.7-max opencode-go/deepseek-v4-pro opencode-go/glm-5.2 opencode-go/kimi-k2.6 opencode-go/mimo-v2.5-pro"** — the proven run used 6 models, but the "What this skill does" list at line 16 says "Dispatches the user's prompt to N LLM models in parallel" without specifying a recommended N. The model selection strategy in dispatch-mechanics.md:166-174 recommends 4-6. The discrepancy is small but a reader will want to know: is 6 the proven number, 4 the minimum, 8 the diminishing-returns ceiling? **Fix:** the "What does" list should state "Dispatches the user's prompt to **4-6** LLM models in parallel" to align with the strategy.

### 1.2 rules/methodology.md (173 lines)

**What works well:**

- The 4-phase pipeline is well-structured with clean phase boundaries.
- The 4-fallback extraction path in Phase 2 (lines 37-64) is the most concrete algorithm in the entire skill. Each fallback has a clear trigger condition and a non-LLM-first preference (table → structured tags → extractor LLM → paragraph split).
- The "Deterministic + LLM-assisted hybrid" section (lines 156-161) is honest about the design trade-off: structured extraction is deterministic; free-form extraction is LLM-assisted. This is rare in skill documents.

**What is missing or wrong:**

- **Line 157: "Structured extraction (Mode A) is deterministic — pure parsing, no LLM in the loop" is FALSE.** Mode A's fallback path 3 (lines 52-58) explicitly dispatches an extractor LLM. The claim should be: "Structured extraction is deterministic when the model produces a compliant table; LLM-assisted fallbacks are used otherwise." This was flagged by R3 and is still unfixed.

- **Line 162-168: "Audit trail — Every step is recorded: the exact prompt sent, each model's raw response, the structured extraction per model, the conflict resolutions applied, the final consolidated output."** The structured.jsonl is the audit record, but **Phase 2 (line 70-72) says "drop row with warning" when validation fails, and methodology.md never says WHERE those warnings go.** They don't appear in `conflicts.md` (that's only for cross-model disagreements, not intra-model validation failures). They don't appear in `run-manifest.json` (no `validation_failures` field). They aren't logged anywhere. The audit trail is incomplete — drops are silent. **Fix:** add a `validation_failures` array to `run-manifest.json` (or a separate `validation.md`) capturing `{row_id, model, reason}` per drop.

- **Line 110: "For each unique item (by `primary_key` from schema or by fuzzy title match in free-form mode)"** — `primary_key` is referenced as if it's a schema field, but per the contradiction noted in §1.1, the spec is inconsistent on whether `primary_key` is a valid top-level schema field. methodology.md inherits this confusion.

- **Line 145-147: "The canonical schema lives in `rules/output-schema.md`."** This redirects to output-schema.md, which currently (correctly) defines the manifest fields. But methodology.md is a more natural place for the schema's evolution record. If a future contributor adds a field to methodology.md's narrative and forgets to update output-schema.md, the redirect breaks. **Fix:** define the schema once, in one file, and have the other file reference it as a "see also" rather than as a redirect.

- **Line 173: "Idempotent re-runs."** "Idempotent" is the wrong term. Idempotent means same input → same output. Different model responses each run means different output. The correct term is "re-runnable" or "repeatable." This was flagged by R3 and is still unfixed.

**What is unclear or ambiguous:**

- **Line 53: "extractor model = the slowest/highest-capability model from the dispatch."** How is "highest capability" determined? This is asked in R3 and R4 and is still unanswered. There's no model ranking table, no benchmark, no parameter-count lookup. The implementer has to guess. **Fix:** either provide a concrete heuristic (e.g., "by descending context window size, breaking ties by parameter count") or explicitly say "left to the implementation; the only contract is that the extractor is a separate dispatch, not a re-prompt of the original model."

- **Line 96: "Each numbered/bulleted item = one record"** — but a model might emit a numbered list with sub-bullets (e.g., `1. Item\n   - Sub-claim A\n   - Sub-claim B`). Does "the body content is the fields blob" mean the sub-claims are flattened into the fields? No example is given for nested lists. **Fix:** add one sentence: "If the item has sub-bullets, the body is the concatenation of the parent text and the sub-bullets, with sub-bullet content prefixed by `>`."

- **Line 110-115: "Dedup: items with the same `primary_key` (or fuzzy-matched title) are merged."** This glosses over what "merged" means. If model A says `LangGraph, category=adjacent, score=3` and model B says `LangGraph, category=direct, score=5`, what does the merged record look like? Per the conflict-resolution rules, each field is resolved independently. But the *primary key* merging is not "merge" — it's "the items are now one canonical entry." The next phase (3.5 RESOLVE) is the actual field-merge. methodology.md doesn't make this distinction. **Fix:** use "Dedup: items with the same `primary_key` are grouped into one canonical entry" to clarify that dedup ≠ merge.

### 1.3 rules/dispatch-mechanics.md (188 lines)

**What works well:**

- The 4-mechanism decision table (lines 173-181) is the best decision-support artifact in the skill. It maps concrete constraints (have `task` tool? need cross-provider? shared-port MCPs?) to specific mechanisms.
- The real-world bug references (Mechanism 1's 6 issue numbers, Mechanism 3's issue #18615) add credibility. They show the skill author has actually debugged these mechanisms.

**What is missing or wrong:**

- **Lines 49-58: the default Mechanism 2 snippet uses `"$PROMPT"` directly on the command line.** If the prompt contains `$`, backticks, `"`, `\`, or newlines, the shell will interpret them before `npx` sees them. This is a well-known shell injection hazard. The code-review example (rules/examples/code-review.md:20-30) and fact-check example (rules/examples/fact-check.md:20-35) both use a heredoc pattern (`cat > "$OUT/prompt.md" <<'PROMPT'`) precisely to avoid this — but the main dispatch section doesn't. **Fix:** replace `"$PROMPT"` in the default snippet with a heredoc-then-file approach, matching what the example files already do. This was flagged by R3 and is still unfixed.

- **Line 44: `slug=$(echo "$model" | cut -d/ -f2)`** assumes exactly 2 `/`-separated segments. For 3-segment IDs like `org/opencode-go/minimax-m3` or HuggingFace `huggingface/meta-llama/Llama-3-70b`, this silently extracts the wrong segment (the middle, not the leaf). The skill should use `echo "$model" | sed 's|.*/||'` (extract everything after the last `/`) or `basename "$model"`. **Fix:** one-line change in the snippet.

- **Line 55: `--dangerously-skip-permissions` is passed unconditionally.** The comment at line 66 says "fine for read-only tasks (research, code review, fact-check). For write tasks (writing a file to the user's repo, modifying configs), do NOT use this flag." But the snippet always includes it. A user copying the snippet for a write task gets a security foot-gun. The code-review example (code-review.md:38) and fact-check example (fact-check.md:42) correctly omit it; the default snippet — which is the most-copied — does not. **Fix:** wrap the flag in a conditional or add a prominent `# REMOVE --dangerously-skip-permissions for write tasks` comment. This was flagged by R4 and is still unfixed.

- **Line 50-58: The dispatch loop runs in parallel (`&` + `wait`) but the snippet never sets a process limit.** With 6 models dispatched in parallel, the system opens 6 npx subprocesses simultaneously, each spawning its own OpenCode runtime. On a machine with limited memory or a per-process open-file limit, this can OOM or hit `ulimit`. **Fix:** add a `MAX_PARALLEL` semaphore (e.g., dispatch 2 at a time using a `for ... wait $!` pattern, or use `xargs -P 4`).

- **Line 113: "MCP port collision caveat"** prescribes "configure MCPs that support multiplexing, or dispatch to a single model at a time AND restart the MCP between dispatches." This is concrete advice with zero concrete details. No MCP names, no config syntax, no restart procedure. An implementer reading this can't act on it. **Fix:** either name specific MCPs (`agentmemory` on port 3111, `context-mode` on port 3112) and show the restart command, or remove this caveat.

**What is unclear or ambiguous:**

- **Line 106: "configure MCPs that support multiplexing"** — what does "multiplexing" mean for an MCP? Is it HTTP/2 multiplexing? Is it running multiple MCP instances on different ports? Is it a feature of the MCP itself? This term is used in the failure-modes table too (SKILL.md:223) without definition.

- **Line 116-118: "Always check the model's CWD for stray `*.md` files after a dispatch."** The calling agent has no programmatic access to the model's CWD unless it knows it. The CWD is set by the `npx` invocation — which defaults to the parent's CWD, which is wherever the dispatcher was launched. This advice is for a human, not for an automated pipeline. **Fix:** move this to a "Manual post-run steps" section.

### 1.4 rules/consolidation-rules.md (334 lines)

**What works well:**

- The named rule library (lines 163-221) is the strongest part of the entire skill. Each rule has purpose, input, algorithm, and edge case. The `most-severe` rule's edge-case documentation (lines 167-172) is especially well-done — it explains *why* the default is "don't downgrade" and *when* to override.
- The minimal contract section (lines 7-22) is genuinely useful: it says "an item is a unique identity + fields + optional source pointers" without naming a task type. This is the right level of abstraction.

**What is missing or wrong:**

- **CRITICAL: The `majority-with-uncertain` algorithm (line 183) contradicts the documented example (line 233) and the fact-check example (fact-check.md:74).** R3 caught this and R4 missed it. The math:
  - Algorithm: `require ≥ max(2, ceil(N/2)) models to agree`
  - For N=3: `max(2, ceil(3/2)) = max(2, 2) = 2`
  - So 2 votes of `true` with 1 vote `false` → threshold met → algorithm returns `true`
  - But the example (line 233) says: `claim X | verdict | 2 say true, 1 says false | majority-with-uncertain (threshold not met) | unverified | high`
  - And the fact-check example (fact-check.md:74) says: "if 2 say true and 1 says false, default to `unverified` rather than `true`"
  
  Either the algorithm is wrong (it should be `>` instead of `≥`, i.e., a strict majority) or the examples are wrong. As R3 notes, "the algorithm IS the spec; the examples are wrong." But that interpretation produces a rule that's almost useless for N=3 (a single dissent blocks consensus), which is also the most common fact-check setup. **Fix:** change the algorithm to `require > max(2, ceil(N/2))` AND fix the example at line 233 to a different scenario (e.g., 3-0 vote), AND update fact-check.md:74 and fact-check.md:104-108. The three changes must be consistent. The current spec is broken in three places simultaneously.

- **Line 82: "supply an alias map at run time" — but how?** The interface is undocumented. Not a CLI flag, not a `--schema` sub-key, not a separate file. The research example hardcodes the alias map in its example file. R3 and R4 both flagged this. **Fix:** add a CLI flag (`--aliases <file>`) and a `--schema` sub-key (`"aliases": {...}`), both reading the same JSON format. Document the format in a new `rules/alias-format.md` or in this file.

- **Line 199: `concatenate-all` is the rule name. Line 307 (in the custom strategies table) says "Use `concatenate` for comments" for writing critique.** Different name, same operation (presumably). **Fix:** change line 307 to `concatenate-all`. This was flagged by R4 and is still unfixed.

- **Line 115: `aliases[n] = null` overloads the alias map with skip semantics.** A reader scanning the alias map sees `{'AutoGen/AG2': 'AutoGen', 'SomePlaceholder': null}` — the `null` value is not mentioned in the alias map documentation (line 82), only in the skip rules (line 115). Two different operations (alias resolution and skip filtering) share one data structure. **Fix:** split into two structures: `aliases` for resolution and `skip_rules` for filtering. Or document the `null` semantic clearly in the alias map definition.

- **Line 131: "Match if normalized titles are ≥80% similar (Levenshtein or token-overlap)"** — the algorithm is underspecified. "Levenshtein or token-overlap" produces different results for the same input. For `AutoGen Framework` vs `Framework AutoGen`, Levenshtein gives ~14 distance (low similarity) but token-overlap gives 100% (perfect match). An implementer picking the wrong one gets different dedup results. **Fix:** pick one algorithm. The skill should commit to `token-overlap` (Jaccard on token sets) since it's more robust to word-order differences, which is the common failure mode for cross-model outputs.

- **Line 185: "Do NOT change the rule's return value to match the schema — change the schema to match the rule."** This inverts normal API design. If a user schema has `values: ["true", "false", "partially-true"]` (no `unverified`) and uses `majority-with-uncertain`, the rule silently returns `unverified` — a value the schema doesn't accept. The override is mentioned (`verdict_uncertain_value: "partially-true"`) but the example doesn't show it. **Fix:** show a worked example of the override, including the `conflict_resolution` block in a `--schema` that uses `partially-true` instead of `unverified`.

- **Line 221: `merge-exact` is redundant with `dedup_key: true`.** R3 caught this. The `dedup_key: true` flag on multiple columns already handles composite keys at the registry level (the dedup algorithm groups by canonical primary key). `merge-exact` describes the same operation twice. **Fix:** either remove `merge-exact` from the rule library or change its purpose to "merge non-key fields across models that share a primary key" (which is what it actually does) and rename it to make that clear.

- **Line 258-262: "Maturity / version conflict" uses `last_verified` for the tie-break.** But `last_verified` in the research schema is the *candidate's* last-verified date, not the *model's* verification date. The conflict-resolution rules operate per-model (each model has a value). The "newer `last_verified` wins" rule is comparing candidate maturity dates, which is meaningful (the most recent verification is more trustworthy), but the wording conflates "the model's last verification" with "the candidate's last verification." **Fix:** clarify which date the rule reads.

**What is unclear or ambiguous:**

- **Line 196: `longest-with-quote`'s tie-break is "model's `last_verified` if present, else the order in the input list."** But `last_verified` is an optional schema column, not a per-model field. For schemas that don't define `last_verified`, the tie-break silently falls back to input order, which is a non-deterministic ordering (depends on the order models were dispatched, which depends on shell glob order). **Fix:** state explicitly "if the schema defines `last_verified`, tie-break by it; otherwise, by the model name (alphabetical) for cross-run determinism."

- **Line 203: "Order: by model name (alphabetical) for determinism."** What's a "model name"? Is it the full `provider/model` ID? The bare slug? Different runs may use different forms (`opencode-go/minimax-m3` vs `minimax-m3`). **Fix:** specify exactly: "Order: by the bare slug (the part after `/`), alphabetical."

- **Line 290-294: §6 (Negative Results) is in the final synthesis default table but the methodology says nothing about how negative results are detected.** "Items models searched for but found nothing" requires the prompt to explicitly enumerate "things to search for." If the user doesn't enumerate them, the skill can't produce §6. **Fix:** add a sentence: "§6 is only meaningful when the prompt includes an explicit list of buckets/categories to search. Without that, §6 is empty or omitted."

### 1.5 rules/output-schema.md (270 lines)

**What works well:**

- The markdown formatting rules (lines 258-269) are the most practical section in the entire skill. They codify real WYSIWYG failures ("`***` breaks some viewers", "delimiter rows must start and end with `|`") into enforceable rules. This is exactly the kind of thing a skill should document.
- The two-mode output structure (schema vs free-form) is cleanly delineated. A reader can map "did the user pass `--schema`?" to "which mode is in effect?" in one glance.
- `run-manifest.json` (lines 209-254) is fully specified with field-level semantics. Each field has a "Field semantics" entry. This is the "single source of truth" pattern done right.

**What is missing or wrong:**

- **R4 incorrectly flagged this file as stale ("missing v2.1.0 fields"). It is not stale.** I verified by reading the file: `phases_completed` (line 235), `consolidation` (line 230), `schema_auto_injected` (line 218), and `aliases` (line 224) are all present. R3 must have looked at a pre-v2.1.0 version, and R4 uncritically re-flagged R3's claim. **Action item:** future reviews should re-verify prior-review claims against the current file content instead of propagating.

- **Lines 170-171 list `evidence-ledger.md` and `verification.md` (thorough-mode outputs) but no section of this file defines their format.** The methodology.md doesn't define them either. They are advertised as output files but exist in spec limbo. **Fix:** add a new section "§9. Thorough-mode files" with format specs (columns, per-row structure) for both. Or remove them from the output structure if they're not yet implemented.

- **Lines 102-115: §3 "Per-Item Details" leaks research-specific fields.** Quote: `**Research / comparative:** gaps_vs_reference = ... ; reference_gaps_vs_them = ...` — these are research-prior-art fields. A code-review user reading §3 would be confused (their fields are `severity`, `description`, `suggestion`, not `gaps_vs_reference`). **Fix:** replace the research-specific row with truly generic examples (e.g., "List the canonical fields and the values chosen for this item after conflict resolution").

- **Line 119-126: §4 "Conflicts & Resolutions" uses `rule 4 (outlier downgrade)` and `rule 3 (strict)` in the example row** — these are referenced by number but never defined anywhere. The `prefer-with-evidence-then-newer-then-strict` rule has 4 sub-rules (consolidation-rules.md:155-161), but they're not numbered. An implementer building the conflict log has no way to map `rule 4` to a name. **Fix:** either name the sub-rules (e.g., "evidence-quote-wins", "recency-wins", "outlier-downgrade", "tie-break-by-evidence") or use the rule's full name in the conflict log.

- **Line 73-75: "Conflict marker legend (place at top of section): `value*` = field conflict: at least one model disagreed."** But §2A (which uses the markers) comes before §4 (which explains the rules). The reader sees the marker before knowing what it means. **Fix:** move the legend to the top of §4 (where the rules are defined), or add a forward reference in §2A.

- **Line 205: "`conflicts.md` — Same as §4 but as a standalone file (for tooling that consumes it)."** What tooling? The skill doesn't name a consumer. If there's no consumer, this is duplication. If there is, name it. **Fix:** either name a consumer (e.g., "consumed by `consolidate.js` for incremental re-runs") or remove the duplicate file.

- **Line 130-131: §5 (Aggregated Scores) and §8 (Synthesized Verdict) are "optional" but §6 (Negative Results) and §7 (Open Questions) are not marked optional.** Are they always produced? What if there are no negative results — is §6 omitted or produced empty? The optionality contract is inconsistent. **Fix:** make all sections explicitly optional with a one-line "include when ..." rule per section.

- **Line 242: `task_prompt_hash` — "sha256: of the prompt bytes."** SHA-256 produces 256 bits. Common encodings are hex (64 chars) or base64 (44 chars). The `sha256:` prefix is documented but the encoding is not. Different agents will produce different hashes for the same prompt. **Fix:** specify: "hex-encoded lowercase, 64 characters, no padding."

- **`run-manifest.json` doesn't capture timing data.** The schema has `timestamp` (start time) but no `duration_ms`, no per-model timing, no consolidation wall-time. For a skill that lists "Latency of slowest model + consolidation is OK" as a decision criterion (SKILL.md:41), the manifest doesn't capture the data needed to evaluate that criterion. A user who wants to know "how long did consolidation take?" has no answer. This was flagged by R3 and is still unfixed. **Fix:** add `totals.duration_ms`, `totals.per_model_duration_ms`, and `totals.consolidation_duration_ms`.

- **The "Coverage Scoreboard" bucketing is undefined.** Line 184 says `Bucket` is a column, but "bucket" is never defined. The research example implies per-category buckets; code-review implies per-file buckets; fact-check implies per-verdict buckets. Without a bucketing definition, every run produces incomparable scoreboards. **Fix:** either define a standard bucketing scheme (e.g., "buckets are top-level categories from the schema's `category` enum") or remove the scoreboard section.

**What is unclear or ambiguous:**

- **Lines 130-131: optionality contract for §5-§8.** As above — inconsistent.

- **Line 109: "`gaps_vs_reference = ... ; reference_gaps_vs_them = ...`"** — the double-direction gaps are research-specific and not meaningful for code review or fact-check. As noted above, the example section is non-generic.

### 1.6 rules/examples/research-prior-art.md (185 lines)

**What works well:**

- This is the **only** example with a real, end-to-end run. The provenance (line 173-178) is honest: it cites the actual run output path, the date, the model set, the schema injection behavior, and the alias map size. This is the gold standard the other examples should match.
- The 14-entry alias map (lines 125-141) is practical and shows real-world dedup patterns (`AutoGen` ↔ `AG2`, `MAF` ↔ `Microsoft Agent Framework`). This is the kind of detail that turns a generic spec into a working recipe.

**What is missing or wrong:**

- **Line 75: `"primary_key": "name"`** in the schema JSON. The code-review example (rules/examples/code-review.md:70-71) explicitly says this is wrong. The two examples contradict each other on schema syntax. **Fix:** remove `"primary_key"` from line 75. The column at line 77 (`{"name": "name", "type": "string", "dedup_key": true}`) already declares the dedup key correctly.

- **Line 116: `"aggregate": "sum"`** is used in the scoring rubric but `sum` is not in the documented set of aggregators anywhere else. SKILL.md:100 shows `aggregate: "median"`. methodology.md:115 says "if the schema has a numeric score field with `aggregate: 'median'`." consolidation-rules.md has no aggregator spec — the dedup/conflict section is silent on aggregation. **Fix:** either add `aggregate` to the spec with allowed values `["median", "mean", "sum", "min", "max", "first", "last"]` (as R3 suggested) or replace `sum` with `median` in this example.

- **Line 117: `"max_total": 16`** assumes all 8 dimensions are scored at level 2. But the rubric marks two dimensions as N/A for skills (SE+DevOps unified, Team customization). For a skill evaluation, the max is 12 (6 dimensions × 2), not 16. **Fix:** make `max_total` per-task variable, or state that the 16-total applies to tool evaluations only.

- **Line 24-30: the dispatch bash snippet doesn't pass `--schema`.** Line 173-178 says "the prompt did NOT embed the schema; the skill auto-injected it because `--no-auto-inject` was not passed." But where does the schema come from in the dispatch? The snippet doesn't show `npx ... --schema ./schema.json ...`. **Fix:** add the `--schema` flag to the snippet.

- **Line 24-30: the dispatch bash snippet has the `"$PROMPT"` shell injection vector** (same as dispatch-mechanics.md:49). The snippet should use the heredoc pattern that code-review.md:20-30 already demonstrates. **Fix:** replace the direct `"$PROMPT"` with `cat > "$OUT/prompt.md" <<'PROMPT' ... PROMPT` and `@"$OUT/prompt.md"` in the npx invocation. This was flagged by R3 and is still unfixed.

- **Line 121-141: the alias map format is inconsistent.** Some entries use comma-separation (`Camunda, Camunda 8 | Camunda 8`), others use slash-separation (`AutoGen/AG2, AutoGen (maintenance) | AutoGen`). The pipe delimiter separates alias list from canonical, but the alias list itself is ambiguous. **Fix:** standardize the alias list separator (e.g., `;` for multiple aliases) and document the format in a new `rules/alias-format.md`.

- **Line 139: "Windsurf, Devin Desktop → Windsurf"** is a real alias error. Devin is Cognition's product (not Windsurf/Codeium's). Devin Desktop is a Cognition product. Aliasing `Devin Desktop → Windsurf` will mis-cluster these. **Fix:** either remove `Devin Desktop` from the Windsurf entry or canonicalize to `Devin` (which is the line 140 entry). The current state silently corrupts future runs.

- **Line 182: "diminishing returns past 6 (this is an empirical observation, not a measured curve — run your own benchmark if you want a hard number)"** — the parenthetical disclaimer undermines the claim while keeping it. This is an assertion and a retraction simultaneously. **Fix:** either cite the data or remove the number.

- **Line 67: "Reference Context"** prompt section says "subject catalog snapshot for calibration" — no format. JSON? Markdown table? Free-text? The proven run output (`docs/research-260624/SB_CONSOLIDATED_PRIOR_ART_REPORT.md`) might clarify, but the example file doesn't.

**What is unclear or ambiguous:**

- **Line 64: "Cross-AI Dedup Instructions"** in the research prompt template. The instruction says "normalize names, resolve conflicts, scoring rubric" — but these are orchestrator-side operations, not model instructions. Models don't run dedup; they emit responses. The prompt is conflating "what the model should output" with "what the orchestrator should do." **Fix:** rename to "Output Conventions" or "Formatting Requirements" to clarify these are model-side instructions.

### 1.7 rules/examples/code-review.md (111 lines)

**What works well:**

- The composite-key correction at lines 70-71 is genuinely pedagogically useful. It explicitly documents why `primary_key: "file:line"` is wrong and shows the correct form (`dedup_key: true` on both `file` and `line`). This is exactly the kind of concrete guidance that makes a skill usable.
- The custom strategies table (lines 93-100) maps each field to a named rule with rationale. A reader can build a code-review schema by following the table.

**What is missing or wrong:**

- **Line 111: "Worked example: Not yet produced (deferred to v2.2.0)."** This file is labeled as a worked example in SKILL.md:203-210 (`rules/examples/code-review.md — parallel code review recipe`) but the worked example is missing. The "task-agnostic" claim (SKILL.md:13) is validated by exactly one example (research). **Fix:** Option A — produce a worked run; Option B — change the section heading to "Recipe (unvalidated)"; Option C — remove the file and put the recipe content in SKILL.md as a section. R3 and R4 both flagged this; it remains unfixed.

- **Line 33: the dispatch uses only 2 models.** With 2 models and different `category` values, `majority` returns `null` (consolidation-rules.md:178: "with 2 models and 2 different values, no majority — return null"). The example doesn't warn about this. **Fix:** add a note: "With 2 models, `majority` may return `null` for disagreeing fields. Use ≥3 models for stable `majority` results."

- **Line 38-42: the dispatch snippet doesn't pass `--dangerously-skip-permissions`, but the prompt asks models to "Review the file at /path/to/code.py."** If the model needs to READ the file via the `read` tool, it needs tool permissions. Line 45 says "code review is a read-only task — the models just read and report" — but "read-only" and "no tool permissions needed" are different things. The `--dangerously-skip-permissions` flag is about tool permissions, not write permissions. The security note conflates them. **Fix:** clarify: "The flag is about tool-execution permissions, not about read vs write operations. Read-only tasks that use tools still need the flag (or per-tool permission grants) to invoke those tools."

- **Line 45-46: the security note references `rules/dispatch-mechanics.md:56`.** This is fragile cross-file referencing. If dispatch-mechanics.md is renumbered, the reference breaks. **Fix:** describe the rule, don't link to a line number: "Per the dispatch-mechanics security guidance, this flag is wrong for write tasks but correct for read-only review."

- **Line 107: "Pre-commit hook ... NOT currently supported as a built-in dispatch; requires custom runner."** This is a feature wishlist in an example file, not an example. **Fix:** remove or move to a `ROADMAP.md` or `TODO.md`.

**What is unclear or ambiguous:**

- **Line 86: "§5 Per-Reviewer Statistics"** — counts of raw findings or deduped findings? If reviewer A returns 5 findings and reviewer B returns 3, with 2 overlapping, does the statistic say 5 and 3 (raw) or 3 and 1 (deduped)? The section header doesn't say. **Fix:** specify: "raw findings count, pre-dedup."

- **Line 21: "Review the file at /path/to/code.py."** For multi-file PRs, does the orchestrator concatenate files, dispatch one model per file, or what? Line 107 says "extend prompt to find issues across N files" but doesn't say how consolidation handles cross-file dedup. Same `(file, line)` tuple across files is rare; same `file` is common. The dedup key `(file, line)` is line-specific, not file-specific, so cross-file findings remain distinct — but the "find the bug in PR #123" use case is not addressed.

### 1.8 rules/examples/fact-check.md (113 lines)

**What works well:**

- The consensus requirements section (lines 103-109) is parameterized and honest about thresholds. The progression `N=3 → 2`, `N=5 → 3`, `N=7 → 4` is concrete and actionable.
- The explicit handling of `unverified` as a valid verdict (line 76) is a strong design choice. It admits "we don't know" as an acceptable answer, which is the right call for fact-check.

**What is missing or wrong:**

- **Line 74: contradicts the algorithm in `consolidation-rules.md:183`.** This is the most important finding in this review (see §1.4 above). The fact-check example says: `"if 2 say true and 1 says false, default to unverified rather than true"`. The algorithm computes `max(2, ceil(3/2)) = 2` and says 2 votes meets the threshold. The example and the algorithm disagree. **Fix:** align all three locations (the algorithm, the example, and the conflict documentation template).

- **Line 77: changelog entry embedded in example file.** `"sources: 'url_list' is now formally defined in the schema spec (was a v2.1.0 gap)"` — this is version history, not example documentation. Changelog information should be in a `CHANGELOG.md` at the skill root, not scattered across example files. **Fix:** create a `CHANGELOG.md` and remove the inline changelog entries from example files.

- **Line 104: introduces a `confirmed` status not in the schema enum.** `"≥ max(2, ceil(N/2)) models agree on true with high confidence + primary source → confirmed"` — but the schema's enum (line 60) is `["true", "false", "partially-true", "unverified"]`. `confirmed` is not a valid verdict value. Is `confirmed` the same as `true`? **Fix:** either add `confirmed` to the schema enum (if it's a distinct semantic — e.g., "true with cross-source corroboration") or remove the term and use `true`.

- **Line 109: "The '3+ models' rule in the original draft was a typo; the correct threshold is parameterized."** Self-referential to a deleted draft. The reader can't see the original draft. **Fix:** remove this sentence.

- **Line 59: `claim` field has `type: "text"` but no `max_words`.** The schema column definition table in SKILL.md (lines 117-126) shows `text` as "Long-form text (use `max_words` to constrain)." This field explicitly ignores that guidance. Unbounded text could produce massive output. **Fix:** add `max_words: 500` or similar.

- **Line 24: `verdict: true | false | partially-true | unverified` — the distinction between `partially-true` and `unverified` is never defined.** Both are valid verdict values. Line 76 says `unverified` is for "insufficient evidence" but doesn't say when to use `partially-true`. Is `partially-true` for "the claim is half-right" and `unverified` for "we don't know"? The schema allows both; the prose doesn't distinguish them. **Fix:** add a one-sentence distinction: "`partially-true` = the claim has both supporting and contradicting evidence; `unverified` = the models could not reach a verdict due to insufficient evidence."

- **Line 28: `counter_evidence` "if verdict is false or partially-true"** is a prose instruction to the model, not a schema constraint. The model may ignore it and include `counter_evidence` for `true` claims. The schema has no `condition` field on columns. **Fix:** either add a `condition` field to the column spec (e.g., `"condition": "verdict != 'true'"`) or document the limitation explicitly.

- **Line 28-35: `claim_id: "preserve the input ID"`** — but the schema has `dedup_key: true` on `claim_id`, so different models must agree on the same `claim_id` for dedup to work. If model A renumbers the claims, dedup breaks. **Fix:** specify the `claim_id` format and require models to use it verbatim.

**What is unclear or ambiguous:**

- **Line 105: "with high confidence + primary source"** — how does the orchestrator determine "primary source"? The schema has no `source_type` field. Different models will have different definitions. **Fix:** add a `source_type` field with values `["primary", "secondary", "speculative"]`, or document the criterion.

- **Line 87: "Source Quality"** — URL normalization (handling `https://example.com` vs `https://example.com/` vs `http://example.com`) is not specified. The `union-dedup` rule (consolidation-rules.md:214) catches trailing slashes but not protocol differences. **Fix:** extend the URL normalization: "lowercase, trim, strip trailing slashes, force `https://`."

---

## §2. Score the Skill on the 8-Dimension Rubric

Using the rubric in `consolidation-rules.md` and the prior-art research example (the same rubric used in R3 and R4).

| Dimension | Score | Justification |
|-----------|-------|---------------|
| **Catalog of composable units** | 1 | The named rule library (`most-severe`, `majority`, `majority-with-uncertain`, `lowest-of-majors`, `longest-with-quote`, `concatenate-all`, `all-collected`, `union-dedup`, `merge-exact`, `prefer-with-evidence-then-newer-then-strict`) is well-defined and concrete. But the catalog is *prose*, not a machine-readable file — there's no JSON or enum file enumerating the available rules. An implementer has to read consolidation-rules.md to know what rules exist. The `--schema` validation logic (which would catch invalid rule names) is missing. Score: prose catalog, not machine-readable. |
| **Dynamic composition** | 1 | `--mode`, `--schema`, `--models`, `--no-auto-inject` reconfigure the pipeline. `run-manifest.json` records what was used. But: (a) no runtime replanning on model failure (the skill is fail-soft but doesn't re-dispatch with a substitute model); (b) no dynamic rule selection based on the data; (c) `run-manifest.json` records *what* was used, not *why* (no composition decision graph). Not catalog-backed + audited. |
| **V-loop depth** | 1 | `thorough` mode adds cross-source verification (a verifier model per claim). Standard mode resolves conflicts at the end. But: (a) no recursive V-loop (verify → fix → re-verify); (b) no intent gate that blocks synthesis if verification fails (the `thorough` mode records `source_verified: true/false/wrong` but doesn't refuse to produce `consolidated.md` if all items are `wrong`); (c) `phases_completed` is a list of integers, not a per-step verification matrix. |
| **Enforcement** | 0 | Honor system. No IDE hooks, no CI integration, no delivery blockers. Nothing prevents an agent from skipping Phase 2 extraction, using a non-existent conflict rule, or producing a malformed consolidated report. The skill is documentation, not a runnable artifact. |
| **Parent/worker split** | 2 | Explicit orchestrator/worker with fail-soft design. The orchestrator dispatches N model workers, captures responses, consolidates. The "extractor model" role is a designated fallback worker (a second-order dispatch when first-order output isn't structured). The `models_failed` list in `run-manifest.json` documents partial-failure runs. This is genuinely strong. |
| **Evidence model** | 2 | Tiered sufficiency with staleness: `source_refs` per row, `last_verified` date, `prefer-with-evidence-then-newer-then-strict` rule (quoted-evidence wins, then recency), `thorough` mode verification ledger. More sophisticated than many production systems. |
| **SE + DevOps unified** | 1 | Code-review example covers SE. No infrastructure review, config audit, or deployment verification example. The skill supports *both* domains as task types, but each requires a separate schema and conflict rules. The "covers both in one model" criterion (the rubric's 2-point definition) requires a unified scoring framework — the research example has its own 8-dimension rubric, but it's research-only. Score: covers both domains as task types, but not in one unified model. |
| **Team customization** | 0 | No process packs, no overlay mechanism, no way to persist team defaults. Every run requires full CLI args. The `--schema` parameter supports per-run customization but doesn't persist. No sharing mechanism. The alias map is task-specific but lives in the example file, not in a team-shared location. |
| **TOTAL** | **8/16** | |

**Difference from R4 (10/16):** R4 gave 2 for Catalog (claiming machine-readable catalog) and 1 for Parent/Worker. I gave 1 and 2 respectively. Net: 8 vs 10.

R4's "2 for Catalog" is generous: there is no machine-readable catalog file enumerating the available rules, modes, column types, or dispatch mechanisms. The implementer must read prose to discover them. R4's "2 for Parent/Worker" is defensible. R4's "2 for SE+DevOps" is wrong — the rubric's 2-point definition requires a unified model, not separate examples.

**Difference from R3 (7/16):** R3 gave 1 for Catalog, 1 for Parent/Worker, 0 for Team customization. I gave 1, 2, 0 respectively. Net: 8 vs 7. R3 undervalued Parent/Worker; I undervalued Catalog relative to R4.

My final score (8/16) reflects a skill with strong conceptual design (evidence model, parent/worker split) and a well-specified named rule library, held back by zero enforcement, no machine-readable catalog, no team customization, no reference implementation, and the unfixed `majority-with-uncertain` algorithm contradiction.

---

## §3. Top 5 Improvements (ranked by impact × effort)

### 1. Fix the `majority-with-uncertain` algorithm/example contradiction (R3 caught this, R4 missed it)

- **Issue:** `consolidation-rules.md:183` says the threshold is `≥ max(2, ceil(N/2))` (so 2 votes of 3 meets the threshold for `true`). The example at `consolidation-rules.md:233` says "2 say `true`, 1 says `false` → threshold not met → `unverified`." The fact-check example at `fact-check.md:74` says the same. The algorithm and three example locations disagree.
- **Why it matters:** This is the most-used conflict rule for high-stakes fact-check tasks. Every user of fact-check mode will get wrong results or be confused by conflicting documentation. The skill is at v2.1.0 and the contradiction has been in place for at least 2 review rounds.
- **Concrete change:** Pick one semantics and align all four locations. I recommend the strict-majority semantics (any dissent blocks consensus) because it matches the "high-stakes fact-check" intent:
  - In `consolidation-rules.md:183`, change: `Algorithm: require > max(2, ceil(N/2)) models to agree on a value. For N=3, this means 3 votes needed; for N=5, 4 votes; for N=7, 5 votes. If met, return that value. If not, return "unverified" (or the schema's "verdict_uncertain_value" if defined).`
  - In `consolidation-rules.md:233`, change the example to a 3-0 scenario: `| claim X | verdict | 3 say "true", 0 dissent | majority-with-uncertain (threshold met) | "true" | high |`
  - In `fact-check.md:74`, change: `"if 2 say true and 1 says false, any dissent blocks consensus; return "unverified". Require > max(2, ceil(N/2)) models to agree for a clean verdict (so for N=3 you need all 3 votes, for N=5 you need 4 votes)."`
  - In `fact-check.md:103-108`, update the consensus requirements to use `>` instead of `≥` and update the example thresholds to `N=3 → 3`, `N=5 → 4`, `N=7 → 5`.
- **Effort:** Low (4 documentation edits, ~10 lines total)
- **Impact:** High (correctness of the most common conflict rule; removes a contradiction that has been flagged for 2 rounds)
- **Score:** High / Low = **High ROI**

### 2. Add a reference implementation for the Phase 2-3 pipeline

- **Issue:** The skill is 100% prose. Every orchestrating agent must re-implement table extraction (methodology.md:37-65), dedup (consolidation-rules.md:96-111), conflict resolution (consolidation-rules.md:163-221), and score aggregation (consolidation-rules.md:268-278) from pseudocode. There's no library, no script, no importable module. The pseudocode references undefined symbols (`normalize()`, `canonical`, `fields_per_model`) and can't be copy-pasted.
- **Why it matters:** Consolidation is "the core value of the skill" (SKILL.md:195). Without a reference implementation, every run is a fresh implementation that may differ subtly from the spec. This is the main barrier to adoption and the primary source of divergence between agents. R3 raised this; R4 didn't address it.
- **Concrete change:** Create `skills/multi-ai-task/lib/consolidate.js` (or `.py`) that implements:
  - `extractRows(markdown, schema)` — 4-fallback path from methodology.md:37-65
  - `buildRegistry(rows, aliases)` — dedup algorithm from consolidation-rules.md:96-111
  - `resolveConflicts(registry, schema)` — all named rules from consolidation-rules.md:163-221
  - `aggregateScores(registry, schema)` — median + min/max from consolidation-rules.md:268-278
  - `renderConsolidated(registry, schema, mode)` — render consolidated.md from the registry
  
  Include a CLI: `node lib/consolidate.js --schema schema.json --in-dir out/ --out-dir out/ --mode standard`. Add unit tests in `skills/multi-ai-task/tests/`.
- **Effort:** High (new file, ~300-500 lines of code + ~200 lines of tests)
- **Impact:** High (reduces agent errors, ensures consistency, makes the skill actually usable)
- **Score:** High / High = **Medium ROI** (long-term payoff, but high upfront cost)

### 3. Fix the unsafe `"$PROMPT"` shell injection vector in the default Mechanism 2 snippet (R3 caught this, R4 missed it)

- **Issue:** `dispatch-mechanics.md:49` and `research-prior-art.md:28` both pass the prompt via `"$PROMPT"` on the command line. If the prompt contains `$variable`, backticks, `"`, `\`, or newlines, the shell will interpret them before `npx` receives them. This is a shell-injection hazard for any prompt containing code examples.
- **Why it matters:** Every user who includes a code example in their prompt (a common case for code-review, fact-check with URLs, etc.) will hit a silent prompt corruption on first use.
- **Concrete change:** In both `dispatch-mechanics.md:36-58` and `research-prior-art.md:18-32`, replace the direct `"$PROMPT"` with a heredoc-then-`@file` pattern:
  ```bash
  cat > "$OUT/prompt.md" <<'PROMPT_EOF'
  $PROMPT_CONTENT
  PROMPT_EOF
  
  for model in ...; do
    slug=$(echo "$model" | sed 's|.*/||')  # extract last segment
    npx -y opencode-ai run \
      --model "$model" \
      --title "multi-ai-task-${slug}-$(date +%s)" \
      --dangerously-skip-permissions \
      @"$OUT/prompt.md" \
      > "$OUT/${slug}.md" 2> "$OUT/${slug}.err" &
  done
  ```
  This matches the pattern already used in `code-review.md:20-30` and `fact-check.md:20-35`. (The `cut -d/ -f2` extraction should also become `sed 's|.*/||'` to handle 3-segment model IDs.)
- **Effort:** Low (2 file edits, ~10 lines each)
- **Impact:** High (prevents a class of silent bugs that would make the skill unreliable for code-related tasks)
- **Score:** High / Low = **High ROI**

### 4. Resolve the `primary_key` schema field contradiction across examples

- **Issue:** `SKILL.md:96` and `research-prior-art.md:75` both use `"primary_key": "<column-name>"` as a top-level schema field. The code-review example at `code-review.md:70-71` explicitly says this is wrong: `"The string-form 'primary_key' is not a recognized schema field."` The research example — the only proven run — uses a pattern the other example says is invalid.
- **Why it matters:** An implementor reading both examples will not know which schema syntax is correct. The research example is the only proven run; if its schema is wrong, the provenance is questionable.
- **Concrete change:** In `SKILL.md:96` and `research-prior-art.md:75`, remove the `"primary_key"` line. The column definition immediately below (e.g., `{"name": "item", "type": "string", "dedup_key": true}`) already declares the dedup key correctly. Two-file edit, ~3 lines total.
- **Effort:** Low (2 file edits, ~3 lines)
- **Impact:** High (resolves a cross-file contradiction in the schema spec that has been flagged for 4 rounds)
- **Score:** High / Low = **High ROI**

### 5. Add timing data and input validation to `run-manifest.json` and the `--schema` parser

- **Issue:** (a) The manifest captures `timestamp` (start) but no duration, no per-model timing, no consolidation wall-time. The "When NOT to use" decision criterion at SKILL.md:41 ("Latency of slowest model + consolidation is OK") is unmeasurable. (b) The `--schema` JSON is accepted with zero validation. A user can pass `"conflict_resolution": {"category": "non-existent-rule"}` and the orchestrator will silently fail or produce garbage. Named rule references, column type validity, and `dedup_key` consistency are unchecked.
- **Why it matters:** (a) Without timing data, users can't evaluate the latency criterion or optimize future runs. (b) Schema errors produce output that looks right but is wrong — the worst kind of bug.
- **Concrete change:** (a) In `output-schema.md`'s `run-manifest.json` section, add to the `totals` object:
  ```json
  "totals": {
    "rows_per_model": {"m1": 25, "m2": 30},
    "unique_items_consolidated": 36,
    "conflicts_resolved": 8,
    "duration_ms": 180000,
    "per_model_duration_ms": {"m1": 120000, "m2": 95000, "m3": 180000},
    "consolidation_duration_ms": 5000
  }
  ```
  (b) Create `rules/schema-validation.md` with allowed values for `type`, `conflict_resolution` rule names (cross-referenced to consolidation-rules.md's named rule library), `aggregate` values, and validation rules (e.g., `min ≤ max`, `enum.values` non-empty). The orchestrator should validate in Phase 0 (before any dispatch).
- **Effort:** Medium (~5 lines added to schema spec, ~100 lines of new validation spec)
- **Impact:** High (timing data enables run optimization; schema validation prevents the most expensive kind of bug)
- **Score:** High / Medium = **High ROI**

---

## §4. Open Questions

1. **Is the skill intended as a procedural document, an LLM prompt, or a software artifact?** The current design is ambiguous: `SKILL.md` reads as a human reference, but the dispatch mechanics and pseudocode read as LLM-agent instructions, and there's no executable code. The answer determines every implementation decision. R3 raised this; R4 didn't.

2. **What is the actual version, and what changed between versions?** SKILL.md frontmatter says `2.1.0`. The task description for this review says `v2.0.0`. The fact-check example (`fact-check.md:77`) references a `v2.1.0 gap` fix. R3 and R4 both flagged this. There is no `CHANGELOG.md` documenting what changed between v2.0.0 and v2.1.0. Without one, it's impossible to know what the current version is supposed to be.

3. **Is the `majority-with-uncertain` threshold `≥ max(2, ceil(N/2))` or `> max(2, ceil(N/2))`?** The algorithm says `≥`; three example locations say `>`. The answer determines whether 2 votes of 3 is enough for `true`. This is a critical bug (see Improvement #1).

4. **How does the skill handle incremental runs?** The methodology says re-runs are "fresh" (methodology.md:173) but also mentions that `run-manifest.json` from previous runs can be referenced for "incremental consolidation (future enhancement)." What does incremental consolidation look like? If the user runs the skill, gets 4/6 model responses, and wants to add 2 more models without re-running the first 4, how does that work? No spec.

5. **What harness should the reference implementation target?** The dispatch mechanics are OpenCode-centric (Mechanism 1 references `opencode.json`, Mechanism 2 uses `npx opencode-ai run`). If a reference implementation is built, should it assume OpenCode, or be harness-agnostic? The skill says it's task-agnostic (SKILL.md:13) but the dispatch is harness-specific. This tension needs resolution.

6. **What's the consolidation wall-time?** For 36 items × 6 models, how long do Phases 3-4 take? The skill says "latency of slowest model + consolidation" (SKILL.md:41) but gives no bounds for the consolidation part. Without timing data in `run-manifest.json`, this is unmeasurable.

7. **What is the alias map file format?** The research example stores aliases as a markdown table (research-prior-art.md:125-141) and as a JSON object in `run-manifest.json` (output-schema.md:224). The JSON format is `{"AutoGen/AG2": "AutoGen"}` but the table format is `Alias | Canonical`. These two representations could diverge. Should there be a standard `aliases.json` or `aliases.toml` format? R3 raised this; R4 didn't.

8. **What is the distinction between `partially-true` and `unverified` in fact-check?** Both are valid verdict values. The schema allows both; the prose doesn't distinguish them. The answer determines when a fact-check run returns `partially-true` vs `unverified`.

9. **Does `--no-auto-inject` do anything in free-form mode (no `--schema`)?** If no schema is passed, there's nothing to inject. Is the flag silently ignored? The spec doesn't say.

10. **Why are code-review and fact-check proofs deferred to v2.2.0 when the skill claims v2.1.0 has been generalized?** The "task-agnostic" claim is undermined by having only one proven use case. What's the plan for proving the other task types?

11. **What is the `extractor model` selection heuristic?** R3 and R4 both raised this. The skill says "the slowest/highest-capability model from the dispatch" (methodology.md:53) but "highest capability" is undefined. Is it context window size? Parameter count? A benchmark score? The implementer has to guess.

12. **How does the calling agent detect completion when using Mechanism 1 (`task` tool)?** The bash `&` + `wait` pattern works for Mechanism 2. But if the skill is invoked via `task` tool, how does the orchestrator know all sub-models are done? Is there a completion signal?

---

## §5. Confidence

- **Overall confidence:** High
- **What would change my assessment:**
  1. **Resolution of the `majority-with-uncertain` algorithm contradiction** — the answer determines the most-used conflict rule's behavior. Until the four locations are aligned, the skill is internally inconsistent on its core algorithm.
  2. **A reference implementation that validates the algorithms against real multi-model output** — would surface latent edge cases (e.g., how `lowest-of-majors` behaves when `majority` returns `null`, how the table parser handles models that emit non-standard markdown tables, how the 4-fallback extraction path interacts with real model outputs). Until a reference implementation exists and has been run against diverse model outputs, my assessment assumes the prose algorithms are correct — but the gap between pseudocode and working code is where most bugs live.
  3. **A second worked example (code-review or fact-check) actually run** — would validate or invalidate the "task-agnostic" claim. Currently, the generalization rests on one proven run.

### Note on prior reviews

This review is the 5th round. I cross-checked prior review claims against the current file contents and found that **R4 introduced two incorrect claims that have been perpetuating**:
- R4 flagged `output-schema.md`'s `run-manifest.json` schema as "stale, missing v2.1.0 fields." This is **incorrect** for the current version — the schema at `output-schema.md:209-254` does include `phases_completed`, `consolidation`, `schema_auto_injected`, and `aliases` (lines 235, 230, 218, 224). R3 may have been looking at a pre-v2.1.0 version, and R4 uncritically re-flagged it.
- R4 flagged the Mechanism 2 dispatch snippet (`dispatch-mechanics.md:36-58`) as "TIMEOUT is declared but never used." This is **incorrect** for the current version — the snippet does wire `"$TIMEOUT_CMD" "$TIMEOUT" npx ...` (line 52). R3's finding is the one that's still valid: the snippet uses `"$PROMPT"` directly, which is the shell-injection vector.

Future reviews should re-verify prior-review claims against the current file content before propagating them. R3 (`multi-ai-self-review-r3-20260627-critical.md`) is the strongest prior review and identified the `majority-with-uncertain` algorithm bug, the shell-injection vector, and the missing reference implementation — all of which remain unfixed in this round.
