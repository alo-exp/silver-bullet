# shellcheck shell=bash
# RTK hook coexistence — keep SB-invoked shell verbatim.
#
# RTK PreToolUse rewrites agent Shell/Bash input (e.g. git status → rtk git status).
# SB hook subprocesses and harness scripts are not rewritten, but nested git/gh
# inside those scripts should still bypass RTK filters when RTK is on PATH.
#
# Upstream bypass: prefix commands with RTK_DISABLED=1 (rtk rewrite exits 1).
# SILVER_BULLET=1 is exported alongside for documentation and future RTK aliases.

sb_rtk_compat_enable() {
  export SILVER_BULLET=1
  export RTK_DISABLED=1
}

# Idempotent: safe to source from hook bridge and script entry points.
if [[ "${SB_RTK_COMPAT_ENABLED:-}" != "1" ]]; then
  sb_rtk_compat_enable
  export SB_RTK_COMPAT_ENABLED=1
fi
