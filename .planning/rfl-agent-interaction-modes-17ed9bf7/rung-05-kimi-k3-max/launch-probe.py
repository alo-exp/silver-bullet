#!/usr/bin/env python3
"""Quota probe: Kimi K3 Max native OpenCode. Hard timeout; no hang."""
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
LOGDIR = ROOT / ".planning/rfl-agent-interaction-modes-17ed9bf7/rung-05-kimi-k3-max"
RETRY = LOGDIR / "retry-20260823T2132Z"
OPENCODE = os.environ.get("OPENCODE_BIN", "/Users/shafqat/.opencode/bin/opencode")
TIMEOUT_SEC = int(os.environ.get("RFL_OPENCODE_PROBE_TIMEOUT", "90"))

RETRY.mkdir(parents=True, exist_ok=True)
now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
start_txt = (
    f"{now}\nOPENCODE={OPENCODE}\nHOME={os.environ['HOME']}\n"
    "MODEL=opencode-go/kimi-k3\nVARIANT=max\n"
    f"TIMEOUT_SEC={TIMEOUT_SEC}\nPROBE=1\n"
)
(RETRY / "probe-start.txt").write_text(start_txt, encoding="utf-8")

cmd = [
    OPENCODE,
    "run",
    "--dir",
    str(ROOT),
    "-m",
    "opencode-go/kimi-k3",
    "--variant",
    "max",
    "--auto",
    "--title",
    "rfl-aim-rung-05-kimi-k3-max-probe",
    "Reply with exactly PONG and stop. Do not use tools. Do not edit files.",
]
(RETRY / "probe-argv.log").write_text("\n".join(cmd) + "\n", encoding="utf-8")

code = 124
try:
    with (RETRY / "probe.out").open("w", encoding="utf-8") as out, (
        RETRY / "probe.err"
    ).open("w", encoding="utf-8") as err:
        proc = subprocess.run(cmd, stdout=out, stderr=err, timeout=TIMEOUT_SEC, check=False)
        code = proc.returncode if proc.returncode is not None else 1
except subprocess.TimeoutExpired:
    code = 124
    (RETRY / "probe-timeout.txt").write_text(
        f"killed after {TIMEOUT_SEC}s hard timeout\n", encoding="utf-8"
    )

end = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
(RETRY / "probe-end.txt").write_text(f"{end}\nPROBE_EXIT={code}\n", encoding="utf-8")
sys.exit(code)
