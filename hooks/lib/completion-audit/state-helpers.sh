#!/usr/bin/env bash
# completion-audit: state file skill helpers
has_skill() {
  if declare -F sb_required_skill_is_recorded >/dev/null 2>&1; then
    sb_required_skill_is_recorded "$state_contents" "$1"
    return $?
  fi
  printf '%s\n' "$state_contents" | grep -Fqx -- "$1" 2>/dev/null
}

# Line number of a skill in the state file (for ordering checks); 0 if absent
skill_line() {
  if declare -F sb_required_skill_line >/dev/null 2>&1; then
    sb_required_skill_line "$state_contents" "$1"
    return 0
  fi
  local line
  line=$(printf '%s\n' "$state_contents" | grep -Fnx -- "$1" | head -1 | cut -d: -f1)
  printf '%s' "${line:-0}"
}
