#!/usr/bin/env bash
set -euo pipefail
trap 'printf "{\"hookSpecificOutput\":{\"message\":\"⚠️ uat-gate: hook error — check jq/input format\"}}" ; exit 0' ERR

# PreToolUse hook (matcher: Skill|Bash|exec_command)
# UAT GATE — blocks sb:release / milestone completion when UAT.md is missing,
# has FAIL results, or was run against a stale spec version.

# Security: restrict file creation permissions (user-only)
umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
for _lib in jq-gate.sh sb-project-gate.sh skill-discovery.sh; do
  if [[ -f "$_lib_dir/$_lib" ]]; then
    # shellcheck source=/dev/null
    source "$_lib_dir/$_lib"
  fi
done

emit_block_jq_missing() {
  local reason="$1"
  local json_reason
  json_reason=$(printf '%s' "$reason" | jq -Rs '.' 2>/dev/null || printf '"jq required for Silver Bullet enforcement"')
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$json_reason"
}

if declare -f sb_jq_enforcement_block_sb_initiated >/dev/null 2>&1; then
  sb_jq_enforcement_block_sb_initiated "uat-gate" "emit_block_jq_missing"
elif ! command -v jq >/dev/null 2>&1; then
  printf '{"hookSpecificOutput":{"message":"⚠️ Silver Bullet hooks require jq. Install: brew install jq (macOS) / apt install jq (Linux)"}}'
  exit 0
fi

# Read JSON from stdin
input=$(cat)

if declare -f sb_project_gate_or_exit >/dev/null 2>&1; then
  sb_project_gate_or_exit
fi

# Emit a block (PreToolUse deny)
emit_block() {
  local reason="$1"
  local json_reason
  json_reason=$(printf '%s' "$reason" | jq -Rs '.')
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$json_reason"
}

# Which skills does this call invoke? The Skill tool, or the Codex invoke-skill adapter (R2-17).
# shellcheck source=lib/skill-channel.sh
source "$_lib_dir/skill-channel.sh"
sb_skill_channel_load "$input"
if [[ "$SB_SKILL_CHANNEL_STATUS" == "helper_unavailable" ]]; then
  emit_block "$(sb_shell_analysis_helper_message)"
  exit 0
fi

# Gate milestone release only — phase-level ship (sb:ship) does not require UAT.md. The canonical
# skill name must be exactly silver-release (a skill that merely contains the text is not it).
# UAT is generated at milestone completion (sb:feature Step 17) before sb:release.
is_release=false
while IFS= read -r raw_skill; do
  [[ -n "$raw_skill" ]] || continue
  canonical="$raw_skill"
  if declare -F sb_skill_canonical_name >/dev/null 2>&1; then
    canonical="$(sb_skill_canonical_name "$raw_skill" || true)"
  fi
  canonical="$(printf '%s' "$canonical" | tr '[:upper:]' '[:lower:]')"
  [[ "$canonical" == "silver-release" ]] && is_release=true
done <<< "$SB_SKILL_CHANNEL_NAMES"
[[ "$is_release" == true ]] || exit 0

# Paths come from the project root, not the hook's working directory (R2-25).
uat_root="$PWD"
if declare -f sb_find_project_root_walk_only >/dev/null 2>&1; then
  uat_root="$(sb_find_project_root_walk_only 2>/dev/null || printf '%s' "$PWD")"
fi
UAT="$uat_root/.planning/UAT.md"
SPEC="$uat_root/.planning/SPEC.md"

# Check 1: UAT.md must exist (UATG-01)
if [[ ! -f "$UAT" ]]; then
  emit_block "UAT GATE: .planning/UAT.md not found. Generate UAT checklist from SPEC.md acceptance criteria before completing milestone. Run /sb:release."
  exit 0
fi

# Checks 2 and 3: result cells (R2-25, R10-03). Column-aware and case-insensitive: any table cell
# that is exactly fail/failed or not-run (any spacing, `|FAIL|`, `| Fail |`, `not run`) counts.
# Header and legend rows that name several result words (#, Total, Status, Result, PASS) do not.
read -r fail_count not_run_count < <(awk -F'|' '
  /^[[:space:]]*\|/ {
    fail = 0; nr = 0; legend = 0
    for (i = 2; i <= NF; i++) {
      c = tolower($i); gsub(/^[ \t\r]+|[ \t\r]+$/, "", c)
      if (c == "fail" || c == "failed") fail = 1
      if (c ~ /^not[-_ ]?run$/) nr = 1
      if (c == "pass" || c == "passed" || c == "#" || c == "total" || c == "status" || c == "result") legend = 1
    }
    if (legend || (fail && nr)) next
    if (fail) f++
    else if (nr) n++
  }
  END { print f + 0, n + 0 }
' "$UAT")

# Check 2: No FAIL results allowed (UATG-03)
if [[ "$fail_count" -gt 0 ]]; then
  emit_block "UAT GATE: ${fail_count} criterion/criteria marked FAIL in .planning/UAT.md. Resolve all failures before completing milestone."
  exit 0
fi

# Check 3: NOT-RUN blocks milestone release (UATG-02)
if [[ "$not_run_count" -gt 0 ]]; then
  emit_block "UAT GATE: ${not_run_count} criterion/criteria marked NOT-RUN in .planning/UAT.md. Execute all criteria before completing milestone."
  exit 0
fi

# Check 4: Spec version must match (UATG-04)
if [[ -f "$SPEC" ]]; then
  uat_version=$(grep -m1 '^spec-version:' "$UAT" | awk '{print $2}' | tr -d '"' | tr -d "'" || true)
  spec_version=$(grep -m1 '^spec-version:' "$SPEC" | awk '{print $2}' | tr -d '"' | tr -d "'" || true)
  # Validate against allowlist before interpolating into block message (SEC: content injection guard)
  # Only digits-and-dots (e.g. 1.0, 2.3.1) are accepted; invalid values skip the check safely
  if ! grep -qE '^[0-9]+(\.[0-9]+)*$' <<<"${uat_version:-}"; then
    uat_version=""
  fi
  if ! grep -qE '^[0-9]+(\.[0-9]+)*$' <<<"${spec_version:-}"; then
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
