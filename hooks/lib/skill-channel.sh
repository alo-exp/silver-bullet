# shellcheck shell=bash
# Skill-invocation channels for the Skill-gating hooks (forbidden-skill-check, uat-gate).
#
# Claude invokes a skill through the Skill tool (tool_input.skill). Codex has no Skill tool: its
# channel is the Bash command `silver-bullet invoke-skill <name>` (scripts/silver-bullet). Both
# channels must meet the same gates (R2-17), so this reads either.
#
#   sb_skill_channel_load PAYLOAD
#     sets SB_SKILL_CHANNEL_NAMES  newline-separated skill names the payload invokes (may be empty)
#          SB_SKILL_CHANNEL_STATUS ok | helper_unavailable
#
# The shell side uses the shell-analysis classifier (hooks/lib/shell-analysis.sh): the names come
# from the literal argv of `silver-bullet invoke-skill`, directly or run by an interpreter, never
# from a regex over the command text. SB_SKILL_CHANNEL_STATUS=helper_unavailable means python3
# could not run the classifier; the caller denies with sb_shell_analysis_helper_message.

_sb_skill_channel_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! declare -f sb_tool_input_load >/dev/null 2>&1 && [[ -f "$_sb_skill_channel_dir/shell-analysis.sh" ]]; then
  # shellcheck source=shell-analysis.sh
  source "$_sb_skill_channel_dir/shell-analysis.sh"
fi

sb_skill_channel_load() {
  local payload="${1:-}"
  SB_SKILL_CHANNEL_NAMES="$(printf '%s' "$payload" | jq -r '.tool_input.skill // .tool_input.skillName // .tool_input.name // empty' 2>/dev/null || true)"
  SB_SKILL_CHANNEL_STATUS="ok"
  [[ -z "$SB_SKILL_CHANNEL_NAMES" ]] || return 0
  sb_tool_input_load "$payload"
  if [[ "${SB_TI_STATUS:-}" == "helper_unavailable" ]]; then
    SB_SKILL_CHANNEL_STATUS="helper_unavailable"
    return 0
  fi
  [[ "${SB_TI_STATUS:-}" == "ok" && "${SB_TI_TOOL_KIND:-}" == "shell" ]] || return 0
  SB_SKILL_CHANNEL_NAMES="$(printf '%s' "${SB_SA_JSON:-{\}}" | jq -r '
    def base: split("/") | last;
    [.commands[]?.argv
     | if (.[0] | base) == "silver-bullet" then .[1:]
       elif (.[0] | base | test("^(node|nodejs|python[0-9.]*|bash|sh|zsh|ruby|perl|deno|bun)$"))
            and length > 1 and (.[1] | base) == "silver-bullet" then .[2:]
       else null end
     | select(. != null and .[0] == "invoke-skill" and (.[1] | type) == "string")
     | .[1]] | .[]' 2>/dev/null || true)"
}
