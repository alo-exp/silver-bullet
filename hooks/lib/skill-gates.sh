# shellcheck shell=bash
# The Skill-matcher PreToolUse gates, run on demand for a skill that reaches the agent through
# the invoke-skill adapter (a Bash call the host's own Skill matcher never sees; R3-08).
#
#   sb_skill_gates_denial SKILL HOOKS_DIR   prints the first denial reason and returns 0 when a
#                                           gate denies (or fails to answer); returns 1 when every
#                                           present gate allows. Gates that are not installed are
#                                           skipped. Needs jq; without it nothing is denied here.

sb_skill_gates_denial() {
  local skill="${1:-}" hooks_dir="${2:-}" gate payload out reason
  command -v jq >/dev/null 2>&1 || return 1
  payload="$(jq -cn --arg s "$skill" '{hook_event_name:"PreToolUse", tool_name:"Skill", tool_input:{skill:$s}, cwd:env.PWD}')"
  for gate in review-fix-ladder-guard.sh rfl-policy-c-gate.sh forbidden-skill-check.sh dependency-skill-check.sh uat-gate.sh; do
    [[ -x "$hooks_dir/$gate" ]] || continue
    if ! out="$(printf '%s' "$payload" | "$hooks_dir/$gate" 2>/dev/null)"; then
      # A gate that cannot answer is not an allow.
      printf 'the %s gate failed' "$gate"
      return 0
    fi
    reason="$(printf '%s' "$out" | jq -r 'select(.hookSpecificOutput.permissionDecision == "deny") | (.hookSpecificOutput.permissionDecisionReason // "denied")' 2>/dev/null)" || reason=""
    if [[ -n "$reason" ]]; then
      printf '%s' "$reason"
      return 0
    fi
  done
  return 1
}
