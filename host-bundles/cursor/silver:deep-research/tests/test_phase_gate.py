#!/usr/bin/env python3
"""Tests for phase_gate.py and phases SSoT."""

import json
import os
import subprocess
import sys
import tempfile
import unittest

SKILL_ROOT = os.path.join(os.path.dirname(__file__), '..')
PHASE_GATE = os.path.join(SKILL_ROOT, 'scripts', 'phase_gate.py')
RESEARCH_ENGINE = os.path.join(SKILL_ROOT, 'scripts', 'research_engine.py')
SOURCE_EVAL = os.path.join(SKILL_ROOT, 'scripts', 'source_evaluator.py')


def run_script(script: str, *args: str) -> tuple[int, dict]:
    result = subprocess.run(
        [sys.executable, script, *args],
        capture_output=True, text=True,
    )
    out = result.stdout.strip()
    data = json.loads(out) if out.startswith('{') or out.startswith('[') else {}
    return result.returncode, data


class TestPhasesConfig(unittest.TestCase):
    def test_phases_json_loads(self):
        path = os.path.join(SKILL_ROOT, 'phases.json')
        with open(path, encoding='utf-8') as f:
            cfg = json.load(f)
        self.assertIn('phases', cfg)
        self.assertEqual(len(cfg['phases']), 9)
        self.assertIn('quick', cfg['modes'])
        self.assertIn('outline', cfg['modes']['standard']['phases'])

    def test_research_engine_lists_nine_phases_deep(self):
        result = subprocess.run(
            [sys.executable, RESEARCH_ENGINE, '--list-phases', '--mode', 'deep'],
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0)
        self.assertIn('DR-OUTLINE', result.stdout)
        self.assertIn('DR-CRITIQUE', result.stdout)


class TestPhaseGate(unittest.TestCase):
    def test_missing_artifacts_fail(self):
        with tempfile.TemporaryDirectory() as d:
            code, data = run_script(PHASE_GATE, '--dir', d, '--phase', 'scope')
            self.assertEqual(code, 1)
            self.assertEqual(data['status'], 'fail')

    def test_scope_passes_with_scope_md(self):
        with tempfile.TemporaryDirectory() as d:
            with open(os.path.join(d, 'scope.md'), 'w') as f:
                f.write('# Scope\n\nBounded question with enough content for gate.\n')
            code, data = run_script(PHASE_GATE, '--dir', d, '--phase', 'scope')
            self.assertEqual(code, 0)
            self.assertEqual(data['status'], 'pass')

    def test_retrieve_fails_empty_jsonl(self):
        with tempfile.TemporaryDirectory() as d:
            open(os.path.join(d, 'sources.jsonl'), 'w').close()
            open(os.path.join(d, 'evidence.jsonl'), 'w').close()
            code, data = run_script(PHASE_GATE, '--dir', d, '--phase', 'retrieve')
            self.assertEqual(code, 1)
            self.assertEqual(data['status'], 'fail')


class TestSourceEvaluatorAdmiralty(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        sys.path.insert(0, os.path.join(SKILL_ROOT, 'scripts'))
        from source_evaluator import SourceEvaluator  # noqa: E402
        cls.SourceEvaluator = SourceEvaluator

    def test_high_authority_current_source(self):
        ev = self.SourceEvaluator()
        score = ev.evaluate_source(
            url='https://www.nature.com/articles/s41586-2025-12345',
            title='Peer-reviewed breakthrough',
            publication_date='2026-01-15',
            source_type='academic',
        )
        self.assertIn(score.reliability_code[0], ('A', 'B'))
        self.assertEqual(score.authority_tier, 'primary')
        self.assertEqual(score.recommendation, 'high_trust')

    def test_stale_source_gets_recency_risk(self):
        ev = self.SourceEvaluator()
        score = ev.evaluate_source(
            url='https://example.com/old-post',
            title='Old analysis',
            publication_date='2018-01-01',
        )
        self.assertIn('recency_risk', score.bias_flags)

    def test_biased_low_authority_source(self):
        ev = self.SourceEvaluator()
        score = ev.evaluate_source(
            url='https://shocking-news.wordpress.com/post',
            title='SHOCKING! You Won\'t Believe This Discovery!',
            publication_date='2020-01-01',
        )
        self.assertIn(score.reliability_code[0], ('D', 'E', 'F'))
        self.assertIn('sensationalism', score.bias_flags)

    def test_conflicting_evidence_low_trust(self):
        ev = self.SourceEvaluator()
        score = ev.evaluate_source(
            url='https://random-blog.blogspot.com/conflict',
            title='Unverified claim about quantum',
            publication_date='2015-06-01',
        )
        self.assertIn(score.recommendation, ('low_trust', 'verify'))


if __name__ == '__main__':
    unittest.main()
