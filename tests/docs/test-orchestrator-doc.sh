#!/usr/bin/env bash
# docs/ORCHESTRATOR.md must describe what the hooks do (review finding R4-27):
#  - it must not tell authors to put SB_ORCHESTRATOR_WORKER=1 in Task prompts (the hooks call
#    that a dead, spoofable line);
#  - it must not present removed helpers (event resume, saga) as runtime APIs;
#  - every sb_* function it names in backticks must exist in hooks/lib.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
DOC="$TL_REPO_ROOT/docs/ORCHESTRATOR.md"
LIB="$TL_REPO_ROOT/hooks/lib"

if grep -q 'Workers should run with `SB_ORCHESTRATOR_WORKER=1`' "$DOC"; then
  tl_fail "doc still instructs setting SB_ORCHESTRATOR_WORKER=1 in worker prompts"
else
  tl_pass "doc does not instruct setting SB_ORCHESTRATOR_WORKER=1 in worker prompts"
fi
assert_contains "doc explains how worker identity is decided" "$(cat "$DOC")" "agent_id"
assert_contains "doc has the parent Bash policy" "$(cat "$DOC")" "### Parent Bash"
assert_contains "doc says the parent may run strictly read-only commands" "$(cat "$DOC")" "strictly read-only"
for removed in sb_orchestrator_saga_begin sb_orchestrator_saga_complete sb_orchestrator_saga_rollback_hint sb_orchestrator_event_resume_hints_json sb_orchestrator_event_apply_resume_checkpoint orchestrator-saga.json; do
  if grep -q "$removed" "$DOC"; then
    tl_fail "doc still lists removed API $removed"
  else
    tl_pass "doc does not list removed API $removed"
  fi
done
for fn in $(grep -oE '`(sb_[a-z_]+)`' "$DOC" | tr -d '`' | sort -u); do
  if grep -rqE "^_?${fn}\(\)" "$LIB"; then
    tl_pass "documented function exists: $fn"
  else
    tl_fail "doc names $fn but hooks/lib defines no such function"
  fi
done
lines="$(wc -l <"$DOC" | tr -d ' ')"
assert_eq "doc stays under the 500-line limit" 1 "$(( lines < 500 ? 1 : 0 ))"
tl_results
