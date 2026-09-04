# shellcheck shell=bash
# LeanCTX probe and repair.

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
# shellcheck source=vendor-doctor.sh
source "$(dirname "${BASH_SOURCE[0]}")/vendor-doctor.sh"

rt_leanctx_mcp_file() {
  rt_host_mcp_config_path "${RT_HOST:-cursor}"
}

# Duplicate leanctx + lean-ctx keys are a config FAIL when LeanCTX is opted in.
rt_probe_leanctx_duplicate_mcp() {
  local f
  f="$(rt_leanctx_mcp_file)"
  [[ -f "$f" ]] || return 1
  if [[ "${RT_HOST:-cursor}" == "codex" ]]; then
    grep -q '^\[mcp_servers\.leanctx\]$' "$f" 2>/dev/null \
      && grep -q '^\[mcp_servers\.lean-ctx\]$' "$f" 2>/dev/null
  elif [[ "${RT_HOST:-cursor}" == "opencode" ]]; then
    jq -e '.mcp | has("leanctx") and (has("lean-ctx") or has("lean-ctx-standalone") or has("user-leanctx") or has("user-lean-ctx"))' "$f" >/dev/null 2>&1
  elif [[ "${RT_HOST:-cursor}" == "pi" ]]; then
    return 1
  else
    jq -e '.mcpServers | has("leanctx") and has("lean-ctx")' "$f" >/dev/null 2>&1
  fi
}

rt_probe_leanctx_mcp() {
  local host="${RT_HOST:-cursor}" f
  case "$host" in
    cursor|claude)
      f="$(rt_leanctx_mcp_file)"
      [[ -f "$f" ]] || return 1
      jq -e '.mcpServers.leanctx
        // .mcpServers["lean-ctx"]
        // .mcpServers["user-leanctx"]
        // .mcpServers["user-lean-ctx"]' "$f" >/dev/null 2>&1
      ;;
    codex|opencode|pi)
      rt_host_mcp_server_configured "$host" leanctx
      ;;
    *) return 1 ;;
  esac
}

rt_leanctx_mcp_env() {
  local f key="${1:-}" host="${RT_HOST:-cursor}"
  f="$(rt_leanctx_mcp_file)"
  [[ -f "$f" && -n "$key" ]] || return 1
  if [[ "$host" == "codex" ]]; then
    grep -A 12 '^\[mcp_servers\.leanctx\]$' "$f" 2>/dev/null \
      | grep -m1 -E "^${key}[[:space:]]*=[[:space:]]*\"" \
      | sed -E 's/^[^=]+=[[:space:]]*"([^"]*)".*$/\1/'
    return 0
  fi
  if [[ "$host" == "opencode" ]]; then
    jq -r --arg k "$key" '.mcp.leanctx.environment[$k] // ""' "$f" 2>/dev/null
    return 0
  fi
  if [[ "$host" == "pi" ]]; then
    f="${PI_CODING_AGENT_DIR:-${HOME}/.pi/agent}/extensions/pi-lean-ctx/config.json"
    [[ -f "$f" ]] || return 1
    jq -r --arg k "$key" '.env[$k] // ""' "$f" 2>/dev/null
    return 0
  fi
  jq -r --arg k "$key" '
    (.mcpServers.leanctx // .mcpServers["lean-ctx"] // .mcpServers["user-leanctx"] // .mcpServers["user-lean-ctx"] // {})
    | .env[$k] // ""
  ' "$f" 2>/dev/null
}

rt_probe_leanctx_lctx_prefix() {
  [[ -f "$(rt_leanctx_mcp_file)" ]] || return 1
  [[ "$(rt_leanctx_mcp_env LEANCTX_MCP_TOOL_PREFIX)" == "lctx_" ]]
}

rt_probe_leanctx_overlaps_disabled() {
  [[ -f "$(rt_leanctx_mcp_file)" ]] || return 1
  if [[ "${RT_HOST:-cursor}" == "codex" ]]; then
    local f="$(rt_leanctx_mcp_file)"
    local key
    for key in LEANCTX_DISABLE_SHELL_MCP LEANCTX_DISABLE_SANDBOX_MCP LEANCTX_DISABLE_FETCH_MCP LEANCTX_DISABLE_FTS; do
      grep -A 12 '^\[mcp_servers\.leanctx\]$' "$f" 2>/dev/null \
        | grep -qE "^${key}[[:space:]]*=[[:space:]]*\"1\"" || return 1
    done
    return 0
  fi
  if [[ "${RT_HOST:-cursor}" == "pi" ]]; then
    local pi_f="${PI_CODING_AGENT_DIR:-${HOME}/.pi/agent}/extensions/pi-lean-ctx/config.json"
    [[ -f "$pi_f" ]] || return 1
    for key in LEANCTX_DISABLE_SHELL_MCP LEANCTX_DISABLE_SANDBOX_MCP LEANCTX_DISABLE_FETCH_MCP LEANCTX_DISABLE_FTS; do
      [[ "$(jq -r --arg k "$key" '.env[$k] // ""' "$pi_f" 2>/dev/null)" == "1" ]] || return 1
    done
    jq -e '.disableTools | index("ctx_shell") != null' "$pi_f" >/dev/null 2>&1
    return $?
  fi
  [[ "$(rt_leanctx_mcp_env LEANCTX_DISABLE_SHELL_MCP)" == "1" ]] \
    && [[ "$(rt_leanctx_mcp_env LEANCTX_DISABLE_SANDBOX_MCP)" == "1" ]] \
    && [[ "$(rt_leanctx_mcp_env LEANCTX_DISABLE_FETCH_MCP)" == "1" ]] \
    && [[ "$(rt_leanctx_mcp_env LEANCTX_DISABLE_FTS)" == "1" ]]
}

# Vendor `lean-ctx doctor` when non-interactive. Never `lean-ctx init --agent`.
# 0=pass 1=fail 2=skip
rt_probe_leanctx_vendor_doctor() {
  [[ "${RT_SKIP_VENDOR_DOCTOR:-0}" == "1" ]] && return 2
  local bin cli
  local -a cmd extra=()
  if [[ -n "${RT_LEANCTX_DOCTOR_CMD:-}" ]]; then
    # shellcheck disable=SC2206
    cmd=(${RT_LEANCTX_DOCTOR_CMD})
    rt_run_vendor_doctor "${cmd[@]}"
    return $?
  fi
  if declare -F sb_leanctx_cli_command >/dev/null 2>&1; then
    cli="$(sb_leanctx_cli_command "${cfg:-}" 2>/dev/null || true)"
  else
    cli=""
  fi
  bin="${cli:-lean-ctx}"
  if [[ "$bin" == "lean-ctx" ]] && declare -F sb_leanctx_cli_path >/dev/null 2>&1; then
    bin="$(sb_leanctx_cli_path "${cfg:-}" 2>/dev/null || true)"
  fi
  [[ -n "$bin" ]] || return 2
  rt_vendor_doctor_subcommand_usable "$bin" || return 2
  if "$bin" doctor --help </dev/null 2>&1 | grep -qiE -- '--non-interactive'; then
    extra+=(--non-interactive)
  elif "$bin" doctor --help </dev/null 2>&1 | grep -qiE -- '--yes'; then
    extra+=(--yes)
  fi
  # Bash 3.2 + set -u: empty extra[@] is unbound and aborts the reconciler.
  if ((${#extra[@]})); then
    rt_run_vendor_doctor "$bin" doctor "${extra[@]}"
  else
    rt_run_vendor_doctor "$bin" doctor
  fi
}


rt_leanctx_version_int() {
  local v="${1%%-*}" maj min patch
  IFS='.' read -r maj min patch <<<"$v"
  maj="${maj:-0}"; min="${min:-0}"; patch="${patch:-0}"
  printf '%d' $((10#$maj * 1000000 + 10#$min * 1000 + 10#$patch))
}

rt_probe_leanctx_version_ok() {
  local cfg="${1:-}" min_ver raw ver
  min_ver="3.9.9"
  if [[ -n "$cfg" && -f "$cfg" ]]; then
    min_ver="$(jq -r '.recommended_tools.leanctx.min_version // "3.9.9"' "$cfg" 2>/dev/null || echo "3.9.9")"
  fi
  local cli_path
  cli_path="$(sb_leanctx_cli_path "$cfg" 2>/dev/null || true)"
  raw="$( [[ -n "$cli_path" ]] && "$cli_path" --version </dev/null 2>/dev/null || true)"
  ver="$(printf '%s' "$raw" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || true)"
  [[ -n "$ver" ]] || return 1
  [[ "$(rt_leanctx_version_int "$ver")" -ge "$(rt_leanctx_version_int "$min_ver")" ]]
}

rt_probe_leanctx() {
  local tool_id="leanctx" consent activation="none" canonical repairable=0
  local cfg="${RT_CONFIG_FILE:-$(rt_project_config)}"
  local evidence=()
  local fu=0 fd=0 fp=0 fs=0 ff=0 frr=0 frp=0 fr=0
  local vd_rc=0

  consent="$(rt_consent_for "$tool_id")"
  if ! rt_host_supported "${RT_HOST:-cursor}"; then fu=1
  else
    case "$consent" in
      disabled) fd=1 ;;
      pending|"") fp=1 ;;
      enabled)
        if rt_is_suspended "$tool_id"; then fs=1
        elif ! sb_leanctx_cli_available "$cfg" 2>/dev/null; then ff=1; evidence+=("cli_missing"); frp=1; repairable=1
        elif rt_probe_leanctx_duplicate_mcp; then
          # Config FAIL (also surfaced as D22 WARN). D10 fails when opted in.
          ff=1; frp=1; repairable=1; evidence+=("duplicate_mcp_keys"); evidence+=("duplicate_key")
        elif ! rt_probe_leanctx_version_ok "$cfg"; then frp=1; repairable=1; evidence+=("min_version")
        elif ! rt_probe_leanctx_mcp; then frp=1; repairable=1; activation="partial"; evidence+=("mcp_not_configured")
        elif ! rt_probe_leanctx_lctx_prefix; then frp=1; repairable=1; evidence+=("lctx_prefix_missing")
        elif ! rt_probe_leanctx_overlaps_disabled; then frp=1; repairable=1; evidence+=("overlap_surfaces_enabled")
        else
          set +e
          rt_probe_leanctx_vendor_doctor
          vd_rc=$?
          set -e
          case "$vd_rc" in
            1) frp=1; repairable=1; evidence+=("vendor_doctor_failed") ;;
            2) evidence+=("vendor_skip"); activation="full"; fr=1 ;;
            *) activation="full"; fr=1 ;;
          esac
        fi
        ;;
    esac
  fi
  canonical="$(rt_derive_canonical_state "$fu" "$fd" "$fp" "$fs" "$ff" "$frr" "$frp" "$fr")"
  rt_emit_probe_result "$tool_id" "$consent" "$canonical" "$activation" "$repairable" ${evidence[@]+"${evidence[@]}"}
}

rt_repair_leanctx() {
  local actions=() failures=() restart=0
  if ! rt_mutation_allowed leanctx; then
    echo '{"actions":[],"failures":["mutation_not_authorized"],"restart_required":false}'
    return 0
  fi
  local install="${RT_REPO_ROOT}/scripts/install-leanctx-sb.sh"
  if [[ -f "$install" ]]; then
    local -a install_args=(--host "${RT_HOST:-cursor}" --project-root "${RT_PROJECT_ROOT:-}")
    rt_cross_tool_batch_active && install_args+=(--skip-merge)
    bash "$install" "${install_args[@]}" >&2 \
      && actions+=("install_leanctx_sb") || failures+=("install_leanctx_failed")
    restart=1
  fi
  jq -n \
    --argjson actions "$(printf '%s\n' "${actions[@]:-}" | jq -R -s 'split("\n")|map(select(length>0))')" \
    --argjson failures "$(printf '%s\n' "${failures[@]:-}" | jq -R -s 'split("\n")|map(select(length>0))')" \
    --argjson restart "$([[ $restart -eq 1 ]] && echo true || echo false)" \
    '{actions:$actions,failures:$failures,restart_required:$restart}'
}
