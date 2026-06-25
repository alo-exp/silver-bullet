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
assert_jq_true "Cursor fixed ends gpt-5.5 xhigh" '.rungs[-1] == {"model":"gpt-5.5","reasoning":"xhigh"}' "$cursor_json"
cursor_text="$(python3 "$RESOLVER" --host cursor)"
if printf '%s' "$cursor_text" | grep -q 'gpt-5.5-medium'; then
  fail "Cursor ladder omits rejected gpt-5.5-medium slug"
else
  pass "Cursor ladder omits rejected gpt-5.5-medium slug"
fi
if printf '%s' "$cursor_text" | grep -q 'gpt-5.5-high'; then
  fail "Cursor ladder omits rejected gpt-5.5-high slug"
else
  pass "Cursor ladder omits rejected gpt-5.5-high slug"
fi
if printf '%s' "$cursor_text" | grep -q 'gpt-5.5 / medium (cursor slug: gpt-5.5-extra-high)'; then
  pass "Cursor ladder substitutes medium with extra-high slug"
else
  fail "Cursor ladder substitutes medium with extra-high slug"
  printf '%s\n' "$cursor_text"
fi
if printf '%s' "$cursor_text" | grep -q 'gpt-5.5 / high (cursor slug: gpt-5.5-extra-high)'; then
  pass "Cursor ladder substitutes high with extra-high slug"
else
  fail "Cursor ladder substitutes high with extra-high slug"
  printf '%s\n' "$cursor_text"
fi

override_json="$(python3 "$RESOLVER" --host cursor --json)"
assert_jq_true "Host override without env selects cursor" '.host == "cursor"' "$override_json"

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
