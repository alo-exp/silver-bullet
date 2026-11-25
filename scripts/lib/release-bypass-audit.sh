# shellcheck shell=bash
# Release-gate bypass audit trail (R13-20): every use of SB_SKIP_PRE_RELEASE_GATE or SB_SKIP_RC_MATRIX is
# appended to ${SB_RUNTIME_STATE_DIR}/release-bypass-log.jsonl (who, when, which switch, which repository
# and commit) and printed, so a bypass is never silent.

_sb_rba_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# sb_release_bypass_audit SWITCH [REPO_ROOT]
sb_release_bypass_audit() {
  local switch="${1:-}" root="${2:-$PWD}" dir log commit
  if [[ -z "${SB_RUNTIME_STATE_DIR:-}" && -f "$_sb_rba_dir/../../hooks/lib/runtime-paths.sh" ]]; then
    # shellcheck source=hooks/lib/runtime-paths.sh
    source "$_sb_rba_dir/../../hooks/lib/runtime-paths.sh"
  fi
  dir="${SB_RUNTIME_STATE_DIR:-${HOME}/.silver-bullet}"
  log="${dir}/release-bypass-log.jsonl"
  commit="$(git -C "$root" rev-parse HEAD 2>/dev/null || true)"
  printf 'AUDIT: release gate bypass %s=1 by %s at %s (logged to %s)\n' \
    "$switch" "${USER:-unknown}" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$log" >&2
  mkdir -p "$dir" 2>/dev/null || return 0
  [[ ! -L "$log" ]] || return 0
  jq -nc --arg switch "$switch" --arg user "${USER:-unknown}" --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg repo "$root" --arg commit "$commit" \
    '{switch: $switch, user: $user, at: $at, repo: $repo, commit: $commit}' >>"$log" 2>/dev/null || true
}
