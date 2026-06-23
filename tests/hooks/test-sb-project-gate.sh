#!/usr/bin/env bash
# Tests for SB project boundary gate (project config discovery).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$REPO_ROOT/hooks/lib/sb-project-gate.sh"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi
export SB_RUNTIME_PRESERVE_STATE_DIR=1
export SB_RUNTIME_STATE_DIR="${SB_RUNTIME_HOME_ROOT}/.silver-bullet/sb-project-gate-test-$$"
mkdir -p "$SB_RUNTIME_STATE_DIR"
# shellcheck source=../../hooks/lib/sb-project-gate.sh
source "$LIB"

PASS=0
FAIL=0

WORK=$(mktemp -d)
cleanup() {
  rm -rf "$WORK" "$SB_RUNTIME_STATE_DIR" 2>/dev/null || true
}
trap cleanup EXIT

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

git -C "$WORK" init -q
echo '{}' >"$WORK/.silver-bullet.json"
echo '# x' >"$WORK/silver-bullet.md"

cd "$WORK"
cfg="$(sb_find_project_config)"
assert_true "finds config" test -n "$cfg"
assert_true "active when config file exists" sb_project_is_initiated "$cfg"

jq '.config_version = "0.40.0"' "$WORK/.silver-bullet.json" >"$WORK/.silver-bullet.json.tmp" && mv "$WORK/.silver-bullet.json.tmp" "$WORK/.silver-bullet.json"
cfg="$(sb_find_project_config)"
assert_true "active when only config_version present" sb_project_is_initiated "$cfg"

jq '.sb_initiated = true' "$WORK/.silver-bullet.json" >"$WORK/.silver-bullet.json.tmp" && mv "$WORK/.silver-bullet.json.tmp" "$WORK/.silver-bullet.json"
cfg="$(sb_find_project_config)"
assert_true "active when sb_initiated true" sb_project_is_initiated "$cfg"

# Cached project root resolves when CWD is outside the tree (#232)
sb_project_root_cache_write "$WORK"
OUTSIDE=$(mktemp -d)
cd "$OUTSIDE"
cfg="$(sb_find_project_config)"
assert_true "cached project root resolves from outside cwd" test -n "$cfg"
assert_true "cached config points at project" test "$cfg" = "$WORK/.silver-bullet.json"
rm -rf "$OUTSIDE"

OTHER=$(mktemp -d)
cd "$OTHER"
export SILVER_BULLET_PROJECT_ROOT="$WORK"
cfg="$(sb_find_project_config)"
assert_true "SILVER_BULLET_PROJECT_ROOT override resolves config" test "$cfg" = "$WORK/.silver-bullet.json"
rm -rf "$OTHER"

echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
