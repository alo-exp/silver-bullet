"""Unit tests for scripts/lib/pi-zero-byte-guard.py (frozen clock, fake child)."""
from __future__ import annotations

import io
import os
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

from sbtest import REPO_ROOT, load_module

guard = load_module("scripts/lib/pi-zero-byte-guard.py")


class FakeStdout:
    def __init__(self, leftover=b""):
        self.leftover = leftover

    def fileno(self):
        return 99

    def read(self):
        return self.leftover


class FakeProc:
    """poll() yields the scripted values; the last one repeats."""

    def __init__(self, polls, returncode=0, leftover=b"", wait_script=None, pid=4242):
        self.polls = list(polls)
        self.returncode = returncode
        self.stdout = FakeStdout(leftover)
        self.pid = pid
        self.wait_script = list(wait_script or [None, None])
        self.wait_calls = []

    def poll(self):
        if len(self.polls) > 1:
            return self.polls.pop(0)
        return self.polls[0]

    def wait(self, timeout=None):
        self.wait_calls.append(timeout)
        item = self.wait_script.pop(0)
        if item == "timeout":
            raise subprocess.TimeoutExpired("pi", timeout)
        return item


class Harness:
    """Runs guard.main() against a fake clock, fake select/read and fake child."""

    def __init__(self, test):
        self.test = test
        self.t = 100.0
        self.reads = []
        self.ready = []
        self.killed = []
        self.sleeps = []
        self.out = io.BytesIO()
        self.err = io.StringIO()
        self.killpg_errors = {}

    def run(self, argv, proc, getsize=None, isfile=None, is_stub=None):
        def fake_select(rl, wl, xl, timeout):
            self.t += timeout
            if self.ready:
                return (rl if self.ready.pop(0) else []), [], []
            return [], [], []

        def fake_read(fd, n):
            item = self.reads.pop(0)
            if isinstance(item, Exception):
                raise item
            return item

        def fake_killpg(pid, sig):
            self.killed.append((pid, sig))
            err = self.killpg_errors.get(sig)
            if err:
                raise err

        def fake_sleep(sec):
            self.sleeps.append(sec)
            self.t += sec

        stdout = mock.Mock()
        stdout.buffer = self.out
        patches = [
            mock.patch.object(sys, "argv", ["guard"] + argv),
            mock.patch.object(sys, "stdout", stdout),
            mock.patch.object(sys, "stderr", self.err),
            mock.patch.object(guard.subprocess, "Popen", return_value=proc),
            mock.patch.object(guard.time, "monotonic", lambda: self.t),
            mock.patch.object(guard.time, "sleep", fake_sleep),
            mock.patch.object(guard.select, "select", fake_select),
            mock.patch.object(guard.os, "read", fake_read),
            mock.patch.object(guard.os, "killpg", fake_killpg),
        ]
        if getsize:
            patches.append(mock.patch.object(guard.os.path, "getsize", getsize))
        if isfile:
            patches.append(mock.patch.object(guard.os.path, "isfile", isfile))
        if is_stub:
            patches.append(mock.patch.object(guard, "_is_stub", is_stub))
        for p in patches:
            p.start()
        try:
            with self.test.assertRaises(SystemExit) as cm:
                guard.main()
        finally:
            for p in reversed(patches):
                p.stop()
        return cm.exception.code


class IsStubTest(unittest.TestCase):
    def _stub(self, text):
        with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False) as fh:
            fh.write(text)
        self.addCleanup(os.unlink, fh.name)
        return guard._is_stub(fh.name)

    def test_markers_detected(self):
        for text in (
            "IN_PROGRESS: hash",
            "status IN_PROGRESS now",
            "Do not treat this stub as final",
            "Placeholder body so this path exists",
            "Analysis In Progress At This Checkpoint",
            "final report replaces this content",
        ):
            self.assertTrue(self._stub(text), text)

    def test_real_content_not_stub(self):
        self.assertFalse(self._stub("# Report\nAll findings.\n"))
        self.assertFalse(self._stub("IN_PROGRESSIVE rock"))

    def test_marker_after_8k_head_ignored(self):
        self.assertFalse(self._stub("x" * 9000 + "IN_PROGRESS: late"))

    def test_missing_file_is_not_stub(self):
        self.assertFalse(guard._is_stub("/nonexistent/dir/file.md"))

    def test_undecodable_bytes_replaced(self):
        with tempfile.NamedTemporaryFile("wb", delete=False) as fh:
            fh.write(b"\xff\xfe IN_PROGRESS: x")
        self.addCleanup(os.unlink, fh.name)
        self.assertTrue(guard._is_stub(fh.name))


class MainFakeTest(unittest.TestCase):
    def test_child_exits_cleanly_with_leftover(self):
        h = Harness(self)
        proc = FakeProc([0], returncode=3, leftover=b"tail\n")
        code = h.run(["5", "60", "", "10"], proc)
        self.assertEqual(code, 3)
        self.assertEqual(h.out.getvalue(), b"tail\n")
        self.assertEqual(h.killed, [])
        self.assertEqual(h.err.getvalue(), "")

    def test_child_exits_zero_returncode_none_maps_to_zero(self):
        h = Harness(self)
        proc = FakeProc([0], returncode=None, leftover=b"  \n")
        code = h.run(["5", "60", "", "10"], proc)
        self.assertEqual(code, 0)
        self.assertEqual(h.out.getvalue(), b"  \n")

    def test_child_exits_without_leftover(self):
        h = Harness(self)
        proc = FakeProc([0], returncode=0, leftover=b"")
        self.assertEqual(h.run(["5", "60", "", "10"], proc), 0)
        self.assertEqual(h.out.getvalue(), b"")

    def test_streams_output_then_exits(self):
        h = Harness(self)
        h.ready = [True, True, True]
        h.reads = [b"hello ", b"  ", b""]
        proc = FakeProc([None, None, None, 0], returncode=0)
        code = h.run(["50", "600", "", "10"], proc)
        self.assertEqual(code, 0)
        self.assertEqual(h.out.getvalue(), b"hello   ")
        self.assertEqual(h.sleeps, [0.05])  # EOF read sleeps briefly

    def test_idle_kill_without_any_output(self):
        h = Harness(self)
        proc = FakeProc([None])
        code = h.run(["1", "600", "", "10"], proc)
        self.assertEqual(code, 124)
        self.assertIn("zero-byte-idle", h.err.getvalue())
        self.assertIn("stdout_bytes=no expect_ok=False expect_bytes=0", h.err.getvalue())
        self.assertEqual(h.killed, [(4242, guard.signal.SIGTERM)])
        self.assertEqual(proc.wait_calls, [5])

    def test_hard_timeout_wins_over_idle(self):
        h = Harness(self)
        h.ready = [True, True]
        h.reads = [b"x", b"y"]
        proc = FakeProc([None], leftover=b"left")
        code = h.run(["1000", "1", "", "10"], proc)
        self.assertEqual(code, 124)
        self.assertIn("hard-timeout", h.err.getvalue())
        self.assertIn("stdout_bytes=yes", h.err.getvalue())
        self.assertEqual(h.out.getvalue(), b"xyleft")

    def test_blank_output_is_not_progress(self):
        h = Harness(self)
        h.ready = [True] * 10
        h.reads = [b" \n"] * 10
        proc = FakeProc([None])
        code = h.run(["1", "600", "", "10"], proc)
        self.assertEqual(code, 124)
        self.assertIn("zero-byte-idle", h.err.getvalue())
        self.assertIn("stdout_bytes=no", h.err.getvalue())

    def test_real_output_resets_idle_timer(self):
        h = Harness(self)
        # Output on every iteration keeps the idle timer fresh until hard timeout.
        h.ready = [True] * 100
        h.reads = [b"tick"] * 100
        proc = FakeProc([None])
        code = h.run(["1", "3", "", "10"], proc)
        self.assertEqual(code, 124)
        self.assertIn("hard-timeout", h.err.getvalue())

    def test_growing_expect_file_counts_as_progress_and_ok_file_disables_idle(self):
        h = Harness(self)
        sizes = iter([5, 8, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20])
        last = {"v": 20}

        def getsize(path):
            last["v"] = next(sizes, 20)
            return last["v"]

        proc = FakeProc([None])
        code = h.run(
            ["1", "4", "/x/expect.md", "10"], proc,
            getsize=getsize, isfile=lambda p: True, is_stub=lambda p: False,
        )
        # Once the file reaches min_bytes and is not a stub, idle never fires;
        # only the hard timeout ends the run.
        self.assertEqual(code, 124)
        self.assertIn("hard-timeout", h.err.getvalue())
        self.assertIn("expect_ok=True expect_bytes=20", h.err.getvalue())

    def test_stub_expect_file_does_not_disable_idle(self):
        h = Harness(self)
        proc = FakeProc([None])
        code = h.run(
            ["1", "600", "/x/expect.md", "10"], proc,
            getsize=lambda p: 779, isfile=lambda p: True, is_stub=lambda p: True,
        )
        self.assertEqual(code, 124)
        self.assertIn("zero-byte-idle", h.err.getvalue())
        self.assertIn("expect_ok=False expect_bytes=779", h.err.getvalue())

    def test_small_expect_file_not_ok(self):
        h = Harness(self)
        proc = FakeProc([None])
        h.run(["1", "600", "/x/e", "100"], proc,
              getsize=lambda p: 99, isfile=lambda p: True, is_stub=lambda p: False)
        self.assertIn("zero-byte-idle", h.err.getvalue())
        self.assertIn("expect_ok=False expect_bytes=99", h.err.getvalue())

    def test_missing_expect_file_not_ok(self):
        h = Harness(self)
        proc = FakeProc([None])
        h.run(["1", "600", "/x/e", "10"], proc, isfile=lambda p: False)
        self.assertIn("zero-byte-idle", h.err.getvalue())
        self.assertIn("expect_ok=False expect_bytes=0", h.err.getvalue())

    def test_getsize_oserror_is_tolerated(self):
        h = Harness(self)
        proc = FakeProc([None])

        def boom(path):
            raise OSError("vanished")

        h.run(["1", "600", "/x/e", "10"], proc, getsize=boom, isfile=lambda p: True)
        self.assertIn("zero-byte-idle", h.err.getvalue())
        self.assertIn("expect_ok=False", h.err.getvalue())

    def test_killpg_oserror_and_sigkill_escalation(self):
        h = Harness(self)
        h.killpg_errors = {
            guard.signal.SIGTERM: ProcessLookupError("gone"),
            guard.signal.SIGKILL: ProcessLookupError("gone"),
        }
        proc = FakeProc([None], wait_script=["timeout", None], leftover=b"bye")
        code = h.run(["1", "600", "", "10"], proc)
        self.assertEqual(code, 124)
        self.assertEqual(
            h.killed, [(4242, guard.signal.SIGTERM), (4242, guard.signal.SIGKILL)]
        )
        self.assertEqual(proc.wait_calls, [5, 5])
        self.assertEqual(h.out.getvalue(), b"bye")

    def test_unexpected_exception_reports_and_exits_124(self):
        h = Harness(self)
        h.ready = [True]
        h.reads = [RuntimeError("boom")]
        h.killpg_errors = {guard.signal.SIGTERM: ProcessLookupError("gone")}
        proc = FakeProc([None])
        code = h.run(["50", "600", "", "10"], proc)
        self.assertEqual(code, 124)
        self.assertIn("zero-byte guard error: boom", h.err.getvalue())
        self.assertEqual(h.killed, [(4242, guard.signal.SIGTERM)])


class MainSubprocessTest(unittest.TestCase):
    """End-to-end with real children (short, bounded)."""

    def _run(self, argv, **kw):
        return subprocess.run(
            [sys.executable, str(REPO_ROOT / "scripts/lib/pi-zero-byte-guard.py")] + argv,
            capture_output=True, text=True, timeout=30, cwd=tempfile.gettempdir(), **kw,
        )

    def test_passthrough_exit_code_and_output(self):
        res = self._run(["5", "20", "", "10", sys.executable, "-c",
                         "import sys; print('out'); sys.stderr.write('err\\n'); sys.exit(7)"])
        self.assertEqual(res.returncode, 7)
        self.assertIn("out", res.stdout)
        self.assertIn("err", res.stdout)  # stderr merged into stdout

    def test_silent_child_killed_by_idle(self):
        res = self._run(["1", "20", "", "10", sys.executable, "-c",
                         "import time; time.sleep(30)"])
        self.assertEqual(res.returncode, 124)
        self.assertIn("zero-byte-idle kill", res.stderr)
        self.assertIn("stdout_bytes=no", res.stderr)


if __name__ == "__main__":
    unittest.main()
