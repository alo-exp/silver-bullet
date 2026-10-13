# Task: Critical Self-Review of the multi-ai-task Skill

You are conducting a **critical self-review** of a skill that may be invoked by you or your peers. Your job is to find real issues, gaps, and improvements — **not** to be polite, validate the existing design, or restate what the skill does.

## The Skill

**Location:** `/Users/shafqat/projects/silver-bullet/repo/skills/multi-ai-task/`

**Files to read (use the read tool for each — do not skip any):**

1. `SKILL.md` — entry point, usage, when to use/not use, provenance
2. `rules/methodology.md` — 4-phase pipeline
3. `rules/dispatch-mechanics.md` — 4 dispatch mechanisms
4. `rules/consolidation-rules.md` — dedup, conflict resolution, scoring aggregation
5. `rules/output-schema.md` — output structure
6. `rules/examples/research-prior-art.md` — the proven worked example
7. `rules/examples/code-review.md` — recipe for code-review use
8. `rules/examples/fact-check.md` — recipe for fact-check use

**Context:** This skill is at v2.0.0. It was generalized from a research-focused v1.0.0 to be task-agnostic. The parent orchestrator is using this skill RIGHT NOW to review itself — this is a meta-task.

## Required Output Schema

Return results as markdown. One section per part below.

### §1. Critical Assessment

For each of the 8 files, note:
- **What works well** (1-2 bullets, brief)
- **What is missing or wrong** (1-3 bullets, with the specific issue)
- **What is unclear or ambiguous** (1-2 bullets, with the specific question)

If a file is fine in some area, say "no issues" and move on. Do not pad.

### §2. Score the Skill on the 8-Dimension Rubric

Use the skill's own scoring rubric (defined in `consolidation-rules.md` and the prior-art research example):

| Dimension | 0 | 1 | 2 |
|---|---|---|---|
| Catalog of composable units | None | Informal roles | Machine-readable catalog |
| Dynamic composition | None | Replanner | Catalog-backed + audit log |
| V-loop depth | None | End tests | Per-step rollup + intent gate |
| Enforcement | Honor system | CI only | IDE hooks + delivery blockers |
| Parent/worker split | No | Partial | Explicit orchestrator/worker |
| Evidence model | None | Informal | Tiered sufficiency + staleness |
| SE + DevOps unified (N/A for this skill — judge as "covers both production task types" or "covers neither") | One domain | Partial | Both in one model |
| Team customization (N/A for a skill — judge as "supports team process packs" or "doesn't") | None | Fork required | Overlay packs |

For each, score 0-2 and justify in 1-2 sentences. Total: 0-16.

### §3. Top 5 Improvements (ranked by impact × effort)

For each:
- **Issue** (one-line)
- **Why it matters** (1 sentence)
- **Concrete change** (file:line, with the proposed fix text or sketch)
- **Effort** (low / medium / high)
- **Impact** (low / medium / high)
- **Score** (impact / effort, higher = better ROI)

### §4. Open Questions

What would you need to know to make a more confident review? What's unclear about the skill's intent, scope, or intended audience?

### §5. Confidence

- **Overall confidence:** high / medium / low
- **What would change your assessment** (1-2 sentences)

## Important

- **Be skeptical, not polite.** Find real issues. Do not summarize what the skill does well unless it is genuinely excellent.
- **Cite specific text from the skill files.** Quote the relevant line(s) when flagging an issue.
- **Prefer concrete, actionable changes** over general advice. "Improve clarity" is useless; "rename §X to §Y because Z" is useful.
- **If the skill is fine in some area, say so briefly and move on.** Do not pad every section with boilerplate praise.
- **Do NOT modify the skill files.** This is a read-only review. Your output is the review.

## Method

- Use the `read` tool to load each file before commenting on it.
- Use `grep` / `glob` to find specific patterns if needed (e.g., recurring terms, missing fields).
- Your output should be self-contained — quote the relevant text from the skill, don't just say "see file X".
- The expected review is ~50-150 KB of output. Be thorough but not bloated.
