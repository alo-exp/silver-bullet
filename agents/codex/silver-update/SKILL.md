---
name: "silver:update"
title: "Update"
description: "This skill should be used when the user runs `/silver:update` or asks to update Silver Bullet — checks GitHub for the latest release, shows the changelog since the installed version, and installs the update after confirmation."
version: 0.1.0
---

# /silver:update — Update Silver Bullet

Check GitHub for the latest Silver Bullet release, display what changed since your installed version, and install the update.

## Process

### Step 1: Read installed version

Read `$HOME/.codex/plugins/installed_plugins.json`. Try these keys in order:

- `silver-bullet@alo-labs` (Claude / Cursor marketplace)
- `silver-bullet@alo-labs-codex` (Codex marketplace)
- `silver-bullet@silver-bullet` (legacy installation)

Use the first key that exists; read its `version` field (e.g. `0.24.1`). If none exist, treat installed version as `0.0.0`.

Display:
```
## Silver Bullet Update

Checking for updates...
**Installed:** vX.Y.Z
```

### Step 2: Check latest version from GitHub

```bash
curl -fsSL https://api.github.com/repos/alo-exp/silver-bullet/releases/latest \
  | jq -r '.tag_name' | sed 's/^v//'
```

If the curl fails or returns empty, output:
```
Couldn't check for updates (offline or GitHub unavailable).

To update manually: reinstall via the active host's plugin manager or package refresh path, or clone from https://github.com/alo-exp/silver-bullet
```
Then exit.

**Validate the version string before proceeding.** After extracting `$LATEST`, verify it is a valid semver (`MAJOR.MINOR.PATCH` — digits only, no pre-release suffix):

```bash
if [[ -z "$LATEST" ]] || ! [[ "$LATEST" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "GitHub returned an unexpected version string: '${LATEST:-<empty>}'"
  echo "Expected semver format (e.g. 0.23.6). Aborting to prevent path/ref corruption."
  exit
fi
```

If validation fails, output the message above and exit. Do not proceed — passing a malformed version string to the marketplace install command can cause an incorrect or failed install.

### Step 3: Compare versions

Parse both as semver (MAJOR.MINOR.PATCH) and compare numerically.

**If installed == latest:**
```
## Silver Bullet Update

**Installed:** vX.Y.Z
**Latest:** vX.Y.Z

You're already on the latest version.
```
Exit.

**If installed > latest (dev build):**
```
## Silver Bullet Update

**Installed:** vX.Y.Z
**Latest:** vA.B.C

You're ahead of the latest release (development build).
```
Exit.

### Step 4: Fetch changelog and confirm

Fetch the changelog:
```bash
curl -s https://raw.githubusercontent.com/alo-exp/silver-bullet/main/CHANGELOG.md
```

Extract entries between the installed version and the latest version (inclusive of latest, exclusive of installed). Show all intermediate versions.

Display:
```
## Silver Bullet Update Available

**Installed:** vX.Y.Z
**Latest:** vA.B.C

### What's New
────────────────────────────────────────────────────────────

[extracted changelog entries]

────────────────────────────────────────────────────────────

⚠️  **Note:** The update installs the new release via the active host's marketplace or package manager.
On Codex, use the repo's Codex package refresh path instead of the Claude marketplace command.
Your project files (project instruction file, silver-bullet.md, hooks, config) are never
touched — only the active host's plugin cache and registry are updated.
```

Ask the user directly:
- Question: "Proceed with update to vA.B.C?"
- Options:
  - "A. Yes, update now" — install via marketplace and clean up stale entries
  - "B. No, cancel" — exit without changes

If user cancels, exit.

### Step 5: Install the update

Run the host-appropriate install command. Silver Bullet is a **plugin**, not an MCP server — install it through the host's plugin manager:

```bash
# Claude Code / Cursor (plugin host): run inside the agent, not the shell
/plugin install alo-exp/silver-bullet
# Codex host: ./scripts/install-codex.sh --purge-legacy-skills
```

If the command fails (non-zero exit code), display the error output and exit without proceeding to cleanup:

```
Update failed. The host install did not complete successfully.
Please try again or install manually via the active host's plugin manager or package refresh path.
```

Do not modify the registry or attempt cleanup if the install step fails.

### Step 6: Remove stale legacy entries

After the marketplace install succeeds, clean up any residual legacy installations.

**6a. Remove stale registry entry:**

Check whether `installed_plugins.json` contains the legacy `silver-bullet@silver-bullet` key. If it does, remove it atomically:

```bash
REG="$HOME/.codex/plugins/installed_plugins.json"
if jq -e '.plugins["silver-bullet@silver-bullet"]' "$REG" > /dev/null 2>&1; then
  TMP="$(mktemp "${REG}.XXXXXX")"
  jq 'del(.plugins["silver-bullet@silver-bullet"])' "$REG" > "$TMP" && mv "$TMP" "$REG"
fi
```

**6b. Remove stale cache directory:**

Check whether `$HOME/.codex/plugins/cache/silver-bullet/silver-bullet/` exists. If it does, remove it:

```bash
if [[ -z "$HOME" ]]; then
  echo "WARNING: HOME is unset — skipping stale cache cleanup."
else
  STALE_CACHE="$HOME/.codex/plugins/cache/silver-bullet/silver-bullet"
  if [[ -d "$STALE_CACHE" && ! -L "$STALE_CACHE" && "$STALE_CACHE" == "${HOME}/"* ]]; then
    rm -rf "$STALE_CACHE"
  fi
fi
```

Do NOT remove `$HOME/.codex/plugins/cache/silver-bullet/alo-labs/` — that is the newly installed version.

If either cleanup step fails, log the error but do not abort — the install already succeeded.

### Step 7: Display result

```
╔═══════════════════════════════════════════════════════════╗
║  Silver Bullet Updated: vX.Y.Z → vA.B.C                   ║
╚═══════════════════════════════════════════════════════════╝

Installed via the active host's package manager / marketplace (silver-bullet@alo-labs).

⚠️  Restart the host coding agent to pick up the new skills and hooks.

[View full changelog](https://github.com/alo-exp/silver-bullet/blob/main/CHANGELOG.md)
```

### Step 8: Recommended-tools consent and install retry (project-level)

After the plugin update succeeds, check the **project's** `.silver-bullet.json` (if present)
for Graphify consent and suspension state. This mirrors Phase 1.1a of `/silver:init`.

```bash
test -f .silver-bullet.json && jq -r '.recommended_tools.graphify.enabled_by_user // "null"' .silver-bullet.json
test -f .silver-bullet.json && jq -r '.recommended_tools.graphify.enforcement_suspended // false' .silver-bullet.json
```

**If `enabled_by_user` is `null` (consent pending):** run the same AskQuestion consent flow
as fresh init — present benefits, ask Yes/No, write choice to `.silver-bullet.json`.

**If `enabled_by_user` is `true` AND `enforcement_suspended` is `true`:** retry Graphify install
without re-asking. Detect host the same way as `/silver:init` Phase 1.1a Step 3 (`SB_HOST` =
`claude`, `codex`, or `cursor` via `SILVER_BULLET_RUNTIME`, `CURSOR_PLUGIN_ROOT`, or Codex env vars).

1. `uv tool install graphifyy` or `pipx install graphifyy`
2. Pre-index skill registration (upstream Install Step 2):
   - **Claude:** `graphify install --project`
   - **Codex:** `graphify install --project --platform codex`
   - **Cursor:** skip
3. `graphify update . --no-cluster`
4. Post-index always-on (upstream "Make your assistant always use the graph"):
   - **Claude:** `graphify claude install --project`
   - **Codex:** `graphify codex install --project`
   - **Cursor:** `graphify cursor install`

Read `recommended_tools.graphify.platform_install_commands.<host>.pre_index` / `.post_index` from `.silver-bullet.json` when present.

On success, clear suspension:
```bash
jq '.recommended_tools.graphify.enforcement_suspended = false
  | .recommended_tools.graphify.install_status = "ok"
  | .recommended_tools.graphify.install_failure_reason = null' .silver-bullet.json
```

On failure, keep suspension and update `install_failure_reason`. Do not block the update.

**If `enabled_by_user` is `false`:** no action needed.
