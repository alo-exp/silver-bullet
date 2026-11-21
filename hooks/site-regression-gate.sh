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
# shellcheck disable=SC2034  # read by sb_orchestrator_is_worker_session (subagent identity)
SB_ORCH_HOOK_INPUT="$input"
[[ -n "$input" ]] || exit 0
hook_event="$(printf '%s' "$input" | jq -r '.hook_event_name // "Stop"' 2>/dev/null || echo Stop)"

# The project: the nearest root with a record, else the nearest directory with both contract files.
config_file="$( (source "$(dirname "${BASH_SOURCE[0]}")/lib/integrity-anchor.sh" && sb_integrity_activation_config "$PWD") 2>/dev/null; true)"
search_dir="${config_file:+${config_file%/*}}"
search_dir="${search_dir:-$PWD}"
[[ -n "$config_file" ]] || exit 0
sb_project_gate_or_exit 2>/dev/null || exit 0
sb_site_profile_load || exit 0

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
    # A Stop gate that already told the agent once must not trap the session (R9-03).
    if sb_site_stop_loop_release site-regression-gate "$input"; then exit 0; fi
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
  # Any real push (not a command that merely mentions one) runs the suites first when site edits exist.
  sb_tool_input_load "$input"
  sb_site_shell_push_kind >/dev/null || exit 0
  sb_site_session_gates_apply && should_check=true
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
  reason="Site session regression gate — cannot run: a regression script named in site_profile.regression_scripts is missing under ${repo_root}.
This is a gate setup problem, not a test failure. Fix site_profile in .silver-bullet.json or restore the script."
elif [[ $rc -eq 92 ]]; then
  reason="Site session regression gate — not trusted: $(sb_site_regression_untrusted "$repo_root") is not committed as it stands (untracked, or changed against HEAD).
The gate does not run a regression script that was edited in the working tree: a pass could be forged by replacing it. Review the change and commit it, then retry."
elif [[ $rc -eq 91 ]]; then
  reason="Site session regression gate — cannot run: failed to create a log file under ${SB_RUNTIME_STATE_DIR:-/tmp}.
This is a gate setup problem, not a test failure. Check that the directory exists and is writable, and remove any stale 'site-regression.XXXXXX.log' literal file left by older SB versions."
elif [[ -z "$log_file" || ! -f "$log_file" ]]; then
  # Empty/missing log with a non-setup rc means we could not capture a run —
  # do not tell the operator the suites "failed" when we have no evidence they ran.
  reason="Site session regression gate — cannot run: regression helper returned rc=${rc} without a usable log file.
This is a gate setup problem, not a test failure. No log file was produced."
else
  scripts_list="$(printf '%s' "$SB_SITE_REGRESSION_SCRIPTS" | sed 's/^/  bash /')"
  reason="Site session regression gate — suites ran and failed. Re-run the site regression suites before push/Stop.

Required (all must pass):
${scripts_list}

Fix failures then retry. Log: ${log_file}"
fi
emit_block "$reason"
