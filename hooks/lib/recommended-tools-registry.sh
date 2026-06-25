# shellcheck shell=bash
# Canonical SB recommended-tool IDs — single source for session-start, prompt-reminder, E2E.

# All user-facing recommended tools (order: retrieval → capture → browser → compression).
SB_RECOMMENDED_TOOL_IDS=(
  graphify
  agentmemory
  alumnium
  rtk
  context_mode
)

sb_recommended_tool_ids() {
  local id
  for id in "${SB_RECOMMENDED_TOOL_IDS[@]}"; do
    printf '%s\n' "$id"
  done
}

sb_recommended_tool_is_token_compression() {
  case "${1:-}" in
    rtk|context_mode) return 0 ;;
    *) return 1 ;;
  esac
}

sb_recommended_tool_display_name() {
  case "${1:-}" in
    graphify) printf 'Graphify' ;;
    agentmemory) printf 'agentmemory' ;;
    alumnium) printf 'Alumnium' ;;
    rtk) printf 'RTK' ;;
    context_mode) printf 'Context Mode' ;;
    *) printf '%s' "${1:-tool}" ;;
  esac
}
