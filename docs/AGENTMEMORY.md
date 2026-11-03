# agentmemory Readiness

Silver Bullet uses [agentmemory](https://github.com/rohitg00/agentmemory) as an opt-in recommended tool for session capture, proactive context injection, and git-backed memory export. It pairs with Graphify in the **save via agentmemory, retrieve via Graphify** synergy model.

## Opt-In Policy

agentmemory is a **recommended tool**, not a hard prerequisite like `jq`. SB asks for explicit permission at `/sb:init`, `/sb:update`, and session start. Consent is stored in `.silver-bullet.json`:

```json
"recommended_tools": {
  "agentmemory": {
    "enabled_by_user": null,
    "enforcement_suspended": false,
    "install_status": null,
    "install_failure_reason": null,
    "required_when_enabled": true
  }
}
```

| `enabled_by_user` | Behavior |
|-------------------|----------|
| `null` | Consent pending — SB prompts; no hook enforcement |
| `true` | Mandatory — hooks block substantive edits until CLI, server, MCP, and export root are ready |
| `false` | Opted out — no enforcement |

**Install failure after opt-in:** SB sets `enforcement_suspended: true` and preserves `enabled_by_user: true`. Hooks treat suspended agentmemory like opted-out until the next `/sb:init` or `/sb:update` retry succeeds.

## Local Setup

agentmemory requires Node.js 20+ and runs a local server (API `:3111`, viewer `:3113`).

### Step 1 — CLI package

```bash
npm install -g @agentmemory/agentmemory
agentmemory --version
```

### Step 2 — Server and config

```bash
mkdir -p ~/.agentmemory
# Write cost-minimized ~/.agentmemory/.env (see agentmemory-stack-setup.md)
nohup agentmemory > ~/.agentmemory/server.log 2>&1 &
curl -sf http://localhost:3111/agentmemory/health
```

Required env flags for Graphify synergy:

- `CLAUDE_MEMORY_BRIDGE=true`
- `OBSIDIAN_AUTO_EXPORT=true`
- `AGENTMEMORY_EXPORT_ROOT=./.agentmemory`

Restart the server after editing `.env` — agentmemory does not hot-reload config.

### synergy_max `.env` template (SB-managed block)

When stack optimization runs, SB merges this block into `~/.agentmemory/.env` (backup `.env.bak`, chmod 600):

```bash
AGENTMEMORY_INJECT_CONTEXT=true
AGENTMEMORY_AUTO_COMPRESS=false
CONSOLIDATION_ENABLED=false
OBSIDIAN_AUTO_EXPORT=true
CLAUDE_MEMORY_BRIDGE=true
AGENTMEMORY_EXPORT_ROOT=/absolute/path/to/project/.agentmemory
```

**launchd (macOS):** `com.agentmemory.server` with `KeepAlive` and absolute export root in plist env (see `SETUP_REPORT.md` deviations). **Bridge:** `com.agentmemory.bridge` watches `.agentmemory/` when `~/.agentmemory/bridge.py` exists. The bridge plist includes `GITLEAKS_PATH` and `PATH` so the second-line gitleaks scan runs reliably.

### gitleaks (required with bridge)

The bridge scans exports with regex first, then **gitleaks** as a second line (catches JWTs and other patterns the regex list deliberately skips). Install before or during stack optimization:

```bash
brew install gitleaks          # macOS
gitleaks version
# Linux: apt install gitleaks or GitHub releases — see docs/STACK-OPTIMIZATION.md
```

When agentmemory is opted in, `sb-optimize-stack.sh --apply` and `graphify-am-global-setup.sh --apply` attempt install, verify `which gitleaks`, and write `GITLEAKS_PATH` into `com.agentmemory.bridge` launchd env. Diagnostics warn when gitleaks is missing.

**Injection tradeoff:** `INJECT_CONTEXT=true` improves recall but increases token cost. Use future `cost_minimized` profile to disable.

See `docs/STACK-OPTIMIZATION.md`.

### Step 3 — Project export root

From the project root:

```bash
mkdir -p .agentmemory/memory .agentmemory/snapshots
```

Add the agentmemory managed block to `.gitignore` (see `docs/AGENTMEMORY.md` git section in setup runbook). SB init scaffolds this when the user opts in.

### Step 4 — Platform MCP wiring

SB uses one user-global agentmemory installation for every supported host. The host MCP files are syntax adapters only; they must reference the same `agentmemory` executable recorded in `~/.silver-bullet/five-tool-stack/instances.json` and invoke it as `agentmemory mcp`. The local API service remains shared at `http://localhost:3111`.

| Host | Pre-index | Post-index (MCP connect) | Artifact |
|------|-----------|--------------------------|----------|
| Claude Code | *(none)* | `agentmemory connect claude-code` | `~/.claude.json` |
| Codex | `codex plugin marketplace add rohitg00/agentmemory`; `codex plugin add agentmemory@agentmemory` | `agentmemory connect codex --with-hooks` | `~/.codex/config.toml` |
| OpenCode / Goose / Hermes | *(varies)* | See `platform_install_commands` in template | host config |


## Related Docs

- `docs/GRAPHIFY.md` — Graphify setup and query patterns (retrieval layer)
- `docs/code-intelligence-contract.md` — capability tiers and degradation rules
- `hooks/lib/agentmemory-gate.sh` — enforcement helpers

## MCP reload receipts

Graphify, agentmemory, and LeanCTX MCP registration is merged atomically with the other five-tool servers via `patch-mcp.py`; each supported host points at the same manifest-selected executables. After host config repair, SB does **not** claim any MCP server is live until the current session invokes expected MCP tools and passes attestation validation against the active reload receipt. Partial tool failures are accepted as liveness evidence but retain canonical `reload_required`. See `docs/STACK-OPTIMIZATION.md` and `scripts/reconcile-recommended-tools.sh --host-evidence-stdin`.
