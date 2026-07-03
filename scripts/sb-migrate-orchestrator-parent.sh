#!/usr/bin/env bash
# Migrate existing SB projects to orchestrator parent mode (only supported mode).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN_ROOT="${PLUGIN_ROOT:-$REPO_ROOT}"

config_file=""
search_dir="${1:-$PWD}"
while true; do
  if [[ -f "$search_dir/.silver-bullet.json" ]] && [[ -f "$search_dir/silver-bullet.md" ]]; then
    config_file="$search_dir/.silver-bullet.json"
    break
  fi
  if [[ -d "$search_dir/.git" ]] || [[ "$search_dir" == "/" ]]; then
    break
  fi
  search_dir=$(dirname "$search_dir")
done

if [[ -z "$config_file" ]]; then
  echo "No SB project found (need .silver-bullet.json + silver-bullet.md)" >&2
  exit 1
fi

command -v jq >/dev/null 2>&1 || { echo "jq required" >&2; exit 1; }

proj_root="$(dirname "$config_file")"
mode="$(jq -r '.orchestrator_mode // "absent"' "$config_file")"

tmp="${config_file}.tmp"
jq '.orchestrator_mode = "parent"' "$config_file" >"$tmp" && mv "$tmp" "$config_file"
echo "Set orchestrator_mode=parent (was: $mode)"

mkdir -p "$proj_root/.silver-bullet/orchestrator-workers"
if [[ -d "$PLUGIN_ROOT/templates/orchestrator-workers" ]]; then
  cp -R "$PLUGIN_ROOT/templates/orchestrator-workers/." "$proj_root/.silver-bullet/orchestrator-workers/"
  echo "Copied worker templates to .silver-bullet/orchestrator-workers/"
fi

mkdir -p "$proj_root/.cursor/rules"
if [[ -f "$PLUGIN_ROOT/scripts/lib/install-cursor/templates/cursor-rules/silver-orchestrator.mdc" ]]; then
  cp "$PLUGIN_ROOT/scripts/lib/install-cursor/templates/cursor-rules/silver-orchestrator.mdc" "$proj_root/.cursor/rules/silver-orchestrator.mdc"
  echo "Refreshed .cursor/rules/silver-orchestrator.mdc"
fi

echo "Migration complete for $proj_root"
