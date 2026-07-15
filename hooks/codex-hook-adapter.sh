#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

_adapter_lib="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _adapter_lib=""
if [[ -f "${_adapter_lib}/hook-subproc-timeout.sh" ]]; then
  # shellcheck source=lib/hook-subproc-timeout.sh
  source "${_adapter_lib}/hook-subproc-timeout.sh"
fi

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

SB_HOOK_SUBPROC_TIMEOUT="${SB_CODEX_HOOK_SUBPROC_TIMEOUT:-12}"
trap - ERR
set +e
sb_run_hooked_command "$SB_HOOK_SUBPROC_TIMEOUT" "$input_file" "$stdout_file" "$stderr_file" "$@"
rc=$?
set -e
trap '''exit 0''' ERR
if [[ "$rc" -eq 124 ]]; then
  : >"$stdout_file"
  printf '{"systemMessage":"Silver Bullet hook subprocess timed out."}\n' >"$stdout_file"
  rc=0
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
        # Codex rejects hookSpecificOutput that only carries hookEventName (no
        # permissionDecision, additionalContext, updatedInput, etc.). After
        # promoting Claude "message" to top-level systemMessage, drop the shell.
        meaningful = {k: v for k, v in hook_specific.items() if k != "hookEventName"}
        if meaningful:
            payload["hookSpecificOutput"] = hook_specific
        else:
            payload.pop("hookSpecificOutput", None)

sys.stdout.write(json.dumps(payload, separators=(",", ":")))
PY

cat "$stderr_file" >&2
exit "$rc"
