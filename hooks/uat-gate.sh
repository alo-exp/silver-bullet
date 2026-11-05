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
if ! grep -qE 'silver-release' <<<"$skill"; then
  exit 0
fi

# Check 1: UAT.md must exist (UATG-01)
if [[ ! -f "$UAT" ]]; then
  emit_block "UAT GATE: .planning/UAT.md not found. Generate UAT checklist from SPEC.md acceptance criteria before completing milestone. Run /sb:release."
  exit 0
fi

# Check 2: No FAIL results allowed (UATG-03)
# Two-pipe approach: find lines with | FAIL | then exclude header rows (which also contain
# column names like #, Total, PASS, NOT-RUN, Status, Result).
if grep -qvE '\|\s*(#|Total|PASS|NOT.?RUN|Status|Result)\s*\|' < <(grep -E '\| FAIL \|' "$UAT"); then
  fail_count=$(grep -E '\| FAIL \|' "$UAT" | grep -cvE '\|\s*(#|Total|PASS|NOT.?RUN|Status|Result)\s*\|' || true)
  emit_block "UAT GATE: ${fail_count} criterion/criteria marked FAIL in .planning/UAT.md. Resolve all failures before completing milestone."
  exit 0
fi

# Check 3: NOT-RUN blocks milestone release (UATG-02)
if grep -qvE '\|\s*(#|Total|PASS|FAIL|Status|Result)\s*\|' < <(grep -E '\| NOT-RUN \|' "$UAT"); then
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
