#!/usr/bin/env bash
# sb-diagnostics.sh against the real hooks/lib helpers in a staged repo: the
# gitleaks check must follow the tool's presence, and the stack optimization score
# must carry its critical-gap count out of sb_optimization_score.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude
cd "$TL_TMP"
unset CI SB_DIAG_SMOKE SB_DIAG_FORMAT SB_AGENTMEMORY_HOME SB_STACK_OPTIMIZER_DRY_RUN
export SB_AGENTMEMORY_HOME="$TL_TMP/amhome"

ST="$TL_TMP/stage"
mkdir -p "$ST/scripts" "$ST/hooks"
cp "$TL_REPO_ROOT/scripts/sb-diagnostics.sh" "$ST/scripts/"
ln -s "$TL_REPO_ROOT/hooks/lib" "$ST/hooks/lib"
printf '{"version":"9.9.9"}\n' >"$ST/package.json"
D="$ST/scripts/sb-diagnostics.sh"
GL_CFG='{"recommended_tools":{"agentmemory":{"enabled_by_user":true}},"optimization_profiles":{"synergy_max":{"agentmemory":{"gitleaks_required":true}}}}'

tl_stub curl 'exit 1'
tl_stub agentmemory 'case "$1" in status) echo "Health: healthy";; esac; exit 0'
mkdir -p "$ST/.agentmemory/memory"
printf '%s\n' "$GL_CFG" >"$ST/.silver-bullet.json"

# gitleaks required but not installed: warn, never "installed"
SAFE="$(tl_path_without gitleaks)"
PATH="$SAFE" tl_run bash "$D"
assert_contains "gitleaks missing is a warning" "$TL_OUT" "WARN: optimize-gitleaks — gitleaks required but missing"
assert_not_contains "gitleaks missing is not reported installed" "$TL_OUT" "PASS: optimize-gitleaks"

# gitleaks installed: pass with the path
tl_stub gitleaks 'exit 0'
tl_run bash "$D"
assert_contains "gitleaks installed passes" "$TL_OUT" "PASS: optimize-gitleaks — gitleaks installed ($TL_BIN/gitleaks)"
rm -f "$TL_BIN/gitleaks"

# graphify opted in but absent: the score has critical gaps and diagnostics fails on them
printf '{"recommended_tools":{"graphify":{"enabled_by_user":true}}}\n' >"$ST/.silver-bullet.json"
PATH="$SAFE" tl_run bash "$D"
assert_eq "critical gaps make diagnostics fail" "1" "$TL_STATUS"
assert_contains "optimize-score reports critical gaps" "$TL_OUT" "FAIL: optimize-score — stack optimization 10/100 with 2 critical gap(s)"

tl_results
