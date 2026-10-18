"""Single predicate deciding whether a Cursor custom-agent file is one that
scripts/install-cursor-sb-agents.sh generated (and so must be left alone by the
picker diagnostics, the legacy-agent quarantine and the installer's own pruning).

A file qualifies only when every check holds, so copying the managed marker into
some other file does not exempt it:
  * it sits directly in the agents directory (no subdirectories, no symlinks);
  * its filename is <name>.md with <name> drawn from the generator's character set
    (any configured agent_name_prefix, model ids with upper case, spaces, dots);
  * the frontmatter name equals the filename stem;
  * the frontmatter description starts with the generator's fixed prefix;
  * the managed marker is the last non-empty line.
Line endings (CRLF) and trailing whitespace are tolerated; a byte-order mark is not.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

MARKER = "<!-- sb-managed: cursor-sb-agents -->"
DESCRIPTION_PREFIX = "SB reusable ladder agent — "
_FILENAME = re.compile(r"[A-Za-z0-9][A-Za-z0-9._ -]*\.md")


def is_installer_managed_agent(path: Path, agents_root: Path) -> bool:
    try:
        if path.is_symlink() or path.parent != agents_root or not _FILENAME.fullmatch(path.name):
            return False
        lines = [line.strip() for line in path.read_text(encoding="utf-8").splitlines()]
    except (OSError, UnicodeDecodeError):
        return False
    if not lines or lines[0] != "---":
        return False
    end = next((i for i in range(1, len(lines)) if lines[i] == "---"), None)
    if end is None:
        return False
    meta: dict[str, str] = {}
    for line in lines[1:end]:
        if ":" in line:
            key, value = line.split(":", 1)
            meta[key.strip()] = value.strip()
    if meta.get("name") != path.stem:
        return False
    if not meta.get("description", "").startswith(DESCRIPTION_PREFIX):
        return False
    non_empty = [line for line in lines if line]
    return non_empty[-1] == MARKER


def main(argv: list[str]) -> int:
    """`sb_managed_agent.py FILE`: exit 0 when FILE is installer-managed in its own directory."""
    if len(argv) != 1:
        return 2
    path = Path(argv[0])
    return 0 if is_installer_managed_agent(path, path.parent) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
