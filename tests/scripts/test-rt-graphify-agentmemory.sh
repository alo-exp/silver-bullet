#!/usr/bin/env bash
# scripts/lib/recommended-tools/{graphify-worktree,probe-graphify,repair-graphify,probe-agentmemory}.sh
# Probe decision tables and repair flows. Package managers, graphify, agentmemory,
# curl and the patch helpers are stubs; nothing is installed and no network is used.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$(dirname "${BASH_SOURCE[0]}")/../lib/h-recommended-helpers.sh"
cd "$TL_TMP"  # never run with the checkout as cwd: stubs and relative writes stay in the sandbox
# The checkout's tracked knowledge graph must never be touched by this test.
REPO_GRAPH="$TL_REPO_ROOT/graphify-out/graph.json"
GRAPH_BEFORE="$(cksum <"$REPO_GRAPH")|$(stat -c %Y "$REPO_GRAPH")"

hr_stage_repo
# shellcheck source=/dev/null
source "$HR_RTLIB/common.sh"
rt_init_paths
# shellcheck source=/dev/null
source "$HR_RTLIB/probe-graphify.sh"
# shellcheck source=/dev/null
source "$HR_RTLIB/repair-graphify.sh"
# shellcheck source=/dev/null
source "$HR_RTLIB/probe-agentmemory.sh"
export RT_HOST=cursor
export RT_SKIP_VENDOR_DOCTOR=1
hr_bin sleep 'exit 0'

# ============================================================ graphify-worktree
hr_consent graphify=enabled
assert_eq "worktree root of the project" "$HR_PROJ" "$(rt_graphify_worktree_root)"
assert_eq "worktree root of an explicit dir" "$HR_PROJ" "$(mkdir -p "$HR_PROJ/a"; rt_graphify_worktree_root "$HR_PROJ/a")"
assert_eq "lock path" "/x/graphify-out/.sb-index.lock" "$(rt_graphify_lock_path /x/)"
assert_eq "reject symlink: empty root" "1" "$(rc_of rt_graphify_reject_symlink "")"
assert_eq "reject symlink: plain tree ok" "0" "$(rc_of rt_graphify_reject_symlink "$HR_PROJ")"
mkdir -p "$TL_TMP/real-out"; ln -s "$TL_TMP/real-out" "$HR_PROJ/graphify-out"
assert_eq "reject symlink: symlinked graphify-out" "1" "$(rc_of rt_graphify_reject_symlink "$HR_PROJ")"
rm -f "$HR_PROJ/graphify-out"; mkdir -p "$HR_PROJ/graphify-out"; ln -s "$TL_TMP/real-out/graph.json" "$HR_PROJ/graphify-out/graph.json"
assert_eq "reject symlink: symlinked graph.json" "1" "$(rc_of rt_graphify_reject_symlink "$HR_PROJ")"
rm -rf "$HR_PROJ/graphify-out"

rt_graphify_record_build_commit "$HR_PROJ"
HEAD_COMMIT="$(git -C "$HR_PROJ" rev-parse HEAD)"
assert_eq "build commit recorded" "$HEAD_COMMIT" "$(cat "$HR_PROJ/graphify-out/.build-commit")"
assert_eq "record build commit outside git is a no-op" "0" "$(rc_of rt_graphify_record_build_commit "$TL_TMP/not-git")"
assert_file_absent "nothing written outside git" "$TL_TMP/not-git/graphify-out"
# the output directory cannot be created -> the write fails, the helper reports it
printf 'file\n' >"$TL_TMP/blocked"
git init -q "$TL_TMP/blocked-git"; git -C "$TL_TMP/blocked-git" -c user.email=a@b -c user.name=n commit -q --allow-empty -m i
printf 'file\n' >"$TL_TMP/blocked-git/graphify-out"
assert_eq "record build commit fails when graphify-out is a file" "1" "$(rc_of rt_graphify_record_build_commit "$TL_TMP/blocked-git")"

# staleness
rm -rf "$HR_PROJ/graphify-out"
assert_eq "stale: no project config" "1" "$(RT_PROJECT_ROOT="$TL_TMP/nocfg" rc_of rt_probe_graphify_index_stale)"
assert_eq "stale: no graph" "1" "$(rc_of rt_probe_graphify_index_stale)"
mkdir -p "$HR_PROJ/graphify-out"; echo '{}' >"$HR_PROJ/graphify-out/graph.json"
assert_eq "stale: no recorded build commit" "0" "$(rc_of rt_probe_graphify_index_stale)"
printf '%s' "$HEAD_COMMIT" >"$HR_PROJ/graphify-out/.build-commit"
assert_eq "fresh: build commit equals HEAD" "1" "$(rc_of rt_probe_graphify_index_stale)"
printf 'deadbeef' >"$HR_PROJ/graphify-out/.build-commit"
assert_eq "stale: build commit differs" "0" "$(rc_of rt_probe_graphify_index_stale)"
printf '%s' "$HEAD_COMMIT" >"$HR_PROJ/graphify-out/.build-commit"
NOGITPROJ="$TL_TMP/nogit-proj"; mkdir -p "$NOGITPROJ/graphify-out"; echo '{}' >"$NOGITPROJ/graphify-out/graph.json"; echo '{}' >"$NOGITPROJ/.silver-bullet.json"
assert_eq "stale: outside git there is no HEAD" "1" "$(RT_PROJECT_ROOT="$NOGITPROJ" rc_of rt_probe_graphify_index_stale)"

# an unreadable build-commit file counts as stale
printf '%s' "$HEAD_COMMIT" >"$HR_PROJ/graphify-out/.build-commit" 2>/dev/null || { mkdir -p "$HR_PROJ/graphify-out"; echo '{}' >"$HR_PROJ/graphify-out/graph.json"; printf '%s' "$HEAD_COMMIT" >"$HR_PROJ/graphify-out/.build-commit"; }
hr_bin cat 'exit 1'
assert_eq "stale: unreadable build commit" "0" "$(rc_of rt_probe_graphify_index_stale)"
hr_nobin cat
rm -rf "$HR_PROJ/graphify-out"

# build index
hr_bin graphify 'echo "graphify $*" >>"$HR_LOG"; if [[ "$1" == update ]]; then mkdir -p graphify-out; echo "{}" >graphify-out/graph.json; fi; exit "${HR_GRAPHIFY_RC:-0}"'
rm -rf "$HR_PROJ/graphify-out"
: >"$HR_LOG"
assert_eq "build index outside git fails" "1" "$(RT_PROJECT_ROOT="$NOGITPROJ" rc_of rt_graphify_worktree_build_index "$NOGITPROJ")"
assert_eq "build index without a project root fails" "1" "$(RT_PROJECT_ROOT='' rc_of rt_graphify_worktree_build_index "")"
rt_graphify_worktree_build_index "$HR_PROJ"
assert_contains "graphify update invoked" "$(cat "$HR_LOG")" "graphify update . --no-cluster"
assert_eq "build commit stamped after the build" "$HEAD_COMMIT" "$(cat "$HR_PROJ/graphify-out/.build-commit")"
assert_file_absent "lock released" "$HR_PROJ/graphify-out/.sb-index.lock"
: >"$HR_LOG"
rt_graphify_worktree_build_index "$HR_PROJ"
assert_eq "fresh index is not rebuilt" "" "$(cat "$HR_LOG")"
printf 'old' >"$HR_PROJ/graphify-out/.build-commit"
rt_graphify_worktree_build_index "$HR_PROJ"
assert_contains "stale index is rebuilt" "$(cat "$HR_LOG")" "graphify update"
assert_eq "rebuilt index is re-stamped" "$HEAD_COMMIT" "$(cat "$HR_PROJ/graphify-out/.build-commit")"
printf 'old' >"$HR_PROJ/graphify-out/.build-commit"
assert_eq "failing update fails the build" "1" "$(HR_GRAPHIFY_RC=3 rc_of rt_graphify_worktree_build_index "$HR_PROJ")"
assert_eq "failed build leaves the stamp alone" "old" "$(cat "$HR_PROJ/graphify-out/.build-commit")"
NOTO="$(hr_path_without timeout)"
: >"$HR_LOG"
(PATH="$NOTO"; rt_graphify_worktree_build_index "$HR_PROJ")
assert_contains "update runs without timeout(1)" "$(cat "$HR_LOG")" "graphify update . --no-cluster"
rm -rf "$HR_PROJ/graphify-out"
NOGRAPHIFY="$(hr_path_without graphify)"
assert_eq "no graphify binary and no index -> fail" "1" "$(PATH="$NOGRAPHIFY" rc_of rt_graphify_worktree_build_index "$HR_PROJ")"
ln -s "$TL_TMP/real-out" "$HR_PROJ/graphify-out"
assert_eq "symlinked graphify-out is refused" "1" "$(rc_of rt_graphify_worktree_build_index "$HR_PROJ")"
rm -f "$HR_PROJ/graphify-out"
# lock held by someone else: the build times out
mkdir -p "$HR_PROJ/graphify-out/.sb-index.lock"
assert_eq "held lock times out" "1" "$(RT_GRAPHIFY_UPDATE_TIMEOUT=0 rc_of rt_graphify_worktree_build_index "$HR_PROJ")"
rmdir "$HR_PROJ/graphify-out/.sb-index.lock"
rm -rf "$HR_PROJ/graphify-out"

# ================================================================ probe-graphify
assert_eq "mcp configured: no config" "1" "$(rc_of rt_probe_graphify_mcp_configured)"
mkdir -p "$HOME/.cursor"; printf '{"mcpServers":{"graphify":{}}}\n' >"$HOME/.cursor/mcp.json"
assert_eq "mcp configured" "0" "$(rc_of rt_probe_graphify_mcp_configured)"
rm -f "$HOME/.cursor/mcp.json"
hr_bin graphify-mcp 'exit 0'
assert_eq "mcp binary: none in the manifest" "1" "$(rc_of rt_probe_graphify_mcp_binary)"
hr_manifest "graphify=$HR_BIN/graphify-mcp"
assert_eq "mcp binary: from the manifest" "0" "$(rc_of rt_probe_graphify_mcp_binary)"
unset SB_GLOBAL_TOOLSTACK_MANIFEST
assert_eq "base only: graphify on PATH, no manifest" "0" "$(rc_of rt_probe_graphify_base_only)"
hr_manifest "graphify=$HR_BIN/graphify-mcp"
assert_eq "base only: false when the mcp binary resolves" "1" "$(rc_of rt_probe_graphify_base_only)"
assert_eq "base only: false without graphify" "1" "$(PATH="$NOGRAPHIFY" rc_of rt_probe_graphify_base_only)"
hr_bin graphify 'echo "graphify 1.2.3"'
hr_bin graphify 'exit 1'
assert_eq "skew: failing --version is not skew" "1" "$(rc_of rt_probe_graphify_skill_package_skew)"
hr_bin graphify 'echo "graphify 1.2.3"'
assert_eq "skew: not reported" "1" "$(rc_of rt_probe_graphify_skill_package_skew)"
hr_bin graphify 'echo "warning: skill is from graphify 0.9, package 1.2"'
assert_eq "skew: reported" "0" "$(rc_of rt_probe_graphify_skill_package_skew)"
assert_eq "skew: no graphify" "1" "$(PATH="$NOGRAPHIFY" rc_of rt_probe_graphify_skill_package_skew)"
hr_bin graphify 'echo "graphify $*" >>"$HR_LOG"; if [[ "$1" == update ]]; then mkdir -p graphify-out; echo "{}" >graphify-out/graph.json; fi'

pg() { hr_state "$(rt_probe_graphify)"; }
RT_HOST=goose; assert_eq "graphify: unsupported host" "unsupported|none||false" "$(pg)"; RT_HOST=cursor
hr_consent graphify=disabled; assert_eq "graphify: disabled" "disabled|none||false" "$(pg)"
hr_consent; assert_eq "graphify: pending (no entry)" "pending|none||false" "$(pg)"
hr_consent graphify=pending; assert_eq "graphify: pending (null)" "pending|none||false" "$(pg)"
hr_consent graphify=suspended; assert_eq "graphify: suspended" "suspended|none||false" "$(pg)"
hr_consent graphify=enabled
assert_eq "graphify: cli missing" "failed|none|cli_missing|true" "$(PATH="$NOGRAPHIFY" pg)"
SAVED_MANIFEST="$SB_GLOBAL_TOOLSTACK_MANIFEST"; unset SB_GLOBAL_TOOLSTACK_MANIFEST
assert_eq "graphify: mcp binary missing (base only)" "repairable|none|mcp_binary_missing,base_only_install|true" "$(pg)"
export SB_GLOBAL_TOOLSTACK_MANIFEST="$SAVED_MANIFEST"
assert_eq "graphify: manifest points at a missing mcp binary" "repairable|none|mcp_binary_missing,base_only_install|true" \
  "$(hr_manifest "graphify=$HR_BIN/nonexistent-mcp"; hr_state "$(rt_probe_graphify)")"
hr_manifest "graphify=$HR_BIN/graphify-mcp"
assert_eq "graphify: mcp not configured" "repairable|partial|mcp_not_configured|true" "$(pg)"
printf '{"mcpServers":{"graphify":{}}}\n' >"$HOME/.cursor/mcp.json"
assert_eq "graphify: index missing" "repairable|none|index_missing|true" "$(pg)"
mkdir -p "$HR_PROJ/graphify-out"; echo '{}' >"$HR_PROJ/graphify-out/graph.json"
assert_eq "graphify: index stale (no recorded build)" "repairable|none|index_stale|true" "$(pg)"
printf '%s' "$HEAD_COMMIT" >"$HR_PROJ/graphify-out/.build-commit"
assert_eq "graphify: platform artifact missing" "repairable|none|platform_artifact_missing|true" "$(pg)"
mkdir -p "$HR_PROJ/.cursor/rules"; echo 'graphify rule' >"$HR_PROJ/.cursor/rules/graphify.mdc"
assert_eq "graphify: ready" "ready|full||false" "$(pg)"
hr_bin graphify 'echo "skill is from graphify 0.1"'
out="$(rt_probe_graphify)"
assert_eq "graphify: ready with skill skew evidence" "ready|full|skill_package_skew|false" "$(hr_state "$out")"
assert_eq "graphify: extra json reports configured/live" "true|true|true" "$(jq -r '"\(.configured.mcp)|\(.live.cli_present)|\(.live.mcp_live)"' <<<"$out")"
hr_bin graphify 'exit 0'
# config path override: no project config at all skips the index checks
assert_eq "graphify: no config skips the index check" "ready|full||false" "$(RT_PROJECT_ROOT="$TL_TMP/nocfg" RT_CONFIG_FILE='' hr_state "$(rt_probe_graphify)" 2>/dev/null || echo fail)"
# symlinked graphify-out directory (the index file itself is a regular file behind the link)
rm -rf "$HR_PROJ/graphify-out"; mkdir -p "$TL_TMP/real-out"; echo '{}' >"$TL_TMP/real-out/graph.json"; ln -s "$TL_TMP/real-out" "$HR_PROJ/graphify-out"
assert_eq "graphify: symlinked graphify-out directory" "failed|none|symlinked_graph_dir|false" "$(pg)"
rm -f "$HR_PROJ/graphify-out"
# custom graph path with a symlinked default location
mkdir -p "$HR_PROJ/custom" "$HR_PROJ/graphify-out"; echo '{}' >"$HR_PROJ/custom/graph.json"; ln -s "$HR_PROJ/custom/graph.json" "$HR_PROJ/graphify-out/graph.json"
hr_project '{"sb_initiated":true,"recommended_tools":{"graphify":{"enabled_by_user":true,"graph_path":"custom/graph.json"}}}'
assert_eq "graphify: symlinked graph.json in the default location" "failed|none|symlinked_graph_dir|false" "$(pg)"
rm -rf "$HR_PROJ/custom" "$HR_PROJ/graphify-out"

# ================================================================ repair-graphify
unset SB_GLOBAL_TOOLSTACK_MANIFEST
hr_consent graphify=enabled
export RT_MODE=apply RT_ENTRY_POINT=init RT_SCOPE=all
# packages
hr_nobin graphify
RG_NOTOOLS="$(hr_path_without uv pipx graphify)"
assert_eq "packages: no uv or pipx" "---FAILURES---
no_uv_or_pipx" "$(PATH="$RG_NOTOOLS" rt_repair_graphify_packages)"
hr_bin uv 'echo "uv $*" >>"$HR_LOG"; exit "${HR_UV_RC:-0}"'
hr_bin pipx 'echo "pipx $*" >>"$HR_LOG"; exit "${HR_PIPX_RC:-0}"'
RG_NOGR="$(hr_path_without graphify)"
assert_eq "packages: uv install" "uv_tool_install_graphifyy_mcp
---FAILURES---" "$(PATH="$RG_NOGR" rt_repair_graphify_packages)"
assert_eq "packages: uv install failure" "---FAILURES---
uv_tool_install_failed" "$(HR_UV_RC=1 PATH="$RG_NOGR" rt_repair_graphify_packages)"
hr_nobin uv
RG_NOGR2="$(hr_path_without graphify uv)"
assert_eq "packages: pipx install" "pipx_install_graphifyy_mcp
---FAILURES---" "$(PATH="$RG_NOGR2" rt_repair_graphify_packages)"
assert_eq "packages: pipx install failure" "---FAILURES---
pipx_install_failed" "$(HR_PIPX_RC=1 PATH="$RG_NOGR2" rt_repair_graphify_packages)"
# graphify present but no mcp binary -> forced reinstall
hr_bin graphify 'exit 0'
hr_bin uv 'echo "uv $*" >>"$HR_LOG"; exit "${HR_UV_RC:-0}"'
assert_eq "packages: uv upgrade" "uv_upgrade_graphifyy_mcp
---FAILURES---" "$(rt_repair_graphify_packages)"
assert_eq "packages: uv upgrade failure" "---FAILURES---
uv_upgrade_failed" "$(HR_UV_RC=1 rt_repair_graphify_packages)"
hr_nobin uv
RG_NOUV="$(hr_path_without uv)"
assert_eq "packages: pipx upgrade" "pipx_upgrade_graphifyy_mcp
---FAILURES---" "$(PATH="$RG_NOUV" rt_repair_graphify_packages)"
assert_eq "packages: pipx upgrade failure" "---FAILURES---
pipx_upgrade_failed" "$(HR_PIPX_RC=1 PATH="$RG_NOUV" rt_repair_graphify_packages)"
RG_NONE="$(hr_path_without uv pipx)"
assert_eq "packages: nothing to do without installers" "---FAILURES---" "$(PATH="$RG_NONE" rt_repair_graphify_packages)"
hr_manifest "graphify=$HR_BIN/graphify-mcp"
assert_eq "packages: healthy install needs nothing" "---FAILURES---" "$(rt_repair_graphify_packages)"

# handshake
hr_bin graphify-mcp 'exit 0'
assert_eq "handshake: clean exit" "0" "$(rc_of rt_graphify_mcp_handshake)"
hr_bin graphify-mcp 'exit 1'
assert_eq "handshake: exit 1 is acceptable" "0" "$(rc_of rt_graphify_mcp_handshake)"
hr_bin graphify-mcp 'exit 2'
assert_eq "handshake: other exit codes fail" "1" "$(rc_of rt_graphify_mcp_handshake)"
hr_bin graphify-mcp 'exec sleep 30'
hr_nobin sleep
SECONDS=0
assert_eq "handshake: a server that never exits is stopped and fails" "1" "$(rc_of rt_graphify_mcp_handshake)"
assert_eq "handshake: bounded wait" "1" "$([[ $SECONDS -lt 20 ]] && echo 1 || echo 0)"
hr_bin sleep 'exit 0'
hr_nobin graphify-mcp
assert_eq "handshake: missing binary" "1" "$(PATH="$(hr_path_without graphify-mcp)" rc_of rt_graphify_mcp_handshake)"
hr_bin graphify-mcp 'exit 0'

# platform refresh
assert_eq "platform: no project config" "1" "$(RT_PROJECT_ROOT="$TL_TMP/nocfg" rc_of rt_repair_graphify_platform)"
hr_bin sb-platform-marker 'echo marker >>"$HR_LOG"'
: >"$HR_LOG"
sb_recommended_tool_platform_post_index_commands() { printf '%s\n' "" "sb-platform-marker" "false"; }
# shellcheck disable=SC2218  # defined by the sourced repair-graphify.sh
rt_repair_graphify_platform
assert_eq "platform: post-index commands evaluated, failures tolerated, blanks skipped" "marker" "$(cat "$HR_LOG")"
unset -f sb_recommended_tool_platform_post_index_commands
# shellcheck source=/dev/null
source "$TL_REPO_ROOT/hooks/lib/recommended-tools.sh"

# a handshake child that cannot be signalled (kill reports failure) is still reaped
hr_bin graphify-mcp 'exec sleep 30'
hr_nobin sleep
assert_eq "handshake: failed kill is tolerated" "1" "$(kill() { if [[ "$1" == -0 ]]; then builtin kill "$@"; return; fi; builtin kill "$@"; return 1; }; rc_of rt_graphify_mcp_handshake)"
hr_bin sleep 'exit 0'
hr_bin graphify-mcp 'exit 0'

# mcp config merge
: >"$HR_LOG"
assert_eq "mcp config: patch helper missing" "1" "$(RT_REPO_ROOT="$TL_TMP/none" rc_of rt_repair_graphify_mcp_config)"
hr_nobin graphify-mcp
assert_eq "mcp config: handshake failure" "1" "$(PATH="$(hr_path_without graphify-mcp)" rc_of rt_repair_graphify_mcp_config)"
hr_bin graphify-mcp 'exit 0'
rt_repair_graphify_mcp_config
assert_contains "mcp config: graphify patched when consented" "$(cat "$HR_LOG")" "RT_PATCH_GRAPHIFY=1"
assert_contains "mcp config: leanctx never patched here" "$(cat "$HR_LOG")" "RT_PATCH_LEANCTX=0"
assert_contains "mcp config: repo root passed" "$(cat "$HR_LOG")" "TOOLSTACK_REPO_ROOT=$HR_STAGE"
assert_eq "mcp config: patch env cleaned up" "" "${RT_PATCH_GRAPHIFY:-}${RT_PATCH_LEANCTX:-}"
: >"$HR_LOG"
RT_MODE=verify rt_repair_graphify_mcp_config
assert_contains "mcp config: not consented/authorized -> graphify patch off" "$(cat "$HR_LOG")" "RT_PATCH_GRAPHIFY=0"
assert_eq "mcp config: patcher failure status" "4" "$(HR_PY_RC_patch_mcp=4 bash -c 'true'; export HR_PY_RC_patch_mcp=4; rc=0; rt_repair_graphify_mcp_config || rc=$?; unset HR_PY_RC_patch_mcp; echo $rc)"

# full repair flow
hr_manifest "graphify=$HR_BIN/graphify-mcp"
mkdir -p "$HR_PROJ/graphify-out" "$HR_PROJ/.cursor/rules"; echo '{}' >"$HR_PROJ/graphify-out/graph.json"; echo graphify >"$HR_PROJ/.cursor/rules/graphify.mdc"
printf '%s' "$HEAD_COMMIT" >"$HR_PROJ/graphify-out/.build-commit"
RT_MODE=verify
assert_eq "repair: not authorized" '{"actions":[],"failures":["mutation_not_authorized"],"restart_required":false}' "$(rt_repair_graphify)"
RT_MODE=apply
: >"$HR_LOG"
out="$(rt_repair_graphify 2>/dev/null)"
assert_eq "repair: healthy stack merges mcp config and refreshes platform" '{"actions":["mcp_config_merged","worktree_index_built","platform_artifacts_refreshed"],"failures":[],"restart_required":true}' "$(jq -c . <<<"$out")"
out="$(RT_CROSS_TOOL_BATCH=1 rt_repair_graphify 2>/dev/null)"
assert_eq "repair: cross-tool batch owns the mcp merge" '{"actions":["worktree_index_built","platform_artifacts_refreshed"],"failures":[],"restart_required":false}' "$(jq -c . <<<"$out")"
out="$(HR_PY_RC_patch_mcp=1 rt_repair_graphify 2>/dev/null)"
assert_eq "repair: merge failure recorded" '{"actions":["worktree_index_built","platform_artifacts_refreshed"],"failures":["mcp_config_merge_failed"],"restart_required":false}' "$(jq -c . <<<"$out")"
# stale index gets rebuilt
printf 'old' >"$HR_PROJ/graphify-out/.build-commit"
out="$(RT_CROSS_TOOL_BATCH=1 rt_repair_graphify 2>/dev/null)"
assert_eq "repair: stale index rebuilt" '{"actions":["worktree_index_built","platform_artifacts_refreshed"],"failures":[],"restart_required":false}' "$(jq -c . <<<"$out")"
# packages missing + no cli: nothing else runs
hr_nobin graphify; hr_nobin uv; hr_nobin pipx
out="$(PATH="$(hr_path_without graphify uv pipx)" rt_repair_graphify 2>/dev/null)"
assert_eq "repair: no cli and no installers" '{"actions":[],"failures":["no_uv_or_pipx"],"restart_required":false}' "$(jq -c . <<<"$out")"
# package install actions are carried into the result
hr_nobin graphify
hr_bin uv 'echo "uv $*" >>"$HR_LOG"'
out="$(PATH="$(hr_path_without graphify)" rt_repair_graphify 2>/dev/null)"
assert_contains "repair: package install action reported" "$(jq -c . <<<"$out")" '"uv_tool_install_graphifyy_mcp"'
hr_nobin uv
hr_bin graphify 'exit 0'
# platform refresh failing is reported
hr_bin graphify 'exit 0'
rt_repair_graphify_platform() { return 1; }
out="$(RT_CROSS_TOOL_BATCH=1 rt_repair_graphify 2>/dev/null)"
assert_contains "repair: platform refresh failure recorded" "$(jq -c . <<<"$out")" '"platform_refresh_failed"'
unset -f rt_repair_graphify_platform
# shellcheck source=/dev/null
source "$HR_RTLIB/repair-graphify.sh"

# ============================================================== probe-agentmemory
hr_manifest
unset SB_GLOBAL_TOOLSTACK_MANIFEST
pa() { hr_state "$(rt_probe_agentmemory)"; }
assert_eq "agentmemory mcp: not configured anywhere" "1" "$(rc_of rt_probe_agentmemory_mcp_configured)"
printf '{"mcpServers":{"agentmemory":{}}}\n' >"$HOME/.cursor/mcp.json"
assert_eq "agentmemory mcp: configured (cursor)" "0" "$(rc_of rt_probe_agentmemory_mcp_configured)"
printf '{"mcpServers":{"user-agentmemory":{}}}\n' >"$HOME/.cursor/mcp.json"
assert_eq "agentmemory mcp: user- prefixed server (cursor)" "0" "$(rc_of rt_probe_agentmemory_mcp_configured)"
printf '{"mcpServers":{}}\n' >"$HOME/.cursor/mcp.json"
assert_eq "agentmemory mcp: server missing (cursor)" "1" "$(rc_of rt_probe_agentmemory_mcp_configured)"
rm -f "$HOME/.cursor/mcp.json"
assert_eq "agentmemory mcp: no cursor config" "1" "$(rc_of rt_probe_agentmemory_mcp_configured)"
assert_eq "agentmemory mcp: claude user- prefixed" "0" "$(printf '{"mcpServers":{"user-agentmemory":{}}}\n' >"$HOME/.claude.json"; RT_HOST=claude rc_of rt_probe_agentmemory_mcp_configured)"
assert_eq "agentmemory mcp: no claude config" "1" "$(rm -f "$HOME/.claude.json"; RT_HOST=claude rc_of rt_probe_agentmemory_mcp_configured)"
PI_CFG="$HOME/.pi/agent/extensions/silver-bullet-five-tool-stack/config.json"; mkdir -p "$(dirname "$PI_CFG")"
assert_eq "agentmemory mcp: pi without config" "1" "$(RT_HOST=pi rc_of rt_probe_agentmemory_mcp_configured)"
printf '{"servers":{"agentmemory":{"enabled":true}}}\n' >"$PI_CFG"
assert_eq "agentmemory mcp: pi enabled" "0" "$(RT_HOST=pi rc_of rt_probe_agentmemory_mcp_configured)"
printf '{"servers":{"agentmemory":{"enabled":false}}}\n' >"$PI_CFG"
assert_eq "agentmemory mcp: pi disabled" "1" "$(RT_HOST=pi rc_of rt_probe_agentmemory_mcp_configured)"
assert_eq "agentmemory mcp: hosts without a fallback" "1" "$(RT_HOST=codex rc_of rt_probe_agentmemory_mcp_configured)"

hr_bin curl 'exit "${HR_CURL_RC:-1}"'
RT_HOST=goose; assert_eq "agentmemory: unsupported host" "unsupported|none||false" "$(pa)"; RT_HOST=cursor
hr_consent agentmemory=disabled; assert_eq "agentmemory: disabled" "disabled|none||false" "$(pa)"
hr_consent; assert_eq "agentmemory: pending" "pending|none||false" "$(pa)"
hr_consent agentmemory=suspended; assert_eq "agentmemory: suspended" "suspended|none||false" "$(pa)"
hr_consent agentmemory=enabled
AM_NOCLI="$(hr_path_without agentmemory)"
assert_eq "agentmemory: cli missing" "failed|none|cli_missing|true" "$(PATH="$AM_NOCLI" pa)"
hr_bin agentmemory 'echo "status: stopped"'
assert_eq "agentmemory: server unhealthy" "repairable|none|server_unhealthy|true" "$(pa)"
hr_bin agentmemory 'echo "Health: healthy"'
assert_eq "agentmemory: mcp not configured" "repairable|partial|mcp_not_configured|true" "$(pa)"
printf '{"mcpServers":{"agentmemory":{}}}\n' >"$HOME/.cursor/mcp.json"
assert_eq "agentmemory: export missing" "repairable|none|export_missing|true" "$(pa)"
mkdir -p "$HR_PROJ/.agentmemory/memory" "$HR_PROJ/.agentmemory/snapshots"
assert_eq "agentmemory: ready" "ready|full||false" "$(pa)"
assert_eq "agentmemory: healthy through the health endpoint" "ready|full||false" "$(hr_bin agentmemory 'echo down'; HR_CURL_RC=0 pa)"

# ============================================================== repair-agentmemory
hr_nobin agentmemory
RT_MODE=verify
assert_eq "am repair: not authorized" '{"actions":[],"failures":["mutation_not_authorized"],"restart_required":false}' "$(rt_repair_agentmemory)"
RT_MODE=apply
assert_eq "am config: patch helper missing" "1" "$(RT_REPO_ROOT="$TL_TMP/none" rc_of rt_repair_agentmemory_mcp_config)"
: >"$HR_LOG"
rt_repair_agentmemory_mcp_config
assert_contains "am config: agentmemory patched when consented" "$(cat "$HR_LOG")" "RT_PATCH_AGENTMEMORY=1"
assert_contains "am config: host passed" "$(cat "$HR_LOG")" "RT_HOST=cursor"
: >"$HR_LOG"; RT_MODE=verify rt_repair_agentmemory_mcp_config
assert_contains "am config: not authorized -> patch off" "$(cat "$HR_LOG")" "RT_PATCH_AGENTMEMORY=0"
assert_eq "am config: patcher failure status" "6" "$(export HR_PY_RC_patch_mcp=6; rc=0; rt_repair_agentmemory_mcp_config || rc=$?; unset HR_PY_RC_patch_mcp; echo $rc)"

hr_bin npm 'echo "npm $*" >>"$HR_LOG"; exit "${HR_NPM_RC:-0}"'
hr_bin agentmemory 'echo "agentmemory $*" >>"$HR_LOG"; echo "Health: healthy"'
rm -rf "$HR_PROJ/.agentmemory" "$HOME/.agentmemory"; rm -f "$HOME/.cursor/mcp.json"
: >"$HR_LOG"
out="$(rt_repair_agentmemory)"
assert_eq "am repair: healthy cli, export root and mcp config created" '{"actions":["export_root_created","mcp_config_merged"],"failures":[],"restart_required":true}' "$(jq -c . <<<"$out")"
assert_eq "am repair: export directories created" "0" "$(rc_of test -d "$HR_PROJ/.agentmemory/snapshots")"
out="$(RT_CROSS_TOOL_BATCH=1 rt_repair_agentmemory)"
assert_eq "am repair: cross-tool batch owns the mcp merge" '{"actions":["export_root_created"],"failures":[],"restart_required":false}' "$(jq -c . <<<"$out")"
out="$(HR_PY_RC_patch_mcp=1 rt_repair_agentmemory)"
assert_eq "am repair: merge failure recorded" '{"actions":["export_root_created"],"failures":["mcp_config_merge_failed"],"restart_required":false}' "$(jq -c . <<<"$out")"
printf '{"mcpServers":{"agentmemory":{}}}\n' >"$HOME/.cursor/mcp.json"
out="$(rt_repair_agentmemory)"
assert_eq "am repair: configured host needs no merge" '{"actions":["export_root_created"],"failures":[],"restart_required":false}' "$(jq -c . <<<"$out")"
# export root cannot be created
printf 'file\n' >"$HR_PROJ/.agentmemory.blocker"
hr_project '{"sb_initiated":true,"recommended_tools":{"agentmemory":{"enabled_by_user":true,"export_path":".agentmemory-blocked/x"}}}'
out="$(RT_PROJECT_ROOT="$HR_PROJ" rt_repair_agentmemory)"
assert_contains "am repair: export root outcome reported" "$out" '"actions"'
# server log directory cannot be created, export path lookup fails, export root blocked
hr_consent agentmemory=enabled
hr_bin agentmemory 'echo "Health: healthy"'
rm -rf "$HOME/.agentmemory" "$HR_PROJ/.agentmemory"; printf 'file\n' >"$HR_PROJ/.agentmemory"
out="$(sb_agentmemory_export_rel_path() { return 1; }; sb_agentmemory_server_healthy() { return 1; }; mkdir -p "$TL_TMP/fake-home"; printf 'file\n' >"$TL_TMP/fake-home/.agentmemory"; HOME="$TL_TMP/fake-home" rt_repair_agentmemory)"
assert_contains "am repair: blocked export root reported" "$(jq -c . <<<"$out")" '"export_root_failed"'
rm -f "$HR_PROJ/.agentmemory"
# cli missing -> npm install; server down -> start attempt
hr_consent agentmemory=enabled
hr_nobin agentmemory
AM_NOCLI2="$(hr_path_without agentmemory)"
: >"$HR_LOG"
out="$(PATH="$AM_NOCLI2" rt_repair_agentmemory)"
assert_contains "am repair: npm install attempted" "$(cat "$HR_LOG")" "npm install -g @agentmemory/agentmemory"
assert_contains "am repair: npm install recorded" "$(jq -c . <<<"$out")" '"npm_install_agentmemory"'
assert_contains "am repair: server start failure recorded" "$(jq -c . <<<"$out")" '"server_start_failed"'
out="$(HR_NPM_RC=1 PATH="$AM_NOCLI2" rt_repair_agentmemory)"
assert_contains "am repair: npm failure recorded" "$(jq -c . <<<"$out")" '"npm_install_failed"'
# server down but agentmemory starts and becomes healthy
hr_bin agentmemory 'echo "agentmemory $*" >>"$HR_LOG"; [[ -f "$HOME/.agentmemory/started" ]] && echo "Health: healthy"; touch "$HOME/.agentmemory/started"; exit 0'
rm -rf "$HOME/.agentmemory"
out="$(rt_repair_agentmemory)"
assert_contains "am repair: server started" "$(jq -c . <<<"$out")" '"server_started"'
assert_file_exists "am repair: server log directory created" "$HOME/.agentmemory/server.log"

assert_eq "the checkout's graphify-out/graph.json is untouched (content and mtime)" "$GRAPH_BEFORE" "$(cksum <"$REPO_GRAPH")|$(stat -c %Y "$REPO_GRAPH")"
tl_results
