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

class TestGithubSkillMdRetrieval(unittest.TestCase):
    FIXTURE_BRANCHES = os.path.join(SKILL_ROOT, 'tests', 'fixtures', 'github_default_branches.json')
    REPLAY_REPOS = os.path.join(
        os.path.dirname(__file__), '..', '..', '..',
        '.planning', 'research', '2026-07-08-v2-landscape-replay', 'gh-search-repos.json',
    )

    def _load_branches(self):
        with open(self.FIXTURE_BRANCHES, encoding='utf-8') as f:
            return json.load(f)

    def test_weizhena_uses_master_not_naive_main(self):
        sys.path.insert(0, os.path.join(SKILL_ROOT, 'scripts'))
        from github_skill_retrieval import skill_md_retrieval_plan
        branches = self._load_branches()
        plan = skill_md_retrieval_plan('Weizhena/Deep-Research-skills', branches)
        self.assertEqual(plan['default_branch'], 'master')
        self.assertIn('/master/SKILL.md', plan['skill_md_url'])
        self.assertIn('/main/SKILL.md', plan['naive_main_url'])
        self.assertTrue(plan['use_corrected_url'])

    def test_main_branch_repo_avoids_wrong_correction(self):
        sys.path.insert(0, os.path.join(SKILL_ROOT, 'scripts'))
        from github_skill_retrieval import skill_md_retrieval_plan
        branches = self._load_branches()
        plan = skill_md_retrieval_plan(
            '199-biotechnologies/claude-deep-research-skill', branches,
        )
        self.assertEqual(plan['default_branch'], 'main')
        self.assertEqual(plan['skill_md_url'], plan['naive_main_url'])
        self.assertFalse(plan['use_corrected_url'])

    def test_replay_fixture_enrichment_respects_default_branch(self):
        sys.path.insert(0, os.path.join(SKILL_ROOT, 'scripts'))
        from github_skill_retrieval import enrich_github_search_hits
        with open(self.REPLAY_REPOS, encoding='utf-8') as f:
            hits = json.load(f)
        branches = self._load_branches()
        enriched = enrich_github_search_hits(hits, branches)
        by_name = {row['fullName']: row for row in enriched if row.get('fullName')}
        weizhena = by_name['Weizhena/Deep-Research-skills']
        self.assertEqual(weizhena['default_branch'], 'master')
        self.assertNotIn('/main/SKILL.md', weizhena['skill_md_url'])
        bio = by_name['199-biotechnologies/claude-deep-research-skill']
        self.assertEqual(bio['default_branch'], 'main')

    def test_github_mock_orchestrator_writes_branch_correct_urls(self):
        with tempfile.TemporaryDirectory() as d:
            hits = [{
                'fullName': 'Weizhena/Deep-Research-skills',
                'url': 'https://github.com/Weizhena/Deep-Research-skills',
            }]
            mock = {'github': hits}
            branches_path = os.path.join(d, 'branches.json')
            with open(branches_path, 'w', encoding='utf-8') as f:
                json.dump(self._load_branches(), f)
            mock_path = os.path.join(d, 'mock.json')
            with open(mock_path, 'w', encoding='utf-8') as f:
                json.dump(mock, f)
            env = os.environ.copy()
            env['SB_DR_GITHUB_BRANCHES_JSON'] = branches_path
            result = subprocess.run(
                [sys.executable, ORCHESTRATOR, '--query', 'deep research',
                 '--dir', d, '--research-type', 'landscape', '--mock-portal-json', mock_path],
                capture_output=True, text=True, env=env,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            portal = json.load(open(os.path.join(d, 'portal-github.json')))
            row = portal['results'][0]
            self.assertEqual(row['default_branch'], 'master')
            self.assertIn('/master/SKILL.md', row['skill_md_url'])

