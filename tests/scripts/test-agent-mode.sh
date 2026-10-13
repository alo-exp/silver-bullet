#!/usr/bin/env bash
# Contract tests for scripts/lib/agent-mode.sh (plan 17ed9bf7).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MODE_LIB="${REPO_ROOT}/scripts/lib/agent-mode.sh"
CTL="${REPO_ROOT}/scripts/agent-mode/ctl.sh"
MOCK="${REPO_ROOT}/scripts/agent-mode/mock-interactive.py"

PASS=0
FAIL=0

check() {
  local desc="$1" result="$2"
  if [[ "$result" == pass ]]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== agent-mode contract tests ==="

[[ -f "$MODE_LIB" ]] && check "agent-mode.sh exists" pass || check "agent-mode.sh exists" fail

# shellcheck source=../../scripts/lib/agent-mode.sh
source "$MODE_LIB"

TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/agent-mode-test-XXXXXX")"
cleanup() { rm -rf "$TMPROOT"; }
trap cleanup EXIT

run_parse() {
  agent_mode_reset
  env -u SB_AGENT_INTERACTION_MODE -u SB_AGENT_ALLOW_MODE_FALLBACK \
    -u SB_AGENT_MODE_ATTACH -u SB_AGENT_NO_ESCALATE \
    -u SB_AGENT_AUTO_POLICY -u SB_AGENT_MAX_TURNS \
    bash -c '
      source "$1"
      shift
      agent_mode_reset
      agent_mode_parse_argv "$@"
      rc=$?
      [[ $rc -eq 0 ]] || exit $rc
      agent_mode_preflight_flags
    ' _ "$MODE_LIB" "$@"
}

# --- flags / isolation ---
agent_mode_reset
agent_mode_parse_argv --interaction-mode auto
agent_mode_note_permission_mode permissive
agent_mode_preflight_flags && check "auto + permission --mode permissive is orthogonal" pass \
  || check "auto + permission --mode permissive is orthogonal" fail

agent_mode_reset
if agent_mode_note_permission_mode non-interactive 2>/dev/null; then
  check "--mode non-interactive is mode-conflict" fail
else
  [[ "$SB_AM_FAILURE_CLASS" == "mode-conflict" ]] && check "--mode non-interactive is mode-conflict" pass \
    || check "--mode non-interactive is mode-conflict" fail
fi

agent_mode_reset
agent_mode_parse_argv --interaction-mode interactive --use-print
if agent_mode_preflight_flags 2>/dev/null; then
  check "interactive + --use-print is mode-conflict" fail
else
  check "interactive + --use-print is mode-conflict" pass
fi

agent_mode_reset
agent_mode_parse_argv --interaction-mode auto --use-print
if agent_mode_preflight_flags 2>/dev/null; then
  check "auto + --use-print is mode-conflict" fail
else
  check "auto + --use-print is mode-conflict" pass
fi

agent_mode_reset
agent_mode_parse_argv --interaction-mode auto --interactive
if agent_mode_preflight_flags 2>/dev/null; then
  check "auto + --interactive is mode-conflict" fail
else
  check "auto + --interactive is mode-conflict" pass
fi

agent_mode_reset
agent_mode_parse_argv --interactive --non-interactive
if agent_mode_preflight_flags 2>/dev/null; then
  check "opposite aliases conflict" fail
else
  check "opposite aliases conflict" pass
fi

agent_mode_reset
agent_mode_parse_argv --use-print --use-interactive
if agent_mode_preflight_flags 2>/dev/null; then
  check "opposite legacy pins conflict" fail
else
  check "opposite legacy pins conflict" pass
fi

agent_mode_reset
agent_mode_parse_argv --use-print --non-interactive
agent_mode_preflight_flags && [[ "$SB_AM_REQUESTED" == "non-interactive" ]] \
  && check "redundant --use-print + --non-interactive allowed" pass \
  || check "redundant --use-print + --non-interactive allowed" fail

agent_mode_reset
agent_mode_parse_argv --delegation-mode default --interaction-mode auto
# --delegation-mode is unparsed (orthogonal)
[[ "${SB_AM_UNPARSED[0]:-}" == "--delegation-mode" ]] && check "--delegation-mode orthogonal / unparsed" pass \
  || check "--delegation-mode orthogonal / unparsed" fail

# leftover env pin (I-21)
agent_mode_reset
export SB_AGENT_INTERACTION_MODE=non-interactive
if agent_mode_preflight_flags 2>/dev/null; then
  check "leftover env pin without argv is mode-conflict" fail
else
  [[ "$SB_AM_CONFLICT_DETAIL" == "leftover-env-pin" ]] && check "leftover env pin without argv is mode-conflict" pass \
    || check "leftover env pin without argv is mode-conflict" fail
fi
unset SB_AGENT_INTERACTION_MODE

agent_mode_reset
export SB_AGENT_INTERACTION_MODE=non-interactive
agent_mode_parse_argv --interaction-mode auto
if agent_mode_preflight_flags; then
  [[ -z "${SB_AGENT_INTERACTION_MODE:-}" ]] && check "argv --interaction-mode wins leftover env and unsets" pass \
    || check "argv --interaction-mode wins leftover env and unsets" fail
else
  check "argv --interaction-mode wins leftover env and unsets" fail
fi

# fallback-not-pinned (I-57)
agent_mode_reset
agent_mode_parse_argv --interaction-mode auto --allow-mode-fallback
if agent_mode_preflight_flags 2>/dev/null; then
  check "allow-mode-fallback on auto is fallback-not-pinned" fail
else
  [[ "$SB_AM_CONFLICT_DETAIL" == "fallback-not-pinned" ]] && check "allow-mode-fallback on auto is fallback-not-pinned" pass \
    || check "allow-mode-fallback on auto is fallback-not-pinned" fail
fi

agent_mode_reset
export SB_AGENT_ALLOW_MODE_FALLBACK=1
agent_mode_parse_argv --interaction-mode auto
if agent_mode_preflight_flags 2>/dev/null; then
  check "SB_AGENT_ALLOW_MODE_FALLBACK on auto is fallback-not-pinned" fail
else
  check "SB_AGENT_ALLOW_MODE_FALLBACK on auto is fallback-not-pinned" pass
fi
unset SB_AGENT_ALLOW_MODE_FALLBACK

agent_mode_reset
agent_mode_parse_argv --interaction-mode interactive --allow-mode-fallback
agent_mode_preflight_flags && check "allow-mode-fallback with pinned interactive is valid" pass \
  || check "allow-mode-fallback with pinned interactive is valid" fail

# AF seed fallback-not-pinned (I-47)
agent_mode_reset
if agent_mode_validate_af_seed auto true 2>/dev/null; then
  check "AF {auto, allow_mode_fallback:true} is fallback-not-pinned" fail
else
  check "AF {auto, allow_mode_fallback:true} is fallback-not-pinned" pass
fi

# I-64 env unset after flags resolve
agent_mode_reset
export SB_AGENT_MODE_ATTACH=1 SB_AGENT_NO_ESCALATE=1 SB_AGENT_AUTO_POLICY=parent SB_AGENT_MAX_TURNS=3
agent_mode_parse_argv --interaction-mode interactive
agent_mode_preflight_flags
[[ -z "${SB_AGENT_MODE_ATTACH:-}" && -z "${SB_AGENT_NO_ESCALATE:-}" && -z "${SB_AGENT_AUTO_POLICY:-}" && -z "${SB_AGENT_MAX_TURNS:-}" ]] \
  && check "consumes leftover attach/no-escalate/auto-policy/max-turns env" pass \
  || check "consumes leftover attach/no-escalate/auto-policy/max-turns env" fail

# --- classifier ---
TASKA="${TMPROOT}/agent-claude/t-a"
mkdir -p "$TASKA"

agent_mode_reset
agent_mode_classify_task "Implement the feature and run tests. First-wave implement+test." "$TASKA" "claude" ""
[[ "$SB_AM_CLASSIFIED" == "non-interactive" ]] && check "first-wave implement+test classifies NI" pass \
  || check "first-wave implement+test classifies NI" fail

agent_mode_reset
agent_mode_classify_task "Keep going with the same child." "$TASKA" "claude" "continue"
[[ "$SB_AM_CLASSIFIED" == "interactive" ]] && check "continue utterance classifies interactive" pass \
  || check "continue utterance classifies interactive" fail

# leftover conversation id after terminal result is NOT D3 (I-18)
agent_mode_reset
mkdir -p "$TASKA"
cat >"${TASKA}/session.json" <<EOF
{"status":"dead","conversation_id":"conv-leftover","updated_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
EOF
cat >"${TASKA}/result.md" <<'EOF'
## STATUS
pass
EOF
agent_mode_classify_task "Implement a small fix and test." "$TASKA" "claude" ""
[[ "$SB_AM_CLASSIFIED" == "non-interactive" ]] && check "leftover conversation id after terminal result is NI not D3" pass \
  || check "leftover conversation id after terminal result is NI not D3" fail

# explicit pin wins over D3
LIVE="${TMPROOT}/agent-claude/t-live"
mkdir -p "${LIVE}/control"
SLEEP_PID=""
sleep 120 &
SLEEP_PID=$!
STARTED="$(ps -p "$SLEEP_PID" -o lstart= | sed 's/^ *//')"
cat >"${LIVE}/session.json" <<EOF
{"status":"live","conversation_id":"conv-live","pid":${SLEEP_PID},"pid_started_at":"${STARTED}","updated_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","turns":1,"wave_started_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
EOF
agent_mode_reset
SB_AM_CONCRETE_PIN=1
SB_AM_REQUESTED="non-interactive"
SB_AGENT_MODE_TUI_AVAILABLE=1
agent_mode_resolve_mode "claude" "$LIVE" "continue please" "continue"
[[ "$SB_AM_RESOLVED" == "non-interactive" && -z "$SB_AM_CLASSIFIED" ]] \
  && check "explicit NI pin wins over D3 live session" pass \
  || check "explicit NI pin wins over D3 live session" fail
kill "$SLEEP_PID" 2>/dev/null || true

# auto + attach still classifies; classified NI → attach-on-ni (I-20)
agent_mode_reset
export SB_AGENT_MODE_TUI_AVAILABLE=0
agent_mode_parse_argv --interaction-mode auto --attach
agent_mode_preflight_flags
agent_mode_resolve_mode "claude" "$TASKA" "Implement the feature and run tests." ""
if agent_mode_post_classify_conflicts 2>/dev/null; then
  check "auto --attach classified NI is attach-on-ni" fail
else
  [[ "$SB_AM_CONFLICT_DETAIL" == "attach-on-ni" ]] && check "auto --attach classified NI is attach-on-ni" pass \
    || check "auto --attach classified NI is attach-on-ni" fail
fi

# I-66: auto classified interactive + TUI miss → NI tui-unavailable + fallback_drop, not attach-on-ni
agent_mode_reset
export SB_AGENT_MODE_TUI_AVAILABLE=0
agent_mode_parse_argv --interaction-mode auto --attach --control-dir "${TMPROOT}/ctl-drop"
agent_mode_preflight_flags
agent_mode_resolve_mode "claude" "$TASKA" "Need checkpoints and a permission picker." ""
agent_mode_post_classify_conflicts
[[ "$SB_AM_CLASSIFIED" == "interactive" && "$SB_AM_RESOLVED" == "non-interactive" ]] \
  && agent_mode_reason_has "tui-unavailable" \
  && agent_mode_reason_has "fallback_drop:attach" \
  && agent_mode_reason_has "fallback_drop:control-dir" \
  && [[ ! -d "${TMPROOT}/ctl-drop" ]] \
  && check "I-66 auto TUI-miss hops NI with fallback_drop not attach-on-ni" pass \
  || check "I-66 auto TUI-miss hops NI with fallback_drop not attach-on-ni" fail

# I-67: I-66 hop is not D4-eligible
agent_mode_reset
SB_AM_REQUESTED="auto"
SB_AM_CLASSIFIED="interactive"
SB_AM_RESOLVED="non-interactive"
SB_AM_REASONS=("tui-unavailable")
if agent_mode_d4_eligible_from_state "$SB_AM_REQUESTED" "$SB_AM_CLASSIFIED" "$SB_AM_RESOLVED"; then
  check "I-66 hop is not D4-eligible" fail
else
  check "I-66 hop is not D4-eligible" pass
fi

# D4-eligible classifier NI
agent_mode_reset
SB_AM_REQUESTED="auto"
SB_AM_CLASSIFIED="non-interactive"
SB_AM_RESOLVED="non-interactive"
SB_AM_REASONS=("classifier-ni")
agent_mode_d4_eligible_from_state "$SB_AM_REQUESTED" "$SB_AM_CLASSIFIED" "$SB_AM_RESOLVED" \
  && check "classifier-selected NI is D4-eligible" pass \
  || check "classifier-selected NI is D4-eligible" fail

# pinned NI does not escalate
agent_mode_reset
SB_AM_REQUESTED="non-interactive"
SB_AM_CLASSIFIED=""
SB_AM_RESOLVED="non-interactive"
SB_AM_REASONS=("pin")
if agent_mode_d4_eligible_from_state "$SB_AM_REQUESTED" "$SB_AM_CLASSIFIED" "$SB_AM_RESOLVED"; then
  check "pinned NI is not D4-eligible" fail
else
  check "pinned NI is not D4-eligible" pass
fi

# D3 live-session TUI miss → mode-unavailable not silent NI (I-32)
SLEEP2=""
sleep 120 &
SLEEP2=$!
STARTED2="$(ps -p "$SLEEP2" -o lstart= | sed 's/^ *//')"
D3DIR="${TMPROOT}/agent-pi/d3"
mkdir -p "${D3DIR}/control"
cat >"${D3DIR}/session.json" <<EOF
{"status":"live","conversation_id":"conv-d3","pid":${SLEEP2},"pid_started_at":"${STARTED2}","updated_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","turns":1,"wave_started_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
EOF
agent_mode_reset
export SB_AGENT_MODE_TUI_AVAILABLE=0
if agent_mode_resolve_mode "pi" "$D3DIR" "continue" "continue" 2>/dev/null; then
  check "D3 TUI miss is mode-unavailable not NI" fail
else
  if [[ "$SB_AM_FAILURE_CLASS" == "mode-unavailable" ]] && [[ -f "${D3DIR}/mode.json" ]] \
    && grep -q 'mode-unavailable' "${D3DIR}/mode.json"; then
    check "D3 TUI miss is mode-unavailable not NI" pass
  else
    check "D3 TUI miss is mode-unavailable not NI" fail
  fi
fi
kill "$SLEEP2" 2>/dev/null || true

# in-wave Cursor (I-50)
CDIR="${TMPROOT}/agent-cursor/wave"
mkdir -p "$CDIR"
cat >"${CDIR}/session.json" <<EOF
{"status":"live","conversation_id":"cursor-sess-1","updated_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","turns":2,"wave_started_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
EOF
agent_mode_reset
export SB_AGENT_MODE_TUI_AVAILABLE=1
agent_mode_classify_task "Add a unit test." "$CDIR" "cursor" ""
[[ "$SB_AM_CLASSIFIED" == "interactive" ]] && agent_mode_reason_has "d3-in-wave-cursor" \
  && check "in-wave Cursor status=live + conversation_id is D3 (2)" pass \
  || check "in-wave Cursor status=live + conversation_id is D3 (2)" fail

# pin interactive TUI miss without fallback
agent_mode_reset
export SB_AGENT_MODE_TUI_AVAILABLE=0
SB_AM_CONCRETE_PIN=1
SB_AM_REQUESTED="interactive"
if agent_mode_resolve_mode "pi" "$TASKA" "do it" "" 2>/dev/null; then
  check "pinned interactive TUI miss without fallback is mode-unavailable" fail
else
  if [[ "$SB_AM_FAILURE_CLASS" == "mode-unavailable" ]] && [[ -f "${TASKA}/mode.json" ]] \
    && grep -q 'mode-unavailable' "${TASKA}/mode.json"; then
    check "pinned interactive TUI miss without fallback is mode-unavailable" pass
  else
    check "pinned interactive TUI miss without fallback is mode-unavailable" fail
  fi
fi

# pin interactive TUI miss WITH fallback (I-56/I-61)
agent_mode_reset
export SB_AGENT_MODE_TUI_AVAILABLE=0
agent_mode_parse_argv --interaction-mode interactive --allow-mode-fallback --attach --control-dir "${TMPROOT}/pin-ctl" --max-turns 4 --auto-policy parent
agent_mode_preflight_flags
agent_mode_resolve_mode "pi" "$TASKA" "do it" ""
agent_mode_persist_mode_json "$TASKA"
REASON_BLOB="$(cat "${TASKA}/mode.json")"
[[ "$SB_AM_RESOLVED" == "non-interactive" ]] \
  && grep -q 'mode_fallback:interactive→non-interactive:tui-unavailable:allow-mode-fallback' <<<"$REASON_BLOB" \
  && grep -q 'fallback_drop:attach' <<<"$REASON_BLOB" \
  && grep -q 'fallback_drop:control-dir' <<<"$REASON_BLOB" \
  && grep -q 'fallback_drop:max-turns' <<<"$REASON_BLOB" \
  && grep -q 'fallback_drop:auto-policy' <<<"$REASON_BLOB" \
  && [[ ! -d "${TASKA}/control" ]] \
  && check "pinned fallback hop audits mode_fallback + fallback_drop and skips control/" pass \
  || check "pinned fallback hop audits mode_fallback + fallback_drop and skips control/" fail

# NI session.json may omit turns/wave (I-58)
agent_mode_reset
agent_mode_write_session_json "${TASKA}/ni-session.json" "dead" "conv-ni" "" "" "" ""
python3 - "${TASKA}/ni-session.json" <<'PY'
import json, sys
obj = json.load(open(sys.argv[1]))
assert obj["status"] == "dead"
assert obj["conversation_id"] == "conv-ni"
assert "turns" not in obj
assert "wave_started_at" not in obj
print("ok")
PY
[[ "$(python3 -c 'import json,sys; json.load(open(sys.argv[1])); print("ok")' "${TASKA}/ni-session.json")" == "ok" ]] \
  && check "NI session.json omits turns/wave_started_at" pass \
  || check "NI session.json omits turns/wave_started_at" fail

# incomplete/missing result.md → fail + D4 (I-44)
MISS="${TMPROOT}/agent-claude/miss"
mkdir -p "$MISS"
agent_mode_reset
SB_AM_REQUESTED="auto"
SB_AM_CLASSIFIED="non-interactive"
SB_AM_RESOLVED="non-interactive"
SB_AM_REASONS=("classifier-ni")
agent_mode_normalize_incomplete_result "$MISS" 1
STATUS="$(agent_mode_result_status "${MISS}/result.md")"
[[ "$STATUS" == "fail" ]] && agent_mode_reason_has "incomplete" && agent_mode_reason_has "result-missing" \
  && check "missing result.md normalizes to STATUS fail + incomplete/result-missing" pass \
  || check "missing result.md normalizes to STATUS fail + incomplete/result-missing" fail

# escalate-unavailable clears pending D4 (I-48)
ESC="${TMPROOT}/agent-claude/esc"
mkdir -p "$ESC"
cat >"${ESC}/mode.json" <<'EOF'
{"requested":"auto","classified":"non-interactive","resolved":"non-interactive","reason":["classifier-ni","escalate-unavailable"]}
EOF
cat >"${ESC}/result.md" <<'EOF'
## STATUS
fail
EOF
: >"${ESC}/escalation.md"
agent_mode_reset
if agent_mode_pending_escalate "$ESC"; then
  check "escalate-unavailable does not re-arm D4" fail
else
  check "escalate-unavailable does not re-arm D4" pass
fi

# classifier does not read events.jsonl (I-49)
EV="${TMPROOT}/agent-claude/ev"
mkdir -p "$EV"
echo '{"event":"escalated"}' >"${EV}/events.jsonl"
cat >"${EV}/session.json" <<EOF
{"status":"dead","conversation_id":"x","updated_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
EOF
agent_mode_reset
agent_mode_classify_task "Implement and test a helper." "$EV" "claude" ""
[[ "$SB_AM_CLASSIFIED" == "non-interactive" ]] && check "classifier ignores events.jsonl" pass \
  || check "classifier ignores events.jsonl" fail

# NI never opens PTY/events/control
NIDIR="${TMPROOT}/work-ni"
mkdir -p "$NIDIR"
agent_mode_reset
export SB_AGENT_MODE_TUI_AVAILABLE=0
agent_mode_parse_argv --interaction-mode non-interactive --task-id ni-1
agent_mode_preflight_flags
agent_mode_run_delegate_resolver "claude" "$NIDIR" "Implement and test." ""
[[ "$SB_AM_RESOLVED" == "non-interactive" ]] \
  && [[ ! -e "${SB_AM_TASK_DIR}/events.jsonl" ]] \
  && [[ ! -d "${SB_AM_TASK_DIR}/control" ]] \
  && [[ -f "${SB_AM_TASK_DIR}/mode.json" ]] \
  && python3 - "${SB_AM_TASK_DIR}/mode.json" <<'PY'
import json, sys
obj = json.load(open(sys.argv[1]))
assert obj["requested"] == "non-interactive"
assert obj["classified"] is None
assert obj["resolved"] == "non-interactive"
assert "turns" not in obj
assert "pin" in obj["reason"]
print("ok")
PY
[[ $? -eq 0 ]] && check "NI writes mode.json only (no events/control, classified null)" pass \
  || check "NI writes mode.json only (no events/control, classified null)" fail

# Pi NI argv includes provider+model (I-46)
[[ "${PI_PROVIDER:-}" == "opencode-go" && "${PI_MODEL:-}" == "mimo-v2.5" ]] \
  || true
agent_mode_reset
agent_mode_parse_argv --interaction-mode non-interactive
agent_mode_preflight_flags
SB_AM_RESOLVED="non-interactive"
agent_mode_apply_host_launch_env "pi"
[[ "$PI_PROVIDER" == "opencode-go" && "$PI_MODEL" == "mimo-v2.5" && "$PI_USE_INTERACTIVE" == "0" ]] \
  && check "Pi NI env includes provider+model and not interactive" pass \
  || check "Pi NI env includes provider+model and not interactive" fail

# OpenCode NI is run (USE_INTERACTIVE=0)
agent_mode_reset
SB_AM_RESOLVED="non-interactive"
agent_mode_apply_host_launch_env "opencode"
[[ "$OPENCODE_USE_INTERACTIVE" == "0" && "${SB_LIVE_OPENCODE_USE_INTERACTIVE:-}" == "0" ]] \
  && check "OpenCode NI sets USE_INTERACTIVE=0 (run)" pass \
  || check "OpenCode NI sets USE_INTERACTIVE=0 (run)" fail

agent_mode_reset
SB_AM_RESOLVED="interactive"
agent_mode_apply_host_launch_env "opencode"
[[ "$OPENCODE_USE_INTERACTIVE" == "1" && "$SB_LIVE_OPENCODE_USE_INTERACTIVE" == "1" ]] \
  && check "OpenCode interactive sets SB_LIVE_OPENCODE_USE_INTERACTIVE=1" pass \
  || check "OpenCode interactive sets SB_LIVE_OPENCODE_USE_INTERACTIVE=1" fail

# Cursor follow-up env: interactive sets session flag
agent_mode_reset
SB_AM_RESOLVED="interactive"
agent_mode_apply_host_launch_env "cursor"
[[ "$SB_AGENT_CURSOR_SESSION" == "1" ]] && check "Cursor interactive uses session-id follow-up env" pass \
  || check "Cursor interactive uses session-id follow-up env" fail

# AF seed round-trip
agent_mode_reset
SB_AM_REQUESTED="auto"
SB_AM_MAX_WALL_SEC="1800"
SB_AM_IDLE_SEC="45"
SEED="$(agent_mode_af_seed_fields)"
if echo "$SEED" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert o["interaction_mode"]=="auto"; assert o["max_wall_sec"]==1800; assert o["idle_sec"]==45'; then
  check "AF seed round-trips interaction_mode auto + max_wall_sec + idle_sec" pass
else
  check "AF seed round-trips interaction_mode auto + max_wall_sec + idle_sec" fail
fi

# --no-escalate unsticks pending escalate force-interactive
PEND="${TMPROOT}/agent-claude/pend"
mkdir -p "$PEND"
cat >"${PEND}/mode.json" <<'EOF'
{"requested":"auto","classified":"non-interactive","resolved":"non-interactive","reason":["classifier-ni"]}
EOF
cat >"${PEND}/result.md" <<'EOF'
## STATUS
fail
EOF
: >"${PEND}/escalation.md"
agent_mode_reset
SB_AM_NO_ESCALATE=1
agent_mode_classify_task "Implement and test." "$PEND" "claude" ""
[[ "$SB_AM_CLASSIFIED" == "non-interactive" ]] && check "--no-escalate disables in-flight-escalate force-interactive" pass \
  || check "--no-escalate disables in-flight-escalate force-interactive" fail

# interactive question loop via ctl.sh
IX="${TMPROOT}/ix"
CTLDIR="${IX}/control"
mkdir -p "$CTLDIR" "$IX"
mkfifo "${CTLDIR}/cmd.fifo" "${CTLDIR}/reply.fifo"
python3 "$MOCK" --task-dir "$IX" --control-dir "$CTLDIR" --timeout 15 &
MOCK_PID=$!
sleep 0.2
chmod +x "$CTL" 2>/dev/null || true
bash "$CTL" --control-dir "$CTLDIR" send "please implement foo"
sleep 0.2
bash "$CTL" --control-dir "$CTLDIR" send "src/foo.sh"
wait "$MOCK_PID"
[[ -f "${IX}/result.md" ]] && grep -q 'question' "${IX}/events.jsonl" && grep -q 'prompt_submitted' "${IX}/events.jsonl" \
  && check "interactive question → ctl.sh send → result.md" pass \
  || check "interactive question → ctl.sh send → result.md" fail

# events assistant payload redacted
agent_mode_reset
SB_AM_RESOLVED="interactive"
REDDIR="${TMPROOT}/redact"
mkdir -p "$REDDIR"
FAKE_SK="$(printf '%s-%s' 'sk' 'abc1234567890')"
agent_mode_append_event "$REDDIR" "assistant" "token=${FAKE_SK}"
! grep -q 'sk-abc' "${REDDIR}/events.jsonl" && grep -q 'REDACTED' "${REDDIR}/events.jsonl" \
  && check "events.jsonl assistant payloads are redacted" pass \
  || check "events.jsonl assistant payloads are redacted" fail

# relative --work-dir becomes absolute before chdir/exec
REL_PARENT="${TMPROOT}/rel-wd"
mkdir -p "${REL_PARENT}/nested"
if (
  cd "$REL_PARENT"
  # shellcheck source=../../scripts/lib/agent-delegate-common.sh
  source "${REPO_ROOT}/scripts/lib/agent-delegate-common.sh"
  got="$(agent_delegate_resolve_work_dir "nested")"
  [[ "$got" == /* && "$got" == *"/nested" && "$got" != nested ]]
); then
  check "relative work-dir resolves to absolute" pass
else
  check "relative work-dir resolves to absolute" fail
fi

# OpenCode adapter honors SB_LIVE_OPENCODE_USE_INTERACTIVE (never silent opencode run)
MOCK_BIN="${TMPROOT}/oc-mock-bin"
mkdir -p "$MOCK_BIN"
cat >"${MOCK_BIN}/opencode" <<'MOCK'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then
  printf 'opencode mock 0.0.0\n'
  exit 0
fi
: "${OPENCODE_MOCK_ARGV_FILE:?}"
printf '%s\n' "$@" >"$OPENCODE_MOCK_ARGV_FILE"
exit 0
MOCK
chmod +x "${MOCK_BIN}/opencode"
IXWORK="${TMPROOT}/oc-ix-work"
NIWORK="${TMPROOT}/oc-ni-work"
mkdir -p "$IXWORK" "$NIWORK"
if (
  unset SB_AGENT_OPENCODE_DELEGATION_MODE SB_MULTI_AI_OCG_PROFILE SB_MULTI_AI_OCG_POOL SB_MULTI_AI_OCG_VALIDATED
  export OPENCODE_BIN="${MOCK_BIN}/opencode"
  export OPENCODE_WORK_DIR="$IXWORK"
  export WORK_DIR="$IXWORK"
  export SB_LIVE_OPENCODE_USE_INTERACTIVE=1
  export OPENCODE_USE_INTERACTIVE=1
  export SB_AGENT_OPENCODE_DELEGATE=1
  export OPENCODE_MOCK_ARGV_FILE="${TMPROOT}/oc-ix-argv.txt"
  export OPENCODE_RUN_TIMEOUT=10
  # shellcheck source=../../tests/live/agents/opencode/agent.sh
  source "${REPO_ROOT}/tests/live/agents/opencode/agent.sh"
  agent_invoke permissive "ping" >/dev/null
  [[ -f "$OPENCODE_MOCK_ARGV_FILE" ]] || exit 1
  first="$(head -n 1 "$OPENCODE_MOCK_ARGV_FILE")"
  [[ "$first" != "run" ]] && ! grep -qx 'run' "$OPENCODE_MOCK_ARGV_FILE"
); then
  check "OpenCode interactive does not launch opencode run" pass
else
  check "OpenCode interactive does not launch opencode run" fail
fi
if (
  unset SB_AGENT_OPENCODE_DELEGATION_MODE SB_MULTI_AI_OCG_PROFILE SB_MULTI_AI_OCG_POOL SB_MULTI_AI_OCG_VALIDATED
  export OPENCODE_BIN="${MOCK_BIN}/opencode"
  export OPENCODE_WORK_DIR="$NIWORK"
  export WORK_DIR="$NIWORK"
  export SB_LIVE_OPENCODE_USE_INTERACTIVE=0
  export OPENCODE_USE_INTERACTIVE=0
  export SB_AGENT_OPENCODE_DELEGATE=1
  export OPENCODE_MOCK_ARGV_FILE="${TMPROOT}/oc-ni-argv.txt"
  export OPENCODE_RUN_TIMEOUT=10
  # shellcheck source=../../tests/live/agents/opencode/agent.sh
  source "${REPO_ROOT}/tests/live/agents/opencode/agent.sh"
  agent_invoke permissive "ping" >/dev/null || true
  [[ -f "$OPENCODE_MOCK_ARGV_FILE" ]] || exit 1
  first="$(head -n 1 "$OPENCODE_MOCK_ARGV_FILE")"
  [[ "$first" == "run" ]]
); then
  check "OpenCode NI still launches opencode run" pass
else
  check "OpenCode NI still launches opencode run" fail
fi

# run_delegate_resolver writes mode.json on mode-unavailable
UNAV="${TMPROOT}/work-unav"
mkdir -p "$UNAV"
agent_mode_reset
export SB_AGENT_MODE_TUI_AVAILABLE=0
agent_mode_parse_argv --interaction-mode interactive --task-id unav-1
agent_mode_preflight_flags
if agent_mode_run_delegate_resolver "pi" "$UNAV" "do it" "" 2>/dev/null; then
  check "run_delegate_resolver writes mode.json on mode-unavailable" fail
else
  MODE_FILE="${UNAV}/.planning/agent-pi/unav-1/mode.json"
  if [[ "$SB_AM_FAILURE_CLASS" == "mode-unavailable" && -f "$MODE_FILE" ]] \
    && python3 - "$MODE_FILE" <<'JSONCHK'
import json, sys
obj = json.load(open(sys.argv[1]))
assert obj["requested"] == "interactive"
assert "mode-unavailable" in obj["reason"]
print("ok")
JSONCHK
  then
    check "run_delegate_resolver writes mode.json on mode-unavailable" pass
  else
    check "run_delegate_resolver writes mode.json on mode-unavailable" fail
  fi
fi


# --- lightweight launch (D7) ---
agent_mode_reset
TRACE="${TMPROOT}/ni-fast.trace"
: >"$TRACE"
agent_mode_classify_task() { printf 'classify\n' >>"$TRACE"; SB_AM_CLASSIFIED="non-interactive"; }
agent_mode_detect_d3() { printf 'd3\n' >>"$TRACE"; return 1; }
agent_mode_tui_available() { printf 'tui\n' >>"$TRACE"; return 1; }
agent_mode_pi_tui_probe() { printf 'pi-probe\n' >>"$TRACE"; return 1; }
NIFAST="${TMPROOT}/work-ni-fast"
mkdir -p "$NIFAST"
agent_mode_parse_argv --interaction-mode non-interactive --task-id ni-fast
agent_mode_preflight_flags
agent_mode_run_delegate_resolver "claude" "$NIFAST" "Implement and test." ""
if [[ "$SB_AM_RESOLVED" == "non-interactive" && ! -s "$TRACE" ]] \
  && python3 - "${SB_AM_TASK_DIR}/mode.json" <<'PY'
import json, sys
obj = json.load(open(sys.argv[1]))
assert obj["requested"] == "non-interactive"
assert obj["classified"] is None
assert obj["resolved"] == "non-interactive"
assert obj["reason"] == ["pin"]
print("ok")
PY
then
  check "pinned NI skips classify/D3/TUI and writes mode.json pin" pass
else
  check "pinned NI skips classify/D3/TUI and writes mode.json pin" fail
fi
# restore real functions
# shellcheck source=../../scripts/lib/agent-mode.sh
source "$MODE_LIB"

# Cursor TUI available without SB_AGENT_CURSOR_SESSION_AVAILABLE
CURBIN="${TMPROOT}/cur-bin"
mkdir -p "$CURBIN"
printf '#!/usr/bin/env bash\nexit 0\n' >"${CURBIN}/cursor-agent"
chmod +x "${CURBIN}/cursor-agent"
if (
  unset SB_AGENT_CURSOR_SESSION_AVAILABLE SB_AGENT_MODE_TUI_AVAILABLE
  export PATH="${CURBIN}:$PATH"
  agent_mode_reset
  agent_mode_tui_available cursor
); then
  check "Cursor TUI available when cursor-agent exists (no session env)" pass
else
  check "Cursor TUI available when cursor-agent exists (no session env)" fail
fi

# Pi TUI available without REPL banner grep
PIBIN="${TMPROOT}/pi-bin"
mkdir -p "$PIBIN"
printf '#!/usr/bin/env bash\nexit 0\n' >"${PIBIN}/pi"
chmod +x "${PIBIN}/pi"
if (
  unset SB_AGENT_MODE_TUI_AVAILABLE
  export PATH="${PIBIN}:$PATH"
  agent_mode_reset
  agent_mode_tui_available pi
); then
  check "Pi TUI available when pi exists (no banner probe)" pass
else
  check "Pi TUI available when pi exists (no banner probe)" fail
fi
if ! grep -qE 'banner\|repl\|interactive' "$MODE_LIB"; then
  check "Pi probe source has no magic-string grep" pass
else
  # specifically the probe function must not grep banners
  if python3 - "$MODE_LIB" <<'PY'
import pathlib, re, sys
text = pathlib.Path(sys.argv[1]).read_text()
m = re.search(r"agent_mode_pi_tui_probe\(\) \{.*?\n\}", text, re.S)
assert m, "probe missing"
body = m.group(0)
assert "banner" not in body and "subprocess.Popen" not in body
print("ok")
PY
  then
    check "Pi probe source has no magic-string grep" pass
  else
    check "Pi probe source has no magic-string grep" fail
  fi
fi

# Native argv: Pi interactive has no -p; Cursor interactive has no --print
# shellcheck source=../../scripts/lib/agent-host-exec.sh
source "${REPO_ROOT}/scripts/lib/agent-host-exec.sh"
HOSTBIN="${TMPROOT}/host-bin"
mkdir -p "$HOSTBIN"
for fake in pi cursor-agent claude opencode; do
  printf '#!/usr/bin/env bash\nexit 0\n' >"${HOSTBIN}/${fake}"
  chmod +x "${HOSTBIN}/${fake}"
done
printf '#!/usr/bin/env bash\nexit 0\n' >"${HOSTBIN}/codex"
chmod +x "${HOSTBIN}/codex"
if (
  export PATH="${HOSTBIN}:$PATH"
  unset SB_AGENT_HOST_ARGV_FILE
  agent_host_build_argv pi interactive "$NIFAST" "hello" permissive
  ! printf '%s\n' "${AGENT_HOST_ARGV[@]}" | grep -qx -- '-p'
) && (
  export PATH="${HOSTBIN}:$PATH"
  agent_host_build_argv pi non-interactive "$NIFAST" "hello" permissive
  printf '%s\n' "${AGENT_HOST_ARGV[@]}" | grep -qx -- '-p'
); then
  check "Pi interactive argv has no -p; NI argv has -p" pass
else
  check "Pi interactive argv has no -p; NI argv has -p" fail
fi
if (
  export PATH="${HOSTBIN}:$PATH"
  agent_host_build_argv cursor interactive "$NIFAST" "hello" permissive
  ! printf '%s\n' "${AGENT_HOST_ARGV[@]}" | grep -qx -- '--print'
) && (
  export PATH="${HOSTBIN}:$PATH"
  agent_host_build_argv cursor non-interactive "$NIFAST" "hello" permissive
  printf '%s\n' "${AGENT_HOST_ARGV[@]}" | grep -qx -- '--print'
); then
  check "Cursor interactive argv has no --print; NI argv has --print" pass
else
  check "Cursor interactive argv has no --print; NI argv has --print" fail
fi

# Quota not default on pinned NI; --quota-retry re-enables
# shellcheck source=../../scripts/lib/agent-delegate-common.sh
source "${REPO_ROOT}/scripts/lib/agent-delegate-common.sh"
agent_mode_reset
SB_AM_CONCRETE_PIN=1
SB_AM_REQUESTED="non-interactive"
SB_AM_RESOLVED="non-interactive"
got="$(agent_delegate_quota_retry_max AGENT_CLAUDE_QUOTA_RETRY_MAX 5)"
[[ "$got" == "0" ]] && check "pinned NI quota-retry max defaults to 0" pass \
  || check "pinned NI quota-retry max defaults to 0" fail
agent_mode_reset
SB_AM_CONCRETE_PIN=1
SB_AM_REQUESTED="non-interactive"
SB_AM_RESOLVED="non-interactive"
SB_AM_QUOTA_RETRY=1
got="$(agent_delegate_quota_retry_max AGENT_CLAUDE_QUOTA_RETRY_MAX 5)"
[[ "$got" == "5" ]] && check "--quota-retry restores default max on pinned NI" pass \
  || check "--quota-retry restores default max on pinned NI" fail
agent_mode_reset
got="$(agent_delegate_quota_retry_max AGENT_CLAUDE_QUOTA_RETRY_MAX 5)"
[[ "$got" == "5" ]] && check "auto path keeps quota-retry default 5" pass \
  || check "auto path keeps quota-retry default 5" fail

# Pinned NI process tree: exec native mock, no expect/tmux/python idle watcher
MOCKCLAUDE="${HOSTBIN}/claude"
cat >"$MOCKCLAUDE" <<'MOCK'
#!/usr/bin/env bash
: "${SB_AGENT_HOST_TREE_FILE:?}"
{
  printf 'argv=%s\n' "$*"
  ps -o comm= -p "$PPID" 2>/dev/null || true
  pstree -p $$ 2>/dev/null || ps -ax -o pid,ppid,comm 2>/dev/null | head -n 20 || true
} >"$SB_AGENT_HOST_TREE_FILE"
exit 0
MOCK
chmod +x "$MOCKCLAUDE"
TREE="${TMPROOT}/ni-tree.txt"
ARGVF="${TMPROOT}/ni-argv.txt"
NIEXEC="${TMPROOT}/ni-exec-work"
mkdir -p "$NIEXEC"
if (
  export PATH="${HOSTBIN}:$PATH"
  export CLAUDE_BIN="$MOCKCLAUDE"
  export SB_AGENT_HOST_ARGV_FILE="$ARGVF"
  export SB_AGENT_HOST_TREE_FILE="$TREE"
  agent_host_exec_native claude "$NIEXEC" "ping" permissive
); then
  :
fi
if [[ -f "$ARGVF" ]] && grep -q -- '--print' "$ARGVF" \
  && [[ -f "$TREE" ]] && ! grep -qiE 'expect|tmux|idle' "$TREE"; then
  check "pinned NI exec tree has native argv and no expect/tmux/idle" pass
else
  check "pinned NI exec tree has native argv and no expect/tmux/idle" fail
fi

echo
echo "=== results: ${PASS} passed, ${FAIL} failed ==="
[[ "$FAIL" -eq 0 ]]
