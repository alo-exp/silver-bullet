# Independent V-loop recheck — analyst-grade overhaul claims

ts: 2026-07-21T10:53:00Z (after Harness scrub fix + regen)
file: file:///Users/shafqat/.cursor/worktrees/repo/3ht3/research/2026-07-20-agentic-sdlc-orchestration-landscape-multimarket-final/landscape-report.html
overall: **PASS**

Fresh Playwright DOM/chart checks — prior PASS not trusted. First pass found a **hard** Harness prose miscategorization; fixed at source + regen; re-verified PASS.

## Must PASS/FAIL

| # | Claim | Result | Detail |
|---|---|---|---|
| 1 | SaaS core MQ/Leaders exclude Cursor/Claude Code/Codex/Copilot (adjacent only) | **PASS** | Absent from SaaS MQ + leaders; listed under Adjacent Markets |
| 2 | SaaS core MQ includes Factory / Devin / Augment Cosmos / Tembo / Magic.dev | **PASS** | SaaS MQ: Augment Cosmos, Devin, Factory.ai, Tembo, Magic.dev |
| 3 | Cognition Scout is SaaS adjacent, not core | **PASS** | Not in SaaS MQ/core; Adjacent Markets `cognition-scout` |
| 4 | Conductor is not APO; SaaS-adjacent aggregator framing | **PASS** | Not in APO/SaaS MQ; prose: SaaS-adjacent coding-agent aggregator |
| 5 | Claude Harness in sdlc-plugins OSS, not APO | **PASS** | plugins OSS + MQ Visionaries; profile Overview scrubbed to SDLC-plugins pack (not APO peer) |
| 6 | MetaGPT in APO OSS / on APO MQ | **PASS** | APO OSS + MQ Niche Players |
| 7 | No Claude Code Expert product cards | **PASS** | 0 cards/rankings/titles; only Excluded list + research JSON |
| 8 | AgentSys → github.com/agent-sh/agentsys; no aws.amazon.com/ai-dlc/ | **PASS** | github×23; agentsys.ai=0; aws ai-dlc=0 |
| 9 | No hyperlink underlines; target=_blank+noopener on externals | **PASS** | 286 externals; underlines=0; badRel=0 |
| 10 | file:// renders (no Marked crash); overflow@375 ≈ 0 | **PASS** | contentLen≈16k; pageErrors=0; overflow375=0 |

## Spot-checks (FINDINGS membership) — 22 vendors

| Slug | Expected | APO | Plugins | SaaS | Rank | OK | Note |
|---|---|---|---|---|---|---|---|
| agenthub | apo:core | true | false | false | true | PASS |  |
| agentsys | apo:core | true | false | false | true | PASS |  |
| ai-dlc | apo:core | true | false | false | true | PASS |  |
| ateam | apo:core | true | false | false | true | PASS |  |
| metagpt | apo:core | true | false | false | false | PASS | on APO MQ; thin rankings OK |
| silver-bullet | apo:core | true | false | false | true | PASS |  |
| bmad | sdlc-plugins:core | false | true | false | true | PASS |  |
| claude-harness | sdlc-plugins:core | false | true | false | true | PASS |  |
| gsd | sdlc-plugins:core | false | true | false | true | PASS |  |
| factory-ai | agentic-sdlc-saas:core | false | false | true | true | PASS |  |
| devin | agentic-sdlc-saas:core | false | false | true | true | PASS |  |
| augment-cosmos | agentic-sdlc-saas:core | false | false | true | true | PASS |  |
| tembo | agentic-sdlc-saas:core | false | false | true | true | PASS |  |
| magic-dev | agentic-sdlc-saas:core | false | false | true | true | PASS |  |
| conductor | agentic-sdlc-saas:adjacent | false | false | false | false | PASS | adjacent-only |
| cursor | agentic-sdlc-saas:adjacent | false | false | false | false | PASS | adjacent-only |
| claude-code | agentic-sdlc-saas:adjacent | false | false | false | false | PASS | adjacent-only |
| codex | agentic-sdlc-saas:adjacent | false | false | false | false | PASS | adjacent-only |
| cognition-scout | agentic-sdlc-saas:adjacent | false | false | false | false | PASS | adjacent-only |
| axonflow | apo:adjacent | false | false | false | false | PASS | adjacent-only |
| crewai | apo:adjacent | false | false | false | false | PASS | adjacent-only |
| langchain | apo:adjacent | false | false | false | false | PASS | adjacent-only |

## Defects / fixes

| id | sev | finding | fix |
|---|---|---|---|
| VLOOP-H1 | **hard** | Claude Harness solution profile Overview still said “primary-market APO candidate” — `scrub_membership_framing` only matched bare `Name is a…`, not `[Name](url) is a…` | Extended scrub to markdown-linked names; unit test added; `synthesize_landscape.py --force` + `generate_landscape_report.py` regen |
| VLOOP-S1 | soft | Prior verify only checked visible `#content` innerText — missed `display:none`/off-viewport profile blocks | Vloop now walks `h3#h-*` profile siblings for Harness APO framing |

No other hard wrong-segment bugs in the 22-vendor spot check.

## Evidence files

- [`RESULT.json`](RESULT.json), [`membership.json`](membership.json), [`REPORT.md`](REPORT.md)
- [`vloop-1280.png`](vloop-1280.png), [`vloop-375.png`](vloop-375.png)
- [`vloop-verify.mjs`](vloop-verify.mjs), [`vloop-run-after-fix.log`](vloop-run-after-fix.log)
- [`synthesize-fix.log`](synthesize-fix.log), [`generate-fix.log`](generate-fix.log)
- Source: `skills/silver-deep-research-multi-ai/scripts/synthesize_landscape.py` (`scrub_membership_framing`)
- Test: `skills/silver-deep-research-multi-ai/tests/test_multi_market_landscape.py` (`test_scrub_claude_harness_apo_framing_markdown_link`)
