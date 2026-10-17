#!/usr/bin/env bash
# Behavior tests for hooks/lib/graphify-am-global.sh. Every external tool
# (graphify, agentmemory, launchctl, brew, curl, gitleaks, codex) is a logging stub.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude
unset CI GA_SKIP_HOST_HOOKS GA_GLOBAL_DRY_RUN GA_AGENTMEMORY_HOME

LIBF="$TL_REPO_ROOT/hooks/lib/graphify-am-global.sh"
# shellcheck source=../../hooks/lib/graphify-am-global.sh
source "$LIBF"

yes_t() { local n="$1"; shift; if "$@"; then tl_pass "$n"; else tl_fail "$n"; fi; }
no_t() { local n="$1"; shift; if "$@"; then tl_fail "$n"; else tl_pass "$n"; fi; }
LOG="$TL_TMP/calls.log"
stub_log() { # name [exit-code-expression]
  tl_stub "$1" 'printf "%s %s\n" "'"$1"'" "$*" >>"'"$LOG"'"; '"${2:-exit 0}"
  hash -r
}
calls() { cat "$LOG" 2>/dev/null || true; }
reset_calls() { : >"$LOG"; }
reset_calls
PB="$(tl_path_without graphify agentmemory curl gitleaks brew apt-get node launchctl jq python3)"

# ---------- flags ----------
no_t "skip hooks default" ga_skip_host_hooks
yes_t "skip hooks CI=true" env CI=true bash -c 'source "$1"; ga_skip_host_hooks' _ "$LIBF"
yes_t "skip hooks CI=1" env CI=1 bash -c 'source "$1"; ga_skip_host_hooks' _ "$LIBF"
yes_t "skip hooks GA_SKIP_HOST_HOOKS=1" env GA_SKIP_HOST_HOOKS=1 bash -c 'source "$1"; ga_skip_host_hooks' _ "$LIBF"
no_t "skip hooks CI=false" env CI=false bash -c 'source "$1"; ga_skip_host_hooks' _ "$LIBF"
no_t "dry run default" ga_dry_run
yes_t "dry run on" env GA_GLOBAL_DRY_RUN=1 bash -c 'source "$1"; ga_dry_run' _ "$LIBF"
assert_eq "agentmemory home default" "$HOME/.agentmemory" "$(ga_agentmemory_home)"
assert_eq "agentmemory home override" "/x/am" "$(GA_AGENTMEMORY_HOME=/x/am ga_agentmemory_home)"
for h in claude codex opencode goose hermes; do yes_t "validate host $h" ga_validate_host "$h"; done
no_t "validate host cursor" ga_validate_host cursor
no_t "validate host empty" ga_validate_host ""
assert_eq "upstream goose" "pi" "$(ga_graphify_upstream_platform goose)"
assert_eq "upstream codex" "codex" "$(ga_graphify_upstream_platform codex)"
assert_eq "abs export with repo" "/r/p/.agentmemory" "$(ga_abs_export_path /r/p/)"
assert_eq "abs export fallback" "$HOME/.agentmemory/default-export" "$(ga_abs_export_path)"

# ---------- host config present ----------
for h in claude codex opencode goose hermes bogus; do no_t "no config $h" ga_host_config_present "$h"; done
printf '{}' >"$HOME/.claude.json"; yes_t "config claude" ga_host_config_present claude
mkdir -p "$HOME/.codex"; : >"$HOME/.codex/config.toml"; yes_t "config codex" ga_host_config_present codex
mkdir -p "$HOME/.config/opencode"; : >"$HOME/.config/opencode/opencode.json"; yes_t "config opencode" ga_host_config_present opencode
mkdir -p "$HOME/.config/goose"; : >"$HOME/.config/goose/config.yaml"; yes_t "config goose yaml" ga_host_config_present goose
rm -rf "$HOME/.config/goose"; no_t "goose gone" ga_host_config_present goose
mkdir -p "$HOME/.pi/agent"; yes_t "config goose pi dir" ga_host_config_present goose
mkdir -p "$HOME/.hermes"; yes_t "config hermes dir" ga_host_config_present hermes
rm -rf "$HOME/.hermes"; mkdir -p "$HOME/.hermes"; : >"$HOME/.hermes/config.yaml"; yes_t "config hermes yaml" ga_host_config_present hermes
assert_eq "detect configured hosts" "claude codex opencode goose hermes" "$(ga_detect_configured_hosts | tr '\n' ' ' | sed 's/ $//')"
rm -rf "$HOME/.claude.json" "$HOME/.codex" "$HOME/.config" "$HOME/.pi" "$HOME/.hermes"
assert_eq "detect configured hosts none" "" "$(ga_detect_configured_hosts)"

# ---------- command tables ----------
assert_eq "gfy pre claude" "graphify install" "$(ga_graphify_pre_commands claude)"
assert_eq "gfy pre codex" "graphify install --platform codex" "$(ga_graphify_pre_commands codex)"
assert_eq "gfy pre goose" "graphify install --platform pi" "$(ga_graphify_pre_commands goose)"
assert_eq "gfy pre opencode" "graphify install --platform opencode" "$(ga_graphify_pre_commands opencode)"
assert_eq "gfy pre hermes" "graphify install --platform hermes" "$(ga_graphify_pre_commands hermes)"
assert_eq "gfy pre unknown" "" "$(ga_graphify_pre_commands nope)"
assert_eq "gfy post claude" "graphify claude install" "$(ga_graphify_post_commands claude)"
assert_eq "gfy post codex" "graphify codex install" "$(ga_graphify_post_commands codex)"
assert_eq "gfy post opencode" "graphify opencode install" "$(ga_graphify_post_commands opencode)"
assert_eq "gfy post hermes" "graphify hermes install" "$(ga_graphify_post_commands hermes)"
assert_eq "gfy post goose" "graphify pi install" "$(ga_graphify_post_commands goose)"
assert_eq "gfy post unknown" "" "$(ga_graphify_post_commands nope)"
assert_eq "am cmds claude" "agentmemory connect claude-code" "$(ga_agentmemory_commands claude)"
assert_eq "am cmds codex" "codex plugin marketplace add rohitg00/agentmemory
codex plugin add agentmemory@agentmemory
agentmemory connect codex --with-hooks" "$(ga_agentmemory_commands codex)"
assert_eq "am cmds goose" "agentmemory connect pi" "$(ga_agentmemory_commands goose)"
assert_eq "am cmds hermes" "agentmemory connect hermes" "$(ga_agentmemory_commands hermes)"
assert_eq "am cmds opencode none" "" "$(ga_agentmemory_commands opencode)"

# ---------- artifacts ----------
assert_eq "gfy artifact claude" "$HOME/.claude/skills/graphify/SKILL.md" "$(ga_graphify_global_artifact_path claude)"
assert_eq "gfy artifact codex" "$HOME/.codex/skills/graphify/SKILL.md" "$(ga_graphify_global_artifact_path codex)"
assert_eq "gfy artifact opencode" "$HOME/.config/opencode/opencode.json" "$(ga_graphify_global_artifact_path opencode)"
assert_eq "gfy artifact goose" "$HOME/.pi/agent/skills/graphify/SKILL.md" "$(ga_graphify_global_artifact_path goose)"
assert_eq "gfy artifact hermes" "$HOME/.hermes/skills/graphify/SKILL.md" "$(ga_graphify_global_artifact_path hermes)"
no_t "gfy artifact unknown" ga_graphify_global_artifact_path nope
assert_eq "am artifact claude" "$HOME/.claude.json" "$(ga_agentmemory_global_artifact_path claude)"
assert_eq "am artifact codex" "$HOME/.codex/config.toml" "$(ga_agentmemory_global_artifact_path codex)"
assert_eq "am artifact opencode" "$HOME/.config/opencode/opencode.json" "$(ga_agentmemory_global_artifact_path opencode)"
assert_eq "am artifact goose" "$HOME/.config/goose/config.yaml" "$(ga_agentmemory_global_artifact_path goose)"
assert_eq "am artifact hermes" "$HOME/.hermes/config.yaml" "$(ga_agentmemory_global_artifact_path hermes)"
no_t "am artifact unknown" ga_agentmemory_global_artifact_path nope
no_t "gfy present unknown host" ga_graphify_artifact_present nope
no_t "gfy present missing file" ga_graphify_artifact_present claude
mkdir -p "$HOME/.claude/skills/graphify"; printf 'nothing' >"$HOME/.claude/skills/graphify/SKILL.md"
no_t "gfy present without marker" ga_graphify_artifact_present claude
printf 'graphify skill' >"$HOME/.claude/skills/graphify/SKILL.md"
yes_t "gfy present" ga_graphify_artifact_present claude
no_t "am present unknown host" ga_agentmemory_artifact_present nope
no_t "am present missing file" ga_agentmemory_artifact_present claude
printf '{}' >"$HOME/.claude.json"
no_t "am present without marker" ga_agentmemory_artifact_present claude
printf '{"agentmemory":1}' >"$HOME/.claude.json"
yes_t "am present" ga_agentmemory_artifact_present claude

# chmod failure on the env file is tolerated
tl_stub chmod 'exit 1'; hash -r
GA_AGENTMEMORY_HOME="$TL_TMP/amhome-chmod" ga_merge_agentmemory_env /c/repo
assert_contains "env written even if chmod fails" "$(cat "$TL_TMP/amhome-chmod/.env")" "AGENTMEMORY_EXPORT_ROOT=/c/repo/.agentmemory"
rm -f "$TL_BIN/chmod"; hash -r

# ---------- merge env ----------
AMH="$TL_TMP/amhome"; export GA_AGENTMEMORY_HOME="$AMH"
EF="$AMH/.env"
ga_merge_agentmemory_env /repo/.agentmemory
assert_file_exists "env created" "$EF"
assert_contains "env has flags" "$(cat "$EF")" "AGENTMEMORY_INJECT_CONTEXT=true"
assert_contains "env export root from arg" "$(cat "$EF")" "AGENTMEMORY_EXPORT_ROOT=/repo/.agentmemory"
assert_eq "env mode 600" "-rw-------" "$(ls -l "$EF" | cut -c1-10)"
assert_file_absent "no backup when env was new" "$EF.bak"
printf 'USER_SETTING=1\n' >"$EF"
ga_merge_agentmemory_env /other/repo
assert_file_exists "backup written" "$EF.bak"
assert_eq "backup is previous content" "USER_SETTING=1" "$(cat "$EF.bak")"
assert_contains "repo arg becomes <repo>/.agentmemory" "$(cat "$EF")" "AGENTMEMORY_EXPORT_ROOT=/other/repo/.agentmemory"
assert_contains "user setting preserved" "$(cat "$EF")" "USER_SETTING=1"
ga_merge_agentmemory_env /third/repo
assert_eq "managed block replaced, not duplicated" "1" "$(grep -c '# === graphify-am synergy_max managed block ===' "$EF")"
assert_not_contains "old export root removed" "$(cat "$EF")" "/other/repo/.agentmemory"
assert_contains "new export root present" "$(cat "$EF")" "/third/repo/.agentmemory"
assert_contains "user setting survives replace" "$(cat "$EF")" "USER_SETTING=1"
ga_merge_agentmemory_env ""
assert_contains "empty arg uses fallback export" "$(cat "$EF")" "AGENTMEMORY_EXPORT_ROOT=$HOME/.agentmemory/default-export"
before="$(cat "$EF")"
assert_eq "dry run message" "DRY-RUN: merge $EF (backup .env.bak)" "$(GA_GLOBAL_DRY_RUN=1 ga_merge_agentmemory_env /dry/repo)"
assert_eq "dry run leaves env untouched" "$before" "$(cat "$EF")"
unset GA_AGENTMEMORY_HOME

# ---------- opencode MCP merge ----------
OC="$HOME/.config/opencode/opencode.json"
assert_eq "opencode dry-run message" "DRY-RUN: merge agentmemory MCP into $OC" "$(GA_GLOBAL_DRY_RUN=1 ga_opencode_merge_agentmemory_mcp)"
assert_file_absent "dry-run does not create config" "$OC"
ga_opencode_merge_agentmemory_mcp
assert_eq "new config has MCP" "@agentmemory/mcp" "$(jq -r '.mcp.agentmemory.args[1]' "$OC")"
printf '{"theme":"dark","mcp":{"other":{"type":"stdio"}}}' >"$OC"
ga_opencode_merge_agentmemory_mcp
assert_eq "merge keeps other keys" "dark" "$(jq -r .theme "$OC")"
assert_eq "merge keeps other MCP" "stdio" "$(jq -r .mcp.other.type "$OC")"
assert_eq "merge adds agentmemory" "npx" "$(jq -r .mcp.agentmemory.command "$OC")"
printf '{"theme":"dark"}' >"$OC"
no_t "merge without jq fails" env PATH="$PB" bash -c 'source "$1"; ga_opencode_merge_agentmemory_mcp' _ "$LIBF"
assert_eq "config untouched when jq missing" '{"theme":"dark"}' "$(cat "$OC")"
printf "not json" >"$OC"
no_t "merge with invalid existing json fails" ga_opencode_merge_agentmemory_mcp 2>/dev/null
assert_eq "invalid config left untouched" "not json" "$(cat "$OC")"
rm -f "$OC"

# ---------- launchd plists ----------
stub_log launchctl; stub_log node; stub_log agentmemory
LA="$HOME/Library/LaunchAgents"
reset_calls
assert_eq "server plist dry-run" "DRY-RUN: write $LA/com.agentmemory.server.plist" "$(GA_GLOBAL_DRY_RUN=1 ga_launchd_server_plist /exp)"
assert_file_absent "dry-run writes no plist" "$LA/com.agentmemory.server.plist"
ga_launchd_server_plist /exp/root
P="$LA/com.agentmemory.server.plist"
assert_file_exists "server plist written" "$P"
assert_contains "plist export root" "$(cat "$P")" "<string>/exp/root</string>"
assert_contains "plist node path" "$(cat "$P")" "<string>$TL_BIN/node</string>"
assert_contains "plist agentmemory path" "$(cat "$P")" "<string>$TL_BIN/agentmemory</string>"
assert_contains "plist log path" "$(cat "$P")" "<string>$HOME/.agentmemory/server.log</string>"
assert_contains "launchctl bootout then bootstrap" "$(calls)" "launchctl bootout gui/$(id -u)/com.agentmemory.server"
assert_contains "launchctl bootstrap" "$(calls)" "launchctl bootstrap gui/$(id -u) $P"
assert_not_contains "no load fallback when bootstrap ok" "$(calls)" "launchctl load"
reset_calls
stub_log launchctl 'case "$1" in bootstrap) exit 1;; esac; exit 0'
ga_launchd_server_plist /exp/root
assert_contains "falls back to launchctl load" "$(calls)" "launchctl load $P"
stub_log launchctl 'exit 1'
reset_calls
rm -f "$P"
ga_launchd_server_plist
assert_file_exists "server plist still written when launchctl fails" "$P"
assert_contains "launchctl load was attempted and failure ignored" "$(calls)" "launchctl load $P"
assert_contains "default export root used" "$(cat "$P")" "<string>$HOME/.agentmemory/default-export</string>"
rm -f "$TL_BIN/node" "$TL_BIN/agentmemory"; hash -r
PATH="$PB" ga_launchd_server_plist /exp/root
assert_contains "node fallback path" "$(cat "$P")" "<string>/usr/local/bin/node</string>"
assert_contains "agentmemory fallback path" "$(cat "$P")" "<string>$HOME/.npm-global/bin/agentmemory</string>"

BP="$LA/com.agentmemory.bridge.plist"
RP="$TL_TMP/repo"; mkdir -p "$RP"
reset_calls
stub_log launchctl
ga_launchd_bridge_plist ""
assert_file_absent "bridge plist skipped without repo" "$BP"
ga_launchd_bridge_plist "$RP"
assert_file_absent "bridge plist skipped without bridge script" "$BP"
mkdir -p "$HOME/.agentmemory"; : >"$HOME/.agentmemory/bridge.py"
assert_eq "bridge dry-run" "DRY-RUN: write $BP" "$(GA_GLOBAL_DRY_RUN=1 ga_launchd_bridge_plist "$RP")"
assert_file_absent "bridge dry-run writes nothing" "$BP"
tl_stub gitleaks 'exit 0'; stub_log launchctl
ga_launchd_bridge_plist "$RP"
assert_file_exists "bridge plist written" "$BP"
assert_contains "bridge repo root" "$(cat "$BP")" "<string>$RP</string>"
assert_contains "bridge gitleaks path" "$(cat "$BP")" "<string>$TL_BIN/gitleaks</string>"
assert_contains "bridge PATH includes gitleaks dir" "$(cat "$BP")" "<string>$TL_BIN:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>"
assert_contains "bridge log" "$(cat "$BP")" "<string>$RP/.agentmemory/bridge.log</string>"
assert_contains "bridge launchctl bootstrap" "$(calls)" "launchctl bootstrap gui/$(id -u) $BP"
rm -f "$TL_BIN/gitleaks"; hash -r
PATH="$PB" ga_launchd_bridge_plist "$RP"
assert_contains "bridge falls back to bare gitleaks" "$(cat "$BP")" "<string>gitleaks</string>"
assert_contains "bridge python fallback" "$(cat "$BP")" "<string>/usr/bin/python3</string>"
stub_log launchctl 'case "$1" in bootstrap) exit 1;; esac; exit 0'
reset_calls
ga_launchd_bridge_plist "$RP"
assert_contains "bridge falls back to launchctl load" "$(calls)" "launchctl load $BP"
stub_log launchctl 'exit 1'
reset_calls
rm -f "$BP"
ga_launchd_bridge_plist "$RP"
assert_file_exists "bridge plist still written when launchctl fails" "$BP"
assert_contains "bridge launchctl load attempted and failure ignored" "$(calls)" "launchctl load $BP"
rm -rf "$LA" "$HOME/.agentmemory"

# ---------- cli / server / gitleaks ----------
no_t "graphify cli missing" env PATH="$PB" bash -c 'source "$1"; ga_graphify_cli_available' _ "$LIBF"
no_t "agentmemory cli missing" env PATH="$PB" bash -c 'source "$1"; ga_agentmemory_cli_available' _ "$LIBF"
no_t "server unhealthy without curl" env PATH="$PB" bash -c 'source "$1"; ga_agentmemory_server_healthy' _ "$LIBF"
stub_log graphify; stub_log agentmemory
yes_t "graphify cli present" ga_graphify_cli_available
yes_t "agentmemory cli present" ga_agentmemory_cli_available
stub_log curl 'exit 0'; yes_t "server healthy" ga_agentmemory_server_healthy
stub_log curl 'exit 22'; no_t "server unhealthy when curl fails" ga_agentmemory_server_healthy
assert_eq "gitleaks path empty when missing" "" "$(PATH="$PB" ga_gitleaks_path)"
tl_stub gitleaks 'exit 0'; hash -r
assert_eq "gitleaks path" "$TL_BIN/gitleaks" "$(ga_gitleaks_path)"
assert_eq "bridge path env with gitleaks outside prefix" "$TL_BIN:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin" "$(ga_bridge_path_env)"
(
  ga_gitleaks_path() { printf '/usr/bin/gitleaks'; }
  [[ "$(ga_bridge_path_env)" == "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin" ]]
) && tl_pass "bridge path env does not duplicate prefix dirs" || tl_fail "bridge path env does not duplicate prefix dirs"
assert_eq "bridge path env without gitleaks" "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin" "$(PATH="$PB" ga_bridge_path_env)"
yes_t "ensure_gitleaks already installed" ga_ensure_gitleaks
rm -f "$TL_BIN/gitleaks"; hash -r
NOG="$PB"
assert_eq "ensure dry-run no brew" "DRY-RUN: install gitleaks — brew install gitleaks (macOS) or apt install gitleaks (Linux)" "$(PATH="$NOG" GA_GLOBAL_DRY_RUN=1 ga_ensure_gitleaks)"
stub_log brew; hash -r
assert_eq "ensure dry-run with brew" "DRY-RUN: brew install gitleaks" "$(GA_GLOBAL_DRY_RUN=1 ga_ensure_gitleaks)"
reset_calls
stub_log brew 'printf "#!/bin/sh\nexit 0\n" >"'"$TL_BIN"'/gitleaks"; chmod +x "'"$TL_BIN"'/gitleaks"; exit 0'
yes_t "ensure via brew succeeds" ga_ensure_gitleaks
assert_contains "brew install called" "$(calls)" "brew install gitleaks"
rm -f "$TL_BIN/gitleaks"; hash -r
stub_log brew 'exit 1'
out="$(ga_ensure_gitleaks)" && tl_fail "ensure brew failure returns non-zero" || tl_pass "ensure brew failure returns non-zero"
assert_contains "brew failure warning" "$out" "WARN: gitleaks brew install failed"
rm -f "$TL_BIN/brew"; hash -r
tl_stub apt-get 'exit 0'; hash -r
out="$(PATH="$PB:$TL_BIN" ga_ensure_gitleaks)" && tl_fail "ensure apt branch returns non-zero" || tl_pass "ensure apt branch returns non-zero"
assert_contains "apt warning" "$out" "sudo apt-get install gitleaks"
rm -f "$TL_BIN/apt-get"; hash -r
out="$(PATH="$NOG" ga_ensure_gitleaks)" && tl_fail "ensure no package manager returns non-zero" || tl_pass "ensure no package manager returns non-zero"
assert_contains "no package manager warning" "$out" "WARN: gitleaks not installed"

# ---------- hooks installed / run_cmd ----------
no_t "hooks installed: no graphify" env PATH="$PB" bash -c 'source "$1"; ga_graphify_hooks_installed' _ "$LIBF"
stub_log graphify 'echo "hooks: Installed"'
yes_t "hooks installed" ga_graphify_hooks_installed
stub_log graphify 'echo "hooks: none"'
no_t "hooks not installed" ga_graphify_hooks_installed
reset_calls; stub_log graphify
ga_run_cmd 'graphify hook install'
assert_eq "run_cmd executes" "graphify hook install" "$(calls)"
reset_calls
assert_eq "run_cmd dry-run" "DRY-RUN: graphify x" "$(GA_GLOBAL_DRY_RUN=1 ga_run_cmd 'graphify x')"
assert_eq "run_cmd dry-run does not run" "" "$(calls)"
ga_run_cmd 'false'; tl_pass "run_cmd swallows failing command"

# ---------- apply: shared agentmemory ----------
export GA_AGENTMEMORY_HOME="$TL_TMP/amhome2"
AR="$TL_TMP/applyrepo"; mkdir -p "$AR"
reset_calls; stub_log agentmemory; stub_log launchctl; stub_log brew; tl_stub gitleaks 'exit 0'; hash -r
ga_apply_shared_agentmemory "$AR" >/dev/null
assert_file_exists "export memory dir" "$AR/.agentmemory/memory/."
assert_file_exists "export snapshots dir" "$AR/.agentmemory/snapshots/."
assert_contains "agentmemory init run" "$(calls)" "agentmemory init"
assert_contains "env merged" "$(cat "$GA_AGENTMEMORY_HOME/.env")" "AGENTMEMORY_EXPORT_ROOT=$AR/.agentmemory"
assert_file_exists "server plist written when launchctl available" "$HOME/Library/LaunchAgents/com.agentmemory.server.plist"
rm -rf "$HOME/Library" "$GA_AGENTMEMORY_HOME"
reset_calls
CI=true ga_apply_shared_agentmemory "$AR" >/dev/null
assert_file_absent "no plist when host hooks skipped" "$HOME/Library/LaunchAgents/com.agentmemory.server.plist"
rm -rf "$HOME/Library" "$GA_AGENTMEMORY_HOME"
(
  PATH="$PB"
  ga_apply_shared_agentmemory "$AR" >/dev/null
  [[ ! -e "$HOME/Library/LaunchAgents/com.agentmemory.server.plist" ]] || exit 1
  exit 0
) && tl_pass "no plist without launchctl; no init without agentmemory" || tl_fail "no plist without launchctl"
rm -rf "$HOME/Library" "$GA_AGENTMEMORY_HOME"
(
  # empty repo: falls back to the global default export dir
  export HOME_BEFORE="$HOME"
  ga_apply_shared_agentmemory "" >/dev/null
  [[ -d "$HOME/.agentmemory/default-export/memory" ]]
) && tl_pass "shared apply without repo uses default export dir" || tl_fail "shared apply without repo uses default export dir"
rm -rf "$HOME/Library" "$HOME/.agentmemory" "$GA_AGENTMEMORY_HOME"

# a missing gitleaks (no package manager) warns but must not abort apply under set -e
out="$(set -e; PATH="$PB" CI=true ga_apply_shared_agentmemory "$AR" 2>&1; echo "rc=$?")"
assert_contains "apply_shared warns about gitleaks" "$out" "WARN: gitleaks not installed"
assert_contains "apply_shared still completes under set -e" "$out" "rc=0"
rm -rf "$HOME/Library" "$GA_AGENTMEMORY_HOME"

# ---------- apply: graphify host ----------
reset_calls
PATH="$PB" ga_apply_graphify_host claude
assert_eq "graphify host apply skipped without cli" "" "$(calls)"
stub_log graphify
ga_apply_graphify_host codex
assert_eq "graphify host apply order" "graphify install --platform codex
graphify codex install
graphify hook install" "$(calls)"
reset_calls
CI=1 ga_apply_graphify_host goose
assert_eq "graphify host apply skips hook install in CI" "graphify install --platform pi
graphify pi install" "$(calls)"
reset_calls
ga_apply_graphify_host bogus
assert_eq "unknown host only installs hooks" "graphify hook install" "$(calls)"

# blank lines from the command tables are skipped
reset_calls
(
  ga_graphify_pre_commands() { printf '\n'; }
  ga_graphify_post_commands() { printf '\ngraphify custom-post\n'; }
  CI=1 ga_apply_graphify_host claude
)
assert_eq "blank command lines skipped" "graphify custom-post" "$(calls)"
reset_calls
(
  ga_agentmemory_commands() { printf '\nagentmemory custom\n'; }
  ga_apply_agentmemory_host claude
)
assert_eq "blank agentmemory command lines skipped" "agentmemory custom" "$(calls)"

# ---------- apply: agentmemory host ----------
reset_calls
PATH="$PB" ga_apply_agentmemory_host codex
assert_eq "agentmemory host apply skipped without cli" "" "$(calls)"
stub_log agentmemory; stub_log codex
ga_apply_agentmemory_host codex
assert_contains "codex plugin marketplace add" "$(calls)" "codex plugin marketplace add rohitg00/agentmemory"
assert_contains "agentmemory connect codex" "$(calls)" "agentmemory connect codex --with-hooks"
ga_apply_agentmemory_host opencode
assert_file_exists "opencode host merges MCP config" "$HOME/.config/opencode/opencode.json"
assert_eq "opencode MCP merged" "npx" "$(jq -r .mcp.agentmemory.command "$HOME/.config/opencode/opencode.json")"
rm -rf "$HOME/.config"

# ---------- apply host (full) ----------
reset_calls
stub_log graphify; stub_log agentmemory; stub_log launchctl
out="$(CI=true ga_apply_host claude "$AR")"
assert_contains "apply banner" "$out" "== graphify-am global apply (host=claude, profile=synergy_max) =="
assert_contains "apply runs graphify install" "$(calls)" "graphify install"
assert_contains "apply runs agentmemory connect" "$(calls)" "agentmemory connect claude-code"
assert_contains "apply updates graph index in repo" "$(calls)" "graphify update . --no-cluster"
rm -rf "$HOME/Library"
out="$(GA_GLOBAL_DRY_RUN=1 CI=true ga_apply_host claude "$AR")"
assert_contains "apply dry-run reports graphify update" "$out" "DRY-RUN: graphify update $AR --no-cluster"
reset_calls
out="$(CI=true ga_apply_host claude "")"
assert_not_contains "apply without repo skips graph update" "$(calls)" "update . --no-cluster"
reset_calls
out="$(PATH="$PB" CI=true ga_apply_host claude "$AR")"
assert_not_contains "apply without graphify cli skips graph update" "$out" "graphify update"
# graph update failure inside the repo is tolerated
reset_calls
stub_log graphify 'case "$1" in update) exit 1;; esac; exit 0'
out="$(CI=true ga_apply_host claude "$AR")" && tl_pass "apply tolerates failing graph update" || tl_fail "apply tolerates failing graph update"
stub_log graphify
unset GA_AGENTMEMORY_HOME
rm -rf "$HOME/Library" "$HOME/.agentmemory"

# ---------- verify ----------
rm -rf "$HOME/.claude" "$HOME/.claude.json" "$HOME/.config" "$HOME/.local"
export GA_AGENTMEMORY_HOME="$TL_TMP/amhome3"
VR="$TL_TMP/vrepo"; mkdir -p "$VR"
out="$(PATH="$PB" ga_verify_host claude "$VR")" && rc=0 || rc=$?
assert_eq "verify fails when CLIs missing" "1" "$rc"
assert_contains "verify reports graphify cli failure" "$out" "[ ] graphify-cli: not on PATH"
assert_contains "verify reports agentmemory cli failure" "$out" "[ ] agentmemory-cli: not on PATH"
assert_contains "verify reports server failure" "$out" "[ ] agentmemory-server: not healthy"
assert_contains "verify warns env" "$out" "[!] agentmemory-env: missing synergy_max block"
assert_contains "verify warns graphify platform" "$out" "[!] graphify-platform: missing $HOME/.claude/skills/graphify/SKILL.md"
assert_contains "verify warns agentmemory platform" "$out" "[!] agentmemory-platform: missing $HOME/.claude.json"
assert_contains "verify warns hooks" "$out" "[!] graphify-hooks"
assert_contains "verify warns gitleaks" "$out" "[!] gitleaks"
assert_contains "verify warns index" "$out" "[!] graphify-index: no index"
assert_contains "verify summary" "$out" "Summary: 0 passed, 3 failed, 6 warnings"
assert_eq "verify exports fail count" "3" "$(PATH="$PB" bash -c 'source "$1"; ga_verify_host claude "$2" >/dev/null; printf %s "$GA_VERIFY_FAILS"' _ "$LIBF" "$VR")"
# fully wired host
mkdir -p "$GA_AGENTMEMORY_HOME"; printf 'AGENTMEMORY_INJECT_CONTEXT=true\n' >"$GA_AGENTMEMORY_HOME/.env"
mkdir -p "$HOME/.claude/skills/graphify"; printf 'graphify' >"$HOME/.claude/skills/graphify/SKILL.md"
printf 'agentmemory' >"$HOME/.claude.json"
mkdir -p "$VR/graphify-out"; : >"$VR/graphify-out/graph.json"
stub_log graphify 'echo "git hooks: installed"'; stub_log agentmemory; stub_log curl 'exit 0'; tl_stub gitleaks 'exit 0'; hash -r
out="$(ga_verify_host claude "$VR")" && rc=0 || rc=$?
assert_eq "verify passes when everything is wired" "0" "$rc"
assert_contains "verify summary all pass" "$out" "Summary: 9 passed, 0 failed, 0 warnings"
assert_contains "verify env pass" "$out" "[x] agentmemory-env: synergy_max flags"
assert_contains "verify index pass" "$out" "[x] graphify-index: index at $VR/graphify-out/graph.json"
out="$(ga_verify_host claude "")" && rc=0 || rc=$?
assert_contains "verify without repo omits index check" "$(printf '%s' "$out" | grep -c graphify-index || true)" "0"
# opencode branches
mkdir -p "$HOME/.config/opencode"; printf '{"mcp":{"agentmemory":{}}}' >"$HOME/.config/opencode/opencode.json"
out="$(ga_verify_host opencode "$VR")" && rc=0 || rc=$?
assert_contains "verify opencode MCP pass" "$out" "[x] agentmemory-platform: opencode MCP in opencode.json"
printf '{}' >"$HOME/.config/opencode/opencode.json"
out="$(ga_verify_host opencode "$VR")" && rc=0 || rc=$?
assert_contains "verify opencode MCP warn" "$out" "[!] agentmemory-platform: merge agentmemory MCP"
out="$(ga_verify_host bogus "$VR")" && rc=0 || rc=$?
assert_contains "verify unknown host falls back in messages" "$out" "[!] graphify-platform: missing artifact"
assert_contains "verify unknown host agentmemory fallback" "$out" "[!] agentmemory-platform: missing config"
unset GA_AGENTMEMORY_HOME

tl_results
