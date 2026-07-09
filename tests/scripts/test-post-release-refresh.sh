#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if printf '%s' "$haystack" | grep -qF -- "$needle"; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — missing [$needle]"
    (( FAIL++ )) || true
  fi
}

SCRIPT="$(cd "$(dirname "$0")/../.." && pwd)/scripts/post-release-refresh.sh"
VERIFY_SCRIPT="$(cd "$(dirname "$0")/../.." && pwd)/scripts/post-release-host-verify.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

STUB_VERIFY="$TMP/post-release-host-verify.sh"
VERIFY_LOG="$TMP/verify.log"
cat > "$STUB_VERIFY" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" > "${VERIFY_LOG}"
exit 0
EOF
chmod +x "$STUB_VERIFY"

SB_POST_RELEASE_VERIFY_SCRIPT="$STUB_VERIFY" bash "$SCRIPT" --version v9.9.9 --host cursor >/dev/null

assert_contains "refresh delegates to verify script" "post-release-host-verify" "$(<"$SCRIPT")"
[[ -f "$VERIFY_LOG" ]] && echo "PASS: stub verify invoked" && (( PASS++ )) || { echo "FAIL: stub verify not invoked"; (( FAIL++ )) || true; }
assert_contains "refresh forwards args" "--version v9.9.9" "$(cat "$VERIFY_LOG")"
assert_contains "refresh forwards host arg" "--host cursor" "$(cat "$VERIFY_LOG")"
[[ -x "$VERIFY_SCRIPT" ]] && echo "PASS: verify script executable" && (( PASS++ )) || { echo "FAIL: verify script not executable"; (( FAIL++ )) || true; }

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
