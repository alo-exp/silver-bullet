"""Unit tests for scripts/lib/agent_fifo.py (R4-22)."""

import os
import tempfile
import threading
import time
import unittest

from sbtest import load_module

agent_fifo = load_module("scripts/lib/agent_fifo.py")


class FifoTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.path = os.path.join(self.tmp.name, "f.fifo")
        os.mkfifo(self.path)

    def test_writer_times_out_without_reader(self):
        start = time.monotonic()
        with self.assertRaises(TimeoutError):
            agent_fifo.open_writer(self.path, 0.3)
        self.assertLess(time.monotonic() - start, 3)

    def test_writer_reraises_other_errors(self):
        import errno
        from unittest import mock

        with mock.patch.object(agent_fifo.os, "open", side_effect=OSError(errno.EACCES, "denied")):
            with self.assertRaises(OSError):
                agent_fifo.open_writer(self.path, 0.1)

    def test_missing_path_times_out(self):
        with self.assertRaises(TimeoutError):
            agent_fifo.open_writer(os.path.join(self.tmp.name, "missing"), 0.1)

    def test_write_line_reaches_a_late_reader(self):
        got = []

        def reader():
            time.sleep(0.3)
            fd = os.open(self.path, os.O_RDONLY)
            got.append(os.read(fd, 100))
            os.close(fd)

        thread = threading.Thread(target=reader)
        thread.start()
        agent_fifo.write_line(self.path, '{"op": "abort"}  ', 5)
        thread.join()
        self.assertEqual(got, [b'{"op": "abort"}\n'])

    def test_read_line_returns_data_and_stops_at_newline(self):
        def writer():
            time.sleep(0.2)
            fd = os.open(self.path, os.O_WRONLY)
            os.write(fd, b"ab")
            time.sleep(0.2)
            os.write(fd, b"c\nrest")
            os.close(fd)

        thread = threading.Thread(target=writer)
        thread.start()
        data = agent_fifo.read_line(self.path, 5)
        thread.join()
        self.assertTrue(data.startswith(b"ab"))
        self.assertIn(b"c\n", data)

    def test_read_line_returns_data_on_eof_without_newline(self):
        def writer():
            time.sleep(0.2)
            fd = os.open(self.path, os.O_WRONLY)
            os.write(fd, b"partial")
            os.close(fd)

        thread = threading.Thread(target=writer)
        thread.start()
        data = agent_fifo.read_line(self.path, 5)
        thread.join()
        self.assertEqual(data, b"partial")

    def test_read_line_times_out_empty_without_writer(self):
        start = time.monotonic()
        self.assertEqual(agent_fifo.read_line(self.path, 0.5), b"")
        self.assertLess(time.monotonic() - start, 3)

    def test_read_line_handles_would_block(self):
        calls = []
        real_read = os.read

        def flaky(fd, n):
            if not calls:
                calls.append(1)
                raise BlockingIOError()
            return real_read(fd, n)

        def writer():
            time.sleep(0.2)
            fd = os.open(self.path, os.O_WRONLY)
            os.write(fd, b"x\n")
            os.close(fd)

        thread = threading.Thread(target=writer)
        thread.start()
        os.read = flaky
        try:
            data = agent_fifo.read_line(self.path, 5)
        finally:
            os.read = real_read
        thread.join()
        self.assertEqual(data, b"x\n")


if __name__ == "__main__":
    unittest.main()
