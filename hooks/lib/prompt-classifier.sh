#!/usr/bin/env bash
# Lightweight prompt classification shared by UserPromptSubmit hooks.

sb_prompt_trim() {
  local text="$1"
  printf '%s' "$text" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'
}

# Work-intent verbs (shared by the informational and bare-work classifiers).
_SB_PROMPT_WORK_VERBS='add|build|change|create|cut|debug|deploy|document|fix|implement|improve|investigate|migrate|publish|refactor|release|research|review|ship|test|update|validate|verify'

# Informational / status questions — answer directly; do not compose full SB chains.
#
# R2-19: classify on the FIRST non-blank line with patterns anchored at its start, and only call
# a prompt informational when nothing in it asks for work: no list items, no work verb on the
# later lines, no `... and <work verb>` clause, and (for a question with a work verb in it) a
# trailing question mark. Everything else is work, so the outcome and ledger gates stay on.
sb_prompt_is_informational_query() {
  local prompt lower first rest
  prompt="$(sb_prompt_trim "${1:-}")"
  [[ -n "$prompt" ]] || return 1
  lower="$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]')"
  case "$lower" in
    /*|sb:*|*@silver*|*'`sb:'*) return 1 ;;
  esac
  if grep -Eq '^[[:space:]]*([-*+]|[0-9]+[.)])[[:space:]]+' <<<"$lower"; then
    return 1
  fi
  first="$(printf '%s\n' "$lower" | awk 'NF { print; exit }' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  rest="$(printf '%s\n' "$lower" | awk 'NF { if (seen) print; seen = 1 }')"
  grep -Eq '^(remaining deliverable|left to do|what are the|what is the|what.s the|list the|show me the|status of|status$|how far|where are we|what did we|recap|what.s next|outstanding|pending gate|what|why|how|where|when|who|which|do you|does it|did we|are we|is it|can you explain|explain|summarize|describe)([^[:alnum:]_]|$)' <<<"$first" || return 1
  if [[ -n "$rest" ]] && grep -Eq "(^|[^[:alnum:]_])(${_SB_PROMPT_WORK_VERBS})([^[:alnum:]_]|\$)" <<<"$rest"; then
    return 1
  fi
  if grep -Eq "(and|then|also|but|plus|[,;])[[:space:]]+(please[[:space:]]+)?(${_SB_PROMPT_WORK_VERBS})([^[:alnum:]_]|\$)" <<<"$first"; then
    return 1
  fi
  if grep -Eq "(^|[^[:alnum:]_])(${_SB_PROMPT_WORK_VERBS})([^[:alnum:]_]|\$)" <<<"$first" \
    && ! grep -Eq '[?][[:space:]]*$' <<<"$first" \
    && ! grep -Eq '^(explain|describe|summarize|how (do|does|can|to|would)|what (is|are|does)|why (is|does|did|are))([^[:alnum:]_]|$)' <<<"$first"; then
    return 1
  fi
  return 0
}

# Short replies to orchestrator clarifying questions — do not re-inject directive.
# R2-19: the leading word must be a whole word (`now`, `nothing`, `stopwatch` are new requests,
# not `no`/`stop`) and a bare number must look like a menu choice (`2`, `2.`, `2)`), not `3 bugs`.
sb_prompt_is_orchestrator_followup() {
  local prompt words
  prompt="$(sb_prompt_trim "${1:-}")"
  [[ -n "$prompt" ]] || return 1
  if grep -qiE '^user directive:' <<<"$prompt"; then
    return 0
  fi
  words=$(printf '%s' "$prompt" | tr -cs '[:alnum:]' '\n' | sed '/^$/d' | wc -l | tr -d ' ')
  [[ "${words:-0}" -le 12 ]] || return 1
  grep -qiE '^((yes|no|yep|nope|ok|okay|sure|proceed|continue|stop|cancel|go ahead|that one|the first|the second|option [0-9]+)([^[:alnum:]_]|$)|[0-9]+([.)]|$|[.)]?[[:space:]]+(the|that|this|option)([^[:alnum:]_]|$)))' <<<"$prompt"
}

sb_prompt_is_bare_work_request() {
  local prompt lower word_count
  prompt="$(sb_prompt_trim "${1:-}")"
  [[ -n "$prompt" ]] || return 1

  if declare -f sb_prompt_is_informational_query >/dev/null 2>&1 && sb_prompt_is_informational_query "$prompt"; then
    return 1
  fi

  lower="$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]')"

  # Explicit commands/skill mentions are handled by the normal route recorder.
  case "$lower" in
    /*|sb:*|*@silver*|*'`sb:'*) return 1 ;;
  esac

  # Common conversational/status questions should not be forced through SB.
  if grep -Eq '^(what|why|how|where|when|who|which|do you|does it|did we|are we|is it|can you explain|explain|summarize|describe)[[:space:]].*[?]?$' <<<"$lower"; then
    return 1
  fi

  word_count=$(printf '%s' "$lower" | tr -cs '[:alnum:]' '\n' | sed '/^$/d' | wc -l | tr -d ' ')
  [[ "${word_count:-0}" -ge 3 ]] || return 1

  # Work-intent verbs that normally require SB orchestration or router triage.
  grep -Eq '(^|[^[:alnum:]_])(add|build|change|create|cut|debug|deploy|document|fix|implement|improve|investigate|migrate|publish|refactor|release|research|review|ship|test|update|validate|verify)([^[:alnum:]_]|$)' <<<"$lower"
}

# True when the prompt signals imminent final delivery (PR / release / deploy /
# merge / publish). Used by prompt-reminder.sh to decide whether to surface the
# full required_deploy list (delivery-adjacent) or only the planning floor (dev).
sb_prompt_is_delivery_adjacent() {
  local prompt lower
  prompt="$(sb_prompt_trim "${1:-}")"
  [[ -n "$prompt" ]] || return 1
  lower="$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]')"
  grep -Eq '(^|[^[:alnum:]_])(ship|deploy|release|publish|merge|cut a release|pull request|pr|gh pr|gh release|finalize|finish|hand off|handoff|deliver)([^[:alnum:]_]|$)' <<<"$lower"
}
