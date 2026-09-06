#!/usr/bin/env python3
"""CLI wrapper for capability scoring (eval entry point)."""

import subprocess
import sys
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "capability_score.py"

if __name__ == "__main__":
    sys.exit(subprocess.call([sys.executable, str(SCRIPT), *sys.argv[1:]]))
