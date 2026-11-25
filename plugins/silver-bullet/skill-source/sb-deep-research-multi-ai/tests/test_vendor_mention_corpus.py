"""Table-driven regression corpus for vendor mentions in prose (precision first).

Every sentence the three H8b-followup reviews probed lives in fixtures/vendor_mention_corpus.json. Rounds
had oscillated between false vendor ticks (fabricated evidence in the comparison matrix) and missed
mentions, so one corpus now pins both ends:

* ``plain_english`` sets (r4 and r2 false positives): no ambiguous vendor may be credited. Hard bar: 0.
* ``vendor`` set (round-1 recall): each case is credited as evidence and by extract_slugs, except the
  ``known_miss`` ones, which are listed in the fixture and pinned as misses (a miss costs a tick; a false
  mention would cost a fabricated one).
* ``absence_keep`` / ``absence_drop``: a clause that says nothing was found casts no vote, and a genuine
  positive next to it keeps its vote.
"""

from __future__ import annotations

import collections
import json
import sys
import re
import time
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

import materialize_solution_artifacts as m  # noqa: E402
import solution_classifier as sc  # noqa: E402
from apo_pack_run_fixture import with_apo_pack_run  # noqa: E402

CORPUS = json.loads((Path(__file__).parent / "fixtures" / "vendor_mention_corpus.json").read_text(encoding="utf-8"))
LEGACY_AMBIGUOUS = {"director", "factory-ai", "cursor", "continue", "linear", "conductor", "cognition-scout", "scout",
             "claude-harness", "harness", "sweep", "cursor-agents", "factory", "github-copilot", "devin", "aider",
             "copilot-workspace", "windsurf", "codex", "cline", "poolside", "superpowers", "silver-bullet",
             "augment-cosmos", "open-interpreter", "deepwork", "tembo", "spec-kit", "magic-dev", "openhands"}
EXPECTED_COUNTS = {"r4_false_positive": 14, "r2_false_positive": 31, "round1_recall": 26, "absence_keep": 23,
                   "absence_drop": 14, "r3_false_positive": 52, "r3b_false_positive": 25, "r3_recall": 24,
                   "r3_absence": 34, "r1_absence": 7, "copilot": 7, "r4b_false_positive": 52,
                   "r4c_false_positive": 30, "r4_recall": 25, "r4_absence": 24, "r4_absence_plain": 17,
                   "r5_false_positive": 82, "r5_audit": 14, "r6_false_positive": 79, "r6_matrix_false_positive": 10,
                   "r6_qualified_false_positive": 3, "r7_false_positive": 58}
KNOWN_MISSES = 74  # of 81: the ambiguous vendors need an explicit signal
REPO = Path(__file__).resolve().parents[3]
REAL_RUN = REPO / "research" / "2026-07-20-agentic-sdlc-orchestration-landscape-multimarket-final"


def envs(text, row=None):
    item = {"text": text}
    item.update(row or {})
    return [{"phase_id": "DR-TRIANGULATE", "logical_model_id": "m", "payload": {"claim_candidates": [item]}}]


def cases(kind):
    return [c for c in CORPUS if c["kind"] == kind]


@with_apo_pack_run
class VendorMentionCorpusTests(unittest.TestCase):
    def setUp(self) -> None:
        from category_pack import build_known_solutions, resolve_pack_from_need

        self.pack = resolve_pack_from_need({"category_pack_id": "agentic-sdlc-process-orchestrator"})
        self.known = build_known_solutions(self.pack)

    @property
    def registry(self):  # built inside the test, where the pack run context is installed
        return m.vendor_registry()

    @property
    def ambiguous(self):
        return LEGACY_AMBIGUOUS | set(self.registry.ambiguous_vendors())

    def support(self, text, row=None):
        return m.parse_feature_support(envs(text, row), known=self.known, pack=self.pack)

    def credited(self, slug, text, row=None):
        with m.claim_scope(m._declared_for_row(dict(row or {}, text=text), self.known, self.pack)):
            extracted = slug in m._extract_slugs_from_text(text, self.known, self.pack)
        return slug in sc._envelope_evidence_slugs(envs(text, row), self.pack) and extracted

    def test_the_corpus_has_every_probed_sentence(self) -> None:
        self.assertEqual(dict(collections.Counter(c["set"] for c in CORPUS)), EXPECTED_COUNTS)
        self.assertEqual(len([c for c in CORPUS if c["kind"] == "plain_english"]), 451)
        self.assertFalse([c for c in CORPUS if "residual" in c])  # no lexical residual remains (Devin is ambiguous)

    def test_plain_english_credits_no_vendor(self) -> None:
        failures = []
        for case in cases("plain_english"):
            text = case["text"]
            hits = (set(sc._envelope_evidence_slugs(envs(text), self.pack)) | set(m._extract_slugs_from_text(text, self.known, self.pack))
                    | set(self.support(text))) & self.ambiguous
            if hits:
                failures.append((sorted(hits), text))
        self.assertEqual(failures, [], f"{len(failures)} false vendor mentions")

    def test_untagged_recall_is_pinned_and_a_vendors_tag_recovers_all_of_it(self) -> None:
        recall = cases("vendor")
        missed = [c["text"] for c in recall if not self.credited(c["slug"], c["text"])]
        listed = [c["text"] for c in recall if c.get("known_miss")]
        self.assertEqual(sorted(missed), sorted(listed))  # the misses are exactly the ones the fixture lists
        self.assertEqual((len(recall), len(missed)), (81, KNOWN_MISSES))
        tagged = [c["text"] for c in recall if not self.credited(c["slug"], c["text"], {"vendors": [c["slug"]]})]
        self.assertEqual(tagged, [])  # 81 of 81 once the row declares the vendor

    def test_an_ambiguous_name_is_credited_only_by_an_explicit_signal(self) -> None:
        yes = (("Director enforces gates.", {"vendors": ["director"]}), ("Director enforces gates.", {"source_ref": "Director"}),
               ("Cursor ships agents.", {"source_ref": "https://cursor.com/pricing"}),
               ("Cursor ships agents.", {"source_url": "https://cursor.com/pricing"}),
               ("GitHub Copilot reviews pull requests.", None),
               ("Factory.ai offers SSO.", None))
        slugs = {"Director": "director", "Cursor": "cursor", "See": "cursor", "Devin": "devin", "Workflow": "director",
                 "GitHub": "github-copilot", "Factory.ai": "factory-ai"}
        for text, row in yes:
            slug = slugs[text.split()[0]]
            self.assertTrue(self.credited(slug, text, row), (text, row))
        no = ("We tried Cursor IDE today.", "Cursor extension adds chat.", "Continue.dev supports local models.", "Director 2.0 adds gates.",
              "Melty Conductor orchestrates parallel agents.", "Factory Droids ship PRs.", "The leaders are Conductor, cc10x and Director.",
              "Hard exclusions (never in-scope): Cursor Background Agents, Sweep, Windsurf.", "Silver Bullet uses deterministic gates.",
              "Conductor (Melty Labs) runs agents.", "Cursor by Anysphere is an editor.", "Cursor v2 changed the panel.",
              "Hover the Cursor over the chart.", "Teams that use Cursor report faster refactors.", "Devin from accounting approved it.")
        for text in no:
            self.assertFalse(set(sc._envelope_evidence_slugs(envs(text), self.pack)) & self.ambiguous, text)
            self.assertFalse(set(m._extract_slugs_from_text(text, self.known, self.pack)) & self.ambiguous, text)

    def test_unknown_spellings_credit_nothing(self) -> None:
        self.assertFalse(m.mentions_vendor("Zorp works.", "zorp works.", "zorp"))

    def test_no_display_form_credits_an_ambiguous_vendor(self) -> None:
        self.assertFalse(hasattr(self.registry, "qualified"))
        for text, slug in (("Devin (Cognition) opens pull requests.", "devin"), ("Cognition (Devin) is a heading.", "devin"),
                           ("Our culture is GSD (Get Shit Done): ship fast.", "gsd"), ("Oh My Pi (OMP) is a bakery.", "oh-my-pi"),
                           ("Team leads: Devin (Cognition), Maria (Language).", "devin")):
            self.assertNotIn(slug, set(sc._envelope_evidence_slugs(envs(text), self.pack)) | set(m._extract_slugs_from_text(text, self.known, self.pack)), text)
        self.assertTrue(self.credited("devin", "Devin (Cognition) opens pull requests.", {"vendors": ["devin"]}))
        self.assertTrue(self.credited("devin", "Devin opens pull requests.", {"source_ref": "https://devin.ai/"}))

    def test_matrix_lines_never_credit_or_tick_an_ambiguous_vendor(self) -> None:
        lines = ("Matrix entry - Workflow composition: Director, cc10x", "- Matrix - Workflow composition: Director",
                 'Matrix Critical row "Workflow composition": Director pass; Sweep do not.', "Workflow composition ✔ for Director",
                 "APO matrix leaders are Conductor, cc10x", "Matrix - Director: Lana and Lilly Wachowski.",
                 'Row "Cursor" of the keyboard shortcuts table: arrow keys.', "RBAC ✔ for Director, Editor and Viewer roles.",
                 "Notes from the call:\n- RBAC ✔ for Director, Manager")
        for text in lines:
            self.assertEqual(set(sc._envelope_evidence_slugs(envs(text), self.pack)) & self.ambiguous, set(), text)
            self.assertEqual(set(m._extract_slugs_from_text(text, self.known, self.pack)) & self.ambiguous, set(), text)
            self.assertEqual({a for a, c in self.support(text).items() if any(c.values())} & self.ambiguous, set(), text)
        ticked = self.support("Workflow composition ✔ for Director, cc10x")  # a distinctive name keeps the matrix-line behaviour
        self.assertTrue(ticked["cc10x"]["Workflow composition"])
        self.assertNotIn("director", ticked)

    def test_vendors_tags_are_capped_slug_checked_and_exact(self) -> None:
        def tagged(tags):
            return sc._envelope_evidence_slugs(envs("Many agents copy the SDLC category.", {"vendors": tags}), self.pack)

        self.assertEqual(tagged(["sdlc"]), set())  # a category alias is not a vendor slug
        self.assertEqual(tagged(["Director of Engineering", "no-such-vendor", 7, {"slug": "cursor"}]), set())
        self.assertEqual(tagged("cursor"), set())
        self.assertEqual(tagged(["Director"]), {"director"})  # a name that slug-normalises to a vendor slug
        slugs = [f"vendor-{n}" for n in range(30)]
        known = dict(self.known, **{s: s for s in slugs})
        with m.run_context(known, self.pack):
            self.assertEqual(len(m.tagged_vendor_slugs(envs("x", {"vendors": slugs}), known, self.pack)), 12)

    def test_barkain_is_a_surname_so_the_product_needs_a_signal(self) -> None:
        self.assertNotIn("barkain", m.COINED_NAMES)
        self.assertIn("barkain-workflow-orchestrator", self.registry.ambiguous_vendors())
        self.assertNotIn("barkain-workflow-orchestrator", sc._envelope_evidence_slugs(envs("Mr Barkain from accounting approved it."), self.pack))

    def test_two_hundred_kilobyte_claims_stay_inside_the_budget(self) -> None:
        budget = 2.0 * (8 if "coverage" in sys.modules else 1)
        for unit in ("Linear, ", "Keyboard, Mouse, Cursor and Touch, Linear, Factory, Continue and Copilot. The model is Linear in x. Each Director owns. "):
            text = unit * (200_000 // len(unit))
            started = time.monotonic()
            self.support(text)
            self.assertLess(time.monotonic() - started, budget, unit)
        row = {"source_ref": "; ".join(f"https://example.com/{n}" for n in range(200))}
        started = time.monotonic()
        self.support("Silver Bullet provides workflow composition. " * 2000, row)
        self.assertLess(time.monotonic() - started, budget)

    def test_a_source_ref_needs_a_capitalised_spelling_and_a_negated_vendor_earns_no_inferred_features(self) -> None:
        row = {"source_ref": "https://cursor.com/blog/compare"}
        self.assertNotIn("cursor", sc._envelope_evidence_slugs(envs("Windsurf lets the cursor jump between edits.", row), self.pack))
        self.assertIn("cursor", sc._envelope_evidence_slugs(envs("Windsurf lets Cursor jump between edits.", row), self.pack))
        silver = sc._envelope_evidence_slugs(envs("Startup-weighted comparison: Silver Bullet leads.", {"source_ref": "Silver Bullet — Official Site; x"}), self.pack)
        self.assertNotIn("silver-bullet", silver)  # a source_ref splits on ";" and " + " only: a page title cannot re-credit a group claim
        claim = "Silver Bullet provides workflow composition; Barkain Workflow Orchestrator does not."
        support = self.support(claim, {"vendors": ["silver-bullet", "barkain-workflow-orchestrator"]})
        self.assertTrue(support["silver-bullet"]["Workflow composition"])
        self.assertNotIn("barkain-workflow-orchestrator", {a for a, c in support.items() if any(c.values())})

    def test_the_r8_adversarial_rows_credit_no_wrong_vendor(self) -> None:
        spec = json.loads((Path(__file__).parent / "fixtures" / "vendor_row_cases.json").read_text(encoding="utf-8"))
        self.assertEqual(len(spec["cases"]), 76)
        leaks = []
        for case in spec["cases"]:
            row = case["row"] if isinstance(case["row"], dict) else {"text": case["row"]}
            text = row["text"]
            others = {k: v for k, v in row.items() if k != "text"}
            wrong = set(case["wrong"] or spec["wrong_default"])
            with m.claim_scope(m._declared_for_row(dict(row), self.known, self.pack)):
                got = set(m._extract_slugs_from_text(text, self.known, self.pack))
            got |= set(sc._envelope_evidence_slugs(envs(text, others), self.pack))
            got |= {a for a, c in self.support(text, others).items() if any(c.values())}
            if got & wrong:
                leaks.append((sorted(got & wrong), row))
        self.assertEqual(leaks, [], f"{len(leaks)} of 76 rows credit a wrong vendor")

    def test_urls_in_prose_never_credit(self) -> None:
        for text in ("Export the logo as devin.ai and send it.", "Email devin.ai@example.com.", "conductor.build() registers it.",
                     "See https://www.cursor.com/pricing.", "Run ./autogen.sh before ./configure."):
            vendors = set(sc._envelope_evidence_slugs(envs(text), self.pack)) | set(m._extract_slugs_from_text(text, self.known, self.pack))
            self.assertEqual(vendors & self.ambiguous, set(), text)

    def test_the_r9_url_attacks_credit_nothing_in_text_or_in_source_ref(self) -> None:
        spec = json.loads((Path(__file__).parent / "fixtures" / "vendor_url_cases.json").read_text(encoding="utf-8"))
        self.assertEqual(len(spec["neg"]), 70)
        leaks = []
        for text in spec["neg"]:
            words = text.split(" ")
            for row in (text, {"text": text + " Cursor Devin Conductor Tembo Superpowers GSD Codex", "source_ref": words[2] if len(words) > 2 else text}):
                body = row if isinstance(row, str) else row["text"]
                extra = {} if isinstance(row, str) else {"source_ref": row["source_ref"]}
                with m.claim_scope(m._declared_for_row(dict(extra, text=body), self.known, self.pack)):
                    got = set(m._extract_slugs_from_text(body, self.known, self.pack))
                got |= set(sc._envelope_evidence_slugs(envs(body, extra), self.pack))
                if got & self.ambiguous:
                    leaks.append((sorted(got & self.ambiguous), row))
        self.assertEqual(leaks, [], f"{len(leaks)} of 140 rows credit an ambiguous vendor")

    def test_the_r10_url_attacks_credit_nothing(self) -> None:
        spec = json.loads((Path(__file__).parent / "fixtures" / "vendor_url_cases.json").read_text(encoding="utf-8"))
        self.assertEqual(len(spec["neg12"]), 112)
        names = " Cursor Devin Conductor Tembo Superpowers GSD Codex"
        leaks = []
        for _cls, text in spec["neg12"]:
            word = next((w for w in text.split(" ") if "://" in w or "www" in w.lower() or "." in w.strip(".")), text)
            for row in (text, {"text": text + names, "source_ref": word}, {"text": names.strip() + " ship it.", "source_ref": text}):
                body = row if isinstance(row, str) else row["text"]
                extra = {} if isinstance(row, str) else {"source_ref": row["source_ref"]}
                with m.claim_scope(m._declared_for_row(dict(extra, text=body), self.known, self.pack)):
                    got = set(m._extract_slugs_from_text(body, self.known, self.pack))
                got |= set(sc._envelope_evidence_slugs(envs(body, extra), self.pack))
                if got & self.ambiguous:
                    leaks.append((sorted(got & self.ambiguous), str(row)[:120]))
        self.assertEqual(leaks, [], f"{len(leaks)} of 336 rows credit an ambiguous vendor")

    def test_a_pack_url_credits_only_as_the_whole_source_field(self) -> None:
        text = "Cursor ships agents. Devin opens pull requests. Tembo runs jobs."
        for url, vendor in (("https://www.cursor.com/pricing", "cursor"), ("https://devin.ai/", "devin"), ("https://docs.cursor.com/x", "cursor"),
                            ("HTTPS://devin.ai/", "devin"), ("www.tembo.io", "tembo"), ("  https://devin.ai/  ", "devin")):
            self.assertIn(vendor, sc._envelope_evidence_slugs(envs(text, {"source_ref": url}), self.pack), url)
        self.assertIn("devin", sc._envelope_evidence_slugs(envs(text, {"supporting_sources": ["https://devin.ai/"]}), self.pack))
        self.assertIn("devin", sc._envelope_evidence_slugs(envs(text, {"source_url": "https://devin.ai/"}), self.pack))
        for url in ("https://devin.ai/ and more", "see https://devin.ai/", "https://devin.ai/a//b", "https://devin.ai/../x", "https://devin.ai/./x",
                    "cursor.com/pricing", "https://devin.ai:443@mirror.example/", "https://devin.ai%2eexample.org/", "https://Devin.ai/",
                    "https://devin.ai.evil.example/", "javascript:alert('https://devin.ai/')", "https://cursor.com:99999/", "https://cursor.com\\@evil.example/",
                    "https://cursor.com.\u00e9vil.example/"):
            self.assertEqual(sc._envelope_evidence_slugs(envs(text, {"source_ref": url}), self.pack) & {"devin", "cursor", "tembo"}, set(), url)
        # the same URL in running prose credits nothing, in any form
        for prose in ("See https://www.cursor.com/pricing for plans.", "See [Cursor](https://cursor.com/pricing).", "See <https://cursor.com>.",
                      '<a href="https://devin.ai/">Devin</a>', "```\nfetch('https://cursor.com/api')\n```", "Try www.devin.ai today.", "(https://conductor.build/)"):
            got = set(sc._envelope_evidence_slugs(envs(prose), self.pack)) | set(m._extract_slugs_from_text(prose, self.known, self.pack))
            self.assertEqual(got & self.ambiguous, set(), prose)
        self.assertEqual(self.registry.url_slug("cursor.com/pricing"), None)
        self.assertEqual(self.registry.url_slug("https://cursor.com/pricing"), "cursor")

    def test_autogen_is_a_build_tool_name_so_it_needs_a_signal(self) -> None:
        self.assertIn("autogen", self.registry.ambiguous_vendors())
        for text in ("Run ./autogen.sh before ./configure.", "GNU AutoGen generates the option parser.", "The autogen files are checked in."):
            self.assertNotIn("autogen", set(sc._envelope_evidence_slugs(envs(text), self.pack)) | set(m._extract_slugs_from_text(text, self.known, self.pack)), text)
        self.assertTrue(self.credited("autogen", "AutoGen runs agents.", {"vendors": ["autogen"]}))

    def test_the_classification_of_a_vendor_needs_a_declaration_too(self) -> None:
        self.assertNotIn("sweep", sc._envelope_evidence_slugs(envs("Sweep provides workflow composition."), self.pack))
        self.assertIn("sweep", sc._envelope_evidence_slugs(envs("The row names it.", {"vendors": ["sweep"]}), self.pack))

    def test_the_spelling_audit_is_generated_from_the_pack(self) -> None:
        pinned = json.loads((Path(__file__).parent / "fixtures" / "vendor_spelling_audit.json").read_text(encoding="utf-8"))
        self.assertEqual(json.loads(json.dumps(self.registry.audit())), pinned)

    def test_coined_names_are_justified_and_not_english(self) -> None:
        coined = m.COINED_NAMES
        self.assertTrue(coined)
        words = {w.lower() for c in CORPUS if c["kind"] == "plain_english" for w in re.findall(r"[A-Za-z]+", c["text"])}
        words |= {"director", "cursor", "linear", "continue", "factory", "sweep", "devin", "devika", "tembo", "cline", "aider", "deepwork",
                  "conductor", "scout", "harness", "windsurf", "codex", "poolside", "superpowers", "cognition", "copilot"}
        overlay = json.loads((SCRIPTS.parent / "reference" / "category-pack-overlays" / "agentic-sdlc-process-orchestrator.json").read_text(encoding="utf-8"))
        justified = overlay["vocabulary"]["materialize_solution_artifacts.COINED_NAMES"]
        for name in coined:
            self.assertRegex(name, r"^[a-z]+$")
            self.assertNotIn(name, words)
            self.assertTrue(str(justified[name]).strip(), name)
        dictionary = Path("/usr/share/dict/words")
        if dictionary.is_file():
            english = {w.strip().lower() for w in dictionary.read_text(errors="ignore").splitlines()}
            self.assertFalse(coined & english)

    def test_the_context_rules_are_gone(self) -> None:
        for name in ("AMBIGUOUS_NAMES", "PROPER_PHRASES", "PRODUCT_MAKERS", "NON_VENDOR_TERMS", "_has_product_cue", "_CUE_AFTER"):
            self.assertFalse(hasattr(m, name), name)
        overlay = json.loads((SCRIPTS.parent / "reference" / "category-pack-overlays" / "agentic-sdlc-process-orchestrator.json").read_text(encoding="utf-8"))
        for name in ("AMBIGUOUS_NAMES", "PROPER_PHRASES", "PRODUCT_MAKERS", "NON_VENDOR_TERMS"):
            self.assertNotIn(f"materialize_solution_artifacts.{name}", overlay["vocabulary"])

    @unittest.skipUnless(REAL_RUN.is_dir(), "the real APO run is not in this checkout")
    def test_the_real_apo_run_keeps_its_matrix_and_director_core(self) -> None:
        need = json.loads((REAL_RUN / "need_profile.json").read_text(encoding="utf-8"))
        envelopes = json.loads((REAL_RUN / "contributions" / "all-envelopes.json").read_text(encoding="utf-8"))
        audit = sc.classify_solutions(envelopes, need, self.pack)
        self.assertEqual(len(audit["matrix_slugs"]), 23)
        self.assertEqual(audit["by_slug"]["director"]["classification"], "core")

    def test_a_half_capitalised_phrase_and_a_bare_checkmark_for_are_not_products(self) -> None:
        self.assertFalse(m.mentions_vendor("Silver bullet works.", "silver bullet works.", "silver bullet"))
        self.assertFalse(m._parse_checkmark_for_claims({}, "ab ✔ for x"))
        self.assertFalse(m._parse_checkmark_for_claims({}, "no marks here"))

    def test_discovery_judges_names_against_the_runs_products(self) -> None:
        seeds = set(sc.get_all_market_seed_slugs(self.pack, include_adjacent=True))
        found = set(sc.discover_candidate_slugs(envs("Hover the Cursor over the icon. Keyboard, Mouse, Cursor and Touch inputs."), self.pack)) - seeds
        self.assertEqual(found & {"cursor"}, set())

    def test_a_negation_must_govern_the_hard_exclusion_to_keep_the_sentence(self) -> None:
        for text in ("Unlike Director, Sweep and Windsurf are hard exclusions that provide workflow composition.",
                     "Not every tool qualifies: Sweep is a hard exclusion and provides workflow composition."):
            self.assertNotEqual(m._without_absence_clauses(text).strip(), text.strip(), text)
        for text in ("Silver Bullet provides gates and is not on the hard-exclusion list.",
                     "Silver Bullet provides workflow composition, never a hard exclusion."):
            self.assertEqual(m._without_absence_clauses(text), text, text)

    def test_a_gate_verb_must_govern_the_marker_and_a_lead_refers_back(self) -> None:
        for text in ("Deepwork blocks nothing and provides workflow composition with no evidence.",
                     "Deepwork provides workflow composition; however, no independent evidence was found.",
                     "Deepwork provides workflow composition. This is unresearched."):
            self.assertEqual(m._without_absence_clauses(text).strip().count("workflow composition"), 0, text)
        kept = "Silver Bullet provides workflow composition and denies merges without evidence of review."
        self.assertEqual(m._without_absence_clauses(kept), kept)

    def test_parse_feature_support_is_near_linear(self) -> None:
        unit = "Silver Bullet provides workflow composition, but Deepwork has no public evidence. Director ships gates; the Cursor IDE is adjacent. "
        started = time.monotonic()
        self.support(unit * 200)  # about 26 KB
        self.assertLess(time.monotonic() - started, 2.0)

    def test_a_negated_vendor_earns_no_inferred_features_and_the_extract_cache_is_bounded(self) -> None:
        known = self.known
        self.assertTrue(m._negated_right_after_name("Barkain Workflow Orchestrator does not.", "barkain-workflow-orchestrator", known))
        self.assertFalse(m._negated_right_after_name("Barkain does not. Barkain ships.", "barkain-workflow-orchestrator", known))
        self.assertFalse(m._negated_right_after_name("Nobody here.", "barkain-workflow-orchestrator", known))
        m._EXTRACTED.clear()
        for number in range(2050):
            m._extract_slugs_from_text(f"Devin {number}", known, self.pack)
        self.assertLessEqual(len(m._EXTRACTED), 2048)

    def test_the_known_phrases_follow_the_run_and_are_reused(self) -> None:
        phrases = m._known_phrases()
        self.assertIn("claude harness", phrases)
        self.assertIs(m._known_phrases(), phrases)
        with m.run_context({"zed": "Zed Editor"}, None):
            self.assertIn("zed editor", m._known_phrases())
            inside, before = m._vendor_patterns()
            self.assertTrue(inside.search("the Zed Editor ships") and before.search("see Zed Editor "))
        with m.run_context({"ab": "Ab"}, None):  # nothing of 3+ letters: no vendor pattern can match
            inside, before = m._vendor_patterns()
            self.assertEqual((inside.search("Ab ab"), before.search("Ab")), (None, None))
            self.assertEqual(m._without_absence_clauses("No evidence for Ab."), " " * 18 + ".")

    def test_absence_keeps_a_genuine_positive_in_another_clause(self) -> None:
        for case in cases("absence_keep"):
            row = {"vendors": case["vendors"]} if case.get("vendors") else None
            ticks = {f for f, v in self.support(case["text"], row).get(case["slug"], {}).items() if v}
            if case.get("known_miss"):
                self.assertFalse(ticks, case["text"])  # a recall miss (see the case's note), not a false tick
                self.assertTrue(case.get("note"), case["text"])
            else:
                self.assertTrue(ticks, case["text"])

    def test_absence_casts_no_vote_for_the_vendor_it_is_about(self) -> None:
        for case in cases("absence_drop"):
            row = {"vendors": case["vendors"]} if case.get("vendors") else None
            ticks = {f for f, v in self.support(case["text"], row).get(case["slug"], {}).items() if v}
            self.assertFalse(ticks, (case["text"], ticks))

    def test_marker_dense_claims_are_linear(self) -> None:
        for unit in ("Deepwork has no evidence. ", "no evidence, ", "hard exclusion ", "Director, but no evidence ("):
            text = unit * (200_000 // len(unit))
            started = time.monotonic()
            m._without_absence_clauses(text)
            self.assertLess(time.monotonic() - started, 2.0, unit)

    def test_a_blanked_claim_keeps_its_length_and_line_breaks(self) -> None:
        text = "Deepwork has no evidence.\nSilver Bullet provides workflow composition."
        out = m._without_absence_clauses(text)
        self.assertEqual((len(out), out.count("\n")), (len(text), 1))
        self.assertTrue(out.endswith("Silver Bullet provides workflow composition."))


class TaggingContractTests(unittest.TestCase):
    """The contract that lets a worker say which vendors a row is about (the `vendors` field)."""

    def test_the_brief_asks_for_vendor_tags_on_solution_research_only(self) -> None:
        import dr_live_runner as runner
        from category_pack import resolve_pack_from_need

        solution = runner.research_brief("APO landscape", "solution-landscape")
        self.assertIn("Tag every evidence, claim_candidates, critiques and gaps row with vendors", solution)
        self.assertIn("(Director, Cursor, Linear, Devin, ...)", solution)
        self.assertIn("Put the source URL alone in source_ref", solution)
        self.assertNotIn("vendors", runner.research_brief("Why is the sky blue", "general"))
        self.assertNotIn("[CATEGORY_PACK]", solution)  # no pack selected: the tag names come from matrix_entries
        pack = resolve_pack_from_need({"category_pack_id": "agentic-sdlc-process-orchestrator"})
        self.assertIn("the exact slugs from the [CATEGORY_PACK] list", runner.research_brief("APO", "solution-landscape", {}, pack))

    def test_the_pack_block_lists_slugs_to_copy(self) -> None:
        from category_pack import pack_prompt_block, resolve_pack_from_need

        block = pack_prompt_block(resolve_pack_from_need({"category_pack_id": "agentic-sdlc-process-orchestrator"}))
        self.assertIn("Director (`director`)", block)
        self.assertIn("Sweep (`sweep`)", block)

    def test_the_envelope_schema_allows_a_bounded_vendors_array_on_every_claim_row(self) -> None:
        schema = json.loads((SCRIPTS.parent / "schemas" / "dr-phase-contribution-envelope-v1.schema.json").read_text(encoding="utf-8"))
        rows = {key: props[key] for branch in schema["allOf"] for props in [branch["then"]["properties"]["payload"]["properties"]]
                for key in props if key in ("evidence", "claim_candidates", "critiques", "gaps")}
        self.assertEqual(sorted(rows), ["claim_candidates", "critiques", "evidence", "gaps"])
        for key, spec in rows.items():
            vendors = spec["items"]["properties"]["vendors"]
            self.assertEqual((vendors["type"], vendors["maxItems"], vendors["items"]["maxLength"]), ("array", 12, 80), key)


if __name__ == "__main__":
    unittest.main()
