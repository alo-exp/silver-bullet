# P0 fix checklist (final)

Generated: 2026-07-22 — multi-AI critique P0 hard defects applied.

Report: [`landscape-report.html`](../../landscape-report.html) · source md: [`landscape/landscape-report.md`](../../landscape/landscape-report.md)

## Must-fix (P0) — status

| # | Defect | Status | Notes |
|---|--------|--------|-------|
| 1 | Director card = Superpowers overview | **FIXED** | SCR + §6 card rewritten to Director identity |
| 2 | cc10x card = methodology / SB-anchor leak | **FIXED** | SCR + §5 card rewritten to product identity |
| 3 | AI-DLC attributed to IBM (links awslabs) | **FIXED** | Report, SCRs, consolidation, envelopes scrubbed → AWS / awslabs |
| 4 | Claude Harness → anthropics/claude-code | **FIXED** | Unlinked; heading `UNVERIFIED — not anthropics/claude-code` |
| 5 | Zuvo identity / Leader collision | **FIXED** | Quarantined watchlist; removed from sdlc-plugins core/mq/gmq/wave |
| 6 | MetaGPT core vs adjacent self-conflict | **FIXED** | Kept APO core; §13 no longer lists MetaGPT as adjacent-only |
| 7 | Stale Zuvo coverage-gap while core Leader | **FIXED** | Coverage section now documents quarantine |
| 8 | Devin Adjacent-only vs SaaS Leader | **FIXED** | Scope note: APO-adjacent host vs tertiary SaaS core |
| 9 | comparison-matrix.md stub | **FIXED** | Regenerated from `comparison.json` + SPA pointer |
| 10 | MQ markdown tables = GMQ (not mq_data) | **FIXED** | §3.x.2 rebuilt from `mq_data` |

## Cheap P1 — status

| Item | Status | Notes |
|------|--------|-------|
| Empty Challengers | **FIXED** | `vendor_buckets.challengers` ← APO GMQ Challengers + prose note |
| Wave truncate / all-Strong | **FIXED** | Full `wave_data` rows with numeric labels + footnote |
| Notable Leader definition conflicts | **PARTIAL** | MQ tables aligned to `mq_data`; Blue Ocean caption clarifies column set ≠ Leader-only; full GMQ-vs-MQ axis rename deferred |

## Deferred (not clear corruption / larger judgment)

- Full COI / independent SB scoring review (policy)
- Plugins all-Leaders / y=9.5 ceiling rebalance (scoring redesign)
- Populate missing commercial URLs / adoption metrics
- Historical phase JSON under `phases/` left as audit trail (still mention IBM in old retrieve dumps)

## Files changed (primary)

- `solutions/{director,cc10x,claude-harness,zuvo,ai-dlc,conductor}/scr.md`
- `landscape/landscape-report.md`
- `landscape/chart-data.json`
- `landscape/catalog_audit.json`
- `comparison/comparison-matrix.md`
- `comparison/comparison.json` (research_type + caveats)
- `consolidated/consolidation.json`
- `contributions/all-envelopes.json`
- `landscape-report.html` (regenerated)
- `_multi-ai-critique/p0-fixes/*` (this evidence)

## file:// PASS

- Director card ≠ Superpowers ✓
- cc10x card ≠ methodology leak ✓
- No `AI-DLC (IBM)` in HTML ✓
- Claude Harness unverified / unlinked ✓
- Zuvo QUARANTINED; not in plugins mq/wave ✓
- MQ tables cite `mq_data` ✓
- Matrix panel present ✓
- Report opened via `open` ✓
