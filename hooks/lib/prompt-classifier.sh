#!/usr/bin/env bash
# Lightweight prompt classification shared by UserPromptSubmit hooks.

sb_prompt_trim() {
  local text="$1"
  printf '%s' "$text" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'
}

# Informational / status questions — answer directly; do not compose full SB chains.
sb_prompt_is_informational_query() {
  local prompt lower
  prompt="$(sb_prompt_trim "${1:-}")"
  [[ -n "$prompt" ]] || return 1
  lower="$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]')"
  case "$lower" in
    /*|silver:*|*@silver*|*'`silver:'*) return 1 ;;
  esac
  if printf '%s' "$lower" | grep -Eq '(remaining deliverable|left to do|what are the|what is the|list the|show me the|status of|how far|where are we|what did we|recap|what.s next|outstanding|pending gate)'; then
    return 0
  fi
  if printf '%s' "$lower" | grep -Eq '^(what|why|how|where|when|who|which|do you|does it|did we|are we|is it|can you explain|explain|summarize|describe)[[:space:]].*[?]?$'; then
    return 0
  fi
  return 1
}

# Short replies to orchestrator clarifying questions — do not re-inject directive.
sb_prompt_is_orchestrator_followup() {
  local prompt words
  prompt="$(sb_prompt_trim "${1:-}")"
  [[ -n "$prompt" ]] || return 1
  if printf '%s' "$prompt" | grep -qiE '^user directive:'; then
    return 0
  fi
  words=$(printf '%s' "$prompt" | tr -cs '[:alnum:]' '\n' | sed '/^$/d' | wc -l | tr -d ' ')
  [[ "${words:-0}" -le 12 ]] || return 1
  printf '%s' "$prompt" | grep -qiE '^(yes|no|yep|nope|ok|okay|sure|proceed|continue|stop|cancel|go ahead|that one|the first|the second|option [0-9]|[0-9]+[.)]?[[:space:]])'
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
    /*|silver:*|*@silver*|*'`silver:'*) return 1 ;;
  esac

  # Common conversational/status questions should not be forced through SB.
  if printf '%s' "$lower" | grep -Eq '^(what|why|how|where|when|who|which|do you|does it|did we|are we|is it|can you explain|explain|summarize|describe)[[:space:]].*[?]?$'; then
    return 1
  fi

  word_count=$(printf '%s' "$lower" | tr -cs '[:alnum:]' '\n' | sed '/^$/d' | wc -l | tr -d ' ')
  [[ "${word_count:-0}" -ge 3 ]] || return 1

  # Work-intent verbs that normally require SB orchestration or router triage.
  printf '%s' "$lower" | grep -Eq '(^|[^[:alnum:]_])(add|build|change|create|cut|debug|deploy|document|fix|implement|improve|investigate|migrate|publish|refactor|release|research|review|ship|test|update|validate|verify)([^[:alnum:]_]|$)'
}

# True when the prompt signals imminent final delivery (PR / release / deploy /
# merge / publish). Used by prompt-reminder.sh to decide whether to surface the
# full required_deploy list (delivery-adjacent) or only the planning floor (dev).
sb_prompt_is_delivery_adjacent() {
  local prompt lower
  prompt="$(sb_prompt_trim "${1:-}")"
  [[ -n "$prompt" ]] || return 1
  lower="$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]')"
  printf '%s' "$lower" | grep -Eq '(^|[^[:alnum:]_])(ship|deploy|release|publish|merge|cut a release|pull request|pr|gh pr|gh release|finalize|finish|hand off|handoff|deliver)([^[:alnum:]_]|$)'
}
