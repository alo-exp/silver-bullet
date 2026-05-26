#!/usr/bin/env bash
set -euo pipefail

event_name="${1:-}"
shift || true

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

rc=0
if ! "$@" <"$input_file" >"$stdout_file" 2>"$stderr_file"; then
  rc=$?
fi

python3 - "$event_name" "$stdout_file" <<'PY'
import json
import sys
from pathlib import Path

event_name = sys.argv[1]
stdout_path = Path(sys.argv[2])
text = stdout_path.read_text(encoding="utf-8", errors="replace")
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

hook_specific = payload.get("hookSpecificOutput")
if isinstance(hook_specific, dict):
    message = hook_specific.pop("message", None)
    if message is not None and "systemMessage" not in payload:
        payload["systemMessage"] = message if isinstance(message, str) else str(message)

    if event_name in {"Stop", "SubagentStop"}:
        payload.pop("hookSpecificOutput", None)
    else:
        hook_specific.setdefault("hookEventName", event_name)
        if hook_specific:
            payload["hookSpecificOutput"] = hook_specific
        else:
            payload.pop("hookSpecificOutput", None)

sys.stdout.write(json.dumps(payload, separators=(",", ":")))
PY

cat "$stderr_file" >&2
exit "$rc"
