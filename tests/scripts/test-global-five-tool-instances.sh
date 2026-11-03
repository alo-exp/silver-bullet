#!/usr/bin/env bash
# Regression tests for one user-global five-tool executable registry shared by
# Claude, Codex, OpenCode, and Pi adapters.
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

mkdir -p "$TMP_HOME/.claude" "$TMP_HOME/.codex" "$TMP_HOME/.config/opencode" "$TMP_HOME/.pi/agent"

# Give the OpenCode plugin projection a package root so the test can prove the
# native plugin is loaded from the same manifest-selected Context Mode install.
TMP_CONTEXT_ROOT="$TMP_BIN_REAL/context-mode-package"
mkdir -p "$TMP_CONTEXT_ROOT/build/adapters/opencode"
printf '#!/usr/bin/env bash\nexit 0\n' >"$TMP_CONTEXT_ROOT/cli.bundle.mjs"
chmod +x "$TMP_CONTEXT_ROOT/cli.bundle.mjs"
printf 'export default {}\n' >"$TMP_CONTEXT_ROOT/build/adapters/opencode/plugin.js"

for tool in graphify-mcp agentmemory context-mode lean-ctx rtk; do
  printf '#!/usr/bin/env bash\nexit 0\n' >"$TMP_BIN/$tool"
  chmod +x "$TMP_BIN/$tool"
done
printf '#!/usr/bin/env bash\nexit 0\n' >"$TMP_BIN/npx"
chmod +x "$TMP_BIN/npx"

# Seed executable legacy selections to prove the resolver will not promote a
# host-local plugin path or an npx shim into the shared global profile.
LEGACY_GRAPHIFY="$TMP_HOME/.claude/plugins/cache/alo-labs/silver-bullet/current/bin/graphify-mcp"
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
}' >"$TMP_HOME/.claude.json"
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

printf '%s\n' '{
  "mcp": {
    "graphify": {"type":"local","command":["old-graphify"]},
    "agentmemory": {"type":"local","command":["npx","-y","@agentmemory/mcp"],"environment":{"KEEP":"yes"}},
    "context-mode": {"type":"local","command":["context-mode"]},
    "user-context-mode": {"type":"local","command":["legacy-context-mode"]},
    "leanctx": {"type":"local","command":["lean-ctx"]}
  },
  "plugin": []
}' >"$TMP_HOME/.config/opencode/opencode.json"

run_patch() {
  local host="$1"
  HOME="$TMP_HOME" CODEX_HOME="$TMP_HOME/.codex" PATH="$TMP_BIN:$PATH" \
    PI_CODING_AGENT_DIR="$TMP_HOME/.pi/agent" \
    SB_GLOBAL_TOOLSTACK_HOME="$TMP_HOME/.silver-bullet/five-tool-stack" \
    SB_GLOBAL_CONTEXT_MODE_COMMAND="$TMP_CONTEXT_ROOT/cli.bundle.mjs" \
    RT_HOST="$host" RT_PATCH_GRAPHIFY=1 RT_PATCH_AGENTMEMORY=1 RT_PATCH_CONTEXT_MODE=1 RT_PATCH_LEANCTX=1 \
    python3 "$PATCH_MCP" >/dev/null
}

for host in claude codex opencode pi; do
  run_patch "$host"
done

for host in claude codex opencode; do
  HOME="$TMP_HOME" CODEX_HOME="$TMP_HOME/.codex" \
    SB_GLOBAL_TOOLSTACK_HOME="$TMP_HOME/.silver-bullet/five-tool-stack" \
    SB_GLOBAL_CONTEXT_MODE_COMMAND="$TMP_CONTEXT_ROOT/cli.bundle.mjs" \
    python3 "$REPO_ROOT/scripts/lib/merge-leanctx-mcp-config.py" --host "$host" >/dev/null
done

OPENCODE_CONFIG="$TMP_HOME/.config/opencode/opencode.json"
jq -e --arg graphify "$TMP_BIN_REAL/graphify-mcp" \
  --arg agentmemory "$TMP_BIN_REAL/agentmemory" \
  --arg context_plugin "file://$TMP_CONTEXT_ROOT/build/adapters/opencode/plugin.js" \
  --arg leanctx "$TMP_BIN_REAL/lean-ctx" '
  .mcp.graphify.command == [$graphify, "--transport", "stdio"]
  and .mcp.agentmemory.command == [$agentmemory, "mcp"]
  and .mcp.agentmemory.environment.AGENTMEMORY_URL == "http://localhost:3111"
  and (.plugin | any(.[]?; . == $context_plugin))
  and ([.mcp | keys[] | select(test("context-mode"))] | length) == 0
  and .mcp.leanctx.command == [$leanctx, "mcp"]
' "$OPENCODE_CONFIG" >/dev/null

PI_CONFIG="$TMP_HOME/.pi/agent/extensions/silver-bullet-five-tool-stack/config.json"
PI_LEANCTX_CONFIG="$TMP_HOME/.pi/agent/extensions/pi-lean-ctx/config.json"
PI_SETTINGS="$TMP_HOME/.pi/agent/settings.json"
jq -e '
  .schema == "v1"
  and .profile == "five_tool_routed"
  and ([.servers | to_entries[] | select(.value.enabled == true)] | length) == 4
  and .servers.graphify.enabled
  and .servers.agentmemory.enabled
  and .servers.context_mode.enabled
  and .servers.leanctx.enabled
  and (.servers.rtk.enabled == false)
' "$PI_CONFIG" >/dev/null
jq -e --arg leanctx "$TMP_BIN_REAL/lean-ctx" \
  '.routeShell == false and .enableMcp == true and (.disableTools | index("ctx_shell")) != null and .binary == $leanctx' \
  "$PI_LEANCTX_CONFIG" >/dev/null
jq -e '(.extensions | any(endswith("/extensions/silver-bullet-five-tool-stack"))) and ((.packages | map(select(contains("pi-lean-ctx"))) | length) == 1)' \
  "$PI_SETTINGS" >/dev/null

pi_leanctx_before="$(shasum -a 256 "$PI_LEANCTX_CONFIG")"
HOME="$TMP_HOME" PI_CODING_AGENT_DIR="$TMP_HOME/.pi/agent" \
  SB_GLOBAL_TOOLSTACK_HOME="$TMP_HOME/.silver-bullet/five-tool-stack" \
  SB_GLOBAL_CONTEXT_MODE_COMMAND="$TMP_CONTEXT_ROOT/cli.bundle.mjs" \
  python3 "$REPO_ROOT/scripts/lib/global-toolstack/install-pi.py" --enable-tool rtk >/dev/null
pi_leanctx_after="$(shasum -a 256 "$PI_LEANCTX_CONFIG")"
[[ "$pi_leanctx_before" == "$pi_leanctx_after" ]] || {
  printf 'selective Pi adapter install unexpectedly rewrote pi-lean-ctx config\n' >&2
  exit 1
}

MANIFEST="$TMP_HOME/.silver-bullet/five-tool-stack/instances.json"
test -f "$MANIFEST"

for tool in graphify agentmemory context_mode leanctx rtk; do
  expected="$TMP_BIN_REAL/graphify-mcp"
  case "$tool" in
    agentmemory) expected="$TMP_BIN_REAL/agentmemory" ;;
    context_mode) expected="$TMP_CONTEXT_ROOT/cli.bundle.mjs" ;;
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
  .schema == "five-tool-stack/v1"
  and .scope == "user-global"
  and .profile == "five_tool_routed"
  and .tools.agentmemory.args == ["mcp"]
  and .tools.graphify.args == ["--transport", "stdio"]
  and .tools.leanctx.args == ["mcp"]
  and .tools.agentmemory.env.AGENTMEMORY_URL == "http://localhost:3111"
' "$MANIFEST" >/dev/null

host_file="$TMP_HOME/.claude.json"
  jq -e --arg graphify "$TMP_BIN_REAL/graphify-mcp" \
    --arg agentmemory "$TMP_BIN_REAL/agentmemory" \
    --arg context_mode "$TMP_CONTEXT_ROOT/cli.bundle.mjs" \
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

CODEX_CONFIG="$TMP_HOME/.codex/config.toml"
grep -Fq "command = \"$TMP_BIN_REAL/graphify-mcp\"" "$CODEX_CONFIG"
grep -Fq 'args = ["--transport", "stdio"]' "$CODEX_CONFIG"
grep -Fq "command = \"$TMP_BIN_REAL/agentmemory\"" "$CODEX_CONFIG"
grep -Fq 'args = ["mcp"]' "$CODEX_CONFIG"
grep -Fq 'AGENTMEMORY_URL = "http://localhost:3111"' "$CODEX_CONFIG"
grep -Fq "command = \"$TMP_CONTEXT_ROOT/cli.bundle.mjs\"" "$CODEX_CONFIG"
grep -Fq "command = \"$TMP_BIN_REAL/lean-ctx\"" "$CODEX_CONFIG"
! grep -Fq '[mcp_servers.lean-ctx]' "$CODEX_CONFIG"

before="$(shasum -a 256 "$TMP_HOME/.claude.json" "$TMP_HOME/.codex/config.toml" "$OPENCODE_CONFIG" "$PI_CONFIG" "$PI_LEANCTX_CONFIG" "$PI_SETTINGS" "$MANIFEST")"
for host in claude codex opencode pi; do
  run_patch "$host"
done
after="$(shasum -a 256 "$TMP_HOME/.claude.json" "$TMP_HOME/.codex/config.toml" "$OPENCODE_CONFIG" "$PI_CONFIG" "$PI_LEANCTX_CONFIG" "$PI_SETTINGS" "$MANIFEST")"
[[ "$before" == "$after" ]] || {
  printf 'global five-tool patch is not byte-idempotent\n' >&2
  exit 1
}

printf 'PASS: global five-tool instances are shared and idempotent across Claude, Codex, OpenCode, and Pi\n'
printf 'Results: 1 passed, 0 failed\n'
