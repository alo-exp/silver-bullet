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


render_agent_bundle() {
  local agent="$1"

  mkdir -p "${REPO_ROOT}/agents" "${REPO_ROOT}/host-bundles"
  python3 "$AGENT_RENDERER" render \
    --agent "$agent" \
    --source-root "${REPO_ROOT}/skills" \
    --dest-root "$(sb_agent_bundle_root "$REPO_ROOT" "$agent")"
}


usage() {
  cat <<'USAGE'
Usage: scripts/install-codex.sh [--purge-legacy-skills] [--public-release]

Synchronizes the local Codex plugin package and registers the unified
`alo-labs/agent-plugins` marketplace with Codex.

Options:
  --purge-legacy-skills  Remove SB skill directories already copied into ~/.agents/skills
  --public-release       Refresh from the published Codex marketplace instead of the local checkout
USAGE
}


codex_marketplace_root() {
  local config_file
  local default_root="${CODEX_HOME_ROOT}/.codex/.tmp/marketplaces/alo-labs-codex"
  config_file="$(resolve_codex_config_file)"

  if [[ -f "$config_file" ]]; then
    local resolved
    resolved="$(python3 - "$config_file" "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" <<'PY'
import sys

sys.path.insert(0, sys.argv[2])
from sb_host_config import ConfigError, read_toml, toml_parser  # noqa: E402

try:
    loads = toml_parser()
    if loads is not None:
        with open(sys.argv[1], encoding="utf-8") as handle:
            section = loads(handle.read()).get("marketplaces", {})
        table = section.get("alo-labs-codex", {}) if isinstance(section, dict) else None
        if not isinstance(table, dict):
            raise ConfigError("marketplaces.alo-labs-codex is not a table")
    else:  # no TOML parser installed: the statement-level reader finds the same two strings
        table = read_toml(sys.argv[1]).string_values(("marketplaces", "alo-labs-codex"))
    if table.get("source_type") == "local" and isinstance(table.get("source"), str):
        print(table["source"])
except (OSError, ValueError, ConfigError) as exc:
    print(f"WARN: cannot read the Codex marketplace registration in {sys.argv[1]} ({exc}); using the default marketplace root", file=sys.stderr)
PY
)"
    if [[ -n "$resolved" && -d "$resolved" ]]; then
      printf '%s\n' "$resolved"
      return 0
    fi
  fi

  printf '%s\n' "$default_root"
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


