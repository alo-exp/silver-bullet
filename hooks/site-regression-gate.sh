#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# Stop + PreToolUse (git push) — site regression tests when site/** touched.
umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
[[ -f "$_lib_dir/runtime-paths.sh" ]] && source "$_lib_dir/runtime-paths.sh"
[[ -f "$_lib_dir/site-session.sh" ]] && source "$_lib_dir/site-session.sh"
[[ -f "$_lib_dir/tool-input.sh" ]] && source "$_lib_dir/tool-input.sh"
[[ -f "$_lib_dir/trivial-bypass.sh" ]] && source "$_lib_dir/trivial-bypass.sh"
[[ -f "$_lib_dir/sb-project-gate.sh" ]] && source "$_lib_dir/sb-project-gate.sh"

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat 2>/dev/null || true)"
[[ -n "$input" ]] || exit 0
hook_event="$(printf '%s' "$input" | jq -r '.hook_event_name // "Stop"' 2>/dev/null || echo Stop)"

config_file=""
search_dir="$PWD"
while true; do
  if [[ -f "$search_dir/.silver-bullet.json" && -f "$search_dir/silver-bullet.md" ]]; then
    config_file="$search_dir/.silver-bullet.json"
    break
  fi
  if [[ -d "$search_dir/.git" ]] || [[ "$search_dir" == "/" ]]; then
    break
  fi
  search_dir="$(dirname "$search_dir")"
done
[[ -n "$config_file" ]] || exit 0
sb_project_gate_or_exit 2>/dev/null || exit 0

if [[ -f "$_lib_dir/e2e-matrix-routing.sh" ]]; then
  # shellcheck source=lib/e2e-matrix-routing.sh
  source "$_lib_dir/e2e-matrix-routing.sh"
  if [[ "$hook_event" == "Stop" || "$hook_event" == "SubagentStop" ]] \
    && sb_e2e_matrix_routing_row_active 2>/dev/null; then
    exit 0
  fi
fi

repo_root="$(dirname "$config_file")"
SB_STATE_DIR="${SB_RUNTIME_STATE_DIR}"
mkdir -p "$SB_STATE_DIR" 2>/dev/null || true
trivial_file="${SB_STATE_DIR}/trivial"

emit_block() {
  local reason="$1"
  local json_reason
  json_reason=$(printf '%s' "$reason" | jq -Rs '.')
  if [[ "$hook_event" == "PreToolUse" ]]; then
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$json_reason"
    [[ "${SB_KAY_HOOK_BRIDGE_INVOKED:-}" == "1" ]] && { printf '%s\n' "$reason" >&2; exit 2; }
  else
    printf '{"decision":"block","reason":%s}' "$json_reason"
  fi
  exit 0
}

should_check=false
if [[ "$hook_event" == "Stop" || "$hook_event" == "SubagentStop" ]]; then
  if [[ "$hook_event" == "SubagentStop" && -f "$_lib_dir/orchestrator-parent.sh" ]]; then
    source "$_lib_dir/orchestrator-parent.sh"
    sb_orchestrator_is_worker_session 2>/dev/null && exit 0
  fi
  sb_site_session_gates_apply && should_check=true
elif [[ "$hook_event" == "PreToolUse" ]]; then
  tool_name="$(sb_tool_name "$input" 2>/dev/null || true)"
  case "$tool_name" in
    Bash|Shell|shell|exec_command) ;;
    *) exit 0 ;;
  esac
  cmd="$(sb_tool_command_string "$input" 2>/dev/null || true)"
  if printf '%s' "$cmd" | grep -qE '\bgit push\b'; then
    sb_site_session_mark_push_intent 2>/dev/null || true
    sb_site_session_gates_apply && should_check=true
  else
    exit 0
  fi
else
  exit 0
fi

[[ "$should_check" == true ]] || exit 0
if declare -f sb_trivial_bypass >/dev/null 2>&1; then
  sb_trivial_bypass "$trivial_file"
fi

if sb_site_session_regression_current; then
  exit 0
fi

log_file=""
rc=0
# NOTE: this script runs under `set -e` with `trap 'exit 0' ERR`. A bare
# `log_file="$(...)"` on its own line would trip errexit on a non-zero return,
# fire the ERR trap, and exit 0 — silently failing the gate OPEN. The `|| rc=$?`
# form keeps the assignment in a condition context so the status is captured.
log_file="$(sb_site_session_run_regression_tests "$repo_root" 2>/dev/null)" || rc=$?
if [[ $rc -eq 0 ]]; then
  exit 0
fi

if [[ $rc -eq 90 ]]; then
  reason="Site session regression gate — cannot run: no tests directory at ${repo_root}/tests.
This is a gate setup problem, not a test failure."
elif [[ $rc -eq 91 ]]; then
  reason="Site session regression gate — cannot run: failed to create a log file under ${SB_RUNTIME_STATE_DIR:-/tmp}.
This is a gate setup problem, not a test failure. Check that the directory exists and is writable, and remove any stale 'site-regression.XXXXXX.log' literal file left by older SB versions."
elif [[ -z "$log_file" || ! -f "$log_file" ]]; then
  # Empty/missing log with a non-setup rc means we could not capture a run —
  # do not tell the operator the suites "failed" when we have no evidence they ran.
  reason="Site session regression gate — cannot run: regression helper returned rc=${rc} without a usable log file.
This is a gate setup problem, not a test failure. No log file was produced."
else
  reason="Site session regression gate — suites ran and failed. Re-run site freshness + chrome regression before push/Stop.

Required (all must pass):
  bash tests/scripts/test-site-chrome-regression.sh
  bash tests/scripts/test-site-doc-freshness.sh
  bash tests/scripts/test-site-content-freshness.sh

Fix failures then retry. Log: ${log_file}"
fi
emit_block "$reason"


