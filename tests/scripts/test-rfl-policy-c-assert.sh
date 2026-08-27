#!/usr/bin/env bash
# Encoder asserts for RFL Policy C and sibling failure-management artifacts.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RESOLVER="${REPO_ROOT}/scripts/review-fix-ladder.py"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

assert_exit() {
  local desc="$1" want="$2"
  shift 2
  local rc=0
  "$@" >/tmp/rfl-policy-c-out.$$ 2>/tmp/rfl-policy-c-err.$$ || rc=$?
  if [[ "$rc" -eq "$want" ]]; then
    pass "$desc"
  else
    fail "$desc (exit $rc want $want)"
    sed -n '1,40p' /tmp/rfl-policy-c-out.$$
    sed -n '1,20p' /tmp/rfl-policy-c-err.$$
  fi
}

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/rfl-policy-c.XXXXXX")"
trap 'rm -rf "$WORKDIR" /tmp/rfl-policy-c-out.$$ /tmp/rfl-policy-c-err.$$' EXIT

RUN="$WORKDIR/.planning/rfl-test"
RUNG="$RUN/rung-01-cursor-glm-5.2-high"
mkdir -p "$RUNG"

CLEAN_NONE="$(cat <<'EOF'
{
  "schema": "rfl.policy_c.v1",
  "rung_identity": {"family": "glm", "effort": "high", "display": "GLM 5.2 High"},
  "verdict": "CLEAN",
  "issues": {"HIGH": "none", "MED": "none", "LOW": "none", "NIT": "none"},
  "triage": "none",
  "blockers": "none",
  "highs": "none",
  "mediums": "none",
  "disposition": "SKIP",
  "resolved": "none"
}
EOF
)"

CLEAN_NIT="$(cat <<'EOF'
{
  "schema": "rfl.policy_c.v1",
  "rung_identity": {"family": "glm", "effort": "high", "display": "GLM 5.2 High"},
  "verdict": "CLEAN",
  "issues": {"HIGH": "none", "MED": "none", "LOW": "none", "NIT": [{"id": "N1", "title": "nit"}]},
  "triage": [{"id": "N1", "severity": "NIT", "decision": "ACCEPT", "reason": "valid"}],
  "blockers": "none",
  "highs": "none",
  "mediums": "none",
  "disposition": "ACCEPT-apply",
  "resolved": [{"id": "N1", "severity": "NIT", "title": "nit", "decision": "ACCEPT", "resolved": "yes"}]
}
EOF
)"

BLOCKED_HOLD="$(cat <<'EOF'
{
  "schema": "rfl.policy_c.v1",
  "rung_identity": {"family": "opencode", "effort": "max", "display": "Qwen 3.8 Max"},
  "verdict": "BLOCKED",
  "issues": {"HIGH": "none", "MED": "none", "LOW": "none", "NIT": "none"},
  "triage": "none",
  "blockers": "none",
  "highs": "none",
  "mediums": "none",
  "disposition": "HOLD",
  "resolved": "none"
}
EOF
)"

# --- missing file ---
assert_exit "assert-policy-c fails without file" 2 \
  python3 "$RESOLVER" --assert-policy-c --rung-dir "$RUNG"

# --- without none-rows ---
printf '%s\n' '{"schema":"rfl.policy_c.v1","rung_identity":{"family":"glm","effort":"high","display":"GLM 5.2 High"},"verdict":"CLEAN","issues":{"HIGH":[],"MED":"none","LOW":"none","NIT":"none"},"triage":"none","blockers":"none","highs":"none","mediums":"none","disposition":"SKIP"}' >"$RUNG/POLICY-C.json"
printf '# stub\n' >"$RUNG/POLICY-C.md"
assert_exit "assert-policy-c fails without none-rows" 2 \
  python3 "$RESOLVER" --assert-policy-c --rung-dir "$RUNG"

# --- without triage ---
printf '%s\n' '{"schema":"rfl.policy_c.v1","rung_identity":{"family":"glm","effort":"high","display":"GLM 5.2 High"},"verdict":"CLEAN","issues":{"HIGH":"none","MED":"none","LOW":"none","NIT":"none"},"blockers":"none","highs":"none","mediums":"none","disposition":"SKIP"}' >"$RUNG/POLICY-C.json"
assert_exit "assert-policy-c fails without triage" 2 \
  python3 "$RESOLVER" --assert-policy-c --rung-dir "$RUNG"

# --- CLEAN-none ---
printf '%s\n' "$CLEAN_NONE" >"$WORKDIR/clean-none.json"
assert_exit "write-policy-c CLEAN-none" 0 \
  python3 "$RESOLVER" --write-policy-c --rung-dir "$RUNG" --table-json-file "$WORKDIR/clean-none.json"
assert_exit "assert-policy-c passes CLEAN-none" 0 \
  python3 "$RESOLVER" --assert-policy-c --rung-dir "$RUNG"
if grep -qF '| — | **none** |' "$RUNG/POLICY-C.md" && grep -qF '**Verdict:** CLEAN' "$RUNG/POLICY-C.md"; then
  pass "CLEAN-none markdown has none-rows"
else
  fail "CLEAN-none markdown has none-rows"
fi

# --- CLEAN+NIT ACCEPT ---
printf '%s\n' "$CLEAN_NIT" >"$WORKDIR/clean-nit.json"
assert_exit "write-policy-c CLEAN+NIT ACCEPT" 0 \
  python3 "$RESOLVER" --write-policy-c --rung-dir "$RUNG" --table-json-file "$WORKDIR/clean-nit.json"
assert_exit "assert-policy-c passes CLEAN+NIT ACCEPT" 0 \
  python3 "$RESOLVER" --assert-policy-c --rung-dir "$RUNG"
if grep -qF '| N1 | nit |' "$RUNG/POLICY-C.md" && grep -qF '| N1 | NIT | ACCEPT | valid |' "$RUNG/POLICY-C.md"; then
  pass "CLEAN+NIT markdown has ACCEPT row"
else
  fail "CLEAN+NIT markdown has ACCEPT row"
fi

# --- BLOCKED still requires Policy C ---
printf '%s\n' "$BLOCKED_HOLD" >"$WORKDIR/blocked.json"
assert_exit "write-policy-c BLOCKED HOLD" 0 \
  python3 "$RESOLVER" --write-policy-c --rung-dir "$RUNG" --table-json-file "$WORKDIR/blocked.json"
assert_exit "assert-policy-c passes BLOCKED with none groups + HOLD" 0 \
  python3 "$RESOLVER" --assert-policy-c --rung-dir "$RUNG"

printf '%s\n' '{"status":"active","current_rung":"rung-01-cursor-glm-5.2-high","current_phase":"rung_01_review"}' >"$RUN/LADDER-STATUS.json"
printf '# review\n' >"$RUNG/review.md"

assert_exit "advance to next rung without BLOCKED.md fails" 2 \
  python3 "$RESOLVER" --assert-rfl-advance --run-dir "$RUN" --next-action next_rung_review

printf '# blocked\n' >"$RUNG/BLOCKED.md"
assert_exit "HOLD still cannot start next rung" 2 \
  python3 "$RESOLVER" --assert-rfl-advance --run-dir "$RUN" --next-action next_rung_review

assert_exit "task after BLOCKED Policy C + BLOCKED.md allowed" 0 \
  python3 "$RESOLVER" --assert-rfl-advance --run-dir "$RUN" --next-action task

# --- quota classify required on 429 BLOCKED ---
printf 'OpenCode 429 quota limit reset in 3 hours\n' >"$RUNG/BLOCKED.md"
assert_exit "quota BLOCKED without QUOTA-CLASSIFY.json fails" 2 \
  python3 "$RESOLVER" --assert-rfl-advance --run-dir "$RUN" --next-action task
printf '%s\n' '{"quota_class":"five_hour","should_schedule":true}' >"$RUNG/QUOTA-CLASSIFY.json"
assert_exit "quota BLOCKED with classifier JSON allowed for task" 0 \
  python3 "$RESOLVER" --assert-rfl-advance --run-dir "$RUN" --next-action task

# --- SKIPPED.md before N+1 ---
SKIP_DIR="$RUN/rung-02-cursor-grok-4.6-high"
mkdir -p "$SKIP_DIR"
printf '%s\n' '{"status":"active","current_rung":"rung-02-cursor-grok-4.6-high","current_phase":"rung_02_review"}' >"$RUN/LADDER-STATUS.json"
printf '# review skipped host\n' >"$SKIP_DIR/review.md"
python3 "$RESOLVER" --write-policy-c --rung-dir "$SKIP_DIR" --table-json "$(cat <<'EOF'
{"schema":"rfl.policy_c.v1","rung_identity":{"family":"grok","effort":"high","display":"Grok 4.6 High"},"verdict":"SKIPPED","issues":{"HIGH":"none","MED":"none","LOW":"none","NIT":"none"},"triage":"none","blockers":"none","highs":"none","mediums":"none","disposition":"SKIP","resolved":"none"}
EOF
)" >/dev/null
assert_exit "next rung without SKIPPED.md fails" 2 \
  python3 "$RESOLVER" --assert-rfl-advance --run-dir "$RUN" --rung-dir "$SKIP_DIR" --next-action next_rung_review
printf '# SKIPPED\n' >"$SKIP_DIR/SKIPPED.md"
assert_exit "next rung with SKIPPED.md allowed" 0 \
  python3 "$RESOLVER" --assert-rfl-advance --run-dir "$RUN" --rung-dir "$SKIP_DIR" --next-action next_rung_review

# --- STOP.md ---
printf '%s\n' '{"status":"active","current_rung":"rung-02-cursor-grok-4.6-high","current_phase":"stop","compliance_stop":true}' >"$RUN/LADDER-STATUS.json"
assert_exit "compliance_stop without STOP.md fails" 2 \
  python3 "$RESOLVER" --assert-rfl-advance --run-dir "$RUN" --next-action task
printf '# stop\n\ncheck: policy_c\n' >"$SKIP_DIR/STOP.md"
assert_exit "STOP.md present blocks Task advance" 2 \
  python3 "$RESOLVER" --assert-rfl-advance --run-dir "$RUN" --next-action task

# --- mark-ladder-status completed ---
COMP="$WORKDIR/.planning/rfl-complete"
mkdir -p "$COMP/rung-01-x"
printf '%s\n' '{"status":"active"}' >"$COMP/LADDER-STATUS.json"
assert_exit "mark completed empty run still allowed" 0 \
  python3 "$RESOLVER" --mark-ladder-status completed --run-dir "$COMP"

MISS="$WORKDIR/.planning/rfl-missing-c"
mkdir -p "$MISS/rung-01-x"
printf '# review\n' >"$MISS/rung-01-x/review.md"
printf '%s\n' '{"status":"active","current_rung":"rung-01-x"}' >"$MISS/LADDER-STATUS.json"
assert_exit "cannot --mark-ladder-status completed if current rung missing Policy C" 2 \
  python3 "$RESOLVER" --mark-ladder-status completed --run-dir "$MISS"

# restore a completable run: CLEAN-none + skip artifacts not required if no review? has review.md
python3 "$RESOLVER" --write-policy-c --rung-dir "$MISS/rung-01-x" --table-json "$(cat <<'EOF'
{"schema":"rfl.policy_c.v1","rung_identity":{"family":"glm","effort":"high","display":"GLM 5.2 High"},"verdict":"SKIPPED","issues":{"HIGH":"none","MED":"none","LOW":"none","NIT":"none"},"triage":"none","blockers":"none","highs":"none","mediums":"none","disposition":"SKIP","resolved":"none"}
EOF
)" >/dev/null
printf '# SKIPPED\n' >"$MISS/rung-01-x/SKIPPED.md"
assert_exit "mark completed after Policy C + SKIPPED.md" 0 \
  python3 "$RESOLVER" --mark-ladder-status completed --run-dir "$MISS"

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
