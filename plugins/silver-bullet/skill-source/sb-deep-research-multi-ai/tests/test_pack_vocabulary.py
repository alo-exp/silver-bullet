"""pack_vocabulary: category data from the pack overlay, applied only while a pack is selected."""

from __future__ import annotations

import json
import re
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

import materialize_solution_artifacts as mat  # noqa: E402
import pack_vocabulary as pv  # noqa: E402
import synthesize_landscape as sl  # noqa: E402
from category_pack import load_pack_overlay, resolve_pack_from_need  # noqa: E402

PACK_ID = "agentic-sdlc-process-orchestrator"


class ConverterTests(unittest.TestCase):
    def test_regex_and_collection_converters(self) -> None:
        self.assertIs(pv._regex(None), pv.NEVER)
        self.assertIsNone(pv.NEVER.search("anything"))
        self.assertTrue(pv._regex("abc").search("xabc"))
        self.assertTrue(pv._regex({"pattern": "abc", "flags": int(re.I)}).search("ABC"))
        self.assertEqual(pv._prose_signals([["a+", ["F"]]])[0][1], ["F"])
        self.assertEqual(pv._prose_signals(None), [])
        self.assertEqual(pv._weights([["F", 1]]), (("F", 1.0),))
        self.assertEqual(pv._pairs([["a", "b"]]), (("a", "b"),))
        self.assertEqual(pv._tuple(["a"]), ("a",))
        self.assertEqual(pv._frozen(["a", "a"]), frozenset({"a"}))

    def test_every_overlay_vocabulary_key_is_known_and_converts(self) -> None:
        vocabulary = load_pack_overlay(PACK_ID)["vocabulary"]
        self.assertEqual(set(vocabulary) - set(pv.CONVERTERS), set())
        converted = pv.converted(vocabulary)
        self.assertEqual(set(converted), set(vocabulary))
        for key in converted:
            module, attr = key.rsplit(".", 1)
            self.assertTrue(hasattr(__import__(module), attr), key)


class ActivationTests(unittest.TestCase):
    def test_defaults_are_neutral_and_the_pack_applies_only_inside_the_block(self) -> None:
        self.assertEqual((mat.FEATURE_TEMPLATE, sl.KCF_NAMES, sl.LEADER_RULES), ([], [], {}))
        pack = resolve_pack_from_need({"category_pack_id": PACK_ID})
        with pv.activated(pack):
            self.assertTrue(mat.FEATURE_TEMPLATE)
            self.assertIn("Hook-enforced gates", sl.KCF_NAMES)
            self.assertTrue(sl.LEADER_RULES["markets"])
        self.assertEqual((mat.FEATURE_TEMPLATE, sl.KCF_NAMES, sl.LEADER_RULES), ([], [], {}))
        with pv.activated(None):
            self.assertEqual(mat.FEATURE_TEMPLATE, [])
        with self.assertRaises(RuntimeError):
            with pv.apply_values({"synthesize_landscape.KCF_NAMES": ["x"]}):
                self.assertEqual(sl.KCF_NAMES, ["x"])
                raise RuntimeError("restored even on failure")
        self.assertEqual(sl.KCF_NAMES, [])

    def test_research_dir_decorator_reads_the_need_profile(self) -> None:
        seen = []

        @pv.for_research_dir
        def probe(research_dir):
            seen.append(bool(mat.FEATURE_TEMPLATE))

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            probe(root)  # no need profile
            (root / "need_profile.json").write_text("{bad", encoding="utf-8")
            probe(root)
            (root / "need_profile.json").write_text("[]", encoding="utf-8")
            probe(root)
            (root / "need_profile.json").write_text(json.dumps({"category_pack_id": PACK_ID}), encoding="utf-8")
            probe(root)
        self.assertEqual(seen, [False, False, False, True])


if __name__ == "__main__":
    unittest.main()
