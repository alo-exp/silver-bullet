#!/usr/bin/env bash
# Structural tests for /silver:new-workflow meta workflow catalog registration.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"
PASS=0 FAIL=0
pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1" >&2; FAIL=$((FAIL + 1)); }

[[ -f skills/silver-new-workflow/SKILL.md ]] && pass "skill" || fail "missing skill"
grep -q 'silver:new-workflow' skills/silver/SKILL.md && pass "router" || fail "router"
grep -q 'Default target repo' skills/silver-new-workflow/SKILL.md && pass "default repo" || fail "default repo"
jq -e '.workflows[] | select(.id == "WF-SILVER-NEW-WORKFLOW")' docs/apo-catalog.json >/dev/null && pass "catalog WF" || fail "catalog WF"
bash scripts/validate-workflow-authoring.sh --slug new-workflow && pass "validate helper" || fail "validate helper"
echo "Results: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
