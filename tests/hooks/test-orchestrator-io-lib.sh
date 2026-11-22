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
rewait() { _SB_ORCH_LOCK_WAITED=0; }
live_pid() { sleep 300 & TL_LIVE=$!; }
live_pid # a live process of ours that owns claims below; killed by its exact pid at the end
trap 'kill "$TL_LIVE" 2>/dev/null || true' EXIT
dead_pid="$( (exit 0) & echo $!; wait )"
mkdir "$LOCK"
touch -t 200001010000 "$LOCK" 2>/dev/null || true
assert_eq "an old lock directory without a claim is reclaimed" held "$(sb_orchestrator_with_lock witness 2>/dev/null)"
assert_eq "the reclaimed lock is released" free "$(witness)"
# A stale directory holding a non-claim entry is never removed (only claims are removed by name).
mkdir "$LOCK"
: >"$LOCK/held"
touch -t 200001010000 "$LOCK" 2>/dev/null || true
rewait
start=$SECONDS
out="$(SB_ORCHESTRATOR_LOCK_WAIT_TENTHS=2 sb_orchestrator_with_lock args p q 2>"$TL_TMP/err")"
assert_eq "an unremovable lock times out and the command runs" "p|q" "$out"
assert_contains "the timeout is reported on stderr" "$(cat "$TL_TMP/err")" "stayed busy"
assert_eq "the wait stayed bounded" 1 "$(( SECONDS - start < 10 ? 1 : 0 ))"
assert_eq "the foreign entry is untouched" held "$(ls "$LOCK")"
rm -rf "${LOCK:?}"
# The command may remove the lock itself; the release then has nothing to remove.
release_gone() { rm -rf "${LOCK:?}"; }
sb_orchestrator_with_lock release_gone && rc=0 || rc=$?
assert_eq "a lock removed under the holder is tolerated" 0 "$rc"
mkdir "$LOCK"
rewait
start=$SECONDS
out="$(SB_ORCHESTRATOR_LOCK_WAIT_TENTHS=3 sb_orchestrator_with_lock args a b 2>/dev/null)"
assert_eq "a fresh empty lock (its creator is mid-write) times out and the command still runs" "a|b" "$out"
assert_eq "the other holder's lock is left alone" held "$(witness)"
rmdir "$LOCK"
assert_eq "the wait was bounded" 1 "$(( SECONDS - start < 10 ? 1 : 0 ))"

echo "=== lock: claims, ownership, staleness ==="
# A live process's claim is never reclaimed by age alone while young; the holder is waited on.
mkdir "$LOCK"; printf '%s' "$TL_LIVE" >"$LOCK/claim.$TL_LIVE.1"
rewait
out="$(SB_ORCHESTRATOR_LOCK_WAIT_TENTHS=3 sb_orchestrator_with_lock args l v 2>/dev/null)"
assert_eq "a live holder's claim is waited on, then the command runs unlocked" "l|v" "$out"
assert_eq "the live claim survives" "claim.$TL_LIVE.1" "$(ls "$LOCK")"
# The directory's own age never makes a live holder's lock stale (the old find -mmin takeover did).
touch -t 200001010000 "$LOCK"
rewait
out="$(SB_ORCHESTRATOR_LOCK_WAIT_TENTHS=3 sb_orchestrator_with_lock args o ld 2>/dev/null)"
assert_eq "an old directory with a live fresh claim is not taken over" "claim.$TL_LIVE.1" "$(ls "$LOCK")"
# ...but a live pid's claim older than the stale age is a reused pid and goes.
touch -t 200001010000 "$LOCK/claim.$TL_LIVE.1"
assert_eq "a live pid's claim older than the age limit is reclaimed" held "$(sb_orchestrator_with_lock witness 2>/dev/null)"
assert_eq "and released" free "$(witness)"
# A dead holder's claim is reclaimed at once.
mkdir "$LOCK"; printf '%s' "$dead_pid" >"$LOCK/claim.$dead_pid.2"
assert_eq "a dead holder's claim is reclaimed" held "$(sb_orchestrator_with_lock witness 2>/dev/null)"
assert_eq "and released again" free "$(witness)"
# A claim without a pid: waited on while fresh, reclaimed once old.
mkdir "$LOCK"; : >"$LOCK/claim.5.5"
rewait
out="$(SB_ORCHESTRATOR_LOCK_WAIT_TENTHS=2 sb_orchestrator_with_lock args n p 2>/dev/null)"
assert_eq "a fresh pid-less claim is waited on" "n|p" "$out"
touch -t 200001010000 "$LOCK/claim.5.5"
assert_eq "an old pid-less claim is reclaimed" held "$(sb_orchestrator_with_lock witness 2>/dev/null)"
# Garbage in the staleness and wait settings means the defaults.
mkdir "$LOCK"; printf '%s' "$TL_LIVE" >"$LOCK/claim.$TL_LIVE.3"; touch -t 200001010000 "$LOCK/claim.$TL_LIVE.3"
assert_eq "a non-numeric stale age means the default" held "$(SB_ORCHESTRATOR_LOCK_STALE_MINUTES=soon sb_orchestrator_with_lock witness 2>/dev/null)"
mkdir "$LOCK"; printf '%s' "$TL_LIVE" >"$LOCK/claim.$TL_LIVE.4"
rewait
start=$SECONDS
out="$(SB_ORCHESTRATOR_LOCK_WAIT_TENTHS=forever sb_orchestrator_with_lock args g b 2>/dev/null)"
assert_eq "a non-numeric wait means the default budget (4 s) and the command still runs" "g|b" "$out"
assert_eq "the default budget is about four seconds" 1 "$(( SECONDS - start >= 3 && SECONDS - start < 10 ? 1 : 0 ))"
rm -rf "${LOCK:?}"
# Ownership: a holder whose claim was reclaimed releases nothing, so it cannot free a lock that
# is now somebody else's.
takeover() { rm -f "$LOCK"/claim.*; printf '%s' "$TL_LIVE" >"$LOCK/claim.$TL_LIVE.9"; }
sb_orchestrator_with_lock takeover
assert_eq "a holder that lost its claim leaves the new owner's lock in place" "claim.$TL_LIVE.9" "$(ls "$LOCK")"
rm -rf "${LOCK:?}"
# Refusals: a symlink or a plain file at the lock path is never touched or followed.
mkdir "$TL_TMP/victim"
ln -s "$TL_TMP/victim" "$LOCK"
out="$(sb_orchestrator_with_lock args s y 2>"$TL_TMP/err")"
assert_eq "a symlinked lock path: the command runs unlocked" "s|y" "$out"
assert_contains "and the refusal is reported" "$(cat "$TL_TMP/err")" "not a plain directory"
assert_eq "the symlink target gets no claim" 0 "$(find "$TL_TMP/victim" -mindepth 1 | wc -l | tr -d ' ')"
assert_eq "the symlink is still there" 1 "$([[ -L "$LOCK" ]] && echo 1 || echo 0)"
rm -f "$LOCK"
: >"$LOCK"
out="$(sb_orchestrator_with_lock args f i 2>/dev/null)"
assert_eq "a plain file at the lock path: the command runs unlocked" "f|i" "$out"
assert_eq "the file is untouched" 1 "$([[ -f "$LOCK" ]] && echo 1 || echo 0)"
rm -f "$LOCK"
# A directory that is not ours is refused (root hands one to another uid; anyone else has "/").
assert_eq "an absent lock path is sane" 0 "$(_sb_orch_lock_sane "$LOCK" && echo 0 || echo 1)"
if [[ "$(id -u)" == 0 ]]; then
  mkdir "$TL_TMP/foreign"; chown 12345 "$TL_TMP/foreign"; foreign="$TL_TMP/foreign"
else
  foreign=/
fi
assert_eq "a directory owned by someone else is not sane" 1 "$(_sb_orch_lock_sane "$foreign" && echo 0 || echo 1)"
# Directory removed under its creator between mkdir and the claim: the creator retries.
tl_stub mkdir 'real="$(command -v -p mkdir)"; "$real" "$@" || exit $?; for a in "$@"; do case "$a" in *orchestrator.lock) if [ ! -e "$TL_FLAG" ]; then : >"$TL_FLAG"; rmdir "$a"; fi;; esac; done'; hash -r
export TL_FLAG="$TL_TMP/flag-vanish"; rm -f "$TL_FLAG"
assert_eq "a lock directory removed under its creator is retaken" held "$(sb_orchestrator_with_lock witness 2>/dev/null)"
# A stray entry that shows up beside the claim makes the creator withdraw and retry.
tl_stub mkdir 'real="$(command -v -p mkdir)"; "$real" "$@" || exit $?; for a in "$@"; do case "$a" in *orchestrator.lock) if [ ! -e "$TL_FLAG" ]; then : >"$TL_FLAG"; : >"$a/stray"; fi;; esac; done'; hash -r
export TL_FLAG="$TL_TMP/flag-stray"; rm -f "$TL_FLAG"
rewait
out="$(SB_ORCHESTRATOR_LOCK_WAIT_TENTHS=3 sb_orchestrator_with_lock args s t 2>/dev/null)"
assert_eq "a stray entry makes the creator withdraw; the command still runs" "s|t" "$out"
assert_eq "the stray entry is the only thing left" stray "$(ls "$LOCK")"
rm -rf "${LOCK:?}"
rm -f "$TL_BIN/mkdir"; hash -r
rewait
# A lock path swapped for a symlink after the first look is neither followed nor reclaimed.
tl_stub mkdir 'for a in "$@"; do case "$a" in *orchestrator.lock) [ -L "$a" ] || ln -s "$TL_TMP/victim" "$a"; exit 1;; esac; done; exec "$(command -v -p mkdir)" "$@"'; hash -r
out="$(SB_ORCHESTRATOR_LOCK_WAIT_TENTHS=2 sb_orchestrator_with_lock args w p 2>/dev/null)"
rm -f "$TL_BIN/mkdir"; hash -r
assert_eq "a lock path swapped for a symlink mid-run: the command runs unlocked" "w|p" "$out"
assert_eq "and nothing was written through it" 0 "$(find "$TL_TMP/victim" -mindepth 1 | wc -l | tr -d ' ')"
rm -f "$LOCK"
rewait
# An unusable state directory: the lock cannot be made, the command still runs after the wait.
out="$(SB_RUNTIME_STATE_DIR="$D/notadir" SB_ORCHESTRATOR_LOCK_WAIT_TENTHS=1 sb_orchestrator_with_lock args u d 2>/dev/null)"
assert_eq "an uncreatable state directory: the command runs unlocked" "u|d" "$out"
rewait
# A directory that cannot be removed at release (someone added an entry) is left, without error.
litter() { : >"$LOCK/stray"; }
sb_orchestrator_with_lock litter && rc=0 || rc=$?
assert_eq "a lock directory that cannot be removed at release is tolerated" 0 "$rc"
assert_eq "and only the stray entry is left" stray "$(ls "$LOCK")"
rm -rf "${LOCK:?}"

echo "=== lock: no lost update ==="
# Concurrent read-modify-write cycles never lose an update; a planted stale lock must not let two
# waiters both take it over (the old find -mmin + rmdir takeover failed here about one round in five).
bump() { local n; n="$(cat "$D/counter")"; sleep 0.01; echo $((n + 1)) >"$D/counter"; }
cycles() { # ROUNDS PLANT: how many rounds lost an update
  local r bad=0 pids
  for ((r = 0; r < $1; r++)); do
    echo 0 >"$D/counter"
    if [[ "$2" == plant ]]; then rm -rf "${LOCK:?}"; mkdir "$LOCK"; touch -t 200001010000 "$LOCK"; fi
    pids=()
    for _ in 1 2 3 4 5 6; do ( sb_orchestrator_with_lock bump 2>/dev/null ) & pids+=($!); done
    wait "${pids[@]}"
    [[ "$(cat "$D/counter")" == 6 ]] || bad=$((bad + 1))
    rm -rf "${LOCK:?}"
  done
  echo "$bad"
}
rm -rf "${LOCK:?}"
assert_eq "six concurrent read-modify-write cycles all land" 0 "$(cycles 5 plain)"
assert_eq "six concurrent cycles behind a planted stale lock all land (30 rounds)" 0 "$(cycles 30 plant)"

echo "=== lock: no lost update under CPU load ==="
burners=()
for _ in 1 2 3; do ( while :; do :; done ) & burners+=($!); done
t0=$SECONDS
assert_eq "plain rounds under load" 0 "$(cycles 10 plain)"
assert_eq "stale-lock rounds under load" 0 "$(cycles 30 plant)"
for b in "${burners[@]}"; do kill "$b" 2>/dev/null || true; done
wait "${burners[@]}" 2>/dev/null || true
assert_eq "the stress stayed within its time bound" 1 "$(( SECONDS - t0 < 90 ? 1 : 0 ))"

kill "$TL_LIVE" 2>/dev/null || true

tl_results
