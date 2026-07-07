# RTK + Context Mode — Global Multi-Agent Stack

Machine-level token compression for AI coding agents **without Silver Bullet**. RTK compresses shell output; Context Mode sandboxes MCP results and large-file analysis.

## Quick setup

```bash
# Auto-detect host from ~/.cursor, ~/.codex, ~/.claude, etc.
bash scripts/optimize-rtk-context-mode.sh --host auto

# Or target a specific agent
bash scripts/optimize-rtk-context-mode.sh --host claude
bash scripts/optimize-rtk-context-mode.sh --host codex
bash scripts/optimize-rtk-context-mode.sh --host cursor
bash scripts/optimize-rtk-context-mode.sh --host opencode
bash scripts/optimize-rtk-context-mode.sh --host hermes   # partial
bash scripts/optimize-rtk-context-mode.sh --host goose    # skip (unsupported)

# All hosts (supported + documented skip for goose)
bash scripts/optimize-rtk-context-mode.sh --host all
```

Prerequisites: `rtk-ai/rtk` on PATH (`rtk gain --help` must work), Node >= 22.5 for Context Mode.

## Platform matrix

| Agent | RTK | Context Mode | Status | Global config roots |
|-------|-----|--------------|--------|---------------------|
| **Claude Code** | `rtk init -g` → `~/.codex/settings.json` | Plugin `context-mode@context-mode` | **SUPPORTED** | `~/.codex/` |
| **Codex** | `rtk init -g --codex` → `~/.codex/AGENTS.md` | MCP + `hooks.json` merge | **SUPPORTED** (RTK prompt-layer) | `~/.codex/` |
| **Cursor** | `rtk init -g --agent cursor` + allow-list | MCP + hooks + `~/.cursor/rules/` | **SUPPORTED** | `~/.cursor/` |
| **OpenCode** | `rtk init -g --opencode` → plugin TS | Plugin + MCP in `opencode.json` | **SUPPORTED** | `~/.config/opencode/` |
| **Hermes** | `rtk init --agent hermes` → Python plugin | MCP YAML merge only | **PARTIAL** | `~/.hermes/` |
| **Goose** | — | — | **UNSUPPORTED** | — |

## Verification docs

Per-host self-verification prompts for the **RTK + Context Mode** stack (`*-verify-rtk-cm.md`). No Silver Bullet required.

| Agent | Doc |
|-------|-----|
| Claude Code | [claude-verify-rtk-cm.md](verification/claude-verify-rtk-cm.md) |
| Codex | [codex-verify-rtk-cm.md](verification/codex-verify-rtk-cm.md) |
| Cursor | [cursor-verify-rtk-cm.md](verification/cursor-verify-rtk-cm.md) |
| OpenCode | [opencode-verify-rtk-cm.md](verification/opencode-verify-rtk-cm.md) |
| Hermes | [hermes-verify-rtk-cm.md](verification/hermes-verify-rtk-cm.md) |
| Goose | [goose-verify-rtk-cm.md](verification/goose-verify-rtk-cm.md) |

## Related stacks

| Stack | Docs |
|-------|------|
| **RTK + Context Mode** (this directory) | [README.md](README.md), `verification/*-verify-rtk-cm.md` |
| **Graphify + agentmemory** | [docs/graphify-am/](../graphify-am/), `docs/graphify-am/verification/*-verify-graphify-am.md` |

## Related

- [docs/RTK.md](../RTK.md) — RTK install and per-host wiring
- [docs/CONTEXT-MODE.md](../CONTEXT-MODE.md) — Context Mode install and hooks
- [rtk-cm-cursor-verification.md](rtk-cm-cursor-verification.md) — extended Cursor audit (reference)

## Scripts

| Script | Role |
|--------|------|
| `scripts/optimize-rtk-context-mode.sh` | Idempotent global optimizer (`--host`, `--dry-run`) |
| `scripts/lib/merge-token-compression-config.py` | Merge hooks, MCP, allow-list, AGENTS.md |
| `scripts/install-recommended-tools-global.sh` | Global instruction artifacts per host |
| `scripts/install-recommended-tools-cursor.sh` | Cursor `.mdc` rules (`--global`) |
| `scripts/enable-rtk-context-mode.sh` | Quick verify (SB-aware when `.silver-bullet.json` present) |
| `hooks/lib/rtk-cm-global.sh` | Shared host detection and backup helpers |
