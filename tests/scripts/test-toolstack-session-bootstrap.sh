#!/usr/bin/env bash
# scripts/lib/global-toolstack/session-bootstrap.sh (deployed layout): the
# background graphify index bootstrap, its lock and its early exits.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/toolstack-helpers.sh"
tl_init

ts_stage_deployed
repo="$TL_TMP/repo"; tl_git_repo "$repo"
hash="$(printf '%s' "$repo" | sha256sum | awk '{print substr($1,1,16)}')"
sdir="$HOME/st/$hash"
lock="$sdir/graphify-bootstrap.lock"
log="$sdir/graphify-bootstrap.log"
calls="$HOME/gf-calls"
CFG='{"enforcement":"always","state_dir":"~/st","tools":{"graphify":{"required":true}},"worktree":{"bootstrap_graphify":true}}'
ts_write_config "$CFG"
tl_stub graphify 'echo "$*" >>"$HOME/gf-calls"; exit "${GF_RC:-0}"'
S=session-bootstrap.sh

expect_silent() { assert_eq "$1: exit 0" 0 "$TL_STATUS"; assert_eq "$1: no output" "" "$TL_OUT"; }
wait_unlocked() { # wait (bounded) for the background job to remove the lock
  for _ in $(seq 1 200); do [[ -e "$lock" ]] || return 0; sleep 0.05; done
  return 1
}
settle() { sleep 0.4; } # negative checks: give a wrongly spawned job time to show itself
reset() { rm -rf "$HOME/st" "$calls" "$repo/graphify-out"; }
count() { if [[ -f "$calls" ]]; then wc -l <"$calls" | tr -d ' '; else echo 0; fi; }

sbp="$TL_TMP/sbp"; tl_git_repo "$sbp"
ts_sb_project "$sbp"
mkdir -p "$sbp/scripts/lib/recommended-tools"
cat >"$sbp/scripts/lib/recommended-tools/heartbeat.sh" <<'HB'
rt_project_id() { echo p; }
rt_worktree_id() { echo w; }
rt_current_session_id() { echo s; }
rt_heartbeat_path() { echo /hb; }
rt_heartbeat_is_valid() { return 0; }
HB
mkdir -p "$TL_TMP/nogit"
# tl_path_without symlinks every executable on PATH (about 5 s per call), so build
# minimal PATHs: with everything the script needs, and the same without jq.
mini="$TL_TMP/mini-path"; mini_nojq="$TL_TMP/mini-path-nojq"; mkdir -p "$mini" "$mini_nojq"
for c in bash jq dirname grep sed cat date sha256sum awk mkdir touch rm stat env; do
  ln -s "$(command -v "$c")" "$mini/$c"
  [[ "$c" == jq ]] || ln -s "$(command -v "$c")" "$mini_nojq/$c"
done

# --- early exits (nothing spawned) ---
tl_run env PATH="$mini_nojq" bash -c 'cd "$1" && exec bash "$2"' _ "$repo" "$TS_STAGE/$S"
expect_silent "jq missing"
ts_gate $S "" "$sbp"; expect_silent "defers to a live SB bridge"
TS_CONFIG="$TL_TMP/none.json" ts_gate $S "" "$repo"; expect_silent "no config"
printf '{"enforcement":"off","tools":{"graphify":{"required":true}},"worktree":{"bootstrap_graphify":true}}' >"$TL_TMP/off.json"
TS_CONFIG="$TL_TMP/off.json" ts_gate $S "" "$repo"; expect_silent "enforcement off"
printf '{"enforcement":"always","tools":{},"worktree":{"bootstrap_graphify":true}}' >"$TL_TMP/nr.json"
TS_CONFIG="$TL_TMP/nr.json" ts_gate $S "" "$repo"; expect_silent "graphify not required"
printf '{"enforcement":"always","tools":{"graphify":{"required":true}}}' >"$TL_TMP/nb.json"
TS_CONFIG="$TL_TMP/nb.json" ts_gate $S "" "$repo"; expect_silent "bootstrap not enabled"
rm -f "$TL_BIN/graphify"
ts_gate $S "" "$repo"; expect_silent "graphify CLI missing"
tl_stub graphify 'echo "$*" >>"$HOME/gf-calls"; exit "${GF_RC:-0}"'
ts_gate $S "" "$TL_TMP/nogit"; expect_silent "outside git"
mkdir -p "$repo/graphify-out"; printf '{}' >"$repo/graphify-out/graph.json"
ts_gate $S "" "$repo"; expect_silent "index already present"
settle
assert_eq "no early exit ran graphify" 0 "$(count)"
assert_file_absent "no early exit created state" "$sdir"

# --- default bootstrap: timeout wrapper, default args, lock lifecycle ---
reset
ts_gate $S "" "$repo"; expect_silent "bootstrap spawns silently"
wait_unlocked || assert_eq "lock removed after the job" removed "still locked"
assert_eq "graphify ran once with default args" "update . --no-cluster" "$(cat "$calls")"
assert_contains "log header written" "$(cat "$log")" "=== graphify bootstrap "

# graphify failing is retried once, then ignored
reset
GF_RC=1 ts_gate $S "" "$repo"; expect_silent "failing bootstrap still exits 0"
wait_unlocked || assert_eq "lock removed after failing job" removed "still locked"
assert_eq "failed run is retried once (timeout path)" 2 "$(count)"

# custom args from the config
reset
ts_write_config '{"enforcement":"always","state_dir":"~/st","tools":{"graphify":{"required":true}},"worktree":{"bootstrap_graphify":true,"graphify_update_args":["update","src"]}}'
ts_gate $S "" "$repo"; expect_silent "custom args"
wait_unlocked || assert_eq "lock removed" removed "still locked"
assert_eq "custom args used" "update src" "$(cat "$calls")"

# without timeout(1): plain graphify, failure ignored
ts_write_config "$CFG"
reset
tl_run_stdin "" env PATH="$TL_BIN:$mini" bash -c 'cd "$1" && exec bash "$2"' _ "$repo" "$TS_STAGE/$S"
assert_eq "no timeout(1): exit 0" 0 "$TL_STATUS"
wait_unlocked || assert_eq "lock removed" removed "still locked"
assert_eq "no timeout(1): graphify ran once" 1 "$(count)"
reset
tl_run_stdin "" env GF_RC=1 PATH="$TL_BIN:$mini" bash -c 'cd "$1" && exec bash "$2"' _ "$repo" "$TS_STAGE/$S"
assert_eq "no timeout(1), failing graphify: exit 0" 0 "$TL_STATUS"
wait_unlocked || assert_eq "lock removed" removed "still locked"
assert_eq "no timeout(1): failure is not retried" 1 "$(count)"

# CLI found only in ~/.local/bin (not on PATH)
reset
rm -f "$TL_BIN/graphify"
mkdir -p "$HOME/.local/bin"; printf '#!/bin/sh\nexit 0\n' >"$HOME/.local/bin/graphify"; chmod +x "$HOME/.local/bin/graphify"
ts_gate $S "" "$repo"; expect_silent "CLI in ~/.local/bin"
wait_unlocked || assert_eq "lock removed" removed "still locked"
assert_contains "job started (log header) though PATH lacks graphify" "$(cat "$log")" "=== graphify bootstrap "
rm -rf "$HOME/.local"
tl_stub graphify 'echo "$*" >>"$HOME/gf-calls"; exit "${GF_RC:-0}"'

# --- lock handling ---
reset; mkdir -p "$sdir"; touch "$lock"
ts_gate $S "" "$repo"; expect_silent "fresh lock"
settle
assert_eq "fresh lock: graphify not run" 0 "$(count)"
assert_file_exists "fresh lock is left in place" "$lock"

touch -d '2 hours ago' "$lock"
ts_gate $S "" "$repo"; expect_silent "stale lock"
wait_unlocked || assert_eq "stale lock replaced and removed" removed "still locked"
assert_eq "stale lock: graphify ran" 1 "$(count)"

reset; mkdir -p "$sdir"; touch -d '30 seconds ago' "$lock"
ts_write_config '{"enforcement":"always","state_dir":"~/st","tools":{"graphify":{"required":true}},"worktree":{"bootstrap_graphify":true,"bootstrap_timeout_seconds":10}}'
ts_gate $S "" "$repo"; expect_silent "lock older than a short configured timeout"
wait_unlocked || assert_eq "short-timeout stale lock removed" removed "still locked"
assert_eq "lock older than configured timeout: graphify ran" 1 "$(count)"

reset; mkdir -p "$sdir"; touch -d '30 seconds ago' "$lock"
ts_write_config '{"enforcement":"always","state_dir":"~/st","tools":{"graphify":{"required":true}},"worktree":{"bootstrap_graphify":true,"bootstrap_timeout_seconds":"soon"}}'
ts_gate $S "" "$repo"; expect_silent "non-numeric timeout falls back to 120s"
settle
assert_eq "30s-old lock honoured under the 120s default" 0 "$(count)"
assert_file_exists "lock kept" "$lock"

# lock whose mtime cannot be read counts as ancient
reset; mkdir -p "$sdir"; touch "$lock"
ts_write_config "$CFG"
tl_stub stat 'exit 1'
ts_gate $S "" "$repo"; expect_silent "unreadable lock mtime"
wait_unlocked || assert_eq "lock replaced" removed "still locked"
assert_eq "unreadable mtime: graphify ran" 1 "$(count)"
rm -f "$TL_BIN/stat"

# --- config reads failing fall back to defaults ---
real_jq="$(command -v jq)"
tl_stub jq "case \"\$*\" in *bootstrap_timeout_seconds*|*graphify_update_args*) exit 1 ;; esac; exec $real_jq \"\$@\""
reset
ts_gate $S "" "$repo"; expect_silent "timeout/args reads fail"
wait_unlocked || assert_eq "lock removed" removed "still locked"
assert_eq "defaults used when config reads fail" "update . --no-cluster" "$(cat "$calls")"
rm -f "$TL_BIN/jq"

# --- unusable state dir: the job cannot log, graphify never runs ---
reset; printf x >"$HOME/st"
ts_gate $S "" "$repo"; expect_silent "state dir is a file"
settle
assert_eq "no log possible: graphify not run" 0 "$(count)"
rm -f "$HOME/st"

# --- project root vanishes before the job starts ---
reset
tl_stub jq "case \"\$*\" in *bootstrap_timeout_seconds*) $real_jq \"\$@\"; rm -rf '$repo'; exit 0 ;; esac; exec $real_jq \"\$@\""
ts_gate $S "" "$repo"; expect_silent "repo removed mid-run"
settle
assert_eq "job gave up without running graphify" 0 "$(count)"
assert_file_exists "job left its lock behind (never reached cleanup)" "$lock"
rm -f "$TL_BIN/jq"

tl_results
