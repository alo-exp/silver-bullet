#!/usr/bin/env python3
"""Tests for solution-landscape / solution-compare artifacts."""

import json
import os
import subprocess
import sys
import tempfile
import unittest

SKILL_ROOT = os.path.join(os.path.dirname(__file__), '..')
SCRIPTS = os.path.join(SKILL_ROOT, 'scripts')


def run_py(script: str, *args: str) -> tuple[int, dict]:
    result = subprocess.run(
        [sys.executable, script, *args],
        capture_output=True,
        text=True,
    )
    out = result.stdout.strip()
    data = json.loads(out) if out.startswith('{') else {}
    return result.returncode, data


class TestNeedProfileGate(unittest.TestCase):
    def test_retrieve_blocked_without_interview(self):
        phase_gate = os.path.join(SCRIPTS, 'phase_gate.py')
        with tempfile.TemporaryDirectory() as d:
            os.makedirs(os.path.join(d, 'validation'), exist_ok=True)
            with open(os.path.join(d, 'run_manifest.json'), 'w') as f:
                json.dump({'research_type': 'solution-compare', 'mode': 'deep'}, f)
            with open(os.path.join(d, 'scope.md'), 'w') as f:
                f.write('# Scope\n\nBounded compare question with enough text.\n')
            open(os.path.join(d, 'sources.jsonl'), 'w').write('{"id":"s1"}\n')
            open(os.path.join(d, 'evidence.jsonl'), 'w').write('{"id":"e1"}\n')
            code, data = run_py(phase_gate, '--dir', d, '--phase', 'retrieve')
            self.assertEqual(code, 1)
            self.assertEqual(data['status'], 'fail')

    def test_retrieve_passes_with_complete_need_profile(self):
        phase_gate = os.path.join(SCRIPTS, 'phase_gate.py')
        with tempfile.TemporaryDirectory() as d:
            with open(os.path.join(d, 'run_manifest.json'), 'w') as f:
                json.dump({'research_type': 'solution-landscape', 'mode': 'deep'}, f)
            with open(os.path.join(d, 'scope.md'), 'w') as f:
                f.write('# Scope\n\nLandscape scope with sufficient content.\n')
            with open(os.path.join(d, 'need_profile.json'), 'w') as f:
                json.dump({
                    'category': 'IDP',
                    'audience': 'CTO',
                    'must_haves': ['SSO'],
                    'license_preference': 'mixed',
                    'interview_complete': True,
                }, f)
            open(os.path.join(d, 'sources.jsonl'), 'w').write('{"id":"s1"}\n')
            open(os.path.join(d, 'evidence.jsonl'), 'w').write('{"id":"e1"}\n')
            code, data = run_py(phase_gate, '--dir', d, '--phase', 'retrieve')
            self.assertEqual(code, 0)
            self.assertEqual(data['status'], 'pass')


class TestCompareSolutions(unittest.TestCase):
    def test_builds_comparison_json(self):
        compare = os.path.join(SCRIPTS, 'compare_solutions.py')
        with tempfile.TemporaryDirectory() as d:
            need = {
                'must_haves': ['SSO'],
                'nice_to_haves': [],
                'license_preference': 'mixed',
                'interview_complete': True,
            }
            with open(os.path.join(d, 'need_profile.json'), 'w') as f:
                json.dump(need, f)
            for name in ('alpha', 'beta'):
                sol = os.path.join(d, 'solutions', name)
                os.makedirs(sol)
                with open(os.path.join(sol, 'features.json'), 'w') as f:
                    json.dump({
                        'solution_name': name,
                        'categories': [{
                            'name': 'Core',
                            'features': [
                                {'name': 'SSO', 'supported': name == 'alpha'},
                                {'name': 'API', 'supported': True},
                            ],
                        }],
                    }, f)
            code, data = run_py(compare, '--dir', d)
            self.assertEqual(code, 0)
            self.assertEqual(data['status'], 'ok')
            comp = json.load(open(os.path.join(d, 'comparison', 'comparison.json')))
            self.assertEqual(comp['winner'], 'alpha')


class TestShortlist(unittest.TestCase):
    def test_exactly_five_shortlist(self):
        shortlist = os.path.join(SCRIPTS, 'shortlist_candidates.py')
        with tempfile.TemporaryDirectory() as d:
            cand_path = os.path.join(d, 'candidates.jsonl')
            with open(cand_path, 'w') as f:
                for i in range(10):
                    f.write(json.dumps({'name': f'Sol{i}', 'score': i, 'license': 'oss'}) + '\n')
            need_path = os.path.join(d, 'need_profile.json')
            with open(need_path, 'w') as f:
                json.dump({
                    'license_preference': 'oss',
                    'must_haves': [],
                    'interview_complete': True,
                }, f)
            out = os.path.join(d, 'shortlist.json')
            code, data = run_py(
                shortlist, '--candidates', cand_path,
                '--need-profile', need_path, '--out', out, '--count', '5',
            )
            self.assertEqual(code, 0)
            payload = json.load(open(out))
            self.assertEqual(len(payload['solutions']), 5)


class TestSpaReport(unittest.TestCase):
    def test_generate_and_validate_spa(self):
        gen = os.path.join(SCRIPTS, 'generate_report_spa.py')
        val = os.path.join(SCRIPTS, 'validate_spa_report.py')
        with tempfile.TemporaryDirectory() as d:
            with open(os.path.join(d, 'run_manifest.json'), 'w') as f:
                json.dump({'question': 'Test', 'research_type': 'solution-compare'}, f)
            with open(os.path.join(d, 'need_profile.json'), 'w') as f:
                json.dump({
                    'category': 'Test',
                    'audience': 'Eng',
                    'must_haves': [],
                    'license_preference': 'mixed',
                    'interview_complete': True,
                }, f)
            code, _ = run_py(gen, '--dir', d)
            self.assertEqual(code, 0)
            report = os.path.join(d, 'report.html')
            self.assertTrue(os.path.isfile(report))
            code2, data = run_py(val, '--report', report)
            self.assertEqual(code2, 0)
            self.assertEqual(data['status'], 'pass')


class TestSilverCompareContract(unittest.TestCase):
    def test_compare_rejects_shortlist(self):
        val = os.path.join(SCRIPTS, 'validate_compare.py')
        gen = os.path.join(SCRIPTS, 'generate_report_spa.py')
        with tempfile.TemporaryDirectory() as d:
            with open(os.path.join(d, 'solutions_requested.json'), 'w') as f:
                json.dump({'solutions': ['A', 'B']}, f)
            os.makedirs(os.path.join(d, 'shortlist'))
            with open(os.path.join(d, 'shortlist', 'shortlist.json'), 'w') as f:
                json.dump({'solutions': []}, f)
            for slug in ('a', 'b'):
                os.makedirs(os.path.join(d, 'solutions', slug))
                open(os.path.join(d, 'solutions', slug, 'scr.md'), 'w').write(
                    '# Solution Capability Report\n\nEnough content for gate.\n'
                )
            os.makedirs(os.path.join(d, 'comparison'))
            with open(os.path.join(d, 'comparison', 'comparison.json'), 'w') as f:
                json.dump({'rankings': [{'solution': 'A', 'score': 1}]}, f)
            subprocess.run([sys.executable, gen, '--dir', d], check=True)
            code, data = run_py(val, '--dir', d)
            self.assertEqual(code, 1)
            self.assertTrue(any('shortlist' in e for e in data.get('errors', [])))


if __name__ == '__main__':
    unittest.main()
