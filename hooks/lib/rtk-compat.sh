# shellcheck shell=bash
# RTK hook coexistence — SILVER_BULLET marker + scoped RTK_DISABLED for harness scripts.
#
# RTK PreToolUse rewrites agent Shell/Bash input (e.g. git status → rtk git status).
# SB hook subprocesses are not Shell tool calls, but nested git/gh inside harness
# scripts should bypass RTK filters when RTK is on PATH.
#
# Policy (Option C):
#   • Agent Shell: full RTK when recommended_tools.rtk.enabled_by_user is true
#     (upstream PreToolUse rewrite; SB hooks see original command before RTK).
#   • SB hook bridge (cursor-hook-bridge.sh): no RTK_DISABLED when user opted in.
#   • Harness / install scripts: export SB_RTK_COMPAT_MODE=verbatim before source
#     to force RTK_DISABLED=1 for deterministic output parsing.
#   • When RTK not opted in (or config unknown): RTK_DISABLED=1 (safe default).
#
# Upstream bypass for agents: prefix commands with RTK_DISABLED=1 — rtk hook returns {}.
# SILVER_BULLET=1 is exported for documentation and future RTK aliases.

_compat_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

sb_rtk_user_opted_in() {
  local config_file=""
  if [[ -f "$_compat_lib_dir/sb-project-gate.sh" ]]; then
    # shellcheck source=sb-project-gate.sh
    source "$_compat_lib_dir/sb-project-gate.sh"
    config_file="$(sb_find_project_config 2>/dev/null || true)"
  fi
  [[ -n "$config_file" && -f "$config_file" ]] || return 1
  if [[ -f "$_compat_lib_dir/recommended-tools.sh" ]]; then
    # shellcheck source=recommended-tools.sh
    source "$_compat_lib_dir/recommended-tools.sh"
  fi
  declare -f sb_recommended_tool_enforced >/dev/null 2>&1 \
    && sb_recommended_tool_enforced "$config_file" "rtk"
}

sb_rtk_compat_enable() {
  export SILVER_BULLET=1
  if [[ "${SB_RTK_COMPAT_MODE:-}" == "verbatim" ]]; then
    export RTK_DISABLED=1
    return 0
  fi
  if sb_rtk_user_opted_in 2>/dev/null; then
    unset RTK_DISABLED 2>/dev/null || true
  else
    export RTK_DISABLED=1
  fi
}

# Harness scripts that parse exact git/gh output — call before source or set SB_RTK_COMPAT_MODE.
sb_rtk_compat_verbatim() {
  export SB_RTK_COMPAT_MODE=verbatim
  sb_rtk_compat_enable
}

# Idempotent: safe to source from hook bridge and script entry points.
if [[ "${SB_RTK_COMPAT_ENABLED:-}" != "1" ]]; then
  sb_rtk_compat_enable
  export SB_RTK_COMPAT_ENABLED=1
fi
