#!/usr/bin/env bash
# Behavior tests for hooks/context-mode-read-deny.sh (PreToolUse Read/Grep size gate)
set -euo pipefail
# The opt-in gates act only on the user's own consent, never on .silver-bullet.json alone.
# shellcheck source=../lib/consent-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/consent-helpers.sh"
sb_test_consent_grant_all
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude
unset SB_AGENT_CERT_RUN SB_KAY_HOOK_BRIDGE_INVOKED CONTEXT_MODE_READ_DENY_BYPASS SB_CONTEXT_MODE_READ_DENY_BYPASS
source "$TL_REPO_ROOT/tests/lib/c-toolgates-1-helpers.sh"
gh_init_project
mkdir -p "$TL_TMP/outside"
HOOK=hooks/context-mode-read-deny.sh

base_cfg() { jq -n "{config_version:\"1\", sb_initiated:true, recommended_tools:{context_mode:{enabled_by_user:true}}} | ${1:-.}" >"$GH_CFG"; }
# Context Mode is installed and wired (the nudge only fires when its ctx_* tools exist).
ART="$TL_TMP/cm-art"; printf '{"mcpServers":{"context-mode":{}}}' >"$ART"; export SB_CONTEXT_MODE_MCP_ARTIFACT="$ART"
tl_stub context-mode 'exit 0'; hash -r
# Consent for Context Mode only: with LeanCTX consent as well, Grep is left to LeanCTX.
ALL_CONSENT="$XDG_CONFIG_HOME"
sb_test_consent_sandbox; sb_test_consent_grant context_mode install,wire,enforce
CM_ONLY="$XDG_CONFIG_HOME"; export XDG_CONFIG_HOME="$ALL_CONSENT"
# A denied Read is acknowledged for 30 minutes; forget that before every run.
run_deny() { rm -rf "$SB_RUNTIME_STATE_DIR/context-mode-read-acks"; gh_run "$@"; }
mkfile() { head -c "$2" /dev/zero | tr '\0' 'a' >"$1"; }
read_in() { jq -cn --arg p "$1" --arg e "${2:-PreToolUse}" '{hook_event_name:$e, tool_name:"Read", tool_input:{file_path:$p}}'; }
grep_in() { jq -cn --arg p "$1" '{hook_event_name:"PreToolUse", tool_name:"Grep", tool_input:{pattern:"x", path:$p}}'; }

BIG="$GH_PROJ/src/big.txt"; mkfile "$BIG" 9000
SMALL="$GH_PROJ/src/small.txt"; mkfile "$SMALL" 50
base_cfg

run_deny "$HOOK" "$(read_in "$BIG")"
assert_gate_denies "large Read is denied" "large Read redirected once"
assert_contains "message has size and threshold" "$(gh_reason)" "9000 bytes > 5120 byte threshold"
assert_contains "message names the path" "$(gh_reason)" "Path: $BIG"
assert_eq "deny audited with hook name" "context-mode-read-deny" "$(jq -rs 'last.hook_name' "$GH_AUDIT")"
assert_eq "deny audit decision" "deny" "$(jq -rs 'last.decision' "$GH_AUDIT")"
assert_eq "exit status 0" "0" "$TL_STATUS"
run_deny "$HOOK" "$(read_in "src/big.txt")"
assert_gate_denies "relative path resolves against the project" "9000 bytes"
run_deny "$HOOK" "$(grep_in "$BIG")"
assert_gate_allows "Grep that lists files is allowed"
run_deny "$HOOK" "$(jq -cn --arg p "$BIG" '{hook_event_name:"PreToolUse", tool_name:"Grep", tool_input:{pattern:"x", path:$p, output_mode:"content"}}')" XDG_CONFIG_HOME="$CM_ONLY"
assert_gate_denies "large Grep with content output is denied" "large Read redirected once"
# repeating the same Read within the window is allowed (Edit needs the exact bytes)
run_deny "$HOOK" "$(read_in "$BIG")"
assert_gate_denies "first Read is redirected" "large Read redirected once"
gh_run "$HOOK" "$(read_in "$BIG")"
assert_gate_allows "the repeated Read is allowed"
run_deny "$HOOK" "$(read_in "$BIG" PostToolUse)"
assert_eq "non-PreToolUse event blocks with decision" "block" "$(gh_decision)"
assert_contains "block output has hookSpecificOutput.message" "$(printf '%s' "$TL_OUT" | jq -r '.hookSpecificOutput.message')" "large Read redirected once"
run_deny "$HOOK" "$(read_in "$BIG")" SB_KAY_HOOK_BRIDGE_INVOKED=1
assert_eq "bridge deny exits 2" "2" "$TL_STATUS"
assert_contains "bridge deny stderr" "$TL_ERR" "large Read redirected once"

# allowed cases
run_deny "$HOOK" "$(read_in "$SMALL")"; assert_gate_allows "small file allowed"
mkfile "$GH_PROJ/src/edge.txt" 200
run_deny "$HOOK" "$(read_in "$GH_PROJ/src/edge.txt")"; assert_gate_allows "file at threshold allowed"
run_deny "$HOOK" "$(read_in "$GH_PROJ/src/missing.txt")"; assert_gate_allows "missing file allowed"
run_deny "$HOOK" "$(read_in "")"; assert_gate_allows "empty path allowed"
run_deny "$HOOK" "$(jq -cn '{hook_event_name:"PreToolUse", tool_name:"Bash", tool_input:{command:"cat big"}}')"; assert_gate_allows "other tools allowed"
mkfile "$GH_PROJ/silver-bullet.md" 900
run_deny "$HOOK" "$(read_in "$GH_PROJ/.silver-bullet.json")"; assert_gate_allows "exempt SB config allowed"
mkdir -p "$GH_PROJ/graphify-out"; mkfile "$GH_PROJ/graphify-out/graph.json" 900
run_deny "$HOOK" "$(read_in "$GH_PROJ/graphify-out/graph.json")"; assert_gate_allows "graphify graph.json exempt"
base_cfg '.state = {state_file:"'"$GH_PROJ"'/src/statefile"}'
mkfile "$GH_PROJ/src/statefile" 900
run_deny "$HOOK" "$(read_in "$GH_PROJ/src/statefile")"; assert_gate_allows "configured state file exempt"
base_cfg
run_deny "$HOOK" "$(read_in "$BIG")" CONTEXT_MODE_READ_DENY_BYPASS=1; assert_gate_allows "bypass env allows"
run_deny "$HOOK" "$(read_in "$BIG")" SB_CONTEXT_MODE_READ_DENY_BYPASS=true; assert_gate_allows "SB bypass env allows"
base_cfg '.recommended_tools.context_mode.read_deny_bytes = 20000'
run_deny "$HOOK" "$(read_in "$BIG")"; assert_gate_allows "raised threshold allows"
base_cfg '.recommended_tools.context_mode.read_deny_bytes = 300'
run_deny "$HOOK" "$(read_in "$GH_PROJ/src/small.txt")"; assert_gate_allows "a lowered threshold is not honoured (the project cannot add blocking)"
base_cfg '.recommended_tools.context_mode.read_deny_bytes = 0'
run_deny "$HOOK" "$(read_in "$BIG")"; assert_gate_allows "zero threshold disables"
base_cfg 'del(.recommended_tools.context_mode.read_deny_bytes)'
mkfile "$GH_PROJ/src/mid.txt" 6000
run_deny "$HOOK" "$(read_in "$GH_PROJ/src/mid.txt")"
assert_gate_denies "default threshold is 5120 bytes" "6000 bytes > 5120 byte threshold"
mkfile "$GH_PROJ/src/under.txt" 5000
run_deny "$HOOK" "$(read_in "$GH_PROJ/src/under.txt")"; assert_gate_allows "5000 bytes under default threshold"
mkfile "$GH_PROJ/shot.png" 9000
run_deny "$HOOK" "$(read_in "$GH_PROJ/shot.png")"; assert_gate_allows "images are never redirected"
printf 'aaaaaaaaaa\n%.0s' $(seq 1 900) >"$GH_PROJ/src/lines.txt"
run_deny "$HOOK" "$(jq -cn --arg p "$GH_PROJ/src/lines.txt" '{hook_event_name:"PreToolUse", tool_name:"Read", tool_input:{file_path:$p, limit:5}}')"
assert_gate_allows "a Read with a small limit is allowed"
# Context Mode not installed or not wired: Read is the only way to read, so it is never redirected
rm -f "$TL_BIN/context-mode"; hash -r
run_deny "$HOOK" "$(read_in "$BIG")"; assert_gate_allows "no Context Mode CLI: no redirect"
tl_stub context-mode 'exit 0'; hash -r
printf '{}' >"$ART"
run_deny "$HOOK" "$(read_in "$BIG")"; assert_gate_allows "Context Mode not wired: no redirect"
printf '{"mcpServers":{"context-mode":{}}}' >"$ART"
base_cfg

# leanctx owning sb_read changes routing for Read and exempts Grep
tl_stub lean-ctx 'exit 0'; hash -r
LART="$TL_TMP/lc-art"; printf '{"mcpServers":{"lean-ctx":{}}}' >"$LART"
base_cfg '.recommended_tools.leanctx = {enabled_by_user:true} | .optimization_profiles = {five_tool_routed:{routes:{sb_read:"leanctx"}}}'
run_deny "$HOOK" "$(read_in "$BIG")" SB_LEANCTX_MCP_ARTIFACT="$LART"
assert_gate_denies "Read denied with LeanCTX routing message" "LEANCTX READ ROUTING"
assert_contains "leanctx message mentions lctx_read_ast" "$(gh_reason)" "lctx_read_ast"
run_deny "$HOOK" "$(read_in "$BIG")"
assert_gate_allows "LeanCTX owns reads but is not wired: no redirect" 
run_deny "$HOOK" "$(grep_in "$BIG")"; assert_gate_allows "Grep stays cooperative when leanctx active"
base_cfg

# consent / project gating
jq '.recommended_tools.context_mode.enabled_by_user = false' "$GH_CFG" >"$GH_CFG.n" && mv "$GH_CFG.n" "$GH_CFG"
run_deny "$HOOK" "$(read_in "$BIG")"; assert_gate_allows "opted out allows"
base_cfg 'del(.recommended_tools.context_mode.enabled_by_user)'
run_deny "$HOOK" "$(read_in "$BIG")"; assert_gate_denies "user consent alone enforces (project file silent)" "large Read"
base_cfg
run_deny "$HOOK" "$(read_in "$BIG")" XDG_CONFIG_HOME="$TL_TMP/no-consent"; assert_gate_allows "consent pending allows (a project recommendation is not consent)"
base_cfg '.recommended_tools.context_mode.enforcement_suspended = true'
run_deny "$HOOK" "$(read_in "$BIG")"; assert_gate_allows "suspended enforcement allows"
base_cfg
rm -f "$SB_RUNTIME_STATE_DIR/project-root"
GH_CWD="$TL_TMP/outside" GH_PROJECT_ROOT="" run_deny "$HOOK" "$(read_in "$BIG")"; assert_gate_allows "outside a project allows"
rm -f "$GH_CFG" "$SB_RUNTIME_STATE_DIR/project-root"
run_deny "$HOOK" "$(read_in "$BIG")"; assert_gate_allows "missing project config allows"
printf '{ broken' >"$GH_CFG"
run_deny "$HOOK" "$(read_in "$BIG")"; assert_gate_allows "unparsable project config allows"
base_cfg
printf 'x' >"$SB_RUNTIME_STATE_DIR/trivial"
run_deny "$HOOK" "$(read_in "$BIG")"; assert_gate_allows "trivial marker allows"
rm -f "$SB_RUNTIME_STATE_DIR/trivial"
base_cfg '.state.trivial_file = "~/custom-trivial"'
run_deny "$HOOK" "$(read_in "$BIG")"; assert_gate_denies "configured trivial path absent still denies" "large Read redirected once"
printf 'x' >"$HOME/custom-trivial"
run_deny "$HOOK" "$(read_in "$BIG")"; assert_gate_allows "configured trivial path (~) allows"
rm -f "$HOME/custom-trivial"
base_cfg
run_deny "$HOOK" ""; assert_gate_allows "empty stdin allows"
run_deny "$HOOK" "garbage"; assert_gate_allows "unparsable stdin allows"
GH_PATH="$(tl_path_without jq)" run_deny "$HOOK" "$(read_in "$BIG")"; assert_gate_allows "missing jq allows"
GH_CWD="$GH_PROJ/src" run_deny "$HOOK" "$(read_in "src/big.txt")"
assert_gate_denies "project discovered from subdirectory (relative path resolves against project root)" "large Read redirected once"

tl_results
