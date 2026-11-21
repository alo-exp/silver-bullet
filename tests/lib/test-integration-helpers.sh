#!/usr/bin/env bash
# Self-tests for tests/integration/helpers/common.sh: "allowed" must mean the hook ran and let the
# call through, and the helpers must leave nothing in a real runtime home.
set -euo pipefail
# shellcheck source=testlib.sh
source "$(dirname "${BASH_SOURCE[0]}")/testlib.sh"
tl_init

HELPER="$TL_REPO_ROOT/tests/integration/helpers/common.sh"

# run_scenario <body>: source the helper in a fresh shell with the sandbox HOME, run <body>, print its output.
run_scenario() {
  tl_run env -u SB_RUNTIME_HOME_ROOT -u SB_RUNTIME_STATE_DIR bash -c '
    set -u
    source "$1"
    integration_setup
    write_default_config
    '"$1"'
    integration_teardown' _ "$HELPER"
}

# the real gate blocks, and a clean allow passes
run_scenario 'out=$(run_completion_audit PreToolUse "gh pr create --fill"); assert_blocked "real hook blocks" "$out"
out=$(run_completion_audit PreToolUse "echo hello"); assert_allowed "a harmless command is allowed" "$out"'
assert_contains "the real gate still blocks" "$TL_OUT" "PASS: real hook blocks"
assert_contains "a harmless command is still allowed" "$TL_OUT" "PASS: a harmless command is allowed"

# R15-03: a missing hook, a crash and a shell error are not "allowed"
run_scenario 'HOOKS_DIR=/nonexistent
out=$(run_completion_audit PreToolUse "gh pr create --fill"); assert_allowed "missing hook" "$out"'
assert_contains "a missing hook is not allowed" "$TL_OUT" "FAIL: missing hook (expected allow, but hook exited 127: hook not found"

stubs="$TL_TMP/stubs"
mkdir -p "$stubs"
printf 'exit 1\n' >"$stubs/completion-audit.sh"
run_scenario 'HOOKS_DIR='"$stubs"'
out=$(run_completion_audit PreToolUse "echo hi") || true; assert_allowed "crashing hook" "$out"'
assert_contains "a hook that exits non-zero is not allowed" "$TL_OUT" "FAIL: crashing hook (expected allow, but hook exited 1"

printf 'if then fi\n' >"$stubs/completion-audit.sh"
run_scenario 'HOOKS_DIR='"$stubs"'
out=$(run_completion_audit PreToolUse "echo hi") || true; assert_allowed "syntax error hook" "$out"'
assert_contains "a hook with a syntax error is not allowed" "$TL_OUT" "FAIL: syntax error hook (expected allow, but hook exited 2"

printf 'echo "completion-audit.sh: line 4: frobnicate: command not found" >&2\nexit 0\n' >"$stubs/completion-audit.sh"
run_scenario 'HOOKS_DIR='"$stubs"'
out=$(run_completion_audit PreToolUse "echo hi"); assert_allowed "failing command in a hook" "$out"'
assert_contains "a shell error on stderr is not allowed even with exit 0" "$TL_OUT" "FAIL: failing command in a hook (expected allow, but hook reported a shell error"

printf 'echo "note: a harmless warning" >&2\nexit 0\n' >"$stubs/completion-audit.sh"
run_scenario 'HOOKS_DIR='"$stubs"'
out=$(run_completion_audit PreToolUse "echo hi"); assert_allowed "warning only" "$out"'
assert_contains "ordinary stderr output does not fail an allow" "$TL_OUT" "PASS: warning only"

run_scenario 'out=$(run_completion_audit PreToolUse "gh pr create --fill"); assert_blocked "first" "$out"
assert_allowed "an output that did not come from a hook run is checked on its output alone" ""'
assert_contains "a consumed run status is not reused by the next assertion" "$TL_OUT" "PASS: an output that did not come from a hook run"

# the status checked is that of the run whose output is asserted, not of the latest run
printf 'echo CRASHED-OUTPUT\nexit 3\n' >"$stubs/completion-audit.sh"
printf 'exit 0\n' >"$stubs/record-skill.sh"
run_scenario 'HOOKS_DIR='"$stubs"'
a=$(run_completion_audit PreToolUse "x") || true
b=$(run_record_skill silver-quality-gates)
assert_allowed "the earlier crashed run" "$a"
assert_allowed "the later clean run" "$b"'
assert_contains "an earlier crashed run is judged by its own status" "$TL_OUT" "FAIL: the earlier crashed run (expected allow, but hook exited 3"
assert_contains "a later clean run is not blamed on the crash" "$TL_OUT" "PASS: the later clean run"
run_scenario 'a=$(run_record_skill silver-quality-gates)
HOOKS_DIR=/nonexistent
b=$(run_completion_audit PreToolUse "echo hi") || true
assert_allowed "clean run before a missing hook" "$a"'
assert_contains "a clean run is not failed by a later missing hook" "$TL_OUT" "PASS: clean run before a missing hook"

# R15-09: sourcing and running a scenario leave nothing in the runtime home
fresh_home="$TL_TMP/fresh-home"
mkdir -p "$fresh_home"
tl_run env HOME="$fresh_home" bash -c 'source "$1"; ' _ "$HELPER"
assert_eq "sourcing the helper creates nothing in the runtime home" "" "$(find "$fresh_home" -mindepth 1 | head -3)"
tl_run env HOME="$fresh_home" bash -c 'source "$1"; integration_setup; test -d "$SB_RUNTIME_HOME_ROOT/plugins/cache/alo-labs/silver-bullet/test" && echo stub-present; integration_teardown' _ "$HELPER"
assert_contains "setup provides the plugin-cache stand-in" "$TL_OUT" "stub-present"
assert_eq "setup plus teardown leave no file and no plugin-cache stub behind" "" "$(find "$fresh_home" -mindepth 1 \( -type f -o -path '*plugins*' \) | head -3)"
# a stand-in that was already there is not removed
pre="$fresh_home/.claude/plugins/cache/alo-labs/silver-bullet/test"
mkdir -p "$pre"
tl_run env HOME="$fresh_home" SILVER_BULLET_RUNTIME=claude bash -c 'source "$1"; integration_setup; integration_teardown' _ "$HELPER"
assert_file_exists "a pre-existing plugin-cache directory survives teardown" "$pre"

# R15-01: the helper scrubs host-state variables before computing its paths
tl_run env SILVER_BULLET_RUNTIME=codex KAY_HOME="$TL_TMP/real-kay" HOME="$fresh_home" bash -c 'source "$1"; echo "ROOT=$SB_RUNTIME_HOME_ROOT"' _ "$HELPER"
assert_contains "a codex runtime root is under HOME, not KAY_HOME" "$TL_OUT" "ROOT=$fresh_home/.codex"
assert_file_absent "KAY_HOME is never created" "$TL_TMP/real-kay"
tl_run env SILVER_BULLET_RUNTIME=pi PI_CODING_AGENT_DIR="$TL_TMP/real-pi" HOME="$fresh_home" bash -c 'source "$1"; echo "ROOT=$SB_RUNTIME_HOME_ROOT"' _ "$HELPER"
assert_contains "a pi runtime root is under HOME, not PI_CODING_AGENT_DIR" "$TL_OUT" "ROOT=$fresh_home/.pi/agent"

# the hook-test helper scrubs the same way
tl_run env SILVER_BULLET_RUNTIME=codex KAY_HOME="$TL_TMP/real-kay" GIT_INDEX_FILE="$TL_TMP/idx" HOME="$fresh_home" \
  bash -c 'source "$1/tests/hooks/helpers/common.sh"; hook_test_setup scrub; echo "ROOT=$SB_RUNTIME_HOME_ROOT IDX=${GIT_INDEX_FILE:-}"' _ "$TL_REPO_ROOT"
assert_contains "the hook-test helper keeps a codex runtime root under HOME" "$TL_OUT" "ROOT=$fresh_home/.codex IDX="
assert_file_absent "and never touches KAY_HOME" "$TL_TMP/real-kay"
assert_file_absent "nor the caller's git index" "$TL_TMP/idx"

tl_results
