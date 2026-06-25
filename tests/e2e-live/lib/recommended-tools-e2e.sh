#!/usr/bin/env bash
# E2E helpers — opt in all SB recommended tools for live enterprise testing.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TEMPLATE="${REPO_ROOT}/templates/silver-bullet.config.json.default"

sb_e2e_recommended_tool_ids() {
  printf '%s\n' graphify agentmemory alumnium rtk context_mode
}

# Merge recommended_tools from template into target .silver-bullet.json with all tools enabled.
sb_e2e_enable_all_recommended_tools() {
  local config_file="${1:-}"
  local project_root
  [[ -n "$config_file" && -f "$config_file" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  project_root="$(dirname "$config_file")"

  jq --slurpfile tpl "$TEMPLATE" '
    .recommended_tools = ($tpl[0].recommended_tools // .recommended_tools // {})
    | .recommended_tools.graphify.enabled_by_user = true
    | .recommended_tools.graphify.install_status = "installed"
    | .recommended_tools.graphify.enforcement_suspended = false
    | .recommended_tools.agentmemory.enabled_by_user = true
    | .recommended_tools.agentmemory.install_status = "installed"
    | .recommended_tools.agentmemory.enforcement_suspended = false
    | .recommended_tools.alumnium.enabled_by_user = true
    | .recommended_tools.alumnium.install_status = "installed"
    | .recommended_tools.alumnium.enforcement_suspended = false
    | .recommended_tools.rtk.enabled_by_user = true
    | .recommended_tools.rtk.install_status = "installed"
    | .recommended_tools.rtk.enforcement_suspended = false
    | .recommended_tools.context_mode.enabled_by_user = true
    | .recommended_tools.context_mode.install_status = "installed"
    | .recommended_tools.context_mode.enforcement_suspended = false
  ' "$config_file" >"${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"

  mkdir -p "${project_root}/graphify-out" "${project_root}/.agentmemory/memory"
  touch "${project_root}/graphify-out/graph.json" 2>/dev/null || true
}

sb_e2e_assert_all_recommended_tools_enabled() {
  local config_file="${1:-}"
  local tool_id
  [[ -f "$config_file" ]] || return 1
  for tool_id in $(sb_e2e_recommended_tool_ids); do
    jq -e --arg id "$tool_id" '.recommended_tools[$id].enabled_by_user == true' "$config_file" >/dev/null 2>&1 || return 1
    jq -e --arg id "$tool_id" '.recommended_tools[$id].install_status == "installed"' "$config_file" >/dev/null 2>&1 || return 1
  done
}
