#!/usr/bin/env bash
# scripts/lib/global-toolstack/shell-compression.sh (deployed layout): RTK is the
# primary shell rewriter, lean-ctx the fallback; the first installed owner is exec'd.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/toolstack-helpers.sh"
tl_init

ts_stage_deployed
S=shell-compression.sh
run() { # <stdin>: run the staged script from the sandbox home
  tl_run_stdin "$1" bash -c 'cd "$HOME" && exec bash "$1"' _ "$TS_STAGE/$S"
}
cfg() { # <primary> <fallback>
  ts_write_config "$(jq -cn --arg p "$1" --arg f "$2" '{shell_compression:{primary:$p,fallback:$f}}')"
}
add_rtk() { tl_stub rtk 'echo "rtk $*"; cat'; }
add_lean() { tl_stub lean-ctx 'echo "lean-ctx $*"; cat'; }
rm_tools() { rm -f "$TL_BIN/rtk" "$TL_BIN/lean-ctx"; }
expect_silent() { assert_eq "$1: exit 0" 0 "$TL_STATUS"; assert_eq "$1: no output" "" "$TL_OUT"; }

# --- primary wins; stdin is passed through to the exec'd rewriter ---
cfg rtk leanctx; add_rtk; add_lean
run 'payload-1'
assert_eq "rtk primary: exit 0" 0 "$TL_STATUS"
assert_eq "rtk primary: execs rtk hook cursor with the payload" $'rtk hook cursor\npayload-1' "$TL_OUT"
cfg leanctx rtk
run 'payload-2'
assert_eq "leanctx primary: execs lean-ctx hook rewrite with the payload" $'lean-ctx hook rewrite\npayload-2' "$TL_OUT"

# --- fallback when the primary is not installed ---
cfg rtk leanctx; rm_tools; add_lean
run 'p3'
assert_eq "rtk missing: lean-ctx fallback" $'lean-ctx hook rewrite\np3' "$TL_OUT"
cfg leanctx rtk; rm_tools; add_rtk
run 'p4'
assert_eq "lean-ctx missing: rtk fallback" $'rtk hook cursor\np4' "$TL_OUT"

# --- nothing usable: silent no-op ---
cfg rtk leanctx; rm_tools
run 'p5'; expect_silent "neither tool installed"
cfg rtk rtk
run 'p6'; expect_silent "rtk primary and fallback, rtk missing"
cfg leanctx leanctx
run 'p7'; expect_silent "leanctx primary and fallback, lean-ctx missing"
cfg other other; add_rtk; add_lean
run 'p8'; expect_silent "unknown primary and fallback are ignored"
cfg rtk leanctx; rm_tools; add_rtk
cfg leanctx other
run 'p9'; expect_silent "lean-ctx missing and unknown fallback"
rm_tools

# --- missing config: documented defaults (rtk, then lean-ctx) ---
TS_CONFIG="$TL_TMP/none.json" add_rtk
TS_CONFIG="$TL_TMP/none.json" run 'p10'
assert_eq "no config: rtk is primary" $'rtk hook cursor\np10' "$TL_OUT"
rm_tools; add_lean
TS_CONFIG="$TL_TMP/none.json" run 'p11'
assert_eq "no config: lean-ctx is the fallback" $'lean-ctx hook rewrite\np11' "$TL_OUT"
rm_tools

# --- common.sh without the helper functions: built-in defaults apply ---
bare="$TL_TMP/bare/global-toolstack"; mkdir -p "$bare/lib"
cp "$TS_STAGE/$S" "$bare/$S"; : >"$bare/lib/common.sh"
add_lean
tl_run_stdin 'p12' bash -c 'cd "$HOME" && exec bash "$1"' _ "$bare/$S"
assert_eq "helpers undefined: default fallback lean-ctx" $'lean-ctx hook rewrite\np12' "$TL_OUT"
rm_tools; add_rtk
tl_run_stdin 'p13' bash -c 'cd "$HOME" && exec bash "$1"' _ "$bare/$S"
assert_eq "helpers undefined: default primary rtk" $'rtk hook cursor\np13' "$TL_OUT"

tl_results
