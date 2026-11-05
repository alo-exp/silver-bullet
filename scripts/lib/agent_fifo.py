"""Deadline-bounded FIFO helpers for the interactive delegation control channel.

Opening a FIFO for writing blocks until a reader exists, and opening one for reading
blocks until a writer exists. A crashed driver would hang every ctl.sh call forever, so
both ends open with O_NONBLOCK and retry until a deadline (R4-22).
"""

import errno
import os
import select
import time


def open_writer(path, timeout):
    """Open ``path`` for writing, retrying while no reader is attached (ENXIO).

    Raises TimeoutError when no reader appears before the deadline. The returned
    descriptor is switched back to blocking mode so a full pipe waits for the reader.
    """
    deadline = time.monotonic() + timeout
    while True:
        try:
            fd = os.open(path, os.O_WRONLY | os.O_NONBLOCK)
        except OSError as exc:
            if exc.errno not in (errno.ENXIO, errno.ENOENT):
                raise
            if time.monotonic() >= deadline:
                raise TimeoutError(path)
            time.sleep(0.05)
            continue
        os.set_blocking(fd, True)
        return fd


def write_line(path, payload, timeout=8.0):
    """Write one newline-terminated payload to a FIFO, bounded by ``timeout`` seconds."""
    fd = open_writer(path, timeout)
    try:
        os.write(fd, (payload.rstrip() + "\n").encode("utf-8"))
    finally:
        os.close(fd)


def read_line(path, timeout=8.0):
    """Read until a newline (or EOF after data) from a FIFO, bounded by ``timeout`` seconds."""
    deadline = time.monotonic() + timeout
    fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
    chunks = []
    try:
        while time.monotonic() < deadline:
            ready, _, _ = select.select([fd], [], [], 0.2)
            if not ready:
                continue
            try:
                data = os.read(fd, 65536)
            except BlockingIOError:
                continue
            if data:
                chunks.append(data)
                if b"\n" in data:
                    break
            elif chunks:
                break
            else:
                time.sleep(0.05)
    finally:
        os.close(fd)
    return b"".join(chunks)
