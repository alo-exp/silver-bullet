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
  local payload="$1"
  python3 - "$payload" <<'PY'
import json, re, sys
try:
    data = json.loads(sys.argv[1] or "{}")
except Exception:
    raise SystemExit(0)

patterns = (
    re.compile(r"\[lean-ctx:", re.I),
    re.compile(r"\.\.\.\s*\[lean-ctx:", re.I),
    re.compile(r"^\s*\S+\.plan\.md\s*\[\d+L\]\s*$", re.M),
)

def walk(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for item in value.values():
            yield from walk(item)
    elif isinstance(value, list):
        for item in value:
            yield from walk(item)

for text in walk(data.get("tool_input", {})):
    for pattern in patterns:
        if pattern.search(text):
            raise SystemExit(0)
raise SystemExit(1)
PY
}

if payload_has_compression_markers "$input"; then
  emit_deny "Compression marker guard — edit payload contains LeanCTX compression artifacts ([lean-ctx: …] or ctx_read file header).

Do not Write/Edit from compressed ctx_read output. Re-read the target with native Read or ctx_read(raw=true), then retry the edit."
fi

exit 0
