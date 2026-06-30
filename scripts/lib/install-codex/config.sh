#!/usr/bin/env bash
# Codex install module — auto-split from install-codex.sh
resolve_codex_config_file() {
  local config_file="${CODEX_HOME_ROOT}/.codex/config.toml"
  mkdir -p "${CODEX_HOME_ROOT}/.codex"
  if [[ -f "$config_file" ]]; then
    printf '%s\n' "$config_file"
    return 0
  fi
  printf '%s\n' "${CODEX_HOME_ROOT}/.codex/config.toml"
}


usage() {
  cat <<'USAGE'
Usage: scripts/install-codex.sh [--purge-legacy-skills] [--public-release]

Synchronizes the local Codex plugin package and registers the shared
`alo-labs/codex-plugins` marketplace with Codex.

Options:
  --purge-legacy-skills  Remove SB skill directories already copied into ~/.agents/skills
  --public-release       Refresh from the published Codex marketplace instead of the local checkout
USAGE
}


codex_marketplace_root() {
  local marketplace_root="${CODEX_HOME_ROOT}/.codex/.tmp/marketplaces/alo-labs-codex"
  if [[ -d "$marketplace_root" ]]; then
    printf '%s\n' "$marketplace_root"
    return 0
  fi
  printf '%s\n' "${CODEX_HOME_ROOT}/.codex/.tmp/marketplaces/alo-labs-codex"
}


