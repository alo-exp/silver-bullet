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
assert_eq "with neither (an older install) it is read as written" "a
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
NOPY="$(tl_path_without python3)"
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
REALPY="$(command -v python3)"
tl_stub python3 "case \"\$*\" in *urandom*) exit 1 ;; esac; exec \"$REALPY\" \"\$@\""
printf 'a\n' >"$S"
sb_state_seal_write "$S"
rm -f "$TL_BIN/python3"
assert_eq "no key could be made: a plain checksum" "cksum" "$(sed -n 2p "$S.seal")"
assert_file_absent "and no key file is left" "$SD/seal.key"
assert_file_absent "nor a temporary one" "$SD/seal.key.$$"

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

tl_results
