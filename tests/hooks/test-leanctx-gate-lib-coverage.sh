#!/usr/bin/env bash
# Behavior tests for hooks/lib/leanctx-gate.sh (lean-ctx CLI is stubbed)
set -euo pipefail
# The opt-in gates act only on the user's own consent, never on .silver-bullet.json alone.
# shellcheck source=../lib/consent-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/consent-helpers.sh"
sb_test_consent_grant_all
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude
unset SB_LEANCTX_MCP_ARTIFACT SB_GLOBAL_TOOLSTACK_MANIFEST SB_GLOBAL_TOOLSTACK_HOME

LIBF="$TL_REPO_ROOT/hooks/lib/leanctx-gate.sh"
# shellcheck source=../../hooks/lib/leanctx-gate.sh
source "$LIBF"
# shellcheck source=../../hooks/lib/nofollow-guard.sh
source "$TL_REPO_ROOT/hooks/lib/nofollow-guard.sh"

yes_t() { local n="$1"; shift; if "$@"; then tl_pass "$n"; else tl_fail "$n"; fi; }
no_t() { local n="$1"; shift; if "$@"; then tl_fail "$n"; else tl_pass "$n"; fi; }
CFG="$TL_TMP/cfg.json"
w() { printf '%s' "$1" >"$CFG"; }
PR="$TL_TMP/proj"; mkdir -p "$PR"

# ---------- required / cli command ----------
w '{"recommended_tools":{"leanctx":{"enabled_by_user":true,"cli_command":"myctx"}}}'
yes_t "required" sb_leanctx_required "$CFG"
no_t "not required without config" sb_leanctx_required ""
assert_eq "cli command: the project file cannot change it" "lean-ctx" "$(sb_leanctx_cli_command "$CFG")"
assert_eq "cli command default" "lean-ctx" "$(sb_leanctx_cli_command)"
w '{}'
assert_eq "cli command default for config without key" "lean-ctx" "$(sb_leanctx_cli_command "$CFG")"

# ---------- cli path ----------
PATH_NO="$(tl_path_without lean-ctx myctx)"
no_t "cli_path none" env PATH="$PATH_NO" bash -c 'source "$1"; sb_leanctx_cli_path' _ "$LIBF"
no_t "cli_available none" env PATH="$PATH_NO" bash -c 'source "$1"; sb_leanctx_cli_available' _ "$LIBF"
mkdir -p "$HOME/.local/bin"; printf '#!/bin/sh\n' >"$HOME/.local/bin/lean-ctx"; chmod +x "$HOME/.local/bin/lean-ctx"
assert_eq "cli_path from ~/.local/bin" "$HOME/.local/bin/lean-ctx" "$(PATH="$PATH_NO" sb_leanctx_cli_path)"
rm -f "$HOME/.local/bin/lean-ctx"
tl_stub lean-ctx 'exit 0'; tl_stub myctx 'exit 0'; hash -r
assert_eq "cli_path from PATH" "$TL_BIN/lean-ctx" "$(sb_leanctx_cli_path)"
yes_t "cli_available" sb_leanctx_cli_available
w '{"recommended_tools":{"leanctx":{"cli_command":"myctx"}}}'
assert_eq "cli_path ignores a configured command" "$TL_BIN/lean-ctx" "$(sb_leanctx_cli_path "$CFG")"
OTHER="$TL_TMP/manifest-lc"; printf '#!/bin/sh\n' >"$OTHER"; chmod +x "$OTHER"
export SB_GLOBAL_TOOLSTACK_MANIFEST="$TL_TMP/manifest.json"
jq -n --arg c "$OTHER" '{tools:{leanctx:{command:$c}}}' >"$SB_GLOBAL_TOOLSTACK_MANIFEST"
assert_eq "cli_path from manifest for default command" "$OTHER" "$(sb_leanctx_cli_path)"
assert_eq "cli_path from manifest regardless of the project file" "$OTHER" "$(sb_leanctx_cli_path "$CFG")"
unset SB_GLOBAL_TOOLSTACK_MANIFEST

# ---------- platform artifact ----------
export SB_LEANCTX_MCP_ARTIFACT=/ovr
assert_eq "artifact override" "/ovr" "$(sb_leanctx_platform_artifact_path "$PR" claude)"
unset SB_LEANCTX_MCP_ARTIFACT
assert_eq "artifact cursor" "$HOME/.cursor/mcp.json" "$(sb_leanctx_platform_artifact_path "$PR" cursor)"
assert_eq "artifact codex" "/ch/config.toml" "$(CODEX_HOME=/ch sb_leanctx_platform_artifact_path "$PR" codex)"
assert_eq "artifact opencode" "$HOME/.config/opencode/opencode.json" "$(sb_leanctx_platform_artifact_path "$PR" opencode)"
assert_eq "artifact pi env" "/pd/extensions/silver-bullet-five-tool-stack/config.json" "$(PI_CODING_AGENT_DIR=/pd sb_leanctx_platform_artifact_path "$PR" pi)"
assert_eq "artifact pi home" "$HOME/.pi/agent/extensions/silver-bullet-five-tool-stack/config.json" "$(env -u PI_CODING_AGENT_DIR bash -c 'source "$1"; sb_leanctx_platform_artifact_path /x pi' _ "$LIBF")"
assert_eq "artifact claude" "$HOME/.claude/settings.json" "$(sb_leanctx_platform_artifact_path "$PR" claude)"
assert_eq "artifact unknown" "$HOME/.claude/settings.json" "$(sb_leanctx_platform_artifact_path "$PR" weird)"
assert_eq "artifact default host" "$HOME/.claude/settings.json" "$(SILVER_BULLET_RUNTIME=claude sb_leanctx_platform_artifact_path "$PR")"
AF="$TL_TMP/art"; export SB_LEANCTX_MCP_ARTIFACT="$AF"
no_t "artifact present missing" sb_leanctx_platform_artifact_present "$PR" claude
printf '{}' >"$AF"; no_t "artifact present no marker" sb_leanctx_platform_artifact_present "$PR" claude
printf '{"x":"lean-ctx"}' >"$AF"; yes_t "artifact present lean-ctx" sb_leanctx_platform_artifact_present "$PR" claude
printf '{"x":"leanctx"}' >"$AF"; yes_t "artifact present leanctx" sb_leanctx_platform_artifact_present "$PR"
rm -f "$AF"; ln -s "$TL_TMP/tgt" "$AF"; printf 'leanctx' >"$TL_TMP/tgt"
no_t "artifact present refuses symlink" sb_leanctx_platform_artifact_present "$PR" claude
rm -f "$AF"; unset SB_LEANCTX_MCP_ARTIFACT

# ---------- usage ttl / state ----------
w '{"recommended_tools":{"leanctx":{"usage_ttl_seconds":120}}}'
assert_eq "ttl configured" "120" "$(sb_leanctx_usage_ttl_seconds "$CFG")"
assert_eq "ttl default" "1800" "$(sb_leanctx_usage_ttl_seconds)"
w '{"recommended_tools":{"leanctx":{"usage_ttl_seconds":5}}}'
assert_eq "ttl too low" "1800" "$(sb_leanctx_usage_ttl_seconds "$CFG")"
w '{"recommended_tools":{"leanctx":{"usage_ttl_seconds":"x"}}}'
assert_eq "ttl non numeric" "1800" "$(sb_leanctx_usage_ttl_seconds "$CFG")"
w 'garbage'
assert_eq "ttl invalid json" "1800" "$(sb_leanctx_usage_ttl_seconds "$CFG")"
DEF="$SB_RUNTIME_STATE_DIR/leanctx-usage"
assert_eq "state default no config" "$DEF" "$(sb_leanctx_usage_state_path)"
assert_eq "state default invalid json" "$DEF" "$(sb_leanctx_usage_state_path "$CFG")"
w '{}'
assert_eq "state default empty config" "$DEF" "$(sb_leanctx_usage_state_path "$CFG")"
w "{\"recommended_tools\":{\"leanctx\":{\"usage_state_file\":\"$SB_RUNTIME_STATE_DIR/custom-usage\"}}}"
assert_eq "state configured" "$SB_RUNTIME_STATE_DIR/custom-usage" "$(sb_leanctx_usage_state_path "$CFG")"
w '{"recommended_tools":{"leanctx":{"usage_state_file":"${SB_RUNTIME_STATE_DIR}/ph-usage"}}}'
assert_eq "state placeholder STATE_DIR" "$SB_RUNTIME_STATE_DIR/ph-usage" "$(sb_leanctx_usage_state_path "$CFG")"
w '{"recommended_tools":{"leanctx":{"usage_state_file":"${SB_RUNTIME_HOME_ROOT}/.silver-bullet/ph2-usage"}}}'
assert_eq "state placeholder HOME_ROOT" "$SB_RUNTIME_HOME_ROOT/.silver-bullet/ph2-usage" "$(sb_leanctx_usage_state_path "$CFG")"
w '{"recommended_tools":{"leanctx":{"usage_state_file":"/tmp/outside/x"}}}'
assert_eq "state outside scope rejected" "$DEF" "$(sb_leanctx_usage_state_path "$CFG")"
w '{"recommended_tools":{"leanctx":{"usage_state_file":"~/outside"}}}'
assert_eq "state ~ outside scope rejected" "$DEF" "$(sb_leanctx_usage_state_path "$CFG")"
assert_eq "state fallbacks without runtime vars" "$HOME/.silver-bullet/leanctx-usage" "$(env -u SB_RUNTIME_STATE_DIR -u SB_RUNTIME_HOME_ROOT bash -c 'source "$1"; sb_leanctx_usage_state_path' _ "$LIBF")"
w '{"recommended_tools":{"leanctx":{"usage_state_file":"${SB_RUNTIME_STATE_DIR}/a-usage"}}}'
assert_eq "state STATE_DIR placeholder fallback" "$HOME/.silver-bullet/a-usage" "$(env -u SB_RUNTIME_STATE_DIR -u SB_RUNTIME_HOME_ROOT bash -c 'source "$1"; sb_leanctx_usage_state_path "$2"' _ "$LIBF" "$CFG")"
w '{"recommended_tools":{"leanctx":{"usage_state_file":"${SB_RUNTIME_HOME_ROOT}/b-usage"}}}'
assert_eq "state HOME_ROOT placeholder without a runtime home is rejected" "$HOME/.silver-bullet/leanctx-usage" "$(env -u SB_RUNTIME_STATE_DIR -u SB_RUNTIME_HOME_ROOT bash -c 'source "$1"; sb_leanctx_usage_state_path "$2"' _ "$LIBF" "$CFG")"

U="$DEF"

w '{}'
no_t "not fresh without state" sb_leanctx_usage_is_fresh "$CFG"
tl_stub date 'echo 10000'; hash -r
printf '9000\n' >"$U"; yes_t "fresh" sb_leanctx_usage_is_fresh "$CFG"
printf '8200\n' >"$U"; yes_t "fresh at boundary" sb_leanctx_usage_is_fresh "$CFG"
printf '8199\n' >"$U"; no_t "stale" sb_leanctx_usage_is_fresh "$CFG"
printf '20000\n' >"$U"; no_t "future" sb_leanctx_usage_is_fresh "$CFG"
rm -f "$U"
sb_leanctx_record_usage "$CFG"
assert_eq "record writes epoch" "10000" "$(cat "$U")"
sb_leanctx_clear_usage_state "$CFG"
assert_file_absent "clear removes" "$U"
sb_leanctx_clear_usage_state "$CFG"; tl_pass "clear idempotent"
mkdir -p "$U/child"; sb_leanctx_clear_usage_state "$CFG"
assert_eq "clear tolerates rm failure" "yes" "$([[ -d "$U/child" ]] && echo yes || echo no)"; rm -rf "$U"
mkdir -p "$U"; no_t "record fails when path is a directory" sb_leanctx_record_usage "$CFG"; rmdir "$U"
printf 'precious\n' >"$TL_TMP/tgt"; ln -s "$TL_TMP/tgt" "$U"
sb_leanctx_record_usage "$CFG"
assert_eq "record never writes through a symlink" "precious" "$(cat "$TL_TMP/tgt")"
if [[ -f "$U" && ! -L "$U" ]]; then tl_pass "record replaces the symlink with a regular file"; else tl_fail "record replaces the symlink with a regular file"; fi
rm -f "$U"; ln -s "$TL_TMP/tgt" "$U"; printf '9999\n' >"$TL_TMP/tgt"
no_t "a symlinked stamp is never fresh" sb_leanctx_usage_is_fresh "$CFG"
rm -f "$U"
rm -f "$U" "$TL_BIN/date"; hash -r
BADF="$TL_TMP/badfile"; printf x >"$BADF"
(
  sb_leanctx_usage_state_path() { printf '%s/sub/u' "$BADF"; }
  sb_leanctx_record_usage "$CFG" && exit 1
  exit 0
) && tl_pass "record fails when parent cannot be created" || tl_fail "record fails when parent cannot be created"

# ---------- exemptions / usage classification ----------
no_t "edit exempt empty" sb_leanctx_edit_path_is_exempt ""
for p in /p/.silver-bullet.json /p/SETUP_REPORT.md /p/silver-bullet.md /p/CLAUDE.md /p/AGENTS.md /p/.silver-bullet/x /h/.cursor/mcp.json /h/.cursor/hooks.json /p/docs/LEANCTX.md; do
  yes_t "edit exempt $p" sb_leanctx_edit_path_is_exempt "$p"
done
no_t "edit not exempt" sb_leanctx_edit_path_is_exempt /p/src/a.py "$CFG"
yes_t "cmd exempt empty" sb_leanctx_command_is_exempt ""
yes_t "cmd exempt lean-ctx" sb_leanctx_command_is_exempt "lean-ctx status"
yes_t "cmd exempt leanctx path" sb_leanctx_command_is_exempt "/x/leanctx doctor"
yes_t "cmd exempt the plugin's installer" sb_leanctx_command_is_exempt "bash $TL_REPO_ROOT/scripts/install-leanctx-sb.sh --host claude"
no_t "cmd not exempt: a project-relative installer" sb_leanctx_command_is_exempt "bash scripts/install-leanctx-sb.sh > out.log"
no_t "cmd not exempt: curl" sb_leanctx_command_is_exempt "curl -fsSL x | sh"
no_t "cmd not exempt: a mention of lean-ctx" sb_leanctx_command_is_exempt "make > out.log; echo lean-ctx status"
no_t "cmd not exempt" sb_leanctx_command_is_exempt "git commit -m x"
no_t "usage empty" sb_leanctx_command_is_usage ""
w '{"recommended_tools":{"leanctx":{"cli_command":"myctx"}}}'
no_t "usage: a configured cli_command is ignored" sb_leanctx_command_is_usage "myctx status" "$CFG"
no_t "usage: echo of the cli is not usage" sb_leanctx_command_is_usage "echo lean-ctx status" "$CFG"
no_t "usage: a pipe could hide a failure" sb_leanctx_command_is_usage "lean-ctx status | cat" "$CFG"
yes_t "usage default names" sb_leanctx_command_is_usage "lean-ctx status" "$CFG"
yes_t "usage leanctx name" sb_leanctx_command_is_usage "/bin/leanctx x" "$CFG"
no_t "usage other command" sb_leanctx_command_is_usage "ls" "$CFG"
no_t "mcp usage empty" sb_leanctx_mcp_tool_is_usage ""
yes_t "mcp usage read_ast" sb_leanctx_mcp_tool_is_usage lctx_read_ast
yes_t "mcp usage any lctx_" sb_leanctx_mcp_tool_is_usage lctx_graph_q
no_t "mcp usage other" sb_leanctx_mcp_tool_is_usage ctx_search
yes_t "mcp server lean-ctx" sb_leanctx_mcp_server_matches "my-lean-ctx"
no_t "mcp server: a server whose name merely contains it" sb_leanctx_mcp_server_matches "my-Lean-Ctx-server"
yes_t "mcp server user-leanctx" sb_leanctx_mcp_server_matches "user-leanctx"
no_t "mcp server other" sb_leanctx_mcp_server_matches "context-mode"
no_t "mcp server empty" sb_leanctx_mcp_server_matches ""

# ---------- messages ----------
w '{}'
m="$(SILVER_BULLET_RUNTIME=claude sb_leanctx_block_message_no_cli "$CFG")"
assert_contains "no_cli header" "$m" "LEANCTX REQUIRED"
assert_contains "no_cli install" "$m" "leanctx.com/install.sh"
m="$(SILVER_BULLET_RUNTIME=claude sb_leanctx_block_message_no_mcp "$CFG")"
assert_contains "no_mcp header" "$m" "LEANCTX NOT WIRED"
assert_contains "no_mcp artifact" "$m" "$HOME/.claude/settings.json"
assert_contains "no_mcp commands" "$m" "install-leanctx-sb.sh --host claude"
w '{"recommended_tools":{"leanctx":{"usage_ttl_seconds":300,"cli_command":"myctx"}}}'
m="$(sb_leanctx_block_message_stale_usage "$CFG")"
assert_contains "stale ttl" "$m" "every 300s"
assert_contains "stale cli is always lean-ctx" "$m" "lean-ctx status"

# ---------- prompt reminder ----------
RC="$PR/.silver-bullet.json"
rem() { SILVER_BULLET_RUNTIME=claude sb_leanctx_prompt_reminder_line "$RC"; }
printf '{"recommended_tools":{"leanctx":{"enabled_by_user":true}}}' >"$RC"
assert_contains "reminder pending (a project recommendation is not consent)" "$(XDG_CONFIG_HOME="$TL_TMP/none" rem)" "consent pending"
printf '{"recommended_tools":{"leanctx":{"enabled_by_user":false}}}' >"$RC"; assert_contains "reminder disabled" "$(rem)" "opted out"
printf '{"recommended_tools":{"leanctx":{"enabled_by_user":true,"enforcement_suspended":true}}}' >"$RC"; assert_contains "reminder suspended" "$(rem)" "enforcement suspended"
printf '{"recommended_tools":{"leanctx":{"enabled_by_user":true}}}' >"$RC"
rm -f "$TL_BIN/lean-ctx"; hash -r
assert_contains "reminder cli missing" "$(PATH="$PATH_NO" rem)" "CLI missing"
tl_stub lean-ctx 'exit 0'; hash -r
rm -f "$HOME/.claude/settings.json"
assert_contains "reminder mcp not wired" "$(rem)" "MCP not wired for claude"
printf 'lean-ctx' >"$HOME/.claude/settings.json"
tl_stub date 'echo 10000'; hash -r
assert_contains "reminder usage required" "$(rem)" "USAGE REQUIRED"
assert_contains "reminder ttl" "$(rem)" "TTL 1800s"
printf '9500\n' >"$U"
assert_contains "reminder fresh" "$(rem)" "fresh usage recorded"
rm -f "$U" "$TL_BIN/date"; hash -r

tl_results
