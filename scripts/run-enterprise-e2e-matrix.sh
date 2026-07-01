#!/usr/bin/env bash
# Backward-compatible wrapper — delegates to shared harness matrix runner.
#
# Enterprise matrix contract (implemented in scripts/enterprise-e2e/matrix.sh):
#   export SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT=0
#   CLAUDE_INTERACTIVE_CUSTOM_API_KEY_STRATEGY="${CLAUDE_INTERACTIVE_CUSTOM_API_KEY_STRATEGY:-arrow}"
#   SB_E2E_MATRIX_QUOTA_RETRY_INTERVAL — quota retry interval (default 60)
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/enterprise-e2e/matrix.sh" "$@"
