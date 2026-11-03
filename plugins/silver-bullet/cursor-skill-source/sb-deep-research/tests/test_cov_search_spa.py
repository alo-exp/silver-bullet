"""Coverage tests for search_orchestrator, generate_report_spa/spa_embed, validate_spa_report."""

import io
import json
import os
import tempfile
import unittest
import urllib.error
from pathlib import Path
from unittest import mock

import covhelp
from covhelp import SCRIPTS, call_main, run_script

import generate_report_spa as grs
import search_orchestrator as so
import spa_embed
import validate_spa_report as vsr


def setUpModule():
    covhelp.block_network()


def tearDownModule():
    covhelp.unblock_network()


class FakeResp(io.BytesIO):
    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False


def fake_urlopen(body, seen=None):
    def _open(req, timeout=None):
        if seen is not None:
            seen.append((req.full_url, req.get_header("User-agent"), timeout))
        if isinstance(body, BaseException):
            raise body
        return FakeResp(body.encode("utf-8"))
    return _open


class TestClassifyAndProbe(unittest.TestCase):
    def test_classify_intent(self):
        self.assertEqual(so.classify_intent("anything", "landscape"), "landscape")
        self.assertEqual(so.classify_intent("anything", "skill-comparison"), "landscape")
        self.assertEqual(so.classify_intent("x", "market"), "market")
        self.assertEqual(so.classify_intent("x", "technical"), "technical")
        for q in ("A vs B", "compare things", "X versus Y", "tradeoffs"):
            self.assertEqual(so.classify_intent(q), "comparative", q)
        self.assertEqual(so.classify_intent("what is a cat"), "factual")
        with mock.patch.object(so, "load_catalog", return_value={}):
            self.assertEqual(so.classify_intent("plain"), "factual")
        with mock.patch.object(so, "load_catalog", return_value={"default_class": "custom"}):
            self.assertEqual(so.classify_intent("plain", "other"), "custom")

    def test_probe_search_cli(self):
        with mock.patch("shutil.which", return_value=None):
            self.assertEqual(so.probe_search_cli(),
                             {"status": "unavailable", "providers_available": [], "path": None})
        with mock.patch("shutil.which", return_value="/bin/search"):
            self.assertEqual(so.probe_search_cli(), {"status": "available",
                             "providers_available": ["search-cli"], "path": "/bin/search"})


class TestSysPathBootstrap(unittest.TestCase):
    def test_script_dir_prepended_when_absent(self):
        import sys
        saved = list(sys.path)
        try:
            sys.path[:] = [p for p in sys.path if Path(p).resolve() != SCRIPTS.resolve()]
            run_script(SCRIPTS / "search_orchestrator.py", [], as_main=False)
            self.assertEqual(Path(sys.path[0]).resolve(), SCRIPTS.resolve())
        finally:
            sys.path[:] = saved


class TestBranchResolver(unittest.TestCase):
    def test_resolver_env(self):
        with tempfile.TemporaryDirectory() as d:
            f = Path(d) / "b.json"
            f.write_text(json.dumps({"o/r": "dev"}))
            with mock.patch.dict(os.environ, {}, clear=False):
                os.environ.pop("SB_DR_GITHUB_BRANCHES_JSON", None)
                self.assertIsNone(so._github_branch_resolver())
            with mock.patch.dict(os.environ, {"SB_DR_GITHUB_BRANCHES_JSON": str(Path(d) / "none.json")}):
                self.assertIsNone(so._github_branch_resolver())
            with mock.patch.dict(os.environ, {"SB_DR_GITHUB_BRANCHES_JSON": str(f)}):
                self.assertEqual(so._github_branch_resolver(), {"o/r": "dev"})


class TestFetchPortal(unittest.TestCase):
    def test_unknown_portal(self):
        res = so.fetch_portal("nope", "q")
        self.assertEqual(res, {"portal_id": "nope", "status": "error", "reason": "unknown portal"})

    def test_mock_response_wins(self):
        with mock.patch("urllib.request.urlopen", side_effect=AssertionError("no network")):
            res = so.fetch_portal("skills_sh", "q", {"skills_sh": [1]})
        self.assertEqual(res, {"portal_id": "skills_sh", "status": "ok", "results": [1], "mock": True})

    def test_portal_without_search_url_is_skipped(self):
        res = so.fetch_portal("smithery", "q", {"other": []})
        self.assertEqual(res["status"], "skipped")
        self.assertIn("Adjacent MCP", res["reason"])
        with mock.patch.object(so, "load_catalog", return_value={"portals": {"p": {"id": "p"}}}):
            self.assertEqual(so.fetch_portal("p", "q")["reason"], "no search_url")

    def test_ok_json_and_quoting(self):
        seen = []
        with mock.patch("urllib.request.urlopen", fake_urlopen('{"items": [1]}', seen)):
            res = so.fetch_portal("skills_sh", "a b&c")
        self.assertEqual(res, {"portal_id": "skills_sh", "status": "ok", "results": {"items": [1]}})
        url, ua, timeout = seen[0]
        self.assertEqual(url, "https://skills.sh/api/search?q=a%20b%26c")
        self.assertEqual(ua, "silver-deep-research/1.0")
        self.assertEqual(timeout, 10)

    def test_ok_list_and_raw_body(self):
        with mock.patch("urllib.request.urlopen", fake_urlopen("  [1, 2]")):
            self.assertEqual(so.fetch_portal("skills_sh", "q")["results"], [1, 2])
        with mock.patch("urllib.request.urlopen", fake_urlopen("<html>" + "x" * 600)):
            res = so.fetch_portal("skills_sh", "q")
        self.assertEqual(len(res["results"]["raw"]), 500)

    def test_errors_reported(self):
        for exc in (urllib.error.URLError("down"), TimeoutError("slow")):
            with mock.patch("urllib.request.urlopen", fake_urlopen(exc)):
                res = so.fetch_portal("github", "q")
            self.assertEqual(res["status"], "error")
            self.assertTrue(res["fallback_on_error"])
            self.assertIn("down" if isinstance(exc, urllib.error.URLError) else "slow", res["reason"])
        with mock.patch("urllib.request.urlopen", fake_urlopen("{broken")):
            res = so.fetch_portal("github", "q")
        self.assertEqual(res["status"], "error")
        self.assertIn("Expecting", res["reason"])

    def test_error_default_fallback_flag(self):
        cat = {"portals": {"p": {"search_url": "https://x/{query}"}}}
        with mock.patch.object(so, "load_catalog", return_value=cat), \
                mock.patch("urllib.request.urlopen", fake_urlopen(urllib.error.URLError("x"))):
            self.assertTrue(so.fetch_portal("p", "q")["fallback_on_error"])


class TestOrchestrate(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.addCleanup(self._td.cleanup)
        self.out = Path(self._td.name) / "out"
        patcher = mock.patch("shutil.which", return_value=None)
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_non_landscape_has_no_portals_and_new_manifest(self):
        rec = so.orchestrate("what is x", self.out, mode="deep")
        self.assertEqual(rec["intent_class"], "factual")
        self.assertEqual(rec["retrieval"]["portals_attempted"], [])
        manifest = json.loads((self.out / "run_manifest.json").read_text())
        self.assertEqual(manifest["version"], "3.0.0")
        self.assertEqual(manifest["mode"], "deep")
        self.assertIn("search-cli not installed", manifest["fallback_reason"])

    def test_offline_skips_every_portal(self):
        rec = so.orchestrate("q", self.out, research_type="landscape", offline=True)
        self.assertEqual(rec["search_cli"]["fallback_reason"], "offline")
        self.assertEqual(len(rec["retrieval"]["portals_attempted"]), 5)
        self.assertEqual(rec["retrieval"]["portals_succeeded"], [])
        self.assertEqual(list(self.out.glob("portal-*.json")), [])

    def test_search_cli_available_has_no_fallback(self):
        with mock.patch("shutil.which", return_value="/usr/bin/search"):
            rec = so.orchestrate("q", self.out)
        self.assertIsNone(rec["retrieval"]["fallback_reason"])
        manifest = json.loads((self.out / "run_manifest.json").read_text())
        self.assertNotIn("fallback_reason", manifest)
        self.assertEqual(manifest["search_cli"]["status"], "available")

    def test_mock_portals_written_and_github_enriched(self):
        branches = Path(self._td.name) / "branches.json"
        branches.write_text(json.dumps({"o/r": "dev"}))
        mock_resp = {
            "github": [{"fullName": "o/r"}],
            "skills_sh": [{"name": "x"}],
        }
        def fake_fetch(portal_id, query, mock_responses=None):
            if portal_id in mock_resp:
                return {"portal_id": portal_id, "status": "ok", "results": mock_resp[portal_id]}
            if portal_id == "smithery":
                return {"portal_id": portal_id, "status": "error", "reason": "x"}
            return {"portal_id": portal_id, "status": "skipped"}
        with mock.patch.object(so, "fetch_portal", fake_fetch), \
                mock.patch.dict(os.environ, {"SB_DR_GITHUB_BRANCHES_JSON": str(branches)}):
            rec = so.orchestrate("q", self.out, research_type="skill-comparison")
        self.assertEqual(rec["retrieval"]["portals_succeeded"], ["github", "skills_sh"])
        gh = json.loads((self.out / "portal-github.json").read_text())
        self.assertEqual(gh["results"][0]["default_branch"], "dev")
        sk = json.loads((self.out / "portal-skills_sh.json").read_text())
        self.assertEqual(sk["results"], [{"name": "x"}])
        self.assertFalse((self.out / "portal-smithery.json").exists())
        self.assertEqual(rec["retrieval"]["portal_partials"]["github"], str(self.out / "portal-github.json"))

    def test_github_non_list_results_not_enriched(self):
        def fake_fetch(portal_id, query, mock_responses=None):
            if portal_id == "github":
                return {"portal_id": "github", "status": "ok", "results": {"items": []}}
            return {"portal_id": portal_id, "status": "skipped"}
        with mock.patch.object(so, "fetch_portal", fake_fetch):
            so.orchestrate("q", self.out, research_type="landscape")
        gh = json.loads((self.out / "portal-github.json").read_text())
        self.assertEqual(gh["results"], {"items": []})

    def test_existing_manifest_is_extended(self):
        self.out.mkdir(parents=True)
        (self.out / "run_manifest.json").write_text(json.dumps({"keep": 1, "mode": "quick"}))
        so.orchestrate("q", self.out, mode="deep")
        manifest = json.loads((self.out / "run_manifest.json").read_text())
        self.assertEqual(manifest["keep"], 1)
        self.assertEqual(manifest["mode"], "quick")
        self.assertIn("retrieval", manifest)

    def test_orchestrate_passes_mock_responses_to_fetch(self):
        seen = []
        def fake_fetch(portal_id, query, mock_responses=None):
            seen.append((portal_id, query, mock_responses))
            return {"portal_id": portal_id, "status": "skipped"}
        with mock.patch.object(so, "fetch_portal", fake_fetch):
            so.orchestrate("qq", self.out, research_type="landscape", mock_responses={"a": 1})
        self.assertEqual(seen[0][1:], ("qq", {"a": 1}))

    def test_main_with_and_without_mock_file(self):
        code, out, _ = call_main(so, ["-q", "what", "--dir", str(self.out)])
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(out)["query"], "what")
        mock_file = Path(self._td.name) / "m.json"
        mock_file.write_text(json.dumps({"skills_sh": [{"n": 1}]}))
        with mock.patch("urllib.request.urlopen", fake_urlopen(urllib.error.URLError("offline"))):
            code, out, _ = call_main(so, ["-q", "w", "--dir", str(self.out), "--research-type",
                                          "landscape", "--mock-portal-json", str(mock_file),
                                          "--mode", "deep"])
        res = json.loads(out)
        self.assertEqual(res["retrieval"]["portals_succeeded"], ["skills_sh"])
        self.assertIn("skills_sh", res["retrieval"]["portals_succeeded"])
        self.assertEqual(res["mode"], "deep")

    def test_run_as_script_offline(self):
        code, out, _ = run_script(SCRIPTS / "search_orchestrator.py",
                                  ["-q", "x", "--dir", str(self.out), "--offline"])
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(out)["search_cli"]["fallback_reason"], "offline")


class TestSpaEmbed(unittest.TestCase):
    def test_escapes_script_breakers(self):
        out = spa_embed.safe_json_payload({"a": "</script>\u2028\u2029é"})
        self.assertNotIn("<", out)
        self.assertIn("\\u003c/script>", out)
        self.assertIn("\\u2028", out)
        self.assertIn("\\u2029", out)
        self.assertIn("é", out)
        self.assertEqual(json.loads(out)["a"], "</script>\u2028\u2029é")


class TestGenerateReportSpa(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.addCleanup(self._td.cleanup)
        self.root = Path(self._td.name) / "run"
        self.root.mkdir()

    def test_load_json(self):
        self.assertIsNone(grs.load_json(self.root / "none.json"))
        (self.root / "a.json").write_text("[1]")
        self.assertEqual(grs.load_json(self.root / "a.json"), [1])

    def test_collect_empty(self):
        data = grs.collect_report_data(self.root)
        self.assertEqual(data["title"], "Solution Research")
        self.assertEqual(data["research_type"], "default")
        self.assertEqual(data["scrs"], [])
        self.assertEqual(data["landscape_excerpt"], "")
        self.assertEqual(data["decision_excerpt"], "")
        self.assertIsNone(data["shortlist"])
        self.assertIsNone(data["solutions_requested"])

    def test_collect_full_and_truncation(self):
        r = self.root
        (r / "run_manifest.json").write_text(json.dumps({"question": "Q?", "research_type": "solution-compare"}))
        (r / "need_profile.json").write_text(json.dumps({"category": "IDP"}))
        (r / "comparison").mkdir()
        (r / "comparison" / "comparison.json").write_text(json.dumps({"winner": "A"}))
        (r / "shortlist").mkdir()
        (r / "shortlist" / "shortlist.json").write_text(json.dumps({"solutions": []}))
        (r / "solutions_requested.json").write_text(json.dumps({"names": ["a"]}))
        (r / "solutions" / "b-two").mkdir(parents=True)
        (r / "solutions" / "b-two" / "scr.md").write_text("B" * 13000)
        (r / "solutions" / "a-one").mkdir()
        (r / "solutions" / "a-one" / "scr.md").write_text("A")
        (r / "solutions" / "empty").mkdir()
        (r / "landscape").mkdir()
        (r / "landscape" / "landscape-report.md").write_text("L" * 21000)
        (r / "decision-record.md").write_text("D" * 9000)
        data = grs.collect_report_data(r)
        self.assertEqual(data["title"], "Q?")
        self.assertEqual(data["research_type"], "solution-compare")
        self.assertEqual(data["comparison"], {"winner": "A"})
        self.assertEqual([s["slug"] for s in data["scrs"]], ["a-one", "b-two"])
        self.assertEqual(data["scrs"][0]["title"], "A One")
        self.assertEqual(len(data["scrs"][1]["body"]), 12000)
        self.assertEqual(len(data["landscape_excerpt"]), 20000)
        self.assertEqual(len(data["decision_excerpt"]), 8000)

    def test_title_falls_back_to_category(self):
        (self.root / "need_profile.json").write_text(json.dumps({"category": "IDP"}))
        self.assertEqual(grs.collect_report_data(self.root)["title"], "IDP")

    def test_render_html_escapes_title_and_payload(self):
        html_out = grs.render_html({"title": "<b>T</b>", "need_profile": {}})
        self.assertIn("<title>&lt;b&gt;T&lt;/b&gt;</title>", html_out)
        self.assertIn('id="report-data"', html_out)
        self.assertNotIn("<b>T</b>", html_out)
        self.assertIn("\\u003cb>T\\u003c/b>", html_out)
        self.assertIn("<title>Research Report</title>", grs.render_html({}))

    def test_main_default_and_explicit_out(self):
        code, out, _ = call_main(grs, ["--dir", str(self.root)])
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(out), {"status": "ok", "out": str(self.root / "report.html")})
        self.assertIn("panel-matrix", (self.root / "report.html").read_text())
        custom = self.root / "custom.html"
        code, out, _ = call_main(grs, ["--dir", str(self.root), "--out", str(custom)])
        self.assertTrue(custom.exists())

    def test_run_as_script(self):
        code, out, _ = run_script(SCRIPTS / "generate_report_spa.py", ["--dir", str(self.root)])
        self.assertEqual(code, 0)
        self.assertTrue((self.root / "report.html").exists())

    def test_generated_report_passes_validator(self):
        (self.root / "need_profile.json").write_text(json.dumps({"category": "x<y"}))
        grs_out = self.root / "report.html"
        call_main(grs, ["--dir", str(self.root)])
        self.assertEqual(vsr.validate(grs_out)["status"], "pass")


GOOD_JS = "<script>let table = ''; table += 'x';</script>"


def _html(payload_raw, extra="", markers=("data-tab-marker", "panel-overview", "panel-matrix")):
    return (f'<html>{" ".join(markers)}<script type="application/json" id="report-data">{payload_raw}</script>'
            f'{extra}</html>')


class TestValidateSpaReport(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.addCleanup(self._td.cleanup)
        self.path = Path(self._td.name) / "report.html"

    def run_validate(self, text, profile=None):
        self.path.write_text(text, encoding="utf-8")
        return vsr.validate(self.path, profile)

    def test_missing_file(self):
        self.assertEqual(vsr.validate(self.path), {"status": "fail", "errors": ["report.html missing"]})

    def test_general_pass_and_profile_label(self):
        res = self.run_validate(_html('{"title": "t"}', GOOD_JS), "general")
        self.assertEqual(res, {"status": "pass", "errors": [], "profile": "general"})
        res = self.run_validate(_html('{"title": "t"}', GOOD_JS))
        self.assertEqual(res["profile"], "legacy-general")
        self.assertEqual(res["status"], "pass")

    def test_forbidden_references(self):
        for bad in ("python -m http.server", "http://localhost:8000", "launch_report.sh"):
            res = self.run_validate(_html('{"title": "t"}', GOOD_JS + bad))
            self.assertIn("forbidden server/localhost reference in report.html", res["errors"], bad)

    def test_missing_markers(self):
        res = self.run_validate('<script type="application/json" id="report-data">{"title":1}</script>')
        self.assertEqual([e for e in res["errors"] if e.startswith("missing tab")], [
            "missing tab/data marker: data-tab-marker",
            "missing tab/data marker: panel-overview",
            "missing tab/data marker: panel-matrix"])

    def test_matrix_js_checks(self):
        bad = "<script>table += 'x';</script>"
        res = self.run_validate(_html('{"title": "t"}', bad), "general")
        self.assertIn("matrix JS uses table += without let/var table declaration", res["errors"])
        # no scripts at all besides json (type=application/json does not match <script>)
        res = self.run_validate(_html('{"title": "t"}'), "general")
        self.assertEqual(res["errors"], [])
        # += absent
        res = self.run_validate(_html('{"title": "t"}', "<script>var a = 1;</script>"))
        self.assertEqual(res["errors"], [])
        # declared with var
        res = self.run_validate(_html('{"title": "t"}', "<script>var table = ''; table += 1;</script>"))
        self.assertEqual(res["errors"], [])

    def test_matrix_js_not_checked_for_landscape(self):
        text = ('<html>data-sb-landscape-viewer id="sidebar" id="toc" id="exportBar" chart-frame '
                'landscape-matrix-panel <script type="application/json" id="report-data">{"landscape": 1}'
                "</script><script>table += 1;</script></html>")
        res = self.run_validate(text, "landscape")
        self.assertEqual(res["errors"], [])
        self.assertEqual(res["profile"], "landscape")

    def test_landscape_missing_markers(self):
        res = self.run_validate(_html('{"landscape": 1}'), "landscape")
        self.assertIn("missing tab/data marker: data-sb-landscape-viewer", res["errors"])
        self.assertNotIn("missing tab/data marker: data-tab-marker", res["errors"])

    def test_missing_json_block(self):
        res = self.run_validate("<html>data-tab-marker panel-overview panel-matrix</html>")
        self.assertIn("missing type=application/json report-data script block", res["errors"])

    def test_unparseable_and_non_object_payload(self):
        res = self.run_validate(_html("{nope"))
        self.assertTrue(any(e.startswith("report-data JSON not parseable") for e in res["errors"]))
        res = self.run_validate(_html("[1, 2]"))
        self.assertIn("report-data payload must be a JSON object", res["errors"])

    def test_no_payload_and_no_error_adds_nothing(self):
        with mock.patch.object(vsr, "_extract_json_payload", return_value=(None, None)):
            res = self.run_validate(_html('{"title": "t"}', GOOD_JS))
        self.assertEqual(res["errors"], [])

    def test_missing_substantive_keys(self):
        res = self.run_validate(_html('{"other": 1}'))
        msg = [e for e in res["errors"] if "lacks substantive keys" in e][0]
        self.assertIn("comparison, consolidation, need_profile, research_type, scrs, title", msg)
        text = ('<html>data-sb-landscape-viewer id="sidebar" id="toc" id="exportBar" chart-frame '
                'landscape-matrix-panel <script type="application/json" id="report-data">{"scrs": 1}</script></html>')
        res = self.run_validate(text, "landscape")
        msg = [e for e in res["errors"] if "lacks substantive keys" in e][0]
        self.assertIn("chart_data, comparison, landscape, markdown, need_profile, research_type, title", msg)

    def test_escaping_checks(self):
        raw = json.dumps({"title": "a<b\u2028\u2029"}, ensure_ascii=False)
        res = self.run_validate(_html(raw))
        self.assertIn("report-data must escape < as \\u003c in embedded JSON", res["errors"])
        self.assertIn("report-data must escape U+2028 as \\u2028 in embedded JSON", res["errors"])
        self.assertIn("report-data must escape U+2029 as \\u2029 in embedded JSON", res["errors"])
        safe = spa_embed.safe_json_payload({"title": "a<b\u2028\u2029"})
        self.assertEqual(self.run_validate(_html(safe))["errors"], [])

    def test_main(self):
        self.path.write_text(_html('{"title": "t"}', GOOD_JS))
        code, out, _ = call_main(vsr, ["--report", str(self.path)])
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(out)["status"], "pass")
        code, out, _ = call_main(vsr, ["--report", str(self.path), "--profile", "landscape"])
        self.assertEqual(code, 1)
        code, out, _ = run_script(SCRIPTS / "validate_spa_report.py", ["--report", str(self.path)])
        self.assertEqual(code, 0)


if __name__ == "__main__":
    unittest.main()
