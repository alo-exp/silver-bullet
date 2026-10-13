#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=hooks/lib/recommended-tools-registry.sh
source "$REPO_ROOT/hooks/lib/recommended-tools-registry.sh"

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "=== recommended-tools registry ==="

ids="$(sb_recommended_tool_ids | tr '\n' ' ')"
[[ "$ids" == *graphify* ]] && pass "registry includes graphify" || fail "registry includes graphify"
[[ "$ids" == *agentmemory* ]] && pass "registry includes agentmemory" || fail "registry includes agentmemory"
[[ "$ids" == *alumnium* ]] && pass "registry includes alumnium" || fail "registry includes alumnium"
[[ "$ids" == *rtk* ]] && pass "registry includes rtk" || fail "registry includes rtk"
[[ "$ids" == *context_mode* ]] && pass "registry includes context_mode" || fail "registry includes context_mode"

TEMPLATE="$REPO_ROOT/templates/silver-bullet.config.json.default"
for tool_id in graphify agentmemory alumnium rtk context_mode; do
  if jq -e --arg id "$tool_id" '.recommended_tools[$id]' "$TEMPLATE" >/dev/null 2>&1; then
    pass "template defines recommended_tools.${tool_id}"
  else
    fail "template defines recommended_tools.${tool_id}"
  fi
done

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] || exit 1
