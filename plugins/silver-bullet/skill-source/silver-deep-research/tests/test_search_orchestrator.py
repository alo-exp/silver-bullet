#!/usr/bin/env python3
"""Tests for SB-owned search orchestrator — no network, no TopGun."""

import json
import os
import subprocess
import sys
import tempfile
import unittest

SKILL_ROOT = os.path.join(os.path.dirname(__file__), '..')
ORCHESTRATOR = os.path.join(SKILL_ROOT, 'scripts', 'search_orchestrator.py')
CATALOG_LOADER = os.path.join(SKILL_ROOT, 'scripts', 'catalog_loader.py')


class TestSearchOrchestrator(unittest.TestCase):
    def test_offline_completes_with_fallback(self):
        with tempfile.TemporaryDirectory() as d:
            result = subprocess.run(
                [sys.executable, ORCHESTRATOR, '--query', 'agent skills landscape',
                 '--dir', d, '--research-type', 'landscape', '--offline'],
                capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            data = json.loads(result.stdout)
            self.assertEqual(data['intent_class'], 'landscape')
            manifest = json.load(open(os.path.join(d, 'run_manifest.json')))
            self.assertIn('fallback_reason', manifest)

    def test_skills_sh_mock_fixture(self):
        with tempfile.TemporaryDirectory() as d:
            mock = {"skills_sh": [{"name": "deep-research", "url": "https://skills.sh/x"}]}
            mock_path = os.path.join(d, 'mock.json')
            with open(mock_path, 'w') as f:
                json.dump(mock, f)
            result = subprocess.run(
                [sys.executable, ORCHESTRATOR, '--query', 'deep research',
                 '--dir', d, '--research-type', 'landscape', '--mock-portal-json', mock_path],
                capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0)
            self.assertTrue(os.path.exists(os.path.join(d, 'portal-skills_sh.json')))

    def test_non_landscape_skips_portals(self):
        with tempfile.TemporaryDirectory() as d:
            result = subprocess.run(
                [sys.executable, ORCHESTRATOR, '--query', 'postgres vs mysql',
                 '--dir', d, '--research-type', 'comparison'],
                capture_output=True, text=True,
            )
            data = json.loads(result.stdout)
            self.assertEqual(data['retrieval']['portals_attempted'], [])

    def test_no_topgun_reference_in_scripts(self):
        for root, _, files in os.walk(os.path.join(SKILL_ROOT, 'scripts')):
            for fn in files:
                if fn.endswith('.py'):
                    text = open(os.path.join(root, fn)).read()
                    self.assertNotIn('topgun', text.lower())
                    self.assertNotIn('find-skills', text.lower())


class TestCatalogLoader(unittest.TestCase):
    def test_loads_intent_classes_json(self):
        from importlib.util import spec_from_loader, module_from_spec
        from importlib.machinery import SourceFileLoader
        spec = spec_from_loader('cl', SourceFileLoader('cl', CATALOG_LOADER))
        mod = module_from_spec(spec)
        spec.loader.exec_module(mod)
        catalog = mod.load_catalog('intent_classes')
        self.assertIn('landscape', catalog['classes'])


if __name__ == '__main__':
    unittest.main()
