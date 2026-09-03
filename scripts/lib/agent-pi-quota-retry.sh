#!/usr/bin/env bash
# Pi/Omni Claude 5-hour quota: classify + schedule a retry on quota EXIT.
# Weekly/monthly HOLD — do not arm a 5h job. EXIT 124 hang is not quota.
# shellcheck shell=bash

agent_host_pi_quota_repo_root() {
  if [[ -n "${SB_RFL_PROJECT_ROOT:-}" && -d "${SB_RFL_PROJECT_ROOT}" ]]; then
    printf '%s' "$(cd "${SB_RFL_PROJECT_ROOT}" && pwd)"
    return 0
  fi
  if [[ -n "${_AGENT_HOST_EXEC_DIR:-}" && -d "${_AGENT_HOST_EXEC_DIR}/../.." ]]; then
    printf '%s' "$(cd "${_AGENT_HOST_EXEC_DIR}/../.." && pwd)"
    return 0
  fi
  if [[ -n "${_AGENT_DELEGATE_COMMON_DIR:-}" && -d "${_AGENT_DELEGATE_COMMON_DIR}/../.." ]]; then
    printf '%s' "$(cd "${_AGENT_DELEGATE_COMMON_DIR}/../.." && pwd)"
    return 0
  fi
  pwd
}

agent_host_pi_resolve_quota_run_dir() {
  local work_dir="${1:-${WORK_DIR:-${PI_WORK_DIR:-}}}"
  local abs parent repo
  if [[ -n "${SB_RFL_RUN_DIR:-}" ]]; then
    mkdir -p "${SB_RFL_RUN_DIR}"
    printf '%s' "$(cd "${SB_RFL_RUN_DIR}" && pwd)"
    return 0
  fi
  if [[ -n "$work_dir" && -d "$work_dir" ]]; then
    abs="$(cd "$work_dir" && pwd)"
    if [[ "$(basename "$abs")" == rung-* ]]; then
      parent="$(dirname "$abs")"
      if [[ "$(basename "$parent")" == rfl-* ]]; then
        printf '%s' "$parent"
        return 0
      fi
    fi
    if [[ "$(basename "$abs")" == rfl-* ]]; then
      printf '%s' "$abs"
      return 0
    fi
  fi
  repo="$(agent_host_pi_quota_repo_root)"
  mkdir -p "${repo}/.planning/agent-pi/quota-retry"
  printf '%s' "${repo}/.planning/agent-pi/quota-retry"
}

agent_host_pi_resolve_quota_rung() {
  local work_dir="${1:-${WORK_DIR:-${PI_WORK_DIR:-}}}"
  local base
  if [[ -n "${SB_RFL_RUNG_ID:-}" ]]; then
    printf '%s' "${SB_RFL_RUNG_ID}"
    return 0
  fi
  base="$(basename "${work_dir:-}")"
  if [[ "$base" =~ ^rung-([0-9]+) ]]; then
    printf 'rung-%s' "${BASH_REMATCH[1]}"
    return 0
  fi
  printf '%s' "agent-pi"
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

# Skip --continue on quota windows (and keep 124 hang ≠ success).
agent_host_pi_should_continue() {
  local rc="$1"
  local text="$2"
  [[ "$rc" == "0" ]] || return 1
  [[ "$rc" == "124" ]] && return 1
  if declare -F agent_host_pi_is_auth_failure >/dev/null 2>&1; then
    if agent_host_pi_is_auth_failure "$text"; then
      return 1
    fi
  fi
  if grep -qiE '429|rate[_[:space:]-]*limit|rate_limit_error|5[-[:space:]]*h(ou)?r|quota[[:space:]]+(exhaust|exceed)|usage[[:space:]]+limit' <<<"$text"; then
    return 1
  fi
  return 0
}

agent_host_pi_maybe_schedule_quota_retry() {
  local rc="${1:-0}"
  local text="${2:-}"
  local host="${3:-}"
  local model="${4:-}"
  local repo resolver run_dir run_id rung_id blob classified quota_class should_schedule json wake_iso

  agent_host_pi_quota_is_hang_only "$rc" "$text" && return 0
  [[ -n "$text" ]] || return 0

  repo="$(agent_host_pi_quota_repo_root)"
  resolver="${repo}/scripts/review-fix-ladder.py"
  [[ -f "$resolver" ]] || return 0

  host="${host:-${SB_RFL_QUOTA_HOST:-${PI_PROVIDER:-}}}"
  model="${model:-${SB_RFL_MODEL:-${PI_MODEL:-}}}"

  blob="$(mktemp "${TMPDIR:-/tmp}/agent-pi-quota-XXXXXX")"
  printf '%s' "$text" >"$blob"

  classified="$(python3 "$resolver" --classify-quota-window \
    --quota-host "$host" --model "$model" \
    --subscription-output-file "$blob" 2>/dev/null)" || {
    rm -f "$blob"
    return 0
  }

  quota_class="$(jq -r '.quota_class // empty' <<<"$classified" 2>/dev/null || true)"
  should_schedule="$(jq -r '.should_schedule // false' <<<"$classified" 2>/dev/null || true)"

  if [[ "$should_schedule" != "true" ]]; then
    rm -f "$blob"
    if [[ "$quota_class" == "weekly" || "$quota_class" == "monthly" ]]; then
      printf '[agent-pi] quota %s; HOLD (no 5h retry)\n' "$quota_class" >&2
    fi
    return 0
  fi

  run_dir="$(agent_host_pi_resolve_quota_run_dir)" || {
    rm -f "$blob"
    return 0
  }
  run_id="${SB_RFL_RUN_ID:-$(basename "$run_dir")}"
  rung_id="$(agent_host_pi_resolve_quota_rung)"
  [[ -n "$model" ]] || model="claude/unknown"

  json="$(python3 "$resolver" --schedule-quota-retry \
    --run-dir "$run_dir" --run-id "$run_id" --rung-id "$rung_id" \
    --model "$model" --quota-host "$host" \
    --subscription-output-file "$blob" 2>/dev/null)" || {
    rm -f "$blob"
    return 0
  }
  rm -f "$blob"

  wake_iso="$(jq -r '.job.wake_at // .job.fire_at // .wake_at // empty' <<<"$json" 2>/dev/null || true)"
  if [[ -n "$wake_iso" && "$quota_class" == "five_hour" ]]; then
    printf '[agent-pi] quota 5h; retry at %s\n' "$wake_iso" >&2
  elif [[ -n "$wake_iso" ]]; then
    printf '[agent-pi] quota %s; retry at %s\n' "$quota_class" "$wake_iso" >&2
  fi
  return 0
}
