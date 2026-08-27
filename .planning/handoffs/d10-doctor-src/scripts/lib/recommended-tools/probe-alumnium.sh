# shellcheck shell=bash
# Alumnium probe — CLI/npm reachability + Cursor MCP wiring (docs/ALUMNIUM.md).
# Opt-in only: pending/disabled consent is N/A (canonical pending/disabled).
# Do not invent provider env-key checks; enable-alumnium.sh does not require them.

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
# shellcheck source=vendor-doctor.sh
source "$(dirname "${BASH_SOURCE[0]}")/vendor-doctor.sh"

rt_probe_alumnium_cli() {
  command -v alumnium >/dev/null 2>&1
}

# Cursor MCP: mcpServers.alumnium or user-alumnium in ~/.cursor/mcp.json
# (same artifact the rest of D10 probes and docs/ALUMNIUM.md use).
rt_probe_alumnium_mcp() {
  local host="${RT_HOST:-cursor}"
  case "$host" in
    cursor)
      [[ -f "${HOME}/.cursor/mcp.json" ]] || return 1
      jq -e '.mcpServers.alumnium // .mcpServers["user-alumnium"]' \
        "${HOME}/.cursor/mcp.json" >/dev/null 2>&1
      ;;
    *) return 1 ;;
  esac
}

# Vendor `alumnium doctor` when the subcommand exists and is non-interactive.
# 0=pass 1=fail 2=skip (no subcommand / interactive-only / RT_SKIP_VENDOR_DOCTOR)
rt_probe_alumnium_vendor_doctor() {
  [[ "${RT_SKIP_VENDOR_DOCTOR:-0}" == "1" ]] && return 2
  local -a cmd extra=()
  if [[ -n "${RT_ALUMNIUM_DOCTOR_CMD:-}" ]]; then
    # shellcheck disable=SC2206
    cmd=(${RT_ALUMNIUM_DOCTOR_CMD})
    rt_run_vendor_doctor "${cmd[@]}"
    return $?
  fi
  command -v alumnium >/dev/null 2>&1 || return 2
  rt_vendor_doctor_subcommand_usable alumnium || return 2
  if alumnium doctor --help </dev/null 2>&1 | grep -qiE -- '--non-interactive'; then
    extra+=(--non-interactive)
  elif alumnium doctor --help </dev/null 2>&1 | grep -qiE -- '--yes'; then
    extra+=(--yes)
  fi
  # Bash 3.2 + set -u: empty extra[@] is unbound and aborts the reconciler.
  if ((${#extra[@]})); then
    rt_run_vendor_doctor alumnium doctor "${extra[@]}"
  else
    rt_run_vendor_doctor alumnium doctor
  fi
}

rt_probe_alumnium() {
  local tool_id="alumnium" consent activation="none" canonical repairable=0
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
        elif ! rt_probe_alumnium_cli; then ff=1; evidence+=("cli_missing"); frp=1; repairable=1
        elif ! rt_probe_alumnium_mcp; then frp=1; repairable=1; activation="partial"; evidence+=("mcp_not_configured")
        else
          set +e
          rt_probe_alumnium_vendor_doctor
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

rt_repair_alumnium() {
  # MCP merge needs a provider key; doctor must not invent or write secrets.
  echo '{"actions":[],"failures":["mutation_not_authorized"],"restart_required":false}'
}
