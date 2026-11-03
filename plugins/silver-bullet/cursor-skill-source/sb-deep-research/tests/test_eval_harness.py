#!/usr/bin/env python3
"""Behavioral acceptance tests for eval harness."""

import json
import os
import subprocess
import sys
import tempfile
import unittest

SKILL_ROOT = os.path.join(os.path.dirname(__file__), '..')
CAPABILITY = os.path.join(SKILL_ROOT, 'scripts', 'capability_score.py')
VALIDATE_STRUCTURE = os.path.join(SKILL_ROOT, 'eval', 'validate_structure.py')
OFFLINE_FIXTURE = os.path.join(SKILL_ROOT, 'tests', 'test_offline_fixture.py')


class TestEvalHarness(unittest.TestCase):
    def test_capability_score_no_popularity_signals(self):
        result = subprocess.run(
            [sys.executable, CAPABILITY, '--skill-only'],
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0)
        data = json.loads(result.stdout)
        self.assertIn('dimensions', data)
        self.assertGreaterEqual(data['total'], 45)
        text = result.stdout.lower()
        self.assertNotIn('github stars', text)
        self.assertNotIn('install count', text)

    def test_validate_structure_rejects_incomplete(self):
        with tempfile.TemporaryDirectory() as d:
            result = subprocess.run(
                [sys.executable, VALIDATE_STRUCTURE, '--dir', d],
                capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 1)
            data = json.loads(result.stdout)
            self.assertEqual(data['status'], 'fail')
            self.assertTrue(data['missing'])

    def test_offline_fixture_passes_structure(self):
        offline_test = os.path.join(SKILL_ROOT, 'tests', 'test_offline_fixture.py')
        with tempfile.TemporaryDirectory() as d:
            # Reuse offline fixture writer via subprocess helper
            code = f"""
import sys
sys.path.insert(0, {repr(SKILL_ROOT)})
from tests.test_offline_fixture import write_fixture_tree
write_fixture_tree({repr(d)})
"""
            # Import via path hack
            import importlib.util
            spec = importlib.util.spec_from_file_location('offline_fix', offline_test)
            mod = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(mod)
            mod.write_fixture_tree(d)
            result = subprocess.run(
                [sys.executable, VALIDATE_STRUCTURE, '--dir', d, '--mode', 'quick'],
                capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
