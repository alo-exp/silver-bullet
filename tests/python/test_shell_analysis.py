"""Unit tests for hooks/lib/tool-input/shell_analysis.py (parser, analyzer, payload API, CLI).

The corpus test (test_shell_analysis_corpus.py) covers the review-finding bypasses and the
honest commands; this module pins the individual behaviours: shell syntax the parser must
accept or reject, expansion rules, wrapper unwrapping, write-target extraction, git/gh/deploy
classification, hook-payload handling and the load-record format the Bash loader reads.
"""

from __future__ import annotations

import io
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from sbtest import REPO_ROOT
from tool_input_support import TOOL_INPUT_DIR, run_tool_input_script

if str(TOOL_INPUT_DIR) not in sys.path:
    sys.path.insert(0, str(TOOL_INPUT_DIR))
import shell_analysis as sa  # noqa: E402


class Base(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        root = Path(self._tmp.name).resolve()
        self.base = root / "work"
        self.home = root / "home"
        self.base.mkdir()
        self.home.mkdir()
        patcher = mock.patch.dict(os.environ, {"HOME": str(self.home)})
        patcher.start()
        self.addCleanup(patcher.stop)
        self.addCleanup(self._tmp.cleanup)

    def run_(self, cmd, **kw):
        return sa.analyze_command(cmd, base_dir=str(self.base), **kw)

    def actions(self, cmd, **kw):
        return self.run_(cmd, **kw)["actions"]

    def possible(self, cmd):
        return self.run_(cmd)["possible_actions"]

    def writes(self, cmd):
        return self.run_(cmd)["write_paths"]

    def p(self, rel):
        return str(self.base / rel)

    def ro(self, cmd):
        res = self.run_(cmd)
        return res["read_only"], res["read_only_legacy"]


# =============================================================================
# Parser
# =============================================================================


class ParserTest(unittest.TestCase):
    def ok(self, text):
        script = sa.parse(text)
        self.assertEqual(script.error, "", text)
        return script

    def err(self, text, fragment):
        self.assertIn(fragment, sa.parse(text).error, text)

    def test_syntax_errors_are_reported(self):
        for text, fragment in (
            ("echo $(ls", "expected ')'"),
            ("if true; echo x", "expected 'then'"),
            ("ls |", "unexpected end of input"),
            ("; ls", "unexpected ';'"),
            (")", "unexpected ')'"),
            ("!\nls", "expected a command"),
            ("echo a (b)", "unexpected '('"),
            ("f (x)", "unexpected '('"),
            ("a=(1 2", "unterminated array assignment"),
            ("echo >", "missing redirection target"),
            ("[[ -n x", "unterminated [["),
            ("(( 1 + ", "unterminated arithmetic expression"),
            ("ls @(a", "unterminated pattern"),
            ("echo $[1+1", "unterminated $["),
            ("echo ${x", "unterminated ${"),
            ("echo ${a:-'x", "unterminated single quote"),
            ("echo `date", "unterminated backquote"),
            ("echo $'abc", "unterminated $'"),
            ("echo 'abc", "unterminated single quote"),
            ('echo "abc', "unterminated double quote"),
        ):
            with self.subTest(text=text):
                self.err(text, fragment)

    def test_complete_commands_before_an_error_are_kept(self):
        script = sa.parse("touch a\necho 'oops")
        self.assertEqual(len(script.items), 1)
        self.assertTrue(script.error)

    def test_deep_nesting_is_an_error_not_a_crash(self):
        self.assertEqual(sa.parse("$(" * 4000 + "ls" + ")" * 4000).error, "nesting too deep")

    def test_compound_commands_parse(self):
        for text in (
            "! true", "time -p ls", "time ls | wc -l",
            "if a; then b; elif c; then d; else e; fi", "while a; do b; done", "until a; do b; done",
            "for x; do echo $x; done", "for x in a b\ndo echo $x; done", "for x in a; { echo $x; }",
            "for ((i=0; i<3; i++)); do echo $i; done", "select x in a b; do break; done",
            "case $x in (a) echo a;; b|c) echo b;;& *) echo c;& esac",
            "case $x in a) echo a\nesac", "function f { ls; }", "function g() { ls; }", "h ( ) { ls; }",
            "[[ $x =~ ^(a|b)$ && -n $y ]]", "(( $(echo 1) + `echo 2` + (3) ))", "coproc ls",
            "{ ls; } > out 2>&1", "( cd x ) < in", "a=(1 2\n3); b=(x ; y)", "declare -a arr=(1 $(rm x))",
            "ls @(a|b)", "echo $\"hi\" a$ \"a$\" \"\\x\" \"`date`\" \"\\\n\" \"\"",
            "echo $((1+2)) $[3] $# $? $$ $! $- \"$ \"", "echo ${a:-${b}} ${a:-`date`} ${a:-\\}} ${a:-'x}'} ${a:-\"x}\"}",
            "echo `echo \\`date\\``", "echo $'\\n\\x41\\xZ\\u00e9\\101\\cA\\q\\e'", "echo ab\\\ncd",
            "cat <<-EOF\n\tbody\n\tEOF\n", "cat <<\"$X\"\nhi\n$X\n", "cat <<EOF\nno end",
        ):
            with self.subTest(text=text):
                self.ok(text)

    def test_heredoc_bodies_and_delimiters(self):
        redir = self.ok("cat <<-EOF\n\tone\n\tEOF\n").items[0][0][0][0].redirs[0]
        self.assertEqual(redir.body, "one\n")
        quoted = self.ok("cat <<\"$X\"\nhi\n$X\n").items[0][0][0][0].redirs[0]
        self.assertEqual((quoted.body, quoted.quoted), ("hi\n", True))
        open_ended = self.ok("cat <<EOF\nno end").items[0][0][0][0].redirs[0]
        self.assertEqual(open_ended.body, "no end\n")

    def test_ansi_c_quoting_decodes_escapes_and_stops_at_nul(self):
        word = self.ok("echo $'\\n\\x41\\xZ\\u00e9\\101\\cA\\q\\e'").items[0][0][0][0].words[1]
        self.assertEqual(word.literal(), "\nA\\xZ\u00e9A\x01\\q\x1b")
        self.assertEqual(self.ok("echo $'a\\0b'").items[0][0][0][0].words[1].literal(), "a")

    def test_words_keep_their_offsets(self):
        word = self.ok("  echo  hello").items[0][0][0][0].words[1]
        self.assertEqual((word.start, word.text), (8, "hello"))


# =============================================================================
# Expansion
# =============================================================================


class ExpansionTest(Base):
    def argv(self, cmd):
        return self.run_(cmd)["commands"][-1]["argv"]

    def test_brace_expansion(self):
        self.assertEqual(self.argv("echo {a,b}{1,2}"), ["echo", "a1", "a2", "b1", "b2"])
        self.assertEqual(self.argv("echo {a,{b,c}}"), ["echo", "a", "b", "c"])
        self.assertEqual(self.argv("echo {1..3} {c..a} {1..10..4} {3..1}"),
                         ["echo", "1", "2", "3", "c", "b", "a", "1", "5", "9", "3", "2", "1"])
        self.assertEqual(self.argv("echo {a} {'1'..3} {a {b,c} x{"),
                         ["echo", "{a}", "{1..3}", "{a", "b", "c", "x{"])
        self.assertEqual(self.argv("X=q; echo {p,$X}"), ["echo", "p", "q"])
        self.assertEqual(self.argv("echo {1..100}"), ["echo", "{1..100}"])

    def test_field_splitting_and_empty_expansions(self):
        self.assertEqual(self.argv('X=" a  b "; echo $X "$X" x$X'), ["echo", "a", "b", " a  b ", "x", "a", "b"])
        self.assertEqual(self.argv('E=; echo $E "$E" end'), ["echo", "", "end"])

    def test_tilde_forms(self):
        self.assertEqual(self.argv("cd /tmp && echo ~ ~/x ~+ ~- ~user"),
                         ["echo", str(self.home), str(self.home) + "/x", "/tmp", str(self.base), "~user"])

    def test_positional_parameters(self):
        self.assertEqual(self.actions("sh -c 'git \"$1\" -m x' _ commit"), ["commit"])
        self.assertEqual(self.actions("f() { git $@; }; f push"), ["push"])
        self.assertEqual(self.possible("f() { git $@ -m x; }; f $Y"), ["commit"])
        self.assertEqual(self.argv("set -- a b; echo $2 $3 $0"), ["echo", "b", "$0"])

    def test_static_substitutions(self):
        self.assertEqual(self.argv("echo $(echo -n a) $(echo -e 'b\\tc') $(echo -En d) $(printf %s%% x)"),
                         ["echo", "a", "b", "c", "d", "x%"])
        self.assertEqual(self.argv("echo $(printf '%s-' a b) $(printf '%x' 1) $(pwd) $(date) $(echo $(id))"),
                         ["echo", "a-b-", "$(printf '%x' 1)", str(self.base), "$(date)", "$(echo $(id))"])
        self.assertEqual(self.argv("echo $(echo $Y) $(ls | wc) $(X=1 echo) $(echo >f) $(printf)"),
                         ["echo", "$(echo $Y)", "$(ls | wc)", "$(X=1 echo)", "$(echo >f)", "$(printf)"])
        self.assertEqual(self.argv("echo $(if true; then echo x; fi)"), ["echo", "$(if true; then echo x; fi)"])
        self.assertEqual(self.argv("echo $(echo a; echo b) $(echo a && echo b) $()"),
                         ["echo", "$(echo a; echo b)", "$(echo a && echo b)", "$()"])

    def test_assignment_append_and_unknown_values(self):
        self.assertEqual(self.actions("X=gi; X+=t; $X commit"), ["commit"])
        self.assertEqual(self.possible("Y+=t; $Y commit"), ["commit", "unseen"])  # a computed program is unseen code

    def test_unknown_cwd_makes_relative_paths_dynamic(self):
        self.assertEqual(self.run_("cd $D && cd sub && echo x > f")["writes"][-1]["path"],
                         str(self.base) + "/$D/sub/f")
        self.assertEqual(self.writes("cd $D && echo x > /abs/f"), ["/abs/f"])


# =============================================================================
# Builtins, wrappers and nesting
# =============================================================================


class WalkerTest(Base):
    def test_nesting_limit_makes_code_opaque(self):
        res = self.run_("eval " * 30 + "ls")
        self.assertIn("nesting too deep", res["opaque_reasons"])
        self.assertFalse(res["read_only"])

    def test_reasons_are_listed_once(self):
        self.assertEqual(self.run_("$X; $X")["opaque_reasons"], ["dynamic command word: $X"])

    def test_functions_aliases_and_loops(self):
        self.assertEqual(self.actions("$f() { git push; }"), ["push"])
        self.assertEqual(self.actions("for ((i=$(git push); i<1; i++)); do :; done"), ["push"])
        self.assertEqual(self.possible("for f in $(ls); do git $f -m x; done"), ["commit", "unseen"])
        self.assertEqual(self.actions("alias p='git push'; unalias p; p"), [])
        self.assertEqual(self.actions("alias x=\"$Y\" y; x"), [])
        self.assertEqual(self.actions("f() { f; git push; }; f"), ["push"])

    def test_shell_state_builtins(self):
        self.assertEqual(self.actions("export G=git X; $G push"), ["push"])
        self.assertEqual(self.possible("export G=$(pick) 1A=b; $G push"), ["push", "unseen"])
        self.assertEqual(self.possible("read -r G; $G push"), ["push", "unseen"])
        self.assertEqual(self.actions("G=git; unset G; $G push"), [])
        self.assertEqual(self.actions("f() { git push; }; unset -f f; true"), ["push"])
        self.assertEqual(self.writes("cd /tmp; cd -; echo x > f"), [self.p("f")])
        self.assertEqual(self.run_("pushd /tmp; popd; echo x > f")["writes"][0]["dynamic"], True)
        self.assertEqual(self.writes("cd; echo x > f"), [str(self.home / "f")])
        self.assertEqual(self.ro("cd src; set -e; shift; true"), (True, True))

    def test_eval_source_and_trap(self):
        self.assertEqual(self.actions("eval git push"), ["push"])
        self.assertEqual(self.possible('eval "git $X -m y"'), ["commit", "unseen"])
        self.assertEqual(self.possible('eval "$X commit"'), ["commit", "unseen"])
        self.assertEqual(self.run_('eval "# $X"')["possible_actions"], ["unseen"])  # $X may hold a newline
        self.assertEqual(self.run_("source")["opaque_writers"], [])
        self.assertEqual(self.run_(". ./x.sh")["opaque_writers"][0]["reason"], "sources a script")
        self.assertEqual(self.actions("trap 'git push' EXIT"), ["push"])
        for cmd in ("trap -p", "trap - EXIT", "trap '' INT", "trap x"):
            with self.subTest(cmd=cmd):
                self.assertEqual(self.actions(cmd), [])
        self.assertIn("trap with a non-literal handler", self.run_('trap "$H" EXIT')["opaque_reasons"])

    def test_command_builtin(self):
        self.assertEqual(self.ro("command -v git"), (True, True))
        self.assertEqual(self.actions("command -p git push"), ["push"])
        self.assertEqual(self.actions("command"), [])

    def test_wrappers(self):
        for cmd in ("nohup git push", "nice -n 5 git push", "ionice -c 3 git push", "stdbuf -oL git push",
                    "setsid git push", "timeout -s KILL 5 git push", "gtimeout 5 git push", "sudo -u me git push",
                    "doas git push", "builtin eval git push", "exec git push", "exec -a x git push",
                    "unbuffer git push", "chronic git push", "caffeinate -i git push", "strace -f git push",
                    "busybox sh -c 'git push'", "watch -x git push", "watch 'git push'", "flock /tmp/l git push",
                    "flock /tmp/l -c 'git push'", "sudo -s git push", "npx -c 'git push'", "env -- git push",
                    "env -i -0 git push", "env -u X git push", "env -uX git push", "env -C /tmp git push",
                    "env --chdir=/tmp git push", "env -S 'git push'", "env --split-string='git push'",
                    "rtk proxy git push", "/usr/bin/time -o t.txt git push"):
            with self.subTest(cmd=cmd):
                self.assertEqual(self.actions(cmd), ["push"])
        self.assertEqual(self.writes("/usr/bin/time -o t.txt ls"), [self.p("t.txt")])
        self.assertEqual(self.writes("sudo -e /etc/hosts"), ["/etc/hosts"])
        self.assertEqual(self.ro("nohup"), (False, False))
        self.assertEqual(self.ro("env A=1"), (True, True))
        self.assertEqual(self.ro("rtk --version"), (False, False))
        self.assertEqual(self.ro("rtk"), (False, False))
        self.assertEqual(self.writes("env -C /tmp touch x"), ["/tmp/x"])

    def test_xargs(self):
        self.assertEqual(self.actions("echo push | xargs git"), ["push"])
        self.assertEqual(self.actions("printf 'commit\\n' | xargs -I{} git {} -m x"), ["commit"])
        self.assertEqual(self.actions("echo push | xargs -i git {}"), ["push"])
        self.assertEqual(self.actions("echo push | xargs -iR git R"), ["push"])
        self.assertEqual(self.actions("echo push | xargs --replace=R git R"), ["push"])
        self.assertEqual(self.writes("find src | xargs -I {} cp {} {}.bak"), [self.p("src")])
        self.assertEqual(self.writes("cat list | xargs -I@ touch pre-@"), [])
        self.assertEqual(self.ro("ls | xargs"), (True, True))

    def test_shells(self):
        self.assertEqual(self.actions("bash -o pipefail -c 'git push'"), ["push"])
        self.assertEqual(self.actions("bash --norc -eo pipefail -c 'git push'"), ["push"])
        self.assertEqual(self.actions("bash -- x.sh"), [])
        self.assertIn("shell -c with a missing or non-literal script", self.run_("bash -c")["opaque_reasons"])
        self.assertIn("shell -c with a missing or non-literal script", self.run_('sh -c "$S"')["opaque_reasons"])
        self.assertIn("shell reads commands from a pipe or file that cannot be read", self.run_("curl x | sh")["opaque_reasons"])
        self.assertEqual(self.run_("cat f | sh")["possible_actions"], [])  # the script file is opaque, not unseen
        self.assertEqual(self.actions("echo 'git push' | bash -"), ["push"])
        self.assertIn("script path is dynamic: $S", self.run_('bash "$S"')["opaque_reasons"])

    def test_invoked_shell_script(self):
        (self.base / "run.sh").write_text("echo hi\n")
        self.assertEqual(self.run_("cd . && bash run.sh")["invoked_script"], self.p("run.sh"))
        self.assertEqual(self.run_("python3 run.sh")["invoked_script"], "")
        self.assertEqual(self.run_("cd $X && ./run.sh")["invoked_script"], "")


# =============================================================================
# Read-only verdicts and write targets
# =============================================================================


class ReadOnlyAndWritesTest(Base):
    def test_argument_checks_of_read_only_programs(self):
        for cmd, expected in (
            ("date 0101", False), ("hostname x", False), ("sort -o out f", False), ("sort --compress-program=x f", False),
            ("uniq a b", False), ("xxd a b", False), ("base64 -o out f", False), ("tree -o out", False),
            ("rg --pre=x y", False), ("yq -i .a=1 f.yaml", False), ("yq .a f.yaml", True), ("graphify", False),
            ("printf -v X %s 1", True), ("sed 's/a/b/' f", True), ("sed 'k' f", False), ('sed "$S" f', False),
            ("sed '# c\\n/x/d' f", True), ("sed '\\%x%d' f", True), ("sed ':a;N;ba' f", True),
            ("sed '1i\\ hi' f", True), ("awk '{print > $1}' f", False), ('awk "$P" f', False),
            ("awk -d '{print}' f", False), ("awk -i inplace '{print}' x=1 f", False), ("find -L . -name x", True), ("find . -exec \\;", True),
            ("find . -newermt 2020 -print", True), ("cat a | cat", True), ("echo $(ls)", True),
            ("lua -e 'x=1'", False), ("printf \"$X\" | sh", False),
        ):
            with self.subTest(cmd=cmd):
                self.assertEqual(self.run_(cmd)["read_only"], expected)

    def test_writers(self):
        (self.base / "p.diff").write_text("--- a/src/x.py\n+++ b/src/x.py\n--- /dev/null\n+++ b/src/x.py\n")
        (self.base / "big.diff").write_text("x" * (2 * 1024 * 1024 + 2))
        for cmd, expected in (
            ("install -d d1 d2", ["d1", "d2"]), ("ln -s target", ["target"]), ("rsync a host:/x", []),
            ("curl -O https://h/a/b.txt?x=1", ["b.txt"]), ("curl --output-dir out -O https://h/c.txt", ["out/c.txt"]),
            ("wget https://h/f.tgz", ["f.tgz"]), ("wget -P dl https://h/", ["dl/index.html"]),
            ("wget --spider https://h/x", []), ("wget -o log https://h/x", ["log", "x"]),
            ("tar xzf a.tgz", []), ("tar -czf out.tgz src", ["out.tgz"]), ("tar -tf a.tar", []),
            ("unzip x.zip", []), ("unzip -l x.zip", []), ("gzip -c f > f.gz", ["f.gz"]),
            ("patch --dry-run -p1 < p.diff", []), ("patch -d sub -o out.txt", ["sub/out.txt"]),
            ("patch -p1 -i p.diff", ["src/x.py"]), ("patch -p1 -i big.diff", []), ('patch -i "$P"', []),
            ("vim +10 f.py", ["f.py"]), ("split -l 10 big part-", ["part-"]), ("split big", []),
            ("dd if=a of=$OUT", []), ("cp a", []), ("chown me f", ["f"]), ("chmod --reference=r f", ["f"]),
            ("echo x > -", []), ("git apply p.diff", ["src/x.py"]), ("git apply --cached p.diff", []),
            ("git apply -p0 --apply --check p.diff", ["a/src/x.py", "b/src/x.py"]),
            ("git clean -fd build", ["build"]), ("git clean -n", []), ("git checkout -- a b", ["a", "b"]),
        ):
            with self.subTest(cmd=cmd):
                self.assertEqual(self.writes(cmd), sorted(self.p(e) for e in expected))

    def test_tree_scope_writes_are_not_legacy_paths(self):
        for cmd in ("tar -xf a.tar", "unzip x.zip", "git reset --hard", "git stash pop", "git merge x",
                    "patch -p1", "git clean -f", "git apply"):
            with self.subTest(cmd=cmd):
                res = self.run_(cmd)
                self.assertEqual(res["write_paths"], [])
                self.assertEqual(res["writes"][-1]["scope"], "tree")

    def test_checkout_of_an_existing_file_writes_it(self):
        (self.base / "f.py").write_text("x\n")
        self.assertEqual(self.writes("git checkout f.py"), [self.p("f.py")])
        self.assertEqual(self.writes("git checkout main"), [])

    def test_quoted_operators_and_embedded_redirects(self):
        self.assertEqual(self.writes("printf '>' out"), [self.p("out")])
        self.assertEqual(self.ro("echo '2>&1'"), (False, False))
        self.assertEqual(self.ro("echo '>>/dev/null'"), (True, True))

    def test_parse_error_keeps_regex_redirect_targets(self):
        self.assertEqual(self.writes("echo 'x > a.txt > $V > /dev/null"), [self.p("a.txt")])

    def test_awk_in_place_skips_variable_assignments(self):
        self.assertEqual(self.writes("awk -i inplace '{print}' x=1 f"), [self.p("f")])

    def test_interpreters(self):
        self.assertEqual(self.writes("node --eval \"fs.writeFileSync('a.js','x')\""), [self.p("a.js")])
        self.assertEqual(self.writes("node --print=\"fs.rmSync('b.js')\""), [self.p("b.js")])
        self.assertEqual(self.run_("node --require ./setup.js --test")["read_only_legacy"], True)
        self.assertEqual(self.run_("node --test --updateSnapshot")["read_only_legacy"], False)
        self.assertEqual(self.actions("python3 -m deploy"), ["deploy"])
        self.assertEqual(self.run_("python3 -- x.py")["opaque_writers"][0]["reason"], "runs a python script")
        self.assertEqual(self.possible("echo 'import os; os.system(\"git push\")' | python3"), ["push"])
        self.assertIn("dynamic inline python code", self.run_('python3 -c "$CODE"')["opaque_reasons"])
        self.assertEqual(self.writes("ruby -i -pe 'gsub(/a/,\"b\")' f.rb"), [self.p("f.rb")])
        self.assertEqual(self.writes("perl -i script.pl f"), [self.p("f")])
        self.assertEqual(self.run_("Rscript x.R")["opaque_writers"][0]["reason"], "runs a Rscript script")


# =============================================================================
# Delivery classification
# =============================================================================


class GitTest(Base):
    def test_git_environment_config(self):
        self.assertEqual(self.actions("GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=alias.ci GIT_CONFIG_VALUE_0=commit git ci"),
                         ["commit"])
        self.assertEqual(self.actions("GIT_CONFIG_COUNT=2 GIT_CONFIG_KEY_1=x git ci"), [])
        self.assertEqual(self.actions("GIT_CONFIG_PARAMETERS=\"'alias.ci'='commit'\" git ci"), ["commit"])
        self.assertEqual(self.actions("export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=alias.up GIT_CONFIG_VALUE_0='!git push'; git up"),
                         ["push"])

    def test_git_global_options_and_aliases(self):
        self.assertEqual(self.actions("git --git-dir .git --work-tree . commit"), ["commit"])
        self.assertIn("dynamic git alias: ci", self.run_("git -c alias.ci=$X ci")["opaque_reasons"])
        self.assertEqual(self.ro("git -c $X log"), (False, False))
        self.assertEqual(self.ro("git --version"), (True, True))
        self.assertEqual(self.actions("git config set alias.ci commit && git ci"), ["commit"])
        self.assertEqual(self.ro("git config get user.name"), (True, True))
        self.assertEqual(self.actions("git -c alias.a=b -c alias.b=a a"), [])

    def test_repository_aliases_are_read_from_git_config(self):
        repo = self.base / "repo"
        subprocess.run(["git", "init", "-q", str(repo)], check=True)
        subprocess.run(["git", "-C", str(repo), "config", "alias.ship", "push origin HEAD"], check=True)
        self.assertEqual(sa.analyze_command("git ship && git ship", base_dir=str(repo))["actions"], ["push"])
        self.assertEqual(sa.analyze_command("git nothing", base_dir=str(repo))["actions"], [])
        with mock.patch("subprocess.run", side_effect=OSError("no git")):
            self.assertEqual(sa._repo_git_aliases(str(repo)), {})

    def test_dynamic_subcommand_guesses(self):
        self.assertEqual(self.possible("git $X commit"), ["commit"])
        self.assertEqual(self.possible("git $X send-pack"), ["push"])
        self.assertEqual(self.possible("git $X --tags"), ["push"])
        self.assertEqual(self.possible("git $X log"), [])

    def test_push_details(self):
        push = self.run_("git push -fu origin +HEAD:refs/heads/main :old v1 refs/tags/v2")["push"][0]
        self.assertEqual((push["remote"], push["dsts"]), ("origin", ["refs/heads/main", "old", "v1", "refs/tags/v2"]))
        self.assertEqual((push["force"], push["delete"], push["tags"], push["default"]), (True, True, True, False))
        self.assertEqual(self.run_("git push")["push"][0]["default"], True)
        self.assertEqual(self.run_("git push --mirror")["push"][0]["mirror"], True)

    def test_commit_details(self):
        commit = self.run_("git add a b && git commit -am msg -- c")["commits"][0]
        self.assertEqual(commit, {"all": True, "amend": False, "pathspecs": ["c"], "staged_paths": ["a", "b"]})
        self.assertEqual(self.run_("git commit --amend --no-edit")["commits"][0]["amend"], True)

    def test_read_only_forms(self):
        for cmd, expected in (("git branch -a --contains x", False), ("git tag -n", True),
                              ("git notes show", True), ("git sparse-checkout list", True), ("git stash drop", False),
                              ("git cherry-pick -n x", False)):
            with self.subTest(cmd=cmd):
                self.assertEqual(self.run_(cmd)["read_only"], expected)
        self.assertEqual(self.actions("git cherry-pick -n x"), [])


class GhTest(Base):
    def test_gh_aliases_from_config(self):
        config = self.home / ".config" / "gh"
        config.mkdir(parents=True)
        (config / "config.yml").write_text(
            "# comment\nversion: 1\naliases:\n    pc: pr create --fill\n    sh: '!git push'\n"
            "    q: \"pr merge\"\n    \n    dq: 'it''s'\nother:\n    pc: ignored\n")
        self.assertEqual(self.actions("gh pc"), ["pr_create"])
        self.assertEqual(self.actions("gh sh"), ["push"])
        self.assertEqual(self.actions("gh q 3"), ["pr_merge"])
        self.assertEqual(self.actions("gh nope"), [])
        self.assertEqual(sa._gh_config_aliases(str(self.home))["dq"], "it's")
        with mock.patch.dict(os.environ, {"GH_CONFIG_DIR": str(self.base)}):
            self.assertEqual(sa._gh_config_aliases(str(self.home)), {})

    def test_dynamic_gh_forms(self):
        self.assertEqual(self.possible("gh $X create"), ["pr_create", "release_create"])
        self.assertEqual(self.possible("gh $X merge 3"), ["pr_merge"])
        self.assertEqual(self.possible("gh $X"), [])
        self.assertIn("dynamic gh command: $X", self.run_("gh $X")["opaque_reasons"])
        self.assertEqual(self.possible("gh pr $X"), ["pr_create", "pr_merge"])
        self.assertEqual(self.possible("gh release $X"), ["release_create"])
        self.assertEqual(self.actions("gh"), [])

    def test_gh_api_forms(self):
        for cmd, expected in (
            ("gh api -XPOST repos/o/r/pulls", ["pr_create"]), ("gh api --method=PUT repos/o/r/pulls/1/merge", ["pr_merge"]),
            ("gh api --paginate repos/o/r/pulls", []), ("gh api", []),
            ("gh api -X POST repos/o/r/actions/workflows/deploy.yml/dispatches", ["deploy"]),
            ("gh api -X POST https://api.github.com/repos/o/r/deployments?x=1", ["deploy"]),
            ("gh api -X PATCH repos/o/r/releases/12", ["release_create"]),
            ("gh api -F query=@q.graphql graphql", []), ("hub api repos/o/r/pulls -f title=t", ["pr_create"]),
        ):
            with self.subTest(cmd=cmd):
                self.assertEqual(self.actions(cmd), expected)
        self.assertIn("graphql query is not visible", self.run_("gh api graphql -F query=@q.graphql")["opaque_reasons"])
        self.assertEqual(self.possible('gh api -X DELETE "$EP"'), ["remote_write"])
        self.assertEqual(self.possible('gh api "$EP"'), [])


class DeployTest(Base):
    def test_deploy_tools(self):
        for cmd, expected in (
            ("docker buildx build --push .", ["deploy"]), ("docker buildx build .", []),
            ("az webapp up", ["deploy"]), ("az deployment group create -g x", ["deploy"]), ("az group list", []),
            ("aws lambda update-function-code --function-name f", ["deploy"]), ("aws s3 ls", []),
            ("argocd app sync web", ["deploy"]), ("argocd app list", []), ("kubectl rollout", []),
            ("vercel dev", []), ("vercel", ["deploy"]), ("surge ./dist x.surge.sh", ["deploy"]),
            ("helm", []), ("npm exec -c 'git push'", ["push"]), ("yarn workspace web deploy", ["deploy"]),
            ("yarn npm publish", ["deploy"]), ("npm run", []), ("npm run deploy --dry-run", []),
            ("pnpm deploy out", ["deploy"]), ("bun x vercel deploy", ["deploy"]), ("make -n deploy", []),
            ("mvn -B -f pom.xml deploy", ["deploy"]), ("./run deploy", ["deploy"]), ("deploy --prod", ["deploy"]),
            ("code deploy", []), ("$X deploy", []),
        ):
            with self.subTest(cmd=cmd):
                self.assertEqual(self.actions(cmd), expected)
        self.assertEqual(self.possible("$X deploy"), ["deploy"])

    def test_deploy_names(self):
        for name, expected in (("deploy.sh", True), ("release-notes.sh", False), ("publishToMavenLocal", False),
                               ("build-release", False), ("publish-docs", True), ("", False)):
            with self.subTest(name=name):
                self.assertEqual(sa._deploy_name(name), expected)


# =============================================================================
# Results, payloads and the CLI
# =============================================================================


class ResultTest(Base):
    def test_legacy_first_line(self):
        self.assertEqual(self.run_("ls\ngit status")["legacy_first_line"], "ls")
        self.assertEqual(self.run_("git push && gh pr new --fill")["legacy_first_line"],
                         "gh pr create [gh pr new --fill]")
        self.assertEqual(self.run_("make Deploy")["legacy_first_line"], "deploy [make Deploy]")

    def test_status_values(self):
        self.assertEqual(self.run_("")["status"], "empty")
        self.assertEqual(self.run_("ls 'x")["status"], "parse_failed")
        self.assertEqual(self.run_("ls")["status"], "ok")

    def test_rtk_unwrap(self):
        self.assertEqual(sa.rtk_unwrap("env A=1 rtk git status\nls"), "git status\nls")
        self.assertEqual(sa.rtk_unwrap("env -i rtk git status"), "-i rtk git status")
        self.assertEqual(sa.rtk_unwrap("( rtk ls )"), "( rtk ls )")
        self.assertEqual(sa.rtk_unwrap("A=1"), "")
        self.assertEqual(self.run_("rtk git status")["rtk_unwrapped"], "git status")

    def test_skill_adapter(self):
        for cmd, expected in (
            ("scripts/silver-bullet invoke-skill x", True), ("A=1 scripts/silver-bullet invoke-skill x", True),
            ("A=$(x) scripts/silver-bullet invoke-skill x", False), ("a=(1) scripts/silver-bullet invoke-skill x", False),
            ("scripts/silver-bullet invoke-skill x &", False), ("scripts/silver-bullet invoke-skill x | cat", False),
            ("scripts/silver-bullet invoke-skill x; ls", False), ("scripts/silver-bullet invoke-skill $X", False),
            ("( scripts/silver-bullet invoke-skill x )", False), ("scripts/silver-bullet invoke-skill x >f", False),
            ("env scripts/silver-bullet", False),
        ):
            with self.subTest(cmd=cmd):
                self.assertEqual(sa.is_skill_adapter_invocation(cmd), expected)

    def test_analyze_argv(self):
        res = sa.analyze_argv(["git", "-C", ".", "commit", "-m", "two words", 3], base_dir=str(self.base))
        self.assertEqual((res["actions"], res["status"]), (["commit"], "ok"))
        self.assertEqual(sa.analyze_argv([], base_dir=str(self.base))["status"], "empty")
        self.assertEqual(sa.analyze_argv(["sort", "a", ">", "out\x00"], base_dir=str(self.base))["write_paths"],
                         [self.p("out")])


class PayloadTest(Base):
    def payload(self, obj, **kw):
        text = obj if isinstance(obj, str) else json.dumps(obj)
        return sa.analyze_payload(text, base_dir=str(self.base), **kw)

    def test_payload_status_and_errors(self):
        self.assertEqual(self.payload("")["status"], "empty")
        self.assertEqual(self.payload("{}")["status"], "empty")
        for text in ("{not json", "[1, 2]"):
            with self.subTest(text=text):
                res = self.payload(text)
                self.assertEqual((res["status"], res["error"]), ("parse_failed", "hook payload is not a JSON object"))
        self.assertEqual(self.payload({"tool_name": "Bash", "tool_input": {"command": "ls 'x"}})["status"],
                         "parse_failed")

    def test_shell_payloads(self):
        res = self.payload({"tool_name": "Bash", "tool_input": {"command": "git push"}})
        self.assertEqual((res["tool"]["kind"], res["command"], res["actions"]), ("shell", "git push", ["push"]))
        res = self.payload({"tool_name": "exec_command",
                            "tool_input": {"cmd": ["bash", "-lc", "cd x && echo y > f"], "workdir": "sub"}})
        self.assertEqual(res["command"], "bash -lc 'cd x && echo y > f'")
        self.assertEqual(res["write_paths"], [str(self.base / "sub" / "x" / "f")])
        self.assertEqual(res["base_dir"], str(self.base / "sub"))
        res = self.payload({"tool_input": {"command": "git push", "cmd": "ignored"}})
        self.assertEqual((res["tool"]["kind"], res["actions"]), ("shell", ["push"]))
        res = self.payload({"tool_name": 7, "tool_input": {"command": {"x": 1}}})
        self.assertEqual((res["command"], res["status"]), ("", "empty"))

    def test_mcp_payloads(self):
        res = self.payload({"tool_name": "mcp__github__create_pull_request", "tool_input": {"title": "t"}})
        self.assertEqual((res["tool"]["kind"], res["tool"]["mcp_server"], res["actions"], res["tier"]),
                         ("mcp", "github", ["pr_create"], "completion"))
        self.assertEqual(res["legacy_first_line"], "gh pr create [mcp github create_pull_request]")
        res = self.payload({"tool_name": "mcp__plugin_x__gh__push_files", "tool_input": {}})
        self.assertEqual((res["tool"]["mcp_server"], res["actions"], res["tier"]),
                         ("plugin_x__gh", ["commit", "push"], "intermediate"))
        res = self.payload({"tool_name": "CallMcpTool", "tool_input": {"server": "gh", "toolName": "merge_pull_request"}})
        self.assertEqual(res["actions"], ["pr_merge"])
        res = self.payload({"tool_name": "MCP", "tool_input": {"mcpServer": "gh", "name": "get_me"}})
        self.assertEqual((res["actions"], res["read_only"], res["status"]), ([], False, "ok"))
        res = self.payload({"tool_name": "MCP", "tool_input": {}})
        self.assertEqual((res["tool"]["mcp_server"], res["tool"]["mcp_tool"]), ("", ""))
        res = self.payload({"tool_name": "mcp__github__create_pull_request_with_copilot", "tool_input": {}})
        self.assertEqual(res["actions"], ["pr_create"])
        res = self.payload({"tool_name": "mcp__github__actions_run_trigger", "tool_input": {"method": "run_workflow"}})
        self.assertEqual((res["actions"], res["tier"]), (["deploy"], "completion"))
        res = self.payload({"tool_name": "mcp__github__actions_run_trigger", "tool_input": {"method": "Cancel_Workflow_Run"}})
        self.assertEqual((res["actions"], res["tier"]), ([], "none"))

    def test_edit_patch_and_other_payloads(self):
        res = self.payload({"tool_name": "Write", "tool_input": {"file_path": "src/a.py"}})
        self.assertEqual((res["tool"]["kind"], res["file_path"], res["write_paths"]),
                         ("edit", "src/a.py", []))
        self.assertEqual(res["writes"][0]["path"], self.p("src/a.py"))
        res = self.payload({"tool_name": "Edit", "tool_input": {"file_path": False},
                            "tool_response": {"filePath": "/x/y.py"}})
        self.assertEqual(res["file_path"], "/x/y.py")
        patch = "*** Begin Patch\n*** Update File: a.py\n*** Move to: b.py\n*** Add File: a.py\n*** End Patch"
        res = self.payload({"tool_name": "apply_patch", "tool_input": {"input": patch, "command": "apply_patch"}})
        self.assertEqual((res["tool"]["kind"], res["patch_paths"], res["file_path"], res["command"], res["actions"]),
                         ("patch", ["a.py", "b.py"], "a.py", "apply_patch", []))
        self.assertEqual([w["path"] for w in res["writes"]], [self.p("a.py"), self.p("b.py")])
        res = self.payload({"tool_name": "Read", "tool_input": "*** Delete File: z.py"})
        self.assertEqual((res["tool"]["kind"], res["patch_paths"], res["file_path"]), ("other", ["z.py"], "z.py"))
        res = self.payload({"tool_name": "Edit", "tool_input": {"file_path": "x"}, "tool_response": "not a dict"})
        self.assertEqual(res["file_path"], "x")
        res = self.payload({"tool_name": "Edit", "tool_input": {}, "tool_response": []})
        self.assertEqual(res["file_path"], "")


class LoadRecordsAndCliTest(Base):
    def records(self, result):
        parts = sa.load_records(result).split("\x00")
        return dict(zip(parts[0:-1:2], parts[1::2]))

    def test_load_records(self):
        rec = self.records(sa.analyze_payload(json.dumps(
            {"tool_name": "Bash", "tool_input": {"command": "git push && gh pr create\x00"}}), str(self.base)))
        self.assertEqual((rec["status"], rec["tool_name"], rec["tool_kind"], rec["actions"], rec["tier"]),
                         ("ok", "Bash", "shell", "pr_create push", "completion"))
        self.assertEqual((rec["read_only"], rec["could_be_delivery"], rec["__end__"]), ("false", "false", ""))
        self.assertEqual(json.loads(rec["json"])["schema"], 1)
        rec = self.records(sa.analyze_command("echo x > a; echo y > b", str(self.base)))
        self.assertEqual((rec["tool_name"], rec["tool_kind"], rec["write_paths"]),
                         ("", "shell", self.p("a") + "\n" + self.p("b")))

    def run_main(self, args, stdin_text):
        out = io.BytesIO()
        stdout = mock.Mock(buffer=out)
        with mock.patch("sys.stdin", io.TextIOWrapper(io.BytesIO(stdin_text.encode()))), \
                mock.patch("sys.stdout", stdout):
            code = sa.main(args)
        return code, out.getvalue().decode()

    def test_main_modes(self):
        code, out = self.run_main(["command", "--base-dir", str(self.base)], "git push")
        self.assertEqual((code, json.loads(out)["actions"]), (0, ["push"]))
        code, out = self.run_main(["payload"], json.dumps({"tool_input": {"command": "ls"}}))
        self.assertEqual((code, json.loads(out)["read_only"]), (0, True))
        code, out = self.run_main(["load-command", "--base-dir"], "ls")
        self.assertTrue(out.endswith("__end__\x00\x00"))
        with mock.patch("sys.stderr", io.StringIO()) as err:
            self.assertEqual(sa.main(["bogus"]), 2)
        self.assertIn("usage:", err.getvalue())

    def test_text_streams_without_buffers(self):
        with mock.patch("sys.stdin", io.StringIO("ls")), mock.patch("sys.stdout", io.StringIO()) as out:
            self.assertEqual(sa.main(["command"]), 0)
        self.assertEqual(json.loads(out.getvalue())["read_only"], True)
        self.assertEqual(sa.read_input(["prog", "arg"], 1), "arg")

    def test_analyze_cli_entry_point(self):
        with mock.patch("sys.stdin", io.StringIO("git push")):
            res = run_tool_input_script("analyze.py", "command")
        self.assertEqual((res.code, json.loads(res.stdout)["actions"]), (0, ["push"]))

    def test_cli_runs_as_a_subprocess_with_large_input(self):
        command = "git commit -m x # " + "a" * 300000
        done = subprocess.run([sys.executable, str(TOOL_INPUT_DIR / "analyze.py"), "command"],
                              input=command.encode(), capture_output=True, check=True)
        self.assertEqual(json.loads(done.stdout)["actions"], ["commit"])


class HelperFunctionsTest(unittest.TestCase):
    def test_small_helpers(self):
        self.assertEqual(sa._interpreter_kind("lua5.4"), "lua5.4")
        self.assertFalse(sa._has_flag(["--", "-x"], "x"))
        self.assertEqual(sa._patch_paths("--- /dev/null\n+++ b/x\n+++ c\n", 1), ["x", "c"])
        self.assertIsNone(sa._read_small("/nonexistent/file"))
        self.assertEqual([sa._text(w) for w in sa._split_words("( a b ); c 'd e' $f")], ["c", "d e", "$f"])
        self.assertEqual(sa._split_words("c $f")[1].text, "$f")
        self.assertEqual(sa._sed_effects("s/a/b/gw out\n"), (["out"], False, True))
        self.assertEqual(sa._awk_effects('{print > "/dev/null"}'), ([], False, False))
        self.assertFalse(sa._git_config_safe("pager.log", "sh -c x"))
        self.assertTrue(sa._git_config_safe("pager.log", "false"))


if __name__ == "__main__":
    unittest.main()
