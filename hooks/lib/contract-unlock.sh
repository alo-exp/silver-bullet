# shellcheck shell=bash
# Silver Bullet — the skills that legitimately rewrite the enforcement contract, and what an unlock covers.
#
# The unlock is an ENTRY of the keyed integrity record (hooks/lib/integrity.sh): record-skill.sh
# writes it when the host invokes one of these skills, it lasts SB_CONTRACT_UNLOCK_WINDOW seconds
# (default two hours), and the gates read it from the verified record (SB_IV_UNLOCK_SKILL). A plain
# file in the state directory, or a skill merely named in a command, unlocks nothing.
#
# silver-add and silver-devops cover the JSON configuration only; the others also cover
# silver-bullet.md and the instruction files. tests/hooks/test-planning-floor-lib.sh checks the
# skills directory for contract writers outside this list.
#
#   sb_contract_is_writer SKILL        SKILL is one of the contract-writing skills
#   sb_contract_skill_tags SKILL       the integrity tags SKILL may change
#   sb_contract_unlocked [json|md]     the verified record says a writer skill is running (json: the
#                                      JSON configuration, md: silver-bullet.md)
#   sb_contract_unlock_tags            the tags the unlock in force covers

SB_PF_CONTRACT_WRITER_SKILLS="silver-init silver-update silver-add silver-devops silver-migrate"
SB_CONTRACT_JSON_ONLY_SKILLS="silver-add silver-devops"
SB_CONTRACT_UNLOCK_WINDOW="${SB_CONTRACT_UNLOCK_WINDOW:-7200}"

sb_contract_is_writer() {
  case " $SB_PF_CONTRACT_WRITER_SKILLS " in *" ${1:-} "*) return 0 ;; esac
  return 1
}

sb_contract_skill_tags() { # SKILL
  case " $SB_CONTRACT_JSON_ONLY_SKILLS " in
    *" ${1:-} "*) printf 'config prompt' ;;
    *) printf 'config prompt md instr:CLAUDE.md instr:AGENTS.md' ;;
  esac
}

sb_contract_unlocked() {
  local kind="${1:-md}" skill="${SB_IV_UNLOCK_SKILL:-}"
  [[ -n "$skill" ]] || return 1
  if [[ "$kind" != json ]]; then
    case " $SB_CONTRACT_JSON_ONLY_SKILLS " in *" $skill "*) return 1 ;; esac
  fi
  return 0
}

sb_contract_unlock_tags() {
  [[ -z "${SB_IV_UNLOCK_SKILL:-}" ]] || sb_contract_skill_tags "$SB_IV_UNLOCK_SKILL"
  return 0
}
