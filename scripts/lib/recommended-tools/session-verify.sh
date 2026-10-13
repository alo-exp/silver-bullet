# shellcheck shell=bash
# SessionStart verification-only recommended-tools drift detection (no repair).
# Sourced by hooks/session-start.

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
rt_init_paths
# shellcheck source=graphify-worktree.sh
source "$(dirname "${BASH_SOURCE[0]}")/graphify-worktree.sh"

rt_session_verify_block() {
  local project_root="${1:-}"
  local host="${2:-cursor}"
  [[ -n "$project_root" && -f "${project_root}/.silver-bullet.json" ]] || return 0
  local repo_root reconciler out cfg
  repo_root=""
  if [[ -f "${project_root}/scripts/reconcile-recommended-tools.sh" ]]; then
    repo_root="$project_root"
  elif [[ -n "${RT_REPO_ROOT:-}" && -f "${RT_REPO_ROOT}/scripts/reconcile-recommended-tools.sh" ]]; then
    repo_root="${RT_REPO_ROOT}"
  elif [[ -n "${CLAUDE_PLUGIN_ROOT:-}" && -f "${CLAUDE_PLUGIN_ROOT}/scripts/reconcile-recommended-tools.sh" ]]; then
    repo_root="${CLAUDE_PLUGIN_ROOT}"
  else
    local walk="$project_root"
    while [[ "$walk" != "/" ]]; do
      if [[ -f "${walk}/scripts/reconcile-recommended-tools.sh" ]]; then
        repo_root="$walk"
        break
      fi
      walk="$(dirname "$walk")"
    done
  fi
  [[ -n "$repo_root" ]] || return 0
  reconciler="${repo_root}/scripts/reconcile-recommended-tools.sh"
  [[ -f "$reconciler" ]] || return 0
  cfg="${project_root}/.silver-bullet.json"
  local -a lines=()
  local needs_action=0

  out="$(RT_PROJECT_ROOT="$project_root" RT_HOST="$host" \
    bash "$reconciler" --project-root "$project_root" --host "$host" \
    --mode verify --scope all --format json 2>/dev/null || true)"
  if [[ -n "$out" ]] && command -v jq >/dev/null 2>&1; then
    local tool state activation
    while IFS=$'\t' read -r tool state activation; do
      [[ -n "$tool" ]] || continue
      case "$state" in
        ready|disabled|pending|unsupported) ;;
        suspended)
          lines+=("TOOLSTACK ${tool}: suspended (consent preserved) — retry via /sb:update or /sb:init")
          needs_action=1
          ;;
        failed|repairable|reload_required)
          lines+=("TOOLSTACK ${tool}: ${state} (activation=${activation}) — run /sb:doctor --fix or /sb:init")
          needs_action=1
          ;;
      esac
    done < <(printf '%s' "$out" | jq -r '.components[]? | select(.component != "cross_tool") | [.component,.canonical_state,.activation_status] | @tsv' 2>/dev/null)
    local cross_state cross_activation cross_hb_invalid=0
    cross_state="$(printf '%s' "$out" | jq -r '.components[]? | select(.component=="cross_tool") | .canonical_state' 2>/dev/null || true)"
    cross_activation="$(printf '%s' "$out" | jq -r '.components[]? | select(.component=="cross_tool") | .activation_status' 2>/dev/null || true)"
    if printf '%s' "$out" | jq -e '.components[]? | select(.component=="cross_tool") | .evidence[]? | select(. == "heartbeat_absent_or_invalid")' >/dev/null 2>&1; then
      cross_hb_invalid=1
    fi
    if [[ -n "$cross_state" ]] && { [[ "$cross_state" != "ready" ]] || [[ "$cross_activation" != "full" ]] || [[ "$cross_hb_invalid" -eq 1 ]]; }; then
      lines+=("TOOLSTACK routes: ${cross_state} (activation=${cross_activation:-none}) — run bash scripts/install-cursor.sh or /sb:doctor --fix=host")
      needs_action=1
    fi
    if printf '%s' "$out" | jq -e '.restart_required == true' >/dev/null 2>&1; then
      lines+=("TOOLSTACK reload: MCP config changed — verify liveness in this session (Tools & MCP off/on); receipt verification is session-only")
      needs_action=1
    fi
  fi

  [[ "$needs_action" -eq 0 ]] && return 0
  {
    echo "**Recommended tools — verification only (SessionStart does not repair)**"
    printf '%s\n' "${lines[@]}"
    echo "Fix paths: /sb:init · /sb:update · bash scripts/install-cursor.sh · /sb:doctor --dry-run · /sb:doctor --fix"
    echo "Liveness: CONFIGURED ≠ LIVE until this session successfully invokes expected MCP tools."
  }
}
