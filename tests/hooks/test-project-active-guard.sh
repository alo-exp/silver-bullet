#!/usr/bin/env bash
# Tests hooks/lib/project-active.sh and hook fail-open when SB is not initiated.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=../../hooks/lib/runtime-paths.sh
source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
export SB_RUNTIME_PRESERVE_STATE_DIR=1
export SB_RUNTIME_STATE_DIR="${SB_RUNTIME_HOME_ROOT}/.silver-bullet/project-active-guard-test-$$"
mkdir -p "$SB_RUNTIME_STATE_DIR"

PASS=0
FAIL=0
WORK=""
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

assert_exit0() {
  local name="$1"
  shift
  if ( "$@" ); then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name (expected exit 0)"
    FAIL=$((FAIL + 1))
  fi
}

assert_no_block() {
  local name="$1" out="$2"
  if printf '%s' "$out" | grep -qE 'permissionDecision":"deny|decision":"block'; then
    echo "FAIL: $name (unexpected block)"
    FAIL=$((FAIL + 1))
  else
    echo "PASS: $name"
    PASS=$((PASS + 1))
  fi
}

assert_has_context() {
  local name="$1" out="$2"
  if printf '%s' "$out" | grep -q 'additionalContext'; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name (expected context injection)"
    FAIL=$((FAIL + 1))
  fi
}

setup_repo() {
  local initiated="${1:-}"
  WORK=$(mktemp -d)
  git -C "$WORK" init -q
  git -C "$WORK" -c user.email="t@t.com" -c user.name="T" commit -q --allow-empty -m init 2>/dev/null || true
  printf '# SB\n' >"$WORK/silver-bullet.md"
  mkdir -p "$WORK/src"
  touch "$WORK/src/app.js"
  if [[ -n "$initiated" ]]; then
    local cv
    cv="$(jq -r '.config_version' "$REPO_ROOT/templates/silver-bullet.config.json.default")"
    jq -n --arg cv "$cv" --argjson init "$initiated" \
      '{config_version:$cv, sb_initiated:$init, project:{src_pattern:"/src/",active_workflow:"full-dev-cycle"}, skills:{required_planning:["silver-quality-gates"], required_deploy:["silver-quality-gates"]}, state:{state_file:"'"$SB_RUNTIME_STATE_DIR/state"'", trivial_file:"'"$SB_RUNTIME_STATE_DIR/trivial"'"}}' \
      >"$WORK/.silver-bullet.json"
  fi
}

echo "=== project-active.sh unit tests ==="
# shellcheck source=../../hooks/lib/project-active.sh
source "$REPO_ROOT/hooks/lib/project-active.sh"

setup_repo false
cd "$WORK"
cfg="$(sb_find_project_config)"
assert_true "finds config when scaffold present" test -n "$cfg"
assert_false "sb_project_active false when sb_initiated false" sb_project_active "$cfg"
assert_exit0 "sb_project_active_or_exit when not initiated" sb_project_active_or_exit
rm -rf "$WORK"
WORK=""

setup_repo true
cd "$WORK"
cfg="$(sb_find_project_config)"
assert_true "sb_project_active true when initiated" sb_project_active "$cfg"
rm -rf "$WORK"
WORK=""

OTHER=$(mktemp -d)
git -C "$OTHER" init -q
cd "$OTHER"
assert_exit0 "sb_project_active_or_exit with no config" sb_project_active_or_exit
rm -rf "$OTHER"

echo "=== hook integration: inactive project stays inert ==="
PROMPT_HOOK="$REPO_ROOT/hooks/prompt-reminder.sh"
STOP_HOOK="$REPO_ROOT/hooks/stop-check.sh"
SESSION_HOOK="$REPO_ROOT/hooks/session-start"
PLANNING_HOOK="$REPO_ROOT/hooks/planning-file-guard.sh"

setup_repo false
cd "$WORK"
out="$(printf '{}' | jq -c '{hook_event_name:"UserPromptSubmit",prompt:"hello"}' | bash "$PROMPT_HOOK" 2>/dev/null || true)"
assert_no_block "prompt-reminder noop when not initiated" "$out"

out="$(printf '{}' | jq -c '{hook_event_name:"Stop"}' | SILVER_BULLET_STATE_FILE="$SB_RUNTIME_STATE_DIR/state" bash "$STOP_HOOK" 2>/dev/null || true)"
assert_no_block "stop-check noop when not initiated" "$out"

out="$(SILVER_BULLET_SESSION_SOURCE=startup bash "$SESSION_HOOK" </dev/null 2>/dev/null || true)"
if [[ -z "$out" ]]; then
  echo "PASS: session-start silent when not initiated"
  PASS=$((PASS + 1))
else
  echo "FAIL: session-start should not inject context when not initiated (got output)"
  FAIL=$((FAIL + 1))
fi

input=$(jq -n --arg p "$WORK/.planning/ROADMAP.md" '{hook_event_name:"PreToolUse",tool_name:"Write",tool_input:{file_path:$p}}')
out="$(printf '%s' "$input" | bash "$PLANNING_HOOK" 2>/dev/null || true)"
assert_no_block "planning-file-guard noop when not initiated" "$out"

echo "=== hook integration: initiated project may enforce ==="
setup_repo true
cd "$WORK"
mkdir -p "$WORK/.planning/workflows"
printf '| Step | Skill | Status |\n| 1 | silver-quality-gates | pending |\n' >"$WORK/.planning/workflows/full-dev-cycle.md"
PLUGIN_CACHE="${SB_RUNTIME_HOME_ROOT}/plugins/cache"
mkdir -p "${PLUGIN_CACHE}/alo-labs/silver-bullet/test"
out="$(SILVER_BULLET_SESSION_SOURCE=startup \
  SILVER_BULLET_STATE_FILE="$SB_RUNTIME_STATE_DIR/state-init" \
  SILVER_BULLET_BRANCH_FILE="$SB_RUNTIME_STATE_DIR/branch-init" \
  bash "$SESSION_HOOK" </dev/null 2>/dev/null || true)"
assert_has_context "session-start injects context when initiated" "$out"

echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
