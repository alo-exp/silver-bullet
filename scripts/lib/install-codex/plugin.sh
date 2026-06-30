#!/usr/bin/env bash
# Codex install module — auto-split from install-codex.sh
install_silver_bullet_codex_cli() {
  local bin_dir="${CODEX_HOME_ROOT}/.codex/bin"
  local cli_path="${bin_dir}/silver-bullet"
  local package_root="${CODEX_HOME_ROOT}/.codex/plugins/cache/alo-labs-codex/silver-bullet"
  local target_path="${package_root}/current/scripts/silver-bullet"
  local latest_dir

  if [[ ! -f "$target_path" ]]; then
    latest_dir="$(find "$package_root" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -V | tail -n 1 || true)"
    target_path="${latest_dir}/scripts/silver-bullet"
  fi

  [[ -f "$target_path" ]] || return 0

  mkdir -p "$bin_dir"
  cat > "$cli_path" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec "$target_path" "\$@"
EOF
  chmod 700 "$cli_path"
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


