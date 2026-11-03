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

# The user's per-tool consent (docs/CONSENT.md): nothing is wired or required without it.
ts_wired() { return 1; }
if [[ -n "$REPO_ROOT" && -f "${REPO_ROOT}/hooks/lib/user-consent.sh" ]]; then
  # shellcheck source=/dev/null
  source "${REPO_ROOT}/hooks/lib/user-consent.sh"
  ts_wired() { sb_consent_granted "$1" wire; }
fi

# ts_install_file SRC DEST: copy a Silver Bullet file, keeping the previous different content once in
# DEST.sb-backup. cp writes through a symlinked DEST, so a rule linked into the user's dotfiles stays a link.
ts_install_file() {
  local src="$1" dest="$2"
  if [[ -f "$dest" ]]; then
    cmp -s "$src" "$dest" && return 0
    [[ -f "${dest}.sb-backup" ]] || cp -p "$dest" "${dest}.sb-backup"
  fi
  cp -f "$src" "$dest"
}

[[ -f "${HOME_CURSOR}/hooks.json" ]] && cp -f "${HOME_CURSOR}/hooks.json" "${HOME_CURSOR}/hooks.json.bak.${TS}"
[[ -f "${HOME_CURSOR}/mcp.json" ]] && cp -f "${HOME_CURSOR}/mcp.json" "${HOME_CURSOR}/mcp.json.bak.${TS}"

# --- toolstack.json ---
# The user's file wins: it is written only when absent, with "required" following the user's wire consent.
TOOLSTACK_JSON="${HOME_CURSOR}/toolstack.json"
if [[ -e "$TOOLSTACK_JSON" ]]; then
  printf 'KEEP: %s exists - not overwritten\n' "$TOOLSTACK_JSON"
else
TOOLSTACK_TMP="$(mktemp "${HOME_CURSOR}/.toolstack.json.XXXXXX")"
cat >"$TOOLSTACK_TMP" <<'JSON'
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
_req='{}'
for _t in graphify agentmemory context_mode leanctx rtk; do
  if ts_wired "$_t"; then
    _req="$(jq -c --arg t "$_t" '.[$t] = true' <<<"$_req")"
  else
    _req="$(jq -c --arg t "$_t" '.[$t] = false' <<<"$_req")"
  fi
done
jq --argjson req "$_req" '
  reduce ($req | keys[]) as $t (.; .tools[$t].required = $req[$t])
  | .enforcement = (if ($req | any(.[]; . == true)) then "always" else "off" end)' \
  "$TOOLSTACK_TMP" >"${TOOLSTACK_TMP}.new" && mv -f "${TOOLSTACK_TMP}.new" "$TOOLSTACK_JSON"
rm -f "$TOOLSTACK_TMP"
fi

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

for py in five_tool_instances.py opencode.py install-pi.py patch-hooks.py patch-mcp.py fix-shell-compression-hook.py parity-verify.sh verify.sh; do
  if [[ -f "${SRC_DIR}/${py}" ]]; then
    cp -f "${SRC_DIR}/${py}" "${TS_DIR}/${py}" 2>/dev/null || true
  fi
done
[[ -f "${SRC_DIR}/../sb_host_config.py" ]] && cp -f "${SRC_DIR}/../sb_host_config.py" "${TS_DIR}/sb_host_config.py"
chmod +x "${TS_DIR}/parity-verify.sh" "${TS_DIR}/verify.sh" 2>/dev/null || true

# --- graphify cursor install ---
if command -v graphify >/dev/null 2>&1 && ts_wired graphify; then
  graphify cursor install 2>/dev/null || true
fi

# --- MCP + hooks batch (reconciler owns RTCM optimize + patch writes + reload receipt) ---
# Direct patch-mcp/patch-hooks removed — rt_apply_host_*_batch in reconciler apply path.

# --- global rules sync ---
RULE_SRC="${REPO_ROOT}/.cursor/rules"
[[ -d "$RULE_SRC" ]] || RULE_SRC="${SRC_DIR}"
for rule in graphify.mdc agentmemory.mdc leanctx.mdc context-mode.mdc token-compression-enforcement.mdc; do
  if [[ -f "${RULE_SRC}/${rule}" ]]; then
    ts_install_file "${RULE_SRC}/${rule}" "${RULES_DIR}/${rule}"
  fi
done
if [[ -f "${SRC_DIR}/global-recommended-tools.mdc" ]]; then
  ts_install_file "${SRC_DIR}/global-recommended-tools.mdc" "${RULES_DIR}/recommended-tools.mdc"
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
  chmod +x "${TS_DIR}/install.sh" 2>/dev/null || true
fi

printf '\n== Global toolstack install complete ==\n'
printf 'Backups: hooks.json.bak.%s mcp.json.bak.%s\n' "$TS" "$TS"
printf 'Run: bash %s/parity-verify.sh && bash %s/verify.sh\n' "$TS_DIR" "$TS_DIR"
