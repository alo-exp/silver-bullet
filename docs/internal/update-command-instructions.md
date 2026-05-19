# `/plugin:update` Skill Implementation Guide

This document describes how to build the `/plugin:update` skill for Silver Bullet.
It generalises `/silver:update` to work with any installed Claude Code plugin.
Follow this guide exactly when implementing the skill.

---

## What the skill does

`/plugin:update` updates any plugin installed via Claude Code's plugin system. It:

1. Resolves which plugin to update (from argument or by prompting)
2. Reads the installed version from `${SB_RUNTIME_HOME_ROOT}/plugins/installed_plugins.json`
3. Resolves the GitHub repository URL from the plugin's own `package.json` in the cache
4. Fetches the latest release from GitHub
5. Compares versions; exits early if already up to date
6. Fetches the CHANGELOG and shows what changed
7. Asks the user to confirm
8. Clones the new release into the plugin cache
9. Updates the plugin registry entry

---

## Skill metadata

Place the file at `skills/plugin-update/SKILL.md` with this frontmatter:

```markdown
---
name: plugin:update
description: "Update any installed Claude Code plugin: check for a new release, show changelog, and install"
---
```

---

## Registry structure

The plugin registry is at `${SB_RUNTIME_HOME_ROOT}/plugins/installed_plugins.json`. Its shape:

```json
{
  "version": 2,
  "plugins": {
    "<plugin-name>@<registry-name>": [
      {
        "scope": "user",
        "installPath": "${SB_RUNTIME_HOME_ROOT}/plugins/cache/<registry-name>/<plugin-name>/<version>",
        "version": "1.2.3",
        "installedAt": "2026-01-01T00:00:00.000Z",
        "lastUpdated": "2026-01-01T00:00:00.000Z",
        "gitCommitSha": "<sha>"
      }
    ]
  }
}
```

Key facts:
- The registry key is `<plugin-name>@<registry-name>` (e.g. `silver-bullet@silver-bullet`).
- `installPath` encodes the pattern: `${SB_RUNTIME_HOME_ROOT}/plugins/cache/<registry-name>/<plugin-name>/<version>`.
- The new cache path for an update is the same pattern with the new version:
  `${SB_RUNTIME_HOME_ROOT}/plugins/cache/<registry-name>/<plugin-name>/<new-version>`.
- The `plugins` value is an array; always read/write `[0]` (the first and only entry).

---

## GitHub repo resolution

The installed plugin cache always contains a `package.json`. Read it to get the
source repository URL — do NOT hardcode URLs per plugin:

```bash
cat "<installPath>/package.json"
```

Extract the GitHub `<org>/<repo>` slug. The `repository` field can appear in several forms:

| Form | Example | How to parse |
|------|---------|-------------|
| Object with `url` | `{"url": "https://github.com/org/repo.git"}` | Strip `.git` suffix |
| Object with `url` (git+ prefix) | `{"url": "git+https://github.com/org/repo.git"}` | Strip `git+` and `.git` |
| Plain string URL | `"https://github.com/org/repo"` | Use as-is |
| GitHub shorthand | `"github:org/repo"` | Strip `github:` prefix |

In all cases, extract the `org/repo` portion after `github.com/` or after `github:`.
The resulting `<org>/<repo>` slug is used for all GitHub API and raw content calls.

If `package.json` is missing, `repository` is absent, or parsing produces no recognisable
GitHub slug, output an error and exit:
```
Cannot resolve repository URL for <plugin-name>.
Update manually: reinstall via Claude Desktop plugin manager.
```

---

## Step-by-step implementation

### Step 1 — Resolve the plugin to update

If the user provided a plugin name as an argument (e.g. `/plugin:update silver-bullet`),
use that name to find the matching registry key (find the key whose prefix before `@`
matches the argument).

If no argument was provided, list all installed plugins and use AskUserQuestion:
- Question: "Which plugin do you want to update?"
- Options: one option per registry key, showing `<plugin-name> (v<version>)`, plus "Cancel"

If the user selects Cancel, exit.

If the named plugin is not found in the registry, output:
```
Plugin "<name>" is not installed. Check the spelling or run /plugin list.
```
Then exit.

### Step 2 — Read installed version

From the matched registry entry extract:
- `version` — currently installed version string (e.g. `1.2.3`)
- `installPath` — absolute path to the cached plugin directory
- `scope` — preserve this value unchanged when writing back

Derive:
- `registryKey` — the full `<plugin-name>@<registry-name>` key
- `pluginName` — the part before `@`
- `registryName` — the part after `@`

Display:
```
## Plugin Update — <plugin-name>

Checking for updates...
**Installed:** v<version>
```

### Step 3 — Resolve GitHub repo from package.json

```bash
cat "<installPath>/package.json"
```

Parse `repository.url` and extract the `<org>/<repo>` slug as described above.

### Step 4 — Fetch the latest release from GitHub

```bash
curl -s https://api.github.com/repos/<org>/<repo>/releases/latest \
  | grep '"tag_name"' \
  | sed 's/.*"tag_name": *"v\([^"]*\)".*/\1/'
```

If the curl fails or returns empty, output:
```
Couldn't reach GitHub (offline or rate-limited).

To update manually: reinstall via Claude Desktop plugin manager
or clone from https://github.com/<org>/<repo>
```
Then exit.

### Step 5 — Compare versions

Parse both `installedVersion` and `latestVersion` as semver (MAJOR.MINOR.PATCH)
and compare numerically.

**If installed == latest:**
```
## Plugin Update — <plugin-name>

**Installed:** v<version>
**Latest:** v<version>

You're already on the latest version. ✓
```
Exit.

**If installed > latest (dev build):**
```
## Plugin Update — <plugin-name>

**Installed:** v<installed>
**Latest:** v<latest>

You're ahead of the latest release (development build). No action needed.
```
Exit.

### Step 6 — Fetch changelog and confirm

Fetch the CHANGELOG:
```bash
curl -s https://raw.githubusercontent.com/<org>/<repo>/main/CHANGELOG.md
```

Extract entries between the installed version and the latest version (inclusive of
latest, exclusive of installed). Show all intermediate versions if multiple releases
were skipped.

If the CHANGELOG fetch fails or the file does not exist, skip the changelog section
and proceed to confirmation without it.

Display:
```
## Update Available — <plugin-name>

**Installed:** v<installed>
**Latest:**    v<latest>

### What's New
────────────────────────────────────────────────────────────

<extracted changelog entries, or "(changelog unavailable)" if fetch failed>

────────────────────────────────────────────────────────────

⚠️  The update clones the new release into the plugin cache and updates the
plugin registry. Your project files are never touched — only the plugin cache
is updated.
```

Use AskUserQuestion:
- Question: `Proceed with updating <plugin-name> to v<latest>?`
- Options:
  - `"Yes, update now"` — proceed to install
  - `"No, cancel"` — exit without changes

If user cancels, exit.

### Step 7 — Clone the new release

Construct the new cache path by replacing the version segment in the existing
`installPath`. Expand `~` to the actual `$HOME` value — the registry stores and
expects absolute paths (e.g. `/Users/alice/...`), never `~`-prefixed paths:

```bash
NEW_CACHE="${SB_RUNTIME_HOME_ROOT}/plugins/cache/<registryName>/<pluginName>/<latestVersion>"
```

Clone:
```bash
git clone --depth 1 --branch v<latestVersion> \
  https://github.com/<org>/<repo>.git "$NEW_CACHE"
```

If the clone fails (non-zero exit code), output:
```
Clone failed. The registry was NOT modified.

Check your internet connection or verify that the tag v<latest> exists at
https://github.com/<org>/<repo>/releases
```
Then exit. **Never modify the registry if the clone failed.**

**Tag convention:** The clone assumes the release tag is `v<version>` (e.g. `v1.2.3`).
This is the standard convention for all Ālo Labs plugins. If a plugin uses a different
tag format, the clone will fail — surface the error message above and let the user
update manually.

Get the new commit SHA:
```bash
git -C "$NEW_CACHE" rev-parse HEAD
```

### Step 8 — Update the plugin registry

Read `${SB_RUNTIME_HOME_ROOT}/plugins/installed_plugins.json`. Update only the matching
`registryKey` entry at index `[0]`:

| Field | New value |
|-------|-----------|
| `version` | latest version string |
| `installPath` | `NEW_CACHE` (absolute path, `$HOME` expanded) |
| `lastUpdated` | current UTC ISO timestamp (`date -u +%Y-%m-%dT%H:%M:%S.000Z`) |
| `gitCommitSha` | SHA from Step 7 |

Preserve all other fields (`scope`, `installedAt`, etc.) unchanged.
Preserve all other registry entries unchanged.

Write the updated JSON back to `${SB_RUNTIME_HOME_ROOT}/plugins/installed_plugins.json`.

**Do NOT delete the old cache directory.** The old version remains at its original
`installPath` untouched. This allows manual rollback by reverting the registry entry.
Only the `installPath` pointer in the registry changes — no files are removed.

### Step 9 — Display result

```
╔═══════════════════════════════════════════════════════════╗
║  <plugin-name> updated: v<installed> → v<latest>          ║
╚═══════════════════════════════════════════════════════════╝

⚠️  Restart Claude Desktop to pick up the new skills and hooks.

Old cache: ${SB_RUNTIME_HOME_ROOT}/plugins/cache/<registryName>/<pluginName>/<installed>
New cache: ${SB_RUNTIME_HOME_ROOT}/plugins/cache/<registryName>/<pluginName>/<latest>

[View full changelog](https://github.com/<org>/<repo>/blob/main/CHANGELOG.md)
```

---

## Error handling summary

| Failure point | Behaviour |
|---------------|-----------|
| Plugin not in registry | Print error, exit |
| `package.json` missing or no `repository.url` | Print error, exit |
| GitHub API unreachable | Print offline message with manual instructions, exit |
| Changelog fetch fails | Skip changelog section, proceed to confirmation |
| `git clone` fails | Print error, exit — do NOT touch registry |
| User cancels at confirmation | Exit without changes |

---

## Differences from `/silver:update`

| Aspect | `/silver:update` | `/plugin:update` |
|--------|-----------------|-----------------|
| Target | Silver Bullet only | Any installed plugin |
| Repo URL | Hardcoded | Read from `<installPath>/package.json` |
| Registry key | Hardcoded `silver-bullet@silver-bullet` | Resolved from argument or user selection |
| Plugin discovery | N/A | Lists all keys from registry when no arg given |
| Cache path derivation | Hardcoded pattern | Derived from existing `installPath` + new version |

All other logic (version comparison, changelog extraction, clone mechanics,
registry write) is identical to `/silver:update`.

---

## Reference: `/silver:update` source

The canonical reference implementation lives at:
`skills/silver-update/SKILL.md` in the Silver Bullet repository.

When in doubt about edge-case behaviour, defer to that implementation.
