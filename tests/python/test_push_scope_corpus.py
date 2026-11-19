"""Attack and honest corpus for the shell push scope, with real-repository ground truth (design 6.1-6.4).

Every row restores the sandbox, runs its setup, asks the analyzer for a verdict (in-process, through
``analyze_payload`` so the payload cwd/workdir rules are part of the test), then runs the command with bash and
compares the refs of the two bare remotes: an attack row must really have a protected effect, an honest row must
not. A vacuous corpus (an "attack" that does nothing) or a design hole (an "honest" row that moves main) fails here.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import push_corpus  # noqa: E402
import push_sandbox  # noqa: E402
import sbtest  # noqa: E402

shell_analysis = sbtest.load_module("hooks/lib/tool-input/shell_analysis.py", "sbtest_sa_corpus")


class CorpusTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.mkdtemp(prefix="pscope")
        cls.sb = push_sandbox.Sandbox(os.path.join(cls.tmp, "S"))

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp, ignore_errors=True)

    def sub(self, text):
        return text.replace("@S@", self.sb.root)

    def sh(self, script, cwd, env):
        return subprocess.run(["bash", "-c", script], cwd=cwd, env=env, capture_output=True, text=True,
                              check=False, timeout=60)

    def payload(self, rw, cwd):
        if rw.get("payload") == "codex":
            tool_input = {"cmd": rw["argv"], "workdir": cwd}
            return {"tool_name": "exec_command", "tool_input": tool_input}
        return {"tool_name": "Bash", "cwd": cwd, "tool_input": {"command": self.sub(rw["cmd"])}}

    def run_row(self, rw):
        sb = self.sb
        sb.restore()
        cwd = sb.p(rw.get("cwd", "w"))
        hook_cwd = sb.p(rw.get("hook_cwd", rw.get("cwd", "w")))
        env_extra = {k: self.sub(v) for k, v in rw.get("env", {}).items()}
        env = push_sandbox.git_env(sb.root, env_extra)
        verdict_env = push_sandbox.git_env(sb.root, env_extra, plain=True)
        if rw.get("nowt"):
            sb.g(sb.p("w"), "worktree", "remove", "--force", "../wt-main")
        if rw.get("setup"):
            done = self.sh(self.sub(rw["setup"]), cwd, env)
            self.assertEqual(done.returncode, 0, done.stderr)
        text = json.dumps(self.payload(rw, cwd))
        result = shell_analysis.analyze_payload(text, hook_cwd, True, verdict_env)
        scope = result.get("push_scope") or {"verdict": "strict", "reason": "no push scope in the analysis"}
        if rw.get("verdict_only"):
            return scope, None  # the table of program mechanisms: the verdict is asserted, nothing is executed
        before = sb.refs()
        if rw.get("payload") == "codex":
            subprocess.run(rw["argv"], cwd=cwd, env=env, capture_output=True, check=False, timeout=60)
        else:
            self.sh(self.sub(rw["cmd"]), cwd, env)
        return scope, push_sandbox.protected_effect(before, sb.refs())

    def test_corpus(self):
        seen = set()
        for rw in push_corpus.ROWS:
            self.assertNotIn(rw["id"], seen)
            seen.add(rw["id"])
            if rw.get("needs") and shutil.which(rw["needs"]) is None:
                continue
            with self.subTest(row=rw["id"], cmd=rw["cmd"] or rw.get("argv")):
                scope, effect = self.run_row(rw)
                if rw["expect"] == "I":
                    self.assertEqual(scope["verdict"], "feature", scope)
                else:
                    self.assertEqual(scope["verdict"], "strict", scope)
                    self.assertIn(rw["kw"].lower(), scope["reason"].lower(), scope)
                if rw.get("verdict_only"):
                    pass
                elif rw["gt"] == "P":
                    self.assertTrue(effect, "the attack row has no protected effect: the corpus is vacuous")
                elif rw["gt"] == "N":
                    self.assertFalse(effect, "the row moved a protected ref")


    def mcp_rows(self):
        base = {"owner": "acme", "repo": "app"}
        rows = [
            ("M1", "push_files", dict(base, branch="main"), "C"),
            ("M2", "push_files", dict(base, branch="feat/x"), "I"),
            ("M3", "push_files", {"owner": "other", "repo": "lib", "branch": "feat/x"}, "C"),
            ("M4", "push_files", {"owner": "other", "repo": "lib", "branch": "develop"}, "C"),
            ("M5", "create_or_update_file", {"owner": "ACME", "repo": "App", "branch": "feat/x"}, "I"),
            ("M6", "push_files", dict(base), "C"),
            ("M7", "push_files", dict(base, branch="refs/heads/main"), "C"),
            ("M8", "push_files", dict(base, branch="main "), "C"),
            ("M8b", "push_files", dict(base, branch=" main"), "C"),
            ("M9", "delete_file", dict(base, branch="HEAD"), "C"),
            ("M10", "create_branch", dict(base, branch="main", from_branch="feat/x"), "C"),
            ("M11", "create_branch", dict(base, branch="feat/new"), "I"),
            ("M12", "push_files", {"owner": "acme", "repo": "up", "branch": "develop"}, "C"),
            ("M13", "push_files", {"owner": "acme", "repo": "up", "branch": "feat/q"}, "I"),
            ("M14", "push_files", dict(base, repo="app.git", branch="feat/x"), "C"),
            ("M15", "push_files", dict(base, branch="feat/x"), "C", "plain"),
            ("M16", "push_files", dict(base, branch="feat/x"), "C", "nohead"),
            ("M17", "push_files", dict(base, owner=["acme"], branch="feat/x"), "C"),
            ("M18", "push_files", {"repository": "acme/app", "branch": "feat/x"}, "C"),
            ("M19a", "create_tag", dict(base, tag="v9"), "C"),
            ("M19b", "update_ref", dict(base, ref="heads/main"), "C"),
            ("M19c", "update_pull_request_branch", dict(base, pullNumber=1), "C"),
        ]
        return rows

    def test_mcp_rows(self):
        for row in self.mcp_rows():
            rid, tool, fields, expect = row[:4]
            variant = row[4] if len(row) > 4 else ""
            self.sb.restore()
            cwd = self.sb.p("plain" if variant == "plain" else "w")
            if variant == "nohead":
                self.sb.g(self.sb.p("w"), "remote", "set-head", "origin", "-d")
            env = push_sandbox.git_env(self.sb.root, plain=True)
            text = json.dumps({"tool_name": "mcp__github__" + tool, "cwd": cwd, "tool_input": fields})
            result = shell_analysis.analyze_payload(text, cwd, True, env)
            with self.subTest(row=rid):
                verdict = result["push_scope"]["verdict"]
                self.assertEqual(verdict, "feature" if expect == "I" else "strict", result["push_scope"])

    def test_counts(self):
        ids = [r["id"] for r in push_corpus.ROWS]
        self.assertEqual(len(push_corpus.ATTACKS), 205 + 34 + 16 + 26 + 3 + 15)  # A1-A15, B1-B20, C1-C22, D1-D26, E1-E16, E17-E25 (assignments)
        self.assertEqual(len(push_corpus.HONEST), 52)


if __name__ == "__main__":
    unittest.main()
