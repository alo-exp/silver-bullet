#!/usr/bin/env bash
# Codex install module — auto-split from install-codex.sh
regenerate_core_rules_pin() {
  local hooks_dir="$1"
  local core_rules="${hooks_dir}/core-rules.md"
  local pin_file="${hooks_dir}/core-rules.sha256"

  [[ -f "$core_rules" ]] || return 0
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$core_rules" | awk '{print $1}' >"$pin_file"
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$core_rules" | awk '{print $1}' >"$pin_file"
  else
    return 1
  fi
}

sanitize_codex_package_surface() {
  local marketplace_root
  local package_root

  marketplace_root="$(codex_marketplace_root)"
  package_root="${marketplace_root}/plugins/silver-bullet"

  [[ -d "$package_root" ]] || return 0

  if [[ -x "${SCRIPT_DIR}/codex-sanitize-package.sh" ]]; then
    "${SCRIPT_DIR}/codex-sanitize-package.sh" "$package_root"
  else
    printf 'ERROR: codex sanitizer helper missing at %s\n' "${SCRIPT_DIR}/codex-sanitize-package.sh" >&2
    exit 1
  fi

  # Codex sanitizer rewrites hooks/core-rules.md for runtime wording; refresh L-02 pin.
  regenerate_core_rules_pin "${package_root}/hooks"
}


sync_codex_cache_package_surface() {
  local marketplace_root
  marketplace_root="$(codex_marketplace_root)"
  [[ -d "${marketplace_root}/plugins/silver-bullet" ]] || return 0

  local cache_root="${CODEX_HOME_ROOT}/.codex/plugins/cache"
  local marketplace_package_root="${marketplace_root}/plugins/silver-bullet"
  local package_root="${cache_root}/alo-labs-codex/silver-bullet"
  local package_version
  local version_dir

  package_version="$(jq -r '.version // empty' "${marketplace_package_root}/.codex-plugin/plugin.json" 2>/dev/null || true)"
  [[ -n "$package_version" ]] || return 0

  mkdir -p "${package_root}/${package_version}"
  rsync -a --delete "${marketplace_package_root}/" "${package_root}/${package_version}/"
  regenerate_core_rules_pin "${package_root}/${package_version}/hooks"
  validate_silver_bullet_skill_surface "installed package" "${package_root}/${package_version}"

  shopt -s nullglob
  for version_dir in "$package_root"/*; do
    [[ -d "$version_dir" ]] || continue
    [[ "$(basename "$version_dir")" == "current" ]] && continue
    rsync -a --delete "${marketplace_root}/plugins/silver-bullet/" "${version_dir}/"
  done
  shopt -u nullglob
}


prune_stale_silver_bullet_cache_versions() {
  local package_root="${CODEX_HOME_ROOT}/.codex/plugins/cache/alo-labs-codex/silver-bullet"

  python3 - "$package_root" <<'PY'
import pathlib
import re
import shutil
import sys

package_root = pathlib.Path(sys.argv[1]).expanduser()
if not package_root.exists():
    sys.exit(0)


def version_sort_key(path: pathlib.Path):
    return tuple(int(part) if part.isdigit() else part for part in re.split(r"([0-9]+)", path.name))


version_dirs = sorted(
    [path for path in package_root.iterdir() if path.is_dir() and path.name != "current"],
    key=version_sort_key,
)
if len(version_dirs) <= 1:
    sys.exit(0)

latest = version_dirs[-1]
for stale in version_dirs[:-1]:
    shutil.rmtree(stale)

current = package_root / "current"
if current.exists() or current.is_symlink():
    if current.is_dir() and not current.is_symlink():
        shutil.rmtree(current)
    else:
        current.unlink()
current.symlink_to(latest.resolve())
PY
}


refresh_silver_bullet_current_alias() {
  local package_root="${CODEX_HOME_ROOT}/.codex/plugins/cache/alo-labs-codex/silver-bullet"

  python3 - "$package_root" <<'PY'
import pathlib
import re
import shutil
import sys

plugin_root = pathlib.Path(sys.argv[1]).expanduser()
if not plugin_root.exists():
    sys.exit(0)


def version_sort_key(path: pathlib.Path):
    return tuple(int(part) if part.isdigit() else part for part in re.split(r"([0-9]+)", path.name))


version_dirs = sorted(
    [path for path in plugin_root.iterdir() if path.is_dir() and path.name != "current"],
    key=version_sort_key,
)
if not version_dirs:
    sys.exit(0)

target_path = version_dirs[-1].resolve()
current_path = plugin_root / "current"
if current_path.exists() or current_path.is_symlink():
    if current_path.is_dir() and not current_path.is_symlink():
        shutil.rmtree(current_path)
    else:
        current_path.unlink()
current_path.symlink_to(target_path)
PY

  validate_silver_bullet_skill_surface "installed package alias" "${package_root}/current"
}


