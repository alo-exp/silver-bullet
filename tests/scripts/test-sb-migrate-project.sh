#!/usr/bin/env bash
# Tests scripts/sb-migrate-project.sh installs workflows.sh, gitignore, and workflow docs.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/sb-migrate-project.sh"
PASS=0
FAIL=0

assert_file() {
  local desc="$1" file="$2"
  if [[ -e "$file" ]]; then
    echo "PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $desc — missing $file"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local desc="$1" needle="$2" file="$3"
  if grep -qF "$needle" "$file" 2>/dev/null; then
    echo "PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $desc — missing [$needle] in $file"
    FAIL=$((FAIL + 1))
  fi
}

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

git -C "$WORK" init -q
cp "$REPO_ROOT/templates/silver-bullet.config.json.default" "$WORK/.silver-bullet.json"
echo '# SB' >"$WORK/silver-bullet.md"

if (cd "$WORK" && bash "$SCRIPT" >/dev/null); then
  echo "PASS: sb-migrate-project exits 0"
  PASS=$((PASS + 1))
else
  echo "FAIL: sb-migrate-project failed"
  FAIL=$((FAIL + 1))
fi

assert_file "workflows.sh installed" "$WORK/scripts/workflows.sh"
test -x "$WORK/scripts/workflows.sh" && echo "PASS: workflows.sh executable" && PASS=$((PASS + 1)) || { echo "FAIL: workflows.sh not executable"; FAIL=$((FAIL + 1)); }
assert_file "full-dev-cycle doc" "$WORK/docs/workflows/full-dev-cycle.md"
assert_file "devops-cycle doc" "$WORK/docs/workflows/devops-cycle.md"
assert_file "workflow archive dir" "$WORK/.planning/workflows/.archive"
assert_contains "gitignore has workflows" ".planning/workflows/" "$WORK/.gitignore"
mode="$(jq -r '.orchestrator_mode' "$WORK/.silver-bullet.json")"
if [[ "$mode" == "parent" ]]; then
  echo "PASS: orchestrator_mode parent"
  PASS=$((PASS + 1))
else
  echo "FAIL: orchestrator_mode is $mode"
  FAIL=$((FAIL + 1))
fi

echo
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
