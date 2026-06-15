#!/usr/bin/env bash
set -euo pipefail
trap 'printf "{\"hookSpecificOutput\":{\"message\":\"⚠️ uat-gate: hook error — check jq/input format\"}}" ; exit 0' ERR

# PreToolUse hook (matcher: Skill)
# UAT GATE — blocks silver:release / milestone completion when UAT.md is missing,
# has FAIL results, or was run against a stale spec version. Legacy GSD milestone
# completion aliases remain guarded for migration compatibility.

# Security: restrict file creation permissions (user-only)
umask 0077

# jq is required for JSON parsing
if ! command -v jq >/dev/null 2>&1; then
  printf '{"hookSpecificOutput":{"message":"⚠️ Silver Bullet hooks require jq. Install: brew install jq (macOS) / apt install jq (Linux)"}}'
  exit 0
fi

# Read JSON from stdin
input=$(cat)

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""

# Emit a block (PreToolUse deny)
emit_block() {
  local reason="$1"
  local json_reason
  json_reason=$(printf '%s' "$reason" | jq -Rs '.')
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$json_reason"
}

# Extract skill name from supported skill invocation input
skill=$(printf '%s' "$input" | jq -r '.tool_input.skill // .tool_input.skillName // ""')

if [[ -f "$_lib_dir/legacy-gsd-alias.sh" ]]; then
  # shellcheck source=lib/legacy-gsd-alias.sh
  source "$_lib_dir/legacy-gsd-alias.sh"
  skill="$(sb_legacy_gsd_alias_normalize "$skill")"
fi

UAT=".planning/UAT.md"
SPEC=".planning/SPEC.md"

# Gate milestone release only — phase-level ship (silver:ship) does not require UAT.md.
# UAT is generated at milestone completion (silver:feature Step 17) before silver:release.
if ! printf '%s' "$skill" | grep -qE 'silver-release'; then
  exit 0
fi

# Check 1: UAT.md must exist (UATG-01)
if [[ ! -f "$UAT" ]]; then
  emit_block "UAT GATE: .planning/UAT.md not found. Generate UAT checklist from SPEC.md acceptance criteria before completing milestone. Run /silver:release."
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

# Check 3: NOT-RUN blocks milestone release (UATG-02)
if grep -E '\| NOT-RUN \|' "$UAT" | grep -qvE '\|\s*(#|Total|PASS|FAIL|Status|Result)\s*\|'; then
  not_run_count=$(grep -E '\| NOT-RUN \|' "$UAT" | grep -cvE '\|\s*(#|Total|PASS|FAIL|Status|Result)\s*\|' || true)
  emit_block "UAT GATE: ${not_run_count} criterion/criteria marked NOT-RUN in .planning/UAT.md. Execute all criteria before completing milestone. Override only with explicit SB OVERRIDE: documented waiver in user message (audited)."
  exit 0
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
