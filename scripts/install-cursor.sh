#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=scripts/lib/agent-bundle-paths.sh
source "${REPO_ROOT}/scripts/lib/agent-bundle-paths.sh"
VERSION="$(jq -r '.version // "0.0.0"' "${REPO_ROOT}/package.json" 2>/dev/null || echo 0.0.0)"
PUBLIC_RELEASE_ONLY=0
CURSOR_HOME="${CURSOR_HOME:-${HOME}/.cursor}"
CURSOR_MARKETPLACE_SOURCE="${CURSOR_MARKETPLACE_SOURCE:-https://github.com/alo-labs/agent-plugins}"
CURSOR_SB_PUBLIC_MARKETPLACE_SOURCE="${CURSOR_SB_PUBLIC_MARKETPLACE_SOURCE:-https://github.com/alo-labs/agent-plugins.git}"
CURSOR_MARKETPLACE_NAME="${CURSOR_MARKETPLACE_NAME:-alo-labs-cursor}"
CURSOR_BACKEND_MARKETPLACE_NAME="${CURSOR_BACKEND_MARKETPLACE_NAME:-alo-labs-agent-plugins}"
CURSOR_PLUGIN_GIT_SUBPATH="${CURSOR_PLUGIN_GIT_SUBPATH:-plugins/silver-bullet}"
CURSOR_MARKETPLACE_ROOT="${CURSOR_MARKETPLACE_ROOT:-${CURSOR_HOME}/plugins/marketplaces/${CURSOR_MARKETPLACE_NAME}}"
CURSOR_GITHUB_REPO_SLUG="${CURSOR_GITHUB_REPO_SLUG:-alo-exp/silver-bullet}"
CURSOR_GITHUB_REPO_URL="${CURSOR_GITHUB_REPO_URL:-https://github.com/alo-exp/silver-bullet.git}"
DEST_ROOT="${CURSOR_HOME}/plugins/cache/alo-labs/silver-bullet/${VERSION}"
INSTALL_COMMIT_SHA=""
MERGE_HOOKS="${REPO_ROOT}/scripts/lib/install-cursor/merge-cursor-hooks.py"
LEGACY_MARKETPLACE_LIB="${REPO_ROOT}/scripts/lib/install-cursor/legacy-marketplace.sh"
BACKEND_CACHE_LIB="${REPO_ROOT}/scripts/lib/install-cursor/backend-cache.sh"
AGENT_RENDERER="${REPO_ROOT}/scripts/render-agent-bundle.py"

cursor_install_current_link() {
  printf '%s/plugins/cache/alo-labs/silver-bullet/current' "$CURSOR_HOME"
}

# Never treat the `current` symlink path as the install root — resolve to the versioned dir.
resolve_cursor_install_dest() {
  local candidate="${1:-}"
  local current_link resolved

  current_link="$(cursor_install_current_link)"

  if [[ -z "$candidate" ]]; then
    candidate="$current_link"
  fi

  if [[ "$candidate" == "$current_link" || "$(basename "$candidate")" == "current" ]]; then
    if [[ -L "$current_link" ]]; then
      resolved="$(cd "$current_link" 2>/dev/null && pwd -P || true)"
      if [[ -n "$resolved" && -d "$resolved" ]]; then
        printf '%s\n' "$resolved"
        return 0
      fi
    elif [[ -d "$current_link" ]]; then
      resolved="$(cd "$current_link" && pwd -P)"
      printf '%s\n' "$resolved"
      return 0
    fi
    candidate="$(find "${CURSOR_HOME}/plugins/cache/alo-labs/silver-bullet" -maxdepth 1 -type d -name '[0-9]*.[0-9]*' 2>/dev/null | sort -V | tail -1)"
  fi

  if [[ -n "$candidate" && -d "$candidate" ]]; then
    (cd "$candidate" && pwd -P)
  fi
}

cursor_plugin_commands_src() {
  local source_root="$1"
  if [[ -d "${source_root}/plugins/silver-bullet/commands" ]]; then
    printf '%s/plugins/silver-bullet/commands\n' "$source_root"
  fi
}

usage() {
  cat <<'USAGE'
Usage: scripts/install-cursor.sh [--merge-hooks-only] [--public-release] [--project-root PATH]

Synchronizes the Silver Bullet plugin tree into the Cursor plugin cache and
merges SB hooks into ~/.cursor/hooks.json. Deploys the five-tool reconciler,
global repair framework, and host snapshots on every install/upgrade.

When the legacy alo-labs/alo-labs-cursor-marketplace clone is present, the
installer removes it, seeds gitPath for backend-resolved SHAs, and prints UI
steps to switch to https://github.com/alo-labs/agent-plugins.

Options:
  --merge-hooks-only  Only merge hooks from the current install path
  --public-release    Refresh from the published Cursor marketplace instead of the local checkout
  --project-root PATH Reconcile consented project tools after host infra (requires .silver-bullet.json)
USAGE
}

marketplace_manifest_path() {
  printf '%s/.cursor-plugin/marketplace.json\n' "$CURSOR_MARKETPLACE_ROOT"
}

ensure_marketplace_checkout() {
  local source="${1:-$CURSOR_SB_PUBLIC_MARKETPLACE_SOURCE}"

  if [[ -d "${CURSOR_MARKETPLACE_ROOT}/.git" ]]; then
    git -C "$CURSOR_MARKETPLACE_ROOT" fetch --depth 1 origin main >/dev/null 2>&1 || \
      git -C "$CURSOR_MARKETPLACE_ROOT" fetch --depth 1 origin master >/dev/null 2>&1 || true
    git -C "$CURSOR_MARKETPLACE_ROOT" pull --ff-only >/dev/null 2>&1 || true
    return 0
  fi

  mkdir -p "$(dirname "$CURSOR_MARKETPLACE_ROOT")"
  git clone --depth 1 "$source" "$CURSOR_MARKETPLACE_ROOT" >/dev/null
}

read_marketplace_version() {
  local manifest
  manifest="$(marketplace_manifest_path)"
  [[ -f "$manifest" ]] || {
    printf 'ERROR: Cursor marketplace manifest not found at %s\n' "$manifest" >&2
    exit 1
  }
  jq -r '.plugins[] | select(.name=="silver-bullet") | .version' "$manifest"
}

read_marketplace_manifest_sha() {
  local manifest
  manifest="$(marketplace_manifest_path)"
  [[ -f "$manifest" ]] || return 0
  jq -r '.plugins[] | select(.name=="silver-bullet") | .source.sha // empty' "$manifest" 2>/dev/null || true
}

sync_plugin_tree_from_checkout() {
  local source_root="$1"
  local version="$2"
  local dest="${CURSOR_HOME}/plugins/cache/alo-labs/silver-bullet/${version}"

  mkdir -p "${dest}"
  rsync -a --delete \
    --exclude '.git' --exclude '.planning' --exclude 'tests' --exclude 'site' --exclude 'forge' \
    "${source_root}/hooks/" "${dest}/hooks/"
  # Do not mirror canonical skills/ into the Cursor cache — hyphen directories
  # register as slash skills and duplicate agents/cursor subagents and commands/.
  rm -rf "${dest}/skills"
  mkdir -p "${dest}/skills/silver-init/scripts"
  if [[ -d "${source_root}/skills/silver-init/scripts" ]]; then
    rsync -a --delete "${source_root}/skills/silver-init/scripts/" "${dest}/skills/silver-init/scripts/"
  fi
  local skill_source_src="${source_root}/plugins/silver-bullet/skill-source"
  if [[ -d "$skill_source_src" ]]; then
    mkdir -p "${dest}/skill-source"
    rsync -a --delete "${skill_source_src}/" "${dest}/skill-source/"
  else
    rm -rf "${dest}/skill-source"
  fi
  rsync -a --delete "${source_root}/scripts/" "${dest}/scripts/"
  rsync -a --delete "${source_root}/templates/" "${dest}/templates/"
  # agents/cursor must not ship in the Cursor install cache — cursor-agent TUI
  # auto-discovers agents/<host>/*/SKILL.md for / picker entries regardless of
  # plugin.json skills. Orchestrator + Skill tool read skill-source/ instead.
  rm -rf "${dest}/agents/cursor" "${dest}/agents"
  local commands_src
  commands_src="$(cursor_plugin_commands_src "$source_root" || true)"
  if [[ -n "$commands_src" ]]; then
    mkdir -p "${dest}/commands"
    rsync -a --delete "${commands_src}/" "${dest}/commands/"
  else
    rm -rf "${dest}/commands"
  fi
  python3 "${source_root}/scripts/generate-cursor-hooks.py" >/dev/null 2>&1 || {
    if [[ -x "${REPO_ROOT}/scripts/generate-cursor-hooks.py" ]]; then
      python3 "${REPO_ROOT}/scripts/generate-cursor-hooks.py" >/dev/null
    else
      printf 'ERROR: missing scripts/generate-cursor-hooks.py in %s and %s\n' "$source_root" "$REPO_ROOT" >&2
      exit 1
    fi
  }
  install -m 644 "${source_root}/hooks/cursor-hooks.json" "${dest}/hooks/cursor-hooks.json"
  install_cursor_plugin_manifest "$dest" "$version" "$source_root"
  printf '%s\n' "$dest"
}

install_cursor_plugin_manifest() {
  local dest="$1"
  local version="$2"
  local source_root="$3"
  local manifest_src="${source_root}/.cursor-plugin/plugin.json"
  local tmp

  mkdir -p "${dest}/.cursor-plugin"
  [[ -f "$manifest_src" ]] || manifest_src="${REPO_ROOT}/.cursor-plugin/plugin.json"
  [[ -f "$manifest_src" ]] || {
    printf 'ERROR: missing Cursor plugin manifest at %s\n' "$manifest_src" >&2
    exit 1
  }

  tmp="$(mktemp)"
  if [[ -d "${dest}/commands" ]]; then
    jq --arg v "$version" '
      .version = $v
      | .hooks = "./cursor-hooks.json"
      | .commands = "./commands"
      | del(.skills)
    ' "$manifest_src" > "$tmp"
  else
    jq --arg v "$version" '
      .version = $v
      | .hooks = "./cursor-hooks.json"
      | del(.commands, .skills)
    ' "$manifest_src" > "$tmp"
  fi
  install -m 644 "$tmp" "${dest}/.cursor-plugin/plugin.json"
  rm -f -- "$tmp"
  install -m 644 "${dest}/hooks/cursor-hooks.json" "${dest}/cursor-hooks.json"
}

cursor_github_marketplace_gitpath_root() {
  printf '%s/plugins/marketplaces/github.com/%s\n' "$CURSOR_HOME" "$CURSOR_GITHUB_REPO_SLUG"
}

resolve_install_commit_sha() {
  local source_root="$1"
  if git -C "$source_root" rev-parse HEAD >/dev/null 2>&1; then
    git -C "$source_root" rev-parse HEAD
    return 0
  fi
  git -C "$REPO_ROOT" rev-parse HEAD
}

cursor_git_common_dir() {
  local source_root="$1"
  local git_dir=""

  git_dir="$(git -C "$source_root" rev-parse --git-common-dir 2>/dev/null || true)"
  [[ -n "$git_dir" ]] || git_dir="$(git -C "$source_root" rev-parse --git-dir 2>/dev/null || true)"
  [[ -n "$git_dir" ]] || return 1
  if [[ "$git_dir" != /* ]]; then
    git_dir="$(cd "$source_root" && cd "$git_dir" && pwd)"
  fi
  printf '%s' "$git_dir"
}

ensure_cursor_github_marketplace_gitpath() {
  local commit_sha="$1"
  local source_root="$2"
  local base_root dest_root

  [[ -n "$commit_sha" ]] || return 0

  base_root="$(cursor_github_marketplace_gitpath_root)"
  dest_root="${base_root}/${commit_sha}"

  if [[ -d "${dest_root}/.git" ]] && git -C "$dest_root" cat-file -e "${commit_sha}^{commit}" >/dev/null 2>&1; then
    git -C "$dest_root" checkout -f "$commit_sha" >/dev/null 2>&1 || true
    return 0
  fi

  if [[ -d "$dest_root" ]]; then
    rm -rf "$dest_root"
  fi
  mkdir -p "$(dirname "$base_root")"

  if git -C "$source_root" rev-parse HEAD >/dev/null 2>&1 \
    && [[ "$(git -C "$source_root" rev-parse HEAD)" == "$commit_sha" ]]; then
    local git_common_dir=""
    git_common_dir="$(cursor_git_common_dir "$source_root" 2>/dev/null || true)"
    if [[ -n "$git_common_dir" ]]; then
      git clone --local "$git_common_dir" "$dest_root" >/dev/null 2>&1 || \
        git clone --local "$source_root" "$dest_root" >/dev/null
    else
      git clone --local "$source_root" "$dest_root" >/dev/null
    fi
    git -C "$dest_root" checkout -f "$commit_sha" >/dev/null 2>&1 || true
    return 0
  fi

  if ! git clone --depth 1 "$CURSOR_GITHUB_REPO_URL" "$dest_root" >/dev/null 2>&1; then
    git clone "$CURSOR_GITHUB_REPO_URL" "$dest_root" >/dev/null
  fi

  if ! git -C "$dest_root" cat-file -e "${commit_sha}^{commit}" >/dev/null 2>&1; then
    git -C "$dest_root" fetch --depth 1 origin "$commit_sha" >/dev/null 2>&1 || \
      git -C "$dest_root" fetch origin "$commit_sha" >/dev/null 2>&1 || true
  fi

  if git -C "$dest_root" cat-file -e "${commit_sha}^{commit}" >/dev/null 2>&1 \
    && git -C "$dest_root" checkout -f "$commit_sha" >/dev/null 2>&1; then
    return 0
  fi

  rm -rf "$dest_root"
  printf 'Note: skipped unreachable Cursor gitPath commit %s (not on %s)\n' "${commit_sha:0:8}" "$CURSOR_GITHUB_REPO_URL" >&2
  return 1
}

resolve_remote_github_head_sha() {
  git ls-remote "$CURSOR_GITHUB_REPO_URL" HEAD 2>/dev/null | awk 'NR==1 {print $1}'
}

cursor_marketplace_plugin_cache_root() {
  printf '%s/plugins/cache/%s/silver-bullet\n' "$CURSOR_HOME" "$CURSOR_MARKETPLACE_NAME"
}

ensure_cursor_marketplace_plugin_cache_symlink() {
  local dest="$1"
  local commit_sha="$2"
  local cache_root link_path

  [[ -n "$commit_sha" ]] || return 0

  cache_root="${CURSOR_HOME}/plugins/cache/${CURSOR_MARKETPLACE_NAME}/silver-bullet"
  link_path="${cache_root}/${commit_sha}"
  mkdir -p "$cache_root"
  # macOS ln -sfn fails with "File exists" when link_path is a real directory.
  if [[ -e "$link_path" || -L "$link_path" ]]; then
    rm -rf "$link_path" 2>/dev/null || true
  fi
  if ! ln -sfn "$dest" "$link_path"; then
    printf 'ERROR: failed to link Cursor marketplace cache %s -> %s\n' "$link_path" "$dest" >&2
    return 1
  fi
  ensure_cursor_backend_plugin_cache_dir "$dest" "$commit_sha"
}

read_installed_plugins_git_sha() {
  local registry_file="${CURSOR_HOME}/plugins/installed_plugins.json"
  [[ -f "$registry_file" ]] || return 0
  jq -r '
    .plugins["silver-bullet@alo-labs"] as $entry
    | if $entry == null then empty
      elif ($entry | type) == "array" then ($entry[0].gitCommitSha // empty)
      else ($entry.gitCommitSha // empty)
      end
  ' "$registry_file" 2>/dev/null || true
}

cursor_github_marketplace_gitpath_for_sha() {
  local commit_sha="$1"
  printf '%s/%s' "$(cursor_github_marketplace_gitpath_root)" "$commit_sha"
}

cursor_plugin_git_subpath_root() {
  local commit_sha="$1"
  printf '%s/%s' "$(cursor_github_marketplace_gitpath_for_sha "$commit_sha")" "$CURSOR_PLUGIN_GIT_SUBPATH"
}

prune_cursor_gitpath_picker_skills() {
  local dest="$1"
  local gitpath_root="$2"

  # Full gitPath checkouts still contain canonical skills/ (hyphen dirs). Cursor
  # discovers them alongside plugin.json commands/ and agents/cursor subagents.
  # Tolerate busy/partial trees under ~/.cursor (macOS "Directory not empty").
  rm -rf "${gitpath_root}/skills" 2>/dev/null || true
  if [[ -d "${dest}/skills" ]]; then
    mkdir -p "${gitpath_root}/skills"
    rsync -a --delete "${dest}/skills/" "${gitpath_root}/skills/"
  fi
  rm -rf \
    "${gitpath_root}/plugins/silver-bullet/skills" \
    "${gitpath_root}/.agents" \
    "${gitpath_root}/.cursor/agents" 2>/dev/null || true
}

prune_cursor_gitpath_extra_picker_surfaces() {
  local gitpath_root="$1"
  local nested_manifest="${gitpath_root}/plugins/silver-bullet/.cursor-plugin/plugin.json"
  local tmp=""

  # host-bundles/cursor mirrors agents/cursor — Cursor discovers both from full clone.
  rm -rf "${gitpath_root}/host-bundles" 2>/dev/null || true

  # agents/cursor auto-registers / picker subagents; skill-source is internal-only.
  rm -rf "${gitpath_root}/agents" 2>/dev/null || true

  # Root materialization is canonical; nested plugin mirror duplicates commands/subagents.
  rm -rf \
    "${gitpath_root}/plugins/silver-bullet/commands" \
    "${gitpath_root}/plugins/silver-bullet/agents" \
    "${gitpath_root}/plugins/silver-bullet/skill-source" \
    "${gitpath_root}/plugins/silver-bullet/templates" \
    "${gitpath_root}/templates/orchestrator-workers" \
    "${gitpath_root}/templates/workflows" 2>/dev/null || true

  if [[ -f "$nested_manifest" ]]; then
    tmp="$(mktemp)"
    jq 'del(.skills, .commands)' "$nested_manifest" > "$tmp"
    install -m 644 "$tmp" "$nested_manifest"
    rm -f -- "$tmp"
  fi
}

materialize_cursor_plugin_surface_at_root() {
  local dest="$1"
  local gitpath_root="$2"

  if [[ -d "${dest}/commands" ]]; then
    mkdir -p "${gitpath_root}/commands"
    rsync -a --delete "${dest}/commands/" "${gitpath_root}/commands/"
  fi
  rm -rf "${gitpath_root}/agents/cursor" "${gitpath_root}/agents" 2>/dev/null || true
  if [[ -f "${dest}/cursor-hooks.json" ]]; then
    install -m 644 "${dest}/cursor-hooks.json" "${gitpath_root}/cursor-hooks.json"
  fi
  if [[ -f "${dest}/.cursor-plugin/plugin.json" ]]; then
    mkdir -p "${gitpath_root}/.cursor-plugin"
    install -m 644 "${dest}/.cursor-plugin/plugin.json" "${gitpath_root}/.cursor-plugin/plugin.json"
  fi
  prune_cursor_gitpath_picker_skills "$dest" "$gitpath_root"
}

materialize_cursor_plugin_surface_in_gitpath() {
  local dest="$1"
  local commit_sha="$2"
  local gitpath_root

  [[ -n "$commit_sha" ]] || return 0
  gitpath_root="$(cursor_github_marketplace_gitpath_for_sha "$commit_sha")"
  [[ -d "${gitpath_root}/.git" ]] || return 0

  mkdir -p "${gitpath_root}/.cursor-plugin"
  materialize_cursor_plugin_surface_at_root "$dest" "$gitpath_root"
  prune_cursor_gitpath_extra_picker_surfaces "$gitpath_root"
}

cursor_plugin_gitpath_ready() {
  local commit_sha="$1"
  local gitpath_root

  [[ -n "$commit_sha" ]] || return 1
  gitpath_root="$(cursor_github_marketplace_gitpath_for_sha "$commit_sha")"
  [[ -d "${gitpath_root}/.git" ]] && git -C "$gitpath_root" cat-file -e "${commit_sha}^{commit}" >/dev/null 2>&1
}

cursor_plugin_gitpath_surface_ready() {
  local commit_sha="$1"

  cursor_plugin_gitpath_ready "$commit_sha" || return 1
  cursor_plugin_gitpath_root_surface_ready "$commit_sha"
}

cursor_marketplace_cache_link_ready() {
  local dest="$1"
  local commit_sha="$2"
  local link_path resolved_dest resolved_link

  [[ -n "$commit_sha" ]] || return 1
  link_path="$(cursor_marketplace_plugin_cache_root)/${commit_sha}"
  [[ -L "$link_path" ]] || return 1
  resolved_dest="$(cd "$dest" && pwd -P)"
  resolved_link="$(cd "$link_path" && pwd -P 2>/dev/null || true)"
  [[ "$resolved_link" == "$resolved_dest" ]]
}

seed_cursor_marketplace_gitpaths() {
  local dest="$1"
  local primary_sha="$2"
  local source_root="$3"
  local sha

  while IFS= read -r sha; do
    [[ -n "$sha" ]] || continue
    ensure_cursor_github_marketplace_gitpath "$sha" "$source_root" || continue
    materialize_cursor_plugin_surface_in_gitpath "$dest" "$sha"
    ensure_cursor_marketplace_plugin_cache_symlink "$dest" "$sha"
  done < <(collect_cursor_plugin_seed_shas "$primary_sha" "")
}

rematerialize_all_reachable_cursor_gitpaths() {
  local dest="$1"
  local base_root entry name sha

  base_root="$(cursor_github_marketplace_gitpath_root)"
  [[ -d "$base_root" ]] || return 0

  for entry in "$base_root"/*; do
    [[ -d "$entry" ]] || continue
    name="$(basename "$entry")"
    [[ "$name" =~ ^[0-9a-f]{40}$ ]] || continue
    [[ -d "${entry}/.git" ]] || continue
    if ! git -C "$entry" cat-file -e "${name}^{commit}" >/dev/null 2>&1; then
      continue
    fi
    materialize_cursor_plugin_surface_in_gitpath "$dest" "$name"
    ensure_cursor_marketplace_plugin_cache_symlink "$dest" "$name"
    ensure_cursor_backend_plugin_cache_dir "$dest" "$name"
  done
}

verify_cursor_plugin_discovery_paths() {
  local dest="$1"
  local source_root="$2"
  local primary_sha backend_sha sha failures=0

  primary_sha="$(resolve_install_commit_sha "$source_root")"
  backend_sha="$(resolve_cursor_backend_plugin_sha "$primary_sha")"

  while IFS= read -r sha; do
    [[ -n "$sha" ]] || continue
    if ! cursor_plugin_gitpath_ready "$sha"; then
      printf 'ERROR: Cursor gitPath missing for %s — plugin load fails after restart (see Cursor Plugins log)\n' "$sha" >&2
      failures=1
    elif ! cursor_plugin_gitpath_surface_ready "$sha"; then
      printf 'ERROR: Cursor gitPath plugin surface incomplete for %s — commands/ or plugin.json missing (run: bash scripts/install-cursor.sh)\n' "$sha" >&2
      failures=1
    elif ! cursor_marketplace_cache_link_ready "$dest" "$sha"; then
      printf 'ERROR: Cursor marketplace cache symlink missing for %s at %s/silver-bullet/%s\n' \
        "$sha" "$(cursor_marketplace_plugin_cache_root)" "$sha" >&2
      failures=1
    elif ! cursor_backend_plugin_cache_ready "$dest" "$sha"; then
      printf 'ERROR: Cursor backend marketplace cache missing for %s at %s/%s — /silver commands fail after reload\n' \
        "$sha" "$(cursor_backend_plugin_cache_root)" "$sha" >&2
      failures=1
    fi
  done < <(collect_cursor_plugin_verify_shas "$primary_sha" "$backend_sha")

  if ! cursor_local_plugin_link_ready "$dest"; then
    printf 'ERROR: Cursor local plugin surface missing at %s/plugins/local/silver-bullet — desktop rejects symlinks outside plugins/local (run: bash scripts/install-cursor.sh)\n' \
      "$CURSOR_HOME" >&2
    failures=1
  fi

  return "$failures"
}

ensure_cursor_installed_plugins_registry() {
  local dest="$1"
  local version="$2"
  local commit_sha="${3:-}"
  local registry_file="${CURSOR_HOME}/plugins/installed_plugins.json"
  local now
  local tmp

  now="$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
  mkdir -p "$(dirname "$registry_file")"

  python3 - "$registry_file" "$dest" "$version" "$now" "$commit_sha" "$CURSOR_HOME" <<'PY'
import json
import pathlib
import sys

registry_path = pathlib.Path(sys.argv[1])
install_path = str(pathlib.Path(sys.argv[2]).resolve())
version = sys.argv[3]
now = sys.argv[4]
commit_sha = sys.argv[5]
cursor_home = pathlib.Path(sys.argv[6]).expanduser()
plugin_id = "silver-bullet@alo-labs"

data = {"version": 2, "plugins": {}}
if registry_path.is_file():
    try:
        data = json.loads(registry_path.read_text())
    except Exception:
        pass

plugins = data.setdefault("plugins", {})
entry = {
    "scope": "user",
    "installPath": install_path,
    "version": version,
    "installedAt": now,
    "lastUpdated": now,
    "enabled": True,
}
if commit_sha:
    entry["gitCommitSha"] = commit_sha
    gitpath = (
        cursor_home
        / "plugins"
        / "marketplaces"
        / "github.com"
        / "alo-exp"
        / "silver-bullet"
        / commit_sha
    )
    entry["gitPath"] = str(gitpath.resolve())

existing = plugins.get(plugin_id)
if isinstance(existing, list) and existing:
    existing[0].update(entry)
    plugins[plugin_id] = existing
elif isinstance(existing, dict):
    entry = {**existing, **entry}
    plugins[plugin_id] = [entry]
else:
    plugins[plugin_id] = [entry]

data["version"] = 2
registry_path.write_text(json.dumps(data, indent=2) + "\n")
PY
}

cursor_canonical_physical_path() {
  local path="$1"
  [[ -n "$path" ]] || return 0
  # Normalize duplicate separators even before the final path is materialized
  # (for example a git-archive install rooted under $TMPDIR).
  path="$(printf '%s' "$path" | sed 's#//*#/#g')"
  if [[ -e "$path" || -d "$path" ]]; then
    path="$(cd "$path" 2>/dev/null && pwd -P || printf '%s' "$path")"
  fi
  # macOS: /var symlinks to /private/var — normalize so identity checks are stable.
  if [[ "$path" == /private/var/* ]]; then
    path="/var/${path#/private/var/}"
  fi
  printf '%s' "$path"
}

verify_cursor_install_identity() {
  local dest="$1"
  local version="$2"
  local commit_sha="${3:-}"
  local registry_file="${CURSOR_HOME}/plugins/installed_plugins.json"
  local current_link resolved_dest resolved_current local_plugin
  local registry_version registry_install_path registry_git_sha registry_git_path
  local local_version cache_version marketplace_version marketplace_sha
  local expected_git_path resolved_registry_git_path resolved_expected_git_path
  local failures=0

  resolved_dest="$(cursor_canonical_physical_path "$dest")"
  current_link="$(cursor_install_current_link)"
  resolved_current="$(cursor_canonical_physical_path "$(cd "$current_link" 2>/dev/null && pwd -P || true)")"
  local_plugin="${CURSOR_HOME}/plugins/local/silver-bullet"

  if [[ "$(basename "$resolved_dest")" != "$version" || ! -d "$resolved_dest" ]]; then
    printf 'ERROR: Cursor cache claimed version %s is not materialized at %s\n' "$version" "$resolved_dest" >&2
    failures=1
  fi
  if [[ "$resolved_current" != "$resolved_dest" ]]; then
    printf 'ERROR: Cursor current symlink resolves to %s, expected %s\n' "$resolved_current" "$resolved_dest" >&2
    failures=1
  fi
  if [[ ! -d "${CURSOR_HOME}/plugins/cache/alo-labs/silver-bullet/${version}" ]]; then
    printf 'ERROR: Cursor claimed cache version is missing: %s\n' "${CURSOR_HOME}/plugins/cache/alo-labs/silver-bullet/${version}" >&2
    failures=1
  fi

  registry_version="$(jq -r '.plugins["silver-bullet@alo-labs"][0].version // empty' "$registry_file" 2>/dev/null || true)"
  registry_install_path="$(jq -r '.plugins["silver-bullet@alo-labs"][0].installPath // empty' "$registry_file" 2>/dev/null || true)"
  registry_git_sha="$(jq -r '.plugins["silver-bullet@alo-labs"][0].gitCommitSha // empty' "$registry_file" 2>/dev/null || true)"
  registry_git_path="$(jq -r '.plugins["silver-bullet@alo-labs"][0].gitPath // empty' "$registry_file" 2>/dev/null || true)"
  if [[ -n "$commit_sha" && "$registry_git_sha" != "$commit_sha" ]]; then
    printf 'ERROR: Cursor registry gitCommitSha=%s expected=%s\n' "$registry_git_sha" "$commit_sha" >&2
    failures=1
  fi
  expected_git_path="$(cursor_github_marketplace_gitpath_for_sha "$commit_sha")"
  resolved_registry_git_path=""
  resolved_expected_git_path=""
  if [[ -n "$registry_git_path" ]]; then
    resolved_registry_git_path="$(cursor_canonical_physical_path "$registry_git_path")"
  fi
  if [[ -n "$expected_git_path" ]]; then
    resolved_expected_git_path="$(cursor_canonical_physical_path "$expected_git_path")"
  fi
  if [[ -n "$commit_sha" && "$resolved_registry_git_path" != "$resolved_expected_git_path" ]]; then
    printf 'ERROR: Cursor registry gitPath=%s expected=%s\n' "$registry_git_path" "$expected_git_path" >&2
    failures=1
  fi
  if ! jq -e '.plugins["silver-bullet@alo-labs"][0].enabled == true' "$registry_file" >/dev/null 2>&1; then
    printf 'ERROR: Cursor marketplace enablement record is missing or disabled for silver-bullet@alo-labs\n' >&2
    failures=1
  fi

  if [[ -n "$registry_install_path" ]]; then
    registry_install_path="$(cursor_canonical_physical_path "$registry_install_path")"
  fi
  if [[ "$registry_version" != "$version" || "$(basename "$registry_install_path")" != "$version" || "$registry_install_path" != "$resolved_dest" ]]; then
    printf 'ERROR: Cursor registry identity mismatch: version=%s installPath=%s expectedVersion=%s expectedPath=%s\n' \
      "$registry_version" "$registry_install_path" "$version" "$resolved_dest" >&2
    failures=1
  fi

  cache_version="$(jq -r '.version // empty' "${resolved_dest}/.cursor-plugin/plugin.json" 2>/dev/null || true)"
  local_version="$(jq -r '.version // empty' "${local_plugin}/.cursor-plugin/plugin.json" 2>/dev/null || true)"
  marketplace_version="$(jq -r '.plugins[] | select(.name=="silver-bullet") | .version // empty' "$(marketplace_manifest_path)" 2>/dev/null || true)"
  marketplace_sha="$(read_marketplace_manifest_sha)"
  if [[ "$cache_version" != "$version" || "$local_version" != "$version" ]]; then
    printf 'ERROR: Cursor plugin manifest version mismatch: cache=%s local=%s expected=%s\n' \
      "$cache_version" "$local_version" "$version" >&2
    failures=1
  fi
  if [[ "$marketplace_version" != "$version" ]] || \
     { [[ -n "$commit_sha" ]] && [[ "$marketplace_sha" != "$commit_sha" ]]; }; then
    printf 'ERROR: Cursor marketplace pin mismatch: version=%s sha=%s expectedVersion=%s expectedSha=%s\n' \
      "$marketplace_version" "$marketplace_sha" "$version" "$commit_sha" >&2
    failures=1
  fi
  if [[ "$(cursor_plugin_command_filename_colon_count "$resolved_dest")" -ne 0 || \
        "$(cursor_plugin_command_filename_colon_count "$local_plugin")" -ne 0 ]]; then
    printf 'ERROR: Cursor command filenames contain colon characters; regenerate with scripts/generate-plugin-commands.sh\n' >&2
    failures=1
  fi

  return "$failures"
}

sync_plugin_tree() {
  local dest

  mkdir -p "${REPO_ROOT}/host-bundles"
  python3 "$AGENT_RENDERER" render \
    --agent cursor \
    --source-root "${REPO_ROOT}/skills" \
    --dest-root "$(sb_agent_bundle_root "$REPO_ROOT" cursor)" >/dev/null 2>&1 || true
  INSTALL_COMMIT_SHA="$(resolve_install_commit_sha "$REPO_ROOT")"
  dest="$(sync_plugin_tree_from_checkout "$REPO_ROOT" "$VERSION")"
  seed_cursor_marketplace_gitpaths "$dest" "$INSTALL_COMMIT_SHA" "$REPO_ROOT"
  printf '%s\n' "$dest"
}

sync_plugin_tree_from_public_release() {
  local release_version checkout_dir

  ensure_marketplace_checkout "$CURSOR_SB_PUBLIC_MARKETPLACE_SOURCE"
  release_version="$(read_marketplace_version)"
  checkout_dir="$(mktemp -d "${TMPDIR:-/tmp}/sb-cursor-release.XXXXXX")"

  git clone --depth 1 --branch "v${release_version}" \
    https://github.com/alo-exp/silver-bullet.git "$checkout_dir" >/dev/null 2>&1 || \
    git clone --depth 1 --branch "$release_version" \
      https://github.com/alo-exp/silver-bullet.git "$checkout_dir" >/dev/null 2>&1 || \
    git clone --depth 1 https://github.com/alo-exp/silver-bullet.git "$checkout_dir" >/dev/null

  mkdir -p "${checkout_dir}/host-bundles"
  python3 "$AGENT_RENDERER" render \
    --agent cursor \
    --source-root "${checkout_dir}/skills" \
    --dest-root "$(sb_agent_bundle_root "$checkout_dir" cursor)" >/dev/null

  INSTALL_COMMIT_SHA="$(resolve_install_commit_sha "$checkout_dir")"
  VERSION="$release_version"
  DEST_ROOT="$(sync_plugin_tree_from_checkout "$checkout_dir" "$release_version")"
  seed_cursor_marketplace_gitpaths "$DEST_ROOT" "$INSTALL_COMMIT_SHA" "$checkout_dir"
  rm -rf -- "$checkout_dir"
}

MERGE_ONLY=0
LEGACY_MARKETPLACE_UI_SWITCH=0
SB_RECONCILE_PROJECT_ROOT=""
# shellcheck source=scripts/lib/install-cursor/legacy-marketplace.sh
source "$LEGACY_MARKETPLACE_LIB"
# shellcheck source=scripts/lib/install-cursor/backend-cache.sh
source "$BACKEND_CACHE_LIB"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --merge-hooks-only) MERGE_ONLY=1; shift ;;
    --public-release) PUBLIC_RELEASE_ONLY=1; shift ;;
    --project-root)
      SB_RECONCILE_PROJECT_ROOT="${2:-}"
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

if legacy_cursor_marketplace_active; then
  LEGACY_MARKETPLACE_UI_SWITCH=1
  print_cursor_marketplace_migration_notice
fi

ensure_marketplace_checkout "$CURSOR_UNIFIED_MARKETPLACE_SOURCE"
ensure_agent_plugins_marketplace_clone

if [[ "$MERGE_ONLY" -eq 0 ]]; then
  if [[ "$PUBLIC_RELEASE_ONLY" -eq 1 ]]; then
    sync_plugin_tree_from_public_release
  else
    DEST_ROOT="$(sync_plugin_tree)"
  fi
else
  DEST_ROOT="$(resolve_cursor_install_dest "$(cursor_install_current_link)")"
  if [[ -z "$DEST_ROOT" || ! -d "$DEST_ROOT" ]]; then
    printf 'ERROR: no installed Cursor plugin at %s; run without --merge-hooks-only first\n' "$(cursor_install_current_link)" >&2
    exit 1
  fi
  INSTALL_COMMIT_SHA="$(read_installed_plugins_git_sha)"
  if [[ -z "$INSTALL_COMMIT_SHA" ]]; then
    INSTALL_COMMIT_SHA="$(resolve_install_commit_sha "$REPO_ROOT")"
  fi
  seed_cursor_marketplace_gitpaths_extended "$DEST_ROOT" "$INSTALL_COMMIT_SHA" "$REPO_ROOT"
fi

if [[ "$LEGACY_MARKETPLACE_UI_SWITCH" -eq 1 ]]; then
  remove_legacy_cursor_marketplace_clones
fi

# Never let resolve fall back to a stale `current` symlink when VERSION is known —
# that produced registry version N with installPath still at N-1.
if [[ "$MERGE_ONLY" -eq 0 ]]; then
  DEST_ROOT="$(printf '%s\n' "$DEST_ROOT" | awk 'NF{line=$0} END{print line}')"
  EXPECTED_DEST="${CURSOR_HOME}/plugins/cache/alo-labs/silver-bullet/${VERSION}"
  if [[ ! -d "$EXPECTED_DEST" ]]; then
    printf 'ERROR: expected Cursor cache version dir missing after sync: %s\n' "$EXPECTED_DEST" >&2
    exit 1
  fi
  DEST_ROOT="$(cd "$EXPECTED_DEST" && pwd -P)"
else
  DEST_ROOT="$(resolve_cursor_install_dest "$DEST_ROOT")"
fi
python3 "$MERGE_HOOKS" "$DEST_ROOT"

# SB custom subagents for Cursor review/verify ladders (~/.cursor/agents/)
CSBA_INSTALLER="${REPO_ROOT}/scripts/install-cursor-sb-agents.sh"
if [[ -x "$CSBA_INSTALLER" ]]; then
  # Scope the subagent config write to the project being installed for, when
  # one was named. Unscoped it defaults to this checkout, so installing for
  # another project rewrote Silver Bullet's own .silver-bullet.json.
  # Avoid empty-array expansion under `set -u` (bash 3.2 / some CI images).
  if [[ -n "${SB_RECONCILE_PROJECT_ROOT:-}" ]]; then
    export CSBA_REPO_ROOT="${SB_RECONCILE_PROJECT_ROOT}"
  fi
  if [[ -t 0 && -t 1 ]]; then
    bash "$CSBA_INSTALLER" --global || printf 'WARN: install-cursor-sb-agents.sh exited nonzero (continuing)\n' >&2
  else
    bash "$CSBA_INSTALLER" --global --non-interactive || printf 'WARN: install-cursor-sb-agents.sh exited nonzero (continuing)\n' >&2
  fi
fi

ln -sfn "$DEST_ROOT" "$(cursor_install_current_link)"
if [[ -z "${INSTALL_COMMIT_SHA:-}" ]] && git -C "$REPO_ROOT" rev-parse HEAD >/dev/null 2>&1; then
  INSTALL_COMMIT_SHA="$(resolve_install_commit_sha "$REPO_ROOT")"
fi
REGISTRY_COMMIT_SHA="$(resolve_cursor_registry_git_commit_sha "$INSTALL_COMMIT_SHA" "$LEGACY_MARKETPLACE_UI_SWITCH")"
ensure_cursor_installed_plugins_registry "$DEST_ROOT" "$VERSION" "$REGISTRY_COMMIT_SHA"
seed_cursor_marketplace_gitpaths_extended "$DEST_ROOT" "$REGISTRY_COMMIT_SHA" "$REPO_ROOT"
rematerialize_all_reachable_cursor_gitpaths "$DEST_ROOT"
sync_cursor_user_marketplace_manifest "$REGISTRY_COMMIT_SHA" "$VERSION"
seed_cursor_marketplace_gitpaths_extended "$DEST_ROOT" "$REGISTRY_COMMIT_SHA" "$REPO_ROOT"
ensure_cursor_local_plugin_link "$DEST_ROOT"
if ! verify_cursor_install_identity "$DEST_ROOT" "$VERSION" "$REGISTRY_COMMIT_SHA"; then
  printf 'ERROR: Cursor install identity is inconsistent — refusing to leave a partial install\n' >&2
  exit 1
fi
if ! verify_cursor_plugin_discovery_paths "$DEST_ROOT" "$REPO_ROOT"; then
  printf 'ERROR: Cursor plugin discovery paths incomplete — re-run: bash scripts/install-cursor.sh\n' >&2
  exit 1
fi

# Record install version key for enterprise E2E single-pass-at-version skip (matrix / T1).
if [[ -f "${REPO_ROOT}/scripts/enterprise-e2e/lib/core.sh" ]]; then
  # shellcheck source=scripts/enterprise-e2e/lib/core.sh
  source "${REPO_ROOT}/scripts/enterprise-e2e/lib/core.sh"
  SB_ROOT="$REPO_ROOT"
  export SB_ROOT
  _install_ver="$(enterprise_e2e_write_sb_install_version "$REPO_ROOT" "$VERSION" "$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo "${INSTALL_COMMIT_SHA:0:8}")")"
  printf 'SB install version key: %s (see .e2e-cursor-install-version.txt)\n' "$_install_ver"
fi

printf '\nCursor hook merge complete. SB hooks are in %s/hooks.json.\n' "$CURSOR_HOME"
printf 'If skills do not appear, reload the window or run: bash scripts/install-cursor.sh --merge-hooks-only\n'

if [[ "$PUBLIC_RELEASE_ONLY" -eq 1 ]]; then
  printf 'Silver Bullet Cursor plugin refreshed from %s at %s\n' "$CURSOR_SB_PUBLIC_MARKETPLACE_SOURCE" "$DEST_ROOT"
else
  printf 'Silver Bullet Cursor plugin synced to %s\n' "$DEST_ROOT"
fi

if [[ "$LEGACY_MARKETPLACE_UI_SWITCH" -eq 1 ]]; then
  printf 'Cursor marketplace: legacy clone removed — complete UI switch per notice above\n'
else
  printf 'Cursor marketplace: unified alo-labs/agent-plugins (%s)\n' "$CURSOR_MARKETPLACE_NAME"
fi

# Five-tool reconciler: deploy host snapshots + reconcile consented project tools when root supplied.
RT_INSTALLER_LIB="${REPO_ROOT}/scripts/lib/recommended-tools/installer.sh"
if [[ -f "$RT_INSTALLER_LIB" ]]; then
  # shellcheck source=scripts/lib/recommended-tools/installer.sh
  source "$RT_INSTALLER_LIB"
  _rt_project=""
  if [[ -n "${SB_RECONCILE_PROJECT_ROOT:-}" ]]; then
    _rt_project="$(cd "$SB_RECONCILE_PROJECT_ROOT" && pwd -P 2>/dev/null || true)"
  fi
  rt_installer_post_install "$REPO_ROOT" "$_rt_project" ||     printf 'WARN: reconciler post-install exited nonzero (host infra may still be usable)\n' >&2
  # Toolstack patchers rewrite ~/.cursor/hooks.json after the initial SB merge.
  # Re-merge so multi-matcher bridge entries (Read|Grep coordinator, site-regression
  # Shell, etc.) cannot be left missing when a host patcher drops or supersedes them.
  if [[ -d "$DEST_ROOT" && -f "$MERGE_HOOKS" ]]; then
    python3 "$MERGE_HOOKS" "$DEST_ROOT"
  fi
fi
