#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEST_DIR="${REPO_ROOT}/plugins/silver-bullet"

log() {
  printf '[codex-sync] %s\n' "$*"
}

mkdir -p "$DEST_DIR/.codex-plugin"

if [[ ! -f "$DEST_DIR/.codex-plugin/plugin.json" ]]; then
  printf 'ERROR: missing Codex manifest at %s\n' "$DEST_DIR/.codex-plugin/plugin.json" >&2
  exit 1
fi

log "Refreshing symlinked package surface in ${DEST_DIR}"

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
# marketplace repo, not in this SB package snapshot.
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
  skills
  templates
)

for entry in "${PACKAGE_ENTRIES[@]}"; do
  if [[ ! -e "${REPO_ROOT}/${entry}" && ! -L "${REPO_ROOT}/${entry}" ]]; then
    printf 'ERROR: package source missing: %s\n' "${entry}" >&2
    exit 1
  fi
  if [[ "$entry" == "skills" ]]; then
    ln -sfn "../../../../codex-plugins/skills" "${DEST_DIR}/${entry}"
  else
    ln -sfn "../../${entry}" "${DEST_DIR}/${entry}"
  fi
done

log "Codex package synchronized"
