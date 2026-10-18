"""Branch coverage for landscape_critique_artifacts (pure functions + ledger patching)."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

import landscape_critique_artifacts as lca  # noqa: E402

CRITERIA = lca.INCLUSION_CRITERIA_ORDER


def audit() -> dict:
    return {
        "markets": {
            "apo": {"core": ["silver-bullet", "ai-dlc", "metagpt", "deepwork"], "adjacent": ["agenthub", "tembo", "misc-adj"]},
            "sdlc-plugins": {"core": ["silver-bullet", "bmad", "zuvo"], "adjacent": []},
            "agentic-sdlc-saas": {"core": ["devin"], "adjacent": ["conductor", "tembo"]},
            "broken": "not-a-dict",
        },
        "adjacent": ["top-adj"],
        "excluded": ["top-excl"],
        "sunset": ["top-sunset"],
    }


def vendor(slug, market, statuses=None, **extra):
    criteria = [{"criterion": name, "status": (statuses or {}).get(name, "pass"), "source": f"src-{i}"}
                for i, name in enumerate(CRITERIA)]
    return {"slug": slug, "market": market, "display": slug.title(), "criteria": criteria, **extra}


class SmallHelperTests(unittest.TestCase):
    def test_status_cell(self) -> None:
        self.assertEqual([lca.status_cell(x) for x in ("pass", "FAIL", "unknown", None, "", "weird")], ["P", "F", "U", "U", "U", "U"])

    def test_criterion_status_map(self) -> None:
        v = {"criteria": ["junk", {"criterion": "A", "status": "PASS"}, {"name": "B"}, {"status": "pass"}, {"criterion": " C ", "status": "fail"}]}
        self.assertEqual(lca.criterion_status_map(v), {"A": "pass", "B": "unknown", "C": "fail"})
        self.assertEqual(lca.criterion_status_map({}), {})

    def test_first_evidence_cite(self) -> None:
        self.assertEqual(lca.first_evidence_cite({"criteria": ["junk", {"source": " "}, {"source": "a|b"}, {"source": "later"}]}), "a/b")
        self.assertEqual(lca.first_evidence_cite({"criteria": [{}], "decision_note": "n" * 100}), "n" * 80)
        self.assertEqual(lca.first_evidence_cite({"threshold_note": "tn"}), "tn")
        self.assertEqual(lca.first_evidence_cite({}), "—")

    def test_load_inclusion_ledger(self) -> None:
        self.assertEqual(lca.load_inclusion_ledger(None), {})
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.assertEqual(lca.load_inclusion_ledger(root), {})
            path = root / "landscape" / "inclusion-ledger.json"
            path.parent.mkdir()
            path.write_text("{bad", encoding="utf-8")
            self.assertEqual(lca.load_inclusion_ledger(root), {})
            path.write_text("[1]", encoding="utf-8")
            self.assertEqual(lca.load_inclusion_ledger(root), {})
            path.write_text('{"vendors": []}', encoding="utf-8")
            self.assertEqual(lca.load_inclusion_ledger(root), {"vendors": []})
            with mock.patch.object(Path, "read_text", side_effect=OSError("io")):
                self.assertEqual(lca.load_inclusion_ledger(root), {})

    def test_hard_exclusion_slugs(self) -> None:
        self.assertEqual(lca._hard_exclusion_slugs(None), {"magic-dev"})
        self.assertEqual(lca._hard_exclusion_slugs({}), {"magic-dev"})
        pack = {"hard_exclusions": [{"slug": "bad-one"}], "sunset_registry": [{"slug": "gone"}]}
        self.assertEqual(lca._hard_exclusion_slugs(pack), {"magic-dev", "bad-one", "gone"})
        with mock.patch("category_pack.get_hard_exclusion_slugs", side_effect=RuntimeError("x")):
            self.assertEqual(lca._hard_exclusion_slugs(pack), {"magic-dev"})

    def test_market_block_helpers_ignore_malformed_blocks(self) -> None:
        a = audit()
        self.assertEqual(lca._market_core(a, "sdlc-plugins"), {"silver-bullet", "bmad", "zuvo"})
        self.assertEqual(lca._market_core(a, "broken"), set())
        self.assertEqual(lca._market_core(a, "missing"), set())
        self.assertEqual(lca._market_core(None, "apo"), set())
        self.assertEqual(lca._market_adjacent(a, "apo"), {"agenthub", "tembo", "misc-adj"})
        self.assertEqual(lca._market_adjacent(a, "broken"), set())
        self.assertEqual(lca._market_adjacent(None, "apo"), set())
        self.assertEqual(lca._home_core_markets("silver-bullet", a), ["apo", "sdlc-plugins"])
        self.assertEqual(lca._home_core_markets("nobody", a), [])
        self.assertEqual(lca._home_core_markets("x", None), [])


class FinalDecisionTests(unittest.TestCase):
    def decide(self, slug, market, pack=None, a=None):
        return lca.vendor_final_decision(slug, market, audit=a if a is not None else audit(), pack=pack)

    def test_all_branches(self) -> None:
        self.assertEqual(self.decide("magic-dev", "apo"), "hard-excluded")
        self.assertEqual(self.decide("conductor", "agentic-sdlc-saas"), "adjacent-aggregator (not APO)")
        self.assertEqual(self.decide("bmad", "sdlc-plugins"), "included-core")
        self.assertEqual(self.decide("agenthub", "apo"), "adjacent (APO CRM — not Leaders)")
        self.assertEqual(self.decide("tembo", "apo"), "adjacent (unplotted)")
        self.assertEqual(self.decide("misc-adj", "apo"), "adjacent")
        self.assertEqual(self.decide("bmad", "apo"), "core in sdlc-plugins only — not apo")
        self.assertEqual(self.decide("silver-bullet", "agentic-sdlc-saas"), "core in apo ∩ sdlc-plugins only — not agentic-sdlc-saas")
        self.assertEqual(self.decide("top-adj", "apo"), "adjacent")
        self.assertEqual(self.decide("top-excl", "apo"), "hard-excluded")
        self.assertEqual(self.decide("top-sunset", "apo"), "sunset")
        self.assertEqual(self.decide("unknown", "apo"), "not in core set")
        self.assertEqual(lca.vendor_final_decision(None, None, audit=None, pack=None), "not in core set")
        self.assertEqual(self.decide("pack-bad", "apo", pack={"hard_exclusions": [{"slug": "pack-bad"}]}), "hard-excluded")


class ExecutiveSummaryTests(unittest.TestCase):
    def test_leader_labels(self) -> None:
        chart = {"markets": {"apo": {"gmq_data": [{"q": "Leaders", "label": "L1"}, {"q": "Leaders", "slug": "s2"},
                                                  {"q": "Leaders"}, {"q": "Niche", "label": "N"}, "junk"]}}}
        self.assertEqual(lca._leader_labels(chart, "apo"), ["L1", "s2"])
        self.assertEqual(lca._leader_labels(chart, "other"), [])
        self.assertEqual(lca._leader_labels(None, "apo"), [])

    def test_defaults_without_data(self) -> None:
        text = "\n".join(lca.executive_summary_lines(chart=None, pack=None, known={}, audit=None))
        self.assertIn("- **APO (primary):** Silver Bullet", text)
        self.assertIn("- **SDLC plugins & methodology packs:** Silver Bullet", text)
        self.assertIn("- **Agentic SDLC SaaS:** Devin, Factory.ai, Augment Cosmos", text)
        self.assertIn("- **Spec-first / lean packs:** equal-standing OSS peers — pick on spec", text)
        self.assertIn("- **OSS APO cores:** equal-standing peers; AI-DLC", text)
        self.assertIn("- **Managed autonomous delivery:** Devin, Factory.ai, Augment Cosmos —", text)

    def test_with_chart_and_audit(self) -> None:
        chart = {"markets": {
            "apo": {"gmq_data": [{"q": "Leaders", "label": "ApoLead"}]},
            "sdlc-plugins": {"gmq_data": [{"q": "Leaders", "label": "PlugLead"}]},
            "agentic-sdlc-saas": {"gmq_data": [{"q": "Leaders", "label": "SaasLead"}]},
        }}
        known = {"bmad": "BMAD", "zuvo": "Zuvo", "devin": "Devin Inc", "metagpt": "MetaGPT"}
        a = audit()
        a["markets"]["sdlc-plugins"]["core"] = ["silver-bullet", "bmad", "zuvo", "x1", "x2", "x3", "x4"]
        text = "\n".join(lca.executive_summary_lines(chart=chart, pack=None, known=known, audit=a))
        self.assertIn("**APO (primary):** ApoLead", text)
        self.assertIn("**SDLC plugins & methodology packs:** PlugLead", text)
        self.assertIn("**Agentic SDLC SaaS:** SaasLead", text)
        self.assertIn("equal-standing OSS peers (BMAD, Zuvo, x1, x2, x3) —", text)  # capped at 5 and without silver-bullet
        self.assertIn("equal-standing peers (ai-dlc, MetaGPT, deepwork);", text)
        self.assertIn("**Managed autonomous delivery:** Devin Inc —", text)


class LedgerEmbedTests(unittest.TestCase):
    def write_ledger(self, root: Path, vendors) -> None:
        path = root / "landscape" / "inclusion-ledger.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps({"vendors": vendors}), encoding="utf-8")

    def test_rows_are_partitioned_and_wrong_market_rows_skipped(self) -> None:
        vendors = [
            vendor("bmad", "sdlc-plugins", {CRITERIA[0]: "fail", CRITERIA[1]: "weird"}),
            vendor("bmad", "apo"),  # wrong-market row: bmad is core elsewhere -> skipped
            vendor("magic-dev", "agentic-sdlc-saas"),  # hard-excluded even though not "home" elsewhere
            vendor("misc-adj", "apo"),
            vendor("unlisted", "apo", final_decision="included-core"),  # claims core but is core nowhere -> recomputed
            vendor("metagpt", "apo", final_decision="in review"),  # neither core nor adjacent nor excluded -> dropped
            vendor("ai-dlc", "apo", final_decision="included-core"),
            {"slug": "", "market": "", "criteria": []},
            "junk",
        ]
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.write_ledger(root, vendors)
            text = "\n".join(lca.inclusion_ledger_embed_lines(root=root, audit=audit(), pack=None, known={"bmad": "BMAD"}))
        self.assertIn("### Vendor inclusion ledger", text)
        self.assertIn("| Bmad | `sdlc-plugins` | F | U | P | P | P | P | P | src-0 | included-core |", text)
        self.assertNotIn("| Bmad | `apo` |", text)
        self.assertIn("_Hard-excluded — not membership.", text)
        self.assertIn("| Magic-Dev | `agentic-sdlc-saas` |", text)
        self.assertIn("_Adjacent (not core in that market)_", text)
        self.assertIn("| Misc-Adj | `apo` |", text)
        self.assertNotIn("| Metagpt |", text)
        self.assertIn("| Ai-Dlc | `apo` |", text)
        # "unlisted" recomputed to "not in core set" -> in none of the buckets -> not rendered
        self.assertNotIn("| Unlisted |", text)
        # zuvo/agenthub/conductor/tembo come from stubs when absent from the ledger
        self.assertIn("| Zuvo | `sdlc-plugins` | U | U | U | U | U | U | U | not in inclusion-ledger.json | included-core |", text)
        self.assertIn("| Agenthub | `apo` |", text)
        self.assertIn("adjacent (APO CRM — not Leaders)", text)
        self.assertIn("| Tembo | `agentic-sdlc-saas` |", text)

    def test_no_adjacent_or_excluded_section_when_nothing_qualifies(self) -> None:
        vendors = [vendor(slug, market, final_decision="weird") for slug, market in
                   (("conductor", "agentic-sdlc-saas"), ("zuvo", "sdlc-plugins"), ("agenthub", "apo"), ("tembo", "agentic-sdlc-saas"))]
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.write_ledger(root, vendors)
            lines = lca.inclusion_ledger_embed_lines(root=root, audit=audit(), pack=None, known={})
        text = "\n".join(lines)
        self.assertNotIn("_Adjacent", text)
        self.assertNotIn("_Hard-excluded", text)
        self.assertEqual(lines[-2], "|" + "---|" * 11)
        self.assertEqual(lines[-1], "")

    def test_stub_rows_without_ledger_or_audit(self) -> None:
        lines = lca.inclusion_ledger_embed_lines(root=None, audit=None, pack=None, known={"zuvo": "Zuvo!"})
        text = "\n".join(lines)
        # With no audit nothing is core: zuvo/agenthub/tembo stubs are "not in core set" and not rendered,
        # but conductor is always an adjacent aggregator.
        self.assertNotIn("Zuvo!", text)
        self.assertNotIn("| Agenthub", text)
        self.assertIn("_Adjacent (not core in that market)_", text)
        self.assertIn("| Conductor | `agentic-sdlc-saas` | U | U | U | U | U | U | U | not in inclusion-ledger.json | adjacent-aggregator (not APO) |", text)
        self.assertNotIn("_Hard-excluded", text)
        self.assertEqual(lines[-1], "")

    def test_seen_vendor_suppresses_its_stub(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.write_ledger(root, [vendor("zuvo", "sdlc-plugins")])
            text = "\n".join(lca.inclusion_ledger_embed_lines(root=root, audit=audit(), pack=None, known={}))
        self.assertEqual(text.count("| Zuvo |"), 1)
        self.assertNotIn("not in inclusion-ledger.json | included-core |\n| Zuvo", text)
        self.assertNotIn("not in inclusion-ledger.json", text.split("| Zuvo |")[1].split("\n")[0])


class CoverageMatrixTests(unittest.TestCase):
    def test_evidence_available(self) -> None:
        self.assertEqual(lca._evidence_available(None, "x"), "unknown")
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.assertEqual(lca._evidence_available(root, "x"), "missing")
            sol = root / "solutions" / "x"
            sol.mkdir(parents=True)
            (sol / "scr.md").write_text("s", encoding="utf-8")
            self.assertEqual(lca._evidence_available(root, "x"), "partial (scr.md)")
            (sol / "features.json").write_text("{}", encoding="utf-8")
            self.assertEqual(lca._evidence_available(root, "x"), "yes (features.json + scr.md)")
            (sol / "scr.md").unlink()
            self.assertEqual(lca._evidence_available(root, "x"), "partial (features.json)")

    def test_matrix_rows_and_gap_texts(self) -> None:
        a = {
            "markets": {
                "apo": {"core": ["silver-bullet", "metagpt", "deepwork", "ai-dlc", "zuvo", "dup"],
                        "adjacent": ["agenthub", "dup", "conductor", "tembo"]},
                "agentic-sdlc-saas": {"core": ["ateam"], "adjacent": ["conductor", "tembo"]},
                "bad": "x",
            },
        }
        comparison = {"rankings": [{"solution": "silver-bullet"}, {"solution": "deepwork"}, {"nosolution": 1}, "junk"]}
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            sol = root / "solutions" / "silver-bullet"
            sol.mkdir(parents=True)
            (sol / "features.json").write_text("{}", encoding="utf-8")
            (sol / "scr.md").write_text("s", encoding="utf-8")
            lines = lca.coverage_completeness_lines(root=root, audit=a, comparison=comparison, pack=None, known={"silver-bullet": "SB"})
        text = "\n".join(lines)
        self.assertIn("### Coverage completeness matrix", text)
        self.assertIn("| SB | yes (features.json + scr.md) | yes | `apo` / included-core | — |", text)
        self.assertIn("| Metagpt | missing | no | `apo` / included-core | APO OSS core without solution artifacts in this run", text)
        self.assertIn("core without ranking row", text)
        self.assertIn("| Deepwork | missing | yes | `apo` / included-core | thin-evidence APO commercial", text)
        self.assertIn("no solution artifacts", text)
        self.assertIn("| Agenthub | missing | no | `apo` / adjacent (APO CRM — not Leaders) | APO-adjacent CRM — not Leaders", text)
        self.assertIn("SaaS-adjacent aggregator; not APO core", text)
        self.assertIn("SaaS-adjacent / unplotted", text)
        self.assertIn("AWS/awslabs methodology-without-gates", text)
        self.assertIn("| Magic Dev | missing | no | `hard-excluded` / hard-excluded | quoted model error", text)
        self.assertIn("| Ateam | missing | no | `hard-excluded` / hard-excluded | hard-excluded FDE shop", text)
        self.assertEqual(text.count("| Dup |"), 1)
        # a repeated slug within one market and a market literally named "hard-excluded" are deduplicated
        a_dup = {"markets": {"apo": {"core": ["x", "x"], "adjacent": []},
                             "hard-excluded": {"core": ["magic-dev"], "adjacent": []}}}
        text_dup = "\n".join(lca.coverage_completeness_lines(root=None, audit=a_dup, comparison={}, pack=None, known={}))
        self.assertEqual(text_dup.count("| X |"), 1)
        self.assertEqual(text_dup.count("| Magic Dev |"), 1)
        # agenthub outside apo gets no CRM gap text
        a2 = {"markets": {"other": {"core": [], "adjacent": ["agenthub"]}}}
        text2 = "\n".join(lca.coverage_completeness_lines(root=None, audit=a2, comparison={}, pack=None, known={}))
        self.assertNotIn("APO-adjacent CRM", text2)
        self.assertIn("| Agenthub | unknown | no |", text2)
        # no audit at all still lists the two hard-excluded rows
        text3 = "\n".join(lca.coverage_completeness_lines(root=None, audit=None, comparison={}, pack=None, known={}))
        self.assertIn("| Magic Dev | unknown", text3)
        self.assertIn("| Ateam | unknown", text3)

    def test_zuvo_row_has_no_gap(self) -> None:
        a = {"markets": {"sdlc-plugins": {"core": ["zuvo"], "adjacent": []}}}
        text = "\n".join(lca.coverage_completeness_lines(root=None, audit=a, comparison={"rankings": [{"solution": "zuvo"}]}, pack=None, known={}))
        self.assertIn("| Zuvo | unknown | yes | `sdlc-plugins` / included-core | — |", text)


class ConsensusTableTests(unittest.TestCase):
    def test_side_helpers(self) -> None:
        self.assertEqual(lca._side_agents({"supporting_agents": ["a", "", "b", "c", "d", "e"]}), "`a`, `b`, `c`, `d`")
        self.assertEqual(lca._side_agents({"model_families": ["fam"]}), "`fam`")
        self.assertEqual(lca._side_agents({}), "unattributed")
        item = {"sides": [
            "junk",
            {"supporting_agents": ["pro"], "stance": "positive"},
            {"supporting_agents": ["con"], "stance": "NEG"},
            {"supporting_agents": ["con2"], "label": "contra"},
            {"supporting_agents": ["con3"], "stance_text": "This is not true at all"},
            {"model_families": ["fam"], "stance_text": "x" * 40 + " not here"},
        ]}
        self.assertEqual(lca._sides_by_stance(item), ("`pro`; `fam`", "`con`; `con2`; `con3`"))
        self.assertEqual(lca._sides_by_stance({}), ("—", "—"))

    def test_table_uses_canonical_rows_regardless_of_notable(self) -> None:
        notable = [{"subject": "magic-dev", "sides": [{"supporting_agents": ["x"], "stance": "neg"}]}, "junk", {"nosubject": 1}]
        text = "\n".join(lca.consensus_resolution_table_lines(notable))
        self.assertIn("### Consensus Resolution Table", text)
        self.assertEqual(text.count("| Magic.dev membership"), 1)
        self.assertEqual(text.count("| AI-DLC is IBM"), 1)
        self.assertIn("FINAL: one membership — hard-excluded", text)
        plain = "\n".join(lca.consensus_resolution_table_lines(None))
        self.assertEqual(plain, text)


class PatchLedgerTests(unittest.TestCase):
    def test_patch_creates_ledger_adds_zuvo_and_writes_markdown(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            payload = lca.patch_inclusion_ledger(root, pack=None, audit=audit())
            self.assertEqual(payload["run_id"], "run-57f38dfa25d83cc50d224e283d4692f3")
            self.assertEqual(payload["reviewer"], "act-on-critique-artifacts")
            self.assertEqual([v["slug"] for v in payload["vendors"]], ["zuvo"])
            zuvo = payload["vendors"][0]
            self.assertEqual(zuvo["pass_count"], 5)
            self.assertTrue(zuvo["threshold_met"])
            self.assertEqual(zuvo["final_decision"], "included-core")
            self.assertEqual({c["status"] for c in zuvo["criteria"]}, {"pass", "unknown"})
            self.assertEqual({c["confidence"] for c in zuvo["criteria"]}, {"medium", "low"})
            on_disk = json.loads((root / "landscape" / "inclusion-ledger.json").read_text(encoding="utf-8"))
            self.assertEqual(on_disk, payload)
            md = (root / "landscape" / "inclusion-ledger.md").read_text(encoding="utf-8")
            self.assertTrue(md.startswith("# Inclusion ledger (3-of-7)"))
            self.assertIn("| Zuvo | `sdlc-plugins` | P | P | P | U | P | U | P |", md)
            self.assertIn("### Zuvo (`zuvo`) — sdlc-plugins", md)
            self.assertTrue(md.endswith("\n"))

    def test_patch_existing_vendors(self) -> None:
        vendors = [
            vendor("magic-dev", "agentic-sdlc-saas", threshold_met=True),
            vendor("pack-bad", "apo", threshold_met=True),
            vendor("bmad", "apo"),  # wrong market -> moved to its home
            vendor("metagpt", "apo"),  # right market
            vendor("zuvo", "sdlc-plugins"),  # already present: no extra zuvo appended
            {"slug": "norows", "market": "apo", "criteria": ["junk"]},
            "junk",
        ]
        pack = {"hard_exclusions": [{"slug": "pack-bad"}]}
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            path = root / "landscape" / "inclusion-ledger.json"
            path.parent.mkdir(parents=True)
            path.write_text(json.dumps({"run_id": "keep-me", "vendors": vendors}), encoding="utf-8")
            payload = lca.patch_inclusion_ledger(root, pack=pack, audit=audit())
            by = {v["slug"]: v for v in payload["vendors"]}
            self.assertEqual(payload["run_id"], "keep-me")
            self.assertEqual(len(payload["vendors"]), 6)
            self.assertEqual(by["magic-dev"]["final_decision"], "hard-excluded")
            self.assertFalse(by["magic-dev"]["threshold_met"])
            self.assertEqual(by["magic-dev"]["placement"], "hard-excluded")
            self.assertIn("coding_agent", by["magic-dev"]["decision_note"])
            self.assertEqual(by["pack-bad"]["final_decision"], "hard-excluded")
            self.assertFalse(by["pack-bad"]["threshold_met"])
            self.assertEqual(by["bmad"]["market"], "sdlc-plugins")
            self.assertEqual(by["bmad"]["final_decision"], "included-core")
            self.assertEqual(by["metagpt"]["final_decision"], "included-core")
            self.assertEqual(by["norows"]["final_decision"], "not in core set")
            md = (root / "landscape" / "inclusion-ledger.md").read_text(encoding="utf-8")
            self.assertIn("### norows (`norows`) — apo", md)
            self.assertNotIn("junk", md)
            # a ledger without run_id receives the default
            path.write_text(json.dumps({"vendors": []}), encoding="utf-8")
            self.assertEqual(lca.patch_inclusion_ledger(root, pack=None, audit=None)["run_id"], "run-57f38dfa25d83cc50d224e283d4692f3")

    def test_markdown_decision_falls_back_to_computed_value(self) -> None:
        payload = {"run_id": "r", "vendors": [vendor("bmad", "sdlc-plugins"), {"slug": "x", "market": "apo"}]}
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "landscape").mkdir()
            lca._write_inclusion_ledger_markdown(root, payload, pack=None, audit=audit())
            md = (root / "landscape" / "inclusion-ledger.md").read_text(encoding="utf-8")
        self.assertIn("| Bmad | `sdlc-plugins` | P | P | P | P | P | P | P | src-0 | included-core |", md)
        self.assertIn("| x | `apo` | U | U | U | U | U | U | U | — | not in core set |", md)
        self.assertIn("### x (`x`) — apo", md)


if __name__ == "__main__":
    unittest.main()
