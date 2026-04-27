#!/usr/bin/env bash
# Tests for hooks/phase-lock-heartbeat.sh (HOOK-02).

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$REPO_ROOT/hooks/phase-lock-heartbeat.sh"
HELPER_SRC="$REPO_ROOT/.planning/scripts/phase-lock.sh"

PASS=0
FAIL=0

SB_TEST_DIR="${HOME}/.claude/.silver-bullet"
mkdir -p "$SB_TEST_DIR"
TEST_RUN_ID="$$"
MANIFEST="${SB_TEST_DIR}/claimed-phases-test-${TEST_RUN_ID}.txt"
THROTTLE="${SB_TEST_DIR}/heartbeat-099"

cleanup_all() {
  rm -f "$MANIFEST" "$THROTTLE" "${SB_TEST_DIR}/heartbeat-098"
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
  rm -f "$MANIFEST" "$THROTTLE" "${SB_TEST_DIR}/heartbeat-098"
}

teardown() {
  cd /
  rm -rf "$TMPDIR_TEST"
  unset SB_PHASE_LOCK_FILE
}

ok()   { printf '  ✓ %s\n' "$1"; PASS=$((PASS+1)); }
nope() { printf '  ✗ %s — %s\n' "$1" "$2"; FAIL=$((FAIL+1)); }

# ── T1: SB_PHASE_LOCK_INHERITED bypass ──────────────────────────────────────
echo "--- T1: INHERITED → silent exit 0, no throttle file ---"
setup
out=$(SB_PHASE_LOCK_INHERITED=true printf '{"session_id":"x"}' \
  | SB_PHASE_LOCK_INHERITED=true bash "$HOOK" 2>&1)
rc=$?
[[ "$rc" == "0" ]] && ok "T1: exit 0" || nope "T1: exit 0" "rc=$rc"
[[ -z "$out" ]] && ok "T1: silent" || nope "T1: silent" "got: $out"
[[ ! -f "$THROTTLE" ]] && ok "T1: throttle NOT created" || nope "T1: throttle" "exists"
teardown

# ── T2: no manifest → silent no-op ──────────────────────────────────────────
echo "--- T2: no manifest → silent exit 0 ---"
setup
printf '{"session_id":"missing"}' | bash "$HOOK" >/dev/null 2>&1
rc=$?
[[ "$rc" == "0" ]] && ok "T2: exit 0 with no manifest" || nope "T2: exit 0" "rc=$rc"
teardown

# ── T3: heartbeat fires when throttle stale ─────────────────────────────────
echo "--- T3: throttle stale (missing) → helper called, throttle refreshed ---"
setup
# Claim 099 as claude via helper directly
bash "$TMPDIR_TEST/.planning/scripts/phase-lock.sh" claim 099 claude "test" >/dev/null 2>&1
printf '099\n' > "$MANIFEST"
rm -f "$THROTTLE"  # explicitly stale = absent
hb_before=$(jq -r '."099".last_heartbeat_at' "$SB_PHASE_LOCK_FILE")
sleep 1
printf '{"session_id":"test-%s","tool_name":"Bash","tool_input":{"command":"true"}}' "$TEST_RUN_ID" \
  | bash "$HOOK" >/dev/null 2>&1
rc=$?
[[ "$rc" == "0" ]] && ok "T3: exit 0" || nope "T3: exit 0" "rc=$rc"
[[ -f "$THROTTLE" && ! -L "$THROTTLE" ]] && ok "T3: throttle file refreshed" || nope "T3: throttle" "missing"
hb_after=$(jq -r '."099".last_heartbeat_at' "$SB_PHASE_LOCK_FILE")
[[ "$hb_after" != "$hb_before" ]] \
  && ok "T3: lock last_heartbeat_at advanced" \
  || nope "T3: heartbeat advance" "before=$hb_before after=$hb_after"
# release
bash "$TMPDIR_TEST/.planning/scripts/phase-lock.sh" release 099 claude >/dev/null 2>&1
teardown

# ── T4: heartbeat throttled when fresh ──────────────────────────────────────
echo "--- T4: throttle fresh (mtime within 300s) → helper NOT called ---"
setup
bash "$TMPDIR_TEST/.planning/scripts/phase-lock.sh" claim 099 claude "test" >/dev/null 2>&1
printf '099\n' > "$MANIFEST"
touch "$THROTTLE"  # fresh mtime
hb_before=$(jq -r '."099".last_heartbeat_at' "$SB_PHASE_LOCK_FILE")
sleep 1
printf '{"session_id":"test-%s"}' "$TEST_RUN_ID" | bash "$HOOK" >/dev/null 2>&1
rc=$?
[[ "$rc" == "0" ]] && ok "T4: exit 0 (throttled)" || nope "T4: exit 0" "rc=$rc"
hb_after=$(jq -r '."099".last_heartbeat_at' "$SB_PHASE_LOCK_FILE")
[[ "$hb_after" == "$hb_before" ]] \
  && ok "T4: lock last_heartbeat_at UNCHANGED (helper not called)" \
  || nope "T4: throttled call" "lock advanced — throttle didn't suppress"
bash "$TMPDIR_TEST/.planning/scripts/phase-lock.sh" release 099 claude >/dev/null 2>&1
teardown

# ── T5: helper not-owned does not block ─────────────────────────────────────
echo "--- T5: manifest entry not owned by claude → warn but exit 0 ---"
setup
# Have forge claim 098 — manifest says we (claude) want to heartbeat 098 but don't own it
bash "$TMPDIR_TEST/.planning/scripts/phase-lock.sh" claim 098 forge "owned-by-forge" >/dev/null 2>&1
printf '098\n' > "$MANIFEST"
rm -f "${SB_TEST_DIR}/heartbeat-098"
out=$(printf '{"session_id":"test-%s"}' "$TEST_RUN_ID" | bash "$HOOK" 2>&1)
rc=$?
[[ "$rc" == "0" ]] && ok "T5: exit 0 even on non-owner" || nope "T5: exit 0" "rc=$rc"
# Stderr may contain warning — non-blocking is the contract
bash "$TMPDIR_TEST/.planning/scripts/phase-lock.sh" release 098 forge >/dev/null 2>&1
teardown

# ── Summary ─────────────────────────────────────────────────────────────────
echo ""
printf 'Results: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
