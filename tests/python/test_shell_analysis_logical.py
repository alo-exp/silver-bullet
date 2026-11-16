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


class CdTrackingTest(unittest.TestCase):
    """cd, pushd, popd and ``cd -`` keep BOTH spellings of the working directory: the logical one (lexical join,
    '.' and '..' collapsed, symlinks left alone, as bash -L does) and the resolved one (where the kernel puts it)."""

    def setUp(self):
        self.tmp = os.path.realpath(tempfile.mkdtemp())
        self.real = os.path.join(self.tmp, "real")
        os.makedirs(os.path.join(self.real, "src", "sub"))
        self.proj = os.path.join(self.tmp, "proj")
        os.makedirs(os.path.join(self.proj, "docs"))
        os.symlink(os.path.join(self.real, "src"), os.path.join(self.proj, "src"))
        self.src = os.path.join(self.proj, "src")
        self.elsewhere = os.path.join(self.tmp, "elsewhere")
        os.makedirs(self.elsewhere)

    def paths(self, command, base, logical=None):
        res = sa.analyze_command(command, base_dir=base, scope_logical=logical)
        return [(w["path"], w["lpath"]) for w in res["writes"]]

    def lp(self, command, base=None, logical=None):
        return [lpath for _, lpath in self.paths(command, base or self.src, logical)]

    def test_cd_dot_keeps_the_logical_spelling(self):
        self.assertEqual(self.lp("cd . && echo x > app.js", self.src, self.src), [os.path.join(self.src, "app.js")])

    def test_cd_sub_then_dotdot_stays_on_the_logical_path(self):
        self.assertEqual(self.lp("cd sub && echo x > ../app.js", self.src, self.src), [os.path.join(self.src, "app.js")])
        self.assertEqual(self.paths("cd sub && echo x > ../app.js", self.src, self.src)[0][0],
                         os.path.join(self.real, "src", "app.js"))

    def test_cd_dotdot_is_lexical_like_bash(self):
        # bash -L: from <proj>/src, `cd ..` is <proj>, not the resolved parent of the target
        self.assertEqual(self.lp("cd .. && echo x > src/app.js", self.src, self.src), [os.path.join(self.src, "app.js")])
        self.assertEqual(self.paths("cd .. && echo x > src/app.js", self.src, self.src)[0][0],
                         os.path.join(self.real, "src", "app.js"))

    def test_cd_into_the_symlink_from_the_project(self):
        out = self.paths("cd src && echo x > app.js", self.proj, self.proj)[0]
        self.assertEqual(out, (os.path.join(self.real, "src", "app.js"), os.path.join(self.src, "app.js")))

    def test_cd_P_resolves_the_logical_path_too(self):
        out = self.paths("cd -P src && echo x > ../app.js", self.proj, self.proj)[0]
        self.assertEqual(out[1], os.path.join(self.real, "app.js"))

    def test_cd_L_after_P_is_logical(self):
        self.assertEqual(self.lp("cd -P -L src && echo x > ../app.js", self.proj, self.proj),
                         [os.path.join(self.proj, "app.js")])

    def test_cd_with_an_unrelated_flag_keeps_the_mode(self):
        self.assertEqual(self.lp("cd -Pe src && echo x > ../app.js", self.proj, self.proj), [os.path.join(self.real, "app.js")])

    def test_cd_double_dash(self):
        self.assertEqual(self.lp("cd -- src && echo x > app.js", self.proj, self.proj), [os.path.join(self.src, "app.js")])

    def test_pushd_and_popd_restore_both_spellings(self):
        self.assertEqual(self.lp("pushd src >/dev/null && popd >/dev/null && echo x > app.js", self.proj, self.proj),
                         [os.path.join(self.proj, "app.js")])
        self.assertEqual(self.lp("pushd src >/dev/null && echo x > app.js", self.proj, self.proj),
                         [os.path.join(self.src, "app.js")])

    def test_popd_with_an_empty_stack_or_options_is_dynamic(self):
        res = sa.analyze_command("popd && echo x > app.js", base_dir=self.proj)
        self.assertTrue(res["writes"][0]["dynamic"])
        res = sa.analyze_command("pushd src && pushd -n docs && popd && echo x > app.js", base_dir=self.proj)
        self.assertTrue(res["writes"][0]["dynamic"])
        res = sa.analyze_command("pushd && echo x > app.js", base_dir=self.proj)
        self.assertTrue(res["writes"][0]["dynamic"])

    def test_popd_after_a_dynamic_directory_is_dynamic(self):
        res = sa.analyze_command('pushd "$(cat d)" && pushd src && popd && echo x > app.js', base_dir=self.proj)
        self.assertTrue(res["writes"][0]["dynamic"])
        # the next popd goes back to the directory the first pushd left, which is known
        self.assertEqual(self.lp('pushd "$(cat d)" && pushd src && popd && popd && echo x > app.js', self.proj, self.proj),
                         [os.path.join(self.proj, "app.js")])

    def test_cd_dash_returns_to_the_logical_previous_directory(self):
        self.assertEqual(self.lp("cd src && cd - >/dev/null && echo x > app.js", self.proj, self.proj),
                         [os.path.join(self.proj, "app.js")])
        self.assertEqual(self.lp("cd src; cd ../docs; cd - >/dev/null && echo x > app.js", self.proj, self.proj),
                         [os.path.join(self.src, "app.js")])

    def test_cd_dash_without_a_previous_directory_is_dynamic(self):
        res = sa.analyze_command("cd - && echo x > app.js", base_dir=self.proj)
        self.assertTrue(res["writes"][0]["dynamic"])

    def test_dollar_pwd_and_pwd_are_logical(self):
        self.assertEqual(self.lp('cd src && echo x > "$PWD/app.js"', self.proj, self.proj), [os.path.join(self.src, "app.js")])
        self.assertEqual(self.lp('cd src && echo x > "$(pwd)/app.js"', self.proj, self.proj), [os.path.join(self.src, "app.js")])
        self.assertEqual(self.lp('cd src && echo x > "$(pwd -P)/app.js"', self.proj, self.proj),
                         [os.path.join(self.real, "src", "app.js")])
        self.assertEqual(self.lp('cd src && cd docs; echo x > ~-/app.js', self.proj, self.proj),
                         [os.path.join(self.src, "app.js")])

    def test_subshell_cd_does_not_leak(self):
        self.assertEqual(self.lp("(cd src) && echo x > app.js", self.proj, self.proj), [os.path.join(self.proj, "app.js")])

    def test_payload_cwd_differs_from_the_process_cwd(self):
        # the host runs the command in the payload cwd; the hook process may sit anywhere else
        payload = json.dumps({"tool_name": "Bash", "cwd": self.proj, "tool_input": {"command": "cd src && echo x > app.js"}})
        res = sa.analyze_payload(payload, base_dir=self.elsewhere)
        self.assertEqual((res["writes"][0]["path"], res["writes"][0]["lpath"]),
                         (os.path.join(self.real, "src", "app.js"), os.path.join(self.src, "app.js")))
        self.assertEqual(res["base_dir"], self.proj)

    def test_payload_cwd_that_is_an_alias_symlink(self):
        alias = os.path.join(self.tmp, "alias")
        os.symlink(self.proj, alias)
        payload = json.dumps({"tool_name": "Bash", "cwd": alias, "tool_input": {"command": "cd src && tee app.js"}})
        res = sa.analyze_payload(payload, base_dir=self.elsewhere)
        self.assertEqual(res["writes"][0]["lpath"], os.path.join(alias, "src", "app.js"))
        self.assertEqual(res["writes"][0]["path"], os.path.join(self.real, "src", "app.js"))

    def test_payload_cwd_that_is_not_a_directory_falls_back_to_the_process_cwd(self):
        payload = json.dumps({"tool_name": "Bash", "cwd": os.path.join(self.tmp, "nope"),
                              "tool_input": {"command": "echo x > a.js"}})
        res = sa.analyze_payload(payload, base_dir=self.proj)
        self.assertEqual(res["writes"][0]["lpath"], os.path.join(self.proj, "a.js"))

    def test_process_cwd_spelling_is_kept_when_the_payload_has_no_cwd(self):
        payload = json.dumps({"tool_name": "Bash", "tool_input": {"command": "cd sub; echo x > ../app.js"}})
        res = sa.analyze_payload(payload, base_dir=self.src)
        self.assertEqual(res["writes"][0]["lpath"], os.path.join(self.src, "app.js"))
        self.assertEqual(res["writes"][0]["path"], os.path.join(self.real, "src", "app.js"))

    def test_edit_target_under_a_workdir_joins_both_spellings(self):
        payload = json.dumps({"tool_name": "Write", "cwd": self.proj, "tool_input": {"file_path": "app.js", "workdir": "src"}})
        res = sa.analyze_payload(payload, base_dir=self.elsewhere)
        self.assertEqual((res["writes"][0]["path"], res["writes"][0]["lpath"]),
                         (os.path.join(self.real, "src", "app.js"), os.path.join(self.src, "app.js")))

    def test_workdir_without_a_payload_cwd_joins_the_process_cwd(self):
        payload = json.dumps({"tool_name": "exec_command", "tool_input": {"cmd": "echo x > app.js", "workdir": "src"}})
        res = sa.analyze_payload(payload, base_dir=self.proj)
        self.assertEqual(res["writes"][0]["lpath"], os.path.join(self.src, "app.js"))

    def test_codex_workdir_is_joined_on_both_spellings(self):
        payload = json.dumps({"tool_name": "exec_command", "cwd": self.proj,
                              "tool_input": {"cmd": "echo x > app.js", "workdir": "src"}})
        res = sa.analyze_payload(payload, base_dir=self.elsewhere)
        self.assertEqual((res["writes"][0]["path"], res["writes"][0]["lpath"]),
                         (os.path.join(self.real, "src", "app.js"), os.path.join(self.src, "app.js")))

    def test_codex_argv_form_after_the_payload_cwd(self):
        payload = json.dumps({"tool_name": "exec_command", "cwd": self.src, "tool_input": {"cmd": ["tee", "../app.js"]}})
        res = sa.analyze_payload(payload, base_dir=self.elsewhere)
        self.assertEqual(res["writes"][0]["lpath"], os.path.join(self.proj, "app.js"))

    def test_env_C_and_git_C_still_resolve(self):
        self.assertEqual(self.lp("env -C src tee app.js", self.proj, self.proj), [os.path.join(self.src, "app.js")])


if __name__ == "__main__":
    unittest.main()
