#!/usr/bin/env bash
# Lightweight prompt classification shared by UserPromptSubmit hooks.

sb_prompt_trim() {
  local text="$1"
  printf '%s' "$text" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'
}

# Work-intent verbs (shared by the informational and bare-work classifiers).
_SB_PROMPT_WORK_VERBS='add|build|change|create|cut|debug|deploy|document|fix|implement|improve|investigate|migrate|publish|refactor|release|research|review|ship|test|update|validate|verify'

# Verbs that are a request wherever a clause opens with them (no everyday noun among them).
_SB_PROMPT_STRONG_VERBS='fix|implement|add|change|update|remove|delete|refactor|create|write|make|rename|patch|resolve|repair|rewrite|migrate|install'

# Informational / status questions — answer directly; do not compose full SB chains.
#
# R2-19: classify on the FIRST non-blank line with patterns anchored at its start, and only call
# a prompt informational when nothing in it asks for work: no list items, no work verb on the
# later lines, no `... and <work verb>` clause, and (for a question with a work verb in it) a
# trailing question mark. Everything else is work, so the outcome and ledger gates stay on.
sb_prompt_is_informational_query() {
  local prompt lower first rest sentences clauses
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
  if grep -Eq "(and|then|also|but|plus)[[:space:]]+(please[[:space:]]+)?(${_SB_PROMPT_WORK_VERBS})([^[:alnum:]_]|\$)" <<<"$first"; then
    return 1
  fi
  # After a comma or semicolon only a strong change verb opens a request ("What is X, fix it"): a list of nouns
  # ("Explain the flow: build, test, deploy") is not one.
  if grep -Eq "[,;][[:space:]]+(please[[:space:]]+)?(${_SB_PROMPT_STRONG_VERBS})([^[:alnum:]_]|\$)" <<<"$first"; then
    return 1
  fi
  # A later sentence on the same line ("What is going on with CI? Fix it.", "...CI?Fix it", "going on... fix it") is judged
  # like a later line: split at the first run of terminators (`?`/`!` runs, an ellipsis, or a full stop before
  # whitespace or the end), whitespace after it optional. A dot inside a name (`config.test.js`) is no boundary.
  sentences="$(printf '%s' "$first" | sed -E 's/^([^.?!]|\.[^[:space:].?!])*(\.*[?!]+|\.\.+|\.([[:space:]]|$))[[:space:]]*//')"
  if [[ "$sentences" != "$first" ]] && grep -Eq "(^|[^[:alnum:]_])(${_SB_PROMPT_WORK_VERBS})([^[:alnum:]_]|\$)" <<<"$sentences"; then
    return 1
  fi
  # A clause set off by a Unicode ellipsis, a colon or an em/en dash that is an IMPERATIVE ("What is broken: fix it",
  # "What is wrong — fix it", "What is going on… fix it") is a request. Imperative = a strong change verb (not a
  # noun-ambiguous one such as test, build, review, deploy or release) that opens the clause, after an optional
  # please/pls/go/can you, followed by an object word or the end of the clause. "What does this do: test.sh",
  # "Explain: migrate vs upgrade" and "What is TDD — test driven development" stay questions; so does a line that
  # ends in a question mark. The separators are literal byte sequences (no multibyte bracket expression), so the
  # C locale and BSD awk agree with a UTF-8 locale.
  if ! grep -Eq '[?][[:space:]]*$' <<<"$first"; then
    clauses="$(printf '%s\n' "$first" | awk '{ gsub(/…|—|–|:/, "\001"); n = split($0, p, "\001"); for (i = 2; i <= n; i++) print p[i] }')"
    if grep -Eq "^[[:space:]]*(((and|then|also|please|pls|kindly|just|go|now)|(can|could|would|will)[[:space:]]+you)[[:space:]]+)*(${_SB_PROMPT_STRONG_VERBS})(([[:space:]]+(it|this|that|them|these|those|the|all|everything|my|our|now|please|up|a|an)([^[:alnum:]_]|\$))|[[:space:]]*[.!)]*\$)" <<<"$clauses"; then
      return 1
    fi
  fi
  if grep -Eq "(^|[^[:alnum:]_])(${_SB_PROMPT_WORK_VERBS})([^[:alnum:]_]|\$)" <<<"$first" \
    && ! grep -Eq '[?][[:space:]]*$' <<<"$first" \
    && ! grep -Eq '^(explain|describe|summarize|how (do|does|can|to|would|is|are|did|should)|what (is|are|does|did|changed|was|were)|what.s|which|who|where (is|are|do|does|did)|when (is|are|do|does|did)|why (is|does|did|are|do))([^[:alnum:]_]|$)' <<<"$first"; then
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
