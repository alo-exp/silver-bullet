# shellcheck shell=bash
# RTK probe and repair.

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
# shellcheck source=vendor-doctor.sh
source "$(dirname "${BASH_SOURCE[0]}")/vendor-doctor.sh"

rt_probe_rtk_shell_owner() {
  local host="${RT_HOST:-cursor}"
  case "$host" in
    cursor)
      [[ -f "${HOME}/.cursor/hooks.json" ]] || return 1
      grep -q 'rtk hook cursor' "${HOME}/.cursor/hooks.json" 2>/dev/null
      ;;
    claude)
      [[ -f "${HOME}/.claude/settings.json" ]] || return 1
      grep -qE 'rtk hook claude|rtk' "${HOME}/.claude/settings.json" 2>/dev/null
      ;;
    codex)
      local codex_home="${HOME}/.codex"
      declare -f sb_runtime_codex_home >/dev/null 2>&1 && codex_home="$(sb_runtime_codex_home)"
      [[ -f "${codex_home}/AGENTS.md" ]] || return 1
      grep -qiE 'rtk|rust token killer' "${codex_home}/AGENTS.md" 2>/dev/null
      ;;
    opencode|pi)
      sb_rtk_platform_hook_present "${RT_PROJECT_ROOT:-}" "$host"
      ;;
    *) return 1 ;;
  esac
}

rt_probe_rtk_leanctx_rewrite_absent() {
  case "${RT_HOST:-cursor}" in
    cursor)
      [[ -f "${HOME}/.cursor/hooks.json" ]] || return 0
      ! grep -q 'lean-ctx hook rewrite' "${HOME}/.cursor/hooks.json" 2>/dev/null
      ;;
    opencode|pi)
      local artifact
      artifact="$(sb_rtk_platform_hook_artifact_path "${RT_PROJECT_ROOT:-}" "${RT_HOST:-}")"
      [[ -f "$artifact" ]] || return 0
      ! grep -qiE 'lean-ctx[^[:space:]]*[[:space:]]+rewrite|leanctx[^[:space:]]*[[:space:]]+rewrite' "$artifact" 2>/dev/null
      ;;
    *) return 0 ;;
  esac
}

rt_probe_rtk_before_cm() {
  if [[ "${RT_HOST:-cursor}" == "opencode" ]]; then
    sb_rtk_platform_hook_present "${RT_PROJECT_ROOT:-}" opencode
    return $?
  fi
  if [[ "${RT_HOST:-cursor}" == "pi" ]]; then
    local pi_cfg="${PI_CODING_AGENT_DIR:-${HOME}/.pi/agent}/extensions/pi-lean-ctx/config.json"
    [[ -f "$pi_cfg" ]] || return 1
    [[ "$(jq -r '.routeShell // true' "$pi_cfg" 2>/dev/null)" == "false" ]] || return 1
    jq -e '.disableTools | index("ctx_shell") != null' "$pi_cfg" >/dev/null 2>&1
    return $?
  fi
  [[ "${RT_HOST:-cursor}" == "cursor" ]] || return 0
  python3 - "${HOME}/.cursor/hooks.json" <<'PY'
import json, sys
from pathlib import Path
p = Path(sys.argv[1])
if not p.is_file():
    sys.exit(1)
data = json.loads(p.read_text())
pt = data.get("hooks", {}).get("preToolUse", [])
rtk = cm = None
for i, h in enumerate(pt):
    cmd = h.get("command", "")
    if cmd.endswith("rtk hook cursor"):
        rtk = i
    if "context-mode hook cursor pretooluse" in cmd:
        cm = i
if rtk is None or cm is None:
    sys.exit(0 if rtk is not None else 1)
sys.exit(0 if rtk < cm else 1)
PY
}

# Vendor `rtk doctor` when the subcommand exists and is non-interactive.
# 0=pass 1=fail 2=skip (no subcommand / interactive-only / RT_SKIP_VENDOR_DOCTOR)
rt_probe_rtk_vendor_doctor() {
  [[ "${RT_SKIP_VENDOR_DOCTOR:-0}" == "1" ]] && return 2
  local -a cmd extra=()
  if [[ -n "${RT_RTK_DOCTOR_CMD:-}" ]]; then
    # shellcheck disable=SC2206
    cmd=(${RT_RTK_DOCTOR_CMD})
    rt_run_vendor_doctor "${cmd[@]}"
    return $?
  fi
  local rtk_bin
  rtk_bin="$(sb_rtk_cli_path 2>/dev/null || true)"
  [[ -n "$rtk_bin" ]] || return 2
  # RTK does not expose a vendor `doctor` command in every release.  Check
  # the command index before asking the generic vendor wrapper to probe it;
  # otherwise a valid RTK installation is reported as repairable merely
  # because `rtk doctor --help` is interpreted as a proxy command.
  local help=""
  help="$("$rtk_bin" help </dev/null 2>&1 || true)"
  printf '%s\n' "$help" | grep -qE '^[[:space:]]+doctor([[:space:]]|$)' || return 2
  rt_vendor_doctor_subcommand_usable "$rtk_bin" || return 2
  if "$rtk_bin" doctor --help </dev/null 2>&1 | grep -qiE -- '--non-interactive'; then
    extra+=(--non-interactive)
  elif "$rtk_bin" doctor --help </dev/null 2>&1 | grep -qiE -- '--yes'; then
    extra+=(--yes)
  fi
  # Bash 3.2 + set -u: empty extra[@] is unbound and aborts the reconciler.
  if ((${#extra[@]})); then
    rt_run_vendor_doctor "$rtk_bin" doctor "${extra[@]}"
  else
    rt_run_vendor_doctor "$rtk_bin" doctor
  fi
}

rt_probe_rtk() {
  local tool_id="rtk" consent activation="none" canonical repairable=0
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
        elif ! sb_rtk_cli_available 2>/dev/null; then ff=1; evidence+=("cli_missing"); frp=1; repairable=1
        elif ! sb_rtk_version_ok "$cfg" 2>/dev/null; then frp=1; repairable=1; evidence+=("version_mismatch"); evidence+=("min_version")
        elif ! rt_probe_rtk_shell_owner; then frp=1; repairable=1; evidence+=("shell_hook_missing")
        elif ! rt_probe_rtk_leanctx_rewrite_absent; then frp=1; repairable=1; evidence+=("leanctx_rewrite_present")
        elif ! rt_probe_rtk_before_cm; then frp=1; repairable=1; evidence+=("hook_order_wrong")
        else
          set +e
          rt_probe_rtk_vendor_doctor
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

rt_repair_rtk() {
  local actions=() failures=()
  if ! rt_mutation_allowed rtk; then
    echo '{"actions":[],"failures":["mutation_not_authorized"],"restart_required":false}'
    return 0
  fi
  local opt="${RT_REPO_ROOT}/scripts/optimize-rtk-context-mode.sh"
  if [[ -f "$opt" ]]; then
    local -a opt_args=(--host "${RT_HOST:-cursor}" --project-root "${RT_PROJECT_ROOT:-}" --skip-cm-doctor)
    rt_cross_tool_batch_active && opt_args+=(--skip-rtk-init)
    bash "$opt" "${opt_args[@]}" >&2 \
      && actions+=("optimize_rtk_context_mode") || failures+=("optimize_rtk_failed")
  fi
  if [[ "${RT_HOST:-cursor}" == "cursor" ]] && ! rt_cross_tool_batch_active; then
    local patch_py="${RT_REPO_ROOT}/scripts/lib/global-toolstack/patch-hooks.py"
    if [[ -f "$patch_py" ]]; then
      RT_PATCH_RTK=1 RT_PATCH_GRAPHIFY=0 RT_PATCH_AGENTMEMORY=0 RT_PATCH_CONTEXT_MODE=0 RT_PATCH_LEANCTX=0 \
        python3 "$patch_py" >/dev/null 2>&1 \
        && actions+=("patch_hooks") || failures+=("patch_hooks_failed")
    fi
  fi
  jq -n \
    --argjson actions "$(printf '%s\n' "${actions[@]:-}" | jq -R -s 'split("\n")|map(select(length>0))')" \
    --argjson failures "$(printf '%s\n' "${failures[@]:-}" | jq -R -s 'split("\n")|map(select(length>0))')" \
    '{actions:$actions,failures:$failures,restart_required:false}'
}
