"""Unit tests for scripts/silver-scan.py: candidate extraction, tracking, filing, scan and CLI."""
from __future__ import annotations

import contextlib
import io
import json
import os
import runpy
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from sbtest import REPO_ROOT, load_module

s = load_module("scripts/silver-scan.py", name="silver_scan_flow_under_test")


def cp(returncode=0, stdout="", stderr=""):
    return subprocess.CompletedProcess([], returncode, stdout=stdout, stderr=stderr)


class Base(unittest.TestCase):
    def setUp(self):
        d = tempfile.TemporaryDirectory()
        self.addCleanup(d.cleanup)
        self.tmp = Path(d.name).resolve()
        self.root = self.tmp / "zzroot"
        self.root.mkdir()
        for name, val in (("now_iso", "2030-01-01T00:00:00+00:00"), ("local_date", "2030-01-01"), ("local_month", "2030-01")):
            p = mock.patch.object(s, name, return_value=val)
            p.start()
            self.addCleanup(p.stop)

    def write(self, rel, text="x"):
        p = self.root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text, encoding="utf-8")
        return p

    def source(self, text, rel="docs/sessions/s.md", kind="markdown-session"):
        return {"path": self.root / rel, "kind": kind, "text": text}

    def candidate(self, **over):
        c = {
            "candidate_id": "cid1", "fingerprint": "fp1", "kind": "deferred", "classification": "bug",
            "category": "bug", "confidence": "high", "routing_target": "issue", "title": "Fix it",
            "context": "Fix it now", "source_kind": "markdown-session", "source_path": "docs/sessions/s.md",
            "source_line": 3, "source_refs": [{"path": "docs/sessions/s.md", "line": 3}], "status": "pending",
        }
        c.update(over)
        return c


class ParsingTest(Base):
    def test_parse_sections_only_level_two_headings_start_sections(self):
        text = "preamble\n# H1\n## First Section  \nline a\n### Sub\nline b\n## Second\n"
        sections = s.parse_sections(text)
        self.assertEqual([x["title"] for x in sections], ["first section", "second"])
        self.assertEqual(sections[0]["raw_title"], "First Section")
        self.assertEqual(sections[0]["lines"], [(4, "line a"), (5, "### Sub"), (6, "line b")])
        self.assertEqual(sections[1]["lines"], [])
        self.assertEqual(s.parse_sections("no sections\n"), [])

    def test_split_blocks(self):
        lines = list(enumerate([
            "- first bullet", "  continued", "- second bullet", "", "para one", "para two", "",
            "```", "- in code", "```", "### heading", "1. numbered", "* star", "+ plus", "tail",
        ], 10))
        blocks = s.split_blocks(lines)
        self.assertEqual(blocks, [
            (10, "- first bullet\n  continued"),
            (12, "- second bullet"),
            (14, "para one\npara two"),
            (21, "1. numbered"),
            (22, "* star"),
            (23, "+ plus\ntail"),
        ])
        self.assertEqual(s.split_blocks([]), [])
        self.assertEqual(s.split_blocks([(1, ""), (2, "  "), (3, "a"), (4, ""), (5, ""), (6, "b")]), [(3, "a"), (6, "b")])
        self.assertEqual(s.split_blocks([(1, "### only heading"), (2, "text")]), [(2, "text")])
        self.assertEqual(s.split_blocks([(5, "a"), (6, "### h"), (7, "b")]), [(5, "a"), (7, "b")])

    def test_strip_prefix(self):
        self.assertEqual(s.strip_prefix(""), "")
        self.assertEqual(s.strip_prefix("- item\n  more"), "item\n  more")
        self.assertEqual(s.strip_prefix("12) item"), "item")
        self.assertEqual(s.strip_prefix("no bullet"), "no bullet")

    def test_any_match(self):
        self.assertTrue(s.any_match("A Crash happened", s.BUG_PATTERNS))
        self.assertFalse(s.any_match("all good", s.BUG_PATTERNS))

    def test_classify_deferred(self):
        cases = {
            "the failing test needs attention": ("bug", "high"),
            "Fix the ci pipeline": ("bug", "high"),
            "fixing this issue properly": ("bug", "high"),
            "fix the typo here": ("docs", "medium"),
            "update the README": ("docs", "medium"),
            "refactor the loader": ("tech debt", "medium"),
            "a workaround for sed": ("tech debt", "medium"),
            "add a feature": ("enhancement", "medium"),
            "polish things later": ("enhancement", "medium"),
            "rename the files": ("chore", "medium"),
            "housekeeping": ("chore", "medium"),
            "work is blocked on review": ("question", "medium"),
            "TODO check with owner": ("question", "medium"),
            "nothing to see": ("chore", "low"),
        }
        for text, expected in cases.items():
            with self.subTest(text=text):
                self.assertEqual(s.classify_deferred(text), expected)

    def test_classify_insight(self):
        cfg = {"project": {"name": "Acme"}}
        self.assertEqual(s.classify_insight("zzroot uses a queue", self.root, {}), ("knowledge", "high"))
        self.assertEqual(s.classify_insight("acme prefers tabs", self.root, cfg), ("knowledge", "high"))
        self.assertEqual(s.classify_insight("silver-bullet gates", self.root, {}), ("knowledge", "high"))
        for text in ("see docs/guide", "edit config.json", "run build.sh", "NOTES.md says", "a/b"):
            self.assertEqual(s.classify_insight(text, self.root, {}), ("knowledge", "high"), text)
        self.assertEqual(s.classify_insight("prefer small commits", self.root, cfg), ("learning", "medium"))
        self.assertEqual(s.classify_insight("prefer small commits", self.root, {"project": None}), ("learning", "medium"))

    def test_build_candidate_deferred_and_routing(self):
        src = self.source("")
        c = s.build_candidate(self.root, src, "needs human review", "- Fix the failing test", 7, {})
        self.assertEqual((c["kind"], c["classification"], c["category"], c["confidence"], c["routing_target"]), ("deferred", "bug", "bug", "high", "issue"))
        self.assertEqual((c["title"], c["context"], c["status"], c["source_line"]), ("Fix the failing test", "Fix the failing test", "pending", 7))
        self.assertEqual((c["source_path"], c["source_kind"]), ("docs/sessions/s.md", "markdown-session"))
        self.assertEqual(c["source_refs"], [{"path": "docs/sessions/s.md", "line": 7}])
        self.assertRegex(c["candidate_id"], r"^[0-9a-f]{64}$")
        self.assertEqual(c["fingerprint"], s.scan_item_fingerprint(c["title"], c["context"]))
        c = s.build_candidate(self.root, src, "autonomous decisions", "- rename the files", 1, {})
        self.assertEqual((c["classification"], c["routing_target"]), ("chore", "backlog"))
        c = s.build_candidate(self.root, src, "needs review", "- work is blocked", 1, {})
        self.assertEqual((c["classification"], c["routing_target"]), ("question", "issue"))

    def test_build_candidate_knowledge(self):
        src = self.source("")
        c = s.build_candidate(self.root, src, "knowledge & learnings additions", "- see docs/x", 2, {})
        self.assertEqual((c["kind"], c["classification"], c["routing_target"], c["confidence"]), ("knowledge", "knowledge", "knowledge", "high"))
        c = s.build_candidate(self.root, src, "knowledge and lessons additions", "- be nice", 2, {})
        self.assertEqual((c["classification"], c["routing_target"], c["confidence"]), ("learning", "learning", "medium"))

    def test_build_candidate_skips(self):
        src = self.source("")
        for block in ("", "- (none)", "none", "*(none)*", "N/A", "- N/A"):
            self.assertIsNone(s.build_candidate(self.root, src, "needs review", block, 1, {}), block)
        self.assertIsNone(s.build_candidate(self.root, src, "random section", "- Fix the failing test", 1, {}))
        self.assertIsNone(s.build_candidate(self.root, src, "items filed", "- Fix the failing test", 1, {}))


SESSION = """# Session
Intro line with nothing special.
## Needs Human Review
- Fix the failing test in hooks/foo.sh
- Document the flag in README
- (none)
## Autonomous Decisions
- Refactor the loader
## Knowledge & Learnings Additions
- Always quote variables in hooks/foo.sh
- Prefer small commits
- Already recorded insight
## Items Filed
- [knowledge]: Already recorded insight
- [learnings]: something unrelated
- [lessons]: another one
- plain filed item
## Notes
Open question: which backend?
```
TODO inside code fence
```
Some TODO inside prose
"""


class CandidateStreamTest(Base):
    def stream(self, text=SESSION, config=None, tracker=""):
        with mock.patch.object(s, "git_or_changelog_match", return_value=False):
            return s.parse_candidate_stream(self.root, self.source(text), config or {}, tracker)

    def test_sections_and_keyword_sweep(self):
        cands, dupes = self.stream()
        titles = [c["title"] for c in cands]
        self.assertIn("Fix the failing test in hooks/foo.sh", titles)
        self.assertIn("Refactor the loader", titles)
        self.assertIn("Always quote variables in hooks/foo.sh", titles)
        self.assertIn("Open question: which backend?", titles)
        self.assertIn("Some TODO inside prose", titles)
        self.assertNotIn("TODO inside code fence", titles)
        self.assertFalse(any(t.startswith("#") for t in titles))
        sweep = next(c for c in cands if c["title"] == "Some TODO inside prose")
        self.assertEqual((sweep["kind"], sweep["classification"], sweep["confidence"], sweep["routing_target"]), ("deferred", "question", "medium", "issue"))
        self.assertEqual(sweep["source_line"], SESSION.splitlines().index("Some TODO inside prose") + 1)
        self.assertEqual(sweep["context"], "``` Some TODO inside prose")
        self.assertEqual(sweep["source_refs"], [{"path": "docs/sessions/s.md", "line": sweep["source_line"]}])
        self.assertTrue(all(c["status"] == "pending" for c in cands))

    def test_recorded_insights_in_items_filed_suppress_duplicate_knowledge(self):
        cands, dupes = self.stream()
        self.assertNotIn("Already recorded insight", [c["title"] for c in cands])
        self.assertEqual(dupes, 1)

    def test_recorded_insight_prefixes(self):
        for tag in ("knowledge", "learnings", "lessons"):
            text = f"## Knowledge & Learnings Additions\n- Same thing\n## Items Filed\n- [{tag}]: Same thing\n"
            cands, dupes = self.stream(text)
            self.assertEqual(([c["title"] for c in cands], dupes), ([], 1), tag)
        before = "## Items Filed\n- [knowledge]: Same thing\n## Knowledge & Learnings Additions\n- Same thing\n"
        cands, dupes = self.stream(before)
        self.assertEqual(([c["title"] for c in cands], dupes), ([], 1))
        text = "## Knowledge & Learnings Additions\n- Same thing\n## Items Filed\n- [other]: Same thing\n"
        cands, dupes = self.stream(text)
        self.assertEqual(([c["title"] for c in cands], dupes), (["Same thing"], 0))

    def test_recorded_insight_in_silver_rem_format_suppresses_knowledge(self):
        insight = "Atomic jq+tmpfile+mv pattern for safe JSON writes and temp cleanup"
        self.assertGreater(len(insight), 60)
        filed = f"- [knowledge]: Architecture Patterns \u2014 {insight[:60]}"
        text = f"## Knowledge & Learnings Additions\n- {insight}\n## Items Filed\n\n{filed}\n"
        cands, dupes = self.stream(text)
        self.assertEqual(([c["title"] for c in cands], dupes), ([], 1))

    def test_recorded_insight_short_with_category_and_ascii_hyphen(self):
        for filed in ("- [learnings]: stack:bash \u2014 Prefer small commits", "- [lessons]: practice:workflow - Prefer small commits"):
            text = f"## Knowledge & Learnings Additions\n- Prefer small commits\n## Items Filed\n{filed}\n"
            cands, dupes = self.stream(text)
            self.assertEqual(([c["title"] for c in cands], dupes), ([], 1), filed)

    def test_recorded_insight_hyphen_inside_text_without_category(self):
        text = "## Knowledge & Learnings Additions\n- Use foo - not bar\n## Items Filed\n- [knowledge]: Use foo - not bar\n"
        cands, dupes = self.stream(text)
        self.assertEqual(([c["title"] for c in cands], dupes), ([], 1))

    def test_recorded_insight_non_matches_stay_candidates(self):
        long_insight = "Atomic jq+tmpfile+mv pattern for safe JSON writes and temp cleanup"
        cases = {
            "different insight, same category": ("Something else entirely", "- [knowledge]: Architecture Patterns \u2014 Another thing"),
            "stored short insight is only a prefix of the candidate": ("Same thing and more", "- [knowledge]: Architecture Patterns \u2014 Same thing"),
            "candidate shares only the category": ("Architecture Patterns are fun", "- [knowledge]: Architecture Patterns \u2014 Another thing"),
            "same start but diverges before sixty chars": (long_insight, "- [knowledge]: Architecture Patterns \u2014 Atomic jq+tmpfile+mv pattern for a different thing altogether"),
            "empty recorded insight": ("Anything at all", "- [knowledge]:"),
            "category only": ("Anything at all", "- [knowledge]: Architecture Patterns \u2014"),
        }
        for name, (insight, filed) in cases.items():
            with self.subTest(name):
                text = f"## Knowledge & Learnings Additions\n- {insight}\n## Items Filed\n{filed}\n"
                cands, dupes = self.stream(text)
                self.assertEqual(([c["title"] for c in cands], dupes), ([s.short_title(insight)], 0))

    def test_duplicate_fingerprints_merge_refs_and_ids(self):
        text = "## Needs Human Review\n- Same item\n- Same item\n"
        cands, dupes = self.stream(text)
        self.assertEqual(dupes, 1)
        self.assertEqual(len(cands), 1)
        self.assertEqual([r["line"] for r in cands[0]["source_refs"]], [2, 3])
        self.assertEqual(len(cands[0]["candidate_ids"]), 1)

    def test_duplicates_with_same_candidate_id_and_ref(self):
        a = self.candidate(candidate_id="same", fingerprint="fp", source_refs=[{"path": "p", "line": 1}])
        b = self.candidate(candidate_id="same", fingerprint="fp", source_refs=[{"path": "p", "line": 1}])
        c = self.candidate(candidate_id="other", fingerprint="fp", source_refs=[{"path": "p", "line": 1}, {"path": "p", "line": 2}])
        d = self.candidate(candidate_id="other", fingerprint="fp", source_refs=[])
        built = iter([a, b, c, d])
        with mock.patch.object(s, "build_candidate", side_effect=lambda *x, **k: next(built)), \
             mock.patch.object(s, "git_or_changelog_match", return_value=False):
            cands, dupes = s.parse_candidate_stream(
                self.root, self.source("## Needs Human Review\n- one\n- two\n- three\n- four\n"), {}, "")
        self.assertEqual(dupes, 3)
        self.assertEqual(len(cands), 1)
        self.assertEqual(cands[0]["candidate_ids"], ["same", "other"])
        self.assertEqual(cands[0]["source_refs"], [{"path": "p", "line": 1}, {"path": "p", "line": 2}])

    def test_tracking_status_reasons(self):
        text = "## Needs Human Review\n- Alpha work item\n- Beta work item\n- Gamma work item\n- Delta work item\n"
        tracker = "alpha work item is tracked here"
        with mock.patch.object(s, "github_issue_exists", side_effect=lambda root, c: c["title"] == "Beta work item") as gh, \
             mock.patch.object(s, "git_or_changelog_match", side_effect=lambda root, c: c["title"] == "Gamma work item"):
            cands, _ = s.parse_candidate_stream(self.root, self.source(text), {"issue_tracker": "github"}, tracker)
        got = {c["title"]: (c["status"], c.get("dedupe_reason")) for c in cands}
        self.assertEqual(got["Alpha work item"], ("tracked", "local-tracker"))
        self.assertEqual(got["Beta work item"], ("tracked", "github-issues"))
        self.assertEqual(got["Gamma work item"], ("weakly-tracked", "gitlog-or-changelog"))
        self.assertEqual(got["Delta work item"], ("pending", None))
        self.assertEqual(gh.call_count, 3)  # not asked for the locally tracked one

    def test_github_not_consulted_without_github_tracker(self):
        text = "## Needs Human Review\n- Beta work item\n"
        with mock.patch.object(s, "github_issue_exists") as gh, mock.patch.object(s, "git_or_changelog_match", return_value=False):
            s.parse_candidate_stream(self.root, self.source(text), {"issue_tracker": "local"}, "")
        gh.assert_not_called()


class TrackerTest(Base):
    def test_local_tracker_text(self):
        self.assertEqual(s.local_tracker_text(self.root), "")
        self.write("docs/issues/ISSUES.md", "issues")
        self.write("docs/issues/BACKLOG.md", "backlog")
        self.write("docs/knowledge/2030-01.md", "know")
        self.write("docs/learnings/2030-01.md", "learn")
        self.write("docs/lessons/old.md", "lesson")
        (self.root / "docs" / "knowledge" / "dir.md").mkdir()
        self.assertEqual(s.local_tracker_text(self.root), "issues\nbacklog\nknow\nlearn\nlesson")

    def test_local_tracker_text_skips_unreadable(self):
        self.write("docs/issues/ISSUES.md", "issues")
        self.write("docs/issues/BACKLOG.md", "backlog")
        real = s.read_text

        def flaky(path):
            if path.name == "ISSUES.md":
                raise OSError("denied")
            return real(path)

        with mock.patch.object(s, "read_text", flaky):
            self.assertEqual(s.local_tracker_text(self.root), "backlog")

    def test_local_tracker_matches(self):
        c = self.candidate(candidate_id="CID-123", fingerprint="FP-456", title="Fix the Thing", context="Some context that explains it")
        self.assertFalse(s.local_tracker_matches(c, ""))
        self.assertTrue(s.local_tracker_matches(c, "see CID-123 here"))
        self.assertTrue(s.local_tracker_matches(c, "see FP-456 here"))
        self.assertTrue(s.local_tracker_matches(c, "### SB-I-1 — fix the thing\n"))
        self.assertTrue(s.local_tracker_matches(c, "prefix SOME CONTEXT that explains it suffix"))
        self.assertFalse(s.local_tracker_matches(c, "unrelated text"))
        empty = self.candidate(candidate_id="§1", fingerprint="§2", title="", context="")
        self.assertFalse(s.local_tracker_matches(empty, "anything at all"))


class ExternalTest(Base):
    def test_github_available(self):
        with mock.patch.object(s, "which", return_value="/usr/bin/gh"):
            self.assertTrue(s.github_available())
        with mock.patch.object(s, "which", return_value=None):
            self.assertFalse(s.github_available())

    def test_run_command(self):
        proc = s.run_command([sys.executable, "-c", "import os,sys; print(os.getcwd()); print('e', file=sys.stderr); sys.exit(3)"], cwd=self.root)
        self.assertEqual((proc.returncode, proc.stdout.strip(), proc.stderr.strip()), (3, str(self.root), "e"))
        proc = s.run_command([sys.executable, "-c", "print('hi')"])
        self.assertEqual(proc.stdout.strip(), "hi")

    def test_repo_slug_from_origin(self):
        cases = [
            (cp(1), "unknown/unknown"),
            (cp(0, "https://github.com/acme/repo.git\n"), "acme/repo"),
            (cp(0, "git@github.com:acme/repo.git"), "acme/repo"),
            (cp(0, "host:acme"), "host/acme"),
            (cp(0, "ssh://x/acme/repo"), "ssh://x/acme/repo"),
            (cp(0, "\n"), "unknown/unknown"),
        ]
        for proc, expected in cases:
            with mock.patch.object(s, "run_command", return_value=proc) as run:
                self.assertEqual(s.repo_slug_from_origin(self.root), expected)
                run.assert_called_once_with(["git", "remote", "get-url", "origin"], cwd=self.root)

    def test_gh_issue_list(self):
        with mock.patch.object(s, "github_available", return_value=False):
            self.assertEqual(s.gh_issue_list(self.root, "q"), [])
        with mock.patch.object(s, "github_available", return_value=True):
            with mock.patch.object(s, "run_command", return_value=cp(1)):
                self.assertEqual(s.gh_issue_list(self.root, "q"), [])
            with mock.patch.object(s, "run_command", return_value=cp(0, "{bad")):
                self.assertEqual(s.gh_issue_list(self.root, "q"), [])
            with mock.patch.object(s, "run_command", return_value=cp(0, '{"a": 1}')):
                self.assertEqual(s.gh_issue_list(self.root, "q"), [])
            with mock.patch.object(s, "run_command", return_value=cp(0, "")):
                self.assertEqual(s.gh_issue_list(self.root, "q"), [])
            with mock.patch.object(s, "run_command", return_value=cp(0, '[{"number": 1}]')) as run:
                self.assertEqual(s.gh_issue_list(self.root, "my query"), [{"number": 1}])
            args = run.call_args.args[0]
            self.assertEqual(args[:3], ["gh", "issue", "list"])
            self.assertEqual(args[args.index("--search") + 1], "my query")
            self.assertEqual(run.call_args.kwargs["cwd"], self.root)

    def test_github_issue_exists(self):
        c = self.candidate(candidate_id="CID", fingerprint="FP", title="Fix It")
        with mock.patch.object(s, "github_available", return_value=False):
            self.assertFalse(s.github_issue_exists(self.root, c))
        with mock.patch.object(s, "github_available", return_value=True):
            seen = []

            def listing(root, query):
                seen.append(query)
                return {"CID": [{"title": None, "body": "has CID inside"}],
                        "FP": [{"title": "x", "body": "fp FP here"}],
                        "Fix It": [{"title": "[sb] fix it", "body": None}]}.get(query, [])

            with mock.patch.object(s, "gh_issue_list", side_effect=listing):
                self.assertTrue(s.github_issue_exists(self.root, c))
                self.assertEqual(seen, ["CID"])
                seen.clear()
                self.assertTrue(s.github_issue_exists(self.root, self.candidate(candidate_id="zz", fingerprint="FP")))
                self.assertEqual(seen, ["zz", "FP"])
                seen.clear()
                self.assertTrue(s.github_issue_exists(self.root, self.candidate(candidate_id="§a", fingerprint="§b", title="Fix It")))
                self.assertEqual(seen, ["§a", "§b", "Fix It"])
                self.assertFalse(s.github_issue_exists(self.root, self.candidate(candidate_id="§a", fingerprint="§b", title="Other")))
                self.assertFalse(s.github_issue_exists(self.root, self.candidate(candidate_id="", fingerprint="", title="")))

    def test_github_issue_exists_unrelated_results_do_not_match(self):
        c = self.candidate(candidate_id="CID", fingerprint="FP", title="")
        with mock.patch.object(s, "github_available", return_value=True), \
             mock.patch.object(s, "gh_issue_list", return_value=[{"title": "other", "body": "nothing"}]):
            self.assertFalse(s.github_issue_exists(self.root, c))

    def test_git_or_changelog_match(self):
        c = self.candidate(title="Fix the very long thing now please")
        with mock.patch.object(s, "run_command", return_value=cp(0, "abc123 msg\n")) as run:
            self.assertTrue(s.git_or_changelog_match(self.root, c))
        self.assertEqual(run.call_args.args[0], ["git", "log", "--oneline", "-i", "--fixed-strings", "--grep=fix the very long thing", "--"])
        with mock.patch.object(s, "run_command", return_value=cp(0, "")):
            self.assertFalse(s.git_or_changelog_match(self.root, c))
            (self.root / "CHANGELOG.md").write_text("- fix the very long thing\n")
            self.assertTrue(s.git_or_changelog_match(self.root, c))
            # the phrase is normalized to lower case, so the changelog text is normalized the same way
            (self.root / "CHANGELOG.md").write_text("- Fix The Very Long Thing\n")
            self.assertTrue(s.git_or_changelog_match(self.root, c))
            (self.root / "CHANGELOG.md").write_text("- Fix a different thing\n")
            self.assertFalse(s.git_or_changelog_match(self.root, c))
        with mock.patch.object(s, "run_command", return_value=cp(128, "stuff")):
            (self.root / "CHANGELOG.md").unlink()
            self.assertFalse(s.git_or_changelog_match(self.root, c))
            self.assertFalse(s.git_or_changelog_match(self.root, self.candidate(title="")))
            self.assertFalse(s.git_or_changelog_match(self.root, self.candidate(title=" -- ")))


class LocalFilingTest(Base):
    def test_append_local_entry_creates_headers(self):
        issues = self.root / "docs/issues/ISSUES.md"
        s.append_local_entry(issues, "SB-I-1", self.candidate(source_refs=[{"path": "a.md", "line": 1}, {"path": "b.md", "line": 9}]))
        text = issues.read_text()
        self.assertTrue(text.startswith("# Issues\n\nItems tracked by Silver Bullet. IDs are sequential (SB-I-N). Do not renumber.\n\n---\n\n"))
        self.assertIn("### SB-I-1 — Fix it\n\n**Type:** bug\n**Filed:** 2030-01-01\n**Source:** a.md:1, b.md:9\n", text)
        self.assertIn("**Candidate-ID:** cid1\n**Fingerprint:** fp1\n**Status:** open\n\nFix it now\n\n---\n", text)
        backlog = self.root / "docs/issues/BACKLOG.md"
        s.append_local_entry(backlog, "SB-B-1", self.candidate(source_refs=[]))
        text = backlog.read_text()
        self.assertTrue(text.startswith("# Backlog\n\nItems tracked by Silver Bullet. IDs are sequential (SB-B-N). Do not renumber."))
        self.assertIn("**Source:** (unknown)", text)

    def test_append_local_entry_appends(self):
        issues = self.root / "ISSUES.md"
        s.append_local_entry(issues, "SB-I-1", self.candidate())
        first = issues.read_text()
        s.append_local_entry(issues, "SB-I-2", self.candidate(title="Second"))
        text = issues.read_text()
        self.assertTrue(text.startswith(first))
        self.assertIn("### SB-I-2 — Second", text)
        self.assertEqual(text.count("# Issues"), 1)

    def test_next_local_number(self):
        t = self.root / "x.md"
        self.assertEqual(s.next_local_number(t, "SB-I"), 1)
        t.write_text("no ids")
        self.assertEqual(s.next_local_number(t, "SB-I"), 1)
        t.write_text("SB-I-2 and SB-I-10 and SB-B-99 and SB-I-3")
        self.assertEqual(s.next_local_number(t, "SB-I"), 11)
        self.assertEqual(s.next_local_number(t, "SB-B"), 100)

    def test_issue_kind_and_labels(self):
        self.assertEqual(s.issue_kind(self.candidate(classification="bug")), "issue")
        self.assertEqual(s.issue_kind(self.candidate(classification="question")), "issue")
        self.assertEqual(s.issue_kind(self.candidate(classification="docs")), "backlog")
        expected = {"bug": "bug", "question": "question", "enhancement": "enhancement", "tech debt": "tech-debt",
                    "chore": "chore", "docs": "documentation", "weird": "chore"}
        for cat, label in expected.items():
            self.assertEqual(s.issue_labels(cat), ["filed-by-silver-bullet", label])

    def test_file_local_candidate_numbers_sequentially_and_updates_state(self):
        state = {}
        r1 = s.file_local_candidate(self.root, self.candidate(), state)
        r2 = s.file_local_candidate(self.root, self.candidate(candidate_id="cid2", fingerprint="fp2"), state)
        r3 = s.file_local_candidate(self.root, self.candidate(classification="docs", candidate_id="cid3", fingerprint="fp3"), state)
        self.assertEqual((r1["filed_ref"], r2["filed_ref"], r3["filed_ref"]), ("SB-I-1", "SB-I-2", "SB-B-1"))
        self.assertEqual(r1["target_file"], "docs/issues/ISSUES.md")
        self.assertEqual(r3["target_file"], "docs/issues/BACKLOG.md")
        self.assertEqual((r1["candidate"]["status"], r1["candidate"]["filed_ref"]), ("filed", "SB-I-1"))
        self.assertEqual(state["fingerprints"]["fp1"]["status"], "filed")
        self.assertEqual(state["fingerprints"]["fp1"]["filed_ref"], "SB-I-1")
        self.assertEqual(state["candidates_by_id"]["cid3"]["filed_ref"], "SB-B-1")

    def test_update_state_for_candidate(self):
        state = {}
        c = self.candidate()
        del c["category"]
        s.update_state_for_candidate(state, c, "seen")
        self.assertEqual(state["fingerprints"]["fp1"], {
            "candidate_id": "cid1", "kind": "deferred", "classification": "bug", "category": "bug", "confidence": "high",
            "status": "seen", "updated_at": "2030-01-01T00:00:00+00:00", "filed_ref": None,
            "source_refs": [{"path": "docs/sessions/s.md", "line": 3}],
        })
        by_id = state["candidates_by_id"]["cid1"]
        self.assertEqual((by_id["fingerprint"], by_id["title"], by_id["context"], by_id["source_kind"], by_id["status"]),
                         ("fp1", "Fix it", "Fix it now", "markdown-session", "seen"))
        c2 = self.candidate(candidate_id="c2", fingerprint="f2")
        del c2["source_refs"]
        s.update_state_for_candidate(state, c2, "filed", "REF")
        self.assertEqual(state["fingerprints"]["f2"]["source_refs"], [])
        self.assertEqual(state["fingerprints"]["f2"]["filed_ref"], "REF")

    def test_candidate_seen(self):
        c = self.candidate()
        self.assertFalse(s.candidate_seen({}, c))
        for status in ("seen", "filed", "recorded", "rejected", "tracked", "weakly-tracked"):
            self.assertTrue(s.candidate_seen({"fingerprints": {"fp1": {"status": status}}}, c), status)
        self.assertFalse(s.candidate_seen({"fingerprints": {"fp1": {"status": "pending"}}}, c))
        self.assertFalse(s.candidate_seen({"fingerprints": {"fp1": "seen"}}, c))


class RecordTest(Base):
    def test_record_target_month_file(self):
        self.assertEqual(s.record_target_month_file(self.root, self.candidate(classification="knowledge")), (self.root / "docs/knowledge/2030-01.md", True))
        self.assertEqual(s.record_target_month_file(self.root, self.candidate(classification="learning")), (self.root / "docs/learnings/2030-01.md", False))

    def test_learning_category(self):
        cases = {
            "use jq in bash": "stack:bash",
            "git hygiene": "stack:bash",
            "run the tests first": "practice:workflow",
            "release process": "practice:workflow",
            "deploy to cloud": "devops:operations",
            "monitor the iam roles": "devops:operations",
            "improve ux layout": "design:ux",
            "accessibility matters": "design:ux",
            "completely unrelated": "practice:workflow",
        }
        for text, expected in cases.items():
            self.assertEqual(s.learning_category(text), expected, text)

    def test_ensure_knowledge_index_created_and_updated(self):
        s.ensure_knowledge_index(self.root, "2030-01", "knowledge")
        index = (self.root / "docs/knowledge/INDEX.md").read_text()
        self.assertIn("# Project Knowledge Index", index)
        self.assertIn("| 2030-01 | [`2030-01.md`](../knowledge/2030-01.md) | Knowledge for this month |\n", index)
        self.assertIn("Latest knowledge: `docs/knowledge/2030-01.md`\n", index)
        self.assertIn("Latest learnings: `(none)`", index)
        s.ensure_knowledge_index(self.root, "2030-01", "knowledge")
        self.assertEqual((self.root / "docs/knowledge/INDEX.md").read_text().count("| 2030-01 |"), 1)
        s.ensure_knowledge_index(self.root, "2030-02", "knowledge")
        index = (self.root / "docs/knowledge/INDEX.md").read_text()
        self.assertEqual(index.count("| 2030-0"), 2)
        self.assertIn("Latest knowledge: `docs/knowledge/2030-02.md`", index)
        s.ensure_knowledge_index(self.root, "2030-02", "learnings")
        index = (self.root / "docs/knowledge/INDEX.md").read_text()
        self.assertIn("Latest learnings: `docs/learnings/2030-02.md`", index)
        self.assertIn("Latest knowledge: `docs/knowledge/2030-02.md`", index)

    def test_ensure_knowledge_index_adds_trailing_newline(self):
        idx = self.root / "docs/knowledge/INDEX.md"
        idx.parent.mkdir(parents=True)
        idx.write_text("Latest learnings: x")
        s.ensure_knowledge_index(self.root, "2030-01", "learnings")
        self.assertEqual(idx.read_text(), "Latest learnings: `docs/learnings/2030-01.md`\n")

    def test_record_knowledge_creates_file_and_files_by_topic(self):
        cases = [
            ("An open question about the API", "## Open Questions"),
            ("We made a decision because speed", "## Key Decisions"),
            ("A repeated pattern appears", "## Recurring Patterns"),
            ("You must avoid this gotcha", "## Known Gotchas"),
            ("Layers are separated", "## Architecture Patterns"),
        ]
        state = {}
        for idx, (context, heading) in enumerate(cases):
            cand = self.candidate(classification="knowledge", kind="knowledge", candidate_id=f"k{idx}", fingerprint=f"f{idx}", context=context)
            res = s.record_candidate(self.root, cand, state)
            self.assertEqual(res["target_file"], "docs/knowledge/2030-01.md")
            text = (self.root / "docs/knowledge/2030-01.md").read_text()
            section = text.split(heading, 1)[1].split("\n## ", 1)[0]
            self.assertIn(f"2030-01-01 - {context} [candidate-id:k{idx}]", section, heading)
        text = (self.root / "docs/knowledge/2030-01.md").read_text()
        self.assertTrue(text.startswith("---\nproject: unknown\nperiod: 2030-01\ntype: knowledge\n---\n\n# Project Knowledge - 2030-01\n"))
        self.assertTrue(text.endswith("\n"))
        self.assertEqual(state["fingerprints"]["f0"]["status"], "recorded")
        self.assertEqual(state["fingerprints"]["f0"]["filed_ref"], "docs/knowledge/2030-01.md")
        self.assertTrue((self.root / "docs/knowledge/INDEX.md").is_file())

    def test_record_knowledge_uses_project_name_and_newest_first(self):
        (self.root / ".silver-bullet.json").write_text('{"project": {"name": "Acme"}}')
        s.record_candidate(self.root, self.candidate(classification="knowledge", candidate_id="a", fingerprint="fa", context="first"), {})
        s.record_candidate(self.root, self.candidate(classification="knowledge", candidate_id="b", fingerprint="fb", context="second"), {})
        text = (self.root / "docs/knowledge/2030-01.md").read_text()
        self.assertIn("project: Acme", text)
        self.assertLess(text.index("second"), text.index("first"))

    def test_record_knowledge_appends_missing_heading(self):
        target = self.root / "docs/knowledge/2030-01.md"
        target.parent.mkdir(parents=True)
        target.write_text("# Custom file\n\nbody")
        s.record_candidate(self.root, self.candidate(classification="knowledge", context="a decision was made"), {})
        text = target.read_text()
        self.assertTrue(text.startswith("# Custom file\n\nbody\n\n## Key Decisions\n\n2030-01-01 - a decision was made [candidate-id:cid1]\n"))

    def test_record_learning(self):
        state = {}
        cand = self.candidate(classification="learning", kind="knowledge", context="use jq for json", candidate_id="l1", fingerprint="fl1")
        res = s.record_candidate(self.root, cand, state)
        self.assertEqual(res["filed_ref"], "docs/learnings/2030-01.md")
        text = (self.root / "docs/learnings/2030-01.md").read_text()
        self.assertTrue(text.startswith("---\nperiod: 2030-01\ntype: learnings\ncategories: []\n---\n\n# Learnings - 2030-01\n"))
        self.assertIn("## stack:bash\n\n2030-01-01 - use jq for json [candidate-id:l1]\n", text)
        s.record_candidate(self.root, self.candidate(classification="learning", context="bash again", candidate_id="l2", fingerprint="fl2"), state)
        text = (self.root / "docs/learnings/2030-01.md").read_text()
        self.assertLess(text.index("bash again"), text.index("use jq for json"))
        self.assertEqual(text.count("## stack:bash"), 1)
        self.assertIn("Latest learnings: `docs/learnings/2030-01.md`", (self.root / "docs/knowledge/INDEX.md").read_text())

    def test_record_learning_appends_missing_heading(self):
        target = self.root / "docs/learnings/2030-01.md"
        target.parent.mkdir(parents=True)
        target.write_text("# Learnings\n")
        s.record_candidate(self.root, self.candidate(classification="learning", context="deploy carefully"), {})
        self.assertIn("\n\n## devops:operations\n\n2030-01-01 - deploy carefully [candidate-id:cid1]\n", target.read_text())

    def test_entry_is_not_lost_when_heading_text_only_appears_inside_a_line(self):
        target = self.root / "docs/knowledge/2030-01.md"
        target.parent.mkdir(parents=True)
        target.write_text("# Notes\nsee the ## Key Decisions section later\n")
        s.record_candidate(self.root, self.candidate(classification="knowledge", context="a decision was made"), {})
        self.assertIn("[candidate-id:cid1]", target.read_text())
        lt = self.root / "docs/learnings/2030-01.md"
        lt.parent.mkdir(parents=True)
        lt.write_text("# Notes\nsee ## stack:bash somewhere\n")
        s.record_candidate(self.root, self.candidate(classification="learning", context="bash tip", candidate_id="c2", fingerprint="f2"), {})
        self.assertIn("[candidate-id:c2]", lt.read_text())

    def seed(self, rel, text):
        target = self.root / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8")
        return target

    def test_existing_knowledge_heading_gets_entry_directly_under_it(self):
        target = self.seed("docs/knowledge/2030-01.md", "# T\n\n## Key Decisions\n\nold decision\n\n## Open Questions\n\nold q\n")
        s.record_candidate(self.root, self.candidate(classification="knowledge", kind="knowledge", context="a decision was made"), {})
        self.assertEqual(
            target.read_text(),
            "# T\n\n## Key Decisions\n\n2030-01-01 - a decision was made [candidate-id:cid1]\n\nold decision\n\n## Open Questions\n\nold q\n",
        )

    def test_existing_knowledge_heading_newest_entry_first_with_blank_lines(self):
        target = self.seed("docs/knowledge/2030-01.md", "## Key Decisions\n")
        s.record_candidate(self.root, self.candidate(classification="knowledge", kind="knowledge", candidate_id="a", fingerprint="fa", context="first decision"), {})
        s.record_candidate(self.root, self.candidate(classification="knowledge", kind="knowledge", candidate_id="b", fingerprint="fb", context="second decision"), {})
        self.assertEqual(
            target.read_text(),
            "## Key Decisions\n\n2030-01-01 - second decision [candidate-id:b]\n\n2030-01-01 - first decision [candidate-id:a]\n",
        )

    def test_existing_knowledge_heading_at_end_of_file_without_newline(self):
        target = self.seed("docs/knowledge/2030-01.md", "# T\n\n## Key Decisions")
        s.record_candidate(self.root, self.candidate(classification="knowledge", kind="knowledge", context="a decision was made"), {})
        self.assertEqual(target.read_text(), "# T\n\n## Key Decisions\n\n2030-01-01 - a decision was made [candidate-id:cid1]\n")

    def test_existing_knowledge_heading_trailing_blank_lines_collapse_to_one_newline(self):
        target = self.seed("docs/knowledge/2030-01.md", "## Key Decisions  \n\n\n\n")
        s.record_candidate(self.root, self.candidate(classification="knowledge", kind="knowledge", context="a decision was made"), {})
        self.assertEqual(target.read_text(), "## Key Decisions  \n\n2030-01-01 - a decision was made [candidate-id:cid1]\n")

    def test_existing_learnings_heading_gets_entry_directly_under_it(self):
        target = self.seed("docs/learnings/2030-01.md", "# L\n\n## stack:bash\n\nold tip\n\n## practice:workflow\n\nold practice\n")
        s.record_candidate(self.root, self.candidate(classification="learning", kind="knowledge", context="use jq for json"), {})
        self.assertEqual(
            target.read_text(),
            "# L\n\n## stack:bash\n\n2030-01-01 - use jq for json [candidate-id:cid1]\n\nold tip\n\n## practice:workflow\n\nold practice\n",
        )

    def test_existing_learnings_heading_at_end_of_file_without_newline(self):
        target = self.seed("docs/learnings/2030-01.md", "## stack:bash\n\n\n")
        s.record_candidate(self.root, self.candidate(classification="learning", kind="knowledge", context="use jq for json"), {})
        self.assertEqual(target.read_text(), "## stack:bash\n\n2030-01-01 - use jq for json [candidate-id:cid1]\n")

    def test_knowledge_heading_chosen_by_each_keyword(self):
        cases = [
            ("question", "An unanswered question remains", "## Open Questions"),
            ("open question", "open question about retries", "## Open Questions"),
            ("pattern", "A pattern emerges in loaders", "## Recurring Patterns"),
            ("repeated", "Repeated work in the loaders", "## Recurring Patterns"),
            ("gotcha", "Watch this gotcha in loaders", "## Known Gotchas"),
            ("avoid", "Avoid shelling out in loaders", "## Known Gotchas"),
            ("must", "Loaders must close files", "## Known Gotchas"),
            ("decision", "A decision on loaders", "## Key Decisions"),
            ("because", "Loaders are lazy because speed", "## Key Decisions"),
            ("choose", "We choose lazy loaders", "## Key Decisions"),
            ("none", "Layers are separated", "## Architecture Patterns"),
        ]
        all_headings = {"## Open Questions", "## Recurring Patterns", "## Known Gotchas", "## Key Decisions", "## Architecture Patterns"}
        for idx, (keyword, context, heading) in enumerate(cases):
            with self.subTest(keyword=keyword):
                target = self.root / "docs/knowledge/2030-01.md"
                if target.exists():
                    target.unlink()
                cand = self.candidate(classification="knowledge", kind="knowledge", candidate_id=f"k{idx}", fingerprint=f"f{idx}", context=context)
                s.record_candidate(self.root, cand, {})
                lines = target.read_text().splitlines()
                entry = f"2030-01-01 - {context} [candidate-id:k{idx}]"
                at = lines.index(entry)
                # the entry sits directly under its heading (one blank line between)
                self.assertEqual((lines[at - 2], lines[at - 1]), (heading, ""))
                self.assertEqual(lines.count(entry), 1)
                self.assertTrue(all_headings.issuperset({h for h in lines if h.startswith("## ")}))

    def test_reject_candidate(self):
        state = {}
        res = s.reject_candidate(self.candidate(), state)
        self.assertEqual((res["candidate"]["status"], res["filed_ref"], res["target_file"]), ("rejected", "", ""))
        self.assertEqual(state["fingerprints"]["fp1"]["status"], "rejected")


class ReconstructAndHandleTest(Base):
    def state_with(self, **kw):
        c = self.candidate(**kw)
        state = {}
        s.update_state_for_candidate(state, c, "seen")
        return state, c

    def test_reconstruct_from_candidates_by_id(self):
        state, c = self.state_with()
        got = s.reconstruct_candidate(state, "cid1")
        self.assertEqual((got["candidate_id"], got["fingerprint"], got["kind"], got["classification"], got["category"]), ("cid1", "fp1", "deferred", "bug", "bug"))
        self.assertEqual((got["title"], got["context"], got["source_kind"], got["status"], got["confidence"]), ("Fix it", "Fix it now", "markdown-session", "seen", "high"))
        self.assertEqual((got["source_path"], got["source_line"], got["source_refs"]), ("docs/sessions/s.md", 3, c["source_refs"]))

    def test_reconstruct_by_id_defaults(self):
        got = s.reconstruct_candidate({"candidates_by_id": {"x": {}}}, "x")
        self.assertEqual((got["fingerprint"], got["kind"], got["classification"], got["category"], got["confidence"]), ("", "deferred", "chore", "chore", "medium"))
        self.assertEqual((got["routing_target"], got["title"], got["context"], got["source_kind"]), ("backlog", "session candidate", "", "unknown"))
        self.assertEqual((got["source_path"], got["source_line"], got["source_refs"], got["status"]), ("", 0, [], "pending"))

    def test_reconstruct_falls_back_to_fingerprint_records(self):
        state = {"fingerprints": {
            "other": {"candidate_id": "zzz"}, "garbage": "str",
            "fpX": {"candidate_id": "cidX", "classification": "question", "source_refs": [{"path": "p.md", "line": 4}], "title": "T", "context": "C",
                    "status": "seen", "source_kind": "sk", "kind": "knowledge", "confidence": "high", "category": "cat"},
        }}
        got = s.reconstruct_candidate(state, "cidX")
        self.assertEqual((got["fingerprint"], got["kind"], got["classification"], got["category"], got["routing_target"]), ("fpX", "knowledge", "question", "cat", "issue"))
        self.assertEqual((got["title"], got["context"], got["source_path"], got["source_line"], got["source_kind"], got["status"]), ("T", "C", "p.md", 4, "sk", "seen"))
        bare = s.reconstruct_candidate({"fingerprints": {"f": {"candidate_id": "c"}}}, "c")
        self.assertEqual((bare["classification"], bare["routing_target"], bare["title"], bare["source_refs"], bare["source_line"], bare["status"]), ("chore", "backlog", "session candidate", [], 0, "pending"))

    def test_reconstruct_unknown_candidate_raises_key_error(self):
        for state in ({}, {"candidates_by_id": {}, "fingerprints": {}}, {"candidates_by_id": {"cid1": "junk"}}):
            with self.assertRaises(KeyError) as cm:
                s.reconstruct_candidate(state, "nope")
            self.assertEqual(cm.exception.args[0], "nope")

    def test_handle_record_reject_and_knowledge_file(self):
        state, _ = self.state_with(kind="knowledge", classification="learning", context="use jq")
        res = s.handle_record(self.root, state, "cid1")
        self.assertEqual(res["candidate"]["status"], "recorded")
        state2, _ = self.state_with()
        res = s.handle_reject(state2, "cid1")
        self.assertEqual(res["candidate"]["status"], "rejected")
        state3, _ = self.state_with(kind="knowledge", classification="learning", context="deploy tip")
        res = s.handle_file(self.root, {}, state3, "cid1")
        self.assertEqual(res["candidate"]["status"], "recorded")
        for fn, args in ((s.handle_record, (self.root, {}, "nope")), (s.handle_reject, ({}, "nope")), (s.handle_file, (self.root, {}, {}, "nope"))):
            with self.assertRaises(KeyError):
                fn(*args)

    def test_handle_file_local_tracker(self):
        state, _ = self.state_with()
        res = s.handle_file(self.root, {"issue_tracker": "local"}, state, "cid1")
        self.assertEqual((res["filed_ref"], res["target_file"]), ("SB-I-1", "docs/issues/ISSUES.md"))

    def test_handle_file_github(self):
        state, c = self.state_with()
        cfg = {"issue_tracker": "github"}
        with mock.patch.object(s, "github_available", return_value=False):
            with self.assertRaisesRegex(RuntimeError, "gh CLI is not available"):
                s.handle_file(self.root, cfg, state, "cid1")
        with mock.patch.object(s, "github_available", return_value=True), \
             mock.patch.object(s, "repo_slug_from_origin", return_value="acme/repo"):
            with mock.patch.object(s, "run_command", return_value=cp(1, "", " boom \n")):
                with self.assertRaisesRegex(RuntimeError, "^boom$"):
                    s.handle_file(self.root, cfg, state, "cid1")
            with mock.patch.object(s, "run_command", return_value=cp(1, "", "")):
                with self.assertRaisesRegex(RuntimeError, "gh issue create failed"):
                    s.handle_file(self.root, cfg, state, "cid1")
            out = "Creating issue...\nhttps://github.com/acme/repo/issues/42\n"
            with mock.patch.object(s, "run_command", return_value=cp(0, out)) as run:
                res = s.handle_file(self.root, cfg, state, "cid1")
            args = run.call_args.args[0]
            self.assertEqual(args[:5], ["gh", "issue", "create", "--repo", "acme/repo"])
            self.assertEqual(args[args.index("--title") + 1], "Fix it")
            self.assertIn("## Description\nFix it now", args[args.index("--body") + 1])
            self.assertEqual([args[i + 1] for i, a in enumerate(args) if a == "--label"], ["filed-by-silver-bullet", "bug"])
            self.assertEqual(run.call_args.kwargs["cwd"], self.root)
            self.assertEqual((res["filed_ref"], res["target_file"]), ("https://github.com/acme/repo/issues/42", "https://github.com/acme/repo/issues/42"))
            self.assertEqual(res["candidate"]["status"], "filed")
            self.assertEqual(state["fingerprints"]["fp1"]["filed_ref"], "https://github.com/acme/repo/issues/42")
            with mock.patch.object(s, "run_command", return_value=cp(0, "created: ok\nfinal line\n")):
                res = s.handle_file(self.root, cfg, state, "cid1")
            self.assertEqual(res["filed_ref"], "final line")

    def test_handle_file_github_empty_output_is_a_clear_error(self):
        state, _ = self.state_with()
        with mock.patch.object(s, "github_available", return_value=True), \
             mock.patch.object(s, "repo_slug_from_origin", return_value="acme/repo"):
            for out in ("", "  \n"):
                with mock.patch.object(s, "run_command", return_value=cp(0, out)):
                    with self.assertRaisesRegex(RuntimeError, "gh issue create returned no output"):
                        s.handle_file(self.root, {"issue_tracker": "github"}, state, "cid1")
        self.assertEqual(state["fingerprints"]["fp1"]["status"], "seen")

    def test_github_body(self):
        (self.root / ".silver-bullet.json").write_text('{"issue_tracker": "github"}')
        body = s.github_body(self.candidate(), self.root)
        self.assertIn("- docs/sessions/s.md:3", body)
        self.assertIn("- Tracker: github", body)
        self.assertIn("- Filed: 2030-01-01", body)
        self.assertTrue(body.endswith("Captured by sb:scan from untrusted session content."))
        body = s.github_body(self.candidate(source_refs=[]), self.tmp)
        self.assertIn("## Source\n- (unknown)\n", body)
        self.assertIn("- Tracker: github", body)

    def test_should_autofile(self):
        self.assertFalse(s.should_autofile(self.candidate(), "interactive"))
        self.assertTrue(s.should_autofile(self.candidate(kind="knowledge", confidence="low"), "autonomous"))
        self.assertTrue(s.should_autofile(self.candidate(confidence="high"), "autonomous"))
        self.assertFalse(s.should_autofile(self.candidate(confidence="medium"), "autonomous"))


class ScanFlowTest(Base):
    def setUp(self):
        super().setUp()
        self.write("docs/sessions/a.md", "## Needs Human Review\n- Fix the failing test in hooks/foo.sh\n- Document the flag in README\n")
        git = mock.patch.object(s, "git_or_changelog_match", return_value=False)
        git.start()
        self.addCleanup(git.stop)
        env = mock.patch.dict(os.environ, {"CODEX_HOME": str(self.tmp / "nohome"), "HOME": str(self.tmp / "nohome")})
        env.start()
        self.addCleanup(env.stop)
        home = mock.patch.object(Path, "home", return_value=self.tmp / "nohome")
        home.start()
        self.addCleanup(home.stop)

    def scan(self, mode="interactive", config=None, state=None):
        state = state if state is not None else s.load_state(self.root)
        return s.handle_scan(self.root, config or {}, state, mode, "codex"), state

    def test_preflight(self):
        res = s.handle_preflight(self.root, "codex")
        self.assertEqual(res["mode"], "preflight")
        self.assertEqual(res["candidates"], [])
        self.assertEqual(res["sources"], [{"kind": "markdown-session", "path": "docs/sessions/a.md", "source_state": "unknown"}])
        self.assertEqual(res["preflight"]["matched_count"], 1)
        with mock.patch.object(s, "discover_sources", return_value=([{"kind": "k", "path": self.root / "x"}], {})):
            self.assertEqual(s.handle_preflight(self.root, "auto")["sources"][0]["source_state"], "unknown")

    def test_interactive_scan_collects_for_manual_review_and_is_incremental(self):
        res, state = self.scan()
        summary = res["summary"]
        self.assertEqual((summary["sessions_scanned"], summary["sessions_skipped_already_scanned"], summary["auto_filed"]), (1, 0, 0))
        self.assertEqual(summary["total_candidates"], len(res["candidates"]))
        self.assertEqual(summary["manual_review_count"], len(res["candidates"]))
        self.assertGreaterEqual(len(res["candidates"]), 2)
        self.assertEqual(res["state_path"], str(self.root / ".silver-bullet" / "scan-state.json"))
        self.assertEqual(res["sources"][0]["path"], "docs/sessions/a.md")
        self.assertEqual(set(res["sources"][0]), {"kind", "path", "hash", "mtime_ns"})
        self.assertTrue((self.root / ".silver-bullet" / "scan-state.json").is_file())
        self.assertEqual(state["fingerprints"][res["candidates"][0]["fingerprint"]]["status"], "seen")
        # second scan with the saved state skips the unchanged source
        res2, _ = self.scan()
        self.assertEqual((res2["summary"]["sessions_scanned"], res2["summary"]["sessions_skipped_already_scanned"], res2["candidates"]), (0, 1, []))

    def test_changed_source_is_rescanned_but_seen_candidates_are_filtered(self):
        res, _ = self.scan()
        n = len(res["candidates"])
        self.write("docs/sessions/a.md", "## Needs Human Review\n- Fix the failing test in hooks/foo.sh\n- Document the flag in README\n- Brand new follow up\n")
        res2, _ = self.scan()
        self.assertEqual(res2["summary"]["sessions_scanned"], 1)
        self.assertIn("Brand new follow up", [c["title"] for c in res2["candidates"]])
        self.assertTrue(all(c["title"] != "Document the flag in README" for c in res2["candidates"]))
        self.assertGreaterEqual(res2["summary"]["duplicates_filtered"], n)

    def test_tracked_candidates_are_filtered(self):
        self.write("docs/issues/ISSUES.md", "- fix the failing test in hooks/foo.sh\n- document the flag in readme\n")
        res, _ = self.scan()
        titles = [c["title"] for c in res["candidates"]]
        self.assertNotIn("Fix the failing test in hooks/foo.sh", titles)
        self.assertGreaterEqual(res["summary"]["duplicates_filtered"], 2)

    def test_fingerprint_duplicates_across_sources_are_filtered_once(self):
        self.write("docs/sessions/a.md", "## Needs Human Review\n- Parser crash on empty input\n")
        self.write("docs/sessions/b.md", "## Needs Human Review\n- Parser crash on empty input\n")
        res, _ = self.scan()
        self.assertEqual([c["title"] for c in res["candidates"]], ["Parser crash on empty input"])
        self.assertEqual(res["summary"]["sessions_scanned"], 2)
        self.assertEqual(res["summary"]["duplicates_filtered"], 1)

    def test_autonomous_files_high_confidence_and_knowledge(self):
        self.write("docs/sessions/a.md", "\n".join([
            "## Needs Human Review",
            "- Parser crash on empty input",
            "- Rename the helper files",
            "## Knowledge & Learnings Additions",
            "- Prefer small commits",
            "",
        ]))
        res, state = self.scan("autonomous")
        summary = res["summary"]
        by_title = {c["title"]: c for c in res["candidates"]}
        self.assertEqual(by_title["Parser crash on empty input"]["status"], "filed")
        self.assertEqual(by_title["Parser crash on empty input"]["filed_ref"], "SB-I-1")
        self.assertEqual(by_title["Prefer small commits"]["status"], "recorded")
        self.assertEqual(by_title["Rename the helper files"]["status"], "pending")
        self.assertEqual((summary["issues_filed"], summary["knowledge_recorded"], summary["local_backlog_filed"], summary["manual_review_count"]), (1, 1, 0, 1))
        self.assertEqual(summary["auto_filed"], 2)
        self.assertTrue((self.root / "docs/issues/ISSUES.md").is_file())
        self.assertTrue((self.root / "docs/learnings/2030-01.md").is_file())

    def test_autonomous_local_backlog_branch(self):
        self.write("docs/sessions/a.md", "## Needs Human Review\n- Rename the helper files\n")
        with mock.patch.object(s, "should_autofile", return_value=True):
            res, _ = self.scan("autonomous")
        self.assertEqual((res["summary"]["local_backlog_filed"], res["summary"]["issues_filed"]), (1, 0))
        self.assertEqual(res["candidates"][0]["filed_ref"], "SB-B-1")

    def test_autonomous_github_branch(self):
        self.write("docs/sessions/a.md", "## Needs Human Review\n- Parser crash on empty input\n")
        with mock.patch.object(s, "github_issue_exists", return_value=False), \
             mock.patch.object(s, "github_available", return_value=True), \
             mock.patch.object(s, "repo_slug_from_origin", return_value="acme/repo"), \
             mock.patch.object(s, "run_command", return_value=cp(0, "https://github.com/acme/repo/issues/7\n")):
            res, _ = self.scan("autonomous", config={"issue_tracker": "github"})
        self.assertEqual((res["summary"]["issues_filed"], res["summary"]["auto_filed"]), (1, 1))
        self.assertEqual(res["candidates"][0]["filed_ref"], "https://github.com/acme/repo/issues/7")

    def test_autonomous_filing_failure_leaves_candidate_pending(self):
        self.write("docs/sessions/a.md", "## Needs Human Review\n- Parser crash on empty input\n")
        with mock.patch.object(s, "github_issue_exists", return_value=False), \
             mock.patch.object(s, "github_available", return_value=False):
            res, _ = self.scan("autonomous", config={"issue_tracker": "github"})
        self.assertEqual(res["summary"]["auto_filed"], 0)
        self.assertEqual(res["summary"]["manual_review_count"], 0)
        self.assertEqual([(c["title"], c["status"]) for c in res["candidates"]], [("Parser crash on empty input", "pending")])

    def test_duplicates_filtered_counts_already_seen_candidates_exactly(self):
        self.write("docs/sessions/a.md", "## Needs Human Review\n- Parser crash on empty input\n- Rename the helper files\n")
        res, _ = self.scan()
        self.assertEqual((res["summary"]["duplicates_filtered"], len(res["candidates"])), (0, 2))
        self.write("docs/sessions/a.md", "## Needs Human Review\n- Parser crash on empty input\n- Rename the helper files\n- Rename the cache files\n")
        res2, _ = self.scan()
        self.assertEqual([c["title"] for c in res2["candidates"]], ["Rename the cache files"])
        self.assertEqual(res2["summary"]["duplicates_filtered"], 2)

    def test_duplicates_filtered_counts_cross_source_duplicates_exactly(self):
        for name in ("a", "b", "c"):
            self.write(f"docs/sessions/{name}.md", "## Needs Human Review\n- Parser crash on empty input\n")
        res, _ = self.scan()
        self.assertEqual([c["title"] for c in res["candidates"]], ["Parser crash on empty input"])
        self.assertEqual((res["summary"]["sessions_scanned"], res["summary"]["duplicates_filtered"]), (3, 2))

    def test_duplicates_filtered_counts_tracked_candidates_exactly(self):
        self.write("docs/sessions/a.md", "## Needs Human Review\n- Parser crash on empty input\n- Rename the helper files\n")
        self.write("docs/issues/ISSUES.md", "- parser crash on empty input\n")
        res, _ = self.scan()
        self.assertEqual([c["title"] for c in res["candidates"]], ["Rename the helper files"])
        self.assertEqual(res["summary"]["duplicates_filtered"], 1)

    def test_failed_filing_is_not_recorded_as_seen_and_is_retried_on_next_scan(self):
        self.write("docs/sessions/a.md", "## Needs Human Review\n- Parser crash on empty input\n")
        cfg = {"issue_tracker": "github"}
        with mock.patch.object(s, "github_issue_exists", return_value=False), mock.patch.object(s, "github_available", return_value=False):
            res, state = self.scan("autonomous", config=cfg)
        self.assertEqual([(c["title"], c["status"]) for c in res["candidates"]], [("Parser crash on empty input", "pending")])
        saved = s.load_state(self.root)
        self.assertEqual(saved.get("fingerprints", {}), {})
        self.assertEqual(saved.get("candidates_by_id", {}), {})
        self.assertNotIn("docs/sessions/a.md", saved.get("sources", {}))
        # the next scan (state reloaded from disk) surfaces the candidate again and files it once gh works
        with mock.patch.object(s, "github_issue_exists", return_value=False), \
             mock.patch.object(s, "github_available", return_value=True), \
             mock.patch.object(s, "repo_slug_from_origin", return_value="acme/repo"), \
             mock.patch.object(s, "run_command", return_value=cp(0, "https://github.com/acme/repo/issues/9\n")):
            res2, _ = self.scan("autonomous", config=cfg, state=saved)
        self.assertEqual((res2["summary"]["sessions_scanned"], res2["summary"]["issues_filed"], res2["summary"]["duplicates_filtered"]), (1, 1, 0))
        self.assertEqual([(c["title"], c["status"], c["filed_ref"]) for c in res2["candidates"]], [("Parser crash on empty input", "filed", "https://github.com/acme/repo/issues/9")])
        self.assertEqual(next(iter(s.load_state(self.root)["fingerprints"].values()))["status"], "filed")

    def test_failed_filing_keeps_previous_source_record_and_other_candidates(self):
        self.write("docs/sessions/a.md", "## Needs Human Review\n- Rename the helper files\n")
        res, _ = self.scan()
        old_source = dict(s.load_state(self.root)["sources"]["docs/sessions/a.md"])
        self.write("docs/sessions/a.md", "## Needs Human Review\n- Rename the helper files\n- Parser crash on empty input\n")
        with mock.patch.object(s, "github_issue_exists", return_value=False), mock.patch.object(s, "github_available", return_value=False):
            res2, state = self.scan("autonomous", config={"issue_tracker": "github"})
        self.assertEqual(res2["summary"]["duplicates_filtered"], 1)
        self.assertEqual(state["sources"]["docs/sessions/a.md"], old_source)
        statuses = {rec["status"] for rec in state["fingerprints"].values()}
        self.assertEqual(statuses, {"seen"})  # the rename candidate stays seen; the failed bug was restored (absent)
        self.assertEqual(len(state["fingerprints"]), 1)


class GitChangelogRealRepoTest(Base):
    """git_or_changelog_match against a real git repository (the phrase is lower-cased by normalize_text)."""

    def setUp(self):
        super().setUp()
        env = mock.patch.dict(os.environ, {"GIT_CONFIG_GLOBAL": os.devnull, "GIT_CONFIG_NOSYSTEM": "1", "HOME": str(self.tmp)})
        env.start()
        self.addCleanup(env.stop)
        self.git("init", "-q")
        self.git("config", "gc.auto", "0")
        self.git("config", "maintenance.auto", "false")
        self.commit("Initial commit")

    def git(self, *args):
        subprocess.run(["git", *args], cwd=self.root, check=True, capture_output=True, text=True)

    def commit(self, subject):
        self.git("-c", "user.name=T", "-c", "user.email=t@example.invalid", "commit", "--allow-empty", "-q", "-m", subject)

    def test_mixed_case_commit_subject_matches(self):
        self.commit("Fix The Very Long Thing in Parser")
        c = self.candidate(title="Fix the very long thing now please")
        self.assertTrue(s.git_or_changelog_match(self.root, c))

    def test_mixed_case_changelog_line_matches(self):
        (self.root / "CHANGELOG.md").write_text("# Changelog\n- Fix The Very Long Thing\n", encoding="utf-8")
        c = self.candidate(title="Fix the very long thing now please")
        self.assertTrue(s.git_or_changelog_match(self.root, c))

    def test_changelog_with_doubled_spaces_and_line_wrap_matches(self):
        (self.root / "CHANGELOG.md").write_text("- Fix  the very\n  long   thing\n", encoding="utf-8")
        c = self.candidate(title="Fix the very long thing now please")
        self.assertTrue(s.git_or_changelog_match(self.root, c))

    def test_unrelated_title_does_not_match(self):
        self.commit("Bump dependencies")
        (self.root / "CHANGELOG.md").write_text("- Bump dependencies\n", encoding="utf-8")
        c = self.candidate(title="Fix the very long thing now please")
        self.assertFalse(s.git_or_changelog_match(self.root, c))


class CliTest(Base):
    def run_main(self, *argv, cwd=None):
        out = io.StringIO()
        with mock.patch.object(Path, "cwd", return_value=cwd or self.root), contextlib.redirect_stdout(out):
            rc = s.main(list(argv))
        return rc, out.getvalue()

    def test_parse_args(self):
        a = s.parse_args(["scan"])
        self.assertEqual((a.command, a.mode, a.format, a.agent_env, a.preflight), ("scan", "interactive", "text", "auto", False))
        a = s.parse_args(["scan", "--mode", "autonomous", "--format", "json", "--agent-env", "kay", "--preflight"])
        self.assertEqual((a.mode, a.format, a.agent_env, a.preflight), ("autonomous", "json", "kay", True))
        for cmd in ("file", "record", "reject"):
            a = s.parse_args([cmd, "--candidate-id", "x"])
            self.assertEqual((a.command, a.candidate_id, a.format), (cmd, "x", "json"))
        with contextlib.redirect_stderr(io.StringIO()):
            for bad in ([], ["file"], ["scan", "--mode", "bogus"]):
                with self.assertRaises(SystemExit):
                    s.parse_args(bad)

    def test_emit_json_and_text(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            s.emit_json({"b": 1, "a": 2})
        self.assertEqual(out.getvalue(), '{\n  "a": 2,\n  "b": 1\n}\n')
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            s.emit_text({"summary": {"sessions_scanned": 2, "total_candidates": 1}, "candidates": [{"status": "filed", "kind": "deferred", "classification": "bug", "title": "T"}, {}]})
        self.assertEqual(out.getvalue(), "\n".join([
            "silver-scan summary", "  sessions scanned: 2", "  sessions skipped: 0", "  candidates: 1",
            "  duplicates filtered: 0", "  auto filed: 0",
            "- [filed] deferred bug: T", "- [pending] None None: None", "",
        ]))
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            s.emit_text({})
        self.assertIn("  sessions scanned: 0", out.getvalue())

    def test_scan_text_and_json(self):
        self.write("docs/sessions/a.md", "## Needs Human Review\n- Fix the failing test in hooks/foo.sh\n")
        with mock.patch.object(s, "discover_sources", wraps=s.discover_sources), \
             mock.patch.object(s, "git_or_changelog_match", return_value=False), \
             mock.patch.dict(os.environ, {"CODEX_HOME": str(self.tmp / "nohome")}), \
             mock.patch.object(Path, "home", return_value=self.tmp / "nohome"):
            rc, out = self.run_main("scan")
            self.assertEqual(rc, 0)
            self.assertTrue(out.startswith("silver-scan summary\n  sessions scanned: 1\n"))
            self.assertIn("- [pending] deferred bug: Fix the failing test in hooks/foo.sh", out)
            rc, out = self.run_main("scan", "--format", "json", "--mode", "autonomous")
            self.assertEqual(rc, 0)
            data = json.loads(out)
            self.assertEqual((data["mode"], data["summary"]["sessions_skipped_already_scanned"]), ("autonomous", 1))
            rc, out = self.run_main("scan", "--preflight", "--format", "json")
            self.assertEqual(json.loads(out)["mode"], "preflight")

    def test_file_record_reject_flows_persist_state(self):
        state = {}
        learning = self.candidate(kind="knowledge", classification="learning", context="use jq", candidate_id="L", fingerprint="fl")
        bug = self.candidate(candidate_id="B", fingerprint="fb")
        rej = self.candidate(candidate_id="R", fingerprint="fr")
        for c in (learning, bug, rej):
            s.update_state_for_candidate(state, c, "seen")
        s.save_state(self.root, state)
        rc, out = self.run_main("record", "--candidate-id", "L")
        self.assertEqual((rc, json.loads(out)["candidate"]["status"]), (0, "recorded"))
        rc, out = self.run_main("file", "--candidate-id", "B")
        self.assertEqual((rc, json.loads(out)["filed_ref"]), (0, "SB-I-1"))
        rc, out = self.run_main("reject", "--candidate-id", "R", "--format", "text")
        self.assertEqual(rc, 0)
        self.assertIn("silver-scan summary", out)
        saved = s.load_state(self.root)
        self.assertEqual({k: saved["fingerprints"][k]["status"] for k in ("fl", "fb", "fr")}, {"fl": "recorded", "fb": "filed", "fr": "rejected"})

    def test_missing_candidate_reports_not_found(self):
        for cmd in ("file", "record", "reject"):
            rc, out = self.run_main(cmd, "--candidate-id", "ghost")
            self.assertEqual(rc, 1, cmd)
            self.assertEqual(json.loads(out), {"error": "candidate not found: ghost", "candidate": {"candidate_id": "ghost", "status": "missing"}})

    def test_other_errors_report_error_json(self):
        state = {}
        s.update_state_for_candidate(state, self.candidate(), "seen")
        s.save_state(self.root, state)
        (self.root / ".silver-bullet.json").write_text('{"issue_tracker": "github"}')
        with mock.patch.object(s, "github_available", return_value=False):
            rc, out = self.run_main("file", "--candidate-id", "cid1")
        self.assertEqual(rc, 1)
        self.assertEqual(json.loads(out), {"error": "gh CLI is not available", "candidate": {"candidate_id": "cid1", "status": "error"}})

    def test_unknown_command_reports_error(self):
        import argparse
        with mock.patch.object(s, "parse_args", return_value=argparse.Namespace(command="bogus")):
            rc, out = self.run_main("bogus")
        self.assertEqual(rc, 1)
        self.assertEqual(json.loads(out), {"error": "unknown command: bogus", "candidate": {"candidate_id": "", "status": "error"}})

    def test_project_root_is_found_from_a_subdirectory(self):
        (self.root / ".silver-bullet.json").write_text("{}")
        sub = self.root / "deep" / "dir"
        sub.mkdir(parents=True)
        with mock.patch.dict(os.environ, {"CODEX_HOME": str(self.tmp / "nohome")}), mock.patch.object(Path, "home", return_value=self.tmp / "nohome"):
            rc, out = self.run_main("scan", "--format", "json", cwd=sub)
        self.assertEqual(json.loads(out)["project_root"], str(self.root))

    def test_entrypoint(self):
        out = io.StringIO()
        with mock.patch("sys.argv", ["silver-scan", "reject", "--candidate-id", "ghost"]), \
             mock.patch.object(Path, "cwd", return_value=self.root), contextlib.redirect_stdout(out):
            with self.assertRaises(SystemExit) as cm:
                runpy.run_path(str(REPO_ROOT / "scripts" / "silver-scan.py"), run_name="__main__")
        self.assertEqual(cm.exception.code, 1)
        self.assertIn("candidate not found: ghost", out.getvalue())


if __name__ == "__main__":
    unittest.main()
