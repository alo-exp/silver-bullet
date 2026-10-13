#!/usr/bin/env bash
# Stop hook coalesce — first blocking gate wins; suppress duplicate Stop churn (E2E-014).
#
# Usage (Stop hooks only):
#   sb_stop_coalesce_reset          # call at start of first Stop hook (stop-check.sh)
#   sb_stop_coalesce_record "$reason"  # before emitting decision:block
#   sb_stop_coalesce_suppress_secondary_block && exit 0  # in downstream Stop hooks

sb_stop_coalesce_file() {
  printf '%s/stop-coalesce-block' "${SB_RUNTIME_STATE_DIR:-/tmp}"
}

sb_stop_coalesce_reset() {
  local f
  f="$(sb_stop_coalesce_file)"
  rm -f -- "$f" 2>/dev/null || true
}

sb_stop_coalesce_record() {
  local reason="${1:-}"
  local f
  f="$(sb_stop_coalesce_file)"
  [[ -f "$f" ]] && return 0
  [[ -z "$reason" ]] && return 0
  umask 0077
  printf '%s' "$reason" >"$f"
}

sb_stop_coalesce_suppress_secondary_block() {
  [[ -f "$(sb_stop_coalesce_file)" ]]
}
