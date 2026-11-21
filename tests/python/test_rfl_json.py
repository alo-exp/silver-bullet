"""Unit tests for scripts/lib/rfl_json.py (bounded JSON reads)."""
from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from sbtest import load_module

rj = load_module("scripts/lib/rfl_json.py", name="rfl_json")


class BoundedJsonTest(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.tmp = Path(tmp.name)

    def file(self, text, name="f.json"):
        path = self.tmp / name
        path.write_text(text)
        return path

    def test_depth_of(self):
        self.assertEqual(rj.depth_of(1), 0)
        self.assertEqual(rj.depth_of({"a": [1, {"b": 2}]}), 3)
        self.assertGreater(rj.depth_of([[[[]]]], limit=2), 2)  # stops counting past the limit

    def test_loads_bounded(self):
        self.assertEqual(rj.loads_bounded('{"a": 1}'), {"a": 1})
        for text in ("[1]", "{x", "[" * 200000 + "]" * 200000, '{"a": ' * 40 + "1" + "}" * 40):
            with self.assertRaises(rj.BadJson, msg=text[:20]):
                rj.loads_bounded(text)
        with self.assertRaisesRegex(rj.BadJson, "larger than"):
            rj.loads_bounded('{"a": "' + "x" * 50 + '"}', max_bytes=20)
        self.assertEqual(rj.loads_bounded('{"a": [[1]]}', max_depth=3), {"a": [[1]]})

    def test_read_bounded(self):
        self.assertEqual(rj.read_bounded(self.file('{"k": 1}')), {"k": 1})
        with self.assertRaisesRegex(rj.BadJson, "missing"):
            rj.read_bounded(self.tmp / "none.json")
        with self.assertRaisesRegex(rj.BadJson, "missing"):
            rj.read_bounded(self.tmp)
        target = self.file("{}", "t.json")
        link = self.tmp / "l.json"
        link.symlink_to(target)
        with self.assertRaisesRegex(rj.BadJson, "not a regular file"):
            rj.read_bounded(link)
        with self.assertRaisesRegex(rj.BadJson, "larger than"):
            rj.read_bounded(self.file('{"a": "' + "x" * 50 + '"}'), max_bytes=20)
        bad = self.tmp / "bin.json"
        bad.write_bytes(b"\xff\xfe")
        with self.assertRaisesRegex(rj.BadJson, "unreadable"):
            rj.read_bounded(bad)


if __name__ == "__main__":
    unittest.main()
