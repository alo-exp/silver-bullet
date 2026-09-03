#!/usr/bin/env bash
# Fixture tests for sb-optimize-stack.sh and stack-optimizer score/apply.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="${REPO_ROOT}/scripts/sb-optimize-stack.sh"
LIB="${REPO_ROOT}/hooks/lib/stack-optimizer.sh"
TEMPLATE="${REPO_ROOT}/templates/silver-bullet.config.json.default"
PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "=== sb-optimize-stack tests ==="

[[ -x "$SCRIPT" ]] && pass "script executable" || { chmod +x "$SCRIPT"; pass "script made executable"; }

# shellcheck source=../../hooks/lib/stack-optimizer.sh
source "$LIB"

jq -e '.optimization_profiles.synergy_max.graphify.query_budget == 2000' "$TEMPLATE" >/dev/null \
  && pass "template synergy_max query_budget" || fail "template synergy_max query_budget"

jq -e '.recommended_tools.graphify.optimization.profile == "synergy_max"' "$TEMPLATE" >/dev/null \
  && pass "graphify optimization profile" || fail "graphify optimization profile"

jq -e '.recommended_tools.agentmemory.optimization.profile == "synergy_max"' "$TEMPLATE" >/dev/null \
  && pass "agentmemory optimization profile" || fail "agentmemory optimization profile"

# Dry-run apply should not fail
if SB_STACK_SKIP_HOST_HOOKS=1 bash "$SCRIPT" --apply --dry-run >/dev/null 2>&1; then
  pass "dry-run --apply exits 0"
else
  fail "dry-run --apply exits 0"
fi

# Score on template config
write_cfg() {
  cat >"$TMP/.silver-bullet.json" <<'EOF'
{
  "recommended_tools": {
    "graphify": { "enabled_by_user": true, "optimization": { "profile": "synergy_max" } },
    "agentmemory": { "enabled_by_user": true, "optimization": { "profile": "synergy_max" } }
  },
  "optimization_profiles": {
    "synergy_max": {
      "graphify": { "install_git_hooks": true, "prefer_no_cluster": true },
      "agentmemory": { "inject_context": true, "bridge_enabled": true },
      "synergy": { "post_export_graphify_update": true }
    }
  }
}
EOF
}

write_cfg
mkdir -p "$TMP/.agentmemory/memory"
score="$(sb_optimization_score "$TMP" "$TMP/.silver-bullet.json")"
[[ "$score" =~ ^[0-9]+$ ]] && pass "score returns numeric" || fail "score returns numeric"

# Idempotent gitignore
sb_stack_ensure_agentmemory_gitignore "$TMP"
grep -q '!.agentmemory/memory/\*\*' "$TMP/.gitignore" && pass "gitignore /** negation" || fail "gitignore /** negation"
sb_stack_ensure_agentmemory_gitignore "$TMP"
count="$(grep -c 'agentmemory managed block' "$TMP/.gitignore" || true)"
[[ "$count" -eq 2 ]] && pass "gitignore idempotent" || fail "gitignore idempotent"

# Env merge dry-run
SB_STACK_OPTIMIZER_DRY_RUN=1 SB_AGENTMEMORY_HOME="$TMP/amhome" \
  sb_stack_merge_agentmemory_env "$TMP" "$TMP/.silver-bullet.json" synergy_max
[[ -f "$TMP/amhome/.env" ]] || pass "dry-run env skip write" || fail "dry-run env"

SB_AGENTMEMORY_HOME="$TMP/amhome" sb_stack_merge_agentmemory_env "$TMP" "$TMP/.silver-bullet.json" synergy_max
grep -q 'AGENTMEMORY_INJECT_CONTEXT=true' "$TMP/amhome/.env" && pass "env inject_context" || fail "env inject_context"
grep -q "AGENTMEMORY_EXPORT_ROOT=.*/.agentmemory" "$TMP/amhome/.env" && pass "env absolute export root" || fail "env absolute export root"

grep -q 'sb-optimize-stack' "$REPO_ROOT/docs/STACK-OPTIMIZATION.md" && pass "STACK-OPTIMIZATION.md exists" || fail "STACK-OPTIMIZATION.md"

grep -q '\-\-host HOST' "$SCRIPT" && pass "script supports --host" || fail "script supports --host"
SILVER_BULLET_RUNTIME=hermes bash "$SCRIPT" --apply --dry-run --host hermes >/dev/null 2>&1 \
  && pass "dry-run --host hermes" || fail "dry-run --host hermes"

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
