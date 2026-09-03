---
name: silver-doctor
description: This skill should be used when the user runs `/silver:doctor` or `/sb:doctor` (alias) or asks to audit whether the local Silver Bullet installation and project activation are correct for the active host — run before `/silver:init` update, after `/silver:update`, and during CI diagnostics.
aliases: [sb:doctor]
version: 0.2.0
---

# /silver:doctor — Install and Activation Audit

`/sb:doctor` is an alias of `/silver:doctor`. Both resolve to `scripts/sb-doctor.sh` and forward `--fix` / `--dry-run`. Do not implement a second doctor.

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

**D10 checks** use `scripts/reconcile-recommended-tools.sh` for Graphify, agentmemory, RTK, Context Mode, LeanCTX, Alumnium (when opted in), search_cli (when opted in), and cross-tool route/heartbeat convergence. Per-tool IDs: `D10-graphify`, `D10-agentmemory`, `D10-rtk`, `D10-context_mode`, `D10-leanctx`, `D10-alumnium`, `D10-search_cli`, `D10-routes`. When Alumnium or search_cli is not opted in (`enabled_by_user` null/false), the matching `D10-*` check is PASS N/A (pending/disabled) — the default tree must not FAIL solely because those keys are unset.

When a tool is opted in (`enabled_by_user`) on a supported host, default `sb-doctor` D10 verifies **installation and configuration** (not live MCP session tools). CONFIGURED (MCP key / hook line) is not LIVE (this-chat tools). PATH-only is not Health PASS.

#### D10 F4 coverage table

| tool | class | Setup | Health | Diagnosis | `--fix` action | N/A rule | host support | docs_pin |
|------|-------|-------|--------|-----------|----------------|----------|--------------|----------|
| graphify | five-tool (project+host) | CLI + `graphify-mcp`; Cursor MCP `graphify`; real `graphify-out` index. No invented `graphify doctor`. | CLI+MCP+index. Skill vs package skew is WARN (`skill_package_skew`); `--fix` none (operator `graphify install`). PATH-only is not Health. | `D10-graphify`, `missing_cli`, `skill_package_skew` | `--fix=local` index; `--fix=host` MCP. Skew: none | not opted in → PASS N/A | Cursor (MCP/hooks) | docs/GRAPHIFY.md |
| agentmemory | five-tool (project+host) | CLI; MCP `agentmemory` / `user-agentmemory`; export dir. | HTTP health of the **opted-in** instance (identity). Health URL alone without identity is WARN (`health_identity_unproven`). | `D10-agentmemory`, `missing_cli` | `--fix=host` MCP; start server; scaffold export | not opted in → PASS N/A | Cursor | docs/AGENTMEMORY.md |
| rtk | five-tool (host) | CLI; `min_version` 0.42.0; Cursor `rtk hook cursor`; RTK before Context Mode; no LeanCTX shell rewrite. | CLI+version+hook. `min_version` below pin is FAIL. Vendor skip (`vendor_skip`) is not Health; remaining checks decide. | `D10-rtk`, `missing_cli`, `min_version`, `vendor_skip` | `--fix=host` | not opted in → PASS N/A | Cursor hooks | docs/RTK.md |
| context_mode | five-tool (host) | Node `min_node_version` 22.5; CLI; MCP `context-mode` / `user-context-mode`; instruction fragment. No invented CLI `min_version` pin. | Node+CLI+MCP+vendor `CONTEXT_MODE_PLATFORM=cursor context-mode doctor` on default path. Node below pin → FAIL `min_version`/`node_version`. | `D10-context_mode`, `min_version`, `vendor_skip` | `--fix=host` | not opted in → PASS N/A | Cursor | docs/CONTEXT-MODE.md |
| leanctx | five-tool (host) | CLI; MCP `leanctx` (or `lean-ctx` / `user-leanctx`); `lctx_` prefix; overlap MCP off. Never `lean-ctx init --agent *`. `min_version` 3.9.9. | CLI+version+MCP. Duplicate `leanctx` and `lean-ctx` keys → D10 FAIL `duplicate_key` (D22 WARN does not downgrade D10). | `D10-leanctx`, `missing_cli`, `min_version`, `duplicate_key`, `vendor_skip` | `--fix=host` | not opted in → PASS N/A | Cursor | docs/LEANCTX.md |
| alumnium | extra-tool (host) | CLI `alumnium`; Cursor MCP `alumnium` / `user-alumnium` (`npx -y alumnium mcp`). | CLI+MCP. Vendor `alumnium doctor` if non-interactive. | `D10-alumnium`, `missing_cli`, `vendor_skip` | `--fix=host` | not opted in → PASS N/A | Cursor | docs/ALUMNIUM.md |
| search_cli | extra-tool (packages) | Registry-pinned Homebrew `paperfoot/tap/search-cli` 0.9.0. Never merge project `install_commands`. `required_when_enabled: false`. | PATH **plus** non-secret `search --version`. Provider-missing is WARN (`provider_missing`) on ready Health. | `D10-search_cli`, `missing_cli`, `provider_missing`, `version_drift`, `unsupported_package_manager` | `--fix=packages` upgrades older to pin; must not downgrade newer | `enabled_by_user` null/false → PASS N/A. Never FAIL; do not scaffold the key. | Cursor + Claude + Codex (not Cursor-only `rt_host_supported`) | https://github.com/paperfoot/search-cli/blob/v0.9.0/README.md@v0.9.0 (formula https://github.com/paperfoot/homebrew-tap/blob/main/Formula/search-cli.rb@0.9.0) |
| cross_tool / D10-routes | derived (host) | SB mutex + ten route owners + heartbeat. | `no_five_tool_consent` → **PASS** (not PASS N/A, not WARN). Unsupported host → WARN; do not recommend `--fix=host`. Other drift FAILs. | `D10-routes`, `no_five_tool_consent`, `unknown_key` | `--fix=host` only for repairable drift | no five-tool consent → PASS | Cursor only for convergence | docs/code-intelligence-contract.md@b0f961d |

Opted-in unknown JSON key → WARN `unknown_key` and doctor exit **nonzero**; other components are not FAIL-poisoned. Unknown component id → PASS N/A reason `unsupported`; no installer; no `--fix` suggestion.

Omni / OmniRoute is planned WS7, not D10 Graphify — footnote only, not an F4 schema row. Future ids (`busy`, `provider_expired`) belong there, not this table.

**CONFIGURED ≠ LIVE:** MCP keys in Cursor `mcp.json` and hook lines in Cursor `hooks.json` prove **configuration**, not that Cursor has loaded those MCP tools in **this chat**. `reload_required` means config was written but this session has not proven tool liveness. Do not treat bash `command -v` or a JSON key as live MCP. `--deep` Graphify stdio handshake is WARN only.

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
