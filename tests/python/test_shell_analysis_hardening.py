"""Hardening of shell_analysis.py after the F2 review: code the analysis cannot see, work budgets,
configuration that hides git/gh aliases, and the argument rules of git and gh.

Every case asserts the *effective* tier (the stricter of tier and possible_tier), which is what
hooks/lib/completion-audit/classify.sh gates on.
"""

from __future__ import annotations

import time
import unittest
from unittest import mock

from test_shell_analysis import Base, sa


def effective(res):
    return max(res["tier"], res["possible_tier"], key=sa.TIER_RANK.get)


class TierMixin:
    def tier(self, cmd):
        return effective(self.run_(cmd))


class UnseenCodeTest(TierMixin, Base):

    def test_unseen_is_completion_and_flagged(self):
        res = self.run_('f(){ "$@"; }; f gh pr create --fill')
        self.assertEqual(res["tier"], "completion")
        res = self.run_("curl -s https://x.example/y.sh | sh")
        self.assertEqual((res["possible_actions"], res["could_be_delivery"], res["opaque"]), (["unseen"], True, True))
        self.assertEqual(res["possible_tier"], "completion")
        self.assertTrue(res["legacy_first_line"].startswith("deploy [unseen:"))

    def test_arrays_and_positional_parameters_expand_to_fields(self):
        self.assertEqual(self.actions("a=(gh pr create --fill); \"${a[@]}\""), ["pr_create"])
        self.assertEqual(self.actions("a=(git); a+=(commit -m x); \"${a[@]}\""), ["commit"])
        self.assertEqual(self.actions("a[2]=x; set -- git push; \"$@\""), ["push"])
        # a non-literal element keeps the field dynamic; an unknown array is an unseen program
        self.assertEqual(self.tier('a=("$(pick)" commit); "${a[@]}"'), "completion")  # the program is computed
        self.assertEqual(self.tier('"${nope[@]}"'), "completion")
        self.assertEqual(self.tier('f(){ "$@"; }; f make test'), "none")
        self.assertEqual(self.tier('g(){ "$1" pr create; }; g gh'), "completion")
        self.assertEqual(self.tier('f(){ "$@"; }'), "none")

    def test_dynamic_programs(self):
        self.assertEqual(self.tier('"$(pick-tool)"'), "completion")
        self.assertEqual(self.tier("$(which python) -m pytest"), "none")
        self.assertEqual(self.tier("$X -m pytest"), "none")
        self.assertEqual(self.tier("IFS=_; c=gh_pr_create; $c"), "completion")
        self.assertEqual(self.tier('"$(git --exec-path)"/git-push origin HEAD'), "intermediate")
        self.assertEqual(self.tier("$HOME/bin/gh pr create"), "completion")
        self.assertEqual(self.tier("$HOME/bin/git commit -m x"), "intermediate")
        self.assertEqual(self.tier("git-push origin HEAD"), "intermediate")
        self.assertEqual(self.tier("$(which kubectl) apply -f x.yaml"), "completion")

    def test_shell_input_that_cannot_be_read(self):
        self.assertEqual(self.tier("echo gh pr create | bash -s foo"), "completion")
        self.assertEqual(self.tier("bash /dev/stdin <<< 'git push'"), "intermediate")
        self.assertEqual(self.tier(". /dev/stdin <<< 'git push'"), "intermediate")
        self.assertEqual(self.tier("source <(curl -s x)"), "completion")
        self.assertEqual(self.tier("bash <(echo hi)"), "completion")
        self.assertEqual(self.tier("curl -s x | python3"), "completion")
        self.assertEqual(self.tier("python3 < prog.py"), "none")  # a program file, opaque like python3 prog.py
        self.assertEqual(self.tier("cat f | python3 /dev/stdin"), "none")  # the file is the program, as in python3 f
        self.assertEqual(self.tier("curl x | python3 /dev/stdin"), "completion")
        self.assertEqual(self.tier("python3 <(echo 1)"), "completion")
        self.assertEqual(self.tier("python3 - <<'E'\nprint(1)\nE"), "none")
        self.assertEqual(self.tier("bash -c \"$CMD\""), "completion")
        self.assertEqual(self.tier("bash"), "none")

    def test_eval(self):
        self.assertEqual(self.tier('eval "$(echo Z2l0 | base64 -d)"'), "completion")
        self.assertEqual(self.tier('eval "$(ssh-agent -s)"'), "none")
        self.assertEqual(self.tier('eval "$(brew shellenv)" && ls'), "none")
        self.assertEqual(self.tier("eval " * 30 + "gh pr create"), "completion")

    def test_builtins_that_execute_what_they_are_given(self):
        for cmd in ("x='a[$(git push)]'; (( x ))", "x='a[$(git push)]'; echo $((x))", "(( a[$(git push)] ))",
                    "x='a[$(git push)]'; [[ $x -eq 0 ]]", "[[ -v 'a[$(git push)]' ]]", "x='a[$(git push)]'; let y=x",
                    "printf -v 'a[$(git push)]' v", "read 'a[$(git push)]' < f", "unset 'a[$(git push)]'",
                    "n='a[$(git push)]'; echo ${!n}", "x='$(git push)'; echo \"${x@P}\"",
                    "x='$(git push)'; declare -a \"a=($x)\"", "a[$(git push)]=1", "mapfile -C \"$CB\" -c 1 a < f"):
            with self.subTest(cmd=cmd):
                self.assertEqual(self.tier(cmd), "completion")
        self.assertEqual(self.tier("mapfile -C 'git push' -c 1 a < f"), "intermediate")
        for cmd in ("n=$((n+1)); echo $n", "(( i++ ))", "x=5; [[ $x -gt 3 ]]", "let n=n+1", "echo $((1+2))",
                    "declare -a arr=(a b)", "printf -v v %s x", "mapfile -t l < f", "read -r a b <<< 'x y'"):
            with self.subTest(cmd=cmd):
                self.assertEqual(self.tier(cmd), "none")
        self.assertEqual(self.ro("echo $((1+2))"), (True, True))
        self.assertEqual(self.ro("echo $((n+1))"), (False, False))
        self.assertEqual(self.ro("[[ $x -eq 0 ]]"), (False, False))

    def test_awk_sed_and_inline_code(self):
        self.assertEqual(self.tier("awk 'BEGIN{system(\"git push\")}'"), "intermediate")
        self.assertEqual(self.tier("awk -v c=\"$X\" 'BEGIN{system(c)}'"), "completion")
        self.assertEqual(self.tier("awk 'BEGIN{printf \"%s\", \"hello\"}'"), "none")
        self.assertEqual(self.tier("echo | sed '1e git push'"), "completion")
        self.assertEqual(self.tier("sed s/a/b/ f"), "none")
        self.assertEqual(self.tier("python3 -c 'import os; os.system(\"gi\"+\"t push\")'"), "completion")
        self.assertEqual(self.tier("python3 -c 'import subprocess; subprocess.run([\"ls\"])'"), "none")
        self.assertEqual(self.tier("python3 -c 'import requests; requests.post(\"https://api.github.com/repos/o/r/pulls\")'"),
                         "completion")

    def test_runners(self):
        self.assertEqual(self.tier("script -qc 'git push' /dev/null"), "intermediate")
        self.assertEqual(self.tier("su -c 'git push' deploy"), "intermediate")
        self.assertEqual(self.tier("runuser -u u -c 'git push'"), "intermediate")
        self.assertEqual(self.tier('su -c "$X" deploy'), "completion")
        self.assertEqual(self.tier("su - deploy"), "none")

    def test_coproc_and_parse_failures(self):
        self.assertEqual(self.tier("coproc NAME { gh pr create; }"), "completion")
        self.assertEqual(self.tier("coproc cat"), "none")
        self.assertEqual(self.tier("coproc ( git push )"), "intermediate")
        res = self.run_("$((true); G=gh; $G pr create --fill)")
        self.assertEqual((res["status"], effective(res)), ("parse_failed", "completion"))
        self.assertEqual(self.tier("eval 'echo ('"), "completion")

    def test_function_definition_is_not_a_call(self):
        res = self.run_('wrap(){ "$@"; }')
        self.assertEqual((res["possible_actions"], res["opaque"]), ([], False))
        self.assertEqual(self.tier('w(){ eval "$X"; }'), "none")

    def test_echo_and_printf_escapes_are_not_guessed(self):
        self.assertEqual(self.tier("$(printf '\\x67it') commit -m x"), "completion")  # computed program: unseen
        self.assertEqual(self.tier("$(printf 'a\\qb') x"), "completion")  # whatever it prints runs
        self.assertEqual(self.tier("$(printf 'git\\') commit -m x"), "completion")
        self.assertEqual(self.tier("$(printf '%b' 'a\\x67') commit -m x"), "completion")
        self.assertEqual(self.tier('sh -c \'G=$(echo "\\0147it"); $G commit -m x\''), "completion")
        self.assertEqual(self.tier("$(echo -e 'a\\x67') commit -m x"), "completion")
        self.assertEqual(self.tier("$(echo -e 'a\\tb') commit -m x"), "none")
        self.assertEqual(self.sa_echo(["-e", "a\\tb"]), "a\tb\n")

    def test_expansion_corners(self):
        self.assertEqual(self.tier('f(){ echo "$*"; }; f a b'), "none")
        self.assertEqual(self.tier("n=x; echo ${!n}"), "none")
        self.assertEqual(self.tier("a+=(gh pr create); \"${a[@]}\""), "completion")
        self.assertEqual(self.tier("a=(gh pr create); a[1]=x; \"${a[@]}\" --fill"), "completion")
        self.assertEqual(self.tier("a=(git push); a[0]=ls; \"${a[@]}\""), "completion")
        self.assertEqual(self.tier('"$UNKNOWN/gh" pr create'), "completion")
        self.assertEqual(self.tier('"$UNKNOWN/git" commit -m x'), "intermediate")
        self.assertEqual(self.tier("python3"), "none")
        self.assertEqual(len(self.run_("eval \"$A\"; eval \"$B\"")["opaque_reasons"]), 2)
        self.assertEqual(self.run_("eval \"$A\"; eval \"$B\"")["possible_actions"], ["unseen"])
        self.assertEqual(self.tier("a[0]=x; echo ok"), "none")

    @staticmethod
    def sa_echo(args):
        return sa._echo_output(args)


class BudgetTest(Base):
    def nested_loops(self, depth):
        body = "git push"
        for i in range(depth):
            body = "for v%d in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16; do %s; done" % (i, body)
        return body

    def test_nested_loops_stop_at_the_budget(self):
        started = time.monotonic()
        res = self.run_(self.nested_loops(6) + "; gh pr create --fill")
        self.assertLess(time.monotonic() - started, 20)
        self.assertEqual(res["possible_tier"], "completion")
        self.assertIn("analysis budget exceeded", res["opaque_reasons"])

    def test_call_chains_stop_at_the_budget(self):
        funcs = ["f%d(){ f%d; f%d; }" % (i, i + 1, i + 1) for i in range(20)]
        started = time.monotonic()
        res = self.run_("; ".join(funcs + ["f20(){ gh pr create; }", "f0"]))
        self.assertLess(time.monotonic() - started, 20)
        self.assertEqual(effective(res), "completion")

    def test_oversized_input_is_unseen(self):
        with mock.patch.object(sa, "MAX_INPUT_CHARS", 100):
            res = self.run_("echo " + "a" * 200)
            self.assertEqual((res["possible_actions"], res["opaque_reasons"]), (["unseen"], ["command too large to analyze"]))
            res = sa.analyze_argv(["echo", "a" * 200], str(self.base))
            self.assertEqual(res["possible_actions"], ["unseen"])
        self.assertEqual(self.possible("git push " + "# x" * 100000), [])

    def test_parse_time_budget(self):
        with mock.patch.object(sa, "MAX_PARSE_SECONDS", -1.0):
            res = self.run_("ls; " * 200)
        self.assertEqual((res["status"], effective(res)), ("parse_failed", "completion"))

    def test_time_budget_of_the_walk(self):
        with mock.patch.object(sa, "MAX_SECONDS", -1.0):
            res = self.run_("ls; " * 200)
        self.assertEqual(effective(res), "completion")
        self.assertIn("analysis budget exceeded", res["opaque_reasons"])

    def test_huge_brace_sequences_are_dynamic(self):
        res = self.run_("echo {1..30000000}; G=gh; $G pr create --fill")
        self.assertEqual(res["actions"], ["pr_create"])

    def test_git_config_count_is_bounded(self):
        for count in ("99999999", "²", "1e3", "-1", ""):
            with self.subTest(count=count):
                res = self.run_("GIT_CONFIG_COUNT=%s git status; git ci -m x" % count)
                self.assertEqual(effective(res), "intermediate")
        self.assertEqual(effective(self.run_("GIT_CONFIG_COUNT=100 git ci -m x")), "intermediate")
        res = self.run_("GIT_CONFIG_COUNT=2 GIT_CONFIG_KEY_0=alias.ci GIT_CONFIG_VALUE_0=commit "
                        "GIT_CONFIG_KEY_1=include.path GIT_CONFIG_VALUE_1=/tmp/x git ci -m x")
        self.assertEqual(res["actions"], ["commit"])

    def test_an_analyzer_fault_is_reported_not_raised(self):
        with mock.patch.object(sa._Analysis, "walk_script", side_effect=ValueError("boom")):
            res = self.run_("git push")
        self.assertEqual((res["status"], res["error"], effective(res)),
                         ("parse_failed", "analyzer error: ValueError", "completion"))
        with mock.patch.object(sa._Analysis, "walk_script", side_effect=RecursionError):
            res = sa.analyze_command("git push", str(self.base))
        self.assertEqual((res["status"], effective(res)), ("ok", "completion"))
        with mock.patch.object(sa._Analysis, "execute", side_effect=ValueError("boom")):
            res = sa.analyze_argv(["git", "push"], str(self.base))
        self.assertEqual(res["status"], "parse_failed")
        with mock.patch.object(sa, "MAX_STEPS", 0):
            self.assertEqual(effective(self.run_("ls")), "completion")


class ConfigAndAliasTest(TierMixin, Base):

    def test_config_that_hides_aliases_makes_unknown_subcommands_possible_commits(self):
        for cmd in ("G=commit git --config-env=alias.ci=G ci -m x", "git --config-env alias.ci=G ci -m x",
                    "printf '[alias]\\n\\tci = commit\\n' >> .git/config; git ci -m x",
                    "HOME=/tmp/h git ci -m x", "export HOME=/tmp/h; git ci -m x", "GIT_CONFIG_GLOBAL=/tmp/x git ci -m x",
                    "XDG_CONFIG_HOME=/tmp/h git ci -m x", "git -c include.path=/tmp/a git ci -m x",
                    "git config include.path /tmp/a && git ci -m x", "git config alias.ci \"$X\" && git ci -m x",
                    "echo x >> ~/.gitconfig; git ci -m x", "GIT_CONFIG_PARAMETERS=\"'alias.ci'='$X'\" git ci -m x"):
            with self.subTest(cmd=cmd):
                self.assertEqual(self.tier(cmd), "intermediate")
        self.assertEqual(self.tier("git -c include.path=/tmp/a ci -m x"), "intermediate")
        # a plain unknown subcommand (an external git-<name> program, or a typo) is not delivery
        self.assertEqual(self.tier("git lfs ls-files"), "none")
        self.assertEqual(self.tier("git frobnicate"), "none")
        self.assertEqual(self.tier("git config --get alias.ci"), "none")
        self.assertEqual(self.tier("git config alias.ci commit && git ci -m x"), "intermediate")

    def test_possible_push_from_visible_arguments(self):
        res = self.run_("HOME=/tmp/h git sync origin")
        self.assertEqual(res["possible_actions"], ["push"])

    def test_gh_aliases(self):
        self.assertEqual(self.tier("gh alias set pc 'pr create' && gh pc --fill"), "completion")
        self.assertEqual(self.tier("gh alias import f.yml && gh pc"), "completion")
        self.assertEqual(self.tier("gh pc --fill"), "none")

    def test_gh_api_graphql_and_credentials(self):
        for cmd in ("gh api graphql -F query=@q.graphql", "gh api graphql --input q.json",
                    "gh api graphql -f query=\"$(cat q)\""):
            with self.subTest(cmd=cmd):
                self.assertEqual(self.tier(cmd), "completion")
        self.assertEqual(self.tier("gh api graphql -f query='query { viewer { login } }'"), "none")
        self.assertEqual(self.tier("gh auth status"), "none")
        # handing out the token is not delivery: what uses it (curl, gh api, git push) is judged on its own
        for cmd in ("gh auth token", "TOKEN=$(gh auth token)", "GH_TOKEN=$(gh auth token) npm run e2e",
                    'curl -H "Authorization: Bearer $(gh auth token)" https://api.github.com/user'):
            self.assertEqual(self.tier(cmd), "none")
        self.assertEqual(self.tier('curl -X POST -H "Authorization: Bearer $(gh auth token)" https://api.github.com/repos/o/r/pulls'),
                         "completion")
        self.assertEqual(self.tier("gh repo sync"), "completion")
        self.assertEqual(self.tier("gh release upload v1 a.tgz"), "completion")
        self.assertEqual(self.tier("gh release edit v1 --notes x"), "completion")
        self.assertEqual(self.tier("gh api -X POST repos/o/r/merge-upstream -f branch=main"), "completion")
        self.assertEqual(self.tier("gh api repos/o/r/dispatches -f event_type=x"), "completion")
        self.assertEqual(self.tier("gh api repos/o/r/actions/workflows/ci.yml/dispatches -f ref=main"), "none")

    def test_raw_http_to_the_github_api(self):
        for cmd in ("curl -X POST https://api.github.com/repos/o/r/pulls", "curl -d @b https://api.github.com/repos/o/r/pulls",
                    "curl -XPUT https://api.github.com/repos/o/r/pulls/5/merge",
                    "curl --request POST --url https://api.github.com/repos/o/r/releases",
                    "curl --json @b https://api.github.com/repos/o/r/releases",
                    "curl --data-binary @a https://uploads.github.com/repos/o/r/releases/1/assets",
                    "curl -X POST https://ghe.example.com/api/v3/repos/o/r/pulls",
                    "curl -X POST api.github.com/repos/o/r/pulls",
                    "wget --post-data=x https://api.github.com/repos/o/r/releases",
                    "wget --method=PUT https://api.github.com/repos/o/r/contents/f",
                    "http POST api.github.com/repos/o/r/pulls", "https api.github.com/repos/o/r/pulls title=x",
                    "xh POST https://api.github.com/repos/o/r/releases", 'curl -X POST "https://api.github.com/repos/$R/pulls"',
                    "curl -X DELETE $URL/repos/o/r/git/refs/heads/x" if False else "curl -X POST https://api.github.com/$P"):
            with self.subTest(cmd=cmd):
                self.assertEqual(self.tier(cmd), "completion")
        for cmd in ("curl https://api.github.com/repos/o/r/pulls", "curl -s https://example.com -X POST",
                    "wget -q https://api.github.com/repos/o/r", "http GET api.github.com/repos/o/r",
                    "curl -X POST https://api.github.com/repos/o/r/issues", 'curl "https://api.github.com/repos/$R/pulls"',
                    "http example.com"):
            with self.subTest(cmd=cmd):
                self.assertEqual(self.tier(cmd), "none")


class GitArgumentRulesTest(TierMixin, Base):

    def test_help_is_an_option_only_where_git_and_gh_read_options(self):
        self.assertEqual(self.tier("git commit --allow-empty -m --help"), "intermediate")
        self.assertEqual(self.tier("git commit -m x -- -h"), "intermediate")
        self.assertEqual(self.tier("git commit -h"), "none")
        # git honours --help only as the first argument; later it may be the value of an option it does not list
        self.assertEqual(self.tier("git commit -m x --help"), "intermediate")
        self.assertEqual(self.tier("git commit --help"), "none")
        self.assertEqual(self.tier("git merge --no-edit --into-name --help other"), "intermediate")
        self.assertEqual(self.tier("gh pr create --fill --title -h"), "completion")
        self.assertEqual(self.tier("gh pr create -h"), "none")
        self.assertEqual(self.tier("gh pr create --body-file f --help"), "none")

    def test_merge_dash_n_is_no_stat(self):
        self.assertEqual(self.tier("git merge -n other"), "intermediate")
        self.assertEqual(self.tier("git merge --no-commit other"), "none")
        self.assertEqual(self.tier("git cherry-pick -n abc"), "none")
        self.assertEqual(self.tier("git revert -n abc"), "none")
        self.assertEqual(self.tier("git revert abc"), "intermediate")

    def test_commits_that_move_refs(self):
        for cmd in ("git pull --no-rebase . other", "git pull . other", "git branch -f main abc", "git branch -M main",
                    "git branch -C a b", "git branch --force main abc", "git branch --move a b",
                    "git subtree add --prefix=lib url main", "git subtree merge --prefix=lib main",
                    "git subtree pull --prefix=lib url main", "git subtree push --prefix=dist origin gh-pages",
                    "git http-push origin master", "git reset --soft $(git stash create)", "git reset --mixed \"$REV\"",
                    "git hash-object -tw blob f"):
            with self.subTest(cmd=cmd):
                self.assertEqual(self.tier(cmd), "intermediate")
        for cmd in ("git pull", "git pull --ff-only", "git pull origin main", "git stash", "git branch feature",
                    "git branch -d old", "git branch -u origin/main", "git branch", "git checkout -B feat origin/main",
                    "git switch -C feat", "git reset --soft HEAD~1", "git subtree split --prefix=a", "git hash-object f"):
            with self.subTest(cmd=cmd):
                self.assertEqual(self.tier(cmd), "none")

    def test_other_forges_and_vcs_front_ends(self):
        for cmd in ("glab mr create --fill", "glab mr merge 1", "tea pr create", "tea pr merge 3", "lab mr create",
                    "az repos pr create --title x", "glab release create v1", "jj git push", "sl push"):
            with self.subTest(cmd=cmd):
                self.assertNotEqual(self.tier(cmd), "none")
        for cmd in ("glab mr list", "tea pr list", "az repos pr list", "jj log", "sl status", "jj git fetch"):
            with self.subTest(cmd=cmd):
                self.assertEqual(self.tier(cmd), "none")

    def test_deploy_targets(self):
        for cmd in ("ssh deploy@prod systemctl restart app", "ssh deploy@prod", "rsync -av dist/ deploy@prod:/srv",
                    "scp a.tar deploy@prod:/opt/", "sftp release@host", "./deploy/run.sh", "bash scripts/release/ship.sh",
                    "python -m twine upload dist/*", "python3 -m cargo publish" if False else "python -m twine upload x"):
            with self.subTest(cmd=cmd):
                self.assertEqual(self.tier(cmd), "completion")
        for cmd in ("ssh dev@host ls", "ssh deploy@host cat /var/log/app.log", "ssh host systemctl status app",
                    "ssh", "scp a.txt dev@host:/tmp/", "cat deploy/README.md", "ls deploy/", "./scripts/test.sh",
                    "bash scripts/release/check.sh", "python -m twine check dist/*", "python -m pytest"):
            with self.subTest(cmd=cmd):
                self.assertEqual(self.tier(cmd), "none")


class ReadOnlyHardeningTest(Base):
    def test_execution_capable_forms_are_not_read_only(self):
        for cmd in ("git ls-remote --upload-pack='touch X' .", "git ls-remote --exec='touch x' .", "git ls-remote -u 'x' .",
                    "mapfile -C 'touch zz #' -c 1 a < f", "hash -p /usr/bin/touch cat", "git config --unset core.hooksPath",
                    "git config --remove-section x", "git config --add a.b c", "history -w out", "history -c",
                    "file -C -m magic", "file --compile -m magic", "x='$(touch zz)'; echo ${!x}",
                    "npm test", "yarn test", "pnpm test", "npm run test:unit"):
            with self.subTest(cmd=cmd):
                self.assertEqual(self.ro(cmd), (False, False))
        for cmd in ("git ls-remote origin", "git ls-remote --heads origin", "git config --get user.name", "history",
                    "history | tail -3", "file x.bin", "hash -r", "hash"):
            with self.subTest(cmd=cmd):
                self.assertEqual(self.ro(cmd), (True, True))
        self.assertEqual(self.ro("jest"), (False, True))


class ParserTest(Base):
    def test_coproc_names(self):
        self.assertEqual(self.tier_of("coproc NAME { true; }"), "none")
        self.assertEqual(self.tier_of("coproc NAME ( git push )"), "intermediate")

    def tier_of(self, cmd):
        return effective(self.run_(cmd))

    def test_process_substitutions_are_walked(self):
        self.assertEqual(self.tier_of("diff <(git push) <(ls)"), "intermediate")


if __name__ == "__main__":
    unittest.main()
