#!/usr/bin/env bash
# Structural tests for scripts/run-rc-validation-matrix.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MATRIX="$REPO_ROOT/scripts/run-rc-validation-matrix.sh"
ISOLATION="$REPO_ROOT/scripts/lib/pre-release-host-isolation.sh"
PASS=0
FAIL=0

assert_pass() {
  local name="$1"
  shift
  if "$@"; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local haystack="$1" needle="$2"
  grep -F -- "$needle" >/dev/null <<<"$haystack"
}

assert_pass "rc matrix script exists" test -f "$MATRIX"
[[ -f "$MATRIX" ]] || { echo "FAIL: missing $MATRIX"; exit 1; }
chmod +x "$MATRIX"
matrix_body="$(<"$MATRIX")"
iso_body="$(<"$ISOLATION")"

assert_pass "supports --dry-run" assert_contains "$matrix_body" '--dry-run'
assert_pass "supports SB_SKIP_RC_MATRIX bypass" assert_contains "$matrix_body" 'SB_SKIP_RC_MATRIX'
assert_pass "covers cursor codex claude" assert_contains "$matrix_body" 'cursor codex claude'
assert_pass "covers fresh and upgrade modes" assert_contains "$matrix_body" 'fresh upgrade'
assert_pass "uses host-smoke-cell" assert_contains "$matrix_body" 'host-smoke-cell.sh'
assert_pass "claude host uses auth-aware live check" assert_contains "$matrix_body" 'five_tool_claude_cli_authenticated'
assert_pass "writes rc-validation markers" assert_contains "$matrix_body" 'sb_smoke_write_rc_marker'
assert_pass "isolation has sb_smoke_rc_markers_complete" assert_contains "$iso_body" 'sb_smoke_rc_markers_complete'
assert_pass "isolation has upgrade tag resolver" assert_contains "$iso_body" 'sb_smoke_resolve_previous_tag'

grep -q 'require_rc_matrix' "$REPO_ROOT/templates/silver-bullet.config.json.default"
assert_pass "config template has require_rc_matrix" test $? -eq 0

grep -q 'require_rc_matrix' "$REPO_ROOT/hooks/completion-audit.sh"
assert_pass "completion-audit reads require_rc_matrix" test $? -eq 0

grep -q 'rc-validation' "$REPO_ROOT/hooks/lib/completion-audit/deploy-tier.sh"
assert_pass "deploy-tier enforces rc-validation markers" test $? -eq 0

test -f "$REPO_ROOT/.github/workflows/rc-validation.yml"
assert_pass "rc-validation workflow exists" test $? -eq 0

workflow_body="$(<"$REPO_ROOT/.github/workflows/rc-validation.yml")"
assert_pass "workflow is optional non-blocking" assert_contains "$workflow_body" 'continue-on-error: true'
assert_pass "workflow sets SB_RC_CI_MODE" assert_contains "$workflow_body" 'SB_RC_CI_MODE=1'
assert_not_contains() {
  local haystack="$1" needle="$2"
  ! grep -F -- "$needle" >/dev/null <<<"$haystack"
}

assert_pass "workflow excludes ANTHROPIC_API_KEY" assert_not_contains "$workflow_body" 'ANTHROPIC_API_KEY'
assert_pass "matrix supports SB_RC_CI_MODE" assert_contains "$matrix_body" 'RC_CI_MODE'
assert_pass "matrix skips codex/claude live in CI" assert_contains "$matrix_body" 'ci-no-first-party-keys'
assert_pass "deploy-tier mentions operator-local RC" assert_contains "$(<"$REPO_ROOT/hooks/lib/completion-audit/deploy-tier.sh")" 'operator-local'

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
