---
name: silver-update
description: "Check for Silver Bullet updates, show changelog, and install if available"
version: 0.1.0
---

# /silver:update — Update Silver Bullet

Check GitHub for the latest Silver Bullet release, display what changed since your installed version, and install the update.

## Process

### Step 1: Read installed version

Read `~/.claude/plugins/installed_plugins.json` and extract the `silver-bullet@silver-bullet` entry:
- `version` — currently installed version (e.g. `0.12.0`)
- `installPath` — cache path (e.g. `~/.claude/plugins/cache/silver-bullet/silver-bullet/0.12.0`)

If the entry is missing, treat installed version as `0.0.0` and installPath as unknown.

Display:
```
## Silver Bullet Update

Checking for updates...
**Installed:** vX.Y.Z
```

### Step 2: Check latest version from GitHub

```bash
curl -s https://api.github.com/repos/alo-exp/silver-bullet/releases/latest | grep '"tag_name"' | sed 's/.*"tag_name": *"v\([^"]*\)".*/\1/'
```

If the curl fails or returns empty, output:
```
Couldn't check for updates (offline or GitHub unavailable).

To update manually: reinstall via Claude Desktop plugin manager or clone from https://github.com/alo-exp/silver-bullet
```
Then exit.

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

⚠️  **Note:** The update clones the new release into the plugin cache and
updates the plugin registry. Your project files (CLAUDE.md, silver-bullet.md,
hooks, config) are never touched — only the plugin cache is updated.
```

Use AskUserQuestion:
- Question: "Proceed with update to vA.B.C?"
- Options:
  - "A. Yes, update now" — clone new version and update registry
  - "B. No, cancel" — exit without changes

If user cancels, exit.

### Step 5: Install the update

Determine new cache path:
```
NEW_CACHE=~/.claude/plugins/cache/silver-bullet/silver-bullet/<latest-version>
```

Clone the new release:
```bash
git clone --depth 1 --branch v<latest-version> https://github.com/alo-exp/silver-bullet.git "$NEW_CACHE"
```

If clone fails, show error and exit without modifying the registry.

Get the commit SHA:
```bash
git -C "$NEW_CACHE" rev-parse HEAD
```

Display the SHA to the user before proceeding:
```
⚠️  Security check: Silver Bullet v<latest-version> cloned at commit SHA:
    <commit-sha>

Note: This release tag is not cryptographically signed. Verify this SHA
matches the expected commit at https://github.com/alo-exp/silver-bullet/releases
if you have any security concerns.
```

Use AskUserQuestion:
- Question: "Proceed with installing v<latest-version> at commit <short-sha>?"
- Options: "A. Yes, install" / "B. Cancel"

If user cancels, remove `$NEW_CACHE` safely (only if the path is non-empty and contained within `~/.claude/plugins/cache/`) and exit without modifying the registry.

### Step 6: Update the plugin registry

Read `~/.claude/plugins/installed_plugins.json`, update the `silver-bullet@silver-bullet` entry:
- `version` → latest version string
- `installPath` → new cache path (absolute, with `$HOME` expanded)
- `lastUpdated` → current ISO timestamp
- `gitCommitSha` → SHA from step 5

Write the updated JSON back to `~/.claude/plugins/installed_plugins.json`.

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
