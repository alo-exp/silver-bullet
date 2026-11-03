#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BRIDGE="${REPO_ROOT}/hooks/cursor-hook-bridge.sh"
PASS=0 FAIL=0
assert_field() { local a; a=$(printf '%s' "$2" | jq -r "$3" 2>/dev/null); [[ "$a" == "$4" ]] && { echo "  PASS: $1"; PASS=$((PASS+1)); } || { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }; }
echo "=== cursor-hook-bridge tests ==="
stub=$(mktemp); printf '#!/bin/bash\nprintf '"'"'{"hookSpecificOutput":{"permissionDecision":"deny","permissionDecisionReason":"blocked"}}'"'"'' >"$stub"; chmod +x "$stub"
out=$(printf '{}' | "$BRIDGE" preToolUse "$stub")
assert_field "deny permission" "$out" '.permission' 'deny'
stub2=$(mktemp); printf '#!/bin/bash\nprintf '"'"'{"decision":"block","reason":"missing ship"}'"'"'' >"$stub2"; chmod +x "$stub2"
out2=$(printf '{}' | "$BRIDGE" stop "$stub2")
assert_field "stop followup" "$out2" '.followup_message' 'missing ship'
stub3=$(mktemp); printf '#!/bin/bash\nprintf '"'"'{"systemMessage":"Skill recorded"}'"'"'' >"$stub3"; chmod +x "$stub3"
out3=$(printf '{}' | "$BRIDGE" postToolUse "$stub3")
assert_field "systemMessage notice reaches Cursor as additional_context" "$out3" '.additional_context' 'Skill recorded'
out4=$(printf '{}' | "$BRIDGE" preToolUse "$stub3")
assert_field "systemMessage notice reaches Cursor preToolUse as agent_message" "$out4" '.agent_message' 'Skill recorded'
stub5=$(mktemp); printf '#!/bin/bash\nprintf '"'"'{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"REAL REASON"},"systemMessage":"just a notice"}'"'"'' >"$stub5"; chmod +x "$stub5"
out5=$(printf '{}' | "$BRIDGE" preToolUse "$stub5")
assert_field "deny + notice: still denies" "$out5" '.permission' 'deny'
assert_field "deny + notice: the agent sees the deny reason, not the notice" "$out5" '.agent_message' 'REAL REASON'
out6=$(printf '{}' | "$BRIDGE" stop "$stub3")
assert_field "stop notice is not turned into an auto-submitted followup" "$out6" '.followup_message // "none"' 'none'
rm -f "$stub" "$stub2" "$stub3" "$stub5"
echo; echo "Passed: $PASS"; echo "Failed: $FAIL"; [[ "$FAIL" -eq 0 ]]
