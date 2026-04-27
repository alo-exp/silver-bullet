#!/usr/bin/env bash
# Tests for hooks/phase-lock-release.sh (HOOK-03).

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$REPO_ROOT/hooks/phase-lock-release.sh"
HELPER_SRC="$REPO_ROOT/.planning/scripts/phase-lock.sh"

PASS=0
FAIL=0

SB_TEST_DIR="${HOME}/.claude/.silver-bullet"
mkdir -p "$SB_TEST_DIR"
TEST_RUN_ID="$$"
MANIFEST="${SB_TEST_DIR}/claimed-phases-test-${TEST_RUN_ID}.txt"

cleanup_all() {
  rm -f "$MANIFEST" \
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
  mkdir -p .planning/scripts
  cp "$HELPER_SRC" .planning/scripts/phase-lock.sh
  chmod +x .planning/scripts/phase-lock.sh
  export SB_PHASE_LOCK_FILE="$TMPDIR_TEST/.planning/.phase-locks.json"
  rm -f "$MANIFEST"
}

teardown() {
  cd /
  rm -rf "$TMPDIR_TEST"
  unset SB_PHASE_LOCK_FILE
}

ok()   { printf '  ✓ %s\n' "$1"; PASS=$((PASS+1)); }
nope() { printf '  ✗ %s — %s\n' "$1" "$2"; FAIL=$((FAIL+1)); }

# ── T1: SB_PHASE_LOCK_INHERITED bypass ──────────────────────────────────────
echo "--- T1: INHERITED → silent exit 0, no manifest deletion ---"
setup
printf 'dummy-line\n' > "$MANIFEST"
out=$(SB_PHASE_LOCK_INHERITED=true printf '{"session_id":"test-%s"}' "$TEST_RUN_ID" \
  | SB_PHASE_LOCK_INHERITED=true bash "$HOOK" 2>&1)
rc=$?
[[ "$rc" == "0" ]] && ok "T1: exit 0" || nope "T1: exit 0" "rc=$rc"
[[ -z "$out" ]] && ok "T1: silent" || nope "T1: silent" "got: $out"
[[ -f "$MANIFEST" ]] && ok "T1: manifest NOT deleted (inherited skips work)" \
  || nope "T1: manifest preservation" "deleted unexpectedly"
rm -f "$MANIFEST"
teardown

# ── T2: no manifest → silent no-op ──────────────────────────────────────────
echo "--- T2: no manifest → silent exit 0 ---"
setup
printf '{"hook_event_name":"Stop","session_id":"missing"}' | bash "$HOOK" >/dev/null 2>&1
rc=$?
[[ "$rc" == "0" ]] && ok "T2: exit 0 with no manifest" || nope "T2: exit 0" "rc=$rc"
teardown

# ── T3: release each manifest entry, manifest deleted ──────────────────────
echo "--- T3: manifest with two entries → both released, manifest deleted ---"
setup
# Claim 099 + 098 as claude
bash "$TMPDIR_TEST/.planning/scripts/phase-lock.sh" claim 099 claude "test" >/dev/null 2>&1
bash "$TMPDIR_TEST/.planning/scripts/phase-lock.sh" claim 098 claude "test" >/dev/null 2>&1
printf '099\n098\n' > "$MANIFEST"
printf '{"hook_event_name":"Stop","session_id":"test-%s"}' "$TEST_RUN_ID" \
  | bash "$HOOK" >/dev/null 2>&1
rc=$?
[[ "$rc" == "0" ]] && ok "T3: exit 0" || nope "T3: exit 0" "rc=$rc"
if jq -e '."099" == null and ."098" == null' "$SB_PHASE_LOCK_FILE" >/dev/null 2>&1; then
  ok "T3: both 099 and 098 released from lock file"
else
  nope "T3: lock release" "$(cat "$SB_PHASE_LOCK_FILE")"
fi
[[ ! -f "$MANIFEST" ]] && ok "T3: manifest deleted after release" \
  || nope "T3: manifest cleanup" "still exists"
teardown

# ── T4: non-owner does not abort the loop ──────────────────────────────────
echo "--- T4: 099 owned by forge, 098 by claude → continues, 098 released, manifest deleted ---"
setup
bash "$TMPDIR_TEST/.planning/scripts/phase-lock.sh" claim 099 forge  "owned-by-forge"  >/dev/null 2>&1
bash "$TMPDIR_TEST/.planning/scripts/phase-lock.sh" claim 098 claude "owned-by-claude" >/dev/null 2>&1
printf '099\n098\n' > "$MANIFEST"
out=$(printf '{"hook_event_name":"Stop","session_id":"test-%s"}' "$TEST_RUN_ID" \
  | bash "$HOOK" 2>&1)
rc=$?
[[ "$rc" == "0" ]] && ok "T4: exit 0 (Stop must NEVER block)" || nope "T4: exit 0" "rc=$rc"
if jq -e '."098" == null' "$SB_PHASE_LOCK_FILE" >/dev/null 2>&1; then
  ok "T4: 098 released (claude owned it)"
else
  nope "T4: 098 release" "still in lock file"
fi
if jq -e '."099".agent_runtime == "forge"' "$SB_PHASE_LOCK_FILE" >/dev/null 2>&1; then
  ok "T4: 099 still owned by forge (claude could not release)"
else
  nope "T4: 099 forge ownership" "$(cat "$SB_PHASE_LOCK_FILE")"
fi
[[ ! -f "$MANIFEST" ]] && ok "T4: manifest deleted (cleanup safety)" \
  || nope "T4: manifest cleanup" "still exists"
# Cleanup forge claim
bash "$TMPDIR_TEST/.planning/scripts/phase-lock.sh" release 099 forge >/dev/null 2>&1
teardown

# ── Summary ─────────────────────────────────────────────────────────────────
echo ""
printf 'Results: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
