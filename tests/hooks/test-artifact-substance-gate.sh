#!/usr/bin/env bash
# test-artifact-substance-gate.sh — P3 regression for artifact substance delivery gate
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

HOOK_HELPERS="$(cd "$(dirname "$0")" && pwd)/helpers/common.sh"
if [[ -f "$HOOK_HELPERS" ]]; then
  # shellcheck source=helpers/common.sh
  source "$HOOK_HELPERS"
fi

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$REPO_ROOT/hooks/lib/artifact-substance-gate.sh"
PASS=0
FAIL=0

# shellcheck source=../../hooks/lib/artifact-substance-gate.sh
source "$LIB"

setup() {
  TMPDIR_TEST=$(mktemp -d)
  hook_test_stamp_sb_scaffold "$TMPDIR_TEST"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

run_gate() {
  local state_contents="$1"
  (
    emit_warn() { :; }
    emit_block() { printf 'blocked\n%s\n' "$1"; exit 0; }
    sb_artifact_substance_gate_enforce "$TMPDIR_TEST" emit_warn emit_block 1 "$state_contents" || true
    echo passed
  )
}


assert_message_real_newlines() {
  local name="$1" result="$2"
  local msg
  msg=$(printf '%s' "$result" | sed -n '2,$p')
  if [[ -z "$msg" ]]; then
    echo "  FAIL: $name — no message captured"
    FAIL=$((FAIL + 1))
    return
  fi
  if [[ "$msg" != *$'\n'* ]]; then
    echo "  FAIL: $name — message has no real newlines"
    FAIL=$((FAIL + 1))
    return
  fi
  if grep -qF '\n' <<<"$msg"; then
    echo "  FAIL: $name — message contains literal backslash-n"
    FAIL=$((FAIL + 1))
    return
  fi
  echo "  ok: $name"
  PASS=$((PASS + 1))
}

assert_blocked() {
  local name="$1" result="$2"
  if [[ "$result" == *blocked* ]]; then
    echo "  ok: $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name"
    FAIL=$((FAIL + 1))
  fi
}

assert_passed() {
  local name="$1" result="$2"
  if [[ "$result" == *passed* ]]; then
    echo "  ok: $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name"
    FAIL=$((FAIL + 1))
  fi
}

echo "--- artifact-substance-gate ---"

setup
mkdir -p "$TMPDIR_TEST/.planning/phases/01-test"
cat >"$TMPDIR_TEST/.planning/phases/01-test/VERIFICATION.md" <<'MD'
# Verification
TODO fill later
MD
result=$(run_gate $'silver-verify\n')
assert_blocked "stub VERIFICATION.md blocks delivery when silver-verify recorded" "$result"
assert_message_real_newlines "NEWLINE: stub VERIFICATION block message uses real newlines" "$result"
teardown

setup
mkdir -p "$TMPDIR_TEST/.planning/phases/01-test"
cat >"$TMPDIR_TEST/.planning/phases/01-test/VERIFICATION.md" <<'MD'
# Verification
```bash
$ bash tests/run-all-tests.sh
Results: 10 passed, 0 failed
```
MD
result=$(run_gate $'silver-verify\n')
assert_passed "substantive VERIFICATION.md with command output passes" "$result"
teardown

setup
mkdir -p "$TMPDIR_TEST/.planning/phases/01-test"
cat >"$TMPDIR_TEST/.planning/phases/01-test/REVIEW.md" <<'MD'
# Review
lorem ipsum only
MD
result=$(run_gate $'silver-review\n')
assert_blocked "REVIEW.md without findings language blocks" "$result"
teardown

setup
mkdir -p "$TMPDIR_TEST/.planning/phases/01-test"
cat >"$TMPDIR_TEST/.planning/phases/01-test/REVIEW.md" <<'MD'
# Review
No findings — clean pass.
MD
result=$(run_gate $'silver-review\n')
assert_blocked "REVIEW.md without REVIEW-ROUNDS.md blocks" "$result"
teardown

setup
mkdir -p "$TMPDIR_TEST/.planning/phases/01-test"
cat >"$TMPDIR_TEST/.planning/phases/01-test/REVIEW.md" <<'MD'
# Review
No findings — clean pass.
MD
cat >"$TMPDIR_TEST/.planning/REVIEW-ROUNDS.md" <<'MD'
## Round 1
Findings: must-fix item — fixed.

## Round 2
No findings — clean pass.
MD
result=$(run_gate $'silver-review\n')
assert_passed "REVIEW.md with two REVIEW-ROUNDS passes" "$result"
teardown


# R9-11: a recorded skill with no artifact at all is the lifecycle gate's finding (ARTIFACT BLOCKED), not this one's
setup
result=$(run_gate $'silver-verify\n')
assert_passed "no artifact at all is left to the lifecycle gate (deploy-tier ARTIFACT BLOCKED)" "$result"
teardown

setup
result=$(run_gate $'silver-plan\n')
assert_passed "silver-plan recorded without PLAN.md is not gated here either" "$result"
teardown

setup
result=$(run_gate "")
assert_passed "no recorded state: no artifact is demanded" "$result"
teardown

# R9-11: an empty fenced block is not command output
setup
mkdir -p "$TMPDIR_TEST/.planning/phases/01-test"
printf '# Verification\nall good\n```bash\n```\n' >"$TMPDIR_TEST/.planning/phases/01-test/VERIFICATION.md"
result=$(run_gate $'silver-verify\n')
assert_blocked "an empty bash fence is not command output (R9-11)" "$result"
printf '# Verification\n```text\n\n   \n```\nthen\n```bash\n$ make test\nok\n```\n' >"$TMPDIR_TEST/.planning/phases/01-test/VERIFICATION.md"
result=$(run_gate $'silver-verify\n')
assert_passed "a later non-empty fence counts even after an empty one" "$result"
printf '# Verification\n$ pytest -q\n3 passed\n' >"$TMPDIR_TEST/.planning/phases/01-test/VERIFICATION.md"
result=$(run_gate $'silver-verify\n')
assert_passed "an unfenced shell transcript still counts" "$result"
teardown

# R9-11: a newer top-level file with an empty fence cannot shadow a stub phase artifact
setup
mkdir -p "$TMPDIR_TEST/.planning/phases/01-test"
printf '# Verification\nTODO\n' >"$TMPDIR_TEST/.planning/phases/01-test/VERIFICATION.md"
sleep 1
printf '# Verification\nall good\n```bash\n```\n' >"$TMPDIR_TEST/.planning/VERIFICATION.md"
result=$(run_gate $'silver-verify\n')
assert_blocked "a newer top-level VERIFICATION.md with an empty fence does not shadow a stub (R9-11)" "$result"
teardown

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
