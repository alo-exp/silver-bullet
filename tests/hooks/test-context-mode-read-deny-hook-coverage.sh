#!/usr/bin/env bash
# Behavior tests for hooks/context-mode-read-deny.sh (PreToolUse Read/Grep size gate)
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
unset SB_AGENT_CERT_RUN SB_KAY_HOOK_BRIDGE_INVOKED CONTEXT_MODE_READ_DENY_BYPASS SB_CONTEXT_MODE_READ_DENY_BYPASS
source "$TL_REPO_ROOT/tests/lib/c-toolgates-1-helpers.sh"
gh_init_project
mkdir -p "$TL_TMP/outside"
HOOK=hooks/context-mode-read-deny.sh

base_cfg() { jq -n "{config_version:\"1\", sb_initiated:true, recommended_tools:{context_mode:{enabled_by_user:true, read_deny_bytes:200}}} | ${1:-.}" >"$GH_CFG"; }
mkfile() { head -c "$2" /dev/zero | tr '\0' 'a' >"$1"; }
read_in() { jq -cn --arg p "$1" --arg e "${2:-PreToolUse}" '{hook_event_name:$e, tool_name:"Read", tool_input:{file_path:$p}}'; }
grep_in() { jq -cn --arg p "$1" '{hook_event_name:"PreToolUse", tool_name:"Grep", tool_input:{pattern:"x", path:$p}}'; }

BIG="$GH_PROJ/src/big.txt"; mkfile "$BIG" 600
SMALL="$GH_PROJ/src/small.txt"; mkfile "$SMALL" 50
base_cfg

gh_run "$HOOK" "$(read_in "$BIG")"
assert_gate_denies "large Read is denied" "CONTEXT MODE — Read blocked"
assert_contains "message has size and threshold" "$(gh_reason)" "600 bytes > 200 byte threshold"
assert_contains "message names the path" "$(gh_reason)" "Path: $BIG"
assert_eq "deny audited with hook name" "context-mode-read-deny" "$(jq -rs 'last.hook_name' "$GH_AUDIT")"
assert_eq "deny audit decision" "deny" "$(jq -rs 'last.decision' "$GH_AUDIT")"
assert_eq "exit status 0" "0" "$TL_STATUS"
gh_run "$HOOK" "$(read_in "src/big.txt")"
assert_gate_denies "relative path resolves against the project" "600 bytes"
gh_run "$HOOK" "$(grep_in "$BIG")"
assert_gate_denies "large Grep target is denied" "CONTEXT MODE — Read blocked"
gh_run "$HOOK" "$(read_in "$BIG" PostToolUse)"
assert_eq "non-PreToolUse event blocks with decision" "block" "$(gh_decision)"
assert_contains "block output has hookSpecificOutput.message" "$(printf '%s' "$TL_OUT" | jq -r '.hookSpecificOutput.message')" "Read blocked"
gh_run "$HOOK" "$(read_in "$BIG")" SB_KAY_HOOK_BRIDGE_INVOKED=1
assert_eq "bridge deny exits 2" "2" "$TL_STATUS"
assert_contains "bridge deny stderr" "$TL_ERR" "Read blocked"

# allowed cases
gh_run "$HOOK" "$(read_in "$SMALL")"; assert_gate_allows "small file allowed"
mkfile "$GH_PROJ/src/edge.txt" 200
gh_run "$HOOK" "$(read_in "$GH_PROJ/src/edge.txt")"; assert_gate_allows "file at threshold allowed"
gh_run "$HOOK" "$(read_in "$GH_PROJ/src/missing.txt")"; assert_gate_allows "missing file allowed"
gh_run "$HOOK" "$(read_in "")"; assert_gate_allows "empty path allowed"
gh_run "$HOOK" "$(jq -cn '{hook_event_name:"PreToolUse", tool_name:"Bash", tool_input:{command:"cat big"}}')"; assert_gate_allows "other tools allowed"
mkfile "$GH_PROJ/silver-bullet.md" 900
gh_run "$HOOK" "$(read_in "$GH_PROJ/.silver-bullet.json")"; assert_gate_allows "exempt SB config allowed"
mkdir -p "$GH_PROJ/graphify-out"; mkfile "$GH_PROJ/graphify-out/graph.json" 900
gh_run "$HOOK" "$(read_in "$GH_PROJ/graphify-out/graph.json")"; assert_gate_allows "graphify graph.json exempt"
base_cfg '.state = {state_file:"'"$GH_PROJ"'/src/statefile"}'
mkfile "$GH_PROJ/src/statefile" 900
gh_run "$HOOK" "$(read_in "$GH_PROJ/src/statefile")"; assert_gate_allows "configured state file exempt"
base_cfg
gh_run "$HOOK" "$(read_in "$BIG")" CONTEXT_MODE_READ_DENY_BYPASS=1; assert_gate_allows "bypass env allows"
gh_run "$HOOK" "$(read_in "$BIG")" SB_CONTEXT_MODE_READ_DENY_BYPASS=true; assert_gate_allows "SB bypass env allows"
base_cfg '.recommended_tools.context_mode.read_deny_bytes = 700'
gh_run "$HOOK" "$(read_in "$BIG")"; assert_gate_allows "raised threshold allows"
base_cfg '.recommended_tools.context_mode.read_deny_bytes = 0'
gh_run "$HOOK" "$(read_in "$BIG")"; assert_gate_allows "zero threshold disables"
base_cfg 'del(.recommended_tools.context_mode.read_deny_bytes)'
mkfile "$GH_PROJ/src/mid.txt" 6000
gh_run "$HOOK" "$(read_in "$GH_PROJ/src/mid.txt")"
assert_gate_denies "default threshold is 5120 bytes" "6000 bytes > 5120 byte threshold"
gh_run "$HOOK" "$(read_in "$BIG")"; assert_gate_allows "600 bytes under default threshold"
base_cfg

# leanctx owning sb_read changes routing for Read and exempts Grep
base_cfg '.recommended_tools.leanctx = {enabled_by_user:true} | .optimization_profiles = {five_tool_routed:{routes:{sb_read:"leanctx"}}}'
gh_run "$HOOK" "$(read_in "$BIG")"
assert_gate_denies "Read denied with LeanCTX routing message" "LEANCTX READ ROUTING"
assert_contains "leanctx message mentions lctx_read_ast" "$(gh_reason)" "lctx_read_ast"
gh_run "$HOOK" "$(grep_in "$BIG")"; assert_gate_allows "Grep stays cooperative when leanctx active"
base_cfg

# consent / project gating
jq '.recommended_tools.context_mode.enabled_by_user = false' "$GH_CFG" >"$GH_CFG.n" && mv "$GH_CFG.n" "$GH_CFG"
gh_run "$HOOK" "$(read_in "$BIG")"; assert_gate_allows "opted out allows"
base_cfg 'del(.recommended_tools.context_mode.enabled_by_user)'
gh_run "$HOOK" "$(read_in "$BIG")"; assert_gate_allows "consent pending allows"
base_cfg '.recommended_tools.context_mode.enforcement_suspended = true'
gh_run "$HOOK" "$(read_in "$BIG")"; assert_gate_allows "suspended enforcement allows"
base_cfg
rm -f "$SB_RUNTIME_STATE_DIR/project-root"
GH_CWD="$TL_TMP/outside" GH_PROJECT_ROOT="" gh_run "$HOOK" "$(read_in "$BIG")"; assert_gate_allows "outside a project allows"
rm -f "$GH_CFG" "$SB_RUNTIME_STATE_DIR/project-root"
gh_run "$HOOK" "$(read_in "$BIG")"; assert_gate_allows "missing project config allows"
printf '{ broken' >"$GH_CFG"
gh_run "$HOOK" "$(read_in "$BIG")"; assert_gate_allows "unparsable project config allows"
base_cfg
printf 'x' >"$SB_RUNTIME_STATE_DIR/trivial"
gh_run "$HOOK" "$(read_in "$BIG")"; assert_gate_allows "trivial marker allows"
rm -f "$SB_RUNTIME_STATE_DIR/trivial"
base_cfg '.state.trivial_file = "~/custom-trivial"'
gh_run "$HOOK" "$(read_in "$BIG")"; assert_gate_denies "configured trivial path absent still denies" "Read blocked"
printf 'x' >"$HOME/custom-trivial"
gh_run "$HOOK" "$(read_in "$BIG")"; assert_gate_allows "configured trivial path (~) allows"
rm -f "$HOME/custom-trivial"
base_cfg
gh_run "$HOOK" ""; assert_gate_allows "empty stdin allows"
gh_run "$HOOK" "garbage"; assert_gate_allows "unparsable stdin allows"
GH_PATH="$(tl_path_without jq)" gh_run "$HOOK" "$(read_in "$BIG")"; assert_gate_allows "missing jq allows"
GH_CWD="$GH_PROJ/src" gh_run "$HOOK" "$(read_in "src/big.txt")"
assert_gate_denies "project discovered from subdirectory (relative path resolves against project root)" "Read blocked"

tl_results
