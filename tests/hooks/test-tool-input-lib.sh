#!/usr/bin/env bash
# hooks/lib/tool-input.sh: payload accessors and their failure fallbacks.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

LIB="$TL_REPO_ROOT/hooks/lib/tool-input.sh"
call() { tl_run bash -c 'source "$1"; shift; "$@"' _ "$LIB" "$@"; }

# --- sb_tool_name / sb_tool_is_shell_like ---------------------------------
call sb_tool_name '{"tool_name":"Bash"}'
assert_eq "tool name read from payload" "Bash" "$TL_OUT"
call sb_tool_name '{}'
assert_eq "missing tool name is empty" "" "$TL_OUT"
call sb_tool_name 'not json'
assert_eq "invalid JSON gives empty tool name" "" "$TL_OUT"
assert_eq "invalid JSON does not fail" 0 "$TL_STATUS"
tl_stub jq 'exit 1'
call sb_tool_name '{"tool_name":"Bash"}'
assert_eq "failing jq gives empty tool name" "" "$TL_OUT"
assert_eq "failing jq does not fail the helper" 0 "$TL_STATUS"
rm -f "$TL_BIN/jq"

for tool in Bash Shell shell exec_command; do
  call sb_tool_is_shell_like "$tool"
  assert_eq "$tool is shell-like" 0 "$TL_STATUS"
done
for tool in Edit Write "" bash; do
  call sb_tool_is_shell_like "$tool"
  assert_eq "'$tool' is not shell-like" 1 "$TL_STATUS"
done

# --- python helper wrappers ----------------------------------------------
call sb_tool_command_string '{"tool_input":{"command":"git status"}}'
assert_eq "command string extracted" "git status" "$TL_OUT"

tl_stub python3 'exit 3'
call sb_tool_command_string '{"tool_input":{"command":"git status"}}'
assert_eq "failing python helper yields empty output" "" "$TL_OUT"
assert_eq "failing python helper is swallowed" 0 "$TL_STATUS"
call sb_shell_command_looks_read_only "ls"
assert_eq "status variant propagates helper failure" 3 "$TL_STATUS"
rm -f "$TL_BIN/python3"

# --- sb_shell_command_unwrap_rtk -----------------------------------------
call sb_shell_command_unwrap_rtk ''
assert_eq "empty payload prints nothing" "" "$TL_OUT"
call sb_shell_command_unwrap_rtk 'RTK_DISABLED=1 rtk git status'
assert_eq "rtk wrapper stripped" "git status" "$TL_OUT"
call sb_shell_command_unwrap_rtk 'rtk'
assert_eq "wrapper-only payload falls back to the original" "rtk" "$TL_OUT"

# --- sb_tool_patch_paths / sb_tool_file_path ------------------------------
patch='*** Begin Patch\n*** Update File: src/a.py\n*** Add File: src/b.py\n*** End Patch'
json="$(jq -cn --arg p "$(printf '%b' "$patch")" '{tool_input:{input:$p}}')"
call sb_tool_patch_paths "$json"
assert_eq "patch paths listed" "src/a.py
src/b.py" "$TL_OUT"
call sb_tool_file_path "$json"
assert_eq "first patch path used when no file_path" "src/a.py" "$TL_OUT"
call sb_tool_file_path '{"tool_input":{"file_path":"/x/y.txt"}}'
assert_eq "tool_input.file_path preferred" "/x/y.txt" "$TL_OUT"
call sb_tool_file_path '{"tool_response":{"filePath":"/x/z.txt"}}'
assert_eq "tool_response.filePath fallback" "/x/z.txt" "$TL_OUT"
tl_stub jq 'exit 1'
call sb_tool_file_path '{"tool_input":{"file_path":"/x/y.txt"}}'
assert_eq "failing jq: no path" "" "$TL_OUT"
rm -f "$TL_BIN/jq"

# --- script / write path helpers -----------------------------------------
mkdir -p "$TL_TMP/work"
printf '#!/bin/sh\n' >"$TL_TMP/work/run.sh"
call sb_shell_invoked_script_path "bash run.sh" "$TL_TMP/work"
assert_eq "invoked script resolved against base dir" "$TL_TMP/work/run.sh" "$TL_OUT"
call sb_shell_candidate_write_paths "echo hi > out.txt" "$TL_TMP/work"
assert_eq "write target resolved against base dir" "$TL_TMP/work/out.txt" "$TL_OUT"
pwd_out="$(cd "$TL_TMP/work" && bash -c 'source "$1"; sb_shell_candidate_write_paths "touch t.txt"' _ "$LIB")"
assert_eq "base dir defaults to PWD" "$TL_TMP/work/t.txt" "$pwd_out"
call sb_shell_command_looks_read_only "ls -la"
assert_eq "read-only verdict" "read-only" "$TL_OUT"
call sb_shell_command_looks_read_only "rm -rf x"
assert_eq "mutating command is not read-only" 1 "$TL_STATUS"

# --- helper directory selection -------------------------------------------
mkdir -p "$TL_TMP/altlib/tool-input"
printf 'print("alt-helper")\n' >"$TL_TMP/altlib/tool-input/tool_command_string.py"
tl_run bash -c '_lib_dir="$2"; source "$1"; sb_tool_command_string x' _ "$LIB" "$TL_TMP/altlib"
assert_eq "_lib_dir with tool-input/ is preferred" "alt-helper" "$TL_OUT"

tl_results
