# shellcheck shell=bash
# Canonical SB recommended-tool IDs — single source for session-start, prompt-reminder, E2E.

# All user-facing recommended tools (order: retrieval → capture → browser → compression → stack-routed).
SB_RECOMMENDED_TOOL_IDS=(
  graphify
  agentmemory
  alumnium
  search_cli
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

# Stack-routed compression tools (includes LeanCTX — not shell-only token_compression).
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
    search_cli) printf 'search-cli' ;;
    *) printf '%s' "${1:-tool}" ;;
  esac
}


# Authoritative F6 install pin. Never merge project-local install_commands.
sb_recommended_tool_install_pin() {
  local tool_id="${1:-}"
  case "$tool_id" in
    search_cli)
      local argv="brew tap paperfoot/tap && brew install paperfoot/tap/search-cli"
      local digest
      if command -v shasum >/dev/null 2>&1; then
        digest="$(printf '%s' "$argv" | shasum -a 256 | awk '{print $1}')"
      else
        digest="$(printf '%s' "$argv" | sha256sum | awk '{print $1}')"
      fi
      jq -n \
        --arg v "0.9.0" \
        --arg tap "paperfoot/tap" \
        --arg formula "search-cli" \
        --arg argv "$argv" \
        --arg digest "$digest" \
        --arg docs "https://github.com/paperfoot/search-cli/blob/v0.9.0/README.md@v0.9.0" \
        --arg formula_pin "https://github.com/paperfoot/homebrew-tap/blob/main/Formula/search-cli.rb@0.9.0" \
        '{version:$v,brew_tap:$tap,brew_formula:$formula,argv:$argv,argv_digest:$digest,docs_pin:$docs,formula_pin:$formula_pin}'
      ;;
    *)
      jq -n '{}'
      ;;
  esac
}
