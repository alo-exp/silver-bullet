#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
AGENT_RENDERER="${SCRIPT_DIR}/render-agent-bundle.py"
PURGE_LEGACY_SKILLS=0
PUBLIC_RELEASE_ONLY=0
# Native Codex loads plugin-declared hooks directly, so merging the same SB
# hook bundle into ~/.codex/hooks.json duplicates delivery. Kay still relies on
# the merged user-hook surface, so keep merge enabled there unless explicitly
# overridden.
if [[ -n "${SB_CODEX_MERGE_USER_HOOKS:-}" ]]; then
  MERGE_USER_HOOKS="${SB_CODEX_MERGE_USER_HOOKS}"
elif [[ -n "${KAY_HOME:-}" ]]; then
  MERGE_USER_HOOKS=1
else
  MERGE_USER_HOOKS=0
fi
CODEX_BIN="${CODEX_BIN:-codex}"
NPM_BIN="${NPM_BIN:-npx}"
# `npm exec` / `npx` can prompt for confirmation when installing a fresh
# package. Force non-interactive mode so release and isolated live tests do not
# stall waiting for stdin.
GSD_INSTALL_CMD="${GSD_INSTALL_CMD:-${NPM_BIN} --yes get-shit-done-cc@latest}"
CODEX_MARKETPLACE_SOURCE="${CODEX_MARKETPLACE_SOURCE:-https://github.com/alo-labs/codex-plugins}"
CODEX_MARKETPLACE_LEGACY_NAME="${CODEX_MARKETPLACE_LEGACY_NAME:-silver-bullet-local}"
SUPERPOWERS_MARKETPLACE_SOURCE="${SUPERPOWERS_MARKETPLACE_SOURCE:-https://github.com/obra/superpowers-marketplace.git}"
GSD_MARKETPLACE_SOURCE="${GSD_MARKETPLACE_SOURCE:-https://github.com/gsd-build/get-shit-done.git}"
CODEX_HOME_ROOT="${KAY_HOME:-${HOME}}"

resolve_codex_config_file() {
  local config_file="${CODEX_HOME_ROOT}/.codex/config.toml"
  mkdir -p "${CODEX_HOME_ROOT}/.codex"
  if [[ -f "$config_file" ]]; then
    printf '%s\n' "$config_file"
    return 0
  fi
  printf '%s\n' "${CODEX_HOME_ROOT}/.codex/config.toml"
}

resolve_codex_gsd_home() {
  local gsd_home="${CODEX_HOME_ROOT}/.codex/get-shit-done"
  if [[ -f "${gsd_home}/VERSION" ]]; then
    printf '%s\n' "$gsd_home"
    return 0
  fi
  printf '%s\n' "${CODEX_HOME_ROOT}/.codex/get-shit-done"
}

render_agent_bundle() {
  local agent="$1"

  mkdir -p "${REPO_ROOT}/agents"
  python3 "$AGENT_RENDERER" render \
    --agent "$agent" \
    --source-root "${REPO_ROOT}/skills" \
    --dest-root "${REPO_ROOT}/agents/${agent}"
}

usage() {
  cat <<'USAGE'
Usage: scripts/install-codex.sh [--purge-legacy-skills] [--public-release]

Synchronizes the local Codex plugin package and registers the shared
`alo-labs/codex-plugins` marketplace with Codex. Also ensures the official
dependency sources are present.

Options:
  --purge-legacy-skills  Remove SB skill directories already copied into ~/.agents/skills
  --public-release       Refresh from the published Codex marketplace instead of the local checkout
USAGE
}

remove_marketplace_if_present() {
  local marketplace_name="$1"
  local config_file
  config_file="$(resolve_codex_config_file)"

  [[ -f "$config_file" ]] || return 0

  python3 - "$config_file" "$marketplace_name" <<'PY'
import pathlib
import sys

config_path = pathlib.Path(sys.argv[1])
marketplace_name = sys.argv[2]
text = config_path.read_text() if config_path.exists() else ''
lines = text.splitlines()
output = []
i = 0
removed = False
header = f'[marketplaces.{marketplace_name}]'

while i < len(lines):
    line = lines[i]
    if line.strip() == header:
        removed = True
        i += 1
        while i < len(lines) and not lines[i].startswith('['):
            i += 1
        continue
    output.append(line)
    i += 1

if removed:
    new_text = '\n'.join(output)
    if text.endswith('\n'):
        new_text += '\n'
    config_path.write_text(new_text)
PY
}

ensure_marketplace_registered() {
  local source_spec="$1"
  local marketplace_name="${2:-}"
  local config_file
  config_file="$(resolve_codex_config_file)"

  python3 - "$config_file" "$source_spec" "$marketplace_name" <<'PY'
import pathlib
import sys

config_path = pathlib.Path(sys.argv[1])
source_spec = sys.argv[2]
marketplace_name = sys.argv[3] or ('superpowers-marketplace' if 'superpowers' in source_spec else 'alo-labs-codex')
source_type = 'local' if source_spec.startswith('/') else 'git'
config_path.parent.mkdir(parents=True, exist_ok=True)
text = config_path.read_text() if config_path.exists() else ''
lines = text.splitlines()
output = []
i = 0
found = False
header = f'[marketplaces.{marketplace_name}]'

while i < len(lines):
    line = lines[i]
    if line.strip() == header:
        found = True
        output.append(line)
        i += 1

        section_lines = []
        source_type_seen = False
        source_seen = False
        while i < len(lines) and not lines[i].startswith('['):
            section_line = lines[i]
            stripped = section_line.strip()
            if stripped.startswith('source_type ='):
                section_lines.append(f'source_type = "{source_type}"')
                source_type_seen = True
            elif stripped.startswith('source ='):
                section_lines.append(f'source = "{source_spec}"')
                source_seen = True
            else:
                section_lines.append(section_line)
            i += 1

        if not source_type_seen:
            output.append(f'source_type = "{source_type}"')
        if not source_seen:
            output.append(f'source = "{source_spec}"')
        output.extend(section_lines)
        continue

    output.append(line)
    i += 1

if found:
    new_text = '\n'.join(output)
    if text.endswith('\n'):
        new_text += '\n'
    config_path.write_text(new_text)
else:
    if text and not text.endswith('\n'):
        text += '\n'
    text += f'\n{header}\nsource_type = "{source_type}"\nsource = "{source_spec}"\n'
    config_path.write_text(text)
PY
}

refresh_marketplace() {
  local marketplace_name="$1"
  local marketplace_root
  marketplace_root="$(codex_marketplace_root)"

  if [[ -d "${marketplace_root}/.git" ]]; then
    git -C "$marketplace_root" fetch --all --prune >/dev/null 2>&1 || true
    git -C "$marketplace_root" pull --ff-only >/dev/null 2>&1 || true
  fi
}

seed_marketplace_snapshot_if_missing() {
  local marketplace_root
  local package_root

  marketplace_root="$(codex_marketplace_root)"
  package_root="${marketplace_root}/plugins/silver-bullet"

  if [[ -f "${package_root}/.codex-plugin/plugin.json" ]]; then
    return 0
  fi

  mkdir -p "$(dirname "$marketplace_root")"
  rsync -a "${REPO_ROOT}/" "${marketplace_root}/"
}

sync_marketplace_package_surface() {
  local marketplace_root
  marketplace_root="$(codex_marketplace_root)"

  mkdir -p "$marketplace_root"

  resolve_realpath() {
    python3 - "$1" <<'PY'
import os
import sys
print(os.path.realpath(sys.argv[1]))
PY
  }

  local dir
  for dir in agents hooks skills templates docs commands scripts; do
    if [[ -d "${REPO_ROOT}/${dir}" ]]; then
      local src_dir="${REPO_ROOT}/${dir}"
      local dst_dir="${marketplace_root}/${dir}"
      if [[ -e "$dst_dir" ]] && [[ ! -L "$dst_dir" ]] && [[ "$(resolve_realpath "$src_dir")" == "$(resolve_realpath "$dst_dir")" ]]; then
        continue
      fi
      if [[ -L "$dst_dir" ]]; then
        rm -rf "$dst_dir"
      fi
      mkdir -p "$dst_dir"
      rsync -a --delete "${src_dir}/" "${dst_dir}/"
    fi
  done

  local file
  for file in \
    AGENTS.md \
    CHANGELOG.md \
    CODE_OF_CONDUCT.md \
    CONTRIBUTING.md \
    LICENSE \
    README.md \
    SECURITY.md \
    SENTINEL-audit-silver-bullet-v0.15.1.md \
    SENTINEL-audit-silver-init.md \
    .silver-bullet.json \
    silver-bullet.md; do
    if [[ -e "${REPO_ROOT}/${file}" ]]; then
      local src_file="${REPO_ROOT}/${file}"
      local dst_file="${marketplace_root}/${file}"
      if [[ -e "$dst_file" ]] && [[ ! -L "$dst_file" ]] && [[ "$(resolve_realpath "$src_file")" == "$(resolve_realpath "$dst_file")" ]]; then
        continue
      fi
      if [[ -L "$dst_file" ]]; then
        rm -f "$dst_file"
      fi
      cp -p "$src_file" "$dst_file"
    fi
  done
}

sync_marketplace_package_snapshot() {
  local marketplace_root
  local package_root

  marketplace_root="$(codex_marketplace_root)"
  package_root="${marketplace_root}/plugins/silver-bullet"

  [[ -d "${REPO_ROOT}/plugins/silver-bullet" ]] || return 0
  mkdir -p "$package_root"

  # Keep the marketplace package root in lockstep with the repo's generated
  # plugin snapshot, including `.generated-skills/` where Codex reads the
  # routed skill bodies during live runs.
  rsync -a --delete "${REPO_ROOT}/plugins/silver-bullet/" "${package_root}/"
}

materialize_silver_bullet_package() {
  local marketplace_root
  local package_root

  marketplace_root="$(codex_marketplace_root)"
  package_root="${marketplace_root}/plugins/silver-bullet"

  [[ -d "$package_root" ]] || return 0

  # Codex's cache materialization can drop symlink-backed package entries.
  # Replace SB's symlinked top-level package surface with real files/dirs so
  # hooks/hooks.json, agents/, skills/, templates/, and the rest survive install-time
  # copying into the versioned cache.
  python3 - "$package_root" <<'PY'
import pathlib
import shutil
import sys

package_root = pathlib.Path(sys.argv[1])

for entry in sorted(package_root.iterdir(), key=lambda p: p.name):
    if not entry.is_symlink():
        continue

    target = entry.resolve()
    materialized = entry.with_name(f".materialized-{entry.name}")

    if materialized.exists() or materialized.is_symlink():
        if materialized.is_dir() and not materialized.is_symlink():
            shutil.rmtree(materialized)
        else:
            materialized.unlink()

    if target.is_dir():
        shutil.copytree(target, materialized, symlinks=False)
    else:
        shutil.copy2(target, materialized)

    entry.unlink()
    materialized.rename(entry)
PY
}

sync_materialized_package_surface() {
  local marketplace_root
  local package_root

  marketplace_root="$(codex_marketplace_root)"
  package_root="${marketplace_root}/plugins/silver-bullet"

  [[ -d "$package_root" ]] || return 0

  local dir
  for dir in agents hooks skills templates docs commands scripts; do
    if [[ -d "${marketplace_root}/${dir}" ]]; then
      mkdir -p "${package_root}/${dir}"
      rsync -a --delete "${marketplace_root}/${dir}/" "${package_root}/${dir}/"
    fi
  done

  local file
  for file in \
    AGENTS.md \
    CHANGELOG.md \
    CODE_OF_CONDUCT.md \
    CONTRIBUTING.md \
    LICENSE \
    README.md \
    SECURITY.md \
    SENTINEL-audit-silver-bullet-v0.15.1.md \
    SENTINEL-audit-silver-init.md \
    .silver-bullet.json \
    silver-bullet.md; do
    if [[ -e "${marketplace_root}/${file}" ]]; then
      cp -p "${marketplace_root}/${file}" "${package_root}/${file}"
    fi
  done
}

fail_missing_silver_bullet_skill_surface() {
  local label="$1"
  local path="$2"

  printf 'ERROR: Silver Bullet %s is missing skills/ at %s\n' "$label" "$path" >&2
  printf 'The Codex skill picker will not surface SB skills from this package. Rebuild or reinstall the Silver Bullet Codex package before continuing.\n' >&2
  exit 1
}

validate_silver_bullet_skill_surface() {
  local label="$1"
  local package_root="$2"
  local skills_root="${package_root}/skills"
  local required_skill

  [[ -d "$package_root" ]] || return 0

  if [[ ! -d "$skills_root" ]]; then
    fail_missing_silver_bullet_skill_surface "$label" "$skills_root"
  fi

  for required_skill in silver-init silver silver-feature; do
    if [[ ! -f "${skills_root}/${required_skill}/SKILL.md" ]]; then
      printf 'ERROR: Silver Bullet %s is missing required skill surface %s at %s\n' \
        "$label" \
        "$required_skill" \
        "${skills_root}/${required_skill}/SKILL.md" >&2
      printf 'The Codex skill picker will not surface SB skills from this package. Rebuild or reinstall the Silver Bullet Codex package before continuing.\n' >&2
      exit 1
    fi
  done
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
  validate_silver_bullet_skill_surface "installed package" "${package_root}/${package_version}"

  shopt -s nullglob
  for version_dir in "$package_root"/*; do
    [[ -d "$version_dir" ]] || continue
    [[ "$(basename "$version_dir")" == "current" ]] && continue
    rsync -a --delete "${marketplace_root}/plugins/silver-bullet/" "${version_dir}/"
  done
  shopt -u nullglob
}

ensure_silver_bullet_registry_entry() {
  local registry_file="${CODEX_HOME_ROOT}/.codex/plugins/installed_plugins.json"

  python3 - "$registry_file" "$CODEX_HOME_ROOT" <<'PY'
import datetime
import json
import pathlib
import re
import shutil
import sys

registry_path = pathlib.Path(sys.argv[1])
home = pathlib.Path(sys.argv[2]).expanduser()
now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z")
plugin_id = "silver-bullet@alo-labs-codex"
plugin_root = home / ".codex" / "plugins" / "cache" / "alo-labs-codex" / "silver-bullet"

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

target_path = version_dirs[-1]
current_path = plugin_root / "current"
if current_path.exists() or current_path.is_symlink():
    if current_path.is_dir() and not current_path.is_symlink():
        shutil.rmtree(current_path)
    else:
        current_path.unlink()
current_path.symlink_to(target_path)

data = {"version": 2, "plugins": {}}
if registry_path.is_file():
    try:
        data = json.loads(registry_path.read_text())
    except Exception:
        pass

plugins = data.setdefault("plugins", {})
entry = {
    "scope": "project",
    "projectPath": str(home),
    "installPath": str(current_path),
    "version": target_path.name,
    "installedAt": now,
    "lastUpdated": now,
}

if plugin_id in plugins and plugins[plugin_id]:
    plugins[plugin_id][0].update(entry)
else:
    plugins[plugin_id] = [entry]

registry_path.parent.mkdir(parents=True, exist_ok=True)
registry_path.write_text(json.dumps(data, indent=2) + "\n")
PY
}

sync_codex_installed_plugin_registry_paths() {
  local registry_file="${CODEX_HOME_ROOT}/.codex/plugins/installed_plugins.json"
  local updated_at
  local plugin_id
  local plugin_name
  local marketplace
  local current_path
  local stable_path
  local updates=()
  updated_at="$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"

  [[ -f "$registry_file" ]] || return 0

  updates=()
  while IFS= read -r plugin_id; do
    [[ -n "$plugin_id" ]] || continue
    [[ "$plugin_id" == *"@"* ]] || continue

    plugin_name="${plugin_id%@*}"
    marketplace="${plugin_id#*@}"
    current_path=""
    stable_path=""

    local cache_root="${CODEX_HOME_ROOT}/.codex/plugins/cache"
    if [[ -d "${cache_root}/${marketplace}/${plugin_name}" ]]; then
      current_path="$(find "${cache_root}/${marketplace}/${plugin_name}" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -V | tail -n 1)"
    fi

    [[ -n "$current_path" ]] || continue
    python3 - "$current_path" "$marketplace" "$plugin_name" "$CODEX_HOME_ROOT" <<'PY'
import pathlib
import shutil
import sys

current_path = pathlib.Path(sys.argv[1])
marketplace = sys.argv[2]
plugin_name = sys.argv[3]
home_root = pathlib.Path(sys.argv[4]).expanduser()

alias_roots = [
    home_root / ".codex" / "plugins" / "cache" / marketplace / plugin_name / "current",
]

def refresh_alias(alias_path: pathlib.Path, target_path: pathlib.Path) -> None:
    alias_path.parent.mkdir(parents=True, exist_ok=True)
    if alias_path.exists() or alias_path.is_symlink():
        if alias_path.is_dir() and not alias_path.is_symlink():
            shutil.rmtree(alias_path)
        else:
            alias_path.unlink()
    alias_path.symlink_to(target_path)

target_path = current_path.resolve()
for alias_path in alias_roots:
    refresh_alias(alias_path, target_path)
PY
      stable_path="${CODEX_HOME_ROOT}/.codex/plugins/cache/${marketplace}/${plugin_name}/current"
      updates+=("${plugin_id}=${stable_path}|${current_path##*/}")
    done < <(python3 - "$registry_file" <<'PY'
import json
import pathlib
import sys

registry_path = pathlib.Path(sys.argv[1])
if not registry_path.is_file():
    sys.exit(0)

data = json.loads(registry_path.read_text())
for plugin_id in data.get("plugins", {}):
    print(plugin_id)
PY
    )

    [[ "${#updates[@]}" -gt 0 ]] || return 0

    python3 - "$registry_file" "$updated_at" "${updates[@]}" <<'PY'
import json
import pathlib
import sys

registry_path = pathlib.Path(sys.argv[1])
updated_at = sys.argv[2]
updates = {}

for item in sys.argv[3:]:
    if "=" not in item:
        continue
    plugin_id, new_path = item.split("=", 1)
    updates[plugin_id] = new_path

data = json.loads(registry_path.read_text())
changed = False

for plugin_id, entries in data.get("plugins", {}).items():
    update = updates.get(plugin_id)
    if update is None:
        continue

    path_value, version = update.split("|", 1)
    new_path = pathlib.Path(path_value)
    if not new_path.is_dir():
        continue

    for entry in entries:
        entry["installPath"] = str(new_path)
        entry["version"] = version
        entry["lastUpdated"] = updated_at
        changed = True

if changed:
    registry_path.write_text(json.dumps(data, indent=2) + "\n")
PY
}

ensure_codex_dependency_registry_entries() {
  local registry_file
  registry_file="${CODEX_HOME_ROOT}/.codex/plugins/installed_plugins.json"

  python3 - "$registry_file" "$CODEX_HOME_ROOT" <<'PY'
import datetime
import json
import pathlib
import re
import shutil
import sys

registry_path = pathlib.Path(sys.argv[1])
home = pathlib.Path(sys.argv[2]).expanduser()
now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z")

plugin_specs = {
    "superpowers@superpowers-marketplace": ("superpowers-marketplace", "superpowers"),
    "gsd@get-shit-done-marketplace": ("get-shit-done-marketplace", "gsd"),
    "engineering@alo-labs-codex": ("alo-labs-codex", "engineering"),
    "design@alo-labs-codex": ("alo-labs-codex", "design"),
    "product-management@alo-labs-codex": ("alo-labs-codex", "product-management"),
}

data = {"version": 2, "plugins": {}}
if registry_path.is_file():
    try:
        data = json.loads(registry_path.read_text())
    except Exception:
        pass

plugins = data.setdefault("plugins", {})
changed = False

def version_sort_key(path: pathlib.Path):
    return tuple(int(part) if part.isdigit() else part for part in re.split(r"([0-9]+)", path.name))

for plugin_id, (marketplace, plugin_name) in plugin_specs.items():
    plugin_root = home / ".codex" / "plugins" / "cache" / marketplace / plugin_name
    if not plugin_root.exists():
        continue

    version_dirs = sorted(
        [path for path in plugin_root.iterdir() if path.is_dir() and path.name != "current"],
        key=version_sort_key,
    )
    if not version_dirs:
        continue

    target_path = version_dirs[-1]
    current_path = plugin_root / "current"
    if current_path.exists() or current_path.is_symlink():
        if current_path.is_dir() and not current_path.is_symlink():
            shutil.rmtree(current_path)
        else:
            current_path.unlink()
    current_path.symlink_to(target_path)

    entry = {
        "scope": "project",
        "projectPath": str(home),
        "installPath": str(current_path),
        "version": target_path.name,
        "installedAt": now,
        "lastUpdated": now,
    }

    if plugin_id in plugins and plugins[plugin_id]:
        plugins[plugin_id][0].update(entry)
    else:
        plugins[plugin_id] = [entry]
    changed = True

if changed:
    registry_path.parent.mkdir(parents=True, exist_ok=True)
    registry_path.write_text(json.dumps(data, indent=2) + "\n")
PY
}

normalize_codex_hook_async_flags() {
  local marketplace_root
  marketplace_root="$(codex_marketplace_root)"

  python3 - "$marketplace_root" "${CODEX_HOME_ROOT}/.codex/plugins/cache" <<'PY'
import json
import pathlib
import sys

marketplace_root = pathlib.Path(sys.argv[1])
cache_roots = [pathlib.Path(sys.argv[2])]

# The marketplace keeps a top-level hooks tree and a materialized plugin copy.
# Both can carry stale async flags, so normalize each surface before Codex reads it.
candidate_files = [
    marketplace_root / "hooks/hooks.json",
    marketplace_root / "plugins/silver-bullet/hooks/hooks.json",
]

for cache_root in cache_roots:
    package_root = cache_root / "alo-labs-codex" / "silver-bullet"
    if not package_root.exists():
        continue
    for version_dir in sorted((p for p in package_root.iterdir() if p.is_dir()), key=lambda p: p.name):
        if version_dir.name == "current":
            continue
        candidate_files.append(version_dir / "hooks/hooks.json")

seen = set()
for hooks_json in candidate_files:
    key = str(hooks_json)
    if key in seen or not hooks_json.is_file():
        continue
    seen.add(key)

    data = json.loads(hooks_json.read_text())
    changed = False
    for event_items in data.get("hooks", {}).values():
        for item in event_items:
            for hook in item.get("hooks", []):
                if hook.get("async") is True:
                    hook["async"] = False
                    changed = True

    if changed:
        hooks_json.write_text(json.dumps(data, indent=2) + "\n")
PY
}

ensure_plugin_enabled() {
  local plugin_spec="$1"
  local config_file
  config_file="$(resolve_codex_config_file)"
  local header="[plugins.\"${plugin_spec}\"]"

  python3 - "$config_file" "$header" <<'PY'
import pathlib
import sys

config_path = pathlib.Path(sys.argv[1])
header = sys.argv[2]
config_path.parent.mkdir(parents=True, exist_ok=True)
text = config_path.read_text() if config_path.exists() else ''
lines = text.splitlines()
output = []
i = 0
found = False

while i < len(lines):
    line = lines[i]
    if line.strip() == header:
        found = True
        output.append(line)
        i += 1

        section_lines = []
        enabled_seen = False
        while i < len(lines) and not lines[i].startswith('['):
            section_line = lines[i]
            if section_line.strip().startswith('enabled ='):
                section_lines.append('enabled = true')
                enabled_seen = True
            else:
                section_lines.append(section_line)
            i += 1

        if not enabled_seen:
          output.append('enabled = true')
        output.extend(section_lines)
        continue

    output.append(line)
    i += 1

if found:
    new_text = '\n'.join(output)
    if text.endswith('\n'):
        new_text += '\n'
    config_path.write_text(new_text)
else:
    if text and not text.endswith('\n'):
        text += '\n'
    text += f'\n{header}\nenabled = true\n'
    config_path.write_text(text)
PY
}

ensure_feature_enabled() {
  local feature_name="$1"
  local config_file
  config_file="$(resolve_codex_config_file)"
  local header="[features]"

  python3 - "$config_file" "$header" "$feature_name" <<'PY'
import pathlib
import sys

config_path = pathlib.Path(sys.argv[1])
header = sys.argv[2]
feature_name = sys.argv[3]
config_path.parent.mkdir(parents=True, exist_ok=True)
text = config_path.read_text() if config_path.exists() else ''
lines = text.splitlines()
output = []
i = 0
found = False

while i < len(lines):
    line = lines[i]
    if line.strip() == header:
        found = True
        output.append(line)
        i += 1

        section_lines = []
        feature_seen = False
        while i < len(lines) and not lines[i].startswith('['):
            section_line = lines[i]
            stripped = section_line.strip()
            if stripped.startswith(f'{feature_name} ='):
                section_lines.append(f'{feature_name} = true')
                feature_seen = True
            else:
                section_lines.append(section_line)
            i += 1

        if not feature_seen:
            output.append(f'{feature_name} = true')
        output.extend(section_lines)
        continue

    output.append(line)
    i += 1

if found:
    new_text = '\n'.join(output)
    if text.endswith('\n'):
        new_text += '\n'
    config_path.write_text(new_text)
else:
    if text and not text.endswith('\n'):
        text += '\n'
    text += f'\n{header}\n{feature_name} = true\n'
    config_path.write_text(text)
PY
}

remove_plugin_enabled() {
  local plugin_spec="$1"
  local config_file

  config_file="$(resolve_codex_config_file)"
  [[ -f "$config_file" ]] || return 0

  python3 - "$config_file" "$plugin_spec" <<'PY'
import pathlib
import sys

config_path = pathlib.Path(sys.argv[1])
plugin_spec = sys.argv[2]
text = config_path.read_text()
lines = text.splitlines()
output = []
i = 0
removed = False
header = f'[plugins."{plugin_spec}"]'

while i < len(lines):
    line = lines[i]
    if line.strip() == header:
      removed = True
      i += 1
      while i < len(lines) and not lines[i].startswith('['):
        i += 1
      continue
    output.append(line)
    i += 1

if removed:
    new_text = '\n'.join(output)
    if text.endswith('\n'):
        new_text += '\n'
    config_path.write_text(new_text)
PY
}

purge_legacy_silver_bullet_codex_alias() {
  python3 - "${CODEX_HOME_ROOT}/.codex/plugins/installed_plugins.json" "${CODEX_HOME_ROOT}/.codex/config.toml" "$CODEX_HOME_ROOT" <<'PY'
import json
import pathlib
import shutil
import sys

registry_paths = [pathlib.Path(sys.argv[1])]
config_paths = [pathlib.Path(sys.argv[2])]
home_root = pathlib.Path(sys.argv[3]).expanduser()
legacy_plugin_ids = {
    "silver-bullet@alo-labs-codex",
    "silver-bullet@alo-labs-codex-local",
}
legacy_cache_roots = [
    home_root / ".codex" / "plugins" / "cache" / "alo-labs-codex-local" / "silver-bullet",
]

for registry_path in registry_paths:
    if not registry_path.is_file():
        continue

    data = json.loads(registry_path.read_text())
    plugins = data.get("plugins", {})
    changed = False
    for plugin_id in legacy_plugin_ids:
        if plugin_id in plugins:
            del plugins[plugin_id]
            changed = True
    if changed:
        registry_path.write_text(json.dumps(data, indent=2) + "\n")

for config_path in config_paths:
    if not config_path.is_file():
        continue

    text = config_path.read_text()
    text = text.replace("/.Codex/", "/.codex/")
    lines = text.splitlines()
    output = []
    i = 0
    changed = False

    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        if any(stripped == f'[plugins."{plugin_id}"]' for plugin_id in legacy_plugin_ids):
            changed = True
            i += 1
            while i < len(lines) and not lines[i].startswith('['):
                i += 1
            continue
        if any(stripped.startswith(f'[hooks.state."{plugin_id}') for plugin_id in legacy_plugin_ids):
            changed = True
            i += 1
            while i < len(lines) and not lines[i].startswith('['):
                i += 1
            continue
        output.append(line)
        i += 1

    if changed:
        new_text = '\n'.join(output)
        if text.endswith('\n'):
            new_text += '\n'
        config_path.write_text(new_text)

for cache_root in legacy_cache_roots:
    if cache_root.exists():
        if cache_root.is_dir() and not cache_root.is_symlink():
            shutil.rmtree(cache_root)
        else:
            cache_root.unlink()
PY
}

purge_legacy_silver_bullet_hooks_from_user_config() {
  python3 - "${CODEX_HOME_ROOT}/.codex/hooks.json" <<'PY'
import json
import pathlib
import re
import sys

sb_hook_re = re.compile(r'(?:^|[/.])silver-bullet(?:/|@|$)')

for raw_path in sys.argv[1:]:
    hooks_path = pathlib.Path(raw_path)
    if not hooks_path.is_file():
        continue

    data = json.loads(hooks_path.read_text())
    hooks_by_event = data.get("hooks", {})
    changed = False

    for event_name in list(hooks_by_event.keys()):
        groups = hooks_by_event[event_name]
        kept_groups = []

        for group in groups:
            hooks = group.get("hooks", [])
            kept_hooks = [hook for hook in hooks if not sb_hook_re.search(hook.get("command", ""))]

            if len(kept_hooks) != len(hooks):
                changed = True

            if kept_hooks:
                if len(kept_hooks) != len(hooks):
                    group = dict(group)
                    group["hooks"] = kept_hooks
                kept_groups.append(group)
            else:
                changed = True

        if kept_groups:
            hooks_by_event[event_name] = kept_groups
        else:
            del hooks_by_event[event_name]

    if changed:
        hooks_path.write_text(json.dumps(data, indent=2) + "\n")
PY

  python3 - "${CODEX_HOME_ROOT}/.codex/config.toml" <<'PY'
import pathlib
import sys

for raw_path in sys.argv[1:]:
    config_path = pathlib.Path(raw_path)
    if not config_path.is_file():
        continue

    text = config_path.read_text()
    lines = text.splitlines()
    output = []
    i = 0
    changed = False

    while i < len(lines):
        line = lines[i]
        if line.startswith('[hooks.state."silver-bullet@'):
            changed = True
            i += 1
            while i < len(lines) and not lines[i].startswith('['):
                i += 1
            continue
        output.append(line)
        i += 1

    if changed:
        new_text = '\n'.join(output)
        if text.endswith('\n'):
            new_text += '\n'
        config_path.write_text(new_text)
PY
}

seed_silver_bullet_hook_trust_state() {
  local marketplace_root
  marketplace_root="$(codex_marketplace_root)"
  [[ -d "${marketplace_root}/plugins/silver-bullet" ]] || return 0

  python3 - "${marketplace_root}/plugins/silver-bullet" "${CODEX_HOME_ROOT}/.codex/config.toml" "$MERGE_USER_HOOKS" "$CODEX_HOME_ROOT" <<'PY'
import hashlib
import json
import os
import pathlib
import re
import sys

package_root = pathlib.Path(sys.argv[1])
target_paths = [pathlib.Path(sys.argv[2])]
merge_user_hooks = sys.argv[3] == "1"
home = pathlib.Path(sys.argv[4]).expanduser()
resolved_home = home.resolve()

package_hooks_src = package_root / "hooks" / "hooks.json"
if not package_hooks_src.is_file():
    sys.exit(0)

package_hooks_prefix = "silver-bullet@alo-labs-codex:hooks/hooks.json"
raw_user_hooks_prefix = str(home / ".codex" / "hooks.json")
resolved_user_hooks_prefix = str(resolved_home / ".codex" / "hooks.json")

def event_slug(name: str) -> str:
    return re.sub(r"(?<!^)(?=[A-Z])", "_", name).lower()

def canonical_json(value):
    if isinstance(value, dict):
        return {key: canonical_json(value[key]) for key in sorted(value) if value[key] is not None}
    if isinstance(value, list):
        return [canonical_json(item) for item in value]
    return value

def hook_current_hash(event_name, matcher, hook):
    hook_type = hook.get("type")
    if hook_type is None and "command" in hook:
        hook_type = "command"
    if hook_type != "command":
        return None
    if hook.get("async", False):
        return None

    command = hook.get("command", "")
    command_windows = hook.get("commandWindows")
    if command_windows is None:
        command_windows = hook.get("command_windows")
    if os.name == "nt" and command_windows:
        command = command_windows
    if not str(command).strip():
        return None

    normalized_hook = {
        "type": "command",
        "command": command,
        "timeout": max(int(hook.get("timeout", 600) or 600), 1),
        "async": False,
    }
    status_message = hook.get("statusMessage")
    if status_message is None:
        status_message = hook.get("status_message")
    if status_message is not None:
        normalized_hook["statusMessage"] = status_message

    identity = {
        "event_name": event_slug(event_name),
        "hooks": [normalized_hook],
    }
    if matcher is not None:
        identity["matcher"] = matcher

    serialized = json.dumps(
        canonical_json(identity),
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")
    return "sha256:" + hashlib.sha256(serialized).hexdigest()

def first_existing(*paths):
    for path in paths:
        if path.is_file():
            return path
    return None

def hooks_data_for(path):
    if path is None:
        return {}
    return json.loads(path.read_text()).get("hooks", {})

resolved_sources = {}
resolved_sources[package_hooks_prefix] = package_hooks_src
if merge_user_hooks:
    user_hooks_src = first_existing(home / ".codex" / "hooks.json")
    for prefix in [raw_user_hooks_prefix, resolved_user_hooks_prefix]:
        if prefix not in resolved_sources:
            resolved_sources[prefix] = user_hooks_src

entries = []

for prefix, source_path in resolved_sources.items():
    for event_name, groups in hooks_data_for(source_path).items():
        slug = event_slug(event_name)
        for group_index, group in enumerate(groups):
            for hook_index, hook in enumerate(group.get("hooks", [])):
                digest = hook_current_hash(event_name, group.get("matcher"), hook)
                if digest is None:
                    continue
                key = f"{prefix}:{slug}:{group_index}:{hook_index}"
                entries.append((key, digest))

def render_entries():
    lines = []
    for key, digest in entries:
        lines.append(f'[hooks.state."{key}"]')
        lines.append(f'trusted_hash = "{digest}"')
        lines.append("")
    return lines

for config_path in target_paths:
    text = config_path.read_text() if config_path.is_file() else ""
    lines = text.splitlines()
    output = []
    changed = False
    hooks_state_seen = False
    inserted = False
    i = 0

    while i < len(lines):
        line = lines[i]
        if line == "[hooks.state]":
            hooks_state_seen = True
            output.append(line)
            i += 1
            continue

        if hooks_state_seen:
            if (
                line.startswith(f'[hooks.state."{package_hooks_prefix}')
                or line.startswith(f'[hooks.state."{raw_user_hooks_prefix}')
                or line.startswith(f'[hooks.state."{resolved_user_hooks_prefix}')
            ):
                changed = True
                i += 1
                while i < len(lines) and not lines[i].startswith('['):
                    i += 1
                continue

            if line.startswith("[") and not line.startswith("[hooks.state."):
                if not inserted:
                    output.extend(render_entries())
                    inserted = True
                    changed = True
                hooks_state_seen = False
                output.append(line)
                i += 1
                continue

        output.append(line)
        i += 1

    if hooks_state_seen and not inserted:
        output.extend(render_entries())
        inserted = True
        changed = True

    if not hooks_state_seen and not inserted:
        if output and output[-1] != "":
            output.append("")
        output.append("[hooks.state]")
        output.extend(render_entries())
        changed = True

    if changed:
        new_text = "\n".join(output).rstrip("\n") + "\n"
        config_path.write_text(new_text)
PY
}

merge_silver_bullet_hooks_into_user_config() {
  local marketplace_root package_root
  marketplace_root="$(codex_marketplace_root)"
  package_root="${marketplace_root}/plugins/silver-bullet"

  [[ -d "${package_root}/hooks" ]] || return 0

  python3 - "$package_root" "${CODEX_HOME_ROOT}/.codex/hooks.json" <<'PY'
import json
import pathlib
import re
import sys

package_root = pathlib.Path(sys.argv[1])
target_paths = [pathlib.Path(sys.argv[2])]
hooks_src = package_root / "hooks" / "hooks.json"

if not hooks_src.is_file():
    sys.exit(0)

src_data = json.loads(hooks_src.read_text())
sb_hooks = src_data.get("hooks", {})

def sub_path(obj):
    if isinstance(obj, str):
        return obj.replace("${CLAUDE_PLUGIN_ROOT}", str(package_root))
    if isinstance(obj, list):
        return [sub_path(item) for item in obj]
    if isinstance(obj, dict):
        return {key: sub_path(value) for key, value in obj.items()}
    return obj

sb_hooks = sub_path(sb_hooks)
sb_hook_re = re.compile(r'/silver-bullet(?:/[^/]+)?/hooks/')

for hooks_path in target_paths:
    if hooks_path.is_file():
        data = json.loads(hooks_path.read_text())
    else:
        data = {}

    hooks_by_event = data.setdefault("hooks", {})
    changed = False

    # Purge stale SB hooks from previous installs first.
    for event_name in list(hooks_by_event.keys()):
        groups = hooks_by_event[event_name]
        kept_groups = []

        for group in groups:
            hooks = group.get("hooks", [])
            kept_hooks = [hook for hook in hooks if not sb_hook_re.search(hook.get("command", ""))]

            if len(kept_hooks) != len(hooks):
                changed = True

            if kept_hooks:
                if len(kept_hooks) != len(hooks):
                    group = dict(group)
                    group["hooks"] = kept_hooks
                kept_groups.append(group)
            else:
                changed = True

        if kept_groups:
            hooks_by_event[event_name] = kept_groups
        elif event_name in hooks_by_event:
            del hooks_by_event[event_name]

    # Merge the current SB hook surface, deduping by command within each matcher group.
    for event_name, entries in sb_hooks.items():
        existing_event = hooks_by_event.setdefault(event_name, [])
        for new_group in entries:
            new_hooks_list = new_group.get("hooks", [])
            matcher = new_group.get("matcher", "")
            matched = next((g for g in existing_event if g.get("matcher", "") == matcher), None)
            if matched is None:
                matched = {"matcher": matcher, "hooks": []}
                existing_event.append(matched)
                changed = True
            for new_hook in new_hooks_list:
                new_cmd = new_hook.get("command", "")
                already_present = any(
                    h.get("command", "") == new_cmd
                    for h in matched.get("hooks", [])
                )
                if already_present:
                    continue

                matched.setdefault("hooks", []).append(new_hook)
                changed = True

    if changed:
        hooks_path.parent.mkdir(parents=True, exist_ok=True)
        hooks_path.write_text(json.dumps(data, indent=2) + "\n")
PY
}

codex_marketplace_root() {
  local marketplace_root="${CODEX_HOME_ROOT}/.codex/.tmp/marketplaces/alo-labs-codex"
  if [[ -d "$marketplace_root" ]]; then
    printf '%s\n' "$marketplace_root"
    return 0
  fi
  printf '%s\n' "${CODEX_HOME_ROOT}/.codex/.tmp/marketplaces/alo-labs-codex"
}

find_silver_bullet_project_root() {
  local search_dir="$PWD"
  while true; do
    if [[ -f "$search_dir/.silver-bullet.json" ]] && [[ -f "$search_dir/silver-bullet.md" ]]; then
      printf '%s\n' "$search_dir"
      return 0
    fi
    if [[ -d "$search_dir/.git" ]] || [[ "$search_dir" == "/" ]]; then
      break
    fi
    search_dir=$(dirname "$search_dir")
  done
  return 1
}

sync_silver_bullet_skill_cache() {
  local marketplace_root
  local current_package_dir=""

  marketplace_root="$(codex_marketplace_root)"
  [[ -d "$marketplace_root" ]] || return 0

  current_package_dir="${marketplace_root}/plugins/silver-bullet"
  [[ -d "${current_package_dir}/skills" ]] || return 0

  python3 - "${current_package_dir}/skills" <<'PY'
import pathlib
import re
import sys

skills_root = pathlib.Path(sys.argv[1])
name_re = re.compile(r'^(name:\s*)silver-([A-Za-z0-9_-]+)\s*$', re.MULTILINE)

for skill_md in skills_root.rglob("SKILL.md"):
    text = skill_md.read_text()
    updated = name_re.sub(lambda m: f"{m.group(1)}silver:{m.group(2)}", text, count=1)
    if updated != text:
        skill_md.write_text(updated)
PY
}

rewrite_codex_bundle_host_paths() {
  local marketplace_root
  local package_root

  marketplace_root="$(codex_marketplace_root)"
  package_root="${marketplace_root}/plugins/silver-bullet"

  [[ -d "$package_root" ]] || return 0

  python3 - "$marketplace_root" "$package_root" "${CODEX_HOME_ROOT}/.codex/plugins/cache" <<'PY'
import json
import pathlib
import re
import sys

marketplace_root = pathlib.Path(sys.argv[1])
package_root = pathlib.Path(sys.argv[2])
cache_roots = [pathlib.Path(arg) for arg in sys.argv[3:] if arg]

targets = [marketplace_root, package_root]
for cache_root in cache_roots:
    package_cache_root = cache_root / "alo-labs-codex" / "silver-bullet"
    if not package_cache_root.exists():
        continue
    for version_dir in package_cache_root.iterdir():
        if version_dir.name == "current" or not version_dir.is_dir():
            continue
        targets.append(version_dir)

path_segment_re = re.compile(r'/\.claude(?=/|$)')
gsd_sdk_replacements = (
    (
        "path.join(os.homedir(), '.claude', 'get-shit-done', 'bin', 'gsd-tools.cjs')",
        "path.join(os.homedir(), '.codex', 'get-shit-done', 'bin', 'gsd-tools.cjs')",
    ),
    (
        "path.join(os.homedir(), '.claude', 'get-shit-done', 'bin', 'gsd-tools')",
        "path.join(os.homedir(), '.codex', 'get-shit-done', 'bin', 'gsd-tools')",
    ),
)
home_claude_replacements = (
    ("os.homedir(), '.claude'", "os.homedir(), '.codex'"),
    ('os.homedir(), ".claude"', 'os.homedir(), ".codex"'),
    ("os.homedir() + '/.claude'", "os.homedir() + '/.codex'"),
    ('os.homedir() + "/.claude"', 'os.homedir() + "/.codex"'),
)

def rewrite_hook_manifest(file_path: pathlib.Path) -> bool:
    try:
        data = json.loads(file_path.read_text())
    except Exception:
        return False

    if not isinstance(data, dict) or "hooks" not in data:
        return False

    changed = False
    adapter_path = str(package_root / "hooks" / "codex-hook-adapter.sh")

    def rewrite_value(value):
        nonlocal changed
        if isinstance(value, str):
            updated = value.replace("${CLAUDE_PLUGIN_ROOT}", str(package_root))
            if file_path.name == "hooks.json":
                for src, dst in gsd_sdk_replacements:
                    updated = updated.replace(src, dst)
                for src, dst in home_claude_replacements:
                    updated = updated.replace(src, dst)
                updated = updated.replace("\\.claude/", "\\.codex/")
                updated = updated.replace(".claude/", ".codex/")
                updated = updated.replace("~/\\.claude", "~/.codex")
                updated = updated.replace("$HOME/.claude", "$HOME/.codex")
                updated = updated.replace("${HOME}/.claude", "${HOME}/.codex")
                updated = path_segment_re.sub("/.codex", updated)
            if updated != value:
                changed = True
            return updated
        if isinstance(value, list):
            return [rewrite_value(item) for item in value]
        if isinstance(value, dict):
            return {key: rewrite_value(item) for key, item in value.items()}
        return value

    updated = rewrite_value(data)

    shell_like_matchers = ("Bash", "shell", "exec_command")

    def dedupe_hooks(hooks):
        deduped = []
        seen = set()
        for hook in hooks:
            key = json.dumps(hook, sort_keys=True)
            if key in seen:
                continue
            seen.add(key)
            deduped.append(hook)
        return deduped

    def codex_matchers_for(matcher):
        if not isinstance(matcher, str) or "|" not in matcher and matcher != "Bash":
            return [matcher]

        parts = [part for part in matcher.split("|") if part]
        if not parts:
            return [matcher]

        if not any(part in shell_like_matchers for part in parts):
            return [matcher]

        non_shell_parts = [part for part in parts if part not in shell_like_matchers]
        expanded = []
        if non_shell_parts:
            expanded.append("|".join(non_shell_parts))
        expanded.extend(shell_like_matchers)

        ordered = []
        seen = set()
        for item in expanded:
            if item in seen:
                continue
            seen.add(item)
            ordered.append(item)
        return ordered or [matcher]

    normalized_hooks = {}
    for event_name, groups in updated.get("hooks", {}).items():
        merged_groups = {}
        ordered_matchers = []
        for group in groups:
            hooks = dedupe_hooks(group.get("hooks", []))
            for matcher in codex_matchers_for(group.get("matcher", "")):
                if matcher not in merged_groups:
                    merged_groups[matcher] = {"matcher": matcher, "hooks": []}
                    ordered_matchers.append(matcher)
                existing = merged_groups[matcher]["hooks"]
                seen_commands = {
                    json.dumps(hook, sort_keys=True)
                    for hook in existing
                }
                for hook in hooks:
                    hook_key = json.dumps(hook, sort_keys=True)
                    if hook_key in seen_commands:
                        continue
                    existing.append(hook)
                    seen_commands.add(hook_key)
        normalized_hooks[event_name] = [merged_groups[matcher] for matcher in ordered_matchers]

    for event_name, groups in normalized_hooks.items():
        for group in groups:
            hooks = group.get("hooks", [])
            for hook in hooks:
                if hook.get("type") != "command":
                    continue
                command = hook.get("command", "")
                if not isinstance(command, str) or not command:
                    continue
                if adapter_path in command:
                    continue
                hook["command"] = f'"{adapter_path}" "{event_name}" {command}'
                changed = True

    if normalized_hooks != updated.get("hooks", {}):
        updated["hooks"] = normalized_hooks
        changed = True

    if changed:
        file_path.write_text(json.dumps(updated, indent=2) + "\n")
    return changed

path_segment_re = re.compile(r'/\.claude(?=/|$)')
gsd_sdk_replacements = (
    (
        "path.join(os.homedir(), '.claude', 'get-shit-done', 'bin', 'gsd-tools.cjs')",
        "path.join(os.homedir(), '.codex', 'get-shit-done', 'bin', 'gsd-tools.cjs')",
    ),
    (
        "path.join(os.homedir(), '.claude', 'get-shit-done', 'bin', 'gsd-tools')",
        "path.join(os.homedir(), '.codex', 'get-shit-done', 'bin', 'gsd-tools')",
    ),
)
home_claude_replacements = (
    ("os.homedir(), '.claude'", "os.homedir(), '.codex'"),
    ('os.homedir(), ".claude"', 'os.homedir(), ".codex"'),
    ("os.homedir() + '/.claude'", "os.homedir() + '/.codex'"),
    ('os.homedir() + "/.claude"', 'os.homedir() + "/.codex"'),
)

for root in targets:
    for file_path in root.rglob("*"):
        if not file_path.is_file() or file_path.is_symlink():
            continue
        if ".git" in file_path.parts:
            continue
        if file_path.name == "runtime-paths.sh" and "hooks" in file_path.parts:
            continue
        try:
            text = file_path.read_text()
        except UnicodeDecodeError:
            continue
        except Exception:
            continue

        if file_path.name == "hooks.json" and rewrite_hook_manifest(file_path):
            continue

        updated = text
        if file_path.name == "gsd-sdk.cjs":
            for src, dst in gsd_sdk_replacements:
                updated = updated.replace(src, dst)
        for src, dst in home_claude_replacements:
            updated = updated.replace(src, dst)
        updated = updated.replace("\\.claude/", "\\.codex/")
        updated = updated.replace(".claude/", ".codex/")
        updated = updated.replace("~/\\.claude", "~/.codex")
        updated = updated.replace("$HOME/.claude", "$HOME/.codex")
        updated = updated.replace("${HOME}/.claude", "${HOME}/.codex")
        updated = path_segment_re.sub("/.codex", updated)

        if updated != text:
            file_path.write_text(updated)

canonical_hooks_path = marketplace_root / "hooks" / "hooks.json"
if canonical_hooks_path.is_file():
    try:
        canonical_hooks_text = canonical_hooks_path.read_text()
    except Exception:
        canonical_hooks_text = ""
    if canonical_hooks_text:
        for root in targets:
            hooks_path = root / "hooks" / "hooks.json"
            if not hooks_path.is_file() or hooks_path == canonical_hooks_path:
                continue
            if hooks_path.read_text() != canonical_hooks_text:
                hooks_path.write_text(canonical_hooks_text)
PY
}

scrub_legacy_silver_bullet_traces() {
  local marketplace_root
  local changelog_file

  marketplace_root="$(codex_marketplace_root)"
  [[ -d "$marketplace_root" ]] || return 0
  changelog_file="${marketplace_root}/CHANGELOG.md"
  [[ -f "$changelog_file" ]] || return 0

  python3 - "$changelog_file" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text()
lines = [line for line in text.splitlines() if "using-silver-bullet" not in line]
new_text = "\n".join(lines)
if text.endswith("\n"):
    new_text += "\n"
path.write_text(new_text)
PY
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --purge-legacy-skills) PURGE_LEGACY_SKILLS=1; shift ;;
    --public-release) PUBLIC_RELEASE_ONLY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$PUBLIC_RELEASE_ONLY" -eq 0 ]]; then
  "${SCRIPT_DIR}/sync-codex-package.sh"
fi

if ! command -v "${CODEX_BIN}" >/dev/null 2>&1; then
  printf 'ERROR: codex CLI not found in PATH\n' >&2
  exit 1
fi

remove_marketplace_if_present "${CODEX_MARKETPLACE_LEGACY_NAME}"
ensure_marketplace_registered "${CODEX_MARKETPLACE_SOURCE}"
if [[ "$PUBLIC_RELEASE_ONLY" -eq 0 ]]; then
  seed_marketplace_snapshot_if_missing
fi
refresh_marketplace "alo-labs-codex"
purge_legacy_silver_bullet_codex_alias
if [[ "$PUBLIC_RELEASE_ONLY" -eq 0 ]]; then
  render_agent_bundle "claude"
  render_agent_bundle "codex"
  sync_marketplace_package_surface
  sync_marketplace_package_snapshot
fi
materialize_silver_bullet_package
sync_materialized_package_surface
sanitize_codex_package_surface
sync_codex_cache_package_surface
rewrite_codex_bundle_host_paths
sync_codex_installed_plugin_registry_paths
normalize_codex_hook_async_flags
ensure_feature_enabled "plugin_hooks"
ensure_plugin_enabled "superpowers@superpowers-marketplace"
ensure_plugin_enabled "gsd@get-shit-done-marketplace"
remove_plugin_enabled "silver@alo-labs-codex"
ensure_plugin_enabled "product-management@alo-labs-codex"
ensure_plugin_enabled "engineering@alo-labs-codex"
ensure_plugin_enabled "design@alo-labs-codex"
ensure_codex_dependency_registry_entries
purge_legacy_silver_bullet_hooks_from_user_config

SB_PROJECT_ROOT=""
if SB_PROJECT_ROOT="$(find_silver_bullet_project_root)"; then
  ensure_plugin_enabled "silver-bullet@alo-labs-codex"
  ensure_silver_bullet_registry_entry
  validate_silver_bullet_skill_surface "installed package alias" "${CODEX_HOME_ROOT}/.codex/plugins/cache/alo-labs-codex/silver-bullet/current"
  if [[ "$MERGE_USER_HOOKS" == "1" ]]; then
    merge_silver_bullet_hooks_into_user_config
  fi
else
  remove_plugin_enabled "silver-bullet@alo-labs-codex"
  printf 'Skipping Silver Bullet plugin auto-enable outside a Silver Bullet project root.\n'
fi

ensure_marketplace_registered "${SUPERPOWERS_MARKETPLACE_SOURCE}"
ensure_marketplace_registered "${GSD_MARKETPLACE_SOURCE}" "get-shit-done-marketplace"

GSD_HOME="$(resolve_codex_gsd_home)"

if [[ -f "${GSD_HOME}/VERSION" ]]; then
  printf 'GSD already installed at %s\n' "${GSD_HOME}/VERSION"
else
  if ! command -v "${NPM_BIN}" >/dev/null 2>&1; then
    printf 'ERROR: npm/npx not found in PATH; cannot install GSD\n' >&2
    exit 1
  fi
  printf 'Installing GSD from official source: %s\n' "${GSD_INSTALL_CMD}"
  # Avoid eval so the bootstrap path stays predictable and shell-safe.
  # The command is treated as a simple whitespace-delimited invocation.
  # Tests can override it with a tiny helper executable.
  read -r -a GSD_INSTALL_ARGS <<< "${GSD_INSTALL_CMD}"
  GSD_HOME="$GSD_HOME" "${GSD_INSTALL_ARGS[@]}"
fi

if [[ -n "$SB_PROJECT_ROOT" ]]; then
  seed_silver_bullet_hook_trust_state
fi

sync_silver_bullet_skill_cache
scrub_legacy_silver_bullet_traces

if [[ "$PURGE_LEGACY_SKILLS" -eq 1 ]]; then
  LEGACY_SKILLS_HOME="${CODEX_HOME_ROOT}/.agents/skills"
  if [[ -d "${LEGACY_SKILLS_HOME}" ]]; then
    while IFS= read -r -d '' skill_dir; do
      skill_name="$(basename "${skill_dir}")"
      if [[ -e "${LEGACY_SKILLS_HOME}/${skill_name}" ]]; then
        rm -rf -- "${LEGACY_SKILLS_HOME:?}/${skill_name}"
        printf 'Removed legacy skill: %s\n' "${skill_name}"
      fi
    done < <(find "${REPO_ROOT}/skills" -mindepth 1 -maxdepth 1 -type d -print0)
  fi

  if [[ -e "${LEGACY_SKILLS_HOME}/using-silver-bullet" ]]; then
    rm -rf -- "${LEGACY_SKILLS_HOME:?}/using-silver-bullet"
    printf 'Removed legacy skill: using-silver-bullet\n'
  fi
fi

if [[ "$PUBLIC_RELEASE_ONLY" -eq 1 ]]; then
  printf 'Codex marketplace refreshed from published source %s\n' "${CODEX_MARKETPLACE_SOURCE}"
else
  printf 'Codex marketplace registered from %s\n' "${REPO_ROOT}"
fi
