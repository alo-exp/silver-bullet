#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# SessionStart hook (matcher: startup|clear|compact)
# Captures spec-version and jira-id from .planning/SPEC.md into spec-session file.
# Enables zero-annotation PR traceability — pr-traceability.sh reads this file at PR creation.

# Security: restrict file creation permissions (user-only)
umask 0077

# jq is required for JSON parsing
if ! command -v jq >/dev/null 2>&1; then
  printf '{"hookSpecificOutput":{"message":"⚠️ Silver Bullet hooks require jq. Install: brew install jq (macOS) / apt install jq (Linux)"}}'
  exit 0
fi

# Read JSON from stdin
input=$(cat)

SPEC=".planning/SPEC.md"

# If no SPEC.md, nothing to record — exit silently
if [[ ! -f "$SPEC" ]]; then
  exit 0
fi

# Extract spec-version and jira-id from SPEC.md frontmatter
spec_version=$(grep -m1 '^spec-version:' "$SPEC" | awk '{print $2}' | tr -d '"' | tr -d "'" || true)
jira_id=$(grep -m1 '^jira-id:' "$SPEC" | awk '{print $2}' | tr -d '"' | tr -d "'" || true)

# Write spec-session file (empty values are fine — do not block)
SB_STATE_DIR="${HOME}/.claude/.silver-bullet"
mkdir -p "$SB_STATE_DIR"
spec_session_file="${SB_STATE_DIR}/spec-session"

printf 'spec-version=%s\njira-id=%s\n' "${spec_version:-}" "${jira_id:-}" > "$spec_session_file"

# Emit advisory
version_display="${spec_version:-unknown}"
jira_display="${jira_id:-n/a}"
printf '{"hookSpecificOutput":{"message":"Spec session: SPEC.md v%s, JIRA: %s"}}' "$version_display" "$jira_display"

exit 0
