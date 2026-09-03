#!/usr/bin/env bash
set -euo pipefail
MAIN="/Users/shafqat/projects/silver-bullet/repo"
LOG="${MAIN}/.e2e-r9-pilot-rows-6-11-sequential.log"
SB_ROOT="/private/tmp/sb-main-row11-fp"
_ISO_CFG="${MAIN}/.planning/enterprise-e2e/.r9-claude-config"
export CLAUDE_CONFIG_DIR="$_ISO_CFG" CLAUDE_SETTINGS_FILE="$_ISO_CFG/settings.json"
# shellcheck disable=SC1091
source "${MAIN}/.planning/enterprise-e2e/.r9-pilot-rows-1-6-11-sequential.sh" 2>/dev/null || true
