#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

pass() {
  printf 'PASS: %s\n' "$1"
  PASS=$((PASS + 1))
}

fail() {
  printf 'FAIL: %s\n' "$1"
  FAIL=$((FAIL + 1))
}

assert_file() {
  [[ -f "$REPO_ROOT/$2" ]] && pass "$1" || fail "$1"
}

assert_contains() {
  local desc="$1" file="$2" pattern="$3"
  if grep -qE "$pattern" "$REPO_ROOT/$file"; then
    pass "$desc"
  else
    fail "$desc"
  fi
}

assert_not_contains() {
  local desc="$1" file="$2" pattern="$3"
  if grep -qE "$pattern" "$REPO_ROOT/$file"; then
    fail "$desc"
  else
    pass "$desc"
  fi
}

assert_json() {
  local desc="$1" expr="$2"
  if jq -e "$expr" "$REPO_ROOT/docs/apo-catalog.json" >/dev/null; then
    pass "$desc"
  else
    fail "$desc"
  fi
}

assert_file "silver-deep-research skill exists" "skills/silver-deep-research/SKILL.md"
assert_file "search-cli docs exist" "docs/SEARCH-CLI.md"

assert_json "FS-SILVER_DEEP_RESEARCH exists" '.flow_steps[] | select(.id == "FS-SILVER_DEEP_RESEARCH")'
assert_json "FS-SILVER_RESEARCH removed" '([.flow_steps[].id] | index("FS-SILVER_RESEARCH")) == null'
assert_json "FS-SILVER_MULTI_AI removed from flow steps" '([.flow_steps[].id] | index("FS-SILVER_MULTI_AI")) == null'
assert_json "AF-DECIDE owns silver-deep-research step" '.atomic_flows[] | select(.id == "AF-DECIDE" and (.flow_steps | index("FS-SILVER_DEEP_RESEARCH")))'
assert_json "AF-DECIDE no longer owns MultAI step" '.atomic_flows[] | select(.id == "AF-DECIDE" and ((.flow_steps | index("FS-SILVER_MULTI_AI")) == null))'
assert_json "WF-SILVER-DEEP-RESEARCH exists" '.workflows[] | select(.id == "WF-SILVER-DEEP-RESEARCH")'
assert_json "WF-SILVER-RESEARCH removed" '([.workflows[].id] | index("WF-SILVER-RESEARCH")) == null'

assert_contains "DECIDE worker uses silver-deep-research" "templates/orchestrator-workers/DECIDE.md" "skills/silver-deep-research/SKILL.md"
assert_not_contains "DECIDE worker does not use silver-multi-ai" "templates/orchestrator-workers/DECIDE.md" "skills/silver-multi-ai/SKILL.md"
assert_contains "skill requires nested V-loop rollup" "skills/silver-deep-research/SKILL.md" "vloop-rollup.json"
assert_contains "skill records search-cli policy" "skills/silver-deep-research/SKILL.md" "search-cli"
assert_contains "docs explain provider recommendation policy" "docs/SEARCH-CLI.md" "provider signup/setup"
assert_contains "router uses silver:deep-research" "skills/silver/SKILL.md" "silver:deep-research"
assert_not_contains "router does not use silver:research" "skills/silver/SKILL.md" "silver:research"

printf '\nResults: %s passed, %s failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
