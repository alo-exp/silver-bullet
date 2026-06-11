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

assert_passes() {
  local desc="$1"
  shift
  if "$@"; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc"
    (( FAIL++ )) || true
  fi
}

assert_fails() {
  local desc="$1"
  shift
  if "$@"; then
    echo "FAIL: $desc"
    (( FAIL++ )) || true
  else
    echo "PASS: $desc"
    (( PASS++ )) || true
  fi
}

SCRIPT="$(cd "$(dirname "$0")/../.." && pwd)/scripts/run-release-live-matrix.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

captured_pwd="$TMP/captured-pwd"
stub_script="$TMP/release-live-matrix-stub.sh"
home_dir="$TMP/home"
verify_marker="$home_dir/.codex/.silver-bullet/verify-tests-state"

cat > "$stub_script" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s' "$PWD" > "$1"
rm -f -- "$2"
EOF
chmod +x "$stub_script"

mkdir -p "$(dirname "$verify_marker")"
cat > "$verify_marker" <<'EOF'
verified_at=2026-06-11T00:00:00Z
repo_root=/tmp/example
commands:
  - bash tests/run-all-tests.sh
EOF

HOME="$home_dir" \
SILVER_BULLET_RUNTIME=codex \
SB_RELEASE_LIVE_MATRIX_CMD="bash '$stub_script' '$captured_pwd' '$verify_marker'" \
  bash "$SCRIPT" >/dev/null

assert_equals "wrapper runs configured command from repo root" \
  "$(cd "$(dirname "$SCRIPT")/.." && pwd)" \
  "$(cat "$captured_pwd")"
assert_passes "wrapper restores verify-tests marker after configured command" \
  test -f "$verify_marker"
assert_fails "wrapper blocks when verify-tests marker is missing" \
  env HOME="$TMP/missing-home" SILVER_BULLET_RUNTIME=codex SB_RELEASE_LIVE_MATRIX_CMD="bash '$stub_script' '$captured_pwd' '$verify_marker'" bash "$SCRIPT"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
