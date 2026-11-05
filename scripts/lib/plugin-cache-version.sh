#!/usr/bin/env bash
# Shared plugin-cache version resolution for Claude/Cursor install scripts.
# Only version-named directories (v?MAJOR.MINOR.PATCH[-pre][+build]) with a
# plugin surface count: the stable alias (current), orphaned markers and other
# directories (test/, dev/) never win, whatever they contain.
set -euo pipefail

# Print absolute path to the latest semver-like version directory under plugin_root.
# Returns 0 with stdout path, or 1 when no valid version dir exists.
sb_plugin_cache_latest_version_dir() {
  local plugin_root="${1:-}"
  [[ -n "$plugin_root" && -d "$plugin_root" ]] || return 1
  command -v python3 >/dev/null 2>&1 || return 1

  python3 - "$plugin_root" <<'PY'
import pathlib
import re
import sys

plugin_root = pathlib.Path(sys.argv[1]).expanduser().resolve()
if not plugin_root.is_dir():
    sys.exit(1)


VERSION_RE = re.compile(
    r"^v?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)"
    r"(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+[0-9A-Za-z.-]+)?$"
)


def version_sort_key(path: pathlib.Path):
    """Semver precedence: a pre-release ranks below its release; pre-release
    identifiers compare numerically when numeric, numeric below alphanumeric,
    and a longer list above its prefix. Build metadata is ignored."""
    major, minor, patch, pre = VERSION_RE.match(path.name).groups()
    if pre is None:
        return (int(major), int(minor), int(patch), 1, ())
    identifiers = tuple(
        (0, int(part), "") if part.isdigit() else (1, 0, part) for part in pre.split(".")
    )
    return (int(major), int(minor), int(patch), 0, identifiers)


def is_valid_version_dir(path: pathlib.Path) -> bool:
    if not path.is_dir() or not VERSION_RE.match(path.name):
        return False
    # A version dir that holds only an .orphaned_at marker has no surface.
    has_plugin = (path / ".claude-plugin" / "plugin.json").is_file()
    has_codex_plugin = (path / ".codex-plugin" / "plugin.json").is_file()
    has_hooks = (path / "hooks").is_dir()
    return has_plugin or has_codex_plugin or has_hooks


version_dirs = sorted(
    [path for path in plugin_root.iterdir() if is_valid_version_dir(path)],
    key=version_sort_key,
)
if not version_dirs:
    sys.exit(1)

print(version_dirs[-1])
PY
}

# Refresh plugin_root/current → latest valid version directory.
sb_plugin_cache_refresh_current_alias() {
  local plugin_root="${1:-}"
  local latest=""
  [[ -n "$plugin_root" && -d "$plugin_root" ]] || return 0
  latest="$(sb_plugin_cache_latest_version_dir "$plugin_root" 2>/dev/null || true)"
  [[ -n "$latest" ]] || return 0
  command -v python3 >/dev/null 2>&1 || return 0

  python3 - "$latest" "${plugin_root}/current" <<'PY'
import pathlib
import shutil
import sys

target = pathlib.Path(sys.argv[1]).resolve()
alias_path = pathlib.Path(sys.argv[2])
alias_path.parent.mkdir(parents=True, exist_ok=True)
if alias_path.exists() or alias_path.is_symlink():
    if alias_path.is_dir() and not alias_path.is_symlink():
        shutil.rmtree(alias_path)
    else:
        alias_path.unlink()
alias_path.symlink_to(target)
PY
}

# Remove orphaned cache directories (only .orphaned_at marker, no plugin surface).
sb_plugin_cache_prune_orphaned_dirs() {
  local plugin_root="${1:-}"
  [[ -n "$plugin_root" && -d "$plugin_root" ]] || return 0
  command -v python3 >/dev/null 2>&1 || return 0

  python3 - "$plugin_root" <<'PY'
import pathlib
import shutil
import sys

plugin_root = pathlib.Path(sys.argv[1]).expanduser().resolve()
if not plugin_root.is_dir():
    sys.exit(0)

for child in plugin_root.iterdir():
    if not child.is_dir() or child.name == "current":
        continue
    if not (child / ".orphaned_at").is_file():
        continue
    has_plugin = (child / ".claude-plugin" / "plugin.json").is_file()
    has_hooks = (child / "hooks").is_dir()
    if has_plugin or has_hooks:
        continue
    shutil.rmtree(child, ignore_errors=True)
PY
}

# Ensure Claude Silver Bullet plugin cache has current alias + hooks (dev checkout).
sb_claude_ensure_plugin_cache_ready() {
  local repo_root="${1:-}"
  local cache_root="${HOME}/.claude/plugins/cache/alo-labs/silver-bullet"
  local latest=""

  [[ -d "$cache_root" ]] || return 1

  sb_plugin_cache_prune_orphaned_dirs "$cache_root"
  sb_plugin_cache_refresh_current_alias "$cache_root"
  latest="$(sb_plugin_cache_latest_version_dir "$cache_root" 2>/dev/null || true)"
  [[ -n "$latest" ]] || return 1

  # Copy hooks only from a Silver Bullet source checkout (R2-12/R8-07): a project that merely
  # has a hooks/ directory must never overwrite the installed plugin.
  if [[ -n "$repo_root" && -d "${repo_root}/hooks" ]] \
     && [[ "$(jq -r '.name // ""' "${repo_root}/.claude-plugin/plugin.json" 2>/dev/null || true)" == "silver-bullet" ]]; then
    install -d -m 755 "${latest}/hooks"
    rsync -a --chmod=Du=rwx,go=rx,Fu=rx,Fgo=rx \
      "${repo_root}/hooks/" "${latest}/hooks/"
  fi

  [[ -L "${cache_root}/current" || -d "${cache_root}/current" ]] || return 1
  [[ -f "${cache_root}/current/hooks/session-start" || -x "${cache_root}/current/hooks/session-start" ]] || return 1
  return 0
}
