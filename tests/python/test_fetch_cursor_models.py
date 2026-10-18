"""Unit tests for scripts/lib/cursor-sb-agents/fetch-cursor-models.py (no network)."""
from __future__ import annotations

import contextlib
import io
import json
import os
import runpy
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from sbtest import REPO_ROOT, load_module

REL = "scripts/lib/cursor-sb-agents/fetch-cursor-models.py"
fetch = load_module(REL)

CATALOG = {
    "source": "agent-models+docs",
    "models": [
        {"id": "gpt-9", "display_name": "GPT 9", "agent_ids": ["gpt-9-high"],
         "pricing": {"input": 1.0, "cache_read": 0.1, "output": 5.0}, "pool": "api"},
        {"id": "plain", "agent_ids": ["plain"], "pricing": {}, "pool": "first-party"},
        {"id": "gpt-fast", "agent_ids": ["gpt-fast"], "fast_available": True, "pricing": {}},
        {"id": "maxed", "agent_ids": ["maxed"], "max_detected": True, "pricing": {}},
    ],
}


class FetchCliTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.tmp = Path(self._tmp.name).resolve()
        self.gcache = self.tmp / "g" / "catalog.json"

    def run_main(self, *argv, env=None):
        out = io.StringIO()
        with mock.patch("sys.argv", ["fetch-cursor-models.py", *argv]), \
             mock.patch.dict(os.environ, env or {}), \
             contextlib.redirect_stdout(out):
            rc = fetch.main()
        return rc, out.getvalue()

    def seed_global(self, catalog=CATALOG):
        self.gcache.parent.mkdir(parents=True, exist_ok=True)
        self.gcache.write_text(json.dumps(catalog))

    # --- cache path helpers ---------------------------------------------
    def test_global_cache_path_env_and_default(self):
        with mock.patch.dict(os.environ, {"SB_CURSOR_MODELS_CATALOG": "/x/c.json"}):
            self.assertEqual(fetch.global_cache_path(), Path("/x/c.json"))
        env = {k: v for k, v in os.environ.items() if k != "SB_CURSOR_MODELS_CATALOG"}
        with mock.patch.dict(os.environ, env, clear=True), \
             mock.patch.object(Path, "home", return_value=Path("/home/zed")):
            self.assertEqual(fetch.global_cache_path(),
                             Path("/home/zed/.config/silver-bullet/cursor-models-catalog.json"))

    def test_project_cache_path(self):
        self.assertIsNone(fetch.project_cache_path(None))
        self.assertEqual(fetch.project_cache_path(Path("/r")),
                         Path("/r/.silver-bullet/cursor-models-catalog.json"))

    # --- main -----------------------------------------------------------
    def test_no_fetch_reads_existing_cache_and_prints_summary(self):
        self.seed_global()
        with mock.patch.object(fetch, "fetch_and_cache_catalog") as fc:
            rc, out = self.run_main("--no-fetch", "--global-cache", str(self.gcache))
        fc.assert_not_called()
        self.assertEqual(rc, 0)
        self.assertEqual(out, f"Catalog cached: {self.gcache}\n"
                              "Models: 4 | source: agent-models+docs\n")

    def test_summary_mentions_existing_project_cache(self):
        self.seed_global()
        repo = self.tmp / "repo"
        pcache = repo / ".silver-bullet" / "cursor-models-catalog.json"
        pcache.parent.mkdir(parents=True)
        pcache.write_text("{}")
        rc, out = self.run_main("--no-fetch", "--global-cache", str(self.gcache),
                                "--repo-root", str(repo))
        self.assertEqual(rc, 0)
        self.assertIn(f"Project cache: {pcache}\n", out)

    def test_summary_omits_missing_project_cache(self):
        self.seed_global()
        repo = self.tmp / "repo"
        repo.mkdir()
        _, out = self.run_main("--no-fetch", "--global-cache", str(self.gcache),
                               "--repo-root", str(repo))
        self.assertNotIn("Project cache", out)

    def test_no_fetch_without_cache_falls_back_to_fetch(self):
        with mock.patch.object(fetch, "fetch_and_cache_catalog",
                               return_value={"models": [], "source": "docs-only"}) as fc:
            rc, out = self.run_main("--no-fetch", "--global-cache", str(self.gcache))
        self.assertEqual(rc, 0)
        fc.assert_called_once_with(self.gcache, None)
        self.assertIn("Models: 0 | source: docs-only", out)

    def test_fetch_passes_project_cache_and_uses_env_global(self):
        repo = self.tmp / "repo"
        repo.mkdir()
        with mock.patch.object(fetch, "fetch_and_cache_catalog",
                               return_value={"models": [1], "source": "s"}) as fc:
            rc, out = self.run_main("--repo-root", str(repo),
                                    env={"SB_CURSOR_MODELS_CATALOG": str(self.gcache)})
        self.assertEqual(rc, 0)
        fc.assert_called_once_with(self.gcache, repo / ".silver-bullet/cursor-models-catalog.json")
        self.assertIn(f"Catalog cached: {self.gcache}", out)
        self.assertIn("Models: 1 | source: s", out)

    def test_json_flag_prints_full_catalog(self):
        self.seed_global()
        rc, out = self.run_main("--no-fetch", "--json", "--global-cache", str(self.gcache))
        self.assertEqual(rc, 0)
        self.assertEqual(json.loads(out), CATALOG)

    def test_list_selectable_default_hides_fast_and_max(self):
        self.seed_global()
        rc, out = self.run_main("--no-fetch", "--list-selectable",
                                "--global-cache", str(self.gcache))
        self.assertEqual(rc, 0)
        self.assertEqual(out.splitlines(), [
            "gpt-9\tGPT 9\t$1.00 in / $0.10 cache / $5.00 out (api) (per 1M)",
            "plain\tplain\tfirst-party",
        ])

    def test_list_selectable_include_flags(self):
        self.seed_global()
        rc, out = self.run_main("--no-fetch", "--list-selectable", "--include-fast",
                                "--include-max", "--global-cache", str(self.gcache))
        self.assertEqual(rc, 0)
        self.assertEqual([line.split("\t")[0] for line in out.splitlines()],
                         ["gpt-9", "plain", "gpt-fast", "maxed"])

    def test_list_selectable_wins_over_json(self):
        self.seed_global()
        _, out = self.run_main("--no-fetch", "--list-selectable", "--json",
                               "--global-cache", str(self.gcache))
        self.assertTrue(out.startswith("gpt-9\t"))

    def test_fetch_path_never_touches_network(self):
        """End to end with urllib and the agent CLI mocked at the library boundary."""
        lib = fetch.fetch_and_cache_catalog.__globals__
        repo = self.tmp / "repo"
        repo.mkdir()
        resp = mock.MagicMock()
        resp.__enter__.return_value = resp
        resp.read.return_value = (
            b"| Model | Provider | In | CW | CR | Out | Notes |\n"
            b"| --- | --- | --- | --- | --- | --- | --- |\n"
            b"| GPT 9 | OpenAI | $1 | - | $0.1 | $5 | |\n"
        )
        with mock.patch.object(lib["urllib"].request, "urlopen", return_value=resp), \
             mock.patch.object(lib["subprocess"], "run", side_effect=FileNotFoundError()):
            rc, out = self.run_main("--global-cache", str(self.gcache), "--repo-root", str(repo))
        self.assertEqual(rc, 0)
        self.assertIn("Models: 1 | source: docs-only", out)
        self.assertEqual(json.loads(self.gcache.read_text())["models"][0]["id"], "gpt-9")
        self.assertTrue((repo / ".silver-bullet/cursor-models-catalog.json").is_file())
        self.assertIn("Project cache:", out)

    def test_dunder_main_exits_with_main_status(self):
        self.seed_global()
        with mock.patch("sys.argv", ["fetch-cursor-models.py", "--no-fetch",
                                     "--global-cache", str(self.gcache)]), \
             contextlib.redirect_stdout(io.StringIO()) as out:
            with self.assertRaises(SystemExit) as cm:
                runpy.run_path(str(REPO_ROOT / REL), run_name="__main__")
        self.assertEqual(cm.exception.code, 0)
        self.assertIn("Models: 4", out.getvalue())


if __name__ == "__main__":
    unittest.main()
