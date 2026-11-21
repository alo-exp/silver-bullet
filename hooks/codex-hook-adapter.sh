#!/usr/bin/env bash
# Codex hook adapter: runs one Silver Bullet hook command and reshapes its output
# for Codex. Usage: codex-hook-adapter.sh EVENT [--timeout SECONDS] COMMAND...
# It does no tool-name translation (the installer expands matchers); see
# docs/RUNTIME-COMPATIBILITY.md.
set -euo pipefail
trap 'exit 0' ERR

_adapter_lib="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _adapter_lib=""
if [[ -f "${_adapter_lib}/hook-subproc-timeout.sh" ]]; then
  # shellcheck source=lib/hook-subproc-timeout.sh
  source "${_adapter_lib}/hook-subproc-timeout.sh"
fi

event_name="${1:-}"
shift || true

# Optional per-hook budget, written by the Codex installer from the hook's own
# hooks.json timeout so the adapter never stops a hook earlier than the manifest
# allows (R7-01). SB_CODEX_HOOK_SUBPROC_TIMEOUT overrides it (tests, operators).
manifest_timeout=""
if [[ "${1:-}" == "--timeout" ]]; then
  manifest_timeout="${2:-}"
  shift 2 || true
fi
case "$manifest_timeout" in
  '' | *[!0-9]* | 0) manifest_timeout=120 ;;
esac

if [[ -z "$event_name" || "$#" -eq 0 ]]; then
  exit 2
fi

input_file="$(mktemp "${TMPDIR:-/tmp}/sb-hook-input.XXXXXX")"
stdout_file="$(mktemp "${TMPDIR:-/tmp}/sb-hook-stdout.XXXXXX")"
stderr_file="$(mktemp "${TMPDIR:-/tmp}/sb-hook-stderr.XXXXXX")"

cleanup() {
  rm -f -- "$input_file" "$stdout_file" "$stderr_file"
}
trap cleanup EXIT

cat >"$input_file"

SB_HOOK_SUBPROC_TIMEOUT="${SB_CODEX_HOOK_SUBPROC_TIMEOUT:-$manifest_timeout}"
trap - ERR
set +e
sb_run_hooked_command "$SB_HOOK_SUBPROC_TIMEOUT" "$input_file" "$stdout_file" "$stderr_file" "$@"
rc=$?
set -e
trap 'exit 0' ERR
if [[ "$rc" -eq 124 ]]; then
  # A hook that ran out of time produced no verdict. On the events that can
  # deny, that is a deny (fail closed) so a slow gate cannot become an allow;
  # other events only get a notice. SB_CODEX_HOOK_ON_TIMEOUT=allow opts out.
  timeout_msg="Silver Bullet hook timed out after ${SB_HOOK_SUBPROC_TIMEOUT}s and was blocked (fail closed). Retry, or raise the hook timeout in hooks.json."
  case "$event_name:${SB_CODEX_HOOK_ON_TIMEOUT:-deny}" in
    PreToolUse:deny)
      jq -cn --arg r "$timeout_msg" \
        '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}' >"$stdout_file"
      ;;
    Stop:deny | SubagentStop:deny)
      jq -cn --arg r "$timeout_msg" '{decision:"block",reason:$r}' >"$stdout_file"
      ;;
    *)
      printf '{"systemMessage":"Silver Bullet hook subprocess timed out."}\n' >"$stdout_file"
      ;;
  esac
  rc=0
fi

# Reshape the hook's output for Codex with jq (a hard Silver Bullet requirement).
# If the transform cannot run (jq missing, non-JSON output) the hook's own
# output is passed through unchanged: a deny or block is never dropped (R7-02).
codex_transform='
  if (type == "object") and ((.hookSpecificOutput | type) == "object") then
    (.hookSpecificOutput.message) as $m
    | (if $m != null and (has("systemMessage") | not)
       then .systemMessage = (if ($m | type) == "string" then $m else ($m | tostring) end)
       else . end)
    | del(.hookSpecificOutput.message)
    | if ($ev == "Stop" or $ev == "SubagentStop") then del(.hookSpecificOutput)
      else
        (.hookSpecificOutput |= (if has("hookEventName") then . else . + {hookEventName: $ev} end))
        | if ((.hookSpecificOutput | del(.hookEventName) | length) > 0) then . else del(.hookSpecificOutput) end
      end
  else . end'
if transformed="$(jq -c --arg ev "$event_name" "$codex_transform" "$stdout_file" 2>/dev/null)"; then
  [[ -z "$transformed" ]] || printf '%s' "$transformed"
else
  cat "$stdout_file"
fi

cat "$stderr_file" >&2
exit "$rc"
