#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# Silver Bullet legacy trivial-file guard.
#
# Agents must not arm the old touch-file bypass by writing to the trivial marker. Use /sb:fast
# for trivial changes instead. The marker is judged by what a call WRITES (the shell analysis
# resolves ~, $HOME, `cd dir && touch trivial`, mv/cp/ln/tee/dd targets), never by the text of
# the command, so every spelling of the path is covered. Interpreter one-liners (python -c,
# node -e) write to places the analysis cannot list: one that names the marker is refused too.

# Security: restrict file creation permissions (user-only)
umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"
# shellcheck source=lib/planning-floor.sh
source "$_lib_dir/planning-floor.sh"
if [[ -f "$_lib_dir/cert-bypass.sh" ]]; then
  # shellcheck source=lib/cert-bypass.sh
  source "$_lib_dir/cert-bypass.sh"
fi
if [[ -f "$_lib_dir/sb-project-gate.sh" ]]; then
  # shellcheck source=lib/sb-project-gate.sh
  source "$_lib_dir/sb-project-gate.sh"
fi

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
if declare -f sb_cert_run_bypass_active >/dev/null 2>&1 && sb_cert_run_bypass_active; then
  exit 0
fi
hook_event=$(printf '%s' "$input" | jq -r '.hook_event_name // "PreToolUse"' 2>/dev/null || echo "PreToolUse")
[[ "$hook_event" == "PreToolUse" ]] || exit 0

# The project is decided here; the record is verified only if a write lands in the state directory (below).
SB_IV_ROOT="$(sb_integrity_root "$PWD")"
[[ -n "$SB_IV_ROOT" ]] || exit 0
if declare -f sb_project_active >/dev/null 2>&1; then
  sb_project_active "$SB_IV_ROOT/.silver-bullet.json" || exit 0
fi

emit_block() {
  sb_emit_hook_decision PreToolUse deny "$1"
}

sb_tool_input_load "$input" "$PWD"
if ! sb_tool_input_ok; then
  [[ "${SB_TI_STATUS:-}" == "empty" ]] && exit 0
  # The shell command cannot be analysed: refuse only what names the marker.
  [[ "$(printf '%s' "$input" | tr '[:upper:]' '[:lower:]')" == *trivial* ]] || exit 0
  cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // .tool_input.cmd // ""' 2>/dev/null || true)"
  sb_pf_plain_read_only "$cmd" && exit 0
  emit_block "$(sb_pf_unanalysable_message)"
  exit 0
fi
if [[ "${SB_TI_TOOL_KIND:-}" == "shell" ]]; then
  unseen_why="$(sb_pf_unseen_reason)"
  if [[ -n "$unseen_why" ]]; then
    emit_block "$(sb_pf_unseen_message "$unseen_why")"
    exit 0
  fi
fi

# The default marker, and the one the project config names (it is not honoured by the gates,
# but writing it is still an attempt to arm the bypass). A configured path must sit in the state directory to
# stand for the marker at all, so the record is only read when a write lands there.
default_trivial="${SB_RUNTIME_STATE_DIR}/trivial"
state_canon="$(sb_pf_canon "$SB_RUNTIME_STATE_DIR")"
guarded="$(sb_pf_canon "$default_trivial")"
guarded_full=false

while IFS=$'\t' read -r via target; do
  # Removing the marker only disarms the bypass.
  case "$via" in rm | rmdir | unlink | "git rm") continue ;; esac
  if [[ "$guarded_full" != true && "$target" == "$state_canon"/* ]]; then
    guarded_full=true
    sb_integrity_gate "$PWD"
    cfg_trivial=""
    if cfg_trivial="$(sb_iv_jq -r '.state.trivial_file // ""' 2>/dev/null)"; then :; fi
    cfg_trivial="${cfg_trivial/#\~/$HOME}"
    if [[ -n "$cfg_trivial" ]]; then guarded="$guarded"$'\n'"$(sb_pf_canon "$cfg_trivial")"; fi
  fi
  if grep -qxF -- "$target" <<<"$guarded"; then
    emit_block "🚫 LEGACY TRIVIAL BYPASS BLOCKED — Agents must not write or arm the trivial marker file. Use /sb:fast for trivial work instead."
    exit 0
  fi
done < <(sb_pf_write_records "$input")

exit 0
