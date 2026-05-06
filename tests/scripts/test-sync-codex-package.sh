#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

assert_file_exists() {
  local desc="$1" path="$2"
  if [[ -f "$path" ]]; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — missing: $path"
    (( FAIL++ )) || true
  fi
}

assert_path_absent() {
  local desc="$1" path="$2"
  if [[ ! -e "$path" ]]; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — should be absent: $path"
    (( FAIL++ )) || true
  fi
}

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/sync-codex-package.sh"
PACKAGE_ROOT="$REPO_ROOT/plugins/silver-bullet"

bash "$SCRIPT" >/dev/null

assert_file_exists "Codex manifest present" "$PACKAGE_ROOT/.codex-plugin/plugin.json"
assert_file_exists "Silver Bullet skill available" "$PACKAGE_ROOT/skills/silver-feature/SKILL.md"
assert_file_exists "Stamped template present" "$PACKAGE_ROOT/templates/silver-bullet.md.base"
assert_path_absent "Third-party plugins excluded from SB bundle" "$PACKAGE_ROOT/third-party-plugins"
assert_path_absent "Project planning tree excluded from SB bundle" "$PACKAGE_ROOT/.planning"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
