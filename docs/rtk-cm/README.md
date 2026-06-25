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
| **Claude Code** | `rtk init -g` → `~/.claude/settings.json` | Plugin `context-mode@context-mode` | **SUPPORTED** | `~/.claude/` |
| **Codex** | `rtk init -g --codex` → `~/.codex/AGENTS.md` | MCP + `hooks.json` merge | **SUPPORTED** (RTK prompt-layer) | `~/.codex/` |
| **Cursor** | `rtk init -g --agent cursor` + allow-list | MCP + hooks + `~/.cursor/rules/` | **SUPPORTED** | `~/.cursor/` |
| **OpenCode** | `rtk init -g --opencode` → plugin TS | Plugin + MCP in `opencode.json` | **SUPPORTED** | `~/.config/opencode/` |
| **Hermes** | `rtk init --agent hermes` → Python plugin | MCP YAML merge only | **PARTIAL** | `~/.hermes/` |
| **Goose** | — | — | **UNSUPPORTED** | — |

Filenames use `*-verify-graphify-am.md` for historical parity with the Graphify+agentmemory verification suite; each doc verifies **RTK + Context Mode only**. Graphify/agentmemory cross-refs are optional.

## Verification docs

| Agent | Doc |
|-------|-----|
| Claude Code | [claude-verify-graphify-am.md](verification/claude-verify-graphify-am.md) |
| Codex | [codex-verify-graphify-am.md](verification/codex-verify-graphify-am.md) |
| Cursor | [cursor-verify-graphify-am.md](verification/cursor-verify-graphify-am.md) |
| OpenCode | [opencode-verify-graphify-am.md](verification/opencode-verify-graphify-am.md) |
| Hermes | [hermes-verify-graphify-am.md](verification/hermes-verify-graphify-am.md) |
| Goose | [goose-verify-graphify-am.md](verification/goose-verify-graphify-am.md) |

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
