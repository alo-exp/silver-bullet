#!/usr/bin/env bash
# Canonical R9 pilot row 3 driver (single instance — do not duplicate).
set -euo pipefail
MAIN="/Users/shafqat/projects/silver-bullet/repo"
LOG="${MAIN}/.e2e-r9-pilot-row3-live.log"
PIDFILE="${MAIN}/.e2e-r9-pilot-row3.pid"
SB_ROOT="/private/tmp/sb-main-row11-fp"

_ISO_CFG="${MAIN}/.planning/enterprise-e2e/.r9-claude-config"
export CLAUDE_CONFIG_DIR="$_ISO_CFG"
export CLAUDE_SETTINGS_FILE="$_ISO_CFG/settings.json"
export CLAUDE_INTERACTIVE_CUSTOM_API_KEY_STRATEGY=keys
if [[ -f "$_ISO_CFG/settings.json" ]]; then
  ANTHROPIC_BASE_URL="$(jq -r '.env.ANTHROPIC_BASE_URL // empty' "$_ISO_CFG/settings.json")"
  [[ -n "$ANTHROPIC_BASE_URL" && "$ANTHROPIC_BASE_URL" != null ]] && export ANTHROPIC_BASE_URL
  _api_key="$(jq -r '.env.ANTHROPIC_API_KEY // empty' "$_ISO_CFG/settings.json")"
  if [[ "$_api_key" == "PROXY_MANAGED" && -f "${HOME}/.codex/settings.json" ]]; then
    _api_key="$(jq -r '.env.ANTHROPIC_API_KEY // empty' "${HOME}/.codex/settings.json")"
  fi
  [[ -n "$_api_key" && "$_api_key" != null && "$_api_key" != "PROXY_MANAGED" ]] && export ANTHROPIC_API_KEY="$_api_key"
fi


# Synchronous plugin install (detached nohup drivers hang on marketplace-add without TTY).
_install_log="${SB_ROOT}/.e2e-install-claude.log"
if ! grep -qE 'Claude marketplaces registered|Claude marketplace refreshed' "$_install_log" 2>/dev/null; then
  echo "Plugin pre-install (synchronous):"
  (cd "$SB_ROOT" && bash scripts/install-claude.sh </dev/null) 2>&1 | tee -a "$_install_log"
fi

rm -f "${SB_ROOT}/.e2e-live-test.lock"
printf '%s\n' "$$" >"$PIDFILE"

export SB_ROOT
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
export SB_E2E_MONITOR_AUTO_RESTART=0
export SB_E2E_MATRIX_MONITOR=0
export SB_E2E_LEDGER_FILE="${MAIN}/.planning/enterprise-e2e/ROUND-9-LEDGER.md"
export SB_E2E_MATRIX_LOG="$LOG"

exec >>"$LOG" 2>&1
echo "=== pilot row3 launch inner $(date -u +%Y-%m-%dT%H:%M:%SZ) pid=$$ ==="
cd "$SB_ROOT"
bash scripts/run-enterprise-e2e-live-test.sh 3
rc=$?
echo "=== pilot row3 finished rc=$rc $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
exit $rc
