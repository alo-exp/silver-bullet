"""Unit tests for scripts/agent-mode/mock-interactive.py (FIFO driven mock TUI)."""
from __future__ import annotations

import errno
import json
import os
import runpy
import sys
import tempfile
import threading
import time
import unittest
from pathlib import Path
from unittest import mock

from sbtest import load_module

REPO = Path(__file__).resolve().parents[2]
mi = load_module("scripts/agent-mode/mock-interactive.py")


def _line(**kw):
    return (json.dumps(kw) + "\n").encode()


class FifoHarness:
    """Run mi.main() in-process with a writer thread feeding cmd.fifo."""

    def __init__(self, tc: unittest.TestCase, timeout: float = 5.0):
        self.tc = tc
        self.tmp = tempfile.TemporaryDirectory()
        tc.addCleanup(self.tmp.cleanup)
        self.task = os.path.join(self.tmp.name, "task")
        self.ctl = os.path.join(self.tmp.name, "ctl")
        self.timeout = timeout
        self.replies: list[str] = []

    def events(self):
        p = os.path.join(self.task, "events.jsonl")
        if not os.path.exists(p):
            return []
        return [json.loads(x) for x in Path(p).read_text().splitlines()]

    def run(self, writers, expect_replies=0, entry=None):
        """writers: list of lists of byte chunks; each inner list is one open/close session."""
        cmd = os.path.join(self.ctl, "cmd.fifo")
        reply = os.path.join(self.ctl, "reply.fifo")

        def writer():
            for _ in range(200):  # main() creates the fifos when absent
                if os.path.exists(cmd):
                    break
                time.sleep(0.02)
            for session in writers:
                fd = os.open(cmd, os.O_WRONLY)
                for chunk in session:
                    if isinstance(chunk, float):
                        time.sleep(chunk)
                    else:
                        os.write(fd, chunk)
                        time.sleep(0.05)
                os.close(fd)
                time.sleep(0.05)

        def reader():
            for _ in range(expect_replies):
                for _ in range(200):
                    if os.path.exists(reply):
                        break
                    time.sleep(0.02)
                fd = os.open(reply, os.O_RDONLY)
                data = b""
                while True:
                    part = os.read(fd, 4096)
                    if not part:
                        break
                    data += part
                os.close(fd)
                self.replies.append(data.decode())

        threads = [threading.Thread(target=writer, daemon=True),
                   threading.Thread(target=reader, daemon=True)]
        for t in threads:
            t.start()
        argv = ["mock-interactive.py", "--task-dir", self.task, "--control-dir", self.ctl,
                "--timeout", str(self.timeout)]
        with mock.patch.object(sys, "argv", argv):
            rc = (entry or mi.main)()
        for t in threads:
            t.join(timeout=5)
        return rc


class EmitTest(unittest.TestCase):
    def test_emit_with_and_without_payload_creates_dirs(self):
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "a", "b", "events.jsonl")
            mi.emit(path, "ready")
            mi.emit(path, "question", "why?")
            rows = [json.loads(x) for x in Path(path).read_text().splitlines()]
            self.assertEqual(rows[0]["event"], "ready")
            self.assertNotIn("payload", rows[0])
            self.assertRegex(rows[0]["ts"], r"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$")
            self.assertEqual(rows[1]["payload"], "why?")

    def test_emit_bare_filename_uses_cwd(self):
        with tempfile.TemporaryDirectory() as d:
            old = os.getcwd()
            os.chdir(d)
            try:
                mi.emit("events.jsonl", "ready")
            finally:
                os.chdir(old)
            self.assertTrue(os.path.exists(os.path.join(d, "events.jsonl")))


class OpenRdTest(unittest.TestCase):
    def test_times_out_when_path_missing(self):
        with tempfile.TemporaryDirectory() as d:
            with self.assertRaises(TimeoutError):
                mi.open_rd(os.path.join(d, "nope"), 0.1)

    def test_opens_existing_file(self):
        with tempfile.NamedTemporaryFile() as f:
            fd = mi.open_rd(f.name, 1.0)
            os.close(fd)


class ReplyTest(unittest.TestCase):
    def test_retries_blocking_open_after_nonblocking_failure(self):
        calls = []
        real_open = os.open

        def fake_open(path, flags, *a):
            calls.append(flags)
            if len(calls) == 1:
                raise OSError(errno.ENXIO, "no reader")
            return real_open(os.devnull, os.O_WRONLY)

        written = []
        with mock.patch.object(mi.os, "open", fake_open), \
                mock.patch.object(mi.os, "write", lambda fd, b: written.append(b)), \
                mock.patch.object(mi.os, "close", lambda fd: None):
            mi._reply("/x/reply.fifo", "hello\n\n")
        self.assertEqual(len(calls), 2)
        self.assertEqual(written, [b"hello\n"])

    def test_gives_up_silently_after_deadline(self):
        def always_fail(path, flags, *a):
            raise OSError(errno.ENXIO, "no reader")

        clock = iter([100.0, 103.0])
        with mock.patch.object(mi.os, "open", always_fail), \
                mock.patch.object(mi.time, "time", lambda: next(clock)), \
                mock.patch.object(mi.time, "sleep", lambda s: self.fail("should not sleep")), \
                mock.patch.object(mi.os, "write", lambda *a: self.fail("should not write")):
            self.assertIsNone(mi._reply("/x/reply.fifo", "body"))

    def test_sleeps_between_retries(self):
        attempts = []
        real_open = os.open

        def flaky(path, flags, *a):
            attempts.append(1)
            if len(attempts) < 3:
                raise OSError(errno.ENXIO, "no reader")
            return real_open(os.devnull, os.O_WRONLY)

        sleeps = []
        with mock.patch.object(mi.os, "open", flaky), \
                mock.patch.object(mi.time, "sleep", sleeps.append), \
                mock.patch.object(mi.os, "write", lambda fd, b: None), \
                mock.patch.object(mi.os, "close", lambda fd: None):
            mi._reply("/x/reply.fifo", "body")
        self.assertEqual(sleeps, [0.05])


class MainTest(unittest.TestCase):
    def test_full_conversation_reaches_done_with_result(self):
        h = FifoHarness(self)
        rc = h.run([[
            _line(op="status"),
            b"\n   \n",
            _line(op="snapshot"),
            _line(op="noop"),
            _line(op="send", text="do the thing"),
            _line(op="status"),
            _line(op="key", name="Enter"),
        ]], expect_replies=3)
        self.assertEqual(rc, 0)
        self.assertEqual(json.loads(h.replies[0]), {"state": "await_brief"})
        self.assertEqual(h.replies[1], "MOCK-TUI state=await_brief\n")
        self.assertEqual(json.loads(h.replies[2]), {"state": "await_answer"})
        names = [e["event"] for e in h.events()]
        self.assertEqual(names, ["ready", "prompt_submitted", "question", "assistant", "done"])
        self.assertEqual(h.events()[1]["payload"], "do the thing")
        result = Path(h.task, "result.md").read_text()
        self.assertTrue(result.startswith("## STATUS\npass\n"))
        self.assertIn("## NEXT_RETRY_PROMPT", result)

    def test_abort_exits_zero_and_emits_exited(self):
        h = FifoHarness(self)
        rc = h.run([[_line(op="abort")]])
        self.assertEqual(rc, 0)
        self.assertEqual(h.events()[-1], {**h.events()[-1], "event": "exited", "payload": "abort"})
        self.assertFalse(os.path.exists(os.path.join(h.task, "result.md")))

    def test_writer_close_reopens_fifo_and_split_line_is_buffered(self):
        h = FifoHarness(self)
        msg = _line(op="abort")
        rc = h.run([[b'{"op": '], [b'"abort"}\n'], [msg]])
        self.assertEqual(rc, 0)
        self.assertEqual(h.events()[-1]["event"], "exited")

    def test_timeout_returns_one_with_error_event(self):
        h = FifoHarness(self, timeout=0.6)
        rc = h.run([[0.9]])
        self.assertEqual(rc, 1)
        self.assertEqual(h.events()[-1]["event"], "error")
        self.assertEqual(h.events()[-1]["payload"], "timeout")

    def test_existing_fifos_are_reused(self):
        h = FifoHarness(self)
        os.makedirs(h.ctl)
        os.mkfifo(os.path.join(h.ctl, "cmd.fifo"))
        os.mkfifo(os.path.join(h.ctl, "reply.fifo"))
        rc = h.run([[_line(op="abort")]])
        self.assertEqual(rc, 0)

    def test_script_entrypoint_exits_with_main_status(self):
        h = FifoHarness(self)

        def entry():
            try:
                runpy.run_path(str(REPO / "scripts/agent-mode/mock-interactive.py"), run_name="__main__")
            except SystemExit as exc:
                return exc.code
            return None

        rc = h.run([[_line(op="abort")]], entry=entry)
        self.assertEqual(rc, 0)
        self.assertEqual(h.events()[-1]["event"], "exited")

    def test_fd_close_failure_in_finally_is_swallowed(self):
        h = FifoHarness(self)
        real_close = os.close
        state = {"n": 0}

        def close(fd):
            real_close(fd)
            state["n"] += 1
            if state["n"] == 1:
                raise OSError("boom")

        with mock.patch.object(mi.os, "close", close):
            rc = h.run([[_line(op="abort")]])
        self.assertEqual(rc, 0)
        self.assertGreaterEqual(state["n"], 1)


if __name__ == "__main__":
    unittest.main()
