#!/usr/bin/env bash
# Tests session-start recommended-tools consent injection
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SESSION="$REPO_ROOT/hooks/session-start"
CURRENT_CONFIG_VERSION="$(jq -r '.config_version' "$REPO_ROOT/templates/silver-bullet.config.json.default")"
PASS=0
FAIL=0

if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat >"$TMP/silver-bullet.md" <<'EOF'
# SB
EOF

write_consent() {
  local val="$1"
  local suspended="${2:-false}"
  cat >"$TMP/.silver-bullet.json" <<EOF
{
  "config_version": "${CURRENT_CONFIG_VERSION}",
  "sb_initiated": true,
  "recommended_tools": {
    "graphify": {
      "enabled_by_user": ${val},
      "enforcement_suspended": ${suspended}
    }
  },
  "skills": { "required_planning": ["silver-quality-gates"] },
  "state": {
    "state_file": "${SB_RUNTIME_STATE_DIR}/session-rt-test-state",
    "trivial_file": "${SB_RUNTIME_STATE_DIR}/session-rt-test-trivial"
  }
}
EOF
}

run_session() {
  (cd "$TMP" && export SILVER_BULLET_SESSION_SOURCE=startup && printf '{"source":"startup"}' | bash "$SESSION" 2>/dev/null)
}

extract_ctx() {
  jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null || true
}

echo "=== session-start recommended-tools tests ==="

write_consent null
out="$(run_session)"
ctx="$(printf '%s' "$out" | extract_ctx)"
printf '%s' "$ctx" | grep -q 'CONSENT PENDING' && pass "pending consent injects prompt" || fail "pending consent injects prompt"

write_consent false
out="$(run_session)"
ctx="$(printf '%s' "$out" | extract_ctx)"
printf '%s' "$ctx" | grep -q 'opted out' && pass "disabled consent injects opted-out note" || fail "disabled consent injects opted-out note"

write_consent true
out="$(run_session)"
ctx="$(printf '%s' "$out" | extract_ctx)"
# enabled + no CLI should mention install
printf '%s' "$ctx" | grep -qi 'graphify' && pass "enabled consent injects graphify status" || fail "enabled consent injects graphify status"

write_consent true true
out="$(run_session)"
ctx="$(printf '%s' "$out" | extract_ctx)"
printf '%s' "$ctx" | grep -q 'enforcement suspended' && pass "suspended opt-in injects suspension note" || fail "suspended opt-in injects suspension note"

# Fresh init template always defaults enabled_by_user to null (pending)
template_null="$(jq -r '.recommended_tools.graphify.enabled_by_user' "$REPO_ROOT/templates/silver-bullet.config.json.default")"
[[ "$template_null" == "null" ]] && pass "fresh init template defaults to null pending" || fail "fresh init template defaults to null pending"

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] || exit 1
