#!/usr/bin/env python3
"""Encoder CLI of sb:review-fix-ladder (native Claude subagents). See --help.

Run lifecycle:  --start --charter-file F | --approve | --issue-ticket review|verify_1|verify_2 |
                --write-policy-c ... --complete-triage | --record-apply | --run-signals | --advance |
                --status | --resume ID | --abort ID (needs the user's `RFL ABORT <id>` message)
Policy C:       --write-policy-c --assert-policy-c --assert-rfl-advance --issue-ledger --write-review-brief
                (--write-review-brief is the only legal review brief text)
Quota:          --classify-quota-window (JSON contract used by the agent delegates)
"""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

sys.dont_write_bytecode = True  # never write bytecode next to the plugin's scripts (also under `python3 -I`, which ignores PYTHONDONTWRITEBYTECODE)

_HERE = Path(__file__).resolve().parent
for _path in (_HERE / "lib", _HERE):
    if str(_path) not in sys.path:
        sys.path.insert(0, str(_path))

_spec = importlib.util.spec_from_file_location("_review_fix_ladder_impl", _HERE / "_review_fix_ladder_impl.py")
if _spec is None or _spec.loader is None:
    raise ImportError("cannot load the review-fix-ladder implementation")
_impl = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_impl)

# Re-export the public API so `import`/`runpy` callers keep working.
for _name in dir(_impl):
    if not _name.startswith("_"):
        globals()[_name] = getattr(_impl, _name)


def main() -> int:
    return int(_impl.main())


if __name__ == "__main__":
    sys.exit(main())
