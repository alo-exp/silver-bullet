"""Coverage tests for eval wrappers, capability_score, catalog_loader, deps_probe, chain_tracker."""

import builtins
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import covhelp
from covhelp import EVAL, SCRIPTS, call_main, run_script

import capability_score
import catalog_loader
import chain_tracker
import deps_probe


def setUpModule():
    covhelp.block_network()


def tearDownModule():
    covhelp.unblock_network()


class TestScoreCapabilityWrapper(unittest.TestCase):
    def test_wrapper_forwards_args_to_capability_score(self):
        with mock.patch("subprocess.call", return_value=7) as call:
            code, _, _ = run_script(EVAL / "score_capability.py", ["--skill-only"])
        self.assertEqual(code, 7)
        args = call.call_args[0][0]
        self.assertEqual(args[0], sys.executable)
        self.assertTrue(args[1].endswith("capability_score.py"))
        self.assertEqual(args[2:], ["--skill-only"])


class TestScoreCapabilityImport(unittest.TestCase):
    def test_importing_wrapper_does_not_run_scorer(self):
        with mock.patch("subprocess.call") as call:
            run_script(EVAL / "score_capability.py", [], as_main=False)
        call.assert_not_called()


class TestValidateStructure(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        sys.path.insert(0, str(EVAL))
        cls.addClassCleanup(sys.path.remove, str(EVAL))
        import validate_structure
        cls.vs = validate_structure

    def test_not_a_directory(self):
        res = self.vs.validate_structure(Path("/nonexistent/dir-xyz"))
        self.assertEqual(res["status"], "fail")
        self.assertIn("not a directory", res["reason"])

    def test_manifest_mode_is_used_and_missing_listed(self):
        with tempfile.TemporaryDirectory() as d:
            (Path(d) / "run_manifest.json").write_text(json.dumps({"mode": "quick"}))
            res = self.vs.validate_structure(Path(d))
        self.assertEqual(res["mode"], "quick")
        self.assertEqual(res["status"], "fail")
        self.assertIn("sources.jsonl", res["missing"])
        self.assertNotIn("run_manifest.json", res["missing"])

    def test_manifest_without_mode_defaults_to_standard(self):
        with tempfile.TemporaryDirectory() as d:
            (Path(d) / "run_manifest.json").write_text("{}")
            res = self.vs.validate_structure(Path(d))
        self.assertEqual(res["mode"], "standard")

    def test_explicit_mode_overrides_manifest(self):
        with tempfile.TemporaryDirectory() as d:
            (Path(d) / "run_manifest.json").write_text(json.dumps({"mode": "quick"}))
            res = self.vs.validate_structure(Path(d), "deep")
        self.assertEqual(res["mode"], "deep")
        self.assertIn("critique.md", res["missing"])

    def test_unknown_mode_falls_back_to_standard_files(self):
        with tempfile.TemporaryDirectory() as d:
            res = self.vs.validate_structure(Path(d), "weird")
        self.assertIn("research-plan.md", res["missing"])
        self.assertNotIn("critique.md", res["missing"])

    def test_pass_when_complete_and_gate_passes(self):
        with tempfile.TemporaryDirectory() as d:
            for name in self.vs.REQUIRED_ROOT + self.vs.MODE_EXTRA["quick"]:
                (Path(d) / name).write_text("{}" if name.endswith(".json") else "x")
            with mock.patch.object(self.vs, "check_mode_complete",
                                   return_value={"status": "pass"}):
                res = self.vs.validate_structure(Path(d), "quick")
        self.assertEqual(res["status"], "pass")
        self.assertEqual(res["missing"], [])

    def test_complete_files_but_failing_gate_fails(self):
        with tempfile.TemporaryDirectory() as d:
            for name in self.vs.REQUIRED_ROOT + self.vs.MODE_EXTRA["quick"]:
                (Path(d) / name).write_text("{}" if name.endswith(".json") else "x")
            with mock.patch.object(self.vs, "check_mode_complete",
                                   return_value={"status": "fail"}):
                res = self.vs.validate_structure(Path(d), "quick")
        self.assertEqual(res["status"], "fail")
        self.assertEqual(res["missing"], [])

    def test_main_exit_codes(self):
        with tempfile.TemporaryDirectory() as d:
            code, out, _ = call_main(self.vs, ["--dir", d, "--mode", "quick"])
            self.assertEqual(code, 1)
            self.assertEqual(json.loads(out)["status"], "fail")
            with mock.patch.object(self.vs, "validate_structure",
                                   return_value={"status": "pass"}):
                code, out, _ = call_main(self.vs, ["--dir", d])
            self.assertEqual(code, 0)

    def test_run_as_script(self):
        with tempfile.TemporaryDirectory() as d:
            code, out, _ = run_script(EVAL / "validate_structure.py", ["--dir", d])
        self.assertEqual(code, 1)
        self.assertEqual(json.loads(out)["status"], "fail")


class TestCapabilityScore(unittest.TestCase):
    def test_skill_tree_all_present(self):
        res = capability_score.score_skill_tree()
        self.assertEqual(res["max"], 55)
        self.assertEqual(res["total"], sum(res["dimensions"].values()))
        self.assertEqual(set(res["dimensions"]), set(capability_score.DIMENSIONS))

    def test_skill_tree_all_missing_scores_lower(self):
        with mock.patch.object(capability_score, "_exists", return_value=False):
            res = capability_score.score_skill_tree()
        d = res["dimensions"]
        self.assertEqual(d["phases_modes"], 3)
        self.assertEqual(d["citation_evidence"], 4)
        self.assertEqual(d["multilingual"], 2)
        self.assertEqual(d["portability"], 5)
        self.assertEqual(res["total"], 3 + 4 + 3 + 2 + 3 + 4 + 5 + 3 + 5 + 3 + 3)

    def test_score_run_empty_dir(self):
        with tempfile.TemporaryDirectory() as d:
            res = capability_score.score_run(Path(d))
        b = res["behavioral"]
        self.assertEqual(b["source_count"], 0)
        self.assertFalse(b["fallback_recorded"])
        self.assertEqual(b["human_checkpoint_count"], 0)
        self.assertIn("observational", res["note"])

    def test_score_run_reads_artifacts(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d)
            (p / "sources.jsonl").write_text('{"a":1}\n\n{"b":2}\n   \n')
            (p / "run_manifest.json").write_text(json.dumps({"fallback_reason": "no key"}))
            (p / "handoff.md").write_text("checkpoint_type: a\nCHECKPOINT_TYPE: b\n")
            b = capability_score.score_run(p)["behavioral"]
        self.assertEqual(b["source_count"], 2)
        self.assertTrue(b["fallback_recorded"])
        self.assertEqual(b["human_checkpoint_count"], 2)

    def test_score_run_manifest_without_fallback(self):
        with tempfile.TemporaryDirectory() as d:
            (Path(d) / "run_manifest.json").write_text("{}")
            b = capability_score.score_run(Path(d))["behavioral"]
        self.assertFalse(b["fallback_recorded"])

    def test_main_skill_only_and_default(self):
        code, out, _ = call_main(capability_score, ["--skill-only"])
        self.assertEqual(code, 0)
        self.assertIn("dimensions", json.loads(out))
        code, out, _ = call_main(capability_score, [])
        self.assertIn("dimensions", json.loads(out))

    def test_main_with_dir(self):
        with tempfile.TemporaryDirectory() as d:
            code, out, _ = call_main(capability_score, ["--dir", d])
        self.assertEqual(code, 0)
        self.assertIn("behavioral", json.loads(out))

    def test_run_as_script(self):
        code, out, _ = run_script(SCRIPTS / "capability_score.py", ["--skill-only"])
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(out)["max"], 55)


class TestCatalogLoader(unittest.TestCase):
    def test_json_preferred_over_yaml(self):
        with tempfile.TemporaryDirectory() as d:
            (Path(d) / "x.json").write_text('{"from": "json"}')
            (Path(d) / "x.yaml").write_text("from: yaml\n")
            with mock.patch.object(catalog_loader, "CATALOGS_DIR", Path(d)):
                self.assertEqual(catalog_loader.load_catalog("x"), {"from": "json"})

    def test_yaml_used_when_no_json(self):
        fake_yaml = mock.MagicMock()
        fake_yaml.safe_load.return_value = {"from": "yaml"}
        with tempfile.TemporaryDirectory() as d:
            (Path(d) / "y.yaml").write_text("from: yaml\n")
            with mock.patch.object(catalog_loader, "CATALOGS_DIR", Path(d)), \
                    mock.patch.dict(sys.modules, {"yaml": fake_yaml}):
                self.assertEqual(catalog_loader.load_catalog("y"), {"from": "yaml"})

    def test_yaml_without_pyyaml_raises_runtime_error(self):
        real_import = builtins.__import__

        def fake_import(name, *a, **k):
            if name == "yaml":
                raise ImportError("no yaml")
            return real_import(name, *a, **k)

        with tempfile.TemporaryDirectory() as d:
            (Path(d) / "y.yaml").write_text("from: yaml\n")
            with mock.patch.object(catalog_loader, "CATALOGS_DIR", Path(d)), \
                    mock.patch.dict(sys.modules, {"yaml": None}), \
                    mock.patch("builtins.__import__", fake_import):
                with self.assertRaises(RuntimeError) as cm:
                    catalog_loader.load_catalog("y")
        self.assertIn("PyYAML not installed", str(cm.exception))

    def test_missing_catalog_raises(self):
        with tempfile.TemporaryDirectory() as d:
            with mock.patch.object(catalog_loader, "CATALOGS_DIR", Path(d)):
                with self.assertRaises(FileNotFoundError):
                    catalog_loader.load_catalog("nope")

    def test_list_catalogs_dedups_and_filters(self):
        with tempfile.TemporaryDirectory() as d:
            for n in ("b.json", "a.json", "a.yaml", "c.txt"):
                (Path(d) / n).write_text("")
            with mock.patch.object(catalog_loader, "CATALOGS_DIR", Path(d)):
                self.assertEqual(catalog_loader.list_catalogs(), ["a", "b"])

    def test_list_catalogs_missing_dir(self):
        with mock.patch.object(catalog_loader, "CATALOGS_DIR", Path("/nonexistent/cat-dir")):
            self.assertEqual(catalog_loader.list_catalogs(), [])

    def test_real_catalog_loads(self):
        self.assertIn("intent_classes", catalog_loader.list_catalogs())
        self.assertIsInstance(catalog_loader.load_catalog("intent_classes"), dict)


class TestDepsProbe(unittest.TestCase):
    def test_importable_true(self):
        with mock.patch.dict(sys.modules, {"openpyxl": mock.MagicMock()}):
            self.assertTrue(deps_probe.openpyxl_importable())

    def test_importable_false_when_missing(self):
        with mock.patch.dict(sys.modules, {"openpyxl": None}):
            self.assertFalse(deps_probe.openpyxl_importable())


class TestChainTrackerMain(unittest.TestCase):
    def test_follow_references_skips_rejected_links(self):
        t = chain_tracker.ChainTracker(max_depth=2, max_nodes=30)
        t.add_source("https://a.example/x")
        added = t.follow_references(
            "https://a.example/x",
            "https://a.example/x https://b.example/y https://b.example/y",
            "n0", 0)
        self.assertEqual(added, ["https://b.example/y"])
        self.assertEqual(len(t.nodes), 2)

    def test_add_normal_flow_and_persist(self):
        with tempfile.TemporaryDirectory() as d:
            code, out, _ = call_main(chain_tracker, ["--dir", d, "--add", "https://a.example/x"])
            self.assertEqual(code, 0)
            data = json.loads(out)
            self.assertEqual(data["node_count"], 1)
            saved = json.loads((Path(d) / "reference-chain.json").read_text())
            self.assertEqual(saved["nodes"][0]["url"], "https://a.example/x")
            # reload from disk: duplicate add is rejected, node count stays 1
            code, out, _ = call_main(chain_tracker, ["--dir", d, "--add", "https://a.example/x"])
            self.assertEqual(json.loads(out)["node_count"], 1)

    def test_follow_file_uses_last_node_as_parent(self):
        with tempfile.TemporaryDirectory() as d:
            call_main(chain_tracker, ["--dir", d, "--add", "https://a.example/x"])
            f = Path(d) / "content.txt"
            f.write_text("see https://b.example/y and https://c.example/z")
            code, out, _ = call_main(chain_tracker, ["--dir", d, "--follow-file", str(f)])
        data = json.loads(out)
        self.assertEqual(data["node_count"], 3)
        self.assertEqual(len(data["edges"]), 2)
        self.assertEqual(data["nodes"][1]["depth"], 1)

    def test_follow_file_with_explicit_parent(self):
        with tempfile.TemporaryDirectory() as d:
            f = Path(d) / "c.txt"
            f.write_text("https://b.example/y")
            code, out, _ = call_main(chain_tracker, [
                "--dir", d, "--add", "https://a.example/x", "--parent", "root",
                "--follow-file", str(f)])
        data = json.loads(out)
        self.assertEqual(data["node_count"], 2)
        self.assertEqual(data["edges"][0]["from"], "root")
        self.assertEqual(data["edges"][1], {"from": "root", "to": "n1"})

    def test_follow_file_without_nodes_is_noop(self):
        with tempfile.TemporaryDirectory() as d:
            f = Path(d) / "c.txt"
            f.write_text("https://b.example/y")
            code, out, _ = call_main(chain_tracker, ["--dir", d, "--follow-file", str(f)])
        self.assertEqual(json.loads(out)["node_count"], 0)

    def test_run_as_script(self):
        with tempfile.TemporaryDirectory() as d:
            code, out, _ = run_script(SCRIPTS / "chain_tracker.py", ["--dir", d])
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(out)["node_count"], 0)


if __name__ == "__main__":
    unittest.main()
