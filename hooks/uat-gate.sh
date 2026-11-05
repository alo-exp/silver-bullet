#!/usr/bin/env bash
set -euo pipefail
trap 'sb_emit_hook_message PreToolUse "⚠️ uat-gate: hook error — check jq/input format"; exit 0' ERR

# PreToolUse hook (matcher: Skill)
# UAT GATE — blocks sb:release / milestone completion when UAT.md is missing,
# has FAIL results, or was run against a stale spec version.

# Security: restrict file creation permissions (user-only)
umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
for _lib in jq-gate.sh sb-project-gate.sh skill-discovery.sh planning-floor.sh; do
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
  printf '{"systemMessage":"⚠️ Silver Bullet hooks require jq. Install: brew install jq (macOS) / apt install jq (Linux)"}'
  exit 0
fi

if ! declare -f sb_pf_skill_calls >/dev/null 2>&1; then
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Silver Bullet hook libraries are missing (hooks/lib/planning-floor.sh). Reinstall the plugin."}}'
  exit 0
fi

# Read JSON from stdin
input=$(cat)

if declare -f sb_project_gate_or_exit >/dev/null 2>&1; then
  sb_project_gate_or_exit
fi

hook_event=$(printf '%s' "$input" | jq -r '.hook_event_name // "PreToolUse"')

# Emit a block (PreToolUse deny)
emit_block() {
  sb_emit_hook_decision "$hook_event" deny "$1"
}

# The invoked skill(s): the Skill tool, or the Codex invoke-skill adapter. A skill named in a
# payload under the tool_input.skillName spelling is read by sb_pf_invoked_skills too.
rc=0
sb_pf_skill_calls "$input" || rc=$?
[[ "$rc" -eq 1 ]] && exit 0
if [[ "$rc" -eq 2 ]]; then
  emit_block "$(sb_pf_unanalysable_message)"
  exit 0
fi
skill="$SB_PF_SKILLS"

project_root="$(sb_find_project_root_walk_only 2>/dev/null || true)"
[[ -n "$project_root" ]] || project_root="$PWD"
UAT="$project_root/.planning/UAT.md"
SPEC="$project_root/.planning/SPEC.md"

# Gate milestone release only — phase-level ship (sb:ship) does not require UAT.md.
# UAT is generated at milestone completion (sb:feature Step 17) before sb:release.
if ! grep -qx 'silver-release' <<<"$skill"; then
  exit 0
fi

# Check 1: UAT.md must exist (UATG-01)
if [[ ! -f "$UAT" ]]; then
  emit_block "UAT GATE: .planning/UAT.md not found. Generate UAT checklist from SPEC.md acceptance criteria before completing milestone. Run /sb:release."
  exit 0
fi

# Checks 2 and 3: result cells (R2-25, R10-03). Case-insensitive and column-aware: when the table has
# a header naming a Result/Status column, only that column of each row is read, so an "expected: pass"
# column next to a fail result is still a failure; without a header any cell that is exactly
# fail/failed or not-run (any spacing: |FAIL|, | Fail |, `not run`) counts unless the row names several
# result words (a legend). Summary rows (#, Total, Legend) never count.
read -r fail_count not_run_count < <(awk -F'|' '
  function trim(x) { x = tolower(x); gsub(/^[ \t\r]+|[ \t\r]+$/, "", x); return x }
  !/^[[:space:]]*\|/ { col = 0 }
  /^[[:space:]]*\|/ {
    first = trim($2)
    if (first == "#" || first == "total" || first == "legend" || first == "summary") {
      for (i = 2; i <= NF; i++) { c = trim($i); if (c == "result" || c == "status") col = i }
      next
    }
    for (i = 2; i <= NF; i++) { c = trim($i); if ((c == "result" || c == "status") && col == 0) { col = i; hdr = 1 } }
    if (hdr) { hdr = 0; next }
    fail = 0; nr = 0; pass = 0
    if (col > 0) {
      c = trim($col)
      if (c == "fail" || c == "failed") fail = 1
      else if (c ~ /^not[-_ ]?run$/) nr = 1
    } else {
      for (i = 2; i <= NF; i++) {
        c = trim($i)
        if (c == "fail" || c == "failed") fail = 1
        if (c ~ /^not[-_ ]?run$/) nr = 1
        if (c == "pass" || c == "passed") pass = 1
      }
      if (fail + nr + pass > 1) next
    }
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
sb_emit_hook_message "$hook_event" "✓ UAT gate passed. Milestone completion allowed."
exit 0
