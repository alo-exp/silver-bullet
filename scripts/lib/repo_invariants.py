#!/usr/bin/env python3
"""File-content invariants for scripts/check-repo-invariants.sh.

Usage: repo_invariants.py CHECK [ROOT]

CHECK is one of:
  worm-indicators       host configuration that runs code when the folder is opened
                        (VS Code folder-open tasks, task.allowAutomaticTasks) and the
                        public/fonts/ payload directory of the recurring repository worm
  binary-signatures     font and image files whose bytes are not that format (a script or
                        text saved under a font or image name)
  vendored-skills-lock  the third-party skills under .agents/skills, and the tool-managed
                        (graphify) skill directories, match skills-lock.json
  personal-data         no tracked text file holds a personal home-directory path or an
                        email address outside the allowlist
  tracked-file-size     no tracked file nears GitHub's 100 MB per-file limit
  site-duplicate-ids    no page of the public site (site/**/*.html) repeats an element id

refresh-skills-lock [ROOT] re-locks the tool-managed skill directories in skills-lock.json
after a tool (graphify) upgrade rewrote them.

ROOT (default: the current directory) is the repository to check. The files checked are
the ones git tracks there, or every file under ROOT when ROOT is not the top of a git work
tree (a fixture copy). Prints one line per problem and exits 1 when there is any, 0 when
there is none, 2 on a usage error. Standard library only.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
import sys
from collections import Counter
from html.parser import HTMLParser
from pathlib import Path

# --- which files ---------------------------------------------------------------------------


def git_toplevel(root: Path) -> Path | None:
    """The top of the git work tree that contains ROOT, or None."""
    try:
        out = subprocess.run(
            ["git", "-C", str(root), "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return None
    return Path(out).resolve()


def tracked_files(root: Path) -> list[str]:
    """Repo-relative POSIX paths of the files to check, sorted."""
    if git_toplevel(root) == root.resolve():
        out = subprocess.run(
            ["git", "-C", str(root), "ls-files", "-z"], capture_output=True, check=True,
        ).stdout
        return sorted(p for p in out.decode("utf-8", "surrogateescape").split("\0") if p)
    files = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d != ".git"]
        files.extend(Path(dirpath, name).relative_to(root).as_posix() for name in filenames)
    return sorted(files)


def read_bytes(root: Path, rel: str, limit: int = -1) -> bytes | None:
    """The first LIMIT bytes of a regular file (all with -1), or None if it is not one."""
    path = root / rel
    if not path.is_file():
        return None
    with path.open("rb") as handle:
        return handle.read(limit)


# --- worm indicators -------------------------------------------------------------------------

# Host configuration that VS Code (and its forks) applies when the folder is opened.
AUTORUN_CONFIG = re.compile(r"(^|/)\.vscode/[^/]+$|\.code-workspace$")
FOLDER_OPEN_TASK = re.compile(r"""["']?runOn["']?\s*:\s*["']folderOpen["']""")
AUTOMATIC_TASKS = re.compile(r"""["']task\.allowAutomaticTasks["']\s*:""")
PAYLOAD_DIR = re.compile(r"(^|/)public/fonts/")
UNICODE_ESCAPE = re.compile(r"\\u([0-9a-fA-F]{4})")


def decode_json_escapes(text: str) -> str:
    """VS Code parses these files as JSON, so "folder\\u004fpen" means folderOpen."""
    return UNICODE_ESCAPE.sub(lambda match: chr(int(match.group(1), 16)), text)


def strip_jsonc(text: str) -> str:
    """Remove // and /* */ comments and trailing commas outside strings (what VS Code ignores)."""
    out: list[str] = []
    i, n = 0, len(text)
    while i < n:
        char = text[i]
        if char == '"':
            j = i + 1
            while j < n and text[j] != '"':
                j += 2 if text[j] == "\\" else 1
            out.append(text[i:j + 1])
            i = j + 1
        elif text.startswith("//", i):
            # VS Code's scanner ends a line comment at CR as well as at LF.
            while i < n and text[i] not in "\r\n":
                i += 1
        elif text.startswith("/*", i):
            end = text.find("*/", i + 2)
            i = n if end < 0 else end + 2
            out.append(" ")
        else:
            if char in "}]":
                while out and not out[-1].strip():
                    out.pop()
                if out and out[-1] == ",":
                    out.pop()
            out.append(char)
            i += 1
    return "".join(out)


def autorun_kinds(value: object) -> set[str]:
    """Walk parsed config for folder-open tasks and the automatic-task switch at any depth."""
    kinds: set[str] = set()
    if isinstance(value, dict):
        for key, item in value.items():
            if key == "runOn" and item == "folderOpen":
                kinds.add("folder-open")
            if key == "task.allowAutomaticTasks" or (key == "task" and isinstance(item, dict) and "allowAutomaticTasks" in item):
                kinds.add("automatic")
            kinds |= autorun_kinds(item)
    elif isinstance(value, list):
        for item in value:
            kinds |= autorun_kinds(item)
    return kinds


def worm_indicators(root: Path, files: list[str]) -> list[str]:
    problems = []
    for rel in files:
        if PAYLOAD_DIR.search(rel):
            problems.append(f"{rel}: tracked under public/fonts/, where the repository worm hid its payload")
        if not AUTORUN_CONFIG.search(rel):
            continue
        raw = read_bytes(root, rel)
        if raw is None:
            continue
        text = raw.decode("utf-8-sig", "replace")  # VS Code reads a leading BOM as nothing
        # The literal members count too, so a difference between this parser and VS Code's
        # (duplicate keys, comment rules) can never hide one.
        decoded = decode_json_escapes(text)
        kinds = {name for name, rx in (("folder-open", FOLDER_OPEN_TASK), ("automatic", AUTOMATIC_TASKS)) if rx.search(decoded)}
        try:
            kinds |= autorun_kinds(json.loads(strip_jsonc(text)))
        except ValueError:
            if rel.endswith((".json", ".code-workspace")):
                problems.append(f"{rel}: cannot be parsed as JSON with comments, so it cannot be checked for auto-run tasks")
        if "folder-open" in kinds:
            problems.append(f"{rel}: task runs automatically when the folder is opened (runOn: folderOpen)")
        if "automatic" in kinds:
            problems.append(f"{rel}: sets task.allowAutomaticTasks, which lets such tasks run unprompted")
    return problems


# --- binary signatures --------------------------------------------------------------------------

# extension -> alternatives, each a list of (offset, bytes) that must all match.
SIGNATURES: dict[str, list[list[tuple[int, bytes]]]] = {
    ".woff2": [[(0, b"wOF2")]],
    ".woff": [[(0, b"wOFF")]],
    ".ttf": [[(0, b"\x00\x01\x00\x00")], [(0, b"true")], [(0, b"OTTO")]],
    ".otf": [[(0, b"OTTO")], [(0, b"\x00\x01\x00\x00")]],
    ".eot": [[(34, b"LP")]],
    ".png": [[(0, b"\x89PNG\r\n\x1a\n")]],
    ".jpg": [[(0, b"\xff\xd8\xff")]],
    ".jpeg": [[(0, b"\xff\xd8\xff")]],
    ".gif": [[(0, b"GIF87a")], [(0, b"GIF89a")]],
    ".webp": [[(0, b"RIFF"), (8, b"WEBP")]],
    ".ico": [[(0, b"\x00\x00\x01\x00")]],
    ".bmp": [[(0, b"BM")]],
}


def has_signature(head: bytes, alternatives: list[list[tuple[int, bytes]]]) -> bool:
    return any(
        all(head[offset:offset + len(magic)] == magic for offset, magic in parts)
        for parts in alternatives
    )


def binary_signatures(root: Path, files: list[str]) -> list[str]:
    problems = []
    for rel in files:
        suffix = Path(rel).suffix.lower()
        alternatives = SIGNATURES.get(suffix)
        if alternatives is None:
            continue
        head = read_bytes(root, rel, 64)
        if head is not None and not has_signature(head, alternatives):
            problems.append(f"{rel}: not a {suffix} file (its bytes do not start with the format's signature)")
    return problems


# --- vendored skills -----------------------------------------------------------------------------

SKILLS_DIR = ".agents/skills"
SKILLS_DIRS = (SKILLS_DIR, ".claude/skills")
LOCK_FILE = "skills-lock.json"
TOOL_MANAGED = "toolManaged"
# Skills installed and versioned by a tool: a skill directory holding one of these files.
TOOL_VERSION_FILES = (".graphify_version",)
REFRESH_HINT = "refresh with: python3 scripts/lib/repo_invariants.py refresh-skills-lock"


def dir_hash(base: Path, rel_files: list[str]) -> str:
    """The skills-lock.json computedHash: sha256 over each file's path inside the directory
    followed by its bytes, files in case-insensitive path order."""
    digest = hashlib.sha256()
    for rel in sorted(rel_files, key=lambda p: (p.lower(), p)):
        digest.update(rel.encode("utf-8"))
        digest.update((base / rel).read_bytes())
    return digest.hexdigest()


def skill_hash(root: Path, skill: str, rel_files: list[str]) -> str:
    return dir_hash(root / SKILLS_DIR / skill, rel_files)


def dir_files(root: Path, directory: str, files: list[str]) -> list[str]:
    """The paths inside DIRECTORY (relative to it) of the given repo-relative FILES."""
    prefix = directory + "/"
    return [rel[len(prefix):] for rel in files if rel.startswith(prefix)]


def tool_managed_dirs(files: list[str]) -> list[str]:
    """Skill directories that need a toolManaged lock entry: everything under .claude/skills,
    and any .agents/skills directory that carries a tool version file."""
    found: dict[str, list[str]] = {}
    for base in SKILLS_DIRS:
        prefix = base + "/"
        for rel in files:
            if rel.startswith(prefix) and "/" in rel[len(prefix):]:
                skill, inner = rel[len(prefix):].split("/", 1)
                found.setdefault(f"{base}/{skill}", []).append(inner)
    return sorted(d for d, inner in found.items() if d.startswith(".claude/") or any(v in inner for v in TOOL_VERSION_FILES))


def vendored_skills_lock(root: Path, files: list[str]) -> list[str]:
    by_skill: dict[str, list[str]] = {}
    prefix = SKILLS_DIR + "/"
    for rel in files:
        if rel.startswith(prefix) and "/" in rel[len(prefix):]:
            skill, inner = rel[len(prefix):].split("/", 1)
            by_skill.setdefault(skill, []).append(inner)
    lock_path = root / LOCK_FILE
    try:
        lock = json.loads(lock_path.read_text(encoding="utf-8")) if lock_path.is_file() else {}
        locked = lock.get("skills", {})
    except (ValueError, AttributeError):
        return [f"{LOCK_FILE}: not valid JSON with a \"skills\" object"]
    managed = lock.get(TOOL_MANAGED, {})
    if not isinstance(managed, dict):
        return [f"{LOCK_FILE}: \"{TOOL_MANAGED}\" must be an object"]
    problems = []
    for skill, entry in sorted(locked.items()):
        inner = by_skill.get(skill)
        if not inner:
            problems.append(f"{skill}: listed in {LOCK_FILE} but missing from {SKILLS_DIR}/")
        elif skill_hash(root, skill, inner) != entry.get("computedHash"):
            problems.append(f"{skill}: content does not match {LOCK_FILE} (computedHash)")
    for skill, inner in sorted(by_skill.items()):
        if skill in locked or any(v in inner for v in TOOL_VERSION_FILES):
            continue
        problems.append(f"{skill}: vendored skill is not in {LOCK_FILE}")
    for directory, entry in sorted(managed.items()):
        inner = dir_files(root, directory, files)
        if not inner:
            problems.append(f"{directory}: listed in {LOCK_FILE} {TOOL_MANAGED} but missing")
        elif dir_hash(root / directory, inner) != entry.get("computedHash"):
            problems.append(f"{directory}: content does not match {LOCK_FILE} {TOOL_MANAGED} computedHash ({REFRESH_HINT})")
    for directory in tool_managed_dirs(files):
        if directory not in managed:
            problems.append(f"{directory}: tool-managed skill is not in {LOCK_FILE} {TOOL_MANAGED} ({REFRESH_HINT})")
    return problems


def refresh_skills_lock(root: Path) -> list[str]:
    """Re-lock the tool-managed skill directories found on disk; returns their paths.
    Raises ValueError when the lock file is not a JSON object."""
    lock_path = root / LOCK_FILE
    lock = json.loads(lock_path.read_text(encoding="utf-8")) if lock_path.is_file() else {"version": 1, "skills": {}}
    if not isinstance(lock, dict):
        raise ValueError(f"{LOCK_FILE} is not a JSON object")
    files = [f for f in tracked_files(root) if f.startswith(tuple(base + "/" for base in SKILLS_DIRS))]  # tracked only, as the check reads them
    managed = {}
    for directory in tool_managed_dirs(files):
        entry = {"computedHash": dir_hash(root / directory, dir_files(root, directory, files))}
        version = next(((root / directory / v).read_text(encoding="utf-8").strip() for v in TOOL_VERSION_FILES if (root / directory / v).is_file()), None)
        if version:
            entry = {"version": version, **entry}
        managed[directory] = entry
    lock[TOOL_MANAGED] = managed
    lock_path.write_text(json.dumps(lock, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return list(managed)


# --- tracked file size ---------------------------------------------------------------------------

MAX_TRACKED_MIB = 90  # GitHub rejects pushes with a file over 100 MB


def tracked_file_size(root: Path, files: list[str]) -> list[str]:
    problems = []
    for rel in files:
        path = root / rel
        if not path.is_file():
            continue
        mib = path.stat().st_size / (1024 * 1024)
        if mib > MAX_TRACKED_MIB:
            problems.append(f"{rel}: {mib:.1f} MiB, over the {MAX_TRACKED_MIB} MiB limit (GitHub rejects files over 100 MB)")
    return problems


# --- personal data --------------------------------------------------------------------------------
# Machine-specific home directories and personal email addresses leak who built the repository
# and where; they also ship to every plugin install. Reported by line, never by value.

# Path forms: /Users/<n>, /home/<n>, /var/home/<n>, /mnt/c/Users/<n> (WSL), C:\\Users\\<n> (any case, any slash count).
HOME_PATH = re.compile(
    r"(?<![A-Za-z0-9])(?:/mnt/[a-z]/Users/|/(?:var/)?(?:Users|home)/|[A-Za-z]:[\\/]+Users[\\/]+)([A-Za-z0-9][A-Za-z0-9._-]*)", re.I)
# Flattened forms that tools derive from a home path: Cursor's Users-<n>-projects-..., the lean-ctx
# _Users_<n>_..., Claude's -home-<n>-... project directories, and normalised graph labels. Lower-case
# users_/users- and underscore home need a well-known directory after the name, because users_table_
# and _home_core_markets are ordinary identifiers.
SUBDIR = r"(?=(?:projects|desktop|documents|downloads|library|code|dev|work|workspace|repos|src|github|git|sites)(?![A-Za-z0-9]))"
FLAT_HOMES = (
    re.compile(r"(?<![A-Za-z0-9])[-_]?Users[-_]([A-Za-z0-9]+)[-_]"),
    re.compile(r"(?<![A-Za-z0-9])-home-([A-Za-z0-9]+)-"),
    re.compile(r"(?<![A-Za-z0-9])[-_]?(?:users|home)[-_]([A-Za-z0-9]+)[-_]" + SUBDIR, re.I),
)
# Generic names that stand for "some user" in examples, fixtures, system, CI, VM and container accounts.
GENERIC_HOME_NAMES = frozenset({
    "user", "users", "username", "name", "you", "me", "example", "shared", "guest", "u", "foo", "bar", "test", "x",
    "alice", "bob", "jane", "ada", "dev", "developer", "demo", "sample", "someone", "yourname", "your-name", "nobody",
    "root", "admin", "administrator", "agent", "sandbox", "claude", "docker", "build", "builder", "john", "johndoe",
    "john.doe", "jane.doe", "janedoe", "jdoe", "jsmith", "first", "last", "first.last", "firstname", "lastname", "me",
    # CI, VM, distro, cloud and container accounts
    "runner", "runneradmin", "ubuntu", "node", "vscode", "zed", "linuxbrew", "codespace", "gitpod", "ec2-user",
    "vagrant", "jovyan", "pi", "circleci", "coder", "jenkins", "travis", "appveyor", "github", "www-data",
    "azureuser", "opc", "centos", "debian", "fedora", "core", "git", "postgres", "nonroot", "app", "mambauser",
    "wdagutilityaccount", "defaultuser0", "devcontainer", "lima", "rocky", "alma", "admin1", "packer", "cloud-user",
    "public", "default", "all", "guide", "manual", "docs", "doc", "list", "table", "profile", "profiles", "data",
    "and", "or", "of", "the", "who", "with", "facing", "only", "can", "to", "in", "for",
})
GENERIC_NUMBERED = re.compile(r"(?:user|test|dev|demo|admin|ci|runner)[0-9]*\Z")
EMAIL_DOMAIN = re.compile(r"((?:[A-Za-z0-9-]+\.)+[A-Za-z]{2,})")
EMAIL_LOCAL = re.compile(r"[A-Za-z0-9._%+-]+\Z")
# The maintainer's public addresses, placeholder domains used by tests and docs, and vendor domains.
EMAIL_DOMAINS = (
    "alolabs.dev", "alolabs.io", "sourcevo.com", "example.com", "example.org", "example.net", "test.com", "t.com", "evil.md",
    "yourcompany.com", "yourdomain.com", "yourorg.com", "mycompany.com", "company.com", "acme.com", "domain.tld", "anthropic.com",
    "python.org",
)
EMAIL_TEST_TLDS = frozenset({"invalid", "test", "localhost", "example", "tld"})
# name@2x.png, pkg@1.0.js: asset and package references, not mailboxes.
EMAIL_FILE_TLDS = frozenset({"png", "jpg", "jpeg", "gif", "svg", "webp", "avif", "ico", "bmp", "tif", "tiff", "js", "mjs", "css",
                             "json", "md", "txt", "html", "tgz", "zip", "woff", "woff2", "ttf"})
# Plainly organisational mailboxes (vendors, support desks, bots), whatever the domain.
EMAIL_ROLE_LOCALS = frozenset({
    "noreply", "no-reply", "support", "security", "contact", "help", "sales", "press", "abuse", "privacy", "legal", "billing",
    "feedback", "team", "hello", "hi", "info", "admin", "postmaster", "webmaster", "bot", "dependabot", "notifications", "service",
    "docs", "action", "actions", "github-actions", "ci", "release", "maintainers",
})
GITHUB_URL_USERS = frozenset({"git", "token", "x-access-token"})
ALLOW_FILE = ".github/personal-data-allow.txt"


def generic_name(name: str) -> bool:
    """A placeholder, system, CI or cloud account, or a run of x (a redaction mask)."""
    name = name.lower()
    return name in GENERIC_HOME_NAMES or bool(GENERIC_NUMBERED.match(name)) or set(name) == {"x"}


def load_allowlist(root: Path) -> tuple[frozenset[str], frozenset[str]]:
    """Audited exceptions from ALLOW_FILE: 'home <name>' and 'email <address|@domain>' lines, '#' comments."""
    homes, emails = set(), set()
    raw = read_bytes(root, ALLOW_FILE)
    for line in (raw or b"").decode("utf-8", "replace").splitlines():
        kind, _, value = line.split("#", 1)[0].strip().partition(" ")
        if kind == "home" and value.strip():
            homes.add(value.strip().lower())
        elif kind == "email" and value.strip():
            emails.add(value.strip().lower())
    return frozenset(homes), frozenset(emails)


def email_allowed(local: str, domain: str, allowed_emails: frozenset[str] = frozenset()) -> bool:
    local, domain = local.lower(), domain.lower()
    return (
        local.startswith(("noreply", "no-reply"))
        or local in EMAIL_ROLE_LOCALS
        or generic_name(local)  # ssh user@host, you@..., jane@...
        or f"{local}@{domain}" in allowed_emails
        or "@" + domain in allowed_emails
        or local == "git"  # ssh remotes: git@<host>:org/repo
        or domain.endswith("noreply.github.com")
        or any(domain == allowed or domain.endswith("." + allowed) for allowed in EMAIL_DOMAINS)
        or domain.rsplit(".", 1)[-1] in EMAIL_TEST_TLDS | EMAIL_FILE_TLDS
        or (domain == "github.com" and local in GITHUB_URL_USERS)
    )


def email_hits(text: str, allowed_emails: frozenset[str] = frozenset()) -> list[int]:
    """Offsets of email addresses outside the allowlist; scans only around each '@'."""
    hits, at = [], text.find("@")
    while at != -1:
        local = EMAIL_LOCAL.search(text, max(0, at - 64), at)
        domain = EMAIL_DOMAIN.match(text, at + 1, at + 256)
        if local and domain and not email_allowed(local.group(), domain.group(1), allowed_emails):
            hits.append(local.start())
        at = text.find("@", at + 1)
    return hits


KEYWORD = re.compile(r"users|home")
WINDOW_BEFORE, WINDOW_AFTER = 24, 120


def home_hits(text: str, low: str) -> list[tuple[int, int]]:
    """(start, end) of home-path matches, found by running the patterns only around the words
    'users' and 'home' (a 55 MB graph file otherwise costs several seconds per pattern)."""
    windows: list[list[int]] = []
    for m in KEYWORD.finditer(low):
        begin, end = max(0, m.start() - WINDOW_BEFORE), m.end() + WINDOW_AFTER
        if windows and begin <= windows[-1][1]:
            windows[-1][1] = end
        else:
            windows.append([begin, end])
    hits = []
    for begin, end in windows:
        chunk = text[begin:end]
        for rx in (HOME_PATH, *FLAT_HOMES):
            for m in rx.finditer(chunk):
                if not generic_name(m.group(1)):
                    hits.append((begin + m.start(), begin + m.end(), m.group(1)))
    return hits


HOME_MESSAGE = "personal home-directory path (use a placeholder such as /Users/<user>/)"
EMAIL_MESSAGE = "email address outside the allowlist (alolabs.dev, sourcevo.com, noreply, role mailboxes, test domains)"
SCANNED_BINARY = (".pdf",)  # link annotations and metadata sit in the clear


def personal_data(root: Path, files: list[str]) -> list[str]:
    problems = []
    allowed_homes, allowed_emails = load_allowlist(root)
    for rel in files:
        raw = read_bytes(root, rel)
        if raw is None or rel == ALLOW_FILE:
            continue
        binary = b"\0" in raw[:8000]
        if binary and not rel.lower().endswith(SCANNED_BINARY):
            continue
        text = raw.decode("latin-1" if binary else "utf-8", "replace")
        low = text.lower()  # only to decide whether the file can hold anything; offsets are taken after decoding
        if "@" in text or "users" in low or "home" in low:
            # JSON-escaped (\/, \\/, \u002f) and URL-encoded (%2F, %5C) separators; newlines stay put, so line numbers hold.
            if "\\" in text:
                text = re.sub(r"\\u00(2[fF]|5[cC])", lambda m: "/" if m.group(1) in "2f2F" else "\\", text)
                while "\\/" in text:
                    text = text.replace("\\/", "/")
            if "%" in text:
                text = text.replace("%2F", "/").replace("%2f", "/").replace("%5C", "\\").replace("%5c", "\\")
            hits = [(start, end, HOME_MESSAGE) for start, end, name in home_hits(text, text.lower()) if name.lower() not in allowed_homes]
            hits += [(offset, offset, EMAIL_MESSAGE) for offset in email_hits(text, allowed_emails)]
            reported_to = -1
            for start, end, message in sorted(hits):
                if start < reported_to:
                    continue  # the same text matched by two patterns
                reported_to = max(end, start + 1)
                problems.append(f"{rel}:{text.count(chr(10), 0, start) + 1}: {message}")
    return problems


# --- site pages ----------------------------------------------------------------------------------


class IdCollector(HTMLParser):
    """Collects the non-empty id attribute of every element."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.ids: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        self.ids.extend(value for name, value in attrs if name == "id" and value)

    handle_startendtag = handle_starttag


def site_duplicate_ids(root: Path, files: list[str]) -> list[str]:
    problems = []
    for rel in files:
        if not (rel.startswith("site/") and rel.endswith(".html")):
            continue
        data = read_bytes(root, rel)
        if data is None:
            continue
        collector = IdCollector()
        collector.feed(data.decode("utf-8", "replace"))
        duplicates = sorted(i for i, count in Counter(collector.ids).items() if count > 1)
        if duplicates:
            problems.append(f"{rel}: duplicate id {', '.join(duplicates)}")
    return problems


# --- GitHub Actions workflows ----------------------------------------------------------------------
# A line-oriented reading of the block-style YAML the workflows use (no YAML parser in the
# standard library): top-level keys start in column 0, children are indented below them.

WORKFLOW_FILE = re.compile(r"^\.github/workflows/[^/]+\.ya?ml$")
UNPINNED = re.compile(r"@latest\b|\bnpx\s+(--yes|-y)\b")
# run: scripts and actions/github-script script: bodies; GitHub expands ${{ }} in both before any shell or JS runs.
RUN_KEY = re.compile(r"^(\s*(?:-\s+)?)(?:run|script)\s*:\s*(.*)$")
CONTINUE_ON_ERROR = re.compile(r"^\s*(?:-\s+)?continue-on-error\s*:\s*(?!false\s*(?:#.*)?$)(?:\S|$)")
QUOTED_KEY = re.compile(r"""^\s*(?:-\s+)?["'][^"']+["']\s*:""")
FLOW_STEP = re.compile(r"^\s*-\s+\{")
FLOW_STEPS_KEY = re.compile(r"""^\s*(?:-\s+)?["']?steps["']?\s*:\s*[\[{]""")
# group(1) is the indentation up to the key (past a list dash), the column the scalar's text must exceed.
BLOCK_SCALAR = re.compile(r"^(\s*(?:-\s+)?)[^#\s][^#]*?:\s*[|>][+-]?[0-9]*\s*(?:#.*)?$")
# Anything the line-oriented reading cannot follow safely fails closed: flow collections, anchors, aliases,
# tags and complex keys (a line opening with "? " or ": "), also as the value of a key.
FLOW_LINE = re.compile(r"^\s*(?:[\[{]|-\s+[&*!]|jobs\s*:\s*[\[{]|[?:](?:\s|$)|(?:-\s+)?[A-Za-z0-9_.-]+\s*:\s*[&*!])")
CHECKOUT_GUARD = re.compile(r"git status --porcelain --ignored\b")
WRITE_ALL = re.compile(r"""^\s*permissions:\s*["']?write-all\b""")
FORCE_NODE24 = re.compile(r"^\s+FORCE_JAVASCRIPT_ACTIONS_TO_NODE24:\s*true\s*$")
JOB_HEADER = re.compile(r"^\s+[A-Za-z0-9_-]+:\s*$")


def indent_of(line: str) -> int:
    return len(line) - len(line.lstrip(" "))


def top_level_block(lines: list[str], key: str) -> list[tuple[int, str]]:
    """(line number, line) of the lines nested under the top-level KEY."""
    block, inside = [], False
    for number, line in enumerate(lines, 1):
        if line[:1] not in ("", " ", "#"):
            inside = line.startswith(key + ":")
        elif inside:
            block.append((number, line))
    return block


def block_extent(lines: list[str], start: int, parent_indent: int) -> list[tuple[int, str]]:
    """The lines after line START (1-based) that are nested deeper than PARENT_INDENT."""
    extent = []
    for number in range(start + 1, len(lines) + 1):
        line = lines[number - 1]
        if line.strip() and indent_of(line) <= parent_indent:
            break
        extent.append((number, line))
    return extent


def flow_job_lines(lines: list[str]) -> set[int]:
    """Line numbers of job headers written as a flow mapping or sequence (build: {...})."""
    jobs = [(n, line) for n, line in top_level_block(lines, "jobs") if line.strip() and not line.lstrip().startswith("#")]
    if not jobs:
        return set()
    job_indent = min(indent_of(line) for _, line in jobs)
    return {n for n, line in jobs if indent_of(line) == job_indent and re.match(r"^\s+[A-Za-z0-9_-]+:\s*[\[{]", line)}


def job_timeout_problems(rel: str, lines: list[str]) -> list[str]:
    jobs = [(n, line) for n, line in top_level_block(lines, "jobs") if line.strip() and not line.lstrip().startswith("#")]
    if not jobs:
        return []
    job_indent = min(indent_of(line) for _, line in jobs)
    problems = []
    for number, line in jobs:
        if indent_of(line) != job_indent or not JOB_HEADER.match(line):
            continue
        body = [entry for entry in block_extent(lines, number, job_indent) if entry[1].strip()]
        child_indent = indent_of(body[0][1]) if body else job_indent + 2
        if not any(indent_of(text) == child_indent and text.strip().startswith("timeout-minutes:") for _, text in body):
            problems.append(f"{rel}: job {line.strip()[:-1]} has no timeout-minutes")
    return problems


def workflow_problems(rel: str, lines: list[str]) -> list[str]:
    problems = []
    if not any(line.startswith("permissions:") for line in lines):
        problems.append(f"{rel}: no top-level permissions block (least privilege)")
    if rel.endswith("/ci.yml") and not any(CHECKOUT_GUARD.search(line) for line in lines if not line.lstrip().startswith("#")):
        problems.append(f"{rel}: the checkout-unchanged guard must use git status --porcelain --ignored")
    if any(WRITE_ALL.match(line) for line in lines):
        problems.append(f"{rel}: permissions: write-all (grant only the scopes the job needs)")
    if not any(FORCE_NODE24.match(line) for _, line in top_level_block(lines, "env")):
        problems.append(f"{rel}: FORCE_JAVASCRIPT_ACTIONS_TO_NODE24 is not set to true in the top-level env")
    flow_jobs = flow_job_lines(lines)
    script_until = 0  # last line number of the run script being read
    scalar_until = 0  # last line number of any block scalar (run script, github-script body, ...)
    for number, line in enumerate(lines, 1):
        code = line.strip()
        if number <= script_until:
            # Script text, comment lines included: ${{ }} is expanded before the shell sees a "#".
            if UNPINNED.search(line) and not code.startswith("#"):
                problems.append(f"{rel}:{number}: unpinned @latest or npx --yes")
            if "${{" in line:
                problems.append(f"{rel}:{number}: ${{{{ }}}} expression inside a run script (pass it through env)")
            continue
        if code.startswith("#"):
            continue
        if UNPINNED.search(line):
            problems.append(f"{rel}:{number}: unpinned @latest or npx --yes")
        if number <= scalar_until:
            continue  # literal text of a block scalar, not workflow structure
        if QUOTED_KEY.match(line) or FLOW_STEP.match(line) or FLOW_STEPS_KEY.match(line) or FLOW_LINE.match(line) or number in flow_jobs:
            problems.append(f"{rel}:{number}: quoted keys, anchors, aliases, tags, complex keys and flow-style jobs or steps hide settings from the hardening check; use plain block YAML")
        scalar = BLOCK_SCALAR.match(line)
        if scalar:
            extent = block_extent(lines, number, len(scalar.group(1)))
            scalar_until = extent[-1][0] if extent else number
        if CONTINUE_ON_ERROR.match(line):
            problems.append(f"{rel}:{number}: continue-on-error hides failures")
        run = RUN_KEY.match(line)
        if run:
            if "${{" in run.group(2):
                problems.append(f"{rel}:{number}: ${{{{ }}}} expression inside a run script (pass it through env)")
            extent = block_extent(lines, number, len(run.group(1)))
            script_until = extent[-1][0] if extent else number
        if code.startswith("- "):
            item = [(number, line)] + block_extent(lines, number, indent_of(line))
            text = "\n".join(entry for _, entry in item)
            checkout = next((n for n, entry in item if "uses: actions/checkout@" in entry), None)
            if checkout is not None and not re.search(r"persist-credentials:\s*false\b", text):
                problems.append(f"{rel}:{checkout}: actions/checkout without persist-credentials: false")
    return problems + job_timeout_problems(rel, lines)


def workflow_hardening(root: Path, files: list[str]) -> list[str]:
    problems = []
    for rel in files:
        if not WORKFLOW_FILE.match(rel):
            continue
        data = read_bytes(root, rel)
        if data is not None:
            problems.extend(workflow_problems(rel, data.decode("utf-8", "replace").splitlines()))
    return problems


CHECKS = {
    "worm-indicators": worm_indicators,
    "binary-signatures": binary_signatures,
    "vendored-skills-lock": vendored_skills_lock,
    "personal-data": personal_data,
    "tracked-file-size": tracked_file_size,
    "site-duplicate-ids": site_duplicate_ids,
    "workflow-hardening": workflow_hardening,
}


def main(argv: list[str]) -> int:
    if len(argv) not in (1, 2) or argv[0] not in (*CHECKS, "refresh-skills-lock"):
        print(f"usage: repo_invariants.py {{{','.join(CHECKS)},refresh-skills-lock}} [ROOT]", file=sys.stderr)
        return 2
    root = Path(argv[1] if len(argv) == 2 else ".")
    if argv[0] == "refresh-skills-lock":
        try:
            locked = refresh_skills_lock(root)
        except ValueError as error:
            print(f"refresh-skills-lock: {LOCK_FILE}: {error}", file=sys.stderr)
            return 2
        for directory in locked:
            print(f"  locked {directory}")
        return 0
    problems = CHECKS[argv[0]](root, tracked_files(root))
    for problem in problems:
        print(f"  {problem}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
