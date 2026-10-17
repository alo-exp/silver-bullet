#!/usr/bin/env bash
# Behavior tests for hooks/lib/context-mode-gate.sh and hooks/lib/context-mode-read-deny.sh
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude
unset SB_CONTEXT_MODE_MCP_ARTIFACT CONTEXT_MODE_READ_DENY_BYPASS SB_CONTEXT_MODE_READ_DENY_BYPASS SB_GLOBAL_TOOLSTACK_MANIFEST SB_GLOBAL_TOOLSTACK_HOME

# shellcheck source=../../hooks/lib/context-mode-read-deny.sh
source "$TL_REPO_ROOT/hooks/lib/context-mode-read-deny.sh"

yes_t() { local n="$1"; shift; if "$@"; then tl_pass "$n"; else tl_fail "$n"; fi; }
no_t() { local n="$1"; shift; if "$@"; then tl_fail "$n"; else tl_pass "$n"; fi; }
CFG="$TL_TMP/cfg.json"
w() { printf '%s' "$1" >"$CFG"; }
PR="$TL_TMP/proj"; mkdir -p "$PR"

# ---------- required / min node ----------
w '{"recommended_tools":{"context_mode":{"enabled_by_user":true,"min_node_version":"20.1"}}}'
yes_t "required" sb_context_mode_required "$CFG"
no_t "not required on missing config" sb_context_mode_required "$TL_TMP/none.json"
assert_eq "min node configured" "20.1" "$(sb_context_mode_min_node_version "$CFG")"
assert_eq "min node default without config" "22.5" "$(sb_context_mode_min_node_version)"
w '{"recommended_tools":{}}'
assert_eq "min node default when unset" "22.5" "$(sb_context_mode_min_node_version "$CFG")"
w 'garbage'
assert_eq "min node default on invalid json" "22.5" "$(sb_context_mode_min_node_version "$CFG")"

# ---------- cli path / plugin / availability ----------
PATH_NO_CM="$(tl_path_without context-mode)"
no_t "cli_path none" env PATH="$PATH_NO_CM" bash -c 'source "$1"; sb_context_mode_cli_path' _ "$TL_REPO_ROOT/hooks/lib/context-mode-gate.sh"
no_t "plugin absent" sb_context_mode_claude_plugin_present
no_t "cli_available none" sb_context_mode_cli_available
mkdir -p "$HOME/.claude/plugins/context-mode"
yes_t "plugin present (context-mode dir)" sb_context_mode_claude_plugin_present
yes_t "cli_available via plugin" sb_context_mode_cli_available
rm -rf "$HOME/.claude/plugins/context-mode"; mkdir -p "$HOME/.claude/plugins/mksglu-context-mode"
yes_t "plugin present (mksglu dir)" sb_context_mode_claude_plugin_present
rm -rf "$HOME/.claude"
tl_stub context-mode 'exit 0'
hash -r
assert_eq "cli_path from PATH" "$TL_BIN/context-mode" "$(sb_context_mode_cli_path)"
yes_t "cli_available via PATH" sb_context_mode_cli_available
OTHER="$TL_TMP/manifest-cm"; printf '#!/bin/sh\n' >"$OTHER"; chmod +x "$OTHER"
export SB_GLOBAL_TOOLSTACK_MANIFEST="$TL_TMP/manifest.json"
jq -n --arg c "$OTHER" '{tools:{context_mode:{command:$c}}}' >"$SB_GLOBAL_TOOLSTACK_MANIFEST"
assert_eq "cli_path from manifest" "$OTHER" "$(sb_context_mode_cli_path)"
unset SB_GLOBAL_TOOLSTACK_MANIFEST

# ---------- node ----------
nodev() { tl_stub node "echo ${1}"; hash -r; }
no_t "node missing" env PATH="$(tl_path_without node)" bash -c 'source "$1"; sb_context_mode_node_ok' _ "$TL_REPO_ROOT/hooks/lib/context-mode-gate.sh"
tl_stub node 'exit 0'; hash -r
no_t "node empty version" sb_context_mode_node_ok
w '{"recommended_tools":{"context_mode":{"min_node_version":"22.5"}}}'
nodev v24.0.0; yes_t "node major greater" sb_context_mode_node_ok "$CFG"
nodev v20.9.0; no_t "node major lower" sb_context_mode_node_ok "$CFG"
nodev v22.5.0; yes_t "node minor equal" sb_context_mode_node_ok "$CFG"
nodev v22.10.1; yes_t "node minor greater" sb_context_mode_node_ok "$CFG"
nodev v22.4.9; no_t "node minor lower" sb_context_mode_node_ok "$CFG"
nodev v23.0.0; yes_t "node default min used without config" sb_context_mode_node_ok

# ---------- platform artifact ----------
export SB_CONTEXT_MODE_MCP_ARTIFACT=/override/art
assert_eq "artifact override" "/override/art" "$(sb_context_mode_platform_artifact_path "$PR" claude)"
unset SB_CONTEXT_MODE_MCP_ARTIFACT
assert_eq "artifact cursor" "$HOME/.cursor/mcp.json" "$(sb_context_mode_platform_artifact_path "$PR" cursor)"
assert_eq "artifact codex" "/ch/config.toml" "$(CODEX_HOME=/ch sb_context_mode_platform_artifact_path "$PR" codex)"
assert_eq "artifact opencode" "$HOME/.config/opencode/opencode.json" "$(sb_context_mode_platform_artifact_path "$PR" opencode)"
assert_eq "artifact pi env" "/pd/extensions/silver-bullet-five-tool-stack/config.json" "$(PI_CODING_AGENT_DIR=/pd sb_context_mode_platform_artifact_path "$PR" pi)"
assert_eq "artifact pi home" "$HOME/.pi/agent/extensions/silver-bullet-five-tool-stack/config.json" "$(env -u PI_CODING_AGENT_DIR bash -c 'source "$1"; sb_context_mode_platform_artifact_path /x pi' _ "$TL_REPO_ROOT/hooks/lib/context-mode-gate.sh")"
assert_eq "artifact default claude" "$HOME/.claude/plugins/context-mode" "$(sb_context_mode_platform_artifact_path "$PR" claude)"
assert_eq "artifact default host" "$HOME/.claude/plugins/context-mode" "$(SILVER_BULLET_RUNTIME=claude sb_context_mode_platform_artifact_path "$PR")"

present() { sb_context_mode_platform_artifact_present "$PR" "$1"; }
no_t "present claude nothing" present claude
mkdir -p "$HOME/.claude/plugins/context-mode"
yes_t "present claude via plugin" present claude
rm -rf "$HOME/.claude"
export SB_CONTEXT_MODE_MCP_ARTIFACT="$TL_TMP/art"
mkdir -p "$TL_TMP/art"
yes_t "present claude via artifact dir" present claude
rmdir "$TL_TMP/art"
no_t "present claude artifact not a dir" present claude
for h in cursor codex; do
  no_t "present $h missing file" present "$h"
  printf 'nothing' >"$TL_TMP/art"
  no_t "present $h without marker" present "$h"
  printf 'x context-mode y' >"$TL_TMP/art"
  yes_t "present $h" present "$h"
  rm -f "$TL_TMP/art"
done
ln -s "$TL_TMP/other-target" "$TL_TMP/art"; printf 'context-mode' >"$TL_TMP/other-target"
no_t "present cursor refuses symlink" present cursor
rm -f "$TL_TMP/art"
no_t "present opencode missing file" present opencode
printf '{"plugin":["context-mode"]}' >"$TL_TMP/art"; yes_t "present opencode plugin exact" present opencode
printf '{"plugin":["context-mode@1.2"]}' >"$TL_TMP/art"; yes_t "present opencode plugin versioned" present opencode
printf '{"plugin":["/x/build/adapters/opencode/plugin.js"]}' >"$TL_TMP/art"; yes_t "present opencode plugin path" present opencode
printf '{"mcp":{"context-mode":{}}}' >"$TL_TMP/art"; yes_t "present opencode mcp" present opencode
printf '{"mcp":{"user-context-mode":{}}}' >"$TL_TMP/art"; yes_t "present opencode user mcp" present opencode
printf '{"plugin":["other"],"mcp":{}}' >"$TL_TMP/art"; no_t "present opencode unrelated" present opencode
printf 'not json' >"$TL_TMP/art"; no_t "present opencode invalid json" present opencode
no_t "present pi invalid json" present pi
printf '{"servers":{"context_mode":{"enabled":true}}}' >"$TL_TMP/art"; yes_t "present pi enabled" present pi
printf '{"servers":{"context_mode":{"enabled":false}}}' >"$TL_TMP/art"; no_t "present pi disabled" present pi
rm -f "$TL_TMP/art"; no_t "present pi missing file" present pi
no_t "present unknown host" present hermes
unset SB_CONTEXT_MODE_MCP_ARTIFACT
no_t "present default host (claude, nothing wired)" sb_context_mode_platform_artifact_present "$PR"

# ---------- hooks present ----------
no_t "hooks_present claude none" sb_context_mode_hooks_present claude
mkdir -p "$HOME/.claude/plugins/context-mode"; yes_t "hooks_present claude" sb_context_mode_hooks_present claude
rm -rf "$HOME/.claude"
no_t "hooks_present cursor missing" sb_context_mode_hooks_present cursor
mkdir -p "$HOME/.cursor"; printf 'nothing' >"$HOME/.cursor/hooks.json"
no_t "hooks_present cursor no marker" sb_context_mode_hooks_present cursor
printf 'context-mode' >"$HOME/.cursor/hooks.json"; yes_t "hooks_present cursor" sb_context_mode_hooks_present cursor
no_t "hooks_present codex missing" env CODEX_HOME="$TL_TMP/codexhome" bash -c 'source "$1"; sb_context_mode_hooks_present codex' _ "$TL_REPO_ROOT/hooks/lib/context-mode-gate.sh"
mkdir -p "$TL_TMP/codexhome"; printf 'context-mode' >"$TL_TMP/codexhome/hooks.json"
yes_t "hooks_present codex" env CODEX_HOME="$TL_TMP/codexhome" bash -c 'source "$1"; sb_context_mode_hooks_present codex' _ "$TL_REPO_ROOT/hooks/lib/context-mode-gate.sh"
yes_t "hooks_present codex default dir" bash -c 'source "$1"; mkdir -p "$HOME/.codex"; echo context-mode >"$HOME/.codex/hooks.json"; unset CODEX_HOME; sb_context_mode_hooks_present codex' _ "$TL_REPO_ROOT/hooks/lib/context-mode-gate.sh"
export SB_CONTEXT_MODE_MCP_ARTIFACT="$TL_TMP/art"; printf '{"plugin":["context-mode"]}' >"$TL_TMP/art"
yes_t "hooks_present opencode delegates to artifact" sb_context_mode_hooks_present opencode
printf '{"servers":{"context_mode":{"enabled":true}}}' >"$TL_TMP/art"
yes_t "hooks_present pi delegates to artifact" sb_context_mode_hooks_present pi
unset SB_CONTEXT_MODE_MCP_ARTIFACT
no_t "hooks_present unknown" sb_context_mode_hooks_present hermes
no_t "hooks_present default host (claude, none)" sb_context_mode_hooks_present

# ---------- instruction fragment ----------
FR="$TL_TMP/frag"; mkdir -p "$FR"
no_t "fragment none" sb_context_mode_instruction_fragment_present "$FR"
printf '<!-- BEGIN context-mode hint (do not edit) -->\n' >"$FR/silver-bullet.md"
no_t "fragment begin without ctx tools" sb_context_mode_instruction_fragment_present "$FR"
printf '<!-- BEGIN context-mode hint (do not edit) -->\nuse ctx_search\n' >"$FR/silver-bullet.md"
yes_t "fragment sentinel + tool (silver-bullet.md)" sb_context_mode_instruction_fragment_present "$FR/"
rm -f "$FR/silver-bullet.md"
printf 'context-mode hint here\nctx_index\n' >"$FR/CLAUDE.md"
yes_t "fragment plain hint (CLAUDE.md)" sb_context_mode_instruction_fragment_present "$FR"
rm -f "$FR/CLAUDE.md"
printf 'context-mode hint only\n' >"$FR/AGENTS.md"
no_t "fragment hint without tools (AGENTS.md)" sb_context_mode_instruction_fragment_present "$FR"
printf 'context-mode hint\nctx_batch_execute\n' >"$FR/AGENTS.md"
yes_t "fragment AGENTS.md" sb_context_mode_instruction_fragment_present "$FR"
(cd "$FR" && sb_context_mode_instruction_fragment_present) && tl_pass "fragment default root is PWD" || tl_fail "fragment default root is PWD"
# cursor rule
no_t "cursor rule absent" sb_context_mode_cursor_rule_present "$FR"
mkdir -p "$FR/.cursor/rules"; : >"$FR/.cursor/rules/context-mode.mdc"
yes_t "cursor rule file" sb_context_mode_cursor_rule_present "$FR"
rm "$FR/.cursor/rules/context-mode.mdc"; printf 'uses context-mode' >"$FR/.cursor/rules/other.mdc"
yes_t "cursor rule via grep" sb_context_mode_cursor_rule_present "$FR/"
rm "$FR/.cursor/rules/other.mdc"; printf 'x' >"$FR/.cursor/rules/other.mdc"
no_t "cursor rule none matching" sb_context_mode_cursor_rule_present "$FR"

# ---------- windows ----------
for u in MINGW64_NT MSYS_NT CYGWIN_NT Windows_NT; do
  tl_stub uname "echo $u"; hash -r
  yes_t "windows native via uname $u" sb_context_mode_is_windows_native
done
tl_stub uname 'echo Linux'; hash -r
no_t "linux not windows" env -u OS bash -c 'source "$1"; sb_context_mode_is_windows_native' _ "$TL_REPO_ROOT/hooks/lib/context-mode-gate.sh"
yes_t "windows via OS env" env OS=Windows_NT bash -c 'source "$1"; sb_context_mode_is_windows_native' _ "$TL_REPO_ROOT/hooks/lib/context-mode-gate.sh"
no_t "non-windows OS env" env OS=linux-gnu bash -c 'source "$1"; sb_context_mode_is_windows_native' _ "$TL_REPO_ROOT/hooks/lib/context-mode-gate.sh"
rm -f "$TL_BIN/uname"; hash -r

# ---------- exemptions ----------
no_t "edit exempt empty" sb_context_mode_edit_path_is_exempt ""
for p in /p/.silver-bullet.json /p/SETUP_REPORT.md /p/.silver-bullet/x /h/.cursor/mcp.json /h/.cursor/hooks.json /p/templates/context-mode-hint.md.base; do
  yes_t "edit exempt $p" sb_context_mode_edit_path_is_exempt "$p"
done
no_t "edit not exempt" sb_context_mode_edit_path_is_exempt /p/src/a.py
yes_t "cmd exempt empty" sb_context_mode_command_is_exempt ""
yes_t "cmd exempt context-mode" sb_context_mode_command_is_exempt "context-mode doctor"
yes_t "cmd exempt enable script" sb_context_mode_command_is_exempt "bash enable-rtk-context-mode.sh"
yes_t "cmd exempt npm install" sb_context_mode_command_is_exempt "foo npm install -g context-mode"
yes_t "cmd exempt node" sb_context_mode_command_is_exempt "node script.js"
yes_t "cmd exempt mkdir" sb_context_mode_command_is_exempt "mkdir -p x"
no_t "cmd not exempt" sb_context_mode_command_is_exempt "git commit -m x"

# ---------- messages ----------
w '{"recommended_tools":{"context_mode":{"enabled_by_user":true,"license_note":"ELv2 notice"}}}'
m="$(SILVER_BULLET_RUNTIME=claude sb_context_mode_block_message_no_cli "$CFG")"
assert_contains "no_cli header" "$m" "CONTEXT MODE REQUIRED"
assert_contains "no_cli license" "$m" "License: ELv2 notice"
assert_contains "no_cli install lines" "$m" "npm install -g context-mode"
w '{"recommended_tools":{"context_mode":{"enabled_by_user":true}}}'
assert_not_contains "no_cli without license" "$(sb_context_mode_block_message_no_cli "$CFG")" "License:"
(
  sb_recommended_tool_full_install_lines() { return 1; }
  [[ "$(sb_context_mode_block_message_no_cli "$CFG")" == *"CONTEXT MODE REQUIRED"* ]]
) && tl_pass "no_cli survives install-line failure" || tl_fail "no_cli survives install-line failure"
w '{"recommended_tools":{"context_mode":{"min_node_version":"21.3"}}}'
assert_contains "node message" "$(sb_context_mode_block_message_node "$CFG")" "need >= 21.3"
m="$(SILVER_BULLET_RUNTIME=claude sb_context_mode_block_message_no_platform "$CFG")"
assert_contains "no_platform header" "$m" "CONTEXT MODE NOT WIRED"
assert_contains "no_platform artifact" "$m" "$HOME/.claude/plugins/context-mode"
assert_contains "no_platform commands" "$m" "npm install -g context-mode"
(
  sb_recommended_tool_platform_install_commands() { return 1; }
  [[ "$(sb_context_mode_block_message_no_platform "$CFG")" == *"CONTEXT MODE NOT WIRED"* ]]
) && tl_pass "no_platform survives command failure" || tl_fail "no_platform survives command failure"
assert_contains "no_fragment message" "$(sb_context_mode_block_message_no_fragment)" "INSTRUCTION FRAGMENT MISSING"

# ---------- prompt reminder ----------
PRC="$FR/.silver-bullet.json"
printf '{}' >"$PRC"
assert_contains "reminder pending" "$(sb_context_mode_prompt_reminder_line "$PRC")" "consent pending"
printf '{"recommended_tools":{"context_mode":{"enabled_by_user":false}}}' >"$PRC"
assert_contains "reminder opted out" "$(sb_context_mode_prompt_reminder_line "$PRC")" "opted out"
printf '{"recommended_tools":{"context_mode":{"enabled_by_user":true,"enforcement_suspended":true}}}' >"$PRC"
assert_contains "reminder suspended" "$(sb_context_mode_prompt_reminder_line "$PRC")" "enforcement suspended"
printf '{"recommended_tools":{"context_mode":{"enabled_by_user":true}}}' >"$PRC"
nodev v10.0.0
assert_contains "reminder node old" "$(sb_context_mode_prompt_reminder_line "$PRC")" "Node too old"
nodev v24.0.0
rm -f "$TL_BIN/context-mode"; hash -r
assert_contains "reminder cli missing" "$(PATH="$(tl_path_without context-mode)" sb_context_mode_prompt_reminder_line "$PRC")" "CLI/plugin missing"
tl_stub context-mode 'exit 0'; hash -r
assert_contains "reminder not wired" "$(SILVER_BULLET_RUNTIME=claude sb_context_mode_prompt_reminder_line "$PRC")" "MCP/plugin not wired for claude"
mkdir -p "$HOME/.claude/plugins/context-mode"
rm -f "$FR/AGENTS.md" "$FR/silver-bullet.md" "$FR/CLAUDE.md"
assert_contains "reminder fragment missing" "$(SILVER_BULLET_RUNTIME=claude sb_context_mode_prompt_reminder_line "$PRC")" "instruction fragment missing"
printf 'context-mode hint\nctx_search\n' >"$FR/CLAUDE.md"
assert_contains "reminder wired" "$(SILVER_BULLET_RUNTIME=claude sb_context_mode_prompt_reminder_line "$PRC")" "Context Mode: wired"
rm -rf "$HOME/.claude"

# ================= read-deny lib =================
yes_t_bypass() { local v="$1"; if CONTEXT_MODE_READ_DENY_BYPASS="$v" sb_context_mode_read_deny_bypassed; then echo yes; else echo no; fi; }
for v in 1 true yes YES on ON; do assert_eq "bypass value $v" "yes" "$(yes_t_bypass "$v")"; done
for v in 0 false no off ""; do assert_eq "bypass value '$v' off" "no" "$(yes_t_bypass "$v")"; done
yes_t "bypass via SB_ var" env SB_CONTEXT_MODE_READ_DENY_BYPASS=1 bash -c 'source "$1"; sb_context_mode_read_deny_bypassed' _ "$TL_REPO_ROOT/hooks/lib/context-mode-read-deny.sh"

assert_eq "deny bytes default" "5120" "$(sb_context_mode_read_deny_bytes)"
w '{"recommended_tools":{"context_mode":{"read_deny_bytes":300}}}'
assert_eq "deny bytes configured" "300" "$(sb_context_mode_read_deny_bytes "$CFG")"
w '{"recommended_tools":{"context_mode":{"read_deny_bytes":"big"}}}'
assert_eq "deny bytes non numeric" "5120" "$(sb_context_mode_read_deny_bytes "$CFG")"
w 'garbage'
assert_eq "deny bytes invalid json" "5120" "$(sb_context_mode_read_deny_bytes "$CFG")"

assert_eq "resolve relative to root" "$PR/a/b.txt" "$(sb_context_mode_resolve_read_path a/../a/b.txt "$PR")"
assert_eq "resolve absolute" "/etc/hostname" "$(sb_context_mode_resolve_read_path /etc/hostname "$PR")"
assert_eq "resolve empty is empty" "" "$(sb_context_mode_resolve_read_path "" "$PR")"
tilde="$(printf '~')/x"
assert_eq "resolve ~ expands" "$HOME/x" "$(sb_context_mode_resolve_read_path "$tilde" "$PR")"
assert_eq "resolve defaults root to PWD" "$PR/zz" "$(cd "$PR" && sb_context_mode_resolve_read_path zz)"
tl_stub python3 'exit 3'; hash -r
[[ -z "$(sb_context_mode_resolve_read_path a "$PR")" ]] && tl_pass "resolve survives python failure" || tl_fail "resolve survives python failure"
rm -f "$TL_BIN/python3"; hash -r

BIG="$PR/big.txt"; head -c 600 /dev/zero | tr '\0' 'a' >"$BIG"
assert_eq "file size" "600" "$(sb_context_mode_file_size_bytes "$BIG")"
no_t "file size empty arg" sb_context_mode_file_size_bytes ""
no_t "file size missing" sb_context_mode_file_size_bytes "$PR/none"
no_t "file size directory" sb_context_mode_file_size_bytes "$PR"
tl_stub python3 'exit 3'; hash -r
no_t "file size fails when python fails" sb_context_mode_file_size_bytes "$BIG"
rm -f "$TL_BIN/python3"; hash -r

rj() { jq -cn --arg t "$1" --arg p "$2" --arg k "$3" '{tool_name:$t, tool_input:{($k):$p}}'; }
assert_eq "read path Read" "$BIG" "$(sb_context_mode_tool_read_path "$(rj Read "$BIG" file_path)")"
assert_eq "read path Grep" "$PR" "$(sb_context_mode_tool_read_path "$(rj Grep "$PR" path)")"
assert_eq "read path other tool empty" "" "$(sb_context_mode_tool_read_path "$(rj Bash x command)")"
assert_eq "read path invalid json empty" "" "$(sb_context_mode_tool_read_path 'garbage')"

# exemption
no_t "read exempt empty" sb_context_mode_read_path_is_exempt ""
yes_t "read exempt inherits edit exemptions" sb_context_mode_read_path_is_exempt /p/.silver-bullet.json
yes_t "read exempt graph.json" sb_context_mode_read_path_is_exempt /p/graphify-out/graph.json
yes_t "read exempt graphify wiki" sb_context_mode_read_path_is_exempt /p/graphify-out/wiki/index.md
no_t "read not exempt no config" sb_context_mode_read_path_is_exempt /p/src.py
w '{"state":{"state_file":"~/st/state","trivial_file":"~/st/trivial"}}'
yes_t "read exempt configured state file" sb_context_mode_read_path_is_exempt "$HOME/st/state" "$CFG"
yes_t "read exempt configured trivial file" sb_context_mode_read_path_is_exempt "$HOME/st/trivial" "$CFG"
no_t "read not exempt other file with config" sb_context_mode_read_path_is_exempt "$HOME/st/other" "$CFG"
w '{}'
no_t "read not exempt config without state keys" sb_context_mode_read_path_is_exempt "$HOME/st/other" "$CFG"
no_t "read not exempt missing config file" sb_context_mode_read_path_is_exempt /p/x "$TL_TMP/none.json"
(
  unset -f sb_context_mode_edit_path_is_exempt
  sb_context_mode_read_path_is_exempt /p/.silver-bullet.json && exit 1
  exit 0
) && tl_pass "read exempt without edit helper" || tl_fail "read exempt without edit helper"

w 'garbage'
no_t "read not exempt when config unparsable" sb_context_mode_read_path_is_exempt /p/src.py "$CFG"
(
  sb_tool_name() { return 1; }
  [[ -z "$(sb_context_mode_tool_read_path "$(rj Read "$BIG" file_path)")" ]] || exit 1
  sb_context_mode_should_deny_read "$(rj Read "$BIG" file_path)" "$CFG" "$PR" && exit 2
  exit 0
) && tl_pass "tool name lookup failure yields no path and no deny" || tl_fail "tool name lookup failure (exit $?)"
(
  sb_tool_name() { printf 'Grep'; }
  [[ -z "$(sb_context_mode_tool_read_path 'garbage')" ]]
) && tl_pass "Grep path extraction tolerates unparsable input" || tl_fail "Grep path extraction tolerates unparsable input"

# should_deny_read
w '{"recommended_tools":{"context_mode":{"enabled_by_user":true,"read_deny_bytes":500}}}'
sd() { sb_context_mode_should_deny_read "$@"; }
assert_eq "deny read large" "$BIG" "$(sd "$(rj Read "$BIG" file_path)" "$CFG" "$PR")"
yes_t "deny read large rc" sd "$(rj Read "$BIG" file_path)" "$CFG" "$PR"
assert_eq "deny read relative path" "$BIG" "$(sd "$(rj Read big.txt file_path)" "$CFG" "$PR")"
yes_t "deny Grep large (no leanctx)" sd "$(rj Grep "$BIG" path)" "$CFG" "$PR"
head -c 100 /dev/zero | tr '\0' 'a' >"$PR/small.txt"
no_t "allow small file" sd "$(rj Read small.txt file_path)" "$CFG" "$PR"
head -c 500 /dev/zero | tr '\0' 'a' >"$PR/edge.txt"
no_t "allow file exactly at threshold" sd "$(rj Read edge.txt file_path)" "$CFG" "$PR"
head -c 501 /dev/zero | tr '\0' 'a' >"$PR/edge2.txt"
yes_t "deny file one byte over threshold" sd "$(rj Read edge2.txt file_path)" "$CFG" "$PR"
no_t "allow missing file" sd "$(rj Read nope.txt file_path)" "$CFG" "$PR"
no_t "allow empty path" sd "$(rj Read "" file_path)" "$CFG" "$PR"
no_t "allow other tool" sd "$(rj Bash x command)" "$CFG" "$PR"
no_t "allow garbage input" sd 'garbage' "$CFG" "$PR"
no_t "allow exempt file" sd "$(rj Read "$PR/.silver-bullet.json" file_path)" "$CFG" "$PR"
head -c 900 /dev/zero | tr '\0' 'a' >"$PR/.silver-bullet.json"
no_t "allow exempt large file" sd "$(rj Read "$PR/.silver-bullet.json" file_path)" "$CFG" "$PR"
no_t "bypass env allows" env CONTEXT_MODE_READ_DENY_BYPASS=1 bash -c 'source "$1"; shift; sb_context_mode_should_deny_read "$@"' _ "$TL_REPO_ROOT/hooks/lib/context-mode-read-deny.sh" "$(rj Read "$BIG" file_path)" "$CFG" "$PR"
w '{"recommended_tools":{"context_mode":{"enabled_by_user":true,"read_deny_bytes":0}}}'
no_t "zero threshold disables" sd "$(rj Read "$BIG" file_path)" "$CFG" "$PR"
(cd "$PR" && w '{"recommended_tools":{"context_mode":{"read_deny_bytes":500}}}' && sb_context_mode_should_deny_read "$(rj Read big.txt file_path)" "$CFG") && tl_pass "default project root is PWD" || tl_fail "default project root is PWD"
# leanctx owning sb_read: Grep stays cooperative, Read still denied
w '{"recommended_tools":{"context_mode":{"read_deny_bytes":500},"leanctx":{"enabled_by_user":true}}}'
no_t "Grep allowed when leanctx active" sd "$(rj Grep "$BIG" path)" "$CFG" "$PR"
yes_t "Read still denied when leanctx active" sd "$(rj Read "$BIG" file_path)" "$CFG" "$PR"
w '{"recommended_tools":{"context_mode":{"read_deny_bytes":500}}}'
(
  sb_context_mode_file_size_bytes() { return 1; }
  sd "$(rj Read "$BIG" file_path)" "$CFG" "$PR" && exit 1
  exit 0
) && tl_pass "allow when size cannot be determined" || tl_fail "allow when size cannot be determined"
(
  unset -f sb_stack_leanctx_active
  sd "$(rj Grep "$BIG" path)" "$CFG" "$PR" || exit 1
  exit 0
) && tl_pass "Grep denied when leanctx helper unavailable" || tl_fail "Grep denied when leanctx helper unavailable"

# deny message
m="$(sb_context_mode_read_deny_message /p/big 9000 5120)"
assert_contains "deny message" "$m" "CONTEXT MODE — Read blocked (9000 bytes > 5120 byte threshold)"
assert_contains "deny message path" "$m" "Path: /p/big"
w '{"recommended_tools":{"leanctx":{"enabled_by_user":true},"context_mode":{"enabled_by_user":true}},"optimization_profiles":{"five_tool_routed":{"routes":{"sb_read":"leanctx"}}}}'
assert_contains "deny message defers to leanctx" "$(sb_context_mode_read_deny_message /p/big 9000 5120 "$CFG")" "LEANCTX READ ROUTING"
w '{"recommended_tools":{"context_mode":{"enabled_by_user":true}}}'
assert_contains "deny message with config but no leanctx" "$(sb_context_mode_read_deny_message /p/big 9000 5120 "$CFG")" "CONTEXT MODE — Read blocked"
(
  unset -f sb_stack_read_deny_defer_to_leanctx
  [[ "$(sb_context_mode_read_deny_message /p/big 1 2 "$CFG")" == *"CONTEXT MODE — Read blocked"* ]]
) && tl_pass "deny message without coordinator helper" || tl_fail "deny message without coordinator helper"

tl_results
