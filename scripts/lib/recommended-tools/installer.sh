# shellcheck shell=bash
# Installer integration — deploy reconciler snapshots and invoke canonical engine.
# Sourced by install-cursor.sh, install-global-toolstack.sh, install-body.sh.

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

rt_installer_toolstack_dir() {
  printf '%s/.cursor/hooks/toolstack' "${HOME}"
}

rt_installer_reconciler_lib_dir() {
  printf '%s/lib/recommended-tools' "$(rt_installer_toolstack_dir)"
}

rt_deploy_toolstack_scripts() {
  local repo_root="${1:-${RT_REPO_ROOT:-}}"
  local src_dir="${repo_root}/scripts/lib/global-toolstack"
  [[ -d "$src_dir" ]] || return 1
  local ts_dir ts_lib
  ts_dir="$(rt_installer_toolstack_dir)"
  ts_lib="${ts_dir}/lib"
  mkdir -p "$ts_dir" "$ts_lib" 2>/dev/null || true
  local f base
  for f in common.sh shell-compression.sh graphify-gate.sh agentmemory-gate.sh \
    rtk-gate.sh context-mode-gate.sh token-compression-tools-gate.sh \
    stack-compression-coordinator.sh session-bootstrap.sh \
    record-graphify-query.sh record-agentmemory-usage.sh; do
    [[ -f "${src_dir}/${f}" ]] || continue
    if [[ "$f" == "common.sh" ]]; then
      cp -f "${src_dir}/${f}" "${ts_lib}/${f}" 2>/dev/null || true
    else
      cp -f "${src_dir}/${f}" "${ts_dir}/${f}" 2>/dev/null || true
      chmod +x "${ts_dir}/${f}" 2>/dev/null || true
    fi
  done
  for f in five_tool_instances.py opencode.py opencode-rtk-plugin.ts install-pi.py pi-five-tool-stack.ts \
    patch-hooks.py patch-mcp.py fix-shell-compression-hook.py parity-verify.sh verify.sh; do
    [[ -f "${src_dir}/${f}" ]] || continue
    cp -f "${src_dir}/${f}" "${ts_dir}/${f}" 2>/dev/null || true
  done
  chmod +x "${ts_dir}/parity-verify.sh" "${ts_dir}/verify.sh" 2>/dev/null || true
  return 0
}

rt_deploy_reconciler_snapshots() {
  local repo_root="${1:-${RT_REPO_ROOT:-}}"
  [[ -n "$repo_root" && -d "$repo_root/scripts/lib/recommended-tools" ]] || return 1
  local ts_dir lib_dir
  ts_dir="$(rt_installer_toolstack_dir)"
  lib_dir="$(rt_installer_reconciler_lib_dir)"
  mkdir -p "$ts_dir" "$lib_dir" "${HOME}/.cursor/state/toolstack" 2>/dev/null || true
  printf '%s' "$repo_root" >"${HOME}/.cursor/state/toolstack/repo-root" 2>/dev/null || true
  rt_deploy_toolstack_scripts "$repo_root" || true
  cp -f "${repo_root}/scripts/reconcile-recommended-tools.sh" "${ts_dir}/reconcile-recommended-tools.sh" 2>/dev/null || true
  chmod +x "${ts_dir}/reconcile-recommended-tools.sh" 2>/dev/null || true
  for f in "${repo_root}/scripts/lib/recommended-tools/"*; do
    [[ -f "$f" ]] || continue
    cp -f "$f" "${lib_dir}/$(basename "$f")" 2>/dev/null || true
  done
  return 0
}

rt_installer_resolve_project_root() {
  local explicit="${1:-${SB_RECONCILE_PROJECT_ROOT:-}}"
  if [[ -n "$explicit" && -f "${explicit}/.silver-bullet.json" ]]; then
    cd "$explicit" && pwd -P
    return 0
  fi
  local start="${PWD}"
  if git -C "$start" rev-parse --show-toplevel >/dev/null 2>&1; then
    local top
    top="$(git -C "$start" rev-parse --show-toplevel)"
    if [[ -f "${top}/.silver-bullet.json" ]]; then
      printf '%s' "$top"
      return 0
    fi
  fi
  return 1
}

rt_installer_run_reconcile() {
  local repo_root="${1:-${RT_REPO_ROOT:-}}"
  local project_root="${2:-}"
  local scope="${3:-host}"
  local mode="${4:-apply}"
  local reconciler="${repo_root}/scripts/reconcile-recommended-tools.sh"
  [[ -x "$reconciler" || -f "$reconciler" ]] || return 1
  local -a args=(
    --host cursor
    --mode "$mode"
    --scope "$scope"
    --format text
  )
  if [[ "$mode" == "apply" ]]; then
    args+=(--entry-point installer)
  fi
  if [[ -n "$project_root" ]]; then
    args+=(--project-root "$project_root")
  elif [[ "$scope" == "project" || "$scope" == "all" ]]; then
    printf 'WARN: installer reconcile scope=%s requires project root — host infra only\n' "$scope" >&2
    scope=host
    args=(--host cursor --mode "$mode" --scope host --format text)
    [[ "$mode" == "apply" ]] && args+=(--entry-point installer)
  fi
  bash "$reconciler" "${args[@]}"
}

rt_emit_reload_notice() {
  local restart="${1:-false}"
  [[ "$restart" == "true" || "$restart" == "1" ]] || return 0
  cat <<'EOF'

RELOAD REQUIRED: Host MCP/hooks changed during install.
  1. Cursor → Tools & MCP → toggle affected servers off/on (graphify, agentmemory, leanctx, context-mode)
  2. Or Developer: Reload Window
  3. Start a new chat to verify tool liveness

Project-scoped work may remain pending until /silver:init or /silver:doctor --fix runs in the project.
EOF
}

rt_installer_post_install() {
  local repo_root="${1:-${RT_REPO_ROOT:-}}"
  local project_root="${2:-}"
  local restart=false
  rt_deploy_reconciler_snapshots "$repo_root" || true
  if [[ -z "$project_root" ]]; then
    project_root="$(rt_installer_resolve_project_root 2>/dev/null || true)"
  fi
  local scope=host
  if [[ -n "$project_root" ]]; then
    scope=all
  fi
  # Isolated install smokes should not run five-tool apply (slow/networky).
  if [[ "${RT_SKIP_POST_INSTALL:-0}" == "1" ]]; then
    printf 'SKIP: installer post-install reconcile (RT_SKIP_POST_INSTALL=1)\n'
    return 0
  fi
  # Already inside a reconcile apply: that run owns convergence and will finish
  # it after this installer returns. Calling back into it here closes the
  # reconcile -> optimize -> install -> reconcile cycle.
  if [[ -n "${SB_RT_APPLY_ACTIVE:-}" ]]; then
    printf 'SKIP: installer post-install reconcile (already inside reconcile apply)\n'
    return 0
  fi
  local out rc=0
  out="$(rt_installer_run_reconcile "$repo_root" "$project_root" "$scope" apply 2>&1)" || rc=$?
  printf '%s\n' "$out"
  if printf '%s' "$out" | grep -q 'RESTART_REQUIRED: yes'; then
    restart=true
  fi
  rt_emit_reload_notice "$restart"
  if [[ -z "$project_root" ]]; then
    printf '\nNOTE: Host infrastructure deployed. Project toolstack reconciliation pending — run /silver:init in an SB project.\n'
  fi
  return "$rc"
}
