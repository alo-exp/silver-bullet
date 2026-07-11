# Agent Comparison — Canonical SDLC Process Architecture Study

**Research date:** 2026-07-12  
**Dispatch:** Parallel `opencode run --model opencode-go/<model> --auto` (primary invocation; ocg-* subagent config at `~/.config/opencode/opencode.jsonc`)

| Agent | Model | Status | Report size | Lines | Sources | Notable characteristics |
|-------|-------|--------|------------:|------:|--------:|-------------------------|
| [ocg-minimax-m3](../ocg-minimax-m3/research_report.md) | `opencode-go/minimax-m3` | **COMPLETE** | 116 KB | 1,938 | 80 | Deepest workflow library (~110 workflows); explicit 4-layer grouping (Direction/Delivery/Feedback/Sustainability); strongest standards cross-walk (NIST SSDF, OWASP SAMM, SLSA) |
| [ocg-kimi-k2.7-code](../ocg-kimi-k2.7-code/research_report.md) | `opencode-go/kimi-k2.7-code` | **COMPLETE** | 123 KB | 1,641 | 121 | Largest source registry; used 4 parallel subagents for area clusters; richest evidence ledger (155 spans) |
| [ocg-deepseek-v4-flash](../ocg-deepseek-v4-flash/research_report.md) | `opencode-go/deepseek-v4-flash` | **COMPLETE** | 62 KB | 758 | 25 | Strongest quantitative AI framing (DORA 2025 stability tradeoff); concise PA tables; fastest complete run (~7 min) |
| [ocg-mimo-v2.5](../ocg-mimo-v2.5/research_report.md) | `opencode-go/mimo-v2.5` | **COMPLETE** | 52 KB | 1,132 | 44 | Balanced mid-length synthesis; clear practice classification percentages; good company-blog coverage |
| [ocg-qwen3.7-plus](../ocg-qwen3.7-plus/) | `opencode-go/qwen3.7-plus` | **PARTIAL** | 591 B | — | 32 | Stopped after scope/plan/source gathering; no substantive `research_report.md` |

## Consensus (4/4 complete agents)

All four complete runs independently converged on:

1. **18 Process Areas** — identical taxonomy to the research brief; capability-based (not waterfall stages).
2. **Universal core** — trunk-based development, continuous integration, automated testing pyramid, mandatory code review, CI/CD with progressive delivery, SRE (SLOs/error budgets), observability (OpenTelemetry), shift-left security (NIST SSDF / OWASP / supply chain).
3. **Leading-edge mainstream** — platform engineering + Internal Developer Portals (Backstage pattern), Team Topologies, DevEx measurement, golden paths.
4. **AI as amplifier** — DORA and vendor studies cited; individual productivity gains with organizational stability risks if fundamentals (small batches, test automation, review discipline) are weak.
5. **Three maturity tiers** — Minimum / Standard / Leading-edge implementation per workflow.
6. **Deprecated practices** — annual release trains, long-lived feature branches as default, manual QA hand-off gates, big-bang migrations, story-points-as-performance-metric.

## Divergences

| Topic | minimax-m3 | kimi-k2.7 | deepseek-v4-flash | mimo-v2.5 |
|-------|------------|-----------|-------------------|-----------|
| Workflow count | ~110 named workflows | ~90+ with metadata standard | Summary tables per PA | ~80 with tier tags |
| Source depth | 80 sources, heavy standards | 121 sources, 4 subagents | 25 sources, DORA-weighted | 44 sources, survey-heavy |
| AI stability risk | Qualitative + GitHub study | NIST AI RMF + Anthropic | **7.2% stability ↓ per 25% AI adoption** (DORA 2025) | 90%+ adoption, verification tax |
| Org model | Team Topologies + Backstage | ITIL/COBIT compatibility noted | Platform engineering normative | Spotify squad cited as historical only |
| Evidence gaps flagged | PA-17 maintenance, PA-18 governance | Public-source / geographic bias | Chinese tech missing | Regulated-industry underrepresented |

## Recommended primary references for adoption

| Use case | Primary agent report |
|----------|---------------------|
| Full workflow library + standards mapping | **ocg-minimax-m3** |
| Broadest source bibliography + subagent area depth | **ocg-kimi-k2.7-code** |
| Executive briefing + AI quantitative risks | **ocg-deepseek-v4-flash** |
| Balanced mid-length handbook | **ocg-mimo-v2.5** |

## Blockers

- **ocg-qwen3.7-plus:** Run exited early (591-byte stdout placeholder). Scope, research-plan, and 32-source `sources.jsonl` exist but synthesis never completed. No retry attempted in this pass.
