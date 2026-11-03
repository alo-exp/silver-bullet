#!/usr/bin/env bash
# sync-codex-package.sh failure, lock and cleanup paths, always run from a
# disposable repository snapshot (the script rewrites agents/, host-bundles/
# and plugins/silver-bullet in the checkout it lives in).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=tests/lib/repo-snapshot.sh
source "$TL_REPO_ROOT/tests/lib/repo-snapshot.sh"
# shellcheck source=tests/lib/offline-tools.sh
source "$TL_REPO_ROOT/tests/lib/offline-tools.sh"
sb_offline_tools_install "$TL_TMP/offline-bin"

SNAP="$(sb_repo_snapshot --git "$TL_REPO_ROOT" "$TL_TMP/repo")"
assert_eq "snapshot is not the real checkout" 1 "$([[ "$SNAP" != "$TL_REPO_ROOT" ]] && echo 1 || echo 0)"
SCRIPT="$SNAP/scripts/sync-codex-package.sh"
PKG="$SNAP/plugins/silver-bullet"
FAKE_TMP="$TL_TMP/tmp"
mkdir -p "$FAKE_TMP"
cd "$TL_TMP"

# Restore tracked files a test removed (a successful sync regenerates the rest).
restore() { git -C "$SNAP" checkout -q -- "$@"; }
sync_pkg() { tl_run env TMPDIR="$FAKE_TMP" timeout 120 bash "$SCRIPT"; }
snap_dirty() { git -C "$SNAP" status --porcelain --untracked-files=all; }

# --- full run -------------------------------------------------------------
# Leftovers the sync must prune.
mkdir -p "$PKG/.codex-plugin/migrated-command-skills/source-command-x" "$SNAP/agents/codex/old" \
  "$PKG/.skill-source.staging.stale" "$PKG/junk-dir" "$PKG/cursor-skill-source"
printf 'x' >"$PKG/junk-file"
jq '.version = "0.0.0-stale"' "$PKG/.codex-plugin/plugin.json" >"$TL_TMP/plugin.json" && cp "$TL_TMP/plugin.json" "$PKG/.codex-plugin/plugin.json"
chmod 600 "$PKG/.codex-plugin/plugin.json"

sync_pkg
assert_eq "sync exits 0" 0 "$TL_STATUS"
assert_contains "refresh logged" "$TL_OUT" "[codex-sync] Refreshing generated package surface in $PKG"
assert_contains "completion logged" "$TL_OUT" "[codex-sync] Codex package synchronized"
assert_eq "manifest version follows package.json" "$(jq -r .version "$SNAP/package.json")" "$(jq -r .version "$PKG/.codex-plugin/plugin.json")"
assert_eq "manifest is world-readable" "644" "$(stat -c %a "$PKG/.codex-plugin/plugin.json" 2>/dev/null || stat -f %Lp "$PKG/.codex-plugin/plugin.json")"
assert_file_absent "migrated command skills pruned" "$PKG/.codex-plugin/migrated-command-skills"
assert_file_absent "legacy agents/codex pruned" "$SNAP/agents/codex"
assert_file_absent "stale staging dir pruned" "$PKG/.skill-source.staging.stale"
assert_file_absent "retired cursor-skill-source dir pruned" "$PKG/cursor-skill-source"
assert_file_absent "no render lock left inside the package" "$PKG/.skill-source.render.lock"
assert_file_exists "Codex hidden sources rendered" "$PKG/skill-source/sb-feature/SILVER_SOURCE"
assert_file_absent "unknown package dir pruned" "$PKG/junk-dir"
assert_file_absent "unknown package file pruned" "$PKG/junk-file"
assert_eq "package entries are relative symlinks" "../../docs" "$(readlink "$PKG/docs")"
assert_eq "package scripts link stays inside the repo" "../../scripts" "$(readlink "$PKG/scripts")"
assert_file_exists "templates mirrored" "$PKG/templates/silver-bullet.md.base"
assert_file_absent "skill sources renamed away from SKILL.md" "$(find "$PKG/skill-source" -name SKILL.md -print -quit)"
assert_eq "skill sources stored extensionless" 1 "$([[ -n "$(find "$PKG/skill-source" -name SILVER_SOURCE -print -quit)" ]] && echo 1 || echo 0)"
assert_file_absent "lock released" "$SNAP/.planning/sb-sync-codex-package.lock.d"
assert_eq "no staging dir left in TMPDIR" "" "$(ls -A "$FAKE_TMP")"

# The snapshot is the generated state, so the sync restores exactly it, and a
# second run changes nothing either.
assert_eq "sync restores the generated state" "" "$(snap_dirty)"
sync_pkg
assert_eq "second sync exits 0" 0 "$TL_STATUS"
assert_eq "second sync leaves the tree unchanged" "" "$(snap_dirty)"

# --- prerequisites ----------------------------------------------------------
# A PATH holding only what the script needs before its preflight (dirname)
# plus the tools that should stay present.
preflight_path() {
  local dir="$TL_TMP/preflight-path-$1" t
  mkdir -p "$dir"
  ln -sf "$(command -v dirname)" "$dir/dirname"
  shift
  for t in "$@"; do ln -sf "$(command -v "$t")" "$dir/$t"; done
  printf '%s\n' "$dir"
}
TIMEOUT_BIN="$(command -v timeout)"
BASH_BIN="$(command -v bash)"
for tool in rsync python3; do
  if [[ "$tool" == rsync ]]; then keep=(python3); else keep=(rsync); fi
  tl_run env PATH="$(preflight_path "no-$tool" "${keep[@]}")" TMPDIR="$FAKE_TMP" "$TIMEOUT_BIN" 60 "$BASH_BIN" "$SCRIPT"
  assert_eq "missing $tool exits 1" 1 "$TL_STATUS"
  assert_contains "missing $tool named" "$TL_ERR" "ERROR: $tool is required by sync-codex-package.sh"
  assert_contains "missing $tool: prune warning" "$TL_ERR" "prunes tracked trees before repopulating"
  assert_eq "missing $tool: nothing was touched" "" "$(snap_dirty)"
done

# --- source checks ------------------------------------------------------------
rm -f "$PKG/.codex-plugin/plugin.json"
sync_pkg
assert_eq "missing Codex manifest exits 1" 1 "$TL_STATUS"
assert_contains "missing Codex manifest named" "$TL_ERR" "missing Codex manifest at $PKG/.codex-plugin/plugin.json"
assert_file_absent "lock released after an error" "$SNAP/.planning/sb-sync-codex-package.lock.d"
restore plugins/silver-bullet/.codex-plugin/plugin.json

rm -f "$SNAP/SECURITY.md"
sync_pkg
assert_eq "missing package source exits 1" 1 "$TL_STATUS"
assert_contains "missing package source named" "$TL_ERR" "package source missing: SECURITY.md"

restore SECURITY.md

# --- lock -------------------------------------------------------------------
# A held lock times out after 300 one-second waits (sleep is stubbed).
mkdir -p "$SNAP/.planning/sb-sync-codex-package.lock.d"
SLEEP_LOG="$TL_TMP/sleep.log"
: >"$SLEEP_LOG"
tl_stub sleep 'echo "$*" >>"'"$SLEEP_LOG"'"'
sync_pkg
assert_eq "held lock times out" 1 "$TL_STATUS"
assert_contains "lock timeout reported" "$TL_ERR" "timed out waiting for sync-codex-package lock"
assert_eq "waited 299 times before giving up" 299 "$(wc -l <"$SLEEP_LOG" | tr -d ' ')"
assert_file_exists "a lock held by someone else is not released" "$SNAP/.planning/sb-sync-codex-package.lock.d"

# R8-22: a lock whose owner is still running is waited for and names its owner.
LOCK="$SNAP/.planning/sb-sync-codex-package.lock.d"
printf '%s\n' "$$" >"$LOCK/pid"
: >"$SLEEP_LOG"
tl_run env TMPDIR="$FAKE_TMP" SB_SYNC_LOCK_WAIT_SECONDS=3 bash "$SCRIPT"
assert_eq "live owner: lock times out" 1 "$TL_STATUS"
assert_contains "live owner named" "$TL_ERR" "(held by pid $$)"
assert_eq "live owner: waited" 2 "$(wc -l <"$SLEEP_LOG" | tr -d ' ')"
# R8-22: a lock left by a killed sync (its PID is gone) is broken at once.
sh -c 'exit 0' &
dead_pid=$!
wait "$dead_pid" || true
printf '%s\n' "$dead_pid" >"$LOCK/pid"
: >"$SLEEP_LOG"
sync_pkg
assert_eq "dead owner: stale lock broken, sync exits 0" 0 "$TL_STATUS"
assert_contains "stale lock reported" "$TL_ERR" "removing stale lock $LOCK"
assert_eq "dead owner: no waiting" 0 "$(wc -l <"$SLEEP_LOG" | tr -d ' ')"
assert_file_absent "lock released after the run" "$LOCK"
# R8-22: a lock without an owner PID (older script, or killed before writing
# it) is broken once it is a minute old, and waited for while it is fresh.
mkdir -p "$LOCK"
touch -t 202001010000 "$LOCK"
sync_pkg
assert_eq "ownerless old lock broken" 0 "$TL_STATUS"
assert_contains "ownerless lock reported" "$TL_ERR" "removing stale lock $LOCK"

# One more successful sync carries two tolerance conditions at once, so the synced snapshot
# is not regenerated for each: .planning is unusable (the lock moves to TMPDIR), and the lock
# is held by someone else until its holder lets go.
rm -rf "$SNAP/.planning"
printf 'not a dir' >"$SNAP/.planning"
FALLBACK_LOCK="$FAKE_TMP/sb-sync-codex-package.lock.d"
mkdir -p "$FALLBACK_LOCK"
: >"$SLEEP_LOG"
tl_stub sleep 'echo "$*" >>"'"$SLEEP_LOG"'"; [[ $(wc -l <"'"$SLEEP_LOG"'") -ge 3 ]] && rmdir "'"$FALLBACK_LOCK"'"; exit 0'
sync_pkg
assert_eq "sync works with an unusable .planning" 0 "$TL_STATUS"
assert_eq "waited until released" 3 "$(wc -l <"$SLEEP_LOG" | tr -d ' ')"
assert_eq ".planning left alone" "not a dir" "$(<"$SNAP/.planning")"
assert_file_absent "fallback lock released" "$FALLBACK_LOCK"
rm -f "$TL_BIN/sleep"

tl_results
