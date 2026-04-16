#!/usr/bin/env bash
# Tests for hooks/ensure-model-routing.sh
# Hook is DISABLED (2026-04-16) — frontmatter injection into GSD agent files
# is discontinued. Tests verify the hook is a safe no-op in all scenarios.

set -euo pipefail

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/ensure-model-routing.sh"
PASS=0
FAIL=0

# ── Helpers ───────────────────────────────────────────────────────────────────

assert_pass() {
  local label="$1"
  echo "  PASS: $label"
  PASS=$((PASS + 1))
}

assert_fail() {
  local label="$1"
  local reason="$2"
  echo "  FAIL: $label — $reason"
  FAIL=$((FAIL + 1))
}

assert_file_not_contains() {
  local label="$1"
  local path="$2"
  local needle="$3"
  if ! grep -q "$needle" "$path" 2>/dev/null; then
    assert_pass "$label"
  else
    assert_fail "$label" "expected '$needle' NOT in $path"
  fi
}

assert_exit_zero() {
  local label="$1"
  local exit_code="$2"
  if [[ "$exit_code" -eq 0 ]]; then
    assert_pass "$label"
  else
    assert_fail "$label" "exit code was $exit_code, expected 0"
  fi
}

# ── Setup helper ──────────────────────────────────────────────────────────────
make_fake_home() {
  FAKE_HOME="$(mktemp -d)"
  FAKE_AGENTS_DIR="${FAKE_HOME}/.claude/agents"
  FAKE_SB_DIR="${FAKE_HOME}/.claude/.silver-bullet"
  mkdir -p "$FAKE_AGENTS_DIR" "$FAKE_SB_DIR"
}

make_agent_file() {
  local path="$1"
  local extra="${2:-}"
  {
    echo "---"
    echo "name: $(basename "$path" .md)"
    echo "description: Test agent"
    if [[ -n "$extra" ]]; then
      echo "$extra"
    fi
    echo "---"
    echo ""
    echo "Body content here."
  } > "$path"
}

run_hook() {
  local fake_home="$1"
  HOME="$fake_home" bash "$HOOK" 2>/dev/null
  echo $?
}

cleanup_fake_home() {
  [[ -n "${FAKE_HOME:-}" ]] && rm -rf "$FAKE_HOME" || true
}

trap cleanup_fake_home EXIT

# ── Tests ─────────────────────────────────────────────────────────────────────
echo "=== ensure-model-routing.sh tests (hook DISABLED) ==="

# ── S1: Hook exits 0 and makes no modifications when canary is stale ──────────
# Previously this scenario verified patching ran. Now the hook is a no-op.
echo "--- S1: Canary stale -> no-op (hook disabled) ---"
make_fake_home

make_agent_file "${FAKE_AGENTS_DIR}/gsd-planner.md"
make_agent_file "${FAKE_AGENTS_DIR}/gsd-security-auditor.md"
make_agent_file "${FAKE_AGENTS_DIR}/gsd-executor.md"

before_planner=$(cat "${FAKE_AGENTS_DIR}/gsd-planner.md")
exit_code=$(run_hook "$FAKE_HOME")

assert_exit_zero "S1: hook exits 0 when canary stale" "$exit_code"

after_planner=$(cat "${FAKE_AGENTS_DIR}/gsd-planner.md")
if [[ "$before_planner" == "$after_planner" ]]; then
  assert_pass "S1: gsd-planner.md not modified (no-op)"
else
  assert_fail "S1: gsd-planner.md not modified (no-op)" "file was unexpectedly modified"
fi

assert_file_not_contains "S1: no model: line injected into gsd-planner.md" \
  "${FAKE_AGENTS_DIR}/gsd-planner.md" "^model:"
assert_file_not_contains "S1: no model: line injected into gsd-security-auditor.md" \
  "${FAKE_AGENTS_DIR}/gsd-security-auditor.md" "^model:"
assert_file_not_contains "S1: no model: line injected into gsd-executor.md" \
  "${FAKE_AGENTS_DIR}/gsd-executor.md" "^model:"

cleanup_fake_home

# ── S2: Hook exits 0 when canary is already correct ──────────────────────────
echo "--- S2: Canary fresh -> exits 0 (no-op) ---"
make_fake_home

make_agent_file "${FAKE_AGENTS_DIR}/gsd-planner.md" "model: opus"
make_agent_file "${FAKE_AGENTS_DIR}/gsd-executor.md"

before_planner=$(cat "${FAKE_AGENTS_DIR}/gsd-planner.md")
before_executor=$(cat "${FAKE_AGENTS_DIR}/gsd-executor.md")

exit_code=$(run_hook "$FAKE_HOME")
assert_exit_zero "S2: hook exits 0 when canary fresh" "$exit_code"

after_planner=$(cat "${FAKE_AGENTS_DIR}/gsd-planner.md")
after_executor=$(cat "${FAKE_AGENTS_DIR}/gsd-executor.md")

if [[ "$before_planner" == "$after_planner" ]]; then
  assert_pass "S2: gsd-planner.md not modified"
else
  assert_fail "S2: gsd-planner.md not modified" "checksum changed"
fi

if [[ "$before_executor" == "$after_executor" ]]; then
  assert_pass "S2: gsd-executor.md not modified"
else
  assert_fail "S2: gsd-executor.md not modified" "checksum changed"
fi

cleanup_fake_home

# ── S3: Hook exits 0 when agents dir is missing ───────────────────────────────
echo "--- S3: agents dir missing -> exits 0 ---"
make_fake_home
rm -rf "${FAKE_AGENTS_DIR}"

exit_code=$(run_hook "$FAKE_HOME")
assert_exit_zero "S3: hook exits 0 when agents dir missing" "$exit_code"

cleanup_fake_home

# ── S4: Non-gsd-*.md files are not touched ───────────────────────────────────
echo "--- S4: non-gsd-*.md files are not processed ---"
make_fake_home

make_agent_file "${FAKE_AGENTS_DIR}/gsd-planner.md"
cat > "${FAKE_AGENTS_DIR}/my-custom-agent.md" << 'EOF'
---
name: my-custom-agent
description: custom agent (not gsd-prefixed)
---
Body.
EOF
before_custom=$(cat "${FAKE_AGENTS_DIR}/my-custom-agent.md")

exit_code=$(run_hook "$FAKE_HOME")
assert_exit_zero "S4: hook exits 0 with non-gsd file present" "$exit_code"

after_custom=$(cat "${FAKE_AGENTS_DIR}/my-custom-agent.md")
if [[ "$before_custom" == "$after_custom" ]]; then
  assert_pass "S4: non-gsd-*.md file not touched"
else
  assert_fail "S4: non-gsd-*.md file not touched" "file was unexpectedly modified"
fi

cleanup_fake_home

# ── S5: Existing model: lines in agent files are not changed ──────────────────
# Previously this verified replacement behavior. Now no modification occurs.
echo "--- S5: existing model: line not modified (hook disabled) ---"
make_fake_home

make_agent_file "${FAKE_AGENTS_DIR}/gsd-planner.md"
make_agent_file "${FAKE_AGENTS_DIR}/gsd-executor.md" "model: haiku"

before_executor=$(cat "${FAKE_AGENTS_DIR}/gsd-executor.md")

exit_code=$(run_hook "$FAKE_HOME")
assert_exit_zero "S5: hook exits 0" "$exit_code"

after_executor=$(cat "${FAKE_AGENTS_DIR}/gsd-executor.md")
if [[ "$before_executor" == "$after_executor" ]]; then
  assert_pass "S5: gsd-executor.md not modified (model: haiku preserved)"
else
  assert_fail "S5: gsd-executor.md not modified" "file was unexpectedly modified"
fi

cleanup_fake_home

# ── Results ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
