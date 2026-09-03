# shellcheck shell=bash
# Graphify probe — CLI, MCP, index, platform registration.

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
# shellcheck source=graphify-worktree.sh
source "$(dirname "${BASH_SOURCE[0]}")/graphify-worktree.sh"

rt_probe_graphify_mcp_configured() {
  local host="${RT_HOST:-cursor}"
  case "$host" in
    cursor)
      [[ -f "${HOME}/.cursor/mcp.json" ]] || return 1
      jq -e '.mcpServers.graphify' "${HOME}/.cursor/mcp.json" >/dev/null 2>&1
      ;;
    *) return 1 ;;
  esac
}

rt_probe_graphify_mcp_binary() {
  command -v graphify-mcp >/dev/null 2>&1
}

rt_probe_graphify_base_only() {
  command -v graphify >/dev/null 2>&1 && ! rt_probe_graphify_mcp_binary
}


rt_probe_graphify_skill_package_skew() {
  command -v graphify >/dev/null 2>&1 || return 1
  local out
  out="$(graphify --version </dev/null 2>&1 || true)"
  printf '%s' "$out" | grep -qiE 'skill is from graphify|skill.*package'
}

rt_probe_graphify() {
  local tool_id="graphify"
  local consent activation="none" canonical repairable=0
  local cfg="${RT_CONFIG_FILE:-$(rt_project_config)}"
  local evidence=()
  local fu=0 fd=0 fp=0 fs=0 ff=0 frr=0 frp=0 fr=0

  consent="$(rt_consent_for "$tool_id")"

  if ! rt_host_supported "${RT_HOST:-cursor}"; then
    fu=1
    canonical="$(rt_derive_canonical_state "$fu" "$fd" "$fp" "$fs" "$ff" "$frr" "$frp" "$fr")"
    rt_emit_probe_result "$tool_id" "$consent" "$canonical" "$activation" 0
    return 0
  fi

  case "$consent" in
    disabled) fd=1 ;;
    pending|"") fp=1 ;;
    enabled)
      if rt_is_suspended "$tool_id"; then
        fs=1
      elif ! sb_graphify_cli_available 2>/dev/null; then
        ff=1; evidence+=("cli_missing"); frp=1; repairable=1
      elif ! rt_probe_graphify_mcp_binary; then
        frp=1; repairable=1; evidence+=("mcp_binary_missing")
        rt_probe_graphify_base_only && evidence+=("base_only_install")
      elif ! rt_probe_graphify_mcp_configured; then
        frp=1; repairable=1; activation="partial"; evidence+=("mcp_not_configured")
      elif [[ -n "$cfg" ]] && ! sb_graphify_index_exists "${RT_PROJECT_ROOT:-}" "$cfg" 2>/dev/null; then
        frp=1; repairable=1; evidence+=("index_missing")
      elif [[ -L "${RT_PROJECT_ROOT:-}/graphify-out" ]] || [[ -L "${RT_PROJECT_ROOT:-}/graphify-out/graph.json" ]]; then
        ff=1; evidence+=("symlinked_graph_dir")
      elif rt_probe_graphify_index_stale; then
        frp=1; repairable=1; evidence+=("index_stale")
      elif ! sb_graphify_platform_artifact_present "${RT_PROJECT_ROOT:-}" "${RT_HOST:-}" 2>/dev/null; then
        frp=1; repairable=1; evidence+=("platform_artifact_missing")
      else
        activation="full"; fr=1
        if rt_probe_graphify_skill_package_skew; then
          evidence+=("skill_package_skew")
        fi
      fi
      ;;
  esac

  canonical="$(rt_derive_canonical_state "$fu" "$fd" "$fp" "$fs" "$ff" "$frr" "$frp" "$fr")"
  RT_PROBE_EXTRA_JSON="$(jq -n \
    --argjson evidence "$(rt_evidence_json_array ${evidence[@]+"${evidence[@]}"})" \
    '{configured:{mcp:(($evidence|index("mcp_not_configured"))|not)},
      live:{cli_present:(($evidence|index("cli_missing"))|not),mcp_live:(($evidence|index("mcp_binary_missing"))|not)}}')"
  rt_emit_probe_result "$tool_id" "$consent" "$canonical" "$activation" "$repairable" ${evidence[@]+"${evidence[@]}"}
  unset RT_PROBE_EXTRA_JSON
}
