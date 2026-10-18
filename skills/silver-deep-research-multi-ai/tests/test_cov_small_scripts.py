"""Offline unit tests for the small DR-multi-AI helper scripts.

Covers skill_paths, compression_markers, consolidate, generate_report,
generate_landscape_report, generate_spa_report, package_solution_outputs,
migrate_run_manifest and dr_multi_ai_cli. Everything runs in-process with
the heavy collaborators replaced by fakes: no network, no subprocesses.
"""

from __future__ import annotations

import contextlib
import io
import json
import os
import runpy
import sys
import tempfile
import types
import unittest
import warnings
from pathlib import Path
from unittest import mock

SKILL_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = SKILL_ROOT / "scripts"
sys.path.insert(0, str(SCRIPTS))

import compression_markers  # noqa: E402
import consolidate  # noqa: E402
import dr_multi_ai_cli  # noqa: E402
import generate_landscape_report  # noqa: E402
import generate_spa_report  # noqa: E402
import migrate_run_manifest  # noqa: E402
import package_solution_outputs  # noqa: E402
import skill_paths  # noqa: E402


def _run(func, *args, **kwargs):
    """Call func capturing stdout/stderr; return (result, stdout, stderr)."""
    out, err = io.StringIO(), io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
        result = func(*args, **kwargs)
    return result, out.getvalue(), err.getvalue()


class SkillPathsTests(unittest.TestCase):
    def test_resolve_sibling_install_layout(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            skill = Path(tmp) / "install" / "silver-deep-research-multi-ai" / "scripts"
            skill.mkdir(parents=True)
            sib = Path(tmp) / "install" / "sb:other" / "scripts"
            sib.mkdir(parents=True)
            (sib / "marker.py").write_text("", encoding="utf-8")
            fake_file = skill / "skill_paths.py"
            with mock.patch.object(skill_paths, "__file__", str(fake_file)):
                # "silver-other" is not present, but its "sb:other" alias is.
                self.assertEqual(skill_paths.resolve_skill_scripts("silver-other", marker="marker.py"), sib)

    def test_resolve_prefers_exact_sibling_name(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            skill = Path(tmp) / "silver-deep-research-multi-ai" / "scripts"
            skill.mkdir(parents=True)
            sib = Path(tmp) / "silver-x" / "scripts"
            sib.mkdir(parents=True)
            (sib / "m.py").write_text("", encoding="utf-8")
            with mock.patch.object(skill_paths, "__file__", str(skill / "skill_paths.py")):
                self.assertEqual(skill_paths.resolve_skill_scripts("silver-x", marker="m.py"), sib)

    def test_resolve_non_silver_name_has_no_alias(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            skill = Path(tmp) / "a" / "scripts"
            skill.mkdir(parents=True)
            with mock.patch.object(skill_paths, "__file__", str(skill / "skill_paths.py")):
                with self.assertRaises(FileNotFoundError) as cm:
                    skill_paths.resolve_skill_scripts("plainname", marker="nope.py")
            self.assertIn("nope.py not found for skill 'plainname'", str(cm.exception))

    def test_resolve_falls_back_to_skills_tree_in_parents(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            here = root / "mirror" / "deep" / "scripts"
            here.mkdir(parents=True)
            target = root / "skills" / "silver-y" / "scripts"
            target.mkdir(parents=True)
            (target / "m.py").write_text("", encoding="utf-8")
            with mock.patch.object(skill_paths, "__file__", str(here / "skill_paths.py")):
                resolved = skill_paths.resolve_skill_scripts("silver-y", marker="m.py")
            self.assertEqual(resolved.resolve(), target.resolve())

    def test_ensure_scripts_on_path_prepends_once(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            d = Path(tmp)
            saved = list(sys.path)
            try:
                with mock.patch.object(skill_paths, "resolve_skill_scripts", return_value=d) as res:
                    self.assertEqual(skill_paths.ensure_scripts_on_path("silver-z", "mk.py"), d)
                    res.assert_called_once_with("silver-z", marker="mk.py")
                self.assertEqual(sys.path[0], str(d.resolve()))
                count = sys.path.count(str(d.resolve()))
                skill_paths.ensure_dir_on_path(d)
                self.assertEqual(sys.path.count(str(d.resolve())), count)
            finally:
                sys.path[:] = saved

    def test_resolve_multi_ai_scripts_local_when_files_present(self) -> None:
        self.assertEqual(skill_paths.resolve_multi_ai_scripts(), SCRIPTS)

    def test_resolve_multi_ai_scripts_searches_parents(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            here = root / "thin" / "scripts"
            here.mkdir(parents=True)
            canon = root / "skills" / "silver-deep-research-multi-ai" / "scripts"
            canon.mkdir(parents=True)
            (canon / "synthesize_landscape.py").write_text("", encoding="utf-8")
            with mock.patch.object(skill_paths, "__file__", str(here / "skill_paths.py")):
                self.assertEqual(skill_paths.resolve_multi_ai_scripts().resolve(), canon.resolve())

    def test_resolve_multi_ai_scripts_returns_here_when_nothing_found(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            here = Path(tmp) / "lonely" / "scripts"
            here.mkdir(parents=True)
            with mock.patch.object(skill_paths, "__file__", str(here / "skill_paths.py")):
                self.assertEqual(skill_paths.resolve_multi_ai_scripts().resolve(), here.resolve())

    def test_ensure_multi_ai_scripts_on_path_returns_directory(self) -> None:
        saved = list(sys.path)
        try:
            self.assertEqual(skill_paths.ensure_multi_ai_scripts_on_path(), SCRIPTS)
            self.assertIn(str(SCRIPTS.resolve()), sys.path)
        finally:
            sys.path[:] = saved


class CompressionMarkerTests(unittest.TestCase):
    def test_empty_text_has_no_markers(self) -> None:
        self.assertFalse(compression_markers.contains_compression_markers(""))
        self.assertEqual(compression_markers.sanitize_compression_markers(""), "")

    def test_snippets_respect_limit_and_skip_clean_lines(self) -> None:
        text = "clean\n[Archived]\nalso clean\nomitted 5 lines\n[3 more lines]\n"
        snippets = compression_markers.find_compression_marker_snippets(text, limit=2)
        self.assertEqual(snippets, ["[Archived]", "omitted 5 lines"])
        self.assertEqual(compression_markers.find_compression_marker_snippets("nothing here"), [])

    def test_sanitize_inline_marker_kept_when_text_remains_and_dropped_when_empty(self) -> None:
        text = "keep this ... [lean-ctx: cut 4] tail\nprefix [lean-ctx:x] [Archived]\nreport.md [12L]\nplain"
        cleaned = compression_markers.sanitize_compression_markers(text)
        self.assertEqual(cleaned.splitlines(), ["keep this  tail", "prefix", "plain"])

    def test_sanitize_drops_line_whose_residue_still_matches_marker(self) -> None:
        # "[3 more lines]" is not stripped by the inline regex, so the line is dropped.
        text = "text [3 more lines] more\nok"
        self.assertEqual(compression_markers.sanitize_compression_markers(text), "ok")

    def test_sanitize_returns_clean_text_unchanged(self) -> None:
        self.assertEqual(compression_markers.sanitize_compression_markers("a\nb"), "a\nb")

    def test_assert_no_markers_message_with_and_without_snippets(self) -> None:
        with self.assertRaises(ValueError) as cm:
            compression_markers.assert_no_compression_markers("x\n[Archived]", context="doc")
        self.assertEqual(str(cm.exception), "compression markers in doc: [Archived]")
        with mock.patch.object(compression_markers, "find_compression_marker_snippets", return_value=[]):
            with self.assertRaises(ValueError) as cm2:
                compression_markers.assert_no_compression_markers("[Archived]")
        self.assertEqual(str(cm2.exception), "compression markers in durable artifact: (marker detected)")
        compression_markers.assert_no_compression_markers("fine")

    def test_assert_file_free_of_markers(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            good = Path(tmp) / "good.md"
            good.write_text("fine\n", encoding="utf-8")
            bad = Path(tmp) / "bad.md"
            bad.write_text("omitted 9 lines\n", encoding="utf-8")
            compression_markers.assert_file_free_of_compression_markers(Path(tmp) / "missing.md")
            compression_markers.assert_file_free_of_compression_markers(good)
            with self.assertRaises(ValueError) as cm:
                compression_markers.assert_file_free_of_compression_markers(bad)
            self.assertIn(str(bad), str(cm.exception))
            with self.assertRaises(ValueError) as cm2:
                compression_markers.assert_file_free_of_compression_markers(str(bad), label="lbl")
            self.assertIn("compression markers in lbl:", str(cm2.exception))


class ConsolidateTests(unittest.TestCase):
    INDEX = {
        "entries": [
            {"work_item_id": "w1", "logical_model_id": "a"},
            {"work_item_id": "w1", "logical_model_id": "b"},
            {"work_item_id": "w1", "logical_model_id": "c"},
        ]
    }

    def _env(self, agent: str, family: str, claims: list, phase: str = "DR-TRIANGULATE") -> dict:
        return {
            "phase_id": phase,
            "work_item_id": "w1",
            "logical_model_id": agent,
            "model_family_id": family,
            "payload": {"claim_candidates": claims},
        }

    def test_validate_index_entry_missing_ids(self) -> None:
        for entry in ({"logical_model_id": "a"}, {"work_item_id": "w"}):
            with self.assertRaisesRegex(ValueError, "missing work_item_id or logical_model_id"):
                consolidate.validate_inputs([], {"entries": [entry]})

    def test_validate_rejects_unknown_phase(self) -> None:
        env = self._env("a", "f1", [], phase="DR-SYNTH")
        with self.assertRaisesRegex(ValueError, "forbidden or unknown phase_id: DR-SYNTH"):
            consolidate.validate_inputs([env], self.INDEX)

    def test_validate_rejects_unindexed_envelope(self) -> None:
        env = self._env("zzz", "f1", [])
        with self.assertRaisesRegex(ValueError, "envelope not referenced by result index"):
            consolidate.validate_inputs([env], self.INDEX)

    def test_validate_rejects_forbidden_fields_exact_and_prefixed(self) -> None:
        for field in ("report", "synthesis_notes", "worker_state", "vloop_x", "canonical_claim"):
            env = self._env("a", "f1", [])
            env[field] = 1
            with self.assertRaisesRegex(ValueError, f"forbidden input class present: {field}"):
                consolidate.validate_inputs([env], self.INDEX)

    def test_validate_accepts_clean_envelope(self) -> None:
        consolidate.validate_inputs([self._env("a", "f1", [])], self.INDEX)
        consolidate.validate_inputs([], {})

    def test_normalize_claim(self) -> None:
        self.assertEqual(consolidate.normalize_claim("  Foo \n BAR\tbaz "), "foo bar baz")

    def test_consolidate_labels(self) -> None:
        envs = [
            self._env("a", "f1", [{"text": "Alpha  works"}, {"claim": "Solo claim"}, {"text": ""}, {}]),
            self._env("b", "f2", [{"text": "alpha works"}]),
            self._env("c", "f2", [{"text": "ALPHA WORKS"}, {"text": "pair claim"}]),
            self._env("a", "f1", [{"text": "pair claim"}]),
            self._env("b", "f1", [{"text": "Weak"}]),
            self._env("a", "f2", [{"text": "weak"}]),
            self._env("c", "f2", [], phase="DR-RETRIEVE"),
        ]
        envs.append(self._env("a", "f3", [{"text": "nameless"}]))
        out = consolidate.consolidate(envs, self.INDEX, resolved_pool=5)
        self.assertEqual(out["schema_id"], "consolidation-output-v1")
        by_text = {r["claim_key"]: r for r in out["consensus"] + out["divergence"]}
        alpha = by_text["alpha works"]
        self.assertEqual((alpha["label"], alpha["support_count"]), ("consensus", 3))
        self.assertEqual(alpha["supporting_agents"], ["a", "b", "c"])
        self.assertEqual(alpha["model_families"], ["f1", "f2"])
        weak = by_text["weak"]
        self.assertEqual((weak["label"], weak["support_count"]), ("weak_consensus", 2))
        self.assertEqual(by_text["solo claim"]["label"], "divergent")
        # pool 5 -> strong threshold 3, so two agreeing agents are only weak consensus
        self.assertEqual(by_text["pair claim"]["label"], "weak_consensus")
        self.assertEqual(by_text["nameless"]["label"], "divergent")
        self.assertEqual(out["coverage"]["indexed"], 3)
        self.assertEqual(out["coverage"]["families_seen"], ["f1", "f2", "f3"])
        self.assertTrue(all(r["label"] == "divergent" for r in out["divergence"]))
        self.assertTrue(all(r["label"] != "divergent" for r in out["consensus"]))

    def test_consolidate_weak_consensus_with_large_pool(self) -> None:
        envs = [self._env("a", "f1", [{"text": "x"}]), self._env("b", "f2", [{"text": "x"}])]
        out = consolidate.consolidate(envs, self.INDEX, resolved_pool=9)
        self.assertEqual(out["consensus"][0]["label"], "weak_consensus")

    def test_consolidate_agent_missing_is_not_counted(self) -> None:
        env = self._env("a", "f1", [{"text": "x"}])
        index = {"entries": [{"work_item_id": "w1", "logical_model_id": "a"}]}
        env2 = dict(env)
        out = consolidate.consolidate([env, env2], index, 2)
        self.assertEqual(out["divergence"][0]["support_count"], 1)
        # an envelope with a falsy logical_model_id cannot pass validation (not in the index)
        bad = dict(env, logical_model_id="")
        with self.assertRaises(ValueError):
            consolidate.consolidate([bad], index, 2)

    def test_consolidate_requires_family(self) -> None:
        env = self._env("a", "", [{"text": "x"}])
        with self.assertRaisesRegex(ValueError, "model_family_id required"):
            consolidate.consolidate([env], self.INDEX, 3)

    def test_main_writes_output_with_content_hash(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            d = Path(tmp)
            (d / "env.json").write_text(
                json.dumps([self._env("a", "f1", [{"text": "x"}]), self._env("b", "f2", [{"text": "X"}])]),
                encoding="utf-8",
            )
            (d / "idx.json").write_text(json.dumps(self.INDEX), encoding="utf-8")
            argv = ["consolidate", "--envelopes", str(d / "env.json"), "--index", str(d / "idx.json"),
                    "--output", str(d / "out.json"), "--resolved-pool", "2"]
            with mock.patch.object(sys, "argv", argv):
                rc, stdout, _ = _run(consolidate.main)
            self.assertEqual(rc, 0)
            written = json.loads((d / "out.json").read_text(encoding="utf-8"))
            printed = json.loads(stdout)
            self.assertTrue(printed["ok"])
            self.assertEqual(printed["content_hash"], written["content_hash"])
            self.assertEqual(len(written["content_hash"]), 64)
            self.assertEqual(written["consensus"][0]["label"], "consensus")

    def test_main_rejects_non_array_envelopes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            d = Path(tmp)
            (d / "env.json").write_text("{}", encoding="utf-8")
            (d / "idx.json").write_text("{}", encoding="utf-8")
            argv = ["consolidate", "--envelopes", str(d / "env.json"), "--index", str(d / "idx.json"),
                    "--output", str(d / "out.json"), "--resolved-pool", "1"]
            with mock.patch.object(sys, "argv", argv):
                with self.assertRaises(SystemExit) as cm:
                    consolidate.main()
            self.assertEqual(str(cm.exception), "envelopes file must be a JSON array")
            self.assertFalse((d / "out.json").exists())

    def test_script_entrypoint_exits_with_main_status(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            d = Path(tmp)
            (d / "env.json").write_text("[]", encoding="utf-8")
            (d / "idx.json").write_text("{}", encoding="utf-8")
            argv = ["consolidate.py", "--envelopes", str(d / "env.json"), "--index", str(d / "idx.json"),
                    "--output", str(d / "out.json"), "--resolved-pool", "1"]
            with mock.patch.object(sys, "argv", argv):
                with self.assertRaises(SystemExit) as cm:
                    _run(runpy.run_path, str(SCRIPTS / "consolidate.py"), run_name="__main__")
            self.assertEqual(cm.exception.code, 0)
            self.assertTrue((d / "out.json").is_file())


class ReportWrapperTests(unittest.TestCase):
    def test_generate_report_entrypoint_forwards_general_profile(self) -> None:
        seen = {}

        def fake_main(argv):
            seen["argv"] = argv
            return 7

        with mock.patch.object(generate_spa_report, "main", fake_main):
            with mock.patch.object(sys, "argv", ["generate_report.py", "--dir", "/x"]):
                with self.assertRaises(SystemExit) as cm:
                    runpy.run_path(str(SCRIPTS / "generate_report.py"), run_name="__main__")
        self.assertEqual(cm.exception.code, 7)
        self.assertEqual(seen["argv"], ["--profile", "general", "--dir", "/x"])

    def test_generate_report_import_does_not_run(self) -> None:
        ns = runpy.run_path(str(SCRIPTS / "generate_report.py"), run_name="not_main")
        self.assertIn("main", ns)

    def _manifest(self, root: Path, payload) -> None:
        (root / "run_manifest.json").write_text(payload if isinstance(payload, str) else json.dumps(payload), encoding="utf-8")

    def test_landscape_wrapper_type_checks(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            # no manifest at all
            with self.assertRaisesRegex(ValueError, "got None"):
                generate_landscape_report._require_landscape_type(root)
            self._manifest(root, "{not json")
            with self.assertRaisesRegex(ValueError, "got None"):
                generate_landscape_report._require_landscape_type(root)
            self._manifest(root, ["list"])
            with self.assertRaisesRegex(ValueError, "got None"):
                generate_landscape_report._require_landscape_type(root)
            self._manifest(root, {"research_type": "default"})
            with self.assertRaisesRegex(ValueError, "got 'default'"):
                generate_landscape_report._require_landscape_type(root)
            for ok in ("solution-landscape", "solution-compare"):
                self._manifest(root, {"research_type": ok})
                generate_landscape_report._require_landscape_type(root)

    def test_landscape_wrapper_main_success_and_errors(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self._manifest(root, {"research_type": "solution-landscape"})
            rendered = {"status": "ok", "out": "x"}
            with mock.patch.object(generate_landscape_report, "render_landscape_outputs", return_value=rendered) as r:
                rc, stdout, _ = _run(generate_landscape_report.main, ["--dir", str(root), "--out", str(root / "o.html")])
            self.assertEqual(rc, 0)
            self.assertEqual(json.loads(stdout), rendered)
            r.assert_called_once_with(root, out=root / "o.html")
            with mock.patch.object(generate_landscape_report, "render_landscape_outputs", return_value=rendered) as r2:
                _run(generate_landscape_report.main, ["--dir", str(root)])
            r2.assert_called_once_with(root, out=None)
            # FileNotFoundError from the renderer maps to exit 1
            with mock.patch.object(generate_landscape_report, "render_landscape_outputs", side_effect=FileNotFoundError("gone")):
                rc, stdout, stderr = _run(generate_landscape_report.main, ["--dir", str(root)])
            self.assertEqual(rc, 1)
            self.assertEqual(stdout, "")
            self.assertEqual(json.loads(stderr), {"status": "error", "reason": "gone"})
            # wrong research type
            self._manifest(root, {"research_type": "default"})
            rc, _, stderr = _run(generate_landscape_report.main, ["--dir", str(root)])
            self.assertEqual(rc, 1)
            self.assertIn("landscape report only for solution types", json.loads(stderr)["reason"])

    def test_landscape_wrapper_entrypoint(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            with mock.patch.object(sys, "argv", ["generate_landscape_report.py", "--dir", tmp]):
                with self.assertRaises(SystemExit) as cm:
                    _run(runpy.run_path, str(SCRIPTS / "generate_landscape_report.py"), run_name="__main__")
        self.assertEqual(cm.exception.code, 1)


class GenerateSpaReportTests(unittest.TestCase):
    def test_load_helpers_ignore_non_dict_json(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.assertEqual(generate_spa_report.load_manifest(root), {})
            self.assertEqual(generate_spa_report.load_consolidation(root), {})
            (root / "run_manifest.json").write_text("[1]", encoding="utf-8")
            (root / "consolidated").mkdir()
            (root / "consolidated" / "consolidation.json").write_text("[2]", encoding="utf-8")
            self.assertEqual(generate_spa_report.load_manifest(root), {})
            self.assertEqual(generate_spa_report.load_consolidation(root), {})

    def test_collect_general_defaults_and_values(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            data = generate_spa_report.collect_general(root)
            self.assertEqual(data["title"], "Multi-AI Deep Research")
            self.assertEqual(data["research_type"], "default")
            self.assertEqual(data["comparison"], {"consensus_count": 0})
            (root / "run_manifest.json").write_text(json.dumps({"query": "Q?", "research_type": "solution-compare"}), encoding="utf-8")
            (root / "consolidated").mkdir()
            (root / "consolidated" / "consolidation.json").write_text(json.dumps({"consensus": [{"text": "t"}]}), encoding="utf-8")
            data = generate_spa_report.collect_general(root)
            self.assertEqual(data["title"], "Q?")
            self.assertEqual(data["need_profile"], {"category": "solution-compare"})
            self.assertEqual(data["comparison"], {"consensus_count": 1})

    def test_render_general_escapes_title_and_embeds_payload(self) -> None:
        html_text = generate_spa_report.render_general({"title": "<b>x</b> & y", "research_type": "default"})
        self.assertIn("<title>&lt;b&gt;x&lt;/b&gt; &amp; y</title>", html_text)
        self.assertIn('id="report-data"', html_text)
        self.assertIn('data-tab-marker="matrix"', html_text)
        self.assertNotIn("<b>x</b>", html_text)

    def test_require_landscape_type(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            with self.assertRaisesRegex(ValueError, "got None"):
                generate_spa_report._require_landscape_type(root)
            (root / "run_manifest.json").write_text(json.dumps({"research_type": "solution-landscape"}), encoding="utf-8")
            generate_spa_report._require_landscape_type(root)

    def test_generate_file_general_default_and_custom_out(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            result = generate_spa_report.generate_spa_report_file(root, "general")
            self.assertEqual(result, {"status": "ok", "out": str(root / "report.html"), "profile": "general"})
            self.assertIn("Multi-AI Deep Research", (root / "report.html").read_text(encoding="utf-8"))
            custom = root / "nested.html"
            result = generate_spa_report.generate_spa_report_file(root, "general", out=custom)
            self.assertEqual(result["out"], str(custom))
            self.assertTrue(custom.is_file())

    def test_generate_file_rejects_unknown_profile(self) -> None:
        with self.assertRaisesRegex(ValueError, "unknown profile: 'bogus'"):
            generate_spa_report.generate_spa_report_file(Path("/nowhere"), "bogus")

    def test_generate_file_landscape_validates_then_renders(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            with self.assertRaisesRegex(ValueError, "landscape report only for solution types"):
                generate_spa_report.generate_spa_report_file(root, "landscape")
            (root / "run_manifest.json").write_text(json.dumps({"research_type": "solution-compare"}), encoding="utf-8")
            fake = types.ModuleType("landscape_preview_render")
            calls = []
            fake.render_landscape_outputs = lambda r, out=None: calls.append((r, out)) or {"status": "ok"}
            with mock.patch.dict(sys.modules, {"landscape_preview_render": fake}):
                result = generate_spa_report.generate_spa_report_file(root, "landscape")
            self.assertEqual(result, {"status": "ok"})
            self.assertEqual(calls, [(root, root / "landscape-report.html")])

    def test_generate_file_profile_without_render_and_with_markers(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            broken = {"default_out": "b.html", "collect": None, "render": None, "validate_root": None}
            with mock.patch.dict(generate_spa_report.PROFILES, {"broken": broken}):
                with self.assertRaisesRegex(ValueError, "profile 'broken' has no render function"):
                    generate_spa_report.generate_spa_report_file(root, "broken")
            marked = {
                "default_out": "m.html",
                "collect": lambda r: {"title": "T"},
                "render": lambda d: "<html>" + d["title"] + "</html>",
                "validate_root": None,
                "markers": ["m1"],
            }
            with mock.patch.dict(generate_spa_report.PROFILES, {"marked": marked}):
                result = generate_spa_report.generate_spa_report_file(root, "marked")
            self.assertEqual(result["markers"], ["m1"])
            self.assertEqual((root / "m.html").read_text(encoding="utf-8"), "<html>T</html>")

    def test_main_success_error_and_entrypoint(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            rc, stdout, _ = _run(generate_spa_report.main, ["--dir", str(root), "--out", str(root / "x.html")])
            self.assertEqual(rc, 0)
            self.assertEqual(json.loads(stdout)["out"], str(root / "x.html"))
            rc, stdout, stderr = _run(generate_spa_report.main, ["--dir", str(root), "--profile", "landscape"])
            self.assertEqual(rc, 1)
            self.assertEqual(stdout, "")
            self.assertEqual(json.loads(stderr)["status"], "error")
            with mock.patch.object(sys, "argv", ["generate_spa_report.py", "--dir", str(root)]):
                with self.assertRaises(SystemExit) as cm:
                    _run(runpy.run_path, str(SCRIPTS / "generate_spa_report.py"), run_name="__main__")
            self.assertEqual(cm.exception.code, 0)
            self.assertTrue((root / "report.html").is_file())


class PackageSolutionOutputsTests(unittest.TestCase):
    """package_solution_outputs with every heavy collaborator faked."""

    def _fakes(self, calls: list, *, gate_status: str = "pass", xlsx_exists: bool = False, tmp: Path | None = None):
        def mod(name: str, **attrs):
            m = types.ModuleType(name)
            for k, v in attrs.items():
                setattr(m, k, v)
            return m

        def rec(name, ret):
            def f(*a, **kw):
                calls.append((name, a, kw))
                return ret
            return f

        gate = {"status": gate_status, "errors": ["bad thing", "worse thing"] if gate_status != "pass" else []}
        xlsx = (tmp / "comparison" / "comparison-matrix.xlsx") if tmp else Path("/does/not/exist.xlsx")
        if xlsx_exists and tmp:
            xlsx.parent.mkdir(parents=True, exist_ok=True)
            xlsx.write_text("x", encoding="utf-8")
        return {
            "materialize_solution_artifacts": mod("materialize_solution_artifacts", materialize_solution_artifacts=rec("materialize", {"m": 1})),
            "compare_solutions": mod("compare_solutions", compare_solutions=rec("compare", {"c": 1})),
            "generate_comparison_xlsx": mod("generate_comparison_xlsx", generate_comparison_xlsx=rec("xlsx", {"x": 1})),
            "generate_spa_report": mod("generate_spa_report", generate_spa_report_file=rec("spa", {"s": 1})),
            "synthesize_landscape": mod("synthesize_landscape", synthesize_landscape=rec("synth", {"l": 1})),
            "landscape_preview_render": mod("landscape_preview_render", render_landscape_outputs=rec("render", {"r": 1})),
            "validate_landscape_content": mod("validate_landscape_content", validate_landscape_content=rec("gate", gate)),
            "matrix_core": mod("matrix_core", comparison_matrix_xlsx_path=lambda root: xlsx),
        }

    def _run(self, root: Path, calls: list, **kw):
        gate_status = kw.pop("gate_status", "pass")
        xlsx_exists = kw.pop("xlsx_exists", False)
        fakes = self._fakes(calls, gate_status=gate_status, xlsx_exists=xlsx_exists, tmp=root)
        saved = list(sys.path)
        try:
            with mock.patch.dict(sys.modules, fakes):
                with mock.patch.object(package_solution_outputs, "ensure_scripts_on_path"):
                    with mock.patch.object(package_solution_outputs, "ensure_multi_ai_scripts_on_path"):
                        return package_solution_outputs.package_solution_outputs(root, **kw)
        finally:
            sys.path[:] = saved

    def _manifest(self, root: Path, research_type: str | None) -> None:
        payload = {} if research_type is None else {"research_type": research_type}
        (root / "run_manifest.json").write_text(json.dumps(payload), encoding="utf-8")

    def test_spa_without_manifest_is_an_error(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaisesRegex(FileNotFoundError, "run_manifest.json required for SPA packaging"):
                self._run(Path(tmp), [])

    def test_no_manifest_with_skip_spa_runs_compare_only(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            calls: list = []
            result = self._run(Path(tmp), calls, skip_spa=True)
            self.assertEqual([c[0] for c in calls], ["compare"])
            self.assertEqual(calls[0][2], {"emit_xlsx": True})
            self.assertEqual(result["status"], "ok")
            self.assertEqual(result["compare"], {"c": 1})
            self.assertNotIn("materialize", result)
            self.assertNotIn("comparison_matrix_xlsx", result)

    def test_skip_compare_generates_xlsx_unless_skipped(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            calls: list = []
            result = self._run(root, calls, skip_compare=True, skip_spa=True)
            self.assertEqual([c[0] for c in calls], ["xlsx"])
            self.assertEqual(result["xlsx"], {"x": 1})
            calls.clear()
            result = self._run(root, calls, skip_compare=True, skip_xlsx=True, skip_spa=True)
            self.assertEqual(calls, [])
            self.assertNotIn("xlsx", result)
            self.assertNotIn("compare", result)

    def test_compare_xlsx_flag_inverts_skip_xlsx(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            calls: list = []
            self._run(Path(tmp), calls, skip_xlsx=True, skip_spa=True)
            self.assertEqual(calls[0][2], {"emit_xlsx": False})

    def test_non_landscape_manifest_runs_general_report_only(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self._manifest(root, "default")
            calls: list = []
            result = self._run(root, calls)
            self.assertEqual([c[0] for c in calls], ["compare", "spa"])
            self.assertEqual(calls[1][1], (root, "general"))
            self.assertEqual(result["report_general"], {"s": 1})
            self.assertNotIn("landscape_synthesis", result)

    def test_landscape_full_pipeline_and_xlsx_path(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self._manifest(root, "solution-landscape")
            calls: list = []
            result = self._run(root, calls, xlsx_exists=True)
            self.assertEqual([c[0] for c in calls], ["materialize", "compare", "spa", "synth", "render", "gate"])
            self.assertEqual(calls[3][2], {"force": True})
            self.assertEqual(result["landscape_content_gate"]["status"], "pass")
            self.assertEqual(result["comparison_matrix_xlsx"], str(root / "comparison" / "comparison-matrix.xlsx"))

    def test_landscape_content_gate_failure_raises_with_errors(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self._manifest(root, "solution-compare")
            with self.assertRaisesRegex(ValueError, "landscape content quality gate failed: bad thing; worse thing"):
                self._run(root, [], gate_status="fail")

    def test_landscape_marker_in_generated_files_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self._manifest(root, "solution-landscape")
            (root / "landscape").mkdir()
            (root / "landscape" / "landscape-report.md").write_text("ok\n[Archived]\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, r"landscape/landscape-report\.md"):
                self._run(root, [])
            (root / "landscape" / "landscape-report.md").write_text("clean\n", encoding="utf-8")
            (root / "landscape-report.html").write_text("<p>omitted 4 lines</p>", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, r"landscape-report\.html"):
                self._run(root, [])

    def test_main_ok_and_error(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            with mock.patch.object(package_solution_outputs, "package_solution_outputs", return_value={"status": "ok"}) as p:
                rc, stdout, _ = _run(package_solution_outputs.main, ["--dir", tmp, "--skip-compare", "--skip-xlsx", "--skip-spa"])
            self.assertEqual(rc, 0)
            self.assertEqual(json.loads(stdout), {"status": "ok"})
            p.assert_called_once_with(Path(tmp), skip_compare=True, skip_xlsx=True, skip_spa=True)
            with mock.patch.object(package_solution_outputs, "package_solution_outputs", side_effect=RuntimeError("boom")):
                rc, stdout, stderr = _run(package_solution_outputs.main, ["--dir", tmp])
            self.assertEqual(rc, 1)
            self.assertEqual(stdout, "")
            self.assertEqual(json.loads(stderr), {"status": "error", "reason": "boom"})

    def test_script_entrypoint(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            with mock.patch.object(sys, "argv", ["package_solution_outputs.py", "--dir", tmp]):
                with self.assertRaises(SystemExit) as cm:
                    _run(runpy.run_path, str(SCRIPTS / "package_solution_outputs.py"), run_name="__main__")
            # no run_manifest.json -> FileNotFoundError mapped to exit 1
            self.assertEqual(cm.exception.code, 1)


class MigrateRunManifestTests(unittest.TestCase):
    def test_classify_v3(self) -> None:
        self.assertEqual(
            migrate_run_manifest.classify_v3({"version": "3.0.0", "schema_id": "deep-research-run-manifest-strict-v3"}),
            "run-manifest-strict-v3.schema.json",
        )
        self.assertEqual(
            migrate_run_manifest.classify_v3({"version": "3.0.0", "schema_id": "deep-research-run-manifest-host-v3"}),
            "run-manifest-host-v3.schema.json",
        )
        with self.assertRaisesRegex(ValueError, "unsupported manifest version: '2.0.0'"):
            migrate_run_manifest.classify_v3({"version": "2.0.0"})
        with self.assertRaisesRegex(ValueError, "unknown v3 schema_id: 'other'"):
            migrate_run_manifest.classify_v3({"version": "3.0.0", "schema_id": "other"})
        with self.assertRaisesRegex(ValueError, "unknown v3 schema_id: ''"):
            migrate_run_manifest.classify_v3({"version": "3.0.0"})

    def test_deterministic_ids_are_stable_and_distinct(self) -> None:
        a = migrate_run_manifest.deterministic_run_id("d", "s")
        self.assertEqual(a, migrate_run_manifest.deterministic_run_id("d", "s"))
        self.assertNotEqual(a, migrate_run_manifest.deterministic_run_id("d2", "s"))
        self.assertRegex(a, r"^run-[0-9a-f]{32}$")
        w = migrate_run_manifest.deterministic_work_item_id("r", "p", "h")
        self.assertRegex(w, r"^work-[0-9a-f]{32}$")
        self.assertNotEqual(w, migrate_run_manifest.deterministic_work_item_id("r", "p2", "h"))

    def test_audit_record_hash_covers_body(self) -> None:
        rec = migrate_run_manifest.build_audit_record(
            source_dialect="d", source_sha256="a", source_path="sp", target_sha256="b", target_path="tp", prior_head=None
        )
        self.assertIsNone(rec["prior_audit_head"])
        body = {k: v for k, v in rec.items() if k != "record_hash"}
        expected = migrate_run_manifest.sha256_bytes(migrate_run_manifest.canonical_json_bytes(body))
        self.assertEqual(rec["record_hash"], expected)
        rec2 = migrate_run_manifest.build_audit_record(
            source_dialect="d", source_sha256="a", source_path="sp", target_sha256="b", target_path="tp", prior_head="h"
        )
        self.assertNotEqual(rec["record_hash"], rec2["record_hash"])

    def test_migrate_full_mapping(self) -> None:
        source = {
            "schema_id": "deep-research-run-manifest-host-v3",
            "version": "3.0.0",
            "run_id": "run-fixed",
            "question": "why?",
            "mode": "quick",
            "research_type": "solution-landscape",
            "started_at": "2025-05-05T00:00:00Z",
            "finished_at": "2025-05-06T00:00:00Z",
            "budget": {"currency_micro_usd_cap": 5, "price_known": False, "budget_stop_reason": "cap"},
            "artifact_paths": {"report": "r.md"},
            "phases": [
                {"phase_id": "P1", "work_item_id": "w-given", "parallel": False},
                {"id": "P2"},
                {"name": "no id at all"},
            ],
        }
        out = migrate_run_manifest.migrate_v3_to_v4(source, research_root=Path("/root"), source_sha256="s" * 64)
        self.assertEqual(out["run_id"], "run-fixed")
        self.assertEqual(out["query"], "why?")
        self.assertEqual(out["mode"], "quick")
        self.assertEqual(out["finished_at"], "2025-05-06T00:00:00Z")
        self.assertEqual(out["artifact_paths"], {"report": "r.md"})
        self.assertEqual(out["report_dir"], "/root")
        budget = out["multi_ai"]["budget"]
        self.assertEqual(budget["currency_micro_usd_cap"], 5)
        self.assertEqual(budget["total_tokens_cap"], 2_000_000)
        self.assertFalse(budget["price_known"])
        self.assertEqual(budget["budget_stop_reason"], "cap")
        phases = out["multi_ai"]["phases"]
        self.assertEqual([p["phase_id"] for p in phases], ["P1", "P2"])
        self.assertEqual(phases[0], {"phase_id": "P1", "work_item_id": "w-given", "parallel": False})
        self.assertTrue(phases[1]["parallel"])
        self.assertRegex(phases[1]["work_item_id"], r"^work-")
        self.assertEqual(len(out["multi_ai"]["work_item_refs"]), 2)
        self.assertEqual(out["multi_ai"]["work_item_refs"][0]["manifest_path"], "work-items/w-given/multi-ai-work-item-manifest-v1.json")

    def test_migrate_defaults(self) -> None:
        source = {"schema_id": "deep-research-run-manifest-strict-v3", "version": "3.0.0"}
        out = migrate_run_manifest.migrate_v3_to_v4(source, research_root=Path("/r"), source_sha256="a" * 64)
        self.assertRegex(out["run_id"], r"^run-[0-9a-f]{32}$")
        self.assertEqual(out["query"], "")
        self.assertEqual(out["mode"], "deep")
        self.assertEqual(out["research_type"], "default")
        self.assertEqual(out["multi_ai"]["phases"], [])
        self.assertIn("report_html", out["artifact_paths"])
        self.assertEqual(out["migration"]["source_dialect"], "run-manifest-strict-v3.schema.json")

    def test_atomic_write_replaces_file_and_leaves_no_temp(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "m.json"
            p.write_text("old", encoding="utf-8")
            migrate_run_manifest.atomic_write(p, "new")
            self.assertEqual(p.read_text(encoding="utf-8"), "new")
            self.assertEqual([x.name for x in Path(tmp).iterdir()], ["m.json"])

    def _v3(self, d: Path) -> Path:
        src = d / "v3.json"
        src.write_text(
            json.dumps({"schema_id": "deep-research-run-manifest-strict-v3", "version": "3.0.0", "query": "q"}),
            encoding="utf-8",
        )
        return src

    def test_main_migrates_chains_audit_and_guards_existing_target(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            d = Path(tmp)
            src = self._v3(d)
            root = d / "root"
            rc, stdout, _ = _run(migrate_run_manifest.main, ["--input", str(src), "--research-root", str(root)])
            self.assertEqual(rc, 0)
            printed = json.loads(stdout)
            manifest = json.loads((root / "run_manifest.json").read_text(encoding="utf-8"))
            self.assertEqual(manifest["schema_id"], "deep-research-run-manifest-v4")
            self.assertEqual(printed["run_id"], manifest["run_id"])
            archive = root / "migration" / "sources" / f"{printed['source_sha256']}.json"
            self.assertEqual(archive.read_bytes(), src.read_bytes())
            audit = root / "migration" / "run-manifest-migration-audit-v1.jsonl"
            first = json.loads(audit.read_text(encoding="utf-8").splitlines()[0])
            self.assertIsNone(first["prior_audit_head"])
            self.assertEqual(first["record_hash"], printed["audit_record_hash"])

            # an existing v4 manifest blocks a second migration without --force
            with self.assertRaises(SystemExit) as cm:
                _run(migrate_run_manifest.main, ["--input", str(src), "--research-root", str(root)])
            self.assertIn("refusing to overwrite existing v4 manifest", str(cm.exception))
            self.assertEqual(len(audit.read_text(encoding="utf-8").splitlines()), 1)

            # --force replaces it, chaining the audit record to the previous head
            custom_audit = root / "audit" / "custom.jsonl"
            custom_audit.parent.mkdir()
            custom_audit.write_text(json.dumps({"record_hash": "HEAD1"}) + "\n\n", encoding="utf-8")
            rc, stdout, _ = _run(
                migrate_run_manifest.main,
                ["--input", str(src), "--research-root", str(root), "--force", "--audit-out", str(custom_audit)],
            )
            self.assertEqual(rc, 0)
            lines = custom_audit.read_text(encoding="utf-8").splitlines()
            self.assertEqual(json.loads(lines[-1])["prior_audit_head"], "HEAD1")

            # an empty audit log yields no prior head
            custom_audit.write_text("\n", encoding="utf-8")
            _run(migrate_run_manifest.main, ["--input", str(src), "--research-root", str(root), "--force", "--audit-out", str(custom_audit)])
            self.assertIsNone(json.loads(custom_audit.read_text(encoding="utf-8").splitlines()[-1])["prior_audit_head"])

    def test_main_refuses_unreadable_existing_target_but_overwrites_non_v4(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            d = Path(tmp)
            src = self._v3(d)
            root = d / "root"
            root.mkdir()
            (root / "run_manifest.json").write_text("{broken", encoding="utf-8")
            with self.assertRaises(SystemExit) as cm:
                _run(migrate_run_manifest.main, ["--input", str(src), "--research-root", str(root)])
            self.assertIn("refusing to overwrite unreadable", str(cm.exception))
            self.assertEqual((root / "run_manifest.json").read_text(encoding="utf-8"), "{broken")
            (root / "run_manifest.json").write_text(json.dumps({"schema_id": "old"}), encoding="utf-8")
            rc, _, _ = _run(migrate_run_manifest.main, ["--input", str(src), "--research-root", str(root)])
            self.assertEqual(rc, 0)
            self.assertEqual(json.loads((root / "run_manifest.json").read_text(encoding="utf-8"))["version"], "4.0.0")

    def test_main_keeps_existing_source_archive(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            d = Path(tmp)
            src = self._v3(d)
            root = d / "root"
            _run(migrate_run_manifest.main, ["--input", str(src), "--research-root", str(root)])
            archive = next((root / "migration" / "sources").iterdir())
            archive.write_text("tampered", encoding="utf-8")
            _run(migrate_run_manifest.main, ["--input", str(src), "--research-root", str(root), "--force"])
            self.assertEqual(archive.read_text(encoding="utf-8"), "tampered")

    def test_script_entrypoint(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            d = Path(tmp)
            src = self._v3(d)
            argv = ["migrate_run_manifest.py", "--input", str(src), "--research-root", str(d / "r")]
            with mock.patch.object(sys, "argv", argv):
                with self.assertRaises(SystemExit) as cm:
                    _run(runpy.run_path, str(SCRIPTS / "migrate_run_manifest.py"), run_name="__main__")
            self.assertEqual(cm.exception.code, 0)


class DrMultiAiCliTests(unittest.TestCase):
    def setUp(self) -> None:
        patcher = mock.patch.dict(os.environ, {}, clear=False)
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_parse_args_defaults(self) -> None:
        args = dr_multi_ai_cli.parse_args([])
        self.assertEqual((args.query, args.mode, args.research_type), ("", "deep", "default"))
        self.assertEqual((args.ocg_pool, args.cursor_pool, args.timeout_sec), ("lite", "default", 600))
        self.assertEqual(args.include_only, [])

    def test_bootstrap_runs_once(self) -> None:
        with mock.patch.object(dr_multi_ai_cli, "_BOOTSTRAPPED", False):
            saved = list(sys.path)
            try:
                with mock.patch("skill_paths.ensure_scripts_on_path") as e1, mock.patch("skill_paths.ensure_dir_on_path") as e2:
                    dr_multi_ai_cli._bootstrap()
                    dr_multi_ai_cli._bootstrap()
                e1.assert_called_once_with("silver-multi-ai-task", marker="multi_ai_core.py")
                e2.assert_called_once_with(dr_multi_ai_cli.DRM_SCRIPTS)
                self.assertTrue(dr_multi_ai_cli._BOOTSTRAPPED)
            finally:
                sys.path[:] = saved
                dr_multi_ai_cli._BOOTSTRAPPED = False

    def test_needs_solution_packaging_and_parallel_phases(self) -> None:
        self.assertTrue(dr_multi_ai_cli.needs_solution_packaging("solution-landscape"))
        self.assertTrue(dr_multi_ai_cli.needs_solution_packaging("solution-compare"))
        self.assertFalse(dr_multi_ai_cli.needs_solution_packaging("default"))
        self.assertEqual(dr_multi_ai_cli.load_parallel_phases("default", "quick"), [])
        self.assertEqual(dr_multi_ai_cli.load_parallel_phases("default", "standard"), ["DR-RETRIEVE"])
        self.assertEqual(
            dr_multi_ai_cli.load_parallel_phases("solution-landscape", "deep"), ["DR-RETRIEVE", "DR-TRIANGULATE"]
        )
        self.assertEqual(dr_multi_ai_cli.load_parallel_phases("solution-compare", "standard"), [])
        self.assertEqual(dr_multi_ai_cli.load_parallel_phases("unknown-type", "standard"), ["DR-RETRIEVE"])

    def test_default_output_root_slug(self) -> None:
        root = dr_multi_ai_cli.default_output_root("  Hello World " + "x" * 200)
        self.assertEqual(root.parent, dr_multi_ai_cli.REPO_ROOT / "research")
        self.assertRegex(root.name, r"^\d{4}-\d{2}-\d{2}-hello-world-x+$")
        self.assertEqual(len(root.name) - len("2000-01-01-"), 80)

    def test_package_only_validation_errors(self) -> None:
        rc, stdout, _ = _run(dr_multi_ai_cli.main, ["--package-only", "--output-root", "/x"])
        self.assertEqual(rc, 2)
        self.assertEqual(json.loads(stdout)["error_code"], "SOLUTION_PACKAGING_TYPE_MISMATCH")
        rc, stdout, _ = _run(dr_multi_ai_cli.main, ["--package-only", "--research-type", "solution-compare"])
        self.assertEqual(rc, 2)
        self.assertEqual(json.loads(stdout)["error_code"], "OUTPUT_ROOT_REQUIRED")

    def test_package_only_success_and_failure(self) -> None:
        fake = types.ModuleType("package_solution_outputs")
        seen = {}

        def ok(root, **kw):
            seen.update(root=root, **kw)
            return {"status": "ok"}

        fake.package_solution_outputs = ok
        argv = ["--package-only", "--research-type", "solution-landscape", "--output-root", "/o",
                "--skip-compare", "--skip-xlsx", "--skip-spa"]
        with mock.patch.object(dr_multi_ai_cli, "_bootstrap"), mock.patch.dict(sys.modules, {"package_solution_outputs": fake}):
            rc, stdout, _ = _run(dr_multi_ai_cli.main, argv)
        self.assertEqual(rc, 0)
        self.assertEqual(json.loads(stdout), {"ok": True, "status": "ok"})
        self.assertEqual(seen, {"root": Path("/o"), "skip_compare": True, "skip_xlsx": True, "skip_spa": True})

        def boom(root, **kw):
            raise RuntimeError("pkg exploded")

        fake.package_solution_outputs = boom
        with mock.patch.object(dr_multi_ai_cli, "_bootstrap"), mock.patch.dict(sys.modules, {"package_solution_outputs": fake}):
            rc, stdout, _ = _run(dr_multi_ai_cli.main, argv)
        self.assertEqual(rc, 1)
        payload = json.loads(stdout)
        self.assertEqual((payload["ok"], payload["error_code"], payload["message"]), (False, "SOLUTION_PACKAGING_FAILED", "pkg exploded"))

    def test_query_required(self) -> None:
        rc, stdout, _ = _run(dr_multi_ai_cli.main, [])
        self.assertEqual(rc, 2)
        self.assertEqual(json.loads(stdout)["error_code"], "QUERY_REQUIRED")

    def test_include_only_warning_only_for_full_solution_runs(self) -> None:
        with warnings.catch_warnings(record=True) as caught:
            warnings.simplefilter("always")
            _run(dr_multi_ai_cli.main, ["q", "--dry-run", "--research-type", "solution-landscape", "--include-only", "ocg-minimax-m3"])
        self.assertTrue(any("--include-only replaces the full pool" in str(w.message) for w in caught))
        with warnings.catch_warnings(record=True) as caught2:
            warnings.simplefilter("always")
            _run(dr_multi_ai_cli.main, ["q", "--dry-run", "--research-type", "solution-landscape", "--include-only", "ocg-minimax-m3", "--max-phases", "1"])
            _run(dr_multi_ai_cli.main, ["q", "--dry-run", "--include-only", "ocg-minimax-m3"])
        self.assertFalse([w for w in caught2 if "--include-only" in str(w.message)])

    def test_dry_run_reports(self) -> None:
        rc, stdout, _ = _run(dr_multi_ai_cli.main, ["q", "--dry-run"])
        report = json.loads(stdout)
        self.assertEqual(rc, 0)
        self.assertEqual(report["parallel_phases"], ["DR-RETRIEVE", "DR-TRIANGULATE", "DR-CRITIQUE"])
        self.assertEqual((report["research_type"], report["mode"]), ("default", "deep"))
        self.assertNotIn("solution_packaging", report)
        # quick mode legitimately has no parallel phases
        rc, stdout, _ = _run(dr_multi_ai_cli.main, ["q", "--dry-run", "--mode", "quick"])
        self.assertEqual(rc, 0)
        self.assertEqual(json.loads(stdout)["parallel_phases"], [])
        # landscape adds packaging hints
        rc, stdout, _ = _run(dr_multi_ai_cli.main, ["q", "--dry-run", "--research-type", "solution-landscape"])
        self.assertEqual(rc, 0)
        self.assertEqual(json.loads(stdout)["solution_packaging"]["script"], "package_solution_outputs.py")
        # a solution type with no phases for the mode is an error
        rc, stdout, _ = _run(dr_multi_ai_cli.main, ["q", "--dry-run", "--research-type", "solution-compare", "--mode", "standard"])
        report = json.loads(stdout)
        self.assertEqual(rc, 1)
        self.assertEqual(report["error_code"], "EMPTY_PARALLEL_PHASES")
        self.assertIn("solution-compare", report["message"])

    def test_dry_run_failing_report_returns_one(self) -> None:
        import multi_ai_core

        with mock.patch.object(multi_ai_core, "dry_run_report", return_value={"ok": False}):
            rc, stdout, _ = _run(dr_multi_ai_cli.main, ["q", "--dry-run"])
        self.assertEqual(rc, 1)
        self.assertFalse(json.loads(stdout)["ok"])

    def test_live_host_gate_failure(self) -> None:
        import multi_ai_core

        gate = {"ok": False, "error_code": "HOST_NOPE", "message": "no host"}
        with mock.patch.object(multi_ai_core, "host_gate", return_value=gate):
            rc, stdout, _ = _run(dr_multi_ai_cli.main, ["q"])
        self.assertEqual(rc, 2)
        self.assertEqual(json.loads(stdout), {"ok": False, "error_code": "HOST_NOPE", "message": "no host"})
        gate2 = {"ok": False, "error_code": "HOST_NOPE"}
        with mock.patch.object(multi_ai_core, "host_gate", return_value=gate2):
            _, stdout, _ = _run(dr_multi_ai_cli.main, ["q"])
        self.assertEqual(json.loads(stdout)["message"], "")

    def _live(self, argv, *, run_result=None, run_exc=None, pkg_result=None, pkg_exc=None, existing_root=None):
        import multi_ai_core

        runner = types.ModuleType("dr_live_runner")
        calls = {}

        def run_dr_live(**kw):
            calls["live"] = kw
            if run_exc:
                raise run_exc
            return dict(run_result)

        runner.run_dr_live = run_dr_live
        pkg = types.ModuleType("package_solution_outputs")

        def package(root):
            calls["pkg"] = root
            if pkg_exc:
                raise pkg_exc
            return pkg_result

        pkg.package_solution_outputs = package
        with mock.patch.object(multi_ai_core, "host_gate", return_value={"ok": True, "host": "cursor"}), \
                mock.patch.dict(sys.modules, {"dr_live_runner": runner, "package_solution_outputs": pkg}):
            rc, stdout, _ = _run(dr_multi_ai_cli.main, argv)
        return rc, json.loads(stdout), calls

    def test_live_success_default_type_no_packaging(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            os.environ.pop("SB_HOST", None)
            rc, out, calls = self._live(["q", "--output-root", tmp, "--max-phases", "2", "--timeout-sec", "9"], run_result={"ok": True})
            self.assertEqual(rc, 0)
            self.assertEqual(out, {"ok": True})
            live = calls["live"]
            self.assertEqual((live["query"], live["output_root"], live["max_phases"], live["timeout_sec"]), ("q", Path(tmp), 2, 9))
            self.assertEqual(live["parallel_phases"], ["DR-RETRIEVE", "DR-TRIANGULATE", "DR-CRITIQUE"])
            self.assertNotIn("pkg", calls)
            self.assertEqual(os.environ.get("SB_HOST"), "cursor")

    def test_live_force_clears_output_root_and_keeps_existing_host(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "out"
            root.mkdir()
            (root / "stale.txt").write_text("x", encoding="utf-8")
            os.environ["SB_HOST"] = "codex"
            seen = {}

            def fake_run(**kw):
                seen["exists"] = kw["output_root"].exists()
                return {"ok": True}

            runner = types.ModuleType("dr_live_runner")
            runner.run_dr_live = fake_run
            import multi_ai_core

            with mock.patch.object(multi_ai_core, "host_gate", return_value={"ok": True}), \
                    mock.patch.dict(sys.modules, {"dr_live_runner": runner}):
                rc, _, _ = _run(dr_multi_ai_cli.main, ["q", "--output-root", str(root), "--force"])
            self.assertEqual(rc, 0)
            self.assertFalse(seen["exists"])
            self.assertEqual(os.environ["SB_HOST"], "codex")

    def test_live_default_output_root_used_without_flag(self) -> None:
        rc, out, calls = self._live(["My Query"], run_result={"ok": True})
        self.assertEqual(rc, 0)
        self.assertEqual(calls["live"]["output_root"].parent, dr_multi_ai_cli.REPO_ROOT / "research")

    def test_live_runner_exception_and_not_ok_result(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            rc, out, _ = self._live(["q", "--output-root", tmp], run_exc=RuntimeError("live died"))
            self.assertEqual(rc, 1)
            self.assertEqual((out["error_code"], out["message"]), ("DR_LIVE_RUN_FAILED", "live died"))
            rc, out, _ = self._live(["q", "--output-root", tmp], run_result={"ok": False, "why": "x"})
            self.assertEqual(rc, 1)
            self.assertEqual(out["why"], "x")

    def test_live_solution_packaging_success_error_and_skipped_on_failed_run(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            argv = ["q", "--output-root", tmp, "--research-type", "solution-landscape"]
            rc, out, calls = self._live(argv, run_result={"ok": True}, pkg_result={"status": "ok"})
            self.assertEqual(rc, 0)
            self.assertEqual(out["packaging"], {"status": "ok"})
            self.assertEqual(calls["pkg"], Path(tmp))
            rc, out, _ = self._live(argv, run_result={"ok": True}, pkg_exc=ValueError("pack fail"))
            self.assertEqual(rc, 0)
            self.assertEqual(out["packaging_error"], "pack fail")
            self.assertNotIn("packaging", out)
            rc, out, calls = self._live(argv, run_result={"ok": False}, pkg_result={"status": "ok"})
            self.assertEqual(rc, 1)
            self.assertNotIn("pkg", calls)

    def test_script_entrypoint(self) -> None:
        with mock.patch.object(sys, "argv", ["dr_multi_ai_cli.py"]):
            with self.assertRaises(SystemExit) as cm:
                _run(runpy.run_path, str(SCRIPTS / "dr_multi_ai_cli.py"), run_name="__main__")
        self.assertEqual(cm.exception.code, 2)


if __name__ == "__main__":
    unittest.main()
