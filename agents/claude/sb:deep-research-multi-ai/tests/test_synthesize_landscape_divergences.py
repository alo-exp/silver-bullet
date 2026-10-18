"""Unit tests for the notable-divergence selection helpers of synthesize_landscape."""

from __future__ import annotations

import unittest
from unittest import mock

from synth_helpers import TmpCase, sl


def side(text, agents=(), families=(), wave="DR-TRIANGULATE", **extra):
    out = {"text": text, "supporting_agents": list(agents), "model_families": list(families),
           "wave": wave, "support_count": 1}
    out.update(extra)
    return out


class TextHelperTests(unittest.TestCase):
    def test_apply_preserving(self):
        up = str.upper
        self.assertEqual(sl.apply_preserving_notable_divergences(None, up), "")
        self.assertEqual(sl.apply_preserving_notable_divergences("abc", up), "ABC")
        md = "intro\n### Consensus Resolution Table\nkeep me\n## Next\ntail"
        self.assertEqual(sl.apply_preserving_notable_divergences(md, up),
                         "INTRO\n### Consensus Resolution Table\nkeep me\n## NEXT\nTAIL")
        md = "intro\n**Notable divergences**\nkeep\nto the end"
        self.assertEqual(sl.apply_preserving_notable_divergences(md, up),
                         "INTRO\n**Notable divergences**\nkeep\nto the end")

    def test_clean_and_normalize(self):
        self.assertEqual(sl._clean_text(None), "")
        self.assertEqual(sl._clean_text("a [lean-ctx: x] b"), "a  b")
        self.assertEqual(sl._normalize_divergence_text("[Link Text](http://x.y) -- Foo!"), "link text foo")
        self.assertEqual(sl._normalize_divergence_text(None), "")

    def test_jaccard(self):
        j = sl._divergence_token_jaccard
        self.assertEqual(j("", "a"), 0.0)
        self.assertEqual(j("a", ""), 0.0)
        self.assertAlmostEqual(j("a b c", "b c d"), 0.5)

    def test_stances(self):
        self.assertEqual(sl._divergence_stance("it is the weakest option"), "neg")
        self.assertEqual(sl._divergence_stance("the most complete one"), "pos")
        self.assertEqual(sl._divergence_stance("weakest yet most complete"), "mix")
        self.assertEqual(sl._divergence_stance("neutral"), "mix")
        self.assertEqual(sl._divergence_stance(None), "mix")
        self.assertEqual(sl._item_stance({"stance_text": "Hard-Excluded!", "text": "enterprise-grade"}), "neg")
        self.assertEqual(sl._item_stance({"text": "enterprise-grade"}), "pos")
        self.assertEqual(sl._item_stance({}), "mix")

    def test_subject_key(self):
        k = sl._divergence_subject_key
        # magic.dev outranks everything that appears in the same blob
        self.assertEqual(k("silver bullet and magic dev"), "magic-dev")
        self.assertEqual(k("cognition scout then magic dev"), "cognition-scout")
        self.assertEqual(k("zuvo is good"), "zuvo")
        # earliest position wins; longer needle wins a tie at the same position
        self.assertEqual(k("factory ai role"), "factory-ai")
        self.assertEqual(k("bmad method guide"), "bmad")
        self.assertEqual(k("devin then zuvo"), "devin")
        # claim_key participates in the blob
        self.assertEqual(k("generic words here", "conductor"), "conductor")
        # needles far from the start and outside the first 16 tokens are ignored
        far = " ".join(["filler"] * 20) + " zuvo"
        self.assertEqual(k(far), "filler filler filler filler")
        # beyond 48 chars but still within the first 16 tokens counts
        near = " ".join(["abcdefgh"] * 7) + " zuvo"
        self.assertEqual(k(near), "zuvo")
        self.assertEqual(k(""), "")

    def test_clip(self):
        c = sl._clip_divergence_claim
        self.assertEqual(c("Short claim."), "Short claim")
        self.assertEqual(c(None), "")
        long = "word " * 100
        got = c(long, 20)
        self.assertTrue(got.endswith("…"))
        self.assertLessEqual(len(got), 20)
        self.assertEqual(c("x" * 50, 10), "x" * 9 + "…")

    def test_lists(self):
        self.assertEqual(sl._agent_list({"supporting_agents": "solo"}), ["solo"])
        self.assertEqual(sl._agent_list({"agents": [" a ", "", None]}), ["a", "None"])
        self.assertEqual(sl._agent_list({}), [])
        self.assertEqual(sl._family_list({"model_families": "fam"}), ["fam"])
        self.assertEqual(sl._family_list({"families": [" f ", ""]}), ["f"])


class NormalizeItemTests(unittest.TestCase):
    def test_non_dict(self):
        self.assertIsNone(sl._normalize_divergence_item(None))
        self.assertIsNone(sl._normalize_divergence_item("   "))
        item = sl._normalize_divergence_item("  plain claim ")
        self.assertEqual(item["text"], "plain claim")
        self.assertEqual(item["wave"], "DR-TRIANGULATE")
        self.assertEqual(item["support_count"], 1)

    def test_dict(self):
        self.assertIsNone(sl._normalize_divergence_item({"text": "  "}))
        item = sl._normalize_divergence_item({"text": "t", "agents": ["a", "b"], "families": "f",
                                              "claim_key": None, "wave": None})
        self.assertEqual((item["supporting_agents"], item["model_families"], item["claim_key"]),
                         (["a", "b"], ["f"], ""))
        self.assertEqual(item["support_count"], 2)
        self.assertEqual(item["wave"], "DR-TRIANGULATE")
        item = sl._normalize_divergence_item({"text": "t", "support_count": 5, "wave": "W"})
        self.assertEqual((item["support_count"], item["wave"]), (5, "W"))


class CritiqueItemsTests(unittest.TestCase):
    def test_critique_items(self):
        self.assertEqual(sl._critique_divergence_items(None), [])
        envs = [
            "junk",
            {"phase_id": "DR-RETRIEVE", "payload": {"critiques": [{"severity": "high"}]}},
            {"phase_id": "DR-CRITIQUE", "payload": "not-a-dict"},
            {"phase_id": "DR-CRITIQUE", "logical_model_id": "m1", "model_family_id": "f1", "payload": {"critiques": [
                "junk",
                {"severity": "low", "target": "t", "finding": "f"},
                {"severity": "HIGH", "target": "AI-DLC", "finding": "is the weakest"},
                {"severity": "critical", "target": "", "finding": "only finding"},
                {"severity": "critical", "target": "only target", "finding": ""},
                {"severity": "high", "target": "", "finding": ""},
            ]}},
            {"phase_id": "DR-CRITIQUE", "payload": {"critiques": [
                {"severity": "high", "target": "X", "finding": "y"}]}},
        ]
        got = sl._critique_divergence_items(envs)
        self.assertEqual([g["text"] for g in got],
                         ["AI-DLC: is the weakest", "only finding", "only target", "X: y"])
        self.assertEqual(got[0]["supporting_agents"], ["m1"])
        self.assertEqual(got[0]["model_families"], ["f1"])
        self.assertEqual(got[0]["stance_text"], "is the weakest")
        self.assertEqual((got[0]["wave"], got[0]["label"], got[0]["claim_key"]),
                         ("DR-CRITIQUE", "divergent", "AI-DLC"))
        self.assertEqual((got[3]["supporting_agents"], got[3]["model_families"]), ([], []))


class MergeTests(unittest.TestCase):
    def test_restatement_predicate(self):
        r = sl._is_divergence_restatement
        self.assertTrue(r("a b c d", "a b c d", 0.5))
        prefix = "x" * 60
        self.assertTrue(r(prefix + " one two three", prefix + " four five six", 0.9))
        self.assertFalse(r("alpha beta", "gamma delta", 0.5))
        self.assertFalse(r("", "", 0.5))

    def test_merge_new_and_longer_text(self):
        a = side("claim alpha beta gamma delta", ["a1"], ["f1"])
        b = side("claim alpha beta gamma delta epsilon zeta eta theta iota", ["a2"], ["f2"])
        c = side("totally other words entirely", ["a3"])
        out = sl._merge_restatement_sides([a, b, c], similarity=0.4)
        self.assertEqual(len(out), 2)
        self.assertEqual(out[0]["text"], b["text"])
        self.assertEqual(out[0]["supporting_agents"], ["a1", "a2"])
        self.assertEqual(out[0]["model_families"], ["f1", "f2"])
        self.assertEqual(out[0]["support_count"], 2)
        self.assertEqual(a["supporting_agents"], ["a1"])  # inputs untouched

    def test_merge_keeps_text_when_not_longer(self):
        a = side("claim alpha beta gamma delta epsilon")
        b = side("claim alpha beta gamma delta")
        out = sl._merge_restatement_sides([a, b], similarity=0.4)
        self.assertEqual(out[0]["text"], a["text"])

    def test_merge_wave_rules(self):
        base = "claim alpha beta gamma delta"
        crit = side(base, wave="DR-CRITIQUE", stance_text="finding text")
        crit_nostance = side(base, wave="DR-CRITIQUE")
        tri = side(base)
        no_wave = side(base)
        no_wave["wave"] = ""
        # critique merged into a triangulation side promotes it and carries the stance
        out = sl._merge_restatement_sides([tri, crit], similarity=0.4)
        self.assertEqual((out[0]["wave"], out[0]["stance_text"]), ("DR-CRITIQUE", "finding text"))
        out = sl._merge_restatement_sides([side(base), crit_nostance], similarity=0.4)
        self.assertEqual(out[0]["wave"], "DR-CRITIQUE")
        self.assertNotIn("stance_text", out[0])
        # triangulation merged into a different non-critique wave takes the later wave
        out = sl._merge_restatement_sides([side(base, wave="W1"), side(base, wave="W2")], similarity=0.4)
        self.assertEqual(out[0]["wave"], "W2")
        # a critique side is never downgraded; an empty wave changes nothing
        out = sl._merge_restatement_sides([side(base, wave="DR-CRITIQUE"), tri], similarity=0.4)
        self.assertEqual(out[0]["wave"], "DR-CRITIQUE")
        out = sl._merge_restatement_sides([side(base, wave="W1"), no_wave], similarity=0.4)
        self.assertEqual(out[0]["wave"], "W1")

    def test_union_and_collapse(self):
        u = sl._union_divergence_sides
        g = [side("short", ["a"], ["f1"]), side("a much longer claim text", ["b"], ["f2"], support_count=3)]
        out = u(g)
        self.assertEqual(out["text"], "a much longer claim text")
        self.assertEqual((out["supporting_agents"], out["model_families"], out["support_count"]),
                         (["a", "b"], ["f1", "f2"], 4))
        self.assertEqual(g[0]["text"], "short")
        out = u([side("long enough text", ["a"]), side("tiny", ["b"])])
        self.assertEqual(out["text"], "long enough text")
        crit = u([side("x", wave="DR-CRITIQUE", stance_text="s1"),
                  side("y", wave="DR-CRITIQUE", stance_text="longer stance")])
        self.assertEqual((crit["wave"], crit["stance_text"]), ("DR-CRITIQUE", "longer stance"))
        crit = u([side("x", wave="DR-CRITIQUE"), side("y")])
        self.assertEqual(crit["wave"], "DR-CRITIQUE")
        self.assertNotIn("stance_text", crit)

    def test_collapse_same_stance(self):
        pos1 = side("the most complete process layer", ["a"], ["f1"])
        pos2 = side("enterprise-grade and in-scope", ["b"], ["f2"])
        neg1 = side("weakest excluded option here today", ["c"])
        neg2 = side("weakest excluded option here today again", ["d"])
        mix = side("plain neutral note", ["e"])
        out = sl._collapse_same_stance_sides([pos1, pos2, neg1, neg2, mix], similarity=0.55)
        self.assertEqual(len(out), 3)  # one pos union, one merged neg pair, one mix
        self.assertEqual(out[0]["supporting_agents"], ["a", "b"])
        self.assertEqual(sl._collapse_same_stance_sides([], similarity=0.5), [])
        with mock.patch.object(sl, "_item_stance", return_value="odd"):
            self.assertEqual(sl._collapse_same_stance_sides([pos1], similarity=0.5), [])


class DisagreementTests(unittest.TestCase):
    def test_sides_disagree(self):
        d = lambda sides: sl._sides_disagree(sides, similarity=0.5)  # noqa: E731
        pos = lambda **k: side("the most complete one", **k)  # noqa: E731
        neg = lambda **k: side("it is the weakest", **k)  # noqa: E731
        mix = lambda **k: side("plain note", **k)  # noqa: E731
        self.assertFalse(d([pos(agents=["a"])]))
        self.assertFalse(d([pos(), neg()]))  # nothing distinguishes the sources
        self.assertTrue(d([pos(agents=["a"]), neg(agents=["b"])]))
        self.assertTrue(d([pos(families=["f1"]), neg(families=["f2"])]))
        # critique negative vs triangulation positive / mixed
        self.assertTrue(d([neg(wave="DR-CRITIQUE"), pos()]))
        self.assertTrue(d([neg(wave="DR-CRITIQUE"), mix()]))
        # critique non-negative vs triangulation: no disagreement
        self.assertFalse(d([pos(wave="DR-CRITIQUE"), mix()]))
        self.assertFalse(d([mix(agents=["a"]), mix(agents=["b"])]))
        self.assertFalse(d([neg(wave="DR-CRITIQUE"), neg(agents=["b"])]))


class FormatTests(unittest.TestCase):
    def test_format(self):
        sides = [
            side("claim one.", ["a", "b", "c", "d"], ["f1", "f2", "f3", "f4"], wave="DR-CRITIQUE"),
            side("claim two"),
            side("x " * 200, ["z"]),
            side("three"), side("four"), side("five"),
        ]
        out = sl._format_inter_model_divergence("ai-dlc", sides)
        self.assertTrue(out.startswith("**AI-DLC:** `a`, `b`, `c` (f1/f2/f3, DR-CRITIQUE) — claim one; "))
        self.assertIn("unattributed claim — claim two", out)
        self.assertIn("`z` — ", out)
        self.assertEqual(out.count(" — "), 4)  # at most four sides
        self.assertTrue(out.startswith("**AI-DLC:**"))
        self.assertTrue(sl._format_inter_model_divergence("some-new-topic", [side("t", ["a"])])
                        .startswith("**Some New Topic:** `a` — t"))
        self.assertEqual(sl._format_inter_model_divergence("zuvo", [side("t", ["a"], ["f"])]),
                         "**Zuvo classification:** `a` (f) — t")


class SelectTests(unittest.TestCase):
    def items(self):
        return [
            {"text": "AI-DLC is the most complete process layer", "supporting_agents": ["a1"],
             "model_families": ["f1"]},
            {"text": "AI-DLC is the weakest option and hard excluded", "supporting_agents": ["a2"],
             "model_families": ["f2"]},
            "",
            None,
            {"text": "Zuvo is a plain neutral note", "supporting_agents": ["a1"]},
            {"text": "Zuvo is another unrelated remark", "supporting_agents": ["a1"]},
        ]

    def test_select_disagreements(self):
        got = sl.select_notable_divergences(self.items())
        self.assertEqual(len(got), 1)
        d = got[0]
        self.assertEqual((d["subject"], d["claim_key"], d["label"]), ("ai-dlc", "ai-dlc", "divergent"))
        self.assertTrue(d["text"].startswith("**AI-DLC:** "))
        self.assertEqual(d["model_families"], ["f1", "f2"])
        self.assertEqual(d["support_count"], 2)
        self.assertEqual(len(d["sides"]), 2)

    def test_limit_ranking_and_envelopes(self):
        envs = [{"phase_id": "DR-CRITIQUE", "logical_model_id": "m9", "model_family_id": "f9", "payload": {
            "critiques": [{"severity": "high", "target": "Conductor", "finding": "is the weakest option"}]}}]
        items = self.items() + [
            {"text": "Conductor is the most complete process layer", "supporting_agents": ["a5"]}]
        got = sl.select_notable_divergences(items, envelopes=envs)
        # the critique-backed subject outranks the plain one
        self.assertEqual([g["subject"] for g in got], ["conductor", "ai-dlc"])
        self.assertEqual([g["subject"] for g in sl.select_notable_divergences(items, envelopes=envs, limit=1)],
                         ["conductor"])
        self.assertEqual(sl.select_notable_divergences(None), [])
        self.assertEqual(sl.select_notable_divergences([]), [])


if __name__ == "__main__":
    unittest.main()
