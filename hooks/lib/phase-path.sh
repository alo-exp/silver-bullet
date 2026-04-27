# shellcheck shell=bash
# Silver Bullet — path-to-phase resolver (Phase 71, HOOK-01..HOOK-04).
# Used by hooks/phase-lock-claim.sh and the informational lock-owner peek
# in completion-audit.sh / stop-check.sh. Centralises the regex so all
# phase-lock hooks see the same definition of "this path lives under
# .planning/phases/<NNN>/".
#
# CONTEXT.md decision: Path-to-phase resolution — emit the zero-padded
# 3-digit phase number for any path matching `.planning/phases/<NNN>[-/]`,
# emit empty stdout (and return 0) on no-match. Returning 0 in BOTH cases
# lets callers safely use `phase=$(_resolve_phase_from_path "$path") || true`
# and treat empty as "not a phase-locked path".
#
# Usage:
#   source "${_lib_dir}/phase-path.sh"
#   phase=$(_resolve_phase_from_path "$file_path") || true
#   if [[ -n "$phase" ]]; then
#     # phase is a 3-digit zero-padded string, e.g. "071"
#     ...
#   fi
#
# Match cases (all return 0, stdout = "071"):
#   .planning/phases/071-foo/bar.md
#   /abs/path/.planning/phases/071-foo/
#   .planning/phases/071/
#
# No-match cases (all return 0, stdout = ""):
#   /etc/passwd
#   src/foo.ts
#   .planning/phases/abc-foo/   (non-numeric)

_resolve_phase_from_path() {
  local path="${1:-}"
  if [[ "$path" =~ \.planning/phases/([0-9]{3})[-/] ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
  fi
  return 0
}

# _phase_lock_peek_on_exit — informational EXIT-trap helper for Phase 71
# HOOK-04 (informational half). Sourced by completion-audit.sh and
# stop-check.sh, registered via `trap _phase_lock_peek_on_exit EXIT`.
#
# Behavior:
# - Resolves a phase from $PWD.
# - If $PWD is not under .planning/phases/<NNN>/ → silent no-op.
# - If `.planning/scripts/phase-lock.sh` is missing or not executable → silent.
# - If jq is missing → silent (the peek output is JSON we need to parse).
# - If the phase has no active lock → emit `WARN: phase NNN has no active
#   lock — proceeding anyway` on stderr.
# - If the lock is owned by a non-`claude` runtime → emit `WARN: phase NNN
#   is currently locked by <owner_id> — proceeding anyway` on stderr.
# - In ALL cases preserves the original exit code via $_saved_rc / return.
#
# This is intentionally non-blocking — lock ownership is orthogonal to
# skill-completion gating per CONTEXT.md HOOK-04 design.
_phase_lock_peek_on_exit() {
  local _saved_rc=$?
  command -v jq >/dev/null 2>&1 || return $_saved_rc
  local _peek_phase
  _peek_phase=$(_resolve_phase_from_path "$PWD" 2>/dev/null || true)
  [[ -z "$_peek_phase" ]] && return $_saved_rc
  # Walk up from $PWD to locate the helper (repo root may be above $PWD when
  # the user has cd'd into a phase directory — which is exactly when the
  # warning is most useful).
  local _peek_dir="$PWD"
  local _peek_helper=""
  while [[ "$_peek_dir" != "/" && "$_peek_dir" != "" ]]; do
    if [[ -x "$_peek_dir/.planning/scripts/phase-lock.sh" ]]; then
      _peek_helper="$_peek_dir/.planning/scripts/phase-lock.sh"
      break
    fi
    _peek_dir=$(dirname "$_peek_dir")
  done
  [[ -n "$_peek_helper" ]] || return $_saved_rc
  local _peek_owner_json
  _peek_owner_json=$("$_peek_helper" peek "$_peek_phase" 2>/dev/null || true)
  if [[ -z "$_peek_owner_json" ]]; then
    printf 'WARN: phase %s has no active lock — proceeding anyway\n' "$_peek_phase" >&2
  else
    local _peek_runtime _peek_owner_id
    _peek_runtime=$(printf '%s' "$_peek_owner_json" | jq -r '.agent_runtime // ""' 2>/dev/null || echo '')
    if [[ "$_peek_runtime" != "claude" ]]; then
      _peek_owner_id=$(printf '%s' "$_peek_owner_json" | jq -r '.owner_id // "?"' 2>/dev/null || echo '?')
      printf 'WARN: phase %s is currently locked by %s — proceeding anyway\n' \
        "$_peek_phase" "$_peek_owner_id" >&2
    fi
  fi
  return $_saved_rc
}
