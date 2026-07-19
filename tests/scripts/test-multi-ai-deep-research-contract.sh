#!/usr/bin/env bash
# Contract tests for multi-AI task + DR-multi-AI registration (Phase 6).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"
PASS=0 FAIL=0
pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1" >&2; FAIL=$((FAIL + 1)); }

assert_file() { [[ -f "$REPO_ROOT/$1" ]] && pass "$1 exists" || fail "missing $1"; }

assert_file "skills/silver-multi-ai-task/SKILL.md"
assert_file "skills/silver-deep-research-multi-ai/SKILL.md"
assert_file "skills/silver-multi-ai-task/reference/model-family-registry-v1.json"
assert_file "skills/silver-deep-research-multi-ai/schemas/run-manifest-v4.schema.json"

grep -q 'multi-ai-task-v2' skills/silver-multi-ai-task/SKILL.md && pass "primitive spine documented" || fail "primitive spine"
grep -q 'WF-SILVER-DEEP-RESEARCH-MULTI-AI' skills/silver-deep-research-multi-ai/SKILL.md && pass "composer workflow id" || fail "composer workflow id"

jq -e '[.workflows[].id] | length > 0' docs/apo-catalog.json >/dev/null && pass "workflows non-empty" || fail "workflow count"
jq -e '(.atomic_flows | map(.id) | unique | length) == (.atomic_flows | length)' docs/apo-catalog.json >/dev/null && pass "atomic flow ids unique" || fail "atomic flow ids"
jq -e '(.flow_steps | map(.id) | unique | length) == (.flow_steps | length)' docs/apo-catalog.json >/dev/null && pass "flow step ids unique" || fail "flow step ids"

jq -e '.workflows[] | select(.id == "WF-SILVER-MULTI-AI-TASK")' docs/apo-catalog.json >/dev/null && pass "WF-SILVER-MULTI-AI-TASK" || fail "WF-SILVER-MULTI-AI-TASK"
jq -e '.workflows[] | select(.id == "WF-SILVER-DEEP-RESEARCH-MULTI-AI")' docs/apo-catalog.json >/dev/null && pass "WF-SILVER-DEEP-RESEARCH-MULTI-AI" || fail "WF-SILVER-DEEP-RESEARCH-MULTI-AI"
jq -e '.atomic_flows[] | select(.id == "AF-MULTI-AI-TASK")' docs/apo-catalog.json >/dev/null && pass "AF-MULTI-AI-TASK" || fail "AF-MULTI-AI-TASK"

for step in FS-MULTI-AI-RESOLVE FS-MULTI-AI-CAPABILITY-PROBE FS-MULTI-AI-RESERVE FS-MULTI-AI-DISPATCH FS-MULTI-AI-RECONCILE FS-MULTI-AI-INDEX FS-SILVER_MULTI_AI_TASK FS-SILVER_DEEP_RESEARCH_MULTI_AI; do
  jq -e --arg s "$step" '.flow_steps[] | select(.id == $s)' docs/apo-catalog.json >/dev/null && pass "$step registered" || fail "$step missing"
done

python3 skills/silver-multi-ai-task/scripts/multi_ai_cli.py --output-root /tmp/sb-mat-contract --dry-run >/dev/null && pass "multi-ai dry-run cli" || fail "multi-ai dry-run cli"
python3 skills/silver-deep-research-multi-ai/scripts/dr_multi_ai_cli.py "contract probe" --dry-run >/dev/null && pass "dr-multi-ai dry-run cli" || fail "dr-multi-ai dry-run cli"

python3 -m unittest discover -s skills/silver-multi-ai-task/tests -p 'test_*.py' -q && pass "multi-ai unit tests" || fail "multi-ai unit tests"
python3 -m unittest discover -s skills/silver-deep-research-multi-ai/tests -p 'test_*.py' -q && pass "dr-multi-ai unit tests" || fail "dr-multi-ai unit tests"

bash tests/scripts/test-multi-ai-opencode-mode.sh && pass "ocg multi-ai-worker mode" || fail "ocg multi-ai-worker mode"
test -f skills/silver-multi-ai-task/scripts/cursor_host_adapter.py && pass "cursor host adapter stub" || fail "cursor host adapter stub"
test -f skills/silver-multi-ai-task/schemas/backend-capabilities-v1.schema.json && pass "backend-capabilities schema" || fail "backend-capabilities schema"
test -f skills/silver-deep-research-multi-ai/scripts/migrate_run_manifest.py && pass "manifest migration script" || fail "manifest migration script"

REG="$REPO_ROOT/skills/silver-multi-ai-task/reference/model-family-registry-v1.json"
jq -e '(.ocg_lite_pool | length) >= 1 and (.ocg_regular_pool | length) >= 1' "$REG" >/dev/null && pass "ocg registry pools present" || fail "ocg registry pools"

echo "Results: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
