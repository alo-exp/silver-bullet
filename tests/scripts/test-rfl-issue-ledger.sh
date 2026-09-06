#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RESOLVER="${REPO_ROOT}/scripts/review-fix-ladder.py"
LEDGER_PY="${REPO_ROOT}/scripts/lib/rfl_issue_ledger.py"
SKILL="${REPO_ROOT}/skills/silver-review-fix-ladder/SKILL.md"
BRIEF="${REPO_ROOT}/templates/rfl-review-brief.md"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; (( PASS++ )) || true; }
fail() { echo "FAIL: $1"; (( FAIL++ )) || true; }

[[ -f "$RESOLVER" ]] && pass "resolver exists" || fail "resolver missing"
[[ -f "$LEDGER_PY" ]] && pass "rfl_issue_ledger.py exists" || fail "rfl_issue_ledger.py missing"
[[ -f "$BRIEF" ]] && pass "canonical brief template exists" || fail "templates/rfl-review-brief.md missing"

if grep -qF 'do not re-report ledger rows' "$BRIEF" \
  && grep -qF 'all severities' "$BRIEF" \
  && grep -qF -- '--write-review-brief' "$BRIEF" \
  && grep -qF 'only legal review brief' "$BRIEF" \
  && ! grep -qF 'verify_2 is skipped' "$BRIEF"; then
  pass "brief template encodes pack-ledger hop brief, not verify overlay"
else
  fail "brief template encodes pack-ledger hop brief, not verify overlay"
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/rfl-issue-ledger.XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

mkdir -p "$TMP/run/rung-01"
cat >"$TMP/run/ISSUE-LEDGER.md" <<'EOF'
# ISSUE LEDGER

Freeze SHA after APPLY: `aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa`

| ID | Severity | Status | Summary |
|----|----------|--------|---------|
| R1-F01 | HIGH | ACCEPT | first hole |
| R1-F02 | NIT | REJECT | false cite |
EOF

cat >"$TMP/run/LADDER-STATUS.json" <<'EOF'
{
  "status": "active",
  "freeze": { "sha256": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" },
  "consecutive_clean_reviews": 0
}
EOF

cat >"$TMP/run/rung-01/POLICY-C.json" <<'EOF'
{
  "schema": "rfl.policy_c.v1",
  "verdict": "NOT CLEAN",
  "apply_sha": "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
  "issues": {
    "HIGH": "none",
    "MED": [{"id": "R2-F01", "title": "second hole"}],
    "LOW": "none",
    "NIT": [{"id": "R2-F02", "title": "valid nit"}]
  },
  "triage": [
    {"id": "R2-F01", "severity": "MED", "decision": "ACCEPT", "reason": "real"},
    {"id": "R2-F02", "severity": "NIT", "decision": "ACCEPT", "reason": "still valid"}
  ],
  "resolved": [
    {"id": "R2-F01", "severity": "MED", "title": "second hole", "decision": "ACCEPT", "resolved": "yes"},
    {"id": "R2-F02", "severity": "NIT", "title": "valid nit", "decision": "ACCEPT", "resolved": "yes"}
  ]
}
EOF

ledger="$(python3 "$RESOLVER" --issue-ledger --run-dir "$TMP/run")"
grep -q '| R1-F01 | HIGH | ACCEPT |' <<<"$ledger" && pass "ledger includes ISSUE-LEDGER.md HIGH row" || fail "ledger includes ISSUE-LEDGER.md HIGH row"
grep -q '| R1-F02 | NIT | REJECT |' <<<"$ledger" && pass "ledger includes REJECT nit" || fail "ledger includes REJECT nit"
grep -q '| R2-F01 | MED | ACCEPT | yes |' <<<"$ledger" && pass "ledger merges POLICY-C ACCEPT MED" || fail "ledger merges POLICY-C ACCEPT MED"
grep -q '| R2-F02 | NIT | ACCEPT | yes |' <<<"$ledger" && pass "ledger merges POLICY-C valid nit" || fail "ledger merges POLICY-C valid nit"
grep -q 'Issue ledger (already identified)' <<<"$ledger" && pass "ledger has canonical heading" || fail "ledger has canonical heading"

brief="$(python3 "$RESOLVER" --write-review-brief --run-dir "$TMP/run")"
grep -q 'do not re-report ledger rows' <<<"$brief" && pass "brief residual-only definition" || fail "brief residual-only definition"
grep -q 'file only one new ID' <<<"$brief" && pass "brief negates one-ID cap" || fail "brief negates one-ID cap"
grep -q 'all severities' <<<"$brief" && pass "brief all severities" || fail "brief all severities"
grep -q "APPLY'd as a pack" <<<"$brief" && pass "brief pack APPLY" || fail "brief pack APPLY"
grep -q 'Orthogonal to Policy F' <<<"$brief" && pass "brief orthogonal to Policy F" || fail "brief orthogonal to Policy F"
grep -q '| R2-F02 | NIT | ACCEPT |' <<<"$brief" && pass "brief includes nit pack row" || fail "brief includes nit pack row"
if grep -q 'verify_2 is skipped' <<<"$brief"; then
  fail "brief must not bake skip-verify_2"
else
  pass "brief must not bake skip-verify_2"
fi

inline='[{"id":"X-F01","severity":"LOW","decision":"ACCEPT","resolved":"no","sha":"ddd","summary":"inline only"}]'
inline_out="$(python3 "$RESOLVER" --issue-ledger --table-json "$inline")"
grep -q '| X-F01 | LOW | ACCEPT | no | ddd | inline only |' <<<"$inline_out" && pass "ledger accepts inline table-json" || fail "ledger accepts inline table-json"

if python3 "$RESOLVER" --issue-ledger >/tmp/rfl-issue-ledger-err.txt 2>&1; then
  fail "issue-ledger without run-dir/json exits non-zero"
else
  pass "issue-ledger without run-dir/json exits non-zero"
fi

if grep -qF '### Policy G — hop review (pack-ledger) (HARD)' "$SKILL" \
  && grep -qF 'Stop **one-residual-per-round**' "$SKILL" \
  && grep -qF 'only legal review brief' "$SKILL"; then
  pass "SKILL Policy G heading present"
else
  fail "SKILL Policy G heading present"
fi

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
