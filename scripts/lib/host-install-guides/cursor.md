# Graphify / agentmemory / RTK / context-mode — runtime `cursor`

Host-specific commands are loaded from `.silver-bullet.json`
`recommended_tools.*.platform_install_commands.cursor` after `SB_HOST=cursor`.

## Marketplace install

- Marketplace `https://github.com/alo-labs/agent-plugins` (`alo-labs-cursor` catalog), install
  `silver-bullet`, or `bash scripts/install-cursor.sh --public-release`
- Dev: `bash scripts/install-cursor.sh`

## Graphify

| Phase | Commands | Artifact |
|-------|----------|----------|
| Pre-index | *(none)* | — |
| Post-index | `graphify cursor install` | `.cursor/rules/graphify.mdc` |

## Agentmemory

Verify agentmemory MCP in `~/.cursor/mcp.json` per `docs/AGENTMEMORY.md`

## RTK

`rtk init -g --agent cursor`;
`bash scripts/optimize-rtk-context-mode.sh --host cursor`

## Context-mode

Copy `context-mode.mdc` to `.cursor/rules/` per upstream (optimize script)

## Orchestrator parent

Copy `scripts/lib/install-cursor/templates/cursor-rules/silver-orchestrator.mdc`
→ `.cursor/rules/silver-orchestrator.mdc`

## Hook merge

`python3 scripts/lib/install-cursor/merge-cursor-hooks.py "$INSTALL_PATH"`

## SB custom subagents (RFL / review ladders)

After hook merge, `bash scripts/install-cursor.sh` runs `install-cursor-sb-agents.sh --global`
(interactive when TTY; else `--non-interactive` defaults: Composer 2.5 + Grok 4.5 × medium/high/xhigh → 6 `sb-*` agents in `~/.cursor/agents/`).

| Surface | Command |
|---------|---------|
| Install | `bash scripts/install-cursor-sb-agents.sh --global` |
| Project fallback (init) | `bash scripts/install-cursor-sb-agents.sh --project` — only when global probe fails |
| Doctor D21 | `bash scripts/lib/cursor-sb-agents/probe-global-agents.sh` |
| Remediation | `bash scripts/install-cursor-sb-agents.sh --fix` or `bash scripts/sb-doctor.sh --fix` |

Init §3.2.3: tri-state `cursor_sb_agents.enabled_by_user`; **skip** project `.cursor/agents/` when global probe passes (exact count + name set). Fast/Max models excluded unless user opts in at install/init.

## Token compression global rule

`scripts/lib/install-cursor/templates/cursor/token-compression-enforcement.mdc`
→ `~/.cursor/rules/token-compression-enforcement.mdc`
