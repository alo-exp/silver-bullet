"""Sandbox of real local git repositories for the push-scope tests (design section 6.2).

``Sandbox(root)`` builds, once, under ``root`` (``S`` below):

* ``S/home/.gitconfig``: user, ``init.defaultBranch=main``, ``protocol.file.allow=always`` and two ``insteadOf``
  rewrites that make ``https://github.com/acme/app.git`` and ``.../acme/up.git`` local bare repositories;
* ``S/origin.git`` (HEAD main; branches main, feat/x, feat/y; tags v1, rtag) and ``S/up.git`` (HEAD develop;
  branches develop, feat/x);
* ``S/w``: a clone of origin with a second remote ``up`` (``remote set-head up develop``), local branches main,
  develop, feat/x (checked out), feat/y, one new commit on main, develop and feat/x, and an untracked file;
* ``S/wt-main``: a worktree of ``main``; ``S/dirfile``/``S/cdfile``; ``S/bin/git`` (execs git in wt-main);
  ``S/plain`` (not a repository).

``restore()`` puts the pristine copy back (same path, so the paths inside the repositories stay valid).
``protected_effect(before, after)`` is the ground-truth predicate used by the corpus.
"""

from __future__ import annotations

import os
import shutil
import subprocess

DEFAULT_BRANCHES = {"main", "master", "develop"}


def git_env(root, extra=None):
    env = {"PATH": os.environ.get("PATH", "/usr/bin:/bin"), "HOME": os.path.join(root, "home"),
           "GIT_CONFIG_NOSYSTEM": "1", "LC_ALL": "C", "TMPDIR": os.path.join(root, "tmp")}
    env.update(extra or {})
    return env


def run(args, cwd, root, extra=None, check=True):
    proc = subprocess.run(args, cwd=cwd, env=git_env(root, extra), capture_output=True, text=True, check=False)
    if check and proc.returncode:
        raise RuntimeError("%s failed: %s" % (args, proc.stderr))
    return proc


class Sandbox:
    def __init__(self, root):
        self.root = os.path.realpath(root)
        self.pristine = self.root + ".pristine"
        self._build()
        shutil.copytree(self.root, self.pristine, symlinks=True)

    def p(self, *parts):
        return os.path.join(self.root, *parts)

    def g(self, cwd, *args):
        return run(["git"] + list(args), cwd, self.root)

    def _build(self):
        s = self.root
        for sub in ("home", "tmp", "plain", "bin"):
            os.makedirs(self.p(sub), exist_ok=True)
        with open(self.p("home", ".gitconfig"), "w") as fh:
            fh.write("[user]\n\tname = T\n\temail = t@example.invalid\n[init]\n\tdefaultBranch = main\n"
                     "[protocol \"file\"]\n\tallow = always\n"
                     "[url \"%s/origin.git\"]\n\tinsteadOf = https://github.com/acme/app.git\n"
                     "[url \"%s/up.git\"]\n\tinsteadOf = https://github.com/acme/up.git\n" % (s, s))
        seed = self.p("seed")
        os.makedirs(seed)
        self.g(seed, "init", "-q", "-b", "main")
        self._commit(seed, "a.txt", "1")
        self.g(seed, "branch", "feat/x")
        self.g(seed, "branch", "feat/y")
        self.g(seed, "tag", "v1")
        self.g(seed, "tag", "rtag")
        self.g(seed, "branch", "develop")
        for name, head, branches in (("origin.git", "main", ("main", "feat/x", "feat/y")),
                                     ("up.git", "develop", ("develop", "feat/x"))):
            self.g(s, "init", "-q", "--bare", "-b", head, name)
            self.g(seed, "push", "-q", self.p(name), *branches)
        self.g(seed, "push", "-q", self.p("origin.git"), "refs/tags/v1", "refs/tags/rtag")
        shutil.rmtree(seed)
        w = self.p("w")
        self.g(s, "clone", "-q", "https://github.com/acme/app.git", "w")
        self.g(w, "remote", "add", "up", "https://github.com/acme/up.git")
        self.g(w, "fetch", "-q", "up")
        self.g(w, "remote", "set-head", "up", "develop")
        self._commit(w, "main.txt", "main")
        self.g(w, "checkout", "-q", "-b", "develop", "--track", "up/develop")
        self._commit(w, "develop.txt", "develop")
        self.g(w, "checkout", "-q", "-b", "feat/x", "--track", "origin/feat/x")
        self._commit(w, "featx.txt", "feat/x")
        self.g(w, "branch", "feat/y", "origin/feat/y")
        os.makedirs(self.p("w", "sub"), exist_ok=True)
        with open(self.p("w", "sub", "keep"), "w") as fh:
            fh.write("x\n")
        self.g(w, "worktree", "add", "-q", "../wt-main", "main")
        with open(self.p("w", "new.txt"), "w") as fh:
            fh.write("untracked\n")
        os.symlink(self.p("w", "sub"), self.p("lnk"))
        with open(self.p("dirfile"), "w") as fh:
            fh.write(self.p("wt-main") + "\n")
        with open(self.p("cdfile"), "w") as fh:
            fh.write("cd %s\n" % self.p("wt-main"))
        with open(self.p("bin", "git"), "w") as fh:
            fh.write('#!/bin/sh\nexec /usr/bin/env git -C %s "$@"\n' % self.p("wt-main"))
        os.chmod(self.p("bin", "git"), 0o755)

    def _commit(self, cwd, name, text):
        with open(os.path.join(cwd, name), "w") as fh:
            fh.write(text + "\n")
        self.g(cwd, "add", name)
        self.g(cwd, "commit", "-q", "-m", "c " + name)

    def restore(self):
        shutil.rmtree(self.root)
        shutil.copytree(self.pristine, self.root, symlinks=True)

    def refs(self):
        out = {}
        for name in ("origin.git", "up.git"):
            text = self.g(self.p(name), "for-each-ref", "--format=%(refname) %(objectname)").stdout
            out[name] = dict(line.split(" ") for line in text.splitlines() if line)
        return out


def protected_effect(before, after):
    """True when a remote ref other than a non-default branch was created, moved or deleted."""
    for name, old in before.items():
        new = after[name]
        for ref in set(old) | set(new):
            if old.get(ref) == new.get(ref):
                continue
            branch = ref[len("refs/heads/"):] if ref.startswith("refs/heads/") else None
            if branch is None or branch in DEFAULT_BRANCHES:
                return True
    return False
