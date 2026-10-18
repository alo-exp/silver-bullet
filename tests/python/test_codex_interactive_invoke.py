"""Unit tests for scripts/codex-interactive-invoke.py.

The PTY, clock and child-process layers are replaced by a scripted fake so every
branch of main() is exercised deterministically without a real Codex CLI.
"""
from __future__ import annotations

import contextlib
import errno
import io
import os
import runpy
import signal
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from sbtest import REPO_ROOT, load_module

m = load_module("scripts/codex-interactive-invoke.py")

FAKE_FD = 4242
FAKE_PID = 999001
PROMPT_TEXT = b"Please implement the feature described in the brief carefully now"
READY = "OpenAI Codex\ndirectory: /x\n› ".encode()


class PureHelpersTest(unittest.TestCase):
    def test_env_or_default(self):
        with mock.patch.dict(os.environ, {"X_SET": "v", "X_EMPTY": ""}):
            self.assertEqual(m.env_or_default("X_SET", "d"), "v")
            self.assertEqual(m.env_or_default("X_EMPTY", "d"), "d")
            self.assertEqual(m.env_or_default("X_NOPE_UNSET", "d"), "d")

    def test_strip_ansi(self):
        self.assertEqual(m.strip_ansi("\x1b[31mred\x1b[0m \x1b[?25l\x1bMx"), "red x")

    def test_compact_text(self):
        self.assertEqual(m.compact_text(" A b\n\tC "), "abc")

    def test_apply_terminal_overwrites(self):
        self.assertEqual(m.apply_terminal_overwrites("abc\rxy\nline\bX\n\b\bq"), "xy\nlinX\nq")
        self.assertEqual(m.apply_terminal_overwrites(""), "")
        self.assertEqual(m.apply_terminal_overwrites("a\n"), "a")

    def test_append_terminal_text(self):
        self.assertEqual(m.append_terminal_text("ab", "cd"), "abcd")
        self.assertEqual(m.append_terminal_text("one\ntwo", "\rX"), "one\nX")
        self.assertEqual(m.append_terminal_text("only", "\rX"), "X")
        self.assertEqual(m.append_terminal_text("ab", "\b"), "a")
        self.assertEqual(m.append_terminal_text("ab\n", "\b"), "ab\n")
        self.assertEqual(m.append_terminal_text("", "\b"), "")
        self.assertEqual(m.append_terminal_text("abc", "defg", max_len=4), "defg")

    def test_load_prompt(self):
        with tempfile.NamedTemporaryFile("w", suffix=".txt", encoding="utf-8", delete=False) as f:
            f.write("héllo")
        self.addCleanup(os.unlink, f.name)
        self.assertEqual(m.load_prompt(f.name), "héllo")

    def test_sanitized_child_env(self):
        base = {"A": "1", "TERM": "dumb", "CODEX_THREAD_ID": "t", "CODEX_INTERNAL_ORIGINATOR_OVERRIDE": "o",
                "__CFBundleIdentifier": "b", "XPC_SERVICE_NAME": "x"}
        out = m.sanitized_child_env(base)
        self.assertEqual(out, {"A": "1", "TERM": "xterm-256color"})
        self.assertEqual(base["TERM"], "dumb")  # input not mutated
        self.assertIn("CODEX_THREAD_ID", base)

    def test_native_prompt_ready(self):
        with mock.patch.dict(os.environ, {"SB_AGENT_CODEX_LIGHTWEIGHT": "0"}):
            self.assertTrue(m.native_prompt_ready("Use /skills to list available skills"))
            self.assertFalse(m.native_prompt_ready("nothing"))
            self.assertFalse(m.native_prompt_ready("OpenAI Codex only"))
            self.assertFalse(m.native_prompt_ready("OpenAI Codex\ndirectory: /x"))  # no prompt glyph
            self.assertTrue(m.native_prompt_ready("OpenAI Codex\ndirectory: /x\n›"))
            self.assertTrue(m.native_prompt_ready("OpenAI Codex\nbooting MCP server: x\n❯"))
            self.assertFalse(m.native_prompt_ready("OpenAI Codex\n›"))  # neither directory nor booting
        with mock.patch.dict(os.environ, {"SB_AGENT_CODEX_LIGHTWEIGHT": "1"}):
            self.assertTrue(m.native_prompt_ready("OpenAI Codex directory: /x ❯"))
            self.assertFalse(m.native_prompt_ready("OpenAI Codex directory: /x"))

    def test_activity_fingerprint_ignores_noise(self):
        a = m.activity_fingerprint("\x1b[2mWorking (3s • esc to interrupt)\x1b[0m ⠋ real text 12/40")
        b = m.activity_fingerprint("Working (9s • esc to interrupt) ⠙ real text 33/40")
        self.assertEqual(a, b)
        self.assertIn("realtext", a)
        self.assertNotEqual(a, m.activity_fingerprint("other text"))
        self.assertEqual(len(m.activity_fingerprint("x" * 20000)), 8000)

    def test_stop_hook_predicates(self):
        self.assertTrue(m.stop_hooks_active("runningstophook"))
        self.assertFalse(m.stop_hooks_active("running"))
        self.assertFalse(m.stop_hooks_active("stophook"))
        self.assertTrue(m.stop_hooks_completed("ranstophook"))
        self.assertTrue(m.stop_hooks_completed("workedfor3s"))
        self.assertFalse(m.stop_hooks_completed("ran"))
        self.assertFalse(m.stop_hooks_completed("stophook"))

    def test_completion_prompt_returned(self):
        self.assertTrue(m.completion_prompt_returned("Use /skills to list available skills"))
        self.assertTrue(m.completion_prompt_returned("Ran 1 Stop hook"))
        self.assertTrue(m.completion_prompt_returned("Worked for 3s"))
        self.assertFalse(m.completion_prompt_returned("still going ›"))
        self.assertFalse(m.completion_prompt_returned("Running Stop hook"))  # glyph missing
        self.assertTrue(m.completion_prompt_returned("Running Stop hook ❯"))


class TranscriptAndStdoutTest(unittest.TestCase):
    def test_append_transcript(self):
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, "t.bin")
            m.append_transcript("", b"ignored")
            self.assertFalse(os.path.exists(p))
            m.append_transcript(p, b"ab")
            m.append_transcript(p, b"cd")
            self.assertEqual(Path(p).read_bytes(), b"abcd")

    def test_redirect_stdout_to_devnull(self):
        with tempfile.TemporaryFile() as sink:
            fake = mock.Mock()
            fake.fileno.return_value = sink.fileno()
            saved = os.dup(sink.fileno())
            try:
                with mock.patch.object(sys, "stdout", fake):
                    m.redirect_stdout_to_devnull()
                    os.write(sink.fileno(), b"gone")
            finally:
                os.dup2(saved, sink.fileno())
                os.close(saved)
            sink.seek(0)
            self.assertEqual(sink.read(), b"")

    def test_redirect_stdout_swallows_oserror(self):
        with mock.patch.object(m.os, "open", side_effect=OSError("no")):
            self.assertIsNone(m.redirect_stdout_to_devnull())

    def test_redirect_stdout_closes_fd_even_if_dup2_fails(self):
        closed = []
        with mock.patch.object(m.os, "open", return_value=77), \
                mock.patch.object(m.os, "dup2", side_effect=OSError("bad")), \
                mock.patch.object(m.os, "close", side_effect=closed.append), \
                mock.patch.object(sys, "stdout", mock.Mock(fileno=lambda: 1)):
            m.redirect_stdout_to_devnull()
        self.assertEqual(closed, [77])

    def _stdout(self, write_exc=None):
        buf = io.BytesIO()
        out = mock.Mock()
        out.buffer = mock.Mock()
        if write_exc:
            out.buffer.write.side_effect = write_exc
        else:
            out.buffer.write.side_effect = buf.write
        return out, buf

    def test_forward_stdout_disabled(self):
        out, buf = self._stdout()
        with mock.patch.object(sys, "stdout", out):
            self.assertFalse(m.forward_stdout(b"x", False))
        self.assertEqual(buf.getvalue(), b"")

    def test_forward_stdout_writes_and_flushes(self):
        out, buf = self._stdout()
        with mock.patch.object(sys, "stdout", out):
            self.assertTrue(m.forward_stdout(b"hello", True))
        self.assertEqual(buf.getvalue(), b"hello")
        out.buffer.flush.assert_called_once()

    def test_forward_stdout_broken_pipe_disables(self):
        out, _ = self._stdout(BrokenPipeError())
        with mock.patch.object(sys, "stdout", out), \
                mock.patch.object(m, "redirect_stdout_to_devnull") as red:
            self.assertFalse(m.forward_stdout(b"x", True))
        red.assert_called_once()

    def test_forward_stdout_epipe_oserror_disables(self):
        exc = OSError("pipe")  # plain OSError (not the BrokenPipeError subclass) carrying EPIPE
        exc.errno = errno.EPIPE
        out, _ = self._stdout(exc)
        with mock.patch.object(sys, "stdout", out), \
                mock.patch.object(m, "redirect_stdout_to_devnull") as red:
            self.assertFalse(m.forward_stdout(b"x", True))
        red.assert_called_once()

    def test_forward_stdout_other_oserror_propagates(self):
        out, _ = self._stdout(OSError(errno.ENOSPC, "full"))
        with mock.patch.object(sys, "stdout", out), \
                mock.patch.object(m, "redirect_stdout_to_devnull") as red:
            with self.assertRaises(OSError):
                m.forward_stdout(b"x", True)
        red.assert_not_called()


class TerminalQueryTest(unittest.TestCase):
    def _answers(self, chunk):
        written = []
        with mock.patch.object(m.os, "write", lambda fd, data: written.append((fd, data))):
            m.answer_terminal_queries(9, chunk)
        return written

    def test_each_query(self):
        self.assertEqual(self._answers(b"\x1b[6n"), [(9, b"\x1b[1;1R")])
        self.assertEqual(self._answers(b"\x1b]10;?\x1b\\"), [(9, b"\x1b]10;rgb:ffff/ffff/ffff\x1b\\")])
        self.assertEqual(self._answers(b"\x1b]11;?\x1b\\"), [(9, b"\x1b]11;rgb:0000/0000/0000\x1b\\")])
        self.assertEqual(self._answers(b"\x1b[c"), [(9, b"\x1b[?1;2c")])
        self.assertEqual(self._answers(b"\x1b[?u"), [(9, b"\x1b[?0u")])

    def test_no_query_no_write_and_multiple_in_order(self):
        self.assertEqual(self._answers(b"plain"), [])
        out = self._answers(b"\x1b[?u\x1b[6n")
        self.assertEqual([d for _, d in out], [b"\x1b[1;1R", b"\x1b[?0u"])


class ChildReturncodeTest(unittest.TestCase):
    def _rc(self, result=None, exc=None):
        with mock.patch.object(m.os, "waitpid", side_effect=exc, return_value=result):
            return m.child_returncode(1)

    def test_variants(self):
        self.assertEqual(self._rc(exc=ChildProcessError()), (True, 0))
        self.assertEqual(self._rc((0, 0)), (False, None))
        self.assertEqual(self._rc((1, 3 << 8)), (True, 3))
        self.assertEqual(self._rc((1, signal.SIGKILL)), (True, 128 + signal.SIGKILL))
        self.assertEqual(self._rc((1, 0x137F)), (True, 1))  # stopped, neither exited nor signaled

    def test_real_child(self):
        pid = os.fork()
        if pid == 0:
            os._exit(7)
        for _ in range(200):
            exited, rc = m.child_returncode(pid)
            if exited:
                break
            import time
            time.sleep(0.01)
        self.assertEqual((exited, rc), (True, 7))


class TerminateChildTest(unittest.TestCase):
    def _run(self, returncodes, kill_exc=None, killpg_exc=None, waitpid_exc=None):
        sigs = []
        clock = {"t": 0.0}

        def kill(pid, sig):
            sigs.append(("kill", sig))
            if kill_exc:
                raise kill_exc

        def killpg(pid, sig):
            sigs.append(("killpg", sig))
            if killpg_exc:
                raise killpg_exc

        def sleep(s):
            clock["t"] += 1.0

        rcs = iter(returncodes)
        with mock.patch.object(m.os, "kill", kill), mock.patch.object(m.os, "killpg", killpg), \
                mock.patch.object(m.time, "monotonic", lambda: clock["t"]), \
                mock.patch.object(m.time, "sleep", sleep), \
                mock.patch.object(m, "child_returncode", lambda pid: next(rcs, (False, None))), \
                mock.patch.object(m.os, "waitpid", side_effect=waitpid_exc, return_value=(0, 0)) as wp:
            m.terminate_child(5, grace=3.0)
        return sigs, wp

    def test_exits_after_sigterm(self):
        sigs, wp = self._run([(False, None), (True, 0)])
        self.assertEqual(sigs, [("kill", signal.SIGTERM), ("killpg", signal.SIGTERM)])
        wp.assert_not_called()

    def test_escalates_to_sigkill(self):
        sigs, wp = self._run([(False, None)] * 3 + [(True, 0)])
        self.assertIn(("kill", signal.SIGKILL), sigs)
        self.assertEqual(sigs[0], ("kill", signal.SIGTERM))
        wp.assert_not_called()

    def test_gives_up_after_sigkill_with_final_waitpid(self):
        sigs, wp = self._run([(False, None)] * 50)
        self.assertEqual([s for s in sigs if s[1] == signal.SIGKILL],
                         [("kill", signal.SIGKILL), ("killpg", signal.SIGKILL)])
        wp.assert_called_once_with(5, os.WNOHANG)

    def test_final_waitpid_childprocesserror_is_swallowed(self):
        self._run([(False, None)] * 50, waitpid_exc=ChildProcessError())

    def test_signal_errors_are_swallowed(self):
        sigs, _ = self._run([(True, 0)], kill_exc=ProcessLookupError(), killpg_exc=PermissionError())
        self.assertEqual(sigs, [("kill", signal.SIGTERM), ("killpg", signal.SIGTERM)])


# --------------------------------------------------------------------------- main()


class Script:
    """Scripted terminal: one step per main-loop iteration."""

    def __init__(self, steps, start=0.0):
        self.steps = steps
        self.start = start
        self.calls = 0
        self.cur = {}
        self.writes = []
        self.terminated = []
        self.closed = []

    def monotonic(self):
        n = self.calls
        self.calls += 1
        if n == 0:
            return self.start
        if n > len(self.steps):
            raise RuntimeError("script exhausted: main loop did not terminate")
        self.cur = self.steps[n - 1]
        return self.cur["now"]

    def select(self, rl, wl, xl, timeout=None):
        return ([FAKE_FD], [], []) if self.cur.get("read") is not None else ([], [], [])

    def read(self, fd, n):
        value = self.cur["read"]
        if isinstance(value, BaseException):
            raise value
        return value

    def write(self, fd, data):
        self.writes.append(data)
        return len(data)

    def rc(self, pid):
        return self.cur.get("rc", (False, None))


def step(now, read=None, rc=None):
    d = {"now": now}
    if read is not None:
        d["read"] = read
    if rc is not None:
        d["rc"] = rc
    return d


class MainBase(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.tmp = Path(tmp.name)
        self.prompt = self.tmp / "prompt.txt"
        self.prompt.write_text(PROMPT_TEXT.decode(), encoding="utf-8")
        self.transcript = self.tmp / "transcript.bin"
        self.base_env = {
            "CODEX_BIN": "/fake/codex",
            "CODEX_WORK_DIR": str(self.tmp),
            "CODEX_PROMPT_FILE": str(self.prompt),
            "CODEX_TRANSCRIPT_FILE": str(self.transcript),
        }

    def env(self, **extra):
        keys = [k for k in os.environ if k.startswith(("CODEX_", "SB_E2E", "SB_AGENT_CODEX"))]
        env = {k: v for k, v in os.environ.items() if k not in keys}
        env.update(self.base_env)
        env.update(extra)
        return env

    def run_main(self, steps, start=0.0, ioctl_exc=None, fcntl_exc=None, close_exc=None, **env_extra):
        s = Script(steps, start)
        stderr = io.StringIO()
        forwarded = []

        def close(fd):
            s.closed.append(fd)
            if close_exc:
                raise close_exc

        def forward(chunk, enabled):
            forwarded.append(chunk)
            return enabled

        with mock.patch.dict(os.environ, self.env(**env_extra), clear=True), \
                mock.patch.object(m.pty, "fork", return_value=(FAKE_PID, FAKE_FD)), \
                mock.patch.object(m.fcntl, "ioctl", side_effect=ioctl_exc), \
                mock.patch.object(m.fcntl, "fcntl", side_effect=fcntl_exc, return_value=0), \
                mock.patch.object(m.time, "monotonic", s.monotonic), \
                mock.patch.object(m.select, "select", s.select), \
                mock.patch.object(m.os, "read", s.read), \
                mock.patch.object(m.os, "write", s.write), \
                mock.patch.object(m.os, "close", close), \
                mock.patch.object(m, "child_returncode", s.rc), \
                mock.patch.object(m, "terminate_child", lambda pid, **k: s.terminated.append(pid)), \
                mock.patch.object(m, "forward_stdout", forward), \
                contextlib.redirect_stderr(stderr):
            try:
                rc = m.main()
            except BaseException as exc:  # noqa: BLE001 - returned for assertion
                rc = exc
        s.stderr = stderr.getvalue()
        s.forwarded = forwarded
        return rc, s


class MainArgumentsTest(MainBase):
    def child_args(self, **env_extra):
        calls = []
        with mock.patch.dict(os.environ, self.env(**env_extra), clear=True), \
                mock.patch.object(m.pty, "fork", return_value=(0, FAKE_FD)), \
                mock.patch.object(m.os, "chdir", side_effect=lambda p: calls.append(("chdir", p))), \
                mock.patch.object(m.os, "execvpe", side_effect=lambda *a: calls.append(("exec", a))):
            with self.assertRaises(SystemExit) as cm:
                m.main()
        self.assertEqual(cm.exception.code, 127)
        self.assertEqual(calls[0], ("chdir", str(self.tmp)))
        _, (cli, args, env) = calls[1]
        return cli, args, env

    def test_missing_required_env_returns_2(self):
        for missing in ("CODEX_BIN", "CODEX_WORK_DIR", "CODEX_PROMPT_FILE"):
            env = self.env()
            env[missing] = ""
            err = io.StringIO()
            with mock.patch.dict(os.environ, env, clear=True), contextlib.redirect_stderr(err):
                self.assertEqual(m.main(), 2)
            self.assertIn("CODEX_BIN, CODEX_WORK_DIR, and CODEX_PROMPT_FILE must be set", err.getvalue())

    def test_cli_falls_back_to_codex_cli_variable(self):
        env = self.env(CODEX_CLI="/alt/codex")
        del env["CODEX_BIN"]
        with mock.patch.dict(os.environ, env, clear=True), \
                mock.patch.object(m.pty, "fork", return_value=(0, FAKE_FD)), \
                mock.patch.object(m.os, "chdir"), \
                mock.patch.object(m.os, "execvpe") as ex:
            with self.assertRaises(SystemExit):
                m.main()
        self.assertEqual(ex.call_args[0][0], "/alt/codex")

    def test_default_arguments_include_prompt_last(self):
        cli, args, env = self.child_args()
        self.assertEqual(cli, "/fake/codex")
        self.assertEqual(args[:6], ["/fake/codex", "--cd", str(self.tmp), "--no-alt-screen",
                                    "--sandbox", "danger-full-access"])
        self.assertEqual(args[-1], self.prompt.read_text())
        self.assertEqual(len(args), 7)
        self.assertEqual(env["TERM"], "xterm-256color")

    def test_all_options(self):
        _, args, _ = self.child_args(
            CODEX_SANDBOX_MODE="read-only", CODEX_BYPASS="1", CODEX_BYPASS_HOOK_TRUST="1",
            CODEX_MODEL="gpt-x", CODEX_MODEL_PROVIDER="prov", CODEX_REASONING_EFFORT="high",
            CODEX_EXPERIMENTAL_USE_EXEC_COMMAND_TOOL="true")
        self.assertEqual(args[4:6], ["--sandbox", "read-only"])
        self.assertIn("--dangerously-bypass-approvals-and-sandbox", args)
        self.assertIn("--dangerously-bypass-hook-trust", args)
        self.assertEqual(args[args.index("--model") + 1], "gpt-x")
        configs = [args[i + 1] for i, a in enumerate(args) if a == "--config"]
        self.assertEqual(configs, ["model_provider=prov", "model_reasoning_effort=high",
                                   "experimental_use_exec_command_tool=true"])
        self.assertEqual(args[-1], self.prompt.read_text())

    def test_interactive_prompt_input_omits_prompt_argument(self):
        _, args, _ = self.child_args(CODEX_INTERACTIVE_PROMPT_INPUT="1")
        self.assertNotIn(self.prompt.read_text(), args)

    def test_enterprise_matrix_forces_hook_trust_flags(self):
        _, args, _ = self.child_args(SB_E2E_ENTERPRISE_MATRIX="1")
        self.assertIn("--dangerously-bypass-hook-trust", args)
        _, args, _ = self.child_args(SB_E2E_ENTERPRISE_MATRIX="1", CODEX_BYPASS_HOOK_TRUST="1",
                                     CODEX_AUTO_TRUST_HOOKS="1")
        self.assertEqual(args.count("--dangerously-bypass-hook-trust"), 1)

    def test_child_environment_is_sanitized(self):
        with mock.patch.dict(os.environ, {"CODEX_THREAD_ID": "abc"}):
            _, _, env = self.child_args()
        self.assertNotIn("CODEX_THREAD_ID", env)


class MainLoopTest(MainBase):
    def test_hard_timeout(self):
        rc, s = self.run_main([step(10)], CODEX_INTERACTIVE_TIMEOUT="10")
        self.assertEqual(rc, 1)
        self.assertIn("hard timeout (10s) exceeded", s.stderr)
        self.assertEqual(s.terminated, [FAKE_PID])
        self.assertEqual(s.closed, [FAKE_FD])

    def test_pty_setup_failures_are_tolerated(self):
        rc, s = self.run_main([step(10)], ioctl_exc=OSError("ioctl"), fcntl_exc=OSError("fcntl"),
                              CODEX_INTERACTIVE_TIMEOUT="10")
        self.assertEqual(rc, 1)

    def test_eagain_continues_then_idle_watchdog(self):
        again = OSError(errno.EAGAIN, "again")
        rc, s = self.run_main([step(1, again), step(6, again)], CODEX_INTERACTIVE_IDLE_TIMEOUT="5")
        self.assertEqual(rc, 1)
        self.assertIn("no substantive Codex PTY output for 5s (idle watchdog)", s.stderr)
        self.assertEqual(s.terminated, [FAKE_PID])

    def test_other_read_error_propagates_and_closes_fd(self):
        rc, s = self.run_main([step(1, OSError(errno.EBADF, "bad"))], close_exc=OSError("closed"))
        self.assertIsInstance(rc, OSError)
        self.assertEqual(rc.errno, errno.EBADF)
        self.assertEqual(s.closed, [FAKE_FD])

    def test_eof_returns_child_status(self):
        rc, s = self.run_main([step(1, b""), ], )
        self.assertEqual(rc, 0)  # child not yet reaped -> 0
        rc, s = self.run_main([step(1, b"", rc=(True, 5))])
        self.assertEqual(rc, 5)
        rc, s = self.run_main([step(1, b"", rc=(True, None))])
        self.assertEqual(rc, 0)

    def test_pty_eio_when_child_exits_is_treated_as_eof(self):
        # Linux reports EIO (not EOF) on the master once the child side is closed.
        eio = OSError(errno.EIO, "Input/output error")
        rc, s = self.run_main([step(1, eio, rc=(True, 3))])
        self.assertEqual(rc, 3)
        self.assertEqual(s.closed, [FAKE_FD])
        rc, s = self.run_main([step(1, eio, rc=(True, None))])
        self.assertEqual(rc, 0)

    def test_pty_eio_waits_for_child_to_become_reapable(self):
        eio = OSError(errno.EIO, "Input/output error")
        outcomes = iter([(False, None), (False, None), (True, 9)])
        sleeps = []
        steps = [step(1, eio)]
        s = Script(steps)
        with mock.patch.dict(os.environ, self.env(), clear=True), \
                mock.patch.object(m.pty, "fork", return_value=(FAKE_PID, FAKE_FD)), \
                mock.patch.object(m.fcntl, "ioctl"), mock.patch.object(m.fcntl, "fcntl", return_value=0), \
                mock.patch.object(m.time, "monotonic", s.monotonic), \
                mock.patch.object(m.time, "sleep", sleeps.append), \
                mock.patch.object(m.select, "select", s.select), mock.patch.object(m.os, "read", s.read), \
                mock.patch.object(m.os, "write", s.write), mock.patch.object(m.os, "close", lambda fd: None), \
                mock.patch.object(m, "child_returncode", lambda pid: next(outcomes)), \
                mock.patch.object(m, "forward_stdout", lambda c, e: e):
            self.assertEqual(m.main(), 9)
        self.assertEqual(sleeps, [0.05, 0.05])

    def test_pty_eio_with_unreapable_child_gives_up_with_zero(self):
        eio = OSError(errno.EIO, "Input/output error")
        sleeps = []
        s = Script([step(1, eio)])
        with mock.patch.dict(os.environ, self.env(), clear=True), \
                mock.patch.object(m.pty, "fork", return_value=(FAKE_PID, FAKE_FD)), \
                mock.patch.object(m.fcntl, "ioctl"), mock.patch.object(m.fcntl, "fcntl", return_value=0), \
                mock.patch.object(m.time, "monotonic", s.monotonic), \
                mock.patch.object(m.time, "sleep", sleeps.append), \
                mock.patch.object(m.select, "select", s.select), mock.patch.object(m.os, "read", s.read), \
                mock.patch.object(m.os, "write", s.write), mock.patch.object(m.os, "close", lambda fd: None), \
                mock.patch.object(m, "child_returncode", lambda pid: (False, None)), \
                mock.patch.object(m, "forward_stdout", lambda c, e: e):
            self.assertEqual(m.main(), 0)
        self.assertEqual(len(sleeps), 40)

    def test_child_exit_between_reads(self):
        rc, s = self.run_main([step(1, rc=(True, 4))])
        self.assertEqual(rc, 4)
        rc, s = self.run_main([step(1, rc=(True, 0))])
        self.assertEqual(rc, 0)

    def test_idle_watchdog_without_reads(self):
        rc, s = self.run_main([step(1), step(6)], CODEX_INTERACTIVE_IDLE_TIMEOUT="5")
        self.assertEqual(rc, 1)
        self.assertIn("idle watchdog", s.stderr)

    def test_chunk_is_answered_logged_and_forwarded(self):
        chunk = b"\x1b[6nhello"
        rc, s = self.run_main([step(1, chunk), step(2, b""), ])
        self.assertEqual(s.writes[0], b"\x1b[1;1R")
        self.assertEqual(self.transcript.read_bytes(), chunk)
        self.assertEqual(s.forwarded, [chunk])

    def test_noise_only_output_does_not_count_as_activity(self):
        rc, s = self.run_main([step(3, b"1/2"), step(6, b"\n")], CODEX_INTERACTIVE_IDLE_TIMEOUT="5")
        self.assertEqual(rc, 1)
        self.assertIn("idle watchdog", s.stderr)

    def test_real_output_resets_idle_clock(self):
        rc, s = self.run_main([step(3, b"real text"), step(6, b"more text"), step(7, b"")],
                              CODEX_INTERACTIVE_IDLE_TIMEOUT="5")
        self.assertEqual(rc, 0)

    def test_continue_anyway_prompt_is_confirmed(self):
        rc, s = self.run_main([step(1, b"Continue anyway? [y/N]: "), step(2, b"")])
        self.assertIn(b"y\r", s.writes)

    def test_model_selection_prompt_picks_existing_model(self):
        for text in (b"Choose how you'd like to proceed\nUse existing model", b"Try new model\nUse existing model"):
            rc, s = self.run_main([step(1, text), step(2, b"")])
            self.assertIn(b"\x1b[B\r", s.writes)
        rc, s = self.run_main([step(1, b"Choose how you would like\nUse existing model"), step(2, b"")])
        self.assertIn(b"\x1b[B\r", s.writes)
        rc, s = self.run_main([step(1, b"Try new model only"), step(2, b"")])
        self.assertNotIn(b"\x1b[B\r", s.writes)

    def test_workspace_trust_prompt(self):
        text = b"Do you trust the contents of this directory?"
        rc, s = self.run_main([step(1, text)])
        self.assertEqual(rc, 1)
        self.assertIn("interactive workspace trust prompt surfaced", s.stderr)
        rc, s = self.run_main([step(1, text), step(2, b"")], CODEX_AUTO_TRUST_HOOKS="1")
        self.assertEqual(s.writes, [b"\r"])

    def test_hook_trust_review_without_auto_trust_fails(self):
        rc, s = self.run_main([step(1, b"Hooks need review")])
        self.assertEqual(rc, 1)
        self.assertIn("interactive hook trust review surfaced", s.stderr)
        rc, s = self.run_main([step(1, b"Trust all and continue")])
        self.assertEqual(rc, 1)

    def test_hook_trust_review_auto_then_confirm(self):
        rc, s = self.run_main(
            [step(1, b"Hooks need review"), step(2, b"Press enter to confirm or esc to go back"), step(3, b"")],
            CODEX_AUTO_TRUST_HOOKS="1")
        self.assertEqual(s.writes, [b"2\r", b"\x1b[B\r", b"\r"])

    def test_hook_confirm_text_ignored_unless_pending(self):
        rc, s = self.run_main([step(1, b"Press enter to confirm or esc to go back"), step(2, b"")])
        self.assertEqual(s.writes, [])

    def test_prompt_submission_and_completion(self):
        prompt_prefix = PROMPT_TEXT
        rc, s = self.run_main([
            step(1, READY + prompt_prefix),
            step(2, b"doing things"),
            step(3, b"Worked for 3s \xe2\x80\xba"),
        ])
        self.assertEqual(rc, 0)
        self.assertEqual(s.writes, [b"\r"])
        self.assertEqual(s.terminated, [FAKE_PID])

    def test_default_flow_waits_while_prompt_not_visible(self):
        rc, s = self.run_main([step(1, READY), step(2, b"")])
        self.assertEqual(s.writes, [])

    def test_interactive_input_types_prompt_then_submits_after_delay(self):
        rc, s = self.run_main([
            step(1, READY),
            step(1.5, b"x"),     # typed 0.5s ago, prompt not echoed yet: keep waiting
            step(2.5, b"y"),     # >= 1s since typing: submit
            step(3, b""),
        ], CODEX_INTERACTIVE_PROMPT_INPUT="1")
        self.assertEqual(s.writes, [self.prompt.read_bytes(), b"\r"])

    def test_interactive_input_submits_when_prompt_is_echoed(self):
        rc, s = self.run_main([
            step(1, READY),
            step(1.1, PROMPT_TEXT),
            step(2, b""),
        ], CODEX_INTERACTIVE_PROMPT_INPUT="1")
        self.assertEqual(s.writes, [self.prompt.read_bytes(), b"\r"])

    def test_empty_prompt_never_counts_as_visible(self):
        self.prompt.write_text("", encoding="utf-8")
        rc, s = self.run_main([step(1, READY), step(2, b"")])
        self.assertEqual(s.writes, [])

    def test_completion_requires_output_after_submit(self):
        # Prompt submitted; the completion marker alone (no post-submit output) is not trusted.
        rc, s = self.run_main([
            step(1, READY + PROMPT_TEXT),
            step(2, b"   \n"),                       # whitespace only: not substantive output
            step(3, b"Worked for 1s \xe2\x80\xba"),  # now substantive and complete
        ])
        self.assertEqual(rc, 0)

    def test_quiet_timeout_after_output(self):
        submit = READY + PROMPT_TEXT
        rc, s = self.run_main([step(1, submit), step(2, b"partial output"), step(3), step(8)],
                              CODEX_INTERACTIVE_QUIET_TIMEOUT="5")
        self.assertEqual(rc, 0)
        self.assertEqual(s.terminated, [FAKE_PID])

    def test_not_quiet_yet_keeps_waiting(self):
        submit = READY + PROMPT_TEXT
        rc, s = self.run_main([step(1, submit), step(2, b"partial output"), step(3), step(10)],
                              CODEX_INTERACTIVE_QUIET_TIMEOUT="5", CODEX_INTERACTIVE_TIMEOUT="10")
        self.assertEqual(rc, 1)  # ended by hard timeout, not by the quiet shortcut

    def test_ready_timeout_when_prompt_not_accepted(self):
        submit = READY + PROMPT_TEXT
        rc, s = self.run_main([step(1, submit), step(2), step(30)], CODEX_INTERACTIVE_READY_TIMEOUT="20")
        self.assertEqual(rc, 1)
        self.assertIn("timed out waiting for Codex to accept the submitted prompt", s.stderr)

    def test_waiting_for_cli_to_become_ready_loops(self):
        rc, s = self.run_main([step(5), step(25), step(26, b""), ], CODEX_INTERACTIVE_READY_TIMEOUT="20")
        self.assertEqual(rc, 0)
        self.assertEqual(s.terminated, [])

    def test_ready_but_unsubmitted_then_eof(self):
        rc, s = self.run_main([step(25, READY), step(26, b"")], CODEX_INTERACTIVE_READY_TIMEOUT="20")
        self.assertEqual(rc, 0)


class RealPtyStubCliTest(unittest.TestCase):
    """Drive the real script against a stub CLI over a real PTY (no Codex involved)."""

    def _run(self, body):
        import subprocess
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            cli = d / "fake-codex"
            cli.write_text("#!/usr/bin/env bash\n" + body + "\n")
            cli.chmod(0o755)
            prompt = d / "prompt.txt"
            prompt.write_text("do it")
            env = {k: v for k, v in os.environ.items() if not k.startswith("CODEX_")}
            env.update(CODEX_BIN=str(cli), CODEX_WORK_DIR=str(d), CODEX_PROMPT_FILE=str(prompt),
                       CODEX_INTERACTIVE_TIMEOUT="30", CODEX_INTERACTIVE_READY_TIMEOUT="5")
            return subprocess.run([sys.executable, str(REPO_ROOT / "scripts" / "codex-interactive-invoke.py")],
                                  env=env, capture_output=True, text=True, timeout=60)

    def test_child_exit_status_is_propagated_without_traceback(self):
        proc = self._run("echo hello-from-stub\nexit 3")
        self.assertEqual(proc.returncode, 3, proc.stderr)
        self.assertNotIn("Traceback", proc.stderr)
        self.assertIn("hello-from-stub", proc.stdout)

    def test_clean_child_exit_returns_zero(self):
        proc = self._run("echo done\nexit 0")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertNotIn("Traceback", proc.stderr)


class EntrypointTest(unittest.TestCase):
    def test_script_exits_with_main_status(self):
        with mock.patch.dict(os.environ, {"CODEX_BIN": "", "CODEX_CLI": "", "CODEX_WORK_DIR": "",
                                          "CODEX_PROMPT_FILE": ""}), \
                contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit) as cm:
                runpy.run_path(str(REPO_ROOT / "scripts" / "codex-interactive-invoke.py"), run_name="__main__")
        self.assertEqual(cm.exception.code, 2)


if __name__ == "__main__":
    unittest.main()
