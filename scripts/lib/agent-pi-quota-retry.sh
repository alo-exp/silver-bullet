#!/usr/bin/env bash
# Pi/Omni Claude quota windows: classify and report. Nothing is scheduled: a delegate shares the
# caller's account, so a usage window stops the caller too. Weekly/monthly are HOLD. An EXIT 124
# hang is not quota. The classifier is the plugin's own scripts/review-fix-ladder.py (never a
# project copy) and its --classify-quota-window JSON contract.
# shellcheck shell=bash

agent_host_pi_quota_plugin_root() {
  if [[ -n "${_AGENT_HOST_EXEC_DIR:-}" && -d "${_AGENT_HOST_EXEC_DIR}/../.." ]]; then
    printf '%s' "$(cd "${_AGENT_HOST_EXEC_DIR}/../.." && pwd)"
    return 0
  fi
  if [[ -n "${_AGENT_DELEGATE_COMMON_DIR:-}" && -d "${_AGENT_DELEGATE_COMMON_DIR}/../.." ]]; then
    printf '%s' "$(cd "${_AGENT_DELEGATE_COMMON_DIR}/../.." && pwd)"
    return 0
  fi
  printf '%s' "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
}

agent_host_pi_quota_is_hang_only() {
  local rc="${1:-0}"
  local text="${2:-}"
  [[ "$rc" == "124" ]] || return 1
  grep -qiE 'zero-byte-idle kill|hard-timeout kill' <<<"$text" || return 0
  if grep -qiE '429|rate[_[:space:]-]*limit|rate_limit_error|5[-[:space:]]*h(ou)?r|quota[[:space:]]+(exhaust|exceed)' <<<"$text"; then
    return 1
  fi
  return 0
}

# Classify captured output and print one line to stderr; never schedules, never writes state.
# (Name kept for scripts/agent-pi/invoke.sh.)
agent_host_pi_maybe_schedule_quota_retry() {
  local rc="${1:-0}"
  local text="${2:-}"
  local host="${3:-}"
  local model="${4:-}"
  local resolver blob classified quota_class should_schedule reset

  agent_host_pi_quota_is_hang_only "$rc" "$text" && return 0
  [[ -n "$text" ]] || return 0

  resolver="$(agent_host_pi_quota_plugin_root)/scripts/review-fix-ladder.py"
  [[ -f "$resolver" ]] || return 0

  host="${host:-${SB_RFL_QUOTA_HOST:-${PI_PROVIDER:-}}}"
  model="${model:-${SB_RFL_MODEL:-${PI_MODEL:-}}}"

  blob="$(mktemp "${TMPDIR:-/tmp}/agent-pi-quota-XXXXXX")"
  printf '%s' "$text" >"$blob"
  classified="$(python3 -I "$resolver" --classify-quota-window \
    --quota-host "$host" --model "$model" \
    --subscription-output-file "$blob" 2>/dev/null)" || {
    rm -f "$blob"
    return 0
  }
  rm -f "$blob"

  quota_class="$(jq -r '.quota_class // empty' <<<"$classified" 2>/dev/null || true)"
  should_schedule="$(jq -r '.should_schedule // false' <<<"$classified" 2>/dev/null || true)"
  reset="$(jq -r '.reset_seconds // empty' <<<"$classified" 2>/dev/null || true)"

  if [[ "$should_schedule" == "true" ]]; then
    printf '[agent-pi] quota %s; window resets in %ss; no retry is scheduled, re-run after it\n' \
      "$([[ "$quota_class" == "five_hour" ]] && echo 5h || echo "$quota_class")" "${reset:-18000}" >&2
  elif [[ "$quota_class" == "weekly" || "$quota_class" == "monthly" ]]; then
    printf '[agent-pi] quota %s; HOLD (no 5h retry)\n' "$quota_class" >&2
  fi
  return 0
}
