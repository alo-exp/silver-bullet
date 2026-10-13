#!/usr/bin/env bash
# Regression test: Claude always uses the shared Context Mode MCP executable.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOME_FIXTURE="$(mktemp -d)"
PROJECT_FIXTURE="$(mktemp -d)"
FALLBACK_HOME="$(mktemp -d)"
FALLBACK_BIN="$(mktemp -d)"
FALLBACK_BIN_REAL="$(cd "$FALLBACK_BIN" && pwd -P)"
trap 'rm -rf "$HOME_FIXTURE" "$PROJECT_FIXTURE" "$FALLBACK_HOME" "$FALLBACK_BIN"' EXIT

mkdir -p "$HOME_FIXTURE/.claude/plugins/cache/context-mode/context-mode"
printf '{"mcpServers":{"user-context-mode":{"command":"old-context-mode"}}}\n' >"$HOME_FIXTURE/.claude.json"
printf '{"enabledPlugins":{"context-mode@context-mode":true}}\n' >"$HOME_FIXTURE/.claude/settings.json"
printf '{"sb_initiated":true}\n' >"$PROJECT_FIXTURE/.silver-bullet.json"

for tool in graphify-mcp agentmemory context-mode lean-ctx rtk; do
  printf '#!/usr/bin/env bash\nexit 0\n' >"$FALLBACK_BIN/$tool"
  chmod +x "$FALLBACK_BIN/$tool"
done
export CLAUDE_DISABLE_MARKER="$HOME_FIXTURE/claude-context-mode-disabled"
printf '#!/usr/bin/env bash\n: >"$CLAUDE_DISABLE_MARKER"\n' >"$FALLBACK_BIN/claude"
chmod +x "$FALLBACK_BIN/claude"

if HOME="$HOME_FIXTURE" PATH="$FALLBACK_BIN:$PATH" RT_HOST=claude \
  RT_PATCH_CONTEXT_MODE=1 RT_PATCH_LEANCTX=1 \
  SB_GLOBAL_TOOLSTACK_HOME="$HOME_FIXTURE/.silver-bullet/five-tool-stack" \
  python3 "$REPO_ROOT/scripts/lib/global-toolstack/patch-mcp.py" >/dev/null \
  && jq -e --arg command "$FALLBACK_BIN_REAL/context-mode" '
    .mcpServers["context-mode"].command == $command
    and .mcpServers["context-mode"].args == []
    and (.mcpServers | has("user-context-mode") | not)
    and .mcpServers.leanctx.env.LEANCTX_MCP_TOOL_PREFIX == "lctx_"
    and .mcpServers.leanctx.env.LEANCTX_DISABLE_SHELL_MCP == "1"
    and .mcpServers.leanctx.env.LEANCTX_DISABLE_SANDBOX_MCP == "1"
    and .mcpServers.leanctx.env.LEANCTX_DISABLE_FETCH_MCP == "1"
    and .mcpServers.leanctx.env.LEANCTX_DISABLE_FTS == "1"
  ' "$HOME_FIXTURE/.claude.json" >/dev/null; then
  if [[ -f "$CLAUDE_DISABLE_MARKER" ]]; then
    echo "PASS: Claude uses shared Context Mode and disables native plugin"
  else
    echo "FAIL: Claude did not disable enabled native plugin"
    exit 1
  fi
else
  echo "FAIL: Claude should use shared Context Mode MCP when native plugin cache exists"
  exit 1
fi

if HOME="$HOME_FIXTURE" PATH="$FALLBACK_BIN:$PATH" RT_HOST=claude \
  RT_PATCH_CONTEXT_MODE=1 RT_PATCH_LEANCTX=1 \
  SB_GLOBAL_TOOLSTACK_HOME="$HOME_FIXTURE/.silver-bullet/five-tool-stack" \
  python3 "$REPO_ROOT/scripts/lib/global-toolstack/patch-mcp.py" >/dev/null; then
  echo "PASS: shared Claude Context Mode patch is idempotent"
else
  echo "FAIL: shared Claude Context Mode patch is not idempotent"
  exit 1
fi

printf '#!/usr/bin/env bash\nexit 0\n' >"$FALLBACK_BIN/context-mode"
chmod +x "$FALLBACK_BIN/context-mode"
mkdir -p "$FALLBACK_HOME/.claude"
printf '{"mcpServers":{}}\n' >"$FALLBACK_HOME/.claude.json"
if HOME="$FALLBACK_HOME" PATH="$FALLBACK_BIN:$PATH" RT_HOST=claude \
  RT_PATCH_CONTEXT_MODE=1 \
  SB_GLOBAL_TOOLSTACK_HOME="$FALLBACK_HOME/.silver-bullet/five-tool-stack" \
  python3 "$REPO_ROOT/scripts/lib/global-toolstack/patch-mcp.py" >/dev/null \
  && jq -e --arg command "$FALLBACK_BIN_REAL/context-mode" \
    '.mcpServers["context-mode"].command == $command and .mcpServers["context-mode"].args == []' \
    "$FALLBACK_HOME/.claude.json" >/dev/null; then
  echo "PASS: Claude fallback uses shared manifest Context Mode executable"
else
  echo "FAIL: Claude fallback uses shared manifest Context Mode executable"
  exit 1
fi

echo "Results: 3 passed, 0 failed"
