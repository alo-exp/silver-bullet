# --- D10 five-tool default-path coverage ---
# Keep vendor doctor skipped for the historical cases above, then exercise it
# explicitly in this block.
export RT_SKIP_VENDOR_DOCTOR="${RT_SKIP_VENDOR_DOCTOR:-1}"

D10_HOME="$(mktemp -d)"
D10_PROJ="$(mktemp -d)"
D10_BIN="$(mktemp -d)"
mkdir -p "${D10_HOME}/.cursor"
export HOME="$D10_HOME"
cp "$TEMPLATE" "${D10_PROJ}/.silver-bullet.json"
printf '# SB\n' >"${D10_PROJ}/silver-bullet.md"
git -C "$D10_PROJ" init -q
printf '{"mcpServers":{}}\n' >"${D10_HOME}/.cursor/mcp.json"
printf '{"hooks":{"preToolUse":[]}}\n' >"${D10_HOME}/.cursor/hooks.json"

d10_enable() {
  local tool="$1"
  jq --arg t "$tool" '.recommended_tools[$t].enabled_by_user = true | .sb_initiated = true' \
    "${D10_PROJ}/.silver-bullet.json" >"${D10_PROJ}/.silver-bullet.json.tmp"
  mv "${D10_PROJ}/.silver-bullet.json.tmp" "${D10_PROJ}/.silver-bullet.json"
}

d10_probe() {
  local script="$1"
  local fn="$2"
  RT_PROJECT_ROOT="$D10_PROJ" RT_HOST=cursor RT_MODE=verify RT_REPO_ROOT="$REPO_ROOT" \
    HOME="$D10_HOME" PATH="${D10_BIN}:${PATH}" \
    bash -c '
      set -euo pipefail
      # shellcheck source=/dev/null
      source "$1/scripts/lib/recommended-tools/common.sh"
      rt_init_paths
      # shellcheck source=/dev/null
      source "$1/scripts/lib/recommended-tools/'"$script"'"
      '"$fn"'
    ' _ "$REPO_ROOT"
}

# Graphify: CLI + graphify-mcp present, MCP server key missing
d10_enable graphify
printf '#!/usr/bin/env bash\nexit 0\n' >"${D10_BIN}/graphify"
printf '#!/usr/bin/env bash\nexit 0\n' >"${D10_BIN}/graphify-mcp"
chmod +x "${D10_BIN}/graphify" "${D10_BIN}/graphify-mcp"
gfy_json="$(d10_probe probe-graphify.sh rt_probe_graphify 2>/dev/null || true)"
echo "$gfy_json" | jq -e '.evidence | index("mcp_not_configured") != null' >/dev/null 2>&1 \
  && pass "D10 graphify FAILs when MCP server missing" \
  || fail "D10 graphify FAILs when MCP server missing (${gfy_json:-empty})"

# agentmemory: CLI present, health endpoint down
d10_enable agentmemory
printf '#!/usr/bin/env bash\nexit 0\n' >"${D10_BIN}/agentmemory"
chmod +x "${D10_BIN}/agentmemory"
am_json="$(d10_probe probe-agentmemory.sh rt_probe_agentmemory 2>/dev/null || true)"
echo "$am_json" | jq -e '.evidence | (index("server_unhealthy") != null or index("cli_missing") != null)' >/dev/null 2>&1 \
  && pass "D10 agentmemory FAILs when health is down" \
  || fail "D10 agentmemory FAILs when health is down (${am_json:-empty})"

# RTK: CLI looks valid, cursor hook missing
d10_enable rtk
cat >"${D10_BIN}/rtk" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  gain) exit 0 ;;
  --version) echo "rtk 0.42.0"; exit 0 ;;
  doctor) echo "no doctor"; exit 2 ;;
  --help) echo "rtk hook helper"; exit 0 ;;
  *) exit 0 ;;
esac
EOF
chmod +x "${D10_BIN}/rtk"
rtk_json="$(d10_probe probe-rtk.sh rt_probe_rtk 2>/dev/null || true)"
echo "$rtk_json" | jq -e '.evidence | index("shell_hook_missing") != null' >/dev/null 2>&1 \
  && pass "D10 rtk FAILs when cursor hook missing" \
  || fail "D10 rtk FAILs when cursor hook missing (${rtk_json:-empty})"

# LeanCTX: duplicate leanctx + lean-ctx MCP keys
d10_enable leanctx
printf '#!/usr/bin/env bash\nexit 0\n' >"${D10_BIN}/lean-ctx"
chmod +x "${D10_BIN}/lean-ctx"
cat >"${D10_HOME}/.cursor/mcp.json" <<'EOF'
{
  "mcpServers": {
    "leanctx": {
      "command": "lean-ctx",
      "env": {
        "LEANCTX_MCP_TOOL_PREFIX": "lctx_",
        "LEANCTX_DISABLE_SHELL_MCP": "1",
        "LEANCTX_DISABLE_SANDBOX_MCP": "1",
        "LEANCTX_DISABLE_FETCH_MCP": "1",
        "LEANCTX_DISABLE_FTS": "1"
      }
    },
    "lean-ctx": { "command": "lean-ctx" }
  }
}
EOF
lc_json="$(d10_probe probe-leanctx.sh rt_probe_leanctx 2>/dev/null || true)"
echo "$lc_json" | jq -e '.evidence | index("duplicate_mcp_keys") != null' >/dev/null 2>&1 \
  && pass "D10 leanctx FAILs on duplicate leanctx+lean-ctx MCP keys" \
  || fail "D10 leanctx FAILs on duplicate MCP keys (${lc_json:-empty})"

# Context Mode: vendor doctor on the default (non --deep) path
unset RT_SKIP_VENDOR_DOCTOR
d10_enable context_mode
printf '{"mcpServers":{"context-mode":{"command":"context-mode"}}}\n' >"${D10_HOME}/.cursor/mcp.json"
cat >"${D10_PROJ}/silver-bullet.md" <<'EOF'
# SB
<!-- BEGIN context-mode hint (do not edit) -->
Use ctx_execute, ctx_index, ctx_search, ctx_batch_execute instead of raw dumps.
<!-- END context-mode hint (do not edit) -->
EOF
CM_STAMP="${D10_HOME}/cm-doctor.stamp"
: >"$CM_STAMP"
cat >"${D10_BIN}/context-mode" <<EOF
#!/usr/bin/env bash
if [[ "\$1" == "doctor" ]]; then
  echo invoked >> "${CM_STAMP}"
  exit \${CM_DOCTOR_RC:-0}
fi
exit 0
EOF
chmod +x "${D10_BIN}/context-mode"
export CM_DOCTOR_RC=1
cm_json="$(d10_probe probe-context-mode.sh rt_probe_context_mode 2>/dev/null || true)"
echo "$cm_json" | jq -e '.evidence | index("vendor_doctor_failed") != null' >/dev/null 2>&1 \
  && pass "D10 context_mode FAILs when vendor doctor fails on default path" \
  || fail "D10 context_mode FAILs when vendor doctor fails (${cm_json:-empty})"
if grep -q invoked "$CM_STAMP"; then
  pass "D10 context-mode doctor invoked without --deep"
else
  fail "D10 context-mode doctor invoked without --deep"
fi
export CM_DOCTOR_RC=0
: >"$CM_STAMP"
cm_ok="$(d10_probe probe-context-mode.sh rt_probe_context_mode 2>/dev/null || true)"
echo "$cm_ok" | jq -e '.evidence | index("vendor_doctor_failed") == null' >/dev/null 2>&1 \
  && pass "D10 context_mode passes vendor doctor on default path" \
  || fail "D10 context_mode passes vendor doctor (${cm_ok:-empty})"
export RT_SKIP_VENDOR_DOCTOR=1
rm -rf "$D10_HOME" "$D10_PROJ" "$D10_BIN"
export HOME="$TEST_HOME"
