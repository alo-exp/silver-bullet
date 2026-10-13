#!/usr/bin/env bash
# Regression: heavy Shell hooks must not duplicate onto beforeShellExecution/afterShellExecution.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; ((PASS++)) || true; }
fail() { echo "FAIL: $1"; ((FAIL++)) || true; }

if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP: python3 required"
  exit 0
fi

python3 "$REPO_ROOT/scripts/generate-cursor-hooks.py" >/dev/null

CURSOR_HOOKS="$REPO_ROOT/hooks/cursor-hooks.json"
PLUGIN_HOOKS="$REPO_ROOT/plugins/silver-bullet/cursor-hooks.json"

for path in "$CURSOR_HOOKS" "$PLUGIN_HOOKS"; do
  if [[ ! -f "$path" ]]; then
    fail "missing generated hooks file: $path"
    continue
  fi
done

# Hooks that must never appear on shell execution events (pre/post ToolUse Shell is authoritative).
HEAVY_SKIP_PATTERNS=(
  "dev-cycle-check.sh"
  "completion-audit.sh"
  "stack-compression-coordinator.sh"
  "ci-status-check.sh"
  "site-regression-gate.sh"
  "-gate.sh"
  "-guard.sh"
)

check_hooks_file() {
  local path="$1"
  local label
  label="$(basename "$(dirname "$path")")/$(basename "$path")"

  local shell_dup_count
  shell_dup_count="$(jq '[.hooks.beforeShellExecution[]?, .hooks.afterShellExecution[]?] | length' "$path")"
  if [[ "$shell_dup_count" -eq 0 ]]; then
    pass "$label: no shell-execution hook duplicates"
  else
    fail "$label: expected zero shell-execution duplicates (found $shell_dup_count)"
  fi

  for pattern in "${HEAVY_SKIP_PATTERNS[@]}"; do
    local hits
    hits="$(jq --arg p "$pattern" '[.hooks.beforeShellExecution[]?, .hooks.afterShellExecution[]? | select(.command | contains($p))] | length' "$path")"
    if [[ "$hits" -eq 0 ]]; then
      pass "$label: shell events skip $pattern"
    else
      fail "$label: shell events must not list $pattern (found $hits)"
    fi
  done

  local pre_count post_count
  pre_count="$(jq '[.hooks.preToolUse[]? | select(.command | contains("dev-cycle-check.sh"))] | length' "$path")"
  post_count="$(jq '[.hooks.postToolUse[]? | select(.command | contains("dev-cycle-check.sh"))] | length' "$path")"
  if [[ "$pre_count" -eq 1 ]]; then
    pass "$label: preToolUse retains single dev-cycle-check hook"
  else
    fail "$label: preToolUse should have exactly one dev-cycle-check (found $pre_count)"
  fi
  if [[ "$post_count" -eq 1 ]]; then
    pass "$label: postToolUse retains single dev-cycle-check hook"
  else
    fail "$label: postToolUse should have exactly one dev-cycle-check (found $post_count)"
  fi

  local global_stack_hits
  global_stack_hits="$(jq '[.hooks | to_entries[] | .value[]? | select(.command | test("(graphify-gate|agentmemory-gate|leanctx-gate|stack-compression-coordinator|context-mode-read-deny|rtk-gate|context-mode-gate|token-compression-tools-gate|record-graphify-query|record-agentmemory-usage)\\.sh"))] | length' "$path")"
  if [[ "$global_stack_hits" -eq 0 ]]; then
    pass "$label: plugin manifest leaves global five-tool hooks to global stack"
  else
    fail "$label: plugin manifest must omit global five-tool hooks (found $global_stack_hits)"
  fi
}

for path in "$CURSOR_HOOKS" "$PLUGIN_HOOKS"; do
  [[ -f "$path" ]] && check_hooks_file "$path"
done

echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
