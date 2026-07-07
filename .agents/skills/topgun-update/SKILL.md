---
name: topgun-update
description: >
  Updates the local TopGun installation to the latest release from GitHub.
  Invoke when the user says "update topgun", "upgrade topgun", "topgun update",
  "check for topgun updates", or "/topgun-update". Checks the installed version
  against the latest GitHub release, displays the changelog delta, verifies the
  commit SHA, and installs the update using the same mechanism as the official
  Codex plugin system.
argument-hint: [--check]
allowed-tools: [Read, Write, Bash]
---

# /topgun-update — Update TopGun

Updates the local TopGun installation to the latest release.

**`--check` flag:** Check version and STOP — do not prompt or update.

---

## Step 1: Prerequisites and Plugin Lookup

```bash
command -v jq  >/dev/null 2>&1 || { echo "❌ jq required: brew install jq / sudo apt install jq"; exit 1; }
command -v git >/dev/null 2>&1 || { echo "❌ git is required but not found."; exit 1; }
```

Locate the TopGun entry in the plugin registry:

```bash
REGISTRY_FILE="${HOME}/.codex/plugins/installed_plugins.json"
TOPGUN_KEY="$(jq -r '
  if .plugins["topgun@alo-labs-codex"] then "topgun@alo-labs-codex"
  elif .plugins["topgun@alo-labs"] then "topgun@alo-labs"
  elif .plugins["topgun@alo-labs-codex-local"] then "topgun@alo-labs-codex-local"
  else empty end
' "$REGISTRY_FILE" 2>/dev/null)"
if [ -n "$TOPGUN_KEY" ]; then
  jq -r --arg k "$TOPGUN_KEY" '.plugins[$k][0] | "\($k)\t\(.version // "unknown")\t\(.installPath // "")"' \
    "$REGISTRY_FILE"
fi
```

Extract `TOPGUN_KEY`, `INSTALLED_VERSION`, `INSTALL_PATH` from the tab-separated output. If the key resolves to a legacy alias, continue the update, but Step 6.2 will rewrite the registry entry to the canonical `topgun@alo-labs-codex` id and delete the stale alias. If no registry row is present because a clean uninstall already removed it, set `REINSTALL_MODE=1`, treat `INSTALLED_VERSION` as `0.0.0`, and continue — Step 5 will bootstrap the local snapshot before the normal install flow repopulates the live mirrors.

Display: `━━━ TOPGUN ► UPDATE ━━━  |  Installed: v{INSTALLED_VERSION}` (use `0.0.0` when bootstrapping a clean reinstall)

**If not found** (`TOPGUN_KEY` empty):
- Continue with the clean reinstall bootstrap path.
- Do not stop early just because the registry row is gone; the local snapshot fallback in Step 5 is now the source of truth.

---

## Step 2: Check Latest Version from GitHub

```bash
curl -s -m 30 https://api.github.com/repos/alo-labs/topgun/releases/latest \
  | jq -r '.tag_name // empty' | sed 's/^v//'
```

Capture as `LATEST_VERSION`. On failure or empty result:
```
⚠️  Could not reach GitHub (offline or rate-limited).
    Update via: codex plugin marketplace add https://github.com/alo-labs/codex-plugins.git
```
STOP.

---

## Step 3: Compare Versions

Execute this canonical semver function verbatim:

```bash
semver_gt() {
  local IFS=.
  read -r -a va <<< "$1"; read -r -a vb <<< "$2"
  for i in 0 1 2; do
    local ai="${va[$i]:-0}" bi="${vb[$i]:-0}"
    if (( ai > bi )); then return 0; fi
    if (( ai < bi )); then return 1; fi
  done; return 1
}
```

| Condition | Output | Action |
|-----------|--------|--------|
| `INSTALLED == LATEST` | `✓ Already on v{X.Y.Z} — latest.` | STOP |
| `semver_gt "$INSTALLED" "$LATEST"` | `Dev build v{X.Y.Z} ahead of latest v{A.B.C}.` | STOP |
| `--check` flag AND update available | `Update available: v{X.Y.Z} → v{A.B.C}. Run /topgun-update to install.` | STOP |

If `REINSTALL_MODE=1`, do not short-circuit on `INSTALLED == LATEST`; continue through the reinstall path so the cache tree, current alias, and registry row are rebuilt explicitly from the local snapshot.

---

## Step 4: Fetch Changelog and Confirm

```bash
curl -s -m 10 "https://raw.githubusercontent.com/alo-labs/topgun/refs/tags/v${LATEST_VERSION}/docs/CHANGELOG.md"
```

Extract entries newer than `INSTALLED_VERSION`. On failure: "Could not fetch changelog — proceeding."

Display:
```
━━━ TOPGUN ► UPDATE AVAILABLE ━━━
 Installed: v{X.Y.Z}   Latest: v{A.B.C}
 What's New
 ──────────────────────────────────
 {changelog entries}
 ──────────────────────────────────
 ⚠️  Clones new release into plugin cache; updates registry.
     ~/.topgun/ state, audit cache, and keychain tokens are preserved.
 💡 Official alternative: codex plugin marketplace add https://github.com/alo-labs/codex-plugins.git
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Ask: `Proceed with update to v{LATEST_VERSION}? A. Yes  B. No (cancel)` → B: STOP.

---

## Step 5: Clone the New Release

**5.1 Derive cache path:**

```bash
CACHE_ROOT=$(echo "$INSTALL_PATH" | sed "s|/topgun/[^/]*$||")
CACHE_ROOT="${CACHE_ROOT/.Codex/.codex}"
if [[ -z "$CACHE_ROOT" || "$CACHE_ROOT" == "$INSTALL_PATH" ]]; then
  CACHE_ROOT="$HOME/.codex/plugins/cache/alo-labs-codex"
fi
TOPGUN_CACHE_DIR="${CACHE_ROOT}/topgun"
CURRENT_ALIAS="${TOPGUN_CACHE_DIR}/current"
NEW_CACHE="${TOPGUN_CACHE_DIR}/${LATEST_VERSION}"
[[ "$NEW_CACHE" == "$HOME/.codex/plugins/cache/"* ]] \
  || { echo "❌ Derived path outside expected prefix: $NEW_CACHE"; exit 1; }
```

**5.2 Bootstrap missing cache tree from the local snapshot:**

If the clean reinstall removed the versioned cache tree, recreate it from the
local snapshot before any host-managed refresh step runs.

```bash
SOURCE_SNAPSHOT="${CODEX_PLUGIN_ROOT:-$INSTALL_PATH}"
[[ -d "$SOURCE_SNAPSHOT" ]] \
  || { echo "❌ No local snapshot available to bootstrap the cache tree."; exit 1; }
if [[ ! -d "$NEW_CACHE" ]]; then
  mkdir -p "$NEW_CACHE"
  rsync -a --delete "${SOURCE_SNAPSHOT%/}/" "${NEW_CACHE}/"
fi
```

**5.3 Clone into a temporary overlay, then refresh the live alias:**

```bash
TMP_CACHE="${NEW_CACHE}.tmp"
rm -rf "$TMP_CACHE"
git clone --depth 1 --branch "v${LATEST_VERSION}" \
  https://github.com/alo-labs/topgun.git "$TMP_CACHE" 2>&1
rsync -a --delete "${TMP_CACHE}/" "${NEW_CACHE}/"
rm -rf "$TMP_CACHE"
python3 - "$CURRENT_ALIAS" "$NEW_CACHE" <<'PY'
import pathlib
import shutil
import sys

alias_path = pathlib.Path(sys.argv[1])
target_path = pathlib.Path(sys.argv[2])

if alias_path.exists() or alias_path.is_symlink():
    if alias_path.is_dir() and not alias_path.is_symlink():
        shutil.rmtree(alias_path)
    else:
        alias_path.unlink()

alias_path.parent.mkdir(parents=True, exist_ok=True)
alias_path.symlink_to(target_path)
PY
```

On failure: `❌ Clone failed. Try: codex plugin marketplace add https://github.com/alo-labs/codex-plugins.git` → STOP.

**5.4 Security gate — show SHA before registry write:**

```bash
COMMIT_SHA=$(git -C "$NEW_CACHE" rev-parse HEAD)
SHORT_SHA="${COMMIT_SHA:0:12}"
```

Display: `⚠️ SHA: {COMMIT_SHA}  Verify at: github.com/alo-labs/topgun/releases/tag/v{LATEST_VERSION}`

Ask: `Install at commit {SHORT_SHA}? A. Yes  B. Cancel`

On cancel — clean up cloned dir then STOP:
```bash
[ -n "$NEW_CACHE" ] && [[ "$NEW_CACHE" == "$HOME/.codex/plugins/cache/"* ]] \
  && [ -d "$NEW_CACHE" ] && rm -rf "$NEW_CACHE"
```

---

## Step 6: Verify Integrity, then Update Registry

**6.1 Verify clone before touching registry:**

```bash
[ -f "${NEW_CACHE}/bin/topgun-tools.cjs" ]       || { echo "❌ Clone incomplete — bin/topgun-tools.cjs missing."; exit 1; }
[ -f "${NEW_CACHE}/skills/topgun/SKILL.md" ]     || { echo "❌ Clone incomplete — skills/topgun/SKILL.md missing."; exit 1; }
[ -L "$CURRENT_ALIAS" ]                           || { echo "❌ current alias missing."; exit 1; }
[ -f "${CURRENT_ALIAS}/bin/topgun-tools.cjs" ]    || { echo "❌ current alias missing bin/topgun-tools.cjs."; exit 1; }
[ -f "${CURRENT_ALIAS}/skills/topgun/SKILL.md" ]  || { echo "❌ current alias missing skills/topgun/SKILL.md."; exit 1; }
```

**6.2 Write to registry:**

```bash
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
CANONICAL_KEY="topgun@alo-labs-codex"
REGISTRY_FILE="$HOME/.codex/plugins/installed_plugins.json"
[[ -f "$REGISTRY_FILE" ]] || { echo "❌ Missing lowercase Codex registry file."; exit 1; }
TMPFILE=$(mktemp)
jq --arg key "$CANONICAL_KEY" --arg version "$LATEST_VERSION" \
   --arg path "$CURRENT_ALIAS" --arg sha "$COMMIT_SHA" --arg now "$NOW" \
   'del(.plugins["topgun@alo-labs"], .plugins["topgun@alo-labs-codex-local"]) |
    (.plugins[$key] //= [{}]) |
    (.plugins[$key][0].scope //= "project") |
    (.plugins[$key][0].projectPath //= env.HOME) |
    (.plugins[$key][0].installedAt //= $now) |
    .plugins[$key][0].version=$version | .plugins[$key][0].installPath=$path |
    .plugins[$key][0].lastUpdated=$now | .plugins[$key][0].gitCommitSha=$sha' \
   "$REGISTRY_FILE" > "$TMPFILE" \
   && mv "$TMPFILE" "$REGISTRY_FILE" \
   || { rm -f "$TMPFILE"; false; }

# Legacy uppercase mirror cleanup: back it up if needed, then remove it once the
# lowercase install is valid.
LEGACY_REGISTRY_FILE="$HOME/.Codex/plugins/installed_plugins.json"
if [[ -f "$LEGACY_REGISTRY_FILE" ]]; then
  LEGACY_BACKUP_ROOT="${HOME}/.topgun/legacy-codex"
  mkdir -p "$LEGACY_BACKUP_ROOT/plugins"
  cp "$LEGACY_REGISTRY_FILE" "$LEGACY_BACKUP_ROOT/plugins/installed_plugins.json"
  TMPFILE=$(mktemp)
  jq 'del(.plugins["topgun@alo-labs"], .plugins["topgun@alo-labs-codex-local"], .plugins["topgun@alo-labs-codex"])' \
    "$LEGACY_REGISTRY_FILE" > "$TMPFILE" \
    && mv "$TMPFILE" "$LEGACY_REGISTRY_FILE" \
    || { rm -f "$TMPFILE"; false; }
fi
```

On failure: display path to `NEW_CACHE` and suggest `codex plugin marketplace add https://github.com/alo-labs/codex-plugins.git`. STOP.

**6.3 Refresh native Codex skill mirrors:**

Codex's live picker discovers user-facing skills from `$HOME/.codex/skills/<name>/SKILL.md`. Keep TopGun's internal sub-skills in the plugin cache to avoid collisions with existing skills such as `find-skills`, but mirror the picker-facing entrypoints natively after every update:

```bash
NATIVE_SKILLS_ROOT="$HOME/.codex/skills"
mkdir -p "$NATIVE_SKILLS_ROOT"

mirror_topgun_skill() {
  local source_dir="$1" target_dir="$2" source_path target_path
  source_path="${CURRENT_ALIAS}/skills/${source_dir}"
  target_path="${NATIVE_SKILLS_ROOT}/${target_dir}"
  [[ -f "${source_path}/SKILL.md" ]] || { echo "❌ Missing skill source: ${source_path}/SKILL.md"; return 1; }
  case "$target_dir" in
    topgun|topgun-update|audit-security-of-skill) ;;
    *) echo "❌ Refusing unexpected native skill target: $target_dir"; return 1 ;;
  esac
  rm -rf "$target_path"
  mkdir -p "$target_path"
  rsync -a --delete "${source_path%/}/" "${target_path}/"
  chmod -R u+rwX,go+rX "$target_path"
}

mirror_topgun_skill "topgun" "topgun"
mirror_topgun_skill "topgun-update" "topgun-update"
mirror_topgun_skill "sentinel" "audit-security-of-skill"
```

Do not mirror `find-skills`, `compare-skills`, `secure-skills`, or `install-skills` into `$HOME/.codex/skills`; they are internal dispatch surfaces and their generic names can shadow unrelated installed skills.

**6.4 Purge old cache versions:**

After the registry write succeeds, delete all version directories under the TopGun cache root except the newly installed one. **Important:** TopGun can be installed from multiple marketplace ids — each lives at its own cache root (e.g. `~/.codex/plugins/cache/topgun/` for the top-level marketplace, `~/.codex/plugins/cache/alo-labs-codex/topgun/` for the official Alo Labs Codex marketplace). Purge ALL known cache roots so sibling installs from older marketplace listings are also cleaned up:

```bash
# Primary cache dir derived from the current INSTALL_PATH
TOPGUN_CACHE_DIR="${CACHE_ROOT}/topgun"

# Sibling cache dirs to scan (other marketplace install paths).
# Add new entries here as additional marketplace listings appear.
SIBLING_CACHE_DIRS=(
  "$HOME/.codex/plugins/cache/topgun"
  "$HOME/.codex/plugins/cache/alo-labs-codex/topgun"
)

DELETED=()

purge_cache_dir() {
  local dir="$1"
  [[ ! -d "$dir" ]] && return 0
  [[ "$dir" == "$HOME/.codex/plugins/cache/"* ]] \
    || { echo "❌ Cache dir outside safe prefix: $dir"; return 1; }
  while IFS= read -r -d '' old_dir; do
    # Don't delete the directory we just installed into
    [[ "$old_dir" == "$NEW_CACHE" ]] && continue
    [[ "$old_dir" == "$CURRENT_ALIAS" ]] && continue
    if rm -rf "$old_dir"; then
      DELETED+=("$old_dir")
    else
      echo "⚠️ Could not delete $old_dir — remove manually."
    fi
done < <(find "$dir" -mindepth 1 -maxdepth 1 -type d \
             ! -name "$LATEST_VERSION" ! -name "current" -print0)
}

# Remove any legacy uppercase mirror cache once the lowercase tree is valid.
LEGACY_TOPGUN_CACHE_DIR="$HOME/.Codex/plugins/cache/alo-labs-codex/topgun"
if [[ -d "$LEGACY_TOPGUN_CACHE_DIR" ]]; then
  LEGACY_BACKUP_ROOT="${HOME}/.topgun/legacy-codex"
  mkdir -p "$LEGACY_BACKUP_ROOT/plugins/cache/alo-labs-codex"
  rsync -a --delete "${LEGACY_TOPGUN_CACHE_DIR%/}/" \
    "${LEGACY_BACKUP_ROOT}/plugins/cache/alo-labs-codex/topgun/"
  rm -rf "$LEGACY_TOPGUN_CACHE_DIR"
fi

# Purge primary first, then siblings (deduplicated)
purge_cache_dir "$TOPGUN_CACHE_DIR"
for sibling in "${SIBLING_CACHE_DIRS[@]}"; do
  [[ "$sibling" == "$TOPGUN_CACHE_DIR" ]] && continue
  purge_cache_dir "$sibling"
done

# Also remove stale registry entries pointing at directories that no longer exist
node -e '
  const fs=require("fs"), path=require("path");
  const registries=[
    path.join(process.env.HOME,".codex/plugins/installed_plugins.json"),
  ];
  for (const reg of registries) {
    if (!fs.existsSync(reg)) continue;
    const r=JSON.parse(fs.readFileSync(reg,"utf8"));
    let changed=false;
    for (const k of Object.keys(r.plugins||{})) {
      if (!k.startsWith("topgun@")) continue;
      const filtered = r.plugins[k].filter(inst => {
        const exists = fs.existsSync(inst.installPath);
        if (!exists) { console.log("Pruned stale registry entry: " + k + " → " + inst.installPath); changed=true; }
        return exists;
      });
      if (filtered.length === 0) { delete r.plugins[k]; changed=true; }
      else r.plugins[k] = filtered;
    }
    if (changed) fs.writeFileSync(reg, JSON.stringify(r, null, 2));
  }
'
```

On success: deleted paths are collected in `DELETED` for display in Step 7. Stale registry entries (entries whose `installPath` was just rm'd) are pruned from `installed_plugins.json` so they don't leak forward.
On `rm` failure: warning is printed inline and the loop continues (non-fatal).

---

## Step 7: Re-initialize and Display Result

```bash
node "${NEW_CACHE}/bin/topgun-tools.cjs" init 2>/dev/null && echo "INIT_OK" || echo "INIT_SKIP"
```

Then display:
```
╔══════════════════════════════════════════════╗
║  TopGun Updated: v{OLD} → v{LATEST_VERSION}  ║
╚══════════════════════════════════════════════╝
Picker mirrors refreshed in ~/.codex/skills; no restart required.
Commit SHA: {COMMIT_SHA}
Current alias: {CURRENT_ALIAS}
Versioned cache: {NEW_CACHE}
Cleaned up: {DELETED paths, or "none" if DELETED is empty}
~/.topgun/ state, audit cache, and keychain tokens unchanged.
Hook trust: refreshed from the final stable hook surface before exit.
🔗 https://github.com/alo-labs/topgun/releases/tag/v{LATEST_VERSION}
```
