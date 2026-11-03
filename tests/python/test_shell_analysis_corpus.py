"""Table-driven corpus test for the shell-command analyzer and its legacy CLIs.

tests/fixtures/shell-analysis/corpus.json holds the bypasses from review findings
R1-01/02/03/12/13/28, R2-02, R4-04 and R5-05 next to an equally large set of honest
commands. Each case states what the analyzer (hooks/lib/tool-input/shell_analysis.py)
must report and, where the legacy CLIs make a promise, what they must print:

* command_looks_read_only.py exits 0 only for read-only commands (``read_only``);
* candidate_write_paths.py prints the paths a command may write (``writes``).
"""

from __future__ import annotations

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from sbtest import REPO_ROOT
from tool_input_support import TOOL_INPUT_DIR, run_tool_input_script

CORPUS = json.loads((REPO_ROOT / "tests/fixtures/shell-analysis/corpus.json").read_text(encoding="utf-8"))
TIER_RANK = {"none": 0, "intermediate": 1, "completion": 2}


def analyzer():
    if str(TOOL_INPUT_DIR) not in sys.path:
        sys.path.insert(0, str(TOOL_INPUT_DIR))
    import shell_analysis  # noqa: PLC0415 - imported lazily so a missing module fails per test

    return shell_analysis


class CorpusShapeTest(unittest.TestCase):
    def test_corpus_ids_are_unique_and_both_sides_are_large(self):
        ids = [c["id"] for c in CORPUS]
        self.assertEqual(len(ids), len(set(ids)))
        gated = [c for c in CORPUS if c.get("tier") not in (None, "none")]
        honest = [c for c in CORPUS if c.get("tier") == "none"]
        self.assertGreaterEqual(len(gated), 100)
        self.assertGreaterEqual(len(honest), len(gated))


class CorpusEnvMixin:
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        root = Path(self._tmp.name).resolve()
        self.base = root / "work"
        self.home = root / "home"
        self.base.mkdir()
        self.home.mkdir()
        patcher = mock.patch.dict(os.environ, {"HOME": str(self.home)})
        patcher.start()
        self.addCleanup(patcher.stop)

    def tearDown(self):
        self._tmp.cleanup()

    def expected_path(self, rel):
        if rel.startswith("~/"):
            return str(self.home / rel[2:])
        if rel.startswith("/"):
            return rel
        return str(self.base / rel)


class LegacyCliCorpusTest(CorpusEnvMixin, unittest.TestCase):
    def test_read_only_verdicts(self):
        for case in CORPUS:
            if "read_only" not in case:
                continue
            with self.subTest(id=case["id"], cmd=case["cmd"]):
                res = run_tool_input_script("command_looks_read_only.py", case["cmd"])
                self.assertEqual(res.code == 0, case["read_only"], f"[{case['finding']}] {case['cmd']!r}")

    def test_write_paths(self):
        for case in CORPUS:
            if "writes" not in case and not case.get("no_writes"):
                continue
            with self.subTest(id=case["id"], cmd=case["cmd"]):
                res = run_tool_input_script("candidate_write_paths.py", str(self.base), case["cmd"])
                self.assertEqual(res.code, 0)
                if case.get("no_writes"):
                    self.assertEqual(res.lines, [], case["cmd"])
                for rel in case.get("writes", []):
                    self.assertIn(self.expected_path(rel), res.lines, f"[{case['finding']}] {case['cmd']!r}")


class AnalyzerCorpusTest(CorpusEnvMixin, unittest.TestCase):
    def analyze(self, cmd):
        return analyzer().analyze_command(cmd, base_dir=str(self.base))

    def test_tiers_and_actions(self):
        for case in CORPUS:
            if "tier" not in case:
                continue
            with self.subTest(id=case["id"], cmd=case["cmd"]):
                res = self.analyze(case["cmd"])
                effective = res["tier"]
                if res["could_be_delivery"] and TIER_RANK[res["possible_tier"]] > TIER_RANK[effective]:
                    effective = res["possible_tier"]
                self.assertEqual(effective, case["tier"], f"[{case['finding']}] {case['cmd']!r}: {res}")
                if "actions" in case:
                    self.assertEqual(res["actions"], case["actions"], case["cmd"])
                if "possible" in case:
                    self.assertEqual(res["possible_actions"], case["possible"], case["cmd"])
                    self.assertTrue(res["could_be_delivery"], case["cmd"])
                if "opaque" in case:
                    self.assertEqual(res["opaque"], case["opaque"], case["cmd"])

    def test_read_only_verdicts(self):
        for case in CORPUS:
            if "strict_read_only" not in case:
                continue
            with self.subTest(id=case["id"], cmd=case["cmd"]):
                res = self.analyze(case["cmd"])
                self.assertEqual(res["read_only"], case["strict_read_only"], case["cmd"])
                self.assertEqual(res["read_only_legacy"], case["read_only"], case["cmd"])

    def test_write_paths(self):
        for case in CORPUS:
            if "writes" not in case and not case.get("no_writes"):
                continue
            with self.subTest(id=case["id"], cmd=case["cmd"]):
                res = self.analyze(case["cmd"])
                if case.get("no_writes"):
                    self.assertEqual(res["write_paths"], [], case["cmd"])
                for rel in case.get("writes", []):
                    self.assertIn(self.expected_path(rel), res["write_paths"], case["cmd"])


if __name__ == "__main__":
    unittest.main()
