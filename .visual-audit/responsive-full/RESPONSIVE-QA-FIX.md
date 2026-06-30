# Responsive QA Fix — Mobile Horizontal Overflow

**Date:** 2026-06-30  
**Commit:** [667114ef](https://github.com/alo-exp/silver-bullet/commit/667114ef)  
**File changed:** [`site/chrome.css`](../../site/chrome.css)

## Problem

21 pages had document-level horizontal overflow at 375px, primarily from:

- Per-page inline `<style>` overriding shared `chrome.css` grid (`220px 1fr` vs `minmax(0,1fr)`)
- `.ref-table` elements without `.table-wrap` expanding grid columns
- `white-space: nowrap` on mono command cells
- Gaps `.backlog-grid { minmax(380px, 1fr) }` exceeding viewport
- Changelog inline `<code>` extending past viewport by 7px

## Fix (shared CSS)

All fixes in `site/chrome.css`:

| Rule | Effect |
|------|--------|
| `body.has-help-subnav .doc-layout` with `!important` | `minmax(0,1fr)` beats per-page inline grid |
| `body.has-help-subnav .doc-content { overflow-x:auto }` | Wide tables scroll inside content column, not page |
| `.ref-table td:first-child { white-space:normal !important }` | Mono cells wrap on mobile |
| `@media (max-width:768px) .backlog-grid { grid-template-columns:1fr }` | Gaps backlog single-column on mobile |
| `main code { overflow-wrap:anywhere }` | Changelog inline code no longer bleeds |

## Re-test @ 375px (local, `overflow-check.mjs`)

| Page | Before | After |
|------|-------:|------:|
| `/help/workflows/` | 328px | **0px** |
| `/help/concepts/routing-logic.html` | 209px | **0px** |
| `/help/concepts/composable-workflow.html` | 173px | **0px** |
| `/help/workflows/silver-ship-readiness.html` | 155px | **0px** |
| `/help/workflows/silver-review-triad.html` | 109px | **0px** |
| `/help/reference/` | 72px | **0px** |
| `/help/concepts/` | 64px | **0px** |
| `/gaps/` | 29px | **0px** |
| `/changelog/` | 7px | **0px** |
| All 21 previously failing pages | — | **0px** |

**Result:** `Total failures: 0` (21/21 PASS)

## Site tests

| Suite | Passed |
|-------|-------:|
| `test-site-chrome-regression.sh` | 14 |
| `test-site-content-freshness.sh` | 67 |
| `test-site-doc-freshness.sh` | 4 |
| **Total** | **85** |

## Ship readiness

**PASS** — mobile horizontal overflow blockers resolved. Re-run full matrix with `node .visual-audit/responsive-full/capture-matrix.mjs` after deploy for screenshot evidence.
