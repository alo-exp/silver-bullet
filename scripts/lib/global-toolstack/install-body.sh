#!/usr/bin/env bash
# SB OVERRIDE: Install host-global Cursor toolstack — full five_tool_routed parity.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# When deployed: SCRIPT_DIR = ~/.cursor/hooks/toolstack
# When in repo: SCRIPT_DIR = .../scripts/lib/global-toolstack
if [[ -f "${SCRIPT_DIR}/../../install-global-toolstack.sh" ]]; then
  REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
  SRC_DIR="${SCRIPT_DIR}"
else
  REPO_ROOT="${TOOLSTACK_REPO_ROOT:-}"
  SRC_DIR="${SCRIPT_DIR}"
fi
if [[ -z "$REPO_ROOT" && -f "${HOME}/.cursor/state/toolstack/repo-root" ]]; then
  REPO_ROOT="$(cat "${HOME}/.cursor/state/toolstack/repo-root")"
fi

HOME_CURSOR="${HOME}/.cursor"
TS_DIR="${HOME_CURSOR}/hooks/toolstack"
TS_LIB="${TS_DIR}/lib"
RULES_DIR="${HOME_CURSOR}/rules"
STATE_DIR="${HOME_CURSOR}/state/toolstack"
TS="$(date +%Y%m%dT%H%M%S)"

mkdir -p "$TS_LIB" "$STATE_DIR" "$RULES_DIR"
[[ -n "$REPO_ROOT" ]] && printf '%s' "$REPO_ROOT" >"${STATE_DIR}/repo-root"

[[ -f "${HOME_CURSOR}/hooks.json" ]] && cp -f "${HOME_CURSOR}/hooks.json" "${HOME_CURSOR}/hooks.json.bak.${TS}"
[[ -f "${HOME_CURSOR}/mcp.json" ]] && cp -f "${HOME_CURSOR}/mcp.json" "${HOME_CURSOR}/mcp.json.bak.${TS}"

# --- toolstack.json ---
cat >"${HOME_CURSOR}/toolstack.json" <<'JSON'
{
  "version": 1,
  "enforcement": "always",
  "profile": "five_tool_routed",
  "sb_parity": true,
  "state_dir": "~/.cursor/state/toolstack",
  "shell_compression": {
    "primary": "rtk",
    "fallback": "leanctx"
  },
  "routes": {
    "sb_wire": "leanctx",
    "sb_read": "leanctx",
    "sb_grep": "context_mode",
    "sb_shell": "rtk",
    "sb_slice": "context_mode",
    "sb_webfetch": "context_mode",
    "sb_graph": "graphify",
    "sb_remember": "agentmemory",
    "sb_pathjail": "leanctx",
    "sb_injection": "leanctx"
  },
  "tools": {
    "graphify": {
      "required": true,
      "graph_path": "graphify-out/graph.json",
      "query_ttl_seconds": 1800,
      "query_budget": 2000
    },
    "agentmemory": {
      "required": true,
      "usage_ttl_seconds": 1800,
      "health_url": "http://localhost:3111/agentmemory/health",
      "export_root": ".agentmemory"
    },
    "context_mode": {
      "required": true
    },
    "leanctx": {
      "required": true,
      "profile": "five_tool_routed",
      "mcp_server": "leanctx"
    },
    "rtk": {
      "required": true,
      "usage_ttl_seconds": 1800
    }
  },
  "worktree": {
    "bootstrap_graphify": true,
    "bootstrap_on": ["sessionStart", "missing_graph"],
    "graphify_update_args": ["update", ".", "--no-cluster"],
    "bootstrap_timeout_seconds": 120
  }
}
JSON

# --- deploy hook scripts from SRC_DIR ---
for f in common.sh shell-compression.sh graphify-gate.sh agentmemory-gate.sh \
  rtk-gate.sh context-mode-gate.sh token-compression-tools-gate.sh \
  stack-compression-coordinator.sh session-bootstrap.sh \
  record-graphify-query.sh record-agentmemory-usage.sh; do
  if [[ -f "${SRC_DIR}/${f}" ]]; then
    if [[ "$f" == "common.sh" ]]; then
      cp -f "${SRC_DIR}/${f}" "${TS_LIB}/common.sh" 2>/dev/null || true
    else
      cp -f "${SRC_DIR}/${f}" "${TS_DIR}/${f}" 2>/dev/null || true
      chmod +x "${TS_DIR}/${f}" 2>/dev/null || true
    fi
  fi
done

for py in patch-hooks.py patch-mcp.py fix-shell-compression-hook.py parity-verify.sh verify.sh; do
  [[ -f "${SRC_DIR}/${py}" ]] && cp -f "${SRC_DIR}/${py}" "${TS_DIR}/${py}" 2>/dev/null || true
done
chmod +x "${TS_DIR}/parity-verify.sh" "${TS_DIR}/verify.sh" 2>/dev/null || true

# --- graphify cursor install ---
if command -v graphify >/dev/null 2>&1; then
  graphify cursor install 2>/dev/null || true
fi

# --- MCP + hooks batch (reconciler owns RTCM optimize + patch writes + reload receipt) ---
# Direct patch-mcp/patch-hooks removed — rt_apply_host_*_batch in reconciler apply path.

# --- global rules sync ---
RULE_SRC="${REPO_ROOT}/.cursor/rules"
[[ -d "$RULE_SRC" ]] || RULE_SRC="${SRC_DIR}"
for rule in graphify.mdc agentmemory.mdc leanctx.mdc context-mode.mdc token-compression-enforcement.mdc; do
  if [[ -f "${RULE_SRC}/${rule}" ]]; then
    cp -f "${RULE_SRC}/${rule}" "${RULES_DIR}/${rule}"
  fi
done
if [[ -f "${SRC_DIR}/global-recommended-tools.mdc" ]]; then
  cp -f "${SRC_DIR}/global-recommended-tools.mdc" "${RULES_DIR}/recommended-tools.mdc"
fi

# --- five-tool reconciler (installer entry point; batches MCP + hook writes) ---
_installer_lib=""
if [[ -n "$REPO_ROOT" && -f "${REPO_ROOT}/scripts/lib/recommended-tools/installer.sh" ]]; then
  _installer_lib="${REPO_ROOT}/scripts/lib/recommended-tools/installer.sh"
elif [[ -f "${TS_LIB}/recommended-tools/installer.sh" ]]; then
  _installer_lib="${TS_LIB}/recommended-tools/installer.sh"
fi
if [[ -n "$_installer_lib" ]]; then
  # shellcheck source=../../recommended-tools/installer.sh
  source "$_installer_lib"
  _rt_proj=""
  if [[ -n "${SB_RECONCILE_PROJECT_ROOT:-}" && -f "${SB_RECONCILE_PROJECT_ROOT}/.silver-bullet.json" ]]; then
    _rt_proj="$(cd "${SB_RECONCILE_PROJECT_ROOT}" && pwd -P)"
  fi
  rt_installer_post_install "${REPO_ROOT}" "${_rt_proj:-}" || \
    printf 'WARN: reconciler post-install exited nonzero (host infra may still be usable)\n' >&2
fi

# --- self-deploy install.sh (skip when already running from deployed path) ---
_self="$(cd "$(dirname "$0")" && pwd -P)/$(basename "$0")"
_dest="$(cd "$TS_DIR" && pwd -P)/install.sh"
if [[ "$_self" != "$_dest" ]]; then
  cp -f "$0" "${TS_DIR}/install.sh"
  chmod +x "${TS_DIR}/install.sh"
fi

printf '\n== Global toolstack install complete ==\n'
printf 'Backups: hooks.json.bak.%s mcp.json.bak.%s\n' "$TS" "$TS"
printf 'Run: bash %s/parity-verify.sh && bash %s/verify.sh\n' "$TS_DIR" "$TS_DIR"

