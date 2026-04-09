# Forensic Report: Skipped/Deferred Work Since v0.11.0

**Date:** 2026-04-10
**Scope:** All milestones v0.11.0 through v0.15.3
**Method:** Git history, verification reports, review findings, REQUIREMENTS.md, ROADMAP.md, episodic memory
**Evidence sources examined:** 44+ data points across 9 categories

---

## Executive Summary

Investigation found **12 still-open items** from work that was skipped, scope-minimized, or rationalized away. 4 previously-open items have been resolved in code. The most impactful gaps are a macOS-incompatible grep pattern in a critical hook, stale requirement checkboxes creating false signals, and a missing content diff feature.

---

## Prioritized Open Items

### P1 — Functional Bugs (fix now)

| # | Item | Phase | Impact | Evidence |
|---|------|-------|--------|----------|
| 1 | **`\b` word boundary in spec-floor-check.sh** — uses `\b` in `grep -E`, which is PCRE-only. On macOS stock grep, the hook silently fails to match, disabling spec floor enforcement entirely. | 12-WR-01 | **CRITICAL** — security hook disabled on macOS | `hooks/spec-floor-check.sh:44,46` |
| 2 | **grep `^## Overview` matches prefix** — also matches `## Overviewer`, `## Overview of X`. Should be `^## Overview$`. | 12-WR-02 | LOW — unlikely false positive but incorrect | `hooks/spec-floor-check.sh:63` |
| 3 | **curl fallback hardcodes `main` branch** — repos using `master` or custom default branches will fail on cross-repo spec fetch. | 13-WR-01 | MEDIUM — breaks for non-`main` repos | `skills/silver-ingest/SKILL.md:270` |

### P2 — Missing Features (implement)

| # | Item | Phase | Impact | Evidence |
|---|------|-------|--------|----------|
| 4 | **BFIX-04: Version mismatch content diff** — spec version mismatch shows version numbers only, not a diff of what changed. ROADMAP required a diff. | 13-SC5 | MEDIUM — user can't assess mismatch severity | `skills/silver-ingest/SKILL.md` |
| 5 | **No minimum turn enforcement in silver-spec** — 9-turn elicitation marked "NON-SKIPPABLE" in prose but has no mechanical guard. Claude can skip turns freely. | 12-IN-03 | MEDIUM — quality gate is advisory only | `skills/silver-spec/SKILL.md` |
| 6 | **REQUIREMENTS.md staged unconditionally** — `git add .planning/REQUIREMENTS.md` runs even if file wasn't modified, creating noise commits. | 12-WR-03 | LOW — cosmetic but messy | `skills/silver-spec/SKILL.md:230` |

### P3 — Documentation/Tracking Debt (clean up)

| # | Item | Phase | Impact | Evidence |
|---|------|-------|--------|----------|
| 7 | **REQUIREMENTS.md: 9 stale checkboxes** — BFIX-01..04, EXRV-01..04, WFIN-10 unchecked despite work being done. Creates false impression of incomplete milestone. | v0.15.0 | HIGH — misleading project state | `.planning/REQUIREMENTS.md` |
| 8 | **ROADMAP.md: Phases 12, 13 unchecked** — both phases fully executed with all plans, reviews, verifications complete. Checkboxes never updated. | v0.14.0 | MEDIUM — misleading project state | `.planning/ROADMAP.md` |
| 9 | **Quick task 260409-4vd missing SUMMARY** — work completed (3 commits) but tracking artifact absent. | Quick | LOW — incomplete audit trail | `.planning/quick/260409-4vd/` |
| 10 | **ENF-HARNESS-09 missing from requirements** — requirement IDs skip from 08 to 10. Either a gap or a numbering error. | Phase 8 | LOW — tracking gap | `.planning/ROADMAP.md` |

### P4 — Deferred by Design (future milestone)

| # | Item | Phase | Impact | Evidence |
|---|------|-------|--------|----------|
| 11 | **ARVW-09: Cross-artifact consistency reviewer** | v2 | Deferred — future release | `.planning/REQUIREMENTS.md` |
| 12 | **ARVW-10: Review round analytics** | v2 | Deferred — future release | `.planning/REQUIREMENTS.md` |
| 13 | **ARVW-11: Configurable review depth** | v2 | Deferred — future release | `.planning/REQUIREMENTS.md` |

### Previously Open, Now Resolved

| Item | Resolution |
|------|-----------|
| BFIX-01 (shell injection in silver-ingest) | Fixed: regex validation `^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$` |
| BFIX-02 (heredoc injection in pr-traceability) | Fixed: sed sanitization of warn_items |
| BFIX-03 (Confluence [ARTIFACT MISSING]) | Fixed: explicit failure handler in silver-ingest |
| apply_fix undefined / save ordering | Fixed: review-loop.md defines contract, ordering corrected |

---

## Methodology

- **Git log:** `v0.11.0..HEAD` (300+ commits), keyword search for skip/defer/scope/abbreviate
- **Verification reports:** All VERIFICATION.md files in `.planning/phases/` and `.planning/archive/v0.14.0/`
- **Code reviews:** All REVIEW.md files in same locations
- **Requirements:** `.planning/REQUIREMENTS.md` checkbox state
- **Roadmap:** `.planning/ROADMAP.md` checkbox state
- **Episodic memory:** Past session investigations
- **File system:** Direct inspection of hook scripts and skill files
