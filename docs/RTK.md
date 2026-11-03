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

| Host | Command | Artifact | Status |
|------|---------|----------|--------|
| Claude Code | `rtk init -g` | `~/.claude/settings.json` | Supported |
| Codex | `rtk init -g --codex` | `~/.codex/AGENTS.md` (awareness layer; no live PreToolUse rewrite on Codex yet) | Supported (prompt-layer) |
| OpenCode | `bash scripts/optimize-rtk-context-mode.sh --host opencode --project-root "$(pwd)"` | `~/.config/opencode/plugins/rtk.ts` + `opencode.json` | Supported |
| Pi | `bash scripts/optimize-rtk-context-mode.sh --host pi --project-root "$(pwd)"` | `~/.pi/agent/extensions/silver-bullet-five-tool-stack/` | Supported |
| Hermes | `rtk init --agent hermes` | `~/.hermes/plugins/rtk-rewrite/` | Partial |
| Goose | — | — | **Unsupported** upstream |

**Global setup (no SB):** `bash scripts/optimize-rtk-context-mode.sh --host <host> --project-root "$(pwd)"` — see [docs/rtk-cm/README.md](rtk-cm/README.md).

## Verification

```bash
bash scripts/enable-rtk-context-mode.sh --tool rtk
bash scripts/optimize-rtk-context-mode.sh --host claude --project-root "$(pwd)"   # idempotent re-merge
```

## Optimization checklist (research-backed)

Silver Bullet ships `scripts/optimize-rtk-context-mode.sh` for the **most optimized** global wiring. Run after `/sb:init` or standalone:

```bash
bash scripts/optimize-rtk-context-mode.sh --host auto --project-root "$(pwd)"   # detect from ~/.codex, ~/.config/opencode, etc.
bash scripts/optimize-rtk-context-mode.sh --host all --project-root "$(pwd)"    # every host (+ goose SKIP)
```

| Step | Claude | Codex | OpenCode | Pi | Hermes | Goose |
|------|--------|--------|-------|----------|----|--------|-------|
| RTK hook | `rtk init -g` | `rtk init -g --codex` | manifest-backed plugin | native `tool_call` adapter | `rtk init --agent hermes` | SKIP |
| Verify binary | `rtk gain --help` | same | same | same | same | same | — |
| Allow-list | N/A | N/A | N/A | N/A | N/A | — |
| Hook rewrite test | `rtk hook claude` | prompt-only | plugin `tool.execute.before` | extension `tool_call` | `pre_tool_call` plugin | — |
| CM wiring | Claude plugin | MCP+hooks+rules | MCP+hooks.toml | plugin+MCP | extension+MCP | MCP YAML only | SKIP |
| Doctor | `CONTEXT_MODE_PLATFORM=claude` | `=codex` | `=opencode` | SKIP | SKIP | SKIP |

Verification: [docs/rtk-cm/README.md](rtk-cm/README.md) — per-host prompts at `docs/rtk-cm/verification/<host>-verify-rtk-cm.md`.

**Known pitfall:** `reachingforthejack/rtk` (Rust Type Kit) shares the `rtk` name. Verify with `rtk gain --help`.

Manual checks:

```bash
rtk --version
rtk gain
grep -q rtk ~/.claude/settings.json   # Claude example
```

## Hook Coexistence

| Layer | Owner | Event |
|-------|-------|-------|
| SB rtk-gate | Silver Bullet plugin | PreToolUse — blocks until install wired |
| RTK rewrite | `~/.claude/settings.json` etc. | PreToolUse — rewrites Bash input |

SB does **not** merge RTK rewrite logic into the SB plugin `hooks.json`.

### Silver Bullet coexistence

| Surface | RTK rewrite? | SB handling |
|---------|--------------|-------------|
| Agent Shell/Bash (Claude) | Yes — allow-listed commands become `rtk <cmd>` when opted in | SB PreToolUse hooks run **before** RTK and match the **original** command string; gates also unwrap `rtk` prefix for `beforeShellExecution` |
| SB hook subprocesses (`session-start`, …) | No — hooks are not Shell tool calls | `rtk-compat.sh` exports `SILVER_BULLET=1`; `RTK_DISABLED` only when RTK **not** opted in |
| SB harness scripts (`install-claude.sh`, `run-enterprise-e2e-matrix.sh`, …) | No — direct terminal execution | `SB_RTK_COMPAT_MODE=verbatim` before source → `RTK_DISABLED=1` for deterministic parsing |
| Nested `git`/`gh` inside SB scripts | Filter only if invoked via `rtk` on PATH | Verbatim harness mode disables filters; opted-in hook bridge allows RTK |

**Verbatim agent commands:** prefix with `RTK_DISABLED=1` (upstream documented bypass). Example: `RTK_DISABLED=1 git diff main...HEAD` — `rtk hook claude` returns `{}` and runs uncompressed.

**When RTK rewrite is safe:** SB intentionally recommends RTK for agent shell compression when opted in. Round 1 enterprise E2E (22 rows) and 4600+ unit tests passed with RTK wired. Rewrites affect output shape, not exit codes, for `git`/`gh` plumbing.

**Context Mode (separate):** `context-mode hook <host> pretooluse` may redirect `curl`/`wget` in Shell and deny `WebFetch` — unrelated to RTK. See `docs/CONTEXT-MODE.md`.

## Complementary Tools

- **Graphify** — retrieval (tier 1); no conflict with RTK
- **agentmemory** — capture; RTK compresses shell output automatically once wired
- **Context Mode** — MCP/large-file compaction (separate opt-in)

See `silver-bullet.md` §2g-ii.

## Shell ownership and reload receipts

In `five_tool_routed` mode RTK is the **sole** `sb_shell` owner. Context Mode owns grep/slice/webfetch; LeanCTX shell MCP is disabled. Hook order is RTK before Context Mode; `lean-ctx hook rewrite` entries are removed on repair.

Host hook changes batch into one reload receipt (not multiple restart prompts). RTK liveness is proven only when the session attestation reports successful shell-hook evidence alongside MCP tools — config presence alone is insufficient for canonical `ready`.
