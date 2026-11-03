"""The strict near-quote rule of the claim checker (H8a, review rounds 6 and 7).

``supported`` only when the claim repeats the cited quote word for word. Only case, punctuation, the articles
a/an/the and a plural -s may differ; every other character that can change a meaning is kept and a figure is
compared exactly as written. ``contradicted`` only when the sentences differ by exactly one token: an added
or removed not/never/no, or one figure of another value written the same way.
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
                         "Acme does not offer an on-premises version", "Net margin was -12% in 2023",
                         "The fee is €1,5 million", "Müller was appointed CEO", "营收下降40%", "10⁶ requests", "Throughput is ≥ 10 Gbps"):
            self.assert_supported(sentence, sentence)

    def test_the_first_capital_punctuation_lowercase_articles_and_digit_script_may_differ(self):
        self.assert_supported("acme supports SSO!", "Acme supports SSO.")
        self.assert_supported("Acme supports SSO", "acme supports SSO")  # only the first word may change its capital
        self.assert_supported("Acme integrates with Slack, Jira and GitHub", "Acme integrates with Slack Jira and GitHub")
        self.assert_supported("Acme shipped [3] the product", "Acme shipped the product")  # a citation marker is no word
        self.assert_supported("Acme’s CEO resigned", "Acme's CEO resigned")
        self.assert_supported("Acme `ships` “two” products (new)…", "Acme ships two products new")
        self.assertNotEqual(status("**Acme** ships", "Acme ships"), "supported")  # emphasis marks are stripped by extract_claims
        self.assert_supported("The Acme CEO", "the Acme CEO")
        self.assert_supported("A shares class", "a shares class")  # a first word may change its capital
        self.assert_supported("Acme MÜLLER", "acme MÜLLER")
        self.assert_supported("Acme ｵ５０ and ٥", "Acme ｵ50 and 5")  # every decimal digit script is 0-9
        self.assert_supported("Acme café", "Acme café")  # a composed and a decomposed accent are one letter

    def test_articles_are_words_like_any_other(self):
        for claim, quote in (("Acme is a market leader", "Acme is the market leader"),
                             ("Acme has a free tier", "Acme has the free tier"),
                             ("An Acme user", "The Acme user"),
                             ("Acme is market leader", "Acme is the market leader"),
                             ("Acme is the market leader", "Acme is market leader"),
                             ("Acme has a free tier", "Acme has a a free tier")):
            self.assertEqual(status(claim, quote), "needs_review", (claim, quote))
        self.assertEqual(vcs._words("The Acme is a leader"), ["the", "Acme", "is", "a", "leader"])
        self.assertFalse(hasattr(vcs, "STOPWORDS"))

    def test_case_and_capital_articles_and_plurals_are_not_ignored(self):
        for claim, quote in (("The file is 5 Mb", "The file is 5 MB"), ("The plant makes 5 mW", "The plant makes 5 MW"),
                             ("The link is 5 GBps", "The link is 5 Gbps"), ("The dose is 500 Mg", "The dose is 500 mg"),
                             ("Acme has 5K users", "Acme has 5k users"), ("Sales to us firms rose", "Sales to US firms rose"),
                             ("Hepatitis cases rose", "Hepatitis A cases rose"),
                             ("Vitamin A deficiency", "Vitamin deficiency"), ("Class shares rose", "Class A shares rose"),
                             ("The new release", "The news release"), ("Acme sells glass", "Acme sells glasses"),
                             ("Acme sells security", "Acme sells securities"), ("Acme makes good", "Acme makes goods"),
                             ("The drug work", "The drug works"), ("Acme doe sell X", "Acme does sell X"),
                             ("The can not index rose", "The CANT index rose")):
            self.assertNotEqual(status(claim, quote), "supported", (claim, quote))
            self.assertNotEqual(status(quote, claim), "supported", (claim, quote))

    def test_a_question_a_footnote_and_a_citation_in_a_number_change_the_claim(self):
        for claim, quote in (("The vaccine is safe", "The vaccine is safe?"), ("Is the vaccine safe", "Is the vaccine safe?"),
                             ("The plan is free", "The plan is free*"), ("Acme has 3 employees", "Acme has 3[00] employees"),
                             ("Revenue was $5", "Revenue was $5[000]"), ("Revenue grew 5% in 2023", "Revenue grew 5[0]% in 2023")):
            self.assertEqual(status(claim, quote), "needs_review", (claim, quote))
            self.assertEqual(status(quote, claim), "needs_review", (claim, quote))
        self.assert_supported("The drug is approved [3]", "The drug is approved")  # a marker after a space is no word
        self.assert_supported("The drug is approved for adults [1, 2].", "The drug is approved for adults")
        self.assertEqual(vcs._words("Acme has 3[00] employees [4]"), ["acme", "has", "3", "00", "employees"])

    def test_no_is_a_negator_only_as_a_plain_word(self):
        self.assertEqual(vcs._words("No, the tool is not free. Acme ranks No. 1"),
                         ["No,", "the", "tool", "is", "not", "free", "Acme", "ranks", "No.", "1"])
        self.assertEqual(status("The tool is not free", "No, the tool is not free"), "needs_review")
        self.assertEqual(status("Acme ranks 1 in Europe", "Acme ranks No. 1 in Europe"), "needs_review")
        self.assertEqual(status("The study found effect", "The study found no effect"), "contradicted")

    def test_contractions_are_opened_up(self):
        self.assert_supported("Acme doesn't support SSO", "Acme does not support SSO")
        self.assert_supported("The tool isn't free", "The tool is not free")
        self.assert_supported("Acme can't export data", "Acme cannot export data")
        self.assert_supported("Acme won't ship it", "Acme will not ship it")

    def test_figures_attach_their_symbol_even_across_a_space(self):
        self.assert_supported("Unemployment fell to 40 % in March", "Unemployment fell to 40% in March")
        self.assert_supported("The fee is 50 € per seat", "The fee is 50€ per seat")
        self.assert_supported("The fee is € 50", "The fee is €50")
        self.assertEqual(vcs._words("40 % of 50 $ and $5 6"), ["40%", "of", "50$", "and", "$5", "6"])

    def test_every_other_difference_goes_to_a_reader(self):
        for claim, quote in (
            ("Acme is acquired by Initech", "Initech acquires Acme"),
            ("Initech acquired Acme", "Acme acquired Initech"),
            ("Acme was acquired by Initech in 2022", "In 2022 Acme was acquired by Initech"),
            ("Acme lacks SCIM provisioning", "Acme does not support SCIM provisioning"),
            ("Acme employs about 400 people", "Acme employs roughly 400 people"),
            ("Acme sells licenses", "Acme sold licences"),
            ("Acme's revenue grew 40%", "Acme's revenue rose 40%"),
            ("Acme supports SSO", "Acme will support SSO"),
            ("Acme supports SSO", "Acme supports SSO only on paper"),
            ("Acme is SOC 2 certified", "Acme is SOC 2 certified. Not true."),
            ("Acme supports SSO", "Myth: Acme supports SSO."),
            ("Acme has 500 employees", "Initech has 500 employees and Acme has 200"),
            ("Acme costs $20 per month", "Acme costs $20 per year"),
            ("Acme revenue grew 30% in Q3", "Acme revenue grew 30% in Q2 and 10% in Q3"),
            ("Acme raised $50M in 2023", "Acme raised A$50M in 2023"),
            ("Acme has 3 offices", "Acme has 3+ offices"),
            ("Acme grew 3%", "Acme grew 3"),
        ):
            self.assertEqual(status(claim, quote), "needs_review", (claim, quote))

    def test_words_that_carry_meaning_are_not_filler(self):
        for claim, quote in (("Revenue doubled that year", "Revenue doubled this year"),
                             ("Their revenue tripled", "Its revenue tripled"),
                             ("The feature is available", "The feature is available only if you pay"),
                             ("The feature is available if you pay", "The feature is available only if you pay"),
                             ("Only admins can export data", "All admins can export data"),
                             ("The store is open in May", "The store is opening in May"),
                             ("Staff numbers grew 10%", "Employee numbers grew 10%"),
                             ("The client is Acme", "The customer is Acme"),
                             ("Acme are the largest vendor", "Acme is the largest vendor"),
                             ("Acme servers are in the EU", "Acme's servers are in the EU"),
                             ("It free for students", "It's free for students"),
                             ("The vendor is profitable", "The vendor is hardly profitable")):
            self.assertNotEqual(status(claim, quote), "supported", (claim, quote))
            self.assertNotEqual(status(quote, claim), "supported", (claim, quote))

    def test_notes_say_why(self):
        self.assertEqual(verdict("Acme offers SSO", "Acme offers SSO on all plans")[2],
                         "the claim repeats only part of the source text: quote just the span that supports it, "
                         "or make the claim say all of it")
        self.assertEqual(verdict("Acme offers SSO on all plans", "Acme offers SSO")[2],
                         "the claim says more than the source text: the extra words are not in the quote")
        self.assertEqual(verdict("We bought Acme and Initech", "We bought Initech and Acme")[2],
                         "the source has the same words in a different order (reordered or changed voice)")
        self.assertEqual(verdict("Acme employs about 400 people", "Acme employs roughly 400 staff")[2],
                         "reworded, not a near-quote: 60% of the claim's words are in the source")

    def test_a_claim_without_words_is_never_supported(self):
        self.assertEqual(verdict("[1] [2, 3]", "The a"), ("needs_review", 0.0, "the claim has no words to check"))


class FiguresCompareExactlyAsWritten(unittest.TestCase):
    """A figure written another way is a different token: needs_review, never supported, never contradicted."""

    def test_signs_comparators_and_marks_are_kept(self):
        for claim, quote in (("Net margin was 12% in 2023", "Net margin was -12% in 2023"),
                             ("Q3 revenue was -5%", "Q3 revenue was +5%"),
                             ("Temperature can reach 40°C", "Temperature can reach −40°C"),
                             ("Latency is > 5 ms", "Latency is < 5 ms"),
                             ("Throughput is ≤ 10 Gbps", "Throughput is ≥ 10 Gbps"),
                             ("Revenue was $5m", "Revenue was ~$5m"),
                             ("Throughput is 10 Gbps", "Throughput is ≈ 10 Gbps"),
                             ("Sales rose 5", "Sales rose 5x"),
                             ("Ships in 12 weeks", "Ships in 1–2 weeks"),
                             ("The price is $5 user month", "The price is $5/user/month"),
                             ("A 10 fold increase", "A 10-fold increase")):
            self.assertNotEqual(status(claim, quote), "supported", (claim, quote))
            self.assertNotEqual(status(quote, claim), "supported", (claim, quote))

    def test_letters_of_every_script_are_kept(self):
        for claim, quote in (("Müller was appointed CEO", "Möller was appointed CEO"),
                             ("José Péraz leads", "José Pérez leads"),
                             ("Выручка выросла на 40%", "Выручка упала на 40%"),
                             ("营收增长40%", "营收下降40%")):
            self.assertNotEqual(status(claim, quote), "supported", (claim, quote))

    def test_separators_are_never_reinterpreted(self):
        for claim, quote in (("The fee is €15 million", "The fee is €1,5 million"),
                             ("The plan costs €350", "The plan costs €3,50"),
                             ("The limit is 1000 calls", "The limit is 1,000 calls"),
                             ("Version 123 fixed it", "Version 1.2.3 fixed it"),
                             ("The SDK supports Python 312", "The SDK supports Python 3.12"),
                             ("Accuracy is 95", "Accuracy is 0.95"),
                             ("Accuracy is 95", "Accuracy is .95"),
                             ("Requests: 106", "Requests: 10⁶"),
                             ("Uptime was 999%", "Uptime was 99.9%")):
            self.assertNotEqual(status(claim, quote), "supported", (claim, quote))
            self.assertNotEqual(status(quote, claim), "supported", (claim, quote))

    def test_symbols_after_a_space_belong_to_the_figure(self):
        self.assertNotEqual(status("Unemployment fell to 40", "Unemployment fell to 40 %"), "supported")
        self.assertNotEqual(status("The fee is 50 $ per seat", "The fee is 50 € per seat"), "supported")

    def test_numbers_in_words_and_years_are_not_interpreted(self):
        for claim, quote in (("The free tier allows 5 users", "The free tier allows five users"),
                             ("The device ships in 45", "The device ships in twenty twenty-five"),
                             ("The model ships in 2024", "The model ships in '24"),
                             ("The format dates from the 1990s", "The format dates from the 90s"),
                             ("Prices rose 5 percent", "Prices rose 5 percentage points"),
                             ("Acme grew 40 percent", "Acme grew 40%")):
            self.assertEqual(status(claim, quote), "needs_review", (claim, quote))
            self.assertEqual(status(quote, claim), "needs_review", (claim, quote))

    def test_the_same_value_written_another_way_is_a_review_not_a_contradiction(self):
        for claim, quote in (("Version 3 shipped in May", "Version 3.0 shipped in May"),
                             ("The plan costs $5 per month", "The plan costs $5.00 per month"),
                             ("Accuracy is .95", "Accuracy is 0.95"),
                             ("Uptime was 40% higher", "Uptime was 40.0% higher"),
                             ("The format dates from the 90s", "The format dates from the 1990s"),
                             ("The model ships in '24", "The model ships in 2024")):
            self.assertEqual(status(claim, quote), "needs_review", (claim, quote))
            self.assertEqual(status(quote, claim), "needs_review", (claim, quote))

    def test_figure_tokens(self):
        self.assertEqual(vcs._words("Net -12%, +5, −40°C, €1,5, 3,50, 10⁶, .95, '24, $5.00, 99.9%, A$5m, 1,000."),
                         ["net", "-12%", "+5", "−40", "°", "C", "€1,5", "3,50", "10⁶", ".95", "'24", "$5.00", "99.9%",
                          "A$5m", "1,000"])
        self.assertEqual(vcs._words("The price is $5/user/month, 3-5 days, x > 5 ~ y"),
                         ["the", "price", "is", "$5", "/", "user", "/", "month", "3", "-", "5", "days", "x", ">", "5", "~", "y"])
        for figure in ("30%", "$5", "a$5m", "ca$5", "2023", "3.5", "-12", "'24", ".95"):
            self.assertTrue(vcs._is_figure(figure), figure)
        for word in ("q3", "ec2", "acme", "gpt4", "-", "$"):
            self.assertFalse(vcs._is_figure(word), word)

    def test_no_stemming(self):
        self.assertFalse(hasattr(vcs, "_stem"))
        self.assertFalse(hasattr(vcs, "_keys"))


class ContradictedOnlyWhenClear(unittest.TestCase):
    def test_one_added_or_removed_negator(self):
        for claim, quote in (("Acme supports SSO", "Acme not supports SSO"),
                             ("Acme encrypts backups", "Acme never encrypts backups"),
                             ("Acme can export data", "Acme cannot export data"),
                             ("Acme is cheaper than Initech", "Acme isn't cheaper than Initech"),
                             ("The feature is available", "The feature is not available"),
                             ("The study found effect", "The study found no effect"),
                             ("Acme has free tier", "Acme has no free tier"),
                             ("Don't use the v1 API", "Do use the v1 API"),
                             ("Acme acquired Initech", "Acme not acquired Initech"),
                             ("Acme supports SSO", "Acme supports SSO: No")):
            self.assertEqual(status(claim, quote), "contradicted", (claim, quote))
            self.assertEqual(status(quote, claim), "contradicted", (claim, quote))
        self.assertEqual(verdict("Acme supports SSO", "Acme not supports SSO")[2], "the source negates what the claim says")
        self.assertEqual(verdict("Acme not supports SSO", "Acme supports SSO")[2], "the claim negates what the source says")

    def test_a_negation_with_anything_else_changed_is_a_review(self):
        for claim, quote in (("Acme supports SSO", "Acme does not support SSO"),  # does + not: two tokens
                             ("Acme acquired Initech", "Acme did not acquire Initech"),
                             ("Acme does not support SSO", "Acme never supports SSO"),
                             ("Acme does not support SSO", "Acme does not support SCIM"),
                             ("Acme is popular", "Acme is not unpopular"),
                             ("Acme leads the market", "There is no doubt that Acme leads the market"),
                             ("Acme includes SSO for free", "Acme includes SSO for no extra charge"),
                             ("Acme's growth has been remarkable", "Acme's growth has been nothing short of remarkable"),
                             ("All users can export data", "No users can export data"),
                             ("Acme offers SCIM", "Acme offers SSO without SCIM"),
                             ("The vendor is profitable", "The vendor is hardly profitable")):
            self.assertEqual(status(claim, quote), "needs_review", (claim, quote))

    def test_exactly_one_figure_of_another_value_written_the_same_way(self):
        for claim, quote in (("Acme has 500 employees", "Acme has 200 employees"),
                             ("Acme was founded in 2015", "Acme was founded in 2019"),
                             ("Acme raised $50M in 2023", "Acme raised $60M in 2023"),
                             ("Acme grew 30% in Q3", "Acme grew 10% in Q3"),
                             ("Uptime was 99.9%", "Uptime was 99.8%"),
                             ("Net margin was -12%", "Net margin was -13%")):
            self.assertEqual(status(claim, quote), "contradicted", (claim, quote))
        self.assertEqual(verdict("Acme has 500 employees", "Acme has 200 employees")[2],
                         "the source gives a different figure: 500 (source: 200)")

    def test_two_differing_tokens_are_a_review(self):
        for claim, quote in (("Acme has 500 employees", "Acme has 200 engineers"),
                             ("Revenue was $7m in 2024", "Revenue was $5m in 2023"),
                             ("Acme had 150 staff in 2023", "Acme had 100 staff in 2022"),
                             ("Acme has 500 employees", "Acme has 200 employees and offices"),
                             ("Acme grew 30% in 2023", "Acme grew 30 in 2024"),
                             ("Acme raised $50M in 2023", "Acme raised A$60M in 2023"),
                             ("Acme grew 30% in Q3", "Acme grew 10% in Q2")):
            self.assertEqual(status(claim, quote), "needs_review", (claim, quote))
        self.assertEqual(status("In 2015", "In 2019"), "contradicted")  # a single figure differs, nothing else
        self.assertEqual(status("Acme has 5 offices", "Acme has 50 offices"), "needs_review")  # not the same form

    def test_no_whole_text_rule_exists(self):
        self.assertFalse(hasattr(vcs, "_quantifier_conflict"))
        self.assertEqual(status("Acme has 500 employees", "Initech has 500 employees. Acme has 200 employees."), "needs_review")


class SeveralQuotesAndNoOverlap(unittest.TestCase):
    def test_no_evidence_and_no_overlap(self):
        self.assertEqual(vcs.compute_support_score("Any claim text.", []), ("unsupported", 0.0, "no evidence linked"))
        self.assertEqual(verdict("The moon landing occurred in 1969.", "Bananas are rich in potassium")[0], "unsupported")
        self.assertEqual(verdict("Zebra 2020 99", "Giraffe words"),
                         ("unsupported", 0.0, "only 0% of the claim's words appear in the source"))

    def test_overlap_boundary(self):
        claim = "alpha bravo charlie delta eeee ffff gggg hhhh iiii jjjj"
        self.assertEqual(status(claim, "alpha bravo"), "unsupported")          # 20%
        self.assertEqual(status(claim, "alpha bravo charlie"), "needs_review")  # exactly 30%

    def test_any_supporting_quote_is_enough_and_every_quote_must_contradict(self):
        self.assertEqual(status("Acme supports SSO", "Acme supports SSO", "Bananas"), "supported")
        self.assertEqual(status("Acme supports SSO", "Bananas", "Acme supports SSO"), "supported")
        self.assertEqual(status("Acme supports SSO", "Acme supports SSO", "Acme not supports SSO"), "supported")
        self.assertEqual(status("Acme supports SSO", "Acme not supports SSO", "Acme not supports SSO"), "contradicted")
        self.assertEqual(status("Acme supports SSO", "Acme not supports SSO", "Bananas"), "unsupported" if False else "needs_review")
        self.assertEqual(status("Acme has 500 employees", "Acme has 200 employees", "Acme has 500 staff"), "needs_review")

    def test_a_sibling_quote_about_another_year_never_contradicts(self):
        # The quote of 2023 differs from the claim in one figure, and the real source is worded differently.
        self.assertEqual(status("Revenue rose 5% in 2024.", "Revenue rose 5% in 2023.", "In 2024, revenue again rose 5%."),
                         "needs_review")
        self.assertEqual(status("The pro plan costs $9 per month.", "The basic plan costs $5 per month.",
                                "The pro plan, at $9 per month, adds SSO."), "needs_review")
        self.assertEqual(status("Revenue was $7m in 2024.", "Revenue was $5m in 2023.", "Revenue rose to $7m in 2024."),
                         "needs_review")
        self.assertEqual(status("Acme had 150 staff in 2023.", "Acme had 100 staff in 2022.",
                                "Acme has grown to 150 staff in 2023."), "needs_review")
        self.assertEqual(status("The pro tier allows fifty users.", "The free tier allows 5 users.",
                                "The pro tier allows 50 users."), "needs_review")

    def test_contradicting_quotes_without_a_supporting_one(self):
        got = verdict("Acme has 500 employees", "Acme has 200 employees", "Acme has 300 employees")
        self.assertEqual(got[0], "contradicted")
        self.assertIn("200", got[2])
        self.assertIn("300", got[2])

    def test_the_best_overlap_is_reported_for_a_review(self):
        got = verdict("Acme employs about 400 people", "Bananas", "Acme employs roughly 400 staff")
        self.assertEqual((got[0], got[1]), ("needs_review", 0.6))


if __name__ == "__main__":
    unittest.main()
