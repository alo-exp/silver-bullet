#!/usr/bin/env bash
# hooks/kay-project-hook-bridge.sh: overlapping denials with DIFFERENT call ids share
# one lock per path (original mode captured once, restored by the last holder).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

BRIDGE="$TL_REPO_ROOT/hooks/kay-project-hook-bridge.sh"
export SILVER_BULLET_TEST_HOOK_ENFORCED=1
unset CODE_HOOK_EVENT CODE_HOOK_PAYLOAD CODE_HOOK_SOURCE_CALL_ID CODE_HOOK_CALL_ID KAY_HOME \
  SB_KAY_HOOK_BRIDGE_DEBUG SB_KAY_HOOK_BRIDGE_LEGACY_FALLBACK

PLUG="$TL_TMP/plugin"
WORK="$TL_TMP/work"
BHOME="$TL_TMP/bhome"
mkdir -p "$PLUG/hooks" "$WORK" "$BHOME"
ln -s "$TL_REPO_ROOT/hooks/lib" "$PLUG/hooks/lib"
BR="$BHOME/.kay/.silver-bullet/kay-hook-bridge"

printf '#!/usr/bin/env bash\ncat >/dev/null; echo "stderr reason" >&2; exit 2\n' >"$TL_TMP/deny2"
chmod +x "$TL_TMP/deny2"
jq -cn --arg c "$TL_TMP/deny2" '{hooks:{PreToolUse:[{matcher:"Bash|Write",hooks:[{type:"command",command:$c}]}]}}' >"$PLUG/hooks/hooks.json"

run_bridge() { # event payload call-id [cwd]
  tl_run bash -c 'cd "$1" && exec env HOME="$2" CLAUDE_PLUGIN_ROOT="$3" CODE_HOOK_EVENT="$4" CODE_HOOK_PAYLOAD="$5" CODE_HOOK_SOURCE_CALL_ID="$6" bash "$7"' \
    _ "${4:-$WORK}" "$BHOME" "$PLUG" "$1" "$2" "$3" "$BRIDGE"
}
deny_file() { run_bridge file.before_write "$(jq -cn --arg p "$1" '{changes:[{path:$p}]}')" "$2"; }
after() { run_bridge tool.after '{"command":"x"}' "$1"; }

mkdir -p "$WORK/d"
chmod 755 "$WORK/d"

# ---- one file, three overlapping denials, every completion order
# orders are space-separated lists of ids to complete (after events), in sequence
for order in "a b c" "c b a" "b a c" "b c a" "a c b" "c a b"; do
  printf 'x' >"$WORK/d/f.txt"; chmod 644 "$WORK/d/f.txt"
  for id in a b c; do deny_file "$WORK/d/f.txt" "ov-$id"; done
  assert_eq "[$order] three denials lock the file" "444" "$(stat -c %a "$WORK/d/f.txt")"
  for id in $order; do after "ov-$id"; done
  assert_eq "[$order] file restored to its original mode" "644" "$(stat -c %a "$WORK/d/f.txt")"
done

# ---- partial completion keeps the lock until the last holder releases
deny_file "$WORK/d/f.txt" ph1
deny_file "$WORK/d/f.txt" ph2
after ph1
assert_eq "one holder left: still locked" "444" "$(stat -c %a "$WORK/d/f.txt")"
after ph2
assert_eq "last holder released: restored" "644" "$(stat -c %a "$WORK/d/f.txt")"

# ---- repo: two denied git commits with different ids
mkdir -p "$WORK/repo"
git -C "$WORK/repo" init -q
GITC="$(jq -cn '{command:"git commit -m x"}')"
repo_modes() { printf '%s %s %s' "$(stat -c %a "$WORK/repo")" "$(stat -c %a "$WORK/repo/.git")" "$(stat -c %a "$WORK/repo/.git/objects")"; }
ORIG_REPO="$(repo_modes)"
for order in "h1 h2" "h2 h1"; do
  run_bridge tool.before "$GITC" h1 "$WORK/repo"
  run_bridge tool.before "$GITC" h2 "$WORK/repo"
  assert_eq "[$order] repo locked after two denials" "2" "$TL_STATUS"
  for id in $order; do after "$id"; done
  assert_eq "[$order] repo modes restored" "$ORIG_REPO" "$(repo_modes)"
done

# ---- file and repo denials overlap on the same directory
printf 'x' >"$WORK/repo/f.txt"; chmod 644 "$WORK/repo/f.txt"
run_bridge tool.before "$GITC" m1 "$WORK/repo"
deny_file "$WORK/repo/f.txt" m2
after m1
after m2
assert_eq "mixed overlap: repo restored" "$ORIG_REPO" "$(repo_modes)"
assert_eq "mixed overlap: file restored" "644" "$(stat -c %a "$WORK/repo/f.txt")"

# ---- session.start / session.end restore everything regardless of holders
for ev in session.start session.end; do
  run_bridge tool.before "$GITC" s1 "$WORK/repo"
  run_bridge tool.before "$GITC" s2 "$WORK/repo"
  deny_file "$WORK/repo/f.txt" s3
  after s1
  run_bridge "$ev" '{}' sx
  assert_eq "$ev: repo restored with holders still live" "$ORIG_REPO" "$(repo_modes)"
  assert_eq "$ev: file restored with holders still live" "644" "$(stat -c %a "$WORK/repo/f.txt")"
  assert_eq "$ev: no state left" "" "$(ls "$BR/blocks")"
done

# the original mode is never replaced by an already-locked mode: a path locked
# once, then denied again by a new id after the first released, is locked again
# from its true original.
deny_file "$WORK/d/f.txt" r1
after r1
deny_file "$WORK/d/f.txt" r2
after r2
assert_eq "re-lock after release restores the true original" "644" "$(stat -c %a "$WORK/d/f.txt")"

# a path whose write bits were re-enabled outside the bridge (a stale lock record
# remains) is locked again by the next denial, and still restores the TRUE original
printf 'x' >"$WORK/d/g.txt"; chmod 640 "$WORK/d/g.txt"
deny_file "$WORK/d/g.txt" st1
assert_eq "first denial locks" "440" "$(stat -c %a "$WORK/d/g.txt")"
chmod u+w "$WORK/d/g.txt"
deny_file "$WORK/d/g.txt" st2
assert_eq "a re-enabled path is locked again by the next denial" "440" "$(stat -c %a "$WORK/d/g.txt")"
after st1
assert_eq "one holder left after the re-lock" "440" "$(stat -c %a "$WORK/d/g.txt")"
after st2
assert_eq "last holder restores the true original mode" "640" "$(stat -c %a "$WORK/d/g.txt")"
# an already read-only original joined by a second holder is left alone
printf 'x' >"$WORK/d/h.txt"; chmod 444 "$WORK/d/h.txt"
deny_file "$WORK/d/h.txt" ro1
deny_file "$WORK/d/h.txt" ro2
after ro1; after ro2
assert_eq "read-only original stays read-only" "444" "$(stat -c %a "$WORK/d/h.txt")"

tl_results
