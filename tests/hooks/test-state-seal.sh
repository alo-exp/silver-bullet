#!/usr/bin/env bash
# hooks/lib/state-seal.sh: the keyed seal, the counter, tamper evidence and the event log.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=../../hooks/lib/state-seal.sh
source "$TL_REPO_ROOT/hooks/lib/state-seal.sh"

SD="$SB_RUNTIME_STATE_DIR"
S="$SD/state"
BR="$TL_TMP/branch"
export SILVER_BULLET_BRANCH_FILE="$BR"
LOG="$SD/seal-events.log"
fresh() { rm -f "$S" "$S.seal" "$S.hwm" "$LOG" "$SD/seal.key" "$BR"; mkdir -p "$SD"; }
logged() { [[ -f "$LOG" ]] && cat "$LOG" || true; }

fresh
assert_eq "seal path" "$S.seal" "$(sb_state_seal_file "$S")"
assert_eq "no state, nothing trusted" "" "$(sb_state_seal_trusted "$S")"
printf 'a\nb\n' >"$S"
assert_eq "no seal and no counter: read as written" "a
b" "$(sb_state_seal_trusted "$S")"
sb_state_seal_write "$S"
assert_eq "the seal is keyed" "hmac" "$(sed -n 2p "$S.seal")"
assert_eq "first counter" "1" "$(sed -n 3p "$S.seal")"
assert_eq "sealed line count" "2" "$(sed -n 4p "$S.seal")"
assert_eq "the key has mode 0600" "600" "$(stat -c %a "$SD/seal.key" 2>/dev/null || stat -f %Lp "$SD/seal.key")"
assert_eq "sealed: all of it" "a
b" "$(sb_state_seal_trusted "$S")"
printf 'forged\n' >>"$S"
assert_eq "appended outside the hooks: ignored" "a
b" "$(sb_state_seal_trusted "$S")"
sb_state_seal_enforce "$S"
assert_eq "enforce drops the unsealed line" "a
b" "$(cat "$S")"
printf 'c\n' >>"$S"
sb_state_seal_write "$S"
assert_eq "the counter is monotonic" "2" "$(sed -n 3p "$S.seal")"
assert_eq "the highest counter is kept" "2" "$(cat "$S.hwm")"
assert_eq "a legitimate append is trusted" "a
b
c" "$(sb_state_seal_trusted "$S")"
assert_eq "nothing was logged so far" "" "$(logged)"

# an edit of a sealed line
printf 'a\nX\nc\n' >"$S"
assert_eq "an in-place edit yields nothing" "" "$(sb_state_seal_trusted "$S")"
assert_contains "and is logged" "$(logged)" "the sealed lines changed"
sb_state_seal_enforce "$S"
assert_eq "enforce empties an edited state" "" "$(cat "$S")"
assert_file_absent "and drops its seal" "$S.seal"
printf 'a\n' >>"$S"
sb_state_seal_write "$S"
assert_eq "the counter goes on after a tamper" "3" "$(sed -n 3p "$S.seal")"

# a shorter rewrite is not a reset
fresh
printf 'a\nb\nc\n' >"$S"
sb_state_seal_write "$S"
printf 'a\n' >"$S"
assert_eq "fewer lines than sealed are not trusted" "" "$(sb_state_seal_trusted "$S")"
assert_contains "and logged" "$(logged)" "shorter than sealed"
sb_state_seal_enforce "$S"
assert_eq "enforce empties it" "" "$(cat "$S")"

# a deleted seal
fresh
printf 'a\nb\n' >"$S"
sb_state_seal_write "$S"
rm -f "$S.seal"
assert_eq "a deleted seal is not trusted while the counter exists" "" "$(sb_state_seal_trusted "$S")"
assert_contains "and logged" "$(logged)" "the seal was deleted"
rm -f "$S.hwm"
assert_eq "no seal and no counter on a live install: not trusted" "" "$(sb_state_seal_trusted "$S")"
assert_contains "and logged" "$(logged)" "the state has no seal"
rm -f "$SD/seal.key"
assert_eq "an install that never made its key reads the state as written" "a
b" "$(sb_state_seal_trusted "$S")"

# a rollback and a copied pair
fresh
printf 'a\n' >"$S"
sb_state_seal_write "$S"
cp "$S" "$TL_TMP/old.state"
cp "$S.seal" "$TL_TMP/old.seal"
printf 'b\n' >>"$S"
sb_state_seal_write "$S"
cp "$TL_TMP/old.state" "$S"
cp "$TL_TMP/old.seal" "$S.seal"
assert_eq "an older state and seal put back are not trusted" "" "$(sb_state_seal_trusted "$S")"
assert_contains "and logged" "$(logged)" "an older seal was put back"

# a state emptied by its owner (rm, : >) is not a tamper
fresh
printf 'a\nb\n' >"$S"
sb_state_seal_write "$S"
: >"$S"
assert_eq "an empty state trusts nothing and is no alarm" "" "$(sb_state_seal_trusted "$S")"
assert_eq "nothing was logged" "" "$(logged)"
printf 'c\n' >>"$S"
sb_state_seal_write "$S"
assert_eq "recording goes on after it" "c" "$(sb_state_seal_trusted "$S")"
assert_eq "with the counter still rising" "2" "$(sed -n 3p "$S.seal")"

# a recomputed unkeyed seal
fresh
printf 'a\n' >"$S"
sb_state_seal_write "$S"
printf 'a\nb\n' >"$S"
printf 'v2\nhmac\n1\n2\n-\n%s\n' "$(printf 'sb-seal-v2\n2\n1\n-\na\nb\n' | cksum | tr ' ' -)" >"$S.seal"
assert_eq "a seal recomputed without the key does not verify" "" "$(sb_state_seal_trusted "$S")"
rm -f "$SD/seal.key"
printf 'a\n' >"$S"
sb_state_seal_write "$S"
mv "$SD/seal.key" "$SD/seal.key.bak"
assert_eq "a missing key is not trusted" "" "$(sb_state_seal_trusted "$S")"
mv "$SD/seal.key.bak" "$SD/seal.key"

# the branch binding
fresh
printf 'feature/a\n' >"$BR"
printf 'a\n' >"$S"
sb_state_seal_write "$S"
assert_eq "same branch: trusted" "a" "$(sb_state_seal_trusted "$S")"
printf 'feature/b\n' >"$BR"
assert_eq "a pair sealed on another branch is not trusted" "" "$(sb_state_seal_trusted "$S")"
assert_contains "and logged" "$(logged)" "another branch"
rm -f "$BR"
assert_eq "no branch file now: the binding is not checked" "a" "$(sb_state_seal_trusted "$S")"
fresh
printf 'a\n' >"$S"
sb_state_seal_write "$S"
printf 'feature/new\n' >"$BR"
assert_eq "a seal made before any branch file existed still verifies" "a" "$(sb_state_seal_trusted "$S")"

# an unreadable seal, a symlinked seal
fresh
printf 'a\n' >"$S"
printf 'garbage\n' >"$S.seal"
assert_eq "an unreadable seal yields nothing" "" "$(sb_state_seal_trusted "$S")"
rm -f "$S.seal"
ln -s "$TL_TMP/elsewhere" "$S.seal"
assert_eq "a symlinked seal yields nothing" "" "$(sb_state_seal_trusted "$S")"
sb_state_seal_write "$S"
assert_file_absent "and is never written through" "$TL_TMP/elsewhere"
rm -f "$S.seal"
ln -s "$TL_TMP/elsewhere2" "$S.hwm"
sb_state_seal_write "$S"
assert_file_absent "a symlinked counter is never written through" "$TL_TMP/elsewhere2"
rm -f "$S.hwm"
rm -f "$LOG"
ln -s "$TL_TMP/elsewhere3" "$LOG"
_sb_state_seal_log "$S" "ignored"
assert_file_absent "a symlinked log is never written through" "$TL_TMP/elsewhere3"
rm -f "$LOG"

# no python3: a plain checksum, said so
fresh
printf 'a\nb\n' >"$S"
NOPY="$(tl_path_without python3 openssl)"
NOSSL="$(tl_path_without openssl)"
PATH="$NOPY" sb_state_seal_write "$S"
assert_eq "without python3 the seal is a plain checksum" "cksum" "$(sed -n 2p "$S.seal")"
assert_contains "with a logged warning" "$(logged)" "plain checksum"
assert_eq "it verifies without python3" "a
b" "$(PATH="$NOPY" sb_state_seal_trusted "$S")"
printf 'a\nX\n' >"$S"
assert_eq "and still detects an edit" "" "$(PATH="$NOPY" sb_state_seal_trusted "$S")"
printf 'a\nb\n' >"$S"
sb_state_seal_write "$S"
assert_eq "with python3 back, the next seal is keyed" "hmac" "$(sed -n 2p "$S.seal")"
fresh
mkdir -p "$SD"
ln -s "$TL_TMP/elsewhere4" "$SD/seal.key"
printf 'a\n' >"$S"
sb_state_seal_write "$S"
assert_eq "a symlinked key is not used: plain checksum" "cksum" "$(sed -n 2p "$S.seal")"
assert_file_absent "and not written through" "$TL_TMP/elsewhere4"
rm -f "$SD/seal.key"

# without a state file or through a symlink there is nothing to seal
fresh
sb_state_seal_write "$S"
assert_file_absent "no state, no seal" "$S.seal"
printf 'a\n' >"$TL_TMP/real"
ln -s "$TL_TMP/real" "$S"
sb_state_seal_write "$S"
assert_file_absent "a symlinked state is never sealed" "$S.seal"
rm -f "$S"

# the log and key directory default to the state's own when the runtime has none
assert_eq "without a runtime state directory the state's own is used" "/x/y" "$(unset SB_RUNTIME_STATE_DIR; _sb_state_seal_dir /x/y/state)"

# a key that cannot be made
fresh
tl_stub openssl 'exit 1'
printf 'a\n' >"$S"
sb_state_seal_write "$S"
rm -f "$TL_BIN/openssl"
assert_eq "no key could be made: a plain checksum" "cksum" "$(sed -n 2p "$S.seal")"
assert_file_absent "and no key file is left" "$SD/seal.key"
assert_file_absent "nor a temporary one" "$SD/seal.key.$$"

# python3 cannot make the key either (no openssl): a plain checksum, no key left
fresh
REALPY="$(command -v python3)"
tl_stub python3 "case \"\$*\" in *urandom*) exit 1 ;; esac; exec \"$REALPY\" \"\$@\""
printf 'a\n' >"$S"
PATH="$TL_BIN:$NOSSL" sb_state_seal_write "$S"
rm -f "$TL_BIN/python3"
assert_eq "python3 could not make a key: a plain checksum" "cksum" "$(sed -n 2p "$S.seal")"
assert_file_absent "and no key file is left" "$SD/seal.key"

# a digest that cannot be computed leaves the seal alone
fresh
printf 'a\n' >"$S"
sb_state_seal_write "$S"
before="$(cat "$S.seal")"
tl_stub openssl 'exit 1'
sb_state_seal_write "$S"
rm -f "$TL_BIN/openssl"
assert_eq "no digest: the seal is untouched" "$before" "$(cat "$S.seal")"

# counters: a damaged seal, and a counter that fell behind the seal
fresh
printf 'a\n' >"$S"
printf 'v2\nhmac\nXX\n1\n-\nd\n' >"$S.seal"
sb_state_seal_write "$S"
assert_eq "a damaged seal counts from the stored maximum" "1" "$(sed -n 3p "$S.seal")"
printf '0\n' >"$S.hwm"
sb_state_seal_write "$S"
assert_eq "a counter behind the seal is overtaken, not reused" "2" "$(sed -n 3p "$S.seal")"

# nothing to judge
fresh
sb_state_seal_enforce "$S"
assert_file_absent "enforce on a missing state creates nothing" "$S"
ln -s "$TL_TMP/real2" "$S"
sb_state_seal_enforce "$S"
assert_file_absent "enforce through a symlinked state does nothing" "$TL_TMP/real2"
rm -f "$S"

# an unkeyed seal is a downgrade where keyed seals are possible
fresh
printf 'a\n' >"$S"
sb_state_seal_write "$S"
printf 'v2\ncksum\n1\n1\n-\n%s\n' "$(printf 'sb-seal-v2\n1\n1\n-\na\n' | cksum | tr ' ' -)" >"$S.seal"
assert_eq "a checksum seal with python3 and a key available is not trusted" "" "$(sb_state_seal_trusted "$S")"
assert_contains "and logged as a downgrade" "$(logged)" "unkeyed"
fresh
printf 'a\n' >"$S"
PATH="$NOPY" sb_state_seal_write "$S"
assert_eq "a checksum seal with neither python3 nor a key still verifies" "a" "$(PATH="$NOPY" sb_state_seal_trusted "$S")"
assert_eq "but not once a digest tool is back" "" "$(sb_state_seal_trusted "$S")"
fresh
printf 'a\n' >"$S"
PATH="$(tl_path_without openssl)" sb_state_seal_write "$S"
assert_eq "python3 alone seals with a key" "hmac" "$(sed -n 2p "$S.seal")"
assert_eq "and openssl reads it" "a" "$(sb_state_seal_trusted "$S")"

# the lock: the claim protocol of orchestrator-io.sh (a claim file the sole entry of the lock directory)
fresh
LK="$S.lock"
claims() { local n=0 e; for e in "$LK"/*; do [[ -e "$e" ]] && n=$((n + 1)); done; printf '%s' "$n"; }
sb_state_seal_lock "$S"
assert_eq "the lock is taken: a claim is its sole entry" "1" "$(claims)"
assert_match "the claim is named claim.PID.NONCE" '^claim\.[0-9]+\.[0-9]+$' "$(ls "$LK")"
assert_eq "and it names its owner" "$$" "$(cut -d' ' -f1 "$LK"/claim.*)"
sb_state_seal_unlock
assert_file_absent "released: the directory is gone" "$LK"
sb_state_seal_unlock
assert_file_absent "releasing twice does nothing" "$LK"
rc=0
SB_STATE_SEAL_LOCK_TRIES=abc sb_state_seal_lock "$S" || rc=$?
assert_eq "an unreadable tries setting falls back to the default" "0" "$rc"
sb_state_seal_unlock
# a holder from the first protocol (a "pid" file) whose process is gone is taken over
mkdir "$LK"
printf '99999999\n' >"$LK/pid"
sb_state_seal_lock "$S"
assert_eq "a lock of a gone owner (old pid file) is taken over" "1" "$(claims)"
assert_file_absent "and its pid file is gone" "$LK/pid"
sb_state_seal_unlock
# a claim of a gone process is taken over
mkdir "$LK"
printf '99999999 %s\n' "$(date +%s)" >"$LK/claim.99999999.1"
sb_state_seal_lock "$S"
assert_file_absent "a stale claim (process gone) is removed by name" "$LK/claim.99999999.1"
assert_eq "and the lock is ours" "1" "$(claims)"
sb_state_seal_unlock
# a live owner is waited for, then the lock is NOT obtained (status 1, a notice, nothing touched)
mkdir "$LK"
printf '%s %s\n' "$$" "$(date +%s)" >"$LK/claim.$$.5"
rc=0
err="$(SB_STATE_SEAL_LOCK_TRIES=2 sb_state_seal_lock "$S" 2>&1 >/dev/null)" || rc=$?
assert_eq "a lock held by a live owner is not obtained" "1" "$rc"
assert_contains "and says so on stderr" "$err" "stayed busy"
assert_file_exists "the live owner's claim is left alone" "$LK/claim.$$.5"
assert_eq "nothing was recorded as held" "" "$_SB_SEAL_LOCK_CLAIMS"
# a live pid whose claim is over a minute old is a reused pid: taken over
touch -t 202001010000 "$LK/claim.$$.5"
sb_state_seal_lock "$S"
assert_file_absent "an old claim of a reused pid is removed" "$LK/claim.$$.5"
sb_state_seal_unlock
mkdir "$LK"
printf '%s %s\n' "$$" "$(date +%s)" >"$LK/claim.$$.6"
touch -t 202001010000 "$LK/claim.$$.6"
SB_STATE_SEAL_LOCK_STALE_MINUTES=x sb_state_seal_lock "$S"
assert_eq "an unreadable stale age falls back to one minute" "1" "$(claims)"
sb_state_seal_unlock
# a claim without a readable pid: left alone while fresh, removed when over a minute old
mkdir "$LK"
printf 'garbage\n' >"$LK/claim.1.1"
rc=0
SB_STATE_SEAL_LOCK_TRIES=1 sb_state_seal_lock "$S" 2>/dev/null || rc=$?
assert_eq "a fresh claim with no pid is a holder being written: not taken" "1" "$rc"
touch -t 202001010000 "$LK/claim.1.1"
sb_state_seal_lock "$S"
assert_file_absent "an old claim with no pid is taken over" "$LK/claim.1.1"
sb_state_seal_unlock
# a directory with no claim yet: a holder between mkdir and claim. Left alone while fresh, taken over when old
mkdir "$LK"
rc=0
SB_STATE_SEAL_LOCK_TRIES=1 sb_state_seal_lock "$S" 2>/dev/null || rc=$?
assert_eq "an empty fresh lock directory is not taken" "1" "$rc"
assert_file_exists "and stays" "$LK"
touch -t 202001010000 "$LK"
sb_state_seal_lock "$S"
assert_eq "an empty lock directory over a minute old is taken over" "1" "$(claims)"
sb_state_seal_unlock
# an entry that is no claim keeps the lock held, whatever its age; nothing recursive is ever removed
mkdir -p "$LK/sub"
printf 'x\n' >"$LK/sub/f"
touch -t 202001010000 "$LK" "$LK/sub"
rc=0
SB_STATE_SEAL_LOCK_TRIES=1 sb_state_seal_lock "$S" 2>/dev/null || rc=$?
assert_eq "a foreign entry keeps the lock held" "1" "$rc"
assert_file_exists "and is not removed" "$LK/sub/f"
rm -rf "$LK"
# a symlinked lock path is refused and never followed
mkdir "$TL_TMP/lktarget"
printf 'keep\n' >"$TL_TMP/lktarget/f"
ln -s "$TL_TMP/lktarget" "$LK"
rc=0
err="$(sb_state_seal_lock "$S" 2>&1 >/dev/null)" || rc=$?
assert_eq "a symlinked lock is refused" "1" "$rc"
assert_contains "with a notice" "$err" "not a plain directory"
assert_eq "its target is untouched" "keep" "$(cat "$TL_TMP/lktarget/f")"
assert_eq "and nothing is held" "" "$_SB_SEAL_LOCK_CLAIMS"
sb_state_seal_unlock
assert_file_exists "an unlock with nothing held leaves it alone" "$TL_TMP/lktarget/f"
rm -f "$LK"
# a file where the lock should be is refused as well
printf 'x\n' >"$LK"
rc=0
sb_state_seal_lock "$S" 2>/dev/null || rc=$?
assert_eq "a plain file in the way is refused" "1" "$rc"
rm -f "$LK"
# a second claim appearing between the claim and the check: not held, the other entry stays
date() { mkdir -p "$LK"; : >"$LK/other"; command date "$@"; }
rc=0
_sb_seal_lock_try "$LK" || rc=$?
unset -f date
assert_eq "a claim that is not the sole entry is not held" "1" "$rc"
assert_file_exists "the other entry is left alone" "$LK/other"
assert_eq "and our own claim is gone" "1" "$(claims)"
rm -rf "$LK"
# no robbery of a live owner after a stale judgement: B judged the lock stale, A took it over and holds it
mkdir "$LK"
printf '99999999 %s\n' "$(date +%s)" >"$LK/claim.99999999.1"
_sb_seal_lock_reclaim "$LK"
sb_state_seal_lock "$S"
A_CLAIM="$_SB_SEAL_LOCK_CLAIM"
rc=0
_sb_seal_lock_reclaim "$LK" || rc=$?
assert_eq "a late reclaim finds a live owner: it takes nothing" "1" "$rc"
assert_file_exists "the new owner's claim stands" "$A_CLAIM"
rc=0
(SB_STATE_SEAL_LOCK_TRIES=1 sb_state_seal_lock "$S" 2>/dev/null) || rc=$?
assert_eq "a second waiter does not get the lock either" "1" "$rc"
assert_file_exists "the owner's claim still stands" "$A_CLAIM"
sb_state_seal_unlock
assert_file_absent "the owner releases it" "$LK"
# unlock never removes a lock it does not own: our claim was taken over (judged gone), a new owner holds the lock
sb_state_seal_lock "$S"
rm -f "$_SB_SEAL_LOCK_CLAIM"
printf '%s %s\n' "$$" "$(date +%s)" >"$LK/claim.$$.9"
sb_state_seal_unlock
assert_file_exists "unlock leaves the new owner's lock" "$LK/claim.$$.9"
rm -rf "$LK"
# locks nest: the one taken last is released first
sb_state_seal_lock "$S"
sb_state_seal_lock "$S.rec"
assert_eq "two locks are held" "2" "$(printf '%s\n' "$_SB_SEAL_LOCK_CLAIMS" | wc -l | tr -d ' ')"
sb_state_seal_unlock
assert_file_absent "the inner lock is released first" "$S.rec.lock"
assert_file_exists "the outer one is still held" "$LK"
sb_state_seal_unlock
assert_file_absent "then the outer" "$LK"
# a claim that is a symlink is not a claim to release
mkdir "$LK"
ln -s "$TL_TMP/lktarget/f" "$LK/claim.$$.8"
_SB_SEAL_LOCK_CLAIMS="$LK/claim.$$.8"
sb_state_seal_unlock
assert_file_exists "a symlinked claim is not removed" "$LK/claim.$$.8"
rm -rf "$LK"

# the skill invoked last (the .last record)
fresh; rm -f "$S.last" "$S.lasthwm"
_sb_state_seal_ensure_key "$S"
assert_eq "no record: nothing" "" "$(sb_state_last_read "$S")"
sb_state_last_write "$S" silver-spec
assert_eq "a written record reads back" "silver-spec" "$(sb_state_last_read "$S")"
assert_eq "its counter is 1" "1" "$(sed -n 3p "$S.last")"
sb_state_last_write "$S" silver-spec
assert_eq "a re-invocation is written again (counter 2)" "2" "$(sed -n 3p "$S.last")"
sb_state_last_write "$S" silver-plan
assert_eq "the latest skill wins" "silver-plan" "$(sb_state_last_read "$S")"
cp "$S.last" "$TL_TMP/last.keep"
sb_state_last_write "$S" silver-spec
cp "$TL_TMP/last.keep" "$S.last"
assert_eq "an older record put back is refused" "" "$(sb_state_last_read "$S")"
sb_state_last_write "$S" silver-spec
printf 'branch-a\n' >"$BR"; sb_state_last_write "$S" silver-spec
assert_eq "same branch: verifies" "silver-spec" "$(sb_state_last_read "$S")"
printf 'branch-b\n' >"$BR"
assert_eq "another branch: refused" "" "$(sb_state_last_read "$S")"
rm -f "$BR"; sb_state_last_write "$S" silver-spec
printf 'v9\nsilver-spec\n9\n-\nx\n' >"$S.last"
assert_eq "an unknown version is refused" "" "$(sb_state_last_read "$S")"
printf 'v1\n\n9\n-\nx\n' >"$S.last"
assert_eq "an empty skill is refused" "" "$(sb_state_last_read "$S")"
printf 'v1\nsilver-spec\nnine\n-\nx\n' >"$S.last"
assert_eq "a non-numeric counter is refused" "" "$(sb_state_last_read "$S")"
sb_state_last_write "$S" silver-spec
sed -i 's/silver-spec/silver-ingest/' "$S.last"
assert_eq "an edited skill breaks the digest" "" "$(sb_state_last_read "$S")"
rm -f "$S.last"; ln -s "$TL_TMP/elsewhere" "$S.last"
sb_state_last_write "$S" silver-spec
assert_eq "a symlinked .last is not written through" "" "$(sb_state_last_read "$S")"
assert_file_absent "and nothing is created behind it" "$TL_TMP/elsewhere"
rm -f "$S.last"; sb_state_last_write "$S" silver-spec
rm -f "$S.lasthwm"; ln -s "$TL_TMP/elsewhere2" "$S.lasthwm"
assert_eq "a symlinked counter file is refused on read" "" "$(sb_state_last_read "$S")"
sb_state_last_write "$S" silver-spec
assert_file_absent "and on write" "$TL_TMP/elsewhere2"
rm -f "$S.lasthwm"
# per-agent records
rm -f "$S".last.* "$S".lasthwm.*
sb_state_last_write "$S" silver-spec w1
assert_eq "an agent's record reads back for that agent" "silver-spec" "$(sb_state_last_read "$S" w1)"
assert_eq "and not for another agent" "" "$(sb_state_last_read "$S" w2)"
assert_eq "nor for the main session" "" "$(sb_state_last_read "$S")"
for bad in '../x' 'a/b' 'a b' '.h' "$(printf 'z%.0s' $(seq 1 65))"; do
  sb_state_last_write "$S" silver-spec "$bad"
  assert_eq "an invalid agent id reads nothing: $bad" "" "$(sb_state_last_read "$S" "$bad")"
done
assert_eq "only the valid agent has a file" "1" "$(ls "$S".last.* | wc -l | tr -d ' ')"
cp "$S.last.w1" "$S.last.w3"; cp "$S.lasthwm.w1" "$S.lasthwm.w3"
assert_eq "an agent's record copied to another agent id fails its digest" "" "$(sb_state_last_read "$S" w3)"
touch "$S.last.w1.12345" "$S.last.not.valid.id"
SB_LAST_AGENT_RECORDS=1 sb_state_last_write "$S" silver-spec w4
assert_file_exists "pruning keeps files that are not agent records" "$S.last.not.valid.id"
rm -f "$S".last.* "$S".lasthwm.*
sb_state_last_write "$S" silver-spec
rm -f "$S.lasthwm"
assert_eq "a record whose counter file was deleted is refused" "" "$(sb_state_last_read "$S")"
sb_state_last_write "$S" silver-spec
printf 'v1' >"$S.last"
assert_eq "a record cut short (no newline, missing lines) is refused" "" "$(sb_state_last_read "$S")"
sb_state_last_write "$S" silver-spec
cp "$S.last" "$TL_TMP/last.hi"; printf '1\n' >"$S.lasthwm"
sb_state_last_write "$S" silver-plan
assert_eq "the counter never goes back below the record's own (hwm was lowered)" "$(( $(sed -n 3p "$TL_TMP/last.hi") + 1 ))" "$(sed -n 3p "$S.last")"
cp "$S.last" "$TL_TMP/last.before"
( PATH="$(tl_path_without openssl python3)"; sb_state_last_write "$S" silver-spec )
assert_eq "when the digest cannot be computed the record is left as it was" "$(cat "$TL_TMP/last.before")" "$(cat "$S.last")"
rm -f "$SD/seal.key" "$S.last"
sb_state_last_write "$S" silver-spec
assert_file_absent "without a key nothing is written (a record never creates the key)" "$S.last"
assert_file_absent "and no key was created" "$SD/seal.key"
printf 'v1\nsilver-spec\n1\n-\nx\n' >"$S.last"
assert_eq "an unkeyed record is not trusted" "" "$(sb_state_last_read "$S")"
rm -f "$S.last" "$S.lasthwm"


tl_results
