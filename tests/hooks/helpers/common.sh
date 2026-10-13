#!/usr/bin/env bash
# Shared fixtures for hook unit tests — git repo, state file, branch file, config.
# shellcheck shell=bash

HOOK_TEST_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
HOOK_TEST_HOOKS_DIR="${HOOK_TEST_REPO_ROOT}/hooks"

if [[ -f "${HOOK_TEST_REPO_ROOT}/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "${HOOK_TEST_REPO_ROOT}/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_RUNTIME="${SILVER_BULLET_RUNTIME:-codex}"
export SB_RUNTIME_HOME_ROOT SB_RUNTIME_STATE_DIR SB_RUNTIME_PLUGIN_CACHE_ROOT SB_RUNTIME_NAME

hook_test_init_counters() {
  HOOK_TEST_PASS="${HOOK_TEST_PASS:-0}"
  HOOK_TEST_FAIL="${HOOK_TEST_FAIL:-0}"
}

hook_test_assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "PASS: $name"
    HOOK_TEST_PASS=$((HOOK_TEST_PASS + 1))
  else
    echo "FAIL: $name (expected '$expected', got '$actual')"
    HOOK_TEST_FAIL=$((HOOK_TEST_FAIL + 1))
  fi
}

hook_test_setup() {
  local run_id="${1:-$$}"
  HOOK_TEST_RUN_ID="$run_id"
  export SB_RUNTIME_PRESERVE_STATE_DIR=1
  export SB_RUNTIME_STATE_DIR="${SB_RUNTIME_HOME_ROOT}/.silver-bullet/hook-test-${run_id}"
  HOOK_TEST_DIR="$SB_RUNTIME_STATE_DIR"
  mkdir -p "$HOOK_TEST_DIR"

  HOOK_TEST_TMPDIR="$(mktemp -d)"
  HOOK_TEST_STATE="${HOOK_TEST_DIR}/test-state-${run_id}"
  HOOK_TEST_BRANCH="${HOOK_TEST_DIR}/test-branch-${run_id}"
  HOOK_TEST_CFG="${HOOK_TEST_TMPDIR}/.silver-bullet.json"
  HOOK_TEST_TRIVIAL="${HOOK_TEST_DIR}/trivial-test-${run_id}"

  git -C "$HOOK_TEST_TMPDIR" init -q
  git -C "$HOOK_TEST_TMPDIR" config user.email "test@test.com"
  git -C "$HOOK_TEST_TMPDIR" config user.name "Test"
  touch "$HOOK_TEST_TMPDIR/.gitkeep"
  git -C "$HOOK_TEST_TMPDIR" add .gitkeep
  git -C "$HOOK_TEST_TMPDIR" commit -q -m "init" 2>/dev/null || true
  git -C "$HOOK_TEST_TMPDIR" checkout -q -b feature/test 2>/dev/null || true
  mkdir -p "$HOOK_TEST_TMPDIR/src"
  touch "$HOOK_TEST_TMPDIR/src/app.js"
  printf '%s\n' '# Silver Bullet' > "$HOOK_TEST_TMPDIR/silver-bullet.md"
  printf 'feature/test\n' > "$HOOK_TEST_BRANCH"

  export SILVER_BULLET_STATE_FILE="$HOOK_TEST_STATE"
  export SILVER_BULLET_BRANCH_FILE="$HOOK_TEST_BRANCH"
  export SILVER_BULLET_TEST_HOOK_ENFORCED=1

  TMPCFG="$HOOK_TEST_CFG"
  TMPSTATE="$HOOK_TEST_STATE"
  TMPDIR_TEST="$HOOK_TEST_TMPDIR"
}

hook_test_teardown() {
  rm -rf "${HOOK_TEST_DIR:-}" "${HOOK_TEST_TMPDIR:-}" 2>/dev/null || true
  unset SILVER_BULLET_STATE_FILE SILVER_BULLET_BRANCH_FILE TMPCFG TMPSTATE TMPDIR_TEST
}

# Minimal SB project boundary files for hook tests (sb_initiated optional via env).
hook_test_stamp_sb_scaffold() {
  local dir="${1:-}"
  [[ -n "$dir" && -d "$dir" ]] || return 0
  if [[ ! -f "$dir/silver-bullet.md" ]]; then
    printf '# Silver Bullet\n' >"$dir/silver-bullet.md"
  fi
  if [[ ! -f "$dir/.silver-bullet.json" ]]; then
    printf '{"project":{}}\n' >"$dir/.silver-bullet.json"
  fi
}

hook_test_write_minimal_config() {
  local workflow="${1:-full-dev-cycle}"
  local config_version
  config_version="$(jq -r '.config_version' "${HOOK_TEST_REPO_ROOT}/templates/silver-bullet.config.json.default")"
  cat > "$HOOK_TEST_CFG" <<EOF
{
  "config_version": "${config_version}",
  "sb_initiated": true,
  "project": { "src_pattern": "/src/", "active_workflow": "${workflow}" },
  "skills": {
    "required_planning": ["silver-quality-gates"],
    "required_deploy": ["silver-quality-gates", "silver-review", "silver-verify", "silver-ship", "verify-tests"],
    "all_tracked": ["silver-quality-gates", "silver-review", "silver-verify", "silver-ship", "verify-tests"]
  },
  "state": {
    "state_file": "${HOOK_TEST_STATE}",
    "trivial_file": "${HOOK_TEST_TRIVIAL}"
  }
}
EOF
}

hook_test_results() {
  echo "Results: ${HOOK_TEST_PASS:-0} passed, ${HOOK_TEST_FAIL:-0} failed"
  [[ "${HOOK_TEST_FAIL:-0}" -eq 0 ]]
}
