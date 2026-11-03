#!/usr/bin/env bash
# hooks/lib/shell-analysis.sh: the parse-once loader and its query helpers, the statuses the
# gates fail closed on (parse_failed, helper_unavailable), a 300 KiB payload (R1-05, R2-03,
# R3-10), a host without python3 (R1-06), and the legacy tool-input.sh accessors reusing one
# load instead of starting python3 again (R2-34, R3-19).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

LIB="$TL_REPO_ROOT/hooks/lib"
WORK="$TL_TMP/work"
mkdir -p "$WORK"
printf 'echo hi\n' >"$WORK/run.sh"
REAL_PY="$(command -v python3)"

# drive <bash code>: run code in a shell that sourced tool-input.sh (and so shell-analysis.sh).
drive() { tl_run bash -c 'cd "$1" && source "$2/tool-input.sh" && eval "$3"' _ "$WORK" "$LIB" "$1"; }
bash_payload() { printf '%s' "$1" | jq -Rsc '{tool_name:"Bash",tool_input:{command:.}}'; }

# ── a shell payload: every exported value ─────────────────────────────────────────
P="$(bash_payload 'git push -u origin HEAD && gh pr create --fill')"
drive "sb_tool_input_load '$P'; for v in SB_TI_STATUS SB_TI_TOOL_NAME SB_TI_TOOL_KIND SB_SA_ACTIONS SB_SA_TIER \
  SB_SA_POSSIBLE_TIER SB_SA_COULD_BE_DELIVERY SB_SA_OPAQUE SB_SA_READ_ONLY SB_SA_READ_ONLY_LEGACY SB_SA_SKILL_ADAPTER; do
  printf '%s=%s\n' \"\$v\" \"\${!v}\"; done; printf 'cmd=%s\nfirst=%s\n' \"\$SB_TI_COMMAND\" \"\$SB_SA_LEGACY_FIRST_LINE\"
  printf 'json=%s\n' \"\$(jq -r .schema <<<\"\$SB_SA_JSON\")\"; sb_tool_input_ok && echo ok-true"
for want in SB_TI_STATUS=ok SB_TI_TOOL_NAME=Bash SB_TI_TOOL_KIND=shell "SB_SA_ACTIONS=pr_create push" \
  SB_SA_TIER=completion SB_SA_POSSIBLE_TIER=none SB_SA_COULD_BE_DELIVERY=false SB_SA_OPAQUE=false \
  SB_SA_READ_ONLY=false SB_SA_READ_ONLY_LEGACY=false SB_SA_SKILL_ADAPTER=false \
  "cmd=git push -u origin HEAD && gh pr create --fill" "first=gh pr create [gh pr create --fill]" json=1 ok-true; do
  assert_contains "load: $want" "$TL_OUT" "$want"
done

# ── query helpers ─────────────────────────────────────────────────────────────────
drive 'sb_shell_analysis_load "\$X commit -m x"; sb_shell_analysis_has_action commit && echo has;
  sb_shell_analysis_may_deliver commit && echo may; sb_shell_analysis_may_deliver push || echo not-push;
  echo "tier=$(sb_shell_analysis_effective_tier) opaque=$SB_SA_OPAQUE reasons=$SB_SA_OPAQUE_REASONS"'
assert_not_contains "possible action is not an action" "$TL_OUT" "has"
assert_contains "possible action may deliver" "$TL_OUT" "may"
assert_contains "other actions may not" "$TL_OUT" "not-push"
assert_contains "effective tier includes the possible tier" "$TL_OUT" "tier=intermediate opaque=true"
assert_contains "reasons are listed" "$TL_OUT" 'reasons=dynamic command word: $X'
drive 'sb_shell_analysis_load "git push && npm publish"; echo "$(sb_shell_analysis_effective_tier)";
  sb_shell_analysis_load "ls"; echo "$(sb_shell_analysis_effective_tier)"'
assert_eq "effective tier: completion then none" $'completion\nnone' "$TL_OUT"

# ── base directory and the legacy views ───────────────────────────────────────────
drive 'sb_shell_analysis_load "echo x > a.txt; bash run.sh; rtk ls" "$PWD"; printf "%s|%s|%s|%s\n" \
  "$SB_SA_WRITE_PATHS" "$SB_SA_INVOKED_SCRIPT" "$SB_SA_RTK_UNWRAPPED" "$SB_TI_STATUS"'
assert_eq "command load: write paths, script, unwrap" "$WORK/a.txt|$WORK/run.sh||ok" "$TL_OUT"
drive 'sb_shell_analysis_load "rtk git status"; echo "$SB_SA_RTK_UNWRAPPED"'
assert_eq "rtk prefix removed" "git status" "$TL_OUT"

# ── statuses the gates fail closed on ─────────────────────────────────────────────
drive 'sb_tool_input_load ""; echo "$SB_TI_STATUS"; sb_tool_input_ok || echo not-ok'
assert_eq "empty payload" $'empty\nnot-ok' "$TL_OUT"
drive 'sb_tool_input_load "{not json"; echo "$SB_TI_STATUS|$SB_TI_ERROR"'
assert_eq "invalid JSON: parse_failed" "parse_failed|hook payload is not a JSON object" "$TL_OUT"
bash_payload "git commit -m 'oops" >"$TL_TMP/bad.json"
drive "sb_tool_input_load \"\$(cat '$TL_TMP/bad.json')\"; echo \"\$SB_TI_STATUS|\$SB_TI_ERROR\""
assert_eq "bad shell syntax: parse_failed" "parse_failed|unterminated single quote" "$TL_OUT"
NOPY="$(tl_path_without python3)"
tl_run env PATH="$NOPY" bash -c 'source "$1/tool-input.sh"; sb_tool_input_load "{}"; echo "$SB_TI_STATUS|$SB_TI_ERROR|$SB_SA_TIER";
  sb_shell_analysis_helper_message' _ "$LIB"
assert_contains "no python3: helper_unavailable (R1-06)" "$TL_OUT" "helper_unavailable|python3 is not installed or not on PATH|none"
assert_contains "no python3: message says how to proceed" "$TL_OUT" "python3 is a required prerequisite"
tl_stub python3 'exit 9'
drive 'sb_tool_input_load "{}"; echo "$SB_TI_STATUS|$SB_TI_ERROR"'
assert_contains "broken python3: helper_unavailable" "$TL_OUT" "helper_unavailable|the python3 helper failed"
rm -f "$TL_BIN/python3"
tl_run bash -c 'source "$1/shell-analysis.sh"; SB_TI_ERROR=""; sb_shell_analysis_helper_message' _ "$LIB"
assert_contains "message without a recorded reason" "$TL_OUT" "the python3 helper is unavailable"

# ── 300 KiB payload: stdin transport, no argv limit (R1-05, R2-03, R3-10) ─────────
BIG="$(bash_payload "git commit -m x # $(head -c 307200 /dev/zero | tr '\0' 'a')")"
printf '%s' "$BIG" >"$TL_TMP/big.json"
tl_run bash -c 'source "$1/tool-input.sh"; p="$(cat "$2")"; sb_tool_input_load "$p";
  echo "$SB_TI_STATUS|$SB_SA_ACTIONS|${#SB_TI_COMMAND}"; c="$(sb_tool_command_string "$p")"; echo "legacy=${#c}"
  unset -f _sb_sa_loaded_payload; c="$(sb_tool_command_string "$p")"; echo "fresh=${#c}"' _ "$LIB" "$TL_TMP/big.json"
assert_contains "300 KiB payload analysed" "$TL_OUT" "ok|commit|307218"
assert_contains "300 KiB command from the load" "$TL_OUT" "legacy=307218"
assert_contains "300 KiB command through the stdin helper" "$TL_OUT" "fresh=307218"

# ── other tool kinds ──────────────────────────────────────────────────────────────
drive 'sb_tool_input_load "{\"tool_name\":\"mcp__github__merge_pull_request\",\"tool_input\":{}}";
  echo "$SB_TI_TOOL_KIND|$SB_SA_ACTIONS|$SB_SA_TIER"'
assert_eq "MCP tool classified by name" "mcp|pr_merge|completion" "$TL_OUT"
PATCH="$(jq -cn --arg p $'*** Begin Patch\n*** Update File: src/a.js\n*** Add File: b.js\n*** End Patch' \
  '{tool_name:"apply_patch",tool_input:{input:$p}}')"
drive "sb_tool_input_load '$PATCH'; printf '%s|%s|%s\n' \"\$SB_TI_TOOL_KIND\" \"\$SB_TI_FILE_PATH\" \"\${SB_TI_PATCH_PATHS//\$'\n'/,}\""
assert_eq "apply_patch paths" "patch|src/a.js|src/a.js,b.js" "$TL_OUT"

# ── sb_shell_analysis_invokes (real invocations, not mentions) ─────────────────────
drive 'sb_shell_analysis_load "node gsd-tools.cjs phases clear --raw"; sb_shell_analysis_invokes gsd-tools phases clear && echo yes'
assert_eq "interpreter script with leading args" "yes" "$TL_OUT"
drive 'sb_shell_analysis_load "gsd-tools phases clear"; sb_shell_analysis_invokes gsd-tools phases clear && echo yes'
assert_eq "program with leading args" "yes" "$TL_OUT"
drive 'sb_shell_analysis_load "git commit -m \"phases clear\""; sb_shell_analysis_invokes gsd-tools phases clear || echo no'
assert_eq "a mention in a message is not an invocation" "no" "$TL_OUT"
drive 'sb_shell_analysis_load "gsd-tools phases list"; sb_shell_analysis_invokes gsd-tools phases clear || echo no'
assert_eq "other arguments do not match" "no" "$TL_OUT"
drive 'sb_shell_analysis_load "/opt/bin/gsd-tools"; sb_shell_analysis_invokes gsd-tools && echo yes'
assert_eq "program by basename, no arguments required" "yes" "$TL_OUT"
drive 'sb_shell_analysis_load "echo gsd-tools phases clear"; sb_shell_analysis_invokes gsd-tools phases clear || echo no'
assert_eq "an argument of another program is not an invocation" "no" "$TL_OUT"
tl_run env PATH="$(tl_path_without jq)" bash -c 'source "$1/shell-analysis.sh"; SB_SA_JSON="{}"; sb_shell_analysis_invokes x || echo no' _ "$LIB"
assert_eq "no jq: never matches" "no" "$TL_OUT"

# ── legacy accessors reuse one load (one python3 start per hook) ──────────────────
tl_stub python3 "printf 'x\n' >>'$TL_TMP/py-calls'; exec '$REAL_PY' \"\$@\""
: >"$TL_TMP/py-calls"
CMD='echo x > a.txt; bash run.sh; rtk ls'
P="$(bash_payload "$CMD")"
drive "sb_tool_input_load '$P' \"\$PWD\"
  sb_tool_command_string '$P'; echo
  sb_tool_patch_paths '$P'
  sb_shell_candidate_write_paths '$CMD' \"\$PWD\"
  sb_shell_invoked_script_path '$CMD' \"\$PWD\"
  sb_shell_command_looks_read_only '$CMD' || echo not-ro
  sb_shell_command_unwrap_rtk '$CMD'; echo"
assert_eq "one python3 start for the load and six accessors" 1 "$(wc -l <"$TL_TMP/py-calls" | tr -d ' ')"
assert_eq "accessors answer from the load" "$CMD
$WORK/a.txt
$WORK/run.sh
not-ro
$CMD" "$TL_OUT"
: >"$TL_TMP/py-calls"
drive "sb_shell_analysis_load 'ls' \"\$PWD\"
  sb_shell_command_looks_read_only 'ls'; sb_shell_candidate_write_paths 'ls'; sb_shell_invoked_script_path 'ls'
  sb_shell_command_unwrap_rtk 'rtk ls'; echo; sb_shell_candidate_write_paths 'ls' /elsewhere; sb_tool_patch_paths '{}'"
assert_eq "different input or base dir starts python3 again" 4 "$(wc -l <"$TL_TMP/py-calls" | tr -d ' ')"
assert_eq "cached read-only verdict and fresh answers" $'read-only\nls' "$TL_OUT"
P2="$(jq -cn '{tool_name:"Write",tool_input:{file_path:"/x"}}')"
: >"$TL_TMP/py-calls"
drive "sb_tool_input_load '$P2'; sb_tool_patch_paths '$P2'; sb_tool_file_path '$P2'"
assert_eq "cached empty patch paths" "/x" "$TL_OUT"
assert_eq "patch paths answered from the load" 1 "$(wc -l <"$TL_TMP/py-calls" | tr -d ' ')"
rm -f "$TL_BIN/python3"

# ── helpers that must never fail, and patch paths answered from a load ─────────────
drive "_sb_tool_input_py no-such-helper.py x; echo \"rc=\$?\""
assert_eq "_sb_tool_input_py swallows a failing helper" "rc=0" "$TL_OUT"
P3="$(jq -cn '{tool_name:"apply_patch",tool_input:{input:"*** Begin Patch\n*** Add File: src/new.py\n+x\n*** End Patch"}}')"
drive "sb_tool_input_load '$P3'; sb_tool_patch_paths '$P3'"
assert_eq "patch paths come from the load" "src/new.py" "$TL_OUT"

tl_results
