#!/usr/bin/env bash
# Fixture-based tests for optimize-rtk-context-mode.sh and merge helper.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

TEST_HOME="$(mktemp -d)"
trap 'rm -rf "$TEST_HOME"' EXIT

export HOME="$TEST_HOME"
mkdir -p "$TEST_HOME/.cursor"

echo "=== optimize-rtk-context-mode tests ==="

# 1. Script exists and is executable
if [[ -x "$REPO_ROOT/scripts/optimize-rtk-context-mode.sh" ]]; then
  pass "optimize script executable"
else
  fail "optimize script executable"
fi

# 2. Dry-run completes
if bash "$REPO_ROOT/scripts/optimize-rtk-context-mode.sh" --host cursor --dry-run --skip-rtk-init --skip-cm-doctor >/dev/null 2>&1; then
  pass "dry-run exits 0"
else
  fail "dry-run exits 0"
fi

# 3. Merge helper adds CM hooks idempotently
python3 "$REPO_ROOT/scripts/lib/merge-token-compression-config.py" \
  --host cursor --repo-root "$REPO_ROOT" >/dev/null

if grep -q 'context-mode hook cursor pretooluse' "$TEST_HOME/.cursor/hooks.json" 2>/dev/null; then
  pass "merge adds context-mode pretooluse hook"
else
  fail "merge adds context-mode pretooluse hook"
fi

python3 "$REPO_ROOT/scripts/lib/merge-token-compression-config.py" \
  --host cursor --repo-root "$REPO_ROOT" >/dev/null
count="$(grep -c 'context-mode hook cursor pretooluse' "$TEST_HOME/.cursor/hooks.json" || true)"
[[ "$count" -eq 1 ]] && pass "merge is idempotent (no duplicate pretooluse)" || fail "merge is idempotent (no duplicate pretooluse)"

# 4. Allow-list merge
if [[ -f "$TEST_HOME/.cursor/cli-config.json" ]]; then
  allow_count="$(jq '.permissions.allow | length' "$TEST_HOME/.cursor/cli-config.json")"
  [[ "$allow_count" -ge 50 ]] && pass "cli-config allow-list merged ($allow_count entries)" || fail "cli-config allow-list merged"
else
  fail "cli-config created"
fi

# 5. Extended hooks (sessionStart, afterAgentResponse)
grep -q 'context-mode hook cursor sessionstart' "$TEST_HOME/.cursor/hooks.json" \
  && pass "sessionStart hook merged" || fail "sessionStart hook merged"
grep -q 'context-mode hook cursor afteragentresponse' "$TEST_HOME/.cursor/hooks.json" \
  && pass "afterAgentResponse hook merged" || fail "afterAgentResponse hook merged"

# 6. Template config has optimize flags
jq -e '.recommended_tools.rtk.optimize_on_init == true' \
  "$REPO_ROOT/templates/silver-bullet.config.json.default" >/dev/null \
  && pass "template rtk optimize_on_init" || fail "template rtk optimize_on_init"
jq -e '.recommended_tools.context_mode.optimize_script | test("optimize-rtk-context-mode")' \
  "$REPO_ROOT/templates/silver-bullet.config.json.default" >/dev/null \
  && pass "template context_mode optimize_script" || fail "template context_mode optimize_script"

# 7. Docs reference optimization script
grep -q 'optimize-rtk-context-mode' "$REPO_ROOT/docs/RTK.md" \
  && pass "RTK.md references optimize script" || fail "RTK.md references optimize script"
grep -q 'optimize-rtk-context-mode' "$REPO_ROOT/docs/CONTEXT-MODE.md" \
  && pass "CONTEXT-MODE.md references optimize script" || fail "CONTEXT-MODE.md references optimize script"

# 8. Allowlist JSON valid
jq -e '.allow | length > 0' "$REPO_ROOT/scripts/lib/cursor-cli-allowlist.json" >/dev/null \
  && pass "cursor-cli-allowlist.json valid" || fail "cursor-cli-allowlist.json valid"

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] || exit 1
