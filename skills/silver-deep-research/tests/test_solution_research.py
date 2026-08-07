#!/usr/bin/env python3
"""Tests for solution-landscape / solution-compare artifacts."""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SKILL_ROOT = os.path.join(os.path.dirname(__file__), '..')
SCRIPTS = os.path.join(SKILL_ROOT, 'scripts')
sys.path.insert(0, SCRIPTS)

from shortlist_candidates import _is_commercial_license  # noqa: E402


def run_py(script: str, *args: str) -> tuple[int, dict]:
    result = subprocess.run(
        [sys.executable, script, *args],
        capture_output=True,
        text=True,
    )
    out = result.stdout.strip()
    data = json.loads(out) if out.startswith('{') else {}
    return result.returncode, data




def _has_openpyxl() -> bool:
    from deps_probe import openpyxl_importable
    return openpyxl_importable()


def _maybe_emit_fixture_xlsx(d: str) -> None:
    if not _has_openpyxl():
        return
    from generate_comparison_xlsx import generate_comparison_xlsx
    generate_comparison_xlsx(Path(d))


def seed_landscape_fixture(
    d: str,
    *,
    shortlist_count: int = 5,
    with_solutions: bool = True,
    with_landscape: bool = True,
) -> None:
    os.makedirs(os.path.join(d, 'shortlist'), exist_ok=True)
    with open(os.path.join(d, 'shortlist', 'shortlist.json'), 'w') as f:
        json.dump({
            'count': shortlist_count,
            'solutions': [{'name': f'Sol{i}', 'rank': i} for i in range(1, shortlist_count + 1)],
        }, f)
    if with_landscape:
        os.makedirs(os.path.join(d, 'landscape'), exist_ok=True)
        with open(os.path.join(d, 'landscape', 'landscape-report.md'), 'w') as f:
            f.write('# Landscape Report\n\nMarket survey with enough content.\n')
    if with_solutions:
        for i in range(1, 6):
            sol = os.path.join(d, 'solutions', f'sol{i}')
            os.makedirs(sol, exist_ok=True)
            with open(os.path.join(sol, 'scr.md'), 'w') as f:
                f.write('# Solution Capability Report\n\nEnough content for gate.\n')
    os.makedirs(os.path.join(d, 'comparison'), exist_ok=True)
    with open(os.path.join(d, 'comparison', 'comparison.json'), 'w') as f:
        json.dump({
            'rankings': [{'solution': 'Sol1', 'score': 1, 'rank': 1}],
            'rows': [
                {'type': 'category', 'name': 'Core'},
                {
                    'type': 'feature',
                    'name': 'SSO',
                    'priority': 'High',
                    'solutions': {'Sol1': '\u2714', 'Sol2': '', 'Sol3': '', 'Sol4': '', 'Sol5': ''},
                },
            ],
        }, f)
    with open(os.path.join(d, 'report.html'), 'w') as f:
        f.write('<!DOCTYPE html><html><body>report</body></html>')
    _maybe_emit_fixture_xlsx(d)


class TestNeedProfileGate(unittest.TestCase):
    def test_scope_blocked_without_interview(self):
        phase_gate = os.path.join(SCRIPTS, 'phase_gate.py')
        with tempfile.TemporaryDirectory() as d:
            with open(os.path.join(d, 'run_manifest.json'), 'w') as f:
                json.dump({'research_type': 'solution-compare', 'mode': 'deep'}, f)
            with open(os.path.join(d, 'scope.md'), 'w') as f:
                f.write('# Scope\n\nBounded compare question with enough text.\n')
            code, data = run_py(phase_gate, '--dir', d, '--phase', 'scope')
            self.assertEqual(code, 1)
            self.assertEqual(data['status'], 'fail')

    def test_solution_compare_rejects_quick_mode(self):
        phase_gate = os.path.join(SCRIPTS, 'phase_gate.py')
        with tempfile.TemporaryDirectory() as d:
            with open(os.path.join(d, 'run_manifest.json'), 'w') as f:
                json.dump({'research_type': 'solution-compare', 'mode': 'quick'}, f)
            with open(os.path.join(d, 'scope.md'), 'w') as f:
                f.write('# Scope\n\nBounded compare question with enough text.\n')
            with open(os.path.join(d, 'need_profile.json'), 'w') as f:
                json.dump({
                    'category': 'IDP',
                    'audience': 'CTO',
                    'must_haves': ['SSO'],
                    'category_pack_id': 'agentic-sdlc-process-orchestrator',
                    'license_preference': 'mixed',
                    'interview_complete': True,
                }, f)
            code, data = run_py(phase_gate, '--dir', d, '--mode', 'quick')
            self.assertEqual(code, 1)
            self.assertEqual(data['status'], 'fail')
            self.assertIn('deep or ultradeep', data.get('reason', ''))

    def test_solution_compare_rejects_standard_mode(self):
        phase_gate = os.path.join(SCRIPTS, 'phase_gate.py')
        with tempfile.TemporaryDirectory() as d:
            with open(os.path.join(d, 'run_manifest.json'), 'w') as f:
                json.dump({'research_type': 'solution-compare', 'mode': 'standard'}, f)
            code, data = run_py(phase_gate, '--dir', d, '--mode', 'standard')
            self.assertEqual(code, 1)
            self.assertEqual(data['status'], 'fail')
            self.assertIn('deep or ultradeep', data.get('reason', ''))

    def test_per_phase_rejects_quick_from_manifest(self):
        phase_gate = os.path.join(SCRIPTS, 'phase_gate.py')
        with tempfile.TemporaryDirectory() as d:
            with open(os.path.join(d, 'run_manifest.json'), 'w') as f:
                json.dump({'research_type': 'solution-landscape', 'mode': 'quick'}, f)
            with open(os.path.join(d, 'scope.md'), 'w') as f:
                f.write('# Scope\n\nLandscape scope with sufficient content.\n')
            code, data = run_py(phase_gate, '--dir', d, '--phase', 'scope')
            self.assertEqual(code, 1)
            self.assertEqual(data['status'], 'fail')
            self.assertIn('deep or ultradeep', data.get('reason', ''))

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
                    'category_pack_id': 'agentic-sdlc-process-orchestrator',
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

    def test_category_false_not_overwritten_by_flat_features(self):
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
            sol = os.path.join(d, 'solutions', 'alpha')
            os.makedirs(sol)
            with open(os.path.join(sol, 'features.json'), 'w') as f:
                json.dump({
                    'solution_name': 'alpha',
                    'categories': [{
                        'name': 'Core',
                        'features': [{'name': 'SSO', 'supported': False}],
                    }],
                    'features': [{'name': 'SSO', 'supported': True}],
                }, f)
            sol2 = os.path.join(d, 'solutions', 'beta')
            os.makedirs(sol2)
            with open(os.path.join(sol2, 'features.json'), 'w') as f:
                json.dump({
                    'solution_name': 'beta',
                    'categories': [{
                        'name': 'Core',
                        'features': [{'name': 'SSO', 'supported': True}],
                    }],
                }, f)
            code, data = run_py(compare, '--dir', d)
            self.assertEqual(code, 0)
            comp = json.load(open(os.path.join(d, 'comparison', 'comparison.json')))
            sso_row = next(r for r in comp['rows'] if r.get('name') == 'SSO')
            self.assertEqual(sso_row['solutions']['alpha'], '')
            self.assertEqual(sso_row['solutions']['beta'], '\u2714')

    def test_flat_string_features_do_not_crash(self):
        compare = os.path.join(SCRIPTS, 'compare_solutions.py')
        with tempfile.TemporaryDirectory() as d:
            need = {
                'must_haves': [],
                'nice_to_haves': [],
                'license_preference': 'mixed',
                'interview_complete': True,
            }
            with open(os.path.join(d, 'need_profile.json'), 'w') as f:
                json.dump(need, f)
            for name, feats in (
                ('alpha', {'features': ['RBAC', 'Audit log']}),
                ('beta', {'features': ['RBAC']}),
            ):
                sol = os.path.join(d, 'solutions', name)
                os.makedirs(sol)
                with open(os.path.join(sol, 'features.json'), 'w') as f:
                    json.dump({'solution_name': name, **feats}, f)
            code, data = run_py(compare, '--dir', d)
            self.assertEqual(code, 0)
            self.assertEqual(data['status'], 'ok')
            comp = json.load(open(os.path.join(d, 'comparison', 'comparison.json')))
            feat_names = [r['name'] for r in comp['rows'] if r.get('type') == 'feature']
            self.assertIn('RBAC', feat_names)
            self.assertIn('Audit log', feat_names)


class TestCommercialLicenseNormalize(unittest.TestCase):
    def test_rejects_non_commercial_variants(self):
        rejects = (
            'non_commercial',
            'not_commercial',
            'NON_COMMERCIAL',
            'non-commercial',
            'noncommercial',
            'notcommercial',
            'Not Commercial License',
        )
        for lic in rejects:
            with self.subTest(license=lic):
                self.assertFalse(_is_commercial_license(lic))

    def test_accepts_commercial_variants(self):
        accepts = (
            'commercial',
            'Commercial License',
            'commercial-use',
            'Commercial Use Only',
            'enterprise commercial',
            'proprietary',
            'saas',
            'Enterprise SaaS',
        )
        for lic in accepts:
            with self.subTest(license=lic):
                self.assertTrue(_is_commercial_license(lic))

    def test_rejects_empty_license(self):
        self.assertFalse(_is_commercial_license(''))
        self.assertFalse(_is_commercial_license('   '))


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

    def test_commercial_filter_excludes_empty_license(self):
        shortlist = os.path.join(SCRIPTS, 'shortlist_candidates.py')
        with tempfile.TemporaryDirectory() as d:
            cand_path = os.path.join(d, 'candidates.jsonl')
            with open(cand_path, 'w') as f:
                f.write(json.dumps({'name': 'NoLic', 'score': 10}) + '\n')
                f.write(json.dumps({'name': 'Comm', 'score': 5, 'license': 'commercial'}) + '\n')
            need_path = os.path.join(d, 'need_profile.json')
            with open(need_path, 'w') as f:
                json.dump({
                    'license_preference': 'commercial',
                    'must_haves': [],
                    'interview_complete': True,
                }, f)
            out = os.path.join(d, 'shortlist.json')
            code, _ = run_py(
                shortlist, '--candidates', cand_path,
                '--need-profile', need_path, '--out', out, '--count', '1',
            )
            self.assertEqual(code, 0)
            payload = json.load(open(out))
            self.assertEqual(len(payload['solutions']), 1)
            self.assertEqual(payload['solutions'][0]['name'], 'Comm')

    def test_commercial_filter_excludes_non_commercial(self):
        shortlist = os.path.join(SCRIPTS, 'shortlist_candidates.py')
        with tempfile.TemporaryDirectory() as d:
            cand_path = os.path.join(d, 'candidates.jsonl')
            with open(cand_path, 'w') as f:
                f.write(json.dumps({
                    'name': 'NonComm', 'score': 10, 'license': 'non-commercial',
                }) + '\n')
                f.write(json.dumps({
                    'name': 'NonComm2', 'score': 9, 'license': 'noncommercial',
                }) + '\n')
                f.write(json.dumps({
                    'name': 'NonComm3', 'score': 8, 'license': 'non_commercial',
                }) + '\n')
                f.write(json.dumps({
                    'name': 'NonComm4', 'score': 7, 'license': 'not_commercial',
                }) + '\n')
                f.write(json.dumps({
                    'name': 'Comm', 'score': 5, 'license': 'commercial',
                }) + '\n')
                f.write(json.dumps({
                    'name': 'CommLic', 'score': 4, 'license': 'Commercial License',
                }) + '\n')
            need_path = os.path.join(d, 'need_profile.json')
            with open(need_path, 'w') as f:
                json.dump({
                    'license_preference': 'commercial',
                    'must_haves': [],
                    'interview_complete': True,
                }, f)
            out = os.path.join(d, 'shortlist.json')
            code, _ = run_py(
                shortlist, '--candidates', cand_path,
                '--need-profile', need_path, '--out', out, '--count', '2',
            )
            self.assertEqual(code, 0)
            payload = json.load(open(out))
            names = {s['name'] for s in payload['solutions']}
            self.assertEqual(names, {'Comm', 'CommLic'})


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

    def test_spa_escapes_angle_brackets_in_payload(self):
        gen = os.path.join(SCRIPTS, 'generate_report_spa.py')
        val = os.path.join(SCRIPTS, 'validate_spa_report.py')
        with tempfile.TemporaryDirectory() as d:
            with open(os.path.join(d, 'run_manifest.json'), 'w') as f:
                json.dump({
                    'question': 'Compare <script>alert(1)</script>',
                    'research_type': 'solution-compare',
                }, f)
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
            html = open(report, encoding='utf-8').read()
            self.assertIn('\\u003c', html)
            self.assertNotIn('<script>alert', html)
            code2, data = run_py(val, '--report', report)
            self.assertEqual(code2, 0)
            self.assertEqual(data['status'], 'pass')

    def test_spa_matrix_declares_table_variable(self):
        gen = os.path.join(SCRIPTS, 'generate_report_spa.py')
        val = os.path.join(SCRIPTS, 'validate_spa_report.py')
        with tempfile.TemporaryDirectory() as d:
            with open(os.path.join(d, 'run_manifest.json'), 'w') as f:
                json.dump({'question': 'Matrix', 'research_type': 'solution-compare'}, f)
            with open(os.path.join(d, 'need_profile.json'), 'w') as f:
                json.dump({
                    'category': 'Test',
                    'audience': 'Eng',
                    'must_haves': [],
                    'license_preference': 'mixed',
                    'interview_complete': True,
                }, f)
            os.makedirs(os.path.join(d, 'comparison'))
            with open(os.path.join(d, 'comparison', 'comparison.json'), 'w') as f:
                json.dump({
                    'rankings': [{'solution': 'A', 'score': 1}],
                    'rows': [{
                        'type': 'feature',
                        'name': 'SSO',
                        'priority': 'High',
                        'solutions': {'A': '\u2714'},
                    }],
                }, f)
            code, _ = run_py(gen, '--dir', d)
            self.assertEqual(code, 0)
            report = os.path.join(d, 'report.html')
            html = open(report, encoding='utf-8').read()
            self.assertRegex(html, r'\blet\s+table\s*=')
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

    def test_compare_scr_count_uses_names_field(self):
        val = os.path.join(SCRIPTS, 'validate_compare.py')
        gen = os.path.join(SCRIPTS, 'generate_report_spa.py')
        with tempfile.TemporaryDirectory() as d:
            with open(os.path.join(d, 'solutions_requested.json'), 'w') as f:
                json.dump({'names': ['Alpha', 'Beta']}, f)
            for slug in ('alpha', 'beta'):
                os.makedirs(os.path.join(d, 'solutions', slug))
                open(os.path.join(d, 'solutions', slug, 'scr.md'), 'w').write(
                    '# Solution Capability Report\n\nEnough content for gate.\n'
                )
            os.makedirs(os.path.join(d, 'comparison'))
            with open(os.path.join(d, 'comparison', 'comparison.json'), 'w') as f:
                json.dump({
                    'rankings': [{'solution': 'Alpha', 'score': 1, 'rank': 1}],
                    'rows': [
                        {'type': 'category', 'name': 'Core'},
                        {
                            'type': 'feature',
                            'name': 'SSO',
                            'priority': 'High',
                            'solutions': {'Alpha': '\u2714', 'Beta': ''},
                        },
                    ],
                }, f)
            _maybe_emit_fixture_xlsx(d)
            subprocess.run([sys.executable, gen, '--dir', d], check=True)
            code, data = run_py(val, '--dir', d)
            self.assertEqual(code, 0)
            self.assertEqual(data['status'], 'pass')


class TestValidateLandscape(unittest.TestCase):
    def test_happy_path(self):
        val = os.path.join(SCRIPTS, 'validate_landscape.py')
        with tempfile.TemporaryDirectory() as d:
            seed_landscape_fixture(d)
            code, data = run_py(val, '--dir', d)
            self.assertEqual(code, 0)
            self.assertEqual(data['status'], 'pass')

    def test_wrong_shortlist_count(self):
        val = os.path.join(SCRIPTS, 'validate_landscape.py')
        with tempfile.TemporaryDirectory() as d:
            seed_landscape_fixture(d, shortlist_count=3)
            code, data = run_py(val, '--dir', d)
            self.assertEqual(code, 1)
            self.assertTrue(any('exactly 5' in e for e in data.get('errors', [])))

    def test_missing_landscape_report(self):
        val = os.path.join(SCRIPTS, 'validate_landscape.py')
        with tempfile.TemporaryDirectory() as d:
            seed_landscape_fixture(d, with_landscape=False)
            code, data = run_py(val, '--dir', d)
            self.assertEqual(code, 1)
            self.assertTrue(any('landscape-report' in e for e in data.get('errors', [])))

    def test_missing_solutions_dir(self):
        val = os.path.join(SCRIPTS, 'validate_landscape.py')
        with tempfile.TemporaryDirectory() as d:
            seed_landscape_fixture(d, with_solutions=False)
            code, data = run_py(val, '--dir', d)
            self.assertEqual(code, 1)
            self.assertTrue(any('solutions/' in e for e in data.get('errors', [])))


class TestValidateCompareNegative(unittest.TestCase):
    def test_missing_solutions_dir(self):
        val = os.path.join(SCRIPTS, 'validate_compare.py')
        gen = os.path.join(SCRIPTS, 'generate_report_spa.py')
        with tempfile.TemporaryDirectory() as d:
            with open(os.path.join(d, 'solutions_requested.json'), 'w') as f:
                json.dump({'solutions': ['A', 'B']}, f)
            os.makedirs(os.path.join(d, 'comparison'))
            with open(os.path.join(d, 'comparison', 'comparison.json'), 'w') as f:
                json.dump({'rankings': [{'solution': 'A', 'score': 1}]}, f)
            subprocess.run([sys.executable, gen, '--dir', d], check=True)
            code, data = run_py(val, '--dir', d)
            self.assertEqual(code, 1)
            self.assertTrue(any('solutions/' in e for e in data.get('errors', [])))


class TestPhaseGateShortlist(unittest.TestCase):
    def test_shortlist_requires_five_for_landscape(self):
        phase_gate = os.path.join(SCRIPTS, 'phase_gate.py')
        with tempfile.TemporaryDirectory() as d:
            with open(os.path.join(d, 'run_manifest.json'), 'w') as f:
                json.dump({'research_type': 'solution-landscape', 'mode': 'deep'}, f)
            os.makedirs(os.path.join(d, 'shortlist'))
            with open(os.path.join(d, 'shortlist', 'shortlist.json'), 'w') as f:
                json.dump({'solutions': [{'name': 'A'}, {'name': 'B'}]}, f)
            code, data = run_py(phase_gate, '--dir', d, '--phase', 'triangulate')
            self.assertEqual(code, 1)
            self.assertEqual(data['status'], 'fail')
            shortlist_art = next(
                a for a in data.get('artifacts', []) if 'shortlist' in a.get('artifact', '')
            )
            self.assertFalse(shortlist_art['ok'])
            self.assertIn('exactly 5', shortlist_art['detail'])


class TestMatrixOpenpyxl(unittest.TestCase):
    @staticmethod
    def _has_openpyxl() -> bool:
        try:
            import openpyxl  # noqa: F401
            return True
        except ImportError:
            return False

    @unittest.skipUnless(_has_openpyxl(), 'openpyxl not installed')
    def test_matrix_builder_help(self):
        builder = os.path.join(SCRIPTS, 'matrix_builder.py')
        result = subprocess.run(
            [sys.executable, builder, '--help'],
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0)
        self.assertIn('--config', result.stdout)

    @unittest.skipUnless(_has_openpyxl(), 'openpyxl not installed')
    def test_matrix_ops_help(self):
        ops = os.path.join(SCRIPTS, 'matrix_ops.py')
        result = subprocess.run(
            [sys.executable, ops, '--help'],
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0)
        self.assertIn('add-platform', result.stdout)

    @unittest.skipIf(_has_openpyxl(), 'openpyxl is installed')
    def test_require_openpyxl_clear_error(self):
        ops = os.path.join(SCRIPTS, 'matrix_ops.py')
        result = subprocess.run(
            [sys.executable, ops, 'info', '--src', 'missing.xlsx'],
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn('openpyxl', result.stderr.lower())


if __name__ == '__main__':
    unittest.main()
