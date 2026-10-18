#!/usr/bin/env bash
# scripts/lib/recommended-tools/{heartbeat,session-verify,vendor-doctor,installer}.sh:
# bridge heartbeats, the SessionStart drift report, bounded vendor `doctor` runs
# and the installer's reconciler deployment. Libraries are sourced in-process;
# reconcilers, vendor CLIs and timeouts are stubs inside the sandboxed HOME.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

RTLIB="$TL_REPO_ROOT/scripts/lib/recommended-tools"
export RT_REPO_ROOT="$TL_REPO_ROOT"
REAL_DATE="$(command -v date)"
export REAL_DATE

PROJ="$TL_TMP/proj"
tl_git_repo "$PROJ"
printf '{"sb_initiated":true,"recommended_tools":{"graphify":{"enabled_by_user":true},"rtk":{"enabled_by_user":false}}}\n' >"$PROJ/.silver-bullet.json"
export RT_PROJECT_ROOT="$PROJ"
export SILVER_BULLET_SESSION_ID="sess-1"

# shellcheck source=/dev/null
source "$RTLIB/heartbeat.sh"
rc_of() { local rc=0; "$@" >/dev/null 2>&1 || rc=1; printf '%s' "$rc"; }

# ------------------------------------------------------------- session ids
assert_eq "session id from SILVER_BULLET_SESSION_ID" "sess-1" "$(rt_current_session_id)"
assert_eq "session id from CURSOR_SESSION_ID" "cur-9" "$(SILVER_BULLET_SESSION_ID= CURSOR_SESSION_ID=cur-9 rt_current_session_id)"
printf '1700000000' >"$SB_RUNTIME_STATE_DIR/session-start-time"
assert_eq "session id from the session-start marker" "sb-1700000000" "$(SILVER_BULLET_SESSION_ID= CURSOR_SESSION_ID= rt_current_session_id)"
rm -f "$SB_RUNTIME_STATE_DIR/session-start-time"
assert_match "session id fallback is unknown-<epoch>" '^unknown-[0-9]+$' "$(SILVER_BULLET_SESSION_ID= CURSOR_SESSION_ID= rt_current_session_id)"
assert_match "unsafe session ids are hashed" '^sid-[0-9a-f]{16}$' "$(SILVER_BULLET_SESSION_ID='a/../b' rt_current_session_id)"
# the marker file exists but cannot be read -> falls through to unknown-*
assert_eq "empty marker still yields an sb- id" "sb-" "$(: >"$SB_RUNTIME_STATE_DIR/session-start-time"; SILVER_BULLET_SESSION_ID= CURSOR_SESSION_ID= rt_current_session_id)"
rm -f "$SB_RUNTIME_STATE_DIR/session-start-time"

# ------------------------------------------------------------ consent summary
assert_eq "consent summary" '{"graphify":"enabled","agentmemory":"pending","rtk":"disabled","context_mode":"pending","leanctx":"pending"}' "$(rt_heartbeat_consent_summary)"
assert_eq "consent summary without a config" "{}" "$(RT_PROJECT_ROOT= rt_heartbeat_consent_summary)"

# --------------------------------------------------------------- build json
hb="$(rt_heartbeat_build_json "$PROJ" claude)"
assert_eq "heartbeat schema" "v1" "$(jq -r .schema <<<"$hb")"
assert_eq "heartbeat host" "claude" "$(jq -r .host <<<"$hb")"
assert_eq "heartbeat roots" "$PROJ|$PROJ" "$(jq -r '"\(.project_root)|\(.worktree_root)"' <<<"$hb")"
assert_eq "heartbeat ids" "$(rt_stable_id "$PROJ")|$(rt_stable_id "$PROJ")" "$(jq -r '"\(.project_id)|\(.worktree_id)"' <<<"$hb")"
assert_eq "heartbeat session" "sess-1" "$(jq -r .session_id <<<"$hb")"
assert_eq "heartbeat bridge version" "$RT_RECONCILER_VERSION" "$(jq -r .bridge_version <<<"$hb")"
assert_eq "heartbeat initiated and not suspended" "true|false" "$(jq -r '"\(.sb_initiated)|\(.suspended)"' <<<"$hb")"
assert_eq "heartbeat consent embedded" "enabled" "$(jq -r .consent.graphify <<<"$hb")"
assert_match "heartbeat written_at format" '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$' "$(jq -r .written_at <<<"$hb")"
delta=$(( $("$REAL_DATE" -u -d "$(jq -r .expires_at <<<"$hb")" +%s) - $("$REAL_DATE" -u -d "$(jq -r .written_at <<<"$hb")" +%s) ))
assert_eq "heartbeat TTL is 300s" "300" "$delta"
hb="$(rt_heartbeat_build_json "" "")"
assert_eq "defaults: host falls back to RT_HOST/cursor" "cursor" "$(env -u RT_HOST bash -c 'source "$1/heartbeat.sh" 2>/dev/null; rt_heartbeat_build_json "" "" | jq -r .host' _ "$RTLIB")"
assert_eq "defaults: project root from RT_PROJECT_ROOT config" "true" "$(jq -r .sb_initiated <<<"$hb")"

# suspended tool anywhere marks the heartbeat suspended
printf '{"sb_initiated":true,"recommended_tools":{"leanctx":{"enabled_by_user":true,"enforcement_suspended":true}}}\n' >"$PROJ/.silver-bullet.json"
assert_eq "suspended flag" "true" "$(rt_heartbeat_build_json "$PROJ" cursor | jq -r .suspended)"
# unreadable config -> sb_initiated falls back to false
printf 'not json\n' >"$PROJ/.silver-bullet.json"
assert_eq "invalid config -> not initiated" "false" "$(rt_heartbeat_build_json "$PROJ" cursor | jq -r .sb_initiated)"
# no config at all
rm -f "$PROJ/.silver-bullet.json"
NOCFG="$TL_TMP/nocfg"; mkdir -p "$NOCFG"
assert_eq "no config -> not initiated" "false" "$(RT_PROJECT_ROOT="$NOCFG" rt_heartbeat_build_json "$NOCFG" cursor | jq -r .sb_initiated)"
assert_eq "no config and no root -> not initiated" "false" "$(RT_PROJECT_ROOT= rt_heartbeat_build_json "" cursor | jq -r .sb_initiated)"
# git-less root: no project id, but the worktree id is still derived from the given root
assert_eq "ids fall back to unknown" "unknown|$(rt_stable_id "$NOCFG")" "$(RT_PROJECT_ROOT="$NOCFG" rt_heartbeat_build_json "$NOCFG" cursor | jq -r '"\(.project_id)|\(.worktree_id)"')"
printf '{"sb_initiated":true,"recommended_tools":{"graphify":{"enabled_by_user":true}}}\n' >"$PROJ/.silver-bullet.json"

# expiry computed without GNU/BSD date extensions
tl_stub date '
for a in "$@"; do [[ "$a" == -v* || "$a" == -d ]] && exit 1; done
exec "$REAL_DATE" "$@"'
hb="$(rt_heartbeat_build_json "$PROJ" cursor)"
assert_eq "expiry falls back to 'now' when date cannot add" "$(jq -r .written_at <<<"$hb")" "$(jq -r .expires_at <<<"$hb")"
rm -f "$TL_BIN/date"

# ------------------------------------------------------------ last write / cadence
HB_FILE="$TL_TMP/hb.json"
printf '{"written_at":"2020-01-01T00:00:00Z"}\n' >"$HB_FILE"
assert_eq "last write epoch" "1577836800" "$(rt_heartbeat_last_write_epoch "$HB_FILE")"
assert_eq "last write: missing file" "1" "$(rc_of rt_heartbeat_last_write_epoch "$TL_TMP/none.json")"
ln -s "$HB_FILE" "$TL_TMP/hb-link.json"
assert_eq "last write: symlink refused" "1" "$(rc_of rt_heartbeat_last_write_epoch "$TL_TMP/hb-link.json")"
printf '{}\n' >"$TL_TMP/hb-empty.json"
assert_eq "last write: no timestamp" "1" "$(rc_of rt_heartbeat_last_write_epoch "$TL_TMP/hb-empty.json")"
printf '{"written_at":"garbage"}\n' >"$TL_TMP/hb-bad.json"
assert_eq "last write: unparsable timestamp" "1" "$(rc_of rt_heartbeat_last_write_epoch "$TL_TMP/hb-bad.json")"
assert_eq "cadence due: no file" "0" "$(rc_of rt_heartbeat_cadence_due "$TL_TMP/none.json")"
assert_eq "cadence due: old write" "0" "$(rc_of rt_heartbeat_cadence_due "$HB_FILE")"
assert_eq "cadence due: unparsable timestamp counts as old" "0" "$(rc_of rt_heartbeat_cadence_due "$TL_TMP/hb-bad.json")"
printf '{"written_at":"%s"}\n' "$("$REAL_DATE" -u +%Y-%m-%dT%H:%M:%SZ)" >"$TL_TMP/hb-fresh.json"
assert_eq "cadence not due: written just now" "1" "$(rc_of rt_heartbeat_cadence_due "$TL_TMP/hb-fresh.json")"

# ------------------------------------------------------------------ write
HB_PATH="$(rt_heartbeat_path "$(rt_project_id)" "$(rt_worktree_id "$PROJ")" "sess-1")"
rt_heartbeat_write "$PROJ" cursor
assert_file_exists "heartbeat written at the canonical path" "$HB_PATH"
assert_eq "written heartbeat is valid JSON for this host" "0" "$(rc_of rt_heartbeat_is_valid "$HB_PATH" cursor "$PROJ" "$PROJ")"
first="$(cat "$HB_PATH")"
printf '{"x":1}' >"$HB_PATH"
printf '{"written_at":"%s"}\n' "$("$REAL_DATE" -u +%Y-%m-%dT%H:%M:%SZ)" >"$HB_PATH"
rt_heartbeat_write "$PROJ" cursor
assert_contains "second write inside the cadence window is skipped" "$(cat "$HB_PATH")" '"written_at"'
assert_not_contains "skipped write leaves the file untouched" "$(cat "$HB_PATH")" '"schema"'
printf '%s\n' "$first" | jq '.written_at = "2020-01-01T00:00:00Z"' >"$HB_PATH"
rt_heartbeat_write "$PROJ" cursor
assert_eq "an old heartbeat is rewritten" "v1" "$(jq -r .schema "$HB_PATH")"
assert_eq "no lock directory left behind" "1" "$(rc_of test -e "$(dirname "$HB_PATH")/.lock")"

# ---------------------------------------------------------------- validity
good="$TL_TMP/good-hb.json"
future="$("$REAL_DATE" -u -d '+1 hour' +%Y-%m-%dT%H:%M:%SZ)"
past="$("$REAL_DATE" -u -d '-1 hour' +%Y-%m-%dT%H:%M:%SZ)"
mk() { jq -n --arg exp "$1" --argjson init "${2:-true}" --argjson susp "${3:-false}" --arg sid "${4-s}" \
  '{schema:"v1",host:"cursor",project_root:"/p",worktree_root:"/w",session_id:$sid,sb_initiated:$init,suspended:$susp,expires_at:$exp}' >"$good"; }
mk "$future"
assert_eq "valid heartbeat" "0" "$(rc_of rt_heartbeat_is_valid "$good" cursor /p /w)"
assert_eq "blank expectations match anything" "0" "$(rc_of rt_heartbeat_is_valid "$good" "" "" "")"
assert_eq "host mismatch" "1" "$(rc_of rt_heartbeat_is_valid "$good" codex /p /w)"
assert_eq "project mismatch" "1" "$(rc_of rt_heartbeat_is_valid "$good" cursor /other /w)"
assert_eq "worktree mismatch" "1" "$(rc_of rt_heartbeat_is_valid "$good" cursor /p /other)"
mk "$past"; assert_eq "expired heartbeat" "1" "$(rc_of rt_heartbeat_is_valid "$good" cursor /p /w)"
mk "$future" false; assert_eq "not sb-initiated" "1" "$(rc_of rt_heartbeat_is_valid "$good" cursor /p /w)"
mk "$future" true true; assert_eq "suspended" "1" "$(rc_of rt_heartbeat_is_valid "$good" cursor /p /w)"
mk "$future" true false ""; assert_eq "empty session id" "1" "$(rc_of rt_heartbeat_is_valid "$good" cursor /p /w)"
assert_eq "missing file" "1" "$(rc_of rt_heartbeat_is_valid "$TL_TMP/none.json" cursor /p /w)"
ln -sf "$good" "$TL_TMP/good-link.json"
assert_eq "symlink refused" "1" "$(rc_of rt_heartbeat_is_valid "$TL_TMP/good-link.json" cursor /p /w)"
# the schema check passes but the expiry is unreadable at the second read
mk "$future"
assert_eq "expiry is re-read separately" "1" "$(jq() { if [[ "${1:-}" == "-r" ]]; then echo ""; return 1; fi; command jq "$@"; }; rc_of rt_heartbeat_is_valid "$good" cursor /p /w)"

# ----------------------------------------------------------------- cleanup
HBR="$TL_TMP/hb-root"; mkdir -p "$HBR/a/b"
printf '{}' >"$HBR/a/b/old.json"; printf '{}' >"$HBR/a/b/new.json"; printf 'x' >"$HBR/a/b/keep.txt"
touch -d '3 days ago' "$HBR/a/b/old.json" "$HBR/a/b/keep.txt"
rt_heartbeat_cleanup_expired "$HBR"
assert_file_absent "expired heartbeat removed (GNU stat mtime)" "$HBR/a/b/old.json"
assert_file_exists "recent heartbeat kept" "$HBR/a/b/new.json"
assert_file_exists "non-json file untouched" "$HBR/a/b/keep.txt"
assert_eq "cleanup of a missing root is a no-op" "0" "$(rc_of rt_heartbeat_cleanup_expired "$TL_TMP/no-such-root")"
SB_RUNTIME_STATE_DIR="$TL_TMP/state-default"
mkdir -p "$(rt_heartbeat_root)/p/w"; printf '{}' >"$(rt_heartbeat_root)/p/w/old.json"; touch -d '2 days ago' "$(rt_heartbeat_root)/p/w/old.json"
rt_heartbeat_cleanup_expired
assert_file_absent "cleanup defaults to the heartbeat root" "$(rt_heartbeat_root)/p/w/old.json"
# BSD-style stat is used when -c is unavailable
mkdir -p "$HBR/c"; printf '{}' >"$HBR/c/old.json"; touch -d '3 days ago' "$HBR/c/old.json"
tl_stub stat 'if [[ "$1" == "-c" ]]; then exit 1; fi; if [[ "$1" == "-f" ]]; then echo 1; exit 0; fi; exit 1'
rt_heartbeat_cleanup_expired "$HBR"
assert_file_absent "BSD stat fallback used when -c fails" "$HBR/c/old.json"
tl_stub stat 'exit 1'
printf '{}' >"$HBR/c/unreadable.json"
rt_heartbeat_cleanup_expired "$HBR"
assert_file_absent "unreadable mtime counts as epoch 0 (expired)" "$HBR/c/unreadable.json"
rm -f "$TL_BIN/stat"

# ======================================================== session verify
# shellcheck source=/dev/null
source "$RTLIB/session-verify.sh"
SV="$TL_TMP/sv"; SVP="$SV/project"; mkdir -p "$SVP/scripts"
printf '{}\n' >"$SVP/.silver-bullet.json"
cat >"$SVP/scripts/reconcile-recommended-tools.sh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${RECON_LOG:-/dev/null}"
printf '%s' "${RECON_JSON:-}"
exit "${RECON_RC:-0}"
EOF
export RECON_LOG="$TL_TMP/recon.log"
json() { # components json array
  printf '{"components":%s,"restart_required":%s}' "$1" "${2:-false}"
}
ALLREADY='[{"component":"graphify","canonical_state":"ready","activation_status":"full"},{"component":"cross_tool","canonical_state":"ready","activation_status":"full","evidence":[]}]'
sv() { RECON_JSON="$1" rt_session_verify_block "${2-$SVP}" "${3-cursor}"; }
assert_eq "no project root -> silent" "" "$(sv "" "")"
assert_eq "no config -> silent" "" "$(sv "" "$SV")"
assert_eq "healthy report -> silent" "" "$(sv "$(json "$ALLREADY")")"
assert_contains "reconciler invoked read-only for the project and host" "$(cat "$RECON_LOG")" "--project-root $SVP --host cursor --mode verify --scope all --format json"
assert_eq "empty reconciler output -> silent" "" "$(sv "")"
assert_eq "reconciler failure -> silent" "" "$(RECON_RC=3 sv "")"
assert_eq "ok-ish states need no action" "" "$(sv "$(json '[{"component":"a","canonical_state":"disabled"},{"component":"b","canonical_state":"pending"},{"component":"c","canonical_state":"unsupported"},{"component":"d","canonical_state":"mystery"}]')")"
out="$(sv "$(json '[{"component":"rtk","canonical_state":"suspended","activation_status":"none"},{"component":"graphify","canonical_state":"failed","activation_status":"partial"},{"component":"leanctx","canonical_state":"repairable","activation_status":"none"},{"component":"agentmemory","canonical_state":"reload_required","activation_status":"partial"}]')")"
assert_contains "heading" "$out" "**Recommended tools — verification only (SessionStart does not repair)**"
assert_contains "suspended line" "$out" "TOOLSTACK rtk: suspended (consent preserved) — retry via /sb:update or /sb:init"
assert_contains "failed line" "$out" "TOOLSTACK graphify: failed (activation=partial) — run /sb:doctor --fix or /sb:init"
assert_contains "repairable line" "$out" "TOOLSTACK leanctx: repairable (activation=none) — run /sb:doctor --fix or /sb:init"
assert_contains "reload_required line" "$out" "TOOLSTACK agentmemory: reload_required (activation=partial)"
assert_contains "fix paths footer" "$out" "Fix paths: /sb:init"
assert_contains "liveness footer" "$out" "CONFIGURED ≠ LIVE"
out="$(sv "$(json '[{"component":"cross_tool","canonical_state":"repairable","activation_status":"partial","evidence":[]}]')")"
assert_contains "cross-tool not ready" "$out" "TOOLSTACK routes: repairable (activation=partial) — run bash scripts/install-cursor.sh or /sb:doctor --fix=host"
out="$(sv "$(json '[{"component":"cross_tool","canonical_state":"ready","activation_status":"partial"}]')")"
assert_contains "cross-tool ready but not fully active" "$out" "TOOLSTACK routes: ready (activation=partial)"
out="$(sv "$(json '[{"component":"cross_tool","canonical_state":"ready","activation_status":"full","evidence":["heartbeat_absent_or_invalid"]}]')")"
assert_contains "cross-tool heartbeat invalid" "$out" "TOOLSTACK routes: ready (activation=full)"
out="$(sv "$(json "$ALLREADY" true)")"
assert_contains "restart required" "$out" "TOOLSTACK reload: MCP config changed"
out="$(sv "$(json '[{"component":"cross_tool","canonical_state":"failed"}]')")"
assert_contains "missing activation shows none" "$out" "TOOLSTACK routes: failed (activation=none)"
NOJQ="$(tl_path_without jq)"
assert_eq "jq missing -> silent" "" "$(PATH="$NOJQ" sv "$(json '[{"component":"x","canonical_state":"failed"}]')")"

# reconciler discovery
rm -rf "$SV/disc"; mkdir -p "$SV/disc/plain" "$SV/disc/rtroot/scripts" "$SV/disc/plugin/scripts" "$SV/disc/up/scripts" "$SV/disc/up/deep/er"
for d in plain "up/deep/er"; do printf '{}\n' >"$SV/disc/$d/.silver-bullet.json"; done
for d in rtroot plugin up; do cp "$SVP/scripts/reconcile-recommended-tools.sh" "$SV/disc/$d/scripts/"; done
FAILJSON="$(json '[{"component":"x","canonical_state":"failed","activation_status":"none"}]')"
: >"$RECON_LOG"
assert_eq "no reconciler anywhere -> silent" "" "$(cd /; env -u CLAUDE_PLUGIN_ROOT RT_REPO_ROOT= sv "$FAILJSON" "$SV/disc/plain")"
assert_eq "RT_REPO_ROOT reconciler used" "0" "$(RT_REPO_ROOT="$SV/disc/rtroot" sv "$FAILJSON" "$SV/disc/plain" | grep -c 'TOOLSTACK x: failed' | sed 's/^1$/0/')"
assert_contains "CLAUDE_PLUGIN_ROOT reconciler used" "$(RT_REPO_ROOT= CLAUDE_PLUGIN_ROOT="$SV/disc/plugin" sv "$FAILJSON" "$SV/disc/plain")" "TOOLSTACK x: failed"
assert_contains "ancestor directory reconciler used" "$(RT_REPO_ROOT= CLAUDE_PLUGIN_ROOT= sv "$FAILJSON" "$SV/disc/up/deep/er")" "TOOLSTACK x: failed"

# =========================================================== installer
# shellcheck source=/dev/null
source "$RTLIB/installer.sh"
IR="$TL_TMP/inst-repo"; rm -rf "$IR"
mkdir -p "$IR/scripts/lib/global-toolstack" "$IR/scripts/lib/recommended-tools" "$IR/scripts/lib/five_tool_runtime"
for f in common.sh shell-compression.sh graphify-gate.sh rtk-gate.sh record-graphify-query.sh; do printf '# %s\n' "$f" >"$IR/scripts/lib/global-toolstack/$f"; done
for f in five_tool_instances.py install-pi.py parity-verify.sh verify.sh; do printf '# %s\n' "$f" >"$IR/scripts/lib/global-toolstack/$f"; done
printf '# rt\n' >"$IR/scripts/lib/recommended-tools/probe-x.sh"; mkdir -p "$IR/scripts/lib/recommended-tools/subdir"
printf '# runtime\n' >"$IR/scripts/lib/five_tool_runtime/runtime.py"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >>"$RECON_LOG"\nprintf "%%s" "${RECON_OUT:-}"\nexit "${RECON_RC:-0}"\n' >"$IR/scripts/reconcile-recommended-tools.sh"
assert_eq "toolstack dir" "$HOME/.cursor/hooks/toolstack" "$(rt_installer_toolstack_dir)"
assert_eq "reconciler lib dir" "$HOME/.cursor/hooks/toolstack/lib/recommended-tools" "$(rt_installer_reconciler_lib_dir)"
assert_eq "deploy needs the toolstack sources" "1" "$(rc_of rt_deploy_toolstack_scripts "$TL_TMP/no-such-repo")"
rt_deploy_toolstack_scripts "$IR"
TS="$HOME/.cursor/hooks/toolstack"
assert_eq "common.sh lands in lib/" "# common.sh" "$(cat "$TS/lib/common.sh")"
assert_file_absent "common.sh not copied beside the gates" "$TS/common.sh"
assert_eq "gates copied" "# rtk-gate.sh" "$(cat "$TS/rtk-gate.sh")"
assert_eq "python helpers copied" "# install-pi.py" "$(cat "$TS/install-pi.py")"
assert_file_absent "missing sources skipped" "$TS/agentmemory-gate.sh"
assert_eq "gates executable" "0" "$(rc_of test -x "$TS/rtk-gate.sh")"
assert_eq "verify scripts executable" "0" "$(rc_of test -x "$TS/parity-verify.sh")"
assert_eq "generic runtime copied" "# runtime" "$(cat "$TS/lib/five_tool_runtime/runtime.py")"
rm -rf "$IR/scripts/lib/five_tool_runtime"
assert_eq "deploy without a generic runtime" "0" "$(rc_of rt_deploy_toolstack_scripts "$IR")"
# every copy fails when the destination is not a directory
rm -rf "$HOME/.cursor"; mkdir -p "$HOME/.cursor"; printf 'file\n' >"$HOME/.cursor/hooks"
assert_eq "deploy tolerates an unwritable toolstack" "0" "$(rc_of rt_deploy_toolstack_scripts "$IR")"
rm -rf "$HOME/.cursor"

assert_eq "snapshots need the reconciler libs" "1" "$(rc_of rt_deploy_reconciler_snapshots "$TL_TMP/no-such-repo")"
assert_eq "snapshots need a repo root" "1" "$(env -u RT_REPO_ROOT bash -c 'source "$1/installer.sh"; RT_REPO_ROOT=; rt_deploy_reconciler_snapshots' _ "$RTLIB" >/dev/null 2>&1; echo $?)"
rt_deploy_reconciler_snapshots "$IR"
assert_eq "repo root recorded" "$IR" "$(cat "$HOME/.cursor/state/toolstack/repo-root")"
assert_eq "reconciler snapshot deployed" "0" "$(rc_of test -x "$TS/reconcile-recommended-tools.sh")"
assert_eq "lib snapshot deployed" "# rt" "$(cat "$TS/lib/recommended-tools/probe-x.sh")"
assert_file_absent "directories inside the lib are not copied" "$TS/lib/recommended-tools/subdir"
rm -rf "$HOME/.cursor"; mkdir -p "$HOME/.cursor"; printf 'file\n' >"$HOME/.cursor/hooks"; printf 'file\n' >"$HOME/.cursor/state"
assert_eq "snapshots tolerate unwritable destinations" "0" "$(rc_of rt_deploy_reconciler_snapshots "$IR")"
rm -rf "$HOME/.cursor"

# project root resolution
IP="$TL_TMP/inst-proj"; tl_git_repo "$IP"; printf '{}\n' >"$IP/.silver-bullet.json"
assert_eq "explicit root with a config" "$IP" "$(rt_installer_resolve_project_root "$IP")"
assert_eq "root from SB_RECONCILE_PROJECT_ROOT" "$IP" "$(SB_RECONCILE_PROJECT_ROOT="$IP" rt_installer_resolve_project_root)"
assert_eq "root from the git toplevel of the cwd" "$IP" "$(mkdir -p "$IP/sub"; cd "$IP/sub" && rt_installer_resolve_project_root)"
assert_eq "no root outside an SB project" "1" "$(cd "$TL_TMP/nogit-x" 2>/dev/null || mkdir -p "$TL_TMP/nogit-x"; cd "$TL_TMP/nogit-x" && rc_of rt_installer_resolve_project_root "$TL_TMP/nogit-x")"
NOCFGGIT="$TL_TMP/git-nocfg"; tl_git_repo "$NOCFGGIT"
assert_eq "git root without a config is not a project" "1" "$(cd "$NOCFGGIT" && rc_of rt_installer_resolve_project_root)"

# run_reconcile argument plumbing
: >"$RECON_LOG"
assert_eq "run_reconcile: missing reconciler" "1" "$(rc_of rt_installer_run_reconcile "$TL_TMP/no-such-repo" "" host apply)"
rt_installer_run_reconcile "$IR" "$IP" all apply >/dev/null
assert_eq "run_reconcile: apply with a project" "--host cursor --mode apply --scope all --format text --entry-point installer --project-root $IP" "$(cat "$RECON_LOG")"
: >"$RECON_LOG"; rt_installer_run_reconcile "$IR" "$IP" project verify >/dev/null
assert_eq "run_reconcile: verify has no entry point" "--host cursor --mode verify --scope project --format text --project-root $IP" "$(cat "$RECON_LOG")"
: >"$RECON_LOG"; rt_installer_run_reconcile "$IR" "" host apply >/dev/null
assert_eq "run_reconcile: host scope needs no project" "--host cursor --mode apply --scope host --format text --entry-point installer" "$(cat "$RECON_LOG")"
: >"$RECON_LOG"; warn_out="$(rt_installer_run_reconcile "$IR" "" all apply 2>&1 >/dev/null)"
assert_contains "run_reconcile: project scope without a root degrades" "$warn_out" "WARN: installer reconcile scope=all requires project root — host infra only"
assert_eq "run_reconcile: degraded to host scope" "--host cursor --mode apply --scope host --format text --entry-point installer" "$(cat "$RECON_LOG")"
: >"$RECON_LOG"; rt_installer_run_reconcile "$IR" "" project verify >/dev/null 2>&1
assert_eq "run_reconcile: degraded verify has no entry point" "--host cursor --mode verify --scope host --format text" "$(cat "$RECON_LOG")"
assert_eq "run_reconcile: default repo root from RT_REPO_ROOT" "1" "$(RT_REPO_ROOT="$TL_TMP/no-such-repo" rc_of rt_installer_run_reconcile)"

# reload notice
assert_eq "no notice by default" "" "$(rt_emit_reload_notice)"
assert_eq "no notice when false" "" "$(rt_emit_reload_notice false)"
assert_contains "notice when true" "$(rt_emit_reload_notice true)" "RELOAD REQUIRED: Host MCP/hooks changed during install."
assert_contains "notice when 1" "$(rt_emit_reload_notice 1)" "Developer: Reload Window"

# post-install
export RT_SKIP_POST_INSTALL=1
assert_contains "post-install skip flag" "$(rt_installer_post_install "$IR" "$IP")" "SKIP: installer post-install reconcile (RT_SKIP_POST_INSTALL=1)"
unset RT_SKIP_POST_INSTALL
: >"$RECON_LOG"
out="$(SB_RT_APPLY_ACTIVE=1 rt_installer_post_install "$IR" "$IP")"
assert_contains "post-install inside apply" "$out" "SKIP: installer post-install reconcile (already inside reconcile apply)"
assert_eq "nothing reconciled inside apply" "" "$(cat "$RECON_LOG")"
out="$(RECON_OUT="RESTART_REQUIRED: yes" rt_installer_post_install "$IR" "$IP")"
assert_contains "post-install runs the reconciler" "$(cat "$RECON_LOG")" "--scope all"
assert_contains "restart notice printed" "$out" "RELOAD REQUIRED"
assert_not_contains "project given -> no pending note" "$out" "Project toolstack reconciliation pending"
: >"$RECON_LOG"
out="$(cd "$TL_TMP/nogit-x" && rt_installer_post_install "$IR" "")"
assert_contains "no project -> host scope" "$(cat "$RECON_LOG")" "--scope host"
assert_contains "pending note without a project" "$out" "Project toolstack reconciliation pending"
assert_not_contains "no restart -> no notice" "$out" "RELOAD REQUIRED"
out="$(cd "$IP" && rt_installer_post_install "$IR" "")"
assert_contains "project resolved from the cwd" "$(cat "$RECON_LOG")" "--project-root $IP"
rc=0; RECON_RC=9 rt_installer_post_install "$IR" "$IP" >/dev/null || rc=$?
assert_eq "reconciler status propagates" "9" "$rc"
assert_eq "re-entry guard is exported for descendants" "1" "$(env -u SB_RT_POST_INSTALL_ACTIVE bash -c 'source "$1/installer.sh"; rt_installer_post_install "$2" "$3" >/dev/null; echo "$SB_RT_POST_INSTALL_ACTIVE"' _ "$RTLIB" "$IR" "$IP")"

tl_results
