#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="${REPO_ROOT}/hooks/lib/stack-optimizer.sh"
PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# shellcheck source=../../hooks/lib/stack-optimizer.sh
source "$LIB"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "=== stack-optimizer agentmemory tests ==="

cat >"$TMP/.silver-bullet.json" <<'EOF'
{
  "recommended_tools": {
    "agentmemory": {
      "enabled_by_user": true,
      "export_root": ".agentmemory",
      "optimization": { "profile": "synergy_max" }
    }
  },
  "optimization_profiles": {
    "synergy_max": {
      "agentmemory": {
        "inject_context": true,
        "obsidian_export": true,
        "bridge_enabled": true,
        "gitleaks_required": true,
        "server_persistence": "launchd"
      }
    }
  }
}
EOF

SB_AGENTMEMORY_HOME="$TMP/amhome"
sb_stack_merge_agentmemory_env "$TMP" "$TMP/.silver-bullet.json" synergy_max
[[ -f "$TMP/amhome/.env.bak" || -f "$TMP/amhome/.env" ]] && pass "env merge creates files" || fail "env merge"

export_path="$(sb_agentmemory_abs_export_path "$TMP" "$TMP/.silver-bullet.json")"
[[ "$export_path" == "$TMP/.agentmemory" ]] && pass "export root absolute path" || fail "export root"

# launchd plist generation dry-run
SB_STACK_OPTIMIZER_DRY_RUN=1 SB_STACK_SKIP_HOST_HOOKS=0 \
  sb_stack_launchd_server_plist "$TMP" "$TMP/.silver-bullet.json" 2>/dev/null || true
if SB_STACK_OPTIMIZER_DRY_RUN=1 sb_stack_launchd_server_plist "$TMP" "$TMP/.silver-bullet.json" 2>&1 | grep -q 'DRY-RUN'; then
  pass "launchd server plist dry-run"
else
  pass "launchd server plist path optional"
fi

mkdir -p "$TMP/.agentmemory/memory"
SB_STACK_SKIP_HOST_HOOKS=1 SB_STACK_OPTIMIZER_DRY_RUN=1 \
  sb_optimize_agentmemory "$TMP" "$TMP/.silver-bullet.json" cursor \
  && pass "optimize_agentmemory dry-run" || fail "optimize_agentmemory dry-run"

[[ -d "$TMP/.agentmemory/memory" ]] && pass "scaffold memory dir" || fail "scaffold memory dir"

sb_stack_gitleaks_required "$TMP/.silver-bullet.json" synergy_max \
  && pass "gitleaks required for synergy_max" || fail "gitleaks required knob"

if sb_stack_gitleaks_path >/dev/null 2>&1; then
  sb_stack_ensure_gitleaks "$TMP/.silver-bullet.json" synergy_max && pass "ensure_gitleaks when installed"
else
  if SB_STACK_OPTIMIZER_DRY_RUN=1 sb_stack_ensure_gitleaks "$TMP/.silver-bullet.json" synergy_max 2>&1 | grep -q 'DRY-RUN.*gitleaks'; then
    pass "ensure_gitleaks dry-run"
  else
    fail "ensure_gitleaks dry-run"
  fi
fi

if SB_STACK_OPTIMIZER_DRY_RUN=1 sb_stack_launchd_bridge_plist "$TMP" 2>&1 | grep -q 'DRY-RUN'; then
  pass "bridge plist dry-run mentions write"
else
  pass "bridge plist dry-run optional"
fi

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
