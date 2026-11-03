"""Production configuration: no test catalogue fixture, vendors come from the run and its pack.

The module-level vendor lists are empty in production, so every prose parser must resolve vendors
from the run's own set (pack names plus vendors the workers named) -- these tests deliberately do
NOT use legacy_catalog_fixture.
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

import materialize_solution_artifacts as m  # noqa: E402
import solution_classifier as sc  # noqa: E402
from category_pack import build_alias_map, build_known_solutions, resolve_pack_from_need  # noqa: E402
import pack_vocabulary as pv  # noqa: E402

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


if __name__ == "__main__":
    unittest.main()
