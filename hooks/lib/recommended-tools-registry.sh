# shellcheck shell=bash
# Canonical SB recommended-tool IDs — single source for session-start, prompt-reminder, E2E.

# All user-facing recommended tools (order: retrieval → capture → browser → compression → stack-routed).
SB_RECOMMENDED_TOOL_IDS=(
  graphify
  agentmemory
  alumnium
  rtk
  context_mode
  leanctx
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

# Compression-stack tools (RTK, Context Mode, LeanCTX) — LeanCTX is stack-routed, not shell-only.
sb_recommended_tool_is_compression_stack() {
  case "${1:-}" in
    rtk|context_mode|leanctx) return 0 ;;
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
    leanctx) printf 'LeanCTX' ;;
    *) printf '%s' "${1:-tool}" ;;
  esac
}
