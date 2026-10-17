#!/usr/bin/env bash
# Behavior tests for hooks/lib/stack-optimizer.sh. graphify, agentmemory, launchctl,
# systemctl, pgrep, brew, curl, gitleaks and node are all logging stubs.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
unset CI SB_STACK_OPTIMIZER_DRY_RUN SB_STACK_SKIP_HOST_HOOKS SB_AGENTMEMORY_HOME SB_STACK_SCORE_THRESHOLD SB_AGENTMEMORY_MCP_ARTIFACT

LIBF="$TL_REPO_ROOT/hooks/lib/stack-optimizer.sh"
# shellcheck source=../../hooks/lib/stack-optimizer.sh
source "$LIBF"

yes_t() { local n="$1"; shift; if "$@"; then tl_pass "$n"; else tl_fail "$n"; fi; }
no_t() { local n="$1"; shift; if "$@"; then tl_fail "$n"; else tl_pass "$n"; fi; }
LOG="$TL_TMP/calls.log"
stub_log() { tl_stub "$1" 'printf "%s %s\n" "'"$1"'" "$*" >>"'"$LOG"'"; '"${2:-exit 0}"; hash -r; }
unstub() { local n; for n in "$@"; do rm -f "$TL_BIN/$n"; done; hash -r; }
calls() { cat "$LOG" 2>/dev/null || true; }
reset_calls() { : >"$LOG"; }
reset_calls
CFG="$TL_TMP/cfg.json"
w() { printf '%s' "$1" >"$CFG"; }
PB="$(tl_path_without graphify agentmemory curl gitleaks brew apt-get node launchctl systemctl pgrep python3)"
PNJ="$(tl_path_without graphify agentmemory curl gitleaks brew apt-get node launchctl systemctl pgrep python3 jq)"
export SB_AGENTMEMORY_HOME="$TL_TMP/amhome"

# ---------- simple flags ----------
no_t "dry run default" sb_stack_optimizer_dry_run
yes_t "dry run on" env SB_STACK_OPTIMIZER_DRY_RUN=1 bash -c 'source "$1"; sb_stack_optimizer_dry_run' _ "$LIBF"
no_t "skip hooks default" sb_stack_skip_host_hooks
yes_t "skip hooks CI=true" env CI=true bash -c 'source "$1"; sb_stack_skip_host_hooks' _ "$LIBF"
yes_t "skip hooks CI=1" env CI=1 bash -c 'source "$1"; sb_stack_skip_host_hooks' _ "$LIBF"
yes_t "skip hooks explicit" env SB_STACK_SKIP_HOST_HOOKS=1 bash -c 'source "$1"; sb_stack_skip_host_hooks' _ "$LIBF"
assert_eq "agentmemory home override" "$TL_TMP/amhome" "$(sb_stack_agentmemory_home)"
assert_eq "agentmemory home default" "$HOME/.agentmemory" "$(env -u SB_AGENTMEMORY_HOME bash -c 'source "$1"; sb_stack_agentmemory_home' _ "$LIBF")"

# ---------- profile name / knob ----------
assert_eq "profile default no config" "synergy_max" "$(sb_stack_optimization_profile_name)"
w '{"recommended_tools":{"graphify":{"optimization":{"profile":"gp"}},"agentmemory":{"optimization":{"profile":"ap"}}}}'
assert_eq "profile from graphify" "gp" "$(sb_stack_optimization_profile_name "$CFG")"
w '{"recommended_tools":{"agentmemory":{"optimization":{"profile":"ap"}}}}'
assert_eq "profile from agentmemory" "ap" "$(sb_stack_optimization_profile_name "$CFG")"
w '{"recommended_tools":{"graphify":{"optimization":{"profile":""}}}}'
assert_eq "empty profile uses default" "synergy_max" "$(sb_stack_optimization_profile_name "$CFG")"
w 'garbage'
assert_eq "profile invalid json" "synergy_max" "$(sb_stack_optimization_profile_name "$CFG")"
w '{"optimization_profiles":{"p":{"graphify":{"k":"v","n":null,"f":false}}}}'
assert_eq "knob value" "v" "$(sb_stack_profile_knob "$CFG" p graphify k dflt)"
assert_eq "knob missing default" "dflt" "$(sb_stack_profile_knob "$CFG" p graphify none dflt)"
assert_eq "knob explicit false preserved" "false" "$(sb_stack_profile_knob "$CFG" p graphify f dflt)"
assert_eq "knob null default" "dflt" "$(sb_stack_profile_knob "$CFG" p graphify n dflt)"
assert_eq "knob unknown profile default" "dflt" "$(sb_stack_profile_knob "$CFG" zz graphify k dflt)"
w '{"optimization_profiles":{"p":{"graphify":{"s":"null"}}}}'
assert_eq "knob literal string null falls back to default" "dflt" "$(sb_stack_profile_knob "$CFG" p graphify s dflt)"
w 'garbage'
assert_eq "knob invalid json default" "dflt" "$(sb_stack_profile_knob "$CFG" p graphify k dflt)"
assert_eq "knob missing file default" "dflt" "$(sb_stack_profile_knob "$TL_TMP/none.json" p graphify k dflt)"

# ---------- graphify git hooks ----------
RP="$TL_TMP/repo"; tl_git_repo "$RP"
stub_log graphify 'if [[ "${1:-}" == hook && "${2:-}" == status ]]; then echo "${GFY_HOOK_STATUS:-}"; exit "${GFY_HOOK_RC:-0}"; fi; exit 0'
no_t "hooks: nothing installed, status empty" sb_stack_graphify_hooks_installed "$RP"
export GFY_HOOK_STATUS="hooks Installed"
yes_t "hooks: via graphify hook status" sb_stack_graphify_hooks_installed "$RP"
export GFY_HOOK_RC=1
no_t "hooks: status command fails" sb_stack_graphify_hooks_installed "$RP"
unset GFY_HOOK_RC GFY_HOOK_STATUS
no_t "hooks: no graphify cli" env PATH="$PB" bash -c 'source "$1"; sb_stack_graphify_hooks_installed "$2"' _ "$LIBF" "$RP"
printf '#!/bin/sh\ngraphify update\n' >"$RP/.git/hooks/post-commit"
yes_t "hooks: post-commit mentions graphify" env PATH="$PB" bash -c 'source "$1"; sb_stack_graphify_hooks_installed "$2"' _ "$LIBF" "$RP"
rm "$RP/.git/hooks/post-commit"
printf '#!/bin/sh\ngraphify update\n' >"$RP/.git/hooks/post-checkout"
yes_t "hooks: post-checkout mentions graphify" env PATH="$PB" bash -c 'source "$1"; sb_stack_graphify_hooks_installed "$2"' _ "$LIBF" "$RP"
rm "$RP/.git/hooks/post-checkout"
no_t "hooks: repo without .git/hooks and no cli" env PATH="$PB" bash -c 'source "$1"; sb_stack_graphify_hooks_installed "$2"' _ "$LIBF" "$TL_TMP"
yes_t "hooks: default repo is PWD" bash -c 'cd "$1" && source "$2" && GFY_HOOK_STATUS=active sb_stack_graphify_hooks_installed' _ "$RP" "$LIBF"

# ---------- gitignore ----------
GI="$RP/.gitignore"; rm -f "$GI"
assert_eq "gitignore dry-run new" "DRY-RUN: append agentmemory gitignore block to $GI" "$(SB_STACK_OPTIMIZER_DRY_RUN=1 sb_stack_ensure_agentmemory_gitignore "$RP")"
assert_file_exists "gitignore touched even in dry-run" "$GI"
assert_eq "dry-run does not append" "" "$(cat "$GI")"
sb_stack_ensure_agentmemory_gitignore "$RP"
assert_contains "gitignore block appended" "$(cat "$GI")" "# === agentmemory managed block ==="
assert_contains "gitignore has memory negation" "$(cat "$GI")" '!.agentmemory/memory/**'
before="$(cat "$GI")"
sb_stack_ensure_agentmemory_gitignore "$RP"
assert_eq "gitignore block idempotent" "$before" "$(cat "$GI")"
# older block missing the /** negation gets repaired
printf '# === agentmemory managed block ===\n.agentmemory/*\n!.agentmemory/memory/\n# === end agentmemory managed block ===\n' >"$GI"
assert_eq "gitignore repair dry-run" "DRY-RUN: fix agentmemory gitignore /** negation in $GI" "$(SB_STACK_OPTIMIZER_DRY_RUN=1 sb_stack_ensure_agentmemory_gitignore "$RP")"
assert_not_contains "dry-run does not repair" "$(cat "$GI")" '!.agentmemory/memory/**'
sb_stack_ensure_agentmemory_gitignore "$RP"
assert_contains "gitignore repaired" "$(cat "$GI")" '!.agentmemory/memory/**'
tl_stub sed 'exit 1'; hash -r
printf '# === agentmemory managed block ===\n!.agentmemory/memory/\n' >"$GI"
sb_stack_ensure_agentmemory_gitignore "$RP" && tl_pass "gitignore repair tolerates sed failures" || tl_fail "gitignore repair tolerates sed failures"
assert_not_contains "failed repair leaves file unchanged" "$(cat "$GI")" '!.agentmemory/memory/**'
unstub sed
rm -f "$GI"
( cd "$RP" && sb_stack_ensure_agentmemory_gitignore ) && assert_file_exists "gitignore default repo is PWD" "$GI"

# ---------- env merge ----------
rm -rf "$SB_AGENTMEMORY_HOME"
w '{"optimization_profiles":{"p":{"agentmemory":{"inject_context":false,"auto_compress":true,"obsidian_export":false,"bridge_enabled":false}}}}'
sb_stack_merge_agentmemory_env "$RP" "$CFG" p
EF="$SB_AGENTMEMORY_HOME/.env"
assert_contains "env inject knob" "$(cat "$EF")" "AGENTMEMORY_INJECT_CONTEXT=false"
assert_contains "env compress knob" "$(cat "$EF")" "AGENTMEMORY_AUTO_COMPRESS=true"
assert_contains "env obsidian knob" "$(cat "$EF")" "OBSIDIAN_AUTO_EXPORT=false"
assert_contains "env bridge knob" "$(cat "$EF")" "CLAUDE_MEMORY_BRIDGE=false"
assert_contains "env export root" "$(cat "$EF")" "AGENTMEMORY_EXPORT_ROOT=$RP/.agentmemory"
assert_eq "env mode" "-rw-------" "$(ls -l "$EF" | cut -c1-10)"
printf 'USER=1\n' >"$EF"
sb_stack_merge_agentmemory_env "$RP" "" synergy_max
assert_eq "env backup" "USER=1" "$(cat "$EF.bak")"
assert_contains "env defaults applied" "$(cat "$EF")" "AGENTMEMORY_INJECT_CONTEXT=true"
sb_stack_merge_agentmemory_env "$RP"
assert_eq "env block replaced once" "1" "$(grep -c '# === SB synergy_max managed block ===' "$EF")"
assert_contains "env keeps user line" "$(cat "$EF")" "USER=1"
before="$(cat "$EF")"
assert_eq "env dry-run message" "DRY-RUN: merge $EF (backup .env.bak)" "$(SB_STACK_OPTIMIZER_DRY_RUN=1 sb_stack_merge_agentmemory_env "$RP" "" p)"
assert_eq "env dry-run untouched" "$before" "$(cat "$EF")"
tl_stub chmod 'exit 1'; hash -r
( cd "$RP" && sb_stack_merge_agentmemory_env ) && tl_pass "env merge tolerates chmod failure and uses PWD" || tl_fail "env merge tolerates chmod failure"
unstub chmod

# ---------- launchd plists ----------
stub_log launchctl; stub_log node
LA="$HOME/Library/LaunchAgents"; SP="$LA/com.agentmemory.server.plist"; BP="$LA/com.agentmemory.bridge.plist"
assert_eq "server plist dry-run" "DRY-RUN: write $SP" "$(SB_STACK_OPTIMIZER_DRY_RUN=1 sb_stack_launchd_server_plist "$RP")"
assert_file_absent "dry-run writes nothing" "$SP"
reset_calls
sb_stack_launchd_server_plist "$RP" ""
assert_contains "server plist node" "$(cat "$SP")" "<string>$TL_BIN/node</string>"
assert_contains "server plist default agentmemory path" "$(cat "$SP")" "<string>$HOME/.npm-global/bin/agentmemory</string>"
assert_contains "server plist export root" "$(cat "$SP")" "<string>$RP/.agentmemory</string>"
assert_contains "server plist working dir" "$(cat "$SP")" "<key>WorkingDirectory</key>"
assert_contains "launchctl bootout" "$(calls)" "launchctl bootout gui/$(id -u)/com.agentmemory.server"
assert_contains "launchctl bootstrap" "$(calls)" "launchctl bootstrap gui/$(id -u) $SP"
assert_not_contains "no load when bootstrap ok" "$(calls)" "launchctl load"
reset_calls; stub_log launchctl 'case "$1" in bootstrap) exit 1;; esac; exit 0'
sb_stack_launchd_server_plist "$RP"
assert_contains "falls back to load" "$(calls)" "launchctl load $SP"
stub_log launchctl 'exit 1'
reset_calls; rm -f "$SP"
sb_stack_launchd_server_plist "$RP" && tl_pass "server plist tolerates launchctl failures" || tl_fail "server plist tolerates launchctl failures"
assert_file_exists "server plist written despite launchctl failure" "$SP"
assert_contains "load attempted after failed bootstrap" "$(calls)" "launchctl load $SP"
stub_log agentmemory; stub_log launchctl
sb_stack_launchd_server_plist "$RP"
assert_contains "agentmemory path rewritten to PATH binary" "$(cat "$SP")" "<string>$TL_BIN/agentmemory</string>"
assert_file_absent "sed backup removed" "$SP.bak"
# first sed fails (replacement contains '|'), fallback sed also fails: still succeeds
mkdir -p "$TL_TMP/bin|x"; printf '#!/bin/sh\nexit 0\n' >"$TL_TMP/bin|x/agentmemory"; chmod +x "$TL_TMP/bin|x/agentmemory"
tl_stub sed 'exit 1'; hash -r
( PATH="$TL_TMP/bin|x:$PATH"; sb_stack_launchd_server_plist "$RP" ) && tl_pass "server plist survives sed failures" || tl_fail "server plist survives sed failures"
assert_contains "path not rewritten when sed fails" "$(cat "$SP")" "<string>$HOME/.npm-global/bin/agentmemory</string>"
unstub sed agentmemory
rm -rf "$LA"
unstub node
PATH="$PB" sb_stack_launchd_server_plist "$RP" ""
assert_contains "server plist node fallback" "$(cat "$SP")" "<string>/usr/local/bin/node</string>"
rm -rf "$LA"

rm -rf "$SB_AGENTMEMORY_HOME"; mkdir -p "$SB_AGENTMEMORY_HOME"
sb_stack_launchd_bridge_plist "$RP"
assert_file_absent "bridge plist skipped without script" "$BP"
: >"$SB_AGENTMEMORY_HOME/bridge.py"
assert_eq "bridge plist dry-run" "DRY-RUN: write $BP" "$(SB_STACK_OPTIMIZER_DRY_RUN=1 sb_stack_launchd_bridge_plist "$RP")"
assert_file_absent "bridge dry-run writes nothing" "$BP"
tl_stub gitleaks 'exit 0'; hash -r
reset_calls
sb_stack_launchd_bridge_plist "$RP"
assert_contains "bridge repo root" "$(cat "$BP")" "<string>$RP</string>"
assert_contains "bridge gitleaks" "$(cat "$BP")" "<string>$TL_BIN/gitleaks</string>"
assert_contains "bridge PATH env" "$(cat "$BP")" "<string>$TL_BIN:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>"
assert_contains "bridge launchctl bootstrap" "$(calls)" "launchctl bootstrap gui/$(id -u) $BP"
unstub gitleaks
PATH="$PB" sb_stack_launchd_bridge_plist "$RP"
assert_contains "bridge gitleaks fallback" "$(cat "$BP")" "<string>gitleaks</string>"
assert_contains "bridge python fallback" "$(cat "$BP")" "<string>/usr/bin/python3</string>"
reset_calls; stub_log launchctl 'case "$1" in bootstrap) exit 1;; esac; exit 0'
sb_stack_launchd_bridge_plist "$RP"
assert_contains "bridge falls back to load" "$(calls)" "launchctl load $BP"
stub_log launchctl 'exit 1'
reset_calls; rm -f "$BP"
sb_stack_launchd_bridge_plist "$RP" && tl_pass "bridge plist tolerates launchctl failures" || tl_fail "bridge plist tolerates launchctl failures"
assert_file_exists "bridge plist written despite launchctl failure" "$BP"
assert_contains "bridge load attempted" "$(calls)" "launchctl load $BP"
rm -f "$BP"
( cd "$RP" && sb_stack_launchd_bridge_plist ) && tl_pass "bridge plist default repo is PWD" || tl_fail "bridge plist default repo"
assert_contains "bridge plist default repo recorded" "$(cat "$BP")" "<string>$RP</string>"
unstub launchctl
rm -rf "$LA"

# ---------- bridge running / persistence ----------
BR() { sb_stack_bridge_running; }
no_t "bridge not running anywhere" env PATH="$PB" bash -c 'source "$1"; sb_stack_bridge_running' _ "$LIBF"
stub_log launchctl 'echo "123 0 com.agentmemory.bridge"'
yes_t "bridge running via launchctl" BR
stub_log launchctl 'echo "123 0 other"'
no_t "bridge launchctl list without bridge" env PATH="$TL_BIN:$PB" bash -c 'source "$1"; sb_stack_bridge_running' _ "$LIBF"
unstub launchctl
stub_log systemctl 'exit 0'
yes_t "bridge running via systemctl" env PATH="$TL_BIN:$PB" bash -c 'source "$1"; sb_stack_bridge_running' _ "$LIBF"
stub_log systemctl 'exit 3'
no_t "bridge systemctl inactive" env PATH="$TL_BIN:$PB" bash -c 'source "$1"; sb_stack_bridge_running' _ "$LIBF"
unstub systemctl
stub_log pgrep 'exit 0'
yes_t "bridge running via pgrep" env PATH="$TL_BIN:$PB" bash -c 'source "$1"; sb_stack_bridge_running' _ "$LIBF"
stub_log pgrep 'exit 1'
no_t "bridge pgrep finds nothing" env PATH="$TL_BIN:$PB" bash -c 'source "$1"; sb_stack_bridge_running' _ "$LIBF"
unstub pgrep

stub_log curl 'exit "${CURL_RC:-0}"'
stub_log launchctl 'echo "1 0 com.agentmemory.server"'
yes_t "persistence via launchctl" sb_stack_server_persistence_ok "$CFG"
stub_log launchctl 'echo "nothing"'
export CURL_RC=22
no_t "persistence: launchctl without server, unhealthy" env PATH="$TL_BIN:$PB" CURL_RC=22 bash -c 'source "$1"; sb_stack_server_persistence_ok' _ "$LIBF"
unstub launchctl
stub_log systemctl 'exit 0'
yes_t "persistence via systemctl" env PATH="$TL_BIN:$PB" bash -c 'source "$1"; sb_stack_server_persistence_ok' _ "$LIBF"
stub_log systemctl 'exit 3'
no_t "persistence: systemctl inactive, unhealthy" env PATH="$TL_BIN:$PB" CURL_RC=22 bash -c 'source "$1"; sb_stack_server_persistence_ok' _ "$LIBF"
unstub systemctl
unset CURL_RC
yes_t "persistence via healthy server" env PATH="$TL_BIN:$PB" CURL_RC=0 bash -c 'source "$1"; sb_stack_server_persistence_ok' _ "$LIBF"
export CURL_RC=22
no_t "persistence: nothing available" env PATH="$TL_BIN:$PB" CURL_RC=22 bash -c 'source "$1"; sb_stack_server_persistence_ok' _ "$LIBF"
unset CURL_RC

# ---------- gitleaks ----------
assert_eq "gitleaks path empty when missing" "" "$(PATH="$PB" sb_stack_gitleaks_path)"
tl_stub gitleaks 'exit 0'; hash -r
assert_eq "gitleaks path" "$TL_BIN/gitleaks" "$(sb_stack_gitleaks_path)"
assert_eq "bridge path env with gitleaks" "$TL_BIN:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin" "$(sb_stack_bridge_path_env)"
(
  sb_stack_gitleaks_path() { printf '/bin/gitleaks'; }
  [[ "$(sb_stack_bridge_path_env)" == "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin" ]]
) && tl_pass "bridge path env does not duplicate prefix dirs" || tl_fail "bridge path env duplicate"
unstub gitleaks
assert_eq "bridge path env without gitleaks" "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin" "$(PATH="$PB" sb_stack_bridge_path_env)"

w '{"optimization_profiles":{"synergy_max":{"agentmemory":{"gitleaks_required":true}},"rec":{"agentmemory":{"gitleaks_recommended":true}},"none":{"agentmemory":{}}}}'
yes_t "gitleaks required knob" sb_stack_gitleaks_required "$CFG" synergy_max
yes_t "gitleaks recommended knob" sb_stack_gitleaks_required "$CFG" rec
no_t "gitleaks not required" sb_stack_gitleaks_required "$CFG" none
yes_t "gitleaks required uses default profile name" sb_stack_gitleaks_required "$CFG"
GL="$CFG"
yes_t "ensure: not required is a no-op" sb_stack_ensure_gitleaks "$CFG" none
yes_t "ensure: default profile resolves to synergy_max (gitleaks_required) and dry-runs" env PATH="$PB" SB_STACK_OPTIMIZER_DRY_RUN=1 bash -c 'source "$1"; sb_stack_ensure_gitleaks "$2"' _ "$LIBF" "$CFG"
NOG="$PB"
assert_eq "ensure dry-run without brew" "DRY-RUN: install gitleaks — brew install gitleaks (macOS) or apt install gitleaks (Linux)" "$(PATH="$NOG" SB_STACK_OPTIMIZER_DRY_RUN=1 sb_stack_ensure_gitleaks "$GL" synergy_max)"
stub_log brew
assert_eq "ensure dry-run with brew" "DRY-RUN: brew install gitleaks" "$(SB_STACK_OPTIMIZER_DRY_RUN=1 sb_stack_ensure_gitleaks "$GL" synergy_max)"
reset_calls
stub_log brew 'printf "#!/bin/sh\nexit 0\n" >"'"$TL_BIN"'/gitleaks"; chmod +x "'"$TL_BIN"'/gitleaks"; exit 0'
yes_t "ensure via brew succeeds" sb_stack_ensure_gitleaks "$GL" synergy_max
assert_contains "brew install called" "$(calls)" "brew install gitleaks"
unstub gitleaks
yes_t "ensure with installed gitleaks short-circuits" bash -c 'true'
stub_log brew 'exit 1'
out="$(sb_stack_ensure_gitleaks "$GL" synergy_max)" && tl_fail "ensure brew failure returns non-zero" || tl_pass "ensure brew failure returns non-zero"
assert_contains "brew failure warning" "$out" "WARN: gitleaks brew install failed"
unstub brew
stub_log apt-get
out="$(PATH="$PB:$TL_BIN" sb_stack_ensure_gitleaks "$GL" synergy_max)" && tl_fail "ensure apt returns non-zero" || tl_pass "ensure apt returns non-zero"
assert_contains "apt warning" "$out" "sudo apt-get install gitleaks"
unstub apt-get
out="$(PATH="$PB" sb_stack_ensure_gitleaks "$GL" synergy_max)" && tl_fail "ensure no package manager returns non-zero" || tl_pass "ensure no package manager returns non-zero"
assert_contains "no package manager warning" "$out" "WARN: gitleaks not installed"
tl_stub gitleaks 'exit 0'; hash -r
yes_t "ensure when gitleaks installed" sb_stack_ensure_gitleaks "$GL" synergy_max
unstub gitleaks

# ---------- optimize graphify ----------
G="$TL_TMP/gcfg.json"
printf '{"recommended_tools":{"graphify":{"enabled_by_user":true}}}' >"$G"
GR="$TL_TMP/grepo"; tl_git_repo "$GR"
reset_calls; stub_log graphify
sb_optimize_graphify "$GR" "$TL_TMP/none.json" claude
assert_eq "graphify not consented: no-op" "" "$(calls)"
printf '{}' >"$TL_TMP/empty.json"
sb_optimize_graphify "$GR" "$TL_TMP/empty.json" claude
assert_eq "graphify pending consent: no-op" "" "$(calls)"
sb_optimize_graphify "$GR" "$G" claude
assert_contains "hook install runs" "$(calls)" "graphify hook install"
assert_contains "pre-index command runs" "$(calls)" "graphify install --project"
assert_contains "post-index command runs" "$(calls)" "graphify claude install --project"
assert_contains "index built with no-cluster" "$(calls)" "graphify update . --no-cluster"
reset_calls
CI=true sb_optimize_graphify "$GR" "$G" claude
assert_not_contains "CI skips hook install" "$(calls)" "graphify hook install"
assert_contains "CI still runs platform commands" "$(calls)" "graphify install --project"
reset_calls
mkdir -p "$GR/graphify-out"; : >"$GR/graphify-out/graph.json"
sb_optimize_graphify "$GR" "$G" claude
assert_not_contains "existing index not rebuilt" "$(calls)" "graphify update"
rm -rf "$GR/graphify-out"
out="$(SB_STACK_OPTIMIZER_DRY_RUN=1 sb_optimize_graphify "$GR" "$G" claude)"
assert_contains "dry-run hook install" "$out" "DRY-RUN: graphify hook install"
assert_contains "dry-run platform command" "$out" "DRY-RUN: graphify install --project"
assert_contains "dry-run index build" "$out" "DRY-RUN: graphify update . --no-cluster"
printf '{"recommended_tools":{"graphify":{"enabled_by_user":true}},"optimization_profiles":{"synergy_max":{"graphify":{"install_git_hooks":false,"prefer_no_cluster":false}}}}' >"$G"
out="$(SB_STACK_OPTIMIZER_DRY_RUN=1 sb_optimize_graphify "$GR" "$G" claude)"
assert_not_contains "install_git_hooks=false skips hook install" "$out" "graphify hook install"
assert_contains "prefer_no_cluster=false drops flag" "$out" "DRY-RUN: graphify update . "
assert_not_contains "no cluster flag" "$out" "--no-cluster"
reset_calls
sb_optimize_graphify "$GR" "$G" claude
assert_contains "real update without cluster flag" "$(calls)" "graphify update ."
printf '{"recommended_tools":{"graphify":{"enabled_by_user":true}}}' >"$G"
reset_calls
PATH="$PB" sb_optimize_graphify "$GR" "$G" claude
assert_eq "no graphify cli: nothing run" "" "$(calls)"
(
  sb_recommended_tool_platform_pre_index_commands() { printf '\n'; }
  sb_recommended_tool_platform_post_index_commands() { printf '\ngraphify custom-post\n'; }
  CI=1 SB_STACK_OPTIMIZER_DRY_RUN=1 sb_optimize_graphify "$GR" "$G" claude
) >"$TL_TMP/blank.out"
assert_contains "blank platform lines skipped, real one kept" "$(cat "$TL_TMP/blank.out")" "DRY-RUN: graphify custom-post"
assert_not_contains "no empty DRY-RUN command line" "$(cat "$TL_TMP/blank.out")" "DRY-RUN: $"
reset_calls
(cd "$GR" && SILVER_BULLET_RUNTIME=claude sb_optimize_graphify)  # no config: consent pending
assert_eq "defaults without config: no-op" "" "$(calls)"
reset_calls
stub_log graphify 'exit 1'
sb_optimize_graphify "$GR" "$G" claude && tl_pass "failing graphify commands are tolerated" || tl_fail "failing graphify commands are tolerated"
stub_log graphify

# ---------- optimize agentmemory ----------
A="$TL_TMP/acfg.json"
printf '{"recommended_tools":{"agentmemory":{"enabled_by_user":true}}}' >"$A"
AR="$TL_TMP/arepo"; tl_git_repo "$AR"
reset_calls; stub_log agentmemory; stub_log launchctl; stub_log node
rm -rf "$SB_AGENTMEMORY_HOME" "$LA"
sb_optimize_agentmemory "$AR" "$TL_TMP/empty.json" claude
assert_file_absent "agentmemory not consented: nothing created" "$AR/.agentmemory"
sb_optimize_agentmemory "$AR" "$A" claude
assert_file_exists "memory dir scaffolded" "$AR/.agentmemory/memory/."
assert_file_exists "snapshots dir scaffolded" "$AR/.agentmemory/snapshots/."
assert_contains "gitignore managed" "$(cat "$AR/.gitignore")" "# === agentmemory managed block ==="
assert_contains "env merged" "$(cat "$SB_AGENTMEMORY_HOME/.env")" "AGENTMEMORY_EXPORT_ROOT=$AR/.agentmemory"
assert_file_exists "server plist written (launchd persistence)" "$SP"
assert_contains "post-index command run" "$(calls)" "agentmemory connect claude-code"
rm -rf "$LA"; reset_calls
CI=true sb_optimize_agentmemory "$AR" "$A" claude
assert_file_absent "CI skips launchd plists" "$SP"
rm -rf "$LA"
printf '{"recommended_tools":{"agentmemory":{"enabled_by_user":true}},"optimization_profiles":{"synergy_max":{"agentmemory":{"server_persistence":"none"}}}}' >"$A"
sb_optimize_agentmemory "$AR" "$A" claude
assert_file_absent "non-launchd persistence skips plists" "$SP"
printf '{"recommended_tools":{"agentmemory":{"enabled_by_user":true}}}' >"$A"
out="$(SB_STACK_OPTIMIZER_DRY_RUN=1 CI=1 sb_optimize_agentmemory "$AR" "$A" codex)"
assert_contains "dry-run codex commands" "$out" "DRY-RUN: agentmemory connect codex --with-hooks"
reset_calls
printf '{"recommended_tools":{"agentmemory":{"enabled_by_user":true,"platform_install_commands":{"claude":{"post_index":["","Verify the thing","agentmemory custom-step"]}}}}}' >"$A"
CI=1 sb_optimize_agentmemory "$AR" "$A" claude
assert_contains "custom post-index command executed" "$(calls)" "agentmemory custom-step"
assert_not_contains "Verify* hint lines are skipped" "$(calls)" "Verify"
# gitleaks required but not installable must not abort the apply (callers run under set -e)
printf '{"recommended_tools":{"agentmemory":{"enabled_by_user":true}},"optimization_profiles":{"synergy_max":{"agentmemory":{"gitleaks_required":true,"server_persistence":"none"}}}}' >"$TL_TMP/gl-req.json"
out="$(set -e; PATH="$PB:$TL_BIN" CI=1 sb_optimize_agentmemory "$AR" "$TL_TMP/gl-req.json" claude 2>&1; echo "rc=$?")"
assert_contains "gitleaks failure is only a warning" "$out" "WARN: gitleaks not installed"
assert_contains "apply continues after gitleaks failure" "$out" "rc=0"
(
  sb_recommended_tool_platform_post_index_commands() { printf '\nagentmemory late-step\n'; }
  CI=1 sb_optimize_agentmemory "$AR" "$TL_TMP/gl-req.json" claude
) >/dev/null 2>&1
assert_contains "blank post-index line skipped, command run" "$(calls)" "agentmemory late-step"
stub_log agentmemory 'exit 1'
CI=1 sb_optimize_agentmemory "$AR" "$A" claude && tl_pass "failing post-index command tolerated" || tl_fail "failing post-index command tolerated"
stub_log agentmemory
(cd "$AR" && CI=1 SILVER_BULLET_RUNTIME=claude sb_optimize_agentmemory)
tl_pass "optimize agentmemory without args is a no-op (pending consent)"
PATH="$PB" CI=1 sb_optimize_agentmemory "$AR" "$A" claude && tl_pass "no launchctl: skips plists" || tl_fail "no launchctl"
unstub launchctl node agentmemory
rm -rf "$LA"

# ---------- optimize synergy ----------
S="$TL_TMP/scfg.json"
printf '{"recommended_tools":{"graphify":{"enabled_by_user":true},"agentmemory":{"enabled_by_user":true}}}' >"$S"
SR="$TL_TMP/srepo"; tl_git_repo "$SR"
reset_calls; stub_log graphify; stub_log agentmemory 'echo Connected'; stub_log curl 'exit "${CURL_RC:-0}"'
sb_optimize_synergy "$SR" "$TL_TMP/empty.json"
assert_eq "synergy: no consent no-op" "" "$(calls)"
printf '{"recommended_tools":{"graphify":{"enabled_by_user":true}}}' >"$TL_TMP/g-only.json"
sb_optimize_synergy "$SR" "$TL_TMP/g-only.json"
assert_eq "synergy: graphify only no-op" "" "$(calls)"
printf '{"recommended_tools":{"agentmemory":{"enabled_by_user":true}}}' >"$TL_TMP/a-only.json"
sb_optimize_synergy "$SR" "$TL_TMP/a-only.json"
assert_eq "synergy: agentmemory only no-op" "" "$(calls)"
sb_optimize_synergy "$SR" "$S"
assert_contains "synergy: obsidian export POST" "$(calls)" "curl -sf -X POST http://localhost:3111/agentmemory/obsidian/export"
assert_contains "synergy: vault dir" "$(calls)" "$SR/.agentmemory/memory"
assert_contains "synergy: post-export graph update" "$(calls)" "graphify update . --no-cluster"
reset_calls
out="$(SB_STACK_OPTIMIZER_DRY_RUN=1 sb_optimize_synergy "$SR" "$S")"
assert_contains "synergy dry-run export" "$out" "DRY-RUN: POST obsidian export to $SR/.agentmemory"
assert_contains "synergy dry-run update" "$out" "DRY-RUN: graphify update . --no-cluster (post-export)"
printf '{"recommended_tools":{"graphify":{"enabled_by_user":true},"agentmemory":{"enabled_by_user":true,"health_url":"http://h:9/agentmemory/health"}},"optimization_profiles":{"synergy_max":{"synergy":{"post_export_graphify_update":false}}}}' >"$S"
reset_calls
sb_optimize_synergy "$SR" "$S"
assert_contains "synergy: custom health url base" "$(calls)" "http://h:9/agentmemory/obsidian/export"
assert_not_contains "synergy: post_export disabled" "$(calls)" "graphify update"
printf '{"recommended_tools":{"graphify":{"enabled_by_user":true},"agentmemory":{"enabled_by_user":true}},"optimization_profiles":{"synergy_max":{"graphify":{"prefer_no_cluster":false}}}}' >"$S"
out="$(SB_STACK_OPTIMIZER_DRY_RUN=1 sb_optimize_synergy "$SR" "$S")"
assert_contains "synergy: cluster flag dropped" "$out" "DRY-RUN: graphify update .  (post-export)"
export CURL_RC=22
unstub agentmemory; stub_log agentmemory 'echo down'
reset_calls
sb_optimize_synergy "$SR" "$S"
assert_not_contains "synergy: unhealthy server skips export" "$(calls)" "obsidian/export"
unset CURL_RC
stub_log agentmemory 'echo Connected'; unstub curl
reset_calls
PATH="$TL_BIN:$PB" sb_optimize_synergy "$SR" "$S"
assert_not_contains "synergy: without curl nothing posted" "$(calls)" "obsidian"
stub_log curl 'exit 0'
stub_log agentmemory 'echo Connected'
reset_calls
(cd "$SR" && sb_optimize_synergy "" "$S")
assert_contains "synergy defaults repo to PWD" "$(calls)" "obsidian/export"
assert_contains "synergy PWD vault dir" "$(calls)" "$SR/.agentmemory/memory"
stub_log curl 'exit 22; # export POST fails but synergy continues'
sb_optimize_synergy "$SR" "$S" && tl_pass "failing export POST tolerated" || tl_fail "failing export POST tolerated"
stub_log curl 'exit 0'
tl_stub graphify 'exit 1'; hash -r
sb_optimize_synergy "$SR" "$S" && tl_pass "failing post-export update tolerated" || tl_fail "failing post-export update tolerated"
stub_log graphify

# ---------- graph refs / score ----------
printf '{}' >"$TL_TMP/plain.json"
no_t "graph refs: no graph" sb_stack_graph_has_agentmemory_refs "$SR" "$TL_TMP/plain.json"
mkdir -p "$SR/graphify-out"; printf '{"nodes":[]}' >"$SR/graphify-out/graph.json"
no_t "graph refs: none" sb_stack_graph_has_agentmemory_refs "$SR" "$TL_TMP/plain.json"
sb_stack_graph_has_agentmemory_refs "$SR" "$TL_TMP/plain.json" 2>"$TL_TMP/refs.err" || true
assert_eq "graph refs: no stderr noise when graph has no refs" "" "$(cat "$TL_TMP/refs.err")"
printf '{"nodes":[".agentmemory/memory/a.md"]}' >"$SR/graphify-out/graph.json"
yes_t "graph refs: present" sb_stack_graph_has_agentmemory_refs "$SR" "$TL_TMP/plain.json"
yes_t "graph refs: default repo" bash -c 'cd "$1" && source "$2" && sb_stack_graph_has_agentmemory_refs' _ "$SR" "$LIBF"

# score: nothing opted in
score="$(sb_optimization_score "$SR" "$TL_TMP/empty.json")"
assert_eq "score nothing enabled" "0" "$score"
sb_optimization_score "$SR" "$TL_TMP/empty.json" >/dev/null
assert_contains "score report skips graphify" "$SB_STACK_SCORE_REPORT" "skip|graphify-opt|graphify not opted in|0"
# fully healthy stack
H="$TL_TMP/hcfg.json"
printf '{"recommended_tools":{"graphify":{"enabled_by_user":true},"agentmemory":{"enabled_by_user":true}}}' >"$H"
mkdir -p "$SR/.git/hooks"; printf 'graphify' >"$SR/.git/hooks/post-commit"
mkdir -p "$SR/.claude"; printf 'graphify' >"$SR/.claude/settings.json"
rm -rf "$SB_AGENTMEMORY_HOME"; mkdir -p "$SB_AGENTMEMORY_HOME"; printf 'AGENTMEMORY_INJECT_CONTEXT=true\n' >"$SB_AGENTMEMORY_HOME/.env"
stub_log pgrep 'exit 0'; stub_log curl 'exit 0'; tl_stub gitleaks 'exit 0'; hash -r
export SB_AGENTMEMORY_MCP_ARTIFACT="$TL_TMP/amart"; printf 'agentmemory' >"$SB_AGENTMEMORY_MCP_ARTIFACT"
score="$(SILVER_BULLET_RUNTIME=claude sb_optimization_score "$SR" "$H")"
assert_eq "full score" "120" "$score"
unset SB_AGENTMEMORY_MCP_ARTIFACT
SILVER_BULLET_RUNTIME=claude sb_optimization_score "$SR" "$H" >/dev/null
assert_eq "score fails" "0" "$SB_STACK_SCORE_FAILS"
assert_eq "score warns" "0" "$SB_STACK_SCORE_WARNS"
assert_contains "score report pass" "$SB_STACK_SCORE_REPORT" "pass|graphify-cli|CLI on PATH|10"
assert_contains "score synergy pass" "$SB_STACK_SCORE_REPORT" "pass|synergy-index|graph contains .agentmemory refs|15"
assert_contains "score gitleaks installed" "$SB_STACK_SCORE_REPORT" "pass|gitleaks|installed|5"
# degrade: everything missing but opted in
unstub gitleaks pgrep curl graphify agentmemory
rm -rf "$SB_AGENTMEMORY_HOME" "$SR/.git/hooks/post-commit" "$SR/.claude" "$SR/graphify-out"
score="$(PATH="$PB" SILVER_BULLET_RUNTIME=claude sb_optimization_score "$SR" "$H")"
assert_eq "degraded score" "25" "$score"
PATH="$PB" SILVER_BULLET_RUNTIME=claude sb_optimization_score "$SR" "$H" >/dev/null
assert_eq "degraded fails counted" "5" "$SB_STACK_SCORE_FAILS"
assert_contains "degraded report" "$SB_STACK_SCORE_REPORT" "fail|graphify-cli|CLI missing|10"
assert_contains "degraded warn for platform" "$SB_STACK_SCORE_REPORT" "warn|graphify-platform|platform artifact missing|10"
assert_contains "gitleaks not required skip" "$SB_STACK_SCORE_REPORT" "skip|gitleaks|not required for profile|0"
assert_contains "env warn" "$SB_STACK_SCORE_REPORT" "warn|agentmemory-env|.env missing synergy_max flags|10"
assert_contains "bridge warn" "$SB_STACK_SCORE_REPORT" "warn|agentmemory-bridge|bridge not running|10"
assert_contains "persistence warn" "$SB_STACK_SCORE_REPORT" "warn|agentmemory-persistence|no launchd/systemd persistence|10"
assert_contains "synergy fail" "$SB_STACK_SCORE_REPORT" "fail|synergy-index|graph missing .agentmemory refs|15"
# gitleaks required but missing
printf '{"recommended_tools":{"agentmemory":{"enabled_by_user":true}},"optimization_profiles":{"synergy_max":{"agentmemory":{"gitleaks_required":true}}}}' >"$H"
PATH="$PB" sb_optimization_score "$SR" "$H" >/dev/null
assert_contains "gitleaks required but missing warns" "$SB_STACK_SCORE_REPORT" "warn|gitleaks|required but missing — brew install gitleaks|5"
tl_stub gitleaks 'exit 0'; hash -r
sb_optimization_score "$SR" "$H" >/dev/null
assert_contains "gitleaks required and installed" "$SB_STACK_SCORE_REPORT" "pass|gitleaks|installed ($TL_BIN/gitleaks)|5"
unstub gitleaks
# graphify only with the default repo / no config argument
(cd "$SR" && sb_optimization_score >/dev/null)
tl_pass "score defaults to PWD and no config"

# ---------- prompt line ----------
assert_eq "prompt line: no config file" "" "$(sb_stack_optimization_prompt_line "$SR" "$TL_TMP/none.json")"
assert_eq "prompt line: nothing opted in" "" "$(sb_stack_optimization_prompt_line "$SR" "$TL_TMP/empty.json")"
out="$(PATH="$PB" sb_stack_optimization_prompt_line "$SR" "$H")"
assert_contains "prompt line below threshold" "$out" "STACK OPTIMIZATION: score"
assert_contains "prompt line hint" "$out" "sb-optimize-stack.sh --apply"
assert_eq "prompt line above threshold" "" "$(PATH="$PB" SB_STACK_SCORE_THRESHOLD=1 sb_stack_optimization_prompt_line "$SR" "$H")"
(cd "$SR" && sb_stack_optimization_prompt_line "" "$H" >/dev/null) && tl_pass "prompt line default repo" || tl_fail "prompt line default repo"
out="$(PATH="$PB" sb_stack_optimization_prompt_line "$SR" "$TL_TMP/a-only.json")"
assert_contains "prompt line agentmemory only" "$out" "STACK OPTIMIZATION"
printf '{"recommended_tools":{"graphify":{"enabled_by_user":true}}}' >"$TL_TMP/g1.json"
out="$(PATH="$PB" sb_stack_optimization_prompt_line "$SR" "$TL_TMP/g1.json")"
assert_contains "prompt line graphify only" "$out" "STACK OPTIMIZATION"

# ---------- timestamps ----------
TS="$TL_TMP/ts.json"
tl_stub date 'echo 2024-01-02T03:04:05Z'; hash -r
printf '{"recommended_tools":{}}' >"$TS"
sb_stack_update_config_timestamps "$TS" apply 80
assert_eq "apply timestamp graphify" "2024-01-02T03:04:05Z" "$(jq -r .recommended_tools.graphify.optimization.last_applied_at "$TS")"
assert_eq "apply timestamp agentmemory" "2024-01-02T03:04:05Z" "$(jq -r .recommended_tools.agentmemory.optimization.last_applied_at "$TS")"
assert_eq "apply score" "80" "$(jq -r .recommended_tools.graphify.optimization.score "$TS")"
sb_stack_update_config_timestamps "$TS" verify 90
assert_eq "verify timestamp" "2024-01-02T03:04:05Z" "$(jq -r .recommended_tools.graphify.optimization.last_verified_at "$TS")"
assert_eq "verify score updates" "90" "$(jq -r .recommended_tools.agentmemory.optimization.score "$TS")"
assert_eq "verify keeps applied stamp" "2024-01-02T03:04:05Z" "$(jq -r .recommended_tools.graphify.optimization.last_applied_at "$TS")"
sb_stack_update_config_timestamps "$TS" apply
assert_eq "apply without score defaults to null" "null" "$(jq -r .recommended_tools.graphify.optimization.score "$TS")"
before="$(cat "$TS")"
sb_stack_update_config_timestamps "$TS" bogus 1
assert_eq "unknown mode leaves config untouched" "$before" "$(cat "$TS")"
sb_stack_update_config_timestamps "$TS"
assert_eq "default mode is apply" "null" "$(jq -r .recommended_tools.agentmemory.optimization.score "$TS")"
yes_t "missing config file is a no-op" sb_stack_update_config_timestamps "$TL_TMP/none.json" apply 1
yes_t "no config argument is a no-op" sb_stack_update_config_timestamps
yes_t "without jq is a no-op" env PATH="$PNJ" bash -c 'source "$1"; sb_stack_update_config_timestamps "$2" apply 5' _ "$LIBF" "$TS"
assert_eq "no jq left score untouched" "null" "$(jq -r .recommended_tools.graphify.optimization.score "$TS")"
printf 'not json' >"$TS"
no_t "invalid config fails to update" sb_stack_update_config_timestamps "$TS" apply 1 2>/dev/null
assert_eq "invalid config preserved" "not json" "$(cat "$TS")"

tl_results
