#!/usr/bin/env python3
"""Native OpenCode DeepSeek V4 Pro Max (no --file; positional message only)."""
from __future__ import annotations

import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path("/Users/shafqat/projects/silver-bullet/repo")
LOGDIR = ROOT / ".planning/rfl-agent-interaction-modes-17ed9bf7/rung-02-deepseek-v4-pro-max"
OPENCODE = os.environ.get("OPENCODE_BIN", str(Path.home() / ".opencode/bin/opencode"))
MSG = (LOGDIR / "prompt.md").read_text(encoding="utf-8")
MSG += "\n\n---BRIEF---\n"
MSG += (LOGDIR / "brief.md").read_text(encoding="utf-8")
MSG += "\n\nPlan path: .cursor/plans/agent_interaction_modes_17ed9bf7.plan.md\n"
MSG += "Rung-1 review: .planning/rfl-agent-interaction-modes-17ed9bf7/rung-01-minimax-m3-high/review.md\n"

(LOGDIR / "invoke-native-start.txt").write_text(
    datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ") + f"\nOPENCODE={OPENCODE}\n",
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
    "opencode-go/deepseek-v4-pro",
    "--variant",
    "max",
    "--auto",
    "--title",
    "rfl-aim-rung-02-deepseek-v4-pro-max",
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
