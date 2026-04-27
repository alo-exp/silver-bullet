#!/usr/bin/env bash
# Silver Bullet — phase-lock-claim hook (HOOK-01).
#
# PreToolUse hook fired on Edit | Write | MultiEdit. When the tool's
# `tool_input.file_path` resolves under `.planning/phases/<NNN>/`, calls
# `.planning/scripts/phase-lock.sh claim <NNN> claude "<intent>"` and on
# success appends `<NNN>` to the session-claim manifest at
# `~/.claude/.silver-bullet/claimed-phases-<session>.txt` so the
# Stop/SubagentStop release hook can release everything this session
# claimed during its lifetime.
#
# Exit semantics:
# - 0 — claimed (or already claimed in this session, or not a phase path,
#   or jq missing, or helper missing, or any non-conflict helper rc).
# - 2 — lock conflict. Stderr names the current owner (phase, runtime,
#   owner_id, attempted intent, peek hint). Claude Code interprets
#   exit-2 from PreToolUse as a hard block.
#
# Project invariants honored:
# - `trap 'exit 0' ERR` so unexpected failures never block Claude.
# - jq required; warn-and-fail-open if missing.
# - `SB_PHASE_LOCK_INHERITED=true` short-circuits to exit 0 (delegated
#   subagents inherit their parent's lock; they must not double-claim).
# - State files validated to stay under `${HOME}/.claude/`.
# - Symlink writes refused via `hooks/lib/nofollow-guard.sh`.

set -euo pipefail
trap 'exit 0' ERR

# ── Delegated-subagent short-circuit (D-03) ──────────────────────────────────
if [[ "${SB_PHASE_LOCK_INHERITED:-}" == "true" ]]; then
  exit 0
fi

# ── jq probe (warn-and-fail-open) ────────────────────────────────────────────
if ! command -v jq >/dev/null 2>&1; then
  printf '{"hookSpecificOutput":{"message":"⚠️ phase-lock-claim.sh: jq missing — skipping lock claim"}}\n'
  exit 0
fi

# ── Source shared libs (phase-path, nofollow-guard) ──────────────────────────
_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
if [[ -z "$_lib_dir" || ! -f "$_lib_dir/phase-path.sh" ]]; then
  printf '{"hookSpecificOutput":{"message":"⚠️ phase-lock-claim.sh: phase-path.sh missing — skipping"}}\n'
  exit 0
fi
# shellcheck source=lib/phase-path.sh disable=SC1091
source "$_lib_dir/phase-path.sh"
if [[ -f "$_lib_dir/nofollow-guard.sh" ]]; then
  # shellcheck source=lib/nofollow-guard.sh disable=SC1091
  source "$_lib_dir/nofollow-guard.sh"
else
  sb_safe_write() { [[ -L "$1" ]] && rm -f -- "$1"; return 0; }
fi

# ── Read stdin JSON ──────────────────────────────────────────────────────────
input=$(cat)

# ── Resolve phase from tool_input.file_path ──────────────────────────────────
file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""')
[[ -z "$file_path" ]] && exit 0
phase=$(_resolve_phase_from_path "$file_path" || true)
[[ -z "$phase" ]] && exit 0

# ── Helper-exists check (graceful degrade for non-SB-initialized projects) ──
helper="$PWD/.planning/scripts/phase-lock.sh"
if [[ ! -x "$helper" ]]; then
  printf '{"hookSpecificOutput":{"message":"⚠️ phase-lock-claim.sh: %s not executable — skipping"}}\n' "$helper"
  exit 0
fi

# ── Build intent string (truncated to 120 chars) ─────────────────────────────
tool_name=$(printf '%s' "$input" | jq -r '.tool_name // "Edit"')
intent=$(printf '%.120s' "${tool_name} $(basename "$file_path")")

# ── Resolve + sanitize session id ────────────────────────────────────────────
raw_session_id=$(printf '%s' "$input" | jq -r '.session_id // empty')
[[ -z "$raw_session_id" ]] && raw_session_id="$(date +%s)-$$"
session_id=$(printf '%s' "${raw_session_id}" | tr -c 'A-Za-z0-9_-' '_')

# ── Compute manifest path + validate stays under ~/.claude/ ─────────────────
SB_STATE_DIR="${HOME}/.claude/.silver-bullet"
manifest="${SB_STATE_DIR}/claimed-phases-${session_id}.txt"
case "$manifest" in
  "$HOME"/.claude/*) ;;
  *)
    printf '{"hookSpecificOutput":{"message":"⚠️ phase-lock-claim.sh: manifest path escaped ~/.claude/ — skipping"}}\n'
    exit 0
    ;;
esac

# ── Ensure state dir exists ──────────────────────────────────────────────────
umask 0077
mkdir -p "$(dirname "$manifest")" 2>/dev/null || true

# ── Idempotent claim — skip if this session already claimed this phase ──────
if grep -Fxq "$phase" "$manifest" 2>/dev/null; then
  exit 0
fi

# ── Call helper ─────────────────────────────────────────────────────────────
# Suspend ERR trap during the call: the trap is inherited by the $() subshell
# and would fire on the helper's non-zero conflict exit, short-circuiting
# before helper_rc is read. Re-arm the trap after the call.
trap - ERR
set +e
helper_stderr=$("$helper" claim "$phase" "claude" "$intent" 2>&1 >/dev/null)
helper_rc=$?
set -e
trap 'exit 0' ERR

case "$helper_rc" in
  0)
    # Acquired (or stolen-stale) — record in manifest.
    sb_safe_write "$manifest"
    printf '%s\n' "$phase" >> "$manifest"
    exit 0
    ;;
  2)
    # Conflict — emit stderr block-message and exit 2 (PreToolUse block).
    owner_json=$("$helper" peek "$phase" 2>/dev/null || true)
    owner_runtime=$(printf '%s' "$owner_json" | jq -r '.agent_runtime // "?"' 2>/dev/null || echo '?')
    owner_id=$(printf '%s' "$owner_json" | jq -r '.owner_id // "?"' 2>/dev/null || echo '?')
    printf '🚫 PHASE LOCK CONFLICT — phase %s is locked by %s (owner_id=%s).\n' "$phase" "$owner_runtime" "$owner_id" >&2
    printf 'Attempted intent: %s\n' "$intent" >&2
    [[ -n "$helper_stderr" ]] && printf '%s\n' "$helper_stderr" >&2
    # shellcheck disable=SC2016  # backticks are literal markdown, not command substitution
    printf 'Hint: run `.planning/scripts/phase-lock.sh peek %s` for details.\n' "$phase" >&2
    exit 2
    ;;
  *)
    # 1 (internal) / 3 (unknown runtime) / 4 (usage) / other — fail-open.
    printf '{"hookSpecificOutput":{"message":"⚠️ phase-lock-claim.sh: helper exit %d — proceeding without claim"}}\n' "$helper_rc"
    exit 0
    ;;
esac
