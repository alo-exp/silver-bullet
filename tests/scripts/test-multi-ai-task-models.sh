#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RESOLVER="${REPO_ROOT}/scripts/multi-ai-task-models.py"
LADDER="${REPO_ROOT}/scripts/review-fix-ladder.py"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; (( PASS++ )) || true; }
fail() { echo "FAIL: $1"; (( FAIL++ )) || true; }

assert_jq_true() {
  local desc="$1" filter="$2" json="$3"
  if jq -e "$filter" >/dev/null <<<"$json"; then
    pass "$desc"
  else
    fail "$desc"
    printf '%s\n' "$json"
  fi
}

[[ -f "$RESOLVER" ]] && pass "multi-ai-task-models.py exists" || fail "multi-ai-task-models.py exists"

cursor_json="$(python3 "$RESOLVER" --host cursor --json)"
assert_jq_true "cursor plan resolves" '.host == "cursor"' "$cursor_json"
assert_jq_true "cursor uses medium only" '[.models[].reasoning] | all(. == "medium")' "$cursor_json"
assert_jq_true "cursor includes composer-2.5 medium" '[.models[] | select(.model == "composer-2.5")] | length >= 1' "$cursor_json"

claude_json="$(python3 "$RESOLVER" --host claude --json)"
assert_jq_true "claude sonnet medium present" '[.models[] | select(.model == "claude-sonnet-4-6" and .reasoning == "medium")] | length == 1' "$claude_json"

# OCG-Lite profile
lite_json="$(python3 "$RESOLVER" --host cursor --json --lite)"
assert_jq_true "lite plan is ocg-lite" '.plan == "ocg-lite"' "$lite_json"
assert_jq_true "lite still medium only" '[.models[].reasoning] | all(. == "medium")' "$lite_json"

# Synthetic OCG fixture: verify lite mapping when OCG models present
ocg_fixture="$(mktemp -d)"
trap 'rm -rf "$ocg_fixture"' EXIT
cat >"${ocg_fixture}/opencode.json" <<'EOF'
{
  "agent": {
    "ocg-minimax-m3": { "mode": "subagent", "model": "opencode-go/minimax-m3" },
    "ocg-qwen": { "mode": "subagent", "model": "opencode-go/qwen3.7-max" },
    "ocg-deepseek": { "mode": "subagent", "model": "opencode-go/deepseek-v4-pro" },
    "ocg-glm": { "mode": "subagent", "model": "opencode-go/glm-5.2" },
    "ocg-kimi": { "mode": "subagent", "model": "opencode-go/kimi-k2.6" },
    "ocg-mimo": { "mode": "subagent", "model": "opencode-go/mimo-v2.5-pro" }
  }
}
EOF
ocg_json="$(OPENCODE_CONFIG_DIR="$ocg_fixture" python3 "$RESOLVER" --host cursor --json)"
assert_jq_true "ocg fixture uses ocg-primary" '.plan == "ocg-primary"' "$ocg_json"
assert_jq_true "ocg fixture has 6 models" '[.models[] | select(.source == "ocg-config")] | length == 6' "$ocg_json"

ocg_lite_json="$(OPENCODE_CONFIG_DIR="$ocg_fixture" python3 "$RESOLVER" --host cursor --json --lite)"
assert_jq_true "ocg-lite fixture plan" '.plan == "ocg-lite"' "$ocg_lite_json"
assert_jq_true "ocg-lite maps qwen to plus" '[.models[] | select(.model == "opencode-go/qwen3.7-plus")] | length == 1' "$ocg_lite_json"
assert_jq_true "ocg-lite maps deepseek to flash" '[.models[] | select(.model == "opencode-go/deepseek-v4-flash")] | length == 1' "$ocg_lite_json"
assert_jq_true "ocg-lite excludes glm-5.2" '[.models[] | select(.model == "opencode-go/glm-5.2")] | length == 0' "$ocg_lite_json"
assert_jq_true "ocg-lite maps kimi to k2.7-code" '[.models[] | select(.model == "opencode-go/kimi-k2.7-code")] | length == 1' "$ocg_lite_json"
assert_jq_true "ocg-lite maps mimo to v2.5" '[.models[] | select(.model == "opencode-go/mimo-v2.5")] | length == 1' "$ocg_lite_json"
assert_jq_true "ocg-lite keeps minimax-m3" '[.models[] | select(.model == "opencode-go/minimax-m3")] | length == 1' "$ocg_lite_json"
assert_jq_true "ocg-lite has 5 ocg models after exclusion" '[.models[] | select(.source == "ocg-lite")] | length == 5' "$ocg_lite_json"

# Claude bundle exposes silver: prefix route
if grep -qE '^name: silver:multi-ai$' "${REPO_ROOT}/agents/claude/silver:multi-ai/SKILL.md" 2>/dev/null; then
  pass "Claude bundle exposes silver:multi-ai"
else
  fail "Claude bundle exposes silver:multi-ai (run sync-codex-package.sh)"
fi

if grep -qE '^name: silver-multi-ai$' "${REPO_ROOT}/skills/silver-multi-ai/SKILL.md"; then
  pass "authoring skill keeps silver-multi-ai source name"
else
  fail "authoring skill keeps silver-multi-ai source name"
fi

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
