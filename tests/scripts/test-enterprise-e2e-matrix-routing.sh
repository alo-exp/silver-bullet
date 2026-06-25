#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

assert_ok() {
  local desc="$1"
  shift
  if "$@"; then
    echo "PASS: $desc"
    ((PASS++)) || true
  else
    echo "FAIL: $desc"
    ((FAIL++)) || true
  fi
}

assert_fail() {
  local desc="$1"
  shift
  if "$@"; then
    echo "FAIL: $desc — expected failure"
    ((FAIL++)) || true
  else
    echo "PASS: $desc"
    ((PASS++)) || true
  fi
}

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMPDIR="${TMPDIR:-/tmp}"
STATE_DIR="$(mktemp -d "${TMPDIR}/sb-matrix-routing.XXXXXX")"
trap 'rm -rf "$STATE_DIR"' EXIT

export HOME="$STATE_DIR/home"
mkdir -p "$HOME/.claude/.silver-bullet"
STATE_FILE="$HOME/.claude/.silver-bullet/state"
ROUTING_STATE_SNAPSHOT=""

# shellcheck source=tests/e2e-live/lib/skill-prompt.sh
source "${REPO_ROOT}/tests/e2e-live/lib/skill-prompt.sh"

build_matrix_prompt() {
  local route="$1"
  local prompt_card="$2"
  local evidence_path="$3"
  local row_num="${4:-}"
  if [[ "$row_num" == "1" ]]; then
    printf '%s %s Enterprise E2E routing validation only. Route this request through the Silver Bullet orchestrator and invoke the composed workflow skill. Stop when routing completes.' \
      "$route" "$prompt_card"
    return 0
  fi
  matrix_route_prompt "$route" "$prompt_card" "$evidence_path" ""
}

claude_routing_state_file() {
  printf '%s\n' "${HOME}/.claude/.silver-bullet/state"
}

snapshot_routing_state() {
  local state_file
  state_file="$(claude_routing_state_file)"
  if [[ -f "$state_file" ]]; then
    ROUTING_STATE_SNAPSHOT="$(cat "$state_file")"
  else
    ROUTING_STATE_SNAPSHOT=""
  fi
}

verify_row_routing_state_delta() {
  local state_file new_skills
  state_file="$(claude_routing_state_file)"
  [[ -f "$state_file" ]] || return 1
  new_skills="$(comm -13 \
    <(printf '%s\n' "$ROUTING_STATE_SNAPSHOT" | sed '/^$/d' | sort -u) \
    <(sed '/^$/d' "$state_file" | sort -u) 2>/dev/null || true)"
  [[ -n "$new_skills" ]] || return 1
  printf '%s\n' "$new_skills" | grep -qE '^(silver-feature|silver-fast|silver-clarify|silver-context|silver-quality-gates)$'
}

row1_prompt="$(build_matrix_prompt '/silver' 'I need to add order validation to the API — route me.' '.planning/workflows/router-session.md' '1')"
if [[ "$row1_prompt" == *"routing validation only"* && "$row1_prompt" != *"Create workflow evidence"* ]]; then
  echo "PASS: row 1 prompt is routing-only"
  ((PASS++)) || true
else
  echo "FAIL: row 1 prompt is routing-only"
  ((FAIL++)) || true
fi

printf 'silver-context\n' >"$STATE_FILE"
snapshot_routing_state
printf 'silver-context\nsilver-feature\n' >"$STATE_FILE"
assert_ok "detects new routing skill in state delta" verify_row_routing_state_delta

snapshot_routing_state
printf 'silver-context\nsilver-unknown\n' >"$STATE_FILE"
assert_fail "rejects unrelated new skill names" verify_row_routing_state_delta

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
