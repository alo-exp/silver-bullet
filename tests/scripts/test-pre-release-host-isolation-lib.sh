#!/usr/bin/env bash
# scripts/lib/pre-release-host-isolation.sh: smoke-root management, per-host isolation env,
# Cursor auth resolution, tag helpers and RC markers. Each case runs in a subshell.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude

LIB="$TL_REPO_ROOT/scripts/lib/pre-release-host-isolation.sh"
export TMPDIR="$TL_TMP/tmpdir"; mkdir -p "$TMPDIR"
unset SB_PRE_RELEASE_SMOKE_ROOT SB_PRE_RELEASE_REPO_ROOT SB_RC_PREVIOUS_TAG CURSOR_API_KEY HOST_API_KEY \
  _SB_PRE_RELEASE_ISOLATION_LOADED SB_RUNTIME_PRESERVE_STATE_DIR CURSOR_HOME CURSOR_CONFIG_DIR \
  AGENT_CLI_CREDENTIAL_STORE
REAL_HOME="$HOME"

# sub '<bash snippet>': run the snippet after sourcing the library, in a subshell.
# shellcheck source=../../scripts/lib/pre-release-host-isolation.sh
sub() { ( source "$LIB"; eval "$1" ); }

# --- load guard ---------------------------------------------------------------------------------
assert_eq "second source is a no-op (state kept)" "x" "$(sub 'sb_smoke_roots=(x); source "$LIB"; echo "${sb_smoke_roots[*]}"')"

# executed (not sourced) with the guard already set: `return` is invalid, so it exits 0
tl_run env _SB_PRE_RELEASE_ISOLATION_LOADED=1 bash "$LIB"
assert_eq "direct execution with guard set exits 0" 0 "$TL_STATUS"

# --- smoke root ---------------------------------------------------------------------------------------
r="$(sub 'sb_smoke_root')"
assert_match "default root is mktemp under TMPDIR" "^$TMPDIR/sb-pre-release-smoke\\.[A-Za-z0-9]+$" "$r"
assert_eq "root dir created" yes "$([[ -d "$r" ]] && echo yes || echo no)"
# the first call must run in the current shell (not a command substitution) to export the root
assert_eq "root is memoised and exported" "same" "$(sub 'sb_smoke_root >/dev/null; first="$SB_PRE_RELEASE_SMOKE_ROOT"; [[ "$(sb_smoke_root)" == "$first" && -d "$first" ]] && echo same || echo differ')"
assert_eq "preset root honoured" "$TL_TMP/preset" "$(SB_PRE_RELEASE_SMOKE_ROOT="$TL_TMP/preset" sub 'sb_smoke_root')"
SM="$TL_TMP/sm"
assert_eq "host root created" "$SM/h1" "$(SB_PRE_RELEASE_SMOKE_ROOT="$SM" sub 'sb_smoke_host_root h1')"
assert_file_exists "host root dir exists" "$SM/h1"

# --- tracking -------------------------------------------------------------------------------------------
assert_eq "track dedupes" "/a /b" "$(sub 'sb_smoke_track_root /a; sb_smoke_track_root /b; sb_smoke_track_root /a; echo "${sb_smoke_roots[*]}"')"

# --- per-host begin ------------------------------------------------------------------------------------------
env_dump='echo "HOME=$HOME"; echo "RT=$SILVER_BULLET_RUNTIME"; echo "PRESERVE=$SB_RUNTIME_PRESERVE_STATE_DIR"; echo "STATE=$SB_RUNTIME_STATE_DIR"'
for host in codex claude; do
  out="$(SB_PRE_RELEASE_SMOKE_ROOT="$SM" sub "sb_smoke_begin_$host; $env_dump; echo \"TRACKED=\${sb_smoke_roots[*]}\"")"
  assert_contains "$host: HOME isolated" "$out" "HOME=$SM/$host"
  assert_contains "$host: runtime pinned" "$out" "RT=$host"
  assert_contains "$host: state dir preserved" "$out" "STATE=$SM/$host/.silver-bullet"
  assert_contains "$host: preserve flag" "$out" "PRESERVE=1"
  assert_contains "$host: root tracked" "$out" "TRACKED=$SM/$host"
  # with a repo root the runtime-paths library is sourced; the preserved state dir still wins
  out="$(SB_PRE_RELEASE_REPO_ROOT="$TL_REPO_ROOT" SB_PRE_RELEASE_SMOKE_ROOT="$SM" sub "sb_smoke_begin_$host; $env_dump; echo \"NAME=\$SB_RUNTIME_NAME\"")"
  assert_contains "$host: runtime-paths sourced" "$out" "NAME=$host"
  assert_contains "$host: preserved state dir survives runtime-paths" "$out" "STATE=$SM/$host/.silver-bullet"
done
assert_contains "codex: CODEX_HOME_ROOT" "$(SB_PRE_RELEASE_SMOKE_ROOT="$SM" sub 'sb_smoke_begin_codex; echo "$CODEX_HOME_ROOT"')" "$SM/codex"

# --- cursor ----------------------------------------------------------------------------------------------------------
out="$(SB_PRE_RELEASE_REPO_ROOT="$TL_REPO_ROOT" SB_PRE_RELEASE_SMOKE_ROOT="$SM" CURSOR_HOME=/should/go sub "sb_smoke_begin_cursor; $env_dump"'; echo "CFG=$CURSOR_CONFIG_DIR"; echo "WS=$SB_SMOKE_CURSOR_WORKSPACE"; echo "PLUG=$SB_SMOKE_CURSOR_PLUGIN_DIR"; echo "FH=$SB_SMOKE_CURSOR_FAKE_HOME"; echo "CH=${CURSOR_HOME:-unset}"')"
assert_contains "cursor: fake home" "$out" "HOME=$SM/cursor/fake-home"
assert_contains "cursor: runtime" "$out" "RT=cursor"
assert_contains "cursor: state dir" "$out" "STATE=$SM/cursor/.silver-bullet"
assert_contains "cursor: config dir" "$out" "CFG=$SM/cursor/fake-home/.cursor"
assert_contains "cursor: workspace" "$out" "WS=$SM/cursor/workspace"
assert_contains "cursor: plugin dir from repo" "$out" "PLUG=$TL_REPO_ROOT/plugins/silver-bullet"
assert_contains "cursor: fake home var" "$out" "FH=$SM/cursor/fake-home"
assert_contains "cursor: CURSOR_HOME unset" "$out" "CH=unset"
assert_eq "cursor: hooks.json seeded" '{"version":1,"hooks":{}}' "$(cat "$SM/cursor/fake-home/.cursor/hooks.json")"
assert_eq "cursor: mcp.json seeded" '{"mcpServers":{}}' "$(cat "$SM/cursor/fake-home/.cursor/mcp.json")"
assert_eq "cursor: cli-config permissions" '["Shell(bash *)","Shell(echo *)","Shell(pwd)","Shell(test *)"]' "$(jq -c .permissions.allow "$SM/cursor/fake-home/.cursor/cli-config.json")"
assert_file_exists "cursor: workspace dir" "$SM/cursor/workspace"
out="$(SB_PRE_RELEASE_SMOKE_ROOT="$TL_TMP/sm2" sub 'sb_smoke_begin_cursor; echo "PLUG=[$SB_SMOKE_CURSOR_PLUGIN_DIR]"')"
assert_contains "cursor: no repo root -> empty plugin dir" "$out" "PLUG=[]"

# a read-only CURSOR_HOME cannot be unset; begin_cursor carries on
out="$(SB_PRE_RELEASE_SMOKE_ROOT="$SM" sub 'readonly CURSOR_HOME=/ro; sb_smoke_begin_cursor; echo "CH=$CURSOR_HOME"')"
assert_contains "readonly CURSOR_HOME tolerated" "$out" "CH=/ro"

# --- cursor helpers --------------------------------------------------------------------------------------------------------------
assert_eq "plugin dir: unset repo" 1 "$(sub 'sb_smoke_cursor_plugin_dir >/dev/null; echo $?' || true)"
mkdir -p "$TL_TMP/norepo"
assert_eq "plugin dir: repo without plugin" 1 "$(SB_PRE_RELEASE_REPO_ROOT="$TL_TMP/norepo" sub 'sb_smoke_cursor_plugin_dir >/dev/null; echo $?' || true)"
assert_eq "plugin dir: repo with plugin" "$TL_REPO_ROOT/plugins/silver-bullet" "$(SB_PRE_RELEASE_REPO_ROOT="$TL_REPO_ROOT" sub 'sb_smoke_cursor_plugin_dir')"
assert_eq "cursor workspace path" "$SM/cursor/workspace" "$(SB_PRE_RELEASE_SMOKE_ROOT="$SM" sub 'sb_smoke_cursor_workspace')"
assert_eq "cursor config dir path" "$SM/cursor/fake-home/.cursor" "$(SB_PRE_RELEASE_SMOKE_ROOT="$SM" sub 'sb_smoke_cursor_config_dir')"

# --- cursor auth ------------------------------------------------------------------------------------------------------------------------
auth() { # <env assignments...> -> "rc|key|store"
  # shellcheck disable=SC2163  # arguments are NAME=value pairs
  ( export "$@"
    # shellcheck source=../../scripts/lib/pre-release-host-isolation.sh
    source "$LIB"; rc=0; sb_smoke_cursor_cli_auth_env || rc=$?; echo "$rc|${CURSOR_API_KEY:-}|${AGENT_CLI_CREDENTIAL_STORE:-}" )
}
KH="$TL_TMP/keyhome"; mkdir -p "$KH/.silver-bullet"
assert_eq "auth: env key" "0|envkey|memory" "$(auth HOME="$KH" SB_PRE_RELEASE_SMOKE_ROOT="$SM" CURSOR_API_KEY=envkey)"
assert_eq "auth: HOST_API_KEY alias" "0|hostkey|memory" "$(auth HOME="$KH" SB_PRE_RELEASE_SMOKE_ROOT="$SM" HOST_API_KEY=hostkey)"
assert_eq "auth: none available" "1||memory" "$(auth HOME="$KH" SB_PRE_RELEASE_SMOKE_ROOT="$SM")"
echo homefilekey >"$KH/.silver-bullet/cursor-api-key"
assert_eq "auth: operator key file" "0|homefilekey|memory" "$(auth HOME="$KH" SB_PRE_RELEASE_SMOKE_ROOT="$SM")"
echo rootfilekey >"$SM/.cursor-api-key"
assert_eq "auth: smoke-root key file wins over operator file" "0|rootfilekey|memory" "$(auth HOME="$KH" SB_PRE_RELEASE_SMOKE_ROOT="$SM")"
assert_eq "auth: env beats files" "0|envkey|memory" "$(auth HOME="$KH" SB_PRE_RELEASE_SMOKE_ROOT="$SM" CURSOR_API_KEY=envkey)"

# --- cleanup --------------------------------------------------------------------------------------------------------------------------------
CL="$TL_TMP/cl"; mkdir -p "$CL/a" "$CL/b" "$TL_TMP/extra-root"
res="$(SB_PRE_RELEASE_SMOKE_ROOT="$CL" sub 'sb_smoke_roots=("$CL/a" "$CL/b"); sb_smoke_cleanup; echo "root=${SB_PRE_RELEASE_SMOKE_ROOT:-unset}"')"
assert_contains "cleanup: unsets the root var" "$res" "root=unset"
assert_file_absent "cleanup: root removed" "$CL"
res="$(SB_PRE_RELEASE_SMOKE_ROOT="$TL_TMP/missing-root" sub 'sb_smoke_cleanup; echo done-no-roots')"
assert_contains "cleanup: no tracked roots, missing root dir" "$res" "done-no-roots"
mkdir -p "$TL_TMP/tracked-only"
sub 'sb_smoke_roots=("$TL_TMP/tracked-only"); sb_smoke_cleanup'
assert_file_absent "cleanup: tracked root removed without root var" "$TL_TMP/tracked-only"

# rm failing (stubbed): cleanup is best-effort and still unsets the root variable
mkdir -p "$TL_TMP/rmfail/a"
tl_stub rm 'exit 1'; hash -r
res="$(SB_PRE_RELEASE_SMOKE_ROOT="$TL_TMP/rmfail" sub 'sb_smoke_roots=("$TL_TMP/rmfail/a"); sb_smoke_cleanup; echo "root=${SB_PRE_RELEASE_SMOKE_ROOT:-unset}"')"
rm_stub="$TL_BIN/rm"; /bin/rm -f "$rm_stub"; hash -r
assert_contains "cleanup tolerates rm failures" "$res" "root=unset"
assert_file_exists "cleanup with failing rm leaves the dirs" "$TL_TMP/rmfail/a"

# --- previous tag / checkout ---------------------------------------------------------------------------------------------------------------------
assert_eq "previous tag: env override" "v9.9.9" "$(SB_RC_PREVIOUS_TAG=v9.9.9 sub 'sb_smoke_resolve_previous_tag')"
assert_eq "previous tag: no repo -> 1" 1 "$(sub 'sb_smoke_resolve_previous_tag >/dev/null; echo $?' || true)"
GR="$TL_TMP/gr"; tl_git_repo "$GR"
git -C "$GR" tag v1.0.0; git -C "$GR" tag v1.10.0; git -C "$GR" tag v1.2.0
assert_eq "previous tag: second newest by version sort" "v1.2.0" "$(SB_PRE_RELEASE_REPO_ROOT="$GR" sub 'sb_smoke_resolve_previous_tag')"
git -C "$GR" tag -d v1.2.0 v1.10.0 >/dev/null
assert_eq "previous tag: single tag -> none (status 1)" "1" "$(SB_PRE_RELEASE_REPO_ROOT="$GR" sub 'sb_smoke_resolve_previous_tag >/dev/null; echo $?' || true)"
echo hello >"$GR/file.txt"; git -C "$GR" add file.txt; git -C "$GR" commit -qm add; git -C "$GR" tag v2.0.0
assert_eq "checkout: no repo -> 1" 1 "$(sub 'sb_smoke_checkout_at_tag v1 "$TL_TMP/co0" >/dev/null; echo $?' || true)"
SB_PRE_RELEASE_REPO_ROOT="$GR" sub 'sb_smoke_checkout_at_tag v2.0.0 "$TL_TMP/co1"'
assert_eq "checkout: tag contents extracted" hello "$(cat "$TL_TMP/co1/file.txt")"
SB_PRE_RELEASE_REPO_ROOT="$GR" sub 'sb_smoke_checkout_at_tag v1.0.0 "$TL_TMP/co2"'
assert_file_absent "checkout: older tag lacks later file" "$TL_TMP/co2/file.txt"
assert_eq "checkout: unknown tag fails" "nonzero" "$(SB_PRE_RELEASE_REPO_ROOT="$GR" sub 'sb_smoke_checkout_at_tag nope "$TL_TMP/co3" >/dev/null 2>&1 && echo ok || echo nonzero')"

# --- RC markers ------------------------------------------------------------------------------------------------------------------------------------------
tl_stub date 'echo 2026-01-02T03:04:05Z'
assert_eq "marker dir from state dir" "$TL_TMP/st/rc-validation" "$(SB_RUNTIME_STATE_DIR="$TL_TMP/st" sub 'sb_smoke_rc_marker_dir')"
assert_eq "marker dir falls back to HOME" "$TL_TMP/hh/.silver-bullet/rc-validation" "$(env -u SB_RUNTIME_STATE_DIR HOME="$TL_TMP/hh" bash -c "source '$LIB'; sb_smoke_rc_marker_dir")"
MD="$TL_TMP/mk"
f="$(SB_RUNTIME_STATE_DIR="$MD" sub 'sb_smoke_write_rc_marker cursor fresh')"
assert_eq "marker path returned" "$MD/rc-validation/cursor-fresh" "$f"
assert_eq "marker defaults to pass, no artifact" "host=cursor
mode=fresh
status=pass
timestamp=2026-01-02T03:04:05Z" "$(cat "$f")"
f="$(SB_RUNTIME_STATE_DIR="$MD" sub 'sb_smoke_write_rc_marker codex upgrade skip /tmp/art.log')"
assert_eq "marker with status+artifact" "host=codex
mode=upgrade
status=skip
timestamp=2026-01-02T03:04:05Z
artifact=/tmp/art.log" "$(cat "$f")"
complete() { SB_RUNTIME_STATE_DIR="$MD" sub 'sb_smoke_rc_markers_complete; echo $?' || true; }
assert_eq "markers incomplete (2 of 6)" 1 "$(complete)"
for h in cursor codex claude; do for m in fresh upgrade; do SB_RUNTIME_STATE_DIR="$MD" sub "sb_smoke_write_rc_marker $h $m pass >/dev/null"; done; done
assert_eq "markers complete (all pass)" 0 "$(complete)"
SB_RUNTIME_STATE_DIR="$MD" sub 'sb_smoke_write_rc_marker claude upgrade skip >/dev/null'
assert_eq "markers complete (skip counts)" 0 "$(complete)"
SB_RUNTIME_STATE_DIR="$MD" sub 'sb_smoke_write_rc_marker claude upgrade fail >/dev/null'
assert_eq "markers incomplete (fail)" 1 "$(complete)"
rm "$MD/rc-validation/codex-fresh"
SB_RUNTIME_STATE_DIR="$MD" sub 'sb_smoke_write_rc_marker claude upgrade pass >/dev/null'
assert_eq "markers incomplete (missing file)" 1 "$(complete)"

: "$REAL_HOME"
tl_results
