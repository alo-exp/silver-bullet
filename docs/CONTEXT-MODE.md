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

**Usage enforcement:** When to use `ctx_*` vs `Read` is mandatory in `silver-bullet.md` §2g-ii. When Context Mode is opted in and enforced, SB **`context-mode-read-deny.sh`** (PreToolUse on `Read|Grep`) returns **deny** if the target file exceeds `recommended_tools.context_mode.read_deny_bytes` (default **5120**). Exempt: trivial bypass, SB state/config paths, files at or below the threshold.

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
bash scripts/optimize-rtk-context-mode.sh --host cursor   # idempotent re-merge
```

## Optimization checklist (research-backed)

Run `bash scripts/optimize-rtk-context-mode.sh` after install when Context Mode is opted in:

| Step | Cursor | Claude | Codex |
|------|--------|--------|-------|
| CLI / plugin | `npm install -g context-mode` | `claude plugin install context-mode@context-mode` | `npm install -g context-mode` + merge `config.toml` |
| MCP | Merge `configs/cursor/mcp.json` → `~/.cursor/mcp.json` | Plugin auto-registers | `[mcp_servers.context-mode]` in `config.toml` |
| Hooks (full set) | `preToolUse`, `postToolUse`, `sessionStart`, `stop`, `afterAgentResponse` | Plugin manifest (incl. `PreCompact`) | 6 events in `hooks.json` |
| Rules | `context-mode.mdc` + `token-compression-enforcement.mdc` in `~/.cursor/rules/` **and** project `.cursor/rules/` | Plugin rules | `configs/codex/AGENTS.md` |
| Instruction fragment | `templates/context-mode-hint.md.base` in project docs | same | same |
| Doctor | `CONTEXT_MODE_PLATFORM=cursor context-mode doctor` | `/context-mode:ctx-doctor` | `context-mode doctor` |
| Restart agent | Required after plugin/MCP/hook changes | Required | Required |

**Hook ordering:** Place context-mode `preToolUse` **after** RTK `preToolUse` for Shell — RTK rewrites first; CM routes/denies WebFetch and large Read analysis.

**Read deny:** Upstream context-mode still has no global Read deny. SB adds **`hooks/context-mode-read-deny.sh`** on the plugin PreToolUse manifest (`Read|Grep`) when `context_mode` is enforced. Threshold: `read_deny_bytes` (default 5120). Global `~/.cursor/hooks.json` is unchanged — merge via `/silver:init` docs if you want the same deny outside the plugin bridge.

**Cursor `additional_context` bug:** Hooks accept `additional_context` but Cursor does not surface it to the model ([#155689](https://forum.cursor.com/t/native-posttooluse-hooks-accept-and-log-additional-context-successfully-but-the-injected-context-is-not-surfaced-to-the-model/155689)). Routing must use `.mdc` rules and MCP tool descriptions, not hook-injected context.

**Duplicate hooks:** If both plugin and manual `hooks.json` entries exist, `context-mode doctor` warns — remove one source.

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
