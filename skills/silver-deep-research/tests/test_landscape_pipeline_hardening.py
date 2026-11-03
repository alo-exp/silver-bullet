"""Group 4 hardening: phase gate, comparison, shortlist, SPA, XLSX, scoring, portals."""

import json
import sys
import tempfile
import unittest
import unittest.mock
from pathlib import Path

import covhelp  # noqa: F401  (puts scripts/ on sys.path)
from covhelp import SKILL_ROOT

import phase_gate as pg


def _tree(testcase):
    td = tempfile.TemporaryDirectory(prefix="2026-11-01-landscape-demo-")
    testcase.addCleanup(td.cleanup)
    return Path(td.name)


class PhaseGateSolutionTests(unittest.TestCase):
    def test_slug_artifact_resolves_to_generated_xlsx(self):
        root = _tree(self)
        (root / "comparison").mkdir()
        name = f"{root.name}-comparison-matrix.xlsx"
        (root / "comparison" / name).write_bytes(b"PK\x03\x04data")
        ok, detail = pg.artifact_satisfied(root, "comparison/{dir-slug}-comparison-matrix.xlsx")
        self.assertTrue(ok, detail)

    def test_slug_artifact_accepts_legacy_name_and_reports_missing(self):
        root = _tree(self)
        ok, detail = pg.artifact_satisfied(root, "comparison/{dir-slug}-comparison-matrix.xlsx")
        self.assertFalse(ok)
        self.assertIn("comparison-matrix.xlsx", detail)
        (root / "comparison").mkdir()
        (root / "comparison" / "comparison-matrix.xlsx").write_bytes(b"PK\x03\x04data")
        ok, _ = pg.artifact_satisfied(root, "comparison/{dir-slug}-comparison-matrix.xlsx")
        self.assertTrue(ok)

    def test_package_phase_does_not_require_ungenerated_landscape_html(self):
        cfg = pg.load_phases_config()
        for rt in ("solution-landscape", "solution-compare"):
            arts = pg.phase_required_artifacts("package", cfg, rt)
            self.assertNotIn("landscape-report.html", arts)
            self.assertIn("report.html", arts)

    def test_phases_yaml_and_json_agree(self):
        import yaml
        y = yaml.safe_load((SKILL_ROOT / "phases.yaml").read_text(encoding="utf-8"))
        j = json.loads((SKILL_ROOT / "phases.json").read_text(encoding="utf-8"))
        for key in ("phases", "research_types", "modes"):
            for name, val in j[key].items():
                yv = y[key][name]
                if key == "phases":
                    self.assertEqual(yv["required_artifacts"], val["required_artifacts"], name)
                elif key == "research_types":
                    self.assertEqual(yv.get("phase_artifacts"), val.get("phase_artifacts"), name)
                else:
                    self.assertEqual(yv["phases"], val["phases"], name)

    def test_empty_xlsx_does_not_satisfy_the_gate(self):
        root = _tree(self)
        (root / "comparison").mkdir()
        (root / "comparison" / f"{root.name}-comparison-matrix.xlsx").write_bytes(b"")
        ok, detail = pg.artifact_satisfied(root, "comparison/{dir-slug}-comparison-matrix.xlsx")
        self.assertFalse(ok)
        self.assertIn("empty", detail)


class ProjectLocalPackTests(unittest.TestCase):
    PACK = {
        "category_id": "internal-developer-portals",
        "inclusion_criteria": {"rule": "min_pass_count", "min_pass_count": 1, "criteria": ["a"]},
        "core_seeds": [{"slug": "backstage", "name": "Backstage"}, {"slug": "port", "name": "Port"}],
        "hard_exclusions": [{"slug": "windsurf", "class": "coding_agent"}],
    }

    def _run_dir(self, with_pack=True):
        root = _tree(self)
        profile = {"interview_complete": True, "license_preference": "mixed",
                   "category_pack_id": "internal-developer-portals"}
        (root / "need_profile.json").write_text(json.dumps(profile), encoding="utf-8")
        if with_pack:
            (root / "category-packs").mkdir()
            (root / "category-packs" / "internal-developer-portals.json").write_text(
                json.dumps(self.PACK), encoding="utf-8")
        return root

    def test_gate_accepts_a_project_local_pack_for_a_new_category(self):
        root = self._run_dir()
        self.assertEqual(pg.check_need_profile_gate(root, "solution-compare"), (True, "ok"))

    def test_gate_without_any_pack_still_fails_closed(self):
        root = self._run_dir(with_pack=False)
        ok, detail = pg.check_need_profile_gate(root, "solution-compare")
        self.assertFalse(ok)
        self.assertIn("unresolvable category_pack_id", detail)

    def test_gate_rejects_traversal_in_pack_id(self):
        ok, detail = pg.check_category_pack_gate({"category_pack_id": "../../etc/x"}, Path("/nonexistent"))
        self.assertFalse(ok)
        self.assertIn("invalid category_pack_id", detail)


def _features(root, name, feats, **extra):
    d = root / "solutions" / name
    d.mkdir(parents=True)
    (d / "features.json").write_text(json.dumps({"solution_name": name, **feats}), encoding="utf-8")


class CompareScoringTests(unittest.TestCase):
    def setUp(self):
        import compare_solutions as cs
        self.cs = cs

    def _rows(self, a, b, need=None):
        feats = {"A": a, "B": b}
        comp = self.cs.build_comparison_json(feats, need or {})
        return {r["name"]: r for r in comp["rows"] if r["type"] == "feature"}, comp

    def test_string_false_is_not_a_tick(self):
        rows, _ = self._rows(
            {"features": [{"name": "Audit log", "supported": "false"}, {"name": "SSO", "supported": "Yes"},
                          {"name": "RBAC", "present": 0}]},
            {"features": ["Audit log", "SSO", "RBAC"]})
        self.assertEqual(rows["Audit log"]["solutions"]["A"], "")
        self.assertNotEqual(rows["SSO"]["solutions"]["A"], "")
        self.assertEqual(rows["RBAC"]["solutions"]["A"], "")

    def test_empty_evidence_list_is_not_a_tick(self):
        rows, _ = self._rows(
            {"features": [{"name": "SSO", "evidence_ids": []}, {"name": "API", "evidence_ids": ["e1"]}]},
            {"features": ["SSO", "API"]})
        self.assertEqual(rows["SSO"]["solutions"]["A"], "")
        self.assertNotEqual(rows["API"]["solutions"]["A"], "")

    def test_feature_in_two_categories_is_one_row(self):
        a = {"categories": [{"name": "Security", "features": ["SSO"]},
                            {"name": "Identity", "features": ["SSO", "SCIM"]}]}
        rows, comp = self._rows(a, {"features": ["SSO"]}, {"must_haves": ["SSO"]})
        names = [r["name"] for r in comp["rows"] if r["type"] == "feature"]
        self.assertEqual(names.count("SSO"), 1)
        self.assertEqual(comp["categories"], ["Security", "Identity"])

    def test_tie_is_flagged_in_json_and_markdown(self):
        _, comp = self._rows({"features": ["SSO"]}, {"features": ["SSO"]})
        self.assertEqual(sorted(comp["tie"]), ["A", "B"])
        self.assertIn("**Tie:** ", self.cs.matrix_markdown(comp))
        self.assertNotIn("Tie", self.cs.matrix_markdown({**comp, "tie": []}))

    def test_clear_leader_is_the_winner(self):
        _, comp = self._rows({"features": ["SSO", "API"]}, {"features": ["SSO"]})
        self.assertEqual((comp["winner"], comp["runner_up"], comp["tie"]), ("A", "B", []))

    def test_no_solutions_has_no_tie(self):
        comp = self.cs.build_comparison_json({}, {})
        self.assertEqual((comp["winner"], comp["tie"]), (None, []))


class CompareCategoryPackTests(unittest.TestCase):
    """Real pack, no injected fake module (the old test faked sys.modules)."""

    def _run(self, names, pack_id="agentic-sdlc-process-orchestrator", local=None):
        import compare_solutions as cs
        root = _tree(self)
        profile = {"category_pack_id": pack_id, "must_haves": ["SSO"]} if pack_id else {}
        (root / "need_profile.json").write_text(json.dumps(profile), encoding="utf-8")
        for n in names:
            _features(root, n, {"features": ["SSO", "API"] if n != "silver-bullet" else ["SSO", "API", "Audit"]})
        if local:
            (root / "category-packs").mkdir()
            (root / "category-packs" / f"{pack_id}.json").write_text(json.dumps(local), encoding="utf-8")
        return root, cs

    def test_hard_excluded_product_is_dropped_before_scoring(self):
        root, cs = self._run(["silver-bullet", "Windsurf", "ai-dlc"])
        cs.compare_solutions(root, emit_xlsx=False)
        comp = json.loads((root / "comparison" / "comparison.json").read_text())
        self.assertEqual(sorted(r["solution"] for r in comp["rankings"]), ["ai-dlc", "silver-bullet"])

    def test_unresolvable_pack_fails_closed(self):
        root, cs = self._run(["a-one", "b-two"], pack_id="no-such-pack")
        with self.assertRaisesRegex(ValueError, "category pack could not be resolved"):
            cs.compare_solutions(root, emit_xlsx=False)

    def test_everything_excluded_is_an_error(self):
        root, cs = self._run(["Windsurf", "Cline", "aider"])
        with self.assertRaisesRegex(ValueError, "Fewer than 2"):
            cs.compare_solutions(root, emit_xlsx=False)

    def test_project_local_pack_exclusions_apply(self):
        local = dict(ProjectLocalPackTests.PACK, category_id="idp")
        root, cs = self._run(["Backstage", "Port", "Windsurf"], pack_id="idp", local=local)
        cs.compare_solutions(root, emit_xlsx=False)
        comp = json.loads((root / "comparison" / "comparison.json").read_text())
        self.assertEqual(sorted(r["solution"] for r in comp["rankings"]), ["Backstage", "Port"])

    def test_no_pack_id_keeps_all(self):
        root, cs = self._run(["a-one", "b-two"], pack_id=None)
        cs.compare_solutions(root, emit_xlsx=False)
        comp = json.loads((root / "comparison" / "comparison.json").read_text())
        self.assertEqual(len(comp["rankings"]), 2)


class ShortlistTests(unittest.TestCase):
    def setUp(self):
        import shortlist_candidates as sl
        self.sl = sl

    def test_spdx_open_source_licences_pass_an_oss_preference(self):
        for lic in ("Apache-2.0", "MIT License", "BSD-3-Clause", "GPL-3.0-or-later", "MPL-2.0",
                    "AGPL-3.0", "ISC", "Open Source", "oss"):
            self.assertTrue(self.sl.license_ok({"license": lic}, "oss"), lic)

    def test_non_open_licences_fail_an_oss_preference(self):
        for lic in ("", "Proprietary", "Commercial", "Source-available (BSL 1.1)", "Elastic", "Noncommercial"):
            self.assertFalse(self.sl.license_ok({"license": lic}, "oss"), lic)

    def test_slugs_are_sanitised(self):
        out = self.sl.shortlist([{"name": "X", "slug": "../../../.github/workflows", "score": 1},
                                 {"name": "Y!!", "slug": "///", "score": 0}], {}, 2)
        self.assertEqual(out[0]["slug"], "github-workflows")
        self.assertEqual(out[1]["slug"], "y")
        for item in out:
            self.assertNotIn("/", item["slug"])
            self.assertNotIn("..", item["slug"])

    def test_pack_hard_exclusions_and_aliases_are_applied(self):
        need = {"category_pack_id": "agentic-sdlc-process-orchestrator"}
        cands = [{"name": "Windsurf", "score": 9}, {"name": "Silver Bullet", "score": 5},
                 {"name": "x", "slug": "cline", "score": 8}]
        out = self.sl.shortlist(cands, need, 5)
        self.assertEqual([i["name"] for i in out], ["Silver Bullet"])

    def test_unresolvable_pack_fails_closed(self):
        with self.assertRaises(FileNotFoundError):
            self.sl.shortlist([{"name": "A"}], {"category_pack_id": "nope-pack"}, 1)

    def test_cli_reports_pack_failure_and_uses_local_packs(self):
        import io
        from contextlib import redirect_stderr, redirect_stdout
        root = _tree(self)
        (root / "c.jsonl").write_text(json.dumps({"name": "Backstage", "score": 1}) + "\n"
                                      + json.dumps({"name": "Windsurf", "score": 9}) + "\n", encoding="utf-8")
        need = {"category_pack_id": "idp"}
        (root / "need_profile.json").write_text(json.dumps(need), encoding="utf-8")
        argv = ["x", "--candidates", str(root / "c.jsonl"), "--need-profile", str(root / "need_profile.json"),
                "--out", str(root / "s" / "shortlist.json"), "--count", "1"]
        err = io.StringIO()
        with unittest.mock.patch.object(sys, "argv", argv), redirect_stderr(err):
            with self.assertRaises(SystemExit) as cm:
                self.sl.main()
        self.assertEqual(cm.exception.code, 1)
        self.assertIn("category pack", err.getvalue())
        (root / "category-packs").mkdir()
        (root / "category-packs" / "idp.json").write_text(
            json.dumps(dict(ProjectLocalPackTests.PACK, category_id="idp")), encoding="utf-8")
        out = io.StringIO()
        with unittest.mock.patch.object(sys, "argv", argv), redirect_stdout(out):
            self.sl.main()
        data = json.loads((root / "s" / "shortlist.json").read_text())
        self.assertEqual([x["name"] for x in data["solutions"]], ["Backstage"])


class MatrixCoreSanitizerTests(unittest.TestCase):
    def test_sanitizer_lives_in_matrix_core_and_is_shared(self):
        import matrix_builder as mb
        import matrix_core as mc
        self.assertIs(mb._sanitize_cell_value, mc._sanitize_cell_value)
        self.assertEqual(mc._sanitize_cell_value('=HYPERLINK("x")'), "'=HYPERLINK(\"x\")")
        self.assertEqual(mc._sanitize_cell_value(" \t@x"), "' \t@x")
        self.assertEqual(mc._sanitize_cell_value("ok"), "ok")
        self.assertEqual(mc._sanitize_cell_value(3), 3)


class SpaTests(unittest.TestCase):
    def test_scores_and_tie_are_escaped_in_the_rendered_script(self):
        import generate_report_spa as grs
        html = grs.render_html({"title": "t", "comparison": {}})
        self.assertIn("esc(String(r.score))", html)
        self.assertNotIn("' + r.score +", html)
        self.assertIn("<strong>Tie:</strong>", html)
        self.assertIn("esc(cmp.tie.join(", html)

    def test_malicious_score_stays_inside_the_json_block(self):
        import generate_report_spa as grs
        payload = {"title": "t", "comparison": {"winner": "A",
                   "rankings": [{"solution": "A", "score": "<img src=x onerror=alert(1)>"}]}}
        html = grs.render_html(payload)
        self.assertNotIn("<img src=x", html)  # escaped as \u003c in the data block

    def test_localhost_in_research_content_does_not_fail_validation(self):
        import generate_report_spa as grs
        import validate_spa_report as vsr
        root = _tree(self)
        (root / "solutions" / "a").mkdir(parents=True)
        (root / "solutions" / "a" / "scr.md").write_text("Runs on localhost:3000 via python -m http.server", encoding="utf-8")
        (root / "run_manifest.json").write_text(json.dumps({"question": "q", "research_type": "solution-compare"}))
        out = root / "report.html"
        out.write_text(grs.render_html(grs.collect_report_data(root)), encoding="utf-8")
        res = vsr.validate(out)
        self.assertNotIn("forbidden server/localhost reference in report.html", res["errors"])

    def test_localhost_in_the_page_itself_still_fails(self):
        import generate_report_spa as grs
        import validate_spa_report as vsr
        root = _tree(self)
        out = root / "report.html"
        out.write_text(grs.render_html({"title": "t", "comparison": {}}) + "<a href='http://localhost:8000'>x</a>",
                       encoding="utf-8")
        self.assertIn("forbidden server/localhost reference in report.html", vsr.validate(out)["errors"])


class SourceEvaluatorSpoofTests(unittest.TestCase):
    def setUp(self):
        import source_evaluator as se
        self.ev = se.SourceEvaluator()
        self.se = se

    def _score(self, url, **kw):
        return self.ev.evaluate_source(url=url, title=kw.pop("title", "A page"), **kw)

    def test_userinfo_does_not_grant_gov_authority(self):
        spoof = self._score("https://x.gov@evil.example/p")
        plain = self._score("https://evil.example/p")
        self.assertEqual(spoof.domain_authority, plain.domain_authority)
        self.assertEqual(spoof.authority_tier, plain.authority_tier)
        self.assertNotEqual(spoof.authority_tier, "primary")

    def test_real_gov_and_edu_hosts_still_count(self):
        for url in ("https://www.nasa.gov/x", "https://data.agency.gov/x", "https://www.cabinet-office.gov.uk/x",
                    "https://cs.mit.edu/x", "https://www.ox.ac.uk/x", "https://www.unsw.edu.au/x"):
            self.assertEqual(self._score(url).authority_tier, "primary", url)

    def test_keyword_substrings_do_not_grant_expertise(self):
        blog = self._score("https://acme-science-blog.example/post")
        real = self._score("https://science.org/post")
        self.assertLess(blog.expertise, real.expertise)
        self.assertEqual(blog.expertise, self._score("https://other.example/post").expertise)
        self.assertEqual(self._score("https://data.who.int/x").expertise,
                         self._score("https://who.int/x").expertise)

    def test_commercial_flag_needs_the_real_host(self):
        self.assertIn("commercial", self._score("https://aws.amazon.com/x").bias_flags)
        self.assertIn("commercial", self._score("https://docs.aws.amazon.com/x").bias_flags)
        self.assertNotIn("commercial", self._score("https://aws.amazon.evil.example/x").bias_flags)

    def test_future_dates_are_not_recent(self):
        future = self._score("https://example.org/x", publication_date="2999-01-01")
        old = self._score("https://example.org/x", publication_date="2001-01-01")
        self.assertEqual(future.recency, old.recency)
        self.assertLess(future.recency, 50)

    def test_unparseable_host_is_empty_domain(self):
        self.assertEqual(self.ev._extract_domain("http://[::1"), "")
        self.assertEqual(self.ev._extract_domain("https://WWW.Example.org:8443/p"), "example.org")


class SearchOrchestratorFaultTests(unittest.TestCase):
    def setUp(self):
        import search_orchestrator as so
        self.so = so
        patcher = unittest.mock.patch.dict("os.environ", {"GITHUB_TOKEN": "tok"}, clear=False)
        patcher.start()
        self.addCleanup(patcher.stop)

    def _open(self, raw=None, exc=None, seen=None):
        import io

        class R(io.BytesIO):
            def __enter__(self_inner):
                return self_inner

            def __exit__(self_inner, *a):
                return False

        def fake(req, timeout=None):
            if seen is not None:
                seen.append(req)
            if exc:
                raise exc
            return R(raw)
        return fake

    def test_dropped_connection_is_an_error_not_a_traceback(self):
        import http.client
        with unittest.mock.patch("urllib.request.urlopen",
                                 self._open(exc=http.client.RemoteDisconnected("closed"))):
            res = self.so.fetch_portal("skills_sh", "q")
        self.assertEqual(res["status"], "error")
        self.assertIn("closed", res["reason"])

    def test_latin1_body_is_decoded_with_replacement(self):
        with unittest.mock.patch("urllib.request.urlopen", self._open(raw=b'{"name": "caf\xe9"}')):
            res = self.so.fetch_portal("skills_sh", "q")
        self.assertEqual(res["status"], "ok")
        self.assertIn("caf", res["results"]["name"])

    def test_oversized_body_is_refused(self):
        big = b"x" * (self.so.MAX_PORTAL_BYTES + 10)
        with unittest.mock.patch("urllib.request.urlopen", self._open(raw=big)):
            res = self.so.fetch_portal("skills_sh", "q")
        self.assertEqual(res["status"], "error")
        self.assertIn("larger than", res["reason"])

    def test_github_without_a_token_is_skipped_and_with_one_sends_it(self):
        with unittest.mock.patch.dict("os.environ", {"GITHUB_TOKEN": "", "GH_TOKEN": ""}):
            res = self.so.fetch_portal("github", "q")
        self.assertEqual(res["status"], "skipped")
        self.assertIn("GITHUB_TOKEN", res["reason"])
        seen = []
        with unittest.mock.patch.dict("os.environ", {"GITHUB_TOKEN": "", "GH_TOKEN": "ghp_x"}), \
                unittest.mock.patch("urllib.request.urlopen", self._open(raw=b"[]", seen=seen)):
            self.assertEqual(self.so.fetch_portal("github", "q")["status"], "ok")
        self.assertEqual(seen[0].get_header("Authorization"), "Bearer ghp_x")

    def test_github_code_search_items_get_branch_correct_urls(self):
        results = {"total_count": 1, "items": [{"repository": {"full_name": "Weizhena/Deep-Research-skills"}},
                                               {"name": "no repo"}, "junk"]}
        with unittest.mock.patch.object(self.so, "_github_branch_resolver",
                                        return_value={"Weizhena/Deep-Research-skills": "master"}):
            out = self.so._enrich_github_results(results)
        self.assertEqual(out["total_count"], 1)
        self.assertIn("/master/SKILL.md", out["items"][0]["skill_md_url"])
        self.assertNotIn("skill_md_url", out["items"][1])
        self.assertEqual(self.so._enrich_github_results({"raw": "x"}), {"raw": "x"})
        self.assertEqual(self.so._enrich_github_results("text"), "text")

    def test_failed_portal_is_recorded_and_the_manifest_is_still_written(self):
        root = _tree(self)

        def fake_fetch(portal_id, query, mock=None):
            if portal_id == "skills_sh":
                return {"portal_id": portal_id, "status": "error", "reason": "RemoteDisconnected"}
            if portal_id == "github":
                return {"portal_id": portal_id, "status": "ok", "results": {"items": []}}
            return {"portal_id": portal_id, "status": "skipped", "reason": "x"}

        with unittest.mock.patch.object(self.so, "fetch_portal", fake_fetch), \
                unittest.mock.patch("shutil.which", return_value=None):
            rec = self.so.orchestrate("q", root, research_type="landscape")
        self.assertEqual(rec["retrieval"]["portals_failed"], {"skills_sh": "RemoteDisconnected"})
        self.assertIn("github", rec["retrieval"]["portals_succeeded"])
        manifest = json.loads((root / "run_manifest.json").read_text())
        self.assertEqual(manifest["retrieval"]["portals_failed"], {"skills_sh": "RemoteDisconnected"})

    def test_error_without_reason_is_still_recorded(self):
        root = _tree(self)
        with unittest.mock.patch.object(self.so, "fetch_portal",
                                        lambda *a, **k: {"status": "error"}), \
                unittest.mock.patch("shutil.which", return_value=None):
            rec = self.so.orchestrate("q", root, research_type="landscape")
        self.assertTrue(all(v == "error" for v in rec["retrieval"]["portals_failed"].values()))


class GeneratedArtifactsPassThePhaseGateTests(unittest.TestCase):
    """Run the documented tools and let the gate judge their real output (R11-16)."""

    def test_compare_then_spa_satisfy_the_solution_type_artifacts(self):
        import deps_probe
        if not deps_probe.openpyxl_importable():
            self.skipTest("openpyxl not installed")
        import compare_solutions as cs
        import generate_report_spa as grs
        root = _tree(self)
        (root / "need_profile.json").write_text(json.dumps({"must_haves": ["SSO"]}), encoding="utf-8")
        (root / "run_manifest.json").write_text(
            json.dumps({"question": "q", "research_type": "solution-compare"}), encoding="utf-8")
        _features(root, "alpha", {"features": ["SSO", "API"]})
        _features(root, "beta", {"features": ["API"]})
        cs.compare_solutions(root)
        (root / "report.html").write_text(grs.render_html(grs.collect_report_data(root)), encoding="utf-8")
        cfg = pg.load_phases_config()
        for phase in ("synthesize", "package"):
            added = (cfg["research_types"]["solution-compare"]["phase_artifacts"].get(phase) or {}).get("add", [])
            self.assertTrue(added, phase)
            for artifact in added:
                ok, detail = pg.artifact_satisfied(root, artifact)
                self.assertTrue(ok, f"{phase}: {artifact}: {detail}")


if __name__ == "__main__":
    unittest.main()
