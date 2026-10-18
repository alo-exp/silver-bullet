#!/usr/bin/env bash
# scripts/lib/plugin-cache-version.sh: guards, alias refresh, orphan pruning and
# sb_claude_ensure_plugin_cache_ready, in the sandboxed HOME.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude

# shellcheck source=../../scripts/lib/plugin-cache-version.sh
source "$TL_REPO_ROOT/scripts/lib/plugin-cache-version.sh"
set +e   # the library sets -e; keep the harness in control of return codes

REAL_PY="$(command -v python3)"
NOPY="$(tl_path_without python3)"
CR="$HOME/.claude/plugins/cache/alo-labs/silver-bullet"

mkver() { mkdir -p "$CR/$1/hooks"; : >"$CR/$1/hooks/session-start"; }
rc_of() { "$@" >/dev/null 2>&1; echo $?; }

# --- sb_plugin_cache_latest_version_dir -------------------------------------------
assert_eq "latest: empty arg" 1 "$(rc_of sb_plugin_cache_latest_version_dir "")"
assert_eq "latest: no arg" 1 "$(rc_of sb_plugin_cache_latest_version_dir)"
assert_eq "latest: nonexistent dir" 1 "$(rc_of sb_plugin_cache_latest_version_dir "$TL_TMP/nope")"
mkdir -p "$TL_TMP/empty-root"
assert_eq "latest: no valid version dirs" 1 "$(rc_of sb_plugin_cache_latest_version_dir "$TL_TMP/empty-root")"
mkdir -p "$TL_TMP/py-root/0.1.0/hooks"
assert_eq "latest: python3 missing" 1 "$(PATH="$NOPY" rc_of sb_plugin_cache_latest_version_dir "$TL_TMP/py-root")"

mkdir -p "$TL_TMP/vr/0.9.0/hooks" "$TL_TMP/vr/0.10.0/.claude-plugin" "$TL_TMP/vr/0.2.0/.codex-plugin" \
         "$TL_TMP/vr/current" "$TL_TMP/vr/test" "$TL_TMP/vr/9.9.9"
echo '{}' >"$TL_TMP/vr/0.10.0/.claude-plugin/plugin.json"
echo '{}' >"$TL_TMP/vr/0.2.0/.codex-plugin/plugin.json"
mkdir -p "$TL_TMP/vr/current/hooks"   # alias dir is never a candidate even with hooks
: >"$TL_TMP/vr/test/.orphaned_at"
: >"$TL_TMP/vr/9.9.9/.orphaned_at"     # orphan marker only: invalid
: >"$TL_TMP/vr/plainfile"
assert_eq "latest: numeric-aware sort picks 0.10.0" "$(cd "$TL_TMP/vr/0.10.0" && pwd -P)" "$(sb_plugin_cache_latest_version_dir "$TL_TMP/vr")"
rm -rf "$TL_TMP/vr/0.10.0"
assert_eq "latest: next is 0.9.0 (hooks dir)" "$(cd "$TL_TMP/vr/0.9.0" && pwd -P)" "$(sb_plugin_cache_latest_version_dir "$TL_TMP/vr")"
rm -rf "$TL_TMP/vr/0.9.0"
assert_eq "latest: codex-plugin dir qualifies" "$(cd "$TL_TMP/vr/0.2.0" && pwd -P)" "$(sb_plugin_cache_latest_version_dir "$TL_TMP/vr")"

# --- sb_plugin_cache_refresh_current_alias ----------------------------------------------
assert_eq "alias: empty arg is a no-op" 0 "$(rc_of sb_plugin_cache_refresh_current_alias "")"
assert_eq "alias: nonexistent dir is a no-op" 0 "$(rc_of sb_plugin_cache_refresh_current_alias "$TL_TMP/nope")"
assert_eq "alias: no valid version is a no-op" 0 "$(rc_of sb_plugin_cache_refresh_current_alias "$TL_TMP/empty-root")"
assert_file_absent "alias: not created when nothing valid" "$TL_TMP/empty-root/current"

mkdir -p "$TL_TMP/ar/1.0.0/hooks" "$TL_TMP/ar/current/stale"
sb_plugin_cache_refresh_current_alias "$TL_TMP/ar"
assert_eq "alias: real dir replaced by symlink" "$(cd "$TL_TMP/ar/1.0.0" && pwd -P)" "$(readlink "$TL_TMP/ar/current")"
mkdir -p "$TL_TMP/ar/2.0.0/hooks"
sb_plugin_cache_refresh_current_alias "$TL_TMP/ar"
assert_eq "alias: existing symlink re-pointed" "$(cd "$TL_TMP/ar/2.0.0" && pwd -P)" "$(readlink "$TL_TMP/ar/current")"
rm "$TL_TMP/ar/current"; echo file >"$TL_TMP/ar/current"
sb_plugin_cache_refresh_current_alias "$TL_TMP/ar"
assert_eq "alias: plain file replaced" "$(cd "$TL_TMP/ar/2.0.0" && pwd -P)" "$(readlink "$TL_TMP/ar/current")"

# python3 disappearing between version lookup and alias write: no-op, rc 0.
# `command -v python3` is answered "absent" once the first interpreter run has happened.
mkdir -p "$TL_TMP/ar2/1.0.0/hooks"
tl_stub python3 "touch \"$TL_TMP/py-ran\"; exec \"$REAL_PY\" \"\$@\""
hash -r
command() {
  if [[ "${1:-}" == -v && "${2:-}" == python3 && -e "$TL_TMP/py-ran" ]]; then return 1; fi
  builtin command "$@"
}
assert_eq "alias: python3 vanished -> rc 0" 0 "$(rc_of sb_plugin_cache_refresh_current_alias "$TL_TMP/ar2")"
unset -f command
assert_file_absent "alias: not written when python3 vanished" "$TL_TMP/ar2/current"
rm -f "$TL_BIN/python3" "$TL_TMP/py-ran"; hash -r

# --- sb_plugin_cache_prune_orphaned_dirs ---------------------------------------------------
assert_eq "prune: empty arg" 0 "$(rc_of sb_plugin_cache_prune_orphaned_dirs "")"
assert_eq "prune: nonexistent dir" 0 "$(rc_of sb_plugin_cache_prune_orphaned_dirs "$TL_TMP/nope")"
mkdir -p "$TL_TMP/pr/orphan" "$TL_TMP/pr/orphan-hooks/hooks" "$TL_TMP/pr/orphan-plugin/.claude-plugin" \
         "$TL_TMP/pr/healthy/hooks" "$TL_TMP/pr/current"
: >"$TL_TMP/pr/orphan/.orphaned_at"; : >"$TL_TMP/pr/orphan-hooks/.orphaned_at"; : >"$TL_TMP/pr/orphan-plugin/.orphaned_at"
: >"$TL_TMP/pr/current/.orphaned_at"; : >"$TL_TMP/pr/stray-file"
echo '{}' >"$TL_TMP/pr/orphan-plugin/.claude-plugin/plugin.json"
PATH="$NOPY" sb_plugin_cache_prune_orphaned_dirs "$TL_TMP/pr"
assert_file_exists "prune: python3 missing -> nothing removed" "$TL_TMP/pr/orphan"
sb_plugin_cache_prune_orphaned_dirs "$TL_TMP/pr"
assert_file_absent "prune: bare orphan removed" "$TL_TMP/pr/orphan"
assert_file_exists "prune: orphan with hooks kept" "$TL_TMP/pr/orphan-hooks"
assert_file_exists "prune: orphan with plugin.json kept" "$TL_TMP/pr/orphan-plugin"
assert_file_exists "prune: healthy kept" "$TL_TMP/pr/healthy"
assert_file_exists "prune: current kept" "$TL_TMP/pr/current"
assert_file_exists "prune: stray file kept" "$TL_TMP/pr/stray-file"

# --- sb_claude_ensure_plugin_cache_ready ------------------------------------------------------
REPO="$TL_TMP/repo"; mkdir -p "$REPO/hooks/lib"
echo '#!/bin/sh' >"$REPO/hooks/session-start"; echo lib >"$REPO/hooks/lib/x.sh"
assert_eq "ensure: cache root missing" 1 "$(rc_of sb_claude_ensure_plugin_cache_ready "$REPO")"
mkdir -p "$CR/orphan"; : >"$CR/orphan/.orphaned_at"
assert_eq "ensure: no valid version dir" 1 "$(rc_of sb_claude_ensure_plugin_cache_ready "$REPO")"
assert_file_absent "ensure: orphan pruned along the way" "$CR/orphan"

mkdir -p "$CR/0.5.0/hooks"
assert_eq "ensure: syncs hooks from repo and succeeds" 0 "$(rc_of sb_claude_ensure_plugin_cache_ready "$REPO")"
assert_file_exists "ensure: session-start copied" "$CR/0.5.0/hooks/session-start"
assert_eq "ensure: nested hook copied" lib "$(cat "$CR/0.5.0/hooks/lib/x.sh")"
assert_eq "ensure: current alias points at latest" "$(cd "$CR/0.5.0" && pwd -P)" "$(readlink "$CR/current")"
assert_eq "ensure: copied files get the Fu=rx,Fgo=rx mode" "555" "$(stat -c %a "$CR/0.5.0/hooks/session-start")"

# no repo root: only existing cache content counts
rm -rf "$CR/0.5.0/hooks"; mkdir -p "$CR/0.5.0/hooks"
assert_eq "ensure: no repo root and no session-start -> 1" 1 "$(rc_of sb_claude_ensure_plugin_cache_ready "")"
: >"$CR/0.5.0/hooks/session-start"
assert_eq "ensure: no repo root, cache has session-start -> 0" 0 "$(rc_of sb_claude_ensure_plugin_cache_ready)"
assert_eq "ensure: repo without hooks dir is skipped" 0 "$(rc_of sb_claude_ensure_plugin_cache_ready "$TL_TMP/empty-root")"

# alias creation silently failing (3rd python3 call is the alias writer): current missing -> 1
rm -f "$CR/current"
cat >"$TL_BIN/python3" <<EOS
#!/usr/bin/env bash
n=\$(( \$(cat "$TL_TMP/pycalls" 2>/dev/null || echo 0) + 1 )); echo \$n >"$TL_TMP/pycalls"
[[ \$n -eq 3 ]] && exit 0
exec "$REAL_PY" "\$@"
EOS
chmod +x "$TL_BIN/python3"; hash -r
rm -f "$TL_TMP/pycalls"
assert_eq "ensure: alias not created -> 1" 1 "$(rc_of sb_claude_ensure_plugin_cache_ready "$REPO")"
assert_file_absent "ensure: no current alias" "$CR/current"

tl_results
