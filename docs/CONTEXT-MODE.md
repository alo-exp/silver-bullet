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
    "read_deny_bytes": 5120,
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

**Bypass / tuning:**
- Raise threshold: set `read_deny_bytes` in `.silver-bullet.json` (e.g. `65536` for header-only reads).
- One-time research (e.g. large session transcripts): `CONTEXT_MODE_READ_DENY_BYPASS=1` in the session environment before `Read|Grep`.
- Prefer `ctx_execute_file` for bounded extraction when the full file must not enter context.

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

| Host | Steps | Artifacts | Status |
|------|-------|-----------|--------|
| Claude Code | Plugin install (above) | `~/.codex/plugins/context-mode` | Supported |
| Cursor | Merge MCP + hooks per [upstream Cursor docs](https://github.com/mksglu/context-mode#cursor) | `~/.cursor/mcp.json`, `~/.cursor/hooks.json`, `~/.cursor/rules/` | Supported |
| Codex | Merge `config.toml` + `hooks.json` blocks | `~/.codex/config.toml`, `~/.codex/hooks.json` | Supported |
| OpenCode | Plugin + MCP in `opencode.json`; copy `AGENTS.md` | `~/.config/opencode/` | Supported |
| Hermes | MCP YAML merge only (no official adapter) | `~/.hermes/config.yaml` | Partial |
| Goose | — | — | **Unsupported** |

**Global setup (no SB):** `bash scripts/optimize-rtk-context-mode.sh --host <host> --project-root "$(pwd)"` — see [docs/rtk-cm/README.md](rtk-cm/README.md).

SB runs `/sb:init` scaffold steps to inject the instruction fragment into `silver-bullet.md` and `CLAUDE.md` (idempotent sentinel block from `templates/context-mode-hint.md.base`).

## Instruction Fragment

Without the fragment, the model defaults to `Read` and Context Mode savings drop to zero. SB gates check for the sentinel block when opted in.

Tool name placeholders vary by host (Claude plugin-qualified names vs Cursor MCP names). Run `/context-mode:ctx-doctor` in Claude Code or `context-mode doctor` from terminal to confirm prefixes.

## Verification

```bash
bash scripts/enable-rtk-context-mode.sh --tool context_mode
bash scripts/optimize-rtk-context-mode.sh --host cursor --project-root "$(pwd)"   # idempotent re-merge
```

## Optimization checklist (research-backed)

Run `bash scripts/optimize-rtk-context-mode.sh --host cursor --project-root "$(pwd)"` after install:

| Step | Cursor | Claude | Codex | OpenCode | Hermes | Goose |
|------|--------|--------|-------|----------|--------|-------|
| CLI / plugin | `npm install -g context-mode` | `claude plugin install context-mode@context-mode` | `npm install -g context-mode` | plugin in `opencode.json` | MCP YAML | SKIP |
| MCP | `~/.cursor/mcp.json` | Plugin auto-registers | `[mcp_servers.context-mode]` | `mcp.context-mode` | `mcp_servers` in yaml | — |
| Hooks | pre/post/session/stop/afterAgentResponse | Plugin manifest | 6 events in hooks.json | TS plugin events | none official | — |
| Rules | `~/.cursor/rules/*.mdc` | plugin rules | `AGENTS.md` | `~/.config/opencode/AGENTS.md` | — | — |
| Doctor | `CONTEXT_MODE_PLATFORM=cursor` | `/context-mode:ctx-doctor` | `=codex` | `=opencode` | SKIP | SKIP |

Verification: [docs/rtk-cm/README.md](rtk-cm/README.md) — per-host prompts at `docs/rtk-cm/verification/<host>-verify-rtk-cm.md`.

**Hook ordering:** Place context-mode `preToolUse` **after** RTK `preToolUse` for Shell — RTK rewrites first; CM routes/denies WebFetch and large Read analysis.

**Read deny:** Upstream context-mode still has no global Read deny. SB adds **`hooks/context-mode-read-deny.sh`** on the plugin PreToolUse manifest (`Read|Grep`) when `context_mode` is enforced. Threshold: `read_deny_bytes` (default 5120). Global `~/.cursor/hooks.json` is unchanged — merge via `/sb:init` docs if you want the same deny outside the plugin bridge.

**Cursor `additional_context` bug:** Hooks accept `additional_context` but Cursor does not surface it to the model ([#155689](https://forum.cursor.com/t/native-posttooluse-hooks-accept-and-log-additional-context-successfully-but-the-injected-context-is-not-surfaced-to-the-model/155689)). Routing must use `.mdc` rules and MCP tool descriptions, not hook-injected context.

**Duplicate hooks:** If both plugin and manual `hooks.json` entries exist, `context-mode doctor` warns — remove one source.

**Project `hooks.json` trap:** Do not add `.cursor/hooks.json` inside a repo unless you intend team-shared hooks. Cursor (and `context-mode doctor` when cwd is that repo) prefers the workspace file over `~/.cursor/hooks.json`, which breaks global RTK/CM verification. Use global `~/.cursor/hooks.json` for personal wiring; SB plugin hooks merge there via `/sb:init`.

Manual (requires restarted agent):

```
/context-mode:ctx-doctor    # Claude Code
context-mode doctor       # terminal
```

## Known Gaps

- Cursor Context Mode wiring is partly manual (plugin path or MCP + hooks merge)
- Codex PreToolUse lacks `updatedInput` — capture works; live rewrites limited
- Goose: **no upstream RTK or Context Mode integration** — see [docs/rtk-cm/verification/goose-verify-rtk-cm.md](rtk-cm/verification/goose-verify-rtk-cm.md)
- Hermes: Context Mode MCP merge only (partial) — see [docs/rtk-cm/verification/hermes-verify-rtk-cm.md](rtk-cm/verification/hermes-verify-rtk-cm.md)
- Pi: RTK via `rtk init --agent pi`; CM via OpenCode-family adapters where applicable
- Insight dashboard (`context-mode.com/insight`) is optional paid SaaS — out of SB scope

## Complementary Tools

- **Graphify** — retrieval; no tier conflict
- **RTK** — shell output (separate opt-in)
- **agentmemory** — capture; pair with Graphify for retrieve

See `silver-bullet.md` §2g-ii.

## MCP reload receipts

Context Mode MCP tools (`ctx_execute`, `ctx_search`, …) must be registered without LeanCTX `ctx_*` overlap. After installer or `/sb:doctor --fix` host repair, expect `reload_required` until Cursor reloads MCP and a fresh attestation confirms expected tools. Read-only `verify`/`plan` consume `--host-evidence-stdin` in memory only; receipt clearing requires authorized apply with all-success evidence.
