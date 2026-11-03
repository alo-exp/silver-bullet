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
import time
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

import materialize_solution_artifacts as m  # noqa: E402
import solution_classifier as sc  # noqa: E402
from apo_pack_run_fixture import with_apo_pack_run  # noqa: E402

CORPUS = json.loads((Path(__file__).parent / "fixtures" / "vendor_mention_corpus.json").read_text(encoding="utf-8"))
AMBIGUOUS = {"director", "factory-ai", "cursor", "continue", "linear", "conductor", "cognition-scout", "scout",
             "claude-harness", "harness", "sweep", "cursor-agents", "factory"}
EXPECTED_COUNTS = {"r4_false_positive": 14, "r2_false_positive": 31, "round1_recall": 26,
                   "absence_keep": 23, "absence_drop": 14}
MIN_RECALL = 23


def envs(text):
    return [{"phase_id": "DR-TRIANGULATE", "logical_model_id": "m", "payload": {"claim_candidates": [{"text": text}]}}]


def cases(kind):
    return [c for c in CORPUS if c["kind"] == kind]


@with_apo_pack_run
class VendorMentionCorpusTests(unittest.TestCase):
    def setUp(self) -> None:
        from category_pack import build_known_solutions, resolve_pack_from_need

        self.pack = resolve_pack_from_need({"category_pack_id": "agentic-sdlc-process-orchestrator"})
        self.known = build_known_solutions(self.pack)

    def support(self, text):
        return m.parse_feature_support(envs(text), known=self.known, pack=self.pack)

    def credited(self, slug, text):
        return (slug in sc._envelope_evidence_slugs(envs(text), self.pack)
                and slug in m._extract_slugs_from_text(text, self.known, self.pack))

    def test_the_corpus_has_every_probed_sentence(self) -> None:
        self.assertEqual(dict(collections.Counter(c["set"] for c in CORPUS)), EXPECTED_COUNTS)
        self.assertEqual(len({c["text"] for c in CORPUS if c["set"].endswith("false_positive")}), 45)

    def test_plain_english_credits_no_vendor(self) -> None:
        failures = []
        for case in cases("plain_english"):
            text = case["text"]
            hits = (set(sc._envelope_evidence_slugs(envs(text), self.pack)) | set(m._extract_slugs_from_text(text, self.known, self.pack))
                    | set(self.support(text))) & AMBIGUOUS
            if hits:
                failures.append((sorted(hits), text))
        self.assertEqual(failures, [], f"{len(failures)} false vendor mentions")

    def test_recall_cases_count_and_the_known_misses_are_listed(self) -> None:
        recall = cases("vendor")
        missed = [c["text"] for c in recall if not self.credited(c["slug"], c["text"])]
        listed = [c["text"] for c in recall if c.get("known_miss")]
        self.assertEqual(sorted(missed), sorted(listed))
        self.assertGreaterEqual(len(recall) - len(missed), MIN_RECALL)

    def test_the_vendors_stay_when_the_name_is_qualified_by_its_maker_or_a_known_product_name(self) -> None:
        self.assertTrue(m.mentions_vendor("Melty Conductor runs agents.", "melty conductor runs agents.", "conductor"))
        self.assertTrue(m.mentions_vendor("Claude Harness is a pack.", "claude harness is a pack.", "harness"))
        self.assertFalse(m.mentions_vendor("Netflix Conductor orchestrates services.", "netflix conductor orchestrates services.", "conductor"))

    def test_a_sentence_opener_makes_the_name_need_a_verb(self) -> None:
        for text in ("Notably Director enforces review gates.", "Then Director orchestrates agents."):
            self.assertTrue(self.credited("director", text), text)
        for text in ("Plus Director approval is needed.", "Daily Linear sync keeps issues current.",
                     "Weekly Director reviews are held on Fridays."):
            self.assertFalse(self.credited(text.split()[1].lower(), text), text)

    def test_a_capitalised_adverb_inside_a_sentence_is_a_qualifier_not_an_opener(self) -> None:
        for text, name in (("We joined the Daily Linear sync.", "linear"), ("See the Weekly Director review.", "director")):
            self.assertFalse(m.mentions_vendor(text, text.lower(), name), text)
        self.assertTrue(m.mentions_vendor("We use Anysphere Cursor daily.", "we use anysphere cursor daily.", "cursor"))

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
            ticks = {f for f, v in self.support(case["text"]).get(case["slug"], {}).items() if v}
            if case.get("known_miss"):
                self.assertFalse(ticks, case["text"])  # a name that opens a sentence needs a verb: recall miss, not a false tick
            else:
                self.assertTrue(ticks, case["text"])

    def test_absence_casts_no_vote_for_the_vendor_it_is_about(self) -> None:
        for case in cases("absence_drop"):
            ticks = {f for f, v in self.support(case["text"]).get(case["slug"], {}).items() if v}
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


if __name__ == "__main__":
    unittest.main()
