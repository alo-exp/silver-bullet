#!/usr/bin/env bash
# tests/integration/test-multi-agent-coexistence.sh
#
# v0.29.0 multi-agent coordination integration tests:
#   TEST-01 — Coexistence smoke: two-agent race for the same phase.
#             Agent A (claude) claims; agent B (forge) is told to wait;
#             A releases; B claims successfully.
#   TEST-02 — Stale-lock recovery: A claims, mocks last_heartbeat_at to
#             be older than TTL, B peeks (sees expired:true), B claims
#             (steals), warning emitted on stderr.
#   TEST-03 — Delegation envelope semantics: parent claims, child runs
#             with SB_PHASE_LOCK_INHERITED=true, claim/heartbeat/release
#             agents short-circuit to ALLOW (no double-claim verified
#             via lock-state JSON unchanged across child operations).
#
# Hermetic: each test creates a temp git repo, copies the Phase 70 helper,
# sets SB_PHASE_LOCK_FILE so writes don't pollute the dev's real state.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HELPER_SRC="$REPO_ROOT/.planning/scripts/phase-lock.sh"

PASS=0
FAIL=0

cleanup_all() {
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
}

teardown() {
  cd /
  rm -rf "$TMPDIR_TEST"
  unset SB_PHASE_LOCK_FILE
}

ok()   { printf '  ✓ %s\n' "$1"; PASS=$((PASS+1)); }
nope() { printf '  ✗ %s — %s\n' "$1" "$2"; FAIL=$((FAIL+1)); }

# ── TEST-01: Coexistence smoke ─────────────────────────────────────────────
echo "=== TEST-01: two-agent race for same phase ==="
setup

helper="./.planning/scripts/phase-lock.sh"

# A (claude) claims phase 099
out=$($helper claim 099 claude "agent-A-task" 2>&1); rc=$?
[[ "$rc" == "0" ]] && ok "TEST-01.1: claude claims phase 099 (rc=0)" \
  || nope "TEST-01.1: claude claim" "rc=$rc out=$out"

# B (forge) attempts claim — should be told to wait (rc=2)
out=$($helper claim 099 forge "agent-B-task" 2>&1); rc=$?
[[ "$rc" == "2" ]] && ok "TEST-01.2: forge claim rejected with rc=2" \
  || nope "TEST-01.2: forge claim" "expected rc=2, got rc=$rc"
if printf '%s' "$out" | grep -q '099 is locked by'; then
  ok "TEST-01.3: forge stderr names current claude owner"
else
  nope "TEST-01.3: forge stderr" "$out"
fi

# B peeks → should see claude lock with agent_runtime=claude
peek_json=$($helper peek 099 2>/dev/null)
runtime=$(printf '%s' "$peek_json" | jq -r '.agent_runtime')
[[ "$runtime" == "claude" ]] && ok "TEST-01.4: peek reports agent_runtime=claude" \
  || nope "TEST-01.4: peek runtime" "got '$runtime'"

# A releases
$helper release 099 claude >/dev/null 2>&1; rc=$?
[[ "$rc" == "0" ]] && ok "TEST-01.5: claude releases (rc=0)" \
  || nope "TEST-01.5: release" "rc=$rc"

# B claims now succeeds
out=$($helper claim 099 forge "agent-B-task-retry" 2>&1); rc=$?
[[ "$rc" == "0" ]] && ok "TEST-01.6: forge claims after release (rc=0)" \
  || nope "TEST-01.6: forge retry claim" "rc=$rc out=$out"
runtime=$(jq -r '."099".agent_runtime' "$SB_PHASE_LOCK_FILE")
[[ "$runtime" == "forge" ]] && ok "TEST-01.7: lock file shows forge ownership after handoff" \
  || nope "TEST-01.7: handoff state" "got '$runtime'"

teardown

# ── TEST-02: Stale-lock recovery ───────────────────────────────────────────
echo ""
echo "=== TEST-02: stale-lock TTL steal ==="
setup

helper="./.planning/scripts/phase-lock.sh"

# A claims
$helper claim 099 claude "stale-test" >/dev/null 2>&1
# Mock last_heartbeat_at to be 2 hours ago (well beyond default 1800s TTL)
old_iso=$(date -u -v-2H '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u -d '2 hours ago' '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null)
[[ -n "$old_iso" ]] || old_iso="2020-01-01T00:00:00Z"
jq --arg old "$old_iso" '."099".last_heartbeat_at = $old' "$SB_PHASE_LOCK_FILE" \
  > "$SB_PHASE_LOCK_FILE.new" && mv "$SB_PHASE_LOCK_FILE.new" "$SB_PHASE_LOCK_FILE"

# B peeks → should see expired:true
peek_json=$($helper peek 099 2>/dev/null)
expired=$(printf '%s' "$peek_json" | jq -r '.expired // false')
[[ "$expired" == "true" ]] && ok "TEST-02.1: peek reports expired:true on stale lock" \
  || nope "TEST-02.1: stale peek" "got '$expired' from $peek_json"

# B claims (should steal with WARN on stderr)
stderr_out=$($helper claim 099 forge "steal-test" 2>&1 >/dev/null); rc=$?
[[ "$rc" == "0" ]] && ok "TEST-02.2: forge stale-steal exits 0" \
  || nope "TEST-02.2: stale steal rc" "rc=$rc"
if printf '%s' "$stderr_out" | grep -qiE 'WARN|stealing|stale'; then
  ok "TEST-02.3: stderr mentions stale-steal (WARN)"
else
  nope "TEST-02.3: stale-steal stderr" "$stderr_out"
fi

# After steal, lock is owned by forge with fresh heartbeat
runtime=$(jq -r '."099".agent_runtime' "$SB_PHASE_LOCK_FILE")
[[ "$runtime" == "forge" ]] && ok "TEST-02.4: lock now owned by forge after steal" \
  || nope "TEST-02.4: post-steal owner" "got '$runtime'"

teardown

# ── TEST-03: Delegation envelope — SB_PHASE_LOCK_INHERITED short-circuit ──
echo ""
echo "=== TEST-03: SB_PHASE_LOCK_INHERITED prevents double-claim ==="
setup

helper="./.planning/scripts/phase-lock.sh"

# Parent (claude) claims
$helper claim 099 claude "parent-claim" >/dev/null 2>&1
parent_state_before=$(cat "$SB_PHASE_LOCK_FILE")

# Child runs with SB_PHASE_LOCK_INHERITED=true and tries operations:
# All should short-circuit to exit 0 without changing the lock file.
SB_PHASE_LOCK_INHERITED=true $helper claim 099 forge "child-claim" >/dev/null 2>&1; rc1=$?
SB_PHASE_LOCK_INHERITED=true $helper heartbeat 099 forge >/dev/null 2>&1; rc2=$?
SB_PHASE_LOCK_INHERITED=true $helper release 099 forge >/dev/null 2>&1; rc3=$?

[[ "$rc1" == "0" ]] && ok "TEST-03.1: child claim short-circuits to rc=0" || nope "TEST-03.1: child claim" "rc=$rc1"
[[ "$rc2" == "0" ]] && ok "TEST-03.2: child heartbeat short-circuits to rc=0" || nope "TEST-03.2: child heartbeat" "rc=$rc2"
[[ "$rc3" == "0" ]] && ok "TEST-03.3: child release short-circuits to rc=0" || nope "TEST-03.3: child release" "rc=$rc3"

# Most importantly: lock file is UNCHANGED (no double-claim, no release)
parent_state_after=$(cat "$SB_PHASE_LOCK_FILE")
if [[ "$parent_state_before" == "$parent_state_after" ]]; then
  ok "TEST-03.4: lock file unchanged across child operations (no double-claim)"
else
  nope "TEST-03.4: lock file mutated by child" "before=$parent_state_before after=$parent_state_after"
fi

# Hook scripts (Phase 71) also honor SB_PHASE_LOCK_INHERITED — verify they too no-op
# under env. (We don't have the hook scripts in this temp dir, but we test
# the helper-level contract here; hook-level tests live in tests/hooks/.)
runtime=$(jq -r '."099".agent_runtime' "$SB_PHASE_LOCK_FILE")
[[ "$runtime" == "claude" ]] && ok "TEST-03.5: parent's claude lock still owns the phase" \
  || nope "TEST-03.5: parent ownership" "got '$runtime'"

# Parent peeks normally (peek is the one op SB_PHASE_LOCK_INHERITED does NOT
# short-circuit — confirms the contract from Phase 70)
SB_PHASE_LOCK_INHERITED=true peek_json=$($helper peek 099 2>/dev/null)
runtime_peek=$(printf '%s' "$peek_json" | jq -r '.agent_runtime')
[[ "$runtime_peek" == "claude" ]] && ok "TEST-03.6: peek works even under SB_PHASE_LOCK_INHERITED=true" \
  || nope "TEST-03.6: peek under inheritance" "got '$runtime_peek'"

teardown

# ── Summary ────────────────────────────────────────────────────────────────
echo ""
printf 'Results: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
