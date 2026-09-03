#!/usr/bin/env bash
# AE-11: CI template parity — silver-bullet.md.base substitution placeholders.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEMPLATE="$REPO_ROOT/templates/silver-bullet.md.base"
PASS=0
FAIL=0

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $label (expected '$expected', got '$actual')"
    FAIL=$((FAIL + 1))
  fi
}

# Allowed placeholders per init contract (skills/silver-init, scaffold-steps.md)
allowed='{{PROJECT_NAME}} {{ACTIVE_WORKFLOW}}'
found=$(grep -oE '\{\{[A-Z0-9_]+\}\}' "$TEMPLATE" | sort -u | tr '\n' ' ' | sed 's/ $//')
for token in $found; do
  case " $allowed " in
    *" $token "*) ;;
    *)
      echo "FAIL: unexpected placeholder $token in silver-bullet.md.base"
      FAIL=$((FAIL + 1))
      ;;
  esac
done
if [[ "$FAIL" -eq 0 ]]; then
  echo "PASS: only allowed placeholders present"
  PASS=$((PASS + 1))
fi

assert_eq "PROJECT_NAME placeholder present" "1" "$(grep -c '{{PROJECT_NAME}}' "$TEMPLATE" || true)"
assert_eq "ACTIVE_WORKFLOW placeholder present" "1" "$(grep -c '{{ACTIVE_WORKFLOW}}' "$TEMPLATE" || true)"

# Live silver-bullet.md must not retain template placeholders (dogfood)
if [[ -f "$REPO_ROOT/silver-bullet.md" ]]; then
  if grep -qE '\{\{[A-Z0-9_]+\}\}' "$REPO_ROOT/silver-bullet.md"; then
    echo "FAIL: live silver-bullet.md still contains template placeholders"
    FAIL=$((FAIL + 1))
  else
    echo "PASS: live silver-bullet.md has no template placeholders"
    PASS=$((PASS + 1))
  fi
fi

echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
