#!/usr/bin/env bash
# Behavior tests for hooks/lib/context-mode-gate.sh and hooks/lib/context-mode-read-deny.sh
set -euo pipefail
# The opt-in gates act only on the user's own consent, never on .silver-bullet.json alone.
# shellcheck source=../lib/consent-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/consent-helpers.sh"
sb_test_consent_grant_all
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
# R5-02: the value is repository data and must never reach arithmetic evaluation
for bad in 'a[$(touch /tmp/pwned-cm)]' '1;2' '$(id)' '-1' '1.2.3.4' '' ' 22 '; do
  w "$(jq -n --arg v "$bad" '{recommended_tools:{context_mode:{min_node_version:$v}}}')"
  assert_eq "min node rejects: [$bad]" "22.5" "$(sb_context_mode_min_node_version "$CFG")"
done
w '{"recommended_tools":{"context_mode":{"min_node_version":22}}}'
assert_eq "min node accepts a bare number" "22" "$(sb_context_mode_min_node_version "$CFG")"
w '{"recommended_tools":{"context_mode":{"min_node_version":"a[$(touch '"$TL_TMP"'/pwned-cm)]"}}}'
tl_stub node 'echo v24.0.0'; hash -r
sb_context_mode_node_ok "$CFG" || true
[[ ! -e "$TL_TMP/pwned-cm" ]] && tl_pass "a hostile min_node_version is never evaluated" || tl_fail "a hostile min_node_version is never evaluated"

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
mkdir -p "$HOME/.claude/plugins"
printf '{"plugins":{"context-mode@context-mode":[{}]}}' >"$HOME/.claude/plugins/installed_plugins.json"
yes_t "plugin present (marketplace registry)" sb_context_mode_claude_plugin_present
printf '{"plugins":{"other@x":[{}]}}' >"$HOME/.claude/plugins/installed_plugins.json"
no_t "plugin absent (registry without it)" sb_context_mode_claude_plugin_present
printf 'garbage' >"$HOME/.claude/plugins/installed_plugins.json"
no_t "plugin absent (unparsable registry)" sb_context_mode_claude_plugin_present
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
# the version is cached per node binary: a later change of the binary refreshes it
nodev v22.0.0
no_t "node cache refreshed when the binary changes" sb_context_mode_node_ok
assert_eq "node version reported" "22.0.0" "$(sb_context_mode_node_version)"
printf 'garbage\n' >"$SB_RUNTIME_STATE_DIR/context-mode-node"
touch -d '+1 minute' "$SB_RUNTIME_STATE_DIR/context-mode-node" 2>/dev/null || touch "$SB_RUNTIME_STATE_DIR/context-mode-node"
assert_eq "node version re-read when the cache is unusable" "22.0.0" "$(sb_context_mode_node_version)"
nodev v24.1.0
touch -d '-1 minute' "$SB_RUNTIME_STATE_DIR/context-mode-node" 2>/dev/null || true
assert_eq "node version re-read when the binary is newer than the cache" "24.1.0" "$(sb_context_mode_node_version)"

# ---------- platform artifact ----------
export SB_CONTEXT_MODE_MCP_ARTIFACT=/override/art
assert_eq "artifact override" "/override/art" "$(sb_context_mode_platform_artifact_path "$PR" claude)"
unset SB_CONTEXT_MODE_MCP_ARTIFACT
assert_eq "artifact cursor" "$HOME/.cursor/mcp.json" "$(sb_context_mode_platform_artifact_path "$PR" cursor)"
assert_eq "artifact codex" "/ch/config.toml" "$(CODEX_HOME=/ch sb_context_mode_platform_artifact_path "$PR" codex)"
assert_eq "artifact opencode" "$HOME/.config/opencode/opencode.json" "$(sb_context_mode_platform_artifact_path "$PR" opencode)"
assert_eq "artifact pi env" "/pd/extensions/silver-bullet-five-tool-stack/config.json" "$(PI_CODING_AGENT_DIR=/pd sb_context_mode_platform_artifact_path "$PR" pi)"
assert_eq "artifact pi home" "$HOME/.pi/agent/extensions/silver-bullet-five-tool-stack/config.json" "$(env -u PI_CODING_AGENT_DIR bash -c 'source "$1"; sb_context_mode_platform_artifact_path /x pi' _ "$TL_REPO_ROOT/hooks/lib/context-mode-gate.sh")"
assert_eq "artifact default claude" "$HOME/.claude.json" "$(sb_context_mode_platform_artifact_path "$PR" claude)"
assert_eq "artifact default host" "$HOME/.claude.json" "$(SILVER_BULLET_RUNTIME=claude sb_context_mode_platform_artifact_path "$PR")"

present() { sb_context_mode_platform_artifact_present "$PR" "$1"; }
no_t "present claude nothing" present claude
mkdir -p "$HOME/.claude/plugins/context-mode"
yes_t "present claude via plugin" present claude
rm -rf "$HOME/.claude"
# R5-08: the documented wiring is an MCP entry in ~/.claude.json (user scope, project scope) or .mcp.json
printf '{"mcpServers":{"context-mode":{}}}' >"$HOME/.claude.json"
yes_t "present claude via user-scope MCP entry" present claude
printf '{"projects":{"%s":{"mcpServers":{"plugin_context-mode_context-mode":{}}}}}' "$PR" >"$HOME/.claude.json"
yes_t "present claude via this project's MCP entry" present claude
printf '{"projects":{"/elsewhere":{"mcpServers":{"context-mode":{}}}}}' >"$HOME/.claude.json"
no_t "another project's MCP entry is not wiring" present claude
printf 'garbage' >"$HOME/.claude.json"
no_t "unparsable ~/.claude.json is not wiring" present claude
rm -f "$HOME/.claude.json"
printf '{"mcpServers":{"context_mode":{}}}' >"$PR/.mcp.json"
yes_t "present claude via the project .mcp.json" present claude
printf '{"mcpServers":{}}' >"$PR/.mcp.json"
no_t "empty .mcp.json is not wiring" present claude
rm -f "$PR/.mcp.json"
export SB_CONTEXT_MODE_MCP_ARTIFACT="$TL_TMP/art"
printf 'x' >"$TL_TMP/art"
no_t "present claude: an explicit artifact override is checked as a file (no marker)" present claude
rm -f "$TL_TMP/art"
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

# ---------- exemptions ----------
no_t "edit exempt empty" sb_context_mode_edit_path_is_exempt ""
for p in /p/.silver-bullet.json /p/SETUP_REPORT.md /p/.silver-bullet/x /h/.cursor/mcp.json /h/.cursor/hooks.json /p/templates/context-mode-hint.md.base; do
  yes_t "edit exempt $p" sb_context_mode_edit_path_is_exempt "$p"
done
no_t "edit not exempt" sb_context_mode_edit_path_is_exempt /p/src/a.py
yes_t "cmd exempt empty" sb_context_mode_command_is_exempt ""
yes_t "cmd exempt context-mode" sb_context_mode_command_is_exempt "context-mode doctor"
yes_t "cmd exempt enable script (plugin script)" sb_context_mode_command_is_exempt "bash $TL_REPO_ROOT/scripts/enable-rtk-context-mode.sh"
no_t "cmd not exempt: a lookalike script path" sb_context_mode_command_is_exempt "bash $TL_REPO_ROOT/scripts/../x.sh"
no_t "cmd not exempt: npm install of another package in a list" sb_context_mode_command_is_exempt "foo npm install -g context-mode"
no_t "cmd not exempt: node" sb_context_mode_command_is_exempt "node script.js"
no_t "cmd not exempt: mkdir" sb_context_mode_command_is_exempt "mkdir -p x"
yes_t "cmd exempt: documented install line" sb_context_mode_command_is_exempt "npm install -g context-mode"
yes_t "cmd exempt: read-only" sb_context_mode_command_is_exempt "ls -la"
no_t "cmd not exempt" sb_context_mode_command_is_exempt "git commit -m x"

# ---------- messages ----------
w '{"recommended_tools":{"context_mode":{"enabled_by_user":true,"license_note":"ignored repo text"}}}'
m="$(SILVER_BULLET_RUNTIME=claude sb_context_mode_block_message_no_cli "$CFG")"
assert_contains "no_cli header" "$m" "CONTEXT MODE REQUIRED"
assert_contains "no_cli license is the built-in ELv2 notice" "$m" "Elastic License 2.0"
assert_not_contains "no_cli ignores a repository license_note" "$m" "ignored repo text"
assert_contains "no_cli install lines" "$m" "npm install -g context-mode"
w '{"recommended_tools":{"context_mode":{"min_node_version":"21.3"}}}'
assert_contains "node message" "$(sb_context_mode_block_message_node "$CFG")" "need >= 21.3"
m="$(SILVER_BULLET_RUNTIME=claude sb_context_mode_block_message_no_platform "$CFG")"
assert_contains "no_platform header" "$m" "CONTEXT MODE NOT WIRED"
assert_contains "no_platform artifact" "$m" "$HOME/.claude.json"
assert_contains "no_platform commands" "$m" "npm install -g context-mode"
assert_contains "no_fragment message" "$(sb_context_mode_block_message_no_fragment)" "INSTRUCTION FRAGMENT MISSING"

# ---------- prompt reminder ----------
PRC="$FR/.silver-bullet.json"
printf '{"recommended_tools":{"context_mode":{"enabled_by_user":true}}}' >"$PRC"
assert_contains "reminder pending (a project recommendation is not consent)" "$(XDG_CONFIG_HOME="$TL_TMP/none" sb_context_mode_prompt_reminder_line "$PRC")" "consent pending"
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

# The threshold can be raised or switched off by the project file, never lowered below the default.
assert_eq "deny bytes default" "5120" "$(sb_context_mode_read_deny_bytes)"
w '{"recommended_tools":{"context_mode":{"read_deny_bytes":300}}}'
assert_eq "deny bytes below the default is ignored" "5120" "$(sb_context_mode_read_deny_bytes "$CFG")"
w '{"recommended_tools":{"context_mode":{"read_deny_bytes":20000}}}'
assert_eq "deny bytes raised" "20000" "$(sb_context_mode_read_deny_bytes "$CFG")"
w '{"recommended_tools":{"context_mode":{"read_deny_bytes":0}}}'
assert_eq "deny bytes zero switches the nudge off" "0" "$(sb_context_mode_read_deny_bytes "$CFG")"
w '{"recommended_tools":{"context_mode":{"read_deny_bytes":"big"}}}'
assert_eq "deny bytes non numeric" "5120" "$(sb_context_mode_read_deny_bytes "$CFG")"
w '{"recommended_tools":{"context_mode":{"read_deny_bytes":"a[$(touch '"$TL_TMP"'/pwned-rd)]"}}}'
assert_eq "deny bytes hostile value" "5120" "$(sb_context_mode_read_deny_bytes "$CFG")"
[[ ! -e "$TL_TMP/pwned-rd" ]] && tl_pass "hostile read_deny_bytes is never evaluated" || tl_fail "hostile read_deny_bytes is never evaluated"
w 'garbage'
assert_eq "deny bytes invalid json" "5120" "$(sb_context_mode_read_deny_bytes "$CFG")"

BIG="$PR/big.txt"; head -c 9000 /dev/zero | tr '\0' 'a' >"$BIG"
assert_eq "file size" "9000" "$(sb_context_mode_file_size_bytes "$BIG")"
no_t "file size empty arg" sb_context_mode_file_size_bytes ""
no_t "file size missing" sb_context_mode_file_size_bytes "$PR/none"
no_t "file size directory" sb_context_mode_file_size_bytes "$PR"
tl_stub wc 'exit 3'; hash -r
no_t "file size fails when wc fails" sb_context_mode_file_size_bytes "$BIG"
tl_stub wc 'echo abc'; hash -r
no_t "file size fails when wc prints junk" sb_context_mode_file_size_bytes "$BIG"
rm -f "$TL_BIN/wc"; hash -r

rj() { jq -cn --arg t "$1" --arg p "$2" --arg k "$3" '{tool_name:$t, tool_input:{($k):$p}}'; }
assert_eq "read path Read" "$BIG" "$(sb_context_mode_tool_read_path "$(rj Read "$BIG" file_path)")"
assert_eq "read path Grep" "$PR" "$(sb_context_mode_tool_read_path "$(rj Grep "$PR" path)")"
assert_eq "read path other tool empty" "" "$(sb_context_mode_tool_read_path "$(rj Bash x command)")"
assert_eq "read path invalid json empty" "" "$(sb_context_mode_tool_read_path 'garbage')"

# media and instruction files are exempt
for m in a.png B.JPG c.jpeg d.gif e.webp f.bmp g.ico h.tif i.tiff j.heic k.avif l.pdf m.ipynb; do
  yes_t "media exempt $m" sb_context_mode_read_path_is_media "/p/$m"
done
no_t "text is not media" sb_context_mode_read_path_is_media /p/a.txt
no_t "read exempt empty" sb_context_mode_read_path_is_exempt ""
yes_t "read exempt inherits edit exemptions" sb_context_mode_read_path_is_exempt /p/.silver-bullet.json
yes_t "read exempt graph.json" sb_context_mode_read_path_is_exempt /p/graphify-out/graph.json
yes_t "read exempt graphify wiki" sb_context_mode_read_path_is_exempt /p/graphify-out/wiki/index.md
yes_t "read exempt a skill file" sb_context_mode_read_path_is_exempt /p/skills/x/SKILL.md
yes_t "read exempt the plugin's own files" sb_context_mode_read_path_is_exempt "$TL_REPO_ROOT/hooks/core-rules.md"
yes_t "read exempt an image" sb_context_mode_read_path_is_exempt /p/shot.png
no_t "read not exempt no config" sb_context_mode_read_path_is_exempt /p/src.py
w '{"state":{"state_file":"~/st/state","trivial_file":"~/st/trivial"}}'
yes_t "read exempt configured state file" sb_context_mode_read_path_is_exempt "$HOME/st/state" "$CFG"
yes_t "read exempt configured trivial file" sb_context_mode_read_path_is_exempt "$HOME/st/trivial" "$CFG"
no_t "read not exempt other file with config" sb_context_mode_read_path_is_exempt "$HOME/st/other" "$CFG"
w '{}'
no_t "read not exempt config without state keys" sb_context_mode_read_path_is_exempt "$HOME/st/other" "$CFG"
no_t "read not exempt missing config file" sb_context_mode_read_path_is_exempt /p/x "$TL_TMP/none.json"
w 'garbage'
no_t "read not exempt when config unparsable" sb_context_mode_read_path_is_exempt /p/src.py "$CFG"

# ----- should_deny_read: only when Context Mode's tools exist (R5-07) -----
# Consent for Context Mode only: LeanCTX consent would hand Grep to LeanCTX.
sb_test_consent_sandbox
sb_test_consent_grant context_mode install,wire,enforce
w '{"recommended_tools":{"context_mode":{"enabled_by_user":true}}}'
sd() { sb_context_mode_should_deny_read "$@"; }
READ_BIG="$(rj Read "$BIG" file_path)"
export SB_CONTEXT_MODE_MCP_ARTIFACT="$TL_TMP/cm-art"   # an explicit artifact stands in for the host wiring
printf 'context-mode' >"$TL_TMP/cm-art"
rm -f "$TL_BIN/context-mode"; hash -r
no_t "no deny when Context Mode is not installed" sd "$READ_BIG" "$CFG" "$PR"
tl_stub context-mode 'exit 0'; hash -r
rm -rf "$SB_RUNTIME_STATE_DIR/context-mode-read-acks"
rm -f "$TL_TMP/cm-art"
no_t "no deny when Context Mode is not wired" sd "$READ_BIG" "$CFG" "$PR"
printf 'context-mode' >"$TL_TMP/cm-art"
assert_eq "deny the first large Read" "$BIG" "$(sd "$READ_BIG" "$CFG" "$PR")"
no_t "the repeated Read within the window is allowed (Edit needs exact bytes)" sd "$READ_BIG" "$CFG" "$PR"
rm -rf "$SB_RUNTIME_STATE_DIR/context-mode-read-acks"
yes_t "deny large Read (rc)" sd "$READ_BIG" "$CFG" "$PR"
rm -rf "$SB_RUNTIME_STATE_DIR/context-mode-read-acks"
assert_eq "deny read relative path" "$BIG" "$(sd "$(rj Read big.txt file_path)" "$CFG" "$PR")"
rm -rf "$SB_RUNTIME_STATE_DIR/context-mode-read-acks"
assert_eq "dotdot out of an exempt directory is still big.txt" "$BIG" "$(sd "$(rj Read "$PR/graphify-out/../big.txt" file_path)" "$CFG" "$PR")"
rm -rf "$SB_RUNTIME_STATE_DIR/context-mode-read-acks"
head -c 100 /dev/zero | tr '\0' 'a' >"$PR/small.txt"
no_t "allow small file" sd "$(rj Read small.txt file_path)" "$CFG" "$PR"
head -c 5120 /dev/zero | tr '\0' 'a' >"$PR/edge.txt"
no_t "allow file exactly at threshold" sd "$(rj Read edge.txt file_path)" "$CFG" "$PR"
head -c 5121 /dev/zero | tr '\0' 'a' >"$PR/edge2.txt"
yes_t "deny file one byte over threshold" sd "$(rj Read edge2.txt file_path)" "$CFG" "$PR"
no_t "allow missing file" sd "$(rj Read nope.txt file_path)" "$CFG" "$PR"
no_t "allow empty path" sd "$(rj Read "" file_path)" "$CFG" "$PR"
no_t "allow other tool" sd "$(rj Bash x command)" "$CFG" "$PR"
no_t "allow garbage input" sd 'garbage' "$CFG" "$PR"
no_t "allow an image" sd "$(rj Read "$PR/shot.png" file_path)" "$CFG" "$PR"
head -c 9000 /dev/zero | tr '\0' 'a' >"$PR/shot.png"
no_t "allow a large image (Read is the only way to see it)" sd "$(rj Read "$PR/shot.png" file_path)" "$CFG" "$PR"
head -c 9000 /dev/zero | tr '\0' 'a' >"$PR/.silver-bullet.json"
no_t "allow exempt large file" sd "$(rj Read "$PR/.silver-bullet.json" file_path)" "$CFG" "$PR"
no_t "bypass env allows" env CONTEXT_MODE_READ_DENY_BYPASS=1 bash -c 'source "$1"; shift; sb_context_mode_should_deny_read "$@"' _ "$TL_REPO_ROOT/hooks/lib/context-mode-read-deny.sh" "$READ_BIG" "$CFG" "$PR"
rm -rf "$SB_RUNTIME_STATE_DIR/context-mode-read-acks"
# a Read with a small limit brings in few bytes
printf 'a\n%.0s' $(seq 1 3000) >"$PR/lines.txt"
no_t "a Read with a small limit is allowed" sd "$(jq -cn --arg p "$PR/lines.txt" '{tool_name:"Read", tool_input:{file_path:$p, limit:50}}')" "$CFG" "$PR"
yes_t "a Read with a limit above the threshold is denied" sd "$(jq -cn --arg p "$PR/lines.txt" '{tool_name:"Read", tool_input:{file_path:$p, limit:2900}}')" "$CFG" "$PR"
rm -rf "$SB_RUNTIME_STATE_DIR/context-mode-read-acks"
yes_t "a limit larger than the file reads the whole file" sd "$(jq -cn --arg p "$PR/lines.txt" '{tool_name:"Read", tool_input:{file_path:$p, limit:99999}}')" "$CFG" "$PR"
rm -rf "$SB_RUNTIME_STATE_DIR/context-mode-read-acks"
printf 'x' >"$PR/nolines.txt"; head -c 9000 /dev/zero | tr '\0' 'b' >"$PR/nolines.txt"
yes_t "a file without newlines counts as one line" sd "$(jq -cn --arg p "$PR/nolines.txt" '{tool_name:"Read", tool_input:{file_path:$p, limit:3}}')" "$CFG" "$PR"
rm -rf "$SB_RUNTIME_STATE_DIR/context-mode-read-acks"
# Grep: only content output can pull a file in
GREP_FILES="$(jq -cn --arg p "$BIG" '{tool_name:"Grep", tool_input:{path:$p, pattern:"a"}}')"
GREP_CONTENT="$(jq -cn --arg p "$BIG" '{tool_name:"Grep", tool_input:{path:$p, pattern:"a", output_mode:"content"}}')"
GREP_LIMITED="$(jq -cn --arg p "$BIG" '{tool_name:"Grep", tool_input:{path:$p, pattern:"a", output_mode:"content", head_limit:20}}')"
no_t "Grep that lists files is allowed" sd "$GREP_FILES" "$CFG" "$PR"
no_t "Grep with a head_limit is allowed" sd "$GREP_LIMITED" "$CFG" "$PR"
yes_t "Grep with unlimited content output is denied" sd "$GREP_CONTENT" "$CFG" "$PR"
rm -rf "$SB_RUNTIME_STATE_DIR/context-mode-read-acks"
w '{"recommended_tools":{"context_mode":{"read_deny_bytes":0}}}'
no_t "zero threshold disables" sd "$READ_BIG" "$CFG" "$PR"
(cd "$PR" && w '{"recommended_tools":{"context_mode":{"enabled_by_user":true}}}' && sb_context_mode_should_deny_read "$(rj Read big.txt file_path)" "$CFG") && tl_pass "default project root is PWD" || tl_fail "default project root is PWD"
rm -rf "$SB_RUNTIME_STATE_DIR/context-mode-read-acks"
(
  sb_tool_name() { return 1; }
  [[ -z "$(sb_context_mode_tool_read_path "$READ_BIG")" ]] || exit 1
  sb_context_mode_should_deny_read "$READ_BIG" "$CFG" "$PR" && exit 2
  exit 0
) && tl_pass "tool name lookup failure yields no path and no deny" || tl_fail "tool name lookup failure (exit $?)"
(
  sb_context_mode_file_size_bytes() { return 1; }
  sd "$READ_BIG" "$CFG" "$PR" && exit 1
  exit 0
) && tl_pass "allow when size cannot be determined" || tl_fail "allow when size cannot be determined"
# LeanCTX owning sb_read: Grep stays cooperative; Read needs LeanCTX's own tools
sb_test_consent_grant leanctx install,wire,enforce
w '{"optimization_profiles":{"five_tool_routed":{"routes":{"sb_read":"leanctx"}}}}'
no_t "Grep allowed when leanctx active" sd "$GREP_CONTENT" "$CFG" "$PR"
rm -f "$SB_RUNTIME_STATE_DIR/consent-test"; rm -rf "$SB_RUNTIME_STATE_DIR/context-mode-read-acks"
no_t "Read allowed when LeanCTX owns reads but is not installed" sd "$READ_BIG" "$CFG" "$PR"
rm -rf "$SB_RUNTIME_STATE_DIR/context-mode-read-acks"
w '{"recommended_tools":{"context_mode":{"enabled_by_user":true}}}'

# deny message
m="$(sb_context_mode_read_deny_message /p/big 9000 5120)"
assert_contains "deny message" "$m" "large Read redirected once (9000 bytes > 5120 byte threshold)"
assert_contains "deny message says how to get the exact bytes" "$m" "Repeat the same Read"
assert_contains "deny message path" "$m" "Path: /p/big"
w '{"recommended_tools":{"leanctx":{"enabled_by_user":true},"context_mode":{"enabled_by_user":true}},"optimization_profiles":{"five_tool_routed":{"routes":{"sb_read":"leanctx"}}}}'
assert_contains "deny message defers to leanctx" "$(sb_context_mode_read_deny_message /p/big 9000 5120 "$CFG")" "LEANCTX READ ROUTING"
w '{"recommended_tools":{"context_mode":{"enabled_by_user":true}}}'
assert_contains "deny message with config but no leanctx" "$(sb_context_mode_read_deny_message /p/big 9000 5120 "$CFG")" "large Read redirected once"

tl_results
