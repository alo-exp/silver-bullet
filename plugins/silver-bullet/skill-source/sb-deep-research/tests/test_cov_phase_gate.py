"""Coverage tests for phase_gate (in-process; temp skill roots and artifact trees)."""

import builtins
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import covhelp
from covhelp import SCRIPTS, call_main, run_script

import phase_gate as pg


def setUpModule():
    covhelp.block_network()


def tearDownModule():
    covhelp.unblock_network()


CFG = {
    "phases": {
        "scope": {"id": "P1", "required_artifacts": ["scope.md"]},
        "retrieve": {"id": "P3", "required_artifacts": ["sources.jsonl"]},
        "package": {"required_artifacts": ["vloop-rollup.json"]},
    },
    "research_types": {
        "default": {},
        "solution-compare": {"phase_artifacts": {
            "scope": {"add": ["need_profile.json", "scope.md"]},
        }},
    },
    "modes": {
        "quick": {"phases": ["scope", "retrieve"]},
        "deep": {"phases": ["scope", "package"]},
    },
}

PACK_ID = "demo-pack"
GOOD_PACK = {"category_id": PACK_ID,
             "inclusion_criteria": {"rule": "min_pass_count", "min_pass_count": 2, "criteria": ["a", "b"]}}


class TempTree(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.addCleanup(self._td.cleanup)
        self.root = Path(self._td.name)
        self.out = self.root / "out"
        self.out.mkdir()

    def put(self, rel, text="x" * 30):
        p = self.out / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text, encoding="utf-8")
        return p


class TestLoadPhasesConfig(TempTree):
    def fake_root(self):
        return mock.patch.object(pg, "_skill_root", return_value=self.root)

    def test_real_config_loads(self):
        self.assertIn("phases", pg.load_phases_config())

    def test_json_preferred(self):
        (self.root / "phases.json").write_text('{"from": "json"}')
        (self.root / "phases.yaml").write_text("from: yaml")
        with self.fake_root():
            self.assertEqual(pg.load_phases_config(), {"from": "json"})

    def test_yaml_fallback(self):
        (self.root / "phases.yaml").write_text("from: yaml")
        fake = mock.MagicMock()
        fake.safe_load.return_value = {"from": "yaml"}
        with self.fake_root(), mock.patch.dict(sys.modules, {"yaml": fake}):
            self.assertEqual(pg.load_phases_config(), {"from": "yaml"})

    def test_yaml_without_pyyaml(self):
        (self.root / "phases.yaml").write_text("from: yaml")
        real_import = builtins.__import__

        def fake_import(name, *a, **k):
            if name == "yaml":
                raise ImportError("nope")
            return real_import(name, *a, **k)

        with self.fake_root(), mock.patch.dict(sys.modules, {"yaml": None}), \
                mock.patch("builtins.__import__", fake_import):
            with self.assertRaisesRegex(RuntimeError, "PyYAML not installed"):
                pg.load_phases_config()

    def test_neither_file(self):
        with self.fake_root():
            with self.assertRaises(FileNotFoundError):
                pg.load_phases_config()


class TestResolvers(TempTree):
    def test_research_type(self):
        self.assertEqual(pg.resolve_research_type(self.out, "x"), "x")
        self.assertEqual(pg.resolve_research_type(self.out), "default")
        self.put("run_manifest.json", json.dumps({"research_type": "solution-compare"}))
        self.assertEqual(pg.resolve_research_type(self.out), "solution-compare")
        self.put("run_manifest.json", json.dumps({"research_type": ""}))
        self.assertEqual(pg.resolve_research_type(self.out), "default")

    def test_mode(self):
        self.assertEqual(pg.resolve_mode(self.out, "deep"), "deep")
        self.assertIsNone(pg.resolve_mode(self.out))
        self.put("run_manifest.json", json.dumps({"mode": "quick"}))
        self.assertEqual(pg.resolve_mode(self.out), "quick")
        self.put("run_manifest.json", json.dumps({}))
        self.assertIsNone(pg.resolve_mode(self.out))

    def test_required_artifacts(self):
        f = pg.phase_required_artifacts
        self.assertEqual(f("nope", CFG), [])
        self.assertEqual(f("scope", CFG), ["scope.md"])
        self.assertEqual(f("scope", CFG, "solution-compare"), ["scope.md", "need_profile.json"])
        self.assertEqual(f("retrieve", CFG, "solution-compare"), ["sources.jsonl"])
        self.assertEqual(f("scope", CFG, "unknown-type"), ["scope.md"])
        self.assertEqual(f("scope", {"phases": {"scope": {}}}), [])


class TestModeGate(unittest.TestCase):
    def test_gate(self):
        self.assertEqual(pg.check_solution_mode_gate("quick", "default"), (True, "ok"))
        self.assertEqual(pg.check_solution_mode_gate("deep", "solution-landscape"), (True, "ok"))
        self.assertEqual(pg.check_solution_mode_gate("ultradeep", "solution-compare"), (True, "ok"))
        ok, msg = pg.check_solution_mode_gate("standard", "solution-compare")
        self.assertFalse(ok)
        self.assertIn("requires mode deep or ultradeep (got standard)", msg)


class TestCategoryPack(TempTree):
    def packs(self):
        d = self.root / "packs"
        d.mkdir(exist_ok=True)
        return mock.patch.object(pg, "_category_packs_dir", return_value=d), d

    def test_packs_dir_is_under_reference(self):
        self.assertEqual(pg._category_packs_dir().parts[-3:], ("reference", "landscape", "category-packs"))

    def test_load_pack(self):
        patcher, d = self.packs()
        with patcher:
            with self.assertRaisesRegex(FileNotFoundError, "not found"):
                pg._load_category_pack_for_gate(PACK_ID)
            (d / f"{PACK_ID}.json").write_text(json.dumps({"category_id": "other"}))
            with self.assertRaisesRegex(ValueError, "mismatch"):
                pg._load_category_pack_for_gate(PACK_ID)
            (d / f"{PACK_ID}.json").write_text(json.dumps(GOOD_PACK))
            self.assertEqual(pg._load_category_pack_for_gate(PACK_ID), GOOD_PACK)

    def test_effective_criteria(self):
        self.assertEqual(pg._effective_inclusion_criteria({"inclusion_criteria": {"a": 1}}, GOOD_PACK), {"a": 1})
        self.assertEqual(pg._effective_inclusion_criteria({}, GOOD_PACK), GOOD_PACK["inclusion_criteria"])
        self.assertEqual(pg._effective_inclusion_criteria({}, {}), {})

    def test_gate_paths(self):
        patcher, d = self.packs()
        pack_file = d / f"{PACK_ID}.json"
        with patcher:
            ok, msg = pg.check_category_pack_gate({})
            self.assertFalse(ok)
            self.assertIn("missing category_pack_id", msg)
            ok, msg = pg.check_category_pack_gate({"category_pack_id": PACK_ID})
            self.assertIn("unresolvable category_pack_id 'demo-pack'", msg)
            pack_file.write_text("{broken")
            ok, msg = pg.check_category_pack_gate({"category_pack_id": PACK_ID})
            self.assertFalse(ok)
            self.assertIn("unresolvable", msg)
            pack_file.write_text(json.dumps(GOOD_PACK))
            self.assertEqual(pg.check_category_pack_gate({"category_pack_id": PACK_ID}), (True, "ok"))
            # empty criteria via pack
            pack_file.write_text(json.dumps({"category_id": PACK_ID, "inclusion_criteria": {}}))
            ok, msg = pg.check_category_pack_gate({"category_pack_id": PACK_ID})
            self.assertEqual((ok, msg), (False, "inclusion_criteria empty (pack and need_profile overrides)"))
            # need_profile override rescues it
            override = {"rule": "min_pass_count", "min_pass_count": 1, "criteria": ["x"]}
            self.assertEqual(pg.check_category_pack_gate(
                {"category_pack_id": PACK_ID, "inclusion_criteria": override}), (True, "ok"))
            bad_rule = dict(override, rule="other")
            ok, msg = pg.check_category_pack_gate({"category_pack_id": PACK_ID, "inclusion_criteria": bad_rule})
            self.assertEqual(msg, "inclusion_criteria.rule must be min_pass_count")
            for bad in (0, -1, "2", None):
                ok, msg = pg.check_category_pack_gate({"category_pack_id": PACK_ID,
                                                       "inclusion_criteria": dict(override, min_pass_count=bad)})
                self.assertEqual(msg, "inclusion_criteria.min_pass_count must be a positive integer")

    def test_real_pack_passes_gate(self):
        need = {"category_pack_id": "agentic-sdlc-process-orchestrator"}
        self.assertEqual(pg.check_category_pack_gate(need), (True, "ok"))


class TestNeedProfileGate(TempTree):
    def test_gate(self):
        self.assertEqual(pg.check_need_profile_gate(self.out), (False, "missing need_profile.json"))
        self.put("need_profile.json", "{bad")
        self.assertEqual(pg.check_need_profile_gate(self.out), (False, "invalid need_profile.json"))
        self.put("need_profile.json", json.dumps({"license_preference": "oss"}))
        self.assertEqual(pg.check_need_profile_gate(self.out),
                         (False, "need_profile.json interview_complete is false"))
        self.put("need_profile.json", json.dumps({"interview_complete": True, "license_preference": "free"}))
        self.assertEqual(pg.check_need_profile_gate(self.out),
                         (False, "need_profile.json license_preference not set"))
        good = {"interview_complete": True, "license_preference": "mixed"}
        self.put("need_profile.json", json.dumps(good))
        self.assertEqual(pg.check_need_profile_gate(self.out), (True, "ok"))
        # solution type adds the category pack gate
        ok, msg = pg.check_need_profile_gate(self.out, research_type="solution-compare")
        self.assertFalse(ok)
        self.assertIn("missing category_pack_id", msg)
        good["category_pack_id"] = "agentic-sdlc-process-orchestrator"
        self.put("need_profile.json", json.dumps(good))
        self.assertEqual(pg.check_need_profile_gate(self.out, research_type="solution-landscape"), (True, "ok"))
        # research type resolved from the manifest when not passed
        self.put("run_manifest.json", json.dumps({"research_type": "solution-compare"}))
        good.pop("category_pack_id")
        self.put("need_profile.json", json.dumps(good))
        self.assertFalse(pg.check_need_profile_gate(self.out)[0])


class TestArtifactSatisfied(TempTree):
    def test_missing(self):
        self.assertEqual(pg.artifact_satisfied(self.out, "a.md"), (False, "missing: a.md"))

    def test_jsonl(self):
        self.put("e.jsonl", "")
        self.assertEqual(pg.artifact_satisfied(self.out, "e.jsonl"), (False, "empty: e.jsonl"))
        self.put("e.jsonl", "{}\n")
        self.assertEqual(pg.artifact_satisfied(self.out, "e.jsonl"), (True, "ok"))

    def test_md(self):
        self.put("a.md", "  short  ")
        self.assertEqual(pg.artifact_satisfied(self.out, "a.md"), (False, "too short: a.md"))
        self.put("a.md", "x" * 20)
        self.assertEqual(pg.artifact_satisfied(self.out, "a.md"), (True, "ok"))

    def test_json(self):
        self.put("a.json", "{bad")
        self.assertEqual(pg.artifact_satisfied(self.out, "a.json"), (False, "invalid json: a.json"))
        self.put("a.json", "{}")
        self.assertEqual(pg.artifact_satisfied(self.out, "a.json"), (False, "empty: a.json"))
        self.put("a.json", '{"k": 1}')
        self.assertEqual(pg.artifact_satisfied(self.out, "a.json"), (True, "ok"))

    def test_shortlist_requires_five_only_for_landscape(self):
        art = "shortlist/shortlist.json"
        self.put(art, json.dumps({"solutions": [1, 2]}))
        self.assertEqual(pg.artifact_satisfied(self.out, art), (True, "ok"))  # default type
        self.put("run_manifest.json", json.dumps({"research_type": "solution-compare"}))
        self.assertEqual(pg.artifact_satisfied(self.out, art), (True, "ok"))
        self.put("run_manifest.json", json.dumps({"research_type": "solution-landscape"}))
        self.assertEqual(pg.artifact_satisfied(self.out, art),
                         (False, "shortlist must have exactly 5 solutions, got 2"))
        self.put(art, json.dumps({"solutions": [1, 2, 3, 4, 5]}))
        self.assertEqual(pg.artifact_satisfied(self.out, art), (True, "ok"))
        self.put(art, json.dumps({"other": 1}))
        self.assertEqual(pg.artifact_satisfied(self.out, art),
                         (False, "shortlist must have exactly 5 solutions, got 0"))

    def test_other_extensions(self):
        self.put("r.html", "")
        self.assertEqual(pg.artifact_satisfied(self.out, "r.html"), (False, "empty: r.html"))
        self.put("r.html", "<html>")
        self.assertEqual(pg.artifact_satisfied(self.out, "r.html"), (True, "ok"))


class TestCheckPhase(TempTree):
    def test_unknown_phase(self):
        res = pg.check_phase(self.out, "zzz", CFG)
        self.assertEqual(res, {"phase": "zzz", "status": "error", "reason": "unknown phase: zzz"})

    def test_default_config_loaded_when_none(self):
        res = pg.check_phase(self.out, "scope")
        self.assertEqual(res["status"], "fail")
        self.assertEqual(res["phase_id"], pg.load_phases_config()["phases"]["scope"]["id"])

    def test_pass_and_fail(self):
        res = pg.check_phase(self.out, "scope", CFG)
        self.assertEqual(res["status"], "fail")
        self.assertEqual(res["artifacts"], [{"artifact": "scope.md", "ok": False, "detail": "missing: scope.md"}])
        self.assertEqual(res["phase_id"], "P1")
        self.assertEqual(res["research_type"], "default")
        self.put("scope.md")
        self.assertEqual(pg.check_phase(self.out, "scope", CFG)["status"], "pass")
        self.assertIsNone(pg.check_phase(self.out, "package", CFG)["phase_id"])

    def test_solution_types_add_need_profile_gate_on_scope_and_retrieve_only(self):
        self.put("scope.md")
        self.put("sources.jsonl", "{}\n")
        res = pg.check_phase(self.out, "scope", CFG, "solution-compare")
        self.assertEqual(res["artifacts"][0]["artifact"], "need_profile.json (gate)")
        self.assertFalse(res["artifacts"][0]["ok"])
        self.assertEqual(res["status"], "fail")
        res = pg.check_phase(self.out, "retrieve", CFG, "solution-compare")
        self.assertEqual(res["artifacts"][0]["detail"], "missing need_profile.json")
        res = pg.check_phase(self.out, "package", CFG, "solution-compare")
        self.assertNotIn("need_profile.json (gate)", [a["artifact"] for a in res["artifacts"]])
        # default type never runs the gate
        res = pg.check_phase(self.out, "retrieve", CFG, "default")
        self.assertEqual([a["artifact"] for a in res["artifacts"]], ["sources.jsonl"])
        self.assertEqual(res["status"], "pass")


class TestCheckModeComplete(TempTree):
    def test_unknown_mode(self):
        self.assertEqual(pg.check_mode_complete(self.out, "zzz", CFG),
                         {"mode": "zzz", "status": "error", "reason": "unknown mode: zzz"})

    def test_solution_type_rejects_quick(self):
        res = pg.check_mode_complete(self.out, "quick", CFG, "solution-compare")
        self.assertEqual(res["status"], "fail")
        self.assertEqual(res["phases"], [])
        self.assertIn("requires mode deep or ultradeep", res["reason"])

    def test_phases_rolled_up(self):
        res = pg.check_mode_complete(self.out, "quick", CFG)
        self.assertEqual(res["status"], "fail")
        self.assertEqual([p["phase"] for p in res["phases"]], ["scope", "retrieve"])
        self.put("scope.md")
        self.put("sources.jsonl", "{}\n")
        res = pg.check_mode_complete(self.out, "quick", CFG)
        self.assertEqual(res["status"], "pass")
        self.assertEqual(res["research_type"], "default")

    def test_default_config(self):
        res = pg.check_mode_complete(self.out, "quick")
        self.assertEqual(res["status"], "fail")


class TestCLI(TempTree):
    def test_not_a_directory(self):
        code, out, _ = call_main(pg, ["--dir", str(self.root / "nope")])
        self.assertEqual(code, 1)
        self.assertIn("not a directory", json.loads(out)["reason"])

    def test_full_gate_defaults_to_standard(self):
        code, out, _ = call_main(pg, ["--dir", str(self.out)])
        self.assertEqual(code, 1)
        self.assertEqual(json.loads(out)["mode"], "standard")

    def test_mode_from_manifest_and_flag(self):
        self.put("run_manifest.json", json.dumps({"mode": "quick"}))
        _, out, _ = call_main(pg, ["--dir", str(self.out)])
        self.assertEqual(json.loads(out)["mode"], "quick")
        _, out, _ = call_main(pg, ["--dir", str(self.out), "--mode", "deep"])
        self.assertEqual(json.loads(out)["mode"], "deep")

    def test_single_phase_pass_and_fail(self):
        code, out, _ = call_main(pg, ["--dir", str(self.out), "--phase", "scope"])
        self.assertEqual(code, 1)
        self.put("scope.md")
        code, out, _ = call_main(pg, ["--dir", str(self.out), "--phase", "scope"])
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(out)["status"], "pass")

    def test_phase_solution_type_with_bad_mode_fails_fast(self):
        code, out, _ = call_main(pg, ["--dir", str(self.out), "--phase", "scope", "--mode", "quick",
                                      "--research-type", "solution-compare"])
        self.assertEqual(code, 1)
        res = json.loads(out)
        self.assertEqual((res["phase"], res["mode"], res["status"]), ("scope", "quick", "fail"))
        self.assertIn("requires mode deep or ultradeep", res["reason"])

    def test_phase_solution_type_good_or_absent_mode_continues(self):
        for extra in (["--mode", "deep"], []):
            code, out, _ = call_main(pg, ["--dir", str(self.out), "--phase", "scope",
                                          "--research-type", "solution-compare", *extra])
            res = json.loads(out)
            self.assertEqual(res["phase"], "scope")
            self.assertIn("artifacts", res)

    def test_run_as_script(self):
        code, out, _ = run_script(SCRIPTS / "phase_gate.py", ["--dir", str(self.out), "--phase", "nope"])
        self.assertEqual(code, 1)
        self.assertEqual(json.loads(out)["status"], "error")


if __name__ == "__main__":
    unittest.main()
