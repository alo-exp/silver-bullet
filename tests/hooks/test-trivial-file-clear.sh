#!/usr/bin/env bash
# Tests for hooks/trivial-file-clear.sh
# Verifies the trivial-session marker is removed after edits/writes.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/trivial-file-clear.sh"
PASS=0
FAIL=0

TEST_RUN_ID="$$"
TMPHOME=""
TMPSTATE=""

cleanup_all() {
  rm -rf "$TMPHOME" 2>/dev/null || true
}
trap cleanup_all EXIT

setup() {
  TMPHOME=$(mktemp -d)
  export HOME="$TMPHOME"
  export SILVER_BULLET_RUNTIME="codex"
  TMPSTATE="${HOME}/.codex/.silver-bullet"
  mkdir -p "$TMPSTATE"
  printf '# Silver Bullet\n' >"$TMPHOME/silver-bullet.md"
  printf '{"project":{}}\n' >"$TMPHOME/.silver-bullet.json"
}

run_hook() {
  ( cd "$TMPHOME" && bash "$HOOK" 2>/dev/null )
}

assert_removed() {
  local label="$1"
  local path="$2"
  if [[ ! -e "$path" ]]; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — expected file removed, still present at $path"
    FAIL=$((FAIL + 1))
  fi
}

assert_exists() {
  local label="$1"
  local path="$2"
  if [[ -e "$path" ]]; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — expected file to exist at $path"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== trivial-file-clear.sh tests ==="

setup
trivial_path="${TMPSTATE}/trivial"
other_path="${TMPSTATE}/keep-me"
printf '1' > "$trivial_path"
printf '2' > "$other_path"

run_hook
assert_removed "Trivial marker is removed" "$trivial_path"
assert_exists "Unrelated state file is preserved" "$other_path"

run_hook
assert_removed "Second run remains idempotent" "$trivial_path"
assert_exists "Second run still preserves unrelated state" "$other_path"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
