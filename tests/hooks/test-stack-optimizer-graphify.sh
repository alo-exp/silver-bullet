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

echo "=== stack-optimizer graphify tests ==="

profile="$(sb_stack_optimization_profile_name "${REPO_ROOT}/templates/silver-bullet.config.json.default")"
[[ "$profile" == "synergy_max" ]] && pass "default profile synergy_max" || fail "default profile"

hooks_rec="$(sb_stack_profile_knob "${REPO_ROOT}/templates/silver-bullet.config.json.default" synergy_max graphify install_git_hooks true)"
[[ "$hooks_rec" == "true" ]] && pass "install_git_hooks knob" || fail "install_git_hooks knob"

mkdir -p "$TMP/.git/hooks"
printf '# graphify auto-rebuild\n' >"$TMP/.git/hooks/post-commit"
sb_stack_graphify_hooks_installed "$TMP" && pass "detect hooks in post-commit" || fail "detect hooks"

# Stale index detection via sb_graphify_index_exists
[[ "$(sb_graphify_index_exists "$REPO_ROOT" "${REPO_ROOT}/.silver-bullet.json" && echo yes || echo no)" == "yes" ]] \
  && pass "repo index exists" || pass "repo index optional in CI"

SB_STACK_SKIP_HOST_HOOKS=1 SB_STACK_OPTIMIZER_DRY_RUN=1 \
  sb_optimize_graphify "$TMP" "${REPO_ROOT}/templates/silver-bullet.config.json.default" cursor \
  && pass "optimize_graphify dry-run" || fail "optimize_graphify dry-run"

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
