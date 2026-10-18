#!/usr/bin/env bash
# scripts/lib/agent-mode.sh part 1: reason codes, failure helpers, flag parsing, env inheritance,
# preflight conflicts, pid identity and the small JSON/result helpers. The library is sourced
# into the test shell; process probes (kill, ps) are shell-function stubs that record their args.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

LIB="$TL_REPO_ROOT/scripts/lib/agent-mode.sh"
# shellcheck source=../../scripts/lib/agent-mode.sh
source "$LIB"
CLEAN_ENV=(SB_AGENT_INTERACTION_MODE SB_AGENT_ALLOW_MODE_FALLBACK SB_AGENT_MODE_ATTACH SB_AGENT_NO_ESCALATE SB_AGENT_AUTO_POLICY
  SB_AGENT_MAX_TURNS SB_AGENT_MAX_WALL_SEC SB_AGENT_IDLE_SEC)
fresh() { agent_mode_reset; unset "${CLEAN_ENV[@]}" 2>/dev/null || true; }
unset "${CLEAN_ENV[@]}" 2>/dev/null || true

# ---------------- reason codes ----------------
fresh
for r in pin tui-unavailable mode-unavailable incomplete result-missing escalate-unavailable escalated d3-process-alive d3-continue \
  d3-in-wave-cursor classifier-interactive classifier-ni fallback_drop:attach fallback_drop:control-dir fallback_drop:max-turns \
  fallback_drop:auto-policy "mode_fallback:interactive→non-interactive:tui-unavailable:x"; do
  agent_mode_reason_ok "$r" && tl_pass "reason ok: $r" || tl_fail "reason ok: $r"
done
agent_mode_reason_ok bogus && tl_fail "reason bogus accepted" || tl_pass "reason bogus rejected"
tl_run agent_mode_reason_append bogus
assert_eq "append invalid reason fails" 1 "$TL_STATUS"
assert_contains "append invalid reason message" "$TL_ERR" "ERROR: invalid mode.json reason code: bogus"
agent_mode_reason_append pin; agent_mode_reason_append pin; agent_mode_reason_append escalated
assert_eq "append dedupes" "pin escalated" "${SB_AM_REASONS[*]}"
agent_mode_reason_has pin && tl_pass "reason_has present" || tl_fail "reason_has present"
agent_mode_reason_has nope && tl_fail "reason_has absent" || tl_pass "reason_has absent"
assert_eq "reasons json" '["pin", "escalated"]' "$(agent_mode_reasons_json)"
fresh
assert_eq "reasons json empty" '[]' "$(agent_mode_reasons_json)"

# ---------------- failure helpers ----------------
fresh
tl_run agent_mode_fail_conflict some-detail
assert_eq "conflict returns 2" 2 "$TL_STATUS"
assert_contains "conflict message" "$TL_ERR" "ERROR: mode-conflict (some-detail)"
assert_eq "conflict class" mode-conflict "$SB_AM_FAILURE_CLASS"
assert_eq "conflict detail recorded" some-detail "$SB_AM_CONFLICT_DETAIL"
fresh
TD="$TL_TMP/task"
SB_AM_TASK_DIR="$TD"
tl_run agent_mode_fail_unavailable
assert_eq "unavailable returns 3" 3 "$TL_STATUS"
assert_eq "unavailable default class" mode-unavailable "$SB_AM_FAILURE_CLASS"
assert_contains "unavailable records the reason" "${SB_AM_REASONS[*]}" "mode-unavailable"
assert_eq "unavailable persists mode.json" '["mode-unavailable"]' "$(jq -c .reason "$TD/mode.json")"
fresh
tl_run agent_mode_fail_unavailable escalate-unavailable
assert_eq "other class does not touch reasons" 0 "${#SB_AM_REASONS[@]}"
assert_contains "other class printed" "$TL_ERR" "ERROR: escalate-unavailable"
# failures inside the helper are tolerated
fresh; SB_AM_TASK_DIR="$TD/x"
agent_mode_reason_append() { return 1; }
agent_mode_persist_mode_json() { return 1; }
tl_run agent_mode_fail_unavailable
assert_eq "unavailable tolerates reason + persist failures" 3 "$TL_STATUS"
# shellcheck source=../../scripts/lib/agent-mode.sh
source "$LIB"

# ---------------- permission mode ----------------
fresh
agent_mode_note_permission_mode permissive; assert_eq "permission permissive" permissive "$SB_AM_PERMISSION_MODE"
agent_mode_note_permission_mode strict; assert_eq "permission strict" strict "$SB_AM_PERMISSION_MODE"
rc=0; agent_mode_note_permission_mode "" || rc=$?; assert_eq "permission empty is a no-op" 0 "$rc"
assert_eq "permission empty keeps the value" strict "$SB_AM_PERMISSION_MODE"
for v in auto interactive non-interactive; do
  tl_run agent_mode_note_permission_mode "$v"
  assert_eq "permission $v smashed (2)" 2 "$TL_STATUS"
  assert_contains "permission $v message" "$TL_ERR" "permission-mode-smashed"
done
tl_run agent_mode_note_permission_mode weird
assert_eq "permission invalid" 2 "$TL_STATUS"
assert_contains "permission invalid message" "$TL_ERR" "invalid-permission-mode"

# ---------------- handle_flag ----------------
flag() { fresh; agent_mode_handle_flag "$@"; }
rc=0; flag --interaction-mode auto || rc=$?
assert_eq "interaction-mode auto consumed" "0 2 auto 1 0" "$rc $SB_AM_SHIFT $SB_AM_REQUESTED $SB_AM_SAW_AUTO $SB_AM_CONCRETE_PIN"
flag --interaction-mode interactive
assert_eq "interaction-mode interactive" "interactive 1 1" "$SB_AM_REQUESTED $SB_AM_CONCRETE_PIN $SB_AM_PIN_INTERACTIVE"
flag --interaction-mode non-interactive
assert_eq "interaction-mode non-interactive" "non-interactive 1 1" "$SB_AM_REQUESTED $SB_AM_CONCRETE_PIN $SB_AM_PIN_NI"
tl_run flag --interaction-mode
assert_eq "interaction-mode needs a value" 2 "$TL_STATUS"
assert_contains "interaction-mode missing value message" "$TL_ERR" "missing-interaction-mode-value"
tl_run flag --interaction-mode bogus
assert_eq "interaction-mode invalid value" 2 "$TL_STATUS"
assert_contains "interaction-mode invalid message" "$TL_ERR" "invalid-interaction-mode"
flag --interactive; assert_eq "--interactive alias" "interactive 1 1" "$SB_AM_REQUESTED $SB_AM_ALIAS_IX $SB_AM_PIN_INTERACTIVE"
flag --non-interactive; assert_eq "--non-interactive alias" "non-interactive 1 1" "$SB_AM_REQUESTED $SB_AM_ALIAS_NI $SB_AM_PIN_NI"
flag --use-print; assert_eq "--use-print legacy" "non-interactive 1" "$SB_AM_REQUESTED $SB_AM_LEGACY_NI"
flag --use-exec; assert_eq "--use-exec legacy" "non-interactive 1" "$SB_AM_REQUESTED $SB_AM_LEGACY_NI"
flag --use-interactive; assert_eq "--use-interactive legacy" "interactive 1" "$SB_AM_REQUESTED $SB_AM_LEGACY_IX"
flag --attach; assert_eq "--attach" 1 "$SB_AM_ATTACH"
flag --no-escalate; assert_eq "--no-escalate" "1 1" "$SB_AM_NO_ESCALATE $SB_AM_SHIFT"
flag --allow-mode-fallback; assert_eq "--allow-mode-fallback" "1 allow-mode-fallback" "$SB_AM_ALLOW_FALLBACK $SB_AM_FALLBACK_VIA"
flag --auto-policy parent; assert_eq "--auto-policy parent" "parent 2" "$SB_AM_AUTO_POLICY $SB_AM_SHIFT"
flag --auto-policy brief_only; assert_eq "--auto-policy brief_only" "brief_only" "$SB_AM_AUTO_POLICY"
flag --auto-policy supervised; assert_eq "--auto-policy supervised" "supervised" "$SB_AM_AUTO_POLICY"
tl_run flag --auto-policy nonsense
assert_eq "--auto-policy invalid" 2 "$TL_STATUS"
assert_contains "--auto-policy invalid message" "$TL_ERR" "invalid-auto-policy"
flag --control-dir /c; assert_eq "--control-dir" "/c 2" "$SB_AM_CONTROL_DIR $SB_AM_SHIFT"
flag --max-turns 5; assert_eq "--max-turns" "5 2" "$SB_AM_MAX_TURNS $SB_AM_SHIFT"
flag --max-wall-sec 90; assert_eq "--max-wall-sec" "90 2" "$SB_AM_MAX_WALL_SEC $SB_AM_SHIFT"
flag --idle-sec 30; assert_eq "--idle-sec" "30 2" "$SB_AM_IDLE_SEC $SB_AM_SHIFT"
flag --task-id t-7; assert_eq "--task-id" "t-7 2" "$SB_AM_TASK_ID $SB_AM_SHIFT"
flag --quota-retry; assert_eq "--quota-retry" 1 "$SB_AM_QUOTA_RETRY"
flag --skip-preflight; assert_eq "--skip-preflight" 1 "$SB_AM_SKIP_PREFLIGHT"
rc=0; flag --delegation-mode x || rc=$?; assert_eq "--delegation-mode not consumed" 1 "$rc"
rc=0; flag --other || rc=$?; assert_eq "unknown flag not consumed" 1 "$rc"

# ---------------- parse_argv ----------------
fresh
agent_mode_parse_argv --prompt hello --max-turns 3 --attach --delegation-mode x tail
assert_eq "parse: unparsed words kept in order" "--prompt hello --delegation-mode x tail" "${SB_AM_UNPARSED[*]}"
assert_eq "parse: flags applied" "3 1" "$SB_AM_MAX_TURNS $SB_AM_ATTACH"
fresh
rc=0; agent_mode_parse_argv --interaction-mode bogus >/dev/null 2>&1 || rc=$?
assert_eq "parse: conflict aborts with 2" 2 "$rc"
fresh
rc=0; agent_mode_parse_argv || rc=$?
assert_eq "parse: empty argv" "0 0" "$rc ${#SB_AM_UNPARSED[@]}"

# ---------------- inherit env / unset consumed ----------------
fresh
SB_AGENT_MODE_ATTACH=1 SB_AGENT_NO_ESCALATE=1 SB_AGENT_ALLOW_MODE_FALLBACK=1 SB_AGENT_AUTO_POLICY=parent SB_AGENT_MAX_TURNS=4 \
  SB_AGENT_MAX_WALL_SEC=120 SB_AGENT_IDLE_SEC=15 agent_mode_inherit_env_flags
assert_eq "inherit: all env flags" "1 1 1 SB_AGENT_ALLOW_MODE_FALLBACK parent 4 120 15" \
  "$SB_AM_ATTACH $SB_AM_NO_ESCALATE $SB_AM_ALLOW_FALLBACK $SB_AM_FALLBACK_VIA $SB_AM_AUTO_POLICY $SB_AM_MAX_TURNS $SB_AM_MAX_WALL_SEC $SB_AM_IDLE_SEC"
fresh
SB_AM_AUTO_POLICY=brief_only SB_AM_MAX_TURNS=2 SB_AM_MAX_WALL_SEC=5 SB_AM_IDLE_SEC=6 SB_AM_FALLBACK_VIA=cli
SB_AGENT_AUTO_POLICY=parent SB_AGENT_MAX_TURNS=9 SB_AGENT_MAX_WALL_SEC=99 SB_AGENT_IDLE_SEC=98 SB_AGENT_ALLOW_MODE_FALLBACK=1 agent_mode_inherit_env_flags
assert_eq "inherit: explicit values win over env" "brief_only 2 5 6 cli" "$SB_AM_AUTO_POLICY $SB_AM_MAX_TURNS $SB_AM_MAX_WALL_SEC $SB_AM_IDLE_SEC $SB_AM_FALLBACK_VIA"
fresh; agent_mode_inherit_env_flags
assert_eq "inherit: nothing set changes nothing" "0 0 0" "$SB_AM_ATTACH $SB_AM_NO_ESCALATE $SB_AM_ALLOW_FALLBACK"
export SB_AGENT_INTERACTION_MODE=x SB_AGENT_MODE_ATTACH=1
agent_mode_unset_consumed_env
assert_eq "unset consumed: variables removed" "" "${SB_AGENT_INTERACTION_MODE:-}${SB_AGENT_MODE_ATTACH:-}"
tl_run bash -c "source '$LIB'; export SB_AGENT_MAX_TURNS=3 SB_AGENT_NO_ESCALATE=1; readonly SB_AGENT_MAX_TURNS; agent_mode_unset_consumed_env; echo rc=\$? turns=\${SB_AGENT_MAX_TURNS:-unset} esc=\${SB_AGENT_NO_ESCALATE:-unset}"
assert_contains "unset consumed: readonly var tolerated" "$TL_OUT" "rc=0 turns=3 esc=unset"

# ---------------- preflight conflicts ----------------
pf() { # run preflight in the current shell; prints nothing, sets TL_*; env via SB_AGENT_INTERACTION_MODE
  tl_run agent_mode_preflight_flags
}
fresh; pf
assert_eq "preflight: clean auto passes" 0 "$TL_STATUS"
assert_eq "preflight: stays auto" auto "$SB_AM_REQUESTED"
fresh; export SB_AGENT_INTERACTION_MODE=auto; pf
assert_eq "preflight: leftover auto passes" 0 "$TL_STATUS"
# preflight unsets consumed env itself; export again for each case
for v in interactive non-interactive weird; do
  fresh; export SB_AGENT_INTERACTION_MODE=$v; pf
  assert_eq "preflight: leftover $v is a conflict" 2 "$TL_STATUS"
  assert_contains "preflight: leftover $v message" "$TL_ERR" "leftover-env-pin"
done
fresh; export SB_AGENT_INTERACTION_MODE=interactive; SB_AM_ARGV_HAS_INTERACTION=1; SB_AM_REQUESTED=interactive; SB_AM_CONCRETE_PIN=1; SB_AM_PIN_INTERACTIVE=1; pf
assert_eq "preflight: env pin ignored when argv pinned" 0 "$TL_STATUS"
conflict() { # <detail> <state assignments...>
  local detail="$1"; shift
  fresh
  local a; for a in "$@"; do eval "$a"; done
  pf
  assert_eq "preflight conflict $detail: exit 2" 2 "$TL_STATUS"
  assert_contains "preflight conflict $detail: message" "$TL_ERR" "mode-conflict ($detail)"
}
conflict opposite-aliases SB_AM_ARGV_HAS_INTERACTION=1 SB_AM_ALIAS_IX=1 SB_AM_ALIAS_NI=1
conflict opposite-legacy-pins SB_AM_ARGV_HAS_INTERACTION=1 SB_AM_LEGACY_NI=1 SB_AM_LEGACY_IX=1
conflict opposite-pins SB_AM_ARGV_HAS_INTERACTION=1 SB_AM_PIN_INTERACTIVE=1 SB_AM_PIN_NI=1
conflict auto-plus-pin SB_AM_ARGV_HAS_INTERACTION=1 SB_AM_SAW_AUTO=1 SB_AM_CONCRETE_PIN=1 SB_AM_REQUESTED=interactive
conflict auto-plus-pin SB_AM_ARGV_HAS_INTERACTION=1 SB_AM_CONCRETE_PIN=1 SB_AM_REQUESTED=auto
conflict fallback-not-pinned SB_AM_ARGV_HAS_INTERACTION=1 SB_AM_REQUESTED=non-interactive SB_AM_ALLOW_FALLBACK=1 SB_AM_CONCRETE_PIN=1
conflict fallback-not-pinned SB_AM_ALLOW_FALLBACK=1
conflict attach-on-ni SB_AM_ARGV_HAS_INTERACTION=1 SB_AM_REQUESTED=non-interactive SB_AM_ATTACH=1
conflict control-dir-on-ni SB_AM_ARGV_HAS_INTERACTION=1 SB_AM_REQUESTED=non-interactive SB_AM_CONTROL_DIR=/c
conflict max-turns-on-ni SB_AM_ARGV_HAS_INTERACTION=1 SB_AM_REQUESTED=non-interactive SB_AM_MAX_TURNS=3
conflict auto-policy-on-ni SB_AM_ARGV_HAS_INTERACTION=1 SB_AM_REQUESTED=non-interactive SB_AM_AUTO_POLICY=parent
fresh; SB_AM_ARGV_HAS_INTERACTION=1 SB_AM_REQUESTED=interactive SB_AM_CONCRETE_PIN=1 SB_AM_ALLOW_FALLBACK=1 SB_AM_ATTACH=1; pf
assert_eq "preflight: interactive pin with fallback and attach passes" 0 "$TL_STATUS"
# env flags are inherited before checks (attach via env conflicts with NI pin)
fresh; SB_AM_ARGV_HAS_INTERACTION=1; SB_AM_REQUESTED=non-interactive; SB_AM_CONCRETE_PIN=1; SB_AM_PIN_NI=1
export SB_AGENT_MODE_ATTACH=1; pf
assert_contains "preflight: inherited env attach conflicts with NI" "$TL_ERR" "attach-on-ni"
unset SB_AGENT_MODE_ATTACH

# ---------------- pid identity (kill/ps stubbed) ----------------
KILL_LOG="$TL_TMP/kill.log"; : >"$KILL_LOG"
LIVE_PIDS=" 4242 "
kill() { echo "kill $*" >>"$KILL_LOG"; [[ "$1" == "-0" && "$LIVE_PIDS" == *" $2 "* ]]; }
ps() { echo "ps $*" >>"$KILL_LOG"; if [[ "$2" == "4242" ]]; then echo "  Mon Jan  1 00:00:00 2026"; fi; }
assert_eq "started_at strips leading blanks" "Mon Jan  1 00:00:00 2026" "$(agent_mode_pid_started_at 4242)"
assert_contains "started_at asks ps for lstart" "$(cat "$KILL_LOG")" "ps -p 4242 -o lstart="
rc=0; agent_mode_pid_alive_identity "" "x" || rc=$?; assert_eq "identity: empty pid" 1 "$rc"
: >"$KILL_LOG"
rc=0; agent_mode_pid_alive_identity 9999 "x" || rc=$?; assert_eq "identity: dead pid" 1 "$rc"
assert_eq "identity: only a signal-0 probe was sent" "kill -0 9999" "$(cat "$KILL_LOG")"
rc=0; agent_mode_pid_alive_identity 4242 "" || rc=$?; assert_eq "identity: live pid without expected start" 1 "$rc"
rc=0; agent_mode_pid_alive_identity 4242 "Tue Feb 2 00:00:00 2026" || rc=$?; assert_eq "identity: start mismatch" 1 "$rc"
rc=0; agent_mode_pid_alive_identity 4242 "Mon Jan  1 00:00:00 2026" || rc=$?; assert_eq "identity: start match" 0 "$rc"
assert_not_contains "identity: never sent a real signal" "$(cat "$KILL_LOG")" "kill -9"
assert_not_contains "identity: never sent TERM" "$(cat "$KILL_LOG")" "kill -15"
unset -f kill ps

# ---------------- json / result helpers ----------------
J="$TL_TMP/j.json"
printf '{"a":{"b":7,"c":null,"d":[1,2],"e":{"x":1}},"s":"str"}' >"$J"
assert_eq "field: missing file empty" "" "$(agent_mode_read_json_field "$TL_TMP/nofile" a)"
assert_eq "field: scalar" "str" "$(agent_mode_read_json_field "$J" s)"
assert_eq "field: nested" "7" "$(agent_mode_read_json_field "$J" a.b)"
assert_eq "field: null is empty" "" "$(agent_mode_read_json_field "$J" a.c)"
assert_eq "field: list as json" "[1, 2]" "$(agent_mode_read_json_field "$J" a.d)"
assert_eq "field: dict as json" '{"x": 1}' "$(agent_mode_read_json_field "$J" a.e)"
assert_eq "field: absent path" "" "$(agent_mode_read_json_field "$J" a.zzz.q)"
printf 'not json' >"$TL_TMP/bad.json"
assert_eq "field: invalid json empty" "" "$(agent_mode_read_json_field "$TL_TMP/bad.json" a)"
printf '{"reason":["x","y"]}' >"$TL_TMP/r.json"
assert_eq "reason list: one per line" "x
y" "$(agent_mode_reason_list_from_file "$TL_TMP/r.json")"
assert_eq "reason list: missing file" "" "$(agent_mode_reason_list_from_file "$TL_TMP/nofile")"
assert_eq "reason list: invalid json" "" "$(agent_mode_reason_list_from_file "$TL_TMP/bad.json")"
printf '{}' >"$TL_TMP/r0.json"
assert_eq "reason list: no reasons" "" "$(agent_mode_reason_list_from_file "$TL_TMP/r0.json")"

NOW_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
agent_mode_iso_within_ttl "$NOW_ISO" 60 && tl_pass "ttl: fresh stamp" || tl_fail "ttl: fresh stamp"
agent_mode_iso_within_ttl "2001-01-01T00:00:00Z" 60 && tl_fail "ttl: stale stamp" || tl_pass "ttl: stale stamp"
agent_mode_iso_within_ttl "" 60 && tl_fail "ttl: empty stamp" || tl_pass "ttl: empty stamp"
agent_mode_iso_within_ttl "garbage" 60 && tl_fail "ttl: garbage stamp" || tl_pass "ttl: garbage stamp"
agent_mode_iso_within_ttl "2001-01-01T00:00:00Z" && tl_fail "ttl: default 24h" || tl_pass "ttl: default 24h applies"

F="$TL_TMP/mtime.txt"; echo x >"$F"
touch -d '2020-06-01 00:00:00 UTC' "$F"
agent_mode_file_newer_than_iso "$TL_TMP/nofile" "2020-01-01T00:00:00Z" && tl_fail "newer: missing file" || tl_pass "newer: missing file"
agent_mode_file_newer_than_iso "$F" "" && tl_pass "newer: no stamp means yes" || tl_fail "newer: no stamp means yes"
agent_mode_file_newer_than_iso "$F" "2020-01-01T00:00:00Z" && tl_pass "newer: file newer than stamp" || tl_fail "newer: file newer than stamp"
agent_mode_file_newer_than_iso "$F" "2021-01-01T00:00:00Z" && tl_fail "newer: file older than stamp" || tl_pass "newer: file older than stamp"

R="$TL_TMP/result.md"
assert_eq "status: missing file" "" "$(agent_mode_result_status "$TL_TMP/nofile")"
printf 'STATUS: PASS\nrest\n' >"$R"; assert_eq "status: STATUS line lowercased" pass "$(agent_mode_result_status "$R")"
printf '## STATUS\nFail\n' >"$R"; assert_eq "status: heading form" fail "$(agent_mode_result_status "$R")"
printf 'nothing\n' >"$R"; assert_eq "status: absent" "" "$(agent_mode_result_status "$R")"

tl_results
