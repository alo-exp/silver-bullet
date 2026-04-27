#!/usr/bin/env bash
# Tests for hooks/phase-lock-claim.sh (HOOK-01).
#
# Hermetic: each test creates a temp git repo, copies the Phase 70 helper
# into it, sets SB_PHASE_LOCK_FILE so the helper writes to a temp lock
# file (not the dev's real `.planning/.phase-locks.json`), and writes
# manifest files only under `~/.claude/.silver-bullet/claimed-phases-*`
# named with $TEST_RUN_ID so concurrent test runs don't collide.
#
# Does NOT modify ~/.claude/.silver-bullet/state, ~/.claude/.silver-bullet/branch,
# or ~/.claude/.silver-bullet/trivial.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$REPO_ROOT/hooks/phase-lock-claim.sh"
HELPER_SRC="$REPO_ROOT/.planning/scripts/phase-lock.sh"

PASS=0
FAIL=0

SB_TEST_DIR="${HOME}/.claude/.silver-bullet"
mkdir -p "$SB_TEST_DIR"
TEST_RUN_ID="$$"

cleanup_all() {
  rm -f "${SB_TEST_DIR}/claimed-phases-test-${TEST_RUN_ID}.txt" \
        "${SB_TEST_DIR}/claimed-phases-test2-${TEST_RUN_ID}.txt" \
        "${SB_TEST_DIR}/claimed-phases-weird_path_name.txt" \
        "${SB_TEST_DIR}/heartbeat-099" \
        "${SB_TEST_DIR}/heartbeat-098"
  [[ -n "${TMPDIR_TEST:-}" ]] && rm -rf "$TMPDIR_TEST"
}
trap cleanup_all EXIT

setup() {
  TMPDIR_TEST=$(mktemp -d)
  cd "$TMPDIR_TEST"
  git init -q
  git config user.email t@t
  git config user.name t
  mkdir -p .planning/scripts .planning/phases/099-test
  cp "$HELPER_SRC" .planning/scripts/phase-lock.sh
  chmod +x .planning/scripts/phase-lock.sh
  export SB_PHASE_LOCK_FILE="$TMPDIR_TEST/.planning/.phase-locks.json"
  rm -f "${SB_TEST_DIR}/claimed-phases-test-${TEST_RUN_ID}.txt" \
        "${SB_TEST_DIR}/claimed-phases-test2-${TEST_RUN_ID}.txt" \
        "${SB_TEST_DIR}/claimed-phases-weird_path_name.txt"
}

teardown() {
  cd /
  rm -rf "$TMPDIR_TEST"
  unset SB_PHASE_LOCK_FILE
}

ok()   { printf '  ✓ %s\n' "$1"; PASS=$((PASS+1)); }
nope() { printf '  ✗ %s — %s\n' "$1" "$2"; FAIL=$((FAIL+1)); }

# ── Test 1: SB_PHASE_LOCK_INHERITED bypass ───────────────────────────────────
echo "--- T1: SB_PHASE_LOCK_INHERITED=true → silent exit 0, no manifest ---"
setup
out=$(SB_PHASE_LOCK_INHERITED=true \
  printf '{"tool_name":"Edit","tool_input":{"file_path":".planning/phases/099-test/x.md"},"session_id":"test-'"${TEST_RUN_ID}"'"}' \
  | SB_PHASE_LOCK_INHERITED=true bash "$HOOK" 2>&1)
rc=$?
[[ "$rc" == "0" ]] && ok "T1: exit 0 with INHERITED" || nope "T1: exit 0" "rc=$rc"
[[ -z "$out" ]] && ok "T1: silent (no stdout/stderr)" || nope "T1: silent" "got: $out"
[[ ! -f "${SB_TEST_DIR}/claimed-phases-test-${TEST_RUN_ID}.txt" ]] \
  && ok "T1: manifest NOT created" \
  || nope "T1: manifest" "exists at ${SB_TEST_DIR}/claimed-phases-test-${TEST_RUN_ID}.txt"
teardown

# ── Test 2: non-phase path is a no-op ────────────────────────────────────────
echo "--- T2: non-phase path → silent exit 0 ---"
setup
printf '{"tool_name":"Edit","tool_input":{"file_path":"/etc/passwd"}}' | bash "$HOOK" >/dev/null 2>&1
rc=$?
[[ "$rc" == "0" ]] && ok "T2: exit 0 on non-phase path" || nope "T2: exit 0" "rc=$rc"
[[ ! -f "${SB_TEST_DIR}/claimed-phases-test-${TEST_RUN_ID}.txt" ]] \
  && ok "T2: manifest NOT created" \
  || nope "T2: manifest" "should not exist"
teardown

# ── Test 3: claim-on-edit appends to manifest + helper records lock ─────────
echo "--- T3: claim under .planning/phases/099-test/ → manifest + lock ---"
setup
json=$(printf '{"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":".planning/phases/099-test/x.md"},"session_id":"test-%s"}' "$TEST_RUN_ID")
printf '%s' "$json" | bash "$HOOK" >/dev/null 2>&1
rc=$?
[[ "$rc" == "0" ]] && ok "T3: exit 0" || nope "T3: exit 0" "rc=$rc"
manifest="${SB_TEST_DIR}/claimed-phases-test-${TEST_RUN_ID}.txt"
[[ -f "$manifest" ]] && grep -qx '099' "$manifest" \
  && ok "T3: manifest contains 099" \
  || nope "T3: manifest" "missing or wrong content"
if jq -e '."099".agent_runtime == "claude"' "$SB_PHASE_LOCK_FILE" >/dev/null 2>&1; then
  ok "T3: lock file owns by runtime=claude"
else
  nope "T3: lock file" "no claude entry for 099"
fi

# ── Test 4: idempotent re-claim (no duplicate manifest line) ────────────────
echo "--- T4: re-claim same phase same session → no duplicate manifest line ---"
printf '%s' "$json" | bash "$HOOK" >/dev/null 2>&1
rc=$?
[[ "$rc" == "0" ]] && ok "T4: exit 0 on re-claim" || nope "T4: exit 0" "rc=$rc"
count=$(grep -c '^099$' "$manifest")
[[ "$count" == "1" ]] && ok "T4: manifest has exactly one '099' line" \
  || nope "T4: manifest dedup" "count=$count"
teardown

# ── Test 5: conflict exits 2 + stderr block-message ─────────────────────────
echo "--- T5: another runtime holds lock → exit 2 + stderr names owner ---"
setup
# Have forge claim phase 099 directly via helper
bash "$TMPDIR_TEST/.planning/scripts/phase-lock.sh" claim 099 forge "simulated-other-runtime" >/dev/null 2>&1

json=$(printf '{"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":".planning/phases/099-test/y.md"},"session_id":"test2-%s"}' "$TEST_RUN_ID")
set +e
stderr_capture=$(printf '%s' "$json" | bash "$HOOK" 2> >(cat) 1>/tmp/claim-stdout.$$)
rc=$?
stdout_capture=$(cat /tmp/claim-stdout.$$ 2>/dev/null)
rm -f /tmp/claim-stdout.$$
set -e

[[ "$rc" == "2" ]] && ok "T5: rc == 2 (PreToolUse block via exit-2)" || nope "T5: rc" "got $rc, expected 2"
if printf '%s' "$stderr_capture" | grep -q '099 is locked by'; then
  ok "T5: stderr contains 'phase 099 is locked by'"
else
  nope "T5: stderr conflict phrasing" "got: $stderr_capture"
fi
printf '%s' "$stderr_capture" | grep -q 'forge' \
  && ok "T5: stderr names owner runtime forge" \
  || nope "T5: forge" "stderr did not mention forge"
printf '%s' "$stderr_capture" | grep -q 'peek' \
  && ok "T5: stderr suggests peek hint" \
  || nope "T5: peek hint" "stderr did not mention peek"
if printf '%s' "$stdout_capture" | grep -q 'permissionDecision'; then
  nope "T5: no permissionDecision JSON" "stdout contained it"
else
  ok "T5: stdout does NOT contain permissionDecision (CONTEXT.md locks exit-2 path)"
fi

# Cleanup forge claim
bash "$TMPDIR_TEST/.planning/scripts/phase-lock.sh" release 099 forge >/dev/null 2>&1
teardown

# ── Test 6: jq-missing fail-open (best-effort) ──────────────────────────────
echo "--- T6: jq missing → warn-and-fail-open (best-effort) ---"
setup
jq_path=$(command -v jq)
if [[ -z "$jq_path" || "$jq_path" =~ ^/usr/bin/jq$|^/bin/jq$ ]]; then
  echo "  ~ skipped (jq is in /usr/bin or /bin — cannot strip from PATH)"
else
  rc=$( ( PATH=/usr/bin:/bin; export PATH; \
          printf '{"tool_name":"Edit","tool_input":{"file_path":".planning/phases/099-test/x.md"}}' \
          | bash "$HOOK" >/dev/null 2>&1; echo $? ) )
  [[ "$rc" == "0" ]] && ok "T6: exit 0 with jq stripped from PATH" \
    || nope "T6: jq fail-open" "rc=$rc"
fi
teardown

# ── Test 7: session-id sanitization (tr -c 'A-Za-z0-9_-' '_') ───────────────
echo "--- T7: weird session_id 'weird/path:name' → sanitized to 'weird_path_name' ---"
setup
raw='weird/path:name'
json=$(printf '{"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":".planning/phases/099-test/x.md"},"session_id":"%s"}' "$raw")
printf '%s' "$json" | bash "$HOOK" >/dev/null 2>&1
rc=$?
[[ "$rc" == "0" ]] && ok "T7: exit 0 on sanitized session id" || nope "T7: exit 0" "rc=$rc"
sanitized_manifest="${SB_TEST_DIR}/claimed-phases-weird_path_name.txt"
[[ -f "$sanitized_manifest" ]] \
  && ok "T7: manifest at sanitized path" \
  || nope "T7: sanitized manifest" "missing $sanitized_manifest"
[[ -f "$sanitized_manifest" ]] && grep -qx '099' "$sanitized_manifest" \
  && ok "T7: manifest contains '099'" \
  || nope "T7: manifest content" "no 099 line"
# Critical: no path-traversal occurred — '/' must not have created a subdir
[[ ! -d "${SB_TEST_DIR}/weird" ]] && [[ ! -e "${SB_TEST_DIR}/weird/path:name.txt" ]] \
  && ok "T7: '/' did not become a directory separator" \
  || nope "T7: traversal defense" "weird/ exists"
teardown

# ── Summary ─────────────────────────────────────────────────────────────────
echo ""
printf 'Results: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
