#!/usr/bin/env bash
# scripts/lib/agent-mode.sh part 2: D3 detection, classifier, TUI gate, resolution, mode.json
# persistence, artifact dirs, launch env, escalation, fifo control ops and the end-to-end
# delegate resolver. kill/ps are function stubs; the fifo reader is an O_RDWR descriptor held by
# the test, so no background process is ever started.
# shellcheck disable=SC2034  # SB_AM_* state is read by the sourced library
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

LIB="$TL_REPO_ROOT/scripts/lib/agent-mode.sh"
# shellcheck source=../../scripts/lib/agent-mode.sh
source "$LIB"
CLEAN_ENV=(SB_AGENT_INTERACTION_MODE SB_AGENT_ALLOW_MODE_FALLBACK SB_AGENT_MODE_ATTACH SB_AGENT_NO_ESCALATE SB_AGENT_AUTO_POLICY
  SB_AGENT_MAX_TURNS SB_AGENT_MAX_WALL_SEC SB_AGENT_IDLE_SEC SB_AGENT_MODE_TUI_AVAILABLE SB_AGENT_TASK_DIR SB_AGENT_CONTROL_DIR
  SB_AGENT_RESOLVED_MODE SB_AGENT_REQUESTED_MODE MODE)
fresh() { agent_mode_reset; unset "${CLEAN_ENV[@]}" 2>/dev/null || true; }
now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

KILL_LOG="$TL_TMP/kill.log"; : >"$KILL_LOG"
LIVE_PIDS=" 4242 "
kill() { echo "kill $*" >>"$KILL_LOG"; [[ "$1" == "-0" && "$LIVE_PIDS" == *" $2 "* ]]; }
ps() { if [[ "$2" == "4242" ]]; then echo " Mon Jan  1 00:00:00 2026"; fi; }

mk_session() { # <task_dir> <status> <conv> <pid> <started> <updated>
  mkdir -p "$1"
  jq -n --arg s "$2" --arg c "$3" --arg p "$4" --arg st "$5" --arg u "$6" \
    '{status:$s, updated_at:$u} + (if $c!="" then {conversation_id:$c} else {} end) + (if $p!="" then {pid:($p|tonumber)} else {} end) + (if $st!="" then {pid_started_at:$st} else {} end)' >"$1/session.json"
}

# ---------------- detect_d3 ----------------
T1="$TL_TMP/d3"
fresh; rc=0; agent_mode_detect_d3 "$T1" claude "continue" || rc=$?
assert_eq "d3: no session.json" 1 "$rc"
assert_eq "d3: no signal" "" "$SB_AM_D3_SIGNAL"
# live child with a control dir -> process-alive
mk_session "$T1" live conv-1 4242 "Mon Jan  1 00:00:00 2026" "$(now)"; mkdir -p "$T1/control"
fresh; rc=0; agent_mode_detect_d3 "$T1" claude || rc=$?
assert_eq "d3: live child with control dir" "0 process-alive" "$rc $SB_AM_D3_SIGNAL"
# live child without control dir -> orphan: session reset to dead, conversation kept, classify fresh
rmdir "$T1/control"
fresh; rc=0; agent_mode_detect_d3 "$T1" claude || rc=$?
assert_eq "d3: orphaned driver returns 1" 1 "$rc"
assert_eq "d3: orphan session marked dead" "dead" "$(jq -r .status "$T1/session.json")"
assert_eq "d3: orphan keeps resume token" "conv-1" "$(jq -r .conversation_id "$T1/session.json")"
assert_eq "d3: orphan clears liveness" "null" "$(jq -r '.pid // "null"' "$T1/session.json")"
# stale session (ttl) with dead pid
mk_session "$T1" live conv-1 9999 "x" "2001-01-01T00:00:00Z"
fresh; rc=0; agent_mode_detect_d3 "$T1" cursor "continue" || rc=$?
assert_eq "d3: expired ttl ignores everything else" 1 "$rc"
# cursor in-wave
mk_session "$T1" live conv-1 9999 "x" "$(now)"
fresh; rc=0; agent_mode_detect_d3 "$T1" cursor || rc=$?
assert_eq "d3: cursor live conversation" "0 in-wave-cursor" "$rc $SB_AM_D3_SIGNAL"
fresh; rc=0; agent_mode_detect_d3 "$T1" claude || rc=$?
assert_eq "d3: non-cursor live conversation without utterance" 1 "$rc"
for u in "please continue" "Coach me" "keep going now"; do
  fresh; rc=0; agent_mode_detect_d3 "$T1" claude "$u" || rc=$?
  assert_eq "d3: utterance '$u'" "0 continue" "$rc $SB_AM_D3_SIGNAL"
done
fresh; rc=0; agent_mode_detect_d3 "$T1" claude "continuously improve" || rc=$?
assert_eq "d3: partial word is not a continue" 1 "$rc"
mk_session "$T1" dead "" 9999 "x" "$(now)"
fresh; rc=0; agent_mode_detect_d3 "$T1" claude "continue" || rc=$?
assert_eq "d3: continue needs a conversation id" 1 "$rc"

# ---------------- session json writer ----------------
agent_mode_write_session_json "$TL_TMP/sess/s.json" live c1 77 "start" 3 "2026-01-01T00:00:00Z"
assert_eq "session json: all fields" "live|c1|77|start|3|2026-01-01T00:00:00Z" \
  "$(jq -r '[.status,.conversation_id,.pid,.pid_started_at,.turns,.wave_started_at]|join("|")' "$TL_TMP/sess/s.json")"
agent_mode_write_session_json "$TL_TMP/sess/s2.json" dead "" "" "" "" ""
assert_eq "session json: only status/updated_at when empty" "status,updated_at" "$(jq -r 'keys_unsorted|join(",")' "$TL_TMP/sess/s2.json")"
agent_mode_write_session_json "$TL_TMP/sess/s3.json" live c abc "" "" ""
assert_eq "session json: non-numeric pid kept as string" "abc" "$(jq -r .pid "$TL_TMP/sess/s3.json")"

# ---------------- pending_escalate ----------------
PE="$TL_TMP/pe"; mkdir -p "$PE"
write_mode() { jq -n --arg r "$1" --arg c "$2" --arg s "$3" --argjson reason "$4" '{requested:$r,classified:$c,resolved:$s,reason:$reason}' >"$PE/mode.json"; }
rc=0; agent_mode_pending_escalate "$PE" || rc=$?; assert_eq "pending: no files" 1 "$rc"
write_mode auto non-interactive non-interactive '[]'; echo esc >"$PE/escalation.md"; printf '## STATUS\nfail\n' >"$PE/result.md"
rc=0; agent_mode_pending_escalate "$PE" || rc=$?; assert_eq "pending: fail result" 0 "$rc"
printf 'STATUS: blocked\n' >"$PE/result.md"
rc=0; agent_mode_pending_escalate "$PE" || rc=$?; assert_eq "pending: blocked result" 0 "$rc"
printf 'STATUS: pass\n' >"$PE/result.md"
rc=0; agent_mode_pending_escalate "$PE" || rc=$?; assert_eq "pending: pass result" 1 "$rc"
rm "$PE/result.md"
rc=0; agent_mode_pending_escalate "$PE" || rc=$?; assert_eq "pending: no result file" 1 "$rc"
printf 'STATUS: fail\n' >"$PE/result.md"
write_mode interactive non-interactive non-interactive '[]'
rc=0; agent_mode_pending_escalate "$PE" || rc=$?; assert_eq "pending: requested not auto" 1 "$rc"
for r in tui-unavailable escalate-unavailable escalated; do
  write_mode auto non-interactive non-interactive "[\"$r\"]"
  rc=0; agent_mode_pending_escalate "$PE" || rc=$?; assert_eq "pending: already $r" 1 "$rc"
done

# ---------------- d4 eligibility ----------------
fresh
agent_mode_d4_eligible_from_state auto non-interactive non-interactive && tl_pass "d4: eligible" || tl_fail "d4: eligible"
agent_mode_d4_eligible_from_state auto interactive non-interactive && tl_fail "d4: classified interactive" || tl_pass "d4: classified interactive"
agent_mode_reason_append tui-unavailable
agent_mode_d4_eligible_from_state auto non-interactive non-interactive && tl_fail "d4: tui-unavailable blocks" || tl_pass "d4: tui-unavailable blocks"

# ---------------- classify_task ----------------
CT="$TL_TMP/ct"; mkdir -p "$CT"
cls() { fresh; agent_mode_classify_task "$@"; }
cls "plain brief" "$CT" claude ""
assert_eq "classify: default NI" "non-interactive classifier-ni" "$SB_AM_CLASSIFIED ${SB_AM_REASONS[*]}"
for kw in checkpoint coaching picker "ask me" clarification "q&a" "permission picker" "multi-step"; do
  cls "please do $kw first" "$CT" claude ""
  assert_eq "classify: keyword '$kw'" "interactive classifier-interactive" "$SB_AM_CLASSIFIED ${SB_AM_REASONS[*]}"
done
cls "brief" "$CT" claude "Checkpoint with me"
assert_eq "classify: keyword in utterance" "interactive" "$SB_AM_CLASSIFIED"
cls "brief" "$CT" claude "Coach"
assert_eq "classify: coach utterance" "interactive classifier-interactive" "$SB_AM_CLASSIFIED ${SB_AM_REASONS[*]}"
cls "brief" "$CT" claude "keep going please"
assert_eq "classify: keep going utterance" "interactive" "$SB_AM_CLASSIFIED"
assert_eq "classify: utterance recorded" "keep going please" "$SB_AM_UTTERANCE"
# pending escalate wins unless disabled
write_mode auto non-interactive non-interactive '[]'; printf 'STATUS: fail\n' >"$PE/result.md"
cls "brief" "$PE" claude ""
assert_eq "classify: pending escalation => interactive" "interactive classifier-interactive" "$SB_AM_CLASSIFIED ${SB_AM_REASONS[*]}"
fresh; SB_AM_NO_ESCALATE=1; agent_mode_classify_task "brief" "$PE" claude ""
assert_eq "classify: --no-escalate ignores pending escalation" "non-interactive" "$SB_AM_CLASSIFIED"
# D3 signals become reasons
mk_session "$CT" live c 4242 "Mon Jan  1 00:00:00 2026" "$(now)"; mkdir -p "$CT/control"
cls "brief" "$CT" claude ""
assert_eq "classify: d3 process-alive reason" "interactive d3-process-alive" "$SB_AM_CLASSIFIED ${SB_AM_REASONS[*]}"
mk_session "$CT" dead c 9999 x "$(now)"; rmdir "$CT/control"
cls "brief" "$CT" claude "continue"
assert_eq "classify: d3 continue reason" "interactive d3-continue" "$SB_AM_CLASSIFIED ${SB_AM_REASONS[*]}"
mk_session "$CT" live c 9999 x "$(now)"
cls "brief" "$CT" cursor ""
assert_eq "classify: d3 in-wave-cursor reason" "interactive d3-in-wave-cursor" "$SB_AM_CLASSIFIED ${SB_AM_REASONS[*]}"
rm -f "$CT/session.json"

# ---------------- tui availability ----------------
for v in 1 true yes; do SB_AGENT_MODE_TUI_AVAILABLE=$v agent_mode_tui_available claude && tl_pass "tui: override $v" || tl_fail "tui: override $v"; done
for v in 0 false no; do SB_AGENT_MODE_TUI_AVAILABLE=$v agent_mode_tui_available claude && tl_fail "tui: override $v" || tl_pass "tui: override $v off"; done
BIN="$TL_TMP/tuibin"
mkbin() { rm -rf "$BIN"; mkdir -p "$BIN"; local c; for c in "$@"; do printf '#!/bin/sh\n' >"$BIN/$c"; chmod +x "$BIN/$c"; done; }
tui() { local host="$1"; shift; mkbin "$@"; if (PATH="$BIN"; unset SB_AGENT_MODE_TUI_AVAILABLE; agent_mode_tui_available "$host"); then echo yes; else echo no; fi; }
assert_eq "tui claude: expect+claude" yes "$(tui claude expect claude)"
assert_eq "tui claude: no expect" no "$(tui claude claude)"
assert_eq "tui claude: no claude" no "$(tui claude expect)"
assert_eq "tui codex: python3+codex" yes "$(tui codex python3 codex)"
assert_eq "tui codex: no python3" no "$(tui codex codex)"
assert_eq "tui codex: no codex" no "$(tui codex python3)"
assert_eq "tui opencode: present" yes "$(tui opencode opencode)"
assert_eq "tui opencode: absent" no "$(tui opencode)"
assert_eq "tui cursor: cursor-agent" yes "$(tui cursor cursor-agent)"
assert_eq "tui cursor: agent" yes "$(tui cursor agent)"
assert_eq "tui cursor: neither" no "$(tui cursor)"
assert_eq "tui pi: present" yes "$(tui pi pi)"
assert_eq "tui pi: absent" no "$(tui pi)"
assert_eq "tui unknown host" no "$(tui bogus claude codex opencode pi)"

# ---------------- drop_interactive_only_flags ----------------
fresh
SB_AM_ATTACH=1 SB_AM_CONTROL_DIR=/c SB_AM_MAX_TURNS=4 SB_AM_AUTO_POLICY=parent
agent_mode_drop_interactive_only_flags
assert_eq "drop: flags cleared" "0|||" "$SB_AM_ATTACH|$SB_AM_CONTROL_DIR|$SB_AM_MAX_TURNS|$SB_AM_AUTO_POLICY"
assert_eq "drop: dropped list" "attach control-dir max-turns auto-policy" "${SB_AM_DROPPED[*]}"
assert_eq "drop: reasons" "fallback_drop:attach fallback_drop:control-dir fallback_drop:max-turns fallback_drop:auto-policy" "${SB_AM_REASONS[*]}"
fresh; agent_mode_drop_interactive_only_flags
assert_eq "drop: nothing to drop" "0 0" "${#SB_AM_DROPPED[@]} ${#SB_AM_REASONS[@]}"

tl_run bash -c "source '$LIB'; agent_mode_reset; export SB_AGENT_MODE_ATTACH=1; readonly SB_AGENT_MODE_ATTACH; SB_AM_ATTACH=1; agent_mode_drop_interactive_only_flags; echo rc=\$? attach=\$SB_AM_ATTACH env=\${SB_AGENT_MODE_ATTACH:-unset}"
assert_contains "drop: unsettable env var tolerated" "$TL_OUT" "rc=0 attach=0 env=1"

# ---------------- apply_tui_gate ----------------
gate() { # <tui 0|1> args...
  local tui="$1"; shift
  SB_AGENT_MODE_TUI_AVAILABLE="$tui"; export SB_AGENT_MODE_TUI_AVAILABLE
  local rc=0; agent_mode_apply_tui_gate "$@" 2>/dev/null || rc=$?
  unset SB_AGENT_MODE_TUI_AVAILABLE
  GATE_RC=$rc
}
fresh; gate 1 claude non-interactive
assert_eq "gate: NI wanted" "0 non-interactive" "$GATE_RC $SB_AM_RESOLVED"
fresh; gate 1 claude interactive
assert_eq "gate: interactive with TUI" "0 interactive" "$GATE_RC $SB_AM_RESOLVED"
fresh; gate 0 claude interactive 1 0
assert_eq "gate: d3 without TUI" "3 |mode-unavailable" "$GATE_RC $SB_AM_RESOLVED|$SB_AM_FAILURE_CLASS"
fresh; gate 0 claude interactive 0 1
assert_eq "gate: d4 without TUI" "3 |escalate-unavailable" "$GATE_RC $SB_AM_RESOLVED|$SB_AM_FAILURE_CLASS"
fresh; SB_AM_CONCRETE_PIN=1 SB_AM_REQUESTED=interactive; gate 0 claude interactive
assert_eq "gate: pinned interactive without TUI/fallback" "3 |mode-unavailable" "$GATE_RC $SB_AM_RESOLVED|$SB_AM_FAILURE_CLASS"
fresh; SB_AM_CONCRETE_PIN=1 SB_AM_REQUESTED=interactive SB_AM_ALLOW_FALLBACK=1 SB_AM_FALLBACK_VIA=cli SB_AM_ATTACH=1; gate 0 claude interactive
assert_eq "gate: pinned interactive with fallback degrades" "0 non-interactive" "$GATE_RC $SB_AM_RESOLVED"
assert_contains "gate: fallback reason names the route" "${SB_AM_REASONS[*]}" "mode_fallback:interactive→non-interactive:tui-unavailable:cli"
assert_contains "gate: fallback drops interactive-only flags" "${SB_AM_REASONS[*]}" "fallback_drop:attach"
fresh; SB_AM_CONCRETE_PIN=1 SB_AM_REQUESTED=interactive SB_AM_ALLOW_FALLBACK=1; gate 0 claude interactive
assert_contains "gate: fallback via defaults to allow-mode-fallback" "${SB_AM_REASONS[*]}" "tui-unavailable:allow-mode-fallback"
fresh; gate 0 claude interactive
assert_eq "gate: auto heuristic hops to NI" "0 non-interactive tui-unavailable" "$GATE_RC $SB_AM_RESOLVED ${SB_AM_REASONS[*]}"

# ---------------- resolve_mode ----------------
RM="$TL_TMP/rm"; mkdir -p "$RM"
res() { # <tui> host task_dir brief utterance
  local tui="$1"; shift
  SB_AGENT_MODE_TUI_AVAILABLE="$tui"; export SB_AGENT_MODE_TUI_AVAILABLE
  RES_RC=0; agent_mode_resolve_mode "$@" 2>/dev/null || RES_RC=$?
  unset SB_AGENT_MODE_TUI_AVAILABLE
}
fresh; SB_AM_CONCRETE_PIN=1 SB_AM_REQUESTED=non-interactive; res 1 claude "$RM" b ""
assert_eq "resolve: pinned NI" "0 non-interactive pin" "$RES_RC $SB_AM_RESOLVED ${SB_AM_REASONS[*]}"
assert_eq "resolve: pinned leaves classified empty" "" "$SB_AM_CLASSIFIED"
fresh; SB_AM_CONCRETE_PIN=1 SB_AM_REQUESTED=interactive; res 1 claude "$RM" b ""
assert_eq "resolve: pinned interactive" "0 interactive" "$RES_RC $SB_AM_RESOLVED"
fresh; SB_AM_CONCRETE_PIN=1 SB_AM_REQUESTED=interactive; res 0 claude "$RM" b ""
assert_eq "resolve: pinned interactive unavailable" "3" "$RES_RC"
fresh; res 1 claude "$RM" "plain" ""
assert_eq "resolve: auto NI" "0 non-interactive non-interactive" "$RES_RC $SB_AM_CLASSIFIED $SB_AM_RESOLVED"
fresh; res 1 claude "$RM" "needs a checkpoint" ""
assert_eq "resolve: auto classified interactive" "0 interactive interactive" "$RES_RC $SB_AM_CLASSIFIED $SB_AM_RESOLVED"
fresh; res 0 claude "$RM" "needs a checkpoint" ""
assert_eq "resolve: classifier interactive without TUI hops to NI" "0 non-interactive" "$RES_RC $SB_AM_RESOLVED"
mk_session "$RM" live c 4242 "Mon Jan  1 00:00:00 2026" "$(now)"; mkdir -p "$RM/control"
fresh; res 1 claude "$RM" b ""
assert_eq "resolve: d3 process-alive" "0 interactive d3-process-alive" "$RES_RC $SB_AM_RESOLVED ${SB_AM_REASONS[*]}"
fresh; res 0 claude "$RM" b ""
assert_eq "resolve: d3 without TUI is fatal" "3 mode-unavailable" "$RES_RC $SB_AM_FAILURE_CLASS"
mk_session "$RM" dead c 9999 x "$(now)"; rmdir "$RM/control"
fresh; res 1 claude "$RM" b "continue"
assert_eq "resolve: d3 continue" "d3-continue" "${SB_AM_REASONS[*]}"
mk_session "$RM" live c 9999 x "$(now)"
fresh; res 1 cursor "$RM" b ""
assert_eq "resolve: d3 in-wave-cursor" "d3-in-wave-cursor" "${SB_AM_REASONS[*]}"
rm -f "$RM/session.json"

# ---------------- post_classify_conflicts ----------------
fresh; rc=0; agent_mode_post_classify_conflicts || rc=$?; assert_eq "post-classify: nothing to flag" 0 "$rc"
fresh; SB_AM_RESOLVED=non-interactive SB_AM_CLASSIFIED=non-interactive SB_AM_ATTACH=1
tl_run agent_mode_post_classify_conflicts
assert_eq "post-classify: attach on auto NI" "2" "$TL_STATUS"; assert_contains "post-classify: attach message" "$TL_ERR" "attach-on-ni"
fresh; SB_AM_RESOLVED=non-interactive SB_AM_CLASSIFIED=non-interactive SB_AM_CONTROL_DIR=/c
tl_run agent_mode_post_classify_conflicts
assert_eq "post-classify: control-dir on auto NI" "2" "$TL_STATUS"; assert_contains "post-classify: control-dir message" "$TL_ERR" "control-dir-on-ni"
fresh; SB_AM_RESOLVED=non-interactive SB_AM_CLASSIFIED=interactive SB_AM_ATTACH=1
rc=0; agent_mode_post_classify_conflicts || rc=$?; assert_eq "post-classify: degraded from interactive is allowed" 0 "$rc"

# ---------------- mode.json persistence ----------------
PJ="$TL_TMP/pj"
fresh; SB_AM_RESOLVED=non-interactive; SB_AM_CLASSIFIED=""; agent_mode_reason_append pin
agent_mode_persist_mode_json "$PJ"
assert_eq "persist: NI record" "auto|non-interactive|[\"pin\"]" \
  "$(jq -c '[.requested,.resolved,(.reason|tojson)]|join("|")' "$PJ/mode.json" | sed 's/^"//;s/"$//;s/\\"/"/g')"
assert_eq "persist: NI has no turns" "false" "$(jq 'has("turns")' "$PJ/mode.json")"
assert_eq "persist: classified empty => null" "null" "$(jq -c .classified "$PJ/mode.json")"
fresh; SB_AM_REQUESTED=interactive SB_AM_RESOLVED=interactive SB_AM_CLASSIFIED=interactive SB_AM_TURNS=2
agent_mode_persist_mode_json "$PJ"
assert_eq "persist: interactive records turns" "2" "$(jq .turns "$PJ/mode.json")"
assert_match "persist: wave start stamped when empty" '^[0-9]{4}-' "$(jq -r .wave_started_at "$PJ/mode.json")"
assert_match "persist: wave start kept in state" '^[0-9]{4}-' "$SB_AM_WAVE_STARTED_AT"
fresh; SB_AM_RESOLVED=interactive SB_AM_WAVE_STARTED_AT="2026-01-01T00:00:00Z"
agent_mode_persist_mode_json "$PJ"
assert_eq "persist: existing wave start preserved" "2026-01-01T00:00:00Z" "$(jq -r .wave_started_at "$PJ/mode.json")"

# ---------------- redact / events ----------------
assert_contains "redact: builtin sed fallback" "$(agent_mode_redact 'password=hunter2 ok')" "password=[REDACTED]"
agent_delegate_redact_output() { printf 'DELEGATE<%s>' "$1"; }
assert_eq "redact: delegate redactor wins when defined" "DELEGATE<x y>" "$(agent_mode_redact 'x y')"
unset -f agent_delegate_redact_output
EV="$TL_TMP/ev"
fresh; SB_AM_RESOLVED=non-interactive; agent_mode_append_event "$EV" mode_resolved x
assert_file_absent "event: NI never writes events" "$EV/events.jsonl"
fresh; SB_AM_RESOLVED=interactive
agent_mode_append_event "$EV" mode_resolved "token=abc123"
agent_mode_append_event "$EV" escalated ""
assert_eq "event: two lines" 2 "$(wc -l <"$EV/events.jsonl" | tr -d ' ')"
assert_eq "event: payload redacted" "mode_resolved|token=[REDACTED]" "$(head -1 "$EV/events.jsonl" | jq -r '[.event,.payload]|join("|")')"
assert_eq "event: empty payload omitted" "false" "$(tail -1 "$EV/events.jsonl" | jq 'has("payload")')"

# ---------------- artifact dir ----------------
WD="$TL_TMP/wd"; mkdir -p "$WD"
fresh; SB_AM_TASK_ID=t-1; SB_AM_RESOLVED=non-interactive; export SB_AGENT_CONTROL_DIR=/old
out="$(agent_mode_prepare_artifact_dir claude "$WD")"
assert_eq "artifact: NI task dir" "$WD/.planning/agent-claude/t-1" "$out"
assert_file_absent "artifact: NI has no control dir" "$WD/.planning/agent-claude/t-1/control"
fresh; SB_AM_TASK_ID=t-1; SB_AM_RESOLVED=non-interactive; export SB_AGENT_CONTROL_DIR=/old
agent_mode_prepare_artifact_dir claude "$WD" >/dev/null
assert_eq "artifact: NI clears control env" "" "${SB_AGENT_CONTROL_DIR:-}"
fresh; SB_AM_TASK_ID=t-2; SB_AM_RESOLVED=interactive
agent_mode_prepare_artifact_dir codex "$WD" >/dev/null
CD="$WD/.planning/agent-codex/t-2/control"
[[ -p "$CD/cmd.fifo" && -p "$CD/reply.fifo" ]] && tl_pass "artifact: interactive creates both fifos" || tl_fail "artifact: interactive creates both fifos"
assert_file_exists "artifact: snapshots dir" "$WD/.planning/agent-codex/t-2/snapshots"
assert_eq "artifact: control env exported" "$CD" "$SB_AGENT_CONTROL_DIR"
agent_mode_prepare_artifact_dir codex "$WD" >/dev/null
assert_eq "artifact: re-run keeps the fifos" "ok" "$([[ -p "$CD/cmd.fifo" ]] && echo ok)"
fresh; SB_AM_TASK_ID=t-3 SB_AM_RESOLVED=interactive SB_AM_CONTROL_DIR="$TL_TMP/custom-control"
SB_AGENT_TASK_DIR="$TL_TMP/custom-task" agent_mode_prepare_artifact_dir pi "$WD" >/dev/null
assert_eq "artifact: custom control dir" "ok" "$([[ -p "$TL_TMP/custom-control/cmd.fifo" ]] && echo ok)"
fresh; SB_AM_RESOLVED=non-interactive
out="$(agent_mode_prepare_artifact_dir claude "$WD")"
assert_match "artifact: default task id is timestamped" "/task-[0-9]{8}T[0-9]{6}Z$" "$out"
unset SB_AGENT_CONTROL_DIR

# ---------------- host launch env ----------------
launch() { # host resolved [extra assignments...] -> prints env lines of interest
  local host="$1" resolved="$2"; shift 2
  (fresh; SB_AM_RESOLVED="$resolved"; SB_AM_REQUESTED=auto; local a; for a in "$@"; do eval "$a"; done
   unset PI_PROVIDER PI_MODEL
   agent_mode_apply_host_launch_env "$host"
   env | grep -E '^(SB_AGENT_RESOLVED_MODE|SB_AGENT_REQUESTED_MODE|CLAUDE_USE_INTERACTIVE|SB_LIVE_CODEX_USE_EXEC|CODEX_LAUNCH_MODE|OPENCODE_USE_INTERACTIVE|SB_LIVE_OPENCODE_USE_INTERACTIVE|PI_PROVIDER|PI_MODEL|PI_USE_INTERACTIVE|SB_AGENT_CURSOR_SESSION|SB_LIVE_CURSOR_FORCE_HEADLESS|SB_AGENT_IDLE_SEC)=' | sort | tr '\n' ' ')
}
assert_eq "launch claude NI" "CLAUDE_USE_INTERACTIVE=0 SB_AGENT_REQUESTED_MODE=auto SB_AGENT_RESOLVED_MODE=non-interactive " "$(launch claude non-interactive)"
assert_contains "launch claude interactive" "$(launch claude interactive)" "CLAUDE_USE_INTERACTIVE=1"
for kv in CODEX_LAUNCH_MODE=exec SB_LIVE_CODEX_USE_EXEC=1; do assert_contains "launch codex NI $kv" "$(launch codex non-interactive)" "$kv"; done
for kv in CODEX_LAUNCH_MODE=interactive SB_LIVE_CODEX_USE_EXEC=0; do assert_contains "launch codex interactive $kv" "$(launch codex interactive)" "$kv"; done
for kv in OPENCODE_USE_INTERACTIVE=1 SB_LIVE_OPENCODE_USE_INTERACTIVE=1; do assert_contains "launch opencode interactive $kv" "$(launch opencode interactive)" "$kv"; done
assert_contains "launch opencode NI" "$(launch opencode non-interactive)" "OPENCODE_USE_INTERACTIVE=0"
assert_contains "launch pi NI pins model" "$(launch pi non-interactive)" "PI_MODEL=mimo-v2.5 PI_PROVIDER=opencode-go PI_USE_INTERACTIVE=0"
assert_contains "launch pi interactive" "$(launch pi interactive)" "PI_USE_INTERACTIVE=1"
for kv in SB_AGENT_CURSOR_SESSION=1 SB_LIVE_CURSOR_FORCE_HEADLESS=0; do assert_contains "launch cursor interactive $kv" "$(launch cursor interactive)" "$kv"; done
for kv in SB_AGENT_CURSOR_SESSION=0 SB_LIVE_CURSOR_FORCE_HEADLESS=1; do assert_contains "launch cursor NI $kv" "$(launch cursor non-interactive)" "$kv"; done
assert_contains "launch idle seconds exported" "$(launch claude non-interactive SB_AM_IDLE_SEC=45)" "SB_AGENT_IDLE_SEC=45"
assert_not_contains "launch without idle exports none" "$(launch claude non-interactive)" "SB_AGENT_IDLE_SEC"
assert_not_contains "launch unknown host sets no host vars" "$(launch bogus interactive)" "CLAUDE_USE_INTERACTIVE"

# ---------------- reason append to file / escalation ----------------
RF="$TL_TMP/rf.json"
rc=0; agent_mode_append_reason_to_file "$TL_TMP/nofile.json" x || rc=$?; assert_eq "append reason: missing file" 1 "$rc"
echo '{"requested":"auto"}' >"$RF"
agent_mode_append_reason_to_file "$RF" escalated
agent_mode_append_reason_to_file "$RF" escalated
agent_mode_append_reason_to_file "$RF" other
assert_eq "append reason: appended once each" '["escalated","other"]' "$(jq -c .reason "$RF")"
assert_eq "append reason: other fields kept" "auto" "$(jq -r .requested "$RF")"

WE="$TL_TMP/we"; mkdir -p "$WE"
agent_mode_write_escalation "$WE" "why not" ""
assert_contains "escalation: header and reason" "$(cat "$WE/escalation.md")" "# Escalation (auto NI → interactive)

why not"
assert_not_contains "escalation: no prompt without result" "$(cat "$WE/escalation.md")" "NEXT_RETRY_PROMPT"
assert_not_contains "escalation: no log tail without log" "$(cat "$WE/escalation.md")" "Log tail"
printf '## STATUS\nfail\n\n## NEXT_RETRY_PROMPT\nTry harder\nwith detail\n\n## OTHER\nx\n' >"$WE/result.md"
seq 1 100 | sed 's/^/logline /' >"$TL_TMP/big.log"
agent_mode_write_escalation "$WE" "again" "$TL_TMP/big.log"
assert_contains "escalation: retry prompt carried over" "$(cat "$WE/escalation.md")" "## NEXT_RETRY_PROMPT
Try harder
with detail"
assert_not_contains "escalation: stops at the next heading" "$(cat "$WE/escalation.md")" "## OTHER"
assert_contains "escalation: log tail present" "$(cat "$WE/escalation.md")" "## Log tail"
assert_contains "escalation: last log line" "$(cat "$WE/escalation.md")" "logline 100"
assert_not_contains "escalation: tail limited to 80 lines" "$(cat "$WE/escalation.md")" "logline 20
"
printf '## NEXT_RETRY_PROMPT\n(none)\n' >"$WE/result.md"
agent_mode_write_escalation "$WE" "none" ""
assert_not_contains "escalation: (none) prompt skipped" "$(cat "$WE/escalation.md")" "NEXT_RETRY_PROMPT"

tail() { return 1; }
agent_mode_write_escalation "$WE" "log unreadable" "$TL_TMP/big.log"
unset -f tail
assert_contains "escalation: unreadable log tail tolerated, fence still closed" "$(cat "$WE/escalation.md")" "## Log tail

\`\`\`
\`\`\`"

# ---------------- normalize_incomplete_result ----------------
NR="$TL_TMP/nr"
fresh; agent_mode_normalize_incomplete_result "$NR"
assert_contains "normalize: missing result gets a failing skeleton" "$(cat "$NR/result.md")" "## STATUS
fail"
assert_eq "normalize: missing result reasons" "incomplete result-missing" "${SB_AM_REASONS[*]}"
fresh; printf 'free text only\n' >"$NR/result.md"
agent_mode_normalize_incomplete_result "$NR"
assert_eq "normalize: statusless result gets a fail status prepended" "## STATUS
fail

free text only" "$(cat "$NR/result.md")"
assert_eq "normalize: present result is only incomplete" "incomplete" "${SB_AM_REASONS[*]}"
fresh; printf '## STATUS\nweird\n\nbody\n' >"$NR/result.md"
agent_mode_normalize_incomplete_result "$NR"
assert_eq "normalize: unknown heading status replaced with fail" "fail" "$(agent_mode_result_status "$NR/result.md")"
fresh; printf 'STATUS: pass\nbody\n' >"$NR/result.md"
agent_mode_normalize_incomplete_result "$NR"
assert_eq "normalize: a real STATUS line is left alone" "STATUS: pass
body" "$(cat "$NR/result.md")"
fresh; printf 'STATUS: pass\n' >"$NR/result.md"
agent_mode_normalize_incomplete_result "$NR" 1
assert_eq "normalize: forced missing flag records result-missing" "incomplete result-missing" "${SB_AM_REASONS[*]}"
assert_eq "normalize: mode.json persisted" '["incomplete","result-missing"]' "$(jq -c .reason "$NR/mode.json")"

# ---------------- maybe_escalate ----------------
ME_WORK="$TL_TMP/mework"; ME_TASK="$ME_WORK/.planning/agent-claude/t-9"; mkdir -p "$ME_TASK"
setup_escalation() {
  fresh; SB_AM_REQUESTED=auto SB_AM_CLASSIFIED=non-interactive SB_AM_RESOLVED=non-interactive SB_AM_TASK_ID=t-9
  printf '## STATUS\nfail\n' >"$ME_TASK/result.md"
  echo '{"requested":"auto","classified":"non-interactive","resolved":"non-interactive","reason":["classifier-ni"]}' >"$ME_TASK/mode.json"
  rm -f "$ME_TASK/escalation.md" "$ME_TASK/events.jsonl"
}
setup_escalation; SB_AM_NO_ESCALATE=1
rc=0; agent_mode_maybe_escalate claude "$ME_TASK" || rc=$?; assert_eq "escalate: --no-escalate" 1 "$rc"
setup_escalation; SB_AM_REQUESTED=interactive
rc=0; agent_mode_maybe_escalate claude "$ME_TASK" || rc=$?; assert_eq "escalate: ineligible state" 1 "$rc"
assert_file_absent "escalate: ineligible writes nothing" "$ME_TASK/escalation.md"
setup_escalation; SB_AGENT_MODE_TUI_AVAILABLE=0
rc=0; agent_mode_maybe_escalate claude "$ME_TASK" "" 2>/dev/null || rc=$?
unset SB_AGENT_MODE_TUI_AVAILABLE
assert_eq "escalate: TUI unavailable returns 1" 1 "$rc"
assert_eq "escalate: unavailable recorded in mode.json" '["classifier-ni","escalated","escalate-unavailable"]' "$(jq -c .reason "$ME_TASK/mode.json")"
assert_eq "escalate: unavailable class" "escalate-unavailable" "$SB_AM_FAILURE_CLASS"
setup_escalation; SB_AGENT_MODE_TUI_AVAILABLE=1
rc=0; agent_mode_maybe_escalate claude "$ME_TASK" "$TL_TMP/big.log" || rc=$?
unset SB_AGENT_MODE_TUI_AVAILABLE
assert_eq "escalate: success" 0 "$rc"
assert_eq "escalate: resolved flipped to interactive" "interactive" "$SB_AM_RESOLVED"
assert_file_exists "escalate: escalation.md written" "$ME_TASK/escalation.md"
assert_eq "escalate: reasons recorded in mode.json" '["classifier-ni","escalated"]' "$(jq -c .reason "$ME_TASK/mode.json")"
assert_eq "escalate: events recorded" "escalated mode_resolved" "$(jq -r .event "$ME_TASK/events.jsonl" | tr '\n' ' ' | sed 's/ $//')"
assert_eq "escalate: task dir is unchanged by re-preparing artifacts" "$ME_TASK" "$SB_AM_TASK_DIR"
[[ -p "$ME_TASK/control/cmd.fifo" ]] && tl_pass "escalate: control fifos live in the original task dir" || tl_fail "escalate: control fifos live in the original task dir"
assert_file_absent "escalate: no stray nested .planning tree" "$ME_WORK/.planning/.planning"
unset SB_AGENT_CONTROL_DIR

# ---------------- control fifo ops / wait_event ----------------
CTL="$TL_TMP/ctl"; mkdir -p "$CTL"; mkfifo "$CTL/cmd.fifo"
exec 7<>"$CTL/cmd.fifo"
rc=0; agent_mode_ctl_write "$TL_TMP/nocontrol" '{}' || rc=$?; assert_eq "ctl write: no fifo" 1 "$rc"
agent_mode_ctl_write "$CTL" '{"op":"snapshot"}'; read -r -t 2 -u 7 line
assert_eq "ctl write: payload arrives newline-terminated" '{"op":"snapshot"}' "$line"
agent_mode_ctl_send "$CTL" 'hello "world"'; read -r -t 2 -u 7 line
assert_eq "ctl send: json op with escaped text" 'send|hello "world"' "$(jq -r '[.op,.text]|join("|")' <<<"$line")"
agent_mode_ctl_key "$CTL" Enter; read -r -t 2 -u 7 line
assert_eq "ctl key" 'key|Enter' "$(jq -r '[.op,.name]|join("|")' <<<"$line")"
agent_mode_ctl_op "$CTL" abort; read -r -t 2 -u 7 line
assert_eq "ctl op" 'abort' "$(jq -r .op <<<"$line")"
exec 7>&-

EVF="$TL_TMP/waitev.jsonl"
rc=0; agent_mode_wait_event "$EVF" "done" 0.2 >/dev/null || rc=$?; assert_eq "wait: missing events file times out" 1 "$rc"
printf '\nnot json\n{"event":"other"}\n{"event":"done","ts":"t"}\n' >"$EVF"
out="$(agent_mode_wait_event "$EVF" "done" 1)"
assert_eq "wait: finds the named event, skipping blanks and junk" '{"event":"done","ts":"t"}' "$out"
rc=0; agent_mode_wait_event "$EVF" missing 0.2 >/dev/null || rc=$?; assert_eq "wait: absent event times out" 1 "$rc"

# ---------------- af seed / validation ----------------
fresh
SB_AM_REQUESTED=interactive SB_AM_MAX_TURNS=5 SB_AM_MAX_WALL_SEC=60 SB_AM_IDLE_SEC=20 SB_AM_ATTACH=1 SB_AM_NO_ESCALATE=1 SB_AM_ALLOW_FALLBACK=1 SB_AM_CONTROL_DIR=/c SB_AM_AUTO_POLICY=parent
assert_eq "af seed: all fields" "interactive|5|60|20|true|true|true|/c|parent" \
  "$(agent_mode_af_seed_fields | jq -r '[.interaction_mode,.max_turns,.max_wall_sec,.idle_sec,.attach,.no_escalate,.allow_mode_fallback,.control_dir,.auto_policy]|join("|")')"
fresh
assert_eq "af seed: defaults" "auto|8|null|null|false|false|false|null|supervised" \
  "$(agent_mode_af_seed_fields | jq -r '[.interaction_mode,.max_turns,.max_wall_sec,.idle_sec,.attach,.no_escalate,.allow_mode_fallback,.control_dir,.auto_policy]|map(tostring)|join("|")')"
tl_run agent_mode_validate_af_seed auto true
assert_eq "af validate: fallback needs interactive" 2 "$TL_STATUS"
tl_run agent_mode_validate_af_seed non-interactive 1
assert_eq "af validate: fallback=1 on NI" 2 "$TL_STATUS"
tl_run agent_mode_validate_af_seed interactive true
assert_eq "af validate: interactive fallback ok" 0 "$TL_STATUS"
tl_run agent_mode_validate_af_seed
assert_eq "af validate: defaults ok" 0 "$TL_STATUS"

# ---------------- run_delegate_resolver ----------------
rdr() { # <tui> host work brief utterance ; flags applied through SB_AM_* before the call
  local tui="$1"; shift
  SB_AGENT_MODE_TUI_AVAILABLE="$tui"; export SB_AGENT_MODE_TUI_AVAILABLE
  RDR_RC=0; agent_mode_run_delegate_resolver "$@" 2>"$TL_TMP/rdr.err" || RDR_RC=$?
  unset SB_AGENT_MODE_TUI_AVAILABLE
}
RW="$TL_TMP/rdr"; mkdir -p "$RW"
fresh; SB_AM_TASK_ID=a1 SB_AM_ARGV_HAS_INTERACTION=1 SB_AM_REQUESTED=non-interactive SB_AM_CONCRETE_PIN=1 SB_AM_PIN_NI=1
rdr 1 claude "$RW" "the brief" ""
assert_eq "rdr: pinned NI succeeds" "0 non-interactive" "$RDR_RC $SB_AM_RESOLVED"
assert_eq "rdr: brief written" "the brief" "$(cat "$RW/.planning/agent-claude/a1/brief.md")"
assert_eq "rdr: pinned NI mode.json" "non-interactive|[\"pin\"]" "$(jq -r '[.resolved,(.reason|tostring)]|join("|")' "$RW/.planning/agent-claude/a1/mode.json" | sed 's/"//g;s/\[pin\]/["pin"]/')" || true
assert_eq "rdr: pinned NI exports launch env" "0" "$CLAUDE_USE_INTERACTIVE"
assert_file_absent "rdr: pinned NI has no control dir" "$RW/.planning/agent-claude/a1/control"
# conflicts abort early
fresh; SB_AM_ARGV_HAS_INTERACTION=1 SB_AM_REQUESTED=non-interactive SB_AM_CONCRETE_PIN=1 SB_AM_ATTACH=1
rdr 1 claude "$RW" b ""
assert_eq "rdr: preflight conflict propagates" 2 "$RDR_RC"
fresh; MODE=auto; export MODE
rdr 1 claude "$RW" b ""
unset MODE
assert_eq "rdr: --mode auto is a permission conflict" 2 "$RDR_RC"
# auto NI resolution
fresh; SB_AM_TASK_ID=a2
rdr 1 codex "$RW" "just do it" ""
assert_eq "rdr: auto NI" "0 non-interactive" "$RDR_RC $SB_AM_RESOLVED"
assert_eq "rdr: auto NI launch env" "exec" "$CODEX_LAUNCH_MODE"
# auto interactive: defaults applied, events written
fresh; SB_AM_TASK_ID=a3
rdr 1 claude "$RW" "needs a checkpoint" ""
assert_eq "rdr: auto interactive" "0 interactive supervised 8" "$RDR_RC $SB_AM_RESOLVED $SB_AM_AUTO_POLICY $SB_AM_MAX_TURNS"
assert_eq "rdr: interactive mode event" "mode_resolved" "$(jq -r .event "$RW/.planning/agent-claude/a3/events.jsonl")"
[[ -p "$RW/.planning/agent-claude/a3/control/cmd.fifo" ]] && tl_pass "rdr: interactive control fifo" || tl_fail "rdr: interactive control fifo"
assert_eq "rdr: interactive launch env" "1" "$CLAUDE_USE_INTERACTIVE"
fresh; SB_AM_TASK_ID=a4 SB_AM_AUTO_POLICY=parent SB_AM_MAX_TURNS=3
rdr 1 claude "$RW" "needs a checkpoint" ""
assert_eq "rdr: explicit policy and turns kept" "parent 3" "$SB_AM_AUTO_POLICY $SB_AM_MAX_TURNS"
# resolution failure and post-classify conflict propagate
fresh; SB_AM_TASK_ID=a5 SB_AM_ARGV_HAS_INTERACTION=1 SB_AM_REQUESTED=interactive SB_AM_CONCRETE_PIN=1 SB_AM_PIN_INTERACTIVE=1
rdr 0 claude "$RW" b ""
assert_eq "rdr: pinned interactive without TUI" 3 "$RDR_RC"
fresh; SB_AM_TASK_ID=a6 SB_AM_ATTACH=1
rdr 1 claude "$RW" "plain" ""
assert_eq "rdr: attach on classifier NI conflicts after classification" 2 "$RDR_RC"
# default task id when none is given
fresh; unset SB_AM_TASK_ID 2>/dev/null || true; SB_AM_TASK_ID=""
rdr 1 claude "$RW" "plain" ""
assert_match "rdr: timestamped task id" "^task-[0-9]{8}T[0-9]{6}Z$" "$SB_AM_TASK_ID"
# the custom task dir env is honored
fresh; SB_AM_TASK_ID=a7; export SB_AGENT_TASK_DIR="$TL_TMP/custom-rdr"
rdr 1 claude "$RW" "plain" ""
unset SB_AGENT_TASK_DIR
assert_file_exists "rdr: SB_AGENT_TASK_DIR honored" "$TL_TMP/custom-rdr/mode.json"

unset -f kill ps
tl_results
