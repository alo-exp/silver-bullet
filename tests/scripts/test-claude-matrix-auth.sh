#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $desc — expected [$expected], got [$actual]"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $desc — missing [$needle]"
    FAIL=$((FAIL + 1))
  fi
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=scripts/lib/claude-matrix-auth.sh
source "${REPO_ROOT}/scripts/lib/claude-matrix-auth.sh"

TMP_HOME="$(mktemp -d)"
trap 'rm -rf "$TMP_HOME"' EXIT
export HOME="$TMP_HOME"
mkdir -p "${HOME}/.codex"
cat > "${HOME}/.codex/settings.json" <<'EOF'
{
  "env": {
    "ANTHROPIC_API_KEY": "sk-test-matrix-key",
    "ANTHROPIC_BASE_URL": "https://api.example.test/anthropic",
    "CUSTOM_MATRIX_FLAG": "enabled"
  }
}
EOF


export SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT=1
unset ANTHROPIC_API_KEY ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN CUSTOM_MATRIX_FLAG 2>/dev/null || true
claude_matrix_export_settings_env
assert_eq "skip export when SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT=1" "" "${ANTHROPIC_API_KEY:-}"
unset SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT

claude_matrix_export_settings_env
assert_eq "exports ANTHROPIC_API_KEY from settings" "sk-test-matrix-key" "${ANTHROPIC_API_KEY:-}"

lines="$(claude_matrix_auth_env_lines)"
assert_eq "auth env lines include API key" "1" "$(printf '%s\n' "$lines" | grep -c '^ANTHROPIC_API_KEY=' || true)"
assert_eq "exports ANTHROPIC_BASE_URL from settings" "https://api.example.test/anthropic" "${ANTHROPIC_BASE_URL:-}"
assert_eq "exports other settings env keys" "enabled" "${CUSTOM_MATRIX_FLAG:-}"

unset ANTHROPIC_API_KEY ANTHROPIC_BASE_URL CUSTOM_MATRIX_FLAG
cat > "${HOME}/.codex/settings.json" <<'EOF'
{
  "env": {
    "API_TIMEOUT_MS": "3000000"
  }
}
EOF
claude_matrix_export_settings_env
assert_eq "skips export when settings lack API keys" "" "${ANTHROPIC_API_KEY:-}"

# Shell env fallback for spawn when settings export is skipped.
export SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT=1
export ANTHROPIC_API_KEY="sk-shell-fallback-key"
export ANTHROPIC_BASE_URL="https://api.example.test/shell"
lines="$(claude_matrix_auth_env_lines)"
assert_eq "auth env lines include shell API key when export skipped" "1" "$(printf '%s\n' "$lines" | grep -c '^ANTHROPIC_API_KEY=sk-shell-fallback-key$' || true)"
assert_eq "auth env lines include shell base URL when export skipped" "1" "$(printf '%s\n' "$lines" | grep -c '^ANTHROPIC_BASE_URL=https://api.example.test/shell$' || true)"

# Enterprise matrix runner forces export on (ignores inherited SKIP=1).
MATRIX="${REPO_ROOT}/scripts/enterprise-e2e/matrix.sh"
MATRIX_SRC="$(<"$MATRIX")"
assert_contains "enterprise matrix forces settings export on" "$MATRIX_SRC" 'export SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT=0'
assert_contains "enterprise matrix arrow strategy for api key disclaimer" "$MATRIX_SRC" 'CLAUDE_INTERACTIVE_CUSTOM_API_KEY_STRATEGY="${CLAUDE_INTERACTIVE_CUSTOM_API_KEY_STRATEGY:-arrow}"'

echo ""
echo "Summary: ${PASS} passed, ${FAIL} failed"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
