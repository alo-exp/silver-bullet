# Adversarial audit findings — multimarket landscape SPA

`run_id=run-57f38dfa25d83cc50d224e283d4692f3`  
Artifact: `research/2026-07-20-agentic-sdlc-orchestration-landscape-multimarket-final/landscape-report.html`

## Findings table

| id | severity | description | evidence | fix applied |
|----|----------|-------------|----------|-------------|
| F1 | P0 | Unpinned Marked CDN / `parseInline` crash | Prior `_vloop-verify/dom-evidence-BEFORE-pin-FAIL.json`; current pin `marked@11.1.1` | Already fixed; contract test `test_marked_cdn_pinned_to_11_1_1` |
| F2 | P0 | False vendor homepage: **SDLC Plugin → https://claude.com/plugins** (marketplace shared with Claude Code Expert) | Live DOM + pack `homepage_by_slug`; SCR has no URL | Removed pack homepage; `drop_ambiguous_shared_homepage_urls`; `scrub_vendor_markdown_links`; enrich re-filters cache merges |
| F3 | P1 | Leaders filter included MQ Visionaries (GMQ∪MQ) | Cavekit/Conductor/etc. in `vendor_buckets.leaders` while MQ `q=Visionaries` | `build_vendor_buckets` MQ overwrites GMQ; per-market buckets rebuilt in enrich |
| F4 | P1 | Critical matrix rows Self-serve signup & Managed hosting at **0% fill** rendered without callout (risk of silent gap) | Comparison rows 0/34; cells already `—` | `annotateCriticalFillGaps()` banner in SPA |
| F5 | P1 | Broken Roboto Condensed weight 500 (fontsource 5.0.8 CSS+woff2 **404**) | Playwright `failed404` | Removed `@font-face` + 500.css; Google Fonts 400+500 |
| F6 | P2 | Challengers filter always empty (no Challengers in any market MQ) | Live filter count 0 | Disable Challengers button when `CHALLENGER_LABELS` empty |
| F7 | P2 | Chart-data cache re-injected stale false URLs on regen | `_enrich_chart_data` merged `existing_pairs` without re-filter | `filter_vendor_link_pairs` after merge; persist cleaned `chart-data.json` |
| F8 | P3 | Template mirrors drifted from `skills/` | Hash mismatch pre-fix | Copied template/scripts/tests/pack to host-bundles, plugins, agents mirrors |
| F9 | — | Card title `target=_blank` + `rel=noopener` | 390 HTTP links, 0 missing blank/rel | Already good (prior vloop) |
| F10 | — | Dark theme link contrast | AgentHub link 9.51:1 on `#0f172a` | No change needed |
| F11 | — | Multi-market structure APO / sdlc-plugins / agentic-sdlc-saas | Sections 3.1/3.2/3.3 present | OK |

## Post-fix verification

**PASS** (`audit-AFTER.json` `"pass": true`)

Screenshots:
- [`AFTER-1280.png`](AFTER-1280.png)
- [`AFTER-dark-1280.png`](AFTER-dark-1280.png)
- [`AFTER-375.png`](AFTER-375.png)

DOM: no page errors; marked pinned; SDLC Plugin link count 0; fill-gap banner present; Challengers disabled; overflow@375 = 0.

## Remaining known gaps (intentionally not fixed — need new DR)

- Critical criteria **Self-serve signup** and **Managed hosting** remain 0/34 filled (research evidence missing).
- ~26–29% fill on Quick onboarding / Prebuilt SDLC templates / Zero-infra bootstrap.
- No Challengers quadrant members in synthesized MQ data (data, not UI).
- MQ vs GMQ quadrant disagreements remain in chart points (filters now MQ-authoritative; charts still show both).
- `sdlc-plugin` SCR content still describes Zuvo (research labeling debt) — display name kept; homepage withheld rather than inventing.

## Files changed

### Source of truth
- `skills/silver-deep-research/reference/landscape/category-packs/agentic-sdlc-process-orchestrator.json`
- `skills/silver-deep-research-multi-ai/scripts/vendor_link_labels.py`
- `skills/silver-deep-research-multi-ai/scripts/synthesize_landscape.py`
- `skills/silver-deep-research-multi-ai/scripts/landscape_preview_render.py`
- `skills/silver-deep-research-multi-ai/assets/landscape-preview.template.html`
- `skills/silver-deep-research-multi-ai/tests/test_vendor_link_and_buckets.py`

### Mirrors synced
- `host-bundles/codex/...`, `plugins/silver-bullet/skill-source/...`, `agents/claude/silver:deep-research(-multi-ai)/...`

### Regenerated artifact
- `research/2026-07-20-agentic-sdlc-orchestration-landscape-multimarket-final/landscape-report.html`
- `.../landscape/chart-data.json` (cleaned)
- `.../landscape/landscape-report.md` (scrubbed stale links)
