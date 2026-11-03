"""Offline unit tests for materialize_solution_artifacts (claim parsers, rubric, artifact writers)."""

from __future__ import annotations

import contextlib
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

import category_pack as cp  # noqa: E402
import materialize_solution_artifacts as m  # noqa: E402

PACK = {
    "category_id": "demo",
    "markets": [{"id": "x", "seeds": [{"slug": "zeta-tool", "name": "Zeta Tool"}, {"slug": "omega", "name": "Omega"}]}],
    "product_aliases": {"zt": "zeta-tool"},
}
KNOWN_WITH_PACK = {**m._known_or_run(None), **cp.build_known_solutions(PACK)}


def support_of(func, *args, **kwargs) -> dict:
    support: dict = {}
    func(support, *args, **kwargs)
    return support


def env(*claims: str) -> list[dict]:
    return [{"payload": {"evidence": [{"claim": c} for c in claims]}}]


from legacy_catalog_fixture import with_legacy_catalogs  # noqa: E402


@with_legacy_catalogs
class ClaimClassificationTests(unittest.TestCase):
    def test_matrix_dump_claims(self) -> None:
        for text in ("", "   ", "startup-weighted matrix stuff", "foo maps to must_have bar", "x maps to must-have",
                     "A ✔ for devin, aider", "they scored 90, 80, 70 overall"):
            with self.subTest(text=text):
                self.assertTrue(m.is_matrix_dump_claim(text))
        for text in ("Devin offers sso.", "A ✔ for devin", "scored 90 one", "clean claim"):
            with self.subTest(text=text):
                self.assertFalse(m.is_matrix_dump_claim(text))
        self.assertTrue(m.is_matrix_dump_claim(None))  # type: ignore[arg-type]

    def test_unusable_overview_claims(self) -> None:
        self.assertFalse(m.is_unusable_overview_claim("A perfectly fine product description."))
        self.assertTrue(m.is_unusable_overview_claim(""))
        self.assertTrue(m.is_unusable_overview_claim("startup-weighted matrix dump"))
        self.assertTrue(m.is_unusable_overview_claim("a triangulation note"))
        self.assertTrue(m.is_unusable_overview_claim("x" * 421))
        self.assertTrue(m.is_unusable_overview_claim("uses superpowers inside", focus_name="Director Mode"))
        self.assertFalse(m.is_unusable_overview_claim("uses superpowers inside", focus_name="Other"))
        for text in ("a startup-weighted comparison", "silver bullet is the anchor", "methodology and score"):
            self.assertTrue(m.is_unusable_overview_claim(text, focus_name="cc10x"), text)
        self.assertFalse(m.is_unusable_overview_claim("cc10x plain", focus_name="cc10x"))
        # a claim that lists three other products is a landscape note
        crowd = "Aider, Cline, Continue and OpenHands are alternatives"
        self.assertTrue(m.is_unusable_overview_claim(crowd))
        self.assertFalse(m.is_unusable_overview_claim("Aider and Cline only"))
        # the focus product itself is not counted among the others
        self.assertTrue(m.is_unusable_overview_claim(crowd, focus_name="Aider"))  # three other products remain
        self.assertFalse(m.is_unusable_overview_claim("Aider, Cline, Continue", focus_name="aider"))


@with_legacy_catalogs
class SlugTests(unittest.TestCase):
    def test_slugify_and_normalize(self) -> None:
        self.assertEqual(m._slugify(" Foo & Bar! "), "foo-bar")
        self.assertIsNone(m._normalize_slug(""))
        self.assertIsNone(m._normalize_slug(" `` "))
        self.assertEqual(m._normalize_slug(" `Devin` "), "devin")
        self.assertIsNone(m._normalize_slug("sb"))  # a bare initialism is not a vendor alias
        self.assertEqual(m._normalize_slug("silver  bullet"), "silver-bullet")
        self.assertEqual(m._normalize_slug("Open-Hands"), "openhands")
        self.assertEqual(m._normalize_slug("Cline"), "cline")
        self.assertIsNone(m._normalize_slug("zzz"))
        self.assertEqual(m._normalize_slug("zt", KNOWN_WITH_PACK, PACK), "zt")
        # the pack resolver maps unknown tokens through its aliases
        self.assertEqual(m._normalize_slug("Zeta Tool", {"zeta-tool": "Zeta"}, PACK), "zeta-tool")
        self.assertEqual(m._normalize_slug("totally unknown", KNOWN_WITH_PACK, PACK), "totally-unknown")

    def test_blank_quoted_token_is_not_a_slug(self) -> None:
        self.assertIsNone(m._normalize_slug("' '", {}, PACK))

    def test_effective_overview_seeds_and_known_solutions(self) -> None:
        with mock.patch.object(m, "resolve_pack_from_need", return_value=None):
            self.assertEqual(m._effective_overview_seeds(), m.OVERVIEW_SEEDS)
            self.assertIsNot(m._effective_overview_seeds(), m.OVERVIEW_SEEDS)
            self.assertEqual(m._effective_known_solutions(), m._known_or_run(None))
        pack = {**PACK, "overview_seeds": {"zeta-tool": "Zeta overview", "devin": "Overridden"}}
        with mock.patch.object(m, "resolve_pack_from_need", return_value=pack):
            seeds = m._effective_overview_seeds({"category_pack_id": "demo"})
            known = m._effective_known_solutions({"category_pack_id": "demo"})
        self.assertEqual(seeds["zeta-tool"], "Zeta overview")
        self.assertEqual(seeds["devin"], "Overridden")
        self.assertEqual(seeds["factory-ai"], m.OVERVIEW_SEEDS["factory-ai"])
        self.assertNotIn("silver-bullet", seeds)
        self.assertEqual(known["zeta-tool"], "Zeta Tool")
        self.assertIn("devin", known)  # the run context supplies the pack names
        self.assertEqual(m.OVERVIEW_SEEDS["devin"], m._effective_overview_seeds() ["devin"])

    def test_extract_slugs_from_text(self) -> None:
        self.assertEqual(m._extract_slugs_from_text("Silver Bullet and github copilot with cline"),
                         ["silver-bullet", "cline", "github-copilot-workspace"])
        self.assertEqual(m._extract_slugs_from_text("nothing here"), [])
        self.assertEqual(m._extract_slugs_from_text("zt rocks and omega", KNOWN_WITH_PACK, PACK), ["omega", "zt", "zeta-tool"])

    def test_resolve_features(self) -> None:
        self.assertEqual(m._resolve_features("Hook-enforced gates and ci/cd"), ["Hook-enforced gates", "CI integration"])
        self.assertEqual(m._resolve_features("Totally unknown"), ["Totally unknown"])
        self.assertEqual(m._resolve_features("  SSO  "), ["SSO"])
        self.assertEqual(m._resolve_features("hook gates"), ["Hook-enforced gates"])

    def test_matrix_entry_head_is_solution(self) -> None:
        yes = ("Devin", "ZetaTool", "Silver Bullet (SB)")
        no = ("", "(only parens)", "x ✔", "Workflow composition", "workflow composition extras", "hook gates x", "something else entirely")
        for head in yes:
            self.assertTrue(m._matrix_entry_head_is_solution(head), head)
        for head in no:
            self.assertFalse(m._matrix_entry_head_is_solution(head), head)
        # a multi-word head that merely mentions a known product still counts as a solution head
        self.assertTrue(m._matrix_entry_head_is_solution("the Devin platform"))
        # a pack-known product name resolves through the pack
        self.assertTrue(m._matrix_entry_head_is_solution("Zeta Tool", KNOWN_WITH_PACK, PACK))

    def test_canonical_known_slug(self) -> None:
        self.assertEqual(m._canonical_known_slug("devin"), "devin")
        self.assertEqual(m._canonical_known_slug("devin-extra"), "devin")
        self.assertEqual(m._canonical_known_slug("dev"), "dev")
        self.assertEqual(m._canonical_known_slug("silver"), "silver-bullet")  # known slug that extends the token
        self.assertEqual(m._canonical_known_slug("sdlc"), "sdlc-plugin")  # candidate "sdlc-plugin" starts with "sdlc-"
        self.assertEqual(m._canonical_known_slug("x", {"x": "X"}), "x")

    def test_resolve_solution_slug(self) -> None:
        r = m._resolve_solution_slug
        self.assertEqual(r("Director Mode (lite)"), "director")
        self.assertEqual(r("director mode lite extras"), "director")
        self.assertEqual(r("AI SDLC Harness"), "claude-harness")
        self.assertEqual(r("Devin (Cognition)"), "devin")
        self.assertEqual(r("aider tool"), "aider")
        self.assertEqual(r("Zetatool"), "zetatool")
        self.assertIsNone(r("Zeta tool"))
        self.assertEqual(r("what about cline here"), "cline")
        self.assertEqual(r("Zeta Tool", KNOWN_WITH_PACK, PACK), "zeta-tool")
        self.assertEqual(r("barkain extras"), "barkain-workflow-orchestrator")
        # a head that only extends a known display name via the alias prefix rule
        self.assertEqual(r("cavekit v3.1 notes"), "cavekit")  # canonicalised onto the known "cavekit" slug
        # a lookup that finds a pack slug through the pack resolver, not the display names
        self.assertEqual(r("zt", KNOWN_WITH_PACK, PACK), "zt")
        self.assertEqual(r("Zeta unknown tool", KNOWN_WITH_PACK, PACK), "zeta-unknown-tool")


@with_legacy_catalogs
class DiscoverTests(unittest.TestCase):
    def test_pack_branch_uses_classifier(self) -> None:
        audit = {"matrix_slugs": ["a", "b", "c"], "core": ["x"]}
        with mock.patch.object(m, "resolve_pack_from_need", return_value=PACK), \
                mock.patch("solution_classifier.classify_solutions", return_value=audit) as classify:
            self.assertEqual(m.discover_solutions(env("c"), need={"category_pack_id": "demo"}), ["a", "b", "c"])
            classify.assert_called_once()
            self.assertEqual(m.discover_solutions(env("c"), min_solutions=9, need={"n": 1}), ["a", "b", "c"])
            audit["matrix_slugs"] = []
            self.assertEqual(m.discover_solutions(env("c"), need={"n": 1}), ["x"])

    def test_pack_branch_falls_back_to_pack_seed_slugs(self) -> None:
        legacy = {"category_id": "legacy", "core_seeds": [{"slug": f"s{i}", "name": f"S{i}"} for i in range(7)]}
        with mock.patch.object(m, "resolve_pack_from_need", return_value=legacy), \
                mock.patch("solution_classifier.classify_solutions", return_value={"matrix_slugs": [], "core": []}):
            slugs = m.discover_solutions(env("nothing"), need={"n": 1})
        self.assertEqual(slugs, ["s0", "s1", "s2", "s3", "s4"])
        self.assertTrue(all(isinstance(s, str) for s in slugs))


    def test_iter_claim_texts(self) -> None:
        envelopes = [
            {"payload": {
                "evidence": [{"claim": "e1"}, {"text": "e2"}, {"claim": ""}, "junk"],
                "claim_candidates": [{"text": "c1"}, {"claim": "c2"}, {"text": ""}, 5],
                "critiques": [{"finding": "f1"}, {"target": "t1"}, {"finding": ""}, None],
                "gaps": [{"description": "d1"}, {"area": "a1"}, {"description": ""}, []],
            }},
            {"payload": None},
            {},
        ]
        self.assertEqual(m._iter_claim_texts(envelopes), ["e1", "e2", "c1", "c2", "f1", "t1", "d1", "a1"])


@with_legacy_catalogs
class ProseInferenceTests(unittest.TestCase):
    def test_explicit_criterion_flags_override_prose(self) -> None:
        body = ("lifecycle_span=yes; deterministic_gates=no; cross_session_state=partial; "
                "specialist_agents=TRUE; plugin_skill_hook_packaging=false; quality_release_enforcement=maybe")
        got = support_of(m._infer_features_from_solution_prose, "devin", body)["devin"]
        self.assertEqual(got["Workflow composition"], True)
        self.assertEqual(got["Atomic flow catalog"], True)
        self.assertEqual(got["Parent/child agent delegation"], True)
        self.assertEqual(got["Hook-enforced gates"], False)
        self.assertEqual(got["Skill/plugin marketplace"], False)
        self.assertEqual(got["IDE-native integration"], False)
        self.assertNotIn("Automated review loops", got)  # "maybe" is not a recognised value
        # partial leaves earlier support untouched
        self.assertEqual(len(got), 6)

    def test_signal_patterns(self) -> None:
        body = ("An open source workflow tool with hooks and CI/CD and plugin marketplace and verification "
                "and multi-agent roles, quick setup, prebuilt templates and managed hosting")
        got = support_of(m._infer_features_from_solution_prose, "devin", body)["devin"]
        for feature in ("Workflow composition", "Hook-enforced gates", "Free tier / OSS core", "CI integration",
                        "Skill/plugin marketplace", "Automated review loops", "Parent/child agent delegation",
                        "Quick onboarding", "Zero-infra bootstrap", "Prebuilt SDLC templates", "Managed hosting"):
            self.assertTrue(got.get(feature), feature)
        self.assertEqual(support_of(m._infer_features_from_solution_prose, "devin", "nothing relevant")  , {})

    def test_assign_support_is_a_majority_vote_not_sticky(self) -> None:
        support: dict = {}
        m._assign_support(support, "a", "F", True)
        self.assertIs(support["a"]["F"], True)
        # one contrary anonymous voter ties 1:1, and a tie is not a tick
        m._assign_support(support, "a", "F", False)
        self.assertIs(support["a"]["F"], False)
        m._assign_support(support, "a", "F", True)
        self.assertIs(support["a"]["F"], True)
        m._assign_support(support, "a", "F", False)
        m._assign_support(support, "a", "F", False)
        self.assertIs(support["a"]["F"], False)

    def test_structured_matrix_entries_decide_their_cells(self) -> None:
        known = {"tembo": "Tembo", "devin": "Devin"}

        def env(model, rows=None, claim=None):
            payload = {}
            if rows is not None:
                payload["matrix_entries"] = rows
            if claim:
                payload["evidence"] = [{"claim": claim}]
            return {"logical_model_id": model, "phase_id": "DR-RETRIEVE", "payload": payload}

        row = lambda v, f, s: {"vendor": v, "feature": f, "supported": s, "source_ref": "u"}  # noqa: E731
        envs = [
            env("m1", [row("Tembo", "SSO", False)]),
            env("m2", [row("tembo", "single sign-on", "no"), row("Tembo", "Audit log", "YES")]),
            env("m3", [row("Tembo", "SSO", True)], claim="Tembo supports SSO and audit logs"),
            env("m4", [row("Tembo", "SSO", "maybe"), row("Nobody", "SSO", True), row("Tembo", "Not a feature", True),
                       row("Tembo", "RBAC", None), "junk"]),
            env("m5", "not-a-list"),
        ]
        self.assertEqual(m.parse_structured_matrix_entries(["not-an-envelope"], known=known), {})
        got = m.parse_feature_support(envs, known=known)
        # two workers say no, one says yes: the structured votes decide, the prose claim cannot tip it
        self.assertIs(got["tembo"]["SSO"], False)
        self.assertIs(got["tembo"]["Audit log"], True)
        self.assertNotIn("RBAC", got["tembo"])
        self.assertIs(got["nobody"]["SSO"], True)  # a vendor only a worker named is still a column
        # a cell nobody voted on still comes from prose
        prose_only = m.parse_feature_support(
            [env("m1", [row("Tembo", "SSO", True)]), env("m2", None, "Devin supports audit logs")], known=known)
        self.assertIs(prose_only["devin"]["Audit log"], True)
        self.assertIs(prose_only["tembo"]["SSO"], True)
        self.assertEqual(m.parse_structured_matrix_entries([], known=known), {})

    def test_clause_without_a_vendor_and_features_without_cues(self) -> None:
        known = {"devin": "Devin", "cline": "Cline"}
        # the first clause names no vendor and does not continue a previous subject: it is skipped
        got = m.parse_feature_support(
            [{"payload": {"evidence": [{"claim": "Devin provides CI integration, while the others do not"}]}}], known=known)
        self.assertIs(got["devin"]["CI integration"], True)
        self.assertEqual(set(got), {"devin"})
        # a feature mentioned next to a vendor without any positive or negative cue earns nothing
        got = m.parse_feature_support([{"payload": {"evidence": [{"claim": "Cline audit log"}]}}], known=known)
        self.assertNotIn("Audit log", got.get("cline", {}))
        # "whereas X and Y offer managed hosting" (no comma) credits both
        support = support_of(m._parse_managed_hosting_offer, "Whereas devin and cline offer managed hosting")
        self.assertTrue(support["devin"]["Managed hosting"])
        self.assertTrue(support["cline"]["Managed hosting"])

    def test_mentions_requires_a_name_and_whole_words(self) -> None:
        self.assertFalse(m._mentions("anything", ""))
        self.assertTrue(m._mentions("see devin.", "devin"))
        self.assertFalse(m._mentions("an sbom", "sb"))

    def test_one_claim_is_one_vote_and_negation_wins_inside_it(self) -> None:
        support: dict = {}
        try:
            m._VOTER[0] = 7
            m._assign_support(support, "a", "F", True)
            m._assign_support(support, "a", "F", True)  # same claim read by two parsers
            m._assign_support(support, "a", "F", False)
            self.assertIs(support["a"]["F"], False)
            m._assign_support(support, "a", "F", True)  # cannot undo the claim's own negation
            self.assertIs(support["a"]["F"], False)
            m._VOTER[0] = 8
            m._assign_support(support, "a", "G", True)
            m._VOTER[0] = 9
            m._assign_support(support, "a", "G", True)
            m._VOTER[0] = 10
            m._assign_support(support, "a", "G", False)
            self.assertIs(support["a"]["G"], True)
        finally:
            m._VOTER[0] = None

    def test_parse_feature_support_negation_and_dissent(self) -> None:
        def env(*texts):
            return [{"payload": {"evidence": [{"claim": x} for x in texts]}}]

        known = {"tembo": "Tembo", "devin": "Devin", "factory-ai": "Factory.ai"}
        many = [*(["Tembo lacks SSO"] * 3), "Tembo supports SSO and audit logs"]
        got = m.parse_feature_support(env(*many), known=known)
        self.assertIs(got["tembo"]["SSO"], False)  # three contrary claims outvote one positive
        self.assertIs(got["tembo"]["Audit log"], True)
        got = m.parse_feature_support(
            env("Devin lacks hook-enforced gates, while Factory.ai provides workflow composition"), known=known)
        self.assertNotIn("Hook-enforced gates", {k for k, v in got.get("factory-ai", {}).items() if v})
        self.assertIs(got["devin"]["Hook-enforced gates"], False)
        got = m.parse_feature_support(
            env("Unlike SB, Devin offers managed hosting and CI integration"), known=known)
        self.assertNotIn("silver-bullet", got)
        self.assertIs(got["devin"]["Managed hosting"], True)

    def test_solution_led_matrix_entry(self) -> None:
        support: dict = {}
        self.assertFalse(m._parse_solution_led_matrix_entry(support, "Workflow composition", "x"))
        self.assertEqual(support, {})
        self.assertTrue(m._parse_solution_led_matrix_entry(support, "Devin", "has hooks and CI/CD"))
        self.assertTrue(support["devin"]["Hook-enforced gates"])
        # head accepted as a solution but unresolvable to a slug -> not handled
        with mock.patch.object(m, "_matrix_entry_head_is_solution", return_value=True), \
                mock.patch.object(m, "_resolve_solution_slug", return_value=None):
            self.assertFalse(m._parse_solution_led_matrix_entry(support, "???", "body"))


@with_legacy_catalogs
class ListParsingTests(unittest.TestCase):
    def test_extract_slugs_from_list(self) -> None:
        self.assertEqual(m._extract_slugs_from_list("Devin, Aider (oss), cline only among peers"), ["devin", "aider", "cline"])
        self.assertEqual(m._extract_slugs_from_list("Director Mode, zzz, BMAD, ✔ devin, devin-agent, , a(i)-team"),
                         ["director", "bmad-method", "devin"])
        self.assertEqual(m._extract_slugs_from_list(""), [])
        self.assertEqual(m._extract_slugs_from_list("a-team; ateam/ AI-team"), ["ateam"])

    def test_checkmark_body_sections(self) -> None:
        pos, neg = m._parse_checkmark_body("✔ devin, aider only extras; ✖ cline; devin ✔ ; aider ✗ x; ; plain")
        self.assertEqual(pos, ["devin", "aider", "devin"])
        self.assertEqual(neg, ["cline", "aider"])
        self.assertEqual(m._parse_checkmark_body("   "), ([], []))
        self.assertEqual(m._parse_checkmark_body("✔ openhands"), (["openhands"], []))

    def test_split_solution_lists_text_forms(self) -> None:
        self.assertEqual(m._split_solution_lists("devin, aider but cline does not, openhands fails"),
                         (["devin", "aider"], ["cline", "openhands", "cline"]))
        self.assertEqual(m._split_solution_lists("devin pass; aider true while cline does not offer; openhands doesn't"),
                         (["devin", "aider"], ["cline", "openhands", "cline"]))
        self.assertEqual(m._split_solution_lists("devin; aider does not"), (["devin"], ["aider", "aider"]))
        self.assertEqual(m._split_solution_lists("✔ devin; ✖ aider"), (["devin"], ["aider"]))
        self.assertEqual(m._split_solution_lists("nobody known here"), ([], []))
        # a negative clause whose subject is not a known product is ignored
        self.assertEqual(m._split_solution_lists("devin but mystery does not"), (["devin"], []))
        self.assertEqual(m._split_solution_lists("devin but zzz fails"), (["devin"], []))

    def test_apply_matrix_row(self) -> None:
        support = support_of(m._apply_matrix_row, "Hook-enforced gates and ci/cd", "devin, aider but cline does not")
        self.assertTrue(support["devin"]["Hook-enforced gates"])
        self.assertTrue(support["aider"]["CI integration"])
        self.assertIs(support["cline"]["Hook-enforced gates"], False)


@with_legacy_catalogs
class ClaimParserTests(unittest.TestCase):
    def test_features_in_text_and_primary_slug(self) -> None:
        self.assertEqual(m._features_in_text("Has hook gates and CI/CD plus audit logs"),
                         ["Audit log", "Hook-enforced gates", "CI integration"])
        self.assertEqual(m._features_in_text("workflow composition"), ["Workflow composition"])
        self.assertEqual(m._features_in_text("nothing"), [])
        self.assertIsNone(m._primary_slug_in_text("SB does things"))
        self.assertEqual(m._primary_slug_in_text("The text mentions devin first"), "devin")
        self.assertIsNone(m._primary_slug_in_text("zzz"))
        self.assertIsNone(m._primary_slug_in_text("x" * 100 + " zzz"))

    def test_comparative_claims(self) -> None:
        support = support_of(m._parse_comparative_claims, "Devin lacks hook gates; while aider and cline offer CI integration.")
        self.assertIs(support["devin"]["Hook-enforced gates"], False)
        self.assertTrue(support["aider"]["CI integration"])
        self.assertTrue(support["cline"]["CI integration"])
        self.assertEqual(support_of(m._parse_comparative_claims, "no signal here"), {})

    def test_prose_claim(self) -> None:
        support = support_of(m._parse_prose_claim, "Devin offers workflow composition, but lacks hook gates")
        self.assertTrue(support["devin"]["Workflow composition"])
        self.assertIs(support["devin"]["Hook-enforced gates"], False)
        support = support_of(m._parse_prose_claim, "Aider ✔ matrix rows: CI integration, Managed hosting.")
        self.assertTrue(support["aider"]["CI integration"])
        self.assertTrue(support["aider"]["Managed hosting"])
        support = support_of(m._parse_prose_claim, "Cline mentions hook gates but trail on audit logs and ✗ managed hosting")
        self.assertIs(support["cline"]["Audit log"], False)
        self.assertEqual(support_of(m._parse_prose_claim, "zzz has hook gates"), {})
        support = support_of(m._parse_prose_claim, "Devin offers ci integration")
        self.assertEqual(support["devin"], {"CI integration": True})

    def test_checkmark_for_and_matrix_dash(self) -> None:
        support: dict = {}
        self.assertFalse(m._parse_checkmark_for_claims(support, "plain text"))
        self.assertTrue(m._parse_checkmark_for_claims(support, "Hook-enforced gates ✔ for devin, aider; ✖ cline"))
        self.assertIs(support["cline"]["Hook-enforced gates"], False)
        self.assertTrue(m._parse_checkmark_for_claims(support, "Hook-enforced gates ✔ for ✔ devin, aider"))
        self.assertTrue(support["devin"]["Hook-enforced gates"])
        support = {}
        self.assertFalse(m._parse_matrix_dash_claims(support, "plain"))
        self.assertTrue(m._parse_matrix_dash_claims(support, "Matrix — CI integration (critical): devin, aider but cline does not"))
        self.assertTrue(support["aider"]["CI integration"])
        self.assertIs(support["cline"]["CI integration"], False)

    def test_must_have_satisfaction(self) -> None:
        self.assertEqual(support_of(m._parse_must_have_satisfaction, "unrelated text"), {})
        self.assertEqual(support_of(m._parse_must_have_satisfaction, "satisfying all three matrix must-haves"), {})
        support = support_of(m._parse_must_have_satisfaction, "Devin, satisfying all three matrix must-haves plus CI execution")
        self.assertEqual(set(support["devin"]), {"Workflow composition", "Parent/child agent delegation", "Hook-enforced gates", "CI integration"})
        no_ci = support_of(m._parse_must_have_satisfaction, "Devin satisfying all three matrix must-haves")
        self.assertNotIn("CI integration", no_ci["devin"])

    def test_has_checkmark_features(self) -> None:
        support = support_of(m._parse_has_checkmark_features, "Devin has ✔ workflow composition and hook gates. Aider also ✔ (managed hosting)")
        self.assertTrue(support["devin"]["Workflow composition"])
        self.assertTrue(support["devin"]["Hook-enforced gates"])
        self.assertTrue(support["aider"]["Managed hosting"])
        support = support_of(m._parse_has_checkmark_features, "Atomic ✔ Workflow catalog here, devin later")
        self.assertTrue(support["devin"]["Atomic flow catalog"] if "devin" in support else False)
        support = support_of(m._parse_has_checkmark_features, "cline also ✔ hook gates are present")
        self.assertTrue(support["cline"]["Hook-enforced gates"])
        # no known product anywhere: nothing is assigned; an also-✔ subject that is not known is skipped
        self.assertEqual(support_of(m._parse_has_checkmark_features, "has ✔ workflow composition"), {})
        self.assertEqual(support_of(m._parse_has_checkmark_features, "zzz also ✔ (hook gates)"), {})

    def test_solution_lead_negative(self) -> None:
        cases = {
            "Devin has no workflow catalog": {("Atomic flow catalog", False), ("Workflow composition", False)},
            "Aider lacks hook enforcement": {("Hook-enforced gates", False)},
            "Cline partial composition": {("Workflow composition", True)},
            "Aider has no catalog or tooling": {("Atomic flow catalog", False)},
            "Aider is an open-source tool": {("Free tier / OSS core", True)},
            "Cline verification gate is limited": {("Hook-enforced gates", False)},
            "Aider limited multi-agent support": {("Parent/child agent delegation", False)},
            "Cline runs ci/cd pipelines": {("CI integration", True)},
            "Aider multi-agent workflows": {("Parent/child agent delegation", True)},
        }
        for text, expected in cases.items():
            with self.subTest(text=text):
                support = support_of(m._parse_solution_lead_negative, text)
                got = {(f, v) for feats in support.values() for f, v in feats.items()}
                self.assertTrue(expected <= got, (text, got))
        self.assertEqual(support_of(m._parse_solution_lead_negative, "Aider has no multi-agent workflows"), {})
        # a verification gate without any negation word leaves the gate support alone
        gate = support_of(m._parse_solution_lead_negative, "Cline verification gate is strong")
        self.assertNotIn("Hook-enforced gates", gate.get("cline", {}))
        self.assertEqual(support_of(m._parse_solution_lead_negative, "unrelated sentence"), {})
        # hook mention without a negation is not downgraded
        plain = support_of(m._parse_solution_lead_negative, "Aider has hook enforcement")
        self.assertNotIn("Hook-enforced gates", plain.get("aider", {}))

    def test_managed_hosting_offer(self) -> None:
        self.assertEqual(support_of(m._parse_managed_hosting_offer, "nothing"), {})
        support = support_of(m._parse_managed_hosting_offer, "While Silver Bullet is local, devin and aider offer managed hosting paths")
        self.assertNotIn("silver-bullet", support)
        self.assertTrue(support["devin"]["Managed hosting"])
        self.assertTrue(support["aider"]["Zero-infra bootstrap"])
        support = support_of(m._parse_managed_hosting_offer, "Cline and devin offer managed hosting")
        self.assertTrue(support["cline"]["Managed hosting"])
        self.assertNotIn("Zero-infra bootstrap", support["devin"])

    def test_misc_single_purpose_parsers(self) -> None:
        self.assertFalse(hasattr(m, "_parse_startup_must_have_badge"))  # no per-vendor badge parser
        self.assertEqual(support_of(m._parse_template_ttv, "nothing"), {})
        self.assertEqual(support_of(m._parse_template_ttv, "time-to-value through templates, zzz"), {})
        self.assertEqual(support_of(m._parse_template_ttv, "Devin has time-to-value through templates"), {"devin": {"Prebuilt SDLC templates": True}})
        self.assertEqual(support_of(m._parse_autonomous_ship_claim, "nothing"), {})
        self.assertEqual(support_of(m._parse_autonomous_ship_claim, "it plans, writes, tests, and ships"), {})
        ship = support_of(m._parse_autonomous_ship_claim, "Devin plans, writes, tests, and ships code")
        self.assertEqual(set(ship["devin"]), {"Managed hosting", "CI integration", "Zero-infra bootstrap"})
        self.assertEqual(support_of(m._parse_strong_composition_claim, "nothing"), {})
        self.assertEqual(support_of(m._parse_strong_composition_claim, "strong git-native composition"), {})
        self.assertEqual(support_of(m._parse_strong_composition_claim, "Aider has strong BYO composition"), {"aider": {"Workflow composition": True}})
        self.assertFalse(hasattr(m, "_parse_openhands_templates"))  # no per-vendor parser

    def test_inclusion_criteria_scoped_claim(self) -> None:
        self.assertEqual(support_of(m._parse_inclusion_criteria_scoped_claim, "nothing about criteria"), {})
        all7 = support_of(m._parse_inclusion_criteria_scoped_claim, "Devin and Aider are passing all 7 inclusion criteria")
        self.assertEqual(set(all7["devin"]), set(m._default_inclusion_features()))
        self.assertEqual(set(all7["aider"]), set(m._default_inclusion_features()))
        paren = support_of(m._parse_inclusion_criteria_scoped_claim,
                           "Deterministic gates are strong (Devin, Aider); lifecycle span exists (zzz); cross-session state (cline)")
        self.assertTrue(paren["devin"]["Hook-enforced gates"])
        self.assertTrue(paren["aider"]["Hook-enforced gates"])
        self.assertTrue(paren["cline"]["Workflow composition"])
        life = support_of(m._parse_inclusion_criteria_scoped_claim, "Per the inclusion criteria, lifecycle span is wide (devin, aider)")
        self.assertTrue(life["devin"]["Workflow composition"])
        self.assertTrue(life["aider"]["Atomic flow catalog"])
        # phrase that maps to no inclusion keyword falls back to feature mentions inside the phrase
        fallback = support_of(m._parse_inclusion_criteria_scoped_claim, "orchestrat (devin)")
        self.assertIn("devin", fallback)

    def test_inclusion_feature_helpers(self) -> None:
        self.assertEqual(m._features_for_inclusion_mentions("Deterministic gates and cross-session state"),
                         ["Hook-enforced gates", "Workflow composition"])
        self.assertEqual(m._features_for_inclusion_mentions("lifecycle span / lifecycle span"), ["Workflow composition", "Atomic flow catalog"])
        self.assertEqual(m._features_for_inclusion_mentions("none"), [])
        defaults = m._default_inclusion_features()
        self.assertEqual(len(defaults), len(set(defaults)))
        self.assertIn("Hook-enforced gates", defaults)


@with_legacy_catalogs
class SlugScopedProseTests(unittest.TestCase):
    def test_window_scan_positive_and_lack(self) -> None:
        support = support_of(m._apply_slug_scoped_prose, "Devin provides hook gates and workflow composition. Aider")
        self.assertTrue(support["devin"]["Hook-enforced gates"])
        support = support_of(m._apply_slug_scoped_prose, "Cline lacks audit logs entirely")
        self.assertIs(support["cline"]["Audit log"], False)
        # the subject of the lack clause mentions the slug again: that is a statement about the slug
        again = support_of(m._apply_slug_scoped_prose, "Cline works fine and cline lacks audit logs")
        self.assertIs(again["cline"]["Audit log"], False)
        # the lack clause belongs to a different subject: nothing is assigned for that feature
        other = support_of(m._apply_slug_scoped_prose, "Cline said that the vendor lacks audit logs")
        self.assertNotIn("Audit log", other.get("cline", {}))
        self.assertEqual(support_of(m._apply_slug_scoped_prose, "Totally unrelated words"), {})

    def test_slug_region_missing_is_skipped(self) -> None:
        # "github copilot" resolves to a slug whose own pattern ("github copilot workspace") is not in the
        # text, so the window scan skips it; the sentence-level parsers still record the claim.
        support = support_of(m._apply_slug_scoped_prose, "github copilot supports hook gates")
        self.assertEqual(support, {"github-copilot-workspace": {"Hook-enforced gates": True}})


@with_legacy_catalogs
class BulkClaimTests(unittest.TestCase):
    def test_extract_bulk_solution_list(self) -> None:
        f = m._extract_bulk_solution_list
        self.assertEqual(f("Startup-weighted core for matrix: devin, aider — comfortably more"), "devin, aider")
        self.assertEqual(f("The primary APO matrix should prioritize devin; Generic things"), "devin")
        self.assertEqual(f("Confirmed in-scope core set (APO): devin, aider"), "devin, aider")
        self.assertEqual(f("APO matrix leaders are devin and aider"), "devin and aider")
        self.assertEqual(f("Commercial-weighted peer: devin"), "devin")
        self.assertEqual(f("The peers are devin, aider"), "devin, aider")
        self.assertIsNone(f("no list at all"))
        self.assertEqual(f("They are "), "")

    def test_core_set_bulk_claim(self) -> None:
        support: dict = {}
        self.assertFalse(m._parse_core_set_bulk_claim(support, "unrelated"))
        self.assertFalse(m._parse_core_set_bulk_claim(support, "Confirmed in-scope core set"))  # no list
        self.assertFalse(m._parse_core_set_bulk_claim(support, "Confirmed in-scope core set: zzz, qqq"))  # no known slug
        self.assertTrue(m._parse_core_set_bulk_claim(support, "Confirmed in-scope core set: devin, aider"))
        self.assertEqual(set(support["devin"]), set(m._default_inclusion_features()))
        support = {}
        self.assertTrue(m._parse_core_set_bulk_claim(support, "Startup-weighted core for matrix: devin; deterministic gates matter"))
        self.assertEqual(set(support["devin"]), {"Hook-enforced gates", "Quick onboarding", "Zero-infra bootstrap"})
        support = {}
        self.assertFalse(m._parse_core_set_bulk_claim(support, "in-scope commercial + OSS solution count: aider"))  # no list marker
        self.assertTrue(m._parse_core_set_bulk_claim(support, "in-scope commercial + OSS solution count; peers are aider and cline"))
        self.assertEqual(set(support), {"aider", "cline"})

    def test_matrix_leaders_claim(self) -> None:
        support: dict = {}
        self.assertFalse(m._parse_matrix_leaders_claim(support, "unrelated"))
        self.assertFalse(m._parse_matrix_leaders_claim(support, "matrix leaders are"))
        self.assertFalse(m._parse_matrix_leaders_claim(support, "matrix leaders are zzz"))
        self.assertTrue(m._parse_matrix_leaders_claim(support, "matrix leaders are devin and aider"))
        self.assertTrue(support["devin"]["IDE-native integration"])
        self.assertTrue(support["aider"]["Parent/child agent delegation"])
        support = {}
        self.assertTrue(m._parse_matrix_leaders_claim(support, "Commercial-weighted peer: devin with deterministic gates"))
        self.assertTrue(support["devin"]["Hook-enforced gates"])
        self.assertNotIn("IDE-native integration", {k for k, v in support["devin"].items() if v is not True})

    def test_host_runtime_substrate(self) -> None:
        support: dict = {}
        self.assertFalse(m._parse_host_runtime_substrate_claim(support, "unrelated"))
        self.assertFalse(m._parse_host_runtime_substrate_claim(support, "host runtime substrate row for zzz"))
        known = {**m._known_or_run(None), "cursor": "Cursor", "claude-code": "Claude Code"}
        self.assertTrue(m._parse_host_runtime_substrate_claim(support, "Host runtime: Cursor IDE and Claude Code", known=known))
        self.assertEqual(support, {"cursor": {"IDE-native integration": True}, "claude-code": {"IDE-native integration": True}})


@with_legacy_catalogs
class ParseFeatureSupportTests(unittest.TestCase):
    def test_dispatch_order(self) -> None:
        envelopes = env(
            "Confirmed in-scope core set: devin",
            "matrix leaders are aider",
            "Host runtime: Cursor IDE",
            "Matrix — CI integration: cline",
            "Hook-enforced gates ✔ for openhands",
            "Matrix entry — Continue: has hooks and CI/CD",
            "Matrix entry — Workflow composition: crewai, autogen but sweep does not",
            "matrix row 'Managed hosting': tembo",
            "Matrix entry gibberish without colon",
            "Linear offers hook gates",
        )
        known = {**m._known_or_run(None), "cursor": "Cursor"}
        support = m.parse_feature_support(envelopes, known=known)
        self.assertTrue(support["devin"]["Hook-enforced gates"])
        self.assertTrue(support["aider"]["IDE-native integration"])
        self.assertTrue(support["cursor"]["IDE-native integration"])
        self.assertTrue(support["cline"]["CI integration"])
        self.assertTrue(support["openhands"]["Hook-enforced gates"])
        self.assertTrue(support["continue"]["CI integration"])
        self.assertTrue(support["crewai"]["Workflow composition"])
        self.assertIs(support["sweep-ai"]["Workflow composition"], False)
        self.assertTrue(support["tembo"]["Managed hosting"])

    def test_matrix_entry_without_solution_head_is_a_feature_row(self) -> None:
        support = m.parse_feature_support(env("Matrix entry — Hook-enforced gates: devin, aider but cline does not"))
        self.assertTrue(support["devin"]["Hook-enforced gates"])
        self.assertIs(support["cline"]["Hook-enforced gates"], False)

    def test_empty_inputs(self) -> None:
        self.assertEqual(m.parse_feature_support([]), {})
        self.assertEqual(m.parse_feature_support(env("matrix entry with nothing parseable")), {})


@with_legacy_catalogs
class RubricTests(unittest.TestCase):
    def test_group_features_into_categories(self) -> None:
        grouped = m._group_features_into_categories(["SSO", "Custom thing", "SSO", "Workflow composition", "Another custom"])
        self.assertEqual(grouped, [
            {"name": "Security and compliance", "features": ["SSO"]},
            {"name": "Run-synthesized", "features": ["Custom thing", "Another custom"]},
            {"name": "Process orchestration", "features": ["Workflow composition"]},
        ])
        self.assertEqual(m._group_features_into_categories([]), [])

    def test_rubric_from_comparison_rows(self) -> None:
        comparison = {"rows": [
            "junk", {"type": "category", "name": "Cat A"}, {"type": "feature", "name": "F1"}, {"type": "feature", "name": "F1"},
            {"type": "feature", "name": " "}, {"type": "other", "name": "skip"}, {"type": "category"},
            {"type": "feature", "name": "F2"}, {"type": "category", "name": "Cat B"}, {"type": "feature", "name": "F3"},
        ]}
        rubric = m.synthesize_feature_rubric(comparison=comparison)
        self.assertEqual(rubric["source"], "comparison.json")
        self.assertEqual(rubric["categories"], [{"name": "Cat A", "features": ["F1"]}, {"name": "Capabilities", "features": ["F2"]},
                                                {"name": "Cat B", "features": ["F3"]}])

    def test_rubric_from_support_then_template(self) -> None:
        support = {"a": {"SSO": True, "": True, " X ": None}, "b": "junk", "c": {"SSO": False}}
        rubric = m.synthesize_feature_rubric(comparison={"rows": []}, support=support)
        self.assertEqual(rubric["source"], "live-envelopes")
        self.assertEqual(rubric["categories"], [{"name": "Security and compliance", "features": ["SSO"]},
                                                {"name": "Run-synthesized", "features": ["X"]}])
        template = m.synthesize_feature_rubric()
        self.assertEqual(template["source"], "fallback-template")
        self.assertEqual([c["name"] for c in template["categories"]], [c["name"] for c in m.FEATURE_TEMPLATE])
        self.assertEqual(m.synthesize_feature_rubric(support={})["source"], "fallback-template")

    def test_build_features_json(self) -> None:
        support = {"devin": {"SSO": True, "RBAC": False}}
        rubric = {"source": "r", "categories": [
            {"name": "Sec", "features": ["SSO", {"name": "RBAC"}, {"name": ""}, {}]},
            {"features": ["Unknown"]}, {"name": "Empty", "features": []}, {"name": "Nothing"},
        ]}
        out = m.build_features_json("devin", support, rubric=rubric)
        self.assertEqual(out["display_name"], "Devin (Cognition)")
        self.assertEqual(out["source"], "r")
        self.assertEqual(out["rubric_source"], "r")
        self.assertEqual(out["categories"], [
            {"name": "Sec", "features": [{"name": "SSO", "supported": True}, {"name": "RBAC", "supported": False}]},
            {"name": "Capabilities", "features": [{"name": "Unknown", "supported": None}]},
        ])
        # without a rubric it is derived from the comparison, and unknown slugs keep their own name
        derived = m.build_features_json("mystery", {}, comparison={"rows": [{"type": "feature", "name": "F"}]})
        self.assertEqual(derived["display_name"], "mystery")
        self.assertEqual(derived["source"], "comparison.json")
        self.assertEqual(derived["categories"][0]["features"], [{"name": "F", "supported": None}])
        no_source = m.build_features_json("devin", support, rubric={"categories": []})
        self.assertEqual(no_source["source"], "live-envelopes")


@with_legacy_catalogs
class WriteRunFeaturesTests(unittest.TestCase):
    def test_writes_rubric_and_per_solution_files(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "comparison").mkdir()
            (root / "comparison" / "comparison.json").write_text(json.dumps({
                "rankings": [{"solution": "devin"}, {"nosolution": 1}, "junk"],
                "rows": [{"type": "feature", "name": "SSO"}]}), encoding="utf-8")
            (root / "solutions" / "extra-dir").mkdir(parents=True)
            (root / "solutions" / "devin").mkdir()
            (root / "solutions" / "a-file.txt").write_text("x", encoding="utf-8")
            result = m.write_run_features_json(root, support={"devin": {"SSO": True}, "extra-dir": {"SSO": False}})
            self.assertEqual(result["status"], "ok")
            self.assertEqual(result["rubric_source"], "comparison.json")
            self.assertEqual(result["rubric_path"], "landscape/features-rubric.json")
            # only ranked solutions get features.json; other folders are not touched
            self.assertEqual(result["features_written"], ["solutions/devin/features.json"])
            self.assertFalse((root / "solutions" / "extra-dir" / "features.json").exists())
            devin = json.loads((root / "solutions" / "devin" / "features.json").read_text(encoding="utf-8"))
            self.assertEqual(devin["categories"][0]["features"], [{"name": "SSO", "supported": True}])
            self.assertEqual(json.loads((root / "landscape" / "features-rubric.json").read_text(encoding="utf-8"))["source"], "comparison.json")

    def test_comparison_argument_and_bad_files(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            result = m.write_run_features_json(root, comparison=None, support=None)
            self.assertEqual((result["rubric_source"], result["features_written"]), ("fallback-template", []))
            (root / "comparison").mkdir()
            (root / "comparison" / "comparison.json").write_text("{broken", encoding="utf-8")
            self.assertEqual(m.write_run_features_json(root)["rubric_source"], "fallback-template")
            (root / "comparison" / "comparison.json").write_text("[1]", encoding="utf-8")
            self.assertEqual(m.write_run_features_json(root)["rubric_source"], "fallback-template")
            given = {"rankings": [{"solution": "aider"}], "rows": [{"type": "feature", "name": "X"}]}
            out = m.write_run_features_json(root, comparison=given, known={"aider": "Aider!"})
            self.assertEqual(out["features_written"], ["solutions/aider/features.json"])
            self.assertEqual(json.loads((root / "solutions" / "aider" / "features.json").read_text(encoding="utf-8"))["display_name"], "Aider!")
            with mock.patch.object(Path, "read_text", side_effect=OSError("io")):
                self.assertEqual(m.write_run_features_json(root, comparison={})["rubric_source"], "fallback-template")


@with_legacy_catalogs
class ScrTests(unittest.TestCase):
    def test_claims_selection(self) -> None:
        texts = [f"Aider supports workflow number {i}" for i in range(15)]
        texts.insert(0, "startup-weighted matrix aider dump")
        texts.insert(1, "Something about devin only")
        claims = m._scr_claims_for_slug("aider", env(*texts))
        self.assertEqual(len(claims), 12)
        self.assertNotIn("startup-weighted matrix aider dump", claims)
        self.assertEqual(m._scr_claims_for_slug("devin", env(*texts)), ["Something about devin only"])
        self.assertEqual(m._scr_claims_for_slug("unknown-thing", env("nothing")), [])
        self.assertEqual(m._scr_claims_for_slug("aider", env("aider notes cost money")), ["aider notes cost money"])

    def test_scr_markdown_variants(self) -> None:
        with_seed = m.build_scr_md("silver-bullet", env("Silver Bullet is local"))
        self.assertIn("# Solution Capability Report: Silver Bullet", with_seed)
        self.assertIn("Slug: `silver-bullet`", with_seed)
        self.assertNotIn("Agentic Process Orchestrator", with_seed)
        self.assertIn("- Silver Bullet is local", with_seed)
        claims_only = m.build_scr_md("ai-dlc", env("AI-DLC is a methodology from AWS"))
        self.assertIn("## Executive summary\n\nAI-DLC is a methodology from AWS", claims_only)
        seed_only = m.build_scr_md("devin", env("nothing relevant"))
        self.assertIn(f"- {m.OVERVIEW_SEEDS['devin']}", seed_only)
        bare = m.build_scr_md("agentgpt-clone", env("nothing relevant"))
        self.assertIn("agentgpt-clone is a solution identified in this research run.", bare)
        self.assertIn("_No direct prose evidence lines matched this solution slug in live envelopes._", bare)


@with_legacy_catalogs
class MaterializeTests(unittest.TestCase):
    def run_materialize(self, root: Path, **kw):
        with mock.patch.object(m, "resolve_pack_from_need", return_value=kw.pop("the_pack", None)):
            return m.materialize_solution_artifacts(root, **kw)

    def test_input_errors(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            with self.assertRaisesRegex(FileNotFoundError, "missing envelopes"):
                self.run_materialize(root)
            (root / "contributions").mkdir()
            (root / "contributions" / "all-envelopes.json").write_text('{"a": 1}', encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "must be a JSON array"):
                self.run_materialize(root)
            (root / "contributions" / "all-envelopes.json").write_text('["junk", 1]', encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "no contribution envelopes"):
                self.run_materialize(root)
            with self.assertRaisesRegex(ValueError, "no contribution envelopes"):
                self.run_materialize(root, envelopes=[])

    def test_open_discovery_run(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "need_profile.json").write_text("{}", encoding="utf-8")
            (root / "contributions").mkdir()
            (root / "contributions" / "all-envelopes.json").write_text(
                json.dumps(env("Aider provides ci integration", "Cline provides ci integration", "junk-not-dict")[0:1] + ["junk"]), encoding="utf-8")
            result = self.run_materialize(root, shortlist_count=1)
            self.assertEqual(result["status"], "ok")
            self.assertEqual(result["shortlist_count"], 1)
            self.assertNotIn("catalog_audit", result)
            solutions = json.loads((root / "solutions.json").read_text(encoding="utf-8"))
            self.assertEqual(solutions["count"], result["solutions_count"])
            slug = solutions["solutions"][0]["slug"]
            self.assertTrue((root / "solutions" / slug / "scr.md").is_file())
            self.assertTrue((root / "landscape" / "features-rubric.json").is_file())
            shortlist = json.loads((root / "shortlist" / "shortlist.json").read_text(encoding="utf-8"))
            self.assertEqual(shortlist["count"], 1)
            self.assertEqual(shortlist["solutions"][0]["rank"], 1)

    def test_pack_run_reports_but_never_deletes_stale_solution_directories(self) -> None:
        audit = {"matrix_slugs": ["devin", "aider"], "core": ["devin", "aider", "cline"]}
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "solutions" / "stale-vendor").mkdir(parents=True)
            (root / "solutions" / "stale-vendor" / "scr.md").write_text("old", encoding="utf-8")
            (root / "solutions" / "note.txt").write_text("keep files", encoding="utf-8")
            with mock.patch("solution_classifier.classify_solutions", return_value=audit), \
                    mock.patch("solution_classifier.write_catalog_audit") as write_audit:
                result = self.run_materialize(root, envelopes=env("Devin and Aider are here"), the_pack=PACK)
            write_audit.assert_called_once()
            self.assertEqual(result["catalog_audit"], "landscape/catalog_audit.json")
            self.assertEqual(result["core_count"], 3)
            self.assertEqual((root / "solutions" / "stale-vendor" / "scr.md").read_text(encoding="utf-8"), "old")
            self.assertEqual(result["stale_solution_dirs"], ["stale-vendor"])
            self.assertTrue((root / "solutions" / "note.txt").is_file())
            self.assertTrue((root / "solutions" / "devin" / "features.json").is_file())

    def test_audit_without_core_omits_counts_when_empty(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            with mock.patch("solution_classifier.classify_solutions", return_value={}), \
                    mock.patch("solution_classifier.write_catalog_audit"):
                result = self.run_materialize(Path(tmp), envelopes=env("Devin"), the_pack=PACK)
        self.assertNotIn("catalog_audit", result)


@with_legacy_catalogs
class MainTests(unittest.TestCase):
    def run_main(self, root: Path):
        out = io.StringIO()
        with mock.patch.object(sys, "argv", ["materialize", "--dir", str(root)]), contextlib.redirect_stdout(out):
            rc = m.main()
        return rc, out.getvalue()

    def test_main_reports_errors_and_success(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            rc, out = self.run_main(root)
            self.assertEqual(rc, 1)
            self.assertEqual(json.loads(out)["status"], "error")
            (root / "contributions").mkdir()
            (root / "contributions" / "all-envelopes.json").write_text(json.dumps(env("Devin provides hooks")), encoding="utf-8")
            with mock.patch.object(m, "resolve_pack_from_need", return_value=None):
                rc, out = self.run_main(root)
            self.assertEqual(rc, 0)
            self.assertEqual(json.loads(out)["status"], "ok")

    def test_script_entrypoint(self) -> None:
        import runpy

        with tempfile.TemporaryDirectory() as tmp:
            with mock.patch.object(sys, "argv", ["materialize_solution_artifacts.py", "--dir", tmp]), \
                    contextlib.redirect_stdout(io.StringIO()), self.assertRaises(SystemExit) as cm:
                runpy.run_path(str(SCRIPTS / "materialize_solution_artifacts.py"), run_name="__main__")
        self.assertEqual(cm.exception.code, 1)


class OpenDiscoveryTests(unittest.TestCase):
    """No category pack and no built-in catalogue: vendors come from the workers' own rows."""

    def test_feature_names_and_rubric_guarded_assignments(self) -> None:
        self.assertIsNone(m._feature_name(""))
        self.assertIsNone(m._feature_name("   "))
        self.assertIsNone(m._feature_name("x" * 81))
        self.assertEqual(m._feature_name("  Exactly-once   semantics "), "Exactly-once semantics")
        # a built-in prose heuristic only credits features the active rubric declares
        support: dict = {}
        m._assign_rubric(support, "a", "Prebuilt SDLC templates", True)
        self.assertEqual(support, {})  # no pack vocabulary active: nothing to credit
        with mock.patch.object(m, "FEATURE_TEMPLATE", [{"name": "C", "features": ["Prebuilt SDLC templates"]}]):
            m._assign_rubric(support, "a", "Prebuilt SDLC templates", True)
        self.assertIs(support["a"]["Prebuilt SDLC templates"], True)

    def rows(self, *rows, model="m1"):
        return {"logical_model_id": model, "phase_id": "DR-RETRIEVE", "payload": {"matrix_entries": list(rows)}}

    def row(self, vendor, feature="SSO", supported=True):
        return {"vendor": vendor, "feature": feature, "supported": supported}

    def test_vendors_are_discovered_from_matrix_entries_not_from_a_catalogue(self) -> None:
        self.assertEqual((m.KNOWN_SOLUTIONS, m.SLUG_ALIASES), ({}, {}))
        with mock.patch.object(m, "resolve_pack_from_need", return_value=None):
            envs = [
                self.rows(self.row("Apache Kafka"), self.row("Redpanda"), self.row("redpanda ", "Tiered storage")),
                self.rows(self.row("Apache Kafka", "SSO", False), model="m2"),
                *env("Aider and Cline are popular"),  # prose naming vendors no worker put in a row
            ]
            self.assertEqual(m.discover_solutions(envs), ["apache-kafka", "redpanda"])
            self.assertEqual(m.discover_solutions([]), [])
            self.assertEqual(m.discover_solutions(env("An SBOM and a USB stick, plus compliance")), [])
            names = m.open_world_known(envs, {})
        self.assertEqual((names["apache-kafka"], names["redpanda"]), ("Apache Kafka", "Redpanda"))

    def test_structured_vendor_resolution_is_exact_never_a_prefix_or_blank(self) -> None:
        known = {"devika": "Devika", "sourcegraph-cody": "Sourcegraph Cody"}
        r = m.resolve_structured_vendor
        self.assertEqual(r("DEVIKA", known, None), "devika")
        self.assertEqual(r("sourcegraph cody", known, None), "sourcegraph-cody")
        self.assertEqual(r("Dev", known, None), "dev")  # an unknown vendor is its own column, not Devika
        self.assertEqual(r("S", known, None), "s")
        for blank in ("", "   ", None, "!!!", "x" * 90):
            self.assertIsNone(r(blank, known, None))
        pack = {"overlay": {"slug_aliases": {"CodyAI": "sourcegraph-cody"}, "head_slug_aliases": {"the dev": "devika"}}}
        self.assertEqual(r("cody ai", known, pack), None)  # an alias must match exactly
        self.assertEqual(r("codyai", known, pack), "sourcegraph-cody")
        self.assertEqual(r("The Dev", known, pack), "devika")
        self.assertIsNone(r("Unknown vendor", known, pack))  # with a pack unknown vendors are ignored

    def test_feature_spellings_are_folded_and_the_users_spelling_wins(self) -> None:
        known = {"devika": "Devika"}
        envs = [
            self.rows(self.row("Devika", "Single sign-on"), model="m1"),
            self.rows(self.row("Devika", "single SIGN ON", False), model="m2"),
            self.rows(self.row("Devika", "Single Sign-On", False), model="m3"),
            self.rows(self.row("Devika", "Single sign on", False), model="m4"),
        ]
        got = m.parse_structured_matrix_entries(envs, known=known)
        self.assertEqual(list(got["devika"]), ["Single sign-on"])  # most common spelling; one row
        self.assertIs(got["devika"]["Single sign-on"], False)  # 1 yes vs 3 no, all on the same cell
        wanted = m.parse_structured_matrix_entries(envs, known=known, preferred_features=["Single Sign-on (SSO)", "Single sign-on"])
        self.assertEqual(list(wanted["devika"]), ["Single sign-on"])
        user = m.parse_structured_matrix_entries(envs, known=known, preferred_features=["SINGLE SIGN-ON"])
        self.assertEqual(list(user["devika"]), ["SINGLE SIGN-ON"])  # the need profile's spelling is used
        self.assertEqual(m._feature_key("  Exactly-once   Semantics! "), "exactly once semantics")

    def test_derived_critical_features(self) -> None:
        support = {"a": {"X": True, "Y": True, "Z": False}, "b": {"X": True, "Y": False, "W": None}}
        self.assertEqual(m.derive_critical_features({}, support), {"X": "Critical", "Y": "Critical"})
        self.assertEqual(m.derive_critical_features({}, support, limit=1), {"X": "Critical"})
        self.assertEqual(m.derive_critical_features({"must_haves": ["x"]}, support), {})  # a must-have matches (folded)
        self.assertEqual(m.derive_critical_features({"must_haves": ["nope"]}, support), {"X": "Critical", "Y": "Critical"})
        self.assertEqual(m.derive_critical_features({"weights_override": {"Z": "Low"}}, support), {})  # the user decided
        self.assertEqual(m.derive_critical_features({}, {"a": {"Z": False}}), {})  # nothing ticked


        known = {"devika": "Devika"}
        envs = [
            self.rows(self.row(""), self.row(None), {"feature": "SSO", "supported": True}, self.row("Devika", "SSO", False)),
            self.rows(self.row("Devika", "SSO", True), model="m1"),  # same model, later phase: wins
            self.rows(self.row("Devika", "SSO", True), model="m2"),
            self.rows(self.row("Devika", "SSO", False), model="m3"),
        ]
        got = m.parse_structured_matrix_entries(envs, known=known)
        self.assertEqual(set(got), {"devika"})
        self.assertIs(got["devika"]["SSO"], True)  # m1 yes (later row), m2 yes, m3 no
        self.assertEqual(m.disputed_cells(got), [{"vendor": "devika", "feature": "SSO", "yes": 2, "no": 1}])
        self.assertEqual(m.disputed_cells({"x": {"A": True}}), [])
        # rows without a resolvable vendor do not create columns
        self.assertEqual(m.structured_vendor_names([self.rows(self.row(""), self.row("Acme")), {"payload": {}}, "junk"], {}, None),
                         {"acme": ("Acme", 1)})


if __name__ == "__main__":
    unittest.main()
