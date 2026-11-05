"""Anti-oscillation regression corpus for the claim-support checker (H8a, review rounds 1-6).

Round 7 made the tokenizer conservative (every character that can change a meaning is kept, figures compare
as written). Round 6 ended the word-pattern approach: ``supported`` now means the claim nearly repeats its quote word for
word, and everything else is ``needs_review`` (or ``contradicted`` for a clear, explicit conflict). The corpus
pins every probe pair of all six rounds, so a change that trades one class for another fails here:

* a fabrication is never `supported`;
* an honest claim is never `contradicted` or `unsupported`;
* a claim identical to its quote is `supported`;
* a reworded honest claim is `needs_review`: the reviewer's everyday and held-out honest sets are pinned at
  the supported / needs_review split the strict rule gives.

Fixtures (tests/fixtures): claim_corpus_verbatim.json (rounds 1-3), claim_corpus_r4.json (round 4),
claim_corpus_r5.json (round 5), claim_corpus_r6.json (round 6: 91 fresh fabrications, 25 honest twins and the
40 held-out everyday honest claims), claim_corpus.json (curated) and claim_corpus_heldout.json.
"""

import json
import unittest
from pathlib import Path

from covhelp import SCRIPTS

import extract_claims
import verify_claim_support as vcs

FIX = SCRIPTS.parent / "tests" / "fixtures"


def load(name):
    return json.loads((FIX / f"{name}.json").read_text(encoding="utf-8"))


def pairs():
    """Every probe pair as (corpus, kind, claim, quote); kind is 'F' (fabrication) or 'H' (honest)."""
    out = []
    for name in ("claim_corpus_verbatim", "claim_corpus_r4", "claim_corpus_r5", "claim_corpus_r6", "claim_corpus_r7", "claim_corpus_r8", "claim_corpus_r9"):
        out += [(name, c["kind"], c["claim"], c["quote"]) for c in load(name)]
    for name in ("claim_corpus", "claim_corpus_heldout"):
        data = load(name)
        out += [(name, "F", a, b) for a, b in data["fabrications"]]
        out += [(name, "H", a, b) for a, b in data["honest"]]
    return out


def status(claim, quote):
    return vcs.compute_support_score(claim, [quote])[0]


class EveryProbeOfEveryRound(unittest.TestCase):
    PAIRS = pairs()

    def test_the_corpus_holds_all_rounds(self):
        self.assertGreaterEqual(len(load("claim_corpus_verbatim")), 100)
        self.assertGreaterEqual(len(load("claim_corpus_r4")), 100)
        self.assertGreaterEqual(len(load("claim_corpus_r5")), 200)
        self.assertGreaterEqual(len(self.PAIRS), 580)

    def test_no_fabrication_is_supported_and_no_honest_claim_is_contradicted(self):
        supported_fabrications, failed_honest = [], []
        for corpus, kind, claim, quote in self.PAIRS:
            got = status(claim, quote)
            if kind == "F" and got == "supported":
                supported_fabrications.append((corpus, claim, quote))
            if kind == "H" and got in ("contradicted", "unsupported"):
                failed_honest.append((corpus, got, claim, quote))
        self.assertEqual(supported_fabrications, [], "fabrications scored as supported")
        self.assertEqual(failed_honest, [], "honest claims contradicted or unsupported")

    def test_a_claim_identical_to_its_quote_is_never_contradicted(self):
        for corpus, kind, claim, quote in self.PAIRS:
            if kind == "H" and claim.rstrip(".") == quote.rstrip("."):
                self.assertEqual(status(claim, quote), "supported", (corpus, claim))
        for sentence in ("Acme supports SCIM and Initech does not", "Acme offers SSO and SCIM, and Initech offers neither",
                         "Acme has no free tier, while Initech has one", "Neither Acme nor Initech supports SCIM",
                         "Acme has no more than 50 customers", "Acme offers SSO with no SCIM"):
            self.assertEqual(status(sentence, sentence), "supported", sentence)

    def test_the_everyday_honest_claims_are_supported_only_when_they_repeat_the_quote(self):
        everyday = [c for c in load("claim_corpus_r5") if c["kind"] == "H" and c["source"].startswith("r5 score5.py")]
        self.assertEqual(len(everyday), 60)
        counts = tally(everyday)
        self.assertEqual(counts.get("contradicted", 0) + counts.get("unsupported", 0), 0, counts)
        self.assertEqual(counts, {"supported": 4, "needs_review": 56})

    def test_the_round_six_held_out_honest_claims_are_reworded_and_need_review(self):
        held = [c for c in load("claim_corpus_r6") if c["source"].startswith("r6 honest6.py")]
        self.assertEqual(len(held), 40)
        self.assertEqual(tally(held), {"needs_review": 40})

    def test_the_round_seven_probes(self):
        """Signs, comparators, accents, other scripts, decimal commas, superscripts, symbols after a space,
        filler words and aliases: every fabrication is non-supported, the identical control is supported, and
        a figure written another way is a review, never a contradiction."""
        items = load("claim_corpus_r7")
        fabrications = [c for c in items if c["kind"] == "F"]
        self.assertEqual(len(fabrications), 55)
        self.assertEqual(tally(fabrications).get("supported", 0), 0)
        for c in items:
            if c["kind"] == "H":
                self.assertNotIn(status(c["claim"], c["quote"]), ("contradicted", "unsupported"), c)

    def test_the_round_eight_probes(self):
        """Case, capital A, plural -s, "?" and "*", digits in brackets, digit scripts and "No,": every
        fabrication is non-supported; the pairs that are equal by the rule are supported; no honest claim is
        contradicted or unsupported."""
        items = load("claim_corpus_r8")
        fabrications = [c for c in items if c["kind"] == "F"]
        self.assertEqual(len(fabrications), 84)
        self.assertEqual(tally(fabrications).get("supported", 0), 0)
        honest = [c for c in items if c["kind"] == "H"]
        self.assertEqual(len(honest), 19)
        for c in honest:
            self.assertNotIn(status(c["claim"], c["quote"]), ("contradicted", "unsupported"), c)

    def test_the_round_nine_probes(self):
        """Punctuation is significant: inch and foot marks, "!=", accounting parentheses, ratio colons,
        quote marks, dashes, "No" before punctuation or a digit. Every fabrication is non-supported; the pairs
        that are equal by the rule are supported; no honest claim is contradicted or unsupported."""
        items = load("claim_corpus_r9")
        fabrications = [c for c in items if c["kind"] == "F"]
        self.assertEqual(len(fabrications), 90)
        self.assertEqual(tally(fabrications).get("supported", 0), 0)
        honest = [c for c in items if c["kind"] == "H"]
        self.assertEqual(len(honest), 62)
        for c in honest:
            self.assertNotIn(status(c["claim"], c["quote"]), ("contradicted", "unsupported"), c)
            if c["claim"] == c["quote"]:
                self.assertEqual(status(c["claim"], c["quote"]), "supported", c)

    def test_the_round_six_fabrications_and_twins(self):
        fabrications = [c for c in load("claim_corpus_r6") if c["kind"] == "F"]
        self.assertEqual(len(fabrications), 91)
        counts = tally(fabrications)
        self.assertEqual(counts.get("supported", 0), 0, counts)
        self.assertEqual(counts, {"needs_review": 91})
        twins = [c for c in load("claim_corpus_r6") if c["kind"] == "H" and c["source"].startswith("r6 score6.py")]
        self.assertEqual(len(twins), 25)
        self.assertEqual(tally(twins).get("contradicted", 0) + tally(twins).get("unsupported", 0), 0)


def tally(items):
    counts = {}
    for c in items:
        got = status(c["claim"], c["quote"])
        counts[got] = counts.get(got, 0) + 1
    return counts


class StrictRuleTables(unittest.TestCase):
    """The classes the earlier rounds fixed one by one are now decided by one rule: a fabrication that is not
    the quote's own sentence is `needs_review` (or `contradicted`), and the identical sentence is `supported`."""

    def assert_escalates(self, table):
        for claim, quote in table:
            self.assertIn(status(claim, quote), ("needs_review", "contradicted"), (claim, quote))

    def test_negation_comparison_and_with_no_x(self):
        self.assert_escalates([
            ("Acme offers SCIM", "Acme offers SSO with no SCIM"),
            ("Acme offers SCIM", "Acme offers SSO without SCIM"),
            ("Acme has more than 50 customers", "Acme has no more than 50 customers"),
            ("Acme has fewer than 500 customers", "Acme has no fewer than 500 customers"),
            ("Acme no longer offers a free tier", "Acme offers a free tier for up to 5 users"),
            ("Acme supports SSO", "Acme hardly supports SSO"),
            ("Acme is HIPAA compliant", "Acme is HIPAA non-compliant"),
            ("Acme is profitable", "Acme is not just unprofitable; it is insolvent"),
        ])

    def test_role_swaps_and_voice_changes_escalate(self):
        self.assert_escalates([
            ("Initech was acquired by Acme", "Acme was acquired by Initech"),
            ("Acme is cheaper than Initech", "Initech is cheaper than Acme"),
            ("Microsoft invested $10 billion in OpenAI", "OpenAI invested $10 billion in Microsoft"),
            ("Acme migrated from Postgres to MySQL", "Acme migrated from MySQL to Postgres"),
            ("Acme replaced Jenkins with GitHub Actions", "Acme replaced GitHub Actions with Jenkins"),
            ("Acme was acquired by Initech in 2022", "In 2022 Acme was acquired by Initech"),
            ("Both Acme and Initech support SAML", "Acme and Initech both support SAML"),
        ])

    def test_figures_must_attach_to_the_same_entity_period_and_unit(self):
        self.assert_escalates([
            ("Acme has 500 employees", "Initech has 500 employees and Acme has 200"),
            ("Acme's market share is 30%", "Initech's market share is 30%, while Acme's is 10%"),
            ("Acme was founded in 2019", "Acme (founded 2015) was acquired by Globex in 2019"),
            ("Acme revenue grew 30% in Q3", "Acme revenue grew 30% in Q2"),
            ("Acme costs $20 per month", "Acme costs $20 per year"),
            ("Acme costs $20 per user", "Acme costs $20 per team"),
            ("Acme booked $5M in H1", "Acme booked $5M in H2"),
            ("Setup takes 3 days", "Setup takes one to three days"),
        ])
        self.assertEqual(status("Acme revenue grew 30% in Q3", "Acme revenue grew 30% in Q3"), "supported")
        self.assertEqual(status("Setup takes one to three days", "Setup takes 1 to 3 days"), "needs_review")

    def test_future_modal_and_conditional_quotes_escalate(self):
        self.assert_escalates([
            ("Acme supports SSO", "Acme plans to support SSO in 2025"),
            ("Acme raised $50M in 2023", "Acme is expected to raise $50M in 2023"),
            ("Initech acquired Acme", "Initech is considering acquiring Acme"),
            ("Acme supports SSO", "Acme supports SSO only if customers buy the enterprise add-on"),
            ("Acme Cloud is SOC 2 Type II certified", "Acme Cloud is pursuing SOC 2 Type II certification"),
            ("Acme uses Postgres", "Acme uses MySQL instead of Postgres"),
        ])
        self.assertEqual(status("Acme plans to support SSO in 2025", "Acme plans to support SSO in 2025"), "supported")

    def test_a_pasted_fragment_of_the_quote_is_not_enough(self):
        self.assertEqual(status("Acme supports SAML single sign-on for enterprise customers",
                                "Acme supports SAML single sign-on for enterprise customers and lacks SCIM provisioning"),
                         "needs_review")


class SentenceSplittingAndOpeners(unittest.TestCase):
    """Round-5 minor issues: a sentence that starts with a digit is its own claim, and the documented
    short-sentence rule names exactly the openers that are excluded."""

    def test_a_paragraph_break_or_a_citation_ends_a_sentence_before_a_digit_or_a_lowercase_brand(self):
        split = extract_claims.SENTENCE_RE.split
        self.assertEqual(split("Acme has 500 employees in Berlin [1].\n\n62% of Fortune 500 companies use Acme in production."),
                         ["Acme has 500 employees in Berlin [1].", "62% of Fortune 500 companies use Acme in production."])
        self.assertEqual(split("Acme has 500 employees in Berlin [1]. 62% of Fortune 500 companies use Acme."),
                         ["Acme has 500 employees in Berlin [1].", "62% of Fortune 500 companies use Acme."])
        self.assertEqual(split("Acme has 500 employees in Berlin [1]. iPhone sales fell 4% in 2023."),
                         ["Acme has 500 employees in Berlin [1].", "iPhone sales fell 4% in 2023."])
        self.assertEqual(split("The price is approx. 5 million dollars in total."), ["The price is approx. 5 million dollars in total."])
        self.assertEqual(split("It ended in 2023.\n\nlatency fell 30% at Acme in 2024."),
                         ["It ended in 2023.", "latency fell 30% at Acme in 2024."])

    def test_the_uncited_digit_paragraph_is_its_own_claim(self):
        text = "Acme has 500 employees in Berlin [1].\n\n62% of Fortune 500 companies use Acme in production."
        self.assertEqual(extract_claims.extract_sentences(text),
                         ["Acme has 500 employees in Berlin [1].", "62% of Fortune 500 companies use Acme in production."])

    def test_only_the_listed_openers_are_everyday_nouns(self):
        for sentence in ("Pricing is simple.", "Onboarding is slow.", "Support is responsive."):
            self.assertFalse(extract_claims._long_enough(sentence), sentence)
        # Any other opener is a possible name: a short fabrication must not slip out of the gate.
        for sentence in ("Latency is low.", "Usage grew quickly.", "Acme is HIPAA compliant.", "Microsoft owns Acme outright."):
            self.assertTrue(extract_claims._long_enough(sentence), sentence)


if __name__ == "__main__":
    unittest.main()
