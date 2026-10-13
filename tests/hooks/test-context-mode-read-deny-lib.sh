#!/usr/bin/env bash
# Unit tests for hooks/lib/context-mode-read-deny.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$REPO_ROOT/hooks/lib/context-mode-read-deny.sh"
PASS=0
FAIL=0
TMP=""

cleanup() {
  rm -rf "$TMP"
}
trap cleanup EXIT

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# shellcheck source=hooks/lib/context-mode-read-deny.sh
source "$LIB"

TMP="$(mktemp -d)"
TMPCFG="${TMP}/.silver-bullet.json"
cat >"$TMPCFG" <<'EOF'
{
  "recommended_tools": {
    "context_mode": {
      "read_deny_bytes": 5120
    }
  },
  "state": {
    "state_file": "/tmp/sb-test-state",
    "trivial_file": "/tmp/sb-test-trivial"
  }
}
EOF

[[ "$(sb_context_mode_read_deny_bytes "$TMPCFG")" == "5120" ]] && pass "default threshold from config" || fail "default threshold from config"

SMALL="${TMP}/small.txt"
BIG="${TMP}/big.txt"
printf 'x' >"$SMALL"
python3 - "$BIG" <<'PY'
import pathlib
import sys
path = pathlib.Path(sys.argv[1])
path.write_text("x" * 6000)
PY

[[ "$(sb_context_mode_file_size_bytes "$SMALL")" == "1" ]] && pass "small file size" || fail "small file size"
[[ "$(sb_context_mode_file_size_bytes "$BIG")" -gt 5120 ]] && pass "big file size" || fail "big file size"

sb_context_mode_read_path_is_exempt "${TMP}/.silver-bullet.json" "$TMPCFG" && pass "config path exempt" || fail "config path exempt"
sb_context_mode_read_path_is_exempt "$BIG" "$TMPCFG" && fail "regular file not exempt" || pass "regular file not exempt"

read_input=$(jq -n --arg f "$BIG" '{tool_name:"Read", tool_input:{file_path:$f}}')
if deny_path="$(sb_context_mode_should_deny_read "$read_input" "$TMPCFG" "$TMP" 2>/dev/null)"; then
  [[ "$deny_path" == "$(sb_context_mode_resolve_read_path "$BIG" "$TMP")" ]] && pass "deny large read" || fail "deny large read"
else
  fail "deny large read"
fi

read_small=$(jq -n --arg f "$SMALL" '{tool_name:"Read", tool_input:{file_path:$f}}')
if sb_context_mode_should_deny_read "$read_small" "$TMPCFG" "$TMP" >/dev/null 2>&1; then
  fail "allow small read"
else
  pass "allow small read"
fi

cat >"${TMP}/.silver-bullet.json" <<'EOF'
{"x":1}
EOF
sb_context_mode_read_path_is_exempt "${TMP}/.silver-bullet.json" "$TMPCFG" && pass "silver-bullet.json exempt" || fail "silver-bullet.json exempt"

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] || exit 1
