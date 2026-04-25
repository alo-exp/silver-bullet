#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# SessionStart hook (matcher: startup|clear|compact)
# Captures spec-version and jira-id from .planning/SPEC.md into spec-session file.
# Enables zero-annotation PR traceability — pr-traceability.sh reads this file at PR creation.

# Security: restrict file creation permissions (user-only)
umask 0077

# Source symlink-write guard (SEC-02)
_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
if [[ -n "$_lib_dir" && -f "$_lib_dir/nofollow-guard.sh" ]]; then
  # shellcheck source=lib/nofollow-guard.sh
  source "$_lib_dir/nofollow-guard.sh"
else
  sb_guard_nofollow() { [[ -L "$1" ]] && { printf 'ERROR: refusing to write through symlink: %s\n' "$1" >&2; exit 1; }; return 0; }
  sb_safe_write()    { [[ -L "$1" ]] && rm -f -- "$1"; return 0; }
fi

# jq is required for JSON parsing
if ! command -v jq >/dev/null 2>&1; then
  printf '{"hookSpecificOutput":{"message":"⚠️ Silver Bullet hooks require jq. Install: brew install jq (macOS) / apt install jq (Linux)"}}'
  exit 0
fi

# Read JSON from stdin (required — SessionStart hooks must consume stdin)
_input=$(cat)

SPEC=".planning/SPEC.md"

# If no SPEC.md, nothing to record — exit silently
if [[ ! -f "$SPEC" ]]; then
  exit 0
fi

# Extract spec-version and jira-id from SPEC.md frontmatter
spec_version=$(grep -m1 '^spec-version:' "$SPEC" | awk '{print $2}' | tr -d '"' | tr -d "'" || true)
jira_id=$(grep -m1 '^jira-id:' "$SPEC" | awk '{print $2}' | tr -d '"' | tr -d "'" || true)

# Validate against allowlists before any interpolation (SEC: content injection guard)
# spec-version: digits and dots only (e.g. 1.0, 2.3.1)
if ! printf '%s' "${spec_version:-}" | grep -qE '^[0-9]+(\.[0-9]+)*$'; then
  spec_version=""
fi
# jira-id: PROJECT-NNN format (e.g. FOO-123)
if ! printf '%s' "${jira_id:-}" | grep -qE '^[A-Z][A-Z0-9_]*-[0-9]+$'; then
  jira_id=""
fi

# Write spec-session file (empty values are fine — do not block)
SB_STATE_DIR="${HOME}/.claude/.silver-bullet"
mkdir -p "$SB_STATE_DIR"
spec_session_file="${SB_STATE_DIR}/spec-session"

sb_guard_nofollow "$spec_session_file"
printf 'spec-version=%s\njira-id=%s\n' "${spec_version:-}" "${jira_id:-}" > "$spec_session_file"

# Emit advisory (jq-mediated encoding prevents JSON injection)
version_display="${spec_version:-unknown}"
jira_display="${jira_id:-n/a}"
_msg="Spec session: SPEC.md v${version_display}, JIRA: ${jira_display}"
printf '{"hookSpecificOutput":{"message":%s}}' "$(printf '%s' "$_msg" | jq -Rs '.')"

exit 0
