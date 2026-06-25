# Context Mode — SB Recommended Tool

Silver Bullet integrates [mksglu/context-mode](https://github.com/mksglu/context-mode) as an opt-in recommended tool for **MCP result compaction** and **PreCompact state recovery**. SB orchestrates install, scaffolds instruction fragments, and verifies wiring.

## License

Context Mode is **ELv2** — not OSI-open. Acceptable for personal/internal use. Teams shipping SaaS products that bundle Context Mode need a commercial license from the upstream author. SB surfaces this at consent time via `recommended_tools.context_mode.license_note`.

## Opt-In Policy

```json
"recommended_tools": {
  "context_mode": {
    "enabled_by_user": null,
    "enforcement_suspended": false,
    "min_node_version": "22.5",
    "license_note": "ELv2 — not OSI-open; commercial bundling requires upstream license"
  }
}
```

| `enabled_by_user` | Behavior |
|-----------------|----------|
| `null` | Consent pending — include ELv2 disclosure and MCP-value note |
| `true` | Install/wiring gate — CLI/plugin, MCP/hooks, instruction fragment |
| `false` | Advisory only |

**Usage enforcement:** When to use `ctx_*` vs `Read` is **instructional** in `silver-bullet.md` §2g-ii and the scaffolded hint fragment — SB does **not** block Read by file size.

**Windows:** Native Windows requires WSL. SB auto-suspends with `install_failure_reason: "Windows requires WSL"`.

## Prerequisites

```bash
node --version   # >= 22.5 required
npm --version
```

## Install

### Global npm (all hosts)

```bash
npm install -g context-mode
context-mode --version
```

### Claude Code plugin (recommended when using Claude)

```bash
claude plugin marketplace add mksglu/context-mode
claude plugin install context-mode@context-mode
```

**Restart Claude Code** after plugin install — hooks load on restart.

## Platform Wiring

| Host | Steps | Artifacts |
|------|-------|-----------|
| Claude Code | Plugin install (above) | `~/.claude/plugins/context-mode` |
| Cursor | Copy `context-mode.mdc` to `.cursor/rules/`; merge MCP + hooks per [upstream Cursor docs](https://github.com/mksglu/context-mode#cursor) | `~/.cursor/mcp.json`, `~/.cursor/hooks.json` |
| Codex | Merge `config.toml` + `hooks.json` blocks; copy `configs/codex/AGENTS.md` | `~/.codex/config.toml`, `~/.codex/hooks.json` |

SB runs `/silver:init` scaffold steps to inject the instruction fragment into `silver-bullet.md` and `CLAUDE.md` (idempotent sentinel block from `templates/context-mode-hint.md.base`).

## Instruction Fragment

Without the fragment, the model defaults to `Read` and Context Mode savings drop to zero. SB gates check for the sentinel block when opted in.

Tool name placeholders vary by host (Claude plugin-qualified names vs Cursor MCP names). Run `/context-mode:ctx-doctor` in Claude Code or `context-mode doctor` from terminal to confirm prefixes.

## Verification

```bash
bash scripts/enable-rtk-context-mode.sh --tool context_mode
```

Manual (requires restarted agent):

```
/context-mode:ctx-doctor    # Claude Code
context-mode doctor       # terminal
```

## Known Gaps

- Cursor Context Mode wiring is partly manual (plugin path or MCP + hooks merge)
- Codex PreToolUse lacks `updatedInput` — capture works; live rewrites limited
- Goose / Pi: thinner upstream docs — see RTK.md for Pi RTK path
- Insight dashboard (`context-mode.com/insight`) is optional paid SaaS — out of SB scope

## Complementary Tools

- **Graphify** — retrieval; no tier conflict
- **RTK** — shell output (separate opt-in)
- **agentmemory** — capture; pair with Graphify for retrieve

See `silver-bullet.md` §2g-ii.
