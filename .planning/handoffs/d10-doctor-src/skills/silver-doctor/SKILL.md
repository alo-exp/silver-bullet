---
name: silver-doctor
description: This skill should be used when the user runs `/silver:doctor` or asks to audit whether the local Silver Bullet installation and project activation are correct for the active host — run before `/silver:init` update, after `/silver:update`, and during CI diagnostics.
version: 0.2.0
---

# /silver:doctor — Install and Activation Audit

Audits whether local SB installation is correct for the active host and whether the current project is on the current enforcement surface. **Default and `--deep` are read-only.** Repair requires `--fix=SCOPE`.

## When to Use

- Before Wave 1+ implementation work or after `/silver:update`
- When hooks appear inactive or plugin version is stale
- After migrating a project with `/silver:migrate` + `/silver:init` update mode
- When five-tool stack reports drift, missing Graphify index, or MCP reload pending

## Process

### Step 1: Run the doctor script

From the project root (or pass an explicit path):

```bash
bash scripts/sb-doctor.sh
bash scripts/sb-doctor.sh --deep          # adds bounded expensive probes (Graphify MCP stdio handshake as WARN)
bash scripts/sb-doctor.sh --dry-run       # reconciler plan only — no writes
bash scripts/sb-doctor.sh --fix=local     # project-scope repair via reconciler doctor-fix
bash scripts/sb-doctor.sh --fix=host      # host hooks/MCP/routes
bash scripts/sb-doctor.sh --fix=packages  # package installs only
bash scripts/sb-doctor.sh --fix           # same as --fix=all
```

JSON output (schema 2.0.0 — includes full reconciler component evidence):

```bash
SB_DOCTOR_FORMAT=json bash scripts/sb-doctor.sh
```

### Step 2: Interpret results

| Level | Meaning |
|-------|---------|
| **PASS** | Check satisfied |
| **WARN** | Non-blocking; remediation listed (`reload_required`, suspended opt-in) |
| **FAIL** | Must fix before relying on SB enforcement |

**Overall PASS** requires zero FAIL lines. WARN is allowed.

**D10 checks** use `scripts/reconcile-recommended-tools.sh` for Graphify, agentmemory, RTK, Context Mode, LeanCTX, Alumnium (when opted in), and cross-tool route/heartbeat convergence. Per-tool IDs: `D10-graphify`, `D10-agentmemory`, `D10-rtk`, `D10-context_mode`, `D10-leanctx`, `D10-alumnium`, `D10-routes`. When Alumnium is not opted in (`enabled_by_user` null/false), `D10-alumnium` is PASS N/A (pending/disabled) — the default tree must not FAIL solely because Alumnium is unset.

When a tool is opted in (`enabled_by_user`) on a supported host (Cursor), default `sb-doctor` D10 verifies **installation and configuration** (not live MCP session tools):

| Tool | Default D10 coverage |
|------|----------------------|
| Graphify | CLI on PATH; `graphify-mcp` binary; `~/.cursor/mcp.json` server `graphify`; real `graphify-out` index when the project has a graph. No invented `graphify doctor`. `--deep`: stdio handshake as WARN. |
| agentmemory | CLI; HTTP health `localhost:3111`; MCP `agentmemory` / `user-agentmemory`; export dir when contracted. |
| RTK | CLI; min version; `~/.cursor/hooks.json` has `rtk hook cursor`; RTK before Context Mode on preToolUse; no LeanCTX shell rewrite when RTK owns `sb_shell`. Vendor `rtk doctor` if that subcommand exists and is non-interactive (timeout-bounded); otherwise hook/CLI probes stand. |
| Context Mode | Node min; CLI; MCP `context-mode` / `user-context-mode`; instruction fragment; **`CONTEXT_MODE_PLATFORM=cursor context-mode doctor` on the default D10 path** (timeout-bounded). Vendor doctor failure → `D10-context_mode` FAIL when opted in. |
| LeanCTX | CLI; MCP key `leanctx` (or `lean-ctx` / `user-leanctx`); `LEANCTX_MCP_TOOL_PREFIX=lctx_`; overlap MCP off (`LEANCTX_DISABLE_{SHELL,SANDBOX,FETCH}_MCP`, `LEANCTX_DISABLE_FTS=1`) when five_tool_routed. Duplicate `leanctx` **and** `lean-ctx` keys → D10 config FAIL when opted in (D22 remains a catalog WARN). Vendor `lean-ctx doctor` if non-interactive. Never `lean-ctx init --agent *`. |
| Alumnium | When opted in: CLI `alumnium` on PATH; Cursor MCP `alumnium` / `user-alumnium` in `~/.cursor/mcp.json` (`npx -y alumnium mcp` per `docs/ALUMNIUM.md`). Vendor `alumnium doctor` if that subcommand exists and is non-interactive (timeout-bounded, stdin closed). No invented provider-key checks. Not opted in → PASS N/A. |
| five_tool_routed | Exclusive owners, RTK shell, no double rewrite, RTK-before-CM. |

**D10-routes WARN (not FAIL)** when no five-tool consent is active (`consent != enabled` on all five tools) and `cross_tool` is `repairable` solely because of `heartbeat_absent_or_invalid` — routes/heartbeat are N/A until opt-in. Any other `cross_tool` evidence (hook order, route drift, shell rewrite) still FAILs.

**CONFIGURED ≠ LIVE:** MCP keys in `~/.cursor/mcp.json` and hook lines in `~/.cursor/hooks.json` prove **configuration**, not that Cursor has loaded those MCP tools in **this chat**. `reload_required` means config was written but this session has not proven tool liveness. Do not treat bash `command -v` or a JSON key as live MCP. Phase C adds receipt verification; until then, toggle MCP or start a new chat after repair.

### Step 3: Fix FAILs inline

```bash
bash scripts/sb-doctor.sh --fix=local    # project index, export roots, consent-scoped repairs
bash scripts/sb-doctor.sh --fix=host     # hooks, MCP merge, route ownership
bash scripts/sb-doctor.sh --fix=all      # bounded dependency-ordered convergence
```

| Check | Typical fix |
|-------|-------------|
| D2/D3 plugin stale | `/silver:update` or `bash scripts/install-${SILVER_BULLET_RUNTIME}.sh` |
| D4 hooks missing | `bash scripts/install-cursor.sh --merge-hooks-only` or `/silver:init` update §3.7.5 |
| D6 config stale | `bash scripts/sb-migrate-config.sh` or `/silver:migrate` |
| D10-* five-tool | `bash scripts/sb-doctor.sh --fix=local|host|packages|all` |
| D10-routes drift | `--fix=host` or `bash scripts/optimize-five-tool-stack.sh --host cursor --project-root "$(pwd)"` |
| D13 manifest paths | Host install script for active runtime |
| D20 stack mutex | `--fix` clears mutex + scaffolds agentmemory export root |
| D22 duplicate LeanCTX MCP | WARN — `RT_PATCH_LEANCTX=1 python3 scripts/lib/global-toolstack/patch-mcp.py` |

Log friction in `${SB_RUNTIME_STATE_DIR}/sb-friction-log.md` when doctor surfaces hook or install issues.

### Step 4: Re-run until PASS

```bash
bash scripts/sb-doctor.sh && echo "doctor PASS"
```

## Check catalog (D1–D22 + D10-*)

- D1 `jq` on PATH
- D2 plugin registry version ≥ project template `config_version`
- D3 plugin cache `current` symlink + hooks manifest
- D4 host hooks manifest
- D5 project activation (`sb_initiated: true`)
- D6 `config_version` freshness
- D7 template parity test
- D8 Cursor orchestrator rule (Cursor host only)
- D9 workflow tracker
- **D10-*** reconciler results (five-tool stack + Alumnium when opted in + D10-routes + optional D10-deep-*)
- D11 hook smoke
- D12 `${SB_RUNTIME_STATE_DIR}` writable
- D13 cross-host manifest paths + expected cache bundle
- D14 foreign agent namespaces in plugin cache
- D15 Claude agent description token budget (Claude only)
- D16 repo install surface
- D17 host-agnostic SB core
- D18–D19 Cursor marketplace gitPath + command stubs
- D20 stack compression mutex
- D21 Cursor SB custom subagents
- D22 duplicate LeanCTX MCP servers

```bash
bash scripts/validate-host-install-surface.sh
bash scripts/validate-host-agnostic-core.sh
bash scripts/sb-doctor.sh --dry-run
bash scripts/sb-doctor.sh --fix=all
```

## Tests

```bash
bash tests/scripts/test-silver-doctor.sh
```
