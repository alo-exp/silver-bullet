#!/usr/bin/env python3
"""Double-fork daemon so Cursor tool teardown cannot kill the OpenCode review."""
from __future__ import annotations

import os
import sys
from pathlib import Path

LOGDIR = Path("/Users/shafqat/projects/silver-bullet/repo/.planning/rfl-agent-interaction-modes-17ed9bf7/rung-05-kimi-k3-max")
SUB = os.environ.get("RFL_RETRY_SUBDIR", "attempt3")
RETRY = LOGDIR / SUB
RETRY.mkdir(parents=True, exist_ok=True)
script = LOGDIR / "launch-review.py"

# first fork
if os.fork() > 0:
    sys.exit(0)
os.setsid()
# second fork
if os.fork() > 0:
    sys.exit(0)

os.chdir("/")
os.environ["RFL_RETRY_SUBDIR"] = SUB
os.environ["HOME"] = "/Users/shafqat"
os.environ["RTK_DISABLED"] = "1"
os.environ["LEANCTX_DISABLED"] = "1"

devnull = os.open("/dev/null", os.O_RDWR)
os.dup2(devnull, 0)
out = os.open(str(RETRY / "daemon.out"), os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o644)
err = os.open(str(RETRY / "daemon.err"), os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o644)
os.dup2(out, 1)
os.dup2(err, 2)

os.execv(sys.executable, [sys.executable, str(script)])
