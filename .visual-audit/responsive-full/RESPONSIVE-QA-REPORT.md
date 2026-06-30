# Silver Bullet Responsive Visual QA Report

**Date:** 2026-06-30  
**Target:** https://sb.alolabs.dev (live, branch `main`)  
**Capture dir:** [`.visual-audit/responsive-full/2026-06-30/`](2026-06-30/)  
**Method:** Playwright full-matrix capture (375 / 768 / 1280 px × light / dark) + programmatic overflow audit + Gemini 3.5 Flash vision review

---

## Executive Summary

| Metric | Value |
|--------|------:|
| **Public pages tested** | 46 |
| **Breakpoint × theme combinations** | 276 (46 × 3 × 2) |
| **Screenshot files** | 388 (56 long pages use hero/mid/footer sections) |
| **Capture errors** | 0 |
| **Pages with horizontal overflow @ 375px** | 21 |
| **Pages clean @ 768px & 1280px** | 46 / 46 |
| **Theme toggle pass rate** | 46 / 46 |
| **Overall ship readiness** | **FAIL** |

**Verdict:** Desktop and tablet layouts are ship-ready. **Mobile (375px) fails** due to widespread horizontal page scroll on help documentation pages with reference tables, plus minor overflow on changelog/gaps. Theme system and mobile hamburger nav work correctly on all tested pages.

---

## Capture Matrix

### Page inventory (46 public pages)

Excluded: `_chrome/` partials, `og-card.html`, `graphify-out/graph.html`.

| Section | Count | Slugs |
|---------|------:|-------|
| Top-level | 6 | `home`, `changelog`, `gaps`, `brute`, `privacy`, `terms` |
| Help hub & sections | 6 | `help`, `help-getting-started`, `help-reference`, `help-troubleshooting`, `help-dev-workflow`, `help-devops-workflow` |
| Concepts | 9 | `help-concepts` + 8 concept pages |
| Workflows | 25 | `help-workflows` + 24 workflow pages |

### Breakpoints & themes

- **375px** — mobile
- **768px** — tablet
- **1280px** — desktop
- **light** / **dark** via `localStorage.silver-bullet-theme` + `data-theme`

### Pragmatic sectioning (56 captures)

Pages taller than 12,000px use **hero + mid + footer** viewport shots instead of single full-page PNG:

- Homepage (`home-*`)
- All workflow reader pages with long content
- Reference, gaps, dev-workflow pages
- Naming: `{slug}-{theme}-{width}px-{hero|mid|footer}.png`

Full-page PNG used for shorter pages (help hub, terms, privacy, changelog, etc.).

---

## Summary Table

| Severity | Unique issues (page × breakpoint) | Theme instances (×2) |
|----------|----------------------------------:|---------------------:|
| **CRITICAL** | 10 | 20 |
| **MAJOR** | 5 | 10 |
| **MINOR** | 8 | 16 |
| **PASS (no issue)** | 25 pages @ 375px; all 46 @ 768/1280 | — |
| **Total flagged** | 23 page-breakpoint combos | 46 theme instances |

---

## Findings by Severity

### CRITICAL — mobile horizontal page scroll (>50px overflow @ 375px)

| Page | Overflow | Screenshot(s) | Root cause |
|------|----------|---------------|------------|
| `/help/workflows/` | 328px | [`help-workflows-light-375px-mid.png`](2026-06-30/help-workflows-light-375px-mid.png) | `.ref-table` (679px) not wrapped in `.table-wrap`; grid column expands page |
| `/help/concepts/routing-logic.html` | 209px | [`help-concepts-routing-logic-light-375px-mid.png`](2026-06-30/help-concepts-routing-logic-light-375px-mid.png) | Same `.ref-table` pattern |
| `/help/concepts/composable-workflow.html` | 173px | [`help-concepts-composable-workflow-light-375px-mid.png`](2026-06-30/help-concepts-composable-workflow-light-375px-mid.png) | Same |
| `/help/workflows/silver-ship-readiness.html` | 155px | [`help-workflows-silver-ship-readiness-light-375px-mid.png`](2026-06-30/help-workflows-silver-ship-readiness-light-375px-mid.png) | Same |
| `/help/workflows/silver-review-triad.html` | 109px | [`help-workflows-silver-review-triad-light-375px-mid.png`](2026-06-30/help-workflows-silver-review-triad-light-375px-mid.png) | Same |
| `/help/workflows/silver-forensics.html` | 106px | [`help-workflows-silver-forensics-light-375px-mid.png`](2026-06-30/help-workflows-silver-forensics-light-375px-mid.png) | Same |
| `/help/workflows/silver-process-maintenance.html` | 83px | [`help-workflows-silver-process-maintenance-light-375px-mid.png`](2026-06-30/help-workflows-silver-process-maintenance-light-375px-mid.png) | Same |
| `/help/workflows/silver-incident.html` | 75px | [`help-workflows-silver-incident-light-375px-mid.png`](2026-06-30/help-workflows-silver-incident-light-375px-mid.png) | Same |
| `/help/workflows/silver-research.html` | 73px | [`help-workflows-silver-research-light-375px-mid.png`](2026-06-30/help-workflows-silver-research-light-375px-mid.png) | Same |
| `/help/reference/` | 72px | [`help-reference-light-375px-mid.png`](2026-06-30/help-reference-light-375px-mid.png) | Local `.doc-layout { grid-template-columns: 220px 1fr }` overrides global `minmax(0,1fr)`; `.ref-table td:first-child { white-space: nowrap }` prevents shrink |

**Impact:** Users on phones must horizontal-scroll the entire page to read workflow catalogs and reference tables. Affects both light and dark themes identically.

---

### MAJOR

| Page | Breakpoint | Theme | Issue | Screenshot |
|------|------------|-------|-------|------------|
| `/help/concepts/` | 375px | both | 64px page overflow — concept index tables | [`help-concepts-light-375px-mid.png`](2026-06-30/help-concepts-light-375px-mid.png) |
| `/help/concepts/documentation.html` | 375px | both | 50px overflow — doc tables | [`help-concepts-documentation-light-375px-mid.png`](2026-06-30/help-concepts-documentation-light-375px-mid.png) |
| `/help/workflows/silver-retro.html` | 375px | both | 65px overflow | [`help-workflows-silver-retro-light-375px-mid.png`](2026-06-30/help-workflows-silver-retro-light-375px-mid.png) |
| `/gaps/` | 375px | both | 29px overflow; topnav links clipped ("Part…" truncated) | [`gaps-light-375px-hero.png`](2026-06-30/gaps-light-375px-hero.png) |
| Homepage hero | 1280px | dark | Subtitle/secondary text contrast borderline (vision) | [`home-dark-1280px-hero.png`](2026-06-30/home-dark-1280px-hero.png) |

**Gaps root cause:** `.backlog-grid { grid-template-columns: repeat(auto-fill, minmax(380px, 1fr)) }` — 380px min exceeds 375px viewport; `.topnav .nav-inner` (535px) also wider than viewport.

---

### MINOR

| Page | Breakpoint | Theme | Issue | Screenshot |
|------|------------|-------|-------|------------|
| `/help/workflows/silver-feature.html` | 375px | both | 35px overflow | [`help-workflows-silver-feature-light-375px-mid.png`](2026-06-30/help-workflows-silver-feature-light-375px-mid.png) |
| `/help/concepts/cost-optimization.html` | 375px | both | 33px overflow | [`help-concepts-cost-optimization-light-375px-mid.png`](2026-06-30/help-concepts-cost-optimization-light-375px-mid.png) |
| `/help/concepts/preferences.html` | 375px | both | 15px overflow | [`help-concepts-preferences-light-375px-hero.png`](2026-06-30/help-concepts-preferences-light-375px-hero.png) |
| `/help/troubleshooting/` | 375px | both | 15px overflow | [`help-troubleshooting-light-375px.png`](2026-06-30/help-troubleshooting-light-375px.png) |
| `/help/dev-workflow/` | 375px | both | 11px overflow | [`help-dev-workflow-light-375px-mid.png`](2026-06-30/help-dev-workflow-light-375px-mid.png) |
| `/help/workflows/silver-benchmark.html` | 375px | both | 11px overflow | [`help-workflows-silver-benchmark-light-375px-mid.png`](2026-06-30/help-workflows-silver-benchmark-light-375px-mid.png) |
| `/changelog/` | 375px | both | 7px overflow; timeline alignment slightly off (vision) | [`changelog-light-375px.png`](2026-06-30/changelog-light-375px.png) |
| `/help/` | 375px | dark | Search bar focus ring low contrast (vision) | [`help-dark-375px.png`](2026-06-30/help-dark-375px.png) |

---

## PASS — No issues detected

### All breakpoints (768px, 1280px) — 46/46 pages

Zero document-level horizontal overflow at tablet and desktop widths in both themes.

### Mobile 375px — 25/46 pages clean

Including: **homepage**, **help hub**, **getting-started**, **devops-workflow**, **terms**, **privacy**, **brute**, and 18 workflow/concept pages without wide tables.

Representative PASS screenshots:

- [`home-light-375px-hero.png`](2026-06-30/home-light-375px-hero.png) / [`home-dark-375px-hero.png`](2026-06-30/home-dark-375px-hero.png)
- [`help-light-375px.png`](2026-06-30/help-light-375px.png) / [`help-dark-375px.png`](2026-06-30/help-dark-375px.png)
- [`terms-light-375px.png`](2026-06-30/terms-light-375px.png)
- [`home-light-1280px-hero.png`](2026-06-30/home-light-1280px-hero.png)

---

## Functional Checks

| Check | Result | Notes |
|-------|--------|-------|
| Theme toggle (`#theme-toggle` / `.help-theme-btn`) | **PASS 46/46** | Toggles `data-theme` light ↔ dark on every page |
| Mobile hamburger (`.nav-toggle` → `.nav-links.active`) | **PASS** | Opens nav with Problem, What If, How It Works, Workflows, Install, GitHub |
| Help search UI present | **PASS** | `#help-search` / search bar on help hub and doc pages |
| Code blocks | **PASS @768+**; scroll inside block @375 | Inline code wraps; pre blocks use `overflow-x:auto` |
| Tables | **FAIL @375** | `.ref-table` without `.table-wrap` causes page-level scroll on 21 pages |

---

## Top 10 Issues (priority order)

1. **CRITICAL** — `/help/workflows/` — 328px mobile page overflow from uncapped `.ref-table` ([screenshot](2026-06-30/help-workflows-light-375px-mid.png))
2. **CRITICAL** — `/help/concepts/routing-logic.html` — 209px overflow ([screenshot](2026-06-30/help-concepts-routing-logic-light-375px-mid.png))
3. **CRITICAL** — `/help/concepts/composable-workflow.html` — 173px overflow
4. **CRITICAL** — `/help/workflows/silver-ship-readiness.html` — 155px overflow
5. **CRITICAL** — `/help/workflows/silver-review-triad.html` — 109px overflow
6. **CRITICAL** — `/help/reference/` — 72px overflow; grid override + `white-space:nowrap` on command cells ([screenshot](2026-06-30/help-reference-light-375px-mid.png))
7. **MAJOR** — `/gaps/` — 29px overflow; topnav clipped; `.backlog-grid minmax(380px,1fr)` ([screenshot](2026-06-30/gaps-light-375px-hero.png))
8. **MAJOR** — `/help/concepts/` index — 64px overflow from catalog tables
9. **MAJOR** — Homepage dark theme @1280px — hero subtitle contrast borderline ([screenshot](2026-06-30/home-dark-1280px-hero.png))
10. **MINOR** — `/changelog/` — 7px overflow + timeline bullet alignment ([screenshot](2026-06-30/changelog-light-375px.png))

---

## Recommended Fixes (review only — not applied)

1. Wrap all `.ref-table` elements in `.table-wrap { overflow-x:auto }` on help doc templates, or add global CSS rule.
2. Replace `grid-template-columns: 220px 1fr` with `220px minmax(0, 1fr)` in [`site/help/reference/index.html`](../../site/help/reference/index.html) local styles.
3. Allow `.ref-table td:first-child` to wrap on mobile via `@media (max-width:768px) { white-space: normal; word-break: break-all; }`.
4. Add mobile override for `.backlog-grid` in [`site/gaps/index.html`](../../site/gaps/index.html): `minmax(0, 1fr)` or single column.
5. Collapse gaps `.topnav` links into hamburger or scrollable row @375px.

---

## Artifacts

| Artifact | Path |
|----------|------|
| Screenshots | [`.visual-audit/responsive-full/2026-06-30/`](2026-06-30/) (388 PNG, ~145 MB) |
| Capture manifest | [`2026-06-30/capture-manifest.json`](2026-06-30/capture-manifest.json) |
| Capture log | [`2026-06-30/capture.log`](2026-06-30/capture.log) |
| Capture script | [`capture-matrix.mjs`](capture-matrix.mjs) |
| This report | [`RESPONSIVE-QA-REPORT.md`](RESPONSIVE-QA-REPORT.md) |

---

## Ship Readiness Verdict

### **PASS** — mobile overflow fixed 2026-06-30

See [`RESPONSIVE-QA-FIX.md`](RESPONSIVE-QA-FIX.md) for fix details and re-test results.

- **Was:** 10 CRITICAL + MAJOR mobile overflow issues on help/reference/workflow pages.
- **Fix:** Shared rules in `site/chrome.css` (grid `minmax(0,1fr)`, `.doc-content` scroll containment, nowrap override, gaps backlog grid, changelog code wrap).
- **Re-test:** 21/21 previously failing pages @ 375px → 0px overflow (`overflow-check.mjs`).
- **Ready:** Tablet (768px), desktop (1280px), theme system, core marketing pages, **mobile help docs**.
- **Optional follow-up:** Homepage dark hero subtitle contrast @1280px (vision-only, not overflow).
