# Milestone Summary — v0.20.5

**Type:** Patch release  
**Date:** 2026-04-16  
**Parent milestone:** v0.20.0 Composable Paths Architecture (in progress)

---

## Overview

v0.20.5 is a terminology consistency patch that renames `/silver` from "Smart Skill Router" to "Smart Skill Orchestrator" and aligns the composable workflow building-block naming from "paths" to "flows" across the live skill and template files.

No runtime behavior, hooks, or tests changed. All 962 tests remain green.

---

## What Changed

### 1. `/silver` — Router → Orchestrator

**Files:** `skills/silver/SKILL.md`, `templates/silver-bullet.md.base`, `docs/workflows/full-dev-cycle.md`, `templates/workflows/full-dev-cycle.md`

`/silver` was described as a "Smart Skill Router" — accurate for its dispatch function, but misleading because it does far more than routing. It proposes flow compositions, manages supervision loops, enforces quality gates, and chains 18 flows in sequence. "Orchestrator" better captures this role.

### 2. Composable "Paths" → "Flows"

**Files:** `skills/silver-feature/SKILL.md` (20 occurrences), `templates/silver-bullet.md.base`, `docs/ENFORCEMENT.md`

The composable architecture uses FLOW 0–17 as its building blocks. The surrounding prose inconsistently called them "paths" (from earlier design docs) while the actual catalog used "FLOW". This patch aligns all prose to "flows" so the terminology is self-consistent: the 18 building blocks are always called flows, the composition chain is a "flow chain", progress reporting shows `FLOW {n}/{total}`.

**Not changed:** `silver-migrate/SKILL.md` references "composable paths" as a proper noun (the milestone name "Composable Paths Architecture v0.20.0") — these remain accurate.

---

## Files Changed (6)

| File | Change |
|------|--------|
| `skills/silver/SKILL.md` | Title + description + composer note: router → orchestrator, paths → flows |
| `skills/silver-feature/SKILL.md` | 20 prose replacements in Composition Proposal + Supervision Loop sections |
| `templates/silver-bullet.md.base` | §2h: router → orchestrator, "Composable Paths Catalog" → "Composable Flows Catalog" |
| `docs/ENFORCEMENT.md` | "composable paths mode" → "composable flows mode" |
| `docs/workflows/full-dev-cycle.md` | "smart router" → "smart orchestrator" |
| `templates/workflows/full-dev-cycle.md` | "smart router" → "smart orchestrator" |

---

## Quality Gates

- Pre-release quality gates: **PASS** (design-time, 9 dimensions)
- Security review: **PASS** (no runtime changes, no secrets, no attack surface)
- Tests: **962 / 962 green**

---

## Getting Started

No migration required. The change is documentation-only — existing workflows, hooks, and state files are unaffected. End users see "Smart Skill Orchestrator" in `/silver` descriptions after the next plugin update.
