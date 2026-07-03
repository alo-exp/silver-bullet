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
- When task host may have an imported primary host-native SB install (contamination check)

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

```bash
bash scripts/sb-doctor.sh --fix
```

| Check | Typical fix |
|-------|-------------|
| D2/D3 plugin stale | `/silver:update` or `bash scripts/install-${SILVER_BULLET_RUNTIME}.sh` (task host) |
| D4 hooks missing | `bash scripts/install-${SILVER_BULLET_RUNTIME}.sh --merge-hooks-only` or `/silver:init` update §3.7.5 |
| D6 config stale | `bash scripts/sb-migrate-config.sh` or `/silver:migrate` |
| D7 template drift | Refresh `silver-bullet.md` from template; run parity test |
| D8 orchestrator rule | task host only: `bash scripts/sb-migrate-orchestrator-parent.sh` |
| D13 manifest paths | Host install script for active runtime |
| D14 cache bleed | `bash scripts/install-{primary host,Codex,task host}.sh` or `sb-doctor.sh --fix` |
| D15 token budget | Shorten primary host `description` frontmatter in `agents/primary host/` |
| D16 repo layout bleed | `bash scripts/validate-host-install-surface.sh`; fix via host install |
| D17 core host bleed | `bash scripts/validate-host-agnostic-core.sh`; move host refs to `scripts/lib/install-*/` |

Log friction in `$HOME/.codex/.silver-bullet/sb-friction-log.md` when doctor surfaces hook or install issues.

### Step 4: Re-run until PASS

```bash
bash scripts/sb-doctor.sh && echo "doctor PASS"
```

## Check catalog (D1–D17)

- D1 `jq` on PATH
- D2 plugin registry version ≥ project template `config_version`
- D3 plugin cache `current` symlink + hooks manifest
- D4 host hooks manifest (task host `hooks.json`, Codex `config.toml`, primary host `settings.json`)
- D5 project activation (`sb_initiated: true`)
- D6 `config_version` freshness
- D7 template parity test
- D8 task host orchestrator rule (**task host host only**)
- D9 workflow tracker
- D10 recommended tools when opted in
- D11 hook smoke
- D12 `$HOME/.codex/.silver-bullet` writable
- D13 cross-host manifest paths + expected cache bundle
- D14 foreign agent namespaces in plugin cache
- D15 primary host agent description token budget
- D16 repo install surface (`validate-host-install-surface.sh`)
- D17 host-agnostic SB core (`validate-host-agnostic-core.sh`)

```bash
bash scripts/validate-host-install-surface.sh
bash scripts/validate-host-agnostic-core.sh
bash scripts/sb-doctor.sh --fix
```

## Tests

```bash
bash tests/scripts/test-silver-doctor.sh
```
