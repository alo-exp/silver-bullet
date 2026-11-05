# Cross-Model Conflicts — Subagent Nesting Research

## Conflict 1: OpenCode — Can subagents spawn sub-subagents?

| Model | Position | Evidence |
|-------|----------|----------|
| minimax-m3 | YES — `permission.task` glob is agent-agnostic; hidden subagents (`hidden: true`) enable programmatic spawning | docs |
| deepseek-v4-flash | YES architecturally — Task tool permission system doesn't distinguish caller role | inference |
| qwen3.7-plus | NO — only `mode: "primary"` agents can invoke Task tool | docs |
| kimi-k2.7-code | NO — subagents use `TaskAgentTools` which omits `agent` tool | source code |
| mimo-v2.5 | PARTIAL — Task tool exists but disabled for subagents by default | docs |

**Resolution:** NO-CONSENSUS. The architecture permits it with explicit config, but default behavior denies it. The answer depends on configuration, not capability.

## Conflict 2: Claude Code — flat hierarchy vs recursive nesting

| Model | Position | Evidence |
|-------|----------|----------|
| deepseek-v4-flash | NO — flat hierarchy (lead → parallel workers) | describes agent teams pattern |
| 4 other models | YES — `Agent` tool in frontmatter enables recursion | official Anthropic docs |

**Resolution:** REJECTED (deepseek-v4-flash describes "agent teams" not subagent spawning). Majority holds.

## Conflict 3: Pi — consumer AI vs extensible platform

| Model | Position | Evidence |
|-------|----------|----------|
| deepseek-v4-flash, mimo-v2.5 | NO subagents — consumer product | pi.ai, inflection.ai |
| minimax-m3, kimi-k2.7-code, qwen3.7-plus | YES via extension — `nicobailon/pi-subagents` | GitHub repos, npm |

**Resolution:** BOTH CORRECT. Pi core has no subagents; the extension ecosystem adds them. The specific extension is `nicobailon/pi-subagents`.
