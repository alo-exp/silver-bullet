#!/usr/bin/env bash
# Tests for hooks/lib/rtk-compat.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
COMPAT_LIB="$REPO_ROOT/hooks/lib/rtk-compat.sh"
PASS=0
FAIL=0
MOCK_BIN=""
TMP_CONFIG=""
TMP_OPTED_OUT=""

cleanup() {
  rm -rf "$MOCK_BIN" "$TMP_CONFIG" "$TMP_OPTED_OUT"
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

reset_compat_env() {
  unset SILVER_BULLET RTK_DISABLED SB_RTK_COMPAT_ENABLED SILVER_BULLET_HOOK_EXEC \
    SB_RTK_COMPAT_MODE 2>/dev/null || true
}

# --- Default mode (RTK not opted in) ---
reset_compat_env
TMP_OPTED_OUT="$(mktemp -d)"
cat >"$TMP_OPTED_OUT/.silver-bullet.json" <<'EOF'
{"recommended_tools":{"rtk":{"enabled_by_user":false}}}
EOF
touch "$TMP_OPTED_OUT/silver-bullet.md"
export SILVER_BULLET_PROJECT_ROOT="$TMP_OPTED_OUT"
# shellcheck source=hooks/lib/rtk-compat.sh
source "$COMPAT_LIB"
assert_eq "opted-out project exports RTK_DISABLED=1" "1" "${RTK_DISABLED:-}"

# --- Verbatim mode (harness scripts) ---
reset_compat_env
export SB_RTK_COMPAT_MODE=verbatim
# shellcheck source=hooks/lib/rtk-compat.sh
source "$COMPAT_LIB"
assert_eq "verbatim mode exports RTK_DISABLED=1" "1" "${RTK_DISABLED:-}"

# --- Opted-in mode (mock project config) ---
TMP_CONFIG="$(mktemp -d)"
cat >"$TMP_CONFIG/.silver-bullet.json" <<'EOF'
{"recommended_tools":{"rtk":{"enabled_by_user":true,"enforcement_suspended":false}}}
EOF
touch "$TMP_CONFIG/silver-bullet.md"

reset_compat_env
export SILVER_BULLET_PROJECT_ROOT="$TMP_CONFIG"
# shellcheck source=hooks/lib/rtk-compat.sh
source "$COMPAT_LIB"
if [[ -z "${RTK_DISABLED:-}" ]]; then
  PASS=$((PASS + 1))
  printf 'PASS: opted-in mode omits RTK_DISABLED\n'
else
  FAIL=$((FAIL + 1))
  printf 'FAIL: opted-in mode should omit RTK_DISABLED (got %q)\n' "${RTK_DISABLED:-}"
fi

# Nested git inside SB script context should bypass RTK filters when verbatim.
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

# sb_rtk_compat_verbatim helper
reset_compat_env
export SILVER_BULLET_PROJECT_ROOT="$TMP_CONFIG"
# shellcheck source=hooks/lib/rtk-compat.sh
source "$COMPAT_LIB"
sb_rtk_compat_verbatim
assert_eq "sb_rtk_compat_verbatim sets RTK_DISABLED" "1" "${RTK_DISABLED:-}"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
