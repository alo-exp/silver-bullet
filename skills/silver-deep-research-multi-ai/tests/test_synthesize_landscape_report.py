"""Unit tests for synthesize_landscape prose scrubbing, consensus, report assembly and CLI."""

from __future__ import annotations

import contextlib
import io
import json
import runpy
import sys
import unittest
from unittest import mock

from synth_helpers import APO_NEED, SCRIPTS, TmpCase, sl

PACK = {
    "markets": [
        {"id": "apo", "seeds": [{"slug": "silver-bullet", "name": "Silver Bullet"}]},
        {"id": "sdlc-plugins",
         "seeds": [{"slug": "claude-harness", "name": "Claude Harness"}, {"slug": "cc10x", "name": "cc10x"},
                   "junk", {"name": "no slug"}],
         "adjacent_seeds": [{"slug": "conductor", "name": "Conductor"}, {"slug": "magic-dev", "name": "Magic.dev"},
                            {"slug": "cursor", "name": "Cursor"}, {"slug": "widget", "name": "Widget"},
                            {"slug": " "}, "junk", {"slug": "silver-bullet", "name": "Silver Bullet"}]},
    ],
    "inclusion_criteria": {"criteria": [{"id": "hook_gates", "label": "Hook gates"}, "junk",
                                        {"id": "other_thing"}, {"label": "no id"}]},
    "exclusion_classes": [{"id": "coding_agent", "label": "Generic coding agent"}, {"id": "host_runtime"}, "junk"],
}


class JargonTests(unittest.TestCase):
    def test_humanize(self):
        h = sl._humanize_pack_jargon
        self.assertEqual(h("", PACK), "")
        self.assertEqual(h("keep hook_gates", None), "keep hook_gates")
        out = h("Fails hook_gates and other_thing; coding_agent / host_runtime ok", PACK)
        self.assertEqual(out, "Fails Hook gates and other thing; Generic coding agent / host runtime ok")
        no_criteria = dict(PACK, inclusion_criteria={})
        self.assertEqual(h("coding_agent here", no_criteria), "Generic coding agent here")
        self.assertEqual(h("nothing special", dict(PACK, exclusion_classes=[])), "nothing special")

    def test_non_apo_labels(self):
        self.assertEqual(sl._non_apo_display_labels(PACK),
                         {"Claude Harness", "cc10x", "Conductor", "Magic.dev", "Cursor", "Widget"})
        no_apo = {"markets": [{"id": "x", "seeds": [{"slug": "a", "name": "A"}], "adjacent_seeds": []}]}
        self.assertEqual(sl._non_apo_display_labels(no_apo), {"A"})
        self.assertEqual(sl._non_apo_display_labels({"markets": [{"id": "apo", "seeds": []}]}), set())


class ScrubTests(unittest.TestCase):
    def s(self, text, pack=PACK):
        return sl.scrub_membership_framing(text, pack)

    def test_passthrough(self):
        self.assertEqual(self.s("", PACK), "")
        self.assertEqual(self.s("text", None), "text")
        empty = {"markets": [{"id": "apo", "seeds": [{"slug": "a", "name": "A"}]}]}
        self.assertEqual(self.s("Claude Harness APO", empty), "Claude Harness APO")
        self.assertEqual(self.s("Nothing relevant here APO"), "Nothing relevant here APO")
        self.assertEqual(self.s("Widget exists"), "Widget exists")  # no APO mention
        self.assertEqual(self.s("a\n\nb\n"), "a\n\nb")

    def test_apo_candidate_rewrites(self):
        self.assertEqual(self.s("Claude Harness is a primary-market APO candidate — strong."),
                         "Claude Harness is an SDLC-plugins methodology pack (not an APO peer) — strong.")
        self.assertIn("[Claude Harness](https://u) is an SDLC-plugins methodology pack",
                      self.s("[Claude Harness](https://u) is a primary-market APO candidate - ok"))
        self.assertIn("hard-excluded coding-model lab", self.s("Magic.dev is a primary-market APO candidate — x"))
        for host in ("Cursor",):
            self.assertIn("host-runtime / SaaS-adjacent surface",
                          self.s(f"{host} is a primary-market APO candidate — x"))
        self.assertIn("Widget is not an APO peer — x", self.s("Widget is a primary-market APO candidate — x"))

    def test_claude_harness_fallback(self):
        out = self.s("Claude Harness is a primary-market APO candidate. APO peers differ.")
        self.assertIn("Claude Harness (sdlc-plugins, not APO)", out)

    def test_cc10x(self):
        out = self.s("cc10x occupies a mid-tier APO band for many teams. More.")
        self.assertEqual(out, "cc10x is an SDLC-plugins Claude Code plugin (not an APO peer). More.")

    def test_conductor_rules(self):
        self.assertTrue(self.s("- Conductor sits in the mid-tier APO cluster").startswith("- cc10x is an"))
        self.assertTrue(self.s("* Conductor sits in the mid-tier APO band").startswith("* cc10x is an"))
        self.assertTrue(self.s("Conductor sits in the mid-tier APO band").startswith("cc10x is an"))
        self.assertTrue(self.s("Conductor and the most credible non-SB APO entrants").startswith(
            "AI-DLC is the most credible non-SB APO entrant"))
        self.assertTrue(self.s("Conductor occupies a distinct sub-position in the APO space").startswith(
            "Conductor occupies a SaaS-adjacent niche"))
        out = self.s("The leading verifiable solutions in APO are Conductor, Foo and Bar.")
        self.assertNotIn("Conductor", out)
        self.assertNotIn("REMOVED_NON_APO", out)
        out = self.s("APO seeds: Alpha, Conductor, Beta, and [Conductor](https://c.example) plus Conductor.build, Gamma")
        self.assertNotIn("Conductor,", out)
        self.assertEqual(self.s("The APO list is Conductor and Foo."), "The APO list is Foo.")

    def test_conductor_annotation(self):
        out = self.s("Conductor is considered APO by some.")
        self.assertIn("Conductor (SaaS-adjacent coding-agent aggregator, not APO)", out)
        already = self.s("Conductor is not APO, though APO is broad.")
        self.assertNotIn("SaaS-adjacent coding-agent aggregator", already)
        no_apo_mention = self.s("Conductor, Foo (APO) and more")
        self.assertNotIn("Conductor,", no_apo_mention)


class ClaimRecordTests(unittest.TestCase):
    def test_records(self):
        envs = ["junk",
                {"logical_model_id": "claude-x", "phase_id": "DR-TRIANGULATE", "payload": {
                    "claim_candidates": [{"text": "c1 [lean-ctx: z]"}, "junk", {"text": ""}],
                    "evidence": [{"claim": "e1"}, {"text": "e2"}, {"other": 1}, "plain string", "  ", 5]}},
                {"phase_id": "P", "payload": "not-a-dict"},
                {"logical_model_id": "gpt-4", "payload": {"claim_candidates": "no", "evidence": None}},
                {"payload": {"evidence": [{"claim": "[lean-ctx: only]"}]}}]
        recs = sl._envelope_claim_records(envs)
        self.assertEqual([(r["text"], r["family"], r["phase"]) for r in recs], [
            ("c1", "claude", "DR-TRIANGULATE"), ("e1", "claude", "DR-TRIANGULATE"),
            ("e2", "claude", "DR-TRIANGULATE"), ("plain string", "claude", "DR-TRIANGULATE")])
        self.assertEqual(sl._envelope_claim_records(None), [])

    def test_consensus(self):
        def env(model, text, phase="DR-TRIANGULATE"):
            return {"logical_model_id": model, "phase_id": phase, "payload": {"evidence": [{"claim": text}]}}

        envs = [env("claude-a", "It is a process layer."), env("gemini-b", "Sits above the host."),
                env("gpt-c", "A Compliance/Enforcement Layer"), env("qwen-d", "process layer", "DR-OTHER"),
                env("claude-a", "hook gates"), env("gemini-b", "quality gate")]
        got = sl.build_consensus_patterns(envs)
        self.assertEqual([p["id"] for p in got], ["process-first"])
        self.assertEqual(got[0]["families"], ["claude", "gemini", "openai"])
        self.assertEqual(got[0]["models"], ["claude-a", "gemini-b", "gpt-c"])
        self.assertEqual(sl.build_consensus_patterns(envs, min_families=4), [])
        self.assertEqual(sl.build_consensus_patterns([]), [])
        both = envs + [env("gpt-c", "hook gate"), env("qwen-d", "PreToolUse hook", "DR-CRITIQUE")]
        self.assertEqual([p["id"] for p in sl.build_consensus_patterns(both, min_families=3)],
                         ["process-first", "hook-gates"])


class MethodologyAndGuidanceTests(unittest.TestCase):
    def test_scoring_methodology(self):
        comp = {"rows": ["junk", {"type": "other"}, {"type": "feature", "name": " "},
                         {"type": "feature", "name": "F1", "priority": "Critical"},
                         {"type": "feature", "name": "F2"}, {"type": "feature", "name": "F3", "priority": "Low"}]}
        text = "\n".join(sl._scoring_methodology_lines(comp, None))
        self.assertIn("### Scoring methodology", text)
        self.assertIn("- **Critical (5 pts per ✔)**: F1", text)
        self.assertIn("- **Unspecified (1 pts per ✔)**: F2", text)
        self.assertIn("- **Low (1 pts per ✔)**: F3", text)
        self.assertNotIn("| Market | Chart |", text)
        self.assertNotIn("Matrix rows in this run", "\n".join(sl._scoring_methodology_lines({}, None)))
        with_pack = "\n".join(sl._scoring_methodology_lines(comp, PACK))
        self.assertIn("| Market | Chart |", with_pack)
        self.assertEqual(with_pack.count("| 3A Positioning |"), 4)
        self.assertIn("3A Positioning | X |", with_pack)
        self.assertIn("| sdlc-plugins | 3B Magic Quadrant | Y |", with_pack)

    def test_buying_guidance(self):
        g = lambda **kw: "\n".join(sl._buying_guidance_lines(known={}, support={}, **kw))  # noqa: E731
        base = g(audit=None)
        self.assertIn("Lean startup / spec-first packs", base)
        self.assertIn("Gsd, Bmad, Superpowers, Spec Kit, Ruflo, Zuvo", base)
        peers = [f"p{i:02d}" for i in range(14)]
        audit = {"markets": {"sdlc-plugins": {"core": ["silver-bullet", *peers, "zuvo"]},
                             "apo": {"core": ["silver-bullet", "ai-dlc"]},
                             "agentic-sdlc-saas": {"core": ["devin"]}}}
        text = g(audit=audit)
        self.assertIn("Zuvo, P00", text)  # zuvo promoted to the head of the shortlist
        self.assertIn("Ai Dlc", text)
        self.assertIn("Devin", text)
        near = {"markets": {"sdlc-plugins": {"core": ["zuvo", "a"]}}}
        self.assertIn("Zuvo, A", g(audit=near))


class ReportTests(TmpCase):
    ENV = [{"phase_id": "DR-RETRIEVE", "logical_model_id": "gemini-x", "payload": {"evidence": [
        {"claim": "Silver Bullet provides process orchestration above coding agents."}]}},
        {"phase_id": "DR-RETRIEVE", "logical_model_id": "claude-y", "payload": {}}]

    def comparison(self):
        return {"winner": "silver-bullet",
                "rankings": [{"solution": "silver-bullet", "score": 25}, "junk", {"solution": "ai-dlc", "score": 12},
                             {"solution": "devin", "score": 3}],
                "rows": [{"type": "feature", "name": "Workflow composition",
                          "solutions": {"silver-bullet": True, "ai-dlc": True, "devin": False}},
                         {"type": "feature", "name": "Hook-enforced gates", "priority": "Critical",
                          "solutions": {"silver-bullet": True}}]}

    def report(self, need=None, comparison=None, envelopes=None, consolidation=None, **kw):
        return sl.build_report_markdown(
            category="Cat", platform_list="p", scope_text=kw.pop("scope_text", "# Scope\nbody"),
            need=need or {}, comparison=comparison or self.comparison(),
            consolidation=consolidation or {"consensus": [{"text": "agreed"}, {"text": ""}, "junk"],
                                            "divergence": []},
            envelopes=self.ENV if envelopes is None else envelopes, claims=["Silver Bullet claim", "", "[lean-ctx: x]"],
            root=self.root, report_date="July 19, 2026")

    def test_legacy_report_without_pack(self):
        md = self.report()
        self.assertIn("# Cat Market Landscape Report", md)
        self.assertIn("**Scope**", md)  # demoted scope H1
        self.assertIn("### 3A. Cat Positioning Matrix", md)
        self.assertIn("### 3B. Magic Quadrant — Cat", md)
        self.assertIn("### 3C. Wave-Style Assessment", md)
        self.assertIn("Silver Bullet](https://sb.alolabs.dev/) | Leaders | Positioned on", md)
        self.assertIn("Devin](https://devin.ai/) (Cognition) | Emerging | Emerging | Emerging |", md)
        self.assertIn("### 3D. Blue Ocean Value Curve", md)
        self.assertIn("### Top Commercial Solutions for SMBs", md)
        self.assertIn("### Top Open Source Solutions", md)
        self.assertIn("No cross-family consensus claims", md)
        self.assertIn("| gemini-x |", md)
        self.assertIn("**Heavy—Primary**", md)
        self.assertIn("| claude-y |", md)
        self.assertIn("**Good—Secondary**", md)
        self.assertNotIn("Adjacent Markets (not core peers)", md)
        self.assertNotIn("lean-ctx", md)

    def test_legacy_report_empty_scope_and_no_vc_labels(self):
        md = self.report(scope_text="")
        self.assertIn("covers solutions operating one level above coding agents", md)
        empty_chart = {"mq_data": [], "gmq_data": [], "wave_data": [], "vc_commercial": [], "vc_oss": [],
                       "vc_kcfs": [], "link_pairs": [], "chart_notes": []}
        with mock.patch.object(sl, "build_chart_data", return_value=empty_chart):
            md = self.report()
        self.assertIn("### 3D. Blue Ocean Value Curve", md)
        header = next(line for line in md.splitlines() if line.startswith("| Key Competitive Factor |"))
        for entry in (sl.COMMERCIAL_CATALOG + sl.OSS_CATALOG)[:5]:
            self.assertIn(entry.get("name", entry["slug"]).split(" (")[0], header)

    def test_legacy_wave_rows_from_rankings(self):
        chart = {"mq_data": [], "gmq_data": [{"label": "G", "q": "Leaders"}], "wave_data": [],
                 "vc_commercial": [{"label": "V", "data": [5]}], "vc_oss": [], "link_pairs": []}
        with mock.patch.object(sl, "build_chart_data", return_value=chart):
            md = self.report()
        self.assertIn("| G | Leaders |", md)
        self.assertIn("| Strong | Strong | Strong |", md)
        self.assertIn("Emerging | Emerging | Emerging |", md)

    def pack_audit(self, **over):
        audit = {"matrix_slugs": ["silver-bullet", "ai-dlc"], "core": ["silver-bullet", "ai-dlc"],
                 "adjacent": ["devin"], "excluded": ["cline", "ai-dlc"], "sunset": ["devika"],
                 "gaps": ["zuvo", "ghost", "in-core", "cored", "sdlc-plugin", "devin"],
                 "by_slug": {"devin": {"reason": "saas adjacent"}, "cline": {"reason": "coding agent"},
                             "devika": {"reason": "sunset"}, "ghost": {"classification": "x"},
                             "in-core": {"canonical_slug": "silver-bullet"}, "cored": {"classification": "core"},
                             "devin2": "junk"},
                 "markets": {"apo": {"core": ["silver-bullet"]}, "bad": "junk"}}
        audit.update(over)
        return audit

    def test_pack_report_sections(self):
        audit = self.pack_audit()
        envs = [{"phase_id": "DR-TRIANGULATE", "logical_model_id": m, "payload": {"evidence": [
            {"claim": "A process layer above the host runtime"}]}} for m in ("claude-a", "gemini-b", "gpt-c")]
        real = sl._resolve_catalogs

        def fake(need, envelopes, audit_arg=None):
            commercial, oss, _a = real(need, envelopes, audit)
            return commercial, oss, audit

        with mock.patch.object(sl, "_resolve_catalogs", side_effect=fake), \
                mock.patch("solution_classifier.write_catalog_audit") as wca, \
                mock.patch.object(sl, "patch_inclusion_ledger") as pil:
            md = self.report(need=APO_NEED, envelopes=envs)
        wca.assert_called_once()
        pil.assert_called_once()
        self.assertIn("### Adjacent Markets (not core peers)", md)
        self.assertIn("(`devin`) — saas adjacent", md)
        self.assertIn("### Explicitly Excluded", md)
        self.assertIn("- **Cline** — coding agent", md)
        self.assertNotIn("- **Ai Dlc** — excluded", md)  # in the matrix: not listed as excluded
        self.assertIn("- **Devika** — sunset", md)
        self.assertIn("**Coverage gaps (must-research seeds missing from envelopes)**", md)
        self.assertIn("- ghost (`ghost`)", md)
        self.assertNotIn("`in-core`", md)
        self.assertNotIn("`cored`", md)
        self.assertNotIn("(`zuvo`)", md)
        self.assertNotIn("(`sdlc-plugin`)", md)
        self.assertIn("#### Process layer above host runtimes", md)
        self.assertIn("did **not** reach cross-family agreement", md)
        self.assertIn("## 4. Findings", md)
        self.assertRegex(md, r"### 4\.1 \w+ market:")
        self.assertIn("Positioning Matrix", md)

    def test_pack_report_gap_variants(self):
        real = sl._resolve_catalogs

        def run(audit):
            def fake(need, envelopes, audit_arg=None):
                commercial, oss, _a = real(need, envelopes, audit)
                return commercial, oss, audit
            with mock.patch.object(sl, "_resolve_catalogs", side_effect=fake), \
                    mock.patch("solution_classifier.write_catalog_audit"), \
                    mock.patch.object(sl, "patch_inclusion_ledger"):
                return self.report(need=APO_NEED)

        md = run(self.pack_audit(gaps=["zuvo"], adjacent=[], sunset=[], excluded=[]))
        self.assertNotIn("Coverage gaps", md)
        md = run(self.pack_audit(gaps=[], adjacent=["devin"]))
        self.assertNotIn("Coverage gaps", md)
        md = run(self.pack_audit(by_slug="junk", gaps=["ghost"], adjacent=[], excluded=[], sunset=[]))
        self.assertIn("- ghost (`ghost`)", md)

    def test_multi_market_chart_branches(self):
        chart = {"markets": {
            "m1": {"market_role": "primary", "market_display_name": "One", "chart_notes": ["note one"],
                   "gmq_data": [{"label": "A", "q": "Leaders"}],
                   "wave_data": [{"label": "A", "offering": 3.6, "strategy": 2.6, "presence": 4},
                                 {"label": "B", "offering": 1.6, "strategy": 1.0, "presence": 9},
                                 {"label": "C", "offering": None, "strategy": None, "presence": None}],
                   "vc_commercial": [{"label": "A", "data": [5]}], "vc_oss": [], "vc_kcfs": ["K1", "K2"]},
            "m2": {"market_role": "weird", "gmq_data": [], "wave_data": [], "vc_commercial": [], "vc_oss": [],
                   "vc_kcfs": []}},
            "link_pairs": []}
        with mock.patch.object(sl, "build_multi_market_chart_data", return_value=chart):
            md = self.report(need=APO_NEED)
        self.assertIn("### 4.1 Primary market: One", md)
        self.assertIn("- note one", md)
        self.assertIn("| A | Strong | Good | Strong |", md)
        self.assertIn("| B | Moderate | Emerging | Emerging |", md)
        self.assertIn("| C | Emerging | Emerging | Emerging |", md)
        self.assertIn("| K1 | 5 |", md)
        self.assertIn("| K2 | 1 |", md)
        self.assertIn("### 4.2 Weird market: m2", md)

    def test_final_pass_keeps_notable_divergences(self):
        cons = {"consensus": [], "divergence": [
            {"text": "AI-DLC is the most complete process layer", "supporting_agents": ["a"],
             "model_families": ["f1"]},
            {"text": "AI-DLC is the weakest option and excluded", "supporting_agents": ["b"],
             "model_families": ["f2"]}]}
        md = self.report(consolidation=cons)
        self.assertIn("AI-DLC", md)
        self.assertIn("Consensus Resolution Table", md)


class SynthesizeTests(TmpCase):
    def seed(self, **extra):
        self.put("contributions/all-envelopes.json", ReportTests.ENV)
        self.put("comparison/comparison.json", ReportTests().comparison())
        self.put("need_profile.json", extra.get("need", {"category": "Cat"}))
        self.put("run_manifest.json", {"query": "q"})

    def test_full_run_then_skip(self):
        self.seed()
        self.put("scope.md", "# Scope\nbody")
        res = sl.synthesize_landscape(self.root)
        self.assertEqual(res["status"], "ok")
        self.assertEqual(res["sections"], len(sl.SECTION_TITLES))
        self.assertGreater(res["mq_points"], 0)
        md = (self.root / "landscape/landscape-report.md").read_text()
        self.assertIn("# Cat Market Landscape Report", md)
        chart = json.loads((self.root / "landscape/chart-data.json").read_text())
        self.assertTrue(chart["mq_data"])
        self.assertTrue((self.root / "comparison/comparison-matrix.md").is_file())
        # existing, large artifacts are left alone unless forced
        (self.root / "landscape/landscape-report.md").write_text("x" * 9000)
        skipped = sl.synthesize_landscape(self.root)
        self.assertEqual(skipped["status"], "skipped")
        self.assertEqual((self.root / "landscape/landscape-report.md").read_text(), "x" * 9000)
        forced = sl.synthesize_landscape(self.root, force=True)
        self.assertEqual(forced["status"], "ok")
        (self.root / "landscape/landscape-report.md").write_text("tiny")
        self.assertEqual(sl.synthesize_landscape(self.root)["status"], "ok")

    def test_small_chart_file_is_regenerated(self):
        self.seed()
        self.put("landscape/landscape-report.md", "x" * 9000)
        self.put("landscape/chart-data.json", "{}")
        self.assertEqual(sl.synthesize_landscape(self.root)["status"], "ok")

    def test_skip_charts_and_date_like_category(self):
        self.seed(need={})
        self.put("run_manifest.json", {"query": "2026-07-19 run"})
        res = sl.synthesize_landscape(self.root, skip_charts=True)
        self.assertEqual((res["status"], res["charts"], res["chart_data_bytes"]), ("ok", "skipped", 0))
        md = (self.root / "landscape/landscape-report.md").read_text()
        self.assertIn("# Agentic SDLC Orchestration Market Landscape Report", md)
        self.put("landscape/chart-data.json", "{}")
        res = sl.synthesize_landscape(self.root, skip_charts=True, force=True)
        self.assertEqual(res["chart_data_bytes"], 2)

    def test_missing_comparison_dir_is_not_created(self):
        self.put("need_profile.json", {})
        res = sl.synthesize_landscape(self.root)
        self.assertEqual(res["status"], "ok")
        self.assertFalse((self.root / "comparison").exists())

    def test_pack_run_uses_multi_market_charts(self):
        self.seed(need=APO_NEED)
        res = sl.synthesize_landscape(self.root)
        self.assertEqual(res["status"], "ok")
        chart = json.loads((self.root / "landscape/chart-data.json").read_text())
        self.assertIn("markets", chart)
        self.assertTrue((self.root / "landscape/catalog_audit.json").is_file())


class MainTests(TmpCase):
    def run_main(self, *argv):
        out = io.StringIO()
        with mock.patch.object(sys, "argv", ["synthesize_landscape.py", *argv]), contextlib.redirect_stdout(out):
            code = sl.main()
        return code, json.loads(out.getvalue())

    def test_main(self):
        self.put("need_profile.json", {})
        code, payload = self.run_main("--dir", str(self.root))
        self.assertEqual((code, payload["status"]), (0, "ok"))
        (self.root / "landscape/landscape-report.md").write_text("x" * 9000)
        (self.root / "landscape/chart-data.json").write_text("{" + " " * 300 + "}")
        code, payload = self.run_main("--dir", str(self.root))
        self.assertEqual((code, payload["status"]), (0, "skipped"))
        code, payload = self.run_main("--dir", str(self.root), "--force", "--skip-charts")
        self.assertEqual((code, payload["charts"]), (0, "skipped"))

    def test_main_failure_status(self):
        with mock.patch.object(sl, "synthesize_landscape", return_value={"status": "error"}):
            code, _payload = self.run_main("--dir", str(self.root))
        self.assertEqual(code, 1)

    def test_entry_point(self):
        self.put("need_profile.json", {})
        out = io.StringIO()
        with mock.patch.object(sys, "argv", ["s.py", "--dir", str(self.root)]), \
                contextlib.redirect_stdout(out), self.assertRaises(SystemExit) as cm:
            runpy.run_path(str(SCRIPTS / "synthesize_landscape.py"), run_name="__main__")
        self.assertEqual(cm.exception.code, 0)
        self.assertEqual(json.loads(out.getvalue())["status"], "ok")


if __name__ == "__main__":
    unittest.main()
