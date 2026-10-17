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

if [[ -f "$TS_JSON" ]]; then _check pass config exists; else _check fail config missing; fi

if [[ "$(_jq '.enforcement')" == "always" ]]; then _check pass enforcement always; else _check fail enforcement "not always"; fi
if [[ "$(_jq '.sb_parity')" == "true" ]]; then _check pass sb_parity true; else _check fail sb_parity "not true"; fi
if [[ "$(_jq '.profile')" == "five_tool_routed" ]]; then _check pass profile five_tool_routed; else _check fail profile "$(_jq '.profile')"; fi

if [[ "$(_jq '.shell_compression.primary')" == "rtk" ]]; then _check pass shell_primary rtk; else _check fail shell_primary "$(_jq '.shell_compression.primary')"; fi
if [[ "$(_jq '.shell_compression.fallback')" == "leanctx" ]]; then _check pass shell_fallback leanctx; else _check fail shell_fallback "$(_jq '.shell_compression.fallback')"; fi

for route in sb_wire sb_read sb_grep sb_shell sb_slice sb_webfetch sb_graph sb_remember sb_pathjail sb_injection; do
  case "$route" in
    sb_wire|sb_read|sb_pathjail|sb_injection) want=leanctx ;;
    sb_grep|sb_slice|sb_webfetch) want=context_mode ;;
    sb_shell) want=rtk ;;
    sb_graph) want=graphify ;;
    sb_remember) want=agentmemory ;;
  esac
  got="$(_jq ".routes.${route}")"
  if [[ "$got" == "$want" ]]; then _check pass "route:${route}" "$want"; else _check fail "route:${route}" "got=${got} want=${want}"; fi
done

if [[ "$(_jq '.tools.graphify.graph_path')" == "graphify-out/graph.json" ]]; then _check pass graph_path ok; else _check fail graph_path "$(_jq '.tools.graphify.graph_path')"; fi
if [[ "$(_jq '.tools.graphify.query_ttl_seconds')" == "1800" ]]; then _check pass graphify_ttl 1800; else _check fail graphify_ttl "$(_jq '.tools.graphify.query_ttl_seconds')"; fi
if [[ "$(_jq '.tools.graphify.query_budget')" == "2000" ]]; then _check pass graphify_budget 2000; else _check fail graphify_budget "$(_jq '.tools.graphify.query_budget')"; fi
if [[ "$(_jq '.tools.agentmemory.export_root')" == ".agentmemory" ]]; then _check pass export_root .agentmemory; else _check fail export_root "$(_jq '.tools.agentmemory.export_root')"; fi
if [[ "$(_jq '.tools.agentmemory.usage_ttl_seconds')" == "1800" ]]; then _check pass agentmemory_ttl 1800; else _check fail agentmemory_ttl "$(_jq '.tools.agentmemory.usage_ttl_seconds')"; fi

if ! jq -e '.tools.leanctx_standalone' "$TS_JSON" >/dev/null 2>&1; then _check pass no_standalone_tool absent; else _check fail no_standalone_tool "leanctx_standalone present"; fi

for tool in graphify agentmemory context_mode leanctx rtk; do
  if [[ "$(_jq ".tools.${tool}.required")" == "true" ]]; then _check pass "required:${tool}" true; else _check fail "required:${tool}" "$(_jq ".tools.${tool}.required")"; fi
done

for hook in session-bootstrap shell-compression graphify-gate agentmemory-gate rtk-gate context-mode-gate token-compression-tools-gate stack-compression-coordinator record-graphify-query record-agentmemory-usage; do
  if [[ -x "${TS_DIR}/${hook}.sh" ]]; then _check pass "hook:${hook}" executable; else _check fail "hook:${hook}" missing; fi
done
if [[ -f "${TS_DIR}/lib/common.sh" ]]; then _check pass common.sh present; else _check fail common.sh missing; fi

for rule in graphify.mdc agentmemory.mdc leanctx.mdc context-mode.mdc token-compression-enforcement.mdc recommended-tools.mdc; do
  if [[ -f "${HOME_CURSOR}/rules/${rule}" ]]; then _check pass "rule:${rule}" present; else _check fail "rule:${rule}" missing; fi
done

if [[ -f "$MCP_JSON" ]]; then
  if grep -q '"graphify"' "$MCP_JSON"; then _check pass mcp:graphify wired; else _check fail mcp:graphify missing; fi
  if grep -q 'agentmemory' "$MCP_JSON"; then _check pass mcp:agentmemory wired; else _check fail mcp:agentmemory missing; fi
  if grep -q '"context-mode"' "$MCP_JSON"; then _check pass mcp:context-mode wired; else _check fail mcp:context-mode missing; fi
  if grep -q '"leanctx"' "$MCP_JSON"; then _check pass mcp:leanctx wired; else _check fail mcp:leanctx missing; fi
  if ! grep -q 'lean-ctx-standalone' "$MCP_JSON"; then _check pass mcp:no_standalone removed; else _check fail mcp:no_standalone "still present"; fi
  if grep -q 'LEANCTX_DISABLE_SHELL_MCP' "$MCP_JSON"; then _check pass leanctx:shell_off env; else _check fail leanctx:shell_off missing; fi
  if grep -q 'lctx_' "$MCP_JSON"; then _check pass leanctx:prefix lctx_; else _check warn leanctx:prefix "check env"; fi
else
  _check fail mcp.json missing
fi

if [[ -f "$HOOKS_JSON" ]]; then
  # The manifest-backed RTK hook is the single global shell rewrite owner.
  # The legacy shell-compression wrapper must stay unwired to prevent a second
  # RTK/LeanCTX rewrite of the same shell command.
  if grep -q 'rtk hook cursor' "$HOOKS_JSON"; then _check pass hooks:shell_compression wired; else _check fail hooks:shell_compression missing; fi
  if ! grep -q 'toolstack/shell-compression' "$HOOKS_JSON"; then _check pass hooks:legacy_shell_wrapper removed; else _check fail hooks:legacy_shell_wrapper "still wired"; fi
  if ! grep -q 'lean-ctx hook rewrite' "$HOOKS_JSON"; then _check pass hooks:no_leanctx_rewrite removed; else _check fail hooks:no_leanctx_rewrite "still present"; fi
  if grep -q 'toolstack/graphify-gate' "$HOOKS_JSON"; then _check pass hooks:graphify_gate wired; else _check fail hooks:graphify_gate missing; fi
  if grep -q 'toolstack/agentmemory-gate' "$HOOKS_JSON"; then _check pass hooks:agentmemory_gate wired; else _check fail hooks:agentmemory_gate missing; fi
  if grep -q 'toolstack/rtk-gate' "$HOOKS_JSON"; then _check pass hooks:rtk_gate wired; else _check fail hooks:rtk_gate missing; fi
  if grep -q 'toolstack/context-mode-gate' "$HOOKS_JSON"; then _check pass hooks:cm_gate wired; else _check fail hooks:cm_gate missing; fi
  if grep -q 'toolstack/stack-compression-coordinator' "$HOOKS_JSON"; then _check pass hooks:coordinator wired; else _check fail hooks:coordinator missing; fi
  if grep -q 'toolstack/token-compression-tools-gate' "$HOOKS_JSON"; then _check pass hooks:token_gate wired; else _check fail hooks:token_gate missing; fi
  if grep -q 'toolstack/session-bootstrap' "$HOOKS_JSON"; then _check pass hooks:session_bootstrap wired; else _check fail hooks:session_bootstrap missing; fi
  # rtk before context-mode
  # grep exits 1 when a hook is absent; under pipefail that must not abort the scorecard.
  rtk_line=$(grep -n 'rtk hook cursor' "$HOOKS_JSON" | head -1 | cut -d: -f1 || true)
  cm_line=$(grep -nE 'context-mode.*hook cursor pretooluse|hook cursor pretooluse.*context-mode' "$HOOKS_JSON" | head -1 | cut -d: -f1 || true)
  if [[ -n "$rtk_line" && -n "$cm_line" && "$rtk_line" -lt "$cm_line" ]]; then
    _check pass hooks:rtk_before_cm order
  else
    _check fail hooks:rtk_before_cm "rtk=${rtk_line} cm=${cm_line}"
  fi
else
  _check fail hooks.json missing
fi

if command -v graphify >/dev/null 2>&1; then _check pass cli:graphify ok; else _check fail cli:graphify missing; fi
if command -v agentmemory >/dev/null 2>&1; then _check pass cli:agentmemory ok; else _check fail cli:agentmemory missing; fi
if command -v context-mode >/dev/null 2>&1; then _check pass cli:context-mode ok; else _check fail cli:context-mode missing; fi
if command -v lean-ctx >/dev/null 2>&1; then _check pass cli:lean-ctx ok; else _check fail cli:lean-ctx missing; fi
if command -v rtk >/dev/null 2>&1; then _check pass cli:rtk ok; else _check fail cli:rtk missing; fi

if [[ -f "$SB_JSON" ]]; then
  sb_budget="$(jq -r '.recommended_tools.graphify.query_budget // 0' "$SB_JSON")"
  if [[ "$sb_budget" == "$(_jq '.tools.graphify.query_budget')" ]]; then _check pass parity:query_budget "$sb_budget"; else _check fail parity:query_budget "sb=${sb_budget} ts=$(_jq '.tools.graphify.query_budget')"; fi
  sb_export="$(jq -r '.recommended_tools.agentmemory.export_root // ""' "$SB_JSON")"
  if [[ "$sb_export" == "$(_jq '.tools.agentmemory.export_root')" ]]; then _check pass parity:export_root "$sb_export"; else _check fail parity:export_root "sb=${sb_export}"; fi
fi

printf '\nSummary: %s passed, %s failed, %s warnings\n' "$pass" "$fail" "$warn"
[[ "$fail" -eq 0 ]]
