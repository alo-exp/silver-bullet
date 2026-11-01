#!/usr/bin/env python3
"""File-content invariants for scripts/check-repo-invariants.sh.

Usage: repo_invariants.py CHECK [ROOT]

CHECK is one of:
  worm-indicators       host configuration that runs code when the folder is opened
                        (VS Code folder-open tasks, task.allowAutomaticTasks) and the
                        public/fonts/ payload directory of the recurring repository worm
  binary-signatures     font and image files whose bytes are not that format (a script or
                        text saved under a font or image name)
  vendored-skills-lock  the third-party skills under .agents/skills match skills-lock.json
  tracked-file-size     no tracked file nears GitHub's 100 MB per-file limit

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


def worm_indicators(root: Path, files: list[str]) -> list[str]:
    problems = []
    for rel in files:
        if PAYLOAD_DIR.search(rel):
            problems.append(f"{rel}: tracked under public/fonts/, where the repository worm hid its payload")
        if not AUTORUN_CONFIG.search(rel):
            continue
        text = (read_bytes(root, rel) or b"").decode("utf-8", "replace")
        if FOLDER_OPEN_TASK.search(text):
            problems.append(f"{rel}: task runs automatically when the folder is opened (runOn: folderOpen)")
        if AUTOMATIC_TASKS.search(text):
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
LOCK_FILE = "skills-lock.json"
# Skills installed and versioned by a tool rather than the skills lock: name -> version file.
TOOL_MANAGED_SKILLS = {"graphify": ".graphify_version"}


def skill_hash(root: Path, skill: str, rel_files: list[str]) -> str:
    """The skills-lock.json computedHash: sha256 over each file's path inside the skill
    followed by its bytes, files in case-insensitive path order."""
    digest = hashlib.sha256()
    for rel in sorted(rel_files, key=lambda p: (p.lower(), p)):
        digest.update(rel.encode("utf-8"))
        digest.update((root / SKILLS_DIR / skill / rel).read_bytes())
    return digest.hexdigest()


def vendored_skills_lock(root: Path, files: list[str]) -> list[str]:
    by_skill: dict[str, list[str]] = {}
    prefix = SKILLS_DIR + "/"
    for rel in files:
        if rel.startswith(prefix) and "/" in rel[len(prefix):]:
            skill, inner = rel[len(prefix):].split("/", 1)
            by_skill.setdefault(skill, []).append(inner)
    lock_path = root / LOCK_FILE
    try:
        locked = json.loads(lock_path.read_text(encoding="utf-8")).get("skills", {}) if lock_path.is_file() else {}
    except (ValueError, AttributeError):
        return [f"{LOCK_FILE}: not valid JSON with a \"skills\" object"]
    problems = []
    for skill, entry in sorted(locked.items()):
        inner = by_skill.get(skill)
        if not inner:
            problems.append(f"{skill}: listed in {LOCK_FILE} but missing from {SKILLS_DIR}/")
        elif skill_hash(root, skill, inner) != entry.get("computedHash"):
            problems.append(f"{skill}: content does not match {LOCK_FILE} (computedHash)")
    for skill, inner in sorted(by_skill.items()):
        if skill in locked or TOOL_MANAGED_SKILLS.get(skill) in inner:
            continue
        problems.append(f"{skill}: vendored skill is not in {LOCK_FILE}")
    return problems


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


CHECKS = {
    "worm-indicators": worm_indicators,
    "binary-signatures": binary_signatures,
    "vendored-skills-lock": vendored_skills_lock,
    "tracked-file-size": tracked_file_size,
}


def main(argv: list[str]) -> int:
    if len(argv) not in (1, 2) or argv[0] not in CHECKS:
        print(f"usage: repo_invariants.py {{{','.join(CHECKS)}}} [ROOT]", file=sys.stderr)
        return 2
    root = Path(argv[1] if len(argv) == 2 else ".")
    problems = CHECKS[argv[0]](root, tracked_files(root))
    for problem in problems:
        print(f"  {problem}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
