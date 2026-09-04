#!/usr/bin/env bash
# Regression tests for five-tool cross_tool support on the supported hosts.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEMPLATE="$REPO_ROOT/templates/silver-bullet.config.json.default"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

for host in claude codex cursor; do
  home="$(mktemp -d)"
  project="$(mktemp -d)"
  cleanup() { rm -rf "$home" "$project"; }
  trap cleanup RETURN

  jq '.sb_initiated = true
    | .recommended_tools.graphify.enabled_by_user = true
    | .recommended_tools.agentmemory.enabled_by_user = true
    | .recommended_tools.rtk.enabled_by_user = true
    | .recommended_tools.context_mode.enabled_by_user = true
    | .recommended_tools.leanctx.enabled_by_user = true' \
    "$TEMPLATE" >"$project/.silver-bullet.json"
  printf '# Silver Bullet\n' >"$project/silver-bullet.md"
  git -C "$project" init -q

  case "$host" in
    claude)
      mkdir -p "$home/.claude"
      printf '{"hooks":{"PreToolUse":[{"command":"rtk hook claude"}]}}\n' >"$home/.claude/settings.json"
      printf '{"mcpServers":{"graphify":{},"agentmemory":{},"context-mode":{},"leanctx":{}}}\n' >"$home/.claude.json"
      ;;
    codex)
      mkdir -p "$home/.codex"
      printf '# RTK awareness layer\n' >"$home/.codex/AGENTS.md"
      printf '[mcp_servers.graphify]\ncommand = "graphify-mcp"\n\n[mcp_servers.agentmemory]\ncommand = "npx"\n\n[mcp_servers.context-mode]\ncommand = "context-mode"\n\n[mcp_servers.leanctx]\ncommand = "lean-ctx"\n' >"$home/.codex/config.toml"
      ;;
    cursor)
      mkdir -p "$home/.cursor"
      printf '{"hooks":{"preToolUse":[{"command":"rtk hook cursor"}]}}\n' >"$home/.cursor/hooks.json"
      printf '{"mcpServers":{"graphify":{},"agentmemory":{},"context-mode":{},"leanctx":{}}}\n' >"$home/.cursor/mcp.json"
      ;;
  esac

  result="$(
    HOME="$home" CODEX_HOME="$home/.codex" RT_PROJECT_ROOT="$project" \
      RT_CONFIG_FILE="$project/.silver-bullet.json" RT_REPO_ROOT="$REPO_ROOT" \
      RT_HOST="$host" RT_MODE=verify RT_SKIP_VENDOR_DOCTOR=1 \
      bash -c '
        set -euo pipefail
        source "$1/scripts/lib/recommended-tools/common.sh"
        rt_init_paths
        source "$1/scripts/lib/recommended-tools/probe-cross-tool.sh"
        rt_probe_cross_tool
      ' _ "$REPO_ROOT"
  )"

  if printf '%s' "$result" | jq -e \
    '(.canonical_state != "unsupported") and ((.evidence | index("shell_owner_not_rtk")) == null)' \
    >/dev/null 2>&1; then
    pass "cross_tool is supported and reaches host checks on $host"
  else
    fail "cross_tool is supported and reaches host checks on $host ($result)"
  fi

  supported="$(HOME="$home" RT_HOST="$host" bash -c '
    source "$1/scripts/lib/recommended-tools/common.sh"
    rt_host_supported "$2"
  ' _ "$REPO_ROOT" "$host"; echo $?)"
  [[ "$supported" == "0" ]] \
    && pass "host capability includes $host" \
    || fail "host capability includes $host"

  mcp_checks="$(
    HOME="$home" CODEX_HOME="$home/.codex" RT_HOST="$host" \
      bash -c '
        set -euo pipefail
        source "$1/scripts/lib/recommended-tools/common.sh"
        rt_init_paths
        source "$1/scripts/lib/recommended-tools/probe-graphify.sh"
        source "$1/scripts/lib/recommended-tools/probe-agentmemory.sh"
        source "$1/scripts/lib/recommended-tools/probe-context-mode.sh"
        source "$1/scripts/lib/recommended-tools/probe-leanctx.sh"
        rt_probe_graphify_mcp_configured
        rt_probe_agentmemory_mcp_configured
        rt_probe_context_mode_mcp
        rt_probe_leanctx_mcp
        echo OK
      ' _ "$REPO_ROOT"
  )"
  [[ "$mcp_checks" == "OK" ]] \
    && pass "five-tool MCP contract checks pass on $host" \
    || fail "five-tool MCP contract checks pass on $host"
done

# The shared MCP repairer must target the active host, never create a Cursor
# config as a side effect of Claude/Codex repair.
for host in claude codex; do
  home="$(mktemp -d)"
  bin="$(mktemp -d)"
  mkdir -p "$home/.codex"
  printf '#!/usr/bin/env bash\nexit 0\n' >"$bin/graphify-mcp"
  chmod +x "$bin/graphify-mcp"
  if [[ "$host" == "codex" ]]; then
    code_home="$home/.codex"
    printf '' >"$code_home/config.toml"
  else
    code_home=""
    printf '{"mcpServers":{}}\n' >"$home/.claude.json"
  fi
  RT_HOST="$host" HOME="$home" CODEX_HOME="$home/.codex" PATH="$bin:$PATH" \
    RT_PATCH_GRAPHIFY=1 RT_PATCH_AGENTMEMORY=1 RT_PATCH_CONTEXT_MODE=1 RT_PATCH_LEANCTX=1 \
    python3 "$REPO_ROOT/scripts/lib/global-toolstack/patch-mcp.py" >/dev/null
  if [[ "$host" == "codex" ]]; then
    target="$home/.codex/config.toml"
    if grep -q '^\[mcp_servers\.graphify\]$' "$target" \
      && grep -q '^\[mcp_servers\.agentmemory\]$' "$target" \
       && grep -q '^\[mcp_servers\.context-mode\]$' "$target" \
       && grep -q '^\[mcp_servers\.leanctx\]$' "$target"; then
      pass "host MCP repair merges all five-tool servers for $host"
    else
      fail "host MCP repair merges all five-tool servers for $host"
    fi
  elif jq -e '.mcpServers | has("graphify") and has("agentmemory") and has("context-mode") and has("leanctx")' "$home/.claude.json" >/dev/null 2>&1; then
    pass "host MCP repair merges all five-tool servers for $host"
  else
    fail "host MCP repair merges all five-tool servers for $host"
  fi
  [[ ! -e "$home/.cursor/mcp.json" ]] \
    && pass "host MCP repair does not create Cursor config for $host" \
    || fail "host MCP repair does not create Cursor config for $host"
  rm -rf "$home" "$bin"
done

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
