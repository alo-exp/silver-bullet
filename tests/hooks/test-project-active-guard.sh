#!/usr/bin/env bash
# Tests hooks/lib/project-active.sh and hook fail-open when SB project is absent.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export SILVER_BULLET_RUNTIME="${SILVER_BULLET_RUNTIME:-codex}"
export SB_RUNTIME_PRESERVE_STATE_DIR=1
# shellcheck source=../../hooks/lib/runtime-paths.sh
source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
export SB_RUNTIME_STATE_DIR="${SB_RUNTIME_HOME_ROOT}/.silver-bullet/project-active-guard-test-$$"
export SILVER_BULLET_TEST_HOOK_ENFORCED=1
mkdir -p "$SB_RUNTIME_STATE_DIR"
# Prerequisite probe (session-start) requires a silver-bullet plugin cache directory.
mkdir -p "${SB_RUNTIME_PLUGIN_CACHE_ROOT}/alo-labs/silver-bullet/test"

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

assert_has_enforcement_context() {
  local name="$1" out="$2"
  if printf '%s' "$out" | grep -q 'Core Enforcement Rules'; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name (expected core-rules context injection)"
    FAIL=$((FAIL + 1))
  fi
}

run_session_start() {
  local workdir="$1"
  local hook="${REPO_ROOT}/hooks/session-start"
  (
    cd "$workdir" || exit 1
    SILVER_BULLET_SESSION_SOURCE=startup \
      SILVER_BULLET_STATE_FILE="$SB_RUNTIME_STATE_DIR/state-init" \
      SILVER_BULLET_BRANCH_FILE="$SB_RUNTIME_STATE_DIR/branch-init" \
      bash "$hook" 2>/dev/null <<< '{"source":"startup"}'
  ) || true
}

# with_config=1 writes .silver-bullet.json (no sb_initiated field — presence is sufficient).
setup_repo() {
  local with_config="${1:-0}"
  WORK=$(mktemp -d)
  git -C "$WORK" init -q
  git -C "$WORK" -c user.email="t@t.com" -c user.name="T" commit -q --allow-empty -m init 2>/dev/null || true
  printf '# SB\n' >"$WORK/silver-bullet.md"
  mkdir -p "$WORK/src"
  touch "$WORK/src/app.js"
  if [[ "$with_config" == "1" ]]; then
    local cv
    cv="$(jq -r '.config_version' "$REPO_ROOT/templates/silver-bullet.config.json.default")"
    cat >"$WORK/.silver-bullet.json" <<EOF
{
  "config_version": "${cv}",
  "project": { "src_pattern": "/src/", "active_workflow": "full-dev-cycle" },
  "skills": {
    "required_planning": ["silver-quality-gates"],
    "required_deploy": ["silver-quality-gates"]
  },
  "state": {
    "state_file": "${SB_RUNTIME_STATE_DIR}/state",
    "trivial_file": "${SB_RUNTIME_STATE_DIR}/trivial"
  }
}
EOF
  fi
}

echo "=== project-active.sh unit tests ==="
# shellcheck source=../../hooks/lib/project-active.sh
source "$REPO_ROOT/hooks/lib/project-active.sh"

setup_repo 1
cd "$WORK"
cfg="$(sb_find_project_config)"
assert_true "finds config when scaffold present" test -n "$cfg"
assert_true "sb_project_active true when config present" sb_project_active "$cfg"
rm -rf "$WORK"
WORK=""

setup_repo 0
cd "$WORK"
assert_false "sb_find_project_config absent without config file" sb_find_project_config
assert_exit0 "sb_project_active_or_exit when no config file" sb_project_active_or_exit
rm -rf "$WORK"
WORK=""

OTHER=$(mktemp -d)
git -C "$OTHER" init -q
cd "$OTHER"
assert_exit0 "sb_project_active_or_exit with no project boundary" sb_project_active_or_exit
rm -rf "$OTHER"

echo "=== hook integration: inactive project stays inert ==="
PROMPT_HOOK="$REPO_ROOT/hooks/prompt-reminder.sh"
STOP_HOOK="$REPO_ROOT/hooks/stop-check.sh"
SESSION_HOOK="$REPO_ROOT/hooks/session-start"
PLANNING_HOOK="$REPO_ROOT/hooks/planning-file-guard.sh"

setup_repo 0
cd "$WORK"
out="$(printf '{}' | jq -c '{hook_event_name:"UserPromptSubmit",prompt:"hello"}' | bash "$PROMPT_HOOK" 2>/dev/null || true)"
assert_no_block "prompt-reminder noop without config" "$out"

out="$(printf '{}' | jq -c '{hook_event_name:"Stop"}' | SILVER_BULLET_STATE_FILE="$SB_RUNTIME_STATE_DIR/state" bash "$STOP_HOOK" 2>/dev/null || true)"
assert_no_block "stop-check noop without config" "$out"

out="$(SILVER_BULLET_SESSION_SOURCE=startup bash "$SESSION_HOOK" 2>/dev/null <<< '{"source":"startup"}' || true)"
if [[ -z "$out" ]]; then
  echo "PASS: session-start silent without config"
  PASS=$((PASS + 1))
else
  echo "FAIL: session-start should not inject context without config (got output)"
  FAIL=$((FAIL + 1))
fi

input=$(jq -n --arg p "$WORK/.planning/ROADMAP.md" '{hook_event_name:"PreToolUse",tool_name:"Write",tool_input:{file_path:$p}}')
out="$(printf '%s' "$input" | bash "$PLANNING_HOOK" 2>/dev/null || true)"
assert_no_block "planning-file-guard noop without config" "$out"

echo "=== hook integration: active project may enforce ==="
setup_repo 1
cd "$WORK"
mkdir -p "$WORK/.planning/workflows"
printf '| Step | Skill | Status |\n| 1 | silver-quality-gates | pending |\n' >"$WORK/.planning/workflows/full-dev-cycle.md"
rm -f "${SB_RUNTIME_STATE_DIR}/project-root" 2>/dev/null || true
out="$(run_session_start "$WORK")"
assert_has_context "session-start injects context when config present" "$out"
assert_has_enforcement_context "session-start injects core rules when config present" "$out"

echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
