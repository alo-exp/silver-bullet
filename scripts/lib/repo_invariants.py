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

import fnmatch
import hashlib
import json
import os
import re
import subprocess
import sys
import unicodedata
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
# _Users_<n>_..., and Claude's -home-<n>-... project directories. Every other spelling of the
# maintainer's own name is caught by the hashed identity tokens (TOKEN_FILE).
FLAT_HOMES = (
    re.compile(r"(?<![A-Za-z0-9])[-_]?Users[-_]([A-Za-z0-9]+)[-_]"),
    re.compile(r"(?<![A-Za-z0-9])-home-([A-Za-z0-9]+)-"),
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
    "wdagutilityaccount", "api", "screen", "page", "dir", "directory", "path", "url", "made", "town", "assistant", "button", "link", "icon", "tab", "menu", "view", "folder", "steam", "ollama", "deploy", "ubuntu", "defaultuser0", "devcontainer", "lima", "rocky", "alma", "admin1", "packer", "cloud-user",
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
EMAIL_TEST_TLDS = frozenset({"invalid", "test", "localhost", "example", "tld", "internal"})
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


TOKEN_FILE = ".github/personal-data-hashes.txt"
TOKEN = re.compile(r"[a-z0-9]+")


def load_hashes(root: Path) -> dict[int, frozenset[str]]:
    """Identity-token hashes from TOKEN_FILE ('<sha256 of the lower-case token> <token length>'), by length."""
    by_length: dict[int, set[str]] = {}
    for line in (read_bytes(root, TOKEN_FILE) or b"").decode("utf-8", "replace").splitlines():
        parts = line.split("#", 1)[0].split()
        if len(parts) == 2 and parts[1].isdigit():
            by_length.setdefault(int(parts[1]), set()).add(parts[0].lower())
    return {length: frozenset(hashes) for length, hashes in by_length.items()}


TOKEN_TABLE = bytes(c if (48 <= c < 58 or 97 <= c < 123) else 32 for c in range(256))


ZERO_WIDTH = re.compile("[\u00ad\u061c\u180e\u200b-\u200f\u202a-\u202e\u2060-\u2064\u2066-\u206f\ufeff]")
UNICODE_ESCAPE = re.compile(r"\\u([0-9a-fA-F]{4})")
# Reading \\n as a newline would hide a Windows path whose name starts with n, t or r, so such files are
# tokenised both ways.
ESCAPED_CONTROLS = ("\\n", "\\t", "\\r")
PERCENT_ESCAPE = re.compile(r"%([2-7][0-9a-fA-F])")
NUMERIC_ENTITY = re.compile(r"&#(?:[xX]([0-9a-fA-F]{1,6})|([0-9]{1,7}));")
# A listed token right after users/home plus 1-3 separators, or after ~ : a home path, never exempt.
PATH_SHAPED = re.compile(rb"(?:(?:users|home)[^a-z0-9\n]{1,3}|~/?)\Z")


def code_point(number: int) -> str:
    return chr(number) if 0x20 <= number <= 0x10FFFF else " "


def fold_for_identity(text: str, control_escapes: bool) -> str:
    """TEXT with JSON (\\uXXXX, optionally \\n \\t \\r), URL (%XX) and numeric HTML escapes decoded,
    zero-width characters removed and compatibility forms (fullwidth letters) folded to ASCII.
    Line numbers are unchanged: no escape decodes to a newline."""
    if "\\u" in text:
        text = UNICODE_ESCAPE.sub(lambda m: code_point(int(m.group(1), 16)), text)
    if control_escapes and "\\" in text:
        text = text.replace("\\n", " ").replace("\\t", " ").replace("\\r", " ")
    if "%" in text:
        text = PERCENT_ESCAPE.sub(lambda m: chr(int(m.group(1), 16)), text)
    if "&#" in text:
        text = NUMERIC_ENTITY.sub(lambda m: code_point(int(m.group(1), 16) if m.group(1) else int(m.group(2))), text)
    if not text.isascii():
        text = ZERO_WIDTH.sub("", text if unicodedata.is_normalized("NFKC", text) else unicodedata.normalize("NFKC", text))
    return text


def identity_context(data: bytes, start: int) -> str:
    """SHA-256 of the quoted string or line around START (at most 200 bytes either side): what an
    allowlist 'file' entry names, so that only this exact text is exempt."""
    before = max(data.rfind(b'"', 0, start), data.rfind(b"\n", 0, start), start - 201) + 1
    stops = [i for i in (data.find(b'"', start), data.find(b"\n", start)) if i != -1]
    return hashlib.sha256(data[before:min(stops + [start + 200, len(data)])].strip()).hexdigest()


def identity_hits(text: str, hashes: dict[int, frozenset[str]], allowed: frozenset[str]) -> list[tuple[int, str]]:
    """(line, message) for each alphanumeric token of TEXT whose SHA-256 is listed: every separator
    form of the maintainer's name (users_<n>_, ~<n>, <n>@..., &#47;<n>) without naming it. A token
    inside a context an allowlist entry names is exempt unless it is path-shaped."""
    data = text.encode("utf-8", "replace")
    low = data.lower()
    unique = {token for token in set(low.translate(TOKEN_TABLE).split()) if len(token) in hashes}
    listed = {token for token in unique if hashlib.sha256(token).hexdigest() in hashes[len(token)]}
    found = []
    spotter = re.compile(rb"(?<![a-z0-9])(?:" + b"|".join(sorted(listed)) + rb")(?![a-z0-9])") if listed else None
    for m in (spotter.finditer(low) if spotter else ()):
        context = identity_context(data, m.start())
        line = data.count(b"\n", 0, m.start()) + 1
        if PATH_SHAPED.search(low, max(0, m.start() - 8), m.start()):
            found.append((line, PATH_IDENTITY_MESSAGE))
        elif not any(context.startswith(entry) for entry in allowed):
            found.append((line, f"{IDENTITY_MESSAGE} (a public use: add 'file <path> {context[:16]}' to {ALLOW_FILE})"))
    return found


class Allowlist:
    """Audited exceptions from ALLOW_FILE, one per line, '#' starts a comment:
    home <name> (a directory name that is not a person), email <address | @domain>,
    file <glob> <context hash> (a public use of the maintainer's name, such as an author field: the
    first 16+ hex digits of the SHA-256 of the quoted string or line holding it, printed by the
    check; only that text is exempt, every other line of the file is still scanned)."""

    def __init__(self, root: Path) -> None:
        self.homes: set[str] = set()
        self.emails: set[str] = set()
        self.files: list[tuple[str, str]] = []
        self.errors: list[str] = []
        self.rest: list[str] = []  # the file's text without its valid entries, scanned like any other file
        for number, line in enumerate((read_bytes(root, ALLOW_FILE) or b"").decode("utf-8", "replace").splitlines(), 1):
            code = line.split("#", 1)[0].strip()
            directive, _, value = code.partition(" ")
            value = value.strip()
            parts = value.split()
            valid = (directive in ("home", "email") and bool(value)) or (
                directive == "file" and len(parts) == 2 and len(parts[1]) >= 16 and re.fullmatch("[0-9a-fA-F]+", parts[1]) is not None)
            if code and not valid:
                self.errors.append(f"{ALLOW_FILE}:{number}: unknown or incomplete directive (expected: home <name>, email <address>, file <path-glob> <context hash>)")
            if valid and directive == "home":
                self.homes.add(value.lower())
            elif valid and directive == "email":
                self.emails.add(value.lower())
            elif valid:
                self.files.append((parts[0], parts[1].lower()))
            self.rest.append("" if valid else line)

    def contexts(self, rel: str) -> frozenset[str]:
        """The context-hash prefixes allowed for file REL."""
        return frozenset(prefix for glob, prefix in self.files if fnmatch.fnmatchcase(rel, glob))


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


IDENTITY_MESSAGE = "maintainer identity token (use a placeholder)"
PATH_IDENTITY_MESSAGE = "maintainer identity token in a home-directory-shaped path (never exempt; use a placeholder)"


def personal_data(root: Path, files: list[str]) -> list[str]:
    allow, hashes = Allowlist(root), load_hashes(root)
    problems = list(allow.errors)
    for rel in files:
        raw = read_bytes(root, rel)
        if raw is None:
            continue
        binary = b"\0" in raw[:8000]
        if binary and not rel.lower().endswith(SCANNED_BINARY):
            continue
        if rel == ALLOW_FILE:
            raw = "\n".join(allow.rest).encode()
        text = original = raw.decode("latin-1" if binary else "utf-8", "replace")
        low = text.lower()  # only to decide whether the file can hold paths; offsets are taken after decoding
        # JSON-escaped (\/, \\/, \u002f) and URL-encoded (%2F, %5C) separators; newlines stay put, so line numbers hold.
        if "\\" in text:
            text = re.sub(r"\\u00(2[fF]|5[cC])", lambda m: "/" if m.group(1) in "2f2F" else "\\", text)
            while "\\/" in text:
                text = text.replace("\\/", "/")
        if "%" in text:
            text = text.replace("%2F", "/").replace("%2f", "/").replace("%5C", "\\").replace("%5c", "\\")
        hits: list[tuple[int, int, str]] = []
        if "@" in text or "users" in low or "home" in low:
            hits += [(start, end, HOME_MESSAGE) for start, end, name in home_hits(text, text.lower()) if name.lower() not in allow.homes]
            hits += [(offset, offset, EMAIL_MESSAGE) for offset in email_hits(text, frozenset(allow.emails))]
        found = [(text.count(chr(10), 0, start) + 1, message) for start, _, message in hits]
        if hashes:
            allowed = frozenset() if rel == ALLOW_FILE else allow.contexts(rel)
            variants = [fold_for_identity(original, True)] + ([fold_for_identity(original, False)] if any(e in original for e in ESCAPED_CONTROLS) else [])
            found += sorted({hit for variant in variants for hit in identity_hits(variant, hashes, allowed)})
        problems += [f"{rel}:{line}: {message}" for line, message in sorted(found, key=lambda item: item[0])]
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
# Parsed with PyYAML, so anchors, aliases, merge keys, flow style, tags and escapes are resolved
# before anything is checked. A missing PyYAML or a file that does not parse fails the check: a
# workflow that cannot be read is never skipped.

WORKFLOW_FILE = re.compile(r"^\.github/workflows/[^/]+\.ya?ml$")
UNPINNED = re.compile(r"@latest\b|\bnpx\s+(--yes|-y)\b")
CHECKOUT_GUARD = re.compile(r"git status --porcelain --ignored\b")
# with: inputs that run as code, so an expression in them is script injection. This is the one list:
# extend it when an action's input runs a command (compared lower-case; any key ending in -command or
# _command counts too). A list value is checked item by item.
CODE_INPUTS = frozenset({
    "script", "run", "command", "args", "arguments", "cmd", "entrypoint", "shell", "inlinescript",
    "start", "build", "install", "pre-command", "post-command", "pre_run", "post_run", "pre-run", "post-run", "options",
})
# Checking out the head of a pull request in a privileged trigger runs its code with secrets (a "pwn request").
PRIVILEGED_TRIGGERS = frozenset({"pull_request_target", "workflow_run"})
HEAD_REF = re.compile(r"github\.event\.pull_request\.(head|merge_commit_sha)|github\.head_ref|github\.event\.workflow_run\.head_|refs/pull/")


class LineMap(dict):
    """A YAML mapping that remembers the line of each key (1-based) and of the mapping itself."""

    line = 0
    key_line: dict


def line_loader(yaml):
    """A safe loader whose mappings are LineMaps; duplicate keys are an error, a later key
    overrides a merged (<<) one."""

    class Loader(yaml.SafeLoader):
        pass

    def construct(loader, node, deep=False):
        keys = [loader.construct_object(key, deep=True) for key, _ in node.value if key.tag != "tag:yaml.org,2002:merge"]
        if len(set(keys)) != len(keys):
            raise yaml.constructor.ConstructorError(None, None, "duplicate key in a mapping", node.start_mark)
        loader.flatten_mapping(node)
        mapping = LineMap()
        mapping.line, mapping.key_line = node.start_mark.line + 1, {}
        for key_node, value_node in node.value:
            key = loader.construct_object(key_node, deep=True)
            mapping[key] = loader.construct_object(value_node, deep=True)
            mapping.key_line[key] = key_node.start_mark.line + 1
        return mapping

    Loader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, construct)
    return Loader


def strings_with_lines(node, line: int):
    """Every string in a parsed document with the line of the key (or mapping) holding it."""
    if isinstance(node, str):
        yield node, line
    elif isinstance(node, dict):
        for key, value in node.items():
            yield from strings_with_lines(value, node.key_line[key])
    elif isinstance(node, list):
        for item in node:
            yield from strings_with_lines(item, line)


def write_all_lines(node, line: int):
    """Lines of every 'permissions: write-all' in the document."""
    if isinstance(node, dict):
        for key, value in node.items():
            if key == "permissions" and value == "write-all":
                yield node.key_line[key]
            yield from write_all_lines(value, node.key_line[key])
    elif isinstance(node, list):
        for item in node:
            yield from write_all_lines(item, line)


def is_code_input(key) -> bool:
    key = str(key).lower()
    return key in CODE_INPUTS or key.endswith(("-command", "_command"))


def expression_lines(mapping: LineMap, label: str, keys=None):
    """(line, message) for each ${{ }} in the values of MAPPING's code inputs, strings and lists of strings."""
    for key, value in mapping.items():
        if keys is not None and key not in keys:
            continue
        if is_code_input(key) and any("${{" in text for text in ([value] if isinstance(value, str) else value if isinstance(value, list) else []) if isinstance(text, str)):
            yield mapping.key_line[key], f"${{{{ }}}} expression inside the {label}{key} input, which runs as code (pass it through env)"


def step_problems(step, privileged: bool) -> list[tuple[int, str]]:
    if not isinstance(step, LineMap):
        return []
    found = []
    run = step.get("run")
    if isinstance(run, str) and "${{" in run:
        found.append((step.key_line["run"], "${{ }} expression inside a run script (pass it through env)"))
    with_ = step.get("with")
    if isinstance(with_, LineMap):
        found.extend(expression_lines(with_, "with: "))
    if "continue-on-error" in step and step["continue-on-error"] is not False:
        found.append((step.key_line["continue-on-error"], "continue-on-error hides failures"))
    uses = step.get("uses")
    if isinstance(uses, str) and uses.lower().startswith("actions/checkout@"):
        if not (isinstance(with_, LineMap) and with_.get("persist-credentials") is False):
            found.append((step.key_line["uses"], "actions/checkout without persist-credentials: false"))
        if privileged and isinstance(with_, LineMap):
            found.extend((with_.key_line[key], "a pull_request_target or workflow_run workflow checks out the head of the pull request (runs untrusted code with secrets)")
                         for key in ("ref", "repository") if HEAD_REF.search(str(with_.get(key, ""))))
    return found


def workflow_problems(rel: str, text: str) -> list[str]:
    try:
        import yaml
    except ImportError:
        return [f"{rel}: PyYAML is required to check workflows and is not installed (python3 -m pip install -r requirements-dev.txt)"]
    try:
        data = yaml.load(text, line_loader(yaml))  # noqa: S506 - a safe loader subclass
    except (yaml.YAMLError, TypeError) as error:
        return [f"{rel}: not parsed as YAML, so it cannot be checked: {str(error).splitlines()[0]}"]
    if not isinstance(data, LineMap):
        return [f"{rel}: not a YAML mapping, so it cannot be checked"]
    problems = []
    if "permissions" not in data:
        problems.append(f"{rel}: no top-level permissions block (least privilege)")
    jobs = data.get("jobs")
    runs = [run for job in (jobs.values() if isinstance(jobs, LineMap) else []) if isinstance(job, LineMap)
            for step in (job.get("steps") or []) if isinstance(step, LineMap) for run in [step.get("run")] if isinstance(run, str)]
    if rel.endswith("/ci.yml") and not any(CHECKOUT_GUARD.search(run) for run in runs):
        problems.append(f"{rel}: the checkout-unchanged guard must use git status --porcelain --ignored")
    if any(True for _ in write_all_lines(data, 0)):
        problems.append(f"{rel}: permissions: write-all (grant only the scopes the job needs)")
    env = data.get("env")
    if not (isinstance(env, LineMap) and env.get("FORCE_JAVASCRIPT_ACTIONS_TO_NODE24") in (True, "true")):
        problems.append(f"{rel}: FORCE_JAVASCRIPT_ACTIONS_TO_NODE24 is not set to true in the top-level env")
    triggers = data.get("on", data.get(True))  # YAML 1.1 reads the key "on" as True
    names = set(triggers) if isinstance(triggers, (list, dict)) else {triggers}
    privileged = bool(names & PRIVILEGED_TRIGGERS)
    lined = [(line, "unpinned @latest or npx --yes") for string, line in strings_with_lines(data, 1) if UNPINNED.search(string)]
    missing = []
    for name, job in (jobs.items() if isinstance(jobs, LineMap) else []):
        if not isinstance(job, LineMap):
            missing.append(name)
            continue
        if "timeout-minutes" not in job and "uses" not in job:  # a reusable-workflow caller cannot set one
            missing.append(name)
        services = job.get("services")
        containers = [job.get("container")] + (list(services.values()) if isinstance(services, LineMap) else [])
        for container in containers:
            if isinstance(container, LineMap):
                lined.extend(expression_lines(container, "container ", {"options"}))
        if "continue-on-error" in job and job["continue-on-error"] is not False:
            lined.append((job.key_line["continue-on-error"], "continue-on-error hides failures"))
        steps = job.get("steps")
        for step in steps if isinstance(steps, list) else []:
            lined.extend(step_problems(step, privileged))
    problems += [f"{rel}:{line}: {message}" for line, message in sorted(lined)]
    return problems + [f"{rel}: job {name} has no timeout-minutes" for name in missing]


def workflow_hardening(root: Path, files: list[str]) -> list[str]:
    problems = []
    for rel in files:
        if not WORKFLOW_FILE.match(rel):
            continue
        data = read_bytes(root, rel)
        if data is not None:
            problems.extend(workflow_problems(rel, data.decode("utf-8", "replace")))
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
