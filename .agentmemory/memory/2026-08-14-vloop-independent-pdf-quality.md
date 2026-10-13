---
type: decision
timestamp: 2026-08-14T00:59:00+10:00
summary: Independent hostile V-loop of landscape-report.pdf vs SPA Roboto Condensed — PASS all four gates; no regen.
artifacts:
  - research/2026-07-20-agentic-sdlc-orchestration-landscape-multimarket-final/_fix-pdf-button/quality-pass/vloop/VLOOP.md
  - research/2026-07-20-agentic-sdlc-orchestration-landscape-multimarket-final/_fix-pdf-button/quality-pass/vloop/PROOF.json
---

Independent PDF quality V-loop (did not trust prior QUALITY-PASS). SPA template + live HTML CSS + Chart.js defaults = Roboto Condensed (Google 300/400/500), not Inter. pdffonts = RobotoCondensed Light/Regular/Medium; no Times/Palatino/Inter. 74/74 SVG data-x/data-y match chart-data.json; Wave x=strategy y=offering. pdftotext leftover markdown = 0. Visual rasters: not Times, not clipped, tables OK. No landscape_independent_pdf.py change, no PDF regen, no commit.
