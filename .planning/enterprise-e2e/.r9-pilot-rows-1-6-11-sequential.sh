#!/usr/bin/env bash
# R9 sequential single-row pilots: 1 → (PASS) 6 → (PASS) 11
set -euo pipefail
MAIN="/Users/shafqat/projects/silver-bullet/repo"
SB_ROOT="/private/tmp/sb-main-row11-fp"
LOG="${MAIN}/.e2e-r9-pilot-rows-1-6-11-sequential.log"
PIDFILE="${MAIN}/.e2e-r9-pilot-rows-1-6-11.pid"
_ISO_CFG="${MAIN}/.planning/enterprise-e2e/.r9-claude-config"

export CLAUDE_CONFIG_DIR="$_ISO_CFG"
export CLAUDE_SETTINGS_FILE="$_ISO_CFG/settings.json"
if [[ -f "$_ISO_CFG/settings.json" ]]; then
  ANTHROPIC_BASE_URL="$(jq -r '.env.ANTHROPIC_BASE_URL // empty' "$_ISO_CFG/settings.json")"
  [[ -n "$ANTHROPIC_BASE_URL" && "$ANTHROPIC_BASE_URL" != null ]] && export ANTHROPIC_BASE_URL
  _api_key="$(jq -r '.env.ANTHROPIC_API_KEY // empty' "$_ISO_CFG/settings.json")"
  if [[ "$_api_key" == "PROXY_MANAGED" && -f "${HOME}/.codex/settings.json" ]]; then
    _api_key="$(jq -r '.env.ANTHROPIC_API_KEY // empty' "${HOME}/.codex/settings.json")"
  fi
  [[ -n "$_api_key" && "$_api_key" != null && "$_api_key" != "PROXY_MANAGED" ]] && export ANTHROPIC_API_KEY="$_api_key"
fi

_install_log="${SB_ROOT}/.e2e-install-claude.log"
if ! grep -qE 'Claude marketplaces registered|Claude marketplace refreshed' "$_install_log" 2>/dev/null; then
  (cd "$SB_ROOT" && bash scripts/install-claude.sh </dev/null) 2>&1 | tee -a "$_install_log"
fi

rm -f "${SB_ROOT}/.e2e-live-test.lock"
printf '%s\n' "$$" >"$PIDFILE"

export SB_ROOT SB_E2E_MAIN_REPO="$MAIN"
export SB_TEST_ENTERPRISE_APP_ROOT=/Users/shafqat/projects/enterprise-grade-test-app-round9-claude
mkdir -p "${SB_TEST_ENTERPRISE_APP_ROOT}/.agentmemory/memory"
export SB_E2E_TEST_APP_BRANCH=enterprise-e2e/round-9-claude
export SB_E2E_TEST_APP_BASELINE_SHA=8482e60
export SB_E2E_TEST_APP_EXCLUDE_ANCESTOR=
export SB_E2E_PRODUCT_WORK_GATE=1
export SB_ENTERPRISE_E2E_LIVE=1 SB_E2E_LIVE_RUNTIME=claude SILVER_BULLET_RUNTIME=claude
export SB_E2E_SURFACE_SKIP=0 SB_E2E_MATRIX_FORCE=1 SB_E2E_ISOLATED_CLAUDE_CONFIG=1
export SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT=0
export CLAUDE_INTERACTIVE_CUSTOM_API_KEY_STRATEGY=keys CLAUDE_INTERACTIVE_BYPASS_STRATEGY=arrow CLAUDE_MODEL=sonnet
export SB_E2E_WORKFLOW_QUIET_TIMEOUT=1200 CLAUDE_INTERACTIVE_QUIET_TIMEOUT=1200 CLAUDE_INTERACTIVE_READY_TIMEOUT=600 CLAUDE_INTERACTIVE_TIMEOUT=2400 RTK_DISABLED=1
export SB_E2E_MONITOR_AUTO_RESTART=0 SB_E2E_MATRIX_MONITOR=0
export SB_E2E_LEDGER_FILE="${MAIN}/.planning/enterprise-e2e/ROUND-9-LEDGER.md"
export SB_E2E_MATRIX_LOG="$LOG"
export SB_E2E_LEDGER_NO_UX_APPEND=1

exec >>"$LOG" 2>&1
echo "=== R9 sequential pilots 1→6→11 $(date -u +%Y-%m-%dT%H:%M:%SZ) pid=$$ commit=$(git -C "$MAIN" rev-parse --short HEAD) ==="
cd "$SB_ROOT"
source "${SB_ROOT}/scripts/lib/enterprise-e2e-live-common.sh"
enterprise_e2e_export_live_defaults
enterprise_e2e_prepare_matrix_mcp_env "$SB_TEST_ENTERPRISE_APP_ROOT" || true
echo "SB_RUNTIME_STATE_DIR=${SB_RUNTIME_STATE_DIR:-unset}"

row_passed() {
  local n="$1"
  local slice
  slice="$(awk -v n="$n" '
    /^=== Row [0-9]+:/ {
      rid = $0
      sub(/^=== Row /, "", rid)
      sub(/:.*$/, "", rid)
      if (rid == n) { buf = ""; collecting = 1 }
      else if (collecting) { collecting = 0 }
      next
    }
    /^=== PILOT row/ {
      if (collecting) { collecting = 0 }
      next
    }
    collecting { buf = buf $0 ORS }
    END { printf "%s", buf }
  ' "$LOG" 2>/dev/null || true)"
  if printf '%s
' "$slice" | grep -q "  FAIL:"; then
    return 1
  fi
  if printf '%s
' "$slice" | grep -q "OUTCOMES: all applicable criteria pass"; then
    return 0
  fi
  if printf '%s
' "$slice" | grep -q "  PASS: evidence at"; then
    return 0
  fi
  return 1
}

run_row() {
  local n="$1"
  echo "=== PILOT row ${n} start $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
  local rc=0
  bash scripts/run-enterprise-e2e-live-test.sh "$n" || rc=$?
  echo "=== PILOT row ${n} finished rc=${rc} $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
  return "$rc"
}

FINAL_RC=0
for row in 1 6 11; do
  if ! run_row "$row"; then
    echo "=== STOP chain: row ${row} harness rc!=0 ==="
    FINAL_RC=1
    break
  fi
  if ! row_passed "$row"; then
    echo "=== STOP chain: row ${row} matrix FAIL in log ==="
    FINAL_RC=1
    break
  fi
  echo "=== row ${row} PASS — continuing ==="
done
echo "=== sequential pilots done rc=${FINAL_RC} $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
exit "$FINAL_RC"
