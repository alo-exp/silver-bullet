#!/usr/bin/env bash
# Codex install module — auto-split from install-codex.sh
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
  local upstream_ref
  marketplace_root="$(codex_marketplace_root)"

  if [[ -d "${marketplace_root}/.git" ]]; then
    git -C "$marketplace_root" fetch --all --prune >/dev/null 2>&1 || true
    upstream_ref="$(git -C "$marketplace_root" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
    if [[ -n "$upstream_ref" ]]; then
      git -C "$marketplace_root" reset --hard "$upstream_ref" >/dev/null 2>&1 || true
    else
      git -C "$marketplace_root" pull --ff-only >/dev/null 2>&1 || true
    fi
    git -C "$marketplace_root" clean -fd -- \
      plugins/silver-bullet \
      agents \
      commands \
      docs \
      hooks \
      scripts \
      skill-source \
      skills \
      templates >/dev/null 2>&1 || true
  fi
}


cleanup_legacy_marketplace_picker_surfaces() {
  local marketplace_root
  marketplace_root="$(codex_marketplace_root)"

  [[ -d "$marketplace_root" ]] || return 0

  if [[ "$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$marketplace_root")" == "$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$REPO_ROOT")" ]]; then
    return 0
  fi

  rm -rf -- "${marketplace_root}/skills" "${marketplace_root}/agents" "${marketplace_root}/skill-source"
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
  for dir in hooks templates docs commands scripts; do
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

  if [[ "$(resolve_realpath "$marketplace_root")" != "$(resolve_realpath "$REPO_ROOT")" ]]; then
    rm -rf -- "${marketplace_root}/skills" "${marketplace_root}/agents"
  fi

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
  rm -rf -- "$package_root"
  mkdir -p "$(dirname "$package_root")"

  # Keep the marketplace package root in lockstep with the repo's generated
  # plugin snapshot. The snapshot intentionally stores skill sources as
  # extensionless SILVER_SOURCE files so Codex's picker cannot recursively
  # discover duplicate plugin-cache Markdown skills.
  rsync -a --delete "${REPO_ROOT}/plugins/silver-bullet/" "${package_root}/"
}


