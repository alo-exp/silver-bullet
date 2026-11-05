#!/usr/bin/env bash
# Unit tests for hooks/lib/orchestrator-io.sh: atomic state writes and the read-modify-write lock.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude
export SB_RUNTIME_PRESERVE_STATE_DIR=1
# shellcheck source=../../hooks/lib/orchestrator-io.sh
source "$TL_REPO_ROOT/hooks/lib/orchestrator-io.sh"
D="$SB_RUNTIME_STATE_DIR"
mkdir -p "$D"

echo "=== atomic write ==="
sb_orchestrator_atomic_write "$D/a.json" '{"a":1}' && rc=0 || rc=$?
assert_eq "write succeeds" 0 "$rc"
assert_eq "content has a trailing newline" '{"a":1}' "$(cat "$D/a.json")"
sb_orchestrator_atomic_write "$D/a.json" '{"a":2}'
assert_eq "overwrite replaces" '{"a":2}' "$(cat "$D/a.json")"
assert_eq "no temp files left" 0 "$(find "$D" -name 'a.json.*' | wc -l | tr -d ' ')"
sb_orchestrator_atomic_write "$D/new/dir/b.json" '{}' && rc=0 || rc=$?
assert_eq "missing parent directories are created" 0 "$rc"
sb_orchestrator_atomic_write "" '{}' && rc=0 || rc=$?
assert_eq "empty path refused" 1 "$rc"
printf 'plain file' >"$D/notadir"
sb_orchestrator_atomic_write "$D/notadir/x/y.json" '{}' && rc=0 || rc=$?
assert_eq "an uncreatable parent directory fails cleanly" 1 "$rc"
printf 'orig' >"$TL_TMP/target"
ln -s "$TL_TMP/target" "$D/link.json"
sb_orchestrator_atomic_write "$D/link.json" 'evil' && rc=0 || rc=$?
assert_eq "a symlink target is refused" 1 "$rc"
assert_eq "the symlink's target is untouched" orig "$(cat "$TL_TMP/target")"
mkdir "$D/dirtarget.json"
sb_orchestrator_atomic_write "$D/dirtarget.json" 'x' && rc=0 || rc=$?
assert_eq "a directory target is refused" 1 "$rc"
assert_eq "nothing slipped into the directory" 0 "$(find "$D/dirtarget.json" -type f | wc -l | tr -d ' ')"
rmdir "$D/dirtarget.json"
mkdir "$TL_TMP/ro"
chmod 500 "$TL_TMP/ro"
sb_orchestrator_atomic_write "$TL_TMP/ro/c.json" 'x' && rc=0 || rc=$?
chmod 700 "$TL_TMP/ro"
if [[ "$(id -u)" != 0 ]]; then assert_eq "an unwritable directory fails cleanly" 1 "$rc"; fi
tl_stub mv 'exit 1'; hash -r
sb_orchestrator_atomic_write "$D/d.json" 'x' && rc=0 || rc=$?
rm -f "$TL_BIN/mv"; hash -r
assert_eq "a failed rename fails" 1 "$rc"
assert_eq "a failed rename leaves no temp file" 0 "$(find "$D" -name 'd.json.*' | wc -l | tr -d ' ')"
tl_stub mv 'exit 1'; tl_stub rm 'exit 1'; hash -r
sb_orchestrator_atomic_write "$D/d2.json" 'x' && rc=0 || rc=$?
/bin/rm -f "$TL_BIN/mv" "$TL_BIN/rm"; hash -r
assert_eq "a failed rename with a failing cleanup still fails cleanly" 1 "$rc"
find "$D" -name 'd2.json.*' -delete
tl_stub mktemp 'exit 1'; hash -r
sb_orchestrator_atomic_write "$D/e.json" 'x' && rc=0 || rc=$?
rm -f "$TL_BIN/mktemp"; hash -r
assert_eq "no temp file available fails" 1 "$rc"

echo "=== lock ==="
LOCK="$(sb_orchestrator_lock_dir)"
assert_eq "lock path" "$D/orchestrator.lock" "$LOCK"
witness() { [[ -d "$LOCK" ]] && echo held || echo free; }
assert_eq "the command runs with the lock held" held "$(sb_orchestrator_with_lock witness)"
assert_eq "the lock is released afterwards" free "$(witness)"
failing() { return 7; }
sb_orchestrator_with_lock failing && rc=0 || rc=$?
assert_eq "the command's status is returned" 7 "$rc"
assert_eq "the lock is released after a failing command" free "$(witness)"
inner() { witness; }
outer() { sb_orchestrator_with_lock inner; }
assert_eq "re-entrant: a nested call does not deadlock" held "$(sb_orchestrator_with_lock outer)"
assert_eq "re-entrant: lock released once" free "$(witness)"
args() { printf '%s|%s' "$1" "$2"; }
assert_eq "arguments are passed through" "x y|z" "$(sb_orchestrator_with_lock args 'x y' z)"

echo "=== lock contention ==="
mkdir "$LOCK"
touch -t 200001010000 "$LOCK" 2>/dev/null || true
assert_eq "a stale lock is taken over" held "$(SB_ORCHESTRATOR_LOCK_STALE_MINUTES=1 sb_orchestrator_with_lock witness)"
assert_eq "the taken-over lock is released" free "$(witness)"
# A stale lock that cannot be removed (not empty) must not hang the caller.
mkdir "$LOCK"
: >"$LOCK/held"
touch -t 200001010000 "$LOCK" 2>/dev/null || true
start=$SECONDS
out="$(SB_ORCHESTRATOR_LOCK_WAIT_TENTHS=2 SB_ORCHESTRATOR_LOCK_STALE_MINUTES=1 sb_orchestrator_with_lock args p q)"
assert_eq "an unremovable stale lock times out and the command runs" "p|q" "$out"
assert_eq "the wait stayed bounded" 1 "$(( SECONDS - start < 10 ? 1 : 0 ))"
rm -rf "${LOCK:?}"
# The command may remove the lock itself; the release then has nothing to remove.
release_gone() { rmdir "$LOCK"; }
sb_orchestrator_with_lock release_gone && rc=0 || rc=$?
assert_eq "a lock removed under the holder is tolerated" 0 "$rc"
mkdir "$LOCK"
start=$SECONDS
out="$(SB_ORCHESTRATOR_LOCK_WAIT_TENTHS=3 SB_ORCHESTRATOR_LOCK_STALE_MINUTES=999 sb_orchestrator_with_lock args a b)"
assert_eq "a live lock times out and the command still runs" "a|b" "$out"
assert_eq "the other holder's lock is left alone" held "$(witness)"
rmdir "$LOCK"
assert_eq "the wait was bounded" 1 "$(( SECONDS - start < 10 ? 1 : 0 ))"
# Two processes updating one counter under the lock never lose an update.
echo 0 >"$D/counter"
bump() { local n; n="$(cat "$D/counter")"; sleep 0.01; echo $((n + 1)) >"$D/counter"; }
for _ in 1 2 3 4 5 6; do ( sb_orchestrator_with_lock bump ) & done
wait
assert_eq "six concurrent read-modify-write cycles all land" 6 "$(cat "$D/counter")"

tl_results
