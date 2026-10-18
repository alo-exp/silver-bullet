#!/usr/bin/env bash
# hooks/lib/prompt-classifier.sh: prompt classification predicates.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=../../hooks/lib/prompt-classifier.sh
source "$TL_REPO_ROOT/hooks/lib/prompt-classifier.sh"

yes_() { # fn prompt label
  if "$1" "$2"; then tl_pass "$3"; else tl_fail "$3 (expected true for [$2])"; fi
}
no_() {
  if "$1" "$2"; then tl_fail "$3 (expected false for [$2])"; else tl_pass "$3"; fi
}

assert_eq "trim" "a b" "$(sb_prompt_trim $'  \t a b  \n')"

# informational
no_ sb_prompt_is_informational_query "" "empty is not informational"
no_ sb_prompt_is_informational_query "/sb:status what are the gates" "slash commands are never informational"
no_ sb_prompt_is_informational_query "sb:plan what is the plan" "sb: prefix is never informational"
no_ sb_prompt_is_informational_query "ask @silver what is next" "@silver mention is never informational"
yes_ sb_prompt_is_informational_query "status of the migration" "status phrase"
yes_ sb_prompt_is_informational_query "What are the remaining deliverables?" "informational deliverables question"
yes_ sb_prompt_is_informational_query "How does this work" "question word"
no_ sb_prompt_is_informational_query "fix the login bug" "work request is not informational"

# follow-ups
no_ sb_prompt_is_orchestrator_followup "" "empty is not a follow-up"
yes_ sb_prompt_is_orchestrator_followup "User directive: go on" "user directive prefix"
yes_ sb_prompt_is_orchestrator_followup "yes please" "short affirmative"
yes_ sb_prompt_is_orchestrator_followup "yes, proceed with option 2" "orchestrator follow-up detected"
no_ sb_prompt_is_orchestrator_followup "fix the login bug and add regression tests" "substantive prompt not follow-up"
yes_ sb_prompt_is_orchestrator_followup "2) the second" "numbered choice"
no_ sb_prompt_is_orchestrator_followup "yes but then please also rework the whole authentication module and the billing flow today" "long reply is not a follow-up"
no_ sb_prompt_is_orchestrator_followup "implement search" "non-affirmative"

# bare work requests
no_ sb_prompt_is_bare_work_request "" "empty"
no_ sb_prompt_is_bare_work_request "what are the pending gates" "informational"
no_ sb_prompt_is_bare_work_request "What are the remaining deliverables?" "informational not bare work"
yes_ sb_prompt_is_bare_work_request "fix the login bug and add tests" "bare work request still detected"
no_ sb_prompt_is_bare_work_request "/sb:fix the bug now" "slash command"
no_ sb_prompt_is_bare_work_request "sb:fix the bug now" "sb: prefix"
no_ sb_prompt_is_bare_work_request "ask @silver to fix it" "@silver"
no_ sb_prompt_is_bare_work_request 'run `sb:fix` for me' "backticked skill"
no_ sb_prompt_is_bare_work_request "explain how to fix this" "explain question form"
no_ sb_prompt_is_bare_work_request "fix it" "too short"
yes_ sb_prompt_is_bare_work_request "please fix the failing login test" "work verb"
no_ sb_prompt_is_bare_work_request "the weather looks nice today" "no work verb"

# the question-form guard still holds when the informational helper is unavailable
if ( unset -f sb_prompt_is_informational_query; sb_prompt_is_bare_work_request "explain how to fix this" ); then
  tl_fail "question form rejected without the informational helper"
else
  tl_pass "question form rejected without the informational helper"
fi

# delivery adjacent
no_ sb_prompt_is_delivery_adjacent "" "empty"
yes_ sb_prompt_is_delivery_adjacent "ship it" "ship"
yes_ sb_prompt_is_delivery_adjacent "open a PR for this" "pr"
no_ sb_prompt_is_delivery_adjacent "continue implementing the parser" "development prompt"

tl_results
