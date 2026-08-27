#!/usr/bin/env python3
"""RFL rung 4: GLM 5.3 Max via native OpenCode NI. No --file (1.17.16 treats extra positional as file)."""
from __future__ import annotations

import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

os.environ["HOME"] = "/Users/shafqat"
os.environ["RTK_DISABLED"] = "1"
os.environ["LEAN_CTX_DISABLED"] = "1"

ROOT = Path("/Users/shafqat/projects/silver-bullet/repo")
LOGDIR = ROOT / ".planning/rfl-agent-interaction-modes-17ed9bf7/rung-04-glm53-max"
OPENCODE = os.environ.get("OPENCODE_BIN", "/Users/shafqat/.opencode/bin/opencode")
PROMPT = (LOGDIR / "prompt.md").read_text(encoding="utf-8")

now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
(LOGDIR / "invoke-native-start.txt").write_text(
    f"{now}\nOPENCODE={OPENCODE}\nHOME={os.environ['HOME']}\n"
    "MODEL=opencode-go/glm-5.3\nVARIANT=max\nNO_FILE_FLAG=1\n",
    encoding="utf-8",
)

cmd = [
    OPENCODE,
    "run",
    "--dir",
    str(ROOT),
    "-m",
    "opencode-go/glm-5.3",
    "--variant",
    "max",
    "--auto",
    "--title",
    "rfl-aim-rung-04-glm-5.3-max",
    PROMPT,
]
argv_log = LOGDIR / "wrapper-argv.log"
argv_log.write_text("\n".join(cmd[:-1] + ["<PROMPT.md last argv>"]) + "\n", encoding="utf-8")

with (LOGDIR / "opencode-run.log").open("w", encoding="utf-8") as out, (
    LOGDIR / "opencode-run.err"
).open("w", encoding="utf-8") as err:
    proc = subprocess.run(cmd, stdout=out, stderr=err, check=False)

end = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
(LOGDIR / "invoke-native-end.txt").write_text(
    f"{end}\nINVOKE_EXIT={proc.returncode}\n",
    encoding="utf-8",
)
sys.exit(proc.returncode if proc.returncode is not None else 1)
