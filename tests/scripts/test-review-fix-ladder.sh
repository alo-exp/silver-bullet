#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RESOLVER="${REPO_ROOT}/scripts/review-fix-ladder.py"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; (( PASS++ )) || true; }
fail() { echo "FAIL: $1"; (( FAIL++ )) || true; }

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

assert_file_exists() {
  [[ -f "$1" ]] && pass "$2" || fail "$2 — missing $1"
}

assert_json_eq() {
  local desc="$1" expected="$2" actual="$3"
  if diff -u <(printf '%s\n' "$expected") <(printf '%s\n' "$actual") >/dev/null; then
    pass "$desc"
  else
    fail "$desc"
    echo "expected:"
    printf '%s\n' "$expected"
    echo "actual:"
    printf '%s\n' "$actual"
  fi
}

assert_jq_true() {
  local desc="$1" filter="$2" json="$3"
  if jq -e "$filter" >/dev/null <<<"$json"; then
    pass "$desc"
  else
    fail "$desc"
    printf '%s\n' "$json"
  fi
}

assert_jq_false() {
  local desc="$1" filter="$2" json="$3"
  if jq -e "$filter" >/dev/null <<<"$json"; then
    fail "$desc"
    printf '%s\n' "$json"
  else
    pass "$desc"
  fi
}

assert_file_exists "$RESOLVER" "review-fix-ladder.py exists"

cat > "$WORKDIR/models_cache.json" <<'EOF'
{
  "models": [
    {
      "slug": "gpt-5.4-mini",
      "visibility": "list",
      "priority": 23,
      "supported_reasoning_levels": [
        {"effort": "low"},
        {"effort": "medium"},
        {"effort": "high"},
        {"effort": "xhigh"}
      ]
    },
    {
      "slug": "gpt-5.4",
      "visibility": "list",
      "priority": 16,
      "supported_reasoning_levels": [
        {"effort": "low"},
        {"effort": "medium"},
        {"effort": "high"},
        {"effort": "xhigh"}
      ]
    },
    {
      "slug": "gpt-5.5",
      "visibility": "list",
      "priority": 9,
      "supported_reasoning_levels": [
        {"effort": "low"},
        {"effort": "medium"},
        {"effort": "high"},
        {"effort": "xhigh"}
      ]
    }
  ]
}
EOF

dynamic_json="$(python3 "$RESOLVER" --host codex --codex-home "$WORKDIR" --json)"
assert_jq_true "Codex dynamic resolves host" '.host == "codex"' "$dynamic_json"
assert_jq_true "Codex dynamic uses cache source" '.source == "dynamic"' "$dynamic_json"
assert_jq_true "Codex dynamic starts at gpt-5.4 low" '.rungs[0] == {"model":"gpt-5.4","reasoning":"low"}' "$dynamic_json"
assert_jq_false "Codex dynamic excludes gpt-5.4-mini" '[.rungs[].model] | index("gpt-5.4-mini")' "$dynamic_json"

fallback_json="$(python3 "$RESOLVER" --host codex --codex-home "$WORKDIR/missing" --json)"
assert_jq_true "Codex fallback resolves host" '.host == "codex"' "$fallback_json"
assert_jq_true "Codex fallback uses fallback source" '.source == "fallback"' "$fallback_json"
assert_jq_true "Codex fallback includes gpt-5.4 low" '.rungs[0] == {"model":"gpt-5.4","reasoning":"low"}' "$fallback_json"
assert_jq_true "Codex fallback includes gpt-5.5 xhigh" '.rungs[-1] == {"model":"gpt-5.5","reasoning":"xhigh"}' "$fallback_json"
assert_jq_false "Codex fallback excludes gpt-5.4-mini" '[.rungs[].model] | index("gpt-5.4-mini")' "$fallback_json"

claude_json="$(python3 "$RESOLVER" --host claude --json)"
assert_jq_true "Claude fallback model chain" '
  .rungs == [
    {"model":"claude-sonnet-4-6","reasoning":"medium"},
    {"model":"claude-sonnet-4-6","reasoning":"high"},
    {"model":"claude-sonnet-4-6","reasoning":"xhigh"},
    {"model":"claude-opus-4-7","reasoning":"medium"},
    {"model":"claude-opus-4-7","reasoning":"high"},
    {"model":"claude-opus-4-7","reasoning":"xhigh"},
    {"model":"claude-opus-4-8","reasoning":"medium"},
    {"model":"claude-opus-4-8","reasoning":"high"},
    {"model":"claude-opus-4-8","reasoning":"xhigh"}
  ]
' "$claude_json"

cursor_json="$(python3 "$RESOLVER" --host cursor --json)"
cursor_rungs="$(python3 -c 'import json,sys; print(len(json.load(sys.stdin)["rungs"]))' <<<"$cursor_json")"
if [[ "$cursor_rungs" == "8" ]]; then
  pass "Cursor fixed ladder has 8 rungs"
else
  fail "Cursor fixed ladder has 8 rungs — got $cursor_rungs"
fi
assert_jq_true "Cursor fixed starts composer-2.5 low" '.rungs[0] == {"model":"composer-2.5","reasoning":"low"}' "$cursor_json"
assert_jq_true "Cursor fixed ends gpt-5.5 xhigh" '.rungs[-1] == {"model":"gpt-5.5","reasoning":"xhigh","delegation":"agent-cursor","task_slug":"gpt-5.5-extra-high","agent_model":"gpt-5.5-xhigh"}' "$cursor_json"
assert_jq_true "Cursor rung 1 uses task delegation" '.rungs[0].delegation == "task"' "$cursor_json"
assert_jq_true "Cursor rung 1 task slug composer-2.5" '.rungs[0].task_slug == "composer-2.5"' "$cursor_json"
assert_jq_true "Cursor rung 5 gpt-5.5 low uses task" '.rungs[4] == {"model":"gpt-5.5","reasoning":"low","delegation":"task","task_slug":"gpt-5.5","agent_model":"gpt-5.5"}' "$cursor_json"
assert_jq_true "Cursor rung 6 gpt-5.5 medium uses agent-cursor" '.rungs[5].delegation == "agent-cursor"' "$cursor_json"
assert_jq_true "Cursor rung 6 agent model gpt-5.5-medium" '.rungs[5].agent_model == "gpt-5.5-medium"' "$cursor_json"
assert_jq_true "Cursor rung 7 agent model gpt-5.5-high" '.rungs[6].agent_model == "gpt-5.5-high"' "$cursor_json"

phase_json="$(python3 "$RESOLVER" --host cursor --json --rung 7 --phase verify_1 --work-dir /tmp/rfl --sb-root "$REPO_ROOT")"
assert_jq_true "Phase routing rung 7 verify_1 delegation agent-cursor" '.delegation == "agent-cursor"' "$phase_json"
assert_jq_true "Phase routing includes delegate_command" '.delegate_command | test("agent-cursor-delegate.sh")' "$phase_json"
assert_jq_true "Phase routing agent model gpt-5.5-high" '.agent_model == "gpt-5.5-high"' "$phase_json"

cursor_text="$(python3 "$RESOLVER" --host cursor)"
if printf '%s' "$cursor_text" | grep -q 'delegation: agent-cursor'; then
  pass "Cursor text output documents agent-cursor delegation"
else
  fail "Cursor text output documents agent-cursor delegation"
  printf '%s\n' "$cursor_text"
fi
if printf '%s' "$cursor_text" | grep -q 'agent-cursor: gpt-5.5-high'; then
  pass "Cursor text output shows gpt-5.5-high agent model"
else
  fail "Cursor text output shows gpt-5.5-high agent model"
  printf '%s\n' "$cursor_text"
fi

override_json="$(python3 "$RESOLVER" --host cursor --json)"
assert_jq_true "Host override without env selects cursor" '.host == "cursor"' "$override_json"

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
