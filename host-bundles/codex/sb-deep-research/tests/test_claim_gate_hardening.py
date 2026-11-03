"""Claim-support gate, report-path and JSONL-store hardening.

Covers R11-02 (unsupported claims marked supported), R11-03 (JSON only via argv),
R11-05/R11-14 (documented interface and report path), R11-13 (unbounded citation numbers
in extract_claims), R11-25 (unlocked read-check-append, inconsistent numbering), R11-26
(non-atomic rewrite that drops rows) and R11-28 (absolute paths in init-run).
"""

import io
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from covhelp import SCRIPTS, call_main, run_script

import citation_manager
import evidence_store
import extract_claims
import verify_claim_support as vcs

SKILL = SCRIPTS.parent


def jsonl(path):
    return [json.loads(line) for line in Path(path).read_text(encoding="utf-8").splitlines() if line.strip()]


class Run(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.dir = Path(tmp.name)

    def cli(self, module, *argv, stdin=None):
        with mock.patch.object(sys, "stdin", io.StringIO(stdin or "")):
            return call_main(module, list(argv))


class SupportScoringTests(unittest.TestCase):
    """R11-02: absent feature classes are neutral, never a free match."""

    def test_claim_without_overlap_is_not_supported(self):
        status, score, _ = vcs.compute_support_score(
            "the vendor guarantees zero downtime for all customers", ["the weather was cold and windy yesterday"]
        )
        self.assertNotEqual(status, "supported")
        self.assertLess(score, 0.35)

    def test_shared_entity_does_not_support_a_contradicting_claim(self):
        status, _, _ = vcs.compute_support_score(
            "Kubernetes is deprecated and unsafe for production", ["Kubernetes is the most popular container orchestrator"]
        )
        self.assertNotEqual(status, "supported")

    def test_wrong_number_is_not_support(self):
        status, _, notes = vcs.compute_support_score("Latency fell 40% in 2024", ["Latency fell 10% in 2024"])
        self.assertNotEqual(status, "supported")
        self.assertIn("figure not matched in the source: 40%", notes)
        self.assertEqual(status, "needs_review")

    def test_matching_evidence_is_still_supported(self):
        status, score, _ = vcs.compute_support_score(
            "Acme Corp revenue grew 40% in 2024", ["In 2024 Acme Corp reported that revenue grew 40% year on year."]
        )
        self.assertEqual(status, "supported")
        self.assertGreaterEqual(score, 0.6)


class ClassificationTests(unittest.TestCase):
    """R11-02: classification uses whole words, so factual claims keep their hard gate."""

    def test_substrings_no_longer_change_the_type(self):
        cases = {
            "Revenue grew by a considerable 40% in 2024 according to the filing.": "factual",
            "The benchmark data suggests latency fell 30% in 2025 across regions.": "factual",
            "Mighty Networks raised 50 million dollars in 2023 from investors.": "factual",
        }
        for text, expected in cases.items():
            self.assertEqual(extract_claims.classify_claim(text, "finding_1"), expected, text)

    def test_real_recommendations_and_speculation_are_still_detected(self):
        self.assertEqual(extract_claims.classify_claim("Teams should adopt the managed offering first.", "x"), "recommendation")
        self.assertEqual(extract_claims.classify_claim("Consider adopting the managed offering for new services.", "x"), "recommendation")
        self.assertEqual(extract_claims.classify_claim("We recommend a phased rollout across regions.", "x"), "recommendation")
        self.assertEqual(extract_claims.classify_claim("This might change next year as vendors consolidate.", "x"), "speculation")
        self.assertEqual(extract_claims.classify_claim("Taken together, the vendors converge on one model.", "synthesis"), "synthesis")


class CitationInferenceTests(unittest.TestCase):
    """R11-02: an uncited claim never inherits a citation from another paragraph or bullet."""

    def test_no_inheritance_across_paragraphs(self):
        report = "The vendor guarantees zero downtime for all customers.\n\nWeather was cold yesterday [1].\n"
        self.assertEqual(vcs.infer_citation_numbers_from_context(report, "The vendor guarantees zero downtime for all customers."), [])

    def test_no_inheritance_across_bullets_or_headings(self):
        report = "- First uncited bullet claim here.\n- Second bullet with source [2].\n## Next\nMore [3].\n"
        self.assertEqual(vcs.infer_citation_numbers_from_context(report, "First uncited bullet claim here."), [])
        heading = "Claim right before a heading.\n## Section\nCited text [4].\n"
        self.assertEqual(vcs.infer_citation_numbers_from_context(heading, "Claim right before a heading."), [])

    def test_same_paragraph_citation_is_still_used(self):
        report = "Revenue grew 40% in 2024. Margins also improved [2, 3].\n\nOther [9].\n"
        self.assertEqual(vcs.infer_citation_numbers_from_context(report, "Revenue grew 40% in 2024."), [2, 3])


class StrictGateEndToEndTests(Run):
    """R11-02: verify --strict fails a fabricated claim that the old scoring passed."""

    def build(self, claim_sentence, quote):
        d = self.dir
        self.assertEqual(self.cli(citation_manager, "init-run", "--out-dir", str(d))[0], 0)
        out = self.cli(citation_manager, "register-source", "--dir", str(d), "--json", "-",
                       stdin=json.dumps({"raw_url": "https://weather.example/today", "title": "Weather"}))[1]
        sid = json.loads(out)["source_id"]
        self.cli(evidence_store, "add", "--dir", str(d), "--json", "-", stdin=json.dumps({"source_id": sid, "quote": quote}))
        report = (
            "# Report\n\n## Finding 1\n\n" + claim_sentence + "\n\nThe weather report covered the whole region [1].\n\n"
            "## Bibliography\n\n[1] Weather desk. https://weather.example/today\n"
        )
        (d / "research_report.md").write_text(report, encoding="utf-8")
        self.cli(extract_claims, "extract", "--report", str(d / "research_report.md"), "--dir", str(d))
        return d

    def test_fabricated_claim_fails_strict(self):
        d = self.build("The vendor guarantees zero downtime for all customers and has never had a breach.",
                       "the weather was cold and windy yesterday")
        code, out, _ = self.cli(vcs, "verify", "--dir", str(d), "--strict")
        self.assertEqual(code, 1, out)
        summary = json.loads(out)
        self.assertEqual(summary["status"], "fail")
        self.assertGreaterEqual(summary["factual_not_supported"], 1)
        vendor = [c for c in jsonl(d / "claims.jsonl") if "zero downtime" in c["text"]][0]
        self.assertEqual(vendor["cited_source_ids"], [])
        self.assertEqual(vendor["support_status"], "unsupported")

    def test_supported_report_passes_strict(self):
        d = self.build("Acme Corp revenue grew 40% in 2024 according to its annual filing [1].",
                       "Acme Corp revenue grew 40% in 2024, its annual filing shows.")
        claims = jsonl(d / "claims.jsonl")
        # Keep only the claim under test so the honest variant is judged alone.
        (d / "claims.jsonl").write_text(json.dumps([c for c in claims if "Acme" in c["text"]][0]) + "\n")
        code, out, _ = self.cli(vcs, "verify", "--dir", str(d), "--strict")
        self.assertEqual(code, 0, out)

    def test_generated_artifacts_fit_their_schemas(self):
        """R11-14: the shipped schemas accept every field the scripts write."""
        d = self.build("Acme Corp revenue grew 40% in 2024 according to its annual filing [1].",
                       "Acme Corp revenue grew 40% in 2024, its annual filing shows.")
        self.cli(vcs, "verify", "--dir", str(d))
        claim_schema = json.loads((SKILL / "schemas" / "claim.schema.json").read_text())
        for row in jsonl(d / "claims.jsonl"):
            self.assertLessEqual(set(row), set(claim_schema["properties"]), row)
            self.assertTrue(set(claim_schema["required"]) <= set(row))
            self.assertIn(row["support_status"], claim_schema["properties"]["support_status"]["enum"])
        manifest_schema = json.loads((SKILL / "schemas" / "run_manifest.schema.json").read_text())
        manifest = json.loads((d / "run_manifest.json").read_text())
        self.assertLessEqual(set(manifest), set(manifest_schema["properties"]))
        self.assertTrue(set(manifest_schema["required"]) <= set(manifest))
        self.assertLessEqual(set(manifest["artifact_paths"]), set(manifest_schema["properties"]["artifact_paths"]["properties"]))

    def test_speculation_without_links_is_not_applicable(self):
        (self.dir / "research_report.md").write_text("# R\n\n## Bibliography\n")
        (self.dir / "claims.jsonl").write_text(json.dumps(
            {"claim_id": "a" * 16, "section_id": "s", "text": "This might change.", "claim_type": "speculation"}) + "\n")
        self.cli(vcs, "verify", "--dir", str(self.dir))
        self.assertEqual(jsonl(self.dir / "claims.jsonl")[0]["support_status"], "not_applicable")


class ReportPathTests(Run):
    """R11-05 / R11-14 / R11-28: one report path, explicit --report, no local paths."""

    def test_init_run_records_research_report_and_no_local_path(self):
        code, out, _ = self.cli(citation_manager, "init-run", "--out-dir", str(self.dir), "--query", "q")
        self.assertEqual(code, 0)
        text = (self.dir / "run_manifest.json").read_text()
        manifest = json.loads(text)
        self.assertEqual(manifest["artifact_paths"]["report"], "research_report.md")
        self.assertEqual(manifest["report_dir"], ".")
        self.assertNotIn(str(self.dir), text)
        self.assertNotIn(os.path.expanduser("~"), text)

    def test_newer_markdown_files_are_never_mistaken_for_the_report(self):
        self.cli(citation_manager, "init-run", "--out-dir", str(self.dir))
        (self.dir / "research_report.md").write_text("report")
        critique = self.dir / "critique.md"
        critique.write_text("critique")
        os.utime(critique, (2_000_000_000, 2_000_000_000))
        self.assertEqual(Path(vcs._find_report_path(str(self.dir))).name, "research_report.md")
        (self.dir / "research_report.md").unlink()
        self.assertIsNone(vcs._find_report_path(str(self.dir)))

    def test_verify_fails_closed_without_a_report(self):
        (self.dir / "claims.jsonl").write_text("")
        code, _, err = self.cli(vcs, "verify", "--dir", str(self.dir))
        self.assertEqual(code, 2)
        self.assertIn("report not found", err)
        code, _, err = self.cli(vcs, "verify", "--dir", str(self.dir), "--report", str(self.dir / "nope.md"))
        self.assertEqual(code, 2)

    def test_plain_url_and_title_dash_url_bibliographies_map_to_the_right_source(self):
        report = (
            "## Bibliography\n\n[1] Beta paper (2024). https://b.example/x.\n"
            "[2] Alpha - https://a.example/y\n[3] Gamma. [Gamma site](https://c.example/z)\n"
        )
        self.assertEqual(vcs.parse_bibliography_number_to_url(report),
                         {1: "https://b.example/x", 2: "https://a.example/y", 3: "https://c.example/z"})
        sources = [
            {"source_id": "aaaaaaaaaaaaaaaa", "raw_url": "https://a.example/y", "canonical_locator": "https://a.example/y"},
            {"source_id": "bbbbbbbbbbbbbbbb", "raw_url": "https://b.example/x", "canonical_locator": "https://b.example/x"},
        ]
        mapping = vcs.build_display_number_to_source_id(sources, vcs.parse_bibliography_number_to_url(report))
        self.assertEqual(mapping[1], "bbbbbbbbbbbbbbbb")
        self.assertEqual(mapping[2], "aaaaaaaaaaaaaaaa")


class ClaimLedgerIntegrityTests(Run):
    """R11-26: verify keeps every row and rewrites claims.jsonl atomically."""

    def write_claims(self, rows):
        (self.dir / "research_report.md").write_text("# R\n\n## Bibliography\n")
        (self.dir / "claims.jsonl").write_text("".join(json.dumps(r) + "\n" for r in rows))

    def test_claims_without_ids_all_survive(self):
        self.write_claims([
            {"section_id": "finding_1", "text": "Alpha holds the largest share of the market."},
            {"section_id": "finding_1", "text": "Beta doubled its revenue in the last year."},
            {"section_id": "finding_2", "text": "Gamma exited the market after the acquisition."},
            {"section_id": "bibliography", "text": "[1] Some source https://x.example"},
        ])
        self.cli(vcs, "verify", "--dir", str(self.dir))
        rows = jsonl(self.dir / "claims.jsonl")
        self.assertEqual(len(rows), 4)
        self.assertEqual(len({r["claim_id"] for r in rows}), 4)
        self.assertEqual(rows[0]["claim_id"], extract_claims.compute_claim_id("finding_1", rows[0]["text"]))
        bib = [r for r in rows if r["section_id"] == "bibliography"][0]
        self.assertEqual(bib["support_status"], "not_applicable")

    def test_failed_rewrite_leaves_the_ledger_intact(self):
        self.write_claims([{"claim_id": "c" * 16, "section_id": "s", "text": "Claim one is long enough here."}])
        before = (self.dir / "claims.jsonl").read_bytes()
        with mock.patch.object(os, "replace", side_effect=OSError("disk full")):
            with self.assertRaises(OSError):
                self.cli(vcs, "verify", "--dir", str(self.dir))
        self.assertEqual((self.dir / "claims.jsonl").read_bytes(), before)
        self.assertEqual([p.name for p in self.dir.iterdir() if p.name.endswith(".tmp")], [])

    def test_corrupt_line_is_reported_not_silently_dropped(self):
        (self.dir / "research_report.md").write_text("# R\n")
        (self.dir / "claims.jsonl").write_text('{"claim_id": "x"}\n{broken\n')
        code, _, err = self.cli(vcs, "verify", "--dir", str(self.dir))
        self.assertEqual(code, 2)
        self.assertIn("claims.jsonl:2", err)


class JsonInputTests(Run):
    """R11-03: untrusted text reaches the stores through stdin or a file, never a shell quote."""

    HOSTILE = "Latency fell 40%'; touch PWNED; echo 'as reported $(id) `uname` \"q\""

    def test_stdin_and_file_input_store_text_byte_for_byte(self):
        d = str(self.dir)
        self.cli(citation_manager, "init-run", "--out-dir", d)
        out = self.cli(citation_manager, "register-source", "--dir", d, "--json", "-",
                       stdin=json.dumps({"raw_url": "https://x.example/a", "title": self.HOSTILE}))[1]
        sid = json.loads(out)["source_id"]
        payload = self.dir / "ev.json"
        payload.write_text(json.dumps({"source_id": sid, "quote": self.HOSTILE}), encoding="utf-8")
        self.assertEqual(self.cli(evidence_store, "add", "--dir", d, "--json-file", str(payload))[0], 0)
        claim = self.dir / "claim.json"
        claim.write_text(json.dumps({"section_id": "s", "text": self.HOSTILE}), encoding="utf-8")
        self.assertEqual(self.cli(extract_claims, "add", "--dir", d, "--json-file", str(claim))[0], 0)
        self.assertEqual(jsonl(self.dir / "sources.jsonl")[0]["title"], self.HOSTILE)
        self.assertEqual(jsonl(self.dir / "evidence.jsonl")[0]["quote"], self.HOSTILE)
        self.assertEqual(jsonl(self.dir / "claims.jsonl")[0]["text"], self.HOSTILE)
        self.assertFalse((self.dir / "PWNED").exists())

    def test_invalid_json_is_a_clear_error(self):
        for module, argv in ((citation_manager, ["register-source"]), (evidence_store, ["add"]), (extract_claims, ["add"])):
            code, _, err = self.cli(module, *argv, "--dir", str(self.dir), "--json", "-", stdin="{not json")
            self.assertEqual(code, 1, module.__name__)
            self.assertIn("invalid JSON input", err)
            code, _, err = self.cli(module, *argv, "--dir", str(self.dir), "--json", "[1, 2]")
            self.assertEqual(code, 1, module.__name__)

    def test_docs_never_put_json_in_single_quotes(self):
        offenders = []
        for path in [SKILL / "SKILL.md", SKILL / "README.md", *sorted((SKILL / "reference").rglob("*.md"))]:
            for no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
                if "--json '" in line or '--json "' in line:
                    offenders.append(f"{path.relative_to(SKILL)}:{no}")
        self.assertEqual(offenders, [])


class StoreConcurrencyTests(Run):
    """R11-25: read-check-append runs under a lock; numbering is consistent."""

    def test_register_source_waits_for_the_store_lock(self):
        import fcntl

        d = self.dir
        (d / "sources.jsonl").write_text("")
        lock = open(d / ".jsonl.lock", "a")
        self.addCleanup(lock.close)
        fcntl.flock(lock, fcntl.LOCK_EX)
        proc = subprocess.Popen(
            [sys.executable, str(SCRIPTS / "citation_manager.py"), "register-source", "--dir", str(d), "--json",
             json.dumps({"raw_url": "https://x.example/p", "title": "t"})],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        )
        self.addCleanup(proc.kill)
        with self.assertRaises(subprocess.TimeoutExpired):
            proc.wait(timeout=1.0)
        fcntl.flock(lock, fcntl.LOCK_UN)
        self.assertEqual(proc.wait(timeout=20), 0)
        self.assertEqual(len(jsonl(d / "sources.jsonl")), 1)

    def test_display_numbers_match_the_exported_bibliography(self):
        rows = [
            {"source_id": "a" * 16, "canonical_locator": "a", "raw_url": "https://a"},
            {"source_id": "a" * 16, "canonical_locator": "a", "raw_url": "https://a"},
            {"source_id": "b" * 16, "canonical_locator": "b", "raw_url": "https://b"},
        ]
        (self.dir / "sources.jsonl").write_text("".join(json.dumps(r) + "\n" for r in rows))
        numbers = json.loads(self.cli(citation_manager, "assign-display-numbers", "--dir", str(self.dir))[1])
        exported = json.loads(self.cli(citation_manager, "export-bibliography", "--dir", str(self.dir), "--style", "json")[1])
        self.assertEqual(numbers, {e["source_id"]: e["display_number"] for e in exported})
        self.assertEqual(numbers["b" * 16], 2)


class ExtractClaimsBoundsTests(Run):
    """R11-13: huge bracketed numbers neither crash nor become citations."""

    def test_long_digit_runs_are_ignored(self):
        report = self.dir / "r.md"
        report.write_text("# R\n\n## Finding 1\n\nThe identifier [" + "9" * 5000 + "] appears in this long sentence [2].\n")
        code, out, _ = self.cli(extract_claims, "extract", "--report", str(report), "--dir", str(self.dir))
        self.assertEqual(code, 0)
        self.assertEqual(jsonl(self.dir / "claims.jsonl")[0]["_citation_numbers"], [2])

    def test_bibliography_sections_are_not_extracted_as_claims(self):
        report = self.dir / "r.md"
        report.write_text("# R\n\n## Finding 1\n\nA finding sentence that is long enough to keep [1].\n\n"
                          "## Bibliography\n\n[1] Some long bibliography entry title. https://x.example/a\n")
        self.cli(extract_claims, "extract", "--report", str(report), "--dir", str(self.dir))
        self.assertEqual({c["section_id"] for c in jsonl(self.dir / "claims.jsonl")}, {"finding_1"})


if __name__ == "__main__":
    unittest.main()


class DocumentedCommandsTests(Run):
    """R11-05 / R11-16: every command the docs tell the agent to run parses, and the claim gate works."""

    DOCS = ["SKILL.md", "README.md"]
    BAD = ("unrecognized arguments", "invalid choice", "arguments are required", "usage:")

    def commands(self):
        import re
        import shlex
        root = SKILL
        files = [root / n for n in self.DOCS] + sorted((root / "reference").rglob("*.md"))
        found = []
        for path in files:
            text = path.read_text(encoding="utf-8")
            for block in re.findall(r"```(?:bash|sh)\n(.*?)```", text, re.S):
                joined = re.sub(r"\\\n\s*", " ", block)
                for line in joined.splitlines():
                    line = line.strip()
                    if not line.startswith("python3 skills/silver-deep-research/scripts/"):
                        continue
                    if any(t in line for t in ("<<", "|", "<run", "<dir", "...", "[")):
                        continue
                    found.append((path.name, shlex.split(line.replace('"', '"'))))
        return found

    def test_every_documented_script_command_parses(self):
        cmds = self.commands()
        self.assertGreaterEqual(len(cmds), 8)
        seen = set()
        env = {**os.environ, "SB_RESEARCH_OUT_DIR": str(self.dir)}
        for doc, argv in cmds:
            argv = [os.path.expandvars(a.replace("$SB_RESEARCH_OUT_DIR", str(self.dir))) for a in argv]
            argv = [str(SCRIPTS / Path(a).name) if a.startswith("skills/silver-deep-research/scripts/") else a for a in argv]
            if tuple(argv) in seen:
                continue
            seen.add(tuple(argv))
            proc = subprocess.run([sys.executable, *argv[1:]], cwd=self.dir, env=env, capture_output=True,
                                  text=True, timeout=60)
            for bad in self.BAD:
                self.assertNotIn(bad, proc.stderr, f"{doc}: {' '.join(argv)}\n{proc.stderr}")

    def _skill_md_gate_command(self):
        for doc, argv in self.commands():
            if doc == "SKILL.md" and argv[1].endswith("verify_claim_support.py"):
                return argv
        self.fail("SKILL.md documents no verify_claim_support.py command")

    def test_skill_md_claim_gate_is_strict_and_runs(self):
        argv = self._skill_md_gate_command()
        self.assertIn("verify", argv)
        self.assertIn("--strict", argv)

        def run(d):
            a = [x.replace("$SB_RESEARCH_OUT_DIR", str(d)) for x in argv]
            a[1] = str(SCRIPTS / "verify_claim_support.py")
            return subprocess.run([sys.executable, *a[1:]], capture_output=True, text=True, timeout=60)

        sb = StrictGateEndToEndTests("test_supported_report_passes_strict")
        sb.dir = self.dir / "good"
        sb.dir.mkdir()
        sb.cli = self.cli
        good = sb.build("Acme Corp revenue grew 40% in 2024 according to its annual filing [1].",
                        "Acme Corp revenue grew 40% in 2024, its annual filing shows.")
        claims = jsonl(good / "claims.jsonl")
        (good / "claims.jsonl").write_text(json.dumps([c for c in claims if "Acme" in c["text"]][0]) + "\n")
        self.assertEqual(run(good).returncode, 0)
        sb.dir = self.dir / "bad"
        sb.dir.mkdir()
        bad = sb.build("The vendor guarantees zero downtime for all customers and has never had a breach.",
                       "the weather was cold and windy yesterday")
        self.assertEqual(run(bad).returncode, 1)


class ReviewVariantTests(Run):
    """Variants of R11-02 found in review: acronym/camelCase entities, hedged figures, negation."""

    build = StrictGateEndToEndTests.build

    def status(self, claim, quote):
        return vcs.compute_support_score(claim, [quote])[0]

    def test_acronym_and_camelcase_entities_must_appear_in_the_quote(self):
        for claim, quote in (
            ("AWS acquired GitHub in 2018 for 7.5 billion dollars", "Microsoft acquired GitHub in 2018 for 7.5 billion dollars"),
            ("IBM acquired the company in 2019 for 34 billion", "Oracle acquired the company in 2019 for 34 billion"),
            ("GitLab acquired the startup in 2021", "GitHub acquired the startup in 2021"),
        ):
            self.assertNotEqual(self.status(claim, quote), "supported", claim)

    def test_honest_acronym_claims_still_pass(self):
        self.assertEqual(self.status("Microsoft acquired GitHub in 2018 for 7.5 billion dollars",
                                     "Microsoft acquired GitHub in 2018 for 7.5 billion dollars"), "supported")
        self.assertEqual(self.status("AWS launched OpenAI integrations in 2023", "AWS launched OpenAI integrations in 2023"),
                         "supported")
        self.assertEqual(vcs.extract_entities("AWS and iPhone and OpenAI"), {"AWS", "iPhone", "OpenAI"})

    def test_negation_mismatch_is_not_support(self):
        quote = "The vendor guarantees zero downtime for all enterprise customers"
        self.assertNotEqual(self.status("The vendor does not guarantee zero downtime for enterprise customers", quote), "supported")
        negated_quote = "The vendor does not guarantee zero downtime for enterprise customers"
        self.assertNotEqual(self.status("The vendor guarantees zero downtime for enterprise customers", negated_quote), "supported")
        status, _, notes = vcs.compute_support_score(
            "The vendor does not guarantee zero downtime for enterprise customers", [quote])
        self.assertEqual(status, "contradicted")
        self.assertIn("polarity: the source says", notes)

    def test_matching_negation_and_unrelated_negation_do_not_fail_honest_claims(self):
        both = "The vendor does not guarantee zero downtime for enterprise customers"
        self.assertEqual(self.status(both, both), "supported")
        claim = "Acme supports single sign-on for enterprise customers"
        quote = "Acme supports single sign-on for enterprise customers, but not SCIM provisioning"
        self.assertEqual(self.status(claim, quote), "supported")
        self.assertFalse(vcs._negation_conflict("zzzz qqqq", "unrelated words only"))

    def test_hedged_or_recommending_sentence_with_a_figure_is_factual(self):
        for text in ("Acme raised 50 million dollars in 2023 and should be shortlisted.",
                     "Revenue might reach 40% growth in 2024.",
                     "We recommend Acme, which raised $50 million."):
            self.assertEqual(extract_claims.classify_claim(text, "findings"), "factual", text)
        self.assertEqual(extract_claims.classify_claim("Acme raised 50 million dollars in 2023 [1].", "synthesis"), "factual")
        self.assertEqual(extract_claims.classify_claim("Overall, Acme grew 40% in 2024.", "synthesis"), "synthesis")

    def test_honest_recommendations_without_figures_stay_exempt(self):
        for text, kind in (("You should shortlist three vendors.", "recommendation"),
                           ("We recommend Acme for small teams.", "recommendation"),
                           ("Adoption might slow down.", "speculation")):
            self.assertEqual(extract_claims.classify_claim(text, "findings"), kind, text)

    def test_strict_gate_catches_a_wrong_company_end_to_end(self):
        d = self.build("AWS acquired GitHub in 2018 for 7.5 billion dollars [1].",
                       "Microsoft acquired GitHub in 2018 for 7.5 billion dollars")
        code, out, _ = self.cli(vcs, "verify", "--dir", str(d), "--strict")
        self.assertEqual(code, 1, out)


class ClaimCorpusTests(Run):
    """R11-02: a curated corpus of fabrications and honest claims, judged by the real strict gate."""

    CORPUS = json.loads((SKILL / "tests" / "fixtures" / "claim_corpus.json").read_text(encoding="utf-8"))

    def test_corpus_is_large_enough(self):
        self.assertGreaterEqual(len(self.CORPUS["fabrications"]), 40)
        self.assertGreaterEqual(len(self.CORPUS["honest"]), 40)

    def test_scorer_never_supports_a_fabrication_and_never_contradicts_an_honest_claim(self):
        bad = [p for p in self.CORPUS["fabrications"] if vcs.compute_support_score(p[0], [p[1]])[0] == "supported"]
        self.assertEqual(bad, [], "fabrications scored as supported")
        wrong = [p for p in self.CORPUS["honest"] if vcs.compute_support_score(p[0], [p[1]])[0] in ("contradicted", "unsupported")]
        self.assertEqual(wrong, [], "honest claims contradicted or unsupported")
        # The curated honest claims are plain enough to be supported outright.
        missed = [p for p in self.CORPUS["honest"] if vcs.compute_support_score(p[0], [p[1]])[0] != "supported"]
        self.assertEqual(missed, [], "honest claims not supported")

    def _strict(self, claim, quote, n):
        d = self.dir / f"run{n}"
        d.mkdir()
        self.cli(citation_manager, "init-run", "--out-dir", str(d))
        sid = json.loads(self.cli(citation_manager, "register-source", "--dir", str(d), "--json", "-",
                                  stdin=json.dumps({"raw_url": "https://src.example/p", "title": "Src"}))[1])["source_id"]
        self.cli(evidence_store, "add", "--dir", str(d), "--json", "-", stdin=json.dumps({"source_id": sid, "quote": quote}))
        (d / "research_report.md").write_text(
            f"# Report\n\n## Finding\n\n{claim.rstrip('.')} [1].\n\n## Bibliography\n\n[1] Src. https://src.example/p\n",
            encoding="utf-8")
        self.cli(extract_claims, "extract", "--report", str(d / "research_report.md"), "--dir", str(d))
        code, out, _ = self.cli(vcs, "verify", "--dir", str(d), "--strict")
        summary = json.loads(out)
        if code == 1:
            return "fail", summary
        return ("review" if summary["review_required"] else "pass"), summary

    def test_strict_gate_end_to_end_on_the_whole_corpus(self):
        """A fabrication must fail strict or be listed for review; an honest claim is never contradicted
        or unsupported, so strict exits 0 for it."""
        n = 0
        for claim, quote in self.CORPUS["fabrications"]:
            n += 1
            outcome, _ = self._strict(claim, quote, n)
            self.assertIn(outcome, ("fail", "review"), f"fabrication passed strict unflagged: {claim!r} / {quote!r}")
        for claim, quote in self.CORPUS["honest"]:
            n += 1
            outcome, summary = self._strict(claim, quote, n)
            self.assertEqual(outcome, "pass", f"honest claim not cleanly passed: {claim!r} / {quote!r}")
            self.assertEqual(summary["factual_needs_review"], 0)

    def test_figure_normalisation(self):
        fig = lambda t: [(f[0], f[1]) for f in vcs.extract_figures(t)]  # noqa: E731
        self.assertEqual(fig("$50M"), fig("50 million dollars"))
        self.assertEqual(fig("$7.5B"), [(7.5e9, "num")])
        self.assertEqual(fig("10k users"), [(10000.0, "num")])
        self.assertEqual(fig("2,500 customers"), [(2500.0, "num")])
        self.assertEqual(fig("grew 40% in 2024"), [(40.0, "%"), (2024.0, "year")])
        self.assertEqual(fig("3x faster"), [(3.0, "x")])
        self.assertEqual(fig("EC2, S3, GPT4, Q3 and FY2018"), [])
        self.assertEqual(vcs.extract_entities("runs on EC2 and GPT4 in FY2018"), {"EC2", "GPT4", "FY2018"})

    def test_negation_helpers(self):
        self.assertTrue(vcs._is_negated("it is not available"))
        # Polarity is boolean per clause: two cues are still one negation.
        self.assertTrue(vcs._is_negated("neither Acme nor Initech supports SSO"))
        self.assertTrue(vcs._is_negated("No, Acme does not support SSO"))
        self.assertTrue(vcs._is_negated("Acme does not support SSO, not even on enterprise plans"))
        self.assertTrue(vcs._is_negated("Acme doesn\u2019t support SSO"))
        self.assertFalse(vcs._is_negated("works offline without an account"))
        self.assertFalse(vcs._is_negated("supports not only SSO but also SCIM"))
        self.assertTrue(vcs._is_negated("the service is unavailable"))
        self.assertEqual(vcs._stem("disclosed"), vcs._stem("disclose"))


class ShortFactualSentenceTests(Run):
    def test_short_sentences_with_a_figure_are_claims_but_short_labels_are_not(self):
        text = "Acme raised $50M in 2023. See Figure 3. Overall good. Acme has 500 users here."
        found = extract_claims.extract_sentences(text)
        self.assertIn("Acme raised $50M in 2023.", found)
        self.assertNotIn("Overall good.", found)
        self.assertNotIn("See Figure 3.", found)


class VerbatimAndHeldOutCorpusTests(Run):
    """The reviewers' probes verbatim (r1-r3), and a held-out set in other styles."""

    FIX = SKILL / "tests" / "fixtures"
    VERBATIM = json.loads((FIX / "claim_corpus_verbatim.json").read_text(encoding="utf-8"))
    HELD = json.loads((FIX / "claim_corpus_heldout.json").read_text(encoding="utf-8"))

    def test_verbatim_probes_strict_fails_every_fabrication_and_passes_every_honest_claim(self):
        self.assertGreaterEqual(len(self.VERBATIM), 100)
        bad = [(c["claim"], c["quote"]) for c in self.VERBATIM
               if vcs.compute_support_score(c["claim"], [c["quote"]])[0] ==
               ("supported" if c["kind"] == "F" else "contradicted")]
        self.assertEqual(bad, [])
        bad = [(c["claim"], c["quote"]) for c in self.VERBATIM
               if c["kind"] == "H" and vcs.compute_support_score(c["claim"], [c["quote"]])[0] == "unsupported"]
        self.assertEqual(bad, [])

    def test_verbatim_probes_end_to_end_through_strict(self):
        helper = ClaimCorpusTests("test_corpus_is_large_enough")
        helper.dir = self.dir
        helper.cli = self.cli
        for n, c in enumerate(self.VERBATIM):
            outcome, summary = helper._strict(c["claim"], c["quote"], f"v{n}")
            if c["kind"] == "F":
                self.assertIn(outcome, ("fail", "review"), f"{c['source']}: {c['claim']!r} / {c['quote']!r}")
            else:
                self.assertIn(outcome, ("pass", "review"), f"{c['source']}: {c['claim']!r} / {c['quote']!r}")
                self.assertEqual((summary["factual_contradicted"], summary["factual_unsupported"]), (0, 0))

    R4 = json.loads((FIX / "claim_corpus_r4.json").read_text(encoding="utf-8"))

    def verdicts(self, items):
        return [(kind, vcs.compute_support_score(claim, [quote])[0]) for kind, claim, quote in items]

    def test_held_out_and_r4_probes_by_verdict_class(self):
        """Held-out (written after the scorer was frozen) and the fourth review's probes: a fabrication is
        contradicted or needs review (or is unsupported), never supported; an honest claim is supported or
        needs review, never contradicted. Counts per class are pinned so a regression shows."""
        held = ([("F", a, b) for a, b in self.HELD["fabrications"]] + [("H", a, b) for a, b in self.HELD["honest"]])
        r4 = [(c["kind"], c["claim"], c["quote"]) for c in self.R4]
        self.assertGreaterEqual(len(self.HELD["fabrications"]), 30)
        self.assertGreaterEqual(len(self.HELD["honest"]), 30)
        self.assertGreaterEqual(len(self.R4), 100)
        for name, items, honest_supported_at_least in (("held-out", held, 32), ("r4", r4, 60)):
            counts = {}
            for kind, status in self.verdicts(items):
                counts[(kind, status)] = counts.get((kind, status), 0) + 1
            self.assertEqual(counts.get(("F", "supported"), 0), 0, name)
            self.assertEqual(counts.get(("H", "contradicted"), 0) + counts.get(("H", "unsupported"), 0), 0, name)
            self.assertGreaterEqual(counts.get(("H", "supported"), 0), honest_supported_at_least, (name, counts))

    def test_r4_probes_end_to_end_through_strict(self):
        helper = ClaimCorpusTests("test_corpus_is_large_enough")
        helper.dir = self.dir
        helper.cli = self.cli
        for n, c in enumerate(self.R4):
            outcome, summary = helper._strict(c["claim"], c["quote"], f"r{n}")
            if c["kind"] == "F":
                self.assertIn(outcome, ("fail", "review"), f"{c['source']}: {c['claim']!r} / {c['quote']!r}")
            else:
                self.assertIn(outcome, ("pass", "review"), f"{c['source']}: {c['claim']!r} / {c['quote']!r}")


class ScorerRootCauseTests(Run):
    def status(self, claim, quote):
        return vcs.compute_support_score(claim, [quote])[0]

    def test_scope_aware_polarity(self):
        for quote in ("Neither Acme nor Initech supports SSO", "No, Acme does not support SSO",
                      "Acme does not support SSO, not even on enterprise plans",
                      "Acme doesn\u2019t support SSO", "Acme isn\u2019t able to support SSO"):
            self.assertNotEqual(self.status("Acme supports SSO", quote), "supported", quote)
        self.assertNotEqual(self.status("Acme supports SCIM", "Acme does not support SSO and SCIM"), "supported")
        self.assertNotEqual(self.status("Acme encrypts backups", "Acme never encrypts logs and backups"), "supported")

    def test_honest_polarity_variants(self):
        pairs = [
            ("Acme doesn't support SSO", "Acme doesn\u2019t support SSO"),
            ("Acme has no SSO and no audit logs", "Acme offers neither SSO nor audit logs"),
            ("Acme works offline without an account", "Acme works offline and without an account"),
            ("The company opened 40 stores in 2021", "The company opened 40 stores in 2021 and closed none"),
            ("The free plan does not include audit logs and is limited to 3 users",
             "The free plan is limited to 3 users and does not include audit logs"),
        ]
        for claim, quote in pairs:
            self.assertEqual(self.status(claim, quote), "supported", (claim, quote))

    def test_how_far_a_negation_reaches_is_ambiguous_not_supported(self):
        """"and"/"or" after a negated part may or may not stay inside the negation: never supported."""
        for claim, quote in (("Acme does not support SSO and SCIM", "Acme does not support SSO or SCIM"),
                             ("Acme supports SCIM", "Acme does not support SSO and SCIM"),
                             ("Acme does not support SSO and supports SCIM", "Acme does not support SSO or SCIM")):
            status, _, notes = vcs.compute_support_score(claim, [quote])
            self.assertEqual(status, "needs_review", (claim, quote, notes))
            self.assertIn("polarity ambiguous", notes)
        # Not even: a negation when it opens the clause (r4).
        status, _, notes = vcs.compute_support_score("Acme supports SSO for enterprise customers",
                                                     ["Not even Acme supports SSO for enterprise customers"])
        self.assertEqual(status, "contradicted", notes)

    def test_currency_is_part_of_the_figure(self):
        self.assertNotEqual(self.status("Acme raised $50M in 2023", "Acme raised \u20ac50M in 2023"), "supported")
        self.assertNotEqual(self.status("Acme raised 50 million dollars in 2023", "Acme raised 50 million euros in 2023"), "supported")
        self.assertEqual(self.status("Acme raised $50 million in 2023", "Acme raised USD 50 million in 2023"), "supported")

    def test_years_are_bound_to_the_event(self):
        self.assertNotEqual(self.status("Acme was founded in 2015 and acquired in 2019",
                                        "Acme was founded in 2019 and acquired in 2015"), "supported")
        self.assertEqual(self.status("Acme grew revenue 40% in 2024", "In 2024 Acme grew revenue 40% year over year"), "supported")

    def test_figures_bind_to_their_noun_even_when_reordered(self):
        self.assertNotEqual(self.status("Acme has 500 enterprise customers", "Acme has 500 staff serving enterprise customers"), "supported")
        for claim, quote in (("Acme cut prices by 20% in March 2024", "In March 2024 Acme cut its prices by 20%"),
                             ("The treatment reduced mortality by 35% compared with placebo",
                              "Compared with placebo, the treatment reduced mortality by 35%"),
                             ("Acme charges $20 per seat", "Seats cost $20 each at Acme")):
            self.assertEqual(self.status(claim, quote), "supported", claim)

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
        self.assertEqual(n("doesn\u2019t \u2013 ok"), "doesn't - ok")
        self.assertEqual(n("at no extra cost"), "for free")
        self.assertEqual(n("a hundred"), "a hundred")  # a bare multiplier is left alone
        self.assertEqual(n("one million"), "1000000")
        self.assertEqual(n("two thousand five hundred"), "2500")

    def test_antonyms_stems_and_entities(self):
        self.assertNotEqual(self.status("Acme raised 50 million in 2023", "Acme lost 50 million in 2023"), "supported")
        self.assertNotEqual(self.status("Acme opened three offices in 2020", "Acme closed three offices in 2020"), "supported")
        self.assertEqual(vcs._stem("shipped"), vcs._stem("ships"))
        self.assertEqual(vcs._stem("companies"), "company")
        self.assertEqual(vcs._stem("boxes"), "box")
        self.assertEqual(vcs._stem("employees"), vcs._stem("employee"))
        self.assertEqual(vcs.extract_entities("Quarterly revenue grew. Recently, Acme won."), {"Acme"})
        self.assertEqual(self.status("Webhooks are signed with HMAC-SHA256", "Every webhook request is signed with HMAC-SHA256"), "supported")
        self.assertEqual(self.status("Acme supports Python but not Ruby", "Acme supports Python. It does not support Ruby."), "supported")
        self.assertNotEqual(self.status("Acme supports Kubernetes and Nomad", "Acme supports Kubernetes. Nomad support is not available."), "supported")
        self.assertEqual(vcs._variants("Acme supports Slack, Jira or Teams")[1:],
                         ["Acme supports Slack", "Acme supports Jira", "Acme supports Teams"])
        self.assertEqual(vcs._variants("Acme supports SSO"), ["Acme supports SSO"])
        self.assertIsNone(vcs._subject("the cat sat"))
        self.assertFalse(vcs._aligned("", "anything", None))
        self.assertFalse(vcs._antonym_conflict("Acme supports SSO", "Acme supports SSO"))

    def test_without_and_zero_quantifiers(self):
        self.assertNotEqual(self.status("Acme includes audit logging in the base plan",
                                        "Acme includes audit logging only without the base plan"), "supported")
        self.assertNotEqual(self.status("Acme reported security incidents in 2023",
                                        "Acme reported zero security incidents in 2023"), "supported")
        self.assertEqual(self.status("Acme offers zero-trust network access", "Acme offers zero-trust network access for remote teams"), "supported")
        # The same names in another order are never decided by words (a role swap): a reader checks it.
        self.assertEqual(self.status("Acme includes SSO at no extra cost on every plan", "SSO is included on every Acme plan for free"), "needs_review")
        self.assertEqual(self.status("Acme includes SSO at no extra cost on every plan", "Acme includes SSO on every plan for free"), "supported")

    def test_no_longer_is_not_compared_with_a_paraphrase(self):
        self.assertEqual(self.status("Acme no longer offers a free tier since 2024",
                                     "Since 2024, Acme has offered only paid plans after retiring its free tier"), "supported")
        self.assertNotEqual(self.status("Acme offers a free tier", "Acme no longer offers a free tier"), "supported")


class ShortClaimSignalTests(Run):
    def kept(self, text):
        return extract_claims.extract_sentences(text)

    def test_factual_signals_make_short_sentences_claims(self):
        for sentence in ("Acme is HIPAA compliant.", "Acme never had a breach.", "Microsoft owns Acme outright.",
                         "Acme raised $50M in 2023.", "Acme leads on price.", "Acme is the fastest option."):
            self.assertEqual(self.kept(sentence), [sentence], sentence)

    def test_navigation_numbers_and_labels_are_not_claims(self):
        text = ("Results are in Table 2. See Figure 3 below. We compared 4 vendors.\n\n1. Overall good. "
                "Section 4 has details here.")
        self.assertEqual(self.kept(text), [])
        self.assertEqual(self.kept("Two words."), [])
        self.assertEqual(self.kept("Table 2 shows Acme grew 40% in 2024."), ["Table 2 shows Acme grew 40% in 2024."])

    def test_short_evaluations_and_transitions_are_not_claims(self):
        for sentence in ("Pricing is simple.", "Support is responsive.", "Documentation is thin.", "Setup took minutes.",
                         "Next, we compare costs.", "Below we list options.", "Finally, let us summarise."):
            self.assertEqual(self.kept(sentence), [], sentence)
        # A statement about a named thing, or a verb with an object, is a claim even when short.
        for sentence in ("Setup takes 7 days.", "Acme runs 3 regions.", "Acme offers a free tier.", "Acme is profitable.", "Finally, Acme leads on price.",
                         "GitHub is fully hosted.", "Acme Cloud is HIPAA ready."):
            self.assertEqual(self.kept(sentence), [sentence], sentence)

    def test_list_markers_do_not_stick_to_sentences(self):
        self.assertEqual(self.kept("Acme leads on price.\n\n2. Beta is the cheapest."), ["Acme leads on price.", "Beta is the cheapest."])

    def test_names_inside_a_sentence_count(self):
        self.assertEqual(self.kept("We chose Acme for it."), ["We chose Acme for it."])
        self.assertEqual(self.kept("We did it ok."), [])
        self.assertEqual(self.kept("1 2 3 4"), [])


class ThreeValuedVerdictTests(Run):
    """Conservative + escalate: supported only when unambiguous, contradicted on clear opposite
    evidence, otherwise needs_review with the figure, entity or polarity that was ambiguous."""

    def score(self, claim, *quotes):
        return vcs.compute_support_score(claim, list(quotes))

    def test_contradicted_on_clear_opposite_evidence(self):
        for claim, quote in (("Acme raised 50 million in 2023", "Acme lost 50 million in 2023"),
                             ("The vendor guarantees zero downtime", "The vendor does not guarantee zero downtime"),
                             ("Acme reported security incidents in 2023", "Acme reported zero security incidents in 2023"),
                             ("The central bank raised rates by 25 basis points", "The central bank cut rates by 25 basis points")):
            status, _, notes = self.score(claim, quote)
            self.assertEqual(status, "contradicted", (claim, quote, notes))

    def test_needs_review_names_what_was_ambiguous(self):
        status, _, notes = self.score("AWS acquired GitHub in 2018 for 7.5 billion dollars",
                                      "Microsoft acquired GitHub in 2018 for 7.5 billion dollars")
        self.assertEqual((status, notes), ("needs_review", "entity not found in the source: AWS"))
        status, _, notes = self.score("Setup takes 7 days", "Setup takes between two and five days")
        self.assertEqual((status, notes), ("needs_review", "figure not matched in the source: 7 day"))
        status, _, notes = self.score("Acme supports SCIM", "Acme does not support SSO and SCIM")
        self.assertEqual(status, "needs_review")
        self.assertIn("polarity ambiguous", notes)

    def test_nothing_in_common_is_unsupported(self):
        self.assertEqual(self.score("Acme raised 50 million in 2023", "Bananas are rich in potassium")[0], "unsupported")

    def test_one_supporting_quote_and_one_contradicting_quote_need_review(self):
        status, _, notes = self.score("Acme supports SSO", "Acme supports SSO on every plan", "Acme does not support SSO")
        self.assertEqual(status, "needs_review")
        self.assertIn("conflicting evidence", notes)
        # A supporting quote with an unrelated one is still supported.
        self.assertEqual(self.score("Acme supports SSO", "Acme supports SSO on every plan", "Bananas")[0], "supported")
        # Two contradicting quotes report the closer one.
        self.assertEqual(self.score("Acme supports SSO", "Acme does not support SSO", "Acme lacks SSO entirely")[0], "contradicted")

    def test_ranges_are_ranges(self):
        n = vcs.normalize_text
        self.assertEqual(n("between two and five days"), "between 2 and 5 days")
        self.assertEqual(n("four and five regions"), "4 and 5 regions")
        self.assertEqual(n("twenty and thirty"), "20 and 30")
        self.assertEqual(n("two hundred and fifty"), "250")
        self.assertEqual(n("one thousand and one"), "1001")
        self.assertEqual(n("between one and five days"), "between 1 and 5 days")
        self.assertEqual(n("one or two"), "1 or 2")  # a lone "one" starts a range when "to"/"or" and a number follow
        self.assertEqual(n("one to three days"), "1 to 3 days")
        for claim, quote in (("Setup takes between 2 and 5 days", "Setup takes between two and five days"),
                             ("Acme has 5 to 7 offices", "Acme has five to seven offices"),
                             ("Acme ships every 3 or 4 weeks", "Acme ships every three or four weeks")):
            self.assertEqual(self.score(claim, quote)[0], "supported", claim)
        for claim, quote in (("Setup takes 7 days", "Setup takes between two and five days"),
                             ("Acme runs in 9 regions", "Acme runs in four and five regions in the US and EU"),
                             ("Acme has 5 offices", "Acme has between five and seven offices"),
                             ("Acme has 12 offices", "Acme has between five and seven offices"),
                             ("Acme has between 5 and 8 offices", "Acme has between five and seven offices")):
            self.assertNotEqual(self.score(claim, quote)[0], "supported", claim)
        fig = lambda t: [(f.value, f.rng) for f in vcs.extract_figures(t)]  # noqa: E731
        self.assertEqual(fig("2023-2024 and 2024-03-05"), [(2023.0, "lo"), (2024.0, "hi"), (2024.0, None), (3.0, None), (5.0, None)])

    def test_every_currency_is_its_own_currency(self):
        for quote in ("Acme raised ¥5 billion in 2023", "Acme raised 5 billion yen in 2023", "Acme raised JPY 5 billion in 2023",
                      "Acme raised RMB 5 billion in 2023", "Acme raised 5 billion yuan in 2023", "Acme raised ₹5 billion in 2023",
                      "Acme raised A$5 billion in 2023", "Acme raised C$5 billion in 2023", "Acme raised CHF 5 billion in 2023",
                      "Acme raised 5 billion francs in 2023", "Acme raised 5 billion in 2023"):
            self.assertNotEqual(self.score("Acme raised $5 billion in 2023", quote)[0], "supported", quote)
        self.assertNotEqual(self.score("Acme raised A$50M in 2023", "Acme raised C$50M in 2023")[0], "supported")
        self.assertNotEqual(self.score("Acme raised ₹500 million in 2023", "Acme raised $500 million in 2023")[0], "supported")
        for claim, quote in (("Acme raised $50M in 2023", "Acme raised US$50M in 2023"),
                             ("Acme raised A$50M in 2023", "Acme raised 50 million Australian dollars as A$50M in 2023"),
                             ("Acme raised ¥5 billion in 2023", "Acme raised 5 billion yen in 2023"),
                             ("Acme raised ¥5 billion in 2023", "Acme raised 5 billion yuan in 2023"),
                             ("Acme raised 5 billion yen in 2023", "Acme raised ¥5 billion in 2023"),
                             ("Acme raised 5 billion rupees in 2023", "Acme raised ₹5 billion in 2023")):
            self.assertEqual(self.score(claim, quote)[0], "supported", (claim, quote))
        self.assertTrue(vcs._currency_conflict("USD", "AUD"))
        self.assertFalse(vcs._currency_conflict("YEN-OR-YUAN", "CNY"))
        self.assertFalse(vcs._currency_conflict(None, "AUD"))

    def test_years_are_bound_to_their_event_wherever_they_stand(self):
        for claim, quote in (
                ("In 2019, Acme was founded by two former Initech engineers",
                 "Acme was founded by two former Initech engineers in 2015 and acquired by Globex in 2019"),
                ("By 2019, Acme had 300 employees", "Acme had 300 employees by 2021 and 100 employees in 2019"),
                ("Since 2015, Acme has been public", "Acme was founded in 2015 and has been public since 2019"),
                ("In 2015, Initech acquired Acme", "Acme was founded in 2015 and Initech acquired it in 2019")):
            self.assertNotEqual(self.score(claim, quote)[0], "supported", claim)
        for claim, quote in (("In 2015, Acme was founded", "Acme was founded in 2015 and acquired in 2019"),
                             ("In 2023 Acme raised $50M", "Acme raised $50M in 2023"),
                             ("Acme grew revenue 40% in 2024", "In 2024 Acme grew revenue 40% year over year")):
            self.assertEqual(self.score(claim, quote)[0], "supported", claim)
        self.assertEqual([(f.value, f.seg) for f in vcs.extract_figures("In 2019, Acme was founded")], [(2019.0, 0)])
        self.assertEqual([f.value for f in vcs.extract_figures("In 2019,")], [2019.0])

    def test_figures_bind_to_the_metric_not_to_the_verb_of_change(self):
        for claim, quote in (("Acme revenue grew 30%", "Acme revenue grew 10% and Acme margins grew 30%"),
                             ("In 2023, Acme revenue grew 30%", "In 2023 Acme revenue grew 10% and Acme margins grew 30%"),
                             ("Acme cut latency by 30%", "Acme cut cost by 30% and latency by 10%")):
            self.assertNotEqual(self.score(claim, quote)[0], "supported", claim)
        for claim, quote in (("Acme revenue grew 30%", "Revenue at Acme grew 30%"),
                             ("Acme's net loss narrowed to $30M in 2023", "In 2023 Acme narrowed its net loss to $30M")):
            self.assertEqual(self.score(claim, quote)[0], "supported", claim)

    def test_negation_is_scoped_to_the_part_it_belongs_to(self):
        for claim, quote in (("Okta supports SCIM provisioning", "Okta supports SCIM provisioning and OneLogin does not"),
                             ("Acme supports SAML single sign-on", "Acme supports SAML single sign-on and lacks SCIM provisioning"),
                             ("Acme Cloud runs on AWS", "Acme Cloud runs on AWS and requires no agents"),
                             ("Acme encrypts data at rest", "Acme encrypts data at rest and never stores keys in plaintext"),
                             ("Acme supports SSO", "Acme supports SSO with no extra configuration"),
                             ("Acme offers a free tier", "Acme offers a free tier with no time limit"),
                             ("Acme supports SAML", "Acme supports SAML, but LDAP is not supported"),
                             ("Acme integrates with Jira", "Acme integrates with Jira, and no plugin is required"),
                             ("Acme lacks SCIM provisioning", "Acme supports SSO and lacks SCIM provisioning"),
                             ("Acme supports Slack and Teams", "Acme supports Slack, not to mention Teams")):
            self.assertEqual(self.score(claim, quote)[0], "supported", (claim, quote))
        for claim, quote, verdict in (
                ("OneLogin supports SCIM provisioning", "Okta supports SCIM provisioning and OneLogin does not", "needs_review"),
                ("Acme supports SCIM provisioning", "Acme supports SSO and does not support SCIM provisioning", "contradicted"),
                ("Acme supports OIDC", "Acme supports SAML, not OIDC", "needs_review"),
                ("Acme supports SSO", "Not even Acme supports SSO", "contradicted"),
                ("Acme supports SSO on free plans", "Acme does not support SSO on free plans", "contradicted"),
                ("Acme does not support SSO", "Acme supports SSO and OneLogin does not", "needs_review"),
                ("Acme has never raised outside funding and remains profitable",
                 "Acme has never raised outside funding. It remains profitable.", "needs_review")):
            self.assertEqual(self.score(claim, quote)[0], verdict, (claim, quote))
        status, _, notes = self.score("Acme supports SAML for enterprise single sign-on",
                                      "Acme supports SAML, not OIDC, for enterprise single sign-on")
        self.assertEqual(status, "needs_review", notes)

    def test_roles_and_voice_are_never_decided_by_words_alone(self):
        for claim, quote in (("Samsung overtook Apple as the largest smartphone maker in 2023",
                              "Apple overtook Samsung as the largest smartphone maker in 2023"),
                             ("Acme acquired Initech", "Acme was acquired by Initech")):
            status, _, notes = self.score(claim, quote)
            self.assertEqual(status, "needs_review", (claim, quote))
            self.assertIn("roles may be swapped", notes)
        # Dates are not roles; a re-ordered clause that is not a plain subject-verb-object is left alone.
        self.assertEqual(self.score("Acme cut prices by 20% in March 2024", "In March 2024 Acme cut its prices by 20%")[0], "supported")
        # Any other order of the claim's names is a possible swap, whatever stands between them.
        self.assertEqual(self.score("SSO is included on every Acme plan", "Acme includes SSO on every plan")[0], "needs_review")
        self.assertEqual(self.score("Acme includes SSO on every plan", "Acme includes SSO on every plan")[0], "supported")

    def test_a_negated_part_of_the_claim_is_flagged(self):
        status, _, notes = self.score("The protein is expressed in the liver and kidney",
                                      "The protein is expressed in the liver but not in the kidney")
        self.assertEqual(status, "needs_review")
        self.assertIn("negates part of the claim", notes)
        self.assertEqual(vcs._negated_fragment("Acme does not support SSO", "Acme does not support SSO"), False)
        # A negated claim part with nothing but the subject in it cannot be placed in the source.
        self.assertEqual(vcs._polarity("Acme, not", "Acme supports SSO", "Acme")[0], "ambiguous")
        self.assertEqual(vcs._polarity("Acme, SSO", "Acme supports SSO", "Acme")[0], "agree")

    def test_report_and_verify_list_the_claims_a_reader_must_check(self):
        d = self.dir / "rv"
        d.mkdir()
        self.cli(citation_manager, "init-run", "--out-dir", str(d))
        sid = json.loads(self.cli(citation_manager, "register-source", "--dir", str(d), "--json", "-",
                                  stdin=json.dumps({"raw_url": "https://src.example/p", "title": "Src"}))[1])["source_id"]
        self.cli(evidence_store, "add", "--dir", str(d), "--json", "-",
                 stdin=json.dumps({"source_id": sid, "quote": "Setup takes between two and five days"}))
        (d / "research_report.md").write_text(
            "# Report\n\n## Finding\n\nSetup of the Acme product takes 7 days [1].\n\n## Bibliography\n\n[1] Src. https://src.example/p\n",
            encoding="utf-8")
        self.cli(extract_claims, "extract", "--report", str(d / "research_report.md"), "--dir", str(d))
        code, out, err = self.cli(vcs, "verify", "--dir", str(d), "--strict")
        summary = json.loads(out)
        self.assertEqual((code, summary["status"], summary["review_required"]), (0, "pass", True))
        self.assertIn("figure not matched in the source: 7 day", summary["needs_review"][0]["reason"])
        self.assertIn("need review", err)
        _, report, _ = self.cli(vcs, "report", "--dir", str(d))
        self.assertIn("## Needs Review", report)
        self.assertIn("figure not matched in the source: 7 day", report)
        # Resolving it: quote the exact supporting span as evidence (here the claim's own words from the source).
        self.cli(evidence_store, "add", "--dir", str(d), "--json", "-",
                 stdin=json.dumps({"source_id": sid, "quote": "Setup of the Acme product takes 7 days"}))
        _, out, _ = self.cli(vcs, "verify", "--dir", str(d), "--strict")
        self.assertEqual(json.loads(out)["review_required"], False)
