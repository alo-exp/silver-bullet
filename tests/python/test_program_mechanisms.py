"""The table of mechanisms that make git or git-lfs execute a program, diffed against the classifier.

tests/fixtures/push-scope/program-mechanisms.json lists every mechanism (config key, environment variable, attribute,
hook, remote helper, background task) with the git subcommands that trigger it, whether the push scope's allowlist can
reach it, and the verdict. This test fails when a reachable row has no strict verdict row in the push corpus, when a
key named in the table is not matched by the classifier's list, when the classifier's list has a key the table does
not mention, or when docs/ENFORCEMENT.md does not carry the table. Nothing is executed.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import unittest

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import push_corpus  # noqa: E402
import sbtest  # noqa: E402

push_scope = sbtest.load_module("hooks/lib/tool-input/push_scope.py", "push_scope")
FIXTURE = sbtest.REPO_ROOT / "tests" / "fixtures" / "push-scope" / "program-mechanisms.json"
DOC = sbtest.REPO_ROOT / "docs" / "ENFORCEMENT.md"
TABLE = json.loads(FIXTURE.read_text())
ROWS = TABLE["rows"]
CORPUS = {row["id"]: row for row in push_corpus.ROWS}
ENV_NAME = re.compile(r"^[A-Z][A-Z0-9_]*$")


def expand_listing(listing):
    """Keys of `git help -c` with every wildcard family expanded into its real subsection forms: `http.<url>.*` becomes
    http.<url>.<name> for every http.<name> the listing has (and the URL-shaped subsection variants), so a dangerous
    key is checked in the form git accepts it per URL, not only in its plain form."""
    raw = listing.split()
    plain = [key for key in raw if "*" not in key]
    out = list(plain)
    for key in raw:
        if "*" not in key:
            continue
        match = re.match(r"^([a-z0-9]+)\.(?:<[^>]+>\.)?\*$", key, re.I)
        if match is None:
            out.append(key)
            continue
        section = match.group(1)
        names = [k.split(".", 1)[1] for k in plain if k.lower().startswith(section.lower() + ".")
                 and k.count(".") == 1 and "<" not in k]
        placeholder = "<" in key
        for name in names:
            out.append("%s.%s.%s" % (section, "<sub>" if placeholder else "x", name) if placeholder else
                       "%s.%s" % (section, name))
            if placeholder:
                out.append("%s.https://example.com/.%s" % (section, name))
    return out


def reduced(key):
    """section.name for a key with a subsection (the form the reviewed lists are written in)."""
    parts = key.split(".")
    return key if len(parts) < 3 else "%s.%s" % (parts[0], parts[-1])


def top_level_alternatives(rx):
    """``^(a|b|c)$`` or ``^a$`` -> ['a', 'b', 'c'] split at the outermost alternation."""
    body = rx.pattern.lstrip("^").rstrip("$")
    if body.startswith("(") and body.endswith(")"):
        body = body[1:-1]
    out, depth, current = [], 0, ""
    for char in body:
        if char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
        if char == "|" and depth == 0:
            out.append(current)
            current = ""
        else:
            current += char
    return out + [current]


def expand(alternative):
    """Expand groups of plain words: ``core\\.(a|b)`` -> ``core\\.a``, ``core\\.b`` (other groups stay)."""
    match = re.search(r"\(([A-Za-z0-9_|]+)\)(?![?*+])", alternative)
    if match is None:
        return [alternative]
    out = []
    for option in match.group(1).split("|"):
        out += expand(alternative[:match.start()] + option + alternative[match.end():])
    return out


class ProgramMechanismTable(unittest.TestCase):
    def test_rows_are_well_formed(self):
        ids = [row["id"] for row in ROWS]
        self.assertEqual(len(ids), len(set(ids)))
        for row in ROWS:
            with self.subTest(row=row["id"]):
                self.assertIn(row["verdict"], ("strict", "not-reachable", "residual"))
                self.assertTrue(row["mechanism"] and row["triggers"] and row["keys"])
                if row["verdict"] == "not-reachable":
                    self.assertFalse(row["reachable"])
                    self.assertTrue(row["note"])
                if row["verdict"] == "residual":
                    self.assertTrue(row["residual"])

    def test_reachable_rows_have_strict_corpus_rows(self):
        for row in ROWS:
            if not (row["reachable"] and row["verdict"] == "strict"):
                continue
            with self.subTest(row=row["id"]):
                self.assertTrue(row["corpus_rows"], "a reachable mechanism needs a strict verdict row")
                for rid in row["corpus_rows"]:
                    self.assertIn(rid, CORPUS)
                    self.assertEqual(CORPUS[rid]["expect"], "C", rid)

    def test_table_keys_are_in_the_classifier(self):
        env_known = set(push_scope.ENV_DENY) | set(push_scope.ENV_BY_VALUE) | set(push_scope.ENV_WRITE_DENY)
        for row in ROWS:
            if row["verdict"] != "strict":
                continue
            for key in row["keys"]:
                with self.subTest(row=row["id"], key=key):
                    if ENV_NAME.match(key) and "." not in key:
                        self.assertIn(key, env_known)
                    elif row["pattern"] in push_scope.PROGRAM_KEY_PATTERNS:
                        self.assertTrue(push_scope.PROGRAM_KEY_PATTERNS[row["pattern"]].match(key))
                    else:
                        self.assertIn(row["pattern"], ("code", ""), row["id"])

    def test_classifier_keys_are_in_the_table(self):
        samples = {}
        for row in ROWS:
            samples.setdefault(row["pattern"], []).extend(row["keys"])
        for name, rx in push_scope.PROGRAM_KEY_PATTERNS.items():
            for alternative in (a for alt in top_level_alternatives(rx) for a in expand(alt)):
                with self.subTest(pattern=name, alternative=alternative):
                    self.assertTrue(any(re.fullmatch(alternative, key) for key in samples.get(name, [])),
                                    "the classifier lists %s but the table has no key for it" % alternative)
        table_env = {key for row in ROWS for key in row["keys"] if ENV_NAME.match(key) and "." not in key}
        for name in list(push_scope.ENV_DENY) + list(push_scope.ENV_BY_VALUE) + list(push_scope.ENV_WRITE_DENY):
            self.assertIn(name, table_env, name)

    def test_docs_carry_the_table(self):
        text = DOC.read_text()
        for row in ROWS:
            with self.subTest(row=row["id"]):
                self.assertIn("| %s | " % row["id"], text)
                verdict = row["verdict"] if not row["residual"] else "%s (%s)" % (row["verdict"], row["residual"])
                match = re.search(r"^\| %s \|.*$" % row["id"], text, re.M)
                self.assertIsNotNone(match)
                self.assertIn(verdict, match.group(0))


    def test_every_program_like_git_key_is_classified_or_reviewed(self):
        """`git help -c` keys that look like they name a program (hook, command, program, cmd, helper, exec, driver,
        filter, editor, pager, textconv, external, ...) must be matched by a classifier list or sit in the reviewed
        non-executing allowlist of the fixture, so a forgotten key fails here."""
        try:
            listing = subprocess.run(["git", "help", "-c"], capture_output=True, text=True, check=True).stdout
        except (OSError, subprocess.CalledProcessError):
            self.skipTest("git help -c is not available")
        words = re.compile(r"hook|command|program|cmd|helper|exec|driver|filter|editor|pager|textconv|external|tool|"
                           r"proxy|ssh|askpass|gpg|fsmonitor|sign", re.I)
        reviewed = TABLE["reviewed_non_executing"]
        patterns = list(push_scope.PROGRAM_KEY_PATTERNS.values()) + [push_scope.SIGN_CONFIG]
        unclassified = []
        for raw in expand_listing(listing):
            if not words.search(raw):
                continue
            key = re.sub(r"<[^>]+>", "x", raw).lower()
            if any(p.match(key) for p in patterns) or raw.lower() in reviewed or reduced(key) in reviewed \
                    or reduced(raw.lower()) in reviewed:
                continue
            parts = key.split(".")
            if parts[0] == "remote" and len(parts) == 3 and parts[2] not in push_scope.REMOTE_KEYS_OK:
                continue  # refused by the remote.<name>.* allowlist
            if key in ("push.gpgsign", "commit.gpgsign", "core.fsmonitor"):
                continue  # judged by value in code (git_bool)
            unclassified.append(raw)
        self.assertEqual(unclassified, [], "classify these keys or add them to reviewed_non_executing")

    def test_push_is_never_weaker_than_its_sequence(self):
        """Every strict mechanism the push itself triggers (push_triggers) has a plain `git push` verdict-only row in
        the corpus, so `git push` is as strict as `git status && git push` for it."""
        triggers = [r for r in ROWS if r["push_triggers"]]
        self.assertGreaterEqual(len(triggers), 15)
        for row in triggers:
            with self.subTest(row=row["id"]):
                self.assertEqual(row["verdict"], "strict")
                plain = [rid for rid in row["corpus_rows"]
                         if CORPUS[rid].get("verdict_only") and CORPUS[rid]["cmd"] == "git push"]
                self.assertTrue(plain, "no plain `git push` verdict row for this mechanism")

    def test_every_file_writing_git_key_is_classified_or_reviewed(self):
        """The same walk for mechanisms that WRITE a file at a user-chosen path (file, path, target, socket, trace,
        output, cookie, store, dir, save, write, dump, log, dest, cache): a classifier list or a reviewed rule."""
        try:
            listing = subprocess.run(["git", "help", "-c"], capture_output=True, text=True, check=True).stdout
        except (OSError, subprocess.CalledProcessError):
            self.skipTest("git help -c is not available")
        words = re.compile(r"file|path|target|socket|trace|output|cookie|store|dir|save|write|dump|log|dest|cache|sock",
                           re.I)
        rules = [re.compile(rx) for rx, _reason in TABLE["reviewed_not_writing"]]
        patterns = list(push_scope.PROGRAM_KEY_PATTERNS.values()) + [push_scope.SIGN_CONFIG, push_scope.WRITE_CONFIG]
        unclassified = []
        for raw in expand_listing(listing):
            if not words.search(raw):
                continue
            key = re.sub(r"<[^>]+>", "x", raw).lower()
            if any(p.match(key) for p in patterns) or any(r.fullmatch(key) or r.fullmatch(reduced(key)) for r in rules):
                continue
            unclassified.append(raw)
        self.assertEqual(unclassified, [], "classify these keys or add a reviewed_not_writing rule")
        for row in ROWS:
            self.assertIn("writes_file", row)
        self.assertTrue(any(r["writes_file"] for r in ROWS))
        for row in ROWS:
            if row["writes_file"]:
                self.assertEqual(row["verdict"], "strict", row["id"])

    def test_wildcard_families_are_expanded(self):
        keys = expand_listing("http.<url>.* http.cookieFile http.saveCookies alias.* credential.<url>.* credential.helper")
        self.assertIn("http.<sub>.saveCookies", keys)
        self.assertIn("http.https://example.com/.cookieFile", keys)
        self.assertIn("credential.<sub>.helper", keys)
        self.assertEqual(reduced("http.x.savecookies"), "http.savecookies")
        self.assertEqual(reduced("core.editor"), "core.editor")
        # the dangerous per-URL forms are matched by the classifier (the walk would fail otherwise)
        self.assertTrue(push_scope.WRITE_CONFIG.match("http.x.savecookies"))
        self.assertTrue(push_scope.WRITE_CONFIG.match("http.https://example.com/.savecookies"))

    def test_helpers(self):
        self.assertEqual(expand("a\\.(b|c)\\.d"), ["a\\.b\\.d", "a\\.c\\.d"])
        self.assertEqual(expand("x(.*\\.)?y"), ["x(.*\\.)?y"])
        self.assertEqual(top_level_alternatives(re.compile("^(a|b(c|d))$")), ["a", "b(c|d)"])
        self.assertEqual(top_level_alternatives(re.compile("^abc$")), ["abc"])


if __name__ == "__main__":
    unittest.main()
