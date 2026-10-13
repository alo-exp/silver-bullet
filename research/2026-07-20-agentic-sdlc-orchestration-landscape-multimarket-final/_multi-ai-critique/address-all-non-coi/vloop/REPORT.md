# Independent V-loop — address-all-non-coi

**Overall: PASS**

Timestamp (UTC): 2026-07-21T21:20:49.992004+00:00

Canonical: `file://` — prior PASS not trusted.

| # | Claim | Verdict |
|---|-------|---------|
| 1 | Tembo NOT in SaaS MQ Leaders/core plotted set; adjacent/unplotted as claimed | **PASS** |
| 2 | landscape/inclusion-ledger.md exists and linked/referenced from report §1 | **PASS** |
| 3 | Blue Ocean scores are 1/3/5 feature-pass (not only binary 3/5); Zuvo absent from BO | **PASS** |
| 4 | developer.ibm.com count = 0 in landscape-report.html | **PASS** |
| 5 | COI ignored for SB demotion — SB still plotted high/Leaders | **PASS** |
| 6 | CHECKLIST has no DEFERRED-NEED-USER rows | **PASS** |
| 7 | file:// renders | **PASS** |
| 8 | Prior hard fixes intact: Director≠Superpowers, cc10x clean, Harness not→claude-code homepage, plugins MQ not all y=9.5 | **PASS** |

## Hard FAIL fixed this pass

Criterion 8 initially **FAIL**: Claude Harness homepage `https://github.com/anthropics/claude-code` still in SPA (category-pack `homepage_by_slug` reintroduced on regen).

Fix: removed pack mapping; MD unlink; chart-data scrub; `filter_vendor_link_pairs` guard; SPA regen.

## Artifacts

- [`RESULT.json`](RESULT.json)
- [`FILE-RENDER.json`](FILE-RENDER.json)
- Report: [`landscape-report.html`](../../../landscape-report.html)
