#!/usr/bin/env bash
# Interactive-only control helper (plan 17ed9bf7 §6.3 / I-31).
# Usage: ctl.sh [--control-dir PATH] send|key|snapshot|status|abort [args]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source=scripts/lib/agent-mode.sh
source "${REPO_ROOT}/scripts/lib/agent-mode.sh"

CONTROL_DIR="${SB_AGENT_CONTROL_DIR:-}"
OP=""
ARG=""

usage() {
  cat <<'EOF'
Usage: scripts/agent-mode/ctl.sh [--control-dir PATH] <send|key|snapshot|status|abort|stop> [args]

  send TEXT     Type TEXT into the child TUI (as the parent user)
  key NAME      Send a key (Enter, Up, Down, y, n, ...)
  snapshot      Capture the current TUI screen (reply.fifo)
  status        Child/driver status (reply.fifo)
  abort|stop    Abort the interactive wave
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --control-dir)
      [[ $# -ge 2 ]] || { printf 'ERROR: --control-dir requires a value\n' >&2; exit 2; }
      CONTROL_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    send|key|snapshot|status|abort|stop)
      OP="$1"
      shift
      ARG="${1:-}"
      [[ $# -gt 0 ]] && shift
      break
      ;;
    *)
      printf 'ERROR: unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

[[ -n "$CONTROL_DIR" ]] || {
  printf 'ERROR: --control-dir or SB_AGENT_CONTROL_DIR required\n' >&2
  exit 2
}
[[ -d "$CONTROL_DIR" ]] || {
  printf 'ERROR: control dir missing (interactive-only): %s\n' "$CONTROL_DIR" >&2
  exit 2
}
[[ -n "$OP" ]] || { usage >&2; exit 2; }

[[ "$OP" == "stop" ]] && OP="abort"

json_payload() {
  case "$OP" in
    send)
      python3 -c 'import json,sys; print(json.dumps({"op":"send","text":sys.argv[1]}))' "$ARG"
      ;;
    key)
      python3 -c 'import json,sys; print(json.dumps({"op":"key","name":sys.argv[1]}))' "$ARG"
      ;;
    snapshot|status|abort)
      python3 -c 'import json,sys; print(json.dumps({"op":sys.argv[1]}))' "$OP"
      ;;
  esac
}

python3 - "$CONTROL_DIR" "$(json_payload)" "$OP" "${REPO_ROOT}/scripts/lib" <<'PY'
import os, sys

control, payload, op, lib_dir = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
sys.path.insert(0, lib_dir)
import agent_fifo

timeout = float(os.environ.get("SB_AGENT_CTL_TIMEOUT") or "8")

cmd = os.path.join(control, "cmd.fifo")
reply = os.path.join(control, "reply.fifo")
if not os.path.exists(cmd):
    sys.stderr.write("ERROR: cmd.fifo missing (not interactive)\n")
    sys.exit(2)

try:
    agent_fifo.write_line(cmd, payload, timeout)
except (OSError, TimeoutError) as exc:
    sys.stderr.write("ERROR: could not open cmd.fifo (no driver reading it?): %s\n" % exc)
    sys.exit(2)

if op in ("snapshot", "status"):
    try:
        data = agent_fifo.read_line(reply, timeout)
    except OSError as exc:
        sys.stderr.write("ERROR: could not open reply.fifo: %s\n" % exc)
        sys.exit(2)
    sys.stdout.write(data.decode("utf-8", "replace"))
PY
