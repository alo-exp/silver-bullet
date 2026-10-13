# V-loop recheck (file://) — independent verification

**Canonical view mode:** `file://` (macOS `open` of the HTML SPA). No localhost/http.server required.

- Report: [`../landscape-report.html`](../../landscape-report.html)
- file URL: `file:///Users/shafqat/.cursor/worktrees/repo/3ht3/research/2026-07-20-agentic-sdlc-orchestration-landscape-multimarket-final/landscape-report.html`
- Automation: Playwright `page.goto(fileURL)` (same file:// path; not a product requirement)
- Fresh evidence JSON: [`vloop-recheck.json`](vloop-recheck.json)
- Script: [`vloop-fileurl.mjs`](vloop-fileurl.mjs)

**Overall: PASS** (`passAll: true`) — no hard regressions; **no fixes applied**.

## PASS/FAIL table

| # | Check | Result | Fresh evidence |
|---|-------|--------|----------------|
| 1 | Report renders live (file:// + Playwright) — no Marked/parseInline crash; no blanking console errors | **PASS** | `protocol: "file:"`, `h1` present, `bodyLen=18536`, `pageErrors=[]`, `consoleErrors=[]`, screenshot [`VLOOP-1280.png`](VLOOP-1280.png) shows full SPA + banner |
| 2 | Marked CDN pinned to `11.1.1` | **PASS** | `https://cdn.jsdelivr.net/npm/marked@11.1.1/marked.min.js` |
| 3 | Zero links from "SDLC Plugin" (or similar) to `claude.com/plugins` | **PASS** | Exact "SDLC Plugin" `<a>` count=0; SDLC-like hrefs are in-page `#h-*` only; `Claude Code Expert` may still use `claude.com/plugins` (distinct vendor) |
| 4 | Critical fill-gap banner when Self-serve/Managed hosting are 0% | **PASS** | Banner visible: "Self-serve signup (0/34); Managed hosting (0/34)…" |
| 5 | Challengers filter disabled / empty-state when 0 challengers | **PASS** | `disabled=true`, class `vfbtn is-empty` |
| 6 | Card title `.vc-name-link` homepage links + external `target="_blank"` `rel="noopener noreferrer"` | **PASS** | 31 name-links, 390 http links; `missingBlank=0`, `missingRel=0` |
| 7 | fontsource 404s gone (Google Fonts loads) | **PASS** | `failed404=[]`, Google Fonts stylesheet loads; fontsource only mentioned in HTML comment |
| 8 | Overflow @375 ≈ 0px | **PASS** | `overflow=0` (`scrollWidth=375`, `innerWidth=375`); [`VLOOP-375.png`](VLOOP-375.png) |
| 9 | Claimed screenshots/JSON in `_adversarial-audit/` exist and match current behavior | **PASS** | `AFTER-*.png`, `audit-AFTER.json`, `FINDINGS.md` present; AFTER JSON claims match recheck (marked pin, sdlcLinkCount 0, banner, challenger disabled, overflow 0) |
| 10 | Leaders filter does not list MQ Visionaries as Leaders (Cavekit etc.) | **PASS** | Live Leaders set: Augment Cosmos, Claude Code, Codex, Cursor, Devin, Factory.ai — **no Cavekit**; embedded MQ point `Cavekit v3.1` q=`Visionaries`; static `vendor_buckets.leaders` exclude Cavekit |

## Defects found

None (hard regression / false URL / file:// break).

## Fixes applied

None.

## Screenshots (this recheck)

| Viewport | Path |
|----------|------|
| 1280 light→dark cycle | [`VLOOP-1280.png`](VLOOP-1280.png), [`VLOOP-dark-1280.png`](VLOOP-dark-1280.png) |
| 375 | [`VLOOP-375.png`](VLOOP-375.png) |

## Notes

- Prior audit scripts defaulted to `http://127.0.0.1` — **automation limitation only**. Product SPA works under `file://` (verified).
- MQ vs GMQ: Cavekit appears as Visionaries (MQ) and Leaders (GMQ) in chart points; **filter buckets are MQ-authoritative** and exclude Cavekit from Leaders — consistent with claimed F3 fix.
