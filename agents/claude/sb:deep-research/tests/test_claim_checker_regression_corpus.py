"""Anti-oscillation regression corpus for the claim-support checker (H8a, review rounds 1-5).

The checker is "conservative + escalate": it returns supported / contradicted / needs_review, and a pair it
cannot settle by its words is needs_review, never supported. Each earlier round added a lexical rule that
fixed the last probes and broke an older pair. This file pins every probe pair of all five rounds in one
table so that a change which trades one class for another fails here:

* a fabrication is never `supported`;
* an honest claim is never `contradicted` or `unsupported`;
* the reviewer's 60 everyday honest claims stay mostly `supported` (needs_review is not routine);
* the named issue classes of round 5 (negation, comparison, role swap, co-occurrence, periods and units,
  ranges, modal cues) each have their own table.

Fixtures (tests/fixtures): claim_corpus_verbatim.json (rounds 1-3), claim_corpus_r4.json (round 4),
claim_corpus_r5.json (round 5, from the probe scripts and TSVs), claim_corpus.json (curated) and
claim_corpus_heldout.json (written after the scorer was frozen).
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
    for name in ("claim_corpus_verbatim", "claim_corpus_r4", "claim_corpus_r5"):
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

    def test_the_everyday_honest_claims_stay_mostly_supported(self):
        everyday = [c for c in load("claim_corpus_r5") if c["kind"] == "H" and c["source"].startswith("r5 score5.py")]
        self.assertEqual(len(everyday), 60)
        counts = {}
        for c in everyday:
            got = status(c["claim"], c["quote"])
            counts[got] = counts.get(got, 0) + 1
        self.assertEqual(counts.get("contradicted", 0) + counts.get("unsupported", 0), 0, counts)
        # needs_review is the escalation path, not the routine one: at most one claim in five.
        self.assertGreaterEqual(counts.get("supported", 0), 48, counts)
        self.assertLessEqual(counts.get("needs_review", 0), 12, counts)


class RoundFiveIssueTables(unittest.TestCase):
    """The round-5 issue classes, each with the fabrications that must escalate and the honest twins that
    must not be contradicted. Entries: (claim, quote)."""

    def assert_escalates(self, table):
        for claim, quote in table:
            self.assertIn(status(claim, quote), ("needs_review", "contradicted"), (claim, quote))

    def assert_supported(self, table):
        for claim, quote in table:
            self.assertEqual(status(claim, quote), "supported", (claim, quote))

    def test_with_no_x_is_without_x(self):
        self.assert_escalates([
            ("Acme offers SCIM", "Acme offers SSO with no SCIM"),
            ("Acme charges a setup fee", "Acme supports SSO on all plans with no setup fee"),
            ("Acme has an offline mode", "Acme ships with no offline mode"),
            ("Acme's migration caused downtime", "Acme migrated its customers with no downtime"),
            ("Acme offers SCIM", "Acme offers SSO without SCIM"),
        ])
        self.assert_supported([
            ("Acme offers a free tier", "Acme offers a free tier with no time limit"),
            ("Acme deploys updates weekly", "Acme deploys updates weekly with no downtime"),
            ("Acme offers SSO with no setup fee", "Acme offers SSO with no setup fee"),
        ])

    def test_no_more_than_is_not_more_than(self):
        self.assert_escalates([
            ("Acme has more than 50 customers", "Acme has no more than 50 customers"),
            ("Acme raised less than $50M in 2023", "Acme raised no less than $50M in 2023"),
            ("Acme has fewer than 500 customers", "Acme has no fewer than 500 customers"),
            ("Acme's uptime is less than 99%", "Acme's uptime is nothing less than 99%"),
            ("Acme has no more than 50 customers", "Acme has more than 50 customers"),
            ("Acme has 500 customers", "Acme has no fewer than 500 customers"),
        ])
        self.assert_supported([("Acme has no more than 50 customers", "Acme has no more than 50 customers")])

    def test_honest_comparison_claims_are_never_contradicted(self):
        for claim, quote in (
            ("Acme supports SCIM and Initech does not", "Acme supports SCIM; Initech does not"),
            ("Acme supports SCIM and Initech does not", "Acme supports SCIM and Initech does not"),
            ("Acme offers SSO and Initech lacks it", "Acme offers SSO, while Initech lacks it"),
            ("Okta supports SAML and OneLogin does not", "Okta supports SAML. OneLogin does not."),
            ("Slack integrates with Jira and Asana does not", "Slack integrates with Jira; Asana does not"),
            ("Acme offers SSO and SCIM, and Initech offers neither", "Acme offers SSO and SCIM, and Initech offers neither"),
            ("Acme supports Kubernetes and Initech does not", "Acme supports Kubernetes, and Initech does not"),
            ("Acme supports SCIM and Initech does not", "Acme supports SCIM, whereas Initech does not"),
        ):
            self.assertNotIn(status(claim, quote), ("contradicted", "unsupported"), (claim, quote))
        for sentence in ("Acme offers SSO and SCIM, and Initech offers neither", "Acme supports SCIM and Initech does not"):
            self.assertEqual(status(sentence, sentence), "supported")

    def test_a_list_does_not_swallow_the_subject_of_the_next_clause(self):
        clause = "Acme supports SCIM and Initech does not"
        self.assertEqual(vcs._variants(clause), [clause])
        self.assertEqual(vcs._variants("Acme offers SSO and SCIM, and Initech offers neither"),
                         ["Acme offers SSO and SCIM, and Initech offers neither",
                          "Acme offers SSO, and Initech offers neither", "Acme offers SCIM, and Initech offers neither"])
        # A genuine list keeps one variant per item.
        self.assertEqual(vcs._variants("Acme supports Kubernetes and Nomad for workloads"),
                         ["Acme supports Kubernetes and Nomad for workloads",
                          "Acme supports Kubernetes for workloads", "Acme supports Nomad for workloads"])

    def test_role_swaps_escalate_whatever_the_gap(self):
        self.assert_escalates([
            ("Initech was acquired by Acme", "Acme was acquired by Initech"),
            ("Acme is a subsidiary of Initech", "Initech is a subsidiary of Acme"),
            ("Acme is owned by Initech", "Initech is owned by Acme"),
            ("Acme is cheaper than Initech", "Initech is cheaper than Acme"),
            ("Acme is faster than Initech on the TPC-H benchmark", "Initech is faster than Acme on the TPC-H benchmark"),
            ("Microsoft invested $10 billion in OpenAI", "OpenAI invested $10 billion in Microsoft"),
            ("Acme licenses its technology to Initech", "Initech licenses its technology to Acme"),
            ("Acme sold its stake in Initech in 2022", "Initech sold its stake in Acme in 2022"),
            ("Acme spun off from Initech in 2019", "Initech spun off from Acme in 2019"),
            ("Acme migrated from Postgres to MySQL", "Acme migrated from MySQL to Postgres"),
            ("Acme replaced Jenkins with GitHub Actions", "Acme replaced GitHub Actions with Jenkins"),
            ("Acme outperformed Initech on every benchmark", "Initech outperformed Acme on every benchmark"),
        ])
        self.assert_supported([
            ("Acme was acquired by Initech in 2022", "In 2022 Acme was acquired by Initech"),
            ("Initech acquired Acme in 2022", "Initech acquired Acme in 2022 for an undisclosed sum"),
            ("Both Acme and Initech support SAML", "Acme and Initech both support SAML"),
        ])

    def test_figures_and_names_must_co_occur_with_the_subject(self):
        self.assert_escalates([
            ("Acme has 500 employees", "Initech has 500 employees and Acme has 200"),
            ("Acme has 500 employees", "Initech has 500 employees. Acme has 200 employees."),
            ("Acme's market share is 30%", "Initech's market share is 30%, while Acme's is 10%"),
            ("Acme raised $50M in 2023", "Initech raised $50M in 2023, and Acme raised $10M in 2023"),
            ("Acme was founded in 2015", "Initech was founded in 2015 and Acme was founded in 2019"),
            ("62% of respondents use Acme", "62% of respondents use Initech and 12% use Acme"),
            ("Acme acquired Initech", "Globex acquired Initech. Acme acquired Hooli."),
            ("Acme supports SCIM", "Okta supports SCIM. Acme supports SAML."),
            ("Acme is SOC 2 certified", "Initech is SOC 2 certified. Acme is ISO 27001 certified."),
            ("Acme was founded in 2019", "Acme (founded 2015) was acquired by Globex in 2019"),
        ])
        self.assert_supported([
            ("Acme was founded in 2015", "Founded in 2015, Acme now employs 400 people"),
            ("Acme's revenue grew 40% year over year", "Revenue grew 40% year over year, Acme said"),
            ("Acme holds a 30% market share", "Acme holds a 30% share of the market, according to IDC"),
        ])

    def test_periods_and_units_are_bound_like_years(self):
        self.assert_escalates([
            ("Acme revenue grew 30% in Q3", "Acme revenue grew 30% in Q2 and 10% in Q3"),
            ("Acme revenue grew 30% in Q3", "Acme revenue grew 30% in Q2"),
            ("Acme costs $20 per month", "Acme costs $20 per year"),
            ("Acme costs $20 per user", "Acme costs $20 per team"),
            ("Acme booked $5M in H1", "Acme booked $5M in H2"),
        ])
        self.assert_supported([
            ("Acme revenue grew 30% in Q3", "Acme revenue grew 30% in Q3"),
            ("Acme costs $20 per user per month", "Acme's Pro plan costs $20 per user per month, billed annually"),
            ("Acme is downloaded 5 million times per week on npm", "Acme is downloaded about 5 million times a week from npm"),
        ])

    def test_a_lone_one_starts_a_range(self):
        n = vcs.normalize_text
        self.assertEqual(n("one or two"), "1 or 2")
        self.assertEqual(n("one to three days"), "1 to 3 days")
        self.assertEqual(n("between one and three days"), "between 1 and 3 days")
        self.assertEqual(n("one who knows"), "one who knows")
        self.assertEqual(n("zero downtime"), "zero downtime")
        self.assertEqual(n("one-to-one"), "one-to-one")
        self.assertEqual(n("one to many"), "one to many")
        self.assert_escalates([("Setup takes 3 days", "Setup takes one to three days"),
                               ("Setup takes 3 days", "Setup takes 1 to 3 days")])
        self.assert_supported([("Setup takes one to three days", "Setup takes 1 to 3 days")])

    def test_future_and_modal_cues_escalate_and_failure_cues_negate(self):
        self.assert_escalates([
            ("Acme supports SSO", "Acme plans to support SSO in 2025"),
            ("Acme supports SCIM provisioning", "Acme will support SCIM provisioning next year"),
            ("Acme raised $50M in 2023", "Acme is expected to raise $50M in 2023"),
            ("Acme supports SSO", "Acme aims to support SSO"),
            ("Initech acquired Acme", "Initech is considering acquiring Acme"),
            ("Acme supports SSO", "Acme supports SSO only if customers buy the enterprise add-on"),
            ("Acme supports SSO", "Does Acme support SSO? The documentation does not say."),
            ("Acme Cloud is SOC 2 Type II certified", "Acme Cloud is pursuing SOC 2 Type II certification"),
        ])
        for claim, quote in (("Acme passed the SOC 2 audit", "Acme failed to pass the SOC 2 audit"),
                             ("Acme supports SSO", "Acme refused to support SSO"),
                             ("Acme met its 2023 revenue target", "Acme failed to meet its 2023 revenue target")):
            self.assertIn(status(claim, quote), ("contradicted", "needs_review"), claim)
            self.assertTrue(vcs._is_negated(quote), quote)
        # The claim states the plan itself: an honest match.
        self.assert_supported([("Acme plans to support SSO in 2025", "Acme plans to support SSO in 2025")])

    def test_remaining_probe_idioms_escalate(self):
        self.assert_escalates([
            ("Acme supports SSO", "Acme hardly supports SSO"),
            ("Acme is HIPAA compliant", "Acme is HIPAA non-compliant"),
            ("Acme stores backups encrypted", "Acme stores backups unencrypted"),
            ("Acme supports SSO on the free plan", "Acme supports SSO on every plan except the free plan"),
            ("Acme offers phone support", "Nobody at Acme offers phone support"),
            ("Acme uses Postgres", "Acme uses MySQL instead of Postgres"),
            ("Acme uses Postgres", "Acme uses MySQL rather than Postgres"),
            ("Acme uses Postgres", "Acme replaced Postgres with MySQL in 2022"),
            ("Acme no longer offers a free tier", "Acme offers a free tier for up to 5 users"),
            ("Acme is profitable", "Acme is not just unprofitable; it is insolvent"),
        ])


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
