#!/usr/bin/env bash
# Tests for hooks/industry-tooling-hint.sh
# Verifies the optional, config-driven industry-tooling reminders:
#   - disabled by default (no hooks.industry_tooling.enabled)
#   - emits npm audit hint when enabled + npm install without audit
#   - suppresses hint when npm audit already present
#   - emits terraform validate hint when enabled + terraform apply without validate
#   - ignores non-Bash tools
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/industry-tooling-hint.sh"
PASS=0
FAIL=0

setup() {
  TMPDIR_TEST=$(mktemp -d)
  git -C "$TMPDIR_TEST" init -q
  cat > "$TMPDIR_TEST/silver-bullet.md" <<'EOF'
# Silver Bullet
EOF
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

# Write .silver-bullet.json with industry_tooling.enabled set to $1 (true/false)
write_config() {
  local enabled="$1"
  jq -n --argjson en "$enabled" \
    '{sb_initiated: true, project: {}, hooks: {industry_tooling: {enabled: $en}}}' \
    > "$TMPDIR_TEST/.silver-bullet.json"
}

run_hook() {
  local cmd="$1" tool="${2:-Bash}"
  local input
  input=$(jq -n --arg t "$tool" --arg c "$cmd" \
    '{hook_event_name: "PreToolUse", tool_name: $t, tool_input: {command: $c}}')
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null )
}

assert_hint() {
  local label="$1" output="$2" needle="$3"
  if printf '%s' "$output" | grep -q "$needle"; then
    echo "  PASS $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL $label — expected hint containing '$needle', got: $output"
    FAIL=$((FAIL + 1))
  fi
}

assert_no_output() {
  local label="$1" output="$2"
  if [[ -z "$output" ]]; then
    echo "  PASS $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL $label — expected no output, got: $output"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== industry-tooling-hint ==="

# T1: disabled by default — even with a trigger command, no hint
setup
write_config false
printf '{}' > "$TMPDIR_TEST/package.json"
out=$(run_hook "npm install")
assert_no_output "T1: disabled config emits no hint" "$out"
teardown

# T2: enabled + npm install without audit + package.json -> npm audit hint
setup
write_config true
printf '{}' > "$TMPDIR_TEST/package.json"
out=$(run_hook "npm install")
assert_hint "T2: npm install without audit emits npm audit hint" "$out" "npm audit"
teardown

# T3: enabled + npm install WITH audit -> no hint
setup
write_config true
printf '{}' > "$TMPDIR_TEST/package.json"
out=$(run_hook "npm install && npm audit")
assert_no_output "T3: npm audit present suppresses hint" "$out"
teardown

# T4: non-Bash tool is ignored
setup
write_config true
printf '{}' > "$TMPDIR_TEST/package.json"
out=$(run_hook "npm install" "Read")
assert_no_output "T4: non-Bash tool produces no hint" "$out"
teardown

# T5: enabled + terraform apply without validate + .tf file -> terraform validate hint
setup
write_config true
printf 'resource "null_resource" "x" {}\n' > "$TMPDIR_TEST/main.tf"
out=$(run_hook "terraform apply -auto-approve")
assert_hint "T5: terraform apply without validate emits validate hint" "$out" "terraform validate"
teardown

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
