#!/usr/bin/env bash
# Regression tests for one user-global five-tool executable registry shared by
# Cursor, Claude, and Codex MCP adapters.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PATCH_MCP="$REPO_ROOT/scripts/lib/global-toolstack/patch-mcp.py"
TMP_HOME="$(mktemp -d)"
TMP_BIN="$(mktemp -d)"
TMP_BIN_REAL="$(cd "$TMP_BIN" && pwd -P)"
cleanup() {
  rm -rf "$TMP_HOME" "$TMP_BIN"
}
trap cleanup EXIT

mkdir -p "$TMP_HOME/.cursor" "$TMP_HOME/.codex"

for tool in graphify-mcp agentmemory context-mode lean-ctx rtk; do
  printf '#!/usr/bin/env bash\nexit 0\n' >"$TMP_BIN/$tool"
  chmod +x "$TMP_BIN/$tool"
done
printf '#!/usr/bin/env bash\nexit 0\n' >"$TMP_BIN/npx"
chmod +x "$TMP_BIN/npx"

# Seed executable legacy selections to prove the resolver will not promote a
# host-local plugin path or an npx shim into the shared global profile.
LEGACY_GRAPHIFY="$TMP_HOME/.cursor/plugins/cache/alo-labs/silver-bullet/current/bin/graphify-mcp"
mkdir -p "$(dirname "$LEGACY_GRAPHIFY")" "$TMP_HOME/.silver-bullet/five-tool-stack"
printf '#!/usr/bin/env bash\nexit 0\n' >"$LEGACY_GRAPHIFY"
chmod +x "$LEGACY_GRAPHIFY"
printf '%s\n' "{
  \"schema\": \"v1\",
  \"scope\": \"user-global\",
  \"profile\": \"five_tool_routed\",
  \"tools\": {
    \"graphify\": {\"command\": \"$LEGACY_GRAPHIFY\", \"args\": []},
    \"agentmemory\": {\"command\": \"$TMP_BIN_REAL/npx\", \"args\": [\"-y\", \"@agentmemory/mcp\"]}
  }
}" >"$TMP_HOME/.silver-bullet/five-tool-stack/instances.json"

printf '%s\n' '{
  "mcpServers": {
    "graphify": {"command": "old-graphify", "args": []},
    "agentmemory": {"command": "npx", "args": ["-y", "@agentmemory/mcp"], "env": {"KEEP": "yes"}},
    "context-mode": {"command": "context-mode"},
    "user-context-mode": {"command": "legacy-context-mode"},
    "leanctx": {"command": "lean-ctx", "args": []}
  }
}' >"$TMP_HOME/.cursor/mcp.json"
cp "$TMP_HOME/.cursor/mcp.json" "$TMP_HOME/.claude.json"
printf '%s\n' '[mcp_servers.graphify]
command = "old-graphify"
args = []

[mcp_servers.agentmemory]
command = "npx"
args = ["-y", "@agentmemory/mcp"]

[mcp_servers.agentmemory.env]
KEEP = "yes"

[mcp_servers.context-mode]
command = "context-mode"

[mcp_servers.leanctx]
command = "lean-ctx"
args = []
' >"$TMP_HOME/.codex/config.toml"

run_patch() {
  local host="$1"
  HOME="$TMP_HOME" CODEX_HOME="$TMP_HOME/.codex" PATH="$TMP_BIN:$PATH" \
    SB_GLOBAL_TOOLSTACK_HOME="$TMP_HOME/.silver-bullet/five-tool-stack" \
    RT_HOST="$host" RT_PATCH_GRAPHIFY=1 RT_PATCH_AGENTMEMORY=1 RT_PATCH_CONTEXT_MODE=1 RT_PATCH_LEANCTX=1 \
    python3 "$PATCH_MCP" >/dev/null
}

for host in cursor claude codex; do
  run_patch "$host"
done

for host in cursor claude codex; do
  HOME="$TMP_HOME" CODEX_HOME="$TMP_HOME/.codex" \
    SB_GLOBAL_TOOLSTACK_HOME="$TMP_HOME/.silver-bullet/five-tool-stack" \
    python3 "$REPO_ROOT/scripts/lib/merge-leanctx-mcp-config.py" --host "$host" >/dev/null
done

MANIFEST="$TMP_HOME/.silver-bullet/five-tool-stack/instances.json"
test -f "$MANIFEST"

for tool in graphify agentmemory context_mode leanctx rtk; do
  expected="$TMP_BIN_REAL/graphify-mcp"
  case "$tool" in
    agentmemory) expected="$TMP_BIN_REAL/agentmemory" ;;
    context_mode) expected="$TMP_BIN_REAL/context-mode" ;;
    leanctx) expected="$TMP_BIN_REAL/lean-ctx" ;;
    rtk) expected="$TMP_BIN_REAL/rtk" ;;
  esac
  actual="$(jq -r ".tools.$tool.command" "$MANIFEST")"
  [[ "$actual" == "$expected" ]] || {
    printf 'manifest command mismatch for %s: expected %s, got %s\n' "$tool" "$expected" "$actual" >&2
    exit 1
  }
done

jq -e '
  .schema == "v1"
  and .scope == "user-global"
  and .profile == "five_tool_routed"
  and .tools.agentmemory.args == ["mcp"]
  and .tools.graphify.args == ["--transport", "stdio"]
  and .tools.leanctx.args == ["mcp"]
  and .tools.agentmemory.env.AGENTMEMORY_URL == "http://localhost:3111"
' "$MANIFEST" >/dev/null

for host_file in "$TMP_HOME/.cursor/mcp.json" "$TMP_HOME/.claude.json"; do
  jq -e --arg graphify "$TMP_BIN_REAL/graphify-mcp" \
    --arg agentmemory "$TMP_BIN_REAL/agentmemory" \
    --arg context_mode "$TMP_BIN_REAL/context-mode" \
    --arg leanctx "$TMP_BIN_REAL/lean-ctx" '
    .mcpServers.graphify.command == $graphify
    and .mcpServers.graphify.args == ["--transport", "stdio"]
    and .mcpServers.agentmemory.command == $agentmemory
    and .mcpServers.agentmemory.args == ["mcp"]
    and .mcpServers.agentmemory.env.AGENTMEMORY_URL == "http://localhost:3111"
    and .mcpServers["context-mode"].command == $context_mode
    and .mcpServers.leanctx.command == $leanctx
    and .mcpServers.leanctx.args == ["mcp"]
    and ([.mcpServers | keys[] | select(test("context-mode"))] | length) == 1
  ' "$host_file" >/dev/null
done

CODEX_CONFIG="$TMP_HOME/.codex/config.toml"
grep -Fq "command = \"$TMP_BIN_REAL/graphify-mcp\"" "$CODEX_CONFIG"
grep -Fq 'args = ["--transport", "stdio"]' "$CODEX_CONFIG"
grep -Fq "command = \"$TMP_BIN_REAL/agentmemory\"" "$CODEX_CONFIG"
grep -Fq 'args = ["mcp"]' "$CODEX_CONFIG"
grep -Fq 'AGENTMEMORY_URL = "http://localhost:3111"' "$CODEX_CONFIG"
grep -Fq "command = \"$TMP_BIN_REAL/context-mode\"" "$CODEX_CONFIG"
grep -Fq "command = \"$TMP_BIN_REAL/lean-ctx\"" "$CODEX_CONFIG"
! grep -Fq '[mcp_servers.lean-ctx]' "$CODEX_CONFIG"

mkdir -p "$TMP_HOME/.cursor/hooks/toolstack"
for hook in shell-compression.sh stack-compression-coordinator.sh rtk-gate.sh token-compression-tools-gate.sh; do
  printf '#!/usr/bin/env bash\nexit 0\n' >"$TMP_HOME/.cursor/hooks/toolstack/$hook"
  chmod +x "$TMP_HOME/.cursor/hooks/toolstack/$hook"
done
printf '%s\n' '{"hooks":{"preToolUse":[{"command":"rtk hook cursor","matcher":"Shell"},{"command":"bash /old/.cursor/hooks/toolstack/shell-compression.sh","matcher":"Shell"},{"command":"/old/.cursor/plugins/cache/alo-labs/silver-bullet/current/hooks/cursor-hook-bridge.sh preToolUse /old/.cursor/plugins/cache/alo-labs/silver-bullet/current/hooks/leanctx-gate.sh","matcher":"Shell"},{"command":"context-mode hook cursor pretooluse","matcher":"Read"},{"command":"context-mode hook cursor pretooluse","matcher":"Grep"}],"postToolUse":[{"command":"/old/.cursor/plugins/cache/alo-labs/silver-bullet/current/hooks/cursor-hook-bridge.sh postToolUse /old/.cursor/plugins/cache/alo-labs/silver-bullet/current/hooks/record-agentmemory-usage.sh","matcher":"MCP"}]}}' >"$TMP_HOME/.cursor/hooks.json"
HOME="$TMP_HOME" PATH="$TMP_BIN:$PATH" \
  SB_GLOBAL_TOOLSTACK_HOME="$TMP_HOME/.silver-bullet/five-tool-stack" RT_PATCH_RTK=1 \
  python3 "$REPO_ROOT/scripts/lib/global-toolstack/patch-hooks.py" >/dev/null
jq -e --arg rtk "$TMP_BIN_REAL/rtk" \
  '.hooks.preToolUse | any(.[]; .command == ($rtk + " hook cursor"))' \
  "$TMP_HOME/.cursor/hooks.json" >/dev/null
! jq -e '.hooks.preToolUse[] | select(.command | contains("shell-compression.sh"))' \
  "$TMP_HOME/.cursor/hooks.json" >/dev/null
! jq -e '.hooks | to_entries[] | .value[] | select(.command | contains("cursor-hook-bridge.sh")) | select(.command | test("leanctx-gate|record-agentmemory-usage"))' \
  "$TMP_HOME/.cursor/hooks.json" >/dev/null
[[ "$(jq '[.hooks.preToolUse[] | select((.command | contains("context-mode")) and (.command | contains("hook cursor pretooluse")))] | length' "$TMP_HOME/.cursor/hooks.json")" -eq 1 ]]
jq -e '.hooks.preToolUse[] | select((.command | contains("context-mode")) and (.command | contains("hook cursor pretooluse"))) | .matcher | contains("Read") and contains("Grep")' "$TMP_HOME/.cursor/hooks.json" >/dev/null

before="$(shasum -a 256 "$TMP_HOME/.cursor/mcp.json" "$TMP_HOME/.claude.json" "$TMP_HOME/.codex/config.toml" "$MANIFEST")"
for host in cursor claude codex; do
  run_patch "$host"
done
after="$(shasum -a 256 "$TMP_HOME/.cursor/mcp.json" "$TMP_HOME/.claude.json" "$TMP_HOME/.codex/config.toml" "$MANIFEST")"
[[ "$before" == "$after" ]] || {
  printf 'global five-tool patch is not byte-idempotent\n' >&2
  exit 1
}

printf 'PASS: global five-tool instances are shared and idempotent across Cursor, Claude, and Codex\n'
printf 'Results: 1 passed, 0 failed\n'
