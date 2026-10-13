#!/usr/bin/env bash
# Portable subprocess timeout for Silver Bullet hook bridges (GNU timeout, python3, or direct).

# sb_run_hooked_command timeout_seconds stdin_file stdout_file stderr_file command...
sb_run_hooked_command() {
  local timeout_seconds="$1"
  local stdin_file="$2"
  local stdout_file="$3"
  local stderr_file="$4"
  shift 4

  if command -v timeout >/dev/null 2>&1; then
    timeout --signal=TERM "${timeout_seconds}s" "$@" <"$stdin_file" >"$stdout_file" 2>"$stderr_file"
    return $?
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 - "$timeout_seconds" "$stdin_file" "$stdout_file" "$stderr_file" "$@" <<'PY'
import os
import signal
import subprocess
import sys

def main() -> None:
    timeout_sec = float(sys.argv[1])
    stdin_path = sys.argv[2]
    stdout_path = sys.argv[3]
    stderr_path = sys.argv[4]
    cmd = sys.argv[5:]
    if not cmd:
        sys.exit(2)

    try:
        with (
            open(stdin_path, "rb") as stdin_f,
            open(stdout_path, "wb") as stdout_f,
            open(stderr_path, "wb") as stderr_f,
        ):
            proc = subprocess.Popen(
                cmd,
                stdin=stdin_f,
                stdout=stdout_f,
                stderr=stderr_f,
                start_new_session=True,
            )
    except FileNotFoundError:
        sys.exit(127)

    try:
        rc = proc.wait(timeout=timeout_sec)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(proc.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            proc.wait(timeout=2)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(proc.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            proc.wait()
        sys.exit(124)

    sys.exit(rc if rc is not None else 1)


if __name__ == "__main__":
    main()
PY
    return $?
  fi

  "$@" <"$stdin_file" >"$stdout_file" 2>"$stderr_file"
}
