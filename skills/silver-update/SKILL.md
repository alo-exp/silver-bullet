---
name: silver-update
description: This skill should be used when the user runs `/silver:update` or asks to update Silver Bullet — checks GitHub for the latest release, shows the changelog since the installed version, and installs the update after confirmation.
version: 0.1.0
---

# /silver:update — Update Silver Bullet

Check GitHub for the latest Silver Bullet release, display what changed since your installed version, and install the update.

## Process

### Step 1: Read installed version

Read `~/.claude/plugins/installed_plugins.json`. Try the `silver-bullet@alo-labs` key first; if absent, fall back to the `silver-bullet@silver-bullet` key (legacy installation):

- `version` — currently installed version (e.g. `0.24.1`)
- If neither key exists, treat installed version as `0.0.0`.

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

To update manually: reinstall via Claude Desktop plugin manager or clone from https://github.com/alo-exp/silver-bullet
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

⚠️  **Note:** The update installs the new release via the Claude CLI marketplace.
Your project files (CLAUDE.md, silver-bullet.md, hooks, config) are never
touched — only the plugin cache and registry are updated by the marketplace.
```

Use AskUserQuestion:
- Question: "Proceed with update to vA.B.C?"
- Options:
  - "A. Yes, update now" — install via marketplace and clean up stale entries
  - "B. No, cancel" — exit without changes

If user cancels, exit.

### Step 5: Install the update

Run the marketplace install command:

```bash
claude mcp install silver-bullet@alo-labs
```

If the command fails (non-zero exit code), display the error output and exit without proceeding to cleanup:

```
Update failed. The marketplace install did not complete successfully.
Please try again or install manually via the Claude Desktop plugin manager.
```

Do not modify the registry or attempt cleanup if the install step fails.

### Step 6: Update the plugin registry

Read `~/.claude/plugins/installed_plugins.json`, update the `silver-bullet@silver-bullet` entry:
- `version` → latest version string
- `installPath` → new cache path (absolute, with `$HOME` expanded)
- `lastUpdated` → current ISO timestamp
- `gitCommitSha` → SHA from step 5

Write the updated JSON back to `~/.claude/plugins/installed_plugins.json` **atomically** (tmpfile + `mv`) to avoid registry corruption on mid-write crash:

```bash
REG="$HOME/.claude/plugins/installed_plugins.json"
TMP="$(mktemp "${REG}.XXXXXX")"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
jq --arg v "$LATEST" \
   --arg p "$NEW_CACHE" \
   --arg t "$NOW" \
   --arg sha "$COMMIT_SHA" \
   '."silver-bullet@silver-bullet" |= (.version = $v | .installPath = $p | .lastUpdated = $t | .gitCommitSha = $sha)' \
   "$REG" > "$TMP" && mv "$TMP" "$REG"
```

### Step 7: Display result

```
╔═══════════════════════════════════════════════════════════╗
║  Silver Bullet Updated: vX.Y.Z → vA.B.C                   ║
╚═══════════════════════════════════════════════════════════╝

⚠️  Restart Claude Desktop to pick up the new skills and hooks.

Old cache kept at: ~/.claude/plugins/cache/silver-bullet/silver-bullet/X.Y.Z
New cache at:      ~/.claude/plugins/cache/silver-bullet/silver-bullet/A.B.C

[View full changelog](https://github.com/alo-exp/silver-bullet/blob/main/CHANGELOG.md)
```
