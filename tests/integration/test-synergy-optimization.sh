#!/usr/bin/env bash
# Integration: synergy optimize triggers graphify update path (mocked CLI).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="${REPO_ROOT}/hooks/lib/stack-optimizer.sh"
PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

MOCK_BIN="$TMP/bin"
mkdir -p "$MOCK_BIN"
cat >"$MOCK_BIN/graphify" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "update" ]]; then
  echo "graphify update $*" >>"${GRAPHIFY_MOCK_LOG:-/tmp/graphify-mock.log}"
  mkdir -p "$(dirname "${GRAPHIFY_MOCK_GRAPH:-graphify-out/graph.json}")"
  echo '{"nodes":[{"id":"n1","label":".agentmemory/memory/MOC.md"}]}' > "${GRAPHIFY_MOCK_GRAPH:-graphify-out/graph.json}"
fi
exit 0
EOF
chmod +x "$MOCK_BIN/graphify"

export PATH="$MOCK_BIN:$PATH"
export GRAPHIFY_MOCK_LOG="$TMP/graphify.log"
export GRAPHIFY_MOCK_GRAPH="$TMP/graphify-out/graph.json"

# shellcheck source=../../hooks/lib/stack-optimizer.sh
source "$LIB"

cat >"$TMP/.silver-bullet.json" <<EOF
{
  "recommended_tools": {
    "graphify": { "enabled_by_user": true, "graph_path": "graphify-out/graph.json" },
    "agentmemory": { "enabled_by_user": true, "export_root": ".agentmemory" }
  },
  "optimization_profiles": {
    "synergy_max": {
      "graphify": { "prefer_no_cluster": true },
      "synergy": { "post_export_graphify_update": true }
    }
  }
}
EOF

mkdir -p "$TMP/.agentmemory/memory"
echo "# MOC" >"$TMP/.agentmemory/memory/MOC.md"

# Mock server healthy
cat >"$MOCK_BIN/curl" <<'EOF'
#!/usr/bin/env bash
[[ "$*" == *health* ]] && exit 0
[[ "$*" == *obsidian/export* ]] && exit 0
exit 0
EOF
chmod +x "$MOCK_BIN/curl"

SB_STACK_SKIP_HOST_HOOKS=1 sb_optimize_synergy "$TMP" "$TMP/.silver-bullet.json" && pass "synergy optimize runs" || fail "synergy optimize"

grep -q 'graphify update' "$TMP/graphify.log" 2>/dev/null && pass "graphify update invoked" || fail "graphify update invoked"

sb_stack_graph_has_agentmemory_refs "$TMP" "$TMP/.silver-bullet.json" && pass "graph has agentmemory ref" || fail "graph has agentmemory ref"

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
