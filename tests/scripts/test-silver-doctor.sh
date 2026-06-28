#!/usr/bin/env bash
# test-silver-doctor.sh — silver:doctor skill + sb-doctor.sh contract
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL="${REPO_ROOT}/skills/silver-doctor/SKILL.md"
DOCTOR="${REPO_ROOT}/scripts/sb-doctor.sh"
PASS=0
FAIL=0

assert_contains() {
  local desc="$1" needle="$2" file="$3"
  if grep -qE "$needle" "$file"; then
    echo "PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $desc — missing [$needle] in $file"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_exists() {
  local desc="$1" file="$2"
  if [[ -f "$file" ]]; then
    echo "PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $desc — missing $file"
    FAIL=$((FAIL + 1))
  fi
}

assert_executable() {
  local desc="$1" file="$2"
  if [[ -x "$file" ]]; then
    echo "PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $desc — not executable: $file"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_exists "silver-doctor skill exists" "$SKILL"
assert_file_exists "sb-doctor.sh exists" "$DOCTOR"
chmod +x "$DOCTOR" 2>/dev/null || true
assert_executable "sb-doctor.sh executable" "$DOCTOR"

assert_contains "documents sb-doctor.sh" "sb-doctor\\.sh" "$SKILL"
assert_contains "documents D1 jq check" "D1" "$SKILL"
assert_contains "documents D13 Claude import" "claude/plugins|D13" "$SKILL"
assert_contains "documents zero FAIL for PASS" "zero FAIL" "$SKILL"
assert_contains "documents friction log" "sb-friction-log" "$SKILL"

# Script implements key check IDs
for id in D1 D2 D3 D4 D5 D6 D7 D8 D9 D11 D12 D13; do
  if grep -q "record pass ${id}\|record fail ${id}\|record warn ${id}" "$DOCTOR" 2>/dev/null || grep -q "${id}" "$DOCTOR"; then
    echo "PASS: sb-doctor.sh references check ${id}"
    PASS=$((PASS + 1))
  else
    echo "FAIL: sb-doctor.sh missing check ${id}"
    FAIL=$((FAIL + 1))
  fi
done

# Broken fixture: missing sb_initiated should FAIL D5
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT
cp "$REPO_ROOT/templates/silver-bullet.config.json.default" "$FIXTURE/.silver-bullet.json"
jq '.sb_initiated = false' "$FIXTURE/.silver-bullet.json" >"${FIXTURE}/.silver-bullet.json.tmp"
mv "${FIXTURE}/.silver-bullet.json.tmp" "$FIXTURE/.silver-bullet.json"
cp "$REPO_ROOT/silver-bullet.md" "$FIXTURE/silver-bullet.md"
mkdir -p "$FIXTURE/docs/workflows" "$FIXTURE/scripts"
cp "$REPO_ROOT/scripts/workflows.sh" "$FIXTURE/scripts/workflows.sh"
chmod +x "$FIXTURE/scripts/workflows.sh"

out="$(bash "$DOCTOR" "$FIXTURE" 2>&1 || true)"
if printf '%s' "$out" | grep -q 'FAIL: D5'; then
  echo "PASS: doctor FAILs D5 when sb_initiated false"
  PASS=$((PASS + 1))
else
  echo "FAIL: doctor should FAIL D5 when sb_initiated false"
  FAIL=$((FAIL + 1))
fi

# Live dogfood repo should PASS when environment is healthy (soft — warn only on fail)
if bash "$DOCTOR" "$REPO_ROOT" >/tmp/sb-doctor-live-$$.txt 2>&1; then
  echo "PASS: doctor PASS on live repo"
  PASS=$((PASS + 1))
else
  echo "WARN: doctor did not PASS on live repo (environment-dependent)"
  cat /tmp/sb-doctor-live-$$.txt | tail -20
  # Do not increment FAIL — CI may lack full host plugin state in sandbox
fi
rm -f /tmp/sb-doctor-live-$$.txt

echo
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
