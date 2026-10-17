"""Unit tests for hooks/lib/tool-input/command_looks_read_only.py.

The script takes a shell command and exits 0 (printing "read-only") only when every
segment of it is a known read-only command; anything that may write, or that it cannot
parse, exits 1.
"""

import unittest

from tool_input_support import run_tool_input_script


def verdict(command):
    res = run_tool_input_script("command_looks_read_only.py", command)
    return res.code, res.stdout


class CommandLooksReadOnlyTest(unittest.TestCase):
    def assertReadOnly(self, command):
        self.assertEqual(verdict(command), (0, "read-only\n"), command)

    def assertMayWrite(self, command):
        self.assertEqual(verdict(command), (1, ""), command)

    # --- plain commands ---------------------------------------------------
    def test_known_read_only_commands_pass(self):
        for cmd in ("ls -la", "cat a | grep x | wc -l", "pwd && date", "echo hi; basename /a/b", "jq . f"):
            with self.subTest(cmd=cmd):
                self.assertReadOnly(cmd)

    def test_blank_and_comment_only_payloads_are_read_only(self):
        self.assertReadOnly("")
        self.assertReadOnly("   \n  ")
        self.assertReadOnly("# just a comment")
        self.assertReadOnly("ls\n# trailing comment\n")

    def test_unknown_command_may_write(self):
        for cmd in ("rm -rf x", "touch f", "ls && rm f", "python3 x.py"):
            with self.subTest(cmd=cmd):
                self.assertMayWrite(cmd)

    def test_assignment_only_segment_is_ignored(self):
        self.assertReadOnly("FOO=1")
        self.assertReadOnly("FOO=1 ls")
        self.assertReadOnly("env FOO=1 ls")

    def test_unparseable_segment_may_write(self):
        self.assertMayWrite("echo 'unterminated")
        self.assertMayWrite("ls; echo \"unterminated")

    # --- splitting respects quotes ---------------------------------------
    def test_operators_inside_quotes_do_not_split(self):
        self.assertReadOnly("echo 'a; rm b'")
        self.assertReadOnly('echo "a && rm b | c"')
        self.assertReadOnly('echo "say \\"hi\\" ; there"')
        self.assertReadOnly("echo 'it\"s' \"and 'that'\"")

    def test_unquoted_operators_split_into_checked_segments(self):
        self.assertMayWrite("ls; rm f")
        self.assertMayWrite("ls && rm f")
        self.assertMayWrite("ls || rm f")
        self.assertMayWrite("ls | rm f")
        self.assertMayWrite("ls\nrm f")

    # --- redirects --------------------------------------------------------
    def test_writing_redirects_are_not_read_only(self):
        for cmd in ("echo hi > f", "echo hi >> f", "ls 2> err", "echo hi >f", 'echo hi > "a b"', "ls &> f"):
            with self.subTest(cmd=cmd):
                self.assertMayWrite(cmd)

    def test_discarding_redirects_stay_read_only(self):
        for cmd in ("ls > /dev/null", "ls 2>/dev/null", "ls >> /dev/null", "ls > /x/dev/null", "ls > NUL", "ls > nul"):
            with self.subTest(cmd=cmd):
                self.assertReadOnly(cmd)

    def test_quoted_redirect_like_arguments(self):
        # Embedded redirect inside a single token (quotes hid it from the regex).
        self.assertMayWrite("echo '>>foo'")
        self.assertMayWrite("echo '>foo'")
        self.assertMayWrite("echo '2>foo'")
        self.assertMayWrite("echo '&>>foo'")
        self.assertReadOnly("echo '2>/dev/null'")
        self.assertReadOnly("echo '>>/dev/null'")
        self.assertReadOnly("echo '>>'")
        self.assertReadOnly("echo '>'")
        self.assertReadOnly("echo 'a>b'")

    def test_separate_redirect_token_with_target(self):
        self.assertMayWrite("echo '>' f")          # echo/printf redirect stdout
        self.assertMayWrite("cat a '>' b")         # operand before the operator
        self.assertMayWrite("cat a '2>' b")
        self.assertReadOnly("ls '>' f")            # no prior operand, not echo: literal args
        self.assertReadOnly("echo '>' /dev/null")  # discard target
        self.assertReadOnly("cat a '>'")           # operator is the last token
        self.assertReadOnly("cat a '>' --")        # "--" is not a target

    # --- shell -c unwrapping ---------------------------------------------
    def test_shell_dash_c_is_unwrapped(self):
        self.assertReadOnly("bash -c 'ls | wc -l'")
        self.assertReadOnly("sh -c \"git status\"")
        self.assertMayWrite("bash -c 'echo hi > f'")
        self.assertMayWrite("zsh -lc 'rm f'")
        self.assertReadOnly("ls; bash -c 'pwd'")
        self.assertMayWrite("ls; bash -c 'touch f'")

    def test_shell_without_dash_c_is_not_read_only(self):
        self.assertMayWrite("bash script.sh")
        self.assertMayWrite("bash -c")

    # --- git ---------------------------------------------------------------
    def test_git_read_only_subcommands(self):
        for cmd in (
            "git status", "git log --oneline", "git diff HEAD", "git -C repo show", "git -c a=b branch",
            "git --no-pager log", "git ls-files", "git rev-parse HEAD",
        ):
            with self.subTest(cmd=cmd):
                self.assertReadOnly(cmd)

    def test_git_writing_or_bare_commands(self):
        for cmd in ("git commit -m x", "git push", "git", "git -C", "git --no-pager"):
            with self.subTest(cmd=cmd):
                self.assertMayWrite(cmd)

    # --- graphify ----------------------------------------------------------
    def test_graphify_query_path_explain(self):
        for cmd in ("graphify query x", "graphify path A B", "graphifyy explain y", "graphify --quiet query q"):
            with self.subTest(cmd=cmd):
                self.assertReadOnly(cmd)

    def test_graphify_other_subcommands_may_write(self):
        for cmd in ("graphify update .", "graphify", "graphify --quiet"):
            with self.subTest(cmd=cmd):
                self.assertMayWrite(cmd)

    # --- test runners ------------------------------------------------------
    def test_test_runners_are_allowed(self):
        for cmd in (
            "node --test tests/", "node --test=x", "jest", "mocha --watch", "tap", "vitest run",
            "npm test", "npm t", "npm run test", "npm run test:unit", "pnpm test", "npm -C pkg test",
            "npm --prefix pkg test", "npm -- test", "npm exec -- jest", "npm exec vitest run",
            "npm exec -- npm test", "yarn test", "yarn jest", "yarn vitest", "yarn run test:ci",
            "yarn --silent test", "npx vitest", "npx --yes jest", "npx npm test",
        ):
            with self.subTest(cmd=cmd):
                self.assertReadOnly(cmd)

    def test_non_test_invocations_of_runner_binaries_may_write(self):
        for cmd in (
            "node script.js", "npm", "npm install", "npm run build", "npm run", "npm exec", "npm exec --",
            "npm exec eslint", "pnpm", "yarn", "yarn build", "yarn run build", "yarn run", "npx", "npx --yes",
            "npx eslint", "npm --", "yarn --",
        ):
            with self.subTest(cmd=cmd):
                self.assertMayWrite(cmd)

    # --- sed ---------------------------------------------------------------
    def test_sed_is_read_only_unless_in_place(self):
        self.assertReadOnly("sed -n 1p f")
        self.assertReadOnly("sed -E s/a/b/ f")
        self.assertMayWrite("sed -i s/a/b/ f")
        self.assertMayWrite("sed -i.bak s/a/b/ f")


if __name__ == "__main__":
    unittest.main()
