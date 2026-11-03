"""The strict near-quote rule of the claim checker (H8a, review round 6 and the user decision after it).

``supported`` only when the claim repeats the cited quote word for word: case, punctuation, articles, simple
inflection, a tiny alias table and the written form of a number may differ, nothing else. Any rewording,
reordering, voice change or paraphrase is ``needs_review``. ``contradicted`` only for an explicit
"not"/"never" added or removed, or one exact figure replaced by another of the same kind.
"""

import unittest

from covhelp import SCRIPTS  # noqa: F401  (puts the scripts directory on sys.path)

import verify_claim_support as vcs


def verdict(claim, *quotes):
    return vcs.compute_support_score(claim, list(quotes))


def status(claim, *quotes):
    return verdict(claim, *quotes)[0]


class SupportedOnlyForANearQuote(unittest.TestCase):
    def assert_supported(self, claim, quote):
        self.assertEqual(verdict(claim, quote), ("supported", 1.0, "near-verbatim match"), (claim, quote))

    def test_identical_text(self):
        for sentence in ("Acme supports SSO", "Acme supports SCIM and Initech does not",
                         "Acme offers SSO and SCIM, and Initech offers neither", "Acme has no more than 50 customers",
                         "Acme offers SSO with no SCIM", "Acme does not offer an on-premises version"):
            self.assert_supported(sentence, sentence)

    def test_case_punctuation_and_stopwords_may_differ(self):
        self.assert_supported("acme SUPPORTS sso!", "Acme supports SSO.")
        self.assert_supported("Acme integrates with Slack, Jira and GitHub", "Acme integrates with Slack Jira and GitHub")
        self.assert_supported("Acme has the free tier", "Acme has a free tier")
        self.assert_supported("Acme also lists its prices", "Acme lists prices")
        self.assert_supported("Acme shipped [3] the product", "Acme shipped the product")  # a citation marker is no word
        self.assert_supported("Acme’s CEO resigned", "Acme's CEO resigned")

    def test_simple_inflection_may_differ(self):
        self.assert_supported("Acme ships two products", "Acme shipped two product")
        self.assert_supported("Acme supports single sign-on", "Acme supporting single sign-on")
        self.assert_supported("Acme lists companies", "Acme listed company")
        self.assert_supported("Acme runs on switches", "Acme run on switch")
        self.assert_supported("Acme employs staff", "Acme employs employees")
        self.assert_supported("Acme serves clients", "Acme serves customers")

    def test_the_written_form_of_a_number_may_differ(self):
        self.assert_supported("Acme grew 40 percent", "Acme grew 40%")
        self.assert_supported("Acme raised USD 50 million", "Acme raised $50 million")
        self.assert_supported("Acme has five thousand customers", "Acme has 5,000 customers")
        self.assert_supported("Setup takes three to five days", "Setup takes 3 to 5 days")
        self.assert_supported("Acme runs Kubernetes v1.29", "Acme runs Kubernetes 1.29")
        self.assert_supported("Acme is free at no cost", "Acme is free for free")

    def test_a_negation_is_part_of_the_words(self):
        self.assert_supported("Acme doesn't support SSO", "Acme does not support SSO")
        self.assert_supported("Acme cannot export data", "Acme can not export data")
        self.assert_supported("Acme won't ship it", "Acme will not ship it")

    def test_every_other_difference_goes_to_a_reader(self):
        for claim, quote in (
            ("Acme is acquired by Initech", "Initech acquires Acme"),                       # voice change
            ("Initech acquired Acme", "Acme acquired Initech"),                              # roles swapped
            ("Acme was acquired by Initech in 2022", "In 2022 Acme was acquired by Initech"),  # reordered
            ("Acme lacks SCIM provisioning", "Acme does not support SCIM provisioning"),     # paraphrase
            ("Acme employs about 400 people", "Acme employs roughly 400 people"),            # near synonym
            ("Acme sells licenses", "Acme sold licences"),                                   # spelling variant
            ("Acme's revenue grew 40%", "Acme's revenue rose 40%"),                          # other verb
            ("Acme supports SSO", "Acme will support SSO"),                                  # added modal
            ("Acme supports SSO", "Acme supports SSO only on paper"),                        # added qualifier
            ("Acme supports SSO", "Acme supports SSO: No"),
            ("Acme supports SSO", "Acme supports SSO? No."),
            ("Acme is SOC 2 certified", "Acme is SOC 2 certified. Not true."),
            ("Acme supports SSO", "Myth: Acme supports SSO."),
            ("Acme acquired Initech", "According to rumors, Acme acquired Initech"),
            ("Acme is HIPAA compliant", "Acme is HIPAA compliant in name only"),
            ("Acme supports SSO", "Acme supported SSO until 2022"),
            ("Acme offers phone support", "Nobody at Acme offers phone support"),
            ("Acme has 500 employees", "Initech has 500 employees and Acme has 200"),
            ("Acme costs $20 per month", "Acme costs $20 per year"),
            ("Acme revenue grew 30% in Q3", "Acme revenue grew 30% in Q2 and 10% in Q3"),
            ("Acme raised $50M in 2023", "Acme raised A$50M in 2023"),
            ("Acme has 3 offices", "Acme has 3+ offices"),
            ("Acme grew 3%", "Acme grew 3"),
        ):
            self.assertEqual(status(claim, quote), "needs_review", (claim, quote))

    def test_a_claim_that_is_only_part_of_the_quote_or_says_more_is_not_supported(self):
        self.assertEqual(verdict("Acme offers SSO", "Acme offers SSO on all plans")[2],
                         "the claim repeats only part of the source text: quote just the span that supports it, "
                         "or make the claim say all of it")
        self.assertEqual(verdict("Acme offers SSO on all plans", "Acme offers SSO")[2],
                         "the claim says more than the source text: the extra words are not in the quote")
        self.assertEqual(verdict("Acme acquired Initech", "Initech acquired Acme")[2],
                         "the source has the same words in a different order (reordered or changed voice)")
        self.assertEqual(verdict("Acme employs about 400 people", "Acme employs roughly 400 staff")[2],
                         "reworded, not a near-quote: 60% of the claim's words are in the source")

    def test_a_claim_without_words_is_never_supported(self):
        self.assertEqual(verdict("The [1] a", "The a"), ("needs_review", 0.0, "the claim has no words to check"))


class ContradictedOnlyWhenClear(unittest.TestCase):
    def test_an_explicit_negation_added_or_removed(self):
        for claim, quote in (("Acme supports SSO", "Acme does not support SSO"),
                             ("Acme does not support SSO", "Acme supports SSO"),
                             ("Acme encrypts backups", "Acme never encrypted backups"),
                             ("Acme can export data", "Acme cannot export data"),
                             ("Acme is cheaper than Initech", "Acme isn't cheaper than Initech"),
                             ("Acme did not ship it", "Acme shipped it")):
            got = verdict(claim, quote)
            self.assertEqual(got[0], "contradicted", (claim, quote))
        self.assertEqual(verdict("Acme supports SSO", "Acme does not support SSO")[2], "the source negates what the claim says")
        self.assertEqual(verdict("Acme does not support SSO", "Acme supports SSO")[2], "the claim negates what the source says")

    def test_both_sides_negated_in_the_same_way_is_a_match_and_otherwise_a_review(self):
        self.assertEqual(status("Acme does not support SSO", "Acme does not support SSO"), "supported")
        self.assertEqual(status("Acme does not support SSO", "Acme never supports SSO"), "needs_review")
        self.assertEqual(status("Acme does not support SSO", "Acme does not support SCIM"), "needs_review")

    def test_one_exact_figure_replaced_by_another_of_the_same_kind(self):
        for claim, quote in (("Acme has 500 employees", "Acme has 200 employees"),
                             ("Acme was founded in 2015", "Acme was founded in 2019"),
                             ("Acme raised $50M in 2023", "Acme raised $60M in 2023"),
                             ("Acme grew 30% in Q3", "Acme grew 10% in Q3"),
                             ("Acme costs $20 per user per month", "Acme costs $25 per user per month")):
            self.assertEqual(status(claim, quote), "contradicted", (claim, quote))
        got = verdict("Acme has 500 employees", "Acme has 200 employees")
        self.assertEqual(got[2], "the source gives a different figure: 500 (source: 200)")

    def test_a_figure_conflict_needs_the_rest_of_the_sentence_to_match(self):
        self.assertEqual(status("Acme has 500 employees", "Acme has 200 engineers"), "needs_review")   # a word differs too
        self.assertEqual(status("In 2015", "In 2019"), "needs_review")                                # too little to compare
        self.assertEqual(status("Acme has 500 employees", "Acme has 200 employees and offices"), "needs_review")
        self.assertEqual(status("Acme grew 30% in 2023", "Acme grew 30 in 2024"), "needs_review")        # unit differs
        self.assertEqual(status("Acme raised $50M in 2023", "Acme raised A$60M in 2023"), "needs_review")

    def test_assertive_idioms_never_make_an_honest_claim_contradicted(self):
        for claim, quote in (
            ("Acme's growth has been remarkable", "Acme's growth has been nothing short of remarkable"),
            ("Acme leads the market", "There is no doubt that Acme leads the market"),
            ("Acme leads the CRM market", "No wonder Acme leads the CRM market"),
            ("Acme includes SSO for free", "Acme includes SSO for no extra charge"),
            ("Acme is popular", "Acme is not unpopular"),
            ("Acme supports SCIM", "Not only does Acme support SSO, it also supports SCIM"),
            ("Acme is more popular than ever", "Acme has never been more popular"),
            ("Acme has more than 50 customers", "Acme has no more than 50 customers"),
            ("Acme offers SCIM", "Acme offers SSO with no SCIM"),
            ("Acme reported 3 outages in 2023", "Acme reported 3 outages in 2023, while Initech reported zero outages"),
        ):
            self.assertNotIn(status(claim, quote), ("contradicted", "unsupported"), (claim, quote))

    def test_no_quantifier_or_whole_text_rule_exists(self):
        self.assertFalse(hasattr(vcs, "_quantifier_conflict"))
        # Two fabrications from the last review: they differ in more than a "not", so they go to a reader.
        self.assertEqual(status("Acme offers SCIM", "Acme offers SSO without SCIM"), "needs_review")
        self.assertEqual(status("Acme has 500 employees", "Initech has 500 employees. Acme has 200 employees."), "needs_review")


class SeveralQuotesAndNoOverlap(unittest.TestCase):
    def test_no_evidence_and_no_overlap(self):
        self.assertEqual(vcs.compute_support_score("Any claim text.", []), ("unsupported", 0.0, "no evidence linked"))
        self.assertEqual(verdict("The moon landing occurred in 1969.", "Bananas are rich in potassium")[0], "unsupported")
        got = verdict("Zebra 2020 99", "Giraffe words")
        self.assertEqual(got, ("unsupported", 0.0, "only 0% of the claim's words appear in the source"))

    def test_overlap_boundary(self):
        claim = "alpha bravo charlie delta eeee ffff gggg hhhh iiii jjjj"
        self.assertEqual(status(claim, "alpha bravo"), "unsupported")          # 20%
        self.assertEqual(status(claim, "alpha bravo charlie"), "needs_review")  # exactly 30%

    def test_one_supporting_quote_is_enough_unless_another_contradicts(self):
        self.assertEqual(status("Acme supports SSO", "Acme supports SSO", "Bananas"), "supported")
        self.assertEqual(status("Acme supports SSO", "Bananas", "Acme supports SSO"), "supported")
        got = verdict("Acme supports SSO", "Acme supports SSO", "Acme does not support SSO")
        self.assertEqual(got[0], "needs_review")
        self.assertIn("conflicting evidence", got[2])
        self.assertIn("the source negates what the claim says", got[2])

    def test_contradicting_quotes_without_a_supporting_one(self):
        got = verdict("Acme has 500 employees", "Acme has 200 employees", "Acme has 300 employees")
        self.assertEqual(got[0], "contradicted")
        self.assertIn("200", got[2])
        self.assertIn("300", got[2])

    def test_the_best_overlap_is_reported_for_a_review(self):
        got = verdict("Acme employs about 400 people", "Bananas", "Acme employs roughly 400 staff")
        self.assertEqual(got[0], "needs_review")
        self.assertEqual(got[1], 0.6)


class Words(unittest.TestCase):
    def test_stem(self):
        for a, b in (("ships", "shipped"), ("shipping", "ship"), ("companies", "company"), ("watches", "watch"),
                     ("employees", "employee"), ("licenses", "license"), ("use", "uses")):
            self.assertEqual(vcs._stem(a), vcs._stem(b), (a, b))
        self.assertNotEqual(vcs._stem("sold"), vcs._stem("sell"))
        self.assertEqual(vcs._stem("pass"), "pass")
        self.assertEqual(vcs._stem("bus"), "bus")

    def test_words_and_figures(self):
        self.assertEqual(vcs._words("Acme's CEO won't pay $1,200, A$5M, 30%, 3x or 3+ in Q3 [2]"),
                         ["acme", "ceo", "will", "not", "pay", "$1200", "a$5m", "30%", "3x", "or", "3+", "in", "q3"])
        self.assertEqual(vcs._words("It doesn't, cannot."), ["it", "does", "not", "can", "not"])

    def test_figures_are_told_from_words_and_shapes_compared(self):
        for figure in ("30%", "$5", "a$5m", "ca$5", "2023", "3.5"):
            self.assertTrue(vcs._is_figure(figure), figure)
        for word in ("q3", "ec2", "acme", "gpt4"):
            self.assertFalse(vcs._is_figure(word), word)
        self.assertEqual(vcs._shape("$50m"), vcs._shape("$20m"))
        self.assertNotEqual(vcs._shape("30%"), vcs._shape("30"))
        self.assertEqual(vcs._shape("a$5.5m"), "a$#m")

    def test_keys(self):
        self.assertEqual(vcs._keys(["the", "acme", "are", "employees", "$5"]), ["acme", "is", "employe", "$5"])

    def test_negation_helper_drops_the_auxiliary_before_it(self):
        self.assertEqual(vcs._without_negation(["acme", "does", "not", "ship"]), ["acme", "ship"])
        self.assertEqual(vcs._without_negation(["acme", "never", "ships"]), ["acme", "ships"])
        self.assertEqual(vcs._without_negation(["not", "acme"]), ["acme"])
        self.assertIsNone(vcs._without_negation(["acme", "ships"]))

    def test_normalisation(self):
        n = vcs.normalize_text
        self.assertEqual(n("40 percent"), "40%")
        self.assertEqual(n("USD 50 million"), "$50 million")
        self.assertEqual(n("five thousand customers"), "5000 customers")
        self.assertEqual(n("one hundred and twenty staff"), "120 staff")
        self.assertEqual(n("twenty-five users"), "25 users")
        self.assertEqual(n("the one who left"), "the one who left")
        self.assertEqual(n("zero downtime"), "zero downtime")
        self.assertEqual(n("Kubernetes v1.29"), "Kubernetes 1.29")
        self.assertEqual(n("doesn’t – ok"), "doesn't - ok")
        self.assertEqual(n("at no extra cost"), "for free")
        self.assertEqual(n("a hundred"), "a hundred")
        self.assertEqual(n("one million"), "1000000")
        self.assertEqual(n("two thousand five hundred"), "2500")

    def test_number_ranges(self):
        n = vcs.normalize_text
        self.assertEqual(n("between two and five days"), "between 2 and 5 days")
        self.assertEqual(n("four and five regions"), "4 and 5 regions")
        self.assertEqual(n("twenty and thirty"), "20 and 30")
        self.assertEqual(n("two hundred and fifty"), "250")
        self.assertEqual(n("one thousand and one"), "1001")
        self.assertEqual(n("between one and five days"), "between 1 and 5 days")
        self.assertEqual(n("one or two"), "1 or 2")
        self.assertEqual(n("one to three days"), "1 to 3 days")
        self.assertEqual(n("one-to-one"), "one-to-one")
        self.assertEqual(n("one to many"), "one to many")
        self.assertEqual(status("Setup takes 3 days", "Setup takes one to three days"), "needs_review")
        self.assertEqual(status("Setup takes 1 to 3 days", "Setup takes one to three days"), "supported")


if __name__ == "__main__":
    unittest.main()
