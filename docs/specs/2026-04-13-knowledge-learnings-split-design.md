# Design: Knowledge & Learnings Directory Split

**Date:** 2026-04-13
**Replaces:** `docs/KNOWLEDGE.md` (single-file accumulated intelligence)

## Problem

KNOWLEDGE.md mixes two concerns: project-specific intelligence and portable engineering/domain learnings. It's also a single append-only file with no scalability enforcement, destined to exceed LLM context limits on long-lived projects.

## Solution

Split into two directories with monthly file segmentation:

- `docs/knowledge/` — project-scoped intelligence (architecture patterns, gotchas, decisions, open questions)
- `docs/learnings/` — portable learnings (tech stack, engineering practices, DevOps, domain knowledge)

## `docs/knowledge/` — Project-Scoped Intelligence

**Content:** Things learned about THIS project that aren't derivable from code or git history.

**Categories:** Architecture Patterns, Known Gotchas, Key Decisions, Recurring Patterns, Open Questions

**File convention:** `YYYY-MM.md` — one file per month, append-only within that month, frozen after.

**Not redundant with:**
- `docs/ARCHITECTURE.md` (current architecture, not the journey of discovering it)
- Phase `CONTEXT.md` files (single-phase decisions, archived on milestone completion)
- `docs/tech-debt.md` (actionable items to fix, not knowledge to remember)

**Gateway:** `docs/knowledge/INDEX.md` replaces KNOWLEDGE.md Part 1 (doc path table).

## `docs/learnings/` — Portable Learnings

**Content:** General learnings applicable beyond this project. Written as if explaining to someone who has never seen this codebase. No project-specific file paths, feature names, requirement IDs, or entity references.

**Category taxonomy (extensible):**
- `domain:{area}` — business domain learnings (regulations, industry patterns, terminology)
- `stack:{technology}` — language/framework/tool-specific learnings
- `practice:{area}` — software engineering practices (testing, review, architecture, security)
- `devops:{area}` — CI, deployment, monitoring, infrastructure
- `design:{area}` — UI, UX, accessibility patterns

**File convention:** `YYYY-MM.md` — same monthly segmentation as knowledge.

## Scalability

- Monthly files stay bounded (~50-150 lines for active projects)
- No rotation needed — natural monthly segmentation handles growth
- Safety cap: if a monthly file exceeds 300 lines, split into `YYYY-MM-a.md` / `YYYY-MM-b.md`
- Old files are never modified
- LLM reads only current month's file + INDEX.md during sessions

## Lifecycle

| Event | knowledge/ | learnings/ |
|-------|-----------|----------|
| Documentation step | Append to current month | Append to current month |
| New month begins | New file on first entry | New file on first entry |
| Milestone completion | No special action | No special action |
| CHANGELOG entry | Reference which files updated | Reference categories added |

## Migration

1. Create `docs/knowledge/INDEX.md` from KNOWLEDGE.md Part 1
2. Create `docs/knowledge/2026-04.md` from KNOWLEDGE.md Part 2 entries
3. Extract portable learnings into `docs/learnings/2026-04.md`
4. Delete `docs/KNOWLEDGE.md`
5. Update workflow Documentation step references
6. Update templates
