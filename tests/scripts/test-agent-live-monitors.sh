#!/usr/bin/env bash
# agent-{claude,codex,opencode,pi}/monitor.sh: argument handling, single scan (--once) and the
# bounded watch loop. The loop is ended by a `sleep` stub that fails (errexit stops the monitor)
# - no process is ever signalled and nothing waits on real time.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

SCRIPTS="$TL_REPO_ROOT/scripts"
REAL_TAIL="$(command -v tail)"
LOGDIR="$TL_TMP/logs"
mkdir -p "$LOGDIR"

# host | env prefix | prompt marker unique to the host | signal text unique to the host
HOSTS=(
  "claude|CLAUDE|prompt submitted|Queued follow-up"
  "codex|CODEX|Submitted prompt|hooks need review"
  "opencode|OPENCODE|opencode run|ERROR:boom"
  "pi|PI|pi -p|ERROR:boom"
)

pad() { head -c "$1" /dev/zero | tr '\0' 'x'; }

for entry in "${HOSTS[@]}"; do
  IFS='|' read -r host pfx prompt_marker signal_text <<<"$entry"
  MON="$SCRIPTS/agent-$host/monitor.sh"
  FLOOR_VAR="SB_AGENT_${pfx}_LOG_FLOOR"
  log="$LOGDIR/$host.log"

  # --- argument handling
  tl_run bash "$MON" --help
  assert_eq "$host monitor --help exits 0" "0" "$TL_STATUS"
  assert_contains "$host monitor --help usage" "$TL_OUT" "Usage: monitor.sh --log PATH"

  tl_run bash "$MON"
  assert_eq "$host monitor without --log exits 2" "2" "$TL_STATUS"
  assert_contains "$host monitor without --log prints usage" "$TL_ERR" "Usage: monitor.sh --log PATH"

  tl_run bash "$MON" --nope
  assert_eq "$host monitor unknown arg exits 2" "2" "$TL_STATUS"
  assert_contains "$host monitor unknown arg named" "$TL_ERR" "unknown argument: --nope"

  tl_run bash "$MON" --log "$log" --interval abc
  assert_eq "$host monitor non-numeric --interval exits 2" "2" "$TL_STATUS"
  assert_contains "$host monitor non-numeric --interval message" "$TL_ERR" "--interval must be numeric"

  tl_run bash "$MON" --log "$log" --stall-sec 1x
  assert_eq "$host monitor non-numeric --stall-sec exits 2" "2" "$TL_STATUS"
  assert_contains "$host monitor non-numeric --stall-sec message" "$TL_ERR" "--stall-sec must be numeric"

  # a value flag given last must be a clear usage error, not an unbound-variable crash
  for flag in --log --interval --stall-sec; do
    tl_run bash "$MON" "$flag"
    assert_eq "$host monitor $flag without value exits 2" "2" "$TL_STATUS"
    assert_contains "$host monitor $flag without value message" "$TL_ERR" "$flag requires a value"
    assert_not_contains "$host monitor $flag without value is not an unbound crash" "$TL_ERR" "unbound variable"
  done

  # --- single scan
  rm -f "$log"
  tl_run bash "$MON" --log "$log" --once
  assert_eq "$host --once on a missing log exits 0" "0" "$TL_STATUS"
  assert_eq "$host --once on a missing log prints nothing" "" "$TL_OUT"

  printf 'hello world\n' >"$log"
  tl_run env "$FLOOR_VAR=" bash "$MON" --log "$log" --once --stall-sec 99999
  assert_eq "$host --once small log exits 0" "0" "$TL_STATUS"
  assert_match "$host --once small log reports activity" "\[agent-$host monitor\] [0-9:]+Z — • activity \+12 B \(total 12 B\)" "$TL_OUT"
  assert_not_contains "$host --once small log has no prompt bullet" "$TL_OUT" "prompt submitted (checkpoint"
  assert_not_contains "$host --once small log has no signal" "$TL_OUT" "signal:"
  assert_not_contains "$host --once small log is below the default floor, no floor bullet" "$TL_OUT" "log floor met"
  assert_not_contains "$host --once growth is not a stall" "$TL_OUT" "idle"

  {
    printf '%s accepted\n' "$prompt_marker"
    printf '%s seen\n' "$signal_text"
    pad 600
    printf '\n'
  } >"$log"
  tl_run env "$FLOOR_VAR=" bash "$MON" --log "$log" --once --stall-sec 99999
  assert_contains "$host --once reports the prompt checkpoint" "$TL_OUT" "• prompt submitted (checkpoint 1 satisfied)"
  assert_contains "$host --once reports the host-specific signal" "$TL_OUT" "• signal: ${signal_text}"
  assert_match "$host --once reports the default floor" "log floor met \([0-9]+ B ≥ 512 B\)" "$TL_OUT"

  # the floor comes from the host-specific environment variable
  tl_run env "$FLOOR_VAR=5" bash "$MON" --log "$log" --once --stall-sec 99999
  assert_contains "$host --once honours $FLOOR_VAR" "$TL_OUT" "≥ 5 B)"

  # an idle log (no growth since start) with --stall-sec 0 raises the stall bullet
  : >"$log"
  tl_run bash "$MON" --log "$log" --once --stall-sec 0
  assert_match "$host --once stall bullet" "• idle [0-9]+s — prepare stuck escalation \(checkpoint 2\)" "$TL_OUT"
  : >"$log"
  tl_run bash "$MON" --log "$log" --once --stall-sec 99999
  assert_not_contains "$host --once no stall before the window" "$TL_OUT" "idle"

  # --- watch loop, ended by a failing sleep stub
  SLEEP_COUNT="$TL_TMP/sleep-count-$host"
  SLEEP_ARGS="$TL_TMP/sleep-args-$host"
  : >"$SLEEP_COUNT"
  : >"$SLEEP_ARGS"
  printf '0123456789' >"$log"
  tl_stub sleep "
printf '%s\\n' \"\$*\" >>'$SLEEP_ARGS'
printf x >>'$SLEEP_COUNT'
n=\$(wc -c <'$SLEEP_COUNT')
if [ \"\$n\" -eq 2 ]; then printf 'more-bytes' >>'$log'; fi
if [ \"\$n\" -ge 3 ]; then exit 9; fi
exit 0"
  tl_run timeout 20 bash "$MON" --log "$log" --interval 7 --stall-sec 0
  assert_eq "$host loop ends with the failing sleep's status" "9" "$TL_STATUS"
  assert_contains "$host loop announces what it watches" "$TL_OUT" "watching $log (interval 7s, stall 0s)"
  assert_eq "$host loop slept three times for the interval" "7 7 7" "$(tr '\n' ' ' <"$SLEEP_ARGS" | sed 's/ $//')"
  idle_count="$(grep -c 'prepare stuck escalation' <<<"$TL_OUT" || true)"
  assert_eq "$host loop warns about a stall once per quiet period" "1" "$idle_count"
  below_count="$(grep -c 'below log floor (10 B < 512 B)' <<<"$TL_OUT" || true)"
  assert_eq "$host loop flags the sub-floor log while stalled (not after growth)" "1" "$below_count"
  assert_contains "$host loop reports growth after the stall" "$TL_OUT" "• activity +10 B (total 20 B)"
  assert_contains "$host loop says not to claim PASS" "$TL_OUT" "do not claim PASS"
  rm -f "$TL_BIN/sleep"
done

# ---- host-specific signal quirks
# codex/opencode/pi accept a signal word in the guard that the extraction pattern does not
# capture ('not logged in' for codex, 'auth' for opencode/pi): the bullet falls back to "anomaly".
printf 'You are not logged in\n' >"$LOGDIR/codex-q.log"
tl_run bash "$SCRIPTS/agent-codex/monitor.sh" --log "$LOGDIR/codex-q.log" --once --stall-sec 99999
assert_contains "codex 'not logged in' falls back to anomaly" "$TL_OUT" "• signal: anomaly"
for host in opencode pi; do
  printf 'auth token rejected\n' >"$LOGDIR/$host-q.log"
  tl_run bash "$SCRIPTS/agent-$host/monitor.sh" --log "$LOGDIR/$host-q.log" --once --stall-sec 99999
  assert_contains "$host 'auth' falls back to anomaly" "$TL_OUT" "• signal: anomaly"
done

# claude: the extraction pipeline failing (tail unavailable) also falls back to anomaly.
printf 'rate limit hit\n' >"$LOGDIR/claude-t.log"
tl_stub tail "
for a in \"\$@\"; do
  if [ \"\$a\" = -1 ]; then exit 1; fi
done
exec '$REAL_TAIL' \"\$@\""
tl_run bash "$SCRIPTS/agent-claude/monitor.sh" --log "$LOGDIR/claude-t.log" --once --stall-sec 99999
assert_eq "claude monitor survives a failing signal extraction" "0" "$TL_STATUS"
assert_contains "claude failed extraction reports anomaly" "$TL_OUT" "• signal: anomaly"
rm -f "$TL_BIN/tail"

# a failing tail leaves the scan with no content (no prompt, no signal) but still counts bytes
for host in claude codex opencode pi; do
  printf 'Prompt submitted\nrate limit\n' >"$LOGDIR/tail-$host.log"
  tl_stub tail 'exit 1'
  tl_run bash "$SCRIPTS/agent-$host/monitor.sh" --log "$LOGDIR/tail-$host.log" --once --stall-sec 99999
  assert_eq "$host monitor survives a failing tail" "0" "$TL_STATUS"
  assert_contains "$host monitor still reports activity without content" "$TL_OUT" "• activity +"
  assert_not_contains "$host monitor reports no prompt without content" "$TL_OUT" "prompt submitted (checkpoint"
  assert_not_contains "$host monitor reports no signal without content" "$TL_OUT" "signal:"
  rm -f "$TL_BIN/tail"
done

tl_results
