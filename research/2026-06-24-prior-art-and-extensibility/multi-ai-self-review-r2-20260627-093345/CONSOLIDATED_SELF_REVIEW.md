# Self-Review: multi-ai-task Skill v2.1.0 → v2.2.0 (Round 2)

**Date:** 2026-06-27
**Method:** Round-2 use of the multi-ai-task skill on itself. 6 OCG models (minimax-m3, qwen3.7-max, glm-5.2, kimi-k2.6, mimo-v2.5-pro, deepseek-v4-pro) re-reviewed the skill after the round-1 fixes. Same prompt, same methodology. This is the diff between round-1 (v2.0.0) and round-2 (v2.1.0) findings.
**Round 1 source:** `docs/research-260624/multi-ai-self-review-20260627-083255/`
**Round 2 source:** `docs/research-260624/multi-ai-self-review-r2-20260627-093345/`

---

## 1. Executive Summary

**The round-1 fixes are validated but round-2 surfaced critical new issues introduced by the v2.1.0 changes themselves.** Most consequential: the `most-severe` algorithm I added in round 1 is **inverted** — `max(values, key=severity_order.index)` with `severity_order=["blocker", "major", "minor", "nit"]` (index 0, 1, 2, 3) picks the LARGEST index = `"nit"` (least-severe). The opposite of intent. This is a real algorithmic bug in the skill's "core value" (per its own documentation).

**Per-model scores (8-dimension rubric, 0-16):**

| Model | Round 1 | Round 2 | Δ |
|-------|--------:|--------:|---:|
| minimax-m3 | 10 | 7 | -3 |
| qwen3.7-max | 5 | 6 | +1 |
| glm-5.2 | 11 | 10 | -1 |
| kimi-k2.6 | 7 | 10 | +3 |
| mimo-v2.5-pro | 5 | 6 | +1 |
| deepseek-v4-pro | 6 | 9 | +3 |
| **Median** | **~7** | **~8** | **+1** |

The score divergence is wider (range 6-10 vs 5-11), reflecting the polarization: some models got stricter (minimax saw new issues in v2.1.0), some got more generous (kimi, deepseek approved of the named-rule library). Net median up by 1.

---

## 2. Critical Findings (Round-2 New Issues)

### 2.1 CRITICAL: `most-severe` algorithm inverted

**Flagged by:** 4/6 models (qwen, kimi, deepseek; glm mentioned it)

**Issue:** In `consolidation-rules.md:175`, the algorithm is `max(values, key=severity_order.index)`. The default `severity_order` is `["blocker", "major", "minor", "nit"]` (most-severe first; indices 0, 1, 2, 3). `max(values, key=index)` picks the LARGEST index = `"nit"` (least-severe) — the opposite of the rule's name and intent.

**Fix applied (v2.2.0):** Changed to `min(values, key=severity_order.index)` (smallest index = most-severe = first in the list). Added a clarifying note: "if `severity_order` is declared, the convention is **most-severe first** (index 0 is the most-severe value)."

### 2.2 Triple-inconsistency on `majority-with-uncertain` return value

**Flagged by:** 3/6 models (qwen, kimi, deepseek)

**Issue:** Same algorithm returned 3 different values across 3 files:
- `consolidation-rules.md:187` → returns `uncertain`
- `consolidation-rules.md:236` (example row) → returns `unverified`
- `examples/fact-check.md:63` → returns `partially-true`

**Fix applied (v2.2.0):** Standardized on `unverified` (matching the schema's `values: ["true", "false", "partially-true", "unverified"]`). Added a "naming consistency" note: if a schema uses a different name for the "unverified" verdict, set `conflict_resolution.verdict_uncertain_value: "partially-true"` to remap. The rule's return value is fixed; the schema adapts.

### 2.3 `majority-with-uncertain` threshold inconsistency

**Flagged by:** 2/6 (kimi, deepseek)

**Issue:** The rule says "require ≥ `max(2, ceil(N/2))`". For N=3, this is 2. But the fact-check example said "require ≥3 votes for a clean verdict" — a hardcoded 3 that contradicts the parameterized rule.

**Fix applied (v2.2.0):** Fact-check example now correctly says "require ≥ `max(2, ceil(N/2))` models to agree for a clean verdict (so for N=3 you need 2 votes, not 3)." Added a worked N=3 example.

### 2.4 `extractor model: no extra cost` fabrication

**Flagged by:** 1/6 (minimax) — but the bug is real

**Issue:** `methodology.md:104` claimed the extractor "caches the response, no extra cost". This is false — the extractor is a fresh LLM call with a new prompt.

**Fix applied (v2.2.0):** Replaced with accurate cost description: "Cost: one additional LLM call per model whose structured extraction failed (paths 1 and 2 in the pseudocode). For N=6 models where 2 fail structured extraction, expect 2 additional LLM calls."

### 2.5 Code-review.md dispatch bug (file-name collision)

**Flagged by:** 4/6 (minimax, glm, kimi, deepseek) — duplicated from round 1

**Issue:** `code-review.md:30` uses `> "code-review-${model}.md"` where `$model` contains a slash (e.g., `opencode-go/minimax-m3`). This creates a subdirectory `code-review-opencode-go/` or fails.

**Fix applied (v2.2.0):** Rewrote the entire dispatch to use:
- `OUT=./multi-ai-out/...` and `mkdir -p "$OUT"`
- `slug=$(echo "$model" | cut -d/ -f2)` for sanitization
- `> "$OUT/${slug}.md"`
- Heredoc prompt (avoids shell-metacharacter injection in `--dangerously-skip-permissions`)

### 2.6 Code-review.md composite key syntax contradiction

**Flagged by:** 3/6 (qwen, kimi, deepseek)

**Issue:** `code-review.md:40` had `"primary_key": "file:line"` (string concatenation), but `SKILL.md:143` says composite keys are expressed by listing multiple columns with `dedup_key: true`. The two are inconsistent.

**Fix applied (v2.2.0):** Schema now uses `dedup_key: true` on both `file` and `line` columns. Removed the bogus `primary_key: "file:line"` string. Added explanatory paragraph.

### 2.7 Fact-check.md and code-review.md use `--dangerously-skip-permissions` unconditionally

**Flagged by:** 3/6 (glm, kimi, deepseek)

**Issue:** Both examples pass the unsafe flag even though `dispatch-mechanics.md:56` says "For write tasks, do NOT use this flag". Read-only review (no edits) and read-only fact-check (no edits) should not bypass permissions.

**Fix applied (v2.2.0):** Both examples now OMIT `--dangerously-skip-permissions` with an explicit security note: "READ-ONLY task; if you want a review-and-fix variant, add the flag and accept the risk."

### 2.8 Duplicate §2 numbering in `output-schema.md`

**Flagged by:** 4/6 (minimax, qwen, kimi, mimo)

**Issue:** Both Mode A and Mode B items tables were labeled `## §2. Items Table`.

**Fix applied (v2.2.0):** Renamed to `## §2A.` and `## §2B.`.

### 2.9 `run-manifest.json` schema inconsistent across 3 files

**Flagged by:** 3/6 (minimax, qwen, kimi)

**Issue:** Three different versions of the manifest in SKILL.md, methodology.md, output-schema.md. Missing fields: `schema_auto_injected`, `aliases`, `phases_completed`.

**Fix applied (v2.2.0):** `methodology.md` now has the canonical schema with all required fields. SKILL.md and output-schema.md reference it. The canonical version lives in methodology.md (the first place a reader looks for "what files does the skill produce").

### 2.10 Structured.jsonl circular reference

**Flagged by:** 1/6 (minimax)

**Issue:** `methodology.md:28` example had `"raw_text_ref": "structured.jsonl#L1"` — but structured.jsonl is the file the record is being written TO. Circular.

**Fix applied (v2.2.0):** Changed to `"source_refs": ["minimax-m3.md#L42-50"]` (pointing to the per-model raw output, which is the correct target) and added `"raw_text": "LangGraph is a framework for..."` (the actual raw cell content).

### 2.11 SKILL.md argument-hint omits `--concurrency`

**Flagged by:** 1/6 (minimax) — but trivially fixable

**Issue:** `SKILL.md:4` listed `--models, --out, --schema, --mode, --no-auto-inject`. The inputs table at `SKILL.md:69` added `--concurrency`. The hint and the table didn't match.

**Fix applied (v2.2.0):** Argument-hint now includes `--concurrency parallel|sequential`.

### 2.12 Date-folder mismatch in `research-prior-art.md`

**Flagged by:** 1/6 (glm)

**Issue:** Folder named `docs/research-260624/` (encodes 2026-06-24) but the run was on 2026-06-27.

**Fix applied (v2.2.0):** Added a "Folder-name note" paragraph in SKILL.md explaining that the folder name is a pre-existing docs convention; the run date is in `run-manifest.json → timestamp`. Did NOT rename the folder (30+ cross-references).

### 2.13 SKILL.md does not declare whether skill is documentation or executable

**Flagged by:** 4/6 (minimax, qwen, kimi, mimo)

**Issue:** `methodology.md:19` says retry policy is "in the calling agent's runner", implying the skill is a docset the agent reads. But the usage example shows `/multi-ai-task "<task-prompt>"` as a CLI invocation. Inconsistent.

**Fix deferred to v2.3.0+** (requires architectural decision: ship an executable, or fully commit to documentation-only with clearer framing). Documented in §6.

---

## 3. Round-2 Issues Already Validated (not re-fixed)

- **Mechanism 1 framing** ("preferred-if-available") — round 1's fix is consistent with the docs; no reviewer objected.
- **Mechanism 2 bash example** — round 1's slug fix is in place; no reviewer objected.
- **Schema auto-inject** (default ON, `--no-auto-inject` opt-out) — round 1's fix is consistent.
- **Conflict-resolution named rules** (`most-severe`, `majority-with-uncertain`, `lowest-of-majors`, `concatenate-all`, `all-collected`, `union-dedup`, `merge-exact`) — all formally defined; no reviewer objected to their *existence*, but the `most-severe` algorithm is wrong (see §2.1).
- **Research-specific content moved to examples** — mostly done. The residual 11-entry `aliases` object at `consolidation-rules.md:85-95` was the only leftover. Fixed in §2.0 (above).

---

## 4. Cross-Model Conflict Resolutions Applied

| Conflict | Disagreement | Resolution per §8.2 |
|---------|-------------|---------------------|
| Is the `most-severe` algorithm right? | minimax: not flagged; qwen/kimi/deepseek: inverted (algorithmic bug); glm: underspecified | **Bug confirmed by pseudocode analysis** — applied `min()` fix |
| Should `majority-with-uncertain` return `unverified` or `partially-true`? | qwen/kimi/deepseek: `unverified`; glm: unstated | **Standardized on `unverified`** (matches schema's `values`) |
| Should `majority-with-uncertain` threshold be `max(2, ceil(N/2))` or hardcoded `3`? | kimi/deepseek: parameterized; glm: hardcoded | **Parameterized** (correct algorithm) |
| Does `extractor model` cost extra? | minimax: not flagged; mimo: yes; minimax called out as fabrication | **Yes**, explicit cost added |
| `output-schema.md` Mode A vs Mode B — same `§2`? | 4/6 flagged as duplicate | **Renamed to `§2A` / `§2B`** |
| Date folder `260624` vs run date `2026-06-27`? | glm only | **Documented as convention**, no rename |
| `user-invocable: false` vs usage shows `/multi-ai-task`? | minimax only | **Deferred to v2.3.0** (requires architectural decision) |

---

## 5. Top 5 Improvements Deferred (still v3.0.0 territory)

| # | Improvement | Why deferred |
|---|------------|--------------|
| 1 | Implement executable backend (`scripts/multi-ai-task.sh`) | Major architectural change; requires tests; would ship as v3.0.0 |
| 2 | Add machine-readable `pipeline.json` manifest | Couples to executable backend (or to a skill-loader integration) |
| 3 | Add overlay-pack loader for team customization | Requires new config layer |
| 4 | Tiered evidence sufficiency model (proper rubric with primary/secondary/tertiary) | Distinct from current `prefer-with-evidence` proxy |
| 5 | Worked code-review and fact-check examples (real runs) | Requires running the skill on real tasks; high effort but high credibility |

---

## 6. Open Questions (carry-forward to v2.3.0)

1. **Documentation or executable?** — the frontmatter says `user-invocable: false`, the usage says `/multi-ai-task`, and there's no `scripts/multi-ai-task.sh`. Pick one and document it explicitly. v2.3.0.
2. **Cost model disclosure** — the skill dispatches N + thorough-mode-verifier calls. Quantify the cost in tokens/dollars for a typical run. v2.3.0.
3. **Thorough-mode verifier failure handling** — if the verifier model says a source URL doesn't support the claim (`source_verified: false`), does the item get downgraded, removed, or flagged? Currently undefined. v2.3.0.
4. **Model refusal handling** — if a model refuses the prompt, is it logged as a failure or excluded silently? Not covered. v2.3.0.
5. **Cross-harness dispatch** — Mechanism 5 for Claude/Cursor/Codex is requested by 1/6 reviewers. v3.0.0.

---

## 7. Files Changed (v2.1.0 → v2.2.0)

| File | Change |
|------|--------|
| `SKILL.md` | Argument-hint: added `--concurrency`. Proven provenance: added "Folder-name note" and round-2 review pointer. |
| `rules/methodology.md` | `run-manifest.json`: unified schema with `schema_auto_injected`, `aliases`, `phases_completed` fields. `structured.jsonl` example: fixed circular reference. `extractor model` cost: corrected fabrication. |
| `rules/consolidation-rules.md` | **`most-severe` algorithm: inverted bug FIXED** (min instead of max). `majority-with-uncertain`: standardized to return `unverified`. Residual alias table: removed from core. |
| `rules/output-schema.md` | §2 duplicate: renamed to §2A/§2B. `structured.jsonl` example: fixed circular reference. |
| `rules/examples/code-review.md` | **Dispatch bug FIXED**: slug sanitization, $OUT/mkdir, heredoc prompt, removed `--dangerously-skip-permissions`. **Composite key syntax FIXED**: removed bogus `primary_key: "file:line"`, added `dedup_key: true` on file+line columns. **Security note added**. |
| `rules/examples/fact-check.md` | **Dispatch bug FIXED**: same as code-review. **Threshold consistency FIXED**: parameterized `max(2, ceil(N/2))` instead of hardcoded 3. **Unverified value standardized**. **Security note added**. |

---

## 8. Confidence

**Overall: High** for the round-2 fixes. The 13 round-2 issues are mostly small (typos, name conflicts, dispatch bugs) plus one critical algorithmic bug (`most-severe` inverted). v2.2.0 strictly improves on v2.1.0.

**Lower confidence** on:
- Whether the new `most-severe` algorithm is what reviewers meant. The 4/6 reviewers who flagged it didn't propose a fix; some may have intended `max` with a reversed `severity_order`. The current fix (switch to `min` with "most-severe first" convention) is the most natural reading but could be re-interpreted.
- Whether v2.2.0 is enough. v3.0.0 is on the horizon with executable backend, machine-readable manifest, overlay packs. The "documentation vs executable" question needs an architectural decision before v3.0.0.

---

## 9. v2.1.0 → v2.2.0 score projection

| Dimension | v2.0.0 (round 1) | v2.1.0 (post-round-1) | v2.2.0 (post-round-2) |
|-----------|----------:|----------:|----------:|
| Catalog of composable units | 1 (median) | 1 | 1 |
| Dynamic composition | 0 | 0 | 0 |
| V-loop depth | 1 | 1 | 1 |
| Enforcement | 0 | 0 | 0 |
| Parent/worker split | 2 | 2 | 2 |
| Evidence model | 1 | 1 | 2 (with `all-collected`/`union-dedup` formally defined) |
| SE + DevOps unified | 1 | 1 | 1 |
| Team customization | 0 | 0 | 0 |
| **Total** | **6** | **6** | **7** |

Modest improvement. The bigger jumps (Dynamic composition, Enforcement, Team customization → 1) require architectural changes (v3.0.0).
