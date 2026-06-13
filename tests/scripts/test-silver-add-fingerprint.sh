#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="${REPO_ROOT}/scripts/silver-add.sh"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; (( PASS++ )) || true; }
fail() { echo "FAIL: $1"; (( FAIL++ )) || true; }

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

chmod +x "$SCRIPT"

fp1="$(bash "$SCRIPT" fingerprint --domain code-health --scope src/a.ts --finding 'null deref')"
fp2="$(bash "$SCRIPT" fingerprint --domain code-health --scope src/a.ts --finding 'null deref')"
fp3="$(bash "$SCRIPT" fingerprint --domain code-health --scope src/a.ts --finding 'other issue')"

if [[ "$fp1" == "$fp2" && -n "$fp1" ]]; then
  pass "fingerprint is stable for identical input"
else
  fail "fingerprint is stable for identical input"
fi

if [[ "$fp1" != "$fp3" ]]; then
  pass "fingerprint changes when finding changes"
else
  fail "fingerprint changes when finding changes"
fi

py_fp="$(PYTHONPATH="${REPO_ROOT}/scripts/lib" python3 -c '
from evidence_common import audit_fingerprint
print(audit_fingerprint("code-health", "src/a.ts", "null deref"))
')"
if [[ "$fp1" == "$py_fp" ]]; then
  pass "shell fingerprint matches evidence_common.py"
else
  fail "shell fingerprint matches evidence_common.py ($fp1 vs $py_fp)"
fi

mkdir -p "$WORKDIR/docs/issues"
echo "fingerprint: $fp1" >> "$WORKDIR/docs/issues/BACKLOG.md"
dup="$(bash "$SCRIPT" dedup --fingerprint "$fp1" --root "$WORKDIR")"
if [[ "$dup" == duplicate:* ]]; then
  pass "dedup detects local backlog fingerprint"
else
  fail "dedup detects local backlog fingerprint — got $dup"
fi

score="$(bash "$SCRIPT" prioritize --impact 5 --risk 4 --evidence-strength 3 --effort 2)"
if [[ "$score" == "10" ]]; then
  pass "prioritization score formula"
else
  fail "prioritization score formula — expected 10 got $score"
fi

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
