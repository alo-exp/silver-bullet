# P1 membership — independent V-loop

Workspace: `research/2026-07-20-agentic-sdlc-orchestration-landscape-multimarket-final`  
No commit. Did not trust prior PASS.

## Independent first pass (FAIL)

Prior `AFTER-membership.json` / MQ / §1 prose were already correct. Per-market `plotted_slugs` were not:

| Market | Defect |
|--------|--------|
| `apo.plotted_slugs` | still listed `agenthub`, `ateam`, `cc10x`, `cavekit-v31`, `barkain-workflow-orchestrator` |
| `sdlc-plugins.plotted_slugs` | missing the three plugin-class vendors that **are** in `membership.core` + `mq_data` |

`apply-chart-membership.mjs` had updated **top-level** `plotted_slugs` only. HTML JS plots `mq_data`, but `#report-data` still advertised stale core-plotted lists.

## Fix

- Synthesize: `build_multi_market_chart_data` now locksteps per-market `plotted_slugs` to MQ slugs and `listed_slugs`/`unplotted` to membership.
- Tests: `test_p1_pack_membership_named_vendors`, `test_plotted_slugs_lockstep_membership_core_and_mq`.
- Artifact: `vloop/sync-plotted-slugs.mjs` then `generate_spa_report.py --profile landscape`.

## Re-verify (PASS)

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | Devin is SaaS core plotted; §1 does NOT call Devin adjacent-only host | **PASS** | SaaS core+MQ+plotted. §1: Devin is agentic-sdlc-saas core, not adjacent-only host. Playwright `s1HasDevinCore=true`. |
| 2 | AgentHub NOT in APO MQ Leaders/core plotted | **PASS** | Not in apo `mq_data` / Leaders / `membership.core` / `plotted_slugs` / HTML. APO adjacent (CRM). |
| 3 | A.Team/ATeam NOT in APO core plotted | **PASS** | Not in apo MQ/core/plotted. Pack `hard_exclusions`. Body: FDE excluded. |
| 4 | cc10x, Cavekit, Barkain in sdlc-plugins (not APO commercial core) | **PASS** | Plugins core+MQ+plotted (13). Absent from APO core/MQ/plotted/commercial buckets. |
| 5 | Value-curve Managed hosting for OSS is not 3 if matrix empty (expect 1) | **PASS** | All OSS VC series hosting=1. APO `vc_commercial` empty. SaaS hosting remains 5. |
| 6 | HTML `#report-data` still locksteps with landscape-report.md | **PASS** | `rd.markdown === landscape/landscape-report.md` (59268 bytes). |
| 7 | file:// renders | **PASS** | Playwright: 12 canvases, 0 page/console errors, `renderFailed=false`. [fileurl-1280.png](fileurl-1280.png). |

Overall: **PASS** after plotted_slugs lockstep + re-render.

## Artifacts

- [vloop-result.json](vloop-result.json)
- [playwright-fileurl.json](playwright-fileurl.json)
- [sync-plotted-slugs-report.json](sync-plotted-slugs-report.json)
- HTML: `landscape-report.html` via `render_landscape_outputs` (`pdf_bytes` 959207)
