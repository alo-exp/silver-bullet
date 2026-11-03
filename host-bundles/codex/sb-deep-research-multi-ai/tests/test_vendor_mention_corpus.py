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
             "claude-harness", "harness", "sweep", "cursor-agents", "factory", "github-copilot", "devin", "aider",
             "copilot-workspace", "windsurf", "codex", "cline", "poolside", "superpowers", "silver-bullet",
             "augment-cosmos", "open-interpreter", "deepwork", "tembo", "spec-kit", "magic-dev", "openhands"}
EXPECTED_COUNTS = {"r4_false_positive": 14, "r2_false_positive": 31, "round1_recall": 26, "absence_keep": 23,
                   "absence_drop": 14, "r3_false_positive": 52, "r3b_false_positive": 25, "r3_recall": 24,
                   "r3_absence": 34, "r1_absence": 7, "copilot": 7, "r4b_false_positive": 52,
                   "r4c_false_positive": 30, "r4_recall": 25, "r4_absence": 24, "r4_absence_plain": 17}


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
        self.assertEqual(len([c for c in CORPUS if c["set"].endswith("false_positive")]), 204)

    def test_plain_english_credits_no_vendor(self) -> None:
        failures = []
        for case in cases("plain_english"):
            text = case["text"]
            hits = (set(sc._envelope_evidence_slugs(envs(text), self.pack)) | set(m._extract_slugs_from_text(text, self.known, self.pack))
                    | set(self.support(text))) & AMBIGUOUS
            if hits != set(case.get("residual", ())):  # a person's first name (Devin) is a documented residual
                failures.append((sorted(hits), text))
        self.assertEqual(failures, [], f"{len(failures)} false vendor mentions")

    def test_recall_cases_count_and_the_known_misses_are_listed(self) -> None:
        recall = cases("vendor")
        missed = [c["text"] for c in recall if not self.credited(c["slug"], c["text"])]
        listed = [c["text"] for c in recall if c.get("known_miss")]
        self.assertEqual(sorted(missed), sorted(listed))
        self.assertEqual((len(recall), len(missed)), (81, 55))  # the misses are exactly the ones the fixture lists

    def test_an_ambiguous_name_needs_an_explicit_product_cue(self) -> None:
        yes = (("We tried Cursor IDE today.", "cursor"), ("Cursor extension adds chat.", "cursor"), ("Continue.dev supports local models.", "continue"),
               ("Director 2.0 adds gates.", "director"), ("See https://cursor.com/pricing for plans.", "cursor"),
               ("Melty Conductor orchestrates parallel agents.", "conductor"), ("Factory Droids ship PRs.", "factory"),
               ("The leaders are Conductor, cc10x and Director.", "director"), ("Hard exclusions (never in-scope): Cursor Background Agents, Sweep, Windsurf.", "windsurf"),
               ("Claude Code, Codex and Cursor ship hooks.", "cursor"), ("Silver Bullet uses deterministic gates.", "silver bullet"),
               ("Conductor (Melty Labs) runs agents.", "conductor"), ("Cursor by Anysphere is an editor.", "cursor"),
               ("Cursor v2 changed the panel.", "cursor"))
        for text, name in yes:
            self.assertTrue(m.mentions_vendor(text, text.lower(), name), text)
        no = (("Hover the Cursor over the chart.", "cursor"), ("Teams that use Cursor report faster refactors.", "cursor"),
              ("Director orchestrates parallel agents.", "director"), ("Netflix Conductor and Temporal schedule jobs.", "conductor"),
              ("Melty Conductor tracks distort when warm.", "conductor"), ("There is no Silver Bullet Thinking Is a Myth.", "silver bullet"),
              ("No Silver Bullet: Essence and Accident.", "silver bullet"), ("Keyboard, Mouse, Cursor and Touch events.", "cursor"),
              ("Growth is Linear for small inputs.", "linear"), ("the Director agent assigns tasks", "director"),
              ("Ask Director (see below).", "director"), ("Press Continue v.", "continue"), ("Factory 2 workers", "factory"))
        for text, name in no:
            self.assertFalse(m.mentions_vendor(text, text.lower(), name), text)

    def test_a_half_capitalised_phrase_and_a_bare_checkmark_for_are_not_products(self) -> None:
        self.assertFalse(m.mentions_vendor("Silver bullet works.", "silver bullet works.", "silver bullet"))
        self.assertFalse(m._parse_checkmark_for_claims({}, "ab ✔ for x"))
        self.assertFalse(m._parse_checkmark_for_claims({}, "no marks here"))

    def test_the_audited_english_word_names_are_ambiguous(self) -> None:
        wanted = {"copilot", "cognition", "aider", "superpowers", "poolside", "windsurf", "codex", "silver bullet", "augment code",
                  "open interpreter", "cline", "deepwork", "tembo", "magic dev", "spec kit", "open hands", "all hands", "workflow manager", "omp"}
        self.assertLessEqual(wanted, m.AMBIGUOUS_NAMES)
        self.assertLessEqual(m.PROPER_PHRASES, m.AMBIGUOUS_NAMES)

    def test_discovery_judges_names_against_the_runs_products(self) -> None:
        seeds = set(sc.get_all_market_seed_slugs(self.pack, include_adjacent=True))
        found = set(sc.discover_candidate_slugs(envs("Hover the Cursor over the icon. Keyboard, Mouse, Cursor and Touch inputs."), self.pack)) - seeds
        self.assertEqual(found & {"cursor"}, set())

    def test_lower_case_common_words_that_are_product_names_credit_nothing(self) -> None:
        self.assertTrue({"copilot", "cognition", "aider", "superpowers", "poolside"} <= m.AMBIGUOUS_NAMES)
        for text in ("An AI copilot for spreadsheets drafts formulas.", "Research on human cognition shows memory limits.",
                     "A good aider makes the job easier.", "Gives developers superpowers."):
            self.assertEqual(sc._envelope_evidence_slugs(envs(text), self.pack), set(), text)
            self.assertEqual(m._extract_slugs_from_text(text, self.known, self.pack), [], text)

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
            ticks = {f for f, v in self.support(case["text"]).get(case["slug"], {}).items() if v}
            if case.get("known_miss"):
                self.assertFalse(ticks, case["text"])  # a recall miss (see the case's note), not a false tick
                self.assertTrue(case.get("note"), case["text"])
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
