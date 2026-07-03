# Graphify / agentmemory / RTK / context-mode — runtime `cursor`

Host-specific commands are loaded from `.silver-bullet.json`
`recommended_tools.*.platform_install_commands.cursor` after `SB_HOST=cursor`.

## Marketplace install

- Marketplace `https://github.com/alo-labs/alo-labs-cursor-marketplace`, install
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

## Token compression global rule

`scripts/lib/install-cursor/templates/cursor/token-compression-enforcement.mdc`
→ `~/.cursor/rules/token-compression-enforcement.mdc`
