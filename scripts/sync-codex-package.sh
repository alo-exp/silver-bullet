#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEST_DIR="${REPO_ROOT}/plugins/silver-bullet"
AGENT_RENDERER="${SCRIPT_DIR}/render-agent-bundle.py"

log() {
  printf '[codex-sync] %s\n' "$*"
}

mkdir -p "$DEST_DIR/.codex-plugin"

if [[ ! -f "$DEST_DIR/.codex-plugin/plugin.json" ]]; then
  printf 'ERROR: missing Codex manifest at %s\n' "$DEST_DIR/.codex-plugin/plugin.json" >&2
  exit 1
fi

log "Refreshing generated package surface in ${DEST_DIR}"

mkdir -p "${REPO_ROOT}/agents"
python3 "$AGENT_RENDERER" render --agent claude --source-root "${REPO_ROOT}/skills" --dest-root "${REPO_ROOT}/agents/claude"
python3 "$AGENT_RENDERER" render --agent codex --source-root "${REPO_ROOT}/skills" --dest-root "${REPO_ROOT}/agents/codex"

shopt -s dotglob nullglob
for entry in "${DEST_DIR}"/*; do
  if [[ "$(basename "$entry")" == ".codex-plugin" ]]; then
    continue
  fi
  rm -rf -- "$entry"
done
shopt -u dotglob nullglob

# Codex gets the plugin-facing SB surface here. Project-instance artifacts
# like planning, Claude packaging, Forge packaging, and repo governance live
# outside this bundle. Third-party Codex wrappers are maintained in the shared
# marketplace repo, not in this SB package snapshot. The packaged skills tree is
# generated under agents/ so the repo keeps agent-specific variants while the
# source skills remain the authoring source of truth.
PACKAGE_ENTRIES=(
  AGENTS.md
  CHANGELOG.md
  CODE_OF_CONDUCT.md
  CONTRIBUTING.md
  LICENSE
  README.md
  SECURITY.md
  SENTINEL-audit-silver-bullet-v0.15.1.md
  SENTINEL-audit-silver-init.md
  commands
  .silver-bullet.json
  docs
  hooks
  scripts
  templates
)

for entry in "${PACKAGE_ENTRIES[@]}"; do
  if [[ ! -e "${REPO_ROOT}/${entry}" && ! -L "${REPO_ROOT}/${entry}" ]]; then
    printf 'ERROR: package source missing: %s\n' "${entry}" >&2
    exit 1
  fi
  ln -sfn "../../${entry}" "${DEST_DIR}/${entry}"
done

if [[ -d "${REPO_ROOT}/templates" ]]; then
  rm -rf -- "${DEST_DIR}/templates"
  mkdir -p -- "${DEST_DIR}/templates"
  rsync -a --delete "${REPO_ROOT}/templates/" "${DEST_DIR}/templates/"
fi

# Codex can discover plugin-owned picker entries from any cached *SKILL.md file
# under the plugin package. Keep SB's packaged skill sources available for the
# installer, but store them under a filename that does not match skill discovery
# globs so the only user-facing picker surface is the native ~/.codex/skills
# mirror with /Silver: titles.
rm -rf -- "${DEST_DIR}/skills" "${DEST_DIR}/skill-source" "${DEST_DIR}/.generated-skills" "${DEST_DIR}/agents"
mkdir -p -- "${DEST_DIR}/skill-source"
rsync -a --delete "${REPO_ROOT}/agents/codex/" "${DEST_DIR}/skill-source/"
find "${DEST_DIR}/skill-source" -name SKILL.md -type f -exec sh -c '
  for path do
    mv "$path" "$(dirname "$path")/SILVER_SOURCE.md"
  done
' sh {} +

if [[ -x "${SCRIPT_DIR}/codex-sanitize-package.sh" ]]; then
  "${SCRIPT_DIR}/codex-sanitize-package.sh" "$DEST_DIR"
else
  printf 'ERROR: codex sanitizer helper missing at %s\n' "${SCRIPT_DIR}/codex-sanitize-package.sh" >&2
  exit 1
fi

log "Codex package synchronized"
