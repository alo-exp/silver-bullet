#!/usr/bin/env bash
# Silver Bullet — phase-lock-heartbeat hook (HOOK-02).
#
# PostToolUse hook fired on Edit | Write | MultiEdit | Bash. For every phase
# in the session-claim manifest, calls
# `.planning/scripts/phase-lock.sh heartbeat <phase> claude` to refresh the
# lock's `last_heartbeat_at` so the lock doesn't expire under the stale-TTL
# steal rule. Throttled to once per 5 minutes per phase via mtime on
# `~/.claude/.silver-bullet/heartbeat-<phase>`.
#
# Project invariants: trap 'exit 0' ERR; jq required (warn-and-fail-open);
# SB_PHASE_LOCK_INHERITED=true short-circuits; state files under ~/.claude/.

set -euo pipefail
trap 'exit 0' ERR

# ── Delegated-subagent short-circuit ────────────────────────────────────────
if [[ "${SB_PHASE_LOCK_INHERITED:-}" == "true" ]]; then
  exit 0
fi

# ── jq probe (warn-and-fail-open) ────────────────────────────────────────────
if ! command -v jq >/dev/null 2>&1; then
  printf '{"hookSpecificOutput":{"message":"⚠️ phase-lock-heartbeat.sh: jq missing — skipping"}}\n'
  exit 0
fi

# ── Source nofollow-guard ───────────────────────────────────────────────────
_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
if [[ -n "$_lib_dir" && -f "$_lib_dir/nofollow-guard.sh" ]]; then
  # shellcheck source=lib/nofollow-guard.sh disable=SC1091
  source "$_lib_dir/nofollow-guard.sh"
else
  sb_safe_write() { [[ -L "$1" ]] && rm -f -- "$1"; return 0; }
fi

# ── Helper-exists check (graceful degrade) ──────────────────────────────────
helper="$PWD/.planning/scripts/phase-lock.sh"
[[ -x "$helper" ]] || exit 0

# ── Read stdin and resolve session id ───────────────────────────────────────
input=$(cat)
raw_session_id=$(printf '%s' "$input" | jq -r '.session_id // empty')
[[ -z "$raw_session_id" ]] && raw_session_id="$(date +%s)-$$"
session_id=$(printf '%s' "${raw_session_id}" | tr -c 'A-Za-z0-9_-' '_')

SB_STATE_DIR="${HOME}/.claude/.silver-bullet"
manifest="${SB_STATE_DIR}/claimed-phases-${session_id}.txt"
case "$manifest" in
  "$HOME"/.claude/*) ;;
  *) exit 0 ;;
esac

[[ -f "$manifest" && ! -L "$manifest" ]] || exit 0
[[ -s "$manifest" ]] || exit 0

# ── Iterate manifest, throttle, heartbeat ───────────────────────────────────
now=$(date +%s)
while IFS= read -r phase || [[ -n "$phase" ]]; do
  [[ -z "$phase" ]] && continue
  # Defensive: phase must be 3 digits (manifest is written by claim hook
  # which already validated, but cheap to re-check)
  [[ "$phase" =~ ^[0-9]{3}$ ]] || continue

  throttle="${SB_STATE_DIR}/heartbeat-${phase}"
  case "$throttle" in
    "$HOME"/.claude/*) ;;
    *) continue ;;
  esac

  # Throttle check: skip if mtime within 300 s
  if [[ -f "$throttle" && ! -L "$throttle" ]]; then
    mtime=$(stat -c %Y "$throttle" 2>/dev/null || stat -f %m "$throttle" 2>/dev/null || echo 0)
    if (( now - mtime < 300 )); then
      continue
    fi
  fi

  # Call helper. Suspend ERR trap so the helper's non-zero rc (e.g. 2 when
  # heartbeat owner mismatches) doesn't trigger the parent trap before
  # hb_rc is read.
  trap - ERR
  set +e
  "$helper" heartbeat "$phase" "claude" >/dev/null 2>&1
  hb_rc=$?
  set -e
  trap 'exit 0' ERR

  if (( hb_rc == 0 )); then
    sb_safe_write "$throttle"
    : > "$throttle"
  else
    printf '⚠️  heartbeat skipped for phase %s (helper rc=%d)\n' "$phase" "$hb_rc" >&2
  fi
done < "$manifest"

exit 0
