#!/usr/bin/env python3
"""Native OpenCode Qwen3.8 XHigh (highest live variant). invoke.sh missing; mimo pin N/A."""
from __future__ import annotations

import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path("/Users/shafqat/projects/silver-bullet/repo")
LOGDIR = ROOT / ".planning/rfl-agent-interaction-modes-17ed9bf7/rung-03-qwen38-xhigh"
OPENCODE = os.environ.get("OPENCODE_BIN", str(Path.home() / ".opencode/bin/opencode"))
VARIANT = os.environ.get("OPENCODE_VARIANT", "max")  # live CLI: high|max|minimal; no xhigh
MODEL = os.environ.get("OPENCODE_MODEL", "opencode-go/qwen3.8-max")

MSG = (LOGDIR / "prompt.md").read_text(encoding="utf-8")
MSG += "\n\nRead charter + prior reviews if needed:\n"
MSG += "  .planning/rfl-agent-interaction-modes-17ed9bf7/CHARTER.md\n"
MSG += "  .planning/rfl-agent-interaction-modes-17ed9bf7/rung-01-minimax-m3-high/review.md\n"
MSG += "  .planning/rfl-agent-interaction-modes-17ed9bf7/rung-02-deepseek-v4-pro-max/review.md\n"

(LOGDIR / "invoke-native-start.txt").write_text(
    datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    + f"\nOPENCODE={OPENCODE}\nMODEL={MODEL}\nVARIANT={VARIANT}\n",
    encoding="utf-8",
)

env = os.environ.copy()
env["RTK_DISABLED"] = "1"
cmd = [
    OPENCODE,
    "run",
    "--dir",
    str(ROOT),
    "-m",
    MODEL,
    "--variant",
    VARIANT,
    "--auto",
    "--title",
    "rfl-aim-rung-03-qwen38-xhigh",
    MSG,
]
with (LOGDIR / "opencode-run.log").open("w", encoding="utf-8") as out, (
    LOGDIR / "opencode-run.err"
).open("w", encoding="utf-8") as err:
    proc = subprocess.run(cmd, cwd=str(ROOT), env=env, stdout=out, stderr=err)
(LOGDIR / "invoke-native-end.txt").write_text(
    datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ") + f"\nINVOKE_EXIT={proc.returncode}\n",
    encoding="utf-8",
)
sys.exit(proc.returncode)
