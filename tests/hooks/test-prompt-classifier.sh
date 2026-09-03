#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=hooks/lib/prompt-classifier.sh
source "$REPO_ROOT/hooks/lib/prompt-classifier.sh"

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "=== prompt-classifier.sh tests ==="

if sb_prompt_is_informational_query "What are the remaining deliverables?"; then
  pass "informational deliverables question"
else
  fail "informational deliverables question"
fi

if ! sb_prompt_is_bare_work_request "What are the remaining deliverables?"; then
  pass "informational not bare work"
else
  fail "informational not bare work"
fi

if sb_prompt_is_bare_work_request "fix the login bug and add tests"; then
  pass "bare work request still detected"
else
  fail "bare work request still detected"
fi

if sb_prompt_is_orchestrator_followup "yes, proceed with option 2"; then
  pass "orchestrator follow-up detected"
else
  fail "orchestrator follow-up detected"
fi

if ! sb_prompt_is_orchestrator_followup "fix the login bug and add regression tests"; then
  pass "substantive prompt not follow-up"
else
  fail "substantive prompt not follow-up"
fi

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] || exit 1
