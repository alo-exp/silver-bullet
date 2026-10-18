#!/usr/bin/env bash
# scripts/lib/recommended-tools/common.sh and paths.sh: the reconciler's shared
# helpers (consent, host config lookups, ids, authorization, scope, locking,
# atomic writes, state paths). Libraries are sourced in-process; all state lives
# in the sandboxed HOME.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

RTLIB="$TL_REPO_ROOT/scripts/lib/recommended-tools"
export RT_REPO_ROOT="$TL_REPO_ROOT"
# shellcheck source=/dev/null
source "$RTLIB/paths.sh"
# shellcheck source=/dev/null
source "$RTLIB/common.sh"
rt_init_paths

rc_of() { local rc=0; "$@" >/dev/null 2>&1 || rc=1; printf '%s' "$rc"; }

PROJ="$TL_TMP/proj"
tl_git_repo "$PROJ"
cfg() { printf '%s\n' "$1" >"$PROJ/.silver-bullet.json"; }

# ------------------------------------------------------------ _rt_repo_root
STAGED="$TL_TMP/staged"
mkdir -p "$STAGED/scripts/lib/recommended-tools"
cp "$RTLIB/common.sh" "$STAGED/scripts/lib/recommended-tools/common.sh"
repo_root_of() { bash -c 'source "$1"; _rt_repo_root' _ "$STAGED/scripts/lib/recommended-tools/common.sh"; }
assert_eq "repo root: no reconciler beside the lib, no recorded root -> computed candidate" "$STAGED" "$(repo_root_of)"
mkdir -p "$HOME/.cursor/state/toolstack"
printf '/recorded/repo\n' >"$HOME/.cursor/state/toolstack/repo-root"
assert_eq "repo root: recorded installer root is used" "/recorded/repo" "$(repo_root_of)"
touch "$STAGED/scripts/reconcile-recommended-tools.sh"
assert_eq "repo root: reconciler beside the lib wins over the recorded root" "$STAGED" "$(repo_root_of)"
assert_eq "repo root: real checkout" "$TL_REPO_ROOT" "$(bash -c 'source "$1/common.sh"; _rt_repo_root' _ "$RTLIB")"

# rt_init_paths defaults RT_REPO_ROOT when unset
assert_eq "init paths derives RT_REPO_ROOT" "$TL_REPO_ROOT|$TL_REPO_ROOT/hooks/lib" \
  "$(env -u RT_REPO_ROOT bash -c 'source "$1/common.sh"; rt_init_paths; printf "%s|%s" "$RT_REPO_ROOT" "$RT_HOOKS_LIB"' _ "$RTLIB")"
# a repo root without hook libs sources nothing and still succeeds
EMPTY_ROOT="$TL_TMP/empty-root"; mkdir -p "$EMPTY_ROOT"
assert_eq "init paths tolerates missing hook libs" "$EMPTY_ROOT/hooks/lib" \
  "$(RT_REPO_ROOT="$EMPTY_ROOT" bash -c 'source "$1/common.sh"; rt_init_paths; printf "%s" "$RT_HOOKS_LIB"' _ "$RTLIB")"

# ----------------------------------------------------- project config / consent
unset RT_PROJECT_ROOT
assert_eq "no RT_PROJECT_ROOT -> no config" "1" "$(rc_of rt_project_config)"
export RT_PROJECT_ROOT="$PROJ"
rm -f "$PROJ/.silver-bullet.json"
assert_eq "root without config -> no config" "1" "$(rc_of rt_project_config)"
assert_eq "consent defaults to pending without config" "pending" "$(rt_consent_for graphify)"
assert_eq "suspension is false without config" "1" "$(rc_of rt_is_suspended graphify)"
cfg '{"recommended_tools":{"graphify":{"enabled_by_user":true,"enforcement_suspended":true},"rtk":{"enabled_by_user":true},"leanctx":{"enabled_by_user":false}}}'
assert_eq "config path resolved" "$PROJ/.silver-bullet.json" "$(rt_project_config)"
assert_eq "consent enabled" "enabled" "$(rt_consent_for rtk)"
assert_eq "consent disabled" "disabled" "$(rt_consent_for leanctx)"
assert_eq "consent pending when unset" "pending" "$(rt_consent_for context_mode)"
assert_eq "suspended tool" "0" "$(rc_of rt_is_suspended graphify)"
assert_eq "non-suspended tool" "1" "$(rc_of rt_is_suspended rtk)"

# ------------------------------------------------------------------ hosts
for h in cursor claude codex opencode pi goose hermes; do
  assert_eq "valid host $h" "0" "$(rc_of rt_validate_host "$h")"
done
assert_eq "invalid host" "1" "$(rc_of rt_validate_host emacs)"
assert_eq "empty host invalid" "1" "$(rc_of rt_validate_host "")"
for h in cursor claude codex opencode pi; do
  assert_eq "host supported $h" "0" "$(rc_of rt_host_supported "$h")"
  assert_eq "five-tool host supported $h" "0" "$(rc_of rt_five_tool_host_supported "$h")"
done
for h in goose hermes ""; do
  assert_eq "host unsupported '$h'" "1" "$(rc_of rt_host_supported "$h")"
  assert_eq "five-tool host unsupported '$h'" "1" "$(rc_of rt_five_tool_host_supported "$h")"
done

# MCP config paths
assert_eq "cursor mcp path" "$HOME/.cursor/mcp.json" "$(rt_host_mcp_config_path cursor)"
assert_eq "claude mcp path" "$HOME/.claude.json" "$(rt_host_mcp_config_path claude)"
assert_eq "codex mcp path via runtime helper" "$(sb_runtime_codex_home)/config.toml" "$(rt_host_mcp_config_path codex)"
assert_eq "codex mcp path fallback without the runtime helper" "$HOME/.codex/config.toml" \
  "$(unset -f sb_runtime_codex_home; rt_host_mcp_config_path codex)"
assert_eq "opencode mcp path" "$HOME/.config/opencode/opencode.json" "$(rt_host_mcp_config_path opencode)"
assert_eq "pi mcp path default" "$HOME/.pi/agent/extensions/silver-bullet-five-tool-stack/config.json" "$(rt_host_mcp_config_path pi)"
assert_eq "pi mcp path honours PI_CODING_AGENT_DIR" "/pi/dir/extensions/silver-bullet-five-tool-stack/config.json" \
  "$(PI_CODING_AGENT_DIR=/pi/dir rt_host_mcp_config_path pi)"
assert_eq "unknown host has no path" "1" "$(rc_of rt_host_mcp_config_path goose)"
assert_eq "host defaults to RT_HOST" "$HOME/.claude.json" "$(RT_HOST=claude rt_host_mcp_config_path)"
assert_eq "host defaults to cursor" "$HOME/.cursor/mcp.json" "$(env -u RT_HOST bash -c 'source "$1/common.sh"; rt_host_mcp_config_path' _ "$RTLIB")"

# server configured?
mkdir -p "$HOME/.cursor" "$HOME/.config/opencode" "$HOME/.pi/agent/extensions/silver-bullet-five-tool-stack"
CODEX_CFG="$(rt_host_mcp_config_path codex)"; mkdir -p "$(dirname "$CODEX_CFG")"
printf '{"mcpServers":{"graphify":{"command":"g"}}}\n' >"$HOME/.cursor/mcp.json"
printf '{"mcpServers":{"agentmemory":{}}}\n' >"$HOME/.claude.json"
printf '{"mcp":{"graphify":{}},"plugin":["context-mode@1.2"]}\n' >"$HOME/.config/opencode/opencode.json"
printf '{"servers":{"context_mode":{"enabled":true},"graphify":{"enabled":false}}}\n' >"$HOME/.pi/agent/extensions/silver-bullet-five-tool-stack/config.json"
printf '[mcp_servers.graphify]\ncommand = "g"\n[mcp_servers."a.b"]\n[mcp_servers.x.y]\n' >"$CODEX_CFG"
assert_eq "cursor server configured" "0" "$(rc_of rt_host_mcp_server_configured cursor graphify)"
assert_eq "cursor server absent" "1" "$(rc_of rt_host_mcp_server_configured cursor leanctx)"
assert_eq "claude server configured" "0" "$(rc_of rt_host_mcp_server_configured claude agentmemory)"
assert_eq "opencode mcp server configured" "0" "$(rc_of rt_host_mcp_server_configured opencode graphify)"
assert_eq "opencode mcp server absent" "1" "$(rc_of rt_host_mcp_server_configured opencode agentmemory)"
assert_eq "opencode context-mode via plugin entry" "0" "$(rc_of rt_host_mcp_server_configured opencode context-mode)"
printf '{"plugin":["file:///g/build/adapters/opencode/plugin.js"]}\n' >"$HOME/.config/opencode/opencode.json"
assert_eq "opencode context-mode via plugin path" "0" "$(rc_of rt_host_mcp_server_configured opencode context-mode)"
printf '{"mcp":{"user-context-mode":{}}}\n' >"$HOME/.config/opencode/opencode.json"
assert_eq "opencode context-mode via mcp entry" "0" "$(rc_of rt_host_mcp_server_configured opencode context-mode)"
printf '{"plugin":["other"]}\n' >"$HOME/.config/opencode/opencode.json"
assert_eq "opencode context-mode absent" "1" "$(rc_of rt_host_mcp_server_configured opencode context-mode)"
assert_eq "pi context-mode maps to context_mode" "0" "$(rc_of rt_host_mcp_server_configured pi context-mode)"
assert_eq "pi disabled server" "1" "$(rc_of rt_host_mcp_server_configured pi graphify)"
assert_eq "codex table configured" "0" "$(rc_of rt_host_mcp_server_configured codex graphify)"
assert_eq "codex dotted table does not match a prefix" "1" "$(rc_of rt_host_mcp_server_configured codex x)"
assert_eq "codex absent table" "1" "$(rc_of rt_host_mcp_server_configured codex leanctx)"
assert_eq "empty server name" "1" "$(rc_of rt_host_mcp_server_configured cursor "")"
assert_eq "host without a config path" "1" "$(rc_of rt_host_mcp_server_configured goose graphify)"
assert_eq "host without a matching reader" "1" "$(rt_host_mcp_config_path() { echo "$HOME/.goose.json"; }; touch "$HOME/.goose.json"; rc_of rt_host_mcp_server_configured goose graphify)"
rm -f "$HOME/.cursor/mcp.json"
ln -s "$HOME/.claude.json" "$HOME/.cursor/mcp.json"
assert_eq "symlinked config is refused" "1" "$(rc_of rt_host_mcp_server_configured cursor agentmemory)"
rm -f "$HOME/.cursor/mcp.json"
assert_eq "missing config" "1" "$(rc_of rt_host_mcp_server_configured cursor graphify)"

# -------------------------------------------------------------------- ids
assert_match "stable id is 16 hex chars" '^[0-9a-f]{16}$' "$(rt_stable_id /some/path)"
assert_eq "stable id is deterministic" "$(rt_stable_id /a)" "$(rt_stable_id /a)"
assert_eq "stable id differs per input" "1" "$([[ "$(rt_stable_id /a)" != "$(rt_stable_id /b)" ]] && echo 1 || echo 0)"
assert_eq "stable id of empty input fails" "1" "$(rc_of rt_stable_id "")"
NOSHASUM="$(tl_path_without shasum)"
assert_eq "stable id via sha256sum equals shasum's" "$(rt_stable_id /a)" "$(PATH="$NOSHASUM" rt_stable_id /a)"

assert_eq "git toplevel" "$PROJ" "$(rt_git_toplevel "$PROJ")"
mkdir -p "$PROJ/sub"
assert_eq "git toplevel from a subdirectory" "$PROJ" "$(rt_git_toplevel "$PROJ/sub")"
NOGIT="$TL_TMP/nogit"; mkdir -p "$NOGIT"
assert_eq "git toplevel outside a repo is empty" "" "$(rt_git_toplevel "$NOGIT")"
assert_eq "git toplevel defaults to RT_PROJECT_ROOT" "$PROJ" "$(rt_git_toplevel)"
assert_eq "main worktree root" "$PROJ" "$(rt_git_main_worktree_root "$PROJ")"
git -C "$PROJ" worktree add -q "$TL_TMP/wt" -b wt-branch
assert_eq "main worktree root from a linked worktree" "$PROJ" "$(rt_git_main_worktree_root "$TL_TMP/wt")"
assert_eq "main worktree root outside git fails" "1" "$(rc_of rt_git_main_worktree_root "$NOGIT")"
assert_eq "main worktree root defaults to RT_PROJECT_ROOT" "$PROJ" "$(rt_git_main_worktree_root)"
# worktree list unavailable: falls back to the toplevel
assert_eq "main worktree root falls back to toplevel when worktree list is empty" "$PROJ" \
  "$(git() { if [[ "$*" == *"worktree list"* ]]; then return 0; fi; command git "$@"; }; rt_git_main_worktree_root "$PROJ")"

assert_eq "worktree id of explicit root" "$(rt_stable_id "$PROJ")" "$(rt_worktree_id "$PROJ")"
assert_eq "worktree ids differ per worktree" "1" "$([[ "$(rt_worktree_id "$PROJ")" != "$(rt_worktree_id "$TL_TMP/wt")" ]] && echo 1 || echo 0)"
assert_eq "worktree id defaults to the git toplevel" "$(rt_stable_id "$PROJ")" "$(cd "$PROJ/sub" && RT_PROJECT_ROOT='' rt_worktree_id)"
assert_eq "worktree id outside git fails" "1" "$(cd "$NOGIT" && RT_PROJECT_ROOT='' rc_of rt_worktree_id)"
assert_eq "project id is the main worktree's id from any worktree" "$(rt_stable_id "$PROJ")" "$(RT_PROJECT_ROOT="$TL_TMP/wt" rt_project_id)"
assert_eq "project id outside git fails" "1" "$(RT_PROJECT_ROOT="$NOGIT" rc_of rt_project_id)"

# batch flag
assert_eq "batch inactive by default" "1" "$(rc_of rt_cross_tool_batch_active)"
assert_eq "batch active when RT_CROSS_TOOL_BATCH=1" "0" "$(RT_CROSS_TOOL_BATCH=1 rc_of rt_cross_tool_batch_active)"

# ------------------------------------------------------- JSON result helpers
assert_eq "evidence array: empty" "[]" "$(rt_evidence_json_array | jq -c .)"
assert_eq "evidence array: values (blanks dropped)" '["a b","c"]' "$(rt_evidence_json_array "a b" "" "c" | jq -c .)"
probe="$(rt_emit_probe_result graphify enabled ready full 1 ev1 ev2)"
assert_eq "probe result shape" '{"component":"graphify","consent":"enabled","canonical_state":"ready","activation_status":"full","evidence":["ev1","ev2"],"repairable":true,"actions":[],"failures":[]}' "$(jq -c . <<<"$probe")"
probe="$(rt_emit_probe_result rtk pending pending none 0)"
assert_eq "probe result: not repairable, no evidence" "false|[]" "$(jq -r '"\(.repairable)|\(.evidence)"' <<<"$probe" | tr -d ' \n')"
probe="$(RT_PROBE_EXTRA_JSON='{"extra":1,"repairable":true}' rt_emit_probe_result rtk enabled ready full 0 e)"
assert_eq "probe result: extra merged and overrides" "1|true" "$(jq -r '"\(.extra)|\(.repairable)"' <<<"$probe")"
probe="$(rt_emit_probe_result graphify enabled ready full)"
# shift 5 fails with <5 arguments, so nothing is consumed and every argument lands in the evidence
assert_eq "probe result: missing trailing arguments tolerated" 'graphify|false|["graphify","enabled","ready","full"]' "$(jq -r '"\(.component)|\(.repairable)|\(.evidence)"' <<<"$probe" | tr -d ' \n')"
assert_eq "derive: unsupported wins" "unsupported" "$(rt_derive_canonical_state 1 1 1 1 1 1 1 1)"
assert_eq "derive: disabled" "disabled" "$(rt_derive_canonical_state 0 1 1 1 1 1 1 1)"
assert_eq "derive: pending" "pending" "$(rt_derive_canonical_state 0 0 1 1 1 1 1 1)"
assert_eq "derive: suspended" "suspended" "$(rt_derive_canonical_state 0 0 0 1 1 1 1 1)"
assert_eq "derive: failed" "failed" "$(rt_derive_canonical_state 0 0 0 0 1 1 1 1)"
assert_eq "derive: reload_required" "reload_required" "$(rt_derive_canonical_state 0 0 0 0 0 1 1 1)"
assert_eq "derive: repairable" "repairable" "$(rt_derive_canonical_state 0 0 0 0 0 0 1 1)"
assert_eq "derive: ready" "ready" "$(rt_derive_canonical_state 0 0 0 0 0 0 0 1)"
assert_eq "derive: nothing set defaults to ready" "ready" "$(rt_derive_canonical_state)"

# ----------------------------------------------------------- authorization
auth() { # <mode> <entry> <scope> [project_root]
  local out rc=0
  out="$(RT_MODE="$1" RT_ENTRY_POINT="$2" RT_SCOPE="$3" RT_PROJECT_ROOT="${4-$PROJ}" bash -c 'source "$1/common.sh"; rt_validate_authorization; rc=$?; printf "%s|%s" "$rc" "$RT_AUTH_ERROR"' _ "$RTLIB")" || rc=$?
  printf '%s' "$out"
}
assert_eq "verify without entry point is fine" "0|" "$(auth verify "" all)"
assert_eq "verify with entry point fails closed" "1|entry-point supplied with mode=verify; fail closed" "$(auth verify init all)"
assert_eq "apply requires an entry point" "1|apply requires exactly one --entry-point" "$(auth apply "" all)"
assert_eq "apply rejects unknown entry points" "1|unknown entry-point: bogus" "$(auth apply bogus all)"
for e in init update doctor-fix; do
  assert_eq "$e accepts a valid scope" "0|" "$(auth apply "$e" host)"
  assert_eq "$e rejects an invalid scope" "1|$e scope must be project|host|packages|all" "$(auth apply "$e" weird)"
done
assert_eq "installer accepts host scope" "0|" "$(auth apply installer host)"
assert_eq "installer accepts packages scope" "0|" "$(auth apply installer packages)"
cfg '{}'
assert_eq "installer project scope with a canonical root" "0|" "$(auth apply installer project)"
assert_eq "installer all scope with a canonical root" "0|" "$(auth apply installer all)"
assert_eq "installer project scope needs a root" "1|installer scope project requires canonical project root" "$(auth apply installer project "")"
assert_eq "installer all scope needs a config in the root" "1|installer scope all requires canonical project root" "$(auth apply installer all "$NOGIT")"
assert_eq "installer rejects unknown scope" "1|installer scope must be host|packages|project|all" "$(auth apply installer weird)"

# scope -> component membership
scope_has() { RT_SCOPE="$1" rc_of rt_scope_includes_component "$2"; }
for c in graphify agentmemory rtk context_mode leanctx alumnium search_cli cross_tool; do
  assert_eq "scope all includes $c" "0" "$(scope_has all "$c")"
done
assert_eq "default scope is all" "0" "$(env -u RT_SCOPE bash -c 'source "$1/common.sh"; rt_scope_includes_component rtk && echo 0' _ "$RTLIB")"
for c in graphify agentmemory cross_tool; do assert_eq "project scope includes $c" "0" "$(scope_has project "$c")"; done
for c in rtk context_mode leanctx alumnium search_cli; do assert_eq "project scope excludes $c" "1" "$(scope_has project "$c")"; done
for c in rtk context_mode leanctx alumnium cross_tool; do assert_eq "host scope includes $c" "0" "$(scope_has host "$c")"; done
for c in graphify agentmemory search_cli; do assert_eq "host scope excludes $c" "1" "$(scope_has host "$c")"; done
for c in graphify agentmemory rtk context_mode leanctx alumnium search_cli; do assert_eq "packages scope includes $c" "0" "$(scope_has packages "$c")"; done
assert_eq "packages scope excludes cross_tool" "1" "$(scope_has packages cross_tool)"
assert_eq "unknown scope includes nothing" "1" "$(scope_has weird rtk)"

# ------------------------------------------------------------ mutation gate
cfg '{"recommended_tools":{"graphify":{"enabled_by_user":true},"rtk":{"enabled_by_user":true,"enforcement_suspended":true},"leanctx":{"enabled_by_user":false}}}'
mut() { RT_MODE="$1" RT_ENTRY_POINT="${2:-}" RT_SCOPE=all rc_of rt_mutation_allowed "$3"; }
assert_eq "mutation: verify mode never mutates" "1" "$(mut verify "" graphify)"
assert_eq "mutation: apply without entry point denied" "1" "$(mut apply "" graphify)"
assert_eq "mutation: apply with consent allowed" "0" "$(mut apply init graphify)"
assert_eq "mutation: apply without consent denied" "1" "$(mut apply init leanctx)"
assert_eq "mutation: apply with pending consent denied" "1" "$(mut apply init context_mode)"
assert_eq "mutation: suspended tool denied" "1" "$(mut apply init rtk)"
anym() { RT_MODE=apply RT_ENTRY_POINT=init RT_SCOPE=all rc_of rt_any_five_tool_mutation_allowed; }
assert_eq "any mutation allowed when one tool is consented" "0" "$(anym)"
cfg '{"recommended_tools":{"graphify":{"enabled_by_user":false}}}'
assert_eq "no mutation allowed when none consented" "1" "$(anym)"

# --------------------------------------------------------- atomic write / lock
D="$TL_TMP/atomic"
rt_atomic_write_json "$D/sub/out.json" '{"a":1}'
assert_eq "atomic write creates parents and content" '{"a":1}' "$(cat "$D/sub/out.json")"
rt_atomic_write_json "$D/sub/out.json" '{"a":2}'
assert_eq "atomic write replaces" '{"a":2}' "$(cat "$D/sub/out.json")"
assert_eq "atomic write leaves no temp files" "out.json" "$(ls -A "$D/sub")"
assert_eq "atomic write needs a destination" "1" "$(rc_of rt_atomic_write_json "" x)"
assert_eq "atomic write needs content" "1" "$(rc_of rt_atomic_write_json "$D/none.json" "")"
printf 'file\n' >"$D/blocker"
assert_eq "atomic write fails when the directory cannot be created" "1" "$(rc_of rt_atomic_write_json "$D/blocker/sub/out.json" '{}')"
ln -s "$D/sub/out.json" "$D/link.json"
assert_eq "atomic write refuses a symlink destination" "1" "$(rc_of rt_atomic_write_json "$D/link.json" '{"x":1}')"
assert_eq "symlink target untouched" '{"a":2}' "$(cat "$D/sub/out.json")"

L="$TL_TMP/locks/job.lock"
assert_eq "lock requires a path" "1" "$(rc_of rt_with_lock "" 1 true)"
OUT="$(rt_with_lock "$L" 5 printf 'ran:%s' "arg")"
assert_eq "lock runs the command" "ran:arg" "$OUT"
assert_file_absent "lock released after the command" "$L"
rc=0; rt_with_lock "$L" 5 false || rc=$?
assert_eq "lock propagates the command's status" "1" "$rc"
assert_file_absent "lock released after a failing command" "$L"
mkdir -p "$L"
tl_stub sleep 'exit 0'
tl_stub date 'if [[ "$1" == "+%s" ]]; then n=$(cat "$DATE_STATE" 2>/dev/null || echo 100); echo "$n"; echo $((n + 20)) >"$DATE_STATE"; else /bin/date "$@"; fi'
export DATE_STATE="$TL_TMP/date-state"
rm -f "$DATE_STATE"
rc=0; rt_with_lock "$L" 5 true || rc=$?
assert_eq "a held lock times out" "1" "$rc"
assert_file_exists "a lock held by someone else is left alone" "$L"
rm -f "$DATE_STATE"
rc=0; rt_with_lock "$D/blocker/locks/x.lock" 5 true || rc=$?
assert_eq "an uncreatable lock directory times out" "1" "$rc"
rm -f "$TL_BIN/date" "$TL_BIN/sleep"; rmdir "$L"

# held lock released by another process while we wait
mkdir -p "$L"
tl_stub sleep 'rmdir "$LOCK_TO_DROP" 2>/dev/null; exit 0'
export LOCK_TO_DROP="$L"
OUT="$(rt_with_lock "$L" 5 printf 'after-wait')"
assert_eq "waiting for a held lock then running" "after-wait" "$OUT"
rm -f "$TL_BIN/sleep"

# ---------------------------------------------------------------- paths.sh
unset SB_RUNTIME_STATE_DIR
assert_eq "state root defaults under HOME" "$HOME/.silver-bullet/recommended-tools" "$(rt_state_root)"
export SB_RUNTIME_STATE_DIR="$TL_TMP/state"
assert_eq "state root follows the runtime state dir" "$TL_TMP/state/recommended-tools" "$(rt_state_root)"
assert_eq "heartbeat root" "$TL_TMP/state/recommended-tools/heartbeats" "$(rt_heartbeat_root)"
assert_eq "heartbeat dir" "$TL_TMP/state/recommended-tools/heartbeats/p/w" "$(rt_heartbeat_dir p w)"
assert_eq "heartbeat dir needs both ids" "1" "$(rc_of rt_heartbeat_dir p "")"
assert_eq "heartbeat dir needs a project id" "1" "$(rc_of rt_heartbeat_dir "" w)"
assert_eq "sanitize: empty -> fallback" "unknown" "$(rt_sanitize_path_segment "")"
assert_eq "sanitize: empty -> custom fallback" "zzz" "$(rt_sanitize_path_segment "" zzz)"
assert_eq "sanitize: safe value kept" "ok-1.2_x" "$(rt_sanitize_path_segment "ok-1.2_x")"
hashed="$(rt_sanitize_path_segment "../etc/passwd" unknown pfx)"
assert_match "sanitize: unsafe value hashed with prefix" '^pfx-[0-9a-f]{16}$' "$hashed"
assert_eq "sanitize: dotdot hashed" "$hashed" "$(rt_sanitize_path_segment "../etc/passwd" unknown pfx)"
assert_match "sanitize: slash hashed" '^seg-[0-9a-f]{16}$' "$(rt_sanitize_path_segment "a/b")"
assert_match "sanitize: spaces hashed" '^seg-[0-9a-f]{16}$' "$(rt_sanitize_path_segment "a b")"
assert_eq "sanitize: sha256sum fallback hashes identically" "$hashed" "$(PATH="$NOSHASUM" rt_sanitize_path_segment "../etc/passwd" unknown pfx)"
NOHASH="$(tl_path_without shasum sha256sum)"
tl_stub date 'echo 1234567890'
assert_eq "sanitize: no hash tool -> timestamp fallback" "unknown-1234567890" "$(PATH="$TL_BIN:$NOHASH" rt_sanitize_path_segment "a b")"
rm -f "$TL_BIN/date"
assert_match "session id sanitizer prefix" '^sid-[0-9a-f]{16}$' "$(rt_sanitize_session_id "a b")"
assert_eq "session id empty -> unknown" "unknown" "$(rt_sanitize_session_id "")"
assert_eq "heartbeat path" "$TL_TMP/state/recommended-tools/heartbeats/p/w/s1.json" "$(rt_heartbeat_path p w s1)"
assert_eq "heartbeat path needs a session" "1" "$(rc_of rt_heartbeat_path p w "")"
assert_eq "heartbeat path needs a project id" "1" "$(rc_of rt_heartbeat_path "" w s)"
assert_eq "heartbeat path needs a worktree id" "1" "$(rc_of rt_heartbeat_path p "" s)"
assert_eq "heartbeat path prints nothing (never a path at the filesystem root) without ids" "" "$(rt_heartbeat_path "" "" s 2>/dev/null || true)"
assert_eq "reload receipt root" "$TL_TMP/state/recommended-tools/reload-receipts" "$(rt_reload_receipt_root)"
assert_eq "reload receipt host dir" "$TL_TMP/state/recommended-tools/reload-receipts/claude" "$(rt_reload_receipt_host_dir claude)"
assert_eq "reload receipt host dir defaults to cursor" "$TL_TMP/state/recommended-tools/reload-receipts/cursor" "$(rt_reload_receipt_host_dir)"
RR="$TL_TMP/state/recommended-tools/reload-receipts"
assert_eq "scope dir: project" "$RR/cursor/p/w" "$(rt_reload_receipt_scope_dir cursor p w project)"
assert_eq "scope dir: default scope is project" "$RR/cursor/p/w" "$(rt_reload_receipt_scope_dir cursor p w)"
assert_eq "scope dir: missing ids fall back to 'unknown' segments" "$RR/cursor/unknown/unknown" "$(rt_reload_receipt_scope_dir cursor "" "" project)"
assert_eq "scope dir: host-global" "$RR/cursor/_host-global/_host-global" "$(rt_reload_receipt_scope_dir cursor "" "" host-global)"
assert_eq "scope dir: host" "$RR/cursor/_host-global/wt1" "$(rt_reload_receipt_scope_dir cursor "" wt1 host)"
assert_eq "scope dir: host without worktree" "$RR/cursor/_host-global/_host-global" "$(rt_reload_receipt_scope_dir cursor "" "" host)"
assert_eq "scope dir: unknown scope behaves as project" "$RR/cursor/p/w" "$(rt_reload_receipt_scope_dir cursor p w whatever)"
assert_eq "receipt path" "$RR/cursor/p/w/r1.json" "$(rt_reload_receipt_path cursor p w r1)"
assert_eq "receipt path: a missing id falls back to 'unknown'" "$RR/cursor/p/w/unknown.json" "$(rt_reload_receipt_path cursor p w "")"
assert_eq "receipt path (host scope)" "$RR/codex/_host-global/w/r1.json" "$(rt_reload_receipt_path codex "" w r1 host)"
assert_match "receipt path sanitizes traversal in the id" "^$RR/cursor/p/w/seg-[0-9a-f]{16}\\.json\$" "$(rt_reload_receipt_path cursor p w ../../x)"
assert_eq "receipt lock dir" "$RR/cursor/p/w/.lock" "$(rt_reload_receipt_lock_dir cursor p w)"
assert_eq "receipt lock dir (host-global)" "$RR/cursor/_host-global/_host-global/.lock" "$(rt_reload_receipt_lock_dir cursor "" "" host-global)"

# resolve a lib script
rm -rf "$TL_TMP/res"; mkdir -p "$TL_TMP/res/proj/scripts/lib" "$TL_TMP/res/plug/scripts/lib" "$TL_TMP/res/rtrepo/scripts/lib" "$TL_TMP/res/repo/scripts/lib" "$TL_TMP/res/up/a/b" "$TL_TMP/res/up/scripts/lib"
for d in proj plug rtrepo repo up; do printf '%s\n' "$d" >"$TL_TMP/res/$d/scripts/lib/x.py"; done
res() { env -u RT_PROJECT_ROOT -u CLAUDE_PLUGIN_ROOT -u RT_REPO_ROOT -u REPO_ROOT "$@" bash -c 'source "$1/paths.sh"; shift; rt_resolve_lib_script x.py "$@"' _ "$RTLIB" "${RES_PROJECT:-}"; }
assert_eq "resolve: project root wins" "$TL_TMP/res/proj/scripts/lib/x.py" "$(RES_PROJECT="$TL_TMP/res/proj" res CLAUDE_PLUGIN_ROOT="$TL_TMP/res/plug" RT_REPO_ROOT="$TL_TMP/res/rtrepo" REPO_ROOT="$TL_TMP/res/repo")"
assert_eq "resolve: plugin root next" "$TL_TMP/res/plug/scripts/lib/x.py" "$(RES_PROJECT="" res CLAUDE_PLUGIN_ROOT="$TL_TMP/res/plug" RT_REPO_ROOT="$TL_TMP/res/rtrepo" REPO_ROOT="$TL_TMP/res/repo")"
assert_eq "resolve: RT_REPO_ROOT next" "$TL_TMP/res/rtrepo/scripts/lib/x.py" "$(RES_PROJECT="" res RT_REPO_ROOT="$TL_TMP/res/rtrepo" REPO_ROOT="$TL_TMP/res/repo")"
assert_eq "resolve: REPO_ROOT next" "$TL_TMP/res/repo/scripts/lib/x.py" "$(RES_PROJECT="" res REPO_ROOT="$TL_TMP/res/repo")"
assert_eq "resolve: walks up from the project root" "$TL_TMP/res/up/scripts/lib/x.py" "$(RES_PROJECT="$TL_TMP/res/up/a/b" res)"
assert_eq "resolve: nothing found fails" "1" "$(RES_PROJECT="$TL_TMP/res/up/a/b" rc_of bash -c 'cd /; source "$1/paths.sh"; rt_resolve_lib_script nope.py "$2"' _ "$RTLIB" "$TL_TMP/res/up/a/b")"
assert_eq "resolve: relative path required" "1" "$(rc_of bash -c 'source "$1/paths.sh"; rt_resolve_lib_script ""' _ "$RTLIB")"
assert_eq "resolve: project root via RT_PROJECT_ROOT" "$TL_TMP/res/proj/scripts/lib/x.py" "$(env -u CLAUDE_PLUGIN_ROOT RT_PROJECT_ROOT="$TL_TMP/res/proj" bash -c 'source "$1/paths.sh"; rt_resolve_lib_script x.py' _ "$RTLIB")"

tl_results
