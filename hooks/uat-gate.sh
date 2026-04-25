#!/usr/bin/env bash
set -euo pipefail
trap 'printf "{\"hookSpecificOutput\":{\"message\":\"⚠️ uat-gate: hook error — check jq/input format\"}}" ; exit 0' ERR

# PreToolUse hook (matcher: Skill)
# UAT GATE — blocks gsd-complete-milestone when UAT.md is missing, has FAIL results,
# or was run against a stale spec version.

# Security: restrict file creation permissions (user-only)
umask 0077

# jq is required for JSON parsing
if ! command -v jq >/dev/null 2>&1; then
  printf '{"hookSpecificOutput":{"message":"⚠️ Silver Bullet hooks require jq. Install: brew install jq (macOS) / apt install jq (Linux)"}}'
  exit 0
fi

# Read JSON from stdin
input=$(cat)

# Emit a block (PreToolUse deny)
emit_block() {
  local reason="$1"
  local json_reason
  json_reason=$(printf '%s' "$reason" | jq -Rs '.')
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$json_reason"
}

# Extract skill name from Skill tool input
skill=$(printf '%s' "$input" | jq -r '.tool_input.skill // .tool_input.skillName // ""')

# Only gate on gsd-complete-milestone
if ! printf '%s' "$skill" | grep -qE 'gsd-complete-milestone|gsd:complete-milestone'; then
  exit 0
fi

UAT=".planning/UAT.md"
SPEC=".planning/SPEC.md"

# Check 1: UAT.md must exist (UATG-01)
if [[ ! -f "$UAT" ]]; then
  emit_block "UAT GATE: .planning/UAT.md not found. Generate UAT checklist from SPEC.md acceptance criteria before completing milestone. Run /silver:feature Step 17."
  exit 0
fi

# Check 2: No FAIL results allowed (UATG-03)
# Two-pipe approach: find lines with | FAIL | then exclude header rows (which also contain
# column names like #, Total, PASS, NOT-RUN, Status, Result).
if grep -E '\| FAIL \|' "$UAT" | grep -qvE '\|\s*(#|Total|PASS|NOT.?RUN|Status|Result)\s*\|'; then
  fail_count=$(grep -E '\| FAIL \|' "$UAT" | grep -cvE '\|\s*(#|Total|PASS|NOT.?RUN|Status|Result)\s*\|' || true)
  emit_block "UAT GATE: ${fail_count} criterion/criteria marked FAIL in .planning/UAT.md. Resolve all failures before completing milestone."
  exit 0
fi

# Check 3: NOT-RUN advisory (non-blocking)
if grep -qE '\| NOT-RUN \|' "$UAT"; then
  not_run_count=$(grep -cE '\| NOT-RUN \|' "$UAT" || true)
  printf '{"hookSpecificOutput":{"message":"⚠️  UAT ADVISORY: %s criterion/criteria marked NOT-RUN in .planning/UAT.md. Ensure all criteria are executed before milestone completion."}}' "$not_run_count"
fi

# Check 4: Spec version must match (UATG-04)
if [[ -f "$SPEC" ]]; then
  uat_version=$(grep -m1 '^spec-version:' "$UAT" | awk '{print $2}' | tr -d '"' | tr -d "'" || true)
  spec_version=$(grep -m1 '^spec-version:' "$SPEC" | awk '{print $2}' | tr -d '"' | tr -d "'" || true)
  # Validate against allowlist before interpolating into block message (SEC: content injection guard)
  # Only digits-and-dots (e.g. 1.0, 2.3.1) are accepted; invalid values skip the check safely
  if ! printf '%s' "${uat_version:-}" | grep -qE '^[0-9]+(\.[0-9]+)*$'; then
    uat_version=""
  fi
  if ! printf '%s' "${spec_version:-}" | grep -qE '^[0-9]+(\.[0-9]+)*$'; then
    spec_version=""
  fi
  if [[ -n "$uat_version" && -n "$spec_version" && "$uat_version" != "$spec_version" ]]; then
    emit_block "UAT GATE: UAT was run against spec v${uat_version} but current SPEC.md is v${spec_version}. Re-run UAT against the current spec."
    exit 0
  fi
fi

# All checks passed
printf '{"hookSpecificOutput":{"message":"✓ UAT gate passed. Milestone completion allowed."}}'
exit 0
