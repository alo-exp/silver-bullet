#!/usr/bin/env bash
# Host resolution and host-isolated artifact paths for enterprise E2E harness.
# Sourced by scripts/enterprise-e2e/lib/core.sh and backward-compat live-common.sh.
set -euo pipefail

enterprise_e2e_harness_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

enterprise_e2e_hosts_config_file() {
  printf '%s\n' "${SB_E2E_HOSTS_CONFIG:-$(enterprise_e2e_harness_root)/config/hosts.json}"
}

# Read a string field from hosts.json for the active or named host.
enterprise_e2e_host_config_get() {
  local field="$1" host="${2:-}"
  local config
  config="$(enterprise_e2e_hosts_config_file)"
  [[ -f "$config" ]] || return 1
  if [[ -z "$host" ]]; then
    host="$(enterprise_e2e_matrix_host)"
  fi
  python3 - "$config" "$host" "$field" <<'PY'
import json, sys
config_path, host, field = sys.argv[1:4]
with open(config_path, encoding="utf-8") as f:
    data = json.load(f)
hosts = data.get("hosts", {})
entry = hosts.get(host, {})
val = entry.get(field)
if val is None:
    sys.exit(1)
if isinstance(val, list):
    print(" ".join(str(v) for v in val))
else:
    print(val)
PY
}

# claude | codex | cursor — honors pre-set SB_E2E_LIVE_RUNTIME / SILVER_BULLET_RUNTIME.
enterprise_e2e_matrix_host() {
  local host="${SB_E2E_LIVE_RUNTIME:-${SILVER_BULLET_RUNTIME:-}}"
  if [[ -z "$host" ]]; then
    local config
    config="$(enterprise_e2e_hosts_config_file)"
    if [[ -f "$config" ]]; then
      host="$(python3 - "$config" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    print(json.load(f).get("default_host", "claude"))
PY
)"
    else
      host="claude"
    fi
  fi
  case "$host" in
    claude|codex|cursor) printf '%s\n' "$host" ;;
    *) printf 'claude\n' ;;
  esac
}

enterprise_e2e_apply_host_path_default() {
  local env_var="$1" field="$2" host sb_root legacy val
  host="$(enterprise_e2e_matrix_host)"
  sb_root="${SB_ROOT:-$(enterprise_e2e_sb_root 2>/dev/null || enterprise_e2e_harness_root)/..}"
  sb_root="$(cd "$sb_root" && pwd)"
  if [[ -n "${!env_var:-}" ]]; then
    return 0
  fi
  val="$(enterprise_e2e_host_config_get "$field" "$host" 2>/dev/null || true)"
  if [[ -n "$val" ]]; then
    export "${env_var}=${sb_root}/${val}"
  fi
}

# Default host-isolated artifact paths (Claude keeps legacy names for Round 6).
enterprise_e2e_apply_matrix_host_defaults() {
  local host sb_root
  host="$(enterprise_e2e_matrix_host)"
  sb_root="${SB_ROOT:-}"
  if [[ -z "$sb_root" ]]; then
  if declare -f enterprise_e2e_sb_root >/dev/null 2>&1; then
    sb_root="$(enterprise_e2e_sb_root)"
  else
    sb_root="$(cd "$(enterprise_e2e_harness_root)/.." && pwd)"
  fi
  fi
  export SB_ROOT="$sb_root"
  export SB_E2E_LIVE_RUNTIME="$host"
  export SILVER_BULLET_RUNTIME="$host"

  if [[ -f "${sb_root}/hooks/lib/runtime-paths.sh" ]]; then
    # shellcheck source=hooks/lib/runtime-paths.sh
    source "${sb_root}/hooks/lib/runtime-paths.sh"
  fi

  enterprise_e2e_apply_host_path_default SB_E2E_LIVE_TEST_LOCK_FILE lock_file
  enterprise_e2e_apply_host_path_default SB_E2E_MATRIX_LOG matrix_log
  enterprise_e2e_apply_host_path_default SB_E2E_MATRIX_BATCH_PID_FILE batch_pid_file
  enterprise_e2e_apply_host_path_default SB_E2E_MATRIX_MONITOR_PID_FILE monitor_pid_file
  enterprise_e2e_apply_host_path_default SB_E2E_MATRIX_MONITOR_STATUS_FILE monitor_status_file
  enterprise_e2e_apply_host_path_default SB_E2E_TUI_FINDINGS tui_findings
  enterprise_e2e_apply_host_path_default SB_E2E_TUI_OFFSETS tui_offsets
  enterprise_e2e_apply_host_path_default SB_E2E_LEDGER_FILE ledger_file
  enterprise_e2e_apply_test_app_fixture_default
}

# Host-isolated test-app checkout (absolute path or repo-relative).
enterprise_e2e_apply_test_app_fixture_default() {
  local host val sb_root
  if [[ -n "${SB_TEST_ENTERPRISE_APP_ROOT:-}" ]]; then
    return 0
  fi
  host="$(enterprise_e2e_matrix_host)"
  val="$(enterprise_e2e_host_config_get test_app_root "$host" 2>/dev/null || true)"
  [[ -n "$val" ]] || return 0
  if [[ "$val" == /* ]]; then
    export SB_TEST_ENTERPRISE_APP_ROOT="$val"
    return 0
  fi
  sb_root="${SB_ROOT:-}"
  if [[ -z "$sb_root" ]]; then
    if declare -f enterprise_e2e_sb_root >/dev/null 2>&1; then
      sb_root="$(enterprise_e2e_sb_root)"
    else
      sb_root="$(cd "$(enterprise_e2e_harness_root)/.." && pwd)"
    fi
  fi
  export SB_TEST_ENTERPRISE_APP_ROOT="${sb_root}/${val}"
}

# Fail fast when SB harness is not on the host track branch (hosts.json git_branch).
enterprise_e2e_assert_host_git_branch() {
  local host expected current sb_root
  if [[ "${SB_E2E_HOST_GIT_BRANCH_ENFORCE:-1}" == "0" ]]; then
    echo "Harness git branch preflight: skipped (SB_E2E_HOST_GIT_BRANCH_ENFORCE=0)"
    return 0
  fi
  host="$(enterprise_e2e_matrix_host)"
  expected="$(enterprise_e2e_host_config_get git_branch "$host" 2>/dev/null || true)"
  if [[ -z "$expected" ]]; then
    return 0
  fi
  sb_root="${SB_ROOT:-}"
  if [[ -z "$sb_root" ]]; then
    if declare -f enterprise_e2e_sb_root >/dev/null 2>&1; then
      sb_root="$(enterprise_e2e_sb_root)"
    else
      sb_root="$(cd "$(enterprise_e2e_harness_root)/.." && pwd)"
    fi
  fi
  [[ -d "${sb_root}/.git" ]] || enterprise_e2e_preflight_fail "SB harness is not a git repo: ${sb_root}"
  current="$(git -C "$sb_root" branch --show-current 2>/dev/null || true)"
  echo "Harness git branch preflight: want=${expected} have=${current:-detached} host=${host}"
  if [[ "$current" != "$expected" ]]; then
    enterprise_e2e_preflight_fail \
      "SB harness on '${current:-detached}' — expected '${expected}' for host=${host} (see hosts.json git_branch)"
  fi
  echo "  OK on ${expected} @ $(git -C "$sb_root" rev-parse --short HEAD 2>/dev/null || echo unknown)"
}

enterprise_e2e_row_attempt_log() {
  local row="$1" attempt="${2:-1}" host sb_root suffix
  host="$(enterprise_e2e_matrix_host)"
  sb_root="${SB_ROOT:-}"
  if [[ "$host" == "claude" ]]; then
    if [[ "$attempt" -eq 1 ]]; then
      printf '%s\n' "${sb_root}/.e2e-row${row}-attempt.log"
    else
      printf '%s\n' "${sb_root}/.e2e-row${row}-attempt${attempt}.log"
    fi
    return 0
  fi
  suffix=""
  if [[ "$attempt" -gt 1 ]]; then
    suffix="${attempt}"
  fi
  printf '%s\n' "${sb_root}/.e2e-row${row}-${host}-attempt${suffix}.log"
}

enterprise_e2e_row_attempt_log_glob() {
  local host sb_root
  host="$(enterprise_e2e_matrix_host)"
  sb_root="${SB_ROOT:-}"
  if [[ "$host" == "claude" ]]; then
    printf '%s\n' "${sb_root}/.e2e-row*-attempt.log"
  else
    printf '%s\n' "${sb_root}/.e2e-row*-${host}-attempt.log"
  fi
}

enterprise_e2e_routing_state_file() {
  if [[ "${SB_E2E_ISOLATED_CLAUDE_CONFIG:-}" == "1" && -n "${CLAUDE_CONFIG_DIR:-}" && -z "${SB_RUNTIME_STATE_DIR:-}" ]]; then
    enterprise_e2e_apply_isolated_claude_runtime_paths 2>/dev/null || true
  fi
  if [[ -f "${SB_ROOT:-}/hooks/lib/runtime-paths.sh" && -z "${SB_RUNTIME_STATE_DIR:-}" ]]; then
    # shellcheck source=hooks/lib/runtime-paths.sh
    source "${SB_ROOT}/hooks/lib/runtime-paths.sh"
  fi
  printf '%s\n' "${SB_RUNTIME_STATE_DIR:-${HOME}/.codex/.silver-bullet}/state"
}

# Host-aware .silver-bullet state root (parent of routing state file).
enterprise_e2e_runtime_state_dir() {
  if [[ -f "${SB_ROOT:-}/hooks/lib/runtime-paths.sh" && -z "${SB_RUNTIME_STATE_DIR:-}" ]]; then
    # shellcheck source=hooks/lib/runtime-paths.sh
    source "${SB_ROOT}/hooks/lib/runtime-paths.sh"
  fi
  printf '%s\n' "${SB_RUNTIME_STATE_DIR:-${HOME}/.codex/.silver-bullet}"
}

# Translate MATRIX_ROWS route column for non-Claude hosts.
enterprise_e2e_matrix_host_route() {
  local route="$1" host
  host="$(enterprise_e2e_matrix_host)"
  case "$host" in
    codex)
      if [[ "$route" == /silver* ]]; then
        printf '$%s\n' "${route:1}"
      else
        printf '%s\n' "$route"
      fi
      ;;
    cursor)
      case "$route" in
        /silver) printf '/silver\n' ;;
        /silver:*) printf '%s\n' "${route#/silver:}" ;;
        *) printf '%s\n' "$route" ;;
      esac
      ;;
    *)
      printf '%s\n' "$route"
      ;;
  esac
}

enterprise_e2e_source_host_adapter() {
  local host adapter_root adapter_file
  host="$(enterprise_e2e_matrix_host)"
  adapter_root="$(enterprise_e2e_harness_root)/lib/adapters"
  adapter_file="${adapter_root}/${host}.sh"
  if [[ -f "$adapter_file" ]]; then
    # shellcheck source=/dev/null
    source "$adapter_file"
    return 0
  fi
  echo "WARN: missing host adapter ${adapter_file}" >&2
  return 1
}
