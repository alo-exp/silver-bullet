#!/usr/bin/env bash
# scripts/tfidf-rank.sh: chunk boundaries, degenerate inputs and scoring details.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

RANK="$TL_REPO_ROOT/scripts/tfidf-rank.sh"
rank() { # rank QUERY FILE... (files on stdin)
  local q="$1"; shift
  local input=""
  local f
  for f in "$@"; do input+="$f"$'\n'; done
  tl_run_stdin "$input" bash "$RANK" "$q"
}

# empty stdin and blank path lines produce nothing
tl_run_stdin "" bash "$RANK" "anything"
assert_eq "no files exits 0" 0 "$TL_STATUS"
assert_eq "no files prints nothing" "" "$TL_OUT"
tl_run_stdin $'\n\n' bash "$RANK" "anything"
assert_eq "blank lines are not files" "" "$TL_OUT"

# files that do not exist are skipped, existing ones still ranked
printf 'alpha beta\n' >"$TL_TMP/real.txt"
rank "alpha" "$TL_TMP/missing.txt" "$TL_TMP/real.txt"
assert_eq "missing file skipped, exit 0" 0 "$TL_STATUS"
assert_match "only the real file is reported" "^[0-9.]+"$'\t'"$TL_TMP/real.txt"$'\t'"1"$'\t'"1"$'\t' "$TL_OUT"
assert_not_contains "missing file absent" "$TL_OUT" "missing.txt"

# an existing but empty file yields no chunks -> no output
: >"$TL_TMP/empty.txt"
rank "alpha" "$TL_TMP/empty.txt"
assert_eq "empty file exits 0" 0 "$TL_STATUS"
assert_eq "empty file prints nothing" "" "$TL_OUT"
rank "" "$TL_TMP/empty.txt"
assert_eq "empty file with empty query prints nothing" "" "$TL_OUT"

# 45 short non-blank lines: split by CHUNK_LINES (40) -> lines 1-40, 41-45
for i in $(seq 1 45); do echo "row$i"; done >"$TL_TMP/long.txt"
rank "" "$TL_TMP/long.txt"
assert_eq "two chunks from 45 lines" 2 "$(wc -l <<<"$TL_OUT" | tr -d ' ')"
assert_match "first chunk covers 1-40" "^0"$'\t'"$TL_TMP/long.txt"$'\t'"1"$'\t'"40"$'\t'"row1" "$(sed -n 1p <<<"$TL_OUT")"
assert_match "second chunk covers 41-45" "^0"$'\t'"$TL_TMP/long.txt"$'\t'"41"$'\t'"45"$'\t'"row41" "$(sed -n 2p <<<"$TL_OUT")"

# blank line closes a chunk (and belongs to it); a trailing line without newline is kept
printf 'one\ntwo\n\nthree\nlast-no-newline' >"$TL_TMP/blank.txt"
rank "" "$TL_TMP/blank.txt"
assert_match "chunk 1 = lines 1-3" $'\t'"1"$'\t'"3"$'\t' "$(sed -n 1p <<<"$TL_OUT")"
assert_match "chunk 2 = lines 4-5 incl. unterminated line" $'\t'"4"$'\t'"5"$'\t'"three" "$(sed -n 2p <<<"$TL_OUT")"
assert_contains "unterminated last line preserved" "$(sed -n 2p <<<"$TL_OUT")" "last-no-newline"

# chunk text: newline escaped as \n, tabs become spaces
printf 'a\tb\nc\n' >"$TL_TMP/tab.txt"
rank "" "$TL_TMP/tab.txt"
assert_eq "5 fields despite a tab in the text" 5 "$(awk -F'\t' '{print NF}' <<<"$TL_OUT")"
assert_contains "tab replaced by space and newline escaped" "$TL_OUT" 'a b\nc\n'

# byte budget (SB_CHUNK_BYTES) splits even without blank lines
printf 'aaaaaaaaaa\nbbbbbbbbbb\ncccccccccc\n' >"$TL_TMP/big.txt"
SB_CHUNK_BYTES=10 rank "" "$TL_TMP/big.txt"
assert_eq "lines over the byte budget are one chunk each" 3 "$(wc -l <<<"$TL_OUT" | tr -d ' ')"
SB_CHUNK_BYTES=100000 rank "" "$TL_TMP/big.txt"
assert_eq "large budget keeps one chunk" 1 "$(wc -l <<<"$TL_OUT" | tr -d ' ')"

# scoring: rarer term outranks, case-insensitive, single-letter terms ignored
printf 'zebra common\n\ncommon words only\n\ncommon again\n' >"$TL_TMP/score.txt"
rank "ZEBRA common" "$TL_TMP/score.txt"
assert_contains "best chunk first is the one with the rare term" "$(sed -n 1p <<<"$TL_OUT")" "zebra common"
top="$(cut -f1 <<<"$TL_OUT" | sed -n 1p)"
bottom="$(cut -f1 <<<"$TL_OUT" | tail -1)"
assert_eq "rare-term chunk scores above others" 1 "$(awk -v a="$top" -v b="$bottom" 'BEGIN{print (a>b)?1:0}')"
rank "z" "$TL_TMP/score.txt"
assert_eq "single-letter query term scores 0 on every chunk" "0.000000" "$(cut -f1 <<<"$TL_OUT" | sort -u)"
rank "nothingmatches" "$TL_TMP/score.txt"
assert_eq "unmatched term scores 0" "0.000000" "$(cut -f1 <<<"$TL_OUT" | sort -u)"

tl_results
