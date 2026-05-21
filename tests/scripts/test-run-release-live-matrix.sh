#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

assert_equals() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — expected [$expected], got [$actual]"
    (( FAIL++ )) || true
  fi
}

SCRIPT="$(cd "$(dirname "$0")/../.." && pwd)/scripts/run-release-live-matrix.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

captured_pwd="$TMP/captured-pwd"
stub_script="$TMP/release-live-matrix-stub.sh"

cat > "$stub_script" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s' "$PWD" > "$1"
EOF
chmod +x "$stub_script"

SB_RELEASE_LIVE_MATRIX_CMD="bash '$stub_script' '$captured_pwd'" \
  bash "$SCRIPT" >/dev/null

assert_equals "wrapper runs configured command from repo root" \
  "$(cd "$(dirname "$SCRIPT")/.." && pwd)" \
  "$(cat "$captured_pwd")"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
