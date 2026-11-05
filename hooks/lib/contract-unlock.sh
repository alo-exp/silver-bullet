# shellcheck shell=bash
# Silver Bullet — the window in which a skill that legitimately rewrites the enforcement contract
# (.silver-bullet.json, silver-bullet.md) may do so through the agent.
#
# The recorder (record-skill.sh) writes ${SB_RUNTIME_STATE_DIR}/contract-unlock when the host
# invokes one of these skills; the gates read it. Naming a skill in a command, or reading its
# SKILL.md, never unlocks anything. The unlock lasts SB_CONTRACT_UNLOCK_WINDOW seconds (default
# two hours) from the most recent invocation, and silver-add / silver-devops unlock the JSON
# configuration only, never silver-bullet.md. tests/hooks/test-planning-floor-lib.sh checks the skills
# directory for contract writers outside this list.
#
#   sb_contract_unlock_write SKILL     record SKILL's invocation when it is a contract writer
#   sb_contract_unlocked [json|md]     a writer skill ran recently enough (json: .silver-bullet*.json,
#                                      md: silver-bullet.md)

SB_PF_CONTRACT_WRITER_SKILLS="silver-init silver-update silver-add silver-devops silver-migrate"
SB_CONTRACT_JSON_ONLY_SKILLS="silver-add silver-devops"
SB_CONTRACT_UNLOCK_WINDOW="${SB_CONTRACT_UNLOCK_WINDOW:-7200}"

sb_contract_unlock_file() { printf '%s/contract-unlock' "${SB_RUNTIME_STATE_DIR:-$HOME/.claude/.silver-bullet}"; }

sb_contract_unlock_write() {
  local skill="${1:-}" file tmp
  case " $SB_PF_CONTRACT_WRITER_SKILLS " in *" $skill "*) ;; *) return 0 ;; esac
  file="$(sb_contract_unlock_file)"
  [[ ! -L "$file" ]] || return 0
  tmp="${file}.$$"
  if printf '%s %s\n' "$skill" "$(date +%s)" 2>/dev/null >"$tmp"; then mv -f -- "$tmp" "$file"; fi
  rm -f -- "$tmp"
  return 0
}

sb_contract_unlocked() {
  local kind="${1:-md}" file skill when now
  file="$(sb_contract_unlock_file)"
  [[ -f "$file" && ! -L "$file" ]] || return 1
  read -r skill when <"$file" 2>/dev/null || return 1
  [[ "$when" =~ ^[0-9]+$ ]] || return 1
  case " $SB_PF_CONTRACT_WRITER_SKILLS " in *" $skill "*) ;; *) return 1 ;; esac
  now="$(date +%s)"
  [[ "$now" -ge "$when" && $((now - when)) -le "$SB_CONTRACT_UNLOCK_WINDOW" ]] || return 1
  if [[ "$kind" != json ]]; then
    case " $SB_CONTRACT_JSON_ONLY_SKILLS " in *" $skill "*) return 1 ;; esac
  fi
  return 0
}
