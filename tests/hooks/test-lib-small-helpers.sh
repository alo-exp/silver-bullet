#!/usr/bin/env bash
# hooks/lib: jq-gate, hook-output, cert-bypass, path-canonical, github-run-list,
# hook-subproc-timeout.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

LIB="$TL_REPO_ROOT/hooks/lib"
NOJQ="$(tl_path_without jq)"

# ---- jq-gate -------------------------------------------------------------
out="$(PATH="$NOJQ" bash -c 'source "$1"; sb_jq_missing_message' _ "$LIB/jq-gate.sh")"
assert_contains "missing message names jq" "$out" "jq is required"

out="$(bash -c 'source "$1"; sb_jq_enforcement_warn x; echo after' _ "$LIB/jq-gate.sh")"
assert_eq "warn with jq present returns silently" "after" "$out"

out="$(PATH="$NOJQ" bash -c 'source "$1"; sb_jq_enforcement_warn stop-check; echo after' _ "$LIB/jq-gate.sh")"
assert_contains "warn without jq names the hook" "$out" "(stop-check)"
assert_not_contains "warn without jq exits" "$out" "after"

out="$(bash -c 'source "$1"; sb_jq_enforcement_block h emit; echo after' _ "$LIB/jq-gate.sh")"
assert_eq "block with jq present returns" "after" "$out"

out="$(PATH="$NOJQ" bash -c 'source "$1"; emit(){ echo "EMIT:${1:0:20}"; }; sb_jq_enforcement_block h emit; echo after' _ "$LIB/jq-gate.sh")"
assert_contains "block uses the emit function" "$out" "EMIT:"
assert_not_contains "block exits after emit" "$out" "after"

out="$(PATH="$NOJQ" bash -c 'source "$1"; sb_jq_enforcement_block h nosuchfn; echo after' _ "$LIB/jq-gate.sh")"
assert_contains "python fallback emits deny" "$out" '"permissionDecision": "deny"'
assert_contains "python fallback carries message" "$out" "jq is required"
assert_not_contains "python fallback exits" "$out" "after"

NOJQPY="$(tl_path_without jq python3)"
out="$(PATH="$NOJQPY" bash -c 'source "$1"; sb_jq_enforcement_block h; echo after' _ "$LIB/jq-gate.sh")"
assert_eq "printf fallback" '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"jq required for Silver Bullet enforcement"}}' "$out"

# sb_jq_enforcement_block_sb_initiated
out="$(bash -c 'source "$1"; sb_jq_enforcement_block_sb_initiated h emit; echo after' _ "$LIB/jq-gate.sh")"
assert_eq "initiated variant: jq present is a no-op" "after" "$out"

proj="$TL_TMP/proj"
mkdir -p "$proj"
git -C "$proj" init -q
# Not initiated (no config): fail open.
out="$(cd "$proj" && PATH="$NOJQ" SB_RUNTIME_STATE_DIR="$TL_TMP/st" bash -c 'source "$1"; emit(){ echo EMIT; }; sb_jq_enforcement_block_sb_initiated h emit; echo after' _ "$LIB/jq-gate.sh")"
assert_eq "no project: fail open" "after" "$out"

printf '{}' >"$proj/.silver-bullet.json"
printf '# SB\n' >"$proj/silver-bullet.md"
out="$(cd "$proj" && PATH="$NOJQ" SB_RUNTIME_STATE_DIR="$TL_TMP/st" bash -c 'source "$1"; emit(){ echo EMIT; }; sb_jq_enforcement_block_sb_initiated h emit; echo after' _ "$LIB/jq-gate.sh")"
assert_eq "initiated project without jq blocks through emit fn" "EMIT" "$out"

# Library missing: copy jq-gate alone into a temp dir.
mkdir -p "$TL_TMP/solo"
cp "$LIB/jq-gate.sh" "$TL_TMP/solo/"
out="$(cd "$proj" && PATH="$NOJQ" bash -c 'source "$1"; sb_jq_enforcement_block_sb_initiated h emit; echo after' _ "$TL_TMP/solo/jq-gate.sh")"
assert_eq "gate library absent: fail open" "after" "$out"

# ---- hook-output ---------------------------------------------------------
# shellcheck source=../../hooks/lib/hook-output.sh
source "$LIB/hook-output.sh"
if sb_emit_hook_message PostToolUse "" >/dev/null; then tl_fail "empty message rejected"; else tl_pass "empty message rejected"; fi
assert_eq "emit with jq" '{"hookSpecificOutput":{"hookEventName":"PostToolUse","message":"hi \"x\""}}' "$(sb_emit_hook_message PostToolUse 'hi "x"')"
out="$(PATH="$NOJQ" bash -c 'source "$1"; sb_emit_hook_message PreToolUse "a\"b"' _ "$LIB/hook-output.sh")"
assert_eq "emit without jq escapes via python" '{"hookSpecificOutput":{"hookEventName":"PreToolUse","message":"a\"b"}}' "$out"
out="$(PATH="$NOJQPY" bash -c 'source "$1"; sb_emit_hook_message PreToolUse "plain"' _ "$LIB/hook-output.sh")"
assert_eq "emit without jq and python quotes plainly" '{"hookSpecificOutput":{"hookEventName":"PreToolUse","message":"plain"}}' "$out"

if sb_emit_hook_message_json PostToolUse "" >/dev/null; then tl_fail "empty json message rejected"; else tl_pass "empty json message rejected"; fi
assert_eq "emit_json with jq" '{"hookSpecificOutput":{"hookEventName":"Stop","message":"m\n2"}}' "$(sb_emit_hook_message_json Stop '"m\n2"')"
out="$(PATH="$NOJQ" bash -c 'source "$1"; sb_emit_hook_message_json Stop "\"raw\""' _ "$LIB/hook-output.sh")"
assert_eq "emit_json without jq passes json through" '{"hookSpecificOutput":{"hookEventName":"Stop","message":"raw"}}' "$out"

# ---- cert-bypass ---------------------------------------------------------
for v in 1 true; do
  out="$(SB_AGENT_CERT_RUN=$v bash -c 'source "$1"; sb_cert_run_bypass; echo after' _ "$LIB/cert-bypass.sh")"
  assert_eq "cert bypass SB_AGENT_CERT_RUN=$v exits" "" "$out"
done
out="$(SB_AGENT_CERT_RUN=0 bash -c 'source "$1"; sb_cert_run_bypass; echo after' _ "$LIB/cert-bypass.sh")"
assert_eq "cert bypass inactive continues" "after" "$out"
out="$(env -u SB_AGENT_CERT_RUN bash -c 'source "$1"; sb_cert_run_bypass_active || echo inactive' _ "$LIB/cert-bypass.sh")"
assert_eq "cert bypass unset is inactive" "inactive" "$out"

# ---- path-canonical ------------------------------------------------------
# shellcheck source=../../hooks/lib/path-canonical.sh
source "$LIB/path-canonical.sh"
assert_eq "empty path yields nothing" "" "$(sb_canonical_path "")"
mkdir -p "$TL_TMP/real"
ln -s "$TL_TMP/real" "$TL_TMP/link"
assert_eq "symlink resolved" "$TL_TMP/real" "$(sb_canonical_path "$TL_TMP/link")"
tilde_path="~"/x
assert_eq "home expanded" "$HOME/x" "$(sb_canonical_path "$tilde_path")"
assert_eq "python missing: path echoed back" "$TL_TMP/link" "$(PATH="$NOJQPY" bash -c 'source "$1"; sb_canonical_path "$2"' _ "$LIB/path-canonical.sh" "$TL_TMP/link")"

# ---- github-run-list -----------------------------------------------------
# shellcheck source=../../hooks/lib/github-run-list.sh
source "$LIB/github-run-list.sh"
assert_eq "override cmd" '[{"n":1}]' "$(GH_RUN_LIST_OVERRIDE_CMD="echo '[{\"n\":1}]'" sb_github_run_list_json abc)"
assert_eq "override json" '[]' "$(GH_RUN_LIST_OVERRIDE='[]' sb_github_run_list_json abc)"
if PATH="$(tl_path_without gh)" sb_github_run_list_json abc >/dev/null; then tl_fail "no gh fails"; else tl_pass "no gh fails"; fi
tl_stub gh 'echo "gh $*"'
assert_contains "gh with commit" "$(sb_github_run_list_json abc)" "gh run list --commit abc --json"
out="$(sb_github_run_list_json)"
assert_contains "gh without commit" "$out" "gh run list --json"
assert_not_contains "gh without commit has no --commit" "$out" "--commit"

# ---- hook-subproc-timeout ------------------------------------------------
# shellcheck source=../../hooks/lib/hook-subproc-timeout.sh
source "$LIB/hook-subproc-timeout.sh"
inp="$TL_TMP/in"; so="$TL_TMP/so"; se="$TL_TMP/se"
echo payload >"$inp"
cmd=(bash -c 'cat; echo err >&2; exit 3')

run_variant() { # label path
  local label="$1" p="$2" rc=0
  PATH="$p" sb_run_hooked_command 5 "$inp" "$so" "$se" "${cmd[@]}" || rc=$?
  assert_eq "$label: exit status propagated" "3" "$rc"
  assert_eq "$label: stdin delivered" "payload" "$(cat "$so")"
  assert_eq "$label: stderr captured" "err" "$(cat "$se")"
}
run_variant "gnu timeout" "$PATH"
NOTIMEOUT="$(tl_path_without timeout)"
run_variant "python fallback" "$NOTIMEOUT"
NOBOTH="$(tl_path_without timeout python3)"
run_variant "direct fallback" "$NOBOTH"

rc=0; PATH="$NOTIMEOUT" sb_run_hooked_command 0.3 "$inp" "$so" "$se" sleep 5 || rc=$?
assert_eq "python fallback times out with 124" "124" "$rc"
rc=0; PATH="$NOTIMEOUT" sb_run_hooked_command 5 "$inp" "$so" "$se" /nonexistent/cmd || rc=$?
assert_eq "python fallback missing command is 127" "127" "$rc"
rc=0; PATH="$NOTIMEOUT" sb_run_hooked_command 5 "$inp" "$so" "$se" || rc=$?
assert_eq "python fallback without command is 2" "2" "$rc"
rc=0; PATH="$NOTIMEOUT" sb_run_hooked_command 0.3 "$inp" "$so" "$se" bash -c 'trap "" TERM; sleep 5' || rc=$?
assert_eq "python fallback escalates to SIGKILL" "124" "$rc"
rc=0; sb_run_hooked_command 1 "$inp" "$so" "$se" sleep 5 || rc=$?
assert_eq "gnu timeout kills slow command" "124" "$rc"

tl_results
