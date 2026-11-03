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
        self.assertIn("number mismatch", notes)

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
        self.assertIn("negation mismatch", vcs.compute_support_score(
            "The vendor does not guarantee zero downtime for enterprise customers", [quote])[2])

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

    def test_scorer_rejects_every_fabrication_and_accepts_every_honest_claim(self):
        bad = [p for p in self.CORPUS["fabrications"] if vcs.compute_support_score(p[0], [p[1]])[0] == "supported"]
        self.assertEqual(bad, [], "fabrications scored as supported")
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
        return self.cli(vcs, "verify", "--dir", str(d), "--strict")[0]

    def test_strict_gate_end_to_end_on_the_whole_corpus(self):
        n = 0
        for claim, quote in self.CORPUS["fabrications"]:
            n += 1
            self.assertEqual(self._strict(claim, quote, n), 1, f"fabrication passed strict: {claim!r} / {quote!r}")
        for claim, quote in self.CORPUS["honest"]:
            n += 1
            self.assertEqual(self._strict(claim, quote, n), 0, f"honest claim failed strict: {claim!r} / {quote!r}")

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
        self.assertFalse(vcs._is_negated("it does not guarantee zero downtime"))  # two cues: positive
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
