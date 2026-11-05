#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# PreToolUse — block Write/Edit payloads that contain LeanCTX compression markers.
# Prevents durable file corruption when agents paste ctx_read output into edits.
#
# Upstream lean-ctx v3.9.9+ also denies [lean-ctx: markers in handle_deny() (issue #805).
# SB keeps this hook as belt-and-suspenders: ctx_read file headers (.plan.md [316L]) and
# SB plugin hook chains that may run without lean-ctx global hooks active.

umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
[[ -f "$_lib_dir/tool-input.sh" ]] && source "$_lib_dir/tool-input.sh"

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat 2>/dev/null || true)"
[[ -n "$input" ]] || exit 0
hook_event="$(printf '%s' "$input" | jq -r '.hook_event_name // "PreToolUse"' 2>/dev/null || echo PreToolUse)"
[[ "$hook_event" == "PreToolUse" ]] || exit 0

tool_name="$(sb_tool_name "$input" 2>/dev/null || true)"
case "$tool_name" in
  Edit|Write|MultiEdit|apply_patch) ;;
  *) exit 0 ;;
esac

emit_deny() {
  local reason="$1"
  local json_reason
  json_reason=$(printf '%s' "$reason" | jq -Rs '.')
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$json_reason"
  [[ "${SB_KAY_HOOK_BRIDGE_INVOKED:-}" == "1" ]] && { printf '%s\n' "$reason" >&2; exit 2; }
  exit 0
}

payload_has_compression_markers() {
  local payload="$1" script
  # the payload goes to python3 on stdin: as an argument it fails past 128 KiB and the guard would allow
  script=$(cat <<'PY'
import json, re, sys
try:
    data = json.loads(sys.stdin.read() or "{}")
except Exception:
    raise SystemExit(1)  # unparsable payload: nothing to inspect

# The ctx_read artifact shapes: an elision/summary line that STARTS with the marker (optionally
# after "..."), and the ".plan.md [316L]" header line. A marker mentioned inside a sentence is
# documentation, not an artifact.
patterns = (
    re.compile(r"^\s*(?:\.\.\.\s*)?\[lean-ctx:", re.I | re.M),
    re.compile(r"^\s*\S+\.plan\.md\s*\[\d+L\]\s*$", re.M),
)
# Only text being WRITTEN counts: removing a marker (old_string, patch '-' lines) must stay possible.
CONTENT_KEYS = {"content", "new_string", "new_str", "new_text", "text", "replacement", "contents", "source"}
PATCH_KEYS = {"input", "patch", "diff"}

def written(value, key=""):
    if isinstance(value, str):
        if key in CONTENT_KEYS:
            yield value
        elif key in PATCH_KEYS:
            yield "\n".join(line[1:] for line in value.splitlines() if line.startswith("+"))
    elif isinstance(value, dict):
        for k, item in value.items():
            yield from written(item, k)
    elif isinstance(value, list):
        for item in value:
            yield from written(item, key)

tool_input = data.get("tool_input", {})
target = ""
if isinstance(tool_input, dict):
    for field in ("file_path", "notebook_path", "path"):
        if isinstance(tool_input.get(field), str):
            target = tool_input[field]
            break
# Files that document the marker: anything under a docs/ directory, or a file that already
# contains it (editing it must not become impossible).
if target:
    if "docs" in target.replace("\\", "/").split("/"):
        raise SystemExit(1)
    try:
        with open(target, "r", encoding="utf-8", errors="replace") as handle:
            if "[lean-ctx:" in handle.read(2_000_000).lower():
                raise SystemExit(1)
    except OSError:
        pass

for text in written(tool_input):
    for pattern in patterns:
        if pattern.search(text):
            raise SystemExit(0)
raise SystemExit(1)
PY
)
  printf '%s' "$payload" | python3 -c "$script"
}

if payload_has_compression_markers "$input"; then
  emit_deny "Compression marker guard — edit payload contains LeanCTX compression artifacts ([lean-ctx: …] or ctx_read file header).

Do not Write/Edit from compressed ctx_read output. Re-read the target with native Read or ctx_read(raw=true), then retry the edit."
fi

exit 0
