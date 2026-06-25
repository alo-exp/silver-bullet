# RTK (Rust Token Killer) — SB Recommended Tool

Silver Bullet integrates [rtk-ai/rtk](https://github.com/rtk-ai/rtk) as an opt-in recommended tool for **shell output compression** via upstream `PreToolUse` hooks. SB orchestrates install and verifies wiring; RTK owns the rewrite logic.

## Opt-In Policy

Consent lives in `.silver-bullet.json`:

```json
"recommended_tools": {
  "rtk": {
    "enabled_by_user": null,
    "enforcement_suspended": false,
    "install_status": null,
    "min_version": "0.42.0"
  }
}
```

| `enabled_by_user` | Behavior |
|-----------------|----------|
| `null` | Consent pending — SB prompts at init, update, session start |
| `true` | Mandatory install/wiring gate — hooks block until CLI + host hook present |
| `false` | Advisory only |

**Wrong binary trap:** `reachingforthejack/rtk` (Rust Type Kit) shares the `rtk` command name. SB verifies `rtk gain --help` succeeds and rejects the wrong binary.

## Install

### macOS (Homebrew)

```bash
brew tap rtk-ai/rtk
brew install rtk
rtk --version    # expect v0.4x
rtk gain --help  # must succeed
```

### Linux

```bash
curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/master/install.sh | sh
# Ensure ~/.local/bin is on PATH
```

### Windows

Native Windows is **not supported**. Use WSL. SB sets `enforcement_suspended: true` with reason `Windows requires WSL` on native Windows.

## Platform Wiring

Run from project root after CLI install. SB stores commands in `recommended_tools.rtk.platform_install_commands`.

| Host | Command | Artifact |
|------|---------|----------|
| Claude Code | `rtk init -g` | `~/.claude/settings.json` |
| Cursor | `rtk init -g --agent cursor` | `~/.cursor/hooks.json` (`rtk hook cursor`) |
| Codex | `rtk init -g --codex` | `~/.codex/AGENTS.md` (awareness layer; no live PreToolUse rewrite on Codex yet) |

Codex limitation: PreToolUse on Codex supports deny rules only — RTK savings on Codex are primarily via `AGENTS.md` awareness ([openai/codex#18491](https://github.com/openai/codex/issues/18491)).

## Verification

```bash
bash scripts/enable-rtk-context-mode.sh --tool rtk
```

Manual checks:

```bash
rtk --version
rtk gain
grep -q rtk ~/.cursor/hooks.json   # Cursor example
```

## Hook Coexistence

| Layer | Owner | Event |
|-------|-------|-------|
| SB rtk-gate | Silver Bullet plugin | PreToolUse — blocks until install wired |
| RTK rewrite | `~/.cursor/hooks.json` etc. | PreToolUse — rewrites Bash input |

SB does **not** merge RTK rewrite logic into the SB plugin `hooks.json`.

## Complementary Tools

- **Graphify** — retrieval (tier 1); no conflict with RTK
- **agentmemory** — capture; RTK compresses shell output automatically once wired
- **Context Mode** — MCP/large-file compaction (separate opt-in)

See `silver-bullet.md` §2g-ii.
