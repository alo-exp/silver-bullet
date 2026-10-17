#!/usr/bin/env bash
# Extra behavior tests for hooks/lib/recommended-tools.sh and recommended-tools-registry.sh
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

# shellcheck source=../../hooks/lib/recommended-tools-registry.sh
source "$TL_REPO_ROOT/hooks/lib/recommended-tools-registry.sh"
# shellcheck source=../../hooks/lib/recommended-tools.sh
source "$TL_REPO_ROOT/hooks/lib/recommended-tools.sh"

CFG="$TL_TMP/cfg.json"
w() { printf '%s' "$1" >"$CFG"; }

# ---- registry ----
assert_eq "ids list" "graphify agentmemory alumnium search_cli rtk context_mode leanctx" "$(sb_recommended_tool_ids | tr '\n' ' ' | sed 's/ $//')"
for t in rtk context_mode; do
  sb_recommended_tool_is_token_compression "$t" && tl_pass "token compression $t" || tl_fail "token compression $t"
done
sb_recommended_tool_is_token_compression leanctx && tl_fail "leanctx not token compression" || tl_pass "leanctx not token compression"
sb_recommended_tool_is_token_compression "" && tl_fail "empty not token compression" || tl_pass "empty not token compression"
for t in rtk context_mode leanctx; do
  sb_recommended_tool_is_compression_stack "$t" && tl_pass "stack $t" || tl_fail "stack $t"
done
sb_recommended_tool_is_compression_stack graphify && tl_fail "graphify not stack" || tl_pass "graphify not stack"
assert_eq "display agentmemory" "agentmemory" "$(sb_recommended_tool_display_name agentmemory)"
assert_eq "display alumnium" "Alumnium" "$(sb_recommended_tool_display_name alumnium)"
assert_eq "display rtk" "RTK" "$(sb_recommended_tool_display_name rtk)"
assert_eq "display context_mode" "Context Mode" "$(sb_recommended_tool_display_name context_mode)"
assert_eq "display leanctx" "LeanCTX" "$(sb_recommended_tool_display_name leanctx)"
assert_eq "display search_cli" "search-cli" "$(sb_recommended_tool_display_name search_cli)"
assert_eq "display graphify" "Graphify" "$(sb_recommended_tool_display_name graphify)"
assert_eq "display unknown echoes" "zzz" "$(sb_recommended_tool_display_name zzz)"
assert_eq "display empty default" "tool" "$(sb_recommended_tool_display_name)"

pin="$(sb_recommended_tool_install_pin search_cli)"
assert_eq "pin version" "0.9.0" "$(jq -r .version <<<"$pin")"
expected_digest="$(printf '%s' 'brew tap paperfoot/tap && brew install paperfoot/tap/search-cli' | sha256sum | awk '{print $1}')"
assert_eq "pin digest (sha256sum path)" "$expected_digest" "$(jq -r .argv_digest <<<"$pin")"
tl_stub shasum 'echo SHASTUB-DIGEST-extra; cat >/dev/null'
pin="$(sb_recommended_tool_install_pin search_cli)"
assert_eq "pin digest (shasum path)" "SHASTUB-DIGEST-extra" "$(jq -r .argv_digest <<<"$pin")"
rm -f "$TL_BIN/shasum"
pin="$(PATH="$(tl_path_without shasum)" sb_recommended_tool_install_pin search_cli)"
assert_eq "pin digest (no shasum, sha256sum path)" "$expected_digest" "$(jq -r .argv_digest <<<"$pin")"
assert_eq "pin unknown empty object" "{}" "$(sb_recommended_tool_install_pin nope | jq -c .)"
assert_eq "pin no arg empty object" "{}" "$(sb_recommended_tool_install_pin | jq -c .)"

# ---- consent ----
assert_eq "consent missing file" "pending" "$(sb_recommended_tool_consent "$TL_TMP/nope.json" graphify)"
assert_eq "consent empty args" "pending" "$(sb_recommended_tool_consent)"
w '{"recommended_tools":{"rtk":{"enabled_by_user":"yes"}}}'
assert_eq "consent non-boolean value is pending" "pending" "$(sb_recommended_tool_consent "$CFG" rtk)"
w '{"recommended_tools":{"rtk":{"enabled_by_user":null}}}'
assert_eq "consent null falls through to pending" "pending" "$(sb_recommended_tool_consent "$CFG" rtk)"
w '{"recommended_tools":{"rtk":{"enabled_by_user":true}}}'
assert_eq "consent enabled" "enabled" "$(sb_recommended_tool_consent "$CFG" rtk)"
w '{"recommended_tools":{"rtk":{"enabled_by_user":false}}}'
assert_eq "consent disabled" "disabled" "$(sb_recommended_tool_consent "$CFG" rtk)"
w '{"graphify":{"required":false}}'
assert_eq "legacy graphify.required false" "disabled" "$(sb_recommended_tool_consent "$CFG" graphify)"
w '{"graphify":{"required":true}}'
assert_eq "legacy graphify.required true" "enabled" "$(sb_recommended_tool_consent "$CFG" graphify)"
w '{"graphify":{}}'
assert_eq "legacy graphify unset" "pending" "$(sb_recommended_tool_consent "$CFG" graphify)"
w '{"graphify":{"required":true}}'
assert_eq "legacy migration only for graphify" "pending" "$(sb_recommended_tool_consent "$CFG" rtk)"

# ---- suspended / enforced / config string ----
sb_recommended_tool_enforcement_suspended "" rtk && tl_fail "suspended no config" || tl_pass "suspended no config"
sb_recommended_tool_enforcement_suspended "$TL_TMP/nope.json" rtk && tl_fail "suspended missing file" || tl_pass "suspended missing file"
w '{"recommended_tools":{"rtk":{"enabled_by_user":true,"enforcement_suspended":true,"install_status":"failed","install_failure_reason":"boom"}}}'
sb_recommended_tool_enforcement_suspended "$CFG" rtk && tl_pass "suspended true" || tl_fail "suspended true"
sb_recommended_tool_enforced "$CFG" rtk && tl_fail "suspended not enforced" || tl_pass "suspended not enforced"
assert_eq "install_status" "failed" "$(sb_recommended_tool_install_status "$CFG" rtk)"
assert_eq "install_failure_reason" "boom" "$(sb_recommended_tool_install_failure_reason "$CFG" rtk)"
w '{"recommended_tools":{"rtk":{"enabled_by_user":true,"required_when_enabled":false}}}'
sb_recommended_tool_enforced "$CFG" rtk && tl_fail "required_when_enabled false" || tl_pass "required_when_enabled false"
w '{"recommended_tools":{"rtk":{"enabled_by_user":true}}}'
sb_recommended_tool_enforced "$CFG" rtk && tl_pass "enforced default" || tl_fail "enforced default"
assert_eq "config_string default on missing file" "dflt" "$(sb_recommended_tool_config_string "$TL_TMP/nope.json" rtk k dflt)"
assert_eq "config_string default on empty key" "dflt" "$(sb_recommended_tool_config_string "$CFG" rtk "" dflt)"
assert_eq "config_string missing key default" "dflt" "$(sb_recommended_tool_config_string "$CFG" rtk absent dflt)"
w 'not json'
assert_eq "config_string invalid json default" "dflt" "$(sb_recommended_tool_config_string "$CFG" rtk k dflt)"

# ---- benefits ----
w '{"recommended_tools":{"rtk":{"benefits_summary":"custom text"}}}'
assert_eq "benefits custom" "custom text" "$(sb_recommended_tool_benefits "$CFG" rtk)"
w '{}'
for t in graphify agentmemory alumnium rtk context_mode leanctx; do
  b="$(sb_recommended_tool_benefits "$CFG" "$t")"
  [[ -n "$b" && "$b" != "Improves SB workflow quality when enabled." ]] && tl_pass "benefits builtin $t" || tl_fail "benefits builtin $t"
done
assert_eq "benefits default" "Improves SB workflow quality when enabled." "$(sb_recommended_tool_benefits "$CFG" other)"

# ---- install commands ----
w '{"recommended_tools":{"rtk":{"install_commands":["a","b"]}}}'
assert_eq "install_commands lists" "a b" "$(sb_recommended_tool_install_commands "$CFG" rtk | tr '\n' ' ' | sed 's/ $//')"
assert_eq "install_commands missing file empty" "" "$(sb_recommended_tool_install_commands "$TL_TMP/nope.json" rtk)"

# ---- global toolstack manifest ----
(
  unset SB_GLOBAL_TOOLSTACK_MANIFEST SB_GLOBAL_TOOLSTACK_HOME FIVE_TOOL_STACK_HOME
  export SB_GLOBAL_TOOLSTACK_MANIFEST=/m/x.json
  [[ "$(sb_global_toolstack_manifest_path)" == "/m/x.json" ]] || exit 1
  unset SB_GLOBAL_TOOLSTACK_MANIFEST
  export SB_GLOBAL_TOOLSTACK_HOME=/h
  [[ "$(sb_global_toolstack_manifest_path)" == "/h/instances.json" ]] || exit 2
  unset SB_GLOBAL_TOOLSTACK_HOME
  export FIVE_TOOL_STACK_HOME=/f
  [[ "$(sb_global_toolstack_manifest_path)" == "/f/manifest.json" ]] || exit 3
  unset FIVE_TOOL_STACK_HOME
  export XDG_STATE_HOME=/xs
  [[ "$(sb_global_toolstack_manifest_path)" == "/xs/five-tool-stack/manifest.json" ]] || exit 4
  unset XDG_STATE_HOME
  [[ "$(sb_global_toolstack_manifest_path)" == "$HOME/.local/state/five-tool-stack/manifest.json" ]] || exit 5
) && tl_pass "manifest path precedence" || tl_fail "manifest path precedence (exit $?)"

export SB_GLOBAL_TOOLSTACK_MANIFEST="$TL_TMP/manifest.json"
BINX="$TL_TMP/real-tool"; printf '#!/bin/sh\n' >"$BINX"; chmod +x "$BINX"
NOEXEC="$TL_TMP/noexec-tool"; printf 'x' >"$NOEXEC"; chmod -x "$NOEXEC"
jq -n --arg a "$BINX" --arg b "$NOEXEC" '{tools:{abs:{command:$a},noexec:{command:$b},named:{command:"bash"},empty:{command:""},num:{command:5}}}' >"$SB_GLOBAL_TOOLSTACK_MANIFEST"
sb_global_tool_command "" && tl_fail "tool_command empty name" || tl_pass "tool_command empty name"
assert_eq "tool_command value" "$BINX" "$(sb_global_tool_command abs)"
sb_global_tool_command empty >/dev/null && tl_fail "tool_command empty string" || tl_pass "tool_command empty string"
sb_global_tool_command num >/dev/null && tl_fail "tool_command non-string" || tl_pass "tool_command non-string"
assert_eq "tool_path absolute" "$BINX" "$(sb_global_tool_path abs)"
assert_eq "tool_path name via PATH" "$(command -v bash)" "$(sb_global_tool_path named)"
sb_global_tool_path missing >/dev/null && tl_fail "tool_path unknown" || tl_pass "tool_path unknown"
if [[ "$(id -u)" != "0" ]]; then
  sb_global_tool_path noexec >/dev/null && tl_fail "tool_path non-exec" || tl_pass "tool_path non-exec"
else
  # root: -x is true for any file with an x bit; use a nonexistent absolute path instead
  jq -n '{tools:{gone:{command:"/nonexistent/dir/tool"}}}' >"$SB_GLOBAL_TOOLSTACK_MANIFEST"
  sb_global_tool_path gone >/dev/null && tl_fail "tool_path absolute missing" || tl_pass "tool_path absolute missing"
fi
export SB_GLOBAL_TOOLSTACK_MANIFEST="$TL_TMP/absent-manifest.json"
sb_global_tool_command abs >/dev/null && tl_fail "tool_command no manifest" || tl_pass "tool_command no manifest"
unset SB_GLOBAL_TOOLSTACK_MANIFEST

# ---- host detection ----
host_clean() { env -u SILVER_BULLET_RUNTIME -u CODEX_CI -u CODEX_THREAD_ID -u CODEX_INTERNAL_ORIGINATOR_OVERRIDE -u CURSOR_PLUGIN_ROOT -u CLAUDE_PLUGIN_ROOT -u OPENCODE -u OPENCODE_PID -u PI_CODING_AGENT_DIR "$@" bash -c 'source "$1"; sb_runtime_host' _ "$TL_REPO_ROOT/hooks/lib/recommended-tools.sh"; }
assert_eq "host explicit goose" "goose" "$(host_clean SILVER_BULLET_RUNTIME=goose)"
assert_eq "host explicit invalid falls back" "claude" "$(host_clean SILVER_BULLET_RUNTIME=bogus)"
assert_eq "host codex CI" "codex" "$(host_clean CODEX_CI=1)"
assert_eq "host codex thread" "codex" "$(host_clean CODEX_THREAD_ID=t)"
assert_eq "host cursor root" "cursor" "$(host_clean CURSOR_PLUGIN_ROOT=/x)"
assert_eq "host plugin root codex" "codex" "$(host_clean CLAUDE_PLUGIN_ROOT=/h/.codex/p)"
assert_eq "host plugin root cursor" "cursor" "$(host_clean CLAUDE_PLUGIN_ROOT=/h/.cursor/p)"
assert_eq "host plugin root other is claude" "claude" "$(host_clean CLAUDE_PLUGIN_ROOT=/h/.claude/p)"
assert_eq "host opencode" "opencode" "$(host_clean OPENCODE=1)"
assert_eq "host opencode pid" "opencode" "$(host_clean OPENCODE_PID=9)"
assert_eq "host pi" "pi" "$(host_clean PI_CODING_AGENT_DIR=/p)"
assert_eq "host default claude" "claude" "$(host_clean FOO=1)"

assert_eq "upstream platform goose" "pi" "$(sb_graphify_upstream_platform goose)"
assert_eq "upstream platform codex" "codex" "$(sb_graphify_upstream_platform codex)"
assert_eq "upstream platform default host" "$(sb_runtime_host)" "$(sb_graphify_upstream_platform)"

# ---- platform install commands ----
w '{}'
pre() { sb_recommended_tool_platform_pre_index_commands "$CFG" "$1" "$2"; }
post() { sb_recommended_tool_platform_post_index_commands "$CFG" "$1" "$2"; }
assert_eq "gfy pre claude" "graphify install --project" "$(pre graphify claude)"
assert_eq "gfy pre codex" "graphify install --project --platform codex" "$(pre graphify codex)"
assert_eq "gfy pre opencode" "graphify install --project --platform opencode" "$(pre graphify opencode)"
assert_contains "gfy pre pi" "$(pre graphify pi)" "install-pi.py"
assert_eq "gfy pre goose" "graphify install --project --platform pi" "$(pre graphify goose)"
assert_eq "gfy pre hermes" "graphify install --project --platform hermes" "$(pre graphify hermes)"
assert_eq "gfy pre cursor none" "" "$(pre graphify cursor)"
assert_contains "am pre codex" "$(pre agentmemory codex)" "codex plugin add agentmemory@agentmemory"
assert_contains "am pre pi" "$(pre agentmemory pi)" "agentmemory connect pi"
assert_eq "am pre claude none" "" "$(pre agentmemory claude)"
assert_eq "rtk pre claude" "rtk init -g" "$(pre rtk claude)"
assert_eq "rtk pre cursor" "rtk init -g --agent cursor" "$(pre rtk cursor)"
assert_eq "rtk pre codex" "rtk init -g --codex" "$(pre rtk codex)"
assert_contains "rtk pre opencode" "$(pre rtk opencode)" "--host opencode"
assert_contains "rtk pre pi" "$(pre rtk pi)" "--host pi"
assert_eq "rtk pre hermes none" "" "$(pre rtk hermes)"
assert_contains "cm pre claude" "$(pre context_mode claude)" "npm install -g context-mode"
assert_contains "cm pre cursor" "$(pre context_mode cursor)" "context-mode.mdc"
assert_contains "cm pre codex" "$(pre context_mode codex)" "config.toml"
assert_contains "cm pre opencode" "$(pre context_mode opencode)" "opencode.json"
assert_contains "cm pre pi" "$(pre context_mode pi)" "install-pi.py"
assert_eq "cm pre hermes none" "" "$(pre context_mode hermes)"
assert_contains "lean pre claude" "$(pre leanctx claude)" "install-leanctx-sb.sh --host claude"
assert_eq "lean pre goose none" "" "$(pre leanctx goose)"
assert_eq "unknown tool pre none" "" "$(pre other claude)"
w '{"recommended_tools":{"graphify":{"platform_install_commands":{"claude":{"pre_index":["x one","x two"],"post_index":["y one"]}}}}}'
assert_eq "pre from config" "x one
x two" "$(pre graphify claude)"
assert_eq "post from config" "y one" "$(post graphify claude)"
assert_eq "platform install joined" "x one
x two
y one" "$(sb_recommended_tool_platform_install_commands "$CFG" graphify claude)"
w '{}'
assert_eq "platform install default host" "$(pre graphify "$(sb_runtime_host)")
$(post graphify "$(sb_runtime_host)")" "$(sb_recommended_tool_platform_install_commands "$CFG" graphify)"
assert_eq "platform install pre only" "$(pre graphify opencode)" "$(sb_recommended_tool_platform_install_commands "$CFG" graphify opencode)"
assert_eq "platform install post only" "graphify cursor install" "$(sb_recommended_tool_platform_install_commands "$CFG" graphify cursor)"

assert_eq "gfy post cursor" "graphify cursor install" "$(post graphify cursor)"
assert_eq "gfy post claude" "graphify claude install --project" "$(post graphify claude)"
assert_eq "gfy post codex" "graphify codex install --project" "$(post graphify codex)"
assert_eq "gfy post opencode none" "" "$(post graphify opencode)"
assert_eq "am post claude" "agentmemory connect claude-code" "$(post agentmemory claude)"
assert_eq "am post codex" "agentmemory connect codex --with-hooks" "$(post agentmemory codex)"
assert_eq "am post goose" "agentmemory connect pi" "$(post agentmemory goose)"
assert_eq "am post pi" "agentmemory connect pi" "$(post agentmemory pi)"
assert_eq "am post hermes" "agentmemory connect hermes" "$(post agentmemory hermes)"
assert_contains "am post opencode" "$(post agentmemory opencode)" "Merge agentmemory MCP"
assert_eq "am post cursor none" "" "$(post agentmemory cursor)"
assert_contains "cm post claude" "$(post context_mode claude)" "Restart Claude Code"
assert_eq "cm post codex none" "" "$(post context_mode codex)"
assert_eq "other tool post none" "" "$(post rtk claude)"
# legacy flat arrays
w '{"recommended_tools":{"graphify":{"platform_install_commands":{"cursor":["c1","c2"],"claude":["a1","a2"],"pi":["p1"]}}}}'
assert_eq "legacy flat cursor post-only" "c1c2" "$(post graphify cursor | tr -d '\n')"
assert_eq "legacy flat claude last cmd" "a2" "$(post graphify claude)"
assert_eq "legacy flat pi falls to builtin (none)" "" "$(post graphify pi)"

# default host argument and unreadable-config fallbacks
assert_eq "pre default host" "rtk init -g" "$(SILVER_BULLET_RUNTIME=claude sb_recommended_tool_platform_pre_index_commands "$CFG" rtk)"
assert_eq "post default host" "agentmemory connect claude-code" "$(SILVER_BULLET_RUNTIME=claude sb_recommended_tool_platform_post_index_commands "$CFG" agentmemory)"
assert_eq "pre with unparsable config uses builtin" "rtk init -g" "$(sb_recommended_tool_platform_pre_index_commands "$TL_TMP/nope.json" rtk claude)"
assert_eq "post with unparsable config uses builtin" "agentmemory connect claude-code" "$(sb_recommended_tool_platform_post_index_commands "$TL_TMP/nope.json" agentmemory claude)"

# ---- graphify platform artifact ----
PR="$TL_TMP/proj"; mkdir -p "$PR"
assert_eq "artifact cursor" "$PR/.cursor/rules/graphify.mdc" "$(sb_graphify_platform_artifact_path "$PR/" cursor)"
assert_eq "artifact codex" "$PR/.codex/hooks.json" "$(sb_graphify_platform_artifact_path "$PR" codex)"
assert_eq "artifact opencode" "$HOME/.config/opencode/opencode.json" "$(sb_graphify_platform_artifact_path "$PR" opencode)"
assert_eq "artifact pi env" "/pidir/extensions/silver-bullet-five-tool-stack/config.json" "$(PI_CODING_AGENT_DIR=/pidir sb_graphify_platform_artifact_path "$PR" pi)"
assert_eq "artifact pi home" "$HOME/.pi/agent/extensions/silver-bullet-five-tool-stack/config.json" "$(env -u PI_CODING_AGENT_DIR bash -c 'source "$1"; sb_graphify_platform_artifact_path /x pi' _ "$TL_REPO_ROOT/hooks/lib/recommended-tools.sh")"
assert_eq "artifact goose" "$PR/.pi/agent/skills/graphify/SKILL.md" "$(sb_graphify_platform_artifact_path "$PR" goose)"
assert_eq "artifact hermes" "$PR/AGENTS.md" "$(sb_graphify_platform_artifact_path "$PR" hermes)"
assert_eq "artifact claude" "$PR/.claude/settings.json" "$(sb_graphify_platform_artifact_path "$PR" claude)"
assert_eq "artifact unknown host" "$PR/.claude/settings.json" "$(sb_graphify_platform_artifact_path "$PR" weird)"
assert_eq "artifact default host" "$PR/.claude/settings.json" "$(SILVER_BULLET_RUNTIME=claude sb_graphify_platform_artifact_path "$PR")"
mkdir -p "$PR/.claude"
sb_graphify_platform_artifact_present "$PR" claude && tl_fail "artifact absent" || tl_pass "artifact absent"
printf '{"hooks":"graphify"}' >"$PR/.claude/settings.json"
sb_graphify_platform_artifact_present "$PR" claude && tl_pass "artifact present" || tl_fail "artifact present"
sb_graphify_platform_artifact_present "$PR" && tl_pass "artifact present default host" || tl_fail "artifact present default host"
sb_graphify_platform_artifact_present "$PR" weird && tl_pass "artifact present unknown host" || tl_fail "artifact present unknown host"
printf '{}' >"$PR/.claude/settings.json"
sb_graphify_platform_artifact_present "$PR" claude && tl_fail "artifact without graphify text" || tl_pass "artifact without graphify text"
rm "$PR/.claude/settings.json"; printf 'graphify' >"$TL_TMP/real.json"; ln -s "$TL_TMP/real.json" "$PR/.claude/settings.json"
sb_graphify_platform_artifact_present "$PR" claude && tl_fail "symlink artifact refused" || tl_pass "symlink artifact refused"

# ---- full install lines ----
w '{}'
assert_contains "full lines graphify default" "$(sb_recommended_tool_full_install_lines "$CFG" graphify claude)" "uv tool install 'graphifyy[mcp]'"
assert_contains "full lines graphify has platform" "$(sb_recommended_tool_full_install_lines "$CFG" graphify claude)" "graphify claude install --project"
assert_contains "full lines agentmemory" "$(sb_recommended_tool_full_install_lines "$CFG" agentmemory claude)" "npm install -g @agentmemory/agentmemory"
assert_contains "full lines rtk" "$(sb_recommended_tool_full_install_lines "$CFG" rtk claude)" "brew tap rtk-ai/rtk"
assert_contains "full lines context_mode" "$(sb_recommended_tool_full_install_lines "$CFG" context_mode claude)" "npm install -g context-mode"
assert_contains "full lines leanctx" "$(sb_recommended_tool_full_install_lines "$CFG" leanctx claude)" "leanctx.com/install.sh"
assert_eq "full lines unknown tool empty" "" "$(sb_recommended_tool_full_install_lines "$CFG" other claude)"
assert_eq "full lines alumnium only cli lines" "" "$(sb_recommended_tool_full_install_lines "$CFG" alumnium claude)"
w '{"recommended_tools":{"rtk":{"install_commands":["custom install"]}}}'
assert_eq "full lines custom + platform" "custom install
rtk init -g" "$(sb_recommended_tool_full_install_lines "$CFG" rtk claude)"
assert_eq "full lines default host" "custom install
rtk init -g" "$(SILVER_BULLET_RUNTIME=claude sb_recommended_tool_full_install_lines "$CFG" rtk)"

# ---- consent prompt block ----
w '{}'
blk="$(sb_recommended_tool_consent_prompt_block "$CFG" rtk)"
assert_contains "block pending header" "$blk" "RECOMMENDED TOOL CONSENT PENDING — rtk"
assert_contains "block pending lists install" "$blk" "brew tap rtk-ai/rtk"
w '{"recommended_tools":{"rtk":{"enabled_by_user":false}}}'
assert_contains "block disabled" "$(sb_recommended_tool_consent_prompt_block "$CFG" rtk)" "opted out for this project"
w '{"recommended_tools":{"rtk":{"enabled_by_user":true,"enforcement_suspended":true,"install_failure_reason":"disk full"}}}'
blk="$(sb_recommended_tool_consent_prompt_block "$CFG" rtk)"
assert_contains "block suspended" "$blk" "install failed — enforcement suspended"
assert_contains "block suspended reason" "$blk" "Failure reason: disk full"
w '{"recommended_tools":{"rtk":{"enabled_by_user":true,"enforcement_suspended":true}}}'
assert_not_contains "block suspended no reason" "$(sb_recommended_tool_consent_prompt_block "$CFG" rtk)" "Failure reason"

# enabled branches: define the availability predicates the block probes via declare -f
ENABLED() { printf '{"recommended_tools":{"%s":{"enabled_by_user":true}}}' "$1"; }
FAKE_GFY_CLI=1 FAKE_GFY_IDX=1
sb_graphify_cli_available() { [[ "$FAKE_GFY_CLI" == 1 ]]; }
sb_graphify_index_exists() { [[ "$FAKE_GFY_IDX" == 1 ]]; }
sb_graphify_graph_rel_path() { printf 'graphify-out/graph.json'; }
w "$(ENABLED graphify)"
FAKE_GFY_CLI=0
assert_contains "graphify CLI missing" "$(sb_recommended_tool_consent_prompt_block "$CFG" graphify)" "Graphify enabled but CLI missing"
FAKE_GFY_CLI=1 FAKE_GFY_IDX=0
assert_contains "graphify index missing" "$(sb_recommended_tool_consent_prompt_block "$CFG" graphify)" "index missing. Run: graphify update . --no-cluster (expected graphify-out/graph.json)"
FAKE_GFY_IDX=1
assert_eq "graphify all good prints nothing" "" "$(sb_recommended_tool_consent_prompt_block "$CFG" graphify)"

FAKE_AM_CLI=1 FAKE_AM_SRV=1 FAKE_AM_EXP=1
sb_agentmemory_cli_available() { [[ "$FAKE_AM_CLI" == 1 ]]; }
sb_agentmemory_server_healthy() { [[ "$FAKE_AM_SRV" == 1 ]]; }
sb_agentmemory_export_exists() { [[ "$FAKE_AM_EXP" == 1 ]]; }
sb_agentmemory_export_rel_path() { printf '.agentmemory'; }
w "$(ENABLED agentmemory)"
FAKE_AM_CLI=0
assert_contains "am CLI missing" "$(sb_recommended_tool_consent_prompt_block "$CFG" agentmemory)" "agentmemory enabled but CLI missing"
FAKE_AM_CLI=1 FAKE_AM_SRV=0
assert_contains "am server unhealthy" "$(sb_recommended_tool_consent_prompt_block "$CFG" agentmemory)" "server not healthy"
FAKE_AM_SRV=1 FAKE_AM_EXP=0
assert_contains "am export missing" "$(sb_recommended_tool_consent_prompt_block "$CFG" agentmemory)" "mkdir -p .agentmemory/memory .agentmemory/snapshots"
FAKE_AM_EXP=1
assert_eq "am all good prints nothing" "" "$(sb_recommended_tool_consent_prompt_block "$CFG" agentmemory)"

FAKE_RTK_CLI=1 FAKE_RTK_HOOK=1
sb_rtk_cli_available() { [[ "$FAKE_RTK_CLI" == 1 ]]; }
sb_rtk_platform_hook_present() { [[ "$FAKE_RTK_HOOK" == 1 ]]; }
w "$(ENABLED rtk)"
FAKE_RTK_CLI=0
assert_contains "rtk CLI missing" "$(sb_recommended_tool_consent_prompt_block "$CFG" rtk)" "RTK enabled but CLI missing or wrong binary"
FAKE_RTK_CLI=1 FAKE_RTK_HOOK=0
assert_contains "rtk hook not wired" "$(sb_recommended_tool_consent_prompt_block "$CFG" rtk)" "host hook not wired for"
FAKE_RTK_HOOK=1
assert_eq "rtk all good prints nothing" "" "$(sb_recommended_tool_consent_prompt_block "$CFG" rtk)"

FAKE_CM_NODE=1 FAKE_CM_CLI=1 FAKE_CM_FRAG=1
sb_context_mode_cli_available() { [[ "$FAKE_CM_CLI" == 1 ]]; }
sb_context_mode_node_ok() { [[ "$FAKE_CM_NODE" == 1 ]]; }
sb_context_mode_instruction_fragment_present() { [[ "$FAKE_CM_FRAG" == 1 ]]; }
w "$(ENABLED context_mode)"
FAKE_CM_NODE=0
assert_contains "cm node too old" "$(sb_recommended_tool_consent_prompt_block "$CFG" context_mode)" "Node >= 22.5 required"
FAKE_CM_NODE=1 FAKE_CM_CLI=0
assert_contains "cm not installed" "$(sb_recommended_tool_consent_prompt_block "$CFG" context_mode)" "Context Mode enabled but not installed"
FAKE_CM_CLI=1 FAKE_CM_FRAG=0
assert_contains "cm fragment missing" "$(sb_recommended_tool_consent_prompt_block "$CFG" context_mode)" "instruction fragment missing"
FAKE_CM_FRAG=1
assert_eq "cm all good prints nothing" "" "$(sb_recommended_tool_consent_prompt_block "$CFG" context_mode)"
w "$(ENABLED alumnium)"
assert_eq "enabled tool without predicates prints nothing" "" "$(sb_recommended_tool_consent_prompt_block "$CFG" alumnium)"

# ---- graphify alias + stack helpers ----
w '{"recommended_tools":{"graphify":{"enabled_by_user":true}}}'
sb_graphify_required "$CFG" && tl_pass "graphify_required" || tl_fail "graphify_required"
sb_graphify_required "$TL_TMP/nope.json" && tl_fail "graphify_required missing file" || tl_pass "graphify_required missing file"

sb_stack_leanctx_active "" && tl_fail "leanctx_active no cfg" || tl_pass "leanctx_active no cfg"
w '{"recommended_tools":{"leanctx":{"enabled_by_user":true}}}'
sb_stack_leanctx_active "$CFG" && tl_pass "leanctx_active enabled" || tl_fail "leanctx_active enabled"
w '{"recommended_tools":{"leanctx":{"enabled_by_user":false}}}'
sb_stack_leanctx_active "$CFG" && tl_fail "leanctx_active disabled" || tl_pass "leanctx_active disabled"
w '{"recommended_tools":{"leanctx":{"enabled_by_user":true,"enforcement_suspended":true}}}'
sb_stack_leanctx_active "$CFG" && tl_fail "leanctx_active suspended" || tl_pass "leanctx_active suspended"

sb_stack_surface_owner "" Read && tl_fail "owner no cfg" || tl_pass "owner no cfg"
w '{}'
sb_stack_surface_owner "$CFG" "" && tl_fail "owner empty surface" || tl_pass "owner empty surface"
sb_stack_surface_owner "$CFG" Bogus && tl_fail "owner unknown surface" || tl_pass "owner unknown surface"
assert_eq "legacy Read" "context_mode" "$(sb_stack_surface_owner "$CFG" Read)"
assert_eq "legacy Grep" "context_mode" "$(sb_stack_surface_owner "$CFG" Grep)"
assert_eq "legacy WebFetch" "context_mode" "$(sb_stack_surface_owner "$CFG" WebFetch)"
assert_eq "legacy sb_slice" "context_mode" "$(sb_stack_surface_owner "$CFG" sb_slice)"
assert_eq "legacy Bash" "rtk" "$(sb_stack_surface_owner "$CFG" Bash)"
assert_eq "legacy sb_graph" "graphify" "$(sb_stack_surface_owner "$CFG" sb_graph)"
assert_eq "legacy sb_remember" "agentmemory" "$(sb_stack_surface_owner "$CFG" sb_remember)"
sb_stack_surface_owner "$CFG" sb_wire && tl_fail "legacy sb_wire has no owner" || tl_pass "legacy sb_wire has no owner"
sb_stack_surface_owner "$CFG" sb_pathjail && tl_fail "legacy sb_pathjail has no owner" || tl_pass "legacy sb_pathjail has no owner"
w '{"recommended_tools":{"leanctx":{"enabled_by_user":true,"optimization_profile":"p1"}},"optimization_profiles":{"p1":{"routes":{"sb_read":"leanctx","sb_shell":"rtk"}},"five_tool_routed":{"routes":{"sb_read":"WRONG"}}}}'
assert_eq "profile owner from config" "leanctx" "$(sb_stack_surface_owner "$CFG" Read)"
assert_eq "profile owner via sb_ route" "rtk" "$(sb_stack_surface_owner "$CFG" sb_shell)"
assert_eq "profile missing route falls back to legacy" "context_mode" "$(sb_stack_surface_owner "$CFG" Grep)"
w '{"recommended_tools":{"leanctx":{"enabled_by_user":true}},"optimization_profiles":{"five_tool_routed":{"routes":{"sb_read":"leanctx"}}}}'
assert_eq "default profile five_tool_routed" "leanctx" "$(sb_stack_surface_owner "$CFG" Read)"
w '{"recommended_tools":{"leanctx":{"enabled_by_user":true,"optimization_profile":"p1"}},"optimization_profiles":{"p1":{"routes":{"sb_read":null}}}}'
REAL_JQ="$(command -v jq)"
tl_stub jq 'for a in "$@"; do case "$a" in *optimization_profile*) exit 1;; esac; done; exec '"$REAL_JQ"' "$@"'
hash -r
assert_eq "profile/route lookup failure falls back to legacy" "context_mode" "$(sb_stack_surface_owner "$CFG" Read)"
rm -f "$TL_BIN/jq"
hash -r
assert_eq "null route falls back to legacy" "context_mode" "$(sb_stack_surface_owner "$CFG" Read)"

tl_results
