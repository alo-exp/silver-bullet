"""Proof-based classification of a shell ``git push`` (and, later, an MCP write) as intermediate or final delivery.

Invariant P: a shell push is *feature* (intermediate) only when, from facts this module observed itself (the parsed
command text, and read-only answers from git in a verified directory), it follows that the command runs exactly one
``git push`` from one known directory, contains nothing else that could change those facts before the push runs,
and, under the git configuration in force, updates only ``refs/heads/<B>`` on one named remote where every ``<B>``
is a spelled-out branch name that is not that remote's default branch. Anything not proved is *strict* (final delivery).

The result is ``{"verdict": "feature"|"strict", "reason": str, "dir": str, "remote": str, "branches": [str]}``.
Design: DESIGN-G1-push-classifier.md (S0-S13). Git is asked three questions, all read-only and offline:
G1 ``rev-parse`` (current branch, source refs), G2 ``config -z --list``, G3 ``for-each-ref`` (remote HEAD symrefs).
"""

from __future__ import annotations

import os
import re
import signal
import stat
import subprocess
import time

GIT_DEADLINE_SECONDS = 3.0
GIT_CALL_SECONDS = 2.0

ENV_DENY = ("GIT_DIR", "GIT_WORK_TREE", "GIT_COMMON_DIR", "GIT_NAMESPACE", "GIT_CONFIG", "GIT_CONFIG_GLOBAL",
            "GIT_CONFIG_SYSTEM", "GIT_CONFIG_PARAMETERS", "GIT_CONFIG_COUNT", "GIT_EXEC_PATH", "BASH_ENV", "ENV")
INERT_PROGRAMS = {"echo", "printf", "true", ":", "cat", "head", "tail", "grep", "wc", "sleep", "pwd", "ls", "test", "["}
# Inert git: a subcommand is inert only when EVERY option is on its exact allowlist (no prefix abbreviations: git
# accepts --outp= for --output=, which writes any file). log/show/diff/shortlog are "viewers": they also run
# configured pagers, external diff drivers and textconv filters, so the stored configuration is checked too.
INERT_GIT_ANY = {"rev-parse", "ls-files", "describe"}
VIEW_COMMON = {"--oneline", "--stat", "--shortstat", "--numstat", "--name-only", "--name-status", "--no-color",
               "--color", "-p", "--patch", "-s", "--no-patch", "--graph", "--decorate", "--no-decorate",
               "--abbrev-commit", "--cached", "--staged", "--all", "--branches", "--tags", "--reverse", "--merges",
               "--no-merges", "--first-parent", "--summary", "--date-order", "-q", "--quiet", "--exit-code",
               "--compact-summary", "--numbered", "--email", "-n", "-e", "--"}
VIEW_PREFIXES = ("--format=", "--pretty=", "--max-count=", "--since=", "--until=", "--author=", "--grep=",
                 "--date=", "--abbrev=")
STATUS_FLAGS = {"-s", "--short", "-b", "--branch", "--porcelain", "--long", "-v", "--verbose", "-z", "--show-stash",
                "-uno", "-unormal", "-uall", "--"}
ADD_FLAGS = {"-A", "--all", "-u", "--update", "-v", "--verbose", "-f", "--force", "-N", "--intent-to-add", "--dry-run",
             "--"}
COMMIT_FLAGS = {"-a", "--all", "-q", "--quiet", "-v", "--verbose", "-s", "--signoff", "--no-verify", "-n",
                "--allow-empty", "--amend", "--no-edit", "--no-gpg-sign", "--allow-empty-message", "--"}
COMMIT_VALUE = {"-m", "--message", "-F", "--file"}
VIEW_CLUSTER = re.compile(r"^-[sneq]+$")
STATUS_CLUSTER = re.compile(r"^-[sbvz]+$")
COMMIT_CLUSTER = re.compile(r"^-[aqvsn]*m$")
COMMIT_BOOL_CLUSTER = re.compile(r"^-[aqvsn]+$")
SYMBOLIC_REF_FORMS = (["HEAD"], ["--short", "HEAD"], ["-q", "HEAD"], ["-q", "--short", "HEAD"], ["--short", "-q", "HEAD"])
CONFIG_FORMS = ("--get", "--get-all", "--get-regexp")
VIEWERS = {"log", "show", "diff", "shortlog"}
VIEWER_CONFIG = re.compile(r"^(core\.pager|pager\..*|diff\.external|diff\..*\.(command|textconv)|"
                           r"core\.fsmonitor|core\.sshcommand|core\.askpass)$")
BRANCH_LIST_FLAGS = {"--show-current", "--list", "-l", "-a", "--all", "-r", "--remotes", "-v", "-vv"}
GIT_GLOBALS_OK = {"--no-pager", "-P"}
PUSH_BOOL = {"-u", "--set-upstream", "-f", "--force", "-q", "--quiet", "-v", "--verbose", "--progress", "--no-verify",
             "--verify", "--atomic", "--no-atomic", "--porcelain", "--thin", "--no-thin", "-4", "--ipv4", "-6",
             "--ipv6", "--force-if-includes", "--no-force-if-includes", "--no-recurse-submodules"}
PUSH_CLUSTER_LETTERS = set("ufqv46")
NEWBRANCH_FLAGS = {"--quiet", "-q", "--track", "-t", "--no-track"}
REMOTE_KEYS_OK = {"url", "fetch", "tagopt", "prune", "prunetags", "promisor", "partialclonefilter",
                  "skipdefaultupdate", "skipfetchall", "followremotehead"}
PUSH_KEYS_OK = {"autosetupremote", "usebitmaps", "negotiate", "useforceifincludes", "gpgsign"}
FALSE_VALUES = {"false", "no", "off", "0"}
ALLOWED_WRITES = {"/dev/null", "/dev/stdout", "/dev/stderr", "/dev/tty"}
BAD_REF_CHARS = re.compile(r"[~^:*?\[\\\s]|@\{")
BRANCH_RE = re.compile(r"^[A-Za-z0-9._+/-]+$")
REMOTE_RE = re.compile(r"^[A-Za-z0-9._-]+$")
RESERVED_FIRST = {"heads", "tags", "remotes", "refs"}
SET_HEAD_REMEDY = "run `git remote set-head %s --auto` once (needs network) so Silver Bullet can see the remote's default branch"


class Strict(Exception):
    """The push is not proved to be a feature-branch push; the message is the one-sentence reason."""


def strict(reason, **extra):
    out = {"verdict": "strict", "reason": reason, "dir": "", "remote": "", "branches": []}
    out.update(extra)
    return out


# --------------------------------------------------------------------------- git (read-only, offline)
class Git:
    """Runs the three allowed read-only git calls under one shared deadline."""

    def __init__(self, environ, runner=None):
        self.env = dict(environ)
        self.env.update(GIT_TERMINAL_PROMPT="0", GIT_OPTIONAL_LOCKS="0", LC_ALL="C", GIT_PAGER="cat")
        self.deadline = time.monotonic() + GIT_DEADLINE_SECONDS
        self.runner = runner or self._run

    def _run(self, args, timeout):
        proc = subprocess.Popen(["git"] + args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=self.env,
                                start_new_session=True)
        try:
            out, err = proc.communicate(timeout=timeout)
        except subprocess.TimeoutExpired:
            # kill git and everything it started: a child that keeps the pipes open would otherwise hold the hook
            os.killpg(proc.pid, signal.SIGKILL)
            proc.communicate()
            raise
        return proc.returncode, out, err

    def call(self, directory, args):
        left = self.deadline - time.monotonic()
        if left <= 0:
            raise Strict("git did not answer in time")
        try:
            rc, out, err = self.runner(["-C", directory] + args, min(GIT_CALL_SECONDS, left))
        except (OSError, subprocess.SubprocessError):
            raise Strict("git did not answer") from None
        return rc, out.decode("utf-8", "replace"), err.decode("utf-8", "replace")


def parse_config_z(text):
    """``git config -z --list`` -> {key: [values]} (keys as git prints them: section and name lowercase)."""
    cfg = {}
    for entry in text.split("\0"):
        if not entry:
            continue
        key, sep, value = entry.partition("\n")
        cfg.setdefault(key, []).append(value if sep else "true")
    return cfg


def cfg_get(cfg, key):
    values = cfg.get(key)
    return values[-1] if values else None


def read_facts(git, directory, srcs):
    """G1 and G2: (git_dir, bare, head_full, {src: full}, cfg)."""
    rc, out, err = git.call(directory, ["rev-parse", "--absolute-git-dir", "--is-bare-repository",
                                        "--symbolic-full-name", "HEAD"] + srcs)
    if rc != 0:
        raise Strict("the repository facts could not be read (is %s a git work tree?)" % directory)
    if err.strip():
        raise Strict("git warned while reading the repository facts: %s" % err.strip().split("\n")[0])
    lines = out.split("\n")
    if len(lines) < 3 + len(srcs):
        raise Strict("git answered with an unexpected shape")
    if lines[1] != "false":
        raise Strict("the push runs in a bare repository")
    resolved = dict(zip(srcs, lines[3:3 + len(srcs)]))
    rc, out, err = git.call(directory, ["config", "-z", "--list"])
    if rc != 0:
        raise Strict("the git configuration could not be read")
    return lines[2], resolved, parse_config_z(out)


def remote_head_symrefs(git, directory, remote, candidates):
    """G3: {refname: symref} for refs/remotes/<remote>/HEAD, refs/remotes/origin/HEAD and the NEW-name candidates."""
    patterns = ["refs/remotes/%s/HEAD" % remote, "refs/remotes/origin/HEAD"] + candidates
    rc, out, _err = git.call(directory, ["for-each-ref", "--format=%(refname)%00%(symref)"] + patterns)
    if rc != 0:
        raise Strict("the remote branches could not be read")
    refs = {}
    for line in out.split("\n"):
        if line:
            name, _sep, target = line.partition("\0")
            refs[name] = target
    return refs


# --------------------------------------------------------------------------- command grammar
def literals(words):
    """The literal values of a word list, or None when any word is not plain text."""
    out = []
    for word in words:
        value = word.literal()
        if value is None:
            return None
        out.append(value)
    return out


def split_git_globals(argv):
    """argv (starting with ``git``) -> (dirs, rest) with -C/--no-pager/-P consumed, or None for any other global."""
    dirs, i = [], 1
    while i < len(argv):
        word = argv[i]
        if word == "-C":
            if i + 1 >= len(argv):
                return None
            dirs.append(argv[i + 1])
            i += 2
        elif word in GIT_GLOBALS_OK:
            i += 1
        elif word.startswith("-"):
            return None
        else:
            break
    return dirs, argv[i:]


def parse_push_args(args):
    """The words after ``push`` -> (remote|None, [refspec], force) or a Strict for anything not understood."""
    positionals, force, i = [], False, 0
    while i < len(args):
        word = args[i]
        if word == "--":
            positionals += args[i + 1:]
            break
        if word.startswith("--"):
            name, eq, value = word.partition("=")
            if name == "--force-with-lease":
                force = True
            elif name == "--recurse-submodules" and eq and value in ("check", "no"):
                pass
            elif word in PUSH_BOOL:
                force = force or word in ("-f", "--force")
            else:
                raise Strict("the push option %s is not a plain feature-branch push" % name)
        elif word.startswith("-") and len(word) > 1:
            letters = word[1:]
            if not set(letters) <= PUSH_CLUSTER_LETTERS:
                raise Strict("the push option %s is not a plain feature-branch push" % word)
            force = force or "f" in letters
        else:
            positionals.append(word)
        i += 1
    remote = positionals[0] if positionals else None
    refspecs = positionals[1:]
    force = force or any(spec.startswith("+") for spec in refspecs)
    return remote, refspecs, force


def parse_new_branch(args, create_flags):
    """The words after ``checkout``/``switch`` -> (NEW, START|None) for the plain create forms, else None."""
    new, start, i = None, None, 0
    while i < len(args):
        word = args[i]
        if word in create_flags and new is None:
            if i + 1 >= len(args):
                return None
            new = args[i + 1]
            i += 2
        elif word in NEWBRANCH_FLAGS:
            i += 1
        elif word.startswith("-") or new is None or start is not None:
            return None
        else:
            start = word
            i += 1
    if new is None or new.startswith("-"):
        return None
    return new, start


def options_ok(args, flags, prefixes=(), values=(), clusters=(), value_clusters=()):
    """Every option is one of ``flags`` (exact), ``prefixes`` (--name=value), takes a value (``values``), or matches a
    cluster regex; ``--`` ends the options. Anything else, including a prefix abbreviation, is not allowed."""
    i = 0
    while i < len(args):
        word = args[i]
        if word == "--":
            return True
        if word.startswith("-") and len(word) > 1:
            if word in values or any(c.match(word) for c in value_clusters):
                i += 1
                if i >= len(args):
                    return False
            elif not (word in flags or re.fullmatch(r"-\d+", word) or
                      any(word.startswith(p) and len(word) > len(p) for p in prefixes) or
                      any(c.match(word) for c in clusters)):
                return False
        i += 1
    return True


def inert_git(sub, args):
    """None when ``git <sub> <args>`` is not provably free of side effects on the push's facts, else True for a
    viewer (log/show/diff/shortlog: the stored pager/diff-driver settings must be checked) or False."""
    if sub in VIEWERS:
        return True if options_ok(args, VIEW_COMMON, VIEW_PREFIXES, clusters=(VIEW_CLUSTER,)) else None
    if sub in INERT_GIT_ANY:
        return False
    if sub == "status":
        ok = options_ok(args, STATUS_FLAGS, clusters=(STATUS_CLUSTER,))
    elif sub in ("add", "stage"):
        ok = options_ok(args, ADD_FLAGS)
    elif sub == "commit":
        ok = options_ok(args, COMMIT_FLAGS, ("--message=", "--file=", "-m"), COMMIT_VALUE, (COMMIT_BOOL_CLUSTER,),
                        (COMMIT_CLUSTER,))
    elif sub == "branch":
        ok = all(a in BRANCH_LIST_FLAGS for a in args)
    elif sub == "remote":
        ok = args in ([], ["-v"]) or (len(args) == 2 and args[0] == "get-url" and not args[1].startswith("-"))
    elif sub == "symbolic-ref":
        ok = args in SYMBOLIC_REF_FORMS
    elif sub == "config":
        ok = args == ["--list"] or args == ["-l"] or (len(args) == 2 and args[0] in CONFIG_FORMS
                                                       and not args[1].startswith("-"))
    else:
        ok = False
    return False if ok else None


def classify_argv(argv):
    """argv -> ("push", dirs, args) | ("cd", arg) | ("newbranch", dirs, new, start) | ("inert", viewer) | ("other", name)."""
    if not argv:
        return ("other", "")
    prog = argv[0]
    if prog == "cd":
        if len(argv) == 2 and argv[1] != "-" and not argv[1].startswith(("~", "-")):
            return ("cd", argv[1])
        return ("other", "cd")
    if prog == "git":
        split = split_git_globals(argv)
        if split is None or not split[1]:
            return ("other", "git")
        dirs, rest = split
        sub, args = rest[0], rest[1:]
        if sub == "push":
            return ("push", dirs, args)
        if sub in ("checkout", "switch"):
            parsed = parse_new_branch(args, ("-b",) if sub == "checkout" else ("-c", "--create"))
            if parsed is not None:
                return ("newbranch", dirs, parsed[0], parsed[1])
            return ("other", "git " + sub)
        verdict = inert_git(sub, args)
        if verdict is not None:
            return ("inert", verdict)
        return ("other", "git " + sub)
    if prog in INERT_PROGRAMS and not (prog == "printf" and "-v" in argv[1:]):
        return ("inert", False)
    return ("other", prog)


# --------------------------------------------------------------------------- shape of the script (S2-S4)
SAFE_ASSIGNS = {"RTK_DISABLED": "1", "NO_COLOR": "1", "CI": "1", "GIT_TERMINAL_PROMPT": "0"}
LOCALE_VALUE = re.compile(r"^[A-Za-z0-9_.@-]+$")


def harmless_assignment(assign):
    """A plain ``NAME=literal`` from the fixed allowlist (tool switches and locale), nothing git reads for a push."""
    if assign.append or assign.array or len(assign.value) != 1:
        return False
    value = assign.value[0].literal()
    if value is None:
        return False
    if assign.name in ("LANG", "LC_ALL"):
        return bool(LOCALE_VALUE.match(value))
    return SAFE_ASSIGNS.get(assign.name) == value


def top_level(script):
    """The top-level simple commands as (and_or_index, position, node) after checking the shape (S2)."""
    nodes = []
    for index, (andor, background) in enumerate(script.items):
        if background:
            raise Strict("a background job in the same command as the push")
        for pipeline in andor:
            for node in pipeline:
                if type(node).__name__ != "Simple":
                    raise Strict("the push is inside a compound command, function, loop or subshell")
                for assign in node.assigns:
                    if not harmless_assignment(assign):
                        raise Strict("a variable assignment in the same command as the push")
        nodes.append((index, andor))
    return nodes


def node_words(node):
    return literals(node.words)


def check_state_steps(script, kinds):
    """S4: a cd/checkout -b step must precede the push in an unbroken && chain."""
    for andor, _background in script.items:
        steps, push_at = [], None
        for pos, pipeline in enumerate(andor):
            for node in pipeline:
                words = node_words(node)
                kind = classify_argv(words)[0] if words else "other"
                if kind == "push":
                    push_at = pos
                if kind in ("cd", "newbranch"):
                    steps.append((pos, len(pipeline), pipeline.negated, kind))
        if not steps:
            continue
        if push_at is None:
            raise Strict("a `cd`/`checkout -b` is not in the same chain as the push")
        order = [kind for _p, _l, _n, kind in steps]
        if len(steps) > 2 or len(order) != len(set(order)) or (len(order) == 2 and order != ["cd", "newbranch"]):
            raise Strict("more than one `cd`/`checkout -b` before the push")
        for pos, length, negated, _kind in steps:
            if pos > push_at or length != 1 or negated:
                raise Strict("a `cd`/`checkout -b` before the push is not chained with `&&`")
        if any(op != "&&" for op in andor.ops[:push_at]):
            raise Strict("a `cd`/`checkout -b` before the push is not chained with `&&`")
        for pos in range(push_at + 1):
            if andor[pos].negated:
                raise Strict("a negated command before the push")


def branch_name_ok(name, default_names):
    if not BRANCH_RE.match(name) or ".." in name or "//" in name or name.startswith(("-", "/")) \
            or name.endswith((".lock", "/")) or BAD_REF_CHARS.search(name):
        return False
    return name.split("/")[0] not in RESERVED_FIRST and name.casefold() not in default_names


def default_names(cfg, refs, remote):
    names = {"main", "master"}
    configured = cfg_get(cfg, "init.defaultbranch")
    if configured:
        names.add(configured.casefold())
    for ref in ("refs/remotes/%s/HEAD" % remote, "refs/remotes/origin/HEAD"):
        target = refs.get(ref, "")
        for owner in (remote, "origin"):
            prefix = "refs/remotes/%s/" % owner
            if target.startswith(prefix):
                names.add(target[len(prefix):].casefold())
    return names


def remote_variable(key):
    """('remote.<name>.<var>') -> (name, var) or None."""
    if not key.startswith("remote.") or key.count(".") < 2:
        return None
    name, _dot, var = key[len("remote."):].rpartition(".")
    return name, var


def check_config(cfg, remote):
    """S10: per-namespace allowlists for the keys that steer a push."""
    for key, values in cfg.items():
        parts = remote_variable(key)
        if parts is not None and parts[0] == remote:
            var = parts[1]
            if var == "mirror":
                if any(v.lower() not in FALSE_VALUES for v in values):
                    raise Strict("remote %s is a mirror" % remote)
            elif var not in REMOTE_KEYS_OK:
                raise Strict("remote.%s.%s changes what a push sends" % (remote, var))
        elif key.startswith("push."):
            name = key[len("push."):]
            value = values[-1].lower()
            if name == "default":
                if value not in ("simple", "current"):
                    raise Strict("push.default=%s pushes more than the named branch" % value)
            elif name == "followtags":
                if value not in FALSE_VALUES:
                    raise Strict("push.followTags pushes tags")
            elif name not in PUSH_KEYS_OK:
                raise Strict("%s changes what a push sends" % key)
        elif key.startswith("url.") and key.endswith(".pushinsteadof"):
            raise Strict("a url.*.pushInsteadOf rewrite changes where a push goes")


def bare_remote(cfg, current):
    for key in ("branch.%s.pushremote" % current, "remote.pushdefault", "branch.%s.remote" % current):
        value = cfg_get(cfg, key)
        if value:
            return value
    return "origin"


def resolve_branch(src, head, new, resolved):
    """The refs/heads/<B> a colon-less name or src stands for, or a Strict."""
    if src in ("HEAD", "@"):
        full = head
    elif new is not None and src in (new, "refs/heads/" + new):
        full = "refs/heads/" + new
    else:
        full = resolved.get(src, "")
        if full != "refs/heads/" + src.removeprefix("refs/heads/"):
            raise Strict("%s does not resolve to a local branch of that exact name" % src)
    if not full.startswith("refs/heads/"):
        raise Strict("%s is not a branch (HEAD is detached or a tag)" % src)
    return full[len("refs/heads/"):]


def plan_destinations(refspecs, new):
    """-> ([(kind, src, dst)], srcs_to_resolve). kind: 'bare' | 'name' | 'pair'."""
    plan, srcs = [], []
    if not refspecs:
        plan.append(("bare", "", ""))
    for spec in refspecs:
        spec = spec.removeprefix("+")
        if "*" in spec:
            raise Strict("a glob refspec")
        src, colon, dst = spec.partition(":")
        if not src or (colon and not dst):
            raise Strict("a deletion or empty refspec")
        if src.startswith("-") or BAD_REF_CHARS.search(src) or (colon and BAD_REF_CHARS.search(dst)):
            raise Strict("the refspec %s is not a plain branch name" % spec)
        plan.append(("pair" if colon else "name", src, dst))
        qualified = colon and dst.startswith("refs/")
        if src not in ("HEAD", "@", new, "refs/heads/%s" % new) and not qualified:
            srcs.append(src)
    return plan, srcs


def destination_branches(plan, force, head, new, resolved, names):
    branches = []
    for kind, src, dst in plan:
        if kind == "bare":
            name = resolve_branch("HEAD", head, new, resolved)
        elif kind == "name":
            name = resolve_branch(src, head, new, resolved)
        elif dst.startswith("refs/heads/"):
            name = dst[len("refs/heads/"):]
        elif dst.startswith("refs/"):
            raise Strict("the destination %s is not a branch" % dst)
        else:
            if force:
                raise Strict("a forced push to an unqualified destination can move a remote tag")
            if dst.split("/")[0] in RESERVED_FIRST or dst in ("HEAD", "@"):
                raise Strict("the destination %s is ambiguous" % dst)
            resolve_branch(src, head, new, resolved)
            name = dst
        if not branch_name_ok(name, names):
            raise Strict("%s is a default branch or not a plain branch name" % name)
        branches.append(name)
    return branches


# --------------------------------------------------------------------------- the algorithm
def effective_dir(base, step_cd, dirs, logical_base=None):
    directory = base
    if step_cd is not None:
        target = os.path.join(directory, step_cd)
        if ".." in step_cd.split("/") and (os.path.realpath(logical_base or base) != os.path.abspath(logical_base or base)
                                            or os.path.realpath(target) != os.path.normpath(target)):
            # bash's cd is logical: `..` after a symlink goes to the symlink's parent, not the target's
            raise Strict("a `cd` with `..` through a symbolic link is ambiguous")
        directory = os.path.realpath(target)
    for entry in dirs:
        directory = os.path.realpath(os.path.join(directory, entry))
    if not os.path.isdir(directory):
        raise Strict("the directory %s does not exist" % directory)
    return directory


def check_entries(result, wrapper=None):
    """S5: every command in the analysis is the push, a state step, or inert. Returns the three kinds' entries, and
    whether a viewer (log/show/diff/shortlog) is among them (``found["viewer"]``). ``wrapper`` is the argv of an
    unwrapped `bash -c '<script>'`, which is not itself a command of the script."""
    found = {"push": [], "cd": [], "newbranch": [], "viewer": False}
    for entry in result.get("commands") or []:
        argv = entry.get("argv") or []
        if wrapper is not None and argv == wrapper:
            wrapper = None
            continue
        kind = classify_argv(argv)
        if kind[0] in ("push", "cd", "newbranch"):
            found[kind[0]].append((entry, kind))
        elif kind[0] == "inert":
            found["viewer"] = found["viewer"] or kind[1]
        else:
            raise Strict("the command also runs %s, which can change what the push does" % (kind[1] or "an unknown program"))
    return found


def unwrap_shell(script, parse):
    """A script that is exactly `bash|sh -c|-lc '<literal script>'` (the Codex shape) -> (inner script, wrapper argv)."""
    if parse is None or len(script.items) != 1 or script.items[0][1] or len(script.items[0][0]) != 1:
        return script, None
    pipeline = script.items[0][0][0]
    node = pipeline[0] if len(pipeline) == 1 and not pipeline.negated else None
    if type(node).__name__ != "Simple" or node.assigns or node.redirs:
        return script, None
    words = node_words(node)
    if words is None or len(words) != 3 or words[0] not in ("bash", "sh") or words[1] not in ("-c", "-lc"):
        return script, None
    return parse(words[2]), words


HOOK_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
COVERAGE_BASH_ENV = os.path.join(HOOK_ROOT, "tests", "coverage", "bash-env.sh")


def is_coverage_tracer(value, environ):
    """BASH_ENV is exactly this checkout's coverage tracer (run-coverage.sh): absolute, not a symlink, the file the
    hook's own root names, a regular file owned by this user that nobody else can write, with SB_COV_DIR set to a
    directory. Anything else is an arbitrary startup file."""
    cov_dir = environ.get("SB_COV_DIR")
    if not (os.path.isabs(value) and cov_dir and os.path.isdir(cov_dir)) or os.path.islink(value):
        return False
    if os.path.realpath(value) != os.path.realpath(COVERAGE_BASH_ENV):
        return False
    try:
        info = os.stat(value)
    except OSError:
        return False
    return stat.S_ISREG(info.st_mode) and info.st_uid == os.geteuid() and not info.st_mode & 0o022


def env_check(environ):
    """S1: variables that redirect git or run code in every bash (the repository's own coverage tracer excepted)."""
    for name in ENV_DENY:
        value = environ.get(name)
        if name == "BASH_ENV" and value and is_coverage_tracer(value, environ):
            continue
        if value:
            raise Strict("%s is set in the environment and redirects git" % name)


def shell_scope(script, result, base, environ, git=None, parse=None, logical_base=None):
    """Classify the shell push of an analysis. ``base`` is the verified payload directory (or None); ``parse`` parses
    the script of an unwrapped `bash -lc`; ``logical_base`` is the payload cwd as the host spelled it."""
    try:
        return _shell_scope(script, result, base, environ, git, parse, logical_base)
    except Strict as exc:
        return strict(str(exc))


def _shell_scope(script, result, base, environ, git, parse, logical_base):
    # S0 preconditions
    if not base or not os.path.isdir(base):
        raise Strict("the working directory of the command is unknown")
    if result.get("status") != "ok" or script.error or result.get("opaque") or result.get("possible_actions") \
            or result.get("unseen_reasons"):
        raise Strict("the command contains code Silver Bullet cannot read")
    pushes = len(result.get("push") or [])
    if pushes > 1:
        raise Strict("more than one push in one command")
    if pushes == 0:
        raise Strict("the push is not a plain top-level `git push`")
    # S1 environment redirecting git
    env_check(environ)
    if any(name.startswith("BASH_FUNC_") for name in environ):
        raise Strict("an exported shell function is in the environment")
    # S2/S3/S4 shape (a single `bash -lc '<script>'` is judged by its script)
    script, wrapper = unwrap_shell(script, parse)  # a script that does not parse is unseen code (S0)
    top_level(script)
    top_kinds = []
    for andor, _background in script.items:
        for pipeline in andor:
            for node in pipeline:
                words = node_words(node)
                top_kinds.append(classify_argv(words) if words else ("other", ""))
    if sum(1 for k in top_kinds if k[0] == "push") != 1:
        raise Strict("the push is not a plain top-level `git push`")
    check_state_steps(script, top_kinds)
    # S5 whole-command inertness, counts equal to the top-level counts
    found = check_entries(result, wrapper)
    for kind in ("push", "cd", "newbranch"):
        if len(found[kind]) != sum(1 for k in top_kinds if k[0] == kind):
            raise Strict("a `%s` that is not a plain literal step of the script (hidden in a substitution or wrapper, "
                         "or its argument is a variable, `~` or substitution)" % kind)
    # S6 writes
    for write in result.get("writes") or []:
        if write.get("path") not in ALLOWED_WRITES:
            raise Strict("the command writes %s" % write.get("path"))
    cd_arg = found["cd"][0][1][1] if found["cd"] else None
    new_entry = found["newbranch"][0][1] if found["newbranch"] else None
    push_entry, push_kind = found["push"][0]
    # S7 directory
    if cd_arg is not None and not os.path.isabs(cd_arg) and environ.get("CDPATH"):
        raise Strict("CDPATH is set, so a relative `cd` is ambiguous")
    directory = effective_dir(base, cd_arg, push_kind[1], logical_base)
    if new_entry is not None and effective_dir(base, cd_arg, new_entry[1], logical_base) != directory:
        raise Strict("the new branch is created in another directory than the push")
    if not push_kind[1] and result.get("base_dir") == base:
        analysed = push_entry.get("cwd")
        if not analysed or os.path.realpath(analysed) != directory:
            raise Strict("the directory of the push could not be confirmed")
    # S8 push arguments
    remote_arg, refspecs, force = parse_push_args(push_kind[2])
    new = new_entry[2] if new_entry else None
    start = new_entry[3] if new_entry else None
    git = git or Git(environ)
    plan, srcs = plan_destinations(refspecs, new)
    # S9 facts
    head0, resolved, cfg = read_facts(git, directory, srcs)
    head = "refs/heads/" + new if new else head0
    if new and any(key.startswith("includeif.onbranch:") for key in cfg):
        raise Strict("the git configuration depends on the branch that is about to be created")
    if found["viewer"] and any(VIEWER_CONFIG.match(key) for key in cfg):
        raise Strict("git log/show/diff would run a configured pager, diff driver or filter")
    # S10 remote
    if remote_arg is None:
        if new and start:
            raise Strict("a bare push after `checkout -b NEW START` may use another remote")
        if not head.startswith("refs/heads/"):
            raise Strict("HEAD is detached")
        remote = bare_remote(cfg, head[len("refs/heads/"):])
    else:
        remote = remote_arg
    if not REMOTE_RE.match(remote) or remote in (".", ".."):
        raise Strict("pushes to a URL or path remote have no known default branch")
    if len(cfg.get("remote.%s.url" % remote, [])) != 1:
        raise Strict("pushes to a URL or path remote have no known default branch")
    check_config(cfg, remote)
    # S11 default branches
    candidates = ["refs/%s" % new, "refs/tags/%s" % new, "refs/heads/%s" % new, "refs/remotes/%s" % new] \
        if new else []
    refs = remote_head_symrefs(git, directory, remote, candidates)
    if any(name == cand or name.startswith(cand + "/") for name in refs for cand in candidates):
        raise Strict("the new branch name %s already exists as another ref" % new)
    if "refs/remotes/%s/HEAD" % remote not in refs:
        raise Strict("the default branch of remote %s is not known locally: %s" % (remote, SET_HEAD_REMEDY % remote))
    names = default_names(cfg, refs, remote)
    # S12 destinations
    branches = destination_branches(plan, force, head, new, resolved, names)
    return {"verdict": "feature", "reason": "", "dir": directory, "remote": remote, "branches": branches}


# --------------------------------------------------------------------------- MCP writes (Invariant M)
MCP_PUSH_TOOLS = {"push_files", "create_or_update_file", "delete_file", "create_commit", "create_branch"}
OWNER_REPO_RE = re.compile(r"^[A-Za-z0-9._-]+$")
GITHUB_URL_RE = re.compile(r"^(?:https://(?:[^@/]+@)?github\.com/|git@github\.com:|ssh://git@github\.com(?::\d+)?/|"
                           r"git://github\.com/)([A-Za-z0-9._-]+)/([A-Za-z0-9._-]+?)(?:\.git)?/?$")


def github_slug(url):
    """The ``owner/repo`` a github.com remote URL names (https, scp-like ssh, ssh://, git://), else None."""
    match = GITHUB_URL_RE.match(url)
    return None if match is None else "%s/%s" % (match.group(1), match.group(2))


def origin_slug(base, environ, git=None):
    """``owner/repo`` of ``remote.origin.url`` in the checkout at ``base`` (None when unknown); one config read."""
    if not base or not os.path.isdir(base):
        return None
    git = git or Git(environ)
    try:
        rc, out, _err = git.call(base, ["config", "-z", "--list"])
    except Strict:
        return None
    urls = parse_config_z(out).get("remote.origin.url") if rc == 0 else None
    return github_slug(urls[-1]) if urls else None


def mcp_scope(tool, fields, base, environ, git=None):
    """Classify an MCP write: ``feature`` only for a non-default branch of a GitHub repository this checkout has a
    remote for, whose default branch this checkout knows (``refs/remotes/<remote>/HEAD``)."""
    try:
        return _mcp_scope(tool, fields, base, environ, git)
    except Strict as exc:
        return strict(str(exc))


def _mcp_scope(tool, fields, base, environ, git):
    if tool not in MCP_PUSH_TOOLS:
        raise Strict("the MCP tool %s writes refs that Silver Bullet cannot scope" % tool)
    owner, repo, branch = fields.get("owner"), fields.get("repo"), fields.get("branch")
    if not (isinstance(owner, str) and isinstance(repo, str) and OWNER_REPO_RE.match(owner)
            and OWNER_REPO_RE.match(repo) and not repo.endswith(".git")):
        raise Strict("the MCP call does not name its repository as plain owner and repo strings")
    if not isinstance(branch, str) or not branch:
        raise Strict("the MCP call names no branch, so it targets the repository's default branch")
    if not base or not os.path.isdir(base):
        raise Strict("the working directory of the call is unknown")
    env_check(environ)
    git = git or Git(environ)
    _head, _resolved, cfg = read_facts(git, base, [])
    wanted = ("%s/%s" % (owner, repo)).lower()
    matching = []
    for key, values in cfg.items():
        parts = remote_variable(key)
        if parts is not None and parts[1] == "url" and any((github_slug(v) or "").lower() == wanted for v in values):
            matching.append(parts[0])
    if not matching:
        raise Strict("the target repository %s/%s is not a remote of this checkout, so its default branch is "
                     "unknown" % (owner, repo))
    names = {"main", "master"}
    for remote in sorted(matching):
        refs = remote_head_symrefs(git, base, remote, [])
        if "refs/remotes/%s/HEAD" % remote not in refs:
            raise Strict("the default branch of remote %s is not known locally: %s" % (remote, SET_HEAD_REMEDY % remote))
        names |= default_names(cfg, refs, remote)
    name = branch.removeprefix("refs/heads/")
    if name in ("HEAD", "@") or not branch_name_ok(name, names):
        raise Strict("%s is a default branch or not a plain branch name" % branch)
    return {"verdict": "feature", "reason": "", "dir": base, "remote": sorted(matching)[0], "branches": [name]}
