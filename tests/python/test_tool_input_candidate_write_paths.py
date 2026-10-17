"""Unit tests for hooks/lib/tool-input/candidate_write_paths.py.

The script receives a base directory and a shell command and prints the sorted,
resolved set of paths the command may write (redirects, tee, cp/mv/install/ln
destinations, rm/chmod/touch/mkdir operands, sed/perl -i targets and inline
interpreter writes).
"""

import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from tool_input_support import run_tool_input_script


class CandidateWritePathsTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.base = Path(self._tmp.name).resolve()

    def tearDown(self):
        self._tmp.cleanup()

    def p(self, rel):
        return str(self.base / rel)

    def targets(self, command):
        res = run_tool_input_script("candidate_write_paths.py", str(self.base), command)
        self.assertEqual(res.code, 0)
        return res.lines

    # --- redirects -------------------------------------------------------
    def test_stdout_redirect_targets_are_resolved(self):
        self.assertEqual(self.targets("echo hi > out.txt"), [self.p("out.txt")])
        self.assertEqual(self.targets("printf x >> logs/app.log"), [self.p("logs/app.log")])
        self.assertEqual(self.targets('cat a 2> "err file.txt"'), [self.p("err file.txt")])
        self.assertEqual(self.targets("cat a > 'single q.txt'"), [self.p("single q.txt")])

    def test_device_targets_and_variables_are_ignored(self):
        self.assertEqual(self.targets("ls > /dev/null 2>/dev/stderr"), [])
        self.assertEqual(self.targets("echo x > /dev/fd/3"), [])
        self.assertEqual(self.targets("echo x > $OUT"), [])
        self.assertEqual(self.targets("echo x > `pick`"), [])
        self.assertEqual(self.targets("cat - > -"), [])

    def test_absolute_and_home_paths(self):
        with mock.patch.dict(os.environ, {"HOME": str(self.base)}):
            self.assertEqual(self.targets("touch ~/notes.md"), [self.p("notes.md")])
        self.assertEqual(self.targets(f"echo x > {self.base}/abs.txt"), [self.p("abs.txt")])

    def test_tokenized_redirect_after_operand(self):
        # A quoted redirect token is invisible to the raw redirect regex, so only
        # the token scan finds it: after an operand, or for echo/printf.
        self.assertEqual(self.targets("sort data '>>' sorted.txt"), [self.p("sorted.txt")])
        self.assertEqual(self.targets("echo '1>' o.txt"), [self.p("o.txt")])
        self.assertIn(self.p("sorted.txt"), self.targets("sort data 1>> sorted.txt"))

    def test_tokenized_redirect_edge_cases_do_not_add_targets(self):
        # trailing redirect token, "--" and control tokens after the redirect
        self.assertEqual(self.targets("grep x f '>'"), [])
        self.assertEqual(self.targets("grep x f '>' --"), [])
        # redirect token with no prior operand on a non-echo command
        self.assertEqual(self.targets("wc '>' counts.txt"), [])
        self.assertEqual(self.targets("sort -r '>' x.txt"), [])

    def test_tokenized_redirect_to_ignored_target_is_skipped(self):
        self.assertEqual(self.targets("sort data '>' /dev/null"), [])

    # --- tee / copy-style / path commands -------------------------------
    def test_tee_writes_every_positional_argument(self):
        self.assertEqual(
            self.targets("echo x | tee -a one.txt two.txt"),
            sorted([self.p("one.txt"), self.p("two.txt")]),
        )
        self.assertEqual(self.targets("echo x | tee $LOG"), [])

    def test_copy_style_commands_write_the_last_positional(self):
        for cmd in ("cp -r a b/dest", "mv a b/dest", "install -m 0644 a b/dest", "ln -s a b/dest"):
            with self.subTest(cmd=cmd):
                self.assertEqual(self.targets(cmd), [self.p("b/dest")])
        self.assertEqual(self.targets("cp a $DEST"), [])

    def test_copy_without_operands_reports_nothing(self):
        self.assertEqual(self.targets("cp --help"), [])

    def test_path_commands_write_every_operand(self):
        self.assertEqual(
            self.targets("rm -rf -- build dist"), sorted([self.p("build"), self.p("dist")])
        )
        res = self.targets("mkdir -p out && chmod 755 run.sh")
        self.assertIn(self.p("out"), res)
        self.assertIn(self.p("run.sh"), res)
        self.assertEqual(self.targets("touch $X"), [])

    def test_positional_args_skip_redirect_targets_and_control_tokens(self):
        # The "2>" token's target is not a cp operand; the destination is still "dst".
        self.assertEqual(
            self.targets("cp src '2>' err.log dst"),
            sorted([self.p("dst"), self.p("err.log")]),
        )

    # --- in-place editors --------------------------------------------------
    def test_sed_and_perl_in_place_edit_their_last_operand(self):
        self.assertEqual(self.targets("sed -i 's/a/b/' conf.ini"), [self.p("conf.ini")])
        self.assertEqual(self.targets("sed -i.bak -e 's/a/b/' -- conf.ini"), [self.p("conf.ini")])
        self.assertEqual(self.targets("perl -i -pe 's/a/b/' lib.pm"), [self.p("lib.pm")])

    def test_bundled_and_long_in_place_flags_are_detected(self):
        # Regression: bundled short flags and --in-place used to hide the target,
        # letting `perl -pi` / `sed -Ei` write into the plugin cache unblocked.
        self.assertEqual(self.targets("perl -pi -e 's/a/b/' lib.pm"), [self.p("lib.pm")])
        self.assertEqual(self.targets("sed -Ei 's/a/b/' conf.ini"), [self.p("conf.ini")])
        self.assertEqual(self.targets("sed --in-place 's/a/b/' conf.ini"), [self.p("conf.ini")])
        self.assertEqual(self.targets("sed --in-place=.bak 's/a/b/' conf.ini"), [self.p("conf.ini")])
        self.assertEqual(self.targets("sed -E --debug 's/a/b/' conf.ini"), [])

    def test_in_place_edit_with_unresolvable_or_missing_operand(self):
        self.assertEqual(self.targets("sed -i 's/a/b/' $FILE"), [])
        self.assertEqual(self.targets("sed -i -e"), [])
        self.assertEqual(self.targets("sed -n p file.txt"), [])

    # --- shell wrappers / segments ----------------------------------------
    def test_nested_shell_command_is_unwrapped(self):
        self.assertEqual(self.targets("bash -c \"sh -c 'echo x > nested.txt'\""), [self.p("nested.txt")])

    def test_shell_without_dash_c_is_not_unwrapped(self):
        self.assertEqual(self.targets("bash script.sh"), [])

    def test_comment_empty_and_assignment_only_segments(self):
        self.assertEqual(self.targets("FOO=1"), [])
        self.assertEqual(self.targets("   "), [])
        self.assertEqual(self.targets("# rm -rf everything"), [])
        self.assertEqual(self.targets("FOO=1; env BAR=2 && touch t.txt"), [self.p("t.txt")])

    def test_unparseable_segment_is_skipped_but_redirect_regex_still_applies(self):
        # shlex cannot split the line, but the raw redirect regex still sees "> bad.txt".
        self.assertEqual(self.targets("echo 'oops > bad.txt"), [self.p("bad.txt")])
        res = self.targets("touch ok.txt; echo \"unterminated")
        self.assertEqual(res, [self.p("ok.txt")])

    # --- inline interpreters ---------------------------------------------
    def test_python_inline_writes(self):
        script = (
            "from pathlib import Path; Path('a.txt').write_text('x'); "
            "pathlib.Path('b.txt').open('w'); open('c.txt', 'a'); open('r.txt', 'r')"
        )
        res = self.targets(f'python3 -c "{script}"')
        for rel in ("a.txt", "b.txt", "c.txt"):
            self.assertIn(self.p(rel), res)
        self.assertNotIn(self.p("r.txt"), res)

    def test_python_attached_flag_and_variable_target(self):
        res = self.targets("python -c\"open('d.txt','w')\"")
        self.assertEqual(res, [self.p("d.txt")])
        self.assertEqual(self.targets("python3 -c \"Path('$HOME/x').touch()\""), [])
        self.assertEqual(self.targets("python3 script.py"), [])

    def test_node_ruby_and_perl_inline_writes(self):
        self.assertEqual(
            self.targets("node -e \"require('fs').writeFileSync('n.txt', 'x')\""), [self.p("n.txt")]
        )
        self.assertEqual(self.targets("nodejs -e \"fs.appendFileSync('n2.txt','x')\""), [self.p("n2.txt")])
        self.assertEqual(
            self.targets("ruby -e \"File.write('r.txt', 'x'); File.open('r2.txt', 'w')\""),
            sorted([self.p("r.txt"), self.p("r2.txt")]),
        )
        self.assertEqual(self.targets("perl -e \"open(FH, '>', 'p.txt')\""), [self.p("p.txt")])

    def test_unknown_interpreter_has_no_inline_targets(self):
        self.assertEqual(self.targets("awk -e 'open(\"x\", \"w\")'"), [])

    # --- helper functions -------------------------------------------------
    def test_normalize_candidate_falls_back_when_resolve_fails(self):
        res = run_tool_input_script("candidate_write_paths.py", str(self.base), "true")
        normalize = res.globals["normalize_candidate"]
        self.assertEqual(normalize("bad\x00name"), str(self.base / "bad\x00name"))
        self.assertIsNone(normalize("  ;"))


if __name__ == "__main__":
    unittest.main()
