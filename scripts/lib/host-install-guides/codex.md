# Graphify / agentmemory / RTK / context-mode — runtime `codex`

Host-specific commands are loaded from `.silver-bullet.json`
`recommended_tools.*.platform_install_commands.codex` after `SB_HOST=codex`.

## Marketplace install

- Public `alo-labs/codex-plugins` marketplace via
  `bash scripts/install-codex.sh --public-release`
- Dev: `bash scripts/install-codex.sh --purge-legacy-skills`

## Graphify

| Phase | Commands | Artifact |
|-------|----------|----------|
| Pre-index | `graphify install --project --platform codex` | — |
| Post-index | `graphify codex install --project` | `.codex/hooks.json` |

## Agentmemory

Pre-index: `codex plugin marketplace add rohitg00/agentmemory`;
`codex plugin add agentmemory@agentmemory`

Post-index: `agentmemory connect codex --with-hooks`

## RTK

`rtk init -g --codex`; merge via `bash scripts/optimize-rtk-context-mode.sh --host codex`

## Context-mode

Merge blocks into `~/.codex/config.toml` and `hooks.json` per `docs/CONTEXT-MODE.md`

## Hook merge

`python3 scripts/lib/install-claude/merge-hooks.py "$INSTALL_PATH"` (shared merge utility)

## Runtime notes

- Keep prompts runtime-neutral; use the current approval model
- Refer to the project instruction file as AGENTS.md where applicable
