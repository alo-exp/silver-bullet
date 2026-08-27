#!/usr/bin/env bash
# Dual interaction-mode contract for /silver:agent-* (plan 17ed9bf7).
# Library-only: resolve_mode, classify_task, wait_event, flag preflight.
# Host adapters implement native ctl start/send/key/snapshot/status/abort.
# shellcheck shell=bash

agent_mode_iso_now() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

agent_mode_reset() {
  SB_AM_REQUESTED="auto"
  SB_AM_SAW_AUTO=0
  SB_AM_ARGV_HAS_INTERACTION=0
  SB_AM_CONCRETE_PIN=0
  SB_AM_PIN_INTERACTIVE=0
  SB_AM_PIN_NI=0
  SB_AM_ALIAS_IX=0
  SB_AM_ALIAS_NI=0
  SB_AM_LEGACY_NI=0
  SB_AM_LEGACY_IX=0
  SB_AM_ATTACH=0
  SB_AM_NO_ESCALATE=0
  SB_AM_ALLOW_FALLBACK=0
  SB_AM_FALLBACK_VIA=""
  SB_AM_AUTO_POLICY=""
  SB_AM_CONTROL_DIR=""
  SB_AM_MAX_TURNS=""
  SB_AM_MAX_WALL_SEC=""
  SB_AM_IDLE_SEC=""
  SB_AM_TASK_ID=""
  SB_AM_QUOTA_RETRY=0
  SB_AM_SKIP_PREFLIGHT=0
  SB_AM_PERMISSION_MODE=""
  SB_AM_CLASSIFIED=""
  SB_AM_RESOLVED=""
  SB_AM_D3_SIGNAL=""
  SB_AM_FAILURE_CLASS=""
  SB_AM_CONFLICT_DETAIL=""
  SB_AM_SHIFT=1
  SB_AM_TURNS=0
  SB_AM_WAVE_STARTED_AT=""
  SB_AM_HOST=""
  SB_AM_TASK_DIR=""
  SB_AM_UTTERANCE=""
  SB_AM_REASONS=()
  SB_AM_DROPPED=()
}

agent_mode_reset

agent_mode_reason_ok() {
  local r="$1"
  case "$r" in
    tui-unavailable|mode-unavailable|incomplete|result-missing|escalate-unavailable|escalated|d3-process-alive|d3-continue|d3-in-wave-cursor|classifier-interactive|classifier-ni|pin)
      return 0 ;;
    fallback_drop:attach|fallback_drop:control-dir|fallback_drop:max-turns|fallback_drop:auto-policy)
      return 0 ;;
    mode_fallback:interactive→non-interactive:*)
      return 0 ;;
    *)
      return 1 ;;
  esac
}

agent_mode_reason_append() {
  local r="$1"
  agent_mode_reason_ok "$r" || {
    printf 'ERROR: invalid mode.json reason code: %s\n' "$r" >&2
    return 1
  }
  local existing
  for existing in "${SB_AM_REASONS[@]+"${SB_AM_REASONS[@]}"}"; do
    [[ "$existing" == "$r" ]] && return 0
  done
  SB_AM_REASONS+=("$r")
}

agent_mode_reason_has() {
  local needle="$1" existing
  for existing in "${SB_AM_REASONS[@]+"${SB_AM_REASONS[@]}"}"; do
    [[ "$existing" == "$needle" ]] && return 0
  done
  return 1
}

agent_mode_reasons_json() {
  python3 -c 'import json,sys; print(json.dumps(sys.argv[1:]))' "${SB_AM_REASONS[@]+"${SB_AM_REASONS[@]}"}"
}

agent_mode_fail_conflict() {
  SB_AM_FAILURE_CLASS="mode-conflict"
  SB_AM_CONFLICT_DETAIL="$1"
  printf 'ERROR: mode-conflict (%s)\n' "$1" >&2
  return 2
}

agent_mode_fail_unavailable() {
  SB_AM_FAILURE_CLASS="${1:-mode-unavailable}"
  if [[ "$SB_AM_FAILURE_CLASS" == "mode-unavailable" ]]; then
    agent_mode_reason_append "mode-unavailable" || true
    if [[ -n "${SB_AM_TASK_DIR:-}" ]]; then
      agent_mode_persist_mode_json "$SB_AM_TASK_DIR" || true
    fi
  fi
  printf 'ERROR: %s\n' "$SB_AM_FAILURE_CLASS" >&2
  return 3
}

agent_mode_note_permission_mode() {
  local value="$1"
  case "$value" in
    permissive|strict)
      SB_AM_PERMISSION_MODE="$value"
      return 0
      ;;
    auto|interactive|non-interactive)
      agent_mode_fail_conflict "permission-mode-smashed"
      return 2
      ;;
    "")
      return 0
      ;;
    *)
      agent_mode_fail_conflict "invalid-permission-mode"
      return 2
      ;;
  esac
}

# Consume one interaction-mode flag. Sets SB_AM_SHIFT to 1 or 2.
# Return 0 if consumed, 1 if not an interaction flag.
agent_mode_handle_flag() {
  local flag="$1" value="${2:-}"
  SB_AM_SHIFT=1
  case "$flag" in
    --interaction-mode)
      [[ -n "$value" ]] || { agent_mode_fail_conflict "missing-interaction-mode-value"; return 2; }
      SB_AM_SHIFT=2
      SB_AM_ARGV_HAS_INTERACTION=1
      case "$value" in
        auto)
          SB_AM_REQUESTED="auto"
          SB_AM_SAW_AUTO=1
          SB_AM_CONCRETE_PIN=0
          ;;
        interactive)
          SB_AM_REQUESTED="interactive"
          SB_AM_CONCRETE_PIN=1
          SB_AM_PIN_INTERACTIVE=1
          ;;
        non-interactive)
          SB_AM_REQUESTED="non-interactive"
          SB_AM_CONCRETE_PIN=1
          SB_AM_PIN_NI=1
          ;;
        *)
          agent_mode_fail_conflict "invalid-interaction-mode"
          return 2
          ;;
      esac
      return 0
      ;;
    --interactive)
      SB_AM_ARGV_HAS_INTERACTION=1
      SB_AM_ALIAS_IX=1
      SB_AM_PIN_INTERACTIVE=1
      SB_AM_CONCRETE_PIN=1
      SB_AM_REQUESTED="interactive"
      return 0
      ;;
    --non-interactive)
      SB_AM_ARGV_HAS_INTERACTION=1
      SB_AM_ALIAS_NI=1
      SB_AM_PIN_NI=1
      SB_AM_CONCRETE_PIN=1
      SB_AM_REQUESTED="non-interactive"
      return 0
      ;;
    --use-print|--use-exec)
      SB_AM_ARGV_HAS_INTERACTION=1
      SB_AM_LEGACY_NI=1
      SB_AM_PIN_NI=1
      SB_AM_CONCRETE_PIN=1
      SB_AM_REQUESTED="non-interactive"
      return 0
      ;;
    --use-interactive)
      SB_AM_ARGV_HAS_INTERACTION=1
      SB_AM_LEGACY_IX=1
      SB_AM_PIN_INTERACTIVE=1
      SB_AM_CONCRETE_PIN=1
      SB_AM_REQUESTED="interactive"
      return 0
      ;;
    --attach)
      SB_AM_ATTACH=1
      return 0
      ;;
    --no-escalate)
      SB_AM_NO_ESCALATE=1
      return 0
      ;;
    --allow-mode-fallback)
      SB_AM_ALLOW_FALLBACK=1
      SB_AM_FALLBACK_VIA="allow-mode-fallback"
      return 0
      ;;
    --auto-policy)
      SB_AM_SHIFT=2
      case "$value" in
        parent|brief_only|supervised) SB_AM_AUTO_POLICY="$value" ;;
        *) agent_mode_fail_conflict "invalid-auto-policy"; return 2 ;;
      esac
      return 0
      ;;
    --control-dir)
      SB_AM_SHIFT=2
      SB_AM_CONTROL_DIR="$value"
      return 0
      ;;
    --max-turns)
      SB_AM_SHIFT=2
      SB_AM_MAX_TURNS="$value"
      return 0
      ;;
    --max-wall-sec)
      SB_AM_SHIFT=2
      SB_AM_MAX_WALL_SEC="$value"
      return 0
      ;;
    --idle-sec)
      SB_AM_SHIFT=2
      SB_AM_IDLE_SEC="$value"
      return 0
      ;;
    --task-id)
      SB_AM_SHIFT=2
      SB_AM_TASK_ID="$value"
      return 0
      ;;
    --quota-retry)
      SB_AM_QUOTA_RETRY=1
      return 0
      ;;
    --skip-preflight)
      SB_AM_SKIP_PREFLIGHT=1
      return 0
      ;;
    --delegation-mode)
      # Orthogonal (I-11): do not consume; host parser keeps it.
      return 1
      ;;
    *)
      return 1
      ;;
  esac
}

agent_mode_parse_argv() {
  SB_AM_UNPARSED=()
  while [[ $# -gt 0 ]]; do
    if agent_mode_handle_flag "$1" "${2:-}"; then
      shift "$SB_AM_SHIFT"
    else
      local rc=$?
      [[ "$rc" -eq 2 ]] && return 2
      SB_AM_UNPARSED+=("$1")
      shift
    fi
  done
  return 0
}

agent_mode_inherit_env_flags() {
  if [[ "${SB_AGENT_MODE_ATTACH:-}" == "1" ]]; then
    SB_AM_ATTACH=1
  fi
  if [[ "${SB_AGENT_NO_ESCALATE:-}" == "1" ]]; then
    SB_AM_NO_ESCALATE=1
  fi
  if [[ "${SB_AGENT_ALLOW_MODE_FALLBACK:-}" == "1" ]]; then
    SB_AM_ALLOW_FALLBACK=1
    [[ -n "$SB_AM_FALLBACK_VIA" ]] || SB_AM_FALLBACK_VIA="SB_AGENT_ALLOW_MODE_FALLBACK"
  fi
  if [[ -n "${SB_AGENT_AUTO_POLICY:-}" && -z "$SB_AM_AUTO_POLICY" ]]; then
    SB_AM_AUTO_POLICY="$SB_AGENT_AUTO_POLICY"
  fi
  if [[ -n "${SB_AGENT_MAX_TURNS:-}" && -z "$SB_AM_MAX_TURNS" ]]; then
    SB_AM_MAX_TURNS="$SB_AGENT_MAX_TURNS"
  fi
  if [[ -n "${SB_AGENT_MAX_WALL_SEC:-}" && -z "$SB_AM_MAX_WALL_SEC" ]]; then
    SB_AM_MAX_WALL_SEC="$SB_AGENT_MAX_WALL_SEC"
  fi
  if [[ -n "${SB_AGENT_IDLE_SEC:-}" && -z "$SB_AM_IDLE_SEC" ]]; then
    SB_AM_IDLE_SEC="$SB_AGENT_IDLE_SEC"
  fi
}

agent_mode_unset_consumed_env() {
  unset SB_AGENT_INTERACTION_MODE SB_AGENT_ALLOW_MODE_FALLBACK \
    SB_AGENT_MODE_ATTACH SB_AGENT_NO_ESCALATE SB_AGENT_AUTO_POLICY \
    SB_AGENT_MAX_TURNS 2>/dev/null || true
}

# Stage-1 preflight (before classify). Does not apply attach-on-ni (needs classify).
agent_mode_preflight_flags() {
  agent_mode_inherit_env_flags

  local leftover="${SB_AGENT_INTERACTION_MODE:-}"
  if [[ "$SB_AM_ARGV_HAS_INTERACTION" -eq 0 ]]; then
    case "$leftover" in
      interactive|non-interactive)
        agent_mode_fail_conflict "leftover-env-pin"
        return 2
        ;;
      auto|"")
        SB_AM_REQUESTED="auto"
        ;;
      *)
        if [[ -n "$leftover" ]]; then
          agent_mode_fail_conflict "leftover-env-pin"
          return 2
        fi
        ;;
    esac
  fi

  if [[ "$SB_AM_ALIAS_IX" -eq 1 && "$SB_AM_ALIAS_NI" -eq 1 ]]; then
    agent_mode_fail_conflict "opposite-aliases"
    return 2
  fi
  if [[ "$SB_AM_LEGACY_NI" -eq 1 && "$SB_AM_LEGACY_IX" -eq 1 ]]; then
    agent_mode_fail_conflict "opposite-legacy-pins"
    return 2
  fi
  if [[ "$SB_AM_PIN_INTERACTIVE" -eq 1 && "$SB_AM_PIN_NI" -eq 1 ]]; then
    agent_mode_fail_conflict "opposite-pins"
    return 2
  fi

  if [[ "$SB_AM_SAW_AUTO" -eq 1 && "$SB_AM_CONCRETE_PIN" -eq 1 ]]; then
    agent_mode_fail_conflict "auto-plus-pin"
    return 2
  fi
  if [[ "$SB_AM_REQUESTED" == "auto" && "$SB_AM_CONCRETE_PIN" -eq 1 ]]; then
    agent_mode_fail_conflict "auto-plus-pin"
    return 2
  fi

  if [[ "$SB_AM_ALLOW_FALLBACK" -eq 1 && "$SB_AM_REQUESTED" != "interactive" ]]; then
    agent_mode_fail_conflict "fallback-not-pinned"
    return 2
  fi

  if [[ "$SB_AM_REQUESTED" == "non-interactive" ]]; then
    if [[ "$SB_AM_ATTACH" -eq 1 ]]; then
      agent_mode_fail_conflict "attach-on-ni"
      return 2
    fi
    if [[ -n "$SB_AM_CONTROL_DIR" ]]; then
      agent_mode_fail_conflict "control-dir-on-ni"
      return 2
    fi
    if [[ -n "$SB_AM_MAX_TURNS" ]]; then
      agent_mode_fail_conflict "max-turns-on-ni"
      return 2
    fi
    if [[ -n "$SB_AM_AUTO_POLICY" ]]; then
      agent_mode_fail_conflict "auto-policy-on-ni"
      return 2
    fi
    if [[ "$SB_AM_ALLOW_FALLBACK" -eq 1 ]]; then
      agent_mode_fail_conflict "fallback-not-pinned"
      return 2
    fi
  fi

  agent_mode_unset_consumed_env
  return 0
}

agent_mode_pid_started_at() {
  local pid="$1"
  ps -p "$pid" -o lstart= 2>/dev/null | sed 's/^ *//'
}

agent_mode_pid_alive_identity() {
  local pid="$1" expected="${2:-}"
  [[ -n "$pid" ]] || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  [[ -n "$expected" ]] || return 1
  local actual
  actual="$(agent_mode_pid_started_at "$pid")"
  [[ "$actual" == "$expected" ]]
}

agent_mode_read_json_field() {
  local path="$1" field="$2"
  [[ -f "$path" ]] || { printf ''; return 0; }
  python3 - "$path" "$field" <<'PY'
import json, sys
path, field = sys.argv[1], sys.argv[2]
try:
    obj = json.load(open(path))
except Exception:
    print("")
    sys.exit(0)
val = obj
for part in field.split("."):
    if isinstance(val, dict) and part in val:
        val = val[part]
    else:
        print("")
        sys.exit(0)
if val is None:
    print("")
elif isinstance(val, (dict, list)):
    print(json.dumps(val))
else:
    print(val)
PY
}

agent_mode_reason_list_from_file() {
  local path="$1"
  [[ -f "$path" ]] || return 0
  python3 - "$path" <<'PY'
import json, sys
try:
    obj = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
for item in obj.get("reason") or []:
    print(item)
PY
}

agent_mode_iso_within_ttl() {
  local stamp="$1" ttl_sec="${2:-86400}"
  python3 - "$stamp" "$ttl_sec" <<'PY'
import sys
from datetime import datetime, timezone
stamp, ttl = sys.argv[1], int(sys.argv[2])
if not stamp:
    sys.exit(1)
try:
    dt = datetime.strptime(stamp, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
except Exception:
    sys.exit(1)
now = datetime.now(timezone.utc)
sys.exit(0 if (now - dt).total_seconds() <= ttl else 1)
PY
}

agent_mode_file_newer_than_iso() {
  local path="$1" stamp="$2"
  python3 - "$path" "$stamp" <<'PY'
import os, sys
from datetime import datetime, timezone
path, stamp = sys.argv[1], sys.argv[2]
if not os.path.isfile(path):
    sys.exit(1)
mtime = datetime.fromtimestamp(os.path.getmtime(path), timezone.utc)
if not stamp:
    sys.exit(0)
dt = datetime.strptime(stamp, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
sys.exit(0 if mtime > dt else 1)
PY
}

agent_mode_result_status() {
  local path="$1"
  [[ -f "$path" ]] || { printf ''; return 0; }
  python3 - "$path" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8", errors="replace").read()
m = re.search(r"(?im)^STATUS:\s*(\S+)", text)
if m:
    print(m.group(1).lower())
else:
    m2 = re.search(r"(?im)^## STATUS\s*\n\s*(\S+)", text)
    print(m2.group(1).lower() if m2 else "")
PY
}

agent_mode_pending_escalate() {
  local task_dir="$1"
  local mode_json="${task_dir}/mode.json"
  local result_md="${task_dir}/result.md"
  local escalation="${task_dir}/escalation.md"
  [[ -f "$mode_json" && -f "$escalation" ]] || return 1
  local requested classified resolved
  requested="$(agent_mode_read_json_field "$mode_json" "requested")"
  classified="$(agent_mode_read_json_field "$mode_json" "classified")"
  resolved="$(agent_mode_read_json_field "$mode_json" "resolved")"
  [[ "$requested" == "auto" && "$classified" == "non-interactive" && "$resolved" == "non-interactive" ]] || return 1
  local r
  while IFS= read -r r; do
    [[ "$r" == "tui-unavailable" || "$r" == "escalate-unavailable" || "$r" == "escalated" ]] && return 1
  done < <(agent_mode_reason_list_from_file "$mode_json")
  local status
  status="$(agent_mode_result_status "$result_md")"
  case "$status" in
    fail|blocked) return 0 ;;
    *) return 1 ;;
  esac
}

agent_mode_d4_eligible_from_state() {
  local requested="$1" classified="$2" resolved="$3"
  [[ "$requested" == "auto" && "$classified" == "non-interactive" && "$resolved" == "non-interactive" ]] || return 1
  agent_mode_reason_has "tui-unavailable" && return 1
  return 0
}

# Sets SB_AM_D3_SIGNAL to process-alive | continue | in-wave-cursor | ""
agent_mode_detect_d3() {
  local task_dir="$1" host="$2" utterance="${3:-}"
  SB_AM_D3_SIGNAL=""
  local session="${task_dir}/session.json"
  [[ -f "$session" ]] || return 1
  local status conv pid started updated
  status="$(agent_mode_read_json_field "$session" "status")"
  conv="$(agent_mode_read_json_field "$session" "conversation_id")"
  pid="$(agent_mode_read_json_field "$session" "pid")"
  started="$(agent_mode_read_json_field "$session" "pid_started_at")"
  updated="$(agent_mode_read_json_field "$session" "updated_at")"

  local ttl_ok=0
  if agent_mode_iso_within_ttl "$updated" 86400; then
    ttl_ok=1
  fi

  if agent_mode_pid_alive_identity "$pid" "$started"; then
    # Identity-matched live child outranks TTL (I-32/I-41).
    local control="${task_dir}/control"
    if [[ ! -d "$control" ]]; then
      # Orphaned driver: reset liveness, keep resume-token, classify fresh.
      agent_mode_write_session_json "$session" "dead" "$conv" "" "" "" ""
      return 1
    fi
    SB_AM_D3_SIGNAL="process-alive"
    return 0
  fi

  [[ "$ttl_ok" -eq 1 ]] || return 1

  if [[ "$host" == "cursor" && -n "$conv" && "$status" == "live" ]]; then
    SB_AM_D3_SIGNAL="in-wave-cursor"
    return 0
  fi

  local ut
  ut="$(printf '%s' "$utterance" | tr '[:upper:]' '[:lower:]')"
  if [[ -n "$conv" && -n "$ut" ]]; then
    if [[ "$ut" =~ (^|[[:space:]])(continue|coach)([[:space:]]|$) || "$ut" == *"keep going"* ]]; then
      # Explicit continue/coach utterance — not brief-flavor "continue this work".
      SB_AM_D3_SIGNAL="continue"
      return 0
    fi
  fi
  return 1
}

agent_mode_write_session_json() {
  local path="$1" status="$2" conv="${3:-}" pid="${4:-}" started="${5:-}" turns="${6:-}" wave="${7:-}"
  python3 - "$path" "$status" "$conv" "$pid" "$started" "$turns" "$wave" "$(agent_mode_iso_now)" <<'PY'
import json, os, sys
path, status, conv, pid, started, turns, wave, now = sys.argv[1:9]
obj = {"status": status, "updated_at": now}
if conv:
    obj["conversation_id"] = conv
if pid:
    obj["pid"] = int(pid) if str(pid).isdigit() else pid
if started:
    obj["pid_started_at"] = started
if turns:
    obj["turns"] = int(turns)
if wave:
    obj["wave_started_at"] = wave
os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
with open(path, "w", encoding="utf-8") as fh:
    json.dump(obj, fh, indent=2, ensure_ascii=False)
    fh.write("\n")
PY
}

# Classifier (auto only). Sets SB_AM_CLASSIFIED.
agent_mode_classify_task() {
  local brief="$1" task_dir="$2" host="${3:-}" utterance="${4:-}"
  SB_AM_CLASSIFIED="non-interactive"
  SB_AM_UTTERANCE="$utterance"

  if [[ "$SB_AM_NO_ESCALATE" -eq 0 ]] && agent_mode_pending_escalate "$task_dir"; then
    SB_AM_CLASSIFIED="interactive"
    agent_mode_reason_append "classifier-interactive"
    return 0
  fi

  if agent_mode_detect_d3 "$task_dir" "$host" "$utterance"; then
    SB_AM_CLASSIFIED="interactive"
    case "$SB_AM_D3_SIGNAL" in
      process-alive) agent_mode_reason_append "d3-process-alive" ;;
      continue) agent_mode_reason_append "d3-continue" ;;
      in-wave-cursor) agent_mode_reason_append "d3-in-wave-cursor" ;;
    esac
    return 0
  fi

  local text ut_l
  text="$(printf '%s\n%s' "$brief" "$utterance" | tr '[:upper:]' '[:lower:]')"
  ut_l="$(printf '%s' "$utterance" | tr '[:upper:]' '[:lower:]')"

  if [[ -n "$ut_l" ]] && [[ "$ut_l" =~ (^|[[:space:]])(continue|coach)([[:space:]]|$) || "$ut_l" == *"keep going"* ]]; then
    SB_AM_CLASSIFIED="interactive"
    agent_mode_reason_append "classifier-interactive"
    return 0
  fi

  local force_ix=0
  if [[ "$text" =~ checkpoint ]] || [[ "$text" =~ coaching ]] || [[ "$text" =~ picker ]] \
    || [[ "$text" =~ "ask me" ]] || [[ "$text" =~ clarif ]] || [[ "$text" =~ "q&a" ]] \
    || [[ "$text" =~ "permission picker" ]] || [[ "$text" =~ "multi-step" ]]; then
    force_ix=1
  fi

  if [[ "$force_ix" -eq 1 ]]; then
    SB_AM_CLASSIFIED="interactive"
    agent_mode_reason_append "classifier-interactive"
    return 0
  fi

  SB_AM_CLASSIFIED="non-interactive"
  agent_mode_reason_append "classifier-ni"
  return 0
}

agent_mode_tui_available() {
  local host="$1"
  case "${SB_AGENT_MODE_TUI_AVAILABLE:-}" in
    1|true|yes) return 0 ;;
    0|false|no) return 1 ;;
  esac
  case "$host" in
    claude)
      command -v expect >/dev/null 2>&1 || return 1
      command -v claude >/dev/null 2>&1 || return 1
      return 0
      ;;
    codex)
      command -v python3 >/dev/null 2>&1 || return 1
      command -v codex >/dev/null 2>&1 || return 1
      return 0
      ;;
    opencode)
      command -v opencode >/dev/null 2>&1 || return 1
      return 0
      ;;
    cursor)
      command -v cursor-agent >/dev/null 2>&1 && return 0
      command -v agent >/dev/null 2>&1 && return 0
      return 1
      ;;
    pi)
      agent_mode_pi_tui_probe
      return $?
      ;;
    *)
      return 1
      ;;
  esac
}

agent_mode_pi_tui_probe() {
  command -v pi >/dev/null 2>&1
}

agent_mode_drop_interactive_only_flags() {
  if [[ "$SB_AM_ATTACH" -eq 1 ]]; then
    SB_AM_ATTACH=0
    agent_mode_reason_append "fallback_drop:attach"
    SB_AM_DROPPED+=("attach")
  fi
  if [[ -n "$SB_AM_CONTROL_DIR" ]]; then
    SB_AM_CONTROL_DIR=""
    agent_mode_reason_append "fallback_drop:control-dir"
    SB_AM_DROPPED+=("control-dir")
  fi
  if [[ -n "$SB_AM_MAX_TURNS" ]]; then
    SB_AM_MAX_TURNS=""
    agent_mode_reason_append "fallback_drop:max-turns"
    SB_AM_DROPPED+=("max-turns")
  fi
  if [[ -n "$SB_AM_AUTO_POLICY" ]]; then
    SB_AM_AUTO_POLICY=""
    agent_mode_reason_append "fallback_drop:auto-policy"
    SB_AM_DROPPED+=("auto-policy")
  fi
  unset SB_AGENT_MODE_ATTACH 2>/dev/null || true
}

agent_mode_apply_tui_gate() {
  local host="$1" want="$2" d3="${3:-0}" d4="${4:-0}"
  if [[ "$want" != "interactive" ]]; then
    SB_AM_RESOLVED="non-interactive"
    return 0
  fi
  if agent_mode_tui_available "$host"; then
    SB_AM_RESOLVED="interactive"
    return 0
  fi
  # TUI/session miss
  if [[ "$d3" -eq 1 ]]; then
    SB_AM_RESOLVED=""
    agent_mode_fail_unavailable "mode-unavailable"
    return 3
  fi
  if [[ "$d4" -eq 1 ]]; then
    SB_AM_RESOLVED=""
    agent_mode_fail_unavailable "escalate-unavailable"
    return 3
  fi
  if [[ "$SB_AM_CONCRETE_PIN" -eq 1 && "$SB_AM_REQUESTED" == "interactive" ]]; then
    if [[ "$SB_AM_ALLOW_FALLBACK" -eq 1 ]]; then
      SB_AM_RESOLVED="non-interactive"
      agent_mode_reason_append "mode_fallback:interactive→non-interactive:tui-unavailable:${SB_AM_FALLBACK_VIA:-allow-mode-fallback}"
      agent_mode_drop_interactive_only_flags
      return 0
    fi
    SB_AM_RESOLVED=""
    agent_mode_fail_unavailable "mode-unavailable"
    return 3
  fi
  # Auto classifier-heuristic (not D3, not D4): hop to NI (I-66)
  SB_AM_RESOLVED="non-interactive"
  agent_mode_reason_append "tui-unavailable"
  agent_mode_drop_interactive_only_flags
  return 0
}

# Full resolver. Pin > D3 > classifier > NI, then TUI gate.
agent_mode_resolve_mode() {
  local host="$1" task_dir="$2" brief="${3:-}" utterance="${4:-}"
  SB_AM_HOST="$host"
  SB_AM_TASK_DIR="$task_dir"
  SB_AM_REASONS=()
  SB_AM_DROPPED=()
  SB_AM_CLASSIFIED=""
  SB_AM_RESOLVED=""
  SB_AM_D3_SIGNAL=""
  local d3=0 d4=0

  if [[ "$SB_AM_CONCRETE_PIN" -eq 1 ]]; then
    agent_mode_reason_append "pin"
    SB_AM_CLASSIFIED=""
    if [[ "$SB_AM_REQUESTED" == "non-interactive" ]]; then
      SB_AM_RESOLVED="non-interactive"
      return 0
    fi
    agent_mode_apply_tui_gate "$host" "interactive" 0 0
    return $?
  fi

  # requested auto
  if agent_mode_detect_d3 "$task_dir" "$host" "$utterance"; then
    d3=1
    SB_AM_CLASSIFIED="interactive"
    case "$SB_AM_D3_SIGNAL" in
      process-alive) agent_mode_reason_append "d3-process-alive" ;;
      continue) agent_mode_reason_append "d3-continue" ;;
      in-wave-cursor) agent_mode_reason_append "d3-in-wave-cursor" ;;
    esac
    agent_mode_apply_tui_gate "$host" "interactive" 1 0
    return $?
  fi

  agent_mode_classify_task "$brief" "$task_dir" "$host" "$utterance"

  if [[ "$SB_AM_CLASSIFIED" == "interactive" ]]; then
    agent_mode_apply_tui_gate "$host" "interactive" 0 0
    return $?
  fi

  SB_AM_RESOLVED="non-interactive"
  return 0
}

agent_mode_post_classify_conflicts() {
  if [[ "$SB_AM_REQUESTED" == "auto" && "$SB_AM_RESOLVED" == "non-interactive" ]]; then
    if [[ "$SB_AM_CLASSIFIED" == "non-interactive" ]]; then
      if [[ "$SB_AM_ATTACH" -eq 1 ]]; then
        agent_mode_fail_conflict "attach-on-ni"
        return 2
      fi
      if [[ -n "$SB_AM_CONTROL_DIR" ]]; then
        agent_mode_fail_conflict "control-dir-on-ni"
        return 2
      fi
    fi
  fi
  return 0
}

agent_mode_write_mode_json() {
  local path="$1"
  python3 - "$path" <<'PY'
import json, os, sys
path = sys.argv[1]
classified = os.environ.get("SB_AM_CLASSIFIED", "")
obj = {
    "requested": os.environ.get("SB_AM_REQUESTED", "auto"),
    "classified": None if classified in ("", "null") else classified,
    "resolved": os.environ.get("SB_AM_RESOLVED", ""),
    "reason": json.loads(os.environ.get("SB_AM_REASON_JSON", "[]")),
}
if os.environ.get("SB_AM_RESOLVED") == "interactive":
    obj["turns"] = int(os.environ.get("SB_AM_TURNS") or "0")
    obj["wave_started_at"] = os.environ.get("SB_AM_WAVE_STARTED_AT") or os.environ.get("SB_AM_NOW", "")
os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
with open(path, "w", encoding="utf-8") as fh:
    json.dump(obj, fh, indent=2, ensure_ascii=False)
    fh.write("\n")
PY
}

agent_mode_persist_mode_json() {
  local task_dir="$1"
  mkdir -p "$task_dir"
  export SB_AM_REQUESTED SB_AM_CLASSIFIED SB_AM_RESOLVED SB_AM_TURNS
  export SB_AM_REASON_JSON
  SB_AM_REASON_JSON="$(agent_mode_reasons_json)"
  if [[ "$SB_AM_RESOLVED" == "interactive" && -z "$SB_AM_WAVE_STARTED_AT" ]]; then
    SB_AM_WAVE_STARTED_AT="$(agent_mode_iso_now)"
  fi
  export SB_AM_WAVE_STARTED_AT
  export SB_AM_NOW
  SB_AM_NOW="$(agent_mode_iso_now)"
  agent_mode_write_mode_json "${task_dir}/mode.json"
}

agent_mode_redact() {
  local blob="$1"
  if declare -f agent_delegate_redact_output >/dev/null 2>&1; then
    agent_delegate_redact_output "$blob"
    return 0
  fi
  printf '%s' "$blob" | sed -E \
    -e 's/(api[_-]?key|token|password|secret|authorization|bearer)[[:space:]]*[:=][[:space:]]*[^[:space:]]+/\1=[REDACTED]/gi' \
    -e 's/sk-[A-Za-z0-9_-]{8,}/sk-[REDACTED]/g' \
    -e 's/ghp_[A-Za-z0-9]{20,}/ghp_[REDACTED]/g'
}

agent_mode_append_event() {
  local task_dir="$1" event="$2" payload="${3:-}"
  [[ "$SB_AM_RESOLVED" == "interactive" ]] || return 0
  mkdir -p "$task_dir"
  local redacted
  redacted="$(agent_mode_redact "$payload")"
  python3 - "$task_dir/events.jsonl" "$event" "$redacted" "$(agent_mode_iso_now)" <<'PY'
import json, sys
path, event, payload, now = sys.argv[1:5]
obj = {"event": event, "ts": now}
if payload:
    obj["payload"] = payload
with open(path, "a", encoding="utf-8") as fh:
    fh.write(json.dumps(obj) + "\n")
PY
}

agent_mode_prepare_artifact_dir() {
  local host="$1" work_dir="$2"
  local task_id="${SB_AM_TASK_ID:-task-$(date -u +%Y%m%dT%H%M%SZ)}"
  SB_AM_TASK_ID="$task_id"
  SB_AM_TASK_DIR="${SB_AGENT_TASK_DIR:-${work_dir}/.planning/agent-${host}/${task_id}}"
  mkdir -p "$SB_AM_TASK_DIR"
  if [[ "$SB_AM_RESOLVED" == "interactive" ]]; then
    local control="${SB_AM_CONTROL_DIR:-${SB_AM_TASK_DIR}/control}"
    SB_AM_CONTROL_DIR="$control"
    mkdir -p "$control" "${SB_AM_TASK_DIR}/snapshots"
    [[ -p "${control}/cmd.fifo" ]] || mkfifo "${control}/cmd.fifo"
    [[ -p "${control}/reply.fifo" ]] || mkfifo "${control}/reply.fifo"
    export SB_AGENT_CONTROL_DIR="$control"
  else
    # NI: never create control/ (I-61/I-66)
    SB_AM_CONTROL_DIR=""
    unset SB_AGENT_CONTROL_DIR
  fi
  printf '%s' "$SB_AM_TASK_DIR"
}

agent_mode_apply_host_launch_env() {
  local host="$1"
  export SB_AGENT_RESOLVED_MODE="$SB_AM_RESOLVED"
  export SB_AGENT_REQUESTED_MODE="$SB_AM_REQUESTED"
  case "$host" in
    claude)
      if [[ "$SB_AM_RESOLVED" == "non-interactive" ]]; then
        export CLAUDE_USE_INTERACTIVE=0
      else
        export CLAUDE_USE_INTERACTIVE=1
      fi
      ;;
    codex)
      if [[ "$SB_AM_RESOLVED" == "non-interactive" ]]; then
        export SB_LIVE_CODEX_USE_EXEC=1
        export CODEX_LAUNCH_MODE="exec"
      else
        export SB_LIVE_CODEX_USE_EXEC=0
        export CODEX_LAUNCH_MODE="interactive"
      fi
      ;;
    opencode)
      if [[ "$SB_AM_RESOLVED" == "interactive" ]]; then
        export OPENCODE_USE_INTERACTIVE=1
        export SB_LIVE_OPENCODE_USE_INTERACTIVE=1
      else
        export OPENCODE_USE_INTERACTIVE=0
        export SB_LIVE_OPENCODE_USE_INTERACTIVE=0
      fi
      ;;
    pi)
      export PI_PROVIDER="${PI_PROVIDER:-opencode-go}"
      export PI_MODEL="${PI_MODEL:-mimo-v2.5}"
      if [[ "$SB_AM_RESOLVED" == "interactive" ]]; then
        export PI_USE_INTERACTIVE=1
      else
        export PI_USE_INTERACTIVE=0
      fi
      ;;
    cursor)
      if [[ "$SB_AM_RESOLVED" == "interactive" ]]; then
        export SB_AGENT_CURSOR_SESSION=1
        export SB_LIVE_CURSOR_FORCE_HEADLESS=0
      else
        export SB_AGENT_CURSOR_SESSION=0
        export SB_LIVE_CURSOR_FORCE_HEADLESS=1
      fi
      ;;
  esac
  if [[ -n "$SB_AM_IDLE_SEC" ]]; then
    export SB_AGENT_IDLE_SEC="$SB_AM_IDLE_SEC"
  fi
}

agent_mode_append_reason_to_file() {
  local path="$1" extra="$2"
  [[ -f "$path" ]] || return 1
  python3 - "$path" "$extra" <<'PY'
import json, sys
path, extra = sys.argv[1], sys.argv[2]
obj = json.load(open(path))
reasons = list(obj.get("reason") or [])
if extra not in reasons:
    reasons.append(extra)
obj["reason"] = reasons
with open(path, "w", encoding="utf-8") as fh:
    json.dump(obj, fh, indent=2, ensure_ascii=False)
    fh.write("\n")
PY
}

agent_mode_normalize_incomplete_result() {
  local task_dir="$1" missing="${2:-0}"
  mkdir -p "$task_dir"
  local result="${task_dir}/result.md"
  if [[ ! -f "$result" ]]; then
    missing=1
    cat >"$result" <<'EOF'
## STATUS
fail

## TASK
(none)

## FILES
(none)

## TESTS
(none)

## COMMIT
(none)

## BLOCKERS
incomplete / result-missing

## NEXT_RETRY_PROMPT
(none)
EOF
  else
    python3 - "$result" <<'PY'
import re, sys
path = sys.argv[1]
text = open(path, encoding="utf-8", errors="replace").read()
if re.search(r"(?im)^STATUS:\s*(pass|fail|blocked)\b", text):
    sys.exit(0)
if not re.search(r"(?im)^## STATUS", text):
    text = "## STATUS\nfail\n\n" + text
else:
    text = re.sub(r"(?im)^(## STATUS\s*\n)(.*)", r"\1fail\n", text, count=1)
open(path, "w", encoding="utf-8").write(text)
PY
  fi
  agent_mode_reason_append "incomplete"
  [[ "$missing" -eq 1 ]] && agent_mode_reason_append "result-missing"
  agent_mode_persist_mode_json "$task_dir"
}

agent_mode_write_escalation() {
  local task_dir="$1" why="$2" log_file="${3:-}"
  local result="${task_dir}/result.md"
  {
    printf '# Escalation (auto NI → interactive)\n\n'
    printf '%s\n\n' "$why"
    if [[ -f "$result" ]]; then
      python3 - "$result" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8", errors="replace").read()
m = re.search(r"(?im)^## NEXT_RETRY_PROMPT\s*\n(.*?)(?=\n## |\Z)", text, re.S)
if m:
    body = m.group(1).strip()
    if body and body != "(none)":
        print("## NEXT_RETRY_PROMPT")
        print(body)
        print()
PY
    fi
    if [[ -n "$log_file" && -f "$log_file" ]]; then
      printf '## Log tail\n\n```\n'
      tail -n 80 "$log_file" 2>/dev/null || true
      printf '```\n'
    fi
  } >"${task_dir}/escalation.md"
}

# D4: auto classifier-selected NI miss → one interactive retry.
# Returns 0 if retry should start (resolved flipped to interactive via TUI gate).
agent_mode_maybe_escalate() {
  local host="$1" task_dir="$2" log_file="${3:-}"
  [[ "$SB_AM_NO_ESCALATE" -eq 0 ]] || return 1
  agent_mode_d4_eligible_from_state "$SB_AM_REQUESTED" "$SB_AM_CLASSIFIED" "$SB_AM_RESOLVED" || return 1
  agent_mode_write_escalation "$task_dir" "Auto non-interactive wave missed acceptance." "$log_file"
  agent_mode_append_reason_to_file "${task_dir}/mode.json" "escalated"
  agent_mode_reason_append "escalated"
  SB_AM_TURNS=0
  SB_AM_WAVE_STARTED_AT="$(agent_mode_iso_now)"
  agent_mode_apply_tui_gate "$host" "interactive" 0 1
  local rc=$?
  if [[ "$rc" -ne 0 ]]; then
    agent_mode_append_reason_to_file "${task_dir}/mode.json" "escalate-unavailable"
    agent_mode_reason_append "escalate-unavailable"
    return 1
  fi
  agent_mode_prepare_artifact_dir "$host" "$(dirname "$(dirname "$task_dir")")" >/dev/null
  agent_mode_append_event "$task_dir" "escalated" ""
  agent_mode_append_event "$task_dir" "mode_resolved" "interactive"
  return 0
}

# Default fifo ctl ops (interactive only).
agent_mode_ctl_write() {
  local control="$1" json="$2"
  [[ -p "${control}/cmd.fifo" ]] || return 1
  python3 - "${control}/cmd.fifo" "$json" <<'PY'
import sys
path, payload = sys.argv[1], sys.argv[2]
with open(path, "w", encoding="utf-8") as fh:
    fh.write(payload.rstrip() + "\n")
PY
}

agent_mode_ctl_send() {
  local control="$1" text="$2"
  python3 -c 'import json,sys; print(json.dumps({"op":"send","text":sys.argv[1]}))' "$text" \
    | { read -r line; agent_mode_ctl_write "$control" "$line"; }
}

agent_mode_ctl_key() {
  local control="$1" name="$2"
  python3 -c 'import json,sys; print(json.dumps({"op":"key","name":sys.argv[1]}))' "$name" \
    | { read -r line; agent_mode_ctl_write "$control" "$line"; }
}

agent_mode_ctl_op() {
  local control="$1" op="$2"
  python3 -c 'import json,sys; print(json.dumps({"op":sys.argv[1]}))' "$op" \
    | { read -r line; agent_mode_ctl_write "$control" "$line"; }
}

agent_mode_wait_event() {
  local events="$1" name="$2" timeout_sec="${3:-30}"
  python3 - "$events" "$name" "$timeout_sec" <<'PY'
import json, os, sys, time
path, name, timeout = sys.argv[1], sys.argv[2], float(sys.argv[3])
deadline = time.time() + timeout
while time.time() < deadline:
    if os.path.isfile(path):
        with open(path, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except Exception:
                    continue
                if obj.get("event") == name:
                    print(line)
                    sys.exit(0)
    time.sleep(0.05)
sys.exit(1)
PY
}

# Orchestrator seed extras (I-43 / I-47). Prints JSON object on stdout.
agent_mode_af_seed_fields() {
  export SB_AM_REQUESTED SB_AM_MAX_TURNS SB_AM_MAX_WALL_SEC SB_AM_IDLE_SEC
  export SB_AM_ATTACH SB_AM_NO_ESCALATE SB_AM_ALLOW_FALLBACK SB_AM_CONTROL_DIR SB_AM_AUTO_POLICY
  python3 - <<PY
import json, os
mode = os.environ.get("SB_AM_REQUESTED", "auto")
fallback = os.environ.get("SB_AM_ALLOW_FALLBACK", "0") == "1"
obj = {
    "interaction_mode": mode,
    "max_turns": int(os.environ["SB_AM_MAX_TURNS"]) if os.environ.get("SB_AM_MAX_TURNS") else 8,
    "max_wall_sec": int(os.environ["SB_AM_MAX_WALL_SEC"]) if os.environ.get("SB_AM_MAX_WALL_SEC") else None,
    "idle_sec": int(os.environ["SB_AM_IDLE_SEC"]) if os.environ.get("SB_AM_IDLE_SEC") else None,
    "attach": os.environ.get("SB_AM_ATTACH", "0") == "1",
    "no_escalate": os.environ.get("SB_AM_NO_ESCALATE", "0") == "1",
    "allow_mode_fallback": fallback,
    "control_dir": os.environ.get("SB_AM_CONTROL_DIR") or None,
    "auto_policy": os.environ.get("SB_AM_AUTO_POLICY") or "supervised",
}
print(json.dumps(obj))
PY
}

agent_mode_validate_af_seed() {
  local mode="${1:-auto}" allow="${2:-false}"
  if [[ "$allow" == "true" || "$allow" == "1" ]] && [[ "$mode" != "interactive" ]]; then
    agent_mode_fail_conflict "fallback-not-pinned"
    return 2
  fi
  return 0
}

# End-to-end helper used by host delegates after host flags are parsed.
agent_mode_run_delegate_resolver() {
  local host="$1" work_dir="$2" brief="${3:-}" utterance="${4:-}"
  agent_mode_preflight_flags || return $?
  agent_mode_note_permission_mode "${MODE:-${SB_AM_PERMISSION_MODE:-permissive}}" || return $?
  local task_id="${SB_AM_TASK_ID:-task-$(date -u +%Y%m%dT%H%M%SZ)}"
  SB_AM_TASK_ID="$task_id"
  local task_dir="${SB_AGENT_TASK_DIR:-${work_dir}/.planning/agent-${host}/${task_id}}"
  mkdir -p "$task_dir"
  printf '%s' "$brief" >"${task_dir}/brief.md"
  # Pinned NI: persist mode.json and return — no classify / D3 / TUI / D4.
  if [[ "$SB_AM_CONCRETE_PIN" -eq 1 && "$SB_AM_REQUESTED" == "non-interactive" ]]; then
    SB_AM_HOST="$host"
    SB_AM_TASK_DIR="$task_dir"
    SB_AM_REASONS=()
    SB_AM_DROPPED=()
    SB_AM_CLASSIFIED=""
    SB_AM_RESOLVED="non-interactive"
    SB_AM_D3_SIGNAL=""
    agent_mode_reason_append "pin"
    agent_mode_persist_mode_json "$task_dir"
    agent_mode_prepare_artifact_dir "$host" "$work_dir" >/dev/null
    agent_mode_apply_host_launch_env "$host"
    return 0
  fi
  agent_mode_resolve_mode "$host" "$task_dir" "$brief" "$utterance" || return $?
  agent_mode_post_classify_conflicts || return $?
  if [[ "$SB_AM_RESOLVED" == "interactive" && -z "$SB_AM_AUTO_POLICY" ]]; then
    SB_AM_AUTO_POLICY="supervised"
  fi
  if [[ "$SB_AM_RESOLVED" == "interactive" && -z "$SB_AM_MAX_TURNS" ]]; then
    SB_AM_MAX_TURNS="8"
  fi
  agent_mode_persist_mode_json "$task_dir"
  agent_mode_prepare_artifact_dir "$host" "$work_dir" >/dev/null
  if [[ "$SB_AM_RESOLVED" == "interactive" ]]; then
    agent_mode_append_event "$SB_AM_TASK_DIR" "mode_resolved" "$SB_AM_RESOLVED"
  fi
  agent_mode_apply_host_launch_env "$host"
  return 0
}
