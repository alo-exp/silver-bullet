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

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=scripts/lib/claude-matrix-auth.sh
source "${REPO_ROOT}/scripts/lib/claude-matrix-auth.sh"

TMP_HOME="$(mktemp -d)"
trap 'rm -rf "$TMP_HOME"' EXIT
export HOME="$TMP_HOME"
mkdir -p "${HOME}/.claude"
cat > "${HOME}/.claude/settings.json" <<'EOF'
{
  "env": {
    "ANTHROPIC_API_KEY": "sk-test-matrix-key",
    "ANTHROPIC_BASE_URL": "https://api.example.test/anthropic",
    "CUSTOM_MATRIX_FLAG": "enabled"
  }
}
EOF

claude_matrix_export_settings_env
assert_eq "exports ANTHROPIC_API_KEY from settings" "sk-test-matrix-key" "${ANTHROPIC_API_KEY:-}"

lines="$(claude_matrix_auth_env_lines)"
assert_eq "auth env lines include API key" "1" "$(printf '%s\n' "$lines" | grep -c '^ANTHROPIC_API_KEY=' || true)"
assert_eq "exports ANTHROPIC_BASE_URL from settings" "https://api.example.test/anthropic" "${ANTHROPIC_BASE_URL:-}"
assert_eq "exports other settings env keys" "enabled" "${CUSTOM_MATRIX_FLAG:-}"

unset ANTHROPIC_API_KEY ANTHROPIC_BASE_URL CUSTOM_MATRIX_FLAG
cat > "${HOME}/.claude/settings.json" <<'EOF'
{
  "env": {
    "API_TIMEOUT_MS": "3000000"
  }
}
EOF
claude_matrix_export_settings_env
assert_eq "skips export when settings lack API keys" "" "${ANTHROPIC_API_KEY:-}"

echo ""
echo "Summary: ${PASS} passed, ${FAIL} failed"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
