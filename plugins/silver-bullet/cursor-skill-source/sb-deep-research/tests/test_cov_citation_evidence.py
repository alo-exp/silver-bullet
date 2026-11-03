"""Coverage tests for citation_manager and evidence_store (in-process CLI runs)."""

import json
import tempfile
import unittest
from pathlib import Path

import covhelp
from covhelp import SCRIPTS, call_main, run_script

import citation_manager as cm
import evidence_store as es


def setUpModule():
    covhelp.block_network()


def tearDownModule():
    covhelp.unblock_network()


class TestCitationManager(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.addCleanup(self._td.cleanup)
        self.d = self._td.name

    def reg(self, obj):
        return call_main(cm, ["register-source", "--dir", self.d, "--json", json.dumps(obj)])

    def test_read_jsonl_missing_and_blank_lines(self):
        self.assertEqual(cm.read_jsonl(str(Path(self.d) / "none.jsonl")), [])
        p = Path(self.d) / "r.jsonl"
        p.write_text('{"a": 1}\n\n   \n{"b": 2}\n')
        self.assertEqual(cm.read_jsonl(str(p)), [{"a": 1}, {"b": 2}])

    def test_canonicalize_strips_tracking_and_sorts_query(self):
        url = "HTTPS://Example.COM/path/?utm_source=x&b=2&a=1&fbclid=z#frag"
        out = cm.canonicalize_locator(url)
        self.assertIn("example.com/path", out)
        self.assertNotIn("utm_source", out)
        self.assertNotIn("fbclid", out)
        self.assertNotIn("#", out)
        self.assertTrue(out.endswith("a=1&b=2"))
        self.assertEqual(cm.compute_source_id("x"), cm.compute_source_id("x"))
        self.assertEqual(len(cm.compute_source_id("x")), 16)

    def test_init_run_creates_manifest_and_artifacts(self):
        out = Path(self.d) / "run"
        code, stdout, _ = call_main(cm, ["init-run", "--out-dir", str(out), "--query", "q?",
                                         "--mode", "deep"])
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(stdout)["status"], "ok")
        manifest = json.loads((out / "run_manifest.json").read_text())
        self.assertEqual(manifest["mode"], "deep")
        self.assertEqual(manifest["query"], "q?")
        for name in ("sources.jsonl", "evidence.jsonl", "claims.jsonl"):
            self.assertTrue((out / name).exists())
        self.assertFalse((out / "report.md").exists())

    def test_init_run_keeps_existing_artifact_content(self):
        out = Path(self.d)
        (out / "sources.jsonl").write_text('{"keep": true}\n')
        call_main(cm, ["init-run", "--out-dir", str(out)])
        self.assertEqual((out / "sources.jsonl").read_text(), '{"keep": true}\n')

    def test_register_source_requires_url(self):
        code, out, err = self.reg({"title": "t"})
        self.assertEqual(code, 1)
        self.assertIn("raw_url is required", err)
        self.assertEqual(out, "")

    def test_register_accepts_url_key_and_dedups(self):
        code, out, _ = self.reg({"url": "https://a.example/p?utm_source=1", "title": "A"})
        first = json.loads(out)
        self.assertEqual(first["status"], "registered")
        code, out, _ = self.reg({"raw_url": "https://a.example/p", "title": "A again"})
        second = json.loads(out)
        self.assertEqual(second["status"], "duplicate")
        self.assertEqual(second["source_id"], first["source_id"])
        rows = cm.read_jsonl(str(Path(self.d) / "sources.jsonl"))
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["source_type"], "web")
        self.assertEqual(rows[0]["metadata_status"], "unverified")

    def test_register_uses_explicit_canonical_locator(self):
        _, out, _ = self.reg({"raw_url": "https://a.example/p", "canonical_locator": "doi:10.1/x"})
        res = json.loads(out)
        self.assertEqual(res["canonical_locator"], "doi:10.1/x")
        self.assertEqual(res["source_id"], cm.compute_source_id("doi:10.1/x"))

    def test_assign_display_numbers_in_registration_order(self):
        self.reg({"raw_url": "https://a.example/1"})
        self.reg({"raw_url": "https://b.example/2"})
        # a duplicate row written directly must not shift numbering
        rows = cm.read_jsonl(str(Path(self.d) / "sources.jsonl"))
        cm.append_jsonl(str(Path(self.d) / "sources.jsonl"), rows[0])
        _, out, _ = call_main(cm, ["assign-display-numbers", "--dir", self.d])
        mapping = json.loads(out)
        self.assertEqual(sorted(mapping.values()), [1, 2])
        self.assertEqual(mapping[rows[0]["source_id"]], 1)
        self.assertEqual(mapping[rows[1]["source_id"]], 2)

    def _sources(self, rows):
        for r in rows:
            cm.append_jsonl(str(Path(self.d) / "sources.jsonl"), r)

    def test_bibliography_markdown_author_variants(self):
        base = {"canonical_locator": "c", "raw_url": "https://x/1"}
        self._sources([
            dict(base, source_id="s1", title="One", authors=["Ann"], year=2020),
            dict(base, source_id="s2", title="Two", authors=["Ann", "Bob"]),
            dict(base, source_id="s3", title="Three", authors=["Ann", "Bob", "Cy"], year=2021),
            dict(base, source_id="s4", title="Four"),
            dict(base, source_id="s1", title="One dup", authors=["Ann"], year=2020),
        ])
        code, out, _ = call_main(cm, ["export-bibliography", "--dir", self.d])
        self.assertEqual(code, 0)
        lines = out.strip().split("\n")
        self.assertEqual(lines[0], "## Bibliography")
        body = lines[2:]
        self.assertEqual(len(body), 4)
        self.assertEqual(body[0], "[1] Ann. (2020). [One](https://x/1)")
        self.assertEqual(body[1], "[2] Ann & Bob. (n.d.). [Two](https://x/1)")
        self.assertEqual(body[2], "[3] Ann et al. (2021). [Three](https://x/1)")
        self.assertEqual(body[3], "[4] (n.d.). [Four](https://x/1)")

    def test_bibliography_json_and_unknown_style(self):
        self._sources([{"source_id": "s1", "canonical_locator": "c", "title": "One",
                        "raw_url": "https://x/1", "year": 2020, "authors": ["Ann"]}])
        _, out, _ = call_main(cm, ["export-bibliography", "--dir", self.d, "--style", "json"])
        data = json.loads(out)
        self.assertEqual(data[0]["display_number"], 1)
        self.assertEqual(data[0]["source_id"], "s1")
        # argparse blocks unknown styles; call the function directly
        import argparse
        import contextlib
        import io
        err = io.StringIO()
        with contextlib.redirect_stderr(err), self.assertRaises(SystemExit) as ctx:
            cm.cmd_export_bibliography(argparse.Namespace(dir=self.d, style="bibtex"))
        self.assertEqual(ctx.exception.code, 1)
        self.assertIn("Unknown style: bibtex", err.getvalue())

    def test_run_as_script(self):
        code, out, _ = run_script(SCRIPTS / "citation_manager.py",
                                  ["assign-display-numbers", "--dir", self.d])
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(out), {})


class TestEvidenceStore(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.addCleanup(self._td.cleanup)
        self.d = self._td.name

    def add(self, obj):
        return call_main(es, ["add", "--dir", self.d, "--json", json.dumps(obj)])

    def test_read_jsonl_missing_and_blank_lines(self):
        self.assertEqual(es.read_jsonl(str(Path(self.d) / "none")), [])
        p = Path(self.d) / "r.jsonl"
        p.write_text('\n{"a": 1}\n  \n')
        self.assertEqual(es.read_jsonl(str(p)), [{"a": 1}])

    def test_init_creates_dir_and_file_once(self):
        sub = Path(self.d) / "new" / "dir"
        code, out, _ = call_main(es, ["init", "--dir", str(sub)])
        self.assertEqual(code, 0)
        path = sub / "evidence.jsonl"
        self.assertEqual(json.loads(out)["path"], str(path))
        self.assertTrue(path.exists())
        path.write_text("keep\n")
        call_main(es, ["init", "--dir", str(sub)])
        self.assertEqual(path.read_text(), "keep\n")

    def test_add_requires_source_and_quote(self):
        for payload in ({"quote": "q"}, {"source_id": "s"}, {}):
            code, out, err = self.add(payload)
            self.assertEqual(code, 1)
            self.assertIn("source_id and quote are required", err)
        self.assertFalse((Path(self.d) / "evidence.jsonl").exists())

    def test_add_row_and_duplicate(self):
        code, out, _ = self.add({"source_id": "s1", "quote": "Hello  World", "locator": "p1",
                                 "retrieval_query": "rq"})
        res = json.loads(out)
        self.assertEqual(res["status"], "added")
        # same quote after whitespace/case normalization is a duplicate
        _, out, _ = self.add({"source_id": "s1", "quote": "hello world", "locator": "p1"})
        dup = json.loads(out)
        self.assertEqual(dup["status"], "duplicate")
        self.assertEqual(dup["evidence_id"], res["evidence_id"])
        rows = es.read_jsonl(str(Path(self.d) / "evidence.jsonl"))
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["retrieval_query"], "rq")
        self.assertEqual(rows[0]["evidence_type"], "direct_quote")

    def test_add_invalid_evidence_type_falls_back_and_valid_kept(self):
        self.add({"source_id": "s1", "quote": "a", "evidence_type": "bogus"})
        self.add({"source_id": "s1", "quote": "b", "evidence_type": "data_point"})
        rows = es.read_jsonl(str(Path(self.d) / "evidence.jsonl"))
        self.assertEqual([r["evidence_type"] for r in rows], ["direct_quote", "data_point"])

    def test_list_filters_and_dedups(self):
        self.add({"source_id": "s1", "quote": "a"})
        self.add({"source_id": "s2", "quote": "b"})
        path = str(Path(self.d) / "evidence.jsonl")
        es.append_jsonl(path, es.read_jsonl(path)[0])  # raw duplicate row
        _, out, _ = call_main(es, ["list", "--dir", self.d])
        self.assertEqual(json.loads(out)["count"], 2)
        _, out, _ = call_main(es, ["list", "--dir", self.d, "--source-id", "s2"])
        res = json.loads(out)
        self.assertEqual(res["count"], 1)
        self.assertEqual(res["evidence"][0]["source_id"], "s2")

    def test_export_dedups(self):
        self.add({"source_id": "s1", "quote": "a"})
        path = str(Path(self.d) / "evidence.jsonl")
        es.append_jsonl(path, es.read_jsonl(path)[0])
        _, out, _ = call_main(es, ["export", "--dir", self.d])
        self.assertEqual(len(json.loads(out)), 1)

    def test_export_empty_run(self):
        _, out, _ = call_main(es, ["export", "--dir", self.d])
        self.assertEqual(json.loads(out), [])

    def test_run_as_script(self):
        code, out, _ = run_script(SCRIPTS / "evidence_store.py", ["list", "--dir", self.d])
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(out)["count"], 0)


if __name__ == "__main__":
    unittest.main()
