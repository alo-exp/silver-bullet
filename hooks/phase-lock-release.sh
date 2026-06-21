#!/usr/bin/env bash
# Silver Bullet — phase-lock-release hook (HOOK-03).
#
# Stop / SubagentStop hook. Reads the session-claim manifest at
# `<host runtime>/.silver-bullet/claimed-phases-<session>.txt` and calls
# `.planning/scripts/phase-lock.sh release <phase> <runtime>` for every entry,
# then deletes the manifest. Stop and SubagentStop must NEVER block —
# release-on-non-owner emits a warning to stderr but continues clearing
# the rest of the manifest.
#
# Project invariants: trap 'exit 0' ERR; jq required (warn-and-fail-open);
# SB_PHASE_LOCK_INHERITED=true short-circuits; state files live under the host runtime root.

set -euo pipefail
trap 'exit 0' ERR

# ── Delegated-subagent short-circuit ────────────────────────────────────────
if [[ "${SB_PHASE_LOCK_INHERITED:-}" == "true" ]]; then
  exit 0
fi

# ── jq probe (warn-and-fail-open) ────────────────────────────────────────────
_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
if [[ -f "$_lib_dir/jq-gate.sh" ]]; then
  # shellcheck source=lib/jq-gate.sh
  source "$_lib_dir/jq-gate.sh"
fi
if declare -f sb_jq_enforcement_warn >/dev/null 2>&1; then
  sb_jq_enforcement_warn "phase-lock-release"
fi

# ── Source nofollow-guard ───────────────────────────────────────────────────
if [[ -n "$_lib_dir" && -f "$_lib_dir/nofollow-guard.sh" ]]; then
  # shellcheck source=lib/nofollow-guard.sh disable=SC1091
  source "$_lib_dir/nofollow-guard.sh"
else
  sb_safe_write() { [[ -L "$1" ]] && rm -f -- "$1"; return 0; }
fi
if [[ -f "$_lib_dir/runtime-paths.sh" ]]; then
  # shellcheck source=lib/runtime-paths.sh
  source "$_lib_dir/runtime-paths.sh"
fi

# ── Helper-exists check (graceful degrade) ──────────────────────────────────
helper="$PWD/.planning/scripts/phase-lock.sh"
[[ -x "$helper" ]] || exit 0

# ── Read stdin and resolve session id ───────────────────────────────────────
input=$(cat)
raw_session_id=$(printf '%s' "$input" | jq -r '.session_id // empty')
[[ -z "$raw_session_id" ]] && raw_session_id="$(date +%s)-$$"
session_id=$(printf '%s' "${raw_session_id}" | tr -c 'A-Za-z0-9_-' '_')

SB_STATE_DIR="${SB_RUNTIME_STATE_DIR}"
manifest="${SB_STATE_DIR}/claimed-phases-${session_id}.txt"
case "$manifest" in
  "$SB_RUNTIME_HOME_ROOT"/.silver-bullet/*) ;;
  *) exit 0 ;;
esac

[[ -f "$manifest" && ! -L "$manifest" ]] || exit 0

# ── Iterate manifest and release each entry ─────────────────────────────────
while IFS= read -r phase || [[ -n "$phase" ]]; do
  [[ -z "$phase" ]] && continue
  [[ "$phase" =~ ^[0-9]{3}$ ]] || continue

  # Suspend ERR trap during $() subshell so the helper's non-zero rc
  # doesn't fire the parent trap and short-circuit before rel_rc is read.
  trap - ERR
  set +e
  release_err=$("$helper" release "$phase" "${SB_RUNTIME_NAME}" 2>&1 >/dev/null)
  rel_rc=$?
  set -e
  trap 'exit 0' ERR

  if (( rel_rc != 0 )); then
    printf '⚠️  phase-lock-release: phase %s rc=%d: %s\n' "$phase" "$rel_rc" "$release_err" >&2
    # Continue clearing other entries even on non-owner per CONTEXT.md
    # "Manifest cleanup safety".
  fi
done < "$manifest"

# ── Clean up manifest (refuse to follow symlink) ────────────────────────────
if [[ ! -L "$manifest" ]]; then
  rm -f -- "$manifest"
fi

exit 0
