#!/usr/bin/env bash
# Tests for hooks/lib/rtk-compat.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
COMPAT_LIB="$REPO_ROOT/hooks/lib/rtk-compat.sh"
PASS=0
FAIL=0
MOCK_BIN=""

cleanup() {
  rm -rf "$MOCK_BIN"
}
trap cleanup EXIT

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    PASS=$((PASS + 1))
    printf 'PASS: %s\n' "$label"
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL: %s (expected %q, got %q)\n' "$label" "$expected" "$actual"
  fi
}

# Hermetic mock: CI runners may not ship RTK; behavior under test is the bypass contract.
MOCK_BIN="$(mktemp -d)"
cat >"$MOCK_BIN/rtk" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "hook" && "${2:-}" == "cursor" ]]; then
  input="$(cat)"
  if [[ "$input" == *"RTK_DISABLED=1"* ]]; then
    printf '%s' '{}'
    exit 0
  fi
  printf '%s' '{"updatedInput":{"command":"rtk git status"}}'
  exit 0
fi
if [[ "${1:-}" == "git" ]]; then
  exec git "${@:2}"
fi
exit 1
EOF
chmod +x "$MOCK_BIN/rtk"
export PATH="$MOCK_BIN:$PATH"

unset SILVER_BULLET RTK_DISABLED SB_RTK_COMPAT_ENABLED SILVER_BULLET_HOOK_EXEC 2>/dev/null || true
# shellcheck source=hooks/lib/rtk-compat.sh
source "$COMPAT_LIB"

assert_eq "exports SILVER_BULLET=1" "1" "${SILVER_BULLET:-}"
assert_eq "exports RTK_DISABLED=1" "1" "${RTK_DISABLED:-}"
assert_eq "idempotent guard" "1" "${SB_RTK_COMPAT_ENABLED:-}"

# Nested git inside SB script context should bypass RTK filters.
if RTK_DISABLED=1 rtk git status >/dev/null 2>&1; then
  PASS=$((PASS + 1))
  printf 'PASS: RTK_DISABLED=1 runs native git status\n'
else
  FAIL=$((FAIL + 1))
  printf 'FAIL: RTK_DISABLED=1 git status exited non-zero\n'
fi

# RTK hook should not rewrite when RTK_DISABLED=1 is in the command.
hook_out="$(printf '%s' '{"tool_name":"Shell","tool_input":{"command":"RTK_DISABLED=1 git status"}}' | rtk hook cursor 2>/dev/null || true)"
if [[ "$hook_out" == "{}" ]]; then
  PASS=$((PASS + 1))
  printf 'PASS: rtk hook cursor skips rewrite for RTK_DISABLED=1 prefix\n'
else
  FAIL=$((FAIL + 1))
  printf 'FAIL: rtk hook cursor should return {} for RTK_DISABLED=1 prefix (got %s)\n' "$hook_out"
fi

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
