"""Generative precision and signalled-recall test for vendor identity (DESIGN-H8b-vendor-detection).

An AMBIGUOUS vendor (none of its display tokens is distinctive) is credited only through an explicit
signal: a ``vendors`` tag, a ``source_ref`` that names it, or its pack URL in the text. The words around a name never credit it, so this test can
exhaust the grammar by construction: every ambiguous spelling in three cases through 30+ sentence
templates and a seeded random composition, all on three paths (classifier evidence, extract_slugs and the
feature parser), must credit nothing.
"""

from __future__ import annotations

import random
import sys
import time
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

import materialize_solution_artifacts as m  # noqa: E402
import solution_classifier as sc  # noqa: E402
from apo_pack_run_fixture import with_apo_pack_run  # noqa: E402
from category_pack import build_homepage_by_slug, build_known_solutions, resolve_pack_from_need  # noqa: E402

NEED = {"category_pack_id": "agentic-sdlc-process-orchestrator"}
# every cue family the five review rounds tried; none of them is a matrix line format (those have their own test)
TEMPLATES = (
    "{N} enforces review gates before merge.", "{N} ships hook-enforced gates and workflow composition.",
    "We compared {N} with LangGraph and CrewAI.", "The leaders are {N}, BMAD-METHOD and AgentSys.",
    "Players: {N}, Copilot, Captain.", "{N} IDE supports SSO and audit logs.", "The {N} app provides workflow composition.",
    "{N} v2 adds parent/child agent delegation.", "{N} 2.5 offers a free tier.", "{N} 4.0 initiatives start in May.",
    "{N} CLI provides hook-enforced gates.", "{N} Platform supports cross-session state.", "{N} AI provides workflow composition.",
    "{N} Code is a subspace.", "Use {N}, Claude Code or OpenHands for this.", "Open Claude Code or {N} reading.",
    "Unlike {N}, GitHub Copilot ships an agent mode.", "{N}'s plugin marketplace is free.", "In {N}, every phase ends with a gate.",
    "## {N}\nProvides hook-enforced gates.", "**{N}** provides workflow composition.", "`{n}` provides workflow composition.",
    "[{N}](#overview) provides workflow composition.", "[{N}](https://en.wikipedia.org/wiki/{U}) provides workflow composition.",
    "{n} provides workflow composition.", "{UP} PROVIDES WORKFLOW COMPOSITION.", "Teams that use {N} report faster refactors.",
    "Solutions include {N}, Zuvo and Turboshovel.", "{N} (the product) supports SSO.", "{N} (Acme) supports SSO.",
    "{N} by its maker supports SSO.", "Melty {N} tracks distort when the vinyl gets warm.", "The {N} raised the baton.",
    "Products: {N}; AI-DLC; SuperClaude.", "{N}-style gates are enforced by AgentHub.", "Hard exclusions: {N}, Sweep, Windsurf.",
    "{N}.", "{N} provides workflow composition, says the {N} team.", "{N} at example.com provides workflow composition.",
    "See {n}.dev for details; {N} provides gates.",
)
CASING_TEMPLATES = (TEMPLATES[0], TEMPLATES[3], TEMPLATES[24])
NEIGHBOURS = ("LangGraph", "CrewAI", "BMAD-METHOD", "AgentSys", "Zuvo", "Turboshovel", "OpenHands", "cc10x", "MetaGPT")
PUNCTUATION = (".", "!", ";", ":", "?", "...")
START = ("{N}", "The {N}", "Our {N}", "Each {N}", "Then {N}", "## {N}", "- {N}", "1. {N}", "> {N}", "\"{N}\"")
MIDDLE = ("{x} and {N}", "{x}, {N} and {y}", "{N} or {x}", "with {N}", "from {N}", "the {N}", "no {N}", "{N}-based", "{N}'s")
REST = (" enforces gates", " is a tool", " raised the baton", " matters", " reviewed the plan", " 2.0 shipped", " IDE launched",
        " provides workflow composition", " are listed here", "")


def env(text, row=None):
    item = {"text": text}
    item.update(row or {})
    return [{"phase_id": "DR-TRIANGULATE", "logical_model_id": "m", "payload": {"claim_candidates": [item]}}]


def titled(name):
    return " ".join(word[:1].upper() + word[1:] for word in name.split())


@with_apo_pack_run
class GenerativeVendorIdentityTests(unittest.TestCase):
    def setUp(self) -> None:
        self.pack = resolve_pack_from_need(NEED)
        self.known = m._effective_known_solutions(NEED)
        self.homes = build_homepage_by_slug(self.pack)

    @property
    def registry(self):  # built inside the test, where the pack run context is installed
        return m.vendor_registry()

    @property
    def ambiguous(self):
        return self.registry.ambiguous_vendors()

    def credited(self, text, row=None, parse=True):
        rows = env(text, row)
        evidence = set(sc._envelope_evidence_slugs(rows, self.pack))
        extracted = set(m._extract_slugs_from_text(text, self.known, self.pack))
        support = set()
        if parse:  # the feature parser is the slow path: it runs on the first spelling of each vendor and on every signal
            support = {slug for slug, cells in m.parse_feature_support(rows, known=self.known, pack=self.pack).items() if any(cells.values())}
        return evidence | extracted | support

    def spellings(self, slug):
        names = {s.replace("-", " ") for s in self.registry.spellings_of[slug] if "(" not in s}
        return sorted(names)

    def test_the_registry_finds_the_ambiguous_vendors_of_the_pack(self) -> None:
        self.assertGreaterEqual(len(self.ambiguous), 20)
        for slug in ("director", "cursor-agents", "linear", "conductor", "devin", "gsd", "silver-bullet", "windsurf", "cline"):
            self.assertIn(slug, self.ambiguous)
        for slug in ("github-copilot", "factory-ai", "cc10x", "agentsys", "zuvo", "openhands"):
            self.assertNotIn(slug, self.ambiguous)

    def test_no_sentence_template_credits_an_ambiguous_vendor(self) -> None:
        started = time.monotonic()
        leaks, total = [], 0
        for slug in self.ambiguous:
            targets = self.registry.slugs_of_vendor(slug)
            for position, name in enumerate(self.spellings(slug)):
                shown = titled(name)
                cases = [(shown, TEMPLATES), (name.lower(), CASING_TEMPLATES), (name.upper(), CASING_TEMPLATES)]
                for spelled, templates in cases:
                    for template in templates:
                        text = template.format(N=spelled, n=name.lower(), U=spelled.replace(" ", "_"), UP=name.upper())
                        total += 1
                        if self.credited(text, parse=position == 0) & targets:
                            leaks.append(text)
        self.assertEqual(leaks, [], f"{len(leaks)} of {total} sentences credit an ambiguous vendor")
        self.assertLess(time.monotonic() - started, 300)

    def test_seeded_random_compositions_credit_no_ambiguous_vendor(self) -> None:
        rng = random.Random(20260705)
        pairs = [(slug, name) for slug in self.ambiguous for name in self.spellings(slug)]
        leaks = []
        for _ in range(200):
            slug, name = rng.choice(pairs)
            spelled = rng.choice((titled(name), name.lower(), name.upper()))
            middle = rng.choice(MIDDLE).format(N=spelled, x=rng.choice(NEIGHBOURS), y=rng.choice(NEIGHBOURS))
            text = rng.choice(START).format(N=middle if rng.random() < 0.5 else spelled) + rng.choice(REST) + rng.choice(PUNCTUATION)
            if self.credited(text, parse=False) & self.registry.slugs_of_vendor(slug):
                leaks.append(text)
        self.assertEqual(leaks, [])

    def test_every_explicit_signal_credits_the_canonical_vendor(self) -> None:
        misses, checked = [], 0
        for slug in self.ambiguous:
            display = min(self.registry.displays[slug], key=len)
            if self.registry.slugs_of(display) != {slug}:
                continue  # the pack gives two slugs the same display name; the display then names the other one
            text = f"{display} provides workflow composition."
            signals = [
                ("vendors tag", text, {"vendors": [slug]}),
                ("source_ref display", text, {"source_ref": display}),
            ]
            if slug in build_known_solutions(self.pack):  # the classifier resolves tags against the pack's own names
                signals.append(("vendors tag, no mention", "The row is about the product named in the tag.", {"vendors": [slug]}))
            if slug in self.homes:
                signals.append(("source_ref pack URL", text, {"source_ref": self.homes[slug]}))
                signals.append(("pack URL in the text", f"{display} ({self.homes[slug]}) provides workflow composition.", None))
                signals.append(("pack URL as a link target", f"[{display}]({self.homes[slug]}) provides workflow composition.", None))
            for label, sentence, row in signals:
                checked += 1
                if slug not in {self.registry.canonical(s) for s in self.credited(sentence, row)}:
                    misses.append((label, slug, sentence))
        self.assertEqual(misses, [], f"{len(misses)} of {checked} signals did not credit")

    def test_a_source_ref_alone_never_invents_a_vendor(self) -> None:
        self.assertNotIn("director", self.credited("The report covers pricing only.", {"source_ref": "Director"}))
        self.assertIn("director", self.credited("Director enforces gates.", {"source_ref": "Director"}))
        self.assertNotIn("director", self.credited("Director enforces gates.", {"source_ref": "Directory of services"}))


if __name__ == "__main__":
    unittest.main()
