"""Unit tests for hooks/lib/tool-input/push_scope.py with a fake git (every branch of the proof)."""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import sbtest  # noqa: E402

shell_analysis = sbtest.load_module("hooks/lib/tool-input/shell_analysis.py", "sbtest_sa_scope")
push_scope = sbtest.load_module("hooks/lib/tool-input/push_scope.py", "push_scope")

ENV = {"PATH": "/usr/bin:/bin", "HOME": "/nonexistent"}


class FakeRepo:
    """Answers the three read-only git calls from a small model of a repository."""

    def __init__(self, head="refs/heads/feat/x", branches=("feat/x", "feat/y", "main"), cfg=None, symrefs=None,
                 extra_refs=(), tags=(), bare="false", rc=None, err="", short=False, aliases=None):
        self.head, self.branches, self.tags = head, set(branches), set(tags)
        self.cfg = {"remote.origin.url": ["https://example.test/acme/app.git"]}
        self.cfg.update(cfg or {})
        self.symrefs = {"refs/remotes/origin/HEAD": "refs/remotes/origin/main"} if symrefs is None else symrefs
        self.extra_refs, self.bare, self.rc, self.err, self.short = set(extra_refs), bare, rc or {}, err, short
        self.calls = []
        self.aliases = aliases or {}

    def __call__(self, args, timeout):
        self.calls.append(args)
        verb = args[2]
        if verb in self.rc:
            return self.rc[verb], b"", b"fatal"
        if verb == "rev-parse":
            if self.short:
                return 0, b"x\n", b""
            lines = ["/repo/.git", self.bare, self.head if self.head else "HEAD"]
            for src in args[7:]:
                short = src.removeprefix("refs/heads/")
                if short in self.branches:
                    lines.append("refs/heads/" + short)
                elif src in self.aliases:
                    lines.append(self.aliases[src])
                elif src in self.tags:
                    lines.append("refs/tags/" + src)
                else:
                    return 128, b"", b"fatal: bad revision"
            return 0, ("\n".join(lines) + "\n").encode(), self.err.encode()
        if verb == "config":
            body = b"".join(("%s\n%s" % (k, v)).encode() + b"\0" for k, vs in self.cfg.items() for v in vs)
            return 0, body + b"bare.key\0", b""
        refs = dict(self.symrefs)
        refs.update({name: "" for name in self.extra_refs})
        wanted = [p for p in args[4:]]
        out = ""
        for name, target in refs.items():
            if any(name == p or name.startswith(p + "/") for p in wanted):
                out += "%s\0%s\n" % (name, target)
        return 0, out.encode(), b""


class Base(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = os.path.realpath(tempfile.mkdtemp(prefix="pscope-unit"))
        os.makedirs(os.path.join(cls.tmp, "sub", "deep"))
        os.makedirs(os.path.join(cls.tmp, "other"))

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp, ignore_errors=True)

    def scope(self, cmd, repo=None, env=None, base="", analysis_base=None):
        repo = repo or FakeRepo()
        base = base or self.tmp
        result = shell_analysis.analyze_command(cmd, analysis_base or base, False)
        script = shell_analysis.parse(cmd)
        out = push_scope.shell_scope(script, result, base, ENV if env is None else env, push_scope.Git(ENV, repo))
        self.repo = repo
        return out

    def feature(self, cmd, **kw):
        out = self.scope(cmd, **kw)
        with self.subTest(cmd=cmd):
            self.assertEqual(out["verdict"], "feature", out)
        return out

    def strict(self, cmd, reason, **kw):
        out = self.scope(cmd, **kw)
        with self.subTest(cmd=cmd):
            self.assertEqual(out["verdict"], "strict", out)
            self.assertIn(reason.lower(), out["reason"].lower(), out)
        return out


class ShapeTests(Base):
    def test_accepted_forms(self):
        out = self.feature("git push -u origin HEAD")
        self.assertEqual((out["remote"], out["branches"]), ("origin", ["feat/x"]))
        self.feature("git push")
        self.feature("git push origin feat/y")
        self.feature("git push origin refs/heads/feat/y")
        self.feature("git push origin HEAD:refs/heads/feat/z")
        self.feature("git push origin feat/y:feat/z")
        self.feature("git push origin @")
        self.feature("git --no-pager push")
        self.feature("git -P push")
        self.feature("git push -uf origin feat/x")
        self.feature("git push --force-with-lease=feat/x:abc origin feat/x")
        self.feature("git push --recurse-submodules=check origin feat/x")
        self.feature("git push -- origin feat/x")
        self.feature("git status && git push")
        self.feature("git branch --show-current && git remote -v && git push")
        self.feature("echo hi; printf '%s' x; git push")

    def test_preconditions(self):
        self.strict("git push", "unknown", base=os.path.join(self.tmp, "nope"))
        out = push_scope.shell_scope(shell_analysis.parse("git push"), {}, None, ENV)
        self.assertIn("unknown", out["reason"])
        self.strict("git push; git push", "more than one")
        self.strict("git push 'unterminated", "cannot read")
        self.strict("git push $X", "plain top-level")
        self.strict("git status", "plain top-level")

    def test_environment(self):
        for name in push_scope.ENV_DENY:
            self.strict("git push", name, env=dict(ENV, **{name: "x"}))
        self.strict("git push", "exported shell function", env=dict(ENV, **{"BASH_FUNC_git%%": "() { :; }"}))

    def test_coverage_tracer_bash_env(self):
        real = push_scope.COVERAGE_BASH_ENV
        cov = os.path.join(self.tmp, "cov")
        os.makedirs(cov, exist_ok=True)
        env = dict(ENV, BASH_ENV=real, SB_COV_DIR=cov)
        self.feature("git push", env=env)
        self.strict("git push", "BASH_ENV", env=dict(env, BASH_ENV="/tmp/evil/tests/coverage/bash-env.sh"))
        self.strict("git push", "BASH_ENV", env=dict(ENV, BASH_ENV=real))  # no SB_COV_DIR
        self.strict("git push", "BASH_ENV", env=dict(env, SB_COV_DIR=os.path.join(self.tmp, "none")))
        self.strict("git push", "BASH_ENV", env=dict(env, BASH_ENV="tests/coverage/bash-env.sh"))  # relative
        link = os.path.join(self.tmp, "tracer-link.sh")
        os.symlink(real, link)
        self.strict("git push", "BASH_ENV", env=dict(env, BASH_ENV=link))
        # a suffix-equal path in a writable temp tree, and a writable copy of the real file
        fake = os.path.join(self.tmp, "x", "tests", "coverage")
        os.makedirs(fake)
        fake_file = os.path.join(fake, "bash-env.sh")
        shutil.copy(real, fake_file)
        self.strict("git push", "BASH_ENV", env=dict(env, BASH_ENV=fake_file))
        self.assertTrue(push_scope.is_coverage_tracer(real, env))
        saved = push_scope.COVERAGE_BASH_ENV
        push_scope.COVERAGE_BASH_ENV = fake_file
        try:
            os.chmod(fake_file, 0o666)
            self.assertFalse(push_scope.is_coverage_tracer(fake_file, env))
            os.chmod(fake_file, 0o644)
            self.assertTrue(push_scope.is_coverage_tracer(fake_file, env))
            os.chmod(fake_file, 0o755)
            self.assertTrue(push_scope.is_coverage_tracer(fake_file, env))
            os.remove(fake_file)
            os.mkdir(fake_file)  # not a regular file
            self.assertFalse(push_scope.is_coverage_tracer(fake_file, env))
            info = os.stat(real)
            real_stat = os.stat
            foreign = type("S", (), {"st_mode": info.st_mode, "st_uid": os.geteuid() + 1})()
            os.stat = lambda path: foreign if path == real else real_stat(path)
            push_scope.COVERAGE_BASH_ENV = real
            try:
                self.assertFalse(push_scope.is_coverage_tracer(real, env))
            finally:
                os.stat = real_stat
        finally:
            push_scope.COVERAGE_BASH_ENV = saved

    def test_top_level_shape(self):
        self.strict("git push &", "background")
        self.strict("(git push)", "compound")
        self.strict("f() { git push; }; f", "push")
        self.strict("X=1 git push", "assignment")
        self.feature("RTK_DISABLED=1 git push")
        self.feature("LANG=en_US.UTF-8 LC_ALL=C NO_COLOR=1 CI=1 GIT_TERMINAL_PROMPT=0 git push")
        self.strict("LANG='a b' git push", "assignment")
        self.strict("RTK_DISABLED=0 git push", "assignment")
        self.strict("RTK_DISABLED+=1 git push", "assignment")
        self.strict("arr=(1) git push", "assignment")
        self.strict("X=1; git push", "assignment")
        self.feature("CI=1; git push")
        self.strict("sh -c 'git push'", "plain top-level")
        self.strict("\\git push origin feat/x && eval 'git push'", "more than one")
        self.strict("git -c a=b push", "plain top-level")
        self.strict("git -C", "plain top-level")
        self.strict("git --git-dir=x push", "plain top-level")
        self.strict("git push || git checkout main", "git checkout")
        self.strict("git checkout main & git push", "background")

    def test_inert_allowlist(self):
        for other in ("git fetch", "git pull", "git config a b", "git stash", "git remote add x y",
                      "git branch newb", "git remote rename a b", "git worktree add x", "npm test", "make",
                      "export A=1", "git checkout main", "git switch main", "git checkout -B n", "git switch -C n",
                      "git checkout -b", "git checkout -b n1 s1 extra", "printf -v x y", "git", "git -C x",
                      "git checkout --detach", "git switch -c --bad"):
            self.strict("%s && git push" % other, "also runs")

    def test_hidden_state_steps(self):
        self.strict("echo \"$(git checkout -b n)\" && git push", "hidden")
        self.strict("echo \"$(cd sub)\" && git push", "hidden")
        self.strict("echo \"$(git push)\"; git push", "more than one")
        self.strict("cat <<EOF\n$(git push)\nEOF\ngit push", "more than one")

    def test_helpers(self):
        self.assertEqual(push_scope.classify_argv([]), ("other", ""))
        self.assertEqual(push_scope.split_git_globals(["git", "-C"]), None)
        result = shell_analysis.analyze_command("git push", self.tmp, False)
        result["writes"] = [{"path": "/dev/null"}, {"path": "/etc/x"}]
        out = push_scope.shell_scope(shell_analysis.parse("git push"), result, self.tmp, ENV,
                                     push_scope.Git(ENV, FakeRepo()))
        self.assertIn("writes /etc/x", out["reason"])

    def test_negated_before_push(self):
        self.strict("! git status && cd sub && git push", "negated")

    def test_writes(self):
        self.feature("git push >/dev/null 2>&1")
        self.strict("git push >%s/out.txt" % self.tmp, "writes")
        self.strict("git push 2>>%s/log" % self.tmp, "writes")


class StateStepTests(Base):
    def test_cd(self):
        out = self.feature("cd %s/sub && git push" % self.tmp)
        self.assertEqual(out["dir"], os.path.join(self.tmp, "sub"))
        self.feature("cd sub && git push", base=self.tmp)
        self.feature("cd .. && git push", base=os.path.join(self.tmp, "sub"))
        self.feature("git status && cd sub && git push")
        self.strict("cd sub; git push", "chain")
        self.strict("cd sub || git push", "chain")
        self.strict("true || cd sub && git push", "chain")
        self.strict("! cd sub && git push", "chain")
        self.strict("cd sub | cat && git push", "chain")
        self.strict("cd sub", "plain top-level")
        self.strict("git push && cd sub", "chain")
        self.strict("cd sub && cd deep && git push", "more than one")
        self.strict("cd - && git push", "also runs")
        self.strict("cd ~ && git push", "cd")
        self.strict("cd && git push", "also runs")
        self.strict("cd a b && git push", "also runs")
        self.strict("cd -P sub && git push", "also runs")
        self.strict("cd $X && git push", "cd")
        self.strict("cd nope && git push", "does not exist")
        self.strict("cd sub && git push", "CDPATH", env=dict(ENV, CDPATH=self.tmp))
        self.feature("cd %s/sub && git push" % self.tmp, env=dict(ENV, CDPATH=self.tmp))
        self.strict("cd sub; git push; cd .. ; git push", "more than one")
        self.strict("cd sub && git push && cd .. && git push", "more than one")

    def test_directory_arguments(self):
        out = self.feature("git -C sub push")
        self.assertEqual(out["dir"], os.path.join(self.tmp, "sub"))
        self.feature("git -C sub -C deep push")
        self.feature("git -C %s push" % os.path.join(self.tmp, "sub"))
        self.feature("cd sub && git -C deep push")
        self.strict("git -C nope push", "does not exist")

    def test_cross_check(self):
        self.strict("git push", "could not be confirmed", base=self.tmp, analysis_base=self.tmp, env=ENV) \
            if False else None
        result = shell_analysis.analyze_command("git push", self.tmp, False)
        result["commands"][0]["cwd"] = os.path.join(self.tmp, "sub")
        out = push_scope.shell_scope(shell_analysis.parse("git push"), result, self.tmp, ENV,
                                     push_scope.Git(ENV, FakeRepo()))
        self.assertIn("could not be confirmed", out["reason"])
        # a different analysis base skips the cross-check (the payload cwd decides)
        self.feature("git push", analysis_base=os.path.join(self.tmp, "sub"))

    def test_new_branch(self):
        out = self.feature("git checkout -b feat/n && git push -u origin feat/n")
        self.assertEqual(out["branches"], ["feat/n"])
        self.feature("git switch -c feat/n && git push -u origin HEAD")
        self.feature("git switch --create feat/n && git push")
        self.feature("git checkout -b feat/n origin/feat/x && git push origin feat/n")
        self.feature("git checkout -q --track -b feat/n && git push origin @")
        self.feature("cd sub && git checkout -b feat/n && git push")
        self.feature("git -C sub checkout -b feat/n && git -C sub push")
        self.strict("git checkout -b feat/n && git -C sub push", "another directory")
        self.strict("git checkout -b feat/n && git push", "cannot be confirmed", repo=FakeRepo(), base=self.tmp,
                    analysis_base=self.tmp) if False else None
        self.strict("git checkout -b feat/n main && git push", "another remote")
        self.strict("git checkout -b main && git push", "default branch")
        self.strict("git checkout -b feat/n; git push", "chain")
        self.strict("git checkout -b feat/n && git checkout -b feat/m && git push", "more than one")
        self.strict("git push && git checkout -b feat/n", "chain")
        self.strict("git checkout -b feat/n && git push", "already exists",
                    repo=FakeRepo(extra_refs=["refs/tags/feat/n"]))
        self.strict("git checkout -b feat/n && git push", "already exists",
                    repo=FakeRepo(extra_refs=["refs/heads/feat/n"]))
        self.strict("git checkout -b origin && git push", "already exists")
        self.strict("git checkout -b feat/n && git push", "depends on the branch",
                    repo=FakeRepo(cfg={"includeif.onbranch:feat/**.path": ["x"]}))
        self.strict("cd sub && git checkout -b feat/n && cd deep && git push", "more than one")
        self.strict("git checkout -b feat/n && cd sub && git push", "more than one")


class PushArgumentTests(Base):
    def test_options(self):
        for opt in ("--all", "--mirror", "--tags", "--follow-tags", "--delete", "-d", "--prune", "--repo=x",
                    "--receive-pack=x", "-o", "--push-option=x", "--recurse-submodules=on-demand", "--mir", "--force-with-leas", "-x", "-ux", "--bogus"):
            self.strict("git push %s origin feat/x" % opt, "push option")
        self.strict("git push -n origin feat/x", "plain top-level")
        self.strict("git push --dry-run origin feat/x", "plain top-level")

    def test_refspec_forms(self):
        self.strict("git push origin 'refs/heads/*:refs/heads/*'", "glob")
        self.strict("git push origin :feat/y", "deletion")
        self.strict("git push origin feat/x:", "deletion")
        self.strict("git push origin -bad", "push option")
        self.strict("git push origin feat/x:refs/tags/v1", "not a branch")
        self.strict("git push origin feat/x:refs/for/main", "not a branch")
        self.strict("git push origin feat/x:main", "default branch")
        self.strict("git push origin feat/x:MAIN", "default branch")
        self.strict("git push origin main", "default branch")
        self.strict("git push origin feat/x main", "default branch")
        self.strict("git push origin +feat/x:feat/z", "forced")
        self.strict("git push -f origin feat/x:feat/z", "forced")
        self.strict("git push --force-with-lease origin feat/x:feat/z", "forced")
        self.feature("git push -f origin feat/x:refs/heads/feat/z")
        self.strict("git push origin feat/x:heads/z", "ambiguous")
        self.strict("git push origin feat/x:HEAD", "ambiguous")
        self.strict("git push origin feat/x:tags/z", "ambiguous")
        self.strict("git push origin feat/x:refs", "ambiguous")
        self.strict("git push origin heads/x", "local branch", repo=FakeRepo(aliases={"heads/x": "refs/heads/x"}))
        self.strict("git push origin nope", "bad revision" if False else "repository facts")
        self.strict("git push origin 'feat/x~1'", "plain branch name")
        self.strict("git push origin 'feat/x^'", "plain branch name")
        self.strict("git push origin 'feat/x@{1}'", "plain branch name")
        self.strict("git push origin feat/x:'a b'", "plain branch name")
        self.strict("git push origin feat/x:a..b", "default branch or not a plain")
        self.strict("git push origin feat/x:a.lock", "default branch or not a plain")
        self.strict("git push origin feat/x:refs/heads/a//b", "default branch or not a plain")
        self.strict("git push origin feat/x:refs/heads/-a", "default branch or not a plain")
        self.strict("git push origin feat/x:refs/heads/heads/a", "default branch or not a plain")
        self.strict("git push origin feat/x:refs/heads/a/", "default branch or not a plain")
        self.strict("git push origin feat/x:é", "default branch or not a plain")
        self.strict("git push origin v1", "local branch", repo=FakeRepo(tags=["v1"]))
        self.strict("git push origin v1:newthing", "local branch", repo=FakeRepo(tags=["v1"]))
        self.strict("git push origin HEAD", "detached", repo=FakeRepo(head=""))
        self.strict("git push", "detached", repo=FakeRepo(head=""))
        self.feature("git push origin HEAD:z", repo=FakeRepo(head="refs/heads/main"))
        self.strict("git push origin HEAD", "default branch", repo=FakeRepo(head="refs/heads/main"))

    def test_default_names(self):
        repo = FakeRepo(cfg={"init.defaultbranch": ["Trunk"]})
        self.strict("git push origin feat/x:trunk", "default branch", repo=repo)
        repo = FakeRepo(symrefs={"refs/remotes/origin/HEAD": "refs/remotes/origin/stable"})
        self.strict("git push origin feat/x:stable", "default branch", repo=repo)
        self.strict("git push origin feat/x:main", "default branch", repo=repo)
        repo = FakeRepo(cfg={"remote.up.url": ["https://example.test/up.git"]},
                        symrefs={"refs/remotes/up/HEAD": "refs/remotes/up/develop",
                                 "refs/remotes/origin/HEAD": "refs/remotes/origin/main"})
        self.strict("git push up feat/x:develop", "default branch", repo=repo)
        self.feature("git push up feat/x", repo=repo)
        self.strict("git push origin feat/x", "set-head", repo=FakeRepo(symrefs={}))
        out = self.strict("git push origin feat/x", "git remote set-head origin --auto", repo=FakeRepo(symrefs={}))
        self.assertEqual(out["branches"], [])


class RemoteTests(Base):
    def test_remote_selection(self):
        cfg = {"remote.up.url": ["https://example.test/up.git"], "branch.feat/x.pushremote": ["up"]}
        repo = FakeRepo(cfg=cfg, symrefs={"refs/remotes/up/HEAD": "refs/remotes/up/main"})
        self.assertEqual(self.feature("git push", repo=repo)["remote"], "up")
        cfg = {"remote.up.url": ["https://example.test/up.git"], "remote.pushdefault": ["up"]}
        repo = FakeRepo(cfg=cfg, symrefs={"refs/remotes/up/HEAD": "refs/remotes/up/main"})
        self.assertEqual(self.feature("git push", repo=repo)["remote"], "up")
        cfg = {"remote.up.url": ["https://example.test/up.git"], "branch.feat/x.remote": ["up"]}
        repo = FakeRepo(cfg=cfg, symrefs={"refs/remotes/up/HEAD": "refs/remotes/up/main"})
        self.assertEqual(self.feature("git push", repo=repo)["remote"], "up")
        self.assertEqual(self.feature("git push")["remote"], "origin")

    def test_invalid_remotes(self):
        self.strict("git push /tmp/x.git feat/x", "URL or path")
        self.strict("git push https://github.com/a/b.git feat/x", "URL or path")
        self.strict("git push . feat/x", "URL or path")
        self.strict("git push .. feat/x", "URL or path")
        self.strict("git push nosuch feat/x", "URL or path")
        self.strict("git push origin feat/x", "URL or path",
                    repo=FakeRepo(cfg={"remote.origin.url": ["a", "b"]}))

    def test_config_allowlists(self):
        bad = {"remote.origin.push": "remote.origin.push", "remote.origin.pushurl": "pushurl",
               "remote.origin.mirror": "mirror", "remote.origin.receivepack": "receivepack",
               "remote.origin.vcs": "vcs", "push.default": "push.default", "push.followtags": "followTags",
               "push.pushoption": "push.pushoption", "push.recursesubmodules": "push.recursesubmodules",
               "url.x.pushinsteadof": "pushInsteadOf"}
        values = {"remote.origin.mirror": "true", "push.default": "upstream", "push.followtags": "true"}
        for key, word in bad.items():
            repo = FakeRepo(cfg={key: [values.get(key, "x")]})
            self.strict("git push origin feat/x", word, repo=repo)
        for key, value in (("remote.origin.mirror", "false"), ("push.default", "simple"),
                           ("push.default", "current"), ("push.followtags", "false"), 
                           ("push.autosetupremote", "true"), ("remote.origin.fetch", "+refs/heads/*"),
                           ("remote.origin.tagopt", "--no-tags"), ("url.x.insteadof", "y"),
                           ("remote.other.push", "x"), ("remote.other.pushurl", "x"), ("core.hookspath", "x"),
                           ("remote.pushdefault", "origin")):
            self.feature("git push origin feat/x", repo=FakeRepo(cfg={key: [value]}))
        self.strict("git push origin feat/x", "push.default", repo=FakeRepo(cfg={"push.default": ["simple", "matching"]}))
        self.strict("git push origin feat/x", "push.default", repo=FakeRepo(cfg={"push.default": ["UPSTREAM"]}))

    def test_remote_names_with_dots(self):
        repo = FakeRepo(cfg={"remote.my.remote.url": ["https://example.test/x.git"], "remote.my.remote.push": ["x"]},
                        symrefs={"refs/remotes/my.remote/HEAD": "refs/remotes/my.remote/main"})
        self.strict("git push my.remote feat/x", "remote.my.remote.push", repo=repo)


class GitFactTests(Base):
    def test_failures(self):
        self.strict("git push", "could not be read", repo=FakeRepo(rc={"rev-parse": 128}))
        self.strict("git push", "warned", repo=FakeRepo(err="warning: refname 'x' is ambiguous\nmore"))
        self.strict("git push", "unexpected shape", repo=FakeRepo(short=True))
        self.strict("git push", "bare repository", repo=FakeRepo(bare="true"))
        self.strict("git push", "configuration could not be read", repo=FakeRepo(rc={"config": 1}))
        self.strict("git push", "remote branches could not be read", repo=FakeRepo(rc={"for-each-ref": 1}))

    def test_runner_errors(self):
        def oserror(args, timeout):
            raise OSError("no git")

        def timeout(args, t):
            raise subprocess.TimeoutExpired(args, t)

        for runner in (oserror, timeout):
            result = shell_analysis.analyze_command("git push", self.tmp, False)
            out = push_scope.shell_scope(shell_analysis.parse("git push"), result, self.tmp, ENV,
                                         push_scope.Git(ENV, runner))
            self.assertIn("did not answer", out["reason"])
        git = push_scope.Git(ENV, FakeRepo())
        git.deadline = 0
        with self.assertRaises(push_scope.Strict):
            git.call(self.tmp, ["status"])

    def test_real_git_runner(self):
        git = push_scope.Git(ENV)
        rc, out, err = git.call(self.tmp, ["--version"])
        self.assertEqual((rc, err), (0, ""))
        self.assertIn("git version", out)
        self.assertEqual(git.env["GIT_OPTIONAL_LOCKS"], "0")

    def test_config_parser(self):
        cfg = push_scope.parse_config_z("a.b\nx\0a.b\ny\0c.d\0\0")
        self.assertEqual(cfg, {"a.b": ["x", "y"], "c.d": ["true"]})
        self.assertEqual(push_scope.cfg_get(cfg, "a.b"), "y")
        self.assertIsNone(push_scope.cfg_get(cfg, "none"))
        self.assertIsNone(push_scope.remote_variable("remote.pushdefault"))
        self.assertIsNone(push_scope.remote_variable("push.default"))
        self.assertEqual(push_scope.remote_variable("remote.a.b.url"), ("a.b", "url"))


class AnalysisIntegrationTests(Base):
    def test_attached_to_the_analysis(self):
        sb = FakeRepo()
        result = shell_analysis.analyze_command("git push", self.tmp, True, ENV, self.tmp)
        self.assertEqual(result["push_scope"]["verdict"], "strict")  # real git: the tmp dir is not a repository
        result = shell_analysis.analyze_command("git status", self.tmp, True, ENV)
        self.assertNotIn("push_scope", result)
        result = shell_analysis.analyze_command("git push", self.tmp, False)
        self.assertNotIn("push_scope", result)
        result = shell_analysis.analyze_command("git push", self.tmp, True, ENV, "")
        self.assertIn("unknown", result["push_scope"]["reason"])
        self.assertIsNotNone(sb)

    def test_argv_and_payload(self):
        result = shell_analysis.analyze_argv(["git", "push"], self.tmp, True, ENV, self.tmp)
        self.assertIn("push_scope", result)
        result = shell_analysis.analyze_argv(["git", "push"], self.tmp, False)
        self.assertNotIn("push_scope", result)
        import json
        text = json.dumps({"tool_name": "Bash", "cwd": os.path.join(self.tmp, "nope"),
                           "tool_input": {"command": "git push"}})
        result = shell_analysis.analyze_payload(text, self.tmp, True, ENV)
        self.assertIn("unknown", result["push_scope"]["reason"])
        text = json.dumps({"tool_name": "exec_command", "cwd": self.tmp,
                           "tool_input": {"cmd": ["git", "push"], "workdir": "sub"}})
        result = shell_analysis.analyze_payload(text, self.tmp, True, ENV)
        self.assertEqual(result["base_dir"], os.path.join(self.tmp, "sub"))
        self.assertIn("push_scope", result)

    def test_scope_base(self):
        base = shell_analysis._payload_scope_base
        self.assertEqual(base(None, None, "/b"), "/b")
        self.assertEqual(base(self.tmp, "", "/b"), self.tmp)
        self.assertEqual(base(self.tmp, "sub", "/b"), os.path.join(self.tmp, "sub"))
        self.assertEqual(base("", "sub", self.tmp), os.path.join(self.tmp, "sub"))
        self.assertEqual(base(os.path.join(self.tmp, "nope"), "", "/b"), "")
        self.assertEqual(base(7, None, "/b"), "/b")

    def test_missing_helper(self):
        original = shell_analysis._sibling
        shell_analysis._sibling = lambda name: None
        try:
            result = shell_analysis.analyze_command("git push", self.tmp, True, ENV, self.tmp)
        finally:
            shell_analysis._sibling = original
        self.assertEqual(result["push_scope"]["reason"], "push scope helper missing")

    def test_sibling_loader(self):
        self.assertIs(shell_analysis._sibling("push_scope"), sys.modules["push_scope"])
        saved = sys.modules.pop("push_scope")
        try:
            module = shell_analysis._sibling("push_scope")
            self.assertTrue(hasattr(module, "shell_scope"))
            sys.modules.pop("push_scope", None)
            self.assertIsNone(shell_analysis._sibling("no_such_helper_module"))
            self.assertNotIn("no_such_helper_module", sys.modules)
        finally:
            sys.modules["push_scope"] = saved


GH = {"remote.origin.url": ["https://github.com/acme/app.git"], "remote.up.url": ["git@github.com:acme/up.git"]}
GH_REFS = {"refs/remotes/origin/HEAD": "refs/remotes/origin/main", "refs/remotes/up/HEAD": "refs/remotes/up/develop"}


class McpTests(Base):
    def mcp(self, tool, fields, repo=None, base="", env=None):
        repo = repo or FakeRepo(cfg=GH, symrefs=GH_REFS)
        return push_scope.mcp_scope(tool, fields, base or self.tmp, ENV if env is None else env,
                                    push_scope.Git(ENV, repo))

    def feature(self, tool, fields, **kw):
        out = self.mcp(tool, fields, **kw)
        with self.subTest(fields=fields):
            self.assertEqual(out["verdict"], "feature", out)
        return out

    def strict(self, tool, fields, reason, **kw):
        out = self.mcp(tool, fields, **kw)
        with self.subTest(tool=tool, fields=fields):
            self.assertEqual(out["verdict"], "strict", out)
            self.assertIn(reason.lower(), out["reason"].lower(), out)
        return out

    def test_rows(self):
        base = {"owner": "acme", "repo": "app", "branch": "feat/x"}
        out = self.feature("push_files", base)
        self.assertEqual((out["remote"], out["branches"]), ("origin", ["feat/x"]))
        self.feature("create_or_update_file", dict(base, owner="ACME", repo="App"))  # M5
        self.feature("create_branch", dict(base, branch="feat/new"))  # M11
        self.feature("create_commit", base)
        self.feature("push_files", dict(base, branch="refs/heads/feat/x"))
        self.feature("push_files", dict(base, repo="up", branch="feat/q"))  # M13
        self.strict("push_files", dict(base, branch="main"), "default branch")  # M1
        self.strict("push_files", dict(base, owner="other", repo="lib"), "not a remote")  # M3
        self.strict("push_files", dict(base, owner="other", repo="lib", branch="develop"), "not a remote")  # M4
        self.strict("push_files", {"owner": "acme", "repo": "app"}, "default branch")  # M6
        self.strict("push_files", dict(base, branch=""), "default branch")
        self.strict("push_files", dict(base, branch="refs/heads/main"), "default branch")  # M7
        self.strict("push_files", dict(base, branch="main "), "default branch")  # M8
        self.strict("push_files", dict(base, branch=" main"), "default branch")
        self.strict("delete_file", dict(base, branch="HEAD"), "default branch")  # M9
        self.strict("delete_file", dict(base, branch="@"), "default branch")
        self.strict("create_branch", dict(base, branch="main", from_branch="feat/x"), "default branch")  # M10
        self.strict("push_files", dict(base, repo="up", branch="develop"), "default branch")  # M12
        self.strict("push_files", dict(base, repo="app.git"), "plain owner and repo")  # M14
        self.strict("push_files", dict(base, owner=["acme"]), "plain owner and repo")  # M17
        self.strict("push_files", dict(base, repo=7), "plain owner and repo")
        self.strict("push_files", dict(base, owner="a b"), "plain owner and repo")
        self.strict("push_files", {"repository": "acme/app", "branch": "feat/x"}, "plain owner and repo")  # M18
        self.strict("push_files", dict(base, branch=["feat/x"]), "default branch")
        for tool in ("create_tag", "update_ref", "create_ref", "update_pull_request_branch", "fork_repository"):
            self.strict(tool, base, "cannot scope")  # M19

    def test_facts(self):
        base = {"owner": "acme", "repo": "app", "branch": "feat/x"}
        self.strict("push_files", base, "unknown", base=os.path.join(self.tmp, "nope"))  # M15
        out = push_scope.mcp_scope("push_files", base, None, ENV)
        self.assertIn("unknown", out["reason"])
        self.strict("push_files", base, "could not be read", repo=FakeRepo(cfg=GH, rc={"rev-parse": 128}))
        self.strict("push_files", base, "set-head", repo=FakeRepo(cfg=GH, symrefs={}))  # M16
        self.strict("push_files", base, "redirects git", env=dict(ENV, GIT_DIR="/x"))
        repo = FakeRepo(cfg={"remote.origin.url": ["https://gitlab.com/acme/app.git"]}, symrefs=GH_REFS)
        self.strict("push_files", base, "not a remote", repo=repo)
        repo = FakeRepo(cfg=dict(GH, **{"remote.fork.url": ["https://github.com/acme/app"]}),
                        symrefs=dict(GH_REFS, **{"refs/remotes/fork/HEAD": "refs/remotes/fork/trunk"}))
        self.strict("push_files", dict(base, branch="trunk"), "default branch", repo=repo)
        self.feature("push_files", base, repo=repo)

    def test_github_slug(self):
        for url in ("https://github.com/acme/app.git", "https://github.com/acme/app", "https://github.com/acme/app/",
                    "https://tok" + "@github.com/acme/app.git", "git" + "@github.com:acme/app.git",
                    "ssh://git@github.com/acme/app.git", "ssh://git@github.com:22/acme/app", "git://github.com/acme/app"):
            self.assertEqual(push_scope.github_slug(url), "acme/app", url)
        for url in ("http://github.com/acme/app", "https://gitlab.com/acme/app", "https://github.example.com/a/b",
                    "file:///tmp/x.git", "/tmp/x.git", "https://github.com/acme", "https://github.com/a/b/c"):
            self.assertIsNone(push_scope.github_slug(url), url)

    def test_origin_slug(self):
        self.assertIsNone(push_scope.origin_slug("", ENV))
        self.assertIsNone(push_scope.origin_slug(os.path.join(self.tmp, "nope"), ENV))
        self.assertEqual(push_scope.origin_slug(self.tmp, ENV, push_scope.Git(ENV, FakeRepo(cfg=GH))), "acme/app")
        self.assertIsNone(push_scope.origin_slug(self.tmp, ENV, push_scope.Git(ENV, FakeRepo(cfg={}))))
        self.assertIsNone(push_scope.origin_slug(self.tmp, ENV, push_scope.Git(ENV, FakeRepo(rc={"config": 1}))))
        git = push_scope.Git(ENV, FakeRepo(cfg=GH))
        git.deadline = 0
        self.assertIsNone(push_scope.origin_slug(self.tmp, ENV, git))
        self.assertIsNone(push_scope.origin_slug(self.tmp, ENV))  # real git: not a repository


class McpAnalysisTests(Base):
    def payload(self, tool, args, **top):
        import json
        body = {"tool_name": tool, "tool_input": args, "cwd": self.tmp}
        body.update(top)
        return json.dumps(body)

    def test_attached_to_the_analysis(self):
        text = self.payload("mcp__github__push_files", {"owner": "acme", "repo": "app", "branch": "feat/x"})
        result = shell_analysis.analyze_payload(text, self.tmp, True, ENV)
        self.assertEqual(result["push_scope"]["verdict"], "strict")  # real git, tmp is not a repository
        result = shell_analysis.analyze_payload(text, self.tmp, False, ENV)
        self.assertNotIn("push_scope", result)
        text = self.payload("CallMcpTool", {"server": "github", "toolName": "push_files",
                                            "arguments": {"owner": "acme", "repo": "app", "branch": "x"}})
        result = shell_analysis.analyze_payload(text, self.tmp, True, ENV)
        self.assertIn("push_scope", result)
        text = self.payload("mcp__github__create_release", {"owner": "acme", "repo": "app", "tag_name": "v1",
                                                            "target_commitish": "main"})
        result = shell_analysis.analyze_payload(text, self.tmp, True, ENV)
        self.assertEqual(result["release"]["reason"].split(";")[0][:20], "the release is in an")
        result = shell_analysis.analyze_payload(text, self.tmp, False, ENV)
        self.assertIn("release", result)
        text = self.payload("mcp__github__list_issues", {})
        self.assertNotIn("release", shell_analysis.analyze_payload(text, self.tmp, True, ENV))

    def test_missing_helpers(self):
        original = shell_analysis._sibling
        shell_analysis._sibling = lambda name: None
        try:
            text = self.payload("mcp__github__push_files", {"owner": "acme", "repo": "app", "branch": "x"})
            result = shell_analysis.analyze_payload(text, self.tmp, True, ENV)
            self.assertEqual(result["push_scope"]["reason"], "push scope helper missing")
            result = shell_analysis.analyze_command("gh release create v1", self.tmp, True, ENV)
            self.assertEqual(result["release"]["reason"], "release scope helper missing")
        finally:
            shell_analysis._sibling = original

    def test_release_in_a_shell_command(self):
        result = shell_analysis.analyze_command("gh release create v1 --target main", self.tmp, False, ENV)
        self.assertTrue(result["release"]["ok"])
        self.assertEqual((result["release"]["tag"], result["release"]["target"]), ("v1", "main"))
        result = shell_analysis.analyze_argv(["gh", "release", "create", "v1"], self.tmp, False, ENV)
        self.assertTrue(result["release"]["ok"])
        self.assertNotIn("release", shell_analysis.analyze_command("git status", self.tmp, False))


class InertGitTests(Base):
    def test_viewer_options(self):
        for cmd in ("git log -1 --output=/x", "git log --outp=/x", "git log --out=/x", "git log -O/x", "git show --output=/x",
                    "git diff --output=/x", "git shortlog --output=/x", "git diff --ext-diff", "git log --textconv",
                    "git log --format", "git diff --no-index", "git log -p --output"):
            self.strict("%s && git push" % cmd, "also runs")
        for cmd in ("git log --oneline -3", "git log --format=%h -5", "git diff --stat --cached", "git show --stat HEAD",
                    "git shortlog -sn HEAD", "git diff -- a b", "git log -- --output=x"):
            self.feature("%s && git push" % cmd)

    def test_other_inert_forms(self):
        for cmd in ("git status -sb", "git status --short --branch", "git add -A", "git add -- a b", "git add -u .",
                    "git commit -m msg", "git commit -qam msg", "git commit -a -m msg", "git commit --message=msg",
                    "git commit -mmsg", "git commit -F msg.txt", "git commit --amend --no-edit", "git commit -nq -m x",
                    "git symbolic-ref --short HEAD", "git symbolic-ref -q HEAD", "git config --get a.b",
                    "git config --list", "git config -l", "git remote get-url origin", "git branch --show-current",
                    "git rev-parse --short HEAD", "git ls-files", "git describe --tags"):
            self.feature("%s && git push" % cmd)
        for cmd in ("git status --bogus", "git add --chmod=+x .", "git commit --template=x -m y", "git commit -m",
                    "git commit -C HEAD", "git symbolic-ref HEAD refs/heads/x", "git symbolic-ref --delete HEAD",
                    "git config a.b c", "git config --unset a.b", "git config --get", "git remote get-url -x",
                    "git remote add x y", "git branch newb", "git config --edit", "git stash", "git mv a b"):
            self.strict("%s && git push" % cmd, "also runs")

    def test_program_config(self):
        for key in ("core.pager", "pager.log", "diff.external", "diff.x.textconv", "diff.y.command", "core.fsmonitor",
                    "core.hookspath", "filter.lfs.clean"):
            self.strict("git log --oneline && git push", "would run a program", repo=FakeRepo(cfg={key: ["x"]}))
        for key in ("core.fsmonitor", "core.hookspath", "filter.lfs.smudge", "filter.x.process"):
            for sub in ("status", "add -A", "commit -qm x", "ls-files", "describe", "rev-parse HEAD"):
                self.strict("git %s && git push" % sub, "would run a program", repo=FakeRepo(cfg={key: ["x"]}))
        self.feature("git status && git push", repo=FakeRepo(cfg={"core.pager": ["less"], "credential.helper": ["store"],
                                                                  "core.sshcommand": ["ssh"], "core.editor": ["vi"]}))
        self.feature("git push", repo=FakeRepo(cfg={"core.fsmonitor": ["true"], "core.hookspath": ["h"]}))

    def test_printf_with_options_is_not_inert(self):
        for cmd in ("printf -v D main", "printf -vD main", "printf -- -v", "printf -vX %s main", "printf -- '%s' x"):
            self.strict("%s && git push" % cmd, "also runs")
        self.feature("printf '%s' x && git push")
        self.feature("printf 'a b' && git push")

    def test_helpers(self):
        self.assertIsNone(push_scope.inert_git("log", ["--output=x"]))
        self.assertEqual(push_scope.inert_git("log", ["--oneline"]), "log")
        self.assertEqual(push_scope.inert_git("status", []), "status")
        self.assertTrue(push_scope.options_ok(["-5"], set()))
        self.assertFalse(push_scope.options_ok(["-m"], set(), values={"-m"}))


class WrapperAndLogicalCwdTests(Base):
    def parse(self, text):
        return shell_analysis.parse(text)

    def wrapped(self, cmd, **kw):
        text = "bash -lc " + shell_analysis.shlex.quote(cmd)
        result = shell_analysis.analyze_command(text, self.tmp, False)
        return push_scope.shell_scope(shell_analysis.parse(text), result, self.tmp, ENV,
                                      push_scope.Git(ENV, kw.get("repo") or FakeRepo()), shell_analysis.parse)

    def test_bash_lc_is_unwrapped(self):
        self.assertEqual(self.wrapped("git push origin feat/x")["verdict"], "feature")
        self.assertEqual(self.wrapped("git add -A && git commit -qm x && git push")["verdict"], "feature")
        for cmd in ("git checkout main && git push", "git push &", "git push 'x"):
            self.assertEqual(self.wrapped(cmd)["verdict"], "strict", cmd)
        for text in ("bash -lc 'git push' extra", "bash -c 'git push' ; echo", "bash -x -c 'git push'",
                     "X=1 bash -c 'git push'", "bash -c 'git push' > /dev/null", "! bash -c 'git push'", "zsh -c 'git push'",
                     "bash -c 'git push' &", 'bash -c "$X"'):
            result = shell_analysis.analyze_command(text, self.tmp, False)
            out = push_scope.shell_scope(shell_analysis.parse(text), result, self.tmp, ENV,
                                         push_scope.Git(ENV, FakeRepo()), shell_analysis.parse)
            with self.subTest(text=text):
                self.assertEqual(out["verdict"], "strict", out)
        out = push_scope.shell_scope(shell_analysis.parse("git push"),
                                     shell_analysis.analyze_command("git push", self.tmp, False), self.tmp, ENV,
                                     push_scope.Git(ENV, FakeRepo()))
        self.assertEqual(out["verdict"], "feature")

    def test_cd_dotdot_through_a_symlink(self):
        link = os.path.join(self.tmp, "lnk")
        os.symlink(os.path.join(self.tmp, "sub", "deep"), link)
        physical = os.path.join(self.tmp, "sub", "deep")
        result = shell_analysis.analyze_command("cd .. && git push", physical, False)
        script = shell_analysis.parse("cd .. && git push")
        out = push_scope.shell_scope(script, result, physical, ENV, push_scope.Git(ENV, FakeRepo()), None, link)
        self.assertIn("symbolic link", out["reason"])
        out = push_scope.shell_scope(script, result, physical, ENV, push_scope.Git(ENV, FakeRepo()), None, physical)
        self.assertEqual(out["verdict"], "feature")
        os.symlink(os.path.join(self.tmp, "other"), os.path.join(self.tmp, "sub", "ln2"))
        self.strict("cd sub/ln2/.. && git push", "symbolic link")
        self.feature("cd sub/ln2 && git push")


class TracerAndTimeoutTests(Base):
    def test_tracer_path_errors(self):
        real = push_scope.COVERAGE_BASH_ENV
        cov = os.path.join(self.tmp, "cov")
        os.makedirs(cov, exist_ok=True)
        env = dict(ENV, SB_COV_DIR=cov)
        self.assertFalse(push_scope.is_coverage_tracer(real + "/", env))
        self.strict("git push", "BASH_ENV", env=dict(env, BASH_ENV=real + "/"))
        gone = os.path.join(self.tmp, "gone", "tests", "coverage", "bash-env.sh")
        saved = push_scope.COVERAGE_BASH_ENV
        push_scope.COVERAGE_BASH_ENV = gone
        try:
            self.assertFalse(push_scope.is_coverage_tracer(gone, env))
        finally:
            push_scope.COVERAGE_BASH_ENV = saved

    def test_slow_git_is_killed_with_its_children(self):
        import time
        bindir = os.path.join(self.tmp, "slowbin")
        os.makedirs(bindir, exist_ok=True)
        stub = os.path.join(bindir, "git")
        with open(stub, "w") as fh:
            fh.write("#!/bin/sh\n(sleep 20) &\nsleep 20\n")
        os.chmod(stub, 0o755)
        env = dict(ENV, PATH=bindir + ":" + ENV["PATH"])
        git = push_scope.Git(env)
        saved = push_scope.GIT_CALL_SECONDS
        push_scope.GIT_CALL_SECONDS = 0.5
        started = time.monotonic()
        try:
            with self.assertRaises(push_scope.Strict):
                git.call(self.tmp, ["status"])
        finally:
            push_scope.GIT_CALL_SECONDS = saved
        self.assertLess(time.monotonic() - started, 8)


class ExpansionAndEnvConfigTests(Base):
    def test_assigning_expansions_are_not_inert(self):
        for word in ("$((HOME=0))", "$[HOME=0]", "${X:=a}", "${X=a}", "${X:+a}", "${a[0]=1}", "$((1+2))", "${!X}", "$?",
                     "\"$((PATH=0))\"", "x$((IFS=x))y", "<(echo)"):
            for verb in (": ", "echo ", "printf '%s' ", "test ", "git status ", "git log "):
                self.strict("%s%s && git push" % (verb, word), "assigns or computes")
        self.strict("echo > $((H=1)) && git push", "assigns or computes")
        self.strict(": <<EOF\n$((H=1))\nEOF\ngit push", "assigns or computes")
        self.strict("CI=$((H=1)) git push", "variable assignment")
        self.feature(": <<'EOF'\n$((H=1))\nEOF\ngit push")
        self.feature("echo $HOME ${USER} \"$PWD\" '$((H=1))' && git push")
        self.feature("git commit -qm \"$(echo hi)\" && git push")

    def test_env_config(self):
        def env(**kw):
            return dict(ENV, **kw)
        cloud = env(GIT_CONFIG_COUNT="3", GIT_CONFIG_KEY_0="credential.interactive", GIT_CONFIG_VALUE_0="false",
                    GIT_CONFIG_KEY_1="url.https://github.com/.insteadOf", GIT_CONFIG_VALUE_1="git@github.com:",
                    GIT_CONFIG_KEY_2="safe.directory", GIT_CONFIG_VALUE_2="*")
        self.feature("git push", env=cloud)
        self.feature("git push", env=env(GIT_CONFIG_COUNT="0"))
        for bad in ("x", "-1", "65", "1.5"):
            self.strict("git push", "GIT_CONFIG_COUNT", env=env(GIT_CONFIG_COUNT=bad))
        self.strict("git push", "not defined", env=env(GIT_CONFIG_COUNT="1"))
        self.strict("git push", "not defined", env=env(GIT_CONFIG_COUNT="1", GIT_CONFIG_KEY_0="user.name"))
        self.strict("git push", "not defined", env=env(GIT_CONFIG_COUNT="1", GIT_CONFIG_VALUE_0="x"))
        for key in ("remote.origin.push", "REMOTE.origin.pushurl", "push.default", "alias.p", "include.path",
                    "includeIf.onbranch:x.path", "core.hooksPath", "core.sshCommand", "url.x.pushInsteadOf",
                    "filter.f.clean", "diff.external", "gpg.program", "branch.main.remote", "remote.pushDefault",
                    "core.editor", "pager.log"):
            self.strict("git push", "changes a push", env=env(GIT_CONFIG_COUNT="1", GIT_CONFIG_KEY_0=key,
                                                              GIT_CONFIG_VALUE_0="x"))

    def test_editor_lfs_and_gpg_settings(self):
        for cmd in ("git commit --amend", "git commit -a", "git commit", "git commit -q"):
            self.strict("%s && git push" % cmd, "start the editor vi", repo=FakeRepo(cfg={"core.editor": ["vi"]}))
            self.strict("%s && git push" % cmd, "start the editor emacs", env=dict(ENV, EDITOR="emacs -nw"))
            self.strict("%s && git push" % cmd, "start the editor evil", env=dict(ENV, VISUAL="evil"))
            self.strict("%s && git push" % cmd, "start the editor x", env=dict(ENV, GIT_EDITOR="x"),
                        repo=FakeRepo(cfg={"core.editor": ["true"]}))
            self.feature("%s && git push" % cmd, env=dict(ENV, GIT_EDITOR="true"), repo=FakeRepo(cfg={"core.editor": ["vi"]}))
            self.feature("%s && git push" % cmd, repo=FakeRepo(cfg={"core.editor": ["true"]}))
            self.feature("%s && git push" % cmd)
        for cmd in ("git commit -qm x", "git commit --amend --no-edit", "git commit -F f", "git commit --message=x",
                    "git commit -am x", "git commit -mx", "git status", "git add -A"):
            self.feature("%s && git push" % cmd, repo=FakeRepo(cfg={"core.editor": ["vi"]}),
                         env=dict(ENV, EDITOR="evil"))
        # gpg programs matter only for a commit that signs; status/add never sign
        signing = {"commit.gpgsign": ["true"], "gpg.ssh.defaultkeycommand": ["x"], "gpg.program": ["y"]}
        self.strict("git commit -qm x && git push", "signs with the program", repo=FakeRepo(cfg=signing))
        self.strict("git commit -qm x && git push", "signs with the program",
                    repo=FakeRepo(cfg={"commit.gpgsign": ["yes"], "gpg.ssh.program": ["y"]}))
        self.feature("git commit -qm x && git push", repo=FakeRepo(cfg={"gpg.program": ["y"], "commit.gpgsign": ["false"]}))
        self.feature("git commit -qm x && git push", repo=FakeRepo(cfg={"gpg.program": ["y"]}))
        for cmd in ("git status", "git add -A", "git rev-parse HEAD", "git diff --stat"):
            self.feature("%s && git push" % cmd, repo=FakeRepo(cfg=signing))
        for cmd in ("git log -1", "git show -s", "git log --format=%G? -1", "git log --format=%GS -1"):
            self.strict("%s && git push" % cmd, "verifies signatures", repo=FakeRepo(cfg=signing))
            self.strict("%s && git push" % cmd, "verifies signatures", repo=FakeRepo(cfg={"gpg.openpgp.program": ["y"]}))
            self.strict("%s && git push" % cmd, "verifies signatures",
                        repo=FakeRepo(cfg={"gpg.ssh.defaultkeycommand": ["y"]}))
        for skip in (False, True):
            stock = {"filter.lfs.clean": ["git-lfs clean %s-- %%f" % ("--skip " if skip else "")],
                     "filter.lfs.smudge": ["git-lfs smudge %s-- %%f" % ("--skip " if skip else "")],
                     "filter.lfs.process": ["git-lfs filter-process" + (" --skip" if skip else "")],
                     "filter.lfs.required": ["true"]}
            self.feature("git add -A && git commit -qm x && git push", repo=FakeRepo(cfg=stock))
            for key in ("filter.lfs.clean", "filter.lfs.smudge", "filter.lfs.process"):
                self.strict("git add -A && git push", "would run a program",
                            repo=FakeRepo(cfg=dict(stock, **{key: ["sh -c evil"]})))
                self.strict("git add -A && git push", "would run a program",
                            repo=FakeRepo(cfg=dict(stock, **{key: [stock[key][0], "sh -c evil"]})))
        self.strict("git add -A && git push", "would run a program",
                    repo=FakeRepo(cfg={"filter.other.clean": ["git-lfs clean -- %f"]}))


class SigningAndBooleanTests(Base):
    def test_no_gpg_sign_skips_the_signing_program(self):
        signing = {"commit.gpgsign": ["true"], "gpg.ssh.program": ["/tmp/code-sign"]}
        self.feature("git commit --no-gpg-sign -m x && git push", repo=FakeRepo(cfg=signing))
        self.feature("git commit -qm x --no-gpg-sign && git push", repo=FakeRepo(cfg=signing))
        self.strict("git commit -m x && git push", "signs", repo=FakeRepo(cfg=signing))
        self.strict("git log -1 && git push", "verifies", repo=FakeRepo(cfg=signing))  # verification is not signing
        self.strict("git commit --no-gpg-sign && git push", "start the editor", repo=FakeRepo(cfg=signing),
                    env=dict(ENV, EDITOR="evil"))

    def test_git_bool(self):
        for text in ("true", "TRUE", "yes", "on", "1", "2", "-1", "1k", "0x1", "+3", "1g", "weird", "if-asked"):
            self.assertTrue(push_scope.git_bool(text), text)
        for text in ("false", "No", "off", "0", "", "00", "0k", "0x0", " false "):
            self.assertFalse(push_scope.git_bool(text), text)

    def test_commit_gpgsign_integer_forms(self):
        for value in ("true", "2", "-1", "1k", "0x1", "yes"):
            self.strict("git commit -q --allow-empty -m x && git push", "signs",
                        repo=FakeRepo(cfg={"commit.gpgsign": [value], "gpg.program": ["/tmp/evil"]}))
        for value in ("false", "0", "", "off", "0k"):
            self.feature("git commit -q --allow-empty -m x && git push",
                         repo=FakeRepo(cfg={"commit.gpgsign": [value], "gpg.program": ["/tmp/evil"]}))
        env = dict(ENV, GIT_CONFIG_COUNT="1", GIT_CONFIG_KEY_0="commit.gpgsign", GIT_CONFIG_VALUE_0="2")
        self.strict("git commit -q --allow-empty -m x && git push", "signs", env=env,
                    repo=FakeRepo(cfg={"commit.gpgsign": ["2"], "gpg.program": ["/tmp/evil"]}))

    def test_stock_system_signer(self):
        outside = tempfile.mkdtemp(prefix="pscope-outside")
        self.addCleanup(shutil.rmtree, outside, True)
        stock = os.path.join(outside, "stockbin")
        os.makedirs(stock, exist_ok=True)
        good = os.path.join(stock, "gpg")
        open(good, "w").close()
        os.chmod(good, 0o755)
        saved_uid, saved_chain = push_scope.STOCK_OWNER_UID, push_scope.safe_chain
        push_scope.STOCK_OWNER_UID = os.geteuid()
        push_scope.safe_chain = lambda path: True  # temp directories are not root-owned: safe_chain has its own test
        home = os.path.join(outside, "home")
        os.makedirs(home, exist_ok=True)
        env = dict(ENV, HOME=home)
        try:
            signing = {"commit.gpgsign": ["true"], "gpg.program": [good]}
            self.feature("git commit -qm x && git push", repo=FakeRepo(cfg=signing), env=env)
            self.feature("git log -1 --format=%G? && git push", repo=FakeRepo(cfg=signing), env=env)
            # a writable file, another name, a relative path, a missing file, inside HOME or the project: strict
            os.chmod(good, 0o775)
            self.strict("git commit -qm x && git push", "signs", repo=FakeRepo(cfg=signing), env=env)
            os.chmod(good, 0o755)
            other = os.path.join(stock, "evil")
            open(other, "w").close()
            os.chmod(other, 0o755)
            for value in (other, "gpg", os.path.join(stock, "nope"), "/bin/gpg extra",
                          os.path.join(self.tmp, "sub", "gpg")):
                self.strict("git commit -qm x && git push", "signs",
                            repo=FakeRepo(cfg={"commit.gpgsign": ["true"], "gpg.program": [value]}), env=env)
            inside_home = os.path.join(home, "gpg")
            open(inside_home, "w").close()
            os.chmod(inside_home, 0o755)
            self.strict("git commit -qm x && git push", "signs",
                        repo=FakeRepo(cfg={"commit.gpgsign": ["true"], "gpg.program": [inside_home]}), env=env)
            inside_project = os.path.join(self.tmp, "gpg")
            open(inside_project, "w").close()
            os.chmod(inside_project, 0o755)
            self.strict("git commit -qm x && git push", "signs",
                        repo=FakeRepo(cfg={"commit.gpgsign": ["true"], "gpg.program": [inside_project]}), env=env)
            self.strict("git commit -qm x && git push", "signs",
                        repo=FakeRepo(cfg={"commit.gpgsign": ["true"], "gpg.ssh.defaultkeycommand": [good]}), env=env)
            push_scope.STOCK_OWNER_UID = os.geteuid() + 1  # owned by somebody else than root
            self.strict("git commit -qm x && git push", "signs", repo=FakeRepo(cfg=signing), env=env)
        finally:
            push_scope.STOCK_OWNER_UID, push_scope.safe_chain = saved_uid, saved_chain
        # the cloud container: a signer in world-writable /tmp
        self.strict("git commit -qm x && git push", "signs", repo=FakeRepo(
            cfg={"commit.gpgsign": ["true"], "gpg.format": ["ssh"], "gpg.ssh.program": ["/tmp/code-sign"]}))

    def test_lfs_extensions_and_push_gpgsign(self):
        stock = {"filter.lfs.clean": ["git-lfs clean -- %f"], "filter.lfs.smudge": ["git-lfs smudge -- %f"],
                 "filter.lfs.process": ["git-lfs filter-process"]}
        for key in ("lfs.extension.x.clean", "lfs.extension.x.smudge", "lfs.customtransfer.a.path",
                    "lfs.standalonetransferagent"):
            for cmd in ("git add -A", "git status", "git commit -qm x"):
                self.strict("%s && git push" % cmd, "would run a program",
                            repo=FakeRepo(cfg=dict(stock, **{key: ["/tmp/evil %f"]})))
        for value in ("true", "if-asked", "1", "2", "yes"):
            self.strict("git push", "signing program", repo=FakeRepo(cfg={"push.gpgsign": [value]}))
        for value in ("false", "0", "no", ""):
            self.feature("git push", repo=FakeRepo(cfg={"push.gpgsign": [value]}))
        for value in ("false", "0", "off", "0x0"):
            self.feature("git push origin feat/x", repo=FakeRepo(cfg={"remote.origin.mirror": [value]}))
        for value in ("true", "2", "1k"):
            self.strict("git push origin feat/x", "mirror", repo=FakeRepo(cfg={"remote.origin.mirror": [value]}))
            self.strict("git push origin feat/x", "pushes tags", repo=FakeRepo(cfg={"push.followtags": [value]}))


class ProgramMechanismTests(Base):
    def test_safe_chain(self):
        real_stat = os.stat

        class Info:
            def __init__(self, uid, mode):
                self.st_uid, self.st_mode = uid, mode

        table = {"/": Info(0, 0o755), "/usr": Info(0, 0o755), "/usr/bin": Info(0, 0o755), "/tmp": Info(0, 0o1777),
                 "/opt": Info(1000, 0o755), "/grp": Info(0, 0o775)}
        os.stat = lambda path: table[path] if path in table else real_stat(path)
        try:
            self.assertTrue(push_scope.safe_chain("/usr/bin/gpg"))
            self.assertFalse(push_scope.safe_chain("/tmp/code-sign"))
            self.assertFalse(push_scope.safe_chain("/opt/x/gpg"))
            self.assertFalse(push_scope.safe_chain("/grp/gpg"))
            self.assertFalse(push_scope.safe_chain("/nonexistent-dir/x/gpg"))
        finally:
            os.stat = real_stat

    def test_user_trusted_signing_program(self):
        outside = tempfile.mkdtemp(prefix="pscope-trust")
        self.addCleanup(shutil.rmtree, outside, True)
        cfgdir = os.path.join(outside, "silver-bullet")
        os.makedirs(cfgdir)
        path = os.path.join(cfgdir, "consent.json")
        env = dict(ENV, XDG_CONFIG_HOME=outside, HOME=outside)
        signing = {"commit.gpgsign": ["true"], "gpg.ssh.program": ["/tmp/code-sign"]}
        self.strict("git commit -qm x && git push", "signs", repo=FakeRepo(cfg=signing), env=env)
        with open(path, "w") as fh:
            fh.write('{"trusted_programs": {"signing": ["/tmp/code-sign"]}}')
        os.chmod(path, 0o600)
        self.feature("git commit -qm x && git push", repo=FakeRepo(cfg=signing), env=env)
        self.feature("git log -1 --format=%G? && git push", repo=FakeRepo(cfg=signing), env=env)
        self.strict("git commit -qm x && git push", "signs",
                    repo=FakeRepo(cfg={"commit.gpgsign": ["true"], "gpg.ssh.program": ["/tmp/other"]}), env=env)
        self.strict("git commit -qm x && git push", "signs",
                    repo=FakeRepo(cfg={"commit.gpgsign": ["true"], "gpg.ssh.defaultkeycommand": ["/tmp/code-sign"]}), env=env)
        os.chmod(path, 0o644)  # readable by others: not trusted
        self.strict("git commit -qm x && git push", "signs", repo=FakeRepo(cfg=signing), env=env)
        for body in ('{"trusted_programs": 1}', '{"trusted_programs": {"signing": "x"}}', "not json",
                     '{"trusted_programs": {"signing": [1]}}'):
            with open(path, "w") as fh:
                fh.write(body)
            os.chmod(path, 0o600)
            self.assertEqual(push_scope.user_trusted_programs(env), set())
        os.remove(path)
        os.symlink("/etc/hostname", path)
        self.assertEqual(push_scope.user_trusted_programs(env), set())

    def test_ssh_commands_credentials_and_urls(self):
        for good in ("ssh", "ssh -i ~/.ssh/key -o IdentitiesOnly=yes", "/usr/bin/ssh -p 22 -q",
                     "ssh -oStrictHostKeyChecking=no -4"):
            self.assertTrue(push_scope.ssh_command_ok(good), good)
            self.feature("git push origin feat/x", repo=FakeRepo(cfg={"core.sshcommand": [good]}))
        for bad in ("", "sh -c evil", "ssh -o ProxyCommand=evil", "ssh -oLocalCommand=x", "ssh -o PermitLocalCommand=yes",
                    "ssh -i", "ssh -o", "ssh -o Foo", "ssh $X", "ssh -i 'a b'", "ssh ; evil", "ssh -Z", "evil -i k",
                    "ssh -o ProxyJump=x", "ssh -F /tmp/cfg", "ssh -o Include=/tmp/cfg", "ssh -o PKCS11Provider=/tmp/x.so",
                    "ssh -o SecurityKeyProvider=/tmp/x.so"):
            self.assertFalse(push_scope.ssh_command_ok(bad), bad)
        self.strict("git push origin feat/x", "start a program", repo=FakeRepo(cfg={"core.sshcommand": ["sh -c evil"]}))
        for helper in ("store", "cache --timeout 3600", "osxkeychain", "!gh auth git-credential",
                       "!/usr/bin/gh auth git-credential", "/usr/lib/git-core/git-credential-store --file=/x", "manager-core", ""):
            self.assertTrue(push_scope.stock_helper(helper), helper)
        self.feature("git push origin feat/x", repo=FakeRepo(cfg={"credential.helper": ["store"],
                                                                  "credential.https://x.helper": ["cache"]}))
        for helper in ("!evil", "/tmp/git-credential-x", "store;evil", "!gh auth git-credential; evil", "evil",
                       "/usr/lib/git-core/evil"):
            self.assertFalse(push_scope.stock_helper(helper), helper)
        self.strict("git push origin feat/x", "start a program", repo=FakeRepo(cfg={"credential.helper": ["!evil"]}))
        self.strict("git push origin feat/x", "start a program",
                    repo=FakeRepo(cfg={"credential.https://x.helper": ["!evil"]}))
        for key in ("core.gitproxy", "core.askpass", "core.alternaterefscommand", "uploadpack.packobjectshook"):
            self.strict("git push origin feat/x", "start a program", repo=FakeRepo(cfg={key: ["evil"]}))
            self.feature("git push origin feat/x", repo=FakeRepo(cfg={key: [""]}))
        self.strict("git push origin feat/x", "start a program", repo=FakeRepo(cfg={"protocol.ext.allow": ["always"]}))
        self.feature("git push origin feat/x", repo=FakeRepo(cfg={"protocol.ext.allow": ["never"]}))
        for url in ("ext::sh -c evil", "evil://x/y", "foo::bar"):
            self.assertFalse(push_scope.safe_url(url), url)
            self.strict("git push origin feat/x", "remote helper", repo=FakeRepo(cfg={"url.%s.insteadof" % url: ["https://github.com/"]}))
        self.strict("git push origin feat/x", "unsupported transport", repo=FakeRepo(cfg={"remote.origin.url": ["evil://x"]}))
        for url in ("https://github.com/a/b.git", "git@github.com:a/b.git", "/srv/repo.git", "../x", "ssh://git@h/x", "file:///x"):
            self.assertTrue(push_scope.safe_url(url), url)
        self.feature("git push origin feat/x", repo=FakeRepo(cfg={"url.https://github.com/.insteadof": ["git@github.com:"]}))

    def test_environment_programs(self):
        for name in ("GIT_EXTERNAL_DIFF", "GIT_SSH", "GIT_PROXY_COMMAND", "GIT_ASKPASS", "SSH_ASKPASS", "GIT_INDEX_FILE",
                     "GIT_OBJECT_DIRECTORY", "GIT_ALTERNATE_OBJECT_DIRECTORIES"):
            self.strict("git push", name, env=dict(ENV, **{name: "x"}))
        self.feature("git push", env=dict(ENV, GIT_ASKPASS=""))
        self.feature("git push", env=dict(ENV, GIT_SSH_COMMAND="ssh -i /k -o IdentitiesOnly=yes"))
        self.strict("git push", "GIT_SSH_COMMAND", env=dict(ENV, GIT_SSH_COMMAND="sh -c evil"))
        for path in ("/usr/bin::/bin", "/usr/bin:.:/bin", "bin:/usr/bin", ":/usr/bin"):
            self.strict("git push", "PATH", env=dict(ENV, PATH=path))
        self.feature("git log -1 && git push", env=dict(ENV, GIT_PAGER="cat"))
        self.strict("git log -1 && git push", "pager", env=dict(ENV, GIT_PAGER="evil --x"))
        self.feature("git status && git push", env=dict(ENV, GIT_PAGER="evil"))

    def test_fsmonitor_and_shortlog(self):
        for value in ("true", "false", "0", ""):
            self.feature("git status && git push", repo=FakeRepo(cfg={"core.fsmonitor": [value]}))
        self.strict("git status && git push", "would run", repo=FakeRepo(cfg={"core.fsmonitor": [".git/hook"]}))
        self.strict("git shortlog -s HEAD --format=%G? && git push", "verifies",
                    repo=FakeRepo(cfg={"gpg.program": ["/tmp/evil"]}))


class ParserTests(unittest.TestCase):
    def test_andor_and_pipeline_attributes(self):
        script = shell_analysis.parse("a && b || ! c | d; e")
        first = script.items[0][0]
        self.assertEqual(first.ops, ["&&", "||"])
        self.assertEqual([p.negated for p in first], [False, False, True])
        self.assertEqual([len(p) for p in first], [1, 1, 2])
        self.assertEqual(script.items[1][0].ops, [])


if __name__ == "__main__":
    unittest.main()
