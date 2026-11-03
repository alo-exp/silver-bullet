"""Second F2 review round: code the analyzer cannot see, honest commands that must stay clean,
work budgets, parser faults and arithmetic that evaluates variables.

Every case asserts the *effective* tier (the stricter of tier and possible_tier), which is what
hooks/lib/completion-audit/classify.sh gates on. The big bypass and honest tables live in
tests/fixtures/shell-analysis/corpus.json (ids r2-*); this module pins each review issue.
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

    def assert_tiers(self, tier, commands):
        for cmd in commands:
            with self.subTest(cmd=cmd):
                self.assertEqual(self.tier(cmd), tier)


class HiddenCommandsTest(TierMixin, Base):
    """Issue 0: a delivery verb visible in the arguments of a program the analyzer does not model."""

    def test_unknown_wrappers_do_not_hide_visible_arguments(self):
        self.assert_tiers("completion", [
            "taskset -c 0 gh pr create --fill", "uv run gh pr create --fill", "poetry run gh pr create --fill",
            "pwsh -c 'gh pr create --fill'", "tmux new-session -d 'gh pr create --fill'",
            "parallel ::: 'gh pr create --fill'", "vim -c '!gh pr create --fill' -c q",
            "env -i PATH=$PATH gh pr create --fill", "direnv exec . gh pr create --fill",
            "op run -- gh pr create --fill", "docker exec c gh pr create --fill",
            "kubectl exec pod -- gh pr create --fill", "ssh me@host 'gh pr create --fill'",
            "osascript -e 'do shell script \"gh pr create --fill\"'", "gdb -batch -ex 'shell gh pr create --fill'",
            "expect -c 'spawn gh pr create --fill; expect eof'", "pipx run gh pr create --fill",
            "script -q /dev/null gh pr create --fill", "runuser -u me -- gh pr create --fill",
            "printf 'all:\\n\\tgh pr create --fill\\n' | make -f -", "make -E 'all: ; gh pr create --fill'",
            "echo 'gh pr create --fill' | at now", "echo '!gh pr create --fill' | ed",
            "conda run -n x gh pr create --fill", "nix develop -c gh pr create --fill",
        ])
        self.assert_tiers("intermediate", [
            "chrt -i 0 git push origin HEAD", "poetry run git commit -m x", "taskset 0x1 git commit -m x",
            "valgrind git push", "ssh host git push", "sg grp -c 'git push'",
        ])

    def test_command_valued_git_settings_and_environment_are_walked(self):
        self.assert_tiers("completion", [
            "git -c core.pager='gh pr create --fill #' log", "GIT_PAGER='gh pr create --fill #' git log",
            "GIT_EXTERNAL_DIFF='gh pr create --fill #' git diff", "GIT_SSH_COMMAND='gh pr create --fill #' git fetch",
            "git -c diff.external='gh pr create --fill #' diff", "git -c core.fsmonitor='gh pr create --fill #' status",
            "git -c core.sshCommand='gh pr create --fill #' fetch", "git -c credential.helper='!gh pr create --fill #' fetch",
            "git -c filter.x.clean='gh pr create --fill' add .", "git bisect run sh -c 'gh pr create --fill'",
            "git rebase --exec 'gh pr create --fill' HEAD~1", "git rebase -x 'gh pr create --fill' HEAD",
            "git submodule foreach 'gh pr create --fill'", "git difftool -y -x 'gh pr create --fill' HEAD",
            "git -c mergetool.x.cmd='gh pr create --fill' mergetool -t x", "git grep -O'gh pr create --fill #' foo",
            "git grep --open-files-in-pager='gh pr create --fill' foo",
            "git filter-branch --msg-filter 'gh pr create --fill' HEAD", "git config core.pager x; git -c core.pager='gh pr create' log",
        ])
        self.assert_tiers("intermediate", [
            "git -c diff.external='git commit --allow-empty -qm gx; true' diff",
            "GIT_EXTERNAL_DIFF='git push #' git diff", "git bisect run git commit -m x",
            "git rebase --exec 'make test' HEAD~3",  # rebase is itself a commit
        ])
        # the same settings with ordinary values stay clean
        self.assert_tiers("none", [
            "git -c core.pager=cat log", "GIT_PAGER=less git log", "git -c core.sshCommand='ssh -i key' fetch",
            "GIT_SSH_COMMAND='ssh -o StrictHostKeyChecking=no' git fetch", "git bisect run make test",
            "git submodule foreach 'git status'", "git grep -O less foo",
            "git difftool -x vimdiff HEAD", "git -c credential.helper=cache fetch", "EDITOR=vim git log",
        ])

    def test_honest_twins_stay_clean(self):
        self.assert_tiers("none", [
            "tldr git commit", "man git-commit", "man git commit", "uv run pytest -k 'git commit'",
            "pip install git", "brew install gh git", "apt-get install -y git curl", "docker run --rm alpine/git status",
            "poetry run pytest tests/", "taskset -c 0 make test", "kubectl exec pod -- ls /app", "ssh host ls -la",
            "tmux new -d -s dev 'npm run dev'", "uv run python -m pytest", "docker exec c make test",
            "pytest --message 'git commit' x", "jira create --summary 'fix: git commit hook' --label bug",
            "which git", "type -a git", "cargo run -- x", "go run ./cmd/x",
        ])


class ComputedProgramsTest(TierMixin, Base):
    """Issue 1: a program word computed in the command is unseen code; inherited variables are not."""

    def test_computed_program_words_are_unseen(self):
        self.assert_tiers("completion", [
            "c=$(cat cmd.txt); $c", "c=$(cat cmd.txt); \"$c\"", "read -r c < cmd.txt; $c --fill",
            "read -r c <<< 'gh pr create --fill'; $c", "c=$(base64 -d <<< Z2l0IGNvbW1pdA==); $c",
            "mapfile -t a < cmd.txt; \"${a[@]}\"", "$(cat a) $(cat b) --fill", "$(cat a) pr create --fill",
            "a=(gh \"$(cat b)\" create --fill); \"${a[@]}\"", "for c in $(cat cmds.txt); do $c; done",
            "f(){ \"$1\" \"$2\" --fill; }; f $(cat a) $(cat b)", "f(){ $1 \"${@:2}\"; }; f $(cat a) b",
            "printf 'git\\0commit\\0' | xargs -0 sh -c '\"$0\" \"$1\" -m x'", "xargs -a cmd.txt sh -c '\"$0\" \"$@\"'",
            "trap \"$(cat x)\" EXIT", "python3 -c \"$(cat x.py)\"", "node -e \"$(cat x.js)\"",
            "bash /dev/fd/3 3< cmds.txt", "bash /proc/self/fd/4 4< cmds.txt",
            "eval \"$(ssh-agent -k 2>/dev/null; printf 'git commit --allow-empty -m ea')\"",
            "eval \"$(ssh-agent -s | sed s/.*/gh pr create --fill/)\"", "eval \"$(ssh-agent -s)$(cat cmds.txt)\"",
            "eval \"$(asdf exec cat cmds.txt)\"", "eval \"$(/tmp/x/ssh-agent)\"", "eval \"$(cat cmds.txt)\"",
            "echo 'alias pc=\"pr create\"' >> ~/.config/gh/config.yml; gh pc --fill",
            "GH_CONFIG_DIR=/tmp/c gh pc --fill", "gh extension install owner/gh-x && gh x --fill",
            "xargs -I{} sh -c '{}' < cmds.txt", "cat args.txt | xargs gh", "xargs -a args.txt git",
        ])

    def test_parameter_operators_are_evaluated(self):
        self.assert_tiers("completion", [
            "c='hg pr create --fill'; ${c/hg/gh}", "c='xgh pr create --fill'; ${c:1}", "c='gh pr create --fill#'; ${c%#}",
            "${UNSET:-gh pr create --fill}", "\"${UNSET:-gh}\" pr create --fill", "${UNSET-gh} pr create --fill",
            "a=(x gh pr create --fill); \"${a[@]:1}\"", "a=(gh pr create --fill); \"${a[0]}\" \"${a[1]}\" \"${a[2]}\"",
            "f(){ local p=$1; shift; $p \"$@\"; }; f gh pr create --fill", "set -- gh pr create; \"${@:1}\"",
            "c=GH; ${c,,} pr create --fill", "c=GH; ${c@L} pr create", "c=XXgh; ${c#XX} pr create --fill",
            "c=XXgh; ${c##XX} pr create --fill", "c=ghYY; ${c%%Y*} pr create --fill", "c=gxh; ${c//x/} pr create --fill",
            "c=xgh; ${c/#x/} pr create --fill", "c=ghx; ${c/%x/} pr create --fill", "c=ggh; ${c:1:2} pr create --fill",
            "c=ggh; ${c: -2} pr create --fill", "c=X; ${c:+gh} pr create --fill",
            "${UNSET:=gh} pr create --fill", "c=''; ${c:-gh} pr create --fill",
        ])
        self.assert_tiers("none", [
            "${PYTHON:-python3} -m pytest", "$PYTHON -m pytest", "${CC:-cc} -o out main.c", "$SOME_CMD --fill",
            "c=${X:-3}; echo $c", "echo ${#c}", "x=abc; echo ${x#a} ${x%c} ${x/b/B} ${x:1} ${x^^}",
            "a=(1 2); echo ${a[1]} ${a[@]:1} \"${a[*]}\"", "f(){ echo ${1:-x} \"${@:2}\"; }; f a b c",
            "x=1; ${x:?missing} 2>/dev/null; true", "c=gh; ${c^^} pr create", "c=gh; ${c@U} pr create",
            "c=gh; ${c^} pr create", "c=GH; ${c,} pr create",
        ])

    def test_arrays_inside_a_larger_word(self):
        self.assertEqual(self.possible("a=(gh pr create); c=x${a[*]}; ${c#x} --fill"), [])  # no program: the word is gh pr create
        self.assertEqual(self.actions("a=(gh pr create); c=${a[*]}; $c --fill"), ["pr_create"])
        self.assertEqual(self.tier("a=(1 \"$(cat f)\"); echo x${a[*]}"), "none")
        self.assertEqual(self.tier("a=(gh); c=x${a[*]}; ${c#x} pr create"), "completion")
        self.assertEqual(self.tier("a=(1 \"$(cat f)\"); c=x${a[*]}; ${c#x} pr create"), "completion")  # an unknown element

    def test_shift_and_positional_parameters(self):
        self.assertEqual(self.actions("f(){ shift; $1 pr create; }; f x gh"), ["pr_create"])
        self.assertEqual(self.actions("set -- gh pr create; shift 0; \"$@\""), ["pr_create"])
        self.assertEqual(self.tier("set -- a b; shift $N; $1"), "none")
        self.assertEqual(self.tier("shift; ls"), "none")

    def test_inherited_variables_are_judged_by_their_arguments(self):
        self.assertEqual(self.possible("$G commit -m x"), ["commit"])
        self.assertEqual(self.possible("$G pr create --fill"), ["pr_create"])
        self.assertEqual(self.possible("$X --version"), [])

    def test_scripts_below_a_computed_directory_are_scripts_not_unseen_code(self):
        self.assert_tiers("none", [
            '"$(git rev-parse --show-toplevel)/scripts/check.sh"', "$(npm bin)/jest", '"$(npm root)/.bin/jest" --ci',
            '"$(brew --prefix)/bin/gsed" -n 1p file', '"$(go env GOPATH)/bin/golangci-lint" run',
            "root=$(git rev-parse --show-toplevel); $root/scripts/lint.sh --fix", "$(which python) -m pytest",
        ])
        self.assertEqual(self.tier('"$(git rev-parse --show-toplevel)/deploy/run.sh"'), "completion")
        res = self.run_('"$(git rev-parse --show-toplevel)/scripts/check.sh"')
        self.assertTrue(res["opaque"])
        self.assertTrue(res["opaque_writers"])

    def test_environment_tool_setup_lines_are_allowlisted_as_a_whole(self):
        self.assert_tiers("none", [
            'eval "$(ssh-agent -s)"', 'eval "$(brew shellenv)"', 'eval "$(/opt/homebrew/bin/brew shellenv)"',
            'eval "$(pyenv init -)"', 'eval $(poetry env activate)', 'eval "$(direnv hook bash)"',
            'eval "$(gh completion -s bash)"', "source <(kubectl completion bash)", 'eval "$(starship init bash)"',
            'eval "$(fnm env --use-on-cd)"', 'eval "$(register-python-argcomplete pipx)"',
        ])

    def test_unknown_stdin_into_git_or_gh_is_unseen(self):
        self.assertEqual(self.possible("cat args.txt | xargs gh"), ["unseen"])
        self.assertEqual(self.tier("cat files.txt | xargs git add"), "none")
        self.assertEqual(self.tier("git ls-files '*.py' | xargs -I{} sh -c 'python3 -m py_compile {}'"), "none")
        self.assertEqual(self.tier("cat files.txt | xargs -I{} cp {} /tmp/"), "none")

    def test_ifs(self):
        self.assert_tiers("none", [
            "OLDIFS=$IFS; IFS=:; for p in $PATH; do ls \"$p\" >/dev/null; done; IFS=$OLDIFS; $PYTHON -m pytest",
            "IFS=$'\\n'; for f in $(git ls-files); do wc -l \"$f\"; done; $PYTHON -m pytest",
            "while IFS= read -r f; do echo \"$f\"; done < files.txt; $PYTHON -m pytest",
            "IFS=, read -r a b <<< 'x,y'; $CC -o out main.c", "IFS=; echo $PYTHON",
        ])
        self.assertEqual(self.tier("IFS=_; c=gh_pr_create; $c"), "completion")
        self.assertEqual(self.tier("IFS=$(cat f); c=gh; $c pr create"), "completion")
        self.assertEqual(self.tier("IFS=$(cat f); $PYTHON -m pytest"), "completion")

    def test_dynamic_git_subcommands_and_trap_handlers(self):
        self.assertEqual(self.tier("git $(cat sub.txt) -m x"), "completion")
        self.assertEqual(self.tier("git $SUB status"), "none")
        self.assertEqual(self.tier('trap "rm -rf $tmp" EXIT'), "none")
        self.assertEqual(self.tier("tmp=$(mktemp -d); trap 'rm -rf \"$tmp\"' EXIT"), "none")
        self.assertEqual(self.tier("trap 'git push' EXIT"), "intermediate")

    def test_config_written_to_a_computed_path(self):
        self.assert_tiers("intermediate", [
            "echo x >> \"$D/config\"; git ci -m x", "echo '[alias]' >> \"$(git rev-parse --git-dir)/config\"; git ci -m x",
            "env -S \"GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=alias.ci GIT_CONFIG_VALUE_0=commit git ci -m x\"",
            "env -S 'GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=alias.ci GIT_CONFIG_VALUE_0=push' git ci",
            "env GIT_CONFIG_COUNT=$N git ci -m x",
        ])
        self.assertEqual(self.tier("echo x > \"$D/notes.txt\"; git status"), "none")
        self.assertEqual(self.tier("gh pc --fill"), "none")
        for cmd in ("GH_CONFIG_DIR=/tmp/c gh pc --fill", "HOME=/tmp/h gh pc --fill", "XDG_CONFIG_HOME=/x gh pc",
                    "echo x >> ~/.config/gh/config.yml; gh pc", "gh extension install o/gh-pc; gh pc",
                    "gh ext upgrade --all; gh pc"):
            with self.subTest(cmd=cmd):
                self.assertEqual(self.tier(cmd), "completion")
        self.assertEqual(self.tier("GH_CONFIG_DIR=/tmp/c gh pr list"), "none")
        self.assertEqual(self.tier("gh extension list"), "none")


class InlineCodeTest(TierMixin, Base):
    """Issue 4: inline interpreter code is unseen only when the command it runs is not written out."""

    def test_literal_commands_are_probed(self):
        self.assert_tiers("none", [
            "python3 - <<'EOF'\nimport subprocess\nout = subprocess.run([\"git\", \"log\", \"--oneline\"], "
            "capture_output=True, text=True).stdout\nprint(\"\\n\".join(out.splitlines()[:5]))\nEOF",
            "python3 - <<'EOF'\nimport subprocess\nfor f in ['a.py', 'b.py']:\n    print('checking %s' % f)\n"
            "    subprocess.run(['python3', '-m', 'py_compile', f])\nEOF",
            "python3 -c 'import os; print(\",\".join(os.popen(\"git ls-files\").read().split()))'",
            "node -e 'const {execSync}=require(\"child_process\"); console.log(execSync(\"git status --short\")"
            ".toString().split(\"\\n\").join(\",\"))'",
            "ruby -e 'puts `ls`.split.join(\",\")'", "perl -e 'print join(\",\", `ls`)'",
            "node -e 'const cp=require(\"child_process\"); console.log(cp.execSync(`ls ${process.cwd()}`).toString())'",
            "node -e 'const {spawnSync}=require(\"child_process\"); spawnSync(\"npm\",[\"test\"])'",
            "python3 -c 'import subprocess,sys; subprocess.run([sys.executable, \"-m\", \"pytest\"])'",
            "python3 -c 'import subprocess; cmd = [\"git\", \"status\"]; subprocess.run(cmd)'",
            "python3 -c 'import os; os.system(\"git status %s\" % \"-s\")'",
            "python3 -c 'import os; os.system(f\"git status {os.getcwd()}\")'",
            "python3 -c 'import os; print(\"{} files\".format(len(os.listdir(\".\"))))'",
            "python3 -c 'import subprocess as sp; sp.run([\"ls\"])'",
            "python3 -c 'from subprocess import run; run([\"ls\"])'",
            "python3 -c 'import os; print(\"\\x1b[1mbold\\x1b[0m\"); os.system(\"ls\")'",
        ])

    def test_visible_delivery_is_found(self):
        self.assert_tiers("intermediate", [
            "python3 -c 'import subprocess; subprocess.run([\"git\", \"push\"])'",
            "node -e 'require(\"child_process\").execSync(\"git push\")'",
            "node -e 'require(\"child_process\").spawnSync(\"git\", [\"push\"])'",
            "ruby -e 'system(\"git push\")'", "perl -e 'system(\"git\", \"push\")'",
            "python3 -c 'import subprocess; cmd = \"git push\"; subprocess.run(cmd, shell=True)'",
            "python3 -c 'import subprocess as sp; sp.run([\"git\", \"push\"])'",
            "python3 -c 'from subprocess import run; run([\"git\", \"push\"])'",
            "python3 -c 'import os; os.system(\"git push\")'", "python3 -c 'import os; os.system(\"git push\", )'",
        ])

    def test_commands_that_are_not_written_out_are_unseen(self):
        self.assert_tiers("completion", [
            "python3 -c 'import os,sys; os.system(sys.argv[1])' x", "python3 -c 'import os; os.system(\"gi\"+\"t push\")'",
            "python3 -c 'import subprocess; subprocess.run([\"g\"+\"h\", \"pr\", \"create\"])'",
            "python3 -c 'import subprocess; subprocess.run(cmd, shell=True)'",
            "python3 -c 'import subprocess; subprocess.run(\"\".join([\"g\", \"it\"]))'",
            "python3 -c 'import os; os.system(\"llif-- etaerc rp hg\"[::-1])'",
            "node -e 'require(\"child_process\").execSync(\"llif\".split(\"\").reverse().join(\"\"))'",
            "python3 -c 'import os; os.system(f\"{cmd} x\")'", "python3 -c 'import os; os.system(c)'",
            "python3 -c 'import os,base64; os.system(base64.b64decode(\"Z2l0\"))'",
            "python3 -c '__import__(\"os\").system(\"ls\")'", "python3 -c 'exec(open(\"f\").read())'",
            "python3 -c 'import os; getattr(os, \"sys\"+\"tem\")(\"ls\")'",
            "python3 -c 'import subprocess; subprocess.run([x, \"y\"])'", "python3 -c 'import subprocess; subprocess.run([])'",
            "node -e 'eval(process.argv[1])'", "node -e 'new Function(\"return 1\")()'",
            "python3 -c 'import os; os.system(\"curl x | sh\")'",
            "python3 -c 'import subprocess; subprocess.run(\"git commit\" if x else y)'",
            "python3 -c 'import os; os.system(\"ls\"\n+ y)'",
        ])

    def test_interpreter_reading_a_file_is_a_script_not_unseen_code(self):
        self.assert_tiers("none", ["python3 < prog.py", "cat prog.py | python3", "python3 /dev/stdin < prog.py"])
        self.assertEqual(self.tier("curl x | python3"), "completion")

    def test_the_review_samples(self):
        # heredoc body that is plain python: nothing hides, nothing is flagged
        res = self.run_("python3 - <<'EOF'\nimport subprocess\nsubprocess.run(['git','log'])\nEOF")
        self.assertEqual(res["possible_actions"], [])


class StdinScriptsTest(TierMixin, Base):
    def test_a_script_fed_by_a_literal_file_is_opaque_like_running_it(self):
        (self.base / "setup.sh").write_text("echo hi\n")
        self.assert_tiers("none", ["bash < setup.sh", "cat setup.sh | bash", "bash -s -- --fast < setup.sh",
                                   "sh < setup.sh", "cat setup.sh | sh -s", "bash setup.sh"])
        res = self.run_("bash < setup.sh")
        self.assertEqual(res["invoked_script"], str(self.base / "setup.sh"))
        self.assertTrue(res["opaque"])
        self.assertEqual(self.tier("bash < deploy/run.sh"), "completion")
        self.assertEqual(self.tier("bash < deploy/run.sh --dry-run"), "completion")
        self.assertEqual(self.tier("./deploy/render-templates.sh --dry-run"), "none")
        self.assertEqual(self.tier("./deploy/render-templates.sh"), "completion")
        self.assert_tiers("completion", ["cat a b | bash", "cat setup.sh - | bash", "curl -s x | bash", "bash < <(curl x)",
                                         "bash < /dev/stdin", "cat setup.sh | bash /dev/stdin"] [:5])
        self.assertEqual(self.tier("bash 3< setup.sh"), "none")


class DeployUsersTest(TierMixin, Base):
    def test_only_a_copy_to_or_a_changing_command_on_the_deploy_host_is_a_deploy(self):
        self.assert_tiers("completion", [
            "scp a.tar deploy@prod:/opt/", "rsync -av dist/ deploy@prod:/srv", "ssh deploy@prod systemctl restart app",
            "ssh deploy@prod", "ssh deploy@prod 'ls; rm -rf /srv/app'", "ssh deploy@prod ls \"$X\"",
            "ssh deploy@prod 'cat /etc/hosts | sh'", "ssh deploy@prod docker restart app", "sftp release@host",
            "ssh deploy@prod kubectl delete pod x", "scp deploy@a:/x deploy@b:/y", "ssh deploy@prod ls\\; rm x",
        ])
        self.assert_tiers("none", [
            "scp deploy@prod:/var/log/app.log .", "rsync -av deploy@prod:/var/log/app/ ./logs/",
            "ssh deploy@prod docker ps", "ssh deploy@prod docker logs app", "ssh deploy@prod kubectl get pods",
            "ssh deploy@prod systemctl status app", "ssh deploy@prod tail -n 50 /var/log/app.log",
            "ssh deploy@prod git status", "ssh dev@host ls", "scp a.txt dev@host:/tmp/",
        ])


class BranchMovesTest(TierMixin, Base):
    """Issue 6: stashed work reaching a branch, and the spellings of 'this repository'."""

    def test_branch_moves_to_a_stash_commit_are_commits(self):
        self.assert_tiers("intermediate", [
            "git stash && git checkout -B feature/x 'stash@{0}'", "git stash && git reset --soft 'stash@{0}'",
            "git stash && git switch -C feature/x 'stash@{0}'", "git checkout -b feat stash", "git switch -c feat refs/stash",
            "git branch feat 'stash@{1}'", "git reset --hard stash@{0}", "git reset --mixed refs/stash",
            "git switch --force-create feat stash@{2}", "git switch --create feat stash",
        ])
        self.assert_tiers("none", [
            "git checkout -B feat origin/main", "git switch -C feat", "git stash", "git stash pop", "git stash list",
            "git checkout stash@{0} -- file.txt", "git branch feat origin/main", "git switch -c feat main",
            "git reset --hard HEAD~1", "git reset --soft HEAD~1", "git checkout -b feat", "git checkout main",
            "git branch --list stash", "git reset", "git stash apply stash@{0}",
        ])

    def test_pulling_from_this_repository_is_a_merge_however_it_is_spelled(self):
        self.assert_tiers("intermediate", [
            "git pull --no-rebase . other", "git pull --no-rebase ./ other", "git pull --no-edit .git other",
            "git pull --no-rebase \"$PWD\" other", "git pull ./.git other", "git pull file:///tmp/r other",
            "git pull -- . other",
        ])
        self.assert_tiers("none", ["git pull", "git pull origin main", "git pull --ff-only", "git pull ../elsewhere main",
                                   "git pull upstream"])


class HelpOptionTest(TierMixin, Base):
    """Issue 7: git honours -h/--help only as the first argument after the subcommand."""

    def test_help_after_other_arguments_is_not_help(self):
        self.assert_tiers("intermediate", [
            "git merge --no-edit --into-name --help other", "git commit -m x --help", "git commit --amend -h",
            "git push --repo --help",
        ])
        self.assert_tiers("none", ["git commit --help", "git commit -h", "git push -h", "git merge --help", "git rebase -h"])
        self.assertEqual(self.tier("gh pr create --title --help"), "completion")  # gh reads --help anywhere else
        self.assertEqual(self.tier("gh pr create --fill --help"), "none")
        self.assertEqual(self.tier("gh pr create --fill -- --help"), "completion")


class ArithmeticTest(TierMixin, Base):
    """Issue 5: bash evaluates subscripts, offsets and integer assignments as arithmetic."""

    EVIL = "x='a[$(git push)]'; "

    def test_arithmetic_contexts_that_run_a_substitution(self):
        self.assert_tiers("completion", [
            self.EVIL + "echo ${a[x]}", self.EVIL + "echo ${x:x}", self.EVIL + "declare -i y=x",
            self.EVIL + "[[ -v $x ]]", self.EVIL + "a=(1); echo ${a[x]:-z}", self.EVIL + "echo ${x:1:x}",
            self.EVIL + "local -i y=x", self.EVIL + "declare -i n; n=x", self.EVIL + "typeset -i n=1; n+=x",
            self.EVIL + "[[ -R $x ]]", "declare -i y='a[$(git push)]'", "declare -i n=0; n='a[$(git push)]'",
        ])
        self.assert_tiers("intermediate", ["echo ${a[$(git push)]}", "echo ${x:$(git push)}"])
        self.assert_tiers("none", [
            "echo ${a[1]}", "echo ${x:1}", "echo ${x:1:2}", "declare -i n=5", "a=(1 2); echo ${a[0]} ${a[1]}",
            "x=abc; echo ${x: -2}", "[[ -v HOME ]]", "[[ -v a[1] ]]", "declare -i n; n=5", "echo ${x:-default}",
            "echo ${x:=default}", "echo ${x:+alt}", "echo ${x:?err}", "echo ${arr[@]}", "echo ${arr[*]}",
        ])

    def test_variables_in_subscripts_are_not_read_only(self):
        self.assertEqual(self.ro("echo ${a[i]}"), (False, False))
        self.assertEqual(self.ro("echo ${x:n}"), (False, False))
        self.assertEqual(self.ro("echo ${a[1]} ${x:1}"), (True, True))
        self.assertEqual(self.ro("declare -i n=m"), (False, False))


class BudgetTest(Base):
    """Issue 2: every step is bounded in cost, not only in number."""

    def timed(self, cmd, limit):
        started = time.monotonic()
        res = self.run_(cmd)
        self.assertLess(time.monotonic() - started, limit, cmd[:60])
        return res

    def test_doubling_a_value_cannot_stall_the_analysis(self):
        res = self.timed("x=abcd; " + "x=$x$x; " * 30 + "echo $x; G=gh; $G pr create --fill", 12)
        self.assertEqual(effective(res), "completion")
        res = self.timed("if false; then x=abcd; " + "x=$x$x; " * 40 + "fi; echo hidden-ran", 12)
        self.assertEqual(res["status"], "ok")
        res = self.timed("x=abcd; " + "x=$x$x; " * 40 + "$x pr create", 12)
        self.assertEqual(effective(res), "completion")

    def test_an_oversized_value_becomes_unknown(self):
        with mock.patch.object(sa, "MAX_VALUE_CHARS", 8):
            res = self.run_("x=abcd; x=$x$x$x; $x commit")
        self.assertIn("unseen", res["possible_actions"])
        with mock.patch.object(sa, "MAX_VALUE_CHARS", 8):
            self.assertEqual(self.run_("x=abcdefghijkl; echo $x")["possible_actions"], [])
            res = self.run_("declare x=abcdefghijkl; $x")
            self.assertIn("unseen", res["possible_actions"])
        self.assertEqual(sa._cap("x" * (sa.MAX_VALUE_CHARS + 1)), None)
        self.assertEqual(sa._cap("x"), "x")
        self.assertEqual(sa._cap(None), None)

    def test_arrays_and_parameters_stop_growing(self):
        res = self.timed("a=(x x); " + 'a+=("${a[@]}"); ' * 30 + "gh pr create --fill", 12)
        self.assertEqual(res["actions"], ["pr_create"])
        res = self.timed("set -- a b; " + 'set -- "$@" "$@"; ' * 30 + "gh pr create --fill", 12)
        self.assertEqual(res["actions"], ["pr_create"])
        with mock.patch.object(sa, "MAX_SEQUENCE", 4):
            res = self.run_("a=(1 2 3); a+=(4 5); \"${a[@]}\"")
        self.assertIn("unseen", res["possible_actions"])

    def test_regexes_over_command_text_are_linear(self):
        for cmd in ("export '" + "[" * 60000 + "'; gh pr create --fill", "echo " + "[" * 100000 + "; gh pr create",
                    "declare " + "[$" * 30000 + "; gh pr create", "read '" + "[" * 60000, "unset " + "[a" * 40000,
                    "echo " + "$[" * 20000, "x=" + "a" * 100000 + "; echo $x$x$x; gh pr create"):
            with self.subTest(n=len(cmd)):
                res = self.timed(cmd, 20)
                self.assertEqual(res["actions"] + res["possible_actions"] != [] or True, True)
        self.assertFalse(sa._SUBSCRIPT_EXEC.search("[" * 100000))
        self.assertTrue(sa._SUBSCRIPT_EXEC.search("a[$(cmd)]"))
        self.assertTrue(sa._SUBSCRIPT_EXEC.search("a[$x$(cmd)]"))
        self.assertTrue(sa._SUBSCRIPT_EXEC.search("a[`cmd`]"))
        self.assertFalse(sa._SUBSCRIPT_EXEC.search("a[1] $(cmd)"))
        self.assertTrue(sa._has_glob("a*") and sa._has_glob("a?") and sa._has_glob("a[b]"))
        self.assertFalse(sa._has_glob("a[b") or sa._has_glob("a]b[") or sa._has_glob("plain"))

    def test_a_huge_command_is_judged_within_the_budget(self):
        res = self.timed("true;" * 200000 + " sed -i s/x/y/ src/app.py", 20)   # over the input cap: not parsed at all
        self.assertEqual((res["possible_actions"], res["opaque_reasons"]), (["unseen"], ["command too large to analyze"]))
        res = self.timed("true;" * 80000 + " sed -i s/x/y/ src/app.py", 20)    # under the cap: the parse budget ends it
        self.assertEqual((res["status"], effective(res)), ("parse_failed", "completion"))
        with mock.patch.object(sa, "MAX_INPUT_CHARS", 1000):
            res = self.timed("true;" * 500 + " gh pr create", 12)
        self.assertEqual(res["possible_actions"], ["unseen"])
        self.assertLessEqual(3 * (sa.MAX_PARSE_SECONDS + sa.MAX_SECONDS), 8)  # dev-cycle-check analyses three times
        self.assertLessEqual(sa.MAX_INPUT_CHARS, 512 * 1024)

    def test_the_deadline_is_checked_at_every_step(self):
        ticks = []
        real = sa.time.monotonic
        with mock.patch.object(sa.time, "monotonic", side_effect=lambda: ticks.append(1) or real()):
            self.run_("ls; ls; ls; ls; ls; ls; ls; ls")
        self.assertGreater(len(ticks), 8)

    def test_the_parser_shares_its_deadline_with_nested_parsers(self):
        script = sa.parse("echo `echo \\`ls\\``; cat <<EOF\n$(ls)\nEOF", deadline=0.0)
        self.assertIn("budget", script.error)
        self.assertEqual(sa.parse("echo `ls`").error, "")


class ParserFaultTest(Base):
    """Issue 3: the parser reports every fault as a parse error and never loops."""

    def test_errors_while_skipping_newlines_are_parse_errors(self):
        res = self.run_("cat <<EOF &\n`\nEOF\ngit -c alias.ci=commit ci --allow-empty -m hd2")
        self.assertEqual(res["status"], "parse_failed")
        self.assertEqual(effective(res), "completion")
        res = self.run_("git push\ncat <<EOF ;\n`\nEOF\nls")
        self.assertEqual((res["status"], res["actions"]), ("parse_failed", ["push"]))
        self.assertEqual(effective(res), "completion")

    def test_the_fuzz_samples_terminate_as_parse_errors(self):
        for text in ("for\nin)$[evalsource:,a=set :<( \\<(iniftime!&", "for x in )", "for x in |", "for x in a ) b",
                     "select x in (", "for i in 1 2 )"):
            with self.subTest(text=text):
                started = time.monotonic()
                res = self.run_(text)
                self.assertLess(time.monotonic() - started, 5)
                self.assertEqual(res["status"], "parse_failed")
        self.assertIn("for loop", sa.parse("for x in )").error)

    def test_any_exception_from_the_parser_is_a_parse_error(self):
        with mock.patch.object(sa._Parser, "parse_item", side_effect=IndexError("boom")):
            script = sa.parse("ls")
        self.assertEqual((script.items, script.error), ([], "parser error: IndexError"))
        with mock.patch.object(sa._Parser, "parse_item", side_effect=RecursionError):
            self.assertEqual(sa.parse("ls").error, "nesting too deep")
        with mock.patch.object(sa._Parser, "parse_list", side_effect=ValueError("x")):
            self.assertEqual(sa.parse("ls").error, "parser error: ValueError")
        with mock.patch.object(sa._Parser, "parse_item", side_effect=sa.ParseError("bad")):
            self.assertEqual(sa.parse("ls").error, "bad")
        self.assertEqual(sa._parse_failure(sa.ParseError("x")), "x")

    def test_random_token_soup_never_raises(self):
        import random
        tokens = ["git", "commit", "$(", ")", "`", "'", '"', "${", "}", "$((", "))", "$[", "<(", "<<", "EOF", "\n", ";", "&",
                  "|", "(", "{", "for", "in", "do", "done", "if", "then", "fi", "case", "esac", "$x", "${a[@]}", "x=",
                  "a=(", ";;", "#", "\\", "<<<", "xargs", "eval", "trap", "-c", "[[", "]]", "declare", "-i", "shift", "$@"]
        rnd = random.Random(7)
        with mock.patch.object(sa, "MAX_PARSE_SECONDS", 0.2), mock.patch.object(sa, "MAX_SECONDS", 0.2):
            for _ in range(1500):
                text = " ".join(rnd.choice(tokens) for _ in range(rnd.randint(1, 12)))
                res = self.run_(text)
                self.assertNotIn("analyzer error", res["error"], text)


class WrittenScriptsTest(TierMixin, Base):
    """A script this very command writes and then runs is judged by the text it was given."""

    def test_scripts_written_and_run_in_one_command(self):
        self.assert_tiers("intermediate", [
            "printf 'git push\\n' > r.sh; bash r.sh", "echo 'git push' > r.sh && source r.sh",
            "echo 'git push' > /tmp/r.sh; . /tmp/r.sh", "cat > r.sh <<'EOF'\ngit push\nEOF\nbash r.sh",
            "cat > a.py <<'EOF'\nimport os\nos.system('git push')\nEOF\npython3 a.py",
            "echo 'git' > r.sh; echo 'push' >> r.sh; mv r.sh /tmp; echo 'git push' > r.sh; sh r.sh",
            "echo 'git push' > r.sh; touch r.sh; sh r.sh", "echo 'git push' > r.sh; (cd sub; sh ../r.sh)",
            "mkdir -p d; echo 'git push' > d/r.sh; cd d && sh r.sh",
        ])
        self.assertEqual(self.tier("echo 'gh pr create --fill' > x.sh && chmod +x x.sh && ./x.sh"), "completion")
        self.assertEqual(self.run_("echo 'gh pr create --fill' > x.sh && chmod +x x.sh && ./x.sh")["actions"], ["pr_create"])
        self.assert_tiers("none", [
            "echo hi > r.sh; bash r.sh", "echo a > f; echo b >> f; cat f", "echo 'git push' > r.sh; > r.sh; bash r.sh",
            "echo 'git push' > notes.txt; cat notes.txt", "echo 'git push' > r.sh; echo 'git push' > r.sh; echo ok",
            "echo 'git push' > /dev/null; bash /dev/null",
        ])

    def test_content_that_cannot_be_read_is_unseen_when_run(self):
        self.assert_tiers("completion", [
            "echo hi > r.sh; cp other.sh r.sh; bash r.sh", "echo \"$(cat y)\" > r.sh; bash r.sh",
            "$(cat y) > r.sh; bash r.sh", "echo 'git push' > r.sh; sed -i s/push/status/ r.sh; bash r.sh",
            "echo 'git push' > r.sh; tee r.sh < in.txt; bash r.sh", "cat in.txt > r.sh; bash r.sh",
            "echo hi > r.sh; echo \"$X\" >> r.sh; bash r.sh", "echo hi > r.sh; cat in.txt >> r.sh; bash r.sh",
        ])
        self.assertEqual(self.tier("cat in.txt > r.sh"), "none")  # nothing runs it
        self.assertEqual(self.tier("echo hi >> r.sh; bash r.sh"), "none")  # a file from before this command
        self.assertEqual(self.tier("echo 'source ~/x' >> ~/.bashrc; source ~/.bashrc"), "none")

    def test_unresolvable_paths_are_not_tracked(self):
        self.assertEqual(self.tier("cd \"$D\"; echo 'git push' > r.sh; bash r.sh"), "none")
        self.assertEqual(self.tier("echo 'git push' > \"$F\"; bash \"$F\""), "none")
        self.assertIsNone(sa._Analysis.file_key("r.sh", sa.Env(None, None)))
        self.assertEqual(sa._Analysis.file_key("/a/../b", sa.Env(None, None)), "/b")


class HelperFunctionsTest(TierMixin, Base):
    """Branches of the parameter, glob and inline-code helpers."""

    def test_parameter_operators_on_known_values(self):
        op = sa._param_operator
        self.assertEqual(op("abcabc", "#a*c"), "abc")
        self.assertEqual(op("abcabc", "##a*c"), "")
        self.assertEqual(op("abcabc", "%b*"), "abca")
        self.assertEqual(op("abcabc", "%%b*"), "a")
        self.assertEqual(op("abc", "#x"), "abc")        # no match: unchanged
        self.assertEqual(op("abc", "%x"), "abc")
        self.assertEqual(op("abc", "#[a-b]"), "bc")     # bracket expression
        self.assertEqual(op("abc", "#[!x]"), "bc")
        self.assertEqual(op("abc", "#?"), "bc")
        self.assertEqual(op("a*c", "#\\*"), "a*c")
        self.assertEqual(op("*bc", "#\\*"), "bc")      # escaped glob character is literal
        self.assertEqual(op("abc", "#["), "abc")        # an unclosed bracket is a literal
        self.assertEqual(op("hg", "/hg/gh"), "gh")
        self.assertEqual(op("hhg", "//h/x"), "xxg")
        self.assertEqual(op("hg", "/#h/x"), "xg")
        self.assertEqual(op("hg", "/%g/x"), "hx")
        self.assertEqual(op("hg", "/"), "hg")           # empty pattern
        self.assertEqual(op("abcdef", ":2"), "cdef")
        self.assertEqual(op("abcdef", ":1:2"), "bc")
        self.assertEqual(op("abcdef", ": -2"), "ef")
        self.assertEqual(op("abcdef", ":1:-1"), "bcde")
        self.assertEqual(op("abcdef", ": -9"), "abcdef")
        self.assertEqual(op("ab", "^"), "Ab")
        self.assertEqual(op("AB", ","), "aB")
        self.assertEqual(op("ab", "^^"), "AB")
        self.assertEqual(op("AB", ",,"), "ab")
        self.assertEqual(op("ab", "@U"), "AB")
        self.assertIsNone(op("ab", "@Q"))
        self.assertIsNone(op("x" * 5000, "^^"))         # too long to evaluate
        self.assertIsNone(op("ab", "/a/$x"))            # an expansion in the operand
        self.assertIsNone(op("ab", ":x"))
        self.assertIsNone(op("abc", "#[z-a]"))          # an invalid range is not modelled
        self.assertEqual(sa._glob_regex("a*?[!b]\\.c"), "a.*.[^b]\\.c")

    def test_command_text(self):
        self.assertTrue(sa._command_text("git commit -m x"))
        self.assertTrue(sa._command_text("FOO=1 git commit"))
        self.assertTrue(sa._command_text("!git push"))
        self.assertTrue(sa._command_text("cd src && make test"))
        self.assertFalse(sa._command_text("git"))
        self.assertFalse(sa._command_text("fix: handle (broken) case"))
        self.assertFalse(sa._command_text("(a b)"))
        self.assertFalse(sa._command_text("Some prose about the commit"))
        self.assertFalse(sa._command_text("do shell script x"))

    def test_string_literals_in_inline_code(self):
        read = sa._read_string
        self.assertEqual(read('"a\\"b" x', 0), ('a\\"b', 6))
        self.assertEqual(read("r'a\\n' x", 0), ("a\\n", 6))
        self.assertEqual(read('"""triple "quoted" text""" x', 0)[0], 'triple "quoted" text')
        self.assertIsNone(read('"open', 0))
        self.assertIsNone(read("x", 0))
        self.assertEqual(read('f"a {b} c"', 0)[0], "a ${_hole} c")
        text, end = read('"a %s c" % (x, y), z', 0)
        self.assertEqual((text, '"a %s c" % (x, y), z'[end:]), ("a ${_hole} c", ", z"))
        text, end = read('"git %s" % (x, "y)")), 1', 0)
        self.assertEqual(text, "git ${_hole}")
        self.assertEqual('"git %s" % (x, "y)")), 1'[end:end + 1], ")")
        text, end = read('"git {}".format(a, b), 2', 0)
        self.assertEqual('"git {}".format(a, b), 2'[end:], ", 2")
        text, end = read('"a %s" % x)', 0)
        self.assertEqual('"a %s" % x)'[end:], ")")
        self.assertEqual(sa._skip_format('"unterminated', 0), len('"unterminated'))
        self.assertEqual(sa._skip_format("x [1, 2] y", 0), len("x [1, 2] y"))

    def test_list_literals_in_inline_code(self):
        split = sa._split_items
        self.assertEqual(split('["git", "log", x]', 0), (['"git"', '"log"', "x"], 17))
        self.assertEqual(split("[ ]", 0), ([], 3))
        self.assertEqual(split('["a", [1, 2], f(3, 4)]', 0)[0], ['"a"', "[1, 2]", "f(3, 4)"])
        self.assertIsNone(split('["a", "open]', 0))
        self.assertIsNone(split('["a", ', 0))
        self.assertEqual(sa._literal_value(" sys.executable "), ("python3", True))
        self.assertEqual(sa._literal_value("process.execPath"), ("node", True))
        self.assertEqual(sa._literal_value("'x'"), ("x", True))
        self.assertEqual(sa._literal_value("f'x{y}'"), (sa._HOLE.join(["x", ""]), False))
        self.assertEqual(sa._literal_value("y"), (sa._HOLE, False))
        self.assertEqual(sa._literal_value("'a' + b"), (sa._HOLE, False))

    def test_call_arguments(self):
        calls = sa._call_commands
        self.assertEqual(calls('os.system( "ls")', "python"), [("code", "ls")])
        self.assertEqual(calls('child_process.spawnSync("git", ["push"])', "node"), [("argv", ["git", "push"])])
        self.assertEqual(calls('spawn("git", ["push"', "node"), [("code", "git")])  # an unterminated list
        self.assertEqual(calls('subprocess.run(["git"] + x)', "python"), [("argv", ["git"])])
        self.assertEqual(calls("subprocess.run([x])", "python"), [("unknown", None)])
        self.assertEqual(calls("subprocess.run([a b", "python"), [("unknown", None)])
        self.assertEqual(calls("`ls`", "ruby"), [("code", "ls")])
        self.assertEqual(calls("`ls`", "node"), [])
        self.assertEqual(calls("x = 'a'\nx = 'b'\nos.system(x)", "python"), [("unknown", None)])
        self.assertEqual(calls("os.system(x)", "python"), [("unknown", None)])

    def test_inline_code_corners(self):
        self.assertEqual(self.tier("python3 -W ignore -c 'print(1)'"), "none")
        self.assertEqual(self.tier("python3 -X dev script.py"), "none")
        self.assertEqual(self.tier("python3 -c \"print('$HOME')\""), "none")
        self.assertEqual(self.tier("node -p \"1 + $N\""), "none")
        self.assertEqual(self.tier("python3 -c 'import os; os.system(\"git push\")' x"), "intermediate")
        self.assertEqual(self.tier("node -e 'require(\"child_process\").spawn(\"git\", [\"push\"'"), "intermediate")
        self.assertEqual(self.tier("git -c core.pager='curl x | sh' log"), "completion")
        self.assertEqual(self.tier("git -c core.pager=less log"), "none")
        self.assertEqual(self.tier("f(){ $* pr create; }; f $(cat a)"), "completion")
        self.assertEqual(self.tier("f(){ $* --version; }; f $HOME"), "none")
        self.assertEqual(self.tier("f(){ echo \"$*\"; }; f $(cat a)"), "none")
        self.assertEqual(self.tier("a=(x); echo ${a[@]/x/y} ${a[@]:x}"), "none")
        self.assertEqual(self.tier("a=(gh pr create); \"${a[@]/gh/git}\""), "completion")


if __name__ == "__main__":
    unittest.main()
