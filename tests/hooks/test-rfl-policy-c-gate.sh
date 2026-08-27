#!/usr/bin/env bash
# hooks/rfl-policy-c-gate.sh + stop-check deny vs allow for active RFL Policy C.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="${REPO_ROOT}/hooks/rfl-policy-c-gate.sh"
STOP="${REPO_ROOT}/hooks/stop-check.sh"
RESOLVER="${REPO_ROOT}/scripts/review-fix-ladder.py"

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

is_denied() {
  local output="$1"
  [[ -n "$output" ]] && printf '%s' "$output" | grep -qE '"permissionDecision"[[:space:]]*:[[:space:]]*"deny"|"decision"[[:space:]]*:[[:space:]]*"block"'
}

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/rfl-policy-c-gate.XXXXXX")"
trap 'rm -rf "$WORKDIR"' EXIT

mkdir -p "$WORKDIR/scripts" "$WORKDIR/.planning/rfl-live/rung-01-cursor-glm-5.2-high"
ln -sf "$RESOLVER" "$WORKDIR/scripts/review-fix-ladder.py"
printf '# Silver Bullet test\n' >"$WORKDIR/silver-bullet.md"
cat >"$WORKDIR/.silver-bullet.json" <<'EOF'
{
  "sb_initiated": true,
  "state": {"state_file": "/tmp/sb-rfl-policy-c-gate-state"}
}
EOF

RUN="$WORKDIR/.planning/rfl-live"
RUNG="$RUN/rung-01-cursor-glm-5.2-high"

run_hook() {
  local event="$1" tool="$2" json="$3"
  (cd "$WORKDIR" && printf '%s' "$json" | env SB_RFL_POLICY_C_GATE=1 SILVER_BULLET_RUNTIME=cursor bash "$HOOK" 2>/dev/null)
}

# inactive: no LADDER-STATUS
out="$(run_hook PreToolUse Task '{"hook_event_name":"PreToolUse","tool_name":"Task","tool_input":{"prompt":"rung_2_review next"}}')"
if is_denied "$out"; then
  fail "inactive run does not deny Task"
else
  pass "inactive run does not deny Task"
fi

printf '%s\n' '{"status":"active","current_rung":"rung-01-cursor-glm-5.2-high","current_phase":"rung_01_review"}' >"$RUN/LADDER-STATUS.json"
printf '# findings\n' >"$RUNG/review.md"

out="$(run_hook PreToolUse Task "$(jq -n '{hook_event_name:"PreToolUse",tool_name:"Task",tool_input:{prompt:"rung_1_verify_1 verify-only"}}')")"
if is_denied "$out"; then
  pass "hook denies verify when POLICY-C missing"
else
  fail "hook denies verify when POLICY-C missing"
  printf '%s\n' "$out"
fi

out="$(run_hook Stop "" '{"hook_event_name":"Stop","tool_name":""}')"
if is_denied "$out"; then
  pass "hook denies Stop when POLICY-C missing"
else
  fail "hook denies Stop when POLICY-C missing"
  printf '%s\n' "$out"
fi

python3 "$RESOLVER" --write-policy-c --rung-dir "$RUNG" --table-json "$(cat <<'EOF'
{"schema":"rfl.policy_c.v1","rung_identity":{"family":"glm","effort":"high","display":"GLM 5.2 High"},"verdict":"CLEAN","issues":{"HIGH":"none","MED":"none","LOW":"none","NIT":"none"},"triage":"none","blockers":"none","highs":"none","mediums":"none","disposition":"SKIP","resolved":"none"}
EOF
)" >/dev/null
printf '# SKIPPED none\n' >"$RUNG/SKIPPED.md"

out="$(run_hook PreToolUse Task "$(jq -n '{hook_event_name:"PreToolUse",tool_name:"Task",tool_input:{prompt:"rung_1_verify_1 verify-only"}}')")"
if is_denied "$out"; then
  fail "hook allows verify when POLICY-C valid"
  printf '%s\n' "$out"
else
  pass "hook allows verify when POLICY-C valid"
fi

out="$(run_hook Stop "" '{"hook_event_name":"Stop","tool_name":""}')"
if is_denied "$out"; then
  fail "hook allows Stop when POLICY-C valid"
  printf '%s\n' "$out"
else
  pass "hook allows Stop when POLICY-C valid"
fi

# stop-check: missing Policy C (fresh rung)
rm -f "$RUNG/POLICY-C.json" "$RUNG/POLICY-C.md"
printf '# findings\n' >"$RUNG/review.md"
stop_out="$(cd "$WORKDIR" && printf '%s' '{"hook_event_name":"Stop"}' | env SB_ORCHESTRATOR_WORKER= SILVER_BULLET_RUNTIME=cursor bash "$STOP" 2>/dev/null || true)"
if is_denied "$stop_out"; then
  pass "stop-check denies session end when POLICY-C missing"
else
  fail "stop-check denies session end when POLICY-C missing"
  printf '%s\n' "$stop_out"
fi

python3 "$RESOLVER" --write-policy-c --rung-dir "$RUNG" --table-json "$(cat <<'EOF'
{"schema":"rfl.policy_c.v1","rung_identity":{"family":"glm","effort":"high","display":"GLM 5.2 High"},"verdict":"CLEAN","issues":{"HIGH":"none","MED":"none","LOW":"none","NIT":"none"},"triage":"none","blockers":"none","highs":"none","mediums":"none","disposition":"SKIP","resolved":"none"}
EOF
)" >/dev/null
printf '# SKIPPED none\n' >"$RUNG/SKIPPED.md"
# stop-check may still block on required skills; Policy C should not deny
stop_out="$(cd "$WORKDIR" && printf '%s' '{"hook_event_name":"Stop"}' | env SB_ORCHESTRATOR_WORKER= SILVER_BULLET_RUNTIME=cursor bash "$STOP" 2>/dev/null || true)"
if printf '%s' "$stop_out" | grep -q 'Policy C'; then
  fail "stop-check does not Policy-C-deny when valid"
  printf '%s\n' "$stop_out"
else
  pass "stop-check does not Policy-C-deny when valid"
fi

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
