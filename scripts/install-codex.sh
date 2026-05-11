#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PURGE_LEGACY_SKILLS=0
CODEX_BIN="${CODEX_BIN:-codex}"
NPM_BIN="${NPM_BIN:-npx}"
GSD_INSTALL_CMD="${GSD_INSTALL_CMD:-${NPM_BIN} get-shit-done-cc@latest}"
CODEX_MARKETPLACE_SOURCE="${CODEX_MARKETPLACE_SOURCE:-https://github.com/alo-labs/codex-plugins}"
CODEX_MARKETPLACE_LEGACY_NAME="${CODEX_MARKETPLACE_LEGACY_NAME:-silver-bullet-local}"
SUPERPOWERS_MARKETPLACE_SOURCE="${SUPERPOWERS_MARKETPLACE_SOURCE:-https://github.com/obra/superpowers-marketplace.git}"

resolve_codex_config_file() {
  local config_file
  for config_file in "${HOME}/.Codex/config.toml" "${HOME}/.codex/config.toml"; do
    if [[ -f "$config_file" ]]; then
      printf '%s\n' "$config_file"
      return 0
    fi
  done
  printf '%s\n' "${HOME}/.Codex/config.toml"
}

usage() {
  cat <<'USAGE'
Usage: scripts/install-codex.sh [--purge-legacy-skills]

Synchronizes the local Codex plugin package and registers the shared
`alo-labs/codex-plugins` marketplace with Codex. Also ensures the official
dependency sources are present.

Options:
  --purge-legacy-skills  Remove SB skill directories already copied into ~/.agents/skills
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
  local config_file
  config_file="$(resolve_codex_config_file)"

  python3 - "$config_file" "$source_spec" <<'PY'
import pathlib
import sys

config_path = pathlib.Path(sys.argv[1])
source_spec = sys.argv[2]
marketplace_name = 'superpowers-marketplace' if 'superpowers' in source_spec else 'alo-labs-codex'
source_type = 'local' if source_spec.startswith('/') else 'git'
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
  for dir in hooks skills templates docs commands; do
    if [[ -d "${REPO_ROOT}/${dir}" ]]; then
      local src_dir="${REPO_ROOT}/${dir}"
      local dst_dir="${marketplace_root}/${dir}"
      if [[ -e "$dst_dir" ]] && [[ "$(resolve_realpath "$src_dir")" == "$(resolve_realpath "$dst_dir")" ]]; then
        continue
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
      if [[ -e "$dst_file" ]] && [[ "$(resolve_realpath "$src_file")" == "$(resolve_realpath "$dst_file")" ]]; then
        continue
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
  # hooks/hooks.json, skills/, templates/, and the rest survive install-time
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
  for dir in hooks skills templates docs commands; do
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

sync_codex_cache_package_surface() {
  local marketplace_root
  marketplace_root="$(codex_marketplace_root)"
  [[ -d "${marketplace_root}/plugins/silver-bullet" ]] || return 0

  local cache_root package_root version_dir
  for cache_root in "${HOME}/.Codex/plugins/cache" "${HOME}/.codex/plugins/cache"; do
    [[ -d "$cache_root" ]] || continue
    for package_root in \
      "${cache_root}/alo-labs-codex/silver-bullet" \
      "${cache_root}/alo-labs-codex-local/silver-bullet"; do
      [[ -d "$package_root" ]] || continue
      shopt -s nullglob
      for version_dir in "$package_root"/*; do
        [[ -d "$version_dir" ]] || continue
        rsync -a --delete "${marketplace_root}/plugins/silver-bullet/" "${version_dir}/"
      done
      shopt -u nullglob
    done
  done
}

normalize_codex_hook_async_flags() {
  local marketplace_root
  marketplace_root="$(codex_marketplace_root)"

  python3 - "$marketplace_root" "$HOME/.Codex/plugins/cache" "$HOME/.codex/plugins/cache" <<'PY'
import json
import pathlib
import sys

marketplace_root = pathlib.Path(sys.argv[1])
cache_roots = [pathlib.Path(sys.argv[2]), pathlib.Path(sys.argv[3])]

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

purge_legacy_silver_bullet_hooks_from_user_config() {
  python3 - "${HOME}/.Codex/hooks.json" "${HOME}/.codex/hooks.json" <<'PY'
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

  python3 - "${HOME}/.Codex/config.toml" "${HOME}/.codex/config.toml" <<'PY'
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

merge_silver_bullet_hooks_into_user_config() {
  local marketplace_root package_root
  marketplace_root="$(codex_marketplace_root)"
  package_root="${marketplace_root}/plugins/silver-bullet"

  [[ -d "${package_root}/hooks" ]] || return 0

  python3 - "$package_root" "${HOME}/.Codex/hooks.json" "${HOME}/.codex/hooks.json" <<'PY'
import json
import pathlib
import re
import sys

package_root = pathlib.Path(sys.argv[1])
target_paths = [pathlib.Path(p) for p in sys.argv[2:]]
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
            for new_hook in new_hooks_list:
                new_cmd = new_hook.get("command", "")
                already_present = any(
                    h.get("command", "") == new_cmd
                    for group in existing_event
                    for h in group.get("hooks", [])
                )
                if already_present:
                    continue

                matcher = new_group.get("matcher", "")
                matched = next((g for g in existing_event if g.get("matcher", "") == matcher), None)
                if matched:
                    matched.setdefault("hooks", []).append(new_hook)
                else:
                    existing_event.append({"matcher": matcher, "hooks": [new_hook]})
                changed = True

    if changed:
        hooks_path.parent.mkdir(parents=True, exist_ok=True)
        hooks_path.write_text(json.dumps(data, indent=2) + "\n")
PY
}

codex_marketplace_root() {
  local marketplace_root
  for marketplace_root in \
    "${HOME}/.Codex/.tmp/marketplaces/alo-labs-codex" \
    "${HOME}/.codex/.tmp/marketplaces/alo-labs-codex"; do
    if [[ -d "$marketplace_root" ]]; then
      printf '%s\n' "$marketplace_root"
      return 0
    fi
  done
  printf '%s\n' "${HOME}/.Codex/.tmp/marketplaces/alo-labs-codex"
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
    -h|--help) usage; exit 0 ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

"${SCRIPT_DIR}/sync-codex-package.sh"

if ! command -v "${CODEX_BIN}" >/dev/null 2>&1; then
  printf 'ERROR: codex CLI not found in PATH\n' >&2
  exit 1
fi

remove_marketplace_if_present "${CODEX_MARKETPLACE_LEGACY_NAME}"
ensure_marketplace_registered "${CODEX_MARKETPLACE_SOURCE}"
seed_marketplace_snapshot_if_missing
refresh_marketplace "alo-labs-codex"
sync_marketplace_package_surface
sync_marketplace_package_snapshot
materialize_silver_bullet_package
sync_materialized_package_surface
sync_codex_cache_package_surface
normalize_codex_hook_async_flags
ensure_feature_enabled "plugin_hooks"
remove_plugin_enabled "silver@alo-labs-codex"
ensure_plugin_enabled "product-management@alo-labs-codex"
ensure_plugin_enabled "engineering@alo-labs-codex"
ensure_plugin_enabled "design@alo-labs-codex"
purge_legacy_silver_bullet_hooks_from_user_config

if find_silver_bullet_project_root >/dev/null 2>&1; then
  ensure_plugin_enabled "silver-bullet@alo-labs-codex"
else
  remove_plugin_enabled "silver-bullet@alo-labs-codex"
  remove_plugin_enabled "silver-bullet@alo-labs-codex-local"
  printf 'Skipping Silver Bullet plugin auto-enable outside a Silver Bullet project root.\n'
fi

ensure_marketplace_registered "${SUPERPOWERS_MARKETPLACE_SOURCE}"

if [[ -f "${HOME}/.claude/get-shit-done/VERSION" ]]; then
  printf 'GSD already installed at %s\n' "${HOME}/.claude/get-shit-done/VERSION"
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
  "${GSD_INSTALL_ARGS[@]}"
fi

sync_silver_bullet_skill_cache
scrub_legacy_silver_bullet_traces
merge_silver_bullet_hooks_into_user_config

if [[ "$PURGE_LEGACY_SKILLS" -eq 1 ]]; then
  LEGACY_SKILLS_HOME="${HOME}/.agents/skills"
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

printf 'Codex marketplace registered from %s\n' "${REPO_ROOT}"
