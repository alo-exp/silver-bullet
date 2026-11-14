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

import hashlib
import json
import os
import re
import signal
import stat
import subprocess
import sys
import time

GIT_DEADLINE_SECONDS = 3.0
GIT_CALL_SECONDS = 2.0

ENV_DENY = ("GIT_DIR", "GIT_WORK_TREE", "GIT_COMMON_DIR", "GIT_NAMESPACE", "GIT_CONFIG", "GIT_CONFIG_GLOBAL",
            "GIT_CONFIG_SYSTEM", "GIT_CONFIG_PARAMETERS", "GIT_EXEC_PATH", "BASH_ENV", "ENV",
            # programs git starts, or repositories it uses instead of the one the proof read
            "GIT_EXTERNAL_DIFF", "GIT_SSH", "GIT_PROXY_COMMAND", "GIT_ASKPASS", "SSH_ASKPASS", "GIT_INDEX_FILE",
            "GIT_OBJECT_DIRECTORY", "GIT_ALTERNATE_OBJECT_DIRECTORIES")
# environment variables that are judged by value (see env_check): GIT_SSH_COMMAND, GIT_PAGER, GIT_EDITOR, VISUAL,
# EDITOR (check_program_config) and PATH (absolute entries only)
ENV_BY_VALUE = ("GIT_SSH_COMMAND", "GIT_PAGER", "GIT_EDITOR", "VISUAL", "EDITOR", "PATH", "GIT_CONFIG_COUNT")
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
RUN_CONFIG = re.compile(r"^(core\.fsmonitor|core\.hookspath|filter\..*\.(clean|smudge|process)|"
                        r"lfs\.extension\..*|lfs\.customtransfer\..*|lfs\.standalonetransferagent)$")
SIGN_CONFIG = re.compile(r"^(gpg\.(.*\.)?program|gpg\.ssh\.defaultkeycommand)$")
EDITOR_CONFIG = re.compile(r"^core\.editor$")
PUSH_RUN_CONFIG = re.compile(r"^(core\.(sshcommand|gitproxy|askpass|alternaterefscommand)|uploadpack\.packobjectshook|"
                             r"credential\.helper|credential\..+\.helper|protocol\.ext\.allow)$")
URL_CONFIG = re.compile(r"^(url\..+\.insteadof|remote\..+\.url)$")
BOOL_WORDS = {"true", "false", "yes", "no", "on", "off", "0", "1", ""}
BENIGN_PAGERS = {"cat", "", "true", ":"}
SSH_PROGRAMS = {"ssh", "/usr/bin/ssh", "/usr/local/bin/ssh", "/bin/ssh"}
SSH_VALUE_FLAGS = {"-i", "-p", "-l"}  # not -F: a config file can hold ProxyCommand/LocalCommand
SSH_BOOL_FLAGS = {"-q", "-v", "-T", "-4", "-6", "-A", "-a", "-x", "-C", "-y"}
# ssh_config keywords that name a program, load more configuration or reroute the connection through one
SSH_PROGRAM_OPTIONS = {"proxycommand", "localcommand", "knownhostscommand", "remotecommand", "xauthlocation",
                       "pkcs11provider", "securitykeyprovider", "include", "match", "permitlocalcommand", "proxyjump"}
SSH_VALUE = re.compile(r"^[A-Za-z0-9_./:@~,+=%-]+$")
STOCK_HELPERS = {"store", "cache", "osxkeychain", "manager", "manager-core", "libsecret", "wincred", "netrc"}
STOCK_HELPER_ARGS = re.compile(r"^(\s+(--[a-z-]+(=[A-Za-z0-9_./~-]+)?|[A-Za-z0-9_./~-]+))*$")
GH_HELPER = re.compile(r"^!(/usr/bin/|/usr/local/bin/|/opt/homebrew/bin/|/bin/)?gh auth git-credential$")
CREDENTIAL_EXEC_DIRS = {"/usr/lib/git-core", "/usr/libexec/git-core", "/usr/local/libexec/git-core"}
SAFE_SCHEMES = {"https", "http", "ssh", "git", "file", "git+ssh", "ssh+git"}
LFS_STOCK = {"filter.lfs.clean": ("git-lfs clean -- %f", "git-lfs clean --skip -- %f"),
             "filter.lfs.smudge": ("git-lfs smudge -- %f", "git-lfs smudge --skip -- %f"),
             "filter.lfs.process": ("git-lfs filter-process", "git-lfs filter-process --skip")}
BENIGN_EDITORS = {"true", ":", "cat", "/bin/true", "/usr/bin/true", "/usr/bin/env true"}
VIEW_CONFIG = re.compile(r"^(core\.pager|pager\..*|diff\.external|diff\..*\.(command|textconv))$")
DIFF_CONFIG = re.compile(r"^(diff\.external|diff\..*\.(command|textconv))$")
PAGER_CONFIG = re.compile(r"^(core\.pager|pager\..*)$")
GC_CONFIG = re.compile(r"^gc\.recentobjectshook$")  # auto gc runs after a commit
BRANCH_LIST_FLAGS = {"--show-current", "--list", "-l", "-a", "--all", "-r", "--remotes", "-v", "-vv"}
GIT_GLOBALS_OK = {"--no-pager", "-P"}
PUSH_BOOL = {"-u", "--set-upstream", "-f", "--force", "-q", "--quiet", "-v", "--verbose", "--progress", "--no-verify",
             "--verify", "--atomic", "--no-atomic", "--porcelain", "--thin", "--no-thin", "-4", "--ipv4", "-6",
             "--ipv6", "--force-if-includes", "--no-force-if-includes", "--no-recurse-submodules"}
PUSH_CLUSTER_LETTERS = set("ufqv46")
NEWBRANCH_FLAGS = {"--quiet", "-q", "--track", "-t", "--no-track"}
REMOTE_KEYS_OK = {"url", "fetch", "tagopt", "prune", "prunetags", "promisor", "partialclonefilter",
                  "skipdefaultupdate", "skipfetchall", "followremotehead"}
PUSH_KEYS_OK = {"autosetupremote", "usebitmaps", "negotiate", "useforceifincludes"}
BOOL_INT = re.compile(r"^[+-]?(0x[0-9a-f]+|[0-9]+)[kmg]?$")
STOCK_SIGNERS = {"gpg", "gpg2", "gpgsm", "ssh-keygen"}
STOCK_OWNER_UID = 0
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


def commit_facts(args):
    """(message given, --no-gpg-sign given, verbose) for ``git commit`` words that options_ok accepted: a real walk
    over option words and their values (a message or file named like an option is a value, not an option)."""
    message = nosign = verbose = False
    i = 0
    while i < len(args):
        word = args[i]
        i += 1
        if word == "--":
            break
        if not (word.startswith("-") and len(word) > 1):
            continue
        if word in COMMIT_VALUE or COMMIT_CLUSTER.match(word):
            message = True
            i += 1  # the value, whatever it looks like
            verbose = verbose or (COMMIT_CLUSTER.match(word) is not None and "v" in word)
        elif word.startswith(("--message=", "--file=")) or (word.startswith("-m") and not word.startswith("--")):
            message = True
        elif word == "--no-edit":
            message = True
        elif word == "--no-gpg-sign":
            nosign = True
        elif word in ("-v", "--verbose") or (COMMIT_BOOL_CLUSTER.match(word) is not None and "v" in word):
            verbose = True
    return message, nosign, verbose


def inert_git(sub, args):
    """None when ``git <sub> <args>`` is not provably free of side effects on the push's facts, else ``(sub, flags)``:
    flags say what the stored settings must be checked for (see check_program_config): ``diff`` (renders a diff, so
    textconv and external diff run), ``editor`` (a commit without a message), ``nosign`` (--no-gpg-sign)."""
    flags = set()
    if sub in VIEWERS:
        ok = options_ok(args, VIEW_COMMON, VIEW_PREFIXES, clusters=(VIEW_CLUSTER,))
    elif sub in INERT_GIT_ANY:
        ok = True
    elif sub == "status":
        ok = options_ok(args, STATUS_FLAGS, clusters=(STATUS_CLUSTER,))
        if ok and any(a in ("-v", "--verbose") or (STATUS_CLUSTER.match(a) and "v" in a) for a in args if a != "--"):
            flags.add("diff")  # status -v shows the staged diff, through textconv
    elif sub in ("add", "stage"):
        ok = options_ok(args, ADD_FLAGS)
    elif sub == "commit":
        ok = options_ok(args, COMMIT_FLAGS, ("--message=", "--file=", "-m"), COMMIT_VALUE, (COMMIT_BOOL_CLUSTER,),
                        (COMMIT_CLUSTER,))
        if ok:
            message, nosign, verbose = commit_facts(args)
            for flag, wanted in (("editor", not message), ("nosign", nosign), ("diff", verbose)):
                if wanted:
                    flags.add(flag)
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
    return (sub, frozenset(flags)) if ok else None


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
        inert = inert_git(sub, args)
        if inert is not None:
            return ("inert", inert)
        return ("other", "git " + sub)
    if prog in INERT_PROGRAMS and not (prog == "printf" and any(a.startswith("-") for a in argv[1:])):
        # printf -v NAME (also -vNAME) assigns a shell variable: any dash-word makes printf not inert
        return ("inert", ("", frozenset()))
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


def effective_editor(cfg, environ):
    """The editor git starts for a commit message: GIT_EDITOR, core.editor, VISUAL, EDITOR (git's own order)."""
    for value in (environ.get("GIT_EDITOR"), cfg_get(cfg, "core.editor"), environ.get("VISUAL"), environ.get("EDITOR")):
        if value:
            return value
    return ""


def git_bool(value):
    """A config value read as git reads a boolean: true/yes/on, false/no/off, an empty string is false, and any other
    integer (also 0x.., k/m/g suffixes) is false only when it is zero. Anything git would reject counts as true
    (the strict reading)."""
    text = value.lower()
    if text in ("true", "yes", "on"):
        return True
    if text in ("false", "no", "off", ""):
        return False
    if BOOL_INT.match(text):
        body = text.lstrip("+-")
        body = body[:-1] if body[-1] in "kmg" else body
        return int(body, 16 if body.startswith("0x") else 10) != 0
    return True


def safe_chain(path):
    """Every directory from / to ``path`` is owned by root and not group/world-writable (a sticky shared directory
    such as /tmp is therefore not)."""
    current = os.path.dirname(path)
    while True:
        try:
            info = os.stat(current)
        except OSError:
            return False
        if info.st_uid != STOCK_OWNER_UID or info.st_mode & 0o022:
            return False
        parent = os.path.dirname(current)
        if parent == current:
            return True
        current = parent


def file_digest(path):
    """sha256 of a file's content (hex), or "" when it cannot be read."""
    try:
        with open(path, "rb") as handle:
            return hashlib.sha256(handle.read()).hexdigest()
    except OSError:
        return ""


def trust_entry(path):
    """The consent-file entry that pins ``path``: its realpath, owner, mode and the sha256 of its content."""
    real = os.path.realpath(path)
    info = os.stat(real)
    return {"path": path, "realpath": real, "uid": info.st_uid, "mode": info.st_mode & 0o7777,
            "sha256": file_digest(real)}


def user_trusted_programs(environ):
    """Signing programs the user blessed in the per-user consent file (never the committed project config):
    ``{"trusted_programs": {"signing": [{"path", "realpath", "uid", "mode", "sha256"}, ...]}}`` in
    ${XDG_CONFIG_HOME:-~/.config}/silver-bullet/consent.json, a regular file owned by the current user that nobody
    else can access. Returns the entries by path; each is checked against the file as it is now (pinned_program)."""
    base = environ.get("XDG_CONFIG_HOME") or os.path.join(environ.get("HOME") or "/nonexistent", ".config")
    path = os.path.join(base, "silver-bullet", "consent.json")
    try:
        info = os.lstat(path)
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.geteuid() or info.st_mode & 0o077:
            return {}
        with open(path, encoding="utf-8") as handle:
            listed = json.load(handle)["trusted_programs"]["signing"]
    except (OSError, ValueError, KeyError, TypeError):
        return {}
    entries = {}
    for item in listed if isinstance(listed, list) else []:
        if isinstance(item, dict) and isinstance(item.get("path"), str):
            entries[item["path"]] = item
    return entries


def pinned_program(value, entry):
    """The program at ``value`` is the one the user blessed: same realpath, owner, mode and content hash."""
    try:
        now = trust_entry(value)
    except OSError:
        return False
    return all(entry.get(field) == now[field] for field in ("realpath", "uid", "mode", "sha256")) and bool(now["sha256"])


def stock_signer(value, directory, environ):
    """A signing/verification program git would run that is trusted: an absolute path the user listed in the
    per-user consent file, or a stock system signer: gpg, gpg2, gpgsm or ssh-keygen, a regular file owned by root that
    nobody else can write, in directories that are all root-owned and not writable by others, not a symlink to
    anything less, and outside the project and HOME."""
    if not os.path.isabs(value) or re.search(r"\s", value):
        return False
    entry = user_trusted_programs(environ).get(value)
    if entry is not None:
        return pinned_program(value, entry)
    if os.path.basename(value) not in STOCK_SIGNERS:
        return False
    try:
        real = os.path.realpath(value)
        info = os.stat(real)
    except OSError:
        return False
    for root in (directory, environ.get("HOME") or "/nonexistent"):
        top = os.path.realpath(root)
        if real == top or real.startswith(top.rstrip("/") + "/"):
            return False
    return (stat.S_ISREG(info.st_mode) and info.st_uid == STOCK_OWNER_UID and not info.st_mode & 0o022
            and safe_chain(value) and safe_chain(real))


def check_signing(sub, key, values, cfg, directory, environ):
    """gpg program settings: a commit that signs, and log/show (which verify signatures: log.showSignature, %G?
    placeholders, --show-signature) run them; a stock system signer is accepted, anything else is a program."""
    verifies = sub in ("log", "show", "shortlog")
    commits = sub == "commit" and git_bool(cfg_get(cfg, "commit.gpgsign") or "")
    if not (verifies or commits):
        return
    if key.endswith("defaultkeycommand") or not all(stock_signer(v, directory, environ) for v in values):
        raise Strict("git %s %s with the program named by %s" % (
            sub, "verifies signatures" if verifies else "signs", key))


def benign_pager(value):
    """A stock pager: nothing, true, `:`, cat, less, more, most with plain dash options."""
    if value in BENIGN_PAGERS:
        return True
    words = value.split()
    return os.path.basename(words[0]) in ("cat", "less", "more", "most") and \
        all(re.fullmatch(r"-[A-Za-z0-9]+", word) for word in words[1:]) and "/" not in value.replace(words[0], "", 1)


def check_program_config(subs, cfg, environ=None, directory=""):
    """An inert git subcommand runs the programs stored settings name for it. ``subs`` holds ``(subcommand, flags)``:
    fsmonitor, filters, hooks path and gc hooks for all; textconv and external diff for log/show/diff, status -v and
    commit -v (or commit.verbose); pagers for the viewers; the gpg program for a commit that signs and for
    log/show/shortlog; the editor for a commit without a message. Any such setting makes the push final delivery."""
    environ = environ or {}
    for sub, flags in subs:
        shown = sub
        viewer = sub in VIEWERS
        editor_commit = "editor" in flags
        diffs = viewer or "diff" in flags or (editor_commit and git_bool(cfg_get(cfg, "commit.verbose") or ""))
        for key, values in cfg.items():
            if key in LFS_STOCK and all(v in LFS_STOCK[key] for v in values):
                continue  # the stock git-lfs filter commands (git-lfs is installed with git)
            if key == "core.fsmonitor" and all(v.lower() in BOOL_WORDS for v in values):
                continue  # a boolean selects git's built-in file system monitor, not a program (no stripping)
            if RUN_CONFIG.match(key) or (diffs and DIFF_CONFIG.match(key)) or (sub == "commit" and GC_CONFIG.match(key)):
                raise Strict("git %s would run a program named by the setting %s" % (shown, key))
            if viewer and PAGER_CONFIG.match(key) and not all(benign_pager(v) for v in values):
                raise Strict("git %s would start the pager named by %s" % (shown, key))
            if SIGN_CONFIG.match(key) and "nosign" not in flags:
                check_signing(sub, key, values, cfg, directory, environ)
        if viewer:
            for name in ("GIT_PAGER", "PAGER"):
                if not benign_pager(environ.get(name) or ""):
                    raise Strict("git %s would start the pager %s" % (shown, environ[name].split()[0]))
        if editor_commit:
            editor = effective_editor(cfg, environ)
            if editor and editor not in BENIGN_EDITORS:
                raise Strict("git commit would start the editor %s (set a message with -m)" % editor.split()[0])


def plain_words(script):
    """An expansion that assigns or computes in the CURRENT shell (`$((X=1))`, `$[X=1]`, `${X:=v}`, `${X=v}`, array
    forms; anything the parser keeps as ``dyn``) can change a variable git reads (HOME, PATH, GIT_*...). Command
    substitutions run in a subshell and their commands are judged by S5; plain `$NAME` reads are harmless."""
    for andor, _background in script.items:
        for pipeline in andor:
            for node in pipeline:
                words = list(node.words) + [w for assign in node.assigns for w in assign.value]
                for redir in node.redirs:
                    words += [w for w in (redir.target, redir.body_word) if w is not None]
                for word in words:
                    if any(atom[0] == "dyn" for atom in word.atoms):
                        raise Strict("a word uses an expansion that assigns or computes a shell variable "
                                     "(arithmetic, ${..=..}, ${..:+..})")


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


def ssh_command_ok(command):
    """A plain `ssh [-i KEY] [-F FILE] [-p N] [-o Name=value] ...` command line: no quoting, no shell syntax and no
    option that runs a command (ProxyCommand, LocalCommand, KnownHostsCommand...)."""
    tokens = command.split()
    if not tokens or tokens[0] not in SSH_PROGRAMS:
        return False
    i = 1
    while i < len(tokens):
        word = tokens[i]
        i += 1
        if word in SSH_BOOL_FLAGS:
            continue
        if word in SSH_VALUE_FLAGS or word == "-o":
            if i >= len(tokens):
                return False
            value, i = tokens[i], i + 1
        elif word.startswith("-o") and len(word) > 2:
            value = word[2:]
        else:
            return False
        if not SSH_VALUE.match(value):
            return False
        if word in ("-o", ) or word.startswith("-o"):
            name = value.split("=", 1)[0].lower()
            if "=" not in value or name.endswith("command") or name.endswith("provider") or name in SSH_PROGRAM_OPTIONS:
                return False
    return True


def stock_helper(value):
    """A credential helper that is a stock one: store/cache/osxkeychain/manager/libsecret/netrc (with plain
    options), `gh auth git-credential`, or git's own git-credential-* in its exec directory."""
    if value == "" or GH_HELPER.match(value):
        return True
    name = value.split(None, 1)[0]
    rest = value[len(name):]
    if name in STOCK_HELPERS:
        return bool(STOCK_HELPER_ARGS.match(rest))
    return os.path.dirname(name) in CREDENTIAL_EXEC_DIRS and os.path.basename(name).startswith("git-credential-") \
        and bool(STOCK_HELPER_ARGS.match(rest))


def safe_url(url):
    """A remote URL that git reaches with its own transports: https, http, ssh, git, file, scp-like or a path; not
    `<helper>::...` and not another scheme (that runs git-remote-<scheme> from PATH, or ext:: runs a command)."""
    if "::" in url:
        return False
    match = re.match(r"^([A-Za-z][A-Za-z0-9+.-]*)://", url)
    return match is None or match.group(1).lower() in SAFE_SCHEMES


def check_push_programs(key, values):
    """Programs a push itself starts or the transport it uses: ssh, proxy, askpass, credential helpers, remote
    helpers, alternate-refs command. A stock form is accepted; anything else is final delivery."""
    if key == "core.sshcommand":
        ok = all(ssh_command_ok(v) for v in values)
    elif key in ("core.gitproxy", "core.askpass", "core.alternaterefscommand", "uploadpack.packobjectshook"):
        ok = all(v == "" for v in values)
    elif key == "protocol.ext.allow":
        ok = all(v.lower() == "never" for v in values)
    else:  # credential.helper, credential.<url>.helper
        ok = all(stock_helper(v) for v in values)
    if not ok:
        raise Strict("the setting %s makes the push start a program" % key)


def check_config(cfg, remote):
    """S10: per-namespace allowlists for the keys that steer a push."""
    for key, values in cfg.items():
        parts = remote_variable(key)
        if parts is not None and parts[0] == remote:
            var = parts[1]
            if var == "mirror":
                if any(git_bool(v) for v in values):
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
                if git_bool(value):
                    raise Strict("push.followTags pushes tags")
            elif name == "gpgsign":
                if value != "false" and (value == "if-asked" or git_bool(value)):
                    raise Strict("push.gpgSign makes the push run the signing program")
            elif name not in PUSH_KEYS_OK:
                raise Strict("%s changes what a push sends" % key)
        elif key.startswith("url.") and key.endswith(".pushinsteadof"):
            raise Strict("a url.*.pushInsteadOf rewrite changes where a push goes")
        if key == "core.hookspath" and any(values):
            raise Strict("core.hooksPath names the directory of the pre-push hook")
        if PUSH_RUN_CONFIG.match(key):
            check_push_programs(key, values)
        if key.startswith("url.") and key.endswith(".insteadof") and not safe_url(key[len("url."):-len(".insteadof")]):
            raise Strict("a url.*.insteadOf rewrite points git at a remote helper (%s)" % key)
        if parts is not None and parts[0] == remote and parts[1] == "url" and not all(safe_url(v) for v in values):
            raise Strict("the remote URL names a remote helper or an unsupported transport")


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
    the inert git subcommands among them (``found["subs"]``). ``wrapper`` is the argv of an
    unwrapped `bash -c '<script>'`, which is not itself a command of the script."""
    found = {"push": [], "cd": [], "newbranch": [], "subs": set()}
    for entry in result.get("commands") or []:
        argv = entry.get("argv") or []
        if wrapper is not None and argv == wrapper:
            wrapper = None
            continue
        kind = classify_argv(argv)
        if kind[0] in ("push", "cd", "newbranch"):
            found[kind[0]].append((entry, kind))
            if kind[0] == "newbranch":
                found["subs"].add(("checkout", frozenset()))  # switching branches runs post-checkout, filters and the monitor
        elif kind[0] == "inert":
            found["subs"].add(kind[1])  # (git subcommand, flags); programs have ("", flags) from classify_argv
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


ENV_CONFIG_DENY = re.compile(
    r"^(alias\..+|include\..*|includeif\..*|core\.(hookspath|sshcommand|editor|pager|fsmonitor|askpass|gitproxy)|"
    r"remote\..+\.(push|pushurl|mirror|receivepack|uploadpack|vcs|proxy)|remote\.pushdefault|push\..+|"
    r"url\..+\.pushinsteadof|filter\..+|diff\..+|pager\..+|gpg\..+|branch\..+\.(remote|pushremote|merge))$",
    re.IGNORECASE)


def env_config_check(environ):
    """GIT_CONFIG_COUNT/KEY_n/VALUE_n (cloud sessions export credential and insteadOf settings this way): well
    formed, and no key that changes what a push sends or runs a program (git also lists them in the stored
    configuration, which is judged again by the same rules)."""
    count = environ.get("GIT_CONFIG_COUNT")
    if not count:
        return
    if not (count.isdigit() and int(count) <= 64):
        raise Strict("GIT_CONFIG_COUNT is not a number and redirects git")
    for index in range(int(count)):
        key = environ.get("GIT_CONFIG_KEY_%d" % index)
        if not key or ("GIT_CONFIG_VALUE_%d" % index) not in environ:
            raise Strict("GIT_CONFIG_COUNT names a setting that is not defined (redirects git)")
        if ENV_CONFIG_DENY.match(key):
            raise Strict("GIT_CONFIG_KEY_%d=%s sets git configuration that changes a push" % (index, key))


def env_check(environ):
    """S1: variables that redirect git or run code in every bash (the repository's own coverage tracer excepted)."""
    env_config_check(environ)
    ssh_command = environ.get("GIT_SSH_COMMAND")
    if ssh_command and not ssh_command_ok(ssh_command):
        raise Strict("GIT_SSH_COMMAND is set to a command line that is not a plain ssh invocation")
    if any(not entry.startswith("/") for entry in (environ.get("PATH") or "/usr/bin").split(":")):
        raise Strict("PATH has an empty or relative entry, so `git` may not be the system git")
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
    plain_words(script)
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
    check_program_config(found["subs"], cfg, environ, directory)
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


# The classifier's own list of program-running configuration keys, by name (tests/fixtures/push-scope/
# program-mechanisms.json is diffed against it by tests/python/test_program_mechanisms.py).
PROGRAM_KEY_PATTERNS = {"run": RUN_CONFIG, "sign": SIGN_CONFIG, "editor": EDITOR_CONFIG, "push_run": PUSH_RUN_CONFIG,
                        "url": URL_CONFIG, "view": VIEW_CONFIG, "gc": GC_CONFIG}


def main(argv):
    """``push_scope.py --trust-entry PATH``: print the consent-file entry that pins PATH (see user_trusted_programs)."""
    if len(argv) == 2 and argv[0] == "--trust-entry":
        try:
            print(json.dumps(trust_entry(argv[1]), indent=2))
        except OSError as exc:
            print("cannot read %s: %s" % (argv[1], exc), file=sys.stderr)
            return 1
        return 0
    print("usage: push_scope.py --trust-entry PATH", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
