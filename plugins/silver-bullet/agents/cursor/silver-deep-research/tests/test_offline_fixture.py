#!/usr/bin/env python3
"""Offline quick-mode fixture — produces complete artifact tree without network."""

import json
import os
import subprocess
import sys
import tempfile
import unittest

SKILL_ROOT = os.path.join(os.path.dirname(__file__), '..')
CITATION_MGR = os.path.join(SKILL_ROOT, 'scripts', 'citation_manager.py')
PHASE_GATE = os.path.join(SKILL_ROOT, 'scripts', 'phase_gate.py')
RESEARCH_ENGINE = os.path.join(SKILL_ROOT, 'scripts', 'research_engine.py')


def write_fixture_tree(out_dir: str) -> None:
    os.makedirs(os.path.join(out_dir, 'validation'), exist_ok=True)

    subprocess.run(
        [sys.executable, CITATION_MGR, 'init-run', '--out-dir', out_dir,
         '--query', 'offline fixture test', '--mode', 'quick'],
        check=True, capture_output=True,
    )
    subprocess.run(
        [sys.executable, RESEARCH_ENGINE, '--manifest-only', '--out-dir', out_dir, '--mode', 'quick'],
        check=True, capture_output=True,
    )

    artifacts = {
        'scope.md': '# Scope\n\nOffline quick-mode bounded question for fixture validation.\n',
        'sources.jsonl': json.dumps({
            'source_id': 'a' * 16, 'canonical_locator': 'https://example.com/doc',
            'raw_url': 'https://example.com/doc', 'title': 'Fixture source',
            'source_type': 'documentation', 'metadata_status': 'url_verified',
            'registered_at': '2026-07-08T00:00:00Z',
        }) + '\n',
        'evidence.jsonl': json.dumps({
            'evidence_id': 'e1', 'source_id': 'a' * 16,
            'quote': 'Fixture evidence quote.', 'evidence_type': 'direct_quote',
            'locator': 'section 1', 'extracted_at': '2026-07-08T00:00:00Z',
        }) + '\n',
        'decision-record.md': '# Decision Record\n\nRecommendation: proceed with offline fixture.\n',
        'handoff.md': '# Handoff\n\nDownstream: AF-DOCUMENT.\n',
    }
    for name, content in artifacts.items():
        with open(os.path.join(out_dir, name), 'w', encoding='utf-8') as f:
            f.write(content)

    vloop = {
        'version': '1.0.0',
        'mode': 'quick',
        'phases': [
            {'phase': 'scope', 'status': 'pass'},
            {'phase': 'retrieve', 'status': 'pass'},
            {'phase': 'package', 'status': 'pass'},
        ],
    }
    with open(os.path.join(out_dir, 'vloop-rollup.json'), 'w') as f:
        json.dump(vloop, f, indent=2)

    manifest_path = os.path.join(out_dir, 'run_manifest.json')
    manifest = json.load(open(manifest_path))
    manifest['search_cli'] = {'status': 'unavailable', 'providers_available': []}
    manifest['fallback_reason'] = 'offline fixture — no network'
    with open(manifest_path, 'w') as f:
        json.dump(manifest, f, indent=2)

    for log in ('validate_report.log', 'verify_citations.log', 'verify_claim_support.log'):
        with open(os.path.join(out_dir, 'validation', log), 'w') as f:
            f.write('offline fixture ok\n')


class TestOfflineQuickFixture(unittest.TestCase):
    def test_quick_mode_gate_passes(self):
        with tempfile.TemporaryDirectory() as d:
            write_fixture_tree(d)
            result = subprocess.run(
                [sys.executable, PHASE_GATE, '--dir', d, '--mode', 'quick'],
                capture_output=True, text=True,
            )
            data = json.loads(result.stdout)
            self.assertEqual(data['status'], 'pass', result.stdout)
            self.assertTrue(os.path.exists(os.path.join(d, 'vloop-rollup.json')))


if __name__ == '__main__':
    unittest.main()
