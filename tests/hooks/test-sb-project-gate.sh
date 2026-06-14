#!/usr/bin/env bash
# Tests for sb_initiated project gate (Wave 0.1).
set -euo pipefail

LIB="$(cd "$(dirname "$0")/../.." && pwd)/hooks/lib/sb-project-gate.sh"
# shellcheck source=../../hooks/lib/sb-project-gate.sh
source "$LIB"

PASS=0
FAIL=0

assert_true() {
  local name="$1"
  shift
  if "$@"; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name"
    FAIL=$((FAIL + 1))
  fi
}

assert_false() {
  local name="$1"
  shift
  if ! "$@"; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name"
    FAIL=$((FAIL + 1))
  fi
}

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
git -C "$WORK" init -q
echo '{}' >"$WORK/.silver-bullet.json"
echo '# x' >"$WORK/silver-bullet.md"

(
  cd "$WORK"
  cfg="$(sb_find_project_config)"
  assert_true "finds config" test -n "$cfg"
  assert_false "not initiated when absent" sb_project_is_initiated "$cfg"
)

jq '.sb_initiated = true' "$WORK/.silver-bullet.json" >"$WORK/.silver-bullet.json.tmp" && mv "$WORK/.silver-bullet.json.tmp" "$WORK/.silver-bullet.json"

(
  cd "$WORK"
  cfg="$(sb_find_project_config)"
  assert_true "initiated when true" sb_project_is_initiated "$cfg"
)

echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
