"""Single predicate deciding whether a Cursor custom-agent file is one that
scripts/install-cursor-sb-agents.sh generated (and so must be left alone by the
picker diagnostics and the legacy-agent quarantine).

A file qualifies only when every check holds, so copying the managed marker into
some other file does not exempt it:
  * it sits directly in the agents directory (no subdirectories, no symlinks);
  * its filename matches sb-<slug>.md;
  * the frontmatter name equals the filename stem and starts with "sb-";
  * the frontmatter description starts with the generator's fixed prefix;
  * the managed marker is the last non-empty line.
"""

from __future__ import annotations

import re
from pathlib import Path

MARKER = "<!-- sb-managed: cursor-sb-agents -->"
DESCRIPTION_PREFIX = "SB reusable ladder agent — "
_FILENAME = re.compile(r"sb-[a-z0-9._-]+\.md")


def is_installer_managed_agent(path: Path, agents_root: Path) -> bool:
    try:
        if path.is_symlink() or path.parent != agents_root or not _FILENAME.fullmatch(path.name):
            return False
        lines = path.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeDecodeError):
        return False
    if not lines or lines[0].strip() != "---":
        return False
    try:
        end = lines.index("---", 1)
    except ValueError:
        return False
    meta: dict[str, str] = {}
    for line in lines[1:end]:
        if ":" in line:
            key, value = line.split(":", 1)
            meta[key.strip()] = value.strip()
    name = meta.get("name", "")
    if name != path.stem or not name.startswith("sb-"):
        return False
    if not meta.get("description", "").startswith(DESCRIPTION_PREFIX):
        return False
    non_empty = [line.strip() for line in lines if line.strip()]
    return bool(non_empty) and non_empty[-1] == MARKER
