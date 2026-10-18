#!/usr/bin/env bash
# Self-tests for tests/lib/testlib.sh.
set -euo pipefail
# shellcheck source=testlib.sh
source "$(dirname "${BASH_SOURCE[0]}")/testlib.sh"

real_home="$HOME"
tl_init codex

assert_eq "HOME is sandboxed" "$TL_TMP/home" "$HOME"
assert_eq "runtime home root follows the sandbox" "$HOME/.codex" "$SB_RUNTIME_HOME_ROOT"
assert_file_exists "runtime state dir created" "$SB_RUNTIME_STATE_DIR"
if [[ "$SB_RUNTIME_HOME_ROOT" != "$real_home"* ]]; then
  tl_pass "runtime root is outside the real home"
else
  tl_fail "runtime root is outside the real home ($SB_RUNTIME_HOME_ROOT)"
fi

tl_stub fakecmd 'echo "fake:$*"; exit 3'
tl_run fakecmd a b
assert_eq "stub output captured" "fake:a b" "$TL_OUT"
assert_eq "stub status captured" "3" "$TL_STATUS"

tl_run_stdin "hello" cat
assert_eq "stdin passed through" "hello" "$TL_OUT"
tl_run_stdin $'a\nb' cat
assert_eq "stdin passed byte for byte (no added newline)" "$(printf 'a\nb' | od -c)" "$(printf '%s' "$TL_OUT" | od -c)"
# A command that exits without reading its input must report its own status,
# not SIGPIPE (141) from the writer; input larger than a pipe buffer makes the
# race deterministic.
tl_run_stdin "$(head -c 200000 /dev/zero | tr '\0' a)" bash -c 'exit 3'
assert_eq "status is the command's even when it ignores stdin" "3" "$TL_STATUS"
tl_run_stdin "$(head -c 200000 /dev/zero | tr '\0' a)" true
assert_eq "early exit without reading stdin is status 0" "0" "$TL_STATUS"

tl_run bash -c 'echo err >&2; exit 1'
assert_eq "stderr captured" "err" "$TL_ERR"

no_jq="$(tl_path_without jq)"
if PATH="$no_jq" command -v jq >/dev/null 2>&1; then
  tl_fail "tl_path_without hides jq"
else
  tl_pass "tl_path_without hides jq"
fi
if PATH="$no_jq" command -v bash >/dev/null 2>&1; then
  tl_pass "tl_path_without keeps other commands"
else
  tl_fail "tl_path_without keeps other commands"
fi

json="$(tl_hook_json PreToolUse Bash 'git push')"
assert_eq "hook json tool name" "Bash" "$(jq -r .tool_name <<<"$json")"
assert_eq "hook json command" "git push" "$(jq -r .tool_input.command <<<"$json")"
json="$(tl_hook_json PostToolUse Edit src/app.js '{"old_string":"a"}')"
assert_eq "hook json file path" "src/app.js" "$(jq -r .tool_input.file_path <<<"$json")"
assert_eq "hook json extra fields merged" "a" "$(jq -r .tool_input.old_string <<<"$json")"

tl_git_repo "$TL_TMP/repo"
assert_eq "git repo on feature branch" "feature/test" "$(git -C "$TL_TMP/repo" branch --show-current)"

assert_match "assert_match works" '^v[0-9]+$' "v12"

# Failure reporting: a sub-shell with a failing assertion must make tl_results fail.
rc=0
(
  # shellcheck disable=SC2034  # counters read by tl_results in the sourced testlib.sh
  TL_PASS=0 TL_FAIL=0
  assert_eq "deliberate mismatch" a b >/dev/null
  tl_results >/dev/null
) || rc=$?
assert_eq "tl_results fails when an assertion failed" "1" "$rc"

tl_results
