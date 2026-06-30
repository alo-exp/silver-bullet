---
name: "silver:doctor"
title: "Doctor"
description: "This skill should be used when the user runs `/silver:doctor` or asks to audit whether the local Silver Bullet installation and project activation are correct for the active host — run before `/silver:init` update, after `/silver:update`, and during CI diagnostics."
version: 0.1.0
---

# /silver:doctor — Install and Activation Audit

Audits whether local SB installation is correct for the active host and whether the current project is on the current enforcement surface.

## When to Use

- Before Wave 1+ implementation work or after `/silver:update`
- When hooks appear inactive or plugin version is stale
- After migrating a project with `/silver:migrate` + `/silver:init` update mode
- When Cursor may have an imported Claude-native SB install (contamination check)

## Process

### Step 1: Run the doctor script

From the project root (or pass an explicit path):

```bash
bash scripts/sb-doctor.sh
# or from plugin install:
bash "${PLUGIN_ROOT}/scripts/sb-doctor.sh" "$(pwd)"
```

JSON output (for automation):

```bash
SB_DOCTOR_FORMAT=json bash scripts/sb-doctor.sh
```

### Step 2: Interpret results

| Level | Meaning |
|-------|---------|
| **PASS** | Check satisfied |
| **WARN** | Non-blocking; remediation listed |
| **FAIL** | Must fix before relying on SB enforcement |

**Overall PASS** requires zero FAIL lines. WARN is allowed.

### Step 3: Fix FAILs inline

| Check | Typical fix |
|-------|-------------|
| D2/D3 plugin stale | `/silver:update` or `bash scripts/install-cursor.sh` (Cursor) |
| D4 hooks missing | `bash scripts/install-cursor.sh --merge-hooks-only` or `/silver:init` update §3.7.5 |
| D6 config stale | `bash scripts/sb-migrate-config.sh` or `/silver:migrate` |
| D7 template drift | Refresh `silver-bullet.md` from template; run parity test |
| D8 orchestrator rule | Cursor only: `bash scripts/sb-migrate-orchestrator-parent.sh` |
| D13 cross-host import | Cursor: purge `.codex/plugins` from hooks; Claude/Codex: reinstall native host plugin |

Log friction in `$HOME/.codex/.silver-bullet/sb-friction-log.md` when doctor surfaces hook or install issues.

### Step 4: Re-run until PASS

```bash
bash scripts/sb-doctor.sh && echo "doctor PASS"
```

## Check catalog (D1–D13)

See plan Section B and `scripts/sb-doctor.sh` for the authoritative check list:

- D1 `jq` on PATH
- D2 plugin registry version ≥ project template `config_version`
- D3 plugin cache `current` symlink + hooks manifest
- D4 host hooks manifest (Cursor `hooks.json`, Codex `config.toml`, Claude `settings.json`)
- D5 project activation (`sb_initiated: true`)
- D6 `config_version` freshness
- D7 template parity test
- D8 Cursor orchestrator rule (**Cursor host only** — N/A on Claude/Codex)
- D9 workflow tracker (`scripts/workflows.sh`, `docs/workflows/`)
- D10 recommended tools when `enabled_by_user: true`
- D11 hook smoke (`session-start`, `outcomes-check`, `stop-check`)
- D12 `$HOME/.codex/.silver-bullet` writable
- D13 cross-host plugin contamination (host-scoped manifest + `agents/<host>/` in active cache)

Host detection uses `hooks/lib/runtime-paths.sh` (`SILVER_BULLET_RUNTIME`, plugin root env vars) — **not** presence of other hosts' config files on disk.

## Tests

```bash
bash tests/scripts/test-silver-doctor.sh
```
