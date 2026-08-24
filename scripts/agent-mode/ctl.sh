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

python3 - "$CONTROL_DIR" "$(json_payload)" "$OP" <<'PY'
import json, os, select, sys, time

control, payload, op = sys.argv[1], sys.argv[2], sys.argv[3]
cmd = os.path.join(control, "cmd.fifo")
reply = os.path.join(control, "reply.fifo")
if not os.path.exists(cmd):
    sys.stderr.write("ERROR: cmd.fifo missing (not interactive)\n")
    sys.exit(2)

def open_fifo(path, flags, timeout=5.0):
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            return os.open(path, flags)
        except OSError:
            time.sleep(0.05)
    raise TimeoutError(path)

flags = os.O_WRONLY | getattr(os, "O_NONBLOCK", 0)
try:
    fd = open_fifo(cmd, os.O_WRONLY, 8.0)
except Exception as exc:
    sys.stderr.write("ERROR: could not open cmd.fifo: %s\n" % exc)
    sys.exit(2)
os.write(fd, (payload.rstrip() + "\n").encode("utf-8"))
os.close(fd)

if op in ("snapshot", "status"):
    try:
        rfd = open_fifo(reply, os.O_RDONLY, 8.0)
    except Exception as exc:
        sys.stderr.write("ERROR: could not open reply.fifo: %s\n" % exc)
        sys.exit(2)
    chunks = []
    deadline = time.time() + 8.0
    while time.time() < deadline:
        ready, _, _ = select.select([rfd], [], [], 0.2)
        if ready:
            data = os.read(rfd, 65536)
            if not data:
                break
            chunks.append(data)
            if b"\n" in data:
                break
    os.close(rfd)
    sys.stdout.write(b"".join(chunks).decode("utf-8", "replace"))
PY
