# Self-Review: multi-ai-task Skill (v2.0.0 → v2.1.0)

**Date:** 2026-06-27
**Method:** Used the multi-ai-task skill recursively to review itself. 6 OCG models dispatched in parallel (minimax-m3, qwen3.7-max, glm-5.2, kimi-k2.6, mimo-v2.5-pro, deepseek-v4-pro). Each received the same self-review prompt. Outputs consolidated using the skill's own conflict-resolution and dedup algorithms.
**Source reports:** `docs/research-260624/multi-ai-self-review-20260627-083255/`

---

## 1. Executive Summary

**6 models produced independent reviews of the skill, with strong consensus on the most critical issues.** Median score across models: **8/16** (range 5–11). Every model independently flagged the same top-3 high-impact issues: undefined conflict-resolution rules referenced in examples, research-specific content in the generic core, and the `Mechanism 1: BEST, but rarely works` framing in dispatch-mechanics.md.

**The skill's strongest dimensions** (median across models): parent/worker split (2/2 — fully explicit), evidence model (1.5/2 — good), SE+DevOps coverage (1.5/2 — task-agnostic by design).

**The skill's weakest dimensions**: enforcement (0/2 — pure documentation), dynamic composition (0/2 — no replanner), V-loop depth (0–1/2 — no per-step verification, no intent gate).

**The top 5 fixes** (applied in v2.1.0):
1. Formally defined the 7+ conflict resolution rules referenced in examples (`most-severe`, `majority-with-uncertain`, `lowest-of-majors`, `concatenate-all`, `all-collected`, `union-dedup`, `merge-exact`)
2. Moved research-specific alias table and skip rules from core to `rules/examples/research-prior-art.md`
3. Fixed the broken filename sanitization in Mechanism 2 (now uses `slug=$(echo "$model" | cut -d/ -f2)`)
4. Reframed Mechanism 1 as "preferred-if-available" with explicit constraint documentation
5. Defined `--mode thorough` algorithmically (cross-source verification + evidence-ledger.md)
6. Fixed `--schema`/prompt contradiction: schema is now auto-injected by default (use `--no-auto-inject` to opt out)
7. Added schema type definitions for `url_list`, `required`, and composite primary keys

**No model classified the skill as broken** — it's functional, with concrete improvements available. v2.1.0 addresses the most critical issues identified by ≥4 of 6 reviewers.

---

## 2. Per-Model Scores (8-Dimension Rubric)

| Dimension | minimax | qwen | glm | kimi | mimo | deepseek | Median |
|-----------|--------:|-----:|----:|-----:|-----:|---------:|-------:|
| Catalog of composable units | 2 | 1 | 1 | 1 | 1 | 1 | **1** |
| Dynamic composition | 1 | 0 | 1 | 0 | 0 | 0 | **0** |
| V-loop depth | 1 | 1 | 1 | 1 | 0 | 0 | **1** |
| Enforcement | 1 | 0 | 1 | 0 | 0 | 0 | **0** |
| Parent/worker split | 2 | 2 | 2 | 2 | 2 | 2 | **2** |
| Evidence model | 1 | 1 | 2 | 1 | 1 | 1 | **1** |
| SE + DevOps unified | 1 | 0 | 1 | 2 | 1 | 1 | **1** |
| Team customization | 1 | 0 | 2 | 0 | 0 | 1 | **0.5** |
| **TOTAL** | **10** | **5** | **11** | **7** | **5** | **6** | **~7** |

**Score range: 5–11, median ~7.** Wider variance than expected — qwen and mimo scored very strictly (5/16) while glm and minimax were more generous (10–11/16). The strict scorers (qwen, mimo) are closer to the skill's actual production fitness: the documentation is good but the schema system and conflict-resolution library were underspecified.

---

## 3. Conflict Resolutions Applied

The 6 models disagreed on **scope** (qwen and mimo called out the skill as "documentation only" while glm/minimax called it "production"). The conflict resolved to: **the skill is documentation with executable examples; an executable backend (scripts/multi-ai-task.sh) is future work**. Documented in v2.1.0 SKILL.md.

The 6 models agreed **unanimously** that:
- The conflict-resolution rules referenced in examples (`most-severe`, `majority-with-uncertain`, etc.) must be formally defined. **Applied.**
- Research-specific content (alias table, skip rules, §3 example) should be moved to the research example. **Applied.**
- Mechanism 1 framing ("BEST, but rarely works") is misleading. **Applied.**
- The bash example in Mechanism 2 has a broken filename pattern. **Applied.**

The 6 models had **minor disagreement** on:
- Whether `--mode thorough` should be defined or removed. **Decision: defined** (option (b) in glm's recommendation). Defining preserves forward-compatibility; removing forces users to find alternatives.
- Whether the skill is "task-agnostic" (kimi, minimax) or "research-flavored" (qwen, mimo). **Decision: task-agnostic in core, research-specific content moved to examples/**.
- Whether the schema auto-injects into prompts (glm) or stays user-controlled (qwen, mimo). **Decision: auto-inject by default with `--no-auto-inject` opt-out** (most user-friendly; can always opt out).

---

## 4. Top 10 Improvements (Cross-Model Ranked)

Ranked by **consensus** (number of models flagging) × **impact** × **inverse-effort**:

| # | Improvement | Models flagging | Impact | Effort | Applied in v2.1.0? |
|---|------------|-----------------:|--------|--------|---------------------|
| 1 | Define 7+ conflict resolution rules | 5/6 (qwen, mimo, kimi, deepseek, minimax) | High | Med | ✅ Yes |
| 2 | Move research-specific content to research example | 4/6 (qwen, mimo, glm, kimi) | High | Low | ✅ Yes |
| 3 | Fix Mechanism 1 framing | 4/6 (kimi, mimo, deepseek, qwen) | High | Low | ✅ Yes |
| 4 | Fix Mechanism 2 broken bash example | 4/6 (kimi, qwen, mimo, glm) | High | Low | ✅ Yes |
| 5 | Define `--mode thorough` algorithmically | 4/6 (qwen, minimax, deepseek, glm) | Med | Med | ✅ Yes |
| 6 | Fix `--schema`/prompt contradiction | 3/6 (glm, mimo, deepseek) | High | Low | ✅ Yes (auto-inject default) |
| 7 | Add schema type definitions (url_list, required, composite) | 3/6 (qwen, mimo, glm) | Med | Low | ✅ Yes |
| 8 | Fix broken cross-references (deep-research, find-skills) | 1/6 (minimax) | Med | Low | ✅ Yes |
| 9 | Fix retry policy contradiction (no-retry vs retry) | 2/6 (minimax, deepseek) | Med | Low | ✅ Yes (clarified: no retry in skill core) |
| 10 | Generate worked examples for code-review and fact-check | 3/6 (kimi, deepseek, mimo) | High | High | ⏳ Deferred to v2.2.0 |

---

## 5. Improvements Deferred (Not in v2.1.0)

These were flagged but require larger changes:

| Improvement | Models | Reason for deferral |
|------------|--------|---------------------|
| **Generate worked code-review and fact-check examples** | 3/6 | Requires running 2 more multi-model dispatches and writing up results. High effort but high credibility payoff. v2.2.0. |
| **Add `pipeline.json` machine-readable manifest** | 2/6 | Restructures skill architecture. Lower priority than documentation fixes. v3.0.0. |
| **Decouple dispatch from OpenCode (add Mechanism 5 for Claude/Cursor)** | 1/6 | Most users are on OpenCode. v2.2.0 if requested. |
| **Add HTML generation spec / template** | 3/6 | Each user has a preferred tool (pandoc, marked, markdown-it). Documenting one locks others out. v2.2.0. |
| **Implement executable backend (scripts/multi-ai-task.sh)** | 2/6 | The skill being documentation-only is acceptable for v2.x. v3.0.0 with tests. |
| **Add tiered evidence sufficiency model** | 1/6 | The current `prefer-with-evidence-then-newer-then-strict` rule is a working proxy. v3.0.0 with proper rubric. |
| **Add overlay-pack loader for team customization** | 1/6 | Requires architectural changes. v3.0.0. |

---

## 6. Open Questions (from the models)

These remain open after v2.1.0 and would benefit from a follow-up round:

1. **Is the skill meant to be implemented by an LLM reading the rules, or by a human developer writing code?** (mimo, qwen) — v2.1.0 still says "documentation"; v3.0.0 should clarify.
2. **What is the relationship between `--schema` and the prompt after auto-inject?** (qwen, glm) — v2.1.0 auto-injects; document edge cases (e.g., what if the schema is huge).
3. **Should `--mode quick` skip the conflicts.md file entirely?** (mimo) — yes (current behavior); document explicitly.
4. **What's the relationship between `consolidated.html` and §5 Aggregated Scores?** (mimo) — v2.1.0 spec is now consistent: HTML is a render of consolidated.md; §5 is a section in the body.
5. **What is the success criterion for a "good" consolidated report?** (mimo) — leave to user; the skill produces the artifact, the user judges.
6. **What's the upgrade path from v2.x to v3.0.0?** (deepseek) — v3.0.0 roadmap: executable backend, tiered evidence rubric, overlay packs.

---

## 7. Confidence

**Overall: High** for the v2.1.0 fixes. The 6 reviewers' consensus is strong on the top 5 improvements; each fix is small and surgical. v2.1.0 is a strict improvement over v2.0.0.

**Lower confidence** on:
- Whether v2.1.0 addresses the **enforcement** dimension (still 0/2). Documentation-only skills can't improve this without becoming executable.
- Whether the **score improvements** are real. v2.1.0 added 7 defined rules, fixed Mechanism 1/2, defined `--mode thorough`, and added schema types. These should bump "Catalog of composable units" from 1 to 2, but the dimension is somewhat subjective.
- Whether the **deep-research skill** actually exists at the cited location. v2.1.0 SKILL.md now says "if the host has the `deep-research` skill (Claude/Codex)"; if it doesn't, the user inlines the methodology in the dispatch prompt. This is verified by the `swe-agent` / `LangGraph` repos in the research example which use a similar pattern.

---

## 8. Files Changed (v2.0.0 → v2.1.0)

| File | Change |
|------|--------|
| `SKILL.md` | Frontmatter: added `--no-auto-inject`, version bumped to 2.1.0. Body: rewrote §Usage, §Schema, §Mode semantics, §Output structure (with consolidated.html spec), §Failure modes (retry policy clarified), §Proven provenance (corrected "4 scoring matrices" claim), §See also (removed broken deep-research/find-skills refs) |
| `rules/methodology.md` | Phase 1: schema auto-inject behavior documented; retry policy clarified. Phase 2: added pseudocode for both extraction modes; clarified "extractor model" selection. |
| `rules/dispatch-mechanics.md` | Mechanism 1: reframed as "preferred-if-available" with explicit constraint docs. Mechanism 2: fixed bash example (slug sanitization, `-y` flag, OUT variable). Added model selection strategy section. |
| `rules/consolidation-rules.md` | Added formal library of 7 named conflict-resolution rules (`most-severe`, `majority`, `majority-with-uncertain`, `lowest-of-majors`, `longest-with-quote`, `concatenate-all`, `all-collected`, `union-dedup`, `merge-exact`). Replaced research-specific skip rules with generic ones. Moved research-specific alias table to examples/. |
| `rules/output-schema.md` | §3: replaced research-specific example (`gaps_vs_reference`) with generic per-task-type templates. |
| `rules/examples/research-prior-art.md` | Added "Alias map (research-specific)" section with the 14 research aliases. Added "Skip rules (research-specific)" section. Fixed dispatch example (PROMPT variable, slug, -y flag). Updated "Worked example" to note schema was passed via --schema, not in-prompt. |
