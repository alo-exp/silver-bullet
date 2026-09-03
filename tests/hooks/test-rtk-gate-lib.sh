#!/usr/bin/env bash
# Unit tests for hooks/lib/rtk-gate.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$REPO_ROOT/hooks/lib/rtk-gate.sh"
PASS=0
FAIL=0
MOCK_BIN=""
TEST_HOME=""

cleanup() {
  rm -rf "$MOCK_BIN" "$TEST_HOME"
}
trap cleanup EXIT

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# shellcheck source=hooks/lib/rtk-gate.sh
source "$LIB"

MOCK_BIN="$(mktemp -d)"
cat >"$MOCK_BIN/rtk" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then echo "rtk 0.42.4"; exit 0; fi
if [[ "${1:-}" == "gain" ]]; then exit 0; fi
exit 0
EOF
chmod +x "$MOCK_BIN/rtk"
export PATH="$MOCK_BIN:/usr/bin:/bin"

sb_rtk_cli_available && pass "mock rtk cli available" || fail "mock rtk cli available"
sb_rtk_version_ok "" && pass "version ok for 0.42.4" || fail "version ok for 0.42.4"

cat >"$MOCK_BIN/rtk-bad" <<'EOF'
#!/usr/bin/env bash
echo "Rust Type Kit"
exit 1
EOF
chmod +x "$MOCK_BIN/rtk-bad"
sb_rtk_is_wrong_binary "$MOCK_BIN/rtk-bad" && pass "detects wrong binary help" || fail "detects wrong binary help"

TEST_HOME="$(mktemp -d)"
mkdir -p "$TEST_HOME/.cursor"
printf '{"hooks":[{"command":"rtk hook cursor"}]}\n' >"$TEST_HOME/.cursor/hooks.json"
export HOME="$TEST_HOME" SILVER_BULLET_RUNTIME=cursor
sb_rtk_platform_hook_present "$REPO_ROOT" cursor && pass "cursor hook present" || fail "cursor hook present"

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] || exit 1
