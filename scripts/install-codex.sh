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

  if grep -Fq "[marketplaces.${marketplace_name}]" "$config_file" 2>/dev/null; then
    "${CODEX_BIN}" plugin marketplace remove "${marketplace_name}"
  fi
}

ensure_marketplace_registered() {
  local source_spec="$1"
  local config_file
  config_file="$(resolve_codex_config_file)"

  if grep -Fq "source = \"${source_spec}\"" "$config_file" 2>/dev/null; then
    printf 'Codex marketplace already registered from %s\n' "${source_spec}"
    return 0
  fi

  "${CODEX_BIN}" plugin marketplace add "${source_spec}"
}

refresh_marketplace() {
  local marketplace_name="$1"

  "${CODEX_BIN}" plugin marketplace upgrade "${marketplace_name}"
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
refresh_marketplace "alo-labs-codex"
ensure_feature_enabled "plugin_hooks"
remove_plugin_enabled "silver@alo-labs-codex"
ensure_plugin_enabled "silver-bullet@alo-labs-codex"
ensure_plugin_enabled "product-management@alo-labs-codex"
ensure_plugin_enabled "engineering@alo-labs-codex"
ensure_plugin_enabled "design@alo-labs-codex"

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
