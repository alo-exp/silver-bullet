"""Unit tests for scripts/silver-scan.py: helpers, state, and source discovery."""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from sbtest import REPO_ROOT, load_module

s = load_module("scripts/silver-scan.py", name="silver_scan_core_under_test")

ENV_KEYS = (
    "SILVER_BULLET_RUNTIME", "SB_RUNTIME_NAME", "KAY_HOME", "CODEX_HOME", "CODE_HOME",
    "CODEX_SESSION_CATALOG_PATH", "CLAUDE_HOME", "SB_RUNTIME_HOME_ROOT",
)


class Base(unittest.TestCase):
    def setUp(self):
        env = {k: v for k, v in os.environ.items() if k not in ENV_KEYS}
        p = mock.patch.dict(os.environ, env, clear=True)
        p.start()
        self.addCleanup(p.stop)
        d = tempfile.TemporaryDirectory()
        self.addCleanup(d.cleanup)
        self.tmp = Path(d.name).resolve()
        self.home = self.tmp / "home"
        self.home.mkdir()
        h = mock.patch.object(Path, "home", return_value=self.home)
        h.start()
        self.addCleanup(h.stop)
        os.environ["HOME"] = str(self.home)
        self.root = self.tmp / "proj"
        self.root.mkdir()

    def write(self, rel, text="x", base=None):
        p = (base or self.tmp) / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text, encoding="utf-8")
        return p


class ClockTest(unittest.TestCase):
    def test_commands_run_python_and_strip_output(self):
        proc = subprocess.CompletedProcess([], 0, stdout=" 2030-01-01T00:00:00+00:00\n")
        with mock.patch.object(s.subprocess, "run", return_value=proc) as run:
            self.assertEqual(s.now_iso(), "2030-01-01T00:00:00+00:00")
            self.assertEqual(s.local_date(), "2030-01-01T00:00:00+00:00")
            self.assertEqual(s.local_month(), "2030-01-01T00:00:00+00:00")
        scripts = [c.args[0][2] for c in run.call_args_list]
        self.assertIn("isoformat(timespec='seconds')", scripts[0])
        self.assertIn("%Y-%m-%d", scripts[1])
        self.assertIn("%Y-%m'", scripts[2])
        for c in run.call_args_list:
            self.assertEqual(c.args[0][0], sys.executable)
            self.assertTrue(c.kwargs["check"] and c.kwargs["text"] and c.kwargs["capture_output"])

    def test_real_formats(self):
        import re
        self.assertRegex(s.now_iso(), r"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d[+-]\d\d:\d\d$")
        self.assertRegex(s.local_date(), r"^\d{4}-\d\d-\d\d$")
        self.assertRegex(s.local_month(), r"^\d{4}-\d\d$")
        self.assertTrue(re.fullmatch(r"\d{4}-\d\d", s.local_month()))


class TextHelpersTest(Base):
    def test_sha256(self):
        self.assertEqual(s.sha256_text("abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")

    def test_normalize_text_shared_and_fallback(self):
        self.assertEqual(s.normalize_text("  `Code` — Thing:; "), "code - thing")
        with mock.patch.dict(sys.modules, {"evidence_common": None}):
            self.assertEqual(s.normalize_text("  `Code` — Thing:; "), "code - thing")
            self.assertEqual(s.normalize_text("A\n\tB"), "a b")

    def test_helpers_add_lib_to_sys_path_only_when_missing(self):
        lib = str(REPO_ROOT / "scripts" / "lib")
        calls = {"normalize_text": ("x",), "scan_item_fingerprint": ("t", "c")}
        for name, args in calls.items():
            for present in (False, True):
                path = [p for p in sys.path if p != lib] + ([lib] if present else [])
                with mock.patch.object(sys, "path", path):
                    getattr(s, name)(*args)
                    self.assertEqual(path.count(lib), 1, (name, present))
                    if not present:
                        self.assertEqual(path[0], lib)

    def test_scan_item_fingerprint_shared_and_fallback(self):
        shared = s.scan_item_fingerprint("Title", "Context")
        self.assertRegex(shared, r"^[0-9a-f]{64}$")
        self.assertEqual(shared, s.scan_item_fingerprint("Title", "Context"))
        self.assertNotEqual(shared, s.scan_item_fingerprint("Title2", "Context"))
        with mock.patch.dict(sys.modules, {"evidence_common": None}):
            self.assertEqual(s.scan_item_fingerprint("T", "C"), s.sha256_text("t\nc"))

    def test_rel_path(self):
        inside = self.root / "a" / "b.md"
        self.assertEqual(s.rel_path(inside, self.root), "a/b.md")
        self.assertEqual(s.rel_path(self.tmp / "other.md", self.root), str(self.tmp / "other.md"))
        with mock.patch.object(Path, "resolve", side_effect=OSError("x")):
            self.assertEqual(s.rel_path(Path("a/b"), Path("a")), "a/b")

    def test_short_title_and_context(self):
        self.assertEqual(s.short_title("  - [ ]  Hello   world "), "[ ] Hello world")
        self.assertEqual(s.short_title("1) numbered item"), "numbered item")
        self.assertEqual(s.short_title("* x"), "x")
        long = "word " * 40
        t = s.short_title(long)
        self.assertLessEqual(len(t), 72)
        self.assertTrue(t.endswith("..."))
        self.assertEqual(s.short_title("abcdefghij", limit=10), "abcdefghij")
        self.assertEqual(s.short_context("a\n\n b   c"), "a b c")
        self.assertTrue(s.short_context("w " * 400).endswith("..."))
        self.assertLessEqual(len(s.short_context("w " * 400)), 280)


class FileHelpersTest(Base):
    def test_atomic_write_and_read(self):
        p = self.tmp / "d" / "f.txt"
        s.atomic_write(p, "héllo")
        self.assertEqual(p.read_text(encoding="utf-8"), "héllo")
        self.assertEqual(sorted(x.name for x in p.parent.iterdir()), ["f.txt"])
        s.atomic_write(p, "new")
        self.assertEqual(s.read_text(p), "new")
        bad = self.tmp / "bad.txt"
        bad.write_bytes(b"a\xffb")
        self.assertEqual(s.read_text(bad), "a\ufffdb")

    def test_json_roundtrip_is_sorted_and_newline_terminated(self):
        p = self.tmp / "x.json"
        s.save_json(p, {"b": 1, "a": [2]})
        self.assertEqual(p.read_text(), '{\n  "a": [\n    2\n  ],\n  "b": 1\n}\n')
        self.assertEqual(s.load_json(p), {"a": [2], "b": 1})

    def test_find_project_root(self):
        top = self.tmp / "top"
        deep = top / "a" / "b"
        deep.mkdir(parents=True)
        (top / ".silver-bullet.json").write_text("{}")
        self.assertEqual(s.find_project_root(deep), (top, True))
        self.assertEqual(s.find_project_root(top), (top, True))
        bare = self.tmp / "bare"
        bare.mkdir()
        self.assertEqual(s.find_project_root(bare), (bare, False))

    def test_load_config(self):
        self.assertEqual(s.load_config(self.root), {})
        cfg = self.root / ".silver-bullet.json"
        cfg.write_text('{"issue_tracker": "github"}')
        self.assertEqual(s.load_config(self.root), {"issue_tracker": "github"})
        cfg.write_text("[1]")
        self.assertEqual(s.load_config(self.root), {})
        cfg.write_text("{broken")
        self.assertEqual(s.load_config(self.root), {})

    def test_load_state(self):
        fresh = s.load_state(self.root)
        self.assertEqual(fresh, {"schema_version": 1, "project_root": str(self.root), "sources": {}, "fingerprints": {}, "candidates_by_id": {}})
        path = self.root / ".silver-bullet" / "scan-state.json"
        path.parent.mkdir()
        path.write_text('{"sources": {"a": 1}, "extra": true}')
        loaded = s.load_state(self.root)
        self.assertEqual(loaded["sources"], {"a": 1})
        self.assertEqual((loaded["extra"], loaded["schema_version"], loaded["fingerprints"]), (True, 1, {}))
        for bad in ("[1]", "{broken"):
            path.write_text(bad)
            self.assertEqual(s.load_state(self.root)["candidates_by_id"], {})
            self.assertEqual(s.load_state(self.root)["project_root"], str(self.root))

    def test_save_state(self):
        with mock.patch.object(s, "now_iso", return_value="T"):
            s.save_state(self.root, {"k": 1})
        saved = json.loads((self.root / ".silver-bullet" / "scan-state.json").read_text())
        self.assertEqual(saved, {"k": 1, "project_root": str(self.root), "last_scan_at": "T"})

    def test_parse_jsonl(self):
        p = self.write("t.jsonl", '{"a": 1}\n\n  \nnot json\n[1]\n"str"\n{"b": 2}\n')
        self.assertEqual(s.parse_jsonl(p), [{"a": 1}, {"b": 2}])

    def test_collect_text(self):
        out: list[str] = []
        s.collect_text(
            {"title": "T", "ignored": "no", "message": ["m1", {"text": "t1", "other": "o"}, "  "], "n": 5,
             "content": "  padded  ", "description": ""},
            out,
        )
        self.assertEqual(out, ["T", "m1", "t1", "padded"])
        out = []
        s.collect_text("top", out)
        s.collect_text(["a", ["b"]], out)
        s.collect_text(7, out)
        self.assertEqual(out, ["top", "a", "b"])

    def test_transcript_text(self):
        j = self.write("t.jsonl", '{"text": "one", "x": "skip"}\n{"message": {"content": "two"}}\n')
        self.assertEqual(s.transcript_text(j), "one\ntwo")
        m = self.write("t.md", "raw *markdown*")
        self.assertEqual(s.transcript_text(m), "raw *markdown*")

    def test_source_hash_depends_on_mtime_and_text(self):
        p = self.write("a.md", "one")
        h1 = s.source_hash(p, "one")
        self.assertEqual(h1, s.source_hash(p, "one"))
        self.assertNotEqual(h1, s.source_hash(p, "two"))
        os.utime(p, ns=(1, 2_000_000_000))
        self.assertNotEqual(h1, s.source_hash(p, "one"))


class ProjectMatchTest(Base):
    def test_metadata_values(self):
        row = {
            "cwd": " /a ", "work_dir": "  ", "project_root": 5, "other": "/z",
            "nested": {"git_project_root": "/b", "list": [{"cwd_real": "/c"}, "str", ["x"]]},
            "arr": [{"cwd_display": "/d"}],
        }
        self.assertEqual(s.project_metadata_values(row), {"/a", "/b", "/c", "/d"})
        self.assertEqual(s.project_metadata_values("scalar"), set())
        self.assertEqual(s.project_metadata_values([{"cwd": "/e"}]), {"/e"})

    def test_matches(self):
        self.assertTrue(s.project_matches_source({"cwd": str(self.root)}, self.root))
        self.assertFalse(s.project_matches_source({"cwd": str(self.tmp / "other")}, self.root))
        self.assertFalse(s.project_matches_source({}, self.root))
        link = self.tmp / "link"
        link.symlink_to(self.root)
        self.assertTrue(s.project_matches_source({"cwd": str(link)}, self.root))
        rel_root = Path("relroot")
        with mock.patch.object(Path, "resolve", return_value=self.root):
            self.assertTrue(s.project_matches_source({"cwd": "relroot"}, rel_root))
        self.assertTrue(s.project_matches_source({"cwd": "~/.."}, Path(str(self.home.parent))))

    def test_unresolvable_candidates_are_ignored(self):
        self.assertFalse(s.project_matches_source({"cwd": "bad\0path"}, self.root))
        self.assertTrue(s.project_matches_source({"cwd": "bad\0path", "work_dir": str(self.root)}, self.root))


class EnvTest(Base):
    def test_env_path(self):
        self.assertIsNone(s.env_path("CODEX_HOME"))
        os.environ["CODEX_HOME"] = "  "
        self.assertIsNone(s.env_path("CODEX_HOME"))
        os.environ["CODEX_HOME"] = "~/x"
        self.assertEqual(s.env_path("CODEX_HOME"), self.home / "x")

    def test_infer_agent_env(self):
        self.assertEqual(s.infer_agent_env("claude"), "claude")
        self.assertEqual(s.infer_agent_env("auto"), "auto")
        for key in ("SILVER_BULLET_RUNTIME", "SB_RUNTIME_NAME"):
            for val in ("codex", " Claude ", "KAY"):
                with mock.patch.dict(os.environ, {key: val}):
                    self.assertEqual(s.infer_agent_env("auto"), val.strip().lower())
        with mock.patch.dict(os.environ, {"SILVER_BULLET_RUNTIME": "cursor"}):
            self.assertEqual(s.infer_agent_env("auto"), "auto")
        with mock.patch.dict(os.environ, {"SILVER_BULLET_RUNTIME": "", "SB_RUNTIME_NAME": "kay"}):
            self.assertEqual(s.infer_agent_env("auto"), "kay")
        with mock.patch.dict(os.environ, {"KAY_HOME": "/k", "CODEX_HOME": "/c"}):
            self.assertEqual(s.infer_agent_env("auto"), "kay")
        for key in ("CODEX_HOME", "CODE_HOME", "CODEX_SESSION_CATALOG_PATH"):
            with mock.patch.dict(os.environ, {key: "/x", "CLAUDE_HOME": "/c"}):
                self.assertEqual(s.infer_agent_env("auto"), "codex")
        with mock.patch.dict(os.environ, {"CLAUDE_HOME": "/c"}):
            self.assertEqual(s.infer_agent_env("auto"), "claude")

    def test_runtime_home_candidates(self):
        h = self.home
        self.assertEqual(
            s.runtime_home_candidates("auto"),
            [h / ".codex", h / ".code", h / ".claude", h / ".kay"],
        )
        self.assertEqual(s.runtime_home_candidates("claude"), [h / ".claude"])
        self.assertEqual(s.runtime_home_candidates("kay"), [h / ".kay"])
        self.assertEqual(s.runtime_home_candidates("codex"), [h / ".codex", h / ".code"])
        os.environ.update({"CODEX_HOME": str(self.tmp / "cx"), "CODE_HOME": str(h / ".code"),
                           "CLAUDE_HOME": str(self.tmp / "cl"), "KAY_HOME": str(self.tmp / "ky"),
                           "SB_RUNTIME_HOME_ROOT": str(self.tmp / "cx")})
        self.assertEqual(
            s.runtime_home_candidates("auto"),
            [self.tmp / "cx", h / ".code", h / ".codex", self.tmp / "cl", h / ".claude", self.tmp / "ky", h / ".kay"],
        )
        os.environ["SB_RUNTIME_HOME_ROOT"] = str(self.tmp / "extra")
        self.assertEqual(s.runtime_home_candidates("claude")[-1], self.tmp / "extra")

    def test_catalog_candidates_dedupe(self):
        a, b = self.tmp / "a", self.tmp / "b"
        os.environ["CODEX_SESSION_CATALOG_PATH"] = str(a / "sessions" / "index" / "catalog.jsonl")
        got = s.catalog_candidates("codex", [a, b, a])
        self.assertEqual(got, [
            a / "sessions" / "index" / "catalog.jsonl",
            a / ".kay" / "sessions" / "index" / "catalog.jsonl",
            b / "sessions" / "index" / "catalog.jsonl",
            b / ".kay" / "sessions" / "index" / "catalog.jsonl",
        ])
        del os.environ["CODEX_SESSION_CATALOG_PATH"]
        self.assertEqual(s.catalog_candidates("codex", []), [])

    def test_transcript_store_roots_dedupe_and_states(self):
        h = self.tmp / "h"
        roots = s.transcript_store_roots([h, h])
        self.assertEqual(len(roots), 7)
        self.assertEqual(roots[0], (h / "projects", "active"))
        self.assertEqual(roots[3], (h / "sessions" / "archive", "archived"))
        self.assertEqual({st for _p, st in roots}, {"active", "archived"})

    def test_classify_source_state(self):
        self.assertEqual(s.classify_source_state(Path("/h/Archive/x.jsonl")), "archived")
        self.assertEqual(s.classify_source_state(Path("/h/sessions/archived/x")), "archived")
        self.assertEqual(s.classify_source_state(Path("/h/PROJECTS/x")), "active")
        self.assertEqual(s.classify_source_state(Path("/h/sessions/x")), "active")
        self.assertEqual(s.classify_source_state(Path("/h/active/x")), "active")
        self.assertEqual(s.classify_source_state(Path("/h/misc/x")), "unknown")
        self.assertEqual(s.classify_source_state(Path("/h/misc/x"), "custom"), "custom")

    def test_empty_preflight(self):
        pre = s.empty_preflight("auto", "codex", [Path("/a"), Path("/b")])
        self.assertEqual(pre["resolved_paths"], ["/a", "/b"])
        self.assertEqual((pre["requested_agent_env"], pre["selected_agent_env"]), ("auto", "codex"))
        self.assertEqual(pre["source_counts"], {"active": 0, "archived": 0, "unknown": 0})
        self.assertEqual((pre["considered_count"], pre["matched_count"], pre["unmatched_reasons"]), (0, 0, {}))


class DiscoverTest(Base):
    def setUp(self):
        super().setUp()
        self.codex = self.tmp / "codex-home"
        os.environ["CODEX_HOME"] = str(self.codex)

    def discover(self, agent="codex"):
        return s.discover_sources(self.root, agent)

    def row(self, **kw):
        return json.dumps({"cwd": str(self.root), **kw})

    def test_nothing_found(self):
        sources, pre = self.discover()
        self.assertEqual(sources, [])
        self.assertEqual((pre["considered_count"], pre["matched_count"], pre["unmatched_count"]), (0, 0, 0))
        self.assertEqual(pre["selected_agent_env"], "codex")
        self.assertEqual(pre["requested_agent_env"], "codex")
        self.assertEqual(pre["catalog_paths"][0], str(self.codex / "sessions" / "index" / "catalog.jsonl"))
        self.assertIn(str(self.codex / "projects"), pre["store_roots"])

    def test_auto_agent_env_is_resolved(self):
        _, pre = s.discover_sources(self.root)
        self.assertEqual((pre["requested_agent_env"], pre["selected_agent_env"]), ("auto", "codex"))

    def test_markdown_sources_and_duplicates(self):
        a = self.write("docs/sessions/a.md", "## Needs Human Review\n- x\n", base=self.root)
        self.write("docs/handoffs/b.md", "b", base=self.root)
        self.write("docs/handoff/c.md", "c", base=self.root)
        self.write("docs/handoff-d.md", "d", base=self.root)
        self.write("my-handoff-notes.md", "e", base=self.root)
        self.write("docs/sessions/ignored.txt", "z", base=self.root)
        (self.root / "docs" / "sessions" / "alias.md").symlink_to(a)
        sources, pre = self.discover()
        paths = [str(src["path"].relative_to(self.root)) for src in sources]
        self.assertEqual(paths, ["docs/sessions/a.md", "docs/handoffs/b.md", "docs/handoff/c.md", "docs/handoff-d.md", "my-handoff-notes.md"])
        self.assertEqual({src["kind"] for src in sources}, {"markdown-session"})
        first = sources[0]
        self.assertEqual(first["text"], "## Needs Human Review\n- x\n")
        self.assertEqual(first["hash"], s.source_hash(first["path"], first["text"]))
        self.assertEqual(first["mtime_ns"], first["path"].stat().st_mtime_ns)
        self.assertEqual(first["metadata"], {"source_state": "unknown"})
        self.assertEqual(pre["matched_count"], 5)
        self.assertEqual(pre["considered_count"], 6)
        self.assertEqual(pre["duplicate_paths"], [str(a.resolve())])
        self.assertEqual(pre["source_counts"], {"active": 0, "archived": 0, "unknown": 5})

    def test_unreadable_markdown_is_counted(self):
        self.write("docs/sessions/a.md", "x", base=self.root)
        with mock.patch.object(s, "transcript_text", side_effect=OSError("denied")):
            sources, pre = self.discover()
        self.assertEqual(sources, [])
        self.assertEqual((pre["considered_count"], pre["unmatched_count"], pre["unmatched_reasons"]), (2, 1, {"unreadable": 1}))

    def test_catalog_rows(self):
        cat = self.codex / "sessions" / "index" / "catalog.jsonl"
        good = self.write("rollouts/good.jsonl", self.row(text="hello") + "\n", base=self.codex)
        rel = self.write("sessions/rel.jsonl", self.row(text="rel") + "\n", base=self.codex)
        dead = self.write("rollouts/dead.jsonl", self.row(text="dead") + "\n", base=self.codex)
        lines = [
            self.row(rollout_path=str(good)),
            json.dumps({"cwd": str(self.root), "rollout_path": "sessions/rel.jsonl"}),
            json.dumps({"deleted": True, "rollout_path": str(dead)}),
            json.dumps({"deleted": True, "rollout_path": "sessions/gone.jsonl"}),
            json.dumps({"deleted": True, "rollout_path": "bad\0path"}),
            json.dumps({"deleted": True}),
            json.dumps({"cwd": "/somewhere/else", "rollout_path": str(good)}),
            self.row(),
            self.row(rollout_path=str(self.codex / "missing.jsonl")),
        ]
        self.write("sessions/index/catalog.jsonl", "\n".join(lines) + "\n", base=self.codex)
        sources, pre = self.discover()
        by_path = {str(src["path"]): src for src in sources}
        self.assertEqual(set(by_path), {str(good), str(rel)})
        self.assertEqual(by_path[str(rel)]["metadata"]["cwd"], str(self.root))
        self.assertEqual(by_path[str(good)]["kind"], "codex-catalog-transcript")
        self.assertEqual(by_path[str(good)]["metadata"]["source_state"], "active")
        self.assertEqual(pre["deleted_skipped_count"], 4)
        self.assertEqual(pre["unmatched_reasons"], {"project-mismatch": 1})
        self.assertEqual(pre["duplicate_paths"], [str(rel.resolve())])
        self.assertEqual(pre["catalog_paths"][0], str(cat))
        self.assertNotIn(str(dead), by_path)

    def test_catalog_relative_rollout_resolves_against_catalog_grandparent(self):
        cat = self.codex / "sessions" / "index" / "catalog.jsonl"
        target = self.write("sessions/index/../../relative/x.jsonl", self.row(text="t") + "\n", base=self.codex)
        self.write("sessions/index/catalog.jsonl", self.row(rollout_path="relative/x.jsonl") + "\n", base=self.codex)
        self.assertEqual(cat.parent.parent.parent, self.codex)
        sources, _ = self.discover()
        catalog_sources = [x for x in sources if x["kind"] == "codex-catalog-transcript"]
        self.assertEqual([x["path"] for x in catalog_sources], [self.codex / "relative" / "x.jsonl"])
        self.assertEqual(catalog_sources[0]["metadata"]["cwd"], str(self.root))
        self.assertTrue(target.exists())

    def test_store_transcripts(self):
        match = self.write("projects/p1/session.jsonl", self.row(text="a") + "\n", base=self.codex)
        arch = self.write("sessions/archive/old.jsonl", self.row(text="b") + "\n", base=self.codex)
        self.write("projects/p2/other.jsonl", json.dumps({"cwd": "/elsewhere"}) + "\n", base=self.codex)
        self.write("projects/p3/deleted.jsonl", self.row() + "\n" + json.dumps({"deleted": True}) + "\n", base=self.codex)
        self.write("projects/catalog.jsonl", self.row() + "\n", base=self.codex)
        self.write("projects/p4/notes.txt", "ignored", base=self.codex)
        sources, pre = self.discover()
        by_kind = {str(src["path"]): src for src in sources}
        self.assertEqual(set(by_kind), {str(match), str(arch)})
        self.assertEqual(by_kind[str(match)]["kind"], "codex-session")
        self.assertEqual(by_kind[str(match)]["metadata"]["source_state"], "active")
        self.assertEqual(by_kind[str(arch)]["metadata"]["source_state"], "archived")
        self.assertEqual(pre["source_counts"], {"active": 1, "archived": 1, "unknown": 0})
        self.assertEqual(pre["deleted_skipped_count"], 1)
        self.assertEqual(pre["unmatched_reasons"], {"project-mismatch": 1})
        # sessions/archive is also reached through the sessions/ root, so old.jsonl is seen twice
        self.assertEqual(pre["considered_count"], 5)
        self.assertEqual(pre["duplicate_paths"], [str(arch.resolve())])
        self.assertEqual(pre["unmatched_count"], 1)

    def test_store_rglob_includes_nested_sessions_dir_once(self):
        # sessions/ and sessions/active both are roots; the same file must be added once.
        f = self.write("sessions/active/s.jsonl", self.row() + "\n", base=self.codex)
        sources, pre = self.discover()
        self.assertEqual([x["path"] for x in sources], [f])
        self.assertEqual(pre["duplicate_paths"], [str(f.resolve())])

    def test_catalog_transcript_is_not_double_counted_by_store_scan(self):
        t = self.write("sessions/t.jsonl", self.row() + "\n", base=self.codex)
        self.write("sessions/index/catalog.jsonl", self.row(rollout_path=str(t)) + "\n", base=self.codex)
        sources, pre = self.discover()
        self.assertEqual([x["kind"] for x in sources], ["codex-catalog-transcript"])
        self.assertEqual(pre["duplicate_paths"], [str(t.resolve())])

    def test_deleted_catalog_rollouts_are_not_picked_up_from_store(self):
        t = self.write("sessions/t.jsonl", self.row() + "\n", base=self.codex)
        self.write("sessions/index/catalog.jsonl", json.dumps({"deleted": True, "rollout_path": str(t)}) + "\n", base=self.codex)
        sources, pre = self.discover()
        self.assertEqual(sources, [])
        self.assertEqual(pre["deleted_skipped_count"], 1)

    def test_unparseable_store_transcript_is_unreadable(self):
        self.write("projects/p/bad.jsonl", self.row() + "\n", base=self.codex)
        with mock.patch.object(s, "parse_jsonl", side_effect=OSError("io")):
            sources, pre = self.discover()
        self.assertEqual(sources, [])
        self.assertEqual(pre["unmatched_reasons"], {"unreadable": 1})
        self.assertEqual(pre["unmatched_count"], 1)

    def test_store_transcript_resolve_failure_falls_back_to_raw_path(self):
        f = self.write("projects/p/x.jsonl", self.row() + "\n", base=self.codex)
        real_resolve = Path.resolve
        calls = []

        def flaky(self_, *a, **k):
            if self_ == f and not calls:
                calls.append(1)
                raise OSError("loop")
            return real_resolve(self_, *a, **k)

        with mock.patch.object(Path, "resolve", flaky):
            sources, _ = self.discover()
        self.assertEqual([x["path"] for x in sources], [f])

    def test_unknown_source_state_counts_as_unknown(self):
        f = self.write("projects/p/x.jsonl", self.row() + "\n", base=self.codex)
        with mock.patch.object(s, "classify_source_state", return_value="weird"):
            sources, pre = self.discover()
        self.assertEqual(pre["source_counts"], {"active": 0, "archived": 0, "unknown": 1})
        self.assertEqual(sources[0]["metadata"]["source_state"], "weird")
        self.assertEqual(sources[0]["path"], f)


if __name__ == "__main__":
    unittest.main()
