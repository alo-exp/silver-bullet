"""Run a command with a real pseudo-terminal on its stdin and answer its prompt.

    python3 -I -B tests/lib/pty-run.py [--reply TEXT] [--prompt MARKER] [--timeout SECS]
        --stdout FILE --stderr FILE -- COMMAND [ARGS...]

The command's stdin is the slave side of a pty, so `[[ -t 0 ]]` is true and `read` sees
what this script types. Its stdout and stderr stay separate (pipes, saved to the files).
When MARKER (default "[y/N]") shows up on either stream, TEXT is typed once; TEXT uses
backslash escapes ("y\\n", "\\x04" for end of input). With no --reply nothing is typed.
A command still running at the timeout is killed and the exit status is 124. Otherwise
the exit status is the command's (128+N when killed by signal N). Standard library only.
"""
import argparse
import os
import pty
import select
import signal
import subprocess
import sys
import time


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--reply")
    ap.add_argument("--prompt", default="[y/N]")
    ap.add_argument("--timeout", type=float, default=45.0)
    ap.add_argument("--stdout", required=True)
    ap.add_argument("--stderr", required=True)
    ap.add_argument("command", nargs="+")
    args = ap.parse_args(argv)
    reply = None
    if args.reply is not None:
        reply = args.reply.encode().decode("unicode_escape").encode("latin-1")
    marker = args.prompt.encode()

    master, slave = pty.openpty()
    proc = subprocess.Popen(args.command, stdin=slave, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, start_new_session=True)
    os.close(slave)
    bufs = {proc.stdout.fileno(): b"", proc.stderr.fileno(): b""}
    open_fds = set(bufs)
    deadline = time.monotonic() + args.timeout
    typed = False
    timed_out = False
    while open_fds:
        left = deadline - time.monotonic()
        if left <= 0:
            timed_out = True
            break
        ready, _, _ = select.select(sorted(open_fds), [], [], min(left, 1.0))
        for fd in ready:
            chunk = os.read(fd, 65536)
            if not chunk:
                open_fds.discard(fd)
                continue
            bufs[fd] += chunk
        if reply is not None and not typed and any(marker in b for b in bufs.values()):
            os.write(master, reply)
            typed = True
    if timed_out:
        os.killpg(proc.pid, signal.SIGKILL)
    code = proc.wait()
    os.close(master)
    with open(args.stdout, "wb") as fh:
        fh.write(bufs[proc.stdout.fileno()])
    with open(args.stderr, "wb") as fh:
        fh.write(bufs[proc.stderr.fileno()])
    if timed_out:
        return 124
    return code if code >= 0 else 128 - code


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
