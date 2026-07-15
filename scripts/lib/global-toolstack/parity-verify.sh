#!/usr/bin/env bash
# Compare ~/.cursor/toolstack.json vs SB five_tool_routed template defaults.
set -euo pipefail

HOME_CURSOR="${HOME}/.cursor"
TS_JSON="${HOME_CURSOR}/toolstack.json"
MCP_JSON="${HOME_CURSOR}/mcp.json"
HOOKS_JSON="${HOME_CURSOR}/hooks.json"
TS_DIR="${HOME_CURSOR}/hooks/toolstack"
SB_JSON="${TOOLSTACK_REPO_ROOT:-${HOME}/.cursor/worktrees/repo/r41j}/.silver-bullet.json"
pass=0 fail=0 warn=0

_check() {
  local status="$1" label="$2" detail="${3:-ok}"
  case "$status" in
    pass) pass=$((pass+1)); printf '  [x] %s: %s\n' "$label" "$detail" ;;
    warn) warn=$((warn+1)); printf '  [!] %s: %s\n' "$label" "$detail" ;;
    fail) fail=$((fail+1)); printf '  [ ] %s: %s\n' "$label" "$detail" ;;
  esac
}

_jq() { jq -r "$1" "$TS_JSON" 2>/dev/null || echo ""; }

printf '== Global toolstack parity verify (SB five_tool_routed) ==\n\n'

[[ -f "$TS_JSON" ]] && _check pass config exists || _check fail config missing

[[ "$(_jq '.enforcement')" == "always" ]] && _check pass enforcement always || _check fail enforcement "not always"
[[ "$(_jq '.sb_parity')" == "true" ]] && _check pass sb_parity true || _check fail sb_parity "not true"
[[ "$(_jq '.profile')" == "five_tool_routed" ]] && _check pass profile five_tool_routed || _check fail profile "$(_jq '.profile')"

[[ "$(_jq '.shell_compression.primary')" == "rtk" ]] && _check pass shell_primary rtk || _check fail shell_primary "$(_jq '.shell_compression.primary')"
[[ "$(_jq '.shell_compression.fallback')" == "leanctx" ]] && _check pass shell_fallback leanctx || _check fail shell_fallback "$(_jq '.shell_compression.fallback')"

for route in sb_wire sb_read sb_grep sb_shell sb_slice sb_webfetch sb_graph sb_remember sb_pathjail sb_injection; do
  case "$route" in
    sb_wire|sb_read|sb_pathjail|sb_injection) want=leanctx ;;
    sb_grep|sb_slice|sb_webfetch) want=context_mode ;;
    sb_shell) want=rtk ;;
    sb_graph) want=graphify ;;
    sb_remember) want=agentmemory ;;
  esac
  got="$(_jq ".routes.${route}")"
  [[ "$got" == "$want" ]] && _check pass "route:${route}" "$want" || _check fail "route:${route}" "got=${got} want=${want}"
done

[[ "$(_jq '.tools.graphify.graph_path')" == "graphify-out/graph.json" ]] && _check pass graph_path ok || _check fail graph_path "$(_jq '.tools.graphify.graph_path')"
[[ "$(_jq '.tools.graphify.query_ttl_seconds')" == "1800" ]] && _check pass graphify_ttl 1800 || _check fail graphify_ttl "$(_jq '.tools.graphify.query_ttl_seconds')"
[[ "$(_jq '.tools.graphify.query_budget')" == "2000" ]] && _check pass graphify_budget 2000 || _check fail graphify_budget "$(_jq '.tools.graphify.query_budget')"
[[ "$(_jq '.tools.agentmemory.export_root')" == ".agentmemory" ]] && _check pass export_root .agentmemory || _check fail export_root "$(_jq '.tools.agentmemory.export_root')"
[[ "$(_jq '.tools.agentmemory.usage_ttl_seconds')" == "1800" ]] && _check pass agentmemory_ttl 1800 || _check fail agentmemory_ttl "$(_jq '.tools.agentmemory.usage_ttl_seconds')"

! jq -e '.tools.leanctx_standalone' "$TS_JSON" >/dev/null 2>&1 && _check pass no_standalone_tool absent || _check fail no_standalone_tool "leanctx_standalone present"

for tool in graphify agentmemory context_mode leanctx rtk; do
  [[ "$(_jq ".tools.${tool}.required")" == "true" ]] && _check pass "required:${tool}" true || _check fail "required:${tool}" "$(_jq ".tools.${tool}.required")"
done

for hook in session-bootstrap shell-compression graphify-gate agentmemory-gate rtk-gate context-mode-gate token-compression-tools-gate stack-compression-coordinator record-graphify-query record-agentmemory-usage; do
  [[ -x "${TS_DIR}/${hook}.sh" ]] && _check pass "hook:${hook}" executable || _check fail "hook:${hook}" missing
done
[[ -f "${TS_DIR}/lib/common.sh" ]] && _check pass common.sh present || _check fail common.sh missing

for rule in graphify.mdc agentmemory.mdc leanctx.mdc context-mode.mdc token-compression-enforcement.mdc recommended-tools.mdc; do
  [[ -f "${HOME_CURSOR}/rules/${rule}" ]] && _check pass "rule:${rule}" present || _check fail "rule:${rule}" missing
done

if [[ -f "$MCP_JSON" ]]; then
  grep -q '"graphify"' "$MCP_JSON" && _check pass mcp:graphify wired || _check fail mcp:graphify missing
  grep -q 'agentmemory' "$MCP_JSON" && _check pass mcp:agentmemory wired || _check fail mcp:agentmemory missing
  grep -q '"context-mode"' "$MCP_JSON" && _check pass mcp:context-mode wired || _check fail mcp:context-mode missing
  grep -q '"leanctx"' "$MCP_JSON" && _check pass mcp:leanctx wired || _check fail mcp:leanctx missing
  ! grep -q 'lean-ctx-standalone' "$MCP_JSON" && _check pass mcp:no_standalone removed || _check fail mcp:no_standalone "still present"
  grep -q 'LEANCTX_DISABLE_SHELL_MCP' "$MCP_JSON" && _check pass leanctx:shell_off env || _check fail leanctx:shell_off missing
  grep -q 'lctx_' "$MCP_JSON" && _check pass leanctx:prefix lctx_ || _check warn leanctx:prefix "check env"
else
  _check fail mcp.json missing
fi

if [[ -f "$HOOKS_JSON" ]]; then
  grep -q 'toolstack/shell-compression' "$HOOKS_JSON" && _check pass hooks:shell_compression wired || _check fail hooks:shell_compression missing
  grep -q 'rtk hook cursor' "$HOOKS_JSON" && _check pass hooks:rtk_primary wired || _check fail hooks:rtk_primary missing
  ! grep -q 'lean-ctx hook rewrite' "$HOOKS_JSON" && _check pass hooks:no_leanctx_rewrite removed || _check fail hooks:no_leanctx_rewrite "still present"
  grep -q 'toolstack/graphify-gate' "$HOOKS_JSON" && _check pass hooks:graphify_gate wired || _check fail hooks:graphify_gate missing
  grep -q 'toolstack/agentmemory-gate' "$HOOKS_JSON" && _check pass hooks:agentmemory_gate wired || _check fail hooks:agentmemory_gate missing
  grep -q 'toolstack/rtk-gate' "$HOOKS_JSON" && _check pass hooks:rtk_gate wired || _check fail hooks:rtk_gate missing
  grep -q 'toolstack/context-mode-gate' "$HOOKS_JSON" && _check pass hooks:cm_gate wired || _check fail hooks:cm_gate missing
  grep -q 'toolstack/stack-compression-coordinator' "$HOOKS_JSON" && _check pass hooks:coordinator wired || _check fail hooks:coordinator missing
  grep -q 'toolstack/token-compression-tools-gate' "$HOOKS_JSON" && _check pass hooks:token_gate wired || _check fail hooks:token_gate missing
  grep -q 'toolstack/session-bootstrap' "$HOOKS_JSON" && _check pass hooks:session_bootstrap wired || _check fail hooks:session_bootstrap missing
  # rtk before context-mode
  rtk_line=$(grep -n 'rtk hook cursor' "$HOOKS_JSON" | head -1 | cut -d: -f1)
  cm_line=$(grep -n 'context-mode hook cursor pretooluse' "$HOOKS_JSON" | head -1 | cut -d: -f1)
  if [[ -n "$rtk_line" && -n "$cm_line" && "$rtk_line" -lt "$cm_line" ]]; then
    _check pass hooks:rtk_before_cm order
  else
    _check fail hooks:rtk_before_cm "rtk=${rtk_line} cm=${cm_line}"
  fi
else
  _check fail hooks.json missing
fi

command -v graphify >/dev/null 2>&1 && _check pass cli:graphify ok || _check fail cli:graphify missing
command -v agentmemory >/dev/null 2>&1 && _check pass cli:agentmemory ok || _check fail cli:agentmemory missing
command -v context-mode >/dev/null 2>&1 && _check pass cli:context-mode ok || _check fail cli:context-mode missing
command -v lean-ctx >/dev/null 2>&1 && _check pass cli:lean-ctx ok || _check fail cli:lean-ctx missing
command -v rtk >/dev/null 2>&1 && _check pass cli:rtk ok || _check fail cli:rtk missing

if [[ -f "$SB_JSON" ]]; then
  sb_budget="$(jq -r '.recommended_tools.graphify.query_budget // 0' "$SB_JSON")"
  [[ "$sb_budget" == "$(_jq '.tools.graphify.query_budget')" ]] && _check pass parity:query_budget "$sb_budget" || _check fail parity:query_budget "sb=${sb_budget} ts=$(_jq '.tools.graphify.query_budget')"
  sb_export="$(jq -r '.recommended_tools.agentmemory.export_root // ""' "$SB_JSON")"
  [[ "$sb_export" == "$(_jq '.tools.agentmemory.export_root')" ]] && _check pass parity:export_root "$sb_export" || _check fail parity:export_root "sb=${sb_export}"
fi

printf '\nSummary: %s passed, %s failed, %s warnings\n' "$pass" "$fail" "$warn"
[[ "$fail" -eq 0 ]]
