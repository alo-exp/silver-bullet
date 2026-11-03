"""Production configuration: no test catalogue fixture, vendors come from the run and its pack.

The module-level vendor lists are empty in production, so every prose parser must resolve vendors
from the run's own set (pack names plus vendors the workers named) -- these tests deliberately do
NOT use apo_pack_run_fixture (except the one class that proves the fixture is the production context).
"""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

import materialize_solution_artifacts as m  # noqa: E402
import solution_classifier as sc  # noqa: E402
from category_pack import build_alias_map, build_known_solutions, resolve_pack_from_need  # noqa: E402
import pack_vocabulary as pv  # noqa: E402
from apo_pack_run_fixture import with_apo_pack_run  # noqa: E402

PACK_ID = "agentic-sdlc-process-orchestrator"
NEED = {"category_pack_id": PACK_ID}


def envs(*claims, rows=()):
    out = [{"logical_model_id": "m1", "phase_id": "DR-RETRIEVE", "payload": {"evidence": [{"claim": c} for c in claims]}}]
    if rows:
        out.append({"logical_model_id": "m2", "phase_id": "DR-RETRIEVE", "payload": {"matrix_entries": list(rows)}})
    return out


class ProseParsersUseTheRunsVendorsTests(unittest.TestCase):
    def test_module_lists_are_empty_in_production(self) -> None:
        self.assertEqual((m.KNOWN_SOLUTIONS, m.SLUG_ALIASES, m._HEAD_SLUG_ALIASES, m.FEATURE_TEMPLATE), ({}, {}, {}, []))

    def test_pack_run_prose_claims_tick_cells(self) -> None:
        pack = resolve_pack_from_need(NEED)
        known = m._effective_known_solutions(NEED)
        got = m.parse_feature_support(
            envs("Devin provides SSO and audit logs.", "Factory.ai lacks SSO, while Devin offers managed hosting."),
            known=known, pack=pack)
        self.assertIs(got["devin"]["SSO"], True)
        self.assertIs(got["devin"]["Audit log"], True)
        self.assertIs(got["devin"]["Managed hosting"], True)
        self.assertIs(got["factory-ai"]["SSO"], False)

    def test_open_world_run_prose_resolves_discovered_vendors_without_a_rubric(self) -> None:
        rows = [{"vendor": "Redpanda", "feature": "Tiered storage", "supported": True}]
        known = m.open_world_known(envs(rows=rows), {})
        self.assertEqual(known, {"redpanda": "Redpanda"})
        # the vendor is found by the prose parsers via the run set; with no pack there is no rubric
        # to tick, so prose adds nothing and the structured row decides
        got = m.parse_feature_support(envs("Redpanda provides tiered storage.", rows=rows), known=known)
        self.assertEqual({k: dict(v) for k, v in got.items()}, {"redpanda": {"Tiered storage": True}})
        self.assertEqual(m._RUN, {"known": None, "pack": None})  # the run context is restored

    def test_run_context_is_used_by_the_helpers_and_restored_on_error(self) -> None:
        with self.assertRaises(RuntimeError):
            previous = dict(m._RUN)
            m._RUN["known"] = {"acme": "Acme"}
            try:
                self.assertEqual(m._primary_slug_in_text("Acme provides SSO"), "acme")
                raise RuntimeError("x")
            finally:
                m._RUN.update(previous)
        self.assertIsNone(m._primary_slug_in_text("Acme provides SSO"))

        def boom(*a, **k):
            raise RuntimeError("boom")

        original = m._parse_prose_unscoped
        m._parse_prose_unscoped = boom
        try:
            with self.assertRaises(RuntimeError):
                m._parse_prose_feature_support([], known={"acme": "Acme"})
        finally:
            m._parse_prose_unscoped = original
        self.assertEqual(m._RUN, {"known": None, "pack": None})


class ApoPackPipelineWithoutFixtureTests(unittest.TestCase):
    """materialize_solution_artifacts on an APO run directory: the real activation path."""

    CLAIMS = (
        "Matrix entry \u2014 Workflow composition (Critical): \u2714 silver-bullet, factory-ai; \u2716 devin, openhands.",
        "Matrix entry \u2014 Hook-enforced gates: \u2714 silver-bullet only among evaluated set.",
        "Devin provides SSO. Factory.ai lacks hook-enforced gates, while Devin offers managed hosting.",
        "Silver Bullet composes workflows with hook-enforced gates.",
    )

    def test_worker_feature_names_map_to_the_pack_rubric_and_aliases(self) -> None:
        with pv.activated(resolve_pack_from_need(NEED)):
            self.assertEqual(m._feature_name("hook ENFORCED gates"), "Hook-enforced gates")  # rubric spelling
            self.assertEqual(m._feature_name("Verification Gates"), "Hook-enforced gates")  # pack alias
            self.assertEqual(m._feature_name("Something Else"), "Something Else")  # run-synthesized

    def test_pack_run_directory(self) -> None:
        import json
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "contributions").mkdir()
            (root / "contributions" / "all-envelopes.json").write_text(json.dumps(envs(*self.CLAIMS)), encoding="utf-8")
            (root / "need_profile.json").write_text(json.dumps({"category": "APO", "category_pack_id": PACK_ID}), encoding="utf-8")
            result = m.materialize_solution_artifacts(root)
            self.assertGreaterEqual(result["solutions_count"], 2)
            self.assertEqual((m.KNOWN_SOLUTIONS, m.FEATURE_TEMPLATE), ({}, []))  # restored after the run
            devin = json.loads((root / "solutions" / "devin" / "features.json").read_text(encoding="utf-8"))
            cells = {f["name"]: f["supported"] for c in devin["categories"] for f in c["features"]}
            self.assertIs(cells["SSO"], True)
            self.assertIs(cells["Managed hosting"], True)
            self.assertIsNot(cells.get("Workflow composition"), True)


class AmbiguousNamesTests(unittest.TestCase):
    """Ordinary phrases that contain a product name are not vendor evidence (R12-08)."""

    PHRASES = (
        "We rely on the director of engineering.",
        "A software factory pattern.",
        "Cursor-based pagination matters.",
        "Continue to monitor results.",
        "Linear scaling is expected.",
        "The conductor of the orchestra.",
        "Sweep the floor.",
    )

    def setUp(self) -> None:
        self.pack = resolve_pack_from_need(NEED)
        self.known = build_known_solutions(self.pack)
        self.aliases = build_alias_map(self.pack)
        ctx = pv.activated(self.pack)
        ctx.__enter__()
        self.addCleanup(ctx.__exit__, None, None, None)

    def test_ordinary_phrases_are_not_vendors_in_materialize_or_the_classifier(self) -> None:
        for phrase in self.PHRASES:
            self.assertEqual(m._extract_slugs_from_text(phrase, self.known, self.pack), [], phrase)
            self.assertEqual(sc._extract_candidates_from_text(phrase, self.aliases, self.known), [], phrase)

    def test_the_same_names_count_next_to_a_product_cue(self) -> None:
        cases = {
            "Cursor IDE background agents run in the cloud.": "cursor",
            "Compared by Factory against rivals.": "factory",
            "Linear (the issue tracker) integrates.": "linear",
            "Visit continue.dev for details, says Continue.dev docs": "continue",
        }
        for text, needle in cases.items():
            found = m._extract_slugs_from_text(text, self.known, self.pack) + sc._extract_candidates_from_text(text, self.aliases, self.known)
            self.assertTrue(any(needle in slug for slug in found), (text, found))
        self.assertTrue(m.mentions_vendor("Cursor IDE", "cursor ide", "cursor"))
        self.assertFalse(m.mentions_vendor("cursor IDE", "cursor ide", "cursor"))  # not a proper noun
        self.assertTrue(m.mentions_vendor("Devin is here", "devin is here", "devin"))  # unambiguous names need no cue


@with_apo_pack_run
class TheSharedFixtureIsTheProductionRunContextTests(unittest.TestCase):
    """The tests that use @with_apo_pack_run run in what a real pack run installs, and nothing more."""

    def test_the_context_is_the_one_a_pack_run_builds(self) -> None:
        pack = resolve_pack_from_need(NEED)
        self.assertEqual(m._RUN["known"], m._effective_known_solutions(NEED))
        self.assertEqual(m._RUN["pack"], pack)
        with pv.activated(pack):  # re-entering the same activation changes nothing
            self.assertTrue(m.AMBIGUOUS_NAMES and m.HOST_RUNTIME_SLUGS)
        # no module-level vendor list is patched in: they stay as empty as in production
        import synthesize_landscape as sl

        self.assertEqual((m.KNOWN_SOLUTIONS, m.SLUG_ALIASES, m.OVERVIEW_SEEDS, sl.OVERVIEW_SEEDS), ({}, {}, {}, {}))
        self.assertFalse(any(hasattr(sl, name) for name in ("COMMERCIAL_CATALOG", "OSS_CATALOG", "EMERGING_CATALOG")))

    def test_the_context_is_restored_after_each_test(self) -> None:
        self.assertIsNotNone(m._RUN["pack"])


class ContextIsRestoredTests(unittest.TestCase):
    def test_outside_the_fixture_no_run_is_active(self) -> None:
        self.assertEqual(m._RUN, {"known": None, "pack": None})
        self.assertEqual((m.AMBIGUOUS_NAMES, m.HOST_RUNTIME_SLUGS), (frozenset(), frozenset()))


class ProperReferencesToCommonWordVendorsTests(unittest.TestCase):
    """R12-08 round 3: a capitalised name inside a sentence or list, or opening one as a subject, is the vendor."""

    REAL_SENTENCES = (
        ("director", "Director is a primary-market APO candidate: agent orchestration, workflow composition."),
        ("director", "Conductor, cc10x, Director, Claude Harness and AgentHub are community packs."),
        ("director", "Director orchestrates parallel Claude Code agents with hook-enforced gates."),
        ("director", "Director's README documents hook-enforced gates."),
        ("director", "**Director** ships hooks."),
        ("factory-ai", "Factory provides SSO and audit logs."),
        ("cursor", "BMAD installs into Claude Code and Cursor via a single command."),
    )
    STILL_PLAIN_ENGLISH = (
        "The Director of Engineering approved it.",
        "Cursor-based pagination matters.",
        "Continue to monitor results.",
        "Linear scaling is expected.",
        "Factory settings are restored.",
        "Sweep the floor.",
        "Notes.\nLinear regression fits.",
    )

    def setUp(self) -> None:
        self.pack = resolve_pack_from_need(NEED)
        self.known = build_known_solutions(self.pack)
        self.aliases = build_alias_map(self.pack)
        ctx = pv.activated(self.pack)
        ctx.__enter__()
        self.addCleanup(ctx.__exit__, None, None, None)

    def test_real_run_sentences_are_vendor_evidence(self) -> None:
        for slug, text in self.REAL_SENTENCES:
            self.assertIn(slug, sc._envelope_evidence_slugs(envs(text), self.pack), text)
            self.assertIn(slug, m._extract_slugs_from_text(text, self.known, self.pack), text)

    def test_plain_english_uses_stay_out(self) -> None:
        for text in self.STILL_PLAIN_ENGLISH:
            found = sc._envelope_evidence_slugs(envs(text), self.pack)
            self.assertFalse(found & {"director", "factory-ai", "cursor", "linear", "sweep", "continue"}, (text, found))

    def test_a_directors_core_seed_with_prose_evidence_stays_core(self) -> None:
        got = sc.classify_solutions(envs("Director is a primary-market APO candidate."), NEED, self.pack)
        self.assertEqual(got["by_slug"]["director"]["classification"], "core")

    def test_structured_matrix_vendor_is_envelope_evidence(self) -> None:
        rows = [{"vendor": "Cursor", "feature": "SSO", "supported": True}, {"vendor": "Nobody Known", "feature": "SSO", "supported": True}]
        found = sc._envelope_evidence_slugs(envs(rows=rows), self.pack)
        self.assertIn("cursor", found)  # exact vendor name from a structured row, no prose needed
        self.assertNotIn("nobody-known", found)  # a pack run ignores vendors it does not know

    def test_a_category_word_alias_is_not_a_vendor(self) -> None:
        text = "Devin automates the SDLC end to end. Agentic SDLC tools need audit logs."
        self.assertNotIn("zuvo", sc._envelope_evidence_slugs(envs(text), self.pack))
        self.assertNotIn("zuvo", m._extract_slugs_from_text(text, self.known, self.pack))
        support = m.parse_feature_support(envs(text), known=self.known, pack=self.pack)
        self.assertNotIn("sdlc", support)
        self.assertNotIn("zuvo", support)
        got = sc.classify_solutions(envs(text), NEED, self.pack)
        self.assertNotIn("zuvo", got["core"])
        self.assertTrue(m.mentions_vendor("Zuvo helps", "zuvo helps", "zuvo"))

    def test_one_product_is_one_slug(self) -> None:
        found = m._extract_slugs_from_text("Silver Bullet and github copilot with cline", self.known, self.pack)
        self.assertEqual(found, ["silver-bullet", "github-copilot", "cline", "github-copilot-workspace"])


def cell_names(support, slug):
    return list(support[slug])


class FeatureFoldingAcrossProseAndStructuredCellsTests(unittest.TestCase):
    """R12-06 round 3: one row per feature, whichever way a worker spelled or reported it."""

    def pack_run(self, must_haves, *envelopes):
        pack = resolve_pack_from_need(NEED)
        known = m._effective_known_solutions(NEED)
        return m.parse_feature_support(list(envelopes), known=known, pack=pack, preferred_features=must_haves)

    def test_rubric_prose_and_structured_votes_on_a_lower_case_must_have_are_one_row(self) -> None:
        got = self.pack_run(
            ["workflow composition"],
            {"logical_model_id": "a", "phase_id": "DR-RETRIEVE", "payload": {"evidence": [{"claim": "Devin lacks workflow composition."}]}},
            {"logical_model_id": "b", "phase_id": "DR-RETRIEVE", "payload": {"evidence": [{"claim": "Devin lacks workflow composition."}]}},
            {"logical_model_id": "c", "phase_id": "DR-TRIANGULATE", "payload": {"matrix_entries": [
                {"vendor": "Devin", "feature": "Workflow composition", "supported": True}]}})
        self.assertEqual(cell_names(got, "devin"), ["Workflow composition"])  # rubric spelling: it matches the must-have case-insensitively
        self.assertIs(got["devin"]["Workflow composition"], True)  # a cell any worker voted on is decided by those votes
        self.assertEqual(m.disputed_cells(got), [])

    def test_prose_only_votes_on_a_differently_cased_must_have_are_one_row_and_vote_together(self) -> None:
        got = self.pack_run(
            ["workflow composition"],
            {"logical_model_id": "a", "phase_id": "DR-RETRIEVE", "payload": {"evidence": [{"claim": "Devin lacks workflow composition."}]}},
            {"logical_model_id": "b", "phase_id": "DR-RETRIEVE", "payload": {"evidence": [{"claim": "Devin provides workflow composition."}]}},
            {"logical_model_id": "c", "phase_id": "DR-RETRIEVE", "payload": {"evidence": [{"claim": "Devin lacks workflow composition."}]}})
        self.assertEqual(cell_names(got, "devin"), ["Workflow composition"])
        self.assertIs(got["devin"]["Workflow composition"], False)  # 2 no, 1 yes
        self.assertEqual(m.disputed_cells(got), [{"vendor": "devin", "feature": "Workflow composition", "yes": 1, "no": 2}])

    def test_a_must_have_worded_differently_from_the_rubric_keeps_the_users_wording(self) -> None:
        got = self.pack_run(
            ["Hook enforced gates!"],
            {"logical_model_id": "c", "phase_id": "DR-TRIANGULATE", "payload": {"matrix_entries": [
                {"vendor": "Devin", "feature": "hook-enforced gates", "supported": True}]}})
        self.assertEqual(cell_names(got, "devin"), ["Hook enforced gates!"])  # the comparator matches priorities on this spelling

    def test_open_world_matrix_prose_merges_with_structured_rows(self) -> None:
        rows = [{"vendor": "Redpanda", "feature": "Tiered storage", "supported": True},
                {"vendor": "Apache Pulsar", "feature": "Tiered storage", "supported": True}]
        envelopes = envs("Matrix — tiered storage: Apache Pulsar, Redpanda but Apache Kafka does not", rows=rows)
        known = m.open_world_known(envelopes, {})
        got = m.parse_feature_support(envelopes, known=known)
        for slug in ("redpanda", "apache-pulsar"):
            self.assertEqual(len(got[slug]), 1, got[slug])
            self.assertIs(next(iter(got[slug].values())), True)

    def test_symbols_are_part_of_a_feature_name(self) -> None:
        self.assertEqual(len({m._feature_key(n) for n in ("C++ support", "C# support", "C support")}), 3)
        self.assertEqual(m._feature_key("Hook-enforced  gates"), m._feature_key("hook enforced Gates!"))
        rows = lambda model, cpp, sharp: {"logical_model_id": model, "phase_id": "DR-TRIANGULATE", "payload": {"matrix_entries": [
            {"vendor": "Coverity", "feature": "C++ support", "supported": cpp},
            {"vendor": "Coverity", "feature": "C# support", "supported": sharp},
            {"vendor": "PVS-Studio", "feature": "C# support", "supported": True}]}}
        got = m.parse_feature_support([rows("a", True, False), rows("b", True, False), rows("c", True, False)], known={})
        self.assertEqual(got["coverity"], {"C++ support": True, "C# support": False})
        self.assertEqual(got["pvs-studio"], {"C# support": True})


class HardWiredApoFeaturesStayOutOfOtherCategoriesTests(unittest.TestCase):
    def test_must_have_satisfaction_phrase_adds_no_apo_rows_without_a_pack(self) -> None:
        rows = [{"vendor": "Redpanda", "feature": "Tiered storage", "supported": True}]
        envelopes = envs("Redpanda is the pick satisfying all three matrix must-haves for the startup.", rows=rows)
        got = m.parse_feature_support(envelopes, known=m.open_world_known(envelopes, {}))
        self.assertEqual({k: dict(v) for k, v in got.items()}, {"redpanda": {"Tiered storage": True}})

    def test_the_pack_rubric_still_applies_the_phrase(self) -> None:
        pack = resolve_pack_from_need(NEED)
        got = m.parse_feature_support(
            envs("Devin is the pick satisfying all three matrix must-haves for the startup."),
            known=m._effective_known_solutions(NEED), pack=pack)
        self.assertEqual(
            {name for name, ok in got["devin"].items() if ok},
            {"Workflow composition", "Parent/child agent delegation", "Hook-enforced gates"})


class ReportWordingTests(unittest.TestCase):
    def test_no_pack_report_claims_neither_startup_weighting_nor_leader_caps(self) -> None:
        import synthesize_landscape as sl

        text = "\n".join(sl._scoring_methodology_lines({"rows": [], "rankings": []}, None))
        self.assertNotIn("Leader eligibility (below) can lower", text)
        self.assertIn("no rule lowers an axis", text)
        profile = sl._build_solution_profile(
            {"slug": "x", "name": "X", "unclassified": True}, commercial=True, root=Path("/nonexistent"), claims=[],
            support={"x": {"SSO": True}}, known={"x": "X"}, overview_seeds={})
        self.assertNotIn("startup", json.dumps(profile).lower())

    def test_the_pack_keeps_its_leader_caps_sentence(self) -> None:
        import synthesize_landscape as sl

        pack = resolve_pack_from_need(NEED)
        with pv.activated(pack):
            text = "\n".join(sl._scoring_methodology_lines({"rows": [], "rankings": []}, pack))
        self.assertNotIn("no rule lowers an axis", text)
        self.assertNotIn("startup", text.lower().replace("startups", ""))


class NoPackDefaultsCarryNoCategoryRulesTests(unittest.TestCase):
    """Without a category pack no APO/SDLC rule, bonus, cap or link-label list applies (R12-22)."""

    def test_defaults(self) -> None:
        import synthesize_landscape as sl
        import vendor_link_labels as vll

        self.assertEqual((sl.SOLO_HOST_MARKER, sl.PRESENCE_REQUIRES_FEATURE, sl.KCF_FALLBACK_EXCLUDE), ("", "", ()))
        self.assertEqual((vll.EXTRA_BLOCKED_LABELS, vll.ALLOWED_SHORT_ACRONYM_LABELS, vll.SLUG_LINK_LABEL_OVERRIDES),
                         (frozenset(), frozenset(), {}))
        # a lone "Claude" mention earns no host bonus, and presence is not capped for a missing feature
        self.assertEqual(sl._scr_strategy_bonus("Works with Claude."), 0.0)
        self.assertFalse(vll.is_generic_link_label("Factory"))
        self.assertTrue(vll.is_generic_link_label("SDLC"))
        text = "\n".join(sl._scoring_methodology_lines({"rows": [], "rankings": []}, None))
        for banned in ("methodology-without-gates", "Zero-infra", "multi-host", "Managed hosting", "inclusion", "hard-exclusion"):
            self.assertNotIn(banned, text)

    def test_the_pack_turns_them_on(self) -> None:
        import synthesize_landscape as sl
        import vendor_link_labels as vll

        pack = resolve_pack_from_need(NEED)
        with pv.activated(pack):
            self.assertEqual(sl._scr_strategy_bonus("Works with Claude."), 0.10)
            self.assertTrue(vll.is_generic_link_label("Factory"))
            self.assertFalse(vll.is_generic_link_label("BMAD"))
            text = "\n".join(sl._scoring_methodology_lines({"rows": [], "rankings": []}, pack))
        for needed in ("methodology-without-gates", "Zero-infra", "multi-host", "cap 3 without Managed hosting", "hard-exclusion"):
            self.assertIn(needed, text)


if __name__ == "__main__":
    unittest.main()
