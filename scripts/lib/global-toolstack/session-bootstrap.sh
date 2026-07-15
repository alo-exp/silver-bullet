#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR
umask 0077
_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"
# shellcheck source=lib/common.sh
source "$_LIB/common.sh"
command -v jq >/dev/null 2>&1 || exit 0
ts_sb_defer_to_bridge && exit 0
ts_config >/dev/null 2>&1 || exit 0
ts_enforcement_active || exit 0
ts_tool_required graphify || exit 0
ts_graphify_bootstrap_enabled || exit 0
ts_graphify_cli_available || exit 0
project_root="$(ts_git_root 2>/dev/null || true)"
[[ -n "$project_root" ]] || exit 0
ts_graphify_index_exists "$project_root" && exit 0
state_dir="$(ts_project_state_dir)"
mkdir -p "$state_dir" 2>/dev/null || true
log="${state_dir}/graphify-bootstrap.log"
lock="${state_dir}/graphify-bootstrap.lock"
timeout_s="$(ts_jq '.worktree.bootstrap_timeout_seconds // 120')" || timeout_s="120"
[[ "$timeout_s" =~ ^[0-9]+$ ]] || timeout_s=120
if [[ -f "$lock" ]]; then
  lock_age=$(( $(date +%s) - $(stat -f %m "$lock" 2>/dev/null || stat -c %Y "$lock" 2>/dev/null || echo 0) ))
  [[ "$lock_age" -lt "$timeout_s" ]] && exit 0
fi
touch "$lock" 2>/dev/null || true
args_json="$(ts_jq '.worktree.graphify_update_args // ["update",".","--no-cluster"]')" || args_json='["update",".","--no-cluster"]'
mapfile -t gf_args < <(printf '%s' "$args_json" | jq -r '.[]' 2>/dev/null)
(
  cd "$project_root" || exit 0
  {
    echo "=== graphify bootstrap $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
    if command -v timeout >/dev/null 2>&1; then
      timeout "${timeout_s}s" graphify "${gf_args[@]}" 2>&1 || graphify "${gf_args[@]}" 2>&1 || true
    else
      graphify "${gf_args[@]}" 2>&1 || true
    fi
  } >>"$log" 2>&1
  rm -f "$lock" 2>/dev/null || true
) &
disown 2>/dev/null || true
exit 0
