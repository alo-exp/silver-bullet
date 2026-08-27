#!/usr/bin/env python3
"""Retry GLM 5.3 Max native OpenCode run. Hard timeout; no hang on quota."""
from __future__ import annotations

import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

os.environ["HOME"] = "/Users/shafqat"
os.environ["RTK_DISABLED"] = "1"
os.environ["LEANCTX_DISABLED"] = "1"

ROOT = Path("/Users/shafqat/projects/silver-bullet/repo")
LOGDIR = ROOT / ".planning/rfl-agent-interaction-modes-17ed9bf7/rung-04-glm53-max"
RETRY = LOGDIR / "retry-20260823T2108Z"
OPENCODE = os.environ.get("OPENCODE_BIN", "/Users/shafqat/.opencode/bin/opencode")
PROMPT = (LOGDIR / "prompt.md").read_text(encoding="utf-8")
TIMEOUT_SEC = int(os.environ.get("RFL_OPENCODE_TIMEOUT", "720"))

RETRY.mkdir(parents=True, exist_ok=True)
now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
start_txt = (
    f"{now}\nOPENCODE={OPENCODE}\nHOME={os.environ['HOME']}\n"
    "MODEL=opencode-go/glm-5.3\nVARIANT=max\n"
    f"TIMEOUT_SEC={TIMEOUT_SEC}\nNO_FILE_FLAG=1\nRETRY=1\n"
)
(RETRY / "invoke-start.txt").write_text(start_txt, encoding="utf-8")
(LOGDIR / "invoke-native-start.txt").write_text(start_txt, encoding="utf-8")

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
    "rfl-aim-rung-04-glm-5.3-max-retry",
    PROMPT,
]
(RETRY / "wrapper-argv.log").write_text(
    "\n".join(cmd[:-1] + ["<PROMPT.md last argv>"]) + "\n", encoding="utf-8"
)

code = 124
try:
    with (RETRY / "opencode-run.log").open("w", encoding="utf-8") as out, (
        RETRY / "opencode-run.err"
    ).open("w", encoding="utf-8") as err:
        proc = subprocess.run(cmd, stdout=out, stderr=err, timeout=TIMEOUT_SEC, check=False)
        code = proc.returncode if proc.returncode is not None else 1
except subprocess.TimeoutExpired:
    code = 124
    (RETRY / "timeout.txt").write_text(
        f"killed after {TIMEOUT_SEC}s hard timeout\n", encoding="utf-8"
    )

end = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
end_txt = f"{end}\nINVOKE_EXIT={code}\n"
(RETRY / "invoke-end.txt").write_text(end_txt, encoding="utf-8")
(LOGDIR / "invoke-native-end.txt").write_text(end_txt, encoding="utf-8")
sys.exit(code)
