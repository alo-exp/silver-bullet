# Milestone Summary — v0.19.0

**Released:** 2026-04-14
**Type:** Ad-hoc release (no formal GSD phases)

---

## Overview

v0.19.0 adds the `silver:brainstorm-idea` workflow — the earliest-stage entry point for new ideas — and removes the `quality-gate-stage-N` state marker mechanism, which was Ālo labs-internal overhead that should not have been part of the base Silver Bullet template.

**Changes shipped:**
1. New `silver:brainstorm-idea` orchestrator skill
2. `/silver` router updated with brainstorm-idea routing row
3. Hook simplification: `stop-check.sh` and `dev-cycle-check.sh`
4. Base template cleanup: `templates/silver-bullet.md.base` §9 removed (Pre-Release Quality Gate is Ālo labs only)
5. Site refresh: all "seven" → "eight" workflow count updates, new brainstorm-idea card and routing table row

---

## What Was Built

### silver:brainstorm-idea

A new idea-stage orchestrator that fires when a user describes a concept before any spec exists. Chains four steps in order:

1. `product-management:product-brainstorming` — PM lens (problem space, personas, success metrics)
2. `superpowers:brainstorming` — Engineering lens (architecture options, trade-offs)
3. `gsd-new-milestone` — Conditional: creates milestone scaffolding if no active milestone exists
4. `gsd-discuss-phase` — Locks Phase 1 decisions into CONTEXT.md before planning begins

**Routing signal:** `silver/SKILL.md` routes here when the user describes a new concept and `.planning/SPEC.md` does not yet exist. SPEC.md presence is the binary disambiguator between `silver:brainstorm-idea` (pre-spec) and `silver:feature` (spec exists).

### Hook Simplification

Removed the `quality-gate-stage-N` state marker mechanism from:
- `hooks/stop-check.sh` — eliminated `check_quality_gate_stages` function and `release_context` block
- `hooks/dev-cycle-check.sh` — eliminated `quality-gate-stage-[1-4]` whitelist entry

**Rationale:** The individual skill markers (`code-review`, `requesting-code-review`, `security`, `verification-before-completion`, etc.) already prove each quality gate stage was completed. The `quality-gate-stage-N` layer was redundant and forced direct state file writes, breaking autonomous execution.

### Base Template Cleanup

Removed `## 9. Pre-Release Quality Gate` from `templates/silver-bullet.md.base`. This 4-stage gate (Code Review Triad, Consistency Audit, Public Content Refresh, SENTINEL Security Audit) is specific to Ālo labs plugin development and must not propagate to end-user projects initialized via `silver-init`.

User Workflow Preferences renumbered from §10 → §9 in the base template. All `§10` references updated to `§9`.

---

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| `product-brainstorming` before `superpowers:brainstorming` | Matches established silver-feature pattern; PM lens frames the problem before engineering explores solutions |
| SPEC.md presence as routing disambiguator | Binary signal: either a spec exists (route to silver:feature) or it doesn't (route to silver:brainstorm-idea) |
| AskUserQuestion A/B/C when active milestone exists | Prevents silently running gsd-discuss-phase on the wrong milestone |
| Explicit "Assumption:" paragraph in Step 3 | Documents that gsd-new-milestone sets active phase in STATE.md; provides fallback if it doesn't |
| Remove quality-gate-stage-N entirely (not just fix) | Individual skill markers are ground truth; the redundant layer was the problem |
| §9 Pre-Release Quality Gate stays in silver-bullet.md only | Ālo labs internal process; end-user projects should not inherit it |

---

## Files Changed

| File | Change |
|------|--------|
| `~/.claude/skills/silver-brainstorm-idea/SKILL.md` | NEW — idea-to-milestone orchestrator |
| `~/.claude/skills/silver/SKILL.md` | Added brainstorm-idea routing row, conflict resolution entry, Step 3 menu option |
| `.silver-bullet.json` | Added `silver-brainstorm-idea` to `all_tracked` |
| `silver-bullet.md` | §2h: seven→eight, new workflow row |
| `templates/silver-bullet.md.base` | Removed §9 Pre-Release Quality Gate, renumbered §10→§9, removed quality-gate-stage bullet |
| `hooks/stop-check.sh` | Removed check_quality_gate_stages function and release_context block |
| `hooks/dev-cycle-check.sh` | Removed quality-gate-stage-[1-4] whitelist entry |
| `site/help/workflows/index.html` | seven→eight, new brainstorm-idea card |
| `site/help/index.html` | seven→eight |
| `site/index.html` | seven→eight (×4) |
| `site/og-card.html` | seven→eight |
| `site/help/reference/index.html` | seven→eight |
| `site/help/concepts/routing-logic.html` | seven→eight, new brainstorm-idea table row |
| `site/help/search.js` | seven→eight, new brainstorm-idea search entry |
| `README.md` | Added brainstorm-idea row to skill table |

---

## Tech Debt

None introduced. The hook simplification reduced existing complexity.

---

## Getting Started with silver:brainstorm-idea

Invoke via `/silver` (auto-routed) or directly:

```
/silver I want to build a tool that [description]
```

The router sends idea-stage inputs (no SPEC.md present) to `silver:brainstorm-idea` automatically. Steps are NON-SKIPPABLE — product brainstorming and engineering brainstorming both run before milestone setup.
