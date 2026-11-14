#!/usr/bin/env bash
# Channel-timeline monitor shared by scripts/agent-{claude,codex,opencode,pi}/monitor.sh
# (parent supervision of a delegation log). One implementation with per-host pattern tables
# replaces four diverged copies (R8-26); the per-host monitor.sh files are 3-line shims.
# shellcheck shell=bash

# Signals are whole-word provider/harness conditions. A bare "auth" substring (AUTHORS, OAuth,
# author) is not a signal.
_AGENT_MONITOR_SIGNALS='ERROR:[^[:space:]]*|0-token|rate limit|HTTP[^0-9]{0,8}429|status[^0-9]{0,6}429|429 Too Many|token plan|not logged in|unauthorized|authentication (failed|required)|invalid[_ ]api[_ ]key|login required'
_AGENT_MONITOR_PROMPT='prompt\.submitted|Prompt submitted|Submitted prompt|prompt submitted'

agent_monitor_usage() {
  cat <<'EOF'
Usage: monitor.sh --log PATH [--interval SEC] [--stall-sec SEC] [--once]

Emits channel bullets while tailing a delegation log:
  • prompt submitted (once)
  • token / activity growth (no 0-token false-complete)
  • harness ERROR / quota / auth signals
  • idle stall (no byte growth between polls)

Parent uses this between checkpoints; not for matrix batch drivers.
EOF
}

# agent_monitor_main HOST [monitor args...]; HOST is claude|codex|opencode|pi.
agent_monitor_main() {
  set -euo pipefail
  local host="$1"
  shift
  local upper signals prompt_re
  upper="$(printf '%s' "$host" | tr '[:lower:]' '[:upper:]')"
  signals="$_AGENT_MONITOR_SIGNALS"
  prompt_re="$_AGENT_MONITOR_PROMPT"
  case "$host" in
    claude) signals="${signals}|Queued follow-up" ;;
    codex) signals="${signals}|hooks need review" ;;
    opencode) prompt_re="${prompt_re}|opencode run" ;;
    pi) prompt_re="${prompt_re}|pi -p" ;;
  esac

  local log_file="" once=0
  local interval_var="AGENT_${upper}_MONITOR_INTERVAL" stall_var="AGENT_${upper}_MONITOR_STALL_SEC"
  local floor_var="SB_AGENT_${upper}_LOG_FLOOR"
  local interval="${!interval_var:-30}" stall_sec="${!stall_var:-300}"
  local prompt_seen=0 floor_announced=0 stall_warned=0 last_bytes=0 last_growth_ts
  last_growth_ts="$(date +%s)"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --log)
        [[ $# -ge 2 ]] || { printf 'ERROR: --log requires a value\n' >&2; return 2; }
        log_file="$2"; shift 2
        ;;
      --interval)
        [[ $# -ge 2 ]] || { printf 'ERROR: --interval requires a value\n' >&2; return 2; }
        [[ "$2" =~ ^[0-9]+$ ]] || { printf 'ERROR: --interval must be numeric\n' >&2; return 2; }
        interval="$2"; shift 2
        ;;
      --stall-sec)
        [[ $# -ge 2 ]] || { printf 'ERROR: --stall-sec requires a value\n' >&2; return 2; }
        [[ "$2" =~ ^[0-9]+$ ]] || { printf 'ERROR: --stall-sec must be numeric\n' >&2; return 2; }
        stall_sec="$2"; shift 2
        ;;
      --once) once=1; shift ;;
      -h|--help) agent_monitor_usage; return 0 ;;
      *) printf 'ERROR: unknown argument: %s\n' "$1" >&2; agent_monitor_usage >&2; return 2 ;;
    esac
  done

  [[ -n "$log_file" ]] || { agent_monitor_usage >&2; return 2; }

  _agent_monitor_bullet() {
    printf '[agent-%s monitor] %s — %s\n' "$host" "$(date -u +%H:%M:%SZ)" "$1"
  }

  _agent_monitor_scan() {
    [[ -f "$log_file" ]] || return 0
    local bytes content floor
    bytes="$(wc -c <"$log_file" | tr -d ' ')"
    content="$(tail -n 120 "$log_file" 2>/dev/null || true)"

    if [[ "$prompt_seen" -eq 0 ]] && grep -qE "$prompt_re" <<<"$content" 2>/dev/null; then
      _agent_monitor_bullet "• prompt submitted (checkpoint 1 satisfied)"
      prompt_seen=1
    fi

    if [[ "$bytes" -gt "$last_bytes" ]]; then
      _agent_monitor_bullet "• activity +$((bytes - last_bytes)) B (total ${bytes} B)"
      last_bytes="$bytes"
      last_growth_ts="$(date +%s)"
      stall_warned=0
    else
      local idle=$(( $(date +%s) - last_growth_ts ))
      if [[ "$idle" -ge "$stall_sec" && "$stall_warned" -eq 0 ]]; then
        _agent_monitor_bullet "• idle ${idle}s — prepare stuck escalation (checkpoint 2)"
        stall_warned=1
      fi
    fi

    if grep -qiE "$signals" <<<"$content"; then
      _agent_monitor_bullet "• signal: $(grep -oiE "$signals" <<<"$content" | tail -1 || echo anomaly)"
    fi

    floor="${!floor_var:-512}"
    if [[ "$floor_announced" -eq 0 && "$bytes" -ge "$floor" ]]; then
      _agent_monitor_bullet "• log floor met (${bytes} B ≥ ${floor} B)"
      floor_announced=1
    elif [[ "$bytes" -gt 0 && "$bytes" -lt "$floor" && "$stall_warned" -eq 1 ]]; then
      _agent_monitor_bullet "• below log floor (${bytes} B < ${floor} B) — do not claim PASS"
    fi
  }

  if [[ "$once" -eq 1 ]]; then
    _agent_monitor_scan
    return 0
  fi

  _agent_monitor_bullet "watching $log_file (interval ${interval}s, stall ${stall_sec}s)"
  while true; do
    _agent_monitor_scan
    sleep "$interval"
  done
}
