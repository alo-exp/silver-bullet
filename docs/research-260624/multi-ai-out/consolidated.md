# Can Subagents Launch Their Own Subagents? — Multi-Model Deep Research

**Date:** 2026-07-13
**OCG profile:** ocg-lite (5 models): minimax-m3, qwen3.7-plus, deepseek-v4-flash, kimi-k2.7-code, mimo-v2.5
**External references:**
- Round 1: 7-model consolidated report (Gemini, Claude, ChatGPT, Copilot, Perplexity, Grok, DeepSeek) — [gemini.google](https://gemini.google.com/app/fbf9ea685079b74d)
- Round 2: 6-model Pi-extension deep-dive (Claude, ChatGPT, Copilot, Perplexity, Grok, DeepSeek; Gemini still generating) — [perplexity](https://www.perplexity.ai/search/ea16f243-0a52-4dd7-accc-18341023967f)

---

## Executive Summary

**Yes — in most modern agent environments, a subagent can launch its own subagent, but with significant differences in how the capability is exposed and constrained.**

Key updates vs. prior report (original OCG-only findings updated with 7-model external reference):

| Environment | Verdict | Key Detail |
|-------------|---------|------------|
| **Claude Code** | ✅ Yes — **hard 5-level cap** (since v2.1.172, June 10, 2026) | `Agent` tool in subagent frontmatter; depth-5 agent receives no `Agent` tool |
| **Cursor** | ✅ Yes — **recursive by design** (majority view); no hard depth cap | `/multitask` (v3.2, Apr 2026); ~8 parallel agents; context isolation per subagent |
| **Codex (OpenAI)** | ✅ Yes — configurable via `config.toml` | `max_depth=1` default; `max_threads=6` concurrency cap; CLI-only |
| **OpenCode** | ⚠️ Config-dependent — **unsafe by default** (documented 18-level recursion) | No architectural depth limit; `permission.task` can silently unlock infinite nesting |
| **Pi** | ✅ Yes via extension (best for recursion: **`nicobailon/pi-subagents`**; `@tintinweb/pi-subagents` is conservative about recursion) | `maxSubagentDepth` (nicobailon) / `--subagent-max-depth` (tintinweb); Pi core has no subagents by design |

---

## Cross-Model Findings

### Finding 1: Claude Code — Hard 5-level cap since June 10, 2026 (v2.1.172)

| Model | Finding | Confidence | Source |
|-------|---------|------------|--------|
| minimax-m3 | Yes — `Agent` in `tools` allows recursive spawn; `permissions.deny` per subagent | high | [s2] |
| qwen3.7-plus | Yes — include `Agent` in subagent's tools frontmatter | high | [s2] |
| deepseek-v4-flash | **No — flat hierarchy (lead → workers)** | medium | — |
| kimi-k2.7-code | Yes — subagent with `Agent` in tools can spawn nested subagents | high | [s2] |
| mimo-v2.5 | Yes — explicitly documented; `Agent` tool in subagent definition | high | [s2] |
| **7-model external** | **Yes — up to 5 levels deep; 5-level cap is fixed, not configurable** | high | [s16] |

**Consensus across both sources:** 4/5 OCG + 5/7 external agree.

**Key updates from 7-model report:**
- **Before June 10, 2026:** Subagents **could not** spawn other subagents (hard rule)
- **v2.1.172 (June 10, 2026):** Nesting enabled up to **5 levels deep**; depth-5 agent receives no `Agent` tool
- **Tiered model routing:** Opus → Sonnet → Haiku at leaves reduces costs 40–66%
- Recommendation: implement a `PreToolUse` hook to prevent runaway token consumption

**OCG dissenter (deepseek-v4-flash):** Describes "agent teams" (parallel workers, no nesting) rather than the `Agent`-tool spawning pattern. Rejected by majority.

Primary source: https://docs.anthropic.com/en/docs/claude-code/sub-agents

---

### Finding 2: Cursor — Recursive by design (majority view); no hard depth cap

| Model | Finding | Confidence | Source |
|-------|---------|------------|--------|
| minimax-m3 | Yes — **2-level cap**: main → subagent → (no further) | high | [s1] |
| qwen3.7-plus | No evidence found | low | — |
| deepseek-v4-flash | Not documented | medium | — |
| kimi-k2.7-code | Yes — planner agents can spawn sub-planners recursively | high | [s6] |
| mimo-v2.5 | Yes — Background Agents + Task tool; `subagentStart` hooks | high | [s4] |
| **7-model external** | **Yes — recursive by design** (Claude, ChatGPT, Grok); Gemini says flat; Perplexity uncertain | mixed | [s16] |

**Key updates from 7-model report:**
- Cursor v2.4 (January 2026) introduced subagents with isolated context windows
- **Cursor 3.2 (April 24, 2026):** `/multitask` feature spawns async subagents in parallel
- Up to **~8 parallel agents** supported
- Agent definitions: `.cursor/agents/` (project) or `~/.cursor/agents/` (user) as Markdown + YAML frontmatter
- Cursor CLI can spawn subagents headlessly via `cursor-agent` shell commands
- **Notable disagreement:** Gemini says flat orchestration only; Copilot says only via Claude Code integration; Perplexity says "possible depending on config, not reliably guaranteed"

Primary source: https://cursor.com/docs/subagents

---

### Finding 3: Codex (OpenAI) — Configurable via `config.toml`; CLI-only

| Model | Finding | Confidence | Source |
|-------|---------|------------|--------|
| minimax-m3 | Yes — `spawn_agent`, `wait_agent`; feature-gated, no documented depth cap | high | [s5] |
| qwen3.7-plus | Yes (depth-limited) — via `AgentControl` spawn | medium | — |
| deepseek-v4-flash | Uncertain — no evidence found | low | — |
| kimi-k2.7-code | Yes, opt-in — `agents.max_depth` defaults to 1 | high | [s3] |
| mimo-v2.5 | Yes — Agents SDK with `Agent.as_tool()` and handoffs | high | [s8,s15] |
| **7-model external** | **Yes — configurable via `config.toml`: `max_depth=1`, `max_threads=6`** | high | [s16] |

**Key updates from 7-model report:**
- **`config.toml`** controls: `[agents] max_threads = 6` (concurrent cap), `max_depth = 1` (nesting depth)
- Raising `max_depth` risks "repeated fan-out, which increases token usage, latency, and local resource consumption"
- **Multi-agent activity is CLI-only** — web app and IDE plugins do not surface child threads; IDE extension visibility is "coming soon"
- Supports orchestrator → implementer → reviewer → tester hierarchies

Primary sources: https://github.com/openai/codex/issues/27331, https://developers.openai.com/codex/agent-configuration/subagents

---

### Finding 4: OpenCode — Unsafe by default (documented 18-level recursion; no depth limit)

| Model | Finding | Confidence | Source |
|-------|---------|------------|--------|
| minimax-m3 | Yes — `permission.task` glob rules; hidden subagents for internal use | high | [s3] |
| qwen3.7-plus | **No** — only primary agents invoke subagents via Task tool | high | — |
| deepseek-v4-flash | **Yes architecturally** — `permission.task` is agent-agnostic | medium | — |
| kimi-k2.7-code | **No** — subagents use `TaskAgentTools` which omits `agent` tool | high | [s9] |
| mimo-v2.5 | **Partial** — Task tool exists but disabled for subagents by default | high | [s7] |
| **7-model external** | **Yes — but no depth limit; documented 18-layer `explore→explore` recursion** | high | [s16] |

**Key updates from 7-model report:**
- **Critical confirmed issue:** OpenCode has **no architectural depth limit** on subagent recursion
- **Real-world case:** 18 layers of `explore→explore` recursion; only the depth-19 agent did real work
- When `permission.task` is configured globally, every agent receives explicit task permission, overriding the built-in guard
- **Community PR #7756** adds opt-in subagent delegation with configurable budgets and depth limits — not yet merged
- "The safe default has Task tool disabled for subagents; this can be accidentally unlocked by any explicit `permission.task` rule in global config"

**Resolution:** The architecture permits it with explicit config, but **unlike all other environments, there is no hard cap**. This is not a feature — it's a danger.

Primary source: https://opencode.ai/docs/agents/

---

### Finding 5: Pi — Two main extensions; `nicobailon/pi-subagents` is best for recursive nesting

| Model | Finding | Confidence | Source |
|-------|---------|------------|--------|
| minimax-m3 | Yes via `nicobailon/pi-subagents` — 2-level cap, `maxSubagentDepth` | high | [s11] |
| qwen3.7-plus | Yes via `subagent/` extension using `registerTool` + `exec` | medium | — |
| deepseek-v4-flash | **No** — Pi is a worker, not an orchestrator | medium | — |
| kimi-k2.7-code | Yes via `pi-subagents` (`pi install npm:pi-subagents`); `maxSubagentDepth` default 1 | high | [s11] |
| mimo-v2.5 | **No** — consumer conversational AI | medium | — |
| 7-model (Round 1) | **`@tintinweb/pi-subagents`** (full 7/7 consensus) | high | [s16] |
| 6-model deep-dive (Round 2) | **`nicobailon/pi-subagents` is best for recursion** (Claude, ChatGPT, Grok, DeepSeek); `@tintinweb` is conservative about recursion by design | high | [s17] |

**Key insight from the 6-model Pi-extension deep-dive:** The Round 1 consensus (`@tintinweb/pi-subagents`) was **correct that it's the canonical extension but wrong about it being the best for recursive nesting**. The maintainer of `@tintinweb/pi-subagents` previously limited child-agent tool exposure to "avoid deep recursions." It supports some nesting but was not purpose-built for it.

#### Extension Comparison: `nicobailon/pi-subagents` vs `@tintinweb/pi-subagents`

| Dimension | `nicobailon/pi-subagents` | `@tintinweb/pi-subagents` |
|---|---|---|
| **GitHub Stars** | **1,200** | 418 |
| **Forks** | **152** | 85 |
| **Commits** | **231** | 164 |
| **Nested subagent spawning** | **Explicit feature with `maxSubagentDepth`** | Not documented / unguarded |
| **Recursion depth control** | **3-layer: env var / config / frontmatter** | None |
| **Chain orchestration** | **Full chains, fan-out/fan-in, saved `.chain.md` files** | Not supported |
| **Live widget UI** | Compact async widget | **Rich (fleet view, spinners, conversation viewer)** |
| **Scheduled agents** | Not mentioned | **Cron/interval/one-shot** |
| **Claude Code look & feel** | Different API shape | **Same tool names (Agent, get_subagent_result, steer_subagent)** |
| **Cross-extension RPC** | Not mentioned | **Event bus with typed API** |
| **Worktree isolation** | Per parallel step `worktree: true` | Per-agent `isolation: worktree` |
| **Fallback models** | **`fallbackModels` in frontmatter** | Not supported |
| **Diagnostics** | **`/subagents-doctor`** | Not supported |
| **Companion extension** | **`pi-intercom`** for child→parent live messaging | None |

**Other extensions mentioned across sources:**

| Extension | Source | Notes |
|---|---|---|
| `@gotgenes/pi-subagents` | DeepSeek (Round 2) | Modular "Unix-like" philosophy; 900+ tests; preferred for granular control |
| `@kmmuntasir/pi-nested-subagents` | ChatGPT (Round 2) | Experimental fork of tintinweb for deeper nesting; supports up to depth 5 |
| `pi-fork` + `pi-minimal-subagent` | Grok (Round 2) | Community favourite for **context efficiency** in long-running multi-level sessions |
| `mjakl/pi-subagent` | Claude (Round 1) | Lightweight alternative |
| `hcom` | DeepSeek (Round 2) | Cross-tool orchestrator — Pi agents can spawn Claude Code agents and vice versa |

**Recommendations by use case (consensus across all 12 sources):**

| Use Case | Best Extension |
|---|---|
| **Recursive/nested orchestration** (planner → worker → reviewer) | **`nicobailon/pi-subagents`** — explicit `maxSubagentDepth`, chain orchestration, fan-out/fan-in |
| **Claude Code UX parity** (fleet view, mid-run steering) | `@tintinweb/pi-subagents` |
| **Scheduled/cron agents** | `@tintinweb/pi-subagents` |
| **Modular / testable architecture** | `@gotgenes/pi-subagents` |
| **Context-efficient long sessions** | `pi-fork` + `pi-minimal-subagent` |
| **Experimental deep nesting (up to 5 levels)** | `@kmmuntasir/pi-nested-subagents` |
| **Cross-platform orchestration** | `hcom` (orchestrates Pi, Claude Code, and other CLIs) |

Primary sources: https://github.com/nicobailon/pi-subagents, https://github.com/tintinweb/pi-subagents

---

## Consolidated Answer Table

| Environment | Subagent → Sub-subagent? | Mechanism | Depth Limit | Default Behavior |
|-------------|------------------------|-----------|-------------|------------------|
| **Claude Code** | **YES** | `Agent` tool in frontmatter | **5 levels** (hard cap since v2.1.172) | Enabled if `Agent` listed |
| **Cursor** | **YES** | Task tool + `/multitask` + CL| No hard cap; ~8 parallel agents | Enabled since v2.4 |
| **Codex (OpenAI)** | **YES** | `config.toml`: `[agents]` section | `max_depth=1` (default); configurable | **Disabled** by default |
| **OpenCode** | **CONFIG-DEPENDENT** | `permission.task` glob | **No depth limit** (unsafe; 18-level recursion documented) | **Disabled** for subagents; can be silently unlocked |
| **Pi** | **YES VIA EXTENSION** | **`nicobailon/pi-subagents`** (best for recursion; explicit `maxSubagentDepth`); `@tintinweb/pi-subagents` (conservative about recursion; rich UX) | Configurable (nicobailon: 3-layer depth control; tintinweb: `--subagent-max-depth` flag) | None natively |

---

## Cross-Model Disagreements (Updated)

### Area 1: OpenCode's safety
- **7-model external** adds critical evidence: 18-level `explore→explore` recursion documented in the wild. This confirms that while the architecture permits nesting, the lack of a depth cap makes it **dangerously different** from every other environment. The OCG split (2 yes / 2 no / 1 partial) is resolved by the external evidence: yes it works, but it's a bug, not a feature.

### Area 2: Claude Code depth cap
- The 7-model report resolves this definitively: **5-level hard cap since June 10, 2026**. My OCG-only report had this as "no documented cap" because the deepseek-v4-flash model confused agent teams with subagent spawning. The external report confirms the cap is fixed and not configurable.

### Area 3: Cursor's nesting model
- **Split persists.** The OCG minimax-m3 model cites an explicit 2-level cap from Cursor's docs. The 7-model external report shows 5/7 sources saying "recursive by design" with no hard cap. **Resolution:** Cursor's behavior may depend on version — the docs page (which clarifies) may have been updated between versions. Treat as "recursive with possible environment-specific caps."

### Area 4: Pi extension identity — `nicobailon` vs `@tintinweb`
- OCG models (5/5 with an answer): `nicobailon/pi-subagents`
- 7-model Round 1: `@tintinweb/pi-subagents` (full 7/7 consensus)
- 6-model deep-dive (Round 2): **These are separate projects.** `@tintinweb/pi-subagents` was designed to *conservatively avoid* deep recursion; `nicobailon/pi-subagents` treats recursive orchestration as a first-class feature with explicit `maxSubagentDepth`, chain patterns, and 3× the community adoption.
- **Resolution:** `nicobailon/pi-subagents` is the better choice specifically for recursive/nested subagents. `@tintinweb/pi-subagents` is richer for general-purpose UX (live widget, scheduled agents, Claude Code parity) but not purpose-built for recursion.

---

## Source Registry (Updated)

| ID | Title | URL |
|----|-------|-----|
| s1 | Cursor — Subagents docs | https://cursor.com/docs/subagents |
| s2 | Anthropic — Claude Code sub-agents | https://docs.anthropic.com/en/docs/claude-code/sub-agents |
| s3 | OpenCode — Agents docs | https://opencode.ai/docs/agents/ |
| s4 | Cursor Changelog (v3.11) | https://www.cursor.com/changelog |
| s5 | openai/codex #27331 — multi_agent_v2 | https://github.com/openai/codex/issues/27331 |
| s6 | Cursor — Scaling agents blog | https://www.cursor.com/blog/scaling-agents |
| s7 | OpenCode — Tools docs | https://opencode.ai/docs/tools |
| s8 | OpenAI Agents SDK — Tools | https://openai.github.io/openai-agents-python/tools/ |
| s9 | OpenCode — agent-tool.go source | https://raw.githubusercontent.com/opencode-ai/opencode/main/internal/llm/agent/agent-tool.go |
| s10 | OpenAI — Codex Subagents config | https://platform.openai.com/codex/agent-configuration/subagents |
| s11 | nicobailon/pi-subagents README | https://github.com/nicobailon/pi-subagents |
| s12 | HazAT/pi-interactive-subagents | https://github.com/HazAT/pi-interactive-subagents |
| s13 | earendil-works/pi-mono | https://github.com/earendil-works/pi-mono |
| s14 | Pi Extensions documentation | https://pi.dev/docs/latest/extensions |
| s15 | OpenAI Agents SDK — Handoffs | https://openai.github.io/openai-agents-python/handoffs/ |
| s16 | 7-Model External Consolidated Report | https://gemini.google.com/app/fbf9ea685079b74d |
| s17 | 6-Model Pi Extension Deep-Dive | https://www.perplexity.ai/search/ea16f243-0a52-4dd7-accc-18341023967f |

---

## Methodology

- **OCG profile:** ocg-lite (5 models: minimax-m3, qwen3.7-plus, deepseek-v4-flash, kimi-k2.7-code, mimo-v2.5)
- **Mode:** ultradeep (8-phase pipeline per model)
- **Dispatch method:** OpenCode `task` tool with `ocg-*` subagents
- **External reference (Round 1):** Consolidated report from Gemini, Claude, ChatGPT, Copilot, Perplexity, Grok, DeepSeek (7 models) — https://gemini.google.com/app/fbf9ea685079b74d
- **External reference (Round 2):** Pi-extension deep-dive from Claude, ChatGPT, Copilot, Perplexity, Grok, DeepSeek (6 models; Gemini still generating) — https://www.perplexity.ai/search/ea16f243-0a52-4dd7-accc-18341023967f

### Conflict Resolution Rules
- **Majority rule** used for binary questions (can/cannot)
- **Single-model dissent** recorded as caveat, not override
- **Source-specific claims** (with URL citations) weighted above unsourced claims
- **Official documentation** weighted above inference from source code
- **No consensus** noted explicitly where split is even
- **External 7-model consensus** treated as tiebreaker when OCG models are evenly split

---

## Limitations & Caveats

1. **Timeliness:** All environments are under active development. Claude Code's 5-level cap shipped June 10, 2026 — ChatGPT and Perplexity in the 7-model report were using pre-v2.1.172 docs.
2. **OpenCode depth:** The 18-level recursion is a real-world bug report, not feature documentation. Behavior may vary by config.
3. **Pi extension landscape:** `nicobailon/pi-subagents` and `@tintinweb/pi-subagents` are separate projects with different design goals. The deep-dive (6 models) confirmed `nicobailon` is purpose-built for recursion while `@tintinweb` is conservative about it. Additional competing implementations exist (see Finding 5 table).
4. **Codex docs gap:** No canonical `docs/multi_agent.md`; details reconstructed from issue reports and config files.
5. **Cursor disagreement:** The 2-level cap (OCG minimax-m3) vs recursive (7-model external) split may reflect version differences or docs being out of date.
6. **Subagent definition variance:** The question's "subagent" may be interpreted differently by each platform. Pi's extensions are the most architecturally distinct from the native implementations.
