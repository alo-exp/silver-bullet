#!/usr/bin/env bash
# Silver Bullet — hook output emitters.
#
# Every emitter prints exactly one JSON document built only from fields the host hook
# protocol defines (Claude Code's schema; hooks/codex-hook-adapter.sh
# translates it for Codex):
#   systemMessage                                     user-visible notice, any event
#   hookSpecificOutput.additionalContext              model-visible context, always with
#                                                     hookSpecificOutput.hookEventName
#   hookSpecificOutput.permissionDecision{,Reason}    PreToolUse deny / ask
#   decision "block" + reason                         Stop, SubagentStop, PostToolUse,
#                                                     UserPromptSubmit
# Strings are JSON-encoded through stdin (never argv, so length is unbounded) by jq, else
# python3, else a Bash encoder: quotes, newlines and control characters always yield one
# valid document, and jq/python3 replace invalid UTF-8 with U+FFFD.
#
# API:
#   sb_emit_hook_message EVENT MESSAGE        {"systemMessage":MESSAGE}. Status 1, no output,
#                                             for an empty MESSAGE. EVENT is accepted for
#                                             compatibility; a notice is the same everywhere.
#   sb_emit_hook_message_json EVENT JSON      as sb_emit_hook_message with MESSAGE given as an
#                                             encoded JSON string; anything that is not exactly
#                                             one JSON string is emitted as literal text.
#   sb_emit_hook_context EVENT CONTEXT        {"hookSpecificOutput":{"hookEventName":EVENT,
#                                             "additionalContext":CONTEXT}}; Stop/SubagentStop
#                                             have no context field, so they get a systemMessage.
#                                             Status 1 for an empty CONTEXT.
#   sb_emit_hook_decision EVENT DECISION REASON [CONTEXT] [NOTICE]
#                                             one document with a decision and advisory text:
#     DECISION ""|none|allow|approve  no decision (SB never emits "allow": that would skip the
#                                     host's own permission prompt); ask (PreToolUse only);
#                                     deny|block and anything unrecognised fail closed.
#     PreToolUse   deny: permissionDecision "deny", REASON then CONTEXT in
#                  permissionDecisionReason (the field every host shows the model on a deny);
#                  ask: "ask" + REASON, CONTEXT as additionalContext; none: CONTEXT only.
#     Stop, SubagentStop          block: decision/reason with CONTEXT appended to the reason;
#                                 none: CONTEXT joins NOTICE in systemMessage.
#     PostToolUse, UserPromptSubmit  block: decision/reason; CONTEXT as additionalContext.
#     other events (SessionStart, SubagentStart, ...)  no decision field: REASON is prefixed
#                                 to CONTEXT in additionalContext.
#     NOTICE becomes systemMessage. An empty REASON on a decision gets a default text.
#     Prints nothing (status 0) when there is nothing to say.

# _sb_hook_replace_all TEXT CHAR REPLACEMENT: replace every CHAR in TEXT into _SB_HOOK_OUT.
# A prefix/suffix loop, not "${s//"$ch"/"$rep"}": Bash <= 4.2 (macOS /bin/bash 3.2) keeps the
# quotes of a quoted replacement string literally.
_sb_hook_replace_all() {
  local rest="$1" ch="$2" rep="$3"
  _SB_HOOK_OUT=""
  while [[ "$rest" == *"$ch"* ]]; do
    _SB_HOOK_OUT="$_SB_HOOK_OUT${rest%%"$ch"*}$rep"
    rest="${rest#*"$ch"}"
  done
  _SB_HOOK_OUT="$_SB_HOOK_OUT$rest"
}

# _sb_hook_json_bash TEXT: last-resort JSON string encoder (non-ASCII bytes pass through).
# Linear time: the text is encoded in 256-character chunks, so the rescanning replace loop
# never works on more than one chunk (a chunk boundary can never split an escape).
_sb_hook_json_bash() {
  # Byte-oriented: Bash 5.2 returns uninitialised bytes from "${s%%"\\"*}" in a UTF-8 locale
  # when a lone lead byte precedes the pattern. Only ever called inside $(...), so no leak.
  local LC_ALL=C
  local s="$1" bs="\\" q='"' nl=$'\n' cr=$'\r' tab=$'\t' i oct hex ch pos=0 out="" len="${#1}"
  local -a ctl_ch=() ctl_esc=()
  for i in 1 2 3 4 5 6 7 8 11 12 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31; do
    printf -v oct '%03o' "$i"
    printf -v hex '%04x' "$i"
    printf -v ch '%b' "\\0$oct"
    ctl_ch[i]="$ch"
    ctl_esc[i]="${bs}u$hex"
  done
  while [[ "$pos" -lt "$len" ]]; do
    _sb_hook_replace_all "${s:pos:256}" "$bs" "$bs$bs"
    _sb_hook_replace_all "$_SB_HOOK_OUT" "$q" "$bs$q"
    _sb_hook_replace_all "$_SB_HOOK_OUT" "$nl" "${bs}n"
    _sb_hook_replace_all "$_SB_HOOK_OUT" "$cr" "${bs}r"
    _sb_hook_replace_all "$_SB_HOOK_OUT" "$tab" "${bs}t"
    for i in "${!ctl_ch[@]}"; do
      _sb_hook_replace_all "$_SB_HOOK_OUT" "${ctl_ch[i]}" "${ctl_esc[i]}"
    done
    out="$out$_SB_HOOK_OUT"
    pos=$((pos + 256))
  done
  printf '"%s"' "$out"
}

# _sb_hook_json_str TEXT: print TEXT as a JSON string literal.
_sb_hook_json_str() {
  local out=""
  if command -v jq >/dev/null 2>&1; then
    out="$(printf '%s' "$1" | jq -Rs . 2>/dev/null)" || out=""
  fi
  if [[ -z "$out" ]] && command -v python3 >/dev/null 2>&1; then
    out="$(printf '%s' "$1" | python3 -c 'import json, sys; sys.stdout.write(json.dumps(sys.stdin.buffer.read().decode("utf-8", "replace")))' 2>/dev/null)" || out=""
  fi
  if [[ -z "$out" ]]; then
    _sb_hook_json_bash "$1"
    return 0
  fi
  printf '%s' "$out"
}

# _sb_hook_is_json_string TEXT: TEXT is exactly one JSON string value.
_sb_hook_is_json_string() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$1" | jq -se 'length == 1 and (.[0] | type) == "string"' >/dev/null 2>&1
    return
  fi
  printf '%s' "$1" | python3 -c 'import json, sys; sys.exit(0 if isinstance(json.loads(sys.stdin.read()), str) else 1)' >/dev/null 2>&1
}

# _sb_hook_join A B: A and B separated by a blank line when both are non-empty.
_sb_hook_join() {
  if [[ -n "$1" && -n "$2" ]]; then
    printf '%s\n\n%s' "$1" "$2"
  else
    printf '%s%s' "$1" "$2"
  fi
}

sb_emit_hook_message() {
  [[ -n "${2:-}" ]] || return 1
  printf '{"systemMessage":%s}' "$(_sb_hook_json_str "$2")"
}

sb_emit_hook_message_json() {
  local message_json="${2:-}"
  [[ -n "$message_json" ]] || return 1
  if _sb_hook_is_json_string "$message_json"; then
    printf '{"systemMessage":%s}' "$message_json"
    return 0
  fi
  sb_emit_hook_message "${1:-}" "$message_json"
}

sb_emit_hook_context() {
  local event="${1:-PostToolUse}" context="${2:-}"
  [[ -n "$context" ]] || return 1
  case "$event" in
    Stop | SubagentStop) printf '{"systemMessage":%s}' "$(_sb_hook_json_str "$context")" ;;
    *) printf '{"hookSpecificOutput":{"hookEventName":%s,"additionalContext":%s}}' \
      "$(_sb_hook_json_str "$event")" "$(_sb_hook_json_str "$context")" ;;
  esac
}

sb_emit_hook_decision() {
  local event="${1:-PreToolUse}" decision="${2:-}" reason="${3:-}" context="${4:-}" notice="${5:-}"
  local verdict="" doc="" hso=""
  case "$decision" in
    "" | none | allow | approve) ;;
    ask) verdict="ask" ;;
    *) verdict="deny" ;;
  esac
  [[ -z "$verdict" || -n "$reason" ]] || reason="Silver Bullet blocked this action."
  case "$event" in
    PreToolUse)
      if [[ "$verdict" == "deny" ]]; then
        reason="$(_sb_hook_join "$reason" "$context")"
        context=""
      fi
      [[ -z "$verdict" ]] || hso=",\"permissionDecision\":\"$verdict\",\"permissionDecisionReason\":$(_sb_hook_json_str "$reason")"
      ;;
    Stop | SubagentStop)
      if [[ -n "$verdict" ]]; then
        doc="\"decision\":\"block\",\"reason\":$(_sb_hook_json_str "$(_sb_hook_join "$reason" "$context")")"
      else
        notice="$(_sb_hook_join "$context" "$notice")"
      fi
      context=""
      ;;
    PostToolUse | UserPromptSubmit)
      [[ -z "$verdict" ]] || doc="\"decision\":\"block\",\"reason\":$(_sb_hook_json_str "$reason")"
      ;;
    *)
      [[ -z "$verdict" ]] || context="$(_sb_hook_join "$reason" "$context")"
      ;;
  esac
  [[ -z "$context" ]] || hso="$hso,\"additionalContext\":$(_sb_hook_json_str "$context")"
  [[ -z "$hso" ]] || doc="${doc:+$doc,}\"hookSpecificOutput\":{\"hookEventName\":$(_sb_hook_json_str "$event")$hso}"
  [[ -z "$notice" ]] || doc="${doc:+$doc,}\"systemMessage\":$(_sb_hook_json_str "$notice")"
  [[ -n "$doc" ]] || return 0
  printf '{%s}' "$doc"
}
