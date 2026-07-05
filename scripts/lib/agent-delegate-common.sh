#!/usr/bin/env bash
# Shared delegate wrapper behavior for agent-codex-delegate.sh and agent-cursor-delegate.sh.
# shellcheck shell=bash

# Canonicalize a repo-relative path to absolute.
agent_delegate_canonicalize_path() {
  local path="$1"
  [[ -n "$path" ]] || return 0
  if [[ "$path" != /* ]]; then
    path="$(cd "$(dirname "$path")" && pwd)/$(basename "$path")"
  fi
  printf '%s' "$path"
}

# Production delegation must not inherit matrix certification env.
agent_delegate_clear_matrix_env() {
  unset SB_E2E_ENTERPRISE_MATRIX SB_E2E_LEDGER_FILE SB_E2E_MATRIX_BATCH_PID \
    SB_E2E_MATRIX_FORCE SB_E2E_MATRIX_MONITOR_PID_FILE \
    SB_E2E_MATRIX_MONITOR_STATUS_FILE SB_E2E_TUI_FINDINGS SB_E2E_TUI_OFFSETS \
    SB_E2E_LIVE_TEST_LOCK_FILE 2>/dev/null || true
}

agent_delegate_is_quota_error() {
  local blob="$1"
  grep -qiE '429|rate[[:space:]]*limit|token[[:space:]]*plan|quota' <<<"$blob"
}

# Redact secrets from log/progress surfaces (sk-*, ghp_*, key=value patterns).
agent_delegate_redact_output() {
  local blob="$1"
  printf '%s' "$blob" | sed -E \
    -e 's/(api[_-]?key|token|password|secret|authorization|bearer)[[:space:]]*[:=][[:space:]]*[^[:space:]]+/\1=[REDACTED]/gi' \
    -e 's/sk-[A-Za-z0-9_-]{8,}/sk-[REDACTED]/g' \
    -e 's/ghp_[A-Za-z0-9]{20,}/ghp_[REDACTED]/g'
}

agent_delegate_redact_log_file() {
  local path="$1"
  [[ -f "$path" ]] || return 0
  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/agent-delegate-log-XXXXXX")"
  agent_delegate_redact_output "$(cat "$path")" >"$tmp"
  mv "$tmp" "$path"
}

agent_delegate_brief_has_secrets() {
  local text="$1"
  grep -qE '(api[_-]?key|token|password|secret|authorization|bearer)[[:space:]]*[:=]' <<<"$text" && return 0
  grep -qE 'sk-[A-Za-z0-9_-]{8,}' <<<"$text" && return 0
  grep -qE 'ghp_[A-Za-z0-9]{20,}' <<<"$text" && return 0
  return 1
}

# Resolve PROMPT_TEXT from --prompt, --prompt-file, or --brief-file (caller sets vars).
agent_delegate_resolve_prompt() {
  local brief_file="$1" prompt_file="$2" prompt_text="$3"
  local resolved=""

  if [[ -n "$brief_file" ]]; then
    [[ -f "$brief_file" ]] || { printf 'ERROR: brief file not found: %s\n' "$brief_file" >&2; return 2; }
    brief_file="$(agent_delegate_canonicalize_path "$brief_file")"
    resolved="$(cat "$brief_file")"
    if agent_delegate_brief_has_secrets "$resolved"; then
      printf 'ERROR: brief contains secret patterns — remove credentials before launch\n' >&2
      return 2
    fi
  elif [[ -n "$prompt_file" ]]; then
    [[ -f "$prompt_file" ]] || { printf 'ERROR: prompt file not found: %s\n' "$prompt_file" >&2; return 2; }
    prompt_file="$(agent_delegate_canonicalize_path "$prompt_file")"
    resolved="$(cat "$prompt_file")"
    if agent_delegate_brief_has_secrets "$resolved"; then
      printf 'ERROR: prompt file contains secret patterns — remove credentials before launch\n' >&2
      return 2
    fi
  else
    resolved="$prompt_text"
    if agent_delegate_brief_has_secrets "$resolved"; then
      printf 'ERROR: prompt contains secret patterns — remove credentials before launch\n' >&2
      return 2
    fi
  fi

  [[ -n "$resolved" ]] || {
    printf 'ERROR: provide --prompt, --prompt-file, or --brief-file\n' >&2
    return 2
  }
  printf '%s' "$resolved"
}

agent_delegate_validate_work_dir() {
  local work_dir="$1"
  [[ -n "$work_dir" && -d "$work_dir" ]] || {
    printf 'ERROR: --work-dir must point to an existing directory\n' >&2
    return 2
  }
}

agent_delegate_write_log_header() {
  local log_file="$1" host_label="$2" work_dir="$3" sb_root="$4" attempt="$5"
  local extra="${6:-}"
  [[ -n "$log_file" ]] || return 0
  mkdir -p "$(dirname "$log_file")"
  {
    printf '=== %s %s ===\n' "$host_label" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'work_dir=%s\nsb_root=%s\nattempt=%s\n' "$work_dir" "$sb_root" "$attempt"
    [[ -n "$extra" ]] && printf '%s\n' "$extra"
    printf '\n'
  } >>"$log_file"
}

agent_delegate_write_log_footer() {
  local log_file="$1" final_exit="$2" attempt="$3" host_label="$4"
  [[ -n "$log_file" && -f "$log_file" ]] || return 0
  {
    printf '\n=== %s complete exit=%s attempt=%s ===\n' "$host_label" "$final_exit" "$attempt"
  } >>"$log_file"
}

# Exec-mode adapters capture stdout in the wrapper; append after header (interactive tee overwrites).
agent_delegate_append_invoke_output() {
  local log_file="$1" output="$2"
  [[ -n "$log_file" && -n "$output" ]] || return 0
  printf '%s' "$output" >>"$log_file"
}

agent_delegate_write_fallback_log() {
  local log_file="$1" host_label="$2" work_dir="$3" sb_root="$4" attempt="$5" final_exit="$6" output="$7"
  [[ -n "$log_file" ]] || return 0
  mkdir -p "$(dirname "$log_file")"
  {
    printf '=== %s %s ===\n' "$host_label" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'work_dir=%s\nsb_root=%s\nattempt=%s\nexit=%s\n\n' "$work_dir" "$sb_root" "$attempt" "$final_exit"
    agent_delegate_redact_output "$output"
    printf '\n'
  } >"$log_file"
}

agent_delegate_check_log_floor() {
  local log_file="$1" log_floor="$2" host_label="$3"
  [[ -n "$log_file" && -f "$log_file" ]] || return 0
  local log_bytes
  log_bytes="$(wc -c <"$log_file" | tr -d ' ')"
  printf '[%s] log: %s (%s B)\n' "$host_label" "$log_file" "$log_bytes" >&2
  if [[ "$log_bytes" -lt "$log_floor" ]]; then
    printf '[%s] ERROR: log below floor (%s B < %s B) — failure_class=log-floor\n' \
      "$host_label" "$log_bytes" "$log_floor" >&2
    return 1
  fi
  return 0
}

agent_delegate_write_result_skeleton() {
  local result_file="$1" host="$2" task_id="$3" exit_code="$4"
  [[ -n "$result_file" ]] || return 0
  mkdir -p "$(dirname "$result_file")"
  cat >"$result_file" <<EOF
# Delegation result

| Field | Value |
|-------|-------|
| host | $host |
| task_id | $task_id |
| exit_code | $exit_code |
| timestamp | $(date -u +%Y-%m-%dT%H:%M:%SZ) |

## STATUS
pending-audit

## TASK
(see brief.md)

## FILES
(none recorded)

## TESTS
(none recorded)

## COMMIT
(none)

## BLOCKERS
(none)

## NEXT_RETRY_PROMPT
(none)
EOF
}

agent_delegate_normalize_failure_class() {
  local exit_code="$1" output="$2" log_file="${3:-}"
  if [[ "$exit_code" -eq 0 ]]; then
    printf 'success'
    return 0
  fi
  if agent_delegate_is_quota_error "$output"; then
    printf 'quota'
    return 0
  fi
  if [[ -n "$log_file" && -f "$log_file" ]]; then
    local log_bytes
    log_bytes="$(wc -c <"$log_file" | tr -d ' ')"
    local floor="${SB_AGENT_CODEX_LOG_FLOOR:-${SB_AGENT_DELEGATE_LOG_FLOOR:-512}}"
    if [[ "$log_bytes" -lt "$floor" ]]; then
      printf 'log-floor'
      return 0
    fi
  fi
  printf 'delegate-failure'
}

agent_delegate_write_state_marker() {
  local marker_dir="$1" host="$2" task_id="$3" exit_code="$4" failure_class="$5"
  [[ -n "$marker_dir" ]] || return 0
  mkdir -p "$marker_dir"
  cat >"${marker_dir}/state.json" <<EOF
{"host":"$host","task_id":"$task_id","exit_code":$exit_code,"failure_class":"$failure_class","updated":"$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
EOF
}

agent_delegate_write_degraded_fallback_evidence() {
  local artifact_dir="$1" host="$2" task_id="$3" trigger="$4" reason="$5"
  [[ -n "$artifact_dir" ]] || return 0
  mkdir -p "$artifact_dir"
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '{"evidence_id":"EV-DELEGATE-DEGRADED-FALLBACK","host":"%s","trigger":"%s","task_id":"%s","timestamp":"%s","reason":"%s"}\n' \
    "$host" "$trigger" "$task_id" "$ts" "$(printf '%s' "$reason" | sed 's/"/\\"/g')" \
    >>"${artifact_dir}/degraded-fallback.jsonl"
}
