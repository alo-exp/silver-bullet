#!/usr/bin/env bash
# Shared helpers for enterprise E2E live test operator runs.
# Sourced by scripts/run-enterprise-e2e-live-test.sh and tests/enterprise-e2e-live/*.
set -euo pipefail

# Bash 3.2 (macOS): mapfile/readarray unavailable
enterprise_e2e_read_lines_to_array() {
  local _var="$1"
  shift
  local _line
  eval "${_var}=()"
  while IFS= read -r _line; do
    [[ -n "$_line" ]] && eval "${_var}+=(\"$_line\")"
  done < <("$@")
}

enterprise_e2e_sb_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
}

enterprise_e2e_fixture_dir() {
  printf '%s\n' "${SB_TEST_ENTERPRISE_APP_ROOT:-/Users/shafqat/projects/enterprise-grade-test-app}"
}

enterprise_e2e_matrix_log() {
  printf '%s\n' "${SB_E2E_MATRIX_LOG:-${SB_ROOT}/.e2e-matrix-live.log}"
}

enterprise_e2e_ledger_file() {
  printf '%s\n' "${SB_E2E_LEDGER_FILE:-${SB_ROOT}/.planning/enterprise-e2e/ROUND-1-LEDGER.md}"
}

# Rows 1-20 explicit; 21-22 are internal (verified via parent rows).
enterprise_e2e_all_row_nums() {
  printf '%s\n' 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20
}

enterprise_e2e_row_complete_in_log() {
  local row="$1" log="$2"
  [[ -f "$log" ]] || return 1
  awk -v target="$row" '
    /^=== Row [0-9]+:/ {
      if (cur == target && (pass || skip)) { done = 1 }
      cur = $3
      sub(/:$/, "", cur)
      pass = 0
      skip = 0
    }
    cur == target && /^  PASS:/ { pass = 1 }
    cur == target && /^  SKIP:/ { skip = 1 }
    cur == target && /^  DRY RUN PASS/ { pass = 1 }
    cur == target && /^  FAIL:/ { pass = 0; skip = 0 }
    END { exit (done || pass || skip) ? 0 : 1 }
  ' "$log"
}

_enterprise_e2e_ensure_ledger_reconcile_sourced() {
  if ! declare -f enterprise_e2e_ledger_matrix_rows >/dev/null 2>&1; then
    local lib_dir
    lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # shellcheck source=scripts/lib/enterprise-e2e-ledger-reconcile.sh
    source "${lib_dir}/enterprise-e2e-ledger-reconcile.sh"
  fi
}

# True when workflow matrix row is Pass in the human-auditable ledger.
enterprise_e2e_ledger_row_is_pass() {
  local row="$1" ledger="$2" row_status
  [[ -n "$ledger" && -f "$ledger" ]] || return 1
  _enterprise_e2e_ensure_ledger_reconcile_sourced
  row_status="$(enterprise_e2e_ledger_matrix_rows "$ledger" | awk -v r="$row" '$1 == r { print $2; exit }')"
  enterprise_e2e_ledger_status_is_pass "${row_status:-}"
}

# Resume rows: ledger Pass → skip; ledger incomplete → include (even when log SKIP).
# Without a ledger file, fall back to matrix log PASS/SKIP completion.
enterprise_e2e_incomplete_rows() {
  local log="$1" ledger="${2:-}" row out=()
  for row in $(enterprise_e2e_all_row_nums); do
    if [[ -n "$ledger" && -f "$ledger" ]]; then
      if enterprise_e2e_ledger_row_is_pass "$row" "$ledger"; then
        continue
      fi
      out+=("$row")
      continue
    fi
    if ! enterprise_e2e_row_complete_in_log "$row" "$log"; then
      out+=("$row")
    fi
  done
  if ((${#out[@]} > 0)); then
    printf '%s\n' "${out[@]}"
  fi
}

enterprise_e2e_assert_no_auth_mutations() {
  local script="$1"
  if grep -qE 'claude auth (login|logout)|claude /logout|setup-token|/login|/logout' "$script" 2>/dev/null; then
    echo "ERROR: $script must not invoke login/logout (API key auth only)" >&2
    return 1
  fi
  return 0
}

# Single live-test driver — prevents concurrent --resume races on install-claude / hook audit.
enterprise_e2e_live_test_lock_file() {
  printf '%s\n' "${SB_E2E_LIVE_TEST_LOCK_FILE:-${SB_ROOT:-}/.e2e-live-test.lock}"
}

enterprise_e2e_acquire_live_test_lock() {
  local lock pid
  lock="$(enterprise_e2e_live_test_lock_file)"
  if [[ -f "$lock" ]]; then
    pid="$(tr -d '[:space:]' <"$lock" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      echo "ERROR: enterprise E2E live test already running (pid ${pid}; lock ${lock})" >&2
      echo "       Stop the other driver or remove stale lock if the pid is dead." >&2
      return 1
    fi
    echo "WARN: removing stale live-test lock (pid ${pid:-unknown} not running)"
    rm -f "$lock"
  fi
  printf '%s\n' "$$" >"$lock"
  return 0
}

enterprise_e2e_release_live_test_lock() {
  local lock
  lock="$(enterprise_e2e_live_test_lock_file)"
  [[ -f "$lock" ]] || return 0
  if [[ "$(tr -d '[:space:]' <"$lock" 2>/dev/null || true)" == "$$" ]]; then
    rm -f "$lock"
  fi
}

# install-claude.sh invokes the Claude CLI; without a controlling tty (nohup / &)
# the child can receive SIGHUP mid-marketplace-add and abort under set -e.
enterprise_e2e_run_install_claude() {
  local sb_root="${1:-${SB_ROOT:-}}"
  local log="${SB_E2E_INSTALL_CLAUDE_LOG:-${sb_root}/.e2e-install-claude.log}"
  local pid deadline
  [[ -n "$sb_root" && -d "$sb_root" ]] || return 1
  enterprise_e2e_prepend_harness_path
  echo "Plugin install (latest SB checkout):"
  if [[ -t 1 && -t 0 ]]; then
    (cd "$sb_root" && bash scripts/install-claude.sh)
    return $?
  fi
  : >"$log"
  pid="$(sb_run_detached --log "$log" -- bash -c "cd $(printf '%q' "$sb_root") && exec bash scripts/install-claude.sh </dev/null")"
  deadline=$((SECONDS + 300))
  while (( SECONDS < deadline )); do
    if grep -qE 'Claude marketplaces registered|Claude marketplace refreshed' "$log" 2>/dev/null; then
      wait "$pid" 2>/dev/null || true
      tail -3 "$log" || true
      return 0
    fi
    if ! kill -0 "$pid" 2>/dev/null; then
      if grep -qE 'Claude marketplaces registered|Claude marketplace refreshed' "$log" 2>/dev/null; then
        tail -3 "$log" || true
        return 0
      fi
      echo "ERROR: install-claude exited before completion — see ${log}" >&2
      tail -20 "$log" >&2 || true
      return 1
    fi
    sleep 2
  done
  echo "ERROR: install-claude timed out after 300s — see ${log}" >&2
  tail -20 "$log" >&2 || true
  return 1
}

enterprise_e2e_prepend_harness_path() {
  local sb_root="${SB_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
  if [[ -f "${sb_root}/tests/live/lib/detach-background.sh" ]]; then
    # shellcheck source=tests/live/lib/detach-background.sh
    source "${sb_root}/tests/live/lib/detach-background.sh"
    sb_prepend_harness_path
  fi
}

enterprise_e2e_export_live_defaults() {
  enterprise_e2e_prepend_harness_path
  export SB_E2E_MATRIX_CLEAN_ENV="${SB_E2E_MATRIX_CLEAN_ENV:-0}"
  export SB_E2E_MATRIX_DRY_RUN="${SB_E2E_MATRIX_DRY_RUN:-}"
  unset SB_E2E_MATRIX_DRY_RUN 2>/dev/null || true
  export SB_E2E_MATRIX_QUOTA_RETRY_INTERVAL="${SB_E2E_MATRIX_QUOTA_RETRY_INTERVAL:-60}"
  export SB_E2E_WORKFLOW_QUIET_TIMEOUT="${SB_E2E_WORKFLOW_QUIET_TIMEOUT:-600}"
  export CLAUDE_MODEL="${CLAUDE_MODEL:-haiku}"
  export SILVER_BULLET_RUNTIME=claude
  export SB_E2E_LIVE_RUNTIME=claude
}

# Session 0 gate — matrix rows require bootstrap unless explicitly skipped.
enterprise_e2e_ledger_session0_pass() {
  local ledger="${1:-}"
  [[ -f "$ledger" ]] || return 1
  awk '
    /^## Session 0/ { in_s0 = 1; next }
    in_s0 && /^## / { in_s0 = 0 }
    in_s0 && /Graphify \+ agentmemory opted in/ {
      if ($0 ~ /\*\*Pass\*\*/ || $0 ~ /\| Pass \|/) { graph = 1 }
    }
    in_s0 && /Enterprise preflight/ {
      if ($0 ~ /\*\*Pass\*\*/ || $0 ~ /\| Pass \|/) { preflight = 1 }
    }
    END { exit (graph || preflight) ? 0 : 1 }
  ' "$ledger" 2>/dev/null
}

enterprise_e2e_fixture_code_intel_opted_in() {
  local fixture_dir="${1:-}" config="${fixture_dir}/.silver-bullet.json"
  [[ -f "$config" ]] || return 1
  jq -e \
    '.recommended_tools.graphify.enabled_by_user == true and .recommended_tools.agentmemory.enabled_by_user == true' \
    "$config" >/dev/null 2>&1
}

enterprise_e2e_session0_satisfied() {
  local fixture_dir="${1:-}" ledger="${2:-}"
  enterprise_e2e_ledger_session0_pass "$ledger" && return 0
  enterprise_e2e_fixture_code_intel_opted_in "$fixture_dir" && return 0
  return 1
}

enterprise_e2e_assert_session0_or_skip() {
  local fixture_dir="${1:-}" ledger="${2:-}"
  if [[ "${SB_E2E_SESSION0_SKIP:-}" == "1" ]]; then
    local reason="${SB_E2E_SESSION0_SKIP_REASON:-unspecified}"
    echo "WARN: Session 0 gate skipped (SB_E2E_SESSION0_SKIP=1): ${reason}"
    return 0
  fi
  if enterprise_e2e_session0_satisfied "$fixture_dir" "$ledger"; then
    echo "Session 0 gate: OK (ledger Pass or fixture graphify+agentmemory opted in)"
    return 0
  fi
  echo "ERROR: Session 0 not satisfied — run /silver:init + code-intel opt-in on fixture," >&2
  echo "       or mark Session 0 Pass in ledger, or set SB_E2E_SESSION0_SKIP=1 with SB_E2E_SESSION0_SKIP_REASON." >&2
  return 1
}

# --- Code-intel preflight (Graphify, agentmemory, RTK, Context Mode) ---
# Fail fast when recommended_tools.*.enabled_by_user is true in .silver-bullet.json.
# Use --skip-code-intel-preflight on the live entrypoint for debugging only.

enterprise_e2e_source_code_intel_libs() {
  local sb_root="${1:-}"
  local lib_dir="${sb_root}/hooks/lib"
  local f
  for f in recommended-tools.sh graphify-gate.sh agentmemory-gate.sh rtk-gate.sh \
    context-mode-gate.sh rtk-cm-global.sh; do
    if [[ -f "${lib_dir}/${f}" ]]; then
      # shellcheck source=/dev/null
      source "${lib_dir}/${f}"
    fi
  done
}

enterprise_e2e_preflight_fail() {
  echo "ERROR: enterprise E2E code-intel preflight: $*" >&2
  return 1
}

enterprise_e2e_tool_enforced_in_config() {
  local config_file="${1:-}" tool_id="${2:-}"
  [[ -n "$config_file" && -f "$config_file" ]] || return 1
  declare -f sb_recommended_tool_enforced >/dev/null 2>&1 \
    && sb_recommended_tool_enforced "$config_file" "$tool_id"
}

enterprise_e2e_any_tool_enforced() {
  local sb_root="${1:-}" fixture_dir="${2:-}" tool_id="${3:-}"
  local config
  for config in "${sb_root}/.silver-bullet.json" "${fixture_dir}/.silver-bullet.json"; do
    enterprise_e2e_tool_enforced_in_config "$config" "$tool_id" && return 0
  done
  return 1
}

enterprise_e2e_preflight_graphify() {
  local project_root="${1:-}" config_file="${2:-}" dry_run="${3:-0}"
  local task_context="${4:-enterprise e2e live test matrix routes hooks skills orchestrator}"
  local graph_rel graph_path

  enterprise_e2e_tool_enforced_in_config "$config_file" "graphify" || return 0

  echo "  graphify: ${project_root} (opted in)"
  if [[ "$dry_run" == "1" ]]; then
    echo "    DRY-RUN: would verify index + fresh graphify query"
    return 0
  fi

  if ! declare -f sb_graphify_cli_available >/dev/null 2>&1 || ! sb_graphify_cli_available; then
    enterprise_e2e_preflight_fail "graphify CLI missing — install: uv tool install graphifyy (${project_root})"
  fi

  if ! sb_graphify_index_exists "$project_root" "$config_file"; then
    echo "    graphify index missing — running graphify update . --no-cluster"
    if ! (cd "$project_root" && graphify update . --no-cluster); then
      enterprise_e2e_preflight_fail "graphify update failed in ${project_root}"
    fi
  fi

  graph_rel="$(sb_graphify_graph_rel_path "$config_file")"
  graph_path="$(sb_graphify_abs_graph_path "$project_root" "$config_file")"
  if [[ ! -f "$graph_path" || -L "$graph_path" ]]; then
    enterprise_e2e_preflight_fail "graphify index still missing at ${graph_path}"
  fi

  if ! sb_graphify_query_is_fresh "$config_file"; then
    echo "    graphify query stale/missing — recording fresh query"
    if ! (cd "$project_root" && graphify query "$task_context" --graph "$graph_rel" --budget 2000 >/dev/null); then
      enterprise_e2e_preflight_fail "graphify query failed in ${project_root}"
    fi
    if declare -f sb_graphify_record_query >/dev/null 2>&1; then
      sb_graphify_record_query "$config_file" || enterprise_e2e_preflight_fail "could not record graphify query state"
    fi
  else
    echo "    graphify query fresh"
  fi
  return 0
}

enterprise_e2e_preflight_agentmemory() {
  local project_root="${1:-}" config_file="${2:-}" host="${3:-}" dry_run="${4:-0}"

  enterprise_e2e_tool_enforced_in_config "$config_file" "agentmemory" || return 0

  echo "  agentmemory: ${project_root} (opted in)"
  if [[ "$dry_run" == "1" ]]; then
    echo "    DRY-RUN: would verify server health, MCP wiring, .agentmemory/"
    return 0
  fi

  if ! declare -f sb_agentmemory_cli_available >/dev/null 2>&1 || ! sb_agentmemory_cli_available; then
    enterprise_e2e_preflight_fail "agentmemory CLI missing — npm install -g @agentmemory/agentmemory"
  fi

  if ! sb_agentmemory_server_healthy "$config_file"; then
    echo "    agentmemory server not healthy — starting background server"
    mkdir -p "${HOME}/.agentmemory"
    nohup agentmemory >"${HOME}/.agentmemory/server.log" 2>&1 &
    sleep 2
    if ! sb_agentmemory_server_healthy "$config_file"; then
      enterprise_e2e_preflight_fail "agentmemory server not healthy — see docs/AGENTMEMORY.md and ~/.agentmemory/server.log"
    fi
  fi

  host="${host:-$(sb_runtime_host)}"
  if declare -f sb_agentmemory_platform_artifact_present >/dev/null 2>&1 \
    && ! sb_agentmemory_platform_artifact_present "$project_root" "$host"; then
    enterprise_e2e_preflight_fail "agentmemory MCP not wired for host=${host} — see docs/AGENTMEMORY.md"
  fi

  if declare -f sb_agentmemory_export_exists >/dev/null 2>&1 \
    && ! sb_agentmemory_export_exists "$project_root" "$config_file"; then
    enterprise_e2e_preflight_fail ".agentmemory/ export root missing in ${project_root} — mkdir -p .agentmemory/memory"
  fi
  return 0
}

enterprise_e2e_preflight_rtk() {
  local config_file="${1:-}" host="${2:-}" dry_run="${3:-0}"

  enterprise_e2e_tool_enforced_in_config "$config_file" "rtk" || return 0

  echo "  rtk: global wiring (opted in via ${config_file})"
  if [[ "$dry_run" == "1" ]]; then
    echo "    DRY-RUN: would verify rtk gain --help and host PreToolUse hook"
    return 0
  fi

  local rtk_bin
  rtk_bin="$(sb_rtk_cli_path 2>/dev/null || true)"
  if [[ -z "$rtk_bin" ]] || ! sb_rtk_cli_available; then
    enterprise_e2e_preflight_fail "rtk CLI missing or wrong binary — install rtk-ai/rtk (see docs/RTK.md)"
  fi
  if ! "$rtk_bin" gain --help >/dev/null 2>&1; then
    enterprise_e2e_preflight_fail "rtk gain --help failed — verify rtk-ai/rtk install"
  fi
  if declare -f sb_rtk_version_ok >/dev/null 2>&1 && ! sb_rtk_version_ok "$config_file"; then
    enterprise_e2e_preflight_fail "rtk version too old — upgrade rtk-ai/rtk"
  fi

  host="${host:-$(sb_runtime_host)}"
  if declare -f sb_rtk_platform_hook_present >/dev/null 2>&1 \
    && ! sb_rtk_platform_hook_present "${SB_ROOT:-$PWD}" "$host"; then
    enterprise_e2e_preflight_fail "RTK host hook missing for ${host} — run rtk init (see docs/RTK.md)"
  fi
  return 0
}

enterprise_e2e_preflight_context_mode() {
  local project_root="${1:-}" config_file="${2:-}" host="${3:-}" dry_run="${4:-0}"
  local platform doctor_out

  enterprise_e2e_tool_enforced_in_config "$config_file" "context_mode" || return 0

  echo "  context-mode: ${project_root} (opted in)"
  if [[ "$dry_run" == "1" ]]; then
    echo "    DRY-RUN: would verify Node >= 22.5, MCP wiring, context-mode doctor"
    return 0
  fi

  if declare -f sb_context_mode_node_ok >/dev/null 2>&1 && ! sb_context_mode_node_ok "$config_file"; then
    enterprise_e2e_preflight_fail "Node < 22.5 — upgrade before Context Mode (see docs/CONTEXT-MODE.md)"
  fi
  if ! declare -f sb_context_mode_cli_available >/dev/null 2>&1 || ! sb_context_mode_cli_available; then
    enterprise_e2e_preflight_fail "context-mode CLI/plugin missing — npm install -g context-mode"
  fi

  host="${host:-$(sb_runtime_host)}"
  if declare -f sb_context_mode_platform_artifact_present >/dev/null 2>&1 \
    && ! sb_context_mode_platform_artifact_present "$project_root" "$host"; then
    enterprise_e2e_preflight_fail "Context Mode MCP not wired for host=${host} — see docs/CONTEXT-MODE.md"
  fi

  if command -v context-mode >/dev/null 2>&1 && declare -f rtcm_doctor_platform >/dev/null 2>&1; then
    platform="$(rtcm_doctor_platform "$host")"
    if [[ -n "$platform" ]]; then
      if ! doctor_out="$(CONTEXT_MODE_PLATFORM="$platform" context-mode doctor 2>&1)"; then
        enterprise_e2e_preflight_fail "context-mode doctor failed (platform=${platform}): ${doctor_out%%$'\n'*}"
      fi
      if printf '%s' "$doctor_out" | grep -qE '(^|[[:space:]])FAIL:'; then
        enterprise_e2e_preflight_fail "context-mode doctor reported FAIL (platform=${platform}) — run: CONTEXT_MODE_PLATFORM=${platform} context-mode doctor"
      fi
      echo "    context-mode doctor OK (platform=${platform})"
    else
      echo "    WARN: no context-mode doctor platform for host=${host} — skipped"
    fi
  fi
  return 0
}

# Orchestrate opt-in checks across SB repo + fixture app.
# dry_run=1: print planned checks only (structural test path).
enterprise_e2e_code_intel_preflight() {
  local sb_root="${1:-}" fixture_dir="${2:-}" dry_run="${3:-0}"
  local host="${SILVER_BULLET_RUNTIME:-claude}"
  local config rtk_checked=0 cm_checked=0

  [[ -n "$sb_root" && -d "$sb_root" ]] || enterprise_e2e_preflight_fail "SB_ROOT missing"
  [[ -n "$fixture_dir" && -d "$fixture_dir" ]] || enterprise_e2e_preflight_fail "fixture dir missing: ${fixture_dir}"

  enterprise_e2e_source_code_intel_libs "$sb_root"
  export SB_ROOT="${sb_root}"

  echo "--- Code-intel preflight (Graphify / agentmemory / RTK / Context Mode) ---"

  for config in "${sb_root}/.silver-bullet.json" "${fixture_dir}/.silver-bullet.json"; do
    [[ -f "$config" ]] || continue
    local project_root
    if [[ "$config" == "${sb_root}/.silver-bullet.json" ]]; then
      project_root="$sb_root"
    else
      project_root="$fixture_dir"
    fi

    enterprise_e2e_preflight_graphify "$project_root" "$config" "$dry_run" || return 1
    enterprise_e2e_preflight_agentmemory "$project_root" "$config" "$host" "$dry_run" || return 1

    if [[ "$rtk_checked" -eq 0 ]] && enterprise_e2e_tool_enforced_in_config "$config" "rtk"; then
      enterprise_e2e_preflight_rtk "$config" "$host" "$dry_run" || return 1
      rtk_checked=1
    fi
    if [[ "$cm_checked" -eq 0 ]] && enterprise_e2e_tool_enforced_in_config "$config" "context_mode"; then
      enterprise_e2e_preflight_context_mode "$project_root" "$config" "$host" "$dry_run" || return 1
      cm_checked=1
    fi
  done

  if [[ "$dry_run" == "1" ]]; then
    echo "Code-intel preflight dry-run complete."
  else
    echo "Code-intel preflight OK."
  fi
  return 0
}