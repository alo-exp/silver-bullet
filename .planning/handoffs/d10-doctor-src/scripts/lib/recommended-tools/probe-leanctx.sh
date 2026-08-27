# shellcheck shell=bash
# LeanCTX probe and repair.

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
# shellcheck source=vendor-doctor.sh
source "$(dirname "${BASH_SOURCE[0]}")/vendor-doctor.sh"

rt_leanctx_mcp_file() {
  printf '%s' "${HOME}/.cursor/mcp.json"
}

# Duplicate leanctx + lean-ctx keys are a config FAIL when LeanCTX is opted in.
rt_probe_leanctx_duplicate_mcp() {
  local f
  f="$(rt_leanctx_mcp_file)"
  [[ -f "$f" ]] || return 1
  jq -e '.mcpServers | has("leanctx") and has("lean-ctx")' "$f" >/dev/null 2>&1
}

rt_probe_leanctx_mcp() {
  local host="${RT_HOST:-cursor}" f
  case "$host" in
    cursor)
      f="$(rt_leanctx_mcp_file)"
      [[ -f "$f" ]] || return 1
      jq -e '.mcpServers.leanctx
        // .mcpServers["lean-ctx"]
        // .mcpServers["user-leanctx"]
        // .mcpServers["user-lean-ctx"]' "$f" >/dev/null 2>&1
      ;;
    *) return 1 ;;
  esac
}

rt_leanctx_mcp_env() {
  local f key="${1:-}"
  f="$(rt_leanctx_mcp_file)"
  [[ -f "$f" && -n "$key" ]] || return 1
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
  command -v "$bin" >/dev/null 2>&1 || return 2
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
          ff=1; frp=1; repairable=1; evidence+=("duplicate_mcp_keys")
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
