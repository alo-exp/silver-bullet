#!/usr/bin/env python3
"""Deterministic unit tests for reference chain tracker — no network."""

import json
import sys
import tempfile
import unittest
from pathlib import Path

SKILL_ROOT = Path(__file__).resolve().parent.parent
SCRIPTS = SKILL_ROOT / "scripts"
sys.path.insert(0, str(SCRIPTS))

from chain_tracker import (  # noqa: E402
    ChainTracker,
    extract_links,
    load_or_create,
    normalize_domain,
    save_tracker,
)


class TestChainTrackerHelpers(unittest.TestCase):
    def test_extract_links_dedup_and_cap(self):
        text = (
            "See https://example.com/a and https://example.com/a "
            "and https://other.org/b then https://third.dev/c"
        )
        links = extract_links(text, max_links=2)
        self.assertEqual(links, ["https://example.com/a", "https://other.org/b"])

    def test_normalize_domain_strips_www(self):
        self.assertEqual(normalize_domain("https://www.Example.COM/path"), "example.com")


class TestChainTracker(unittest.TestCase):
    def test_add_source_respects_depth_and_dedup(self):
        tracker = ChainTracker(max_depth=1, max_nodes=10)
        self.assertTrue(tracker.add_source("https://a.test", depth=0))
        self.assertFalse(tracker.add_source("https://a.test", depth=0))
        self.assertTrue(tracker.add_source("https://b.test", parent="n0", depth=1))
        self.assertFalse(tracker.add_source("https://c.test", parent="n1", depth=2))

    def test_follow_references_builds_edges(self):
        tracker = ChainTracker(max_depth=2, max_nodes=10)
        tracker.add_source("https://root.test", depth=0)
        added = tracker.follow_references(
            "https://root.test",
            "refs https://child.test and https://grand.test",
            parent_id="n0",
            depth=0,
        )
        self.assertEqual(added, ["https://child.test", "https://grand.test"])
        self.assertEqual(len(tracker.edges), 2)

    def test_load_or_create_roundtrip(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "reference-chain.json"
            tracker = ChainTracker(max_depth=2)
            tracker.add_source("https://persist.test", depth=0)
            save_tracker(tracker, path)
            loaded = load_or_create(path)
            self.assertEqual(len(loaded.nodes), 1)
            self.assertEqual(loaded.nodes[0]["url"], "https://persist.test")
            data = json.loads(path.read_text(encoding="utf-8"))
            self.assertEqual(data["node_count"], 1)


if __name__ == "__main__":
    unittest.main()
