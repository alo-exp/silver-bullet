# Session intent audit matrix

run_id=`run-57f38dfa25d83cc50d224e283d4692f3` (not re-derived)

file:// verify: **PASS** — [playwright-verify.json](playwright-verify.json)

| ID | User ask | Report | Code | Fix applied |
|----|----------|--------|------|-------------|
| 1 | Card titles homepage hyperlinks | PASS | PASS | engine template already; regen |
| 2 | Links target=_blank + noopener | PASS | PASS | engine template |
| 3 | No underline on hyperlinks | PASS | PASS | engine template |
| 4 | Body font-weight ~300 | PASS | PASS | engine template |
| 5 | marked@11.1.1 pinned | PASS | PASS | engine template |
| 6 | file:// SPA no server | PASS | PASS | regen verified |
| 7 | Dark-theme link contrast | PASS | PASS | playwright dark color ok |
| 8 | AgentSys github.com/agent-sh/agentsys | PASS | PASS | vendor_link_labels + pack |
| 9 | 404 health check; no aws.ai-dlc | PASS | PASS | filter_healthy_vendor_urls |
| 10 | AI-DLC awslabs; not IBM | PASS | PASS | pack homepage + scrub |
| 11 | No product Claude Code Expert | PASS | PASS | hard_exclusion; exclusion ledger may name it |
| 12 | Deepwork wrong URL unlinked | PASS | PASS | health unlink |
| 13 | Workflow Manager research URL or unlinked | PASS | PASS | unlinked |
| 14 | Claude Harness not anthropics homepage | PASS | PASS | vendor_link_labels block + unverified |
| 15 | SB in APO + sdlc-plugins | PASS | PASS | multi-market pack seeds |
| 16 | Claude Harness ≠ APO core | PASS | PASS | plugins seed |
| 17 | Conductor not APO | PASS | PASS | saas adjacent |
| 18 | MetaGPT APO OSS core | PASS | PASS | pack seed |
| 19 | No identical (x,y) collisions | PASS | PASS | avoid_chart + assert; regenerated |
| 20 | Chart plotted ⊆ listed | PASS | PASS | membership invariants |
| 21 | Unique multi-market card ids | PASS | PASS | SPA template |
| 22 | Wave Strength of Strategy differentiated | PASS | PASS | engine |
| 23 | Realistic scoring; _CHART_FEAT_EQUIV empty | PASS | PASS | engine |
| 24 | SB high placement not fake Execute ceiling | PASS | PASS | kept |
| 25 | Notable divergences deduped | PASS | PASS | test covers |
| 26 | Matrix no phantom CCE column | PASS | PASS | filter_comparison |
| 27 | Director≠Superpowers; cc10x≠methodology leak | PASS | PASS | SCR + is_unusable_overview_claim guard |
| 28 | Zuvo quarantined not fake Leader | PASS | PASS | pack adjacent+quarantine (durable) |
| 29 | Tembo not SaaS core plotted | PASS | PASS | pack demotion to adjacent |
| 30 | Plugins MQ not all y=9.5 Leaders | PASS | PASS | sdlc-plugins axis profile fix |
| 31 | Inclusion ledger; Blue Ocean; IBM scrub | PASS | PASS | regen |
| 32 | ocg_lite_pool uses ocg-kimi-k2.6 | PASS | PASS | registry already correct |

## Skills / engine files changed

- `skills/silver-deep-research/reference/landscape/category-packs/agentic-sdlc-process-orchestrator.json` — Zuvo quarantine → adjacent; Tembo demoted → SaaS adjacent

- `skills/silver-deep-research-multi-ai/scripts/solution_classifier.py` — quarantine/demotion adjacent reasons

- `skills/silver-deep-research-multi-ai/scripts/synthesize_landscape.py` — collision assert; quarantine unplotted reasons; sdlc-plugins MQ Y axes (no all-Leaders y=9.5)

- `skills/silver-deep-research-multi-ai/scripts/materialize_solution_artifacts.py` — Director/Superpowers + cc10x methodology overview leak guard

- `skills/silver-deep-research-multi-ai/tests/test_multi_market_landscape.py` — Zuvo/Tembo/plugins Y tests

- `skills/silver-deep-research-multi-ai/tests/test_materialize_solution_artifacts.py` — overview leak unit tests

## Report artifacts regenerated

- `research/.../landscape/chart-data.json`

- `research/.../landscape/landscape-report.md`

- `research/.../landscape-report.html`

- mirrors: `bash scripts/sync-codex-package.sh`

## Screenshots

- [spa-light-1280.png](spa-light-1280.png)

- [spa-dark-1280.png](spa-dark-1280.png)

## Remaining genuine gaps

- Claude Code Expert still named in **exclusion ledger** prose (by design as hard_exclusion). Not a product card/matrix column.

- Zuvo remains must_research adjacent/watchlist until a primary repo+license DR pass verifies identity (new DR required to lift quarantine).

- SaaS MQ still clusters near high Completeness (x≈9.5) with distinct Y — acceptable under no-identical-(x,y) rule; further Completeness spread would need feature-axis redesign (optional).
