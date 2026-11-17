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


class UncertainCdTest(unittest.TestCase):
    """A cd whose effect cannot be proven does not hide the directory a relative write lands in: a cd that may not
    have run leaves the directory before it among ``alts``; a cd the analysis cannot read makes it dynamic."""

    def setUp(self):
        self.tmp = os.path.realpath(tempfile.mkdtemp())
        self.sd = os.path.join(self.tmp, "state")
        self.other = os.path.join(self.tmp, "other")
        os.makedirs(self.sd)
        os.makedirs(self.other)
        os.symlink(self.sd, os.path.join(self.tmp, "link"))

    def write0(self, command, base=None):
        res = sa.analyze_command(command, base_dir=base or self.sd)
        return res["writes"][-1]

    def places(self, command, base=None):
        write = self.write0(command, base)
        return {write["path"]} | {a["path"] for a in write.get("alts", [])}

    def test_a_cd_after_and_may_not_have_run(self):
        for command in ("false && cd %s; rm -f baselined-roots" % self.other,
                        "test -d x && cd %s; rm -f baselined-roots" % self.other,
                        "false || cd %s; rm -f baselined-roots" % self.other):
            self.assertEqual(self.places(command), {os.path.join(self.sd, "baselined-roots"),
                                                    os.path.join(self.other, "baselined-roots")}, command)

    def test_a_chain_of_and_keeps_the_directory_for_what_follows_the_cd(self):
        write = self.write0("true && cd %s && rm -f baselined-roots" % self.other)
        self.assertEqual(write["path"], os.path.join(self.other, "baselined-roots"))
        self.assertNotIn("alts", write)

    def test_a_cd_on_the_or_side_is_not_certain_inside_the_chain(self):
        places = self.places("false || cd %s && rm -f baselined-roots" % self.other)
        self.assertIn(os.path.join(self.sd, "baselined-roots"), places)

    def test_a_failing_cd_leaves_the_directory(self):
        for command in ("cd /nonexistent-dir 2>/dev/null; rm -f baselined-roots",
                        "cd %s/missing; rm -f baselined-roots" % self.other):
            self.assertIn(os.path.join(self.sd, "baselined-roots"), self.places(command), command)

    def test_a_directory_made_earlier_is_proven(self):
        write = self.write0("mkdir newdir && cd newdir && rm -f baselined-roots")
        self.assertEqual(write["path"], os.path.join(self.sd, "newdir", "baselined-roots"))
        self.assertNotIn("alts", write)
        self.assertIn(os.path.join(self.sd, "x"), self.places("mkdir newdir; cd newdir/sub; rm -f x"))
        write = self.write0("mkdir -p a/b/c && cd a/b && rm -f x")
        self.assertEqual(write["path"], os.path.join(self.sd, "a", "b", "x"))

    def test_a_cd_in_code_that_may_not_run(self):
        for command in ("if false; then cd %s; fi; rm -f baselined-roots" % self.other,
                        "while false; do cd %s; done; rm -f baselined-roots" % self.other,
                        "for i in a b; do cd %s; done; rm -f baselined-roots" % self.other,
                        "case x in y) cd %s;; esac; rm -f baselined-roots" % self.other,
                        "if true; then cd %s; else cd %s; fi; rm -f baselined-roots" % (self.other, self.other)):
            self.assertIn(os.path.join(self.sd, "baselined-roots"), self.places(command), command)

    def test_a_cd_that_a_variable_redirects_is_dynamic(self):
        for command in ("CDPATH=%s cd state && rm -f baselined-roots" % self.tmp,
                        "CDPATH=%s; cd state && rm -f baselined-roots" % self.tmp,
                        "shopt -s cdable_vars; v=%s; cd v && rm -f baselined-roots" % self.sd,
                        "OLDPWD=%s; cd - && rm -f baselined-roots" % self.sd,
                        "cd %s; OLDPWD=%s; cd - && rm -f baselined-roots" % (self.other, self.sd),
                        "cd %s; OLDPWD=%s pushd - && rm -f baselined-roots" % (self.other, self.sd),
                        "HOME=%s; cd && rm -f baselined-roots" % self.sd,
                        "PWD=%s; cd sub && rm -f baselined-roots" % self.sd,
                        "go() { cd %s; }; go; rm -f baselined-roots" % self.other,
                        "pushd -n %s >/dev/null; pushd >/dev/null; rm -f baselined-roots" % self.sd,
                        "find %s -name state -execdir rm -f baselined-roots \\;" % self.tmp):
            write = self.write0(command)
            self.assertTrue(write["dynamic"] and write["relative"], command)

    def test_cd_through_command_builtin_and_eval_still_moves(self):
        for command in ("command cd %s && rm -f x", "builtin cd %s && rm -f x", "eval 'cd %s' && rm -f x",
                        "eval cd %s; rm -f x"):
            write = self.write0(command % self.other)
            self.assertEqual(write["path"], os.path.join(self.other, "x"), command)

    def test_a_child_shell_does_not_move_this_one(self):
        for command in ("bash -c 'cd %s'; rm -f x", "env -C %s true; rm -f x", "(cd %s); rm -f x"):
            self.assertEqual(self.write0(command % self.other)["path"], os.path.join(self.sd, "x"), command)

    def test_cdable_vars_can_be_switched_off(self):
        write = self.write0("shopt -s cdable_vars; shopt -u cdable_vars; cd . && rm -f x")
        self.assertFalse(write["dynamic"])

    def test_a_cdpath_in_the_environment_is_dynamic_for_plain_names_only(self):
        os.environ["CDPATH"] = self.tmp
        try:
            self.assertTrue(self.write0("cd state && rm -f x")["dynamic"])
            self.assertFalse(self.write0("cd ./ && rm -f x")["dynamic"])
        finally:
            del os.environ["CDPATH"]

    def test_the_absolute_cd_clears_the_alternatives(self):
        write = self.write0("false && cd %s; cd %s; rm -f x" % (self.other, self.sd))
        self.assertNotIn("alts", write)

    def test_a_relative_cd_moves_the_alternatives_along(self):
        os.makedirs(os.path.join(self.sd, "sub"))
        os.makedirs(os.path.join(self.other, "sub"))
        places = self.places("false && cd %s; cd sub; rm -f x" % self.other)
        self.assertEqual(places, {os.path.join(self.sd, "sub", "x"), os.path.join(self.other, "sub", "x")})

    def test_too_many_alternatives_make_the_directory_unknown(self):
        command = "; ".join("false && cd %s/d%d" % (self.tmp, i) for i in range(12)) + "; rm -f x"
        self.assertTrue(self.write0(command)["dynamic"])

    def test_add_alts_with_a_dynamic_origin(self):
        write = self.write0("cd \"$(cat f)\"; true && cd %s; rm -f x" % self.other)
        self.assertTrue(write["dynamic"])

    def test_cd_P_follows_symlinks_before_dotdot(self):
        real = os.path.join(self.tmp, "real")
        os.makedirs(os.path.join(real, "deep", "d"))
        os.makedirs(os.path.join(self.tmp, "parent"))
        os.symlink(os.path.join(real, "deep", "d"), os.path.join(self.tmp, "parent", "l"))
        res = sa.analyze_command("cd -P parent/l/.. && echo x > f", base_dir=self.tmp)
        self.assertEqual((res["writes"][0]["path"], res["writes"][0]["lpath"]),
                         (os.path.join(real, "deep", "f"), os.path.join(real, "deep", "f")))
        res = sa.analyze_command("cd parent/l; cd -P ..; echo x > f", base_dir=self.tmp)
        self.assertEqual(res["writes"][0]["path"], os.path.join(real, "deep", "f"))
        res = sa.analyze_command("cd parent/l/.. && echo x > f", base_dir=self.tmp)  # logical: lexical
        self.assertEqual(res["writes"][0]["path"], os.path.join(self.tmp, "parent", "f"))

    def test_hard_link_sources_are_writes(self):
        for command in ("ln %s/baselined-roots x", "ln -f %s/root-1 x", "cp -l %s/baselined-roots x",
                        "cp --link %s/root-1 x", "link %s/baselined-roots x"):
            res = sa.analyze_command(command % self.sd, base_dir=self.other)
            self.assertIn("link source" if not command.startswith("link") else "link",
                          {w["via"] for w in res["writes"]}, command)
        res = sa.analyze_command("ln -s %s/baselined-roots x; cp %s/root-1 x" % (self.sd, self.sd), base_dir=self.other)
        self.assertNotIn("link source", {w["via"] for w in res["writes"]})

    def test_git_stash_options_do_not_hide_the_stash(self):
        for command in ("git stash -u", "git stash -m note", "git stash push -u", "git stash save x", "git stash pop"):
            res = sa.analyze_command(command, base_dir=self.sd)
            self.assertEqual([(w["via"], w["scope"]) for w in res["writes"]], [("git stash", "tree")], command)
        for command in ("git stash list", "git stash show", "git stash drop", "git stash clear"):
            self.assertEqual(sa.analyze_command(command, base_dir=self.sd)["writes"], [], command)

    def test_git_work_tree_is_where_git_works(self):
        for command in ("git --work-tree %s clean -fdx" % self.sd, "git --work-tree=%s clean -fdx" % self.sd,
                        "GIT_WORK_TREE=%s git clean -fdx" % self.sd, "GIT_WORK_TREE=%s; git clean -fdx" % self.sd):
            res = sa.analyze_command(command, base_dir=self.other)
            self.assertEqual([w["path"] for w in res["writes"]], [self.sd], command)
        res = sa.analyze_command('git --work-tree "$X" clean -fdx', base_dir=self.other)
        self.assertTrue(res["writes"][0]["dynamic"])
        res = sa.analyze_command('GIT_WORK_TREE="$(cat f)" git clean -fdx', base_dir=self.other)
        self.assertTrue(res["writes"][0]["dynamic"])


if __name__ == "__main__":
    unittest.main()
