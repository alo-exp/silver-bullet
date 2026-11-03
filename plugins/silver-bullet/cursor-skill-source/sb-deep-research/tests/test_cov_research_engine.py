"""Coverage tests for research_engine (in-process; no network, no real sleeps)."""

import builtins
import contextlib
import io
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import covhelp
from covhelp import SCRIPTS, call_main, run_script

import research_engine as re_


def setUpModule():
    covhelp.block_network()


def tearDownModule():
    covhelp.unblock_network()


def make_state(**over):
    base = dict(
        query="q", mode=re_.ResearchMode.DEEP, phase=re_.ResearchPhase.PLAN,
        scope={"s": 1}, plan={"p": 1},
        sources=[re_.Source(url="https://a", title="A", snippet="s", retrieved_at="2026-01-01",
                            credibility_score=0.5)],
        findings=[{"f": 1}], synthesis={"y": 1}, critique={"c": 1}, report="r", metadata={"m": 1},
    )
    base.update(over)
    return re_.ResearchState(**base)


class TestConfig(unittest.TestCase):
    def test_real_config(self):
        self.assertIn("phases", re_.load_phases_config())

    def test_yaml_paths(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            with mock.patch.object(re_, "SKILL_ROOT", root):
                with self.assertRaises(FileNotFoundError):
                    re_.load_phases_config()
                (root / "phases.yaml").write_text("a: 1")
                fake = mock.MagicMock()
                fake.safe_load.return_value = {"a": 1}
                with mock.patch.dict(sys.modules, {"yaml": fake}):
                    self.assertEqual(re_.load_phases_config(), {"a": 1})
                real_import = builtins.__import__

                def fake_import(name, *a, **k):
                    if name == "yaml":
                        raise ImportError("x")
                    return real_import(name, *a, **k)

                with mock.patch.dict(sys.modules, {"yaml": None}), \
                        mock.patch("builtins.__import__", fake_import):
                    with self.assertRaisesRegex(RuntimeError, "PyYAML not installed"):
                        re_.load_phases_config()


class TestSourceAndState(unittest.TestCase):
    def test_citation(self):
        s = re_.Source(url="https://a", title="T", snippet="x", retrieved_at="2026-01-02")
        self.assertEqual(s.to_citation(3), "[3] T - https://a (Retrieved: 2026-01-02)")
        self.assertEqual((s.credibility_score, s.source_type, s.verification_status),
                         (0.0, "web", "unverified"))

    def test_save_load_roundtrip(self):
        st = make_state()
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "state.json"
            st.save(p)
            raw = json.loads(p.read_text())
            self.assertEqual(raw["mode"], "deep")
            self.assertEqual(raw["phase"], "plan")
            self.assertEqual(raw["sources"][0]["title"], "A")
            self.assertEqual(re_.ResearchState.load(p), st)

    def test_save_retries_then_raises(self):
        st = make_state()
        with tempfile.TemporaryDirectory() as d:
            sleeps = []
            with mock.patch.object(re_.time, "sleep", sleeps.append):
                with self.assertRaises(IOError) as ctx:
                    st.save(Path(d))  # a directory: open() fails with an OSError
            self.assertIn("Failed to save state after 3 attempts", str(ctx.exception))
            self.assertEqual(sleeps, [0.5, 1.0])

    def test_save_recovers_after_transient_failure(self):
        st = make_state()
        real_open = builtins.open
        calls = {"n": 0}

        def flaky(path, *a, **k):
            if str(path).endswith("state.json"):
                calls["n"] += 1
                if calls["n"] == 1:
                    raise OSError("transient")
            return real_open(path, *a, **k)

        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "state.json"
            with mock.patch.object(re_.time, "sleep") as sleep, mock.patch("builtins.open", flaky):
                st.save(p)
            sleep.assert_called_once_with(0.5)
            self.assertEqual(calls["n"], 2)
            self.assertEqual(json.loads(p.read_text())["query"], "q")


class TestEngine(unittest.TestCase):
    def setUp(self):
        self.engine = re_.ResearchEngine(re_.ResearchMode.QUICK)

    def test_phases_for_mode(self):
        self.assertEqual([p.value for p in self.engine.phases_for_mode()], ["scope", "retrieve", "package"])
        self.assertEqual(len(self.engine.phases_for_mode(re_.ResearchMode.DEEP)), 9)
        self.engine.config = {}
        self.assertEqual(self.engine.phases_for_mode(), [])

    def test_phase_metadata(self):
        self.assertEqual(self.engine.phase_metadata(re_.ResearchPhase.SCOPE)["id"], "DR-SCOPE")
        self.engine.config = {}
        self.assertEqual(self.engine.phase_metadata(re_.ResearchPhase.SCOPE), {})

    def test_instructions_with_metadata(self):
        self.engine.config = {"phases": {"scope": {
            "id": "X-1", "name": "Scoping", "required_artifacts": ["a.md", "b.md"],
            "vloop_checks": ["check one", "check two"]}}}
        text = self.engine.get_phase_instructions(re_.ResearchPhase.SCOPE)
        self.assertIn("# X-1: Scoping", text)
        self.assertIn("Required artifacts: a.md, b.md", text)
        self.assertIn("- check one\n- check two", text)

    def test_instructions_defaults(self):
        self.engine.config = {}
        text = self.engine.get_phase_instructions(re_.ResearchPhase.CRITIQUE)
        self.assertIn("# DR-CRITIQUE: CRITIQUE", text)
        self.assertIn("Required artifacts: none", text)
        self.assertIn("- (see phases.yaml)", text)

    def test_write_and_read_manifest(self):
        with tempfile.TemporaryDirectory() as d:
            out = Path(d) / "nested" / "run"
            path = self.engine.write_phase_manifest(out)
            self.assertEqual(path, out / "phase_manifest.json")
            data = self.engine.read_phase_manifest(out)
            self.assertEqual(data["mode"], "quick")
            self.assertEqual([p["key"] for p in data["phases"]], ["scope", "retrieve", "package"])
            self.assertTrue(all(p["status"] == "pending" for p in data["phases"]))
            deep = self.engine.write_phase_manifest(out, re_.ResearchMode.DEEP)
            self.assertEqual(self.engine.read_phase_manifest(out)["mode"], "deep")
            self.assertEqual(deep, path)

    def test_manifest_version_default(self):
        self.engine.config = {"modes": {}}
        with tempfile.TemporaryDirectory() as d:
            self.engine.write_phase_manifest(Path(d))
            self.assertEqual(self.engine.read_phase_manifest(Path(d))["version"], "1.0.0")
            self.assertEqual(self.engine.read_phase_manifest(Path(d))["phases"], [])

    def test_read_manifest_missing(self):
        with tempfile.TemporaryDirectory() as d:
            with self.assertRaisesRegex(FileNotFoundError, "phase_manifest.json not found"):
                self.engine.read_phase_manifest(Path(d))

    def test_initialize_research(self):
        st = self.engine.initialize_research("why?")
        self.assertIs(self.engine.state, st)
        self.assertEqual((st.query, st.mode, st.phase), ("why?", re_.ResearchMode.QUICK, re_.ResearchPhase.SCOPE))
        self.assertIn("started_at", st.metadata)
        self.assertEqual(st.metadata["version"], self.engine.config["version"])
        self.engine.config = {}
        self.assertEqual(self.engine.initialize_research("x").metadata["version"], "1.0.0")

    def test_execute_phase_prints_instructions(self):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            res = self.engine.execute_phase(re_.ResearchPhase.SCOPE)
        self.assertEqual((res["phase"], res["phase_id"], res["status"]),
                         ("scope", "DR-SCOPE", "instructions_displayed"))
        self.assertIn("DR-SCOPE", buf.getvalue())

    def test_run_pipeline(self):
        with tempfile.TemporaryDirectory() as d:
            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                report = self.engine.run_pipeline("q", Path(d) / "o")
            self.assertEqual(report, str(Path(d) / "o" / "research_report.md"))
            self.assertTrue((Path(d) / "o" / "phase_manifest.json").exists())
            self.assertEqual(self.engine.state.phase, re_.ResearchPhase.PACKAGE)
            self.assertEqual(buf.getvalue().count("Output directory:"), 3)

    def test_run_pipeline_default_out_dir(self):
        cwd = os.getcwd()
        with tempfile.TemporaryDirectory() as d:
            os.chdir(d)
            try:
                with contextlib.redirect_stdout(io.StringIO()):
                    report = self.engine.run_pipeline("q")
                self.assertEqual(report, ".planning/research/offline-run/research_report.md")
                self.assertTrue(Path(".planning/research/offline-run/phase_manifest.json").exists())
            finally:
                os.chdir(cwd)


class TestCLI(unittest.TestCase):
    def test_list_phases(self):
        code, out, _ = call_main(re_, ["--list-phases", "--mode", "quick"])
        self.assertEqual(code, 0)
        self.assertEqual(out.splitlines(), ["DR-SCOPE: scope", "DR-RETRIEVE: retrieve", "DR-PACKAGE: package"])
        with mock.patch.object(re_.ResearchEngine, "phase_metadata", return_value={}):
            _, out, _ = call_main(re_, ["--list-phases", "-m", "quick"])
        self.assertEqual(out.splitlines()[0], "scope: scope")

    def test_single_phase(self):
        code, out, _ = call_main(re_, ["--phase", "retrieve"])
        self.assertEqual(code, 0)
        self.assertIn("DR-RETRIEVE", out)

    def test_manifest_only(self):
        code, out, err = call_main(re_, ["--manifest-only"])
        self.assertEqual(code, 1)
        self.assertIn("--out-dir required", err)
        with tempfile.TemporaryDirectory() as d:
            code, out, _ = call_main(re_, ["--manifest-only", "--out-dir", d, "-m", "deep"])
            self.assertEqual(code, 0)
            self.assertEqual(out.strip(), f"Wrote {Path(d) / 'phase_manifest.json'}")

    def test_query_required(self):
        code, _, err = call_main(re_, [])
        self.assertEqual(code, 2)
        self.assertIn("--query required", err)

    def test_pipeline(self):
        with tempfile.TemporaryDirectory() as d:
            code, out, _ = call_main(re_, ["-q", "why", "--out-dir", d, "-m", "quick"])
            self.assertEqual(code, 0)
            self.assertIn(f"Pipeline scaffold complete. Target report: {Path(d) / 'research_report.md'}", out)

    def test_run_as_script(self):
        code, out, _ = run_script(SCRIPTS / "research_engine.py", ["--phase", "scope"])
        self.assertEqual(code, 0)
        self.assertIn("DR-SCOPE", out)


if __name__ == "__main__":
    unittest.main()
