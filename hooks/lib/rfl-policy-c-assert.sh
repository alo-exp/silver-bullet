# shellcheck shell=bash
# Shared RFL Policy C / failure-management assert for PreToolUse, Stop, and CLI.

sb_rfl_policy_c_gate_disabled() {
  [[ "${SB_RFL_POLICY_C_GATE:-1}" == "0" ]]
}

sb_rfl_policy_c_resolver() {
  local root="${1:-}"
  if [[ -n "$root" && -f "$root/scripts/review-fix-ladder.py" ]]; then
    printf '%s' "$root/scripts/review-fix-ladder.py"
    return 0
  fi
  local hook_dir
  hook_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd 2>/dev/null)" || hook_dir=""
  if [[ -n "$hook_dir" && -f "$hook_dir/../scripts/review-fix-ladder.py" ]]; then
    printf '%s' "$hook_dir/../scripts/review-fix-ladder.py"
    return 0
  fi
  return 1
}

sb_rfl_policy_c_has_active_run() {
  local root="${1:-}"
  [[ -n "$root" && -d "$root/.planning" ]] || return 1
  local status
  for status in "$root"/.planning/rfl-*/LADDER-STATUS.json; do
    [[ -f "$status" ]] || continue
    if grep -q '"status"[[:space:]]*:[[:space:]]*"active"' "$status" 2>/dev/null; then
      return 0
    fi
  done
  return 1
}

sb_rfl_policy_c_infer_action() {
  local event="${1:-}" prompt="${2:-}"
  local blob
  blob="$(printf '%s %s' "$event" "$prompt" | tr '[:upper:]' '[:lower:]')"
  case "$blob" in
    *verify_2*|*verify-2*) printf 'verify_2' ;;
    *verify_1*|*verify-1*) printf 'verify_1' ;;
    *'next rung'*|*n+1_review*) printf 'next_rung_review' ;;
    *mark-ladder-status*|*mark_ladder_status*) printf 'mark_completed' ;;
    *)
      if [[ "${event}" == "Stop" || "${event}" == "stop" ]]; then
        printf 'stop'
      else
        printf 'task'
      fi
      ;;
  esac
}

sb_rfl_policy_c_run_assert() {
  local root="${1:-}" action="${2:-task}" prompt="${3:-}"
  local resolver json
  resolver="$(sb_rfl_policy_c_resolver "$root")" || return 0
  command -v python3 >/dev/null 2>&1 || return 0
  json="$(
    python3 "$resolver" \
      --assert-rfl-advance \
      --project-root "$root" \
      --next-action "$action" \
      --prompt "$prompt" \
      2>/dev/null || true
  )"
  if [[ -z "$json" ]]; then
    return 0
  fi
  if command -v jq >/dev/null 2>&1; then
    if [[ "$(printf '%s' "$json" | jq -r '.ok // false')" == "true" ]]; then
      return 0
    fi
    printf '%s' "$json"
    return 1
  fi
  if printf '%s' "$json" | grep -q '"ok"[[:space:]]*:[[:space:]]*true'; then
    return 0
  fi
  printf '%s' "$json"
  return 1
}

sb_rfl_policy_c_reason_from_json() {
  local json="${1:-}"
  if command -v jq >/dev/null 2>&1; then
    jq -r '
      "RFL Policy C / failure-management gate: " +
      ((.errors // []) | join("; "))
    ' <<<"$json" 2>/dev/null && return 0
  fi
  printf 'RFL Policy C / failure-management gate failed. Write POLICY-C via scripts/review-fix-ladder.py --write-policy-c before advancing.'
}
