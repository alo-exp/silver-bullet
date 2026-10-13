# Graphify / agentmemory / RTK / context-mode — runtime `claude`

Host-specific commands are loaded from `.silver-bullet.json`
`recommended_tools.*.platform_install_commands.claude` after `SB_HOST=claude`.

## Marketplace install

- Add marketplace `https://github.com/alo-labs/agent-plugins`
- `/plugin install silver-bullet@alo-labs`
- Or: `bash scripts/install-claude.sh`

## Graphify

| Phase | Commands | Artifact |
|-------|----------|----------|
| Pre-index | `graphify install --project` | — |
| Post-index | `graphify claude install --project` | `.codex/settings.json` hooks |

## Agentmemory

Post-index: `agentmemory connect claude-code`

## Context-mode

- `npm install -g context-mode`
- `bash scripts/optimize-rtk-context-mode.sh --host claude --project-root "$(pwd)"`
- The optimizer disables the optional `context-mode@context-mode` Claude plugin
  and registers the same global MCP executable used by Cursor and Codex.
- Restart the host agent after changing MCP configuration.

## Hook merge

`python3 scripts/lib/install-claude/merge-hooks.py "$INSTALL_PATH"`

## Project instruction template

`scripts/lib/install-claude/templates/CLAUDE.md.base`
