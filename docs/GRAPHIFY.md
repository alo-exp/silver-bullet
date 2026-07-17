# Graphify Readiness

Silver Bullet uses Graphify as the **mandatory** local retrieval layer before planning, editing, debugging, review, and shipping when the CLI is installed. Hooks block substantive work without a fresh query.

## Opt-In Policy

Graphify is a **recommended tool**, not a hard prerequisite like `jq`. SB asks for explicit
permission at `/silver:init` and session start. Consent is stored in `.silver-bullet.json`:

```json
"recommended_tools": {
  "graphify": {
    "enabled_by_user": null,
    "enforcement_suspended": false,
    "install_status": null,
    "install_failure_reason": null,
    "required_when_enabled": true
  }
}
```

| `enabled_by_user` | Behavior |
|-----------------|----------|
| `null` | Consent pending — SB prompts at init, update, and session start; no hook enforcement |
| `true` | Mandatory — hooks block substantive edits until index + fresh query |
| `false` | Opted out — advisory/docs fallback only |

**Install failure after opt-in:** when the user opts in but CLI install or index build fails,
SB sets `enforcement_suspended: true` and `install_status: "failed"` (with `install_failure_reason`).
Init/update is not blocked. Hooks treat suspended Graphify like opted-out while preserving
`enabled_by_user: true`. Session-start notes the suspension. On the next `/silver:init` (update
mode) or `/silver:update`, SB retries install; success clears suspension and re-enables mandatory
enforcement.

The same `recommended_tools` pattern applies to future SB-suggested tooling (see `hooks/lib/recommended-tools.sh`).

## Local Setup

Graphify requires Python 3.10+. Install the CLI, then register the platform-specific skill
per [upstream Pick your platform](https://github.com/safishamsi/graphify#pick-your-platform).

### Step 1 — CLI package

```bash
uv tool install graphifyy
```

or:

```bash
pipx install graphifyy
```

Optional surfaces:

```bash
uv tool install "graphifyy[mcp]"
python3.12 -m pip install watchdog psycopg[binary]
```

`watchdog` enables `graphify watch`. `psycopg` enables `graphify extract --postgres`. `graphifyy[mcp]` enables `graphify-mcp --transport http`.

### Step 2 — Platform registration (SB-supported hosts)

Run from the project root after the CLI is on PATH. SB stores these in
`recommended_tools.graphify.platform_install_commands` in `.silver-bullet.json`.

| Host | Pre-index (skill) | Post-index (always-on) | Artifact |
|------|-------------------|------------------------|----------|
| Claude Code | `graphify install --project` | `graphify claude install --project` | `.claude/settings.json` |
| Codex | `graphify install --project --platform codex` | `graphify codex install --project` | `.codex/hooks.json` |
| Cursor | *(none)* | `graphify cursor install` | `.cursor/rules/graphify.mdc` ([issue #137](https://github.com/safishamsi/graphify/issues/137#issuecomment-4215764533)) |
| OpenCode | `graphify install --project --platform opencode` | *(hooks in `.opencode/plugins/graphify.js`)* | `.opencode/opencode.json` |
| Goose (Pi) | `graphify install --project --platform pi` | *(skill only)* | `.pi/agent/skills/graphify/SKILL.md` |
| Hermes | `graphify install --project --platform hermes` | *(AGENTS.md rules — no PreToolUse)* | `AGENTS.md` graphify section |

Codex also needs `multi_agent = true` under `[features]` in `~/.codex/config.toml` for parallel extraction (upstream note).

SB detects the active host via `SILVER_BULLET_RUNTIME`, `CURSOR_PLUGIN_ROOT`, or Codex env vars
(same logic as `hooks/lib/runtime-paths.sh`). `/silver:init` and `/silver:update` run pre-index
commands, build the index, then run post-index commands when the user opts in.

### Step 3 — Index

For normal SB work without LLM keys:

```bash
graphify update . --no-cluster
```

This refreshes code extraction only and works in docs-heavy SB repos. Full semantic extraction over docs, Markdown, HTML, PDFs, or images requires one of Graphify's supported LLM API keys.

Use `/graphify .` inside the agent session or `graphify update .` from the shell for incremental refresh. After upgrading graphify, re-run platform install commands and optionally `graphify hook install` to refresh embedded interpreter paths (upstream git-hooks note).

### Step 4 — Optional git hooks

```bash
graphify hook install
```

Auto-rebuilds the graph on git commit (AST only, no API cost) and sets up a merge driver for `graph.json`.

## Query Pattern

Prefer concrete, scoped queries:

```bash
graphify query "dev-cycle-check source edit Stage C hooks/dev-cycle-check.sh" --graph graphify-out/graph.json --budget 2000
```

Then inspect returned nodes before acting. Broad terms can match workflow/docs nodes before the intended implementation nodes. If label lookup misses a script or file that appears in `graph.json`, use the generated node id from the graph or from a prior query result.

Useful follow-ups:

```bash
graphify explain hooks_dev_cycle_check --graph graphify-out/graph.json
graphify affected "record-skill.sh" --graph graphify-out/graph.json
graphify path "completion-audit.sh" "verify-tests" --graph graphify-out/graph.json
```

## Tested Surface

Validated against Graphify `0.8.36` in `todo-app`:

- update, extract, cluster-only, label fallback
- query, DFS query, explain, path, affected, diagnose, benchmark
- tree HTML and call-flow HTML exports
- save-result, merge-graphs, merge-driver
- global add/list/remove/path
- URL add, clone
- hook install/status/uninstall
- generic install/uninstall and all platform install/uninstall commands

Observed constraints:

- `graphify extract .` fails without an LLM key when docs/Markdown/HTML inputs are present.
- `graphify watch .` needs `watchdog`.
- `graphify extract --postgres` needs `psycopg` and a reachable database.
- `graphify-mcp --transport http` needs the MCP extra (`graphifyy[mcp]`).
- `graphify label` can exit successfully with placeholder labels when no backend key is available.

## Optimization (synergy_max)

When Graphify is opted in, SB runs `bash scripts/sb-optimize-stack.sh --apply` at init/update (profile `synergy_max`):

| Step | Action |
|------|--------|
| Git hooks | `graphify hook install` — auto-rebuild on commit/checkout |
| Platform always-on | Per-host post-index commands (see Step 2 table) |
| Index | `graphify update . --no-cluster` when missing or after agentmemory export |
| Query budget | `--budget 2000` per §2g-i; TTL `query_ttl_seconds: 1800` in config |

Verify: `bash scripts/sb-optimize-stack.sh --verify` or `optimize-graphify-hooks` in diagnostics.

See `docs/STACK-OPTIMIZATION.md` for full contract.

## agentmemory Synergy

When both Graphify and agentmemory are opted in:

1. **Capture** — agentmemory records sessions and exports markdown to `.agentmemory/memory/` and `.agentmemory/snapshots/`.
2. **Index** — `graphify update . --no-cluster` indexes `.agentmemory/` alongside code and docs.
3. **Retrieve** — use `graphify query` for structural + memory context; hooks treat a fresh Graphify query as satisfying the agentmemory usage gate.

See `docs/AGENTMEMORY.md` for install, MCP wiring, and git-backed auto-save bridge setup.

## MCP extra and reload receipts

Install Graphify with the MCP extra so `graphify-mcp` is on PATH:

```bash
uv tool install "graphifyy[mcp]"
```

SB writes Cursor MCP config only after a successful `graphify-mcp` stdio handshake. **Configured ≠ live:** after host config changes, the reconciler emits a reload receipt at `${SB_RUNTIME_STATE}/recommended-tools/reload-receipts/<host>/<project-id>/<worktree-id>/`. Canonical state stays `reload_required` until the current Cursor session supplies a fresh schema-v1 attestation via `--host-evidence-stdin` (max 64KiB, single JSON document) showing every expected tool succeeded.

| Signal | Meaning |
|--------|---------|
| `CONFIGURED: yes` | `~/.cursor/mcp.json` includes Graphify |
| `LIVE: no` | Receipt active or activation not `full` |
| `ACTION` | Tools & MCP → graphify off/on, then new chat; fallback Developer: Reload Window |

Verify read-only: `bash scripts/reconcile-recommended-tools.sh --mode verify --host-evidence-stdin`. Clear requires authorized apply (`/silver:init`, `/silver:update`, installer, or `/silver:doctor --fix`) with a fresh all-success attestation.
