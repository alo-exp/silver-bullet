#!/usr/bin/env bash
# Cursor backend marketplace cache + agent-plugins clone seeding for install-cursor.sh
set -euo pipefail

CURSOR_AGENT_PLUGINS_REPO_URL="${CURSOR_AGENT_PLUGINS_REPO_URL:-https://github.com/alo-labs/agent-plugins.git}"
CURSOR_AGENT_PLUGINS_GITPATH_ROOT="${CURSOR_AGENT_PLUGINS_GITPATH_ROOT:-${CURSOR_HOME}/plugins/marketplaces/github.com/alo-labs/agent-plugins}"

cursor_backend_plugin_cache_root() {
  printf '%s/plugins/cache/%s/silver-bullet\n' "$CURSOR_HOME" "$CURSOR_BACKEND_MARKETPLACE_NAME"
}

cursor_cursor_logs_root() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    printf '%s/Library/Application Support/Cursor/logs\n' "$HOME"
    return 0
  fi
  printf '%s/.config/Cursor/logs\n' "$HOME"
}

cursor_github_commit_reachable() {
  local sha="$1"
  local source_root="${2:-${REPO_ROOT:-.}}"

  [[ -n "$sha" ]] || return 1
  if git -C "$source_root" cat-file -e "${sha}^{commit}" >/dev/null 2>&1; then
    return 0
  fi
  git ls-remote --exit-code "$CURSOR_GITHUB_REPO_URL" "$sha" >/dev/null 2>&1
}

prune_stale_cursor_marketplace_cache_links() {
  local keep_sha="${1:-}"
  local cache_root entry name

  cache_root="$(cursor_marketplace_plugin_cache_root)"
  [[ -d "$cache_root" ]] || return 0

  for entry in "$cache_root"/*; do
    [[ -e "$entry" ]] || continue
    name="$(basename "$entry")"
    [[ "$name" =~ ^[0-9a-f]{40}$ ]] || continue
    if [[ -n "$keep_sha" && "$name" == "$keep_sha" ]]; then
      continue
    fi
    if cursor_github_commit_reachable "$name"; then
      continue
    fi
    rm -f "$entry"
    printf 'Note: pruned stale Cursor marketplace cache symlink for unreachable commit %s\n' "${name:0:8}" >&2
  done
}

prune_stale_cursor_marketplace_gitpaths() {
  local keep_sha="${1:-}"
  local base_root entry name

  if declare -F cursor_github_marketplace_gitpath_root >/dev/null 2>&1; then
    base_root="$(cursor_github_marketplace_gitpath_root)"
  else
    base_root="${CURSOR_HOME}/plugins/marketplaces/github.com/${CURSOR_GITHUB_REPO_SLUG:-alo-exp/silver-bullet}"
  fi
  [[ -d "$base_root" ]] || return 0

  for entry in "$base_root"/*; do
    [[ -e "$entry" ]] || continue
    name="$(basename "$entry")"
    [[ "$name" =~ ^[0-9a-f]{40}$ ]] || continue
    if [[ -n "$keep_sha" && "$name" == "$keep_sha" ]]; then
      continue
    fi
    if cursor_github_commit_reachable "$name"; then
      continue
    fi
    rm -rf "$entry"
    printf 'Note: pruned stale Cursor gitPath checkout for unreachable commit %s\n' "${name:0:8}" >&2
  done
}

discover_cursor_backend_plugin_shas() {
  local log_root latest_sha
  log_root="$(cursor_cursor_logs_root)"
  if [[ ! -d "$log_root" ]]; then
    return 0
  fi

  latest_sha="$(
    find "$log_root" -name 'Cursor Plugins*.log' -type f -print0 2>/dev/null \
      | xargs -0 grep -h 'Adding enabled plugin: silver-bullet from ' 2>/dev/null \
      | sed -n 's/.*silver-bullet from \([0-9a-f]\{40\}\).*/\1/p' \
      | tail -1
  )"
  [[ -n "$latest_sha" ]] && printf '%s\n' "$latest_sha"
  find "$log_root" -name 'Cursor Plugins*.log' -type f -print0 2>/dev/null \
    | xargs -0 grep -h 'Adding enabled plugin: silver-bullet from ' 2>/dev/null \
    | sed -n 's/.*silver-bullet from \([0-9a-f]\{40\}\).*/\1/p' \
    | sort -u
}

collect_cursor_plugin_required_shas() {
  while IFS= read -r sha; do
    [[ -n "$sha" ]] || continue
    if cursor_github_commit_reachable "$sha"; then
      printf '%s\n' "$sha"
    fi
  done < <(
    {
      printf '%s\n' "$1" "$2"
      read_installed_plugins_git_sha
      read_marketplace_manifest_sha
      discover_cursor_backend_plugin_shas
    } | awk 'NF && !seen[$0]++'
  )
}

# Narrower set for post-install verify — avoids failing on stale marketplace
# manifest SHAs that were not seeded before manifest sync.
collect_cursor_plugin_verify_shas() {
  local primary_sha="${1:-}"
  local backend_sha="${2:-}"
  local registry_sha

  registry_sha="$(read_installed_plugins_git_sha)"
  while IFS= read -r sha; do
    [[ -n "$sha" ]] || continue
    if cursor_github_commit_reachable "$sha"; then
      printf '%s\n' "$sha"
    fi
  done < <(
    {
      printf '%s\n' "$primary_sha" "$registry_sha" "$backend_sha"
    } | awk 'NF && !seen[$0]++'
  )
}


prune_cursor_picker_surfaces_from_cache_dir() {
  local entry="$1"
  local sha_label
  sha_label="$(basename "$entry" | cut -c1-8)"

  for surface in \
    agents \
    skills \
    skill-source \
    host-bundles \
    .agents \
    .cursor/agents \
    plugins/silver-bullet/agents \
    plugins/silver-bullet/skills \
    plugins/silver-bullet/skill-source \
    plugins/silver-bullet/templates
  do
    if [[ -e "${entry}/${surface}" ]]; then
      rm -rf "${entry:?}/${surface}"
      printf 'Note: pruned %s from Cursor backend cache %s (commands-only / picker)\n' "$surface" "$sha_label" >&2
    fi
  done
}

prune_agents_from_all_cursor_backend_caches() {
  local cache_root entry
  cache_root="$(cursor_backend_plugin_cache_root)"
  [[ -d "$cache_root" ]] || return 0
  for entry in "$cache_root"/*; do
    [[ -d "$entry" ]] || continue
    prune_cursor_picker_surfaces_from_cache_dir "$entry"
  done
}

cleanup_cursor_custom_agents() {
  local project_root="${1:-${REPO_ROOT:-}}"
  python3 - "$CURSOR_HOME" "$project_root" <<'INNERPY'
from __future__ import annotations

import json
import re
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

cursor_home = Path(sys.argv[1]).expanduser()
project_root = Path(sys.argv[2]).expanduser() if sys.argv[2] else None
roots: list[tuple[str, Path]] = [("user", cursor_home / "agents")]
if project_root:
    roots.append(("project", project_root / ".cursor" / "agents"))

bad_exact = {
    "subagent-tdd",
    "tdd",
    "full-conversation",
    "ai-llm-safety",
    "artifact-reviewer",
    "devops-skill-router",
}
bad_prefixes = ("silver", "subagent-silver", "subagent-sb", "subagent-devops", "principle-sequence")


def parse_frontmatter(path: Path) -> dict[str, str]:
    try:
        text = path.read_text(errors="ignore")[:4000]
    except Exception:
        return {}
    match = re.match(r"^---\n(.*?)\n---", text, re.S)
    meta: dict[str, str] = {}
    if match:
        for line in match.group(1).splitlines():
            if ":" in line:
                key, value = line.split(":", 1)
                meta[key.strip()] = value.strip().strip('"')
    if path.suffix == ".json":
        try:
            data = json.loads(path.read_text(errors="ignore"))
            for key in ("name", "title"):
                if isinstance(data.get(key), str):
                    meta[key] = data[key]
        except Exception:
            pass
    return meta


def should_quarantine(path: Path) -> bool:
    meta = parse_frontmatter(path)
    name = meta.get("name") or meta.get("title") or path.stem
    lowered = name.strip().lower()
    if lowered in bad_exact or lowered.startswith(bad_prefixes):
        return True
    try:
        text = path.read_text(errors="ignore")[:4000]
    except Exception:
        text = ""
    return "Silver Bullet" in text or "silver-bullet" in text


def quarantine_path(scope: str, root: Path, path: Path, bucket: Path) -> None:
    try:
        rel = path.relative_to(root)
    except ValueError:
        rel = Path(path.name)
    target = bucket / scope / rel
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        target = target.with_name(target.name + ".duplicate")
    shutil.move(str(path), str(target))
    print(f"Note: quarantined Cursor custom agent {path} -> {target}", file=sys.stderr)

bucket = cursor_home / ".silver-bullet-quarantine" / "cursor-agents" / datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
for scope, root in roots:
    if not root.is_dir():
        continue
    candidates: list[Path] = []
    for item in sorted(root.glob("**/*"), key=lambda p: len(p.parts), reverse=True):
        if item.is_file() and item.suffix.lower() in {".md", ".json", ".yaml", ".yml"} and should_quarantine(item):
            candidates.append(item)
    for item in candidates:
        if not item.exists():
            continue
        parent = item.parent
        if item.name == "SKILL.md" and parent != root:
            quarantine_path(scope, root, parent, bucket)
        else:
            quarantine_path(scope, root, item, bucket)
INNERPY
}

collect_cursor_plugin_seed_shas() {
  local primary_sha="${1:-}"
  local backend_sha="${2:-}"

  prune_stale_cursor_marketplace_cache_links "$primary_sha"
  prune_stale_cursor_marketplace_gitpaths "$primary_sha"
  # Stale backend/custom dirs may still contain skills, agents, or templates from older installs;
  # cursor-agent loads every enabled backend cache and custom agent dir into the / picker.
  prune_agents_from_all_cursor_backend_caches
  cleanup_cursor_custom_agents "${REPO_ROOT:-}"

  while IFS= read -r sha; do
    [[ -n "$sha" ]] || continue
    if cursor_github_commit_reachable "$sha"; then
      printf '%s\n' "$sha"
    fi
  done < <(
    {
      collect_cursor_plugin_required_shas "$primary_sha" "$backend_sha"
      resolve_remote_github_head_sha
      collect_cursor_marketplace_cache_shas
    } | awk 'NF && !seen[$0]++'
  )
}

resolve_cursor_backend_plugin_sha() {
  local discovered manifest_sha install_sha
  while IFS= read -r discovered; do
    [[ -n "$discovered" ]] || continue
    if cursor_github_commit_reachable "$discovered"; then
      printf '%s\n' "$discovered"
      return 0
    fi
  done < <(discover_cursor_backend_plugin_shas)
  manifest_sha="$(read_marketplace_manifest_sha)"
  if [[ -n "$manifest_sha" ]] && cursor_github_commit_reachable "$manifest_sha"; then
    printf '%s\n' "$manifest_sha"
    return 0
  fi
  if [[ -n "${1:-}" ]] && cursor_github_commit_reachable "${1}"; then
    printf '%s\n' "${1}"
    return 0
  fi
  printf '%s\n' "${1:-}"
}

materialize_cursor_plugin_surface_into_dir() {
  local source_dest="$1"
  local target_root="$2"

  mkdir -p "${target_root}/.cursor-plugin"
  if [[ -d "${source_dest}/commands" ]]; then
    mkdir -p "${target_root}/commands"
    rsync -a --delete "${source_dest}/commands/" "${target_root}/commands/"
  else
    rm -rf "${target_root}/commands"
  fi
  # Backend cache is commands-only — skill-source stays in the primary install cache only.
  prune_cursor_picker_surfaces_from_cache_dir "$target_root"
  if [[ -f "${source_dest}/cursor-hooks.json" ]]; then
    install -m 644 "${source_dest}/cursor-hooks.json" "${target_root}/cursor-hooks.json"
  fi
  if [[ -f "${source_dest}/.cursor-plugin/plugin.json" ]]; then
    install -m 644 "${source_dest}/.cursor-plugin/plugin.json" "${target_root}/.cursor-plugin/plugin.json"
  fi
}

ensure_cursor_local_plugin_link() {
  local dest="$1"
  local local_root="${CURSOR_HOME}/plugins/local"
  local local_plugin="${local_root}/silver-bullet"

  [[ -n "$dest" && -d "$dest" ]] || return 0
  mkdir -p "$local_root"
  # Cursor desktop rejects symlinks whose resolved target is outside plugins/local
  # (Cursor Plugins log: loadUserLocalPlugin rejected: symlink target ... is outside ...).
  # Materialize commands-only surface directly under plugins/local/ per
  # https://cursor.com/docs/plugins and https://github.com/cursor/plugins/issues/35
  if [[ -L "$local_plugin" ]]; then
    rm -f "$local_plugin"
  fi
  mkdir -p "$local_plugin"
  materialize_cursor_plugin_surface_into_dir "$dest" "$local_plugin"
  printf 'Cursor local plugin surface: %s (materialized from %s)\n' "$local_plugin" "$dest" >&2
}

cursor_plugin_command_filename_colon_count() {
  local root="$1"
  local count=0
  local command_file

  for command_file in "$root"/commands/*.md; do
    [[ -f "$command_file" ]] || continue
    case "$(basename "$command_file")" in
      *:*) count=$((count + 1)) ;;
    esac
  done
  printf '%s\n' "$count"
}

cursor_plugin_commands_surface_ready() {
  local root="$1"
  local router="${root}/commands/sb.md"
  local init="${root}/commands/sb-init.md"

  [[ -f "$router" ]] || return 1
  [[ -f "$init" ]] || return 1
  grep -q '^name: "sb"$' "$router" || return 1
  grep -q '^name: "sb-init"$' "$init" || return 1
  [[ "$(cursor_plugin_command_filename_colon_count "$root")" -eq 0 ]]
}

cursor_local_plugin_link_ready() {
  local dest="$1"
  local local_plugin="${CURSOR_HOME}/plugins/local/silver-bullet"
  local resolved_dest

  [[ -n "$dest" && -d "$dest" ]] || return 1
  [[ -d "$local_plugin" ]] || return 1
  [[ ! -L "$local_plugin" ]] || return 1
  cursor_plugin_commands_surface_ready "$local_plugin" || return 1
  [[ -f "${local_plugin}/.cursor-plugin/plugin.json" ]] || return 1
  jq -e '.commands == "./commands"' "${local_plugin}/.cursor-plugin/plugin.json" >/dev/null 2>&1 || return 1
  resolved_dest="$(cd "$dest" && pwd -P)"
  [[ "$(jq -r '.version // empty' "${local_plugin}/.cursor-plugin/plugin.json")" == \
     "$(jq -r '.version // empty' "${resolved_dest}/.cursor-plugin/plugin.json")" ]]
}

sync_cursor_user_marketplace_manifest() {
  local commit_sha="${1:-}"
  local version="${2:-}"
  local source_manifest="${REPO_ROOT}/.cursor-plugin/marketplace.json"
  local dest_manifest="${CURSOR_MARKETPLACE_ROOT}/.cursor-plugin/marketplace.json"
  local tmp

  [[ -f "$source_manifest" ]] || return 0
  mkdir -p "$(dirname "$dest_manifest")"
  tmp="$(mktemp)"
  if [[ -n "$commit_sha" && -n "$version" ]]; then
    python3 - "$source_manifest" "$tmp" "$commit_sha" "$version" <<'PY'
import json
import pathlib
import sys

src = pathlib.Path(sys.argv[1])
dst = pathlib.Path(sys.argv[2])
commit_sha = sys.argv[3]
version = sys.argv[4]
data = json.loads(src.read_text())
for plugin in data.get("plugins", []):
    if plugin.get("name") != "silver-bullet":
        continue
    plugin["version"] = version
    source = plugin.setdefault("source", {})
    source["sha"] = commit_sha
    source["ref"] = commit_sha
    break
dst.write_text(json.dumps(data, indent=2) + "\n")
PY
    install -m 644 "$tmp" "$dest_manifest"
  else
    install -m 644 "$source_manifest" "$dest_manifest"
  fi
  rm -f -- "$tmp"
  printf 'Synced Cursor user marketplace manifest to %s\n' "$dest_manifest" >&2
}


ensure_cursor_backend_plugin_cache_dir() {
  local dest="$1"
  local commit_sha="$2"
  local cache_path

  [[ -n "$commit_sha" ]] || return 0

  cache_path="$(cursor_backend_plugin_cache_root)/${commit_sha}"
  mkdir -p "$(cursor_backend_plugin_cache_root)"

  if [[ -L "$cache_path" ]]; then
    rm -f "$cache_path"
  fi
  if [[ -e "$cache_path" && ! -d "$cache_path" ]]; then
    rm -f "$cache_path"
  fi
  mkdir -p "$cache_path"

  materialize_cursor_plugin_surface_into_dir "$dest" "$cache_path"
  : > "${cache_path}/.cache-complete"
}

cursor_backend_plugin_cache_ready() {
  local dest="$1"
  local commit_sha="$2"
  local cache_path resolved_dest

  [[ -n "$commit_sha" ]] || return 1
  cache_path="$(cursor_backend_plugin_cache_root)/${commit_sha}"
  [[ -d "$cache_path" ]] || return 1
  [[ -f "${cache_path}/.cache-complete" ]] || return 1
  cursor_plugin_commands_surface_ready "$cache_path" || return 1
  [[ -f "${cache_path}/.cursor-plugin/plugin.json" ]] || return 1
  [[ ! -d "${cache_path}/skill-source" ]] || return 1
  jq -e '.commands == "./commands"' "${cache_path}/.cursor-plugin/plugin.json" >/dev/null 2>&1 || return 1
  resolved_dest="$(cd "$dest" && pwd -P)"
  [[ "$(jq -r '.version // empty' "${cache_path}/.cursor-plugin/plugin.json")" == "$(jq -r '.version // empty' "${resolved_dest}/.cursor-plugin/plugin.json")" ]]
}

ensure_agent_plugins_marketplace_clone() {
  local head_sha dest_root tmp

  head_sha="$(git ls-remote "$CURSOR_AGENT_PLUGINS_REPO_URL" HEAD 2>/dev/null | awk 'NR==1 {print $1}')"
  [[ -n "$head_sha" ]] || return 0

  dest_root="${CURSOR_AGENT_PLUGINS_GITPATH_ROOT}/${head_sha}"
  if [[ -d "${dest_root}/.git" ]] && git -C "$dest_root" cat-file -e "${head_sha}^{commit}" >/dev/null 2>&1; then
    return 0
  fi

  mkdir -p "$(dirname "$CURSOR_AGENT_PLUGINS_GITPATH_ROOT")"
  if [[ -d "$dest_root" ]]; then
    rm -rf "$dest_root"
  fi

  if ! git clone --depth 1 "$CURSOR_AGENT_PLUGINS_REPO_URL" "$dest_root" >/dev/null 2>&1; then
    tmp="$(mktemp -d "${TMPDIR:-/tmp}/sb-agent-plugins-clone.XXXXXX")"
    if git clone --depth 1 "$CURSOR_AGENT_PLUGINS_REPO_URL" "$tmp" >/dev/null 2>&1; then
      mkdir -p "$(dirname "$dest_root")"
      mv "$tmp" "$dest_root"
    else
      rm -rf -- "$tmp"
      return 0
    fi
  fi
}

cursor_plugin_gitpath_root_surface_ready() {
  local commit_sha="$1"
  local gitpath_root

  cursor_plugin_gitpath_ready "$commit_sha" || return 1
  gitpath_root="$(cursor_github_marketplace_gitpath_for_sha "$commit_sha")"
  cursor_plugin_commands_surface_ready "$gitpath_root" || return 1
  [[ -f "${gitpath_root}/.cursor-plugin/plugin.json" ]] || return 1
  jq -e '.commands == "./commands"' "${gitpath_root}/.cursor-plugin/plugin.json" >/dev/null 2>&1 || return 1
  [[ ! -f "${gitpath_root}/skills/silver-feature/SKILL.md" ]]
}
