"""Command-line entry for shell_analysis.py (payload | command | load-payload | load-command).

A script run directly is compiled on every run; importing the module lets Python reuse
its cached bytecode, which keeps per-hook latency low.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import shell_analysis  # noqa: E402

raise SystemExit(shell_analysis.main(sys.argv[1:]))
