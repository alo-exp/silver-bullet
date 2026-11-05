#!/usr/bin/env bash
# Shared delegate wrapper behavior for agent-codex-delegate.sh, agent-cursor-delegate.sh, and agent-claude-delegate.sh.
# shellcheck shell=bash

_AGENT_DELEGATE_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/agent-mode.sh
source "${_AGENT_DELEGATE_COMMON_DIR}/agent-mode.sh"

# shellcheck source=scripts/lib/agent-host-exec.sh
source "${_AGENT_DELEGATE_COMMON_DIR}/agent-host-exec.sh"

agent_delegate_is_pinned_ni() {
  [[ "${SB_AM_CONCRETE_PIN:-0}" -eq 1 && "${SB_AM_RESOLVED:-}" == "non-interactive" ]]
}

agent_delegate_quota_retry_max() {
  local env_name="$1"
  local default_auto="${2:-5}"
  local env_val=""
  eval "env_val=\"\${${env_name}:-}\""
  if [[ "${SB_AM_QUOTA_RETRY:-0}" -eq 1 ]]; then
    printf '%s' "${env_val:-$default_auto}"
    return 0
  fi
  if agent_delegate_is_pinned_ni; then
    printf '%s' "${env_val:-0}"
    return 0
  fi
  printf '%s' "${env_val:-$default_auto}"
}

# Pinned NI: exec native argv only. Does not return on success.
# Pi + expect-file: wrap first hop with zero-byte idle kill (do not exec) so a
# hung Qwen thinking model cannot pin the parent for ~11 min. Gemini/MiniMax/
# DeepSeek use a 600s first-byte window. --continue stays in invoke.sh.
agent_delegate_exec_pinned_ni() {
  local host="$1" work_dir="$2" prompt="$3" permission_mode="${4:-permissive}"
  local expect_file="${SB_AGENT_EXPECT_FILE:-${PI_EXPECT_FILE:-}}"
  if ! agent_host_build_argv "$host" "non-interactive" "$work_dir" "$prompt" "$permission_mode"; then
    agent_mode_fail_unavailable "mode-unavailable"
    return 3
  fi
  agent_host_dump_argv
  cd "$work_dir" || return 1
  if [[ "$host" == "pi" && -n "$expect_file" ]]; then
    agent_host_pi_run_argv_zero_byte_guard "$expect_file"
    return $?
  fi
  exec "${AGENT_HOST_ARGV[@]}" || {
    agent_mode_fail_unavailable "mode-unavailable"
    return 3
  }
}


# Default permission mode when --mode is not given (R4-23): permissive only when the work dir IS the
# current project: CLAUDE_PROJECT_DIR (else $PWD) names the project; when that is a git repo the work
# dir must resolve to the same git toplevel (so a separate repo cloned inside the project is outside),
# otherwise the work dir must be that exact directory (so a session started in $HOME does not make
# everything below it "the project"). Everything else defaults to strict.
# SB_AGENT_DELEGATE_DEFAULT_MODE (permissive|strict) is an explicit operator override.
agent_delegate_default_mode() {
  local work_dir="$1" project wd ptop wtop mode=strict
  case "${SB_AGENT_DELEGATE_DEFAULT_MODE:-}" in
    permissive|strict) printf '%s' "$SB_AGENT_DELEGATE_DEFAULT_MODE"; return 0 ;;
  esac
  project="$(cd "${CLAUDE_PROJECT_DIR:-$PWD}" 2>/dev/null && pwd -P)" || project=""
  wd="$(cd "$work_dir" 2>/dev/null && pwd -P)" || wd=""
  ptop="$(git -C "${project:-/nonexistent}" rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -n "$ptop" ]]; then
    wtop="$(git -C "${wd:-/nonexistent}" rev-parse --show-toplevel 2>/dev/null || true)"
    [[ -n "$wtop" && "$(cd "$wtop" && pwd -P)" == "$(cd "$ptop" && pwd -P)" ]] && mode=permissive
  elif [[ -n "$project" && "$wd" == "$project" ]]; then
    mode=permissive
  fi
  printf '[agent-delegate] default --mode %s (work dir %s the current project; pass --mode to choose)\n' \
    "$mode" "$([[ "$mode" == permissive ]] && echo is || echo is not)" >&2
  printf '%s' "$mode"
}

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

# A quota/rate-limit failure is recognised only from provider or CLI error text (HTTP status
# fields, rate_limit_error types, "quota exceeded"-style sentences). A bare 429, "quota" or
# "rate limit" elsewhere in the output (test logs, file names, code under review) is not one (R4-20).
AGENT_DELEGATE_QUOTA_ERROR_RE='rate_limit_error|rate_limit_exceeded|insufficient_quota|rate[[:space:]]*limit(ed|[[:space:]]+(exceeded|reached|hit))|too[[:space:]]+many[[:space:]]+requests|token[[:space:]]+plan[^[:cntrl:]]{0,40}(exhaust|exceed|limit|reach)|(hit|exceeded|exhausted|reached)[^[:cntrl:]]{0,30}(quota|usage[[:space:]]+limit|token[[:space:]]+plan)|quota[^[:cntrl:]]{0,20}(exceeded|exhausted|reached|used[[:space:]]+up)|usage[[:space:]]+limit[[:space:]]+(reached|exceeded)|(error|status|http|code)["'"'"']?[[:space:]]*[:=/]?[[:space:]]*429([^0-9]|$)|(^|[^0-9.])429[[:space:]]+(too|rate|error|status)'
# Only lines that look like CLI/provider errors are classified (an "Error:" / "API Error:" line, an
# HTTP status line, a JSON error object, a provider error code, or a provider's own quota sentence);
# test output such as "expected status 429, got 200" or "quota exceeded test passed" is not.
AGENT_DELEGATE_ERROR_LINE_RE='^[[:space:]]*(\[[^]]*\][[:space:]]*)?(api[[:space:]]+)?(error|fatal|exception)([^a-z]|$)|HTTP[/ ][0-9.]* *[45][0-9][0-9]|^[[:space:]]*\{.*"error"|rate_limit_error|rate_limit_exceeded|insufficient_quota|^[[:space:]]*(quota[[:space:]]+(exceeded|exhausted)[[:space:]]*[:.-]|token[[:space:]]+plan[[:space:]]+(exhausted|exceeded|limit)|you(.ve|[[:space:]]+have)[[:space:]]+(hit|reached|exceeded)|(claude|codex|openai|anthropic)[^.]{0,40}(quota|usage[[:space:]]+limit))'
agent_delegate_is_quota_error() {
  local blob="$1" lines
  lines="$(grep -iE "$AGENT_DELEGATE_ERROR_LINE_RE" <<<"$blob" || true)"
  grep -qiE "$AGENT_DELEGATE_QUOTA_ERROR_RE" <<<"$lines"
}

# Fingerprint of the work dir's state (HEAD, status, tracked diff, untracked file hashes). "unknown" outside a git repo.
agent_delegate_workdir_fingerprint() {
  local work_dir="$1"
  if ! git -C "$work_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf 'unknown'
    return 0
  fi
  # HEAD, status, the tracked diff and the content hash of every untracked (not ignored) file, so an
  # edit to a pre-existing untracked file counts. Ignored files and writes outside the work dir are
  # not seen (documented residual).
  {
    git -C "$work_dir" rev-parse HEAD 2>/dev/null || echo no-head
    git -C "$work_dir" status --porcelain -uall 2>/dev/null || true
    git -C "$work_dir" diff HEAD --no-ext-diff 2>/dev/null || true
    # Symlinks are recorded by their target string and never followed (a link to /dev/zero or a FIFO
    # must not hang the delegation); only regular files are read, at most 4 MiB each.
    (cd "$work_dir" && git ls-files -o --exclude-standard -z 2>/dev/null | while IFS= read -r -d '' f; do
      if [[ -L "$f" ]]; then
        printf '%s -> %s\n' "$f" "$(readlink "$f")"
      elif [[ -f "$f" ]]; then
        printf '%s %s ' "$f" "$(wc -c <"$f" | tr -d ' ')"
        head -c 4194304 <"$f" | git hash-object --stdin
      fi
    done
    true)
  } | cksum
}

# Decide whether a failed attempt is re-run: only for a real provider quota error, only inside the
# retry budget, and, unless --quota-retry opted in, only when the attempt left the work dir
# untouched (a retry replays the whole task with permissive flags, so side effects would repeat).
# Returns 0 to retry, 1 to stop.
agent_delegate_quota_retry_decision() {
  local label="$1" output="$2" attempt="$3" max="$4" work_dir="$5" fp_before="$6"
  agent_delegate_is_quota_error "$output" || return 1
  if agent_delegate_quota_blocks_short_retry "$output"; then
    printf '[%s] quota window exhausted — skip short retry (RFL schedule)\n' "$label" >&2
    return 1
  fi
  if [[ "$attempt" -gt "$max" ]]; then
    printf '[%s] quota retries exhausted\n' "$label" >&2
    return 1
  fi
  if [[ "${SB_AM_QUOTA_RETRY:-0}" -ne 1 ]]; then
    local fp_after
    fp_after="$(agent_delegate_workdir_fingerprint "$work_dir")"
    if [[ "$fp_before" == "unknown" || "$fp_after" != "$fp_before" ]]; then
      printf '[%s] quota error, but the attempt may have changed the work dir; not re-running (pass --quota-retry to retry anyway)\n' "$label" >&2
      return 1
    fi
  fi
  return 0
}

# 5-hour / weekly / monthly windows are not 60s-retryable. RFL schedules those.
agent_delegate_quota_blocks_short_retry() {
  local blob="$1"
  local repo_root resolver json
  repo_root="$(cd "${_AGENT_DELEGATE_COMMON_DIR}/../.." && pwd)"
  resolver="${repo_root}/scripts/review-fix-ladder.py"
  [[ -f "$resolver" ]] || return 1
  json="$(python3 "$resolver" --classify-quota-window --subscription-output "$blob" 2>/dev/null)" || return 1
  python3 -c 'import json,sys
d=json.load(sys.stdin)
sys.exit(0 if d.get("should_short_retry") is False else 1)' <<<"$json"
}

# Redaction and brief scanning live in scripts/lib/agent_redact.py (case-insensitive, value-shaped:
# token prefixes, JWTs, PEM keys, Bearer/Authorization values, KEY=value assignments).
agent_delegate_redact_output() {
  local blob="$1"
  printf '%s' "$blob" | python3 "${_AGENT_DELEGATE_COMMON_DIR}/agent_redact.py" --redact
}

# Redact a log in place (atomic; never through a symlink).
agent_delegate_redact_log_file() {
  local path="$1"
  [[ -f "$path" ]] || return 0
  python3 "${_AGENT_DELEGATE_COMMON_DIR}/agent_redact.py" --redact-file "$path" || true
}

# Keep the raw log private while the child runs (0600) and redact it even when the delegate is
# interrupted: the traps redact on EXIT and turn INT/TERM/HUP into an exit so EXIT runs.
# SIGKILL cannot be trapped; the 0600 mode is the remaining protection (R4-31).
agent_delegate_guard_log() {
  local log_file="$1"
  [[ -n "$log_file" ]] || return 0
  AGENT_DELEGATE_GUARDED_LOG="$log_file"
  mkdir -p "$(dirname "$log_file")"
  ( umask 077; : >>"$log_file" )
  chmod 600 "$log_file" 2>/dev/null || true
  trap 'agent_delegate_redact_log_file "$AGENT_DELEGATE_GUARDED_LOG"' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  trap 'exit 129' HUP
}

# Returns 0 when text holds a literal credential (token prefix, JWT, PEM key, Bearer value or a
# high-entropy KEY=value; references such as settings.X, process.env.X or calls are not literals) and
# sets AGENT_DELEGATE_SECRET_FINDING to "<rule> line <n>". A scanner failure counts as "has secrets"
# (fail closed). SB_AGENT_ALLOW_SECRET_LIKE_BRIEF=1 is the user's override: it is read from the
# environment of the process that starts the delegate (set it in your own shell before the session;
# never from the brief), and every use is announced on stderr.
agent_delegate_brief_has_secrets() {
  local text="$1" rc=0
  AGENT_DELEGATE_SECRET_FINDING=""
  AGENT_DELEGATE_SECRET_FINDING="$(printf '%s' "$text" | python3 "${_AGENT_DELEGATE_COMMON_DIR}/agent_redact.py" --scan)" || rc=$?
  [[ "$rc" -ne 0 ]] || return 1
  [[ -n "$AGENT_DELEGATE_SECRET_FINDING" ]] || AGENT_DELEGATE_SECRET_FINDING="scanner-error"
  if [[ "${SB_AGENT_ALLOW_SECRET_LIKE_BRIEF:-}" == "1" ]]; then
    printf '[agent-delegate] WARN: SB_AGENT_ALLOW_SECRET_LIKE_BRIEF=1 overrides the brief secret scan (%s)\n' \
      "$AGENT_DELEGATE_SECRET_FINDING" >&2
    return 1
  fi
  return 0
}

agent_delegate_secret_error() {
  printf 'ERROR: %s contains secret patterns — a secret-looking value (rule/line: %s); replace it with a placeholder or an environment reference, or set SB_AGENT_ALLOW_SECRET_LIKE_BRIEF=1 in your own shell to override\n' \
    "$1" "$AGENT_DELEGATE_SECRET_FINDING" >&2
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
      agent_delegate_secret_error "brief"
      return 2
    fi
  elif [[ -n "$prompt_file" ]]; then
    [[ -f "$prompt_file" ]] || { printf 'ERROR: prompt file not found: %s\n' "$prompt_file" >&2; return 2; }
    prompt_file="$(agent_delegate_canonicalize_path "$prompt_file")"
    resolved="$(cat "$prompt_file")"
    if agent_delegate_brief_has_secrets "$resolved"; then
      agent_delegate_secret_error "prompt file"
      return 2
    fi
  else
    resolved="$prompt_text"
    if agent_delegate_brief_has_secrets "$resolved"; then
      agent_delegate_secret_error "prompt"
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

# Resolve --work-dir to an absolute path before any chdir/exec (Codex/OpenCode).
agent_delegate_resolve_work_dir() {
  local work_dir="$1"
  agent_delegate_validate_work_dir "$work_dir" || return $?
  (cd "$work_dir" && pwd)
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

# Post-invoke product evidence: git head, last commit, working tree status.
agent_delegate_append_workdir_evidence() {
  local log_file="$1" work_dir="$2" prompt_text="${3:-}"
  [[ -n "$log_file" && -n "$work_dir" && -d "$work_dir" ]] || return 0

  {
    printf '\n=== workdir evidence ===\n'
    if [[ -n "$prompt_text" ]]; then
      printf 'prompt_bytes=%s\n' "$(printf '%s' "$prompt_text" | wc -c | tr -d ' ')"
    fi
    if git -C "$work_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      printf 'git_head=%s\n' "$(git -C "$work_dir" rev-parse HEAD 2>/dev/null || echo 'none')"
      printf 'git_log_last=\n'
      git -C "$work_dir" log -3 --oneline 2>/dev/null || true
      printf 'git_status=\n'
      git -C "$work_dir" status --short 2>/dev/null || true
      printf 'workdir_files=\n'
      find "$work_dir" -maxdepth 2 -type f ! -path '*/.git/*' 2>/dev/null | head -20 || true
      if [[ -f "${work_dir}/README.md" ]]; then
        printf 'readme_preview=\n'
        head -5 "${work_dir}/README.md" 2>/dev/null || true
      fi
    else
      printf 'git=not-a-repo\n'
      ls -la "$work_dir" 2>/dev/null || true
    fi
    printf '\n'
  } >>"$log_file"
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

# Fail false-complete delegations: brief-only logs without agent activity.
# Enable with SB_AGENT_CLAUDE_REQUIRE_WORKFLOW_MARKERS=1 (AUTO-E2E track).
agent_delegate_check_workflow_markers() {
  local log_file="$1" host_label="$2"
  [[ "${SB_AGENT_CLAUDE_REQUIRE_WORKFLOW_MARKERS:-0}" == "1" ]] || return 0
  [[ -n "$log_file" && -f "$log_file" ]] || return 0

  local has_tokens=0 has_tool_activity=0
  if grep -qE '[1-9][0-9]*[^0-9]{0,40}tokens' "$log_file" 2>/dev/null; then
    has_tokens=1
  fi
  if grep -qE '⏺|Bash\(|Read\(|Write\(|Edit\(' "$log_file" 2>/dev/null; then
    has_tool_activity=1
  fi

  if [[ "$has_tokens" -eq 1 || "$has_tool_activity" -eq 1 ]]; then
    return 0
  fi

  printf '[%s] ERROR: log lacks workflow activity markers (need token counter >0 or tool-use lines) — failure_class=no-workflow-markers\n' \
    "$host_label" >&2
  return 1
}

# One Markdown table cell: no pipes or line breaks that would split the row.
agent_delegate_md_cell() {
  printf '%s' "$1" | tr '\n\r|' '   '
}

agent_delegate_write_result_skeleton() {
  local result_file="$1" host task_id exit_code
  host="$(agent_delegate_md_cell "$2")"
  task_id="$(agent_delegate_md_cell "$3")"
  exit_code="$(agent_delegate_md_cell "$4")"
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
  if [[ -n "${SB_AM_FAILURE_CLASS:-}" ]]; then
    printf '%s' "$SB_AM_FAILURE_CLASS"
    return 0
  fi
  if [[ "$exit_code" -eq 0 ]]; then
    printf 'success'
    return 0
  fi
  if [[ "$output" == *mode-unavailable* ]]; then
    printf 'mode-unavailable'
    return 0
  fi
  if [[ "$output" == *mode-conflict* ]]; then
    printf 'mode-conflict'
    return 0
  fi
  if [[ "$output" == *escalate-unavailable* ]]; then
    printf 'escalate-unavailable'
    return 0
  fi
  if [[ "$output" == *max-turns* ]]; then
    printf 'max-turns'
    return 0
  fi
  if [[ "$output" == *hook-trust* ]]; then
    printf 'hook-trust'
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
  jq -nc --arg host "$host" --arg task_id "$task_id" --arg exit_code "$exit_code" \
    --arg failure_class "$failure_class" --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{host:$host,task_id:$task_id,exit_code:(try ($exit_code|tonumber) catch 1),failure_class:$failure_class,updated:$updated}' \
    >"${marker_dir}/state.json"
}

agent_delegate_write_degraded_fallback_evidence() {
  local artifact_dir="$1" host="$2" task_id="$3" trigger="$4" reason="$5"
  [[ -n "$artifact_dir" ]] || return 0
  mkdir -p "$artifact_dir"
  jq -nc --arg host "$host" --arg trigger "$trigger" --arg task_id "$task_id" \
    --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg reason "$reason" \
    '{evidence_id:"EV-DELEGATE-DEGRADED-FALLBACK",host:$host,trigger:$trigger,task_id:$task_id,timestamp:$timestamp,reason:$reason}' \
    >>"${artifact_dir}/degraded-fallback.jsonl"
}

# Pre-delegation bootstrap for opted-in Graphify + agentmemory (Claude/Codex/Cursor delegates).
# Ensures graphify index/query freshness and agentmemory server/export exist before substantive edits.
agent_delegate_preflight_recommended_tools() {
  local work_dir="${1:-}" sb_root="${2:-}" host="${3:-claude}"
  [[ "${SB_AM_SKIP_PREFLIGHT:-0}" -eq 1 || "${SB_AGENT_SKIP_PREFLIGHT:-}" == "1" ]] && return 0
  if agent_delegate_is_pinned_ni; then
    return 0
  fi
  [[ "${SB_AGENT_CERT_RUN:-}" == "1" || "${SB_AGENT_CERT_RUN:-}" == "true" ]] && return 0
  [[ -n "$work_dir" && -d "$work_dir" && -f "${work_dir}/.silver-bullet/agent-cert-run" ]] && return 0
  [[ -n "$work_dir" && -d "$work_dir" ]] || return 0
  [[ -n "$sb_root" && -d "$sb_root" ]] || return 0

  local core="${sb_root}/scripts/enterprise-e2e/lib/core.sh"
  [[ -f "$core" ]] || {
    printf '[agent-delegate] WARN: missing enterprise preflight lib at %s\n' "$core" >&2
    return 0
  }

  # shellcheck source=scripts/enterprise-e2e/lib/core.sh
  source "$core"
  export SILVER_BULLET_RUNTIME="$host"
  export SB_RUNTIME_HOST="$host"

  if ! enterprise_e2e_code_intel_preflight "$sb_root" "$work_dir" 0; then
    printf '[agent-delegate] ERROR: recommended-tools preflight failed (host=%s work_dir=%s)\n' \
      "$host" "$work_dir" >&2
    return 1
  fi

  local config_file="${work_dir}/.silver-bullet.json"
  if [[ -f "$config_file" ]] && declare -f sb_agentmemory_record_usage >/dev/null 2>&1; then
    sb_agentmemory_record_usage "$config_file" || true
  fi
  return 0
}
