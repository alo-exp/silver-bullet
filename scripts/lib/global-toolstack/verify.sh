#!/usr/bin/env bash
set -euo pipefail

HOME_CURSOR="${HOME}/.cursor"
TS_DIR="${HOME_CURSOR}/hooks/toolstack"
if [[ -n "${SB_GLOBAL_TOOLSTACK_MANIFEST:-}" ]]; then
  GLOBAL_INSTANCES="${SB_GLOBAL_TOOLSTACK_MANIFEST}"
elif [[ -n "${SB_GLOBAL_TOOLSTACK_HOME:-}" ]]; then
  GLOBAL_INSTANCES="${SB_GLOBAL_TOOLSTACK_HOME}/instances.json"
else
  GLOBAL_INSTANCES="${FIVE_TOOL_STACK_HOME:-${XDG_STATE_HOME:-${XDG_DATA_HOME:-${HOME}/.local/state}}/five-tool-stack}/manifest.json"
fi
pass=0 fail=0 warn=0

_check() {
  local status="$1" label="$2" detail="$3"
  case "$status" in
    pass) pass=$((pass+1)); printf '  [x] %s: %s\n' "$label" "$detail" ;;
    warn) warn=$((warn+1)); printf '  [!] %s: %s\n' "$label" "$detail" ;;
    fail) fail=$((fail+1)); printf '  [ ] %s: %s\n' "$label" "$detail" ;;
  esac
}

printf '== Global toolstack verify ==\n\n'

[[ -f "${HOME_CURSOR}/toolstack.json" ]] && _check pass toolstack.json present || _check fail toolstack.json missing

for s in session-bootstrap shell-compression graphify-gate agentmemory-gate rtk-gate context-mode-gate token-compression-tools-gate stack-compression-coordinator record-graphify-query record-agentmemory-usage install parity-verify verify; do
  if [[ -x "${TS_DIR}/${s}.sh" ]] || [[ -f "${TS_DIR}/${s}.sh" && "$s" == "install" ]]; then
    _check pass "hook:${s}" "present"
  else
    _check fail "hook:${s}" "missing"
  fi
done

[[ -f "${TS_DIR}/lib/common.sh" ]] && _check pass lib/common.sh present || _check fail lib/common.sh missing
[[ -f "${TS_DIR}/patch-hooks.py" ]] && _check pass patch-hooks.py present || _check fail patch-hooks.py missing
[[ -f "${TS_DIR}/patch-mcp.py" ]] && _check pass patch-mcp.py present || _check fail patch-mcp.py missing
[[ -f "${TS_DIR}/five_tool_instances.py" ]] && _check pass five_tool_instances.py present || _check fail five_tool_instances.py missing
[[ -f "${TS_DIR}/lib/five_tool_runtime/runtime.py" ]] && _check pass generic-runtime present || _check fail generic-runtime missing
[[ -f "${TS_DIR}/lib/five_tool_runtime/cli.py" ]] && _check pass generic-runtime-cli present || _check fail generic-runtime-cli missing
[[ -f "${TS_DIR}/fix-shell-compression-hook.py" ]] && _check pass fix-shell-compression-hook.py present || _check fail fix-shell-compression-hook.py missing

if [[ -f "$GLOBAL_INSTANCES" ]] && jq -e '
  .schema == "five-tool-stack/v1"
  and .scope == "user-global"
  and .profile == "five_tool_routed"
  and (["graphify", "agentmemory", "context_mode", "leanctx", "rtk"] - (.tools | keys)) == []
  and (["claude", "codex", "cursor", "opencode", "pi"] - (.hosts | keys)) == []
  and .coordination.one_global_instance_per_tool == true
  and .coordination.rtk_rewrite == "single"
' "$GLOBAL_INSTANCES" >/dev/null 2>&1; then
  _check pass global-instances "five-tool manifest present"
else
  _check fail global-instances "five-tool manifest missing or incomplete"
fi

for rule in graphify.mdc agentmemory.mdc leanctx.mdc context-mode.mdc token-compression-enforcement.mdc recommended-tools.mdc; do
  [[ -f "${HOME_CURSOR}/rules/${rule}" ]] && _check pass "rule:${rule}" present || _check fail "rule:${rule}" missing
done

command -v graphify >/dev/null 2>&1 && _check pass graphify-cli "$(command -v graphify)" || _check fail graphify-cli "not on PATH"
command -v graphify-mcp >/dev/null 2>&1 && _check pass graphify-mcp "$(command -v graphify-mcp)" || _check warn graphify-mcp "not on PATH"
command -v agentmemory >/dev/null 2>&1 && _check pass agentmemory-cli "$(command -v agentmemory)" || _check fail agentmemory-cli "not on PATH"
command -v context-mode >/dev/null 2>&1 && _check pass context-mode "$(command -v context-mode)" || _check fail context-mode "not on PATH"
command -v lean-ctx >/dev/null 2>&1 && _check pass lean-ctx "$(command -v lean-ctx)" || _check fail lean-ctx "not on PATH"
command -v rtk >/dev/null 2>&1 && _check pass rtk "$(command -v rtk)" || _check fail rtk "not on PATH"

if [[ -f "${HOME_CURSOR}/mcp.json" ]]; then
  grep -q '"graphify"' "${HOME_CURSOR}/mcp.json" && _check pass mcp:graphify wired || _check fail mcp:graphify missing
  grep -q 'agentmemory' "${HOME_CURSOR}/mcp.json" && _check pass mcp:agentmemory wired || _check fail mcp:agentmemory missing
  grep -q '"context-mode"' "${HOME_CURSOR}/mcp.json" && _check pass mcp:context-mode wired || _check fail mcp:context-mode missing
  grep -q '"leanctx"' "${HOME_CURSOR}/mcp.json" && _check pass mcp:leanctx wired || _check fail mcp:leanctx missing
  ! grep -q 'lean-ctx-standalone' "${HOME_CURSOR}/mcp.json" && _check pass mcp:no_standalone removed || _check fail mcp:lean-ctx-standalone "still present"
else
  _check fail mcp.json missing
fi

if [[ -f "${HOME_CURSOR}/hooks.json" ]]; then
  grep -q 'toolstack/session-bootstrap' "${HOME_CURSOR}/hooks.json" && _check pass hooks:session-bootstrap wired || _check fail hooks:session-bootstrap missing
  # RTK owns the one global shell rewrite; the legacy wrapper must be absent.
  grep -q 'rtk hook cursor' "${HOME_CURSOR}/hooks.json" && _check pass hooks:shell-compression wired || _check fail hooks:shell-compression missing
  ! grep -q 'toolstack/shell-compression' "${HOME_CURSOR}/hooks.json" && _check pass hooks:legacy-shell-wrapper removed || _check fail hooks:legacy-shell-wrapper "still wired"
  grep -q 'rtk hook cursor' "${HOME_CURSOR}/hooks.json" && _check pass hooks:rtk wired || _check fail hooks:rtk missing
  grep -q 'toolstack/graphify-gate' "${HOME_CURSOR}/hooks.json" && _check pass hooks:graphify-gate wired || _check fail hooks:graphify-gate missing
  grep -q 'toolstack/agentmemory-gate' "${HOME_CURSOR}/hooks.json" && _check pass hooks:agentmemory-gate wired || _check fail hooks:agentmemory-gate missing
  grep -q 'toolstack/rtk-gate' "${HOME_CURSOR}/hooks.json" && _check pass hooks:rtk-gate wired || _check fail hooks:rtk-gate missing
  grep -q 'toolstack/context-mode-gate' "${HOME_CURSOR}/hooks.json" && _check pass hooks:context-mode-gate wired || _check fail hooks:context-mode-gate missing
  grep -q 'toolstack/record-graphify-query' "${HOME_CURSOR}/hooks.json" && _check pass hooks:record-graphify wired || _check fail hooks:record-graphify missing
  grep -q 'toolstack/record-agentmemory-usage' "${HOME_CURSOR}/hooks.json" && _check pass hooks:record-agentmemory wired || _check fail hooks:record-agentmemory missing
else
  _check fail hooks.json missing
fi

if curl -sf --max-time 3 http://localhost:3111/agentmemory/health >/dev/null 2>&1; then
  _check pass agentmemory-server healthy
else
  _check warn agentmemory-server "not healthy — start agentmemory"
fi

test_repo="${TEST_REPO:-${HOME}/.cursor/worktrees/repo/r41j}"
if [[ -d "$test_repo/.git" ]]; then
  if [[ -f "$test_repo/graphify-out/graph.json" ]]; then
    _check pass graphify-index "present in test repo"
  else
    _check warn graphify-index "missing in ${test_repo}"
  fi
fi

printf '\nSummary: %s passed, %s failed, %s warnings\n' "$pass" "$fail" "$warn"
[[ "$fail" -eq 0 ]]
