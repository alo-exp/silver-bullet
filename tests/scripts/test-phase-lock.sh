#!/usr/bin/env bash
# Unit tests for .planning/scripts/phase-lock.sh — covers LOCK-05 cases plus
# SB_PHASE_LOCK_INHERITED no-op semantics (forward-compat for AGENT-04).
#
# All tests are hermetic: SB_PHASE_LOCK_FILE points into a tempdir; the real
# .planning/.phase-locks.json is never touched.

set -euo pipefail
PASS=0; FAIL=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then echo "PASS: $desc"; (( PASS++ )) || true
  else echo "FAIL: $desc"; echo "  expected: [$expected]"; echo "  actual:   [$actual]"; (( FAIL++ )) || true; fi
}

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if printf '%s' "$haystack" | grep -q "$needle"; then echo "PASS: $desc"; (( PASS++ )) || true
  else echo "FAIL: $desc — looking for: [$needle]"; echo "  in: [$haystack]"; (( FAIL++ )) || true; fi
}

assert_json_key() {
  local desc="$1" key="$2" output="$3"
  if printf '%s' "$output" | jq -e "$key" > /dev/null 2>&1; then echo "PASS: $desc"; (( PASS++ )) || true
  else echo "FAIL: $desc — key $key not found in JSON"; echo "  json: [$output]"; (( FAIL++ )) || true; fi
}

assert_true() {
  local desc="$1" cond="$2"
  if [[ "$cond" == "true" ]]; then echo "PASS: $desc"; (( PASS++ )) || true
  else echo "FAIL: $desc"; (( FAIL++ )) || true; fi
}

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="${REPO_ROOT}/.planning/scripts/phase-lock.sh"
[[ -x "$SCRIPT" ]] || { echo "FAIL: phase-lock.sh not found or not executable at $SCRIPT"; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Helper expects a planning dir at the parent of the lock file. Provide one.
mkdir -p "$TMP/.planning"
LOCK_FILE="$TMP/.planning/locks.json"
export SB_PHASE_LOCK_FILE="$LOCK_FILE"
export SB_DEFAULT_CONFIG="${REPO_ROOT}/templates/silver-bullet.config.json.default"

reset_lock() {
  rm -f "$LOCK_FILE" "$LOCK_FILE.lock"
  rm -rf "$LOCK_FILE.lock.d"
}

peek() { "$SCRIPT" peek "$1" 2>/dev/null; }

# ---------------------------------------------------------------------------
# Test 1 — claim-when-free (LOCK-05 case 1)
# ---------------------------------------------------------------------------
reset_lock
if "$SCRIPT" claim 070 claude "test intent" >/dev/null 2>&1; then
  echo "PASS: claim-when-free returns 0"; (( PASS++ )) || true
else
  echo "FAIL: claim-when-free should exit 0"; (( FAIL++ )) || true
fi
[[ -f "$LOCK_FILE" ]] && { echo "PASS: lock file created on claim"; (( PASS++ )) || true; } \
                     || { echo "FAIL: lock file not created"; (( FAIL++ )) || true; }
assert_json_key "claim wrote correct shape" \
  '."070".agent_runtime == "claude" and ."070".intent == "test intent"' \
  "$(cat "$LOCK_FILE")"

# ---------------------------------------------------------------------------
# Test 2 — claim-when-held-by-other (LOCK-05 case 2)
# ---------------------------------------------------------------------------
err_out=$("$SCRIPT" claim 070 forge "intrusion" 2>&1 1>/dev/null) && rc=0 || rc=$?
assert_eq "claim-when-held-by-other exits 2" "2" "$rc"
assert_contains "stderr identifies it is locked by prior owner" "locked by" "$err_out"
assert_json_key "lock unchanged after rejected claim" \
  '."070".agent_runtime == "claude"' "$(cat "$LOCK_FILE")"

# ---------------------------------------------------------------------------
# Test 3 — heartbeat-extends-ttl (LOCK-05 case 3)
# ---------------------------------------------------------------------------
before_hb=$(jq -r '."070".last_heartbeat_at' "$LOCK_FILE")
before_claim=$(jq -r '."070".claimed_at' "$LOCK_FILE")
sleep 1
"$SCRIPT" heartbeat 070 claude >/dev/null 2>&1 && rc=0 || rc=$?
assert_eq "heartbeat exits 0 when owned" "0" "$rc"
after_hb=$(jq -r '."070".last_heartbeat_at' "$LOCK_FILE")
after_claim=$(jq -r '."070".claimed_at' "$LOCK_FILE")
if [[ "$before_hb" != "$after_hb" ]]; then
  echo "PASS: heartbeat updates last_heartbeat_at"; (( PASS++ )) || true
else
  echo "FAIL: heartbeat did not update last_heartbeat_at (before=$before_hb after=$after_hb)"
  (( FAIL++ )) || true
fi
assert_eq "heartbeat does not change claimed_at" "$before_claim" "$after_claim"

# ---------------------------------------------------------------------------
# Test 4 — release-by-non-owner (LOCK-05 case 4)
# ---------------------------------------------------------------------------
err_out=$("$SCRIPT" release 070 forge 2>&1 1>/dev/null) && rc=0 || rc=$?
assert_eq "release-by-non-owner exits 2" "2" "$rc"
assert_contains "release-by-non-owner stderr says cannot release" "cannot release" "$err_out"
assert_json_key "lock still present after rejected release" '."070"' "$(cat "$LOCK_FILE")"

# ---------------------------------------------------------------------------
# Test 5 — release-by-owner cleans up (preparation for stale-lock test)
# ---------------------------------------------------------------------------
"$SCRIPT" release 070 claude >/dev/null 2>&1 && rc=0 || rc=$?
assert_eq "release-by-owner exits 0" "0" "$rc"
out=$(peek 070)
assert_eq "after release, peek returns empty" "" "$out"
"$SCRIPT" release 070 claude >/dev/null 2>&1 && rc=0 || rc=$?
assert_eq "release on free phase is no-op exit 0" "0" "$rc"

# ---------------------------------------------------------------------------
# Test 6 — stale-lock-steal (LOCK-05 case 5)
# ---------------------------------------------------------------------------
reset_lock
"$SCRIPT" claim 070 claude "to-be-stolen" >/dev/null 2>&1
# Force last_heartbeat_at older than TTL (1800s) + 1
old_epoch=$(($(date -u +%s) - 1801))
old_iso=$(date -u -r "$old_epoch" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
          || date -u -d "@$old_epoch" +%Y-%m-%dT%H:%M:%SZ)
jq --arg t "$old_iso" '."070".last_heartbeat_at = $t' "$LOCK_FILE" > "$LOCK_FILE.tmp" \
  && mv "$LOCK_FILE.tmp" "$LOCK_FILE"
err_out=$("$SCRIPT" claim 070 forge "stealer" 2>&1 1>/dev/null) && rc=0 || rc=$?
assert_eq "stale-lock claim exits 0 (steals)" "0" "$rc"
assert_contains "stale-lock claim emits WARN: stealing stale lock" "WARN: stealing stale lock" "$err_out"
assert_json_key "lock now owned by forge" \
  '."070".agent_runtime == "forge" and ."070".intent == "stealer"' \
  "$(cat "$LOCK_FILE")"

# Bonus: peek on stale lock includes expired:true
jq --arg t "$old_iso" '."070".last_heartbeat_at = $t' "$LOCK_FILE" > "$LOCK_FILE.tmp" \
  && mv "$LOCK_FILE.tmp" "$LOCK_FILE"
peek_out=$("$SCRIPT" peek 070)
assert_json_key "peek on stale lock has expired:true" '.expired == true' "$peek_out"

# ---------------------------------------------------------------------------
# Test 7 — peek-returns-empty-for-free-phase (LOCK-05 case 6)
# ---------------------------------------------------------------------------
reset_lock
out=$("$SCRIPT" peek 071)
rc=$?
assert_eq "peek on free phase exits 0" "0" "$rc"
assert_eq "peek on free phase returns empty stdout" "" "$out"

# ---------------------------------------------------------------------------
# Test 8 — atomicity under 10 parallel claims (LOCK-05 case 7)
# ---------------------------------------------------------------------------
reset_lock
successes=0
conflicts=0
other=0
rcs_dir=$(mktemp -d)
pids=()
for i in $(seq 1 10); do
  # Subshell inherits `set -e` from parent; capture rc explicitly so a non-zero
  # exit from the helper does NOT short-circuit before `echo $? > $rcs_dir/$i`.
  ( set +e; "$SCRIPT" claim 070 claude "race-$i" >/dev/null 2>&1; rc=$?; echo "$rc" > "$rcs_dir/$i" ) &
  pids+=($!)
done
for p in "${pids[@]}"; do wait "$p" || true; done
for i in $(seq 1 10); do
  rc=$(cat "$rcs_dir/$i")
  if [[ "$rc" == "0" ]]; then successes=$((successes+1))
  elif [[ "$rc" == "2" ]]; then conflicts=$((conflicts+1))
  else other=$((other+1)); fi
done
rm -rf "$rcs_dir"
if [[ "$successes" == "1" ]]; then
  echo "PASS: 10-way parallel atomicity — exactly 1 success"; (( PASS++ )) || true
else
  echo "FAIL: atomicity: expected 1 success, got $successes (conflicts=$conflicts other=$other)"
  (( FAIL++ )) || true
fi
if [[ "$conflicts" == "9" ]]; then
  echo "PASS: 10-way parallel atomicity — exactly 9 conflicts"; (( PASS++ )) || true
else
  echo "FAIL: atomicity: expected 9 conflicts, got $conflicts (successes=$successes other=$other)"
  (( FAIL++ )) || true
fi

# ---------------------------------------------------------------------------
# Test 9 — SB_PHASE_LOCK_INHERITED no-op for claim/heartbeat/release; peek still works
# ---------------------------------------------------------------------------
reset_lock
err_out=$(SB_PHASE_LOCK_INHERITED=true "$SCRIPT" claim 999 claude "noop" 2>&1 1>/dev/null) && rc=0 || rc=$?
assert_eq "SB_PHASE_LOCK_INHERITED=true claim exits 0" "0" "$rc"
assert_contains "SB_PHASE_LOCK_INHERITED=true claim INFO line" "INFO: phase-lock claim skipped" "$err_out"
[[ ! -f "$LOCK_FILE" ]] && { echo "PASS: SB_PHASE_LOCK_INHERITED=true claim does not mutate file"; (( PASS++ )) || true; } \
                       || { echo "FAIL: SB_PHASE_LOCK_INHERITED=true claim created lock file"; (( FAIL++ )) || true; }

err_out=$(SB_PHASE_LOCK_INHERITED=true "$SCRIPT" heartbeat 999 claude 2>&1 1>/dev/null) && rc=0 || rc=$?
assert_eq "SB_PHASE_LOCK_INHERITED=true heartbeat exits 0" "0" "$rc"
assert_contains "SB_PHASE_LOCK_INHERITED=true heartbeat INFO line" "INFO: phase-lock heartbeat skipped" "$err_out"

err_out=$(SB_PHASE_LOCK_INHERITED=true "$SCRIPT" release 999 claude 2>&1 1>/dev/null) && rc=0 || rc=$?
assert_eq "SB_PHASE_LOCK_INHERITED=true release exits 0" "0" "$rc"
assert_contains "SB_PHASE_LOCK_INHERITED=true release INFO line" "INFO: phase-lock release skipped" "$err_out"
[[ ! -f "$LOCK_FILE" ]] && { echo "PASS: SB_PHASE_LOCK_INHERITED=true release does not create file"; (( PASS++ )) || true; } \
                       || { echo "FAIL: SB_PHASE_LOCK_INHERITED=true release created file"; (( FAIL++ )) || true; }

# peek must still work even with SB_PHASE_LOCK_INHERITED set
"$SCRIPT" claim 999 claude "real" >/dev/null 2>&1
peek_inh_out=$(SB_PHASE_LOCK_INHERITED=true "$SCRIPT" peek 999)
assert_json_key "peek works with SB_PHASE_LOCK_INHERITED=true" \
  '.agent_runtime == "claude" and .intent == "real"' "$peek_inh_out"
"$SCRIPT" release 999 claude >/dev/null 2>&1

# ---------------------------------------------------------------------------
# Test 10 — unknown runtime rejected (LOCK-03 boundary)
# ---------------------------------------------------------------------------
reset_lock
err_out=$("$SCRIPT" claim 070 bogusruntime "test" 2>&1 1>/dev/null) && rc=0 || rc=$?
assert_eq "unknown runtime exits 3" "3" "$rc"
assert_contains "unknown runtime stderr" "unknown runtime" "$err_out"

# ---------------------------------------------------------------------------
# Test 11 — phase normalization (`70` and `070` are equivalent)
# ---------------------------------------------------------------------------
reset_lock
"$SCRIPT" claim 70 claude "padded" >/dev/null 2>&1 && rc=0 || rc=$?
assert_eq "claim with phase=70 exits 0" "0" "$rc"
out_padded=$("$SCRIPT" peek 070)
out_unpadded=$("$SCRIPT" peek 70)
[[ -n "$out_padded" ]] && { echo "PASS: peek 070 finds lock claimed as 70"; (( PASS++ )) || true; } \
                       || { echo "FAIL: peek 070 returned empty after claim 70"; (( FAIL++ )) || true; }
[[ -n "$out_unpadded" ]] && { echo "PASS: peek 70 finds lock claimed as 70"; (( PASS++ )) || true; } \
                         || { echo "FAIL: peek 70 returned empty after claim 70"; (( FAIL++ )) || true; }
"$SCRIPT" release 070 claude >/dev/null 2>&1

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
