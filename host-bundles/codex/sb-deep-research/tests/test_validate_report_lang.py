#!/usr/bin/env python3
"""Language-aware validate_report tests for en/zh profiles."""

import os
import subprocess
import sys
import unittest

SKILL_ROOT = os.path.join(os.path.dirname(__file__), '..')
VALIDATE = os.path.join(SKILL_ROOT, 'scripts', 'validate_report.py')
FIXTURES = os.path.join(os.path.dirname(__file__), 'fixtures')


class TestValidateReportLang(unittest.TestCase):
    def _run(self, report: str, lang: str) -> int:
        result = subprocess.run(
            [sys.executable, VALIDATE, '--report', report, '--lang', lang],
            capture_output=True, text=True,
        )
        return result.returncode

    def test_valid_en_passes(self):
        report = os.path.join(FIXTURES, 'valid_report.md')
        self.assertEqual(self._run(report, 'en'), 0)

    def test_broken_en_fails_forecast(self):
        report = os.path.join(FIXTURES, 'broken_en_forecast.md')
        self.assertEqual(self._run(report, 'en'), 1)

    def test_valid_zh_passes(self):
        report = os.path.join(FIXTURES, 'valid_report_zh.md')
        self.assertEqual(self._run(report, 'zh'), 0)

    def test_broken_zh_fails_structure(self):
        report = os.path.join(FIXTURES, 'broken_zh_structure.md')
        self.assertEqual(self._run(report, 'zh'), 1)

    def test_ordinary_research_no_checkpoint_trigger(self):
        """Valid quick report should pass without human-checkpoint artifacts."""
        report = os.path.join(FIXTURES, 'valid_report.md')
        self.assertEqual(self._run(report, 'en'), 0)


if __name__ == '__main__':
    unittest.main()
