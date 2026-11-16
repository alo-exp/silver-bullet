"""Every write also reports its LOGICAL spelling (``lpath``): joined to the payload cwd (else the base
directory), '.' and '..' collapsed lexically, symlinks left alone, next to the resolved ``path``."""

from __future__ import annotations

import json
import os
import tempfile
import unittest

from test_shell_analysis import sa


class LogicalPathTest(unittest.TestCase):
    def setUp(self):
        self.tmp = os.path.realpath(tempfile.mkdtemp())
        self.real = os.path.join(self.tmp, "real")
        os.makedirs(os.path.join(self.real, "src"))
        os.makedirs(os.path.join(self.tmp, "proj"))
        self.link = os.path.join(self.tmp, "proj", "src")
        os.symlink(os.path.join(self.real, "src"), self.link)
        self.proj = os.path.join(self.tmp, "proj")

    def test_shell_redirect_reports_both_spellings(self):
        res = sa.analyze_command("echo x > src/a.js", base_dir=self.proj)
        write = res["writes"][0]
        self.assertEqual(write["path"], os.path.join(self.real, "src", "a.js"))
        self.assertEqual(write["lpath"], os.path.join(self.proj, "src", "a.js"))

    def test_payload_cwd_is_the_logical_base(self):
        res = sa.analyze_command("echo x > src/a.js", base_dir="/", scope_logical=self.proj)
        self.assertEqual(res["writes"][0]["lpath"], os.path.join(self.proj, "src", "a.js"))

    def test_dotdot_collapses_lexically_and_cd_follows_the_text(self):
        res = sa.analyze_command("cd src && echo x > ../src/a.js", base_dir=self.proj)
        self.assertEqual(res["writes"][0]["lpath"], os.path.join(self.proj, "src", "a.js"))

    def test_argv_form(self):
        res = sa.analyze_argv(["tee", "src/a.js"], base_dir=self.proj)
        self.assertEqual(res["writes"][0]["lpath"], os.path.join(self.proj, "src", "a.js"))

    def test_edit_payload_reports_the_logical_path_under_the_payload_cwd(self):
        payload = json.dumps({"tool_name": "Write", "cwd": self.proj, "tool_input": {"file_path": "src/a.js"}})
        res = sa.analyze_payload(payload)
        self.assertEqual(res["writes"][0]["lpath"], os.path.join(self.proj, "src", "a.js"))

    def test_edit_payload_without_cwd_uses_the_base_directory(self):
        payload = json.dumps({"tool_name": "Write", "tool_input": {"file_path": "src/a.js"}})
        res = sa.analyze_payload(payload, base_dir=self.proj)
        self.assertEqual(res["writes"][0]["lpath"], os.path.join(self.proj, "src", "a.js"))


if __name__ == "__main__":
    unittest.main()
