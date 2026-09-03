# Analyst-grade review — multimarket landscape SPA

`run_id=run-57f38dfa25d83cc50d224e283d4692f3` (SCRs/waves reused; no new DR)

Report: [`landscape-report.html`](../landscape-report.html)

## file:// verify: **PASS**

- URL: `file:///Users/shafqat/.cursor/worktrees/repo/3ht3/research/2026-07-20-agentic-sdlc-orchestration-landscape-multimarket-final/landscape-report.html`
- Screenshots: ['AFTER-1280.png', 'AFTER-375.png', 'AFTER-dark-1280.png']
- Checks: `{"hasContent": true, "markedPinned": true, "noAgentsysAi": true, "hasAgentSysGithub": true, "noAwsAiDlc": true, "noDeepworkAi": true, "hasMetaGPT": true, "hasClaudeHarness": true, "noHarnessApoCandidate": true, "saasSectionMentionsFactory": true, "underlines": 0, "overflow375": 0, "noCursorInSaasMq": true, "metaGptInApoMq": true, "harnessInPluginsOss": true, "noClaudeCodeExpertInRankings": true, "pageErrors": 0}`

## Membership audit table (material solutions)

| Solution | Slug | Markets (correct) | License bucket | MQ? | Notes / action |
|---|---|---|---|---|---|
| AgentHub | `agenthub` | apo:core | commercial | yes | pack core_seed |
| AgentSys | `agentsys` | apo:core | oss | yes | pack core_seed |
| AI-DLC | `ai-dlc` | apo:core | oss | yes | pack core_seed |
| ATeam | `ateam` | apo:core | commercial | yes | pack core_seed |
| Barkain Workflow Orchestrator | `barkain-workflow-orchestrator` | apo:core | commercial | yes | pack core_seed |
| Cavekit v3.1 | `cavekit-v31` | apo:core | commercial | yes | pack core_seed |
| cc10x | `cc10x` | apo:core | commercial | yes | pack core_seed |
| Deepwork | `deepwork` | apo:core | commercial | yes | pack core_seed |
| Director | `director` | apo:core | oss | yes | pack core_seed |
| MetaGPT | `metagpt` | apo:core | oss | yes | pack core_seed |
| Silver Bullet | `silver-bullet` | apo:core | oss | yes | pack core_seed |
| Turboshovel | `turboshovel` | apo:core | commercial | yes | pack core_seed |
| Workflow Manager | `workflow-manager` | apo:core | commercial | yes | pack core_seed |
| BMAD-METHOD | `bmad` | sdlc-plugins:core | oss | yes | sdlc-plugins market_core (matrix) |
| Claude Harness | `claude-harness` | sdlc-plugins:core | oss | yes | sdlc-plugins market_core (matrix) |
| GSD (Get Shit Done) | `gsd` | sdlc-plugins:core | oss | yes | sdlc-plugins market_core (matrix) |
| Oh My Pi (OMP) | `oh-my-pi` | sdlc-plugins:core | oss | yes | sdlc-plugins market_core (matrix) |
| Ruflo / Claude Flow | `ruflo` | sdlc-plugins:core | oss | yes | sdlc-plugins market_core (matrix) |
| GitHub Spec Kit | `spec-kit` | sdlc-plugins:core | oss | yes | sdlc-plugins market_core (matrix) |
| SuperClaude | `superclaude` | sdlc-plugins:core | oss | yes | sdlc-plugins market_core (matrix) |
| Superpowers | `superpowers` | sdlc-plugins:core | oss | yes | sdlc-plugins market_core (matrix) |
| Zuvo | `zuvo` | sdlc-plugins:core | oss | yes | sdlc-plugins market_core (matrix) |
| Augment Cosmos | `augment-cosmos` | agentic-sdlc-saas:core | commercial | yes | agentic-sdlc-saas market_core (matrix) |
| Devin | `devin` | agentic-sdlc-saas:core | commercial | yes | agentic-sdlc-saas market_core (matrix) |
| Factory.ai | `factory-ai` | agentic-sdlc-saas:core | commercial | yes | agentic-sdlc-saas market_core (matrix) |
| Magic.dev | `magic-dev` | agentic-sdlc-saas:core | commercial | yes | agentic-sdlc-saas market_core (matrix) |
| Tembo | `tembo` | agentic-sdlc-saas:core | commercial | yes | agentic-sdlc-saas market_core (matrix) |
| Axonflow | `axonflow` | apo:adjacent | adjacent | no | pack adjacent_seed |
| Cavekit V4 | `cavekit-v4` | apo:adjacent | adjacent | no | pack adjacent_seed |
| Claude Code | `claude-code` | agentic-sdlc-saas:adjacent | adjacent | no | pack adjacent_seed |
| Codex | `codex` | agentic-sdlc-saas:adjacent | adjacent | no | pack adjacent_seed |
| Cognition Scout | `cognition-scout` | agentic-sdlc-saas:adjacent | adjacent | no | pack adjacent_seed |
| Conductor | `conductor` | agentic-sdlc-saas:adjacent | adjacent | no | pack adjacent_seed |
| Crewai | `crewai` | apo:adjacent, sdlc-plugins:adjacent | adjacent | no | pack adjacent_seed |
| Cursor | `cursor` | agentic-sdlc-saas:adjacent | adjacent | no | pack adjacent_seed |
| Github Copilot | `github-copilot` | agentic-sdlc-saas:adjacent | adjacent | no | pack adjacent_seed |
| Langchain | `langchain` | apo:adjacent | adjacent | no | pack adjacent_seed |
| Langgraph | `langgraph` | apo:adjacent, sdlc-plugins:adjacent | adjacent | no | pack adjacent_seed |
| Replit Agent | `replit-agent` | agentic-sdlc-saas:adjacent | adjacent | no | pack adjacent_seed |
| Claude Code Expert | `claude-code-expert` | — | excluded | no | pack hard_exclusion (sunset) |
| Aider | `aider` | — | excluded | no | pack hard_exclusion (coding_agent) |
| Amazon Q Developer | `amazon-q-developer` | — | excluded | no | hard_veto from need_profile |
| Cline | `cline` | — | excluded | no | pack hard_exclusion (coding_agent) |
| Coderabbit | `coderabbit` | — | excluded | no | hard_veto from need_profile |
| Continue | `continue` | — | excluded | no | pack hard_exclusion (coding_agent) |
| Cursor Background Agents | `cursor-background-agents` | — | excluded | no | hard_veto from need_profile |
| Github Copilot Enterprise | `github-copilot-enterprise` | — | excluded | no | pack hard_exclusion (coding_agent) |

## Findings P0–P3 (fixed)

| id | sev | finding | fix |
|---|---|---|---|
| P0-1 | P0 | Host runtimes (Cursor/Claude Code/Codex/Copilot) scored as **agentic-sdlc-saas core MQ Leaders** — SCR/pack `host_runtime` says adjacent-only, never Top-N/MQ/Wave | Moved to SaaS `adjacent_seeds`; SaaS core = Factory/Devin/Augment Cosmos/Tembo/Magic.dev only |
| P0-2 | P0 | Cognition Scout treated as SaaS core peer | Moved to SaaS adjacent (`host_runtime`) |
| P0-3 | P0 | MetaGPT in APO OSS cards but **missing from APO MQ/GMQ** (top-12 cut + absent rankings) | `build_chart_data` now injects all `market_slugs` into chart points |
| P0-4 | P0 | `agentsys.ai` still embedded in envelope sources | `rewrite_vendor_url` + `scrub_embedded_vendor_urls` → `github.com/agent-sh/agentsys` |
| P1-1 | P1 | Claude Harness framed as commercial APO candidate in plugins section | License → OSS; `scrub_membership_framing` rewrites primary-market APO candidate copy |
| P1-2 | P1 | `magic-dev` simultaneously hard-excluded and SaaS core seed | Removed from `hard_exclusions`; kept SaaS core |
| P1-3 | P1 | AI-DLC / AgentSys / Director labeled commercial despite GitHub/OSS surfaces | Licenses → OSS in pack |
| P1-4 | P1 | Claude Code Expert + sdlc-plugin still matrix columns | `filter_comparison_for_pack` drops hard-exclusions/aliases; matrix restricted to audit `matrix_slugs` |
| P1-5 | P1 | Dead pack homepages: Director, Oh My Pi, SuperClaude (404) | SuperClaude → `SuperClaude_Framework`; Director/OMP unlinked |
| P2-1 | P2 | TREND_SEEDS listed MetaGPT as generic-framework adjacent | Prose updated — MetaGPT is APO OSS core |
| P2-2 | P2 | Envelope claims still marketed Claude Code Expert as APO | Scrub drops invented source rows / rewrites APO-candidate claims |
| P3-1 | P3 | Buying guidance called Devin a host-runtime adjacent | Updated to SaaS-core vs host-runtime adjacent wording |

## Files changed

- `skills/silver-deep-research/reference/landscape/category-packs/agentic-sdlc-process-orchestrator.json`
- `skills/silver-deep-research-multi-ai/scripts/synthesize_landscape.py`
- `skills/silver-deep-research-multi-ai/scripts/vendor_link_labels.py`
- `skills/silver-deep-research-multi-ai/scripts/landscape_preview_render.py`
- `skills/silver-deep-research-multi-ai/tests/test_multi_market_landscape.py`
- mirrors under `plugins/silver-bullet/skill-source/...`
- regenerated: `landscape/landscape-report.md`, `landscape/chart-data.json`, `landscape/catalog_audit.json`, `landscape-report.html`

## Remaining judgment calls

1. **Deepwork / Workflow Manager / Turboshovel / Barkain / Cavekit / AgentHub / ATeam / cc10x** remain APO seeds despite thin SCR evidence — keep as research-seeded APO cores until a new DR pass; several stay unlinked (no verified URL).
2. **Claude Harness homepage** still points at `github.com/anthropics/claude-code` (host repo) — no distinct harness homepage found; leave linked to host docs/repo rather than invent a product URL.
3. **Magic.dev as SaaS core vs adjacent** — kept as autonomous-SWE SaaS core (Visionaries); could argue adjacent if you want Factory/Devin/Cosmos/Tembo-only cores.
4. **MetaGPT MQ = Niche Players** — expected with score 0 / thin feature support until a dedicated MetaGPT SCR exists (solutions/metagpt/ missing).
5. **Critical matrix fill gaps** (Self-serve signup / Managed hosting 0%) unchanged — research evidence missing, not a categorization bug.

## Regen commands

```bash
SB_SKIP_VENDOR_URL_HEALTH=1 python3 skills/silver-deep-research-multi-ai/scripts/synthesize_landscape.py \
  --dir research/2026-07-20-agentic-sdlc-orchestration-landscape-multimarket-final --force
python3 skills/silver-deep-research-multi-ai/scripts/generate_landscape_report.py \
  --dir research/2026-07-20-agentic-sdlc-orchestration-landscape-multimarket-final
```

