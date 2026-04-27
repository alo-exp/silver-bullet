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
