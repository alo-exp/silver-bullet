#!/usr/bin/env bash
set -euo pipefail

cursor_event="${1:-}"
shift || true

if [[ -z "$cursor_event" || "$#" -eq 0 ]]; then
  exit 2
fi

input_file="$(mktemp "${TMPDIR:-/tmp}/sb-cursor-in.XXXXXX")"
stdout_file="$(mktemp "${TMPDIR:-/tmp}/sb-cursor-out.XXXXXX")"
stderr_file="$(mktemp "${TMPDIR:-/tmp}/sb-cursor-err.XXXXXX")"

cleanup() {
  rm -f -- "$input_file" "$stdout_file" "$stderr_file"
}
trap cleanup EXIT

cat >"$input_file"

python3 - "$cursor_event" "$input_file" <<'PY' >"${input_file}.sb"
import json
import shlex
import sys
from pathlib import Path

cursor_event = sys.argv[1]
raw = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8") or "{}")

EVENT_MAP = {
    "sessionStart": "SessionStart",
    "preToolUse": "PreToolUse",
    "postToolUse": "PostToolUse",
    "postToolUseFailure": "PostToolUse",
    "stop": "Stop",
    "subagentStop": "SubagentStop",
    "beforeSubmitPrompt": "UserPromptSubmit",
    "beforeShellExecution": "PreToolUse",
    "afterShellExecution": "PostToolUse",
}

TOOL_MAP = {
    "Shell": "Bash",
    "shell": "Bash",
    "exec_command": "Bash",
}

sb_event = EVENT_MAP.get(cursor_event, cursor_event)
out = {"hook_event_name": sb_event}

if cursor_event == "beforeSubmitPrompt":
    out["prompt"] = raw.get("prompt") or raw.get("user_message") or raw.get("text") or ""
elif cursor_event in {"beforeShellExecution", "afterShellExecution"}:
    command = raw.get("command") or raw.get("cmd") or ""
    if isinstance(command, list):
        command = " ".join(shlex.quote(str(part)) for part in command)
    out["tool_name"] = "Bash"
    out["tool_input"] = {"command": command}
    if cursor_event == "afterShellExecution":
        out["tool_response"] = {
            "exit_code": raw.get("exit_code", raw.get("exitCode", 0)),
            "stdout": raw.get("stdout", ""),
            "stderr": raw.get("stderr", ""),
        }
elif cursor_event == "sessionStart":
    out["source"] = raw.get("source") or raw.get("sessionSource") or "startup"
else:
    tool_name = raw.get("tool_name") or raw.get("toolName") or raw.get("tool") or ""
    out["tool_name"] = TOOL_MAP.get(tool_name, tool_name)
    tool_input = raw.get("tool_input") or raw.get("toolInput") or raw.get("input") or {}
    if not isinstance(tool_input, dict):
        tool_input = {}
    out["tool_input"] = tool_input
    tool_response = raw.get("tool_response") or raw.get("toolResponse") or raw.get("response")
    if isinstance(tool_response, dict):
        out["tool_response"] = tool_response

Path(sys.argv[2] + ".sb").write_text(json.dumps(out, separators=(",", ":")), encoding="utf-8")
PY

rc=0
if ! "$@" <"${input_file}.sb" >"$stdout_file" 2>"$stderr_file"; then
  rc=$?
fi
rm -f -- "${input_file}.sb"

python3 - "$cursor_event" "$stdout_file" <<'PY'
import json
import sys
from pathlib import Path

cursor_event = sys.argv[1]
text = Path(sys.argv[2]).read_text(encoding="utf-8", errors="replace")
trimmed = text.strip()
if not trimmed or trimmed[0] not in "{[":
    sys.stdout.write(text)
    raise SystemExit(0)
try:
    payload = json.loads(text)
except Exception:
    sys.stdout.write(text)
    raise SystemExit(0)
if not isinstance(payload, dict):
    sys.stdout.write(text)
    raise SystemExit(0)

out = {}
if payload.get("decision") == "block":
    reason = payload.get("reason") or "Silver Bullet blocked completion."
    if cursor_event in {"stop", "subagentStop"}:
        out["followup_message"] = reason if isinstance(reason, str) else str(reason)
    else:
        out["permission"] = "deny"
        out["agent_message"] = reason if isinstance(reason, str) else str(reason)
        out["user_message"] = out["agent_message"]
    sys.stdout.write(json.dumps(out, separators=(",", ":")))
    raise SystemExit(0)

hook_specific = payload.get("hookSpecificOutput")
if isinstance(hook_specific, dict):
    message = hook_specific.get("message")
    additional = hook_specific.get("additionalContext")
    decision = hook_specific.get("permissionDecision")
    reason = hook_specific.get("permissionDecisionReason")
    if decision == "deny":
        out["permission"] = "deny"
        if reason is not None:
            text_reason = reason if isinstance(reason, str) else json.dumps(reason, separators=(",", ":"))
            out["agent_message"] = text_reason
            out["user_message"] = text_reason
    if additional is not None and cursor_event in {"postToolUse", "sessionStart", "beforeSubmitPrompt"}:
        out["additional_context"] = additional if isinstance(additional, str) else str(additional)
    elif message is not None:
        if cursor_event in {"postToolUse", "sessionStart", "beforeSubmitPrompt"}:
            out["additional_context"] = message if isinstance(message, str) else str(message)
        elif cursor_event in {"stop", "subagentStop"}:
            out["followup_message"] = message if isinstance(message, str) else str(message)
        elif cursor_event in {"beforeShellExecution", "preToolUse", "beforeMCPExecution"}:
            out["agent_message"] = message if isinstance(message, str) else str(message)

if out:
    sys.stdout.write(json.dumps(out, separators=(",", ":")))
else:
    sys.stdout.write(text)
PY

cat "$stderr_file" >&2
exit "$rc"
