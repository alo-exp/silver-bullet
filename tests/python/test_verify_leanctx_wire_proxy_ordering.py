"""Unit tests for scripts/lib/verify-leanctx-wire-proxy-ordering.py."""
from __future__ import annotations

import contextlib
import io
import json
import runpy
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from sbtest import REPO_ROOT, load_module

REL = "scripts/lib/verify-leanctx-wire-proxy-ordering.py"
m = load_module(REL)


def good(**over):
    data = {
        "schema": m.SCHEMA_ID,
        "host": "codex",
        "messages": [
            {"index": 0, "role": "system", "id": "a"},
            {"index": 1, "role": "user", "id": "b"},
        ],
    }
    data.update(over)
    return data


class ValidateTest(unittest.TestCase):
    def test_valid_payload_has_no_errors(self):
        self.assertEqual(m.validate_wire_proxy_ordering(good()), [])

    def test_all_roles_accepted_and_id_optional(self):
        msgs = [{"index": i, "role": r} for i, r in enumerate(sorted(m.VALID_ROLES - {"system"}))]
        self.assertEqual(m.validate_wire_proxy_ordering(good(messages=msgs)), [])

    def test_wrong_schema(self):
        errs = m.validate_wire_proxy_ordering(good(schema="x"))
        self.assertEqual(len(errs), 1)
        self.assertIn("schema must be", errs[0])
        self.assertIn("'x'", errs[0])

    def test_messages_not_a_list(self):
        self.assertEqual(m.validate_wire_proxy_ordering(good(messages={})), ["messages must be an array"])

    def test_messages_empty(self):
        self.assertEqual(m.validate_wire_proxy_ordering(good(messages=[])), ["messages must be non-empty"])

    def test_entry_not_object(self):
        errs = m.validate_wire_proxy_ordering(good(messages=["x"]))
        self.assertIn("messages[0] must be an object", errs)
        self.assertIn("missing message indices: [0]", errs)

    def test_index_must_be_int(self):
        errs = m.validate_wire_proxy_ordering(good(messages=[{"index": "0", "role": "user"}]))
        self.assertIn("messages[0].index must be an integer", errs)

    def test_reordered_and_duplicate_index(self):
        msgs = [{"index": 1, "role": "user"}, {"index": 1, "role": "user"}]
        errs = m.validate_wire_proxy_ordering(good(messages=msgs))
        self.assertTrue(any("messages[0].index=1 does not match array position 0" in e for e in errs))
        self.assertIn("duplicate message index 1", errs)
        self.assertIn("missing message indices: [0]", errs)

    def test_unexpected_index(self):
        errs = m.validate_wire_proxy_ordering(good(messages=[{"index": 5, "role": "user"}]))
        self.assertIn("unexpected message indices: [5]", errs)
        self.assertIn("missing message indices: [0]", errs)

    def test_unexpected_only(self):
        msgs = [{"index": 0, "role": "user"}, {"index": 0, "role": "user"}]
        errs = m.validate_wire_proxy_ordering(good(messages=msgs))
        self.assertIn("duplicate message index 0", errs)
        self.assertIn("missing message indices: [1]", errs)
        self.assertFalse(any("unexpected" in e for e in errs))

    def test_bad_roles(self):
        for role in ("robot", 3, None):
            errs = m.validate_wire_proxy_ordering(good(messages=[{"index": 0, "role": role}]))
            self.assertEqual(len(errs), 1)
            self.assertIn("messages[0].role must be one of", errs[0])

    def test_id_rules(self):
        msgs = [
            {"index": 0, "role": "user", "id": "x"},
            {"index": 1, "role": "user", "id": "x"},
            {"index": 2, "role": "user", "id": "  "},
            {"index": 3, "role": "user", "id": 4},
        ]
        errs = m.validate_wire_proxy_ordering(good(messages=msgs))
        self.assertIn("duplicate message id 'x'", errs)
        self.assertIn("messages[2].id must be a non-empty string when set", errs)
        self.assertIn("messages[3].id must be a non-empty string when set", errs)

    def test_system_must_be_first(self):
        msgs = [{"index": 0, "role": "user"}, {"index": 1, "role": "system"}]
        errs = m.validate_wire_proxy_ordering(good(messages=msgs))
        self.assertEqual(errs, ["system message must be first when present (prefix-cache contract)"])


class LoadPayloadTest(unittest.TestCase):
    def test_stdin_for_none_and_dash(self):
        for p in (None, Path("-")):
            with mock.patch("sys.stdin", io.StringIO('{"a": 1}')):
                self.assertEqual(m._load_payload(p), {"a": 1})

    def test_file(self):
        with tempfile.TemporaryDirectory() as d:
            f = Path(d) / "e.json"
            f.write_text('{"b": 2}', encoding="utf-8")
            self.assertEqual(m._load_payload(f), {"b": 2})

    def test_non_object_root(self):
        with mock.patch("sys.stdin", io.StringIO("[1]")):
            with self.assertRaisesRegex(ValueError, "root must be a JSON object"):
                m._load_payload(None)


class MainTest(unittest.TestCase):
    def run_main(self, *argv, stdin=""):
        out, err = io.StringIO(), io.StringIO()
        with mock.patch("sys.argv", ["v", *argv]), mock.patch("sys.stdin", io.StringIO(stdin)), \
             contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            rc = m.main()
        return rc, out.getvalue(), err.getvalue()

    def test_generate_fixture_is_valid(self):
        rc, out, _ = self.run_main("--generate-fixture")
        self.assertEqual(rc, 0)
        self.assertEqual(m.validate_wire_proxy_ordering(json.loads(out)), [])

    def test_valid_from_stdin(self):
        rc, out, err = self.run_main(stdin=json.dumps(good()))
        self.assertEqual(rc, 0)
        self.assertEqual(json.loads(out), {"status": "ok", "schema": m.SCHEMA_ID, "message_count": 2})
        self.assertEqual(err, "")

    def test_valid_from_file(self):
        with tempfile.TemporaryDirectory() as d:
            f = Path(d) / "e.json"
            f.write_text(json.dumps(good()))
            rc, out, _ = self.run_main(str(f))
        self.assertEqual(rc, 0)
        self.assertIn('"ok"', out)

    def test_invalid_returns_1_and_lists_errors(self):
        rc, out, err = self.run_main(stdin=json.dumps(good(schema="x", messages=[{"index": 0, "role": "nope"}])))
        self.assertEqual(rc, 1)
        self.assertEqual(out, "")
        self.assertEqual(err.count("INVALID: "), 2)

    def test_unreadable_bad_json_and_non_object_return_2(self):
        rc, _, err = self.run_main("/nonexistent/dir/evidence.json")
        self.assertEqual(rc, 2)
        self.assertTrue(err.startswith("ERROR: "))
        rc, _, err = self.run_main(stdin="{oops")
        self.assertEqual(rc, 2)
        self.assertTrue(err.startswith("ERROR: "))
        rc, _, err = self.run_main(stdin="[]")
        self.assertEqual((rc, err), (2, "ERROR: root must be a JSON object\n"))

    def test_module_entrypoint_exits_with_main_status(self):
        with mock.patch("sys.argv", ["v", "--generate-fixture"]), contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaises(SystemExit) as cm:
                runpy.run_path(str(REPO_ROOT / REL), run_name="__main__")
        self.assertEqual(cm.exception.code, 0)


if __name__ == "__main__":
    unittest.main()
