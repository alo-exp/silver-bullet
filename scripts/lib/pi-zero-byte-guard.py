#!/usr/bin/env python3
"""Idle/hard-timeout wrapper for pi -p (agent_host_pi_run_argv_zero_byte_guard).

Keep STUB_RE in sync with agent_host_pi_file_is_stub in agent-host-exec.sh.

A non-empty expect-file is not progress. Claude via OmniRoute often writes a
~779-byte hash checkpoint ("analysis in progress at this checkpoint") then
sits on an ESTABLISHED Omni TCP with empty stdout until PI_RUN_TIMEOUT.
Idle fires only when the file is not file_ok (min bytes, not a stub) and
neither stdout nor the expect-file has grown for idle_sec.
"""
from __future__ import annotations

import os
import re
import select
import signal
import subprocess
import sys
import time

STUB_RE = re.compile(
    r"IN_PROGRESS(\s*:|\s)|Do not treat this stub as final|"
    r"Placeholder body so this path exists|"
    r"analysis in progress at this checkpoint|"
    r"final report replaces this content",
    re.I,
)


def _is_stub(path: str) -> bool:
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            head = handle.read(8192)
    except OSError:
        return False
    return bool(STUB_RE.search(head))


def main() -> None:
    idle_sec = int(sys.argv[1])
    hard_sec = int(sys.argv[2])
    expect_file = sys.argv[3]
    min_bytes = int(sys.argv[4])
    args = sys.argv[5:]

    def file_ok() -> bool:
        if not expect_file:
            return False
        try:
            if not os.path.isfile(expect_file):
                return False
            if os.path.getsize(expect_file) < min_bytes:
                return False
            return not _is_stub(expect_file)
        except OSError:
            return False

    proc = subprocess.Popen(
        args,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        start_new_session=True,
    )
    assert proc.stdout is not None
    fd = proc.stdout.fileno()
    got_bytes = False
    start = time.monotonic()
    last_progress = start
    last_size = 0

    try:
        while proc.poll() is None:
            now = time.monotonic()
            if now - start >= hard_sec:
                break
            if expect_file:
                try:
                    if os.path.isfile(expect_file):
                        size = os.path.getsize(expect_file)
                        if size > last_size:
                            last_size = size
                            last_progress = now
                except OSError:
                    pass
            if not file_ok() and (now - last_progress) >= idle_sec:
                break
            ready, _, _ = select.select([fd], [], [], 0.2)
            if not ready:
                continue
            data = os.read(fd, 65536)
            if not data:
                time.sleep(0.05)
                continue
            if data.strip():
                got_bytes = True
                last_progress = time.monotonic()
            sys.stdout.buffer.write(data)
            sys.stdout.buffer.flush()
        if proc.poll() is not None:
            leftover = proc.stdout.read() or b""
            if leftover:
                if leftover.strip():
                    got_bytes = True
                sys.stdout.buffer.write(leftover)
                sys.stdout.buffer.flush()
            sys.exit(proc.returncode or 0)
        try:
            os.killpg(proc.pid, signal.SIGTERM)
        except OSError:
            pass
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(proc.pid, signal.SIGKILL)
            except OSError:
                pass
            proc.wait(timeout=5)
        leftover = proc.stdout.read() or b""
        if leftover:
            sys.stdout.buffer.write(leftover)
            sys.stdout.buffer.flush()
        reason = (
            "hard-timeout"
            if (time.monotonic() - start >= hard_sec)
            else "zero-byte-idle"
        )
        sys.stderr.write(
            "[agent-pi] %s kill after %.0fs (stdout_bytes=%s expect_ok=%s expect_bytes=%s)\n"
            % (
                reason,
                time.monotonic() - start,
                "yes" if got_bytes else "no",
                file_ok(),
                last_size,
            )
        )
        sys.exit(124)
    except Exception as exc:
        try:
            os.killpg(proc.pid, signal.SIGTERM)
        except OSError:
            pass
        sys.stderr.write("[agent-pi] zero-byte guard error: %s\n" % exc)
        sys.exit(124)


if __name__ == "__main__":
    main()
