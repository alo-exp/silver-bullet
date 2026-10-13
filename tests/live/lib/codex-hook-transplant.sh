#!/usr/bin/env bash
# Harvest the install-generated Silver Bullet user-hook surface in a disposable
# Codex home, then transplant only that merged hooks.json + trust state into an
# existing isolated runtime. This avoids the broader install-time mutations that
# currently break native Codex/Kay hook delivery in temp homes.

set -euo pipefail

sb_extract_user_hook_state_blob() {
  local logical_hooks_path="$1"
  local hooks_path="$2"
  local output_path="$3"

  python3 - "$logical_hooks_path" "$hooks_path" "$output_path" <<'PY'
import hashlib
import json
import os
import pathlib
import re
import sys

logical_hooks_path = pathlib.Path(sys.argv[1])
hooks_path = pathlib.Path(sys.argv[2])
output_path = pathlib.Path(sys.argv[3])

if not hooks_path.is_file():
    output_path.write_text("")
    raise SystemExit(0)

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

hooks_data = json.loads(hooks_path.read_text()).get("hooks", {})
logical_paths = []
for candidate in (logical_hooks_path, logical_hooks_path.resolve()):
    candidate_str = str(candidate)
    if candidate_str not in logical_paths:
        logical_paths.append(candidate_str)

lines = []
for logical_path in logical_paths:
    for event_name, groups in hooks_data.items():
        slug = event_slug(event_name)
        for group_index, group in enumerate(groups):
            for hook_index, hook in enumerate(group.get("hooks", [])):
                digest = hook_current_hash(event_name, group.get("matcher"), hook)
                if digest is None:
                    continue
                key = f"{logical_path}:{slug}:{group_index}:{hook_index}"
                lines.append(f'[hooks.state."{key}"]')
                lines.append(f'trusted_hash = "{digest}"')
                lines.append("")

output_path.write_text('\n'.join(lines).rstrip('\n') + '\n')
PY
}

sb_inject_user_hook_state_blob() {
  local config_path="$1"
  local hooks_path="$2"
  local state_blob_path="$3"

  python3 - "$config_path" "$hooks_path" "$state_blob_path" <<'PY'
import pathlib
import sys

config_path = pathlib.Path(sys.argv[1])
hooks_path = pathlib.Path(sys.argv[2])
state_blob_path = pathlib.Path(sys.argv[3])

text = config_path.read_text() if config_path.is_file() else ""
lines = text.splitlines()
state_blob = state_blob_path.read_text().rstrip('\n')

user_suffix = '/.codex/hooks.json:'
out = []
i = 0

while i < len(lines):
    line = lines[i]
    if line.startswith('[hooks.state."') and user_suffix in line:
        i += 1
        while i < len(lines) and not lines[i].startswith('['):
            i += 1
        continue
    out.append(line)
    i += 1

if out and out[-1] != '':
    out.append('')

if not any(line == '[hooks.state]' for line in out):
    out.append('[hooks.state]')

if state_blob:
    out.append(state_blob)

config_path.write_text('\n'.join(out).rstrip('\n') + '\n')
PY
}

sb_dedupe_hook_state_blocks() {
  local config_path="$1"

  python3 - "$config_path" <<'PY'
import pathlib
import sys

config_path = pathlib.Path(sys.argv[1])
if not config_path.is_file():
    raise SystemExit(0)

lines = config_path.read_text().splitlines()
hook_blocks = {}
hook_order = []
out = []
insert_at = None
i = 0

while i < len(lines):
    line = lines[i]
    if line == '[hooks.state]':
        if insert_at is None:
            insert_at = len(out)
        i += 1
        continue
    if line.startswith('[hooks.state."'):
        if insert_at is None:
            insert_at = len(out)
        block = [line]
        i += 1
        while i < len(lines) and not lines[i].startswith('['):
            block.append(lines[i])
            i += 1
        if line not in hook_blocks:
            hook_order.append(line)
        hook_blocks[line] = '\n'.join(block)
        continue
    out.append(line)
    i += 1

if not hook_order:
    config_path.write_text('\n'.join(out).rstrip('\n') + '\n')
    raise SystemExit(0)

hook_section = ['[hooks.state]', '']
for header in hook_order:
    hook_section.append(hook_blocks[header])
    hook_section.append('')
while hook_section and hook_section[-1] == '':
    hook_section.pop()

if insert_at is None:
    insert_at = len(out)
if insert_at > 0 and out[insert_at - 1] != '':
    hook_section.insert(0, '')
if insert_at < len(out) and out[insert_at] != '':
    hook_section.append('')

out[insert_at:insert_at] = hook_section
config_path.write_text('\n'.join(out).rstrip('\n') + '\n')
PY
}

sb_seed_managed_plugin_hook_state() {
  local config_path="$1"
  local registry_path="$2"

  python3 - "$config_path" "$registry_path" <<'PY'
import hashlib
import json
import os
import pathlib
import re
import sys

config_path = pathlib.Path(sys.argv[1])
registry_path = pathlib.Path(sys.argv[2])

if not registry_path.is_file():
    raise SystemExit(0)

try:
    registry = json.loads(registry_path.read_text())
except Exception:
    raise SystemExit(0)

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

entries_by_key = {}
plugin_ids = []
for plugin_id, installs in registry.get("plugins", {}).items():
    install_path = None
    for install in installs:
        candidate = pathlib.Path(install.get("installPath", ""))
        if candidate.is_dir():
            install_path = candidate
            break
    if install_path is None:
        continue

    manifest_path = install_path / ".codex-plugin" / "plugin.json"
    if not manifest_path.is_file():
        continue

    try:
        manifest = json.loads(manifest_path.read_text())
    except Exception:
        continue

    hooks_rel = manifest.get("hooks")
    if not isinstance(hooks_rel, str) or not hooks_rel:
        continue

    hooks_path = install_path / hooks_rel
    if not hooks_path.is_file():
        continue

    try:
        hooks_data = json.loads(hooks_path.read_text()).get("hooks", {})
    except Exception:
        continue

    plugin_ids.append(plugin_id)
    for event_name, groups in hooks_data.items():
        slug = event_slug(event_name)
        for group_index, group in enumerate(groups):
            for hook_index, hook in enumerate(group.get("hooks", [])):
                digest = hook_current_hash(event_name, group.get("matcher"), hook)
                if digest is None:
                    continue
                key = f"{plugin_id}:hooks/hooks.json:{slug}:{group_index}:{hook_index}"
                entries_by_key[key] = digest

if not entries_by_key:
    raise SystemExit(0)

text = config_path.read_text() if config_path.is_file() else ""
lines = text.splitlines()
output = []
i = 0
inserted = False
hooks_state_seen = False

def is_managed_hook_state(line: str) -> bool:
    return any(line.startswith(f'[hooks.state."{plugin_id}:hooks/hooks.json:') for plugin_id in plugin_ids)

def render_entries():
    rendered = []
    for key, digest in entries_by_key.items():
        rendered.append(f'[hooks.state."{key}"]')
        rendered.append(f'trusted_hash = "{digest}"')
        rendered.append("")
    return rendered

while i < len(lines):
    line = lines[i]
    if line == "[hooks.state]":
        hooks_state_seen = True
        output.append(line)
        i += 1
        continue

    if hooks_state_seen and is_managed_hook_state(line):
        i += 1
        while i < len(lines) and not lines[i].startswith('['):
            i += 1
        continue

    if hooks_state_seen and line.startswith("[") and not line.startswith("[hooks.state."):
        if not inserted:
            output.extend(render_entries())
            inserted = True
        hooks_state_seen = False
        output.append(line)
        i += 1
        continue

    output.append(line)
    i += 1

if hooks_state_seen and not inserted:
    output.extend(render_entries())
    inserted = True

if not hooks_state_seen and not inserted:
    if output and output[-1] != "":
        output.append("")
    output.append("[hooks.state]")
    output.extend(render_entries())

config_path.write_text("\n".join(output).rstrip("\n") + "\n")
PY
}

sb_rewrite_user_hook_surface_paths() {
  local hooks_path="$1"
  local harvest_home_root="$2"
  local target_home_root="$3"
  local original_home_root="${4:-}"

  python3 - "$hooks_path" "$harvest_home_root" "$target_home_root" "$original_home_root" <<'PY'
import json
import pathlib
import sys

hooks_path = pathlib.Path(sys.argv[1])
harvest_home_root_raw = sys.argv[2]
harvest_home_root = pathlib.Path(harvest_home_root_raw)
target_home_root = pathlib.Path(sys.argv[3])
original_home_root_raw = sys.argv[4]
original_home_root = pathlib.Path(original_home_root_raw) if original_home_root_raw else None
target_codex_home = str(target_home_root / ".codex")

source_prefixes = []
for raw_home_root, home_root in [
    (harvest_home_root_raw, harvest_home_root),
    (original_home_root_raw, original_home_root),
]:
    if home_root is None or not raw_home_root:
        continue
    raw_codex_home = raw_home_root.rstrip("/") + "/.codex"
    for candidate in [raw_codex_home, home_root / ".codex", (home_root / ".codex").resolve()]:
        candidate_str = str(candidate)
        if candidate_str not in source_prefixes:
            source_prefixes.append(candidate_str)
source_prefixes.sort(key=len, reverse=True)

def rewrite_string(value: str) -> str:
    rewritten = value
    for source_prefix in source_prefixes:
        rewritten = rewritten.replace(source_prefix, target_codex_home)
    return rewritten

def rewrite_json(value):
    if isinstance(value, str):
        return rewrite_string(value)
    if isinstance(value, list):
        return [rewrite_json(item) for item in value]
    if isinstance(value, dict):
        return {key: rewrite_json(item) for key, item in value.items()}
    return value

hooks_data = json.loads(hooks_path.read_text())
hooks_path.write_text(json.dumps(rewrite_json(hooks_data), indent=2) + '\n')
PY
}

sb_rewrite_hook_surface_tree() {
  local root="$1"
  local harvest_home_root="$2"
  local target_home_root="$3"
  local original_home_root="${4:-}"

  [[ -d "$root" ]] || return 0

  while IFS= read -r hooks_path; do
    [[ -n "$hooks_path" ]] || continue
    sb_rewrite_user_hook_surface_paths \
      "$hooks_path" \
      "$harvest_home_root" \
      "$target_home_root" \
      "$original_home_root"
  done < <(find "$root" -type f -name hooks.json | sort)
}

sb_refresh_plugin_cache_current_symlinks() {
  local cache_root="$1"

  python3 - "$cache_root" <<'PY'
import pathlib
import re
import shutil
import sys

cache_root = pathlib.Path(sys.argv[1])
if not cache_root.is_dir():
    raise SystemExit(0)

def version_sort_key(path: pathlib.Path):
    return tuple(int(part) if part.isdigit() else part for part in re.split(r"([0-9]+)", path.name))

for plugin_root in cache_root.iterdir():
    if not plugin_root.is_dir():
        continue
    version_dirs = sorted(
        [path for path in plugin_root.iterdir() if path.is_dir() and path.name != "current"],
        key=version_sort_key,
    )
    if not version_dirs:
        continue
    current_path = plugin_root / "current"
    target_path = version_dirs[-1]
    if current_path.exists() or current_path.is_symlink():
        if current_path.is_dir() and not current_path.is_symlink():
            shutil.rmtree(current_path)
        else:
            current_path.unlink()
    current_path.symlink_to(target_path.resolve())
PY
}


sb_ensure_silver_bullet_registry_entry() {
  local home_root="$1"
  local registry_file="${home_root}/.codex/plugins/installed_plugins.json"

  python3 - "$registry_file" "$home_root" <<'PY'
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
    raise SystemExit(0)

def version_sort_key(path: pathlib.Path):
    return tuple(int(part) if part.isdigit() else part for part in re.split(r"([0-9]+)", path.name))

version_dirs = sorted(
    [path for path in plugin_root.iterdir() if path.is_dir() and path.name != "current"],
    key=version_sort_key,
)
if not version_dirs:
    raise SystemExit(0)

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

sb_rewrite_text_file_runtime_paths() {
  local source_path="$1"
  local dest_path="$2"
  local harvest_home_root="$3"
  local target_home_root="$4"
  local original_home_root="${5:-}"

  python3 - "$source_path" "$dest_path" "$harvest_home_root" "$target_home_root" "$original_home_root" <<'PY'
import pathlib
import sys

source_path = pathlib.Path(sys.argv[1])
dest_path = pathlib.Path(sys.argv[2])
harvest_home_root_raw = sys.argv[3]
harvest_home_root = pathlib.Path(harvest_home_root_raw)
target_home_root = pathlib.Path(sys.argv[4])
original_home_root_raw = sys.argv[5]
original_home_root = pathlib.Path(original_home_root_raw) if original_home_root_raw else None
target_codex_home = str(target_home_root / ".codex")

source_prefixes = []
for raw_home_root, home_root in [
    (harvest_home_root_raw, harvest_home_root),
    (original_home_root_raw, original_home_root),
]:
    if home_root is None or not raw_home_root:
        continue
    raw_codex_home = raw_home_root.rstrip("/") + "/.codex"
    for candidate in [raw_codex_home, home_root / ".codex", (home_root / ".codex").resolve()]:
        candidate_str = str(candidate)
        if candidate_str not in source_prefixes:
            source_prefixes.append(candidate_str)
source_prefixes.sort(key=len, reverse=True)

content = source_path.read_text()
for source_prefix in source_prefixes:
    content = content.replace(source_prefix, target_codex_home)

dest_path.parent.mkdir(parents=True, exist_ok=True)
dest_path.write_text(content)
PY
}

sb_sync_silver_bullet_codex_bin() {
  local harvest_codex_home="$1"
  local target_codex_home="$2"
  local harvest_home_root="$3"
  local target_home_root="$4"
  local original_home_root="${5:-}"
  local harvest_cli="${harvest_codex_home}/bin/silver-bullet"
  local target_cli="${target_codex_home}/bin/silver-bullet"

  [[ -f "$harvest_cli" ]] || return 0

  sb_rewrite_text_file_runtime_paths \
    "$harvest_cli" \
    "$target_cli" \
    "$harvest_home_root" \
    "$target_home_root" \
    "$original_home_root"
  chmod 700 "$target_cli"
}

sb_sync_managed_native_codex_skills() {
  local harvest_skills_root="$1"
  local target_skills_root="$2"

  [[ -d "$harvest_skills_root" ]] || return 0

  python3 - "$harvest_skills_root" "$target_skills_root" <<'PY'
import pathlib
import shutil
import sys

harvest_skills_root = pathlib.Path(sys.argv[1])
target_skills_root = pathlib.Path(sys.argv[2])
marker_name = ".silver-bullet-managed"

desired = {}
for skill_dir in sorted(harvest_skills_root.iterdir(), key=lambda path: path.name):
    if not skill_dir.is_dir():
        continue
    if not (skill_dir / marker_name).exists():
        continue
    desired[skill_dir.name] = skill_dir

if not desired:
    return_code = 0
    raise SystemExit(return_code)

target_skills_root.mkdir(parents=True, exist_ok=True)

for target in sorted(target_skills_root.iterdir(), key=lambda path: path.name):
    if not target.is_dir():
        continue
    if (target / marker_name).exists() and target.name not in desired:
        shutil.rmtree(target)

for dirname, source in desired.items():
    target = target_skills_root / dirname
    if target.is_symlink() or target.is_file():
        target.unlink()
    elif target.exists():
        shutil.rmtree(target)
    shutil.copytree(source, target)
PY
}

sync_install_generated_codex_user_hooks() {
  local target_home_root="$1"
  local runtime_mode="${2:-codex}"
  local harvest_root=""
  local harvest_state_blob=""
  local target_codex_home="${target_home_root}/.codex"
  local target_marketplace_package_root="${target_codex_home}/.tmp/marketplaces/alo-labs-codex/plugins/silver-bullet"
  local command_package_root="${SB_LIVE_COMMAND_PACKAGE_ROOT:-$target_marketplace_package_root}"
  local command_package_version_root="${SB_LIVE_COMMAND_PACKAGE_VERSION_ROOT:-}"
  local harvest_marketplace_root="${harvest_root}/.codex/.tmp/marketplaces/alo-labs-codex"
  local target_marketplace_root="${target_codex_home}/.tmp/marketplaces/alo-labs-codex"
  local harvest_plugin_cache_root="${harvest_root}/.codex/plugins/cache/alo-labs-codex"
  local target_plugin_cache_root="${target_codex_home}/plugins/cache/alo-labs-codex"
  local harvest_user_hooks_root=""
  local target_user_hooks_root=""
  local harvest_codex_home=""

  if [[ "$runtime_mode" == "kay" ]]; then
    command_package_root="$target_marketplace_package_root"
    command_package_version_root=""
  fi

  harvest_root="$(mktemp -d "${TMPDIR:-/tmp}/sb-codex-hook-harvest.XXXXXX")"
  harvest_state_blob="$(mktemp "${TMPDIR:-/tmp}/sb-codex-hook-state.XXXXXX")"
  harvest_marketplace_root="${harvest_root}/.codex/.tmp/marketplaces/alo-labs-codex"
  target_marketplace_root="${target_codex_home}/.tmp/marketplaces/alo-labs-codex"
  harvest_plugin_cache_root="${harvest_root}/.codex/plugins/cache/alo-labs-codex"
  target_plugin_cache_root="${target_codex_home}/plugins/cache/alo-labs-codex"
  harvest_user_hooks_root="${harvest_root}/.codex/hooks"
  target_user_hooks_root="${target_codex_home}/hooks"
  harvest_codex_home="${harvest_root}/.codex"

  mkdir -p "${harvest_root}/.codex"
  if [[ "$runtime_mode" == "kay" ]]; then
    if [[ -f "${target_codex_home}/config.toml" ]]; then
      cp -p "${target_codex_home}/config.toml" "${harvest_root}/.codex/config.toml"
    fi
    if [[ -d "${target_codex_home}/plugins/cache/alo-labs-codex" ]]; then
      mkdir -p "${harvest_root}/.codex/plugins/cache"
      rsync -a "${target_codex_home}/plugins/cache/alo-labs-codex/" "${harvest_root}/.codex/plugins/cache/alo-labs-codex/"
    fi
    if [[ -d "${target_codex_home}/.tmp/marketplaces/alo-labs-codex" ]]; then
      mkdir -p "${harvest_root}/.codex/.tmp/marketplaces"
      rsync -a "${target_codex_home}/.tmp/marketplaces/alo-labs-codex/" "${harvest_root}/.codex/.tmp/marketplaces/alo-labs-codex/"
    fi
    # Reuse the real host GSD install so the harvest path does not reinstall
    # it through npm on every Kay live turn. The live bootstrap only needs the
    # already-installed entrypoint and version marker.
    if [[ -e "${SB_LIVE_ORIGINAL_HOME:-}/.codex/get-shit-done" && ! -e "${harvest_root}/.codex/get-shit-done" ]]; then
      ln -sfn "${SB_LIVE_ORIGINAL_HOME}/.codex/get-shit-done" "${harvest_root}/.codex/get-shit-done"
    fi
  else
    rsync -a "${target_codex_home}/" "${harvest_root}/.codex/"
  fi

  (
    export HOME="$harvest_root"
    if [[ "$runtime_mode" == "kay" ]]; then
      export KAY_HOME="$harvest_root"
    else
      unset KAY_HOME
    fi
    cd "$SB_ROOT"
    ./scripts/install-codex.sh --purge-legacy-skills >/dev/null
  )

  sb_rewrite_hook_surface_tree \
    "${harvest_root}/.codex" \
    "$harvest_root" \
    "$target_home_root" \
    "${SB_LIVE_ORIGINAL_HOME:-}"

  sb_extract_user_hook_state_blob \
    "${target_home_root}/.codex/hooks.json" \
    "${harvest_root}/.codex/hooks.json" \
    "$harvest_state_blob"

  if [[ -d "$harvest_marketplace_root" ]]; then
    mkdir -p "$(dirname "$target_marketplace_root")"
    rsync -a --delete "${harvest_marketplace_root}/" "${target_marketplace_root}/"
  fi

  if [[ -d "$harvest_user_hooks_root" ]]; then
    mkdir -p "$(dirname "$target_user_hooks_root")"
    rsync -a --delete "${harvest_user_hooks_root}/" "${target_user_hooks_root}/"
  else
    rm -rf -- "$target_user_hooks_root"
  fi

  sb_sync_silver_bullet_codex_bin \
    "$harvest_codex_home" \
    "$target_codex_home" \
    "$harvest_root" \
    "$target_home_root" \
    "${SB_LIVE_ORIGINAL_HOME:-}"

  sb_sync_managed_native_codex_skills \
    "${harvest_codex_home}/skills" \
    "${target_codex_home}/skills"

  if [[ -d "${harvest_marketplace_root}/plugins/silver-bullet" ]]; then
    if [[ -n "$command_package_version_root" ]]; then
      mkdir -p "$(dirname "$command_package_version_root")"
      rsync -a --delete "${harvest_marketplace_root}/plugins/silver-bullet/" "${command_package_version_root}/"
      rm -rf "$command_package_root"
      ln -sfn "$command_package_version_root" "$command_package_root"
    else
      mkdir -p "$(dirname "$command_package_root")"
      rsync -a --delete "${harvest_marketplace_root}/plugins/silver-bullet/" "${command_package_root}/"
    fi
  fi

  if [[ -d "$harvest_plugin_cache_root" ]]; then
    mkdir -p "$(dirname "$target_plugin_cache_root")"
    rsync -a --delete "${harvest_plugin_cache_root}/" "${target_plugin_cache_root}/"
    sb_refresh_plugin_cache_current_symlinks "$target_plugin_cache_root"
  fi

  if [[ -f "${harvest_root}/.codex/hooks.json" ]]; then
    cp "${harvest_root}/.codex/hooks.json" "${target_codex_home}/hooks.json"
  else
    rm -f -- "${target_codex_home}/hooks.json"
  fi

  sb_inject_user_hook_state_blob \
    "${target_codex_home}/config.toml" \
    "${target_codex_home}/hooks.json" \
    "$harvest_state_blob"
  sb_ensure_silver_bullet_registry_entry "$target_home_root"
  sb_seed_managed_plugin_hook_state \
    "${target_codex_home}/config.toml" \
    "${target_codex_home}/plugins/installed_plugins.json"
  sb_dedupe_hook_state_blocks "${target_codex_home}/config.toml"

  rm -f "$harvest_state_blob"
  rm -rf "$harvest_root"
}
